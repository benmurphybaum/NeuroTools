#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#include "NT_ImageRegistration"

//Package for analyzing images acquired using ScanImage.
//General imaging analysis routine
//BigTiff loading and header reading

//Create the controls for the ScanImage package
Function SI_CreatePackage()
	
	//Make the ScanImage package folder
	If(!DataFolderExists("root:Packages:NT:ScanImage"))
		NewDataFolder root:Packages:NT:ScanImage
	EndIf
	
	//Make the ScanImage Scans folder
	If(!DataFolderExists("root:Scans"))
		NewDataFolder root:Scans
	EndIf
	
	DFREF NTSI = root:Packages:NT:ScanImage
	
	//Are we creating scanimage file structures or 2PLSM?
	String/G NTSI:imagingSoftware
	SVAR software = NTSI:imagingSoftware
	software = whichImagingSoftware()
	
	//Housekeeping strings and variables
	Variable/G NTSI:numImages
	NVAR numImages = NTSI:numImages
	numImages = 0
	
	//reports which layer is being shown in the display panel
	Variable/G NTSI:imagePlane
	NVAR imagePlane = NTSI:imagePlane
	imagePlane = 0
	
	//switch for if we're playing frames in the image or not
	Variable/G NTSI:isPlaying
	NVAR isPlaying = NTSI:isPlaying
	isPlaying = 0
	
	//switch for whether a max projection is being shown or not
	Variable/G NTSI:isMaxProj
	NVAR isMaxProj = NTSI:isMaxProj
	isMaxProj = 0
	
	//number of ticks between background function calls
	Variable/G NTSI:numTicks
	NVAR numTicks =NTSI:numTicks
	numTicks = 1
	
	//number of frames to jump between for each tick refresh when playing frames
	Variable/G NTSI:deltaPlane
	NVAR deltaPlane = NTSI:deltaPlane
	deltaPlane = 1
	
	//rolling average view in the display panel 
	Variable/G NTSI:rollingAverage
	NVAR rollingAverage = NTSI:rollingAverage
	rollingAverage = 1
	
	//Diameter of the dynamic ROI integration area
	Variable/G NTSI:dynamicROI_Size
	NVAR dynamicROI_Size = NTSI:dynamicROI_Size
	dynamicROI_Size = 10
	
	//Is the dynamic ROI scaling auto or cumulative?
	Variable/G NTSI:scaleCumulative
	NVAR scaleCumulative = NTSI:scaleCumulative
	scaleCumulative = 0
	
	//keeps track of the number of frames that have gone into the average
	Variable/G NTSI:rollingAverageCount
	NVAR rollingAverageCount = NTSI:rollingAverageCount
	rollingAverageCount = 0
	
	//list and selection waves for the ROI list box
	//second layer will record the ROI Group assigned to each ROI...
	//...which is only defined by the folder the ROI lives in
	Make/O/T/N=(0,1,2) NTSI:ROIListWave /Wave = ROIListWave
	Make/O/N=0 NTSI:ROISelWave /Wave = ROISelWave
	
	//list and selection waves for the ROI Group list box
	Make/O/T/N=0 NTSI:ROIGroupListWave /Wave = ROIGroupListWave
	Make/O/N=0 NTSI:ROIGroupSelWave /Wave = ROIGroupSelWave
	
	//ROI groups, select first group
	Wave/T listWave = SI_GetROIGroups()
	Redimension/N=(DimSize(listWave,0)) ROIGroupListWave,ROIGroupSelWave
	ROIGroupListWave = listWave
	If(DimSize(ROIGroupSelWave,0) > 0)
		ROIGroupSelWave = 0
		ROIGroupSelWave[0] = 1
		String group = ROIGroupListWave[0]
	Else
		group = ""
	EndIf
	
	Variable/G NTSI:ROI_Engaged
	NVAR ROI_Engaged = NTSI:ROI_Engaged
	ROI_Engaged = 0
	
	Variable/G NTSI:ROI_Width
	NVAR ROI_Width = NTSI:ROI_Width
	ROI_Width = 15
	Variable/G NTSI:ROI_Height
	NVAR ROI_Height = NTSI:ROI_Height
	ROI_Height = 15
	
	//ROIs within the selected group
	Wave/T listWave = SI_GetROIs(group)
	Redimension/N=(DimSize(listWave,0),-1,-1) ROIListWave,ROISelWave
	ROIListWave = listWave
	
	//Records double click events
	Variable/G NTSI:doubleClick
	NVAR doubleClick = NTSI:doubleClick
	doubleClick = 0
	
	//Saves the name of an edited ROI Group temporarily
	String/G NTSI:oldROIGroupName
	SVAR oldROIGroupName = NTSI:oldROIGroupName
	oldROIGroupName = ""
	
	//list and selection waves for loading SI files
	Make/O/T/N=(0) NTSI:ScanLoadListWave /Wave = ScanLoadListWave
	Make/O/N=(0) NTSI:ScanLoadSelWave /Wave = ScanLoadSelWave
	
	String/G NTSI:ScanLoadPath
	SVAR ScanLoadPath = NTSI:ScanLoadPath
	ScanLoadPath = ""
	
	String/G NTSI:measure
	
	//Outer folder - Scan File, which may contain multiple scans of ROIs and Zs
		//Selection shows the Scan ROIs within that scan group. Z level will be shown as text somewhere else.
	
	//The scan folder - this is the parent folder for a set of groups, and is the subfolder that the group of tiff files are actually kept in.
	//Mine are typically the experiment date (i.e. R4_200326), so multiple days of experiments can be organized in a single Igor pxp.
	Make/O/T/N=(0,1,3) NTSI:ScanFolderListWave /Wave = ScanFolderListWave
	Make/O/N=(0) NTSI:ScanFolderSelWave /Wave = ScanFolderSelWave

	//The scan group
	Make/O/T/N=(0,1,3) NTSI:ScanGroupListWave /Wave = ScanGroupListWave
	Make/O/N=(0) NTSI:ScanGroupSelWave /Wave = ScanGroupSelWave
	
	//The scans themselves
	Make/O/T/N=(0,1,3) NTSI:ScanFieldListWave /Wave = ScanFieldListWave
	Make/O/N=(0) NTSI:ScanFieldSelWave /Wave = ScanFieldSelWave
	
	//Get the scan group list wave
	Wave/T listWave = SI_GetScanFolders()
	Redimension/N=(DimSize(listWave,0),-1,-1) ScanFolderListWave,ScanFolderSelWave
	
	//If this is 2PLSM, need to make it so the scan folders are the scan groups
	If(!cmpstr(software,"2PLSM"))
		Redimension/N=(DimSize(ScanFolderListWave,0),-1,-1) ScanGroupListWave,ScanGroupSelWave
		ScanGroupListWave[][0][0] = ScanFolderListWave
		
		If(DimSize(ScanFolderSelWave,0) > 0)
			ScanGroupSelWave = ScanFolderSelWave
		EndIf
		
		Redimension/N=(1,-1,-1) ScanFolderListWave,ScanFolderSelWave
		ScanFolderListWave[0] = "2PLSM"
		ScanFolderSelWave[0] = 1 
	Else
		ScanFolderListWave = listWave
	EndIf
	
	If(DimSize(ScanFolderListWave,0) > 0)
		Wave/T listWave = SI_GetScanGroups(folder=ScanFolderListWave[0][0][0])
		Redimension/N=(DimSize(listWave,0),-1,-1) ScanGroupListWave,ScanGroupSelWave
		ScanGroupListWave = listWave
	EndIf
	
	//initialize to the first scan folder
	If(DimSize(ScanGroupListWave,0) > 0)
		ScanGroupSelWave[0][0][0] = 1
		Wave/T listWave = SI_GetScanFields(ScanFolderListWave[0][0][0],group=ScanGroupListWave[0][0][0])
	EndIf
	
	If(DimSize(ScanFieldListWave,0) > 0)
		ScanFieldSelWave[0][0][0] = 1
	EndIf
	
	
	//Scan Field match string
	String/G NTSI:scanFieldMatchStr
	SVAR scanFieldMatchStr = NTSI:scanFieldMatchStr
	scanFieldMatchStr = ""
	
	//Create the ScanImage Browsing panel
	KillWindow/Z SI
	
	GetWindow NT wsize
	
	NewPanel/N=SI/K=2/W=(V_left-460,V_top,V_left,V_top + 245) as "Image Browser"
	
	ListBox scanFolders win=SI,pos={5,40},size={85,200},title="",listWave=ScanFolderListWave,selWave=ScanFolderSelWave,mode=2,proc=siListBoxProc,disable=0
	ListBox scanGroups win=SI,pos={95,40},size={85,200},title="",listWave=ScanGroupListWave,selWave=ScanGroupSelWave,mode=9,proc=siListBoxProc,disable=0
	ListBox scanFields win=SI,pos={185,40},size={140,180},title="",listWave=ScanFieldListWave,selWave=ScanFieldSelWave,mode=9,proc=siListBoxProc,disable=0
	ListBox roiGroups win=SI,pos={330,40},size={60,180},title="",listWave=ROIGroupListWave,selWave=ROIGroupSelWave,mode=9,proc=siListBoxProc,disable=0
	ListBox rois win=SI,pos={395,40},size={60,180},title="",listWave=ROIListWave,selWave=ROISelWave,mode=9,proc=siListBoxProc,disable=0
	SetVariable scanFieldMatch win=SI,pos={185,226},size={140,20},title=" ",value=scanFieldMatchStr,proc=siVarProc,disable=0
	
	CheckBox selectAllScanFields win=SI,pos={204,23},size={20,20},title="",value=0,proc=siCheckBoxProc,disable=0
	CheckBox selectAllScanGroups win=SI,pos={88,23},size={20,20},title="",value=0,proc=siCheckBoxProc,disable=0
	
	PopUpMenu targetImage win=SI,pos={330,224},size={120,20},bodywidth=120,font=$LIGHT,title="",mode=1,value=#"root:Packages:NT:ScanImage:availableImages",proc=siPopProc
//	Button appendToTop win=SI,pos={395,223},size={60,20},title="Append",disable=0,proc=siButtonProc
	
	
	SetDrawEnv/W=SI fname=$LIGHT,fsize=12,xcoord=abs,ycoord=abs
	DrawText/W=SI 34,39,"Cells"
	SetDrawEnv/W=SI fname=$LIGHT,fsize=12,xcoord=abs,ycoord=abs
	DrawText/W=SI 102,39,"Scan Groups"
	SetDrawEnv/W=SI fname=$LIGHT,fsize=12,xcoord=abs,ycoord=abs
	DrawText/W=SI 218,39,"Scans Fields"
	SetDrawEnv/W=SI fname=$LIGHT,fsize=12,xcoord=abs,ycoord=abs
	DrawText/W=SI 353,39,"ROI Groupings"
	
	Button displayScanField win=SI,pos={4,1},size={60,20},title="Display",font=$LIGHT,proc=siButtonProc,disable=0
	Button updateImageBrowser win=SI,pos={70,1},size={70,20},title="Refresh",font=$LIGHT,proc=siButtonProc,disable=0 
	
	SI_CreateControls()
	SI_CreateControlLists()
	
	//Scan Registration variables, etc.
	If(!DataFolderExists("root:Packages:NT:ScanImage:Registration"))
		NewDataFolder root:Packages:NT:ScanImage:Registration
	EndIf
	DFREF NTSR = root:Packages:NT:ScanImage:Registration
	String/G NTSR:roiXlist
	String/G NTSR:roiYlist
	Variable/G NTSR:hidden
	
	//set resize hook on the Image Browser for vertical sizing only
	SetWindow SI hook(resizeHook) = resizeHook
	
End

//Creates the controls that are used in scanimage analysis functions
Function SI_CreateControls()
	Variable pos = 100
	
	DFREF NTSI = root:Packages:NT:ScanImage
	//Get ROI
	PopUpMenu channelSelect win=NT,size={120,20},bodywidth=50,pos={461,pos},title="Channel",value="1;2;1/2;2/1;",disable=1	
	pos += 23
	PopUpMenu dFSelect win=NT,size={120,20},bodywidth=50,pos={461,pos},title="Mode",value="∆F/F;SD;Abs;",disable=1
	pos += 23
	SetVariable baselineSt win=NT,size={120,20},bodywidth=40,pos={461,pos},limits={0,inf,0.1},title="Baseline Start (s)",value=_NUM:0,disable=1
	pos += 20
	SetVariable baselineEnd win=NT,size={120,20},bodywidth=40,pos={461,pos},limits={0,inf,0.1},title="Baseline End (s)",value=_NUM:0,disable=1
	pos += 20
	SetVariable peakSt win=NT,size={120,20},bodywidth=40,pos={461,pos},limits={0,inf,0.1},title="Peak Start (s)",value=_NUM:0,disable=1
	pos += 20
	SetVariable peakEnd win=NT,size={120,20},bodywidth=40,pos={461,pos},limits={0,inf,0.1},title="Peak End (s)",value=_NUM:0,disable=1
	pos += 30
//	PopUpMenu filterType win=NT,size={120,20},pos={491,pos},bodywidth=120,value="None;Savitsky-Golay",title="Filter Type",disable=1
//	pos += 20
	SetVariable filterSize win=NT,size={120,20},bodywidth=40,pos={461,pos},limits={-1,inf,2},title="Filter Size",value=_NUM:9,disable=1,proc=siVarProc
	pos += 20	
	
	//Load Scans
	Button BrowseScans win=NT,pos={460,80},font=$LIGHT,fsize=10,size={50,20},title="Browse",disable=1,proc=siButtonProc
	PopupMenu LoadChannel win=NT,pos={535,82},font=$LIGHT,fsize=10,size={50,20},title="Channel",value="1;2;Both;",disable=1
	Wave/T ScanLoadListWave = NTSI:ScanLoadListWave
	Wave ScanLoadSelWave = NTSI:ScanLoadSelWave
	ListBox scanLoadListbox win=NT,pos={460,120},font=$LIGHT,fsize=10,size={225,350},listWave=ScanLoadListWave,selWave=ScanLoadSelWave,mode=9,disable=1,proc=siListBoxProc
	Checkbox selectAllScans win=NT,pos={460,102},font=$LIGHT,fsize=10,size={75,20},title="Select All",disable=1,proc=siCheckBoxProc

	//Population Vector Sum
//	SVAR DSNameList = root:Packages:NT:DataSets:DSNameList
	PopUpMenu Signals win=NT,pos={510,80},size={120,20},bodywidth=120,title="Signals",value=#"root:Packages:NT:DataSets:DSNames",disable=1
	PopUpMenu TuningCurves win=NT,pos={510,100},size={120,20},bodywidth=120,title="Tuning",value=#"root:Packages:NT:DataSets:DSNames",disable=1
	PopUpMenu PrefAngles win=NT,pos={510,120},size={120,20},bodywidth=120,title="Pref. Angle",value=#"root:Packages:NT:DataSets:DSNames",disable=1
	PopUpMenu	 VectorRadii win=NT,pos={510,140},size={120,20},bodywidth=120,title="Vector Radii",value=#"root:Packages:NT:DataSets:DSNames",disable=1
	Checkbox differentiateCheck win=NT,pos={510,160},font=$LIGHT,fsize=10,size={75,20},title="Differentiate",disable=1,proc=siCheckBoxProc

	//Adjust Galvo Distortion
	Slider SR_phase win=NT,live=1,pos={50+426,93+25},size={150,20},value=50,limits={0,360,1},title="Phase",vert=0,proc=NT_ScanRegistrySliderProc,disable=1
	CheckBox SR_phaseLock win=NT,pos={34+426,91+25},title="",value=0,disable=1
	SetVariable SR_phaseVal win=NT,pos={210+426,93+25},size={40,20},title=" ",live=1,frame=0,value=_NUM:NT_GetSliderValue(),disable=1
	CheckBox SR_pixelDeltaLock win=NT,pos={34+426,140+25},title="",value=0,disable=1
	SetVariable SR_pixelDelta win=NT,pos={50+426,142+25},size={60,20},limits={-inf,inf,0.5},title="Pixels",value=_NUM:10,proc=NT_ScanRegistryVarProc,disable=1
	CheckBox SR_divergenceLock win=NT,pos={34+426,163+25},title="",value=1,disable=1
	SetVariable SR_divergence win=NT,pos={50+426,165+25},size={90,20},limits={-1,1,2},title="Divergence",value=_NUM:1,proc=NT_ScanRegistryVarProc,disable=1
	CheckBox SR_frequencyLock win=NT,pos={34+426,186+25},title="",value=0,disable=1
	SetVariable SR_frequency win=NT,pos={50+426,188+25},size={90,20},limits={0,inf,0.01},title="Frequency",value=_NUM:0.6,proc=NT_ScanRegistryVarProc,disable=1
	CheckBox SR_pixelOffsetLock win=NT,pos={34+426,210+25},title="",value=0,disable=1
	SetVariable SR_pixelOffset win=NT,pos={50+426,212+25},size={90,20},limits={-inf,inf,1},title="Offset",value=_NUM:-8,proc=NT_ScanRegistryVarProc,disable=1
	Button SR_autoRegisterButton win=NT,pos={145+426,193+25},size={60,20},title="Auto",proc=NT_ScanRegistryButtonProc,disable=1
	Button SR_addROIButton win=NT,pos={204+426,300+25},size={20,20},title="+",fColor=(3,52428,1),disable=1,proc=NT_ScanRegistryButtonProc,disable=1
	Button SR_reset win=NT,pos={145+426,173+25},size={60,20},title="Reset",proc=NT_ScanRegistryButtonProc,disable=1
	Button SR_showROIButton win=NT,pos={145+426,153+25},size={60,20},title="ROIs",proc=NT_ScanRegistryButtonProc,disable=1
	//Button SR_quitButton win=NT,pos={145,60},size={60,20},title="Quit", fColor=(65535,0,0),proc=ScanRegistryButtonProc
	Button SR_saveTemplateButton win=NT,pos={145+426,213+25},size={60,20},title="Save",proc=NT_ScanRegistryButtonProc,disable=1
	Button SR_applyTemplate win=NT,pos={176+426,237+25},size={50,20},title="Apply",proc=NT_ScanRegistryButtonProc,disable=1
	
	If(!DataFolderExists("root:Packages:NT:ScanImage:Registration"))
		NewDataFolder root:Packages:NT:ScanImage:Registration
	EndIf
	String/G root:Packages:NT:ScanImage:Registration:templateList
	SVAR templateList = root:Packages:NT:ScanImage:Registration:templateList
	templateList = GetTemplateList()
	PopUpMenu SR_templatePopUp win=NT,pos={34+426,238+25},size={100,20},title="Templates",value=#"root:Packages:NT:ScanImage:Registration:templateList",proc=NT_ScanRegistryPopUpProc,disable=1
//	CheckBox SR_UseAnalysisToolsCheck win=NT,pos={34+426,258},size={40,20},title="Use Scan List",disable=1
End



//Assigns control variables to functions from the 'Command' pop up menu
Function SI_CreateControlLists()
	DFREF NTF = root:Packages:NT
	Wave/T controlAssignments = NTF:controlAssignments 
	NVAR numMainCommands = NTF:numMainCommands
	
	//Resize for the Imaging package commands
	Redimension/N=(numMainCommands + 8,4) controlAssignments
	
	//SCANIMAGE PACKAGE
	controlAssignments[numMainCommands][0] = "Load Scans" //command name
	controlAssignments[numMainCommands][1] = "LoadChannel;BrowseScans;scanLoadListbox;selectAllScans;"//controls to include for this command
	controlAssignments[numMainCommands][2] = "250"//this is the required width of the parameters panel. Some functions require larger areas.
	controlAssignments[numMainCommands][3] = ""//these are the titles of text groups to include in the display			
	
	controlAssignments[numMainCommands+1][0] = "Get ROI"
	controlAssignments[numMainCommands+1][1] = "WaveListSelector;baselineSt;baselineEnd;peakSt;peakEnd;filterSize;channelSelect;dFSelect;"
	controlAssignments[numMainCommands+1][2] = "250"
	controlAssignments[numMainCommands+1][3] = "WaveSelectorTitle;"
	
	controlAssignments[numMainCommands+2][0] = "dF Map"
	controlAssignments[numMainCommands+2][1] = "WaveListSelector;baselineSt;baselineEnd;peakSt;peakEnd;filterSize;channelSelect;dFSelect;"
	controlAssignments[numMainCommands+2][2] = "250"
	controlAssignments[numMainCommands+2][3] = "WaveSelectorTitle;"
	
	controlAssignments[numMainCommands+3][0] = "Max Project"
	controlAssignments[numMainCommands+3][1] = "WaveListSelector;"
	controlAssignments[numMainCommands+3][2] = "210"
	controlAssignments[numMainCommands+3][3] = "WaveSelectorTitle;"
	
	controlAssignments[numMainCommands+4][0] = "Vector Sum Map"
	controlAssignments[numMainCommands+4][1] = "WaveListSelector;angleWave;vectorSumReturn;"
	controlAssignments[numMainCommands+4][2] = "210"
	controlAssignments[numMainCommands+4][3] = "WaveSelectorTitle;"
	
	controlAssignments[numMainCommands+5][0] = "Population Vector Sum"
	controlAssignments[numMainCommands+5][1] = "Signals;PrefAngles;VectorRadii;TuningCurves;differentiateCheck;"
	controlAssignments[numMainCommands+5][2] = "210"
	controlAssignments[numMainCommands+5][3] = ""
	
	controlAssignments[numMainCommands+6][0] = "Response Quality"
	controlAssignments[numMainCommands+6][1] = "WaveListSelector;baselineSt;baselineEnd;peakSt;peakEnd;"
	controlAssignments[numMainCommands+6][2] = "210"
	controlAssignments[numMainCommands+6][3] = "WaveSelectorTitle"
	
	controlAssignments[numMainCommands+7][0] = "Adjust Galvo Distortion"
	controlAssignments[numMainCommands+7][1] = "WaveListSelector;SR_phase;SR_phaseLock;SR_phaseVal;SR_pixelDeltaLock;SR_pixelDelta;SR_divergenceLock;SR_divergence;SR_frequencyLock;SR_frequency;SR_pixelOffsetLock;"
	controlAssignments[numMainCommands+7][1] += "SR_pixelOffset;SR_autoRegisterButton;SR_reset;SR_showROIButton;SR_saveTemplateButton;SR_applyTemplate;SR_templatePopUp;"
	controlAssignments[numMainCommands+7][2] = "250"
	controlAssignments[numMainCommands+7][3] = "WaveSelectorTitle"
	
	
End

//Returns a text wave with all available scan folders (immediate subfolders within the root:Scans: directory)
Function/Wave SI_GetScanFolders()
	DFREF NTSI = root:Packages:NT:ScanImage
	SVAR software = NTSI:imagingSoftware
	
	strswitch(software)
		case "2PLSM":
			DFREF NTS = root:twoP_Scans
			break
		case "ScanImage":
			DFREF NTS = root:Scans
			break
	endswitch
	
	String folders = StringByKey("FOLDERS",DataFolderDir(1,NTS),":",";")
	Wave/T listWave = StringListToTextWave(folders,",")
	
	Sort listWave,listWave
	
	return listWave
End

//Returns a text wave with all available scan groups within the selected or indicated scan folder
Function/Wave SI_GetScanGroups([folder])
	String folder
	
	DFREF NTSI = root:Packages:NT:ScanImage
	Wave/T ScanFolderListWave = NTSI:ScanFolderListWave
	
	DFREF saveDF = GetDataFolderDFR()
	
	If(ParamIsDefault(folder))
		folder = TextWaveToStringList(ScanFolderListWave,";")
	EndIf
	
	If(!strlen(folder))
		return $""
	EndIf
	
	strswitch(folder)
		case "2PLSM":
			DFREF NTS = $("root:twoP_Scans:")
			break
		default:
			DFREF NTS =  $("root:Scans:" + folder)
			break
	endswitch
		
	String folders = StringByKey("FOLDERS",DataFolderDir(1,NTS),":",";")
	
	Variable i
	
	For(i=ItemsInList(folders,",")-1;i>-1;i-=1) //go backwards
		SetDataFolder NTS:$StringFromList(i,folders,",")
		String scanList = WaveList("*",";","DIMS:3")
		If(ItemsInList(scanList,";") == 0)
			folders = RemoveListItem(i,folders,",")
		EndIf
	EndFor
	
	Wave/T listWave = StringListToTextWave(folders,",")
	
	Sort listWave,listWave
	
	SetDataFolder saveDF
	return listWave
End

//Returns a text wave with all available scans that are within each scan group
Function/Wave SI_GetScanFields(folder[,group])
	String folder,group 
	
	DFREF saveDF = $GetDataFolder(1)
	DFREF NTSI = root:Packages:NT:ScanImage
	Wave/T ScanGroupListWave = NTSI:ScanGroupListWave
	
	Wave/T ScanFieldListWave = NTSI:ScanFieldListWave
	Wave ScanFieldSelWave = NTSI:ScanFieldSelWave
	
	If(ParamIsDefault(group))
		group = TextWaveToStringList(ScanGroupListWave,";")
	EndIf
	
	If(!strlen(group))
		Make/FREE/N=0/T listWave
		return listWave
	EndIf
		
	strswitch(folder)
		case "2PLSM":
			String baseFolder = "root:twoP_Scans"
			folder = ""
			break
		default:
			baseFolder = "root:Scans:"
			break
	endswitch
	
	Variable i,j
	String list = ""
	String fullList = ""
	String path = ""
	For(i=0;i<ItemsInList(group,";");i+=1)
		String groupPath = baseFolder + folder + ":" + StringFromList(i,group,";")

		If(!DataFolderExists(groupPath))
			Abort "Scan group '" + group + "' does not exist"
		EndIf
		
		SetDataFolder $groupPath
		
		//Get all 3D waves 
		list = WaveList("*",";","DIMS:3")//takes care of extra-semicolon on the end
		fullList += list
		
		//Adds the path of the group to a separate list to combine later
		For(j=0;j<ItemsInList(list,";");j+=1)
			path += groupPath + ";"
		EndFor
		
	EndFor
	
	SetDataFolder saveDF
	
	//Add the full path to the scans in the second layer of the scan field list wave
	Wave/T listWave = StringListToTextWave(fullList,";")
	Wave/T pathWave = StringListToTextWave(path,";")
	
	Redimension/N=(DimSize(listWave,0),-1,-1) ScanFieldListWave,ScanFieldSelWave
	
	ScanFieldListWave[][][0] = listWave
	ScanFieldListWave[][][1] = pathWave[p] + ":" + listWave[p]
	return listWave
End

//Finds all the available ROIs, and returns a listwave of them
Function/Wave SI_GetROIs(group)
	String group //this can be a list of groups
	
	DFREF NTSI = root:Packages:NT:ScanImage
	
	DFREF saveDF = GetDataFolderDFR()
	
	SVAR software = NTSI:imagingSoftware
	
	strswitch(software)
		case "2PLSM":
			String roiFolder = "root:twoP_ROIS:"
			break
		case "ScanImage":
			roiFolder = "root:Packages:NT:ScanImage:ROIs:"
			
			//No group, return empty
			If(!strlen(group))
				Make/FREE/N=(0,1,2)/T listWave
				return listWave
			EndIf
			
			break
	endswitch
	
	String roiList = ""
	String groupList = ""
	
	//LOOP THROUGH ROI GROUPS
	Variable i,j,numGroups = ItemsInList(group,";")
	
	For(j=0;j<numGroups;j+=1)
		String currentGroup = StringFromList(j,group,";")
		DFREF NTR = $(roiFolder + currentGroup)
		
		//Invalid ROI group or no ROIs defined, return empty
		If(!DataFolderRefStatus(NTR))
			Make/N=(0,1,2)/T/FREE listWave
			return listWave
		EndIf

		SetDataFolder NTR
	
		String roiX = WaveList("*_x",";","MINROWS:5")
		String roiY = WaveList("*_y",";","MINROWS:5")
		String somaROIs = WaveList("*_soma",";","")
		
		Wave/T roiData = validROILists(roiList,groupList,currentGroup,roiX,roiY,somaROIs)
		roiList = roiData[0]
		groupList = roiData[1]
	EndFor
	
	//no group, take ROIs from the base folder
	If(!strlen(group))
		DFREF NTR = $roiFolder
		
		SetDataFolder NTR
	
		roiX = WaveList("*_x",";","MINROWS:5")
		roiY = WaveList("*_y",";","MINROWS:5")
		somaROIs = WaveList("*_soma",";","")
		
		Wave/T roiData = validROILists(roiList,groupList,"",roiX,roiY,somaROIs)
		roiList = roiData[0]
		groupList = roiData[1]
	EndIf
	
	
	Wave/T listWave = StringListToTextWave(roiList,";")
	Make/FREE/N=(DimSize(listWave,0),1,2)/T returnList
	If(strlen(roiList))
		returnList[][0][0] = listWave[p][0][0]
	
		Wave/T listWave = StringListToTextWave(groupList,";")
		Redimension/N=(DimSize(returnList,0)) listWave //ensures same dimensions in case group is empty
		returnList[][0][1] = listWave[p][0][0]
	EndIf
		
	SetDataFolder saveDF
	
	return returnList
End

Function/WAVE validROILists(roiList,groupList,currentGroup,roiX,roiY,somaROIs)
	String roiList,groupList,currentGroup,roiX,roiY,somaROIs
	Variable i
	
	//LOOP THROUGH ROIs
	String currentROIList = ""
	For(i=0;i<ItemsInList(roiX,";");i+=1)
		String roi = StringFromList(i,roiX,";")
		String compROI = "*" + ReplaceListItem(ItemsInList(roi,"_")-1,roi,"_","y") + "*" 
		
		//if there was no y coordinate wave
		If(stringmatch(roiY,compROI))
			currentROIList += RemoveEnding(ParseFilePath(1,roi,"_",1,0),"_") + ";"
			groupList += currentGroup + ";"
		EndIf
	EndFor
	
	//Sort the list for each ROI group individually
	currentROIList = SortList(currentROIList,";",16)
	roiList += currentROIList
	
	//append group assignments to the somatic ROI list
	For(i=0;i<ItemsInList(somaROIs,";");i+=1)
		groupList += currentGroup + ";"
	EndFor
	roiList += somaROIs
	
	Make/FREE/T/N=2 roiData
	roiData[0] = roiList
	roiData[1] = groupList
	
	return roiData
End

//Finds all of the existing ROI groups and returns a listwave of them
Function/Wave SI_GetROIGroups()
	DFREF NTSI = root:Packages:NT:ScanImage
	
	String/G NTSI:imagingSoftware
	SVAR software = NTSI:imagingSoftware
	software = whichImagingSoftware()
	
	strswitch(software)
		case "2PLSM":
			DFREF NTR = root:twoP_ROIS
			break
		case "ScanImage":
			DFREF NTR = root:Packages:NT:ScanImage:ROIs
			break
	endswitch
	
	String groups = ""	
	
	//No ROIs defined, return
	If(!DataFolderRefStatus(NTR))
		Make/N=0/T/FREE listWave
		return listWave
	EndIf
	
	DFREF saveDF = GetDataFolderDFR()
	SetDataFolder NTR
	
	//Get the names of the ROI groups
	Variable i,numGroups =	CountObjectsDFR(NTR,4)
	For(i=0;i<numGroups;i+=1)
		groups += GetIndexedObjNameDFR(NTR,4,i) + ";"
	EndFor
	
	//Convert to a alphanumerically sorted list wave
	Wave/T listWave = StringListToTextWave(groups,";")
	Sort/A listWave,listWave
	
	return listWave
End 

//Returns the full paths of the selected scan fields
Function/S GetSelectedImages()
	DFREF NTSI = root:Packages:NT:ScanImage
	Wave/T listWave = NTSI:ScanFieldListWave
	Wave selWave = NTSI:ScanFieldSelWave
	
	Variable i
	String imageList = ""
	For(i=0;i<DimSize(selWave,0);i+=1)
		If(selWave[i] > 0)
			imageList += listWave[i][0][1] + ";"
		EndIf
	EndFor
	return imageList
End
	
//Opens the scanfield display and displays the selected image stack
Function DisplayScanField(imageList[,add])
	String imageList
	Variable add
	
	DFREF NTSI = root:Packages:NT:ScanImage
	NVAR numImages = NTSI:numImages
	
	
	//Make the master panel or resize it if it exists already
	GetWindow/Z SIDisplay wsize
		
	//Kill original panel
	KillWindow/Z SIDisplay


	If(ParamIsDefault(add))
		add = 0
		numImages = ItemsInList(imageList)
	Else
		numImages += ItemsInList(imageList)
	EndIf
	
	Variable i,j,totalY = 0,maxX = 0
	String yDimList = "",xDimList = ""
	//Check that images all exist and get x/y dimension size
	For(i=ItemsInList(imageList,";")-1;i>-1;i-=1) //step backwards
		Wave theImage = $StringFromList(i,imageList,";")
		If(!WaveExists(theImage))
			imageList = RemoveListItem(i,imageList,";")
		Else
			xDimList += num2str(DimSize(theImage,0) * DimDelta(theImage,0)) + ";"
			yDimList += num2str(DimSize(theImage,1) * DimDelta(theImage,1)) + ";"
			totalY += DimSize(theImage,1) * DimDelta(theImage,1)
			
			//maximum x dimension
			If(DimSize(theImage,0) * DimDelta(theImage,0) > maxX)
				maxX = DimSize(theImage,0) * DimDelta(theImage,0)
				Variable maxXScan = i
			EndIf
		EndIf
	EndFor
	
	//reverse the list for correct order
	xDimList = SortList(xDimList, ";", 16)
	yDimList = SortList(yDimList, ";", 16)
	
	//No valid images
	If(ItemsInList(imageList,";") == 0)
		return 0
	EndIf
	
	
	Variable xPixels,yPixels,frames,xSize,ySize,xDim,yDim,sizeRatio,numCols,baseWidth
	 
	 baseWidth = 360
	 
	//sizing of the panel
	numCols = ceil(numImages / 3)
	If(numCols > 1)
		Variable numRows = 3
		baseWidth *= 0.9
		ySize = ceil(baseWidth * numRows)
	Else
		numRows = numImages
		If(numRows < 3)
			ySize = ceil(baseWidth * numImages)// full size panel width if it's a single column of images
		Else
			baseWidth *= 0.9
			ySize = ceil(baseWidth * numImages)
		EndIf
	EndIf
	
	xSize = numCols * (maxX / (str2num(StringFromList(maxXScan,yDimList,";"))/baseWidth)) //(numCols * ySize/numRows))) //set x size to the maximum sized scanfield since we're vertically stacking them
	
	Variable segmentY = floor(ySize/numImages)
	Variable fractionY,fractionX
	
	//put the new image panel next to the Image Browser window
	GetWindow/Z SI wsize
	Variable leftOffset = V_left + 285

	//Make a new SI Display panel
	NewPanel/K=1/W=(leftOffset,0,leftOffset + xSize,ySize)/N=SIDisplay as "Scanfield Display"	
	ModifyPanel/W=SIDisplay frameStyle=0
	
	//Make the image part of the panel
	DefineGuide/W=SIDisplay imageDivide = {FT,40}
	
	//Make the control bar part of the panel
	NewPanel/HOST=SIDisplay/N=control/FG=(FL,FT,FR,imageDivide)
	ModifyPanel/W=SIDisplay#control frameStyle=0

	//Define bottom guides for each image in a column
	For(i=0;i<numRows;i+=1)
		fractionY = (i+1) / numRows
		fractionY = (fractionY > 1) ? 1 : fractionY //ensure less than 1
		DefineGuide/W=SIDisplay $("imageBottom" + num2str(i)) = {imageDivide,fractionY,FB}	
	EndFor
	
	//Define right guides for each image in a row
	For(i=0;i<numCols;i+=1)
		fractionX = (i+1) / numCols
		fractionX = (fractionX > 1) ? 1 : fractionX //ensure less than 1
		DefineGuide/W=SIDisplay $("imageRight" + num2str(i)) = {FL,fractionX,FR}	
	EndFor
	
	//will save the image name list to an SVAR
	String/G NTSI:SIDisplay_ImageNameList
	SVAR SIDisplay_ImageNameList = NTSI:SIDisplay_ImageNameList
	SIDisplay_ImageNameList = ""
	
	//full paths of the waves in the SI display panel
	String/G NTSI:SIDisplay_ImagePaths
	SVAR SIDisplay_ImagePaths = NTSI:SIDisplay_ImagePaths
	SIDisplay_ImagePaths = imageList
	
	Variable count = 0
	For(i=0;i<numCols;i+=1)
		String guideRight = "imageRight" + num2str(i)
		
		If(i == 0)
			String guideLeft = "FL"
		Else
			guideLeft = "imageRight" + num2str(i-1)
		EndIf
			
		For(j=0;j<numRows;j+=1)
			
			String guideBottom = "imageBottom" + num2str(j)
			
			If(j == 0)
				String guideTop = "imageDivide"
			Else
				guideTop = "imageBottom" + num2str(j-1)
			EndIf
			
			//Make each image subpanel below the control panel
			NewPanel/HOST=SIDisplay/N=$("image" + num2str(count))/FG=($guideLeft,$guideTop,$guideRight,$guideBottom)	
			
			//Display an image window within the subpanel
			String subPanel = "image" + num2str(count)
			String graph = "graph" + num2str(count)
			Display/HOST=SIDisplay#$subPanel/FG=(FL,FT,FR,FB)/N=$graph
			
			//What are the autoscaled min max values? Directly telling Igor what these are greatly speeds up frame play.
			Wave theImage = $StringFromList(count,imageList,";")
			
			Variable maxVal = WaveMax(theImage)
			Variable minVal = WaveMin(theImage)
			

			//Append and modify the image being appended
			//append the image
			AppendImage/W=SIDisplay#$subPanel#$graph/L/T theImage
			ModifyImage/W=SIDisplay#$subPanel#$graph $NameOfWave(theImage) plane=0,ctab= {minVal,maxVal,Grays,0}
			ModifyGraph/W=SIDisplay#$subPanel#$graph noLabel=2,axThick=0,standoff=0,btLen=2,margin=-1
			
			//append the image to the image list
			SIDisplay_ImageNameList += NameOfWave(theImage) + ";"
			
			//Set window hook for scroll zoom
			SetWindow SIDisplay hook(zoomScrollHook) = zoomScrollHook
			SetWindow SIDisplay hook(killWindowHook) = killWindowHook

			count += 1
			
			If(count == numImages)
				break
			EndIf
		EndFor
	EndFor
	

	//Make the control panel
	Button playFrames win=SIDisplay#control,pos={5,0},size={45,20},font=$LIGHT,title="Play",disable=0,proc=handlePlayFrames
	Button slowFrames win=SIDisplay#control,pos={55,0},size={25,20},font=$LIGHT,title="<<",disable=0,proc=handlePlayFrames
	Button speedFrames win=SIDisplay#control,pos={85,0},size={25,20},font=$LIGHT,title=">>",disable=0,proc=handlePlayFrames
	Button stepFrame win=SIDisplay#control,pos={115,0},size={40,20},font=$LIGHT,title="Step",disable=0,proc=handlePlayFrames
	Button autoScale win=SIDisplay#control,pos={160,0},size={40,20},font=$LIGHT,title="Auto",disable=0,proc=siButtonProc
	Button maxProj win=SIDisplay#control,pos={205,0},size={60,20},font=$LIGHT,title="Max Proj",disable=0,proc=siButtonProc
	Button liveROIs win=SIDisplay#control,pos={270,20},size={40,20},font=$LIGHT,title="ROIs",disable=0,proc=siButtonProc
	Button dynamicROI win=SIDisplay#control,pos={270,0},size={40,20},font=$LIGHT,title="Live",disable=0,proc=siButtonProc
	
	NVAR size = NTSI:dynamicROI_Size

	SetVariable dynamicROISize win=SIDisplay#control,pos={315,3},size={40,20},font=$LIGHT,title=" ",value=size,disable=0,proc=siVarProc
	SetVariable selectROI win=SIDisplay#control,pos={315,22},size={40,20},font=$LIGHT,title=" ",value=_NUM:1,limits={1,inf,1},disable=0,proc=siVarProc
	
	String/G NTSI:availableImages
	SVAR availableImages = NTSI:availableImages
	availableImages = WinList("*",";","WIN:1")
	
	Variable numGraphs = ItemsInList(availableImages,";")
	For(i=numGraphs-1;i>-1;i-=1) //go backwards
		String images = ImageNameList(StringFromlist(i,availableImages,";"),";")
		If(!strlen(images))
			availableImages = RemoveListItem(i,availableImages,";")
		EndIf
	EndFor
	availableImages = "SIDisplay;" + availableImages
	
//	PopUpMenu targetImage win=SIDisplay#control,pos={315,1},size={80,20},font=$LIGHT,title="",mode=1,value=#"root:Packages:NT:ScanImage:availableImages"
	
	SetVariable rollingAverage win=SIDisplay#control,pos={200,4},size={60,25},font=$LIGHT,fsize=12,title="Avg",value=_NUM:1,limits={1,inf,1},disable=1,proc=siVarProc
	
	//Create custom color table wave for ROI masks
	Make/O/N=(10,4) NTSI:ROI_ColorTable
	Wave color = NTSI:ROI_ColorTable
	
	//Set all to cyan transparency 25% initially
	color[0][] = 0
	color[1,*][0] = 0
	color[1,*][1] = 43690
	color[1,*][2] = 65535
	color[1,*][3] = 16384
	
	Slider darkValueSlider win=SIDisplay#control,pos={367,5},size={75,20},vert=0,side=0,limits={0,100,1},value=0,proc=siSliderProc
	Slider brightValueSlider win=SIDisplay#control,pos={367,25},size={75,20},vert=0,side=0,limits={0,100,1},value=100,proc=siSliderProc
	
	//Bring panel to the front
	DoWindow/F SIDisplay

End


//handles resize events on the Image Browser
Function resizeHook(s)
	STRUCT WMWinHookStruct &s
	Variable hookResult = 0
	switch(s.eventCode)
		case 0: //Activate
			break
		case 1: //Deactivate
			break
		case 6: //Resize
			Variable r = ScreenResolution / 72
			
			//prevents horizontal resize, allows vertical resize. 460 is the set width of the panel
			GetWindow SI wsize
			
			Variable height = s.winRect.bottom
			height = (height < 125) ? 125 : height
			
			MoveWindow/W=SI V_left,V_top,V_left + 460,V_top + height
			
			Variable vSize = height - 45
			Variable vPos = height - 19
			
			//Set the vertical size of the list boxes
			ListBox scanFolders win=SI,size={85,vSize}
			ListBox scanGroups win=SI,size={85,vSize}
			ListBox scanFields win=SI,size={140,vSize-19}
			ListBox roiGroups win=SI,size={60,vSize-19}
			ListBox rois win=SI,size={60,vSize-19}
			SetVariable scanFieldMatch win=SI,pos={185,vPos}
			PopUpMenu targetImage win=SI,pos={330,vPos-3}
			break
	endswitch
	return hookResult
End

//this allows us to kill all of our other hook functions as we kill the display window
Function killWindowHook(s)
	STRUCT WMWinHookStruct &s
	
	Variable hookResult = 0
	switch(s.eventCode)
		case 0: //Activate
			break
		case 1: //Deactivate
			break
		case 2: //killing window
			DFREF NTSI = root:Packages:NT:ScanImage
			NVAR numImages = NTSI:numImages
			NVAR isMaxProj = NTSI:isMaxProj
	 		Variable i
	 		StopFramePlay()
	 		
	 		//remove all the window hooks
	 		For(i=0;i<numImages;i+=1)
				String subPanel = "image" + num2str(i)
				String graph = "graph" + num2str(i)
				SetWindow SIDisplay#$subPanel#$graph hook(zoomScrollHook) = $""
				isMaxProj = 0
			EndFor
			
			//Kill dynamic ROI window if it exists
			NVAR isDynamicROI = NTSI:isDynamicROI
			isDynamicROI = 0
			KillWindow/Z dynamicROI
			break
	endswitch
	return hookResult
End

//Window hook function for handling mouse scrolls for zooming, and drag and drop image movements
Function zoomScrollHook(s)
	STRUCT WMWinHookStruct &s
	DFREF NTSI = root:Packages:NT:ScanImage
	DFREF NTSR = root:Packages:NT:ScanImage:ROIs
	NVAR clickROIStatus = NTSI:clickROIStatus
	NVAR scaleCumulative = NTSI:scaleCumulative
	NVAR ROI_Engaged = NTSI:ROI_Engaged
		
	Variable hookResult = 0
	switch(s.eventCode)
		case 0: //Activate
			break
		case 1: //Deactivate
			break
		case 3: //mouse down
			
			Variable/G NTSI:mouseDrag
			NVAR mouseDrag = NTSI:mouseDrag
			
			Variable/G NTSI:mouseStartX,NTSI:mouseStartY
			NVAR mouseStartX = NTSI:mouseStartX
			NVAR mouseStartY = NTSI:mouseStartY
			
			If(s.eventMod == 17) //right click
				break
			EndIf
			
			//If we're creating an ROI, don't engage the drag hook function
			If(!ROI_Engaged)
				mouseDrag = 1
			EndIf
			
			mouseStartX = s.mouseLoc.h
			mouseStartY = s.mouseLoc.v
			
			hookResult = 1
			return hookResult
			break
		case 4: //mouse moved
			//This is allowed to execute during ROI creation, so dynamic ROI is 
			//available simultaneously...
			
			NVAR isDynamicROI = NTSI:isDynamicROI	
			NVAR mouseDrag = NTSI:mouseDrag
			
			//Which image frame is being controlled?
			Variable sw = whichSubWindow()

		 	If(sw == -1)
		 		return 0
		 	EndIf
		 		 	
			//Skip dynamic ROI if we're dragging the frame around
			If(!mouseDrag)
				If(isDynamicROI)
					NVAR size = NTSI:dynamicROI_Size
				 	
				 	SVAR SIDisplay_ImagePaths = NTSI:SIDisplay_ImagePaths
				 	
					SVAR dynamicROI_Image = NTSI:dynamicROI_Image
					
					//If the image being hovered over isn't already on the dynamic ROI plot
					String theImagePath = StringFromList(sw,SIDisplay_ImagePaths,";")
					If(cmpstr(dynamicROI_Image,theImagePath))
						StartDynamicROI($theImagePath)
					EndIf
					

					dynamicROI_Image = StringFromList(sw,SIDisplay_ImagePaths,";")
					
					Wave theImage = $dynamicROI_Image
					
					If(!WaveExists(theImage))
						return 1
					EndIf
					
					Variable rows,cols
					rows = DimSize(theImage,0)
					cols = DimSize(theImage,1)
					
					
					String target = "SIDisplay#image" + num2str(sw) + "#graph" + num2str(sw)
					//Horizontal index of image
					Variable hPixel = AxisValFromPixel(target,"top",s.mouseLoc.h)
					hPixel = ScaleToIndex(theImage,hPixel,0)
					
					//Vertical index of image
					Variable vPixel = AxisValFromPixel(target,"left",s.mouseLoc.v)
					vPixel = ScaleToIndex(theImage,vPixel,1)
					
					//Ensure valid index
					If(hPixel > rows - 1 || vPixel > cols - 1 || hPixel < 0 || vPixel < 0)
						return 1
					EndIf
					
					Wave dROI = NTSI:dynamicROI
					Wave block = NTSI:block
										
					Variable left = round(hPixel - size/2)
					Variable right = left + size - 1
					Variable bottom = round(vPixel - size/2)
					Variable top = bottom + size - 1
					
					left = (left < 0) ? 0 : left
					right = (right > rows - 1) ? rows - 1 : right
					bottom = (bottom < 0) ? 0 : bottom
					top = (top > cols - 1) ? cols - 1 : top
				
					try
						block[0,right-left][0,top-bottom] = theImage[left + p][bottom + q];AbortOnRTE
					catch
						Variable error = GetRTError(1)
						return 1
					endtry
									
					MatrixOP/O/FREE vol = transposeVol(block,3)
					MatrixOP/O/FREE sideBeam = sumbeams(vol)
					
					Redimension/N=(-1,-1,1) sideBeam
					MatrixOP/O/FREE vol = transposeVol(sideBeam,1)
					MatrixOP/O dROI = sumbeams(vol)
					
					dROI /= (size * size)
					
					NVAR maxVal = NTSI:dynamicROI_MaxVal
					NVAR minVal = NTSI:dynamicROI_MinVal
					
					Variable dROI_min = WaveMin(dROI)
					Variable dROI_max = WaveMax(dROI)
					
					//Accumulates min and max scaling such that the scale is the widest scale encountered during mouse movement
					If(scaleCumulative)	
						If(dROI_max > maxVal)
							maxVal = dROI_max
							SetAxis/W=dynamicROI left,minVal,maxVal
						EndIf
						
						If(dROI_min < minVal)
							minVal = dROI_min
							SetAxis/W=dynamicROI left,minVal,maxVal
						EndIf
					Else
						//always autoscales to the data limits
						maxVal = 0
						SetAxis/W=dynamicROI left,dROI_min,dROI_max
					EndIf
										
//					//Get the ROI number we are hovering over
//					String list = ImageNameList("SIDisplay#image" + num2str(sw) + "#graph" + num2str(sw),";")
//					String ROIname = StringFromList(1,list,";")
//					
//					If(strlen(ROIname))
//						Wave roiMask = NTSR:$(ROIname + "Num")
//						Variable roiNumber = roiMask[hPixel][vPixel]
//						print roiNumber	
//					EndIf

					
				EndIf
				return 1
			Else
				//Drag the image around
				NVAR mouseStartX = NTSI:mouseStartX
				NVAR mouseStartY = NTSI:mouseStartY
				
				s.doSetCursor = 1
				s.cursorCode = 13 //hand cursor	
			 	
			 	String graphRef = "SIDisplay#image" + num2str(sw) + "#graph" + num2str(sw)
			 	
			 	//difference in pixels from last step to now
				Variable diffX =  AxisValFromPixel(graphRef,"top",s.mouseLoc.h) - AxisValFromPixel(graphRef,"top",mouseStartX)
				Variable diffY =  AxisValFromPixel(graphRef,"left",s.mouseLoc.v) - AxisValFromPixel(graphRef,"left",mouseStartY)
				
				//shift the axis
				GetAxis/W=$graphRef/Q top
				SetAxis/W=$graphRef top,V_min - diffX,V_max - diffX
				GetAxis/W=$graphRef/Q left
				SetAxis/W=$graphRef left,V_min - diffY,V_max - diffY
				
				//reset the start points
				mouseStartX = s.mouseLoc.h
				mouseStartY = s.mouseLoc.v
					
				hookResult = 1
			EndIf
			
			return hookResult
			break
		case 5: //mouse up
			Variable/G NTSI:mouseDrag
			NVAR mouseDrag = NTSI:mouseDrag
			NVAR mouseStartX = NTSI:mouseStartX
			NVAR mouseStartY = NTSI:mouseStartY
			
			//Get target image for drawing
			ControlInfo/W=SI targetImage
			target = S_Value
				
			If(!cmpstr(target,"SIDisplay"))
				sw = WhichSubWindow()
				If(sw == -1) //in case of window focus error or something
					sw = 0
				EndIf
				target = "SIDisplay#image" + num2str(sw) + "#graph" + num2str(sw)
			EndIf
			
			mouseDrag = 0
			
			//Create a new ROI if it's engaged
			If(ROI_Engaged)
				ControlInfo/W=SIDisplay#ROIPanel roiType
				strswitch(S_Value)
					case "Click":
						//What is the width and height?
						ControlInfo/W=SIDisplay#ROIPanel roiWidth
						Variable width = V_Value
						
						ControlInfo/W=SIDisplay#ROIPanel roiHeight
						Variable height = V_Value
						
						ControlInfo/W=SIDisplay#ROIPanel roiName
						String baseName = S_Value
						
						ControlInfo/W=SIDisplay#ROIPanel roiGroupSelect
						String group = S_Value
						
						CreateROIFromClick(mouseStartX,mouseStartY,width,height,target,group,baseName)
						break
					case "Grid":
						break
					default:
						break
				endswitch
			Else
				s.doSetCursor = 1
				s.cursorCode = 3 //hand cursor
			EndIf
			
			break
		case 22: //mouse scroll
			//If we're creating an ROI, don't perform hook function
			If(ROI_Engaged)
				break
			EndIf
			
			SVAR imageList = NTSI:SIDisplay_ImageNameList 
			
			GetMouse/W=SIDisplay
			Variable mouseX = V_left,mouseY = V_top
		 	sw = whichSubWindow()
		 	
		 	If(sw == -1)
		 		return hookResult
		 	EndIf
		 	
		 	graphRef = "SIDisplay#image" + num2str(sw) + "#graph" + num2str(sw)
		 	String imageName = StringFromList(sw,imageList,";")
		 	
		 	//Get center point of the graph
		 	GetWindow $graphRef wsize		 	
		 	
		 	//reduce by 1% per scroll event
		 	Variable delta,newMax,newMin
		 	
			GetAxis/W=$graphRef/Q left
			delta = (V_max - V_min) * 0.06
			
			If(s.wheeldy == 1)
				newMin = V_min + delta
				newMax = V_max - delta
			ElseIf(s.wheeldy == -1)
				newMin = V_min - delta
				newMax = V_max + delta
			Else
				return hookResult
			EndIf

			SetAxis/W=$graphRef left,newMin,newMax
			
			GetAxis/W=$graphRef/Q top
			delta = (V_max - V_min) * 0.06

			If(s.wheeldy == 1)
				newMin = V_min + delta
				newMax = V_max - delta
			ElseIf(s.wheeldy == -1)
				newMin = V_min - delta
				newMax = V_max + delta
			Else
				return 1
			EndIf
	
			SetAxis/W=$graphRef top,newMin,newMax
		
		 	hookResult = 1
		 	return hookResult
			break
	endswitch
	
End

//returns the string of the subwindow that the mouse is over
Function whichSubWindow()
	GetMouse/W=SIDisplay
	Variable mouseX,mouseY
	mouseX = V_left;mouseY = V_top
	
	DFREF NTSI = root:Packages:NT:ScanImage
	NVAR numImages = NTSI:numImages

	Variable i
	For(i=0;i<numImages;i+=1)
		String subPanel = "image" + num2str(i)
		String graph = "graph" + num2str(i)
		GetWindow SIDisplay#$subPanel#$graph wsize
		If(mouseX > V_left && mouseX < V_right && mouseY > V_top && mouseY < V_bottom)
			return i//"SIDisplay#" + subPanel + "#" + graph
		EndIf
	EndFor
	
	return -1	
End

//Starts and stops the frame play background task
Function handlePlayFrames(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	DFREF NTSI = root:Packages:NT:ScanImage
	
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			strswitch(ba.ctrlName)
				case "playFrames":
					NVAR numImages = NTSI:numImages
					NVAR imagePlane = NTSI:imagePlane
					
					
					NVAR isPlaying = NTSI:isPlaying
					NVAR deltaPlane = NTSI:deltaPlane
					
					SVAR imageList = NTSI:SIDisplay_ImageNameList 
					
					//Get the current image plane 
					Variable i
					String name = StringFromList(0,imageList,";")
					String graphRef = "SIDisplay#image0#graph0"
					imagePlane = str2num(StringByKey("plane",ImageInfo(graphRef,name,0),"=",";"))
	
					If(isPlaying)
						StopFramePlay()
					Else
						StartFramePlay()
					EndIf
					break
				case "slowFrames":
					NVAR isPlaying = NTSI:isPlaying
					NVAR deltaPlane = NTSI:deltaPlane
					NVAR numTicks = NTSI:numTicks
					If(isPlaying)
						//first reduce the frames
						deltaPlane -= 2
						
						//once that is minimized, start slowing the refresh
						If(deltaPlane <= 0)
							deltaPlane = 1
							numTicks += 2
							CtrlNamedBackground play, period=numTicks, proc=playFramesBackroundTask
						EndIf
					EndIf
					break
				case "speedFrames":
					NVAR isPlaying = NTSI:isPlaying
					NVAR deltaPlane = NTSI:deltaPlane
					NVAR numTicks = NTSI:numTicks
					If(isPlaying)
						//first increase the frame refresh rate
						numTicks -= 2
						
						//once that is maxed out, start skipping frames
						If(numTicks <= 0 )
							numTicks = 1
							deltaPlane += 1
						EndIf
						
						CtrlNamedBackground play, period=numTicks, proc=playFramesBackroundTask 
					EndIf
					break
				case "stepFrame":
					NVAR isPlaying = NTSI:isPlaying
					
					//first pause the movie
					If(isPlaying)
						StopFramePlay()
						Button playFrames win=SIDisplay#control,title="Play"
					EndIf
					
					//step to the next frame
					StepFrame()
					
					break
			endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

//Puts in the real images to the SIDisplay panel instead of max projections
Function flipMaxProj()
	DFREF NTSI = root:Packages:NT:ScanImage
	SVAR SIDisplay_ImagePaths = NTSI:SIDisplay_ImagePaths
	NVAR plane = NTSI:imagePlane
	NVAR isMaxProj = NTSI:isMaxProj
	
	Variable i
	For(i=0;i<ItemsInList(SIDisplay_ImagePaths,";");i+=1)
		String maxProjName = "maxProj" + num2str(i)
		String subpanel = "image" + num2str(i)
		String graph = "graph" + num2str(i)
		
		Wave theImage = $StringFromList(i,SIDisplay_ImagePaths,";")
		ReplaceWave/W=SIDisplay#$subpanel#$graph image=$maxProjName,$StringFromList(i,SIDisplay_ImagePaths,";")
		
		Variable maxVal = WaveMax(theImage)
		Variable minVal = WaveMin(theImage)
				
		plane = 0
		ModifyImage/W=SIDisplay#$subPanel#$graph $NameOfWave(theImage) plane=plane,ctab= {minVal,maxVal,$"",0}
		
	EndFor
	isMaxProj = 0
End

//Start the background task for playing image frames
Function StartFramePlay()
	NVAR isPlaying = root:Packages:NT:ScanImage:isPlaying
	NVAR numTicks = root:Packages:NT:ScanImage:numTicks //refresh speed
	
	//Make sure to remove max projection images with actual images
	DFREF NTSI = root:Packages:NT:ScanImage
	NVAR isMaxProj = NTSI:isMaxProj
	If(isMaxProj)
		flipMaxProj()
		isMaxProj = 0
	EndIf
	
	CtrlNamedBackground play, period=numTicks, proc=playFramesBackroundTask
	CtrlNamedBackground play, start
	isPlaying = 1
	
	//change button title
	Button playFrames win=SIDisplay#control,title="Pause"
	
End

//Stop the background task for playing image frames
Function StopFramePlay()
	NVAR isPlaying = root:Packages:NT:ScanImage:isPlaying
	CtrlNamedBackground play, stop
	isPlaying = 0
	
	//change button title
	Button playFrames win=SIDisplay#control,title="Play"
				
End

//Steps a single frame of the image stacks
Function StepFrame()
	DFREF NTSI = root:Packages:NT:ScanImage
	NVAR plane = NTSI:imagePlane
	NVAR numImages = NTSI:numImages
	
	SVAR imagePaths = NTSI:SIDisplay_ImagePaths
	SVAR imageList = NTSI:SIDisplay_ImageNameList
	
	//Make sure to remove max projection images with actual images
	NVAR isMaxProj = NTSI:isMaxProj
	If(isMaxProj)
		flipMaxProj()
	EndIf
	
	plane += 1
	
	Variable i
	For(i=0;i<numImages;i+=1)
		String name = StringFromList(i,imageList,";")
		Wave theImage = $StringFromList(i,imagePaths,";")
		
		If(plane > DimSize(theImage,2))
			plane = 0
		EndIf
		
		String panel = "image" + num2str(i)
		String graph = "graph" + num2str(i)
		name = StringFromList(i,imageList,";")
		ModifyImage/Z/W=SIDisplay#$("image" + num2str(i))#$("graph" + num2str(i)) $name plane=plane
	EndFor
	
	DrawAction/W=SIDisplay#control getgroup=frameCountText, delete
	GetWindow/Z SIDisplay wsize
	SetDrawEnv/W=SIDisplay#control textxjust=0,gstart,gname=frameCountText
	DrawText/W=SIDisplay#control 5,40,"Frame: " + num2str(plane) + ", " + num2str(plane * DimDelta(theImage,2)) + "s"
	SetDrawEnv/W=SIDisplay#control gstop
	return 0
	
End

//Background task for playing the image frames
Function playFramesBackroundTask(s)
	STRUCT WMBackgroundStruct &s
	DFREF NTSI = root:Packages:NT:ScanImage
	
	NVAR rollingAverage = NTSI:rollingAverage
	NVAR rollingAverageCount = NTSI:rollingAverageCount
	
	If(rollingAverageCount > rollingAverage)
		rollingAverageCount = rollingAverage
	EndIf
	
	NVAR plane = NTSI:imagePlane
	NVAR deltaPlane = NTSI:deltaPlane
	
	plane += deltaPlane
	
	DFREF NTSI = root:Packages:NT:ScanImage
	NVAR numImages = NTSI:numImages
	
	SVAR imagePaths = NTSI:SIDisplay_ImagePaths
	SVAR imageList = NTSI:SIDisplay_ImageNameList
	
	DoWindow SIDisplay
	If(!V_Flag)
		StopFramePlay()
		return 0
	EndIf

	Variable i
	
	For(i=0;i<numImages;i+=1)
		String name = StringFromList(i,imageList,";")
		Wave theImage = $StringFromList(i,imagePaths,";")
		
		If(plane > DimSize(theImage,2))
			plane = 0
		EndIf
		
		String panel = "image" + num2str(i)
		String graph = "graph" + num2str(i)
		name = StringFromList(i,imageList,";")
		
		If(rollingAverage > 1)
			String graphName = "graph" + num2str(i) + "_rollingAvg"
			Wave avg = NTSI:$graphName
			Wave disp = NTSI:$(graphName + "Display")
			Multithread avg[][][1,*] = avg[p][q][r-1] //shift all frames back 1
			Multithread avg[][][0] = theImage[p][q][plane] //add in the next frame
			MatrixOp/O/S beam = sumbeams(avg) //perform the rolling average
			Multithread disp = beam / rollingAverage
			rollingAverageCount += 1
		Else
			ModifyImage/Z/W=SIDisplay#$("image" + num2str(i))#$("graph" + num2str(i)) $name plane=plane
		EndIf
	EndFor
	
	
	DrawAction/W=SIDisplay#control getgroup=frameCountText,delete
	GetWindow/Z SIDisplay wsize
	SetDrawEnv/W=SIDisplay#control textxjust=0,gstart,gname=frameCountText
	DrawText/W=SIDisplay#control 5,40,"Frame: " + num2str(plane) + ", " + num2str(plane * DimDelta(theImage,2)) + "s"
	SetDrawEnv/W=SIDisplay#control gstop
	return 0
End

//Removes the wave from the SIDisplay window
Function RemoveFromSIDisplay(w)
	Wave w
	
	If(!WaveExists(w))
		return 0
	EndIf
	
	DFREF NTSI = root:Packages:NT:ScanImage
	NVAR numImages = NTSI:numImages
	numImages = GetNumImages("SIDisplay","image")
	
	Variable i
	For(i=0;i<numImages;i+=1)
		RemoveFromGraph/Z/W=$("SIDisplay#image" + num2str(i) + "#graph" + num2str(i)) $NameOfWave(w)
	EndFor
End

//Updates the list boxes on the ScanImage image browser
Function updateImageBrowserLists()
	DFREF NTSI = root:Packages:NT:ScanImage
	
	SVAR software = NTSI:imagingSoftware
	
	Wave/T ScanFolderListWave = NTSI:ScanFolderListWave
	Wave ScanFolderSelWave = NTSI:ScanFolderSelWave
	
	Wave/T ScanGroupListWave = NTSI:ScanGroupListWave
	Wave ScanGroupSelWave = NTSI:ScanGroupSelWave
	
	Wave/T ScanFieldListWave = NTSI:ScanFieldListWave
	Wave ScanFieldSelWave = NTSI:ScanFieldSelWave
	
	Wave/T ROIListWave = NTSI:ROIListWave
	Wave ROISelWave = NTSI:ROISelWave
	
	Wave/T ROIGroupListWave = NTSI:ROIGroupListWave
	Wave ROIGroupSelWave = NTSI:ROIGroupSelWave
	
	//Refresh the scan folders, if any have been added or deleted
	Wave/T listWave = SI_GetScanFolders()
	Redimension/N=(DimSize(listWave,0),-1,-1) ScanFolderListWave,ScanFolderSelWave
	ScanFolderListWave = listWave
	
	//If there are no scan folders, reset everything
	If(DimSize(ScanFolderListWave,0) == 0)
		Redimension/N=(0,-1,-1) ScanFolderListWave,ScanFolderSelWave,ScanGroupListWave,ScanGroupSelWave,ScanFieldListWave,ScanFieldSelWave
		return 0
	EndIf
	
	//If this is 2PLSM, need to make it so the scan folders are the scan groups
	If(!cmpstr(software,"2PLSM"))
		Redimension/N=(DimSize(ScanFolderListWave,0),-1,-1) ScanGroupListWave,ScanGroupSelWave
		ScanGroupListWave[][0][0] = ScanFolderListWave
		
		Redimension/N=(1,-1,-1) ScanFolderListWave,ScanFolderSelWave
		ScanFolderListWave[0] = "2PLSM"
		ScanFolderSelWave[0] = 1 
	Else
		String folder = SelectedScanFolder()
		Wave/T groups = SI_GetScanGroups(folder=ScanFolderListWave[0][0][0])
	
		Redimension/N=(DimSize(groups,0),-1,-1) ScanGroupListWave,ScanGroupSelWave
		ScanGroupListWave = groups
	EndIf
	
	
	//If there are no scan folders, reset everything
	If(DimSize(ScanGroupListWave,0) == 0)
		Redimension/N=(0,-1,-1) ScanGroupListWave,ScanGroupSelWave,ScanFieldListWave,ScanFieldSelWave
		return 0
	EndIf
	
	String selGroups = SelectedScanGroups()
	Wave/T fields = SI_GetScanFields(ScanFolderListWave[0][0][0],group=selGroups)
	
	//Matches the scan fields according to the match string
	SVAR scanFieldMatchStr = NTSI:scanFieldMatchStr
	If(strlen(scanFieldMatchStr))
		matchScanFields(scanFieldMatchStr)
	EndIf
	
	//Refresh the ROI lists
	Wave/T roiGroupList = SI_GetROIGroups()
	Redimension/N=(DimSize(roiGroupList,0)) ROIGroupListWave,ROIGroupSelWave
	ROIGroupListWave = roiGroupList
	
	//Ensure their is a selection
	If(sum(ROIGroupSelWave) == 0 && DimSize(ROIGroupSelWave,0) > 0)
		ROIGroupSelWave[0] = 1
	EndIf
	
	String groupList = SelectedROIGroup()
	
	Wave/T roiList = SI_GetROIs(groupList)
	Redimension/N=(DimSize(roiList,0),-1,-1) ROIListWave,ROISelWave

	ROIListWave = roiList
	//Set selection to the first ROI after refreshing
	If(DimSize(ROISelWave,0) > 0)
		ROISelWave = 0
		ROISelWave[0] = 1 
	EndIf
End

//Handles list box selections in the ScanImage package
Function siListBoxProc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave
	Variable errorCode = 0
	
	DFREF NTSI = root:Packages:NT:ScanImage
	
	//list and selection waves for the ScanImage list boxes
	Wave/T ScanFolderListWave = NTSI:ScanFolderListWave
	Wave ScanFolderSelWave = NTSI:ScanFolderSelWave
	
	Wave/T ScanFieldListWave = NTSI:ScanFieldListWave
	Wave ScanFieldSelWave = NTSI:ScanFieldSelWave
	Wave/T ScanGroupListWave = NTSI:ScanGroupListWave
	Wave ScanGroupSelWave = NTSI:ScanGroupSelWave				
	
	//ROI List and selection waves
	Wave/T ROIGroupListWave = NTSI:ROIGroupListWave
	Wave ROIGroupSelWave = NTSI:ROIGroupSelWave
	
	//ROI List and selection waves
	Wave/T ROIListWave = NTSI:ROIListWave
	Wave ROISelWave = NTSI:ROISelWave
					
	//ROI color table wave
	Wave color = NTSI:ROI_ColorTable
		
	Variable hookResult = 0
	NVAR doubleClick = NTSI:doubleClick
	
	SVAR software = NTSI:imagingSoftware
	software = whichImagingSoftware()
	
	If(doubleClick)
		doubleClick = 0
		return 1
	EndIf
		
	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
				strswitch(lba.ctrlName)
					case "scanFields":	
					case "scanFolders":
					case "scanGroups":
						
						If(lba.eventMod == 16 || lba.eventMod == 17)
							//Goto ROI contextual menu
							PopupContextualMenu/C=(lba.mouseLoc.h, lba.mouseLoc.v) "GoTo;"
							If(V_flag)
								strswitch(lba.ctrlName)	
									case "scanFolders":
										String folderPath = "root:Scans:" + ScanFolderListWave[row]
										break
									case "scanGroups":
										String scanFolder = SelectedScanFolder()
										folderPath = "root:Scans:" + scanFolder + ":" + ScanGroupListWave[row]
										break
									case "scanFields":
										String scanfieldPath = ScanFieldListWave[row][0][1]
										folderPath = ParseFilePath(1,scanfieldPath,":",1,0)
										break
								endswitch
							
								ModifyBrowser collapseAll//close all folders first
								CreateBrowser //activates the data browser focus
								ModifyBrowser setDataFolder = folderPath
								
								If(!cmpstr(lba.ctrlName,"scanFields"))
									ModifyBrowser clearSelection,selectList=scanfieldPath //selects waves 
								EndIf
							EndIf
						EndIf
					break
				case "roiGroups":
					If(lba.eventMod == 16 || lba.eventMod == 17)
						//Rename/Goto ROI contextual menu
						PopupContextualMenu/C=(lba.mouseLoc.h, lba.mouseLoc.v) "Rename;GoTo;"
						If(V_flag)
							strswitch(S_Selection)
								case "Rename":
									ROIGroupSelWave[row] = 2 //set to editable
									break
								case "GoTo":	
									//Browse to the selected wave
									String roiGroup = ROIGroupListWave[row][0][1]
									ModifyBrowser collapseAll//close all folders first
									CreateBrowser //activates the data browser focus
									If(!cmpstr(software,"2PLSM"))
										ModifyBrowser setDataFolder="root:twoP_ROIS:" + roiGroup
									Else
										ModifyBrowser setDataFolder="root:Packages:NT:ScanImage:ROIs:" + roiGroup
									EndIf
									break
							endswitch
						EndIf
					EndIf
					hookResult = 1
					break
				case "rois":
					If(lba.eventMod == 16 || lba.eventMod == 17)
						
						//Rename/Goto/Delete ROI contextual menu
						PopupContextualMenu/C=(lba.mouseLoc.h, lba.mouseLoc.v)/N "roiRightClickMenu" //"Rename;GoTo;Move To;Delete;"
						If(V_flag)
							
							String roiName = ROIListWave[row][0][0]
							roiGroup = ROIListWave[row][0][1]
									
							If(!cmpstr(software,"2PLSM"))
								If(strlen(roiGroup))
									DFREF NTR = root:twoP_ROIS:$roiGroup
									String baseROIPath = "root:twoP_ROIS:"
								Else
									DFREF NTR = root:twoP_ROIS
								EndIf
							Else
								DFREF NTR = root:Packages:NT:ScanImage:ROIs:$roiGroup
								baseROIPath = "root:Packages:NT:ScanImage:ROIs:"
							EndIf
							
							strswitch(S_Selection)
								case "Rename":
									ROISelWave[row] = 2 //set to editable
									break
								case "Delete":

									Wave roiX = NTR:$(roiName + "_x")
									Wave roiY = NTR:$(roiName + "_y")
									
									RemoveFromSIDisplay(roiY) //Remove from the SIDisplay
									ReallyKillWaves(roiY) //Remove from any other plot and kill
									ReallyKillWaves(roiX)
									
									updateImageBrowserLists()
									break
								case "GoTo":
									//Browse to the selected wave
	
									Wave roiX = NTR:$(roiName + "_x")
									ModifyBrowser collapseAll//close all folders first
									CreateBrowser //activates the data browser focus
									
									If(!cmpstr(software,"2PLSM"))
										If(strlen(roiGroup))
											ModifyBrowser setDataFolder="root:twoP_ROIS:" + roiGroup
										Else
											ModifyBrowser setDataFolder="root:twoP_ROIS"
										EndIf
									Else
										ModifyBrowser setDataFolder="root:Packages:NT:ScanImage:ROIs:" + roiGroup
									EndIf
									
									ModifyBrowser clearSelection,selectList=GetWavesDataFolder(roiX,2) //selects waves
									break
								default:
									//Move To option was selected if it's default
									If(!strlen(S_Selection))
										return 0
									EndIf
									
									String moveToROI = S_Selection
									Wave roiX = NTR:$(roiName + "_x")
									Wave roiY = NTR:$(roiName + "_y")
									
									MoveWave roiX,$(baseROIPath + moveToROI + ":")
									MoveWave roiY,$(baseROIPath + moveToROI + ":")
									updateImageBrowserLists()
									break
							endswitch
						EndIf
					EndIf
					hookResult = 1
					break
			endswitch
			break
		case 2: // mouse up
			
			//Uses the mouse up instead of selection hook because this process may take computation time and cause..
			//...lag if it's called on every selection hook.
			strswitch(lba.ctrlName)
				case "rois":		
					String roiList = SelectedROIs()
					String groupList = SelectedROIs(groups=1)			
					
					appendROIsToImage(groupList,roiList)
					hookResult = 1
					break
			endswitch
			
			break
		case 3: // double click
			strswitch(lba.ctrlName)
				case "roiGroups":
					//select all ROIs in the group
					groupList = SelectedROIGroup()
					Wave/T listWave = SI_GetROIs(groupList)
					Redimension/N=(DimSize(listWave,0),-1,-1) ROIListWave,ROISelWave
					ROIListWave = listWave
					
					If(DimSize(ROISelWave,0) > 0)
						ROISelWave = 1
					EndIf
					
					roiList = SelectedROIs()
					groupList = SelectedROIs(groups=1)			
					
					appendROIsToImage(groupList,roiList)
					
					//Sets this variable to block the very next call to WMListBoxAction, which is Cell Selection			
					doubleClick = 1
					break
			endswitch
			
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
			strswitch(lba.ctrlName)
				case "scanFolders":
					String folder = SelectedScanFolder()
					Wave/T scanGroups = SI_GetScanGroups(folder=folder)
					
					//update the scan field list box according to the scan group selection
					Redimension/N=(DimSize(scanGroups,0),-1,-1) ScanGroupListWave,ScanGroupSelWave
					ScanGroupListWave = scanGroups
					
					String groups = SelectedScanGroups()
					Wave/T scanFields = SI_GetScanFields(folder,group=groups)
					
					//update the scan field list box according to the scan group selection
					Redimension/N=(DimSize(scanFields,0),-1,-1) ScanFieldListWave,ScanFieldSelWave
					ScanFieldListWave = scanFields
					
					break
				case "scanGroups":
					ControlInfo/W=SI selectAllScanGroups
					Variable selectAll = V_Value
					
					If(row > DimSize(listWave,0) - 1)
						return 0
					ElseIf(selectAll)
						ScanGroupSelWave = 1
					EndIf

					folder = SelectedScanFolder()
					groups = SelectedScanGroups()
					SI_GetScanFields(folder,group=groups)
					
					ControlInfo/W=SI selectAllScanFields
					selectAll = V_Value
					If(selectAll)
						ScanFieldSelWave = 1
					EndIf
					
					break		
				case "scanFields":
					ControlInfo/W=SI selectAllScanFields
					selectAll = V_Value
					If(selectAll)
						ScanFieldSelWave = 1
						return 0
					EndIf
					break
				case "roiGroups":
					//Updates the ROI list box for the selected ROI groups
					
					groupList = SelectedROIGroup()
					Wave/T listWave = SI_GetROIs(groupList)
					Redimension/N=(DimSize(listWave,0),-1,-1) ROIListWave,ROISelWave
					ROIListWave = listWave
					
					If(DimSize(ROISelWave,0) > 0)
						ROISelWave = 0
						ROISelWave[0] = 1
					Else
						//remove any ROI displays from the selected image
						appendROIsToImage("","")
					EndIf
					
					hookResult = 1
					break
				case "rois":
					If(lba.eventMod == 19) //shift held during right click
						
						//Rename/Goto/Delete ROI contextual menu
						PopupContextualMenu/C=(lba.mouseLoc.h, lba.mouseLoc.v)/N "roiRightClickMenu" //"Rename;GoTo;Move To;Delete;"
						If(V_flag)
							HandleSelectionRightClick(S_Selection,software,ROIListWave,ROISelWave)
						EndIf
						
					EndIf
					break
			endswitch
			
			SVAR scanFieldMatchStr = NTSI:scanFieldMatchStr
			matchScanFields(scanFieldMatchStr)
			break
		case 6: // begin edit
			SVAR oldROIGroupName = NTSI:oldROIGroupName //this will work for both groups and rois
			strswitch(lba.ctrlName)
				case "roiGroups":
					oldROIGroupName = ROIGroupListWave[row]
					break
				case "rois":
					oldROIGroupName = ROIListWave[row]
					break
			endswitch
			break
		case 7: // finish edit
			SVAR oldROIGroupName = NTSI:oldROIGroupName
		
			
			strswitch(lba.ctrlName)
				case "roiGroups":			
					String newName = ROIGroupListWave[row][0][0]
					
					//Can't overwrite itself
					If(!cmpstr(newName,oldROIGroupName))
						ROISelWave[row] = 1
						return 0
					EndIf
					
					roiGroup = ROIGroupListWave[row][0][1]
							
					ROIGroupSelWave[row] = 1
					
					If(!cmpstr(software,"2PLSM"))
						RenameDataFolder root:twoP_ROIS:$oldROIGroupName,$ROIGroupListWave[row]
					Else
						RenameDataFolder root:Packages:NT:ScanImage:ROIs:$oldROIGroupName,$ROIGroupListWave[row]
					EndIf
									
					break
				case "rois":
					newName = ROIListWave[row][0][0]
					
					//Can't overwrite itself
					If(!cmpstr(newName,oldROIGroupName))
						ROISelWave[row] = 1
						return 0
					EndIf
					
					roiGroup = ROIListWave[row][0][1]
					
					If(!cmpstr(software,"2PLSM"))
						If(strlen(roiGroup))	
							DFREF NTR = root:twoP_ROIS:$roiGroup
						Else
							DFREF NTR = root:twoP_ROIS
						EndIf
					Else
						DFREF NTR = root:Packages:NT:ScanImage:ROIs:$roiGroup
					EndIf
					
					If(stringmatch(oldROIGroupName,"*soma"))
						Wave origROI = NTR:$(oldROIGroupName + "_soma")
						Duplicate/O origROI, NTR:$(newName + "_soma")
						
						ReallyKillWaves(origROI)
					Else
						Wave origROIx = NTR:$(oldROIGroupName + "_x")
						Wave origROIy = NTR:$(oldROIGroupName + "_y")
						Duplicate/O origROIx, NTR:$(newName + "_x")
						Duplicate/O origROIy, NTR:$(newName + "_y")

						RemoveFromSIDisplay(origROIy)
						ReallyKillWaves(origROIy)
						ReallyKillWaves(origROIx)
					EndIf
					
					ROISelWave[row] = 1
					break
			endswitch
			
			updateImageBrowserLists()
			refreshROIGroupList()
			break
		case 13: // checkbox clicked (Igor 6.2 or later)
			break
	endswitch
	return hookResult
End

//Handle ROI selection right clicks
Function HandleSelectionRightClick(selection,software,ROIListWave,ROISelWave)
	String selection,software
	Wave/T ROIListWave
	Wave ROISelWave
	
	Variable i
	//Get the selected ROIs
	String roiNameList="",roiGroupList="",roiName="",roiGroup="",selectedRowList=""
	For(i=0;i<DimSize(ROISelWave,0);i+=1)
		If(ROISelWave[i] > 0)
			roiNameList += ROIListWave[i][0][0] + ";"
			roiGroupList += ROIListWave[i][0][1] + ";"
			selectedRowList += num2str(i) + ";"
		EndIf
	EndFor
	
	Variable numROIs = ItemsInList(roiNameList,";")
	For(i=0;i<numROIs;i+=1)
		roiGroup = StringFromList(i,roiGroupList,";")
		roiName = StringFromList(i,roiNameList,";")
		Variable row = str2num(StringFromList(i,selectedRowList,";"))
		
		//Set the correct path to the ROI folder
		If(!cmpstr(software,"2PLSM"))
			If(strlen(roiGroup))
				DFREF NTR = root:twoP_ROIS:$roiGroup
				String baseROIPath = "root:twoP_ROIS:"
			Else
				DFREF NTR = root:twoP_ROIS
			EndIf
		Else
			DFREF NTR = root:Packages:NT:ScanImage:ROIs:$roiGroup
			baseROIPath = "root:Packages:NT:ScanImage:ROIs:"
		EndIf
		
		//Handle the right click selection
		strswitch(selection)
			case "Rename":
				ROISelWave[row] = 2 //set to editable
				break
			case "Delete":

				Wave roiX = NTR:$(roiName + "_x")
				Wave roiY = NTR:$(roiName + "_y")
				
				RemoveFromSIDisplay(roiY) //Remove from the SIDisplay
				ReallyKillWaves(roiY) //Remove from any other plot and kill
				ReallyKillWaves(roiX)
				
				updateImageBrowserLists()
				break
			case "GoTo":
				//Browse to the selected wave

				Wave roiX = NTR:$(roiName + "_x")
				ModifyBrowser collapseAll//close all folders first
				CreateBrowser //activates the data browser focus
				
				If(!cmpstr(software,"2PLSM"))
					If(strlen(roiGroup))
						ModifyBrowser setDataFolder="root:twoP_ROIS:" + roiGroup
					Else
						ModifyBrowser setDataFolder="root:twoP_ROIS"
					EndIf
				Else
					ModifyBrowser setDataFolder="root:Packages:NT:ScanImage:ROIs:" + roiGroup
				EndIf
				
				ModifyBrowser clearSelection,selectList=GetWavesDataFolder(roiX,2) //selects waves
				break
			default:
				//Move To option was selected if it's default
				If(!strlen(selection))
					return 0
				EndIf
				
				String moveToROI = selection
				Wave roiX = NTR:$(roiName + "_x")
				Wave roiY = NTR:$(roiName + "_y")
				
				MoveWave roiX,$(baseROIPath + moveToROI + ":")
				MoveWave roiY,$(baseROIPath + moveToROI + ":")
				break
		endswitch
	EndFor
	
	updateImageBrowserLists()
End

//Handles list box selections in the ScanImage package
Function siButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	DFREF NTSI = root:Packages:NT:ScanImage
	
	Variable hookResult = 0
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			strswitch(ba.ctrlName)
				case "displayScanfield":
					//first ensure that the mouse drag monitor is set to 0
					NVAR mouseDrag = NTSI:mouseDrag
					mouseDrag = 0
					
					//displays the selected scanfield in a new panel
					String imageList = GetSelectedImages()
					DisplayScanField(imageList)
					break
				case "updateImageBrowser":
					//refreshes the list boxes in case of any deleted or loaded scans
					updateImageBrowserLists()
					
					//Matches the scan fields according to the match string
//					SVAR scanFieldMatchStr = NTSI:scanFieldMatchStr
//					If(strlen(scanFieldMatchStr))
//						matchScanFields(scanFieldMatchStr)
//					EndIf
								
					break
				case "autoScale":
					//resets all the scaling on the displayed images
					NVAR numImages = NTSI:numImages
					Variable i
					For(i=0;i<numImages;i+=1)
						String graphRef = "SIDisplay#image" + num2str(i) + "#graph" + num2str(i)
						SetAxis/W=$graphRef/A
					EndFor
					break
					
				case "liveROIs":
					
//					Button somaROI win=SIDisplay#control,pos={315,20},size={80,20},font=$LIGHT,valueColor=(0,0x9999,0),title="Find Somas",disable=0,proc=siButtonProc
					
					
					//Build a new external panel for controlling ROI creation
					DoWindow/W=SIDisplay#ROIPanel ROIPanel
					If(V_flag)
						break
					EndIf
					
					NewPanel/EXT=1/HOST=SIDisplay/N=ROIPanel/W=(110,0,0,300) as "Create ROIs"
					PopUpMenu roiType,win=SIDisplay#ROIPanel,pos={54,10},bodywidth=72,title="Type",font=$LIGHT,value="Marquee;Click;Grid;Somas;",proc=siPopProc
			
					//Disable the movement hook for marquee mode
					ControlInfo/W=SIDisplay#ROIPanel roiType
					
					If(!cmpstr(S_Value,"Marquee"))
						SetWindow SIDisplay hook(zoomScrollHook) = $""
					EndIf
					
					NVAR ROI_Width = NTSI:ROI_Width
					NVAR ROI_Height = NTSI:ROI_Height
	
					SetVariable roiWidth,win=SIDisplay#ROIPanel,pos={2,35},size={60,20},bodywidth=30,title="Width",font=$LIGHT,limits={2,inf,1},value=ROI_Width,disable=1
					SetVariable roiHeight,win=SIDisplay#ROIPanel,pos={2,55},size={60,20},bodywidth=30,title="Height",font=$LIGHT,limits={2,inf,1},value=ROI_Height,disable=1
					SetVariable ROIname win=SIDisplay#ROIPanel,pos={3,35},size={93,20},font=$LIGHT,value=_STR:"",title="Name",disable=0
					
					Wave/T ROIGroupListWave = NTSI:ROIGroupListWave
					String/G NTSI:GroupList 
					SVAR GroupList = NTSI:GroupList
					GroupList = "**NEW**;" + TextWaveToStringList(ROIGroupListWave,";")
					
					PopUpMenu roiGroupSelect,win=SIDisplay#ROIPanel,pos={54,55},bodywidth=72,title="Group",font=$LIGHT,value=#"root:Packages:NT:ScanImage:GroupList",proc=siPopProc
					Button addROI win=SIDisplay#ROIPanel,pos={2,80},size={20,20},font=$LIGHT,valueColor=(0,0x9999,0),title="+",disable=0,proc=siButtonProc
					Button confirmROI win=SIDisplay#ROIPanel,pos={25,80},size={81,20},font=$LIGHT,valueColor=(0,0x9999,0),title="Done",disable=0,proc=siButtonProc

					break
				
				case "addROI":
					//Adds new marquee ROI

					//Get target image for drawing
					ControlInfo/W=SI targetImage
					String target = S_Value
					
					If(!strlen(target))
						target = "SIDisplay"
						PopUpMenu targetImage,win=SI,value="SIDisplay"
					EndIf
					
					If(!cmpstr(target,"SIDisplay"))
						GetMarquee/W=$("SIDisplay#image0#graph0")/K left,top
					Else
						GetMarquee/W=$target/K/Z left,top
					EndIf
					
					Variable leftEdge,rightEdge,topEdge,bottomEdge
					leftEdge = V_left;rightEdge=V_right;topEdge=V_top;bottomEdge=V_bottom
					
					
					If(V_flag)
					
						//Which group will we put the new ROI in?
						ControlInfo/W=SIDisplay#ROIPanel ROIGroupSelect
						String group = S_Value
						
						ControlInfo/W=SIDisplay#ROIPanel ROIname
						String baseName = S_Value
						Wave/Wave roiRefs = CreateROI(leftEdge,topEdge,rightEdge,bottomEdge,group=group,baseName=baseName)
						
						If(!WaveExists(roiRefs))
							return 0
						EndIf
						
						//Append the ROI onto the image
						
						Wave roiX = roiRefs[0]
						Wave roiY = roiRefs[1]
						
						NVAR numImages = NTSI:numImages
						
						If(!cmpstr(target,"SIDisplay"))
							For(i=0;i<numImages;i+=1)
								String graph = "graph" + num2str(i)
								String subPanel = "image" + num2str(i)
								
								AppendToGraph/W=SIDisplay#$subPanel#$graph/L/T roiY vs roiX
							EndFor
						Else
							String imageName = StringFromList(0,ImageNameList(target,";"),";")
							If(!strlen(imageName))
								return 0
							EndIf
							String info = ImageInfo(target,imageName,0)
							String axisflags = StringByKey("AXISFLAGS",info)
							
							strswitch(axisflags)
								case "/T":
									AppendToGraph/W=$target/T roiY vs roiX
									break
								case "/R":
									AppendToGraph/W=$target/R roiY vs roiX
									break
								case "/T/L":
									AppendToGraph/W=$target/T/L roiY vs roiX
									break
								case "/B/L":
									AppendToGraph/W=$target/B/L roiY vs roiX
									break
								case "/T/R":
									AppendToGraph/W=$target/T/R roiY vs roiX
								default:
								AppendToGraph/W=$target/L/B roiY vs roiX
							endswitch
						EndIf						
						updateImageBrowserLists()
					EndIf		
					
					//Refresh the ROI group list
					refreshROIGroupList()
					
					break
				case "confirmROI":
				
					NVAR ROI_Engaged = NTSI:ROI_Engaged
					
					If(ROI_Engaged)
						ROI_Engaged = 0 //set back to zero, finished creating ROIs
						
						Button confirmROI win=SIDisplay#ROIPanel,title="Start"
											
						KillWindow/Z SIDisplay#ROIPanel
						
						//Enable the mouse movement hook for the SIDisplay window
						SetWindow SIDisplay hook(zoomScrollHook) = zoomScrollHook
						
					Else
						//Begin creating ROIs
						ROI_Engaged = 1
						
						Button confirmROI win=SIDisplay#ROIPanel,title="Finish"
					EndIf
					break
				case "somaROI":
					//Finds all the somas in the ROI, and makes a 3D ROI mask wave, each soma in it's own layer
					
					//Enable the movement hook
					SetWindow SIDisplay hook(zoomScrollHook) = zoomScrollHook
					
					//Hide the confirm button and ROI name entry
					SetVariable ROIname win=SIDisplay#ROIPanel,disable=3
					Button confirmROI win=SIDisplay#ROIPanel,disable=3,proc=siButtonProc
					Button somaROI win=SIDisplay#ROIPanel,disable=3,proc=siButtonProc
					
						
					//Get target image for drawing
					ControlInfo/W=SI targetImage
					target = S_Value
					
					If(!cmpstr(target,"SIDisplay"))
						target = "SIDisplay#image0#graph0"
					EndIf
					
					imageList = ImageNameList(target,";")
					Wave theImage = ImageNameToWaveRef(target,StringFromList(0,imageList,";"))
				
							
					//Get ROI name
					ControlInfo/W=SIDisplay#control ROIname
					String name = S_Value + "_soma"
					
					If(!strlen(S_Value))
						Abort "Must enter a name for the ROI"
						return 0
					EndIf
					
					If(WaveExists($("root:Packages:NT:ScanImage:ROIs:" + S_Value + "_soma")))
						DoAlert/T="Overwrite ROI?" 1,"ROI already exists. Overwrite?"
						If(V_flag == 2) //clicked no
							return 0
						EndIf
					EndIf
					
					FindSomas(theImage,name)
					
					break
				case "maxProj":
					NVAR isMaxProj = NTSI:isMaxProj
					
					If(isMaxProj)
						break
					EndIf
					
					//pauses the frame video and subs in the max projection images
					StopFramePlay()
					
					//Get max projection of every image in the SIDisplay
					SVAR SIDisplay_ImagePaths = root:Packages:NT:ScanImage:SIDisplay_ImagePaths
					
					
					For(i=0;i<ItemsInList(SIDisplay_ImagePaths,";");i+=1)
						Wave theImage = $StringFromList(i,SIDisplay_ImagePaths,";")
						
						If(!WaveExists(theImage))
							continue
						EndIf
						
						String outName = "maxProj" + num2str(i)
						
						MatrixOP/O NTSI:$outName = sumBeams(theImage)
						Wave maxProj = NTSI:$outName
						
						Redimension/S maxProj //must be 32 bit float to be divided by 200 
						maxProj /= DimSize(theImage,2)
						
						CopyScales/P theImage,maxProj
						
						subpanel = "image" + num2str(i)
						graph = "graph" + num2str(i)
						ReplaceWave/W=SIDisplay#$subpanel#$graph image=$NameOfWave(theImage),maxProj
				
						ModifyImage/Z/W=SIDisplay#$subpanel#$graph $NameOfWave(maxProj),ctab={*,*,$"",0}
						
						//Put a copy in the image's home folder
						Duplicate/O maxProj,$(GetWavesDataFolder(theImage,2) + "_max")
					
					EndFor
					
					isMaxProj = 1 
					break
				case "dynamicROI":
					SVAR SIDisplay_ImagePaths = NTSI:SIDisplay_ImagePaths
					Wave theImage = $StringFromList(0,SIDisplay_ImagePaths,";")
					NVAR isDynamicROI = NTSI:isDynamicROI
					
					If(isDynamicROI)
						isDynamicROI = 0
						KillWindow/Z dynamicROI
						return 1
					Else
						isDynamicROI = 1
					EndIf
					StartDynamicROI(theImage)
					break
				case "BrowseScans":
					//browse files on disk for wavesurfer loading
					Variable fileID
					SVAR ScanLoadPath = NTSI:ScanLoadPath

					//Set the default dialog path
					PathInfo/S ScanLoadPath
					
					//Pick a folder
					NewPath/O scanPath
					
					PathInfo scanPath
					ScanLoadPath = S_path

					If(!strlen(ScanLoadPath))
						return 0
					EndIf
					
					Wave/T ScanLoadListWave = NTSI:ScanLoadListWave
					Wave ScanLoadSelWave = NTSI:ScanLoadSelWave
					
					String fileList = IndexedFile(scanPath,-1,".tif")
					fileList = SortList(fileList, ";", 16)
					
					Wave/T listWave = StringListToTextWave(fileList,";")
					Redimension/N=(DimSize(listWave,0)) ScanLoadListWave,ScanLoadSelWave
					ScanLoadListWave = listWave
					
					Close/A
					break
			endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return hookResult
End

//Handles all check box clicks
Function siCheckBoxProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	DFREF NTSI = root:Packages:NT:ScanImage
	
	Wave ScanFieldSelWave = NTSI:ScanFieldSelWave
	Wave ScanGroupSelWave = NTSI:ScanGroupSelWave
	
	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			
			strswitch(cba.ctrlName)
				case "selectAllScans":
					Wave ScanLoadSelWave = NTSI:ScanLoadSelWave
					If(cba.checked)
						ScanLoadSelWave = 1
					Else
						ScanLoadSelWave = 0
					EndIf
					break
				case "selectAllScanGroups":
					ScanGroupSelWave = checked
					
					If(!checked && DimSize(ScanGroupSelWave,0) > 0)
						ScanGroupSelWave[0] = 1
					EndIf
					
					//Update the scan fields list box
					String folder = SelectedScanFolder()
					String groups = SelectedScanGroups()
					SI_GetScanFields(folder,group=groups)
					
					ControlInfo/W=SI selectAllScanFields
					Variable selectAll = V_Value
					If(selectAll)
						ScanFieldSelWave = 1
					EndIf
					
					break
				case "selectAllScanFields":
					Wave ScanFieldSelWave = NTSI:ScanFieldSelWave
					ScanFieldSelWave = checked
					break
				case "CumulativeScale":
					NVAR scaleCumulative = NTSI:scaleCumulative
					scaleCumulative = checked
			endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


//Handles the variable inputs on the SI display panel
Function siVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	DFREF NTSI = root:Packages:NT:ScanImage
	
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			NVAR rollingAverage = NTSI:rollingAverage
			NVAR numImages = NTSI:numImages
			NVAR imagePlane = NTSI:imagePlane
			SVAR imagePaths = NTSI:SIDisplay_ImagePaths
			SVAR imageList = NTSI:SIDisplay_ImageNameList
			Variable i
			
			
			strswitch(sva.ctrlName)
				case "filterSize":
					//sets filter to zero if it's less than 5, meaning no filter will be applied
					Variable filter = (dval < 5) ? 0:dval
					
					SetVariable filterSize win=NT,value=_NUM:filter
					break
				case "dynamicROISize":
					SVAR dynamicROI_Image = NTSI:dynamicROI_Image
					Wave theImage = $dynamicROI_Image
					NVAR isDynamicROI = NTSI:isDynamicROI
					
					If(isDynamicROI)
						If(!WaveExists(theImage))
							isDynamicROI = 0
							return 1
						EndIf
			
						StartDynamicROI(theImage)
					EndIf
					break
				case "scanFieldMatch":
					//refreshes the list boxes in case of any deleted or loaded scans
					updateImageBrowserLists()
					
					//Matches the scan fields according to the match string
					matchScanFields(sval)
					break
				case "selectROI":
					//turns the indicated ROI yellow and the rest cyan.
					String list = ImageNameList("SIDisplay#image0#graph0",";")
					String roiName = StringFromList(1,list,";")
					
					If(!strlen(roiName))
						break
					EndIf

					If(dval == 0)
						break
					EndIf
										
					Wave color = NTSI:ROI_ColorTable
	
					//Set all to cyan transparency 25% initially
					color[0][] = 0
					color[1,*][0] = 0
					color[1,*][1] = 43690
					color[1,*][2] = 65535
					color[1,*][3] = 16384
					
					//Set specific ROI to yellow
					color[dval][0] = 52425
					color[dval][1] = 52425
					color[dval][2] = 0
					
					break
			endswitch
//			
//			//sets the rolling average
//			rollingAverage = dval
//			
//			//makes the rolling average display waves
//			If(rollingAverage > 1)
//				For(i=0;i<numImages;i+=1)
//					Wave theImage = $StringFromList(i,imagePaths,";")
//					String graphName = "graph" + num2str(i) + "_rollingAvg"
//					Make/O/N=(DimSize(theImage,0),DimSize(theImage,1),rollingAverage) NTSI:$graphName
//					Make/O/N=(DimSize(theImage,0),DimSize(theImage,1),0) NTSI:$(graphName + "Display")
//					Wave avg = NTSI:$graphName
//					Wave disp = NTSI:$(graphName + "Display")
//					Multithread disp[][][] = 0
//					Multithread disp[][][0] = theImage[p][q][imagePlane]
//					Multithread avg[][][] = 0
//					Multithread avg[][][0] = theImage[p][q][imagePlane]
//					
//					//make sure the scale is the same
//					CopyScales/P theImage,avg
//					CopyScales/P theImage,disp
//					//replace it with the rolling average version 
//					ReplaceWave/W=$("SIDisplay#image" + num2str(i) + "#graph" + num2str(i)) image=$StringFromList(i,imageList,";"),disp
//				EndFor
//			Else
//				For(i=0;i<numImages;i+=1)
//					graphName = "graph" + num2str(i) + "_rollingAvgDisplay"
//					Wave disp = NTSI:$graphName
//					
//					ReplaceWave/W=$("SIDisplay#image" + num2str(i) + "#graph" + num2str(i)) image=disp,$StringFromList(i,imageList,";")
//					Wave theImage = $StringFromList(i,imagePaths,";")
//				EndFor
//			EndIf
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

//Handles all pop up menu actions in SI panel
Function siPopProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			
			strswitch(pa.ctrlName)
				case "targetImage":
					If(!stringmatch(popStr,"_none_"))
						DoWindow/F $popStr
					EndIf
					break
				case "roiType":
					//handle ROI creation control displays
					SwitchROIControls(popStr)
					break
			endswitch
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function siSliderProc(sa) : SliderControl
	STRUCT WMSliderAction &sa
	DFREF NTSI = root:Packages:NT:ScanImage
	
	switch( sa.eventCode )
		case -3: // Control received keyboard focus
		case -2: // Control lost keyboard focus
		case -1: // Control being killed
			break
		default:
			If( sa.eventCode & 1 ) // value set
				Variable curval = sa.curval / 100
				
		
				//resets all the scaling on the displayed images
				NVAR numImages = NTSI:numImages
				Variable i
				For(i=0;i<numImages;i+=1)
					//Get the min/max setting for the 
					String graphRef = "SIDisplay#image" + num2str(i) + "#graph" + num2str(i)
					String list = ImageNameList(graphRef,";")
					Wave image = ImageNameToWaveRef(graphRef,StringFromList(0,list,";"))
					Variable minVal = WaveMin(image)
					Variable maxVal = WaveMax(image)
					
					strswitch(sa.ctrlName)
						case "darkValueSlider":
							ControlInfo/W=SIDisplay#control brightValueSlider
							ModifyImage/W=$graphRef $StringFromList(0,list,";"),ctab={round(minVal + curval * (maxVal - minVal)),round(minVal + (V_Value/100) * (maxVal - minVal)),Grays,0}
							break
						case "brightValueSlider":
							ControlInfo/W=SIDisplay#control darkValueSlider
							ModifyImage/W=$graphRef $StringFromList(0,list,";"),ctab={round(minVal + (V_Value/100) * (maxVal - minVal)),round(minVal + curval * (maxVal - minVal)),Grays,0}
						break
					endswitch
				EndFor
			EndIf
			break
	endswitch

	return 0
End

//Switches control display on the ROI Creation Panel according to ROI type
Function SwitchROIControls(roiType)
	String roiType
	
	strswitch(roiType)
		case "Marquee":
			SetVariable roiWidth,win=SIDisplay#ROIPanel,disable=1
			SetVariable roiHeight,win=SIDisplay#ROIPanel,disable=1
			SetVariable ROIname,win=SIDisplay#ROIPanel,pos={3,35},disable=0
			Button addROI,win=SIDisplay#ROIPanel,disable=0
			Button confirmROI,win=SIDisplay#ROIPanel,pos={25,80},size={81,20},title="Done"
			PopUpMenu roiGroupSelect,win=SIDisplay#ROIPanel,pos={5,55},bodywidth=72,disable=0

			SetWindow SIDisplay hook(zoomScrollHook) = $""
			break
		case "Click":
			SetVariable roiWidth,win=SIDisplay#ROIPanel,disable=0
			SetVariable roiHeight,win=SIDisplay#ROIPanel,disable=0
			SetVariable ROIname,win=SIDisplay#ROIPanel,pos={3,75},disable=0
			Button addROI,win=SIDisplay#ROIPanel,disable=1
			Button confirmROI,win=SIDisplay#ROIPanel,pos={9,120},size={93,20},title="Start"
			PopUpMenu roiGroupSelect,win=SIDisplay#ROIPanel,pos={5,95},bodywidth=72, disable=0
			
			SetWindow SIDisplay hook(zoomScrollHook) = zoomScrollHook
			break
		case "Grid":
			SetVariable roiWidth,win=SIDisplay#ROIPanel,disable=0
			SetVariable roiHeight,win=SIDisplay#ROIPanel,disable=0
			SetVariable ROIname,win=SIDisplay#ROIPanel,pos={3,75},disable=0
			Button addROI,win=SIDisplay#ROIPanel,disable=1
			Button confirmROI,win=SIDisplay#ROIPanel,pos={9,120},size={93,20},title="Start"
			PopUpMenu roiGroupSelect,win=SIDisplay#ROIPanel,pos={5,95},bodywidth=72,disable=0
			
			SetWindow SIDisplay hook(zoomScrollHook) = zoomScrollHook
			break
	endswitch
End

Function refreshROIGroupList()
	DFREF NTSI = root:Packages:NT:ScanImage
	
	//Refresh the ROI group list
	Wave/T ROIGroupListWave = NTSI:ROIGroupListWave
	String/G NTSI:GroupList 
	SVAR GroupList = NTSI:GroupList
	GroupList = "**NEW**;" + TextWaveToStringList(ROIGroupListWave,";")

End

//Dynamic ROI
Function StartDynamicROI(theImage)
	Wave theImage
	
	DFREF NTSI = root:Packages:NT:ScanImage
	NVAR scaleCumulative = NTSI:scaleCumulative
	
	//Make a new display window
	GetWindow/Z dynamicROI wsize
	KillWindow/Z dynamicROI
	
	If(!V_flag)
		Display/N=dynamicROI/W=(V_left,V_top,V_right,V_bottom)/K=1 as "Dynamic ROI"
	Else
		GetWindow/Z SIDisplay wsize
		Display/N=dynamicROI/W=(V_right,V_top,V_right+300,V_top+200)/K=1 as "Dynamic ROI"
	EndIf
	
	ControlBar/T/W=dynamicROI 20
	Checkbox CumulativeScale,win=dynamicROI,pos={5,0},size={100,20},side=1,title="Cumulative Scaling ",value=scaleCumulative,proc=siCheckBoxProc 
	
	Variable frames = DimSize(theImage,2)
	Variable delta = DimDelta(theImage,2)
	Variable offset = DimOffset(theImage,2)
	
	DFREF NTSI = root:Packages:NT:ScanImage
	Make/O/N=(frames) NTSI:dynamicROI/Wave=dROI
	
	SetScale/P x,offset,delta,dROI
	
	NVAR size = NTSI:dynamicROI_Size
	
	Make/O/N=(size,size,frames) NTSI:block
	
	Variable/G NTSI:isDynamicROI
	NVAR isDynamicROI = NTSI:isDynamicROI
	isDynamicROI = 1
	
	Variable/G NTSI:dynamicROI_MaxVal
	NVAR maxVal = NTSI:dynamicROI_MaxVal
	Variable/G NTSI:dynamicROI_MinVal
	NVAR minVal = NTSI:dynamicROI_MinVal
	maxVal = -5000
	minVal = 5000
	
	String/G NTSI:dynamicROI_Image
	SVAR dynamicROI_Image = NTSI:dynamicROI_Image
	dynamicROI_Image = GetWavesDataFolder(theImage,2)
	
	AppendToGraph/W=dynamicROI dROI
	SetAxis/W=dynamicROI left,0,maxVal
End

//Returns the currently selected scan folder
Function/S SelectedScanFolder()
	Wave/T listWave = root:Packages:NT:ScanImage:ScanFolderListWave
	ControlInfo/W=SI scanFolders
	return listWave[V_Value][0][0]
End

//Returns the currently selected scan groups
Function/S SelectedScanGroups()
	Wave/T listWave = root:Packages:NT:ScanImage:ScanGroupListWave
	Wave selWave = root:Packages:NT:ScanImage:ScanGroupSelWave
	
	Variable i
	String groups = ""
	For(i=0;i<DimSize(selWave,0);i+=1)
		If(selWave[i] > 0)
			groups += listWave[i][0][0] + ";"
		EndIf
	EndFor
	
	groups = RemoveEnding(groups,";") //extra semi-colon on the end
	return groups
End

//Returns the currently selected scan fields
Function/S SelectedScanFields([fullpath])
	Variable fullpath //returns full path to the scans, not just the names
	
	If(ParamIsDefault(fullpath))
		fullpath = 0
	Else
		fullpath = 1
	EndIf
	
	Wave/T listWave = root:Packages:NT:ScanImage:ScanFieldListWave
	Wave selWave = root:Packages:NT:ScanImage:ScanFieldSelWave
	
	Variable i
	String fields = ""
	For(i=0;i<DimSize(selWave,0);i+=1)
		If(selWave[i] > 0)
			If(fullpath)
				fields += listWave[i][0][1] + ";"
			Else
				fields += listWave[i][0][0] + ";"
			EndIf
		EndIf
	EndFor
	
	fields = RemoveEnding(fields,";") //extra semi-colon on the end
	return fields
End

//Returns a string list of matched items from the listWave or listString
Function/S matchScanFields(matchStr)
	String matchStr
	
	DFREF NTSI = root:Packages:NT:ScanImage
	
	If(!strlen(matchStr))
		matchStr = "*"
	EndIf
	
	//List and seletion waves in the SI panel
	Wave/T fieldList = NTSI:ScanFieldListWave
	Wave/T fieldSel = NTSI:ScanFieldSelWave
	
	String nameList = "",fullPathList = ""
	
	nameList = TextWaveToStringList(fieldList,";",layer=0)
	fullPathList = TextWaveToStringList(fieldList,";",layer=1)

	//Are there any OR statements in the match string?
	Variable i,j,numORs = ItemsInList(matchStr,"||")

	
	//Set empty temporary list
	String tempList = ""
	String indexList = ""
	
	//Match each OR element in the match string separately 
	For(j=0;j<numORs;j+=1)
		String matchItem = StringFromList(j,matchStr,"||")
		indexList += filterTable(matchItem,fieldList)
	EndFor
	
	//Delete items from the scanfield table in all layers
	For(i=DimSize(fieldList,0)-1;i>-1;i-=1) //go backwards
		Variable inList = WhichListItem(num2str(i),indexList,";")
		If(inList == -1)
			DeletePoints/M=0 i,1,fieldList
		EndIf
	EndFor
	
	Redimension/N=(DimSize(fieldList,0)) fieldSel
	Redimension/N=(DimSize(fieldList,0),1,2) fieldList
End

//returns names of the selected ROI Group in the Image Browser
Function/S SelectedROIGroup()
	String groupList = ""
	Wave selWave = root:Packages:NT:ScanImage:ROIGroupSelWave
	Wave/T listWave = root:Packages:NT:ScanImage:ROIGroupListWave
	
	Variable i
	For(i=0;i<DimSize(selWave,0);i+=1)
		If(selWave[i] > 0)
			groupList += listWave[i] + ";"
		EndIf
	EndFor
	
	return groupList
End

//returns names of the selected ROIs in the Image Browser
Function/S SelectedROIs([groups])
	Variable groups //1 to return the group assignment list
	
	groups = (ParamIsDefault(groups)) ? 0 : 1
	
	String roiList = ""
	Wave selWave = root:Packages:NT:ScanImage:ROISelWave
	Wave/T listWave = root:Packages:NT:ScanImage:ROIListWave
	
	Variable i
	For(i=0;i<DimSize(selWave,0);i+=1)
		If(selWave[i] > 0)
			If(groups)
				roiList += listWave[i][0][1] + ";"
			Else
				roiList += listWave[i][0][0] + ";"
			EndIf
		EndIf
	EndFor
	return roiList
End

//Creates a new ROI using marquee coordinates, returns a wave reference wave with the X and Y coordinate waves
Function/WAVE CreateROI(left,top,right,bottom,[group,baseName,autoName])
	Variable left,top,right,bottom
	String baseName,group
	Variable autoName
	
	If(ParamIsDefault(autoName))
		autoName = 0
	EndIf
	
	If(ParamIsDefault(group))
		group = "**NEW**"
	EndIf
	
	If(!DataFolderExists("root:Packages:NT:ScanImage:ROIs"))
		NewDataFolder root:Packages:NT:ScanImage:ROIs
	EndIf
	
	String software = whichImagingSoftware()
	
	strswitch(software)
		case "ScanImage":
			String roiFolder = "root:Packages:NT:ScanImage:ROIs:"
			break
		case "2PLSM":
			roiFolder = "root:twoP_ROIS:"
			break
	endswitch
	
	DFREF saveDF = GetDataFolderDFR()
	
	//If automatic naming is indicated or we're creating a new group
	If(autoName)
		If(!cmpstr(group,"**NEW**"))
			//Make a new ROI group
			group = UniqueName("Group",11,0)
			NewDataFolder $(roiFolder + group)
		EndIf
		
		DFREF NTR = $(roiFolder + group)
		
		//Make numerically named ROIs
		SetDataFolder NTR
		
		Variable index = 0
		Do
			If(!WaveExists($(roiFolder + group + ":" + baseName + "_" + num2str(index) + "_x")) && !WaveExists($(roiFolder + group + ":" + baseName + num2str(index) + "_y")))
				baseName +=  "_" + num2str(index)
				break
			EndIf
			index += 1
			
			If(index == 1000)
				Abort "Couldn't find an available ROI name"
			EndIf
		While(1)
		
	Else
		DFREF NTR = $(roiFolder + group)
		
		If(!DataFolderRefStatus(NTR))
			//If the ROI group doesn't actually exist for some reason, create one with that name
			NewDataFolder $(roiFolder + group)
			DFREF NTR = $(roiFolder + group)
		EndIf
	
		//Make ROI coordinates X and Y waves
		ControlInfo/W=SIDisplay#ROIPanel ROIname
		baseName = S_Value
		
		If(!strlen(S_Value))
			Abort "Must enter a name for the ROI"
			return $""
		EndIf
	EndIf
		
	If(WaveExists($(roiFolder + group + ":" + basename + "_x")) || WaveExists($(roiFolder + group + ":" + basename + "_y")))
		DoAlert/T="Overwrite ROI?" 1,"ROI already exists. Overwrite?"
		If(V_flag == 2) //clicked no
			return $""
		EndIf
	EndIf
	
	
	Make/O/N=5 NTR:$(baseName + "_x") /Wave = roiX
	Make/O/N=5 NTR:$(baseName + "_y") /Wave = roiY
	
	//Fill the ROI wave with the coordinates to form a rectangle
	roiX[0] = left //top left
	roiY[0] = top //top left
	
	roiX[1] = left //bottom left
	roiY[1] = bottom //bottom left
	
	roiX[2] = right //bottom right
	roiY[2] = bottom //bottom right
	
	roiX[3] = right //top right
	roiY[3] = top //top right
	
	roiX[4] = left //top left
	roiY[4] = top //top left
	
	Make/FREE/WAVE roiRefs
	roiRefs[0] = roiX
	roiRefs[1] = roiY
	
	SetDataFolder saveDF
	
	//Set the ROI Group Selector to the current group, in case ***NEW** group was created.
	//This will allow you to click-create ROIs in a NEW group without having to choose the group that
	//was just created. 
	DFREF NTSI = root:Packages:NT:ScanImage
	
	updateImageBrowserLists()
	refreshROIGroupList()
	
	SVAR ROIGroupList = NTSI:GroupList
	index = WhichListItem(group,ROIGroupList,";")
	
	If(index != -1)
		PopUpMenu roiGroupSelect,win=SIDisplay#ROIPanel,mode=index+1
		ControlUpdate/A
	EndIf
	
	return roiRefs
End


//Automatic detection of somas, creation of ROIs around them
Function FindSomas(theImage,roiName)
	Wave theImage
	String roiName
	
	If(!DataFolderExists("root:Packages:NT:ScanImage:ROIs"))
		NewDataFolder root:Packages:NT:ScanImage:ROIs
	EndIf
	
	DFREF NTSR = root:Packages:NT:ScanImage:ROIs
	
	DFREF saveDF = GetDataFolderDFR()
	
	SetDataFolder NTSR
	
	Variable i,j,k,m
	
	//Dimensions
	Variable rows = DimSize(theImage,0)
	Variable cols = DimSize(theImage,1)
	Variable frames = DimSize(theImage,2)
	
	//Makes max projection image
	If(frames > 0)
		MatrixOP/O/FREE maxProj = sumbeams(theImage)
		Redimension/S maxProj
		maxProj /= frames
		Wave temp = maxProj
	Else
		Duplicate/FREE theImage,temp
	EndIf
	
	//Large median filter of the temp image, to help smooth out dendrites to make the somas easier to detect
	MatrixFilter/N=3 median temp
	
	Variable blockSize = 25
	Variable repeatX = 4,repeatY = 4
	Variable shift = 5
	
	Variable sizeThreshold = 50 //used for deleting rogue pixel values around an ROI
	Variable areaThreshold = 50//ROI must have at least this many pixels in it to count
	
	Variable xSteps,ySteps
	
	xSteps = ceil(rows / blockSize)
	ySteps = ceil(cols / blockSize)
	
	Variable maxROIs = 50
	
	Make/O/N=(blockSize,blockSize) NTSR:block /Wave=block
	
	Make/O/FREE/N=(rows,cols,repeatX*repeatY)/U roiMask
	roiMask = 0
	
	Make/O/N=(rows,cols) NTSR:$roiName /Wave = outputMask
	outputMask = 0

	//bit masks for detecting ROI overlap using an XOR operation
	Make/O/FREE/B/N=(blockSize,blockSize) bitMask0,bitMask1
	
	Variable left=0,top=0,overShootX = 0,overShootY = 0,endX,endY
	Variable count = 0
	
	Variable roiCount = 1
	
	For(m=0;m<repeatX;m+=1)
		Variable offsetX = k * shift
		
		For(k=0;k<repeatY;k+=1)
			Variable offsetY = k * shift
			
			xSteps = ceil((rows - offsetX) / blockSize)
			For(i=0;i<xSteps;i+=1)
				left = i * blockSize + offsetX
				
				ySteps = ceil((cols - offsetY) / blockSize)
				
				For(j=0;j<ySteps;j+=1)
					top = j * blockSize + offsetY
					
					overShootX = left + blockSize - rows  
					If(overShootX > 0)
						endX = blockSize - overShootX - 1
					Else
						endX = blockSize - 1
					EndIf
					
					overShootY = top + blockSize - cols  
					If(overShootY > 0)
						endY = blockSize - overShootY - 1
					Else
						endY = blockSize - 1
					EndIf
					
					MultiThread block = 0
					MultiThread block[0,endX][0,endY] = temp[p + left][q + top]
					
					//Clear runtime any errors prior to the fit.
//					Variable error = GetRTError(1)
					
					try
						//Set the 'corr' coefficient to zero, does much better detecting circular ROIs, and not extending the fit over multiple somas.
						Variable K6 = 0
						CurveFit/M=2/W=2/Q/N=1/H="0000001" Gauss2D,block/D;AbortOnRTE
					catch
						Variable error = GetRTError(1)
						continue
					endtry
					
					Wave coef = W_coef
					
					Wave fit = fit_block
					
					Variable maxValThreshold = 0.04
					
					Variable maxVal = WaveMax(fit)
					Variable minVal = WaveMin(fit)
					Variable threshold = minVal + (0.15) * (maxVal - minVal) //thresholding step
					
					//Not a soma, too dim of a fit
					If(maxVal < maxValThreshold)
						continue
					EndIf
					
					try
						ImageInterpolate/RESL={blockSize,blockSize} Bilinear,fit;AbortOnRTE
					catch
						error = GetRTError(1)
						continue
					endtry
									
					Wave interpImage = M_InterpolatedImage
					MultiThread interpImage = (interpImage > threshold) ? roiCount : 0
					
					MatrixOP/O/FREE edgeX = maxRows(interpImage)
					MatrixOP/O/FREE edgeY = maxCols(interpImage)^t
					
					//soma is on the edge of the block, try to recenter
					If(edgeX[0] > 0 || edgeY[0] > 0 || edgeX[blockSize-1] > 0 || edgeY[blockSize-1] > 0)
						
						If(minVal < 1) //there is some structure here, try to re-center
							
							
							Variable centerX,centerY,shiftX,shiftY
							centerX = round(coef[2])//ScaleToIndex(theImage,coef[2],0)
							centerY = round(coef[4])//ScaleToIndex(theImage,coef[5],1)
							
							shiftX = left + round(centerX - 0.5 * blockSize)
							shiftY = top + round(centerY - 0.5 * blockSize)
							
							//on left or bottom edge, can't recenter
							If(shiftX < 0 || shiftY < 0)
								continue
							EndIf
							
							//Calculate overshoots
							overShootX = shiftX + blockSize - rows  
							If(overShootX > 0)
								endX = blockSize - overShootX - 1
							Else
								endX = blockSize - 1
							EndIf
							
							If(endX < 0)
								continue
							EndIf
							
							overShootY = shiftY + blockSize - cols  
							If(overShootY > 0)
								endY = blockSize - overShootY - 1
							Else
								endY = blockSize - 1
							EndIf
							
							If(endY < 0)
								continue
							EndIf
							
							//Get new block that is better centered
							MultiThread block = 0
							MultiThread block[0,endX][0,endY] = temp[p + shiftX][q + shiftY]
							
							//Fit the gaussian again
							try
								//Set the 'corr' coefficient to zero, does much better detecting circular ROIs, and not extending the fit over multiple somas.
								K6 = 0
								CurveFit/M=2/W=2/Q/N=1/H="0000001" Gauss2D,block/D;AbortOnRTE
							catch
								error = GetRTError(1)
								continue
							endtry
							
							maxVal = WaveMax(fit)
							minVal = WaveMin(fit)
							threshold = minVal + (0.15) * (maxVal - minVal) //thresholding step
							
							//Not a soma, too dim of a fit
							If(maxVal < maxValThreshold)
								continue
							EndIf
							
							try
								ImageInterpolate/RESL={blockSize,blockSize} Bilinear,fit;AbortOnRTE
							catch
								error = GetRTError(1)
								continue
							endtry
											
							Wave interpImage = M_InterpolatedImage
							MultiThread interpImage = (interpImage > threshold) ? roiCount : 0
							
							MatrixOP/O/FREE edgeX = maxRows(interpImage)
							MatrixOP/O/FREE edgeY = maxCols(interpImage)^t
							
							//soma is on the edge of the block, ignore this time through
							If(edgeX[0] > 0 || edgeY[0] > 0 || edgeX[blockSize-1] > 0 || edgeY[blockSize-1] > 0)
								continue
							EndIf
							
							Variable ratio = sum(interpImage) / WaveMax(interpImage)
							
							If(sum(interpImage) / WaveMax(interpImage) < areaThreshold)
								continue
							EndIf
							
							
							Variable y
							//Sum all ROI layers from the current block region to generate a bitmask
							For(y=0;y<DimSize(roiMask,2);y+=1)
								Multithread bitMask0[0,endX][0,endY][0] = roiMask[p + shiftX][q + shiftY][y]
						
								
								Multithread bitMask0 = (bitMask0) ? 1 : 0
								
								Redimension/B/U interpImage
								Multithread bitMask1 = (interpImage) ? 1 : 0
								//Bitmask detect overlap ROIs from previous block frame
								MatrixOP/O interpImage = bitXOR(bitMask1,bitMask0) * interpImage
							EndFor
							
							//Put the newly centered ROI into the mask wave
							Multithread roiMask[shiftX,shiftX + endX][shiftY,shiftY + endY][count] += interpImage[p-shiftX][q-shiftY][0]
																
						Else				
							continue
						EndIf
					Else
					
						If(sum(interpImage) / WaveMax(interpImage) < areaThreshold)
							continue
						EndIf
						
						
						//Sum all ROI layers from the current block region to generate a bitmask
						For(y=0;y<DimSize(roiMask,2);y+=1)
							Multithread bitMask0[0,endX][0,endY][0] = roiMask[p + left][q + top][y]
						
							Multithread bitMask0 = (bitMask0) ? 1 : 0
							
							Redimension/B/U interpImage
							Multithread bitMask1 = (interpImage) ? 1 : 0
							//Bitmask detect overlap ROIs from previous block frame
							MatrixOP/O interpImage = bitXOR(bitMask1,bitMask0) * interpImage
						EndFor
		
						//Put the new ROI into the mask wave
						Multithread roiMask[left,left + endX][top,top + endY][count] += interpImage[p-left][q-top][0]
					EndIf
					
					//Set assigned ROI pixels to 0, so we can detect less intense somas that are very close by on subsequent passes.
					Multithread temp = (roiMask[p][q][count] > 0) ? 0 : temp
					
					If(count > 0)
						Multithread roiMask[][][0,count-1] = (roiMask[p][q][count] > 0) ? 0 : roiMask[p][q][r]		
					EndIf
					
					roiCount += 1
					
					bitMask0 = bitMask1
				EndFor
				
			EndFor
			count += 1
			
		EndFor
	EndFor
	
	//sum together all the layers to get the final soma ROI mask
	MatrixOP/O outputMask = sumBeams(roiMask)
	
	
	//highest value ROI
	maxVal = WaveMax(outputMask)
	
	count = 10001 //set high to be above the largest possible ROI number
	Multithread outputMask = (outputMask == 0) ? 10000 : outputMask
	
	Make/O/N=(maxVal+1) hist
	Histogram/B={0,1,maxVal+1} outputMask,hist
	
	For(i=0;i<DimSize(hist,0);i+=1)
		If(hist[i] < areaThreshold)
			outputMask = (outputMask == i) ? 10000 : outputMask
		EndIf
	EndFor
	
	
	//find lowest ROI number
	minVal = WaveMin(outputMask)
	Do
		//set to the count
		Multithread outputMask = (outputMask == minVal) ? count : outputMask
		count += 1
		
		//safety check in case of runaway loop
		If(count > 10200)
			break
		EndIf
		
		minVal = WaveMin(outputMask)
	While(minVal != 10000)
	
	//reset ROI numbers from 1 to etc....
//	outputMask = (outputMask != 100000) ? outputMask - 10000 : outputMask - 100000
	outputMask -= 10000
		
	Variable numROIs = WaveMax(outputMask)
	Redimension/N=(-1,-1,numROIs+1) outputMask
	
	//Make a duplicate version with all ROIs in the same layer, for easier display purposes
	Make/O/N=(rows,cols) $(NameOfWave(outputMask) + "_flat")/Wave=flatROI //Single layer, 1's for every ROI
	Make/O/N=(rows,cols) $(NameOfWave(outputMask) + "_flatNum")/Wave=flatNumROI //Single layer, ROI # for every ROI
	
	flatROI[][][0] = outputMask[p][q][0]
	flatNumROI = flatROI
	CopyScales theImage,flatROI,flatNumROI,outputMask
	
	flatROI = (flatROI > 0) ? 1 : 0
	
	//Separates each ROI into it's own layer of the mask wave
	MatrixOP/FREE firstLayer = layer(outputMask,0)
	For(i=1;i<numROIs+1;i+=1)
		outputMask[][][i] = (firstLayer[p][q][0] == i) ? 1 : 0	
		
		//Takes care of lingering ROIs created from overlap regions
		MatrixOP/FREE layer = layer(outputMask,i)
		If(sum(layer) < areaThreshold)
			DeletePoints/M=2 i,1,outputMask
		EndIf
	EndFor
	
	DeletePoints/M=2 0,1,outputMask
	KillWaves/Z fit,interpImage,block,W_coef,W_sigma,M_covar,hist
	
	SetDataFolder saveDF
End

//Determines the number of subwindows in the window
Function getNumImages(windowNameStr,baseNameStr)
	String windowNameStr,baseNameStr
	Variable i
	
	i = 0
	Do
		String fullWinName = windowNameStr + "#" + baseNameStr + num2str(i)
		GetWindow/Z $fullWinName wsize //keyword doesn't matter, but need to reserve V_flag for existence or not
		i += 1
	While(!V_flag)
	
	
	return i - 1
End

//Append the ROIs in the list to the top image plot
Function appendROIsToImage(groupList,roiList)
	String groupList,roiList
	
	//If groupList or roiList are empty strings, just removes all ROIs
	
	DFREF NTSI = root:Packages:NT:ScanImage
	NVAR numImages = NTSI:numImages
	
	String software = whichImagingSoftware()
	
	numImages = getNumImages("SIDisplay","image")
	
	//Get name of selected graph window in the drop down menu
	ControlInfo/W=SI targetImage
	String graphName = S_Value
	
	//ROI color table wave
	Wave color = NTSI:ROI_ColorTable
	
	Variable i,j
	
	//Check it's SIDisplay or another image plot
	If(!cmpstr("SIDisplay",graphName))
		DoWindow SIDisplay
		
		If(V_flag == 0)
			return 0
		EndIf
		
		//in case of errors in image number
		If(numImages == 0)
			numImages = 1
		EndIf
		
		For(i=0;i<numImages;i+=1)
		
			String subpanel = "image" + num2str(i)
			String graph = "graph" + num2str(i)
			
			//First remove all ROI traces to clear the image graph
			String tracelist = TraceNameList("SIDisplay#" + subpanel + "#" + graph,";",1)
			For(j=ItemsInList(tracelist,";")-1;j>-1;j-=1) //step backwards
				RemoveFromGraph/W=SIDisplay#$subpanel#$graph/Z $StringFromList(j,tracelist,";")
			EndFor
			
			//First remove all ROI image masks to clear the image graph
			tracelist = ImageNameList("SIDisplay#" + subpanel + "#" + graph,";")
			For(j=ItemsInList(tracelist,";")-1;j>0;j-=1) //step backwards
				RemoveImage/Z/W=SIDisplay#$subpanel#$graph $StringFromList(j,tracelist,";")
			EndFor
			
			For(j=0;j<ItemsInList(roiList,";");j+=1)
				String roiName = StringFromList(j,roiList,";")
				String roiGroup = StringFromList(j,groupList,";")
				
				If(stringmatch(roiName,"*soma"))
					
					If(!cmpstr(software,"2PLSM"))
						If(strlen(roiGroup))
							Wave roiMask = $("root:twoP_ROIS:" + roiGroup + ":" + roiName + "_flatNum") //append the flattened ROI mask wave
						Else
							Wave roiMask = $("root:twoP_ROIS:" + roiName + "_flatNum") //append the flattened ROI mask wave
						EndIf
					Else
						Wave roiMask = $("root:Packages:NT:ScanImage:ROIs:" + roiGroup + ":" + roiName + "_flatNum") //append the flattened ROI mask wave
					EndIf
									
					If(!WaveExists(roiMask))
						continue
					EndIf
					
					Redimension/N=(WaveMax(roiMask) + 1,-1) color
					color[1,*][] = color[1][q]
					
					AppendImage/W=SIDisplay#$subpanel#$graph/L/T roiMask
					ModifyImage/W=SIDisplay#$subpanel#$graph $(roiName + "_flatNum") ctab= {0,DimSize(color,0),color,0}
					SetVariable selectROI win=SIDisplay#control,limits={1,DimSize(color,0)-1,1}
//					ModifyImage/W=SIDisplay#$subpanel#$graph $(roiName + "_flatNum") ctab= {0,0,Grays,0},minRGB=(0,43690,65535,16384),maxRGB=(0,43690,65535,16384)
				Else
					If(!cmpstr(software,"2PLSM"))
						If(strlen(roiGroup))
							Wave roiX = $("root:twoP_ROIS:" + roiGroup + ":" + roiName + "_x")
							Wave roiY = $("root:twoP_ROIS:" + roiGroup + ":" + roiName + "_y")
						Else
							Wave roiX = $("root:twoP_ROIS:" + roiName + "_x")
							Wave roiY = $("root:twoP_ROIS:" + roiName + "_y")
						EndIf
					Else
						Wave roiX = $("root:Packages:NT:ScanImage:ROIs:" + roiGroup + ":" + roiName + "_x")
						Wave roiY = $("root:Packages:NT:ScanImage:ROIs:" + roiGroup + ":" + roiName + "_y")
					EndIf
												
					If(!WaveExists(roiX) || !WaveExists(roiY))
						continue
					EndIf
					AppendToGraph/W=SIDisplay#$subpanel#$graph/L/T roiY vs roiX
				EndIf
			EndFor
			
		EndFor
		return 0
	Else
		String imageList = ImageNameList(graphName,";")
		If(!strlen(imageList))
			return 0
		EndIf
	EndIf
	
	//This runs if we're using a non-SIDisplay image plot
	/////////////////////////////////////////////////////
	
	//First remove all ROI traces to clear the image graph
	tracelist = TraceNameList(graphName,";",1)
	For(j=ItemsInList(tracelist,";")-1;j>-1;j-=1) //step backwards
		RemoveFromGraph/W=$graphName/Z $StringFromList(j,tracelist,";")
	EndFor

	Variable isSoma,numROIs
	String axisFlags="",info = "",hAxisName="",vAxisName=""
	
	numROIs = ItemsInList(roiList,";")
	For(i=0;i<numROIs;i+=1)
		 roiName = StringFromList(i,roiList,";")
		 roiGroup = StringFromList(i,groupList,";")
		
		If(!cmpstr(software,"2PLSM"))
			If(strlen(roiGroup))
				DFREF NTSR = root:twoP_ROIS:$roiGroup
			Else
				DFREF NTSR = root:twoP_ROIS
			EndIf
		Else
			DFREF NTSR = root:Packages:NT:ScanImage:ROIs:$roiGroup
		EndIf
		
		If(stringmatch(roiName,"*soma"))
			isSoma = 1
		Else
			isSoma = 0
		EndIf
		
		//what are the axes?
		info = ImageInfo("",StringFromList(0,imageList,";"),0)
		axisFlags = StringByKey("AXISFLAGS",info)
		hAxisName = StringByKey("XAXIS",info)
		vAxisName = StringByKey("YAXIS",info)
		
		If(isSoma)
			Wave roiWave = NTSR:$roiName
		
			strswitch(axisFlags)
				case "/T":
					AppendImage/W=$graphName/T=$hAxisName roiWave
					break
				case "/R":
					AppendImage/W=$graphName/R=$vAxisName roiWave
					break
				case "/T/R":
					AppendImage/W=$graphName/T=$hAxisName/R=$vAxisName roiWave
					break
			endswitch
			
			Else
				Wave xROI = NTSR:$(roiName + "_x")
				Wave yROI = NTSR:$(roiName + "_y")
				
				strswitch(axisFlags)
					case "/T":
						AppendToGraph/W=$graphName/T=$hAxisName yROI vs xROI
						break
					case "/R":
						AppendToGraph/W=$graphName/R=$vAxisName yROI vs xROI
						break
					case "/T/R":
						AppendToGraph/W=$graphName/T=$hAxisName/R=$vAxisName yROI vs xROI
						break
				endswitch	
		EndIf
	EndFor
End


//Get ROI ------------------------------------
Function/WAVE NT_GetROI(ds)
	STRUCT ds &ds
	
	STRUCT IMAGING img
	
	
	DFREF NTF = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	DFREF saveDF = GetDataFolderDFR()
	
	//Get the parameters from the GUI
	initParam(img,ds)
	
	//Make the ROI analysis folder if it doesn't already exist
	If(!DataFolderExists("root:Analysis"))
		NewDataFolder root:Analysis
	EndIf
	SetDataFolder root:Analysis	
	
	//Make the output wave reference wave for passing the result onto another function
	Make/FREE/WAVE/N=0 outputWaveRefs
	
	Variable i,j,k,totalWaveCount = 0

	//SCAN LOOP
	For(i=0;i<img.scan.num;i+=1)
		Variable ref = StartMSTimer
		
		switch(img.channel)
			case 1: //channel 1 only
				Wave theScan = img.scan.ch1[i] //signal fluorescence
				Wave theBgnd = img.scan.ch1[i] //background fluorescence
				break
			case 2: //channel 2 only
				Wave theScan = img.scan.ch2[i]
				Wave theBgnd = img.scan.ch2[i]
				break
			case 3: // ch1 / ch2
				Wave theScan = img.scan.ch1[i]
				Wave theBgnd = img.scan.ch2[i]
				break
			case 4: // ch2 / ch1
				Wave theScan = img.scan.ch2[i]
				Wave theBgnd = img.scan.ch1[i] 
				break
		endswitch

		//Get dendritic mask
		Wave mask = GetDendriticmask(theBgnd)
		Redimension/B/U mask
		
		//Get dark value
		ImageStats/R=mask theBgnd
		Variable darkVal = 0.9*V_avg
		
		//Cleanup
		KillWaves/Z mask,root:Analysis:maxProj
		
		//ROI LOOP
		For(j=0;j<img.roi.num;j+=1)
			String theROI = img.rois[j][0][0]
			String roiGroup = img.rois[j][0][1]
			
			//Make the ROI Group Analysis folder
			If(!DataFolderExists("root:Analysis:" + roiGroup))
				NewDataFolder $("root:Analysis:" + roiGroup)
			EndIf
			
			//Make the ROI analysis subfolder
			String ROIFolder = "root:Analysis:" + roiGroup + ":" + theROI
			
			If(!DataFolderExists(ROIFolder))
				NewDataFolder $ROIFolder
			EndIf
			
			//X and Y waves that define the ROI area
			Wave roiX = img.roi.x[j]
			Wave roiY  = img.roi.y[j]
			
			If(DimSize(roiX,1) > 0)
				Variable isSoma = 1
			Else
				isSoma = 0
			EndIf
			
			//Use somatic ROI map instead of the traditional boundary ROIs
			If(isSoma)
				SetDataFolder $ROIFolder
				NT_GetROI_Soma(roiX,theScan,theBgnd,img)
				SetDataFolder saveDF
				continue
			EndIf
			
			//Seed values for filling out the ROI mask
			Variable maskMax,maskMin,xSeed,ySeed
			WaveStats/Q theBgnd
			
			maskMin = WaveMin(roiX)
			maskMax = WaveMax(roiX)
			
			xSeed = maskMax + DimDelta(theBgnd,0)
			If(xSeed > IndexToScale(theBgnd,DimSize(theBgnd,0)-1,0))
				xSeed = IndexToScale(theBgnd,0,0)
			EndIf
			
			maskMin = WaveMin(roiY)
			maskMax = WaveMax(roiY)
			
			ySeed = maskMax + DimDelta(theBgnd,1)
			If(ySeed > IndexToScale(theBgnd,DimSize(theBgnd,1)-1,1))
				ySeed = IndexToScale(theBgnd,0,1)
			EndIf
			
			//ROI mask wave	
			SetDataFolder $ROIFolder			
			ImageBoundaryToMask ywave=roiY,xwave=roiX,width=(DimSize(theBgnd,0)),height=(DimSize(theBgnd,1)),scalingwave=theBgnd,seedx=xSeed,seedy=ySeed			
		
			Wave ROIMask = $(ROIFolder + ":M_ROIMask")	
			
			//Did the ROI mask actually get created?
			If(!WaveExists(ROIMask))
				DoAlert 0, "Couldn't find the ROI mask wave for: " + NameOfWave(theScan)
				continue
			EndIf
			
			//Make the raw ROI waves for signal and background
			Variable numFrames = DimSize(theScan,2)
			Make/O/FREE/N=(numFrames) ROI_Signal,ROI_Bgnd
			
			//Set all the scales of the ROI waves
			SetScale/P x,DimOffset(theScan,2),DimDelta(theScan,2),ROI_Signal,ROI_Bgnd
			
			//Average values over the ROI region
			For(k=0;k<numFrames;k+=1)
				ImageStats/M=1/P=(k)/R=ROImask theScan
				ROI_Signal[k] = V_avg
				
				ImageStats/M=1/P=(k)/R=ROImask theBgnd
				ROI_Bgnd[k] = V_avg
			EndFor		
			
			//Savitzky-Golay smoothing
			If(img.filter)
				Smooth/S=2 (img.filter), ROI_Signal,ROI_Bgnd
			EndIf
					
			//Use median for the baseline, so it doesn't get pulled up or down from noisy values
			Variable	bsln = median(ROI_Bgnd,img.bsSt,img.bsEnd)
			
			//Absolute fluorescence or delta fluorescence?
			If(img.mode == 1)
			//∆F/F
				String outName = NameOfWave(theScan) + "_" + theROI + "_dF"
			ElseIf(img.mode == 2)
			//Standard Deviation
			 	outName = NameOfWave(theScan) + "_" + theROI + "_sd"
			ElseIf(img.mode == 3)
			//Abs
				outName = NameOfWave(theScan) + "_" + theROI + "_abs"
			EndIf	
			
			//Make the dF or dG wave
			Make/O/N=(numFrames) $outName
			Wave dF = $outName
			
			//Set all the scales of the ROI waves
			SetScale/P x,DimOffset(theScan,2),DimDelta(theScan,2),dF
			
			//Calculate the ∆F/F or Absolute fluoresence ratios
			
			darkVal = 0
			
			If(img.mode == 1) //dF
				dF = (ROI_Signal - bsln) / (bsln - darkVal)
			ElseIf(img.mode == 2) //SD
				//baseline subtracted and dark subtracted signal
				dF = ROI_Signal - bsln - darkVal
				
				//get standard deviation of the baseline region
				WaveStats/Q/R=(img.bsSt,img.bsEnd) dF 
				
				//standard deviations above the median baseline value
				dF /= V_sdev
			ElseIf(img.mode == 3) //abs
				dF = ROI_Signal
			EndIf
			
			//Set the wave note with the original scan name
			Note dF,"Scan: " + GetWavesDataFolder(theScan,2)
						
			//These are all the output ROI waves
			Redimension/N=(totalWaveCount + 1) outputWaveRefs
			outputWaveRefs[totalWaveCount] = dF

			totalWaveCount += 1
		EndFor
		
		updateProgress(ds)
		print "Get ROI:",NameOfWave(theScan) + ",",StopMSTimer(ref) / (1e6),"s"
		
	EndFor
	
	SetDataFolder saveDF
		
	//pass the output wave on
	return outputWaveRefs
End

//Uses a 2 or 3D ROI map instead of traditional boundary ROIs
Function NT_GetROI_Soma(roi,theScan,theBgnd,img)
	Wave roi,theScan,theBgnd
	STRUCT IMAGING &img
	
	Variable i,j,k,numROIs = DimSize(roi,2)
	
	For(i=0;i<numROIs;i+=1)
		//Get the ROI mask in each layer in the map
		MatrixOP/O/FREE ROImask = layer(roi,i)
		
		Redimension/B/U ROImask
		
		//Get dark value
		ImageStats/R=ROImask theBgnd
		Variable darkVal = 0.9*V_avg
		
		//flip ROI
		ROImask = (ROImask == 0) ? 1 : 0
		
		String theROI = NameOfWave(roi) + "_" + num2str(i + 1)
		
		//Make the raw ROI waves for signal and background
		Variable numFrames = DimSize(theScan,2)
		Make/O/FREE/N=(numFrames) ROI_Signal,ROI_Bgnd
		
		//Set all the scales of the ROI waves
		SetScale/P x,DimOffset(theScan,2),DimDelta(theScan,2),ROI_Signal,ROI_Bgnd
		
		//Average values over the ROI region
		For(k=0;k<numFrames;k+=1)
			ImageStats/M=1/P=(k)/R=ROImask theScan
			ROI_Signal[k] = V_avg
			
			ImageStats/M=1/P=(k)/R=ROImask theBgnd
			ROI_Bgnd[k] = V_avg
		EndFor		
		
		//Savitzky-Golay smoothing
		If(img.filter)
			Smooth/S=2 (img.filter), ROI_Signal
		EndIf
				
		//Use median for the baseline, so it doesn't get pulled up or down from noisy values
		Variable	bsln = median(ROI_Bgnd,img.bsSt,img.bsEnd)
		
		//Absolute fluorescence or delta fluorescence?
		If(img.mode == 1)
		//∆F/F
			String outName = NameOfWave(theScan) + "_" + theROI + "_dF"
		ElseIf(img.mode == 2)
		//Abs
			outName = NameOfWave(theScan) + "_" + theROI + "_abs"
		EndIf	
		
		//Make the dF or dG wave
		Make/O/N=(numFrames) $outName
		Wave dF = $outName
		
		//Set all the scales of the ROI waves
		SetScale/P x,DimOffset(theScan,2),DimDelta(theScan,2),dF
		
		//Calculate the ∆F/F or Absolute fluoresence ratios
		If(img.mode == 1) //dF
			dF = (ROI_Signal - bsln) / (bsln - darkVal)
		ElseIf(img.mode == 2) //abs
			dF = ROI_Signal
		EndIf
		
		//Set the wave note with the original scan name
		Note dF,"Scan: " + GetWavesDataFolder(theScan,2)
	EndFor
End

//dF Map --------------------------------
//---------------------------------------
//Generates a pixel map of the peak ∆F/F or variant thereof
Function/WAVE NT_dFMap(ds)
	STRUCT ds &ds
	STRUCT IMAGING img //Imaging package data structure
	
	
	DFREF NTF = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	DFREF NTSI = root:Packages:NT:ScanImage
	
	//Initializes the structure that holds scan and ROI selection information
	initParam(img,ds)
	
	//Which scans are selected?
	Wave/T ScanListWave = NTSI:ScanListWave
	Wave ScanSelWave = NTSI:ScanSelWave
	
	Variable i,j,k,totalWaveCount = 0
	
	Variable rows,cols,frames
	
	For(i=0;i<img.scan.num;i+=1)
		Variable ref = StartMSTimer
		
		//Get the scan and background channels
		switch(img.channel)
			case 1: //channel 1 only
				Wave theScan = img.scan.ch1[i] //signal fluorescence
				Wave theBgnd = img.scan.ch1[i] //background fluorescence
				String suffix = "_dF"
				String type = "∆F/F" //for the wave note at the end
				break
			case 2: //channel 2 only
				Wave theScan = img.scan.ch2[i]
				Wave theBgnd = img.scan.ch2[i]
				suffix = "_dG"
				type = "∆F/F"
				break
			case 3: // ch1 / ch2
				Wave theScan = img.scan.ch1[i]
				Wave theBgnd = img.scan.ch2[i]
				suffix = "_dGR"
				type = "∆G/R"
				break
			case 4: // ch2 / ch1
				Wave theScan = img.scan.ch2[i]
				Wave theBgnd = img.scan.ch1[i] 
				suffix = "_dRG"
				type = "∆R/G"
				break
		endswitch
		
		strswitch(img.measure)
			case "Peak":
				String param = "_pk"
				break
			case "Peak Location":
				 param = "_loc"
				break
			case "Area":
				 param = "_area"
				break
			case "Area/Peak":
				 param = "_areaPk"
				break
			case "Peak/Area":
				param = "_pkArea"
				break
			default:
				img.measure = "Peak"
				param = "_pk"
		endswitch
		
		//Wave dimensions
		rows = DimSize(theScan,0)
		cols = DimSize(theScan,1)
		frames = DimSize(theScan,2)
		
		//Get the frame range for finding the peak dF
		Variable startLayer,endLayer,startBgndLayer,endBgndLayer
		startLayer = ScaleToIndex(theScan,img.pkSt,2)
		endLayer = ScaleToIndex(theScan,img.pkEnd,2)
		startBgndLayer = ScaleToIndex(theScan,img.bsSt,2)
		endBgndLayer = ScaleToIndex(theScan,img.bsEnd,2)
		
		
		//Make time-varying dF Map Wave
		SetDataFolder GetWavesDataFolder(theScan,1)
		Make/O/N=(rows,cols,frames) $(NameOfWave(theScan) + suffix)/Wave = dF
		Make/O/N=(rows,cols) $(NameOfWave(theScan) + suffix + param)/Wave = dFMeasure
		
		//Remove extreme fluorescence values
		Variable cleanNoiseThresh = 2
		
		//Don't use this for photon counting on the new rig.
		Wave theWave = CleanUpNoise(theScan,cleanNoiseThresh)	//threshold is in sdevs above the mean
		
		//Get dendritic mask
		Variable skip = 0
		
		If(!skip)
			Wave mask = GetDendriticMask(theBgnd)
			Redimension/B/U mask
				
			//Find average dark value
			ImageStats/R=mask/P=1 theScan
			Variable darkValue = 0.9 * V_avg  //estimate dark value slightly low to avoid it accidentally surpassing the dendrite baseline fluorescence.
		EndIf
					
		//Operate on temporary waves so raw data is never altered.
		Make/FREE/O/S/N=(rows,cols,frames) theScanTemp
		Make/FREE/O/S/N=(rows,cols,frames) theBgndTemp
		
		Multithread theScanTemp = theScan
		Multithread theBgndTemp = theBgnd
		
		//Spatial filter for each layer of the scan and bgnd channels.
		For(k=0;k<frames;k+=1)
			MatrixOP/O/FREE theLayer = layer(theScanTemp,k)
			MatrixFilter/N=(img.preFilter) gauss theLayer
			Multithread theScanTemp[][][k] = theLayer[p][q][0]
			
			MatrixOP/O/FREE theLayer = layer(theBgndTemp,k)
			MatrixFilter/N=(img.preFilter) gauss theLayer
			Multithread theBgndTemp[][][k] = theLayer[p][q][0]
		EndFor
		
		//Get baseline fluorescence maps
		Make/FREE/O/N=(rows,cols) scanBaseline,bgndBaseline
		Multithread scanBaseline = 0
			
		//Get the mean over the baseline region for the scan channel
		Make/O/FREE/N=(rows,cols,endBgndLayer - startBgndLayer) extractBsln
		extractBsln = theScanTemp[p][q][startBgndLayer+r]
		MatrixOP/O scanBaseline = sumBeams(extractBsln)
		Multithread scanBaseline /= (endBgndLayer - startBgndLayer)

		//photon counting is so sparse, set to zero 
//		Multithread scanBaseline = 0
				
		//Get the mean over the baseline region for the background channel
		extractBsln = theBgndTemp[p][q][startBgndLayer+r]
		MatrixOP/O/FREE bgndBaseline = sumBeams(extractBsln)
		Multithread bgndBaseline /= (endBgndLayer - startBgndLayer)
	
		Redimension/S bgndBaseline,scanBaseline
		
		//photon counting is so sparse, set to zero 
//		Multithread bgndBaseline = 0
		
		
		//Eliminates the possibility of zero values in the dataset for dendrites in the mask, which all get converted to NaN at the end.
		Multithread theScanTemp = (theScanTemp[p][q][r] == scanBaseline[p][q][0]) ? theScanTemp[p][q][r] + 1 : theScanTemp[p][q][r]
		
		//Calculate the ∆F map
		MultiThread dF = (theScanTemp[p][q][r] - scanBaseline[p][q][0]) / (bgndBaseline[p][q][0])
		
		CopyScales/I theScan,dF
				
		//Smooth the volume in the Z direction
//		Smooth/S=2/DIM=2 img.filter,dF
		
		//Extract the peak values
		MatrixOP/O/FREE vol = transposeVol(dF,1) //row x frame x col
		
		For(j=0;j<cols;j+=1) //col is z axis now
			MatrixOP/O/FREE theLayer = layer(vol,j)
			MatrixOP/O/FREE pk = maxRows(theLayer)
			 
			Multithread dFMeasure[][j] = pk[p]
		EndFor
		
		
		//Calculate the specified ∆F map measurement
		For(j=0;j<rows;j+=1)
			For(k=0;k<cols;k+=1)
							
				//only operates if the data is within the mask region to save time.
				If(mask[j][k] != 1)
					continue
				EndIf
				
				//Get the beam for each x/y pixel
				MatrixOP/FREE/O/S theBeam = Beam(dF,j,k)
				
				Variable bgnd = bgndBaseline[j][k]
				
				SetScale/P x,DimOffset(dF,2),DimDelta(dF,2),theBeam
				
				//Smooths the beam as an integer and single float.
				//The integer version will result in zero if the photon events were sparse in time
				//Convert the integer smoothing to a binary mask, and apply to the single float smooth version
				Duplicate/FREE theBeam,theBeamW
				Redimension/W theBeamW

				Smooth/S=2/DIM=0 img.filter,theBeam
//				Smooth/S=2/DIM=0 img.filter,theBeamW
//				theBeamW = (theBeamW) ? 1 : 0
//				
//				theBeam *= theBeamW
	
				Multithread dF[j][k][] = theBeam[r]
				WaveStats/Q/R=(img.pkSt,img.pkEnd) theBeam
				
				strswitch(img.measure)
					case "Peak":
						Multithread dFMeasure[j][k] = V_max
						break
					case "Peak Location":
						Multithread dFMeasure[j][k] = V_maxLoc
						break
					case "Mean":
						Multithread dFMeasure[j][k] = V_avg
						break
					case "Median":
						Multithread dFMeasure[j][k] = median(theBeam,img.pkSt,img.pkEnd)
						break
					case "Area":
						Multithread dFMeasure[j][k] = area(theBeam,img.pkSt,img.pkEnd)
						break
					case "Area/Peak":
						Multithread dFMeasure[j][k] = area(theBeam,img.pkSt,img.pkEnd) / V_max
						break
					case "Peak/Area":
						Multithread dFMeasure[j][k] = V_max / area(theBeam,img.pkSt,img.pkEnd)
						break
				endswitch		
			EndFor
		EndFor
		
		CopyScales/I theScan,dFMeasure
		
		//Masking and final filtering
		MatrixFilter/N=(3)/R=mask median dF
		
		MatrixFilter/N=(3)/R=mask median dFMeasure
		
		If(!skip)
			Multithread dFMeasure *= mask[p][q]
		EndIf
		
		Multithread dFMeasure = (mask) ? dFMeasure : nan
		
		Variable m
		For(m=0;m<1;m+=1)
			If(m)
				Wave notedWave = dF
			Else
				Wave notedWave = dFMeasure
			EndIf
			
			Note/K notedWave,"TYPE:" + type
			Note notedWave,"MEASURE:" + img.measure
			Note notedWave,"BSL_START:" + num2str(img.bsSt)
			Note notedWave,"BSL_END:" + num2str(img.bsEnd)
			Note notedWave,"PK_START:" + num2str(img.pkSt)
			Note notedWave,"PK_END:" + num2str(img.pkEnd)
			Note notedWave,"SMOOTH:" + num2str(img.filter)
			Note notedWave,"PRE-SPATIAL:" + num2str(img.preFilter)
			Note notedWave,"POST-SPATIAL:" + num2str(img.postFilter)
			Note notedWave,"MASK:" + GetWavesDataFolder(mask,2)
		EndFor
		
		
		updateProgress(ds)
		
		print "∆F Map (" + img.measure + "):",NameofWave(theScan) + " in",StopMSTimer(ref) / (1e6),"s"
	EndFor
	
End

//Uses a series of 2D image waves (e.g. peak ∆F/F maps) to compute the vector sum...
//...angle, DSI, and resultant maps.
Function NT_VectorSumMap(ds,angles)
	STRUCT ds &ds
	String angles
	
	DFREF saveDF = GetDataFolderDFR()
	
	Wave theWave = ds.waves[0]
	
	Variable rows,cols,theAngle
	
	//Dimensions
	rows = DimSize(theWave,0)
	cols = DimSize(theWave,1)

	//Make the operating waves for the vector sum
	Make/O/FREE/N=(rows,cols) vSumX,vSumY,totalSignal
	
	//Make output vector angle wave
	String outWaveName = GetWavesDataFolder(theWave,2) + "_vAng"
	Make/O/N=(rows,cols) $outWaveName
	Wave vAngle = $outWaveName
	vAngle = 0
	
	//Make output vector DSI wave
	outWaveName = GetWavesDataFolder(theWave,2) + "_vDSI"
	Make/O/N=(rows,cols) $outWaveName
	Wave vDSI = $outWaveName
	vDSI = 0
	
	//Make output vector Resultant wave
	outWaveName = GetWavesDataFolder(theWave,2) + "_vTotal"
	Make/O/N=(rows,cols) $outWaveName
	Wave vTotal = $outWaveName
	vTotal = 0
	
	//Make a histogram of the output pixels
	String histName = GetWavesDataFolder(theWave,2) + "_vHist"
	Make/O/N=24 $histName /Wave=vHist
	
	//Set scales
	SetScale/P x,DimOffset(theWave,0),DimDelta(theWave,0),vSumX,vSumY,totalSignal,vAngle,vDSI,vTotal
	SetScale/P y,DimOffset(theWave,1),DimDelta(theWave,1),vSumX,vSumY,totalSignal,vAngle,vDSI,vTotal

	//reset wsi
	ds.wsi = 0
	Do
		Wave theWave = ds.waves[ds.wsi]
		
		theAngle = str2num(StringFromList(ds.wsi,angles,";"))
		
		vSumX += theWave * cos(theAngle * pi/180)
		vSumY += theWave * sin(theAngle * pi/180)
		totalSignal += theWave
		
		updateProgress(ds)
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves)
	
	Multithread vAngle = atan2(vSumY,vSumX) * 180/pi
	Multithread vAngle = (vAngle[p][q] < 0) ? vAngle[p][q] + 360 : vAngle[p][q]
	
	//change zeros, so the mask can be applied
	Multithread vAngle = (theWave == 0) ? nan : vAngle
	
	//Mask the output wave
////	Wave mask = GetDendriticMask(vAngle)
////	
////	Multithread vAngle *= mask
////	Multithread vAngle = (vAngle == 0) ? nan : vAngle
//	
//	//put the zeros back after applying mask
//	Multithread vAngle = (vAngle == -1) ? 0 : vAngle
	
	//Make a histogram of the image values
	Histogram/C/B={0,15,24} vAngle,vHist
	
	Make/N=(rows,cols)/FREE vRadius
	Multithread vRadius = sqrt(vSumX^2 + vSumY^2)
	Multithread vDSI = vRadius / totalSignal
	Multithread vTotal = totalSignal
	
//	Duplicate/O vDSI,vDSI_noFilter
	
//	MatrixFilter/N=(3) median vAngle
//	MatrixFilter/N=(3) median vDSI
//	MatrixFilter/N=(5) median vTotal
	
//	vDSI *= vDSI
	
	SetDataFolder saveDF
End

//Input is peak dF maps, angle list
Function NT_FindDSCells(ds,angles)
	STRUCT ds &ds
	String angles
	
	DFREF saveDF = GetDataFolderDFR()
	
	Wave theWave = ds.waves[0]
	
	Variable rows,cols,theAngle,i
	
	//Dimensions
	rows = DimSize(theWave,0)
	cols = DimSize(theWave,1)
	
	//Put all the data into a single 3D wave
	Make/O/N=(rows,cols,ds.numWaves) data
	
	
	//Sort the images into the linear order according to their angle
	Variable done = 0
	Make/FREE/N=(ItemsInList(angles,";")) order,angleWave
	order = x
	
	Wave/T angleText = StringListToTextWave(angles,";")
	
	angleWave = str2num(angleText)
	
	Sort angleWave,order
	ds.wsi = 0
	
	For(i=0;i<ds.numWaves;i+=1)
		Wave image = ds.waves[order[i]]
		data[][][i] = image[p][q][0]
	EndFor
	
	//Once in a sorted 3D wave, each beam is a tuning curve
	
	//Make some template tuning curves for correlating the beams
	Make/FREE/N=(8) tune_0,tune_45,tune_90,tune_135,tune_180,tune_225,tune_270
	SetScale/P x,0,45,tune_0,tune_45,tune_90,tune_135,tune_180,tune_225,tune_270
	tune_0 = 0.5 + 0.5 * sin(x * pi/180)
//	tune_45 = 0.5 + 0.5 * sin((z-45) * pi/180)
//	tune_90 = 0.5 + 0.5 * sin((z-90) * pi/180)
//	tune_135 = 0.5 + 0.5 * sin((z-135) * pi/180)
//	tune_180 = 0.5 + 0.5 * sin((z-180) * pi/180)
//	tune_225 = 0.5 + 0.5 * sin((z-225) * pi/180)
//	tune_270 = 0.5 + 0.5 * sin((z-270) * pi/180)
	
//	Duplicate/O data,conv
	MatrixOP/FREE vol = transposeVol(data,2)
	Convolve/A tune_0,vol
	Redimension/N=(DimSize(tune_0,0),rows,cols) vol
	MatrixOP/O conv = transposeVol(vol,4)
	Redimension/N=(rows,cols) conv
	
	CopyScales/P image,conv
	
	SetDataFolder saveDF
End

//Gets the max projection of the image
//Function NT_MaxProject(ds)
	STRUCT ds &ds
	
	DFREF saveDF = GetDataFolderDFR()
	
	//reset wsi
	ds.wsi = 0
	Do
		Wave theWave = ds.waves[ds.wsi]
		SetDataFolder $GetWavesDataFolder(theWave,1)
		
		String outName = NameOfWave(theWave) + "_max"
		Make/O/N=(DimSize(theWave,0),DimSize(theWave,1)) $outName /Wave=maxproj
		
		MatrixOP/O maxproj = sumbeams(theWave)
		Redimension/S maxproj
		maxproj /= DimSize(theWave,2)
		
		CopyScales/I theWave,maxproj
		ds.wsi += 1
	While(ds.wsi < ds.numWaves)
	
	SetDataFolder saveDF
End

//Calculates the Max Projection of the 3D input wave
Function/WAVE NT_MaxProject(w)
	Wave w
		
	DFREF saveDF = GetDataFolderDFR()
	SetDataFolder $GetWavesDataFolder(w,1)
		
	String outName = NameOfWave(w) + "_max"
	Make/O/N=(DimSize(w,0),DimSize(w,1)) $outName /Wave=maxproj
	
	MatrixOP/O maxproj = sumbeams(w)
	Redimension/S maxproj
	maxproj /= DimSize(w,2)
	
	CopyScales/I w,maxproj
	
	SetDataFolder saveDF
	
	//return the output wave
	return maxProj
End

//Wrapper function to setup the max projection parameters
Function WRAPPER_MaxProject(ds)
	STRUCT ds &ds
	
	DFREF saveDF = GetDataFolderDFR()
	
	//reset wsi
	ds.wsi = 0
	Do
		Wave theWave = ds.waves[ds.wsi]
		SetDataFolder $GetWavesDataFolder(theWave,1)
		
		NT_MaxProject(theWave)
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves)
	
	SetDataFolder saveDF
End


//Calculates the response quality index for the input images
Function NT_ResponseQuality(ds)
	STRUCT ds &ds
	DFREF saveDF = GetDataFolderDFR()
	
	//Get the parameters from the GUI
	STRUCT IMAGING img
	initParam(img,ds)
	
	ds.wsi = 0
	Do
		//Get the wave
		Wave w = ds.waves[ds.wsi]
		SetDataFolder $GetWavesDataFolder(w,1)
		
		//Make the output wave
		String outName = NameOfWave(w) + "_RQI"
		Make/O/N=(DimSize(w,0),DimSize(w,1)) $outName /Wave=RQI
		
		Variable i,rows,cols,layers 
		rows = DimSize(w,0)
		cols = DimSize(w,1)
		layers = DimSize(w,2)
		
		//Calculate mean and standard deviation across frames
		Variable startLayer,endLayer,numLayers
		startLayer = ScaleToIndex(w,img.bsSt,2)
		endLayer = ScaleToIndex(w,img.bsEnd,2)
		numLayers = endLayer - startLayer + 1
		
		Make/FREE/N=(rows,cols,numLayers) baseline
		Multithread baseline = w[p][q][startLayer + r]
		
		ImageTransform averageImage baseline
		Wave avg = M_AveImage
		Wave sd = M_StdvImage
		
		//Calculate the pk value in each pixel over frames
		Make/N=(rows,cols)/FREE pk
		Multithread pk = 0
		
		startLayer = ScaleToIndex(w,img.pkSt,2)
		endLayer = ScaleToIndex(w,img.pkEnd,2)
		
		For(i=startLayer;i<endLayer+1;i+=1)
			Multithread pk = (w[p][q][i] > pk) ? w[p][q][i] : pk
		EndFor
		
		//Calculate Response Quality Index
		Multithread RQI = (pk - (avg + 2 * sd)) / (pk + (avg + 2 * sd))
		RQI = (RQI > 0.6) ? 1 : 0
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves)
	
	SetDataFolder saveDF
End

//Creates an ROI of
Function CreateROIFromClick(mh,mv,width,height,target,group,baseName)
	Variable mh,mv,width,height
	String target,group,baseName
	
	String imageName = StringFromList(0,ImageNameList(target,";"),";")
	String info = ImageInfo(target,imageName,0)
	String xAxis = StringByKey("XAXIS",info,":",";")
	String yAxis = StringByKey("YAXIS",info,":",";")
	
	Variable xCenter = AxisValFromPixel(target,xAxis,mh)
	Variable yCenter = AxisValFromPixel(target,yAxis,mv)
	
	Wave image = ImageNameToWaveRef(target,imageName)
	Variable left = xCenter - (DimDelta(image,0) * width * 0.5)
	Variable top  = yCenter - (DimDelta(image,1) * height * 0.5)
	Variable right = xCenter + (DimDelta(image,0) * width * 0.5)
	Variable bottom  = yCenter + (DimDelta(image,1) * height * 0.5)
	
	Wave/WAVE roiRefs = CreateROI(left,top,right,bottom,group=group,baseName=baseName,autoname=1)
	
	AppendToGraph/W=$target/T=$xAxis/L=$yAxis roiRefs[1] vs roiRefs[0]
	
	//Update lists
	updateImageBrowserLists()
	refreshROIGroupList()
End


//Returns a mask wave for the input scan
Function/WAVE GetDendriticMask(theWave)
	Wave theWave
	
	//Get max projection image
	MatrixOP/S/O maxProj = sumBeams(theWave)
//	ImageStats maxProj
	
	Variable rows,cols,frames,i,j
	
	rows = DimSize(theWave,0)
	cols = DimSize(theWave,1)
	frames = DimSize(theWave,2)
	
	Redimension/S maxProj
	Multithread maxProj /= DimSize(theWave,2)
	
	Make/FREE/N=(DimSize(theWave,0),DimSize(theWave,1)) varMap
	varMap = 0


	For(i=0;i<frames;i+=1)
		MultiThread varMap += (maxProj - theWave[p][q][i])^2
	EndFor
	
	MultiThread varMap /= (frames - 1)	
	
	
//	Redimension/S maxProj
	
	ImageStats varMap
		
	//Min/max of the image
	Variable minVal = V_min
	Variable maxVal = V_max
	
	//Simple value thresholding based on those values
	Variable threshold = minVal + (maxVal - minVal) * 0.03//1.25 is a mask threshold and can be changed
	Multithread varMap = (varMap < threshold) ? 0 : maxProj
	
	//Eliminate isolated points
	Make/FREE/N=(5,5) block
	block = 0
	
	
	
	For(i=0;i<rows;i+=1)	
		For(j=0;j<cols;j+=1)
			//skip zeros
			If(varMap[i][j] == 0)
				continue
			EndIf			
	
			//check for image edges
			If(i-2 < 0 || i+2 > rows-2 || j-2 < 0 || j+2 > cols-2)
				continue
			Else
				//Get data block surrounding point
				block = varMap[i-2 + p][j-2 + q]
				
				//Check for isolated point
				If(sum(block) < 3*varMap[i][j])
					varMap[i][j] = 0
				EndIf	
			EndIf
		
			block = 0
		EndFor
	EndFor
	
	//2D median filter 3x3
	MatrixFilter/N=3 median varMap
	
	//Create mask wave
	String maskName = NameOfWave(theWave) + "_mask"
	If(strlen(maskName) > 31)
		maskName = "Scan_mask"
	EndIf
	
	Make/O/N=(rows,cols) theMask
	MultiThread theMask = (varMap == 0) ? 0 : 1
	
	//Scaling
	SetScale/P x,DimOffset(theWave,0),DimDelta(theWave,0),theMask
	SetScale/P y,DimOffset(theWave,1),DimDelta(theWave,1),theMask
	
	return theMask
End

//Replaces extreme fluorescence values with the mean.
Function/WAVE CleanUpNoise(theWave,threshold)
	Wave theWave
	Variable threshold
	Variable i,j,rows,cols,frames
	
	//Get dimensions
	rows = DimSize(theWave,0)
	cols = DimSize(theWave,1)
	frames = DimSize(theWave,2)
	
	//First make a variance map
   Make/FREE/S/N=(rows,cols,0) varMap
	varMap = 0
	
	//Calculate variance across frames
	MatrixOP/FREE/O theMean = sumBeams(theWave)
	MultiThread theMean /= frames
	
	For(i=0;i<frames;i+=1)
		MultiThread varMap += (theWave[p][q][i] - theMean[p][q])^2
	EndFor
				
	MultiThread varMap /= (frames - 1)	
	MultiThread varMap = sqrt(varMap)
				
	//Use the variance map to identify pixels that have large outlier values
	Duplicate/FREE theWave,theWaveNoise
				
	For(j=0;j<frames;j+=1)
		MatrixOP/FREE theLayer = layer(theWave,j)
		MultiThread theWaveNoise[][][j] = (theLayer[p][q][0] > theMean[p][q][0] + threshold*varMap[p][q][0]) ? theMean[p][q][0] : theLayer[p][q][0]
	EndFor

	return theWaveNoise	
End

//Population Vector Sum
////////////////////////////////
Function NT_PopVectorSum()
	
	//Get the signals data set
	ControlInfo/W=NT Signals
	Wave/T signals_ds = GetDataSetWave(S_Value,"ORG")
	
	//Get the preferred angles data set
	ControlInfo/W=NT PrefAngles
	Wave/T prefAngles_ds = GetDataSetWave(S_Value,"ORG")
	
	//Get the tuning curves data set
	ControlInfo/W=NT TuningCurves
	Wave/T tuningCurves_ds = GetDataSetWave(S_Value,"ORG")
	
	//Differentiate or not?
	ControlInfo/W=NT differentiateCheck
	Variable differential = V_Value
	
	Variable i,j,numWaveSets,numWaves
	
	numWaveSets = GetNumWaveSets(signals_ds)
	
	For(i=0;i<numWaveSets;i+=1)
		//Get the wave set
		Wave/T signals_ws = GetWaveSet(signals_ds,i)
	
		//Get the preferred angles wave set
		Wave/T prefAngles_ws = GetWaveSet(prefAngles_ds,0)
		
		//Get the preferred angles wave, should be only wave in the wave set
		Wave pd = $prefAngles_ws[0][0][1]
		
		//Get the tuning curves wave sets
		Wave/T tuningCurves_ws = GetWaveSet(tuningCurves_ds,0)
		
		SetDataFolder GetWavesDataFolder($signals_ws[0][0][1],1)
		
		//Make the output vector angle wave for this wave set
		String outputName = NameOfWave($signals_ws[0][0][1]) + "_vAng"
		Make/O/N=(DimSize($signals_ws[0][0][1],0)) $outputName /Wave = vAngle
		
		//Make the output vector DSI wave for this wave set
		outputName = NameOfWave($signals_ws[0][0][1]) + "_vDSI"
		Make/O/N=(DimSize($signals_ws[0][0][1],0)) $outputName /Wave = vDSI
		
		//Make the output vector Total wave for this wave set (total summed signal)
		outputName = NameOfWave($signals_ws[0][0][1]) + "_vTotal"
		Make/O/N=(DimSize($signals_ws[0][0][1],0)) $outputName /Wave = vTotal
		
		Make/FREE/N=(DimSize($signals_ws[0][0][1],0)) sumX,sumY,radius
		
		sumX = 0
		sumY = 0
		vTotal = 0
		radius = 0
		
		numWaves = DimSize(signals_ws,0)
		
		//Get the max values of each tuning curve for normalization of the Signals data
		Variable peakResponse
		
		For(j=0;j<numWaves;j+=1)
			Wave signalWave = $signals_ws[j][0][1]
			Wave tuningWave = $tuningCurves_ws[j][0][1]
			
			//Used as a normalization factor, to make all neurons equal contributors to the vector sum
			peakResponse = WaveMax(tuningWave)
			
			If(differential)
				Differentiate signalWave /D=signal
				signal = (signal < 0) ? 0 : signal
			Else
				Duplicate/FREE signalWave,signal
			EndIf
			
			sumX += (signal / peakResponse) * cos(pd[j] * pi/180)
			sumY += (signal / peakResponse) * sin(pd[j] * pi/180)
			vTotal += (signal / peakResponse)
		EndFor
		
		radius = sqrt(sumX^2 + sumY^2)
		vAngle = atan2(sumY,sumX) * 180/pi
		vDSI = radius / vTotal
		
		vAngle = (vAngle < 0) ? vAngle + 360 : vAngle
		SetScale/P x,DimOffset(signalWave,0),DimDelta(signalWave,0),vTotal,vAngle,vDSI
	EndFor
	
	
End

Function NT_OLE()

	DFREF NTSR = root:Packages:NT:ScanImage:ROIs
	
	//Get the signals data set
	ControlInfo/W=NT Signals
	Wave/T signals_ds = GetDataSetWave(S_Value,"ORG")
	
	//Get the preferred angles data set
	ControlInfo/W=NT PrefAngles
	Wave/T prefAngles_ds = GetDataSetWave(S_Value,"ORG")
	
	//Get the radii from the vector sum data set
	ControlInfo/W=NT VectorRadii
	Wave/T radii_ds = GetDataSetWave(S_Value,"ORG")
	
	//Get the tuning curves data set
	ControlInfo/W=NT TuningCurves
	Wave/T tuningCurves_ds = GetDataSetWave(S_Value,"ORG")
	
	Variable i,j,k,numWaveSets,numWaves,delta
	
	numWaveSets = GetNumWaveSets(signals_ds)
	
	For(i=0;i<numWaveSets;i+=1)
		//Get the wave set
		Wave/T signals_ws = GetWaveSet(signals_ds,i)
	
		//Get the preferred angles wave set
		Wave/T prefAngles_ws = GetWaveSet(prefAngles_ds,0)
		
		//Get the preferred angles wave, should be only wave in the wave set
		Wave pd = $prefAngles_ws[0][0][1]
		
		//Get the vector radius wave set
		Wave/T radii_ws = GetWaveSet(radii_ds,0)
		
		//Get the vector radius wave, should be only wave in the wave set
		Wave radii = $radii_ws[0][0][1]
		
		//Get the tuning curves wave sets
		Wave/T tuningCurves_ws = GetWaveSet(tuningCurves_ds,0)
		
		SetDataFolder GetWavesDataFolder($signals_ws[0][0][1],1)
		
		numWaves = DimSize(signals_ws,0)
		
		//Make the inverse correlation matrix
		Make/O/N=(numWaves,numWaves)/FREE Qmatrix
		Qmatrix = 0
		
		//Make the output vector angle wave for this wave set
		String outputName = NameOfWave($signals_ws[0][0][1]) + "_OLE_vAng"
		Make/O/N=(DimSize($signals_ws[0][0][1],0)) $outputName /Wave = vAngle
		
		//Make the output vector DSI wave for this wave set
		outputName = NameOfWave($signals_ws[0][0][1]) + "_OLE_vDSI"
		Make/O/N=(DimSize($signals_ws[0][0][1],0)) $outputName /Wave = vDSI
		
		//Make the output vector Total wave for this wave set (total summed signal)
		outputName = NameOfWave($signals_ws[0][0][1]) + "_OLE_vTotal"
		Make/O/N=(DimSize($signals_ws[0][0][1],0)) $outputName /Wave = vTotal
		
		Make/FREE/N=(DimSize($signals_ws[0][0][1],0)) sumX,sumY,radius
		
		sumX = 0
		sumY = 0
		vTotal = 0
		radius = 0
		Make/O/N=(numWaves) dVector_Record
		Wave record = dVector_Record
		
		For(j=0;j<numWaves;j+=1)
			Wave signalWave = $signals_ws[j][0][1]
			Wave f1 = $tuningCurves_ws[j][0][1]
			SetScale/P x,0,45,f1
			
			//Make dVector wave to hold angle and radius data. Radius will be scaled by the correlation matrix
			Make/O/N=(1,2)/FREE dVector
			dVector[0][0] = 0	//starts radius of dVector at zero, it will be scaled by Qmatrix later
			dVector[0][1] = pd[j]	//puts vector sum angle into dVector
			
			For(k=0;k<numWaves;k+=1)
				//Center of mass vectors will be the average vector sums, which I've already calculated.
		
				//Calculate the inverse correlation matrix. This is our weighting factor for the center of mass
				//vectors. Once COM vectors are scaled by the correlation matrices, a normal vector sum is used on the
				//actual scan data.
	
				//Get second tuning curve
				Wave f2 = $tuningCurves_ws[k][0][1]
				SetScale/P x,0,45,f2
				
				Make/FREE/N=(DimSize(f1,0)) product
				SetScale/P x,DimOffset(f1,0),DimDelta(f1,0),product
				product = f1*f2
				
				If(j != k)
					WaveStats/Q f1
					delta = 1
				Else
					delta = 0
				EndIf
				
				Qmatrix[j][k] = delta*V_sdev^2 + area(product)
				//Scale dVector wave by inverse correlation matrix
				dVector[0] += (1/Qmatrix[j][k]) * radii[j]
			EndFor
			
			record[j] = dVector[0]
			//Compute vector sum of dVector and the scan data
			sumX += signalWave * dVector[0][0] * cos(dVector[0][1]*pi/180)
			sumY += signalWave * dVector[0][0] * sin(dVector[0][1]*pi/180)
			vTotal += signalWave * dVector[0][0]
		EndFor
		
		radius = sqrt(sumX^2 + sumY^2)
		vAngle = atan2(sumY,sumX) * 180/pi
		vDSI = radius / vTotal
		vAngle = (vAngle < 0) ? vAngle + 360 : vAngle
		SetScale/P x,DimOffset(signalWave,0),DimDelta(signalWave,0),vTotal,vAngle,vDSI
	EndFor
	/////////////////////////////////////
End
	
//	String scanList,ROIList,actualAngles
//	//actualAngles must be a comma separated list of angles in quotations.
//	Variable i,j,k,delta
//	String ROIfolder,tuningCurveName
//	
//	//Make correlation matrix wave
//	If(!DataFolderExists("root:ROI_analysis:multiROI"))
//		NewDataFolder root:ROI_analysis:multiROI
//	EndIf
//	SetDataFolder root:ROI_analysis:multiROI
//	Variable numROIs = ItemsInList(ROIList,";")
//	Make/O/N=(numROIs,numROIs) Qmatrix
//	Wave Qmatrix = Qmatrix
//	Qmatrix = 0
//
// For(k=0;k<ItemsInList(scanList,";");k+=1)
//	
//	For(i=0;i<ItemsInList(ROIList,";");i+=1)
//		//Get first tuning curve
//		ROIfolder = "ROI" + StringFromList(i,ROIlist,";")
//	 	If(WaveExists($("root:ROI_analysis:" + ROIfolder + ":DStuning_1_" + ROIfolder + "_avg")))
//	 		wave f1 = $("root:ROI_analysis:" + ROIfolder + ":DStuning_1_" + ROIfolder + "_avg")
//	 	Else
//	 		DoAlert 0,"Couldn't find tuning curve for " + ROIfolder
//			return 0
//		EndIf
//		
//		//Make dVector wave to hold angle and radius data. Radius will be scaled by the correlation matrix
//		If(WaveExists($("root:ROI_analysis:" + ROIfolder + ":DStuning_1_VSUM_avg")))
//			wave VSUM = $("root:ROI_analysis:" + ROIfolder + ":DStuning_1_VSUM_avg")
//		Else
//			DoAlert 0,"Couldn't find vector sum wave for " + ROIfolder
//			return 0
//		EndIf
//		
//		String dVectorName = "root:ROI_analysis:" + ROIfolder + ":dVector_" + ROIfolder
//		Make/O/N=(1,2) $dVectorName
//		Wave dVector = $dVectorName
//		dVector[0][0] = 0	//starts radius of dVector at zero, it will be scaled by Qmatrix later
//		dVector[0][1] = VSUM[1]	//puts vector sum angle into dVector
//		
//		For(j=0;j<ItemsInList(ROIlist,";");j+=1)
//		
//			//SetDataFolder root:ROI_analysis:$ROIfolder
//
//			//Center of mass vectors will be the average vector sums, which I've already calculated.
//		
//			//Calculate the inverse correlation matrix. This is our weighting factor for the center of mass
//			//vectors. Once COM vectors are scaled by the correlation matrices, a normal vector sum is used on the
//			//actual scan data.
//
//			//Get second tuning curve
//			ROIfolder = "ROI" + StringFromList(j,ROIlist,";")
//			If(WaveExists($("root:ROI_analysis:" + ROIfolder + ":DStuning_1_" + ROIfolder + "_avg")))
//	 			wave f2 = $("root:ROI_analysis:" + ROIfolder + ":DStuning_1_" + ROIfolder + "_avg")
//	 		Else
//	 			DoAlert 0,"Couldn't find tuning curve for " + ROIfolder
//				return 0
//			EndIf
//			
//			Make/FREE/N=(DimSize(f1,0)) product
//			SetScale/P x,DimOffset(f1,0),DimDelta(f1,0),product
//			product = f1*f2
//			
//			If(i != j)
//				WaveStats/Q f1
//				delta = 1
//			Else
//				delta = 0
//			EndIf
//			Qmatrix[i][j] = delta*V_sdev^2 + area(product)
//			//Scale dVector wave by inverse correlation matrix
//			dVector[0] += (1/Qmatrix[i][j]) * VSUM[0]
//		EndFor
//		
//		//Get current scan in the designated ROI
//		ROIfolder = "ROI" + StringFromList(i,ROIlist,";")
//		SetDataFolder root:ROI_analysis:$ROIfolder
//		wave currentWave = $(StringFromList(k,scanList,";") + ROIfolder)
//		
//		//Compute vector sum of dVector and the scan data
//		If(i == 0)
//			Make/FREE/N=(DimSize(currentWave,0)) vSumX,vSumY,totalsignal
//			vSumX = 0
//			vSumY = 0
//			totalSignal = 0
//		EndIf
//		
//		vSumX += currentWave * dVector[0][0] * cos(dVector[0][1]*pi/180)
//		vSumY += currentWave * dVector[0][0] * sin(dVector[0][1]*pi/180)
//		totalSignal += currentWave * dVector[0][0]
//	EndFor	
//	
//	//Make waves to hold time-varying angle, radius, and DSI output
//	Make/N=(DimSize(currentWave,0))/O $("root:ROI_analysis:multiROI:OLE_angle_" + StringFromList(1,StringFromList(k,scanList,";"),"_"))
//	Wave OLE_angle = $("root:ROI_analysis:multiROI:OLE_angle_" + StringFromList(1,StringFromList(k,scanList,";"),"_"))
//	Make/N=(DimSize(currentWave,0))/O $("root:ROI_analysis:multiROI:OLE_radius_" + StringFromList(1,StringFromList(k,scanList,";"),"_"))
//	Wave OLE_radius = $("root:ROI_analysis:multiROI:OLE_radius_" + StringFromList(1,StringFromList(k,scanList,";"),"_"))
//	Make/N=(DimSize(currentWave,0))/O $("root:ROI_analysis:multiROI:OLE_dsi_" + StringFromList(1,StringFromList(k,scanList,";"),"_"))
//	Wave OLE_dsi = $("root:ROI_analysis:multiROI:OLE_dsi_" + StringFromList(1,StringFromList(k,scanList,";"),"_"))
//	
//	//Compute estimated angle and radius
//	OLE_angle = -atan2(vSumY,vSumX)*180/pi
//	OLE_radius = sqrt(vSumX^2 + vSumY^2)
//	OLE_dsi = OLE_radius/totalSignal
//	
//	//adjustments to the angle wave so its on the correct 0-359 degree scale.
//	OLE_angle = (OLE_angle < 0) ? OLE_angle+360 : OLE_angle
//	OLE_angle = 360 - OLE_angle
//	
//	//X scale angle,radius, and DSI waves
//	String scanIndex = StringFromList(1,StringFromList(k,scanList,";"),"_")
//	Variable frameTime = GetScanFrameTime(scanIndex,0)
//	SetScale/P x,DimOffset(currentWave,0),frameTime,OLE_angle,OLE_radius,OLE_dsi
//	
//	//If actual stimulus angles were provided, calculate % error and deviation from OLE results
//	If(!ParamIsDefault(actualAngles))
//		Make/N=(DimSize(currentWave,0))/O $("root:ROI_analysis:multiROI:OLE_pctError_" + StringFromList(1,StringFromList(k,scanList,";"),"_"))
//		Wave OLE_pctError = $("root:ROI_analysis:multiROI:OLE_pctError_" + StringFromList(1,StringFromList(k,scanList,";"),"_"))
//		Make/N=(DimSize(currentWave,0))/O $("root:ROI_analysis:multiROI:OLE_deviation_" + StringFromList(1,StringFromList(k,scanList,";"),"_"))
//		Wave OLE_deviation = $("root:ROI_analysis:multiROI:OLE_deviation_" + StringFromList(1,StringFromList(k,scanList,";"),"_"))
//		
//		Variable angle = str2num(StringFromList(k,actualAngles,","))
//		Duplicate/FREE OLE_angle,diff
//		diff = OLE_angle-angle
//		diff = sqrt(diff^2)
//		
//		If(angle == 0)
//			OLE_pctError = 100*(diff/360)
//		Else
//			OLE_pctError = 100*(diff/angle)
//		EndIf
//		OLE_deviation = OLE_angle - angle
//		SetScale/P x,DimOffset(currentWave,0),frameTime,OLE_pctError,OLE_deviation
//	EndIf
//	
//	//Looping through each scan index
// EndFor	
//End

//Returns ROI parameters to the calling function (Get ROI)
Function initParam(img,ds)
	STRUCT IMAGING &img
	STRUCT ds &ds
	
	DFREF RF = root:Packages:NT:ScanImage:ROIs
	DFREF TP = root:Packages:twoP:examine
	DFREF NTI = root:Packages:NT:Imaging
	DFREF NTSI = root:Packages:NT:ScanImage
	
	//Is this 2PLSM or ScanImage file structures?
	String software = whichImagingSoftware()
	
	ControlInfo/W=NT channelSelect
	img.channel = V_Value
	
	ControlInfo/W=NT dFSelect
	img.mode = V_Value
	
	ControlInfo/W=NT baselineSt
	img.bsSt = V_Value
	
	ControlInfo/W=NT baselineEnd
	img.bsEnd = V_Value
	
	ControlInfo/W=NT peakSt
	img.pkSt = V_Value
	
	ControlInfo/W=NT peakEnd
	img.pkEnd = V_Value
	
	ControlInfo/W=NT filterSize
	img.filter = V_Value
	
	//holds the measurement string
	ControlInfo/W=NT measurePopUp
	SVAR img.measure = NTSI:measure 
	img.measure = S_Value
	
	//ROI ListBox list and select waves
	Wave/T ROIListWave = NTSI:ROIListWave
	Wave ROISelWave =  NTSI:ROISelWave
	
	Wave/T ScanListWave = NTSI:ScanListWave
	Wave ScanSelWave = NTSI:ScanSelWave

	If(DimSize(ROISelWave,0) > 0)
		ROISelWave = (ROISelWave >= 1) ? 1 : 0
		img.roi.num = sum(ROISelWave)
	Else
		img.roi.num = 0
	EndIf
	img.scan.num = ds.numWaves
	
	//active ROIs used for the analsis and their position wave references
	Make/O/N=(img.roi.num,1,2)/T NTSI:ROI_List_Analysis
	Make/O/N=(img.roi.num)/WAVE NTSI:ROI_Coord_X
	Make/O/N=(img.roi.num)/WAVE NTSI:ROI_Coord_Y
	
	Wave/T img.rois = NTSI:ROI_List_Analysis
	Wave/WAVE img.roi.x = NTSI:ROI_Coord_X
	Wave/WAVE img.roi.y = NTSI:ROI_Coord_Y
	
	//active Scans channels used for the analysis
	Make/O/N=(img.scan.num)/WAVE NTSI:Scan_List_Ch1
	Make/O/N=(img.scan.num)/WAVE NTSI:Scan_List_Ch2
	Wave/WAVE/Z img.scan.ch1 = NTSI:Scan_List_Ch1
	Wave/WAVE/Z img.scan.ch2 = NTSI:Scan_List_Ch2
	
	//Fill out all the ROI name and get their position waves
	Variable i = 0, count = 0
	
	If(DimSize(ROISelWave,0) > 0 || img.roi.num > 0)
		Do
			If(ROISelWave[i] > 0)
				If(!cmpstr(software,"ScanImage"))
					DFREF RF = root:Packages:NT:ScanImage:ROIs:$ROIListWave[i][0][1]
				ElseIf(!cmpstr(software,"2PLSM"))
					DFREF RF = root:twoP_ROIS:$ROIListWave[i][0][1]
				EndIf
				img.rois[count][0][0] = ROIListWave[i][0][0] //ROI names
				img.rois[count][0][1] = ROIListWave[i][0][1]	//ROI groups
				
				If(stringmatch(ROIListWave[i][0][0],"*_soma"))
					//somatic ROI map
					img.roi.x[count] = RF:$(img.rois[count])
					img.roi.y[count] = RF:$(img.rois[count])
				Else
					//standard ROI boundaries
					img.roi.x[count] = RF:$(img.rois[count] + "_x")
					img.roi.y[count] = RF:$(img.rois[count] + "_y")
				EndIf
				count += 1
			EndIf
			i += 1
		While(i < DimSize(ROISelWave,0))
	EndIf
	
	//Fill out all the scan waves
//	ds.listWave = RemoveEnding(ParseFilePath(1,ds.listWave[p],"_",1,0),"_")
	
	For(i=0;i<ds.numWaves;i+=1)
		img.scan.ch1[i] = ds.waves[i]
		
		img.scan.ch2[i] = ds.waves[i]
	EndFor	
End

//Runs the selected command
Function RunCmd_ScanImagePackage(cmd)
	String cmd
	STRUCT ds ds
	
	DFREF NTSI = root:Packages:NT:ScanImage
	
	strswitch(cmd)
		case "Get ROI":
			GetStruct(ds)
			Wave/WAVE out = NT_GetROI(ds)
			break
		case "dF Map":
			GetStruct(ds)
			Wave/WAVE out = NT_dFMap(ds)
			break
		case "Population Vector Sum":
//			NT_PopVectorSum()
			NT_OLE()
			break
		case "Load Scans":
			//Get the folder path
			SVAR ScanLoadPath = NTSI:ScanLoadPath
			Wave/T ScanLoadListWave = NTSI:ScanLoadListWave
			Wave ScanLoadSelWave = NTSI:ScanLoadSelWave
			
			//Get the selected file list
			String fileList = ""
			
			Variable i
			For(i=0;i<DimSize(ScanLoadSelWave,0);i+=1)
				If(ScanLoadSelWave[i] > 0)
					fileList += ScanLoadListWave[i] + ";"
				EndIf
			EndFor
			
			SI_LoadScans(ScanLoadPath,fileList)
			updateImageBrowserLists()
			
			break
		case "Max Project":
			GetStruct(ds)
			WRAPPER_MaxProject(ds)
			break
		case "Vector Sum Map":
			GetStruct(ds)
			String angles = GetVectorSumAngles(ds,ds.numWaves)
//			NT_VectorSumMap(ds,angles)
			NT_FindDSCells(ds,angles)
			break
		case "Response Quality":
			GetStruct(ds)
			NT_ResponseQuality(ds)
			break
	endswitch
End

Menu "roiRightClickMenu",contextualMenu,dynamic
	"Rename"
	"GoTo"
	SubMenu "Move To"
		TextWaveToStringList(SI_GetROIGroups(),";")
	End
	"Delete;"
End