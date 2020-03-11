#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//Command functions that are built into NeuroTools

//RUN COMMAND MASTER FUNCTION
Function RunCmd(cmd)
	String cmd
	
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
		//Imaging package commands
		case "Get ROI":
		case "dF Map":
			//Executes this middle-man function from the command line to escape the .ipf,
			//allowing me to reference potentially uncompiled functions in other packages.
			Execute/Q/Z "RunCmd_ImagingPackage(\"" + cmd + "\"" + ")"
			return 0
	endswitch
	
	//Initialize data set info structure
	STRUCT ds ds

	//Get the data set info
	Variable error = GetDataSetInfo(ds)
	
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
	
	//End the timer
	print cmd + ":",StopMSTimer(ref)/(1e6),"s"
	
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
		case "Duplicate Rename":
			NT_DuplicateRename(ds)
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
			ControlInfo/W=NT extFuncPopUp
			String extCmd = TrimString(StringFromList(1,S_Title,"\u005cJL▼   "))
			RunExternalFunction(extCmd)
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
	If(strlen(folder))
		If(!DataFolderExists(GetWavesDataFolder(ds.waves[0],1) + folder))
			NewDataFolder $(GetWavesDataFolder(ds.waves[0],1) + folder)
		EndIf
	EndIf
		
	SetDataFolder GetWavesDataFolder(ds.waves[0],1) + folder
	
	//Make output wave for each wave set
	ControlInfo/W=NT replaceSuffixCheck
	If(V_Value)
		String outputName = ReplaceSuffix(NameOfWave(ds.waves[0]),"avg")
	Else
		outputName = NameOfWave(ds.waves[0]) + "_avg"
	EndIf
	
	//Are we passing the result on?
	If(!pass)
		//Real wave
		Make/O/N=(DimSize(ds.waves[0],0),DimSize(ds.waves[0],1),DimSize(ds.waves[0],2)) $outputName
		Wave outWave = $outputName
	Else
		//Free wave to pass back to the calling function
		Make/FREE/N=(DimSize(ds.waves[0],0),DimSize(ds.waves[0],1),DimSize(ds.waves[0],2)) outWave
	EndIf
	
	//Reset outWave in case of overwrite
	outWave = 0
	
//	WSI loop
	//Do the average calculation
	String noteStr = "Average: " + num2str(ds.numWaves) + " Waves\r"
	Do
		Wave theWave = ds.waves[ds.wsi]
		Multithread outWave += theWave
		
		noteStr += StringFromList(ds.wsi,ds.paths,";") + "\r"
		ds.wsi += 1
	While(ds.wsi < ds.numWaves)
	
	Multithread outWave /= ds.numWaves
	
	//Set the wave note
	Note/K outWave,noteStr
	
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
	If(strlen(folder))
		If(!DataFolderExists(GetWavesDataFolder(ds.waves[0],1) + folder))
			NewDataFolder $(GetWavesDataFolder(ds.waves[0],1) + folder)
		EndIf
	EndIf
		
	SetDataFolder GetWavesDataFolder(ds.waves[0],1) + folder
	
	
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
				String histName = ReplaceListItem(0,NameOfWave(theWave),"_","PSTH")
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
				
				histName = ReplaceListItem(0,NameOfWave(theWave),"_","PSTH")
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
	
		ds.wsi += 1
	While(ds.wsi < ds.numWaves)
	
End

Function NT_DuplicateRename(ds)
	STRUCT ds &ds
	
	Variable numWaves,i,j,pos,numAddItems
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
					If(i > numAddItems - 1)
						addItem = StringFromList(numAddItems - 1,S_Value,",")
					Else
						addItem = StringFromList(i,S_Value,",")
					EndIf
					newName = AddListItem(addItem,newName,"_",pos)
					newName = RemoveEnding(newName,"_")
				EndIf
			EndIf
		EndFor
		
		newName = RemoveEnding(newName,"_")
		
		//If no changes in name were made, make the name unique with extra 0,1,2... at the end
		If(!cmpstr(name,newName,1)) //case-sensitive
			newName = UniqueName(newName,1,0)
		EndIf
		
		If(killOriginals)
			Rename $name,$newName
		Else
			Duplicate/O theWave,$newName
		EndIf
		
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
		If(!DataFolderExists(folderPath))
			NewDataFolder $folderPath
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
						firstWave = StringFromList(0,theWaveSet,";")
						folder = GetWavesDataFolder($firstWave,1)
					
						//full path to output wave
						outWaveName = folder + outWaveName
						
						//append full path to cmd string
						String editCommandStr = StringFromList(numCommands-1,runCmdStr,";/;") //get command string that contains the wave assignment
						editCommandStr[0,pos-1] = ""
						editCommandStr = outWaveName + editCommandStr
						
						runCmdStr = ReplaceListItem(numCommands-1,runCmdStr,";/;",editCommandStr)
	
					EndIf
					
					If(strlen(outWaveName) && !WaveExists($outWaveName))
						//doesn't exist, make it with correct dimensions
						Make/O/N=(numWaves) $outWaveName
					ElseIf(strlen(outWaveName) && WaveExists($outWaveName))
						//already exists, correct any incorrect dimensions
						Redimension/N=(numWaves) $outWaveName
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
	Do
		Wave theWave = ds.waves[ds.wsi]
		ReallyKillWaves(theWave)
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves)

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
	For(i=0;i<ItemsInList(folderList,";");i+=1)
		String path = StringFromList(i,folderList,";") + ":" + folder
		NewDataFolder/O $path
	EndFor
	
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
	
	Variable i
	For(i=0;i<ItemsInList(folderList,";");i+=1)
		String path = StringFromList(i,folderList,";") + ":" + folder
		KillDataFolder/Z $path
	EndFor
End

//Performs various measurements on the data set and puts the result in an output wave
Function NT_Measure(ds)
	STRUCT ds &ds
	
	//Get input parameters
	ControlInfo/W=NT measureType
	Variable type = V_Value
	
	//Wave note
	String theNote = ""
	
	switch(type)
		case 1: //peak
			String suffix = "_pk"
			theNote = "Peak:\n"
			break
		case 2: //peak x location
			suffix = "_pkLoc"
			theNote = "Peak Location:\n"
			break
		case 3: //area
			suffix = "_area"
			theNote = "Area:\n"
			break
		case 4: //mean
			suffix = "_avg"
			theNote = "Average:\n"
			break
		case 5: //median
			suffix = "_med"
			theNote = "Median:\n"
			break
		case 6: //sdev
			suffix = "_sdev"
			theNote = "Std. Deviation:\n"
			break
		case 7: //sem
			suffix = "_sem"
			theNote = "Std. Error:\n"
		break
	endswitch
	
	ControlInfo/W=NT measureStart
	Variable startTm = V_Value
	
	ControlInfo/W=NT measureEnd
	Variable endTm = V_Value
	//this allows each wave to have a different end point if we're using the whole wave
	Variable origEndTm = endTm 
	
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
		
		switch(type)
			case 1: //peak
				outWave[ds.wsi] = V_max
				break
			case 2: //peak x location
				outWave[ds.wsi] = V_maxLoc
				break
			case 3: //area
				outWave[ds.wsi] = area(theWave,startTm,endTm)
				break
			case 4: //mean
				outWave[ds.wsi] = V_avg
				break
			case 5: //median
				outWave[ds.wsi] = median(theWave,startTm,endTm)
				break
			case 6: //sdev
				outWave[ds.wsi] = V_sdev
				break
			case 7: //sem
				outWave[ds.wsi] = V_sem
			break
		endswitch
		
		//Add wave name to wave note
		theNote += StringFromList(ds.wsi,ds.paths,";") + "\n"
		
		//Reset the end point to its original value for the next wave
		endTm = origEndTm
		ds.wsi += 1
	While(ds.wsi < ds.numWaves)
	
	Note outWave,theNote
End