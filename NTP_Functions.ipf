#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//Command functions that are built into NeuroTools

//RUN COMMAND MASTER FUNCTION
Function RunCmd(cmd)
	String cmd
	DFREF NPC = $CW
	
	//Initialize data set info structure
	STRUCT ds ds
	
	//Make sure a timer is available
	ResetAllTimers()
	
	//Save data folder
	DFREF saveDF = $GetDataFolder(1)
	
	//Special treatment for some functions that may not use any data sets
	strswitch(cmd)
		case "Run Cmd Line":
//			NT_RunCmdLine()
			
			//Check that the contents exist, if not, grey them out
			CheckDataSetWaves()
			return 0
		case "New Data Folder":
//			NT_NewDataFolder()
//			return 0
		case "Kill Data Folder":	
//			NT_KillDataFolder()
//			return 0
		case "External Function":
			//Get the data set info
			Variable error = GetDataSetInfo(ds)
			break
		case "Max Project":
			error = GetDataSetInfo(ds)
			break
		case "Load Ephys":
//			NT_LoadEphys()
			
			return 0
			break
		case "Load WaveSurfer":
//			SVAR wsFilePath = NPC:wsFilePath
//			SVAR wsFileName = NPC:wsFileName
//			ControlInfo/W=NTP ChannelSelector
//			
//			Wave/T wsFileListWave = NPC:wsFileListWave
//			Wave wsFileSelWave = NPC:wsFileSelWave
//			
//			Variable i
//			String filePathList = ""
//
//			//Get the selected files
//			For(i=0;i<DimSize(wsFileListWave,0);i+=1)
//				If(wsFileSelWave[i] ==1)
//					filePathList += wsFilePath + wsFileListWave[i] + ";"
//				EndIf
//			EndFor
//			
//			//no selection, load all of them
//			If(sum(wsFileSelWave) == 0)
//				filePathList = ""
//				For(i=0;i<DimSize(wsFileListWave,0);i+=1)
//					filePathList += wsFilePath + wsFileListWave[i] + ";"
//				EndFor
//			EndIf
//			
//			NT_Load_WaveSurfer(filePathList,channels=S_Value)
//			return 0
			break
		case "Load pClamp":
			SVAR wsFilePath = NPC:wsFilePath
			SVAR wsFileName = NPC:wsFileName
			ControlInfo/W=NTP ChannelSelector
			
			Wave/T wsFileListWave = NPC:wsFileListWave
			Wave wsFileSelWave = NPC:wsFileSelWave
			
			String filePathList = ""
			Variable i
			
			//Get the selected files
			For(i=0;i<DimSize(wsFileListWave,0);i+=1)
				If(wsFileSelWave[i] ==1)
					filePathList += wsFilePath + wsFileListWave[i] + ";"
				EndIf
			EndFor
			
			//no selection, load all of them
			If(sum(wsFileSelWave) == 0)
				filePathList = ""
				For(i=0;i<DimSize(wsFileListWave,0);i+=1)
					filePathList += wsFilePath + wsFileListWave[i] + ";"
				EndFor
			EndIf
			
			For(i=0;i<ItemsInList(filePathList,";");i+=1)
				String theFile = StringFromList(i,filePathList,";") + ".abf"
				ABFLoader(theFile,S_Value,1)
			EndFor
			return 0
			break
		//Imaging package commands
		case "Load Scans":
		case "Population Vector Sum":
		case "Load Suite2P":
//		case "Max Project":
			//Executes this middle-man function from the command line to escape the .ipf,
			//allowing me to reference potentially uncompiled functions in other packages.
			Execute/Q/Z "RunCmd_ScanImagePackage(\"" + cmd + "\"" + ")"
			return 0	
		default:
			//Get the data set info
//			error = GetDataSetInfo(ds,extFunc=1)
			error = GetDataSetInfo(ds)
	endswitch
	
	
	
	If(error == -1)
		//reserved, doesn't break bc data sets aren't required necessarily
		return 0
	EndIf
	
	//Get the workflow structure
//	STRUCT workflow wf
//	GetWorkFlow(wf)
	
	//Start a timer
	Variable ref = StartMSTimer
	
	//Reset the output waveset wave
	Redimension/N=0 ds.output
	
	//WSN loop
	Do
		//Get the waves in the current WSN
		Wave/WAVE ds.waves = GetWaveSetRefs(ds.listWave,ds.wsn,ds.name)
		Redimension/N=(DimSize(ds.Waves,0),DimSize(ds.Waves,1)) ds.paths
		
		For(i=0;i<ds.numDataSets;i+=1)
		
			String fullPaths = GetWaveSetList(ds.listWave,ds.wsn,1,dsNum=i)
			
			//Remove any potential empty positions that might be at the end of the list wave if the two data sets have different numbers of waves
			fullPaths = RemoveEmptyItems(fullPaths,";")
			
			Wave/T tempPaths = StringListToTextWave(fullPaths,";")
			
			Redimension/N=(DimSize(ds.paths,0)) tempPaths
			If(DimSize(tempPaths,0) > 0)
				ds.paths[][i] = tempPaths[p][0]		
			EndIf
			ds.numWaves[i] = ItemsInList(fullPaths,";")
		EndFor
	
		
		//Execute the function returns optional output waves
//		Do
			//Run the next command in the workflow
//			Wave/WAVE out = ExecuteCommand(ds,wf.cmds[wf.i])
		
		//Make sure we start at the same point every call to the function in case of current data folder wave references
		SetDataFolder saveDF
		
		Wave/WAVE out = ExecuteCommand(ds,cmd)
		
			
			//Re-build the ds structure according to the output from the previous command
			
//			wf.i += 1
//		While(wf.i < wf.numCmds)
		
		//Increment to the next WSN
		ds.wsn += 1
		
		//Reset the WSI
		ds.wsi = 0
	While(ds.wsn < ds.numWaveSets[0])
	
	//If output waves were assigned in the function, make a new data set
	If(DimSize(ds.output,0))
		//Change the listbox focus to data set before creating the data set output
		changeFocus("DataSet",1)
		
		//create output data set 
		CreateOutputDataSet(ds)
	EndIf
	
	//Make progress bar invisible
//	ValDisplay progress win=NT,disable=1
	
	//End the timer
	print cmd + ":",StopMSTimer(ref)/(1e6),"s"
	
	//Return to original data folder
	SetDataFolder saveDF
	
	//Check data set wave existence in case waves were deleted or renamed during execution
	CheckDataSetWaves()
	
	//Update the folders and wave listWaves
	updateFolders()
	updateFolderWaves()
	
	
	//animate a notification that the function ran
	String/G NPC:notificationEntry
	SVAR notificationEntry = NPC:notificationEntry
	notificationEntry = "Function:  \f01" + cmd + "()"
	SendNotification()
End

//Takes a Command string, executes the corresponding function
Function/WAVE ExecuteCommand(ds,cmd)
	STRUCT ds &ds
	String cmd
		
	String extCmd = CurrentExtFunc()
			
	If(cmpstr(extCmd,"Write Your Own"))
		//Save the data set structure so the external function can retrieve it.
		SaveStruct(ds)
	EndIf
	
	RunExternalFunction(extCmd)
	
	return $""
	
	strswitch(cmd)
		case "Average":
//			NT_Average(ds)
			Wave/WAVE out = $""
			break
		case "Errors":
//			NT_Error(ds)
			Wave/WAVE out = $""
			break
		case "Measure":
//			NT_Measure(ds)
			Wave/WAVE out = $""
			break
		case "Set Wave Note":
//			NT_SetWaveNote(ds)
			Wave/WAVE out = $""
			break
		case "PSTH":
//			NT_PSTH(ds)
			Wave/WAVE out = $""
			break
		case "Subtract Mean":
//			NT_SubtractMean(ds)
			Wave/WAVE out = $""
			break
		case "Subtract Trend":
//			NT_SubtractTrend(ds)
			Wave/WAVE out = $""
			break
		case "Duplicate Rename":
//			NT_DuplicateRename(ds)
			Wave/WAVE out = $""
			break
		case "delSuffix":
			delSuffix(ds)
			Wave/WAVE out = $""
			break
		case "Move To Folder":
//			NT_MoveToFolder(ds)
			Wave/WAVE out = $""
			break
		case "Run Cmd Line":
//			NT_RunCmdLine()
			Wave/WAVE out = $""
			break
		case "Kill Waves":
//			NT_KillWaves(ds)
			Wave/WAVE out = $""
			break
		case "New Data Folder":
//			NT_NewDataFolder()
			Wave/WAVE out = $""
			break
		case "Kill Data Folder":
//			NT_KillDataFolder()
			Wave/WAVE out = $""
			break
		case "External Function":
			extCmd = CurrentExtFunc()
			
			If(cmpstr(extCmd,"Write Your Own"))
				//Save the data set structure so the external function can retrieve it.
				SaveStruct(ds)
			EndIf
			
			RunExternalFunction(extCmd)
			break
			
		//ScanImage Packages Functions
		case "Max Project":
		case "Vector Sum Map":
		case "Get ROI":
		case "dF Map":
		case "Response Quality":
		case "Align Images":
			SaveStruct(ds)
			Execute/Q/Z "RunCmd_ScanImagePackage(\"" + cmd + "\"" + ")"
			break
	endswitch
	
	return out
End

//Performs various measurements on the data set and puts the result in an output wave
Function NT_Measure(DS_Waves,menu_Type,StartTime,EndTime,BaselineStart,BaselineEnd,Threshold,Width,cb_SubtractBaseline,menu_SortOutput,AngleWave,menu_ReturnType,menu_OSReturnType)
	String DS_Waves,menu_Type
	Variable StartTime,EndTime,BaselineStart,BaselineEnd,Threshold,Width,cb_SubtractBaseline
	String menu_SortOutput,AngleWave,menu_ReturnType,menu_OSReturnType
	
	String menu_Type_List = "Peak;Peak Location;Area;Mean;Median;Std. Dev.;Std. Error;# Spikes;Orientation Vector Sum;Vector Sum;"
	String menu_Type_Proc = "measureProc" //this identifies a trigger procedure based on the menu selection
	String menu_ReturnType_List = "All;Angle;DSI;Resultant;"
	String menu_OSReturnType_List = "Angle;OSI;Resultant;"
	String menu_SortOutput_List = "Linear;Alternating;"
	String Threshold_Assign = "root:Packages:NeuroToolsPlus:ControlWaves:threshold" //assigns the threshold variable to the Viewer Graph threshold bar
	String StartTime_Assign = "root:Packages:NeuroToolsPlus:ControlWaves:rangeLeft"
	String EndTime_Assign = "root:Packages:NeuroToolsPlus:ControlWaves:rangeRight"
	
	STRUCT ds ds
	GetStruct(ds)
	
//	Note={
//	Performs a variety of different measurements on the input waves.
//	Output is a single wave per waveset.
// 
// Most variables are self explanatory except for a few:
// \f01Width\f00 : Takes the average within that size window around the peak. 
// \f01SortOutput\f00 : Sorts the output wave from if the data is alternating or linear (unsorted)
//     -e.g. alternating directions (0°,180°,45°...) will be sorted 0° to 315°
// \f01AngleWave\f00 : Angles used for the vector sum. This can be an math expression 
//     to be evaluated at runtime, a path to a wave, or a list of angles.
//	}
	
	
	//Get input parameters
	
	//no waves defined
	If(DimSize(ds.waves,0) == 0)
		return 0
	EndIf
	
	
	//Wave note
	String theNote = ""
	
	strswitch(menu_Type)
		case "Peak":
			String suffix = "_pk"
			theNote = "Peak:\n"
			break
		case "Peak Location":
			suffix = "_pkLoc"
			theNote = "Peak Location:\n"
			break
		case "Area":
			suffix = "_area"
			theNote = "Area:\n"
			break
		case "Mean":
			suffix = "_mean"
			theNote = "Average:\n"
			break
		case "Median":
			suffix = "_med"
			theNote = "Median:\n"
			break
		case "Std. Dev.":
			suffix = "_sdev"
			theNote = "Std. Deviation:\n"
			break
		case "Std. Error":
			suffix = "_sem"
			theNote = "Std. Error:\n"
			break
		case "# Spikes":
			suffix = "_spkct"
			theNote = "Spike Count:\n"
			break
		case "Vector Sum":
			theNote = "Vector Sum:\n"
				
			strswitch(menu_ReturnType)
				case "Angle":
					suffix = "_vAng"
					String returnItem = "angle"
					break
				case "Resultant":
					suffix = "_vRes"
					returnItem = "resultant"
					break
				case "DSI":
					suffix = "_vDSI"
					returnItem = "DSI"
					break
				case "All":
					suffix = "_All"
					returnItem = "All"
					break
			endswitch
			break
		case "Orientation Vector Sum":
			theNote = "OS Vector Sum:\n"
				
			strswitch(menu_OSReturnType)
				case "Angle":
					suffix = "_vAng"
					returnItem = "angle"
					break
				case "Resultant":
					suffix = "_vRes"
					returnItem = "resultant"
					break
				case "OSI":
					suffix = "_vOSI"
					returnItem = "OSI"
					break
			endswitch
			
			break
	endswitch
	
	//Saves original value of the EndTime in case it needs adjusting to put into valid range
	Variable origEndTm = EndTime 	

	//Make the output wave
	String outName = ds.paths[0][0] + suffix
	Make/O/N=(ds.numWaves[0]) $outName /Wave = outWave
	
	//Add to the output data set
	AddOutput(outWave,ds)
	
	//Make the measurement
	ds.wsi = 0
	Do
		Wave theWave = ds.waves[ds.wsi]
		
		//Ensure valid point range
		If(EndTime == 0 || EndTime < StartTime)
			StartTime = 0
			EndTime = x2pnt(theWave,DimSize(theWave,0))
		EndIf
		
		WaveStats/Q/R=(StartTime,EndTime) theWave
		
		strswitch(menu_Type)
			case "Peak": //peak
				outWave[ds.wsi] = V_max
				
				If(cb_subtractBaseline)
					If(BaselineEnd == 0)
						BaselineStart = pnt2x(theWave,0)
						BaselineEnd = pnt2x(theWave,DimSize(theWave,0) - 1)
					EndIf
					
					If(BaselineEnd < BaselineStart)
						DoAlert 0,"Baseline End must be after Baseline Start"
						return 0
					EndIf
					
					Variable bgnd = mean(theWave,2,4)
					outWave[ds.wsi] -= bgnd
				EndIf
				
				break
			case "Peak Location": //peak x location
				outWave[ds.wsi] = V_maxLoc
				break
			case "Area": //area
				If(cb_subtractBaseline)
					If(BaselineEnd == 0)
						BaselineStart = pnt2x(theWave,0)
						BaselineEnd = pnt2x(theWave,DimSize(theWave,0) - 1)
					EndIf
					
					If(BaselineEnd < BaselineStart)
						DoAlert 0,"Baseline End must be after Baseline Start"
						return 0
					EndIf
					
					bgnd = mean(theWave,BaselineStart,BaselineEnd)
					Duplicate/FREE theWave,temp
					temp -= bgnd
					outWave[ds.wsi] = area(temp,StartTime,EndTime)
				Else
					outWave[ds.wsi] = area(theWave,StartTime,EndTime)
				EndIf
				
				break
			case "Mean": //mean
				outWave[ds.wsi] = V_avg
				break
			case "Median": //median
				outWave[ds.wsi] = median(theWave,StartTime,EndTime)
				break
			case "Std. Dev.": //sdev
				outWave[ds.wsi] = V_sdev
				break
			case "Std. Error": //sem
				outWave[ds.wsi] = V_sem
				break
			case "# Spikes": //spike count
				outWave[ds.wsi] = GetSpikeCount(theWave,StartTime,EndTime,Threshold)
				break
			case "Vector Sum": //vector sum
				String angles = GetVectorSumAngles(ds,AngleWave)
				
				If(!cmpstr(returnItem,"All"))
					KillWaves/Z outWave
					VectorSum(theWave,angles,returnItem)
				Else
					outWave[ds.wsi] = VectorSum(theWave,angles,returnItem)
				EndIf
							
				menu_SortOutput = "Linear"
				break
			case "Orientation Vector Sum": //vector sum
				angles = GetVectorSumAngles(ds,AngleWave)
		
				outWave[ds.wsi] = OSVectorSum(theWave,angles,returnItem)
				
				menu_SortOutput = "Linear"
				break
		endswitch
		
		//Add wave name to wave note
		theNote += ds.paths[ds.wsi][0] + "\n"
		
		//Reset the end point to its original value for the next wave
		EndTime = origEndTm
		
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
	
	//Optional sorting
	strswitch(menu_SortOutput)
		case "Linear":
			break
		case "Alternating":
			Make/O/FREE/N=(DimSize(outWave,0)) sortKey
			Variable halfway = floor(DimSize(outWave,0) / 2)
			
//			sortKey = {0,4,1,5,2,6,3,7, etc...}
			sortKey[0,*;2] = p/2
			sortKey[1,*;2] = halfway + (p-1)/2
			
			Sort sortKey,outWave
			break
	endswitch
	
	If(WaveExists(outWave))
		Note outWave,theNote
	EndIf
End

//Averages the waves
//Function/WAVE NT_AverageFilter(DS_Waves,CDF_Filter,outFolder,cb_ReplaceSuffix,cb_isCircular,[free])
	String DS_Waves,CDF_Filter //data set reference
	String outFolder //output folder location
	Variable cb_ReplaceSuffix //replace suffix checkbox
	Variable cb_isCircular //is this circular data
	Variable free
	
	//loads up the data set info structure
	STRUCT ds ds 
	GetStruct(ds)

	//Reset wsi in case this function has been passed to
	ds.wsi = 0
	
	//Set the output data folder
	DFREF cdf = GetDataFolderDFR()
	
	//If it's a full path folder
	free = (ParamIsDefault(free)) ? 0 : 1
	
	Wave filter = ds.waves[0][1]
	
	If(!free)
		If(stringmatch(outFolder,"root*"))
			Variable i = 0
			String sub = ""
			Do
				sub += ParseFilePath(0,outFolder,":",0,i) + ":"
				
				If(!DataFolderExists(sub))
					NewDataFolder $RemoveEnding(sub,":")
				EndIf
				
				i += 1
			While(i < ItemsInList(outFolder,":"))
			
			SetDataFolder outFolder
		Else
			If(strlen(outFolder))
				If(!DataFolderExists(GetWavesDataFolder(ds.waves[0],1) + outFolder))
					NewDataFolder $(GetWavesDataFolder(ds.waves[0],1) + outFolder)
				EndIf
			EndIf
			SetDataFolder GetWavesDataFolder(ds.waves[0],1) + outFolder
		EndIf
	EndIf
	
	//Make output wave for each wave set
	If(cb_ReplaceSuffix)
		String outputName = ReplaceSuffix(NameOfWave(ds.waves[0]),"avg")
	Else
		outputName = NameOfWave(ds.waves[0]) + "_avg"
	EndIf
	
	//What is the wave type?
	Variable type = WaveType(ds.waves[0])
		
	//Real wave
	switch(type)
		case 72: //unsigned 8 bit integer
			Make/O/N=(DimSize(ds.waves[0],0),DimSize(ds.waves[0],1),DimSize(ds.waves[0],2))/B/U $outputName
			break
		case 2: //single float 32 bit
			Make/O/N=(DimSize(ds.waves[0],0),DimSize(ds.waves[0],1),DimSize(ds.waves[0],2))/S $outputName
			break
		case 8: //signed 8 bit integer
			Make/O/N=(DimSize(ds.waves[0],0),DimSize(ds.waves[0],1),DimSize(ds.waves[0],2))/B $outputName
			break
		case 16: //unsigned 16 bit word
			Make/O/N=(DimSize(ds.waves[0],0),DimSize(ds.waves[0],1),DimSize(ds.waves[0],2))/W $outputName
	endswitch
	Wave outWave = $outputName

	
	//Reset outWave in case of overwrite
	outWave = 0
	
	//Set the scale of the output wave
	SetScale/P x,DimOffset(ds.waves[0],0),DimDelta(ds.waves[0],0),outWave
	SetScale/P y,DimOffset(ds.waves[0],1),DimDelta(ds.waves[0],1),outWave
	SetScale/P z,DimOffset(ds.waves[0],2),DimDelta(ds.waves[0],2),outWave
	
//	WSI loop
	//Do the average calculation
	String noteStr = "Average: " + num2str(ds.numWaves[0]) + " Waves\r"
	
	If(cb_isCircular)
		//Circular data
		Wave theWave = ds.waves[0]		
		Make/FREE/N=(DimSize(theWave,0)) xTotal,yTotal
		xTotal = 0
		yTotal = 0
		Do
			If(filter[ds.wsi] == 0)
				ds.wsi += 1
				If(ds.wsi > ds.numWaves[0] - 1)
					break
				EndIf
				continue
			EndIf
			
			Wave theWave = ds.waves[ds.wsi][0]
				
			If(WaveMax(theWave) > 2*pi)
				//probably degrees
				MatrixOP/O/FREE xComp = cos(theWave * pi/180)
				MatrixOP/O/FREE yComp = sin(theWave * pi/180)
				xTotal += xComp
				yTotal += yComp
				
			Else
				//probably radians
				MatrixOP/O/FREE xComp = cos(theWave)
				MatrixOP/O/FREE yComp = sin(theWave)
				xTotal += xComp
				yTotal += yComp
				
			EndIf		

			noteStr += ds.paths[ds.wsi][0] + "\r"
			
			ds.wsi += 1
		While(ds.wsi < ds.numWaves[0])
		
		MatrixOP/O/FREE vMean = atan2(yTotal,xTotal)
		
		vMean = vMean * 180/pi
	
		//atan2 outputs data from -pi to +pi. We want it from 0 to +2pi.
		vMean = (vMean < 0) ? vMean + 360 : vMean
		
		outWave = vMean
	Else
		//Linear data
		Do
			
			If(filter[ds.wsi] == 0)
				ds.wsi += 1
				If(ds.wsi > ds.numWaves[0] - 1)
					break
				EndIf
				continue
			EndIf
			
			Wave theWave = ds.waves[ds.wsi][0]

			Multithread outWave += theWave
			
			noteStr += ds.paths[ds.wsi][0] + "\r"
			
			ds.wsi += 1
		While(ds.wsi < ds.numWaves[0])
		
		If(WaveType(outWave) > 7) //any type of integer
			Redimension/S outWave
		EndIf
		
		Multithread outWave /= ds.numWaves[0]
	EndIf
		
	//Set the wave note
	Note/K outWave,noteStr
	
	//Reset data folder
	SetDataFolder cdf
	
	//pass the wave to the calling function
	Duplicate/FREE outWave,freeWave
	
	If(free)
		KillWaves/Z outWave
		return freeWave
	Else
		return outWave
	EndIf
	
End

Function NT_MedianWaves(DS_Waves)
	//TITLE=Median Waves
	String DS_Waves
	
//	Note={
//	Calculates the median for the input waves. Same as averaging 
// waves together, but uses the median.
//	}
	
	STRUCT ds ds 
	GetStruct(ds)
	
	ds.wsi = 0
	DFREF cdf = GetDataFolderDFR()
	
	SetDataFolder GetWavesDataFolder(ds.waves[0],1)
	
	//What is the wave type?
	Variable type = WaveType(ds.waves[0])
	
	//Make the output wave of the same type
	String outputName = NameOfWave(ds.waves[0]) + "_med"
	Make/O/N=(DimSize(ds.waves[0],0),DimSize(ds.waves[0],1),DimSize(ds.waves[0],2))/Y=(type) $outputName
	Wave outWave = $outputName
	
	//Set the scale of the output wave
	String xDim = WaveUnits(ds.waves[0],0)
	String yDim = WaveUnits(ds.waves[0],1)
	String zDim = WaveUnits(ds.waves[0],2)
	
	SetScale/P x,DimOffset(ds.waves[0],0),DimDelta(ds.waves[0],0),xDim,outWave
	SetScale/P y,DimOffset(ds.waves[0],1),DimDelta(ds.waves[0],1),yDim,outWave
	SetScale/P z,DimOffset(ds.waves[0],2),DimDelta(ds.waves[0],2),zDim,outWave
	
	String noteStr = "Median: " + num2str(ds.numWaves[0]) + " Waves\r"
	
	Make/FREE/N=(DimSize(ds.waves[0],0),ds.numWaves[0]) master
	
	Do
		Wave theWave = ds.waves[ds.wsi]
		Multithread master[][ds.wsi] = theWave[p][0]	
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
	
	ds.wsi = 0
		
	Variable i
	For(i=0;i<DimSize(master,0);i+=1)
		MatrixOP/FREE theRow = row(master,i)^t
		outWave[i] = median(theRow)
	EndFor
	
	SetDataFolder cdf
End


//Averages the waves
Function/WAVE NT_Average(DS_Waves,outFolder,cb_ReplaceSuffix,cb_isCircular,[free])
	//TITLE=Average
	String DS_Waves //data set reference
	String outFolder //output folder location
	Variable cb_ReplaceSuffix //replace suffix checkbox
	Variable cb_isCircular //is this circular data
	Variable free
	
//	Note={
//	Averages the waves in each wave set
//	
//	\f01outFolder\f00 : Folder to put the averaged wave.
//	\f01ReplaceSuffix\f00 : End of the wave name is replaced with '_avg'. Otherwise '_avg'
//      is added to the end of the wave name.
//	\f01isCircular\f00 : Check if the data is angular.
//	}
	
	//loads up the data set info structure
	STRUCT ds ds 
	GetStruct(ds)

	//Reset wsi in case this function has been passed to
	ds.wsi = 0
	
	//Set the output data folder
	DFREF cdf = GetDataFolderDFR()
	
	//If it's a full path folder
	free = (ParamIsDefault(free)) ? 0 : 1
	
	If(!free)
		If(stringmatch(outFolder,"root*"))
			Variable i = 0
			String sub = ""
			Do
				sub += ParseFilePath(0,outFolder,":",0,i) + ":"
				
				If(!DataFolderExists(sub))
					NewDataFolder $RemoveEnding(sub,":")
				EndIf
				
				i += 1
			While(i < ItemsInList(outFolder,":"))
			
			SetDataFolder outFolder
		Else
			If(strlen(outFolder))
				If(!DataFolderExists(GetWavesDataFolder(ds.waves[0],1) + outFolder))
					NewDataFolder $(GetWavesDataFolder(ds.waves[0],1) + outFolder)
				EndIf
			EndIf
			SetDataFolder GetWavesDataFolder(ds.waves[0],1) + outFolder
		EndIf
	EndIf
	
	//Make output wave for each wave set
	If(cb_ReplaceSuffix)
		String outputName = ReplaceSuffix(NameOfWave(ds.waves[0]),"avg")
	Else
		outputName = NameOfWave(ds.waves[0]) + "_avg"
	EndIf
	
	//What is the wave type?
	Variable type = WaveType(ds.waves[0])
	
	//Make the output wave of the same type
	If(!free)
		Make/O/N=(DimSize(ds.waves[0],0),DimSize(ds.waves[0],1),DimSize(ds.waves[0],2))/Y=(type) $outputName
		Wave outWave = $outputName
	Else
		Make/O/N=(DimSize(ds.waves[0],0),DimSize(ds.waves[0],1),DimSize(ds.waves[0],2))/Y=(type)/FREE outWave
	EndIf
	
	//Add outwave to the output data set
	If(!free)
		AddOutput(outWave,ds)
	EndIf
	
	//Reset outWave in case of overwrite
	outWave = 0
	
	//Set the scale of the output wave
	String xDim = WaveUnits(ds.waves[0],0)
	String yDim = WaveUnits(ds.waves[0],1)
	String zDim = WaveUnits(ds.waves[0],2)
	
	SetScale/P x,DimOffset(ds.waves[0],0),DimDelta(ds.waves[0],0),xDim,outWave
	SetScale/P y,DimOffset(ds.waves[0],1),DimDelta(ds.waves[0],1),yDim,outWave
	SetScale/P z,DimOffset(ds.waves[0],2),DimDelta(ds.waves[0],2),zDim,outWave
	
//	WSI loop
	//Do the average calculation
	String noteStr = "Average: " + num2str(ds.numWaves[0]) + " Waves\r"
	
	If(cb_isCircular)
		//Circular data
		Wave theWave = ds.waves[0]		
		Make/FREE/N=(DimSize(theWave,0)) xTotal,yTotal
		xTotal = 0
		yTotal = 0
		Do
			Wave theWave = ds.waves[ds.wsi]
				
			If(WaveMax(theWave) > 2*pi)
				//probably degrees
				MatrixOP/O/FREE xComp = cos(theWave * pi/180)
				MatrixOP/O/FREE yComp = sin(theWave * pi/180)
				xTotal += xComp
				yTotal += yComp
				
			Else
				//probably radians
				MatrixOP/O/FREE xComp = cos(theWave)
				MatrixOP/O/FREE yComp = sin(theWave)
				xTotal += xComp
				yTotal += yComp
				
			EndIf		

			noteStr += ds.paths[ds.wsi][0] + "\r"
			
//			updateProgress(ds)
			
			ds.wsi += 1
		While(ds.wsi < ds.numWaves[0])
		
		MatrixOP/O/FREE vMean = atan2(yTotal,xTotal)
		
		vMean = vMean * 180/pi
	
		//atan2 outputs data from -pi to +pi. We want it from 0 to +2pi.
		vMean = (vMean < 0) ? vMean + 360 : vMean
		
		outWave = vMean
	Else
		//Linear data
		
		//accounts for any nans in the data
		Duplicate/FREE ds.waves[0],pnts
		pnts = 0
			
		Do
			Wave theWave = ds.waves[ds.wsi]
			
			//keeps track of nans so division is done properly later on
			If(DimSize(theWave,1) == 0)
				Duplicate/FREE theWave,temp
			
				pnts += 1
				pnts = (numtype(temp[p]) == 2) ? pnts - 1 : pnts
			
				//replace nans with 0
				temp = (numtype(temp[p]) == 2) ? 0 : temp[p]
			
				Multithread outWave += temp
			Else
				Duplicate/FREE theWave,temp
			
				pnts += 1
				pnts = (numtype(temp[p][q]) == 2) ? pnts - 1 : pnts
			
				//replace nans with 0
				temp = (numtype(temp[p][q]) == 2) ? 0 : temp[p][q]
			
				Multithread outWave += temp
			EndIf
			
			noteStr += ds.paths[ds.wsi][0] + "\r"
			
//			updateProgress(ds)
			ds.wsi += 1
		While(ds.wsi < ds.numWaves[0])
		
		
		//Make a float briefly to handle the averaging
		If(WaveType(outWave) > 7) //any type of integer
			Redimension/S outWave
		EndIf
		
//		Multithread outWave /= ds.numWaves[0]
		Multithread outWave /= pnts
	EndIf
	
	Redimension/Y=(type) outWave
		
	//Set the wave note
	Note/K outWave,noteStr
	
	//Reset data folder
	SetDataFolder cdf
	
	//pass the wave to the calling function
	Duplicate/FREE outWave,freeWave
	
	If(free)
//		KillWaves/Z outWave
		return freeWave
	Else
		return outWave
	EndIf
	
End

//Gets the error of the waves - SEM or SDEV
Function/WAVE NT_Error(DS_Waves,menu_errorType,outFolder,cb_ReplaceSuffix,cb_isCircular)
	String DS_Waves,menu_errorType,outFolder
	Variable cb_ReplaceSuffix,cb_isCircular
	
	String menu_errorType_List = "sem;sdev;"
	
	//	Note={
//	Measures the error (sem or sdev) of the waves in each wave set
//	
// \f01errorType\f00 : Standard error or Standard Deviation
//	\f01outFolder\f00 : Folder to put the averaged wave.
//	\f01ReplaceSuffix\f00 : End of the wave name is replaced with '_avg'. Otherwise '_avg'
//      is added to the end of the wave name.
//	\f01isCircular\f00 : Check if the data is angular.
//	}

	STRUCT ds ds
	GetStruct(ds)
	
	
	//First get the averages
	Wave avg = NT_Average(DS_Waves,outFolder,cb_ReplaceSuffix,cb_isCircular,free=1)
	
	//Failed to get the average
	If(!WaveExists(avg))
		return $""
	EndIf
	
	//Reset wsi in case this function has been passed to
	ds.wsi = 0
	
	//Set the output data folder
	DFREF cdf = GetDataFolderDFR()

	//If it's a full path folder
	If(stringmatch(outFolder,"root*"))
		If(!DataFolderExists(outFolder))
			NewDataFolder $outFolder
		EndIf
		SetDataFolder outFolder
	Else
		If(strlen(outFolder))
			If(!DataFolderExists(GetWavesDataFolder(ds.waves[0],1) + outFolder))
				NewDataFolder $(GetWavesDataFolder(ds.waves[0],1) + outFolder)
			EndIf
		EndIf
		SetDataFolder GetWavesDataFolder(ds.waves[0],1) + outFolder
	EndIf

	String suffix = menu_errorType
		
	//Make output wave for each wave set
	If(cb_ReplaceSuffix)
		String outputName = ReplaceSuffix(NameOfWave(ds.waves[0]),suffix)
	Else
		outputName = NameOfWave(ds.waves[0]) + "_" + suffix
	EndIf

	//real wave
	Make/O/N=(DimSize(ds.waves[0],0),DimSize(ds.waves[0],1),DimSize(ds.waves[0],2)) $outputName
	Wave outWave = $outputName
	AddOutput(outWave,ds)
	
	//Reset outWave in case of overwrite
	outWave = 0
	
	//Do the error calculation
	String noteStr = "Errors: " + suffix + "(" + num2str(ds.numWaves[0]) + " Waves)\r"
	Do
		Wave theWave = ds.waves[ds.wsi]
		outWave += (theWave - avg)^2
		noteStr += ds.paths[ds.wsi][0] + "\r"
		
//		updateProgress(ds)
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
	
	//stdev
	outWave = sqrt(outWave / (ds.numWaves[0] - 1))
	
	//sem
	If(!cmpstr(suffix,"sem"))
		//sem
		outWave /= sqrt(ds.numWaves[0])
	EndIf

	//Set the wave note
	Note/K outWave,noteStr
	
	//return to original data folder
	SetDataFolder cdf

	//pass the wave to the calling function
	return outWave
	
End

//Gets the error of the waves - SEM or SDEV
//Function/WAVE NT_ErrorFilter(DS_Waves,CDF_Filter,menu_errorType,outFolder,cb_ReplaceSuffix,cb_isCircular)
	String DS_Waves,CDF_Filter,menu_errorType,outFolder
	Variable cb_ReplaceSuffix,cb_isCircular
	
	String menu_errorType_List = "sem;sdev;"
	
	STRUCT ds ds
	GetStruct(ds)
	
	
	//First get the averages
	Wave avg = NT_AverageFilter(DS_Waves,CDF_Filter,outFolder,cb_ReplaceSuffix,cb_isCircular,free=1)
	
	Wave filter = ds.waves[0][1]
	
	//Failed to get the average
	If(!WaveExists(avg))
		return $""
	EndIf
	
	//Reset wsi in case this function has been passed to
	ds.wsi = 0
	
	//Set the output data folder
	DFREF cdf = GetDataFolderDFR()

	//If it's a full path folder
	If(stringmatch(outFolder,"root*"))
		If(!DataFolderExists(outFolder))
			NewDataFolder $outFolder
		EndIf
		SetDataFolder outFolder
	Else
		If(strlen(outFolder))
			If(!DataFolderExists(GetWavesDataFolder(ds.waves[0],1) + outFolder))
				NewDataFolder $(GetWavesDataFolder(ds.waves[0],1) + outFolder)
			EndIf
		EndIf
		SetDataFolder GetWavesDataFolder(ds.waves[0],1) + outFolder
	EndIf

	String suffix = menu_errorType
		
	//Make output wave for each wave set
	If(cb_ReplaceSuffix)
		String outputName = ReplaceSuffix(NameOfWave(ds.waves[0]),suffix)
	Else
		outputName = NameOfWave(ds.waves[0]) + "_" + suffix
	EndIf

	//real wave
	Make/O/N=(DimSize(ds.waves[0],0),DimSize(ds.waves[0],1),DimSize(ds.waves[0],2)) $outputName
	Wave outWave = $outputName
	
	//Reset outWave in case of overwrite
	outWave = 0
	
	//Do the error calculation
	String noteStr = "Errors: " + suffix + "(" + num2str(ds.numWaves[0]) + " Waves)\r"
	Do
		If(filter[ds.wsi] == 0)
			ds.wsi += 1
			If(ds.wsi > ds.numWaves[0] - 1)
				break
			EndIf
			continue
		EndIf
		
		Wave theWave = ds.waves[ds.wsi]
		outWave += (theWave - avg)^2
		noteStr += ds.paths[ds.wsi][0] + "\r"
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
	
	//stdev
	outWave = sqrt(outWave / (ds.numWaves[0] - 1))
	
	//sem
	If(!cmpstr(suffix,"sem"))
		//sem
		outWave /= sqrt(ds.numWaves[0])
	EndIf

	//Set the wave note
	Note/K outWave,noteStr
	
	//return to original data folder
	SetDataFolder cdf

	//pass the wave to the calling function
	return outWave
	
End

//Makes a histogram of the input waves
Function NT_Histogram(DS_Waves,StartX,EndX,BinSize,cb_Centered,Suffix)
	
	String DS_Waves
	Variable StartX,EndX //these are scaled values, not indexes
	Variable BinSize,cb_Centered
	String Suffix
	
//	Note={
//	Makes a histogram of the input waves.
//	}
	
	STRUCT ds ds
	GetStruct(ds)
	
	ds.wsi = 0
	
	If(!strlen(Suffix))
		Suffix = "hist"
	EndIf
	
	Do
		Wave theWave = ds.waves[ds.wsi]
		SetDataFolder GetWavesDataFolder(theWave,1)
		
		//Output histogram name
		String outName = NameOfWave(theWave) + "_" + Suffix
		
		If(StartX == 0 && EndX == 0)
			EndX = pnt2x(theWave,DimSize(theWave,0) - 1)
		EndIf
		
		Variable numBins = ceil((EndX - StartX) / BinSize)
				
		//Make the histogram wave
		Make/O/N=(numBins) $outName/Wave=hist
		
		//Get the histogram
		If(cb_Centered)
			Histogram/B={StartX,binSize,numBins}/C theWave,hist
		Else
			Histogram/B={StartX,binSize,numBins} theWave,hist
		EndIf
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
End

Function NT_Display(DS_Waves,menu_AxisSeparation)
	String DS_Waves,menu_AxisSeparation
	
	String menu_AxisSeparation_List = "None;Horizontal;Vertical;Grid;"
	
	DFREF NPC = $CW
	
	STRUCT ds ds
	GetStruct(ds)

	If(strlen(DS_Waves))
		GetStruct(ds,waves=DS_Waves)
	Else
		GetStruct(ds)
	EndIf
//	
	ds.wsi = 0
	
	String/G NPC:graphName
	SVAR graphName = NPC:graphName
			
	//Check for first wsn if this is a grid layout
	If(!cmpstr(menu_AxisSeparation,"Grid"))
		If(ds.wsn == 0)
			//Generate a unique graph window name
			graphName = UniqueName("NTDisplay_",6,0)
			
			Display/K=1/B=bottom_0/L=left_0/N=$graphName as "NeuroTools+ Display"
		EndIf
	EndIf
	
	Do
		
		Wave theWave = ds.waves[ds.wsi]
		
		//First display of the graphs if its not Grid format
		strswitch(menu_AxisSeparation)
			case "None":

				If(ds.wsi == 0)
					SVAR graphName = NPC:graphName
					graphName = UniqueName("NTDisplay_",6,0)
					
					Display/K=1/B=bottom/L=left/N=$graphName as "NeuroTools+ Display"
				EndIf
				break
			case "Horizontal":
			case "Vertical":
				Variable horFraction = 1/ds.numWaves[0]
				Variable vertFraction = 1/ds.numWaves[0]
				
				If(ds.wsi == 0)
					SVAR graphName = NPC:graphName
					graphName = UniqueName("NTDisplay_",6,0)
					
					Display/K=1/B=bottom_0/L=left_0/N=$graphName as "NeuroTools+ Display"
				EndIf
				break
			case "Grid":
				horFraction = 1/ds.numWaves[0]
				vertFraction = 1/ds.numWaveSets[0]
				break
		endswitch

		
		strswitch(menu_AxisSeparation)
			case "None":
				AppendToGraph/W=$graphName/B=bottom/L=left theWave
				break
			case "Horizontal":
				String axisB = "bottom_" + num2str(ds.wsi) //wave set index along the horizontal axis
				String axisL = "left_0"
				
				AppendToGraph/W=$graphName/B=$axisB/L=$axisL theWave
				
				//Set the axis limits
				ModifyGraph/W=$graphName axisEnab($axisB)={horFraction * ds.wsi,horFraction  + horFraction * ds.wsi},freePos($axisL)=0,freePos($axisB)=0
				break
			case "Vertical":
				axisB = "bottom_0"
				axisL = "left_" + num2str(ds.wsi) //wave set index along the vertical axis
				
				AppendToGraph/W=$graphName/B=$axisB/L=$axisL theWave
				
				//Set the axis limits
				ModifyGraph/W=$graphName axisEnab($axisL)={vertFraction * ds.wsi,vertFraction  + vertFraction * ds.wsi},freePos($axisB)=0,freePos($axisL)=0
				
				break
			case "Grid":
			   axisB = "bottom_" + num2str(ds.wsi) //wave set index along the horizontal axis
				axisL = "left_" + num2str(ds.wsn) //wave set number along the vertical axis
				
				AppendToGraph/W=$graphName/B=$axisB/L=$axisL theWave
				
				//Set the axis limits
				ModifyGraph/W=$graphName axisEnab($axisL)={vertFraction * ds.wsn,vertFraction  + vertFraction * ds.wsn},axisEnab($axisB)={horFraction * ds.wsi,horFraction  + horFraction * ds.wsi},freePos($axisB)=0,freePos($axisL)=0
				break
		endswitch
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])

End

//Sets the wave note for the waves
Function NT_SetWaveNote(DS_Waves,noteStr,cb_overwrite)
	//SUBMENU=Waves and Folders
	//TITLE=Set Wave Note
	
	String DS_Waves,noteStr
	Variable cb_overwrite
	
	STRUCT ds ds
	GetStruct(ds)
	
	ds.wsi = 0
	
	//Set the wave note of the input waves
	Do
		Wave theWave = ds.waves[ds.wsi]
		If(cb_overwrite)
			Note/K theWave, noteStr
		Else
			Note theWave, noteStr
		EndIf
				
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
End




Function delSuffix(ds)
	STRUCT ds &ds
	
	ControlInfo/W=NTP killOriginals
	Variable killOriginals = V_Value
	
	ds.wsi = 0
	Do
		Wave theWave = ds.waves[ds.wsi]
		
		If(!WaveExists(theWave))
			break
		EndIf
		
		SetDataFolder GetWavesDataFolder(theWave,1)
		
		String newName = RemoveEnding(ParseFilePath(1,NameOfWave(theWave),"_",1,0),"_")
		
		If(!strlen(newName))
			break
		EndIf
		
		If(killOriginals)
			Duplicate/O theWave,$newName
			KillWaves/Z theWave
		Else
			Duplicate/O theWave,$newName
		EndIf
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])

	//Update the list boxes since we've just modified waves
		
	//Builds the match list according to all search terms, groupings, and filters
	getWaveMatchList()
	
	//display the full path to the wave in a text box
	drawFullPathText()
	
End

Function NT_DuplicateRename(DS_Waves,cb_KillOriginals,Position,SubName)
	//SUBMENU=Waves and Folders
	//TITLE=Duplicate Rename
	
	String DS_Waves
	Variable cb_KillOriginals,Position
	String SubName
	
	If(Position < 0)
		return 0
	EndIf
	
	STRUCT ds ds
	GetStruct(ds)
	
	Variable numWaves,j,pos,numAddItems
	String theWaveList,name,newName,posList,ctrlList,addItem
	
	posList = "0;1;2;3;4"
	ctrlList = "prefixName;groupName;seriesName;sweepName;traceName"
	
	ds.wsi = 0
	
	If(ds.numWaves[0] == 0)
		return 0
	EndIf
	
	Do
		Wave theWave = ds.waves[ds.wsi]
		SetDataFolder GetWavesDataFolder(theWave,1)
		
		name = NameOfWave(theWave)
		newName = name
		
		Variable numPositions = ItemsInList(name,"_")
		
		If(Position > numPositions)
			ds.wsi += 1
			If(ds.wsi > ds.numWaves[0] - 1)
				break
			Else
				continue
			EndIf
		EndIf
		
		SubName = resolveListItems(SubName,",")
		SubName = RemoveEnding(SubName,",")
		
		numAddItems = ItemsInList(SubName,",")
		
		If(strlen(SubName))
			If(!cmpstr(SubName,"-"))
				newName = RemoveListItem(Position,newName,"_")		
			Else
				newName = RemoveListItem(Position,newName,"_")
				If(ds.wsi > numAddItems - 1)
					addItem = StringFromList(numAddItems - 1,SubName,",")
				Else
					addItem = StringFromList(ds.wsi,SubName,",")
				EndIf
				
				If(stringmatch(addItem,"*<wsi>*"))
					addItem = ReplaceString("<wsi>",addItem,num2str(ds.wsi))
				ElseIf(stringmatch(addItem,"*<wsn>*"))
					addItem = ReplaceString("<wsn>",addItem,num2str(ds.wsn))
				EndIf
				
				newName = AddListItem(addItem,newName,"_",Position)
				newName = RemoveEnding(newName,"_")
			EndIf
		EndIf
		
		newName = RemoveEnding(newName,"_")
		
		//If no changes in name were made, and we aren't killing the originals, ... 
		//...make the name unique with extra 0,1,2... at the end
		If(!cmpstr(name,newName,1) && !cb_KillOriginals) //case-sensitive
			newName = UniqueName(newName,1,0)
		EndIf
		
		If(cb_KillOriginals)
			If(cmpstr(name,newName))
				ReallyKillWaves($newName)
				try
					Rename $name,$newName;AbortOnRTE
				catch
					Variable error = GetRTError(1)
				endtry
			EndIf
		Else
			Duplicate/O theWave,$newName
		EndIf
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
	
//	Do
//		Wave theWave = ds.waves[ds.wsi]
//		SetDataFolder GetWavesDataFolder(theWave,1)
//		
//		name = NameOfWave(theWave)
//		newName = NameOfWave(theWave)
//		
//		For(j=4;j>-1;j-=1)	//step backwards
//			//new name and the position
//			ControlInfo/W=NTP $StringFromList(j,ctrlList,";")
//			S_Value = resolveListItems(S_value,",")
//			S_Value = RemoveEnding(S_Value,",")
//			
//			numAddItems = ItemsInList(S_Value,",")
//			pos = str2num(StringFromList(j,posList,";"))
//			
//			If(strlen(S_Value))
//				If(!cmpstr(S_Value,"-"))
//					newName = RemoveListItem(pos,newName,"_")		
//				Else
//					newName = RemoveListItem(pos,newName,"_")
//					If(ds.wsi > numAddItems - 1)
//						addItem = StringFromList(numAddItems - 1,S_Value,",")
//					Else
//						addItem = StringFromList(ds.wsi,S_Value,",")
//					EndIf
//					
//					If(!cmpstr(addItem,"<wsi>"))
//						addItem = num2str(ds.wsi)
//					ElseIf(!cmpstr(addItem,"<wsn>"))
//						addItem = num2str(ds.wsn)
//					EndIf
//					
//					newName = AddListItem(addItem,newName,"_",pos)
//					newName = RemoveEnding(newName,"_")
//				EndIf
//			EndIf
//		EndFor
		
//		newName = RemoveEnding(newName,"_")
//		
//		//If no changes in name were made, and we aren't killing the originals, ... 
//		//...make the name unique with extra 0,1,2... at the end
//		If(!cmpstr(name,newName,1) && !cb_KillOriginals) //case-sensitive
//			newName = UniqueName(newName,1,0)
//		EndIf
//		
//		If(cb_KillOriginals)
//			If(cmpstr(name,newName))
//				KillWaves/Z $newName
//				try
//					Rename $name,$newName;AbortOnRTE
//				catch
//					Variable error = GetRTError(1)
//				endtry
//			EndIf
//		Else
//			Duplicate/O theWave,$newName
//		EndIf
//				
//		ds.wsi += 1
//	While(ds.wsi < ds.numWaves[0])

End

Function NT_FilterDataTable(menu_InputSet,menu_OutputSet,FilterTerms)
	String menu_InputSet,menu_OutputSet
	String FilterTerms //Key-value pairs, semi-colon separated
	String FilterTerms_Pos="-1;-1;400;20"
	
	String menu_InputSet_List = GetDataArchives("Archive")
	String menu_OutputSet_List = GetDataArchives("Archive")
	//SUBMENU=Waves and Folders
	//TITLE=Filter Data Table
	
//	Note={
//	Filters the input data set by key-value pairs in FilterTerms.
//	\f01Keys\f00 refer to column labels in the data set archive table.
//	\f01Values\f00 are string matches for that particular column in the table.
//	
// E.g. Comments="*DS Spot*"
//
// Both input and output data sets must be data archives. The input data set isn't 
//overwritten, but the filtered data table is sent as an output data set, 
//which must already exist.
//	}
	
	
	//Make sure both data sets are archived
//	If(!isArchive(DS_InputSet) || !isArchive(DS_OutputSet))
//		Abort "Both data sets must be data archives."
//	EndIf
	
	DFREF NPD = $DSF
	
	Wave/T in = GetDataSetWave(menu_InputSet,"Archive")
	Wave/T out = GetDataSetWave(menu_OutputSet,"Archive")
	
	Duplicate/FREE/T in,temp,outTemp

	If(cmpstr(menu_InputSet,menu_OutputSet))
		Duplicate/O/T in,out
		Redimension/N=(0,-1) out
	EndIf
	
	Variable numTerms = ItemsInList(FilterTerms,";")
	Variable i,j
	
	For(j=0;j<numTerms;j+=1)
		String term = StringFromList(j,FilterTerms,";")
		String key = StringFromList(0,term,"=")
		String value = StringFromList(1,term,"=")
		
		Variable col = FindDimLabel(in,1,key)
		
		If(col == -2)
			continue
		EndIf
		
		//Fill temp table with the filtered outTemp table for each filter term in sequence
		Redimension/N=(DimSize(outTemp,0),DimSize(outTemp,1)) temp
		temp = outTemp
		Redimension/N=(0,-1) outTemp
		
		Variable row = -1,count=0
		Do
			row = tableMatch(value,temp,startp=row+1,whichCol=col)
			
			If(row != -1)
				If(count > DimSize(outTemp,0) - 1)
					Redimension/N=(count + 1,-1) outTemp
				EndIf
				
				outTemp[count][] = temp[row][q]
				count += 1
			EndIf
		While(row != -1)
	EndFor
	
	Redimension/N=(DimSize(outTemp,0),DimSize(outTemp,1)) out
	out = outTemp
End

//Requires 2 archived data sets. The first data set will be renamed as defined in the second data set
Function NT_RenameData(DS_InputWaves,DS_OutputWaves)
	String DS_InputWaves,DS_OutputWaves
	
	//TITLE=Rename Data
	
	//Check that the second data set is archived. This is how the rename is accomplished, since an archived set allows us to define a data set with waves that don't exist yet.
	If(!isArchive(DS_OutputWaves))
		return 0
	EndIf
	
	STRUCT ds ds
	GetStruct(ds)

	If(ds.numWaves[0] != ds.numWaves[1])
		DoAlert 0,"Error: Data sets must have the same number of waves"
		return 0
	EndIf

	ds.wsi = 0
	
	//Duplicate and rename the waves
	Do
		Wave inWave = ds.waves[ds.wsi][0] //fullpath to wave		
		String inPath = ds.paths[ds.wsi][0]
		String outPath = ds.paths[ds.wsi][1] //output wave path to be created
		
		If(!WaveExists(inWave))
			return 0
		EndIf
		
		//wave already exists
		If(!cmpstr(inPath,outPath))
			Duplicate/O inWave,temp
			ReallyKillWaves(inWave)
			Duplicate/O temp,$outPath
			ReallyKillWaves(temp)
		Else
			Duplicate/O inWave,$outPath
		EndIf

		//Check that the duplication succeeded
		Wave outWave = $outPath //fullpath to wave
		If(WaveExists(outWave))
			//Kill the original wave
			ReallyKillWaves(inWave)
		EndIf	
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
End

//Moves waves to the indicated folder within the current data folder
//Use the relative depth to back out of the current data folder.
Function NT_MoveToFolder(DS_Waves,MoveToFolder,RelativeFolder)
	//SUBMENU=Waves and Folders
	//TITLE=Move Waves
	
	String DS_Waves
	String MoveToFolder
	Variable RelativeFolder
	
	STRUCT ds ds
	GetStruct(ds)
	
	Variable i
	
	ds.wsi = 0
	
	Do
		String folderPath = MoveToFolder
		Wave theWave = ds.waves[ds.wsi]
		
		If(!WaveExists(theWave))
			continue
		EndIf
		
		String wavePath = GetWavesDataFolder(theWave,1)
		SetDataFolder $wavePath
		
		//finds on the full path to the folder if it's a relative path
		If(!stringmatch(folderPath,"root:*"))
			//only takes relative depth into account if it's a relative path
			If(RelativeFolder < 0)
				String relativePath = ParseFilePath(1,wavePath,":",1,abs(RelativeFolder) - 1) //takes relative depth path
			Else
				relativePath = ParseFilePath(2,wavePath,":",1,0) //takes entire path
			EndIf
			
			folderPath = RemoveEnding(relativePath + folderPath,":")
		EndIf
		
		//makes new data folder if it doesn't exist already
		i = 1
		Do
			String subPath = ParseFilePath(1,folderPath,":",0,i)
			If(!DataFolderExists(subPath))
				NewDataFolder $RemoveEnding(subPath,":")
			EndIf
			i+=1
		While(i < ItemsInList(folderPath,":"))
		
		If(!DataFolderExists(folderPath))
			NewDataFolder $RemoveEnding(folderPath,":")
		EndIf
		
		folderPath += ":" + NameOfWave(theWave)
		
		//kill existing wave in new location so it can be overwritten
		Wave/Z existingWave = $folderPath
		If(WaveExists(existingWave))
			ReallyKillWaves(existingWave)
		EndIf
		
		//move the wave to new location
		MoveWave theWave,$folderPath
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])

End

//Parses the command line entry string, and resolves any data set declarations, etc. to form
//a valid command line entry.
//Syntax:
//DataSet declaration: <DataSet>
//Specific wave set number/indes declaration: <DataSet>{wsn,wsi}

Function NT_RunCmdLine(Command,cb_Print)
	//TITLE=Run Command Line
	
//	Note={
//	Runs the command as if it were run from the command line prompt.
//	
//	\f01Syntax:\f00
//	<WM> : Uses waves defined in the wave match list box
//	<MyDataSetName> : Uses the waves defined by the data set MyDataSetName.
//	<wsi> : References the current wave set index of the data set.
//	<wsn> : References the current wave set number of the data set.
// 
// \f01print\f00 : prints the command to the command line after completion.
//	}
	
	String Command
	Variable cb_Print
	
	String Command_Pos="0;0;400;20"
	
	DFREF NPC = $CW
	String/G NPC:masterCmdLineStr
	SVAR masterCmdLineStr = NPC:masterCmdLineStr
	masterCmdLineStr = Command
	//If there are no appended commands, take directly from the entry box
//	If(!strlen(masterCmdLineStr))
//		Variable resetEntry = 1
//		ControlInfo/W=NTP cmdLineStr
//		masterCmdLineStr += S_Value + ";/;"
//	Else
		Variable resetEntry = 0
//	EndIf
	
	//Print result or not
	Variable doPrint = cb_Print
	
	Variable n,numMasterCommands
	numMasterCommands = ItemsInList(masterCmdLineStr,";/;")
	
	//LOOP THROUGH EACH COMMAND IN THE MASTER COMMAND LIST
	For(n=0;n<numMasterCommands;n+=1)
	
		//Make a temporary duplicate string to operate on, so the master isn't overwritten
		String tempStr = StringFromList(n,masterCmdLineStr,";/;")
		
		Variable pos1 = 0,pos2 = 0,j,numWaves
		String dsRefList = "",dsName = ""
		
		//Find the data set references in the command string
		Do
			pos1 = strsearch(tempStr,"<",0)
			pos2 = strsearch(tempStr,">",pos1)
			If(pos1 != -1 && pos2 != -1)
				dsName = tempStr[pos1+1,pos2-1]
				If(!cmpstr(dsName,"wsi"))
					tempStr = tempStr[pos2+1,strlen(tempStr)-1]
					continue
				EndIf
				dsRefList += dsName + ";"
				tempStr = tempStr[pos2+1,strlen(tempStr)-1]
			Else
				break
			EndIf
		While(pos1 != -1)
		
		Variable i
		If(ItemsInList(dsRefList,";") > 0)	//if there are data set references, otherwise continue
			Make/FREE/N=(ItemsInList(dsRefList,";")) wsDimSize //holds number of waves in each waveset
			
			For(i=1;i<ItemsInList(dsRefList,";");i+=1)
				String testDims = GetDataSetDims(StringFromList(i,dsRefList,";"))
				wsDimSize[i] = str2num(testDims)
			EndFor		
			
			dsName = StringFromList(0,dsRefList,";") //name of first data set found		
			
			If(!cmpstr(dsName,"WM"))
				Wave/T MatchLB_ListWave = NPC:MatchLB_ListWave
				Variable numWaveSets = GetNumWaveSets(MatchLB_ListWave)	//number wave sets
			ElseIf(!cmpstr(dsName,"Nav"))
				Wave/T NavigatorSelectionListWave = GetNavigatorWaveSelection()
				numWaveSets = GetNumWaveSets(NavigatorSelectionListWave)	//number wave sets
			Else
				numWaveSets = GetNumWaveSets(GetDataSetWave(dsName,"ORG"))	//number wave sets
			EndIf
		Else
			numWaveSets = 1
		EndIf
	
	
		//LOOP THROUGH EACH WAVE SET IN ANY IDENTIFIED DATA SETS
		For(i=0;i<numWaveSets;i+=1)
			
			//update the size of the wavesets for each wsn
			Variable k
			For(k=0;k<ItemsInList(dsRefList,";");k+=1)
				dsName = StringFromList(k,dsRefList,";")
				If(!cmpstr(dsName,"WM"))
					testDims = GetDataSetDims(StringFromList(k,dsRefList,";"),WM=1)
					wsDimSize[k] = str2num(StringFromList(i,testDims,";"))
				ElseIf(!cmpstr(dsName,"Nav"))
					testDims = GetDataSetDims(StringFromList(k,dsRefList,";"),Nav=1)
					wsDimSize[k] = str2num(StringFromList(i,testDims,";"))
				Else
					testDims = GetDataSetDims(StringFromList(k,dsRefList,";"))
					wsDimSize[k] = str2num(StringFromList(i,testDims,";"))
				EndIf
			EndFor
					
			If(strlen(dsName))
				If(!cmpstr(dsName,"WM"))
					String theWaveSet = GetWaveSetList(MatchLB_ListWave,i,1)
					numWaves = WaveMax(wsDimSize)
				Else
					theWaveSet = GetWaveSetList(GetDataSetWave(dsName,"ORG"),i,1)
					numWaves = WaveMax(wsDimSize)
				EndIf		
			Else
				theWaveSet = ""
				numWaves = 1
			EndIf
			
			For(j=0;j<numWaves;j+=1)
				String runCmdStr = resolveCmdLine(StringFromList(n,masterCmdLineStr,";/;"),i,j)
				
				//check if there is an output wave assignment, if so does it exist?
				String left,outWaveName,folder,firstWave
				Variable pos,semicolonPos,numCommands
				
				left = ""
				If(stringmatch(runCmdStr,"*=*"))
				   left = StringFromList(0,runCmdStr,"=")
				   //if the wave assignment is not the first command, there may be problems with other escape codes. Remove these first
				   Do	
				   	numCommands = ItemsInList(left,";/;")
					   left = StringFromlist(numCommands-1,left,";/;")
					   semicolonPos = strsearch(left,";/;",0)
					While(semicolonPos != -1)
				EndIf
				
				
				If(strlen(left) && !stringmatch(left,"*/*")) //makes sure that the equals sign is truly for a wave assignment, as opposed to a flag assignment
					pos = strsearch(left,"[",0)
					If(pos != -1)
						outWaveName = left[0,pos-1]
					Else
						pos = strsearch(left,"(",0) //checks if equals sign is from an optional parameter assignment, which would always have an open parentheses prior to it.
						If(pos != -1)
							outWaveName = "" //null string if it finds that this is an optional parameter declaration, not a wave assignment
						Else
							pos = strlen(left)
							outWaveName = left
						EndIf
					EndIf	
					
					//if its a full path, don't add a path to the name
					If(strlen(outWaveName) && !stringmatch(outWaveName,"root:*"))
					
						//Get the data folder of the wave in the waveset, but if no waveset is being referenced,
						//use the current data folder
						If(!strlen(theWaveSet))
							folder = GetDataFolder(1)
						Else
							firstWave = StringFromList(0,theWaveSet,";")
							folder = GetWavesDataFolder($firstWave,1)
						EndIf
						
					
						//full path to output wave
						outWaveName = folder + outWaveName
						
						//append full path to cmd string
						String editCommandStr = StringFromList(numCommands-1,runCmdStr,";/;") //get command string that contains the wave assignment
						editCommandStr[0,pos-1] = ""
						editCommandStr = outWaveName + editCommandStr
						
						runCmdStr = ReplaceListItem(numCommands-1,runCmdStr,";/;",editCommandStr)
	
					EndIf
					
					If(strlen(outWaveName) && !WaveExists($outWaveName))
						If(!strlen(theWaveSet))
							//Make the wave with default dimensioning if no wave set is referenced
							Make/O $outWaveName
						Else
							//doesn't exist, make it with correct dimensions
							//Use wave set dimensions for wave length if there is a waveset referenced
							Make/O/N=(numWaves) $outWaveName
						EndIf
//					ElseIf(strlen(outWaveName) && WaveExists($outWaveName) && strlen(theWaveSet))
//						//already exists, correct any incorrect dimensions
////						Redimension/N=(numWaves) $outWaveName
//						
//						Wave theFirstWave = $StringFromList(0,theWaveSet,";")
//						Redimension/N=(DimSize(theFirstWave,0)) $outWaveName
					EndIf 
	
				EndIf
			
				//Replace the separator with a single semi-colon
				runCmdStr = ReplaceString(";/;",runCmdStr,";")
				runCmdStr = RemoveEnding(runCmdStr,";")
				
				//Execute each command
				If(doPrint)
					print runCmdStr
				EndIf
				
				//Try to execute the command string, catch error
				try
					Execute runCmdStr;Variable error = GetRTError(1)
				catch			
					//Reset in case we had an empty master command entry, and took from the list box
					If(resetEntry)
						masterCmdLineStr = ""
					EndIf
				endtry
			EndFor
			
		EndFor
	EndFor
	
	//Reset in case we had an empty master command entry, and took from the list box
	If(resetEntry)
		masterCmdLineStr = ""
	EndIf
	
End
//
////Kills the waves
//Function NT_KillWaves(ds)
//	STRUCT ds &ds
//		
//	ds.wsi = 0
//	
//	Variable/G root:Packages:NT:totalSize
//	NVAR totalSize = root:Packages:NT:totalSize
//		
//	If(ds.wsn == 0)
//		totalSize = 0
//	EndIf
//	
//	Do
//		Wave theWave = ds.waves[ds.wsi]
//		String info = WaveInfo(theWave,0)
//		totalSize += str2num(StringByKey("SIZEINBYTES",info))
//		
//		ReallyKillWaves(theWave)
//		
//		ds.wsi += 1
//	While(ds.wsi < ds.numWaves[0])
//	
//	//print out the total size of the deleted waves after killing the waves.
//	//print on last wave set
//	If(ds.wsn == ds.numWaveSets[0]-1)
//		print "Deleted:", totalSize / (1e6),"MB"
//	EndIf
//End

//Makes new data folder of the specified name within the selected data folders
//Use the subfolder option to go deeper into the folder structure
Function NT_NewDataFolder(FolderName,RelativeFolder)
	//SUBMENU=Waves and Folders
	//TITLE=New Data Folder
	
	String FolderName,RelativeFolder
	
	DFREF NPC = $CW
	
	STRUCT filters filters
	
	//Must set this structure so we can use the relative folder option
	SetFilterStructure(filters,"")
	
	filters.relFolder = RelativeFolder
	
	Wave/T listWave = NPC:FolderLB_ListWave
	Wave selWave = NPC:FolderLB_SelWave
	
	//Gets all the matched folders from the relative folder term
	String folderList = GetFolderSearchList(filters,listWave,selWave)
	
	SVAR cdf = NPC:cdf
	
	Variable i
	
	//no selection, so must use current data folder
	If(!strlen(folderList))
	 folderList += RemoveEnding(cdf,":")
	EndIf
	
	For(i=0;i<ItemsInList(folderList,";");i+=1)
		String path = StringFromList(i,folderList,";") + ":" + FolderName
		CreateFolder(path)
	EndFor
	
	//update the folder and waves listbox
	updateFolders()
	updateFolderWaves()
End

//Kills the selected data folders
Function NT_KillDataFolder(FolderName,RelativeFolder)
	//SUBMENU=Waves and Folders
	//TITLE=Kill Data Folder
	
	String RelativeFolder,FolderName
	STRUCT filters filters
	
	DFREF NPC = $CW
	
	SetFilterStructure(filters,"")

	filters.relFolder = RelativeFolder

	Wave/T listWave = root:Packages:NT:FolderLB_ListWave
	Wave selWave = root:Packages:NT:FolderLB_SelWave
	
	//Gets all the matched folders from the relative folder term
	String folderList = GetFolderSearchList(filters,listWave,selWave)
	
	SVAR cdf = NPC:cdf
	
	//no selection, so must use current data folder
	If(!strlen(folderList))
	 folderList += RemoveEnding(cdf,":")
	EndIf
	
	
	Variable i
	For(i=0;i<ItemsInList(folderList,";");i+=1)
		String path = StringFromList(i,folderList,";") + ":" + FolderName
		KillDataFolder/Z $path
	EndFor
	
	SetDataFolder root:
	
	//update the folder and waves listbox
	updateFolders()
	updateFolderWaves()
End

//Special procedure function for the Measure command
Function measureProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	
	DFREF NPC = $CW
	Wave/T param = NPC:ExtFunc_Parameters
			
	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			
			Variable index = ExtFuncParamIndex(pa.ctrlName)
			setParam("PARAM_" + num2str(index) + "_VALUE","NT_Measure",popStr)
			
			If(strlen(popStr))	
				KillExtParams()
				setupMeasureControls(popStr)
			EndIf

			break		
		case -1: // control being killed
			break
	endswitch

	return 0
	
End

Function LoadEphysListBoxProc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave
	Variable errorCode = 0
	
	DFREF NPD = $DSF
	DFREF NPC = $CW
	
	Wave/T param = NPC:ExtFunc_Parameters
	
	DFREF saveDF = GetDataFolderDFR()
	Variable hookResult = 0
	
	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
			//show sweeps from the last cell selected only
			//browse files on disk for wavesurfer or pclamp loading
			Variable fileID
			
			SVAR wsFilePath = NPC:wsFilePath
			SVAR wsFileName = NPC:wsFileName
			
			If(row > DimSize(listWave,0) -1)
				return 0
			EndIf
			
			wsFileName = listWave[row]
			String fullPath = wsFilePath + wsFileName
			
			String fileType = getParam2("menu_FileType","VALUE","NT_LoadEphys")
			
			strswitch(fileType)
				case "WaveSurfer":
					HDF5OpenFile/R fileID as fullPath
			
					If(V_flag == -1) //cancelled
						break
					EndIf
					
					//Save the path and filename
					wsFilePath = S_path
					wsFileName = S_fileName
					
					UpdateWaveSurferLists(fileID,wsFilePath,wsFileName)
					
					GetStimulusData(fileID)

					HDF5CloseFile/A fileID
					break
				case "TurnTable":
					HDF5OpenFile/R fileID as fullPath
			
					If(V_flag == -1) //cancelled
						break
					EndIf
					
					//Save the path and filename
					wsFilePath = S_path
					wsFileName = S_fileName
					
					String seriesList = TT_GetSeriesList(fileID)
					String protList = TT_GetProtocolList(fileID)
//					String stimList = TT_GetStimList(fileID)
					
					Wave/T wsSweepListWave = $getParam2("lb_SweepList","LISTWAVE","NT_LoadEphys")
					Wave/T wsSweepSelWave = $getParam2("lb_SweepList","SELWAVE","NT_LoadEphys")
					
					Redimension/N=(ItemsInList(seriesList,";")) wsSweepListWave
					
					If(WaveExists(wsSweepSelWave))
						Redimension/N=(ItemsInList(seriesList,";")) wsSweepSelWave
					EndIf
					
					wsSweepListWave = StringFromList(p,seriesList,";") + "/" + StringFromList(p,protList,";")
					
					HDF5CloseFile/A fileID
					break
				case "PClamp":
//					Variable refnum
//					fullPath = RemoveEnding(fullPath,".abf") + ".abf"
//					Open/R/Z=2 refnum as fullPath
//
//					fSetPos refnum,12
//					
//					Variable numSweeps = 0					
//					FBInRead/B=3/F=3/U refnum,numSweeps
//					
//					Wave/T wsSweepListWave = NPC:wsSweepListWave
//					Redimension/N=(numSweeps) wsSweepListWave
//					
//					Variable i
//					For(i=0;i<numSweeps;i+=1)
//						wsSweepListWave[i] = "Sweep " + num2str(i + 1)
//					EndFor
//					
//					Close refnum
					break
				case "Presentinator":
					break
			endswitch
			
			break
	endswitch
	
	SetDataFolder saveDF
	
	return hookResult
End

Function LoadScanImageButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	DFREF NPC = $CW
	DFREF NTSI = $SI
	SVAR ScanLoadPath = NTSI:ScanLoadPath
	
	Wave/T param = NPC:ExtFunc_Parameters
	
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			//browse files on disk for wavesurfer loading
			
			//What file type are we opening?
			String fileType = getParam2("menu_FileType","VALUE","NT_LoadScanImage")
			
			ScanLoadPath = BrowseScanImage(fileType)
			
			break	
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function LoadScanImageListBoxProc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave
	Variable errorCode = 0
	
	DFREF NPD = $DSF
	DFREF NPC = $CW
	
	Wave/T param = NPC:ExtFunc_Parameters
	
	DFREF saveDF = GetDataFolderDFR()
	Variable hookResult = 0
	
	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
			//browse files on disk for scanimage data
			
			If(row > DimSize(listWave,0) -1)
				return 0
			EndIf
			
			
			break
	endswitch
End

//Makes visible the appropriate controls for each measurement type
Function/S setupMeasureControls(selection)
	String selection
	
	DFREF NPC = $CW
	DFREF NPD = $DSF
	
	Wave/T param = NPC:ExtFunc_Parameters
	
	//Start by killing all the parameters
	KillExtParams()
	
	//then display only parameters according to their control list names
	
	String visibleList = "DS_Waves;menu_Type;"
	
	strswitch(selection)
		case "Vector Sum":
			visibleList += "AngleWave;menu_ReturnType;"
			break
		case "Orientation Vector Sum":
			visibleList += "AngleWave;menu_OSReturnType;"
			break
		case "Peak":
			visibleList += "StartTime;EndTime;BaselineStart;BaselineEnd;cb_SubtractBaseline;Width;menu_SortOutput;"
			break
		case "Area":
			visibleList += "StartTime;EndTime;BaselineStart;BaselineEnd;cb_SubtractBaseline;menu_SortOutput;"
			break
		case "# Spikes":
			visibleList += "StartTime;EndTime;Threshold;menu_SortOutput;"
			break
		default:
			visibleList += "StartTime;EndTime;menu_SortOutput;"
			break	
	endswitch
	
	//Finds which column in the parameter wave the Measure function is located
	String theFunction = "NT_Measure"
	Variable col = FindDimLabel(param,1,theFunction)
	If(col == -1)
		return ""
	EndIf
	
	Variable left=60,top=70 //top left starting position of the controls
	Variable fontSize = 12
	
	//Make all the appropriate controls visible
	Variable i
	For(i=0;i<ItemsInList(visibleList,";");i+=1)
		String name = StringFromList(i,visibleList,";")
		
		//Gets the parameter's row inside the Measure function's parameter column
		Variable row = tableMatch(name,param,whichCol=col)
		If(row == -1)
			continue
		EndIf
		
		//Which control number is this?
		String controlLabel = GetDimLabel(param,0,row)
		String whichParam = StringFromList(1,controlLabel,"_")
		String ctrlName = "param" + whichParam
		String items = getParam("PARAM_" + whichParam + "_ITEMS",theFunction)
		String paramType = getParam("PARAM_" + whichParam + "_TYPE",theFunction)

		//Check if the control is a pop up menu or not
		Variable isMenu = 0
		
		If(stringmatch(name,"menu_*"))
			isMenu = 1
		Else
			isMenu = 0
		EndIf
		
		strswitch(paramType)
			case "4"://variable
				Variable valueNum = str2num(getParam("PARAM_" + whichParam + "_VALUE",theFunction))
				
				//CheckBox designation
				If(stringmatch(name,"cb_*"))		
					name = RemoveListItem(0,name,"_") //removes the "CB" prefix
					valueNum = (valueNum > 0) ? 1 : 0
					SetParam("PARAM_" + whichParam + "_VALUE",theFunction,num2str(valueNum))
					
					CheckBox/Z $ctrlName win=NTP#Func,pos={left+65,top},align=1,size={90,20},bodywidth=50,fsize=fontSize,font=$LIGHT,side=1,title=name,value=valueNum,disable=0,proc=ntExtParamCheckProc
				Else
					SetVariable/Z $ctrlName win=NTP#Func,pos={left+125,top-2},align=1,size={90,20},fsize=fontSize,font=$LIGHT,bodywidth=75,title=name,value=_NUM:valueNum,disable=0,proc=ntExtParamProc
					
					//Is there an assignment with this variable?
					String controlAssignment = getParam("PARAM_" + whichParam + "_ASSIGN",theFunction)
					
					If(strlen(controlAssignment))
						Button/Z $(ctrlname + "_assign") win=NTP#Func,pos={left+175,top-2},align=1,size={45,20},fsize=fontSize,font=$LIGHT,title="Get",disable=0,mode=1,proc=ControlAssignmentButtonProc
					EndIf
				EndIf
				
				break
			case "8192"://string
			
				//Popup menu designation
				If(isMenu)
					name = RemoveListItem(0,name,"_") //removes the "pop" prefix
					
					//Is this a literal string expression or a function call?
					If(stringmatch(items,"*(*") && stringmatch(items,"*)*"))
						String itemStr = items
					Else
						itemStr = "\"" + items + "\""	
					EndIf
					
					String valueStr = getParam("PARAM_" + whichParam + "_VALUE",theFunction)
					
					String theProc = getParam("PARAM_" + whichParam + "_PROC",theFunction)	 //special procedure reference
					If(!strlen(theProc))
						theProc = "ntExtParamPopProc"//default procedure
					EndIf
					PopUpMenu/Z $ctrlName win=NTP#Func,pos={left+200,top},align=1,size={185,20},fsize=fontSize,font=$LIGHT,bodywidth=150,title=name,value=#itemStr,disable=0,proc=$theProc	
					PopUpMenu/Z $ctrlName win=NTP#Func,popmatch=valueStr
					break
				Else
					valueStr = getParam("PARAM_" + whichParam + "_VALUE",theFunction)
				EndIf
				
				//test if the string is a data set reference, in which case make it a popup menu
				If(stringmatch(name,"DS_*"))		
					//Data Set Menu			
					SVAR DSNameList = NPD:DSNameList
					DSNameList = textWaveToStringList(NPD:DSNamesLB_ListWave,";")
					DSNameList = "**Wave Match**;" + DSNameList
					
					String dsSelection = getParam("PARAM_" + whichParam + "_VALUE",theFunction)
					If(!strlen(dsSelection))
						dsSelection = StringFromList(0,DSNameList,";") //will always at least have Wave Match as the first item
					EndIf
					
					Variable selectionIndex = WhichListItem(dsSelection,DSNameList,";")
					
//					PopUpMenu/Z $ctrlName win=NTP#Func,pos={left+200,top},align=1,size={185,20},fsize=fontSize,font=$LIGHT,bodywidth=150,title=StringFromList(1,name,"_"),value=GetDataSetNamesList(),disable=0,mode=1,popValue=dsSelection,proc=ntExtParamPopProc
					String spacedStr = getSpacer(dsSelection,18)
					Button/Z $ctrlname win=NTP#Func,pos={left+200,top},align=1,size={150,20},fsize=fontSize,font=$LIGHT,title=spacedStr,disable=0,mode=1,proc=DataSetButtonProc
					Button/Z $(ctrlname + "_show") win=NTP#Func,pos={left+250,top},align=1,size={45,20},fsize=fontSize,font=$LIGHT,title="Show",disable=0,mode=1,proc=DataSetButtonProc
					
					
					ControlInfo/W=NTP#Func $ctrlname
					
					//Text label for the data set input
					DrawAction/W=NTP#Func getGroup=$("DSNameLabel" + whichParam),delete
					SetDrawEnv/W=NTP#Func gname=$("DSNameLabel" + whichParam),gstart
					SetDrawEnv/W=NTP#Func xcoord= abs,ycoord= abs, fsize=fontSize, textxjust= 2,textyjust= 1,fname=$LIGHT //right aligned
					DrawText/W=NTP#Func V_left - 5,V_top + 10,StringFromList(1,name,"_") 
					SetDrawEnv/W=NTP#Func gname=$("DSNameLabel" + whichParam),gstop
				
				ElseIf(stringmatch(name,"CDF_*"))
					//Current Data Folder Waves Menu
					selection = getParam("PARAM_" + whichParam + "_VALUE",theFunction)
					selectionIndex = WhichListItem(selection,DSNameList,";")
					
					If(selectionIndex == -1)
						selectionIndex = 0
					EndIf
					
					PopUpMenu/Z $ctrlName win=NTP#Func,pos={left,top},size={185,20},font=$LIGHT,fsize=fontSize,bodywidth=150,title=StringFromList(1,name,"_"),value=WaveList("*",";",""),disable=0,mode=1,popValue=selection,proc=ntExtParamPopProc
				Else
					SetVariable/Z $ctrlName win=NTP#Func,pos={left+200,top},align=1,size={190,20},fsize=fontSize,font=$LIGHT,bodywidth=150,title=name,value=_STR:valueStr,disable=0,proc=ntExtParamProc
				EndIf
				
				break
			case "16386"://wave
				valueStr = getParam("PARAM_" + whichParam + "_VALUE",theFunction)
				//this will convert a wave path to a wave reference pointer
				SetVariable/Z $ctrlName win=NTP#Func,pos={left,top},size={140,20},fsize=fontSize,font=$LIGHT,bodywidth=100,title=name,value=_STR:valueStr,disable=0,proc=ntExtParamProc
				
				//confirm validity of the wave reference
				validWaveText("",0,deleteText=1)
				ControlInfo/W=NTP#Func $ctrlName
				validWaveText(valueStr,V_top+13)
				
				break
			case "4608"://structure
				top -= 25 //reset back				
				break
		endswitch
		top += 25
		
	EndFor
	
	
End

//Special button trigger function for the Load Ephys command to browse files
Function LoadEphysButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	DFREF NPD = $DSF
	DFREF NPC = $CW
	Wave/T param = NPC:ExtFunc_Parameters
	SVAR currentFunc = NPC:currentFunc
	
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			
			//Get the name of the parameter
			ControlInfo/W=NTP#Func $ba.ctrlName
			String ctrlName = S_Title
			
			strswitch(ctrlName)
				case "BrowseFiles":
					//browse files on disk for wavesurfer loading
				
					//What file type are we opening?
					String fileType = getParam2("menu_FileType","VALUE","NT_LoadEphys")
					
					BrowseEphys(fileType)
					break
				case "Open":
					
					String archiveSelection = GetParam2("menu_DataTable","VALUE",currentFunc)
					Wave/T archive = NPD:$("DS_" + archiveSelection + "_archive")
					
					If(WaveExists(archive))
						openArchive(archiveSelection)
					EndIf
					
					break
			endswitch
			
			break	
		case -1: // control being killed
			break
	endswitch

	return 0
End

//Fills the channels row of a data table with that data files channel information
Function NT_GetDataTableChannels(menu_DataTable,menu_Rows,StartRow,EndRow,bt_Open)
	//TITLE=Get Channel Info
	//SUBMENU=Load Data
	String menu_DataTable
	String menu_Rows
	Variable StartRow,EndRow
	String bt_Open
	
	String menu_DataTable_List = GetDataArchives("load")
	String menu_Rows_List = "All;StartRow to EndRow;"
	String bt_Open_Pos = "105;68;40;20"
	String bt_Open_Proc = "LoadEphysButtonProc"
	
	DFREF NPD = $DSF
	
	//Get the selected table wave
	String archiveName = "DS_" + menu_DataTable + "_archive"
	Wave/T archive = NPD:$archiveName
	
	If(!WaveExists(archive))
		return 0
	EndIf
	
	//Get the list of files from the table
	strswitch(menu_Rows)
		case "All":
			StartRow = 0
			EndRow = DimSize(archive,0) - 1
			break
		case "StartRow to EndRow":
			//Start and End Rows are already defined
			break
	endswitch
	
	Variable pathCol = FindDimLabel(archive,1,"Path")
	String filePathList = TextWaveToStringList(archive,";",col=pathCol)
	filePathList = ReplaceString("/",filePathList,":") //replace / to : for paths
	
	//Make sure start and end rows are within valid range
	StartRow = (StartRow < 0) ? 0 : StartRow
	StartRow = (StartRow > ItemsInList(filePathList,";") - 1) ? 0 : StartRow
	
	EndRow = (EndRow < StartRow || EndRow == StartRow) ? StartRow : EndRow
	EndRow = (EndRow > ItemsInList(filePathList,";") - 1) ? ItemsInList(filePathList,";") - 1 : EndRow
	
	Variable col = FindDimLabel(archive,1,"Channels")
	
	If(col == -1)
		return 0
	EndIf
	
	//Get the channels in each wavesurfer file
	Variable i
	For(i=StartRow;i<EndRow + 1;i+=1)
		String theFile = StringFromList(i,filePathList,";")
		
		If(stringmatch(theFile,"*.h5"))
			String channels = RemoveEnding(GetWavesurferChannels(theFile),",")
		
			archive[i][col] = channels
		EndIf
		
	EndFor
	
End

Function NT_LoadEphysTable(menu_DataTable,menu_Rows,StartRow,EndRow,bt_Open)
	//TITLE=Load From Data Table
	//SUBMENU=Load Data
	String menu_DataTable
//	String menu_Channels
	String menu_Rows
	Variable StartRow,EndRow
	String bt_Open

	String menu_DataTable_List = GetDataArchives("load")
//	String menu_Channels_List = "All;1;2;3;4;"
	String menu_Rows_List = "All;StartRow to EndRow;"
	String bt_Open_Pos = "105;68;40;20"
	String bt_Open_Proc = "LoadEphysButtonProc"
	
//	Note = {
//	Loads Ephys data using the file paths and channels supplied in a Data Table.
//	New Data Tables can be created from the NeuroTools+ menu in 'Data Sets'.

//	Once loaded, the new data will automatically be defined as a data set.
//	The data table can be added to and deleted from, which will modify the waves
// included in the data set. 
//	
//	\f01Rows\f00 : All rows in the table will be loaded, or a range of rows
//	\f01StartRow\f00 : First row to be loaded if not loading 'All' data.
//	\f01EndRow\f00 : Last row to be loaded if not loading 'All' data.
//	}
	
	
	DFREF NPD = $DSF
	
	//Keeps track of the data table position
	NVAR dti = NPD:dataTableIndex
	dti = 0
	
	//Get the selected table wave
	String archiveName = "DS_" + menu_DataTable + "_archive"
	Wave/T archive = NPD:$archiveName
	
	If(!WaveExists(archive))
		return 0
	EndIf
	
	//Get the list of files from the table
	strswitch(menu_Rows)
		case "All":
			StartRow = 0
			EndRow = DimSize(archive,0) - 1
			break
		case "StartRow to EndRow":
			//Start and End Rows are already defined
			break
		default:
			Abort "Re-initialize the function, didn't acquire the row selection"
			break
	endswitch
	
	Variable fileCol = FindDimLabel(archive,1,"Path")
	Variable fileTypeCol = FindDimLabel(archive,1,"Type")
	
	If(fileCol == -2 || fileTypeCol == -2)
		Abort "Couldn't find the 'Path' or 'Type' column in the data table."
	EndIf
	
	String filePathList = TextWaveToStringList(archive,";",col=fileCol)
	filePathList = ReplaceString("/",filePathList,":") //replace / to : for paths
	
	//Make sure start and end rows are within valid range
	StartRow = (StartRow < 0) ? 0 : StartRow
	StartRow = (StartRow > ItemsInList(filePathList,";") - 1) ? 0 : StartRow
	
	EndRow = (EndRow < StartRow || EndRow == StartRow) ? StartRow : EndRow
	EndRow = (EndRow > ItemsInList(filePathList,";") - 1) ? ItemsInList(filePathList,";") - 1 : EndRow
	
	String masterFilePathList = ""
	String channelList = ""
	Variable channelCol = FindDimLabel(archive,1,"Channels")
	
	If(channelCol == -1)
		Abort "Couldn't find 'Channels' column in the data table"
	EndIf
	
	For(dti=StartRow;dti<EndRow + 1;dti+=1)	
		String fileType = 	archive[dti][fileTypeCol]
		
		strswitch(fileType)
			case "pclamp":
			case ".abf":
			case ".abf2":
			case "abf":
			case "abf2":
				//PClamp file
				//these aren't packed files, so each sweep is its own file. The File path column should hold the folder base name without the
				//trace numbers. All traces will be loaded unless indicated in one of the Pos_ columns
				String theFile = archive[dti][fileCol]
				
				theFile = GetABFTrialList(theFile,archive,dti)
				
				//For each Trials entry, if multiple trials are defined, they all must have the same number of traces. Check this here
				Variable numTraces = CheckABFTraceCounts(theFile)
				
				If(!numTraces) //not all equal if zero
					Abort "All trials must have the same number of traces if defined on the same data table line."
				EndIf
				
				//Fill the trace counts into the correct data table lines
				Variable traceCol = FindDimLabel(archive,1,"Traces")
				
				archive[dti][traceCol] = "1-" + num2str(numTraces)
				
				channelList = archive[dti][channelCol]
				
				If(!strlen(channelList))
					channelList = "All"
				EndIf
				
				LoadPClamp(theFile,channels=channelList,table=menu_DataTable) //list of pclamp file paths depending on the sweeps
				break
			case "wavesurfer":
			case ".h5":
			case "h5":
			case "hdf5":
			case "hdf":
				//wavesurfer file
				//these are packed files, so each one contains series of traces. Auto loads all traces unless indicated in one
				//of the Pos_ columns
				theFile = archive[dti][fileCol]
				
				//		String theFile = StringFromList(dti,filePathList,";")
				channelList = archive[dti][channelCol]
				
				//Load the files one at a time so we can increment the data table index
				Load_WaveSurfer(theFile,channels=channelList,table=menu_DataTable)
				break
		endswitch
	EndFor
	
//	//Load the files
//	Load_WaveSurfer(masterFilePathList,channels=channelList,table=menu_DataTable)
	
End

//Checks that all the ABF2 files in the list have the same numner of traces in them
Function CheckABFTraceCounts(fileList)
	String fileList
	
	Variable i,numFiles = ItemsInList(fileList,";")
	Variable refNum
	
	For(i=0;i<numFiles;i+=1)
		String path = StringFromList(i,fileList,";")
		
		Open/R/Z refNum as path
		
		If(V_flag)
			continue
		EndIf
		
		fSetPos refnum,12
		Variable tempVar
		
		FBInRead/B=3/F=3/U refnum,tempVar
		Close refnum
		
		If(i == 0)
			Variable numTraces = tempVar
		Else
			If(tempVar != numTraces)
				return 0
			EndIf
		EndIf	
	EndFor
	
	return numTraces //all files have same number of traces, and this is the number
End

//Takes a file path for an abf2 (pclamp) file (truncated without the trace numbers or extension) and adds the trial/sweep numbers
//into a list
Function/S GetABFTrialList(theFile,table,dti)
	String theFile
	Wave/T table //archive data set
	Variable dti //data table index - what row are we trying to use in the data table?
	
	String fileList = ""
	Variable i,trialCol = FindDimLabel(table,1,"Trials")
	
	If(trialCol == -2)
		return ""
	EndIf
	
	//Gets any traces that are specified, otherwise loads all of them.
	String trialList = table[dti][trialCol]
	trialList = ResolveListItems(trialList,";")
	
	//If nothing is defined in the trial list, return empty string
	If(!strlen(trialList))
		DoAlert/T="Load PClamp Error:" 0, "Must define the trials #s being to be loaded from the data table for table index: " + num2str(dti)
		return ""
	EndIf
	
	For(i=0;i<ItemsInList(trialList,";");i+=1)
		String theTrial = StringFromList(i,trialList,";")
		
		Variable trialNum = str2num(theTrial)
		
		If(numtype(trialNum) == 2)
			continue
		EndIf
		
		//abf trace numbers are zero buffered
		If(trialNum < 10)
			theTrial = "000" + theTrial
		ElseIf(trialNum < 100)
			theTrial = "00" + theTrial
		ElseIf(trialNum < 1000)
			theTrial = "0" + theTrial
		EndIf
		
		String path = theFile + "_" + theTrial + ".abf"
		
		//check that the file path is valid, otherwise don't include in the list
		Variable refNum
		Open/R/Z refNum as path
		
		If(V_flag)
			continue
		EndIf
		
		Close refNum
		
		fileList += theFile + "_" + theTrial + ".abf" + ";"
	EndFor
	
	return fileList
End

Function NT_LoadEphys(menu_FileType,bt_BrowseFiles,menu_Channels,lb_FileList,lb_SweepList,menu_NameByStimulus)
	//TITLE=Load Ephys
	//SUBMENU=Load Data
	
//	Note={
//	Loads different types of electrophysiology data. Choose the file type from the menu, 
//	browse to the folder that contains the data. Select and load.  
//	}
	
	String menu_FileType,bt_BrowseFiles,menu_Channels,lb_FileList,lb_SweepList,menu_NameByStimulus
	
	String menu_FileType_List = "WaveSurfer;PClamp;TurnTable;Presentinator;"
	String bt_BrowseFiles_Proc = "LoadEphysButtonProc"
	
	String menu_Channels_List = "1;2;All;"
	
	String lb_FileList_Pos = "-20;10;200;350" //left,top,width,height
	String lb_FileList_ListWave = "root:Packages:NeuroToolsPlus:ControlWaves:wsFileListWave"
	String lb_FileList_SelWave = "root:Packages:NeuroToolsPlus:ControlWaves:wsFileSelWave"
	String lb_FileList_Proc = "LoadEphysListBoxProc"
	
	String lb_SweepList_Pos = "190;10;200;350"
	String lb_SweepList_ListWave = "root:Packages:NeuroToolsPlus:ControlWaves:sweepListWave"
	String lb_SweepList_SelWave = "root:Packages:NeuroToolsPlus:ControlWaves:sweepSelWave"
	
	String menu_NameByStimulus_List = "None;angle;speed;driftFreq;trajectory;diameter;length;width;orientation;spatialFreq;spatialPhase;modulationFreq;contrast;xPos;yPos;"
	String menu_NameByStimulus_Pos = "80;530;"
	
	DFREF NPC = $CW
	SVAR wsFilePath = NPC:wsFilePath
	SVAR wsFileName = NPC:wsFileName
	
	
	Wave/T wsFileListWave = NPC:wsFileListWave
	Wave wsFileSelWave = NPC:wsFileSelWave
	
	Wave/T sweepListWave = NPC:sweepListWave
	Wave/Z sweepSelWave = NPC:sweepSelWave
	
	
	Variable i
	String filePathList = ""

	//Get the selected files
	For(i=0;i<DimSize(wsFileListWave,0);i+=1)
		If(wsFileSelWave[i] > 0)
			filePathList += wsFilePath + wsFileListWave[i] + ";"
		EndIf
	EndFor
	
	//no selection, load all of them
	If(sum(wsFileSelWave) == 0)
		filePathList = ""
		For(i=0;i<DimSize(wsFileListWave,0);i+=1)
			filePathList += wsFilePath + wsFileListWave[i] + ";"
		EndFor
	EndIf

	NewPath/O/Q/Z filePath,wsFilePath
	
	strswitch(menu_FileType)
		case "PClamp":
			NT_LoadPClamp(filePathList,channels=menu_Channels)
			break
		case "WaveSurfer":
			Load_WaveSurfer(filePathList,channels=menu_Channels,NameByStimulus=menu_NameByStimulus)
			break
		case "Presentinator":
			LoadPresentinator(filePathList)
			break
		case "TurnTable":
			//Get the selected series
			String seriesList = ""
			For(i=0;i<DimSize(sweepListWave,0);i+=1)
				If(sweepSelWave[i] > 0)
					seriesList += StringFromList(0,sweepListWave[i],"/") + ";"
				EndIf
			EndFor
			
			//no selection, load all of them
			If(sum(sweepSelWave) == 0)
				seriesList = ""
				For(i=0;i<DimSize(sweepListWave,0);i+=1)
					seriesList += StringFromList(0,sweepListWave[i],"/") + ";"
				EndFor
			EndIf
			
			LoadTurnTable(filePathList,seriesList)
			break
	endswitch
	
End

Function LoadTurnTable(filePathList,seriesList)
	String filePathList,seriesList
	
	DFREF saveDF = GetDataFolderDFR()
	
	Variable i,j,fileID,numSeries = ItemsInList(seriesList,";")
	
	String file = StringFromList(0,filePathList,";")
	
	//Open the file
	HDF5OpenFile/R fileID as file
			
	If(V_flag == -1) //cancelled
		return 0
	EndIf

	//Ensure folders exist for loading data into
	If(!DataFolderExists("root:Ephys"))
		NewDataFolder root:Ephys
	EndIf
	
	//Ensure valid subfolder name
	String subfolder = S_fileName
	subfolder = RemoveEnding(S_fileName,".h5")
	subfolder = ReplaceString(" ",subfolder,"_")
	subfolder = ReplaceString("-",subfolder,"_")
	
	If(isnum(subfolder[0]))
		subfolder = "Cell_" + subfolder
	EndIf
	
	String destFolder = "root:Ephys:" + subfolder
	
	If(!DataFolderExists(destFolder))
		NewDataFolder $destFolder
	EndIf
	
	SetDataFolder $destFolder
	
	//load each channel in the selected series
	For(i=0;i<numSeries;i+=1)
		String series = StringFromList(i,seriesList,";")
		String sweepList = TT_GetSweepList(fileID,series)
		String unitsList = TT_GetSeriesUnits(fileID,series)
		String scaleList = TT_GetSeriesScale(fileID,series)
		
		Variable nSweeps = ItemsInList(sweepList,";")
		For(j=0;j<nSweeps;j+=1)
			String sweep = StringFromList(j,sweepList,";")
			String unit = StringFromList(j,unitsList,";")
			String scale = StringFromList(j,scaleList,";")
			
			strswitch(unit)
				case "V":
					//Current clamp
					String prefix = "Vm"
					break
				case "A":
					//Voltage clamp
					prefix = "Im"
					break
			endswitch
			
			String dataName = prefix + "_1_" + series + "_" + sweep + "_1"
			
			HDF5LoadData/O/TYPE=2/Q/N=$dataName fileID,"/Data/" + series + "/Ch1/" + sweep
			Wave d = $dataName
			
			//Scale the data
			SetScale/P x,0,str2num(scale),"s",d
			SetScale/P y,0,1,unit,d
		EndFor
		
	EndFor
	
	HDF5CloseFile fileID
	
	SetDataFolder saveDF
End

Function LoadPClamp(filePathList,[channels,table])
	String filePathList,channels,table

	If(!strlen(filePathList))
		return 0
	EndIf
	
	If(ParamIsDefault(channels))
		channels = "All"
	EndIf
	
	If(ParamIsDefault(table))
		table = ""
	EndIf
	
	Variable i
	For(i=0;i<ItemsInList(filePathList,";");i+=1)
		String theFile = RemoveEnding(StringFromList(i,filePathList,";"),".abf") + ".abf"
		ABFLoader(theFile,channels,1,table=table,fileIndex=i)
	EndFor
	
	//clean up
	KillDataFolder/Z root:Packages:NeuroToolsPlus:ABFvar
End

//Returns a string list of the channels in a given wavesurfer .h5 file
Function/S GetWavesurferChannels(theFile)
	String theFile
	
	//Reformat the path for colons
	String path = ReplaceString("/",theFile,":")
	
	//Clean up leading colons
	If(!cmpstr(path[0],":"))
		path = path[1,strlen(path)-1]
	EndIf
		

	//Get the file name
	String fileName = ParseFilePath(0,theFile,":",1,0)
	
	//Get the folder path
	String folderPath = ParseFilePath(1,theFile,":",1,0)
	
	//Set the path
	NewPath/O wsPath,folderPath

	//Open the HDF5 file read only
	Variable fileID
	HDF5OpenFile/P=wsPath/Z/R fileID as fileName

	If(V_flag)
		Abort "Couldn't load the file: " + path
	EndIf
	
	//Get the channel names in the file
	HDF5LoadData/N=ch/Q fileID,"/header/AIChannelNames"
	
	Wave/T ch = :ch
	
	String channelStr = TextWaveToStringList(ch,",")
	
	KillWaves/Z ch
	
	return channelStr
End

//Loads and scales sweeps loaded from an HDF5 file made by WaveSurfer electrophysiology software
Function Load_WaveSurfer(String fileList[,String channels,String NameByStimulus,String table])
		
	DFREF NPD = $DSF
	NVAR dti = NPD:dataTableIndex
	
	If(ParamIsDefault(channels))
		channels = "All"
	EndIf
	
	If(ParamIsDefault(NameByStimulus))
		NameByStimulus = "None"
	EndIf
	
	If(ParamIsDefault(table))
		table = ""
	EndIf
		
	//Reformat the path for colons
	String path = ReplaceString("/",fileList,":")
	
	//Clean up leading colons
	If(!cmpstr(path[0],":"))
		path = path[1,strlen(path)-1]
	EndIf
	
	Variable k,m,n
	For(k=0;k<ItemsInList(fileList,";");k+=1)
		String theFile = StringFromList(k,fileList,";")
		
		//Get the file name
		String fileName = ParseFilePath(0,theFile,":",1,0)
		
		//Get the folder path
		String folderPath = ParseFilePath(1,theFile,":",1,0)
		
		//Set the path
		NewPath/O wsPath,folderPath

		//Open the HDF5 file read only
		Variable fileID
		HDF5OpenFile/P=wsPath/Z/R fileID as fileName

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
		
		//Check if the parent folder starts with a number or character (Igor requires a character)
		String lastFolder = ParseFilePath(0,folder,":",1,0)
		String firstChar = lastFolder[0]
		Variable numCheck = str2num(firstChar)
		
		If(numtype(numCheck) != 2)
			lastFolder = "Cell_" + lastFolder
			folder = ReplaceListItem(ItemsInList(folder,":")-1,folder,":",lastFolder)
		EndIf
		
		If(!DataFolderExists(folder))
			NewDataFolder $folder
		EndIf
		
		//Get the stimulus data, if available
		Wave/T stimData = GetStimulusData(fileID)
		
		//Resolve the NameByStimulus selection
		String stimList = ResolveStimulusNaming(fileID,stimData,NameByStimulus)
		
		String channelList = StringFromList(k,channels,";")
		
		//Resolve the channel selection
		If(strlen(table))
			Wave/T dataTable = NPD:$("DS_" + table + "_archive")
			
			If(!WaveExists(dataTable))
				return 0
			EndIf
			
			//clear the name information from the current data table index
//			dataTable[dti][0,9] = ""
			
			//Is there any input into the channel list? If not, get the channel data
			If(!strlen(channelList))
				//which table row are we on?
				
				channelList = TextWaveToStringList(ch,",",noEnding=1)
				
				dataTable[dti][FindDimLabel(dataTable,1,"Channels")] = channelList
				 
			Else
				//Make the channel string into a list, in case its a range
				channelList = resolveListItems(channelList,",",noEnding=1)
				
				//make sure the channel selection is either a valid match for the channels, or is numeric index for the channels
				For(m=0;m<ItemsInList(channelList,",");m+=1)
					String chStr = StringFromList(m,channelList,",")
					
					//no valid match, check for numeric index
					If(tableMatch(chStr,ch) == -1)
						Variable chNum = str2num(chStr)
						
						//valid number
						If(numtype(chNum) != 2)
							//does the channel num within range of number of channels?

							If(chNum <= DimSize(ch,0))
								chNum -= 1 //zero offset compensation
								
								//replace number with the actual channel name
								channelList = ReplaceListItem(m,channelList,",",ch[chNum],noEnding=1)
							EndIf
							
						EndIf
					EndIf
				EndFor
			
			EndIf
		EndIf
		
		SetDataFolder $folder
		
		//If we're loading from a data table, add folder to the Igor Path section of the table
		If(strlen(table))
			Variable igorPathIndex = FindDimLabel(dataTable,1,"IgorPath")
			If(igorPathIndex != -1)
				dataTable[dti][igorPathIndex] = RemoveEnding(folder,":") + ":"
			EndIf
		EndIf
		
		
		//Load the sweeps into waves
		Make/Wave/FREE/N=0 sweepRefs
		
		Variable extraCount = 1 //for stimulus naming conventions
		
		For(i=0;i<numSweeps;i+=1)
			String dataSet = StringFromList(i,S_HDF5ListGroup,";") + "/analogScans"
			String name = UniqueName("analogScans",1,0)
			HDF5LoadData/N=$name/Q fileID,dataSet
			
			//Declare the loaded wave
			Wave data = $StringFromList(0,S_WaveNames,";")
			
			//Make sure its a single float, so it can handle the scaling
			Redimension/S data
			
			//Get the sweep index, truncate zeros
			String theSweep = StringFromList(1,StringFromList(i,S_HDF5ListGroup,";"),"_")
			
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
			Variable channelCount = 0
			
			For(j=0;j<DimSize(data,0);j+=1)
				
				String theUnit = unit[j]
				String prefix = ""
				
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
						mult = 1 //either V or A without prefix
				endswitch
				
				String unitBase = theUnit[1]
				
				If(!strlen(unitBase))
					unitBase = theUnit[0]
				EndIf
				
				strswitch(unitBase)
					case "A":
						//current
						prefix = "Im"
						break
					case "V":
						//voltage
						prefix = "Vm"
						break
				endswitch
							
				//////////////
				
				If(strlen(table))	
					If(WhichListItem(ch[j],channelList,",") != -1)
						Variable load = 1
					Else
						load = 0
					EndIf
					
					//Check if the prefix is already defined by the data table
					Make/T/FREE/N=5 entryWave = ""
					
					String entry = dataTable[dti][0]
					If(strlen(entry))
						entryWave[0] = StringFromList(channelCount,entry,",")
					Else
						entryWave[0] = prefix
					EndIf

					For(n=1;n<5;n+=1)
						entry = dataTable[dti][n]
						entry = ResolveListItems(entry,",",noEnding=1)
						If(strlen(entry))
							If(ItemsInList(entry,",") > 1)
								entryWave[n] = StringFromList(i,entry,",") //increment by sweep
							Else
								entryWave[n] = entry
							EndIf
						Else
							//No pre-made entry, fill with names generated from the data file
							If(n == 2)
								//this is the sweep column for auto-naming
								entryWave[n] = num2str(i + 1) //sweep number
							Else
								entryWave[n] = "1"
							EndIf
						EndIf
					EndFor
				Else
					If(!cmpstr(ch[j],channels) || !cmpstr(channels,"All") || str2num(channels) - 1 == j)	
						load = 1
					Else
						load = 0
					EndIf
				EndIf
				
				If(load)
					Multithread data[j][] = ( (data[j][q] / scale[j]) * coef[j][1] + (coef[j][0] / scale[j]) ) * mult
					
					//Split the channels - puts wave into a folder that is the immediate subfolder
					//of the file.
					Variable numStimListNames = ItemsInList(stimList,";")
					
					If(numStimListNames == 0)
						//Resolve the final wave name, depends on if loading from data table or not.
						If(strlen(table))
							String channelName = TextWaveToStringList(entryWave,"_",noEnding=1)
						Else
							channelName = prefix + "_1_" + theSweep + "_1_1" // + num2str(j + 1)
						EndIf
							
						//Add this name to the data table, if its loading from one
						If(strlen(table))
							
							dataTable[dti][FindDimLabel(dataTable,1,"Comment")] = protocol
							
							If(!strlen(dataTable[dti][2]))
								If(i == 0 && channelCount == 0)
									dataTable[dti][2] = ""
									dataTable[dti][2] += theSweep
								ElseIf(channelCount == 0)
									dataTable[dti][2] += "," + theSweep  //position 2 - this is a potential list, if there are more than one sweep being loaded from the file
								EndIf
							EndIf
							
							If(!strlen(dataTable[dti][1]))						
								dataTable[dti][1] = "1" //position 1
							EndIf
							
							If(!strlen(dataTable[dti][3]))					
								dataTable[dti][3] = "1" //position 3
							EndIf
							
							If(!strlen(dataTable[dti][4]))				
								dataTable[dti][4] = "1" //position 4
							EndIf
							
							If(!strlen(dataTable[dti][0]))
								If(channelCount == 0 && i == 0)
									dataTable[dti][0] = "" //position 0
									dataTable[dti][0] = prefix
									
	//								dataTable[dti][4] = "" //position 4
	//								dataTable[dti][4] += num2str(j + 1)
								ElseIf(i == 0)
									dataTable[dti][0] += "," + prefix
	//								dataTable[dti][4] += "," + num2str(j + 1) //position 4 - channels, potential list
								EndIf
							EndIf
							
						EndIf
			
					Else
						If(i > numStimListNames - 1)
							//If there are more sweeps than stim list names, just name it with the last stimulus name and increment the next underscore position as the sweep number
							channelName = prefix + "_1_" + theSweep + "_" + StringFromList(numStimListNames - 1,stimList,";") + "_1" //+ num2str(j + 1)
							
							//Add this name to the data table, if its loading from one
							If(strlen(table))
								dataTable[dti][FindDimLabel(dataTable,1,"Comment")] = protocol
								
								If(i == 0 && channelCount == 0)
									dataTable[dti][2] = ""
									dataTable[dti][2] += theSweep
								ElseIf(channelCount == 0) //do on first channel only, to avoid repeating the list for each channel
									dataTable[dti][2] += "," + theSweep  //position 1 - this is a potential list, if there are more than one sweep being loaded from the file
								EndIf
								
								dataTable[dti][1] = StringFromList(numStimListNames - 1,stimList,";")//position 2
								dataTable[dti][3] = "1" //position 3
								dataTable[dti][4] = "1" //position 4
								
								If(channelCount == 0 && i == 0)
									dataTable[dti][0] = "" //position 0
									dataTable[dti][0] = prefix
								
//									dataTable[dti][4] = ""
//									dataTable[dti][4] += num2str(j + 1)
								ElseIf(i == 0)
									dataTable[dti][0] += "," + prefix
//									dataTable[dti][4] += "," + num2str(j + 1) //position 4 - channels, potential list
								EndIf
							EndIf
						Else
							channelName = prefix + "_1_" + theSweep + "_" + StringFromList(i,stimList,";") + "_1" //+ num2str(j + 1)
							
							//Add this name to the data table, if its loading from one
							If(strlen(table))
								dataTable[dti][0] = prefix //position 0
								dataTable[dti][FindDimLabel(dataTable,1,"Comment")] = protocol
								
								If(i == 0 && channelCount == 0)
									dataTable[dti][2] = ""
									dataTable[dti][2] += theSweep
								ElseIf(channelCount == 0)
									dataTable[dti][2] += "," + theSweep  //position 1 - this is a potential list, if there are more than one sweep being loaded from the file
								EndIf
								
								dataTable[dti][1] = StringFromList(i,stimList,";")//position 2
								dataTable[dti][3] = "1" //position 3
								dataTable[dti][4] = "1" //position 4
								
								If(channelCount == 0 && i == 0)
									dataTable[dti][0] = "" //position 0
									dataTable[dti][0] = prefix
									
//									dataTable[dti][4] = ""
//									dataTable[dti][4] += num2str(j + 1)
								ElseIf(i == 0)
									dataTable[dti][0] += "," + prefix
									
//									dataTable[dti][4] += "," + num2str(j + 1) //position 4 - channels, potential list
								EndIf
							EndIf
						EndIf

					EndIf
					
					
					Make/O/N=(DimSize(data,1))/S $channelName
					Wave channel = $channelName
					
					Multithread channel = data[j][p]
					SetScale/P x,0,1/rate[0],"s",channel
					SetScale/P y,0,1,unitBase,channel
					
					//Set the wave note
					Note/K channel,"Path: " + StringFromList(k,path,";")
					Note channel,"Protocol: " + protocol
					
					//Set the stimulus data note, extracting any sequences
					If(DimSize(stimData,0) > 0)
						For(m=0;m<DimSize(stimData,0);m+=1)
							String line = stimData[m][1]
							If(ItemsInList(line,";") > 1)
								Note channel,stimData[m][0] + ": " + StringFromList(i,line,";")
							Else
								Note channel,stimData[m][0] + ": " + line
							EndIf	
						EndFor
					EndIf
				
					channelCount += 1 //increment channel count as they are loaded
				EndIf 
				
			EndFor
			
			KillWaves/Z data
		EndFor
		
		//Ensure no repetitions in the prefix name list
		If(strlen(table))
			dataTable[dti][0] = RemoveDuplicateList(dataTable[dti][0],",")
		EndIf
		
		//Cleanup
		KillWaves/Z coef,scale,unit,rate,ch,prot
		
		//Close file
		HDF5CloseFile/A fileID
	EndFor
	
	//refresh the folder and wave list boxes
	getFolders()
	getFolderWaves()
End

Function/S ResolveStimulusNaming(fileID,stimData,NameByStimulus)
	Variable fileID
	Wave/T stimData
	String NameByStimulus
	
	
	String stimList = ""
	
	strswitch(NameByStimulus)
		case "None":
			return ""
			break
		case "trajectory":
			String trajName = GetAttribute(fileID,0,NameByStimulus)
			
			If(!strlen(trajName))
				return ""
			EndIf
			
			//What's in the trajectory?
			String trajectoryDefinition = GetTrajectory(trajName,fileID)
			
			If(!strlen(trajectoryDefinition))
				return ""
			EndIf
			
			String trajAngles = StringByKey("Angle",trajectoryDefinition,":","//")
			
			If(!strlen(trajAngles))
				return ""
			EndIf
			
			Variable i,j
			
			Make/T/N=(ItemsInList(trajAngles,","))/FREE trajectorySegments //keeps track of each segment
			
			For(i=0;i<ItemsInList(trajAngles,",");i+=1)
				String angle = StringFromList(i,trajAngles,",") //segment angle
				Variable numTest = str2num(angle)
				Variable isSequence = (numtype(numTest) == 2) ? 1 : 0 //is it a sequence definition or a number?
				
				If(isSequence)
					Variable row = tableMatch(angle,stimData,startfrom=1)
					If(row == -1)
						continue
					EndIf
					
					trajectorySegments[i] = stimData[row][1]
				Else
					trajectorySegments[i] = angle
				EndIf
				
			EndFor
			
			//Loop through each item in the sequence for the first trajectory segment
			For(j=0;j<ItemsInList(trajectorySegments[0],";");j+=1)
				String duplicateCheck = ""
				
				//Loop through the number of segments
				For(i=0;i<ItemsInList(trajAngles,",");i+=1)
					stimList += StringFromList(j,trajectorySegments[i],";") + "t" //'t' is the turn designation I use, 90t270 means 90° turned into 270° for the trajectory
					duplicateCheck += StringFromList(j,trajectorySegments[i],";") + "t"
				EndFor
				
				//If all trajectory segments are the same, we can reduce it to a single angle
				duplicateCheck = RemoveDuplicateList(duplicateCheck,"t")
				If(ItemsInList(duplicateCheck,"t") == 1)
					stimList = ReplaceListItem(j,stimList,";",duplicateCheck)
				EndIf
				
				stimList = RemoveEnding(stimList,"t")
				stimList += ";" //new trajectory 
			EndFor
	
			break
		default:
			//get the attribute
			String assign = GetSequenceAssignment(fileID,0,NameByStimulus)
			
			strswitch(assign)
				case "None":
					stimList = GetAttribute(fileID,0,NameByStimulus)
					break
				default:
					stimList =  GetSequence(assign,fileID)
					break
			endswitch
			
			break			
	endswitch
	
	return stimList
End

//Counts the number of spikes in the wave
//This is for other functions to use, operates on a single wave
Function GetSpikeCount(theWave,StartTime,EndTime,Threshold)
	Wave theWave
	Variable StartTime,EndTime,Threshold
	
	If(!WaveExists(theWave))
		return -1
	EndIf
	
	DFREF saveDF = GetDataFolderDFR()
	SetDataFolder GetWavesDataFolder(theWave,1)
	
	Duplicate/FREE theWave,temp
	
	FlattenWave(temp)
	
	FindLevels/Q/D=spktm/R=(StartTime,EndTime)/M=0.002/T=0.0005 temp,threshold

	Variable spkct = V_LevelsFound
	KillWaves/Z W_FindLevels,spktm
	
	SetDataFolder saveDF
	
	return spkct
End


//Returns the vector sum angle or dsi of the input wave
Function OSVectorSum(theWave,angles,returnItem)
	Wave theWave
	String angles
	String returnItem
	
	Variable i,n,size = DimSize(theWave,0)
	
	If(ItemsInList(angles,";") != size)
		return -1 //angle list must be the same length as the input wave
	EndIf
	
	Variable vSumX,vSumY,totalSignal
	
	vSumX = 0
	vSumY = 0
	totalSignal = 0
	
	Variable count = 0
	
	For(i=0;i<size;i+=1)
		If(numtype(theWave[i]) == 2) //protects against NaNs, returns -9999, invalid
			return -9999
		EndIf
		
		Variable theAngle = str2num(StringFromList(i,angles,";"))
		
		vSumX += theWave[i]*cos(theAngle*pi/90)
		vSumY += theWave[i]*sin(theAngle*pi/90)
		totalSignal += theWave[i]
	EndFor
	
	Variable vRadius = sqrt(vSumX^2 + vSumY^2)
	Variable vAngle = atan2(vSumY,vSumX)*90/pi
	Variable	OSI = vRadius/totalSignal
	Variable SNR = vRadius
	
	If(vAngle < 0)
		vAngle +=360
	Endif

	strswitch(returnItem)
		case "angle":
		case "vAng":
		case "vAngle":
			return vAngle
			break
		case "resultant":
			return vRadius
			break
		case "OSI":
			return OSI
			break
	endswitch
End

//Returns the vector sum angle or dsi of the input wave
Function VectorSum(theWave,angles,returnItem)
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
		case "All":
			Make/N=3/O $(GetWavesDataFolder(theWave,2) + "_VectorSum")  /Wave=VSData
			VSData[0] = vAngle
			VSData[1] = DSI
			VSData[2] = vRadius
			
			SetDimLabel 0,0,Angle,VSData
			SetDimLabel 0,1,DSI,VSData
			SetDimLabel 0,2,Radius,VSData
			break
	endswitch
End

//Returns the vector sum angle or dsi of the input wave
Function [Variable PD,Variable DSI,Variable Radius] VectorSum2(Wave theWave,String angles)
	
	Variable i,size = DimSize(theWave,0)
	
	If(ItemsInList(angles,";") != size)
		return [-1,-1,-1] //angle list must be the same length as the input wave
	EndIf
	
	Variable vSumX,vSumY,totalSignal
	
	vSumX = 0
	vSumY = 0
	totalSignal = 0

	For(i=0;i<size;i+=1)
		If(numtype(theWave[i]) == 2) //protects against NaNs, returns -9999, invalid
			return [-9999,-9999,-9999]
		EndIf
		
		Variable theAngle = str2num(StringFromList(i,angles,";"))
		
		vSumX += theWave[i]*cos(theAngle*pi/180)
		vSumY += theWave[i]*sin(theAngle*pi/180)
		totalSignal += theWave[i]
	EndFor
	
	Variable vRadius = sqrt(vSumX^2 + vSumY^2)
	Variable vAngle = atan2(vSumY,vSumX)*180/pi
	DSI = vRadius/totalSignal
	Variable SNR = vRadius
	
	If(vAngle < 0)
		vAngle +=360
	Endif

	Make/N=3/O $(GetWavesDataFolder(theWave,2) + "_VectorSum")  /Wave=VSData
	VSData[0] = vAngle
	VSData[1] = DSI
	VSData[2] = vRadius
	
	SetDimLabel 0,0,Angle,VSData
	SetDimLabel 0,1,DSI,VSData
	SetDimLabel 0,2,Radius,VSData
	
	PD = vAngle
	Radius = vRadius
	
	return [PD,DSI,Radius]
End

//Same as SaveGraphCopy, but does it iteratively for an entire layout page
//Function SaveLayoutCopy()
	
	//Gets the top layout
	String theLayout = StringFromList(0,WinList("*",";","WIN:4"),";")
	
	//Get a list of all the graphs in the current layout page	
	String info = LayoutInfo(theLayout,"Layout")
	Variable numObjects = str2num(StringByKey("NUMOBJECTS",info,":",";"))
	
	Variable i
	String graphName = ""
	
	
	
	//This is the path that the new pxp will be saved in
	String path = SpecialDirPath("Desktop",0,0,0) + "Layouts"
	NewPath/O/Z/Q savePath,path
	
	info = ""
	For(i=0;i<numObjects;i+=1)
		info = LayoutInfo(theLayout,num2str(i))
		graphName = StringByKey("NAME",info,":",";")
		
		//Save a graph copy to a new experiment file
		SaveGraphCopy/O/P=savePath/W=$graphName as graphName
	EndFor
End


//Makes a series of waves of specified type, name, and dimensions
Function NT_MakeWaves(menu_Type,Rows,Columns,Layers,Chunks,NumberWaves,BaseName)
	//SUBMENU=Waves and Folders
	//TITLE=Make Waves
	
	String menu_Type
	Variable Rows,Columns,Layers,Chunks,NumberWaves
	String BaseName
	
	String menu_Type_List = "Numeric;Text;Wave Reference;"

	
	If(!strlen(BaseName))
		BaseName = "wave"
	EndIf
	
	Variable i
	For(i=0;i<NumberWaves;i+=1)
		strswitch(menu_Type)
			case "Numeric":
				Make/O/N=(Rows,Columns,Layers,Chunks) $UniqueName(BaseName,1,0)
				break
			case "Text":
				Make/O/T/N=(Rows,Columns,Layers,Chunks) $UniqueName(BaseName,1,0)
				break
			case "Wave Reference":
				Make/O/WAVE/N=(Rows,Columns,Layers,Chunks) $UniqueName(BaseName,1,0)
				break
		endswitch
	EndFor
End

//Kills the indicated waves
Function NT_KillWaves(DS_Waves)
	//SUBMENU=Waves and Folders
	//TITLE=Kill Waves
	
	String DS_Waves
	
	STRUCT ds ds
	GetStruct(ds)
	
	DFREF NPC = $CW
	Variable/G NPC:totalSize
	NVAR totalSize = NPC:totalSize
		
	If(ds.wsn == 0)
		totalSize = 0
	EndIf
	
	ds.wsi = 0
	Do
		Wave theWave = ds.waves[ds.wsi]
		String info = WaveInfo(theWave,0)
		totalSize += str2num(StringByKey("SIZEINBYTES",info))
		
		
		ReallyKillWaves(theWave)
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
	
	//print out the total size of the deleted waves after killing the waves.
	//print on last wave set
	If(ds.wsn == ds.numWaveSets[0]-1)
		print "Deleted:", totalSize / (1e6),"MB"
	EndIf
End





Function NT_RenameToTuning(DS_Tuning,DS_Data,NameIndex)
	String DS_Tuning //tuning curve to rename the data with
	String DS_Data //data to be renamed according to the preferred direction of the tuning curve
	Variable NameIndex //underscore position of the angle in the wave name
	
	//SUBMENU=Turning Project
	//TITLE=Rename to Tuning
	
//	Note={
//	Data waves are renamed so that it is normalized to the PD of the cell.
//	E.g. ND, N135, N90, N45, PD, P45, P90, P135 instead of angles.

//	\f01Tuning\f00 : Tuning curve data
//	\f01Data\f00 : Spiking, Calcium ROIs, or Currents that underlie tuning curve
//	\f01NameIndex\f00 : Underscore position in the 'Data' wave names that contain
//	    the angle of the stimulus.
//	}
	
	STRUCT ds ds
	GetStruct(ds)
	
	ds.wsi = 0
	
	Make/FREE/N=8 angleWave = 45 * x
	Make/FREE/N=8 distWave = 0
	
	
	Wave tuning = ds.waves[0][0] //one tuning curve per waveset
	//Get the preferred direction
	Variable PD = VectorSum(tuning,"0;45;90;135;180;225;270;315;","angle")
	
	//Get the angular distance of the PD from each angle, find the minimum
	distWave = polarMath(angleWave[p],PD,"deg","distance",0)
	
	WaveStats/Q/M=1 distWave
	Variable closestPD = angleWave[V_minRowLoc]
	
	//Change the names of the waves
	Do
		Wave data = ds.waves[ds.wsi][1]
		String name = NameOfWave(data)
		
		//name at the indicated underscore position
		String subname = StringFromList(NameIndex,name,"_")
		
		//is there a turn indicated by the name? (i.e. *t*)
		Variable isTurn = stringmatch(subname,"*t*")
		
		If(isTurn)
			//turn
			Variable entry = str2num(StringFromList(0,subname,"t"))
			Variable exit = str2num(StringFromList(1,subname,"t"))
			
			If(numtype(entry) == 2 || numtype(exit) == 2)
				Abort "Couldn't calculate angle"
			EndIf
			
			//distance between entry and exit directions
			Variable dist = round(polarMath(entry,exit,"deg","distance",1)) //signed distance
				
			//distance between PD and the entry direction
			Variable entryDist = round(polarMath(closestPD,entry,"deg","distance",1)) //signed distance
			
			switch(entryDist)
				case 0:
					String entryName = "PD"
					break
				case 180:
				case -180:
					entryName = "ND"
					break
				default:
					entryName = num2str(entryDist)
					If(stringmatch(entryName,"*-*"))
						entryName = ReplaceString("-",entryName,"N")
					Else
						entryName = "P" + entryName
					EndIf
					break
			endswitch
			
			switch(dist)
				case 90:
					String newName = ReplaceListItem(NameIndex,name,"_",entryName + "t90",noEnding=1)
					break
				case -90:
				 	newName = ReplaceListItem(NameIndex,name,"_",entryName + "tN90",noEnding=1)
					break
				case 180:
				case -180:
					newName = ReplaceListItem(NameIndex,name,"_",entryName + "t180",noEnding=1)
					
					break
				default:
					print "Unknown",dist
					break
			endswitch
			
			//If the new name is the same as the old one
			If(!cmpstr(name,newName))
				ds.wsi += 1
				continue
			EndIf
			
			SetDataFolder GetWavesDataFolder(data,1)
			Duplicate/O data,$newName 
			ReallyKillWaves(data)
		Else
			//linear
			
			//distance between PD and the entry direction
			entry = str2num(subname)
			
			If(numtype(entry) == 2)
				Abort "Couldn't find angle"
			EndIf
			
			entryDist = round(polarMath(closestPD,entry,"deg","distance",1)) //signed distance
			
			switch(entryDist)
				case 0:
					entryName = "PD"
					break
				case 180:
				case -180:
					entryName = "ND"
					break
				default:
					entryName = num2str(entryDist)
					If(stringmatch(entryName,"*-*"))
						entryName = ReplaceString("-",entryName,"N")
					Else
						entryName = "P" + entryName
					EndIf
					break
			endswitch
			
			//Generate the new name
			newName = ReplaceListItem(NameIndex,name,"_",entryName,noEnding=1)
			
			//If the new name is the same as the old one
			If(!cmpstr(name,newName))
				ds.wsi += 1
				continue
			EndIf
			
			SetDataFolder GetWavesDataFolder(data,1)
			Duplicate/O data,$newName 
			ReallyKillWaves(data)
			
		EndIf
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[1])
End

Function NT_TransienceIndex(DS_Data,StartTime,EndTime)
	String DS_Data
	Variable StartTime,EndTime
	
	//SUBMENU=GluSnFR Project
	//TITLE=Transience Index
	
	STRUCT ds ds
	GetStruct(ds)
	
	ds.wsi = 0

	SetDataFolder GetWavesDataFolder(ds.waves[0],1)
	
	String outName = NameOfWave(ds.waves[0]) + "_STI"
	Make/O/N=(ds.numWaves[0]) $outName/Wave=outWave
	
	AddOutput(outWave,ds)
	
	Do
		Wave theWave = ds.waves[ds.wsi]
				
		WaveStats/R=(StartTime,StartTime + 1) theWave
		
		//peak with a 100 ms measurement width
		Variable peak = mean(theWave,V_MaxLoc - 0.05,V_MaxLoc + 0.05)
		
		//area
		Variable ar = area(theWave,StartTime,EndTime) //2 second range is what zach used
		
		outWave[ds.wsi] = peak / ar
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
	
End

Function NT_NormalizedPeak(DS_Data,StartTime,EndTime)
	String DS_Data
	Variable StartTime,EndTime
	
	String StartTime_Assign = "root:Packages:NeuroToolsPlus:ControlWaves:rangeLeft"
	String EndTime_Assign = "root:Packages:NeuroToolsPlus:ControlWaves:rangeRight"
	
	//SUBMENU=GluSnFR Project
	//TITLE=Normalized Peak
	
	STRUCT ds ds
	GetStruct(ds)
	
	ds.wsi = 0
	
	SetDataFolder GetWavesDataFolder(ds.waves[0],1)
	
	String outName = NameOfWave(ds.waves[0]) + "_NormPk"
	Make/O/N=(ds.numWaves[0]) $outName/Wave=outWave
	
	AddOutput(outWave,ds)
	
	Do
		Wave theWave = ds.waves[ds.wsi]
				
		outWave[ds.wsi] = WaveMax(theWave,StartTime,EndTime)
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
	
	//Normalize to maximum value
	Variable maxVal = WaveMax(outWave)
	outWave /= maxVal
	
End


Function NT_FacilitationIndex(menu_DataType,DS_CenterSpot,DS_CenterNoSpot,DS_SurroundSpot,DS_SurroundNoSpot,StartTime,EndTime,Width,Threshold)
	String menu_DataType,DS_CenterSpot,DS_CenterNoSpot,DS_SurroundSpot,DS_SurroundNoSpot
	Variable StartTime,EndTime,Width,Threshold
	
	String menu_DataType_List = "Calcium;Spiking;PSTH;"
	
	//SUBMENU=Local Motion Project
	//TITLE=Facilitation Index
	
//	Note={
//	Calculates an index (FI) measuring how facilitated a spot response is
//	during continuous background jitter confined to the center versus the surround.
//	
//	FI = 0 means the spot response was equal for center and surround background
// stimuli
//
//	FI = 1 means the spot response was maximal for the surround background stimulus,
// but is zero for the center background stimulus.
//
//	FI = (Surround - Center) / (Surround + Center)
//	
// \f01DataType\f00 : Can accept either calcium recordings of ROIs, raw spike recordings, or 
// spike time histograms. 
// \f01Threshold\f00 : Calculates percent of waves above the threshold FI if using Calcium.
//		Used for spike threshold if using Spiking data type.
//	}
	
	STRUCT ds ds
	GetStruct(ds)
	
	ds.wsi = 0 
		
	//Creates a new output wave with the specified suffix
	Wave FI = MakeOutputWave(ds,"FI",0)
	
	//Creates percent above threshold wave
	Make/O/N=1 $(NameOfWave(FI) + "_pctAbove")/Wave=PctAbove
	
	FI = 0
	PctAbove = 0
	
	If(EndTime < StartTime)
		Abort "Ensure start and end times are valid"
	EndIf
	
	Do
		//Get all the waves
		Wave CS = ds.waves[ds.wsi][%CenterSpot]
		Wave SS = ds.waves[ds.wsi][%SurroundSpot]
		Wave CNS = ds.waves[ds.wsi][%CenterNoSpot]
		Wave SNS = ds.waves[ds.wsi][%SurroundNoSpot]
		
		//make sure the range is valid
		If(EndTime == 0)
			EndTime = xEnd(CS)
			StartTime = 0
		EndIf
		
		//Get the peaks
		strswitch(menu_DataType)
			case "Calcium":
				WaveStats/Z/Q/R=(StartTime,EndTime) CS
				Variable CSP = mean(CS,V_maxLoc - 0.5 * Width,V_maxLoc + 0.5 * Width)
				Variable CNSP = mean(CNS,V_maxLoc - 0.5 * Width,V_maxLoc + 0.5 * Width) //baseline response without the spot
						
				WaveStats/Z/Q/R=(StartTime,EndTime) SS
				Variable SSP = mean(SS,V_maxLoc - 0.5 * Width,V_maxLoc + 0.5 * Width)
				Variable SNSP = mean(SNS,V_maxLoc - 0.5 * Width,V_maxLoc + 0.5 * Width)  //baseline response without the spot
				Variable isCa = 1
				break
			case "Spiking":
				CSP = GetSpikeCount(CS,StartTime,EndTime,Threshold)
				CNSP = GetSpikeCount(CNS,StartTime,EndTime,Threshold)
				SSP = GetSpikeCount(SS,StartTime,EndTime,Threshold)
				SNSP = GetSpikeCount(SNS,StartTime,EndTime,Threshold)
				isCa = 0
				break
			case "PSTH":
				WaveStats/Z/Q/R=(StartTime,EndTime) CS
				CSP = mean(CS,V_maxLoc - 0.5 * Width,V_maxLoc + 0.5 * Width)
				CNSP = mean(CNS,V_maxLoc - 0.5 * Width,V_maxLoc + 0.5 * Width) //baseline response without the spot
						
				WaveStats/Z/Q/R=(StartTime,EndTime) SS
				SSP = mean(SS,V_maxLoc - 0.5 * Width,V_maxLoc + 0.5 * Width)
				SNSP = mean(SNS,V_maxLoc - 0.5 * Width,V_maxLoc + 0.5 * Width)  //baseline response without the spot
				isCa = 0
				break
		endswitch
		
		//Change from no spot to spot condition for center and surround clouds
		Variable Cdelta = CSP - CNSP
		Variable Sdelta = SSP - SNSP
		
		//calculate facilitation index
		FI[ds.wsi] = (Sdelta - Cdelta) / (Sdelta + Cdelta)
		
		If(FI[ds.wsi] > Threshold && isCa)
			PctAbove += 1
		EndIf
	
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[%CenterSpot])
	
	If(isCa)
		PctAbove = 100 * (PctAbove / ds.numWaves[%CenterSpot])
	EndIf
End

Function NT_PeakTime(DS_ROIs,PercentPeak,FitTime,StartTime,EndTime)
	String DS_ROIs
	Variable PercentPeak //0 to 1, 1 just takes the location peak itself
	Variable FitTime //amount of time prior to the peak location to begin the sigmoid fit
	Variable StartTime,EndTime
	
	//SUBMENU=Turning Project
	//TITLE=Peak Time
	
//	Note={
//	Finds the time point of the peak value, or some fraction of the peak value.
//	Performs a sigmoid fit to the peak event to more accurately get the peak rise times.
//	Output is a single wave with the peak times for each wave set.
//	
//	\f01PercentPeak\f00 : Time point when the amplitude is this fraction of the actual peak. 0-1.
//	      -Set to 1 to take the actual peak time. 
//	\f01FitTime\f00 : Amount of time prior to the peak to start the sigmoid fit (1-2 s)
//	\f01StartTime\f00 : Start X value for finding the peak
//	\f01EndTime\f00 : Ending X value for finding the peak
//	}
//	
	STRUCT ds ds
	GetStruct(ds)
	
	ds.wsi = 0
	
	If(PercentPeak > 1 || PercentPeak < 0)
		Abort "PercentPeak must be between 0 and 1"
	EndIf
	
	String outName = "PkLoc_" + NameOfWave(ds.waves[0])
	Make/O/N=(ds.numWaves[0]) $outName/Wave=outWave
	
	
	Note outWave,"Percent Peak: " + num2str(PercentPeak)
	Note outWave,"Peak Location Waves:"
	
	Do
		Wave ROI = ds.waves[ds.wsi]
		SetDataFolder GetWavesDataFolder(ROI,1)
		
		WaveStats/Q ROI
		
		//peak location X scale
		Variable pk = V_MaxLoc
		
		//Peak amplitude
		Variable pkVal = V_Max
		
		//peak location X point
		Variable pkPnt = ScaleToIndex(ROI,pk,0)
		
		Variable fitStart = pk - FitTime //fit starts 1 second prior to the peak 
		Variable fitStartPt = ScaleToIndex(ROI,fitStart,0)
		
		//Fit a sigmoid to the data for reducing measurement noise
		try
			CurveFit/Q sigmoid ROI[fitStartPt,pkPnt]/D;AbortOnRTE
		catch
			Variable error = GetRTError(1)
			print GetErrMessage(error),"...continuing..."
			continue
		endtry	
		
		Wave fit = $("fit_" + NameOfWave(ROI))
		
		If(!WaveExists(fit))
			Abort "Couldn't find the fit wave"
		EndIf
		
		Variable threshold = PercentPeak * pkVal
		FindLevel/EDGE=1/Q fit,threshold
		
		If(V_flag)
			print "Couldn't find the level. Using NaN"
			outWave[ds.wsi] = nan
		Else
			outWave[ds.wsi] = V_LevelX
		EndIf
		
		KillWaves/Z fit
		
		Note outWave,NameOfWave(ROI)
			
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
	
End

//Counts spikes for turning stimuli - Change Direction Project
Function NT_TurnSpikeCount(DS_SpikeData,Threshold,StartTime,EndTime,FolderName,menu_Range,menu_TurnType,filterTerm)
	//SUBMENU=Turning Project
	//TITLE=Spike Count (Turn Data)
	
//	Note={
//	Counts spikes, names the output waves specifically for turning stimuli.
//	
//	\f01Range\f00 : Specifies time range for the spike count
//	\f01TurnType\f00 : Specifies linear, ± 90°, or 180° turns
//	\f01FilterTerm\f00 : String for additional filtering of a data set. Waves that
//	    don't match the filter will be ignored.
//	}
	
	//Data Set for the spiking data
	String DS_SpikeData
	
	//Some input variables
	Variable Threshold,StartTime,EndTime
	
	//Name of the folder to put the spike counts in
	String FolderName
	
	//Drop down menu for the time range we're counting in - for wave naming purposes
	String menu_Range
	
	//Drop down menu for the type of turn the data contains
	String menu_TurnType
	
	//This will filter out certain wavesets. If the string match fails on the first wave, it will skip that wave set
	String filterTerm
	
	String menu_Range_List = "early;late;all;"
	String menu_TurnType_List = "Linear;Turn90;TurnN90;Turn180;"
	
	String Threshold_Assign = "root:Packages:NeuroToolsPlus:ControlWaves:threshold"
	
	//Data set info structure
	STRUCT ds ds 
	
	//Fills the data set structure
	GetStruct(ds)
	
	//Reset wave set index
	ds.wsi = 0
	
	//Filter term match test
	If(strlen(filterTerm))
		If(!stringmatch(NameOfWave(ds.waves[0]),filterTerm))
			return 0
		EndIf
	EndIf
	
	String folder = GetWavesDataFolder(ds.waves[0],1)
	
	If(strlen(FolderName))
		folder = ParseFilePath(1,folder,":",1,0) // back out one folder
	
		folder += FolderName
	EndIf
	
	If(!DataFolderExists(folder))
		NewDataFolder $folder
	EndIf
	
	SetDataFolder $folder
	
	//Name of the output wave that will hold the results
	String outputName = "DSSpk_" + menu_Range + "_" + StringsFromList("2-*",NameOfWave(ds.waves[0]),"_",noEnding=1)
	Make/O/N=(ds.numWaves[0]) $outputName/Wave = outWave
	
	String vAngName = "vAng_" + menu_Range + "_" + StringsFromList("2-*",NameOfWave(ds.waves[0]),"_",noEnding=1)
	Make/O/N=(1) $vAngName/Wave = vAng
	
	String dsiName = "vDSI_" + menu_Range + "_" + StringsFromList("2-*",NameOfWave(ds.waves[0]),"_",noEnding=1)
	Make/O/N=(1) $dsiName/Wave = dsi
	
	//Function Loop
	Do
		If(endTime == 0)
			endTime = pnt2x(ds.waves[ds.wsi],DimSize(ds.waves[ds.wsi],0)-1)
		EndIf
		
		//Spike count
		outWave[ds.wsi] = GetSpikeCount(ds.waves[ds.wsi],StartTime,EndTime,Threshold)
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
	
	//Were any spikes detected? If not, toss out the tuning curve
	If(sum(outWave) == 0)
		KillWaves/Z vAng,dsi,outWave
		return 0
	EndIf
	
	SetScale/P x,0,45,"deg",outWave
	
	//Vector Sum angle
	vAng[0] = VectorSum(outWave,"0;45;90;135;180;225;270;315;","angle")
	//Vector Sum DSI
	dsi[0] = VectorSum(outWave,"0;45;90;135;180;225;270;315;","DSI")
	
	
	Note outWave,"Threshold: " + num2str(Threshold)
	Note outWave,"StartTime: " + num2str(StartTime)
	Note outWave,"EndTime: " + num2str(EndTime)
	Note outWave,"Range: " + menu_Range
	Note outWave,"TurnType: " + menu_TurnType
	Note outWave,"PD: " + num2str(vAng[0])
	Note outWave,"DSI: " + num2str(dsi[0])
End

//Counts spikes for turning stimuli - Change Direction Project
Function NT_CollisionSpikeCount(DS_SpikeData,Threshold,StartTime,EndTime,menu_Range)
	//SUBMENU=Turning Project
	//TITLE=Spike Count (Collision Data)
	
//	Note={
//	Counts spikes, names the output waves specifically for colliding stimuli.
//	
//	\f01Range\f00 : Specifies time range for the spike count
	
	//Data Set for the spiking data
	String DS_SpikeData
	
	//Some input variables
	Variable Threshold,StartTime,EndTime

	//Drop down menu for the time range we're counting in - for wave naming purposes
	String menu_Range
	
	String menu_Range_List = "early;collision;late;"
	
	String Threshold_Assign = "root:Packages:NeuroToolsPlus:ControlWaves:threshold"
	
	//Data set info structure
	STRUCT ds ds 
	
	//Fills the data set structure
	GetStruct(ds)
	
	//Reset wave set index
	ds.wsi = 0
	
	String folder = GetWavesDataFolder(ds.waves[0],1)
	SetDataFolder $folder
	
	//Name of the output wave that will hold the results
	String outputName = "DSSpk_" + StringFromList(1,NameOfWave(ds.waves[0]),"_") + "_" + menu_Range + "_" + StringsFromList("2-*",NameOfWave(ds.waves[0]),"_",noEnding=1)
	Make/O/N=(ds.numWaves[0]) $outputName/Wave = outWave
	
	AddOutput(outWave,ds)
	
	//Function Loop
	Do
		If(endTime == 0)
			endTime = pnt2x(ds.waves[ds.wsi],DimSize(ds.waves[ds.wsi],0)-1)
		EndIf
		
		//Spike count
		outWave[ds.wsi] = GetSpikeCount(ds.waves[ds.wsi],StartTime,EndTime,Threshold)
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
		
	Note outWave,"Threshold: " + num2str(Threshold)
	Note outWave,"StartTime: " + num2str(StartTime)
	Note outWave,"EndTime: " + num2str(EndTime)
	Note outWave,"Range: " + menu_Range
End


//Calculates the difference in angle between two waves. 
Function NT_AngleDistance(DS_Turns,menu_Range,Suffix)
	//SUBMENU=Turning Project
	//TITLE=Angular Distance
	
//	Note = {
//	Gets the angular distance between the apparent preferred directions for -90° 
//	and +90° turns, compared with the preferred direction for the linear stimulus.
//	
//	Each wave set must contain all three (+90°,-90°, and linear) angle varieties.
//	
//	\f01Range\f00 : Time range that the tuning curves were acquired in (naming purposes)
//	\f01Suffix\f00 : Suffix applied to the output wave, defaults to 'delta'
//	}
	
	String DS_Turns //Data set containing linear, turn90, and turnN90 avg angles in each wave set.
	//If all three aren't present, we ignore the wave set.
	
	String menu_Range,Suffix
	String menu_Range_List = "early;late;all;"
	
	//Data set info structure
	STRUCT ds ds 
	
	//Fills the data set structure
	GetStruct(ds)
	
	//Data set checks, must have three waves
	If(ds.numWaves[0] != 3)
		return 0
	EndIf
	
	Variable i
	
	If(!strlen(suffix))
		suffix = "delta"
	EndIf
	
	//allocate to waves
	For(i=0;i<3;i+=1)
		String name = NameOfWave(ds.waves[i])
		
		If(stringmatch(name,"*t90*"))
			Wave turn90 = ds.waves[i]
			String outName = name + "_" + suffix
			SetDataFolder GetWavesDataFolder(turn90,1)
			Duplicate/O turn90,$outName
			Wave turn90_delta = $outName
			
		ElseIf(stringmatch(name,"*t270*"))
			Wave turnN90 = ds.waves[i]
			outName = name + "_" + suffix
			SetDataFolder GetWavesDataFolder(turnN90,1)
			Duplicate/O turnN90,$outName
			Wave turnN90_delta = $outName
			
		Else
			Wave linear = ds.waves[i]
		EndIf
	EndFor
	
	//Compute the signed difference between them
	turn90_delta[0] = polarMath(linear[0],turn90[0],"deg","distance",1)
	
	turnN90_delta[0] = polarMath(linear[0],turnN90[0],"deg","distance",1)
	
End


//Calculates the percent difference between two IPSCs. I'm using it to compare linear and turning stimuli IPSCs - Change Direction Project
Function NT_IPSC_PercentDiff(DS_IPSC_Turn,TurnIdentityPos,FolderName)
	//SUBMENU=Turning Project
	//TITLE=% Difference IPSC
	
//	Note={
//	Calculates the %Difference between two IPSC waves.
//	Input is two IPSC waves per wave set, one is the linear exit stimulus, 
//	      the other is the turning stimulus.
//	
//	\f01TurnIdentityPos\f00 : Underscore position that identifies the wave's
//	    turn type (turn90, turnN90, linear)
//	\f01FolderName\f00 : Name of folder for the output waves
//	}
	
	//Data Set for the turning IPSC data
	String DS_IPSC_Turn
	
	Variable TurnIdentityPos //this indicates the underscore position of where the turn name (e.g. 90t270) can be found
									//allows identification of the entry and exit direction for that turn
									
	//Name of the folder to put the spike counts in
	String FolderName
	
	//Data set info structure
	STRUCT ds ds 
	
	//Fills the data set structure
	GetStruct(ds)
	
	//Reset wave set index
	ds.wsi = 0
	
	//Function Loop
	Do
		Wave turn = ds.waves[ds.wsi][0] //turn wave
		
		If(!WaveExists(turn))
			continue
		EndIf
		
		//Set up the folder, otherwise puts data into the same folder 
		String folder = GetWavesDataFolder(ds.waves[ds.wsi][0],1)
		folder = ParseFilePath(1,folder,":",1,0) // back out one folder
		
		folder += FolderName
		
		If(!DataFolderExists(folder))
			NewDataFolder $folder
		EndIf
		
		SetDataFolder GetWavesDataFolder(turn,1)
		
		//Get entry and exit angles
		String entryAngle = StringFromList(0,StringFromList(TurnIdentityPos,NameOfWave(turn),"_"),"t")
		String exitAngle = StringFromList(1,StringFromList(TurnIdentityPos,NameOfWave(turn),"_"),"t")
		
		//Check that they are valid numeric angles
		Variable check = str2num(entryAngle)
		If(numtype(check) == 2)
			continue
		EndIf
		
		check = str2num(exitAngle)
		If(numtype(check) == 2)
			continue
		EndIf
		
		//Find the entry and exit linear waves
		String name = ReplaceListItem(TurnIdentityPos,NameOfWave(turn),"_",entryAngle,noEnding=1)
		
		Variable pos = whichlistitem("turn90",name,"_")
		If(pos == -1)
			pos = whichlistitem("turnN90",name,"_")
		EndIf
		
		If(pos == -1)
			print "Couldn't resolve the waves from the naming scheme"
			continue
		EndIf
		
		name = ReplaceListItem(pos,name,"_","linear",noEnding=1)
		
		Wave entry = $ReplaceListItem(TurnIdentityPos,name,"_",entryAngle,noEnding=1)
		Wave exit = $ReplaceListItem(TurnIdentityPos,name,"_",exitAngle,noEnding=1)
		
		//wave checks
		If(!WaveExists(entry) || !WaveExists(exit))
			print "Couldn't find the entry or exit wave"
			continue
		EndIf
		
		//Set data folder to the output folder 
		SetDataFolder $folder
		
		//Make the output waves to hold the percent differences
		String outputName = NameOfWave(turn)
		outputName = ReplaceListItem(0,outputName,"_", "PctDiff",noEnding=1)
		outputName = ReplaceListItem(TurnIdentityPos + 1,outputName,"_", "Entry",noEnding=1)
		Duplicate/O turn,$outputName/Wave=entryDiff

		outputName = ReplaceListItem(TurnIdentityPos + 1,outputName,"_", "Exit",noEnding=1)
		Duplicate/O turn,$outputName/Wave=exitDiff
		
		//Percent difference
		Multithread entryDiff = abs(entry - turn) / (0.5 * (entry + turn))
		Multithread exitDiff = abs(exit - turn) / (0.5 * (exit + turn))
		
		//Some median smoothing to kill the noise in low signal regions
		Smooth/M=0 50,entryDiff
		Smooth/M=0 50,exitDiff
		
		//Notes
		Note entryDiff,"Percent Difference:"
		Note entryDiff,GetWavesDataFolder(entry,2)
		Note entryDiff,GetWavesDataFolder(turn,2)
		
		Note exitDiff,"Percent Difference:"
		Note exitDiff,GetWavesDataFolder(exit,2)
		Note exitDiff,GetWavesDataFolder(turn,2)
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0][0])
	
End

Function NT_CircularStats(DS_Waves,cb_Radians,cb_outputInDegrees)
	//SUBMENU=Turning Project
	//TITLE=Circular Stats
	
	String DS_Waves //input waves contain angular data
	Variable cb_Radians //is the data already in radians?
	Variable cb_outputInDegrees //do you want the output data to be in degrees?
	
	//Data set info structure
	STRUCT ds ds 
	
	//Fills the data set structure
	GetStruct(ds)
	
	Variable i
	For(i=0;i<ds.numWaves[0];i+=1)
		Wave theWave = ds.waves[i]
		
		SetDataFolder GetWavesDataFolder(theWave,1)
		
		//Make radians scaled wave for the mean angles
		If(!cb_Radians)
			Duplicate/O theWave,$(ds.paths[i][0] + "_rad")
			Wave rad = $(ds.paths[i][0] + "_rad")
			rad = theWave * pi/180
		Else
			Wave rad = theWave
		EndIf		
		
		//Extra column needed for vector lengths, set all to 1
		Redimension/N=(-1,2) rad
		rad[][1] = 1
		
		StatsCircularMeans/Z/CI rad
		Wave stats = W_CircularMeans
		
		Duplicate/O stats,$(ds.paths[i][0] + "_CircularMeans")
		KillWaves/Z stats
		
		Wave stats = $(ds.paths[i][0] + "_CircularMeans")
		If(cb_outputInDegrees)
			stats[1] = stats[1] * 180/pi
			stats[2] = stats[2] * 180/pi
			stats[3] = stats[3] * 180/pi
			stats[4] = stats[4] * 180/pi
		EndIf
		
		Redimension/N=(-1,1) rad
		rad = (rad < 0) ? rad + 2*pi : rad
		StatsCircularMoments/Q/Z rad
		Wave stats = W_CircularStats
		
		If(cb_outputInDegrees)
		
			stats[10] = stats[10] * 180/pi//circular standard deviation
			stats[8] = stats[8] * 180/pi //mean
			stats[11] = stats[11] * 180/pi //median
		EndIf
		
		Duplicate/O stats,$(ds.paths[i][0] + "_CircularStats")
		KillWaves/Z stats
		
		
		
		
	EndFor
End

//Concatenates each wave in a waveset together into a single output wave
Function NT_Concatenate(DS_Waves,OutputFolder,Suffix)
	//SUBMENU=Waves and Folders
	String DS_Waves //input waves contain angular data
	String OutputFolder //name of the output folder, full path or relative path
	String Suffix //suffix applied to end of first wave in the wave set as the output wave name
	
	//Data set info structure
	STRUCT ds ds 
	
	//Fills the data set structure
	GetStruct(ds)
	
	//Which data folder should we put the output waves?
	If(strlen(OutputFolder))
		If(!stringmatch(OutputFolder,"root*"))
			CreateFolder(GetWavesDataFolder(ds.waves[0],1) + OutputFolder)
			SetDataFolder GetWavesDataFolder(ds.waves[0],1) + OutputFolder
		Else
			CreateFolder(OutputFolder)
			SetDataFolder OutputFolder
		EndIf
	EndIf
		
	OutputFolder = RemoveEnding(OutputFolder,":") + ":"
	
	If(!strlen(suffix))
		suffix = "concat"
	EndIf
	
	String path = NameOfWave(ds.waves[0])
	path += "_" + suffix
	path = OutputFolder + path
	
	String list = textWaveToStringList(ds.paths,";")
	
	Concatenate/NP/O list,$path

End



Function NT_MiscFunction(DS_Waves)
	String DS_Waves
	
	STRUCT ds ds
	GetStruct(ds)
	
	ds.wsi = 0
	
	
	Do
		Wave theWave = ds.waves[ds.wsi]
		
		//Enter code here
		SetDataFolder GetWavesDataFolder(theWave,1)
		
		Make/O/N=(DimSize(theWave,0)) $(NameOfWave(theWave) + "_DSI")/Wave = dsi
		
		Variable null = theWave[0]
		dsi = (theWave - null) / (theWave + null)
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])

End


//Generates a scatter plot with connected paired points
//Requires a 2D matrix wave, with each column containing pairs of points
Function NT_PairedScatterPlot(DS_Control,DS_Test)
	String DS_Control,DS_Test
	//SUBMENU=Graphing
	//TITLE=Paired Scatter Plot
	
//	Note={
//	Generates a scatter plot with connected paired points
//	Input control data set and a test data set.
// Control and Test must have same number of points
//	}
	
	STRUCT ds ds
	GetStruct(ds)
	
	ds.wsi = 0
	
	Do
		Wave control = ds.waves[ds.wsi][%Control]
		Wave test = ds.waves[ds.wsi][%Test]
		
		Variable cols = DimSize(control,0)
		
		If(cols != DimSize(test,0))
			DoAlert 0,"Data waves must have the same number of points."
			return 0
		EndIf
		
		SetDataFolder GetWavesDataFolder(control,1)
		
		String outName = NameOfWave(control) + "_VS_" + NameOfWave(test)
		Make/O/N=(2,cols) $outName/Wave=out
		
		out[0][] = control[q]
		out[1][] = test[q]
		
		Display out[][0]
		
		Variable i
		For(i=1;i<cols;i+=1)
			AppendToGraph out[][i]
		EndFor
		
		ModifyGraph mode=4,marker=8,msize=3,rgb=(0,0,0),lsize=0.5,opaque=1,btLen=2,btThick=0
		ModifyGraph axThick=0.5,axThick(bottom)=0.5,standoff(bottom)=0,manTick(left)={0,0.1,0,1},manMinor(left)={0,0},manTick(bottom)={0,1,0,0},manMinor(bottom)={0,0}
		ModifyGraph margin(left)=28,margin(bottom)=28,margin(right)=7,margin(top)=7,gfSize=8,standoff=0,ZisZ(left)=1
		SetAxis bottom -0.25,1.25
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[%Control])
	
End

//Calculates the modulation index of two Ca signals. Calculates the peak first, then a % difference.
Function NT_Modulation_Index(DS_Data,StartTime,EndTime,PeakWidth,cb_Abs_Value)
	//SUBMENU=Turning Project
	//TITLE=Modulation Index
//	
//	Note={
//	Calculates the modulation index between the peaks of two waves (difference / sum)
//	Each waveset should have two waves that will be compared.
//	
//	\f01StartTime:\f00 Starting X value for finding the peak
//	\f01EndTime:\f00 Ending X value for finding the peak
//	\f01PeakWidth:\f00 Size of window to average around the peak value.
//	}
	
	String DS_Data
	Variable StartTime,EndTime,PeakWidth,cb_Abs_Value
	
	//Data set info structure
	STRUCT ds ds 
	
	//Fills the data set structure
	GetStruct(ds)
	
	//Reset wave set index
	ds.wsi = 0
	
	DFREF saveDF = GetDataFolderDFR()
	
	If(ds.numWaves[0] != 2)
		Abort "This function requires 2 waves per wave set"
	EndIf

	//declare each wave in the wave set
	Wave wave1 = ds.waves[0]
	Wave wave2 = ds.waves[1]
	
	If(ds.wsn == 0)	
		SetDataFolder GetWavesDataFolder(wave1,1)
		Make/O/N=(ds.numWaveSets[0]) $"MI"/Wave=MI
		Note/K MI,"Modulation Index (difference / sum)"
		Note MI,"Waves:"
		
		SaveWaveRef(MI)
	Else
		Wave MI = recallSavedWaveRef()
	EndIf
	
	//YOUR CODE GOES HERE....
	Variable pk1,pk2,modulationIndex
	
	PeakWidth /= 2
	
	WaveStats/Q/R=(StartTime,EndTime) wave1 //find the peak location
	
	//Get the average value ±PeakWidth around the peak location
	pk1 = mean(wave1,V_maxLoc - PeakWidth,V_maxLoc + PeakWidth)
	
	WaveStats/Q/R=(StartTime,EndTime) wave2 //find the peak location
	
	//Get the average value ±PeakWidth around the peak location
	pk2 = mean(wave2,V_maxLoc - PeakWidth,V_maxLoc + PeakWidth)
	
//	pk1 = WaveMax(wave1,StartTime,EndTime)
//	pk2 = WaveMax(wave2,StartTime,EndTime)
	
	//Ensure no negative values
	pk1 = (pk1 < 0) ? 0 : pk1
	pk2 = (pk2 < 0) ? 0 : pk2
	
	If(cb_Abs_Value)
		MI[ds.wsn] = abs(pk2 - pk1) / (pk1 + pk2)
	Else
		MI[ds.wsn] = (pk2 - pk1) / (pk1 + pk2)
	EndIf
	
//	MI = (MI < 0) ? 0 : MI
	
	Note MI,NameOfWave(wave1) + " vs. " + NameOfWave(wave2)
	
	SetDataFolder saveDF
End

//Calculates the modulation index of two Ca signals. Calculates the peak first, then a % difference.
Function NT_Modulation_Index2(DS_Data1,DS_Data2,StartTime,EndTime,PeakWidth,cb_Abs_Value,Output_Suffix)
	//SUBMENU=Turning Project
	//TITLE=Modulation Index 2
//	
//	Note={
//	Calculates the modulation index between the peaks of two waves (difference / sum)
//	Corresponding waves in each data set are compared. Same as Modulation Index, but uses
// two data sets instead of one to define the data. 
//	
//	\f01StartTime:\f00 Starting X value for finding the peak
//	\f01EndTime:\f00 Ending X value for finding the peak
//	\f01PeakWidth:\f00 Size of window to average around the peak value.
//	}
	
	String DS_Data1,DS_Data2
	Variable StartTime,EndTime,PeakWidth,cb_Abs_Value
	String Output_Suffix
	
	//Data set info structure
	STRUCT ds ds 
	
	//Fills the data set structure
	GetStruct(ds)
	
	//Reset wave set index
	ds.wsi = 0
	
	DFREF saveDF = GetDataFolderDFR()
	
	If(ds.numWaves[0] != ds.numWaves[1])
		Abort "Each waveset must have the same number of waves"
	EndIf
	
	//modulation index wave is put in the first wave's folder
	Wave wave1 = ds.waves[0][0] //data 1
	SetDataFolder GetWavesDataFolder(wave1,1)
	
	If(strlen(Output_Suffix))
		Output_Suffix = "_" + Output_Suffix
	EndIf
	
	Make/O/N=(ds.numWaves[0]) $("MI" + Output_Suffix)/Wave=MI
	Note/K MI,"Modulation Index (difference / sum)"
	Note MI,"Waves:"
	
	//YOUR CODE GOES HERE....
	Variable pk1,pk2,modulationIndex
	
	PeakWidth /= 2
		
	Do
		//declare each wave in the wave set
		Wave wave1 = ds.waves[ds.wsi][0] //data 1
		Wave wave2 = ds.waves[ds.wsi][1] //data 2
		
		//Data 1
		WaveStats/Q/R=(StartTime,EndTime) wave1 //find the peak location
		
		//Get the average value ±PeakWidth around the peak location
		pk1 = mean(wave1,V_maxLoc - PeakWidth,V_maxLoc + PeakWidth)
		
		//Data 2
		WaveStats/Q/R=(StartTime,EndTime) wave2 //find the peak location
		
		//Get the average value ±PeakWidth around the peak location
		pk2 = mean(wave2,V_maxLoc - PeakWidth,V_maxLoc + PeakWidth)
		
		//Ensure no negative peak values
		pk1 = (pk1 < 0) ? 0 : pk1
		pk2 = (pk2 < 0) ? 0 : pk2
		
		//calculate modulation index for absolute value (unsigned DSI) or signed DSI.
		If(cb_Abs_Value)
			MI[ds.wsi] = abs(pk1 - pk2) / (pk1 + pk2)
		Else
			MI[ds.wsi] = (pk1 - pk2) / (pk1 + pk2)
		EndIf

		Note MI,NameOfWave(wave1) + " vs. " + NameOfWave(wave2)
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
	
	SetDataFolder saveDF
	
End



//Calculates the modulation index for a set of 3 Ca signals.
//MI = (Turn - ND) / (PD - ND)
//MI = 0 means the turn response was equal to the ND response.
//MI = 1 means the turn response was equal to the PD response.
Function NT_ModIndex_Turn180(DS_PD,DS_ND,DS_Turn,StartTime,EndTime,PeakWidth)
	//SUBMENU=Turning Project
	//TITLE=Mod. Index (Turn 180)
//	
//	Note={
//	Calculates modulation index using three waves, PD, ND, and Turn.
//	MI of 1 means the Turn is identical to the PD response
//	MI of 0 means the Turn is identical to the ND response
//	}
	
	String DS_PD,DS_ND,DS_Turn
	Variable StartTime,EndTime,PeakWidth
	
	//Data set info structure
	STRUCT ds ds 
	
	//Fills the data set structure
	GetStruct(ds)
	
	//Reset wave set index
	ds.wsi = 0
	
	DFREF saveDF = GetDataFolderDFR()
	
	If(ds.numWaves[0] != ds.numWaves[1] && ds.numWaves[0] != ds.numWaves[2])
		Abort "All wave sets must have the same number of waves"
	EndIf
	
	
	
	Do
		//declare each wave in the wave set
		Wave wave1 = ds.waves[ds.wsi][0]
		Wave wave2 = ds.waves[ds.wsi][1]
		Wave wave3 = ds.waves[ds.wsi][2]
		
		//Set the folder, output wave and wave notes
		If(ds.wsi == 0)
			SetDataFolder GetWavesDataFolder(wave1,1)
			Make/O/N=(ds.numWaves[0]) $"MI"/Wave=MI
			Note/K MI,"Modulation Index ( (Signal - ND) / (PD - ND))"
			Note MI,"Waves:"
		EndIf
		
		Variable pk1,pk2,pk3,modulationIndex
	
		PeakWidth /= 2
		
		WaveStats/Q/R=(StartTime,EndTime) wave1 //find the peak location
		
		//Get the average value ±PeakWidth around the peak location
		pk1 = mean(wave1,V_maxLoc - PeakWidth,V_maxLoc + PeakWidth)
		
		WaveStats/Q/R=(StartTime,EndTime) wave2 //find the peak location
		
		//Get the average value ±PeakWidth around the peak location
		pk2 = mean(wave2,V_maxLoc - PeakWidth,V_maxLoc + PeakWidth)
		
		WaveStats/Q/R=(StartTime,EndTime) wave3 //find the peak location
		
		//Get the average value ±PeakWidth around the peak location
		pk3 = mean(wave3,V_maxLoc - PeakWidth,V_maxLoc + PeakWidth)
		
		//Ensure no negative values
		pk1 = (pk1 < 0) ? 0 : pk1
		pk2 = (pk2 < 0) ? 0 : pk2
		pk3 = (pk3 < 0) ? 0 : pk3
		
		//Some special cases need to be handled to avoid unreasonable MI values in the case of the turn
		//response being greater than PD or less than ND.
		
		If(pk2 > pk1) //ND greater than PD, throw out the ROI with a nan MI index
			MI[ds.wsi] = -1
//		ElseIf(pk3 < pk2) //Turn less than ND, make MI = 0 since it is fully ND
//			MI[ds.wsi] = 0
//		ElseIf(pk3 > pk1) //Turn greater than PD, make MI = 1 ince it is fully PD
//			MI[ds.wsi] = 1
		Else
			MI[ds.wsi] = abs(pk3 - pk2) / (pk1 - pk2)
		EndIf
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
	
	SetDataFolder saveDF
End

Function NT_DefineROISector(DS_BaseImage,CDF_MI,X_Center,Y_Center,menu_Split,menu_ROI_Group,menu_diagonalAngle)
	//SUBMENU=Turning Project
	//TITLE=Define ROI Sector
	
//	Note = {
//	For a given set of ROIs, it assigns each ROI to different spatial sectors,
//	as defined by the 'Split' input, and the X/Y centers. Modulation index
//	for these ROIs is sorted into one wave for each spatial sector.
//	
//	\f01MI\f00 : Modulation index wave. Must be same size as number of ROIs
//	\f01X_Center\f00 : X center point on the image from where the divide is drawn
//	\f01Y_Center\f00 : Y center point on the image from where the divide is drawn
//	\f01Split\f00 : Defines how the image is split up into sectors
//	\f01ROI_Group\f00 : ROI Group from previously defined ROIs
//	\f01diagonalAngle\f00 : Defines angle to divide the image if diagonal split is chosen
//	}
	
	String DS_BaseImage,CDF_MI
	Variable X_Center,Y_Center
	String menu_Split //Should we split the receptive field vertically, horizontally, or diagonally
	String menu_ROI_Group
	String menu_diagonalAngle
	
	String menu_Split_List = "Vertical;Horizontal;Diagonal;"
	String menu_diagonalAngle_List = "45;-45;" //+45 is bottom left to top right, -45 is top left to bottom right
	
	//Use the ROI lists as the menu items 
	String menu_ROI_Group_List = TextWaveToStringList(root:Packages:NeuroToolsPlus:ScanImage:ROIGroupListWave,";")
	
	Variable angle = str2num(menu_diagonalAngle)
	
	DFREF NTSI = $SI
	
	//Data set info structure
	STRUCT ds ds 
	
	//Fills the data set structure
	GetStruct(ds)

	//If the data set happens to have more than one image in it, just use the first one
	Wave theWave = ds.waves[0]
	
	If(!WaveExists(theWave))
		return 0
	EndIf
	
	//Make sure it's a 2D wave
	If(WaveDims(theWave) < 2)
		return 0
	EndIf
	
	//Make sure the MI wave is selected and valid
	Wave/Z MI = $CDF_MI
	If(!WaveExists(MI))
		print "Couldn't find the MI Wave"
		return 0
	EndIf	
	
	//YOUR CODE GOES HERE....
	
	Variable rows =  DimSize(theWave,0)
	Variable cols =  DimSize(theWave,1)
	
	//Resolve the X center point
	If(X_Center > 1e-3 && X_Center < 1) //above scale of the image (mm not microns) means its a fractional input
		Variable xTurn = IndexToScale(theWave,DimSize(theWave,0) * X_Center,0)
	Else
		//Make sure center point is actually within the range of the images
		Variable index = ScaleToIndex(theWave,X_Center,0)
		If(index > rows || index < 0)
			DoAlert 1,"Turn center point was not within the image scale. Continue anyway?"
			
			If(V_flag == 2)
				Abort ""
			EndIf
		EndIf
		
		xTurn = X_Center
	EndIf
	
	//Resolve the Y center point
	If(Y_Center > 1e-3 && Y_Center < 1) //above scale of the image (mm not microns) means its a fractional input
		Variable yTurn = IndexToScale(theWave,DimSize(theWave,1) * Y_Center,1)
	Else
		//Make sure center point is actually within the range of the images
		index = ScaleToIndex(theWave,Y_Center,1)
		If(index > cols || index < 0)
			DoAlert 1,"Turn center point was not within the image scale. Continue anyway?"
			
			If(V_flag == 2)
				Abort ""
			EndIf
		EndIf
	
		yTurn = Y_Center
	EndIf
	
	//Get the center XY coordinates of the ROI group
	SI_GetCenter(group =menu_ROI_Group)
	
	SVAR software = NTSI:imagingSoftware
	
	strswitch(software)
		case "2PLSM":
			Wave xROI = $("root:twoP_ROIs:" + menu_ROI_Group + "_ROIx")
			Wave yROI = $("root:twoP_ROIs:" + menu_ROI_Group + "_ROIy")
			break
		case "ScanImage":
			Wave xROI = $("root:Packages:NeuroToolsPlus:ScanImage:ROIs:" + menu_ROI_Group + "_ROIx")
			Wave yROI = $("root:Packages:NeuroToolsPlus:ScanImage:ROIs:" + menu_ROI_Group + "_ROIy")
			break
	endswitch
	
	
	If(!WaveExists(xROI) || !WaveExists(yROI))
		return 0
	EndIf
	
	//Assign each ROI to one side of the image or the other
	Variable numROIs = DimSize(xROI,0)
	If(numROIs == 0)
		return 0
	EndIf
	
	//Name of the output wave that will hold the results
	SetDataFolder root:Analysis:$menu_ROI_Group
	String outputName = menu_ROI_Group + "_Sectors"
	
	DFREF MIFolder = GetWavesDataFolderDFR(MI)
	
	//Make the output wave 
	Make/O/N=(numROIs) $outputName/Wave = outWave
	
	Variable i,count1=0,count2=0
	For(i=0;i<numROIs;i+=1)
		Variable ycoord = yROI[i]
		Variable xcoord = xROI[i]
		
		strswitch(menu_Split)
			case "Vertical":
				If(i == 0)
					Make/O/N=1 :top/Wave=out1
					Make/O/N=1 :bottom/Wave=out2
				EndIf
						
				If(ycoord > yTurn)
					outWave[i] = 1 //top
					out1 += MI[i]
					count1 += 1
				Else
					outWave[i] = 0 //bottom
					out2 += MI[i]
					count2 += 1
				EndIf
				
				//Split the original MI wave into sectors for scatter plotting
				Duplicate/O MI,MIFolder:MI_top
				Duplicate/O MI,MIFolder:MI_bottom
				
				Wave MI_1 = MIFolder:MI_top
				Wave MI_2 = MIFolder:MI_bottom
				break
			case "Horizontal":
				If(i == 0)
					Make/O/N=1 :left/Wave=out1
					Make/O/N=1 :right/Wave=out2
				EndIf
				
				If(xcoord < xTurn)
					outWave[i] = 1 //left
					out1 += MI[i]
					count1 += 1
				Else
					outWave[i] = 0 //right
					out2 += MI[i]
					count2 += 1
				EndIf
				
				//Split the original MI wave into sectors for scatter plotting
				Duplicate/O MI,MIFolder:MI_left
				Duplicate/O MI,MIFolder:MI_right
				
				Wave MI_1 = MIFolder:MI_left
				Wave MI_2 = MIFolder:MI_right
				
				break
			case "Diagonal":
				If(i == 0)
					Make/O/N=1 :above/Wave=out1
					Make/O/N=1 :below/Wave=out2
				EndIf
				
				Variable slope = sin(angle * pi/180) / cos(angle * pi/180)
				Make/FREE line
				SetScale/I x,-200e-6,200e-6,line //set the scale range ±200 microns
				
				line =  (x - X_Center) * slope + Y_Center //y = mx + b
				
				//check if ROI is below the line
				Variable threshold = line[x2pnt(line,xCoord)]
				
				If(yCoord > threshold)
					//above the line
					outWave[i] = 1
					out1 += MI[i]
					count1 += 1
					
				Else
					//below the line
					outWave[i] = 0
					out2 += MI[i]
					count2 += 1
				EndIf
				
				//Split the original MI wave into sectors for scatter plotting
				Duplicate/O MI,MIFolder:MI_above
				Duplicate/O MI,MIFolder:MI_below
				
				Wave MI_1 = MIFolder:MI_above
				Wave MI_2 = MIFolder:MI_below
				
				break
		endswitch
	EndFor

	out1 /= count1
	out2 /= count2
	
	Variable num1 = sum(outWave) //number of sites in left/top/above
	Variable num2 = DimSize(outWave,0) - num1 //number of sites in right/bottom/below
	Redimension/N=(num1) MI_1
	Redimension/N=(num2) MI_2
	
	count1 = 0
	count2 = 0
	
	MI_1 = 0
	MI_2 = 0
	
	For(i=0;i<DimSize(outWave,0);i+=1)
		If(outWave[i] == 1)
			MI_1[count1] = MI[i] //left or top or above
			count1 += 1
		Else
			MI_2[count2] = MI[i] //right or bottom or below
			count2 += 1
		EndIf
	EndFor
	
	KillWaves/Z left,right
End

Function NT_DistanceFromSoma(DS_ROI_X,DS_ROI_Y,Soma_X,Soma_Y)
	String DS_ROI_X,DS_ROI_Y //X and Y coordinate waves for all the ROIs. Should be single waves.
	Variable Soma_X,Soma_Y //Scaled coordinates of the soma or whatever reference point we're using
	
	//SUBMENU=Turning Project
	//TITLE=Distance From Soma
	
	//	Note={
	//	Calculates the distance (line of sight, not cable distance) of ROIs from a target location,
	//	usually the soma but could be any coordinate. 
	//	
	//	Input two waves, one with all the ROIs X coordinates and the other with the Y coordinates.
	//	}
		
	STRUCT ds ds
	GetStruct(ds)
	
	If(ds.numWaves[%ROI_X] != 1 || ds.numWaves[%ROI_Y] != 1 )
		DoAlert 0,"Must have single X ROI coordinates wave and a single Y ROI coordinates wave."
		return 0
	EndIf
	
	//Get the coordinates waves
	Wave xROI = ds.waves[0][%ROI_X]
	Wave yROI = ds.waves[0][%ROI_Y]
	
	//Make the output distance wave
	String folder = GetWavesDataFolder(xROI,1)
	
	String outPath =  folder + RemoveEnding(NameOfWave(xROI),"x") + "_DistanceToSoma"
	Make/O/N=(DimSize(xROI,0)) $outPath/Wave=distance
	
	//calculate distance from the target coordinate.
	distance = sqrt((xROI[p] - Soma_X)^2 + (yROI[p] - Soma_Y)^2)

End

Function NT_AverageMasked(DS_Data,DS_DataMask,cb_InvertMask,OutputFolder,cb_replaceSuffix)
	//SUBMENU=Turning Project
	//TITLE=Average With Data Mask
	String DS_Data,DS_DataMask
	Variable cb_InvertMask
	String OutputFolder
	Variable cb_replaceSuffix
	
//	Note={
//	Averages waves according to a bitwise data mask. Mask values of 1 are included 
// in the average.

//	\f01Invert Mask\f00 : Mask values of 0 are included in the average
//	\f01outFolder\f00 : Folder to put the averaged wave.
//	\f01ReplaceSuffix\f00 : End of the wave name is replaced with '_avg'. Otherwise '_avg'
//      is added to the end of the wave name.
//	}
	
	STRUCT ds ds
	GetStruct(ds)
	
	DFREF cdf = GetDataFolderDFR()
	
	Wave mask = ds.waves[0][1]
	
	If(numpnts(mask) != DimSize(ds.waves,0))
		Abort "Data mask must have the same number of points as the number of waves"
	EndIf
	
	//Create output folder if specified
	If(strlen(OutputFolder))
		If(!DataFolderExists(GetWavesDataFolder(ds.waves[0],1) + OutputFolder))
			NewDataFolder $(GetWavesDataFolder(ds.waves[0],1) + OutputFolder)
		EndIf
	EndIf
	SetDataFolder GetWavesDataFolder(ds.waves[0],1) + OutputFolder
		
	//Make output wave for each wave set
	If(cb_ReplaceSuffix)
		String outputName = ReplaceSuffix(NameOfWave(ds.waves[0]),"avg")
	Else
		outputName = NameOfWave(ds.waves[0]) + "_avg"
	EndIf
	
	//What is the wave type?
	Variable type = WaveType(ds.waves[0])
	
	//Make the output wave of the same type
	Make/O/N=(DimSize(ds.waves[0],0),DimSize(ds.waves[0],1),DimSize(ds.waves[0],2))/Y=(type) $outputName/Wave=outWave
	
	//Set the scale of the output wave
	String xDim = WaveUnits(ds.waves[0],0)
	String yDim = WaveUnits(ds.waves[0],1)
	String zDim = WaveUnits(ds.waves[0],2)
	
	SetScale/P x,DimOffset(ds.waves[0],0),DimDelta(ds.waves[0],0),xDim,outWave
	SetScale/P y,DimOffset(ds.waves[0],1),DimDelta(ds.waves[0],1),yDim,outWave
	SetScale/P z,DimOffset(ds.waves[0],2),DimDelta(ds.waves[0],2),zDim,outWave
	
	//Add outwave to the output data set
	AddOutput(outWave,ds)

	//Reset outWave in case of overwrite
	outWave = 0
	
	String noteStr = "Average: " + num2str(ds.numWaves[0]) + " Waves\r"
	
	Variable count = 0
	ds.wsi = 0
	Do
		//Check masking
		If(cb_InvertMask)
			If(!mask[ds.wsi])
				Wave theWave = ds.waves[ds.wsi][0]
				count += 1
			Else
				ds.wsi += 1
				
				If(ds.wsi >= ds.numWaves[0])
					break
				EndIf
				continue
			EndIf
		Else
			If(mask[ds.wsi])
				Wave theWave = ds.waves[ds.wsi][0]
				count += 1
			Else
				ds.wsi += 1
				If(ds.wsi >= ds.numWaves[0])
					break
				EndIf
				continue
			EndIf
		EndIf
		
		Multithread outWave += theWave
		
		noteStr += ds.paths[ds.wsi][0] + "\r"
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
	
	Multithread outWave /= count
	
	//Set the wave note
	Note/K outWave,noteStr
	
	//Reset data folder
	SetDataFolder cdf
	
End



//Generates a custom color table for a green to magenta fade
Function NT_CustomColorTable(menu_firstColor,menu_secondColor,alpha)
	//SUBMENU=Waves and Folders
	//TITLE=Custom Color Table
//	
//	Note={
//	\f01firstColor\f00 : Starting color for the color table

//	\f01secondColor\f00 : firstColor will be blended into this color

//	\f01alpha\f00 : transparency, either as 0-100 or 0-1 range works.
//	}

	String menu_firstColor,menu_secondColor
	Variable alpha
	
	//Menu items
	String menu_firstColor_List = "Red;Green;Blue;Yellow;Orange;White;Black;Magenta;Cyan;"
	String menu_secondColor_List = "Red;Green;Blue;Yellow;Orange;White;Black;Magenta;Cyan;"
	
	//percentage alpha
	If(alpha <= 1)
		alpha = round(0xffff * alpha)
	EndIf
	
	DFREF saveDF = GetDataFolderDFR()
	
	If(!DataFolderExists("root:Packages:NeuroToolsPlus:CustomColors"))
		NewDataFolder root:Packages:NeuroToolsPlus:CustomColors
	EndIf
		
	DFREF cc = root:Packages:NeuroToolsPlus:CustomColors
	SetDataFolder cc
	
	Make/U/W/O/N=(256,4) cc:$(menu_firstColor + menu_secondcolor)/Wave = color
	
	Variable startR,startG,startB,endR,endG,endB
	
	strswitch(menu_firstColor)
		case "Green":
			startR = 0
			startG = 0xffff
			startB = 0		
			break
		case "Blue":
			startR = 0
			startG = 0
			startB = 0xffff
			break
		case "Red":
			startR = 0xffff
			startG = 0
			startB = 0
			break
		case "Yellow":
			startR = 0xffff
			startG = 0xffff
			startB = 0
			break
		case "Orange":
			startR = 0xffff
			startG = 0.64 * 0xffff
			startB = 0
			break		
		case "White":
			startR = 0xffff
			startG = 0xffff
			startB = 0xffff
			break
		case "Black":
			startR = 0
			startG = 0
			startB = 0
			break
		case "Magenta":
			startR = 0xffff
			startG = 0
			startB = 0xffff
			break
		case "Cyan":
			startR = 0
			startG = 0xffff
			startB = 0xffff
			break
	endswitch
	
	strswitch(menu_secondColor)
		case "Green":
			endR = 0
			endG = 0xffff
			endB = 0
			break
		case "Blue":
			endR = 0
			endG = 0
			endB = 0xffff
			break
		case "Red":
			endR = 0xffff
			endG = 0
			endB = 0
			break
		case "Yellow":
			endR = 0xffff
			endG = 0xffff
			endB = 0
			break
		case "Orange":
			endR = 0xffff
			endG = 0.64 * 0xffff
			endB = 0
			break		
		case "White":
			endR = 0xffff
			endG = 0xffff
			endB = 0xffff
			break	
		case "Black":
			endR = 0
			endG = 0
			endB = 0
			break	
		case "Magenta":
			endR = 0xffff
			endG = 0
			endB = 0xffff
			break
		case "Cyan":
			endR = 0
			endG = 0xffff
			endB = 0xffff
			break
	endswitch
	
	//Assign the colors and alpha
	color[][0] = startR + ((endR - startR) / 255) * x
	color[][1] = startG + ((endG - startG) / 255) * x
	color[][2] = startB + ((endB - startB) / 255) * x
	color[][3] = alpha
	
	SetDataFolder saveDF
End

Function copyTable()

	Wave/T test = root:test
	
	Make/O/T/N=(DimSize(test,0),DimSize(test,1) * 2) root:copy/Wave=copy
	copy = ""
	copy[][1,33;2] = test[p][floor(q/2)]
	

End