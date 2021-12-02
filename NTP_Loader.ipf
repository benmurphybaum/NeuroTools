#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.


STRCONSTANT NTversion = "1.0"

#if(DataFolderExists("root:Packages:twoP"))
	//Adds #includes the external procedure files
	Function NT_InsertIncludes()
		String fileList = "twoP_Loader.ipf;Load_NeuroTools;NT_Common;NT_Controls;NT_DataSets;NT_Functions;NT_InsertTemplate;NT_ExternalFunctions;NT_Structures;json_functions;NT_ABF_Loader;NT_Presentinator;"
		Variable numFiles,i
		String theFile
		
		String info = IgorInfo(0)
		Variable version = str2num(StringByKey("IGORVERS",info,":",";"))
		
		If(version < 8)
			fileList = RemoveFromList("json_functions",fileList,";")
		EndIf
		
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
		String fileList = "Load_NeuroTools;NT_Common;NT_Controls;NT_DataSets;NT_Functions;NT_InsertTemplate;NT_ExternalFunctions;NT_Structures;json_functions;NT_ABF_Loader;NT_Presentinator;"
		Variable numFiles,i
		String theFile
		
		String info = IgorInfo(0)
		Variable version = str2num(StringByKey("IGORVERS",info,":",";"))
		
		If(version < 8)
			fileList = RemoveFromList("json_functions",fileList,";")
		EndIf
		
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


Menu "Macros",dynamic
	"Update NeuroTools",Update_NT()
End

//Downloads the latest package from github, puts the files in the correct places.
Function Update_NT()	
	
	String gitAddress="https://github.com/benmurphybaum/NeuroTools/archive/master.zip",gitFile="master.zip"
	
	Variable i
	String procs = "Load_NeuroTools;NT_Common;NT_Controls;NT_DataSets;NT_Functions;"
	procs += "NT_ImageRegistration;NT_InsertTemplate;NT_ScanImage_Package;NT_Imaging_Package;NT_Structures;"
	procs += "ScanImageTiffReader;NT_ExternalFunctions;"
	
	For(i=0;i<ItemsInList(procs,";");i+=1)
		String theProc = StringFromList(i,procs,";")
		Execute/Q/Z/P "DELETEINCLUDE \"" + theProc + "\""
	EndFor	
	
	
	//Move the files to the correct folders
	String path = SpecialDirPath("Desktop",0,0,0)
	
	NewPath/O desktopPath,path
	//Download the github repo as a zip file
	Print "Downloading NeuroTools..."
	URLRequest/O/FILE=gitFile/P=desktopPath url=gitAddress
	
	//Unzip the package
	Print "Updating Packages..."
	unzipArchive(path + "master.zip",path)	

	//Unzipped folder path
	String packagePath = path + "NeuroTools-master:"
	
	String IgorAppPath = SpecialDirPath("Igor Pro User Files",0,0,0)
	String UserProcPath = IgorAppPath + "User Procedures:NeuroTools:"
	NewPath/C/O/Q NTPath,UserProcPath
	
	String IgorProcPath = IgorAppPath + "Igor Procedures:"
	String IgorHelpPath = IgorAppPath + "Igor Help Files:"
	
	String UserProcedures = "Load_NeuroTools.ipf;NT_Common.ipf;NT_Controls.ipf;NT_DataSets.ipf;NT_Functions.ipf;"
	UserProcedures += "NT_ImageRegistration.ipf;NT_InsertTemplate.ipf;NT_ScanImage_Package.ipf;NT_Imaging_Package.ipf;NT_Structures.ipf;"
	UserProcedures += "ScanImageTiffReader.ipf;ReadMe.md;LICENSE;"
	
	String IgorProcedures = "NT_Loader.ipf;"
	String IgorHelpFiles = "NeuroTools_Help.ihf;"
	
	//User Procedures
	Variable numFiles = ItemsInList(UserProcedures,";")
	For(i=0;i<numFiles;i+=1)
		String fileName = StringFromList(i,UserProcedures,";")
		String filePath = packagePath + fileName
		String destPath = UserProcPath + fileName
		
		Execute/Z/Q "CloseProc/D=0/SAVE/NAME=" + fileName
		DeleteFile/Z destPath
		MoveFile/O/Z filePath as destPath
	EndFor	
	
	//Igor Procedures
	numFiles = ItemsInList(IgorProcedures,";")
	For(i=0;i<numFiles;i+=1)
		fileName = StringFromList(i,IgorProcedures,";")
		filePath = packagePath + fileName
		destPath = IgorProcPath + fileName
		
		Execute/Z/Q "CloseProc/D=0/SAVE/NAME=" + fileName
		DeleteFile/Z destPath
		MoveFile/O/Z filePath as destPath
	EndFor
	
	//Igor Help Files
	numFiles = ItemsInList(IgorHelpFiles,";")
	For(i=0;i<numFiles;i+=1)
		fileName = StringFromList(i,IgorHelpFiles,";")
		filePath = packagePath + fileName
		destPath = IgorHelpPath + fileName
		
		Execute/Z/Q "CloseHelp/D=0/NAME=" + fileName
		DeleteFile/Z destPath
		MoveFile/O/Z filePath as destPath
	EndFor
	
	//JSON XOP files
	fileName = "json_functions.ipf"
	filePath = packagePath + "JSON:procedures:" + fileName
	destPath = UserProcPath + fileName
	MoveFile/O/Z filePath as destPath
	
	fileName = "Json Help.ipf"
	filePath = packagePath + "JSON:docu:" + fileName
	destPath = IgorHelpPath + fileName
	
	Execute/Z/Q "CloseProc/D=0/SAVE/NAME=" + fileName
	DeleteFile/Z destPath
	MoveFile/O/Z filePath as destPath
	
	//32 or 64 bit Igor, and operating system information
	String info = IgorInfo(0)
	String kind = StringByKey("IGORKIND",info,":",";")
	String os = IgorInfo(2)
	
	If(!cmpstr(kind,"pro")) //32 bit
		fileName = "JSON.xop"
		String IgorExtensionsPath = IgorAppPath + "Igor Extensions:"
	ElseIf(!cmpstr(kind,"pro64")) //64 bit
		fileName = "JSON-64.xop"
		IgorExtensionsPath = IgorAppPath + "Igor Extensions (64-bit):"
	EndIf
	
	If(!cmpstr(os,"Windows"))
		If(!cmpstr(kind,"pro"))
			filePath = packagePath + "JSON:output:win:x86:" + fileName
		ElseIf(!cmpstr(kind,"pro64"))
			filePath = packagePath + "JSON:output:win:x64:" + fileName
		EndIf
	ElseIf(!cmpstr(os,"Macintosh"))
		filePath = packagePath + "JSON:output:mac:" + fileName
	EndIf
	
	destPath = IgorExtensionsPath + fileName
	DeleteFile/Z destPath
	MoveFile/O/Z filePath as destPath
	
	//Cleanup 
	DeleteFile/Z path + "master.zip"
	
	Variable secs = DateTime - Date2Secs(-1,-1,-1)
	String updateTime = Secs2Time(secs,1)
	String updateDate = Secs2Date(secs,0)
	
	print "Version: ",NTversion
	print "Last Update: ",updateDate,updateTime,"UTC"
End



//Unzips an archived file
// returns 1 for success, 0 for failure
function unzipArchive(archivePathStr, unzippedPathStr)
    string archivePathStr, unzippedPathStr
        
    string validExtensions="zip;" // set to "" to skip check
    variable verbose=0 // choose whether to print output from executescripttext
    string msg, unixCmd, cmd
        
    GetFileFolderInfo /Q/Z archivePathStr

    if(V_Flag || V_isFile==0)
        printf "Could not find file %s\r", archivePathStr
        return 0
    endif

    if(itemsInList(validExtensions) && findlistItem(ParseFilePath(4, archivePathStr, ":", 0, 0), validExtensions, ";", 0, 0)==-1)
        printf "%s doesn't appear to be a zip archive\r", ParseFilePath(0, archivePathStr, ":", 1, 0)
        return 0
    endif
    
    if(strlen(unzippedPathStr)==0)
        unzippedPathStr=SpecialDirPath("Desktop",0,0,0)+ParseFilePath(3, archivePathStr, ":", 0, 0)
        sprintf msg, "Unzip to %s:%s?", ParseFilePath(0, unzippedPathStr, ":", 1, 1), ParseFilePath(0, unzippedPathStr, ":", 1, 0)
        doALert 1, msg
        if (v_flag==2)
            return 0
        endif
    else
        GetFileFolderInfo /Q/Z unzippedPathStr
        if(V_Flag || V_isFolder==0)
            sprintf msg, "Could not find unzippedPathStr folder\rCreate %s?", unzippedPathStr
            doalert 1, msg
            if (v_flag==2)
                return 0
            endif
        endif   
    endif
    
    // make sure unzippedPathStr folder exists - necessary for mac
    newpath /C/O/Q acw_tmpPath, unzippedPathStr
    killpath /Z acw_tmpPath

    if(stringmatch(StringByKey("OS", igorinfo(3))[0,2],"Win")) // Windows
        // The following works with .Net 4.5, which is available in Windows 8 and up.
        // current versions of Windows with Powershell 5 can use the more succinct PS command 
        // 'Expand-Archive -LiteralPath C:\archive.zip -DestinationPath C:\Dest'
        
        string strVersion=StringByKey("OSVERSION", igorinfo(3))
        variable WinVersion=str2num(strVersion) // turns "10.1.2.3" into 10.1 and 6.23.111 into 6.2 (windows 8.0)
        if (WinVersion<6.2) // https://docs.microsoft.com/en-us/windows/win32/sysinfo/operating-system…
            print "unzipArchive requires Windows 8 or later"
            return 0
        endif
        
        archivePathStr=parseFilePath(5, archivePathStr, "\\", 0, 0)
        unzippedPathStr=parseFilePath(5, unzippedPathStr, "\\", 0, 0)
        
        cmd = "powershell.exe -nologo -noprofile -command Remove-Item -path '%s' -recurse"
        sprintf cmd,cmd,unzippedPathStr + "NeuroTools-master"
        executescripttext/B/UNQ/Z cmd
        
        cmd="powershell.exe -nologo -noprofile -command \"& { Add-Type -A 'System.IO.Compression.FileSystem';"
        sprintf cmd "%s [IO.Compression.ZipFile]::ExtractToDirectory('%s', '%s'); }\"", cmd, archivePathStr, unzippedPathStr
    else // Mac
        sprintf unixCmd, "unzip %s -d %s", ParseFilePath(5, archivePathStr, "/", 0,0), ParseFilePath(5, unzippedPathStr, "/", 0,0)
        sprintf cmd, "do shell script \"%s\"", unixCmd
    endif
    
    executescripttext /B/UNQ/Z cmd
    if(verbose)
        print S_value // output from executescripttext
    endif
    
    return (v_flag==0)
end