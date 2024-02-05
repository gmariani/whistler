import flash.events.Event;
import flash.filesystem.File;
import flash.filesystem.FileMode;
import flash.filesystem.FileStream;
import flash.utils.ByteArray;

import mx.collections.ArrayCollection;
import mx.controls.ComboBox;
import mx.events.FlexEvent;

private var updateScroll:Boolean = true;
private var fileSOL:File = new File();
private var fileRef:File = File.userDirectory;
private var fileStream:FileStream = new FileStream();
private var strOS:String;
private var isOpen:Boolean = false;
private var bytes:ByteArray = new ByteArray();

[Bindable]
public var FONT_SIZES:ArrayCollection = new ArrayCollection(
	[{label:"6", data:6},
	{label:"7", data:7},
	{label:"8", data:8},
	{label:"9", data:9},
	{label:"10", data:10},
	{label:"11", data:11},
	{label:"12", data:12},
	{label:"13", data:13},
	{label:"14", data:14},
	{label:"15", data:15},
	{label:"16", data:16} ]);
// Todo: Read/Edit mm.cfg file to enable or disable errors
/*
Macintosh OS X - MacHD:Library:Application Support:macromedia:mm.cfg 
Microsoft Windows XP - C:\Documents and Settings\user_name\mm.cfg
Windows 2000 - C:\mm.cfg
Linux - ~/.macromedia/Flash_Player/Logs/mm.cfg

mm.cfg
ErrorReportingEnable   1 to enable, 0 to disable def 0
MaxWarnings  def 100  set to 0 to remove limit
TraceOutputFileEnable  1 to enable, 0 to disable def 0
*/

private function init(e:FlexEvent):void {
	var strUserDir:String = fileRef.url;
	
	// Find location of flashlog.txt
	fileRef = fileRef.resolvePath(strUserDir + "/Application Data/Macromedia/Flash Player/Logs/flashlog.txt"); // Win
	if(fileRef.exists) {
		strOS = "Win";
	} else {
		fileRef = fileRef.resolvePath(strUserDir + "/Library/Preferences/Macromedia/Flash Player/Logs/flashlog.txt"); // Mac
		if(fileRef.exists) {
			strOS = "Mac";
		} else {
			fileRef = fileRef.resolvePath(strUserDir + "/.macromedia/Flash_Player/Logs/flashlog.txt"); // Linux
			strOS = "Linux";
		}
	}
	
	updateLog();
	addEventListener(Event.ENTER_FRAME, onEnterFrame);
}

private function updateLog():void {
	if(isOpen == false) {
		isOpen = true;
		
		fileStream.open(fileRef, FileMode.READ);
		var str:String = fileStream.readMultiByte(fileStream.bytesAvailable, File.systemCharset);
		str = str.replace(/[\r\n]$/gm, "");
		taBuffer.text = str;
		fileStream.close();
		isOpen = false;
		
		// asynchronously
		//fileStream.addEventListener(ProgressEvent.PROGRESS, readProgressHandler);
		//fileStream.addEventListener(Event.COMPLETE, readCompleteHandler);
		//fileStream.addEventListener(IOErrorEvent.IO_ERROR, readIOErrorHandler);
		//fileStream.openAsync(fileRef, FileMode.READ); // .open
	}
}

private function readCompleteHandler(e:Event):void {
	var str:String = fileStream.readMultiByte(fileStream.bytesAvailable, File.systemCharset);
	trace("complete", str);
	taBuffer.text += "\n" + str;
	fileStream.close();
	isOpen = false;
}

private function readProgressHandler(e:ProgressEvent):void {
	fileStream.readBytes(bytes, fileStream.position, fileStream.bytesAvailable);
	var str:String = bytes.readMultiByte(bytes.length, File.systemCharset);
	trace("progress", str);
	taBuffer.text += "\n" + str;
}

private function readIOErrorHandler(e:IOErrorEvent):void {
	taBuffer.text = "Error reading file";
}

private function onClickClear():void {
	taBuffer.text = "";
}

private function onClickLock():void {
	updateScroll = !updateScroll;
}

private function onClickOptions():void {
	vsMain.selectedChild = TracerOptions;
}

private function onClickPause():void {
	//
}

private function onClickBrowse():void {
	/*var fileFilters:Array = new Array();
	fileFilters.push(new FileFilter("SOL Files", "*.sol", "SOL"));
	fileSOL.addEventListener(Event.SELECT, onFileSelection);
	fileSOL.browse(fileFilters);*/
}

private function onClickDownload():void {
	navigateToURL(new URLRequest("http://www.adobe.com/support/flashplayer/downloads.html"),"_blank"); 
}

private function onClickSave():void {
	vsMain.selectedChild = TracerMain;
}

private function onClickCancel():void {
	vsMain.selectedChild = TracerMain;
}

private function onClickWrap(e:Event):void {
	taBuffer.wordWrap = e.currentTarget.selected;
}

private function onEnterFrame(e:Event):void {
	updateLog();
}

private function onCloseDD(e:Event):void {
	taBuffer.setStyle("fontSize", ComboBox(e.target).selectedItem.data);
}

/*private function onFileSelection(e:Event):void {
	var objData:Object = new Object();
	var bytes:FileStream = new FileStream();
	bytes.open(fileSOL, FileMode.READ);
	
	// Start reading in text
}*/