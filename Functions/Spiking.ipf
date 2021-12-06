#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//Subtracts the overall average value from the wave
Function NT_SubtractMean(DS_Waves)
	//SUBMENU=Spiking
	//TITLE=Subtract Mean
	String DS_Waves
	
	STRUCT ds ds
	GetStruct(ds)
	
	ds.wsi = 0
	Do
		Wave theWave = ds.waves[ds.wsi]
		
		WaveStats/Q/M=1 theWave
		theWave -= V_avg
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
End

//Fits a low frequency trend to the data and subtracts it
Function NT_SubtractTrend(DS_Waves)
	//SUBMENU=Spiking
	//TITLE=Subtract Trend
	
//	Note={
//	Subtracts a polynomial fit from the input waves so as to flatten their baseline.
//	Works really well on spiking data.
//	}
	
	String DS_Waves
	
	STRUCT ds ds
	GetStruct(ds)
	
	ds.wsi = 0
	Do
		Wave theWave = ds.waves[ds.wsi]
		
		FlattenWave(theWave)
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
End

//inputs spike recording, outputs histograms
Function/WAVE NT_PSTH(DS_Waves,BinSize,SpikeThreshold,menu_Type,OutputFolder,cb_RemoveTrend,StartTime,EndTime)
	//SUBMENU=Spiking
	
//	Note={
//	Calculates the spike rate over time. Input is raw spiking data.
//	
//	\f01BinSize:\f00 Size of the bin to measure the firing rate, 0.02 (20 ms) is good default.
//	\f01SpikeThreshold:\f00 Threshold value for detecting spikes. Make sure units are correct.
//	\f01Type:\f00 Either binned or convolved with a gaussian kernel of width = BinSize
//	\f01OutpuFolder:\f00 Output folder for the PSTH, put inside the folder with the data
//	\f01RemoveTrend:\f00 Eliminates wobbly baseline using a polynomial fit
//	\f01StartTime:\f00 Starting X point for the PSTH
//	\f01EndTime:\f00 Ending X point for the PSTH. 0 will take the entire wave
//	}
	
	String DS_Waves
	Variable BinSize,SpikeThreshold
	String menu_Type,OutputFolder
	Variable cb_RemoveTrend,StartTime,EndTime
	
	String menu_Type_List = "Gaussian;Binned;"
	String SpikeThreshold_Assign = "root:Packages:NeuroToolsPlus:ControlWaves:threshold"
	String StartTime_Assign = "root:Packages:NeuroToolsPlus:ControlWaves:rangeLeft"
	String EndTime_Assign = "root:Packages:NeuroToolsPlus:ControlWaves:rangeRight"
	
	STRUCT ds ds
	GetStruct(ds)
	
	Variable i,j,numWaves,numBins
	
	SetDataFolder GetWavesDataFolder(ds.waves[0],1)
	
	//Check start and end time validity
	If(EndTime == 0 || EndTime < StartTime)
		EndTime = pnt2x(ds.waves[0],DimSize(ds.waves[0],0) -1)
	EndIf
	
	
	//Reset the wsi
	ds.wsi = 0
	Do
		Wave theWave = ds.waves[ds.wsi]
		
		//Which data folder should we put the output waves?
		If(strlen(OutputFolder))
			CreateFolder(GetWavesDataFolder(ds.waves[ds.wsi],1) + OutputFolder)
		EndIf
			
		SetDataFolder GetWavesDataFolder(ds.waves[ds.wsi],1) + OutputFolder
		
		//Remove low pass trends in the wave to flatten it
		If(cb_RemoveTrend)
			FlattenWave(theWave)
		EndIf
		
		//Make Spike Count wave
		Make/FREE/N=(ds.numWaves[0]) spkct
		
		//Get spike times and counts
		FindLevels/Q/EDGE=1/M=0.002/R=(StartTime,EndTime)/D=spktm theWave,SpikeThreshold
		spkct[i] = V_LevelsFound
		
		//Gaussian or binned histograms
		strswitch(menu_Type)
			case "Binned":	
				numBins = floor((IndexToScale(theWave,DimSize(theWave,0)-1,0) - IndexToScale(theWave,0,0) )/ BinSize) //number of bins in wave
				String histName = RemoveEnding(ReplaceListItem(0,NameOfWave(theWave),"_","PSTH"),"_")
				Make/O/N=(numBins) $histName
				Wave hist = $histName
				
				//add to output data set
				AddOutput(hist,ds)
				
				If(DimSize(spktm,0) == 0)
					hist = 0
				Else
					Histogram/C/B={pnt2x(theWave,0),BinSize,numBins} spktm,hist
				EndIf
				
				hist /= binSize
				
				break
			case "Gaussian":
				Variable dT = DimDelta(theWave,0)
				Variable sampleRate = 1000 // 1 ms time resolution
				//gaussian template for convolution
				Make/O/N=(3*(BinSize*sampleRate)+1) template
				Wave template = template
				SetScale/I x,-1.5*BinSize,1.5*BinSize,template
				template = exp((-x^2/(0.5*BinSize)^2)/2)
				
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
				
				//add to output data set
				AddOutput(hist,ds)
				
				Convolve raster, hist
				hist *=1000
				
				break
		endswitch	
		
		//Cleanup
		KillWaves spktm,template
		
		//Set the wave note
		String noteStr = "PSTH:\r"
		noteStr += "Type: " + menu_Type + "\r"
		noteStr += "Threshold: " + num2str(SpikeThreshold) + "\r"
		noteStr += "Bin Size: " + num2str(BinSize) + "\r"
		noteStr += "StartTm: " + num2str(StartTime) + "\r"
		noteStr += "EndTm: " + num2str(EndTime) + "\r"
		
		Note/K hist,noteStr
				
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
	
End

//Generates a tuning curve for input data, returns a vector summation DSI and Angle
Function NT_DSTuning(DS_Waves,StartTime,EndTime,Threshold,menu_Angles,CustomAngles,Output_Name,cb_DisplayOutput)
	//SUBMENU=Spiking
	//TITLE=DS Tuning
	
	//declare any additional custom variables
	String DS_Waves
	Variable StartTime,EndTime,Threshold
	String menu_Angles,CustomAngles,Output_Name
	Variable cb_DisplayOutput
	
	//Items of the menu_Angles menu
	String menu_Angles_List = "Custom;0,45,90,135,180,225,270,315;0,180,45,225,90,270,135,315;"
	
	String Threshold_Assign = "root:Packages:NeuroToolsPlus:ControlWaves:threshold"
	String StartTime_Assign = "root:Packages:NeuroToolsPlus:ControlWaves:rangeLeft"
	String EndTime_Assign = "root:Packages:NeuroToolsPlus:ControlWaves:rangeRight"
	
	//	Note={
//	Creates a DS tuning curve and calculates associated statistics for it.
//	
//	\f01Start Time\f00 : Starting point of the range to count the spikes.
//	\f01Start Time\f00 : End point of the range to count the spikes.
//	\f01Threshold\f00 : Threshold for detecting spikes.
//	\f01Angles\f00 : Input custom or preset angles to sort the output data.
//	\f01OutputName\f00 : Overrides automatic output name generation.
//	\f01DisplayOutput\f00 : Opens a graph of the tuning curve after running.
//	}

	STRUCT ds ds
	GetStruct(ds)
	
	//Set the current data folder to the first wave
	SetDataFolder GetWavesDataFolder(ds.waves[0],1)
	
	//Create the ds tuning output wave
	If(!strlen(Output_Name))
		Output_Name = NameOfWave(ds.waves[0]) + "_tuning"
	EndIf
	
	Make/N=(ds.numWaves[%Waves])/O $Output_Name
	Wave tuning = $Output_Name
	
	Variable i
	//Loop through each wave in the wave list, and get its peak w/ possible background subtraction	
	For(i=0;i<ds.numWaves[%Waves];i+=1)
	
		//current wave in the list
		Wave theWave = ds.waves[i]

		tuning[i] = GetSpikeCount(theWave,StartTime,EndTime,Threshold)
	EndFor
	
	menu_Angles = ReplaceString(",",menu_Angles,";")
	
	Variable PD,DSI,Resultant
	[PD,DSI,Resultant] = VectorSum2(tuning,menu_Angles)
	
	If(strlen(menu_Angles))
		Make/FREE/N=(ItemsInList(menu_Angles,";")) index
		Wave/T sortKey = ListToTextWave(menu_Angles,";")
		
		MakeIndex/A sortKey,index
		MakeIndex/A index,index
		Sort index,tuning
		
		index = str2num(sortKey)
		SetScale/I x,WaveMin(index),WaveMax(index),"deg",tuning
	EndIf
	
	SetScale/I y,0,1,"# Spikes",tuning
	
	//display the tuning curve
	If(cb_DisplayOutput)
		GetWindow/Z NTP wsize
		
		Display/K=1/W=(V_right,V_top,V_right + 300,V_top + 200) tuning
	EndIf
		
End

//fills an output wave with the number of spikes for each wave in a waveset
Function NT_SpikeCount(DS_Waves,StartTime,EndTime,Threshold,menu_SortOutput)
	//SUBMENU=Spiking
	//TITLE=Spike Count
	
	String DS_Waves
	Variable StartTime,EndTime,Threshold
	String menu_SortOutput
	
	String menu_SortOutput_List = "Linear;Alternating;"
	String Threshold_Assign = "root:Packages:NeuroToolsPlus:ControlWaves:threshold"
	String StartTime_Assign = "root:Packages:NeuroToolsPlus:ControlWaves:rangeLeft"
	String EndTime_Assign = "root:Packages:NeuroToolsPlus:ControlWaves:rangeRight"
	
//	Note={
//	Counts the number of spikes in all of the waves in the input data set. 
// Output is a single wave.
//	
//	\f01Start Time\f00 : Starting point of the range to count the spikes
//	\f01Start Time\f00 : End point of the range to count the spikes
//	\f01Threshold\f00 : Threshold for detecting spikes.
//	\f01Sort Output\f00 : Either doesn't sort (linear) or sorts the output for alternating data.
//	}
	
	STRUCT ds ds
	GetStruct(ds)
	
	//Ensure correct data folder is set to pick up V_LevelsFound
	SetDataFolder GetWavesDataFolder(ds.waves[0],1)
	
	String suffix = "_spkct"
	String theNote = "Spike Count:\n"
	
	//Saves original value of the EndTime in case it needs adjusting to put into valid range
	Variable origEndTm = EndTime 	

	//Make the output wave
	String outName = RemoveEnding(ReplaceListItem(0,NameOfWave($ds.paths[0][0]),"_","nSpikes"),"_")
	
//	String outName = ds.paths[0][0] + suffix
	Make/O/N=(ds.numWaves[0]) $outName /Wave = outWave
	SetScale/I y,0,1,"# Spikes",outWave
	
	//Make the measurement
	ds.wsi = 0
	Do
		Wave theWave = ds.waves[ds.wsi]
		
		//Ensure valid point range
		If(EndTime == 0 || EndTime < StartTime)
			StartTime = 0
			EndTime = x2pnt(theWave,DimSize(theWave,0))
		EndIf

		//get number of spikes
		outWave[ds.wsi] = GetSpikeCount(theWave,StartTime,EndTime,Threshold)

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
	
	Note outWave,theNote

End
