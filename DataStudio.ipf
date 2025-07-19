#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later

Constant panelWidth = 500
Constant panelHeight = 500
Constant mainTabWidth = 225

static function/DF packageDF()
	return root:Packages:DataStudio
end

function loadDataStudio()
	KillWindow/Z DataStudio
	KillDataFolder/Z packageDF()
	
	DFREF saveDF = GetDataFolderDFR()

	// Create the package folder
	NewDataFolder/S/O root:Packages
	NewDataFolder/S/O DataStudio
	
	String/G saveDFPath = GetDataFolder(1, saveDF)
	
	NewPanel/K=1/W=(0, 0, panelWidth, panelHeight)/N=DataStudio as "Data Studio"
	SetWindow DataStudio, sizeLimit = {mainTabWidth, 100, inf, inf} , activeChildFrame = 0
	
	// Guides
	DefineGuide/W=DataStudio HMiddle = {FL, 0.5, FR}
	DefineGuide/W=DataStudio TabTop = {FT, 5}
	DefineGuide/W=DataStudio TabBottom = {TabTop, 20}
	DefineGuide/W=DataStudio NavigatorListTop = {TabBottom, 10}
	
	TabControl mainTab, win = DataStudio,	tabLabel(0) = "Navigator",\
											tabLabel(1) = "Data Sets", \
											tabLabel (2) = "Functions", size = {mainTabWidth, 20}
	TabControl mainTab, win = DataStudio,	focusRing = 0, proc = mainTabCallback, \
											guides = {kwNone, HMiddle, kwNone, TabTop, kwNone, TabBottom}

	buildNavigator()
	
	SetDataFolder saveDF
end

function buildNavigator()
	// Necessary objects
	NewDataFolder/O/S packageDF():Navigator
	
	Make/O/T/N=(0,1,2) navigatorFolderList
	
	SVAR saveDFPath = packageDF():saveDFPath
	DFREF currentFolder = $saveDFPath
	
	String folderList = StringByKey("FOLDERS", DataFolderDir(1, currentFolder) , ":", ";")
	
	Wave/T temp = ListToTextWave(folderList, ";")
	Redimension/N=(DimSize(temp,0), -1, -1) navigatorFolderList
	navigatorFolderList = temp
	
	Make/O/N=(DimSize(navigatorFolderList,0)) navigatorFolderSelection

	
	Make/O/T/N=(0,1,2) navigatorObjectList
	Make/O/N=0 navigatorObjectSelection
	
	String/G navigatorControlList = ""
	
	ListBox nav_folderList, win = DataStudio,	guides = {FL, kwNone, HMiddle, NavigatorListTop, kwNone, FB}, focusRing = 0, \
												listWave = navigatorFolderList, selWave = navigatorFolderSelection
	navigatorControlList += "nav_folderList;"									
	
	ListBox nav_objectList, win = DataStudio,	guides = {HMiddle, kwNone, FR, NavigatorListTop, kwNone, FB}, focusRing = 0, \
												listWave = navigatorObjectList, selWave = navigatorObjectSelection
	navigatorControlList += "nav_objectList;"
end

static function/S controlList(String tabGroup)
	strswitch(tabGroup)
		case "Navigator":
			DFREF navFolder = packageDF():Navigator
			SVAR ctrlList = navFolder:navigatorControlList
			return ctrlList
			break
		case "Data Sets":
		
			break
		case "Functions":
			break
	endswitch
	
	return ""
end

function mainTabCallback(tca) : TabControl
	STRUCT WMTabControlAction &tca

	switch( tca.eventCode )
		case 2: // mouse up
			Variable tab = tca.tab
			
			switch (tab)
				case 0: // Navigator
					ModifyControlList controlList("Navigator"), disable = 0
					break
				case 1: // Data Sets
				case 2: // Functions
					ModifyControlList controlList("Navigator"), disable = 1
					break
			endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
end
