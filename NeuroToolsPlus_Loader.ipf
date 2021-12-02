#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later


//Inserts menu for loading NeuroTools+
Menu "NeuroTools+"
	"Load NeuroTools+",NTP_InsertIncludes()
	"Load NeuroLive",NTP_LoadNeuroLive()
	MigrateDataSetEntry(),MigrateDataSets()
End

Function/S MigrateDataSetEntry()
	String status = ""
	
	If(Exists("LoadNeuroPlus") == 6)
		status = "Migrate Data Sets"
	EndIf
	
	return status
End

Function NTP_LoadNeuroLive()
	Execute/P "INSERTINCLUDE \"" + "NeuroLive" + "\"" 
	//compile
	Execute/P "COMPILEPROCEDURES "
	
	//Load the NeuroTools+ Package
	Execute/P "Load_NeuroLive()"
End

//Gathers dependencies and loads the toolbox
Function NTP_InsertIncludes()
	String fileList = "NeuroToolsPlus;NTP_Common;NTP_Controls;NTP_DataSets;NTP_Functions;NTP_ExternalFunctions;NTP_Structures;json_functions;NTP_ABF_loader;NTP_Presentinator;NTP_ScanImage_Package;NTP_ScanImageTiffReader;"
	
	//Get use installed package files
	String userFunctionPath = SpecialDirPath("Igor Pro User Files",0,0,0)	
	userFunctionPath += "User Procedures:NeuroTools+:Functions"
	
	GetFileFolderInfo/Q/Z userFunctionPath
	If(!V_flag)
		NewPath/O/Q userPath,userFunctionPath
	
		If(V_isFolder)
			String userFileList = IndexedFile(userPath,-1,".ipf")
			fileList += userFileList
		EndIf
	EndIf

	
	//remove potential dependencies for old NeuroTools version
	String removeList = "NT_Loader;Load_NeuroTools;NT_Common;NT_Controls;NT_DataSets;NT_ScanImage_Package;ScanImageTiffReader;NT_Image_Registration;NT_Functions;NT_InsertTemplate;NT_ExternalFunctions;NT_Structures;json_functions;NT_ABF_loader;NT_Presentinator;NT_ScanImage_Package;NT_ScanImageTiffReader;"
	
	Variable numFiles,i
	String theFile
	
	String info = IgorInfo(0)
	Variable version = str2num(StringByKey("IGORVERS",info,":",";"))
	
	If(version < 8)
		fileList = RemoveFromList("json_functions",fileList,";")
	EndIf
	
	numFiles = ItemsInList(fileList,";") 
	
	Variable numRemoveFiles = ItemsInList(removeList,";")
	
	//Kill the old NeuroTools panel if it exists
	KillWindow/Z NT //main NeuroTools window
	KillWindow/Z SI //scanimage image browser
	
	//Close the proc windows if they are open
	String procList = WinList("*",";","WIN:128")
	
	For(i=0;i<numRemoveFiles;i+=1)
		theFile = StringFromList(i,removeList,";") + ".ipf"
		
		//check if the proc window exists
		If(WhichListItem(theFile,procList,";") != -1)
			Execute/Z/P/Q "CloseProc/NAME=\"" + theFile + "\"" 
		EndIf	
	EndFor
	
	//Remove old dependencies
	For(i=0;i<numRemoveFiles;i+=1)
		theFile = StringFromList(i,removeList,";")
		theFile = RemoveEnding(theFile,".ipf")
		Execute/P "DELETEINCLUDE \"" + theFile + "\"" 
	EndFor
	
	
	//add new dependencies
	For(i=0;i<numFiles;i+=1)
		theFile = StringFromList(i,fileList,";")
		theFile = RemoveEnding(theFile,".ipf")
		
		Execute/P "INSERTINCLUDE \"" + theFile + "\"" 
	EndFor
	
	//compile
	Execute/P "COMPILEPROCEDURES "
	
	//Load the NeuroTools+ Package
	Execute/P "LoadNeuroPlus()"
	
End