#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function SI_LoadScans(path,file)
	String path,file
	
	STRUCT SI SI
	
	Variable fileRef
	
	Variable ref = StartMSTimer	
	
	//Make the data folder to hold the scan waves
	path = ReplaceString("/",path,":")
	String folder = "root:Scans:" + RemoveEnding(file,".tif")
	
	If(!DataFolderExists("root:Scans"))
		NewDataFolder root:Scans
	EndIf
	
	If(!DataFolderExists(folder))
		NewDataFolder $folder
	EndIf
	
	SetDataFolder $folder
	
	//Open the file
	path = RemoveEnding(path,":") + ":" //ensures ending colon
	NewPath/O/Q image,path
	Open/P=image/R fileRef as file
	
	//Read binary data, little endian, 64 bit integer (8 byte)
	String str = ""
	Variable var
	
	//IFD HEADER OFFSET
	Variable IFD_HEADER_OFFSET
	FSetPos fileRef,8
	FBinRead/B=3/F=2 fileRef,IFD_HEADER_OFFSET
	
	FSetPos fileRef,IFD_HEADER_OFFSET
	str = PadString(str,2,0)
	FBinRead/B=3/F=2 fileRef,str


	//STATIC METADATA
	Variable pos = 16
	
	//Magic # - confirms this is a scanimage big tiff file
	FSetPos fileRef,pos
	FBinRead/B=3/F=3/U fileRef,SI.magic
	
	pos += 4 //20
	FSetPos fileRef,pos
	FBinRead/B=3/F=3/U fileRef,SI.version
	
	pos += 4 //24
	FSetPos fileRef,pos
	FBinRead/B=3/F=3/U fileRef,SI.frameDataLength
	
	pos += 4 //28
	FSetPos fileRef,pos
	FBinRead/B=3/F=3/U fileRef,SI.roiDataLength
	
	//Non-Varying Frame Data
	pos += 4 //32
	
	//Get the Non-Varying Frame Data (HEADER)
	Wave/T header = SI_GetHeader(fileRef,SI.frameDataLength,pos)

	//Get the ROI Group Data (HEADER)
//	String/G root:roiStr 
//	SVAR roiStr = root:roiStr

	pos += SI.frameDataLength
	str = ""
	String roiStr = PadString(str,SI.roiDataLength,0)
	FSetPos fileRef,pos
	FBinRead/B=3/F=3/U fileRef,roiStr
	
	//Extracts the ROI data
	Wave/WAVE roiWaveRefs = GetROIData(roiStr,file,header)
	
	//Use the first ROI wave to get the number of ROIs
	If(DimSize(roiWaveRefs,0) > 0)
		Wave ROI = roiWaveRefs[0]
		Variable index = FindDimLabel(ROI,0,"ROIs")
		If(index != -2)
			Variable numROIs = ROI[index]
		EndIf
	EndIf
	
	Close/A
	
	//Native Igor load of the tiff
	String fullPath = path + file
	ImageLoad/O/T=tiff/S=0/BIGT=1/C=-1/Q/LR3D fullPath
	
	Wave theImage = $(folder + ":'" + file + "'")
	
	SetDataFolder GetWavesDataFolder(theImage,1)
	
	Variable frame,numFrames = DimSize(theImage,2)
	String zs = ReplaceString(" ",GetSIParam("SI.hStackManager.zs",header),";")
	zs = ReplaceString("]",ReplaceString("[",zs,""),";")
	
	//Number of ROIs determines how many waves will be created
	Variable i
	String baseName = RemoveEnding(file,".tif")
	
	Variable prevZ,Z,offsetY,offsetZ,numZs
	numZs = ItemsInList(zs,";")
	prevZ = -1
	offsetY = -1
	offsetZ = 0
	For(i=0;i<numROIs;i+=1)
		Wave theROI = roiWaveRefs[i]
		Variable xPixels = theROI[FindDimLabel(theROI,0,"XPixels")]
		Variable yPixels = theROI[FindDimLabel(theROI,0,"YPixels")]
		Variable frames = theROI[FindDimLabel(theROI,0,"Frames")]
		
		If(frames > numFrames)
			frames = numFrames
		EndIf
		
		String ROIname = baseName + "_R" + num2str(i)
		Make/N=(xPixels,yPixels,frames)/O/W $ROIname/Wave=scanROI

		SetScale/I x,ROI[0] - (ROI[2] / 2),ROI[0] + (ROI[2] / 2),scanROI
		SetScale/I y,ROI[1] - (ROI[3] / 2),ROI[1] + (ROI[3] / 2),scanROI
		SetScale/P z,0,ROI[11],scanROI
		
		//Get the z plane of the scan ROI, and it's frame offset
		String Zstr = num2str(theROI[4])
		Z = str2num(Zstr)
		
		//Put the frames into the output waves
		offsetZ = WhichListItem(Zstr,zs,";")
		If(Z == prevZ)
			offsetY = YPixels
			Multithread scanROI[][][] = theImage[p][offsetY + q][offsetZ + r * numZs]
		Else
			offsetY = 0
			Multithread scanROI[][][] = theImage[p][offsetY + q][offsetZ + r * numZs]
		EndIf
		
		prevZ = Z
		offsetY += yPixels
	EndFor

	KillWaves/Z theImage
	print StopMSTimer(ref) / (1e6)
End

Structure SI
	uint32 magic
	uint32 version
	uint32 frameDataLength
	uint32 roiDataLength
	uint16 LINE_FORMAT_VERSION
	uint16 TIFF_FORMAT_VERSION
EndStructure


Function OpenFile(path,file)
	String path,file
	STRUCT SI SI
	Variable fileRef
	
	Variable ref = StartMSTimer	
	
	//Open the file
	path = RemoveEnding(path,":") + ":" //ensures ending colon
	NewPath/O/Q image,path
	Open/P=image/R fileRef as file
	
	//Read binary data, little endian, 64 bit integer (8 byte)
	String str = ""
	Variable var
	
	
	Variable IFD_HEADER_OFFSET
	
	//IFD HEADER OFFSET
	FSetPos fileRef,8
	FBinRead/B=3/F=2 fileRef,IFD_HEADER_OFFSET
	
	FSetPos fileRef,IFD_HEADER_OFFSET
	str = PadString(str,2,0)
	FBinRead/B=3/F=2 fileRef,str


	//STATIC METADATA
	Variable pos = 16
	
	//Magic # - confirms this is a scanimage big tiff file
	FSetPos fileRef,pos
	FBinRead/B=3/F=3/U fileRef,SI.magic
	
	pos += 4 //20
	FSetPos fileRef,pos
	FBinRead/B=3/F=3/U fileRef,SI.version
	
	pos += 4 //24
	FSetPos fileRef,pos
	FBinRead/B=3/F=3/U fileRef,SI.frameDataLength
	
	pos += 4 //28
	FSetPos fileRef,pos
	FBinRead/B=3/F=3/U fileRef,SI.roiDataLength
	
	//Non-Varying Frame Data
	pos += 4 //32
	
	//Get the Non-Varying Frame Data (HEADER)
	Wave/T header = SI_GetHeader(fileRef,SI.frameDataLength,pos)

	//Get the ROI Group Data (HEADER)
	String/G root:roiStr 
	SVAR roiStr = root:roiStr
	roiStr = ""
	pos += SI.frameDataLength
	str = ""
	roiStr = PadString(str,SI.roiDataLength,0)
	FSetPos fileRef,pos
	FBinRead/B=3/F=3/U fileRef,roiStr
	
	//Extracts the ROI data
	Wave/WAVE roiWaveRefs = GetROIData(roiStr,file,header)
	
	//Use the first ROI wave to get the number of ROIs
	If(DimSize(roiWaveRefs,0) > 0)
		Wave ROI = roiWaveRefs[0]
		Variable index = FindDimLabel(ROI,0,"ROIs")
		If(index != -2)
			Variable numROIs = ROI[index]
		EndIf
	EndIf
	
	pos = IFD_HEADER_OFFSET
	
	//How many IFD headers are there?
	Variable NUM_IFD_HEADERS
	FSetPos fileRef,pos
	FBinRead/B=3/F=6 fileRef,NUM_IFD_HEADERS
	
	//IFD TAGS
	Variable IMAGE_WIDTH,IMAGE_LENGTH,BITS_PER_SAMPLE_FIELD,COMPRESSION,PHOTOMETRIC,IMAGE_DESCR_LOC,STRIP_OFFSET,SOFTWARE_LOC,ARTIST_LOC
	Variable ORIENTATION,SAMPLES_PER_PIXEL,ROWS_PER_STRIP,STRIP_BYTE_COUNT,X_RES,X_RES2,Y_RES,Y_RES2,PLANAR_CONFIG,RES_UNIT,SAMPLE_FORMAT
	
	String IMAGE_DESCR,SOFTWARE,ARTIST
	
	Variable IFD_TAG,IFD_DATATYPE,IFD_DATACOUNT,NEXT_IFD = 0
	Variable i,j,frames = 0
	
	NEXT_IFD = IFD_HEADER_OFFSET + 8
	
	
	
	//Make the folders to hold the output images
	String scanName = RemoveEnding(file,".tif")
	
	If(!DataFolderExists("root:Scans"))
		NewDataFolder root:Scans
	EndIf
	
	String folder = "root:Scans:" + RemoveEnding(file,".tif")
	If(!DataFolderExists(folder))
		NewDataFolder $folder
	EndIf
	
	
	//Get number of frames from the HEADER
	//This may be the number of volumes if FAST Z is used
	index = tableMatch("SI.hFastZ.enable",header)
	If(index == -1)
		return 0
	EndIf
	
	//Number of Z planes taken (slices)
	index = tableMatch("SI.hStackManager.numSlices",header)
	If(index == -1)
		return 0
	Else
		Variable numSlices = str2num(header[index][1])
	EndIf
	
	//Is Fast Z being used? If it is, number of volumes will be the numFrames
	Variable fastZEnabled = bool2int(header[index][1])
	
	If(fastZEnabled && numSlices > 1)
		index = tableMatch("SI.hFastZ.numVolumes",header)
	Else
		index = tableMatch("SI.hStackManager.framesPerSlice",header)
	EndIf
	
	If(index == -1)
		return 0
	Else
		Variable numFrames = str2num(header[index][1])
	EndIf
	
	numFrames = 50
	
	Do
		
		For(i=0;i<NUM_IFD_HEADERS;i+=1)
		
			pos = NEXT_IFD + 20 * i
			
			//IFD Tag
			FSetPos fileRef,pos
			FBinRead/B=3/F=2/U fileRef,IFD_TAG
			
			//Data type
			pos += 2
			FSetPos fileRef,pos
			FBinRead/B=3/F=2/U fileRef,IFD_DATATYPE
			
			//Data Count
			pos += 2
			FSetPos fileRef,pos
			FBinRead/B=3/F=6 fileRef,IFD_DATACOUNT
			
			//Set to data position
			pos += 8
			FSetPos fileRef,pos
			
			switch(IFD_TAG)
				case 256: //image width
					FBinRead/B=3/F=2/U fileRef,IMAGE_WIDTH
					break
				case 257: //image length
				
					//Each ROI is appended onto IMAGE_LENGTH,
					//and can be divided up according to ROI data
					FBinRead/B=3/F=2/U fileRef,IMAGE_LENGTH
					break
				case 258: //bits per sample
					FBinRead/B=3/F=2/U fileRef,BITS_PER_SAMPLE_FIELD
					break
				case 259: //compression
					FBinRead/B=3/F=2/U fileRef,COMPRESSION
					break
				case 262: //photometric interpretation
					FBinRead/B=3/F=2/U fileRef,PHOTOMETRIC 
					break
				case 270: //image description
					FBinRead/B=3/F=2/U fileRef,IMAGE_DESCR_LOC
					IMAGE_DESCR = ""
					IMAGE_DESCR = PadString(str,IFD_DATACOUNT,0)
					FSetPos fileRef,IMAGE_DESCR_LOC
					FBinRead/B=3/F=2 fileRef,IMAGE_DESCR
					break
				case 273: //strip offets
					FBinRead/B=3/F=3/U fileRef,STRIP_OFFSET
					break
				case 274: //orientation
					FBinRead/B=3/F=2/U fileRef,ORIENTATION
					break
				case 277: //samples per pixel
					FBinRead/B=3/F=2/U fileRef,SAMPLES_PER_PIXEL
					break
				case 278: //rows per strip
				
					//Each Z plane is appended onto IMAGE_WIDTH,
					//and can be divided up according to ROWS_PER_STRIP
					FBinRead/B=3/F=2/U fileRef,ROWS_PER_STRIP
					break
				case 279: //strip byte count
					FBinRead/B=3/F=2/U fileRef,STRIP_BYTE_COUNT
					break
				case 282: //X resolution
					FBinRead/B=3/F=3/U fileRef,X_RES
					pos += 4
					FSetPos fileRef,pos
					FBinRead/B=3/F=3/U fileRef,X_RES2
					X_RES = X_RES / X_RES2
					break
				case 283: //Y resolution
					FBinRead/B=3/F=3/U fileRef,Y_RES
					pos += 4
					FSetPos fileRef,pos
					FBinRead/B=3/F=3/U fileRef,Y_RES2
					Y_RES = Y_RES / Y_RES2
					break
				case 284: //Planar Configuration
					FBinRead/B=3/F=2/U fileRef,PLANAR_CONFIG
					break
				case 296: //Resolution unit
					FBinRead/B=3/F=2/U fileRef,RES_UNIT
					break
				case 305: //Software Package (Non-Varying Frame MetaData)
					SOFTWARE = ""
					SOFTWARE = PadString(SOFTWARE,IFD_DATACOUNT,0)
					FBinRead/B=3/F=2/U fileRef,SOFTWARE_LOC
					FSetPos fileRef,SOFTWARE_LOC
					FBinRead/B=3/F=2 fileRef,SOFTWARE
					
					break
				case 315: //Artist Field (ROI Group MetaData offset)
					ARTIST = ""
					ARTIST = PadString(ARTIST,IFD_DATACOUNT,0)
					FBinRead/B=3/F=2/U fileRef,ARTIST_LOC
					FSetPos fileRef,ARTIST_LOC
					FBinRead/B=3/F=2 fileRef,ARTIST
					break
				case 339: //Sample Format
					FBinRead/B=3/F=2/U fileRef,SAMPLE_FORMAT
					break
			endswitch
		EndFor
		
		//Final section of the IFD HEADER - where is the next header (frame) located?	
		pos += 8
		FSetPos fileRef,pos
		FBinRead/B=3/F=6/U fileRef,NEXT_IFD 
		NEXT_IFD += 8
		
		//************Note, image width and height might not be the same for every ROI. This load protocol will only work for resonant MROI mode,...
		//************...where the scan width is the same for every ROI. Need to add support for linear G-G scans, etc. 
		//LOAD EACH IMAGE FRAME 
		
		Variable length = ROWS_PER_STRIP / numROIs
		
		GBLoadWave/Q/T={BITS_PER_SAMPLE_FIELD,BITS_PER_SAMPLE_FIELD}/S=(STRIP_OFFSET)/P=image/B=1/W=1/U=(IMAGE_WIDTH * IMAGE_LENGTH)/A=inputFrame file
		
		Wave theFrame = $("root:inputFrame0")
		Redimension/N=(IMAGE_WIDTH,IMAGE_LENGTH) theFrame
		
		Make/O/W/N=(IMAGE_WIDTH,IMAGE_LENGTH,numFrames) root:theImage
		Wave theImage = root:theImage
		Multithread theImage[][][frames] = theFrame[p][q][0]
		
		//Divide the frame into its various ROI waves
//		Variable ROI_WIDTH,ROI_HEIGHT,zPlane,startCol = 0,startRow
//		For(i=0;i<numROIs;i+=1)
//			Wave ROI = roiWaveRefs[i]
//			ROI_WIDTH = ROI[6]
//			ROI_HEIGHT = ROI[7]
//			
//			startRow = 0
//			For(zPlane=0;zPlane<numSlices;zPlane+=1)
//				//Make the Scan wave for the ROI
//				Make/O/W/N=(ROI_WIDTH,ROI_HEIGHT,numFrames) $(folder + ":" + scanName + "_R" + num2str(i) + "_Z" + num2str(zPlane))
//				Wave theImage = $(folder + ":" + scanName + "_R" + num2str(i) + "_Z" + num2str(zPlane))
//				
//				startRow += ROWS_PER_STRIP
//			EndFor
//			
//			Multithread theImage[][][frames] = theFrame[p][q + startCol][0]
//			
//			startCol += ROI_HEIGHT
//			
//			//Set scales on last pass
//			If(frames == numFrames - 1)
//				SetScale/P x,ROI[0] - (ROI[2] / 2),ROI[9],theImage
//				SetScale/P y,ROI[1] - (ROI[3] / 2),ROI[10],theImage
//				SetScale/P z,0,ROI[11],theImage
//			EndIf
//		EndFor
		
		KillWaves/Z theFrame //kill the frame
		
		frames += 1	
		
	//Final IFD tag reads NEXT_IFD = 0, but we 8 bytes to this
	While(NEXT_IFD > 8) 
	
	//Close the file
	Close fileRef
	
	print StopMSTimer(ref)/(1e6),"s"
	
	If(frames != numFrames)
		Abort "There may have been an error in loading the scan: " + file + "\nThe number of frames loaded did not match the header" 
	EndIf
End


//Returns the ScanImage Big Tiff HEADER from the open file reference
Function/WAVE SI_GetHeader(fileRef,length,offset)
	Variable fileRef,length,offset
	
	FStatus fileRef
	If(!DataFolderExists("root:Scans"))
		NewDataFolder root:Scans
	EndIf
	
	String folder = "root:Scans:" + RemoveEnding(S_fileName,".tif")
	If(!DataFolderExists(folder))
		NewDataFolder $folder
	EndIf
	
	Variable i = 0
	
	//Set position to start of HEADER
	FSetPos fileRef,offset
	
	//Read in the binary data into the correctly sized string for the number of bytes in the header
	String str = ""
	str = PadString(str,length,0)
	FBinRead/B=3/F=3 fileRef,str
	
	String param = GetSIParamStr()
	
	Make/O/N=(ItemsInList(param,";"),2)/T $(folder + ":ScanInfo")
	Wave/T header = $(folder + ":ScanInfo")
	
	For(i=0;i<ItemsInList(param,";");i+=1)
		header[i][0] = StringFromList(i,param,";")
		header[i][1] = StringByKey(StringFromList(i,param,";"),str," = ","\n")
	EndFor
	
	return header
End

//Extracts the position,rotation, z plane, etc. data for all ROIs, puts into ROI output wave
Function/WAVE GetROIData(roiStr,file,header)
	String roiStr,file
	Wave/T/Z header
	
	If(!DataFolderExists("root:Scans"))
		NewDataFolder root:Scans
	EndIf
	
	String folder = "root:Scans:" + RemoveEnding(file,".tif")
	If(!DataFolderExists(folder))
		NewDataFolder $folder
	EndIf
		
	Variable imagingROIpos,photoStimROIpos,integrationROIpos
	imagingROIpos = strsearch(roiStr,"imagingRoiGroup",0)
	photoStimROIpos = strsearch(roiStr,"photostimRoiGroups",0)
	integrationROIpos = strsearch(roiStr,"integrationRoiGroup",0)
	
	JSONXOP_Parse roiStr
	Variable jsonID = V_Value
	
	
	//Type of JSON object (array or object, depending on if there are >1 ROI)
	JSONXOP_GetType jsonID, "RoiGroups/imagingRoiGroup/rois"
	
	//How many ROIs are we extracting?
	If(V_Value)
		JSONXOP_GetArraySize jsonID,"RoiGroups/imagingRoiGroup/rois"
		Variable numROI = V_Value
		String roiPath = "RoiGroups/imagingRoiGroup/rois/"
	Else
		numROI = 1
		roiPath = "RoiGroups/imagingRoiGroup/rois"
	EndIf
	
	Variable i,j,k
	
	
	//Wave reference wave that will hold the ROI data waves
	Make/FREE/WAVE/N=(numROI) roiWaveRefs
	
	For(i=0;i<numROI;i+=1)
	
		If(numROI > 1)
			String roiFullPath = roiPath + num2str(i)
		Else
			roiFullPath = roiPath
		EndIf
			
		JSONXOP_GetKeys jsonID,roiFullPath,keys
		
		//Will hold the ROI data
		Make/O/N=16 $(folder + ":ROI_" + num2str(i))
		Wave ROI = $(folder + ":ROI_" + num2str(i))
		
		JSONXOP_GetKeys jsonID,roiFullPath + "/scanfields",scanKeys
	
		//Get Z plane of each ROI
		JSONXOP_GetValue/V jsonID,roiFullPath + "/zs"
		ROI[4] = V_Value
		
		//Single plane ROIs, or volumetric ROIs
		JSONXOP_GetValue/V jsonID,roiFullPath + "/discretePlaneMode"
		ROI[15] = V_Value
		
		For(k=0;k<DimSize(scanKeys,0);k+=1)
			strswitch(scanKeys[k])

				case "centerXY": //Rows 0-1 in the ROI wave
					Wave wv = JSON_GetWave(jsonID,roiFullPath + "/scanfields/" + scanKeys[k])
					ROI[0,1] = wv[p]
					break
				case "sizeXY":	//Rows 2-3 in the ROI wave
					Wave wv = JSON_GetWave(jsonID,roiFullPath + "/scanfields/" + scanKeys[k])
					ROI[2,3] = wv[p-2]
					break
				case "rotationDegrees": //Row 5 in the ROI wave
					JSONXOP_GetValue/V jsonID,roiFullPath + "/scanfields/" + scanKeys[k]
					ROI[5] = V_Value
					break
				case "pixelResolutionXY": //Rows 6-7 in the ROI wave
					Wave wv = JSON_GetWave(jsonID,roiFullPath + "/scanfields/" + scanKeys[k])
					ROI[6,7] = wv[p-6]
					break
				case "enable": //Row 13 in the ROI wave
					JSONXOP_GetValue/V jsonID,roiFullPath + "/scanfields/" + scanKeys[k]
					ROI[13] = V_Value
					break					
			endswitch
		EndFor
		
		
		ROI[9] = ROI[2] / ROI[6]  //microns per pixel X
		ROI[10] = ROI[3] / ROI[7]  //microns per pixel Y
		
		
		Variable index = tableMatch("SI.hStackManager.framesPerSlice",header)
		If(index != -1)
			ROI[8] = str2num(header[index][1])  //number of frames per slice
		EndIf
		
		index = tableMatch("SI.hStackManager.numSlices",header)
		If(index != -1)
			ROI[8] *= str2num(header[index][1])  //number of frames total
		EndIf
//		
//		index = tableMatch("SI.hRoiManager.scanFramePeriod",header)
//		If(index != -1)
//			ROI[11] = str2num(header[index][1])  //seconds per frame
//		EndIf
		
		index = tableMatch("SI.hRoiManager.scanVolumeRate",header)
		If(index != -1)
			ROI[12] = str2num(header[index][1])  //volume rate
			ROI[11] = 1 / ROI[12] //seconds per volume
		EndIf
		
		ROI[14] = numROI	  //number of ROIs in the scan
		
		//Label the ROI waves
		SetDimLabel 0,0,CenterX,ROI
		SetDimLabel 0,1,CenterY,ROI
		SetDimLabel 0,2,SizeX,ROI
		SetDimLabel 0,3,SizeY,ROI
		SetDimLabel 0,4,Z,ROI
		SetDimLabel 0,5,Rotation,ROI
		SetDimLabel 0,6,XPixels,ROI
		SetDimLabel 0,7,YPixels,ROI
		SetDimLabel 0,8,Frames,ROI
		SetDimLabel 0,9,XScale,ROI
		SetDimLabel 0,10,YScale,ROI
		SetDimLabel 0,11,TimeScale,ROI
		SetDimLabel 0,12,FrameRate,ROI
		SetDimLabel 0,13,Enable,ROI
		SetDimLabel 0,14,ROIs,ROI
		SetDimLabel 0,15,DiscretePlane,ROI
		
		
		roiWaveRefs[i] = ROI
	EndFor
	
	
	//cleanup
	KillWaves/Z wv
			
	JSONXOP_Release jsonID
	
	//return wave reference wave holding all ROI data
	return roiWaveRefs
End

//Returns integer 1 or 0 for true or false input string
Function bool2int(String bool)
	If(!cmpstr(bool,"true"))
		return 1
	ElseIf(!cmpstr(bool,"false"))
		return 0
	Else
		//bad input
		return -1
	EndIf
End

//Structure SI
	STRUCT hStackManager hStackManager
	STRUCT hUserFunctions hUserFunctions
	STRUCT hWSConnector hWSConnector
	STRUCT hWaveformManager hWaveformManager
	STRUCT hScan2D hScan2D
	STRUCT hRoiManager hRoiManager
	STRUCT hPmts hPmts
	STRUCT hPhotostim hPhotostim
	STRUCT hMotors hMotors
	STRUCT hMotionManager hMotionManager
	STRUCT hIntegrationRoiManager hIntegrationRoiManager
	STRUCT hFastZ hFastZ
	STRUCT hDisplay hDisplay
	STRUCT hCycleManager hCycleManager
	STRUCT hChannels hChannels
	STRUCT hConfigurationSaver hConfigurationSaver
	STRUCT hBeams hBeams
	
	uint32 magic
	uint32 version
	uint32 frameDataLength
	uint32 roiDataLength
	uint16 LINE_FORMAT_VERSION
	uint16 TIFF_FORMAT_VERSION
	SVAR VERSION_COMMIT
	SVAR VERSION_MAJOR
	uint16 VERSION_MINOR
  	SVAR acqState
   uint16	 acqsPerLoop
	SVAR extTrigEnable	
	SVAR imagingSystem
	uint16 loopAcqInterval
	uint16 objectiveResolution
EndStructure

Structure hStackManager
	uint16 framesPerSlice
	uint16 numSlices
	uint16 shutterCloseMinZStepSize
	uint16 slowStackWithFastZ //bool
	uint16 stackReturnHome //bool
	uint16 stackSlicesDone
	uint16 stackStartCentered //bool
	uint16 stackZEndPos
	uint16 stackZStartPos
	uint16 stackZStepSize
	uint16 stageDependentZs //bool
	uint16 stepSizeLock //bool
	uint16 zPowerReference
	Wave zs
EndStructure

Structure hUserFunctions
	Wave userFunctionsCfg
	Wave userFunctionsUsr
	Wave optimizedScanners
EndStructure

Structure hWSConnector
	uint16 communicationTimeout
	uint16 enable //bool
EndStructure

Structure hWaveformManager
	Wave optimizedScanners
EndStructure

Structure hScan2D
	float beamClockDelay
	uint16 beamClockExtend
	uint16 bidirectional //bool
	Wave channelOffsets //4 rows
	Wave channels
	uint16 channelsAdcResolution
	uint16 channelsAutoReadOffsets //bool
	uint16 channelsAvailable
	SVAR channelsDataType
	SVAR channelsFilter
	Wave channelsInputRanges //4 row, 2 col
	Wave channelsSubtractOffsets //4 row bools
	float fillFractionSpatial
	float fillFractionTemporal
	float flybackTimePerFrame
	float flytoTimePerScanfield
	Wave fovCornerPoints //4 row, 2 col
	uint16 hasResonantMirror // bool
	uint16 hasXGalvo // bool
	uint16 keepResonantScannerOn
	uint16 linePhase
	SVAR linePhaseMode
	uint16 logAverageFactor
	uint16 logFramesPerFile
	uint16 logFramesPerFileLock //bool
	uint16 logOverwriteWarn //bool
	Wave mask
	Wave maskDisableAveraging //4 row
	float maxSampleRate
	SVAR name
	Wave nominalFovCornerPoints //4 row, 2 col
	uint16 pixelBinFactor
	float sampleRate
	SVAR scanMode
	float scanPixelTimeMaxMinRatio
	float scanPixelTimeMean
	float scannerFrequency
	Wave scannerToRefTransform //3 row, 3 col
	SVAR scannerType
	uint16 settleTimeFraction
	uint16 simulated //bool
	uint16 stripingEnable //bool
	SVAR trigAcqEdge
	SVAR trigAcqInTerm
	SVAR trigNextEdge
	SVAR trigNextInTerm
	uint16 trigNextStopEnable //bool
	SVAR trigStopEdge
	SVAR trigStopInTerm
	uint16 uniformSampling //bool
	uint16 useNonlinearResonantFov2VoltsCurve //bool
	
EndStructure

Structure hRoiManager
	uint16 forceSquarePixelation //bool
	uint16 forceSquarePixels //bool
	uint16 imagingFovDeg
	uint16 imagingFovUm
	float linePeriod
	uint16 linesPerFrame
	uint16 mroiEnable
	uint16 pixelsPerLine
	uint16 scanAngleMultiplierFast
	uint16 scanAngleMultiplierSlow
	uint16 scanAngleShiftFast
	uint16 scanAngleShiftSlow
	float scanFramePeriod
	float scanFrameRate
	uint16 scanRotation
	SVAR scanType
	float scanVolumeRate
	uint16 scanZoomFactor
EndStructure

Structure hPmts
	uint16 autoPower
	uint16 bandwidths
	uint16 gains
	uint16 names
	uint16 offsets
	uint16 powersOn
	uint16 tripped
EndStructure

Structure hPhotostim
	uint16 allowMultipleOutputs //bool
	uint16 autoTriggerPeriod
	uint16 compensateMotionEnabled //bool
	uint16 completedSequences
	float laserActiveSignalAdvance
	Wave lastMotion //2 row
	uint16 logging //bool
	uint16 monitoring //bool
	uint16 monitoringSampleRate
	uint16 nextStimulus
	uint16 numOutputs
	uint16 numSequences
	uint16 sequencePosition
	uint16 sequenceSelectedStimuli
	SVAR status
	uint16 stimImmediately
	uint16 stimSelectionAssignment
	SVAR stimSelectionDevice
	uint16 stimSelectionTerms
	uint16 stimSelectionTriggerTerm
	uint16 stimTriggerTerm
	SVAR stimulusMode
	uint16 syncTriggerTerm
	SVAR zMode
EndStructure

Structure hMotors
	uint16 azimuth
	Wave backlashCompensation //3 row
	Wave dimNonblockingMoveInProgress //3 row
	uint16 elevation
	uint16 motorFastMotionThreshold
	Wave motorPosition //3 row floats
	Wave motorPositionTarget //3 row floats
	uint16 motorStepLimit
	Wave motorToRefTransform //3x3
	Wave motorToRefTransformAbsolute //3x3
	uint16 motorToRefTransformValid //bool
	uint16 nonblockingMoveInProgress //bool
	Wave scanimageToMotorTF //4x4
	uint16 userDefinedPositions
EndStructure

Structure hMotionManager
	Wave correctionBoundsXY //2 row signed
	Wave correctionBoundsZ //2 row signed
	SVAR correctionDeviceXY
	SVAR correctionDeviceZ
	uint16 correctionEnableXY //bool
	uint16 correctionEnableZ //bool
	SVAR correctorClassName
	uint16 enable
	SVAR estimatorClassName
	uint16 motionHistoryLength
	Wave motionMarkersXY //zeros(0,2)
	uint16 resetCorrectionAfterAcq //bool
	SVAR zStackAlignmentFcn //@scanimage.components.motionEstimators.util.alignZRoiData

EndStructure

Structure hIntegrationRoiManager
	uint16 enable  //bool
	uint16 enableDisplay  //bool
	uint16 integrationHistoryLength //bool
	SVAR postProcessFcn // @scanimage.components.integrationRois.integrationPostProcessingFcn
EndStructure

Structure hFastZ
	uint16 actuatorLag
	uint16 discardFlybackFrames //bool
	uint16 enable //bool
	uint16 enableFieldCurveCorr  //bool
	uint16 flybackTime
	uint16 hasFastZ  //bool
	uint16 nonblockingMoveInProgress  //bool
	uint16 numDiscardFlybackFrames 
	uint16 numFramesPerVolume 
	uint16 numVolumes
	float positionAbsolute
	float positionAbsoluteRaw 
	uint16 positionTarget
	uint16 positionTargetRaw
	uint16 useArbitraryZs //bool
	uint16 userZs
	float volumePeriodAdjustment//signed
	SVAR waveformType
EndStructure

Structure hDisplay
	STRUCT scanfieldDisplays scanfieldDisplays
	Wave autoScaleSaturationFraction //2 row float
	uint16 channelsMergeEnable //bool
	uint16 channelsMergeFocusOnly //bool
	uint16 displayRollingAverageFactor
	uint16 displayRollingAverageFactorLock //bool
	uint16 enableScanfieldDisplays //bool
	uint16 lineScanHistoryLength
	SVAR renderer
	uint16 scanfieldDisplayColumns
	uint16 scanfieldDisplayRows
	SVAR scanfieldDisplayTilingMode
	uint16 selectedZs
	uint16 showScanfieldDisplayNames //bool
	SVAR volumeDisplayStyle
EndStructure

Structure scanfieldDisplays
	uint16 enable
	SVAR name
	uint16 channel
	uint16 roi
	uint16 z
EndStructure

Structure hCycleManager
	uint16 cycleIterIdxTotal
	uint16 cyclesCompleted
	uint16 enabled //bool
	uint16 itersCompleted
	uint16 totalCycles
EndStructure

Structure hChannels
	Wave channelAdcResolution //4 row int
	uint16 channelDisplay
	Wave channelInputRange //4 row, 2 col
	Wave channelLUT //4 row, 2 col
	Wave/t channelMergeColor //4 row text
	Wave/t channelName //4 row text
	Wave channelOffset //4 row int
	uint16 channelSave
	Wave channelSubtractOffset //4 row int
	Wave/t channelType //4 row text
	uint16 channelsActive
	uint16 channelsAvailable
	uint16 loggingEnable
EndStructure

Structure hConfigurationSaver
	SVAR cfgFilename
	SVAR usrFilename
EndStructure

Structure hBeams
	STRUCT powerBoxes powerBoxes
	uint16 beamCalibratedStatus
	uint16 directMode //bool
	uint16 enablePowerBox //bool
	uint16 flybackBlanking //bool
	uint16 interlaceDecimation
	uint16 interlaceOffset
	uint16 lengthConstants
	uint16 powerLimits
	uint16 powers
	uint16 pzAdjust //bool
	Wave pzCustom
	uint16 stackEndPower
	uint16 stackStartPower
	uint16 stackUseStartPower //bool
	uint16 stackUserOverrideLz //bool

EndStructure

Structure powerBoxes
	uint16 powers
	SVAR name
	uint16 oddLines
	uint16 evenLines
	Wave rect //4 row int
	uint16 powerBoxEndFrame
	uint16 powerBoxStartFrame
EndStructure


Function/S GetSIParam(param,header)
	String param
	Wave/T header
	String value = ""
	
	value = header[tableMatch(param,header)][1]
	return value
End

//Colon separated string of all the parameter fields in the header
Function/S GetSIParamStr()
	String param = ""
	
	param += "SI.LINE_FORMAT_VERSION;"
	param += "SI.TIFF_FORMAT_VERSION;"
	param += "SI.VERSION_COMMIT;"
	param += "SI.VERSION_MAJOR;"
	param += "SI.VERSION_MINOR;"
	param += "SI.acqState;"
	param += "SI.acqsPerLoop;"
	param += "SI.extTrigEnable;"
	param += "SI.imagingSystem;"
	param += "SI.loopAcqInterval;"
	param += "SI.objectiveResolution;"
	
	
	param += "SI.hStackManager.framesPerSlice;"
	param += "SI.hStackManager.numSlices;"
	param += "SI.hStackManager.shutterCloseMinZStepSize;"
	param += "SI.hStackManager.slowStackWithFastZ;"
	param += "SI.hStackManager.stackReturnHome;"
	param += "SI.hStackManager.stackSlicesDone;"
	param += "SI.hStackManager.stackStartCentered;"
	param += "SI.hStackManager.stackZEndPos;"
	param += "SI.hStackManager.stackZStartPos;"
	param += "SI.hStackManager.stackZStepSize;"
	param += "SI.hStackManager.stageDependentZs;"
	param += "SI.hStackManager.stepSizeLock;"
	param += "SI.hStackManager.zPowerReference;"
	param += "SI.hStackManager.zs;"
	
	param += "SI.hUserFunctions.userFunctionsCfg;"
	param += "SI.hUserFunctions.userFunctionsUsr;"	
	
	
	param += "SI.hWSConnector.communicationTimeout;"
	param += "SI.hWSConnector.enable;"
	
	
	param += "SI.hWaveformManager.optimizedScanners;"
	
	param += "SI.hScan2D.beamClockDelay;"
	param += "SI.hScan2D.beamClockExtend;"
	param += "SI.hScan2D.bidirectional;"
	param += "SI.hScan2D.channelOffsets;"
	param += "SI.hScan2D.channels;"
	param += "SI.hScan2D.channelsAdcResolution;"
	param += "SI.hScan2D.channelsAutoReadOffsets;"
	param += "SI.hScan2D.channelsAvailable;"
	param += "SI.hScan2D.channelsDataType;"
	param += "SI.hScan2D.channelsFilter;"
	param += "SI.hScan2D.channelSInputRanges;"
	param += "SI.hScan2D.channelsSubtractOffsets;"
	param += "SI.hScan2D.fillFractionSpatial;"
	param += "SI.hScan2D.fillFractionTemporal;"
	param += "SI.hScan2D.flybackTimePerFrame;"
	param += "SI.hScan2D.flytoTimePerScanfield;"
	param += "SI.hScan2D.fovCornerPoints;"
	param += "SI.hScan2D.hasResonantMirror;"
	param += "SI.hScan2D.hasXGalvo;"
	param += "SI.hScan2D.keepResonantScannerOn;"
	param += "SI.hScan2D.linePhase;"
	param += "SI.hScan2D.linePhaseMode;"
	param += "SI.hScan2D.logAverageFactor;"
	param += "SI.hScan2D.logFramesPerFile;"
	param += "SI.hScan2D.logFramesPerFileLock;"
	param += "SI.hScan2D.logOverwriteWarn;"
	param += "SI.hScan2D.mask;"
	param += "SI.hScan2D.maskDisableAveraging;"
	param += "SI.hScan2D.maxSampleRate;"
	param += "SI.hScan2D.name;"
	param += "SI.hScan2D.nominalFovCornerPoints;"
	param += "SI.hScan2D.pixelBinFactor;"
	param += "SI.hScan2D.sampleRate;"
	param += "SI.hScan2D.scanMode;"
	param += "SI.hScan2D.scanPixelTimeMaxMinRatio;"
	param += "SI.hScan2D.scanPixelTimeMean;"
	param += "SI.hScan2D.scannerFrequency;"
	param += "SI.hScan2D.scannerToRefTransform;"
	param += "SI.hScan2D.scannerType;"
	param += "SI.hScan2D.settleTimeFraction;"
	param += "SI.hScan2D.SImulated;"
	param += "SI.hScan2D.stripingEnable;"
	param += "SI.hScan2D.trigAcqEdge;"
	param += "SI.hScan2D.trigAcqInTerm;"
	param += "SI.hScan2D.trigNextEdge;"
	param += "SI.hScan2D.trigNextInTerm;"
	param += "SI.hScan2D.trigNextStopEnable;"
	param += "SI.hScan2D.trigStopEdge;"
	param += "SI.hScan2D.trigStopInTerm;"
	param += "SI.hScan2D.uniformSampling;"
	param += "SI.hScan2D.useNonlinearResonantFov2VoltsCurve;"
	
	
	param += "SI.hRoiManager.forceSquarePixelation;"
	param += "SI.hRoiManager.forceSquarePixels;"
	param += "SI.hRoiManager.imagingFovDeg;"
	param += "SI.hRoiManager.imagingFovUm;"
	param += "SI.hRoiManager.linePeriod;"
	param += "SI.hRoiManager.linesPerFrame;"
	param += "SI.hRoiManager.mroiEnable;"
	param += "SI.hRoiManager.pixelsPerLine;"
	param += "SI.hRoiManager.scanAngleMultiplierFast;"
	param += "SI.hRoiManager.scanAngleMultiplierSlow;"
	param += "SI.hRoiManager.scanAngleShiftFast;"
	param += "SI.hRoiManager.scanAngleShiftSlow;"
	param += "SI.hRoiManager.scanFramePeriod;"
	param += "SI.hRoiManager.scanFrameRate;"
	param += "SI.hRoiManager.scanRotation;"
	param += "SI.hRoiManager.scanType;"
	param += "SI.hRoiManager.scanVolumeRate;"
	param += "SI.hRoiManager.scanZoomFactor;"
	
	
	param += "SI.hPmts.autoPower;"
	param += "SI.hPmts.bandwidths;"
	param += "SI.hPmts.gains;"
	param += "SI.hPmts.names;"
	param += "SI.hPmts.offsets;"
	param += "SI.hPmts.powersOn;"
	param += "SI.hPmts.tripped;"
	
	
	param += "SI.hPhotostim.allowMultipleOutputs;"
	param += "SI.hPhotostim.autoTriggerPeriod;"
	param += "SI.hPhotostim.compensateMotionEnabled;"
	param += "SI.hPhotostim.completedSequences;"
	param += "SI.hPhotostim.laserActiveSIgnalAdvance;"
	param += "SI.hPhotostim.lastMotion;"
	param += "SI.hPhotostim.logging;"
	param += "SI.hPhotostim.monitoring;"
	param += "SI.hPhotostim.monitoringSampleRate;"
	param += "SI.hPhotostim.nextStimulus;"
	param += "SI.hPhotostim.numOutputs;"
	param += "SI.hPhotostim.numSequences;"
	param += "SI.hPhotostim.sequencePoSItion;"
	param += "SI.hPhotostim.sequenceSelectedStimuli;"
	param += "SI.hPhotostim.status;"
	param += "SI.hPhotostim.stimImmediately;"
	param += "SI.hPhotostim.stimSelectionAsSIgnment;"
	param += "SI.hPhotostim.stimSelectionDevice;"
	param += "SI.hPhotostim.stimSelectionTerms;"
	param += "SI.hPhotostim.stimSelectionTriggerTerm;"
	param += "SI.hPhotostim.stimTriggerTerm;"
	param += "SI.hPhotostim.stimulusMode;"
	param += "SI.hPhotostim.syncTriggerTerm;"
	param += "SI.hPhotostim.zMode;"
	
	
	param += "SI.hMotors.azimuth;"
	param += "SI.hMotors.backlashCompensation;"
	param += "SI.hMotors.dimNonblockingMoveInProgress;"
	param += "SI.hMotors.elevation;"
	param += "SI.hMotors.motorFastMotionThreshold;"
	param += "SI.hMotors.motorPoSItion;"
	param += "SI.hMotors.motorPoSItionTarget;"
	param += "SI.hMotors.motorStepLimit;"
	param += "SI.hMotors.motorToRefTransform;"
	param += "SI.hMotors.motorToRefTransformAbsolute;"
	param += "SI.hMotors.motorToRefTransformValid;"
	param += "SI.hMotors.nonblockingMoveInProgress;"
	param += "SI.hMotors.scanimageToMotorTF;"
	param += "SI.hMotors.userDefinedPoSItions;"
	
	
	param += "SI.hMotionManager.correctionBoundsXY;"
	param += "SI.hMotionManager.correctionBoundsZ;"
	param += "SI.hMotionManager.correctionDeviceXY;"
	param += "SI.hMotionManager.correctionDeviceZ;"
	param += "SI.hMotionManager.correctionEnableXY;"
	param += "SI.hMotionManager.correctionEnableZ;"
	param += "SI.hMotionManager.correctorClassName;"
	param += "SI.hMotionManager.enable;"
	param += "SI.hMotionManager.estimatorClassName;"
	param += "SI.hMotionManager.motionHistoryLength;"
	param += "SI.hMotionManager.motionMarkersXY;"
	param += "SI.hMotionManager.resetCorrectionAfterAcq;"
	param += "SI.hMotionManager.zStackAlignmentFcn;"
	
	
	param += "SI.hIntegrationRoiManager.enable;"
	param += "SI.hIntegrationRoiManager.enableDisplay;"
	param += "SI.hIntegrationRoiManager.integrationHistoryLength;"
	param += "SI.hIntegrationRoiManager.postProcessFcn;"
	
	
	param += "SI.hFastZ.actuatorLag;"
	param += "SI.hFastZ.discardFlybackFrames;"
	param += "SI.hFastZ.enable;"
	param += "SI.hFastZ.enableFieldCurveCorr;"
	param += "SI.hFastZ.flybackTime;"
	param += "SI.hFastZ.hasFastZ;"
	param += "SI.hFastZ.nonblockingMoveInProgress;"
	param += "SI.hFastZ.numDiscardFlybackFrames;"
	param += "SI.hFastZ.numFramesPerVolume;"
	param += "SI.hFastZ.numVolumes;"
	param += "SI.hFastZ.poSItionAbsolute;"
	param += "SI.hFastZ.poSItionAbsoluteRaw;"
	param += "SI.hFastZ.poSItionTarget;"
	param += "SI.hFastZ.poSItionTargetRaw;"
	param += "SI.hFastZ.useArbitraryZs;"
	param += "SI.hFastZ.userZs;"
	param += "SI.hFastZ.volumePeriodAdjustment;"
	param += "SI.hFastZ.waveformType;"
	
	
	param += "SI.hDisplay.autoScaleSaturationFraction;"
	param += "SI.hDisplay.channelsMergeEnable;"
	param += "SI.hDisplay.channelsMergeFocusOnly;"
	param += "SI.hDisplay.displayRollingAverageFactor;"
	param += "SI.hDisplay.displayRollingAverageFactorLock;"
	param += "SI.hDisplay.enableScanfieldDisplays;"
	param += "SI.hDisplay.lineScanHistoryLength;"
	param += "SI.hDisplay.renderer;"
	param += "SI.hDisplay.scanfieldDisplayColumns;"
	param += "SI.hDisplay.scanfieldDisplayRows;"
	param += "SI.hDisplay.scanfieldDisplayTilingMode;"
	param += "SI.hDisplay.selectedZs;"
	param += "SI.hDisplay.showScanfieldDisplayNames;"
	param += "SI.hDisplay.volumeDisplayStyle;"
	
	param += "SI.hDisplay.scanfieldDisplays.enable;"
	param += "SI.hDisplay.scanfieldDisplays.name;"
	param += "SI.hDisplay.scanfieldDisplays.channel;"
	param += "SI.hDisplay.scanfieldDisplays.roi;"
	param += "SI.hDisplay.scanfieldDisplays.z;"
	
	
	param += "SI.hCycleManager.cycleIterIdxTotal;"
	param += "SI.hCycleManager.cyclesCompleted;"
	param += "SI.hCycleManager.enabled;"
	param += "SI.hCycleManager.itersCompleted;"
	param += "SI.hCycleManager.totalCycles;"
	
	
	param += "SI.hChannels.channelAdcResolution;"
	param += "SI.hChannels.channelDisplay;"
	param += "SI.hChannels.channelInputRange;"
	param += "SI.hChannels.channelLUT;"
	param += "SI.hChannels.channelMergeColor;"
	param += "SI.hChannels.channelName;"
	param += "SI.hChannels.channelOffset;"
	param += "SI.hChannels.channelSave;"
	param += "SI.hChannels.channelSubtractOffset;"
	param += "SI.hChannels.channelType;"
	param += "SI.hChannels.channelsActive;"
	param += "SI.hChannels.channelsAvailable;"
	param += "SI.hChannels.loggingEnable;"
	
	param += "SI.hConfigurationSaver.cfgFilename;"
	param += "SI.hConfigurationSaver.usrFilename;"
	
	
	param += "SI.hBeams.beamCalibratedStatus;"
	param += "SI.hBeams.directMode;"
	param += "SI.hBeams.enablePowerBox;"
	param += "SI.hBeams.flybackBlanking;"
	param += "SI.hBeams.interlaceDecimation;"
	param += "SI.hBeams.interlaceOffset;"
	param += "SI.hBeams.lengthConstants;"
	param += "SI.hBeams.powerLimits;"
	param += "SI.hBeams.powers;"
	param += "SI.hBeams.pzAdjust;"
	param += "SI.hBeams.pzCustom;"
	param += "SI.hBeams.stackEndPower;"
	param += "SI.hBeams.stackStartPower;"
	param += "SI.hBeams.stackUseStartPower;"
	param += "SI.hBeams.stackUserOverrideLz;"
	param += "SI.hBeams.powers;"
	param += "SI.hBeams.powerBoxEndFrame;"
	param += "SI.hBeams.powerBoxStartFrame;"
	
	
	param += "SI.hBeams.powerBoxes.name;"
	param += "SI.hBeams.powerBoxes.oddLines;"
	param += "SI.hBeams.powerBoxes.evenLines;"
	param += "SI.hBeams.powerBoxes.rect;"
	
	return param
End