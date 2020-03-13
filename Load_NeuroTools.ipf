#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//NeuroTools (NT) is an interface for organizing and analyzing data.
//Major updates, refactoring, and reorganization from its predecessor, AnalysisTools.
//Ben Murphy-Baum, 2020


//Global Fonts
StrConstant LIGHT = "Helvetica Neue Light"
StrConstant REG = "Helvetica Neue"
StrConstant TITLE = "Bodoni 72 SmallCaps"
StrConstant SUBTITLE = "Bodoni 72 Oldstyle"

//Builds the GUI
Function LoadNT([left,top])
	Variable left,top
	Variable width,height,i
	
	//Reopens the GUI
	DoWindow NT
	If(V_flag)
		DoWindow/K NT
	EndIf
	
	//Create the NeuroTools package folders and waves
	MakePackageFolders()
	
	//Makes table for holding the list of Command functions. 
	MakeCommandList() 
	
	DFREF NTF = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	
	//Build the GUI
	left += 0
	top += 0
	width = 754
	height = 515

	//Main Panel
	NewPanel /K=1 /W=(left,top,left + width,top + height) as "NeuroTools"
	DoWindow/C NT
	ModifyPanel /W=NT, fixedSize= 1
	
	//Navigator Panel and Guides
	DefineGuide/W=NT listboxLeft={FR,-300}//,listboxBottom={FB}
	NewPanel/HOST=NT/FG=(listboxLeft,FT,FR,FB)/N=navigatorPanel
	ModifyPanel/W=NT#navigatorPanel frameStyle=0
	SetDrawEnv/W=NT#navigatorPanel textxjust=1
	
	//Current data folder text
	String/G NTF:currentDataFolder
	SVAR cdf = NTF:currentDataFolder
	cdf = GetDataFolder(1)
	SetVariable NT_cdf win=NT#navigatorPanel,pos={0,28},size={200,20},fsize=10,font=$LIGHT,value=cdf,title=" ",disable=2,frame=0
	
	//Back Button
	Button Back win=NT#navigatorPanel,size={30,20},pos={1,49},font=$REG,fsize=9,title="Back",proc=ntButtonProc,disable=0

	//Reload NeuroTools button
	Button Reload win=NT,font=$LIGHT,size={50,20},pos={3,1},title="Reload",proc=ntButtonProc
	
	//Viewer Button
	//Draw line along bottom of the GUI as a window hook for opening and closing the Viewer window
	SetDrawEnv/W=NT xcoord= abs,ycoord= abs,linefgc= (0,0,0,16384),linethick= 4.00,gname=ViewerLine,gstart 
	DrawLine/W=NT 0,513,446,513
	SetDrawEnv/W=NT gstop
	
//	Button ntViewerButton win=NT,font=$LIGHT,size={80,20},pos={288,58},title="▼ Viewer ▼",proc=ntButtonProc
	String/G NTF:viewerRecall = ""
	
	//Command drop down menu, employed as a button with conditional menus
	
	//Current Command Menu selection
	SVAR selectedCmd = root:Packages:NT:selectedCmd
	
	//Calculates spacer to ensure centered text on the drop down menu
	String spacer = ""
	Variable cmdLen = strlen(selectedCmd)
	cmdLen = 16 - cmdLen
	
	Do
		spacer += " "
		cmdLen -= 1
	While(cmdLen > 0)
	
	//Command Menu
	Button CommandMenu win=NT,font=$LIGHT,pos={456,39},size={140,20},fsize=12,proc=ntButtonProc,title="\\JL▼   " + spacer + selectedCmd,disable=0
	
	//Run command button
	Button RunCmd win=NT,font=$LIGHT,pos={601,39},size={50,20},title="Run",disable=0,proc=ntButtonProc

	//Settings
	Button NT_Settings win=NT,font=$LIGHT,pos={57,1},size={20,20},title="...",disable=0,proc=ntButtonProc
	
	//Wave Matching
	SetVariable waveMatch win=NT,font=$LIGHT,pos={13,40},size={162,25},fsize=12,title="Match",value=_STR:"*",help={"Matches waves in the selected folder.\rLogical 'OR' can be used via '||'"},disable=0,proc=ntSetVarProc
	SetVariable waveNotMatch win=NT,font=$LIGHT,pos={26,60},size={149,25},fsize=12,title="Not",value=_STR:"",help={"Excludes matched waves in the selected folder.\rLogical 'OR' can be used via '||'"},disable=0,proc=ntSetVarProc
	String helpNote = "Target subfolder for wave matching.\r Useful if matching in multiple parent folders that each have a common subfolder structure\r"
	helpNote += "Supports folder matching, and can use '||' as a logical OR to match multiple subfolder searches"
	SetVariable relativeFolderMatch win=NT,font=$LIGHT,pos={8,80},size={167,25},fsize=12,title=":Folder",value=_STR:"",help={helpNote},disable=0,proc=ntSetVarProc
   
	//List box selection and table waves
	Wave MatchLB_SelWave = NTF:MatchLB_SelWave //match list box
	Wave/T MatchLB_ListWave = NTF:MatchLB_ListWave //match list box
	Wave/T MatchLB_ListWave_BASE = NTF:MatchLB_ListWave_BASE //BASE wave match list without any groupings or filters
	Wave DataSetLB_SelWave = NTD:DataSetLB_SelWave //data set waves list box
	Wave/T DataSetLB_ListWave = NTD:DataSetLB_ListWave //data set waves list box
	Wave DSNamesLB_SelWave = NTD:DSNamesLB_SelWave //data set names list box
	Wave/T DSNamesLB_ListWave = NTD:DSNamesLB_ListWave //data set names list box
	Wave FolderLB_SelWave = NTF:FolderLB_SelWave //folder list box
	Wave/T FolderLB_ListWave = NTF:FolderLB_ListWave //folder list box
	Wave WavesLB_SelWave = NTF:WavesLB_SelWave //waves list box
	Wave/T WavesLB_ListWave = NTF:WavesLB_ListWave //waves list box
	
	
	//Navigation List Boxes
	//Set up and fill the list box waves
	SetDataFolder root:
	cdf = "root:"
	getFolders()
	getFolderWaves()
	
	ListBox folderListBox win=NT#navigatorPanel,size={140,435},pos={0,70},mode=4,listWave=FolderLB_ListWave,selWave=FolderLB_SelWave,disable=0,proc=ntListBoxProc
	ListBox waveListBox win=NT#navigatorPanel,size={140,435},pos={150,70},mode=4,listWave=WavesLB_ListWave,selWave=WavesLB_SelWave,disable=0,proc=ntListBoxProc
	
	//List Box Labels
	SetDrawEnv/W=NT gstart,gname=labels
	SetDrawEnv/W=NT xcoord= abs,ycoord= abs, fsize=11, textxjust= 1,textyjust= 1,fname=$LIGHT
	DrawText/W=NT 92,112,"Wave Matches"
	SetDrawEnv/W=NT xcoord= abs,ycoord= abs, fsize=11, textxjust= 1,textyjust= 1,fname=$LIGHT
	DrawText/W=NT 269,112,"Data Set Waves"
	SetDrawEnv/W=NT xcoord= abs,ycoord= abs, fsize=11, textxjust= 1,textyjust= 1,fname=$LIGHT
	DrawText/W=NT 402,112,"Data Sets"
	SetDrawEnv/W=NT#navigatorPanel xcoord= abs,ycoord= abs, fsize=11, textxjust= 1,textyjust= 1,fname=$LIGHT
	DrawText/W=NT#navigatorPanel 63,60,"Folders"
	SetDrawEnv/W=NT#navigatorPanel xcoord= abs,ycoord= abs, fsize=11, textxjust= 1,textyjust= 1,fname=$LIGHT
	DrawText/W=NT#navigatorPanel 221,60,"Waves"
	SetDrawEnv/W=NT gstop
	
	
	SetDrawEnv/W=NT#navigatorPanel xcoord= abs,ycoord= abs, fsize=14, textxjust= 1,textyjust= 1,fname=$LIGHT
	DrawText/W=NT#navigatorPanel 143,15,"Navigator"
	
	SetDrawEnv/W=NT xcoord= abs,ycoord= abs, fsize=14, textxjust= 1,textyjust= 1, textrgb= (0,0,0),fname=$LIGHT,gstart,gname=parameterText
	DrawText/W=NT 554,15,"Parameters"
	SetDrawEnv/W=NT gstop
	
	
	SetDrawEnv/W=NT xcoord= abs,ycoord= abs, fsize=12, textxjust= 1, textrgb= (0,0,0),textyjust= 1,fname=$LIGHT,gname=waveSelectorTitle,gstart
	DrawText/W=NT 483,85,"Waves:"
	SetDrawEnv/W=NT gstop
	
	SetDrawEnv/W=NT fname= $TITLE,textrgb= (43690,43690,43690),xcoord= abs,ycoord= abs,textxjust= 1,textyjust= 1
	DrawText/W=NT 314,35,"\\Z36N e u r o T o o l s"
	SetDrawEnv/W=NT fname= $SUBTITLE,textrgb= (43690,43690,43690),xcoord= abs,ycoord= abs,textxjust= 1,textyjust= 1
	DrawText/W=NT 314,66,"A data organization and analysis toolbox"
	
	//Group Box for control parameters
	GroupBox parameterBox win=NT,pos={455,69},size={197,437},disable=0,title="" 
	
	//Data Set controls
	Button addDataSet win=NT,pos={340,444},font=$LIGHT,size={100,20},title="Add Data Set",disable=0,help={"Adds a new data set with the specified name"},proc=ntButtonProc
	SetVariable dsNameInput win=NT,pos={345,468},size={90,20},disable=1,focusRing=0,frame=0,value=_STR:"",proc=ntSetVarProc
	GroupBox dsNameGroupBox win=NT,pos={340,463},size={100,26},disable=1
	
	//Button addDataSetFromSelection win=NT,font=$LIGHT,pos={172,468},size={100,20},title="From Selection",help={"Adds a new data set from the wave list in Browse mode"},disable=0,proc=ntButtonProc
	Button updateDataSet win=NT,font=$LIGHT,pos={340,465},size={100,20},title="Update DS",help={"Udpate the selected data set from the Wave Match list box"},disable=0,proc=ntButtonProc
	Button delDataSet win=NT,font=$LIGHT,pos={340,486},size={100,20},title="Delete DS",help={"Delete the selected data set"},disable=0,proc=ntButtonProc	
	
	helpNote = "Organize the wave list into wave sets by the indicated underscore position.\rUses zero offset; -2 concatenates into a single wave set"
	SetVariable waveGrouping win=NT,pos={58,471},size={85,20},title="",disable=0,value=_STR:"",help={helpNote},proc=ntSetVarProc
	SetDrawEnv/W=NT fsize=9,fname=$LIGHT
	DrawText/W=NT 14,484,"Grouping"
	SetDrawEnv/W=NT fsize=9,fname=$LIGHT
	DrawText/W=NT 27,504,"Filters"
	
	
	SetVariable prefixGroup win=NT,pos={58,491},size={40,20},title="",disable=0,value=_STR:"",help={"Filter the wave list by the 1st underscore position"},proc=ntSetVarProc
	SetVariable groupGroup win=NT,pos={99,491},size={55,20},title=" __",disable=0,value=_STR:"",help={"Filter the wave list by the 2nd underscore position"},proc=ntSetVarProc
	SetVariable seriesGroup win=NT,pos={155,491},size={55,20},title=" __",disable=0,value=_STR:"",help={"Filter the wave list by the 3rd underscore position"},proc=ntSetVarProc
	SetVariable sweepGroup win=NT,pos={211,491},size={55,20},title=" __",disable=0,value=_STR:"",help={"Filter the wave list by the 4th underscore position"},proc=ntSetVarProc
	SetVariable traceGroup win=NT,pos={266,491},size={55,20},title=" __",disable=0,value=_STR:"",help={"Filter the wave list by the 5th underscore position"},proc=ntSetVarProc
	
	Button clearFilters win=NT,pos={153,468},size={130,20},title="Clear Group/Filters",disable=0,help={"Clear all filters and groupings"},proc=ntButtonProc
	
	//Initialize the match list from the current data folder
   SetDataFolder root:
   cdf = "root:"
   
   //Draws selection dots around the selected list box
   SVAR listFocus = NTF:listFocus
   listFocus = "WaveMatch"
   
   //Initialize the wave match list
   getWaveMatchList()
   
	//List box that holds wave matches
	ListBox MatchListBox win=NT,pos={6,120},size={172,320},mode=4,listWave=MatchLB_ListWave,selWave=MatchLB_SelWave,disable=0,proc=ntListBoxProc
	
	//List box that holds data set wave lists
	ListBox DataSetWavesListBox win=NT,mode=4,pos={183,120},size={172,320},listWave=DataSetLB_ListWave,selWave=DataSetLB_SelWave,disable=0,proc=ntListBoxProc
	
	//List box to hold names of data sets 
	ListBox DataSetNamesListBox win=NT,mode=2,pos={361,120},size={80,320},listWave=DSNamesLB_ListWave,selWave=DSNamesLB_SelWave,disable=0,proc=ntListBoxProc
	
	//Draw line between matching and data set section, and the Data Browser section
	//Put the line into its own draw group so I can pull it out individually
	SetDrawEnv/W=NT xcoord= abs,ycoord= abs,linefgc= (0,0,0,16384),linethick= 4.00,gname=NavLine,gstart 
	DrawLine/W=NT 448,0,448,515
//	SetDrawEnv/W=NT# xcoord= abs,ycoord= abs,linefgc= (0,0,0,16384),linethick= 4.00,
	SetDrawEnv/W=NT gstop
	
	
	//For opening and closing the parameters infold for running functions
	SetWindow NT hook(parameterFoldHook) = foldParametersHook
	
	//Control lists and controls
	CreateControlLists()
	CreateControls()
	
	//Switch to a default control. I use 'Measure'
	switchControls("Measure","")
	
	//Initialize the first data set in the list
	If(DimSize(DSNamesLB_ListWave,0) > 0)
		changeDataSet(DSNamesLB_ListWave[0][0][0])
	EndIf
	
	//need to put listfocus to empty so it actually changes back
	//This will draw the selection dots around WaveMatch
	listFocus = "" 
	changeFocus("WaveMatch",1)
	
	BuildMenu "All"
	
End

//Creates NeuroTools package folders and makes all supporting waves
Function MakePackageFolders()
	
	If(!DataFolderExists("root:Packages"))
		NewDataFolder root:Packages
	EndIf
	
	If(!DataFolderExists("root:Packages:NT"))
		NewDataFolder root:Packages:NT
	EndIf
	
	If(!DataFolderExists("root:Packages:NT:DataSets"))
		NewDataFolder root:Packages:NT:DataSets
	EndIf
	
	If(!DataFolderExists("root:Packages:NT:Settings"))
		NewDataFolder root:Packages:NT:Settings
		Variable firstLoad = 1
	Else
		firstLoad = 0
	EndIf
	
	DFREF NTF = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	
	//List Box Selection Waves//
	//************************//
	
	//Match List Box
	Make/O/N=0 NTF:MatchLB_SelWave
	Wave MatchLB_SelWave = NTF:MatchLB_SelWave
	MatchLB_SelWave = 0
	
	Make/O/T/N=(0,1,2) NTF:MatchLB_ListWave
	
	//BASE wave list for the Wave Match list box, no groupings
	//This is used to build a new data set
	Make/O/T/N=(0,1,2) NTF:MatchLB_ListWave_BASE
	
	//Data Set Waves List Box
	Make/O/N=0 NTD:DataSetLB_SelWave
	Wave DataSetLB_SelWave = NTD:DataSetLB_SelWave
	
	Make/O/T/N=(0,1,2) NTD:DataSetLB_ListWave
	Wave/T DataSetLB_ListWave = NTD:DataSetLB_ListWave
	
	//Data Set Names List Box
	Wave/Z/T DSNamesLB_ListWave = NTD:DSNamesLB_ListWave
	
	//Data Set Names List for the External Functions pop up menus
	String/G NTD:DSNameList
	SVAR DSNameList = NTD:DSNameList
	
	If(WaveExists(DSNamesLB_ListWave))
		DSNameList = textWaveToStringList(DSNamesLB_ListWave,";",layer=0)
	Else
		DSNameList = ""
	EndIf
	
	//Tests for existence to avoid overwriting saved data sets
	If(!WaveExists(DSNamesLB_ListWave))
		//2nd layer dimension will be the filter settings for each data set name
		//3rd layer dimension wil be the folder selection for each data set name
		Make/T/N=(0,1,3) NTD:DSNamesLB_ListWave
		Wave/T DSNamesLB_ListWave = NTD:DSNamesLB_ListWave
	EndIf

	Make/O/N=(DimSize(DSNamesLB_ListWave,0)) NTD:DSNamesLB_SelWave
	Wave DSNamesLB_SelWave = NTD:DSNamesLB_SelWave
	DSNamesLB_SelWave = 0
	
	//String variable to hold names of data sets for drop down menus
	String/G NTD:DSNames
	SVAR DSNames = NTD:DSNames
	DSNames = "Wave Match;Navigator;--;" + textWaveToStringList(DSNamesLB_ListWave,";")
	
	//This will be used by the 'ds' structure to hold the data set waves
	//after a Command Function has been called
	String/G NTD:DataSetWaves
	SVAR DataSetWaves = NTD:DataSetWaves
	DataSetWaves = "" 
	
	Make/WAVE/O/N=0 NTD:DataSetWaveRefs
	
	//This will hold the interim data set structure binary data,
	//so it can be retrieved by external functions
	Make/O/N=1 root:Packages:NT:ds
	
	//Folder list box
	Make/O/N=1 NTF:FolderLB_SelWave
	Wave FolderLB_SelWave = NTF:FolderLB_SelWave
	FolderLB_SelWave = 0
	
	Make/O/T/N=1 NTF:FolderLB_ListWave
	Wave/T FolderLB_ListWave = NTF:FolderLB_ListWave
	
	//Waves list box
	Make/O/N=1 NTF:WavesLB_SelWave
	Wave WavesLB_SelWave = NTF:WavesLB_SelWave
	WavesLB_SelWave = 0
	
	Make/O/T/N=1 NTF:WavesLB_ListWave
	Wave/T WavesLB_ListWave = NTF:WavesLB_ListWave
	
	//INITIALIZE PARAMETERS-----------------------------------------
	//Parameter panel open/close status
	Variable/G NTF:foldStatus
	NVAR foldStatus = NTF:foldStatus
	foldStatus = 0 //closed default
	
	//Parameter panel open/close status
	Variable/G NTF:navPanelStatus
	NVAR navPanelStatus = NTF:navPanelStatus
	navPanelStatus = 1 //open default
	
	Variable/G NTF:numMainCommands
	
	String/G NTF:listFocus
	SVAR listFocus = NTF:listFocus
	listFocus = ""
	
	String/G NTF:filterSettings
	SVAR filterSettings = NTF:filterSettings
	filterSettings = ""
	
	//Saves the folder selection that went into a WaveMatch
	//This will be sent to new data sets for saving.
	String/G NTF:folderSelection
	SVAR folderSelection =  NTF:folderSelection
	folderSelection = ""
	
	//Match and NOT-match, Relative Folder, and Wave grouping string parameters
	String/G NTF:waveMatchStr
	String/G NTF:waveNotMatchStr
	String/G NTF:relFolderStr
	String/G NTF:waveGroupingStr
	String/G NTF:prefixGroupingStr
	String/G NTF:groupGroupingStr
	String/G NTF:seriesGroupingStr
	String/G NTF:sweepGroupingStr
	String/G NTF:traceGroupingStr
	
	//these are for saving the original filter settings prior to Data Set update/add
	//if we ever want to send the data set back to the Wave Match list box, we'll need to
	//save this data.
//	String/G NTF:prefixOrigGroupingStr
//	String/G NTF:groupOrigGroupingStr
//	String/G NTF:seriesOrigGroupingStr
//	String/G NTF:sweepOrigGroupingStr
//	String/G NTF:traceOrigGroupingStr
//	
//	SVAR filters.prefixOrig = root:Packages:NT:prefixOrigGroupingStr
//	SVAR filters.groupOrig = root:Packages:NT:groupOrigGroupingStr
//	SVAR filters.seriesOrig = root:Packages:NT:seriesOrigGroupingStr
//	SVAR filters.sweepOrig = root:Packages:NT:sweepOrigGroupingStr
//	SVAR filters.traceOrig = root:Packages:NT:traceOrigGroupingStr
//	filters.prefixOrig = ""
//	filters.groupOrig = ""
//	filters.seriesOrig = ""
//	filters.sweepOrig = ""
//	filters.traceOrig = ""
	
	SVAR waveMatchStr = NTF:waveMatchStr; waveMatchStr = "*"
	SVAR waveNotMatchStr = NTF:waveNotMatchStr; waveNotMatchStr = ""
	SVAR relFolderStr = NTF:relFolderStr;relFolderStr = ""
	SVAR waveGroupingStr = NTF:waveGroupingStr;waveGroupingStr = ""
	
	//Underscore filter string parameters
	SVAR prefixGroupingStr = NTF:prefixGroupingStr;prefixGroupingStr = ""
	SVAR groupGroupingStr = NTF:groupGroupingStr; groupGroupingStr = ""
	SVAR seriesGroupingStr = NTF:seriesGroupingStr; seriesGroupingStr = ""
	SVAR sweepGroupingStr = NTF:sweepGroupingStr; sweepGroupingStr = ""
	SVAR traceGroupingStr = NTF:traceGroupingStr; traceGroupingStr = ""
	
	//Data Set wave list strings
	String/G NTF:matchWaveNameList
	String/G NTF:matchFullPathList
	String/G NTD:DSWaveNameList
	String/G NTD:DSWaveNameFullPathList
	
	SVAR matchWaveNameList = root:Packages:NT:matchWaveNameList; matchWaveNameList = ""
	SVAR matchFullPathList = root:Packages:NT:matchFullPathList; matchFullPathList = ""
	SVAR DSWaveNameList = NTD:DSWaveNameList; DSWaveNameList = ""
	SVAR DSWaveNameFullPathList = NTD:DSWaveNameFullPathList; DSWaveNameFullPathList = ""
	
	//Master command line entry string and editing indicator
	String/G NTF:masterCmdLineStr
	SVAR masterCmdLineStr = NTF:masterCmdLineStr
	masterCmdLineStr = ""
	
	Variable/G NTF:editingMasterCmdLineStr
	NVAR editingMasterCmdLineStr = NTF:editingMasterCmdLineStr
	editingMasterCmdLineStr = -1
	
	//Data set variable for data set name entry
	String/G NTD:dsNameInput
	SVAR dsNameInput = NTD:dsNameInput
	dsNameInput = ""
	
	//Current Command Menu selection
	String/G NTF:selectedCmd
	SVAR selectedCmd = NTF:selectedCmd
	selectedCmd = "Measure"
	
	//Current WaveSelector menu selection
	String/G NTF:waveSelectorStr
	SVAR waveSelectorStr = NTF:waveSelectorStr
	waveSelectorStr = "Wave Match"
	
	//Holds the command list for the workflow
	Make/T/O/N=0 NTF:workFlowCmds
	
	//External functions strings and variables
	String/G NTF:isOptional
	SVAR isOptional = NTF:isOptional
	isOptional = ""
	
	If(!WaveExists(NTF:ExtFunc_Parameters))
		Make/T/O/N=(6,1) NTF:ExtFunc_Parameters
	EndIf
	
	Wave/T ExtFunc_Parameters = NTF:ExtFunc_Parameters
	Wave/T param = GetExternalFunctionData(ExtFunc_Parameters)
	
	Variable/G NTF:numExtParams
	String/G  NTF:extParamTypes
	String/G NTF:extParamNames
	String/G NTF:ctrlList_extFunc
	Make/WAVE/O/N=0 NTF:extFuncWaveRefs
	
	//VIEWER variables and strings
	Variable/G NTF:viewerOpen
	NVAR viewerOpen = NTF:viewerOpen
	viewerOpen = 0
	
	String/G NTF:viewerRecall
	SVAR viewerRecall = NTF:viewerRecall
	viewerRecall = ""
	
	Variable/G NTF:areHorizSeparated
	NVAR areHorizSeparated = NTF:areHorizSeparated
	areHorizSeparated = 0
	
	Variable/G NTF:areVertSeparated
	NVAR areVertSeparated = NTF:areVertSeparated
	areVertSeparated = 0
	
	//Loaded Packages strings
	String/G NTF:loadedPackages
	SVAR loadedPackages = NTF:loadedPackages
	loadedPackages = "Main;"
	
	//NeuroTools SETTINGS-----------------------------------------------
	//Parameter Panel Open Speed
	DFREF NTS = root:Packages:NT:Settings
	Variable/G NTS:ppr
	NVAR ppr = NTS:ppr
	
	//NT Scale Factor
	Variable/G NTS:scaleFactor
	NVAR scaleFactor = NTS:scaleFactor
	
	//Only set if it is the first time loading the tool box
	If(firstLoad)
		ppr = 60
		scaleFactor = 1
	EndIf

	return 1
End

//Initializes the external functions module, and fills out a text wave with the data for each 
//main function in NT_ExternalFunctions.ipf'
Function/Wave GetExternalFunctionData(param)
	Wave/T param
	Variable i,j
	
	//function list
	String funcs = GetExternalFunctions()
	String keys = "NAME;TYPE;THREADSAFE;RETURNTYPE;N_PARAMS;N_OPT_PARAMS;"
	
	//Wave to hold all the function parameter data
	Redimension/N=(-1,ItemsInList(funcs,";")) param
	
	//Will keep track if there are empty variables in the text wave across all functions
	Variable isEmpty = 0
	Variable emptySlots = 100
	
	//function data
	For(i=0;i<ItemsInList(funcs,";");i+=1)
		String theFunction = StringFromList(i,funcs,";")
		
		//Function info
		String info = FunctionInfo("NT_" + theFunction)
		
		//Gets the actual code for the beginning of the function to extract parameter names
		String functionStr = ProcedureText("NT_" + theFunction,0)
		Variable pos = strsearch(functionStr,")",0)
		functionStr = functionStr[0,pos]
		functionStr = RemoveEnding(StringFromList(1,functionStr,"("),")")
		
		//Resize according to the parameter number
		Variable numParams = str2num(StringByKey("N_PARAMS",info,":",";"))
		If(numtype(numParams) == 2)
			numParams = 0
		EndIf
		
		If(6 + numParams*3 > DimSize(param,0))
			Redimension/N=(6 + numParams * 3,-1) param
		EndIf
			
		For(j=0;j<numParams*3;j+=1)
			keys += "PARAM_" + num2str(j) + "_TYPE;PARAM_" + num2str(j) + "_NAME;PARAM_" + num2str(j) + "_VALUE;"
		EndFor
		
		Variable whichParam = 0
		For(j=0;j < 6 + numParams*3;j+=1)
			String theKey = StringFromList(j,keys,";")
			
			//Label the dimension
			SetDimLabel 0,j,$theKey,param
			SetDimLabel 1,i,$theFunction,param
			
			//Add the function data to the wave
			If(stringmatch(theKey,"*PARAM*VALUE*"))
				continue
			EndIf
			
			If(stringmatch(theKey,"*PARAM*NAME*"))
				param[j][i] = StringFromList(whichParam,functionStr,",")
				whichParam += 1
			Else
				param[j][i] = StringByKey(theKey,info,":",";")
			EndIf	
		EndFor
		
		Variable diff = DimSize(param,0) - (6 + numParams * 3)
		If(diff)
			param[6 + numParams * 3,DimSize(param,0)-1][i] = ""
		EndIf
		
		If(diff < emptySlots)
			emptySlots = diff
		EndIf
	EndFor
	
	Redimension/N=(DimSize(param,0) - emptySlots,-1) param
	return param
End

//Makes wave and string lists for the command list
Function MakeCommandList()
	//Set data folder reference
	DFREF NT = root:Packages:NT
	
	Make/O/T/N=(2,2) NT:controlListWave
	Wave/T controlListWave = NT:controlListWave
	
	controlListWave[0][0] = "Main"
	controlListWave[0][1] = "Measure;Average;Errors;PSTH;-;Duplicate Rename;Kill Waves;Set Wave Note;Move To Folder;New Data Folder;Kill Data Folder;-;Run Cmd Line;External Function;"

	controlListWave[1][0] = "Imaging"
	controlListWave[1][1] = "Get ROI;dF Map;"
	return 1
End



//Defines the CommandMenu drop down menu
Menu "CommandMenu",contextualMenu
		
//	SubMenu "Wave Tools"
//		AddSubMenu("Wave Tools"),""
//	End
//	
	AddSubMenu("Main"),""
	
	AddSubMenu("Imaging"),""
	
End

//Defines the external functions drop down menu
Menu "ExternalFuncMenu",contextualMenu
	GetExternalFunctions(),""
End

//Loads the Imaging Package for access to specialized Calcium imaging functions
Function LoadImagingPackage()
	DFREF NTF = root:Packages:NT
	SVAR loadedPackages = NTF:loadedPackages
	If(!stringmatch(loadedPackages,"*Imaging*"))
		//LOAD
		If(DataFolderExists("root:Packages:twoP"))
			loadedPackages += "Imaging;"
			
			//Load procedures
			Execute/P/Q/Z "INSERTINCLUDE \"NT_Imaging_Package\""
			Execute/P/Q/Z "COMPILEPROCEDURES "
			
			//Load the controls, etc.
			//Executes command string to avoid compilation prior to loading the package.
			Execute/Q/Z "NT_Imaging_CreateControls()"
		EndIf
	Else
		//UNLOAD
		loadedPackages = RemoveFromList("Imaging;",loadedPackages,";")
		
		//Remove procedures
		Execute/P/Q/Z "DELETEINCLUDE \"NT_Imaging_Package\""
		Execute/P/Q/Z "COMPILEPROCEDURES "
			
		//return to a main menu function
		SVAR selectedCmd = NTF:selectedCmd
		switchCommandMenu("Measure")
		SwitchControls("Measure",selectedCmd)
		switchHelpMessage("Measure")
	EndIf
	
	//Rebuild all the menus
	BuildMenu "All"
	
End

//Contextual menu for the wave list selector in the parameters panel
Menu "WaveListSelectorMenu",contextualMenu,dynamic
	AddSubMenu("WaveSelector"),""
End

Menu "GroupingMenu",contextualMenu
	"\\M0Concatenate (/WG=-2);\\M0Folder (/WG=-1);\\M0Position (/WG);\\M0Block (/B);\\M0Stride (/S);\\M0Wave Set Number (/WSN);\\M0Wave Set Index (/WSI);",""
End	

//Loads the Imaging functions for the NeuroTools
Menu "Macros",dynamic
	Submenu "Load Packages"
		 LoadUnload("Imaging"),LoadImagingPackage()
	End
End

Function/S LoadUnload(package)
	String package
	DFREF NTF = root:Packages:NT
	SVAR loadedPackages = NTF:loadedPackages
	
	If(!SVAR_EXISTS(loadedPackages))
		return ""
	EndIf
	
	If(!stringmatch(loadedPackages,"*Imaging*"))
		return "Imaging"
	Else
		return "Unload Imaging"
	EndIf
End

//Uses the selection from the Grouping menu to append the appropriate flag to the grouping SetVariable box
Function appendGroupSelection(selection)
	String selection
	String output = ""
	
	ControlInfo/W=NT waveGrouping
	strswitch(selection)
		case "Concatenate":
			output = "/WG=2"
			break
		case "Folder":
			output = "/WG=-1"
			break
		case "Position":
			output = "/WG="
			break
		case "Block":
			output = "/B="
			break
		case "Stride":
			output = "/S="
			break
		case "Wave Set Number":
			output = "/WSN="
			break
		case "Wave Set Index":
			output = "/WSI="
			break
	endswitch
	
	SetVariable waveGrouping win=NT,value=_STR:S_Value + output,activate
	
End

//Gets the commands to put in the menu
//Add new cases for each additional submenu, which are defined in the Contextual Menu definition above.
Function/S AddSubMenu(String package)
	DFREF NTF = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	
	SVAR loadedPackages = NTF:loadedPackages
	
	Wave/T controlListWave = NTF:controlListWave
	Variable index
	String commandStr = ""
	
	If(!SVAR_EXISTS(loadedPackages))
		return ""
	EndIf
	
	strswitch(package)
		case "Main":
			If(!stringmatch(loadedPackages,"*Main*"))
				return ""
			EndIf
			index = tableMatch("Main",controlListWave)
			If(index == -1)
				return ""
			EndIf
			commandStr = controlListWave[index][1]
			break
		case "Wave Tools":
			If(!stringmatch(loadedPackages,"*Wave Tools*"))
				return ""
			EndIf
			index = tableMatch("Wave Tools",controlListWave)
			If(index == -1)
				return ""
			EndIf
			commandStr = controlListWave[index][1]
			break
		case "Imaging":
			If(!stringmatch(loadedPackages,"*Imaging*"))
				return ""
			EndIf
			
			index = tableMatch("Imaging",controlListWave)
			If(index == -1)
				return ""
			EndIf
			commandStr = "-;" + controlListWave[index][1]
			break
		case "WaveSelector":
			commandStr = updateDSNameList()
			break
	endswitch
		
	return commandStr
End

//Assigns control variables to functions from the 'Command' pop up menu
Function CreateControlLists()
	DFREF NTF = root:Packages:NT
	Wave/T controlListWave = NTF:controlListWave
	
	If(!WaveExists(controlListWave))
		LoadNT()
	EndIf
	
   //Control Assignment wave will hold the control names assigned to each 
   //command function in the controlListWave
   Make/O/T/N=(12,3) NTF:controlAssignments 
	Wave/T controlAssignments = NTF:controlAssignments 
	
	//To change the order in the drop down menu, change the order in the controlListWave.
	controlAssignments[0][0] = "Average"
	controlAssignments[0][1] = "WaveListSelector;outFolder;replaceSuffixCheck;"
	controlAssignments[0][2] = "210" //this is the required width of the parameters panel.
												//some functions require larger areas.
	
	controlAssignments[1][0] = "Errors"
	controlAssignments[1][1] = "WaveListSelector;errType;outFolder;replaceSuffixCheck;"
	controlAssignments[1][2] = "210"
	
	controlAssignments[2][0] = "PSTH"
	controlAssignments[2][1] = "WaveListSelector;binSize;spkThreshold;histType;outFolder;flattenWaveCheck;startTmPSTH;endTmPSTH;"
	controlAssignments[2][2] = "210"
	
	controlAssignments[3][0] = "Kill Waves"
	controlAssignments[3][1] = "WaveListSelector;"
	controlAssignments[3][2] = "210"
	
	controlAssignments[4][0] = "Duplicate Rename"
	controlAssignments[4][1] = "WaveListSelector;prefixName;groupName;SeriesName;SweepName;TraceName;killOriginals;"
	controlAssignments[4][2] = "300"
	
	controlAssignments[5][0] = "Move To Folder"
	controlAssignments[5][1] = "WaveListSelector;moveFolderStr;relativeFolder;"
	controlAssignments[5][2] = "300"
	
	controlAssignments[6][0] = "Set Wave Note"
	controlAssignments[6][1] = "WaveListSelector;waveNote;overwriteNote;"
	controlAssignments[6][2] = "300"
	
	controlAssignments[7][0] = "External Function"
	controlAssignments[7][1] = "extFuncPopUp;extFuncHelp;goToProcButton;"
	controlAssignments[7][2] = "230"
	
	controlAssignments[8][0] = "Run Cmd Line"
	controlAssignments[8][1] = "cmdLineStr;appendCommand;clearCommand;printCommand;"
	controlAssignments[8][2] = "300"
	
	controlAssignments[9][0] = "New Data Folder"
	controlAssignments[9][1] = "NDF_RelFolder;NDF_FolderName;"
	controlAssignments[9][2] = "210"
	
	controlAssignments[10][0] = "Kill Data Folder"
	controlAssignments[10][1] = "NDF_RelFolder;NDF_FolderName;"
	controlAssignments[10][2] = "210"
	
	controlAssignments[11][0] = "Measure"
	controlAssignments[11][1] = "WaveListSelector;measureType;measureStart;measureEnd;"
	controlAssignments[11][2] = "210"
	
	NVAR numMainCommands = NTF:numMainCommands
	numMainCommands = DimSize(controlAssignments,0)
End


//Creates the controls that are used by all of the built-in command functions
Function CreateControls()
	DFREF NTF = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	DFREF NTI = root:Packages:NT:Imaging
	
	SVAR DSNames = NTD:DSNames
	
	
	//COMMON CONTROLS TO ALL FUNCTIONS
	Button WaveListSelector win=NT,font=$LIGHT,pos={507,75},size={138,20},title="\\JL▼        Wave Match",fSize=12,disable=3,proc=ntButtonProc
	
	//AVERAGE
	SetVariable outFolder win=NT,pos={460,105},size={175,20},font=$LIGHT,fsize=10,title="Output Folder:",value=_STR:"",disable=1
	CheckBox replaceSuffixCheck win=NT,pos={460,125},size={40,20},font=$LIGHT,fsize=10,title="Replace",value=1,disable=1
	
	//ERRORS
	PopUpMenu errType win=NT,pos={460,145},size={50,20},font=$LIGHT,fsize=10,title="Type",value="sem;sdev",disable=3
	
	//PSTH
	PopUpMenu histType win=NT,pos={460,150},size={90,20},fsize=10,font=$LIGHT,title="Type",value="Binned;Gaussian",disable=3
	SetVariable spkThreshold win=NT,pos={469,180},size={90,20},bodywidth=40,fsize=10,font=$LIGHT,title="Threshold",value=_NUM:0,disable=1
	SetVariable binSize win=NT,pos={469,200},size={90,20},bodywidth=40,fsize=10,font=$LIGHT,title="Bin Size",value=_NUM:0,disable=1
	Checkbox flattenWaveCheck win=NT,pos={469,260},size={50,20},side=1,fsize=10,font=$LIGHT,title="Flatten Wave",disable=1
	SetVariable startTmPSTH win=NT,pos={469,220},size={90,20},bodywidth=40,fsize=10,font=$LIGHT,title="Start",value=_NUM:0,disable=1
	SetVariable endTmPSTH win=NT,pos={469,240},size={90,20},bodywidth=40,fsize=10,font=$LIGHT,title="End",value=_NUM:0,disable=1
	
	//DUPLICATE RENAME
	SetVariable prefixName win=NT,pos={464,100},size={40,20},title="",value=_STR:"",disable=1
	SetVariable groupName win=NT,pos={509,100},size={55,20},title=" __",value=_STR:"",disable=1
	SetVariable seriesName win=NT,pos={569,100},size={55,20},title=" __",value=_STR:"",disable=1
	SetVariable sweepName win=NT,pos={624,100},size={55,20},title=" __",value=_STR:"",disable=1
	SetVariable traceName win=NT,pos={679,100},size={55,20},title=" __",value=_STR:"",disable=1
	Checkbox killOriginals win=NT,pos={464,120},size={100,20},title="Kill Originals",value=0,disable=1
	
	//SET WAVE NOTE
	SetVariable waveNote win=NT,size={274,0},pos={460,100},font=$LIGHT,fsize=12,title="Note:",value=_STR:"",disable=1
	CheckBox overwriteNote win=NT,pos={460,120},size={100,20},font=$LIGHT,fsize=10,title="Overwrite Note",value=0,disable=1
	
	//MOVE TO FOLDER
	SetVariable moveFolderStr win=NT,size={274,20},pos={460,100},font=$LIGHT,fsize=12,title="Move to:",value=_STR:"",disable=1
	SetVariable relativeFolder win=NT,size={125,20},pos={460,125},bodywidth=40,font=$LIGHT,fsize=12,limits={-inf,0,1},title="Relative Depth:",value=_NUM:0,disable=1

	//RUN CMD LINE
	SetVariable cmdLineStr win=NT,size={260,20},pos={460,100},font=$LIGHT,fsize=12,title="Cmd:",value=_STR:"",disable=1,proc=ntSetVarProc
	Button appendCommand win=NT,size={60,20},pos={495,76},font=$LIGHT,fsize=12,title="Append",valueColor=(8738,8738,8738),disable=1,proc=ntButtonProc
	Button clearCommand win=NT,size={50,20},pos={559,76},font=$LIGHT,fsize=12,title="Clear",disable=1,proc=ntButtonProc
	Checkbox printCommand win=NT,size={41,20},pos={621,78},font=$LIGHT,fsize=12,title="Print",disable=1
	
	//EXTERNAL FUNCTION
	String currentExtCmd = "Write Your Own"
	Button extFuncPopUp win=NT,pos={460,75},size={125,20},fsize=12,font=$LIGHT,proc=ntButtonProc,title="\\JL▼   " + currentExtCmd,disable=1
//	DrawText/W=NT 23,84,"Functions:"
	
	Button goToProcButton win=NT,pos={587,75},size={40,20},title="GoTo",proc=ntButtonProc,disable=1
	
	//NEW DATA FOLDER
	SetVariable NDF_RelFolder win=NT,size={120,20},fSize=12,font=$LIGHT,bodywidth=120,pos={525,100},title="Rel. Folder:",value=_STR:"",disable=1
	SetVariable NDF_FolderName win=NT,size={120,20},fSize=12,font=$LIGHT,bodywidth=120,pos={525,120},title="Folder:",value=_STR:"",disable=1

	//MEASURE
	PopUpMenu measureType win=NT,pos={460,105},font=$LIGHT,fsize=10,size={50,20},title="Type",value="Peak;Peak Location;Area;Mean;Median;Std. Dev.;Std. Error;",disable=3
	SetVariable measureStart win=NT,pos={485,130},bodywidth=40,font=$LIGHT,fsize=10,size={40,20},title="Start",limits={0,inf,0.1},value=_NUM:0,disable=1
	SetVariable measureEnd win=NT,pos={485,150},bodywidth=40,font=$LIGHT,fsize=10,size={40,20},title="End",limits={0,inf,0.1},value=_NUM:0,disable=1
End

//SETTINGS PANEL----------------------------------------------------------------------------------
Function openSettingsPanel()
	DFREF NTS = root:Packages:NT:Settings
	//Open the settings panel
	DoWindow/W=NTSettingsPanel NTSettingsPanel
	If(!V_flag)
		GetWindow NT wsize
		NewPanel/K=1/N=NTSettingsPanel/W=(V_right,V_top,V_right+200,V_top+200) as "Settings"
	Else
		DoWindow/F/W=NTSettingsPanel NTSettingsPanel
	EndIf
	
	//Parameter Settings
	NVAR ppr = NTS:ppr
	NVAR scaleFactor = NTS:scaleFactor
	SetVariable ppr win=NTSettingsPanel,pos={10,10},size={150,20},title="Parameters Open Speed",value=ppr,proc=NTSettings_SetVarProc
	SetVariable scaleFactor win=NTSettingsPanel,pos={62,30},size={98,20},title="Scale Factor",value=scaleFactor,limits={0.1,inf,0.05},proc=NTSettings_SetVarProc
	Button scaleFactorUpdate win=NTSettingsPanel,pos={162,26},size={20,20},title="∆",proc=ntButtonProc
End

//Handles SetVariable inputs for the Settings Panel
Function NTSettings_ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			If(HandleButtonClick(ba))
				print "BUTTON ERROR"
			EndIf
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function NTSettings_SetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	DFREF NTS = root:Packages:NT:Settings
	
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			
			strswitch(sva.ctrlName)
				case "ppr":
					NVAR ppr = NTS:ppr
					ppr = dval
					break
			endswitch
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

//Structure to hold all of the filter terms, wave grouping terms, and match terms
Structure filters
	SVAR match
	SVAR notMatch
	SVAR relFolder
	
	SVAR prefix
	SVAR group
	SVAR series
	SVAR sweep
	SVAR trace
	SVAR wg
	
	SVAR name
	SVAR path
EndStructure

//Data set info structure
Structure ds
	Wave/T listWave //listwave being used by the data set (Wave Match, Navigator, or a Data Set)
	SVAR name	 //data set name
	SVAR paths //string list of the waves in the wsn
	Wave/WAVE waves //wave of wave references for the wsn
	int16 num //number of wave sets
	int16 wsi //current wave set index
	int16 wsn //current wave set number
	int16 numWaves //number of waves in the current wsn
EndStructure

//Workflow info structure
Structure workflow
	int16 numCmds	//total number of commands in workflow
	int16 i //command index
	Wave/T cmds //holds the commands in workflow
EndStructure

//Fill the filter structure with string variables
Function SetFilterStructure(filters,selection)
	STRUCT filters &filters
	String selection
	Variable DataSet
	
	SVAR filters.match = root:Packages:NT:waveMatchStr
	SVAR filters.notMatch = root:Packages:NT:waveNotMatchStr
	SVAR filters.relFolder = root:Packages:NT:relFolderStr
	
	SVAR filters.prefix = root:Packages:NT:prefixGroupingStr
	SVAR filters.group = root:Packages:NT:groupGroupingStr
	SVAR filters.series = root:Packages:NT:seriesGroupingStr
	SVAR filters.sweep = root:Packages:NT:sweepGroupingStr
	SVAR filters.trace = root:Packages:NT:traceGroupingStr
	
	SVAR filters.wg = root:Packages:NT:waveGroupingStr
	
	If(!cmpstr(selection,"DataSet"))
		SVAR filters.name = root:Packages:NT:DataSets:DSWaveNameList
		SVAR filters.path = root:Packages:NT:DataSets:DSWaveNameFullPathList
	ElseIf(!cmpstr(selection,"WaveMatch"))
		SVAR filters.name = root:Packages:NT:matchWaveNameList
		SVAR filters.path = root:Packages:NT:matchFullPathList
	Else
		SVAR filters.name = root:Packages:NT:matchWaveNameList
		SVAR filters.path = root:Packages:NT:matchFullPathList
	EndIf
End