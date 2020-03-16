#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//Package for analyzing images acquired using ScanImage.
//General imaging analysis routine
//BigTiff loading and header reading

//Create the controls for the ScanImage package
Function NT_ScanImage_CreateControls()
	
	//Make the ScanImage package folder
	If(!DataFolderExists("root:Packages:NT:ScanImage"))
		NewDataFolder root:Packages:NT:ScanImage
	EndIf
	
	//Make the ScanImage Scans folder
	If(!DataFolderExists("root:Scans"))
		NewDataFolder root:Scans
	EndIf
	
	DFREF NTSI = root:Packages:NT:ScanImage
	
	//Housekeeping strings and variables
	Variable/G NTSI:numImages
	NVAR numImages = NTSI:numImages
	numImages = 0
	
	Make/O/T/N=(0,1,3) NTSI:ROIListWave /Wave = ROIListWave
	Make/O/N=(0) NTSI:ROISelWave /Wave = ROISelWave
	
	//Outer folder - Scan File, which may contain multiple scans of ROIs and Zs
		//Selection shows the Scan ROIs within that scan group. Z level will be shown as text somewhere else.
	
	//The scan group
	Make/O/T/N=(0,1,3) NTSI:ScanGroupListWave /Wave = ScanGroupListWave
	Make/O/N=(0) NTSI:ScanGroupSelWave /Wave = ScanGroupSelWave
	
	//The scans themselves
	Make/O/T/N=(0,1,3) NTSI:ScanFieldListWave /Wave = ScanFieldListWave
	Make/O/N=(0) NTSI:ScanFieldSelWave /Wave = ScanFieldSelWave
	
	//Get the scan group list wave
	Wave/T listWave = SI_GetScanGroups()
	Redimension/N=(DimSize(listWave,0),-1,-1) ScanGroupListWave,ScanGroupSelWave
	ScanGroupListWave = listWave
	
	Wave/T listWave = SI_GetScanFields()
	Redimension/N=(DimSize(listWave,0),-1,-1) ScanFieldListWave,ScanFieldSelWave
	ScanFieldListWave = listWave
	
	//Create the ScanImage Browsing panel
	NewPanel/N=SI/K=2/W=(0,0,285,500) as "Image Browser"
	
	ListBox scanGroups win=SI,pos={5,30},size={135,450},title="",listWave=ScanGroupListWave,selWave=ScanGroupSelWave,mode=2,proc=siListBoxProc,disable=0
	ListBox scanFields win=SI,pos={145,30},size={135,450},title="",listWave=ScanFieldListWave,selWave=ScanFieldSelWave,mode=4,proc=siListBoxProc,disable=0
	Button displayScanField win=SI,pos={146,10},size={60,20},title="Display",font=$LIGHT,proc=siButtonProc,disable=0
	Button addScanField win=SI,pos={210,10},size={70,20},title="Add Scan",font=$LIGHT,proc=siButtonProc,disable=0
	
	NT_ScanImage_CreateControlLists()
	
End


//Assigns control variables to functions from the 'Command' pop up menu
Function NT_ScanImage_CreateControlLists()
	DFREF NTF = root:Packages:NT
	Wave/T controlAssignments = NTF:controlAssignments 
	NVAR numMainCommands = NTF:numMainCommands
	
	//Resize for the Imaging package commands
	Redimension/N=(numMainCommands + 2,3) controlAssignments
	
	//SCANIMAGE PACKAGE
	controlAssignments[numMainCommands][0] = "SI: Get ROI"
	controlAssignments[numMainCommands][1] = "scanGroups;scanFields;baselineSt;baselineEnd;peakSt;peakEnd;filterSize;channelSelect;dFSelect;"
	controlAssignments[numMainCommands][2] = "400"
	
	controlAssignments[numMainCommands+1][0] = "SI: dF Map"
	controlAssignments[numMainCommands+1][1] = "scanGroups;scanFields;baselineSt;baselineEnd;peakSt;peakEnd;filterSize;channelSelect;dFSelect;"
	controlAssignments[numMainCommands+1][2] = "400"
	
	
End

//Returns a text wave with all available scan group (folders)
Function/Wave SI_GetScanGroups()
	DFREF NTSI = root:Packages:NT:ScanImage
	DFREF NTS = root:Scans
	
	String folders = StringByKey("FOLDERS",DataFolderDir(1,NTS),":",";")
	
	Wave/T listWave = StringListToTextWave(folders,",")
	return listWave
End

//Returns a text wave with all available scans that are within each scan group
Function/Wave SI_GetScanFields([group])
	String group 
	
	DFREF saveDF = $GetDataFolder(1)
	DFREF NTSI = root:Packages:NT:ScanImage
	Wave/T ScanGroupListWave = NTSI:ScanGroupListWave
	
	If(ParamIsDefault(group))
		group = TextWaveToStringList(ScanGroupListWave,",")
	EndIf
	
	Variable i
	String list = ""
	For(i=0;i<ItemsInList(group,";");i+=1)
		String groupPath = "root:Scans:" + StringFromList(i,group,",")

		If(!DataFolderExists(groupPath))
			Abort "Scan group '" + group + "' does not exist"
		EndIf
		
		DFREF NTG = $groupPath
		
		SetDataFolder NTG
		
		//Get all 3D waves
		list += WaveList("*",";","DIMS:3")
	EndFor
	
	Wave/T listWave = StringListToTextWave(list,";")
	return listWave
End


Function/WAVE GetSelectedImage()
	DFREF NTSI = root:Packages:NT:ScanImage
	Wave/T listWave = NTSI:ScanGroupListWave
	
	//Get the scan group
	ControlInfo/W=SI scanGroups
	
	If(V_Value == -1) //no selection
		return $""
	EndIf
	
	String imagePath = "root:Scans:" + listWave[V_Value] + ":"
	
	//Get the scanfield
	Wave/T listWave = NTSI:ScanFieldListWave
	Wave selWave = NTSI:ScanFieldSelWave
	
	If(sum(selWave) == 0)
		return $"" //no selection
	EndIf
	
	Variable i,index
	For(i=0;i<DimSize(selWave,0);i+=1)
		If(selWave[i] == 1)
			index = i
			break
		EndIf
	EndFor
	
	ControlInfo/W=SI scanFields

	imagePath += listWave[index]
	
	If(!WaveExists($imagePath))
		return $""
	EndIf
	
	return $imagePath
End
	
//Opens the scanfield display and displays the selected image stack
Function DisplayScanField(theImage[,add])
	Wave theImage
	Variable add
	
	If(!WaveExists(theImage))
		return 0
	EndIf
	
	If(ParamIsDefault(add))
		add = 0
	EndIf
	
	DFREF NTSI = root:Packages:NT:ScanImage
	NVAR numImages = NTSI:numImages
	numImages += 1
	
	Variable xPixels,yPixels,frames,xSize,ySize
	
	Variable xDim,yDim
	xDim = DimSize(theImage,0) * DimDelta(theImage,0)
	yDim = DimSize(theImage,1) * DimDelta(theImage,1)
	
	xPixels = DimSize(theImage,0)
	yPixels = DimSize(theImage,1)
	frames = DimSize(theImage,2)
	
	//sizing of the panel
	If(xDim > yDim)
		xSize = 500
		ySize = round(500 * yDim/xDim) + 25  //extra 25 pixels for a control bar
	Else
		xSize = round(500 * xDim/yDim)
		ySize = 500 + 25 //extra 25 pixels for a control bar
	EndIf
	
	//put the new image panel next to the Image Browser window
	GetWindow/Z SI wsize
	Variable leftOffset = V_left + 285

	//Make the master panel or resize it if it exists already
	GetWindow/Z SIDisplay wsize
	
	If(!V_flag) //exists
			
		If(add)
			ySize += abs(V_bottom - V_top) - 25
			
		Else
			numImages = 1
		EndIf
		
		
		MoveWindow/W=SIDisplay V_left,V_top,V_left + xSize,V_top + ySize
		
		//Append the image
		
		//Define bottom guides in case of multiple images
		Variable i
	
		
		Variable fraction = i / numImages
		DefineGuide/W=SIDisplay#image $("imageBottom" + num2str(i)) = {FT,fraction,FB}
		Display/HOST=SIDisplay#image/FG=(FL,FT,FR,FB)/N=$("graph" + num2str(i))  	
		AppendImage/W=$("SIDisplay#image#graph" + num2str(i))/L/T theImage	
		ModifyImage/W=$("SIDisplay#image#graph" + num2str(i)) $NameOfWave(theImage) plane=0
		ModifyGraph/W=$("SIDisplay#image#graph" + num2str(i)) noLabel=2,axThick=0,standoff=0,btLen=2,margin=-1
	
		
		//Bring panel to the front
		DoWindow/F SIDisplay
		return 0
	EndIf

	//display panel doesn't exist
	NewPanel/K=1/W=(leftOffset,0,leftOffset + xSize,ySize)/N=SIDisplay as "Scanfield Display"	
	ModifyPanel/W=SIDisplay frameStyle=0
	
	//Make the image part of the panel
	DefineGuide/W=SIDisplay imageDivide = {FT,25}
	
	If(numImages > 1)
		fraction = (numImages - 1) / numImages
	Else
		fraction = 1
	EndIf
	
	String bDivide = "imageBottom" + num2str(numImages-1)
	
	DefineGuide/W=SIDisplay $bDivide = {FT,fraction,FB}
	NewPanel/HOST=SIDisplay/N=image/FG=(FL,imageDivide,FR,$bDivide)	
	ModifyPanel/W=SIDisplay#image frameStyle=0
	
	//Make the control bar part of the panel
	NewPanel/HOST=SIDisplay/N=control/FG=(FL,FT,FR,imageDivide)
	ModifyPanel/W=SIDisplay#control frameStyle=0
	
	//Make the control panel
	Button playFrames win=SIDisplay#control,pos={5,0},size={35,25},font=$LIGHT,title="Play",disable=0,proc=handlePlayFrames
	
	//What are the autoscaled min max values? Directly telling Igor what these are greatly speeds up frame play.
	Variable maxVal = WaveMax(theImage)
	Variable minVal = WaveMin(theImage)
	
	//Append the image
	Display/HOST=SIDisplay#image/FG=(FL,FT,FR,FB)/N=graph
	AppendImage/W=SIDisplay#image#graph/L/T theImage
	ModifyImage/W=SIDisplay#image#graph $NameOfWave(theImage) plane=0,ctab= {minVal,maxVal,Grays,0}
	ModifyGraph/W=SIDisplay#image#graph noLabel=2,axThick=0,standoff=0,btLen=2,margin=-1
	
	//Bring panel to the front
	DoWindow/F SIDisplay
End

//Starts and stops the frame play background task
Function handlePlayFrames(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			String/G root:Packages:NT:imageName
			SVAR name = root:Packages:NT:imageName
			name = RemoveEnding(ImageNameList("SIDisplay#image#graph",";"),";")
			
			Variable/G root:Packages:NT:imagePlane
			NVAR plane = root:Packages:NT:imagePlane
			
			Variable/G root:Packages:NT:isPlaying
			NVAR isPlaying = root:Packages:NT:isPlaying
			
			plane = str2num(StringByKey("plane",ImageInfo("SIDisplay#image#graph",name,0),"=",";"))
			
			If(isPlaying)
				StopFramePlay()
			Else
				StartFramePlay()
			EndIf
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

//Start the background task for playing image frames
Function StartFramePlay()
	NVAR isPlaying = root:Packages:NT:isPlaying
	Variable numTicks = 5		// Run every two seconds (120 ticks)
	CtrlNamedBackground play, period=numTicks, proc=playFramesBackroundTask
	CtrlNamedBackground play, start
	isPlaying = 1
End

//Stop the background task for playing image frames
Function StopFramePlay()
	NVAR isPlaying = root:Packages:NT:isPlaying
	CtrlNamedBackground play, stop
	isPlaying = 0
End

//Background task for playing the image frames
Function playFramesBackroundTask(s)
	STRUCT WMBackgroundStruct &s
	SVAR name = root:Packages:NT:imageName
	NVAR plane = root:Packages:NT:imagePlane
	plane += 1
	
	If(plane > DimSize($name,2))
		plane = 0
	EndIf
	
	DoWindow SIDisplay
	If(!V_Flag)
		StopFramePlay()
		return 0
	EndIf
	
	ModifyImage/Z/W=SIDisplay#image#graph $name plane=plane
	DrawAction/W=SIDisplay#control delete
	DrawText/W=SIDisplay#control 350,20,"Frame: " + num2str(plane) + ", " + num2str(plane * DimDelta($name,2)) + "s"
	return 0
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
	Variable hookResult = 0
	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			
			break
		case 2: // mouse up
			//display the full path to the wave in a text box
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
	return hookResult
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
					//displays the selected scanfield in a new panel
					Wave theImage = GetSelectedImage()
					DisplayScanField(theImage)
					break
				case "addScanfield":
					//displays the selected scanfield in a new panel
					Wave theImage = GetSelectedImage()
					DisplayScanField(theImage,add=1)
					break
			endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return hookResult
End