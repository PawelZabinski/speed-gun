// Author: Pawel Zabinski
// Last updated: 19/02/2024

import org.gicentre.utils.stat.*;
import processing.serial.*;
import controlP5.*;

XYChart lineChart;
ControlP5 cp5;
Button pauseButton;

//: /dev/cu.usbmodem1101
Serial port;
String portName = "/dev/cu.usbmodem1101";

String incomingData;
String[] latestData = new String[3];     // (distance, speed, time_elapsed)

float latestDistance() { 
  if (latestData[0] != null)
    return parseFloat(latestData[0]); 
  
  return 0;
}

float latestSpeed() { 
  if (latestData[1] != null)
    return parseFloat(latestData[1]);
    
  return 0;
}

int latestTimeElapsed() { 
  if (latestData[2] != null)
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
  if (!isPaused)
    handleSerialData();
  
  background(255);
  fill(0);
  
  lineChart.draw(30, 75, 455, 400);
  
  text("Distance: " + latestDistance(), 15, 15);
  text("Speed: " + latestSpeed(), 115, 15);
  text("Time: " + latestTimeElapsed(), 215, 15);
}

public void exportData() {
  saveTable(table, "data/speed-gun-measurements.csv");
}

public void resetData() {
  distanceData = new ArrayList();
  speedData = new ArrayList();
  timeData = new ArrayList();
  startTime = 0;
}

public void togglePause() {
  isPaused = !isPaused;
  
  pauseButton.setLabel(isPaused ? "Resume" : "Pause");
}

void handleSerialData() {
  if (port.available() > 0) {  
    incomingData = port.readStringUntil('\n');
    
    if (incomingData != null) {
      incomingData = incomingData.trim();
      
      // Check data validity as it ensures that the string is complete: <distance speed time>
      if (incomingData.startsWith("<") && incomingData.endsWith(">")) {
        incomingData = incomingData.substring(1, incomingData.length() - 1);
        
        if (timeData.size() == 0)
          startTime = latestTimeElapsed();
        
        latestData = split(incomingData, ' ');
        handleLatestData();
      }
    }
  }
}

void handleLatestData() {
  Float speed = latestSpeed();
  Float distance = latestDistance();
  Integer time = latestTimeElapsed() - startTime;
  
  speedData.add(speed);
  distanceData.add(distance);
  timeData.add(time);
  
  lineChart.setData(convertIntArrayListToFloatArray(timeData), convertFloatArrayListToFloatArray(distanceData));
  
  TableRow newRow = table.addRow();
  newRow.setInt("Time", time);
  newRow.setFloat("Distance", distance);
  newRow.setFloat("Speed", speed);
}


// Helper functions
float[] convertFloatArrayListToFloatArray(ArrayList<Float> floatList) {
  float[] floatArray = new float[floatList.size()];
  
  for (int i = 0; i < floatList.size(); i++) {
      floatArray[i] = floatList.get(i);
  }
  
  return floatArray;
}

float[] convertIntArrayListToFloatArray(ArrayList<Integer> intList) {
  float[] floatArray = new float[intList.size()];
  
  for (int i = 0; i < intList.size(); i++) {
      floatArray[i] = intList.get(i);
  }
  
  return floatArray;
}
