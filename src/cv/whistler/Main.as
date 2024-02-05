import com.google.analytics.AnalyticsTracker;
import com.google.analytics.GATracker;

import cv.managers.UpdateManager;

import flash.events.Event;
import flash.filesystem.File;
import flash.filesystem.FileMode;
import flash.filesystem.FileStream;
import flash.net.SharedObject;
import flash.net.URLRequest;
import flash.net.navigateToURL;
import flash.system.Capabilities;
import flash.utils.clearTimeout;
import flash.utils.setTimeout;

import mx.collections.ArrayCollection;
import mx.events.FlexEvent;
import mx.events.ItemClickEvent;

private var os:String;
private var tracker:AnalyticsTracker;
private var um:UpdateManager;
private var aboutWin:AboutWindow;
private var updateWin:UpdateWindow;
private var updateScroll:Boolean = true;
private var filePolicyLog:File;
private var fileTraceLog:File;
private var fileCurrentLog:File;
private var fileMM:File;
private var fs:FileStream = new FileStream();
private var defTimeout:int = 50;
private var timeout:int = 50;
private var readInterval:int;
private var logIndex:int = 0;
private var bufferCache:String;
private var hasLogChanged:Boolean = false;
private var hasFilterChanged:Boolean = false;
private var logStatus:Array = [
	{type:"trace", selected:true, buffer:"", lastModifiedTime:null, fileSize:null, paused:false},
	{type:"policy", selected:false, buffer:"", lastModifiedTime:null, fileSize:null, paused:false}
];

[Embed(source="assets/icons/pause.png")]
[Bindable]
public var pauseIcon:Class;

[Embed(source="assets/icons/play.png")]
[Bindable]
public var playIcon:Class;

[Embed(source="assets/icons/open.png")]
[Bindable]
public var openIcon:Class;

[Embed(source="assets/icons/clear.png")]
[Bindable]
public var clearIcon:Class;

[Embed(source="assets/icons/errorIcon.png")]
[Bindable]
public var errorIcon:Class;

[Embed(source="assets/icons/warningIcon.png")]
[Bindable]
public var warningIcon:Class;

[Embed(source="assets/icons/infoIcon.png")]
[Bindable]
public var infoIcon:Class;

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

// TODO: Figure out if we can detect flash player version within air - No

// TODO: AIR2 automatically download and install the debug player (Would need to use NativeProcess)
// Netscape - Win 	/ http://download.macromedia.com/pub/flashplayer/updaters/10/flashplayer_10_ax_debug.exe
// IE - Win 		/ http://download.macromedia.com/pub/flashplayer/updaters/10/flashplayer_10_plugin_debug.exe
// Mac 				/ http://download.macromedia.com/pub/flashplayer/updaters/10/flashplayer_10_plugin_debug_ub.dmg
// Linux 			/ http://download.macromedia.com/pub/flashplayer/updaters/10/flash_player_10_linux_dev.tar.gz

private function init(e:FlexEvent):void {
	os = Capabilities.os.toLowerCase();
	if(os.indexOf("mac") != -1) {
		os = "mac";
	} else if(os.indexOf("linux") != -1) {
		os = "linux";
	} else if(os.indexOf("xp") != -1) {
		os = "win";
	} else {
		os = "winVista";
	}
	
	// Get Flash Player Directory
	var fpDirPath:String;
	switch(os) {
		case "win" :
			// C:\Documents and Settings\<user>\Application Data
			fpDirPath = File.userDirectory.resolvePath("Application Data/Macromedia/Flash Player/").url;
			break;
		case "winVista" :
			// C:\Users\<user>\AppData\Roaming
			fpDirPath = File.userDirectory.resolvePath("AppData/Roaming/Macromedia/Flash Player/").url;
			break;
		case "mac" :
			// /User/<user>/Library/Preferences
			fpDirPath = File.userDirectory.resolvePath("Library/Preferences/Macromedia/Flash Player/").url;
			break;
		case "linux":
			// /home/<user>
			fpDirPath = File.userDirectory.resolvePath(".macromedia/Flash_Player/").url;
			break;
	}
	
	/*
	File.userDirectory
	C:\Documents and Settings\<user>
	C:\Users\<user>
	/Users/<user>
	*/
	
	// Get Flash Log
	fileTraceLog = new File(fpDirPath + "/Logs/flashlog.txt");
	
	// Get Policy Log
	filePolicyLog = new File(fpDirPath + "/Logs/policyfiles.txt");
	
	// Get mm.cfg
	switch(os) {
		case "win" :
			// C:\Documents and Settings\<user>
			fileMM = File.userDirectory.resolvePath("mm.cfg");
			break;
		case "winVista" :
			// C:\Users\<user>
			fileMM = File.userDirectory.resolvePath("mm.cfg");
			break;
		case "mac" :
			// /Library/Application Support/Macromedia
			fileMM = File.userDirectory.resolvePath("Library/Application Support/Macromedia/mm.cfg");
			break;
		case "linux":
			// /home/<user>
			fileMM = File.userDirectory.resolvePath("mm.cfg");
			break;
	}
	
	// Load prefs
	var so:SharedObject = SharedObject.getLocal("whistler");
	if(so.data.hasOwnProperty("wordWrap")) {
		cbWrap.selected = so.data.wordWrap;
		cbLock.selected = so.data.autoScroll;
		cbTop.selected = so.data.onTop;
		ddSize.selectedIndex = so.data.fontSize;
		onCloseDD();
	}
	
	this.alwaysInFront = cbTop.selected;
	
	if (!fileMM.exists) saveMMFile(true);
	readMMFile();
	
	// Based on toggle bar
	fileCurrentLog = fileTraceLog; 
	
	readInterval = setTimeout(updateLog, timeout);
	
	// Init Updater
	um = UpdateManager.instance;
	um.addEventListener(UpdateManager.AVAILABLE, updateHandler, false, 0, true);
	um.updateURL = "http://www.coursevector.com/projects/whistler/update.xml";
	um.checkNow();
}

private function initTracker():void {
	// Analytics
	tracker = new GATracker(this, "UA-349755-7", "AS3", false);
	tracker.trackPageview("/whistler/" + UpdateManager.instance.currentVersion + "/MainScreen");
	tracker.trackEvent(".whistler-" + UpdateManager.instance.currentVersion, "flashPlayerDir", os, -1);
}

private function updateHandler(event:Event = null):void {
	updateWin = new UpdateWindow();
	updateWin.open();
}

private function readMMFile():void {
	if(fileMM.exists && fileMM.size != 0) {
		var fs:FileStream = new FileStream();
		fs.open(fileMM, FileMode.READ);
		var str:String = fs.readUTFBytes(fs.bytesAvailable);
		fs.close();
		str = str.replace(File.lineEnding, "\n");
		
		// Regex to populate settings
		var regex:RegExp = /^ErrorReportingEnable=([01])/gm;
		var result:Object = regex.exec(str);
		cbWarnings.selected = Boolean(result[1] == 1);
		
		regex = /^MaxWarnings=(\d+)/gm;
		result = regex.exec(str);
		nsWarnings.value = uint(result[1]);
				
		regex = /^PolicyFileLog=([01])/gm;
		result = regex.exec(str);
		cbPolicyLogging.selected = Boolean(result[1] == 1);
		
		regex = /^PolicyFileLogAppend=([01])/gm;
		result = regex.exec(str);
		cbPolicyAppend.selected = Boolean(result[1] == 1);
		
		regex = /^TraceOutputBuffered=([01])/gm;
		result = regex.exec(str);
		cbTraceBuffered.selected = Boolean(result[1] == 1);
		
		regex = /^AS3Verbose=([01])/gm;
		result = regex.exec(str);
		cbVerbose.selected = Boolean(result[1] == 1);
		
		regex = /^AS3Trace=([01])/gm;
		result = regex.exec(str);
		cbTrace.selected = Boolean(result[1] == 1);
		
		regex = /^AS3StaticProfile=([01])/gm;
		result = regex.exec(str);
		cbStatic.selected = Boolean(result[1] == 1);
		
		regex = /^AS3DynamicProfile=([01])/gm;
		result = regex.exec(str);
		cbDynamic.selected = Boolean(result[1] == 1);
	}
}

private function saveMMFile(force:Boolean = false):void {
	if(!fileMM.exists || (fileMM.exists && fileMM.size == 0) || force) {
		
		var isFirst:Boolean = !fileMM.exists;
	
		var enableErrors:uint = cbWarnings.selected ? 1 : 0;
		var maxWarnings:int = nsWarnings.value;
		var enablePolicy:uint = cbPolicyLogging.selected ? 1 : 0;
		var enablePolicyAppend:uint = cbPolicyAppend.selected ? 1 : 0;
		var enableOutputBuff:uint = cbTraceBuffered.selected ? 1 : 0;
		var enableVerbose:uint = cbVerbose.selected ? 1 : 0;
		var enableTrace:uint = cbTrace.selected ? 1 : 0;
		var enableStatic:uint = cbStatic.selected ? 1 : 0;
		var enableDynamic:uint = cbDynamic.selected ? 1 : 0;
		
		var str:String = "";
		str += "#flashlog";
		str += "\n# Beginning with the Flash Player 9 Update, Flash Player ignores the TraceOutputFileName property.";
		str += "\n# On Macintosh OS X, you should use colons to separate directories in the TraceOutputFileName path rather than slashes.";
		str += "\nTraceOutputFileName=" + fileTraceLog.nativePath + " # Set TraceOutputFileName to override the default name and location of the log file";
		str += "\n";
		str += "\nErrorReportingEnable=" + enableErrors + " # Enables the logging of error messages.  0/1";
		str += "\nTraceOutputFileEnable=1 # Enables trace logging. 0/1";
		str += "\nMaxWarnings=" + maxWarnings + " # Sets the number of warnings to log before stopping.";
		str += "\n";
		str += "\n#flashlog - undocumented";
		str += "\nTraceOutputBuffered=" + enableOutputBuff + " # Traces will be buffered and write to disk multiple lines in one access";
		str += "\nAS3Verbose=" + enableVerbose + " # Traces detailed information about SWF ByteCode structure and Runtime parsing of the bytecode";
		str += "\nAS3Trace=" + enableTrace + " # Trace every single call to any function that is being called in the SWF at runtime";
		str += "\nAS3StaticProfile=" + enableStatic + " # Enables Just in Time Compiler (NanoJIT) logs.";
		str += "\nAS3DynamicProfile=" + enableDynamic + " # Shows dynamic information about the opcodes being called and gives statistic for each. The statistics include count, cycles, %count, %times and CPI";
		str += "\n";
		str += "\n#policyfiles";
		str += "\nPolicyFileLog=" + enablePolicy + " # Enables policy file logging";
		str += "\nPolicyFileLogAppend=" + enablePolicyAppend + " # Optional; do not clear log at startup";
		str = str.replace(/\r/g, File.lineEnding);
		
		try {
			var fs:FileStream = new FileStream();
			fs.open(fileMM, FileMode.WRITE);
			fs.writeUTFBytes(str);
			fs.close();
		} catch(e:Error) {
			tracker.trackEvent(".whistler-" + UpdateManager.instance.currentVersion, "error", "mm.cfg", -1);
			mx.controls.Alert.show("Cannot create the Flash Player Debugger config (mm.cfg) file in " + fileMM.parent.url + ".\n\n" + e.message );
		}

		if(isFirst)	mx.controls.Alert.show("Flash Player Debugger config (mm.cfg) file created for the first time. You may have to restart your browser for the Player to detect it and begin emitting traces.");
	}
	
	if(!fileMM.exists) {
		mx.controls.Alert.show("Flash Player Debugger config (mm.cfg) file does not exist");
		pauseLog();
	}
}

private function updateLog(e:Event = null):void {
	var str:String = "";
	
	try {
		if(logStatus[logIndex].lastModifiedTime != fileCurrentLog.modificationDate.time || logStatus[logIndex].fileSize != fileCurrentLog.size) {
			hasLogChanged = true;
			logStatus[logIndex].lastModifiedTime = fileCurrentLog.modificationDate.time;
			logStatus[logIndex].fileSize = fileCurrentLog.size;
			
			fs.open(fileCurrentLog, FileMode.READ);
			// Limit to the last 2mb
			var mbLimit:int = 2;
			var limit:Number = mbLimit * 1024 * 1024; // 2mb in bytes
			if (fs.bytesAvailable > limit) {
				logStatus[logIndex].buffer = fs.readMultiByte(limit, File.systemCharset);
				logStatus[logIndex].buffer += " ** Filesize exceeds " + mbLimit + "mb limit (" + Math.round(fs.bytesAvailable/1024/1024) + "mb); truncated. **";
			} else {
				logStatus[logIndex].buffer = fs.readMultiByte(fs.bytesAvailable, File.systemCharset);
			}
			fs.close();
		}
	} catch(e:Error) {
		pauseLog();
		tracker.trackEvent(".whistler-" + UpdateManager.instance.currentVersion, "error", "ReadFile", -1);
		mx.controls.Alert.show(e.message + "\n\n" + fileCurrentLog.url, "Error Reading File");
	}
	
	var strFilter:String = txtFilter.text.toLowerCase();
	if(strFilter != "" && (hasFilterChanged || hasLogChanged)) {
		var arrLines:Array = logStatus[logIndex].buffer.split(File.lineEnding);
		var l:int = arrLines.length;
		var i:int = 0;
		var regex:RegExp = new RegExp(strFilter, "i");
		var foundItems:Boolean = false;
		
		while(l--) {
			if(String(arrLines[i]).search(regex) != -1) {
				str += arrLines[i] + "\n";
				foundItems = true;
			}
			i++;
		}
		
		// Set BG based on filter results
		if(foundItems) {
			txtFilter.clearStyle("styleName");
		} else {
			txtFilter.setStyle("styleName", "bgRedSkin");
		}
	} else {
		txtFilter.clearStyle("styleName");
		str = logStatus[logIndex].buffer.replace(File.lineEnding, "\n");
	}
	
	// Remove double spaces from AIR
	str = str.replace(/\x0D$/gm, '');
	
	if((hasLogChanged || hasFilterChanged) && bufferCache != str) {
		bufferCache = taBuffer.text = str;
	}
	if(cbLock.selected) taBuffer.verticalScrollPosition = taBuffer.maxVerticalScrollPosition;
	
	// Reset
	hasLogChanged = false;
	hasFilterChanged = false;
	
	// If playing
	if(!logStatus[logIndex].paused && logStatus[logIndex].selected) {
		timeout = hasLogChanged ? defTimeout : 1000;
		playLog();
	}
}

private function onChangeFilter(e:Event):void {
	hasFilterChanged = true;
}

private function onClickPausePlay():void {
	if(btnPausePlay.label == "Pause") {
		pauseLog();
	} else {
		playLog();
	}
}

private function onClickAbout():void {
	aboutWin = new AboutWindow();
	aboutWin.open();
}

private function pauseLog():void {
	logStatus[logIndex].paused = true;
	clearTimeout(readInterval);
	btnPausePlay.label = "Play";
	btnPausePlay.toolTip = "Resume Log Updates";
	btnPausePlay.setStyle("icon", playIcon);
}

private function playLog():void {
	logStatus[logIndex].paused = false;
	clearTimeout(readInterval);
	readInterval = setTimeout(updateLog, timeout);
	
	btnPausePlay.label = "Pause";
	btnPausePlay.toolTip = "Pause Log Updates";
	btnPausePlay.setStyle("icon", pauseIcon);
}

private function onClickClear():void {
	try {
		fs.open(fileCurrentLog, FileMode.WRITE);
	    fs.writeMultiByte("", File.systemCharset);
	    fs.close();
	    //mx.controls.Alert.show("Log cleared");
	 } catch(e:Error) {
		tracker.trackEvent(".whistler-" + UpdateManager.instance.currentVersion, "error", "ClearFile", -1);
	 	mx.controls.Alert.show(e.message + "\n\n" + fileCurrentLog.url, "Error Clearing File");
	 }
    
    clearTimeout(readInterval);
	readInterval = setTimeout(updateLog, timeout);
	updateLog();
}

private function onClickOpen():void {
	fileCurrentLog.openWithDefaultApplication();
}

private function onClickTab(e:ItemClickEvent):void {
	var tabLabel:String = e.label.toLowerCase();
	if(tabLabel == "trace") {
		fileCurrentLog = fileTraceLog;
		logIndex = 0;
		logStatus[0].selected = true;
		logStatus[1].selected = false;
	} else {
		fileCurrentLog = filePolicyLog;
		logIndex = 1;
		logStatus[0].selected = false;
		logStatus[1].selected = true;
	}
	
	hasLogChanged = true;
	updateLog();
	
	if(logStatus[logIndex].paused) {
		pauseLog();
	} else {
		playLog();
	}
}

private function onClickOptions():void {
	vsMain.selectedChild = TracerOptions;
	tracker.trackPageview("/whistler/" + UpdateManager.instance.currentVersion + "/OptionsScreen");
}

// Options
private function onCloseDD(e:Event = null):void {
	taBuffer.setStyle("fontSize", ddSize.selectedItem.data);
}

private function onClickWrap(e:Event):void {
	taBuffer.wordWrap = e.currentTarget.selected;
}

private function onClickDownload():void {
	tracker.trackEvent(".whistler-" + UpdateManager.instance.currentVersion, "link", "FlashDownload", -1);
	navigateToURL(new URLRequest("http://www.adobe.com/support/flashplayer/downloads.html"),"_blank");
}

private function onClickVersion():void {
	tracker.trackEvent(".whistler-" + UpdateManager.instance.currentVersion, "link", "FlashAbout", -1);
	navigateToURL(new URLRequest("https://www.adobe.com/software/flash/about/"),"_blank");
}

private function onClickReference():void {
	tracker.trackEvent(".whistler-" + UpdateManager.instance.currentVersion, "link", "FPSecurity", -1);
	navigateToURL(new URLRequest("http://www.adobe.com/devnet/flashplayer/articles/fplayer9_security_07.html"), "_blank");
}

private function onClickOk():void {
	saveMMFile(true);
	
	// Save Pref via Shared Object
	var so:SharedObject = SharedObject.getLocal("whistler");
	so.data.wordWrap = cbWrap.selected;
	so.data.autoScroll = cbLock.selected;
	so.data.fontSize = ddSize.selectedIndex;
	so.data.onTop = cbTop.selected;
	
	// Toggle Always on Top
	this.alwaysInFront = cbTop.selected;
	
    try {
		so.flush(10000);
    } catch (e:Error) {
		tracker.trackEvent(".whistler-" + UpdateManager.instance.currentVersion, "error", "SavePref", -1);
		mx.controls.Alert.show("Error saving preferences", 'Error');
    }
	
	tracker.trackPageview("/whistler/" + UpdateManager.instance.currentVersion + "/MainScreen");
	vsMain.selectedChild = TracerMain;
}