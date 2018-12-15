#include <FilterTwoPole.h>
#include <FilterDerivative.h>
#include <FloatDefine.h>
#include <FilterOnePole.h>
#include <RunningStatistics.h>
#include <Filters.h>
#include <Wire.h>
#include <Adafruit_INA219.h>
#include <RFduinoBLE.h>

const int wakePin = 3;
const int nBytes = 6;              //current time (long) milliseconds: first 4 bytes, duration (int16) milliseconds: next 2 bytes
const int n = 150;                 //number of desired samples
const int bufferSize = n * nBytes; //leave enough room to store all samples

const int windowSize = 10;          //window for moving average filter
const int threshold = 20;           //noise threshold

int winData[windowSize];            //buffers data for moving ave filter
char timeStampBuffer[bufferSize];   //up to 166 puffs w/duration on the ram (8kb) with longs

long startTime = 0;
long currentTime = 0;

int puff = 0;                       //count puffs
int counter = 0;                    //increment timeStamp Buffer
int bufferFilled = 0;               //check to see if buffer is filled
int sampleRate = 500;
int sampleDelay = 1000 / sampleRate; //sample rate to milliseconds delay
int consecutiveZeros = 0;           //increment when under noise threshold
int conZeroThresh = 5;              //determines if puff has ended
int connectCheck = 15;              //check to maintain connection every 15 minutes
long timeThresh = 1000 * 60 * connectCheck; //15 minutes in milliseconds

float filterFrequency = 100.0;
float shuntvoltage = 0;
float busvoltage = 0;
float current_mA = 0;
float loadvoltage = 0;
float power_mW = 0;

FilterOnePole lowpassFilter( LOWPASS, filterFrequency );
Adafruit_INA219 ina219;

void setup() {
  ina219.begin();
  Wire.beginOnPins(4, 5);

  //  pinMode(wakePin, INPUT);

  RFduinoBLE.advertisementInterval = 1000;
  RFduinoBLE.deviceName = "Juul-Current-1";
  RFduinoBLE.advertisementData = "juulCurrent";

  RFduinoBLE.txPowerLevel = 0; //Sets the transmit power to max +4dBm
  // start the BLE stack
  RFduinoBLE.begin();
  //  RFduino_pinWake(wakePin, HIGH);

  Serial.begin(9600);
}
void RFduinoBLE_onConnect() {
  startTime = millis();
}

void RFduinoBLE_onDisconnect() {
  //  digitalWrite(wakePin, LOW);
}

void loop() {
//
//  shuntvoltage = ina219.getShuntVoltage_mV();
//  busvoltage = ina219.getBusVoltage_V();
  current_mA = ina219.getCurrent_mA();
//  power_mW = ina219.getPower_mW();
//  loadvoltage = busvoltage + (shuntvoltage / 1000);

  
      if(millis() > timeThresh && millis()%timeThresh == 0){
        RFduinoBLE.sendInt(0);
  //      RFduino_resetPinWake(wakePin);
      }
  //    if(RFduino_pinWoke(wakePin)){
      if(current_mA > 20){
  //      Serial.println("mA > 100");
  //      Serial.println("Woke");
  
        //Simple test, transmits every puff with fixed delay before reseting
  //      recordPuff();
  
        //Buffers puff time and duration to save battery life
        //Only sends over BLE when n puffs complete
  //      recordPuffs();
  
        //Records and transmits duration of each puff
        recordDuration();
  //      RFduino_resetPinWake(wakePin);
      }
      else{
        RFduino_ULPDelay(50); // Stay in ultra low power mode until interrupt from the BLE or pinWake()
      }
  //debug signal
//  debug();
}
//Sends duration of each puff
void recordDuration() {
  long ct = millis();
  int duration = 0;

  //    int rawData = movingAve();
  bool puffing = true;
  while (puffing) {

    current_mA = ina219.getCurrent_mA();
    float lpCurrent = lowpassFilter.input(current_mA);
    if (lpCurrent <= threshold) {
      consecutiveZeros += 1;
    } else {
      consecutiveZeros = 0;
    }
    if (consecutiveZeros == conZeroThresh) {
      puffing = false;
      duration = millis() - ct;
    }
    delay(sampleDelay);
  }
  //    Serial.println(duration);
  RFduinoBLE.sendInt(duration);
  //    RFduino_resetPinWake(wakePin);
}

void recordPuff() {
  puff = puff + 1;
  RFduinoBLE.sendInt(puff);
  delay(2000);
  //    RFduino_resetPinWake(wakePin);
}

void recordPuffs() {
  current_mA = ina219.getCurrent_mA();
  int t =   lowpassFilter.input(current_mA);
  //calculate current time in milliseconds
  currentTime = millis() - startTime;
  byte bOne = currentTime >> 24;
  byte bTwo = currentTime >> 16;
  byte bThree = currentTime >> 8;
  byte bFour = currentTime;
  timeStampBuffer[counter] = char(bOne);
  timeStampBuffer[counter + 1] = char(bTwo);
  timeStampBuffer[counter + 2] = char(bThree);
  timeStampBuffer[counter + 3] = char(bFour);
  //increment by 4 to avoid writing over bytes
  counter = counter + 4;

  puff = puff + 1;
  //convert 32 bit long into 8 bytes so it can be sent as char array
  //  Serial.print(puff);Serial.print(", ");
  //  Serial.println(currentTime);

  //Decode timestamps from 4 bytes to long
  //  long t = 0;
  //  t += bOne << 24;
  //  t += bTwo << 16;
  //  t += bThree <<8;
  //  t += bFour;

  // Serial.print("bytes: "); Serial.println(t);

  bool puffing = true;
  while (puffing) {
    current_mA = ina219.getCurrent_mA();
    t =   lowpassFilter.input(current_mA);
    if (t <= threshold) {
      consecutiveZeros += 1;
    } else {
      consecutiveZeros = 0;
    }

    if (consecutiveZeros == conZeroThresh) {
      puffing = false;
      consecutiveZeros = 0;
      int16_t ct = millis() - currentTime;

      bOne = ct >> 8;
      bTwo = ct;

      timeStampBuffer[counter] = char(bOne);
      timeStampBuffer[counter + 1] = char(bTwo);

      //increment by 2 to avoid writing over bytes
      counter = counter + 2;

      //      RFduino_resetPinWake(wakePin);
    }
    //increment by 4 to include all bytes
    counter = counter + 4;
    delay(sampleDelay);
  }
  if (counter == bufferSize) {
    while (! RFduinoBLE.send(timeStampBuffer, bufferSize));
    counter = 0;
    //    Serial.println("buffer sent");
  }
}
//averages voltage over a given window
int movingAve() {
  int sum = 0;
  int ave = 0;

  current_mA = ina219.getCurrent_mA();
  int t =   lowpassFilter.input(current_mA);
  if (t <= threshold) {
    consecutiveZeros += 1;
  } else {
    consecutiveZeros = 0;
  }
  if (consecutiveZeros == conZeroThresh) {
    bufferFilled = 0;
    consecutiveZeros = 0;
  }

  if (bufferFilled == 0) {
    for (int i = 0; i < windowSize; i++) {
      current_mA = ina219.getCurrent_mA();
      winData[i] = lowpassFilter.input(current_mA);
      delay(sampleDelay);
      sum += winData[i];
    }
    bufferFilled += 1;
  } else {

    int temp[windowSize - 1];

    for (int i = 0; i < windowSize; i++) {
      if (i < (windowSize - 1)) {
        temp[i] = winData[i + 1];
        sum += temp[i];
      } else {
        temp[i] = t;
        sum += temp[i];
        delay(sampleDelay);
      }
    }
  }

  return ave = sum / windowSize;
  //  Serial.println(ave);
}

void debug() {
  //    int debugData = lowpassFilter.input(analogRead(voltage));
  //    int debugData = movingAve();

//  shuntvoltage = ina219.getShuntVoltage_mV();
//  busvoltage = ina219.getBusVoltage_V();
  current_mA = ina219.getCurrent_mA();
//  power_mW = ina219.getPower_mW();
//  loadvoltage = busvoltage + (shuntvoltage / 1000);
//
//  Serial.print(busvoltage); Serial.print(",");
//  Serial.print(loadvoltage); Serial.print(",");
  Serial.print(shuntvoltage); Serial.print(",");
//  Serial.print(power_mW); Serial.print(",");
  Serial.println(current_mA);

  delay(sampleDelay);

  //    int debugData =  current_mA;
  //    Serial.println(debugData);
}
