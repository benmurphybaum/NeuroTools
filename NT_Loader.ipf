﻿#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#if(DataFolderExists("root:Packages:twoP"))
	//Adds #includes the external procedure files
	Function NT_InsertIncludes()
		String fileList = "twoP_Loader.ipf;Load_NeuroTools;NT_Common;NT_Controls;NT_DataSets;NT_Functions;NT_InsertTemplate;NT_ExternalFunctions;NT_Structures;"
		Variable numFiles,i
		String theFile
		
		numFiles = ItemsInList(fileList,";")
		
		For(i=0;i<numFiles;i+=1)
			theFile = StringFromList(i,fileList,";")
			theFile = RemoveEnding(theFile,".ipf")
			Execute/P "INSERTINCLUDE \"" + theFile + "\"" 
		EndFor
		Execute/P "COMPILEPROCEDURES "
		
		//Load the NeuroTools Package
		Execute/P "LoadNT()"
		
	End
#else
	//Adds #includes the external procedure files
	Function NT_InsertIncludes()
		String fileList = "Load_NeuroTools;NT_Common;NT_Controls;NT_DataSets;NT_Functions;NT_InsertTemplate;NT_ExternalFunctions;NT_Structures;"
		Variable numFiles,i
		String theFile
		
		numFiles = ItemsInList(fileList,";")
		
		For(i=0;i<numFiles;i+=1)
			theFile = StringFromList(i,fileList,";")
			theFile = RemoveEnding(theFile,".ipf")
			Execute/P "INSERTINCLUDE \"" + theFile + "\"" 
		EndFor
		Execute/P "COMPILEPROCEDURES "
		
		//Load the NeuroTools Package
		Execute/P "LoadNT()"
	End
#endif

#if(!cmpstr(IgorInfo(2),"Macintosh"))
	StrConstant LIGHT = "Roboto Light"
	StrConstant REG = "Roboto"
	StrConstant TITLE = "Bodoni 72 Smallcaps"
	StrConstant SUBTITLE = "Bodoni 72 Oldstyle"
#else
	StrConstant LIGHT = "Roboto Light"
	StrConstant REG = "Roboto"
	StrConstant TITLE = "Mongolian Baiti"
	StrConstant SUBTITLE = "Mongolian Baiti"
#endif

//Setup menu for loading NT
Menu "Analysis", dynamic
	Submenu "Packages"
		 "Load_NeuroTools",NT_InsertIncludes()
	End
End
