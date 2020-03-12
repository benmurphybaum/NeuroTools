#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//Runs the selected command
Function RunCmd_ImagingPackage(cmd)
	String cmd
	
	strswitch(cmd)
		case "Get ROI":
			Wave/WAVE out = NT_GetROI()
			break
		case "dF Map":
			Wave/WAVE out = NT_dFMap()
			break
	endswitch
End

//Create the controls for the imaging package
Function NT_Imaging_CreateControls()
	DFREF TP = root:Packages:twoP:examine
	
	//Make the Imaging package folder
	If(!DataFolderExists("root:Packages:NT:Imaging"))
		NewDataFolder root:Packages:NT:Imaging
	EndIf
	DFREF NTI = root:Packages:NT:Imaging
	
	//IMAGING PACKAGE-------------------
	
	//Get ROI
	
	//Lists from the 2PLSM package
	SVAR ROIListStr = TP:ROIListStr
	
	//Convert strings to list and select waves
	Variable numROIs = ItemsInList(ROIListStr,";")
	Make/O/T/N=(numROIs,1,3) NTI:ROIListWave /Wave = ROIListWave
	Make/O/N=(numROIs) NTI:ROISelWave /Wave = ROISelWave
	Wave/T textWave = StringListToTextWave(ROIListStr,";")
	ROIListWave = textWave	
	
	Wave/T ScanListWave = GetScanListWave()
	Make/O/N=(DimSize(ScanListWave,0)) NTI:ScanSelWave /Wave = ScanSelWave
	
	ListBox ScanListBox win=NT,pos={591,100},size={75,380},title="",listWave=ScanListWave,selWave=ScanSelWave,mode=4,proc=ntListBoxProc,disable=3
	ListBox ROIListBox win=NT,pos={668,100},size={75,380},title="",listWave=ROIListWave,selWave=ROISelWave,mode=4,proc=ntListBoxProc,disable=3
	Variable pos = 100
	
	PopUpMenu channelSelect win=NT,size={120,20},bodywidth=50,pos={461,pos},title="Channel",value="1;2;1/2;2/1;",disable=1	
	pos += 23
	PopUpMenu dFSelect win=NT,size={120,20},bodywidth=50,pos={461,pos},title="Mode",value="∆F/F;Abs;",disable=1
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
	SetVariable filterSize win=NT,size={120,20},bodywidth=40,pos={461,pos},limits={5,inf,2},title="Filter Size",value=_NUM:9,disable=1
	pos += 20
	
	//Some IMAGING structure SVARs that are needed
	String/G NTI:measure
	SVAR measure = NTI:measure 
	
	//Assign the controls to the Commands
	NT_Imaging_CreateControlLists()
End

//Assigns control variables to functions from the 'Command' pop up menu
Function NT_Imaging_CreateControlLists()
	DFREF NTF = root:Packages:NT
	Wave/T controlAssignments = NTF:controlAssignments 
	NVAR numMainCommands = NTF:numMainCommands
	
	//Resize for the Imaging package commands
	Redimension/N=(numMainCommands + 2,3) controlAssignments
	
	//IMAGING PACKAGE
	controlAssignments[numMainCommands][0] = "Get ROI"
	controlAssignments[numMainCommands][1] = "ScanListBox;ROIListBox;baselineSt;baselineEnd;peakSt;peakEnd;filterSize;channelSelect;dFSelect;"
	controlAssignments[numMainCommands][2] = "305"
	
	controlAssignments[numMainCommands+1][0] = "dF Map"
	controlAssignments[numMainCommands+1][1] = "ScanListBox;baselineSt;baselineEnd;peakSt;peakEnd;filterSize;channelSelect;dFSelect;"
	controlAssignments[numMainCommands+1][2] = "230"
	
	
End


//Get ROI ------------------------------------
Function/WAVE NT_GetROI()
	STRUCT IMAGING img
	
	DFREF TP = root:Packages:twoP:examine
	DFREF NTF = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	
	//Get the parameters from the GUI
	initParam(img)
	
	//Make the ROI analysis folder if it doesn't already exist
	If(!DataFolderExists("root:ROI_analysis"))
		NewDataFolder root:ROI_analysis
	EndIf
	SetDataFolder root:ROI_analysis	
	
	//Make the output wave reference wave for passing the result onto another function
	Make/FREE/WAVE/N=0 outputWaveRefs
	
	Variable i,j,k,totalWaveCount = 0
	
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
		
		For(j=0;j<img.roi.num;j+=1)
			String theROI = img.rois[j]
			
			
			String ROIFolder = "root:ROI_analysis:" + theROI
			
			If(!DataFolderExists(ROIFolder))
				NewDataFolder $ROIFolder
			EndIf
			
			//X and Y waves that define the ROI area
			Wave roiX = img.roi.x[j]
			Wave roiY  = img.roi.y[j]
		
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
			Smooth/S=2 (img.filter), ROI_Signal
			
			//Use median for the baseline, so it doesn't get pulled up or down from noisy values
			Variable	bsln = median(ROI_Bgnd,img.bsSt,img.bsEnd)
			
			//Absolute fluorescence or delta fluorescence?
			If(img.mode == 1)
			//∆F/F
				String outName = NameOfWave(theScan) + "_" + theROI + "_dF"
			ElseIf(img.mode == 2)
			//Abs
				outName = NameOfWave(theScan) +  theROI + "_" + "_abs"
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
						
			//These are all the output ROI waves
			Redimension/N=(totalWaveCount + 1) outputWaveRefs
			outputWaveRefs[totalWaveCount] = dF
			totalWaveCount += 1
		EndFor
		
		print "Get ROI:",NameOfWave(theScan) + ",",StopMSTimer(ref) / (1e6),"s"
		
	EndFor
	
	//pass the output wave on
	return outputWaveRefs
End

//Generates a pixel map of the peak ∆F/F or variant thereof
Function/WAVE NT_dFMap()
	STRUCT IMAGING img //Imaging package data structure
	
	DFREF TP = root:Packages:twoP:examine
	DFREF NTF = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	DFREF NTI = root:Packages:NT:Imaging
	
	//Initializes the structure that holds scan and ROI selection information
	initParam(img)
	
	//Which scans are selected?
	Wave/T ScanListWave = NTI:ScanListWave
	Wave ScanSelWave = NTI:ScanSelWave
	
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
		endswitch
		
		//Wave dimensions
		rows = DimSize(theScan,0)
		cols = DimSize(theScan,1)
		frames = DimSize(theScan,2)
		
		//Make time-varying dF Map Wave
		SetDataFolder GetWavesDataFolder(theScan,1)
		Make/O/N=(rows,cols,frames) $(NameOfWave(theScan) + suffix)/Wave = dF
		Make/O/N=(rows,cols) $(NameOfWave(theScan) + suffix + param)/Wave = dFMeasure
		
		//Remove extreme fluorescence values
		Variable cleanNoiseThresh = 2
		Wave theWave = CleanUpNoise(theScan,cleanNoiseThresh)	//threshold is in sdevs above the mean
		
		//Get dendritic mask
		Wave mask = GetDendriticMask(theBgnd)
		Redimension/B/U mask
			
		//Find average dark value
		ImageStats/R=mask/P=1 theWave
		Variable darkValue = 0.9*V_avg  //estimate dark value slightly low to avoid it accidentally surpassing the dendrite baseline fluorescence.
		
		//Operate on temporary waves so raw data is never altered.
		Duplicate/FREE/O theScan,theScanTemp
		Duplicate/FREE/O theBgnd,theBgndTemp
		
		//Spatial filter for each layer of the scan and bgnd channels.
		For(k=0;k<frames;k+=1)
			MatrixOP/O/FREE theLayer = layer(theScanTemp,k)
			MatrixFilter/N=(img.preFilter) median theLayer
			Multithread theScanTemp[][][k] = theLayer[p][q][0]
			
			MatrixOP/O/FREE theLayer = layer(theBgndTemp,k)
			MatrixFilter/N=(img.preFilter) median theLayer
			Multithread theBgndTemp[][][k] = theLayer[p][q][0]
		EndFor
		
		//Get baseline fluorescence maps
		Make/FREE/O/N=(rows,cols) scanBaseline,bgndBaseline
		Multithread scanBaseline = 0
		Multithread bgndBaseline = 0
		
		//Get the frame range for finding the peak dF
		Variable startLayer,endLayer
		startLayer = ScaleToIndex(theScanTemp,img.bsSt,2)
		endLayer = ScaleToIndex(theScanTemp,img.bsEnd,2)
		
		//Get the mean over the baseline region for the scan channel
		MatrixOP scanBaseline = sumBeams(theScanTemp[][][startLayer,endLayer])
		Multithread scanBaseline /= (endLayer - startLayer)
		
		//Get the mean over the baseline region for the background channel
		MatrixOP bgndBaseline = sumBeams(theBgndTemp[][][startLayer,endLayer])
		Multithread bgndBaseline /= (endLayer - startLayer)
		
		//Eliminates the possibility of zero values in the dataset for dendrites in the mask, which all get converted to NaN at the end.
		Multithread theScanTemp = (theScanTemp[p][q][r] == scanBaseline[p][q][0]) ? theScanTemp[p][q][r] + 1 : theScanTemp[p][q][r]
		
		//Calculate the ∆F map
		MultiThread dF = (theScanTemp[p][q][r] - scanBaseline[p][q][0]) / (bgndBaseline[p][q][0] - darkValue)
		
		//Temporal smoothing via Solgay-Gavitsky
		Smooth/S=2/DIM=2 img.filter,dF
		
		//Calculate the specified ∆F map measurement
		For(j=0;j<rows;j+=1)
			For(k=0;k<cols;k+=1)
							
				//only operates if the data is within the mask region to save time.
				If(mask[i][j] != 1)
					continue
				EndIf
				
				//Get the beam for each x/y pixel
				MatrixOP/FREE/O/S theBeam = Beam(dF,i,j)
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
		
		CopyScales/I theScan,dF,dFMeasure
		
		//Masking and final filtering
		MatrixFilter/N=(img.postFilter)/R=mask median dF
		MatrixFilter/N=(img.postFilter)/R=mask median dFMeasure
		Multithread dF *= mask[p][q][0]
		Multithread dFMeasure *= mask
		
		Variable m
		For(m=0;m<2;m+=1)
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
		
		print StopMSTimer(ref)
	EndFor
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

//Returns a mask wave for the input scan
Function/WAVE GetDendriticMask(theWave)
	Wave theWave
	
	//Get max projection image
	MatrixOP/S/O maxProj = sumBeams(theWave)
	ImageStats maxProj
	
	//Min/max of the image
	Variable minVal = V_min
	Variable maxVal = WaveMax(maxProj)
	
	//Simple value thresholding based on those values
	Variable threshold = minVal + (maxVal - minVal) * 0.05 //1.25 is a mask threshold and can be changed
	Multithread maxProj = (maxProj < threshold) ? 0 : maxProj
	
	//Eliminate isolated points
	Make/FREE/N=(5,5) block
	block = 0
	
	Variable rows,cols,i,j
	
	rows = DimSize(maxProj,0)
	cols = DimSize(maxProj,1)
	
	For(i=0;i<rows;i+=1)	
		For(j=0;j<cols;j+=1)
			//skip zeros
			If(maxProj[i][j] == 0)
				continue
			EndIf			
	
			//check for image edges
			If(i-2 < 0 || i+2 > rows-2 || j-2 < 0 || j+2 > cols-2)
				continue
			Else
				//Get data block surrounding point
				block = maxProj[i-2 + p][j-2 + q]
				
				//Check for isolated point
				If(sum(block) < 3*maxProj[i][j])
					maxProj[i][j] = 0
				EndIf	
			EndIf
		
			block = 0
		EndFor
	EndFor
	
	//2D median filter 3x3
	MatrixFilter/N=3 median maxProj
	
	//Create mask wave
	String maskName = NameOfWave(theWave) + "_mask"
	If(strlen(maskName) > 31)
		maskName = "Scan_mask"
	EndIf
	
	Make/O/N=(rows,cols)/FREE theMask
	MultiThread theMask = (maxProj == 0) ? 0 : 1
	
	//Scaling
	SetScale/P x,DimOffset(theWave,0),DimDelta(theWave,0),theMask
	SetScale/P y,DimOffset(theWave,1),DimDelta(theWave,1),theMask
	
	return theMask
End

//Returns ROI parameters to the calling function (Get ROI)
Function initParam(img)
	STRUCT IMAGING &img
	
	DFREF RF = root:twoP_ROIS
	DFREF TP = root:Packages:twoP:examine
	DFREF NTI = root:Packages:NT:Imaging
	
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
	SVAR img.measure = NTI:measure 
	img.measure = S_Value
	
	//ROI ListBox list and select waves
	Wave/T ROIListWave = NTI:ROIListWave
	Wave ROISelWave =  NTI:ROISelWave
	
	Wave/T ScanListWave = NTI:ScanListWave
	Wave ScanSelWave = NTI:ScanSelWave
	
	img.roi.num = sum(ROISelWave)
	img.scan.num = sum(ScanSelWave)
	
	//active ROIs used for the analsis and their position wave references
	Make/O/N=(img.roi.num)/T NTI:ROI_List_Analysis
	Make/O/N=(img.roi.num)/WAVE NTI:ROI_Coord_X
	Make/O/N=(img.roi.num)/WAVE NTI:ROI_Coord_Y
	
	Wave/T img.rois = NTI:ROI_List_Analysis
	Wave/WAVE img.roi.x = NTI:ROI_Coord_X
	Wave/WAVE img.roi.y = NTI:ROI_Coord_Y
	
	//active Scans channels used for the analysis
	Make/O/N=(img.scan.num)/WAVE NTI:Scan_List_Ch1
	Make/O/N=(img.scan.num)/WAVE NTI:Scan_List_Ch2
	Wave/WAVE/Z img.scan.ch1 = NTI:Scan_List_Ch1
	Wave/WAVE/Z img.scan.ch2 = NTI:Scan_List_Ch2
	
	//Check that there is a selection at all for scans and rois
	Variable i = 0
	If(DimSize(ROISelWave,0) == 0 || img.roi.num == 0 || img.scan.num == 0)
		Redimension/N=0 img.rois,img.scan.ch1,img.scan.ch2,img.roi.x,img.roi.y
		return 0
	EndIf
	
	//Fill out all the ROI name and get their position waves
	Variable count = 0
	Do
		If(ROISelWave[i] == 1)
			img.rois[count] = ROIListWave[i]
			img.roi.x[count] = RF:$(img.rois[count] + "_x")
			img.roi.y[count] = RF:$(img.rois[count] + "_y")
			count += 1
		EndIf
		i += 1
	While(i < DimSize(ROISelWave,0))
	
	//Fill out all the scan waves
	count = 0;i = 0
	Do
		If(ScanSelWave[i] == 1)
			img.scan.ch1[count] = $("root:twoP_Scans:" + ScanListWave[i] + ":" + ScanListWave[i] + "_ch1")
			img.scan.ch2[count] = $("root:twoP_Scans:" + ScanListWave[i] + ":" + ScanListWave[i] + "_ch2")
			count += 1
		EndIf
		i += 1
	While(i < DimSize(ScanSelWave,0))
	
End

//Makes and fills the scan list wave for use in the list box
Function/WAVE GetScanListWave()
	DFREF TP = root:twoP_Scans
	DFREF NTI = root:Packages:NT:Imaging
	
	If(!DataFolderRefStatus(TP))
		return $""
	EndIf
	
	Variable i,numFolders = CountObjectsDFR(TP,4)
	
	Make/O/T/N=(numFolders,1,3) NTI:ScanListWave /Wave = listWave
	
	For(i=0;i<numFolders;i+=1)
		listWave[i] = GetIndexedObjNameDFR(TP,4,i)
	EndFor
	
	return listWave
End

//Holds parameters of the ROIs for call by functions
Structure IMAGING
	STRUCT ROI roi
	STRUCT SCAN scan
	uint16 channel
	uint16 mode
	uint16 bsSt
	uint16 bsEnd
	uint16 pkSt
	uint16 pkEnd
	uint16 filter
	uint16 preFilter
	uint16 postFilter
	SVAR measure
	Wave/T rois
EndStructure

Structure ROI
	Wave/WAVE x
	Wave/WAVE y
	uint16 num
EndStructure

Structure SCAN
	Wave/WAVE ch1
	Wave/WAVE ch2
	uint16 num
EndStructure