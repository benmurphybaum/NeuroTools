#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//SCAN REGISTRY FUNCTIONS
///////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////

Function NT_GetSliderValue()
	Variable sliderVal
	ControlInfo/W=NT SR_phase
	return V_Value
End

Function/S GetTemplateList()
	String cdf
	
	cdf = GetDataFolder(1)
	If(!DataFolderExists("root:Packages:NT:ScanImage:Registration"))
		NewDataFolder root:Packages:NT:ScanImage:Registration
	EndIf
	SetDataFolder root:Packages:NT:ScanImage:Registration
	
	String templateList = WaveList("template*",";","DIMS:2")
	If(!strlen(templateList))
		templateList = "None"
	EndIf
	
	SetDataFolder cdf
	return templateList
	
End


Function NT_ScanRegistryButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	STRUCT ds ds
	
	String windowName,errStr
	
	Variable i,j,k
	String roiNameY,roiNameX
	
	DFREF NTSR = root:Packages:NT:ScanImage:Registration
	
	Wave coordinates = NTSR:roiCoord
	SVAR roiXlist = NTSR:roiXlist
	SVAR roiYlist = NTSR:roiYlist
	NVAR hidden = NTSR:hidden
	
	switch( ba.eventCode )
		case 2: // mouse up
			strswitch(ba.ctrlName)
				case "SR_autoRegisterButton":
					ControlInfo/W=NT SR_autoRegisterButton
					String info = StringByKey("title",S_recreation,"=",",")
			
					If(strlen(info) > 10)
						info = info[0,10]
					EndIf
			
					If(StringMatch(info,"*Auto*"))
					
						//Finds the image wave, and display a max projection of it
						NT_SetupROICapture()
						
						Button SR_autoRegisterButton win=NT,title="Done",fColor=(65535,32764,16385)
						Button SR_addROIButton win=NT,disable=0
					//	Button SR_saveWaveformButton win=ScanRegistry,disable = 1
					//	Button SR_applyTemplate win=ScanRegistry, disable = 1
						NT_SR_Message(1)
						//Make text message to select ROIs for registry alignment. 
						//
					ElseIf(StringMatch(info,"*Done*"))
						Button SR_autoRegisterButton win=NT,title="Auto",fColor=(0,0,0)
						Button SR_addROIButton win=NT,disable=1
						//Trim ROI coordinates wave of its extra column
						
						Wave coordinates = root:Packages:NT:ScanImage:Registration:roiCoord
						Variable size = DimSize(coordinates,1)
						If(size == 0)
							Redimension/N=(4,1) coordinates
							size = 1
						EndIF
						
						MatrixOP/O/FREE result = sum(col(coordinates,size-1))
						
						If(result[0] == 0)
							Redimension/N=(-1,size - 1) coordinates
						EndIf
						NT_SR_Message(2)
						
						String images = ImageNameList("GalvoDistortion",";")
						images = StringFromList(0,images,";")
						
						
						If(!strlen(images))
							NT_SR_Message(4)
							return 0
						EndIf
						
						Wave maxProj = ImageNameToWaveRef("GalvoDistortion",images)
						Wave imageWave = $(GetWavesDataFolder(maxProj,1) + RemoveEnding(ParseFilePath(1,images,"_",1,0),"_"))
					
						If(!WaveExists(imageWave))
							NT_SR_Message(4)
							return 0
						EndIf
						
						//Register image
						NT_AutoRegister(imageWave,"GalvoDistortion")
						
					//	Button SR_saveWaveformButton win=ScanRegistry,disable = 0
					//	Button SR_applyTemplate win=ScanRegistry, disable = 0
					EndIf
					
					break
				case "SR_addROIButton":					
					Wave coordinates = root:Packages:NT:ScanImage:Registration:roiCoord
					If(!WaveExists(coordinates))
						Make/N=(4,1) root:Packages:NT:ScanImage:Registration:roiCoord /Wave=coordinates
					EndIf
					
					//Add column to coordinate wave to hold next ROI
					Redimension/N=(-1,DimSize(coordinates,1) + 1) coordinates
					SR_addROI("GalvoDistortion")
					break
				case "SR_reset":
					//Erases ROI lists
					For(i=0;i<ItemsInList(roiYlist,";");i+=1)
						roiNameY = StringFromList(i,roiYlist,";")
						roiNameX = StringFromList(i,roiXlist,";")
						DoWindow GalvoDistortion
						If(V_flag)
							RemoveFromGraph/Z $roiNameY
						EndIf
						
						KillWaves/Z $("root:Packages:NT:ScanImage:Registration:" + roiNameY)
						KillWaves/Z $("root:Packages:NT:ScanImage:Registration:" + roiNameX)
					EndFor
					
					roiXlist = ""
					roiYlist = ""
					
					//Resets to zero selected ROIs
					Redimension/N=(4,1) coordinates
					coordinates = 0
					
					//Resets button titles
					Button SR_autoRegisterButton win=NT,title="Auto",fColor=(0,0,0)
					Button SR_addROIButton win=NT,disable=1
				//	Button SR_saveWaveformButton win=ScanRegistry,disable = 0
				//	Button SR_applyTemplate win=ScanRegistry, disable = 0
					NT_SR_Message(5)
					break
				case "SR_showROIButton":
		
					If(hidden)
						ModifyGraph/Z/W=GalvoDistortion hideTrace = 0
						hidden = 0
					Else	
						ModifyGraph/Z/W=GalvoDistortion hideTrace = 1
						hidden = 1
					EndIf
					break
					
				case "SR_saveTemplateButton":
					//Saves the template waveform so it can be reapplied to other images
					
					SetDataFolder root:Packages:NT:ScanImage:Registration
					String templateName = UniqueName("template",1,0)
					Wave template = root:Packages:NT:ScanImage:Registration:template
					Duplicate/O template,$templateName
					
										
					SVAR templateList = root:Packages:NT:ScanImage:Registration:templateList
					templateList = GetTemplateList()
					PopUpMenu SR_templatePopUp win=NT,value=#"root:Packages:NT:ScanImage:Registration:templateList"
					break
				case "SR_applyTemplate":
					
					//Get the images that will be adjusted
					GetDataSetInfo(ds)
					
					//Get the template that defines the adjustment
					ControlInfo/W=NT SR_templatePopUp
					wave template = $("root:Packages:NT:ScanImage:Registration:" + S_Value)
					
					DFREF saveDF = GetDataFolderDFR()
					DFREF NTSR = root:Packages:NT:ScanImage:Registration
					ds.wsi = 0
					Do
						//Current image
						Wave imageWave = ds.waves[ds.wsi]
						
						SetDataFolder GetWavesDataFolder(imageWave,1)
						
						//Image parameters
						Variable xDelta,yDelta,xOffset,yOffset,xSize,ySize,zSize
	
						xDelta = DimDelta(imageWave,0)
						xOffset = DimOffset(imageWave,0)
						xSize = DimSize(imageWave,0)
						yDelta = DimDelta(imageWave,1)
						yOffset = DimOffset(imageWave,1)
						ySize = DimSize(imageWave,1)
						zSize = DimSize(imageWave,2)
						
						//Make the starting grid, which is unwarped
						Make/O/D/N=(xSize,ySize) NTSR:xs /Wave = xs
						Make/O/D/N=(xSize,ySize) NTSR:ys /Wave = ys

						xs = p*xSize/(xSize)
						ys = q*ySize/(ySize)
		
						//Make destination grid, which is warped according to template sine wave
						Make/O/D/N=(xSize,ySize) NTSR:xd /Wave = xd
						Make/O/D/N=(xSize,ySize) NTSR:yd /Wave = yd
						
						xd = xs + template
						yd = ys //+ template

						//Makes wave to hold each layer of the stack
						Duplicate/O/FREE imageWave,theLayer
						Redimension/N=(-1,-1,0) theLayer
				
						//New name for the output wave; 'reg' stands for registered.
						//Duplicate/O imageWave,$(NameOfWave(imageWave) + "_reg")
						Wave correctedImage = imageWave //$(NameOfWave(imageWave) + "_reg")
						
						//Apply the template to fix the galvo distortion
						For(i=0;i<zSize;i+=1)
							theLayer[][] = imageWave[p][q][i]
							ImageInterpolate/wm=1/sgrx=xs/sgry=ys/dgrx=xd/dgry=yd warp theLayer
							Wave correctedLayer = M_InterpolatedImage
							correctedImage[][][i] = correctedLayer[p][q][0]
						EndFor
						
						ds.wsi += 1
					While(ds.wsi < ds.numWaves[0])
					
					SetDataFolder saveDF
					
					break
				case "SR_getRefScan":
					String list = StringFromList(0,getSelectedItems(),";")
					If(WaveDims($list) < 2)
						list = ""
					EndIf
					SetVariable SR_referenceImage win=NT,value=_STR:StringFromList(0,list,";")
					break
			endswitch
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function NT_ScanRegistryPopUpProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			strswitch(pa.ctrlName)
				case "SR_waveList":
					Variable popNum = pa.popNum
					String popStr = pa.popStr
					DoWindow/F $popStr
					String imageList = ImageNameList(popStr,";")
					
					If(strlen(imageList) != 0)
						Wave theImage = ImageNameToWaveRef(popStr,StringFromList(0,ImageNameList(popStr,";")))
					Else
						print "No images on graph"
						return -1
					EndIf
					
					SetDataFolder GetWavesDataFolder(theImage,1)
					break
				case "SR_templatePopUp":	
			
					SVAR templateList = root:Packages:NT:ScanImage:Registration:templateList
					templateList = GetTemplateList()
					PopUpMenu SR_templatePopUp win=NT,value=#"root:Packages:NT:ScanImage:Registration:templateList"
			
					break
			endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function NT_ScanRegistrySliderProc(sa) : SliderControl
	STRUCT WMSliderAction &sa

	switch( sa.eventCode )
		case -1: // control being killed
			break
		default:
			if( sa.eventCode & 1 ) // value set
				Variable curval = sa.curval
				SetVariable SR_phaseVal win=NT,value=_NUM:curval
				
				String images = ImageNameList("GalvoDistortion",";")
				images = StringFromList(0,images,";")
				Wave scanWave = ImageNameToWaveRef("GalvoDistortion",images)
		
			
				Variable phase,pixelOffset,pixelDelta,divergence,frequency
				phase = curval*pi/180
				ControlInfo/W=NT SR_pixelDelta
				pixelDelta = V_Value
				ControlInfo/W=NT SR_divergence
				divergence = V_Value
				ControlInfo/W=NT SR_frequency
				frequency = V_Value
				Controlinfo/W=NT SR_pixelOffset
				pixelOffset = V_Value
				CorrectScanRegister(scanWave,pixelOffset,pixelDelta,phase,frequency,divergence)
			endif
			break
	endswitch

	return 0
End

Function NT_ScanRegistryVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			
			String images = ImageNameList("GalvoDistortion",";")
			images = StringFromList(0,images,";")
			Wave scanWave = ImageNameToWaveRef("GalvoDistortion",images)
			
//			Wave scanWave = $(GetWavesDataFolder(imageWave,1) + RemoveEnding(ParseFilePath(1,images,"_",1,0),"_"))
					
			Variable phase,pixelOffset,pixelDelta,divergence,frequency
			ControlInfo/W=NT SR_phase
			phase = V_Value*pi/180
			ControlInfo/W=NT SR_pixelDelta
			pixelDelta = V_Value
			ControlInfo/W=NT SR_divergence
			divergence = V_Value
			ControlInfo/W=NT SR_frequency
			frequency = V_Value
			Controlinfo/W=NT SR_pixelOffset
			pixelOffset = V_Value
			
			CorrectScanRegister(scanWave,pixelOffset,pixelDelta,phase,frequency,divergence)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function/WAVE NT_SetupROICapture()
	String imageName
	String errStr
	
	//Gets the intended image wave using the wave selector menu
	STRUCT ds ds
	GetDataSetInfo(ds)
	
	If(DimSize(ds.waves,0) == 0)
		NT_SR_Message(4)
		return $""
	EndIf
	
	//Image wave exists?
	If(!WaveExists(ds.waves[0]))
		NT_SR_Message(4)
		return $""	
	EndIf
	 
	//Create a max projection of the image wave, display it
	Wave maxProj = MeanProjection(ds.waves[0])	
				
	//Open a new image window with the target image
	KillWindow/Z GalvoDistortion
	NewImage/N=GalvoDistortion maxProj

	return ds.waves[0]
End


Function/S SR_addROI(theWindow)
	String theWindow

	DFREF NTSR =  root:Packages:NT:ScanImage:Registration
	SVAR roiXlist = NTSR:roiXlist
	SVAR roiYlist = NTSR:roiYlist
	
	If(!WaveExists(NTSR:roiCoord))
		Make/N=(4,1) NTSR:roiCoord
	EndIf
	
	Wave coordinates = NTSR:roiCoord
	Variable numROIs = DimSize(coordinates,1) - 1
		
	GetMarquee/K/W=$theWindow/Z left,top
	
	coordinates[0][numROIs - 1] = V_left
	coordinates[1][numROIs - 1] = V_top
	coordinates[2][numROIs - 1] = V_right
	coordinates[3][numROIs - 1] = V_bottom
	
	String roiNameX = "ROIx_" + num2str(ItemsInList(roiXlist,";") + 1)
	roiXlist += roiNameX + ";"
	String roiNameY = "ROIy_" + num2str(ItemsInList(roiYlist,";") + 1)
	roiYlist += roiNameY + ";"
	
	Make/O/N=5 NTSR:$roiNameX = {V_left,V_right,V_right,V_left,V_left}
	Wave roiXwave = NTSR:$roiNameX
	Make/O/N=5  NTSR:$roiNameY = {V_bottom,V_bottom,V_top,V_top,V_bottom}
	Wave roiYwave = NTSR:$roiNameY

	AppendToGraph/W=$theWindow/L/T roiYwave vs roiXwave
	
	ModifyGraph/W=$theWindow rgb=(0,65535,65535)
End



Function NT_SR_Message(code)
	Variable code
	String message
	
	DrawAction/W=NT delete,getgroup=GalvoDistortionMessage
	
	switch(code)
		case 1:
			message = "Select ROIs using the marquee tool"
			break
		case 2:
			message = "Registering image"
			DrawAction/W=NT delete,getgroup=GalvoDistortionMessage
			break
		case 3:
			message = "More than 1 image on the graph"
			break
		case 4:
			message = "Image wave cannot be found"
			break
		case 5:
			message = ""
			break
	endswitch
	
	SetDrawEnv/W=NT fsize=10,fstyle=(2^1),textxjust=0,gstart,gname=GalvoDistortionMessage
	DrawText/W=NT 33,304,message
	SetDrawEnv/W=NT gstop
End

Function NT_AutoRegister(imageWave,windowName)
	Wave imageWave
	String windowName

	Variable error,rows,cols,left,right,top,bottom,i,j,k,m,numROIs,count,endPt
	
	DFREF NTSR = root:Packages:NT:ScanImage:Registration
	Wave coordinates = NTSR:roiCoord
	
	
	Variable timeRef = StartMSTimer
	
	numROIs = DimSize(coordinates,1)
	
	//errorWave keeps track of error minimization
	Make/O/N=1000 NTSR:errorWave /Wave = errorWave
	errorWave = 0
	
	//Original values for the image correction
	Variable pixelOffset,pixelDelta,phase,frequency,divergence
	Variable finalPixelOffset,finalPixelDelta,finalPhase,finalFrequency,finalDivergence
	
	//Some defaults initial values that are probably close to the right answer
	ControlInfo/W=NT SR_pixelDelta
	pixelDelta = V_Value
	
	ControlInfo/W=NT SR_pixelOffset
	pixelOffset = V_Value
				
	ControlInfo/W=NT SR_frequency
	frequency = V_Value
	
	ControlInfo/W=NT SR_phase
	phase = V_Value*pi/180
		
	ControlInfo/W=NT SR_divergence
	divergence = V_Value	
	//pixelOffset = -8
	//pixelDelta = 0
	//phase = 45*pi/180
	//frequency = 0.6
	//divergence = -1
	
	DFREF saveDF = GetDataFolderDFR()
	SetDataFolder NTSR
	
	//Is this an image stack?
	If(DimSize(imageWave,2) > 0)
		MatrixOP/O/S maxProj = sumBeams(imageWave)
		Wave maxProj = maxProj
		SetScale/P x,DimOffset(imageWave,0),DimDelta(imageWave,0),maxProj
		SetScale/P y,DimOffset(imageWave,1),DimDelta(imageWave,1),maxProj
		Wave imagewave = maxProj
//		NewImage imageWave
	EndIf
	
	Wave correctedImage = imageWave	
	
	//Get ROI coordinates in index
	Duplicate/O coordinates,NTSR:roiCoordScale
	Wave coordinates_Scale = NTSR:roiCoordScale
	Redimension/N=(6,-1) coordinates_Scale
	
	For(i=0;i<numROIs;i+=1)
		coordinates_Scale[0][i] = ScaleToIndex(imageWave,coordinates_Scale[0][i],0)//left
		coordinates_Scale[1][i] = ScaleToIndex(imageWave,coordinates_Scale[1][i],1)//top
		coordinates_Scale[2][i] = ScaleToIndex(imageWave,coordinates_Scale[2][i],0)//right
		coordinates_Scale[3][i] = ScaleToIndex(imageWave,coordinates_Scale[3][i],1)//bottom
		coordinates_Scale[4][i] = 	abs(coordinates_Scale[2][i] - coordinates_Scale[0][i])//rows
		
		If(stringmatch(windowName,"twoPscanGraph*"))
			coordinates_Scale[5][i] = 	abs(coordinates_Scale[1][i] - coordinates_Scale[3][i]) //cols
		Else
			coordinates_Scale[5][i] = 	abs(coordinates_Scale[3][i] - coordinates_Scale[1][i])//cols
		EndIf
		
		String dataName,peakName
		dataName = "data_" + num2str(i)
		peakName = "peaks_" + num2str(i)
	
		If(stringmatch(windowName,"twoPscanGraph*"))
			Make/O/N=(coordinates_Scale[4][i],coordinates_Scale[5][i]) $dataName = correctedImage[p + coordinates_Scale[0][i]][q + coordinates_Scale[3][i]]
		Else
			Make/O/N=(coordinates_Scale[4][i],coordinates_Scale[5][i]) $dataName = correctedImage[p + coordinates_Scale[0][i]][q + coordinates_Scale[1][i]]
		EndIf
		
		Make/O/N=(coordinates_Scale[5][i]) $peakName
	EndFor
	
	For(m=0;m<4;m+=1)
		count = 0
		
		If(m == 0)
			//pixel delta
			Redimension/N=50 errorWave
			endPt = 50
			ControlInfo/W=NT SR_pixelDeltaLock
			If(V_Value)
				continue
			Else
				pixelDelta = 0
			EndIf
		ElseIf(m == 1)
			//frequency
			Redimension/N=50 errorWave
			endPt = 50
		
			ControlInfo/W=NT SR_frequencyLock
			If(V_Value)
				continue
			Else
				frequency = 0.3	
			EndIf
		ElseIf(m == 2)	
			//pixel offset
			Redimension/N=60 errorWave
			endpt = 60
			ControlInfo/W=NT SR_pixelOffsetLock
			If(V_Value)
				continue
			Else
				pixelOffset = -15
			EndIf
		ElseIf(m == 3)
			//phase
			Redimension/N=100 errorWave
			endPt = 100
			ControlInfo/W=NT SR_phaseLock
			If(V_Value)
				continue
			Else
				phase = 0
			EndIf
		EndIf
		
		For(k=0;k<endPt;k+=1)
			//error will accumulate over each ROI, then the program will adjust parameters
			//in an attempt to find the parameters that minimize error. 
			error = 0
			For(i=0;i<numROIs;i+=1)
				//Get the updated ROI data
				dataName = "data_" + num2str(i)
				peakName = "peaks_" + num2str(i)
				Wave data = $dataName
				Wave peaks = $peakName
				
				If(stringmatch(windowName,"twoPscanGraph*"))
					data = correctedImage[p + coordinates_Scale[0][i]][q + coordinates_Scale[3][i]]
				Else
					data = correctedImage[p + coordinates_Scale[0][i]][q + coordinates_Scale[1][i]]
				EndIf
				//We'll be registering left/right shifts, so stepping through columns
				
				//Find peak intensity in each row of each ROI, calculate positional differences in peaks across rows.
				For(j=0;j<coordinates_Scale[5][i];j+=1)
					MatrixOP/O/FREE colData = col(data,j)
					WaveStats/Q colData
					peaks[j] = V_maxloc
					
					If(j > 0)
						error += abs(peaks[j-1] - peaks[j])
					EndIf
				EndFor
	
			EndFor
		
			errorWave[count] = error
			count += 1
		
	
			//update variables to new values
			If(m == 0)
				pixelDelta += 1
			ElseIf(m == 1)
				frequency += 0.01
			ElseIf(m == 2)
				pixelOffset += 0.5
			ElseIf(m == 3)
				phase += 1*pi/180
			EndIf
			
			Wave correctedImage = CorrectScanRegister(imageWave,pixelOffset,pixelDelta,phase,frequency,divergence)
		
		EndFor
		
		//Set the parameter to its minimum error value
		If(m == 0)
			WaveStats/Q/R=[1,DimSize(errorWave,0)] errorWave
			pixelDelta = V_minloc
		ElseIf(m == 1)
			WaveStats/Q/R=[1,DimSize(errorWave,0)] errorWave
			frequency = 0.3 + V_minloc*0.01
		ElseIf(m == 2)
			WaveStats/Q/R=[1,DimSize(errorWave,0)] errorWave
			pixelOffset = -15 + V_minloc*0.5
		ElseIf(m == 3)
			WaveStats/Q/R=[1,DimSize(errorWave,0)] errorWave
			phase = (V_minloc)*pi/180
		EndIf
		//Reset errorWave
		errorWave = 0
	EndFor	
	
	//Final correction with minimum parameter error values
	Wave correctedImage = CorrectScanRegister(imageWave,pixelOffset,pixelDelta,phase,frequency,divergence)
	
	error = 0
	//Kill ROI data waves
	For(i=0;i<numROIs;i+=1)
		dataName = "data_" + num2str(i)
		peakName = "peaks_" + num2str(i)
		Wave data = $dataName
		Wave peaks = $peakName
		
		If(stringmatch(windowName,"twoPscanGraph*"))
			data = correctedImage[p + coordinates_Scale[0][i]][q + coordinates_Scale[3][i]]
		Else
			data = correctedImage[p + coordinates_Scale[0][i]][q + coordinates_Scale[1][i]]
		EndIf	
		//We'll be registering left/right shifts, so stepping through columns
				
		//Get final error value from optimized parameters
		For(j=0;j<coordinates_Scale[5][i];j+=1)
			MatrixOP/O/FREE colData = col(data,j)
			WaveStats/Q colData
			peaks[j] = V_maxloc
					
			If(j > 0)
				error += abs(peaks[j-1] - peaks[j])
			EndIf
		EndFor
		
		KillWaves/Z data,peaks
	EndFor
	
	SetDataFolder saveDF
	
	print "------------"
	print "Image registration: " + NameOfWave(imageWave)
	SetVariable SR_pixelOffset win=NT,value=_NUM:pixelOffset
	print "Pixel Offset = ",pixelOffset
	SetVariable SR_pixelDelta win=NT,value=_NUM:pixelDelta
	print "Pixel Delta = ",pixelDelta
	SetVariable SR_frequency win=NT,value=_NUM:frequency
	print "Frequency = ",frequency
	Slider SR_phase win=NT,value=phase*180/pi
	SetVariable SR_phaseVal win=NT,value=_NUM:NT_GetSliderValue()
	print "Phase = ",phase*180/pi
	print "Error = ",error
	NT_SR_Message(5)
	Variable totalTime = StopMSTimer(timeRef)
	print "Time = ", totalTime/1000000," s"
	NewImage correctedImage
End

Function/WAVE CorrectScanRegister(scanWave,pixelOffset,pixelDelta,phase,frequency,divergence)
	Wave scanWave
	Variable pixelOffset,pixelDelta,phase,frequency,divergence
	//divergence is 1 if even columns shift positively and odd columns shift negatively
	//divergence is -1 if even columns shift negatively and odd columns shift positively
	
	DFREF NTSR = root:Packages:NT:ScanImage:Registration
	
	Variable xDelta,yDelta,xOffset,yOffset,xSize,ySize,i
	
	xDelta = DimDelta(scanWave,0)
	xOffset = DimOffset(scanWave,0)
	xSize = DimSize(scanWave,0)
	yDelta = DimDelta(scanWave,1)
	yOffset = DimOffset(scanWave,1)
	ySize = DimSize(scanWave,1)
	
	//abort if no scanwave is found
	If(numtype(xDelta) == 2)
		abort
	EndIf
	
	//Make template wave for register adjustment

	Make/O/N=(xSize,ySize) NTSR:template /Wave = template 
	template = 0
	
	//Creates the sine wave for the image correction. The second equation works much better when the constant pixel offset
	For(i=0;i<ySize;i+=1)
		If(mod(i,2) == 0)
			//template = 0.5*pixelDelta + 0.5*pixelDelta*sin((1/xSize)*(2*pi)*(x-(phase)*xSize/(2*pi)))
	//		template[][i] =  divergence*0.5*pixelDelta*sin((frequency/xSize)*(2*pi)*(x-(phase)*xSize/(2*pi)))
			template[][i] = pixelOffset + divergence*0.5*pixelDelta*sin((frequency/xSize)*(2*pi)*(x-(phase)*xSize/(2*pi)))
		Else
			//template[][i] = pixelOffset - divergence*0.5*pixelDelta*sin((frequency/xSize)*(2*pi)*(x-(phase)*xSize/(2*pi)))
		EndIf
	EndFor
	
	
	//Make source grid with the images original scaling
	Make/O/D/N=(xSize,ySize) NTSR:xs /Wave= xs
	Make/O/D/N=(xSize,ySize) NTSR:ys /Wave= ys
	
	xs = p*xSize/(xSize)
	ys = q*ySize/(ySize)
	
	//Make destination grid, which is warped according to template sine wave
	Make/O/D/N=(xSize,ySize) NTSR:xd /Wave=xd
	Make/O/D/N=(xSize,ySize) NTSR:yd /Wave=yd
	
	xd = xs + template
	yd = ys //+ template
	
	//xs=p*imagerows/(gridRows-1)
	//ys=q*imageCols/(gridCols-1)
	//ImageInterpolate/RESL={4500,4500}/TRNS={radialPoly,1,0,0,0} Resample scanWave
	DFREF saveDF = GetDataFolderDFR()
	SetDataFolder NTSR
	
	ImageInterpolate/wm=1/sgrx=xs/sgry=ys/dgrx=xd/dgry=yd warp scanWave
	
	Wave correctedImage = M_InterpolatedImage	
	
	SetDataFolder saveDF
	
	return correctedImage
End

///////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////