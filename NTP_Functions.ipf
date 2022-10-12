#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//Command functions that are built into NeuroTools


Function RunCmd(cmd)
//RUN COMMAND MASTER FUNCTION
	String cmd
	DFREF NPC = $CW
	
	//Initialize data set info structure
	STRUCT ds ds
	
	//Make sure a timer is available
	ResetAllTimers()
	
	//Save data folder
	DFREF saveDF = $GetDataFolder(1)
	
	//Retrieve the data set information into the main data set Structure, called ds
	//The definition of STRUCTURE ds lives in NTP_Structures.ipf
	
//	Wave/T listWave 		---listwave being used by the data set (Wave Match, Navigator, or a Data Set)
//	Wave/T name 				---holds data set names
//	Wave/T paths 			---string list of the waves in the wsn
//	Wave/WAVE output 		---holds the wave references for any output waves
//	Wave/WAVE waves 		---wave of wave references for the wsn
//	Wave numWaveSets 		---number of wave sets
//	int16 wsi 				---current wave set index
//	int16 wsn 				---current wave set number
//	Wave numWaves 			---number of waves in the current wsn for each data set
//	int16 numDataSets 		---number of datasets defined
	Variable i,j,error = GetDataSetInfo(ds)
	
	If(error == -1)
		//reserved, doesn't break bc data sets aren't required necessarily
		return 0
	EndIf
	
	//Start a timer to time the function execution
	Variable ref = StartMSTimer
	
	//Reset the output waveset wave
	Redimension/N=0 ds.output
	
	//WSN (Wave Set Number) loop
		//Each data set is comprised of potentially multiple wave sets, each referenced by their wave set number
	Do
		//Get the waves in each wave set using the ds structure
		Wave/WAVE ds.waves = GetWaveSetRefs(ds.listWave,ds.wsn,ds.name)
		
		//Resize the text wave that holds the full paths to the waves
		Redimension/N=(DimSize(ds.Waves,0),DimSize(ds.Waves,1)) ds.paths
		
		//A function may reference multiple data sets.
		//Wave sets and waves must be retrieved from each of them
		For(i=0;i<ds.numDataSets;i+=1)
			
			//Retrieve the full paths to the waves in each wave set
			String fullPaths = GetWaveSetList(ds.listWave,ds.wsn,1,dsNum=i)
			
			//Remove any potential empty positions that might be at the end of the list wave if the two data sets have different numbers of waves
			fullPaths = RemoveEmptyItems(fullPaths,";")
			
			//Put the full paths to the waves into the ds structure as ds.paths
			ds.paths[][i] = StringFromList(p,fullPaths,";")

			//Number of waves for each data set
			ds.numWaves[i] = ItemsInList(fullPaths,";")
		EndFor
		
		//Make sure we start at the same point every call to the function in case of 'current data folder' wave references
		SetDataFolder saveDF
		
		//Execute the function with the resolved data set structure
		Wave/WAVE out = ExecuteCommand(ds,cmd)
		
		//Increment to the next WSN
		ds.wsn += 1
		
		//Reset the WSI
		ds.wsi = 0
	While(ds.wsn < ds.numWaveSets[0]) //This may be a bug for situations where each data sets have different numbers of wave sets.
	
	//If output waves were assigned in the function, make a new data set
	If(DimSize(ds.output,0))
		//Change the listbox focus to data set before creating the data set output
		changeFocus("DataSet",1)
		
		//create output data set 
		CreateOutputDataSet(ds)
	EndIf
	
	//End the timer, print the result
	print cmd + ":",StopMSTimer(ref)/(1e6),"s"
	
	//Return to original data folder
	SetDataFolder saveDF
	
	//Check data set wave existence in case waves were deleted or renamed during execution
	CheckDataSetWaves()
	
	//Update the folders and wave list waves for the GUI
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
Function NT_Measure(DS_Waves,menu_Type,StartTime,EndTime,BaselineStart,BaselineEnd,Threshold,Width,cb_SubtractBaseline,cb_SaveToParentFolder,menu_SortOutput,OutputName,AngleWave,menu_ReturnType,menu_OSReturnType)
	String DS_Waves,menu_Type
	Variable StartTime,EndTime,BaselineStart,BaselineEnd,Threshold,Width,cb_SubtractBaseline,cb_SaveToParentFolder
	String menu_SortOutput,OutputName,AngleWave,menu_ReturnType,menu_OSReturnType
	
	String menu_Type_List = "Peak;Peak Location;Minimum;Area;Mean;Median;Std. Dev.;Std. Error;# Spikes;Orientation Vector Sum;Vector Sum;"
	String menu_Type_Proc = "measureProc" //this identifies a trigger procedure based on the menu selection
	String menu_ReturnType_List = "All;Angle;DSI;Resultant;"
	String menu_OSReturnType_List = "Angle;OSI;Resultant;"
	String menu_SortOutput_List = "Linear;Alternating;"
	String Threshold_Assign = "root:Packages:NeuroToolsPlus:ControlWaves:threshold" //assigns the threshold variable to the Viewer Graph threshold bar
	String StartTime_Assign = "root:Packages:NeuroToolsPlus:ControlWaves:rangeLeft"
	String EndTime_Assign = "root:Packages:NeuroToolsPlus:ControlWaves:rangeRight"
	
	
	//title designations
	String menu_ReturnType_Title = "Return Type"
	String menu_OSReturnType_Title = "OS Return Type"
	String menu_SortOutput_Title = "Sort Output"
	String StartTime_Title = "Start Time (s)"
	String EndTime_Title = "End Time (s)"
	String BaselineStart_Title = "Baseline Start (s)"
	String BaselineEnd_Title = "Baseline End (s)"
	String cb_SubtractBaseline_Title = "Subtract Baseline"
	String AngleWave_Title = "Angle Wave"
	String OutputName_Title = "Output Name"
	String cb_SaveToParentFolder_Title = "Save To Parent"
	
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
		case "Minimum":
			suffix = "_min"
			theNote = "Minimum:\n"
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
	If(!strlen(OutputName))
		OutputName = NameOfWave(ds.waves[0][%Waves]) + suffix
	EndIf
	
	If(cb_SaveToParentFolder)
		SetDataFolder $ParseFilePath(1,GetWavesDataFolder(ds.waves[0][%Waves],1),":",1,0)
	Else
		SetDataFolder GetWavesDataFolderDFR(ds.waves[0][%Waves])
	EndIf
	
	Make/O/N=(ds.numWaves[0]) $OutputName /Wave = outWave
	
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
				If(Width > 0)
					outWave[ds.wsi] = mean(theWave,V_maxloc - 0.5*Width,V_maxloc + 0.5*Width)
				Else
					outWave[ds.wsi] = V_max
				EndIf
											
				If(cb_subtractBaseline)
					If(BaselineEnd == 0)
						BaselineStart = pnt2x(theWave,0)
						BaselineEnd = pnt2x(theWave,DimSize(theWave,0) - 1)
					EndIf
					
					If(BaselineEnd < BaselineStart)
						DoAlert 0,"Baseline End must be after Baseline Start"
						return 0
					EndIf
					
					Variable bgnd = median(theWave,BaselineStart,BaselineEnd)
					outWave[ds.wsi] -= bgnd
				EndIf
				
				break
			case "Peak Location": //peak x location
				outWave[ds.wsi] = V_maxLoc
				break
			case "Minimum": //minimum value (negative peak)
				
				If(Width > 0)
					outWave[ds.wsi] = mean(theWave,V_minloc - 0.5*Width,V_minloc + 0.5*Width)
				Else
					outWave[ds.wsi] = V_min
				EndIf
				
				If(cb_subtractBaseline)
					If(BaselineEnd == 0)
						BaselineStart = pnt2x(theWave,0)
						BaselineEnd = pnt2x(theWave,DimSize(theWave,0) - 1)
					EndIf
						
					If(BaselineEnd < BaselineStart)
						DoAlert 0,"Baseline End must be after Baseline Start"
						return 0
					EndIf
					
					WaveStats/M=1/Q/R=(BaselineStart,BaselineEnd) theWave
					
					bgnd = median(theWave,BaselineStart,BaselineEnd)
					outWave[ds.wsi] -= bgnd
				EndIf
				
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
	
	//title designation for the control
	String outFolder_Title = "Output Folder"
	String cb_ReplaceSuffix_Title = "Replace Suffix"
	String cb_isCircular_Title = "Circular Data?"

//	Note={
//	Averages the waves in each wave set
//	
//	\f01outFolder\f00 : Folder to put the averaged wave.
//	\f01ReplaceSuffix\f00 : End of the wave name is replaced with '_avg'. Otherwise '_avg' is added to the end of the wave name.
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
//	If(!free)
//		AddOutput(outWave,ds)
//	EndIf
	
	//How many dimensions in the wave
	Variable nDims = WaveDims(ds.waves[0])
	
	//Reset outWave in case of overwrite
	If(nDims > 2)
		Multithread outWave = 0
	Else
		outWave = 0
	EndIf
	
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
		
		If(nDims > 2)
			Multithread pnts = 0
		Else
			pnts = 0
		EndIf
				
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
				
				If(nDims > 2)
					Multithread pnts += 1
					Multithread pnts = (numtype(temp[p][q][r]) == 2) ? pnts - 1 : pnts
				
					//replace nans with 0
					Multithread temp = (numtype(temp[p][q][r]) == 2) ? 0 : temp[p][q][r]
				Else					
					pnts += 1
					pnts = (numtype(temp[p][q]) == 2) ? pnts - 1 : pnts
				
					//replace nans with 0
					temp = (numtype(temp[p][q]) == 2) ? 0 : temp[p][q]
				EndIf
				
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
	
//	Redimension/Y=(type) outWave
//		
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
	
	//title designation for the control
	String menu_errorType_Title = "Type"
	String outFolder_Title = "Output Folder"
	String cb_ReplaceSuffix_Title = "Replace Suffix"
	String cb_isCircular_Title = "Circular Data?"
	
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
Function NT_Histogram(DS_Waves,StartY,EndY,BinSize,cb_Centered,Suffix)
	
	String DS_Waves
	Variable StartY,EndY
	Variable BinSize,cb_Centered
	String Suffix
	
	//Title designations
	String StartY_Title = "Y Start"
	String EndY_Title = "Y End"
	String BinSize_Title = "Bin Size"
	
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
		
		If(StartY == 0 && EndY == 0)
			EndY = WaveMax(theWave)
			StartY = WaveMin(theWave)
		EndIf
		
		Variable numBins = ceil((EndY - StartY) / BinSize)
				
		//Make the histogram wave
		Make/O/N=(numBins) $outName/Wave=hist
		
		//Get the histogram
		If(cb_Centered)
			Histogram/B={StartY,binSize,numBins}/C theWave,hist
		Else
			Histogram/B={StartY,binSize,numBins} theWave,hist
		EndIf
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
End

Function GetTopGraphProc(ba) : ButtonControl
	//Called from NT_AppendErrorShading and NT_ReconstructNeuron in the ScanImage package
	STRUCT WMButtonAction &ba
	
	DFREF NPC = $CW
	Wave/T param = NPC:ExtFunc_Parameters
	SVAR currentFunc = NPC:currentFunc
	
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			
			//Retrieve the name of the top graph window
			String list = WinList("*",";","WIN:1")
			list = RemoveFromList("NTP",list,";")
			
			String name = StringFromList(0,list,";")
			
			//Get the 'Graph' control
			String ctrlName = getParam2("Graph","CTRL",currentFunc)
			
			//Insert the graph name into the Graph control
			SetVariable/Z $ctrlName win=NTP#Func,value=_STR:name	
			
			//Insert into the parameters wave
			String key = "PARAM_" + GetParam2("Graph","INDEX",currentFunc) + "_VALUE"
			setParam(key,currentFunc,name)
			
			break	
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function NT_AppendErrors(Graph,bt_GraphName,Suffix,menu_Type)
	//TITLE=Append Errors
	//SUBMENU=Graphing
	
	String Graph
	String bt_GraphName //button
	String Suffix
	String menu_Type
	
	String bt_GraphName_Title = "Get Top Graph"
	String bt_GraphName_Proc = "GetTopGraphProc"
	String bt_GraphName_Pos = "105;-27;100;20;"
	String menu_Type_List = "Shading;Bars;"
	
	String Suffix_Pos = "0;-25;"
	String menu_Type_Pos = "0;-25;"
//	Note={
//	Appends error shading to traces in the top graph.
//	Error waves must already exist, probably generated using the 'Errors' function.
//	The name of the error wave must be the same as the trace on the graph except
//	for the specified suffix.
//
//	e.g. If suffix = 'stdev':
//	     \f01trace\f00 : 'data_control_1_avg'
//	     \f01error wave\f00 : 'data_control_1_stdev'
//	}

	STRUCT ds ds
	GetStruct(ds)
		
	String traceList = TraceNameList(Graph,";",1)
	Variable i,numTraces = ItemsInList(traceList,";")
	
	For(i=0;i<numTraces;i+=1)
		String trace = StringFromList(i,traceList,";")
		Wave t = TraceNameToWaveRef(Graph,trace)
		
		If(!WaveExists(t))
			continue
		EndIf
		
		SetDataFolder GetWavesDataFolderDFR(t)
		
		String errorName = ReplaceListItem(ItemsInList(trace,"_") - 1,trace,"_",Suffix,noEnding=1)
		
		Wave errorWave = $errorName
		
		If(!WaveExists(errorWave))
			continue
		EndIf
		
		strswitch(menu_Type)
			case "Shading":
				ErrorBars/W=$Graph $NameOfWave(t) SHADE= {0,0,(0,0,0,0),(0,0,0,0)},wave=(errorWave,errorWave)
				break
			case "Bars":
				ErrorBars/W=$Graph/T=0.5/L=0.5 $NameOfWave(t) Y,wave=(errorWave,errorWave)
				break
		endswitch
	EndFor
End

Function NT_Display(DS_Waves,menu_AxisSeparation)
	//SUBMENU=Graphing
	
	String DS_Waves,menu_AxisSeparation
	
	String menu_AxisSeparation_List = "None;Horizontal;Vertical;Grid;"
	
	DFREF NPC = $CW
	
	STRUCT ds ds
	
	//By checking, this allows a user to run this using a wave list as well
	Wave/Z dsWave = GetDataSetWave(DS_Waves,"BASE")
	
	If(!WaveExists(dsWave))
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
		
		Wave theWave = ds.waves[ds.wsi][%Waves]
		
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
	While(ds.wsi < ds.numWaves[%Waves])

End

//Sets the wave note for the waves
Function NT_SetWaveNote(DS_Waves,noteStr,cb_overwrite)
	//SUBMENU=Waves and Folders
	//TITLE=Set Wave Note
	//SUBGROUP=Waves
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
	//SUBGROUP=Renaming
	
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


Function NT_RenameData(DS_InputWaves,DS_OutputWaves)
	String DS_InputWaves,DS_OutputWaves
	//TITLE=Rename Data
	//SUBMENU=Waves and Folders
	//SUBGROUP=Renaming
	
//	Note={
//	Requires 2 archived data sets. The first data set will be renamed
//	as defined in the second data set
//	}
	
	//Title designations
	String DS_InputWaves_Title = "Input Waves"
	String DS_OutputWaves_Title = "Output Waves"
	
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


Function NT_MoveToFolder(DS_Waves,MoveToFolder,RelativeFolder)
	//SUBMENU=Waves and Folders
	//TITLE=Move Waves
	//SUBGROUP=Waves
	
//	Note={
//	Moves waves to the indicated folder within the current data folder
//	Use the relative folder depth to back out of the current data folder.
//
//	i.e. Relative Folder = -1 will move the waves into the parent folder.
//	}

	String DS_Waves
	String MoveToFolder
	Variable RelativeFolder
	
	String MoveToFolder_Title = "Move To Folder"
	String RelativeFolder_Title = "Relative Folder"
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
	//SUBGROUP=Folders
	
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
	//SUBGROUP=Folders
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
					HDF5OpenFile/Q/R fileID as fullPath
			
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
					HDF5OpenFile/Q/R fileID as fullPath
			
					If(V_flag == -1) //cancelled
						break
					EndIf
					
					//Save the path and filename
					wsFilePath = S_path
					wsFileName = S_fileName
					
					String seriesList = TT_GetSeriesList(fileID,",")
					String protList = TT_GetProtocolList(fileID)
//					String stimList = TT_GetStimList(fileID)
					
					Wave/T wsSweepListWave = $getParam2("lb_SweepList","LISTWAVE","NT_LoadEphys")
					Wave/T wsSweepSelWave = $getParam2("lb_SweepList","SELWAVE","NT_LoadEphys")
					
					Redimension/N=(ItemsInList(seriesList,",")) wsSweepListWave
					
					If(WaveExists(wsSweepSelWave))
						Redimension/N=(ItemsInList(seriesList,",")) wsSweepSelWave
					EndIf
					
					wsSweepListWave = StringFromList(p,seriesList,",") + "/" + StringFromList(p,protList,";")
					
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
		
			ScanLoadPath = BrowseScanImage()
			
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
			visibleList += "AngleWave;menu_ReturnType;cb_SaveToParentFolder;"
			break
		case "Orientation Vector Sum":
			visibleList += "AngleWave;menu_OSReturnType;cb_SaveToParentFolder;"
			break
		case "Peak":
			visibleList += "StartTime;EndTime;BaselineStart;BaselineEnd;cb_SubtractBaseline;Width;menu_SortOutput;OutputName;cb_SaveToParentFolder;"
			break
		case "Minimum":
			visibleList += "StartTime;EndTime;BaselineStart;BaselineEnd;cb_SubtractBaseline;Width;menu_SortOutput;OutputName;cb_SaveToParentFolder;"
			break
		case "Area":
			visibleList += "StartTime;EndTime;BaselineStart;BaselineEnd;cb_SubtractBaseline;menu_SortOutput;cb_SaveToParentFolder;"
			break
		case "# Spikes":
			visibleList += "StartTime;EndTime;Threshold;menu_SortOutput;cb_SaveToParentFolder;"
			break
		default:
			visibleList += "StartTime;EndTime;menu_SortOutput;cb_SaveToParentFolder;"
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
		String title = getParam("PARAM_" + whichParam + "_TITLE",theFunction)
		
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
					
					CheckBox/Z $ctrlName win=NTP#Func,pos={left+65,top},align=1,size={90,20},bodywidth=50,fsize=fontSize,font=$LIGHT,side=1,title=title,value=valueNum,disable=0,proc=ntExtParamCheckProc
				Else
					SetVariable/Z $ctrlName win=NTP#Func,pos={left+125,top-2},align=1,size={90,20},fsize=fontSize,font=$LIGHT,bodywidth=75,title=title,value=_NUM:valueNum,disable=0,proc=ntExtParamProc
					
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
					PopUpMenu/Z $ctrlName win=NTP#Func,pos={left+200,top},align=1,size={185,20},fsize=fontSize,font=$LIGHT,bodywidth=150,title=title,value=#itemStr,disable=0,proc=$theProc	
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
					DrawText/W=NTP#Func V_left - 5,V_top + 10,title
					SetDrawEnv/W=NTP#Func gname=$("DSNameLabel" + whichParam),gstop
				
				ElseIf(stringmatch(name,"CDF_*"))
					//Current Data Folder Waves Menu
					selection = getParam("PARAM_" + whichParam + "_VALUE",theFunction)
					selectionIndex = WhichListItem(selection,DSNameList,";")
					
					If(selectionIndex == -1)
						selectionIndex = 0
					EndIf
					
					PopUpMenu/Z $ctrlName win=NTP#Func,pos={left,top},size={185,20},font=$LIGHT,fsize=fontSize,bodywidth=150,title=title,value=WaveList("*",";",""),disable=0,mode=1,popValue=selection,proc=ntExtParamPopProc
				Else
					SetVariable/Z $ctrlName win=NTP#Func,pos={left+200,top},align=1,size={190,20},fsize=fontSize,font=$LIGHT,bodywidth=150,title=title,value=_STR:valueStr,disable=0,proc=ntExtParamProc
				EndIf
				
				break
			case "16386"://wave
				valueStr = getParam("PARAM_" + whichParam + "_VALUE",theFunction)
				//this will convert a wave path to a wave reference pointer
				SetVariable/Z $ctrlName win=NTP#Func,pos={left,top},size={140,20},fsize=fontSize,font=$LIGHT,bodywidth=100,title=title,value=_STR:valueStr,disable=0,proc=ntExtParamProc
				
				//confirm validity of the wave reference
				validWaveText("",0,deleteText=1,parentCtrl=ctrlName)
				ControlInfo/W=NTP#Func $ctrlName
				validWaveText(valueStr,V_top+13,parentCtrl=ctrlName)
				
				break
			case "4608"://structure
				top -= 25 //reset back				
				break
		endswitch
		top += 25
		
	EndFor
	
	
End


Function LoadTimeStampsButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	DFREF NPD = $DSF
	DFREF NPC = $CW
	
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			
			//Get the name of the parameter
			ControlInfo/W=NTP#Func $ba.ctrlName
			String ctrlName = S_Title
			
			strswitch(ctrlName)
				case "Browse Files":
					//browse files on disk for wavesurfer loading
				
					//What file type are we opening?
					String fileType = getParam2("menu_FileType","VALUE","NT_LoadStimulusTimeStamps")
					
					BrowseEphys(fileType)
					break
			endswitch
			
			break	
		case -1: // control being killed
			break
	endswitch

	return 0
	
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
				case "Browse Files":
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
//Function NT_GetDataTableChannels(menu_DataTable,menu_Rows,StartRow,EndRow,bt_Open)
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

//Function NT_LoadEphysTable(menu_DataTable,menu_Rows,StartRow,EndRow,bt_Open)
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

Function NT_LoadStimulusTimeStamps(menu_FileType,bt_BrowseFiles,lb_FileList,lb_SweepList)
	//TITLE=Load TimeStamps
	//SUBMENU=Load Data
	
//	Note={
//	Loads time stamp data
//	}
	String menu_FileType,bt_BrowseFiles,lb_FileList,lb_SweepList
	
	//title designations
	String menu_FileType_Title = "File Type"
	String bt_BrowseFiles_Title = "Browse Files"
	
	String menu_FileType_List = "ScanImage;WaveSurfer;TurnTable;"//;Presentinator;
	String bt_BrowseFiles_Proc = "LoadTimeStampsButtonProc"
	
	String lb_FileList_Pos = "-20;10;200;350" //left,top,width,height
	String lb_FileList_ListWave = "root:Packages:NeuroToolsPlus:ControlWaves:wsFileListWave"
	String lb_FileList_SelWave = "root:Packages:NeuroToolsPlus:ControlWaves:wsFileSelWave"
	String lb_FileList_Proc = "LoadEphysListBoxProc"
	
	String lb_SweepList_Pos = "190;10;200;350"
	String lb_SweepList_ListWave = "root:Packages:NeuroToolsPlus:ControlWaves:sweepListWave"
	String lb_SweepList_SelWave = "root:Packages:NeuroToolsPlus:ControlWaves:sweepSelWave"
	
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
		case "ScanImage":
			print filePathList
			break
		case "WaveSurfer":
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
			print seriesList
			break
	endswitch
	
End


Function LoadEphys2()
	//Press Run to initialize the loader control table
	String EL = "EphysLoader"
	
	//Control waves folder in the NeuroTools package
	DFREF NTF = $CW
	
	//Browse a folder
	NewPath/O/Q/Z ephysPath
	
	//Operation cancelled or failed
	If(V_flag)
		return 0
	EndIf
	
	//Get the files in the path if they are of the accepted types:
		//PClamp (.abf)
		//WaveSurfer (.h5)
		//Turntable (.h5)
	String extensionList = ".abf;.h5;"
	String fileList = ""
	
	Variable i
	For(i=0;i<ItemsInList(extensionList,";");i+=1)
		String ext = StringFromList(i,extensionList,";")
		String list = IndexedFile(ephysPath,-1,ext)
		fileList += list //add to master list
	EndFor
	
	//Create a text wave to hold the file names
//	Make/O/T/N=(
	
	//Open the control panel
	KillWindow/Z $EL
	NewPanel/N=$EL/W=(0,0,600,400)/K=1 as "Electrophysiology Loader"
	
	//Define guide lines for the control area and table area
	DefineGuide/W=$EL controlGuide = {FT,30}
	DefineGuide/W=$EL leftGuide = {FL,120}
	
	//Create a table to hold the ephys file information
	Make/O/N=(4,9)/T NTF:EphysLoaderTable/Wave=ELTable
	
	//Append the table to the panel
	NewPanel/HOST=$EL/N=Data/FG=(leftGuide,controlGuide,FR,FB)
	Edit/HOST=$EL#Data/W=(0,0,1,1)/N=Table ELTable
	
	//Set the dimension labels on the table
	String dimList = "Path;Pos_0;Pos_1;Pos_2;Pos_3;Pos_4;Pos_5;Channels;Type;"
	For(i=0;i<ItemsInList(dimList,";");i+=1)
		SetDimLabel 1,i,$StringFromList(i,dimList,";"),ELTable
	EndFor
	
	//Show only the horizontal dimension labels
	ModifyTable/W=$EL#Data#Table horizontalIndex=2
	
End

Function NT_LoadEphys(menu_FileType,bt_BrowseFiles,menu_Channels,lb_FileList,lb_SweepList)
	//TITLE=Load Ephys
	//SUBMENU=Load Data
	
//	Note={
//	Loads different types of electrophysiology data. Choose the file type from the menu, 
//	browse to the folder that contains the data. Select and load.  
//	}
	
	String menu_FileType,bt_BrowseFiles,menu_Channels,lb_FileList,lb_SweepList//,menu_NameByStimulus
	
	//title designations
	String menu_FileType_Title = "File Type"
	String bt_BrowseFiles_Title = "Browse Files"
//	String menu_NameByStimulus_Title = "Name By Stimulus"
	
	String menu_FileType_List = "WaveSurfer;PClamp;TurnTable"//;Presentinator;
	String bt_BrowseFiles_Proc = "LoadEphysButtonProc"
	
	String menu_Channels_List = "1;2;All;"
	
	String lb_FileList_Pos = "-20;10;200;350" //left,top,width,height
	String lb_FileList_ListWave = "root:Packages:NeuroToolsPlus:ControlWaves:wsFileListWave"
	String lb_FileList_SelWave = "root:Packages:NeuroToolsPlus:ControlWaves:wsFileSelWave"
	String lb_FileList_Proc = "LoadEphysListBoxProc"
	
	String lb_SweepList_Pos = "190;10;200;350"
	String lb_SweepList_ListWave = "root:Packages:NeuroToolsPlus:ControlWaves:sweepListWave"
	String lb_SweepList_SelWave = "root:Packages:NeuroToolsPlus:ControlWaves:sweepSelWave"
	
//	String menu_NameByStimulus_List = "None;angle;speed;driftFreq;trajectory;diameter;length;width;orientation;spatialFreq;spatialPhase;modulationFreq;contrast;xPos;yPos;"
//	String menu_NameByStimulus_Pos = "80;530;"
	
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
			Load_WaveSurfer(filePathList,channels=menu_Channels)
			break
		case "Presentinator":
//			LoadPresentinator(filePathList)
			break
		case "TurnTable":
			//Get the selected series
			String seriesList = ""
			For(i=0;i<DimSize(sweepListWave,0);i+=1)
				If(sweepSelWave[i] > 0)
					seriesList += StringFromList(0,sweepListWave[i],"/") + ","
				EndIf
			EndFor
			
			//no selection, load all of them
			If(sum(sweepSelWave) == 0)
				seriesList = ""
				For(i=0;i<DimSize(sweepListWave,0);i+=1)
					seriesList += StringFromList(0,sweepListWave[i],"/") + ","
				EndFor
			EndIf
			
			LoadTurnTable(filePathList,seriesList,"")
			break
	endswitch
	
End

Function LoadTurnTable(filePathList,seriesList,channelList,[archive,dti])
	String filePathList,seriesList,channelList
	Wave/T archive //possible data table archive
	Variable dti //dti must be provided if archive is given, otherwise archive will be ignored
	
	
	DFREF saveDF = GetDataFolderDFR()
	
	Variable i,j,fileID,numSeries = ItemsInList(seriesList,",")
	
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
	
	//If no series are specified, load all of them.
	If(numSeries == 0)
		seriesList = TT_GetSeriesList(fileID,",")
		numSeries = ItemsInList(seriesList,",")
		
		DoAlert/T="Loading Data" 1,"Are you sure you want to load all of the data in the file?"
		
		If(V_flag == 2)
			return 0
		EndIf
		
	EndIf
	
	seriesList = ResolveListItems(seriesList,",")
	
	//If its a data archive, make sure each series number has the same number of sweeps
	//Otherwise the data table line is invalid, bc we can't define a data set with different sweep numbers.
	If(WaveExists(archive))
		String sweepNumList = TT_GetSweepNumbers(fileID,seriesList)
		
		String baseNum = StringFromList(0,sweepNumList,";")
		For(i=1;i<ItemsInList(sweepNumList,";");i+=1)
			
			If(cmpstr(baseNum,StringFromList(i,sweepNumList,";")))
				DoAlert/T="Data Table Error" 0,"Cannot have series numbers with different numbers of sweeps. Please define each series on a different data table line."
				return 0
			EndIf
		EndFor
	EndIf
	
	String protocolList = TT_GetProtocolList(fileID)
	
	//load each channel in the selected series
	For(i=0;i<numSeries;i+=1)
		String series = StringFromList(i,seriesList,",")
		String sweepList = TT_GetSweepList(fileID,series,",")
		String unitsList = TT_GetSeriesUnits(fileID,series)
		String scaleList = TT_GetSeriesScale(fileID,series)
		String channels = TT_GetChannelList(fileID,series)
		
		String protocol = StringFromList(str2num(series) - 1,protocolList,";")
		
		
//		
		
		//RESOLVE WAVE NAMES FROM OPTIONAL DATA TABLE
		If(WaveExists(archive) && !numtype(dti))
			//Resolve the SWEEP names being used for the loaded data.
			String archiveSweepList = archive[dti][%Pos_3]
			String sweepListTemp = ResolveListItems(sweepList,",")
			String archiveSweepListTemp = ResolveListItems(archiveSweepList,",")
			
			If(ItemsInList(sweepListTemp,",") == ItemsInList(archiveSweepListTemp,","))
				//Use the archive tables sweep list for naming the input waves if they have the same number of sweeps
				String sweepListNames = archiveSweepListTemp 
			Else
				//if invalid entry, use the files actual sweep list and insert it into the archive table
				archive[dti][%Pos_3] = ListToRange(sweepList,",") 
				sweepListNames = sweepList
			EndIf		
			
			archive[dti][%Comment] = protocol
			//SERIES
			
			//from the optional 'Trials' input, which is used if you want to auto rename the loaded data waves from Pos_2 input
			seriesList = archive[dti][%Trials]
			String seriesListNames = seriesList

			If(!strlen(seriesList))
				seriesList = archive[dti][%Pos_2]
				seriesList = ResolveListItems(seriesList,",")
				seriesListNames = seriesList
			Else
				String seriesListTemp = ResolveListItems(seriesList,",")
				seriesList = seriesListTemp
				seriesListNames = seriesList
				
				String archiveSeriesList = archive[dti][%Pos_2]
				archiveSeriesList = ResolveListItems(archiveSeriesList,",")

				//Trials input, but no rename in the Pos_2 input
				If(!strlen(archiveSeriesList))
					archiveSeriesList = seriesListTemp
					archive[dti][%Pos_2] = archive[dti][%Trials]
					
				Else
					//Rename input in Pos_2
					
					//Ensure same number of items, else abort the rename
					String archiveSeriesListTemp = ResolveListItems(archiveSeriesList,",")
					If(ItemsInList(seriesList,",") == ItemsInList(archiveSeriesListTemp,","))
						//Use the archive tables sweep list for naming the input waves if they have the same number of sweeps
						seriesListNames = archiveSeriesListTemp 
					Else
						//invalid rename items, abort the rename, use the series numbers from the file
						archive[dti][%Pos_2] = ListToRange(seriesList,",") 
					 	seriesListNames = archive[dti][%Pos_2]
					 	seriesListNames = ResolveListItems(seriesListNames,",")
					EndIf
				EndIf
				
			EndIf
		Else
			sweepListNames = sweepList	
			seriesListNames = 	seriesList		
		EndIf
		
		Variable nSweeps = ItemsInList(sweepList,",")
		For(j=0;j<nSweeps;j+=1)
			String sweep = StringFromList(j,sweepList,",")
			String sweepName = StringFromList(j,sweepListNames,",")
			String seriesName = StringFromList(i,seriesListNames,",")
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
			
			//Possible rename on the prefix
			If(WaveExists(archive) && !numtype(dti))
				If(!strlen(archive[dti][%Pos_0]))
					archive[dti][%Pos_0] = prefix
				Else
					prefix = archive[dti][%Pos_0]
				EndIf
			EndIf
			
			//GROUP
			If(WaveExists(archive) && !numtype(dti))
				//Possible rename on the prefix
				String group = archive[dti][%Pos_1]
				
				If(!strlen(group))
					group = "1"
					archive[dti][%Pos_1] = group
				EndIf
			Else
				group = "1"
			EndIf
			
			Variable c,nChannels
			
			//Ensure valid channel list
			If(!strlen(channelList))
				channelList = channels
			Else
			
				If(WaveExists(archive) && numtype(dti) == 0 && j == 0 && i == 0)
					archive[dti][%Channels] = "" //reset this, will refill after loading
				EndIf
				
				//make sure channelList has valid recorded channels in it
				For(c=0;c<ItemsInList(channelList,";");c+=1)
					If(WhichListItem(StringFromList(c,channelList,";"),channels,";") == -1)
						channelList = RemoveListItem(c,channelList,";")
						print StringFromList(c,channelList,";") + " is not a valid channel for series number " + series
					EndIf
				EndFor
			EndIf
						
			//Generate the wave name for the channel and load the data into a wave
			For(c=0;c<ItemsInList(channelList,";");c+=1)
				String ch = StringFromList(c,channelList,";")
				
				
				//Insert the recorded channels back into the data table archive, if it was provided as an input
				If(WaveExists(archive) && numtype(dti) == 0 && j == 0 && i == 0) //only on first sweep of first series in the list
					archive[dti][%Channels] += ch	 + ","
					archive[dti][%IgorPath] = RemoveEnding(destFolder,":") + ":"
					
					If(!strlen(archive[dti][%Pos_4]))
						archive[dti][%Pos_4] = ch
						String chName = ch
					Else
						chName = archive[dti][%Pos_4]
					EndIf
				Else
					chName = ch
				EndIf
				
				String dataName = prefix + "_" + group + "_" + seriesName + "_" + sweepName + "_" + chName
				
				HDF5LoadData/O/TYPE=2/Q/N=$dataName fileID,"/Data/" + series + "/Ch" + ch + "/" + sweep
				
				Wave d = $dataName
			
				//Scale the data
				SetScale/P x,0,str2num(scale),"s",d
				SetScale/P y,0,1,unit,d
				
				Note/K d,"FILE: " + file
				Note d,"PROTOCOL: " + protocol
				Note d,"SERIES: " + series
				Note d,"SWEEP: " + sweep
				Note d,"CHANNEL: " + ch
			EndFor
		EndFor
		
		//Clean up the channels column in the data archive
		If(WaveExists(archive) && numtype(dti) == 0)
			archive[dti][%Channels] = ListToRange(archive[dti][%Channels],",")	
		EndIf
		
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
	
//	Duplicate/FREE theWave,temp
	
//	FlattenWave(temp)
	
	FindLevels/Q/D=spktm/R=(StartTime,EndTime)/M=0.002/T=0.0005 theWave,threshold

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

Function/Wave OrientationVectorSum(Tuning,Angles,[separator])
	//Returns the vector sum of the input tuning curve and associated statistics
	//180° orientation data only
	
	Wave Tuning
	String Angles
	String separator
	
	If(ParamIsDefault(separator))
		separator = ";"
	EndIf
	
	Variable i,size = DimSize(Tuning,0)
	
	If(ItemsInList(Angles,separator) != size)
		return $"" //angle list must be the same length as the input wave
	EndIf
		
	Variable vSumX,vSumY,totalSignal
	
	vSumX = 0
	vSumY = 0
	totalSignal = 0
	
	For(i=0;i<size;i+=1)
		If(numtype(Tuning[i]) == 2) //protects against NaNs, returns -9999, invalid
			return $""
		EndIf
		
		Variable theAngle = str2num(StringFromList(i,angles,separator))
		
		vSumX += Tuning[i]*cos(theAngle*pi/90)
		
		vSumY += Tuning[i]*sin(theAngle*pi/90)
		totalSignal += Tuning[i] //double contribution, one for each 180° pair of angles
	EndFor
	
	Variable vRadius = sqrt(vSumX^2 + vSumY^2)
	Variable vAngle = atan2(vSumY,vSumX)*90/pi
	Variable OSI = vRadius/totalSignal
	Variable SNR = vRadius
	
	If(vAngle < 0)
		vAngle +=360
	Endif
	
	//Turn off the debugger in case it's on, so the try-catch doesn't trigger an interupt
	DebuggerOptions debugOnError = 0
	
	//Fit a gaussian to the tuning curve to get the FWHM
	try
		CurveFit/Q gauss, Tuning/D ;AbortOnRTE
		Wave coef = :W_coef
		Variable FWHM = coef[3]
	catch
		//Fitting error
		Variable error = GetRTError(1)
		FWHM = nan
	endtry
	
	//von mises distribution kappa parameter is useful as a tuning width measurement, probably better than FWHM from a gaussian fit
	//because it takes into account the baseline minimum of the tuning curve
	//Fit a von mises distribution to the tuning curve to get the kappa value
	try
		Wave coef = :W_coef
		Redimension/N=3 coef
		coef[0] = {-500,1,WaveMax(Tuning)} //initial guesses for the fit (mu, kappa, peak)
		FuncFit/Q NT_vonMises coef Tuning/D ;AbortOnRTE
		
		Variable kappa = coef[1]
	catch
		//Fitting error
		error = GetRTError(1)
		kappa = nan
	endtry
	
	Make/N=5/O $(GetWavesDataFolder(Tuning,2) + "_VectorSum")  /Wave=VSData
	
	VSData[0] = vAngle
	VSData[1] = OSI
	VSData[2] = vRadius
	VSData[3] = FWHM
	VSData[4] = Kappa 
	
	//Sets dimension labels
	SetDimLabel 0,0,Angle,VSData
	SetDimLabel 0,1,OSI,VSData
	SetDimLabel 0,2,Resultant,VSData
	SetDimLabel 0,3,FWHM,VSData
	SetDimLabel 0,4,Kappa,VSData
	
	return VSData
	
End


Function/Wave VectorSum2(Wave theWave,String angles,[String separator])
	//Returns the vector sum of the input tuning curve and associated statistics
	//360° directional data only
	
	If(ParamIsDefault(separator))
		separator = ";"
	EndIf
	
	Variable i,size = DimSize(theWave,0)
	
	If(ItemsInList(angles,separator) != size)
		return $"" //angle list must be the same length as the input wave
	EndIf
	
	Variable vSumX,vSumY,totalSignal
	
	vSumX = 0
	vSumY = 0
	totalSignal = 0

	For(i=0;i<size;i+=1)
		If(numtype(theWave[i]) == 2) //protects against NaNs, returns -9999, invalid
			return $""
		EndIf
		
		Variable theAngle = str2num(StringFromList(i,angles,separator))
		
		vSumX += theWave[i]*cos(theAngle*pi/180)
		vSumY += theWave[i]*sin(theAngle*pi/180)
		totalSignal += theWave[i]
	EndFor
	
	Variable vRadius = sqrt(vSumX^2 + vSumY^2)
	Variable vAngle = atan2(vSumY,vSumX)*180/pi
	Variable DSI = vRadius/totalSignal
	Variable SNR = vRadius
	
	If(vAngle < 0)
		vAngle +=360
	Endif
	
	//Turn off the debugger in case it's on, so the try-catch doesn't trigger an interupt
	DebuggerOptions debugOnError = 0
	
	//Fit a gaussian to the tuning curve to get the FWHM
	try
		CurveFit/Q gauss, theWave/D ;AbortOnRTE
		Wave coef = :W_coef
		Variable FWHM = coef[3]
	catch
		//Fitting error
		Variable error = GetRTError(1)
		FWHM = nan
	endtry
	
	//von mises distribution kappa parameter is useful as a tuning width measurement, probably better than FWHM from a gaussian fit
	//because it takes into account the baseline minimum of the tuning curve
	//Fit a von mises distribution to the tuning curve to get the kappa value
	try
		Wave coef = :W_coef
		Redimension/N=3 coef
		coef[0] = {-500,1,WaveMax(theWave)} //initial guesses for the fit (mu, kappa, peak)
		FuncFit/Q NT_vonMises coef theWave/D ;AbortOnRTE
		
		Variable kappa = coef[1]
	catch
		//Fitting error
		error = GetRTError(1)
		kappa = nan
	endtry
	
	Make/N=5/O $(GetWavesDataFolder(theWave,2) + "_VectorSum")  /Wave=VSData
	
	VSData[0] = vAngle
	VSData[1] = DSI
	VSData[2] = vRadius
	VSData[3] = FWHM
	VSData[4] = Kappa 
	
	//Sets dimension labels
	SetDimLabel 0,0,Angle,VSData
	SetDimLabel 0,1,DSI,VSData
	SetDimLabel 0,2,Resultant,VSData
	SetDimLabel 0,3,FWHM,VSData
	SetDimLabel 0,4,Kappa,VSData
	
	return VSData
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
	//SUBGROUP=Waves
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
	//SUBGROUP=Waves
	String DS_Waves
	
	STRUCT ds ds
	GetStruct(ds)
	
	DFREF NPC = $CW
	Variable/G NPC:totalSize
	NVAR totalSize = NPC:totalSize
		
	If(ds.wsn == 0)
		totalSize = 0
	EndIf
	
	Variable i
	For(i=0;i<ds.numWaves[0];i+=1)
		Wave theWave = ds.waves[i]
		String info = WaveInfo(theWave,0)
		totalSize += str2num(StringByKey("SIZEINBYTES",info))
		
		
		ReallyKillWaves(theWave)
		
		ds.wsi += 1
	EndFor
	
	//print out the total size of the deleted waves after killing the waves.
	//print on last wave set
	If(ds.wsn == ds.numWaveSets[0]-1)
		print "Deleted:", totalSize / (1e6),"MB"
	EndIf
End


Function NT_SplitWave(DS_Waves,BaseName,nWaves)
	//SUBMENU=Waves and Folders
	//TITLE=Split Wave
	//SUBGROUP=Waves
	
//	Note={
//	Takes a single wave and splits it into any number of subwaves.
//	
//	Useful if multiple data trials were taken in a single acquisition.
//	
//	\f01Base Name\f00 : Base name of the output waves
//	\f01# Waves\f00 : Number of waves to split the input wave into
//	}
	
	String DS_Waves
	String BaseName
	Variable nWaves //number of output waves to split to
	
	String BaseName_Title = "Base Name"
	String nWaves_Title = "# Waves"
	
	STRUCT ds ds
	GetStruct(ds)
	
	Variable i,j
	
	For(i=0;i<ds.numWaves[%Waves];i+=1)
		Wave w = ds.waves[i][%Waves]
		SetDataFolder GetWavesDataFolderDFR(w)
		
		Variable size = DimSize(w,0)
		
		Variable nPoints = floor(size / nWaves)
		
		Variable startPt = 0
		
		For(j=0;j<nWaves;j+=1)
			String outputName = BaseName + "_" + num2str(j)
			Make/O/N=(nPoints) $outputName/Wave=out
			
			out = w[startPt + p]
			
			SetScale/P x,DimOffset(w,0),DimDelta(w,0),out
			
			startPt += nPoints
		EndFor
		
	EndFor
End

Function NT_SetDimensionLabel(DS_Waves,WhichDimension,LabelList)
	//TITLE = Set Dimension Labels
	//SUBMENU = Waves and Folders
	String DS_Waves
	Variable WhichDimension
	String LabelList
	
	STRUCT ds ds
	GetStruct(ds)
	
//	Note={
//	Sets the dimension labels of the input waves.
//	The number of points in the wave must equal the number of labels.
//	
//	\f01Dimension\f00 : Dimension to label
//	\f01Labels\f00 : Comma-separated list of labels
//	}
	
	Variable i,j
	For(i=0;i<ds.numWaves[%Waves];i+=1)
		Wave w = ds.waves[i][%Waves]
		
		If(ItemsInList(LabelList,",") != DimSize(w,WhichDimension))
			continue
			print "Number of labels must equal the number of data points in the specified dimension."
		EndIf
		
		For(j=0;j<ItemsInList(LabelList,",");j+=1)
			String theLabel = StringFromList(j,LabelList,",")
			
			SetDimLabel WhichDimension,j,$theLabel,w
		EndFor		
	EndFor
	
End

//Concatenates each wave in a waveset together into a single output wave
Function NT_Concatenate(DS_Waves,OutputFolder,Suffix)
	//SUBMENU=Waves and Folders
	//SUBGROUP=Waves
	String DS_Waves //input waves contain angular data
	String OutputFolder //name of the output folder, full path or relative path
	String Suffix //suffix applied to end of first wave in the wave set as the output wave name
	
//	Note={
//	Concatenates each wave in a waveset together into a single output wave
//	}

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


//Generates a scatter plot with connected paired points
//Requires a 2D matrix wave, with each column containing pairs of points
Function NT_ScatterPlot(Control,Test,cb_Paired)
	Wave Control,Test
	Variable cb_Paired
	
	//SUBMENU=Graphing
	//TITLE=Paired Scatter Plot
	
//	Note={
//	Generates a scatter plot with connected paired points
//	Input control data set and a test data set.
// Control and Test must have same number of points
//	}

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
	
	If(cb_Paired)
		Variable mode = 4
	Else
		mode = 3
	EndIf
		
	ModifyGraph mode=(mode),marker=8,msize=3,rgb=(0,0,0),lsize=0.5,opaque=1,btLen=2,btThick=0
	ModifyGraph axThick=0.5,axThick(bottom)=0.5,standoff(bottom)=0,manTick(left)={0,0.1,0,1},manMinor(left)={0,0},manTick(bottom)={0,1,0,0},manMinor(bottom)={0,0}
	ModifyGraph margin(left)=28,margin(bottom)=28,margin(right)=7,margin(top)=7,gfSize=8,standoff=0,ZisZ(left)=1
	SetAxis bottom -0.25,1.25
	

	//Average and SDev wavess
	
	SetDataFolder GetWavesDataFolderDFR(Control)
	Make/N=1/O $(NameOfWave(Control) + "_avg")/Wave=avg
	Make/N=1/O $(NameOfWave(Control) + "_sdev")/Wave=sdev

	WaveStats/Q Control
	avg = V_avg
	sdev = V_sdev
	
	SetDataFolder GetWavesDataFolderDFR(Test)
	Make/N=1/O $(NameOfWave(Test) + "_avg")/Wave=avg
	Make/N=1/O $(NameOfWave(Test) + "_sdev")/Wave=sdev
	
	WaveStats/Q Test
	avg = V_avg
	sdev = V_sdev
	
	SetScale/P x,0.999,1.001,avg
	
End

Function/Wave ColorTableAlpha(ColorTable,alpha)
	//creates a duplicate of a standard Igor color table, but with transparency
	String ColorTable
	Variable alpha
	
	DFREF saveDF = GetDataFolderDFR()
	
	If(alpha > 1)
		print "Transparency must be set to between 0 and 1"
		return $""
	EndIf
	
	//percentage alpha
	If(alpha <= 1)
		alpha = round(0xffff * alpha)
	EndIf
	
	If(!DataFolderExists("root:Packages:NeuroToolsPlus:CustomColors"))
		NewDataFolder root:Packages:NeuroToolsPlus:CustomColors
	EndIf
		
	DFREF cc = root:Packages:NeuroToolsPlus:CustomColors
	SetDataFolder cc
	
	ColorTab2Wave $ColorTable
	Wave colorTab = :M_colors
	
	Duplicate/O colorTab,$(ColorTable +  "_" + num2str(alpha))
	Wave colorTab = $(ColorTable +  "_" + num2str(alpha))
	
	Redimension/N=(-1,4) colorTab
	
	colorTab[][3] = alpha
	
	KillWaves/Z M_colors
	
	SetDataFolder saveDF
	
	return colorTab
End


//Generates a custom color table for a green to magenta fade
Function/WAVE NT_CustomColorTable(menu_firstColor,menu_secondColor,alpha)
	//SUBMENU=Graphing
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
		String alphaStr = num2str(alpha * 100)
		alpha = round(0xffff * alpha)
	EndIf
	
	
	DFREF saveDF = GetDataFolderDFR()
	
	If(!DataFolderExists("root:Packages:NeuroToolsPlus:CustomColors"))
		NewDataFolder root:Packages:NeuroToolsPlus:CustomColors
	EndIf
		
	DFREF cc = root:Packages:NeuroToolsPlus:CustomColors
	SetDataFolder cc
	
	Make/U/W/O/N=(256,4) cc:$(menu_firstColor + menu_secondcolor + "_" + alphaStr)/Wave = color
	
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
	
	return color
End

Function copyTable()

	Wave/T test = root:test
	
	Make/O/T/N=(DimSize(test,0),DimSize(test,1) * 2) root:copy/Wave=copy
	copy = ""
	copy[][1,33;2] = test[p][floor(q/2)]
	

End