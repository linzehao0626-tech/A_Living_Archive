#include <Arduino.h>
#include <Adafruit_NeoPixel.h>
#include <ESP_I2S.h>
#include <SPI.h>
#include <SD.h>
#include <math.h>
#include <string.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

// A LIVING ARCHIVE — INTEGRATED V3 / AUDIO CUES / SERVO 170 DEG
// ESP32-S3, Arduino ESP32 3.x.
// Original MEMORY CORE light effects retained.

#define LED_PIN 4
#define LED_COUNT 16
#define TOUCH_PIN 6
#define MIC_BCLK 7
#define MIC_WS 8
#define MIC_DATA 9
#define AMP_BCLK 10
#define AMP_WS 11
#define AMP_DATA 12
#define SD_SCK 13
#define SD_MISO 14
#define SD_MOSI 15
#define SD_CS 16

const uint8_t SERVO_PINS[5] = {2, 5, 17, 18, 21};
// Set a direction to -1 only if that particular servo turns the wrong way.
int8_t SERVO_DIRECTION[5] = {1, 1, 1, 1, 1};
// Map conventional 1000-2000us / 0-180 degree instructions:
// CLOSED = 5 degrees (1028us); WAKING = 175 degrees (1972us).
const uint16_t SERVO_CENTER_US = 1500;
const uint16_t SERVO_CLOSED_US = 1028;
const uint16_t SERVO_OPEN_US = 1972;
const uint16_t SERVO_MIN_US = 1000;
const uint16_t SERVO_MAX_US = 2000;
const uint32_t SERVO_TICK_MS = 8;
const uint16_t SERVO_STEP_US = 15;

const uint32_t AUDIO_RATE = 16000;
const uint32_t WAKING_MS = 3400;
const uint32_t ARCHIVING_MS = 3600;
const uint32_t MAX_RECORD_MS = 90000;
const uint32_t TOUCH_DEBOUNCE_MS = 55;
const uint32_t LONG_PRESS_MS = 1400;
const float REPLAY_GAIN = 0.38f;
const float CUE_GAIN = 0.24f;  // gentle but audible; reduce if too loud
const float TAU = 6.28318530718f;

Adafruit_NeoPixel ring(LED_COUNT, LED_PIN, NEO_GRB + NEO_KHZ800);
I2SClass mic(I2S_NUM_0);
I2SClass amp(I2S_NUM_1);
SPIClass sdSPI(FSPI);

bool sdOK = false;
bool ampOK = false;
uint32_t errors = 0;
uint32_t touchCount = 0;
uint8_t state = 0;           // 0 Closed, 1 Waking, 2 Listening, 3 Archiving
uint32_t stateStarted = 0;

// Touch: a short touch is recognised when the finger is released.
bool touchRawPrevious = false;
bool touchStable = false;
bool touchLongHandled = false;
uint32_t touchEdgeAt = 0;
uint32_t touchPressedAt = 0;

// LED effects: V4
float shown[LED_COUNT][3] = {{0}};
float transitionFrom[LED_COUNT][3] = {{0}};
uint32_t lastLEDFrame = 0;

// Five physical servos, automatically enabled
bool servoAttached[5] = {false};
bool servoStopped = false;
uint16_t servoPosition[5] = {1500,1500,1500,1500,1500};
uint16_t servoTarget[5] = {1500,1500,1500,1500,1500};
uint32_t lastServoTick = 0;
uint8_t servoCursor = 0;

// WAV capture: 16kHz / signed 16-bit / mono.
File wav;
bool recording = false;
bool recordWriteOK = true;
char wavPath[24] = "";
char latestPath[24] = "";
int32_t micStereo[256 * 2];
int16_t pcm[2048];
size_t pcmUsed = 0;
uint32_t recordedFrames = 0;
uint32_t recordedBytes = 0;
uint32_t recordingStarted = 0;
uint32_t lastMicReport = 0;
uint64_t rmsSum = 0;
uint32_t rmsWindows = 0;
uint32_t activeWindows = 0;
uint32_t extremeSamples = 0;
uint32_t allSamples = 0;
uint32_t memorySequence = 0;

// Audio core: continuously clocks zeros when not playing WAV/cues.
// GPIO SD on MAX98357A stays connected to ESP32 3V3.
portMUX_TYPE audioMux = portMUX_INITIALIZER_UNLOCKED;
volatile uint8_t pendingCue = 0;
volatile bool playRequested = false;
volatile bool stopPlaybackRequested = false;
volatile bool playbackActive = false;
char playRequestPath[24] = "";
TaskHandle_t speakerTaskHandle = nullptr;
volatile uint32_t audioWriteErrors = 0;

enum { CUE_NONE = 0, CUE_WAKE = 1, CUE_ARCHIVE = 2, CUE_CLOSED = 3 };

// ------------------------ UTILITIES ------------------------
float clip01(float x) { return x < 0 ? 0 : (x > 1 ? 1 : x); }
float smooth01(float x) { x=clip01(x);return x*x*(3.0f-2.0f*x); }
float smoothBetween(float a,float b,float x) {
  if (b<=a) return x>=b ? 1.0f : 0.0f;
  return smooth01((x-a)/(b-a));
}
float wrap16(float x) { x=fmodf(x,16.0f);if(x<0)x+=16.0f;return x; }
float ringDist(float a,float b) { float d=wrap16(a-b);return fminf(d,16.0f-d); }
float halo(float led,float center,float width) {
  float d=ringDist(led,center)/width;return expf(-0.5f*d*d);
}
float breathing(float t,float period) {
  return smooth01(0.5f-0.5f*cosf(TAU*t/period));
}
uint8_t toByte(float x) {
  x=constrain(x,0.0f,255.0f);return (uint8_t)(x+0.5f);
}

// ------------------------------------
void lightColor(int mode,int led,float t,float &r,float &g,float &b) {
  float i=(float)led; r=g=b=0;
  if (mode==0) {
    float breath=breathing(t,4.4f);
    float shimmer=0.95f+0.05f*sinf(i*0.75f-t*0.45f);
    float intensity=(0.045f+0.49f*breath)*shimmer;
    float gold=0.07f*halo(i,t*0.27f,2.0f);
    r=255*(intensity+gold);
    g=130*intensity+148*gold;
    b=48*intensity+80*gold;
    return;
  }
  if (mode==1) {
    float grow=smoothBetween(0,2.65f,t);
    float front=grow*8.4f;
    float distance=ringDist(i,0);
    float opened=1-smoothBetween(front-0.65f,front+0.8f,distance);
    float edge=expf(-0.5f*powf((distance-front)/0.85f,2));
    float after=smoothBetween(2.4f,3.15f,t);
    float pulse=0.5f+0.5f*sinf(t*TAU/3.2f);
    float power=0.04f+0.63f*opened+0.30f*edge;
    power*=1.0f-after*0.14f*(1-pulse);
    float orchid=clip01(distance/9.5f);
    r=(255-72*orchid)*power;
    g=(92+8*orchid)*power+90*edge*0.21f;
    b=(148+90*orchid)*power;
    return;
  }
  if (mode==2) {
    float breath=breathing(t,4.8f);
    float base=0.12f+0.48f*breath;
    float texture=0.91f+0.09f*sinf(i*0.84f+t*0.3f);
    base*=texture;
    float posA=wrap16(1.5f+t*1.85f);
    float posB=wrap16(9.5f-t*1.15f);
    float rose=halo(i,posA,1.45f);
    float blushTrail=halo(i,posA-1.75f,2.0f);
    float pearl=halo(i,posB,1.75f);
    float flicker=0.5f+0.5f*sinf(i*0.7f-t*0.82f);
    r=153*base+155*rose*0.63f+75*blushTrail*0.38f+125*pearl*0.44f;
    g=97*base+92*rose*0.42f+91*pearl*0.68f+9*flicker;
    b=237*base+133*rose*0.46f+110*pearl*0.73f;
    return;
  }
  if (mode==3) {
    if (t<1.95f) {
      float p=smoothBetween(0,1.95f,t);
      float turns=1.65f*t+0.80f*t*t;
      float head=wrap16(16.0f*turns);
      float length=8.0f*(1-p)+0.65f;
      float behind=wrap16(head-i);
      float trail=expf(-behind/(0.26f+length*0.37f))*(1-smoothBetween(length*0.72f,length,behind));
      float core=halo(i,head,0.35f+1.25f*(1-p));
      float echo=halo(i,head-4.0f,1.35f)*(1-p);
      float vanish=1-smoothBetween(1.70f,1.95f,t);
      float haze=(1-p)*0.095f;
      r=255*(haze+vanish*(0.66f*trail+0.47f*core+0.12f*echo));
      g=74*haze+vanish*(69*trail+161*core+23*echo);
      b=215*haze+vanish*(177*trail+183*core+105*echo);
      return;
    }
    if (t<2.30f) {
      float flash=sinf(3.14159265f*clip01((t-1.95f)/0.35f));
      float centerGlow=halo(i,0.0f,2.6f);
      float value=flash*(0.19f+0.56f*centerGlow);
      r=255*value;g=222*value;b=202*value;return;
    }
    float fade=1-smoothBetween(2.30f,3.50f,t);
    float ember=halo(i,0.0f,1.35f)*fade;
    r=245*ember;g=128*ember;b=52*ember;
  }
}
void setState(uint8_t next) {
  if(next>3)return;
  for(int i=0;i<LED_COUNT;i++)for(int c=0;c<3;c++)transitionFrom[i][c]=shown[i][c];
  state=next;stateStarted=millis();
  const char *names[]={"CLOSED","WAKING","LISTENING","ARCHIVING"};
  Serial.print("STATE:");Serial.println(names[state]);
}
void updateLights() {
  uint32_t now=millis();if(now-lastLEDFrame<16)return;
  lastLEDFrame=now;
  float t=(now-stateStarted)/1000.0f;
  float fade=smoothBetween(0,state==3?0.15f:0.42f,t);
  for(int i=0;i<LED_COUNT;i++) {
    float r,g,b;lightColor(state,i,t,r,g,b);
    shown[i][0]=transitionFrom[i][0]*(1-fade)+r*fade;
    shown[i][1]=transitionFrom[i][1]*(1-fade)+g*fade;
    shown[i][2]=transitionFrom[i][2]*(1-fade)+b*fade;
    ring.setPixelColor(i,ring.Color(toByte(shown[i][0]),toByte(shown[i][1]),toByte(shown[i][2])));
  }
  ring.show();
}

// ------------------------ SERVOS ------------------------
// 170-degree total sweep between separately bounded endpoints.
// Servos move in staggered slow steps.
void writeServoUs(int i,uint16_t pulse) {
  if(!servoAttached[i])return;
  uint32_t duty=((uint32_t)pulse*16384UL)/20000UL;
  ledcWrite(SERVO_PINS[i],duty);
}
void initServos() {
  for(int i=0;i<5;i++) {
    if(ledcAttach(SERVO_PINS[i],50,14)) {
      servoAttached[i]=true;
      writeServoUs(i,SERVO_CENTER_US);
      // Slew slowly to the CLOSED endpoint rather than jumping there.
      servoTarget[i] = SERVO_DIRECTION[i] >= 0
        ? SERVO_CLOSED_US : SERVO_OPEN_US;
      Serial.printf("SERVO%d GPIO%d START 90 -> CLOSED (SLOW)\n",i+1,SERVO_PINS[i]);
    } else {
      errors++;
      Serial.printf("SERVO%d ATTACH FAILED\n",i+1);
    }
    delay(110);
  }
}
void setServoTargets(bool conceptualOpen) {
  if(servoStopped)return;
  for(int i=0;i<5;i++) {
    // Every activation moves between 5-degree and 175-degree
    // Endpoints: 170-degree total commanded excursion.
    // Reverse direction by setting SERVO_DIRECTION[i] to -1.
    int value = (SERVO_DIRECTION[i]>=0)
      ? (conceptualOpen ? SERVO_OPEN_US : SERVO_CLOSED_US)
      : (conceptualOpen ? SERVO_CLOSED_US : SERVO_OPEN_US);
    servoTarget[i]=(uint16_t)constrain(value,(int)SERVO_MIN_US,(int)SERVO_MAX_US);
  }
}
void stopServoPWM() {
  servoStopped=true;
  for(int i=0;i<5;i++) {
    if(servoAttached[i]) {
      ledcDetach(SERVO_PINS[i]);servoAttached[i]=false;
    }
  }
  Serial.println("SERVO PWM DISABLED. Restart to re-enable.");
}
void updateServos() {
  if(servoStopped || millis()-lastServoTick<SERVO_TICK_MS)return;
  lastServoTick=millis();
  int i=servoCursor;servoCursor=(servoCursor+1)%5;
  if(!servoAttached[i])return;
  int current=servoPosition[i];int target=servoTarget[i];
  if(current<target)current=min(current+(int)SERVO_STEP_US,target);
  else if(current>target)current=max(current-(int)SERVO_STEP_US,target);
  servoPosition[i]=(uint16_t)current;
  writeServoUs(i,(uint16_t)current);
}

// ------------------------ WAV / SD ------------------------
void put16(File &f,uint16_t v) {f.write((uint8_t)(v&255));f.write((uint8_t)((v>>8)&255));}
void put32(File &f,uint32_t v) {for(int i=0;i<4;i++)f.write((uint8_t)((v>>(8*i))&255));}
void wavHeader(File &f,uint32_t n) {
  f.seek(0);f.write((const uint8_t*)"RIFF",4);put32(f,36+n);
  f.write((const uint8_t*)"WAVE",4);f.write((const uint8_t*)"fmt ",4);put32(f,16);
  put16(f,1);put16(f,1);put32(f,AUDIO_RATE);put32(f,AUDIO_RATE*2);
  put16(f,2);put16(f,16);f.write((const uint8_t*)"data",4);put32(f,n);
}
bool flushPCM() {
  if(!pcmUsed)return true;
  size_t expected=pcmUsed*2;
  size_t actual=wav.write((const uint8_t*)pcm,expected);
  recordedBytes+=(uint32_t)actual;pcmUsed=0;
  if(actual!=expected) {recordWriteOK=false;errors++;return false;}
  return true;
}
void logMemory(bool sizeOK,bool micSuspect,uint32_t fileSize) {
  if(!sdOK)return;
  bool first=!SD.exists("/TEST_V3.CSV");
  File f=SD.open("/TEST_V3.CSV",FILE_APPEND);
  if(!f) {errors++;Serial.println("LOG ERROR");return;}
  if(first)f.println("uptime_ms,file,pcm_ms,bytes,wav_size,avg_rms16,voice_windows,total_windows,extremes,size_ok,mic_suspect,touches,errors");
  uint32_t ms=(uint32_t)(((uint64_t)recordedFrames*1000ULL)/AUDIO_RATE);
  uint32_t rms=rmsWindows?(uint32_t)(rmsSum/rmsWindows):0;
  f.printf("%lu,%s,%lu,%lu,%lu,%lu,%lu,%lu,%lu,%d,%d,%lu,%lu\n",
    (unsigned long)millis(),wavPath,(unsigned long)ms,(unsigned long)recordedBytes,
    (unsigned long)fileSize,(unsigned long)rms,(unsigned long)activeWindows,
    (unsigned long)rmsWindows,(unsigned long)extremeSamples,sizeOK?1:0,micSuspect?1:0,(unsigned long)touchCount,(unsigned long)errors);
  f.close();
}
bool startRecording() {
  if(!sdOK) {Serial.println("RECORD FAILED: SD NOT READY");errors++;return false;}
  bool found=false;
  for(uint32_t n=1;n<=9999;n++) {
    snprintf(wavPath,sizeof(wavPath),"/MEM%04lu.WAV",(unsigned long)n);
    if(!SD.exists(wavPath)) {memorySequence=n;found=true;break;}
  }
  if(!found) {Serial.println("RECORD FAILED: FILES FULL");errors++;return false;}
  wav=SD.open(wavPath,FILE_WRITE);
  if(!wav) {Serial.println("RECORD FAILED: FILE CREATE");errors++;return false;}
  wavHeader(wav,0);
  mic.setPins(MIC_BCLK,MIC_WS,-1,MIC_DATA);
  if(!mic.begin(I2S_MODE_STD,AUDIO_RATE,I2S_DATA_BIT_WIDTH_32BIT,I2S_SLOT_MODE_STEREO)) {
    Serial.println("RECORD FAILED: MIC I2S");wav.close();SD.remove(wavPath);errors++;return false;
  }
  pcmUsed=0;recordedFrames=0;recordedBytes=0;
  rmsSum=0;rmsWindows=0;activeWindows=0;extremeSamples=0;allSamples=0;
  recordWriteOK=true;recording=true;recordingStarted=millis();lastMicReport=millis();
  Serial.printf("RECORDING:%s\n",wavPath);
  return true;
}
void finishRecording() {
  if(!recording)return;
  recording=false;mic.end();
  bool flushed=flushPCM();
  wavHeader(wav,recordedBytes);wav.flush();
  uint32_t size=wav.size();wav.close();
  bool sizeOK=flushed && recordWriteOK && (size==recordedBytes+44) && recordedBytes>0;
  bool suspect=allSamples>0 && extremeSamples>(allSamples*9ULL)/10ULL;
  if(!sizeOK)errors++;
  if(sizeOK && !suspect) {
    strncpy(latestPath,wavPath,sizeof(latestPath)-1);latestPath[sizeof(latestPath)-1]='\0';
  }
  logMemory(sizeOK,suspect,size);
  Serial.printf("SAVED:%s WAV_BYTES:%lu SIZE:%s MIC:%s\n",wavPath,(unsigned long)size,
    sizeOK?"OK":"ERROR",suspect?"SUSPECT":"NO_RAIL_PATTERN");
}

// Declare archive helper before recording so failures can transition safely.
void enterArchiving();
void updateRecording() {
  if(!recording)return;
  size_t nBytes=mic.readBytes((char*)micStereo,sizeof(micStereo));
  int count=(int)(nBytes/8);
  if(count<=0) {
    Serial.println("MIC READ ERROR");errors++;recordWriteOK=false;
    enterArchiving();return;
  }
  uint64_t sq=0;
  for(int i=0;i<count;i++) {
    int32_t raw=micStereo[i*2];
    if(raw==INT32_MIN || raw==0)extremeSamples++;
    allSamples++;
    int16_t sample=(int16_t)(raw>>16);
    pcm[pcmUsed++]=sample;
    sq+=(int32_t)sample*(int32_t)sample;
    recordedFrames++;
    if(pcmUsed==2048 && !flushPCM()) {
      Serial.println("SD WRITE ERROR");enterArchiving();return;
    }
  }
  uint32_t rms=(uint32_t)sqrtf((float)sq/count);
  rmsSum+=rms;rmsWindows++;if(rms>250)activeWindows++;
  if(millis()-lastMicReport>=2000) {
    lastMicReport=millis();
    Serial.printf("STATE:LISTENING,VOICE:%.2f,TRACE:%.1f,MEMORY:%lu,RMS16:%lu\n",
      clip01(rms/2500.0f),rmsWindows?100.0f*activeWindows/rmsWindows:0.0f,
      (unsigned long)memorySequence,(unsigned long)rms);
  }
}

// ------------------------ SPEAKER AUDIO TASK ------------------------
// Tone cues and WAV playback run only here (one I2S writer).
// Silent periods stream zeros, like the standalone working speaker test.
uint32_t readLE32(const uint8_t *p) {
  return (uint32_t)p[0]|((uint32_t)p[1]<<8)|((uint32_t)p[2]<<16)|((uint32_t)p[3]<<24);
}
void audioBlock(const int16_t *stereo,size_t frames) {
  size_t expected=frames*2*sizeof(int16_t);
  if(amp.write((const uint8_t*)stereo,expected)!=expected)audioWriteErrors++;
}
void audioSilence() {
  static int16_t zeros[256*2]={0};audioBlock(zeros,256);
}
void toneSweep(float firstHz,float lastHz,uint16_t ms) {
  static int16_t data[256*2];
  uint32_t total=(uint32_t)AUDIO_RATE*ms/1000;
  float phase=0;
  for(uint32_t start=0;start<total;start+=256) {
    uint32_t n=min((uint32_t)256,total-start);
    for(uint32_t j=0;j<n;j++) {
      float p=(float)(start+j)/(float)total;
      float env=fminf(1.0f,p/0.065f)*powf(1.0f-p,1.6f);
      float hz=firstHz+(lastHz-firstHz)*p;
      phase+=TAU*hz/AUDIO_RATE;
      if(phase>=TAU)phase-=TAU;
      float wave=sinf(phase)+0.17f*sinf(2*phase);
      int16_t v=(int16_t)(wave*env*CUE_GAIN*16000.0f);
      data[j*2]=v;data[j*2+1]=v;
    }
    audioBlock(data,n);
  }
}
void playCueNow(uint8_t cue) {
  if(cue==CUE_WAKE) {
    Serial.println("SOUND:WAKING");
    toneSweep(560,760,190);toneSweep(750,1050,230);
  } else if(cue==CUE_ARCHIVE) {
    Serial.println("SOUND:ARCHIVING");
    toneSweep(1000,820,140);toneSweep(820,660,170);toneSweep(660,500,210);
  } else if(cue==CUE_CLOSED) {
    Serial.println("SOUND:CLOSED");
    toneSweep(550,440,260);
  }
  audioSilence();audioSilence();
}
void queueCue(uint8_t cue) {
  if(!ampOK) {Serial.println("SOUND SKIPPED: SPEAKER NOT READY");return;}
  portENTER_CRITICAL(&audioMux);
  pendingCue=cue;
  portEXIT_CRITICAL(&audioMux);
}
void playLatestWAV(const char *path) {
  File f=SD.open(path,FILE_READ);
  if(!f || f.size()<44) {Serial.println("PLAY: FILE ERROR");if(f)f.close();return;}
  uint8_t h[44];bool ok=f.read(h,44)==44 &&
    memcmp(h,"RIFF",4)==0 && memcmp(h+8,"WAVE",4)==0 &&
    memcmp(h+12,"fmt ",4)==0 && memcmp(h+36,"data",4)==0 &&
    h[20]==1 && h[21]==0 && h[22]==1 && h[23]==0 &&
    readLE32(h+24)==AUDIO_RATE && h[34]==16 && h[35]==0;
  if(!ok) {Serial.println("PLAY: INVALID 16K MONO WAV");f.close();return;}
  uint32_t audioBytes=min(readLE32(h+40),(uint32_t)(f.size()-44));
  uint32_t total=audioBytes/2;
  static int16_t mono[256];static int16_t stereo[256*2];
  Serial.printf("PLAYING:%s\n",path);
  for(uint32_t pos=0;pos<total && !stopPlaybackRequested;) {
    uint32_t count=min((uint32_t)256,total-pos);
    size_t got=f.read((uint8_t*)mono,count*2)/2;
    if(!got)break;
    for(uint32_t i=0;i<got;i++) {
      uint32_t index=pos+i;
      float env=fminf(1.0f,index/(AUDIO_RATE*0.05f));
      env*=fminf(1.0f,(total-1-index)/(AUDIO_RATE*0.05f));
      int16_t s=(int16_t)(mono[i]*REPLAY_GAIN*env);
      stereo[2*i]=s;stereo[2*i+1]=s;
    }
    audioBlock(stereo,got);pos+=got;
  }
  f.close();audioSilence();audioSilence();
  Serial.println("PLAYBACK DONE");
}
void speakerTask(void *arg) {
  for(;;) {
    uint8_t cue=0;bool play=false;char path[24]="";
    portENTER_CRITICAL(&audioMux);
    cue=pendingCue;pendingCue=0;
    if(playRequested) {
      playRequested=false;play=true;
      memcpy(path,playRequestPath,sizeof(path));
      stopPlaybackRequested=false;
    }
    portEXIT_CRITICAL(&audioMux);
    if(cue)playCueNow(cue);
    if(play) {
      playbackActive=true;
      playLatestWAV(path);
      playbackActive=false;
    }
    audioSilence();  // I2S.write feeds clocks continuously
  }
}
void requestPlayback() {
  if(!ampOK || !sdOK || recording || state!=0 || playbackActive || latestPath[0]=='\0') {
    Serial.println("PLAY NOT AVAILABLE (needs saved memory / CLOSED)");return;
  }
  portENTER_CRITICAL(&audioMux);
  strncpy(playRequestPath,latestPath,sizeof(playRequestPath)-1);
  playRequestPath[sizeof(playRequestPath)-1]='\0';
  playRequested=true;
  portEXIT_CRITICAL(&audioMux);
  Serial.println("PLAY REQUESTED");
}

// ------------------------ INTERACTION ------------------------
void enterArchiving() {
  if(state!=2)return;
  finishRecording();               // save first, then play cue
  setServoTargets(false);         // return from +20deg to center
  setState(3);
  queueCue(CUE_ARCHIVE);
}
void shortTouch() {
  touchCount++;
  if(state==0) {
    stopPlaybackRequested=true;
    portENTER_CRITICAL(&audioMux);playRequested=false;portEXIT_CRITICAL(&audioMux);
    setServoTargets(true);       // opening
    setState(1);
    queueCue(CUE_WAKE);
  } else if(state==2) {
    enterArchiving();
  }
}
void updateTouch() {
  bool raw=digitalRead(TOUCH_PIN)==HIGH;
  uint32_t now=millis();
  if(raw!=touchRawPrevious) {touchRawPrevious=raw;touchEdgeAt=now;}
  if(now-touchEdgeAt>=TOUCH_DEBOUNCE_MS && raw!=touchStable) {
    touchStable=raw;
    if(touchStable) {touchPressedAt=now;touchLongHandled=false;}
    else if(!touchLongHandled)shortTouch();
  }
  if(touchStable && !touchLongHandled && state==0 &&
     now-touchPressedAt>=LONG_PRESS_MS) {
    touchLongHandled=true;requestPlayback();
  }
}
void updateState() {
  uint32_t elapsed=millis()-stateStarted;
  if(state==1 && elapsed>=WAKING_MS) {
    setState(2);
    if(!startRecording()) {
      setServoTargets(false);setState(3);queueCue(CUE_ARCHIVE);
    }
  } else if(state==2 && recording && millis()-recordingStarted>=MAX_RECORD_MS) {
    Serial.println("90 SECOND LIMIT: ARCHIVING");enterArchiving();
  } else if(state==3 && elapsed>=ARCHIVING_MS) {
    setState(0);queueCue(CUE_CLOSED);
  }
}
void commands() {
  while(Serial.available()) {
    char c=(char)Serial.read();
    if(c=='\r'||c=='\n')continue;
    if(c=='w')shortTouch();
    else if(c=='s')enterArchiving();
    else if(c=='p')requestPlayback();
    else if(c=='t')queueCue(CUE_WAKE);  // diagnostic chime without interaction
    else if(c=='x')stopServoPWM();
    else if(c=='v') {
      Serial.printf("STATE:%u SD:%u AMP:%u RECORD:%u ERROR:%lu AUDIO_ERRORS:%lu\n",
        state,sdOK,ampOK,recording,(unsigned long)errors,(unsigned long)audioWriteErrors);
      Serial.printf("SERVO SWEEP: nominal 5-175 deg (%u-%u us), outputs:%s\n",SERVO_CLOSED_US,SERVO_OPEN_US,servoStopped?"OFF":"ON");
    } else if(c=='?') {
      Serial.println("w touch | s archive | p playback | t sound test | x servo PWM off | v status");
      Serial.println("Short touch/release -> start or archive; long hold in CLOSED -> replay.");
    }
  }
}

void setup() {
  Serial.begin(115200);delay(700);
  Serial.println("\nA LIVING ARCHIVE - INTEGRATED V3 AUDIO CUES");
  Serial.println("MEMORY CORE V4 LOCKED | NO WIRING CHANGES");
  pinMode(TOUCH_PIN,INPUT);
  touchRawPrevious=digitalRead(TOUCH_PIN)==HIGH;
  touchStable=touchRawPrevious;touchEdgeAt=millis();
  ring.begin();ring.setBrightness(190);ring.clear();ring.show();
  state=0;stateStarted=millis();

  // Keep a hand near the external 5V OFF switch during first test.
  initServos();

  sdSPI.begin(SD_SCK,SD_MISO,SD_MOSI,SD_CS);
  for(int k=0;k<3 && !sdOK;k++) {
    sdOK=SD.begin(SD_CS,sdSPI,4000000);
    if(!sdOK)delay(250);
  }
  Serial.println(sdOK?"SD OK":"SD FAILED");
  if(sdOK) {
    for(uint32_t n=1;n<=9999;n++) {
      char file[24];snprintf(file,sizeof(file),"/MEM%04lu.WAV",(unsigned long)n);
      if(!SD.exists(file))break;
      strncpy(latestPath,file,sizeof(latestPath)-1);
      latestPath[sizeof(latestPath)-1]='\0';
    }
  }

  amp.setPins(AMP_BCLK,AMP_WS,AMP_DATA,-1);
  ampOK=amp.begin(I2S_MODE_STD,AUDIO_RATE,I2S_DATA_BIT_WIDTH_16BIT,I2S_SLOT_MODE_STEREO);
  if(ampOK) {
    BaseType_t task=xTaskCreatePinnedToCore(speakerTask,"memory_speaker",8192,nullptr,2,&speakerTaskHandle,0);
    if(task!=pdPASS) {ampOK=false;errors++;amp.end();}
  }
  Serial.println(ampOK?"SPEAKER READY + DIGITAL SILENCE":"SPEAKER START FAILED");
  Serial.println("STATE:CLOSED | READY");
  Serial.println("Touch briefly and release to WAKING. Touch again while LISTENING to archive.");
  Serial.println("Closed long press 1.4s: playback last WAV. Serial ? = help.");
}
void loop() {
  commands();
  updateTouch();
  updateState();
  updateServos();
  updateLights();
  if(recording)updateRecording();
  delay(1);
}
