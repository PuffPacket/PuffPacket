#include <FilterTwoPole.h>
#include <FilterDerivative.h>
#include <FloatDefine.h>
#include <FilterOnePole.h>
#include <RunningStatistics.h>
#include <Filters.h>

#include <RFduinoBLE.h>

const int voltage = 6;             //Voltage input pin
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
int sampleDelay = 1000/sampleRate;  //sample rate to milliseconds delay
int consecutiveZeros = 0;           //increment when under noise threshold 
int conZeroThresh = 5;              //determines if puff has ended
int connectCheck = 15;              //check to maintain connection every 15 minutes
long timeThresh = 1000*60*connectCheck; //15 minutes in milliseconds

float filterFrequency = 100.0;  
FilterOnePole lowpassFilter( LOWPASS, filterFrequency ); 

void setup() {

  pinMode(voltage, INPUT);
  digitalWrite(voltage, LOW);
  RFduinoBLE.advertisementInterval = 1000;
  RFduinoBLE.deviceName = "Juul-volt-Disposable";
  RFduinoBLE.advertisementData = "juulVoltage";
  
  RFduinoBLE.txPowerLevel = 0; //Sets the transmit power to max +4dBm
  // start the BLE stack
  RFduinoBLE.begin();
  RFduino_pinWake(voltage, HIGH); 
  startTime = millis();
  Serial.begin(9600);
}

void RFduinoBLE_onConnect(){
  startTime = millis();
}


void loop() {

    if(millis() > timeThresh && millis()%timeThresh == 0){
      digitalWrite(voltage, HIGH);
      RFduinoBLE.sendInt(0);
      digitalWrite(voltage, LOW);
      RFduino_resetPinWake(voltage); 
    }
    if(RFduino_pinWoke(voltage)){
      //Simple test, transmits every puff with fixed delay before reseting
//      recordPuff();

      //Buffers puff time since connected and duration to save battery life 
      //Only sends over BLE when n puffs complete
//      recordPuffs();

      //Records and transmits duration of each puff
      recordDuration();


    }
    else{
      RFduino_ULPDelay(INFINITE); // Stay in ultra low power mode until interrupt from the BLE or pinWake()
    }
      //debug signal
//      debug();
}
//Sends duration of each puff
void recordDuration(){
    long ct = millis();
    int duration = 0;
    int rawData = lowpassFilter.input(analogRead(voltage));
//    int rawData = movingAve();
    bool puffing = true;
    while(puffing){

      rawData = analogRead(voltage);
      if(rawData <= threshold){
        consecutiveZeros += 1; 
      }
      else{
        consecutiveZeros = 0; 
      }
      if(consecutiveZeros == conZeroThresh){
        puffing = false;
        duration = millis() - ct;
      }
      delay(sampleDelay);
    }
//    Serial.println(duration);
    RFduinoBLE.sendInt(duration);
    RFduino_resetPinWake(voltage); 
}

void recordPuff(){
    puff = puff + 1;
    RFduinoBLE.sendInt(puff);
    delay(2000);
    RFduino_resetPinWake(voltage); 
}

void recordPuffs(){
  
  int t =   lowpassFilter.input(analogRead(voltage));
  //calculate current time in milliseconds
  currentTime = millis() - startTime; 
  byte bOne = currentTime >> 24;
  byte bTwo = currentTime >> 16;
  byte bThree = currentTime >> 8; 
  byte bFour = currentTime;
  timeStampBuffer[counter] = char(bOne);  
  timeStampBuffer[counter+1] = char(bTwo);  
  timeStampBuffer[counter+2] = char(bThree);  
  timeStampBuffer[counter+3] = char(bFour);  
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
  while(puffing){
    t =   lowpassFilter.input(analogRead(voltage));
    if(t <= threshold){
      consecutiveZeros+=1;
    }else{
      consecutiveZeros = 0; 
    } 
    
    if(consecutiveZeros == conZeroThresh){
      puffing = false;
      consecutiveZeros = 0; 
      int16_t ct = millis() - currentTime;
     
      bOne = ct >> 8;
      bTwo = ct;

      timeStampBuffer[counter] = char(bOne);  
      timeStampBuffer[counter+1] = char(bTwo);  

      //increment by 2 to avoid writing over bytes
      counter = counter + 2; 
  
      RFduino_resetPinWake(voltage); 
    }
    //increment by 4 to include all bytes
    counter = counter + 4; 
    delay(sampleDelay);
  }
  if(counter == bufferSize){
    while (! RFduinoBLE.send(timeStampBuffer, bufferSize));
    counter = 0; 
//    Serial.println("buffer sent");
  } 
}
//averages voltage over a given window
int movingAve(){
  int sum = 0; 
  int ave = 0; 
  int t =   lowpassFilter.input(analogRead(voltage));
  if(t <= threshold){
    consecutiveZeros+=1;
  }else{
      consecutiveZeros = 0; 
    } 
  if(consecutiveZeros == conZeroThresh){
    bufferFilled = 0;
    consecutiveZeros = 0; 
  }
  
  if(bufferFilled == 0){
    for(int i = 0; i < windowSize; i++){
      winData[i] = lowpassFilter.input(analogRead(voltage));
      delay(sampleDelay);
      sum += winData[i]; 
    }
    bufferFilled += 1;
  }else{
    
    int temp[windowSize-1]; 
    
     for(int i = 0; i < windowSize; i++){
      if(i < (windowSize-1)){
        temp[i] = winData[i+1];
        sum += temp[i]; 
      }else{
        temp[i] = t;
        sum += temp[i]; 
        delay(sampleDelay);
      }
    }
  }

  return ave = sum/windowSize;
//  Serial.println(ave);
}

void debug(){
//    int debugData = lowpassFilter.input(analogRead(voltage));
//    int debugData = movingAve();
    int debugData =  analogRead(voltage);
//    Serial.print("d: ");  
    Serial.println(debugData);
    delay(sampleDelay);
}
