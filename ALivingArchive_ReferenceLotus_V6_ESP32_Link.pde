/*
 A LIVING ARCHIVE — REFERENCE LOTUS V6 (PROCESSING 4, JAVA MODE)

 REBUILT from the user's supplied violet/pink point-mesh lotus reference.
 Not a rigid petal fan: 47 broad, overlapping silk-lattice 3D petals.
  • Outer wings span almost the entire width of the screen
  • Four progressively warmer/pinker crowns form a luminous inner cup
  • Delicate, regular particle rows/columns with flexing translucent surfaces

 Controls: 1-4 states | T touch | SPACE auto | F reform | H hide overlay
 P palette | L lower detail | C ESP32 USB | S screenshot | drag orbit
 USB protocol (115200, newline terminated): supports both STATE,CLOSED / VOICE,0.50
 and final ESP32 firmware STATE:CLOSED / STATE:LISTENING,VOICE:0.50,TRACE:...

 Runs standalone without an ESP32. Requires the official Processing Serial
 library only when using the optional ESP32 bridge.

 This code has been syntax checked but NOT rendered on the user's Mac.
*/

import processing.serial.*;
import java.util.ArrayList;

final int CANVAS_W=1280, CANVAS_H=800;
final int PETAL_TOTAL=47;
final float ROOT_Y=160f;

// Shape design [tipX, tipY, halfWidth, depthZ, arc, rootX, rootY, phase, tier].
// NOT a radial fountain: the tip locations are hand-composed as a full flower.
final float[][] DESIGN={
    {-620.000f,-195.000f,141.040f,-210.000f,-20.000f,-8.550f,160.000f,0.000f,0f},
    {-570.000f,-330.000f,169.310f,-210.000f,-20.000f,-6.650f,160.000f,0.760f,0f},
    {-455.000f,-335.000f,150.865f,-210.000f,-20.000f,-4.750f,160.000f,1.520f,0f},
    {-325.000f,-400.000f,153.075f,-210.000f,-20.000f,-2.850f,160.000f,2.280f,0f},
    {-150.000f,-425.000f,167.868f,-210.000f,-20.000f,-0.950f,160.000f,3.040f,0f},
    {30.000f,-415.000f,141.213f,-210.000f,-20.000f,0.950f,160.000f,3.800f,0f},
    {210.000f,-430.000f,170.467f,-210.000f,-20.000f,2.850f,160.000f,4.560f,0f},
    {390.000f,-385.000f,148.781f,-210.000f,-20.000f,4.750f,160.000f,5.320f,0f},
    {530.000f,-310.000f,155.362f,-210.000f,-20.000f,6.650f,160.000f,6.080f,0f},
    {635.000f,-205.000f,166.173f,-210.000f,-20.000f,8.550f,160.000f,6.840f,0f},
    {-660.000f,0.000f,131.200f,-185.000f,26.000f,-8.550f,160.000f,0.000f,0f},
    {-660.000f,135.000f,157.498f,-185.000f,26.000f,-6.650f,160.000f,0.760f,0f},
    {-550.000f,250.000f,140.339f,-185.000f,26.000f,-4.750f,160.000f,1.520f,0f},
    {-350.000f,300.000f,142.395f,-185.000f,26.000f,-2.850f,160.000f,2.280f,0f},
    {-140.000f,310.000f,156.156f,-185.000f,26.000f,-0.950f,160.000f,3.040f,0f},
    {155.000f,315.000f,131.361f,-185.000f,26.000f,0.950f,160.000f,3.800f,0f},
    {360.000f,290.000f,158.574f,-185.000f,26.000f,2.850f,160.000f,4.560f,0f},
    {560.000f,240.000f,138.401f,-185.000f,26.000f,4.750f,160.000f,5.320f,0f},
    {655.000f,100.000f,144.523f,-185.000f,26.000f,6.650f,160.000f,6.080f,0f},
    {670.000f,-20.000f,154.579f,-185.000f,26.000f,8.550f,160.000f,6.840f,0f},
    {-490.000f,-200.000f,102.500f,-75.000f,-25.000f,-8.550f,156.000f,2.100f,1f},
    {-400.000f,-315.000f,123.045f,-75.000f,-25.000f,-6.650f,156.000f,2.860f,1f},
    {-295.000f,-362.000f,109.640f,-75.000f,-25.000f,-4.750f,156.000f,3.620f,1f},
    {-185.000f,-350.000f,111.246f,-75.000f,-25.000f,-2.850f,156.000f,4.380f,1f},
    {-60.000f,-345.000f,121.997f,-75.000f,-25.000f,-0.950f,156.000f,5.140f,1f},
    {70.000f,-355.000f,102.626f,-75.000f,-25.000f,0.950f,156.000f,5.900f,1f},
    {210.000f,-340.000f,123.886f,-75.000f,-25.000f,2.850f,156.000f,6.660f,1f},
    {340.000f,-300.000f,108.126f,-75.000f,-25.000f,4.750f,156.000f,7.420f,1f},
    {455.000f,-235.000f,112.909f,-75.000f,-25.000f,6.650f,156.000f,8.180f,1f},
    {505.000f,-140.000f,120.765f,-75.000f,-25.000f,8.550f,156.000f,8.940f,1f},
    {-295.000f,-170.000f,85.280f,40.000f,-15.000f,-7.600f,152.000f,4.200f,2f},
    {-245.000f,-255.000f,102.374f,40.000f,-15.000f,-5.700f,152.000f,4.960f,2f},
    {-185.000f,-300.000f,91.221f,40.000f,-15.000f,-3.800f,152.000f,5.720f,2f},
    {-105.000f,-310.000f,92.557f,40.000f,-15.000f,-1.900f,152.000f,6.480f,2f},
    {-25.000f,-315.000f,101.502f,40.000f,-15.000f,0.000f,152.000f,7.240f,2f},
    {75.000f,-300.000f,85.384f,40.000f,-15.000f,1.900f,152.000f,8.000f,2f},
    {175.000f,-275.000f,103.073f,40.000f,-15.000f,3.800f,152.000f,8.760f,2f},
    {250.000f,-230.000f,89.960f,40.000f,-15.000f,5.700f,152.000f,9.520f,2f},
    {310.000f,-145.000f,93.940f,40.000f,-15.000f,7.600f,152.000f,10.280f,2f},
    {-168.000f,-92.000f,59.860f,125.000f,-10.000f,-9.100f,148.000f,6.300f,3f},
    {-138.000f,-160.000f,71.858f,125.000f,-10.000f,-6.500f,148.000f,7.060f,3f},
    {-85.000f,-216.000f,64.030f,125.000f,-10.000f,-3.900f,148.000f,7.820f,3f},
    {-25.000f,-238.000f,64.968f,125.000f,-10.000f,-1.300f,148.000f,8.580f,3f},
    {36.000f,-227.000f,71.246f,125.000f,-10.000f,1.300f,148.000f,9.340f,3f},
    {90.000f,-200.000f,59.933f,125.000f,-10.000f,3.900f,148.000f,10.100f,3f},
    {145.000f,-140.000f,72.349f,125.000f,-10.000f,6.500f,148.000f,10.860f,3f},
    {175.000f,-82.000f,63.145f,125.000f,-10.000f,9.100f,148.000f,11.620f,3f}
};

ArrayList<MeshPetal> petals=new ArrayList<MeshPetal>();
ArrayList<MemoryLight> archiveLights=new ArrayList<MemoryLight>();
PImage backdrop;

int mode=2; // CLOSED, WAKING, LISTENING, ARCHIVING
int palette=0;
boolean automatic=false, overlay=true, lowDetail=false, dragging=false;
int nextStep=0, wakeDeadline=-1, archiveDeadline=-1;
int formedAt=0;
float form=0, bloom=1, glow=.80f, gather=1, voice=0, simulatedVoice=.52f;
float orbit=0, tilt=0, orbitAim=0, tiltAim=0;
int archiveCount=0;

Serial esp=null;
final int SERIAL_BAUD=115200;
final String SERIAL_PORT_OVERRIDE="";
float serialVoice=0;
int lastSerialVoice=-100000;
String serialStatus="";
int serialStatusUntil=0;

void setup() {
  size(1280,800,P3D);
  smooth(4);
  frameRate(60);
  surface.setTitle("A Living Archive | Reference Lotus V6");
  colorMode(RGB,255);
  randomSeed(12205);
  createBackdrop();
  buildPetals();
  restartFormation();
}

void draw() {
  float t=millis()*.001f;
  readESP32();
  updateWorld(t);

  hint(DISABLE_DEPTH_TEST);
  image(backdrop,0,0,width,height);
  drawBackgroundLight(t);

  // Orthographic framing: no collapsing into the tall fountain silhouette.
  // Every ring was composed to occupy a predictable screen location.
  ortho(-640,640,-400,400,1,4000);
  camera(0,-25,1400,0,0,0,0,1,0);
  hint(DISABLE_DEPTH_TEST);
  pushMatrix();
  rotateY(orbit + .025f*sin(t*.18f));
  rotateX(tilt-.045f+.018f*sin(t*.25f));
  scale(.94f,.96f,1.0f);

  drawMembranes(t);
  drawParticlePetals(t);
  drawPetalEdgeFilaments(t);
  drawLivingCenter(t);
  drawArchivedMemory(t);
  popMatrix();

  perspective(); // Restore Processing default screen projection for the 2D UI.
  camera();
  noLights();
  drawFrontGlow(t);
  if(overlay) drawOverlay();
}

// Purple stage lighting; deep/near-black at the bottom for projection contrast.
void createBackdrop() {
  backdrop=createImage(CANVAS_W,CANVAS_H,RGB);
  backdrop.loadPixels();
  for(int y=0;y<CANVAS_H;y++) {
    for(int x=0;x<CANVAS_W;x++) {
      float yy=y/(float)CANVAS_H;
      float dx=(x-CANVAS_W*.50f)/(CANVAS_W*.72f);
      float dy=(y-CANVAS_H*.12f)/(CANVAS_H*.79f);
      float haze=exp(-(dx*dx+dy*dy));
      float stage=pow(1.0f-yy,1.25f);
      float violet=exp(-2.5f*(dx*dx+.30f*dy*dy));
      int r=(int)constrain(4+33*haze+24*stage+11*violet,0,255);
      int g=(int)constrain(1+5*haze+2*stage,0,255);
      int b=(int)constrain(17+71*haze+25*stage+9*violet,0,255);
      backdrop.pixels[y*CANVAS_W+x]=color(r,g,b);
    }
  }
  backdrop.updatePixels();
}

// Tier colors: distant blue violet -> lilac -> saturated rose -> pale pink.
float[][] lotusColors={
  {142,98,238}, {180,142,255}, {242,164,248}, {255,183,237}
};

void buildPetals() {
  petals.clear();
  randomSeed(61626);
  for(int i=0;i<DESIGN.length;i++) {
    float[] d=DESIGN[i];
    petals.add(new MeshPetal(d));
  }
}

class MeshDot {
  float x,y,z,u,v,phase;
  float red,green,blue,alpha;
  float scatterX,scatterY,scatterZ;
  MeshDot(float[] pos,float uu,float vv,int tier,float phaseOffset) {
    x=pos[0];y=pos[1];z=pos[2];u=uu;v=vv;
    phase=random(TWO_PI)+phaseOffset*.2f;
    scatterX=randomGaussian()*250;
    scatterY=randomGaussian()*185;
    scatterZ=randomGaussian()*270;
    float edge=pow(abs(v),6);
    float vein=pow(max(0,1-abs(v)),1.4f)*sin(PI*u);
    float pale=pow(1-u,1.9f);
    float[] col=lotusColors[tier];
    float shift=(palette==0 ? 0:1);
    red=constrain(col[0]+18*edge+12*pale+shift*7,0,255);
    green=constrain(col[1]+29*edge+26*pale-shift*5,0,255);
    blue=constrain(col[2]+7*edge-shift*13,0,255);
    // Soft points with luminous folded edges; not a solid white disk.
    float strength=(tier==0 ? 64 : tier==1 ? 76 : tier==2 ? 85 : 93);
    alpha=strength*(.64f+.47f*edge+.23f*vein);
    if(random(1)<.10f) alpha*=.56f;
  }
}

class MeshPetal {
  float tipX,tipY,halfWidth,depth,arch,baseX,baseY,phase;
  int tier,rows,cols;
  MeshDot[] dots;
  MeshPetal(float[] d) {
    tipX=d[0];tipY=d[1];halfWidth=d[2];depth=d[3];arch=d[4];
    baseX=d[5];baseY=d[6];phase=d[7];tier=(int)d[8];
    rows=tier==0?59:tier==1?60:tier==2?60:59;
    cols=tier==0?53:tier==1?55:tier==2?57:55;
    dots=new MeshDot[rows*cols];
    int index=0;
    for(int row=0;row<rows;row++) {
      float u=.033f+.955f*row/(rows-1.0f);
      for(int col=0;col<cols;col++) {
        float v=-.992f+1.984f*col/(cols-1.0f);
        // Preserve a VISIBLE lattice. Only tiny irregularities, not random dust.
        float uu=constrain(u+random(-.0018f,.0018f),.02f,.99f);
        float vv=constrain(v+random(-.0025f,.0025f),-.999f,.999f);
        float[] xyz=surfacePoint(this,uu,vv,0);
        dots[index++]=new MeshDot(xyz,uu,vv,tier,phase);
      }
    }
  }
}

// A REAL spatial surface: broad ribbon, cup, side-curled edge, curled tip.
// Reused both for static lattice coordinates and ultra-fine contour curves.
float[] surfacePoint(MeshPetal p,float u,float v,float t) {
  float dx=p.tipX-p.baseX,dy=p.tipY-p.baseY;
  float len=sqrt(dx*dx+dy*dy);
  float px=-dy/len,py=dx/len;
  float s=pow(max(.0001f,sin(PI*u)),.70f);
  float centerX=p.baseX+dx*u+24*(p.tipX>=0?1:-1)*sin(PI*u)*(p.tier<2?.60f:.34f);
  float centerY=p.baseY+dy*u+p.arch*sin(PI*u);
  float width=p.halfWidth*s*(.65f+.48f*u);
  float wave=9*sin(u*6.2f+v*3.8f+p.phase+t*.62f)*s*u;
  float x=centerX+px*(v*width+wave);
  float y=centerY+py*(v*width+wave*.48f);
  float z=p.depth+64*(1-v*v)*s-36*pow(abs(v),1.8f)*s
    +(18+9*p.tier)*sin(u*4.8f+v*4.2f+p.phase+t*.43f)*u*s
    +38*pow(u,3)*cos(v*2.9f+p.phase*.5f);
  return new float[]{x,y,z};
}

float smooth01(float value) {
  float a=constrain(value,0,1);
  return a*a*(3-2*a);
}

float opennessScale() {
  return .58f + .42f*constrain(bloom,0,1.20f);
}

float foldLift() {
  return constrain(1.0f-bloom,-0.22f,.90f);
}

// Dynamic motion is intentionally gentle so the flower stays recognizable.
// No huge +/- 90 degree rotations of every petal.
void dynamicCoord(MeshDot d,float t) {
  float folded=foldLift();
  float openScale=opennessScale();
  float movement=sin(t*.47f+d.phase);
  float sway=movement*(.9f+3.0f*d.u*d.u);
  float x=d.x*openScale+sway;
  float y=d.y+folded*(180-d.y)*.56f+movement*1.7f*d.u;
  float z=d.z+movement*(3.5f+1.4f*bloom)*d.u*d.u;
  renderWave=movement;
  float scatter=constrain((1-form)+(1-gather)*0.95f,0,1.55f);
  renderX=x+scatter*d.scatterX;
  renderY=y+scatter*d.scatterY;
  renderZ=z+scatter*d.scatterZ;
}
float renderX,renderY,renderZ,renderWave;

void drawMembranes(float t) {
  if(form<.5f) return;
  pushStyle();
  noStroke();
  blendMode(BLEND);
  float formAlpha=smooth01((form-.50f)/.50f);
  for(MeshPetal p:petals) {
    // Use exceptionally thin translucent surfaces so grid points remain visible.
    float baseA=(p.tier==0 ? 3.1f : p.tier==1 ? 4.4f : p.tier==2 ? 7.2f : 9.8f);
    for(int r=0;r<22;r++) {
      int row1=(int)(r*(p.rows-1)/22.0f);
      int row2=(int)((r+1)*(p.rows-1)/22.0f);
      beginShape(TRIANGLE_STRIP);
      for(int k=0;k<=13;k++) {
        int col=(int)(k*(p.cols-1)/13.0f);
        float v=-1+2*k/13.0f;
        float center=.72f+.28f*(1-abs(v));
        float[] colorRGB=lotusColors[p.tier];
        fill(colorRGB[0],colorRGB[1],colorRGB[2],baseA*formAlpha*center);
        MeshDot a=p.dots[row1*p.cols+col];
        vertex(a.x*opennessScale(),a.y+foldLift()*(180-a.y)*.56f,a.z);
        MeshDot b=p.dots[row2*p.cols+col];
        vertex(b.x*opennessScale(),b.y+foldLift()*(180-b.y)*.56f,b.z);
      }
      endShape();
    }
  }
  popStyle();
}

void drawParticlePetals(float t) {
  pushStyle();
  hint(DISABLE_DEPTH_TEST);
  blendMode(ADD);
  int stride=lowDetail?3:1;
  float f=smooth01(form);
  for(MeshPetal p:petals) {
    strokeWeight(p.tier==0?1.18f:p.tier==1?1.28f:p.tier==2?1.40f:1.46f);
    beginShape(POINTS);
    for(int j=0;j<p.dots.length;j+=stride) {
      MeshDot d=p.dots[j];
      dynamicCoord(d,t);
      float twinkle=.88f+.12f*renderWave;
      float alpha=d.alpha*(.36f+.64f*glow)*(.12f+.88f*f)*twinkle;
      // The brighter inner cup is deliberately pink, not pure white.
      stroke(d.red,d.green,d.blue,constrain(alpha,0,155));
      vertex(renderX,renderY,renderZ);
    }
    endShape();
  }
  blendMode(BLEND);
  popStyle();
}

void drawPetalEdgeFilaments(float t) {
  if(form<.58f)return;
  pushStyle();
  blendMode(ADD);
  noFill();
  float fade=smooth01((form-.58f)/.42f)*(.65f+.25f*glow);
  for(MeshPetal p:petals) {
    if(p.tier==0 && lowDetail)continue;
    strokeWeight(.55f);
    for(int side=-1;side<=1;side+=2) {
      stroke(p.tier>=2 ? color(255,205,245,19*fade):color(205,185,255,13*fade));
      beginShape();
      for(int i=1;i<46;i++) {
        float[] a=surfacePoint(p,i/46.0f,side*.985f,t);
        vertex(a[0]*opennessScale(),a[1]+foldLift()*(180-a[1])*.56f,a[2]);
      }
      endShape();
    }
    // One central longitudinal silk fold, not a hard neon contour.
    if(p.tier>=2) {
      stroke(255,193,251,17*fade);
      beginShape();
      for(int i=2;i<46;i++) {
        float[] a=surfacePoint(p,i/46.0f,0,t);
        vertex(a[0]*opennessScale(),a[1]+foldLift()*(180-a[1])*.56f,a[2]+1);
      }
      endShape();
    }
  }
  popStyle();
}

// Several soft cup filaments fill the throat, NOT a solid white starburst.
void drawLivingCenter(float t) {
  if(form<.25f)return;
  pushStyle();
  blendMode(ADD);
  noFill();
  float scaleAlpha=smooth01(form)*(.42f+.55f*glow);
  for(int i=0;i<32;i++) {
    float a=i*2.399963f;
    float h=66+(i%7)*11;
    strokeWeight(.75f);
    stroke(255,185,250,37*scaleAlpha);
    beginShape();
    for(int j=0;j<=18;j++) {
      float u=j/18.0f;
      float radius=8+u*u*(32+(i%5)*5);
      float x=cos(a)*radius+8*u*u*sin(t*.34f+i);
      float y=155-u*h;
      float z=125+sin(a)*radius;
      vertex(x,y,z);
    }
    endShape();
    strokeWeight(1.6f);
    stroke(255,224,250,80*scaleAlpha);
    float rr=40+(i%5)*5;
    point(cos(a)*rr,155-h,125+sin(a)*rr);
  }
  popStyle();
}

void drawBackgroundLight(float t) {
  pushStyle();
  blendMode(ADD);
  noStroke();
  for(int i=11;i>=1;i--) {
    float ratio=i/11.0f;
    fill(144,39,205,(2.2f-ratio*1.1f)*(.22f+.40f*glow));
    ellipse(width*.5f+15*sin(t*.15f),height*.41f,width*(.23f+.44f*ratio),height*(.25f+.34f*ratio));
  }
  blendMode(BLEND);
  popStyle();
}

void drawFrontGlow(float t) {
  pushStyle();
  noStroke();
  blendMode(ADD);
  for(int i=12;i>=1;i--) {
    float ratio=i/12.0f;
    fill(255,115,235,(1.85f-ratio*.95f)*(.2f+.70f*glow)*form);
    ellipse(width*.5f,height*.5f+150,width*(.04f+.17f*ratio),height*(.03f+.11f*ratio));
  }
  blendMode(BLEND);
  popStyle();
}

class MemoryLight {
  float x,y,z,phase;
  MemoryLight() {
    float a=random(TWO_PI),r=random(340,600);
    x=cos(a)*r;
    y=140+sin(a)*r*.48f;
    z=random(-180,220);
    phase=random(TWO_PI);
  }
}

void drawArchivedMemory(float t) {
  if(archiveLights.size()==0)return;
  pushStyle();
  blendMode(ADD);
  strokeWeight(1.55f);
  beginShape(POINTS);
  for(MemoryLight m:archiveLights) {
    stroke(246,189,255,(37+16*sin(t*.55f+m.phase))*(mode==3?1.35f:1.0f)*(.36f+.64f*glow));
    vertex(m.x+3*sin(t*.16f+m.phase),m.y,m.z);
  }
  endShape();
  popStyle();
}

void setMode(int next) {
  next=constrain(next,0,3);
  if(next==mode)return;
  mode=next;
  if(mode==3) {
    archiveCount++;
    for(int i=0;i<70;i++)archiveLights.add(new MemoryLight());
    while(archiveLights.size()>320)archiveLights.remove(0);
  }
}

void touchFlower() {
  automatic=false;
  wakeDeadline=-1;
  archiveDeadline=-1;
  if(mode==0||mode==3){setMode(1);wakeDeadline=millis()+2300;}
  else if(mode==1){setMode(2);}
  else {setMode(3);archiveDeadline=millis()+6500;}
}

void restartFormation() {formedAt=millis();form=0;}

void updateWorld(float t) {
  if(automatic && millis()>=nextStep) {
    setMode((mode+1)%4);
    nextStep=millis()+(mode==2?18000:mode==1?5500:mode==3?8500:8000);
  }
  if(!automatic && wakeDeadline>0 && millis()>=wakeDeadline){wakeDeadline=-1;if(mode==1)setMode(2);}
  if(!automatic && archiveDeadline>0 && millis()>=archiveDeadline){archiveDeadline=-1;if(mode==3)setMode(0);}

  float desiredVoice=0;
  if(mode==2) {
    if(esp!=null) {
      if(millis()-lastSerialVoice<3000)desiredVoice=serialVoice;
    } else {
      float phrase=pow(max(0,(sin(t*.51f+.4f)+1)*.5f),2);
      desiredVoice=simulatedVoice*(.10f+.90f*phrase*abs(sin(t*2.65f)));
    }
  }
  voice=lerp(voice,desiredVoice,.11f);
  float targetBloom=(mode==0?.08f:mode==1?.50f:mode==2?1.12f:.28f);
  if(mode==2)targetBloom+=.040f*sin(t*.42f)+.12f*voice;
  bloom=lerp(bloom,targetBloom,.040f);
  float targetGlow=(mode==0?.07f:mode==1?.34f:mode==2?1.02f+.28f*voice:.18f);
  glow=lerp(glow,targetGlow,.060f);
  float targetGather=(mode==0?.56f:mode==1?.78f:mode==2?1.0f:.66f);
  gather=lerp(gather,targetGather,.050f);

  float elapsed=(millis()-formedAt)*.001f;
  float baseForm=smooth01((elapsed-.08f)/4.0f);
  float targetForm=baseForm*(mode==0?.74f:mode==1?.88f:mode==2?1.0f:.80f);
  form=lerp(form,targetForm,.082f);

  if(!dragging) {
    orbitAim=.055f*sin(t*.13f);
    tiltAim=.023f*sin(t*.11f);
  }
  orbit=lerp(orbit,orbitAim,.045f);
  tilt=lerp(tilt,tiltAim,.045f);
}

void connectESP32() {
  if(esp!=null) {
    try{esp.stop();}catch(Exception e){}
    esp=null;serialStatus="ESP32 disconnected";serialStatusUntil=millis()+5000;return;
  }
  String chosen=SERIAL_PORT_OVERRIDE.trim();
  String[] ports=Serial.list();
  println("Serial ports available:");printArray(ports);
  if(chosen.length()==0) {
    for(String p:ports) {
      String low=p.toLowerCase();
      if(low.indexOf("/dev/cu.")>=0 && (low.indexOf("usbmodem")>=0||low.indexOf("usbserial")>=0)) {
        chosen=p;break;
      }
    }
  }
  if(chosen.length()==0) {serialStatus="ESP32 port not found";serialStatusUntil=millis()+5000;return;}
  try {
    esp=new Serial(this,chosen,SERIAL_BAUD);
    esp.clear();automatic=false;
    wakeDeadline=-1;archiveDeadline=-1;
    serialVoice=0;lastSerialVoice=-100000;
    setMode(0); // ESP32 generally starts in CLOSED; next STATE line is authoritative
    serialStatus="ESP32 connected: "+chosen;serialStatusUntil=millis()+5000;
  }catch(Exception e) {esp=null;serialStatus="USB error: "+e.getMessage();serialStatusUntil=millis()+5000;}
}

void readESP32() {
  if(esp==null)return;
  try {
    for(int i=0;i<24 && esp.available()>0;i++) {
      String line=esp.readStringUntil('\n');
      if(line==null)break;
      parseESP32(trim(line));
    }
  } catch(Exception e) {
    try{esp.stop();}catch(Exception ignored){}
    esp=null;serialStatus="USB disconnected";serialStatusUntil=millis()+5000;
  }
}

void parseESP32(String line) {
  if(line==null || line.length()==0)return;
  String upper=trim(line).toUpperCase();

  // Final ESP32 V3 Servo170 writes STATE:WAKING and, during recording,
  // STATE:LISTENING,VOICE:0.42,TRACE:65.0,MEMORY:10,RMS16:....
  // The visual mode follows the ESP32's reported state, not a guessed timer.
  if(upper.startsWith("STATE:")) {
    String value=upper.substring(6).trim();
    int received=-1;
    if(value.startsWith("CLOSED")) received=0;
    else if(value.startsWith("WAKING")) received=1;
    else if(value.startsWith("LISTENING")) received=2;
    else if(value.startsWith("ARCHIVING")) received=3;
    if(received>=0) {
      automatic=false;
      wakeDeadline=-1;
      archiveDeadline=-1;
      setMode(received);
    }
  }

  // Voice may be embedded in the same STATE line (not a separate message).
  // V3 currently transmits it about every 2 seconds; a 3-second hold
  // avoids dropping to zero between reports.
  int voiceAt=upper.indexOf("VOICE:");
  if(voiceAt>=0) {
    String number=upper.substring(voiceAt+6);
    int comma=number.indexOf(',');
    if(comma>=0)number=number.substring(0,comma);
    number=trim(number);
    float value=parseFloat(number);
    if(!Float.isNaN(value) && !Float.isInfinite(value)) {
      serialVoice=constrain(value,0,1);
      lastSerialVoice=millis();
    }
  }

  // Retain support for the sketch's original comma-separated test protocol.
  String[] parts=split(line,',');
  String cmd=trim(parts[0]).toUpperCase();
  if(cmd.equals("VOICE") && parts.length>=2) {
    float val=parseFloat(trim(parts[1]));
    if(!Float.isNaN(val)&&!Float.isInfinite(val)) {
      serialVoice=constrain(val,0,1);
      lastSerialVoice=millis();
    }
  } else if(cmd.equals("STATE") && parts.length>=2) {
    automatic=false;wakeDeadline=-1;archiveDeadline=-1;
    String received=trim(parts[1]).toUpperCase();
    if(received.equals("CLOSED"))setMode(0);
    else if(received.equals("WAKING"))setMode(1);
    else if(received.equals("LISTENING"))setMode(2);
    else if(received.equals("ARCHIVING"))setMode(3);
  } else if(cmd.equals("TOUCH") && parts.length>=2 && trim(parts[1]).equals("1")) {
    touchFlower();
  } else if(cmd.equals("ARCHIVE")) {
    automatic=false;setMode(3);
  }
}

void drawOverlay() {
  pushStyle();
  textAlign(LEFT,TOP);
  textSize(12);
  fill(247,218,255,177);
  String[] names={"CLOSED","WAKING","LISTENING","ARCHIVING"};
  text("A LIVING ARCHIVE  /  REFERENCE LOTUS V6",24,22);
  fill(240,203,255,134);
  text(names[mode]+"  /  "+(automatic?"AUTO":"INTERACTIVE")+"  /  VOICE "+nf(voice,1,2)+"  /  "+(esp==null?"USB OFF":"ESP32 ON"),24,43);
  if(millis()<serialStatusUntil) {fill(255,229,251,181);text(serialStatus,24,66);}
  fill(242,208,255,112);
  text("1–4 STATES    T TOUCH    SPACE AUTO    F REFORM    H HIDE    L QUALITY    C USB",24,height-25);
  popStyle();
}

void keyPressed() {
  if(key>='1'&&key<='4') {
    automatic=false;wakeDeadline=-1;archiveDeadline=-1;
    setMode((int)(key-'1'));
  } else if(key=='t'||key=='T')touchFlower();
  else if(key==' ') {automatic=!automatic;if(automatic)nextStep=millis()+8000;}
  else if(key=='f'||key=='F')restartFormation();
  else if(key=='h'||key=='H')overlay=!overlay;
  else if(key=='p'||key=='P') {palette=1-palette;buildPetals();}
  else if(key=='l'||key=='L')lowDetail=!lowDetail;
  else if(key=='c'||key=='C')connectESP32();
  else if(key=='s'||key=='S')saveFrame("reference-lotus-v6-####.png");
  else if(key==CODED) {
    if(keyCode==UP)simulatedVoice=min(1,simulatedVoice+.07f);
    if(keyCode==DOWN)simulatedVoice=max(0,simulatedVoice-.07f);
  }
}

void mousePressed(){dragging=true;}
void mouseDragged() {
  if(!dragging)return;
  orbitAim=constrain(orbitAim+(mouseX-pmouseX)*.0028f,-.27f,.27f);
  tiltAim=constrain(tiltAim+(mouseY-pmouseY)*.0019f,-.20f,.20f);
}
void mouseReleased(){dragging=false;}
