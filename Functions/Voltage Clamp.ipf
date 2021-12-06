#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.


Function NT_FilterCurrents(DS_Waves,menu_Passband,Frequency)
	String DS_Waves,menu_Passband
	Variable Frequency //Hz
	
	String menu_Passband_List = "High-pass;Low-pass;"
	
	//SUBMENU=Voltage Clamp
	//TITLE=Filter Currents
		
//	Notes={
//	Performs a high or low pass filter with a cut-off at the indicated frequency.
// Creates a new filtered wave, will not overwrite original data.
//
// \f01Passband\f00 : High or low pass filter.
// \f01Frequency\f00 : Cut-off frequency.
//	}
	
	
	STRUCT ds ds
	GetStruct(ds)
	
	ds.wsi = 0
	
	Do
		Wave theWave = ds.waves[ds.wsi][%Waves]
		
		SetDataFolder GetWavesDataFolder(theWave,1)
		
		Duplicate/O theWave,$(NameOfWave(theWave) + "_filter")
		Wave filterWave = $(NameOfWave(theWave) + "_filter")
		
		//Get fraction of the sample frequency
		Variable sampleFreq = 1/DimDelta(theWave,0)
		Variable freqFraction = Frequency / sampleFreq
		
		If(freqFraction > 0.5)
			DoAlert 0,"Frequency must be lower than half the sampling frequency (" + num2str(sampleFreq) + " Hz)"
			return 0
		EndIf
		
		strswitch(menu_Passband)
			case "High-pass":
				FilterFIR/DIM=0/HI={freqFraction,freqFraction,301} filterWave
				Note filterWave,"Highpass filter: " + num2str(Frequency) + "Hz"
				break
			case "Low-pass":
				FilterFIR/DIM=0/Lo={freqFraction,freqFraction,301} filterWave
				Note filterWave,"Lowpass filter: " + num2str(Frequency) + "Hz"
				break
		endswitch
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[%Waves])

End

Function NT_ResampleCurrents(DS_Waves,Sample_Rate,cb_Overwrite)
	//SUBMENU=Voltage Clamp
	//TITLE=Resample Currents
	
	String DS_Waves
	Variable Sample_Rate,cb_Overwrite
	
//	Note={
//	Resamples voltage clamp data to the specified sample rate
//	
//	\f01Overwrite\f00 : Overwrites the wave with the resampled version when checked.
//		-Unchecked will create a new wave with the '_resample' suffix. 
//	}

	STRUCT ds ds
	GetStruct(ds)
	
	ds.wsi = 0
	
	Do
		Wave theWave = ds.waves[ds.wsi]
		
		If(!WaveExists(theWave))
			continue
		EndIf
		
		If(cb_Overwrite)
			Resample/RATE=(Sample_Rate) theWave
		Else
			Duplicate/O theWave,$(NameOfWave(theWave) + "_resample")
			Wave outWave = $(NameOfWave(theWave) + "_resample")
			Resample/RATE=(Sample_Rate) outWave
		EndIf

		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
End

Function NT_ExtractRange(DS_Waves,StartTime,EndTime)
	//SUBMENU=Voltage Clamp
	//TITLE=Extract Range
	
	String DS_Waves
	Variable StartTime,EndTime
	
	STRUCT ds ds
	GetStruct(ds)
	
	ds.wsi = 0
	Do
		Wave theWave = ds.waves[ds.wsi]
		
		If(EndTime < StartTime)
			Variable endPt = DimSize(theWave,0) - 1
		Else
			endPt = x2pnt(theWave,EndTime)
			endPt = (endPt > DimSize(theWave,0)) ? DimSize(theWave,0) - 1 : endPt
		EndIf
		
		Variable startPt = x2pnt(theWave,StartTime)

		Redimension/N=(endPt + 1) theWave //remove ending points first
		DeletePoints 0,startPt,theWave //remove starting points
		
		Variable actualStartTime = pnt2x(theWave,startPt)
		Variable actualEndTime = pnt2x(theWave,endPt)
		
		SetScale/I x,actualStartTime,actualEndTime,theWave
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
End

Function NT_SubtractLeak(DS_Waves,menu_Type,X1,X2,X3,X4,Extract_Start,Extract_End,Width)
	//SUBMENU=Voltage Clamp
	//TITLE=Subtract Leak
	
	String DS_Waves,menu_Type
	Variable X1,X2,X3,X4  //Defines the 4 points with which to perform the subtraction for zeroing the leak current during voltage step
	Variable Extract_Start,Extract_End //Defines the start and end points of the data extraction from the voltage step.
	Variable Width
	
	String menu_Type_List = "Exponential;Linear;"
	
//	Note={
//	Takes a voltage clamp recording, removes leak current, and extracts the currents
//		from the voltage step.
//	\f01Type\f00 : Type of fit to apply for subtracting the leak current. 
//	     -Exponential is usually best.
//	\f01X1,X2,X3\f00 : Define 3 time points for the fit
//	     -Place them just after the voltage step, somewhere before the light-evoked
//	     currents, and one right before the step back to the holding potential.
//	\f01Extract_Start\f00 : Start time point for extracting the current trace.
//	\f01Extract_End\f00 : End time point for extracting the current trace.
//	\f01Width\f00 : Width of an average measurement of the current for X1, X2, and X3
//	}

	STRUCT ds ds
	GetStruct(ds)
	
	//Turn off the debug on error
	DebuggerOptions debugOnError=0
	
	ds.wsi = 0
	
	Display/N=fitData as "fitData"
	
	Do
		Wave theWave = ds.waves[ds.wsi]
		
		If(!WaveExists(theWave))
			continue
		EndIf
		
		SetDataFolder GetWavesDataFolder(theWave,1)
		
		If(X1 < DimOffset(theWave,0))
			continue
		EndIf
		
		If(x2pnt(theWave,X4) > DimSize(theWave,0))
			continue
		EndIf
		
		//Make the weighting wave for the points being used
		Make/O/N=(DimSize(theWave,0))/B/U weights
		multithread weights = 0
		multithread	weights[x2pnt(theWave,X1)] = 1
		multithread weights[x2pnt(theWave,X2)] = 1
		multithread weights[x2pnt(theWave,X3)] = 1
		multithread weights[x2pnt(theWave,X4)] = 1

		//Make the y data wave that has the mean over the selected range
		Duplicate/O theWave,yData
		multithread yData[x2pnt(theWave,X1)] = mean(theWave,X1 - 0.5 * Width,X1 + 0.5 * Width)
		multithread yData[x2pnt(theWave,X2)] = mean(theWave,X2 - 0.5 * Width,X2 + 0.5 * Width)
		multithread yData[x2pnt(theWave,X3)] = mean(theWave,X3 - 0.5 * Width,X3 + 0.5 * Width)
		multithread yData[x2pnt(theWave,X4)] = mean(theWave,X4 - 0.5 * Width,X4 + 0.5 * Width)
		
		CopyScales theWave,yData,weights
		
		Variable startPt = x2pnt(theWave,Extract_Start)
		Variable endPt = x2pnt(theWave,Extract_End)
		
		//Perform the curve fit
		strswitch(menu_Type)
			case "Linear":
				AppendToGraph/W=fitData yData
				CurveFit/Q/X=1 line yData /M=weights/D
				break
			case "Exponential":
				AppendToGraph/W=fitData yData
				CurveFit/Q/L=(endPt - startPt +1) exp_XOffset yData[startPt,endPt] /M=weights/D
				
				break
		endswitch
		
		Wave/Z fit = fit_yData
		
		RemoveFromGraph/W=fitData yData
						
		//Do the subtraction
		Multithread theWave[startPt,EndPt] -= fit[p-startPt]
		
		//Extract the currents
		Variable P1 = x2pnt(theWave,Extract_Start)
		Variable P2 = x2pnt(theWave,Extract_End)
		
		Extract/O theWave,theWave,p>=P1 && p<=P2
		SetScale/I x,Extract_Start,Extract_End,theWave 
		
			
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
	
	//Cleanup
//	KillWindow/Z fitData	
	KillWaves/Z weights,fit_yData,fit,yData,W_sigma,W_fitConstants,W_coef
		
End

Function NT_EI_Ratio(DS_EPSC,DS_IPSC)
	//SUBMENU=Voltage Clamp
	//TITLE=EI Ratio

//	Note={
//	Calculates the E/I ratio using EPSC and IPSC waves of the same length.
//	}

	String DS_EPSC,DS_IPSC
	
	STRUCT ds ds
	GetStruct(ds)
	
	
	ds.wsi = 0
	Do
		Wave EPSC = ds.waves[ds.wsi][0]
		Wave IPSC = ds.waves[ds.wsi][1]
		
		String outName = NameOfWave(EPSC)
		outName = ReplaceListItem(0,outName,"_","EIRatio",noEnding=1)
		
		SetDataFolder GetWavesDataFolder(EPSC,1)
		
		Duplicate/O EPSC,$outName
		Wave ratio = $outName
		
		Multithread ratio = EPSC / IPSC
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves[0])
End

Function NT_STA(DS_Response,DS_Stimulus,DS_PeakX,DS_PeakY,reverseTime)
	//SUBMENU=Voltage Clamp
	//TITLE=Event Triggered Average
	
//	Note={
//	Calculates the event-triggered average from a current recording and a stimulus wave.
//	
//	Response: EPSC/IPSC recording
//	Stimulus: 3D wave of the visual stimulus that was presented. Make sure the stimulus
//	and response wave are scaled appropriately.
// DS_PeakX: 1D wave of the x positions for the identified peaks. Do multipeak fitting to find these.
// reverseTime: Time prior to each event to do the stimulus averaging
//	}
	String DS_Response,DS_Stimulus,DS_PeakX,DS_PeakY
	Variable reverseTime
	
	STRUCT ds ds
	GetStruct(ds)
	
	Variable i,j
	
	For(i=0;i<ds.numWaves[0];i+=1)
		Wave response = ds.waves[ds.wsi][%Response]
		Wave s = ds.waves[ds.wsi][%Stimulus]
		Wave e = ds.waves[ds.wsi][%eventX]
		Wave ey = ds.waves[ds.wsi][%eventY]
		
		Variable numEvents = DimSize(e,0)
		
		Variable numReverseFrames = ceil(reverseTime / DimDelta(s,2))
		
		Make/O/N=(DimSize(s,0),DimSize(s,1),numReverseFrames) root:STA/Wave=STA
		STA = 0
		
		Make/N=(numReverseFrames)/FREE frameCounts
		
		Variable maxEvent = WaveMax(ey)
		
		Duplicate/FREE ey,eventAmp
		eventAmp /= maxEvent
		
		For(j=0;j<numEvents;j+=1)
			Variable frame = 0
			Variable pastFrame = 0
			
			//frame for the event
			frame = ScaleToIndex(s,e[j],2)
			
			If(e[j] < 2 + reverseTime)
				pastFrame = ScaleToIndex(s,2,2)
			Else
				pastFrame = ScaleToIndex(s,e[j] - reverseTime,2)
			EndIf
			
			Variable startPos = numReverseFrames - (frame - pastFrame)
			
			frameCounts[startPos,*] += 1
			STA[][][startPos,*] += s[p][q][pastFrame + (r - startPos)] * eventAmp[j]
			
		EndFor
		
		STA /= frameCounts[r]

	EndFor
End

Function NT_STA2(DS_Response,DS_Stimulus,reverseTime)
	//SUBMENU=Voltage Clamp
	//TITLE=Event Triggered Average 2
	 
//	Note={
//	Calculates the event-triggered average from a current recording and a stimulus wave.
//	
//	Response: EPSC/IPSC recording
//	Stimulus: 3D wave of the visual stimulus that was presented. Make sure the stimulus
//	and response wave are scaled appropriately.
// DS_PeakX: 1D wave of the x positions for the identified peaks. Do multipeak fitting to find these.
// reverseTime: Time prior to each event to do the stimulus averaging
//	}
	String DS_Response,DS_Stimulus
	Variable reverseTime
	
	STRUCT ds ds
	GetStruct(ds)
	
	Variable i,j
	
	For(i=0;i<ds.numWaves[0];i+=1)
		Wave response = ds.waves[ds.wsi][%Response]
		Wave s = ds.waves[ds.wsi][%Stimulus]
				
		Variable numReverseFrames = ceil(reverseTime / DimDelta(s,2))
		
		Make/O/N=(DimSize(s,0),DimSize(s,1),numReverseFrames) root:STA/Wave=STA
		STA = 0
		
		Make/N=(numReverseFrames)/FREE frameCounts
				
		Variable maxEvent = wavemax(response,2,12)
		Variable xPos = 2.2
		
		Variable delta = 0.05
		
		Do
			Variable frame = 0
			Variable pastFrame = 0
			
			//frame for the event
			frame = ScaleToIndex(s,xPos,2)
			
			If(xPos < 2 + reverseTime)
				pastFrame = ScaleToIndex(s,2,2)
			Else
				pastFrame = ScaleToIndex(s,xPos - reverseTime,2)
			EndIf
			
			Variable startPos = numReverseFrames - (frame - pastFrame)
			Variable gain = response[frame] / maxEvent
			
			frameCounts[startPos,*] += 1
			Multithread STA[][][startPos,*] += s[p][q][pastFrame + (r - startPos)] * gain
			
			xPos += delta
		While(xPos < 12)
		
		STA /= frameCounts[r]

	EndFor
End