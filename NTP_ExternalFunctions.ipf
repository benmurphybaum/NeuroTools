#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include <Multi-peak fitting 2.0>

//RESERVED FUNCTION, don't change or remove. 
Function ArrangeProcWindows()
	MoveWindow/P=$"NT_InsertTemplate.ipf" 0,0,600,600
	MoveWindow/P=$"NT_ExternalFunctions.ipf" 600,0,1200,600
	
End


//Put your own functions here.

//Put the prefix 'NT_' on your functions that you want to include in the 'External Function' menu.

//Functions without the 'NT_' prefix aren't included in the list, and can be used as subroutines
	//for the main 'NT_' functions. 
	
Function NT_SumWaves(suffix,DS_Data)
	String suffix 
	String DS_Data
	
	//Data set info structure
	STRUCT ds ds 
	
	//Fills the data set structure
	GetStruct(ds)
	
	//Reset wave set index
	ds.wsi = 0
	
	//Name of the output wave that will hold the results
	If(!strlen(suffix))
		suffix = "sum"
	EndIf 
	
	String outputName = NameOfWave(ds.waves[0]) + "_" + suffix
	
	//Make the output wave, ensuring proper dimensioning out to 4D
	SetDataFolder GetWavesDataFolder(ds.waves[0],1)
	
	Make/O/N=(DimSize(ds.waves[0],0),DimSize(ds.waves[0],1),DimSize(ds.waves[0],2),DimSize(ds.waves[0],3)) $outputName/Wave = outWave
	Multithread outWave = 0
	
	//Function Loop
	Do
		//declare each wave in the wave set
		Wave theWave = ds.waves[ds.wsi]
		
		//YOUR CODE GOES HERE....
		Multithread outWave += theWave
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
	
	CopyScales/P theWave,outWave
	
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
	While(ds.wsi < ds.numWaves[0])
	
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
	ControlInfo/W=NTP param5 //output name parameter
	String outputName = S_Value + "_" + StringFromList(3,NameOfWave(ds.waves[0][1]),"_")
	
	String outputName2 = S_Value + "_diff_" + StringFromList(3,NameOfWave(ds.waves[0][1]),"_")
	
	String outputName3 = S_Value + "_successRate_" + StringFromList(3,NameOfWave(ds.waves[0][1]),"_")
	
	//Make the output wave 
	If(ds.wsn == 0)
		SetDataFolder GetWavesDataFolder(ds.waves[0][0],1)
		Make/O/N=(ds.numWaves[0]) $outputName
		Make/O/N=(ds.numWaves[0]) $outputName2
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
	While(ds.wsi < ds.numWaves[0])
	
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
	While(ds.wsi < ds.numWaves[0])
	
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
	While(ds.wsi < ds.numWaves[0])
End


Function NT_AvgZRange(DS_Data,StartLayer,EndLayer)
	String DS_Data
	Variable StartLayer,EndLayer
	
	//Data set info structure
	STRUCT ds ds 
	
	//Fills the data set structure
	GetStruct(ds)
	
	//Reset wave set index
	ds.wsi = 0
	
	DFREF saveDF = GetDataFolderDFR()
	
	Do
		//declare each wave in the wave set
		Wave theWave = ds.waves[ds.wsi]
		
		//Make sure end layer isn't higher than wave dimensions
		EndLayer = (EndLayer > DimSize(theWave,2)) ? DimSize(theWave,2) - 1 : EndLayer
		
		SetDataFolder GetWavesDataFolderDFR(theWave)
		
		//Make wave to hold extracted layers
		Make/FREE/N=(DimSize(theWave,0),DimSize(theWave,1),EndLayer - StartLayer + 1) layerTemp
		
		Make/O/N=(DimSize(theWave,0),DimSize(theWave,1),1) $(NameOfWave(theWave) + "_L" + num2str(StartLayer) + "tL" + num2str(EndLayer))/Wave = outWave
		CopyScales/P theWave,outWave
		
		//Extract the layers
		Multithread layerTemp[][][] = theWave[p][q][r + StartLayer]
		
		//Average them
		MatrixOP/O outWave = sumbeams(layerTemp)
		Redimension/S outWave
		outWave /= DimSize(layerTemp,2)
		
		CopyScales/P layerTemp,outWave
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
	
		
	SetDataFolder saveDF
End

Function NT_SumImages(DS_Images)
	String DS_Images
	
	//Data set info structure
	STRUCT ds ds 
	
	//Fills the data set structure
	GetStruct(ds)
	
	//Reset wave set index
	ds.wsi = 0
	
	//Name of the output wave that will hold the results
	String outputName = NameOfWave(ds.waves[0]) + "_sum"
	
	SetDataFolder GetWavesDataFolder(ds.waves[0],1)
	
	//Make the output wave 
	Make/O/N=(DimSize(ds.waves[0],0),DimSize(ds.waves[0],1),DimSize(ds.waves[0],2)) $outputName/Wave = outWave
	outWave = 0
	
	CopyScales ds.waves[0],outWave
	
	//Function Loop
	Do
		//declare each wave in the wave set
		Wave theWave = ds.waves[ds.wsi]
		
		//YOUR CODE GOES HERE....
		
		outWave += theWave
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
	
	outWave /= ds.numWaves
	
End

Function NT_RiseTime(DS_Data,PeakStart,PeakEnd)
	String DS_Data
	Variable PeakStart,PeakEnd
	
	//Data set info structure
	STRUCT ds ds 
	
	//Fills the data set structure
	GetStruct(ds)
	
	//Reset wave set index
	ds.wsi = 0
	
	//Name of the output wave that will hold the results
	String outputName = NameOfWave(ds.waves[0]) + "_riseTime"
	
	//Make the output wave 
	Make/O/N=(ds.numWaves[0]) $outputName/Wave = outWave
	
	//Function Loop
	Do
		//declare each wave in the wave set
		Wave theWave = ds.waves[ds.wsi]
		
		//YOUR CODE GOES HERE....
		WaveStats/Q/R=(PeakStart,PeakEnd) theWave
//		Variable peakTime = V_MaxLoc
		
//		Duplicate/FREE theWave,temp
//		Differentiate temp 
//		
//		WaveStats/Q/R=(peakTime-1,peakTime) temp
		
		outWave[ds.wsi] = V_MaxLoc
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
	
End


Function NT_Normalize(DS_Data,startTm,endTm)
	String DS_Data
	Variable startTm,endTm
	
	//Data set info structure
	STRUCT ds ds 
	
	//Fills the data set structure
	GetStruct(ds)
	
	//Reset wave set index
	ds.wsi = 0
	
	//Name of the output wave that will hold the results
	String outputName = NameOfWave(ds.waves[0]) + "_out"
	
	//Make the output wave 
//	Make/O/N=(DimSize(ds.waves[0],0),DimSize(ds.waves[0],1),DimSize(ds.waves[0],2)) $outputName/Wave = outWave
	
	//Function Loop
	Do
		//declare each wave in the wave set
		Wave theWave = ds.waves[ds.wsi]
		
		SetDataFolder GetWavesDataFolder(theWave,1)
		
		Duplicate/O theWave,$NameOfWave(theWave) + "_norm"
		Wave normWave = $NameOfWave(theWave) + "_norm"
		
		//YOUR CODE GOES HERE....
		Variable maxValue = WaveMax(normWave,startTm,endTm)
		theWave = theWave / maxValue
		
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
	
End






//Sums image data so that the view is XZ projection
Function NT_ProjectXZ(DS_Data)
	String DS_Data
	
	//Data set info structure
	STRUCT ds ds 
	
	//Fills the data set structure
	GetStruct(ds)
	
	//Reset wave set index
	ds.wsi = 0
	
	Variable i,j
		
	//Function Loop
	Do
		//declare each wave in the wave set
		Wave theWave = ds.waves[ds.wsi]
		
		SetDataFolder GetWavesDataFolder(theWave,1)
		
		//YOUR CODE GOES HERE....
		Variable rows = DimSize(theWave,0)
		Variable cols = DimSize(theWave,1)
		Variable layers = DimSize(theWave,2)
		
		//Must be a 3D wave
		If(!layers)
			continue
		EndIf
		
		
		Make/O/N=(rows,layers)/S $NameOfWave(theWave) + "_XZ"/Wave=outWave
		Multithread	outWave = 0
		
		//rotate image to XZY
		MatrixOP/O/FREE xzy = transposeVol(theWave,1)
		
		//project the z plane
		MatrixOP/O outWave = sumbeams(xzy)
		
		CopyScales/P theWave,outWave
		SetScale/P y,0,DimDelta(theWave,2),"m",outWave
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
	
End

//Double peak or single peak?
Function NT_CrossTalk(DS_Data,menu_Arbor,startTm,endTm,smoothFactor,peakThreshold,NameTruncate)
	String DS_Data,menu_Arbor
	Variable startTm,endTm,smoothFactor,peakThreshold
	Variable NameTruncate
	
	String menu_Arbor_List = "ON;OFF;"
	
	//Data set info structure
	STRUCT ds ds 
	
	//Button control structure to get in between
	STRUCT MPFitInfoStruct MPStruct
	
	//Fills the data set structure
	GetStruct(ds)
	
	//Reset wave set index
	ds.wsi = 0
	
//	//Name of the output wave that will hold the results
//	String outputName = NameOfWave(ds.waves[0]) + "_out"
//	
//	//Make the output wave 
//	Make/O/N=(DimSize(ds.waves[0],0),DimSize(ds.waves[0],1),DimSize(ds.waves[0],2)) $outputName/Wave = outWave
	
	If(!DataFolderExists("root:Packages:NT:MultiPeak"))
		NewDataFolder root:Packages:NT:MultiPeak
	EndIf
	
	String DFpath = "root:Packages:NT:MultiPeak"
	SetDataFolder $DFpath
	
	String path = ParseFilePath(1,GetWavesDataFolder(ds.waves[0],1),":",1,0)
	
	String prefix = ParseFilePath(1,NameOfWave(ds.waves[0]),"_",0,NameTruncate)
	
	Make/O/N=(ds.numWaves[0]) $(path + prefix + "Crossover")/Wave=crossover //ratio of the peak amplitudes
	Make/O/N=(ds.numWaves[0]) $(path + prefix +"FirstPeak")/Wave=firstPeak //first peak amplitude
	Make/O/N=(ds.numWaves[0]) $(path + prefix + "SecPeak")/Wave=secPeak //second peak amplitude
	
	//Function Loop
	Do
		//declare each wave in the wave set
		Wave theWave = ds.waves[ds.wsi]
		path = GetWavesDataFolder(theWave,1)

		//Each ROI gets its own PeakFits subfolder to hold all of the output waves		
		If(!DataFolderExists(path + "PeakFits"))
			NewDataFolder $(path + "PeakFits")
		EndIf
		
		String peakPath = path + "PeakFits"
		
		//Baseline coefficient wave
		Wave/Z cwave = $(DFPath+":'Baseline Coefs'")
		if (!WaveExists(cwave))
			Make/O/D/N=1 $(DFPath+":'Baseline Coefs'")
		endif
		
		//Multi-peak fitting
		Variable npks = AutoFindPeaks(theWave, x2pnt(theWave,startTm),  x2pnt(theWave,endTm), 0.02, smoothFactor, Inf)		// Empirically these settings do well
		Wave wpi = W_AutoPeakInfo
		
		//Convert the results to scaled amplitudes and times
		AdjustAutoPeakInfoForX(wpi, theWave,  $"")
		
		//Sort so the peaks are in order
		Make/D/N=(DimSize(wpi, 0))/O MPF2_sortwave, MPF2_indexwave
		MPF2_sortwave = wpi[p][0]
		MakeIndex MPF2_sortwave, MPF2_indexwave
		SortColumns keyWaves={MPF2_indexwave},sortWaves={wpi}	
		KillWaves MPF2_sortwave,MPF2_indexwave
		
		npks = TrimAmpAutoPeakInfo(wpi,0.05)
		
		Variable i
		//Coefficient waves for the peaks and initial guesses for a Gaussian peak fit
		FUNCREF MPF2_FuncInfoTemplate infoFunc=$("Gauss"+PEAK_INFO_SUFFIX)
		Variable nparams
		String GaussGuessConversionFuncName = infoFunc(PeakFuncInfo_GaussConvFName)
		if (strlen(GaussGuessConversionFuncName) == 0)
		else
			FUNCREF MPF2_GaussGuessConvTemplate gconvFunc=$GaussGuessConversionFuncName
		endif
		
		String newWName
		for (i = 0; i < npks; i += 1)
			sprintf newWName, "Peak %d Coefs", i
			Make/D/O/N=(DimSize(wpi, 1)) $newWName
			Wave w = $newWName
			w = wpi[i][p]
			gconvFunc(w)
		endfor
		
		//Fill out the peak fitting structure
		MPStruct.NPeaks = DimSize(wpi, 0)
		
		//Y and optional X wave
		Wave MPStruct.yWave = theWave
		Wave/Z MPStruct.xWave = $""
		
		//Masks and weighting waves are optionals
		Wave/Z MPStruct.weightWave = $""
		Wave/Z MPStruct.maskWave = $""
		
		//Start and End ranges
		MPStruct.XPointRangeBegin = x2pnt(theWave,startTm)
		MPStruct.XPointRangeEnd = x2pnt(theWave,endTm)
		
		//Fit points variable
		Variable/G $(DFpath + ":MPF2_FitCurvePoints")
		NVAR MPF2_FitCurvePoints  = $(DFpath + ":MPF2_FitCurvePoints")
		MPF2_FitCurvePoints = 100
		MPStruct.FitCurvePoints = MPF2_FitCurvePoints
		
		//Baseline Coefficients
		MPStruct.ListOfFunctions = "Constant;"
		MPStruct.ListOfCWaveNames = "Baseline Coefs;"	
		MPStruct.ListOfHoldStrings = ";"
		
		For (i = 0; i < MPStruct.NPeaks; i += 1)
			MPStruct.ListOfCWaveNames += "Peak "+num2istr(i)+" Coefs;"
			MPStruct.ListOfFunctions += "Gauss;"
			MPStruct.ListOfHoldStrings += ";"
		endfor
		
		MPStruct.fitOptions = 4
		
		//Perform the fit of initial approximation to the data
		MPF2_DoMPFit(MPStruct, DFPath+":")
		
		Wave fitWave = $(DFPath + ":fit_" + NameOfWave(theWave))
		Duplicate/O fitWave,$(peakPath + ":fit_" + NameOfWave(theWave))
		
		//Extract the amplitudes of the fitted peaks
		Make/O/N=(MPStruct.NPeaks) $(peakPath + ":" + NameOfWave(theWave) + "_peakAmp")/Wave = amp
		
		For (i = 0; i < MPStruct.NPeaks; i += 1)
			String coefName = "'Peak " + num2str(i) + " Coefs'"
			Wave coef = $(DFpath + ":" + coefName)
			amp[i] = coef[2]
		Endfor
		
		//Remove values that are negative		
		amp = (amp < 0) ? nan : amp
		WaveTransform zapNaNs amp
		
		//Remove if there are more than two peaks
		If(DimSize(amp,0) > 2)
			amp = nan
			WaveTransform zapNaNs amp
		EndIf
		
		
		
		
		If(!cmpstr(menu_Arbor,"OFF"))
			Variable whichPeak = 1
	
			//If only one peak was detected, make this the 'second' peak position
			If(DimSize(amp,0) == 1)
				Redimension/N=2 amp
				amp[1] = amp[0]
				amp[0] = 0
			EndIf
	
		ElseIf(!cmpstr(menu_Arbor,"ON"))
			whichPeak = 0
			
			//If only one peak was detected, make this the 'second' peak position
			If(DimSize(amp,0) == 1)
				Redimension/N=2 amp
				amp[1] = 0
			EndIf
		EndIf	
	
		//Remove if the peak is less than peakThreshold
		If(DimSize(amp,0) == 2)
			If(amp[whichPeak] < peakThreshold)
				amp = nan
				WaveTransform zapNaNs amp
			EndIf
		EndIf

		//Fraction of first peak relative to the second peak
		If(!cmpstr(menu_Arbor,"OFF"))
			If(DimSize(amp,0) == 2)
				crossover[ds.wsi] = amp[0] / amp[1]
				firstPeak[ds.wsi] = amp[0]
				secPeak[ds.wsi] = amp[1]
			ElseIf(DimSize(amp,0) == 1)
				crossover[ds.wsi] = 0
				firstPeak[ds.wsi] = 0
				secPeak[ds.wsi] = amp[0]
			Else
				crossover[ds.wsi] = nan
				firstPeak[ds.wsi] = nan
				secPeak[ds.wsi] = nan
			EndIf
		Else
			If(DimSize(amp,0) == 2)
				crossover[ds.wsi] = amp[1] / amp[0]
				firstPeak[ds.wsi] = amp[0]
				secPeak[ds.wsi] = amp[1]
			ElseIf(DimSize(amp,0) == 1)
				crossover[ds.wsi] = 0
				firstPeak[ds.wsi] = amp[0]
				secPeak[ds.wsi] = 0
			Else
				crossover[ds.wsi] = nan
				firstPeak[ds.wsi] = nan
				secPeak[ds.wsi] = nan
			EndIf
		EndIf
					
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
	
	SetDataFolder $path
End


//Event-Triggered Average
Function NT_ETA(DS_Signals,DS_Stimulus,TimeWidth)
	String DS_Signals,DS_Stimulus
	Variable TimeWidth
	
	//Data set info structure
	STRUCT ds ds 
	
	//Fills the data set structure
	GetStruct(ds)
	
	//Reset wave set index
	ds.wsi = 0
	
	//only accept the first wave in the data set as a stimulus wave
	Wave stimulus = ds.waves[0][1]
	
	//Function Loop
	Do
		//declare each wave in the wave set
		Wave theWave = ds.waves[ds.wsi][0]
		
		//YOUR CODE GOES HERE....
		
		//Stimulus dimensions
		Variable xSize,ySize
		xSize = DimSize(stimulus,0)
		ySize = DimSize(stimulus,1)
		
		//Normalize the wave 0 to 1
		Duplicate/FREE theWave,signal
		Variable maxVal = WaveMax(signal)
		signal /= maxVal
		
		//Initialize the starting point for the analysis
		Variable startTm = DimOffset(stimulus,2) //time point when the stimulus began
		Variable tm = startTm + TimeWidth
		
		//Start and end points for the signal
		Variable tmPt = ScaleToIndex(signal,tm,0)
		
		Variable stimPt = ScaleToIndex(stimulus,tm,2)
		Variable endStimPt = ScaleToIndex(stimulus,startTm,2)
		
		Variable etaSize = stimPt - endStimPt
		
		//Make the event triggered average output wave
		Make/O/N=(xSize,ySize,etaSize)/O $(NameOfWave(theWave) + "_ETA")/Wave = eta
		CopyScales/P stimulus,eta
		
		Multithread eta = 0
		
		Variable count = 0
		Do
			//work backwards from start point for the time width
			Multithread eta += signal[tmPt] * stimulus[p][q][endStimPt + r]
			count += 1
			
			//move one time step ahead
			tmPt += 1
			
			If(tmPt > DimSize(signal,0) - 1)
				break
			EndIf
			
			//compute the point in the stimulus that is at the beginning of the time width
			Variable val = IndexToScale(signal,tmPt,0) - timeWidth
			
			endStimPt = ScaleToIndex(stimulus,val,2)
			
			If(endStimPt + DimSize(eta,2) > DimSize(stimulus,2) - 1)
				break
			EndIf
			
			
			
		While(1)
		
		eta /= count 
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
	
End



//Returns the angular difference (signed) between the linear motion and test stimuli (linear, turn90, or turnN90)
Function NT_AngularDiff(DS_LinearPD,DS_DataPD,menu_Range,menu_TurnType,filterTerm)
	String DS_LinearPD //linear PD (1 value per wave for each tuning curve)
	String DS_DataPD //test PD (1 value per wave for each tuning curve)
	
	//Drop down menu for the time range we're counting in - for wave naming purposes
	String menu_Range
	String menu_TurnType
	
	//This will filter out certain wavesets. If the string match fails on the first wave, it will skip that wave set
	String filterTerm
	
	String menu_Range_List = "early;late;all;"
	String menu_TurnType_List = "Linear;Turn90;TurnN90;"
	
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
	SetDataFolder $folder
	
	//Name of the output wave that will hold the results
	String diffName = "vDiff_" + menu_Range + "_" + StringsFromList("2-*",NameOfWave(ds.waves[0][1]),"_",noEnding=1)
	diffName = ReplaceListItem(2,diffName,"_","1",noEnding=1)
	diffName = ReplaceListItem(3,diffName,"_",menu_TurnType,noEnding=1)
	
	Make/O/N=(1) $diffName/Wave = diff
	
	//LINEAR DATA SET 
	Do
		//declare each wave in the wave set
		Wave linear = ds.waves[ds.wsi][0]
	
		//put all the angles into a single wave so we can average them with circular stats
		If(ds.wsi == 0) //FIRST PASS ONLY
			String compiledAngName = ReplaceListItem(2,NameOfWave(linear),"_","comp",noEnding=1)
			Make/O/N=(ds.numWaves[0],2) $compiledAngName /Wave=linearComp
		EndIf
				
		linearComp[ds.wsi] = linear[0]
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
	
	//TEST DATA SET
	ds.wsi = 0
	Do
		//declare each wave in the wave set
		Wave test = ds.waves[ds.wsi][1]
	
		//put all the angles into a single wave so we can average them with circular stats
		If(ds.wsi == 0) //FIRST PASS ONLY
			compiledAngName = ReplaceListItem(2,NameOfWave(test),"_","comp",noEnding=1)
			Make/O/N=(ds.numWaves[1],2) $compiledAngName /Wave=testComp
		EndIf
				
		testComp[ds.wsi] = test[0]
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[1])
	
	//fill radius columns
	linearComp[][1] = 1
	testComp[][1] = 1
	
	//convert to radians
	linearComp[][0] *= pi/180
	testComp[][0] *= pi/180
	
	//Compute the mean angles
	StatsCircularMeans/Z/Q linearComp
	Wave W_CircularMeans
	Variable linearMean = W_CircularMeans[2]
	
	StatsCircularMeans/Z/Q testComp
	Wave W_CircularMeans
	Variable testMean = W_CircularMeans[2]
	
	//Compute the signed difference between them
	diff = polarMath(linearMean,testMean,"rad","distance",1)
	
	//convert back to degrees
	diff *= 180/pi
	linearComp[][0] *= 180/pi
	testComp[][0] *= 180/pi
	
	Note diff, "Signed Angular Distance between:"
	Note diff,GetWavesDataFolder(linearComp,2)
	Note diff,GetWavesDataFolder(testComp,2)
End