// Author: Pawel Zabinski
// Latest Edit: 26/02/2024

#include <NewPing.h>
#include <LiquidCrystal.h>
#include "RunningMedian.h"
#include "ModeButton.h"

#define TRIGGER_PIN  12
#define ECHO_PIN     11
#define MAX_DISTANCE 300
#define MEASUREMENT_INTERVAL 100
#define DISTANCE_SAMPLES 5
#define SPEED_SAMPLES 3

// The speed of sound in room temperature air is 346 m/s
// 346 m/s = 0.0346 cm/μs ≈ 29 μs/cm
#define SOUND_SPEED_MULTIPLIER 29

#define BLACK_BTN_PIN 8 // Top button
#define RED_BTN_PIN 9 // Bottom button

#define STANDARD_MODE 0
#define PLOT_MODE 1
#define CALIBRATION_MODE 2

// There is a pull-up resistor (4.7kΩ) in these buttons; LOW signifies pressed, HIGH signifies not pressed
ModeButton blackBtn(BLACK_BTN_PIN, CALIBRATION_MODE);
ModeButton redBtn(RED_BTN_PIN, PLOT_MODE);

NewPing sonar(TRIGGER_PIN, ECHO_PIN, MAX_DISTANCE);
LiquidCrystal lcd(7,6,5,4,3,2); // Initialise the LCD library
RunningMedian speeds = RunningMedian(SPEED_SAMPLES); // RunningMedian library helps to easily add new samples every iteration and calculates a running average median which automatically rejects anomalies

// Tracks the current mode, alternates between Standard (shows normal speed), Plot mode (plots graphs of distance and speed in SerialPlotter), and Calibration mode (calibrates readings from ultrasonic sensor for higher accuracy)
int mode = STANDARD_MODE;

// Previous distance and time used in speed calculations
float previousDistance = 0;
long previousTime = 0;

const int calibrationCount = 5;
const float calibrationDistances[calibrationCount] = { 5, 10, 25, 50, 80 };
float calibrationFactors[calibrationCount] = {};

void setup() {
  // Set up button pins as input pins ready to digitalRead(_:) 
  pinMode(BLACK_BTN_PIN, INPUT);
  pinMode(RED_BTN_PIN, INPUT);

  // HIGH refers to buttons not being pressed down. LOW refers to buttons being pressed down.
  digitalWrite(BLACK_BTN_PIN, HIGH);
  digitalWrite(RED_BTN_PIN, HIGH);

  Serial.begin(9600);
  lcd.begin(16, 2);     // Set up the LCD's number of columns and rows
}

void loop() {
  blackBtn.check();
  redBtn.check();

  // Take readings to calibrate the ultrasonic sensor
  if (mode == CALIBRATION_MODE) {
    calibrationMode();

    return;
  }

  // Use ping_median to get the median distance directly
  float medianDistance = pingDistance();

  long currentTime = millis();

  if (medianDistance > 0) {
    float timeInterval = (currentTime - previousTime) / 1000.0;
    speeds.add((medianDistance - previousDistance) / timeInterval);

    // abs(speeds.getMedianAverage(3));
    float medianSpeed = speeds.getMedianAverage(3);

    if (mode == PLOT_MODE)
      plotMode(medianDistance, medianSpeed, currentTime);
    else if (mode == STANDARD_MODE) {
      standardMode(medianSpeed);
    }

    previousDistance = medianDistance;
    previousTime = currentTime;
  }

  delay(MEASUREMENT_INTERVAL);
}

/*
 - Separate functions for different modes which can be alternated using the black and red buttons
*/
void standardMode(float medianSpeed) {
  displaySpeed(medianSpeed);
  displayMode("Standard");
}

void plotMode(float medianDistance, float medianSpeed, long elapsedTime) {
  displayMode("Plot");

  Serial.print("<");
  Serial.print(medianDistance);
  Serial.print("  ");
  Serial.print(medianSpeed);
  Serial.print("  ");
  Serial.print(elapsedTime);
  Serial.println(">");
}

// Black and red button functionality will be overwritten here to act as forward/backward steps in calibration mode
// Black (top) - Restart calibration process
// Red (bottom) - Take calibration values, and move to next value (or move to standard mode)
// Assume the differences in ultrasonic sensors are a constant term at some values
void calibrationMode() {
  const int calibrationReadings = 5; // 5 calibration readings for each value (reduce effect of anomalies)

  int step = 0; // Index of calibration values to act as a progress of the calibration process

  while (step < calibrationCount) {
    float totalDeviation = 0;

    float val = calibrationDistances[step];

    displayMode("Calibration");
    displayCalibrationDistance(val);

    // If the black button is being pressed, then restart calibration process
    if (blackBtn.isPressed()) {
      step = 0;
      continue;
    }

    // If the red button is being pressed, then take the readings and proceed
    if (redBtn.isPressed()) {
      for (int i = 0; i < calibrationReadings; i++) {
        float distance = pingDistance();

        totalDeviation += (val - distance); // val is the known reference distance

        delay(MEASUREMENT_INTERVAL);
      }

      calibrationFactors[step] = totalDeviation / calibrationReadings;
      step += 1;
    }
  }

  lcd.clear();
  lcd.setCursor(0, 1);
  lcd.print("Calibration done");
  
  delay(2000); // Display calibration done message for 2 seconds
  mode = STANDARD_MODE; // Go back to standard mode after calibration
}

/*
 - ModeButton - abstracts button logic, initialiser takes two inputs PIN and the BUTTON MODE
*/
ModeButton::ModeButton(int p, int m) : pin(p), btnMode(m) {};

// If the button is pressed and if not locked, toggle the mode, but also lock it (to prevent multiple function calls within same button press request)
// If the button is locked and the button is not being pressed, then unlock it (to allow the user to press it again to toggle mode)
// If the mode is toggled, return true, else return false
bool ModeButton::check() {
  if (isPressed()) {
    if (!isLocked) {
      toggleMode();
      isLocked = true;

      return true;
    }
  } else if (isLocked)
    isLocked = false;
  
  return false;
}

// Checks if button is currently pressed down (LOW pressed down, HIGH not pressed down)
bool ModeButton::isPressed() const {
  return digitalRead(pin) == LOW;
}

// Toggles between button-defined mode and standard
void ModeButton::toggleMode() {
  lcd.clear();
  // global mode variable must be defined before
  mode = btnMode == mode ? STANDARD_MODE : btnMode;    
}

/*
 -  Helper functions
*/

// Returns the index of the value which is closest to the target value
int closestIndex(int valuesLength, float values[], float val) {
  if (valuesLength == 0) return -1;
  else if (valuesLength == 1) return 0;

  int closestIndex = 0;
  float closestDistance = abs(val - values[0]);

  for (int i = 1; i < valuesLength; i++) {
    float distance = abs(val - values[i]);
    
    if (distance < closestDistance) {
      closestDistance = distance;
      closestIndex = i;
    }
  }
  
  return closestIndex;
}

float pingDistance() {
  // fetch the raw microseconds elapsed time from sensor readings to calculate distance using own multiplier for speed of sound
  float microseconds = sonar.ping_median(DISTANCE_SAMPLES);
  float distance = microseconds / (2 * SOUND_SPEED_MULTIPLIER);

  // uses the closest calibration factor to the chosen distance from previously set calibration data, i.e distance of 43cm would use calibration factor for 50cm
  float calibrationFactor = calibrationFactors[closestIndex(calibrationCount, calibrationDistances, distance)];

  // The calibration factor is the constant term that is added to the raw distance
  // This has experimentally been found to be the most efficient and accurate calibration technique
  return distance + calibrationFactor;
}

void displaySpeed(float speed) {
  lcd.setCursor(0, 0);
  lcd.print("Speed: ");
  lcd.print(speed);
  lcd.print(" cm/s");
}

void displayCalibrationDistance(int distance) {
  lcd.setCursor(0, 0);
  lcd.print(distance);
  lcd.print(" cm");
}

void displayMode(char mode[]) {
  lcd.setCursor(0, 1);
  lcd.print(mode);
}
