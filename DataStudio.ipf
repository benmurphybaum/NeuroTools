#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
#pragma IgorVersion = 10.0

#include "md2ihf"

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
	
	Variable/G mouseDown = 0
	
	
	NewPanel/K=1/W=(0, 0, panelWidth, panelHeight)/N=DataStudio as "Data Studio"
	SetWindow DataStudio, sizeLimit = {mainTabWidth, 100, inf, inf} , activeChildFrame = 0
	
	// Guides
	DefineGuide/W=DataStudio HMiddle = {FL, 0.5, FR}
	
	// Splitter between the two list boxes
	DefineGuide/W=DataStudio ListSplitLeft = {FL, 0.3, FR}
	DefineGuide/W=DataStudio ListSplitRight = {ListSplitLeft, 10}
	
	DefineGuide/W=DataStudio TabTop = {FT, 5}
	DefineGuide/W=DataStudio TabBottom = {TabTop, 20}
	
	DefineGuide/W=DataStudio NavigatorControlPanelTop = {TabBottom, 10}
	DefineGuide/W=DataStudio NavigatorControlPanelBottom = {NavigatorControlPanelTop, 20}
	DefineGuide/W=DataStudio NavigatorBackH = {FL, 20}
	DefineGuide/W=DataStudio NavigatorForwardH = {NavigatorBackH, 20}
	DefineGuide/W=DataStudio NavigatorPathH = {NavigatorForwardH, 20}
	
	DefineGuide/W=DataStudio NavigatorListTop = {NavigatorControlPanelBottom, 5}
	DefineGuide/W=DataStudio NavigatorListBottom = {FB, -25}
	
	DefineGuide/W=DataStudio DatasetsListBottom = {FB, -200}
	DefineGuide/W=DataStudio DatasetsNotebookTop= {DatasetsListBottom, 25}
	
	DefineGuide/W=DataStudio DatasetsSplitLeft = {FL, 0.45, FR}
	DefineGuide/W=DataStudio DatasetsSplitRight = {DatasetsSplitLeft, 10}
	
	DefineGuide/W=DataStudio DatasetsButtonLeft = {HMiddle, -40}
	
	TabControl mainTab, win = DataStudio,	tabLabel(0) = "Navigator",\
											tabLabel(1) = "Data Sets", \
											tabLabel (2) = "Functions", size = {mainTabWidth, 20}
	TabControl mainTab, win = DataStudio,	focusRing = 0, proc = mainTabCallback, \
											guides = {kwNone, HMiddle, kwNone, TabTop, kwNone, TabBottom}

	buildNavigator()
	
	buildDataSets()
	
	SetDataFolder saveDF
	updatePathControl()
	
	ModifyControlList controlList("DataSets"), disable = 1	
	ModifyControlList controlList("Navigator"), disable = 0
end

static function updateNavigatorLists(DFREF dfr)
	DFREF nav = packageDF():Navigator
	Wave/T navigatorFolderList = nav:navigatorFolderList
	Wave navigatorFolderSelection = nav:navigatorFolderSelection
	Wave/T navigatorObjectList = nav:navigatorObjectList
	Wave navigatorObjectSelection = nav:navigatorObjectSelection
	
	// Folders
	String folderList = StringByKey("FOLDERS", DataFolderDir(1, dfr) , ":", ";")
	Wave/T temp = ListToTextWave(folderList, ",")
	Redimension/N=(DimSize(temp, 0), -1, -1) navigatorFolderList, navigatorFolderSelection
	if (DimSize(temp, 0) > 0)
		navigatorFolderList = temp
	endif
	
	// Objects
	String objectList = StringByKey("WAVES", DataFolderDir(2, dfr) , ":", ";")
	Wave/T temp = ListToTextWave(objectList, ",")
	Redimension/N=(DimSize(temp, 0), -1, -1) navigatorObjectList, navigatorObjectSelection
	
	if (DimSize(temp, 0) > 0)
		navigatorObjectList = temp
	endif
	
	updatePathControl()
end

function buildNavigator()
	// Necessary objects
	NewDataFolder/O/S packageDF():Navigator
	
	Make/O/T/N=(0,1,2) navigatorFolderList
	Make/O/N=0 navigatorFolderSelection

	Make/O/T/N=(0,1,2) navigatorObjectList
	Make/O/N=0 navigatorObjectSelection

	SVAR saveDFPath = packageDF():saveDFPath
	DFREF currentFolder = $saveDFPath
	
	updateNavigatorLists(currentFolder)
	
	String/G navigatorControlList = ""
	
	Button nav_back, win = DataStudio, title = "<",	size = {20, 20}, focusRing = 0, proc = NavigatorButtonCallback, \
													guides = {kwNone, NavigatorBackH, kwNone, NavigatorControlPanelTop, kwNone, NavigatorControlPanelBottom}
	navigatorControlList += "nav_back;"									

	Button nav_forward, win = DataStudio, title = ">",	size = {20, 20}, focusRing = 0, \
														guides = {kwNone, NavigatorForwardH, kwNone, NavigatorControlPanelTop, kwNone, NavigatorControlPanelBottom}
	navigatorControlList += "nav_forward;"	
	
	TitleBox nav_path, win = DataStudio,	title = currentFolderPath(), disable = 2, fstyle = 2, fixedSize = 1, frame = 0, anchor=LC, \
											guides = {NavigatorPathH, kwNone , FR, NavigatorControlPanelTop, kwNone, NavigatorControlPanelBottom}
	navigatorControlList += "nav_path;"	
																						
	ListBox nav_folderList, win = DataStudio,	guides = {FL, kwNone, ListSplitLeft, NavigatorListTop, kwNone, NavigatorListBottom}, focusRing = 0, mode=10, frame = 0, \
												listWave = navigatorFolderList, selWave = navigatorFolderSelection, proc = NavigatorFolderListCallback
	navigatorControlList += "nav_folderList;"									
	
	ListBox nav_objectList, win = DataStudio,	guides = {ListSplitRight, kwNone, FR, NavigatorListTop, kwNone, NavigatorListBottom}, focusRing = 0, mode=10, frame = 0, \
												listWave = navigatorObjectList, selWave = navigatorObjectSelection, proc = NavigatorObjectListCallback
	navigatorControlList += "nav_objectList;"
		
	SetVariable nav_regexMatch, win = DataStudio, value = _STR:"", focusRing = 0, guides = {FL, kwNone, FR, kwNone, kwNone, FB}, anchor = LC, proc = matchCallback
	navigatorControlList += "nav_regexMatch;"
	
	SetWindow DataStudio, hook(NavigatorMouseHook) = NavigatorMouseHook
end

static function buildDataSets()
	// Necessary objects
	NewDataFolder/O/S packageDF():DataSets
	
	Make/O/T/N=(0,1,2) datasetsBaseList
	Make/O/N=0 datasetsBaseListSelection

	Make/O/T/N=(0,1,2) datasetsViewList
	Make/O/N=0 datasetsViewListSelection
	
	DFREF datasets = packageDF():DataSets
	Wave/T datasetsBaseList = datasets:datasetsBaseList
	Wave datasetsBaseListSelection = datasets:datasetsBaseListSelection
	Wave/T datasetsViewList = datasets:datasetsViewList
	Wave datasetsViewListSelection = datasets:datasetsViewListSelection
		
	SVAR saveDFPath = packageDF():saveDFPath
	DFREF currentFolder = $saveDFPath
	
	String/G datasetsControlList = ""
	
	ListBox datasets_base, win = DataStudio,	guides = {FL, kwNone, DatasetsSplitLeft, NavigatorListTop, kwNone, DatasetsListBottom}, focusRing = 0, mode=10, frame = 0, \
												listWave = datasetsBaseList, selWave = datasetsBaseListSelection, proc = datasetsBaseListCallback
	datasetsControlList += "datasets_base;"									
	
	ListBox datasets_view, win = DataStudio,	guides = {DatasetsSplitRight, kwNone, FR, NavigatorListTop, kwNone, DatasetsListBottom}, focusRing = 0, mode=10, frame = 0, \
												listWave = datasetsViewList, selWave = datasetsViewListSelection, proc = datasetsViewListCallback
	datasetsControlList += "datasets_view;"
	
	KillWindow/Z datasetNotebook_edit
	KillWindow/Z datasetNotebook_view
	NewNotebook/HOST=DataStudio/N=datasetNotebook_edit/FG=(FL, DatasetsNotebookTop, FR, FB)/F=0/K=2/V=0
	NewNotebook/HOST=DataStudio/N=datasetNotebook_view/FG=(FL, DatasetsNotebookTop, FR, FB)/F=1/K=2/OPTS=4/V=0
	Notebook DataStudio#datasetNotebook_view showRuler = 0
	
	Button datasets_editNotebook, win = DataStudio,	guides = {kwNone, DatasetsButtonLeft, kwNone, kwNone , kwNone, DatasetsNotebookTop}, size = {40, 20}, title = "Edit"
	Button datasets_editNotebook, proc = DataSetsNotebookButtonCallback
	datasetsControlList += "datasets_editNotebook;"
	
	Button datasets_viewNotebook, win = DataStudio,	guides = {kwNone, HMiddle, kwNone, kwNone , kwNone, DatasetsNotebookTop}, size = {40, 20}, title = "View"
	Button datasets_viewNotebook, proc = DataSetsNotebookButtonCallback
	datasetsControlList += "datasets_viewNotebook;"

end

static function updatePathControl()
	TitleBox nav_path, win = DataStudio, title = currentFolderPath()
end

static function/S currentFolderPath()
	return GetDataFolder(1)
end

static function/S controlList(String tabGroup)
	strswitch(tabGroup)
		case "Navigator":
			DFREF navFolder = packageDF():Navigator
			SVAR ctrlList = navFolder:navigatorControlList
			return ctrlList
			break
		case "DataSets":
			DFREF datasetsFolder = packageDF():DataSets
			SVAR ctrlList = datasetsFolder:datasetsControlList
			return ctrlList
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
					ModifyControlList controlList("DataSets"), disable = 1	
					Notebook DataStudio#datasetNotebook_edit visible = 0
					Notebook DataStudio#datasetNotebook_view visible = 0	
					
					ModifyControlList controlList("Navigator"), disable = 0
					SetWindow DataStudio, hook(NavigatorMouseHook) = NavigatorMouseHook
					break
				case 1: // Data Sets
					ModifyControlList controlList("Navigator"), disable = 1
					ModifyControlList controlList("DataSets"), disable = 0
					Notebook DataStudio#datasetNotebook_edit visible = 1
					Notebook DataStudio#datasetNotebook_view visible = 1
					
					SetWindow DataStudio, hook(NavigatorMouseHook) = $""
					break
				case 2: // Functions
					ModifyControlList controlList("Navigator"), disable = 1
					SetWindow DataStudio, hook(NavigatorMouseHook) = $""
					break
			endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
end

static function guidePosition(String guideName)
	return NumberByKey("POSITION", GuideInfo("DataStudio", guideName), ":", ";")
end

Function NavigatorMouseHook(s)
	STRUCT WMWinHookStruct &s

	Variable hookResult = 0

	switch(s.eventCode)
		case 0:				// Activate
			// Handle activate
			break

		case 1:				// Deactivate
			// Handle deactivate
			break
		case 3:
			// mouse down
			if (s.mouseLoc.h > guidePosition("ListSplitLeft") && \
				s.mouseLoc.h < guidePosition("ListSplitRight") && \
				s.mouseLoc.v > guidePosition("NavigatorListTop"))
				NVAR mouseDown = packageDF():mouseDown
				mouseDown = 1
				s.doSetCursor = 1
				s.cursorCode = 5
			else
				mouseDown = 0
			endif
			break
		case 4:
			// mouse moved
			NVAR mouseDown = packageDF():mouseDown
			if (mouseDown)
				s.doSetCursor = 1
				s.cursorCode = 5
				
				Variable leftPos = guidePosition("FL")
				Variable rightPos = guidePosition("FR")
				
				Variable currentLeftGuide = guidePosition("ListSplitLeft")
				Variable diff = s.mouseLoc.h - currentLeftGuide
				
				Variable newFraction = (currentLeftGuide + diff) / (rightPos - leftPos)
				if (newFraction > 0.2 && newFraction < 0.8)
					DefineGuide/W=DataStudio ListSplitLeft = {FL, newFraction, FR}
				endif
			else
				if (s.mouseLoc.h > guidePosition("ListSplitLeft") && \
					s.mouseLoc.h < guidePosition("ListSplitRight") && \
					s.mouseLoc.v > guidePosition("NavigatorListTop"))
					s.doSetCursor = 1
					s.cursorCode = 5
				else
					s.doSetCursor = 0
				endif
			endif
			break
		case 5:
			// mouse up
			NVAR mouseDown = packageDF():mouseDown
			mouseDown = 0
			s.doSetCursor = 0
			break
	endswitch

	return hookResult		// 0 if nothing done, else 1
End


Function NavigatorFolderListCallback(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave

	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			break
		case 3: // double click
			if (DimSize(listWave,0) > row)
				SetDataFolder listWave[row][0][0]
				updateNavigatorLists(GetDataFolderDFR())
			endif
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
			break
		case 6: // begin edit
			break
		case 7: // finish edit
			break
		case 13: // checkbox clicked (Igor 6.2 or later)
			break
	endswitch

	return 0
End

Function NavigatorObjectListCallback(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave

	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			break
		case 3: // double click
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
			break
		case 6: // begin edit
			break
		case 7: // finish edit
			break
		case 13: // checkbox clicked (Igor 6.2 or later)
			break
	endswitch

	return 0
End

Function NavigatorButtonCallback(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			strswitch (ba.ctrlName)
				case "nav_back":
					DFREF folder = $ParseFilePath(1, GetDataFolder(1), ":", 1, 0)
					SetDataFolder folder
					updateNavigatorLists(folder)
					break
				case "nav_forward":
					break
			endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function DataSetsNotebookButtonCallback(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			strswitch (ba.ctrlName)
				case "datasets_editNotebook":
					Notebook DataStudio#datasetNotebook_edit visible = 1
					Notebook DataStudio#datasetNotebook_view visible = 0
					break
				case "datasets_viewNotebook":
					Notebook DataStudio#datasetNotebook_edit visible = 0
					Notebook DataStudio#datasetNotebook_view visible = 1
					
					String/G root:Packages:DataStudio:DataSets:notebookText/N=notebookText
					
					Notebook DataStudio#datasetNotebook_edit getData = 2
					notebookText = ReplaceString("\r", S_Value, "\n")
					
					struct LineContext context
					md2ihf("root:Packages:DataStudio:DataSets:notebookText", "DataStudio#datasetNotebook_view", "", context)
					break
			endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function matchCallback(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
			String argumentStr = ""
			sprintf argumentStr, "\"%s\" %s", sva.sval, GetDataFolder(1)
			PythonFile/Z file = "DataStudio/regexMatch.py", args = argumentStr
			
			DFREF folder = packageDF()
			SVAR matchResults = folder:regexMatches
			print matchResults
			
			break
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

