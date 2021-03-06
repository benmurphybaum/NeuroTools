﻿#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//Command functions that are built into NeuroTools

//RUN COMMAND MASTER FUNCTION
Function RunCmd(cmd)
	String cmd
	DFREF NTF = root:Packages:NT
	
	//Initialize data set info structure
	STRUCT ds ds
	
	//Make sure a timer is available
	ResetAllTimers()
	
	//Save data folder
	DFREF saveDF = $GetDataFolder(1)
	
	//Special treatment for some functions that may not use any data sets
	strswitch(cmd)
		case "Run Cmd Line":
			NT_RunCmdLine()
			
			//Check that the contents exist, if not, grey them out
			CheckDataSetWaves()
			return 0
		case "New Data Folder":
			NT_NewDataFolder()
			return 0
		case "Kill Data Folder":	
			NT_KillDataFolder()
			return 0
		case "External Function":
			//Get the data set info
			Variable error = GetDataSetInfo(ds,extFunc=1)
			break
		case "Max Project":
			error = GetDataSetInfo(ds)
			break
		case "Load Ephys":
			NT_LoadEphys()
			
			return 0
			break
		case "Load WaveSurfer":
//			SVAR wsFilePath = NTF:wsFilePath
//			SVAR wsFileName = NTF:wsFileName
//			ControlInfo/W=NT ChannelSelector
//			
//			Wave/T wsFileListWave = NTF:wsFileListWave
//			Wave wsFileSelWave = NTF:wsFileSelWave
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
			SVAR wsFilePath = NTF:wsFilePath
			SVAR wsFileName = NTF:wsFileName
			ControlInfo/W=NT ChannelSelector
			
			Wave/T wsFileListWave = NTF:wsFileListWave
			Wave wsFileSelWave = NTF:wsFileSelWave
			
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
			error = GetDataSetInfo(ds)
	endswitch
	
	
	
	If(error == -1 || DimSize(ds.waves,0) == 0)
		//reserved, doesn't break bc data sets aren't required necessarily
		If(cmpstr(cmd, "External Function")) 
			//No waves or other error
			return 0
		EndIf
	EndIf
	
	//Get the workflow structure
//	STRUCT workflow wf
//	GetWorkFlow(wf)
	
	//Start a timer
	Variable ref = StartMSTimer
	
	//WSN loop
	Do
		//Get the waves in the current WSN
		ds.paths = GetWaveSetList(ds.listWave,ds.wsn,1)
		Wave/WAVE ds.waves = GetWaveSetRefs(ds.listWave,ds.wsn)
		
		ds.numWaves = ItemsInList(ds.paths,";")
		
		//Execute the function returns optional output waves
//		Do
			//Run the next command in the workflow
//			Wave/WAVE out = ExecuteCommand(ds,wf.cmds[wf.i])
			
	
		Wave/WAVE out = ExecuteCommand(ds,cmd)
		
			
			//Re-build the ds structure according to the output from the previous command
			
//			wf.i += 1
//		While(wf.i < wf.numCmds)
		
		//Increment to the next WSN
		ds.wsn += 1
		
		//Reset the WSI
		ds.wsi = 0
	While(ds.wsn < ds.num)
	
	//Make progress bar invisible
	ValDisplay progress win=NT,disable=1
	
	//End the timer
	print cmd + ":",StopMSTimer(ref)/(1e6),"s"
	
	//Return to original data folder
	SetDataFolder saveDF
	
	//Check data set wave existence in case waves were deleted or renamed during execution
	CheckDataSetWaves()
	
	//Update the folders and wave listWaves
	getFolders()
	getFolderWaves()
	
End

//Takes a Command string, executes the corresponding function
Function/WAVE ExecuteCommand(ds,cmd)
	STRUCT ds &ds
	String cmd
	
	strswitch(cmd)
		case "Average":
			NT_Average(ds)
			Wave/WAVE out = $""
			break
		case "Errors":
			NT_Error(ds)
			Wave/WAVE out = $""
			break
		case "Measure":
			NT_Measure(ds)
			Wave/WAVE out = $""
			break
		case "Set Wave Note":
			NT_SetWaveNote(ds)
			Wave/WAVE out = $""
			break
		case "PSTH":
			NT_PSTH(ds)
			Wave/WAVE out = $""
			break
		case "Subtract Mean":
			NT_SubtractMean(ds)
			Wave/WAVE out = $""
			break
		case "Subtract Trend":
			NT_SubtractTrend(ds)
			Wave/WAVE out = $""
			break
		case "Duplicate Rename":
			NT_DuplicateRename(ds)
			Wave/WAVE out = $""
			break
		case "delSuffix":
			delSuffix(ds)
			Wave/WAVE out = $""
			break
		case "Move To Folder":
			NT_MoveToFolder(ds)
			Wave/WAVE out = $""
			break
		case "Run Cmd Line":
			NT_RunCmdLine()
			Wave/WAVE out = $""
			break
		case "Kill Waves":
			NT_KillWaves(ds)
			Wave/WAVE out = $""
			break
		case "New Data Folder":
			NT_NewDataFolder()
			Wave/WAVE out = $""
			break
		case "Kill Data Folder":
			NT_KillDataFolder()
			Wave/WAVE out = $""
			break
		case "External Function":
			String extCmd = CurrentExtFunc()
			
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

//Averages the waves
Function/WAVE NT_Average(ds[,pass])
	STRUCT ds &ds //data set info structure
	
	Variable pass //1 will output a free wave to pass to the calling function
					  //0 or no input will output a real wave
					  
	If(ParamIsDefault(pass))
		pass = 0
	EndIf
	
	//Reset wsi in case this function has been passed to
	ds.wsi = 0
	
	//Set the output data folder
	DFREF cdf = GetDataFolderDFR()
	
	//Which data folder should we put the output waves?
	ControlInfo/W=NT outFolder
	String folder = S_Value
	
	//If it's a full path folder
	If(stringmatch(folder,"root*"))
		Variable i = 0
		String sub = ""
		Do
			sub += ParseFilePath(0,folder,":",0,i) + ":"
			
			If(!DataFolderExists(sub))
				NewDataFolder $RemoveEnding(sub,":")
			EndIf
			
			i += 1
		While(i < ItemsInList(folder,":"))
		
		SetDataFolder folder
	Else
		If(strlen(folder))
			If(!DataFolderExists(GetWavesDataFolder(ds.waves[0],1) + folder))
				NewDataFolder $(GetWavesDataFolder(ds.waves[0],1) + folder)
			EndIf
		EndIf
		SetDataFolder GetWavesDataFolder(ds.waves[0],1) + folder
	EndIf
	
	
	//Make output wave for each wave set
	ControlInfo/W=NT replaceSuffixCheck
	V_Value = 0
	If(V_Value)
		String outputName = ReplaceSuffix(NameOfWave(ds.waves[0]),"avg")
	Else
		outputName = NameOfWave(ds.waves[0]) + "_avg"
	EndIf
	
	//What is the wave type?
	Variable type = WaveType(ds.waves[0])

	//Is this circular data?
	ControlInfo/W=NT polarCheck
	Variable isCircular = V_Value
	
	//Are we passing the result on?
	If(!pass)
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
	Else
		//Free wave to pass back to the calling function
		Make/FREE/N=(DimSize(ds.waves[0],0),DimSize(ds.waves[0],1),DimSize(ds.waves[0],2)) outWave
	EndIf
	
	//Reset outWave in case of overwrite
	outWave = 0
	
	//Set the scale of the output wave
	SetScale/P x,DimOffset(ds.waves[0],0),DimDelta(ds.waves[0],0),outWave
	SetScale/P y,DimOffset(ds.waves[0],1),DimDelta(ds.waves[0],1),outWave
	SetScale/P z,DimOffset(ds.waves[0],2),DimDelta(ds.waves[0],2),outWave
	
//	WSI loop
	//Do the average calculation
	String noteStr = "Average: " + num2str(ds.numWaves) + " Waves\r"
	
	If(isCircular)
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

			noteStr += StringFromList(ds.wsi,ds.paths,";") + "\r"
			
			updateProgress(ds)
			
			ds.wsi += 1
		While(ds.wsi < ds.numWaves)
		
		MatrixOP/O/FREE vMean = atan2(yTotal,xTotal)
		
		vMean = vMean * 180/pi
	
		//atan2 outputs data from -pi to +pi. We want it from 0 to +2pi.
		vMean = (vMean < 0) ? vMean + 360 : vMean
		
		outWave = vMean
	Else
		//Linear data
		Do
			Wave theWave = ds.waves[ds.wsi]
			Multithread outWave += theWave
			
			noteStr += StringFromList(ds.wsi,ds.paths,";") + "\r"
			
			updateProgress(ds)
			ds.wsi += 1
		While(ds.wsi < ds.numWaves)
		
		If(WaveType(outWave) > 7) //any type of integer
			Redimension/S outWave
		EndIf
		
		Multithread outWave /= ds.numWaves
	EndIf
		
	//Set the wave note
	Note/K outWave,noteStr
	
	//Reset data folder
	SetDataFolder cdf
	
	//pass the wave to the calling function
	If(pass)
		return outWave
	EndIf
End

//Gets the error of the waves - SEM or SDEV
Function/WAVE NT_Error(ds[,pass])
	Struct ds &ds
	Variable pass
	
	If(ParamIsDefault(pass))
		pass = 0
	EndIf
	
	//First get the averages
	Wave avg = NT_Average(ds,pass=1)
	
	//Failed to get the average
	If(!WaveExists(avg))
		return $""
	EndIf
	
	//Reset wsi in case this function has been passed to
	ds.wsi = 0
	
	//Set the output data folder
	DFREF cdf = GetDataFolderDFR()
	
	
	
	//Which data folder should we put the output waves?
	ControlInfo/W=NT outFolder
	String folder = S_Value
	
	//If it's a full path folder
	If(stringmatch(folder,"root*"))
		If(!DataFolderExists(folder))
			NewDataFolder $folder
		EndIf
		SetDataFolder folder
	Else
		If(strlen(folder))
			If(!DataFolderExists(GetWavesDataFolder(ds.waves[0],1) + folder))
				NewDataFolder $(GetWavesDataFolder(ds.waves[0],1) + folder)
			EndIf
		EndIf
		SetDataFolder GetWavesDataFolder(ds.waves[0],1) + folder
	EndIf

	
	ControlInfo/W=NT errType 
	String suffix = S_Value
		
	//Make output wave for each wave set
	ControlInfo/W=NT replaceSuffixCheck
	If(V_Value)
		String outputName = ReplaceSuffix(NameOfWave(ds.waves[0]),suffix)
	Else
		outputName = NameOfWave(ds.waves[0]) + "_" + suffix
	EndIf
	
	//Are we passing the result on?
	If(pass)
		//free wave
		Make/FREE/N=(DimSize(ds.waves[0],0),DimSize(ds.waves[0],1),DimSize(ds.waves[0],2)) outWave
	Else
		//real wave
		Make/O/N=(DimSize(ds.waves[0],0),DimSize(ds.waves[0],1),DimSize(ds.waves[0],2)) $outputName
		Wave outWave = $outputName
	EndIf
	
	//Reset outWave in case of overwrite
	outWave = 0
	
	//Do the error calculation
	String noteStr = "Errors: " + suffix + "(" + num2str(ds.numWaves) + " Waves)\r"
	Do
		Wave theWave = ds.waves[ds.wsi]
		outWave += (theWave - avg)^2
		noteStr += StringFromList(ds.wsi,ds.paths,";") + "\r"
		
		updateProgress(ds)
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves)
	
	//stdev
	outWave = sqrt(outWave / (ds.numWaves - 1))
	
	//sem
	If(!cmpstr(suffix,"sem"))
		//sem
		outWave /= sqrt(ds.numWaves)
	EndIf

	//Set the wave note
	Note/K outWave,noteStr
	
	//return to original data folder
	SetDataFolder cdf

	//pass the wave to the calling function
	If(pass)
		return outWave
	EndIf
End

//Sets the wave note for the waves
Function NT_SetWaveNote(ds[,noteStr,overwrite])
	Struct ds &ds
	
	//if the string is passed by a calling function
	//instead of from the Parameters panel
	String noteStr 
	Variable overwrite
	
	If(ParamIsDefault(noteStr))
		//get the note
		ControlInfo/W=NT waveNote
		noteStr = S_Value
	EndIf
		
	//overwrite?
	If(ParamIsDefault(overwrite))
		ControlInfo/W=NT overwriteNote
		overwrite = V_Value
	EndIf
		
	ds.wsi = 0
	
	//Set the wave note of the input waves
	Do
		If(overwrite)
			Note/K ds.waves[ds.wsi], noteStr
		Else
			Note ds.waves[ds.wsi], noteStr
		EndIf
		
		updateProgress(ds)
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves)
End


//inputs spike recording, outputs histograms
Function/WAVE NT_PSTH(ds)
	Struct ds &ds
	
	//Parameters
	ControlInfo/W=NT binSize
	Variable binSize = V_Value
	ControlInfo/W=NT spkThreshold
	Variable threshold = V_Value
	ControlInfo/W=NT histType
	String type = S_Value
	ControlInfo/W=NT outFolder
	String folder = S_Value
	ControlInfo/W=NT flattenWaveCheck
	Variable flatten = V_Value
	ControlInfo/W=NT startTmPSTH
	Variable startTm = V_Value
	ControlInfo/W=NT endTmPSTH
	Variable endTm = V_Value

	
	Variable i,j,numWaves,numBins
	
	SetDataFolder GetWavesDataFolder(ds.waves[0],1)
	
	//Check start and end time validity
	If(endTm == 0 || endTm < startTm)
		endTm = pnt2x(ds.waves[0],DimSize(ds.waves[0],0) -1)
	EndIf
	
	
	//Which data folder should we put the output waves?
	If(strlen(folder))
		If(!DataFolderExists(GetWavesDataFolder(ds.waves[0],1) + folder))
			NewDataFolder $(GetWavesDataFolder(ds.waves[0],1) + folder)
		EndIf
	EndIf
		
	SetDataFolder GetWavesDataFolder(ds.waves[0],1) + folder
	
	//Reset the wsi
	ds.wsi = 0
	Do
		Wave theWave = ds.waves[ds.wsi]
		
		//Remove low pass trends in the wave to flatten it
		If(flatten)
			FlattenWave(theWave)
		EndIf
		
		//Make Spike Count wave
		Make/FREE/N=(ds.numWaves) spkct
		
		//Get spike times and counts
		FindLevels/Q/EDGE=1/M=0.002/R=(startTm,endTm)/D=spktm theWave,threshold
		spkct[i] = V_LevelsFound
		
		//Gaussian or binned histograms
		strswitch(type)
			case "Binned":	
				numBins = floor((IndexToScale(theWave,DimSize(theWave,0)-1,0) - IndexToScale(theWave,0,0) )/ binSize) //number of bins in wave
				String histName = RemoveEnding(ReplaceListItem(0,NameOfWave(theWave),"_","PSTH"),"_")
				Make/O/N=(numBins) $histName
				Wave hist = $histName
				
				If(DimSize(spktm,0) == 0)
					hist = 0
				Else
					Histogram/C/B={pnt2x(theWave,0),binSize,numBins} spktm,hist
				EndIf
				
				hist /= binSize
				
				break
			case "Gaussian":
				Variable dT = DimDelta(theWave,0)
				Variable sampleRate = 1000 // 1 ms time resolution
				//gaussian template for convolution
				Make/O/N=(3*(binSize*sampleRate)+1) template
				Wave template = template
				SetScale/I x,-1.5*binSize,1.5*binSize,template
				template = exp((-x^2/(0.5*binSize)^2)/2)
				
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
				
				histName = RemoveEnding(ReplaceListItem(0,NameOfWave(theWave),"_","PSTH"),"_")
				Duplicate/O template,$histName
				Wave hist = $histName
				
				Convolve raster, hist
				hist *=1000
				
				break
		endswitch	
		
		//Cleanup
		KillWaves spktm,template
		
		//Set the wave note
		String noteStr = "PSTH:\r"
		noteStr += "Type: " + type + "\r"
		noteStr += "Threshold: " + num2str(threshold) + "\r"
		noteStr += "Bin Size: " + num2str(binSize) + "\r"
		noteStr += "StartTm: " + num2str(startTm) + "\r"
		noteStr += "EndTm: " + num2str(endTm) + "\r"
		
		Note/K hist,noteStr
		
		updateProgress(ds)
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves)
	
End

//Subtracts the overall average value from the wave
Function NT_SubtractMean(ds)
	STRUCT ds &ds
	
	ds.wsi = 0
	Do
		Wave theWave = ds.waves[ds.wsi]
		
		WaveStats/Q/M=1 theWave
		theWave -= V_avg
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves)
End

//Fits a low frequency trend to the data and subtracts it
Function NT_SubtractTrend(ds)
	STRUCT ds &ds
	
	ds.wsi = 0
	Do
		Wave theWave = ds.waves[ds.wsi]
		
		FlattenWave(theWave)
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves)
End

Function delSuffix(ds)
	STRUCT ds &ds
	
	ControlInfo/W=NT killOriginals
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
	While(ds.wsi < ds.numWaves)

	//Update the list boxes since we've just modified waves
		
	//Builds the match list according to all search terms, groupings, and filters
	getWaveMatchList()
	
	//display the full path to the wave in a text box
	drawFullPathText()
	
End

Function NT_DuplicateRename(ds)
	STRUCT ds &ds
	
	Variable numWaves,j,pos,numAddItems
	String theWaveList,name,newName,posList,ctrlList,addItem
	
	posList = "0;1;2;3;4"
	ctrlList = "prefixName;groupName;seriesName;sweepName;traceName"
	
	ControlInfo/W=NT killOriginals
	Variable killOriginals = V_Value
	
	ds.wsi = 0
	
	Do
		Wave theWave = ds.waves[ds.wsi]
		SetDataFolder GetWavesDataFolder(theWave,1)
		
		name = NameOfWave(theWave)
		newName = NameOfWave(theWave)
		
		For(j=4;j>-1;j-=1)	//step backwards
			//new name and the position
			ControlInfo/W=NT $StringFromList(j,ctrlList,";")
			S_Value = resolveListItems(S_value,",")
			S_Value = RemoveEnding(S_Value,",")
			
			numAddItems = ItemsInList(S_Value,",")
			pos = str2num(StringFromList(j,posList,";"))
			
			If(strlen(S_Value))
				If(!cmpstr(S_Value,"-"))
					newName = RemoveListItem(pos,newName,"_")		
				Else
					newName = RemoveListItem(pos,newName,"_")
					If(ds.wsi > numAddItems - 1)
						addItem = StringFromList(numAddItems - 1,S_Value,",")
					Else
						addItem = StringFromList(ds.wsi,S_Value,",")
					EndIf
					
					If(!cmpstr(addItem,"<wsi>"))
						addItem = num2str(ds.wsi)
					ElseIf(!cmpstr(addItem,"<wsn>"))
						addItem = num2str(ds.wsn)
					EndIf
					
					newName = AddListItem(addItem,newName,"_",pos)
					newName = RemoveEnding(newName,"_")
				EndIf
			EndIf
		EndFor
		
		newName = RemoveEnding(newName,"_")
		
		//If no changes in name were made, and we aren't killing the originals, ... 
		//...make the name unique with extra 0,1,2... at the end
		If(!cmpstr(name,newName,1) && !killOriginals) //case-sensitive
			newName = UniqueName(newName,1,0)
		EndIf
		
		If(killOriginals)
			If(cmpstr(name,newName))
				KillWaves/Z $newName
				try
					Rename $name,$newName;AbortOnRTE
				catch
					Variable error = GetRTError(1)
				endtry
			EndIf
		Else
			Duplicate/O theWave,$newName
		EndIf
		
		updateProgress(ds)
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves)

End


//Moves waves to the indicated folder within the current data folder
//Use the relative depth to back out of the current data folder.
 
Function NT_MoveToFolder(ds)
	STRUCT ds &ds
	
	Variable i

	ControlInfo/W=NT moveFolderStr
	String theFolder = S_Value
	
	ControlInfo/W=NT relativeFolder
	Variable depth = V_Value
	
	ds.wsi = 0
	
	Do
		String folderPath = theFolder
		Wave theWave = ds.waves[ds.wsi]
		
		If(!WaveExists(theWave))
			continue
		EndIf
		
		String wavePath = GetWavesDataFolder(theWave,1)
		SetDataFolder $wavePath
		
		//finds on the full path to the folder if it's a relative path
		If(!stringmatch(folderPath,"root:*"))
			//only takes relative depth into account if it's a relative path
			If(depth < 0)
				String relativePath = ParseFilePath(1,wavePath,":",1,abs(depth) - 1) //takes relative depth path
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
	While(ds.wsi < ds.numWaves)

End

//Parses the command line entry string, and resolves any data set declarations, etc. to form
//a valid command line entry.
//Syntax:
//DataSet declaration: <DataSet>
//Specific wave set number/indes declaration: <DataSet>{wsn,wsi}

Function NT_RunCmdLine()
	
	DFREF NTF = root:Packages:NT
	SVAR masterCmdLineStr = NTF:masterCmdLineStr
	
	//If there are no appended commands, take directly from the entry box
	If(!strlen(masterCmdLineStr))
		Variable resetEntry = 1
		ControlInfo/W=NT cmdLineStr
		masterCmdLineStr += S_Value + ";/;"
	Else
		resetEntry = 0
	EndIf
	
	//Print result or not
	ControlInfo/W=NT printCommand
	Variable doPrint = V_Value
	
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
			Variable numWaveSets = GetNumWaveSets(GetDataSetWave(dsName,"ORG"))	//number wave sets
		Else
			numWaveSets = 1
		EndIf
	
	
		//LOOP THROUGH EACH WAVE SET IN ANY IDENTIFIED DATA SETS
		For(i=0;i<numWaveSets;i+=1)
			
			//update the size of the wavesets for each wsn
			Variable k
			For(k=0;k<ItemsInList(dsRefList,";");k+=1)
				testDims = GetDataSetDims(StringFromList(k,dsRefList,";"))
				wsDimSize[k] = str2num(StringFromList(i,testDims,";"))
			EndFor
					
			If(strlen(dsName))
				String theWaveSet = GetWaveSetList(GetDataSetWave(dsName,"ORG"),i,1)
				numWaves = WaveMax(wsDimSize)
				
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
					ElseIf(strlen(outWaveName) && WaveExists($outWaveName) && strlen(theWaveSet))
						//already exists, correct any incorrect dimensions
//						Redimension/N=(numWaves) $outWaveName
						
						Wave theFirstWave = $StringFromList(0,theWaveSet,";")
						Redimension/N=(DimSize(theFirstWave,0)) $outWaveName
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

//Kills the waves
Function NT_KillWaves(ds)
	STRUCT ds &ds
		
	ds.wsi = 0
	
	Variable/G root:Packages:NT:totalSize
	NVAR totalSize = root:Packages:NT:totalSize
		
	If(ds.wsn == 0)
		totalSize = 0
	EndIf
	
	Do
		Wave theWave = ds.waves[ds.wsi]
		String info = WaveInfo(theWave,0)
		totalSize += str2num(StringByKey("SIZEINBYTES",info))
		
		ReallyKillWaves(theWave)
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves)
	
	//print out the total size of the deleted waves after killing the waves.
	//print on last wave set
	If(ds.wsn == ds.num-1)
		print "Deleted:", totalSize / (1e6),"MB"
	EndIf
End

//Makes new data folder of the specified name within the selected data folders
//Use the subfolder option to go deeper into the folder structure
Function NT_NewDataFolder()
	STRUCT filters filters
	
	SetFilterStructure(filters,"")
	
	ControlInfo/W=NT NDF_relFolder
	String relFolder = S_Value
	
	filters.relFolder = relFolder
	
	ControlInfo/W=NT NDF_folderName
	String folder = S_Value
	
	Wave/T listWave = root:Packages:NT:FolderLB_ListWave
	Wave selWave = root:Packages:NT:FolderLB_SelWave
	
	//Gets all the matched folders from the relative folder term
	String folderList = GetFolderSearchList(filters,listWave,selWave)
	
	SVAR cdf = root:Packages:NT:currentDataFolder
	
	Variable i
	
	//no selection, so must use current data folder
	If(!strlen(folderList))
	 folderList += RemoveEnding(cdf,":")
	EndIf
	
	For(i=0;i<ItemsInList(folderList,";");i+=1)
		String path = StringFromList(i,folderList,";") + ":" + folder
		NewDataFolder/O $path
	EndFor
	
	//update the folder and waves listbox
	getFolders()
	getFolderWaves()
End

//Kills the selected data folders
Function NT_KillDataFolder()
	STRUCT filters filters
	
	SetFilterStructure(filters,"")
	
	ControlInfo/W=NT NDF_relFolder
	String relFolder = S_Value
	
	filters.relFolder = relFolder
	
	ControlInfo/W=NT NDF_folderName
	String folder = S_Value
	
	Wave/T listWave = root:Packages:NT:FolderLB_ListWave
	Wave selWave = root:Packages:NT:FolderLB_SelWave
	
	//Gets all the matched folders from the relative folder term
	String folderList = GetFolderSearchList(filters,listWave,selWave)
	
	SVAR cdf = root:Packages:NT:currentDataFolder
	
	//no selection, so must use current data folder
	If(!strlen(folderList))
	 folderList += RemoveEnding(cdf,":")
	EndIf
	
	
	Variable i
	For(i=0;i<ItemsInList(folderList,";");i+=1)
		String path = StringFromList(i,folderList,";") + ":" + folder
		KillDataFolder/Z $path
	EndFor
	
	//update the folder and waves listbox
	getFolders()
	getFolderWaves()
End

//Performs various measurements on the data set and puts the result in an output wave
Function NT_Measure(ds)
	STRUCT ds &ds
	
	//Get input parameters
	String type = CurrentMeasureType()
	
	//Wave note
	String theNote = ""
	
	strswitch(type)
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
			suffix = "_avg"
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
			
			ControlInfo/W=NT vectorSumReturn
				
			switch(V_Value)
				case 1:
					suffix = "_vAng"
					String returnItem = "angle"
					break
				case 2:
					suffix = "_vRes"
					returnItem = "resultant"
					break
				case 3:
					suffix = "_vDSI"
					returnItem = "DSI"
					break
			endswitch
			
		break
	endswitch
	
	ControlInfo/W=NT measureStart
	Variable startTm = V_Value
	
	ControlInfo/W=NT measureEnd
	Variable endTm = V_Value
	//this allows each wave to have a different end point if we're using the whole wave
	Variable origEndTm = endTm 
	
	ControlInfo/W=NT measureThreshold
	Variable threshold = V_Value
	
	ControlInfo/W=NT sortOutput
	String sortType = S_Value
	
	
	//Make the output wave
	String outName = StringFromList(0,ds.paths,";") + suffix
	Make/O/N=(ds.numWaves) $outName /Wave = outWave
	
	//Make the measurement
	ds.wsi = 0
	Do
		Wave theWave = ds.waves[ds.wsi]
		
		
		//Ensure valid point range
		If(endTm == 0 || endTm < startTm)
			startTm = 0
			endTm = x2pnt(theWave,DimSize(theWave,0))
		EndIf
		
		WaveStats/Q/R=(startTm,endTm) theWave
		
		strswitch(type)
			case "Peak": //peak
				outWave[ds.wsi] = V_max
				
//				Variable bgnd = mean(theWave,2,4)
//				outWave[ds.wsi] -= bgnd
//				
				break
			case "Peak Location": //peak x location
				outWave[ds.wsi] = V_maxLoc
				break
			case "Area": //area
//				bgnd = mean(theWave,2,4)
//				Duplicate/FREE theWave,temp
//				temp -= bgnd
//				outWave[ds.wsi] = area(temp,startTm,endTm)
				outWave[ds.wsi] = area(theWave,startTm,endTm)
				break
			case "Mean": //mean
				outWave[ds.wsi] = V_avg
				break
			case "Median": //median
				outWave[ds.wsi] = median(theWave,startTm,endTm)
				break
			case "Std. Dev.": //sdev
				outWave[ds.wsi] = V_sdev
				break
			case "Std. Error": //sem
				outWave[ds.wsi] = V_sem
				break
			case "# Spikes": //spike count
				outWave[ds.wsi] = NT_SpikeCount(theWave,startTm,endTm,threshold)
				break
			case "Vector Sum": //vector sum
				String angles = GetVectorSumAngles(ds,DimSize(theWave,0))
		
				outWave[ds.wsi] = NT_VectorSum(theWave,angles,returnItem)
				
				sortType = "Linear"
				break
		endswitch
		
		//Add wave name to wave note
		theNote += StringFromList(ds.wsi,ds.paths,";") + "\n"
		
		//Reset the end point to its original value for the next wave
		endTm = origEndTm
		
		updateProgress(ds)
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves)
	
	//Optional sorting
	strswitch(sortType)
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
	
	Note outWave,theNote
End


Function NT_LoadEphys()
	DFREF NTF = root:Packages:NT
	SVAR wsFilePath = NTF:wsFilePath
	SVAR wsFileName = NTF:wsFileName
	
	
	Wave/T wsFileListWave = NTF:wsFileListWave
	Wave wsFileSelWave = NTF:wsFileSelWave
	
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
	
	ControlInfo/W=NT fileType
	String type = S_Value
	
	ControlInfo/W=NT ChannelSelector
	String ch = S_Value
	
	NewPath/O/Q/Z filePath,wsFilePath
	
	strswitch(type)
		case "PClamp":
			LoadPClamp(filePathList)
			break
		case "WaveSurfer":
			NT_Load_WaveSurfer(filePathList,channels=ch)
			break
		case "Presentinator":
			LoadPresentinator(filePathList)
			break
	endswitch
End

Function LoadPClamp(filePathList)
	String filePathList

	If(!strlen(filePathList))
		return 0
	EndIf
	
	Variable i
	For(i=0;i<ItemsInList(filePathList,";");i+=1)
		String theFile = StringFromList(i,filePathList,";") + ".abf"
		ABFLoader(theFile,"All",1)
	EndFor
	
	//clean up
	KillDataFolder/Z root:ABFvar
End

//Loads and scales sweeps loaded from an HDF5 file made by WaveSurfer electrophysiology software
Function NT_Load_WaveSurfer(String fileList[,String channels])

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
		GetStimulusData(fileID)
		Wave/T stimData = root:Packages:NT:wsStimulusDataListWave
		
		SetDataFolder $folder
		
		//Load the sweeps into waves
		Make/Wave/FREE/N=0 sweepRefs
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
				
				If(!cmpstr(ch[j],channels) || !cmpstr(channels,"All"))	
					Multithread data[j][] = ( (data[j][q] / scale[j]) * coef[j][1] + (coef[j][0] / scale[j]) ) * mult
					
					//Split the channels - puts wave into a folder that is the immediate subfolder
					//of the file.
					
					
					String channelName = prefix + "_" + theSweep + "_1_1_" + num2str(j + 1)
					Make/O/N=(DimSize(data,1))/S $channelName
					Wave channel = $channelName
					
					Multithread channel = data[j][p]
					SetScale/P x,0,1/rate[0],"s",channel
					SetScale/P y,0,1,unitBase,channel
					
					//Set the wave note
					Note/K channel,"Path: " + path
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
				EndIf 
			EndFor
			
			KillWaves/Z data	
		EndFor
		
		//Cleanup
		KillWaves/Z coef,scale,unit,rate,ch,prot
		
		//Close file
		HDF5CloseFile/A fileID
	EndFor
	
	//refresh the folder and wave list boxes
	getFolders()
	getFolderWaves()
End

//Counts the number of spikes in the wave
Function NT_SpikeCount(theWave,startTm,endTm,threshold)
	Wave theWave
	Variable startTm,endTm,threshold
	Variable spkct
	
	If(!WaveExists(theWave))
		return -1
	EndIf
	
	FindLevels/Q/EDGE=1/R=(startTm,endTm) theWave,threshold
	spkct = V_LevelsFound
	KillWaves/Z W_FindLevels
	return spkct
End

//Returns the vector sum angle or dsi of the input wave
Function NT_VectorSum(theWave,angles,returnItem)
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
	endswitch
End

//Same as SaveGraphCopy, but does it iteratively for an entire layout page
Function SaveLayoutCopy()
	
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