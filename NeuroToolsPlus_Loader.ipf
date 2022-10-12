#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
#pragma IndependentModule = NTP

STRCONSTANT NTPVERSION = "3.11"

Function/S Version()
	return NTPVERSION
End

//Inserts menu for NeuroTools+ options
Menu "NeuroTools+",dynamic
	
	HideShowTitle(),/Q,DoHideShow()
	"Load NeuroTools",/Q,NTP_InsertIncludes()
	CheckNeuroLive(),/Q,NTP_LoadNeuroLive()
	MigrateDataSetEntry(),/Q,MigrateDataSets()
	"Reset NeuroTools",/Q,NTP_RemoveIncludes()
	
	MenuSwitch("Image Browser/1"),/Q,OpenImageBrowser()
	"-"
	
	SubMenu "Packages Files"
		GetUserPackages(fullIPFList=1,includesOnly=1),/Q,GoToProc()
	End
	
	SubMenu "Update Packages"
		ReplaceString(".ipf",GetUserPackages(),""),/Q,UpdateUserPackage()
	End
	
//	SubMenu "Data Sets"
//		"New Data Table",NewDataTable()
//	End
	
	MenuSwitch("Manage Packages"),/Q,ManagePackages()
	
	"-"
	
	"Report a bug",/Q,ReportBug()
	
	"Check for updates...",/Q,CheckForUpdates(fromMenu=1)
	"About...",/Q,DisplayVersion()
End

Function ping()
	
	//Pings the website server, no internet connection results in -1, else round trip time in ms.
	String cmd = ""
	String unixCmd = "ping -c1 www.benmurphybaum.com"
	sprintf cmd, "do shell script \"%s\"", unixCmd
	
	ExecuteScriptText/UNQ/Z cmd
	
	Variable result = str2num(StringByKey("stddev",S_Value," = ","/"))
	
	If(numtype(result) == 2)
		result = -1
	EndIf	
	
	return result 
End

Function ReportBug()
	//Sets up an email to me about a bug in the software.
	String msg
	
	String subject = ""
	Prompt subject,"Short description of problem:"
	DoPrompt "Bug Report",subject
	subject = "Bug Report: " + subject
	String body = "*** Tell me about the bug ***"
	
	If(!V_flag)
		sprintf msg, "mailto:bmurphy.baum@gmail.com?subject=%s&body=%s&quot", subject, body
		BrowseUrl msg
	EndIf
End

Function DisplayVersion()
	String aboutStr = "NeuroTools v" + NTPVERSION + "\n"
	aboutStr += "Developed by Ben Murphy-Baum,  2017\n\n"
	aboutStr += "NeuroTools is a functional imaging and electrophysiology data analysis interface,  "
	aboutStr += "designed to improve the organization and efficiency of batch analysis routines and workflows."
	
	DoAlert/T="About NeuroTools" 0,aboutStr
End

Function/S MenuSwitch(menuTitle)
	String menuTitle
	
	DFREF NPC = root:Packages:NeuroToolsPlus:ControlWaves
	NVAR/Z isLoaded = NPC:isLoaded
	
	If(NVAR_Exists(isLoaded) && isLoaded)
		return menuTitle
	Else
		return ""
	EndIf
	
	return menuTitle
End

Function/S HideShowTitle()
	GetWindow/Z NTP hide
	
	DFREF NPC = root:Packages:NeuroToolsPlus:ControlWaves
	NVAR/Z isLoaded = NPC:isLoaded
	
	If(isLoaded)
		If(V_Value)
			return "Show/2"
		Else
			return "Hide/2"
		EndIf
	Else
		return ""
	EndIf
End

Function DoHideShow()
	GetLastUserMenuInfo
	String showhide = S_Value
	
	If(!cmpstr(showhide,"Show"))
		SetWindow NTP,hide=0
	Else
		SetWindow NTP,hide=1
	EndIf
End

Function UpdateUserPackage()
	//Updates the selected user package from the Neurotools menu
	GetLastUserMenuInfo
	String package = S_Value
	
	String ftpServer = "ftp://ftp.benmurphybaum.com/public_html/"
	
	NewPanel/K=1/N=UpdatePanel/W=(200,200,450,280) as "Package Update"
	
	SetDrawEnv/W=UpdatePanel gname=UpdateText,gstart
	SetDrawEnv/W=UpdatePanel xcoord=rel,ycoord=rel,textxjust=1,fsize=16
	DrawText/W=UpdatePanel 0.5,0.5,"Downloading  " + package + " ..."
	SetDrawEnv/W=UpdatePanel gstop
	DoUpdate/W=UpdatePanel
	
	//Check if the package is a folder or a single file
	String NTPathStr = SpecialDirPath("Igor Pro User Files",0,0,0) + "User Procedures:NeuroTools+:Functions:"
	NewPath/O/Z/Q NTPath,NTPathStr
	
	String fileList = IndexedFile(NTPath,-1,".ipf")
	
	Variable isFile = WhichListItem(package + ".ipf",fileList,";")
	
	String urlStr = ""
	
	If(isFile != -1)
		urlStr = ftpServer + "NeuroTools_Functions/" + package + ".ipf"
		isFile = 1
		Variable isFolder = 0
	Else
		String folderList = IndexedDir(NTPath,-1,0)
		
		isFolder = WhichListItem(package,folderList,";")
		
		If(isFolder != -1)
			urlStr = ftpServer + "NeuroTools_Functions/" + package + ".zip"
		EndIf
		
		isFile = 0
		isFolder = 1
	EndIf
	
	If(!strlen(urlStr))
		Abort "Couldn't find the package file.  Failed to update."
		KillWindow/Z UpdatePanel
	EndIf
	
	//Download to the desktop
	If(isFolder)
		String installPathStr = SpecialDirPath("Desktop",0,0,0)	
		installPathStr += "NeuroTools Update:Packages:" + package + ".zip"
	ElseIf(isFile)
		installPathStr = SpecialDirPath("Desktop",0,0,0)	
		installPathStr += "NeuroTools Update:Packages:" + package + ".ipf"
	EndIf
		
	//Create a new folder to hold the update zip file
	String unzipPathStr = SpecialDirPath("Desktop",0,0,0)	
	unzipPathStr += "NeuroTools Update:"
	
	NewPath/C/O/Q/Z installPath,unzipPathStr
	unzipPathStr += "Packages:"
	NewPath/C/O/Q/Z installPath,unzipPathStr
	
	//Download the updated package file
	FTPDownload/V=0/P=installPath/S=0/O=1/U="benmurp1"/W="M0rphybb!!" urlStr,installPathStr
	
	DrawAction/W=UpdatePanel getgroup=UpdateText,delete
	SetDrawEnv/W=UpdatePanel gname=UpdateText,gstart
	SetDrawEnv/W=UpdatePanel xcoord=rel,ycoord=rel,textxjust=1,fsize=16
	DrawText/W=UpdatePanel 0.5,0.5,"Installing " + package + "..."
	SetDrawEnv/W=UpdatePanel gstop
	DoUpdate/W=UpdatePanel
	
	If(isFolder)
		unzipArchive(installPathStr,unzipPathStr,verbose=0)
		
		unzipPathStr += package
		
		GetFileFolderInfo/Q/Z unzipPathStr
		
		If(V_isFolder)
			NewPath/O/Q/Z installPath,unzipPathStr
			String packageFileList = IndexedFile(installPath,-1,".ipf")
			
			String packageLocation = NTPathStr + package
			
			GetFileFolderInfo/Q/Z packageLocation
			
			//If somehow this folder doesn't exist, create it
			If(!isFolder)
				NewPath/O/Q/Z/C packageLocationPath,packageLocation
			EndIf
			
			Variable i
			For(i=0;i<ItemsInList(packageFileList,";");i+=1)
				String theFile = StringFromList(i,packageFileList,";")
				CopyFile/O/D/Z/P=installPath theFile as packageLocation
			EndFor			
		EndIf
			
	ElseIf(isFile)
		GetFileFolderInfo/Q/Z installPathStr
		If(V_isFile)
			CopyFile/O/D/Z installPathStr as NTPathStr
		EndIf
	EndIf
	
	Sleep/T 30
	
	DrawAction/W=UpdatePanel getgroup=UpdateText,delete
	SetDrawEnv/W=UpdatePanel gname=UpdateText,gstart
	SetDrawEnv/W=UpdatePanel xcoord=rel,ycoord=rel,textxjust=1,fsize=16
	DrawText/W=UpdatePanel 0.5,0.5,"Installation Complete."
	SetDrawEnv/W=UpdatePanel gstop
	DoUpdate/W=UpdatePanel
	
	Sleep/T 30
	
	KillWindow/Z UpdatePanel
	
End

Function CheckForUpdates([fromMenu])
	Variable fromMenu //was this function triggered from the menu, or from the initialization?
	fromMenu = (ParamIsDefault(fromMenu)) ? 0 : fromMenu
	
	String updatePath = SpecialDirPath("Igor Pro User Files",0,0,0)	
	updatePath += "User Procedures:NeuroTools+:update.txt"
	
	String ftpServer = "ftp://ftp.benmurphybaum.com/public_html/"
	String urlStr = ftpServer + "NeuroTools_Functions/NTVERSION.txt"
	
	strswitch(IgorInfo(2))
		case "Macintosh":
			Variable isInternet = ping()
			If(isInternet == -1)
				return 0
			EndIf
			break
		case "Windows":
			break
	endswitch	
	
	FTPDownload/Z/V=0/S=0/O=1/U="benmurp1"/W="M0rphybb!!" urlStr,updatePath
	
	GetFileFolderInfo/Z/Q updatePath
	If(V_isFile)
		LoadWave/Q/J/K=2/N=updateCheck updatePath
		Wave/T updateCheck = $StringFromList(0,S_wavenames,";")
		
		If(!WaveExists(updateCheck))
			return 0
		EndIf
		
		Variable currentVersion = str2num(NTPVERSION)
		Variable availableVersion = str2num(updateCheck[0])
		
		If(currentVersion < availableVersion)
			DoAlert/T="NeuroTools Update" 1,"Update available.  Install v" + updateCheck[0] + "?"
			
			If(V_flag == 1)
				NewPanel/K=1/N=UpdatePanel/W=(200,200,450,280) as "NeuroTools Update"
				
				SetDrawEnv/W=UpdatePanel gname=UpdateText,gstart
				SetDrawEnv/W=UpdatePanel xcoord=rel,ycoord=rel,textxjust=1,fsize=16
				DrawText/W=UpdatePanel 0.5,0.5,"Downloading NeuroTools..."
				SetDrawEnv/W=UpdatePanel gstop
				DoUpdate/W=UpdatePanel
				
				//perform the download and installation routine
				urlStr = ftpServer + "NeuroTools_Functions/NeuroTools+.zip"
				
				//Download to the desktop
				String installPathStr = SpecialDirPath("Desktop",0,0,0)	
				installPathStr += "NeuroTools Update:NeuroTools_Update.zip"
				
				//Create a new folder to hold the update zip file
				String unzipPathStr = SpecialDirPath("Desktop",0,0,0)	
				unzipPathStr += "NeuroTools Update:"
				
				NewPath/C/O/Q/Z unzipPath,unzipPathStr
				
				//Download the update zip file
				FTPDownload/V=0/P=unzipPath/S=0/O=1/U="benmurp1"/W="M0rphybb!!" urlStr,installPathStr
				
				
				DrawAction/W=UpdatePanel getgroup=UpdateText,delete
				SetDrawEnv/W=UpdatePanel gname=UpdateText,gstart
				SetDrawEnv/W=UpdatePanel xcoord=rel,ycoord=rel,textxjust=1,fsize=16
				DrawText/W=UpdatePanel 0.5,0.5,"Unpackaging..."
				SetDrawEnv/W=UpdatePanel gstop
				DoUpdate/W=UpdatePanel
				
				//Unzip
				unzipArchive(installPathStr,unzipPathStr,verbose=0)
				
				unzipPathStr += "NeuroTools+:"
				
				GetFileFolderInfo/Q/Z unzipPathStr
				If(!V_isFolder)
					DoAlert/T="Update NeuroTools" 0,"Error occurred during installation."
					KillWaves/Z updateCheck
					return 0
				EndIf
				
				DrawAction/W=UpdatePanel getgroup=UpdateText,delete
				SetDrawEnv/W=UpdatePanel gname=UpdateText,gstart
				SetDrawEnv/W=UpdatePanel xcoord=rel,ycoord=rel,textxjust=1,fsize=16
				DrawText/W=UpdatePanel 0.5,0.5,"Distributing files..."
				SetDrawEnv/W=UpdatePanel gstop
				DoUpdate/W=UpdatePanel
				
				//Distribute files
				DistributeUpdateFiles(unzipPathStr)
				
				//Kill the update panel
				KillWindow/Z UpdatePanel
				KillWaves/Z updateCheck
			EndIf
		ElseIf(fromMenu)
			If(currentVersion > availableVersion)
				DoAlert/T="Update NeuroTools" 0,"Ben messed up the version number on the latest update, please email him to let him know."
			Else
				DoAlert/T="Update NeuroTools" 0,"NeuroTools v" + NTPVERSION + " is up to date."
			EndIf
		EndIf
	EndIf
	
	KillWaves/Z updateCheck
End

Function PushNTP([update,package])
	//Pushes the local distribution of NeuroTools to the benmurphybaum.com repository.
	//Find the folder with the NeuroTools package in it	
	
	Variable update
	String package 
	update = (ParamIsDefault(update)) ? 0 : 1

	Variable isInternet = ping()
	
	If(isInternet == -1)
		Abort "Couldn't push to server,  no internet connection."
	EndIf
	
	If(ParamIsDefault(package))
		package = ""
	EndIf
	
	If(!strlen(package))
		String archivePathStr = FunctionPath("")
		archivePathStr = ParseFilePath(1,archivePathStr,":",1,0)
		
		zipArchive(archivePathStr)
		
		String zipArchiveStr = RemoveEnding(archivePathStr,":") + ".zip"
		
		GetFileFolderInfo/Q/Z zipArchiveStr
		If(V_isFile)
			String ftpServer = "ftp://ftp.benmurphybaum.com/public_html/NeuroTools_Functions/NeuroTools+.zip"
			FTPUpload/O/U="benmurp1"/W="M0rphybb!!"/S=0 ftpServer,zipArchiveStr
		EndIf
	Else
		String packagePathStr = FunctionPath("")
		packagePathStr = ParseFilePath(1,packagePathStr,":",1,1)
		String packagePath = packagePathStr + package + ".ipf"
		
		
		GetFileFolderInfo/Q/Z packagePath
		If(V_isFile)
			ftpServer = "ftp://ftp.benmurphybaum.com/public_html/NeuroTools_Functions/" + package + ".ipf"
			FTPUpload/O/U="benmurp1"/W="M0rphybb!!"/S=0 ftpServer,packagePath
			DoAlert/T="Update Package: " + package 0,package + " package updated."
			return 0
		Else
			packagePath = packagePathStr + package
			GetFileFolderInfo/Q/Z packagePath
			
			packagePath = RemoveEnding(packagePath,":") + ":" //ensure ending colon
			
			print packagePath
			
			If(V_isFolder)
				zipArchive(packagePath)
				zipArchiveStr = RemoveEnding(packagePath,":") + ".zip"
				
				GetFileFolderInfo/Q/Z zipArchiveStr
				If(V_isFile)
					ftpServer = "ftp://ftp.benmurphybaum.com/public_html/NeuroTools_Functions/" + package + ".zip"
					FTPUpload/O/U="benmurp1"/W="M0rphybb!!"/S=0 ftpServer,zipArchiveStr
					
					DoAlert/T="Update Package: " + package 0,package + " package updated."
					
				Else
					DoAlert/T="Update Package: " + package 0,"Update failed. Check packages."
				EndIf
				
				
				return 0
			Else
				DoAlert/T="Update Package" 0,"Couldn't find the package, make sure it is named correctly."
				return 0
			EndIf
		EndIf
	EndIf
		
	If(update)
		//Logs an actual increment in the NTPVERSION variable, this triggers a distribution notification to users.
		String versionPath = ParseFilePath(1,archivePathStr,":",1,0) + "NTVERSION.txt"
		Variable fileRef
		
		Close/A
		
		GetFileFolderInfo/Q/Z versionPath
		If(!V_isFile)
			DoAlert/T="NeuroTools Distribution" 0,"NTVERSION not set, manually do this in the NTVERSION.txt file and try again."
			return 0
		Else
			Open fileRef as versionPath
		EndIf
		
		String versionStr
		FReadLine fileRef,versionStr
		
		If(!strlen(versionStr))
			DoAlert/T="NeuroTools Distribution" 0,"NTPVERSION not set, manually do this in the NTVERSION.txt file and try again."
			return 0
		EndIf
		
		Variable newVersion = str2num(versionStr) + 0.01
		
		FSetPos fileRef,0
		fprintf fileRef,num2str(newVersion)
		
		Close fileRef
		
		ftpServer = "ftp://ftp.benmurphybaum.com/public_html/NeuroTools_Functions/NTVERSION.txt"
		FTPUpload/O/U="benmurp1"/W="M0rphybb!!"/S=0 ftpServer,versionPath
	EndIf

End

Function DistributeUpdateFiles(NTPath)
	String NTPath //This is where the update was downloaded to
	
	//Installation routine
	
	String AppUserFiles = SpecialDirPath("Igor Application",0,0,0)
	
	//Find the Igor Pro User Procedures folder
	String IgorUserFiles = SpecialDirPath("Igor Pro User Files",0,0,0)
	String UserProcedures = IgorUserFiles + "User Procedures"
	
	//Find the Igor Procedures folder
	String IgorProcedures = IgorUserFiles + "Igor Procedures"
	
	//Find the Igor Extensions 64 folder
	String IgorExtensions64 = IgorUserFiles + "Igor Extensions (64-bit)"
	String IgorExtensions = IgorUserFiles + "Igor Extensions"
	
	//Find the Igor Help Files folder
	String IgorHelp = IgorUserFiles + "Igor Help Files"
		
	//JSON XOP
	strswitch(IgorInfo(2))
		case "Macintosh":
			String JSONXOP = NTPath + "JSON:output:mac:JSON-64.xop" 
			
		case "Windows":
			String info = IgorInfo(0)
			String kind = StringByKey("IGORKIND",info,":",";")
			
			strswitch(kind)
				case "pro64":
				case "pro64 demo":
					JSONXOP = NTPath + "JSON:output:win:x64:JSON-64.xop" 
					CopyFile/O/D/Z JSONXOP as IgorExtensions64
					break
				case "pro":
				case "pro demo":
					JSONXOP = NTPath + "JSON:output:win:x86:JSON.xop" 
					CopyFile/O/D/Z JSONXOP as IgorExtensions
					break
			endswitch
			break
	endswitch	
	
	//JSON Help file
	String JSON_Help = NTPath + "JSON:docu:Json Help.ihf"
	CopyFile/O/D/Z JSON_Help as IgorHelp
	
	//JSON functions ipf
	String JSON_Functions = NTPath + "JSON:procedures:json_functions.ipf"
	CopyFile/O/D/Z JSON_Functions as IgorProcedures
	
	//NeuroTools Loader file
	String NTLoader = NTPath + "NeuroToolsPlus_Loader.ipf"
	CopyFile/O/D/Z NTLoader as IgorProcedures
	
	//Create NeuroTools folder to hold the ipf files
	String NTFolder = UserProcedures + ":NeuroTools+:"
	NewPath/O/Q/Z/C NTFolderPath,NTFolder
	
	//Create user functions folder
	String FunctionsFolder = UserProcedures + ":NeuroTools+:Functions:"
	NewPath/O/Q/Z/C NTFunctionsPath,FunctionsFolder
	
	//Move all other ipfs into the NeuroTools home folder
	String fileList = "NeuroToolsPlus.ipf;NTP_ABF_Loader.ipf;NTP_Common.ipf;NTP_Controls.ipf;NTP_DataSets.ipf;NTP_Functions.ipf;NTP_Structures.ipf;"
	Variable i
	For(i=0;i<ItemsInList(fileList,";");i+=1)
		String theFile = StringFromList(i,fileList,";")
		String filePath = NTPath + theFile
		
		GetFileFolderInfo/Q/Z filePath
		If(V_isFile)
			CopyFile/O/D/Z filePath as NTFolder
		EndIf
	EndFor
		
	//Move the HDF5 package into place for Igor versions less than 9
	If(IgorVersion() < 9)
		String HDF5_XOP = AppUserFiles + "More Extensions (64-bit):File Loaders:HDF5-64.xop"
		String HDF5_Browser = AppUserFiles + "WaveMetrics Procedures:File Input Output:HDF5 Browser.ipf"
		
		//MacOS treats the XOP as a folder for some reason
		GetFileFolderInfo/Q/Z HDF5_XOP
		If(V_isFolder)
			CopyFolder/O/D/Z HDF5_XOP as IgorExtensions64
		Else
			CopyFile/O/D/Z HDF5_XOP as IgorExtensions64
		EndIf
		
		CopyFile/O/D/Z HDF5_Browser as IgorProcedures
	EndIf
	
	DoAlert 0,"Installation Complete!\n\nRestart Igor.\n\nOpen NeuroTools from the 'NeuroTools' menu bar."

End

Function/S CheckNeuroLive()
	
	String packages = GetUserPackages(ignoreLoad=1)
	packages = ListMatch(packages,"NeuroLive*",";")
	
	If(!strlen(packages))
		return ""
	Else
		return "Load NeuroLive"
	EndIf

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

//Returns a string list of all user package files. If there is no parent folder for the .ipf it the name of the .ipf file
//will serve as the name of the package. If there is a parent folder that contains several .ipfs, these are considered a single
//package and will be included or discluded together.
Function/S GetUserPackages([fullIPFList,includesOnly,ignoreLoad])
	Variable fullIPFList //returns full list of ipf files, since some may reside within package subfolders
	Variable includesOnly//returns only those ipfs that are included via the package manager
	Variable ignoreLoad//overrides the return statement if NT isn't loaded, still returns the available packages
	
	String packageList = ""
	
	fullIPFList = (ParamIsDefault(fullIPFList)) ? 0 : fullIPFList
	ignoreLoad = (ParamIsDefault(ignoreLoad)) ? 0 : 1
	
	DFREF NPC = root:Packages:NeuroToolsPlus:ControlWaves
	SVAR/Z HiddenPackages = NPC:HideUserPackages
	
	Variable isLoaded = 1
	
	If(!SVAR_Exists(HiddenPackages))
		If(DataFolderRefStatus(NPC) == 1)
			String/G NPC:HideUserPackages
			SVAR HiddenPackages = NPC:HideUserPackages
			HiddenPackages = ""
		Else
			isLoaded = 0
		EndIf
	EndIf
	
	If(isLoaded == 0 && !ignoreLoad)
		return ""
	EndIf
	
	//Get use installed package files
	String userFunctionPath = SpecialDirPath("Igor Pro User Files",0,0,0)	
	userFunctionPath += "User Procedures:NeuroTools+:Functions"
	
	GetFileFolderInfo/Q/Z userFunctionPath
	If(!V_flag)
		NewPath/O/Q userPath,userFunctionPath
		
		If(V_isFolder)
			String userFileList = IndexedFile(userPath,-1,".ipf")
			
			If(includesOnly)
				Variable i
				For(i=0;i<ItemsInList(HiddenPackages,";");i+=1)
					userFileList = RemoveFromList(StringFromList(i,HiddenPackages,";") + ".ipf",userFileList,";")
				EndFor
			EndIf
			
			packageList += userFileList
		EndIf
		
		//Find any package folders within the Functions folder
		String UserPackageFolders = IndexedDir(userPath,-1,1)
		
		If(includesOnly)
			For(i=0;i<ItemsInList(HiddenPackages,";");i+=1)
				UserPackageFolders = RemoveFromList(StringFromList(i,HiddenPackages,";"),UserPackageFolders,";")
			EndFor
		EndIf
		
		Variable numUserPackages = ItemsInList(UserPackageFolders,";")
		If(numUserPackages > 0)
			For(i=0;i<numUserPackages;i+=1)
				String userFolder = StringFromList(i,UserPackageFolders,";")
				userFolder = ParseFilePath(0,userFolder,":",1,0)				
				
				If(fullIPFList)
					String packagePathStr = userFunctionPath + ":" + userFolder
					GetFileFolderInfo/Q/Z packagePathStr
					If(!V_isFolder)
						continue
					EndIf
					
					NewPath/O/Q packagePath,packagePathStr
					userFileList = IndexedFile(packagePath,-1,".ipf")
					
					packageList += userFileList
				Else
					packageList += userFolder
				EndIf
			EndFor
		EndIf
	EndIf
	
	return packageList
End


Function NTP_RemoveIncludes()
	//Rescue function if there are compilation errors with the rest of NeuroTools
	//Since this ipf is an independent module, the main control menu will be still available when the rest
	//of the code breaks. 
	
	String fileList = "NeuroToolsPlus;NTP_Common;NTP_Controls;NTP_DataSets;NTP_Functions;NTP_Structures;NTP_ABF_loader;NTP_Presentinator;"
		
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
	
		//Find any package folders within the Functions folder
		String UserPackageFolders = IndexedDir(userPath,-1,1)
		Variable i,numUserPackages = ItemsInList(UserPackageFolders,";")
		If(numUserPackages > 0)
			For(i=0;i<numUserPackages;i+=1)
				String userFolder = StringFromList(i,UserPackageFolders,";")
				NewPath/O/Q userPath,userFolder
				
				userFileList = IndexedFile(userPath,-1,".ipf")
				fileList += userFileList
			EndFor
		EndIf
	EndIf
	
	//Close the proc windows if they are open
	String procList = WinList("*",";","WIN:128")
	
	For(i=0;i<ItemsInList(fileList,";");i+=1)
		String theFile = StringFromList(i,fileList,";") + ".ipf"
		
		//check if the proc window exists
		If(WhichListItem(theFile,procList,";") != -1)
			Execute/Z/P/Q "CloseProc/NAME=\"" + theFile + "\"" 
		EndIf	
	EndFor
	
	//Remove old dependencies
	For(i=0;i<ItemsInList(fileList,";");i+=1)
		theFile = StringFromList(i,fileList,";")
		theFile = RemoveEnding(theFile,".ipf")
		Execute/P "DELETEINCLUDE \"" + theFile + "\"" 
	EndFor
	
	NVAR isLoaded = NPC:isLoaded
	isLoaded = 0
	
End

//Gathers dependencies and loads the toolbox
Function NTP_InsertIncludes()
	//CheckForUpdates()
	
	String fileList = "NeuroToolsPlus;NTP_Common;NTP_Controls;NTP_DataSets;NTP_Functions;NTP_Structures;NTP_ABF_loader;"
	
	//Allows user to access the Loader ipf file.
	Execute "SetIgorOption IndependentModuleDev=1"
	
	print "Initialized NeuroTools...v" + NTPVERSION
	
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
	
		//Find any package folders within the Functions folder
		String UserPackageFolders = IndexedDir(userPath,-1,1)
		Variable i,numUserPackages = ItemsInList(UserPackageFolders,";")
		If(numUserPackages > 0)
			For(i=0;i<numUserPackages;i+=1)
				String userFolder = StringFromList(i,UserPackageFolders,";")
				NewPath/O/Q userPath,userFolder
				
				userFileList = IndexedFile(userPath,-1,".ipf")
				fileList += userFileList
			EndFor
		EndIf
	EndIf
	
	
	//remove potential dependencies for old NeuroTools version
	String removeList = "NT_Loader;Load_NeuroTools;NT_Common;NT_Controls;NT_DataSets;NT_ScanImage_Package;ScanImageTiffReader;NT_Image_Registration;NT_Functions;NT_InsertTemplate;NT_ExternalFunctions;NT_Structures;NT_ABF_loader;NT_Presentinator;NT_ScanImage_Package;NT_ScanImageTiffReader;NTP_Presentinator;"
	
	Variable numFiles
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
	
	Variable loadSI = 0
	
	//add new dependencies
	For(i=0;i<numFiles;i+=1)
		theFile = StringFromList(i,fileList,";")
		theFile = RemoveEnding(theFile,".ipf")
		
		Execute/P "INSERTINCLUDE \"" + theFile + "\"" 
		
		If(!cmpstr(theFile,"NTP_ScanImage_Package"))
			loadSI = 1
		Else
			loadSI = (loadSI) ? 1 : 0
		EndIf
	EndFor
	
	//compile
	Execute/P "COMPILEPROCEDURES "
	
	//Load the NeuroTools+ Package
	Execute/P "LoadNeuroPlus()"
	
	If(loadSI)
		Execute/P/Q "SI_CreatePackage()"
	EndIf
	
End

// utility function, inflates a zip archive
// verbose=1 to print output from executescripttext
function unzipArchive(string archivePathStr, string unzipPathStr, [int verbose])
    verbose = ParamIsDefault(verbose) ? 1 : verbose     
    string validExtensions = "zip;" // set to "" to skip check
    string msg, unixCmd, cmd
        
    GetFileFolderInfo /Q/Z archivePathStr

    if (V_Flag || V_isFile==0)
        printf "Could not find file %s\r", archivePathStr
        return 0
    endif

    if (ItemsInList(validExtensions) && FindListItem(ParseFilePath(4, archivePathStr, ":", 0, 0), validExtensions, ";", 0, 0) == -1)
        printf "%s doesn't appear to be a zip archive\r", ParseFilePath(0, archivePathStr, ":", 1, 0)
        return 0
    endif
    
    if (strlen(unzipPathStr) == 0)
        unzipPathStr = SpecialDirPath("Desktop",0,0,0) + ParseFilePath(3, archivePathStr, ":", 0, 0)
        sprintf msg, "Unzip to %s:%s?", ParseFilePath(0, unzipPathStr, ":", 1, 1), ParseFilePath(0, unzipPathStr, ":", 1, 0)
        DoAlert 1, msg
        if (v_flag == 2)
            return 0
        endif
    else
        GetFileFolderInfo /Q/Z unzipPathStr
        if (V_Flag || V_isFolder==0)
            sprintf msg, "Could not find unzipPathStr folder\rCreate %s?", unzipPathStr
            DoAlert 1, msg
            if (v_flag == 2)
                return 0
            endif
        endif
    endif
    
    // make sure unzipPathStr folder exists - necessary for mac
    NewPath /C/O/Q acw_tmpPath, unzipPathStr
    KillPath /Z acw_tmpPath

    if (stringmatch(StringByKey("OS", IgorInfo(3))[0,2],"Win")) // Windows
        // The following works with .Net 4.5, which is available in Windows 8 and up.
        // current versions of Windows with Powershell 5 can use the more succinct PS command
        // 'Expand-Archive -LiteralPath C:\archive.zip -DestinationPath C:\Dest'
        string strVersion = StringByKey("OSVERSION", IgorInfo(3))
        variable WinVersion = str2num(strVersion) // turns "10.1.2.3" into 10.1 and 6.23.111 into 6.2 (windows 8.0)
        if (WinVersion<6.2)
            Print "unzipArchive requires Windows 8 or later"
            return 0
        endif
        
        archivePathStr = ParseFilePath(5, archivePathStr, "\\", 0, 0)
        unzipPathStr = ParseFilePath(5, unzipPathStr, "\\", 0, 0)
        cmd = "powershell.exe -nologo -noprofile -command \"& { Add-Type -A 'System.IO.Compression.FileSystem';"
        sprintf cmd "%s [IO.Compression.ZipFile]::ExtractToDirectory('%s', '%s'); }\"", cmd, archivePathStr, unzipPathStr
    else // Mac
        sprintf unixCmd, "unzip '%s' -d '%s'", ParseFilePath(5, archivePathStr, "/", 0,0), ParseFilePath(5, unzipPathStr, "/", 0,0)
        sprintf cmd, "do shell script \"%s\"", unixCmd
    endif
    
    ExecuteScriptText /B/UNQ/Z cmd
    if (verbose)
        Print S_value // output from executescripttext
    endif
    
    return (v_flag == 0)
end


// utility function, inflates a zip archive
// verbose=1 to print output from executescripttext
function zipArchive(string archivePathStr,[Variable verbose])
	string msg, unixCmd, cmd
	
	verbose = (ParamIsDefault(verbose)) ? 0 : 1
	GetFileFolderInfo /Q/Z archivePathStr
	
	if (V_Flag || V_isFolder==0)
		printf "Could not find file %s\r", archivePathStr
		return 0
	endif
	
	String folderName = RemoveEnding(ParseFilePath(0,archivePathStr,":",1,0),":")
	String zipFileName = folderName + ".zip"
	
	archivePathStr = ParseFilePath(5,archivePathStr,"/",0,0)
	archivePathStr = "/" + ParseFilePath(1,archivePathStr,"/",1,0)
	
	unixCmd = "cd " + archivePathStr + ";zip -vr " + "./" + zipFileName + " ./" + folderName
	sprintf cmd, "do shell script \"%s\"", unixCmd
	
	ExecuteScriptText /UNQ/Z cmd
	if (verbose)
	    Print S_value // output from executescripttext
	endif
	
	return (v_flag == 0)
end