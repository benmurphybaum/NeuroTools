#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//Loads ScanImage tiff files into 3D waves
//Takes a folder path, and a semi-colon list of file names within that folder
Function/S SI_LoadScans(path,fileList)
	String path,fileList
	
	Variable fileRef
	
	Variable j,numFiles = ItemsInList(fileList,";")
	
	STRUCT ds ds
	
	String imageList = ""
	
	For(j=0;j<numFiles;j+=1)
	
		Variable ref = StartMSTimer	
		
		//the file name
		String file = StringFromList(j,fileList,";")
		
		If(stringmatch(file,"*.pmt.dat"))
			SI_LoadLineScan(path,file)
			print StopMSTimer(ref)
			continue
		EndIf
		
		//Make the data folder to hold the scan waves
		path = ReplaceString("/",path,":")
	
		//This is the full path of the folder to be created in Igor that will hold the scan wave
		String folder = "root:Scans:" + ParseFilePath(0,path,":",1,0)
		
		If(!DataFolderExists("root:Scans"))
			NewDataFolder root:Scans
		EndIf
		
		//Remove any whitespaces
		folder = ReplaceString(" ",folder,"")
		
		If(!DataFolderExists(folder))
			NewDataFolder $folder
		EndIf
		
		//add the scan name folder on and make the folder
		folder += ":" + RemoveEnding(file,".tif")
		
		If(!DataFolderExists(folder))
			NewDataFolder $folder
		EndIf
		
		SetDataFolder $folder
		
		//Open the file
		path = RemoveEnding(path,":") + ":" //ensures ending colon
		NewPath/O/Q image,path
		
		//Can't open the file if MATLAB is currently writing to it.
		try
			Open/P=image/R fileRef as file
			AbortOnRTE
		catch
			return ""
		endtry	
			
		//Read binary data, little endian, 64 bit integer (8 byte)
		String str = ""
		Variable var
		
		Variable IFD_HEADER_OFFSET,MAGIC,VERSION,FRAME_DATA_LENGTH,ROI_DATA_LENGTH
	
		//IFD HEADER OFFSET
		FSetPos fileRef,8
		FBinRead/B=3/F=2 fileRef,IFD_HEADER_OFFSET

		//STATIC METADATA
		Variable pos = 16
		
		//Magic # - confirms this is a scanimage big tiff file
		FSetPos fileRef,pos
		FBinRead/B=3/F=3/U fileRef,MAGIC
		
		pos += 4 //20
		FSetPos fileRef,pos
		FBinRead/B=3/F=3/U fileRef,VERSION
		
		pos += 4 //24
		FSetPos fileRef,pos
		FBinRead/B=3/F=3/U fileRef,FRAME_DATA_LENGTH
		
		pos += 4 //28
		FSetPos fileRef,pos
		FBinRead/B=3/F=3/U fileRef,ROI_DATA_LENGTH
		
		//Non-Varying Frame Data
		pos += 4 //32
		
		//Get the Non-Varying Frame Data (HEADER)
		Wave/T header_return = SI_GetHeader(fileRef,FRAME_DATA_LENGTH,pos)
		Make/O/T/N=(DimSize(header_return,0),2) $(folder + ":scanInfo") /Wave = header
		header = header_return
		
		//Get the ROI Group Data (HEADER)
	//	String/G root:roiStr 
	//	SVAR roiStr = root:roiStr
	
		pos += FRAME_DATA_LENGTH
		str = ""
		String roiStr = PadString(str,ROI_DATA_LENGTH,0)
		FSetPos fileRef,pos
		FBinRead/B=3/F=3/U fileRef,roiStr
		
		//Extracts the ROI data
		Wave/WAVE roiWaveRefs = GetROIData(roiStr,file,header)
		
		//Use the first ROI wave to get the number of ROIs
		Variable numROIs = DimSize(roiWaveRefs,0)
		
		Close/A
		
		//Native Igor load of the tiff
		String fullPath = path + file
		ImageLoad/O/T=tiff/S=0/BIGT=1/C=-1/Q/LR3D fullPath
		
		Wave theImage = $(folder + ":'" + file + "'")
		
		SetDataFolder GetWavesDataFolder(theImage,1)
		
		
		//Number of frames will be a multiple of the # Z levels
		Variable frame,numFrames = DimSize(theImage,2)
		
		
		Variable prevZ,Z,offsetY,offsetZ,numZs
		
		//Was this a Z stack enabled scan?
		Variable stackEnable = bool2int(GetSIParam("hStackManager.enable",header))
		
		//Is multiROI enabled?
		Variable mroiEnable = str2num(GetSIParam("mroiEnable",header))
		
		If(stackEnable)
			String stackMode = GetSIParam("stackDefinition",header)
			
			//arbitrary Zs were used
			strswitch(stackMode)
				case "'arbitrary'":
					//get the Z levels
					String zs = ReplaceString(" ",GetSIParam("zs",header),";")
					zs = ReplaceString("]",ReplaceString("[",zs,""),";")
					
					//Number of Z levels
					numZs = str2num(GetSIParam("actualNumSlices",header))
					
					//Number of time steps in each volume (i.e. number of frames)
					Variable numTimeFrames = str2num(GetSIParam("actualNumVolumes",header))
					
					Variable framesPerSlice = str2num(GetSIParam("framesPerSlice",header))
					
					//Volume rate (i.e. frame rate)
					Variable frameRate = str2num(GetSIParam("scanVolumeRate",header))
					
					break
				case "'bounded'":
				case "'uniform'":
					//get the Z levels
					zs = ReplaceString(" ",GetSIParam("zs",header),";")
					zs = ReplaceString("]",ReplaceString("[",zs,""),";")
					
					//Number of Z levels
					numZs = str2num(GetSIParam("actualNumSlices",header))
					
					//Number of time steps in each volume (i.e. number of frames)
					numTimeFrames = str2num(GetSIParam("actualNumVolumes",header))
					
					framesPerSlice = str2num(GetSIParam("framesPerSlice",header))
					
					//Volume rate (i.e. frame rate)
					frameRate = str2num(GetSIParam("scanVolumeRate",header))
					break
				
				default:
		
					zs = "0"
					numZs = 1
					numTimeFrames = str2num(GetSIParam("framesPerSlice",header))
					frameRate = str2num(GetSIParam("scanFrameRate",header))
					break
			endswitch
		
		Else
			zs = "0"
			numZs = 1
			numTimeFrames = numFrames
			framesPerSlice = 1
			frameRate = str2num(GetSIParam("scanFrameRate",header))
		EndIf

		//Number of ROIs determines how many waves will be created
		Variable i
		String baseName = RemoveEnding(file,".tif")
		
		prevZ = -1
		offsetY = -1
		offsetZ = 0
		
		//MUST CHANGE, WHEN SELECTING CHANNELS TO LOAD. FOR NOW JUST DOING CH 1.
//		String ch = "ch1"
		
		String channelList = GetSIParam("channelsActive",header)
		channelList = ReplaceString(" ",channelList,";")
		channelList = ReplaceString("[",channelList,"")
		channelList = ReplaceString("]",channelList,"")
		Variable numChannels = ItemsInList(channelList,";")
		
		//Microns per degree of mirror angle
		Variable objResolution = str2num(GetSIParam("objectiveResolution",header)) * 1e-6
		
		For(i=0;i<numROIs;i+=1)
			Wave/T theROI = roiWaveRefs[i]
			Variable xPixels = GetROIVar("XPixels",theROI)
			
			Variable yPixels = GetROIVar("YPixels",theROI)
//			Variable frames = theROI[FindDimLabel(theROI,0,"Frames")]
			
			String name = GetROIString("Name",theROI)
			
			If(stringmatch(name,"Default*"))
				name = ""
			EndIf
			
			If(strlen(name))
				String ROIname = baseName + "_" + name //+ "_" + ch
			Else
				ROIname = baseName + "_R" + num2str(i) //+ "_" + ch
			EndIf
					
			numZs = (numZs == 0) ? 1 : numZs
//			Make/N=(xPixels,yPixels,(numFrames / numZs))/O/W $ROIname/Wave=scanROI
			
			If(framesPerSlice > 1)
				//Z stack (probably) with multiple frames per slice
				Make/N=(xPixels,yPixels,numZs,framesPerSlice)/O/W $ROIname/Wave=scanROI
			Else
				If(numROIs > 1 || numZs == 1)
					//Not a Zstack (not necessarily true, but probably true for our purposes)
					//Standard for multi ROI multi-plane imaging
					Make/N=(xPixels,yPixels,(numFrames / numZs))/O/W $ROIname/Wave=scanROI
				Else
					//Z stack, single frame per slice, potentially multiple volumes taken (numTimeFrames)
					Make/N=(xPixels,yPixels,numZs,numTimeFrames)/O/W $ROIname/Wave=scanROI
				EndIf
			EndIf
								
			imageList += GetWavesDataFolder(scanROI,2) + ";"	
			
			//These are built in scan mirror offsets used to center the image. By removing these, the scaling of the image reflects the actual stage position,
			//which is a lot more useful for our analysis.
			Variable XOffset = str2num(GetSIParam("scanAngleShiftFast",header))
			Variable YOffset = str2num(GetSIParam("scanAngleShiftSlow",header))
			
			Variable XCenter = str2num(theROI[1]) - XOffset
			Variable YCenter = str2num(theROI[2]) - YOffset
			
//			SetScale/I x,objResolution * (theROI[0] - (theROI[2] / 2)),objResolution * (theROI[0] + (theROI[2] / 2)),"m",scanROI
			SetScale/I x,objResolution * (XCenter - (str2num(theROI[3]) / 2)),objResolution * (XCenter + (str2num(theROI[3]) / 2)),"m",scanROI
			
			//Reverse scaling from what I originally had, so now the image is oriented the same as in MATLAB when the data is taken
//			SetScale/I y,objResolution * (theROI[1] - (theROI[3] / 2)),objResolution * (theROI[1] + (theROI[3] / 2)),"m",scanROI
			SetScale/I y,objResolution * (YCenter - (str2num(theROI[4]) / 2)),objResolution * (YCenter + (str2num(theROI[4]) / 2)),"m",scanROI
			
			SetScale/P z,0,str2num(theROI[12]),"s",scanROI
			
			//Get the z plane of the scan ROI, and it's frame offset
			String Zstr = theROI[5]
			Z = str2num(Zstr)
			
			//Put the frames into the output waves
			offsetZ = WhichListItem(Zstr,zs,";")
			
			If(offsetZ == -1)
				offsetZ = 0
			EndIf
			
			offsetY = (Z == prevZ) ? Ypixels : 0
		
//			If(framesPerSlice > 1)
//				//This will hold each block of frames per slice
//				Make/N=(xPixels,yPixels,framesPerSlice)/FREE sliceBlock
//				Redimension/S scanROI
//				For(k=0;k<numZs;k+=1)
//					Multithread sliceBlock = theImage[p][q][r + k * framesPerSlice]
//					MatrixOP/FREE avgSlice = sumBeams(sliceBlock) / framesPerSlice
//					Multithread scanROI[][][k] = avgSlice[p][q][0]
//				EndFor
//			Else
			Variable k
			
			If(framesPerSlice == 1)
				Multithread scanROI[][][][] = theImage[p][offsetY + q][offsetZ + r * numZs]
			Else
				Make/FREE/N=(xPixels,yPixels,framesPerSlice) chunk
				For(k=0;k<numZs;k+=1)
					Multithread chunk = theImage[p][q][r + k * framesPerSlice]
					Multithread scanROI[][][k][] = chunk[p][q][s]
				EndFor
			EndIf		
				
			//break this into channels, channels for each frame are stacked in order
			Variable c
			For(c=0;c<numChannels;c+=1)
				String ch = "ch" + StringFromList(c,channelList,";")
				String scanName = NameOfWave(scanROI)
				If(numChannels > 1)
					Duplicate/O scanROI,$(scanName + "_" + ch)
					Wave scanChannel = $(scanName + "_" + ch)
					Redimension/N=(-1,-1,DimSize(scanROI,2) / numChannels) scanChannel
					scanChannel = scanROI[p][q][c + r * numChannels]
				Else
					Duplicate/O scanROI,$(scanName + "_" + ch)
				EndIf				
			EndFor
				
			KillWaves/Z scanROI
			
			prevZ = Z
			offsetY += yPixels
		EndFor
		
		Variable size = str2num(StringByKey("SIZEINBYTES",WaveInfo(theImage,0))) / (1e6)
		
		KillWaves/Z theImage
		
		print "Loaded " + fullpath + ":", StopMSTimer(ref) / (1e6),"s (" + num2str(size) + " MB)"
		
	EndFor
		
	return imageList
End

Function/S SI_LoadLineScan(path,file)
	String path,file
	
	Variable fileRef 
	
	//Make a new folder for the file
	//Make the data folder to hold the scan waves
	path = ReplaceString("/",path,":")

	//This is the full path of the folder to be created in Igor that will hold the scan wave
	String folder = "root:Scans:" + ParseFilePath(0,path,":",1,0)
	
	If(!DataFolderExists("root:Scans"))
		NewDataFolder root:Scans
	EndIf
	
	//Remove any whitespaces
	folder = ReplaceString(" ",folder,"")
	
	If(!DataFolderExists(folder))
		NewDataFolder $folder
	EndIf
	
	//add the scan name folder on and make the folder
	folder += ":" + RemoveEnding(file,".pmt.dat")
	
	If(!DataFolderExists(folder))
		NewDataFolder $folder
	EndIf
	
	SetDataFolder $folder
	
	//Open the file
	path = RemoveEnding(path,":") + ":" //ensures ending colon
	NewPath/O/Q image,path
	
	//Can't open the file if MATLAB is currently writing to it.
	try
		Open/P=image/R fileRef as file
		AbortOnRTE
	catch
		return ""
	endtry	
	
	//Load the header file as well
	String headerStr = ReplaceString(".pmt.dat",file,".meta.txt")
	LoadWave/O/J/N=header/P=image/ENCG=4/K=2 headerStr
	Wave/T header = header0
	Duplicate/T/O header,$"header"
	KillWaves header
	
	Wave/T header = header
	
	//split header into columns
	Redimension/N=(-1,2) header
	Variable i
	For(i=0;i<DimSize(header,0);i+=1)
		String row = header[i]
		If(stringmatch(row,"*ROIGroups*"))
			Redimension/N=(i-2,2) header
			break
		EndIf
		
		header[i][0] = ReplaceString(" ",StringFromList(0,row,"="),"")	
		header[i][1] = ReplaceString(" ",StringFromList(1,row,"="),"")
	EndFor
	
	Variable samplesPerFrame = str2num(header[TableMatch("SI.hScan2D.lineScanSamplesPerFrame",header)][1])
	Variable framesPerSlice = str2num(header[TableMatch("SI.hStackManager.framesPerSlice",header)][1])
	Variable framePeriod = str2num(header[TableMatch("SI.hRoiManager.scanFramePeriod",header)][1])
	
	//Read binary data, 16 bit signed
	GBLoadWave/O/B=1/P=image/T={16,16} file
	
//	Variable refnum
//	Open refnum as file 
//	
//	Make/o/n=(6300000)/W image
//	FBinRead refnum,image 
	
//	close/a
	 
	Wave theImage = wave0
	
	Redimension/N=(samplesPerFrame,framesPerSlice) theImage
	
	
	MatrixOP/O theImage = sumCols(theImage)^t
	
	String name = RemoveEnding(file,".pmt.dat") + "_ch1"
		
	Redimension/S theImage
//	Multithread theImage = theImage / samplesPerFrame
	
	SetScale/P x,0,framePeriod,theImage
	
	ReallyKillWaves($name)
	Rename $NameOfWave(theImage),$name
	
//	Smooth/S=2 5,theImage,theImage
End


//Returns the ScanImage Big Tiff HEADER from the open file reference
Function/WAVE SI_GetHeader(fileRef,length,offset)
	Variable fileRef,length,offset
	
	FStatus fileRef
	
	String path = S_path + S_fileName
	
	Variable i = 0
	
	//Set position to start of HEADER
	FSetPos fileRef,offset
	
	//Read in the binary data into the correctly sized string for the number of bytes in the header
	String/G root:str = ""
	SVAR str = root:str
	str = PadString(str,length,0)
	FBinRead/B=3/F=3 fileRef,str
	
	String param = GetParamStr()
	
	Make/O/N=(ItemsInList(param,";"),2)/T/FREE header
	
	For(i=0;i<ItemsInList(param,";");i+=1)
		String theParam = StringFromList(i,param,";")
		strswitch(theParam)
			case "SI.hFastZ.enable":
			case "SI.hStackManager.enable":
				header[i][0] = RemoveListItem(0,theParam,".")
				break
			default:
				header[i][0] = ParseFilePath(0,theParam,".",1,0)
				break
		endswitch
		
		header[i][1] = StringByKey(theParam,str," = ","\n")
	EndFor
	
	//Append the file location to the header
	Variable row = DimSize(header,0)
	Redimension/N=(row + 2,2) header
	header[row][0] = "File Path"
	header[row][1] = path
	header[row+1][0] = "Stimulus Path"
	header[row+1][1] = ""
	
	//Try to append the path to potential stimulus .h5 file
	String fileList = IndexedFile(image,-1,".h5") //image is the pre-defined path to the image, as defined in the calling function
	String stimFile = RemoveEnding(S_fileName,".tif") + ".h5"
	
	If(stringmatch(fileList,"*" + stimFile + "*"))
		header[row+1][1] = S_path + stimFile
	EndIf
	
	return header
End

//Extracts the position,rotation, z plane, etc. data for all ROIs, puts into ROI output wave
Function/WAVE GetROIData(roiStr,file,header)
	String roiStr,file
	Wave/T/Z header
	
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
	
	Variable i,j,k,count = 0
	
	
	//Wave reference wave that will hold the ROI data waves
	Make/FREE/WAVE/N=(0) roiWaveRefs
	
	For(i=0;i<numROI;i+=1)
	
		If(numROI > 1)
			String roiFullPath = roiPath + num2str(i)
		Else
			roiFullPath = roiPath
		EndIf
			
		JSONXOP_GetKeys jsonID,roiFullPath,keys
		
		//check for more than one scanfield in the ROI
		JSONXOP_GetType jsonID,roiFullPath + "/scanfields"
		
		If(V_Value)
			JSONXOP_GetArraySize jsonID,roiFullPath + "/scanfields"
			Variable numScanFields = V_Value
		Else
			numScanFields = 1
		EndIf
		
		For(j=0;j<numScanFields;j+=1)
			Redimension/N=(DimSize(roiWaveRefs,0) + 1) roiWaveRefs
			
			//Get the ROI name
			If(numScanFields > 1)
				//take name from the scanfields if the ROI has multiple defined
				JSONXOP_GetValue/T jsonID,roiFullPath + "/scanfields/" + num2str(j) + "/name"
				String name = S_Value
			Else
				JSONXOP_GetValue/T jsonID,roiFullPath + "/name"
				name = S_Value
			EndIf	
			
			//Will hold the ROI data
			If(strlen(name))
				String roiName = "ROI_" + name
				roiName = ReplaceString(" ",roiName,"")
			Else
				roiName = "ROI_" + num2str(count)
			EndIf
			
			If(stringmatch(name,"Default*"))
				roiName = "ROI_" + num2str(count)
			EndIf
			
			KillWaves/Z $(":" + roiName)
			Make/O/N=20/T $(":" + roiName)/Wave=ROI
			
			ROI[0] = name 
		
			If(numScanFields > 1)
				String suffix = "/" + num2str(j)
			Else
				suffix = ""
			EndIf
					
			JSONXOP_GetKeys jsonID,roiFullPath + "/scanfields" + suffix,scanKeys
			
			//Get Z plane of each Scanfield in the ROI
			JSONXOP_GetValue/V jsonID,roiFullPath + "/zs" + suffix
			ROI[5] = num2str(V_Value)
			
			JSONXOP_GetValue/V jsonID,roiFullPath + "/discretePlaneMode"
			ROI[17] = num2str(V_Value)
			
			//Single plane ROIs, or volumetric ROIs
		
		
			For(k=0;k<DimSize(scanKeys,0);k+=1)
				strswitch(scanKeys[k])
					case "centerXY": //Rows 0-1 in the ROI wave
						Wave wv = JSON_GetWave(jsonID,roiFullPath + "/scanfields" + suffix + "/" + scanKeys[k])
						ROI[1,2] = num2str(wv[p-1])
						break
					case "sizeXY":	//Rows 2-3 in the ROI wave
						Wave wv = JSON_GetWave(jsonID,roiFullPath + "/scanfields" + suffix + "/" +scanKeys[k])
						ROI[3,4] = num2str(wv[p-3])
						break
					case "rotationDegrees": //Row 5 in the ROI wave
						JSONXOP_GetValue/V jsonID,roiFullPath + "/scanfields" + suffix + "/" + scanKeys[k]
						ROI[6] = num2str(V_Value)
						break
					case "pixelResolutionXY": //Rows 6-7 in the ROI wave
						Wave wv = JSON_GetWave(jsonID,roiFullPath + "/scanfields" + suffix + "/" + scanKeys[k])
						ROI[7,8] = num2str(wv[p-7])
						break
					case "enable": //Row 13 in the ROI wave
						JSONXOP_GetValue/V jsonID,roiFullPath + "/scanfields" + suffix + "/" + scanKeys[k]
						ROI[14] = num2str(V_Value)
						break					
				endswitch
			EndFor
			
			
			ROI[10] = num2str(str2num(ROI[3]) / str2num(ROI[7])) //microns per pixel X
			ROI[11] = num2str(str2num(ROI[4]) / str2num(ROI[8]))  //microns per pixel Y
			
			
			Variable index = tableMatch("framesPerSlice",header)
			If(index != -1)
				ROI[9] = header[index][1] //number of frames per slice
			EndIf
			
			index = tableMatch("numSlices",header)
			If(index != -1)
				ROI[9] = num2str( str2num(ROI[9]) * str2num(header[index][1]) )  //number of frames total
			EndIf
	//		
	//		index = tableMatch("SI.hRoiManager.scanFramePeriod",header)
	//		If(index != -1)
	//			ROI[11] = str2num(header[index][1])  //seconds per frame
	//		EndIf
			
			index = tableMatch("scanVolumeRate",header)
			If(index != -1)
				ROI[13] = header[index][1] //volume rate
				ROI[12] = num2str(1 / str2num(ROI[13])) //seconds per volume
			EndIf
			
			ROI[15] = num2str(numROI	)  //number of ROIs in the scan
			
			ROI[16] = num2str(numScanFields) //number of scanfields in the ROI
			
			//Get the slow and fast mirror offsets
			ROI[18] = GetSIParam("scanAngleShiftFast",header)
			ROI[19] = GetSIParam("scanAngleShiftSlow",header)
			
			//Label the ROI waves
			SetDimLabel 0,0,Name,ROI
			SetDimLabel 0,1,CenterX,ROI
			SetDimLabel 0,2,CenterY,ROI
			SetDimLabel 0,3,SizeX,ROI
			SetDimLabel 0,4,SizeY,ROI
			SetDimLabel 0,5,Z,ROI
			SetDimLabel 0,6,Rotation,ROI
			SetDimLabel 0,7,XPixels,ROI
			SetDimLabel 0,8,YPixels,ROI
			SetDimLabel 0,9,Slices,ROI
			SetDimLabel 0,10,XScale,ROI
			SetDimLabel 0,11,YScale,ROI
			SetDimLabel 0,12,TimeScale,ROI
			SetDimLabel 0,13,FrameRate,ROI
			SetDimLabel 0,14,Enable,ROI
			SetDimLabel 0,15,ROIs,ROI
			SetDimLabel 0,16,ScanFields,ROI
			SetDimLabel 0,17,DiscretePlane,ROI
			SetDimLabel 0,18,ScanAngleShiftFast,ROI
			SetDimLabel 0,19,ScanAngleShiftSlow,ROI
			
			roiWaveRefs[count] = ROI
			
			count += 1
		EndFor	
		
	EndFor
	
	//cleanup
	KillWaves/Z wv,scanKeys,keys
			
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

Function/S GetSIParam(param,header)
	String param
	Wave/T header
	String value = ""
	
	value = header[tableMatch(param,header)][1]
	return value
End

Function GetROIVar(param,header)
	String param
	Wave/T header //ROI data wave
	
	Variable index = FindDimLabel(header,0,param)
	If(index == -2)
		return index
	EndIf
	
	return str2num(header[index])
End

Function/S GetROIString(param,header)
	String param
	Wave/T header //ROI data wave
	
	Variable index = FindDimLabel(header,0,param)
	If(index == -2)
		return ""
	EndIf
	
	return header[index]
End

//Colon separated string of all the parameter fields in the header
Function/S GetParamStr()
	String param = ""
	
	param += "SI.acqState;"
	param += "SI.acqsPerLoop;"
	param += "SI.loopAcqInterval;"
	param += "SI.objectiveResolution;"
	param += "SI.hBeams.powers;"
	param += "SI.hChannels.channelsActive;"
	param += "SI.hFastZ.enable;"
	param += "SI.hFastZ.waveformType;"
	param += "SI.hRoiManager.linePeriod;"
	param += "SI.hRoiManager.linesPerFrame;"
	param += "SI.hRoiManager.mroiEnable;"
	param += "SI.hRoiManager.pixelsPerLine;"
	param += "SI.hRoiManager.scanAngleShiftFast;"
	param += "SI.hRoiManager.scanAngleShiftSlow;"
	param += "SI.hRoiManager.scanFramePeriod;"
	param += "SI.hRoiManager.scanFrameRate;"
	param += "SI.hRoiManager.scanRotation;"
	param += "SI.hRoiManager.scanType;"
	param += "SI.hRoiManager.scanVolumeRate;"
	param += "SI.hRoiManager.scanZoomFactor;"
	param += "SI.hScan2D.bidirectional;"
	param += "SI.hScan2D.fillFractionSpatial;"
	param += "SI.hScan2D.fillFractionTemporal;"
	param += "SI.hScan2D.fovCornerPoints;"
	param += "SI.hScan2D.scanPixelTimeMaxMinRatio;"
	param += "SI.hScan2D.scanPixelTimeMean;"
	param += "SI.hStackManager.actualNumSlices;"
	param += "SI.hStackManager.actualNumVolumes;"
	param += "SI.hStackManager.actualStackZStepSize;"
	param += "SI.hStackManager.arbitraryZs;"
	param += "SI.hStackManager.enable;"
	param += "SI.hStackManager.framesPerSlice;"
	param += "SI.hStackManager.numFramesPerVolume;"
	param += "SI.hStackManager.numSlices;"
	param += "SI.hStackManager.numVolumes;"
	param += "SI.hStackManager.stackDefinition;"
	param += "SI.hStackManager.stackFastWaveformType;"
	param += "SI.hStackManager.stackMode;"
	param += "SI.hStackManager.stackZEndPos;"
	param += "SI.hStackManager.stackZStartPos;"
	param += "SI.hStackManager.stackZStepSize;"
	param += "SI.hStackManager.zs;"
	param += "SI.hStackManager.zsRelative;"
	
	return param
End


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