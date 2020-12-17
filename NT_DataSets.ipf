#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//Handles all of the Data Set organization code

//Puts the data set names that already exist into the dataSetNames list wave
Function/S GetDataSetNames()
	DFREF NTD = root:Packages:NT:DataSets
	
	Wave/T dataSetNames = NTD:dataSetNames
	String dataSets,cdf
	Variable numDataSets,i
	
	cdf = GetDataFolder(1)
	SetDataFolder NTD
	
	dataSets = WaveList("DS_*",";","TEXT:1")
	numDataSets = ItemsInList(dataSets,";")
	Redimension/N=(numDataSets) dataSetNames
	
	For(i=0;i<numDataSets;i+=1)
		dataSetNames[i] = RemoveListItem(0,StringFromList(i,dataSets,";"),"_")	//also removes the DS from the front for display purposes
	EndFor
	
	SetDataFolder $cdf
End

//Adds a new data set from the waves in the Wave Match list box.
Function addDataSet(dsName)
	String dsName
	STRUCT filters filters
	
	DFREF NTD = root:Packages:NT:DataSets
	DFREF NTF = root:Packages:NT
	Variable errorCode = 0
	
	SVAR folderSelection =  NTF:folderSelection
	
	//Data Set Names list box Selection and List waves
	Wave/T DSNamesLB_ListWave = NTD:DSNamesLB_ListWave
	Wave DSNamesLB_SelWave = NTD:DSNamesLB_SelWave
	
	//Waves in the Wave Match list box
	Wave/T MatchLB_ListWave = NTF:MatchLB_ListWave
	Variable numWaves = DimSize(MatchLB_ListWave,0)
	
	//Base set of waves in the Wave Match list box (no groupings)
	Wave/T MatchLB_ListWave_BASE = NTF:MatchLB_ListWave_BASE 
	
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
	Make/T/O/N=(numWaves,1,2) NTD:$dsWaveName 
	Wave/T DS_BASE = NTD:$dsWaveName
	
	//ORGANIZED data set - contains wave set labels
	Make/T/O/N=(numWaves,1,2) NTD:$(dsWaveName + "_org") 
	Wave/T DS_ORG = NTD:$(dsWaveName + "_org")
	
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
	Wave/T DataSetLB_ListWave = NTD:DataSetLB_ListWave
	Wave DataSetLB_SelWave = NTD:DataSetLB_SelWave
	
	//Push the organized data set waves into the data set waves list box
	matchContents(DS_ORG,DataSetLB_ListWave)
	
	Redimension/N=(DimSize(DS_ORG,0)) DataSetLB_SelWave
	DataSetLB_SelWave = 0
	
	//Change the displayed data set to the one that now occupies that list position
	index = tableMatch(dsName,DSNamesLB_ListWave)
	
	If(index != -1)
		ListBox DataSetNamesListBox win=NT,selRow=(index)
	EndIf

	//Update the controls with the saved WaveMatch filter settings
	//Return string is just for quality control and debugging
	
	//Initiate the filter structure with SVARs
	SetFilterStructure(filters,"")
	
	//Get the filter settings from the WaveMatch list box
	String filterSettingStr = recallFilterSettings("WaveMatch")
	
	//Remove all values filter values (prefix thru trace)
	Variable i
	For(i=3;i<8;i+=1) 
		filterSettingStr += StringFromList(i,filterSettingStr,";") + ";"
		filterSettingStr = ReplaceListItem(i,filterSettingStr,";","")
	EndFor
	
	//Append to the data set definition
	DSNamesLB_ListWave[index][0][1] = filterSettingStr
	
	//Save the folder selection that went into building this data set
	DSNamesLB_ListWave[index][0][2] = folderSelection
	
	//Switch focus to the DataSet list box
	changeFocus("DataSet",1)
	
	//add Data Set name to a string list for the Parameters panel list box
	updateDSNameList()
	
	//display the full path to the wave in a text box
	drawFullPathText()
	
	return errorCode
End

//Updates the selected data set with the contents of the Wave Match listbox
Function updateDataSet(dsName)
	String dsName
	STRUCT filters filters
	
	//Initialize the filter structure with SVARs
	SetFilterStructure(filters,"DataSet")
	
	DFREF NTD = root:Packages:NT:DataSets
	DFREF NTF = root:Packages:NT
	
	Variable errorCode = 0
	
	//Data Set Wave Lists
	Wave/T DataSetLB_ListWave = NTD:DataSetLB_ListWave
	Wave DataSetLB_SelWave = NTD:DataSetLB_SelWave
	
	//WaveMatch list waves
	Wave/T MatchLB_ListWave = NTF:MatchLB_ListWave
	
	//Base set of waves in the Wave Match list box (no groupings)
	Wave/T MatchLB_ListWave_BASE = NTF:MatchLB_ListWave_BASE 
	
	//BASE data set
	Wave/T DS_BASE = NTD:$("DS_" + dsName)
	
	//ORGANIZED data set - contains wave set labels
	Wave/T DS_ORG = NTD:$("DS_" + dsName + "_org")
	
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
	Wave/T DSNamesLB_ListWave = NTD:DSNamesLB_ListWave
	SVAR folderSelection = NTF:folderSelection
	Variable index = GetDSIndex()
	If(index != -1)
		DSNamesLB_ListWave[index][0][2] = folderSelection
	EndIf
	
	//Switch focus to data sets
	changeFocus("DataSet",0)

	//Migrate the current filter settings from the WaveMatch list box to the data set
	//Because of clearFilters, the ORG data set will have no filtering, but it will retain grouping
	String filterSettingStr = migrateFilterSettings(dsName)

	return errorCode
End

//Migrate the current filter settings from the WaveMatch list box to the data set
//Filter and grouping options are stored in layer 2 of the DSNamesListWave
Function/S migrateFilterSettings(dsName)
	String dsName
	DFREF NTD = root:Packages:NT:DataSets
	
	//First recall the WaveMatch filter settings
	STRUCT filters filters
	SetFilterStructure(filters,"")

	String filterSettingStr = recallFilterSettings("WaveMatch")
	
	//Clear the filter controls only, but leave the groupings intact
	clearFilterControls(filtersOnly=1)
	
	//Put the control values back into the structure
	SetSearchTerms(filters)
	
	Wave/T DSNamesLB_ListWave = NTD:DSNamesLB_ListWave
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
	filterSettings += filters.wg + ";"	
	
	return filterSettings
End

//Removes the selected data set
Function deleteDataSet(dsName)
	String dsName
	DFREF NTD = root:Packages:NT:DataSets
	DFREF NTF = root:Packages:NT
	Variable errorCode = 0
	
	SVAR waveSelectorStr = NTF:waveSelectorStr
	
	//Data Set copies to be deleted
	Wave/T BASE = NTD:$("DS_" + dsName)
	Wave/T ORG = NTD:$("DS_" + dsName + "_org")
	
	KillWaves/Z BASE,ORG
	
	//Remove the entry from the listbox
	Wave/T DSNamesLB_ListWave = NTD:DSNamesLB_ListWave
	Wave DSNamesLB_SelWave = NTD:DSNamesLB_SelWave
	
	Variable index = tableMatch(dsName,DSNamesLB_ListWave)
	
	//Select new data set and delete the old selection from the listbox
	If(index != -1)
		DeletePoints/M=0 index,1,DSNamesLB_ListWave,DSNamesLB_SelWave
	EndIf
	
	//Change the displayed data set to the one that now occupies that list position
	If(DimSize(DSNamesLB_ListWave,0) == 0)
		dsName = ""
	ElseIf(index >= DimSize(DSNamesLB_ListWave,0))
		dsName = DSNamesLB_ListWave[index-1][0][0]
		ListBox DataSetNamesListBox win=NT,selRow=(index-1)
	Else
		dsName = DSNamesLB_ListWave[index][0][0]
		ListBox DataSetNamesListBox win=NT,selRow=(index)
	EndIf
	
	changeDataSet(dsName)

	//add Data Set name to a string list for the Parameters panel list box
	updateDSNameList()
	
	//Change the selection in the Wave Selector menu if we just deleted the selected data set.
	If(cmpstr(dsName,waveSelectorStr))
		switchWaveListSelectorMenu("Wave Match")
	EndIf
	
	//display the full path to the wave in a text box
	drawFullPathText()
	
	return errorCode
End

//Refresh list of Data Set names in a string list for the Parameters panel list box
Function/S updateDSNameList()
	DFREF NTD = root:Packages:NT:DataSets
	
	String cmd = CurrentCommand()
	
	Wave/T DSNamesLB_ListWave = NTD:DSNamesLB_ListWave
	SVAR DSNames = NTD:DSNames
	
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
	
	DFREF NTD = root:Packages:NT:DataSets
	
	Wave/T DataSetLB_ListWave = NTD:DataSetLB_ListWave
	Wave DataSetLB_SelWave = NTD:DataSetLB_SelWave
	
	//Data set names selection and list wave
	Wave/T DSNamesLB_ListWave = NTD:DSNamesLB_ListWave
	Wave DSNamesLB_SelWave = NTD:DSNamesLB_SelWave
	
	//no input data set - clear the list box
	If(!strlen(dsName))
		Redimension/N=(0) DataSetLB_ListWave,DataSetLB_SelWave
		return 0	
	EndIf
	
	//Data set wave - organized
	Wave/T ds = GetDataSetWave(dsName,"ORG")
	
	//Display the newly selected data set in the Data Set Waves list box
	matchContents(ds,DataSetLB_ListWave)
	Redimension/N=(DimSize(ds,0)) DataSetLB_SelWave
	DataSetLB_SelWave = 0
	
	If(DimSize(DataSetLB_SelWave,0) == 0)
		return 0
	EndIf
	
	DataSetLB_SelWave[0] = 1
	
	//recall the match/filter/grouping terms for the data set
	recallFilterSettings("DataSet")
	
	//Check that the contents exist, if not, grey them out
	CheckDataSetWaves()
	
	//display the full path to the wave in a text box
	drawFullPathText()
End

//Check that the contents exist, if not, grey them out
Function CheckDataSetWaves()
	DFREF NTD = root:Packages:NT:DataSets
	DFREF NTF = root:Packages:NT:
	
	//Data set wave - organized
	Wave/T ds = GetDataSetWave(GetDSName(),"ORG")
	Wave/T listWave = NTD:DataSetLB_ListWave
	
	//Wave Match list wave
	Wave/T MatchLB_ListWave = NTF:MatchLB_ListWave
	
	If(WaveExists(ds))
		Variable i
		For(i=0;i<DimSize(ds,0);i+=1)
			If(!stringmatch(ds[i][0][1],"*Wave Set*") && !WaveExists($ds[i][0][1]))
				//red wave name
				listWave[i][0][0] = "\K(65535,0,0)" + ParseFilePath(0,ds[i][0][1],":",1,0)
			Else
				//normal black wave name
				listWave[i][0][0] = ParseFilePath(0,ds[i][0][1],":",1,0)
			EndIf
		EndFor
	EndIf
	
	For(i=0;i<DimSize(MatchLB_ListWave,0);i+=1)
		If(!stringmatch(MatchLB_ListWave[i][0][1],"*Wave Set*") && !WaveExists($MatchLB_ListWave[i][0][1]))
			//red wave name
			MatchLB_ListWave[i][0][0] = "\K(65535,0,0)" + ParseFilePath(0,MatchLB_ListWave[i][0][1],":",1,0)
		Else
			//normal black wave name
			MatchLB_ListWave[i][0][0] = ParseFilePath(0,MatchLB_ListWave[i][0][1],":",1,0)
		EndIf
	EndFor
End

//Returns the wave reference to the named data set
Function/Wave GetDataSetWave(dsName,version)
	//version is either "BASE","ORG",or "NOLABEL" for the 3 existing copies of the data set
	String dsName,version
	DFREF NTD = root:Packages:NT:DataSets
	
	strswitch(version)
		case "BASE":
			String dsWaveName = "DS_" + dsName
			break
		case "ORG":
			dsWaveName = "DS_" + dsName + "_org"
			break
		default:
			//empty string input might happen
			return $""
	endswitch
	
	Wave/Z/T ds = NTD:$dsWaveName
	
	If(!WaveExists(ds))
		return $""
	Else
		return ds
	EndIf

End

//Returns the name of the currently selected data set
Function/S GetDSName()
	String dsName = ""
	Variable index = -1
	
	DFREF NTD = root:Packages:NT:DataSets
	Wave/T DSNamesLB_ListWave = NTD:DSNamesLB_ListWave
	
	//No data sets yet defined
	If(DimSize(DSNamesLB_ListWave,0) == 0)
		return ""
	EndIf
	
	ControlInfo/W=NT DataSetNamesListBox
	//No selection made
	If(V_Value == -1)
		return ""	
	EndIf
	
	dsName = DSNamesLB_ListWave[V_Value][0][0]
	return dsName
End

//Returns the index of the currently selected data set
Function GetDSIndex()
	DFREF NTD = root:Packages:NT:DataSets
	ControlInfo/W=NT DataSetNamesListBox
	
	Wave/T DSNamesLB_ListWave = NTD:DSNamesLB_ListWave
	If(DimSize(DSNamesLB_ListWave,0) == 0)
		V_Value = -1
	EndIf
	
	return V_Value
End

//Returns the number of wavesets in the input list
Function GetNumWaveSets(listWave)
	Wave/T listWave
	Variable item = 0,count = 0
	String name = ""
	
	If(!WaveExists(listWave))
		return 0
	EndIf
	
	If(DimSize(listWave,0) == 0)
		return 0
	EndIf
	
	Do
		name = listWave[item][0][0]
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
	Variable size
	
	Wave/T ws = GetWaveSet(listWave,wsn)
	size = DimSize(ws,0)
	
	return size
End

//Returns the waves with the indicated wave set index from the listwave
Function/WAVE GetWaveSet(listWave,wsn)
	Wave/T listWave
	Variable wsn
	Variable i = 0,count = 0
	
	//If listwave is empty or doesn't exist
	If(!WaveExists(listWave))
		return $""
	EndIf
	
	If(DimSize(listWave,0) == 0)
		return $""
	EndIf
	
	//Only 1 wave set
	If(!stringmatch(listWave[0][0][0],"*WAVE SET*") && wsn == 0)
		Duplicate/T/FREE listWave,tempWave
		return tempWave
	EndIf
	
	//Get start of the wave set
	
	Variable first = tableMatch("*WAVE SET*" + num2str(wsn) + "*",listWave) + 1
	
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
	
	Variable last = tableMatch("*WAVE SET*" + num2str(wsn + 1) + "*",listWave)
	
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
	
	tempWave[][0][0] = listWave[first+p][0][0]	 //names
	tempWave[][0][1] = listWave[first+p][0][1] //full path
	
	return tempWave
End

//Returns a string list of the wave set instead of a wave as in GetWaveSet()
Function/S GetWaveSetList(listWave,wsn,fullPath)
	Wave/T listWave
	Variable wsn
	Variable fullPath //1 for full path, 0 for names only
	String list = ""
	
	If(!WaveExists(listWave))
		return ""
	EndIf
	
	Wave/T ws = GetWaveSet(listWave,wsn)
	
	If(!WaveExists(ws))
		return ""
	EndIf
	
	list = TextWaveToStringList(ws,";",layer=fullPath)
	return list
End

//Returns a wave reference wave of the indicated wave set
Function/WAVE GetWaveSetRefs(listWave,wsn)
	Wave/T listWave
	Variable wsn
	
	If(!WaveExists(listWave))
		return $""
	EndIf
	
	//Can have multiple data sets if this is an external function call
	Variable i,numDataSets = DimSize(listWave,1)
	If(numDataSets == 0)
		numDataSets = 1
	EndIf
	
	Make/WAVE/O/N=(1,numDataSets) root:Packages:NT:ds_waveRefs
	Wave/WAVE ds_waveRefs = root:Packages:NT:ds_waveRefs
		
	For(i=0;i<numDataSets;i+=1)
		Make/FREE/O/T/N=(DimSize(listWave,0),1,2) currentDS
		
		If(!DimSize(currentDS,0))
			Redimension/N=(0,-1) ds_waveRefs
			return ds_waveRefs
		EndIf
		
		currentDS = listWave[p][i][r]
		
		//current data set
		String list = GetWaveSetList(currentDS,wsn,1)
	
		try
			Wave/WAVE refs = ListToWaveRefWave(list);AbortOnRTE
		catch
			Variable error = GetRTError(1)
		endtry
		
		If(DimSize(refs,0) > DimSize(ds_waveRefs,0))
			Redimension/N=(DimSize(refs,0),-1) ds_waveRefs
		EndIf
		
		ds_waveRefs[0,DimSize(refs,0)-1][i] = refs[p][i]
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
	
	startIndex = tableMatch("*WAVE SET*" + num2str(wsn) + "*",listWave)
	
	//wave set doesn't exist
	If(startIndex == -1)
		//actually there just is no wave set division and this it the 0th wave set
		If(!stringmatch(listWave[0],"*WAVE SET*") && wsn == 0)
			startIndex = 0
		Else	
			return -1
		EndIf
	EndIf
	
	
	endIndex = tableMatch("*WAVE SET*" + num2str(wsn+1) + "*",listWave)
	
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
		index = tableMatch("*WAVE SET*",listWave,startP=index+1)
		
		If(index != -1)
			//set to incremental order
			listWave[index] = "----WAVE SET " + num2str(count) + "----"
			count += 1
		EndIf
	While(index != -1)
	
	return 0
End