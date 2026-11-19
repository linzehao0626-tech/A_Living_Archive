# A_Living_Archive: The Shape of Remembering
An interactive robotic flower for personal memory sharing and archiving - Final Project

**MSc Creative Robotics | University of the Arts London**

**Author:** Zehao Lin

## Project Overview

*A Living Archive: The Shape of Remembering* is an interactive robotic flower designed to explore the relationship between personal memories, physical interaction, and emotional connection.

Rather than functioning solely as a digital recording device, the installation allows users to share and preserve personal memories through touch, movement, light, and sound.

The project investigates how users' emotional connection to an interactive object may change through repeated memory sharing.

## Interaction Design

The installation follows four interaction states:

1. **Closed** — The flower rests with a soft amber breathing light.
2. **Waking** — Touch activates the flower, triggering petal movement and warm pink lighting.
3. **Listening** — The flower records the user's spoken memory while displaying gentle purple lighting.
4. **Archiving** — A second touch ends the recording, triggering petal movement and a gradual lighting transition.

Recorded memories are saved as WAV audio files on a MicroSD card.

## Hardware

The physical installation includes:

- ESP32-S3 microcontroller
- Five MG90S servo motors
- WS2812B 16-pixel LED ring
- TTP223 capacitive touch sensor
- INMP441 digital microphone
- MAX98357A audio amplifier and speaker
- MicroSD storage module
- Handmade organza petals and mechanical framework

## Software and Visualisation

The physical system is programmed using Arduino and communicates with a Processing-based visualisation.

Processing displays a three-dimensional particle flower with layered pink and purple colours. The digital flower responds to interaction state changes received from the ESP32-S3 through serial communication.

The movements, lighting, and visual effects follow programmed interaction states rather than analysing the emotional content of recorded memories.

## Repository Files

- **A_Living_Archive_Integrated.ino** — ESP32-S3 code for touch interaction, servo movement, LED lighting, audio recording, and playback.
- **ALivingArchive_Visualization_Processing.pde** — Processing code for the interactive digital flower visualisation.

## Research

An exploratory repeated-use study involved six participants. Five completed five days of interaction, while one completed three days.

Daily questionnaires and final interviews explored emotional connection, familiarity, comfort in sharing memories, and perceived responsiveness.

The study examines participants' reported experiences without claiming that repeated interaction directly causes emotional connection.

## Privacy

Personal voice recordings collected during user testing are not included in this public repository.

## Project Information

This project was developed as part of the MSc Creative Robotics programme at the Creative Computing Institute, University of the Arts London.
