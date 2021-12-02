#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include <Append Calibrator>

StrConstant NL_LIGHT = "Helvetica Neue Light"

Menu "Macros"
	"Load NeuroLive",Load_NeuroLive()
End


Menu "funcMenu",contextualmenu,dynamic
	GetFuncMenu(),""
End

Function/S GetFuncMenu()
	//Command list
	DFREF NLF = root:Packages:NeuroLive
	
	String/G NLF:funcList
	SVAR funcList = NLF:funcList
	funcList = GetExternalFunctions()
	return funcList
End

Function Load_NeuroLive([left,top])
	Variable left,top
	
	left = (ParamIsDefault(left)) ? 50 : left
	top = (ParamIsDefault(top)) ? 50 : top
	
	KillWindow/Z NL
	
	NewPanel/K=1/N=NL/W=(left,top,left + 800,top + 600) as "NeuroLive"
	SetWindow NL sizeLimit={800,400,inf,inf}
	
	MakePackageFolders()
	
	DFREF NLF = root:Packages:NeuroLive
	
	//File List
	Make/N=(0,2,2)/T/O NLF:fileListWave/Wave = fileListWave
	Make/N=(0,2,2)/O NLF:fileSelWave/Wave = fileSelWave	
	Make/N=(2,4)/O/W/U NLF:colColor/Wave = colColor
	
	colColor[][0] = {0,0}
	colColor[][1] = {0,0xb000}
	colColor[][2] = {0,0}
	colColor[][3] = {0,0x2000}
	
	SetDimLabel 2,1,backColors,fileSelWave	// define plane 1 as background colors

	ListBox fileList win=NL,pos={10,50},size={400,240},listWave=fileListWave,selWave=fileSelWave,colorWave=colColor,mode=9,widths={150,10},proc=nlListBoxProc
//	ListBox channelList win=NL,pos={415,50},size={100,200},listWave=chListWave,selWave=chSelWave,colorWave=colColor,mode=9,widths={150,10},proc=nlListBoxProc
	
	//Browse Folder Button
	Button browseFiles win=NL,pos={10,29},size={30,20},fsize=14,title="...",proc=nlButtonProc
	
	//File Type Menu
	PopUpMenu fileType win=NL,pos={50,30},size={100,20},title="Type",font=$NL_LIGHT,fsize=10,value="PClamp;WaveSurfer;Presentinator;"
	
	//Channel Selector
	PopUpMenu channel win=NL,pos={335,30},size={50,20},title="Channel",value="1;2;3;4;All;",font=$NL_LIGHT,fsize=10,proc=nlMenuProc
	
	//Reload button
	Button reload win=NL,pos={10,5},size={60,20},title="Reload",proc=nlButtonProc,font=$NL_LIGHT
	
	//Goto Code button
	Button gotoCode win=NL,pos={430,30},size={50,20},title="GoTo",font=$NL_LIGHT,fsize=12,proc=nlButtonProc
	
	//Viewer Graph
	DefineGuide/W=NL midGuide = {FT,300}
	Display/HOST=NL/N=LiveViewer/FG=(FL,midGuide,FR,FB)
	
	SetWindow NL hook(NLHook) = NLHook
	
	//Graph control buttons
	Button autoscale win=NL,pos={415,271},size={40,20},title="Auto",font=$NL_LIGHT,fsize=12,proc=nlButtonProc
	CheckBox horTrace win=NL,pos={460,273},size={40,20},title="Horiz",font=$NL_LIGHT,fsize=10,proc=nlCheckProc
	CheckBox vertTrace win=NL,pos={505,273},size={40,20},title="Vert",font=$NL_LIGHT,fsize=10,proc=nlCheckProc
	Button displayGraphContents win=NL,pos={550,253},size={30,20},title="◻︎",fsize=24,font=$NL_LIGHT,proc=nlButtonProc
	String colorButtonTitle = "\\K(65535,0,52428)/\\K(1,16019,65535)/\\K(0,60535,60535)\\K(1,52428,52428)/\\K(52428,52425,1)/"
	Button colorGraphContents win=NL,pos={550,277},size={30,20},title=colorButtonTitle,fsize=18,font=$NL_LIGHT,proc=nlButtonProc


	//Histogram controls
	Variable leftPos = 590
	GroupBox histControls win=NL,pos={leftPos,240},size={205,60},title=" "
	CheckBox doHistogram win=NL,pos={leftPos + 10,256},size={60,20},font=$NL_LIGHT,fsize=10,title="Histogram ",proc=nlCheckProc
	Button flatten win=NL,pos={leftPos + 10,272},size={60,20},fsize=10,font=$NL_LIGHT,fsize=10,title="De-Trend",proc=nlButtonProc
	PopUpMenu histType win=NL,pos={leftPos + 85,255},size={80,20},font=$NL_LIGHT,fsize=10,title="Type",value="Gaussian;Binned;",proc=nlMenuProc
	SetVariable binSize win=NL,pos={leftPos + 85,276},size={90,20},font=$NL_LIGHT,fsize=10,title="Bin Size",value=_NUM:0.02,limits={0,inf,0.005},proc=nlSetVarProc
	
	//Background signal range
	CheckBox bgndRange win=NL,pos={415,251},size={100,20},title="Background Range ",font=$NL_LIGHT,fsize=10,proc=nlCheckProc
	
	
	//External functions
	If(!WaveExists(NLF:ExtFunc_Parameters))
		Make/T/O/N=(6,1) NLF:ExtFunc_Parameters
	EndIf
	
	Wave/T ExtFunc_Parameters = NLF:ExtFunc_Parameters
	Wave/T param = GetExternalFunctionData(ExtFunc_Parameters)
	
	Variable/G NLF:numExtParams
	String/G  NLF:extParamTypes
	String/G NLF:extParamNames
	String/G NLF:ctrlList_extFunc
	Make/WAVE/O/N=0 NLF:extFuncWaveRefs
	
	
////	PopUpMenu functions win=NL,pos={450,30},size={250,20},bodywidth=200,title="Functions",value=#"root:Packages:NeuroLive:funcList",proc=nlMenuProc
	String menuItems = GetFuncMenu()
	
	String item = StringFromList(0,menuItems,";")
	String spacer = NTL_GetSpacer(item)
	
	Button functions win=NL,pos={490,30},size={175,20},title=spacer + item,proc=nlButtonProc
	
	//Display the first function's controls
	BuildExtFuncControls(item)
	
	String/G NLF:selFunction
	SVAR selFunction = NLF:selFunction
	selFunction = StringFromList(0,menuItems,";")
	Button run win=NL,pos={690,30},size={50,20},fColor=(48316,60909,37265),title="RUN",font=$NL_LIGHT,fsize=12,proc=nlButtonProc
	
//	PopUpMenu histChannel win=NL,pos={720,355},size={80,20},title="Ch",value="1;2;",proc=nlMenuProc
	
	//Threshold bar
	Variable/G NLF:threshold
	NVAR threshold = NLF:threshold
	threshold = 30e-3
	
	Variable/G NLF:moveThreshold
	NVAR moveThreshold = NLF:moveThreshold
	moveThreshold = 0
	
	Variable/G NLF:guidePos
	NVAR guidePos = NLF:guidePos
	guidePos = 500
	
	Variable/G NLF:moveGuides
	NVAR moveGuides = NLF:moveGuides
	moveGuides = 0
	
	//Analysis start time and end time bars
	Variable/G NLF:startTime
	NVAR startTime = NLF:startTime
	startTime = -100 //try to put it out of range so it sets itself according to axis limits
	
	Variable/G NLF:endTime
	NVAR endTime = NLF:endTime
	endTime = 100 //try to put it out of range so it sets itself according to axis limits
	
	Variable/G NLF:bgndStartTime
	NVAR bgndStartTime = NLF:bgndStartTime
	bgndStartTime = -100 //try to put it out of range so it sets itself according to axis limits
	
	Variable/G NLF:bgndEndTime
	NVAR bgndEndTime = NLF:bgndEndTime
	bgndEndTime = 100 //try to put it out of range so it sets itself according to axis limits
	
	Variable/G NLF:moveEndRange
	NVAR moveEndRange = NLF:moveEndRange
	moveEndRange = 0
	
	Variable/G NLF:moveStartRange
	NVAR moveStartRange = NLF:moveStartRange
	moveStartRange = 0
	
	Variable/G NLF:moveBgndEndRange
	NVAR moveBgndEndRange = NLF:moveBgndEndRange
	moveBgndEndRange = 0
	
	Variable/G NLF:moveBgndStartRange
	NVAR moveBgndStartRange = NLF:moveBgndStartRange
	moveBgndStartRange = 0
	
	Variable/G NLF:areColored
	NVAR areColored = NLF:areColored
	areColored = 0
End

//Make the Von Mises fit function for curve fit
//Function vonMises(w,x) : FitFunc
	Wave w
	Variable x

	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ //	return w[2]*exp(w[1]*cos((x-w[0])*pi/180))/(2*pi*Besseli(0,w[1]))
	//CurveFitDialog/ f(x) = peak*exp(kappa*cos((x-mu)*pi/180))/exp(kappa)	// Peak = w[2]
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ x
	//CurveFitDialog/ Coefficients 3
	//CurveFitDialog/ w[0] = mu
	//CurveFitDialog/ w[1] = kappa
	//CurveFitDialog/ w[2] = peak

	//	return w[2]*exp(w[1]*cos((x-w[0])*pi/180))/(2*pi*Besseli(0,w[1]))
	return w[2]*exp(w[1]*cos((x-w[0])*pi/180))/exp(w[1])	// w[2] = w[2]
End

//Returns the list of external functions
Static Function/S GetExternalFunctions()
	String theFile,theList=""
	theFile = "NeuroLive.ipf"
	theList = FunctionList("NL_*", ";","WIN:" + theFile)
	theList = ReplaceString("NL_",theList,"") //remove NT_ prefixes for the menu
	return theList
End

//Initializes the external functions module, and fills out a text wave with the data for each 
//main function in NT_ExternalFunctions.ipf'
Static Function/Wave GetExternalFunctionData(param)
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
		String info = FunctionInfo("NL_" + theFunction)
		
		//Gets the actual code for the beginning of the function to extract parameter names
		String fullFunctionStr = ProcedureText("NL_" + theFunction,0)
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
		Variable col = tableMatch("NL_" + theFunction,param,returnCol=1)
		
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
			
			//Label the dimension for each key item
			SetDimLabel 0,j,$theKey,param
			
			//Add the function data to the wave
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
					param[j][i] = GetPopUpValue(popUpStr,fullFunctionStr)
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

//Finds the pop up menu values from the code
Static Function/S GetPopUpValue(popUpStr,functionStr)
	String popUpStr,functionStr
	String values = ""
	
	If(!strlen(popUpStr) || !strlen(functionStr))
		return ""
	EndIf
	
	//Syntax for referencing the list items in a user defined menu
	String list = popUpStr + "_List"
	
	Variable pos = strsearch(functionStr,list,0)
	
	If(pos == -1)
		print "Couldn't find the pop up menu items for " + popUpStr + ". Make sure the syntax for referencing them is correct."
		return ""
	EndIf
	
	//Extracts the referenced item list using string quotations as a list separator
	values = functionStr[pos,pos + 400]
	values = StringFromList(1,values,"\"")
	
	return values
End

Function colorScheme(scheme)
	Variable scheme
	
	String ctrlList = "doHistogram;flatten;histType;binSize;horTrace;vertTrace;fileType;channel;histControls;"
	Variable i
	switch(scheme)
		case 0:
			Variable R = 0
			Variable G = 0
			Variable B = 0
			
			ModifyPanel/W=NL cbRGB=(1,1,1,0)
			break
		case 1:
			R = 0xffff
			G = 0xffff
			B = 0xffff
			
			ModifyPanel/W=NL cbRGB=(0,0xffff/5,0xffff/2.5)
			break
	endswitch
	
	
	
	
	For(i=0;i<ItemsInList(ctrlList,";");i+=1)
		String ctrl = StringFromList(i,ctrlList,";")
		ControlInfo/W=NL $ctrl
		switch(V_flag)
			case 1:
				//button
				Button $ctrl win=NL,fColor=(R,G,B)
				break
			case 2:
				//checkbox
				Checkbox $ctrl win=NL,fColor=(R,G,B)
				break
			case -3:
			case 3:
				//menu
				PopUpMenu $ctrl win=NL,fColor=(R,G,B)
				break
			case -5:
			case 5:
				//setvariable
				SetVariable $ctrl win=NL,fColor=(R,G,B)
				break
			case 9:
				//groupbox
				GroupBox $ctrl win=NL,fColor=(R,G,B)
				break
		endswitch
	EndFor
End

Static Function AppendRangeBar()
	
	ControlInfo/W=NL bgndRange
	Variable doBgnd = V_Value
	
	DFREF NLF = root:Packages:NeuroLive
	NVAR startTime = NLF:startTime
	NVAR endTime = NLF:endTime
	
	NVAR bgndStartTime = NLF:bgndStartTime
	NVAR bgndEndTime = NLF:bgndEndTime
	
	//Get the range of the x and y axes
	GetAxis/W=NL#LiveViewer/Q bottom
	
	If(V_flag)
		GetAxis/W=NL#LiveViewer/Q bottom_0
		If(V_flag)
			return 0	
		EndIf
	EndIf
	
	//Make sure our selection ranges are within axis range
	If(bgndEndTime > V_max + V_max * 1.5)
		bgndEndTime = V_max * 0.3
	EndIf
	
	If(bgndStartTime < V_min -  V_min * 0.5)
		bgndStartTime = V_min + (V_max - V_min) * 0.1
	EndIf
	
	If(endTime > V_max +  V_max * 1.5)
		endTime = V_max * 0.6
	EndIf
	
	If(startTime < V_min - V_min * 0.5)
		startTime = V_min + (V_max - V_min) * 0.4
	EndIf
	
	//Get list of all the x axes
	String axList = AxisList("NL#LiveViewer")
	axList = ListMatch(axList,"bottom*",";")

	DrawAction/W=NL#LiveViewer getgroup=range,delete
	SetDrawEnv/W=NL#LiveViewer gstart,gname=range
		
	Variable i
	For(i=0;i<ItemsInList(axList,";");i+=1)
		String ax = StringFromList(i,axList,";")
		
		If(doBgnd)
			SetDrawEnv/W=NL#LiveViewer xcoord=$ax,ycoord=rel,linethick=0,fillfgc=(0,0,0xffff,0x1000)
			DrawRect/W=NL#LiveViewer bgndStartTime,1,bgndEndTime,0
		EndIf
		
		SetDrawEnv/W=NL#LiveViewer xcoord=$ax,ycoord=rel,linethick=0,fillfgc=(0,0,0,0x1000)
		DrawRect/W=NL#LiveViewer startTime,1,endTime,0
		
	EndFor
	
	SetDrawEnv/W=NL#LiveViewer gstop,gname=range

End



Static Function AppendThresholdBar()
	DFREF NLF = root:Packages:NeuroLive
	NVAR threshold = NLF:threshold
	
	
	//Get the range of the x and y axes
	GetAxis/W=NL#LiveViewer/Q left
	
	If(V_flag)
		return 0	
	EndIf
	
	Variable yMin,yMax,yRange,yBottom,yTop
	yMin = V_min
	yMax = V_max
	
	threshold = (threshold < yMin) ? yMin : threshold
	threshold = (threshold > yMax) ? yMax : threshold
	
	DrawAction/W=NL#LiveViewer getgroup=threshold,delete
	
	SetDrawEnv/W=NL#LiveViewer xcoord=rel,ycoord=left,linethick=1,linefgc=(0,0,0,0x4000)
	SetDrawEnv/W=NL#LiveViewer gstart,gname=threshold
	DrawLine/W=NL#LiveViewer 0,threshold,1,threshold
	SetDrawEnv/W=NL#LiveViewer gstop
	DoUpdate/W=NL#LiveViewer
End


Static Function MakePackageFolders()
	If(!DataFolderExists("root:Packages"))
		NewDataFolder root:Packages
	EndIf
	
	If(!DataFolderExists("root:Packages:NeuroLive"))
		NewDataFolder root:Packages:NeuroLive
	EndIf
End


//Opens a browse dialog and lists out the files with the indicated type
Static Function BrowseFiles(fileType)
	String fileType
	String filter = ""
	
	DFREF NLF = root:Packages:NeuroLive
	Wave/T fileListWave = NLF:fileListWave 
	Wave fileSelWave = NLF:fileSelWave
	
	strswitch(fileType)
		case "WaveSurfer":
			filter = ".h5"
			break
		case "PClamp":
			filter = ".abf"
			break
		case "Presentinator":
			filter = ".phys"
			break
	endswitch
	
	//Choose a folder path for the data
	NewPath/O/Q/Z filePath
	
	PathInfo/S filePath
	
	If(!strlen(S_path))
		return 0	
	EndIf
	
	String folder = ParseFilePath(0,S_path,":",1,0)
	
	//Get the list of files with the correct extension based on their file type
	String fileList = IndexedFile(filePath,-1,filter)	
	
	If(!strlen(fileList))
		return 0
	EndIf
	
	Variable i,j
	
	strswitch(fileType)
		case "WaveSurfer":
		
			//Get the sweep list if it's a wavesurfer file
			String sweepListTemp = GetWSSweeps(fileList)
			String colorList = "", chList = "", sweepList = "", fullPathList = "", prefixList = ""
			
			//Resize the list box that holds the file names and parent folders
			Redimension/N=(ItemsInList(sweepListTemp,";"),2,2) fileListWave
			Redimension/N=(ItemsInList(sweepListTemp,";"),2,2) fileSelWave
			
			//Extract number of channels and the row color from the list
			For(i=0;i<ItemsInList(sweepListTemp,";");i+=1)
				colorList += StringFromList(0,StringFromlist(i,sweepListTemp,";"),"//") + ";"
				prefixList = StringFromList(1,StringFromlist(i,sweepListTemp,";"),"//") + ";"
				chList += StringFromList(2,StringFromlist(i,sweepListTemp,";"),"//") + ";"
				sweepList += StringFromList(3,StringFromlist(i,sweepListTemp,";"),"//") + ";"
				
				fileSelWave[i][][1] = str2num(StringFromList(i,colorList,";"))
			EndFor
			
			For(i=0;i<ItemsInList(sweepList,";");i+=1)	
				String sweepPath = StringFromList(i,sweepList,";")
				String sweepNum = StringFromList(1,StringFromList(1,sweepPath,"/"),"_")
				String wavePath = ""
				
				j = 0
				Do
					If(!cmpstr(sweepNum[j],"0"))
						sweepNum = sweepNum[j+1,strlen(sweepNum)-1] //truncate leading zeros
						continue
					Else
						break
					EndIf
					
					j += 1
				While(j < strlen(sweepNum)-1)
				
				prefixList = RemoveEnding(prefixList,";")
				
				For(j=0;j<ItemsInList(prefixList,"#");j+=1)
					String prefix = StringFromList(j,prefixList,"#")
					wavePath += "root:EPhys:" + folder + ":" + prefix + "_" + sweepNum + "_1_1_" + num2str(j+1) + ";"
				EndFor
				
				fileListWave[i][0][1] = wavePath
			EndFor
			
			//Load the data into Igor if it doesn't already exist
			StringListToTextWave(sweepList,fileListWave,";",col=0)
			StringListToTextWave(chList,fileListWave,";",col=1)
			Load_WaveSurfer(sweepList,channels="All")
				
			break
		case "PClamp":
			Variable numFiles = ItemsInList(fileList,";")
			
			Redimension/N=0 fileListWave,fileSelWave
			
			Variable color = 0
			
			For(i=0;i<numFiles;i+=1)	
				String theFile = StringFromList(i,fileList,";")
				
				Variable nSweeps = PCLamp_GetNumSweeps(S_Path + theFile)
				Variable nChannels = PClamp_nChannels(S_Path + theFile)
				
				Variable c,size = DimSize(fileListWave,0)
				Redimension/N=(DimSize(fileListWave,0) + nSweeps,2,2) fileListWave,fileSelWave
				
				folder = ParseFilePath(0,S_Path,":",1,0) 
				Variable row,sweep
				For(row = size,sweep=1;row < size + nSweeps;row += 1,sweep+=1)
					fileListWave[row][0][0] = folder + ":" + theFile + "/Sweep " + num2str(sweep)
					
					//Get the channel indexes
					Variable refnum
					Open/R/Z=2 refnum as S_Path + theFile
					
					If(V_flag == -1 || V_flag > 0)
						return 0
					EndIf
					
					Wave ADCSection = GetADCSection(refnum)
					
					wavePath = ""
					String channelBase = ""
					
					//Set the wave path for loading
					For(c=0;c<nChannels;c+=1)
				
						Variable chIndex = GetADCParam(refnum,ADCSection,c,"ADCNum")
						
						String unitBase = pClamp_GetChannelUnit(refnum,c)

						//Prefix
						strswitch(unitBase)
							case "A": //amps, voltage clamp
								prefix = "Im"
								break
							case "V": //volts, current clamp
								prefix = "Vm"
								break
						endswitch
						
						//Group
						String group = ParseFilePath(0,theFile,":",1,0)
						group = ParseFilePath(0,group,"_",1,0)
						group = ParseFilePath(0,group,".",0,0)
						group = num2str(str2num(group))
						
						wavePath += "root:EPhys:" + folder + ":" + prefix + "_" + group + "_" + num2str(sweep) + "_1_" + num2str(chIndex) + ";"
					EndFor
					
					Close refnum
					
					fileListWave[row][0][1] = wavePath
					fileSelWave[row][][1] = color		
					
				EndFor
				
				fileList = ReplaceListItem(i,fileList,";",S_Path + theFile)
				color = (color) ? 0 : 1
			EndFor
			
			NL_LoadPClamp(fileList,channels="All")
									
			break
		case "Presentinator":
		
			//Resize the list box that holds the file names and parent folders
			Redimension/N=(ItemsInList(fileList,";"),2,2) fileListWave
			Redimension/N=(ItemsInList(fileList,";"),2,2) fileSelWave
			
			sweepList = ""
			For(i=0;i<ItemsInList(fileList,";");i+=1)	
				theFile = StringFromList(i,fileList,";")
				fileListWave[i][0][1] = LoadPresentinator(theFile)
			EndFor
			
			StringListToTextWave(fileList,fileListWave,";",col=0)

			break
	endswitch


	
	//Start a background task to repeatedly check this folder for new data
//	StartDataTask()
End

//returns the number of sweeps in a pclamp file
Static Function pClamp_GetNumSweeps(file)
	String file //this needs to be a full path to the file
	
	file = RemoveEnding(file,".abf") + ".abf"
	
	Variable refnum,nSweeps
	
	Open/R/Z=2 refnum as file
		
	If(V_flag == -1 || V_flag > 0)
		return 0
	EndIf
		
	//Number sweeps
	FSetPos refnum,12
	FBInRead/B=3/F=3 refnum,nSweeps
	
	Close/A
	
	return nSweeps
End

Static Function/Wave GetSynchSection(refnum)
	Variable refnum
	
	//Section list
	String sectionStr = "ProtocolSection;ADCSection;DACSection;EpochSection;ADCPerDACSection;EpochPerDACSection;UserListSection;StatsRegionSection;MathSection;"
	sectionStr += "StringsSection;DataSection;TagSection;ScopeSection;DeltaSection;VoiceTagSection;SynchArraySection;AnnotationSection;StatsSection;"
	
	//Data start byte and data length
	Variable whichSection = WhichListItem("SynchArraySection",sectionStr,";")
	Variable offset = 76 + 16 * whichSection
	
	Make/N=3/FREE SynchArraySection
	
	Variable tempVar
	
	//uBlockIndex
	FSetPos refnum,offset
	FBInRead/B=3/F=3/U refnum,tempVar
	SynchArraySection[0] = tempVar
	//uBytes
	FSetPos refnum,offset+4
	FBInRead/B=3/F=3/U refnum,tempVar
	SynchArraySection[1] = tempVar
	//numEntries
	FSetPos refnum,offset+8
	FBInRead/B=3/F=6 refnum,tempVar
	SynchArraySection[2] = tempVar
	
	return SynchArraySection
End

Static Function/Wave GetDataSection(refnum)
	Variable refnum
	
	//Section list
	String sectionStr = "ProtocolSection;ADCSection;DACSection;EpochSection;ADCPerDACSection;EpochPerDACSection;UserListSection;StatsRegionSection;MathSection;"
	sectionStr += "StringsSection;DataSection;TagSection;ScopeSection;DeltaSection;VoiceTagSection;SynchArraySection;AnnotationSection;StatsSection;"
	
	//Data start byte and data length
	Variable whichSection = WhichListItem("DataSection",sectionStr,";")
	Variable offset = 76 + 16 * whichSection
	
	Make/N=3/FREE DataSection
	
	Variable tempVar
	
	//uBlockIndex
	FSetPos refnum,offset
	FBInRead/B=3/F=3/U refnum,tempVar
	DataSection[0] = tempVar
	//uBytes
	FSetPos refnum,offset+4
	FBInRead/B=3/F=3/U refnum,tempVar
	DataSection[1] = tempVar
	//numEntries
	FSetPos refnum,offset+8
	FBInRead/B=3/F=6 refnum,tempVar
	DataSection[2] = tempVar
	
	return DataSection
End

Static Function GetProtocolParam(refnum,ProtSection,param)
	Variable refnum
	Wave ProtSection
	String param
	
	String protStr = "operationMode;ADCSequenceInterval;enableFileCompression;unused1;fileCompressionRatio;synchTimeUnit;secondsPerRun;numSamplesPerEpisode;preTriggerSamples;"
	protStr += "episodesPerRun;runsPerTrial;numberOfTrials;averagingMode;undoRunCount;firstEpisodeInRun;triggerThreshold;triggerSource;triggerAction;triggerPolarity;scopeOutputInterval;"
	protStr += "episodeStartToStart;runStartToStart;averageCount;trialStartToStart;autoTriggerStrategy;firstRunDelayS;channelStatsStrategy;samplesPerTrace;startDisplayNum;finishDisplayNum;"
	protStr += "showPNRawData;statisticsPeriod;statisticsMeasurements;statisticsSaveStrategy;ADCRange;DACRange;ADCResolution;DACResolution;experimentType;manualInfoStrategy;commentsEnable;"
	protStr += "fileCommentIndex;autoAnalyseEnable;signalType;digitalEnable;ActiveDACChannel;digitalHolding;digitalInterEpisode;digitalDACChannel;digitalTrainActiveLogic;statsEnable;statisticsClearStrategy;levelHysteresis;"
	protStr += "timeHysteresis;allowExternalTags;averageAlgorithm;averageWeighting;undoPromptStrategy;trialTriggerSource;statisticsDisplayStrategy;externalTagType;scopeTriggerOut;LTPType;"
	protStr += "alternateDACOutputState;alternateDigitalOutputState;cellID;digitizerADCs;digitizerDACs;digitizerTotalDigitalOuts;digitizerSynchDigitalOuts;digitizerType"
	
	Make/FREE protocolSectionBitFormat = {2,4,1,1,3,4,4,3,3,3,3,3,2,2,2,4,2,2,2,4,4,4,3,4,2,4,2,3,3,3,2,4,3,2,4,4,3,3,2,2,2,3,2,2,2,2,2,2,2,2,2,2,2,3,2,2,4,2,2,2,2,2,2,2,2,4,2,2,2,2,2}
	protocolSectionBitFormat[3] += 2
	protocolSectionBitFormat[64] += 8
	
	String bitPositions = "0;2;6;7;10;14;18;22;26;30;34;38;42;44;46;48;52;54;56;58;62;66;70;74;78;80;84;86;90;94;98;100;104;108;110;114;"
	bitPositions += "118;122;126;128;130;132;136;138;140;142;144;146;148;150;152;154;156;158;162;164;166;170;172;174;176;178;180;182;184;194;198;200;202;204;206;"
	
	Make/FREE/N=(DimSize(protocolSectionBitFormat,0) + 1) protocolSectionBitOffset
	protocolSectionBitOffset[1,DimSize(protocolSectionBitOffset,0) - 1] = protocolSectionBitFormat[p - 1] + protocolSectionBitOffset[p-1]

	Variable returnVar = 0
	
	//Channel scale factor
	Variable index = WhichListItem(param,protStr,";")
	
	If(index == -1)
		return -1
	EndIf
	
	Variable bitOffset = str2num(StringFromList(index,bitPositions,";"))
	
	Variable offset = ProtSection[0] * 512 + bitOffset
	FSetPos refnum,offset
	
	Variable bitFormat = protocolSectionBitFormat[index]
	FBInRead/B=3/F=(bitFormat) refnum,returnVar
	
	return returnVar
End


Static Function/Wave GetProtocolSection(refnum)
	Variable refnum
	
	//Section list
	String sectionStr = "ProtocolSection;ADCSection;DACSection;EpochSection;ADCPerDACSection;EpochPerDACSection;UserListSection;StatsRegionSection;MathSection;"
	sectionStr += "StringsSection;DataSection;TagSection;ScopeSection;DeltaSection;VoiceTagSection;SynchArraySection;AnnotationSection;StatsSection;"
	
	//Data start byte and data length
	Variable whichSection = WhichListItem("ProtocolSection",sectionStr,";")
	Variable offset = 76 + 16 * whichSection
	
	Make/N=3/FREE ProtocolSection
	
	Variable tempVar
	
	//uBlockIndex
	FSetPos refnum,offset
	FBInRead/B=3/F=3/U refnum,tempVar
	ProtocolSection[0] = tempVar
	//uBytes
	FSetPos refnum,offset+4
	FBInRead/B=3/F=3/U refnum,tempVar
	ProtocolSection[1] = tempVar
	//numEntries
	FSetPos refnum,offset+8
	FBInRead/B=3/F=6 refnum,tempVar
	ProtocolSection[2] = tempVar
	
	return ProtocolSection
End

Static Function/Wave GetStringsSection(refnum)
	Variable refnum
	
	//Section list
	String sectionStr = "ProtocolSection;ADCSection;DACSection;EpochSection;ADCPerDACSection;EpochPerDACSection;UserListSection;StatsRegionSection;MathSection;"
	sectionStr += "StringsSection;DataSection;TagSection;ScopeSection;DeltaSection;VoiceTagSection;SynchArraySection;AnnotationSection;StatsSection;"
	
	//Data start byte and data length
	Variable whichSection = WhichListItem("StringsSection",sectionStr,";")
	Variable offset = 76 + 16 * whichSection
	
	Make/N=3/FREE StringsSection
	
	Variable tempVar
	
	//uBlockIndex
	FSetPos refnum,offset
	FBInRead/B=3/F=3/U refnum,tempVar
	StringsSection[0] = tempVar
	//uBytes
	FSetPos refnum,offset+4
	FBInRead/B=3/F=3/U refnum,tempVar
	StringsSection[1] = tempVar
	//numEntries
	FSetPos refnum,offset+8
	FBInRead/B=3/F=6 refnum,tempVar
	StringsSection[2] = tempVar
	
	return StringsSection
End

Static Function/Wave GetADCSection(refnum)
	Variable refnum
	
	//Section list
	String sectionStr = "ProtocolSection;ADCSection;DACSection;EpochSection;ADCPerDACSection;EpochPerDACSection;UserListSection;StatsRegionSection;MathSection;"
	sectionStr += "StringsSection;DataSection;TagSection;ScopeSection;DeltaSection;VoiceTagSection;SynchArraySection;AnnotationSection;StatsSection;"
	
	//ADC Section Info
	Variable whichSection = WhichListItem("ADCSection",sectionStr,";")
	Variable offset = 76 + 16 * whichSection
	
	Make/N=3/FREE ADCSection
	
	Variable tempVar
	
	//uBlockIndex
	FSetPos refnum,offset
	FBInRead/B=3/F=3/U refnum,tempVar
	ADCSection[0] = tempVar
	//uBytes
	FSetPos refnum,offset+4
	FBInRead/B=3/F=3/U refnum,tempVar
	ADCSection[1] = tempVar
	//numEntries
	FSetPos refnum,offset+8
	FBInRead/B=3/F=6 refnum,tempVar
	ADCSection[2] = tempVar
	
	return ADCSection
End

Static Function GetADCParam(refnum,ADCSection,whichChannel,param)
	Variable refnum
	Wave ADCSection
	Variable whichChannel
	String param
	
	String adcStr = "ADCNum;telegraphEnable;telegraphInstrument;telegraphAdditGain;telegraphFilter;telegraphMembraneCap;telegraphMode;"
	adcStr += "telegraphAccessResistance;ADCPtoLChannelMap;ADCSamplingSeq;ADCProgrammableGain;ADCDisplayAmplification;ADCDisplayOffset;"
	adcStr += "instrumentScaleFactor;instrumentOffset;signalGain;signalOffset;signalLowpassFilter;signalHighpassFilter;lowpassFilterType;"
	adcStr += "highpassFilterType;postProcessLowpassFilter;postProcessLowpassFilterType;enabledDuringPN;StatsChannelPolarity;ADCChannelNameIndex;ADCUnitsIndex"
	
	String adcBitFormat = "2;2;2;4;4;4;2;4;2;2;4;4;4;4;4;4;4;4;4;1;1;4;1;1;2;3;3;"
	String adcBitOffset = "0;2;4;6;10;14;18;20;24;26;28;32;36;40;44;48;52;56;60;64;65;66;70;71;72;74;77;80;"
	
	Variable returnVar = 0
	
	//Channel scale factor
	Variable index = WhichListItem(param,adcStr,";")
	
	If(index == -1)
		return -1
	EndIf
	
	Variable bitOffset = str2num(StringFromList(index,adcBitOffset,";"))
	
	Variable offset = ADCSection[0] * 512 + ADCSection[1]*whichChannel + bitOffset
	FSetPos refnum,offset
	
	Variable bitFormat = str2num(StringFromList(index,adcBitFormat,";"))
	FBInRead/B=3/F=(bitFormat) refnum,returnVar
	
	return returnVar
End


//Returns the unit for the input channel number
Function/S pClamp_GetChannelUnit(refnum,channel)
	Variable refnum,channel
	
	Wave StringsSection = GetStringsSection(refnum)
	
	//Longer strings information about the recording
	FSetPos refnum,StringsSection[0]*512
	String bigString = ""
	bigString = PadString(bigString,StringsSection[1],0)
	FBInRead refnum,bigString
	String progStr = "clampex;clampfit;axoscope;patchexpress"
	Variable goodStart,j,i
	For(i=0;i<4;i+=1)
		goodStart = strsearch(bigString,StringFromList(i,progStr,";"),0,2)
		If(goodStart)
			break
		EndIf
	EndFor
	
	Variable lastSpace = 0
	Variable nextSpace

	bigString = bigString[goodStart,strlen(bigString)]
	Make/FREE/T/N=1 Strings
	Strings[0] = ""
	For(i=0;i<30;i+=1)
		Redimension/N=(i+1) Strings
		nextSpace = strsearch(bigString,"\u0000",lastSpace)
		If(nextSpace == -1)
			Redimension/N=(i) Strings
			break
		EndIf
		Strings[i] = bigString[lastSpace,nextSpace-1]
		lastSpace = nextSpace + 1
	EndFor
	
	String unit = Strings[3 + 2 * channel]
	
	String channelBase = unit[1,strlen(unit)-1]
	
	return channelBase
End

//returns the number of channels in a pclamp file
Static Function pClamp_nChannels(file)
	String file //this needs to be a full path to the file
	
	file = RemoveEnding(file,".abf") + ".abf"
	
	Variable refnum,nSweeps
	
	Open/R/Z=2 refnum as file
		
	If(V_flag == -1 || V_flag > 0)
		return 0
	EndIf
	
	Wave ADCSection = GetADCSection(refnum)
	Variable nChannels = ADCSection[2]
	
	Close/A
	
	return nChannels
End

//Retrieves stimulus data from a WaveSurfer HDF5 file that has logged StimGen data
Static Function GetStimulusData(fileID)
	Variable fileID
	
	Wave/T wsStimulusDataListWave = root:Packages:NT:wsStimulusDataListWave
	
	If(!WaveExists(wsStimulusDataListWave))
		return 0
	EndIf
	
	//Get the groups in the file
	HDF5ListGroup/F/R/TYPE=1 fileID,"/"
	S_HDF5ListGroup = ListMatch(S_HDF5ListGroup,"/StimGen*",";")
	
	If(!strlen(S_HDF5ListGroup))
		Redimension/N=(0,2) wsStimulusDataListWave
		return 0
	EndIf
	
	HDF5ListGroup/TYPE=1/Z fileID,"/StimGen/Stimulus"
	Variable numGroups = ItemsInList(S_HDF5ListGroup,";")
	
	HDF5ListAttributes/TYPE=1/Z fileID,"/StimGen/Stimulus/0"
	Variable numAttr = ItemsInList(S_HDF5ListAttributes,";")
	
	Variable i,j
	
	//Get the stimulus name
	String path = "/StimGen/Stimulus"
	HDF5LoadData/Z/Q/O/A="Name"/TYPE=1/N=stimData fileID, path
	Wave/T data = $StringFromList(0,S_waveNames,";")
	String stimName = data[0]
	KillWaves/Z data
	
	Redimension/N=(numAttr + 1,numGroups + 1) wsStimulusDataListWave
	
	wsStimulusDataListWave[0][0] = "Stimulus"
	wsStimulusDataListWave[0][1] = stimName
	
	For(j=0;j<numGroups;j+=1)
		Variable objectNum = str2num(StringFromList(j,S_HDF5ListGroup,";"))
		For(i=0;i<numAttr;i+=1)
			String attr = StringFromList(i,S_HDF5ListAttributes,";")
			String value = GetAttribute(fileID,objectNum,attr)
			wsStimulusDataListWave[i+1][0] = attr //+1 leaves room at the top for the stimulus name
			wsStimulusDataListWave[i+1][j + 1] = value	
		EndFor
	EndFor
End

 
//Returns an attribute
Static Function/S GetAttribute(fileID,objectNum,attr)
	Variable fileID,objectNum
	String attr
	
	DFREF saveDF = GetDataFolderDFR()
	SetDataFolder root:Packages:NT
	
	String path = "/StimGen/Stimulus/" + num2str(objectNum)
	
	HDF5LoadData/Z/Q/O/A=attr/TYPE=1/N=stimData fileID, path
	String stimWave = StringFromList(0,S_waveNames,";")
	
	Variable type = WaveType($stimWave,1)
	
	switch(type)
		case 0:
			return ""
			break
		case 1:
			Wave data = $stimWave
			String value = num2str(data[0])
			break
		case 2:
			Wave/T textData = $stimWave
			value = textData[0]
			break
	endswitch
	
	KillWaves/Z data,textData
	SetDataFolder saveDF
	
	return value
End

//Appends the selected waves to the viewer graph
Static Function AppendSelection(optionStr,graphStr)
	String optionStr,graphStr //optionStr is "" for normal channel plot, "hist" for histograms
	
	Variable i
	
	//Get the waves
	Wave/WAVE refs = GetSelectedWaves(optionStr)

	For(i=0;i<DimSize(refs,0);i+=1)
		Wave theWave = refs[i]
		
		If(WaveExists(theWave))
			AppendToGraph/W=$graphStr theWave
		EndIf
	EndFor
	
	ControlInfo/W=NL horTrace
	If(V_Value)
		SeparateTraces("horiz",graphStr,0)
	EndIf
	
	ControlInfo/W=NL vertTrace
	If(V_Value)
		SeparateTraces("vert",graphStr,0)
	EndIf
	
	GetAxis/W=$graphStr/Q left
	
	ModifyGraph/W=$graphStr  margin(left)=28,margin(bottom)=28,margin(right)=7,margin(top)=7,gfSize=8
					
	GetWindow/Z NL#HistViewer activeSW
	
	ControlInfo/W=NL doHistogram
	If(V_Value && !V_flag)
		String list = AxisList("NL#HistViewer")
		list = ListMatch(list,"bottom*",";")
		
		For(i=0;i<ItemsInList(list,";");i+=1)
			String ax = StringFromList(i,list,";")
			ModifyGraph/W=NL#HistViewer noLabel($ax)=2,axThick($ax)=0,standoff($ax)=0
			
			//Gets the live viewer version of the axis, and equalizes the scaling
			GetAxis/W=NL#LiveViewer/Q $ax
			SetAxis/W=NL#HistViewer $ax,V_min,V_max
		EndFor
	
		
		If(!cmpstr(graphStr,"NL#HistViewer"))
			ModifyGraph/W=NL#HistViewer noLabel(bottom)=2,axThick(bottom)=0,standoff(bottom)=0
		EndIf
	
	EndIf	
	
	ColorViewerGraph()
	
	DoUpdate/W=$graphStr
	
	//only update the threshold bar if we updated the live viewer
	If(!strlen(optionStr))
		AppendThresholdBar()
		AppendRangeBar()
	EndIf
End


//Splits traces on the Viewer either horizontally or vertically
Static Function SeparateTraces(orientation,graphStr,reset)
	String orientation,graphStr
	Variable reset
	
	DFREF NLF = root:Packages:NeuroLive
	
	String traceList = TraceNameList(graphStr,";",1)
	String theTrace,prevTrace
	Variable numTraces,i,traceMax,traceMin,traceMinPrev,traceMaxPrev,offset
	offset = 0
	
	numTraces = ItemsInList(traceList,";")
	
	Variable separateAxis = 1
	
	strswitch(orientation)
		case "vert":
			If(reset)
				For(i=0;i<numTraces;i+=1)
					theTrace = StringFromList(i,traceList,";")
					offset = 0
					ModifyGraph/W=$graphStr offset($theTrace)={0,offset}
					
				EndFor	
			Else
				For(i=1;i<numTraces;i+=1)
					theTrace = StringFromList(i,traceList,";")
					Wave theTraceWave = TraceNameToWaveRef(graphStr,theTrace)
					traceMin = WaveMin(theTraceWave)
					traceMax = WaveMax(theTraceWave)
					Wave prevTraceWave = TraceNameToWaveRef(graphStr,StringFromList(i-1,traceList,";"))
					traceMinPrev = WaveMin(prevTraceWave)
					traceMaxPrev = WaveMax(prevTraceWave)
					offset += 1.05 * abs(traceMaxPrev) //add 10% buffer to separate traces vertically
					
					String axisName = "left_" + num2str(i)
					
					ModifyGraph/W=$graphStr offset($theTrace)={0,offset}
					
					If(!cmpstr(graphStr,"NL#HistViewer"))
						ModifyGraph/W=NL#HistViewer noLabel(bottom)=2,axThick(bottom)=0,standoff(bottom)=0
					EndIf
				EndFor
								
			EndIf
			
			break
		case "horiz":
			If(reset)
				For(i=0;i<numTraces;i+=1)
					theTrace = StringFromList(i,traceList,";")
					offset = 0
					ChangeAxis(theTrace,graphStr,"bottom","hor")
					ModifyGraph/W=$graphStr offset($theTrace)={offset,0},zero(left)=3,zeroThick(left)=0.5
					
					If(!cmpstr(graphStr,"NL#HistViewer"))
						ModifyGraph/Z/W=NL#HistViewer noLabel(bottom)=2,axThick(bottom)=0,standoff(bottom)=0
					EndIf
				EndFor	
			Else
				For(i=1;i<numTraces;i+=1)
					theTrace = StringFromList(i,traceList,";") //backwards
					Wave theTraceWave = TraceNameToWaveRef(graphStr,theTrace)
					traceMin = DimOffset(theTraceWave,0)
					traceMax = IndexToScale(theTraceWave,DimSize(theTraceWave,0)-1,0)
					Wave prevTraceWave = TraceNameToWaveRef(graphStr,StringFromList(i-1,traceList,";"))
					traceMinPrev = DimOffset(prevTraceWave,0)
					traceMaxPrev = IndexToScale(prevTraceWave,DimSize(prevTraceWave,0)-1,0)
//					offset += abs(traceMinPrev+traceMax)
					ModifyGraph/W=$graphStr zero(left)=3,zeroThick(left)=0.5
				EndFor
				
				If(separateAxis)
					For(i=numTraces-1;i> -1;i-=1) //backwards
						theTrace = StringFromList(i,traceList,";")
						axisName = "bottom_" + num2str(i)
						ChangeAxis(theTrace,graphStr,axisName,"hor")
						ModifyGraph/W=$graphStr axisEnab($axisName)={(i)/numTraces,(i+1)/numTraces},zero(left)=3,zeroThick(left)=0.5,freePos($axisName)=0
						
						If(!cmpstr(graphStr,"NL#HistViewer"))
							ModifyGraph/W=NL#HistViewer noLabel($axisName)=2,axThick($axisName)=0,standoff($axisName)=0
						EndIf
					EndFor
				EndIf
				
			EndIf
			break
	endswitch
	
	
End

//Moves a trace from its current axis to the named axis
Static Function ChangeAxis(theTrace,theGraph,axisName,orient)
	String theTrace,theGraph,axisName,orient
	
	String axes = axisList(theGraph)
	strswitch(orient)
		case "hor":		
			Wave theWave = TraceNameToWaveRef(theGraph,theTrace)
			RemoveFromGraph/Z/W=$theGraph $theTrace
			AppendToGraph/W=$theGraph/B=$axisName/L theWave 
			break
		case "vert":
			Wave theWave = TraceNameToWaveRef(theGraph,theTrace)
			RemoveFromGraph/Z/W=$theGraph $theTrace
			AppendToGraph/W=$theGraph/B/L=$axisName theWave 
			break
	endswitch	
End

//Appends a calibrator for the axes
Static Function AppendCalibrator()

	//Get the range of the x and y axes
	GetAxis/Q/W=NL#LiveViewer left
	Variable yMin,yMax,yRange,yBottom,yTop
	yMin = V_min
	yMax = V_max
	yRange = yMax - yMin
	yBottom = yMin + 0.6 * yRange //10% of the range
	yTop = yMin + 0.7 * yRange
	
	GetAxis/Q/W=NL#LiveViewer bottom
	Variable xMin,xMax,xRange,xLeft,xRight
	xMin = V_min
	xMax = V_max
	xRange = xMax - xMin
	xLeft = xMin + 0.1 * xRange //10% of the range
	xRight = xMin + 0.2 * xRange
	
	SetDrawLayer/W=NL#LiveViewer UserBack
	DrawAction/W=NL#LiveViewer getgroup=xCal,delete
	DrawAction/W=NL#LiveViewer getgroup=yCal,delete
	
	SetDrawEnv/W=NL#LiveViewer gstart,gname=xCal
	SetDrawEnv/W=NL#LiveViewer xcoord=bottom,ycoord=rel,fsize=6,linethick=0.5
	DrawLine/W=NL#LiveViewer xLeft,0.5,xRight,0.5
	SetDrawEnv/W=NL#LiveViewer gstop
	
	SetDrawEnv/W=NL#LiveViewer gstart,gname=yCal
	SetDrawEnv/W=NL#LiveViewer xcoord=rel,ycoord=left,fsize=6,linethick=0.5
	DrawLine/W=NL#LiveViewer 0.5,yBottom,0.5,yTop
	SetDrawEnv/W=NL#LiveViewer gstop
	
	DoUpdate/W=NL#LiveViewer
End

//Fills the rows of a text wave with the items from a string list
Static Function/WAVE StringListToTextWave(list,textWave,separator[,col,lay])
	String list
	Wave/T textWave
	String separator
	Variable col,lay
	
	If(ParamIsDefault(col))
		col = 0
	EndIf
	
	If(ParamIsDefault(lay))
		lay = 0
	EndIf
	
	Redimension/N=(ItemsInList(list,separator),-1,-1) textWave
	Variable i
	For(i=0;i<ItemsInList(list,separator);i+=1)
		textWave[i][col][lay] = StringFromList(i,list,separator)
	EndFor
	
	return textWave
End

//Goes in to each wavesurfer file and expands it to include the list of sweeps inside it
Static Function/S GetWSSweeps(fileList)
	String fileList
	Variable i,j,k
	
	PathInfo/S filePath
	String parent = ParseFilePath(0,S_path,":",1,0)
	
	String sweepList = ""
	Variable color = 0
	
	For(k=0;k<ItemsInList(fileList,";");k+=1)
		String theFile = StringFromList(k,fileList,";")

		//Open the HDF5 file read only
		Variable fileID
		HDF5OpenFile/P=filePath/Z/R fileID as theFile

		If(V_flag)
			Abort "Couldn't load the file: " + theFile
		EndIf
		
		//How many channels were recorded
		HDF5LoadData/N=ch/Q fileID,"/header/AIChannelNames"
		Wave/T ch = ch
		Variable numCh = DimSize(ch,0)
		String prefix = ""
		
		//Extract the wave name prefixes that are being used
		For(j=0;j<numCh;j+=1)
			String chName = ch[j]
			If(stringmatch(chName,"*Current*") || stringmatch(chName,"*I*") || stringmatch(chName,"*Im*"))
				prefix += "Im#"
			ElseIf(stringmatch(chName,"*Voltage*") || stringmatch(chName,"*V*") || stringmatch(chName,"*Vm*"))
				prefix += "Vm#"
			EndIf
		EndFor
		
		KillWaves/Z ch
		
		//Get the groups in the file
		HDF5ListGroup/F/R/TYPE=1 fileID,"/"
		
		//Finds the data sweep groups
		S_HDF5ListGroup = ListMatch(S_HDF5ListGroup,"/sweep*",";")
		
		S_HDF5ListGroup = ReplaceString("/",S_HDF5ListGroup,parent + ":" + theFile + "/")
		Variable numSweeps = ItemsInList(S_HDF5ListGroup,";")
		
		For(j=0;j<numSweeps;j+=1)
			S_HDF5ListGroup = ReplaceListItem(j,S_HDF5ListGroup,";",num2str(color) + "//" + prefix + "//" + num2str(numCh) + "//" + StringFromList(j,S_HDF5ListGroup,";"))
		EndFor
		
		
		sweepList += S_HDF5ListGroup + ";"
		
		color = (color) ? 0 : 1
	EndFor

	return sweepList
End

//Loads and scales sweeps loaded from an HDF5 file made by WaveSurfer electrophysiology software
Static Function Load_WaveSurfer(String fileList[,String channels])
	
	If(ParamIsDefault(channels))
		channels = "All"
	EndIf
	
	//Reformat the path for colons
	String path = ReplaceString("/",fileList,":")
	
	//Clean up leading colons
	If(!cmpstr(path[0],":"))
		path = path[1,strlen(path)-1]
	EndIf
	
	Variable k,m
	For(k=0;k<ItemsInList(fileList,";");k+=1)
		String theFile = StringFromList(k,fileList,";")
		
		String theSweep = "/" + StringFromList(1,theFile,"/")
		theFile = StringFromList(0,theFile,"/") //eliminates the sweep
				
		//Get the file name
		String fileName = ParseFilePath(0,theFile,":",1,0)
		
		//Get the folder path
		String folderPath = ParseFilePath(1,theFile,":",1,0)
	
	
		//Open the HDF5 file read only
		Variable fileID
		HDF5OpenFile/P=filePath/Z/R fileID as fileName

		If(V_flag)
			Abort "Couldn't load the file: " + path
		EndIf
		
		//Get the groups in the file
		HDF5ListGroup/F/R/TYPE=1 fileID,"/"
	
		//Finds the data sweep groups
		S_HDF5ListGroup = ListMatch(S_HDF5ListGroup,"/sweep*",";")
		
		Variable i,j,numSweeps = ItemsInList(S_HDF5ListGroup,";")
		
		//Load the scaling coefficients from the header
		HDF5LoadData/N=coef/Q fileID,"/header/AIScalingCoefficients"
		HDF5LoadData/N=scale/Q fileID,"/header/AIChannelScales"
		HDF5LoadData/N=unit/Q fileID,"/header/AIChannelUnits"
		HDF5LoadData/N=rate/Q fileID,"/header/AcquisitionSampleRate"
		HDF5LoadData/N=ch/Q fileID,"/header/AIChannelNames"
		HDF5LoadData/N=prot/Q fileID,"/header/AbsoluteProtocolFileName"
		
		Wave scale = :scale
		Wave coef = :coef
		Wave/T unit = :unit
		Wave rate = :rate
		Wave/T ch = :ch
		Wave/T prot = :prot
		
	   String protocol = RemoveEnding(ParseFilePath(0,prot[0],"\\",1,0),".wsp")
		String folder = "root:Ephys:" + ParseFilePath(0,S_path,":",1,0)
		
		If(!DataFolderExists("root:Ephys"))
			NewDataFolder root:Ephys
		EndIf
		
		folder = ReplaceString(" ",folder,"")
		
		If(!DataFolderExists(folder))
			NewDataFolder $folder
		EndIf
		
		//Get the stimulus data, if available
		GetStimulusData(fileID)
		Wave/T stimData = root:Packages:NT:wsStimulusDataListWave
		
		SetDataFolder $folder
		
		//Load the sweeps into waves
		Make/Wave/FREE/N=0 sweepRefs
		
		Variable whichSweep = WhichListItem(theSweep,S_HDF5ListGroup,";")
		
		If(whichSweep == -1)
			//Cleanup
			KillWaves/Z coef,scale,unit,rate,ch,prot
			return 0
		EndIf
		
		String dataSet = StringFromList(whichSweep,S_HDF5ListGroup,";") + "/analogScans"
		String name = UniqueName("analogScans",1,0)
		HDF5LoadData/N=$name/Q fileID,dataSet
		
		//Declare the loaded wave
		Wave data = $StringFromList(0,S_WaveNames,";")
		
		//Make sure its a single float, so it can handle the scaling
		Redimension/S data
		
		//Get the sweep index, truncate zeros
		theSweep = StringFromList(1,StringFromList(whichSweep,S_HDF5ListGroup,";"),"_")
		
		j = 0
		Do
			If(!cmpstr(theSweep[j],"0"))
				theSweep = theSweep[j+1,strlen(theSweep)-1] //truncate leading zeros
				continue
			Else
				break
			EndIf
			
			j += 1
		While(j < strlen(theSweep)-1)
		
		
		//Scale the data
		Variable mult
		For(j=0;j<DimSize(data,0);j+=1)
			String theUnit = unit[j]
			
			//multiplier to get the units correct to Amps or Volts
			strswitch(theUnit[0])
				case "m": //milli
					mult = 1e-3
					break
				case "µ": //micro
					mult = 1e-6
					break
				case "n": //nano
					mult = 1e-9
					break
				case "p": //pico
					mult = 1e-12
					break
				default:
			endswitch
			
			If(!cmpstr(ch[j],channels) || !cmpstr(channels,"All"))	
				Multithread data[j][] = ( (data[j][q] / scale[j]) * coef[j][1] + (coef[j][0] / scale[j]) ) * mult
				
				//Split the channels - puts wave into a folder that is the immediate subfolder
				//of the file.
				
				String prefix = ch[j]
				If(stringmatch(prefix,"*Current*") || stringmatch(prefix,"*I*") || stringmatch(prefix,"*Im*"))
					prefix = "Im"
					String chScale = "A"
				ElseIf(stringmatch(prefix,"*Voltage*") || stringmatch(prefix,"*V*") || stringmatch(prefix,"*Vm*"))
					prefix = "Vm"
					chScale = "V"
				EndIf
				
				String channelName = prefix + "_" + theSweep + "_1_1_" + num2str(j + 1)
				Make/O/N=(DimSize(data,1))/S $channelName
				Wave channel = $channelName
				
				Multithread channel = data[j][p]
				SetScale/P x,0,1/rate[0],"s",channel //seconds
				
				SetScale/P y,0,1,chScale,channel //channel scale
				
				//Set the wave note
				Note/K channel,"Path: " + path
				Note channel,"Protocol: " + protocol
				
				//Set the stimulus data note, extracting any sequences
				If(DimSize(stimData,0) > 0)
					For(m=0;m<DimSize(stimData,0);m+=1)
						String line = stimData[m][1]
						If(ItemsInList(line,";") > 1)
							Note channel,stimData[m][0] + ": " + StringFromList(whichSweep,line,";")
						Else
							Note channel,stimData[m][0] + ": " + line
						EndIf	
					EndFor
				EndIf
			EndIf 
		EndFor
	
		//Cleanup
		KillWaves/Z data,coef,scale,unit,rate,ch,prot	
		
		//Close file
		HDF5CloseFile/A fileID
	EndFor

End


//Much improved ABF2 loader - doesn't bother with a lot of the unnecessary header information,
//uses multi-threading, and also optimized some wave assignments. Overall about 5-6x faster than NeuroMatic. 
Static Function NL_LoadPClamp(fileList[,channels])
	String fileList
	String channels
	
	Variable refnum
	
	STRUCT NL_abfInfo a
	
	Variable f
	
	For(f=0;f<ItemsInList(fileList,";");f+=1)
	
		Variable refTime = StartMSTimer
			
		String filePath = StringFromList(f,fileList,";")
		filePath = RemoveEnding(filePath,".abf") + ".abf" //"ASTRODRIVE:Data:Ephys:2017:08:R2_170808:170808_01_0000.abf"
		
		Variable tempVar = 0
		String tempStr = ""
		
		Open/R/Z=2 refnum as filepath
		
		If(V_flag == -1)
			return 0
		EndIf
		
		FStatus refnum
		Variable eof = V_logEOF
		
		//Number sweeps
		FSetPos refnum,12
		FBInRead/B=3/F=3 refnum,a.nSweeps
		
		//Data format
		FSetPos refnum,30
		FBInRead/B=3/F=2 refnum,a.dataFormat
		
		Variable dataSz	,bitFormat
		switch(a.dataFormat)
			case 0:
				dataSz = 2 //bytes/point
				bitFormat = 2
				break
			case 1:
				dataSz = 4 //bytes/point
				bitFormat = 3
				break
			default:
				DoAlert 0,"Invalid number format"
				return -1
				break
		endswitch
	
		//Section info
		Wave ADCSection = GetADCSection(refnum)
		Wave DataSection = GetDataSection(refnum)
		Wave ProtocolSection = GetProtocolSection(refnum)
		Wave StringsSection = GetStringsSection(refnum)
		Wave SynchArraySection = GetSynchSection(refnum)
		
		//Number channels
		a.nChannels = ADCSection[2]
		
		//Start bytes for the data
		a.startByte = DataSection[0] * 512
		a.dataPoints = DataSection[2]
		
		//Synch array for some data location/scaling things
		a.synchArray[0] = SynchArraySection[0]
		a.synchArray[1] = SynchArraySection[1]
		a.synchArray[2] = SynchArraySection[2]
		
		//Longer strings information about the recording
		FSetPos refnum,StringsSection[0]*512
		String bigString = ""
		bigString = PadString(bigString,StringsSection[1],0)
		FBInRead refnum,bigString
		String progStr = "clampex;clampfit;axoscope;patchexpress"
		Variable goodStart,j,i
		For(i=0;i<4;i+=1)
			goodStart = strsearch(bigString,StringFromList(i,progStr,";"),0,2)
			If(goodStart)
				break
			EndIf
		EndFor
		
		Variable lastSpace = 0
		Variable nextSpace
	
		bigString = bigString[goodStart,strlen(bigString)]
		Make/FREE/T/N=1 Strings
		Strings[0] = ""
		For(i=0;i<30;i+=1)
			Redimension/N=(i+1) Strings
			nextSpace = strsearch(bigString,"\u0000",lastSpace)
			If(nextSpace == -1)
				Redimension/N=(i) Strings
				break
			EndIf
			Strings[i] = bigString[lastSpace,nextSpace-1]
			lastSpace = nextSpace + 1
		EndFor
		
		//Get the Channel names, units, and scales
		a.ChannelNames = ""
		a.ChannelUnits = ""
		a.ChannelBase = ""
		
		For(i=0;i<a.nChannels;i+=1)
	
			String name = Strings[2 + 2 * i]
			String unit = Strings[3 + 2 * i]
			
			a.ChannelNames += name + ";"
			a.ChannelUnits += unit + ";"
			a.ChannelScale[i] = 0 //reset
			a.ChannelBase += unit[1,strlen(unit)-1] + ";"
			
			String scalePrefix = unit[0]
			strswitch(scalePrefix)
				case "k":
					a.ChannelScale[i] = 1e3
					break
				case "m":
					a.ChannelScale[i] = 1e-3
					break
				case "µ":
				case "u":
					a.ChannelScale[i] = 1e-6
					break
				case "n":
					a.ChannelScale[i] = 1e-9
					break
				case "p":
					a.ChannelScale[i] = 1e-12
					break
				default:
					a.ChannelScale[i] = 1
					break
			endswitch
		EndFor
		
		//ADC data
		For(i=0;i<a.nChannels;i+=1)
			a.scaleFactor[i] = GetADCParam(refnum,ADCSection,i,"instrumentScaleFactor")
			a.signalGain[i] = GetADCParam(refnum,ADCSection,i,"signalGain")
			a.ADCprogrammableGain[i] = GetADCParam(refnum,ADCSection,i,"ADCProgrammableGain")
			a.instrumentOffset[i] = GetADCParam(refnum,ADCSection,i,"instrumentOffset")
			a.signalOffset[i] = GetADCParam(refnum,ADCSection,i,"signalOffset")
			a.ChannelIndex[i] = GetADCParam(refnum,ADCSection,i,"ADCNum")
		EndFor
		
		a.startByte = DataSection[0] * 512
		a.dataPoints = DataSection[2]
		
		a.synchArrTimeBase = GetProtocolParam(refnum,ProtocolSection,"synchTimeUnit")
		a.ADCSampleInterval = GetProtocolParam(refnum,ProtocolSection,"ADCSequenceInterval") / a.nChannels
		a.actualSampleInterval = a.ADCSampleInterval * a.nChannels
		a.ADCRange = GetProtocolParam(refnum,ProtocolSection,"ADCRange")
		a.ADCResolution = GetProtocolParam(refnum,ProtocolSection,"ADCResolution")
			
		//Synch Array information and sweep pointers
		a.synchArrayPtrByte = 512 * a.synchArray[0]
		
		FSetPos refnum,a.synchArrayPtrByte
		Make/FREE/N=(a.synchArray[2]*2) synchArray
		FBInRead/B=3/F=3 refnum,synchArray
		
		Redimension/N=(-1,2) synchArray
		Make/N=(a.synchArray[2])/FREE temp1,temp2
	
		Variable count1,count2
		count1 = 0
		count2 = 0
		For(i=0;i<DimSize(synchArray,0);i+=1)
			If(mod(i,2) == 0)
				temp1[count1] = synchArray[i][0]
				count1 += 1 					
			Else
				temp2[count2] = synchArray[i][0] 	
				count2 += 1	
			EndIf
		EndFor
	
		Redimension/N=(a.synchArray[2],2) synchArray
		synchArray[][0] = temp1[p][0]
		synchArray[][1] = temp2[p][0]
		
		a.sweepLengthInPts = synchArray[0][1]/a.nChannels
		
		//Kept as wave instead of structure element because I have to dimension it according to the number of sweeps
		Make/N=(DimSize(synchArray,0))/FREE sweepStartInPts
		sweepStartInPts = synchArray * (a.synchArrTimeBase/a.ADCSampleInterval/a.nChannels)
		
		FSetPos refnum,a.startByte
		
		//Sweep list	
		Make/FREE sweeps = x + 1
			
		//Sweep offsets
		Make/FREE/N=(a.nSweeps) selectedSegStartInPts
		a.dataPtsPerSweep = a.sweepLengthInPts * a.nChannels
		
		For(i=0;i<a.nSweeps;i+=1)
			selectedSegStartInPts[i] = (sweeps[i] - 1) * a.dataPtsPerSweep * dataSz + a.startByte
		EndFor
		
		//Loads the data
		Make/FREE/N=(a.dataPtsPerSweep) tempd
		
		Variable c
		For(i=0;i<a.nSweeps;i+=1)
			FSetPos refnum,selectedSegStartInPts[i] //set position to start of each sweep.
			FBInRead/B=3/F=(bitFormat) refnum,tempd	 //load data for all channels recorded for that sweep
			
			String traceList = ""
			
			//Figure out the wave names for each of the channels in each sweep
			For(c=0;c<a.nChannels;c+=1)
				
				String unitBase = StringFromList(c,a.channelBase,";")
				
				//Prefix
				strswitch(unitBase)
					case "A": //amps, voltage clamp
						String prefix = "Im"
						break
					case "V": //volts, current clamp
						prefix = "Vm"
						break
				endswitch
				
				String group = ParseFilePath(0,filePath,":",1,0)
				group = ParseFilePath(0,group,"_",1,0)
				group = ParseFilePath(0,group,".",0,0)
				group = num2str(str2num(group))
				String series = num2str(i+1)
				String sweep = "1"
				String trace = "1"
				
				String traceName = prefix + "_" + group + "_" + series + "_" + sweep + "_" + trace
				Do
					//Check for duplicates, if so increment the trace counter
					If(WhichListItem(traceName,traceList,";") != -1)
						trace = num2str(str2num(trace) + 1)
						traceName = prefix + "_" + group + "_" + series + "_" + sweep + "_" + trace
					Else
						break
					EndIf
				While(1)
				
				traceList += traceName + ";"
			EndFor
			
			String folder = ntSeparateChannels(filepath,traceList,channels,tempd,a)
		EndFor
		
				
		Close/A
		
		Variable duration = StopMSTimer(refTime)/1000000
		print "Loaded",filepath,"in",duration,"s"
		
	EndFor
End

Static Function/S ntSeparateChannels(filepath,traceList,channels,tempd,a)
	String filepath,traceList,channels
	Wave tempd
	
	STRUCT NL_abfInfo &a
	
	Variable i,j
	DFREF cdf = GetDataFolderDFR()
	
	j = 0
	Make/FREE/N=(a.dataPtsPerSweep/a.nChannels,a.nChannels) d //name from the first trace name
	
	switch(a.nChannels)
		case 2:
			//Much faster than the original version. Overall load speed is about 5-6x faster than NeuroMatic's ABF2 loader.
			Multithread d[][0] = tempd[p * 2][0]
			Multithread d[][1] = tempd[1 + p * 2][0]
		break
		case 3:
			Multithread d[][0] = tempd[p * 3][0]
			Multithread d[][1] = tempd[1 + p * 3][0]
			Multithread d[][2] = tempd[2 + p * 3][0]
		break
		case 4:
			Multithread d[][0] = tempd[p * 4][0]
			Multithread d[][1] = tempd[1 + p * 4][0]
			Multithread d[][2] = tempd[2 + p * 4][0]
			Multithread d[][2] = tempd[3 + p * 4][0]
			break
		default:
			Multithread d = tempd[p][0]
		break
	endswitch
	
	//Apply scale factors and gains
	For(i=0;i<DimSize(d,1);i+=1)
		//	d[][i] = unitScaleFactor*(d[p][i])/(h.InstrumentScaleFactor[index]*h.signalGain[index]*h.ADCProgrammableGain[index]*addGain[index])*(h.ADCRange/h.ADCResolution) + h.instrumentOffset[index] - h.signalOffset[index]
		Multithread d[][i] = a.ChannelScale[i] * (d[p][i]) / (a.scaleFactor[i] * a.signalGain[i] * a.ADCprogrammableGain[i]) * (a.ADCRange/a.ADCResolution) + a.instrumentOffset[i] - a.signalOffset[i]
	EndFor
	
	//Split the scaled data into channel waves in the correct data folder
	For(j=0;j<a.nChannels;j+=1)
		
		String channelName = num2str(a.ChannelIndex[j])
		
		//Check that the channel is meant to be loaded
		If(cmpstr(channels,"All"))
			Variable index = WhichListItem(channelName,channels,",")
			
			If(index == -1)
				continue
			EndIf
		EndIf
		
//		If(cmpstr(channels,"All"))
//			If(str2num(channels) != j + 1)
//				continue
//			EndIf
//		EndIf
		
		//Make the folder to put the waves in
		If(!DataFolderExists("root:Ephys"))
			NewDataFolder root:Ephys
		EndIf
		
		String outputFolder = ParseFilePath(0,filepath,":",1,1)
		
		//Check for initial numbers - Igor doesn't like folders starting with numbers
		Variable isAlpha = str2num(outputFolder[0])
		If(numtype(isAlpha) != 2)
			outputFolder = "Cell_" + outputFolder
		EndIf
		
		outputFolder = ReplaceString(",",outputFolder,"_")
		
		outputFolder = ReplaceString(" ",outputFolder,"_")
		
		If(!DataFolderExists("root:Ephys:" + outputFolder))
			NewDataFolder $"root:Ephys:" + outputFolder
		EndIf
		
		SetDataFolder $"root:Ephys:" + outputFolder
		
		String traceName = StringFromList(j,traceList,";")
		
		Make/O/N=(DimSize(d,0)) $StringFromList(j,traceList,";")
		Wave outWave = $StringFromList(j,traceList,";")
		
		outWave[] = d[p][j]
		SetScale/P x,0,a.actualSampleInterval/(1e6),"s",outWave
		
		String chScale = StringFromList(j,a.ChannelBase,";")
		SetScale/P y,0,1,chScale,outWave
		
		Note/K outWave,filepath
		
//		//Append stimulus name
//		If(cmpstr(stimChannel,"None"))
//			Note outWave,"Stimulus: " + stimName
//		EndIf
	EndFor
	
	//Cleanup
	KillWaves/Z d
	
	return GetWavesDataFolder(outWave,1)
End



Static Function/S LoadPresentinator(fileName)
	String fileName
	
	
	If(!strlen(fileName))
		return ""
	EndIf
	
	DFREF saveDF = GetDataFolderDFR()
	
	//Make the new ephys folder for the incoming waves
	PathInfo filePath
	String folder = ParseFilePath(0,S_Path,":",1,0)
	
	If(!DataFolderExists("root:EPhys"))
		NewDataFolder root:EPhys
	EndIf
	
	If(!DataFolderExists("root:EPhys:" + folder))
		NewDataFolder $("root:EPhys:" + folder)
	EndIf
	
	SetDataFolder $("root:EPhys:" + folder)
	
	//Create a wave name
	String num = StringFromList(1,fileName,"#")
	num = num[0,2]
	String baseName = "Im_" + num
	
	Variable ref
	
	//Open the .phys file
	Open/R/P=filePath ref as fileName
	
	//HEADER
	Make/T/O/N=(100,2) root:header/Wave=header 
	
	FSetPos ref,4
	String inStr = ""
	String stopText = ""
	Variable i = 0
	
	Do
		FReadLine ref,inStr
		
		If(!strlen(inStr))
			break
		EndIf
		
		String headerItem = StringFromList(0,inStr,":")
		headerItem = ReplaceString("\r",headerItem,"")
		header[i][0] = headerItem
		
		//Presentinator or Pulsinator?
		If(i == 0)
			//Is this a presentinator file or a pulsinator file?
			If(stringmatch(header[0][0],"*Presentinator*"))
				String type = "Presentinator"
				stopText = "*Stimulus Protocol*"
			ElseIf(stringmatch(header[0][0],"*Pulsinator*"))
				type = "Pulsinator"
				stopText = "*Intracellular solution Ch2*"
			EndIf
		EndIf
		
		headerItem = StringByKey(header[i][0],inStr,":","\n")
		headerItem = ReplaceString("\r",headerItem,"")
		
		header[i][1] = headerItem
		
		i += 1	
		
		If(stringmatch(inStr,stopText))
			break
		EndIf
		
	While(i < 100)
	
	Redimension/N=(i,2) header
	
	
	//BMP STIMULUS FILE
	FGetPos ref
	Variable bmpStart = V_filePos
	Variable dataStartPos = bmpStart
	
	FStatus ref
	Variable eof = V_logEOF
	
	If(!cmpstr(type,"Presentinator"))	
		Variable pos = -1
		Do
			inStr = ""
			If(dataStartPos + 1000 > eof)
				inStr = PadString(inStr,eof - dataStartPos,0x20)
			Else
				inStr = PadString(inStr,1000,0x20)
			EndIf
			
			FBInRead/B=2 ref,inStr
			
			pos = strsearch(inStr,"Notes",0)
			
			If(pos != -1)
				dataStartPos += pos
			Else
				dataStartPos += 1000
			EndIf
		While(pos == -1)
		
		//Set file position to the 'Notes:' lines and read one more line to get to the actual dat
		FSetPos ref,dataStartPos
		FReadLine ref,inStr

	EndIf
		

	FGetPos ref
	dataStartPos = V_filePos + 4
	
	FSetPos ref,dataStartPos
	
	Variable inVar,dataLen
	
	//Read the data length
	FBInRead/B=2/F=3 ref,inVar
	dataLen = inVar
	
	dataStartPos += 4
	
	Close/A
	
	//16 bit data, load as a 32 bit float
	//High byte first Big-Endian
	GBLoadWave/Q/B=0/P=filePath/N=data/O=1/T={16,2}/S=(dataStartPos)/U=(dataLen) fileName 
	
	
	//Y scaling
	Variable scaleFactor = str2num(GetHeaderItem(header,"Waveform Scale Factors"))
	scaleFactor = (numtype(scaleFactor) == 2) ?  1 : scaleFactor
	
	//Get the channel scale (pA, mV, etc.)
	String chName = GetHeaderItem(header,"Waveform0 Name")
	chName = ReplaceString(")",StringFromList(1,chName,"("),"")
	
	strswitch(chName)
		case "pA":
			Variable scaleCh = 1e-12
			String scaleName = "A"
			break
		case "mV":
			scaleCh = 1e-3
			scaleName = "V"
			break
		default:
			scaleCh = 1e-12 //default to voltage clamp, measuring current
			scaleName = "A"
			break
	endswitch
	
	scaleFactor *= scaleCh
	
	String sweepList = ""
	
	//Scale the waveform
	For(i=0;i<ItemsInList(S_WaveNames,";");i+=1)
		Wave data = $StringFromList(i,S_WaveNames,";")
		
		//Rename the wave
		KillWaves/Z $(baseName + "_" + num2str(i+1) + "_1_1")
		Rename $NameOfWave(data),$(baseName + "_" + num2str(i+1) + "_1_1")
		
		sweepList += "root:EPhys:" + folder + ":" + baseName + "_" + num2str(i+1) + "_1_1;"
		
		//Y Scaling
		Multithread data *=  scaleFactor
		SetScale/P y,0,1,scaleName,data
		
		//X scaling
		Variable sampleRate = str2num(GetHeaderItem(header,"Sample Rate"))
		sampleRate = (numtype(sampleRate) == 2) ?  1 : sampleRate
		sampleRate = 1/sampleRate
		
		SetScale/P x,0,sampleRate,"s",data
	EndFor
	
	
	SetDataFolder saveDF
	
	return sweepList
End


Function/S GetHeaderItem(header,key)
	Wave/T header
	String key
	
	If(!WaveExists(header))
		return ""
	EndIf
	
	If(!strlen(key))
		return ""
	EndIf
	
	Variable index = tableMatch(key,header)
	If(index == -1)
		return ""
	EndIf
	
	return header[index][1]
End

//If str matches an entry in the tableWave, returns the row, otherwise return -1
Static Function tableMatch(str,tableWave,[startp,endp,returnCol])
	String str
	Wave/T tableWave
	Variable startp,endp,returnCol//for range
	Variable i,j,size = DimSize(tableWave,0)
	Variable cols = DimSize(tableWave,1)
	
	If(cols == 0)
		cols = 1
	EndIf
	
	If(ParamIsDefault(startp))
		startp = 0
	EndIf
	
	If(ParamIsDefault(endp))
		endp = size - 1
	EndIf
	
	If(ParamIsDefault(returnCol))
		returnCol = 0
	EndIf
	
	If(startp > DimSize(tableWave,0) - 1)
		return -1
	EndIf
	
	If(endp < DimSize(tableWave,0) - 1)
		return -1
	EndIf
	
	For(j=0;j<cols;j+=1)
		For(i=startp;i<endp+1;i+=1)
			If(stringmatch(tableWave[i][j][0],str))
				If(returnCol)
					return j
				Else
					return i
				EndIf
			EndIf
		EndFor
	EndFor
	
	return -1
End

//Replaces the indicated list item with the replaceWith string
Static Function/S ReplaceListItem(index,listStr,separator,replaceWith)
	Variable index
	String listStr,separator,replaceWith
	
	listStr = RemoveListItem(index,listStr,separator)
	listStr = AddListItem(replaceWith,listStr,separator,index)
	If(index == ItemsInList(listStr,separator) - 1)
		listStr = RemoveEnding(listStr,separator)
	EndIf
	
	return listStr
End

Function/WAVE GetSelectedWaves(optionStr)
	String optionStr
	
	DFREF NLF = root:Packages:NeuroLive
	Wave/T listWave =  NLF:fileListWave
	Wave selWave =  NLF:fileSelWave
	String list = ""
	
	Make/WAVE/O/N=(DimSize(selWave,0)) NLF:refs/Wave=refs
	
	Variable channel = GetChannel() //-1 means all channels
	
	Variable i,count = 0
	For(i=0;i<DimSize(selWave,0);i+=1)
		If(selWave[i][0][0] > 0)
		
			If(DimSize(listWave,0) < i + 1)
				continue
			EndIf
			
			//Uses the optionStr to select different wave sets
			strswitch(optionStr)
				case "hist":
					If(channel == -1)
						refs[count] = $(StringFromList(0,listWave[i][0][1],";") + "_PSTH")
						count += 1
						refs[count] = $(StringFromList(1,listWave[i][0][1],";") + "_PSTH")
					Else
						refs[count] = $(StringFromList(channel-1,listWave[i][0][1],";") + "_PSTH")
					EndIf
					break
				default:
					If(channel == -1)
						refs[count] = $StringFromList(0,listWave[i][0][1],";")
						count += 1
						refs[count] = $StringFromList(1,listWave[i][0][1],";")
					Else
						refs[count] = $StringFromList(channel-1,listWave[i][0][1],";")
					EndIf
					break
			endswitch
			
			count += 1
		EndIf
	EndFor
	
	Redimension/N=(count) refs

	return refs
End

//Calculates the histogram of the displayed traces using the threshold
Static Function/WAVE GetHistogram(threshold,[w])
	Variable threshold
	Wave w
	
	If(ParamIsDefault(w))
		//only compute it if the histogram control is checked
		ControlInfo/W=NL doHistogram
		If(!V_Value)
			return $""
		EndIf
	EndIf
	
	//Get the waves
	Wave/WAVE refs = GetSelectedWaves("")
	Variable i,j
	
	If(!ParamIsDefault(w))
		Variable numWaves = 1
	Else
		numWaves = DimSize(refs,0)
	EndIf
	
	Make/N=(numWaves)/FREE/WAVE outWaves
	
	For(i=0;i<numWaves;i+=1)
		Wave theWave = refs[i]
		
		If(!ParamIsDefault(w))
			Wave theWave = w
		EndIf
		
		If(!WaveExists(theWave))
			return $""
		EndIf
		
		SetDataFolder GetWavesDataFolder(theWave,1)
		
		//Get spike times and counts
		FindLevels/Q/EDGE=1/M=0.002/D=spktm/T=0.002 theWave,threshold
		Variable numSpikes = V_LevelsFound
		
		//Variables
		ControlInfo/W=NL histType
		String type = S_Value
		
		ControlInfo/W=NL binSize
		Variable binSize = V_Value
		
		//Gaussian or binned histograms
		strswitch(type)
			case "Binned":	
				Variable numBins = ceil((IndexToScale(theWave,DimSize(theWave,0)-1,0) - IndexToScale(theWave,0,0) )/ binSize) //number of bins in wave
				String histName = NameOfWave(theWave) + "_PSTH"
				
				If(numtype(numBins) == 1)
					return $""
				EndIf
				 
				Make/O/N=(numBins) $histName
				Wave hist = $histName
						
				
				If(DimSize(spktm,0) == 0)
					hist = 0
					SetScale/P x,DimOffSet(theWave,0),binSize,hist
				Else
					Histogram/B={pnt2x(theWave,0),binSize,numBins} spktm,hist
				EndIf
				
				hist /= binSize
				
				SetScale/P y,0,1,"Hz",hist
				
				break
			case "Gaussian":
				Variable dT = DimDelta(theWave,0)
				Variable sampleRate = 1000 // 1 ms time resolution
				//gaussian template for convolution
				Make/O/N=(3*(binSize*sampleRate)+1) template
				Wave template = template
				SetScale/I x,-1.5*binSize,1.5*binSize,template
				template = exp((-x^2/(0.5*binSize)^2)/2)
				
				Variable extraPoints = 1.5 * binSize / DimDelta(template,0)
				Variable theSum = sum(template)
				template /= (1000*binSize)
				
				Variable histDelta = (DimSize(theWave,0)*dT)/sampleRate
				Make/O/FREE/N=(DimSize(theWave,0)*dT*sampleRate) raster
				
				SetScale/P x,0,1/sampleRate,raster
				raster = 0
				
				For(j=0;j<DimSize(spktm,0);j+=1)
					If(x2pnt(raster,spktm[j]) > (DimSize(raster,0)-1))
						continue
					EndIf
					raster[x2pnt(raster,spktm[j])] = 1
				Endfor
				
				histName = NameOfWave(theWave) + "_PSTH"
				Duplicate/O template,$histName
				Wave hist = $histName
				
				Convolve raster, hist
				hist *=1000
				
				SetScale/P y,0,1,"Hz",hist
				
				DeletePoints/M=0 DimSize(hist,0) - extraPoints,extraPoints,hist
				DeletePoints/M=0 0,extraPoints,hist
				SetScale/P x,0,1/sampleRate,hist
				break
		endswitch	
		
		//Cleanup
		KillWaves spktm,template
		
		//save the wave reference of the histogram for return
		outWaves[i] = hist
	EndFor
	
	
	return outWaves
End

//Resets the graph layouts
Function ResetGraphs()
	ControlInfo/W=NL doHistogram
	If(V_Value)
		//Reposition the live viewer to squeeze in the histograms
		KillWindow/Z NL#LiveViewer
		KillWindow/Z NL#HistViewer
		Display/HOST=NL/N=HistViewer/FG=(FL,midGuide,FR,histBottom)
		Display/HOST=NL/N=LiveViewer/FG=(FL,viewerTop,FR,FB)
	Else
		//Reposition the live viewer to squeeze in the histograms
		KillWindow/Z NL#LiveViewer
		KillWindow/Z NL#HistViewer
		Display/HOST=NL/N=LiveViewer/FG=(FL,midGuide,FR,FB)
	EndIf
End

//Opens the histogram plot above the live viewer
Function OpenHistogramGraph()
	DFREF NLF = root:Packages:NeuroLive
	Wave/T listWave =  NLF:fileListWave
	Wave selWave =  NLF:fileSelWave
	NVAR guidePos = root:Packages:NeuroLive:guidePos
	
	DefineGuide/W=NL histBottom = {FT,guidePos}
	DefineGuide/W=NL viewerTop = {histBottom,2}
	
	//Reposition the live viewer to squeeze in the histograms
	GetWindow/Z NL#HistViewer activeSW
	
	If(V_flag)
		MoveSubWindow/W=NL#LiveViewer fguide=(FL,viewerTop,FR,FB)
		Display/HOST=NL/N=HistViewer/FG=(FL,midGuide,FR,histBottom)
	EndIf
	
	AppendSelection("hist","NL#HistViewer")
	
End

//returns the channel number selected
Function GetChannel()
	ControlInfo/W=NL channel
	
	If(!cmpstr(S_Value,"All"))
		return -1
	EndIf
	
	return str2num(S_Value)
End

//returns the channel number selected for the histogram display
Function GetHistChannel()
	ControlInfo/W=NL histChannel
	return str2num(S_Value)
End

//Window hook for the viewer graph
Function NLHook(s)
	STRUCT WMWinHookStruct &s
	
	DFREF NLF = root:Packages:NeuroLive
	NVAR threshold = NLF:threshold
	NVAR moveThreshold = NLF:moveThreshold
	NVAR guidePos = NLF:guidePos
	NVAR moveGuides = NLF:moveGuides
	NVAR endTime = NLF:endTime
	NVAR startTime = NLF:startTime
	NVAR moveStartRange = NLF:moveStartRange
	NVAR moveEndRange = NLF:moveEndRange
	
	NVAR bgndEndTime = NLF:bgndEndTime
	NVAR bgndStartTime = NLF:bgndStartTime
	NVAR moveBgndStartRange = NLF:moveBgndStartRange
	NVAR moveBgndEndRange = NLF:moveBgndEndRange
	
	Variable hookResult = 0

	switch(s.eventCode)
		case 0:				// Activate
			// Handle activate
			break

		case 1:				// Deactivate
			// Handle deactivate
			break
		case 3:
			//Mouse Down
			Variable xCoord = AxisValFromPixel("NL#LiveViewer","bottom",s.mouseLoc.h)
			Variable yCoord = AxisValFromPixel("NL#LiveViewer","left",s.mouseLoc.v)
			
			GetAxis/W=NL#LiveViewer/Q left
			Variable yMax = V_max
			
			//List of horizontal axes
			String axList = ListMatch(AxisList("NL#LiveViewer"),"bottom*",";")
			String traceList = TraceNameList("NL#LiveViewer",";",1)
			String ax = ""
			
			Variable i
			For(i=0;i<ItemsInList(axList,";");i+=1)
				Variable val = AxisValFromPixel("NL#LiveViewer",StringFromList(i,axList,";"),s.mouseLoc.h)
				Wave theTrace = TraceNameToWaveRef("NL#LiveViewer",StringFromList(i,traceList,";"))
				
				If(val < DimDelta(theTrace,0) * DimSize(theTrace,0) && val > DimOffset(theTrace,0))
					ax = StringFromList(i,axList,";")
					break
				EndIf
			EndFor
			
			
			ControlInfo/W=NL bgndRange
			Variable isBackgroundRange = V_Value
			
			Variable xMin = V_min
			Variable xMax = V_max
			
			//5% lenience for clicking the threshold bar
			If(yCoord > threshold - abs(yMax * 0.05) && yCoord < threshold + abs(yMax * 0.05))
				moveGuides = 0
				moveThreshold = 1
				hookResult = 1
				
			ElseIf(abs(s.mouseLoc.v - guidePos) < 5)
			
				moveGuides = 1
				moveThreshold = 0
				hookResult = 1
				
				//Set the mouse cursor to vertical arrows
				s.doSetCursor = 1
				s.cursorCode = 6
				
			ElseIf(abs(PixelFromAxisVal("NL#LiveViewer",ax,endTime) - PixelFromAxisVal("NL#LiveViewer",ax,val)) < 8)
				//selected end time
				moveStartRange = 0
				moveEndRange = 1
				moveBgndEndRange = 0
				moveBgndStartRange = 0
				
			ElseIf(abs(PixelFromAxisVal("NL#LiveViewer",ax,startTime) - PixelFromAxisVal("NL#LiveViewer",ax,val)) < 8)
				//selected start time
				moveStartRange = 1
				moveEndRange = 0
				moveBgndEndRange = 0
				moveBgndStartRange = 0
				
			ElseIf(abs(PixelFromAxisVal("NL#LiveViewer",ax,bgndEndTime) - PixelFromAxisVal("NL#LiveViewer",ax,val)) < 8)
				//selected end time
				If(isBackgroundRange)
					moveStartRange = 0
					moveEndRange = 0
					moveBgndEndRange = 1
					moveBgndStartRange = 0
				EndIf
			ElseIf(abs(PixelFromAxisVal("NL#LiveViewer",ax,bgndStartTime) - PixelFromAxisVal("NL#LiveViewer",ax,val)) < 8)
				//selected start time
				If(isBackgroundRange)
					moveStartRange = 0
					moveEndRange = 0
					moveBgndEndRange = 0
					moveBgndStartRange = 1
				EndIf
			Else
				//Set the mouse cursor to vertical arrows
				
				moveGuides = 0
				moveThreshold = 0
				moveStartRange = 0
				moveEndRange = 0
				moveBgndEndRange = 0
				moveBgndStartRange = 0
				hookResult = 0
			EndIf

			break
		case 4:
			//Mouse Moved
			If(moveThreshold)
				threshold = AxisValFromPixel("NL#LiveViewer","left",s.mouseLoc.v)
				AppendThresholdBar()
//				DoUpdate/W=NL#LiveViewer
				hookResult = 1
			ElseIf(moveGuides)
				//Shift the guide for the displays
				guidePos = s.mouseLoc.v
				
				If(guidePos < 350)
					guidePos = 350
					DefineGuide/W=NL histBottom={FT,guidePos}
					DefineGuide/W=NL viewerTop = {histBottom,2}
					moveGuides = 0
					hookResult = 1
					break
				EndIf
				
				DefineGuide/W=NL histBottom={FT,guidePos}
				DefineGuide/W=NL viewerTop = {histBottom,2}
				
				hookResult = 1
			EndIf
			
			ControlInfo/W=NL bgndRange
			isBackgroundRange = V_Value
			
			//List of vertical axes
			String vAxList = ListMatch(AxisList("NL#LiveViewer"),"left*",";")
			String vertAxis = ""
			vertAxis = StringFromList(0,vAxList,";")
			
			yCoord = AxisValFromPixel("NL#LiveViewer",vertAxis,s.mouseLoc.v)
			GetAxis/W=NL#LiveViewer/Q $vertAxis
			yMax = V_max
	
			
			//List of horizontal axes
		 	axList = ListMatch(AxisList("NL#LiveViewer"),"bottom*",";")
			traceList = TraceNameList("NL#LiveViewer",";",1)
			ax = ""
			
			For(i=0;i<ItemsInList(axList,";");i+=1)
				val = AxisValFromPixel("NL#LiveViewer",StringFromList(i,axList,";"),s.mouseLoc.h)
				Wave theTrace = TraceNameToWaveRef("NL#LiveViewer",StringFromList(i,traceList,";"))
				
				
				If(!WaveExists(theTrace))
					break
				EndIf
				
				If(val < DimDelta(theTrace,0) * DimSize(theTrace,0) && val > DimOffset(theTrace,0))
					ax = StringFromList(i,axList,";")
					break
				EndIf
			EndFor
			
			//Move the range bars
			If(moveEndRange)
				endTime = val
				
				If(endTime < startTime)
					Variable temp = startTime
					startTime = endTime
					endTime = temp
				EndIf
				
				AppendRangeBar()
			ElseIf(moveStartRange)
				startTime = val
				
				If(endTime < startTime)
					temp = startTime
					startTime = endTime
					endTime = temp
				EndIf
				
				AppendRangeBar()
			ElseIf(moveBgndStartRange)
				bgndStartTime = val
				
				If(bgndEndTime < bgndStartTime)
					temp = bgndStartTime
					bgndStartTime = bgndEndTime
					bgndEndTime = temp
				EndIf
				
				AppendRangeBar()
			ElseIf(moveBgndEndRange)
				bgndEndTime = val
				
				If(bgndEndTime < bgndStartTime)
					temp = bgndStartTime
					bgndStartTime = bgndEndTime
					bgndEndTime = temp
				EndIf
				
				AppendRangeBar()
			EndIf
				
			//5% lenience for clicking the threshold bar
			If(yCoord > threshold - abs(yMax * 0.05) && yCoord < threshold + abs(yMax * 0.05))
				s.doSetCursor = 1
				s.cursorCode = 6
				hookResult = 1
				
			ElseIf(abs(s.mouseLoc.v - guidePos) < 5)
				//Set the mouse cursor to vertical arrows
				s.doSetCursor = 1
				s.cursorCode = 6
				hookResult = 1
				
			ElseIf(abs(PixelFromAxisVal("NL#LiveViewer",ax,endTime) - PixelFromAxisVal("NL#LiveViewer",ax,val)) < 8 && s.mouseLoc.v > 300)
				//selected end time
				//Set the mouse cursor to horizontal arrows
				s.doSetCursor = 1
				s.cursorCode = 5
				
			ElseIf(abs(PixelFromAxisVal("NL#LiveViewer",ax,startTime) - PixelFromAxisVal("NL#LiveViewer",ax,val)) < 8 && s.mouseLoc.v > 300)
				//selected start time
				//Set the mouse cursor to horizontal arrows
				s.doSetCursor = 1
				s.cursorCode = 5
				
			ElseIf(abs(PixelFromAxisVal("NL#LiveViewer",ax,bgndEndTime) - PixelFromAxisVal("NL#LiveViewer",ax,val)) < 8 && s.mouseLoc.v > 300)
				//selected background end time
				//Set the mouse cursor to horizontal arrows
				If(isBackgroundRange)
					s.doSetCursor = 1
					s.cursorCode = 5
				EndIf		
				
			ElseIf(abs(PixelFromAxisVal("NL#LiveViewer",ax,bgndStartTime) - PixelFromAxisVal("NL#LiveViewer",ax,val)) < 8 && s.mouseLoc.v > 300)
				//selected background start time
				//Set the mouse cursor to horizontal arrows
				If(isBackgroundRange)
					s.doSetCursor = 1
					s.cursorCode = 5
				EndIf
			EndIf
			
			break
		case 5:
			//Mouse up
			
			If(moveThreshold == 1)
				
				ControlInfo/W=NL doHistogram
				If(V_Value)
					
					//Calculate histograms
					GetHistogram(threshold)
				
					//Display histogram plots
					KillWindow/Z NL#HistViewer
					OpenHistogramGraph()
				EndIf
				
			EndIf
			
			moveGuides = 0
			moveStartRange = 0
			moveEndRange = 0
			moveBgndStartRange = 0
			moveBgndEndRange = 0
			moveThreshold = 0
			hookResult = 1
			break
		// And so on . . .
	endswitch

	return hookResult		// 0 if nothing done, else 1
End

//Applies a 60Hz notch filter to the data to remove 60 cycle noise contamination
Static Function Remove60Cycle(inputWave)
	Wave inputWave
	
	SetDataFolder GetWavesDataFolder(inputWave,1)
	Make/O/D/N=0 coefs
	Duplicate/O inputWave,filtered
	
	If(DimSize(filtered,0) < 101)
		print "Wave is too short to filter with a 101 length coefficient wave"
		return -1
	EndIf
	
	FilterFIR/DIM=0/NMF={0.006,0.001}/COEF coefs, filtered;AbortOnRTE
	
	Wave filterWave = filtered
	inputWave = filterWave
	
	WaveStats/Q inputWave
	inputWave -= V_avg
	
	KillWaves/Z filterWave,coefs

End

//Removes low pass trends in the wave, effectively flattening the trace
Static Function FlattenWave(inputWave)
	Wave inputWave
	
	SetDataFolder GetWavesDataFolder(inputWave,1)
	Make/O/D/N=0 coefs
	Duplicate/O inputWave,filtered
	
	If(DimSize(filtered,0) < 101)
		print "Wave is too short to filter with a 101 length coefficient wave"
		return -1
	EndIf
	
	FilterFIR/DIM=0/HI={0.006,0.01,101}/COEF coefs, filtered;AbortOnRTE
	
	Wave filterWave = filtered
	inputWave = filterWave
	
	WaveStats/Q inputWave
	inputWave -= V_avg

	
	KillWaves/Z filterWave,coefs
End

Function/S NTL_getSpacer(str)
	String str
		
	//Calculates spacer to ensure centered text on the drop down menu
	String spacer = ""
	Variable cmdLen = strlen(str)
	cmdLen = 18 - cmdLen
	
	Do
		spacer += " "
		cmdLen -= 1
	While(cmdLen > 0)
	
	spacer = "\\JL▼   " + spacer
	
	return spacer
End

//Runs the selected function, master function
Function/S runFunction()
	STRUCT paramStruct s
	DFREF NLF = root:Packages:NeuroLive
	
	//Which function
	SVAR selFunction = NLF:selFunction
	
	If(!strlen(selFunction))
		return "Coulnd't find the selected function"
	EndIf
	
	//Get the command string to execute with all parameters resolved
	String cmdStr = getExtFuncCmdStr(selFunction)
	
	DFREF saveDF = GetDataFolderDFR()
	
	//Execute the function
	Execute/P/Q/Z cmdStr
	
	SetDataFolder saveDF
	
//	
//	strswitch(selFunction)
//		case "testFunc1":
//			testFunc1(s)
//			break
//		case "DSPlot":
//			NL_DSPlot(5)
//			break
//		default:
//			print "default"
//			break
//	endswitch
	
End

//Handles button clicks
Function nlButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	NVAR threshold = root:Packages:NeuroLive:threshold
	SVAR selFunction = root:Packages:NeuroLive:selFunction
	DFREF NLF = root:Packages:NeuroLive
	
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			strswitch(ba.ctrlName)
				case "BrowseFiles":
					ControlInfo/W=NL fileType
					BrowseFiles(S_Value)
					break
				case "reload":
					GetWindow/Z NL wsize
					Load_NeuroLive(left=V_left,top=V_top)
					break
				case "gotoCode":
					SVAR selFunction = NLF:selFunction
					DisplayProcedure/W=NeuroLive "NL_" + selFunction
					break
				case "autoscale":
					SetAxis/W=NL#LiveViewer/A
					
					GetWindow/Z NL#HistViewer activeSW
					If(!V_flag)
						SetAxis/W=NL#HistViewer/A
					EndIf
					break
				case "flatten":
					Wave/WAVE refs = GetSelectedWaves("")
					Variable i
					For(i=0;i<DimSize(refs,0);i+=1)
						Wave theWave = refs[i]
						FlattenWave(theWave)
//						Remove60Cycle(theWave)
					EndFor
					
					//Redo the histogram if it's checked
					ControlInfo/W=NL doHistogram
					If(V_Value)
						//Calculate histograms
						GetHistogram(threshold)
						
						//Display histogram plots
						KillWindow/Z NL#HistViewer
						OpenHistogramGraph()
					EndIf
					
					break
				case "functions":
					PopupContextualMenu/C=(490,50)/N/W=NL "funcMenu"
					
					If(strlen(S_Selection))
						//Calculates spacer to ensure centered text on the drop down menu
						String spacer = NTL_GetSpacer(S_Selection)
					
						
						//switch the text on the button/drop down menu
						Button functions win=NL,title=spacer + S_Selection
						
						selFunction = S_Selection
						
						//Refresh the external function data, in case a function has been edited to add new parameters
						//A full reload is necessary if parameters have been deleted though
						Wave/T param = NLF:ExtFunc_Parameters
						GetExternalFunctionData(param)
						
						//Switch the controls
						BuildExtFuncControls(selFunction)
					EndIf
					break
				case "displayGraphContents":
					//Duplicates the Viewer graph outside of the viewer
					String theTraces = TraceNameList("NL#LiveViewer",";",1)
						
					String winRec = WinRecreation("NL#LiveViewer",0)
					
					Variable pos1 = strsearch(winRec,"/W",0)
					Variable pos2 = strsearch(winRec,"/HOST",0) - 1
					
					String matchStr = winRec[pos1,pos2]
					
					//coordinates of NL window
					GetWindow NL wsize
					
					winRec = ReplaceString(matchStr,winRec,"/K=1/W=(" + num2str(V_right+10) + "," + num2str(V_top) + "," + num2str(V_right + 10 + 360) + "," + num2str(V_top + 200) + ")")
					winRec = ReplaceString("/HOST=#",winRec,"")
					Execute/Q/Z winRec
					
					//Remove the background layers from the graph
					
					GetWindow kwTopWin activeSW
					SetDrawLayer/W=$S_Value/K UserFront
					
					ControlInfo/W=NL doHistogram
					Variable doHist = V_Value
					
					If(doHist)
						//Duplicates the Viewer graph outside of the viewer
						theTraces = TraceNameList("NL#HistViewer",";",1)
							
						winRec = WinRecreation("NL#HistViewer",0)
						
						pos1 = strsearch(winRec,"/W",0)
						pos2 = strsearch(winRec,"/HOST",0) - 1
						
						matchStr = winRec[pos1,pos2]
						
						//coordinates of NL window
						GetWindow NL wsize
						
						winRec = ReplaceString(matchStr,winRec,"/K=1/W=(" + num2str(V_right+10) + "," + num2str(V_top + 200) + "," + num2str(V_right + 10 + 360) + "," + num2str(V_top + 400) + ")")
						winRec = ReplaceString("/HOST=#",winRec,"")
						Execute/Q/Z winRec
						
						//Remove the background layers from the graph
						
						GetWindow kwTopWin activeSW
						SetDrawLayer/W=$S_Value/K UserFront
					EndIf
					
					break
				case "colorGraphContents":
					NVAR areColored = NLF:areColored
					areColored = (areColored) ? 0 : 1
					colorViewerGraph()
					break
				case "run":
					runFunction()
					break
			endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Static Function colorViewerGraph()
	DFREF NLF = root:Packages:NeuroLive
	NVAR areColored = NLF:areColored
	
	String theTraces = TraceNameList("NL#LiveViewer",";",1)
	Variable i,numTraces = ItemsInList(theTraces,";")
	
	If(!DataFolderExists("root:Packages:NeuroLive:CustomColors"))
		NewDataFolder NLF:CustomColors
	EndIf
	
	Wave/Z colorTab = root:Packages:NeuroLive:CustomColors:Rainbow
	If(!WaveExists(colorTab))
		DFREF saveDF = GetDataFolderDFR()
		SetDataFolder root:Packages:NeuroLive:CustomColors
		ColorTab2Wave rainbow
		Duplicate/O root:Packages:NeuroLive:CustomColors:M_colors,root:Packages:NeuroLive:CustomColors:Rainbow
		Wave colorTab = root:Packages:NeuroLive:CustomColors:Rainbow
		KillWaves/Z root:Packages:NeuroLive:CustomColors:M_colors
		SetDataFolder saveDF
	EndIf
	
	Variable colorDelta = round(DimSize(colorTab,0) / numTraces)
	Variable tableSize = DimSize(colorTab,0)
	
	For(i=0;i<numTraces;i+=1)
		String traceName = StringFromlist(i,theTraces,";")
		String histTraceName = StringFromlist(i,theTraces,";") + "_PSTH"
		
		Variable index = i * colorDelta
		
		//Repeats the color table from the start if there are too many waves displayed
		Variable overRunTimes = floor(index/tableSize)
	
		index -= tableSize * overRunTimes
		
		If(areColored)
			ModifyGraph/W=NL#LiveViewer rgb($traceName)=(colorTab[index][0],colorTab[index][1],colorTab[index][2])
		Else
			ModifyGraph/W=NL#LiveViewer rgb($traceName)=(0,0,0) //return to black
		EndIf
		
		ControlInfo/W=NL doHistogram
		Variable doHist = V_Value
		
		If(doHist)
			If(areColored)
				ModifyGraph/W=NL#HistViewer rgb($histTraceName)=(colorTab[index][0],colorTab[index][1],colorTab[index][2])
			Else
				ModifyGraph/W=NL#HistViewer rgb($histTraceName)=(0,0,0) //return to black
			EndIf
		EndIf
	EndFor

End

//Handles list box selections
Function nlListBoxProc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave
	NVAR threshold = root:Packages:NeuroLive:threshold
	
	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			break
		case 2: // mouse up
			
			//only update the histograms on mouse up to any reduce lag
			ControlInfo/W=NL doHistogram
			If(V_Value)
				//Calculate histograms
				GetHistogram(threshold)
				
				//Display histogram plots
				KillWindow/Z NL#HistViewer
				OpenHistogramGraph()
			EndIf
			
			AppendRangeBar()
						
			break
		case 3: // double click
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
			strswitch(lba.ctrlName)
				case "fileList":
					ControlInfo/W=NL channel
					Variable ch = str2num(S_Value)
					
					//Reset the graph
					ResetGraphs()
	
					AppendSelection("","NL#LiveViewer")
					
					colorViewerGraph()
					break
			endswitch
		
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


Function nlCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	NVAR threshold = root:Packages:NeuroLive:threshold
	
	DFREF NLF = root:Packages:NeuroLive
	Wave/T listWave =  NLF:fileListWave
	Wave selWave =  NLF:fileSelWave
	
	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			strswitch(cba.ctrlName)
				case "horTrace":
					Checkbox vertTrace value=0
					
					ControlInfo/W=NL doHistogram
					Variable doHist = V_Value
					
					If(checked)
						SeparateTraces("vert","NL#LiveViewer",1)
						SeparateTraces("horiz","NL#LiveViewer",0)
						
						If(doHist)
							SeparateTraces("vert","NL#HistViewer",1)
							SeparateTraces("horiz","NL#HistViewer",0)
						EndIf
					Else
						SeparateTraces("horiz","NL#LiveViewer",1)
						
						If(doHist)
							SeparateTraces("horiz","NL#HistViewer",1)
						EndIf
					EndIf
					
					colorViewerGraph()
					
					//set the threshold and range bars
					DoUpdate/W=NL#LiveViewer
					AppendRangeBar()
					AppendThresholdBar()
					
					
					break
				case "vertTrace":
					Checkbox horTrace value=0
					
					ControlInfo/W=NL doHistogram
					doHist = V_Value
					
					If(checked)
						SeparateTraces("horiz","NL#LiveViewer",1)
						SeparateTraces("vert","NL#LiveViewer",0)
						
						If(doHist)
							SeparateTraces("horiz","NL#HistViewer",1)
							SeparateTraces("vert","NL#HistViewer",0)
						EndIf
						
					Else
						SeparateTraces("vert","NL#LiveViewer",1)
						
						If(doHist)
							SeparateTraces("vert","NL#HistViewer",1)
						EndIf
					EndIf
					
					colorViewerGraph()
					
					//set the threshold bar
					DoUpdate/W=NL#LiveViewer
					AppendRangeBar()
					AppendThresholdBar()
					
					
					
					break
				case "doHistogram":
				
					If(checked)
						//Calculate histograms
						GetHistogram(threshold)
						
						//Display histogram plots
						OpenHistogramGraph()			
						
					Else
						//remove histogram traces
						KillWindow/Z NL#HistViewer
						MoveSubWindow/W=NL#LiveViewer fguide=(FL,midGuide,FR,FB)
						
					EndIf
					break
				case "bgndRange":
					GetWindow/Z NL#LiveViewer activeSW
					If(V_flag)
						break
					EndIf
					
					AppendRangeBar()
							
					break
			endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

//Handle all drop down menus
Function nlMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	
	DFREF NLF = root:Packages:NeuroLive
	Wave/T listWave =  NLF:fileListWave
	Wave selWave =  NLF:fileSelWave
	NVAR threshold = root:Packages:NeuroLive:threshold
	
	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			
			strswitch(pa.ctrlName)
				case "channel":
					Variable ch = str2num(popStr)
					
					//reset the graph
					KillWindow/Z NL#LiveViewer
					Display/HOST=NL/N=LiveViewer/FG=(FL,midGuide,FR,FB)
					
					AppendSelection("","NL#LiveViewer")
					ControlInfo/W=NL doHistogram
					If(V_Value)
						//Calculate histograms
						Wave/WAVE hists = GetHistogram(threshold)
						
						//Display histogram plots
						If(!WaveExists(hists))
							KillWindow/Z NL#HistViewer
						Else
							KillWindow/Z NL#HistViewer
							OpenHistogramGraph()
						EndIf
					EndIf
					break
				case "histType":
					ControlInfo/W=NL doHistogram
					If(V_Value)
						//Calculate histograms
						GetHistogram(threshold)
						
						//Display histogram plots
						KillWindow/Z NL#HistViewer
						OpenHistogramGraph()
					EndIf
					
					break
			endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function nlSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	NVAR threshold = root:Packages:NeuroLive:threshold
	
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			
			strswitch(sva.ctrlName)
				case "binSize":

					ControlInfo/W=NL doHistogram
					If(V_Value)
						//Calculate histograms
						GetHistogram(threshold)
						
						//Display histogram plots
						KillWindow/Z NL#HistViewer
						OpenHistogramGraph()
					EndIf
					
					break
			endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


//Background function for updating fileList every 5 seconds in case there is new data
Function GetNewDataTask(s)		// This is the function that will be called periodically
	STRUCT WMBackgroundStruct &s
	
	DFREF NLF = root:Packages:NeuroLive
	Wave/T fileListWave = NLF:fileListWave 
	Wave fileSelWave = NLF:fileSelWave
		
	ControlInfo/W=NL fileType
	String fileType = S_Value
	
	strswitch(fileType)
		case "WaveSurfer":
			String filter = ".h5"
			break
		case "PClamp":
			filter = ".abf2"
			break
		case "Presentinator":
			
			break
	endswitch

	//Get the current list
	String currentFiles = ""
	Variable i
	For(i=0;i<DimSize(fileListWave,0);i+=1)
		currentFiles += ParseFilePath(0,StringFromList(0,fileListWave[i][0][0],"/"),":",1,0) + ";"
	EndFor

	//Get the list of files with the correct extension based on their file type
	String fileList = IndexedFile(filePath,-1,filter)	

	If(!strlen(fileList))
		return 0
	EndIf
	
	//Test if any files have been removed from the folder
	For(i=ItemsInList(currentFiles,";") - 1;i>-1;i-=1) //reverse order
		String theFile = StringFromList(i,currentFiles,";")
		
		Do
		Variable index = WhichListItem(theFile,fileList,";")
			If(index == -1) //File has been removed
				currentFiles = RemoveFromList(theFile,currentFiles,";")
				DeletePoints/M=0 index,1,fileListWave,fileSelWave
			EndIf
		While(index == -1)
	EndFor
	
	//Narrow the list down to only the newly added files
	For(i=0;i<ItemsInList(currentFiles,";");i+=1)
		theFile = StringFromList(i,currentFiles,";")
		fileList = RemoveFromList(theFile,fileList,";")
	EndFor
	
	If(!strlen(fileList))
		return 0
	EndIf
	
	PathInfo/S filePath
	
	String folder = ParseFilePath(0,S_path,":",1,0)
	
	//Get the sweep list if it's a wavesurfer file
	String sweepListTemp = GetWSSweeps(fileList)
	String colorList = "", chList = "", sweepList = "", fullPathList = "", prefixList = ""
	
	//Resize the list box that holds the file names and parent folders
	Variable size = DimSize(fileListWave,0)
	Redimension/N=(size + ItemsInList(sweepListTemp,";"),2,2) fileListWave
	Redimension/N=(size + ItemsInList(sweepListTemp,";"),2,2) fileSelWave
	
	//Extract number of channels and the row color from the list
	Variable j
	For(i=0;i<ItemsInList(sweepListTemp,";");i+=1)
		colorList += StringFromList(0,StringFromlist(i,sweepListTemp,";"),"//") + ";"
		prefixList = StringFromList(1,StringFromlist(i,sweepListTemp,";"),"//") + ";"
		chList += StringFromList(2,StringFromlist(i,sweepListTemp,";"),"//") + ";"
		sweepList += StringFromList(3,StringFromlist(i,sweepListTemp,";"),"//") + ";"
		
		fileSelWave[i][][1] = str2num(StringFromList(i,colorList,";"))
	EndFor
	
	For(i=0;i<ItemsInList(sweepList,";");i+=1)	
		String sweepPath = StringFromList(i,sweepList,";")
		String sweepNum = StringFromList(1,StringFromList(1,sweepPath,"/"),"_")
		String wavePath = ""
		
		j = 0
		Do
			If(!cmpstr(sweepNum[j],"0"))
				sweepNum = sweepNum[j+1,strlen(sweepNum)-1] //truncate leading zeros
				continue
			Else
				break
			EndIf
			
			j += 1
		While(j < strlen(sweepNum)-1)
		
		prefixList = RemoveEnding(prefixList,";")
		
		For(j=0;j<ItemsInList(prefixList,"#");j+=1)
			String prefix = StringFromList(j,prefixList,"#")
			wavePath += "root:EPhys:" + folder + ":" + prefix + "_" + sweepNum + "_1_1_" + num2str(j+1) + ";"
		EndFor
		
		fileListWave[i][0][1] = wavePath
	EndFor
		
	StringListToTextWave(sweepList,fileListWave,";",col=0)
	StringListToTextWave(chList,fileListWave,";",col=1)
	
	//Load the data into Igor if it doesn't already exist
	Load_WaveSurfer(sweepList,channels="All")
	
	
	return 0	// Continue background task
End

Function StartDataTask()
	Variable numTicks = 5 * 60		// Run every two seconds (120 ticks)
	CtrlNamedBackground GetNewData, period=numTicks, proc=GetNewDataTask
	CtrlNamedBackground GetNewData, start
End

Function StopDataTask()
	CtrlNamedBackground GetNewData, stop
End

//Parameter structure for built in functions
Structure paramStruct
	int16 bRange //background range checked
	int16 numWaves //number of waves for analysis
	int16 channel //channel selection
	float bstartTm //background start time
	float bendTm  //background end time
	float startTm	//signal start time
	float endTm  //signal end time
	float threshold //signal threshold
	Wave/WAVE waves //selected waves for analysis as wave references
	Wave/T paths //selected waves for analysis as full paths in a table wave
EndStructure

Function GetParams(s)
	STRUCT paramStruct &s
	
	DFREF NLF = root:Packages:NeuroLive
	
	//Selected files
	Wave/T fileListWave = NLF:fileListWave 
	Wave fileSelWave = NLF:fileSelWave
	
	//Signal time range
	NVAR startTime = NLF:startTime
	NVAR endTime = NLF:endTime
	
	//Background time range
	NVAR bgndStartTime = NLF:bgndStartTime
	NVAR bgndEndTime = NLF:bgndEndTime
	
	//threshold
	NVAR threshold = NLF:threshold
	
	Variable i,count = 0
	
	//channel selection
	ControlInfo/W=NL channel
	s.channel = V_Value
	
	//Selected Waves
	Make/O/WAVE NLF:refs/Wave = refWave
	
	//Selected waves full paths form
	Make/O/T NLF:wavePaths /Wave=wavePaths
	wavePaths[] = ""
	
	Redimension/N=(DimSize(fileSelWave,0)) refWave,wavePaths
	
	For(i=0;i<DimSize(fileSelWave,0);i+=1)
		If(fileSelWave[i][0] > 0)
			refWave[count] = $StringFromList(s.channel - 1,fileListWave[i][0][1],";")
			wavePaths[count] = StringFromList(s.channel - 1,fileListWave[i][0][1],";")
			count += 1
		EndIf		
	EndFor	

	Redimension/N=(count) refWave,wavePaths
	Wave/WAVE s.waves = refWave
	Wave/T s.paths = wavePaths
	
	s.paths = wavePaths
	ControlInfo/W=NL bgndRange
	s.bRange = V_Value
	
	s.startTm = startTime
	s.endTm = endTime
	s.bstartTm = bgndStartTime
	s.bendTm = bgndEndTime
	s.threshold = threshold
	s.numWaves = DimSize(s.waves,0)
End

Function NL_Measure(menu_Type,Output_Name)
	String menu_Type,Output_Name
	
	String menu_Type_List = "Mean;Median;Peak;Area;Count Spikes;"
	
	//declare the structure paramStruct, which already contains the built-in parameters
	STRUCT paramStruct s
	GetParams(s)
	
	Variable i
	
	DFREF saveDF = GetDataFolderDFR()
	
	SetDataFolder GetWavesDataFolder(s.waves[0],1)
	
	If(!strlen(Output_Name))
		If(!cmpstr(menu_Type,"Count Spikes"))
			Output_Name = NameOfWave(s.waves[0]) + "_nSpks"
		Else
			Output_Name = NameOfWave(s.waves[0]) + "_" + menu_Type
		EndIf
	EndIf
		
	Make/O/N=(s.numWaves) $Output_Name/Wave=outWave
			
	For(i=0;i<s.numWaves;i+=1)
		Wave theWave = s.waves[i]
		
		//Do analysis on the wave
		
		strswitch(menu_Type)
			case "Mean":
				outWave[i] = mean(theWave,s.startTm,s.endTm)
				
				If(s.bRange)
					outWave[i] -= mean(theWave,s.bstartTm,s.bendTm)
				EndIf
				
				break
			case "Median":
				outWave[i] = median(theWave,s.startTm,s.endTm)
				
				If(s.bRange)
					outWave[i] -= mean(theWave,s.bstartTm,s.bendTm)
				EndIf
				
				break
			case "Peak":
				outWave[i] = WaveMax(theWave,s.startTm,s.endTm)
				
				If(s.bRange)
					outWave[i] -= mean(theWave,s.bstartTm,s.bendTm)
				EndIf
				
				break
			case "Area":
				outWave[i] = area(theWave,s.startTm,s.endTm)
				
				If(s.bRange)
					//subtract the mean background value from the wave first, then take the area of what's left
					Duplicate/FREE theWave,temp
					Multithread temp = theWave - mean(theWave,s.bstartTm,s.bendTm)
					outWave[i] = area(temp,s.startTm,s.endTm)
				EndIf
				
				break
			case "Count Spikes":
				outWave[i] = GetSpikeCount(theWave,s.threshold,startTm=s.startTm,endTm=s.endTm)
				break
			default:
				print "nothing done"
				break
		endswitch
	EndFor
	
	DisplayOutput(outWave)
	
	SetDataFolder saveDF
End


//Returns spike count for the input wave over a range and at a certain threshold
Static Function GetSpikeCount(inWave,threshold,[startTm,endTm])
	Wave inWave
	Variable threshold,startTm,endTm

	//Get spike times and counts
	FindLevels/Q/EDGE=1/M=0.002/D=spktm/R=(startTm,endTm)/M=0.002/T=0.0005 inWave,threshold
	Variable numSpikes = V_LevelsFound
	
	KillWaves/Z spktm

	return numSpikes
End

//Generates a tuning curve for input data, returns a vector summation DSI and Angle
Function NL_DSPlot(menu_Angles,CustomAngles,menu_Measurement,Output_Name)
	
	//declare any additional custom variables
	String menu_Angles,CustomAngles,menu_Measurement,Output_Name
		
	//Items of the menu_Angles menu
	String menu_Angles_List = "Custom;0,45,90,135,180,225,270,315;0,180,45,225,90,270,135,315;"
	
	String menu_Measurement_List = "# Spikes;Peak Spike Rate;Peak;Area;"
	
	//declare the structure paramStruct, which already contains the built-in parameters
	STRUCT paramStruct s
	GetParams(s)
	
	Variable i
	
	NVAR threshold = root:Packages:NeuroLive:threshold
	
	If(!cmpstr(menu_Angles,"Custom"))
		menu_Angles = CustomAngles
	EndIf
	
	//First wave in the set
	If(DimSize(s.waves,0) == 0)
		return 0
	EndIf
	
	//Set the current data folder to the first wave
	SetDataFolder GetWavesDataFolder(s.waves[0],1)
	
	//Create the ds tuning output wave
	If(!strlen(Output_Name))
		Output_Name = NameOfWave(s.waves[0]) + "_tuning"
	EndIf
	
	Make/N=(s.numWaves)/O $Output_Name
	Wave ds = $Output_Name
	
	//Loop through each wave in the wave list, and get its peak w/ possible background subtraction	
	For(i=0;i<DimSize(s.paths,0);i+=1)
	
		//current wave in the list
		Wave theWave = s.waves[i]
		
		strswitch(menu_Measurement)
			case "# Spikes":
				ds[i] = GetSpikeCount(theWave,s.threshold,startTm=s.startTm,endTm=s.endTm)
				break
			case "Peak Spike Rate":
				//Calculate histograms on first pass
				If(i == 0)
					Wave/WAVE hists = GetHistogram(threshold)
				EndIf
				
				Wave theHist = hists[i]
				
				//get the peak firing rate over the selected range
				If(s.bRange)
					ds[i] = WaveMax(theHist,s.startTm,s.endTm) - mean(theHist,s.bstartTm,s.bendTm)
				Else
					ds[i] = WaveMax(theHist,s.startTm,s.endTm)
				EndIf
							
				break
			case "Peak":
				//get the peak over the selected range
				If(s.bRange)
					ds[i] = WaveMax(theWave,s.startTm,s.endTm) - mean(theWave,s.bstartTm,s.bendTm)
				Else
					ds[i] = WaveMax(theWave,s.startTm,s.endTm)
				EndIf
				break
			case "Area":
				//get the area over the selected range
				If(s.bRange)
					//get area above/below baseline
					Duplicate/FREE theWave,temp
					temp -= mean(theWave,s.bstartTm,s.bendTm)
					ds[i] = area(temp,s.startTm,s.endTm)
				Else
					ds[i] = area(theWave,s.startTm,s.endTm)
				EndIf
				
				break
			default:
				break
		endswitch

	EndFor
	
	menu_Angles = ReplaceString(",",menu_Angles,";")
	
	print "-----------------"
	VectorSum(ds,menu_Angles,"vAngle")
	
	If(strlen(menu_Angles))
		Make/FREE/N=(ItemsInList(menu_Angles,";")) index
		Wave/T sortKey = ListToTextWave(menu_Angles,";")
		
		MakeIndex/A sortKey,index
		MakeIndex/A index,index
		Sort index,ds
		
		index = str2num(sortKey)
		SetScale/I x,WaveMin(index),WaveMax(index),"deg",ds
	EndIf
	
	SetScale/I y,0,1,"# Spikes",ds
	
	//display the tuning curve
	DisplayOutput(ds)
	
End


//Generates a tuning curve for input data, returns a vector summation DSI and Angle
Function NL_RFPlot(menu_Measurement,X_Start,X_End,Y_Start,Y_End,Output_Name)
	
	//declare any additional custom variables
	String menu_Measurement
	Variable X_Start,X_End,Y_Start,Y_End
	String Output_Name
		
	String menu_Measurement_List = "# Spikes;Peak Spike Rate;Peak;Area;"
	
	//declare the structure paramStruct, which already contains the built-in parameters
	STRUCT paramStruct s
	GetParams(s)
	
	Variable i

	//First wave in the set
	If(DimSize(s.waves,0) == 0)
		return 0
	EndIf
	
	//Set the current data folder to the first wave
	SetDataFolder GetWavesDataFolder(s.waves[0],1)
	
	//Create the rf tuning output wave
	If(!strlen(Output_Name))
		Output_Name = NameOfWave(s.waves[0]) + "_RF"
	EndIf
	
	Make/N=(s.numWaves)/O $(Output_Name + "_X"),$(Output_Name + "_Y")
	Wave rfx = $(Output_Name + "_X")
	Wave rfy = $(Output_Name + "_Y")
	
	Variable halfway = s.numWaves/2
	
	//Loop through each wave in the wave list, and get its peak w/ possible background subtraction	
	For(i=0;i<DimSize(s.paths,0);i+=1)
		
		//current wave in the list
		Wave theWave = s.waves[i]
		
		strswitch(menu_Measurement)
			case "# Spikes":
				rfx[i] = GetSpikeCount(theWave,s.threshold,startTm=s.startTm,endTm=s.endTm)
				break
			case "Peak Spike Rate":
				GetHistogram(s.threshold,w=theWave)
				Wave hist = $(NameOfWave(theWave) + "_PSTH")
								
				If(s.bRange)
					rfx[i] = WaveMax(hist,s.startTm,s.endTm) - mean(hist,s.bstartTm,s.bendTm)
				Else
					rfx[i] = WaveMax(hist,s.startTm,s.endTm)
				EndIf
				break
			case "Peak":
				//get the peak, taken as the average over the selected range
				If(s.bRange)
					rfx[i] = mean(theWave,s.startTm,s.endTm) - mean(theWave,s.bstartTm,s.bendTm)
				Else
					rfx[i] = mean(theWave,s.startTm,s.endTm)
				EndIf
				break
			case "Area":
				//get the peak, taken as the average over the selected range
				If(s.bRange)
					rfx[i] = area(theWave,s.startTm,s.endTm) - mean(theWave,s.bstartTm,s.bendTm)
				Else
					rfx[i] = area(theWave,s.startTm,s.endTm)
				EndIf
				
				break
			default:
				break
		endswitch

	EndFor
	

	rfy = rfx
	Redimension/N=(halfway) rfx
	DeletePoints/M=0 0,halfway,rfy
	
	SetScale/I x,X_Start,X_End,"m",rfx
	SetScale/I x,Y_Start,Y_End,"m",rfy
	
	SetScale/I y,0,1,"# Spikes",rfx
	SetScale/I y,0,1,"# Spikes",rfy
	
	//display the tuning curve
	DisplayOutput(rfx)
	DisplayOutput(rfy)
End


Function DisplayOutput(w)
	Wave w
	
	GetWindow/Z NL wsize
	
	Display/K=1/W=(V_right,V_top,V_right + 300,V_top + 200) w
	
End

//Returns the vector sum angle or dsi of the input wave
Static Function VectorSum(theWave,angles,returnItem)
	Wave theWave
	String angles
	String returnItem
	
	Variable i,size = DimSize(theWave,0)
	
	If(ItemsInList(angles,";") != size)
		return -1 //angle list must be the same length as the input wave
	EndIf
	
	Variable vSumX,vSumY,totalSignal
	
	vSumX = 0
	vSumY = 0
	totalSignal = 0

	For(i=0;i<size;i+=1)
		If(numtype(theWave[i]) == 2) //protects against NaNs, returns -9999, invalid
			return -9999
		EndIf
		
		Variable theAngle = str2num(StringFromList(i,angles,";"))
		
		vSumX += theWave[i]*cos(theAngle*pi/180)
		vSumY += theWave[i]*sin(theAngle*pi/180)
		totalSignal += theWave[i]
	EndFor
	
	Variable vRadius = sqrt(vSumX^2 + vSumY^2)
	Variable vAngle = atan2(vSumY,vSumX)*180/pi
	Variable	DSI = vRadius/totalSignal
	Variable SNR = vRadius
	
	If(vAngle < 0)
		vAngle +=360
	Endif

	print "Angle: ",vAngle
	print "DSI: ",DSI
	print "Resultant: ",vRadius
	
	strswitch(returnItem)
		case "angle":
		case "vAng":
		case "vAngle":
			return vAngle
			break
		case "resultant":
			return vRadius
			break
		case "DSI":
			return DSI
			break
	endswitch
End


//Returns the named parameter from the external functions data wave
Static Function/S getParam(key,func)
	String key,func
	DFREF NLF = root:Packages:NeuroLive
	Wave/T param = NLF:ExtFunc_Parameters
	
	Variable row = FindDimLabel(param,0,key)
	Variable col = FindDimLabel(param,1,func)
	
	return param[row][col]
End



//Sets the named parameter for an external function with the specified value
Static Function setParam(key,func,value)
	String key,func,value
	
	DFREF NLF = root:Packages:NeuroLive
	Wave/T param = NLF:ExtFunc_Parameters
	
	Variable row = FindDimLabel(param,0,key)
	Variable col = FindDimLabel(param,1,func)
	
	param[row][col] = value
End

//Returns a string list of the control names for the indicated external function
Static Function/S getParamCtrlList(func)
	String func	
	String list = ""
	Variable i,numParams = str2num(getParam("N_PARAMS",func))
	
	For(i=0;i<numParams;i+=1)
		list += "param" + num2str(i) + ";"
	EndFor 
	return list
End

Static Function/S getExtFuncCmdStr(func)
	String func
	Wave/T param = root:Packages:NeuroLive:ExtFunc_Parameters
	Variable i,numParams = str2num(getParam("N_PARAMS",func))
	
	String cmdStr = "NL_" + func + "("
	For(i=0;i<numParams;i+=1)
		String value = getParam("PARAM_" + num2str(i) + "_VALUE",func)
		String type =  getParam("PARAM_" + num2str(i) + "_TYPE",func)
		String name = getParam("PARAM_" + num2str(i) + "_NAME",func)
		
		strswitch(type)
			case "4": //variable
				cmdStr += value + "," 
				break
			case "8192": //string
				cmdStr += "\"" + value + "\"" + "," 
				break
			case "16386": //wave
				cmdStr += value + "," 
				break
		endswitch		
	EndFor
	
	cmdStr = RemoveEnding(cmdStr,",") + ")"
	return cmdStr
End

//Builds the parameters for the selected external function
Static Function BuildExtFuncControls(theFunction)
	String theFunction
	DFREF NLF = root:Packages:NeuroLive
	
	//holds the parameters of the external functions
	Wave/T param = NLF:ExtFunc_Parameters
		
	String info = FunctionInfo("NL_" + theFunction)

	Variable i,pos
	
	Variable numParams,numOptParams
	numParams = str2num(StringByKey("N_PARAMS",info,":",";"))
	numOptParams = str2num(StringByKey("N_OPT_PARAMS",info,":",";"))
	
	//Function has no extra parameters declared
	KillExtParams()
	
	String paramType,functionStr
	paramType = ""

	//gets the type for each input parameter
	SVAR isOptional = NTF:isOptional
	isOptional = ""
	
	//Gets the names of each inputs in the selected function
	functionStr = ProcedureText("NL_" + theFunction,0)
	pos = strsearch(functionStr,")",0)
	functionStr = functionStr[0,pos]
	functionStr = RemoveEnding(StringFromList(1,functionStr,"("),")")
	
	String extParamNames = functionStr
	Variable left=480,top=75
	String type,name,ctrlName,items
	
	For(i=0;i<numParams;i+=1)
		name = getParam("PARAM_" + num2str(i) + "_NAME",theFunction)
		ctrlName = "param" + num2str(i)
		type = getParam("PARAM_" + num2str(i) + "_TYPE",theFunction)
		items = getParam("PARAM_" + num2str(i) + "_ITEMS",theFunction)
		
		Variable isMenu = 0
		
		If(stringmatch(name,"menu_*"))
			isMenu = 1
		Else
			isMenu = 0
		EndIf
		
		strswitch(type)
			case "4"://variable
				
				Variable valueNum = str2num(getParam("PARAM_" + num2str(i) + "_VALUE",theFunction))
				
				//CheckBox designation
				If(stringmatch(name,"cb_*"))		
					name = RemoveListItem(0,name,"_") //removes the "CB" prefix
					valueNum = (valueNum > 0) ? 1 : 0
					SetParam("PARAM_" + num2str(i) + "_VALUE",theFunction,num2str(valueNum))
					
					CheckBox/Z $ctrlName win=NL,pos={left,top},size={90,20},bodywidth=50,side=1,font=$NL_LIGHT,fsize=10,title=name,value=valueNum,disable=0,proc=nlExtParamCheckProc
		
				Else
					If(numtype(valueNum) == 2)
						valueNum = 0
					EndIf
					SetVariable/Z $ctrlName win=NL,pos={left,top},size={90,20},bodywidth=50,font=$NL_LIGHT,fsize=10,title=name,value=_NUM:valueNum,disable=0,proc=nlExtParamProc
				EndIf
				
				break
			case "8192"://string
			
				//Popup menu designation
				If(isMenu)
					name = RemoveListItem(0,name,"_") //removes the "pop" prefix
					String itemStr = "\"" + items + "\""	
					String valueStr = getParam("PARAM_" + num2str(i) + "_VALUE",theFunction)	

					PopUpMenu/Z $ctrlName win=NL,pos={left,top},size={185,20},bodywidth=150,font=$NL_LIGHT,fsize=10,title=name,value=#itemStr,disable=0,proc=nlExtParamPopProc	
					PopUpMenu/Z $ctrlName win=NL,popmatch=valueStr
				Else
					valueStr = getParam("PARAM_" + num2str(i) + "_VALUE",theFunction)	
					SetVariable/Z $ctrlName win=NL,pos={left,top},size={185,20},bodywidth=150,font=$NL_LIGHT,fsize=10,title=name,value=_STR:valueStr,disable=0,proc=nlExtParamProc	
				EndIf
				
				break
			case "16386"://wave
				valueStr = getParam("PARAM_" + num2str(i) + "_VALUE",theFunction)
				//this will convert a wave path to a wave reference pointer
				SetVariable/Z $ctrlName win=NL,pos={left,top},size={140,20},bodywidth=100,font=$NL_LIGHT,fsize=10,title=name,value=_STR:valueStr,disable=0,proc=nlExtParamProc
				
				//confirm validity of the wave reference
				ControlInfo/W=NT $ctrlName
				break
			case "4608"://structure
				top -= 25 //reset back				
				break
		endswitch
		top += 25
		
	EndFor
	
End

//Kills all the visible external function parameters controls
Static Function KillExtParams()
	Variable i
	Do
		ControlInfo/W=NL $("param" + num2str(i))
		
		If(V_flag != 0)
			KillControl/W=NL $("param" + num2str(i))
		EndIf
		
		i += 1
	While(V_flag != 0)
End

//Handles variable, string, and wave inputs to external function parameter inputs
Function nlExtParamProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	DFREF NLF = root:Packages:NeuroLive
	SVAR func = root:Packages:NeuroLive:selFunction
	
	//holds the parameters of the external functions
	Wave/T param = NLF:ExtFunc_Parameters
	
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
			Variable dval = sva.dval
			String sval = sva.sval
			
			String name = sva.ctrlName
			Variable paramIndex = ExtFuncParamIndex(name)
			
			String type = getParam("PARAM_" + num2str(paramIndex) + "_TYPE",func)
			
			strswitch(type)
				case "4"://variable
					setParam("PARAM_" + num2str(paramIndex) + "_VALUE",func,num2str(dval))
					break
				case "8192"://string
					setParam("PARAM_" + num2str(paramIndex) + "_VALUE",func,sval)
					break
				case "16386"://wave
					setParam("PARAM_" + num2str(paramIndex) + "_VALUE",func,sval)
					//confirm validity of the wave reference
					ControlInfo/W=NT $sva.ctrlName
					break
			endswitch
			
			break
		case 3: // Live update
			
			break
		case -1: // control being killed
			break
	endswitch	
	return 0
End

Function nlExtParamCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	
	DFREF NLF = root:Packages:NeuroLive
	SVAR func = root:Packages:NeuroLive:selFunction
	
	//holds the parameters of the external functions
	Wave/T param = NLF:ExtFunc_Parameters
	
	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			
			String name = cba.ctrlName
			Variable paramIndex = ExtFuncParamIndex(name)
			
			String type = getParam("PARAM_" + num2str(paramIndex) + "_TYPE",func)
			
			setParam("PARAM_" + num2str(paramIndex) + "_VALUE",func,num2str(checked))
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


//returns the parameter number for the provided control name for an external function
Static Function ExtFuncParamIndex(ctrlName)
	String ctrlName
	Variable index = str2num(ctrlName[strlen(ctrlName)-1])
	return index
End

Function nlExtParamPopProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	SVAR func = root:Packages:NeuroLive:selFunction
	
	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			
			//Set the value of the external function parameter
			DFREF NLF = root:Packages:NeuroLive
			Wave/T param = NLF:ExtFunc_Parameters
			
			Variable index = ExtFuncParamIndex(pa.ctrlName)
			
			setParam("PARAM_" + num2str(index) + "_VALUE",func,popStr)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Structure NL_abfInfo
	int32 dataFormat
	int32 nSweeps
	int32 nChannels
	int32 startByte
	int32 dataPoints
	string ChannelNames
	string ChannelBase
	string ChannelUnits
	double ChannelScale[8]
	double scaleFactor[8]
	float signalGain[8]
	float ADCprogrammableGain[8]
	float instrumentOffset[8]
	float ADCRange
	int32 ADCResolution
	int32 ChannelIndex[8]
	float signalOffset[8]
	int32 synchArray[3]
	int32 synchArrayPtrByte
	int32 sweepLengthInPts
	int32 dataPtsPerSweep
	float ADCSampleInterval
	float actualSampleInterval
	float synchArrTimeBase
EndStructure