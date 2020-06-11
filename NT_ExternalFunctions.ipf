﻿#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//RESERVED FUNCTION, don't change or remove. 
Function ArrangeProcWindows()
	MoveWindow/P=$"NT_InsertTemplate.ipf" 0,0,600,600
	MoveWindow/P=$"NT_ExternalFunctions.ipf" 600,0,1200,600
	
End


//Put your own functions here.

//Put the prefix 'NT_' on your functions that you want to include in the 'External Function' menu.

//Functions without the 'NT_' prefix aren't included in the list, and can be used as subroutines
	//for the main 'NT_' functions. 
	
Function NT_BensFunction(suffix,DS_myDataset,DS_myDataset2)
	String suffix 
	String DS_myDataset,DS_myDataset2
	
	//Data set info structure
	STRUCT ds ds 
	
	//Fills the data set structure
	GetStruct(ds)
	
	//Reset wave set index
	ds.wsi = 0
	
	//Name of the output wave that will hold the results
	String outputName = NameOfWave(ds.waves[0]) + "_out"
	
	//Make the output wave 
	Make/O/N=(DimSize(ds.waves[0],0),DimSize(ds.waves[0],1),DimSize(ds.waves[0],2)) $outputName/Wave = outWave
	
	//Function Loop
	Do
		//declare each wave in the wave set
		Wave theWave = ds.waves[ds.wsi]
		
		//YOUR CODE GOES HERE....
		print NameOfWave(theWave) + "_" + suffix
		
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves)
	
End

//Truncates signals to zero after the peak
Function NT_TruncateDecay(DS_Locations,DS_Signals)
	String DS_Locations,DS_Signals
	
	//Data set info structure
	STRUCT ds ds 
	
	//Fills the data set structure
	GetStruct(ds)
	
	//Get the data sets
	Wave/T locations_ds = GetDataSetWave(DS_Locations,"ORG")
	Wave/T signals_ds = GetDataSetWave(DS_Signals,"ORG")
	
	//Get the wave sets
	Wave/T locations_ws = GetWaveSet(locations_ds,ds.wsn)
	Wave/T signals_ws = GetWaveSet(signals_ds,ds.wsn)
	
	//Get peak locations wave - should be only wave in the wave set
	Wave locations = $locations_ws[ds.wsn][0][1]
	
	//Reset wave set index
	ds.wsi = 0
	ds.numWaves = DimSize(signals_ws,0)
	
	//Function Loop
	Do
		//declare each wave in the wave set
		Wave signal = $signals_ws[ds.wsi][0][1]
		
		//YOUR CODE GOES HERE....
		SetDataFolder GetWavesDataFolder(signal,1)
		
		//Make the truncated wave
		Duplicate/O signal,$RemoveEnding(ReplaceListItem(0,NameOfWave(signal),"_","Trunc"),"_")
		Wave truncWave = $RemoveEnding(ReplaceListItem(0,NameOfWave(signal),"_","Trunc"),"_")
		
		//Truncate the wave to zero after the peak
		Variable index = ScaleToIndex(signal,locations[ds.wsi][0][1],0)
		truncWave[index,*] = 0
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves)
	
End

//Wrapper function for Spike Adjustment
Function NT_Spike_Adjustment(Time_Point,Delay,Threshold,DS_Linear,DS_Turn,Output_Name)
	Variable Time_Point //time point to reference from (e.g. start of the stimulus turn) in seconds
	Variable Delay //transduction delay in seconds
	Variable Threshold  //traces must be within % of each other to count as 'adjusted'
	String DS_Linear,DS_Turn,Output_Name
	
	//Data set info structure
	STRUCT ds ds 
	
	//Fills the data set structure
	GetStruct(ds)
	
	//Reset wave set index
	ds.wsi = 0
	
	//save data folder
	DFREF saveDF = GetDataFolderDFR()
	
	//Name of the output wave that will hold the results
	ControlInfo/W=NT param5 //output name parameter
	String outputName = S_Value + "_" + StringFromList(3,NameOfWave(ds.waves[0][1]),"_")
	
	String outputName2 = S_Value + "_diff_" + StringFromList(3,NameOfWave(ds.waves[0][1]),"_")
	
	String outputName3 = S_Value + "_successRate_" + StringFromList(3,NameOfWave(ds.waves[0][1]),"_")
	
	//Make the output wave 
	If(ds.wsn == 0)
		SetDataFolder GetWavesDataFolder(ds.waves[0][0],1)
		Make/O/N=(ds.numWaves) $outputName
		Make/O/N=(ds.numWaves) $outputName2
		Make/O/N=1 $outputName3
	EndIf
	
	Wave outWave = $outputName
	Wave outWave2 = $outputName2
	Wave outWave3 = $outputName3
	
	Variable successCounter = 0
	
	//Function Loop
	Do
		//declare each wave in the wave set
		Wave linear = ds.waves[ds.wsi][0] //should only be one wave per waveset
		Wave turn = ds.waves[ds.wsi][1]
		
		SetDataFolder GetWavesDataFolder(linear,1)
		
		//YOUR CODE GOES HERE....
		Variable adjustTime,adjustDiff,isSuccess
		[adjustTime,adjustDiff,isSuccess] = Spike_Adjustment(linear,turn,Time_Point,Delay,Threshold)
		outWave[ds.wsi] = adjustTime
		outWave2[ds.wsi] = adjustDiff
		
		successCounter += isSuccess 
		 
		ds.wsi += 1
	While(ds.wsi < ds.numWaves)
	
	outWave3 = successCounter / ds.numWaves
	
	SetDataFolder saveDF
End

//Finds Spike adjustment time from turning stimulus to linear stimulus
Function [Variable adjustTime, Variable adjustDiff, Variable success] Spike_Adjustment(Wave linear,Wave turn,Variable refTime,Variable delay,Variable threshold)
//	Wave linear,turn
//	Variable refTime,delay,threshold
	
	//Percent difference between linear and turn waves
	Make/N=(DimSize(linear,0))/FREE pctDiff
//	pctDiff = abs(linear - turn) / (0.5 * (linear + turn))
	pctDiff = abs(linear - turn) //just the difference
	CopyScales/P linear,pctDiff
	
	threshold = threshold * 0.5 * (WaveMax(linear) + WaveMax(turn)) //come within % of the mean max value of the linear and turn waves
	
	//Finds first point that is less than threshold
	FindLevel/Q/R=(refTime + delay)/EDGE=2 pctDiff,threshold
	
	
	//Get the linear entry wave based on names of the turning and linear exit wave
	String entryName = NameOfWave(turn)
	String item = StringFromList(3,entryName,"_")
	item = StringFromList(0,item,"t")
	
	String list = WaveList("*_" + item + "_*avg",";","")
	
	entryName = StringFromList(0,list,";")
//	entryName = RemoveEnding(ReplaceListItem(3,entryName,"_",item),"_")
	Wave entryWave = $entryName
	
	If(V_flag) //no level found
		return [nan,nan,0]
	Else
		
		Variable index = ScaleToIndex(linear,V_LevelX,0)
		If(linear[index] < 1 && entryWave[index] < 1)
			//If the adjustment time is at the point where both entry and exit waves are close to zero, the adjustment basically didn't happen.
			adjustTime = nan
			adjustDiff = nan
			success = 0
		Else
			adjustTime = V_LevelX - (refTime + delay)
			adjustDiff = (linear[ScaleToIndex(linear,V_LevelX,0)] - turn[ScaleToIndex(turn,refTime + delay,0)])
			success = 1
		EndIf
		
		return [adjustTime,adjustDiff,success]
	EndIf
End

Function NT_FilterSuccessRate(DS_Input_Data)
	String DS_Input_Data
	
	//Data set info structure
	STRUCT ds ds 
	
	//Fills the data set structure
	GetStruct(ds)
	
	//Reset wave set index
	ds.wsi = 0

	//Function Loop
	Do
		//declare each wave in the wave set
		Wave theWave = ds.waves[ds.wsi]
		
		SetDataFolder GetWavesDataFolder(theWave,1)
	
		//Name of the output wave that will hold the results
		String outputName = NameOfWave(ds.waves[ds.wsi]) + "_filtered"
	
		//Make the output wave 
		Make/O/N=(DimSize(ds.waves[ds.wsi],0),DimSize(ds.waves[ds.wsi],1),DimSize(ds.waves[ds.wsi],2)) $outputName/Wave = outWave
	
		//YOUR CODE GOES HERE....		
		FilterSuccessRate(theWave,outWave)
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves)
	
End

//Filters the success rate for adjustment time to remove unreasonable values
Function FilterSuccessRate(theWave,outWave)
	Wave theWave,outWave

	outWave = (theWave > 0.3) ? nan : theWave
	outWave = (theWave < 0.02) ? nan : outWave
End

Function NT_PrintFolders(DS_Data)
	String DS_Data
	
	//Data set info structure
	STRUCT ds ds 
	
	//Fills the data set structure
	GetStruct(ds)
	
	//Reset wave set index
	ds.wsi = 0
	
	//Function Loop
	Do
		//declare each wave in the wave set
		Wave theWave = ds.waves[ds.wsi]
		
		//YOUR CODE GOES HERE....
		Variable pt = ScaleToIndex(theWave,1.273,0)
		
		If(theWave[pt] > 25)
			print GetWavesDataFolder(theWave,1)
		EndIf
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves)
End