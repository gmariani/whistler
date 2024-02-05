import flash.display.Sprite;
import flash.filesystem.FileMode;
import flash.filesystem.FileStream;
import flash.filesystem.File;
import flash.net.FileFilter;
import flash.errors.EOFError;
import flash.events.Event;
		
private var fileSOL:File = new File();

public function SharedObjectEditor():void {
	init();
}

private function init():void {
	
	browse();
}

private function browse():void {
	var fileFilters:Array = new Array();
	fileFilters.push(new FileFilter("SOL Files", "*.sol", "SOL"));
	fileSOL.addEventListener(Event.SELECT, onFileSelection);
	fileSOL.browse(fileFilters);
}

private function onFileSelection(e:Event):void {
	var objData:Object = new Object();
	var bytes:FileStream = new FileStream();
	bytes.open(fileSOL, FileMode.READ);

	// Read SOL Header
	var fileName:String = getFileName(bytes);
	bytes.position += 4; // In AS3, format is different
	
	// Get Variables
	var getNext:Boolean = true;
	while(getNext != false) {
		try {
			bytes.readByte(); // If EOF, this will fail
			bytes.position--; // reset reader position
			getVariable(bytes, objData);
		} catch(e:EOFError) {
			getNext = false;
		}
	}
}

private function getFileName(by:FileStream):String {
	var fileSize = by.readInt();
	by.position = 16;
	var fileName = by.readUTFBytes(by.readUnsignedShort());
	return fileName;
}

private function getArrayValue(by:FileStream):* {
	var varIdx:String = by.readUTFBytes(by.readUnsignedShort());
	var varType:int = by.readByte();
	var valReturn:* = returnValue(varType, by);
	// No Ending Byte in Arrays
	by.position--;
	return valReturn;
}

private function getObjectValue(by:FileStream):Array {
	var arrReturn:Array = new Array();
	var varName:String = by.readUTFBytes(by.readUnsignedShort());
	var varType:int = by.readByte();
	arrReturn.push(varName);
	arrReturn.push(returnValue(varType, by));
	// No Ending Byte in Objects
	by.position--;
	return arrReturn;
}

private function getVariable(by:FileStream, o:Object):void {
	var varNameLen:int = by.readUnsignedShort();
	var varName:String = by.readUTFBytes(varNameLen);
	var varType:int = by.readByte();
	var varVal:* = returnValue(varType, by);
	trace(varName + " = '" + varVal + "'");
	
	o[varName] = varVal;
}

private function returnValue(varType:int, by:FileStream):* {
	var varVal:*;
	
	switch(varType) {
		case 0:
			// Number
			varVal = by.readDouble();
			break;
		case 1:
			// Boolean
			varVal = by.readBoolean();
			break;
		case 2:
			// String
			varVal = by.readUTFBytes(by.readUnsignedShort());
			break;
		case 16:
			// Object CustomClass
			trace("Custom Class");
			var classID:String = by.readUTFBytes(by.readUnsignedInt());
			// Skip down to object and continue as if it's an object
		case 3:
			// Object
			varVal = new Object();
			var getNext = true;
			while(getNext != false) {
				// End tag 00 00 09
				var endTag = by.readByte() + by.readByte() + by.readByte();
				if(endTag != 9) {
					by.position -= 3;
					var objVal:Array = getObjectValue(by);
					varVal[objVal[0]] = objVal[1];
					trace(" - " + objVal[0] + " = " + objVal[1]);
				} else {
					getNext = false;
				}
			}
			break;
		case 5:
			// Null
			varVal = null;
			break;
		case 6:
			// Undefined
			varVal = undefined;
			break;
		case 8:
			// Array
			var al:uint = by.readUnsignedInt();
			varVal = new Array();
			for(var j:int = 0; j < al; j++) {
				varVal[j] = getArrayValue(by);
			}
			
			// End tag 00 00 09
			by.position += 3;
			break;
		case 10:
			// Raw Array (amf only)
			trace("Raw Array (AMF Only)");
			break;
		case 11:
			// Date
			var str:String = String(by.readDouble());
			var arrDate:Array = str.split(".");
			var millisec:Number = arrDate[0];
			var twentyFourHours:int = arrDate[1]; 
			
			//var timezone:int = (by.readShort()) * -60;
			//var timezone:int = by.readByte() + by.readByte();
			//var timezone:int = 0;
			
			varVal = new Date();
			varVal.setTime(millisec);
			break;
		case 13:
			// Object String, Number, Boolean, TextFormat
			trace("Object String, Number, Boolean, TextFormat");
			break;
		case 15:
			// XML
			var strXML:String = by.readUTFBytes(by.readUnsignedInt());
			varVal = new XML(strXML);
			break;
	}
	
	by.readByte(); // Ending byte
	return varVal;
}
