//Board should be set to "Arduino Pro or Pro Mini (3.3V, 8MHz) w/ ATmega328"
#include <WProgram.h>
#include <Wire.h>
#include "ST7036.h"
#include "LCD_C0220BiZ.h"
#include "MCP23008.h"
#include <MenuBackend.h>

//-------------------------------------------------------------------------------------------------------------//
//Variable nad constant initialization, initialiazation of MCP23008 library, ST7036 librar

//Start 2 instances of MCP23008 library
MCP23008 mcp_internal;  //This one is for controlling various peripherals
MCP23008 mcp_general;  //This one is for general purpose use. The LCD backlight is also on here

//Start instance of I2C LCD library
ST7036 lcd = ST7036(2, 20, 0x78);

//Define some constants
//The first four here are on mcp_internal
#define DAC_CS 1
#define ADC_CS 0
#define RANGE 2  //Range selection for rev.B boards, not used anyway
#define LCD_RESET 3

//These are on mcp_general
#define BACKLIGHT_PIN 7
byte buttons[] = {0, 0, 0, 0};  //Array to store states of onboard buttons

//Rotary encoder pins
#define ENC1A 2
#define ENC1B 4
#define ENC2A 3
#define ENC2B 7

//These are the counts for the rotary encoders. They are volatile because they will be modified
//in an interrupt and we don't want the compiler to try and optimise these
volatile unsigned int VOLTAGE_POS = 0;
volatile unsigned int CURRENT_POS = 0;

//ADC stuff
int adcVals[] = {0, 0, 0, 0};  //Array to store the different ADC values
//Define some ADC constants
#define IOUT200 0
#define IOUT 1
#define VOUT 2
#define VIN 3
float VOLTAGE_PRINT_DIVISOR = 333.889816;  //This is to output the correct value after voltage
                                           //divider and ADC. Only to be used for VIN

//These are for SPI communication and are located directly on the AVR
#define SPI_DATA A0
#define SPI_CLK A3
#define ADC_DATA A1
#define SPI_CLK_CTRL digitalWrite(SPI_CLK, HIGH); digitalWrite(SPI_CLK, LOW);  //Macro to 'clock' the clock

//-------------------------------------------------------------------------------------------------------------//

//Menu system! This area contains stuff for setting up and using the menu
/*
root
  Presets      Settings
    1.8V         Calibration
    2.5V           Auto
    3.3V           Manual
    5.0V         LCD
                   Backlight
                   Contrast
*/
//Start instance fo Menu Backend library
MenuBackend menu = MenuBackend(menuUseEvent, menuChangeEvent);

//Preset voltage menu
MenuItem mPresets = MenuItem("Presets");
  MenuItem m1v8 = MenuItem("1.8V");
  MenuItem m2v5 = MenuItem("2.5V");
  MenuItem m3v3 = MenuItem("3.3V");
  MenuItem m5v = MenuItem("5.0V");
  
//Settings menu
MenuItem mSettings = MenuItem("Settings");
  MenuItem mCalibration = MenuItem("Calibration");
    MenuItem mAuto = MenuItem("Auto");
    MenuItem mManual = MenuItem("Manual");
  MenuItem mLCD = MenuItem("LCD");
    MenuItem mBacklight = MenuItem("Backlight");
    MenuItem mContrast = MenuItem("Contrast");
    
void menuSetup()
{
  menu.getRoot().add(mPresets).add(mSettings);           //Add Presets and Settings to root
  mPresets.addRight(m1v8).add(m2v5).add(m3v3).add(m5v);  //Add options under Presets
  mSettings.add(mCalibration).add(mLCD);                 //Add options under Settings
  mCalibration.addRight(mAuto).add(mManual);             //Add options under Calibration
  mLCD.addRight(mBacklight).add(mContrast);              //Add options under LCD
}

void menuUseEvent(MenuUseEvent used)
{
}

//Currently prints what happened to the serial port
void menuChangeEvent(MenuChangeEvent changed)
{
  Serial.print("Menu change ");
  Serial.print(changed.from.getName());
  Serial.print(" ");
  Serial.println(changed.to.getName());
}

//VERY rough way to read buttons, doesn't really work
void menuNav()
{
  if(buttons[0] == 0){
    menu.moveDown();
    delay(10);
  }
  
  if(buttons[1] == 0){
    menu.moveUp();
    delay(10);
  }
  
  if(buttons[2] == 0){
    menu.moveLeft();
    delay(10);
  }
  
  if(buttons[3] == 0){
    menu.moveRight();
    delay(10);
  }
}

//-------------------------------------------------------------------------------------------------------------//

void setup()
{
  Serial.begin(9600);  //Serial for debugging
  
  //Start the library for the two MCP23008's
  mcp_internal.begin(0);
  mcp_general.begin(8);

  //Bring LCD_RESET high to enable LCD
  mcp_internal.pinMode(LCD_RESET, OUTPUT);
  mcp_internal.digitalWrite(LCD_RESET, HIGH);

  //Bring CS lines high to ignore stray data
  mcp_internal.pinMode(DAC_CS, OUTPUT);
  mcp_internal.pinMode(ADC_CS, OUTPUT);
  mcp_internal.digitalWrite(DAC_CS, HIGH);
  mcp_internal.digitalWrite(ADC_CS, HIGH);

  //Set SPI pins as outputs
  pinMode(SPI_DATA, OUTPUT);
  pinMode(SPI_CLK, OUTPUT);
  pinMode(ADC_DATA, INPUT);

  //Set up rotary encoder pins
  pinMode(ENC1A, INPUT);
  pinMode(ENC1B, INPUT);
  pinMode(ENC2A, INPUT);
  pinMode(ENC2B, INPUT);
  digitalWrite(ENC1A, HIGH);
  digitalWrite(ENC1B, HIGH);
  digitalWrite(ENC2A, HIGH);
  digitalWrite(ENC2B, HIGH);
  
  //Set up button inputs on mcp_general
  mcp_general.pinMode(0, INPUT);
  mcp_general.pinMode(1, INPUT);
  mcp_general.pinMode(2, INPUT);
  mcp_general.pinMode(3, INPUT);

  //Set up interrupts for rotary encoders
  attachInterrupt(0, voltageChange, CHANGE);
  attachInterrupt(1, currentChange, CHANGE);
  
  menuSetup();

  //Initialize the LCD
  lcd.init();
  lcd.setContrast(10);
  //Turn on backlight. Power pin is connected to mcp_general GP7
  mcp_general.pinMode(BACKLIGHT_PIN, OUTPUT);
  mcp_general.digitalWrite(BACKLIGHT_PIN, HIGH);
  lcd.clear();

  //Start up niceness  
  lcd.setCursor(0, 6);
  lcd.print("uSupply");
  lcd.setCursor(1, 1);
  lcd.print("Bench Power Supply");
  delay(2000);
  lcd.clear();
}

void loop()
{
  //int vVal = map(VOLTAGE_POS, 0, 1024, 0, 2048);
  //dacSend(1, vVal);

  //int cVal = map(CURRENT_POS, 0, 1024, 0, 2048);
  //dacSend(2, cVal);

  //adcRead(IOUT);
  //adcRead(VOUT);
  //adcRead(VIN);

  //updateDisplay();
  readButtons();
  //for(byte b = 0; b < 4; b++){
  //  Serial.println(buttons[b], DEC);
  //}
  
  menuNav();
}

//-------------------------------------------------------------------------------------------------------------//

//This gets called when the voltage set encoder is changed
void voltageChange()
{
  if(digitalRead(ENC1A) != digitalRead(ENC1B)){
    VOLTAGE_POS++;
  }else{
    VOLTAGE_POS--;
  }

  if(VOLTAGE_POS >= 1024){
    VOLTAGE_POS = 1024;
  }

  if(VOLTAGE_POS <= 0){
    VOLTAGE_POS = 0;
  }
  delay(20);
}

//-------------------------------------------------------------------------------------------------------------//

//This gets called when the current set encoder is changed
void currentChange()
{
  if(digitalRead(ENC2A) != digitalRead(ENC2B)){
    CURRENT_POS++;
  }else{
    CURRENT_POS--;
  }

  if(CURRENT_POS >= 1024){
    CURRENT_POS = 1024;
  }

  if(CURRENT_POS <= 0){
    CURRENT_POS = 0;
  }
}

//-------------------------------------------------------------------------------------------------------------//

//Set "channel" as 1 for voltage, 2 for current. Maximum "value" is 1023, because we are using 10 bits. Maximum is 4095 if using all 12 bits
//Bit-bang the DAC
void dacSend(byte channel, int value)
{
  unsigned int temp;

  //Bring CS low to enable communication
  mcp_internal.digitalWrite(DAC_CS, LOW);

  //If "channel" is set to volatge, send a LOW bit, vice-versa for current
  if(channel == 1){
    digitalWrite(SPI_DATA, LOW);
  }else{
    digitalWrite(SPI_DATA, HIGH);
  }

  SPI_CLK_CTRL
    digitalWrite(SPI_DATA, LOW);  //Unbuffered VREF input
  SPI_CLK_CTRL
    digitalWrite(SPI_DATA, LOW);  //Output gain x2
  SPI_CLK_CTRL
    digitalWrite(SPI_DATA, HIGH);  //Disable shutdown
  SPI_CLK_CTRL
    temp = value;
  digitalWrite(SPI_DATA, ((temp>>11) & 1));  //Only using 10 bits of 12 bit DAC. It won't work without these
  SPI_CLK_CTRL
    temp = value;
  digitalWrite(SPI_DATA, ((temp>>10) & 1));
  SPI_CLK_CTRL
    temp = value;
  digitalWrite(SPI_DATA, ((temp>>9) & 1));
  SPI_CLK_CTRL
    temp = value;
  digitalWrite(SPI_DATA, ((temp>>8) & 1));
  SPI_CLK_CTRL
    temp = value;
  digitalWrite(SPI_DATA, ((temp>>7) & 1));
  SPI_CLK_CTRL
    temp = value;
  digitalWrite(SPI_DATA, ((temp>>6) & 1));
  SPI_CLK_CTRL
    temp = value;
  digitalWrite(SPI_DATA, ((temp>>5) & 1));
  SPI_CLK_CTRL
    temp = value;
  digitalWrite(SPI_DATA, ((temp>>4) & 1));
  SPI_CLK_CTRL
    temp = value;
  digitalWrite(SPI_DATA, ((temp>>3) & 1));
  SPI_CLK_CTRL
    temp = value;
  digitalWrite(SPI_DATA, ((temp>>2) & 1));
  SPI_CLK_CTRL
    temp = value;
  digitalWrite(SPI_DATA, ((temp>>1) & 1));
  SPI_CLK_CTRL
    temp = value;
  digitalWrite(SPI_DATA, temp & 1);
  SPI_CLK_CTRL

  //Done sending data, so set the CS pin high to "latch" the data
  mcp_internal.digitalWrite(DAC_CS, HIGH);
}

//-------------------------------------------------------------------------------------------------------------//

//We read from the ADC over SPI using this function to bit-bang
void adcRead(byte ADC_CHANNEL)
{
  byte i;  //Variable for storing the read bit from the ADC


  mcp_internal.digitalWrite(ADC_CS, LOW);  //Set ADC CS line low to begin comms

  digitalWrite(SPI_DATA, HIGH);  //Start bit
  SPI_CLK_CTRL
  digitalWrite(SPI_DATA, HIGH);  //Single input mode
  SPI_CLK_CTRL
  digitalWrite(SPI_DATA, LOW);  //D2 setup bit - this gets ignored when in single input mode
  SPI_CLK_CTRL

  if(ADC_CHANNEL == 0){  //Send set up for channel 0
    digitalWrite(SPI_DATA, LOW);
    SPI_CLK_CTRL
    digitalWrite(SPI_DATA, LOW);
    SPI_CLK_CTRL
  }

  if(ADC_CHANNEL == 1){  //Send set up for channel 1
    digitalWrite(SPI_DATA, LOW);
    SPI_CLK_CTRL
    digitalWrite(SPI_DATA, HIGH);
    SPI_CLK_CTRL
  }
  
  if(ADC_CHANNEL == 2){  //Send set up for channel 2
    digitalWrite(SPI_DATA, HIGH);
    SPI_CLK_CTRL
    digitalWrite(SPI_DATA, LOW);
    SPI_CLK_CTRL
  }
  
  if(ADC_CHANNEL == 3){  //Send set up for channel 3
    digitalWrite(SPI_DATA, HIGH);
    SPI_CLK_CTRL
    digitalWrite(SPI_DATA, HIGH);
    SPI_CLK_CTRL
  }

  //We are done sending setup data. Now we need to listen for data, MSB first, 12 bits

  //The first recieved bit is null, ignore it
  SPI_CLK_CTRL

    i = digitalRead(ADC_DATA);  //bit 11
  bitWrite(adcVals[ADC_CHANNEL], 11, i);  //Write the first bit received to the correct array element
  SPI_CLK_CTRL

    i = digitalRead(ADC_DATA);  //bit 10
  bitWrite(adcVals[ADC_CHANNEL], 10, i);
  SPI_CLK_CTRL

    i = digitalRead(ADC_DATA);  //bit 9
  bitWrite(adcVals[ADC_CHANNEL], 9, i);
  SPI_CLK_CTRL

    i = digitalRead(ADC_DATA);  //bit 8
  bitWrite(adcVals[ADC_CHANNEL], 8, i);
  SPI_CLK_CTRL

    i = digitalRead(ADC_DATA);  //bit 7
  bitWrite(adcVals[ADC_CHANNEL], 7, i);
  SPI_CLK_CTRL

    i = digitalRead(ADC_DATA);  //bit 6
  bitWrite(adcVals[ADC_CHANNEL], 6, i);
  SPI_CLK_CTRL

    i = digitalRead(ADC_DATA);  //bit 5
  bitWrite(adcVals[ADC_CHANNEL], 5, i);
  SPI_CLK_CTRL

    i = digitalRead(ADC_DATA);  //bit 4
  bitWrite(adcVals[ADC_CHANNEL], 4, i);
  SPI_CLK_CTRL

    i = digitalRead(ADC_DATA);  //bit 3
  bitWrite(adcVals[ADC_CHANNEL], 3, i);
  SPI_CLK_CTRL

    i = digitalRead(ADC_DATA);  //bit 2
  bitWrite(adcVals[ADC_CHANNEL], 2, i);
  SPI_CLK_CTRL

    i = digitalRead(ADC_DATA);  //bit 1
  bitWrite(adcVals[ADC_CHANNEL], 1, i);
  SPI_CLK_CTRL

    i = digitalRead(ADC_DATA);  //bit 0
  bitWrite(adcVals[ADC_CHANNEL], 0, i);
  SPI_CLK_CTRL

  mcp_internal.digitalWrite(ADC_CS, HIGH);
}

//-------------------------------------------------------------------------------------------------------------//

void updateDisplay()
{
  lcd.setCursor(0, 0);
  lcd.print("SET: ");
  lcd.print(VOLTAGE_POS / 100.00);
  lcd.print("V ");
  lcd.setCursor(0, 12);
  lcd.print(CURRENT_POS);
  lcd.print("mA  ");

  lcd.setCursor(1, 0);
  lcd.print("OUT: ");
  lcd.print(adcVals[IOUT]);
  lcd.print(",");
  lcd.print(adcVals[VOUT]);
  lcd.print(",");
  lcd.print((adcVals[VIN] * 2) / VOLTAGE_PRINT_DIVISOR);  //We calculate the actual voltage AFTER the voltage divider, and ADC
  lcd.print("    ");
}

//-------------------------------------------------------------------------------------------------------------//

void readButtons()
{
  for(byte buttonNumber = 0; buttonNumber < 4; buttonNumber++){
    byte buttonState = mcp_general.digitalRead(buttonNumber);
    buttons[buttonNumber] = buttonState;
  }
}
