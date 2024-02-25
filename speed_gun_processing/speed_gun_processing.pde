// Author: Pawel Zabinski
// Last updated: 25/02/2024

import org.gicentre.utils.stat.*;
import processing.serial.*;
import controlP5.*;

XYChart lineChart;
ControlP5 cp5;
Button pauseButton;

//: /dev/cu.usbmodem1101 -> /dev/cu.usbmodem1401 
Serial port;
String portName = "/dev/cu.usbmodem1101";

String[] latestData;     // (distance, speed, time_elapsed)

// Returns the latest distance value if available, otherwise returns 0.
float latestDistance() { 
  if (latestData != null && latestData.length == 3)
    return parseFloat(latestData[0]); 
  
  return 0;
}

// Returns the latest speed value if available, otherwise returns 0.
float latestSpeed() {
  if (latestData != null && latestData.length == 3)
    return parseFloat(latestData[1]);
    
  return 0;
}

// Returns the latest time elapsed value if available, otherwise returns 0.
int latestTimeElapsed() { 
  if (latestData != null && latestData.length == 3)
    return parseInt(latestData[2]); 
    
  return 0;
}

Table table;
boolean isPaused = false;
int startTime = 0;

ArrayList<Float> distanceData = new ArrayList();
ArrayList<Float> speedData = new ArrayList();
ArrayList<Integer> timeData = new ArrayList();

void setup() {
  size(500, 500);
  
  port = new Serial(this, portName, 9600);
  cp5 = new ControlP5(this);
  lineChart = new XYChart(this);
  
  lineChart.showXAxis(true); 
  lineChart.showYAxis(true); 
  
  lineChart.setXAxisLabel("\nTime / ms");
  lineChart.setYAxisLabel("Distance / cm\n");
  
  lineChart.setXFormat("#");
  
  lineChart.setPointColour(color(180,50,50,100));
  lineChart.setPointSize(5);
  lineChart.setLineWidth(2);
  
  table = new Table();
  table.addColumn("Time");
  table.addColumn("Distance");
  table.addColumn("Speed");
  
  pauseButton = cp5.addButton("togglePause")
     .setPosition(15, 30)
     .setSize(100, 30)
     .setLabel("Pause");
  
  cp5.addButton("exportData")
    .setPosition(130, 30)
    .setSize(100, 30)
    .setLabel("Export");
  
  cp5.addButton("resetData")
    .setPosition(245, 30)
    .setSize(100, 30)
    .setLabel("Reset");
}

void draw() {
  // Handle data collection based on pause state and clear serial port if paused.
  if (isPaused)
    clearPort();
  else
    handleSerialData();
  
  background(255);
  fill(0);
  
  lineChart.draw(30, 75, 455, 400);
  
  text("Distance: " + latestDistance(), 15, 15);
  text("Speed: " + latestSpeed(), 115, 15);
  text("Time: " + latestTimeElapsed(), 215, 15);
}

// Function to save the collected data to a CSV file.
public void exportData() {
  saveTable(table, "data/measurements.csv");
}

// Function to reset collected data and clear the chart.
public void resetData() {
  distanceData = new ArrayList();
  speedData = new ArrayList();
  timeData = new ArrayList();
  
  table.clearRows();
  
  updateLineChart();
}

// Function to toggle the pause state and update the button label.
public void togglePause() {
  isPaused = !isPaused;
  
  pauseButton.setLabel(isPaused ? "Resume" : "Pause");
}

// Reads data from the serial port, validates it, and updates the latest data.
void handleSerialData() {
  if (port.available() > 0) {  
    String incomingData = port.readStringUntil('\n');
    
    if (incomingData != null) {
      incomingData = incomingData.trim();
      
      // Check data validity as it ensures that the string is complete: <distance speed time>
      if (incomingData.startsWith("<") && incomingData.endsWith(">")) {
        incomingData = incomingData.substring(1, incomingData.length() - 1);
        
        String[] incomingDataArray = split(incomingData, "  ");
        
        if (incomingDataArray == null || incomingDataArray.length != 3) {
          return;
        }
        
        latestData = incomingDataArray;
        
        if (timeData.size() == 0) {
          startTime = latestTimeElapsed();
        }
        
        handleLatestData();
      }
    }
  }
}

// Processes the latest data, updates arrays, and the chart.
void handleLatestData() {
  Float speed = latestSpeed();
  Float distance = latestDistance();
  Integer time = latestTimeElapsed() - startTime;
  
  // If time is negative, then something has gone wrong, and data should be reset (this should only occur at the start due to weird arduino data from millis())
  if (time < 0) {
    resetData();
    return;
  }
  
  speedData.add(speed);
  distanceData.add(distance);
  timeData.add(time);
  
  updateLineChart();
  
  TableRow newRow = table.addRow();
  newRow.setInt("Time", time);
  newRow.setFloat("Distance", distance);
  newRow.setFloat("Speed", speed);
}


// Updates the line chart with the latest data, ensuring the parameters are float[].
void updateLineChart() {
  lineChart.setData(convertIntArrayListToFloatArray(timeData), convertFloatArrayListToFloatArray(distanceData));
}

// Clears the serial port buffer to ensure fresh data is read.
void clearPort() {
  if (port.available() > 0) {  
    port.readStringUntil('\n');
  }
}

// Converts an ArrayList of Floats to a float array (used for lineChart.setData as float[] are needed).
float[] convertFloatArrayListToFloatArray(ArrayList<Float> floatList) {
  float[] floatArray = new float[floatList.size()];
  
  for (int i = 0; i < floatList.size(); i++) {
      floatArray[i] = floatList.get(i);
  }
  
  return floatArray;
}

// Converts an ArrayList of Ints to a float array (used for lineChart.setData as float[] are needed).
float[] convertIntArrayListToFloatArray(ArrayList<Integer> intList) {
  float[] floatArray = new float[intList.size()];
  
  for (int i = 0; i < intList.size(); i++) {
      floatArray[i] = intList.get(i);
  }
  
  return floatArray;
}
