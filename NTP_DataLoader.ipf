#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Menu "Macros"
	"Data Loader",/Q,OpenDataLoaderInterface()
End

Function OpenDataLoaderInterface()
//Opens the data loader interface panel
	
	DFREF NTP = $CW
	
	KillWindow/Z DLI
	
	//Opens a panel for the data loader interface
	NewPanel/W=(0,0,950,400)/K=1/N=DLI as "Data Loader"
	
	//Browse button for initial navigation entry point
	Button BrowseSystemFolders win=DLI,pos={10,10},size={140,20},title="Select Data Folder...",proc=SystemFoldersButtonProc
	
	//Back button
	Button BackSystemFolders win=DLI,pos={160,10},size={40,20},title="↰",proc=SystemFoldersButtonProc
	
	//Populate the DLI with empty list boxes to hold the folder structure for navigating
	Make/N=0/O/T NTP:SystemFoldersListWave/Wave=listwave
	ListBox SystemFolders win=DLI,pos={10,50},size={150,300},title="System Folders",listwave=listwave,mode=1,proc=SystemFoldersListProc

	//Populate the DLI with empty list boxes to hold the files within each folder
	Make/N=0/O/T NTP:SystemFilesListWave/Wave=DataListWave
	Make/N=0/O NTP:SystemFilesSelWave/Wave=DataSelWave
	ListBox SystemFiles win=DLI,pos={170,50},size={150,300},title="Files",listwave=DataListWave,selwave=DataSelWave,mode=9,proc=SystemFilesListProc
	
	//Add Data button
	Button AddData win=DLI,pos={330,360},size={200,20},title="Add Selected Data →",proc=AddDataButtonProc
	
	//List box that will hold a summary of the contents of a given file. This will depend on the file type
	Make/N=0/O/T NTP:DataContentsListWave/Wave=DataContentsListWave
	Make/N=0/O NTP:DataContentsSelWave/Wave=DataContentsSelWave
	ListBox DataContents win=DLI,pos={330,50},size={200,300},special={0,0,1},mode=9,listwave=DataContentsListWave,selwave=DataContentsSelWave
	
	//Create a list box to hold all of the 'added' data paths
	Make/N=0/O/T NTP:IncludedDataListWave/Wave=IncludedDataListWave
	Make/N=0/O NTP:IncludedDataSelWave/Wave=IncludedDataSelWave
	ListBox IncludedData win=DLI,pos={540,50},size={400,300},title="Included Data",special={0,0,1},mode=9,listwave=IncludedDataListWave,selWave=IncludedDataSelWave
	
	//Port data into a data set archive for renaming purposes
	Button PortToArchive win=DLI,pos={740,360},size={160,20},title="Customize Wave Names",proc=CustomizeButtonProc
	
	Button RemoveData win=DLI,pos={560,360},size={160,20},title="Remove Data",proc=RemoveDataButtonProc
	
	PathInfo SystemFolderPath
	If(V_flag)
		OpenSystemFolder()
	EndIf
End

Function OpenSystemFolder()
//Opens the double clicked system folder
	
	DFREF NTP = $CW
	Wave/T listwave = NTP:SystemFoldersListWave
	
	//Get all of the subfolders within the folder selection, which is placed in the 
	String folderList = IndexedDir(SystemFolderPath,-1,0)
	String removeList = ListMatch(folderList,".*",";")
	
	//Clean up the folder list to take out hidden folders
	Variable i
	For(i=0;i<ItemsInList(removeList,";");i+=1)
		folderList = RemoveFromList(StringFromList(i,removeList,";"),folderList,";")
	EndFor
	
	//Assign the subfolders to the listbox for potential navigation via double click
	Redimension/N=(ItemsInList(folderList,";")) listwave
	listwave = StringFromList(p,folderList,";")
	
	//Index all the files within the folder selection
	String fileList = IndexedFile(SystemFolderPath,-1,"????")
	
	//Clean up the file list to take out hidden file
	removeList = ListMatch(fileList,".*",";")
	For(i=0;i<ItemsInList(removeList,";");i+=1)
		folderList = RemoveFromList(StringFromList(i,removeList,";"),folderList,";")
	EndFor
		
	Wave/T DataListWave = NTP:SystemFilesListWave
	Wave DataSelWave = NTP:SystemFilesSelWave
	
	Redimension/N=(ItemsInList(fileList,";")) DataListWave,DataSelWave
	DataListWave = StringFromList(p,fileList,";")
			
	//Print the current folder as text above the list boxes
	PathInfo SystemFolderPath
	DrawAction/W=DLI getgroup=pathText,delete
	SetDrawEnv/W=DLI xcoord=abs,ycoord=abs,fsize=12,gname=pathText,gstart
	DrawText/W=DLI 10,47,S_path
	SetDrawEnv/W=DLI gstop
	
End

Function/WAVE GetDataSummary(DataSummary,DataSummarySelWave,dataFile)
	Wave/T DataSummary	//listwave for the summary list box
	Wave DataSummarySelWave //selection wave for the summary list box
	String dataFile
	
	DFREF NPC = $CW
	
	PathInfo SystemFolderPath
	If(V_flag)
		String dataPath = S_path + dataFile
		String dataFolder = S_path
	Else
		return $""
	EndIf
	
	Variable fileID
	
	//What is the file type?
	String extension = ParseFilePath(0,dataFile,".",1,0)
	strswitch(extension)
		case "abf":
		case "abf2":
			print "PClamp"
			
			Wave SystemFilesSelWave = NPC:SystemFilesSelWave
			Wave/T SystemFilesListWave = NPC:SystemFilesListWave

			//How many files are selected?
			String seriesList = ""
			String fileNameList = ""
			Variable i
			For(i=0;i<DimSize(SystemFilesSelWave,0);i+=1)
				If(SystemFilesSelWave[i] > 0)
					fileNameList += SystemFilesListWave[i] + ";"
					seriesList += num2str(str2num(ParseFilePath(0,RemoveEnding(SystemFilesListWave[i],".abf"),"_",1,0))) + ";"
				EndIf
			EndFor
			
			Variable nSeries = ItemsInList(seriesList,";")
			
			//Redimension the data summary wave
			Redimension/N=(nSeries,5) DataSummary
			Redimension/N=(nSeries) DataSummarySelWave
			
			//Add in the series list to the data summary
			DataSummary[][0] = StringFromList(p,seriesList,";")
			
			For(i=0;i<nSeries;i+=1)
				Variable index = str2num(StringFromList(i,seriesList,";"))
				String abfPath = dataFolder + SystemFilesListWave[index]
				String sweepStr = "1-" + num2str(pClamp_GetNumSweeps(abfPath))
				
				//Add in the protocol name to the data summary
				String protocol = pClamp_GetProtocolName(abfPath)
				DataSummary[i][1] = protocol
				
				//Add in the series list to the data summary
				DataSummary[i][2] = sweepStr
				
				String chUnits = pClamp_GetChannelUnits(abfPath)
				DataSummary[i][3] = StringFromList(0,chUnits,";")
				
				//Add in pClamp indicator
				DataSummary[i][4] = "pClamp"
			EndFor
			
			
			
			break
		case "h5":
		case "hdf5":
			
			//Open the file
			HDF5OpenFile/R fileID as dataPath
			
			//Series list
			seriesList = TT_GetSeriesList(fileID,";")
			
			nSeries = ItemsInList(seriesList,";")
			Redimension/N=(nSeries,5) DataSummary
			Redimension/N=(nSeries) DataSummarySelWave
			
			DataSummary[][0] = StringFromList(p,seriesList,";")
			
			//Protocol list
			String protocolList = TT_GetProtocolList(fileID)
			DataSummary[][1] = StringFromList(p,protocolList,";")
			
			//Open the data group
			Variable DataGroup_ID
			HDF5OpenGroup/Z fileID,"/Data",DataGroup_ID
			
			//How many sweeps are in each series number?
			For(i=0;i<nSeries;i+=1)
				String sweepList = TT_GetSweepList(fileID,DataSummary[i][0],";")
				String firstNum = StringFromList(0,sweepList,";")
				String lastNum = StringFromList(ItemsInList(sweepList,";")-1,sweepList,";")
				
				If(cmpstr(firstNum,lastNum))
					String finalSweepList = firstNum + "-" + lastNum
				Else
					finalSweepList = firstNum
				EndIf
			
				DataSummary[i][2] = finalSweepList

				//Load in the units data for the first sweep, it'll be the same for all sweeps
				HDF5LoadData/Q/A="IGORWaveUnits"/N=units/TYPE=2/O fileID,"/Data/" + DataSummary[i][0] + "/Ch1/" + StringFromList(0,sweepList,";")
				Wave/T units
		
				strswitch(units[0])
					case "V":
						//Current clamp
						DataSummary[i][3] = "CC"
						break
					case "A":
						//Voltage clamp
						DataSummary[i][3] = "VC"
						break
				endswitch
				
				KillWaves units
				
				DataSummary[i][4] = "Turntable"
			EndFor		
			
			//Close the file
			HDF5CloseFile/Z fileID
			break
	endswitch
End

Function SystemFoldersListProc(lba) : ListBoxControl
//Controls the System Folders list box
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave
		
	DFREF NTP = $CW
	
	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			break
		case 3: // double click
			If(row == -1 || row > DimSize(listwave,0) - 1)
				break
			EndIf
			
			//Set the system path to the selected folder
			PathInfo SystemFolderPath
			NewPath/O/Q/Z SystemFolderPath,S_path + listwave[row] + ":"
			
			//failsafe in case the path was somehow invalid
			If(V_flag)
				NewPath/O/Q/Z SystemFolderPath,S_path
			EndIf
			
			OpenSystemFolder()
			
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
			break
		case 6: // begin edit
			break
		case 7: // finish edit
			break
		case 13: // checkbox clicked (Igor 6.2 or later)
			break
	endswitch

	return 0
End

Function SystemFilesListProc(lba) : ListBoxControl
//Controls the System Files list box
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave
		
	DFREF NTP = $CW
	
	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			break
		case 3: // double click
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
		
			Wave/T DataContentsListWave = NTP:DataContentsListWave
			Wave DataContentsSelWave = NTP:DataContentsSelWave
			
			If(row < 0 || row > DimSize(selWave,0) - 1)
				Redimension/N=0 DataContentsListWave,DataContentsSelWave
				break
			EndIf
				
			
			//Only show the contents of the row that is selected upon mouse release
			Variable i,count = 0
			For(i=0;i<DimSize(selWave,0);i+=1)
				If(selWave[i] > 0)
					count += 1
				EndIf
				
				If(count > 1)
					break
				EndIf
			EndFor
			
			If(count > 1)
				If(stringmatch(listWave[row],"*.abf") || stringmatch(listWave[row],"*.abf2"))
					Redimension/N=(1,5) DataContentsListWave
					Redimension/N=1 DataContentsSelWave
					DataContentsListWave = ""
					DataContentsSelWave = 0
					
					//pass .abf string if you want the function to resolve multiple item list of files
					GetDataSummary(DataContentsListWave,DataContentsSelWave,".abf")
					
					ListBox DataContents win=DLI,special={0,0,1}
					
				Else
					Redimension/N=1 DataContentsListWave,DataContentsSelWave
					DataContentsListWave = "Multiple data files are selected..."
				EndIf
			ElseIf(count == 0)
				Redimension/N=0 DataContentsListWave,DataContentsSelWave
			ElseIf(count == 1)
				Redimension/N=(1,5) DataContentsListWave
				Redimension/N=1 DataContentsSelWave
				DataContentsListWave = ""
				DataContentsSelWave = 0
				
				GetDataSummary(DataContentsListWave,DataContentsSelWave,listWave[row])
				
				ListBox DataContents win=DLI,special={0,0,1}
			EndIf
			
			break
		case 6: // begin edit
			break
		case 7: // finish edit
			break
		case 13: // checkbox clicked (Igor 6.2 or later)
			break
	endswitch

	return 0
End

Function SystemFoldersButtonProc(ba) : ButtonControl
//Controls the buttons on the data loader interface panel
	STRUCT WMButtonAction &ba
	
	DFREF NTP = $CW
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			
			strswitch(ba.ctrlName)
				case "BackSystemFolders":
					//Navigate the folder path to parent directory
					PathInfo SystemFolderPath
					String backPath = ParseFilePath(1,S_path,":",1,0)
					NewPath/O/Q/Z SystemFolderPath,backPath
					
					//Reset the data summary
					Wave/T DataContentsListWave = NTP:DataContentsListWave
					Wave DataContentsSelWave = NTP:DataContentsSelWave
				
					Redimension/N=0 DataContentsListWave,DataContentsSelWave
						
					break
				case "BrowseSystemFolders":
					//Check for previous System Path designation, otherwise reset to 'Documents' folder
					PathInfo SystemFolderPath
					If(!V_flag)
						NewPath/O/Q/Z SystemFolderPath,SpecialDirPath("Documents",0,0,0)
						PathInfo SystemFolderPath
					EndIf
					
					PathInfo/S SystemFolderPath
								
					//Browse for a folder to open
					NewPath/O/Q/Z SystemFolderPath
					
					break
			endswitch
			
			If(!V_flag)
				OpenSystemFolder()
			EndIf

			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function AddDataButtonProc(ba) : ButtonControl
//Controls the buttons on the data loader interface panel
	STRUCT WMButtonAction &ba
	
	DFREF NTP = $CW
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			Wave/T DataListWave = NTP:SystemFilesListWave
			Wave DataSelWave = NTP:SystemFilesSelWave
			
			Variable i,selRow = -1
			For(i=0;i<DimSize(DataSelWave,0);i+=1)
				If(DataSelWave[i] > 0)
					selRow = i
					break
				EndIf
			EndFor
			
			If(selRow == -1)
				return 0
			EndIf
			
			String DataFile = DataListWave[selRow]
			
			
			Wave/T DataContentsListWave = NTP:DataContentsListWave
			Wave DataContentsSelWave = NTP:DataContentsSelWave
					
			Wave/T AddDataList = NTP:IncludedDataListWave
			Wave AddDataSelWave =  NTP:IncludedDataSelWave
			
			strswitch(ba.ctrlName)
				case "AddData":
					PathInfo SystemFolderPath
					
					String dataList = ""
					
					For(i=0;i<DimSize(DataContentsListWave,0);i+=1)
						If(DataContentsSelWave[i] > 0)
							
							Variable newSize = DimSize(AddDataList,0) + 1
							Redimension/N=(newSize,6) AddDataList
							Redimension/N=(newSize) AddDataSelWave
							
							Variable whichRow = DimSize(AddDataList,0)-1
							
							//Check if it's a pClamp file, in which case we must take the corresponding file path for each individual file
							If(stringmatch(DataContentsListWave[i][4],"*pClamp*"))
								AddDataList[whichRow][0] = S_path + DataListWave[i]
							Else
								AddDataList[whichRow][0] = S_path + DataFile
							EndIf
							AddDataList[whichRow][1,*] = DataContentsListWave[i][q-1]
						EndIf	
					EndFor
					
					
					break
			endswitch
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function RemoveDataButtonProc(ba) : ButtonControl
//Controls the buttons on the data loader interface panel
	STRUCT WMButtonAction &ba
	
	DFREF NTP = $CW
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			Wave/T IncludedDataListWave = NTP:IncludedDataListWave
			Wave IncludedDataSelWave = NTP:IncludedDataSelWave
			
			
			Variable i,selRow = -1
			For(i=DimSize(IncludedDataSelWave,0)-1;i>-1;i-=1) //count backwards
				If(IncludedDataSelWave[i] > 0)
					DeletePoints/M=0 i,1,IncludedDataSelWave,IncludedDataListWave
				EndIf
			EndFor

			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function CustomizeButtonProc(ba) : ButtonControl
//Controls the button for customizing the wave names for the included data
	STRUCT WMButtonAction &ba
	
	DFREF NTP = $CW
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			
			//Create a new data table for the loader
			String dsName = NewDataTable()
			
			If(!strlen(dsName))
				DoAlert/T="Customize Wave Names" 0,"Can't overwrite a data set! Use a different name"
				return 0
			EndIf
			
			//data that is to be imported into the data table			
			Wave/T AddDataList = NTP:IncludedDataListWave
			
			//Get the data table wave
			Wave/T archive = GetDataSetWave(dsName,"ARCHIVE")
			
			Variable i,j,nRows = DimSize(AddDataList,0)
			Redimension/N=(nRows,-1) archive
			
			For(i=0;i<nRows;i+=1)
				String path = AddDataList[i][0]
				String series = AddDataList[i][1]
				String protocol = AddDataList[i][2]
				String sweeps = AddDataList[i][3]
				
				strswitch(AddDataList[i][4])
					case "VC":
						String unit = "Im"
						break
					case "CC":
						unit = "Vm"
						break
				endswitch
			
				
				//Default naming
				strswitch(AddDataList[i][4])
					case "VC":
						archive[i][%Pos_0] = "Im"
						break
					case "CC":
						archive[i][%Pos_0] = "Vm"
						break
				endswitch

				archive[i][%Pos_1] = "1"
				archive[i][%Pos_2] = series
				archive[i][%Pos_3] = sweeps
				archive[i][%Pos_4] = "1"
				
				String fileType = AddDataList[i][5]	
				
				archive[i][%Path] = path
				archive[i][%Trials] = series
				archive[i][%Traces] = sweeps
				archive[i][%Comment] = protocol
				archive[i][%Type] = fileType
				
				Variable skipCollapse = 0
				If(!cmpstr(archive[i][%Type],"pClamp"))
					skipCollapse = 1
					
					String channels = pClamp_GetChannelIndices(path)
					archive[i][%Channels] = channels
					
					archive[i][%Pos_4] = channels
				EndIf
				
				ModifyTable showParts=2^0 + 2^2 + 2^3 + 2^4 + 2^5 + 2^6 + 2^7 
			EndFor
			
			
			//Check for any possible rows that can be collapsed into a range in a single row
			If(!skipCollapse)
				String commonList = ""
				String commonListIndex = ""
				String doneList = ""
				String refIndexList = ""
				
				For(i=0;i<nRows;i+=1)
					If(WhichListItem(num2str(i),doneList,";") != -1)
						continue
					EndIf
					
					String refPath = archive[i][%Path]
					String refTraces = archive[i][%Traces]
					String refComment = archive[i][%Comment]
					
					commonList += archive[i][%Trials] + ","
					commonListIndex += num2str(i) + ","
					
					For(j=i+1;j<nRows;j+=1)
						If(!cmpstr(refPath,archive[j][%Path]) && !cmpstr(refTraces,archive[j][%Traces]) && !cmpstr(refComment,archive[j][%Comment]))
							commonList += archive[j][%Trials] + ","
							commonListIndex += num2str(j) + ","
							doneList += num2str(j) + ";"
						EndIf
					EndFor
					
					commonList = RemoveEnding(commonList,",") + ";"
					commonListIndex += RemoveEnding(commonListIndex,",") + ";"
				EndFor
				
				nRows = ItemsInList(commonList,";")
				For(i=0;i<nRows;i+=1)
					String list = StringFromList(i,commonList,";")
					String listIndex = StringFromList(i,commonListIndex,";")
					
					refIndexList += StringFromList(0,listIndex,",") + ";"
					
					Variable refIndex = str2num(StringFromList(0,listIndex,","))
					archive[refIndex][%Trials] = ListToRange(list,",")
					archive[refIndex][%Pos_2] = archive[refIndex][%Trials]
				EndFor
				
				//delete all rows not included in the ranges
				For(i=DimSize(archive,0)-1;i>-1;i-=1)
					If(WhichListItem(num2str(i),refIndexList,";") == -1)
						DeletePoints/M=0 i,1,archive
					EndIf
				EndFor
			EndIf			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End