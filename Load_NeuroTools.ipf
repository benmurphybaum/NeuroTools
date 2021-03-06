﻿#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//NeuroTools (NT) is an interface for organizing and analyzing data.
//Major updates, refactoring, and reorganization from its predecessor, AnalysisTools.
//Ben Murphy-Baum, 2020

//Global Fonts

//StrConstant LIGHT = "Roboto Light"
//StrConstant REG = "Roboto"
//StrConstant TITLE = "Mongolian Baiti"
//StrConstant SUBTITLE = "Mongolian Baiti"


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
	DFREF NTS = root:Packages:NT:Settings
	
	//Build the GUI
	left += 0
	top += 0
	width = 754
	height = 515
	
	//Get the screen dimensions for scaling purposes
	String screenInfo =StringByKey("SCREEN1",IgorInfo(0),":",";")
	screenInfo = StringFromList(2,screenInfo,"=")
	
	Variable/G NTS:screenWidth
	NVAR screenWidth = NTS:screenWidth
	Variable/G NTS:screenHeight
	NVAR screenHeight = NTS:screenHeight
	
	screenWidth = str2num(StringFromList(2,screenInfo,","))
	screenHeight = str2num(StringFromList(3,screenInfo,","))
	
	Variable/G NTS:fontSize,NTS:offsetY,NTS:fontSizeDS,NTS:controlHeightDS //vertical offset of some controls based on common screen heights
	NVAR fontSize = NTS:fontSize
	NVAR fontSizeDS = NTS:fontSizeDS
	NVAR offsetY = NTS:offsetY
	NVAR controlHeightDS = NTS:controlHeightDS
	Variable/G NTS:wf
	NVAR wf =  NTS:wf
	Variable/G NTS:hf
	NVAR hf =  NTS:hf
		
	If(!cmpstr(IgorInfo(2),"Macintosh"))
		offsetY = 0
		fontSize = 9
		fontSizeDS = 12
		controlHeightDS = 20
		hf = 1
		wf = 1
	Else
		wf = screenWidth / 1440	
		hf = screenHeight / (900 + 150)
		
		switch(screenHeight)
			case 660:
				//incompatible, just get a better screen.
				return 0
			case 720:		
				//not ideal, mild cut-offs		
			case 768:
			case 800:
				offsetY = -8
				fontSize = 9
				fontSizeDS = 9
				controlHeightDS = 19
				break
			case 864:
				offsetY = -8
				fontSize = 10
				fontSizeDS = 10
				controlHeightDS = 19
				break
			case 960:
				offsetY = -8
				fontSize = 11
				fontSizeDS = 11
				controlHeightDS = 19
				break
			case 1024:
				offsetY = -8
				fontSize = 12
				fontSizeDS = 12
				controlHeightDS = 19
				break
			default: //anthing over 1024 vertical pixels should be handle native coding just fine.
				offsetY = 0
				fontSize = 12
				controlHeightDS = 20
		endswitch
	EndIf

	Variable r = ScreenResolution / 72

	//Main Panel
	NewPanel /K=1 /W=(left*r,top*r,left*r + width,top*r + height*hf) as "NeuroTools"
	DoWindow/C NT
	ModifyPanel /W=NT, fixedSize= 1
	
	//Navigator Panel and Guides
	DefineGuide/W=NT listboxLeft={FR,-300}//,listboxBottom={FB}
	NewPanel/HOST=NT/FG=(listboxLeft,FT,FR,FB)/N=navigatorPanel
	ModifyPanel/W=NT#navigatorPanel frameStyle=0
	SetDrawEnv/W=NT#navigatorPanel textxjust=1
	
	//Drag and Drop variable for the navigator
	Variable/G NTF:dragging = 0
	
	//Current data folder text
	String/G NTF:currentDataFolder
	SVAR cdf = NTF:currentDataFolder
	cdf = GetDataFolder(1)
	SetVariable NT_cdf win=NT#navigatorPanel,pos={0,28*hf},size={300,20},fsize=10,font=$LIGHT,value=cdf,title=" ",disable=2,frame=0
	
	//Back Button
	Button Back win=NT#navigatorPanel,size={30,20},pos={1,49*hf},font=$REG,fsize=9,title="Back",proc=ntButtonProc,disable=0

	//Reload NeuroTools button
	Button Reload win=NT,font=$LIGHT,size={50,20},pos={3,1},title="Reload",proc=ntButtonProc
	
	//Viewer Button
	//Draw line along bottom of the GUI as a window hook for opening and closing the Viewer window
	SetDrawEnv/W=NT xcoord= abs,ycoord= abs,linefgc= (0,0,0,16384),linethick= 4.00,gname=ViewerLine,gstart 
	DrawLine/W=NT 0,513*hf,446,513*hf
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
	Variable waveMatchPosition = 40*hf
	SetVariable waveMatch win=NT,font=$LIGHT,pos={13,waveMatchPosition},size={162,20},fsize=fontSize,title="Match",value=_STR:"*",help={"Matches waves in the selected folder.\rLogical 'OR' can be used via '||'"},disable=0,proc=ntSetVarProc
	SetVariable waveNotMatch win=NT,font=$LIGHT,pos={26,waveMatchPosition + 20*hf},size={149,20},fsize=fontSize,title="Not",value=_STR:"",help={"Excludes matched waves in the selected folder.\rLogical 'OR' can be used via '||'"},disable=0,proc=ntSetVarProc
	String helpNote = "Target subfolder for wave matching.\r Useful if matching in multiple parent folders that each have a common subfolder structure\r"
	helpNote += "Supports folder matching, and can use '||' as a logical OR to match multiple subfolder searches"
	SetVariable relativeFolderMatch win=NT,font=$LIGHT,pos={8,waveMatchPosition + 40*hf},size={167,20},fsize=fontSize,title=":Folder",value=_STR:"",help={helpNote},disable=0,proc=ntSetVarProc
   
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
	
	ListBox folderListBox win=NT#navigatorPanel,size={140,435*hf},pos={0,70*hf},mode=9,listWave=FolderLB_ListWave,selWave=FolderLB_SelWave,disable=0,proc=ntListBoxProc
	ListBox waveListBox win=NT#navigatorPanel,size={140,435*hf},pos={150,70*hf},mode=9,listWave=WavesLB_ListWave,selWave=WavesLB_SelWave,disable=0,proc=ntListBoxProc
	
	//List Box Labels
	SetDrawEnv/W=NT gstart,gname=labels
	SetDrawEnv/W=NT xcoord= abs,ycoord= abs, fsize=11, textxjust= 1,textyjust= 1,fname=$LIGHT
	DrawText/W=NT 92,112*hf,"Wave Matches"
	SetDrawEnv/W=NT xcoord= abs,ycoord= abs, fsize=11, textxjust= 1,textyjust= 1,fname=$LIGHT
	DrawText/W=NT 269,112*hf,"Data Set Waves"
	SetDrawEnv/W=NT xcoord= abs,ycoord= abs, fsize=11, textxjust= 1,textyjust= 1,fname=$LIGHT
	DrawText/W=NT 402,112*hf,"Data Sets"
	SetDrawEnv/W=NT#navigatorPanel xcoord= abs,ycoord= abs, fsize=11, textxjust= 1,textyjust= 1,fname=$LIGHT
	DrawText/W=NT#navigatorPanel 63,60*hf,"Folders"
	SetDrawEnv/W=NT#navigatorPanel xcoord= abs,ycoord= abs, fsize=11, textxjust= 1,textyjust= 1,fname=$LIGHT
	DrawText/W=NT#navigatorPanel 221,60*hf,"Waves"
	SetDrawEnv/W=NT gstop
	
	
	SetDrawEnv/W=NT#navigatorPanel xcoord= abs,ycoord= abs, fsize=14, textxjust= 1,textyjust= 1,fname=$LIGHT
	DrawText/W=NT#navigatorPanel 143,15*hf,"Navigator"
	
	SetDrawEnv/W=NT xcoord= abs,ycoord= abs, fsize=14, textxjust= 1,textyjust= 1, textrgb= (0,0,0),fname=$LIGHT,gstart,gname=parameterText
	DrawText/W=NT 554,15*hf,"Parameters"
	SetDrawEnv/W=NT gstop
	
	
	SetDrawEnv/W=NT xcoord= abs,ycoord= abs, fsize=12, textxjust= 1, textrgb= (0,0,0),textyjust= 1,fname=$LIGHT,gname=waveSelectorTitle,gstart
	DrawText/W=NT 483,85*hf,"Waves:"
	SetDrawEnv/W=NT gstop
	
	SetDrawEnv/W=NT fname= $TITLE,textrgb= (43690,43690,43690),xcoord= abs,ycoord= abs,textxjust= 1,textyjust= 1
	DrawText/W=NT 314,35*hf,"\\Z36N e u r o T o o l s"
	SetDrawEnv/W=NT fname= $SUBTITLE,textrgb= (43690,43690,43690),xcoord= abs,ycoord= abs,textxjust= 1,textyjust= 1
	DrawText/W=NT 314,66*hf,"A data organization and analysis toolbox"
	
	//Group Box for control parameters
	GroupBox parameterBox win=NT,pos={455,69},size={197,437*hf},disable=0,title="" 
	
	//Data Set controls
	Variable addDSPosition = 444 * hf + offsetY
	Button addDataSet win=NT,pos={340,addDSPosition},fsize=fontSizeDS,font=$LIGHT,size={100,controlHeightDS},title="Add Data Set",disable=0,help={"Adds a new data set with the specified name"},proc=ntButtonProc
	SetVariable dsNameInput win=NT,pos={345,468*hf},size={90,20},disable=1,focusRing=0,frame=0,value=_STR:"",proc=ntSetVarProc
	GroupBox dsNameGroupBox win=NT,pos={340,463*hf},size={100,26},disable=1
	
	//Button addDataSetFromSelection win=NT,font=$LIGHT,pos={172,468},size={100,20},title="From Selection",help={"Adds a new data set from the wave list in Browse mode"},disable=0,proc=ntButtonProc
	Button updateDataSet win=NT,fsize=fontSizeDS,font=$LIGHT,pos={340,addDSPosition+19},size={100,controlHeightDS},title="Update DS",help={"Udpate the selected data set from the Wave Match list box"},disable=0,proc=ntButtonProc
	Button delDataSet win=NT,fsize=fontSizeDS,font=$LIGHT,pos={340,addDSPosition+38},size={100,controlHeightDS},title="Delete DS",help={"Delete the selected data set"},disable=0,proc=ntButtonProc	
	
	helpNote = "Organize the wave list into wave sets by the indicated underscore position.\rUses zero offset; -2 concatenates into a single wave set"
	Variable groupingYPos = 471*hf + offsetY
	SetVariable waveGrouping win=NT,pos={58,groupingYPos},size={85,20},title="",disable=0,fsize=fontSize,value=_STR:"",help={helpNote},proc=ntSetVarProc
	SetDrawEnv/W=NT fsize=9,fname=$LIGHT
	DrawText/W=NT 14,groupingYPos + 13,"Grouping"
	SetDrawEnv/W=NT fsize=9,fname=$LIGHT
	DrawText/W=NT 27,groupingYPos + 33,"Filters"
	
	
	SetVariable prefixGroup win=NT,pos={58,groupingYPos + 20},size={40,20},title="",disable=0,fsize=fontSize,value=_STR:"",help={"Filter the wave list by the 1st underscore position"},proc=ntSetVarProc
	SetVariable groupGroup win=NT,pos={99,groupingYPos + 20},size={55,20},title=" __",disable=0,fsize=fontSize,value=_STR:"",help={"Filter the wave list by the 2nd underscore position"},proc=ntSetVarProc
	SetVariable seriesGroup win=NT,pos={155,groupingYPos + 20},size={55,20},title=" __",disable=0,fsize=fontSize,value=_STR:"",help={"Filter the wave list by the 3rd underscore position"},proc=ntSetVarProc
	SetVariable sweepGroup win=NT,pos={211,groupingYPos + 20},size={55,20},title=" __",disable=0,fsize=fontSize,value=_STR:"",help={"Filter the wave list by the 4th underscore position"},proc=ntSetVarProc
	SetVariable traceGroup win=NT,pos={266,groupingYPos + 20},size={55,20},title=" __",disable=0,fsize=fontSize,value=_STR:"",help={"Filter the wave list by the 5th underscore position"},proc=ntSetVarProc
	
	Button clearFilters win=NT,pos={153,468*hf + offsetY},fsize=fontSizeDS,font=$LIGHT,size={130,20},title="Clear Group/Filters",disable=0,help={"Clear all filters and groupings"},proc=ntButtonProc
	
	//Initialize the match list from the current data folder
   SetDataFolder root:
   cdf = "root:"
   
   //Draws selection dots around the selected list box
   SVAR listFocus = NTF:listFocus
   listFocus = "WaveMatch"
   
   //Initialize the wave match list
   getWaveMatchList()
   
	//List box that holds wave matches
	ListBox MatchListBox win=NT,pos={6,120*hf},size={172,320*hf + offsetY},mode=9,listWave=MatchLB_ListWave,selWave=MatchLB_SelWave,disable=0,proc=ntListBoxProc
	
	//List box that holds data set wave lists
	ListBox DataSetWavesListBox win=NT,mode=9,pos={183,120*hf},size={172,320*hf + offsetY},listWave=DataSetLB_ListWave,selWave=DataSetLB_SelWave,disable=0,proc=ntListBoxProc
	
	//List box to hold names of data sets 
	ListBox DataSetNamesListBox win=NT,mode=2,pos={361,120*hf},size={80,320*hf + offsetY},listWave=DSNamesLB_ListWave,selWave=DSNamesLB_SelWave,disable=0,proc=ntListBoxProc
	
	//ListBox position indicators, used for keeping track of resizing
	NVAR WM_Position = NTF:WM_Position
	ControlInfo/W=NT MatchListBox
	WM_Position = V_left + V_width
	
	NVAR DSW_Position = NTF:DSW_Position
	ControlInfo/W=NT DataSetWavesListBox
	DSW_Position = V_left + V_width
	
	NVAR Folders_Position = NTF:Folders_Position
	ControlInfo/W=NT#navigatorPanel FolderListBox
	Folders_Position = 460 + V_left + V_width
	
	//Draw line between matching and data set section, and the Data Browser section
	//Put the line into its own draw group so I can pull it out individually
	SetDrawEnv/W=NT xcoord= abs,ycoord= abs,linefgc= (0,0,0,16384),linethick= 4.00,gname=NavLine,gstart 
	DrawLine/W=NT 448,0,448,515*hf
//	SetDrawEnv/W=NT# xcoord= abs,ycoord= abs,linefgc= (0,0,0,16384),linethick= 4.00,
	SetDrawEnv/W=NT gstop
	
	//Progress bar control
	NVAR progressVal = NTF:progressVal
	progressVal = 0

	ValDisplay progress win=NT,pos={198,85*hf},size={233,4},limits={0,100,0},frame=0,barmisc={0,0},mode=0,highColor=(0,43690,65535),value=#"root:Packages:NT:progressVal",disable=1
	
	//For opening and closing the parameters infold for running functions
	SetWindow NT hook(MouseClickHooks) = MouseClickHooks
	
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
	
	//Print version and update information
	Variable secs = DateTime - Date2Secs(-1,-1,-1)
	String updateTime = Secs2Time(secs,1)
	String updateDate = Secs2Date(secs,0)
	
	print "NeuroTools"
	print "Version: ",NTversion
	print "Last Update: ",updateDate,updateTime,"UTC"
	
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
	Make/O/N=1 root:Packages:NT:progress
	
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
	
	//Progress bar
	Variable/G NTF:progressVal
	NVAR progressVal = NTF:progressVal
	
	Variable/G NTF:progressCount
	NVAR progressCount = NTF:progressCount
	
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
	
	//Saved name list for quick access to often-used string lists
	String/G NTF:savedNameList
	SVAR savedNameList = NTF:savedNameList
	
	//Holds all of the saved name lists	
	If(!WaveExists(NTF:savedNameTable))
		Make/O/N=(1,2)/T NTF:savedNameTable
	EndIf	
	
	//Current Command Menu selection
	String/G NTF:selectedCmd
	SVAR selectedCmd = NTF:selectedCmd
	selectedCmd = "Measure"
	
	//Current WaveSelector menu selection
	String/G NTF:waveSelectorStr
	SVAR waveSelectorStr = NTF:waveSelectorStr
	waveSelectorStr = "Wave Match"
	
	//Holds all of the text group titles
	Make/N=(0,3)/O/T NTF:textGroups
	
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
	
	//GUI position indicators for resizing the listboxes
	Variable/G NTF:WM_Position
	NVAR WM_Position = NTF:WM_Position
	WM_Position = 0
	
	Variable/G NTF:DSW_Position
	NVAR DSW_Position = NTF:DSW_Position
	DSW_Position = 0
	
	Variable/G NTF:Folders_Position
	NVAR Folders_Position = NTF:Folders_Position
	Folders_Position = 0
	
	Variable/G NTF:WM_Resize
	NVAR WM_Resize = NTF:WM_Resize
	WM_Resize = 0
	
	Variable/G NTF:DS_Resize
	NVAR DS_Resize = NTF:DS_Resize
	DS_Resize = 0
	
	Variable/G NTF:Waves_Resize
	NVAR Waves_Resize = NTF:Waves_Resize
	Waves_Resize = 0
	
	Variable/G NTF:Folders_Resize
	NVAR Folders_Resize = NTF:Folders_Resize
	Folders_Resize = 0
	
	//For communication between main NT module and ScanImage, etc. modules to pass return values between them
	String/G NTF:returnStr 
	SVAR returnStr = NTF:returnStr
	returnStr = ""
	
	Variable/G NTF:returnVar
	NVAR returnVar = NTF:returnVar
	returnVar = 0
	
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
	
	String/G NTF:selectedTrace
	SVAR selectedTrace = NTF:selectedTrace
	selectedTrace = ""
	
	String/G NTF:selectedAxis
	SVAR selectedAxis = NTF:selectedAxis
	selectedAxis = ""
	
	//Wavesurfer listwave for the loader
	Make/O/N=0/T NTF:wsSweepListWave
	Make/O/N=0 NTF:wsSelWave
	Make/O/N=0/T NTF:wsFileListWave
	Make/O/N=0 NTF:wsFileSelWave
	Make/O/N=(0,2)/T NTF:wsStimulusDataListWave
	
	String/G NTF:wsFilePath
	String/G NTF:wsFileName
	SVAR wsFilePath = NTF:wsFilePath
	SVAR wsFileName = NTF:wsFileName
	wsFilePath = ""
	wsFileName = ""
	
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
	
	If(ppr == 0)
		ppr = 60
	EndIf

	return 1
End

//Returns a string list of all the saved names
Function/S GetSavedNameList()
	DFREF NTF = root:Packages:NT
	String list = ""
	
	//This table holds all of the saved names
	Wave/T savedNameTable = NTF:savedNameTable
	
	Variable i
	For(i=0;i<DimSize(savedNameTable,0);i+=1)
		list += savedNameTable[i][0] + ";"
	EndFor
	
	return list
End

//Initializes the external functions module, and fills out a text wave with the data for each 
//main function in NT_ExternalFunctions.ipf'
Function/Wave GetExternalFunctionData(param)
	Wave/T param
	Variable i,j
	
	//function list
	String funcs = GetExternalFunctions()
	
	//Wave to hold all the function parameter data
	Redimension/N=(-1,ItemsInList(funcs,";")) param
	
	//Will keep track if there are empty variables in the text wave across all functions
	Variable isEmpty = 0
	Variable emptySlots = 100
	
	//Keeps track of pop up menus
	Variable isPopMenu = 0
	String popUpStr = ""
	
	//function data
	For(i=0;i<ItemsInList(funcs,";");i+=1)
		String theFunction = StringFromList(i,funcs,";")
		
		//Function info
		String info = FunctionInfo("NT_" + theFunction)
		
		//Gets the actual code for the beginning of the function to extract parameter names
		String fullFunctionStr = ProcedureText("NT_" + theFunction,0)
		Variable pos = strsearch(fullFunctionStr,")",0)
		String functionStr = fullFunctionStr[0,pos]
		functionStr = RemoveEnding(StringFromList(1,functionStr,"("),")")
		
		//Resize according to the parameter number
		Variable numParams = str2num(StringByKey("N_PARAMS",info,":",";"))
		If(numtype(numParams) == 2)
			numParams = 0
		EndIf
		
		If(6 + numParams*4 > DimSize(param,0))
			Redimension/N=(6 + numParams * 4,-1) param
		EndIf
			
		String keys = "NAME;TYPE;THREADSAFE;RETURNTYPE;N_PARAMS;N_OPT_PARAMS;"
		
		For(j=0;j<numParams;j+=1)
			keys += "PARAM_" + num2str(j) + "_TYPE;PARAM_" + num2str(j) + "_NAME;PARAM_" + num2str(j) + "_ITEMS;PARAM_" + num2str(j) + "_VALUE;"
		EndFor
		
		//Try to find previously created functions
		Variable col = tableMatch("NT_" + theFunction,param,returnCol=1)
		
		//insert the previous column position into the current one, in case of reordering
		//prevents losing preset values for the parameters when new functions are added
		If(col != -1)
			param[][i] = param[p][col]
		EndIf
			
		//Label the dimension for each function column
		SetDimLabel 1,i,$theFunction,param
		
		Variable whichParam = 0
		For(j=0;j < 6 + numParams*4;j+=1)
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
				
				If(stringmatch(param[j][i],"menu_*"))
					popUpStr = param[j][i]
				Else
					popUpStr = ""
				EndIf 
				
				
			ElseIf(stringmatch(theKey,"*PARAM*ITEMS*"))
				If(strlen(popUpStr))
					param[j][i] = NT_GetPopUpValue(popUpStr,fullFunctionStr)
				Else
					param[j][i] = ""
				EndIf
			ElseIf(stringmatch(theKey,"*PARAM*VALUE*"))
				If(strlen(popUpStr))
					If(!strlen(param[j][i]))
						param[j][i] = StringFromList(0,param[j-1][i],";")
					EndIf
					
					popUpStr = "" //reset
				EndIf
			Else
				param[j][i] = StringByKey(theKey,info,":",";")
			EndIf	
		EndFor
		
		Variable diff = DimSize(param,0) - (6 + numParams * 4)
		If(diff)
			param[6 + numParams * 4,DimSize(param,0)-1][i] = ""
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
	
	Make/O/T/N=(3,2) NT:controlListWave
	Wave/T controlListWave = NT:controlListWave
	
	controlListWave[0][0] = "Main"
	controlListWave[0][1] = "Measure;Average;Errors;PSTH;Subtract Mean;Subtract Trend;-;Load Ephys;-;Duplicate Rename;Kill Waves;Set Wave Note;Move To Folder;New Data Folder;Kill Data Folder;-;Run Cmd Line;External Function;"

	controlListWave[1][0] = "Imaging"
	controlListWave[1][1] = "Get ROI;dF Map;"
	
	controlListWave[2][0] = "ScanImage"
	controlListWave[2][1] = "Load Scans;Load Suite2P;Get ROI;dF Map;Max Project;Vector Sum Map;Population Vector Sum;Response Quality;Adjust Galvo Distortion;Align Images;"
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
	
	AddSubMenu("ScanImage"),""
	
End

//Defines the external functions drop down menu
Menu "ExternalFuncMenu",contextualMenu
	GetExternalFunctions(),""
End

Menu "MeasureTypeMenu",contextualMenu
	"Peak;Peak Location;Area;Mean;Median;Std. Dev.;Std. Error;-;# Spikes;Vector Sum;",""
End

Function/S setupMeasureControls(selection)
	String selection
	
	//Start by setting all Measure associated controls to invisible
	String invisibleList = "measureStart;measureEnd;angleWave;measureWidth;measureThreshold;vectorSumReturn;sortOutput;"
	controlsVisible(invisibleList,1)
	
	String visibleList = "measureType;"
	
	strswitch(selection)
		case "Vector Sum":
			visibleList += "angleWave;vectorSumReturn;"
			break
		case "Peak":
			visibleList += "measureStart;measureEnd;measureWidth;sortOutput;"
			break
		case "# Spikes":
			visibleList += "measureStart;measureEnd;measureThreshold;sortOutput;"
			break
		default:
			visibleList += "measureStart;measureEnd;sortOutput;"
			break	
	endswitch
	
	//Make all the appropriate controls visible
	controlsVisible(visibleList,0)
End

//Loads the Imaging Package for access to specialized Calcium imaging functions
Function LoadImagingPackage()
	DFREF NTF = root:Packages:NT
	SVAR loadedPackages = NTF:loadedPackages
	If(!stringmatch(loadedPackages,"*Imaging*"))
	
		//LOAD - supports Jamie Boyd's 2PLSM Igor Imaging software
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

//Loads the ScanImage Imaging Package for access to specialized Calcium imaging functions 
//that work with scanimage bigtiff files
Function LoadScanImagePackage()
	DFREF NTF = root:Packages:NT
	SVAR loadedPackages = NTF:loadedPackages
	If(!stringmatch(loadedPackages,"*ScanImage*"))
	
		//LOAD - supports Vidrio's ScanImage software
		loadedPackages += "ScanImage;"
		
		//Load procedures
		Execute/P/Q/Z "INSERTINCLUDE \"NT_ScanImage_Package\""
		Execute/P/Q/Z "INSERTINCLUDE \"ScanImageTiffReader\""
		Execute/P/Q/Z "COMPILEPROCEDURES "
	
		//Load the controls, etc.
		//Executes command string to avoid compilation prior to loading the package.
		Execute/Q/P "SI_CreatePackage()"
	Else
		//UNLOAD
		loadedPackages = RemoveFromList("ScanImage;",loadedPackages,";")
		
		//Kill the Image Browser
		KillWindow/Z SI
		
		//Remove procedures
		Execute/P/Q/Z "DELETEINCLUDE \"NT_ScanImage_Package\""
		Execute/P/Q/Z "DELETEINCLUDE \"ScanImageTiffReader\""
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


Function LoadNeuroLive()
	DFREF NTF = root:Packages:NT
	SVAR loadedPackages = NTF:loadedPackages
	If(!stringmatch(loadedPackages,"*NeuroLive*"))
	
		//LOAD - supports Vidrio's ScanImage software
		loadedPackages += "NeuroLive;"
		
		//Load procedures
		Execute/P/Q/Z "INSERTINCLUDE \"NeuroLive\""
		Execute/P/Q/Z "COMPILEPROCEDURES "
		
		//Load the controls, etc.
		//Executes command string to avoid compilation prior to loading the package.
		Execute/Q/P "Load_NeuroLive()"
	Else
		//UNLOAD
		loadedPackages = RemoveFromList("NeuroLive;",loadedPackages,";")
		
		Execute/P/Q/Z "DELETEINCLUDE \"NeuroLive\""
		Execute/P/Q/Z "COMPILEPROCEDURES "
		
		KillWindow/Z NL
		
		//return to a main menu function
		SVAR selectedCmd = NTF:selectedCmd
		switchCommandMenu("Measure")
		SwitchControls("Measure",selectedCmd)
		switchHelpMessage("Measure")
	EndIf
	
End


//Contextual menu for the wave list selector in the parameters panel
Menu "WaveListSelectorMenu",contextualMenu,dynamic
	AddSubMenu("WaveSelector"),""
End

Menu "GroupingMenu",contextualMenu
	"\\M0Concatenate (/WG=-2);\\M0Folder (/F);\\M0Position (/WG);\\M0Block (/B);\\M0Stride (/S);\\M0Wave Set Number (/WSN);\\M0Wave Set Index (/WSI);",""
End	

//Loads the Imaging functions for the NeuroTools
Menu "Macros",dynamic
	Submenu "Load Packages"
//		 LoadUnload("Imaging"),LoadImagingPackage()
		 LoadUnload("ScanImage"),LoadScanImagePackage()
		 LoadUnload("NeuroLive"),LoadNeuroLive()
	End
	
	Submenu "Shortcuts"
		"Organize Windows/1"
	End
	
End

//Add in layout tools for figure sizing to single,1.5, and double column
Menu "Layout"

	SubMenu "Figure Size Box"
        SubMenu "EJN"
	        "1 column, 8.8cm",NT_AppendFigureSizeBox(1,8.8,"UserBack")
		End
        SubMenu "JCN"
	        "1 column, 8.3cm",NT_AppendFigureSizeBox(1,8.3,"UserBack")
	        "2 column, 17.3cm",NT_AppendFigureSizeBox(1,17.3,"UserBack")
		End
        SubMenu "J. Neurosci."
	        "1 column, 8.5cm",NT_AppendFigureSizeBox(1,8.5,"UserBack")
	        "1.5 column, 11.6cm",NT_AppendFigureSizeBox(1,11.6,"UserBack")
	        "2 column, 17.6cm",NT_AppendFigureSizeBox(1,17.6,"UserBack")
		End
        SubMenu "J. Neurophys."
	        "1 column, 8.9cm",NT_AppendFigureSizeBox(1,8.9,"UserBack")
	        "2 column, 12.7cm",NT_AppendFigureSizeBox(1,12.7,"UserBack")
	        "Full width, 18cm",NT_AppendFigureSizeBox(1,18,"UserBack")
	        "Max size, 22.86cm",NT_AppendFigureSizeBox(1,22.86,"UserBack")
		End
			SubMenu "Cell Press"
				"1 column, 8.5cm",NT_AppendFigureSizeBox(1,8.5,"UserBack")
				"1.5 columns, 11.4cm",NT_AppendFigureSizeBox(1,11.4,"UserBack")
				"2 columns, 17.4cm",NT_AppendFigureSizeBox(1,17.4,"UserBack")
		End 
	End
End

//Appends a box to the User Back layer of the layout, at the selected column size
Function NT_AppendFigureSizeBox(line,size,layer)
	Variable line,size; String layer
	
	Variable left,top,right,bottom
	Variable cm_to_points = 28.35
	Variable pageMargin = 0.67 //cm
	Variable printWidth = 20.32 //cm
	Variable printHeight = 25.8 //cm
	
	left = round((pageMargin + printWidth/2 - size/2)*cm_to_points)
	top = round(pageMargin*cm_to_points)
	right = round(left + size*cm_to_points)
	bottom = round(top + printHeight*cm_to_points)
	SetDrawLayer $layer
	SetDrawEnv linethick= line,fillpat= 0
	DrawRect left,top,right,bottom
end

//Brings all NT related windows to the front and organizes them 
Function OrganizeWindows()
	//First get info about the number of monitors
	//We'll keep NT in the same monitor and arrange everything else around it
	String info = IgorInfo(0)
	Variable numScreens = str2num(StringByKey("NSCREENS",info))
	
	//NT coordinates on screen
	GetWindow NT wsize
	
	If(V_flag)
		return 0
	EndIf
	
	Make/FREE/T/N=(numScreens) screenInfo
	Variable i,screenLeft,screenTop,screenRight,screenBottom
	
	For(i=0;i<numScreens;i+=1)
		screenInfo[i] = StringByKey("SCREEN" + num2str(i+1),info,":",";")
		screenInfo[i] = StringFromList(0,StringFromList(2,screenInfo[i],"="),";") //sort of hack to get the screen coordinates
		
		screenLeft = str2num(StringFromList(0,screenInfo[i],","))
		screenTop = str2num(StringFromList(1,screenInfo[i],","))
		screenRight = str2num(StringFromList(2,screenInfo[i],","))
		screenBottom = str2num(StringFromList(3,screenInfo[i],","))
		
		//Use the monitor that the left edge of NT is on
		If(V_left > screenLeft && V_left < screenRight)
			Variable monitor = i
			break
		EndIf
		
		//didn't identify monitor, use the first monitor
		If(i == numScreens - 1)
			monitor = 0
		EndIf
	EndFor
	
	//width and height of NT
	Variable width = V_right - V_left
	Variable height = abs(V_top - V_bottom)
	
	Variable setLeft,setRight
	//set the left point of NT according to it's monitor
	setLeft = str2num(StringFromList(0,screenInfo[monitor],",")) + 460 //455 is the width of the scanimage panel
	setRight = setLeft + width
	
	//Move NT and bring to front
	DoWindow/F NT
	MoveWindow/W=NT setLeft,0,setLeft + width,height
	
	//Move scanimage image browser and bring to the front
	GetWindow/Z SI wsize
	If(!V_flag)
		width = V_right - V_left
		height = abs(V_top - V_bottom)
		
		DoWindow/F SI
		MoveWindow/W=SI setLeft-460,0,setLeft - 460 + width,height
		
		GetWindow/Z SI wsize
		
		Variable dispTop = V_bottom + 25
		Variable dispBottom = width + V_bottom
		//Move scanimage display window and bring to front
		GetWindow/Z SIDisplay wsize
		If(!V_flag)
			Variable dispHeight = width
			DoWindow/F SIDisplay
			MoveWindow/W=SIDisplay setLeft-460,dispTop,setLeft-460 + width,dispTop + abs(V_top-V_bottom)
		EndIf
	EndIf
	
End

Function/S LoadUnload(package)
	String package
	DFREF NTF = root:Packages:NT
	SVAR loadedPackages = NTF:loadedPackages
	
	If(!SVAR_EXISTS(loadedPackages))
		return ""
	EndIf

	If(!stringmatch(loadedPackages,"*" + package + "*"))
		return package
	Else
		return "Unload " + package
	EndIf
End

//Uses the selection from the Grouping menu to append the appropriate flag to the grouping SetVariable box
Function appendGroupSelection(selection)
	String selection
	String output = ""
	
	ControlInfo/W=NT waveGrouping
	strswitch(selection)
		case "Concatenate":
			output = "/WG=-2"
			break
		case "Folder":
			output = "/F="
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
		case "ScanImage":
			If(!stringmatch(loadedPackages,"*ScanImage*"))
				return ""
			EndIf
			
			index = tableMatch("ScanImage",controlListWave)
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
   Make/O/T/N=(17,4) NTF:controlAssignments 
	Wave/T controlAssignments = NTF:controlAssignments 
	
	//all of the text group titles that are in use
	Wave/T textGroups = NTF:textGroups
	Redimension/N=(3,5) textGroups
	textGroups[0][0] = "WaveSelectorTitle"
	textGroups[0][1] = "Waves:" //text entry
	textGroups[0][2] = "483" //xpos
	textGroups[0][3] = "85"  //ypos
	textGroups[0][4] = "12" //font size
	
	textGroups[1][0] = "measureTypeTitle"
	textGroups[1][1] = "Type"
	textGroups[1][2] = "475"
	textGroups[1][3] = "115"
	textGroups[1][4] = "10"
	
	textGroups[2][0] = "waveSurferTitle"
	textGroups[2][1] = "Files;"//"Sweeps;Files;"
	textGroups[2][2] = "515"//"640;515;"
	textGroups[2][3] = "112"//"112;112;"
	textGroups[2][4] = "10"//"10;10"
	
	
	
	//To change the order in the drop down menu, change the order in the controlListWave.
	controlAssignments[0][0] = "Average" //command name
	controlAssignments[0][1] = "WaveListSelector;outFolder;polarCheck;" //controls to include for this command
	controlAssignments[0][2] = "210" //this is the required width of the parameters panel. Some functions require larger areas.
	controlAssignments[0][3] = "WaveSelectorTitle;"	//these are the titles of text groups to include in the display								
	
	controlAssignments[1][0] = "Errors"
	controlAssignments[1][1] = "WaveListSelector;outFolder;errType;polarCheck;"
	controlAssignments[1][2] = "210"
	controlAssignments[1][3] = "WaveSelectorTitle;"
	
	controlAssignments[2][0] = "PSTH"
	controlAssignments[2][1] = "WaveListSelector;outFolder;histType;startTmPSTH;endTmPSTH;binSize;spkThreshold;flattenWaveCheck;"
	controlAssignments[2][2] = "210"
	controlAssignments[2][3] = "WaveSelectorTitle;"
	
	controlAssignments[3][0] = "Kill Waves"
	controlAssignments[3][1] = "WaveListSelector;"
	controlAssignments[3][2] = "210"
	controlAssignments[3][3] = "WaveSelectorTitle;"
	
	controlAssignments[4][0] = "Duplicate Rename"
	controlAssignments[4][1] = "WaveListSelector;prefixName;groupName;SeriesName;SweepName;TraceName;deleteSuffix;killOriginals;savedNames;copyToClipboard;editSaveNames;"
	controlAssignments[4][2] = "300"
	controlAssignments[4][3] = "WaveSelectorTitle;"
	
	controlAssignments[5][0] = "Move To Folder"
	controlAssignments[5][1] = "WaveListSelector;moveFolderStr;relativeFolder;"
	controlAssignments[5][2] = "300"
	controlAssignments[5][3] = "WaveSelectorTitle;"
	
	controlAssignments[6][0] = "Set Wave Note"
	controlAssignments[6][1] = "WaveListSelector;waveNote;overwriteNote;"
	controlAssignments[6][2] = "300"
	controlAssignments[6][3] = "WaveSelectorTitle;"
	
	controlAssignments[7][0] = "External Function"
	controlAssignments[7][1] = "extFuncPopUp;extFuncHelp;goToProcButton;"
	controlAssignments[7][2] = "230"
	controlAssignments[7][3] = ""
	
	controlAssignments[8][0] = "Run Cmd Line"
	controlAssignments[8][1] = "cmdLineStr;appendCommand;clearCommand;printCommand;"
	controlAssignments[8][2] = "300"
	controlAssignments[8][3] = ""
	
	controlAssignments[9][0] = "New Data Folder"
	controlAssignments[9][1] = "NDF_RelFolder;NDF_FolderName;"
	controlAssignments[9][2] = "210"
	controlAssignments[9][3] = ""
	
	controlAssignments[10][0] = "Kill Data Folder"
	controlAssignments[10][1] = "NDF_RelFolder;NDF_FolderName;"
	controlAssignments[10][2] = "210"
	controlAssignments[10][3] = ""
	
	controlAssignments[11][0] = "Measure"
	controlAssignments[11][1] = "WaveListSelector;measureType;measureStart;measureEnd;measureThreshold;angleWave;measureWidth;vectorSumReturn;sortOutput;"
	controlAssignments[11][2] = "210"
	controlAssignments[11][3] = "WaveSelectorTitle;measureTypeTitle;"
	
	controlAssignments[12][0] = "Load WaveSurfer"
	controlAssignments[12][1] = "BrowseFiles;ChannelSelector;fileListBox;stimulusData;"
	controlAssignments[12][2] = "270"
	controlAssignments[12][3] = "waveSurferTitle;"
	
	controlAssignments[13][0] = "Subtract Mean"
	controlAssignments[13][1] = "WaveListSelector;"
	controlAssignments[13][2] = "210"
	controlAssignments[13][3] = "WaveSelectorTitle;"
	
	controlAssignments[14][0] = "Subtract Trend"
	controlAssignments[14][1] = "WaveListSelector;"
	controlAssignments[14][2] = "210"
	controlAssignments[14][3] = "WaveSelectorTitle;"
	
	controlAssignments[15][0] = "Load pClamp"
	controlAssignments[15][1] = "BrowseFiles;ChannelSelector;sweepListBox;fileListBox;"
	controlAssignments[15][2] = "270"
	controlAssignments[15][3] = ""
	
	controlAssignments[16][0] = "Load Ephys"
	controlAssignments[16][1] = "BrowseFiles;fileType;fileListBox;stimulusData;"
	controlAssignments[16][2] = "305"
	controlAssignments[16][3] = ""
	
	NVAR numMainCommands = NTF:numMainCommands
	numMainCommands = DimSize(controlAssignments,0)
End


//Creates the controls that are used by all of the built-in command functions
Function CreateControls()
	DFREF NTF = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	DFREF NTI = root:Packages:NT:Imaging
	
	SVAR DSNames = NTD:DSNames
	SVAR savedNameList = NTF:savedNameList
	savedNameList = GetSavedNameList()
	
	//COMMON CONTROLS TO ALL FUNCTIONS
	Button WaveListSelector win=NT,font=$LIGHT,pos={507,75},size={138,20},title="\\JL▼        Wave Match",fSize=12,disable=3,proc=ntButtonProc
	
	//AVERAGE
	SetVariable outFolder win=NT,pos={460,105},size={175,20},font=$LIGHT,fsize=10,title="Output Folder:",value=_STR:"",disable=1
//	CheckBox replaceSuffixCheck win=NT,pos={460,125},size={40,20},font=$LIGHT,fsize=10,title="Replace",value=1,disable=1
	CheckBox polarCheck win=NT,pos={460,125},size={40,20},font=$LIGHT,fsize=10,title="Circular",value=0,disable=1
	
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
	Button deleteSuffix win=NT,pos={464,120},size={100,20},title="Delete Suffix",disable=1,proc=ntButtonProc
	Checkbox killOriginals win=NT,pos={464,150},size={100,20},title="Kill Originals",value=0,disable=1
	Button editSaveNames win=NT,pos={464,305},size={120,20},title="Edit Saved Names",disable=1,proc=ntButtonProc
	PopUpMenu savedNames win=NT,pos={464,180},size={100,20},title="Saved Names",value=#"root:Packages:NT:savedNameList",disable=1	
	Button copyToClipboard win=NT,pos={464,220},size={100,20},title="To Clipboard",disable=1,proc=ntButtonProc
	
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

	//----------------------------------------------------
	//----------------------------------------------------
	
	//MEASURE
	Button measureType win=NT,pos={492,105},font=$LIGHT,fsize=12,size={125,20},title="\\JL▼              " + "Peak",disable=3,proc=ntButtonProc
	SetVariable measureStart win=NT,pos={490,105},bodywidth=40,font=$LIGHT,fsize=10,size={40,20},title="Start",limits={0,inf,0.1},value=_NUM:0,disable=1
	SetVariable measureEnd win=NT,pos={490,105},bodywidth=40,font=$LIGHT,fsize=10,size={40,20},title="End",limits={0,inf,0.1},value=_NUM:0,disable=1
	SetVariable measureWidth win=NT,pos={490,105},bodywidth=40,font=$LIGHT,fsize=10,size={40,20},title="Width",limits={0,inf,0.1},value=_NUM:0,disable=1
	SetVariable measureThreshold win=NT,pos={490,105},bodywidth=60,font=$LIGHT,fsize=10,size={60,20},title="Thresh.",limits={-inf,inf,5e-12},value=_NUM:50e-12,disable=1
	SetVariable angleWave win=NT,pos={530,105},bodywidth=80,font=$LIGHT,fsize=10,size={40,20},title="Angles",value=_STR:"45 * x",disable=1
	PopUpMenu vectorSumReturn win=NT,pos={530,105},bodywidth=80,font=$LIGHT,fsize=10,size={40,20},title="Return",value="Angle;Resultant;DSI;",disable=3
	PopUpMenu sortOutput win=NT,pos={530,105},bodywidth=80,font=$LIGHT,fsize=10,size={40,20},title="Sort",value="Linear;Alternating;",disable=3
	
	//Toggle the 'Sweeps:' title if WavesurferListBox is to be invisible
	String func = CurrentCommand()
	SetDrawEnv/W=NT fstyle = 0, textxjust= 0
	DrawAction/W=NT getgroup=measureTypeTitle,delete
	
	If(!cmpstr(func,"Measure"))
		SetDrawEnv/W=NT xcoord= abs,ycoord= abs, fsize=10, textrgb= (0,0,0), textxjust= 1,textyjust= 1,fname=$LIGHT,gname=measureTypeTitle,gstart
		DrawText/W=NT 475,115,"Type"
		SetDrawEnv/W=NT gstop
		
		setupMeasureControls(CurrentMeasureType())
	EndIf
	
	//----------------------------------------------------
	//----------------------------------------------------
	
	//LOAD WAVESURFER
	Button BrowseFiles win=NT,pos={464,76},font=$LIGHT,fsize=10,size={20,20},title="...",disable=1,proc=ntButtonProc
	PopupMenu ChannelSelector win=NT,pos={618,96},font=$LIGHT,fsize=10,size={50,20},title="Channel",value="Im;Vm",disable=1
	Wave/T wsSweepListWave = NTF:wsSweepListWave
	Wave/T wsFileListWave = NTF:wsFileListWave
	Wave/T wsFileSelWave = NTF:wsFileSelWave
	Wave/T wsStimulusDataListWave = NTF:wsStimulusDataListWave
	
	ListBox fileListBox win=NT,pos={460,100},font=$LIGHT,fsize=10,size={280,220},listWave=wsFileListWave,selWave=wsFileSelWave,mode=9,disable=1,proc=ntListBoxProc
	ListBox sweepListBox win=NT,pos={585,100},font=$LIGHT,fsize=10,size={120,200},listWave=wsSweepListWave,mode=0,disable=1
	ListBox stimulusData win=NT,pos={460,330},font=$LIGHT,fsize=10,size={280,170},listWave=wsStimulusDataListWave,mode=0,userColumnResize=1,disable=1
	
	//Load Ephys
	PopUpMenu fileType win=NT,pos={490,76},font=$LIGHT,fsize=10,size={50,20},title="Type",value="PClamp;WaveSurfer;Presentinator;",disable=1
End

//SETTINGS PANEL----------------------------------------------------------------------------------
Function openSettingsPanel()
	DFREF NTS = root:Packages:NT:Settings
	//Open the settings panel
	DoWindow/W=NTSettingsPanel NTSettingsPanel
	
	Variable r = ScreenResolution / 72
	
	If(!V_flag)
		GetWindow NT wsize
		NewPanel/K=1/N=NTSettingsPanel/W=(V_right*r,V_top*r,V_right*r+200,V_top*r+200) as "Settings"
		ModifyPanel/W=NTSettingsPanel fixedSize=1
	Else
		DoWindow/F/W=NTSettingsPanel NTSettingsPanel
	EndIf
	
	//Parameter Settings
	NVAR ppr = NTS:ppr
	NVAR scaleFactor = NTS:scaleFactor
	SetVariable ppr win=NTSettingsPanel,pos={10,10},size={170,20},title="Parameters Open Speed",value=ppr,limits={20,inf,10},proc=NTSettings_SetVarProc
//	SetVariable scaleFactor win=NTSettingsPanel,pos={62,30},size={98,20},title="Scale Factor",value=scaleFactor,limits={0.1,inf,0.05},proc=NTSettings_SetVarProc
//	Button scaleFactorUpdate win=NTSettingsPanel,pos={162,26},size={20,20},title="∆",proc=ntButtonProc
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

//Migrates your settings from Analysis Tools to NeuroTools folder/file structures
Function NT_Migrate()
	//Find the DataSets folder in AT
	DFREF ATD = root:Packages:analysisTools:DataSets
	
	//NT DataSets folder
	DFREF NTD = root:Packages:NT:DataSets
	
	If(!DataFolderRefStatus(ATD))
		Abort "Couldn't find the DataSets folder in AT"
	EndIf
	
	If(!DataFolderRefStatus(NTD))
		Abort "Couldn't find the DataSets folder in NT. Load NT before migrating."
	EndIf
	
	Variable numWaves = CountObjectsDFR(ATD,1)
	
	//AT data sets
	Wave/T dataSetNames = ATD:dataSetNames
	Variable i,j,numDataSets = DimSize(dataSetNames,0)
	
	//Migrate the data sets
	For(i=0;i<numDataSets;i+=1)
		Wave/T AT_ORG = ATD:$("DS_" + dataSetNames[i]) //full path, ORG
		Wave/T AT_BASE = ATD:$("ogDS_" + dataSetNames[i]) //full path, BASE
		
		//Make the new NT data sets
		Variable ORGsize = DimSize(AT_ORG,0)
		Make/T/O/N=(ORGsize,1,2) NTD:$("DS_" + dataSetNames[i] + "_org") /Wave = NT_ORG //NT data set, ORG
		
		Variable BASEsize = DimSize(AT_BASE,0)
		Make/T/O/N=(BASEsize,1,2) NTD:$("DS_" + dataSetNames[i]) /Wave = NT_BASE//NT data set, BASE
		
		
		//Migrate the filters
		Wave/T dsFilters = ATD:dsFilters		
		Wave/T dsSelection = ATD:dsSelection
		Wave/T DSNamesLB_ListWave = NTD:DSNamesLB_ListWave
		Wave DataSetLB_SelWave = NTD:DataSetLB_SelWave
		
		Redimension/N=(numDataSets,1,3) DSNamesLB_ListWave
		Redimension/N=(numDataSets) DataSetLB_SelWave
		DSNamesLB_ListWave[i][0][0] = dataSetNames[i] //names
		DSNamesLB_ListWave[i][0][1] = dsFilters + ";;;;;;" //filters
		
		String filter = DSNamesLB_ListWave[i][0][1]
		String item = StringFromList(3,filter,";") //grouping needs to be moved
		
		DSNamesLB_ListWave[i][0][1] = RemoveListItem(3,filter,";")
		DSNamesLB_ListWave[i][0][1] = AddListItem(item,DSNamesLB_ListWave[i][0][1],";",8)
		
		If(WaveExists(dsSelection))
			String selectionStr = dsSelection[i][2]
			For(j=0;j<ItemsInList(selectionStr,";");j+=1)
				String subFolder = StringFromList(j,selectionStr,";")
				selectionStr = ReplaceListItem(j,selectionStr,";",dsSelection[i][1] + subFolder)
			EndFor
		Else
			selectionStr = ""
		EndIf	
			
		DSNamesLB_ListWave[i][0][2]	 =  selectionStr//folder selection
		
		//Migrate the data set waves
		If(BASEsize == 0)
			continue
		EndIf
		
		NT_BASE[][0][0] = ParseFilePath(0,AT_BASE[p][0][0],":",1,0) //wave name only
		NT_BASE[][0][1] = AT_BASE[p][0][0] //full path
		
		If(ORGsize == 0)
			continue
		EndIf
	
		For(j=0;j<ORGsize;j+=1)
			If(stringmatch(AT_ORG[j],"*WSN*"))
				String wsn = StringByKey("WSN",AT_ORG[j]," ","-")
				NT_ORG[j][0][] = "----WAVE SET " + wsn + "----"
			Else
				NT_ORG[j][0][0] = ParseFilePath(0,AT_ORG[j][0],":",1,0) //wave name only
				NT_ORG[j][0][1] = AT_ORG[j][0] //full path
			EndIf
		EndFor

	EndFor

End

