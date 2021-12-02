#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function GetPresentinatorChannels(fileName)
	String fileName
	
	DFREF NPC = $CW	
	SVAR wsFilePath = NPC:wsFilePath
	SVAR wsFileName = NPC:wsFileName
	
	Variable fileID


End

Static Function/S GetHeaderItem(header,key)
	Wave/T header
	String key
	
	If(!WaveExists(header))
		return ""
	EndIf
	
	If(!strlen(key))
		return ""
	EndIf
	
	Variable index = tableMatch(key,header)
	If(index == -1)
		return ""
	EndIf
	
	return header[index][1]
End

Function/WAVE GetHeader(ref)
	Variable ref
		
	//HEADER
	Make/T/O/FREE/N=(100,2) header
	
	FSetPos ref,4
	String inStr = ""
	String stopText = ""
	Variable i = 0
	
	Do
		FReadLine ref,inStr
		
		If(!strlen(inStr))
			break
		EndIf
		
		String headerItem = StringFromList(0,inStr,":")
		headerItem = ReplaceString("\r",headerItem,"")
		header[i][0] = headerItem
		
		//Presentinator or Pulsinator?
		If(i == 0)
			//Is this a presentinator file or a pulsinator file?
			If(stringmatch(header[0][0],"*Presentinator*"))
				String type = "Presentinator"
				stopText = "*Stimulus Protocol*"
			ElseIf(stringmatch(header[0][0],"*Pulsinator*"))
				type = "Pulsinator"
				stopText = "*Intracellular solution Ch2*"
			EndIf
		EndIf
		
		headerItem = StringByKey(header[i][0],inStr,":","\n")
		headerItem = ReplaceString("\r",headerItem,"")
		
		header[i][1] = headerItem
		
		i += 1	
		
		If(stringmatch(inStr,stopText))
			break
		EndIf
		
	While(i < 100)
	
	Redimension/N=(i,2) header
	
	return header
End

//Loads .phys files from presentinator
Function/S LoadPresentinator(filePathList)
	String filePathList
	
	If(!strlen(filePathList))
		return ""
	EndIf
	
	DFREF saveDF = GetDataFolderDFR()
	
	//Make the new ephys folder for the incoming waves
	PathInfo filePath
	
	String folder = ParseFilePath(0,S_Path,":",1,0)
	
	If(!DataFolderExists("root:EPhys"))
		NewDataFolder root:EPhys
	EndIf
	
	If(!DataFolderExists("root:EPhys:" + folder))
		NewDataFolder $("root:EPhys:" + folder)
	EndIf
	
	SetDataFolder $("root:EPhys:" + folder)
	
	Variable i,j
	
	For(j=0;j<ItemsInList(filePathList,";");j+=1)
		String fileName = StringFromList(j,filePathList,";") + ".phys"
		
		//Create a wave name
		String num = StringFromList(1,fileName,"#")
		num = num[0,2]
		
		Variable ref
	
		//Open the .phys file
		Open/R/P=filePath ref as fileName
		
		//Get the header
		Wave/T header = GetHeader(ref)
		
		//Is this a presentinator file or a pulsinator file?
		If(stringmatch(header[0][0],"*Presentinator*"))
			String type = "Presentinator"
			String stopText = "*Stimulus Protocol*"
		ElseIf(stringmatch(header[0][0],"*Pulsinator*"))
			type = "Pulsinator"
			stopText = "*Intracellular solution Ch2*"
		EndIf
		
		
		//BMP STIMULUS FILE
		FGetPos ref
		Variable bmpStart = V_filePos
		Variable dataStartPos = bmpStart
		
		FStatus ref
		Variable eof = V_logEOF
		
		If(!cmpstr(type,"Presentinator"))	
			Variable pos = -1
			Do
				String inStr = ""
				If(dataStartPos + 1000 > eof)
					inStr = PadString(inStr,eof - dataStartPos,0x20)
				Else
					inStr = PadString(inStr,1000,0x20)
				EndIf
				
				FBInRead/B=2 ref,inStr
				
				pos = strsearch(inStr,"Notes",0)
				
				If(pos != -1)
					dataStartPos += pos
				Else
					dataStartPos += 1000
				EndIf
			While(pos == -1)
			
			//Set file position to the 'Notes:' lines and read one more line to get to the actual dat
			FSetPos ref,dataStartPos
			FReadLine ref,inStr
	
		EndIf
			
	
		FGetPos ref
		dataStartPos = V_filePos + 4
		
		FSetPos ref,dataStartPos
		
		Variable inVar,dataLen
		
		//Read the data length
		FBInRead/B=2/F=3 ref,inVar
		dataLen = inVar
		
		dataStartPos += 4
		
		Close/A
		
		//16 bit data, load as a 32 bit float
		//High byte first Big-Endian
		GBLoadWave/Q/B=0/P=filePath/N=data/O=1/T={16,2}/S=(dataStartPos)/U=(dataLen) fileName 
		
		
		//Y scaling
		Variable scaleFactor = str2num(GetHeaderItem(header,"Waveform Scale Factors"))
		scaleFactor = (numtype(scaleFactor) == 2) ?  1 : scaleFactor
		
		//Get the channel scale (pA, mV, etc.)
		String chName = GetHeaderItem(header,"Waveform0 Name")
		chName = ReplaceString(")",StringFromList(1,chName,"("),"")
		
		strswitch(chName)
			case "pA":
				Variable scaleCh = 1e-12
				String scaleName = "A"
				String baseName = "Im_" + num
				break
			case "mV":
				scaleCh = 1e-3
				scaleName = "V"
				baseName = "Vm_" + num
				break
			default:
				scaleCh = 1e-12 //default to voltage clamp, measuring current
				scaleName = "A"
				baseName = "Im_" + num
				break
		endswitch
		
		scaleFactor *= scaleCh
		
		String sweepList = ""
		
		//Scale the waveform
		For(i=0;i<ItemsInList(S_WaveNames,";");i+=1)
			Wave data = $StringFromList(i,S_WaveNames,";")
			
			//Rename the wave
			KillWaves/Z $(baseName + "_" + num2str(i+1) + "_1_1")
			Rename $NameOfWave(data),$(baseName + "_" + num2str(i+1) + "_1_1")
			
			sweepList += "root:EPhys:" + folder + ":" + baseName + "_" + num2str(i+1) + "_1_1;"
			
			//Y Scaling
			Multithread data *=  scaleFactor
			SetScale/P y,0,1,scaleName,data
			
			//X scaling
			Variable sampleRate = str2num(GetHeaderItem(header,"Sample Rate"))
			sampleRate = (numtype(sampleRate) == 2) ?  1 : sampleRate
			sampleRate = 1/sampleRate
			
			SetScale/P x,0,sampleRate,"s",data
		EndFor
		
	EndFor	
	
	SetDataFolder saveDF
	
	return sweepList
End