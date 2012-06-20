
#include <MenuBackend.h>

/*
	This program demonstrates a menu modeled after the menubar in the Arduino IDE
	
   +root
	+file			+edit   +sketch			+tools			+help
	 +new			 +cut	 +verify (V)	 +autoformat	 +environment
	 +open
	 +examples
	  +ArduinoISP
*/

//this controls the menu backend and the event generation
MenuBackend menu = MenuBackend(menuUseEvent,menuChangeEvent);
	//beneath is list of menu items needed to build the menu
	MenuItem miFile = MenuItem("File");
		MenuItem miNew = MenuItem("New");
		MenuItem miOpen = MenuItem("Open");
		MenuItem miExamples = MenuItem("Examples");
			MenuItem miArduinoISP = MenuItem("ArduinoISP");

	MenuItem miEdit = MenuItem("Edit");
		MenuItem miCut = MenuItem("Cut");

	MenuItem miSkecth = MenuItem("Sketch");
		MenuItem miVerify = MenuItem("Verify",'V');

	MenuItem miTools = MenuItem("Tools");
		MenuItem miAutoformat = MenuItem("Autoformat");

	MenuItem miHelp = MenuItem("Help");
		MenuItem miEnvironment = MenuItem("Environment");

//this function builds the menu and connects the correct items together
void menuSetup()
{
	Serial.println("Setting up menu...");
	//add the file menu to the menu root
	//when add is used, as opposed to addX as you see below, the item is added below the item it's added to
	menu.getRoot().add(miFile); 
	//add all items below File to the file menu item, 
	//notice the arduino isp item is added _to the right_ of the examples item
	miFile.add(miNew).add(miOpen).add(miExamples).addRight(miArduinoISP);
	//because edit item is to the right of the file item, we use the addRight method when inserting this item
	//then we add the cut item, because it is below the edit
	miFile.addRight(miEdit).add(miCut);
	miEdit.addRight(miSkecth).add(miVerify);
	miSkecth.addRight(miTools).add(miAutoformat);
	miTools.addRight(miHelp).add(miEnvironment);
}

/*
	This is an important function
	Here all use events are handled
	
	This is where you define a behaviour for a menu item
*/
void menuUseEvent(MenuUseEvent used)
{
	Serial.print("Menu use ");
	Serial.println(used.item.getName());
	if (used.item == "ArduinoISP") //comparison using a string literal
	{
		Serial.println("menuUseEvent found ArduinoISP");
	}
	if (used.item == miVerify) //comparison agains a known item
	{
		Serial.println("menuUseEvent found Verify (V)");
	}
}

/*
	This is an important function
	Here we get a notification whenever the user changes the menu
	That is, when the menu is navigated
*/
void menuChangeEvent(MenuChangeEvent changed)
{
	Serial.print("Menu change ");
	Serial.print(changed.from.getName());
	Serial.print(" ");
	Serial.println(changed.to.getName());
}

void setup()
{
	Serial.begin(9600);
	
	menuSetup();
	Serial.println("Starting navigation (see source for description):");

	menu.moveDown();  //move to file
	menu.moveDown();  //move to new
	menu.moveDown();  //move to open
	menu.moveDown();  //move to examples
	menu.moveRight(); //move to arduinoisp
	menu.use();       //use arduniisp
	menu.moveLeft();  //move to examples
	menu.moveUp();    //move to open
	menu.moveUp();    //move to new
	menu.moveUp();    //move to file
	menu.moveRight(); //move to edit
	menu.moveRight(); //move to sketch
	menu.moveDown();  //move to verify
	menu.use();       //use verify
	menu.moveBack();  //move back to sketch
	menu.moveBack();  //move back to edit
	menu.moveBack();  //move back to file
	menu.moveBack();  //move back to new
	menu.use();       //use new

	menu.use('V');    //use verify based on its shortkey 'V'
}

void loop()
{
  //
}


