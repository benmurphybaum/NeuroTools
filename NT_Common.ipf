#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//If str matches an entry in the tableWave, returns the row, otherwise return -1
Function tableMatch(str,tableWave,[startp,endp,returnCol])
	String str
	Wave/T tableWave
	Variable startp,endp,returnCol//for range
	Variable i,j,size = DimSize(tableWave,0)
	Variable cols = DimSize(tableWave,1)
	
	If(cols == 0)
		cols = 1
	EndIf
	
	If(ParamIsDefault(startp))
		startp = 0
	EndIf
	
	If(ParamIsDefault(endp))
		endp = size - 1
	EndIf
	
	If(ParamIsDefault(returnCol))
		returnCol = 0
	EndIf
	
	If(startp > DimSize(tableWave,0) - 1)
		return -1
	EndIf
	
	If(endp < DimSize(tableWave,0) - 1)
		return -1
	EndIf
	
	For(j=0;j<cols;j+=1)
		For(i=startp;i<endp+1;i+=1)
			If(stringmatch(tableWave[i][j],str))
				If(returnCol)
					return j
				Else
					return i
				EndIf
			EndIf
		EndFor
	EndFor
	
	return -1
End

//Switches the label on the Command Menu on a new selection
Function switchCommandMenu(cmd)
	String cmd
	
	//Calculates spacer to ensure centered text on the drop down menu
	String spacer = ""
	Variable cmdLen = strlen(cmd)
	cmdLen = 16 - cmdLen
	
	Do
		spacer += " "
		cmdLen -= 1
	While(cmdLen > 0)
	
	//Command Menu
	Button CommandMenu win=NT,font=$LIGHT,pos={456,39},size={140,20},fsize=12,proc=ntButtonProc,title="\\JL▼   " + spacer + cmd,disable=0

End


//Switches the label on the Wave Selector Menu on a new selection
Function switchWaveListSelectorMenu(cmd)
	String cmd
	
	DFREF NTF = root:Packages:NT
	SVAR waveSelectorStr = NTF:waveSelectorStr
	
	//Calculates spacer to ensure centered text on the drop down menu
	String spacer = ""
	Variable cmdLen = strlen(cmd)
	cmdLen = 15 - cmdLen
	
	Do
		spacer += " "
		cmdLen -= 1
	While(cmdLen > 0)
	
	//Command Menu
	Button WaveListSelector win=NT,font=$LIGHT,proc=ntButtonProc,title="\\JL▼   " + spacer + cmd,disable=0
	
	waveSelectorStr = cmd
End


//Gets the subfolders that reside in the current data folder
Function/WAVE getFolders([folderPath])
	//if folderPath is provided, the folder list within folderPath is provided instead of the cdf
	String folderPath
	
	DFREF NTF = root:Packages:NT
	
	//Selection and List Waves for the list box
	Wave/T FolderLB_ListWave = NTF:FolderLB_ListWave
	Wave/T FolderLB_SelWave = NTF:FolderLB_SelWave
		
	SVAR cdf = NTF:currentDataFolder
	
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
Function/WAVE getFolderWaves([depth])
	Variable depth //folder depth
	DFREF NTF = root:Packages:NT

	//Selection and List waves
	Wave/T WavesLB_ListWave = NTF:WavesLB_ListWave
	Wave WavesLB_SelWave = NTF:WavesLB_SelWave
	
	SVAR cdf = NTF:currentDataFolder
	
	String itemList
	Variable i
	
	//Match list
	itemList = ReplaceString(";",StringFromList(1,DataFolderDir(2),":"),"")
	itemList = TrimString(itemList)
	
	Redimension/N=(ItemsInList(itemList,",")) WavesLB_ListWave,WavesLB_SelWave
	
	For(i=0;i<ItemsInList(itemList,",");i+=1)
		WavesLB_ListWave[i] = StringFromList(i,itemList,",")
	EndFor
	return WavesLB_ListWave
End


//Switches the current data folder to the selection
//Refreshes the folder and wave list box contents
Function switchFolders(selection)
	String selection
	DFREF NTF = root:Packages:NT
	
	//Change the current data folder
	SVAR cdf = NTF:currentDataFolder
	SetDataFolder cdf + selection
	
	//Refresh the folder and waves list boxes
	getFolders()
	getFolderWaves()
End

//Switches the current data folder up one level
//Refreshes the folder and wave list box contents
Function navigateBack()
	DFREF NTF = root:Packages:NT
	
	//Change the current data folder
	SVAR cdf = NTF:currentDataFolder
	
	//Do nothing if we're already in root
	If(!cmpstr(cdf,"root:"))
		return 0
	EndIf
	
	cdf = ParseFilePath(1,cdf,":",1,0)
	SetDataFolder cdf
	
	//Refresh the folder and waves list boxes
	getFolders()
	getFolderWaves()
	
	Wave FolderLB_SelWave = NTF:FolderLB_SelWave
	
	//Set the selection to the first row
	If(DimSize(FolderLB_SelWave,0) > 0)
		FolderLB_SelWave = 0
		FolderLB_SelWave[0] = 1
	EndIf
End

//Switches the listed controls to those of the selected command in the Command Menu
Function switchControls(currentCmd,prevCmd)
	String currentCmd,prevCmd
	DFREF NTF = root:Packages:NT
	NVAR foldStatus = NTF:foldStatus
	
	SVAR selectedCmd = NTF:selectedCmd
	Wave/T controlAssignments = NTF:controlAssignments 
	
	//Find the row for the current command selection in the control assignments wave
	Variable index = tableMatch(currentCmd,controlAssignments)
	If(index == -1)
		return 0
	EndIf
	
	//Get the list of the assigned controls for the selected command
	String visibleList = controlAssignments[index][1]
	Variable panelWidth = str2num(controlAssignments[index][2])
	
	//Get current width of the parameter panel, to see if adjustments need to be  made
	GetWindow NT wsize
	Variable left,top,right,bottom
	left = V_left;right=V_right;top=V_top;bottom=V_bottom
	Variable expansion = (right - left) - 754 //current expansion relative to original width of the panel
	
	//Delete the command line entry
	SetDrawEnv/W=NT  fstyle= 0, textxjust= 0
	DrawAction/W=NT getgroup=CmdLineText,delete
	
	//Toggle visibility of controls according to the selected command
	If(!cmpstr(prevCmd,""))
		//Adjust the size of the parameters panel
		//only makes adjustment if parameters panel is open
		If(panelWidth > expansion && foldStatus) 
			openParameterFold(size = panelWidth)
		ElseIf(panelWidth < expansion && foldStatus)
			closeParameterFold(size = panelWidth)
		EndIf
		
		controlsVisible(visibleList,0)
		selectedCmd = currentCmd
	Else
		//Find the row for the previous command selection in the control assignments wave
		//Need to hide these controls
		index = tableMatch(prevCmd,controlAssignments)
		If(index == -1)
			return 0
		EndIf
		
		String invisibleList = controlAssignments[index][1]
		
		//Adjust the size of the parameters panel
		//Do in between invisible/visible functions for better animation
		//only makes adjustment if parameters panel is open
		If(panelWidth > expansion && foldStatus)
			openParameterFold(size = panelWidth)
		ElseIf(panelWidth < expansion && foldStatus)
			closeParameterFold(size = panelWidth)
		EndIf
		
		//Make previous controls invisible
		controlsVisible(invisibleList,3)
		
		//Toggle the 'Waves:' title if WaveListSelector is to be invisible
		SetDrawEnv/W=NT fstyle = 0, textxjust= 0
		DrawAction/W=NT getgroup=waveSelectorTitle,delete
		
		
		If(stringmatch(visibleList,"*WaveListSelector*"))
			SetDrawEnv/W=NT xcoord= abs,ycoord= abs, fsize=12, textxjust= 1,textyjust= 1,fname=$LIGHT,gname=waveSelectorTitle,gstart
			DrawText/W=NT 483,85,"Waves:"
			SetDrawEnv/W=NT gstop
		EndIf
		
		//make current controls visible 
		controlsVisible(visibleList,0)

		selectedCmd = currentCmd
	EndIf
	
	If(!cmpstr(selectedCmd,"")) 
		return 0
	EndIf
	
	
	//Refresh any command specific text that needs to be displayed
	SetDrawEnv/W=NT fstyle=0
	DrawAction/W=NT getgroup=fcnText,delete
	strswitch(selectedCmd)
		case "Get ROI":
			SetDrawEnv/W=NT fstyle=0,textxjust=0,textyjust=0,xcoord=abs,ycoord=abs,fname=$LIGHT,fsize=12,gname=fcnText,gstart
			DrawText/W=NT 687,98,"ROIs"
			SetDrawEnv/W=NT fstyle=0,textxjust=0,textyjust=0,xcoord=abs,ycoord=abs,fsize=12,fname=$LIGHT
			DrawText/W=NT 605,98,"Scans"
			SetDrawEnv/W=NT gstop
			break
		case "df Map":
			SetDrawEnv/W=NT fstyle=0,textxjust=0,textyjust=0,xcoord=abs,ycoord=abs,fname=$LIGHT,fsize=12,gname=fcnText,gstart
			DrawText/W=NT 605,98,"Scans"
			SetDrawEnv/W=NT gstop
			break
		case "Run Cmd Line":
			 DrawMasterCmdLineEntry()
			break
		case "External Function":
			//refresh the external function list
			
			break
	endswitch
	
End

//Changes the help message that pops up with the different commands
Function switchHelpMessage(cmd)
	String cmd
	String helpMsg = ""
	
	//Reset the help message
	SetDrawEnv/W=NT  fstyle= 0
	DrawAction/W=NT getgroup=helpMessage,delete
	
	If(!strlen(cmd))
		return 0
	EndIf
	
	strswitch(cmd)
		case "Measure":
			helpMsg = "Performs the operation on the selected\n waves"
			break
		case "Average":
			helpMsg = "Calculates the average of the selected\n waves"
			break
		case "Errors":
			helpMsg = "Calculates the standard error or standard\n deviation of the selected waves"
			break
		case "PSTH":
			helpMsg = "Returns the peristimulus time histogram of\n the selected waves"
			break
		case "Duplicate Rename":
			helpMsg = "Duplicates the selected waves, with optional rename according\n to the inputs " 
			helpMsg += "in each underscore position. Optional kill for a full\n replace."
			break
		case "Kill Waves":
			helpMsg = "Kills the selected waves"
			break
		case "Set Wave Note":
			helpMsg = "Writes the input as a wave note in the selected waves"
			break
		case "Move To Folder":
			helpMsg = "Moves the selected waves to the indicated folder within the\n current data folder." 
			helpMsg += " The folder will be created if it doesn't exist. \nOptional depth variable to move waves out of the current data\n folder"
			break
		case "Run Cmd Line":
			helpMsg = "Runs an arbitrary command as if it was executed from the\n command line. "
			helpMsg += "Use the syntax: <DataSet> to reference waves\n in a data set."
			break
		case "External Function":
			helpMsg = "Run your own function within NeuroTools by \nputting the .ipf in the 'External Functions' \nfolder"
			break
	endswitch
	
	SetDrawEnv/W=NT textyjust= 0,xcoord=abs,ycoord=abs,fname=$LIGHT,fstyle=2,fsize=10,gname=helpMessage,gstart
	DrawText/W=NT 456,495,helpMsg
	SetDrawEnv/W=NT gstop
	
End

//Takes text wave, and creates a string list with its contents
Function/S textWaveToStringList(textWave,separator,[col,layer])
	Wave/T textWave
	String separator
	Variable col,layer
	
	Variable size,i
	String strList = ""
	
	If(WaveType(textWave,1) !=2)
		Abort "Input must be a text wave"
	EndIf
	
	size = DimSize(textWave,0)
	
	If(ParamIsDefault(col))
		col = 0
	EndIf
	
	If(ParamIsDefault(layer))
		layer = 0
	EndIf
	
	For(i=0;i<size;i+=1)
		strList += textWave[i][col][layer] + separator
	EndFor
	
	return strList
End

//Takes string list, and creates a text wave with its contents
Function/WAVE StringListToTextWave(strList,separator)
	String strList,separator
	Variable size,i
	
	If(!strlen(strList))
		Abort "String must be longer than 0 characters"
	EndIf
	
	size = ItemsInList(strList,separator)
	Make/FREE/T/N=(size) textWave
	For(i=0;i<size;i+=1)
		textWave[i] = StringFromList(i,strList,";")
	EndFor

	return textWave
End

//Same as StringFromList, but is capable of extracting a range from the list
Function/S StringsFromList(range,list,separator)
	String range,list,separator
	String outList = ""
	Variable i,index
	
	range = ResolveListItems(range,separator)
	
	For(i=0;i<ItemsInList(range,";");i+=1)
		index = str2num(StringFromList(i,range,";"))
		outList += StringFromList(index,list,separator) + separator
	EndFor	

	return outList
End

//Replaces the indicated list item with the replaceWith string
Function/S ReplaceListItem(index,listStr,separator,replaceWith)
	Variable index
	String listStr,separator,replaceWith
	
	listStr = RemoveListItem(index,listStr,separator)
	listStr = AddListItem(replaceWith,listStr,separator,index)
	If(index == ItemsInList(listStr,separator) - 1)
		listStr = RemoveEnding(listStr,separator)
	EndIf
	
	return listStr
End

//Takes a hyphenated range, and resolves it into a comma-separated list
//Can handle leading zeros in the range
Function/S resolveListItems(theList,separator)
	String theList,separator
	
	String commaList,theListItem,first,last,outList
	Variable j,k
	
	outList = ""
	commaList = ""
	
	//Resolves the number of selected channels
	If(stringmatch(theList,"*,*"))	//multiple channels by commmas
		For(j=0;j<ItemsInList(theList,",");j+=1)
			commaList += StringFromList(j,theList,",") + ";"
		EndFor
	Else
		commaList = theList
	EndIf
	
	For(j=0;j<ItemsInList(commaList,";");j+=1)
		theListItem = StringFromList(j,commaList,";")
		If(stringmatch(theListItem,"*-*"))	//multiple channels by hyphen
			first = StringFromList(0,theListItem,"-")
			last = StringFromList(1,theListItem,"-")
			
			If(!strlen(first) || !strlen(last))
				//its a negative number, not a range
				outList += theListItem + separator
				continue
			EndIf
			
			//For leading zeros in numerical ranges
			If(stringmatch(first[0],"0") && strlen(first) > 1)
				Variable bufferZeros = 1
				String buffer = ""
				k = 1
				Do
					buffer += "0"
					k += 1
				While(k < strlen(first))
			EndIf
			
			For(k=str2num(first);k<str2num(last) + 1;k+=1)
				If(bufferZeros)
					If(k < 10)
						outList += buffer + num2str(k) + separator
					ElseIf(k < 100)
						outList += RemoveEnding(buffer,"0") + num2str(k) + separator
					ElseIf(k < 1000)
						outList += RemoveEnding(buffer,"00") + num2str(k) + separator
					ElseIf(k < 10000)
						outList += RemoveEnding(buffer,"000") + num2str(k) + separator
					EndIf
				Else
					outList += num2str(k) + separator
				EndIf
			EndFor
		Else
			outList += theListItem + separator
		EndIf
	EndFor
	
	return outList
End

//Makes the list of control names visible on the GUI
Function controlsVisible(list,visible)
	String list
	Variable visible //0 is visible,1 is invisible
	Variable i
	
	For(i=0;i<ItemsInList(list,";");i+=1)
		String ctrl = StringFromList(i,list,";")
		ControlInfo/W=NT $ctrl
		Variable type = V_flag
		
		switch(type)
			case 1: //Button
				Button $ctrl win=NT,disable=visible
				break
			case -5: //SetVariable
			case 5:
				SetVariable $ctrl win=NT,disable=visible
				break
			case -3: //PopUpMenu
			case 3: 
				PopUpMenu $ctrl win=NT,disable=visible
				break
			case 7: //Slider
				Slider $ctrl win=NT,disable=visible
				break
			case -4: //ValDisplay	
			case 4:
				ValDisplay $ctrl win=NT,disable=visible
				break
			case 11: //ListBox
				ListBox $ctrl win=NT,disable=visible
				break
			case 2: //CheckBox
				CheckBox $ctrl win=NT,disable=visible
				break
		endswitch
	EndFor
End


//Updates the Wave Match list box with matched waves in the selected folders,
//according to the search terms
Function/WAVE getWaveMatchList()
	STRUCT filters filters
	
	DFREF NTF = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	SVAR cdf = NTF:currentDataFolder
	SVAR folderSelection = NTF:folderSelection
	
	//Is the focus set to the Wave Match list or the Data Set Waves list?
	SVAR listFocus = NTF:listFocus
	
	//Update the search, filter, and grouping terms structure
	SetSearchTerms(filters)
	
	//List and Selection waves for the list box
	Wave/T listWave = NTF:MatchLB_ListWave
	Wave selWave = NTF:MatchLB_SelWave
	
	//Navigator selection and list waves
	Wave/T FolderLB_ListWave = NTF:FolderLB_ListWave
	Wave FolderLB_SelWave = NTF:FolderLB_SelWave
		
	Variable i,j
	
	String item="",path="",itemList = ""
	String masterItemList = ""
	String folder = ""
	String folderList = ""
	
	If(!strlen(filters.match))
		filters.match = "*"
	EndIf
	
	If(!cmpstr(listFocus,"WaveMatch"))
		//Wave Match List - first find for wave matches within the selected folders
		//List and Selection waves for the list box
		Wave/T listWave = NTF:MatchLB_ListWave
		Wave selWave = NTF:MatchLB_SelWave
		
		//Selected folders in the Navigator
		//Makes a list of all the selected folders and matched subfolders
		folderList = GetFolderSearchList(filters,FolderLB_ListWave,FolderLB_SelWave)
		
		//Search the folders for matched waves.
		//The matched waves are returned to the filters structure (filters.name,filters.path)
		FindMatchedWaves(filters,folderList)
		
	ElseIf(!cmpstr(listFocus,"DataSet"))
		//Data Set Waves List
		//List and Selection waves for the list box
		Wave/T listWave = NTD:DataSetLB_ListWave
		Wave selWave = NTD:DataSetLB_SelWave
		
		//List and Selection waves for the selected data set
		Wave/T DS_BASE = GetDataSetWave(GetDSName(),"BASE")
		
		//Set the filters structure to hold Data Set wave/paths isntead of the WaveMatch waves/paths
		filters.name = ""
		filters.path = ""
		
		For(i=0;i<DimSize(DS_BASE,0);i+=1)	
			filters.name += DS_BASE[i][0][0] + ","
			filters.path += DS_BASE[i][0][1] + ","
		EndFor
	
	EndIf
	
	//Update the list box - optional here, just for debugging purposes
//	UpdateListBoxWaves(filters,listWave,selWave)

	//Apply the filters for each underscore position, starting with prefix on the left
	ApplyFilters(filters)
	
	//Update the listbox waves - required here. Wave Grouping code uses the actual list box waves
	UpdateListBoxWaves(filters,listWave,selWave)
	
	//Push the filtered waves onto the selected data set if that is in focus
	If(!cmpstr(listFocus,"DataSet"))
		Wave/T DS_ORG = GetDataSetWave(GetDSName(),"ORG")
		matchContents(listWave,DS_ORG)
	EndIf
	
	//BASE match wave list, no groupings; this list is the basis for any new data sets
	Wave/T MatchLB_ListWave_BASE = NTF:MatchLB_ListWave_BASE 
	matchContents(listWave,MatchLB_ListWave_BASE)	
	
	//Apply the wave groupings to the wave lists in the structure
	SetWaveGrouping(filters,listWave,selWave)
	
	//If focus is on DataSet, update the data set ORG wave
	If(!cmpstr(listFocus,"DataSet"))
		String dsName = GetDSName()
		Wave/T DS_ORG = GetDataSetWave(dsName,"ORG")
		
		If(!WaveExists(DS_ORG))
			print "Couldn't find data set wave"
			return $""
		EndIf
		
		//Update the ORGANIZED data set wave with the list box contents
	   matchContents(listWave,DS_ORG)
	   
	   //Update the filters into the ORG data set wave
	   Variable index = GetDSIndex()
	   If(index != -1)
		   saveFilterSettings("DataSet")
		EndIf
	Else
		saveFilterSettings("WaveMatch")
	EndIf
	
	return listWave
End

//Uses the relative Folder entry (located in the 'filters' structure)
//to return the list of folders to be searched for wave matches.
Function/S GetFolderSearchList(filters,listWave,selWave)
	STRUCT filters &filters
	Wave/T listWave
	Wave selWave
	Variable i,j
	
	DFREF NTF = root:Packages:NT
	SVAR cdf = NTF:currentDataFolder
	
	//Used to save the folder selection
	SVAR folderSelection = NTF:folderSelection
	folderSelection = ""
	
	//Makes a list of all the selected folders and matched subfolders
	String folderList = ""
	For(i=0;i<DimSize(listWave,0);i+=1)
	
		//reset the subfolder and matched folder lists for each parent folder
		String subFolderList = ""	//all subfolders
		String relFolderList = "" //matched subfolders
		
		//For each selected Folder
		If(selWave[i] == 1)
			//Save the folder selection
			folderSelection += cdf + listWave[i] + ";"
			
			//Get list of all subfolders within the selected parent folder
			Variable numSubFolders = CountObjects(cdf + listWave[i],4)
			For(j=0;j<numSubFolders;j+=1)
				subFolderList += GetIndexedObjName(cdf + listWave[i],4,j) + ";"
			EndFor
			
			//match all subfolders
			//Relative Folder doesn't have to be exact match, but can accept search terms
			//Also handles boolean logic for relative folder matches
			Variable numOrs = ItemsInList(filters.relFolder,"||")
			For(j=0;j<numOrs;j+=1)
				String folderMatchStr = StringFromList(j,filters.relFolder,"||")
				relFolderList += ListMatch(subFolderList,folderMatchStr,";")
			EndFor		
			
			//append each subfolder that has matched to the folderList
			If(ItemsInList(relFolderList,";") > 0)
				For(j=0;j<ItemsInList(relFolderList,";");j+=1)
					String matchedSubFolder = ":" + StringFromList(j,relFolderList,";")
					folderList +=  cdf + listWave[i] + matchedSubFolder + ";"
				EndFor
			Else
				folderList +=  cdf + listWave[i] + ";"
			EndIf
		EndIf
	EndFor
	return folderList
End

//Uses the input folder list to search those folders
//for matched waves, as defined in the filters structure
//Matched waves and their full paths are returned in the filters structure (filters.name, filters.path)
Function/S FindMatchedWaves(filters,folderList)
	STRUCT filters &filters
	String folderList
	
	DFREF NTF = root:Packages:NT
	SVAR cdf = NTF:currentDataFolder
	
	Variable i,j,count,numORs
	
	Variable numFolders = ItemsInList(folderList,";")
	String folder,item,fullPathItemList,tempList,itemList,masterItemList
	
	//Fill out the wave match list box for each folder in the folder list
	If(numFolders == 0)
		numFolders = 1
	EndIf
	
	count = 0
	
	//Reset the lists that will hold the matched wave names and full paths
	filters.path = ""
	filters.name = ""
	
	For(i=0;i<numFolders;i+=1)
		itemList = "" //reset item list for each folder
		
		If(!strlen(folderList))
			//If nothing is selected, only search the current data folder
			folder = cdf 
		Else
			folder = StringFromList(i,folderList,";") + ":"
		EndIf
		
		//Check if the folder exists
		If(DataFolderExists(folder))
			SetDataFolder $folder
		Else
			continue
		EndIf
		
		//Are there any OR statements in the match string?
		numORs = ItemsInList(filters.match,"||")
		
		//Match list from the current folder in the loop
		itemList = ReplaceString(";",StringFromList(1,DataFolderDir(2),":"),"")
		itemList = TrimString(itemList)
		
		//Set empty temporary list
		tempList = ""
		
		//Match each OR element in the match string separately 
		For(j=0;j<numORs;j+=1)
			String matchStr = StringFromList(j,filters.match,"||")
			tempList += ListMatch(itemList,matchStr,",")
		EndFor
		
		//alphanumeric sort of the matched waves
		itemList = SortList(tempList,",",16)
		
		//get rid of duplicate entries that might occur
		itemList = RemoveDuplicateList(itemList,";")
		
		//NOT-match list
		//These matches get removed from the current match list
		numORs = ItemsInList(filters.notMatch,"||")
		For(j=0;j<numORs;j+=1)
			If(strlen(filters.notMatch))
				matchStr = StringFromList(j,filters.notMatch,"||")
				itemList = ListMatch(itemList,"!*" + matchStr,",")
			EndIf
		EndFor
		
		//update the master list, which has
		filters.name += itemList
		If(strlen(itemList))
			For(j=0;j<ItemsInList(itemList,",");j+=1)
				filters.path += folder + StringFromList(j,itemList,",") + ","
			EndFor
		Else
			filters.path += ""
		EndIf
		
	EndFor
	
	//return to original data folder
	SetDataFolder $cdf
End

//Fills the listbox waves with the contents of the filters.name and filters.path structure
Function UpdateListBoxWaves(filters,listWave,selWave)
	STRUCT filters &filters
	Wave/T listWave
	Wave selWave
	Variable j
	String item="",path=""
	
	//Set the listWave with the new matched waves
	//Uses 3D list wave:
	//First dimension is wave names
	//Third dimension is wave full paths		
	Redimension/N=(ItemsInList(filters.name,",")) selWave
	Redimension/N=(ItemsInList(filters.name,","),1,2) listWave
	
	For(j=0;j<ItemsInList(filters.name,",");j+=1)
		item = StringFromList(j,filters.name,",")
		path = StringFromList(j,filters.path,",")
		
		listWave[j][0][0] = item
		listWave[j][0][1] = path
	EndFor
End


//Applies the underscore position filters to the wave list
Function ApplyFilters(filters)
	STRUCT filters &filters
	Variable i,j,pos,numTerms,numWaves = ItemsInList(filters.name,",")
	String term = "",item = "",name = ""
	String matchList = "",filterTerms = ""
	
	String list_name = "",list_path = ""
	
	//Loop through each underscore position
	For(pos=0;pos<4;pos+=1)	
		switch(pos)
			case 0: //prefix
				filterTerms = resolveListItems(filters.prefix,";")
				break
			case 1: //group
				filterTerms = resolveListItems(filters.group,";")
				break
			case 2: //series
				filterTerms = resolveListItems(filters.series,";")
				break
			case 3: //sweep
				filterTerms = resolveListItems(filters.sweep,";")
				break
			case 4: //trace
				filterTerms = resolveListItems(filters.trace,";")
				break
		endswitch 
		
		//Move to next if there aren't any terms in the current underscore position
		If(!strlen(filterTerms))
			continue
		EndIf
		
		//Resolve any hyphenations,etc. 
		filterTerms = resolveListItems(filterTerms,";")
		
		numTerms = ItemsInList(filterTerms,";")
		
		//Loop through each wave name prefix
		//Go backwards because we're removing from the list as we go
		For(j=numWaves-1;j>-1;j-=1) 
			//current wave name prefix
			name = StringFromList(j,filters.name,",")
			
			//Reset the filter result for each wave
			//This marks 1 for a match, 0 for not match
			//If the string contains a 1 after all search terms, it passes through
			String filterResult = ""
			
			//Loop through each of the prefix search terms
			For(i=0;i<numTerms;i+=1)
				//current search term
				term = StringFromList(i,filterTerms,";")
				
				//Does the prefix match the search term?
				If(stringmatch(StringFromList(pos,name,"_"),term))
					filterResult += "1"
					break
				EndIf
			EndFor
			
			//Check filterResult for any '1', which means one of the terms matched
			If(!stringmatch(filterResult,"*1*"))
				filters.name = RemoveListItem(j,filters.name,",")
				filters.path = RemoveListItem(j,filters.path,",")
			EndIf
		EndFor
	EndFor
End

//Groups the waves in the filters lists (filters.name,filters.path) according to 
//the indicated wave grouping in the structure (filters.wg)
Function SetWaveGrouping(filters,listWave,selWave)
	STRUCT filters &filters
	Wave/T listWave
	Wave selWave
	
	DFREF NTF = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	
	SVAR listFocus = NTF:listFocus
	
	Variable numWaves = ItemsInList(filters.name,",")
	Variable i,j,numGroupings = ItemsInList(filters.wg,",")
	
	//Extract flags
	String itemStr = "",flag = "",value=""
	Variable numItems = ItemsInList(filters.wg,"/")
	
	//First reset to the BASE data set or ungrouped WaveMatchList
	
	If(!cmpstr(listFocus,"DataSet"))
		RemoveWaveGroupings(listWave,"DataSet")
		Wave DataSetLB_SelWave = NTD:DataSetLB_SelWave
		Redimension/N=(DimSize(listWave,0)) DataSetLB_SelWave
	ElseIf(!cmpstr(listFocus,"WaveMatch"))
		RemoveWaveGroupings(listWave,"WaveMatch")
		Wave MatchLB_SelWave = NTF:MatchLB_SelWave
		Redimension/N=(DimSize(listWave,0)) MatchLB_SelWave
	EndIf
	
	//empty grouping - return to BASE data set
	If(numItems == 0)
		If(!cmpstr(listFocus,"DataSet"))
			RemoveWaveGroupings(listWave,"DataSet")
//			Wave/T DS_BASE = GetDataSetWave(GetDSName(),"BASE")
//			Wave/T DS_ORG = GetDataSetWave(GetDSName(),"ORG")
//			matchContents(DS_BASE,listWave)
//			matchContents(DS_BASE,DS_ORG)
//			Redimension/N=(DimSize(listWave,0)) selWave
		EndIf
	EndIf
	
	For(i=0;i<numItems;i+=1)
		itemStr = StringFromList(i,filters.wg,"/")
		
		If(!strlen(itemStr))
			continue
		EndIf
		
		flag = StringFromList(0,itemStr,"=")
		value = StringFromList(1,itemStr,"=")
		
		//This condition indicates that there is an entry without a flagged designation
		//This means we're doing a position grouping by number
		If(strlen(flag) && !strlen(value))
			value = flag
		EndIf
		
		//Itemize the list ('1-5' becomes '1,2,3,4,5')
		If(strlen(value))
			value = resolveListItems(value,",")
		EndIf
		
		//filter or sort the data set, depending on the flag
		strswitch(flag)
			case "WG":
				WaveGroup_Position(listWave,selWave,value)
				break
			case "WSI":
				WaveGroup_WSI(listWave,selWave,value)
				break
			case "WSN":
				WaveGroup_WSN(listWave,selWave,value)
				break
			case "B":
				WaveGroup_Block(listWave,selWave,value)
				break
			case "S":
 				WaveGroup_Stride(listWave,selWave,value)
				break
			default:
 				WaveGroup_Position(listWave,selWave,value)
				break
		endswitch
		
	EndFor
End

//Removes all wave groupings from a list wave
//Useful for clearing BASE data sets
Function RemoveWaveGroupings(listWave,whichList)
	Wave/T listWave
	String whichList //WaveMatch or DataSet
	Variable i,j
	DFREF NTD = root:Packages:NT:DataSets
	DFREF NTF = root:Packages:NT

	strswitch(whichList)
		case "DataSet":
			//group all together
			Wave/T DS_BASE = GetDataSetWave(GetDSName(),"BASE")
			Wave/T DS_ORG = GetDataSetWave(GetDSName(),"ORG")
			Wave DataSetLB_SelWave = NTD:DataSetLB_SelWave
			
			//Remove the groupings from the ORG data set version,
			//Returns the waves to original ordering according to the BASE data set
			//while retaining any filtering that has been performed.
			Variable count = 0
			String paths = TextWaveToStringList(DS_ORG,";",layer=1)
			For(i=0;i<DimSize(DS_BASE,0);i+=1)
				If(stringmatch(paths,"*" + DS_BASE[i][0][1] + "*"))
					Redimension/N=(count + 1,1,2) DS_ORG
					DS_ORG[count][0][] = DS_BASE[i][0][r]
					count += 1
				EndIf
			EndFor
			
//			matchContents(DS_BASE,listWave)
//			matchContents(DS_BASE,DS_ORG)
//			Redimension/N=(DimSize(listWave,0)) DataSetLB_SelWave
		
			break
		case "WaveMatch":
			
//			getWaveMatchList()
//			
//			//Apply the filters for each underscore position, starting with prefix on the left
//			ApplyFilters(filters)
//			
//			//Update the listbox waves - required here. Wave Grouping code uses the actual list box waves
//			UpdateListBoxWaves(filters,listWave,selWave)
			
			break
	endswitch
End

//Groups the input listWave into wave sets by underscore position
//Also can group by folder and concatenate listwaves
Function WaveGroup_Position(listWave,selWave,value)
	Wave/T listWave
	Wave selWave
	String value //wave grouping terms
	
	Variable numWaves = DimSize(listWave,0)
	Variable numGroupings = ItemsInList(value,",")
	Variable i,j,k,m,group,wsn,firstWSN
	
	For(i=0;i<numGroupings;i+=1)
		group = str2num(StringFromList(i,value,","))
		
		switch(group)
			case -2:
				//group all together
				For(j=DimSize(listWave,0)-1;j>-1;j-=1) //go backwards
					If(stringmatch(listWave[j],"*WAVE SET*"))
						DeletePoints/M=0 j,1,listWave,selWave
					EndIf
				EndFor
				break
			case -1:
				//group by folder
				Variable numWaveSets = GetNumWaveSets(listWave)
				Variable whichWSN = 0
				
				//Master temporary wave to build up the new wave groupings
				Make/T/FREE/N=0 tempWave
	
				For(j=0;j<numWaveSets;j+=1)
					//extract each wave set
					Wave/T ws = GetWaveSet(listWave,j)
					
					//This allows additional wave sets to continue
					//stacking on previous wave sets
					
					Variable startRow = DimSize(tempWave,0) - whichWSN
					If(startRow < 0)
						startRow = 0
					EndIf
					
					//Sort using the folder path
//					SortColumns/KNDX=1 sortWaves={ws}
					
					String prevSubFolder = ""
					
					//Separate sorted waves according to their folder paths.
					For(k=0;k<DimSize(ws,0);k+=1)
						String subFolder = ParseFilePath(0,ws[k][0][1],":",1,1)
						
						Variable size = DimSize(tempWave,0)

						If(!cmpstr(subFolder,prevSubFolder))
							size = DimSize(tempWave,0)
							Redimension/N=(size + 1,1,2) tempWave //add a row to temp wave
							tempWave[k + whichWSN + startRow][0][] = ws[k][0][r]
						Else
							//Start a new wave set
							size = DimSize(tempWave,0)
							Redimension/N=(size + 1,1,2) tempWave //add a row to temp wave
							tempWave[k + whichWSN + startRow][0][] = "----WAVE SET " + num2str(whichWSN) + "----"
							whichWSN += 1
							prevSubFolder = subFolder
							k -= 1
						EndIf
						
						prevSubFolder = subFolder
					EndFor
				EndFor
				
				//Push the sorted waves onto the listbox
				matchContents(tempWave,listWave)
				Redimension/N=(DimSize(tempWave,0)) selWave
				break
			default:
				//Group by underscore position
				numWaveSets = GetNumWaveSets(listWave)
				whichWSN = 0
				
				//Master temporary wave to build up the new wave groupings
				Make/T/FREE/N=(0,1,2) tempWave
				
				For(j=0;j<numWaveSets;j+=1)
					Variable baseWSN = whichWSN
					
					//extract each wave set
					Wave/T ws = GetWaveSet(listWave,j)
				
					startRow = DimSize(tempWave,0) - whichWSN
					If(startRow < 0)
						startRow = 0
					EndIf
				
					//Separate sorted waves according to their underscore position
					String matchedTerms = ""
					
					For(k=0;k<DimSize(ws,0);k+=1)

						//Take the wave name, not the full path
						String term = StringFromList(group,ws[k][0][0],"_")
						
						//In case the is no term in that underscore position
						If(!strlen(term))
							term = "xxxxx" //just never use this as an actual wave name
						EndIf
						
						size = DimSize(tempWave,0)
						
						//Try to match each term with existing wave set terms
						wsn = WhichListItem(term,matchedTerms,";")
						
						If(wsn == -1)
							//New term = Make new wave set.
							//Add two points, one for the WSN marker, and one for the first wave
							size = DimSize(tempWave,0)
							InsertPoints/M=0 size,2,tempWave
							tempWave[size][0][] = "----WAVE SET " + num2str(whichWSN) + "----"
							tempWave[size + 1][0][] = ws[k][0][r]
							whichWSN += 1
							matchedTerms += term + ";"
						Else
							//Term matches one thats already defined in a wave set
							//Allocate that wave to the correct wave set
							
							//Find the WSN marker of the wave set one larger than the one we want
							//This finds the last row of the wave set we are allocating to.
							Variable index = tableMatch("*WAVE SET*" + num2str(wsn + baseWSN + 1) + "*",tempWave)
							
							//If it's the last wave set, index will be -1
							//Add the matched wave to the end of the tempWave
							If(index == -1)
								index = DimSize(tempWave,0)
							EndIf
							
							//Insert the matched wave into the last slot in that wave set block
							InsertPoints/M=0 index,1,tempWave
							tempWave[index][0][] = ws[k][0][r]
							
						EndIf
					EndFor
				EndFor
				
				//Push the sorted waves onto the listbox
				matchContents(tempWave,listWave)
				Redimension/N=(DimSize(tempWave,0)) selWave
				
				break
		endswitch
	EndFor
End

//Groups the waves into waves sets by BLOCK 
//Using the flag /B=8 will make wave set groups in chunks of 8
Function WaveGroup_Block(listWave,selWave,value)
	Wave/T listWave
	Wave selWave
	String value
	
	Variable numWaves = DimSize(listWave,0)
	Variable numGroupings = ItemsInList(value,",")
	
	Variable i,j,index,wsCount,nextBlock,size
	
	Variable numWaveSets = GetNumWaveSets(listWave)
	
	Variable blockSize = str2num(StringFromList(0,value,","))
	
	//Master temporary wave to build up the new wave groupings
	Make/T/FREE/N=(0,1,2) tempWave
	index = 0
	wsCount = 0
	
	For(j=0;j<numWaveSets;j+=1)
		//extract each wave set
		Wave/T ws = GetWaveSet(listWave,j)
		Variable waveSetSize = DimSize(ws,0)
		
		nextBlock = 0
		For(i=0;i<waveSetSize;i+=1)
			size = DimSize(tempWave,0)
			//Add new wave set marker
			If(i == nextBlock)
				InsertPoints/M=0 size,2,tempWave
				tempWave[index][0][] = "----WAVE SET " + num2str(wsCount) + "----"
				index += 1
				tempWave[index][0][] = ws[i][0][r]
				index += 1
				wsCount += 1
				nextBlock += blockSize
			Else
				//Add wave to the current block
				InsertPoints/M=0 size,1,tempWave
				tempWave[index][0][] = ws[i][0][r]
				index += 1
			EndIf
		EndFor
	EndFor
	
	//Push the sorted waves onto the listbox
	matchContents(tempWave,listWave)
	Redimension/N=(DimSize(tempWave,0)) selWave
End

//Groups the waves into waves sets by STRIDE 
//Using the flag /S=8 will make every 8th wave in the same wave set
Function WaveGroup_Stride(listWave,selWave,value)
	Wave/T listWave
	Wave selWave
	String value
	
	Variable numWaves = DimSize(listWave,0)
	Variable numGroupings = ItemsInList(value,",")
	
	Variable i,j,count,index,wsCount,nextBlock,size
	
	Variable numWaveSets = GetNumWaveSets(listWave)
	
	Variable stride = str2num(StringFromList(0,value,","))
	
	//Master temporary wave to build up the new wave groupings
	Make/T/FREE/N=(0,1,2) tempWave
	index = 0
	wsCount = 0
	
	For(j=0;j<numWaveSets;j+=1)
		//extract each wave set
		Wave/T ws = GetWaveSet(listWave,j)
		Variable waveSetSize = DimSize(ws,0)
				
		Variable baseWSN = wsCount
		
		//Add all the wave set markers we'll need 
		For(i=0;i<stride;i+=1)
			size = DimSize(tempWave,0)
			
			InsertPoints/M=0 size,1,tempWave
			tempWave[index][0][] = "----WAVE SET " + num2str(wsCount) + "----"
			
			wsCount += 1
			index += 1
			count = 0
			Do
				If(i + count >= DimSize(ws,0))
					break
				EndIf
				InsertPoints/M=0 index,1,tempWave
				tempWave[index][0][] = ws[i + count][0][r]
				count += stride
				index += 1
			While(count < waveSetSize)
		EndFor
		
	EndFor
	
	//Detect empty wavesets and delete them
	numWaveSets = GetNumWaveSets(tempWave)
	For(i=numWaveSets-1;i>-1;i-=1) //go backwards
		If(isEmptyWaveSet(tempWave,i))
			DeleteWaveSet(tempWave,i)
		EndIf
	EndFor
	
	//Push the sorted waves onto the listbox
	matchContents(tempWave,listWave)
	Redimension/N=(DimSize(tempWave,0)) selWave
End

//Filters the waves in the listbox by their wave set index (WSI).
//For WSI=0-4, only the 1st through 5th (zero offset) waves in each waveset will remain
Function WaveGroup_WSI(listWave,selWave,value)
	Wave/T listWave
	Wave selWave
	String value
	
	//number waves in the entire data set
	Variable i,j,baseIndex,numWaves = DimSize(listWave,0)
	
	//list comprehension (mixes of hyphens and commas are resolved into a comma-separated list)
	value = resolveListItems(value,",")
	Variable numItems = ItemsInList(value,",")
	
	Variable numWaveSets = GetNumWaveSets(listWave)
	
	For(j=numWaveSets-1;j>-1;j-=1)
		//extract each wave set
		Wave/T ws = GetWaveSet(listWave,j)
		Variable waveSetSize = DimSize(ws,0)
		
		//Start of the wave set in the list wave
		baseIndex = tableMatch("*WAVE SET*" + num2str(j) + "*",listWave) + 1
		If(baseIndex == -1)
		 	continue
		EndIf
		
		For(i=waveSetSize-1;i>-1;i-=1) //go backwards
			
			//Not one of the indicated WSIs
			If(WhichListItem(num2str(i),value,",") == -1)
				DeletePoints/M=0 baseIndex + i,1,listWave
			EndIf

		EndFor
	EndFor	
	
	//Detect empty wavesets and delete them
	numWaveSets = GetNumWaveSets(listWave)
	For(i=numWaveSets-1;i>-1;i-=1) //go backwards
		If(isEmptyWaveSet(listWave,i))
			DeleteWaveSet(listWave,i)
		EndIf
	EndFor
	
	Redimension/N=(DimSize(listwave,0)) selWave
End

//Filters the waves in the listbox by their wave set number (WSN).
//For WSN=0-4, only the 1st through 5th (zero offset) wave sets will remain
Function WaveGroup_WSN(listWave,selWave,value)
	Wave/T listWave
	Wave selWave
	String value
	
	//list comprehension (mixes of hyphens and commas are resolved into a comma-separated list)
	value = resolveListItems(value,",")
	Variable i,numWaveSets,item,numItems
	
	numItems = ItemsInList(value,",")
	numWaveSets = GetNumWaveSets(listWave)
	
	//No wave set organization here, so call the first waveset 0
	If(!stringmatch(listWave[0],"*WAVE SET*"))
		//delete the waveset if we're not keeping the 0th wave set
		If(WhichListItem("0",value,",") == -1)
			DeleteWaveSet(listWave,0)
			Redimension/N=(DimSize(listwave,0)) selWave
			numWaveSets = GetNumWaveSets(listWave)
		EndIf
	EndIf
	
	For(i=numWaveSets-1;i>-1;i-=1) //go backwards
		If(WhichListItem(num2str(i),value,",") == -1)
			DeleteWaveSet(listWave,i)
		EndIf
	EndFor
	
	Redimension/N=(DimSize(listwave,0)) selWave
End


//Takes a list of items, and removes all the duplicate items
Function/S RemoveDuplicateList(theList,separator)
	String theList,separator
	Variable i,j,size,checkpt
	String item
	
	checkpt = -1
	size = ItemsInList(theList,separator)
	For(i=0;i<size;i+=1)
		item = StringFromList(i,theList,separator)
		For(j=0;j<size;j+=1)
			//Skip the item being tested so it isn't flagged as a duplicate
			If(j == i)
				continue
			EndIf
			//Duplicate found
			If(cmpstr(item,StringFromList(j,theList,separator)) == 0)
				theList = RemoveListItem(j,theList,separator)
				size = ItemsInList(theList,separator)
				//restarts the loop
				i = checkpt	
				break
			ElseIf(j == size - 1) //no duplicates found for that item
				checkpt += 1
			EndIf
		EndFor
	EndFor
	return theList
End

//Updates the Wave Match,NOT-match,relativeFolder search terms with the values in the GUI controls
Function SetSearchTerms(filters)
	STRUCT filters &filters
	DFREF NTF = root:Packages:NT
	
	//Set the structure SVARs
	SetFilterStructure(filters,"")
	
	ControlInfo/W=NT waveNotMatch
	filters.notMatch = S_Value
	
	ControlInfo/W=NT waveMatch
	filters.match = S_Value
	
	ControlInfo/W=NT relativeFolderMatch
	filters.relFolder = S_Value			
	
	ControlInfo/W=NT waveGrouping
	filters.wg = S_Value	
	
	ControlInfo/W=NT prefixGroup
	filters.prefix = S_Value
	
	ControlInfo/W=NT groupGroup
	filters.group = S_Value
	
	ControlInfo/W=NT seriesGroup
	filters.series = S_Value
	
	ControlInfo/W=NT sweepGroup
	filters.sweep = S_Value
	
	ControlInfo/W=NT traceGroup
	filters.trace = S_Value
	
End

//Returns list with full path of the selected items in the WavesListBox in the Navigator
Function/S getSelectedItems()
	DFREF NTF = root:Packages:NT
	//Selection and List waves
	Wave WavesLB_SelWave = NTF:WavesLB_SelWave
	Wave/T WavesLB_ListWave = NTF:WavesLB_ListWave
	
	SVAR cdf = NTF:currentDataFolder
	Variable i
	
	String selWaveList = ""

	For(i=0;i<DimSize(WavesLB_ListWave,0);i+=1)
		If(WavesLB_SelWave[i] == 1)
			selWaveList += cdf + WavesLB_ListWave[i] + ";"
		EndIf
	EndFor
	
	return selWaveList
End

//Adjusts wave2 to have the same dimensions and contents as wave1
Function matchContents(wave1,wave2)
	Wave/Z wave1,wave2
	Variable xdim,ydim,zdim
	
	//Check wave existence
	If(!WaveExists(wave1) || !WaveExists(wave2))
		print "Input does not exist"
		return -1
	EndIf
	
	//What type of wave is wave1?
	Variable type1 = WaveType(wave1,1)
	Variable type2 = WaveType(wave2,1)
	
	//Check that waves are the same type
	If(type1 != type2)
		print "Waves must be of the same type"
		return -1
	EndIf
	
	//Get dimensions
	xdim = DimSize(wave1,0)
	ydim = DimSize(wave1,1)
	zdim = DimSize(wave1,2)
	
	Redimension/N=(xdim,ydim,zdim) wave2
	
	switch(type1)
		case 0://null
			return 0
			break
		case 1://numeric
			Wave refWave_num = wave1
			Wave matchWave_num = wave2
			
			matchWave_num = refWave_num
			break
		case 2://text
			Wave/T refWave_text = wave1
			Wave/T matchWave_text = wave2
			
			matchWave_text = refWave_text
			break
	endswitch

	return 1
End

//Clears all filters, groupings, and matches, and rebuilds the wave match list box
Function clearFilterControls([filtersOnly])
	Variable filtersOnly //if we only want to clear the filters, but not the wave grouping or match boxes
	
	STRUCT filters filters
	
	DFREF NTF = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	
	SVAR listFocus = NTF:listFocus
	
	If(ParamIsDefault(filtersOnly))
		filtersOnly = 0
	EndIf
	
	String controls = "prefixGroup;groupGroup;seriesGroup;sweepGroup;traceGroup;waveGrouping;"
	
	If(!cmpstr(listFocus,"WaveMatch"))
		controls += "waveMatch;waveNotMatch;relativeFolderMatch;"
	EndIf
	
	Variable i,items = ItemsInList(controls,";")
	
	For(i=0;i<items;i+=1)
		If(filtersOnly && i > 4)
			return 0
		EndIf
		SetVariable $StringFromList(i,controls,";") win=NT,value=_STR:""
	EndFor
	
	If(!cmpstr(listFocus,"DataSet"))
		//Return to the BASE data set
		Wave/T DataSetLB_ListWave = NTD:DataSetLB_ListWave
		Wave DataSetLB_SelWave = NTD:DataSetLB_SelWave
		String dsName = GetDSName()
		
		//No data set selected or none exist
		If(!strlen(dsName))
			return 0
		EndIf
		
		Wave/T DS_BASE = GetDataSetWave(dsName,"BASE")
		Wave/T DS_ORG = GetDataSetWave(dsName,"ORG")
		
		matchContents(DS_BASE,DataSetLB_ListWave)
		Redimension/N=(DimSize(DataSetLB_ListWave,0)) DataSetLB_SelWave
		matchContents(DS_BASE,DS_ORG)
		
		//save the filter/grouping selection
		SetSearchTerms(filters)
		saveFilterSettings("DataSet")
	Else
		//Update the WaveMatch list box
		getWaveMatchList()
	EndIf
End

//Draws dots around the selected list box, toggles the focus betwen WaveMatch and DataSet list boxes
//Whichever list box has the focus is the one that the filter/grouping controls will affect.
Function changeFocus(selection,switchFilterSettings)
	String selection //left or right
	Variable switchFilterSettings//switchFilterSettings = 1 to save/recall filters
	
	DFREF NTF = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	
	SVAR listFocus = NTF:listFocus
	
	//return if the selection wasn't changed
	If(!cmpstr(selection,listFocus))
		return 0
	EndIf
	
	SetDrawLayer/W=NT UserBack
	//Delete only the selection dots, not the rest of the draw layer
	DrawAction/W=NT/L=UserBack getgroup=selectionDots
	DrawAction/W=NT/L=UserBack delete=V_startPos,V_endPos
	
	strswitch(selection)
		case "WaveMatch":
			SetDrawEnv/W=NT gname=selectionDots,gstart
			SetDrawEnv/W=NT linethick=0,fillfgc= (3,52428,1,floor(65535 * 1.0))
			DrawOval/W=NT 45,108,50,113
			SetDrawEnv/W=NT linethick=0,fillfgc= (3,52428,1,floor(65535 * 0.8))
			DrawOval/W=NT 35,108,40,113
			SetDrawEnv/W=NT linethick=0,fillfgc= (3,52428,1,floor(65535 * 0.6))
			DrawOval/W=NT 25,108,30,113
			SetDrawEnv/W=NT linethick=0,fillfgc= (3,52428,1,floor(65535 * 0.4))
			DrawOval/W=NT 15,108,20,113
			SetDrawEnv/W=NT linethick=0,fillfgc= (3,52428,1,floor(65535 * 0.2))
			DrawOval/W=NT 5,108,10,113
			
			//This ones extra, to compensate for some Igor bug messing with my object groups?
			SetDrawEnv/W=NT linethick=0,fillfgc= (3,52428,1,floor(65535 * 1.0))
			DrawOval/W=NT 45,108,50,113
			
			SetDrawEnv/W=NT linethick=0,fillfgc= (3,52428,1,floor(65535 * 1.0))
			DrawOval/W=NT 133,108,138,113
			SetDrawEnv/W=NT linethick=0,fillfgc= (3,52428,1,floor(65535 * 0.8))
			DrawOval/W=NT 143,108,148,113
			SetDrawEnv/W=NT linethick=0,fillfgc= (3,52428,1,floor(65535 * 0.6))
			DrawOval/W=NT 153,108,158,113
			SetDrawEnv/W=NT linethick=0,fillfgc= (3,52428,1,floor(65535 * 0.4))
			DrawOval/W=NT 163,108,168,113
			SetDrawEnv/W=NT linethick=0,fillfgc= (3,52428,1,floor(65535 * 0.2))
			DrawOval/W=NT 173,108,178,113
			
			//rectangle selection
			SetDrawEnv/W=NT linethick= 0,linefgc= (3,52428,1),fillfgc= (3,52428,1,32768)
			DrawRect/W=NT 3,117,180,443
			
			SetDrawEnv/W=NT gstop
			
			If(switchFilterSettings)
				//Save the current filters/grouping settings before changing focus
				saveFilterSettings("DataSet")
				
				//Recall any saved filter settings for the WaveMatch list box
				recallFilterSettings("WaveMatch")
			EndIf
						
			listFocus = "WaveMatch"
			break
		case "DataSet":
			Variable offset = 150
			Variable offset2 = 144
			SetDrawEnv/W=NT gname=selectionDots,gstart
			
			SetDrawEnv/W=NT linethick=0,fillfgc= (3,52428,1,floor(65535 * 1.0))
			DrawOval/W=NT 69+offset,108,74+offset,113
			SetDrawEnv/W=NT linethick=0,fillfgc= (3,52428,1,floor(65535 * 0.8))
			DrawOval/W=NT 59+offset,108,64+offset,113
			SetDrawEnv/W=NT linethick=0,fillfgc= (3,52428,1,floor(65535 * 0.6))
			DrawOval/W=NT 49+offset,108,54+offset,113
			SetDrawEnv/W=NT linethick=0,fillfgc= (3,52428,1,floor(65535 * 0.4))
			DrawOval/W=NT 39+offset,108,44+offset,113
			SetDrawEnv/W=NT linethick=0,fillfgc= (3,52428,1,floor(65535 * 0.2))
			DrawOval/W=NT 29+offset,108,34+offset,113
			
			//This ones extra, to compensate for some Igor bug messing with my object groups?
			SetDrawEnv/W=NT linethick=0,fillfgc= (3,52428,1,floor(65535 * 1.0))
			DrawOval/W=NT 69+offset,108,74+offset,113
			
			SetDrawEnv/W=NT linethick=0,fillfgc= (3,52428,1,floor(65535 * 1.0))
			DrawOval/W=NT 169+offset2,108,174+offset2,113
			SetDrawEnv/W=NT linethick=0,fillfgc= (3,52428,1,floor(65535 * 0.8))
			DrawOval/W=NT 179+offset2,108,184+offset2,113
			SetDrawEnv/W=NT linethick=0,fillfgc= (3,52428,1,floor(65535 * 0.6))
			DrawOval/W=NT 189+offset2,108,194+offset2,113
			SetDrawEnv/W=NT linethick=0,fillfgc= (3,52428,1,floor(65535 * 0.4))
			DrawOval/W=NT 199+offset2,108,204+offset2,113
			SetDrawEnv/W=NT linethick=0,fillfgc= (3,52428,1,floor(65535 * 0.2))
			DrawOval/W=NT 209+offset2,108,214+offset2,113
			
			//rectangle selection
			SetDrawEnv/W=NT linethick= 0,linefgc= (3,52428,1),fillfgc= (3,52428,1,32768)
			DrawRect/W=NT 180,117,357,443
			
			SetDrawEnv/W=NT gstop
			
			If(switchFilterSettings)
				//Save the current filters/grouping settings before changing focus
				saveFilterSettings("WaveMatch")
				
				//Recall any saved filter settings for the DataSet list box
				recallFilterSettings("DataSet")
			EndIf
					
			listFocus = "DataSet"
			break
	endswitch
	
	//display the full path to the wave in a text box
	drawFullPathText()
End

//Saves the current match/filter/grouping settings into a string variable
Function saveFilterSettings(selection)
	String selection
	
	DFREF NTF = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	
	SVAR filterSettings = NTF:filterSettings
	
	If(!cmpstr(selection,"WaveMatch"))
		filterSettings = getFilterSettings()
	ElseIf(!cmpstr(selection,"DataSet"))
		Wave/T DS_ORG = GetDataSetWave(GetDSName(),"ORG")
		Wave/T DSNamesLB_ListWave = NTD:DSNamesLB_ListWave
		
		Variable index = GetDSIndex()
		If(index != -1 && WaveExists(DS_ORG))
			String origFilterSettings = StringsFromList("9-13",DSNamesLB_ListWave[index][0][1],";")

			DSNamesLB_ListWave[index][0][1] = getFilterSettings() + origFilterSettings
		EndIf
	EndIf
End


//Recalls match/filter/grouping settings and applies them to the list box
Function/S recallFilterSettings(selection)
	String selection
	STRUCT filters filters
	
	DFREF NTF = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	
	SVAR filterSettings = NTF:filterSettings
	String dsFilters = ""

	SetFilterStructure(filters,"")
	
	If(!cmpstr(selection,"WaveMatch"))
		//WaveMatch list and selection waves
		Wave/T listWave = NTF:MatchLB_ListWave
		Wave selWave = NTF:MatchLB_SelWave
		
		//Fill out the structure with the saved settings
		filters.match = StringFromList(0,filterSettings,";")
		filters.notMatch = StringFromList(1,filterSettings,";")
		filters.relFolder = StringFromList(2,filterSettings,";")
		filters.prefix = StringFromList(3,filterSettings,";")
		filters.group = StringFromList(4,filterSettings,";")
		filters.series = StringFromList(5,filterSettings,";")
		filters.sweep = StringFromList(6,filterSettings,";")
		filters.trace = StringFromList(7,filterSettings,";")
		filters.wg = StringFromList(8,filterSettings,";")
		
		//output the filter structure to a string list for the return value
		String filterSettingStr = getFilterSettings()
		
	ElseIf(!cmpstr(selection,"DataSet"))
		//Get the selected data set ORGANIZED wave
		Wave/T DS_ORG = GetDataSetWave(GetDSName(),"ORG")
		Variable index = GetDSIndex()
		
		//Fill out the structure with the saved settings
		//WaveMatch list and selection waves
		Wave/T listWave = NTD:DataSetLB_ListWave
		Wave selWave = NTD:DataSetLB_SelWave
		
		Wave/T DSNamesLB_ListWave = NTD:DSNamesLB_ListWave
		
		//For data sets with no waves in them, set filters to empty
		If(index == -1 || !WaveExists(DS_ORG) || index > DimSize(DS_ORG,0))
			dsFilters = ";;;;;;;;;"
		ElseIf(DimSize(DSNamesLB_ListWave,0) == 0)
			dsFilters = ";;;;;;;;;"
		Else
			dsFilters = DSNamesLB_ListWave[index][0][1]
		EndIf
		
		//Put the recalled filters into the structure to send them
		//to the filter control updater
		filters.match = StringFromList(0,dsFilters,";")
		filters.notMatch = StringFromList(1,dsFilters,";")
		filters.relFolder = StringFromList(2,dsFilters,";")
		filters.prefix = StringFromList(3,dsFilters,";")
		filters.group = StringFromList(4,dsFilters,";")
		filters.series = StringFromList(5,dsFilters,";")
		filters.sweep = StringFromList(6,dsFilters,";")
		filters.trace = StringFromList(7,dsFilters,";")
		filters.wg = StringFromList(8,dsFilters,";")
		
		filterSettingStr = dsFilters
	Else
		return ""
	EndIf	
	
	//Change the controls
	UpdateFilterControls(filters)
	
	//The actual wave matches shouldn't need to be updated, since the only way we're
	//in this subroutine is from clicking to change focus back to WaveMatch. 
	//Changing the match, notmatch, and relative folder inputs automatically switches
	//focus back to WaveMatch, so we'll never have non-updated match lists when we're clicking
	//to change focus. 
//	ApplyFilters(filters)
//	
//	//Update WaveMatch list box
//	UpdateListBoxWaves(filters,listWave,selWave)
//	
//	//Group waves with the recalled grouping
//	SetWaveGrouping(filters,listWave,selWave)
	
	return filterSettingStr
End

//Recalls the original filtering of the Wave Match that built the data set.
//This data is "lost" by the data set, which takes the original filters to be it's 'BASE' set.
//If there were no original filters, we can assume the user wants to send any new filters
//back to the Wave Match table
Function RecallOriginalFilters(dsFilters)
	String dsFilters
	STRUCT filters filters
	
	SetFilterStructure(filters,"")

	
	If(!strlen(StringFromList(3,dsFilters,";")))
		filters.prefix = StringFromList(9,dsFilters,";")
	Else
		filters.prefix = StringFromList(3,dsFilters,";")
	EndIf
	
	If(!strlen(StringFromList(4,dsFilters,";")))
		filters.group = StringFromList(10,dsFilters,";")
	Else
		filters.group = StringFromList(4,dsFilters,";")
	EndIf
	
	If(!strlen(StringFromList(5,dsFilters,";")))
		filters.series = StringFromList(11,dsFilters,";")
	Else
		filters.series = StringFromList(5,dsFilters,";")
	EndIf
	
	If(!strlen(StringFromList(6,dsFilters,";")))
		filters.sweep = StringFromList(12,dsFilters,";")
	Else
		filters.sweep = StringFromList(6,dsFilters,";")
	EndIf	
	
	If(!strlen(StringFromList(7,dsFilters,";")))
		filters.trace = StringFromList(13,dsFilters,";")
	Else
		filters.trace = StringFromList(7,dsFilters,";")
	EndIf	
	
	
	//Change the controls
	UpdateFilterControls(filters)
End

//Takes the current contents of the filters structure,
//and updates all the controls, except for the wave matching controls
Function UpdateFilterControls(filters)
	STRUCT filters &filters
	
	SetVariable prefixGroup win=NT,value=_STR:filters.prefix
	SetVariable groupGroup win=NT,value=_STR:filters.group
	SetVariable seriesGroup win=NT,value=_STR:filters.series
	SetVariable sweepGroup win=NT,value=_STR:filters.sweep
	SetVariable traceGroup win=NT,value=_STR:filters.trace	
	SetVariable waveGrouping win=NT,value=_STR:filters.wg	
	
	SetVariable waveMatch win=NT,value=_STR:filters.match
	SetVariable waveNotMatch win=NT,value=_STR:filters.notMatch
	SetVariable relativeFolderMatch win=NT,value=_STR:filters.relFolder
End

//Selects the folders in the folder list in the Navigator list box
Function SelectFolder(folderList)
	String folderList
	Variable i,j,numFolders = ItemsInList(folderList,";")
	
	DFREF NTF = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	
	SVAR cdf = NTF:currentDataFolder
	
	//Data Set Name wave list and filter info
	Wave/T DSNamesLB_ListWave =NTD:DSNamesLB_ListWave
	
	//Folder list and selection waves
	Wave/T FolderLB_ListWave = NTF:FolderLB_ListWave
	Wave FolderLB_SelWave = NTF:FolderLB_SelWave
	
	String folder="",parent="",child="",relFolder="",filters=""
	
	//Is there a relative folder indicated for this data set?
	Variable index = GetDSIndex()
	If(index == -1)
		return -1
	EndIf
	
	
	filters = DSNamesLB_ListWave[index][0][1]
	relFolder = StringFromList(2,filters,";")
	
	//reset the selection wave
	FolderLB_SelWave = 0
	
	//Original parent folder
	folder = StringFromList(0,folderList,";")
	parent = ParseFilePath(1,folder,":",1,0)
	SetDataFolder $parent
	cdf = parent
	
	//Fill out the folder table from the parent folder
	GetFolders()
	
	//Fill out the waves in the parent folder in the Navigator Waves list box
	getFolderWaves()
	
	
	For(i=0;i<numFolders;i+=1)
		folder = StringFromList(i,folderList,";")
		child = ParseFilePath(0,folder,":",1,0)
		
		//Select the folder
		index = tableMatch(child,FolderLB_ListWave)
		
		If(index != -1)
			FolderLB_SelWave[index] = 1
		EndIf
	EndFor

End

//Redraws the text showing the full path of th selected wave,
//according to which list box is in-focus
Function drawFullPathText()
	DFREF NTF = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	
	SVAR listFocus = NTF:listFocus
	Variable i = 0,row = -1
	
	//Select the list and selection waves
	strswitch(listFocus)
		case "WaveMatch":
			Wave/T listWave = NTF:MatchLB_ListWave
			Wave selWave = NTF:MatchLB_SelWave
			break
		case "DataSet":
			Wave/T listWave = NTD:DataSetLB_ListWave
			Wave selWave = NTD:DataSetLB_SelWave
			break	
	endswitch
	
	//Find the first selected row
	If(DimSize(selWave,0) > 0)
		Do
			If(selWave[i] == 1)
				row = i
				break
			EndIf
			i+=1
		While(i < DimSize(selWave,0))
	EndIf
	
	//no selection, delete text
	If(row == -1)
		DrawAction/W=NT getGroup=fullPathText,delete
		return 0
	EndIf
	
	//Update the text box
	DrawAction/W=NT getGroup=fullPathText,delete	
	SetDrawEnv/W=NT fname=$LIGHT,fstyle=2,fsize=10,gname=fullPathText,gstart
	DrawText/W=NT 14,464,listWave[row][0][1]
	SetDrawEnv/W=NT gstop
	
End	


//Returns a list of the waves to be operated on by a selected command function
Function/S GetWaveList(ds)
	STRUCT ds &ds
	Variable wsn //wave set number
	String list = ""
	
	DFREF NTF = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	
	//Wave Selector status
	SVAR WaveSelectorStr = NTF:WaveSelectorStr
	SVAR cdf = NTF:currentDataFolder
	
	Variable i
	strswitch(ds.name)
		case "Wave Match":
			Wave/T listWave = NTF:MatchLB_ListWave
			break
		case "Navigator":
			Wave/T WavesLB_ListWave = NTF:WavesLB_ListWave
			Wave selWave = NTF:WavesLB_SelWave
				
			Duplicate/FREE/T WavesLB_ListWave,listWave
			For(i=DimSize(selWave,0) - 1;i > -1;i-=1) //go backwards
				If(selWave[i] != 1)
					DeletePoints/M=0 i,1,listWave
				Else
					listWave[i] = cdf + listWave[i]
				EndIf
			EndFor

			break
		default:
			//Data Set
			Wave/T listWave = GetDataSetWave(ds.name,"ORG")
			break
	endswitch
	
	Wave/T ws = GetWaveSet(listWave,ds.wsn)
	If(!WaveExists(ws))
		return ""
	EndIf
	
	list = TextWaveToStringList(ws,";",layer=1)
	
	return list
End

//Returns info about the data set
//Automatically chooses whatever option is selected in the Wave Selector menu
Function GetDataSetInfo(ds)
	STRUCT ds &ds 

	DFREF NTF = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	
	//Wave Selector status
	SVAR WaveSelectorStr = NTF:WaveSelectorStr
	SVAR cdf = NTF:currentDataFolder
	
	Variable i
	strswitch(WaveSelectorStr)
		case "Wave Match":
			Wave/T listWave = NTF:MatchLB_ListWave
			break
		case "Navigator":
			Wave/T WavesLB_ListWave = NTF:WavesLB_ListWave
			Wave selWave = NTF:WavesLB_SelWave
				
			Duplicate/FREE/T WavesLB_ListWave,listWave
			For(i=DimSize(selWave,0) - 1;i > -1;i-=1) //go backwards
				If(selWave[i] != 1)
					DeletePoints/M=0 i,1,listWave
				Else
					listWave[i] = cdf + listWave[i]
				EndIf
			EndFor

			break
		default:
			//Data Set
			Wave/T listWave = GetDataSetWave(WaveSelectorStr,"ORG")
			break
	endswitch
	
	If(DimSize(listWave,0) == 0)
		SVAR ds.paths = NTD:DataSetWaves
		ds.paths = "NULL" //prevents error in 'Run Cmd'
		return -1
	EndIf
	
	//Fill out the data set structure
	Wave/T ds.listWave = listWave
	SVAR ds.name = NTF:WaveSelectorStr
	SVAR ds.paths = NTD:DataSetWaves
	ds.num = GetNumWaveSets(listWave)
	ds.wsn = 0
	ds.wsi = 0
	ds.numWaves = GetNumWaves(listWave,ds.wsn)
	Wave/WAVE ds.waves = GetWaveSetRefs(listWave,ds.wsn)
	ds.paths = GetWaveSetList(listWave,ds.wsn,1)

End

//Fills the structure with information about the current workflow
Function GetWorkFlow(wf)
	STRUCT workflow &wf
	
	Wave/T wf.cmds = root:Packages:NT:workFlowCmds
	wf.numCmds = DimSize(wf.cmds,0) 
	wf.i = 0
End

//Returns string with replaced suffix
Function/S ReplaceSuffix(name,suffix)
	String name,suffix
	
	name = ReplaceListItem(ItemsInList(name,"_")-1,name,"_",suffix)
	return name
End

//Removes low pass trends in the wave, effectively flattening the trace
Function FlattenWave(inputWave)
	Wave inputWave
	
	SetDataFolder GetWavesDataFolder(inputWave,1)
	Make/O/D/N=0 coefs
	Duplicate/O inputWave,filtered
	
	If(DimSize(filtered,0) < 101)
		print "Wave is too short to filter with a 101 length coefficient wave"
		return -1
	EndIf
	
	FilterFIR/DIM=0/HI={0.006,0.01,101}/COEF coefs, filtered;AbortOnRTE
	
	Wave filterWave = filtered
	inputWave = filterWave
	
	WaveStats/Q inputWave
	inputWave -= V_avg

	
	KillWaves filterWave
End

Function ResetAllTimers()
	Variable i
	For(i=0;i<10;i+=1)
		Variable ref = StopMSTimer(i)
	EndFor
End


//Kills wave even if it is a part of a graph or window
Function ReallyKillWaves(w)
  Wave w

  string name=nameofwave(w)
  string graphs=WinList("*",";","WIN:1") // A list of all graphs
  variable i,j
  for(i=0;i<itemsinlist(graphs);i+=1)
    string graph=stringfromlist(i,graphs)
    string traces=TraceNameList(graph,";",3)
    
    //check all the twoP graph subwindows
    If(!cmpstr(graph,"twoPScanGraph"))
    	graph = "twoPscanGraph#GCH1"
    	traces=TraceNameList(graph,";",3)
    	if(whichlistitem(name,traces) != -1) // Assumes that each wave is plotted at most once on a graph.  
      	RemoveFromGraph/Z /W=$graph $name
    	endif
    	graph = "twoPscanGraph#GCH2"
    	traces=TraceNameList(graph,";",3)
    	if(whichlistitem(name,traces) != -1) // Assumes that each wave is plotted at most once on a graph.  
      	RemoveFromGraph/Z /W=$graph $name
    	endif
    	graph = "twoPscanGraph#GMRG"
    	traces=TraceNameList(graph,";",3)
    	if(whichlistitem(name,traces) != -1) // Assumes that each wave is plotted at most once on a graph.  
      	RemoveFromGraph/Z /W=$graph $name
    	endif	
    Else
    	traces=TraceNameList(graph,";",3)
    
	    if(whichlistitem(name,traces) != -1) // Assumes that each wave is plotted at most once on a graph.  
	      RemoveFromGraph/Z /W=$graph $name
	    endif
	 EndIf 
  endfor

  string tables=WinList("*",";","WIN:2") // A list of all tables
  for(i=0;i<itemsinlist(tables);i+=1)
    string table=stringfromlist(i,tables)
    j=0
    do
      string column=StringFromList(j,table)
      if(!strlen(column))
      	break
      endif
      if(cmpstr(column,name) == 0)
        RemoveFromTable/Z/W=$table $column
        break
      else
      	j+=1
      endif
    while(1)
  endfor 

  killwaves /z w
End  

//Returns a list of the #waves in each waveset of the data set
Function/S GetDataSetDims(dsName)
	String dsName
	String dims = ""
	
	If(!strlen(dsName))
		return ""
	EndIf
	
	Wave/T ds = GetDataSetWave(dsName,"ORG")
	If(!WaveExists(ds))
		return ""
	EndIf	
	
	Variable i,numWaveSets = GetNumWaveSets(ds)
	For(i=0;i<numWaveSets;i+=1)
		dims += num2str(GetNumWaves(ds,i)) + ";"
	EndFor
	
	return dims
End


//Resolves the syntax used in the Cmd input for 'Run Cmd Line' function
//Replaces data set references <DataSet> with the name of the wave
//<DataSet>{wsn,wsi}
Function/S resolveCmdLine(cmdLineStr,wsn,wsi)
	String cmdLineStr
	Variable wsn,wsi

	//WaveSet data
	//ControlInfo/W=NT extFuncDS
	//numWaveSets = GetNumWaveSets(S_Value)
	//wsDims = GetWaveSetDims(S_Value)
	
	String left = "",right = "",dsName="",char="",outStr="",tempStr="",indexStr=""
	Variable pos1,pos2,pos3,pos4,numChars,i,index,wsnIndex,wsiIndex
	
	//Divide into left and right sides of an equals sign
	left = StringFromList(0,cmdLineStr,"=")
	right = StringFromList(1,cmdLineStr,"=")

	
	pos1 = 0;pos2 = 0
	pos3 = 0;pos4 = 0
	outStr = ""
	Do
		pos1 = strsearch(cmdLineStr,"<",0)
		pos2 = strsearch(cmdLineStr,">",pos1)
		
		
		//If a valid data set syntax was found
		If(pos1 != -1 && pos2 != -1)
			//test for wsi specifier { } directly after the dataset specifier
			If(!cmpstr(cmdLineStr[pos2+1],"{"))
				pos3 = pos2+1
				pos4 = strsearch(cmdLineStr,"}",pos3)
			Else
				pos3 = -1
				pos4 = -1
			EndIf
			
			//Get the referenced data set
			dsName = cmdLineStr[pos1+1,pos2-1]
			Wave/T/Z ds = GetDataSetWave(dsName,"ORG")
				
			If(pos3 != -1 && pos2 != -1)
				//set pos2 to after the waveset specifier for proper string trimming
				pos2 = pos4
				
				//wsi specifier
				indexStr = cmdLineStr[pos3+1,pos4-1]
				
				//resolve wsn
				tempStr = StringFromList(0,indexStr,",")
				
				If(cmpstr(tempStr,"*"))
					wsnIndex = str2num(tempStr)
					If(numtype(wsnIndex) == 2)//invalid index number
						outStr = ""
						return outStr
					EndIf
					
					//Ensures that the function only runs for the indicated wave set number,
					//instead of repeating itself for every wave set.
					If(wsnIndex != wsn)
						outStr = ""
						return outStr
					EndIf
				Else
					wsnIndex = wsn
				EndIf
				
				//resolve wsi
				tempStr = StringFromList(1,indexStr,",")
				
				If(cmpstr(tempStr,"*"))
					wsiIndex = str2num(tempStr)
					If(numtype(wsnIndex) == 2)//invalid index number
						outStr = ""
						return outStr
					EndIf
				Else
					wsiIndex = wsi
				EndIf
				
				
			  String theWaveSet = GetWaveSetList(GetDataSetWave(dsName,"ORG"),wsnIndex,1)
			  String theWaveStr = StringFromList(wsiIndex,theWaveSet,";")
				
			Else
				//No wsi specifier
				If(cmpstr(dsName,"wsi") == 0)
					theWaveSet = ""
				   theWaveStr = num2str(wsi)
				ElseIf(cmpstr(dsName,"wsn") == 0)
				   theWaveSet = ""
				   theWaveStr = num2str(wsn)
				Else
					theWaveSet = GetWaveSetList(GetDataSetWave(dsName,"ORG"),wsn,1)
					theWaveStr = StringFromList(wsi,theWaveSet,";")
				EndIf
			EndIf
			
			//section of string that isn't a data set reference
			tempStr = cmdLineStr[0,pos1-1]

			//insert into wave name the output command string
			outStr += tempStr + theWaveStr
			
			//trim to the remaining section of unsearched command string
			cmdLineStr = cmdLineStr[pos2+1,strlen(cmdLineStr)-1]
		Else
			//append remaining characters to the output command string
			outStr += cmdLineStr
			break
		EndIf
	While(pos1 != -1)
	return outStr
End

//Appends the command line entry from 'Run Cmd Line' to the master entry
//and displays it below
Function appendCommandLineEntry()
	DFREF NTF = root:Packages:NT
	SVAR masterCmdLineStr = NTF:masterCmdLineStr
	
	ControlInfo/W=NT cmdLineStr
	String entry = S_Value
	
	If(!strlen(entry))
		return 0
	EndIf
	
	//Make unique separator that shouldn't exist within any of the entries
	masterCmdLineStr += entry + ";/;"
	
	//Draw the entries in the group box
	DrawMasterCmdLineEntry()
	
	//Set the window hook for deleting and editing specific entries
	SetWindow NT hook(cmdLineEntryHook) = cmdLineEntryHook
End

//Draws each entry of the Master Command Line String to the GUI
Function DrawMasterCmdLineEntry()

	DFREF NTF = root:Packages:NT
	SVAR masterCmdLineStr = NTF:masterCmdLineStr
	
	Variable i,xPos,yPos
	xPos = 461
	yPos = 159
	
	//Clear previous command string text
	DrawAction/W=NT getgroup=CmdLineText,delete
	
	//Draw the command string text in lines
	SetDrawEnv/W=NT gname=CmdLineText,gstart
	For(i=0;i<ItemsInList(masterCmdLineStr,";/;");i+=1)
		SetDrawEnv/W=NT fname=$LIGHT,fsize=10
		DrawText/W=NT xPos,yPos,"\f01" + num2str(i) + ": \f00" + StringFromList(i,masterCmdLineStr,";/;")
		yPos += 20
	EndFor
	SetDrawEnv/W=NT gstop
End

//Clears the master command line entry
Function clearCommandLineEntry()
	DFREF NTF = root:Packages:NT
	SVAR masterCmdLineStr = NTF:masterCmdLineStr
	masterCmdLineStr = ""
	
	SetVariable cmdLineStr win=NT,value=_STR:""
	
	//Clear previous command string text
	DrawAction/W=NT getgroup=CmdLineText,delete
	
	//Set the window hook for deleting and editing specific entries
	SetWindow NT hook(cmdLineEntryHook) = $""
End


//VIEWER FUNCTIONS------------------------------------------------

//Opens the Trace Viewer window
Function openViewer()
	DFREF NTF = root:Packages:NT
	
	NVAR viewerOpen = NTF:viewerOpen
	SVAR viewerRecall = NTF:viewerRecall
	
	//Define guides
	DefineGuide/W=NT VT = {FT,0.6315,FB}
	DefineGuide/W=NT VB = {FT,0.97,FB}
	
	//Add an additional 200 pixels to the toolbox on the bottom
	GetWindow NT wsize
	MoveWindow/W=NT V_left,V_top,V_right,V_bottom + 300
	
	//Open the display window only if it wasn't already open
	If(viewerOpen == 0)
		Display/HOST=NT/FG=(FL,VT,FR,VB)/N=ntViewerGraph
	EndIf	
	
	//adjust guide for scanListPanel so it doesn't get in the viewer's way
	DefineGuide/W=NT listboxBottom={FT,0.61,FB}
	
	//Display the window controls
	Button ntViewerAutoScaleButton win=NT,size={50,20},pos={3,793},title="AUTO",proc=ntButtonProc
	Button ntViewerSeparateVertButton win=NT,size={50,20},pos={60,793},title="VSEP",proc=ntButtonProc
	Button ntViewerSeparateHorizButton win=NT,size={50,20},pos={117,793},title="HSEP",proc=ntButtonProc
	Button ntViewerDisplayTracesButton win=NT,size={50,20},pos={174,793},title="DISP",proc=ntButtonProc
	Button ntViewerClearTracesButton win=NT,size={50,20},pos={231,793},title="CLEAR",proc=ntButtonProc
	
	//Recall previous display
	If(strlen(viewerRecall))
		Execute/Z viewerRecall
	EndIf
	
	viewerOpen = 1
End

//Closes the Trace Viewer window
Function closeViewer()
	DFREF NTF = root:Packages:NT
	SVAR viewerRecall = NTF:viewerRecall
	NVAR viewerOpen = NTF:viewerOpen
	
	viewerRecall = WinRecreation("NT#ntViewerGraph",0)
	//viewerRecall = ReplaceString("Display/W=(162,200,488,600)/FG=(FL,VT,FR,VB)/HOST=#",viewerRecall,"AppendToGraph/W=NT#ntViewerGraph")
	
	Variable pos1 = strsearch(viewerRecall,"Display",0)
	Variable pos2 = strsearch(viewerRecall,"#",0)
	String matchStr = viewerRecall[pos1,pos2]
	viewerRecall = ReplaceString(matchStr,viewerRecall,"AppendToGraph/W=NT#ntViewerGraph")
	
	KillWindow/Z NT#ntViewerGraph
	//Remove 200 pixels to the toolbox on the bottom
	GetWindow NT wsize
	MoveWindow/W=NT V_left,V_top,V_right,V_bottom - 300
	
	//adjust guide for scanListPanel so it doesn't get in the viewer's way
	DefineGuide/W=NT listboxBottom={FB,-10}
	
	viewerOpen = 0
End

Function AppendToViewer(listWave,selWave)
	Wave/T listWave //listwave associated with the clicked listbox
	Wave selWave
	
	DFREF NTF = root:Packages:NT
	SVAR cdf = NTF:currentDataFolder
	
	Variable i,j,type

	DoWindow/W=NT#ntViewerGraph ntViewerGraph
	
	//Does the window exist?
	If(V_flag)
		String traceList = TraceNameList("NT#ntViewerGraph",";",1)
		
		//Remove all traces
		For(i=ItemsInList(traceList)-1;i>-1;i-=1)
			RemoveFromGraph/Z/W=NT#ntViewerGraph $StringFromList(i,traceList,";")
		EndFor	
		
		//Append selected traces
		For(i=0;i<DimSize(selWave,0);i+=1)
			//If selected
			If(selWave[i] == 1)
					//ignore text waves
				If(WaveType($listWave[i][0][1],1) == 2)
					continue 
				ElseIf(stringmatch(listWave[i][0][1],"*WAVE SET*"))
					Variable wsn = str2num(StringByKey("WAVE SET",listWave[i][0][1]," ","-"))
					Wave/T ws = GetWaveSet(listWave,wsn)
					
					For(j=0;j<DimSize(ws,0);j+=1)
						AppendToGraph/W=NT#ntViewerGraph $ws[j][0][1]
					EndFor
				Else
					//only append numeric waves
					AppendToGraph/W=NT#ntViewerGraph $listWave[i][0][1]
				EndIf
			EndIf	
		EndFor
	EndIf	
End

//Moves a trace from its current axis to the named axis
Function changeAxis(theTrace,theGraph,axisName,orient)
	String theTrace,theGraph,axisName,orient
	
	String axes = axisList(theGraph)
	strswitch(orient)
		case "hor":		
			Wave theWave = TraceNameToWaveRef(theGraph,theTrace)
			RemoveFromGraph/Z/W=$theGraph $theTrace
			AppendToGraph/W=$theGraph/B=$axisName/L theWave 
			break
		case "vert":
			Wave theWave = TraceNameToWaveRef(theGraph,theTrace)
			RemoveFromGraph/Z/W=$theGraph $theTrace
			AppendToGraph/W=$theGraph/B/L=$axisName theWave 
			break
	endswitch	
End

//Splits traces on the Viewer either horizontally or vertically
Function SeparateTraces(orientation)
	String orientation
	DFREF NTF = root:Packages:NT
	
	NVAR areHorizSeparated = NTF:areHorizSeparated
	NVAR areVertSeparated = NTF:areVertSeparated

	String traceList = TraceNameList("NT#ntViewerGraph",";",1)
	String theTrace,prevTrace
	Variable numTraces,i,traceMax,traceMin,traceMinPrev,traceMaxPrev,offset
	offset = 0
	numTraces = ItemsInList(traceList,";")
	
	Variable separateAxis = 1
	
	strswitch(orientation)
		case "vert":
			If(areVertSeparated)
				For(i=1;i<numTraces;i+=1)
					theTrace = StringFromList(i,traceList,";")
					offset = 0
					ModifyGraph/W=NT#ntViewerGraph offset($theTrace)={0,offset}
				EndFor	
				areVertSeparated = 0	
			Else
				For(i=1;i<numTraces;i+=1)
					theTrace = StringFromList(i,traceList,";")
					Wave theTraceWave = TraceNameToWaveRef("NT#ntViewerGraph",theTrace)
					traceMin = WaveMin(theTraceWave)
					traceMax = WaveMax(theTraceWave)
					Wave prevTraceWave = TraceNameToWaveRef("NT#ntViewerGraph",StringFromList(i-1,traceList,";"))
					traceMinPrev = WaveMin(prevTraceWave)
					traceMaxPrev = WaveMax(prevTraceWave)
					offset -= abs(traceMax - traceMinPrev)
					ModifyGraph/W=NT#ntViewerGraph offset($theTrace)={0,offset}
			EndFor
				
				areVertSeparated = 1
				
			EndIf
			
			break
		case "horiz":
			If(areHorizSeparated)
				For(i=0;i<numTraces;i+=1)
					theTrace = StringFromList(i,traceList,";")
					offset = 0
					changeAxis(theTrace,"NT#ntViewerGraph","bottom","hor")
					ModifyGraph/W=NT#ntViewerGraph offset($theTrace)={offset,0}
				EndFor	
				areHorizSeparated = 0	
			Else
				For(i=1;i<numTraces;i+=1)
					theTrace = StringFromList(i,traceList,";")
					Wave theTraceWave = TraceNameToWaveRef("NT#ntViewerGraph",theTrace)
					traceMin = DimOffset(theTraceWave,0)
					traceMax = IndexToScale(theTraceWave,DimSize(theTraceWave,0)-1,0)
					Wave prevTraceWave = TraceNameToWaveRef("NT#ntViewerGraph",StringFromList(i-1,traceList,";"))
					traceMinPrev = DimOffset(prevTraceWave,0)
					traceMaxPrev = IndexToScale(prevTraceWave,DimSize(prevTraceWave,0)-1,0)
					offset += abs(traceMinPrev+traceMax)
					ModifyGraph/W=NT#ntViewerGraph offset($theTrace)={offset,0}
				EndFor
				
				If(separateAxis)
					For(i=0;i<numTraces;i+=1)
						theTrace = StringFromList(i,traceList,";")
						String axisName = "bottom_" + num2str(i)
						changeAxis(theTrace,"NT#ntViewerGraph",axisName,"hor")
						ModifyGraph/W=NT#ntViewerGraph axisEnab($axisName)={(i)/numTraces,(i+1)/numTraces}
					EndFor
				EndIf
				areHorizSeparated = 1
				
			EndIf
			break
	endswitch
End

//Clears all the traces from the Viewer window
Function clearTraces()
	String traceList = TraceNameList("NT#ntViewerGraph",";",1)
	Variable numTraces = ItemsInList(traceList,";")
	Variable i
	
	For(i=numTraces - 1;i>-1;i-=1)
		String theTrace = StringFromList(i,traceList,";")
		RemoveFromGraph/W=NT#ntViewerGraph $theTrace
	EndFor	
End

//Runs the selected external function (user provided)
Function RunExternalFunction(cmd)
	String cmd
	
	strswitch(cmd)
		case "Write Your Own":
			DisplayProcedure/W=NT_InsertTemplate "NT_MyFunction"
			DisplayProcedure/W=NT_ExternalFunctions "ArrangeProcWindows"
			ArrangeProcWindows()
			break
		default:
			cmd = "NT_" + cmd
			Execute/Q/Z cmd
	endswitch
	
	return 1
End

//Switches the title of the function list in the 'External Functions' command window
Function SwitchExternalFunction(cmd)
	String cmd
	
	//Calculates spacer to ensure centered text on the drop down menu
	String spacer = ""
	Variable cmdLen = strlen(cmd)
	cmdLen = 16 - cmdLen
	
	Do
		spacer += " "
		cmdLen -= 1
	While(cmdLen > 0)
	
	//Command Menu
	Button extFuncPopUp win=NT,font=$LIGHT,pos={460,100},size={125,20},fsize=12,proc=ntButtonProc,title="\\JL▼   " + spacer + cmd,disable=0

	
End

//Returns the list of external functions
Function/S GetExternalFunctions()
	String theFile,theList=""
	theFile = "NT_ExternalFunctions.ipf"
	theList = FunctionList("NT_*", ";","WIN:" + theFile)
	theList = "Write Your Own;" + ReplaceString("NT_",theList,"") //remove NT_ prefixes for the menu
	return theList
End

Function ResolveFunctionParameters(theFunction)
	String theFunction
	DFREF NTF = root:Packages:NT
	
	String info = FunctionInfo(theFunction)
	
	//control list will need updating when controls are added
	SVAR ctrlList_extFunc = NTF:ctrlList_extFunc
	ctrlList_extFunc = ""
	NVAR numExtParams = NTF:numExtParams
	SVAR extParamTypes = NTF:extParamTypes
	SVAR extParamNames = NTF:extParamNames
	
	Variable numParams,i,pos
	String paramType,functionStr

	numParams = str2num(StringByKey("N_PARAMS",info,":",";"))
	
	//Function has no extra parameters declared
	If(numParams == 0)
		numExtParams = 0
		KillExtParams()
		return -1
	EndIf
	
	
	numExtParams = numParams
	paramType = ""

	//gets the type for each input parameter
	Variable numOptionals = str2num(StringByKey("N_OPT_PARAMS",info,":",";"))
	SVAR isOptional = NTF:isOptional
	isOptional = ""
	
	For(i=0;i<numParams;i+=1)
		paramType += StringByKey("PARAM_" + num2str(i) + "_TYPE",info,":",";") + ";"
		If(i < numParams - numOptionals)
			isOptional += "0" + ";"
		Else
			isOptional += "1" + ";"
		EndIf
	EndFor
	extParamTypes = paramType
	
	//Gets the names of each inputs in the selected function
	functionStr = ProcedureText(theFunction,0)
	pos = strsearch(functionStr,")",0)
	functionStr = functionStr[0,pos]
	functionStr = RemoveEnding(StringFromList(1,functionStr,"("),")")
	
	extParamNames = functionStr
	Variable type,left=460,top=145
	String name,paramName
	
	For(i=0;i<numParams;i+=1)
		name = StringFromList(i,functionStr,",")
		paramName = "param" + num2str(i)
		type = str2num(StringFromList(i,paramType,";"))
		switch(type)
			case 4://variable
				SetVariable/Z $paramName win=NT,pos={left,top},size={90,20},bodywidth=50,title=name,value=_NUM:0,disable=0,proc=ntExtParamPopProc
				ctrlList_extFunc += paramName + ";"
				break
			case 8192://string
				SetVariable/Z $paramName win=NT,pos={left,top},size={90,20},bodywidth=50,title=name,value=_STR:"",disable=0,proc=ntExtParamPopProc
				ctrlList_extFunc += paramName + ";"
				break
			case 16386://wave
				//this will convert a wave path to a wave reference pointer
				SetVariable/Z $paramName win=NT,pos={left,top},size={140,20},bodywidth=100,title=name,value=_STR:"",disable=0,proc=ntExtParamPopProc
				ctrlList_extFunc += paramName + ";"
				break
		endswitch
		top += 25
		
	EndFor
	
End

Function/S SetExtFuncCmd()
	Variable option//is this from external command, or is it from a built in command
	
	NVAR numExtParams = root:Packages:analysisTools:numExtParams
	SVAR extParamTypes = root:Packages:analysisTools:extParamTypes
	SVAR extParamNames = root:Packages:analysisTools:extParamNames
	SVAR isOptional = root:Packages:analysisTools:isOptional
	Variable i,type
	String runCmdStr = ""
	String name 
	
	SVAR builtInCmdStr = root:Packages:analysisTools:runCmdStr
	
	//External function
	//ControlInfo/W=analysis_tools extFuncPopUp
	SVAR currentExtCmd = root:Packages:analysisTools:currentExtCmd
	String theFunction = currentExtCmd
	runCmdStr = "NT_" + theFunction + "("

	For(i=0;i<numExtParams;i+=1)
		ControlInfo/W=analysis_tools $("param" + num2str(i))
		type = str2num(StringFromList(i,extParamTypes,";"))
		name = StringFromList(i,extParamNames,",")
		
		switch(type)
			case 4://variable
				If(str2num(StringFromList(i,isOptional,";")) == 0)
					runCmdStr += num2str(V_Value) + ","
				Else
					//optional parameter
					If(V_Value)
						runCmdStr += name + "=" + num2str(V_Value) + ","
					EndIf
				EndIf
				break
			case 8192://string
				If(str2num(StringFromList(i,isOptional,";")) == 0)
					runCmdStr += "\"" + S_Value + "\","
				Else
					//optional parameter
					If(strlen(S_Value))
						runCmdStr += name + "=" + "\"" + S_Value + "\","
					EndIf
				EndIf
				break
			case 16386://wave
				If(str2num(StringFromList(i,isOptional,";")) == 0)
					runCmdStr += S_Value + ","
				Else
					//optional parameter
					If(strlen(S_Value))
						runCmdStr += name + "=" + S_Value + ","
					EndIf
				EndIf
				break
		endswitch
	EndFor
	runCmdStr = RemoveEnding(runCmdStr,",")
	runCmdStr += ")"

	return runCmdStr
End

Function KillExtParams()
	NVAR numExtParams = root:Packages:analysisTools:numExtParams
	Variable i
	For(i=0;i<numExtParams;i+=1)
		KillControl/W=analysis_tools $("param" + num2str(i))
	EndFor
End

Function updateExtFuncValues(theFunction)
	String theFunction
	SVAR extParamTypes = root:Packages:analysisTools:extParamTypes
	SVAR extParamNames = root:Packages:analysisTools:extParamNames
	Wave/T extFuncValues = root:Packages:analysisTools:extFuncValues
	
	Variable cols,i,numParams,whichCol = -1
	
	cols = DimSize(extFuncValues,1)
	numParams = ItemsInList(extParamNames,",")
	
	If(cols == 0)
		whichCol = 0
		cols +=1
		Redimension/N=(1,cols) extFuncValues
		If(numParams + 2 > DimSize(extFuncValues,0))
			Redimension/N=(numParams + 2,-1) extFuncValues
		EndIf
	Else
	
		For(i=0;i<cols;i+=1)
			If(stringmatch(extFuncValues[0][i],theFunction))
				whichCol = i
				break
			EndIf
		EndFor
		
		If(whichCol == -1)
			whichCol = cols
			cols += 1
			Redimension/N=(-1,cols) extFuncValues
			If(numParams + 2 > DimSize(extFuncValues,0))
				Redimension/N=(numParams + 2,-1) extFuncValues
			EndIf
		EndIf
	EndIf
	
	///Fill out the table
	extFuncValues[0][whichCol] = theFunction
	extFuncValues[1][whichCol] = num2str(numParams)
	For(i=0;i<numParams;i+=1)
		ControlInfo/W=analysis_tools $("param" + num2str(i))
		If(numtype(V_Value) == 2 || strlen(S_Value))
			//string or wave input
			extFuncValues[i+2][whichCol] = S_Value
		Else
			//variable input
			extFuncValues[i+2][whichCol] = num2str(V_Value)
		EndIf
	EndFor

End

Function recallExtFuncValues(theFunction)
	String theFunction
	Wave/T extFuncValues = root:Packages:analysisTools:extFuncValues
	NVAR numExtParams = root:Packages:analysisTools:numExtParams
	Variable i,whichCol,cols
	
	cols = DimSize(extFuncValues,1)
	whichCol = -1
	
	For(i=0;i<cols;i+=1)
		If(stringmatch(extFuncValues[0][i],theFunction))
			whichCol = i
			break
		EndIf
	EndFor
	
	If(whichCol != -1)
		For(i=0;i<numExtParams;i+=1)
			ControlInfo/W=analysis_tools $("param" + num2str(i))
			If(numtype(V_Value) ==2)
				//string or wave input
				SetVariable $("param" + num2str(i)) win=analysis_tools,value=_STR:extFuncValues[i+2][whichCol]
			Else
				SetVariable $("param" + num2str(i)) win=analysis_tools,value=_NUM:str2num(extFuncValues[i+2][whichCol])
			EndIf
			
		EndFor
	EndIf

End

//Updates the text showing valid and invalid wave references in the External Functions parameters
Function validWaveText(path,ypos,[,deleteText])
	String path
	Variable ypos
	Variable deleteText
	
	If(!ParamIsDefault(deleteText))
		DrawAction/W=NT getgroup=ValidWaveText,delete
		return 0
	EndIf
	
	If(WaveExists($path))
		SetDrawEnv/W=NT textrgb= (3,52428,1),fstyle=2,fsize=10,gname=ValidWaveText,gstart
		DrawText/W=NT 606,ypos,"Valid"
		SetDrawEnv/W=NT gstop
	Else
		SetDrawEnv/W=NT textrgb= (65535,0,0),fstyle=2,fsize=10,gname=ValidWaveText,gstart
		DrawText/W=NT 606,ypos,"Invalid"
		SetDrawEnv/W=NT gstop
	EndIf
	
End