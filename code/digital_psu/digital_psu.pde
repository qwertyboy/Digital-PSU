#include <WProgram.h>
#include <Wire.h>
#include "ST7036.h"
#include "LCD_C0220BiZ.h"
#include "MCP23008.h"

//Start 2 instances of MCP23008 library
MCP23008 mcp_internal;
MCP23008 mcp_general;

//Start instance of I2C LCD library
ST7036 lcd = ST7036(2, 20, 0x78);

//Define some global variables
//The first four here are on mcp_internal
#define dac_cs 1
#define adc_cs 0
#define range 2
#define lcd_reset 3

//These are on mcp_general
#define backlight_pin 7
int b1 = 0;
int b2 = 0;
int b3 = 0;
int b4 = 0;

//Rotary encoder pins
#define ENC1A 2
#define ENC1B 4
#define ENC2A 3
#define ENC2B 7

//These are for voltage and current setting
float vPos = 0;
int cPos = 0;

//ADC stuff
int adcVals[] = {0, 0, 0, 0};  //Array to store the different ADC values
#define IOUT200 0
#define IOUT 1
#define VOUT 2
#define VIN 3
float vDiv = 333.889816;

//These are for SPI communication and are located directly on the AVR
#define spi_data A0
#define spi_clk A3
#define adc_data A1



void setup()
{
  Serial.begin(9600);
  //Start the library for the two MCP23008's
  mcp_internal.begin(0);
  mcp_general.begin(8);

  //Bring lcd_reset high to enable LCD
  mcp_internal.pinMode(lcd_reset, OUTPUT);
  mcp_internal.digitalWrite(lcd_reset, HIGH);

  //Bring CS lines high to ignore stray data
  mcp_internal.pinMode(dac_cs, OUTPUT);
  mcp_internal.pinMode(adc_cs, OUTPUT);
  mcp_internal.digitalWrite(dac_cs, HIGH);
  mcp_internal.digitalWrite(adc_cs, HIGH);

  //Set SPI pins as outputs
  pinMode(spi_data, OUTPUT);
  pinMode(spi_clk, OUTPUT);
  pinMode(adc_data, INPUT);

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
  attachInterrupt(0, vChange, CHANGE);
  attachInterrupt(1, cChange, CHANGE);

  //Initialize the LCD
  lcd.init();
  lcd.setContrast(10);
  //Turn on backlight. Power pin is connected to mcp_general GP7
  mcp_general.pinMode(backlight_pin, OUTPUT);
  mcp_general.digitalWrite(backlight_pin, HIGH);
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
  int vVal = map(vPos, 0, 1024, 0, 2048);
  dacSend(1, vVal);

  int cVal = map(cPos, 0, 1024, 0, 2048);
  dacSend(2, cVal);

  adcRead(IOUT);
  adcRead(VOUT);
  adcRead(VIN);

  updateDisplay();
}

//---------------------------------------------------//

//This gets called when the voltage set encoder is changed
void vChange()
{
  if(digitalRead(ENC1A) != digitalRead(ENC1B)){
    vPos++;
  }else{
    vPos--;
  }

  if(vPos >= 1024){
    vPos = 1024;
  }

  if(vPos <= 0){
    vPos = 0;
  }
  delay(20);
}

//---------------------------------------------------//

//This gets called when the current set encoder is changed
void cChange()
{
  if(digitalRead(ENC2A) != digitalRead(ENC2B)){
    cPos++;
  }else{
    cPos--;
  }

  if(cPos >= 1024){
    cPos = 1024;
  }

  if(cPos <= 0){
    cPos = 0;
  }
}

//---------------------------------------------------//

//Set "channel" as 1 for voltage, 2 for current. Maximum "value" is 1023, because we are using 10 bits. Maximum is 4095 if using all 12 bits

void dacSend(byte channel, long int value)
{
#define dac_clk digitalWrite(spi_clk, HIGH); digitalWrite(spi_clk, LOW);
  unsigned int temp;

  //Bring CS low to enable communication
  mcp_internal.digitalWrite(dac_cs, LOW);

  //If "channel" is set to volatge, send a LOW bit, vice-versa for current
  if(channel == 1){
    digitalWrite(spi_data, LOW);
  }else{
    digitalWrite(spi_data, HIGH);
  }

  dac_clk
    digitalWrite(spi_data, LOW);  //Unbuffered VREF input
  dac_clk
    digitalWrite(spi_data, LOW);  //Output gain x2
  dac_clk
    digitalWrite(spi_data, HIGH);  //Disable shutdown
  dac_clk
    temp = value;
  digitalWrite(spi_data, ((temp>>11) & 1));  //Only using 10 bits of 12 bit DAC. It won't work without these
  dac_clk
    temp = value;
  digitalWrite(spi_data, ((temp>>10) & 1));
  dac_clk
    temp = value;
  digitalWrite(spi_data, ((temp>>9) & 1));
  dac_clk
    temp = value;
  digitalWrite(spi_data, ((temp>>8) & 1));
  dac_clk
    temp = value;
  digitalWrite(spi_data, ((temp>>7) & 1));
  dac_clk
    temp = value;
  digitalWrite(spi_data, ((temp>>6) & 1));
  dac_clk
    temp = value;
  digitalWrite(spi_data, ((temp>>5) & 1));
  dac_clk
    temp = value;
  digitalWrite(spi_data, ((temp>>4) & 1));
  dac_clk
    temp = value;
  digitalWrite(spi_data, ((temp>>3) & 1));
  dac_clk
    temp = value;
  digitalWrite(spi_data, ((temp>>2) & 1));
  dac_clk
    temp = value;
  digitalWrite(spi_data, ((temp>>1) & 1));
  dac_clk
    temp = value;
  digitalWrite(spi_data, temp & 1);
  dac_clk

    //Done sending data, so set the CS pin high to "latch" the data
  mcp_internal.digitalWrite(dac_cs, HIGH);
}

//---------------------------------------------------//

//We read from the ADC using this function
void adcRead(byte adc_channel)
{
  byte i;  //Variable for storing the read bit from the ADC

#define adc_clk digitalWrite(spi_clk, HIGH); digitalWrite(spi_clk, LOW);

  mcp_internal.digitalWrite(adc_cs, LOW);  //Set ADC CS line low to begin comms

  digitalWrite(spi_data, HIGH);  //Start bit
  adc_clk
  digitalWrite(spi_data, HIGH);  //Single input mode
  adc_clk
  digitalWrite(spi_data, LOW);  //D2 setup bit - this gets ignored when in single input mode
  adc_clk

  if(adc_channel == 0){  //Send set up for channel 0
    digitalWrite(spi_data, LOW);
    adc_clk
    digitalWrite(spi_data, LOW);
    adc_clk
  }

  if(adc_channel == 1){  //Send set up for channel 1
    digitalWrite(spi_data, LOW);
    adc_clk
    digitalWrite(spi_data, HIGH);
    adc_clk
  }
  
  if(adc_channel == 2){  //Send set up for channel 2
    digitalWrite(spi_data, HIGH);
    adc_clk
    digitalWrite(spi_data, LOW);
    adc_clk
  }
  
  if(adc_channel == 3){  //Send set up for channel 3
    digitalWrite(spi_data, HIGH);
    adc_clk
    digitalWrite(spi_data, HIGH);
    adc_clk
  }

  //We are done sending setup data. Now we need to listen for data, MSB first, 12 bits

  //The first recieved bit is null, ignore it
  adc_clk

    i = digitalRead(adc_data);  //bit 11
  bitWrite(adcVals[adc_channel], 11, i);  //Write the first bit received to the correct array element
  adc_clk

    i = digitalRead(adc_data);  //bit 10
  bitWrite(adcVals[adc_channel], 10, i);
  adc_clk

    i = digitalRead(adc_data);  //bit 9
  bitWrite(adcVals[adc_channel], 9, i);
  adc_clk

    i = digitalRead(adc_data);  //bit 8
  bitWrite(adcVals[adc_channel], 8, i);
  adc_clk

    i = digitalRead(adc_data);  //bit 7
  bitWrite(adcVals[adc_channel], 7, i);
  adc_clk

    i = digitalRead(adc_data);  //bit 6
  bitWrite(adcVals[adc_channel], 6, i);
  adc_clk

    i = digitalRead(adc_data);  //bit 5
  bitWrite(adcVals[adc_channel], 5, i);
  adc_clk

    i = digitalRead(adc_data);  //bit 4
  bitWrite(adcVals[adc_channel], 4, i);
  adc_clk

    i = digitalRead(adc_data);  //bit 3
  bitWrite(adcVals[adc_channel], 3, i);
  adc_clk

    i = digitalRead(adc_data);  //bit 2
  bitWrite(adcVals[adc_channel], 2, i);
  adc_clk

    i = digitalRead(adc_data);  //bit 1
  bitWrite(adcVals[adc_channel], 1, i);
  adc_clk

    i = digitalRead(adc_data);  //bit 0
  bitWrite(adcVals[adc_channel], 0, i);
  adc_clk

  mcp_internal.digitalWrite(adc_cs, HIGH);
}

//---------------------------------------------------//

void updateDisplay()
{
  lcd.setCursor(0, 0);
  lcd.print("SET: ");
  lcd.print(vPos / 100.00);
  lcd.print("V ");
  lcd.setCursor(0, 12);
  lcd.print(cPos);
  lcd.print("mA  ");

  lcd.setCursor(1, 0);
  lcd.print("OUT: ");
  lcd.print(adcVals[1]);
  lcd.print(",");
  lcd.print(adcVals[2] / 200.00);
  lcd.print(",");
  lcd.print((adcVals[3] * 2) / vDiv);  //We calculate the actual voltage AFTER the voltage divider, and ADC
  lcd.print("    ");
}

//---------------------------------------------------//

void readButtons()
{
  for(int buttonNumber = 0; buttonNumber < 4; buttonNumber++){
    int buttonState = mcp_general.digitalRead(buttonNumber);
    
    if(buttonNumber == 0){
      b1 = buttonState;
    }
    
    if(buttonNumber == 1){
      b2 = buttonState;
    }
    
    if(buttonNumber == 2){
      b3 = buttonState;
    }
    
    if(buttonNumber == 3){
      b4 = buttonState;
    }
  }
}
