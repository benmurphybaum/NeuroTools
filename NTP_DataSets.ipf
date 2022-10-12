#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//Handles all of the Data Set organization code

//Puts the data set names that already exist into the dataSetNames list wave
Function/S GetDataSetNames()
	DFREF NPD = $DSF
	
	Wave/T dataSetNames = NPD:dataSetNames
	String dataSets,cdf
	Variable numDataSets,i
	
	cdf = GetDataFolder(1)
	SetDataFolder NPD
	
	dataSets = WaveList("DS_*",";","TEXT:1")
	numDataSets = ItemsInList(dataSets,";")
	Redimension/N=(numDataSets) dataSetNames

	
	For(i=0;i<numDataSets;i+=1)
		dataSetNames[i] = RemoveListItem(0,StringFromList(i,dataSets,";"),"_")	//also removes the DS from the front for display purposes
	EndFor
	
	SetDataFolder $cdf
End

//Sends the named data set to the wave match list box and reselects the original folder selection to define it, as well as all matching paramaters
Function SendToWaveMatch(dsName)
	String dsName
	
	DFREF NPD = $DSF
	DFREF NPC = $CW
	
	SVAR listFocus = NPC:listFocus
	Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
	Variable index = GetDSIndex(dataset=dsName)
	
	If(index != -1)
		//Save the current filters/grouping settings
		If(!cmpstr(listFocus,"DataSet"))
			saveFilterSettings("DataSet")
		EndIf
					
		//Puts the saved filter settings into the GUI controls
		recallFilterSettings("DataSet")

		//Change focus to the WaveMatch list, without doing a save/retrieve
		changeFocus("WaveMatch",0)
		
		//Select the old folders
		SelectFolder(DSNamesLB_ListWave[index][0][2])
		
		//Put the original filter settings into the control panel
		RecallOriginalFilters(DSNamesLB_ListWave[index][0][1])
		
		//With focus on the WaveMatch list, re-run the match/filter/group
		getWaveMatchList()
		
	EndIf
End

//Creates or overwrites the 'Output' data set that contains all the output waves created by running a function
Function CreateOutputDataSet(ds)
	STRUCT ds &ds
	
	DFREF NPD = $DSF
	DFREF NPC = $CW
	
	NewDataTable(isOutputDS = 1)
	
	String dsName = "Output"
	Wave/T archive = GetDataSetWave(dsName,"Archive")
	
//	Size of the data set
	Variable numWaves = DimSize(ds.output,0)
	
	Redimension/N=(numWaves,-1) archive
	
	Variable i,j,igorPathCol = FindDimLabel(archive,1,"IgorPath")
	
	For(i=0;i<numWaves;i+=1)
		archive[i][igorPathCol] = GetWavesDataFolder(ds.output[i],1) //path to the wave
		String name = NameOfWave(ds.output[i])
		
		For(j=0;j<ItemsInList(name,"_");j+=1)
			archive[i][j] = StringFromList(j,name,"_")
		EndFor
	EndFor
	
	//Check that the data set name/sel waves are the same size
	
	//updates the base/org data set waves with the archive contents
	transferArchivedDataSet(dsName)
	
	//Empty filters for the output data set
	Variable index = GetDSIndex(dataset=dsName)
	String filterSettingStr = ";;;;;;;;;;;;;;;;;;"
	
	Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
	DSNamesLB_ListWave[index][0][1] = filterSettingStr
	
//	SetDSGroup(group="All")
//	Wave DSGroupContentsSelWave = NPD:DSGroupContentsSelWave
//	DSGroupContentsSelWave = 0
//	DSGroupContentsSelWave[index] = 1
//	ListBox DSGroupContents win=NTP#Data,selRow = index
//	changeDataSet(dsName)
//	
//	//Data Set Names list box Selection and List waves
//	Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
//	Wave DSNamesLB_SelWave = NPD:DSNamesLB_SelWave
//	
//	//BASE data set - not organized, and no wave set labels
//	Make/T/O/N=(numWaves,1,2) NPD:$dsWaveName 
//	Wave/T DS_BASE = NPD:$dsWaveName
//	
//	//ORGANIZED data set - contains wave set labels
//	Make/T/O/N=(numWaves,1,2) NPD:$(dsWaveName + "_org") 
//	Wave/T DS_ORG = NPD:$(dsWaveName + "_org")
//	
//	//ARCHIVED data set - contains wave set labels
//	Make/T/O/N=(numWaves,1,2) NPD:$(dsWaveName + "_archive") 
//	Wave/T DS_ARCHIVE = NPD:$(dsWaveName + "_archive")
//	
//	Variable i
//	For(i=0;i<numWaves;i+=1)
//		DS_BASE[i][0] = NameOfWave(ds.output[i]) //wave names, no path
//		DS_BASE[i][1] = GetWavesDataFolder(ds.output[i],2) //full path
//	EndFor
//	
//	matchContents(DS_BASE,DS_ORG)
//	
//	AddToDSGroup(dataset=dsName,group="All")
	
End

//Adds a new data set from the waves in the Wave Match list box.
Function addDataSet(dsName)
	String dsName
	STRUCT filters filters
	
	DFREF NPD = $DSF
	DFREF NPC = $CW
	Variable errorCode = 0
	
	SVAR notificationEntry = NPC:notificationEntry
	
	SVAR folderSelection =  NPC:folderSelection
	
	//Data Set Names list box Selection and List waves
	Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
	Wave DSNamesLB_SelWave = NPD:DSNamesLB_SelWave
	
	//Waves in the Wave Match list box
	Wave/T MatchLB_ListWave = NPC:MatchLB_ListWave
	Variable numWaves = DimSize(MatchLB_ListWave,0)
	
	//Base set of waves in the Wave Match list box (no groupings)
	Wave/T MatchLB_ListWave_BASE = NPC:MatchLB_ListWave_BASE 
	
	//Test if the data set name already exists
	//If it does, delete the data set first before making a new one
	Variable index = tableMatch(dsName,DSNamesLB_ListWave)
	If(index != -1)
		//Can't overwrite data set using AddDataSet button
		//Must update data set instead
		return 0
	EndIf
	
	
	//Make the waves that will hold the data set and potential organized versions of the data set
	String dsWaveName = "DS_" + dsName //this will be the base name of the data set waves
	
	//Two copies of the data set will be made.
	
	//1) BASE copy, which is the original. 
		//We can always return to the base copy after filtering and grouping
	//2) ORGANIZED copy, which contains all filtering and grouping manipulations, and wave set labels
		//This copy is displayed in the list boxes.
	
	//Uses 3D list waves so the first layer is the wave names
	//and the second layer holds the full paths.
	
	//BASE data set - not organized, and no wave set labels
	Make/T/O/N=(numWaves,1,2) NPD:$dsWaveName 
	Wave/T DS_BASE = NPD:$dsWaveName
	
	//ORGANIZED data set - contains wave set labels
	Make/T/O/N=(numWaves,1,2) NPD:$(dsWaveName + "_org") 
	Wave/T DS_ORG = NPD:$(dsWaveName + "_org")
	
	//Fill the data set from the Wave Match list box
	matchContents(MatchLB_ListWave_BASE,DS_BASE)
	matchContents(MatchLB_ListWave,DS_ORG)
	
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
	String notesName = ReplaceString(" ",dsName,"_") //collapse the name to no spaces, otherwise error in string creation
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
	
	//Make sure the all group is visible after data set creation
	ControlInfo/W=NTP#Data HideAllGroup

	If(V_Value)
		CheckBox HideAllGroup win=NTP#Data,value=0
		STRUCT WMCheckboxAction cba //rebuild the data group waves accordingly
		cba.checked = 0
		cba.eventCode = 2
		cba.ctrlName = "HideAllGroup"
		NTPCheckProc(cba) //trigger the checkbox code
	EndIf
		
	SetDSGroup(group="All",dataset=dsName)
	
	//Switch focus to the DataSet list box
	changeFocus("DataSet",1)
	
	notificationEntry = "New Data Set: \f01" + dsName
	SendNotification()
	return errorCode
End

//Makes a duplicate data set with a new name
Function DuplicateDataSet(newDSName,oldDSName)
	String newDSName,oldDSName
	
	DFREF NPD = $DSF
	DFREF NPC = $CW
	
	CheckDSGroupLists()
	
	Variable index = GetDSIndex(dataset=oldDSName)
	If(index == -1)
		return 0
	EndIf
	
	//Data Set Names list box Selection and List waves
	Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
	Wave DSNamesLB_SelWave = NPD:DSNamesLB_SelWave
	
	Wave/T/Z BASE = NPD:$("DS_" + oldDSName)
	Wave/T/Z ORG = NPD:$("DS_" + oldDSName + "_org")
	
	If(WaveExists(BASE) && WaveExists(ORG))
		Duplicate/O BASE,NPD:$("DS_" + newDSName)
		Duplicate/O ORG,NPD:$("DS_" + newDSName + "_org")
	Else
		return 0
	EndIf
		
	If(isArchive(oldDSName))
		Wave/T/Z archive = NPD:$("DS_" + oldDSName + "_archive")
		Duplicate/O archive,NPD:$("DS_" + newDSName + "_archive")
	EndIf
	
	SVAR notes = NPD:$("DS_" + oldDSName + "_notes")
	
	If(SVAR_Exists(notes))
		String notesName = ReplaceString(" ",newDSName,"_") //collapse the name to no spaces, otherwise error in string creation
		
		String/G NPD:$("DS_" + notesName + "_notes")
		SVAR newNotes = NPD:$("DS_" + notesName + "_notes")
		
		newNotes = notes
	EndIf
	
	Variable rows = DimSize(DSNamesLB_ListWave,0)
	Redimension/N=(rows + 1,-1,-1) DSNamesLB_ListWave,DSNamesLB_SelWave
	
	DSNamesLB_ListWave[rows][0][] = DSNamesLB_ListWave[index][0][r]
	DSNamesLB_ListWave[rows][0][0] = newDSName
	DSNamesLB_SelWave = 0
	DSNamesLB_SelWave[rows] = 1
	
	//add Data Set name to a string list for the Parameters panel list box
	updateDSNameList()
	
	//display the full path to the wave in a text box
	drawFullPathText()

	
	//Add the new data set to the All group
	AddToDSGroup(dataset=newDSName,group="All")
	
	//How many data sets are defined?
	If(DimSize(DSNamesLB_ListWave,0) > 0)
		DrawAction/W=NTP#Func getgroup=dataSetGroupText,delete
		CloseDSGroupForm() //first close a potentially already open form
		SetupDSGroupForm(newDSName) //reopen the form with the new data set
	EndIf
	
	SetDSGroup(group="All",dataset=newDSName)
	
	//Switch focus to the DataSet list box
	changeFocus("DataSet",1)
	
	String notificationEntry = "Duplicated Data Set: \f01" + oldDSName + " \f00 to \f01 " + newDSName
	SendNotification()
End

//Updates the selected data set with the contents of the Wave Match listbox
Function updateDataSet(dsName)
	String dsName
	STRUCT filters filters
	
	//Initialize the filter structure with SVARs
	SetFilterStructure(filters,"DataSet")
	
	DFREF NPD = $DSF
	DFREF NPC = $CW
	
	SVAR notificationEntry = NPC:notificationEntry
	
	Variable errorCode = 0
	
	//Data Set Wave Lists
	Wave/T DataSetLB_ListWave = NPD:DataSetLB_ListWave
	Wave DataSetLB_SelWave = NPD:DataSetLB_SelWave
	
	//WaveMatch list waves
	Wave/T MatchLB_ListWave = NPC:MatchLB_ListWave
	
	//Base set of waves in the Wave Match list box (no groupings)
	Wave/T MatchLB_ListWave_BASE = NPC:MatchLB_ListWave_BASE 
	
	//BASE data set
	Wave/T DS_BASE = NPD:$("DS_" + dsName)
	
	//ORGANIZED data set - contains wave set labels
	Wave/T DS_ORG = NPD:$("DS_" + dsName + "_org")
	
	//Migrate the WaveMatch waves into the organized data set wave
	matchContents(MatchLB_ListWave_BASE,DS_BASE)
	matchContents(MatchLB_ListWave,DS_ORG)
	
	//Migrate the WaveMatch waves into the data set list box
	//This will allow us to remove filters to create the BASE data set,
	//without disrupting the ORGANIZED data set wave we just updated
	matchContents(MatchLB_ListWave,DataSetLB_ListWave)
	Redimension/N=(DimSize(DataSetLB_ListWave,0)) DataSetLB_SelWave
	DataSetLB_SelWave = 0
	
	//Save the folder selection that went into building this data set
	Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
	SVAR folderSelection = NPC:folderSelection
	Variable index = GetDSIndex()
	If(index != -1)
		DSNamesLB_ListWave[index][0][2] = folderSelection
	EndIf
	
	//Switch focus to data sets
	changeFocus("DataSet",0)

	//Migrate the current filter settings from the WaveMatch list box to the data set
	//Because of clearFilters, the ORG data set will have no filtering, but it will retain grouping
	String filterSettingStr = migrateFilterSettings(dsName)
	
	notificationEntry = "Updated \f01" + dsName 
	sendNotification()
	
	return errorCode
End

//Creates a new data archive
//Creates an empty DataSet_load, returns it's name
Function/S NewDataTable([isOutputDS,dsName])
	Variable isOutputDS
	String dsName
	
	If(ParamIsDefault(dsName))
		dsName = ""
	EndIf
	
	isOutputDS = ParamIsDefault(isOutputDS) ? 0 : 1
	
	DFREF NPD = $DSF
	DFREF NPC = $CW
	
	If(isOutputDS)
		dsName = "Output"
	Else
		If(ParamIsDefault(dsName) || !strlen(dsName))
			Do
				dsName = ""
				Prompt dsName,"Name of Data Table:"
				DoPrompt "New Data Table",dsName
				
				If(!cmpstr(dsName,"Output"))
					DoAlert/T="Add Data Set" 0, "The data set name 'Output' is reserved."
					Variable reservedName = 1
				Else
					reservedName = 0
				EndIf
			While(reservedName)
			
			//cancelled
			If(V_flag)
				return ""
			EndIf
		EndIf
	EndIf

	addDataSet(dsName)
	
	//Is the data set already archived? Returns if it does
	Wave/Z/T archiveBASE = NPD:$("DS_" + dsName + "_archive")
	
	If(WaveExists(archiveBASE))
		return ""
	EndIf 
	
	//Set the column dimension labels
	String colLabels = "Path;IgorPath;Pos_0;Pos_1;Pos_2;Pos_3;Pos_4;Pos_5;Pos_6;Pos_7;Pos_8;Pos_9;Trials;Traces;Channels;Comment;Type;Marker;"
	
	//This will be a table based on underscore position, with up to 10 positions. Right now filtering only supports 7 though.
	Make/O/T/N=(1,ItemsInList(colLabels,";")) NPD:$("DS_" + dsName + "_archive")/Wave=archiveBASE
	
	Variable i
	
	For(i=0;i<ItemsInList(colLabels,";");i+=1)
		SetDimLabel 1,i,$StringFromList(i,colLabels,";"),archiveBASE
	EndFor
	
	If(!isOutputDS)
		openArchive(dsName)
	EndIf
	
	return dsName
End

//Returns list of the data archives, can be _load or _archive
Function/S GetDataArchives(type)
	String type
	
	strswitch(type)
		case "Load":
//			String suffix = "_load"
			String suffix = "_archive"
			break
		case "Archive":
			suffix = "_archive"
			break
	endswitch
	
	DFREF NPD = $DSF
	
	DFREF saveDF = GetDataFolderDFR()
	
	SetDataFolder NPD
	
	String archiveList = WaveList("*" + suffix,";","TEXT:1")

	SetDataFolder saveDF
	
	Variable i
	For(i=0;i<ItemsInList(archiveList,";");i+=1)
		String item = StringFromList(i,archiveList,";")
		item = ReplaceString("DS_",item,"")
		item = ReplaceString("_load",item,"")
		item = ReplaceString("_archive",item,"")
		
		archiveList = ReplaceListItem(i,archiveList,";",item)
	EndFor

	return archiveList
End

//Archives the data set. This will take the current base data set, and organize it into a table, so the user can open the table...
//and manually add wave definitions to the table as a way to expand the data set. This is how WAVEPROC does it, and seems to be...
//a potentially better solution for long term data set use and expansion.
Function archiveDataSet(dataset,doCollapse,obeyGroupings)
	String dataset
	Variable doCollapse
	Variable obeyGroupings
	
	If(doCollapse == 3)
		//cancelled
		return 0
	EndIf
	
	If(!strlen(dataset))
		return 0
	EndIf
	
	DFREF NPD = $DSF
	DFREF NPC = $CW
	
		
	//Is the data set already archived? Returns if it does
	Wave/Z/T archiveBASE = NPD:$("DS_" + dataset + "_archive")
	
	If(WaveExists(archiveBASE))
		return 0
	EndIf 
	
	//Get the current data set BASE and ORG sets
	Wave/T BASE = NPD:$("DS_" + dataset)
	Wave/T ORG = NPD:$("DS_" + dataset + "_org")
	
	If(!WaveExists(BASE) || !WaveExists(ORG))
		DoAlert 0,"Couldn't locate the data set for archiving"
		return 0
	EndIf
	
	If(obeyGroupings == 2) //no clicked
		Variable numWaveSets = GetNumWaveSets(ORG)
		Duplicate/FREE/T ORG,temp //make a working copy of the BASE data set
	Else
		numWaveSets = 1
		Duplicate/FREE/T BASE,temp //make a working copy of the BASE data set
	EndIf
	
	//Make the archived BASE and ORG tables
	
	
	
	//Set the column dimension labels
	String colLabels = "Path;IgorPath;Pos_0;Pos_1;Pos_2;Pos_3;Pos_4;Pos_5;Pos_6;Pos_7;Pos_8;Pos_9;Trials;Traces;Channels;Comment;Type;Marker;"
	
	
	//This will be a table based on underscore position, with up to 10 positions. Right now filtering only supports 7 though.
	Make/O/T/N=(0,ItemsInList(colLabels,";")) NPD:$("DS_" + dataset + "_archive")/Wave=archiveBASE
	
	Variable i,j,k
	
	For(i=0;i<ItemsInList(colLabels,";");i+=1)
		SetDimLabel 1,i,$StringFromList(i,colLabels,";"),archiveBASE
	EndFor
	
	Variable currentRow = 0
	Variable m
	
	//Single row for each folder.
	
	//Get the folders that the data set waves are in
	Variable index = GetDSIndex(dataset=dataset)
	If(index == -1)
		DoAlert 0,"Couldn't find the data set in the list wave"
		return 0
	EndIf
	
	Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
	String relFolder = DSNamesLB_ListWave[index][0][1]
	relFolder = StringFromList(2,relFolder,";") //any relative folder input?
	
	If(strlen(relFolder))
		relFolder = RemoveEnding(relFolder,":") + ":"
	EndIf
	
	String folderList = DSNamesLB_ListWave[index][0][2]
	
	If(!strlen(folderList))
		folderList = "root" //if nothing was selected, the waves must be in root:
	EndIf
	
	Variable numFolders = ItemsInList(folderList,";")
	
	For(i=0;i<numFolders;i+=1)
		//If the base data set is empty, this is an empty data set being archived, so keep a single row available so dimension
		//labels are shown
		If(i == 0 && DimSize(BASE,0) == 0)
			Redimension/N=(1,-1) archiveBASE
		EndIf
		
		String folder = RemoveEnding(StringFromList(i,folderList,";"),":") + ":" + relFolder
			
//		//the wave set. If not obeying groupings, this will be all the waves in the data set
//		Wave/T tempWS = GetWaveSet(temp,i)

		//Get the waves in each folder in sequence
		Wave/T list = GetWavesFromFolder(temp,folder) 
		
	
		If(doCollapse == 1)
			//if collapsing is set, we only add a single row for each folder
			Redimension/N=(DimSize(archiveBASE,0) + 1,-1,-1) archiveBASE
			
			For(j=0;j<10;j+=1)
				//loop through underscore positions
				String valueList = RemoveEnding(ValuesPerUnderscore(j,list),",")
				
				archiveBASE[i][j] = valueList
			EndFor
		
			archiveBASE[i][FindDImLabel(archiveBASE,1,"Comment")] = "" //comment
			archiveBASE[i][FindDImLabel(archiveBASE,1,"IgorPath")] = folder //igor path
			
		ElseIf(doCollapse == 2)
			
			Redimension/N=(DimSize(archiveBASE,0) + DimSize(list,0),-1,-1) archiveBASE
				
			For(j=0;j<DimSize(list,0);j+=1)
				String name = list[j][0][0]
				
				
				For(k=0;k<10;k+=1)
					archiveBASE[currentRow + j][k] = StringFromList(k,name,"_")
				EndFor
				
				archiveBASE[currentRow + j][FindDImLabel(archiveBASE,1,"Comment")] = "" //comment
				archiveBASE[currentRow + j][FindDImLabel(archiveBASE,1,"IgorPath")] = folder
		
			EndFor
			
			currentRow += DimSize(list,0) - 1
		EndIf
		
		currentRow += 1		
	EndFor
End



Function/S ValuesPerUnderscore(pos,list)
	Variable pos
	Wave/T list
	
	String valueList = ""
	
	Variable i
	For(i=0;i<DimSize(list,0);i+=1)
		
		String substr = RemoveEnding(StringFromList(pos,list[i],"_"),"_")
		
		If(!strlen(substr))
			continue
		EndIf
		
		If(!strlen(ListMatch(valueList,substr,",")))
			valueList += substr + ","
		EndIf
	EndFor
	
	return valueList
End

//returns a list wave of all waves that match the underscore position indicated
Function/WAVE GetWavesInGroup(match,list,pos) 
	String match
	Wave/T list
	Variable pos
	
	Duplicate/FREE/T list,outlist
	
	Variable i,count = 0
	For(i=0;i<DimSize(list,0);i+=1)
		String subStr = StringFromList(pos,list[i][0][0],"_")
		
		If(!cmpstr(subStr,match))
			outlist[count][0][] = list[i][0][r]
			count += 1
		EndIf
	EndFor
	
	Redimension/N=(count,-1,-1) outlist
	return outlist
End

//Returns a text wave containing the data set waves in the indicated folder path
Function/WAVE GetWavesFromFolder(BASE,folder)
	Wave/T BASE //Base data set wave or working copy of it
	String folder
	
	Make/FREE/T/N=(DimSize(BASE,0),1,2) list
	
	Variable i,count = 0
	For(i=0;i<DimSize(BASE,0);i+=1)
		String matchFolder = ParseFilePath(1,BASE[i][0][1],":",1,0)
		If(!cmpstr(matchFolder,folder))
			list[count][0][] = BASE[i][0][r] //add the full path if it's in the indicated folder
			count += 1
		EndIf
	EndFor
	
	Redimension/N=(count,1,2) list
	
	return list
End

//Migrate the current filter settings from the WaveMatch list box to the data set
//Filter and grouping options are stored in layer 2 of the DSNamesListWave
Function/S migrateFilterSettings(dsName)
	String dsName
	DFREF NPD = $DSF
	
	//First recall the WaveMatch filter settings
	STRUCT filters filters
	SetFilterStructure(filters,"")

	String filterSettingStr = recallFilterSettings("WaveMatch")
	
	//Clear the filter controls only, but leave the groupings intact
	clearFilterControls(filtersOnly=1)
	
	//Put the control values back into the structure
	SetSearchTerms(filters)
	
	Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
	Variable index = tableMatch(dsName,DSNamesLB_ListWave)
	
	If(index == -1)
		print "Couldn't find the data set name"
		return ""
	EndIf
	
	//returns a list of the current filter settings from the GUI	
//	DSNamesLB_ListWave[index][0][1] = getFilterSettings()
	
	//Remove all values filter values (prefix thru trace)
	Variable i
	For(i=3;i<8;i+=1) 
		filterSettingStr += StringFromList(i,filterSettingStr,";") + ";"
		filterSettingStr = ReplaceListItem(i,filterSettingStr,";","")
	EndFor
	
	DSNamesLB_ListWave[index][0][1] = filterSettingStr
	return DSNamesLB_ListWave[index][0][1]
End

//returns a list of the current filter settings from the GUI
Function/S getFilterSettings()
	STRUCT filters filters
	
	//Get the filter/grouping control values
//	SetSearchTerms(filters)
	SetFilterStructure(filters,"")
	
	String filterSettings = ""
	
	filterSettings += filters.match + ";"
	filterSettings += filters.notMatch + ";"
	filterSettings += filters.relFolder + ";"
	filterSettings += filters.prefix + ";"
	filterSettings += filters.group + ";"
	filterSettings += filters.series + ";"
	filterSettings += filters.sweep + ";"
	filterSettings += filters.trace + ";"
	filterSettings += filters.pos6 + ";"
	filterSettings += filters.pos7 + ";"
	filterSettings += filters.wg + ";"	
	
	return filterSettings
End

//Removes the selected data set
Function deleteDataSet(dsName)
	String dsName
	DFREF NPD = $DSF
	DFREF NPC = $CW
	Variable errorCode = 0
	
	SVAR notificationEntry = NPC:notificationEntry
	SVAR waveSelectorStr = NPC:waveSelectorStr
	
	//Data Set copies to be deleted
	Wave/T BASE = NPD:$("DS_" + dsName)
	Wave/T ORG = NPD:$("DS_" + dsName + "_org")
	SVAR notes = NPD:$("DS_" + dsName + "_notes")
	
	Wave/T archive = NPD:$("DS_" + dsName + "_archive")
	ReallyKillWaves(BASE)
	ReallyKillWaves(ORG)
	
	//Kill any window panels for this archive
	KillWindow/Z $("archivePanel_" + dsName)
	ReallyKillWaves(archive)
	
	KillStrings/Z notes
	
	String delDSName = dsName
	
	//Remove the entry from the listbox
	Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
	Wave DSNamesLB_SelWave = NPD:DSNamesLB_SelWave
	
	Variable index = tableMatch(dsName,DSNamesLB_ListWave)
	
	//Select new data set and delete the old selection from the listbox
//	If(index != -1)
//		DeletePoints/M=0 index,1,DSNamesLB_ListWave,DSNamesLB_SelWave
//	EndIf
	
	//Remove the data set from any groups it is defined in
	Wave/T DSGroupContents = NPD:DSGroupContents
	Wave/T DSGroupContentsListWave = NPD:DSGroupContentsListWave
	Wave/T DSGroupListWave = NPD:DSGroupListWave
	
	
	
	Variable col = 0
	Do
		String group = GetDimLabel(DSGroupContents,1,col)
		
		If(!cmpstr(group,"All"))
			Variable row = tableMatch(dsName,DSGroupContents)
			DSGroupContents[row][0] = ""
			//DSGroupContentsListWave[row] = ""
			DSNamesLB_ListWave[row] = ""
		EndIf
		
		If(strlen(group))
			RemoveFromDSGroup(dataset=dsName,group=group)
		EndIf
		col += 1
	While(col < DimSize(DSGroupContents,1))
	
	
	//Change the displayed data set to the one that now occupies that list position
	If(DimSize(DSNamesLB_ListWave,0) == 0)
		dsName = ""
	ElseIf(index >= DimSize(DSNamesLB_ListWave,0))
		dsName = DSNamesLB_ListWave[index-1][0][0]
		ListBox DataSetNamesListBox win=NTP#Data,selRow=(index-1)
	Else
		dsName = DSNamesLB_ListWave[index][0][0]
		ListBox DataSetNamesListBox win=NTP#Data,selRow=(index)
	EndIf
	
	changeDataSet(dsName)

	//add Data Set name to a string list for the Parameters panel list box
	updateDSNameList()
	
	//Change the selection in the Wave Selector menu if we just deleted the selected data set.
//	If(cmpstr(dsName,waveSelectorStr))
//		switchWaveListSelectorMenu("Wave Match")
//	EndIf
	
	//display the full path to the wave in a text box
	drawFullPathText()
	
	CheckDSGroupLists()
	
	SetDSGroup(group="All")
	
	OpenDSNotesEntry2()
	
	notificationEntry = "Deleted Data Set: \f01" + delDSName
	SendNotification()
	
	return errorCode
End

//Refresh list of Data Set names in a string list for the Parameters panel list box
Function/S updateDSNameList()
	DFREF NPD = $DSF
	
	String cmd = CurrentCommand()
	
	Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
	SVAR DSNames = NPD:DSNames
	
	strswitch(cmd)
		case "Get ROI":
		case "dF Map":
		case "Max Project":
		case "Response Quality":
		case "Adjust Galvo Distortion":
		case "Align Images":
			DSNames = "Image Browser;Wave Match;Navigator;--;"
			break
		default:
			DSNames = "Wave Match;Navigator;--;"
			break
	endswitch
	
	String sets = TextWaveToStringList(DSNamesLB_ListWave,";")
	
	DSNames += sets
	If(strlen(sets))
		DSNames += ";"
	EndIf
	
	return DSNames
End

//Changes the data set list box to display the input data set
Function changeDataSet(dsName)
	String dsName
	
	DFREF NPD = $DSF
	
	Wave/T DataSetLB_ListWave = NPD:DataSetLB_ListWave
	Wave DataSetLB_SelWave = NPD:DataSetLB_SelWave
	
	//Data set names selection and list wave
	Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
	Wave DSNamesLB_SelWave = NPD:DSNamesLB_SelWave
	
	//no input data set - clear the list box
	If(!strlen(dsName))
		Redimension/N=(0) DataSetLB_ListWave,DataSetLB_SelWave
		DrawAction/W=NTP#Data getGroup=DSwaveNumText,delete	
		return 0	
	EndIf
	
	//Data set wave - organized
	Wave/T ds = GetDataSetWave(dsName,"ORG",checkArchive=1)
	
	If(!WaveExists(ds))
		Wave/T BASE = GetDataSetWave(dsName,"BASE")
		
		//Does the base data set exist? If so, duplicate to make a new organized data set wave
		If(WaveExists(BASE))
			Duplicate/T/O BASE,NPD:$("DS_" + dsName + "_org")
			Wave/T ds = GetDataSetWave(dsName,"ORG")
		Else
			DoAlert 0,"Couldn't find the data set: " + dsName
			return 0
		EndIf
	EndIf
	
	//Display the newly selected data set in the Data Set Waves list box
	matchContents(ds,DataSetLB_ListWave)
	Redimension/N=(DimSize(ds,0)) DataSetLB_SelWave
	DataSetLB_SelWave = 0
	
	If(DimSize(DataSetLB_SelWave,0) > 0)
		DataSetLB_SelWave[0] = 1
	EndIf
	
	
	//recall the match/filter/grouping terms for the data set
	recallFilterSettings("DataSet")
	
	//Check data set list validity
	CheckDSGroupLists()
	
	//Check that the contents exist, if not, grey them out
	CheckDataSetWaves()
	
	//display the full path to the wave in a text box
	drawFullPathText()
	
	//Change the DS Notes to the new data set
	OpenDSNotesEntry2(dataset=dsName)
	
						
	Variable numWS_DS = GetNumWaveSets(ds)
	
	Wave/T BASE = GetDataSetWave(dsName,"BASE")
	Variable numWaves_DS = DimSize(BASE,0)
	
	DisplayWaveNums(numWS_DS,numWaves_DS,"DS")
End

//Check that the contents exist, if not, grey them out
Function CheckDataSetWaves([dsName])
	String dsName
	
	If(ParamIsDefault(dsName))
		dsName = GetDSName()
	EndIf
	
	DFREF NPD = $DSF
	DFREF NPC = $CW
	
	//Data set wave - organized
	Wave/T ds = GetDataSetWave(dsName,"ORG")
	Wave/T listWave = NPD:DataSetLB_ListWave
	
	//Wave Match list wave
	Wave/T MatchLB_ListWave = NPC:MatchLB_ListWave
	
	If(WaveExists(ds))
		Variable i
		For(i=0;i<DimSize(ds,0);i+=1)
			String path = ParseFilePath(1,ds[i][0][1],":",1,0)//allows us to manage wave names that have spaces
			String name = ParseFilePath(0,ds[i][0][1],":",1,0)
			If(!stringmatch(ds[i][0][1],"*Wave Set*") && !WaveExists($(path + "'" + name + "'")))
				//red wave name
				listWave[i][0][0] = "\K(65535,0,0)" + ParseFilePath(0,ds[i][0][1],":",1,0)
			Else
				//normal black wave name
				listWave[i][0][0] = ParseFilePath(0,ds[i][0][1],":",1,0)
			EndIf
		EndFor
	EndIf
	
	For(i=0;i<DimSize(MatchLB_ListWave,0);i+=1)
		path = ParseFilePath(1,MatchLB_ListWave[i][0][1],":",1,0) //allows us to manage wave names that have spaces
		name = ParseFilePath(0,MatchLB_ListWave[i][0][1],":",1,0)
		If(!stringmatch(MatchLB_ListWave[i][0][1],"*Wave Set*") && !WaveExists($(path + "'" + name + "'")))
			//red wave name
			MatchLB_ListWave[i][0][0] = "\K(65535,0,0)" + ParseFilePath(0,MatchLB_ListWave[i][0][1],":",1,0)
		Else
			//normal black wave name
			MatchLB_ListWave[i][0][0] = ParseFilePath(0,MatchLB_ListWave[i][0][1],":",1,0)
		EndIf
	EndFor
End

Function/Wave GetDataTableLine(dsName,dti)
	//Returns a wave reference wave containing the waves from a single line on a data table
	String dsName
	Variable dti
	
	Wave/T archive = GetDataSetWave(dsName,"ARCHIVE")
	If(!WaveExists(archive))
		return $""
	EndIf
	
	Variable i,j,k,m,rows
	rows = DimSize(archive,0)
	
	//loop through each row in the archive table
	Make/FREE/N=0/T dtiWaves
	Variable currentRow = 0

	String path = archive[dti][%IgorPath] //full path to the wave
	If(!strlen(path))
		path = "root:"
	EndIf
	
	//loop through each underscore position
	For(j=0;j<10;j+=1)
		String item = archive[dti][%$("Pos_" + num2str(j))]
		
		If(!strlen(item))
			continue
		EndIf
		
		//resolve any list syntax (commas and hyphens)
		String itemList = resolveListItems(item,",")
		
		Variable size = DimSize(dtiWaves,0)
			
		If(size - currentRow > 0)
			Variable expansion = ItemsInList(itemList,",") - 1
				
			//Loop through the rows in the current block and add the underscore positions
			For(k=size - 1;k > currentRow - 1;k-=1) //go backwards
				InsertPoints/M=0 k+1,expansion,dtiWaves
				
				String baseName = dtiWaves[k]
				dtiWaves[k,k + expansion] = baseName
				
				//In the case of a list, add each list item to each row in the block sequence
				For(m=0;m<ItemsInList(itemList,",");m+=1)
					item = StringFromList(m,itemList,",")

					dtiWaves[k + m] += item + "_"
				EndFor
				
			EndFor

		Else
			//resize the BASE data set
			Redimension/N=(currentRow + ItemsInList(itemList,",")) dtiWaves
			For(m=0;m<ItemsInList(itemList,",");m+=1)
				item = StringFromList(m,itemList,",")
				dtiWaves[currentRow + m] = path + item + "_"
			EndFor
		EndIf
	EndFor
	
	If(DimSize(dtiWaves,0) > 0)
		//Remove any extra underscores from the wave names
		dtiWaves = RemoveEnding(dtiWaves[p],"_")
	EndIf
	
	Make/N=(DimSize(dtiWaves,0))/FREE/WAVE refs
	refs = $dtiWaves[p]
	
	return refs
End


//Returns the wave reference to the named data set
Function/Wave GetDataSetWave(dsName,version,[checkArchive])
	//version is either "BASE","ORG",or "ARCHIVE" for the 3 existing copies of the data set
	String dsName,version
	Variable checkArchive //this can be used to perform updates of the ORG data set. Leave at 0 normally to avoid recursion
	
	checkArchive = (ParamIsDefault(checkArchive)) ? 0 : 1
	
	DFREF NPD = $DSF
	
	strswitch(version)
		case "BASE":
			//Test for archive first
			If(checkArchive)
				String dsWaveName = "DS_" + dsName + "_archive" 
				Wave/Z/T ds = NPD:$dsWaveName
				
				If(WaveExists(ds))
					Wave/Z/T ds = transferArchivedDataSet(dsName)
					
					recallFilterSettings("DataSet")
					
					getWaveMatchList()
				
				Else
					dsWaveName = "DS_" + dsName
					Wave/Z/T ds = NPD:$dsWaveName
				EndIf
			Else
				dsWaveName = "DS_" + dsName
				Wave/Z/T ds = NPD:$dsWaveName
			EndIf
			
			break
		case "ORG":
			//CAREFUL WITH RECURSION
			If(checkArchive)
				Wave/Z/T BASE = GetDataSetWave(dsName,"BASE",checkArchive=1)
			EndIf	
			
			dsWaveName = "DS_" + dsName + "_org"
			Wave/Z/T ds = NPD:$dsWaveName
			
			break
		case "Archive":
			dsWaveName = "DS_" + dsName + "_archive" 
			Wave/Z/T ds = NPD:$dsWaveName
			break
		default:
			//empty string input might happen
			return $""
	endswitch
	
	
	If(!WaveExists(ds))	
		return $""
	Else
		return ds
	EndIf

End

//Gets the archived data set and transfers it into the BASE data set with updated waves in case user has added manually to the table
Function/WAVE transferArchivedDataSet(dsName)
	String dsName
	DFREF NPD = $DSF

	Wave/T archive = NPD:$("DS_" + dsName + "_archive")
	
	If(!WaveExists(archive))
		return $""
	EndIf 
	
	Wave/T BASE = NPD:$("DS_" + dsName)
	
	//Make a new base data set if it doesn't exist for some reason		
	If(!WaveExists(BASE))
		Make/N=(0,1,2)/T/O NPD:$("DS_" + dsName)/Wave=BASE
	EndIf 
	
	Redimension/N=(0,1,2) BASE
		
	Variable i,j,k,m,rows = DimSize(archive,0)
	Variable currentRow = 0
	
	//loop through each row in the archive table
	For(i=0;i<rows;i+=1)

		String path = archive[i][%IgorPath] //full path to the wave
		If(!strlen(path))
			path = "root:"
		EndIf
		
		String nameList = ""
		
		currentRow = DimSize(BASE,0)
		
//		If(currentRow > 0)
//			Redimension/N=(currentRow + 1,-1,-1) BASE
//		EndIf
			
		//loop through each underscore position
		For(j=0;j<10;j+=1)
			String item = archive[i][%$("Pos_" + num2str(j))]
			
			If(!strlen(item))
				continue
			EndIf
			
			//resolve any list syntax (commas and hyphens)
			String itemList = resolveListItems(item,",")
			
			Variable size = DimSize(BASE,0)
			
			If(size - currentRow > 0)
				Variable expansion = ItemsInList(itemList,",") - 1
					
				//Loop through the rows in the current block and add the underscore positions
				For(k=size - 1;k > currentRow - 1;k-=1) //go backwards
					InsertPoints/M=0 k+1,expansion,BASE
					
					String baseName = BASE[k][0][1]
					BASE[k,k + expansion][0][1] = baseName
					
					//In the case of a list, add each list item to each row in the block sequence
					For(m=0;m<ItemsInList(itemList,",");m+=1)
						item = StringFromList(m,itemList,",")

						BASE[k + m][0][1] += item + "_"
					EndFor
					
				EndFor

			Else
				//resize the BASE data set
				Redimension/N=(currentRow + ItemsInList(itemList,","),-1,-1) BASE
				For(m=0;m<ItemsInList(itemList,",");m+=1)
					item = StringFromList(m,itemList,",")
					BASE[currentRow + m][0][1] = path + item + "_"
				EndFor
			EndIf

		EndFor
		
		If(DimSize(BASE,0) > 0)
			//Remove any extra underscores from the wave names
			BASE[][0][1] = RemoveEnding(BASE[p][q][r],"_")
		
			//Put wave name in the first layer, keep full path in the second layer
			BASE[][0][0] = ParseFilePath(0,BASE[p][0][1],":",1,0)
		EndIf
	EndFor

	return BASE
End

//Returns the name of the currently selected data set
Function/S GetDSName()
	String dsName = ""
	Variable index = -1
	
	DFREF NPD = $DSF
	Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
	Wave/T DSGroupContentsListWave = NPD:DSGroupContentsListWave
	
	//No data sets yet defined
	If(DimSize(DSGroupContentsListWave,0) == 0)
		return ""
	EndIf
	
	ControlInfo/W=NTP#Data DSGroupContents
	//No selection made
	If(V_Value == -1)
		return ""	
	EndIf
	
	dsName = DSGroupContentsListWave[V_Value]
	return dsName
End

Function CheckDSGroupLists()
	DFREF NPD = $DSF
	DFREF NPC = $CW
	
	Wave/T DSGroupContents = NPD:DSGroupContents
	Wave/T DSGroupListWave =  NPD:DSGroupListWave
	
	Variable size = DimSize(DSGroupContents,1)
	Variable i
	
	
	For(i=size-1;i>-1;i-=1)
		String dsName = GetDimLabel(DSGroupContents,1,i)
		
		If(!strlen(dsName))
			DeletePoints/M=1 i,1,DSGroupContents
		EndIf
	EndFor
	
	size = DimSize(DSGroupListWave,0)
	
	For(i=size-1;i>-1;i-=1)
		Variable whichCol = FindDimLabel(DSGroupContents,1,DSGroupListWave[i])
		
		If(whichCol < 0)
			DeletePoints/M=0 i,1,DSGroupListWave
		EndIf
	EndFor
	
	size = DimSize(DSGroupContents,0)
	For(i=size-1;i>-1;i-=1)
		If(!strlen(DSGroupContents[i][%All])) //'All data group'
			DeletePoints/M=0 i,1,DSGroupContents
			
			If(DimSize(DSGroupContents,0) == 0)
				Redimension/N=(0,1) DSGroupContents
				SetDimLabel 1,0,All,DSGroupContents
			EndIf
		EndIf
	EndFor
	
	//Check the data set names list wave for blanks
	Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
	Wave DSNamesLB_SelWave = NPD:DSNamesLB_SelWave
	size = DimSize(DSNamesLB_ListWave,0)
	
	For(i=size-1;i>-1;i-=1)
		If(!strlen(DSNamesLB_ListWave[i][0][0]))
			DeletePoints/M=0 i,1,DSNamesLB_ListWave,DSNamesLB_SelWave
		EndIf
	EndFor
	
	//Check for consistency between the groups and names wave
	Redimension/N=(DimSize(DSGroupContents,0),-1,-1) DSNamesLB_ListWave,DSNamesLB_SelWave
	
	If(DimSize(DSGroupContents,0) > 0 && DimSize(DSNamesLB_ListWave,0) > 0)
		DSNamesLB_ListWave[][0][0] = DSGroupContents[p][0] //'All' data group gets copied in
	EndIf
End

//Returns the index of the currently selected or indicated data set
Function GetDSIndex([dataset])
	String dataset
	DFREF NPD = $DSF
	
	If(ParamIsDefault(dataset))
		ControlInfo/W=NTP#Data DSGroupContents
		Wave/T listWave = NPD:DSGroupContentsListWave
		
		If(DimSize(listWave,0) == 0)
			return -1
		ElseIf(V_Value > DimSize(listWave,0) - 1)
			return -1
		EndIF
		
		dataset = listWave[V_Value]
	EndIf
	
	Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
	Variable index = tableMatch(dataset,DSNamesLB_ListWave)
	If(DimSize(DSNamesLB_ListWave,0) == 0)
		index = -1
	EndIf
	
	return index
End

//Returns the number of wavesets in the input list
Function GetNumWaveSets(listWave,[dsNum])
	Wave/T listWave
	Variable dsNum
	Variable item = 0,count = 0
	String name = ""
	
	dsNum = (ParamIsDefault(dsNum)) ? 0 : dsNum
	
	If(!WaveExists(listWave))
		return 0
	EndIf
	
	If(DimSize(listWave,0) == 0)
		return 0
	EndIf
	
	Do
		name = listWave[item][dsNum][0]
		If(stringmatch(name,"*WAVE SET*"))
			count += 1 
		EndIf
		item += 1
	While(item < DimSize(listWave,0))
	
	If(count == 0)
		count = 1
	EndIf
	
	return count
End

Function GetNumWaves(listWave,wsn)
	Wave/T listWave
	Variable wsn
	Variable size,i
	
	Variable numDataSets = DimSize(listWave,1)
	
	If(numDataSets == 0)
		numDataSets = 1
	EndIf
	
	For(i=0;i<numDataSets;i+=1)
		Wave/T ws = GetWaveSet(listWave,wsn)
		size = DimSize(ws,0)
	EndFor
	return size
End

//Returns the waves with the indicated wave set index from the listwave
Function/WAVE GetWaveSet(listWave,wsn,[dsNum])
	Wave/T listWave
	Variable wsn
	Variable dsNum
	
	dsNum = (ParamIsDefault(dsNum)) ? 0 : dsNum
	
	Variable i = 0,count = 0
	
	//If listwave is empty or doesn't exist
	If(!WaveExists(listWave))
		return $""
	EndIf
	
	If(DimSize(listWave,0) == 0)
		//empty wave set
		return listWave
	EndIf
	
	//Only 1 wave set
	If(!stringmatch(listWave[0][dsNum][0],"*WAVE SET*") && wsn == 0)
		return listWave
	EndIf
	
	//Get start of the wave set
	
	Variable first = tableMatch("*WAVE SET*" + num2str(wsn) + "*-*",listWave,whichCol=dsNum) + 1
	
	//wave set was not found
	If(first == 0)
		return $""
	EndIf
	
	//Get end of the wave set
	i = first + 1
	
	//If the last data set is empty, this will happen
	If(i > DimSize(listWave,0))
		return $""
	EndIf
	
	Variable last = tableMatch("*WAVE SET*" + num2str(wsn + 1) + "*-*",listWave,whichCol=dsNum)
	
	//couldn't find the end of the wave set,
	//so it must be the last waveset
	If(last == -1)
		last = DimSize(listWave,0)
	EndIf
	
	last -= 1
	
	Make/FREE/T/N=(last-first + 1,1,2) tempWave
	
	//If the last wave set is empty
	If(first > DimSize(listWave,0) - 1)
		return $""
	EndIf
	
	tempWave[][0][0] = listWave[first+p][dsNum][0]	 //names
	tempWave[][0][1] = listWave[first+p][dsNum][1] //full path
	
	return tempWave
End

//Returns a string list of the wave set instead of a wave as in GetWaveSet()
Function/S GetWaveSetList(listWave,wsn,fullPath,[dsNum])
	Wave/T listWave
	Variable wsn
	Variable fullPath //1 for full path, 0 for names only
	Variable dsNum
	
	dsNum = (ParamIsDefault(dsNum)) ? 0 : dsNum
	
	String list = ""
	
	If(!WaveExists(listWave))
		return ""
	EndIf
	
	Wave/T ws = GetWaveSet(listWave,wsn,dsNum=dsNum)
	
	If(!WaveExists(ws))
		return ""
	EndIf
	
	If(DimSize(ws,1) <= 1)
		list = TextWaveToStringList(ws,";",layer=fullPath,col=0)
	Else
		list = TextWaveToStringList(ws,";",layer=fullPath,col=dsNum)
	EndIf
	
	return list
End

//Returns a wave reference wave of the indicated wave set
Function/WAVE GetWaveSetRefs(listWave,wsn,name)
	Wave/T listWave
	Variable wsn
	Wave/T name
	
	DFREF NTD = $DSF
	DFREF NTC = $CW
	
	If(!WaveExists(listWave))
		return $""
	EndIf
	
	//Can have multiple data sets if this is an external function call
	Variable i,numDataSets = DimSize(listWave,1)
	If(numDataSets == 0)
		numDataSets = 1
	EndIf
	
	If(numDataSets == 1)
		Make/WAVE/O/N=1 NTD:ds_waveRefs
	Else
		Make/WAVE/O/N=(1,numDataSets) NTD:ds_waveRefs
	EndIf
	
	Wave/WAVE ds_waveRefs = NTD:ds_waveRefs
	//reset the wave references to empty
	ds_waveRefs = $""
	
//	DebuggerOptions debugOnError=0
	
	For(i=0;i<numDataSets;i+=1)
		Make/FREE/O/T/N=(DimSize(listWave,0),1,2) currentDS
		
		If(!DimSize(currentDS,0))
			Redimension/N=(0,-1) ds_waveRefs
			return ds_waveRefs
		EndIf
		
		currentDS = listWave[p][i][r]
		
		//remove ending white space
		Do
			If(DimSize(currentDS,0) == 0)
				break
			EndIf
			
			If(!strlen(currentDS[DimSize(currentDS,0)-1][0][0]))
				DeletePoints/M=0 DimSize(currentDS,0)-1,1,currentDS
			Else
				break
			EndIf
		While(1)
		
		//current data set
		Variable numWaveSets = GetNumWaveSets(currentDS)
		
		If(wsn < numWaveSets - 1)
			String list = GetWaveSetList(currentDS,wsn,1)
		Else
			//Use the last defined wave set if wsn is greater than number of wave sets
			list = GetWaveSetList(currentDS,numWaveSets - 1,1)
		EndIf
		
		try
			Wave/WAVE refs = ListToWaveRefWave(list);AbortOnRTE
		catch
			Variable error = GetRTError(1)
		endtry
		
		If(DimSize(refs,0) > DimSize(ds_waveRefs,0))
			Redimension/N=(DimSize(refs,0),-1) ds_waveRefs
		EndIf
		
		If(DimSize(refs,0) > 0)
			ds_waveRefs[0,DimSize(refs,0)-1][i] = refs[p][i]
		EndIf
		
		strswitch(name[i])
			case "**Navigator**":
				name[i] = "Navigator"
				break
			case "**Wave Match**":
				name[i] = "Wave Match"
				break
		endswitch
		
		If(DimSize(ds_waveRefs,1) == 0)
			Redimension/N=(-1,1) ds_waveRefs
		EndIf
		
		SetDimLabel 1,i,$name[i],ds_waveRefs
	EndFor

	return ds_waveRefs
End

//Returns 1 if the wave set is empty, 0 otherwise
Function isEmptyWaveSet(listwave,wsn)
	Wave/T listWave
	Variable wsn
	Variable isEmpty
	
	Wave/Z/T ws = GetWaveSet(listWave,wsn)
	
	If(!WaveExists(ws))
		isEmpty = 1
		return isEmpty
	EndIf
	
	If(DimSize(ws,0) == 0)
		isEmpty = 1
		return isEmpty
	EndIf
	
	If(stringmatch(ws[0],"*WAVE SET*"))
		isEmpty = 1
	Else
		isEmpty = 0
	EndIf

	return isEmpty
End

//Deletes the indicated wave set number from the provided list wave
Function DeleteWaveSet(listWave,wsn)
	Wave/T listWave
	Variable wsn
	Variable startIndex,endIndex
	
	startIndex = tableMatch("*WAVE SET*" + num2str(wsn) + "-*",listWave)
	
	//wave set doesn't exist
	If(startIndex == -1)
		//actually there just is no wave set division and this it the 0th wave set
		If(!stringmatch(listWave[0],"*WAVE SET*-*") && wsn == 0)
			startIndex = 0
		Else	
			return -1
		EndIf
	EndIf
	
	
	endIndex = tableMatch("*WAVE SET*" + num2str(wsn+1) + "-*",listWave)
	
	//last wave set
	If(endIndex == -1)
		endIndex = DimSize(listWave,0)
	EndIf
	
	//delete the wave set from the list wave
	DeletePoints/M=0 startIndex,endIndex-startIndex,listWave
	
	//Ensure incremental by 1 order of the WSNs, in case middle wave sets were deleted
	Variable i,count,index
	
	count = 0
	index = -1
	Do
		//find each WSN marker
		index = tableMatch("*WAVE SET*-*",listWave,startP=index+1)
		
		
		If(index != -1)
			//set to incremental order
			String wsSize = StringFromList(1,listWave[index],"(")
			wsSize = RemoveEnding(wsSize,")")
			
			listWave[index] = "----WAVE SET " + num2str(count) + "----(" + wsSize + ")"
			count += 1
		EndIf
	While(index != -1)
	
	return 0
End

//Returns a string list of the specified data group index
Function/S GetDataGroupContentsByIndex(index)
	Variable index
	
	If(index < 0)
		return ""
	EndIf
	
	String list = ""
	
	DFREF NPD = $DSF
	Wave/T DSGroupContents = NPD:DSGroupContents
	
	If(!WaveExists(DSGroupContents))
		return ""
	EndIf
	
	If(index > DimSize(DSGroupContents,1) - 1)
		return "-"
	EndIf
	
	list = textWaveToStringList(DSGroupContents,";",col=index)
	
	return list
	
End


//Returns a string list of the specified data group index
Function/S GetDataGroupNameByIndex(index)
	Variable index
	
	If(index < 0)
		return "-" 
	EndIf
	
	String list = ""
	
	DFREF NPD = $DSF
	Wave/T DSGroupContents = NPD:DSGroupContents
	
	If(!WaveExists(DSGroupContents))
		return "-"
	EndIf
	
	If(index > DimSize(DSGroupContents,1) - 1)
		return "-"
	EndIf
	
	String groupName = GetDimLabel(DSGroupContents,1,index)
	
	If(!strlen(groupName))
		groupName = "-" 
	EndIf
	
	return groupName
	
End

//Returns a string list of the specified data group
Function/S GetDataGroup(group)
	String group
	String list = ""
	
	DFREF NPD = $DSF
	Wave/T DSGroupContents = NPD:DSGroupContents
	
	Variable whichCol = FindDimLabel(DSGroupContents,1,group)
	
	If(whichCol == -1) //couldn't find the group
		return ""
	EndIf
	
	list = textWaveToStringList(DSGroupContents,";",col=whichCol)
	return list
End

//Renames a data group and associated waves
Function RenameDataGroup(newName,oldName)
	String newName,oldName

	DFREF NPD = $DSF

	Wave/T DSGroupListWave =  NPD:DSGroupListWave
	Wave/T DSGroupContents = NPD:DSGroupContents
	Wave/T DSGroupContentsListWave = NPD:DSGroupContentsListWave
	Wave/T DataSetNamesLB_ListWave = NPD:DataSetNamesLB_ListWave
	
	//Can't rename the 'All' data group.
	If(!cmpstr(oldName,"All"))
		return 0
	EndIf
	
	//Modify the contents wave column label, which holds the data set name
	Variable col = FindDimLabel(DSGroupContents,1,oldName)
	If(col == -1)
		return 0
	EndIf
	
	SetDimLabel 1,col,$newName,DSGroupContents
	
	//modify the dsgrouplist wave
	Variable row = tableMatch(oldName,DSGroupListWave)
	
	If(row == -1)
		print "discrepancy between the contents wave and the group list wave"
		return 0 //this would mean there is some discrepancy between the contents wave and the group list wave
	EndIf
	
	DSGroupListWave[row] = newName
	
End


//Renames a data set and associated waves
Function RenameDataSet(newName,oldName)
	String newName,oldName
	
	If(!cmpstr(newName,oldName))
		return 0
	EndIf
	
	DFREF NPD = $DSF

	Wave/T DSGroupContents = NPD:DSGroupContents
	Wave/T DSGroupContentsListWave = NPD:DSGroupContentsListWave
	Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
	
	//Replace all instances of the data set name in the contents wave
	Variable i,row
	For(i=0;i<DimSize(DSGroupContents,1);i+=1)
		row = tableMatch(oldName,DSGroupContents,whichCol=i)
		
		If(row != -1)
			DSGroupContents[row][i] = newName
		EndIf
	EndFor
	
	//Replace the data set name in the data set names wave
	row = tableMatch(oldName,DSNamesLB_ListWave)
	If(row == -1)
		print "discrepancy between the contents wave and the group list wave"
		return 0 //this would mean there is some discrepancy between the contents wave and the group list wave
	EndIf
	
	DSNamesLB_ListWave[row][0][0] = newName
	
	row = tableMatch(oldName,DSGroupContentsListWave)
	
	If(row != -1)
		DSGroupContentsListWave[row] = newName
	EndIf
	
	//Replace BASE and ORGANIZED data set wave names
	Wave/T BASE = NPD:$("DS_" + oldName)
	If(WaveExists(BASE))
		Duplicate/O BASE,NPD:$("DS_" + newName)
	EndIf
	
	Wave/T ORG = NPD:$("DS_" + oldName + "_org")
	If(WaveExists(ORG))
		Duplicate/O ORG,NPD:$("DS_" + newName + "_org")
	EndIf
	
	If(isArchive(oldName))
		Wave/T archive = NPD:$("DS_" + oldName + "_archive")
		Duplicate/O archive,NPD:$("DS_" + newName + "_archive")
	EndIf
	
	//Replace the notes string names
	String oldNotesName = ReplaceString(" ",oldName,"_")
	SVAR DSNotes_Old = NPD:$("DS_" + oldNotesName + "_notes")
	
	String newNotesName = ReplaceString(" ",newName,"_")
	String/G NPD:$("DS_" + newNotesName + "_notes")
	SVAR DSNotes_New = NPD:$("DS_" + newNotesName + "_notes")
	DSNotes_New = DSNotes_Old
	
	KillStrings/Z DSNotes_Old
	KillWaves/Z ORG,BASE,archive
End


Function SetDSGroup([group,dataset])
	String group,dataset
	
	DFREF NPD = $DSF
	
	Wave/T DSGroupListWave =  NPD:DSGroupListWave
	Wave DSGroupSelWave = NPD:DSGroupSelWave
	Wave/T DSGroupContents = NPD:DSGroupContents
	Wave/T DSGroupContentsListWave = NPD:DSGroupContentsListWave
	Wave DSGroupContentsSelWave = NPD:DSGroupContentsSelWave
	
	//selecting rows beyond valid range
	//selected group in the data set group list
	If(ParamIsDefault(group))
		ControlInfo/W=NTP#Data DSGroups
		If(V_Value > -1)
			group = DSGroupListWave[V_Value]
		Else
			return 0
		EndIf
	EndIf
	
	//refresh the contents wave
	
	//Check if the 'All' group is set to visible or hidden
	ControlInfo/W=NTP#Data HideAllGroup
	If(V_Value == 1)
		//'All' group is hidden
		If(!cmpstr(group,"All"))
			//If we're switching to All anyway
			Variable index = FindDimLabel(DSGroupContents,1,group)
		Else
			index = FindDimLabel(DSGroupContents,1,group) - 1
		EndIf
			
		If(index < 0)
			return 0
		EndIf
		
		//Change the group list box to the indicated group
		ListBox DSGroups win=NTP#Data,selRow=index
		
		index += 1 //return index to its normal value as if the 'All' group was visible
	Else
		//'All' group is visible
		index = FindDimLabel(DSGroupContents,1,group)
		
		If(index < 0)
			return 0
		EndIf
		
		//Change the group list box to the indicated group
		ListBox DSGroups win=NTP#Data,selRow=index
	EndIf
	
	
	
	
	Redimension/N=(DimSize(DSGroupContents,0)) DSGroupContentsListWave,DSGroupContentsSelWave
	
	
	If(DimSize(DSGroupContentsListWave,0))
		DSGroupContentsListWave[] = DSGroupContents[p][index]
		
		//Remove and blank cells
		RemoveEmptyCells(DSGroupContentsListWave,0)
		Redimension/N=(DimSize(DSGroupContentsListWave,0)) DSGroupContentsSelWave
	EndIf
	
	ControlInfo/W=NTP#Data DSGroupContents
	If(ParamIsDefault(dataset))
		//Select the first data set in the list
		If(DimSize(DSGroupContentsListWave,0) > 0)
			
			If(V_Value > DimSize(DSGroupContentsListWave,0) - 1)
				Variable whichDataSet = DimSize(DSGroupContentsListWave,0) - 1
			Else
				whichDataSet = V_Value
			EndIf
			
			ListBox DSGroupContents win=NTP#Data,selRow=whichDataSet
			//refresh the data set waves list box
			changeDataSet(DSGroupContentsListWave[whichDataSet])
		EndIf
	Else
		//Select the indicated data set
		index = tableMatch(dataset,DSGroupContentsListWave)
		If(index != -1)
			ListBox DSGroupContents win=NTP#Data,selRow=index
		EndIf
	EndIf	
	
	
	//check if there is a data set selected and adjust the notes text and change the data set displayed
	ControlInfo/W=NTP#Data DSGroupContents
	If(DimSize(DSGroupContentsListWave,0) == 0)
		OpenDSNotesEntry2()
		changeDataSet("") //empty data set
	Else
		dataset = DSGroupContentsListWave[V_Value]
		changeDataSet(dataset) //newly selected data set
		OpenDSNotesEntry2(dataset=dataset)
	EndIf
 	
End

Function DeleteDSGroup([group])
	String group
	
	DFREF NPD = $DSF
	DFREF NPC = $CW
	
	Wave/T DSGroupListWave =  NPD:DSGroupListWave
	Wave DSGroupSelWave =  NPD:DSGroupSelWave
	Wave/T DSGroupContents = NPD:DSGroupContents
	Wave/T DSGroupContentsListWave = NPD:DSGroupContentsListWave
	Wave DSGroupContentsSelWave = NPD:DSGroupContentsSelWave
	
	//selected group in the data set group list
	If(ParamIsDefault(group))
		ControlInfo/W=NTP#Data DSGroups
		If(V_Value > -1)
			group = DSGroupListWave[V_Value]
		Else
			return 0
		EndIf
	EndIf
		
	//can't delete the All data group
	If(!cmpstr(group,"All"))
		return 0
	EndIf
	
	String deletedGroup = group
	
	//get the index of the data set group in the contents wave
	Variable index = FindDimLabel(DSGroupContents,1,group)
	If(index < 0)
		return 0
	EndIf
	
	DeletePoints/M=1 index,1,DSGroupContents
	If(DimSize(DSGroupContents,1) == 0)
		Redimension/N=(-1,1) DSGroupContents
	EndIf
	
	DeletePoints/M=0 V_Value,1,DSGroupListWave,DSGroupSelWave
	
	//Select the first group in the list
	If(DimSize(DSGroupListWave,0) > 0)
		ListBox DSGroups win=NTP#Data,selRow=0
		group = DSGroupListWave[0]
		
		//refresh the contents wave
		index = FindDimLabel(DSGroupContents,1,group)
		
		If(index < 0)
			return 0
		EndIf
		
		Redimension/N=(DimSize(DSGroupContents,0)) DSGroupContentsListWave,DSGroupContentsSelWave
		If(DimSize(DSGroupContentsListWave,0))
			DSGroupContentsListWave[] = DSGroupContents[p][index]
			//Remove and blank cells
		
			RemoveEmptyCells(DSGroupContentsListWave,0)
		EndIf		
		Redimension/N=(DimSize(DSGroupContentsListWave,0)),DSGroupContentsSelWave
	Else
		Redimension/N=0 DSGroupContentsListWave,DSGroupContentsSelWave
	EndIf
	
	SetDSGroup()
	
	String notificationEntry = "Deleted Data Group: \f01" + deletedGroup
	SendNotification()
	
End

Function AddToDSGroup([dataset,group])
	String dataset,group
	
	DFREF NPD = $DSF
	DFREF NPC = $CW
	
	SVAR notificationEntry = NPC:notificationEntry
	
	Wave/T DSGroupListWave =  NPD:DSGroupListWave
	Wave/T DSGroupContents = NPD:DSGroupContents
	Wave/T DSGroupContentsListWave = NPD:DSGroupContentsListWave
	
	//Name of the data set in question
	If(ParamIsDefault(dataset))
		ControlInfo/W=NTP#Data DSGroupContents
		Wave/T listWave = $(S_DataFolder + S_Value)
		If(V_Value > DimSize(listWave,0) - 1)
			return 0
		EndIf
		dataset = listWave[V_Value]
	EndIf
	
	If(!strlen(dataset))
		return 0
	EndIf
	
	//selected group in the data set group list
	If(ParamIsDefault(group))
		ControlInfo/W=NTP#Data DSGroups
		If(V_Value > -1)
			group = DSGroupListWave[V_Value]
		Else
			return 0
		EndIf
	EndIf
	
	If(!strlen(group))
		return 0
	EndIf
		
	//get the index of the data set group in the contents wave
	Variable index = FindDimLabel(DSGroupContents,1,group)
	If(index < 0)
		return 0
	EndIf
	
	//Make sure the data set isn't already in the group
	Variable isMatch = tableMatch(dataset,DSGroupContents,whichCol=index)
	If(isMatch != -1)
		return 0
	EndIf
	
	//add a row to the correct frame of the contents wave
	Variable numDSinGroup = NumDataSetsInGroup(group) + 1
	
//	Variable numDSinGroup = DimSize(DSGroupContentsListWave,0) + 1
	
	If(numDSinGroup > DimSize(DSGroupContents,0))
		Redimension/N=(numDSinGroup,-1) DSGroupContents	
	EndIf
	DSGroupContents[numDSinGroup - 1][index] = dataset
	
//	//add the data set to the group contents list wave
//	Redimension/N=(numDSinGroup) DSGroupContentsListWave
//	DSGroupContentsListWave[numDSinGroup-1] = dataset
	
	notificationEntry = "Added \f01" + dataset + "\f00 to \f01" + group
	SendNotification()
End

//Testing out opening the archive as a list box panel
Function openInteractiveArchive(dataset)
	String dataset
	
	DFREF NPD = $DSF
	Wave/Z/T archive = NPD:$("DS_" + dataset + "_archive")
	
	Make/O/N=(DimSize(archive,0),DimSize(archive,1)) NPD:archiveSelWave/Wave=selWave
	selWave = 0
	
	KillWindow/Z ArchivePanel
	NewPanel/N=ArchivePanel/K=1/W=(0,0,600,300) as "Data Set: " + dataset
	
	ListBox archiveListBox win=ArchivePanel,size={600,300},pos={0,0},mode=10,userColumnResize=1,frame=2,listWave=archive,selWave=selWave,proc=ArchiveListBoxProc
	
	Variable/G NPD:columnClick
	NVAR columnClick = NPD:columnClick
	columnClick = ticks
	
	SetWindow ArchivePanel hook(APResizeHook) = APResizeHook
End

Function APResizeHook(s)
	STRUCT WMWinHookStruct &s

	Variable hookResult = 0
	
	switch(s.eventCode)
		case 0:				// Activate
			// Handle activate
			break

		case 1:				// Deactivate
			// Handle deactivate
			break
		case 6:
			// Resize
			GetWindow kwTopWin wsize
			ListBox archiveListBox win=ArchivePanel,size={V_right - V_left,V_bottom - V_top}
			break
		// And so on . . .
	endswitch

	return hookResult		// 0 if nothing done, else 1
End


Function ArchiveListBoxProc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave
	
	DFREF NPD = $DSF
	NVAR columnClick = NPD:columnClick
	
	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			break
		case 2: // mouse up
			break
		case 3: // double click
			If(row > -1)
				selWave[row][col] = 2^1
				ListBox archiveListBox win=ArchivePanel,setEditCell={row,col,1000,1000}
			EndIf
			break
		case 4: // cell selection
			//Check double click

			break
		case 5: // cell selection plus shift key
			break
		case 6: // begin edit
			break
		case 7: // finish edit
			selWave[row][col] = 0
			break
		case 11: //resize column
			//test double click
			If(ticks - columnClick < 15)
				SetColumnToText(col,listWave,lba.ctrlName)
			EndIf
			
			columnClick = ticks
			break
		case 13: // checkbox clicked (Igor 6.2 or later)
			break
	endswitch

	return 0
End


Function SetColumnToText(col,dataTable,ctrlName)
	Variable col
	Wave/T dataTable
	String ctrlName
	
	ControlInfo/W=ArchivePanel $ctrlName
	String colWidths = S_columnWidths
	Make/N=(ItemsInList(colWidths,","))/FREE colWidthWave
	
	Variable i

	Variable maxLength = strlen(dataTable[0][col])
	For(i=1;i<DimSize(dataTable,0);i+=1)
		maxLength = (strlen(dataTable[i][col]) > maxLength) ? strlen(dataTable[i][col]) : maxLength
	EndFor
	
	For(i=0;i<ItemsInList(colWidths,",");i+=1)
		colWidthWave[i] = str2num(StringFromList(i,colWidths,","))
	EndFor
	
	//Assign 5 pixels per character		
	colWidthWave[col] = limit(maxLength * 7,20,inf)
	
	ListBox archiveListBox win=ArchivePanel,widths={colWidthWave[0],colWidthWave[1],colWidthWave[2],colWidthWave[3],colWidthWave[4],colWidthWave[5], \
	colWidthWave[6],colWidthWave[7],colWidthWave[8],colWidthWave[9],colWidthWave[10],colWidthWave[11],colWidthWave[12],colWidthWave[13], \
	colWidthWave[14],colWidthWave[15],colWidthWave[16]}
End

//opens an archived data set
Function openArchive(dataset)
	String dataset
	DFREF NPD = $DSF
	Wave/Z/T archive = NPD:$("DS_" + dataset + "_archive")
	
	String dataSetTempName = ReplaceString(" ",dataset,"_")
	
	//Check if the archive is already open
	
	Variable i
	String list = WinList("*archive*",";","WIN:64") //look for panels
	For(i=0;i<ItemsInList(list,";");i+=1)
		String table = StringFromList(i,list,";")
//		String name = NameOfWave(WaveRefIndexed(table,i,3))
//		String name = ReplaceString(" Archive",table,"")
		
		If(!cmpstr(table,"archivePanel_" + dataSetTempName))
			DoWindow/F $table
			return 0
		EndIf
//		
//		If(!cmpstr(name,"DS_" + dataset + "_archive"))
//			DoWindow/F $table
//			return 0
//		EndIf
		
	EndFor
	
	GetMouse
	
	//If < Igor 9, open the archive with a panel surrounding it to allow for button controls. Igor 9 uses table hooks instead.
	If(IgorVersion() < 9)
		Variable w = 800
		Variable h = 300
		
		
		String panelName = "archivePanel_" +  dataSetTempName
		NewPanel/K=1/W=(V_left - w/2,V_top - h,V_left + w/2,V_top)/N=$panelName as dataset + " Archive"
	
		Edit/HOST=$panelName/W=(160,0,w + 2000,h + 2000)/N=archive archive as dataset + " Archive"
		ModifyTable/W=$panelName#archive horizontalIndex=2,alignment=1
		
		//Control buttons
		Variable top = 5
		
		String buttonList ="Browse File;Get Wave Names;Insert Row;Fill Selection With Top;Increment From Top;"
		buttonList += "Mark By Folder;Add To Igor Path;Remove Last SubPath;Load Selection;Collapse By Folder;New DS With Selection;Add Rows;First Item Only;"
		For(i=0;i<ItemsInList(buttonList,";");i+=1)
			String name = StringFromList(i,buttonList,";")
			String buttonName = StringFromList(0,name,",")
			
			String ctrlName = "archive_" + ReplaceString(" ",buttonName,"")
			Button $ctrlName win=$panelName,pos={5,top},size={150,20},title=buttonName,proc=archiveButtonProc; top += 25
		EndFor
		
	Else
		Edit/W=(V_left - w/2,V_top - h,V_left + w/2,V_top)/N=archive archive as dataset + " Archive"
		ModifyTable/W=$panelName#archive horizontalIndex=2,alignment=1
	EndIf
	
End

Function archiveButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			strswitch(ba.ctrlName)
				case "archive_BrowseFile":
					Variable nFiles = InsertFilePath()
					
					InsertWaveNames(nFiles = nFiles)
					
					break
				case "archive_GetWaveNames":
					InsertWaveNames()
					break
				case "archive_InsertRow":
					InsertNewRow()
					break
				case "archive_FillSelectionWithTop":
					FillTableSelection()
					break
				case "archive_IncrementFromTop":
					IncrementFromTop()
					break
				case "archive_MarkByFolder":
					MarkByFolder()
					break
				case "archive_AddToIgorPath":
					AddToIgorPath()
					break
				case "archive_RemoveLastSubPath":
					RemoveLastSubPath()
					break
				case "archive_LoadSelection":
					LoadDataTableSelection()
					break
				case "archive_CollapseByFolder":
					CollapseByFolder()
					break
				case "archive_NewDSWithSelection":
					NewDataSetWithSelection()
					break
				case "archive_AddRows":
					AddRowsToDataTable()
					break
				case "archive_FirstItemOnly":
					CollapseToFirstItem()
					break
			endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


//Is the named data set archived?
Function isArchive(dataset)
	String dataset
	
	DFREF NPD = $DSF
	Wave/Z/T archive = NPD:$("DS_" + dataset + "_archive")
	
	return WaveExists(archive)	
End

Function NumDataSetsInGroup(group)
	String group
	
	DFREF NPD = $DSF
	
	Wave/T DSGroupContents = NPD:DSGroupContents
	
	Variable col = FindDimLabel(DSGroupContents,1,group)
	
	If(col == -1)
		return 0
	EndIf
	
	Variable numDS = 0
	
	Variable i,size = DimSize(DSGroupContents,0)
	For(i=0;i<size;i+=1)
		If(strlen(DSGroupContents[i][col]))
			numDS += 1
		Else
			break
		EndIf
	EndFor
	
	return numDS
End

Function RemoveFromDSGroup([dataset,group])
	String dataset,group
	
	DFREF NPD = $DSF
	DFREF NPC = $CW
	
	SVAR notificationEntry = NPC:notificationEntry
	
	Wave/T DSGroupListWave =  NPD:DSGroupListWave
	Wave/T DSGroupContents = NPD:DSGroupContents
	Wave/T DSGroupContentsListWave = NPD:DSGroupContentsListWave
	Wave DSGroupContentsSelWave = NPD:DSGroupContentsSelWave
	
	//selected data set in the list
	If(ParamIsDefault(dataset))
		ControlInfo/W=NTP#Data DSGroupContents
		If(V_Value > -1)
			dataset = DSGroupContentsListWave[V_Value]
		Else
			return 0
		EndIf
	EndIf
			
	//selected group in the data set group list
	If(ParamIsDefault(group))	
		ControlInfo/W=NTP#Data DSGroups
		If(V_Value > -1)
			group = DSGroupListWave[V_Value]
		Else
			return 0
		EndIf
	EndIf
	
	//Can't remove from the All data group
	If(!cmpstr(group,"All"))
		return 0
	EndIf
			
	//get the index of the data set group in the contents wave
	Variable index = FindDimLabel(DSGroupContents,1,group)
	If(index < 0)
		return 0
	EndIf

	//get the index of the data set group in the contents wave
	Variable dsIndex = tableMatch(dataset,DSGroupContents,whichCol=index)
	If(dsIndex < 0)
		return 0
	EndIf
	
	//Remove the data set from the group
	DSGroupContents[dsIndex][index] = ""
	 
	//Check that there aren't blank spaces at the bottom of the contents wave now
	Variable i,rows = DimSize(DSGroupContents,0)
	Variable cols = DimSize(DSGroupContents,1)
	
	For(i=0;i<cols;i+=1)
		Variable len = strlen(DSGroupContents[rows-1][i])
		If(len)
			break
		EndIf
	EndFor
	
	If(!len)
		Redimension/N=(rows-1,-1) DSGroupContents
	EndIf
	
	//add the data set to the group contents list wave
	Redimension/N=(DimSize(DSGroupContents,0)) DSGroupContentsListWave
	If(DimSize(DSGroupContentsListWave,0))
		DSGroupContentsListWave = DSGroupContents[p][index]
		RemoveEmptyCells(DSGroupContentsListWave,0)
	EndIf
	
	Redimension/N=(DimSize(DSGroupContentsListWave,0)) DSGroupContentsSelWave
	
	//reset the group
	SetDSGroup(group=group)
	
	notificationEntry = "Removed \f01" + dataset + "\f00 from \f01" + group
	SendNotification()
End

Function OpenDSNotesEntry2([dataset])
	String dataset
	
	DFREF NPD = $DSF
	DFREF NPC = $CW
	
	
	If(numtype(strlen(dataset)) == 2)
		dataset = ""
	EndIf
	
	
	//Draw the function name or data set name above the note
	ControlInfo/W=NTP#Func DSNotesBox
	Variable topPos = V_top + 8
	
	//Delete the existing title and refresh
	SetDrawLayer/W=NTP#Func Overlay
	DrawAction/W=NTP#Func getgroup=dsNotesText,delete
	
	SetDrawLayer/W=NTP#Func Overlay
	SetDrawEnv/W=NTP#Func gstart,gname=dsNotesText,xcoord= abs,ycoord= abs, fsize=16, textxjust= 0,textyjust= 2,fname="Helvetica Light"
	DrawText/W=NTP#Func 15,topPos,"Data Set:    \f01" + dataset
	
	SetDrawEnv/W=NTP#Func gstop
	
	//Positions are relative to the DSNotesBox ControlInfo call a few lines up.
	Button SaveNotes win=NTP#Func,pos={V_right - 75,V_top},size={70,20},font=$LIGHT,fsize=12,title="Save Notes",disable=0,proc=NTPButtonProc
	
	
	Wave/T DSGroupContentsListWave = NPD:DSGroupContentsListWave
	NVAR funcPanelWidth = NPC:funcPanelWidth
	
	If(ParamIsDefault(dataset))
		ControlInfo/W=NTP#Data DSGroupContents
		If(V_Value > DimSize(DSGroupContentsListWave,0) - 1)
			dataset = ""
		Else
			dataset = DSGroupContentsListWave[V_Value]
		EndIf
	Else
		If(!strlen(dataset))
			dataset = ""
		EndIf
	EndIf
	
	String notesName = ReplaceString(" ",dataset,"_")
	SVAR DSNotes = NPD:$("DS_" + notesName + "_notes")
	
	If(SVAR_Exists(DSNotes))
		Notebook NTP#Func#DSNotebook,selection={startOfFile,endOfFile},writeProtect=0,setData=DSNotes
	Else
		Notebook NTP#Func#DSNotebook,selection={startOfFile,endOfFile},writeProtect=0,setData=""
	EndIf
	
End

Function SaveDataSetNotes(dataset)
	String dataset
	
	DFREF NPD = $DSF
	DFREF NPC = $CW
	
	If(!strlen(dataset))
		return 0
	EndIf
	
	Notebook NTP#Func#DSNotebook,getData=1
	
	String notesName = ReplaceString(" ",dataset,"_")
	SVAR DSNotes = NPD:$("DS_" + notesName + "_notes")
	
	If(SVAR_Exists(DSNotes))
		DSNotes = S_Value
	Else
		//notes don't exist, make a new one
		String/G NPD:$("DS_" + notesName + "_notes")
		SVAR DSNotes = NPD:$("DS_" + notesName + "_notes")
		DSNotes = S_Value
	EndIf
End

//Function OpenDSNotesEntry([dataset])
	String dataset
	
	DFREF NPD = $DSF
	DFREF NPC = $CW
	
	Wave/T DSGroupContentsListWave = NPD:DSGroupContentsListWave
	NVAR funcPanelWidth = NPC:funcPanelWidth
	
	If(ParamIsDefault(dataset))
		ControlInfo/W=NTP#Data DSGroupContents
		If(V_Value > DimSize(DSGroupContentsListWave,0) - 1)
			dataset = ""
		Else
			dataset = DSGroupContentsListWave[V_Value]
		EndIf
	Else
		If(!strlen(dataset))
			dataset = ""
		EndIf
	EndIf
	
	String notesName = ReplaceString(" ",dataset,"_")
	SVAR DSNotes = NPD:$("DS_" + notesName + "_notes")
	
	
	//Find position of previously built panels
	ControlInfo/W=NTP#Data dataSetPanel
	Variable topPos = V_top
	Variable height = V_height
	
//	GroupBox DSNotesBox win=NTP#Func,pos={0,topPos},size={funcPanelWidth - 5,height},disable=0
	
	topPos += 8
	
	SetDrawLayer/W=NTP#Func Overlay
	DrawAction/W=NTP#Func getgroup=dsNotesText,delete
	
	SetDrawLayer/W=NTP#Func Overlay
	SetDrawEnv/W=NTP#Func gstart,gname=dsNotesText,xcoord= abs,ycoord= abs, fsize=16, textxjust= 0,textyjust= 2,fname="Helvetica Light"
	DrawText/W=NTP#Func 15,topPos,"Notes:    \f01" + dataset
	
	If(SVAR_Exists(DSNotes))
		SetDrawEnv/W=NTP#Func xcoord= abs,ycoord= abs, fsize=12, textxjust= 0,textyjust= 2,fname=$LIGHT
		DrawText/W=NTP#Func 15,topPos + 35,DSNotes
	EndIf
	
	SetDrawEnv/W=NTP#Func gstop

End

Function notesHook(s)
	STRUCT WMWinHookStruct &s
	
	Variable hookResult = 0
	
	DFREF NTD=$DSF
	Wave/T DSGroupContentsListWave = NTD:DSGroupContentsListWave
	
	ControlInfo/W=NTP#Data DSGroupContents
	If(V_Value < DimSize(DSGroupContentsListWave,0))
		String dsName = DSGroupContentsListWave[V_Value]
	Else
		hookResult = 1
		return hookResult
	EndIf
	
	switch(s.eventCode)
		case 0:				// Activate
			// Handle activate
			break

		case 1:				// Deactivate
			// Handle deactivate
			break
		case 11:
			//Keystroke
			SetDrawLayer/W=NTP#Func Overlay
			DrawAction/W=NTP#Func getgroup=dsNotesText,delete
	
			AddKeystrokeToNote(s.keyText,s.keyCode,s.specialKeyCode,dsName)
			hookResult = 1
			break
		// And so on . . .
	endswitch
	return hookResult		// 0 if nothing done, else 1
End

//Adds keystrokes to the note string
Function AddKeystrokeToNote(keyText,keyCode,specialKeyCode,dsName)
	String keyText
	Variable keyCode,specialKeyCode
	String dsName
	
	DFREF NPD = $DSF
	String notesName = ReplaceString(" ",dsName,"_")
	SVAR DSNotes = NPD:$("DS_" + notesName + "_notes")
	
	If(!SVAR_Exists(DSNotes))
		String/G NPD:$("DS_" + notesName + "_notes")
		SVAR DSNotes = NPD:$("DS_" + notesName + "_notes")
	EndIf
	
	If(strlen(DSNotes) == 1)
		DSNotes = ""
	EndIf
		
	If(keyCode == 13) //enter key
		keyText = "\n"
	ElseIf(keyCode == 9) //tab key
		keyText = "   "
	
	EndIf
	
	If(keyCode == 8) //backspace
		DSNotes = DSNotes[0,strlen(DSNotes)-3] + "_"
	Else
		DSNotes = DSNotes[0,strlen(DSNotes)-2] + keyText + "_"
	EndIf
	
	ControlInfo/W=NTP#Data dataSetPanel
	Variable topPos = V_top + 8
	
	SetDrawLayer/W=NTP#Func Overlay
	DrawAction/W=NTP#Func getgroup=dsNotesText,delete
	
	SetDrawLayer/W=NTP#Func Overlay
	SetDrawEnv/W=NTP#Func gstart,gname=dsNotesText,xcoord= abs,ycoord= abs, fsize=16, textxjust= 0,textyjust= 2,fname="Helvetica Light"
	DrawText/W=NTP#Func 15,topPos,"Notes:    \f01" + dsName
	
	SetDrawEnv/W=NTP#Func gstart,gname=dsNotesText,xcoord= abs,ycoord= abs, fsize=12, textxjust= 0,textyjust= 2,fname=$LIGHT
	DrawText/W=NTP#Func 15,topPos + 35,DSNotes
	
	SetDrawEnv/W=NTP#Func gstop
End