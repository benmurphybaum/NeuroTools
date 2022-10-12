#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.


//Conditional compilation, depending on Igor version
#if IgorVersion() >= 9
	Menu "TablePopup"
		"Browse File...",InsertFilePath()
		"Get Wave Names...",InsertWaveNames()
		"Insert New Row",InsertNewRow()
		"Fill Selection with Top",FillTableSelection()
		"Increment From Top",IncrementFromTop()
		"Mark By Folder",MarkByFolder()
		"Add to Igor Path",AddToIgorPath()
		"Remove Last Sub-Path",RemoveLastSubPath()
		"Load Selection",LoadDataTableSelection()
		"Collapse By Folder",CollapseByFolder()
		"New Data Set With Selection",NewDataSetWithSelection()
	End
	
	Menu "DataBrowserObjectsPopup", dynamic
		// This menu item is displayed if the shift key is not pressed
		Display1vs2MenuItemString(0), /Q, DisplayWave1vsWave2(0)
		
		// This menu item is displayed if the shift key is pressed
		Display1vs2MenuItemString(1), /Q, DisplayWave1vsWave2(1)
		
		//Create new data set with data browser selection
	NewDataSetWithBrowserSelectionString(), /Q, NewDataSetWithBrowserSelection() 
	End
#endif


	
//Removes the last folder in the Igor Path column for the selected rows in a data table
//Works oppositely to 'Add to Igor Path'
Function RemoveLastSubPath()
	
	DFREF NPD = $DSF
	
	GetWindow kwTopWin activeSW
	String panelName = S_Value
	panelName = RemoveEnding(panelName,"#archive") + "#archive"
	
	String info = TableInfo(panelName,0)
	Wave/T archive = $StringByKey("WAVE",info,":",";")

	GetSelection table,$panelName,1

	If(!WaveExists(archive))
		return 0
	EndIf

	Variable row

	For(row=V_startRow;row<V_endRow+1;row+=1)
		String path = archive[row][%IgorPath]
		path = ParseFilePath(1,path,":",1,0)
		archive[row][%IgorPath] = path
	EndFor
End

//Uses the selection in the data table and collapses all data folder into just a single row
Function CollapseByFolder()
	DFREF NPD = $DSF
	
	GetWindow kwTopWin activeSW
	String panelName = S_Value
	panelName = RemoveEnding(panelName,"#archive") + "#archive"
	
	String info = TableInfo(panelName,0)
	Wave/T archive = $StringByKey("WAVE",info,":",";")

	GetSelection table,$panelName,1

	If(!WaveExists(archive))
		return 0
	EndIf

	NVAR dti = NPD:dataTableIndex
	
	If(!NVAR_Exists(dti))
		Variable/G NPD:dataTableIndex
		NVAR dti = NPD:dataTableIndex
	EndIf
	
	//Get a list of the folder paths contained in the selection
	String list = ""
	For(dti=V_startRow;dti<V_endRow + 1;dti+=1)
		list += archive[dti][%IgorPath] + ";"
	EndFor
	
	list = RemoveDuplicateList(list,";")
	
	//Determine which rows need to be deleted within the selection
	String whichRows = ""
	Variable i
	For(i=0;i<ItemsInList(list,";");i+=1)
		String folder = StringFromList(i,list,";")
		
		Variable count = 0
		For(dti=V_startRow;dti<V_endRow + 1;dti+=1)
			If(!cmpstr(archive[dti][%IgorPath],folder))
				If(count)
					whichRows += num2str(dti) + ";"
				EndIf
				
				count += 1
			EndIf
		EndFor
	EndFor
	
	//Delete the rows, decrementing
	For(i=ItemsInList(whichRows,";")-1;i>-1;i-=1)
		Variable theRow = str2num(StringFromList(i,whichRows,";"))
		
		DeletePoints/M=0 theRow,1,archive
	EndFor
	
End

//Same as NT_LoadEphysTable but does it directly from the data table selection
Function LoadDataTableSelection()
	DFREF NPD = $DSF
	
	GetWindow kwTopWin activeSW
	String panelName = S_Value
	panelName = RemoveEnding(panelName,"#archive") + "#archive"
	
	String info = TableInfo(panelName,0)
	Wave/T archive = $StringByKey("WAVE",info,":",";")

	GetSelection table,$panelName,1

	If(!WaveExists(archive))
		return 0
	EndIf
	
	String dataset = NameOfWave(archive)
	dataset = RemoveEnding(dataset,"_archive")
	dataset = StringsFromList("1-*",dataset,"_",noEnding=1)
	
	If(!isArchive(dataSet))
		Abort "Couldn't find the data set: " + dataset
	EndIf
	
	String masterFilePathList = ""
	String channelList = ""

	DFREF NPD = $DSF
	NVAR dti = NPD:dataTableIndex
	
	//Make sure we didn't select an empty row beyond the data table
	If(V_startRow > DimSize(archive,0) - 1)
		return 0
	EndIf
	
	For(dti=V_startRow;dti<V_endRow + 1;dti+=1)	
		String fileType = 	archive[dti][%Type]
		
		strswitch(fileType)
			case "pclamp":
			case ".abf":
			case ".abf2":
			case "abf":
			case "abf2":
				//PClamp file
				//these aren't packed files, so each sweep is its own file. The File path column should hold the folder base name without the
				//trace numbers. All traces will be loaded unless indicated in one of the Pos_ columns
				String theFile = archive[dti][%Path]
				
				theFile = GetABFTrialList(theFile,archive,dti)
				
				//For each Trials entry, if multiple trials are defined, they all must have the same number of traces. Check this here
				Variable numTraces = CheckABFTraceCounts(theFile)
				
				If(!numTraces) //not all equal if zero
					Abort "All trials must have the same number of traces if defined on the same data table line."
				EndIf
				
				//Fill the trace counts into the correct data table lines
				If(numTraces > 1)					
					archive[dti][%Traces] = "1-" + num2str(numTraces)
				Else
					archive[dti][%Traces] = "1"
				EndIf
				
				channelList = archive[dti][%Channels]
				
				If(!strlen(channelList))
					channelList = "All"
				ElseIf(cmpstr(channelList,"All"))
					channelList = ResolveListItems(channelList,",",noEnding=1)
				EndIf
				
				InsertWaveNames()
				
				NT_LoadPClamp(theFile,channels=channelList,table=dataset)
				
//					LoadPClamp(theFile,channels=channelList,table=S_tableName) //list of pclamp file paths depending on the sweeps
				break
			case "wavesurfer":
			case ".h5":
			case "h5":
			case "hdf5":
			case "hdf":
				//wavesurfer file
				//these are packed files, so each one contains series of traces. Auto loads all traces unless indicated in one
				//of the Pos_ columns
				theFile = archive[dti][%Path]
				
				//		String theFile = StringFromList(dti,filePathList,";")
				channelList = archive[dti][%Channels]
				
				//Load the files one at a time so we can increment the data table index
				Load_WaveSurfer(theFile,channels=channelList,table=dataset)
				break
			case "TurnTable":
				theFile = archive[dti][%Path]
				channelList = archive[dti][%Channels]
				String seriesList = archive[dti][%Trials]
				
				If(!strlen(seriesList))
					seriesList = archive[dti][%Pos_2]
				EndIf
				
				seriesList = ResolveListItems(seriesList,",")
				
				LoadTurnTable(theFile,seriesList,channelList,archive=archive,dti=dti)
				break
		endswitch
	EndFor
	
End

//Add the user input string to the end of the igor path in the selected data table rows
Function AddToIgorPath()
	DFREF NPD = $DSF
	
	GetWindow kwTopWin activeSW
	String panelName = S_Value
	panelName = RemoveEnding(panelName,"#archive") + "#archive"
	
	String info = TableInfo(panelName,0)
	Wave/T archive = $StringByKey("WAVE",info,":",";")

	GetSelection table,$panelName,1

	If(!WaveExists(archive))
		return 0
	EndIf
	
	String input = ""
	Prompt input,"Add:"
	DoPrompt "Add to Igor Path",input
	
	If(V_flag)
		return 0
	EndIf
	
	Variable row

	For(row=V_startRow;row<V_endRow+1;row+=1)
		archive[row][%IgorPath] += input
	EndFor
End

//Marks the data table according to the folder in the 'Marker' column
Function MarkByFolder()
	DFREF NPD = $DSF
	
	GetWindow kwTopWin activeSW
	String panelName = S_Value
	panelName = RemoveEnding(panelName,"#archive") + "#archive"
	
	String info = TableInfo(panelName,0)
	Wave/T archive = $StringByKey("WAVE",info,":",";")
	
	If(!WaveExists(archive))
		return 0
	EndIf
	
	String folderList = ""
	
	Variable i,count = 1
	For(i=0;i<DimSize(archive,0);i+=1)
		String folder = archive[i][%IgorPath]
		
		If(i == 0)
			folderList = folder + ";"
		EndIf
		
		If(WhichListItem(folder,folderList,";") == -1)
			folderList += folder + ";"
			count += 1
		EndIf
		
		archive[i][%Marker] = num2str(count)			
	EndFor
End

//Inserts a new row onto the data table
Function InsertNewRow()
	DFREF NPD = $DSF
	
	GetWindow kwTopWin activeSW
	String panelName = S_Value
	panelName = RemoveEnding(panelName,"#archive") + "#archive"
	
	String info = TableInfo(panelName,0)
	Wave/T archive = $StringByKey("WAVE",info,":",";")
	
	If(!WaveExists(archive))
		return 0
	EndIf
	
	GetSelection table,$panelName,1
	
	InsertPoints/M=0 V_startRow,1,archive
End

//Fills the selected table rows with whatever is in the top selected row. Only for text waves.
Function FillTableSelection()
	GetWindow kwTopWin activeSW
	String panelName = S_Value
	panelName = RemoveEnding(panelName,"#archive") + "#archive"
	
	String info = TableInfo(panelName,0)
	Wave/T tableWave = $StringByKey("WAVE",info,":",";")
	
	GetSelection table,$panelName,3
	
	If(!V_flag)
		return 0
	EndIf
	
	//only handles text table waves for now
	If(WaveType(tableWave,1) != 2)
		return 0
	EndIf
	
	V_startCol = (V_startCol < 0) ? 0 : V_startCol
	
	Variable row,col
	For(col=V_startCol;col<V_endCol+1;col+=1)
		//Get the top selected entry in each selected column
		String entry = tableWave[V_startRow][col]
		
		For(row=V_startRow;row<V_endRow+1;row+=1)
			tableWave[row][col] = entry
		EndFor
	EndFor
End

Function AddRowsToDataTable()
	GetWindow kwTopWin activeSW
	String panelName = S_Value
	panelName = RemoveEnding(panelName,"#archive") + "#archive"
	
	String info = TableInfo(panelName,0)
	Wave/T tableWave = $StringByKey("WAVE",info,":",";")
	
	//only handles text table waves for now
	If(WaveType(tableWave,1) != 2)
		return 0
	EndIf
	
	Variable lastRow = DimSize(tableWave,0) - 1
	
	Variable numRows
	Prompt numRows,"Add how many rows?"
	DoPrompt "Add Rows To Data Table",numRows
	
	If(!V_flag)
		InsertPoints/M=0 lastRow+1,numRows,tableWave
	EndIf
End

Function CollapseToFirstItem()
	//Reduces a list input to only the first item in the list
	GetWindow kwTopWin activeSW
	String panelName = S_Value
	panelName = RemoveEnding(panelName,"#archive") + "#archive"
	
	String info = TableInfo(panelName,0)
	Wave/T tableWave = $StringByKey("WAVE",info,":",";")
	
	GetSelection table,$panelName,3
	
	If(!V_flag)
		return 0
	EndIf
	
	//only handles text table waves for now
	If(WaveType(tableWave,1) != 2)
		return 0
	EndIf

	Variable row,col
	For(col=V_startCol;col<V_endCol+1;col+=1)
		For(row=V_startRow;row<V_endRow+1;row+=1)
			//Get the top selected entry in each selected column
			String entry = tableWave[row][col]
			
			If(stringmatch(entry,"*;*") )
				String separator = ";"
			ElseIf(stringmatch(entry,"*,*") )
				separator = ","
			Else
				separator = ","
			EndIf
				
			String firstItem = ResolveListItems(entry,separator,noEnding=1)
			firstItem = StringFromList(0,firstItem,separator)
			tableWave[row][col] = firstItem
		EndFor

	EndFor
End

End

//Fills data table rows with incrementing values starting with the value of the top row
Function IncrementFromTop()
	GetWindow kwTopWin activeSW
	String panelName = S_Value
	panelName = RemoveEnding(panelName,"#archive") + "#archive"
	
	String info = TableInfo(panelName,0)
	Wave/T tableWave = $StringByKey("WAVE",info,":",";")
	
	GetSelection table,$panelName,3
	
	If(!V_flag)
		return 0
	EndIf
	
	
	//only handles text table waves for now
	If(WaveType(tableWave,1) != 2)
		return 0
	EndIf

	Variable row,col
	For(col=V_startCol;col<V_endCol+1;col+=1)
		//Get the top selected entry in each selected column
		String entry = tableWave[V_startRow][col]
		
		If(!cmpstr(GetDimLabel(tableWave,1,col),"IgorPath"))
			//For incrementing in the IgorPath column, we need to test the last folder for numeric values within the text and increment those
			entry = RemoveEnding(entry,":")
			
			Variable size = strlen(entry) - 1
			Variable pos = size
			
			String subStr = entry[size]
			String numStr = ""
			
			Do
				//If the character is a number, keeping pushing the position back to get the full number
				If(isNum(subStr))
					numStr = subStr
					pos -= 1
					subStr = entry[pos,size]
				Else
					//If the first attempt isn't a number, there isn't a number to increment
					If(pos == size)
						Variable firstNum = 0	
					Else
						firstNum = str2num(numStr)
					EndIf
					break
				EndIf
				
				If(pos == -1)
					firstNum = str2num(numStr)
					break
				EndIf
			While(1)
			
			
			For(row=V_startRow;row<V_endRow+1;row+=1,firstNum+=1)
				tableWave[row][col] = entry[0,pos] + num2str(firstNum) + ":"
			EndFor
		Else
			//Check that its a number in the top row, otherwise return
			firstNum = str2num(entry)
			
			If(numtype(firstNum == 2))
				return 0
			EndIf
			
			For(row=V_startRow;row<V_endRow+1;row+=1,firstNum+=1)
				tableWave[row][col] = num2str(firstNum)
			EndFor
		EndIf		
		
	EndFor
End

//Browses for a file, and inserts the selection into the data table
Function InsertFilePath()
	DFREF NPC = $CW
	DFREF NPD = $DSF
	
	Variable fileID
	
	GetWindow kwTopWin activeSW
	String panelName = S_Value
	
	//Ensure the subwindow is the one selected
	panelName = RemoveEnding(panelName,"#archive") + "#archive"
	
	String info = TableInfo(panelName,0)
	Wave/T archive = $StringByKey("WAVE",info,":",";")
	
//	GetSelection table,$panelName,1
	
	//Instead of replacing the selected cell with the browsed file path, we append the new browse to
	//the end of the data table, so as to avoid accidental overwrite
	
	Open/R/D/MULT=1/F="All Files:.*" fileID
	
	If(strlen(S_fileName))
		S_fileName = ReplaceString("/",S_fileName,":")
		S_fileName = ReplaceString("\r",S_fileName,";")
	Else
		return 0
	EndIf
	
	String fileNameList = S_fileName
	
	Close/A
	
	Variable i,numFiles = ItemsInList(fileNameList,";")
	
	For(i=0;i<numFiles;i+=1)
		String theFile = StringFromList(i,fileNameList,";")
		
		Variable pos = DimSize(archive,0)
		
		//is this an .abf file? If so, we need to remove the trace indexing so we can specify that in other parts of the data table
		If(stringmatch(theFile,"*.abf"))
			String fileBase = ParseFilePath(1,theFile,":",1,0)
			
			String newFileName = ParseFilePath(0,theFile,":",1,0)
			newFileName = RemoveEnding(newFileName,".abf")
			
			String trialNum = ParseFilePath(0,newFileName,"_",1,0)
			newFileName = RemoveEnding(ParseFilePath(1,newFileName,"_",1,0),"_")
			
			//buffered zeros removed
			trialNum = num2str(str2num(trialNum))
			
//			If(V_startRow > DimSize(archive,0) - 1)
			If(pos == 1)
				If(strlen(archive[0][%Path])) //only a single row that is empty, don't insert a point
					InsertPoints/M=0 pos,1,archive
				EndIf
			Else
				InsertPoints/M=0 pos,1,archive
			EndIf
//			EndIf
//			
//			If(i > 0)
//				InsertPoints/M=0 V_startRow + i,1,archive
//			EndIf
			
			archive[pos][%Path] = fileBase + newFileName
			archive[pos][%Trials] = trialNum
			archive[pos][%Type] = "pClamp"
			String type = "pClamp"
		ElseIf(stringmatch(theFile,"*.h5"))
			HDF5OpenFile fileID as theFile
			//Check for file type attribute, for turntable files.
			Make/O/N=1/T :fileType /Wave=fileType
			HDF5LoadData/A="FileType"/TYPE=1/Z/Q/O/N=fileType fileID,"/"
			type = fileType[0]
			
			KillWaves/Z fileType
			HDF5CloseFile fileID
			
			strswitch(type)
				case "turntable":
					type = "TurnTable"
					break
				default:
					type = "WaveSurfer"
					break
			endswitch
			
//			If(V_startRow > DimSize(archive,0) - 1)
			If(pos == 1)
				If(strlen(archive[0][%Path])) //only a single row that is empty, don't insert a point
					InsertPoints/M=0 pos,1,archive
				Else
					pos -= 1
				EndIf
			Else
				InsertPoints/M=0 pos,1,archive
			EndIf
//			EndIf
			
//			If(i > 0)
//			InsertPoints/M=0 V_startRow + i,1,archive
//			EndIf
			archive[pos][%Path] = theFile
			archive[pos][%Type] = type
				
		EndIf
	EndFor		
	
	return numFiles
End

Function InsertWaveNames([nFiles])
	Variable nFiles //This indicates to load the wave names for nFile - 1 rows beyond the last selected row.
	
	nFiles = (ParamIsDefault(nFiles)) ? 0 : nFiles
	
	DFREF NPC = $CW
	DFREF NPD = $DSF
	
	Variable fileID
	
	GetWindow kwTopWin activeSW
	String panelName = S_Value
	panelName = RemoveEnding(panelName,"#archive") + "#archive"
	
	String info = TableInfo(panelName,0)
	Wave/T archive = $StringByKey("WAVE",info,":",";")
	
	GetSelection table,$panelName,1
	
	If(!WaveExists(archive))
		return 0
	EndIf
	
	Variable f
	
	nFiles = (!nFiles) ? 1 : nFiles
	V_endRow += nFiles - 1
	
	Variable size = DimSize(archive,0)
	Variable startRow = size - nFiles
	Variable endRow = size
	
	For(f=startRow;f<endRow;f+=1)
		String filePathStr = archive[f][%Path]
		String type = archive[f][%Type]
		
		String folderPath = ParseFilePath(1,filePathStr,":",1,0)
		
		NewPath/O/Q/Z filePath,folderPath
		
		strswitch(type)
			case "WaveSurfer":
				HDF5OpenFile/Z/R fileID as filePathStr
				If(V_flag)
					Abort "Couldn't load the file: " + filePathStr
				EndIf
				
				//Channels indicated on the data table
				String channels = archive[f][%Channels]
				channels = ResolveListItems(channels,";",noEnding=1)
				
				//Finds the data sweep groups
				//Get the groups in the file
				HDF5ListGroup/F/R/TYPE=1 fileID,"/"
				S_HDF5ListGroup = ListMatch(S_HDF5ListGroup,"/sweep*",";")	
				Variable numSweeps = ItemsInList(S_HDF5ListGroup,";")		
				
				//Sweep List
				Variable j,k
				String sweepList = ""
				For(k=0;k<numSweeps;k+=1)
					//Get the sweep index, truncate zeros
					String theSweep = StringFromList(1,StringFromList(k,S_HDF5ListGroup,";"),"_")
					
					j = 0
					Do
						If(!cmpstr(theSweep[j],"0"))
							theSweep = theSweep[j+1,strlen(theSweep)-1] //truncate leading zeros
							continue
						Else
							break
						EndIf
						
						j += 1
					While(j < strlen(theSweep)-1)
					
					sweepList += theSweep + ","
				EndFor
				
				sweepList = RemoveEnding(sweepList,",")
				
				//Protocol name
				HDF5LoadData/N=prot/Q fileID,"/header/AbsoluteProtocolFileName"
				Wave/T prot = :prot
				String protocol = RemoveEnding(ParseFilePath(0,prot[0],"\\",1,0),".wsp")
				
				//Units for the prefix
				HDF5LoadData/N=unit/Q fileID,"/header/AIChannelUnits"
				Wave/T unit = :unit
				
				If(!strlen(channels))
					If(DimSize(unit,0) == 1)
						channels = "1"
					Else
						channels = "1-" + num2str(DimSize(unit,0))
					EndIf
					
					archive[f][%Channels] = channels
					channels = ResolveListItems(channels,";",noEnding=1)
				EndIf
				
				String channelList = ""
				
				For(j=0;j<ItemsInList(channels,";");j+=1)
					
					String theUnit = unit[j]
					String prefix = ""
					String unitBase = theUnit[1]
					
					strswitch(unitBase)
						case "A":
							//current
							prefix = "Im"
							break
						case "V":
							//voltage
							prefix = "Vm"
							break
					endswitch
					
					channelList += prefix + ","
				EndFor
				
				channelList = RemoveEnding(channelList,",")
									
				archive[f][%Pos_0] = channelList //position 0
				archive[f][%Pos_1] = "1" //position 1
				archive[f][%Pos_2] = sweepList//"1-" + num2str(numSweeps) //sweeps
				archive[f][%Pos_3] = "1" //position 3
				archive[f][%Pos_4] = "1" //position 4
				archive[f][%Comment] = protocol //position 4
				
				//Close file
				HDF5CloseFile/A fileID
				
				//Cleanup
				KillWaves/Z unit,prot
				break
			case "TurnTable":
				HDF5OpenFile/Z/R fileID as filePathStr
				If(V_flag)
					Abort "Couldn't load the file: " + filePathStr
				EndIf
				
				//Channels indicated on the data table
				channels = archive[f][%Channels]
				channels = ResolveListItems(channels,";",noEnding=1)
				
				
				//Finds the data sweep groups
				//Get the groups in the file
				HDF5ListGroup/F/R=0/TYPE=1 fileID,"/Data"
				String seriesList = ListMatch(S_HDF5ListGroup,"/Data*",";")
				seriesList = SortList(seriesList,";",16)
					
				Variable i,nSeries = ItemsInList(seriesList,";")		
				
				Make/O/N=(nSeries,7)/T NPD:dataBrowse/Wave=dataBrowse
				
				String labels = "Path;Pos_0;Pos_1;Pos_2;Pos_3;Pos_4;Protocol;"
				For(i=0;i<ItemsInList(labels,";");i+=1)
					SetDimLabel 1,i,$StringFromList(i,labels,";"),dataBrowse
				EndFor
				
				For(i=0;i<nSeries;i+=1)
					String seriesAddress = StringFromList(i,seriesList,";")
					
					//Number channels recorded
					HDF5ListGroup/F/R=0/TYPE=1 fileID,seriesAddress
					channelList = ListMatch(S_HDF5ListGroup,seriesAddress + "/Ch*",";")
					Variable nChannels = ItemsInList(channelList,";")
					
					//Number of sweeps recorded
					String channelAddress = StringFromList(0,channelList,";")
					HDF5ListGroup/F/R=0/TYPE=2 fileID,channelAddress
					sweepList = S_HDF5ListGroup
					Variable nSweeps = ItemsInList(sweepList,";")
					
					//Wave units
					String sweepAddress = channelAddress + "/1"
					HDF5LoadData/Q/O/IGOR=-1/A="IGORWaveUnits"/N=units/TYPE=2 fileID,sweepAddress
					Wave/T units
					
					strswitch(units[0])
						case "A":
							prefix = "Im"
							break
						case "V":
							prefix = "Vm"
							break
					endswitch
					
					
					//Protocol name
					Make/T/N=1/O :Protocol/Wave=prot
					
					HDF5LoadData/Q/A="Protocol"/N=Protocol/O/TYPE=1 fileID,seriesAddress
					protocol = prot[0]
					
					
					KillWaves/Z prot,units
					
					dataBrowse[i][%Pos_0] = prefix
					dataBrowse[i][%Pos_1] = "1"
					dataBrowse[i][%Pos_2] = StringFromList(2,seriesAddress,"/") //series number
					dataBrowse[i][%Pos_3] = "1-" + num2str(nSweeps) //sweep range
					dataBrowse[i][%Pos_4] = "1"
					dataBrowse[i][%Protocol] = protocol
					dataBrowse[i][%Path] = filePathStr
				EndFor
				
				HDF5CloseFile fileID
				
				//Display the finished data table
				String fileName = RemoveEnding(ParseFilePath(0,filePathStr,":",1,0),".h5")
				String tableName = UniqueName("DataBrowser",7,0)
				Edit/K=1/W=(100,100,800,400)/N=$tableName dataBrowse as fileName
				ModifyTable/W=$tableName horizontalIndex=2,alignment=1
				
				break
			case "pClamp":
				//NEED TO CODE
				STRUCT abfInfo a
				
				//Get the full paths to each file
				String fileList = IndexedFile(filepath,-1,".abf")
				
				If(!strlen(fileList))
					return 0
				EndIf
				
				fileList = SortList(fileList,";",16)
				
				fileList = ReplaceString(".abf",fileList,"")
				//check if archive table has preset trace numbers to load
				String traceList = ""
				traceList = archive[f][%Trials]
				
				If(strlen(traceList))
					traceList = ResolveListItems(traceList,";")
					String firstTrace = StringFromList(0,traceList,";")
					
					//Take out the zero buffer in the file name
					If(str2num(firstTrace) < 10)
						firstTrace = "000" + firstTrace
					ElseIf(str2num(firstTrace) < 100)
						firstTrace = "00" + firstTrace
					ElseIf(str2num(firstTrace) < 1000)
						firstTrace = "0" + firstTrace
					EndIf
				Else
					firstTrace = StringFromList(0,fileList,";")
					firstTrace = ParseFilePath(0,firstTrace,"_",1,0)
				EndIf

				If(!strlen(firstTrace))
					sweepList = ""
					For(i=0;i<ItemsInList(fileList,";");i+=1)
						String fileStr = StringFromlist(i,fileList,";")
						fileStr = ParseFilePath(0,fileStr,":",1,0)
						sweepList += ParseFilePath(0,fileStr,"_",1,0) + ";"
					EndFor
					
					//Assume all defined traces have the same properties for a single line on a data table.
					filePathStr += "_" + StringFromList(0,sweepList,";")
				Else
					filePathStr += "_" + firstTrace
				EndIf
									
				//Open pclamp file
				Variable refnum
				filePathStr = RemoveEnding(filePathStr,".abf") + ".abf"
				
			
				Open/R/Z=2 refnum as filePathStr
				If(V_flag == -1)
					Abort "Couldn't load the file: " + filePathStr
				EndIf
				
				//Number sweeps
				FSetPos refnum,12
				FBInRead/B=3/F=3 refnum,a.nSweeps
				
				//Data format
				FSetPos refnum,30
				FBInRead/B=3/F=2 refnum,a.dataFormat
				
				Variable dataSz	,bitFormat
				switch(a.dataFormat)
					case 0:
						dataSz = 2 //bytes/point
						bitFormat = 2
						break
					case 1:
						dataSz = 4 //bytes/point
						bitFormat = 3
						break
					default:
						DoAlert 0,"Invalid number format"
						return -1
						break
				endswitch
			
				//Section info
				Wave ADCSection = GetADCSection(refnum)
				Wave DataSection = GetDataSection(refnum)
				Wave ProtocolSection = GetProtocolSection(refnum)
				Wave StringsSection = GetStringsSection(refnum)
				Wave SynchArraySection = GetSynchSection(refnum)
				
				//Number channels
				a.nChannels = ADCSection[2]
	
				//Longer strings information about the recording
				FSetPos refnum,StringsSection[0]*512
				String bigString = ""
				bigString = PadString(bigString,StringsSection[1],0)
				FBInRead refnum,bigString
				String progStr = "clampex;clampfit;axoscope;patchexpress"
				Variable goodStart
				For(i=0;i<4;i+=1)
					goodStart = strsearch(bigString,StringFromList(i,progStr,";"),0,2)
					If(goodStart)
						break
					EndIf
				EndFor
				
				Variable lastSpace = 0
				Variable nextSpace
			
				bigString = bigString[goodStart,strlen(bigString)]
				Make/FREE/T/N=1 Strings
				Strings[0] = ""
				For(i=0;i<30;i+=1)
					Redimension/N=(i+1) Strings
					nextSpace = strsearch(bigString,"\u0000",lastSpace)
					If(nextSpace == -1)
						Redimension/N=(i) Strings
						break
					EndIf
					Strings[i] = bigString[lastSpace,nextSpace-1]
					lastSpace = nextSpace + 1
				EndFor
				
				
				//Get protocol name
				protocol = Strings[1]
				protocol = ParseFilePath(0,protocol,"\\",1,0)
				protocol = RemoveEnding(protocol,".pro")
				
				archive[f][%Comment] = protocol
				
				//Get the Channel names, units, and scales
				a.ChannelNames = ""
				a.ChannelUnits = ""
				a.ChannelBase = ""
				
				
				Variable c
				For(i=0;i<a.nChannels;i+=1)
			
					String name = Strings[2 + 2 * i]
					String unitStr = Strings[3 + 2 * i]
					
					a.ChannelNames += name + ";"
					a.ChannelUnits += unitStr + ";"
					a.ChannelScale[i] = 0 //reset
					a.ChannelBase += unitStr[1,strlen(unitStr)-1] + ";"
							
					//Channel indices that were recorded
					a.ChannelIndex[i] = GetADCParam(refnum,ADCSection,i,"ADCNum")
				EndFor
				
				unitBase = StringFromList(c,a.channelBase,";")
				
			
				//Reset the trace section
				archive[f][%Pos_4] = ""
				
				
				sweepList = ResolveListItems(archive[f][%Pos_3],",",noEnding=1)
				
				If(!strlen(sweepList))
					Variable autoSweepName = 1
				Else
					autoSweepName = 0
				EndIf
				
				
				
				For(i=0;i<a.nSweeps;i+=1)
										
					//Figure out the wave names for each of the channels in each sweep
				
					//Prefix
					strswitch(unitBase)
						case "A": //amps, voltage clamp
							prefix = "Im"
							break
						case "V": //volts, current clamp
							prefix = "Vm"
							break
					endswitch
					
					String group = archive[f][%Pos_1]
					If(!strlen(group))
						group = "1"
					EndIf
					
					String series = ParseFilePath(0,filePathStr,":",1,0)
					series = ParseFilePath(0,series,"_",1,0)
					series = ParseFilePath(0,series,".",0,0)
					series = num2str(str2num(series))
					
					If(autoSweepName)
						String sweep = num2str(i+1)
					Else
						sweep = StringFromList(i,sweepList,",")
					EndIf
					
					
					
					String trace = "1"
					
					If(!strlen(archive[f][%Pos_0]))
						archive[f][%Pos_0] = prefix
					EndIf
					
					If(strlen(traceList))
						archive[f][%Pos_2] = archive[f][%Trials]
					Else
						archive[f][%Pos_2] += series + ","
						archive[f][%Trials] += series + ","
					EndIf
					
					archive[f][%Pos_1] = group
					archive[f][%Pos_3] += sweep + ","
					
					//Insert the channels, but only for initial loop
					If(i == 0)
						If(strlen(archive[f][%Channels]))
							archive[f][%Pos_4] = archive[f][%Channels]
						Else
							For(c=0;c<a.nChannels;c+=1)
								archive[f][%Pos_4] += num2str(a.ChannelIndex[c]) + ","
								archive[f][%Channels] += num2str(a.ChannelIndex[c]) + ","
							EndFor
							
							archive[f][%Pos_4] = RemoveEnding(archive[f][%Pos_4],",")
							archive[f][%Channels] = RemoveEnding(archive[f][%Channels],",")
						EndIf
					EndIf														
				EndFor
				
				
				archive[f][%Pos_2] = RemoveEnding(archive[f][%Pos_2],",")	
				
				//Sweeps
				If(strlen(archive[f][%Traces]))
					String fileSweepList = ResolveListItems(archive[f][%Traces],",",noEnding=1)
					
					If(ItemsInList(sweep,",") != ItemsInList(fileSweepList,","))
						archive[f][%Pos_3] = archive[f][%Traces]
					EndIf
				Else
					archive[f][%Traces] = archive[f][%Pos_3]
				EndIf
				
				//Cleanup the index lists
				If(!stringmatch(archive[f][%Pos_2],"*-*"))
					archive[f][%Pos_2] = ListToRange(archive[f][%Pos_2],",")
					archive[f][%Trials] = archive[f][%Pos_2]
				EndIf
				
				If(!stringmatch(archive[f][%Pos_3],"*-*"))
					String fullTraceList = ResolveListItems(archive[f][%Pos_3],",",noEnding=1)
					
					archive[f][%Traces] = "1-" + num2str(ItemsInList(fullTraceList,","))
					archive[f][%Pos_3] = ListToRange(archive[f][%Pos_3],",")
				EndIf
				
				If(!stringmatch(archive[f][%Pos_4],"*-*"))
					archive[f][%Pos_4] = ListToRange(archive[f][%Pos_4],",")
					archive[f][%Channels] = archive[f][%Pos_4]
				EndIf
				
				break
		endswitch
	EndFor	
	
End

//Creates a new data set archive with the selected rows in the current data archive
Function NewDataSetWithSelection()
	DFREF NPD = $DSF
	
	GetWindow kwTopWin activeSW
	String panelName = S_Value
	panelName = RemoveEnding(panelName,"#archive") + "#archive"
	
	String info = TableInfo(panelName,0)
	Wave/T tableWave = $StringByKey("WAVE",info,":",";")

	GetSelection table,$panelName,1

	If(!WaveExists(tableWave))
		return 0
	EndIf
		
	//only handles text table waves for now
	If(WaveType(tableWave,1) != 2)
		return 0
	EndIf

	//Get the top selected entry in each selected column
	Variable numRows = V_endRow - V_startRow + 1
		
	String dsName = NewDataTable()
	
	If(!strlen(dsName))
		DoAlert/T="New Data Set" 0,"Data set already exists. Choose a different name."
		return 0
	EndIf
	
	Wave/T archive = NPD:$("DS_" + dsName + "_archive")
	
	Redimension/N=(numRows,-1) archive
	
	archive = tableWave[p + V_startRow][q]
	
End

//Global references
StrConstant CW = "root:Packages:NeuroToolsPlus:ControlWaves"
StrConstant DSF = "root:Packages:NeuroToolsPlus:DataSets"
StrConstant SI = "root:Packages:NeuroToolsPlus:ScanImage"
StrConstant SIR = "root:Packages:NeuroToolsPlus:ScanImage:ROIs"
StrConstant LIGHT = "Roboto Light"
StrConstant REG = "Roboto"
StrConstant MED = "Roboto Medium"
StrConstant TITLE = "Bodoni 72 Smallcaps"
StrConstant SUBTITLE = "Bodoni 72 Oldstyle"


//Graph marquee menu extension
Menu "GraphMarquee"
	"Horiz Expand All",expandAxis("bottom")
	"Vert Expand All",expandAxis("left")
End


Function/S NewDataSetWithBrowserSelectionString()
	DoWindow NTP
	If(DataFolderExists("root:Packages:NeuroToolsPlus:Datasets") && V_flag)
		String menuStr = "New Data Set with Selection"
	Else
		menuStr = ""
	EndIf
	
	return menuStr
End

//Creates a new data set with the current data browser selection
Function NewDataSetWithBrowserSelection()
	
	STRUCT filters filters
	
	String list = ""
	Variable index=0
	do
		String name = GetBrowserSelection(index)
		if (strlen(name) <= 0)
			break
		endif
		list += name + ";"
		index+=1
	while(1)
	
	DFREF NPD = $DSF
	DFREF NPC = $CW
	
	SVAR notificationEntry = NPC:notificationEntry
	SVAR folderSelection =  NPC:folderSelection
	
	//Data Set Names list box Selection and List waves
	Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
	Wave DSNamesLB_SelWave = NPD:DSNamesLB_SelWave
	
	String dsName
	Prompt dsName,"Name"
	DoPrompt "Add New Data Set",dsName
	
	If(V_flag)
		return 0
	EndIf
	
	//Find available data set name
	//Test if the data set name already exists
	//If it does, delete the data set first before making a new one
	index = tableMatch(dsName,DSNamesLB_ListWave)
	If(index != -1)
		//Can't overwrite data set using AddDataSet button
		//Must update data set instead
		DoAlert 0,"Data set name already in use"
	EndIf
	
	String dsWaveName = "DS_" + dsName
	
	Variable numWaves = ItemsInlist(list,";")
	
	//BASE data set - not organized, and no wave set labels
	Make/T/O/N=(numWaves,1,2) NPD:$dsWaveName 
	Wave/T DS_BASE = NPD:$dsWaveName
	
	//ORGANIZED data set - contains wave set labels
	Make/T/O/N=(numWaves,1,2) NPD:$(dsWaveName + "_org") 
	Wave/T DS_ORG = NPD:$(dsWaveName + "_org")
	
	//This holds the data set wave paths
	Wave/T fullPath = StringListToTextWave(list,";")
	Duplicate/FREE/T fullPath,nameOnly
	
	nameOnly = ParseFilePath(0,fullPath[p],":",1,0)
	
	DS_BASE[][0][1] = fullPath[p][0][0]
	DS_ORG[][0][1] = fullPath[p][0][0]
	
	DS_BASE[][0][0] = nameOnly[p][0][0]
	DS_ORG[][0][0] = nameOnly[p][0][0]
	
	//Add the new data set to the Data Set Names list box
	Variable numDS = DimSize(DSNamesLB_ListWave,0)
	
	Redimension/N=(numDS+1,1,3) DSNamesLB_ListWave
	Redimension/N=(numDS+1) DSNamesLB_SelWave
	DSNamesLB_ListWave[numDS][0][0] = dsName
	
	//Select the newly made data set
	DSNamesLB_SelWave = 0
	DSNamesLB_SelWave[numDS] = 1
	
	//Display the newly made data set in the Data Set Waves list box
	Wave/T DataSetLB_ListWave = NPD:DataSetLB_ListWave
	Wave DataSetLB_SelWave = NPD:DataSetLB_SelWave
	
	//Push the organized data set waves into the data set waves list box
	matchContents(DS_ORG,DataSetLB_ListWave)
	
	Redimension/N=(DimSize(DS_ORG,0)) DataSetLB_SelWave
	DataSetLB_SelWave = 0
	
	//Change the displayed data set to the one that now occupies that list position
	index = tableMatch(dsName,DSNamesLB_ListWave)
	
	If(index != -1)
		ListBox DataSetNamesListBox win=NTP#Data,selRow=(index)
	EndIf

	//Update the controls with the saved WaveMatch filter settings
	//Return string is just for quality control and debugging
	
	//Initiate the filter structure with SVARs
	SetFilterStructure(filters,"")
	
	//Get the filter settings from the WaveMatch list box
	String filterSettingStr = recallFilterSettings("WaveMatch")
	
	//Remove all values filter values (prefix thru trace)
	Variable i
	For(i=3;i<10;i+=1) 
		filterSettingStr += StringFromList(i,filterSettingStr,";") + ";"
		filterSettingStr = ReplaceListItem(i,filterSettingStr,";","")
	EndFor
	
	//Append to the data set definition
	DSNamesLB_ListWave[index][0][1] = filterSettingStr
	
	//Save the folder selection that went into building this data set
	DSNamesLB_ListWave[index][0][2] = folderSelection
	
	//add Data Set name to a string list for the Parameters panel list box
	updateDSNameList()
	
	//display the full path to the wave in a text box
	drawFullPathText()
	
	//Create the data set note string
	String notesName = ReplaceString(" ",dsName,"_")
	String/G NPD:$("DS_" + notesName + "_notes")
	SVAR DSNotes = NPD:$("DS_" + notesName + "_notes")
	DSNotes = "_"
	
	//Add the new data set to the All group
	AddToDSGroup(dataset=dsName,group="All")
	
	//How many data sets are defined?
	Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
	If(DimSize(DSNamesLB_ListWave,0) > 0)
	   SetDrawLayer/W=NTP#Data UserBack
	   DrawAction/W=NTP#Data getgroup=dataSetGroupText,delete
		CloseDSGroupForm() //first close a potentially already open form
		SetupDSGroupForm(dsName) //reopen the form with the new data set
	EndIf
	
	SetDSGroup(group="All",dataset=dsName)
	
	//Switch focus to the DataSet list box
	changeFocus("DataSet",1)
	
	notificationEntry = "New Data Set: \f01" + dsName
	SendNotification()
End

// If at least two items are selected in the Data Browser object list and the
// first two selected items are numeric waves, this function returns the first
// selected wave via w1 and the second selected wave via w1 unless reverse
// is non-zero in which case the waves are reversed.
// The function result is 1 if the first two selected objects are numeric waves
// and 0 otherwise.
static Function GetWave1AndWave2(WAVE/Z &w1, WAVE/Z &w2, int reverse)
	if (strlen(GetBrowserSelection(-1)) == 0)
		return 0	// Data Browser is not open
	endif
	
	WAVE/Z w1 = $(GetBrowserSelection(reverse ? 1 : 0))	// May be null
	WAVE/Z w2 = $(GetBrowserSelection(reverse ? 0 : 1))	// May be null

	if (!WaveExists(w1) || !WaveExists(w2))
		return 0		// Fewer than two waves are selected
	endif

	if (WaveType(w1,1)!=1 || WaveType(w2,1)!=1)
		return 0		// Waves are not numeric
	endif
	
	return 1
End

Function/S Display1vs2MenuItemString(reverse)
	int reverse	// True (1) if caller wants the reverse menu item string
	
	int shiftKeyPressed = GetKeyState(0) & 4	// User is asking for reverse?
	if (shiftKeyPressed && !reverse)
		// User is asking for reverse so hide unreversed menu item
		return ""
	endif
	if (!shiftKeyPressed && reverse)
		// User is not asking for reverse so hide reversed menu item
		return ""
	endif
	
	WAVE/Z w1, w2
	int twoNumericWavesSelected = GetWave1AndWave2(w1, w2, reverse)
	if (!twoNumericWavesSelected)
		return ""
	endif

	String menuText
	sprintf menuText, "Display %s vs %s", NameOfWave(w1), NameOfWave(w2)
	return menuText
End

// If reverse is false, execute Display w1 vs w2
// If reverse is true, execute Display w2 vs w1
Function DisplayWave1vsWave2(int reverse)
	WAVE/Z w1, w2
	int twoNumericWavesSelected = GetWave1AndWave2(w1, w2, reverse)
	if (twoNumericWavesSelected)
		Display w1 vs w2
	endif
End


//Menu "NeuroTools+"
//	"Image Browser/1",OpenImageBrowser()
//	"-"
//	
//	SubMenu "Analysis Packages"
//		NTP#GetUserPackages(fullIPFList=1,includesOnly=1),GotoProc()
//	End
//	
////	SubMenu "Data Sets"
////		"New Data Table",NewDataTable()
////	End
//	
//	"Manage Packages",ManagePackages()
//	
//	"-"
//	
//	"Report a bug",ReportBug()
//	
//	NTP#MenuSwitch("Check for updates...",1),NTP#CheckForUpdates()
//	NTP#MenuSwitch("About...",1),NTP#DisplayVersion()
//End


Function ManagePackages()
	//Opens the package manager
	String packageList = NTP#GetUserPackages()
	Variable nPackages = ItemsInList(packageList,";")
	
	DoWindow/F PackageManager
	
	If(!V_flag)
		NewPanel/K=1/N=PackageManager/W=(300,100,500,100 + nPackages * 25 + 30) as "Package Manager"
	EndIf
	
	DFREF NPC = $CW
	SVAR HideUserPackages =  NPC:HideUserPackages
	If(SVAR_Exists(HideUserPackages))
		String hideList = HideUserPackages
	Else
		hideList = ""
	EndIf
	
	Variable i,yPos = 20
	For(i=0;i<nPackages;i+=1)
		String package = RemoveEnding(StringFromList(i,packageList,";"),".ipf")
		
		Variable isHidden = WhichListItem(package,hideList,";")
		isHidden = (isHidden != -1) ? 0 : 1

		String ctrlName = "Package_" + num2str(i)
		Checkbox $ctrlName win=PackageManager,pos={20,yPos},size={100,20},value=isHidden,disable=0,title=package
		
		yPos += 22
	EndFor
	
	Button SetPackages win=PackageManager,pos={20,yPos},size={150,20},title="Update Packages",proc=PackageManagerProc
End

Function UpdatePackages(HideUserPackages,[init])
	//adjusts the function menu list to include specified packages 
	String HideUserPackages
	Variable init //indicates this is an initial loading operation, so here we won't overwrite the preferences file
	
	init = (ParamIsDefault(init)) ? 0 : 1
	
	DFREF NPC = $CW
	
	//Path to a possible package preferences text wave
	String prefPath = SpecialDirPath("Igor Pro User Files",0,0,0)	
	prefPath += "User Procedures:NeuroTools+:PackagePreferences.txt"
		
	//Get use installed package files
	String userFunctionPath = SpecialDirPath("Igor Pro User Files",0,0,0)	
	userFunctionPath += "User Procedures:NeuroTools+:Functions"
	String fileList = ""
	
	GetFileFolderInfo/Q/Z userFunctionPath
	If(!V_flag)
		NewPath/O/Q userPath,userFunctionPath
		If(V_isFolder)
			String userFileList = IndexedFile(userPath,-1,".ipf")
			fileList += userFileList
		EndIf
	Else
		return 0
	EndIf
	
	//Create an additional param table to save the package parameters in case the packages are added back in again
	Wave/T param = NPC:ExtFunc_Parameters
	Wave/Z/T copy = NPC:ExtFunc_Parameters_copy
	
	If(WaveExists(copy))
		//If this isn't the first time, we need to recover the original parameters from the copy table
		Redimension/N=(DimSize(copy,0),DimSize(copy,1)) param
		param = copy
		CopyDimLabels copy,param
	Else
		//If this is the first time packages are being managed, make a copy of the parameters table
		Make/O/T/N=(DimSize(param,0),DimSize(param,1)) NPC:ExtFunc_Parameters_copy
		Wave/T copy = NPC:ExtFunc_Parameters_copy
		copy = param
		CopyDimLabels param,copy
	EndIf
	
	Variable i,j
	For(i=0;i<ItemsInList(HideUserPackages,";");i+=1)
		String package = StringFromList(i,HideUserPackages,";")
		Variable whichipf = WhichListItem(package + ".ipf",fileList,";")
		
		//found the ipf, now lets remove all functions within that ipf from the parameters table
		If(whichipf != -1)
			package += ".ipf"
			String packageFunctions = FunctionList("*NT_*",";","WIN:" + package)
			
			For(j=0;j<ItemsInList(packageFunctions,";");j+=1)
				String fn = StringFromList(j,packageFunctions,";")
				Variable whichCol = FindDimLabel(param,1,fn)
				
				If(whichCol != -1)
					DeletePoints/M=1 whichCol,1,param
				EndIf
			EndFor
		Else
			//didn't find the ipf, lets check if its a folder
			//Find any package folders within the Functions folder
			String UserPackageFolders = IndexedDir(userPath,-1,0)
			Variable whichfolder = WhichListItem(package,UserPackageFolders,";")
			
			If(whichFolder != -1)
				//found the package folder, lets now get the ipfs inside
				String packageFolderPath = userFunctionPath + ":" + package
				NewPath/O/Q/Z packagePath,packageFolderPath
				
				userFileList = IndexedFile(packagePath,-1,".ipf")				
				
				//now get a list of all the 'NT_' functions within these ipfs
				packageFunctions = ""
				For(j=0;j<ItemsInlist(userFileList,";");j+=1)
					String packageFile = StringFromList(j,userFileList,";")
					packageFunctions += FunctionList("*NT_*",";","WIN:" + packageFile)
				EndFor
				
				//exclude the identified functions from the function menu
				For(j=0;j<ItemsInList(packageFunctions,";");j+=1)
					fn = StringFromList(j,packageFunctions,";")
					whichCol = FindDimLabel(param,1,fn)
					
					If(whichCol != -1)
						DeletePoints/M=1 whichCol,1,param
					EndIf
				EndFor
			EndIf
		EndIf
	EndFor
	
	//Rebuild the functions menu
	BuildMenu "FunctionMenu"	
	
	If(!init)
		//Save the preferences as a global preferences text file called PackagePreferences.txt
		Make/T/FREE packagePreferenceWave
		Wave/T packagePreferenceWave = StringListToTextWave(HideUserPackages,";")
			
		Save/O/G/M="\n"/W packagePreferenceWave as prefPath
	EndIf	
End

Function PackageManagerProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			
			DFREF NPC = $CW
			
			//Save packages list for possible reloads
			String/G NPC:UserPackages
			SVAR UserPackages =  NPC:UserPackages
			UserPackages = ""
			
			//Save packages list for possible reloads
			String/G NPC:HideUserPackages
			SVAR HideUserPackages =  NPC:HideUserPackages
			HideUserPackages = ""
			
			Variable i = 0
			Do
				String ctrlName = "Package_" + num2str(i)
				ControlInfo/W=PackageManager $ctrlName
				
				If(!V_flag)
					break
				EndIf
				
				If(V_Value)
					UserPackages += S_Title + ";"
				Else
					HideUserPackages += S_Title + ";"
				EndIf
							
				i += 1
			While(V_flag != 0)
			
			UpdatePackages(HideUserPackages)
			
			//Change button color briefly to indicate update
			Button SetPackages win=PackageManager,fColor=(500,0x2000,500,0x4000)
			ControlUpdate/W=PackageManager SetPackages
			Variable dur,t = ticks
			Do
				dur = ticks - t
			While(dur < 20)
			
			Button SetPackages win=PackageManager,fColor=(0,0,0)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Menu "ColorMenu",contextualMenu,dynamic
	"Custom"
	
	Submenu "Color Tables"
		"*COLORTABLEPOP*(0,0,0,0)"
	End
End

Menu "FunctionMenu",contextualMenu,dynamic
	
	//For functions that have no submenu definitions
	GetSubMenuItems(-1)
	
	"-"
	
	//set up maximum of 10 potential submenus
	SubMenu GetSubMenuName(0)
		GetSubMenuItems(0)
	End
	
	SubMenu GetSubMenuName(1)
		GetSubMenuItems(1)
	End
	
	SubMenu GetSubMenuName(2)
		GetSubMenuItems(2)
	End
	
	SubMenu GetSubMenuName(3)
		GetSubMenuItems(3)
	End
	
	SubMenu GetSubMenuName(4)
		GetSubMenuItems(4)
	End
	
	SubMenu GetSubMenuName(5)
		GetSubMenuItems(5)
	End
	
	SubMenu GetSubMenuName(6)
		GetSubMenuItems(6)
	End
	
	SubMenu GetSubMenuName(7)
		GetSubMenuItems(7)
	End
	
	SubMenu GetSubMenuName(8)
		GetSubMenuItems(8)
	End
	
	SubMenu GetSubMenuName(9)
		GetSubMenuItems(9)
	End
	
	SubMenu GetSubMenuName(10)
		GetSubMenuItems(10)
	End
	
	SubMenu GetSubMenuName(11)
		GetSubMenuItems(11)
	End
	
	SubMenu GetSubMenuName(12)
		GetSubMenuItems(12)
	End
	
	SubMenu GetSubMenuName(13)
		GetSubMenuItems(13)
	End
	
	SubMenu GetSubMenuName(14)
		GetSubMenuItems(14)
	End
	
	SubMenu GetSubMenuName(15)
		GetSubMenuItems(15)
	End
	
	SubMenu GetSubMenuName(16)
		GetSubMenuItems(16)
	End
	
	SubMenu GetSubMenuName(17)
		GetSubMenuItems(17)
	End
	
End

//contextual menu for the data set waves pop ups, supports up to 15 data groups as sub menus
Menu "DSWavesMenu",contextualMenu,dynamic
	
	"**Wave Match**;**Navigator**;"
	
	SubMenu GetDataGroupNameByIndex(0)   
		GetDataGroupContentsByIndex(0)
	End
	SubMenu GetDataGroupNameByIndex(1)
		GetDataGroupContentsByIndex(1)
	End
	SubMenu GetDataGroupNameByIndex(2)
		GetDataGroupContentsByIndex(2)
	End
	SubMenu GetDataGroupNameByIndex(3)
		GetDataGroupContentsByIndex(3)
	End
	SubMenu GetDataGroupNameByIndex(4)
		GetDataGroupContentsByIndex(4)
	End
	SubMenu GetDataGroupNameByIndex(5)
		GetDataGroupContentsByIndex(5)
	End
	SubMenu GetDataGroupNameByIndex(6)
		GetDataGroupContentsByIndex(6)
	End
	SubMenu GetDataGroupNameByIndex(7)
		GetDataGroupContentsByIndex(7)
	End
	SubMenu GetDataGroupNameByIndex(8)
		GetDataGroupContentsByIndex(8)
	End
	SubMenu GetDataGroupNameByIndex(9)
		GetDataGroupContentsByIndex(9)
	End
	SubMenu GetDataGroupNameByIndex(10)
		GetDataGroupContentsByIndex(10)
	End
	SubMenu GetDataGroupNameByIndex(11)
		GetDataGroupContentsByIndex(11)
	End
	SubMenu GetDataGroupNameByIndex(12)
		GetDataGroupContentsByIndex(12)
	End
	SubMenu GetDataGroupNameByIndex(13)
		GetDataGroupContentsByIndex(13)
	End
	SubMenu GetDataGroupNameByIndex(14)
		GetDataGroupContentsByIndex(14)
	End

End

//Add in layout tools for figure sizing to single,1.5, and double column
Menu "Layout"
	SubMenu "Figure Size Box"
		SubMenu "EJN"
			"1 column, 8.8cm",NTP_AppendFigureSizeBox(1,8.8,"UserBack")
		End
		
		SubMenu "JCN"
			"1 column, 8.3cm",NTP_AppendFigureSizeBox(1,8.3,"UserBack")
			"2 column, 17.3cm",NTP_AppendFigureSizeBox(1,17.3,"UserBack")
		End
		
		SubMenu "J. Neurosci."
			"1 column, 8.5cm",NTP_AppendFigureSizeBox(1,8.5,"UserBack")
			"1.5 column, 11.6cm",NTP_AppendFigureSizeBox(1,11.6,"UserBack")
			"2 column, 17.6cm",NTP_AppendFigureSizeBox(1,17.6,"UserBack")
		End
		
		SubMenu "J. Neurophys."
			"1 column, 8.9cm",NTP_AppendFigureSizeBox(1,8.9,"UserBack")
			"2 column, 12.7cm",NTP_AppendFigureSizeBox(1,12.7,"UserBack")
			"Full width, 18cm",NTP_AppendFigureSizeBox(1,18,"UserBack")
			"Max size, 22.86cm",NTP_AppendFigureSizeBox(1,22.86,"UserBack")
		End
		
		SubMenu "Cell Press"
			"1 column, 8.5cm",NTP_AppendFigureSizeBox(1,8.5,"UserBack")
			"1.5 columns, 11.4cm",NTP_AppendFigureSizeBox(1,11.4,"UserBack")
			"2 columns, 17.4cm",NTP_AppendFigureSizeBox(1,17.4,"UserBack")
		End 
		
		SubMenu "Nature"
			"1 column, 8.9 cm",NTP_AppendFigureSizeBox(1,8.9,"UserBack")
			"1.5 column, 12.0 cm",NTP_AppendFigureSizeBox(1,12.0,"UserBack")
			"1.5 column, 13.6 cm",NTP_AppendFigureSizeBox(1,13.6,"UserBack")
			"2 column, 18.3 cm",NTP_AppendFigureSizeBox(1,18.3,"UserBack")
		End
	End
End

//Appends a box to the User Back layer of the layout, at the selected column size
Function NTP_AppendFigureSizeBox(line,size,layer)
	Variable line,size; String layer
	
	Variable left,top,right,bottom
	Variable cm_to_points = 28.35
	Variable pageMargin = 0.67 //cm
	Variable printWidth = 20.32 //cm
	Variable printHeight = 25.8 //cm
	
	left = round((pageMargin + printWidth/2 - size/2)*cm_to_points)
	top = round(pageMargin*cm_to_points)
	right = round(left + size*cm_to_points)
	bottom = round(top + printHeight*cm_to_points)
	SetDrawLayer $layer
	SetDrawEnv linethick= line,fillpat= 0
	DrawRect left,top,right,bottom
end


Function/S GetProcList()
	String theProc = ProcedureText("",0,"NeuroTools+.ipf")[0,800]
	String procList = ""
	
	Variable pos = 0
	Do
		pos = strsearch(theProc,"#include",pos)
		
		pos = strsearch(theProc,"\"",pos) //first quote position
		Variable secondQuote = strsearch(theProc,"\"",pos + 1) //second quote position
		
		If(pos)
			procList += theProc[pos+1,secondquote-1] + ";"
		EndIf
		pos = secondQuote + 1
	While(pos > 0)
	
	print procList
	return procList
End

Function GoToProc()
	GetLastUserMenuInfo
	DisplayProcedure/W=$(S_Value)
End

//Returns the indexed submenu name. Supports up to 10
Function/S GetSubMenuName(index)
	Variable index
	DFREF NPC = $CW
	Wave/T param = NPC:ExtFunc_Parameters
	
	String/G NPC:submenuList
	SVAR submenuList = NPC:submenuList
	submenuList = ""
	
	Variable row = FindDimLabel(param,0,"SUBMENU")
	
	If(row == -1)
		return "-"
	EndIf
	
	//Find the total list of submenus
	Variable i
	For(i=0;i<DimSize(param,1);i+=1)
		String item = param[row][i]
		
		If(strlen(item))
		
			//was the item already found
			submenuList += item + ";"
		EndIf
	EndFor
	
	//remove all duplicate entries
	submenuList = removeduplicateList(submenuList,";")
	
	//Sort the list alphanumerically, case-insensitive
	submenuList = SortList(submenuList,";",16)
	
	String name = StringFromList(index,submenuList,";")
	If(strlen(name))
		return name
	Else
		return "-"
	EndIf
End


//Returns the items for the indexed submenu
Function/S GetSubMenuItems(index)
	Variable index
	DFREF NPC = $CW
	
	If(!DataFolderRefStatus(NPC))
		CreatePackageFolders()
		CreatePackageWaves()
	EndIf
	
	Wave/T param = NPC:ExtFunc_Parameters
	SVAR submenuList = NPC:submenuList
	String func="",itemList = "",groupList = ""
	
	Variable row = FindDimLabel(param,0,"SUBMENU")
	Variable titleRow = FindDimLabel(param,0,"TITLE")
	Variable groupRow = FindDimLabel(param,0,"SUBGROUP")
	
	If(index != -1)
		//Testing for submenu assignments
		String submenuName = StringFromList(index,submenuList,";")
		If(!strlen(submenuName))
			return ""
		EndIf

		If(row == -1)
			return ""
		EndIf

		//Find the functions that are assigned to the named submenu
		Variable i
		For(i=0;i<DimSize(param,1);i+=1)
			String assignment = param[row][i]
			
			If(groupRow == -2)
				String subGroup = ""
			Else
				subGroup = param[groupRow][i]
			EndIf
					
			If(!cmpstr(assignment,submenuName))
				If(titleRow < 0) //no title in param file
					func = GetDimLabel(param,1,i)
					itemList += func + ";"
					groupList += subGroup + ";"
				Else
					func = param[titleRow][i]
					itemList += func + ";"
					groupList += subGroup + ";"
				EndIf
			EndIf
		EndFor
		
		//Sort the submenu into its groupings
		Wave/T groupWave = StringListToTextWave(groupList,";")
		Wave/T itemWave = StringListToTextWave(itemList,";")
		SortColumns keyWaves={groupWave},sortWaves={itemWave,groupWave}
		
		itemList = TextWaveToStringList(itemWave,";")
		groupList = TextWaveToStringList(groupWave,";")
		
		String groupedItemList = "" //will hold all the final submenu item list
		String accumulateGroup = "" //will hold all subgroup items and alpha sort them before adding to groupitemlist
		String lastGroup = StringFromList(0,groupList,";") //start with the first item in the list
		Variable singleGroup = 1
		
		For(i=0;i<ItemsInList(itemList,";");i+=1)
			String currentGroup = StringFromList(i,groupList,";")
			If(cmpstr(lastGroup,currentGroup))
				accumulateGroup = SortList(accumulateGroup,";",16)
				groupedItemList += accumulateGroup + "-;" //insert break in the submenu list
				accumulateGroup = StringFromList(i,itemList,";") + ";"
				singleGroup = 0
				
				If(i == ItemsInList(itemList,";") - 1)
					//last item
					accumulateGroup = SortList(accumulateGroup,";",16)
					groupedItemList += accumulateGroup
				EndIf
				
			Else
				accumulateGroup += StringFromList(i,itemList,";") + ";"
				
				If(i == ItemsInList(itemList,";") - 1)
					//last item
					accumulateGroup = SortList(accumulateGroup,";",16)
					groupedItemList += accumulateGroup
				EndIf
			EndIf
			
			lastGroup = currentGroup
		EndFor
		
		If(singleGroup)
			accumulateGroup = SortList(accumulateGroup,";",16)
			groupedItemList = accumulateGroup
		EndIf
		
//		itemList = SortList(itemList,";",16)
		return groupedItemList
	Else

		//Find the functions that are not assigned to any submenu
		For(i=0;i<DimSize(param,1);i+=1)
			assignment = param[row][i]
			
			If(!strlen(assignment))
				If(titleRow < 0) //no title in param file
					func = GetDimLabel(param,1,i)
					itemList += func + ";"
				Else
					func = param[titleRow][i]
					itemList += func + ";"
				EndIf
			EndIf
		EndFor
		
		itemList = SortList(itemList,";",16)
		return itemList
	EndIf
End



Menu "DSGroupListMenu",contextualMenu,dynamic
	GetDSMenuItems() 
End

Function/S GetDSMenuItems()
	DFREF NPD = $DSF
	Wave/T DSGroupListWave = NPD:DSGroupListWave
	
	If(!WaveExists(DSGroupListWave))
		return ""
	EndIf
	
	String menuItems = TextWaveToStringList(DSGroupListWave,";")
	menuItems = RemoveListItem(0,menuItems,";")
	return menuItems
End

//Creates the main GUI
Function LoadNeuroPlus()
	
	//Full screen panel
	DoWindow NTP
	If(V_flag)
		//If the panel is open, kill it and reload the packages
		KillWindow/Z NTP
	EndIf
	
	//Make the data package
	CreatePackageFolders()
	CreatePackageWaves()
	
	//Data folder references
	DFREF NPC = $CW
	DFREF NPD = $DSF
	
	//Current data folder tracker
	SVAR cdf = NPC:cdf
	
	//Screen information
	String screenInfo = StringByKey("NSCREENS",IgorInfo(0),":",";")
	
	String whichScreen = "2"
	
	If(str2num(screenInfo) > 1)
		String screen2 = StringByKey("SCREEN" + whichScreen,IgorInfo(0),":",";")
		screen2 = screen2[strsearch(screen2,"RECT=",0) + 5,strlen(screen2)]
	EndIf
		
	String info = StringByKey("SCREEN1",IgorInfo(0),":",";")
	info = info[strsearch(info,"RECT=",0) + 5,strlen(info)]
	
	Variable xRange1 = abs(str2num(StringFromList(0,info,",")) - str2num(StringFromList(2,info,",")))
	
	If(str2num(screenInfo) > 1)
		Variable xRange2 = abs(str2num(StringFromList(0,screen2,",")) - str2num(StringFromList(2,screen2,",")))
	Else
		xRange2 = xRange1
	EndIf
		
	If(xRange1 > xRange2)
		info = screen2
		Variable xRange = xRange2
	Else
		xRange = xRange1
	EndIf
	
	String leftPoint = StringFromList(0,info,",")
	
	If(str2num(leftPoint) < 0)
		info = ReplaceListItem(0,info,",","0")
		info = ReplaceListItem(2,info,",",num2str(abs(str2num(leftPoint))))
	EndIf
	
	Variable yRange =  abs(str2num(StringFromList(1,info,",")) - str2num(StringFromList(3,info,",")))

	String osType = IgorInfo(2)
	
	strswitch(osType)
		case "Macintosh":
			yRange -= 50 //for mac machines
			break
		case "Windows":
			yRange -= 230 //for windows machines
			break
	endswitch
	
	info =  ReplaceListItem(3,info,",",num2str(yRange))
	
	xRange = floor(yRange * 1.7)
	info =  ReplaceListItem(2,info,",",num2str(xRange))
	
	//Make the full screen panel
	Variable/G NPC:screenLeft,NPC:screenRight,NPC:screenTop,NPC:screenBottom
	NVAR screenLeft = NPC:screenLeft
	NVAR screenRight = NPC:screenRight
	NVAR screenTop = NPC:screenTop
	NVAR screenBottom = NPC:screenBottom

	Variable left,right,top,bottom
	left = 0;top = 0;right = str2num(StringFromList(2,info,","));bottom = str2num(StringFromList(3,info,","))
	
	String text = ProcedureText("",30,"NeuroToolsPlus_Loader")
	NewPanel/N=NTP/W=(left,top,right,bottom)/K=1 as "NeuroTools+ v" + NTP#Version()
	
	screenLeft = left;screenRight=right;screenTop=top;screenBottom=bottom
	
	//Sizing variables for control elements
	Variable navPanelWidth = floor((screenRight - screenLeft) / 3) //480
	
	Variable/G NPC:dataPanelWidth
	NVAR dataPanelWidth = NPC:dataPanelWidth
	dataPanelWidth = floor((screenRight - screenLeft) / 3) //480
	
	Variable/G NPC:funcPanelWidth
	NVAR funcPanelWidth = NPC:funcPanelWidth
	funcPanelWidth = right - (navPanelWidth + dataPanelWidth + 10)
	
	//WAVE MATCH LIST BOXES
	Variable boxTop = 170
	Variable folderBoxTop = 55
	Variable boxHeight = (bottom - boxTop) - 305
	Variable folderBoxHeight = (bottom - folderBoxTop) - 305
	Variable displayTop = folderBoxTop + folderBoxHeight + 20
	
	//Guide definitions for the GUI
	DefineGuide/W=NTP navPanel_R = {FL,navPanelWidth}
	DefineGuide/W=NTP dataPanel_L = {navPanel_R,5}
	DefineGuide/W=NTP funcPanel_L = {dataPanel_L,dataPanelWidth + 5}
	
	//Left side panel for navigator
	NewPanel/HOST=NTP/FG=(FL,FT,navPanel_R,FB)/N=Nav
	ModifyPanel/W=NTP#Nav,fixedSize=1,frameStyle=0
	GroupBox navPanel win=NTP#Nav,align=0,pos={2,5},size={navPanelWidth-2,bottom-300}
	
	//Left side panel for viewer
	Variable viewerControlLeft = navPanelWidth-50
	GroupBox viewerPanel win=NTP#Nav,align=0,pos={2,bottom-290},size={navPanelWidth-2,280}
	Display/HOST=NTP#Nav/W=(10,displayTop,viewerControlLeft,bottom-20)/N=Viewer
	
	//Viewer control buttons
	Button autoscale win=NTP#Nav,pos={viewerControlLeft + 3,displayTop + 10},size={40,20},title="A",fsize=12,font=$LIGHT,proc=NTPButtonProc
	Button horizSpread win=NTP#Nav,pos={viewerControlLeft + 3,displayTop + 40},size={40,20},title="←H→",fsize=12,font=$LIGHT,proc=NTPButtonProc
	Button vertSpread win=NTP#Nav,pos={viewerControlLeft + 3,displayTop + 70},size={40,20},title="↑V↓",fsize=12,font=$LIGHT,proc=NTPButtonProc
	Button displayViewerContents win=NTP#Nav,pos={viewerControlLeft + 3,displayTop + 100},size={40,20},title="◻︎",fsize=24,font=$LIGHT,proc=NTPButtonProc
	
	String colorButtonTitle = "\\K(65535,0,52428)/\\K(1,16019,65535)/\\K(0,60535,60535)\\K(1,52428,52428)/\\K(52428,52425,1)/"
	Button colorTraces win=NTP#Nav,pos={viewerControlLeft + 3,displayTop + 130},size={40,20},title=colorButtonTitle,fsize=18,font=$REG,fstyle=1,proc=NTPButtonProc
	Button addThreshold win=NTP#Nav,pos={viewerControlLeft + 3,displayTop + 160},size={40,20},title="—",fsize=24,font=$LIGHT,proc=NTPButtonProc
	Button addRange win=NTP#Nav,pos={viewerControlLeft + 3,displayTop + 190},size={40,20},title="|↔|",fsize=14,font=$LIGHT,proc=NTPButtonProc
	Button clearViewer win=NTP#Nav,pos={viewerControlLeft + 3,displayTop + 220},size={40,20},title="C",fsize=12,font=$LIGHT,proc=NTPButtonProc
	
	//Data Set Definition panel
	NewPanel/HOST=NTP/FG=(dataPanel_L,FT,funcPanel_L,FB)/N=Data
	ModifyPanel/W=NTP#Data,fixedSize=1,frameStyle=0
	GroupBox dataPanel win=NTP#Data,align=0,pos={0,5},size={dataPanelWidth,bottom-300}
	GroupBox dataSetPanel win=NTP#Data,align=0,pos={0,bottom-290},size={dataPanelWidth,280}
	
	
	//Right side panel
	NewPanel/HOST=NTP/FG=(funcPanel_L,FT,FR,FB)/N=Func
	ModifyPanel/W=NTP#Func,fixedSize=1,frameStyle=0
	GroupBox funcPanel win=NTP#Func,align=0,pos={0,5},size={funcPanelWidth - 5,bottom - 300}
	
	//Find position of previously built panels
	ControlInfo/W=NTP#Data dataSetPanel
	Variable topPos = V_top
	Variable height = V_height
	
	//Groupbox for holding the data set and function notebook
	GroupBox DSNotesBox win=NTP#Func,pos={0,topPos},size={funcPanelWidth - 5,height},disable=0
	
	//Data set notebook
	NewNotebook/HOST=NTP#Func/W=(5,bottom-260,funcPanelWidth-10,bottom - 10)/N=DSNotebook/F=1/ENCG=1/OPTS=3
	Notebook NTP#Func#DSNotebook frameStyle=0,frameInset=0,backRGB=(59000,59000,59000,0),fSize=12,fStyle=0,font="Helvetica Light"
	
	//Doesn't draw the active subwindow frame
	SetWindow NTP,activeChildFrame=0
	
	//Data Browser emulation
	
	//Text labels for the list boxes
	SetDrawEnv/W=NTP#Nav gstart,gname=navLabels
	SetDrawEnv/W=NTP#Nav xcoord= abs,ycoord= abs, fsize=16, textxjust= 1,textyjust= 1,fname=$LIGHT
	DrawText/W=NTP#Nav navPanelWidth/4,20,"FOLDERS"
	SetDrawEnv/W=NTP#Nav xcoord= abs,ycoord= abs, fsize=16, textxjust= 1,textyjust= 1,fname=$LIGHT
	DrawText/W=NTP#Nav 350,20,"WAVES"
	SetDrawEnv/W=NTP#Nav gstop
	
	//Wave Matching Controls
	Variable waveMatchPosition = 40
	Variable fontSize = 10
	
	//NAVIGATOR LIST BOXES
	SetVariable cdfDisplay win=NTP#Nav,size={navPanelWidth - 20,20},pos={10,35},font=$REG,fsize=11,fstyle=1,noedit=1,frame=0,title=" ",value=root:Packages:NeuroToolsPlus:ControlWaves:cdf
	
	Wave/T FolderLB_ListWave = NPC:FolderLB_ListWave
	Wave FolderLB_SelWave = NPC:FolderLB_SelWave
	ListBox folderListBox win=NTP#Nav,size={navPanelWidth/2 - 20,folderBoxHeight},widths={300},pos={10,folderBoxTop},mode=9,fsize=11,frame=0,font=$REG,listWave=FolderLB_ListWave,selWave=FolderLB_SelWave,disable=0,proc=NTPListBoxProc
	
	Wave/T WavesLB_ListWave = NPC:WavesLB_ListWave
	Wave WavesLB_SelWave = NPC:WavesLB_SelWave
	ListBox waveListBox win=NTP#Nav,size={navPanelWidth/2 - 20,folderBoxHeight},widths={300},pos={navPanelWidth/2 + 5,folderBoxTop},mode=9,fsize=11,frame=0,font=$REG,listWave=WavesLB_ListWave,selWave=WavesLB_SelWave,disable=0,proc=NTPListBoxProc
	
	
	//Back Button
	Button Back win=NTP#Nav,size={30,20},pos={10,10},font=$REG,fsize=9,title="Back",proc=NTPButtonProc,disable=0
	
	//Navigation List Boxes
	//Set up and fill the list box waves
	SetDataFolder root:
	cdf = "root:"
	updateFolders()
	updateFolderWaves()
	
	fontSize = 12
	
	SetVariable waveMatch win=NTP#Data,font=$LIGHT,pos={30,waveMatchPosition},focusRing=0,size={180,20},bodyWidth = 160, fsize=fontSize,title="Match",value=_STR:"*",help={"Matches waves in the selected folder.\rLogical 'OR' can be used via '||'"},disable=0,proc=ntSetVarProc
	SetVariable waveNotMatch win=NTP#Data,font=$LIGHT,pos={30,waveMatchPosition + 20},focusRing=0,size={180,20},bodyWidth = 160,fsize=fontSize,title="Not",value=_STR:"",help={"Excludes matched waves in the selected folder.\rLogical 'OR' can be used via '||'"},disable=0,proc=ntSetVarProc
	String helpNote = "Target subfolder for wave matching.\r Useful if matching in multiple parent folders that each have a common subfolder structure\r"
	helpNote += "Supports folder matching, and can use '||' as a logical OR to match multiple subfolder searches"
	SetVariable relativeFolderMatch win=NTP#Data,font=$LIGHT,pos={30,waveMatchPosition + 40},size={180,20},bodyWidth = 160,focusRing=0,fsize=fontSize,title=":Folder",value=_STR:"",help={helpNote},disable=0,proc=ntSetVarProc
	
	//List box selection and table waves
	Wave MatchLB_SelWave = NPC:MatchLB_SelWave //match list box
	Wave/T MatchLB_ListWave = NPC:MatchLB_ListWave //match list box
	Wave/T MatchLB_ListWave_BASE = NPC:MatchLB_ListWave_BASE //BASE wave match list without any groupings or filters
	Wave DataSetLB_SelWave = NPD:DataSetLB_SelWave //data set waves list box
	Wave/T DataSetLB_ListWave = NPD:DataSetLB_ListWave //data set waves list box
	Wave DSNamesLB_SelWave = NPD:DSNamesLB_SelWave //data set names list box
	Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave //data set names list box
	Wave FolderLB_SelWave = NPC:FolderLB_SelWave //folder list box
	Wave/T FolderLB_ListWave = NPC:FolderLB_ListWave //folder list box
	Wave WavesLB_SelWave = NPC:WavesLB_SelWave //waves list box
	Wave/T WavesLB_ListWave = NPC:WavesLB_ListWave //waves list box
	
	
	ListBox MatchListBox win=NTP#Data,pos={10,boxTop},size={dataPanelWidth/2 - 20,boxHeight},widths={300},mode=9,frame=0,fsize=11,font=$REG,listWave=MatchLB_ListWave,selWave=MatchLB_SelWave,disable=0,proc=ntListBoxProc
	
	//List box that holds data set wave lists
	ListBox DataSetWavesListBox win=NTP#Data,pos={5 + dataPanelWidth/2,boxTop},size={dataPanelWidth/2 - 20,boxHeight},widths={300},fsize=11,font=$REG,mode=9,frame=0,listWave=DataSetLB_ListWave,selWave=DataSetLB_SelWave,disable=0,proc=ntListBoxProc
	
	//List box to hold names of data sets 
	ListBox DataSetNamesListBox win=NTP#Data,mode=2,pos={470 + 10,boxTop},size={125,boxHeight},fsize=11,font=$REG,widths={300},frame=0,listWave=DSNamesLB_ListWave,selWave=DSNamesLB_SelWave,disable=3,proc=ntListBoxProc
	
	SetDrawEnv/W=NTP#Data gstart,gname=dataSetLabels
	SetDrawEnv/W=NTP#Data xcoord= abs,ycoord= abs, fsize=16, textxjust= 1,textyjust= 1,fname=$LIGHT,fstyle=0
	DrawText/W=NTP#Data dataPanelWidth/2,20,"DATA SET BUILDER"
	SetDrawEnv/W=NTP#Data xcoord= abs,ycoord= abs, fsize=14, textxjust= 1,textyjust= 1,fname=$LIGHT,fstyle=0
	DrawText/W=NTP#Data 115,boxTop - 25,"MATCHED WAVES"
	SetDrawEnv/W=NTP#Data xcoord= abs,ycoord= abs, fsize=14, textxjust= 1,textyjust= 1,fname=$LIGHT,fstyle=0
	DrawText/W=NTP#Data 355,boxTop - 25,"DATA SET WAVES"
//	SetDrawEnv/W=NTP#Data xcoord= abs,ycoord= abs, fsize=14, textxjust= 1,textyjust= 1,fname=$LIGHT
//	DrawText/W=NTP#Data 540,135,"DATA SETS"
	SetDrawEnv/W=NTP#Data gstop
	
	//Display number of wave sets and waves
//	SetVariable waveMatchNumWS win=NTP#Data,noedit=1,frame=0,fstyle=1,fsize=11,font=$LIGHT,pos={10,boxTop},size={225,boxHeight},title=" ",value=root:Packages:NeuroToolsPlus:ControlWaves:numWaveSets_WM
	
	//Filters
	ControlInfo/W=NTP#Data MatchListBox
	
	Variable filterLeft = 50
	SetVariable prefixGroup win=NTP#Data,pos={filterLeft,boxTop - 65},size={40,20},focusRing=0,title="Filters",font=$LIGHT,bodywidth=40,disable=0,fsize=fontSize,value=_STR:"",help={"Filter the wave list by the 1st underscore position"},proc=ntSetVarProc
	filterLeft += 45
	SetVariable groupGroup win=NTP#Data,pos={filterLeft,boxTop - 65},size={55,20},focusRing=0,title=" __",disable=0,font=$LIGHT,fsize=fontSize,value=_STR:"",help={"Filter the wave list by the 2nd underscore position"},proc=ntSetVarProc
	filterLeft += 60
	SetVariable seriesGroup win=NTP#Data,pos={filterLeft,boxTop - 65},size={55,20},focusRing=0,title=" __",disable=0,font=$LIGHT,fsize=fontSize,value=_STR:"",help={"Filter the wave list by the 3rd underscore position"},proc=ntSetVarProc
	filterLeft += 60
	SetVariable sweepGroup win=NTP#Data,pos={filterLeft,boxTop - 65},size={55,20},focusRing=0,title=" __",disable=0,font=$LIGHT,fsize=fontSize,value=_STR:"",help={"Filter the wave list by the 4th underscore position"},proc=ntSetVarProc
	filterLeft += 60
	SetVariable traceGroup win=NTP#Data,pos={filterLeft,boxTop - 65},size={55,20},focusRing=0,title=" __",disable=0,font=$LIGHT,fsize=fontSize,value=_STR:"",help={"Filter the wave list by the 5th underscore position"},proc=ntSetVarProc
	filterLeft += 60
	SetVariable pos6Group win=NTP#Data,pos={filterLeft,boxTop - 65},size={55,20},focusRing=0,title=" __",disable=0,font=$LIGHT,fsize=fontSize,value=_STR:"",help={"Filter the wave list by the 6th underscore position"},proc=ntSetVarProc
	filterLeft += 60
	SetVariable pos7Group win=NTP#Data,pos={filterLeft,boxTop - 65},size={55,20},focusRing=0,title=" __",disable=0,font=$LIGHT,fsize=fontSize,value=_STR:"",help={"Filter the wave list by the 7th underscore position"},proc=ntSetVarProc
	filterLeft += 60
	ControlInfo/W=NTP#Data waveMatch
	
	Button searchWaves win=NTP#Data,pos={V_left + V_width + 20,V_top},size={60,60},title="FIND\nWAVES",disable=0,font=$LIGHT,fsize=12,proc=NTPButtonProc
	Button clearFilters win=NTP#Data,pos={V_left + V_width + 140,V_top},size={80,20},title="Clear Filters",disable=0,font=$LIGHT,fsize=12,proc=NTPButtonProc
		
	//Wave grouping controls
	helpNote = "Organize the wave list into wave sets by the indicated underscore position.\rUses zero offset; -2 concatenates into a single wave set"
	SetVariable waveGrouping win=NTP#Data,pos={300,80},size={150,20},title="Grouping",disable=0,focusRing=0,font=$LIGHT,fsize=fontSize,value=_STR:"",help={helpNote},proc=ntSetVarProc
	Button waveGroupingHelp win=NTP#Data,pos={452,77},size={20,20},title="?",disable=0,font=$LIGHT,fsize=fontSize,proc=NTPButtonProc
	
	//Data Set controls
	Button DSMenu win=NTP#Data,fsize=fontSize,pos={190,boxTop - 35},size={35,20},fsize=fontSize,font=$LIGHT,title="→DS",proc=NTPButtonProc
	
//	Button DSGroupMenu win=NTP#Data,pos={584,124},size={20,20},fsize=12,fstyle=1,font=$MED,title=U+22EE,proc=NTPButtonProc


	//Function Controls
	SetDrawEnv/W=NTP#Func gstart,gname=functionLabels
	SetDrawEnv/W=NTP#Func xcoord= abs,ycoord= abs, fsize=16, textxjust= 1,textyjust= 1,fname=$LIGHT
	DrawText/W=NTP#Func funcPanelWidth/2,20,"FUNCTIONS"
	SetDrawEnv/W=NTP#Func gstop
	
	SVAR currentFunc = NPC:currentFunc
	SVAR funcList = NPC:funcList
	funcList = GetExternalFunctions()
	
	If(ItemsInList(funcList,";") > 0)
		currentFunc = StringFromList(0,funcList,";")
	Else
		currentFunc = ""
	EndIf
	
	//Ensures correct control displays if measure function is initialized
	If(!cmpstr(currentFunc,"Measure"))
		STRUCT WMPopupAction pa
		pa.eventCode = 2
		pa.ctrlName = "param_1"
		pa.popStr = "Peak"
		pa.popNum = 1
		measureProc(pa)
	EndIf
	
	Button refreshMenu win=NTP#func,pos={10,40},size={20,20},fsize=12,font=$LIGHT,proc=ntButtonProc,disable=0,title="⟳"
	Button functionPopUp win=NTP#Func,pos={35,40},size={185,20},fsize=12,font=$LIGHT,proc=ntButtonProc,title="\\JL▼   " + currentFunc,disable=0
	Button gotoFunc win=NTP#Func,pos={230,40},size={50,20},font=$LIGHT,title="GoTo",disable=0,proc=ntButtonProc
	Button funcNotes win=NTP#Func,pos={285,40},size={20,20},font=$LIGHT,title="?",disable=0,proc=ntButtonProc
	Button runFunc win=NTP#Func,pos={330,40},size={60,20},font=$LIGHT,title="RUN",disable=0,proc=ntButtonProc
	Button hideNTP win=NTP#Func,pos={funcPanelWidth - 48,7},size={40,20},title="Hide",disable=0,proc=ntButtonProc
	
//	SetVariable dsNameInput win=NTP#Data,pos={345,468},size={90,20},disable=1,focusRing=0,frame=0,value=_STR:"",proc=ntSetVarProc
//	GroupBox dsNameGroupBox win=NTP#Data,pos={340,463},size={100,26},disable=1
	
	//Data Set Editor and Grouping
	SetDrawLayer/W=NTP#Func Overlay
	DrawAction/W=NTP#Func getgroup=dsNotesText,delete
	
		
	//Reset the All group visibility and make sure the data set lists are valid
	CheckBox HideAllGroup win=NTP#Data,value=0
	Wave/T DSGroupListWave =  NPD:DSGroupListWave
	Wave DSGroupSelWave = NPD:DSGroupSelWave
	Wave/T DSGroupContents = NPD:DSGroupContents
	
	Redimension/N=(DimSize(DSGroupContents,1)) DSGroupListWave,DSGroupSelWave
	Variable i
	For(i=0;i<DimSize(DSGroupContents,1);i+=1)
		DSGroupListWave[i] = GetDimLabel(DSGroupContents,1,i)
	EndFor
	
	SetDSGroup(group="All")
	
	Wave/T ds = NPD:DSNamesLB_ListWave
	If(DimSize(ds,0) > 0)
		String dsName = ds[0][0][0]
	Else
		dsName = ""
	EndIf
	
	//Data set navigator
	SetupDSGroupForm(dsName)

	//ScanImage package
//	SI_CreatePackage()
	
	//Initiate the function menu
	SVAR selectedCmd = NPC:selectedCmd
	String func = currentExtFunc()
	String funcTitle = getParam("TITLE",func)
	SwitchExternalFunction(funcTitle)
	selectedCmd = funcTitle
	
		
	//ScanImage Package
//	LoadScanImagePackage()
	
	SetWindow NTP hook(MouseClickHooks) = MouseClickHooks
	
	//Set the listbox focus to wave match
	SVAR listFocus = NPC:listFocus
	listFocus = "DataSet"
	changeFocus("WaveMatch",1)
	
	
	//Check for package manager and update the available packages in the functions menu
	SVAR HideUserPackages =  NPC:HideUserPackages
	If(SVAR_Exists(HideUserPackages))
		UpdatePackages(HideUserPackages,init=1)
	Else
		//If there are no preferences for the current experiment file, let's check for a global package preferences file
		//in the User Procedures folder
		String PackagePreferences = SpecialDirPath("Igor Pro User Files",0,0,0)	
		PackagePreferences += "User Procedures:NeuroTools+:PackagePreferences.txt"
		
		GetFileFolderInfo/Q/Z PackagePreferences
		
		If(V_isFile)
			LoadWave/Q/J/K=2/N=packageList PackagePreferences
			
			Wave/T packageList = :packageList0
			String/G NPC:HideUserPackages
			SVAR HideUserPackages = NPC:HideUserPackages
			HideUserPackages  = ""
			
			DeletePoints/M=0 0,1,packageList //deletes the column label
			
			For(i=0;i<DimSize(packageList,0);i+=1)
				String package = packageList[i]
				
				HideUserPackages += package + ";"
			EndFor
			KillWaves/Z packageList
		EndIf
		
		
		DoWindow/F PackageManager
		If(V_flag)
			ManagePackages()
		EndIf
		
		UpdatePackages(HideUserPackages)
	EndIf
	
	
End

Function CreatePackageFolders()
	CreateFolder("root:Packages:NeuroToolsPlus:ControlWaves")
	CreateFolder("root:Packages:NeuroToolsPlus:DataSets")
	
End

Function CreatePackageWaves()
	DFREF NPC = $CW
	DFREF NPD = $DSF
	
	//Create variable checking if NeuroTools is loaded or not
	Variable/G NPC:isLoaded
	NVAR isLoaded = NPC:isLoaded
	isLoaded = 1
	
	Make/O/T/N=1 NPC:FolderLB_ListWave
	
	Make/O/N=1 NPC:FolderLB_SelWave
	
	Make/O/T/N=1 NPC:WavesLB_ListWave
	
	Make/O/N=1 NPC:WavesLB_SelWave
	
	//List box selection and table waves
	Make/O/N=0 NPC:MatchLB_SelWave //match list box
	Make/O/T/N=0 NPC:MatchLB_ListWave //match list box
	Make/O/T/N=0 NPC:MatchLB_ListWave_BASE //BASE wave match list without any groupings or filters
	Make/O/N=0 NPD:DataSetLB_SelWave //data set waves list box
	Make/O/T/N=0 NPD:DataSetLB_ListWave //data set waves list box
	
	//Don't overwrite existing data sets
	Wave/T/Z DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
	If(!WaveExists(DSNamesLB_ListWave))
		Make/O/T/N=0 NPD:DSNamesLB_ListWave //data set names list box
		Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
	EndIf
	
	Wave/T/Z DSNamesLB_SelWave = NPD:DSNamesLB_SelWave
	If(!WaveExists(DSNamesLB_SelWave))
		Make/O/N=(DimSize(DSNamesLB_ListWave,0)) NPD:DSNamesLB_SelWave //data set names list box
		Wave/T DSNamesLB_SelWave = NPD:DSNamesLB_SelWave
	EndIf
	
	Make/O/N=0 NPC:FolderLB_SelWave //folder list box
	Make/O/T/N=0 NPC:FolderLB_ListWave //folder list box
	Make/O/N=0 NPC:WavesLB_SelWave //waves list box
	Make/O/T/N=0 NPC:WavesLB_ListWave //waves list box
	
	Variable/G NPD:dataTableIndex
	
	//Viewer controls
	Variable/G NPC:areHorizSeparated
	NVAR areHorizSeparated = NPC:areHorizSeparated
	areHorizSeparated = 0
	
	Variable/G NPC:areVertSeparated
	NVAR areVertSeparated = NPC:areVertSeparated
	areVertSeparated = 0
	
	Variable/G NPC:areColored
	NVAR areColored = NPC:areColored
	areColored = 0
	
	Variable/G NPC:threshold
	NVAR threshold = NPC:threshold
	threshold = 0
	
	Variable/G NPC:moveThreshold
	NVAR moveThreshold = NPC:moveThreshold
	moveThreshold = 0
	
	Variable/G NPC:activeThreshold
	NVAR activeThreshold = NPC:activeThreshold
	activeThreshold = 0

	Variable/G NPC:activeRange
	NVAR activeRange = NPC:activeRange
	activeRange = 0
	
	Variable/G NPC:moveRangeLeft
	NVAR moveRangeLeft = NPC:moveRangeLeft
	moveRangeLeft = 0
	
	Variable/G NPC:moveRangeRight
	NVAR moveRangeRight = NPC:moveRangeRight
	moveRangeRight = 0
	
	Variable/G NPC:rangeRight
	NVAR rangeRight = NPC:rangeRight
	rangeRight = 0
	
	Variable/G NPC:rangeLeft
	NVAR rangeLeft = NPC:rangeLeft
	rangeLeft = 0
	
	//Data Set Groups
	//Don't overwrite existing data set groups
	Wave/T DSGroupListWave = NPD:DSGroupListWave
	If(!WaveExists(DSGroupListWave))
		Make/O/T/N=1 NPD:DSGroupListWave/Wave=DSGroupListWave
		DSGroupListWave[0] = "All" //Base data group that always exists
	EndIf
	
	Make/O/N=(DimSize(DSGroupListWave,0)) NPD:DSGroupSelWave/Wave=DSGroupSelWave
	DSGroupSelWave = 0
	
	//Don't overwrite existing data set groups
	Wave/T DSGroupContents = NPD:DSGroupContents
	If(!WaveExists(DSGroupContents))
		Make/O/T/N=(0,1) NPD:DSGroupContents/Wave=DSGroupContents //3d contents wave
		SetDimLabel 1,0,All,DSGroupContents //Base data group that always exists
	EndIf
	
	Make/O/T/N=0 NPD:DSGroupContentsListWave //1d wave of selected group contents
	Make/O/N=0 NPD:DSGroupContentsSelWave/Wave=DSGroupContentsSelWave
	DSGroupContentsSelWave = 0
	
	//Functions

	If(!WaveExists(NPC:ExtFunc_Parameters))
		Make/T/O/N=(7,1) NPC:ExtFunc_Parameters
	EndIf
	
	Wave/T ExtFunc_Parameters = NPC:ExtFunc_Parameters
	Wave/T param = GetExternalFunctionData(ExtFunc_Parameters)
//	
	Make/WAVE/O/N=0 NPC:extFuncWaveRefs
	Variable/G NPC:numExtParams
	String/G  NPC:extParamTypes
	String/G NPC:extParamNames
	String/G NPC:ctrlList_extFunc
	String/G NPD:DSNameList
	String/G NPC:selectedCmd
	
	//Variables
	Variable/G NPD:DataSetEditorOpen
	NVAR DataSetEditorOpen = NPD:DataSetEditorOpen
	DataSetEditorOpen = 0
	
	Variable/G NPD:EditingNotes
	NVAR EditingNotes = NPD:EditingNotes
	EditingNotes = 0
	
	Variable/G NTSI:isInverted
	NVAR isInverted = NTSI:isInverted
	isInverted = 0
	
	//Strings
	String/G NPC:cdf
	String/G NPC:listFocus
	String/G NPC:waveMatchStr
	String/G NPC:waveNotMatchStr
	String/G NPC:relFolderStr
	String/G NPC:prefixGroupingStr
	String/G NPC:groupGroupingStr
	String/G NPC:seriesGroupingStr
	String/G NPC:sweepGroupingStr
	String/G NPC:traceGroupingStr
	String/G NPC:pos6GroupingStr
	String/G NPC:pos7GroupingStr
	String/G NPC:waveGroupingStr
	String/G NPC:filterSettings
	
	String/G NPD:DSNames
	String/G NPD:DSWaveNameList
	String/G NPD:DSWaveNameFullPathList
	String/G NPC:matchWaveNameList
	String/G NPC:matchFullPathList
	
	String/G NPC:folderSelection
	Variable/G NPC:numWaveSets_WM
	NVAR numWaveSets_WM = NPC:numWaveSets_WM
	numWaveSets_WM = 0
	
	String/G NPC:funcList
	String/G NPC:currentFunc
	
	String/G NPC:notificationEntry
	
	//Save this for possible reloads
	String/G NPC:UserPackages
	SVAR UserPackages =  NPC:UserPackages
	UserPackages = ""
	
	//ScanImage package strings
	String/G NPC:loadedPackages
	
	//Loading ephys wave
	String/G NPC:wsFilePath
	String/G NPC:wsFileName
	
	//stimulus data
	Make/O/T/N=(0,2) NPC:wsStimulusDataListWave

	//renaming data sets/groups
	String/G NPD:newName
	SVAR newName = NPD:newName
	newName = ""
End

//Loads the ScanImage Imaging Package for access to specialized Calcium imaging functions 
//that work with scanimage bigtiff files
Function LoadScanImagePackage()
	DFREF NPC = $CW
	SVAR loadedPackages = NPC:loadedPackages
	If(!stringmatch(loadedPackages,"*ScanImage*"))
	
		//LOAD - supports Vidrio's ScanImage software
		loadedPackages += "ScanImage;"
		
		//Load procedures
		Execute/P/Q/Z "INSERTINCLUDE \"NTP_ScanImage_Package\""
		Execute/P/Q/Z "INSERTINCLUDE \"NTP_ScanImageTiffReader\""
		Execute/P/Q/Z "COMPILEPROCEDURES "
	
		//Load the controls, etc.
		//Executes command string to avoid compilation prior to loading the package.
		Execute/Q/P "SI_CreatePackage()"
	Else
		//UNLOAD
		loadedPackages = RemoveFromList("ScanImage;",loadedPackages,";")
		
		//Kill the Image Browser
		KillWindow/Z SI
		
		//Remove procedures
		Execute/P/Q/Z "DELETEINCLUDE \"NTP_ScanImage_Package\""
		Execute/P/Q/Z "DELETEINCLUDE \"NTP_ScanImageTiffReader\""
		Execute/P/Q/Z "COMPILEPROCEDURES "
			
		//return to a main menu function
		SVAR selectedCmd = NPC:selectedCmd
//		switchCommandMenu("Measure")
		SwitchControls("Measure",selectedCmd)
//		switchHelpMessage("Measure")
	EndIf
	
	//Rebuild all the menus
	BuildMenu "All"
	
End

//Creates a new data folder along the specified location
//Creates the entire path if need be
Function/DF CreateFolder(path)
	String path
	 
	If(!strlen(path))
		return $""
	EndIf
	
	Variable i,numel = ItemsInList(path,":")
	For(i=1;i<numel;i+=1)
		String folder = ParseFilePath(1,path,":",0,i)
		
		If(!DataFolderExists(folder))
			folder = RemoveEnding(folder,":")
			NewDataFolder $folder
		EndIf
	EndFor
	
	//last element
	If(!DataFolderExists(path))
		path = RemoveEnding(path,":")
		NewDataFolder $path
	EndIf
	
	DFREF dfr = $path
	
	return dfr
End

//Uses the selection from the Grouping menu to append the appropriate flag to the grouping SetVariable box
Function appendGroupSelection(selection)
	String selection
	String output = ""
	
	ControlInfo/W=NTP waveGrouping
	strswitch(selection)
		case "Concatenate":
			output = "/WG=-2"
			break
		case "Folder":
			output = "/F="
			break
		case "Position":
			output = "/WG="
			break
		case "Block":
			output = "/B="
			break
		case "Stride":
			output = "/S="
			break
		case "Wave Set Number":
			output = "/WSN="
			break
		case "Wave Set Index":
			output = "/WSI="
			break
	endswitch
	
	SetVariable waveGrouping win=NT,value=_STR:S_Value + output,activate
	
End

//Gets the subfolders that reside in the current data folder
Function/WAVE updateFolders([folderPath])
	//if folderPath is provided, the folder list within folderPath is provided instead of the cdf
	String folderPath
	
	DFREF NPC = $CW
	
	//Selection and List Waves for the list box
	Wave/T FolderLB_ListWave = NPC:FolderLB_ListWave
	Wave/T FolderLB_SelWave = NPC:FolderLB_SelWave
		
	SVAR cdf = NPC:cdf
	
	//Indexes waves in current data folder, applies match string
	cdf = GetDataFolder(1) //this is saved in case custom folder path is used
	
	If(!ParamIsDefault(folderPath))
		SetDataFolder $folderPath
	EndIf

	//Gets the list of folders within the current data folder
	String folderList = ReplaceString(";",StringFromList(1,DataFolderDir(1),":"),"")
	folderList = TrimString(folderList)

	//Ensures dimensions are equal between list and selection waves for the listbox
	Redimension/N=(ItemsInList(folderList,",")) FolderLB_ListWave,FolderLB_SelWave
	
	//Fills out folder table for the list box
	Variable i
	For(i=0;i<ItemsInList(folderList,",");i+=1)
		FolderLB_ListWave[i] = StringFromList(i,folderList,",")
	EndFor
	SetDataFolder $cdf
	
	Sort/A FolderLB_ListWave,FolderLB_ListWave //alphanumeric sort
	return FolderLB_ListWave
End

//Gets the waves that reside in the current data folder
Function/WAVE updateFolderWaves([depth])
	Variable depth //folder depth
	DFREF NPC = $CW

	//Selection and List waves
	Wave/T WavesLB_ListWave = NPC:WavesLB_ListWave
	Wave WavesLB_SelWave = NPC:WavesLB_SelWave
	
	SVAR cdf = NPC:cdf
	
	String itemList
	Variable i
	
	//Match list
	itemList = ReplaceString(";",StringFromList(1,DataFolderDir(2),":"),"")
	itemList = TrimString(itemList)
	
	//Alphanumeric Sort
	itemList = SortList(itemList,",",16)
	
	Redimension/N=(ItemsInList(itemList,",")) WavesLB_ListWave,WavesLB_SelWave
	
	For(i=0;i<ItemsInList(itemList,",");i+=1)
		WavesLB_ListWave[i] = StringFromList(i,itemList,",")
	EndFor
	return WavesLB_ListWave
End

//Switches the current data folder to the selection
//Refreshes the folder and wave list box contents
Function switchFolderContents(selection)
	String selection
	DFREF NPC = $CW
	
	//Change the current data folder
	SVAR cdf = NPC:cdf
	
	If(stringmatch(selection,"* *"))
		selection = "'" + selection + "'"
	EndIf
	
	SetDataFolder cdf + selection
	
	//Refresh the folder and waves list boxes
	updateFolders()
	updateFolderWaves()
End


//Fill the filter structure with string variables
Function SetFilterStructure(filters,selection)
	STRUCT filters &filters
	String selection
	Variable DataSet
	
	DFREF NPC = $CW
	SVAR filters.match = NPC:waveMatchStr
	SVAR filters.notMatch = NPC:waveNotMatchStr
	SVAR filters.relFolder = NPC:relFolderStr
	
	SVAR filters.prefix = NPC:prefixGroupingStr
	SVAR filters.group = NPC:groupGroupingStr
	SVAR filters.series = NPC:seriesGroupingStr
	SVAR filters.sweep = NPC:sweepGroupingStr
	SVAR filters.trace = NPC:traceGroupingStr
	SVAR filters.pos6 = NPC:pos6GroupingStr
	SVAR filters.pos7 = NPC:pos7GroupingStr
	
	SVAR filters.wg = NPC:waveGroupingStr
	
	If(!cmpstr(selection,"DataSet"))
		SVAR filters.name = NPD:DSWaveNameList
		SVAR filters.path = NPD:DSWaveNameFullPathList
	ElseIf(!cmpstr(selection,"WaveMatch"))
		SVAR filters.name = NPC:matchWaveNameList
		SVAR filters.path = NPC:matchFullPathList
	Else
		SVAR filters.name = NPC:matchWaveNameList
		SVAR filters.path = NPC:matchFullPathList
	EndIf
End

//Handles list box actions
Function NTPListBoxProc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave
	Variable errorCode = 0
	
	DFREF NPC = $CW
	DFREF NPD = $DSF
	
	Variable hookResult = 0
	
	Variable/G NPC:isDoubleClick
	NVAR isDoubleClick = NPC:isDoubleClick
	
		
	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			//set a potential drag variable
			break
		case 2: // mouse up
			strswitch(lba.ctrlName)
				case "waveListBox":
					AppendToViewer(listWave,selWave)
					break
				
			endswitch
			break
		case 3: // double click
			strswitch(lba.ctrlName)
				case "DSGroupContents": //data set names
					//select all
					isDoubleClick = 1
					
					break
				case "folderListBox":  //folder navigation
					Wave/T FolderLB_ListWave = NPC:FolderLB_ListWave
					If(lba.row < DimSize(FolderLB_ListWave,0))
						switchFolderContents(FolderLB_ListWave[lba.row])
					EndIf
					break
				case "waveListBox":	//waves navigation
					break
			endswitch
			
			 break
		case 4: //selection
		case 5: // cell selection plus shift key
			
			///Arrow key selection
			If(lba.eventMod == 0)	
				strswitch(lba.ctrlName)
					case "waveListBox":
					case "DataSetWavesListBox":
						AppendToViewer(listWave,selWave)
						break
				endswitch
				
				return 0
			EndIf
			
			//Change data sets/groups on selection, even for right click
			strswitch(lba.ctrlName)
				case "DSGroups":
					SetDSGroup()
							
					break
				case "DSGroupContents":
					If(row < DimSize(listWave,0))
						changeDataSet(listWave[row])
					EndIf
					
					If(isDoubleClick)
						Wave selWave = NPD:DataSetLB_SelWave
						selWave = 1
						
						Wave/T listWave = NPD:DataSetLB_ListWave
						AppendToViewer(listWave,selWave)
					EndIf
					break
			endswitch
			
			
			//Handle Right clicks
			If(lba.eventMod == 16 || lba.eventMod == 17)
				//If the right click happens on a non-previously selected data set,
				//first loads those data set setttings into the GUI controls
				If(row > DimSize(listWave,0) - 1)	
					break
				EndIf
				
				//Define right click menu items depending on the control
				strswitch(lba.ctrlName)
					case "DSGroupContents":
					
						//Is the selected data set an archive?
						
						If(isArchive(listWave[row]))
							PopUpContextualMenu/C=(lba.mouseLoc.h,lba.mouseLoc.v) "Rename;Duplicate Data Set;Open Archive;"
						Else
							PopUpContextualMenu/C=(lba.mouseLoc.h,lba.mouseLoc.v) "Rename;Duplicate Data Set;Archive Data Set;"
						EndIf
											
						If(V_flag == 0)
							break
						EndIf
						
						break		
						
					case "DSGroups":
						PopUpContextualMenu/C=(lba.mouseLoc.h,lba.mouseLoc.v) "Rename;"
						
						If(V_flag == 0)
							break
						EndIf
						break
					case "waveListBox":
						PopUpContextualMenu/C=(lba.mouseLoc.h,lba.mouseLoc.v) "GoTo;Edit;Delete;Display;"
						break
					case "folderListBox":
						PopUpContextualMenu/C=(lba.mouseLoc.h,lba.mouseLoc.v) "Copy Path;"
				endswitch

				//Handle the user's right click menu selection
				strswitch(S_Selection)
					case "Rename":
						//Prompt for new name
						String newDSName = ""
						String newDGName = ""
						
						Prompt newDSName,"New Data Set Name"
						Prompt newDGName,"New Data Group Name"
						
						//Activate editable cells
						
						strswitch(lba.ctrlName)
							case "DSGroups":
								//Can't rename the 'All' data group
								If(!cmpstr("All",listWave[row]))
									break
								EndIf
								
								DoPrompt "Data Set Editor",newDGName
								If(!V_flag)
									RenameDataGroup(newDGName,listWave[row])
								EndIf
								break
							case "DSGroupContents":
								DoPrompt "Data Set Editor",newDSName
								If(!V_flag)
									RenameDataSet(newDSName,listWave[row])
								EndIf
								break
						endswitch
						break
					case "Archive Data Set":
						DoAlert/T="Archive Data Set" 1,"Are you sure you want to archive the data set?"
						
						If(V_flag == 1)
							DoAlert/T="Archive Data Set" 2,"Can each underscore position be condensed into a list?"
							Variable doCollapse = V_flag
							
							DoAlert/T="Archive Data Set" 2,"Obey Wave Groupings?"
							archiveDataSet(listWave[row],doCollapse,V_flag)
						
						EndIf
						
						break
					case "Duplicate Data Set":
						String dsName
						Prompt dsName,"Data Set Name"
						DoPrompt "Duplicate Data Set",dsName
						
						If(!V_flag)
							DuplicateDataSet(dsName,listWave[row])
						EndIf
						return 0
						break
					case "Open Archive":
						openArchive(listWave[row])
						break
					case "GoTo":
					case "Edit":
					case "Delete":
					case "Display":
						If(V_flag)
							HandleRightClick("waveListBox",V_flag,row=row)
						EndIf
						break
					case "Copy Path":
						If(V_flag)
							Wave/T FolderLB_ListWave = NPC:FolderLB_ListWave
							Wave/T FolderLB_SelWave = NPC:FolderLB_SelWave
							SVAR cdf = NPC:cdf
							
							//Get the first wave in the data folder
							String path = cdf + FolderLB_ListWave[row] + ":"
							PutScrapText path
						EndIf
						break
				endswitch

			EndIf
			
			isDoubleClick = 0
			
			break
		case 12:
			
			break
		case -3:
			//receives keyboard focus
			strswitch(lba.ctrlName)
				case "DSGroups":
				case "DSGroupContents":
					changeFocus("DataSet",1)
					break
			endswitch
			break
	endswitch
	
	return hookResult
End

Function ControlAssignmentButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	DFREF NPC = $CW
	DFREF NPD = $DSF
	SVAR currentFunc = NPC:currentFunc
	
	Variable errorCode = 0
	switch(ba.eventCode)
		case 2: // mouse up
			If(stringmatch(ba.ctrlName,"*assign"))
				String parentCtrl = StringFromList(0,ba.ctrlName,"_")
				ControlInfo/W=NTP#Func $parentCtrl
				String name = S_Title
				
				String whichParam = GetParam2(name,"INDEX",currentFunc)
				String assignment = GetParam2(name,"ASSIGN",currentFunc)
			EndIf
			
			NVAR controlAssignment = $assignment
			
			SetParam("PARAM_" + whichParam + "_VALUE",currentFunc,num2str(controlAssignment))
			SetVariable $parentCtrl win=NTP#Func,value=_NUM:controlAssignment
			break
	endswitch
	return errorCode
End

//Special button proc for external function data set pop up menus, which are buttons w/ contextual menus
Function DataSetButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	DFREF NPC = $CW
	DFREF NPD = $DSF
	
	Variable errorCode = 0
	switch(ba.eventCode)
		case 2: // mouse up
			
			If(stringmatch(ba.ctrlName,"*show"))
				String parentCtrl = StringFromList(0,ba.ctrlName,"_")
				ControlInfo/W=NTP#Func $parentCtrl
				String dataset = removeSpacer(S_Title)
				
				If(stringmatch(dataset,"**Wave Match**") || stringmatch(dataset,"**Navigator**"))
					break
				EndIf
				
				String dsGroup = ""
				Wave/T DSGroupContents = NPD:DSGroupContents
				
				//attempt to find a group that the data set belongs to
				Variable i
				For(i=1;i<DimSize(DSGroupContents,1);i+=1)
					Variable row = tableMatch(dataset,DSGroupContents,whichCol=i)
					
					If(row != -1)
						dsGroup = GetDimLabel(DSGroupContents,1,i)
					EndIf
				EndFor
				
				//no group assignments, so we'll switch to the 'All' group
				If(!strlen(dsGroup))
					dsGroup = "All"
				EndIf
				
				ControlInfo/W=NTP#Data HideAllGroup
				If(V_Value && !cmpstr(dsGroup,"All"))
					Checkbox HideAllGroup win=NTP#Data,value=0 //uncheck the hide 'all' group
					STRUCT WMCheckboxAction cba //rebuild the data group waves accordingly
					cba.checked = 0
					cba.eventCode = 2
					cba.ctrlName = "HideAllGroup"
					NTPCheckProc(cba) //trigger the checkbox code
				EndIf
				
				SetDSGroup(group=dsGroup,dataset=dataset)
				break
			ElseIf(stringmatch(ba.ctrlName,"*goto"))
				parentCtrl = StringFromList(0,ba.ctrlName,"_")
				ControlInfo/W=NTP#Func $parentCtrl
				String func = "NT_" + S_Value
				DisplayProcedure/W=NTP_ExternalFunctions func
				break
			ElseIf(stringmatch(ba.ctrlName,"*Nav"))
				parentCtrl = StringFromList(0,ba.ctrlName,"_")
//				String selection = GetBrowserSelection(0)
				Wave/T NavListWave = NPC:WavesLB_ListWave
				Wave NavSelWave = NPC:WavesLB_SelWave
				
				String selection = ""
				
				//Get the first selection item in the list
				SVAR cdf = NPC:cdf
				For(i=0;i<DimSIze(NavListWave,0);i+=1)
					If(NavSelWave[i] > 0)
						selection = cdf + NavListWave[i]
						break
					EndIf
				EndFor
				
				SetVariable $parentCtrl win=NTP#Func,value=_STR:selection
				
				validWaveText("",0,deleteText=1,parentCtrl=parentCtrl)
				ControlInfo/W=NTP#Func $parentCtrl
				validWaveText(selection,V_top+13,parentCtrl=parentCtrl)
				
				func = CurrentExtFunc()
				Variable index = ExtFuncParamIndex(ba.ctrlName)
				setParam("PARAM_" + num2str(index) + "_VALUE",func,selection)
				
				break
			EndIf
			
			ControlInfo/W=NTP#Func $ba.ctrlName
			Variable left = V_left
			Variable top = V_top + 22
			Variable width = V_width
			PopUpContextualMenu/W=NTP#Func/C=(left,top)/N "DSWavesMenu"
			
			If(V_flag == -1) 
				return 0
			EndIf
				
			
			//Set the value of the external function parameter
			DFREF NPC = $CW
			Wave/T param = NPC:ExtFunc_Parameters
			
			func = CurrentExtFunc()
			index = ExtFuncParamIndex(ba.ctrlName)
			
			setParam("PARAM_" + num2str(index) + "_VALUE",func,S_Selection)
			
			String spacedStr = getSpacer(S_Selection,18)
			
			Button $ba.ctrlName win=NTP#Func,title = spacedStr
			break
			
	endswitch
	return errorCode
	
End

Function NTPCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			
			DFREF NPD = $DSF
			Wave/T DSGroupListWave =  NPD:DSGroupListWave
			Wave DSGroupSelWave = NPD:DSGroupSelWave
			
			strswitch(cba.ctrlName)
				case "HideAllGroup":
					If(checked)
						//Break if the only group is the 'All' group
						If(DimSize(DSGroupListWave,0) == 1)
							CheckBox HideAllGroup win=NTP#Data,value=0
							break
						EndIf
						DeletePoints/M=0 0,1,DSGroupListWave,DSGroupSelWave
						DSGroupSelWave = 0
						ListBox DSGroups win=NTP#Data,selRow=0
					Else
						InsertPoints/M=0 0,1,DSGroupListWave,DSGroupSelWave
						DSGroupListWave[0] = "All"
						DSGroupSelWave[0] = 0
					EndIf
					break
			endswitch
			
			//Update the data set group display
			SetDSGroup()
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function NTPButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	DFREF NPC = $CW
	DFREF NPD = $DSF
	SVAR listFocus = NPC:listFocus
	SVAR notificationEntry = NPC:notificationEntry
	
	NVAR areHorizSeparated = NPC:areHorizSeparated
	NVAR areVertSeparated = NPC:areVertSeparated
	NVAR areColored = NPC:areColored
	NVAR activeRange = NPC:activeRange
	NVAR activeThreshold = NPC:activeThreshold
	
	Variable errorCode = 0
	switch(ba.eventCode)
		case 2: // mouse up
			strswitch(ba.ctrlName)
				case "Back":
					folderBack()
					break
				case "searchWaves":
					//Save the current filters/grouping settings before changing focus
					If(!cmpstr(listFocus,"DataSet"))
						saveFilterSettings("DataSet")
					EndIf
					
					//Don't recall previous settings, bc we just changed it.
					changeFocus("WaveMatch",1)
					
						//Builds the match list according to all search terms, groupings, and filters
					getWaveMatchList()
					
					//display the full path to the wave in a text box
					drawFullPathText()
					break
				case "DSMenu":
					//Add new data set
					PopUpContextualMenu/W=NTP#Data/C=(190,150) "Add New Data Set;Update Current Data Set"
					If(V_flag == -1)
						return 0
					EndIf
					
					strswitch(S_Selection)
						case "Add New Data Set":
							String dsName = DSMenuFunc(S_Selection)
			
							If(!strlen(dsName))
								return 0
							EndIf
							
							If(addDataSet(dsName))
								print "ADD DATA SET ERROR"
							EndIf
							break
						case "Update Current Data Set":
							dsName = DSMenuFunc(S_Selection)
							If(!strlen(dsName))
								return 0 //this happens if there was no data set selected, and we created a new one instead
							EndIf
							
							If(isArchive(dsName))
								changeDataSet(dsName)
								notificationEntry = "Updated Archive: \f01" + dsName
								sendNotification()
								return 0
							EndIf
							
							updateDataSet(dsName)
							break
					endswitch
					
					
					break
				case "waveGroupingHelp":
				
					DoWindow/H/F 
					
					print "----------------------------------------------------------------------\n"
					String/G NPC:WGHelp/N=WGHelp
					WGHelp = "Syntax for grouping and organizing data sets:\n"
					WGHelp += "----------------------------------------------------\n"
					WGHelp += "Data sets are a collection of waves.\n"
					WGHelp += "Wave sets are subsets of a data set, which are created according to the wave grouping flags described below.\n\n"
					WGHelp += "Numerical entries will split the data set according to the underscore position (#) in the wave name, starting with 0.\n"
					WGHelp += "/WG=#  : same as a numerical entry (/WG=3 will put all waves with the same 3rd underscore position in the same wave set)\n"
					WGHelp += "/WG=-1  : special case. Organizes the data set into waves that are in the same folder.\n"
					WGHelp += "/WG=-2  : special case. Concatenates all waves into the same wave set.\n\n"
					WGHelp += "/B=#  : splits data set in blocks of waves (/B=8 will make multiple wave sets of 8 waves)\n"
					WGHelp += "/S=#  : splits data set according to stride (/S=3 will put every third wave in the same wave set group)\n"
					WGHelp += "/WSI=#  : only includes the #th wave in the data set or wave set (/WSI=3 will include only the third wave in the data set or wave set)\n"
					WGHelp += "/WSN=#  : only includes the #th wave set in the data set.\n"
					WGHelp += "/WSNS=#  : strides organization, but for wave sets. (/WSNS=3 will include every third wave set in the data set)\n"
					WGHelp += "/F=#  : similar to /WG=-1, but organizes by subfolder of the # depth from the data set's parent folder.\n"
					WGHelp += "/L  : creates a new wave set for each line in a data set archive.\n"
					print WGHelp
					
					print "----------------------------------------------------------------------"
					break
//				case "DSGroupMenu":
//					PopUpContextualMenu/C=(200,200)/W=NTP#Data "Delete Data Set"
//					
//					If(V_flag == -1)
//						break
//					EndIf
//					
//					strswitch(S_selection)
//						case "Delete Data Set":
//							Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
//							ControlInfo/W=NTP#Data DataSetNamesListBox
//							If(V_Value < DimSize(DSNamesLB_ListWave,0))
//								dsName =	DSNamesLB_ListWave[V_Value]
//							Else
//								break
//							EndIf
//							
//							deleteDataSet(dsName)
//							break		
//					endswitch
//				
//					break
				case "CreateDSGroup":
				
					CheckDSGroupLists()
					
					String dsGroupName
					Prompt dsGroupName,"Group Name"
					DoPrompt "Add New Data Set Group",dsGroupName
					
					If(V_flag)
						break
					EndIf
					
					If(!strlen(dsGroupName))
						break
					EndIf
					
					Wave/T DSGroupListWave =  NPD:DSGroupListWave
					Wave DSGroupSelWave =  NPD:DSGroupSelWave
					Wave/T DSGroupContents = NPD:DSGroupContents
					Wave/T DSGroupContentsListWave = NPD:DSGroupContentsListWave
					Wave DSGroupContentsSelWave = NPD:DSGroupContentsSelWave
					
					ControlInfo/W=NTP#Data hideAllGroup
					If(V_Value)
						Variable numGroups = DimSize(DSGroupListWave,0) + 1 //stored as depth
						Redimension/N=(numGroups) DSGroupListWave,DSGroupSelWave
						DSGroupListWave[numGroups-1] = dsGroupName
					Else
						numGroups = DimSize(DSGroupListWave,0)
						Redimension/N=(numGroups+1) DSGroupListWave,DSGroupSelWave
						DSGroupListWave[numGroups] = dsGroupName
					EndIf
					
					Redimension/N=(-1,numGroups+1) DSGroupContents
					SetDimLabel 1,numGroups,$dsGroupName,DSGroupContents
					
					//refresh the contents wave
//					ListBox DSGroups win=NTP#Data,selRow=numGroups
//					String group = DSGroupListWave[numGroups]
//					
//				
//					Variable index = FindDimLabel(DSGroupContents,1,group)
//					
//					If(index < 0)
//						break
//					EndIf
//					
//					Redimension/N=(DimSize(DSGroupContents,0)) DSGroupContentsListWave,DSGroupContentsSelWave
//					If(DimSize(DSGroupContentsListWave,0))
//						DSGroupContentsListWave[] = DSGroupContents[p][index]
//						//Remove and blank cells
//					
//						RemoveEmptyCells(DSGroupContentsListWave,0)
//					EndIf
//					
//					Redimension/N=(DimSize(DSGroupContentsListWave,0)) DSGroupContentsSelWave
				
					
					OpenDSNotesEntry2()
					
					notificationEntry = "New Data Group: \f01" + dsGroupName
					SendNotification()
					break
				case "clearFilters":
					clearFilterControls()
					break
				case "DeleteDSGroup":
					//Alert to confirm deletion
					DoAlert 1,"Are you sure you want to delete the Data Group?"
					
					If(V_flag == 2)
						return 0
					EndIf
					
					DeleteDSGroup()
					CheckDSGroupLists()
			
					break
				case "AddToDSGroup":
					PopUpContextualMenu/W=NTP#Data/C=(335,705)/N "DSGroupListMenu"
					
					If(!V_flag)
						break
					EndIf
					
					AddToDSGroup(group=S_Selection)
					CheckDSGroupLists()
					break
				case "RemoveFromDSGroup":
					RemoveFromDSGroup()		
					CheckDSGroupLists()
					break
				case "newDS":
					//add new data set
					dsName = DSMenuFunc("Add New Data Set")
					
					If(!strlen(dsName))
						return 0
					EndIf
					
					If(!cmpstr(dsName,"Output"))
						DoAlert/T="Add Data Set" 0, "The data set name 'Output' is reserved."
						return 0
					EndIf
					
					If(addDataSet(dsName))
						print "ADD DATA SET ERROR"
					EndIf
					
					break
				case "NewDSTable":
					NewDataTable()
					break
				case "deleteDS":
					//delete selected data set
//					Wave/T DSGroupListWave = NPD:DSGroupListWave
					Wave/T DSGroupContentsListWave = NPD:DSGroupContentsListWave
					
					
						//Alert to confirm deletion
					DoAlert 1,"Are you sure you want to delete the Data Set?"
					
					If(V_flag == 2)
						return 0
					EndIf
					
					ControlInfo/W=NTP#Data DSGroupContents
					If(V_Value > DimSize(DSGroupContentsListWave,0) - 1)
						break
					EndIf
					
					String dataset = DSGroupContentsListWave[V_Value]
					
					If(!strlen(dataset))
						break
					EndIf
					
					deleteDataSet(dataset)
					
					break	
				case "UpdateDS":
					//Updates the selected data set with the contents of the WaveMatch list box
					Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
					
					//No data sets exist to be deleted
					If(DimSize(DSNamesLB_ListWave,0) == 0)
						return 0
					EndIf
					
					dsName = GetDSName()
					//Nothing selected
					If(!strlen(dsName))
						return 0
					EndIf
					
					//Is it an archived data set? These cannot be updated from the wave match list.
					Wave/T archive = NPD:$("DS_" + dsName + "_archive")
					
					If(WaveExists(archive))
			
						//This effectively updates an archived data set from its base table
						changeDataSet(dsName)
						
						notificationEntry = "Updated Archive: \f01" + dsName
						sendNotification()
						
						return 0
					EndIf
					
					If(updateDataSet(dsName))
						print "UPDATE DATA SET ERROR"
					EndIf
				
					break		
				case "RecallDS":
					
					dsName = GetDSName()
					//Nothing selected
					If(!strlen(dsName))
						return 0
					EndIf
					
					//Is it an archived data set? These cannot be updated from the wave match list.
					Wave/T archive = NPD:$("DS_" + dsName + "_archive")
					
					If(WaveExists(archive))
						//open the archive instead
						openArchive(dsName)
//						openInteractiveArchive(dsName)
						return 0
					EndIf
					
					SendToWaveMatch(dsName)
					break	
				case "EditNotes":
					//Keyboard hook for taking the notes input					
					NVAR EditingNotes = NPD:EditingNotes
					
					If(!EditingNotes)
						EditingNotes = 1
						Button EditNotes win=NTP#Func,title="Done",fcolor=(0x2000,0xb000,0x2000)
						SetWindow NTP hook(notesHook)=notesHook
					Else
						EditingNotes = 0
						Button EditNotes win=NTP#Func,title="Edit",fcolor=(0,0,0)
						SetWindow NTP hook(notesHook)=$""
					EndIf				
					
					break
				case "OpenNotes":
					//Get selected data set name	
					dsName = GetDSName()
					
					//Nothing selected
					If(!strlen(dsName))
						return 0
					EndIf
					
					//get the notes name, which has all spaces replaced with underscores
					String notesName = ReplaceString(" ",dsName,"_")
					SVAR DSNotes = NPD:$("DS_" + notesName + "_notes")
										
										
					NewPanel/K=1/N=noteEditor/W=(200,200,400,400) as "Note Editor"
					SetVariable strEditor win=noteEditor,pos={10,10},size={180,180},value=NPD:$("DS_" + notesName + "_notes"),styledText=1,title=" "
					
					break
				case "SaveNotes":
					//Get selected data set name	
					dsName = GetDSName()
					SaveDataSetNotes(dsName)
					break
				case "autoscale":
					autoscaleViewer()
					break
				case "horizSpread":
					NVAR areHorizSeparated = NPC:areHorizSeparated
					NVAR areVertSeparated = NPC:areVertSeparated
					
					//Undo any vertical separation
					areVertSeparated = 0
					SeparateTraces("vert")
					Button vertSpread win=NTP#Nav,valueColor=(0,0,0) //sets to standard color
					
					If(areHorizSeparated)
						//undo horizontal separation, back to normal
						areHorizSeparated = 0
						SeparateTraces("horiz")
						
						//Change button color to normal grey
						Button $ba.ctrlName win=NTP#Nav,valueColor=(0,0,0) //sets to standard color
					Else
						//separate horizontally
						areHorizSeparated = 1
						activeRange = 0 //disable range due to multiple bottom axes. Could implement in future.
						addRangeLines()
						SeparateTraces("horiz")
						
						//Change button color to green to show engagement
						Button $ba.ctrlName win=NTP#Nav,valueColor=(0,0xbbbb,0) //sets to green color
					EndIf
					
					colorViewerGraph()
					addThresholdLine()
					break
				case "vertSpread":
					//Undo any horizontal separation
					areHorizSeparated = 0
					SeparateTraces("horiz")
					Button horizSpread win=NTP#Nav,valueColor=(0,0,0) //sets to standard color
					
					If(areVertSeparated)
						//undo vertical separation, back to normal
						areVertSeparated = 0
						SeparateTraces("vert")
						
						//Change button color to normal grey
						Button $ba.ctrlName win=NTP#Nav,valueColor=(0,0,0) //sets to standard color
					Else
						//separate vertically
						areVertSeparated = 1
						SeparateTraces("vert")
						
						//Change button color to green to show engagement
						Button $ba.ctrlName win=NTP#Nav,valueColor=(0,0xbbbb,0) //sets to green color
					EndIf
					
					colorViewerGraph()
					addThresholdLine()
					break
				case "displayViewerContents":
					displayViewerGraph()
					break
				case "colorTraces":
					areColored = (areColored) ? 0 : 1
					colorViewerGraph()
					break
				case "addThreshold":

					activeThreshold = (activeThreshold) ? 0 : 1
					addThresholdLine()
					
					break
				case "addRange":
					
					If(areHorizSeparated) //disabled if horizontal spread is activated
						break
					EndIf
					
					activeRange = (activeRange) ? 0 : 1
					addRangeLines()
					break
				case "clearViewer":
					activeRange = 0
					activeThreshold = 0
					addRangeLines()
					addThresholdLine()
					clearTraces()
					break
			endswitch
		break
	case 5://mouse enter
		strswitch(ba.ctrlName)
			case "Back":
			case "autoscale":
			case "horizSpread":
			case "vertSpread":
			case "colorTraces":
			case "addThreshold":
			case "clearViewer":
			case "addRange":
			case "displayViewerContents":
				Button $ba.ctrlName win=NTP#Nav,fColor=(0xffff,0xffff,0xffff) //sets to focus grey (0xffff isn't white here, but as light as the button allows).
				break
			case "SaveNotes":
				Button $ba.ctrlName win=NTP#Func,fColor=(0xffff,0xffff,0xffff) //sets to focus grey (0xffff isn't white here, but as light as the button allows).
				break
			default:
				Button $ba.ctrlName win=NTP#Data,fColor=(0xffff,0xffff,0xffff) //sets to focus grey (0xffff isn't white here, but as light as the button allows).
				break
		endswitch
		
		break
	case 6://mouse leave
		strswitch(ba.ctrlName)
			case "Back":
			case "autoscale":
			case "horizSpread":
			case "vertSpread":
			case "colorTraces":
			case "addThreshold":
			case "clearViewer":
			case "addRange":
			case "displayViewerContents":
				Button $ba.ctrlName win=NTP#Nav,fColor=(0,0,0) //sets to standard color
				break
			case "SaveNotes":
				Button $ba.ctrlName win=NTP#Func,fColor=(0,0,0) //sets to focus grey (0xffff isn't white here, but as light as the button allows).
				break
			default:
				Button $ba.ctrlName win=NTP#Data,fColor=(0,0,0) //sets to standard color
				break
		endswitch
		
		break
	case -1: // control being killed
			break
	endswitch
	
	return 0
End



Function CloseDSGroupForm()
	 String list = ControlNameList("NTP#Func",";")
	 Variable i
	 For(i=0;i<ItemsInList(list,";");i+=1)
	 	ControlInfo/W=NTP#Data $StringFromList(i,list,";")
	 	
	 	switch(V_flag)
	 		case 1: //button
	 			Button $StringFromList(i,list,";") win=NTP#Data,disable=3
	 			break
	 		case 9: //group box
	 			GroupBox $StringFromList(i,list,";") win=NTP#Data,disable=3
	 			break
	 		case 11: //list box
	 			ListBox $StringFromList(i,list,";") win=NTP#Data,disable=3
	 	endswitch
	 EndFor
	 
	 SetDrawLayer/W=NTP#Data UserBack
	 DrawAction/W=NTP#Data getgroup=dataSetGroupText,delete
	
End

//Creates the viewer window to display selected waves and wavesets
Function SetupViewer()
	DFREF NPC = $CW
	DFREF NPD = $DSF
	Variable fontSize = 12
	Variable left = 10
	Variable top = 640
End

Function viewerHook(s)
	STRUCT WMWinHookStruct &s
	DFREF NPC = $CW
	
	NVAR activeThreshold = NPC:activeThreshold
	NVAR threshold = NPC:threshold
	NVAR moveThreshold = NPC:moveThreshold
	NVAR screenBottom = NPC:screenBottom
	NVAR activeRange = NPC:activeRange
	NVAR rangeLeft = NPC:rangeLeft
	NVAR rangeRight = NPC:rangeRight
	NVAR moveRangeLeft = NPC:moveRangeLeft
	NVAR moveRangeRight = NPC:moveRangeRight
	
	Variable hookResult = 0

	switch(s.eventCode)
		case 0:				// Activate
			// Handle activate
			break

		case 1:				// Deactivate
			// Handle deactivate
			break
		case 3:
			//Mouse Down
			
			If(activeThreshold || activeRange)
				ControlInfo/W=NTP#Nav viewerPanel
				Variable topPos = V_top
				
				If(s.mouseLoc.h > 10 && s.mouseLoc.h < 430 && s.mouseLoc.v < screenBottom-20 && s.mouseLoc.v > topPos)
					//Get Y axis information
					Variable yCoord = AxisValFromPixel("NTP#NaV#Viewer","left",s.mouseLoc.v)
					
					GetAxis/W=NTP#NaV#Viewer/Q left
					Variable yMax = V_max
					Variable yMin = V_min
					Variable range = yMax - Ymin
					
					//Get X axis information
					Variable xCoord = AxisValFromPixel("NTP#NaV#Viewer","bottom",s.mouseLoc.h)
					
					GetAxis/W=NTP#NaV#Viewer/Q bottom
					Variable xMax = V_max
					Variable xMin = V_min
					Variable xRange = xMax - xmin
					
					//5% lenience for clicking the threshold bar
					If(yCoord > threshold - abs(range * 0.05) && yCoord < threshold + abs(range * 0.05))
						moveThreshold = 1
						moveRangeLeft = 0
						moveRangeRight = 0
						hookResult = 1
					ElseIf(xCoord > rangeLeft - abs(xRange * 0.05) && xCoord < rangeLeft + abs(xRange * 0.05))
						//left range clicked
						moveRangeLeft = 1
						moveRangeRight = 0
						moveThreshold = 0
						hookResult = 1
					ElseIf(xCoord > rangeRight - abs(xRange * 0.05) && xCoord < rangeRight + abs(xRange * 0.05))
					//right range clicked
						moveRangeLeft = 0
						moveRangeRight = 1
						moveThreshold = 0
						hookResult = 1
					Else
						moveThreshold = 0
						hookResult = 0
					EndIf

				EndIf
			EndIf
				
			break
		case 4:
			//Mouse Moved
			If(activeThreshold || activeRange)
//				print s.mouseLoc.h,s.mouseLoc.v,screenBottom-20
				
				ControlInfo/W=NTP#Nav viewerPanel
				topPos = V_top
				
				If(s.mouseLoc.h > 10 && s.mouseLoc.h < 430 && s.mouseLoc.v < screenBottom-20 && s.mouseLoc.v > topPos)
					If(moveThreshold)
						threshold = AxisValFromPixel("NTP#NaV#Viewer","left",s.mouseLoc.v)
						addThresholdLine()
		//				DoUpdate/W=NL#LiveViewer
						hookResult = 1
					ElseIf(moveRangeLeft)
						rangeLeft = AxisValFromPixel("NTP#NaV#Viewer","bottom",s.mouseLoc.h)
						If(rangeLeft > rangeRight)
							rangeRight = rangeLeft
						EndIf
						
						addRangeLines()
						hookResult = 1
					ElseIf(moveRangeRight)
						rangeRight = AxisValFromPixel("NTP#NaV#Viewer","bottom",s.mouseLoc.h)
						If(rangeRight < rangeLeft)
							rangeLeft = rangeRight
						EndIf
						addRangeLines()
						hookResult = 1
					EndIf
					
					//Get Y Axis data
					yCoord = AxisValFromPixel("NTP#NaV#Viewer","left",s.mouseLoc.v)
					GetAxis/W=NTP#NaV#Viewer/Q left
					yMax = V_max
					yMin = V_min
					range = yMax - Ymin
					
					//Get X Axis data
					xCoord = AxisValFromPixel("NTP#NaV#Viewer","bottom",s.mouseLoc.h)
					GetAxis/W=NTP#NaV#Viewer/Q bottom
					xMax = V_max
					xMin = V_min
					xRange = xMax - xMin
					
					//5% lenience for clicking the threshold bar
					If(yCoord > threshold - abs(range * 0.05) && yCoord < threshold + abs(range * 0.05) && activeThreshold)
						s.doSetCursor = 1
						s.cursorCode = 6
						hookResult = 1
					ElseIf(xCoord > rangeLeft - abs(xRange * 0.05) && xCoord < rangeLeft + abs(xRange * 0.05) && activeRange)
						s.doSetCursor = 1
						s.cursorCode = 5
						hookResult = 1
					ElseIf(xCoord > rangeRight - abs(xRange * 0.05) && xCoord < rangeRight + abs(xRange * 0.05) && activeRange)
						s.doSetCursor = 1
						s.cursorCode = 5
						hookResult = 1
					EndIf
				EndIf
			EndIf			
			
			break
		case 5:
			//Mouse up
			
			moveThreshold = 0
			moveRangeLeft = 0
			moveRangeRight = 0
			hookResult = 1
			break
		case 22:
			//Mouse wheel
			ControlInfo/W=NTP#Nav viewerPanel
			topPos = V_top
				
			If(s.mouseLoc.h > 10 && s.mouseLoc.h < 430 && s.mouseLoc.v < screenBottom-20 && s.mouseLoc.v > topPos)
				If(s.eventMod == 4) //Option key held while moving mouse wheel
					expandAxisWheel("bottom",s.wheelDy)
				Else
					expandAxisWheel("left",s.wheelDy)
				EndIf
			EndIf
			
			break
	endswitch
	return hookResult		// 0 if nothing done, else 1
End

Function autoScaleViewer()
	SetAxis/W=NTP#Nav#Viewer/A
End

//Loads Data set group controls
Function SetupDSGroupForm(dsName)
	String dsName
	
	DFREF NPC = $CW
	DFREF NPD = $DSF
	
	NVAR funcPanelWidth = NPC:funcPanelWidth
	
	Wave/T DSGroupListWave =  NPD:DSGroupListWave
	Wave DSGroupSelWave =  NPD:DSGroupSelWave
	Wave/T DSGroupContentsListWave = NPD:DSGroupContentsListWave
	Wave DSGroupContentsSelWave = NPD:DSGroupContentsSelWave
	Wave/T DSGroupContents = NPD:DSGroupContents
	
	Variable fontSize = 12
	
	ControlInfo/W=NTP#Data dataSetPanel
	Variable dsPanelTop = V_top
	Variable dsPanelHeight = V_height
	
//	If(!strlen(dsName))
//		return 0
//	EndIf
	
	//offset from left edge of the panel
	Variable left = 10
	
	//What is the data set being assigned?
	SetDrawEnv/W=NTP#Data gstart,gname=dataSetGroupText
//	SetDrawEnv/W=NTP#Data xcoord= abs,ycoord= abs, fsize=16, textxjust= 1,textyjust= 1,fname=$LIGHT
//	DrawText/W=NTP#Data funcPanelWidth/2,15,"DATA SET EDITOR"
	
	SetDrawEnv/W=NTP#Data xcoord= abs,ycoord= abs, fsize=16, textxjust= 1,textyjust= 1,fname=$LIGHT,fStyle=0
	DrawText/W=NTP#Data left + 70,dsPanelTop + 20,"DATA GROUPS"	
	SetDrawEnv/W=NTP#Data xcoord= abs,ycoord= abs, fsize=16, textxjust= 1,textyjust= 1,fname=$LIGHT,fStyle=0
	DrawText/W=NTP#Data left + 225,dsPanelTop + 20,"DATA SETS"
	SetDrawEnv/W=NTP#Data gstop
	
	Variable topPos = dsPanelTop + 40
	Variable buttonWidth = 130
	
	ListBox DSGroups win=NTP#Data,pos={left,topPos},size={150,dsPanelHeight - 50},fsize=11,font=$REG,frame=0,listWave=DSGroupListWave,selWave=DSGroupSelWave,disable=0,mode=2,proc=NTPListBoxProc
	ListBox DSGroupContents win=NTP#Data,pos={left + 160,topPos},size={150,dsPanelHeight - 50},fsize=11,frame=0,font=$REG,listWave=DSGroupContentsListWave,selWave=DSGroupContentsSelWave,disable=0,mode=2,proc=NTPListBoxProc
	
	Checkbox hideAllGroup win=NTP#Data,pos={left + 330,topPos - 15},size={buttonWidth,20},title="Hide 'All' Group",fsize=fontSize,font=$LIGHT,disable=0,proc=NTPCheckProc
	topPos += 10
	Button NewDS win=NTP#Data,pos={left + 325,topPos},size={80,20},title="New Data Set",font=$LIGHT,fsize=fontSize,disable=0,proc=NTPButtonProc
	Button NewDSTable win=NTP#Data,pos={left + 325 + 85,topPos},size={45,20},title="Table",font=$LIGHT,fsize=fontSize,disable=0,proc=NTPButtonProc
	topPos += 25
	Button DeleteDS win=NTP#Data,pos={left + 325,topPos},size={buttonWidth,20},title="Delete Data Set",font=$LIGHT,fsize=fontSize,disable=0,proc=NTPButtonProc	
	topPos += 30
	
	SetDrawEnv/W=NTP#Data linefgc=(0,0,0,0x4000),linethick=1
	DrawLine/W=NTP#Data  left + 325,topPos-5,left + 325 + 120,topPos-5
	
	Button UpdateDS win=NTP#Data,pos={left + 325,topPos},size={buttonWidth,20},title="Update Data Set",font=$LIGHT,fsize=fontSize,disable=0,proc=NTPButtonProc
	topPos += 25
	Button RecallDS win=NTP#Data,pos={left + 325,topPos},size={buttonWidth,20},title="Recall Data Set",font=$LIGHT,fsize=fontSize,disable=0,proc=NTPButtonProc		
	topPos += 30
	
	SetDrawEnv/W=NTP#Data linefgc=(0,0,0,0x4000),linethick=1
	DrawLine/W=NTP#Data  left + 325,topPos-5,left + 325 + 120,topPos-5
	
	Button CreateDSGroup win=NTP#Data,pos={left + 325,topPos},size={buttonWidth,20},title="New Group",font=$LIGHT,fsize=fontSize,disable=0,proc=NTPButtonProc
	topPos += 25
	Button DeleteDSGroup win=NTP#Data,pos={left + 325,topPos},size={buttonWidth,20},title="Delete Group",font=$LIGHT,fsize=fontSize,disable=0,proc=NTPButtonProc
	topPos += 30
	
	SetDrawEnv/W=NTP#Data linefgc=(0,0,0,0x4000),linethick=1
	DrawLine/W=NTP#Data  left + 325,topPos-5,left + 325 + buttonWidth,topPos-5
	
	Button AddToDSGroup win=NTP#Data,pos={left + 325,topPos},size={buttonWidth,20},title="Add To Group",font=$LIGHT,fsize=fontSize,disable=0,proc=NTPButtonProc
	topPos += 25
	Button RemoveFromDSGroup win=NTP#Data,pos={left + 325,topPos},size={buttonWidth,20},title="Remove From Group",font=$LIGHT,fsize=fontSize,disable=0,proc=NTPButtonProc
	topPos += 30
	
	
	
	
	
	//Find position of previously built panels
	ControlInfo/W=NTP#Data dataSetPanel
	
	//Data Set Notes
//	Button EditNotes win=NTP#Func,pos={V_right - 70,V_top},size={50,19},font=$LIGHT,fsize=fontSize,title="Edit",disable=0,proc=NTPButtonProc
//	Button OpenNotes win=NTP#Func,pos={V_right - 70,V_top + 20},size={50,19},font=$LIGHT,fsize=fontSize,title="Open",disable=0,proc=NTPButtonProc
//	
////	Button OpenNotes win=NTP#Func,pos={left+346,613},size={50,19},font=$LIGHT,fsize=fontSize,title="Open",disable=0,proc=NTPButtonProc
//	SetDrawLayer/W=NTP#Func Overlay
//	DrawAction/W=NTP#Func getgroup=dsNotesText,delete
	
	//Create a new notebook panel that will hold the notes page for all data sets


	OpenDSNotesEntry2(dataset=dsName)
End

//Handles the data set add/delete/update pop up menu
Function/S DSMenuFunc(String selection)
	DFREF NPD = $DSF
	
	If(!strlen(selection)) // no selection
		return ""
	EndIf
	
	strswitch(selection)
		case "Add New Data Set":
					
			String dsName
			Prompt dsName,"Name"
			DoPrompt "Add New Data Set",dsName
			
			If(V_flag)
				return ""
			EndIf
			
			If(!cmpstr(dsName,"Output"))
				DoAlert/T="Add Data Set" 0, "The data set name 'Output' is reserved."
				return ""
			EndIf
			
			return dsName
			break
		case "Update Current Data Set":
			ControlInfo/W=NTP#Data DSGroupContents
			Wave/T listWave = NPD:DSGroupContentsListWave
			
			If(DimSize(listWave,0) == 0)
				//can't update without a selection, so add a new data set instead
				Prompt dsName,"Name"
				DoPrompt "Add New Data Set",dsName
				
				If(V_flag)
					return ""
				Else
					If(!cmpstr(dsName,"Output"))
						DoAlert/T="Add Data Set" 0, "The data set name 'Output' is reserved."
						return ""
					EndIf
					
					If(addDataSet(dsName))
						print "ADD DATA SET ERROR"
					EndIf
					return ""
				EndIf
			Else
				return listWave[V_Value]
			EndIf
			
			break
	endswitch
	return ""
End

Function NTPSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	STRUCT filters filters
	
	DFREF NPC = $CW
	DFREF NPD = $DSF
		
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
			Variable dval = sva.dval
			String sval = sva.sval
			
			strswitch(sva.ctrlName)
				case "waveMatch":
				case "waveNotMatch":
				case "relativeFolderMatch":
					//Save the current filters/grouping settings before changing focus
//					saveFilterSettings("DataSet")
					
//					
//					//Don't recall previous settings, bc we just changed it.
//					changeFocus("WaveMatch",0)
					
				case "waveGrouping":
				case "prefixGroup":
				case "groupGroup":
				case "seriesGroup":
				case "sweepGroup":
				case "traceGroup":					
					//Builds the match list according to all search terms, groupings, and filters
//					GetMatchedWaves()
					
//					//display the full path to the wave in a text box
//					drawFullPathText()
					
					break
				case "dsNameInput":
					SVAR dsNameInput = NPD:dsNameInput
					dsNameInput = sval
					break
				case "cmdLineStr":
					SVAR masterCmdLineStr = NPC:masterCmdLineStr
					NVAR editingMasterCmdLineStr = NPC:editingMasterCmdLineStr
					
					//break if not in editing mode
					If(editingMasterCmdLineStr == -1)
						break
					EndIf
					
					//If we're in editing mode
//					//Replace the specified entry
//					masterCmdLineStr = ReplaceListItem(editingMasterCmdLineStr,masterCmdLineStr,";/;",sval)
//					
//					//ensure that the correct separator is on the end
//					masterCmdLineStr = RemoveEnding(masterCmdLineStr,";/;") + ";/;"
//					
//					//Redraw the command list entries
//					DrawMasterCmdLineEntry()
//					
//					//reset the editing mode
//					editingMasterCmdLineStr = -1
					break
			endswitch
		case 3: // Live update
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


//Switches the current data folder up one level
//Refreshes the folder and wave list box contents
Function folderBack()
	DFREF NPC = $CW
	
	//Change the current data folder
	SVAR cdf = NPC:cdf
	
	//Do nothing if we're already in root
	If(!cmpstr(cdf,"root:"))
		return 0
	EndIf
	
	cdf = ParseFilePath(1,cdf,":",1,0)
	SetDataFolder cdf
	
	//Refresh the folder and waves list boxes
	updateFolders()
	updateFolderWaves()
	
	Wave FolderLB_SelWave = NPC:FolderLB_SelWave
	
	//Set the selection to the first row
	If(DimSize(FolderLB_SelWave,0) > 0)
		FolderLB_SelWave = 0
		FolderLB_SelWave[0] = 1
	EndIf
End

//Migrates all settings and data set definitions from NeuroTools to NeuroTools+
Function MigrateDataSets()
	
	//Confirmation
	String promptStr = "Are you sure? This will overwrite any existing NeuroToolsPlus formatted data sets."
	DoAlert/T="Migrate Data Sets" 1,promptStr
	
	If(V_flag > 1)
		return 0
	EndIf
	
	//First open NeuroTools+ if it isn't already opened
	LoadNeuroPlus()
	
	DFREF NPC = $CW
	DFREF NPD = $DSF
	DFREF NT = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	DFREF SI = root:Packages:NT:ScanImage
	
	
	//List of data set names and their filters/definitions
	Wave/T NT_DSList = NTD:DSNamesLB_ListWave
	Wave/T NP_DSList = NPD:DSNamesLB_ListWave
	Wave NP_DSListSel = NPD:DSNamesLB_SelWave
	Wave/T NP_DSGroupContents = NPD:DSGroupContents
	Wave NP_DSGroupContentsSel = NPD:DSGroupContentsSelWave
	
	matchContents(NT_DSList,NP_DSList)
	matchContents(NT_DSList,NP_DSList)
	Redimension/N=(DimSize(NP_DSList,0)) NP_DSListSel
	
	//Adjust the filters to include the pos6 and pos7 underscore positions
	Variable i
	For(i=0;i<DimSize(NP_DSList,0);i+=1)
		String entry = NP_DSList[i][0][1]
		entry = AddListItem(";",entry,";",8)
		NP_DSList[i][0][1] = entry
	EndFor
	
	String transferList = ""
	
	//Find all data sets in the list and transfer them over
	For(i=0;i<DimSize(NP_DSList,0);i+=1)
		String dataset = NP_DSList[i][0][0]
		
		//BASE
		Wave/T BASE = NTD:$("DS_" + dataset)
		If(WaveExists(BASE))
			Duplicate/O BASE,NPD:$("DS_" + dataset)
		Else
			//If can't find the data set wave, delete it from the data set name list
			DeletePoints/M=0 i,1,NP_DSList
			continue
		EndIf
		
		//BASE
		Wave/T ORG = NTD:$("DS_" + dataset + "_org")
		If(WaveExists(ORG))
			Duplicate/O ORG,NPD:$("DS_" + dataset + "_org")
		ElseIf(WaveExists(BASE))
			//If the base wave exists but the organized one doesn't for some reason
			Make/T/O/N=(DimSize(BASE,0),1,2) NPD:$("DS_" + dataset + "_org")/Wave=NEWORG
			matchContents(ORG,NEWORG)
		EndIf
		
		transferList += dataset + ";"
	EndFor
	
	//Add all the transferred data sets into the data group contents wave
	Variable size = ItemsInList(transferList,";")
	//don't overwrite existing data sets if they have been made prior to migration
	Variable startPt = DimSize(NP_DSGroupContents,0)
	
	//Put each data set into the 'All' data group and make notes string variables
	Redimension/N=(DimSize(NP_DSGroupContents,0) + size,-1) NP_DSGroupContents
	For(i=0;i<ItemsInList(transferList,";");i+=1)
		dataset = StringFromList(i,transferList,";")
		NP_DSGroupContents[startPt + i][0] = dataset
		
		SVAR notes = NPD:$("DS_" + dataset + "_notes")
		
		If(!SVAR_Exists(notes))
			String/G NPD:$("DS_" + dataset + "_notes")
		EndIf
	EndFor
	
	//intialize the list box
	SetDSGroup(group="All")
	
	//For each data set in the All group, re-initialize so it gets labelled with wave set sizes properly
	For(i=0;i<DimSize(NP_DSGroupContents,0);i+=1)
		ListBox DSGroupContents win=NTP#Data,selRow=i
		recallFilterSettings("DataSet")			
		getWaveMatchList()				
	EndFor
	
	//Reset to the first data set in the list
	ListBox DSGroupContents win=NTP#Data,selRow=0
	recallFilterSettings("DataSet")			
	getWaveMatchList()		
	
	//Check if there are ScanImage folders to move over
	If(DataFolderExists("root:Packages:NT:ScanImage"))
		If(DataFolderExists("root:Packages:NT:ScanImage:ROIs"))
			CreateFolder("root:Packages:NeuroToolsPlus:ScanImage:ROIs")
			DuplicateDataFolder/O=2/Z root:Packages:NT:ScanImage:ROIs,root:Packages:NeuroToolsPlus:ScanImage:ROIs
		EndIf
	EndIf
	
	SVAR notificationEntry = NPC:notificationEntry
	notificationEntry = "Migrated Data Sets"
	SendNotification()
End

//Make the Von Mises fit function for curve fit
Function NT_vonMises(w,x) : FitFunc
	Wave w
	Variable x

	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ //	return w[2]*exp(w[1]*cos((x-w[0])*pi/180))/(2*pi*Besseli(0,w[1]))
	//CurveFitDialog/ f(x) = peak*exp(kappa*cos((x-mu)*pi/180))/exp(kappa)	// Peak = w[2]
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ x
	//CurveFitDialog/ Coefficients 3
	//CurveFitDialog/ w[0] = mu
	//CurveFitDialog/ w[1] = kappa
	//CurveFitDialog/ w[2] = peak

	//	return w[2]*exp(w[1]*cos((x-w[0])*pi/180))/(2*pi*Besseli(0,w[1]))
	return w[2]*exp(w[1]*cos((x-w[0])*pi/180))/exp(w[1])	// w[2] = w[2]
End

// Difference of Gaussians
Function NT_DOG(w,xx) : FitFunc
	Wave w
	Variable xx

	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(xx) = amplitude1* (1-exp(-(xx/width1)^2)) + amplitude2* (1-exp(-(xx/width2)^2)) //- w[4]* (1-exp(-(xx/w[5])^2))
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ xx
	//CurveFitDialog/ Coefficients 4
	//CurveFitDialog/ w[0] = amplitude1
	//CurveFitDialog/ w[1] = width1
	//CurveFitDialog/ w[2] = amplitude2
	//CurveFitDialog/ w[3] = width2

	Return w[0]*(1-exp(-(xx/w[1])^2))+ w[2]*(1-exp(-(xx/w[3])^2))
End