﻿#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//Inputs a numerical string list, converts to a ranged list (i.e. 1,2,3,5,6,7 -> 1-3,5-7)
Function/S ListToRange(list,separator)
	String list,separator
	Variable i,size = ItemsInList(list,separator)
	
	String item = ""
	String range = ""
	
	Variable count = 0
	
	For(i=0;i<size;i+=1)
		item = StringFromList(i,list,separator)
		
		If(!isNum(item))
//			print "List must be fully numeric, no characters allowed."
			return list
		EndIf
		
		If(i == 0)
			range = item
		Else
			String lastItem = StringFromList(i-1,list,separator)
			
			If(str2num(item) - 1 == str2num(lastItem))
				count += 1
			Else
				If(count == 0)
					range += "," + item
				Else
					range += "-" + lastItem + "," + item
					count = 0
				EndIf
			EndIf
		EndIf
	EndFor
	
	//last item
	If(count > 0)
		range += "-" + item
	EndIf
	
	return range
End

//returns 1 if the input string is numeric, 0 if it is not
Function isNum(str)
	String str
	
	Variable var = str2num(str)
	
	If(numtype(var) == 2)
		return 0
	Else
		return 1
	EndIf
End

//If str matches an entry in the tableWave, returns the row, otherwise return -1
Function tableMatch(str,tableWave,[startp,endp,whichCol,returnCol,startFrom])
	String str
	Wave/T tableWave
	Variable startp,endp,whichCol,returnCol//for range
	Variable startFrom //start from beginning is default (0) or start from end is 1
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
	
	If(ParamIsDefault(whichCol))
		whichCol = 0
	EndIf
	
	If(ParamIsDefault(startFrom))
		startFrom = 0
	EndIf
	
	If(startp > DimSize(tableWave,0) - 1)
		return -1
	EndIf
	
	If(endp < DimSize(tableWave,0) - 1)
		return -1
	EndIf
	
	If(!ParamIsDefault(whichCol))
		If(startFrom)
			//Backwards
			For(i=endp;i>startp-1;i-=1)
				If(stringmatch(tableWave[i][whichCol][0],str))
					return i
				EndIf
			EndFor
		Else
			//Forwards 
			For(i=startp;i<endp+1;i+=1)
				If(stringmatch(tableWave[i][whichCol][0],str))
					return i
				EndIf
			EndFor
		EndIf
				
		return -1
	EndIf
	
	For(j=0;j<cols;j+=1)
		If(startFrom)
			//Backwards
			For(i=endp;i>startp-1;i-=1)
				If(stringmatch(tableWave[i][j][0],str))
					If(returnCol)
						return j
					Else
						return i
					EndIf
				EndIf
			EndFor
		Else
			//Forwards
			For(i=startp;i<endp+1;i+=1)
				If(stringmatch(tableWave[i][j][0],str))
					If(returnCol)
						return j
					Else
						return i
					EndIf
				EndIf
			EndFor
		EndIf
	EndFor
	
	return -1
End

//Same as table match, but returns a string list of all the matched indexes, not just the first encountered
Function/S filterTable(str,tableWave,[startp,endp,returnCol])
	String str
	Wave/T tableWave
	Variable startp,endp,returnCol//for range
	Variable i,j,size = DimSize(tableWave,0)
	Variable cols = DimSize(tableWave,1)
	String indexList = ""
	
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
		return ""
	EndIf
	
	If(endp < DimSize(tableWave,0) - 1)
		return ""
	EndIf
	
	For(j=0;j<cols;j+=1)
		For(i=startp;i<endp+1;i+=1)
			If(stringmatch(tableWave[i][j],str))
				If(returnCol)
					indexList += num2str(j) + ";"
				Else
					indexList += num2str(i) + ";"
				EndIf
			EndIf
		EndFor
	EndFor
	
	return indexList
End

//Switches the label on the Command Menu on a new selection
//Function switchCommandMenu(cmd)
//	String cmd
//	
//	//Calculates spacer to ensure centered text on the drop down menu
//	String spacer = ""
//	Variable cmdLen = strlen(cmd)
//	cmdLen = 16 - cmdLen
//	
//	Do
//		spacer += " "
//		cmdLen -= 1
//	While(cmdLen > 0)
//	
//	//Command Menu
//	Button CommandMenu win=NTP,font=$LIGHT,pos={456,39},size={140,20},fsize=12,proc=ntButtonProc,title="\\JL▼   " + spacer + cmd,disable=0
//
//End


//Switches the label on the Wave Selector Menu on a new selection
Function switchWaveListSelectorMenu(cmd)
	String cmd
	
	DFREF NPC = $CW
	SVAR waveSelectorStr = NPC:waveSelectorStr
	
	//Calculates spacer to ensure centered text on the drop down menu
	String spacedCmd = getSpacer(cmd,15)
	
	//Command Menu
	Button WaveListSelector win=NTP,font=$LIGHT,proc=ntButtonProc,title=spacedCmd,disable=0
	
	waveSelectorStr = cmd
End

//Returns a string with appropriate buffer for button titles that trigger contextual pop up menus
Function/S getSpacer(str,buffer)
	//Calculates spacer to ensure centered text on the drop down menu
	String str
	Variable buffer
	
	String spacer = ""
	Variable cmdLen = strlen(str)
	cmdLen = buffer - cmdLen
	
	Do
		spacer += " "
		cmdLen -= 1
	While(cmdLen > 0)
	
	return "\\JL▼   " + spacer + str
End

//Gets the subfolders that reside in the current data folder
Function/WAVE getFolders([folderPath])
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
Function/WAVE getFolderWaves([depth])
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
Function switchFolders(selection)
	String selection
	DFREF NPC = $CW
	
	//Change the current data folder
	SVAR cdf = NPC:cdf
	SetDataFolder cdf + selection
	
	//Refresh the folder and waves list boxes
	getFolders()
	getFolderWaves()
End

//Switches the current data folder up one level
//Refreshes the folder and wave list box contents
Function navigateBack()
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
	getFolders()
	getFolderWaves()
	
	Wave FolderLB_SelWave = NPC:FolderLB_SelWave
	
	//Set the selection to the first row
	If(DimSize(FolderLB_SelWave,0) > 0)
		FolderLB_SelWave = 0
		FolderLB_SelWave[0] = 1
	EndIf
End

//Browse the files prior to loading
Function BrowseEphys(fileType)
	String fileType
	
	DFREF NPC = $CW
	Variable fileID
	
	SVAR wsFilePath = NPC:wsFilePath
	SVAR wsFileName = NPC:wsFileName
			
	strswitch(fileType)
		case "WaveSurfer":
			
			HDF5OpenFile/I/R fileID as "theWave"
			
			If(V_flag == -1) //cancelled
				return 0
			EndIf	
			wsFilePath = S_path
			wsFileName = S_fileName
	
			UpdateWaveSurferLists(fileID,wsFilePath,wsFileName)
			
			HDF5CloseFile/A fileID
			break
		case "TurnTable":
			NewPath/O/Q/Z ephysPath
			
			String fileList = IndexedFile(ephysPath,-1,".h5")

			PathInfo ephysPath
			wsFilePath = S_path

			wsFileName = StringFromList(0,fileList,";")
			
			Wave/T wsSweepListWave = $getParam2("lb_SweepList","LISTWAVE","NT_LoadEphys")
			Wave/T wsFileListWave = $getParam2("lb_FileList","LISTWAVE","NT_LoadEphys")
			Wave wsFileSelWave = $getParam2("lb_FileList","SELWAVE","NT_LoadEphys")
			
			Redimension/N=(ItemsInList(fileList,";")) wsFileListWave,wsFileSelWave
			
			wsFileListWave = StringFromList(p,fileList,";")
			wsFileSelWave = 0
			break
			
		case "PClamp":	
			Variable refnum
			String extension = ".abf"
			String message = "Select the data folder to index"
			String fileFilters = "All Files:.abf;"
			Open/D/R/F=fileFilters/M=message refnum
			
			wsFilePath = ParseFilePath(1,S_fileName,":",1,0)
			wsFileName = ParseFilePath(0,S_fileName,":",1,0)
			Close/A
			
			String fullPath = wsFilePath
			NewPath/O/Q/Z loadPath,fullpath
			fileList = IndexedFile(loadPath,-1,extension)
			
			If(!strlen(fileList))
				return 0
			EndIf
			
			fileList = SortList(fileList,";",16)
			
			fileList = ReplaceString(extension,fileList,"")
			
			Wave/T wsFileListWave = NPC:wsFileListWave
			Wave wsFileSelWave = NPC:wsFileSelWave
			
			Wave/T textWave = StringListToTextWave(fileList,";")
			Redimension/N=(DimSize(textWave,0)) wsFileListWave,wsFileSelWave
			wsFileListWave = textWave
			wsFileSelWave[0] = 1
			
//			//What channels are available for the selected file
//			
//			fullPath = wsFilePath + wsFileName
//			ABFLoader(fullPath,"1",0)
//			
//			Wave/T dTable_Values = root:ABFvar:dTable_Values
//			
//			String chList = "1;2;"
//			
			String quote = "\""
			String channelList = quote + "All;1;2;" + quote

			PopUpMenu ChannelSelector win=NTP#Func,value=#channelList
			
			break
		case "Presentinator":
//			extension = ".phys"
//			message = "Select the data folder to index"
//			fileFilters = "All Files:.phys;"
//			Open/D/R/F=fileFilters/M=message refnum
//			
//			wsFilePath = ParseFilePath(1,S_fileName,":",1,0)
//			wsFileName = ParseFilePath(0,S_fileName,":",1,0)
//			Close/A
//			
//			fullPath = wsFilePath
//			NewPath/O/Q/Z loadPath,fullpath
//			fileList = IndexedFile(loadPath,-1,extension)
//			
//			If(!strlen(fileList))
//				return 0
//			EndIf
//			
//			fileList = SortList(fileList,";",16)
//			
//			fileList = ReplaceString(extension,fileList,"")
//			
//			Wave/T wsFileListWave = NPC:wsFileListWave
//			Wave wsFileSelWave = NPC:wsFileSelWave
//			
//			Wave/T textWave = StringListToTextWave(fileList,";")
//			Redimension/N=(DimSize(textWave,0) - 1) wsFileListWave,wsFileSelWave
//			wsFileListWave = textWave
//			wsFileSelWave[0] = 1
//			
//			//What channels are available for the selected file
//			GetPresentinatorChannels("")
			
			break
	endswitch	
	
End



//browses disk for scanimage tiffs
Function/S BrowseScanImage()
	DFREF NPC = $CW
	Variable fileID
	
	Variable refnum
	String extension = ".tif"
	
	//Browse the folder
	NewPath/O/Q/Z loadPath
	
	If(V_flag)
		return ""
	EndIf
	
	String fileList = IndexedFile(loadPath,-1,"????")
	
	String tifList = ListMatch(fileList,"*.tif",";")
	String pmtList = ListMatch(fileList,"*.pmt.dat",";")
	
	fileList = tifList + pmtList
	
	If(!strlen(fileList))
		return ""
	EndIf
	
	//Sort the files
	fileList = SortList(fileList,";",16)	
//	fileList = ReplaceString(extension,fileList,"")
//	fileList = ReplaceString(".pmt.dat",fileList,"")
	Variable numFiles = ItemsInList(fileList,";")
	
	//Enter the file names into the list box
	Make/O/N=(numFiles) NPC:siFileSelWave /Wave = selWave
	Make/O/T/N=(numFiles,2) NPC:siFileListWave /Wave = listWave
	Make/O/T/N=(1,2) NPC:siColumnListWave /Wave = colWave
	
	colWave[0][0] = "Scans"
	colWave[0][1] = "Stimulus"
	
	//Free wave return, transfer to list wave
	Wave/T theList = StringListToTextWave(fileList,";")
	
	listWave[][0] = theList
	
	//Find any StimGen .h5 files with the same names
	String stimFileList = IndexedFile(loadPath,-1,".h5")
	
	Variable i
	For(i=0;i<DimSize(theList,0);i+=1)
		String name = theList[i]
		
		//remove all other possible endings
		name = RemoveEnding(name,".tif")
		name = RemoveEnding(name,".pmt.dat")
		name = RemoveEnding(name,".meta")
		
		name += ".h5"
		
		Variable index = WhichListItem(name,stimFileList,";")
		
		If(index != -1)
			//extract the stimulus name
			HDF5OpenFile/P=loadPath/Z fileID as name
			Wave/T stimData = GetStimulusData(fileID)
			HDF5CloseFile/Z fileID
			
			If(WaveExists(stimData))
				listWave[i][1] = stimData[0][1]
			EndIf
			
		EndIf
	EndFor
	
	PathInfo/S loadPath
	return S_Path
End

//Switches the listed controls to those of the selected command in the Command Menu
Function switchControls(currentCmd,prevCmd)
	String currentCmd,prevCmd
	DFREF NPC = $CW
	NVAR foldStatus = NPC:foldStatus
	
	SVAR selectedCmd = NPC:selectedCmd
	Wave/T controlAssignments = NPC:controlAssignments 
	
	SVAR textGroups = NPC:textGroups
	
	Variable r = ScreenResolution / 72
	
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
	Variable expansion = (V_right*r - V_left*r) - 754 //current expansion relative to original width of the panel
	
	//Delete the command line entry
	SetDrawEnv/W=NTP  fstyle= 0, textxjust= 0
	DrawAction/W=NTP getgroup=CmdLineText,delete
	
	//Toggle visibility of controls according to the selected command
	If(!cmpstr(prevCmd,""))
		//Adjust the size of the parameters panel
		//only makes adjustment if parameters panel is open
		If(panelWidth > expansion && foldStatus) 
			openParameterFold(size = panelWidth)
		ElseIf(panelWidth < expansion && foldStatus)
			closeParameterFold(size = panelWidth)
		EndIf
		
		//Adjust the visible text groups
		updateTextGroups(currentCmd)
		
		//Measure command must go through further setup, since it has variable subcontrols depending on the measurement selection
		If(stringmatch(visibleList,"*measureType*"))
			setupMeasureControls(CurrentMeasureType())
		Else
			//Make the controls visible
			controlsVisible(visibleList,0)
		EndIf
		
		selectedCmd = currentCmd
	Else
		//Find the row for the previous command selection in the control assignments wave
		//Need to hide these controls
		index = tableMatch(prevCmd,controlAssignments)
		If(index == -1)
			return 0
		EndIf
		
		String invisibleList = controlAssignments[index][1]
		
		//Kill any external function parameters, in case that was the previous command selection
		KillExtParams()
		
		
		selectedCmd = currentCmd
		
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
		
		//Adjust the visible text groups
		updateTextGroups(currentCmd)
				
		//Measure command must go through further setup, since it has variable subcontrols depending on the measurement selection
		If(stringmatch(visibleList,"*measureType*"))
			Button WaveListSelector win=NT,disable=0
			setupMeasureControls(CurrentMeasureType())
		Else
			//make current controls visible 
			controlsVisible(visibleList,0)	
		EndIf
		
		
	EndIf
	
	If(!cmpstr(selectedCmd,"")) 
		return 0
	EndIf
	
	
	//Refresh any command specific text that needs to be displayed
	SVAR loadedPackages = NPC:loadedPackages
	
	SetDrawEnv/W=NTP fstyle=0
	DrawAction/W=NTP getgroup=fcnText,delete
	strswitch(selectedCmd)
		case "Get ROI":
		case "dF Map":		
		case "Max Project":
		case "Response Quality":
		case "Adjust Galvo Distortion":
		case "Align Images":
			switchWaveListSelectorMenu("Image Browser")
			break
		case "Run Cmd Line":
			 DrawMasterCmdLineEntry()
			break
		case "External Function":
			//refresh the external function list
			ControlInfo/W=NTP extFuncPopUp
			String func = CurrentExtFunc()
			
			break
		default:
			If(stringmatch(visibleList,"*WaveListSelector*"))
				ControlInfo/W=NTP WaveListSelector
				If(stringmatch(S_title,"*Image Browser"))
					switchWaveListSelectorMenu("Wave Match")
				EndIf
			EndIf
	endswitch
	
End

//Updates special text items according to the selected command
Function updateTextGroups(cmd)
	String cmd
	Variable i,j
	
	DFREF NPC = $CW
	Wave/T textGroups = NPC:textGroups
	Wave/T controlAssignments = NPC:controlAssignments 
	
	//Get the command index in the assignment table
	Variable index = tableMatch(cmd,controlAssignments)
	If(index == -1)
		return 0
	EndIf
	
	//First delete all text groups to clear the panel
	For(i=0;i<DimSize(textGroups,0);i+=1)
		String group = textGroups[i][0]
		
		SetDrawEnv/W=NTP fstyle=0, textxjust=0
		DrawAction/W=NTP getgroup=$group,delete
	EndFor
	
	//Now draw all of the text groups for the selected command
	String controlTextGroups = controlAssignments[index][3]
	
	If(!strlen(controlTextGroups))
		return 0
	EndIf
		
	For(i=0;i<ItemsInList(controlTextGroups,";");i+=1)
		group = StringFromList(i,controlTextGroups,";")
		
		Variable groupIndex = tableMatch(group,textGroups)
		If(groupIndex == -1)
			continue
		EndIf
		
		//the text objects for each text group
		String textList = textGroups[groupIndex][1]
		String xPosList = textGroups[groupIndex][2]
		String yPosList = textGroups[groupIndex][3]
		String fontSizeList = textGroups[groupIndex][4]
		
		//start the group
		SetDrawEnv/W=NTP gname=$group,gstart
		
		//There may be more than one text object per group
		For(j=0;j<ItemsInList(textList,";");j+=1)
			String text = StringFromList(j,textList,";")
			Variable xPos = str2num(StringFromList(j,xPosList,";"))
			Variable yPos = str2num(StringFromList(j,yPosList,";"))
			Variable fontSize = str2num(StringFromList(j,fontSizeList,";"))
			
			SetDrawEnv/W=NTP xcoord= abs,ycoord= abs, fsize=fontSize, textrgb=(0,0,0), textxjust= 1,textyjust= 1,fname=$LIGHT
			DrawText/W=NTP xPos,yPos,text
		EndFor
		
		//stop the group
		SetDrawEnv/W=NTP gstop
	EndFor
End

//Changes the help message that pops up with the different commands
Function switchHelpMessage(cmd)
	String cmd
	String helpMsg = ""
	
	//Reset the help message
	SetDrawEnv/W=NTP  fstyle= 0,textrgb= (0,0,0)
	DrawAction/W=NTP getgroup=helpMessage,delete
	
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
			helpMsg = "Run your own function within NeuroTools by \nputting the code in the 'ExternalFunctions.ipf'\n procedure file"
			break
	endswitch
	
	SetDrawEnv/W=NTP textyjust= 0,xcoord=abs,ycoord=abs,fname=$LIGHT,fstyle=2,fsize=10,textrgb= (0,0,0),gname=helpMessage,gstart
	DrawText/W=NTP 456,495,helpMsg
	SetDrawEnv/W=NTP gstop
	
End

//Takes text wave, and creates a string list with its contents
Function/S textWaveToStringList(textWave,separator,[col,layer,noEnding])
	Wave/T/Z textWave
	String separator
	Variable col,layer,noEnding
	
	Variable size,i
	String strList = ""
	
	If(!WaveExists(textWave))
		return ""
	EndIf
	
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
	
	noEnding = ParamIsDefault(noEnding) ? 0 : 1
	
	For(i=0;i<size;i+=1)
		strList += textWave[i][col][layer] + separator
	EndFor
	
	If(noEnding)
		strList = RemoveEnding(strList,separator)
	EndIf
	
	return strList
End

//Takes string list, and creates a text wave with its contents
Function/WAVE StringListToTextWave(strList,separator)
	String strList,separator
	Variable size,i
	
	If(!strlen(strList))
		Make/FREE/N=0/T textWave
		return textWave
	EndIf
	
	size = ItemsInList(strList,separator)
	Make/FREE/T/N=(size) textWave
	For(i=0;i<size;i+=1)
		textWave[i] = StringFromList(i,strList,separator)
	EndFor

	return textWave
End

//Same as StringFromList, but is capable of extracting a range from the list
Function/S StringsFromList(range,list,separator,[noEnding])
	String range,list,separator
	Variable noEnding
	String outList = ""
	Variable i,index
	
	noEnding = (ParamIsDefault(noEnding)) ? 0 : 1

	//Detect any asterisk wild cards
	If(!cmpstr(range[0],"*"))
		range[0] = "0"
	EndIf
	
	Variable size = strlen(range) - 1
	Variable lastItem = ItemsInList(list,separator) - 1
	
	If(!cmpstr(range[size],"*"))
		range = ReplaceString("*",range,num2str(lastItem))
//		range[size] = num2str(ItemsInList(list,separator)-1)
	EndIf
	
	range = ResolveListItems(range,";")
	range = RemoveDuplicateList(range,";")
	
	For(i=0;i<ItemsInList(range,";");i+=1)
		index = str2num(StringFromList(i,range,";"))
		outList += StringFromList(index,list,separator) + separator
	EndFor	
	
	If(noEnding)
		outList = RemoveEnding(outList,separator)
	EndIf
	
	return outList
End

//Replaces the indicated list item with the replaceWith string
Function/S ReplaceListItem(index,listStr,separator,replaceWith,[noEnding])
	Variable index
	String listStr,separator,replaceWith
	Variable noEnding
	
	noEnding = (ParamIsDefault(noEnding)) ? 0 : 1
	
	listStr = RemoveListItem(index,listStr,separator)
	listStr = AddListItem(replaceWith,listStr,separator,index)
	If(index == ItemsInList(listStr,separator) - 1)
		listStr = RemoveEnding(listStr,separator)
	EndIf
	
	If(noEnding)
		listStr = RemoveEnding(listStr,separator)
	EndIf
	
	return listStr
End

//Removes blank list items in a string list
Function/S RemoveEmptyItems(list,separator)
	String list,separator
	
	list = RemoveFromList("",list,separator)
	
	return list
End

//Removes blank cells in a text wave
Function/Wave RemoveEmptyCells(w,dim)
	Wave/T w
	Variable dim //dimension
	
	Variable i,size = DimSize(w,dim) - 1
	For(i=size;i>-1;i-=1) //count backwards
		If(!strlen(w[i]))
			DeletePoints/M=(dim) i,1,w
		EndIf
	EndFor
	
	return w
End

//Takes a hyphenated range, and resolves it into a comma-separated list
//Can handle leading zeros in the range
Function/S resolveListItems(theList,separator,[noEnding])
	String theList,separator
	Variable noEnding
	
	If(!strlen(theList))
		return ""
	EndIf
	
	noEnding = ParamIsDefault(noEnding) ? 0 : 1
	
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
	
	If(noEnding)
		outList = RemoveEnding(outList,separator)
	EndIf
	
	return outList
End

//Makes the list of control names visible on the GUI
Function controlsVisible(list,visible)
	String list
	Variable visible //0 is visible,1 is invisible
	Variable i,offset = 105
	SVAR selectedCmd = root:Packages:NT:selectedCmd
	
	For(i=0;i<ItemsInList(list,";");i+=1)
		String ctrl = StringFromList(i,list,";")
		ControlInfo/W=NTP $ctrl
		Variable type = V_flag
		
		If(!cmpstr(ctrl,"WaveListSelector"))
			Button $ctrl win=NT,disable=visible,pos={507,75}
			continue
		EndIf
		
		//Some special cases
		strswitch(selectedCmd)
			case "Run Cmd Line":
			case "External Function":
			case "Load Ephys":
			case "Load pClamp":
			case "Load WaveSurfer":
			case "Load Scans":
			case "Load Suite2P":
			case "Adjust Galvo Distortion":
			case "Align Images":
				offset = V_top
				break

		endswitch
		
		
		switch(type)
			case 1: //Button	
				If(!visible)
					Button $ctrl win=NT,disable=visible,pos={V_pos,offset}
				Else
					Button $ctrl win=NT,disable=visible
				EndIf
				break
			case -5: //SetVariable
			case 5:
				If(!cmpstr(selectedCmd,"Duplicate Rename"))
					If(!visible)
						SetVariable $ctrl win=NT,disable=visible,pos={V_pos,105}
					Else
						SetVariable $ctrl win=NT,disable=visible
					EndIf
									
					If(cmpstr(ctrl,"traceName"))
						continue
					EndIf
				Else
					If(!visible)
						SetVariable $ctrl win=NT,disable=visible,pos={V_pos,offset}
					Else
						SetVariable $ctrl win=NT,disable=visible
					EndIf
				EndIf
				break
			case -3: //PopUpMenu
			case 3: 
				If(!visible)
					PopUpMenu $ctrl win=NT,disable=visible,pos={V_pos,offset}//,pos={503,pos}
				Else
					PopUpMenu $ctrl win=NT,disable=visible
				EndIf
				break
			case 7: //Slider
				If(!visible)
					Slider $ctrl win=NT,disable=visible,pos={V_pos,offset}//,pos={461,pos}
				Else
					Slider $ctrl win=NT,disable=visible
				EndIf
				break
			case -4: //ValDisplay	
			case 4:
				If(!visible)
					ValDisplay $ctrl win=NT,disable=visible,pos={V_pos,offset}//,pos={461,pos}
				Else
					ValDisplay $ctrl win=NT,disable=visible
				EndIf
				break
			case 11: //ListBox
				If(!visible)
					ListBox $ctrl win=NT,disable=visible//,pos={V_pos,offset}//,pos={461,pos}
				Else
					ListBox $ctrl win=NT,disable=visible
				EndIf
				break
			case 2: //CheckBox
				If(!visible)
					CheckBox $ctrl win=NT,disable=visible,pos={V_pos,offset}//,pos={461,pos}
				Else
					CheckBox $ctrl win=NT,disable=visible
				EndIf
				break
		endswitch
		
		offset+= 23
	EndFor
	
	DoUpdate/W=NTP
End


//Updates the Wave Match list box with matched waves in the selected folders,
//according to the search terms
Function/WAVE getWaveMatchList()
	STRUCT filters filters
	
	DFREF NPC = $CW
	DFREF NPD = $DSF
	SVAR cdf = NPC:cdf
	SVAR folderSelection = NPC:folderSelection
	
	//Is the focus set to the Wave Match list or the Data Set Waves list?
	SVAR listFocus = NPC:listFocus
	
	//Update the search, filter, and grouping terms structure
	SetSearchTerms(filters)
	
	//List and Selection waves for the list box
	Wave/T listWave = NPC:MatchLB_ListWave
	Wave selWave = NPC:MatchLB_SelWave
	
	//Navigator selection and list waves
	Wave/T FolderLB_ListWave = NPC:FolderLB_ListWave
	Wave FolderLB_SelWave = NPC:FolderLB_SelWave
		
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
		Wave/T listWave = NPC:MatchLB_ListWave
		Wave selWave = NPC:MatchLB_SelWave
		
		//Selected folders in the Navigator
		//Makes a list of all the selected folders and matched subfolders
		folderList = GetFolderSearchList(filters,FolderLB_ListWave,FolderLB_SelWave)
		
		//Search the folders for matched waves.
		//The matched waves are returned to the filters structure (filters.name,filters.path)
		FindMatchedWaves(filters,folderList)
		
	ElseIf(!cmpstr(listFocus,"DataSet"))
		//Data Set Waves List
		//List and Selection waves for the list box
		Wave/T listWave = NPD:DataSetLB_ListWave
		Wave selWave = NPD:DataSetLB_SelWave
		
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
		String dsName = GetDSName()
		
		Wave/T DS_ORG = GetDataSetWave(dsName,"ORG")
		matchContents(listWave,DS_ORG)

	EndIf
	
	//BASE match wave list, no groupings; this list is the basis for any new data sets
	Wave/T MatchLB_ListWave_BASE = NPC:MatchLB_ListWave_BASE 
	matchContents(listWave,MatchLB_ListWave_BASE)	
	
	Variable numWaves = DimSize(listWave,0)
	
	//Apply the wave groupings to the wave lists in the structure
	SetWaveGrouping(filters,listWave,selWave)
	
	//If focus is on DataSet, update the data set ORG wave
	If(!cmpstr(listFocus,"DataSet"))
		dsName = GetDSName()
		Wave/T/Z DS_ORG = GetDataSetWave(dsName,"ORG")
		
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
		
						
		Variable numWS_DS = GetNumWaveSets(DS_ORG)
		
		Wave/T DS_BASE = GetDataSetWave(dsName,"BASE")
		Variable numWaves_DS = DimSize(DS_BASE,0)
		
		DisplayWaveNums(numWS_DS,numWaves_DS,"DS")
		
	Else
		saveFilterSettings("WaveMatch")
		
		//How many wave sets did we define
		Variable numWS = GetNumWaveSets(listWave)
		
		DisplayWaveNums(numWS,numWaves,"WM")
	EndIf
	
	
	
	return listWave
End

Function DisplayWaveNums(numWS,numWaves,whichList)
	Variable numWS,numWaves
	String whichList
	
	String plural = ""
	
	If(numWS > 1 || numWS == 0)
		plural = "s"
	EndIf
	
	String wavePlural = ""
	
	If(numWaves > 1 || numWaves == 0)
		wavePlural = "s"
	EndIf
	
	ControlInfo/W=NTP#Data MatchListBox
	Variable boxTop = V_Top
	
	If(!cmpstr(whichList,"WM"))
		DrawAction/W=NTP#Data getGroup=waveNumText,delete	
		SetDrawEnv/W=NTP#Data fname=$LIGHT,fstyle=2,fsize=12,gname=waveNumText,gstart
		DrawText/W=NTP#Data 50,boxTop-2,num2str(numWS) + " Wave Set" + plural +  " (" + num2str(numWaves) + " Wave" + wavePlural + ")"
		SetDrawEnv/W=NTP#Data gstop
	ElseIf(!cmpstr(whichList,"DS"))
		DrawAction/W=NTP#Data getGroup=DSwaveNumText,delete	
		SetDrawEnv/W=NTP#Data fname=$LIGHT,fstyle=2,fsize=12,gname=DSwaveNumText,gstart
		DrawText/W=NTP#Data 290,boxTop-2,num2str(numWS) + " Wave Set" + plural +  " (" + num2str(numWaves) + " Wave" + wavePlural + ")"
		SetDrawEnv/W=NTP#Data gstop
	EndIf
End

//Uses the relative Folder entry (located in the 'filters' structure)
//to return the list of folders to be searched for wave matches.
Function/S GetFolderSearchList(filters,listWave,selWave)
	STRUCT filters &filters
	Wave/T listWave
	Wave selWave
	Variable i,j
	
	DFREF NPC = $CW
	SVAR cdf = NPC:cdf
	
	//Used to save the folder selection
	SVAR folderSelection = NPC:folderSelection
	folderSelection = "" //set the folder selection to cdf as the base
	
	//Makes a list of all the selected folders and matched subfolders
	String folderList = ""
	
	//If we're matching from a data folder that has been entered as opposed to from a selection...
	//of the folder itself from its parent directory, must properly set folderSelection.
	If(sum(selWave) == 0) //no selected folders
		folderSelection = cdf //set to current data folder	
	EndIf

	
	For(i=0;i<DimSize(listWave,0);i+=1)
	
		//reset the subfolder and matched folder lists for each parent folder
		String subFolderList = ""	//all subfolders
		String relFolderList = "" //matched subfolders
		
		//For each selected Folder
		If(selWave[i]> 0)
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
	
	DFREF NPC = $CW
	SVAR cdf = NPC:cdf
	
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
	For(pos=0;pos<7;pos+=1)	
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
			case 5: //pos 6
				filterTerms = resolveListItems(filters.pos6,";")
				break
			case 6: //pos 7
				filterTerms = resolveListItems(filters.pos7,";")
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
	
	DFREF NPC = $CW
	DFREF NPD = $DSF
	
	SVAR listFocus = NPC:listFocus
	
	Variable numWaves = ItemsInList(filters.name,",")
	Variable i,j,numGroupings = ItemsInList(filters.wg,",")
	
	//Extract flags
	String itemStr = "",flag = "",value=""
	Variable numItems = ItemsInList(filters.wg,"/")
	
	//First reset to the BASE data set or ungrouped WaveMatchList
	
	If(!cmpstr(listFocus,"DataSet"))
		RemoveWaveGroupings(listWave,"DataSet")
		Wave DataSetLB_SelWave = NPD:DataSetLB_SelWave
		Redimension/N=(DimSize(listWave,0)) DataSetLB_SelWave
	ElseIf(!cmpstr(listFocus,"WaveMatch"))
		RemoveWaveGroupings(listWave,"WaveMatch")
		Wave MatchLB_SelWave = NPC:MatchLB_SelWave
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
	
	String tempFilterList = filters.wg
	
	For(i=0;i<numItems;i+=1)
	
		//Search for /L or /DTI flags. These must go first
		Variable isDTI = stringmatch(tempFilterList,"*/DTI*")
		Variable doSort = stringmatch(tempFilterList,"*/L*")
		
		If(isDTI)
			itemStr = RemoveEnding(ListMatch(tempFilterList,"*DTI*","/"),"/")
		ElseIf(doSort)
			itemStr = RemoveEnding(ListMatch(tempFilterList,"*L*","/"),"/")
		Else
			itemStr = StringFromList(i,tempFilterList,"/")
		EndIf
		
		If(!strlen(itemStr))
			continue
		EndIf
		
		flag = StringFromList(0,itemStr,"=")
		value = StringFromList(1,itemStr,"=")

		String origValue = value
		
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
			case "F":
				WaveGroup_Folder(listWave,selWave,value)
				break
			case "WSI":
				WaveGroup_WSI(listWave,selWave,value)
				break
			case "WSN":
				WaveGroup_WSN(listWave,selWave,value)
				break
			case "WSNS":
				WaveGroup_WSNStride(listWave,selWave,value)
				break
			case "B":
				WaveGroup_Block(listWave,selWave,value)
				break
			case "S":
 				WaveGroup_Stride(listWave,selWave,value)
				break
			case "L":
				WaveGroup_Line(listWave,selWave,value)
				break
			case "DTI":
				WaveGroup_DTI(listWave,selWave,value,doSort)
				break
			default:
 				WaveGroup_Position(listWave,selWave,value)
				break
		endswitch
		
		If(isDTI)
			tempFilterList = RemoveEnding(RemoveFromList("/DTI=" + origValue,tempFilterList,"/"),"/")
			numItems -=1
			i = -1
			isDTI = 0
		EndIf
		
		If(doSort)
			tempFilterList = RemoveEnding(RemoveFromList("/L",tempFilterList,"/"),"/")
			numItems -=1
			i = -1
			doSort = 0
		EndIf
		
	EndFor
End

//Removes all wave groupings from a list wave
//Useful for clearing BASE data sets
Function RemoveWaveGroupings(listWave,whichList)
	Wave/T listWave
	String whichList //WaveMatch or DataSet
	Variable i,j
	DFREF NPD = $DSF
	DFREF NPC = $CW

	strswitch(whichList)
		case "DataSet":
			//group all together
			Wave/T DS_BASE = GetDataSetWave(GetDSName(),"BASE")
			Wave/T DS_ORG = GetDataSetWave(GetDSName(),"ORG")
			Wave DataSetLB_SelWave = NPD:DataSetLB_SelWave
			
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
					Variable blockSize = 0
					Variable startWS = 0
					
					//Separate sorted waves according to their folder paths.
					For(k=0;k<DimSize(ws,0);k+=1)
						String subFolder = ParseFilePath(0,ws[k][0][1],":",1,1)
						
						Variable size = DimSize(tempWave,0)

						If(!cmpstr(subFolder,prevSubFolder))
							size = DimSize(tempWave,0)
							Redimension/N=(size + 1,1,2) tempWave //add a row to temp wave
							tempWave[k + whichWSN + startRow][0][] = ws[k][0][r]
							
							blockSize += 1
							tempWave[startWS][0][] = ReplaceString("(" + num2str(blockSize-1) + ")",tempWave[startWS][0][r],"(" + num2str(blockSize) + ")")
							
						Else
							//Start a new wave set
							size = DimSize(tempWave,0)
							Redimension/N=(size + 1,1,2) tempWave //add a row to temp wave
						 	startWS = k + whichWSN + startRow
							tempWave[k + whichWSN + startRow][0][] = "----WAVE SET " + num2str(whichWSN) + "----(0)"
							whichWSN += 1
							prevSubFolder = subFolder
							blockSize = 0
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
							tempWave[size][0][] = "----WAVE SET " + num2str(whichWSN) + "----(1)" //add number of waves in the wave set on the end
							tempWave[size + 1][0][] = ws[k][0][r]
							whichWSN += 1
							matchedTerms += term + ";"
						Else
							//Term matches one thats already defined in a wave set
							//Allocate that wave to the correct wave set
							
							//Find the WSN marker of the wave set one larger than the one we want
							//This finds the last row of the wave set we are allocating to.
							Variable wsStart = tableMatch("*WAVE SET*" + num2str(wsn + baseWSN) + "*-*",tempWave)
							If(wsStart == -1)
								continue
							EndIf
							
							//get current size of matched wave set
							String entry = tempWave[wsStart][0][0]
							Variable wsSize = str2num(StringFromList(0,entry,")",strsearch(entry,"(",0) + 1))
							
							Variable index = tableMatch("*WAVE SET*" + num2str(wsn + baseWSN + 1) + "*-*",tempWave)
							
							//If it's the last wave set, index will be -1
							//Add the matched wave to the end of the tempWave
							If(index == -1)
								index = DimSize(tempWave,0)
							EndIf
							
							//Insert the matched wave into the last slot in that wave set block
							InsertPoints/M=0 index,1,tempWave
							tempWave[index][0][] = ws[k][0][r]
							
							//Increase the wave set counter
							tempWave[wsStart][0][] = ReplaceString("(" + num2str(wsSize) + ")",entry,"(" + num2str(wsSize + 1) + ")")
							
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

//Groups the input listWave into wave sets by their folder
//0 is the immediate parent folder
//1 is the parent folder 1 level up
//2 is the parent folder 2 levels up, etc.
Function WaveGroup_Folder(listWave,selWave,value)
	Wave/T listWave
	Wave selWave
	String value //wave grouping terms
	
	Variable depth = str2num(RemoveEnding(value,","))
	
	Variable numWaves = DimSize(listWave,0)
	Variable i,j,k,m,group,wsn,firstWSN
	
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
		
		String prevSubFolder = ""
		
		Variable blockSize=0,blockStart=0
		
		//Separate sorted waves according to their folder paths.
		For(k=0;k<DimSize(ws,0);k+=1)
			String subFolder = ParseFilePath(0,ws[k][0][1],":",1,depth + 1)
			
			Variable size = DimSize(tempWave,0)

			If(!cmpstr(subFolder,prevSubFolder))
				size = DimSize(tempWave,0)
				Redimension/N=(size + 1,1,2) tempWave //add a row to temp wave
				tempWave[k + whichWSN + startRow][0][] = ws[k][0][r]
				
				tempWave[blockStart][0][] = ReplaceString("(" + num2str(blockSize) + ")",tempWave[blockStart][0][r],"(" + num2str(blockSize + 1) + ")")
				blockSize += 1
			Else
				//Start a new wave set
				blockSize = 0
				blockStart = k + whichWSN + startRow
				size = DimSize(tempWave,0)
				Redimension/N=(size + 1,1,2) tempWave //add a row to temp wave
				tempWave[k + whichWSN + startRow][0][] = "----WAVE SET " + num2str(whichWSN) + "----(0)"
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
	
End

//Must be placed first in a sequence of grouping flags, otherwise it will override all flags before it.
Function WaveGroup_DTI(listWave,selWave,value,doSort)
	//Groups the input listWave into wave sets by their line in a data set archive table
	//Only works for data archives, which are defined in tables.
	//Doesn't accept a numerical entry, just /L
	Wave/T listWave
	Wave selWave
	String value //wave grouping termsa
	Variable doSort //1 if /L flag is also present, 0 otherwise
	
	DFREF NPC = $CW
	DFREF NPD = $DSF
	
	SVAR listFocus = NPC:listFocus
	
	//Master temporary wave to build up the new wave groupings
	Make/T/FREE/N=(0,1,2) tempWave
	

	//Check that the focus is on data sets
	If(cmpstr(listFocus,"DataSet"))
		return 0
	EndIf
	
	//Check that the selected data set is a data archive
	String dsName = GetDSName()
	If(!isArchive(dsName))
		return 0
	EndIf
	
	//Get the archive table and base table
	Wave/T archive = GetDataSetWave(dsName,"Archive")
	Wave/T BASE = GetDataSetWave(dsName,"BASE")
	
	value = ResolveListItems(value,",",noEnding=1)
	
	Variable i,j,numLines = ItemsInList(value,",")
	Variable whichWSN = 0
	Variable startRow = 0
	Variable lineOffset = 0	
	
	For(i=0;i<DimSize(archive,0);i+=1)
		
		Variable pathCol = FindDimLabel(archive,1,"IgorPath")
		If(pathCol < 0)
			continue
		EndIf
		
		String path = archive[i][pathCol] //full path to the wave
		If(!strlen(path))
			path = "root:"
		EndIf
		
		Variable numWaves = 0

		
		//current size of the temporary data set wave
		Variable size = DimSize(tempWave,0)
		
		//loop through each underscore position
		For(j=0;j<10;j+=1)
			String item = archive[i][j]
			
			If(!strlen(item))
				continue
			EndIf
			
			//resolve any list syntax (commas and hyphens)
			String itemList = resolveListItems(item,",")
			
			If(j == 0)
				numWaves = ItemsInList(itemList,",")
			Else
				numWaves *= ItemsInList(itemList,",")
			EndIf		
		EndFor
		
		Variable lineMatch = WhichListItem(num2str(i),value,",")
		
		If(lineMatch != -1)
			//Is a matched line in the data set
			Redimension/N=(size + doSort + numWaves,1,2) tempWave //add rows to temp wave
			
			If(doSort)
				tempWave[startRow][0][] = "----WAVE SET " + num2str(whichWSN) + "----(" + num2str(numWaves) + ")" //add new wave set for this line
				tempWave[startRow + 1,startRow + numWaves][][] = BASE[lineOffset + p - (startRow + 1)][q][r]
				whichWSN += 1		
			Else
				tempWave[startRow,startRow + numWaves - 1][][] = BASE[lineOffset + p - startRow][q][r]
			EndIf
		
			startRow = DimSize(tempWave,0)
		EndIf
		
		lineOffset += numWaves
	EndFor
	
	//Push the sorted waves onto the listbox
	matchContents(tempWave,listWave)
	Redimension/N=(DimSize(tempWave,0)) selWave
End



//Must be placed first in a sequence of grouping flags, otherwise it will override all flags before it.
Function WaveGroup_Line(listWave,selWave,value)

	//Groups the input listWave into wave sets by their line in a data set archive table
	//Only works for data archives, which are defined in tables.
	//Doesn't accept a numerical entry, just /L
	Wave/T listWave
	Wave selWave
	String value //wave grouping termsa
	
	DFREF NPC = $CW
	DFREF NPD = $DSF
	
	SVAR listFocus = NPC:listFocus
	
	//Master temporary wave to build up the new wave groupings
	Make/T/FREE/N=(0,1,2) tempWave
	

	//Check that the focus is on data sets
	If(cmpstr(listFocus,"DataSet"))
		return 0
	EndIf
	
	//Check that the selected data set is a data archive
	String dsName = GetDSName()
	If(!isArchive(dsName))
		return 0
	EndIf
	
	//Get the archive table and base table
	Wave/T archive = GetDataSetWave(dsName,"Archive")
	Wave/T BASE = GetDataSetWave(dsName,"BASE")
	
	Variable i,j,numLines = DimSize(archive,0)
	Variable whichWSN = 0
	Variable startRow = 0
			
	For(i=0;i<numLines;i+=1)
		Variable pathCol = FindDimLabel(archive,1,"IgorPath")
		If(pathCol < 0)
			continue
		EndIf
		
		String path = archive[i][pathCol] //full path to the wave
		If(!strlen(path))
			path = "root:"
		EndIf
		
		Variable numWaves = 0

		
		//current size of the temporary data set wave
		Variable size = DimSize(tempWave,0)
		
		//loop through each underscore position
		For(j=0;j<10;j+=1)
			String item = archive[i][j]
			
			If(!strlen(item))
				continue
			EndIf
			
			//resolve any list syntax (commas and hyphens)
			String itemList = resolveListItems(item,",")
			
			If(j == 0)
				numWaves = ItemsInList(itemList,",")
			Else
				numWaves *= ItemsInList(itemList,",")
			EndIf		
		EndFor
		
		Redimension/N=(size + 1 + numWaves,1,2) tempWave //add rows to temp wave
		tempWave[startRow][0][] = "----WAVE SET " + num2str(whichWSN) + "----(" + num2str(numWaves) + ")" //add new wave set for this line

		tempWave[startRow + 1,startRow + numWaves][][] = BASE[p - (whichWSN + 1)][q][r]
		
		whichWSN += 1		
		startRow = DimSize(tempWave,0)
	EndFor
	
	//Push the sorted waves onto the listbox
	matchContents(tempWave,listWave)
	Redimension/N=(DimSize(tempWave,0)) selWave
	
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
				Variable blockStart = index
				Variable blockCount = 0
				tempWave[index][0][] = "----WAVE SET " + num2str(wsCount) + "----(1)"
				index += 1
				tempWave[index][0][] = ws[i][0][r]
				index += 1
				wsCount += 1
				blockCount += 1 //counts the waves allocated to each wave set
				nextBlock += blockSize
			Else
				//Add wave to the current block
				InsertPoints/M=0 size,1,tempWave
				tempWave[index][0][] = ws[i][0][r]
				index += 1
				blockCount += 1
			EndIf
			
			//increase the wave count in the current wave set
			tempWave[blockStart][0][] = ReplaceString("(" + num2str(blockCount-1) + ")",tempWave[blockStart][0][r],"(" + num2str(blockCount) + ")")
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
			tempWave[index][0][] = "----WAVE SET " + num2str(wsCount) + "----(0)"
			Variable wsStart = index
			Variable blockSize = 0
			
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
				
				tempWave[wsStart][0][] = ReplaceString("(" + num2str(blockSize) + ")",tempWave[wsStart][0][r],"(" + num2str(blockSize+1) + ")")
				blockSize += 1
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
		baseIndex = tableMatch("*WAVE SET*" + num2str(j) + "*-*",listWave) + 1
	
		If(baseIndex == -1)
		 	continue
		EndIf
		
			
		//get current size of matched wave set
		If(baseIndex > 0)
			String entry = listWave[baseIndex-1][0][0]
			Variable wsSize = str2num(StringFromList(0,entry,")",strsearch(entry,"(",0) + 1))
		EndIf
		
		For(i=waveSetSize-1;i>-1;i-=1) //go backwards
			
			//Not one of the indicated WSIs
			If(WhichListItem(num2str(i),value,",") == -1)
				DeletePoints/M=0 baseIndex + i,1,listWave
				If(baseIndex > 0)
					listWave[baseIndex-1][0][] = ReplaceString("(" + num2str(wsSize) + ")",listWave[baseIndex-1][0][r],"(" + num2str(wsSize-1) + ")")
				
					wsSize -= 1
				EndIf
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


//Selects wave set numbers by stride
Function WaveGroup_WSNStride(listWave,selWave,value)
	//If the value is a two part comma-separated list, the first item is the offset, the second is the stride.
	//Otherwise the default is that the first wave set is kept, and we stride from there.
	Wave/T listWave
	Wave selWave
	String value

	//list comprehension (mixes of hyphens and commas are resolved into a comma-separated list)
	value = resolveListItems(value,",")
	Variable i,numWaveSets,item,numItems
	
	//Get the stride and offset
	numItems = ItemsInList(value,",")
	If(numItems == 2)
		Variable offset = str2num(StringFromList(0,value,","))
		Variable stride = str2num(StringFromList(1,value,","))
	ElseIf(numItems == 1)
		stride = str2num(value)
		offset = 0
	EndIf
	
	//are they valid entries?
	If(numtype(stride) == 2 || numtype(offset) == 2)
		return 0
	EndIf
		
	numWaveSets = GetNumWaveSets(listWave)
	
	If(!DimSize(listWave,0))
		return 0
	EndIf
	
	String wsList = ""
	Variable count = offset
	Do
		wsList += num2str(count) + ";"
		count += stride
	While(count < numWaveSets)
	
	For(i=numWaveSets-1;i > -1;i-=1)
		If(whichlistitem(num2str(i),wsList,";") == -1)
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
	
	If(!DimSize(listWave,0))
		return 0
	EndIf
	
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
	DFREF NPC = $CW
	
	//Set the structure SVARs
	SetFilterStructure(filters,"")
	
	ControlInfo/W=NTP#Data waveNotMatch
	filters.notMatch = S_Value
	
	ControlInfo/W=NTP#Data waveMatch
	filters.match = S_Value
	
	ControlInfo/W=NTP#Data relativeFolderMatch
	filters.relFolder = S_Value			
	
	ControlInfo/W=NTP#Data waveGrouping
	filters.wg = S_Value	
	
	ControlInfo/W=NTP#Data prefixGroup
	filters.prefix = S_Value
	
	ControlInfo/W=NTP#Data groupGroup
	filters.group = S_Value
	
	ControlInfo/W=NTP#Data seriesGroup
	filters.series = S_Value
	
	ControlInfo/W=NTP#Data sweepGroup
	filters.sweep = S_Value
	
	ControlInfo/W=NTP#Data traceGroup
	filters.trace = S_Value
	
	ControlInfo/W=NTP#Data pos6Group
	filters.pos6 = S_Value
	
	ControlInfo/W=NTP#Data pos7Group
	filters.pos7 = S_Value
	
	
End

//Returns list with full path of the selected items in the WavesListBox in the Navigator
Function/S getSelectedItems()
	DFREF NPC = $CW
	//Selection and List waves
	Wave WavesLB_SelWave = NPC:WavesLB_SelWave
	Wave/T WavesLB_ListWave = NPC:WavesLB_ListWave
	
	SVAR cdf = NPC:cdf
	Variable i
	
	String selWaveList = ""

	For(i=0;i<DimSize(WavesLB_ListWave,0);i+=1)
		If(WavesLB_selWave[i] > 0)
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
	
	DFREF NPC = $CW
	DFREF NPD = $DSF
	
	SVAR listFocus = NPC:listFocus
	
	If(ParamIsDefault(filtersOnly))
		filtersOnly = 0
	EndIf
	
	String controls = "prefixGroup;groupGroup;seriesGroup;sweepGroup;traceGroup;pos6Group;pos7Group;waveGrouping;"
	
	If(!cmpstr(listFocus,"WaveMatch"))
		controls += "waveMatch;waveNotMatch;relativeFolderMatch;"
	EndIf
	
	Variable i,items = ItemsInList(controls,";")
	
	For(i=0;i<items;i+=1)
		If(filtersOnly && i > 4)
			return 0
		EndIf
		SetVariable $StringFromList(i,controls,";") win=NTP#Data,value=_STR:""
	EndFor
	
	If(!cmpstr(listFocus,"DataSet"))
		//Return to the BASE data set
		Wave/T DataSetLB_ListWave = NPD:DataSetLB_ListWave
		Wave DataSetLB_SelWave = NPD:DataSetLB_SelWave
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
		
							
		Variable numWS_DS = GetNumWaveSets(DS_ORG)
		
		Wave/T DS_BASE = GetDataSetWave(dsName,"BASE")
		Variable numWaves_DS = DimSize(DS_BASE,0)
		
		DisplayWaveNums(numWS_DS,numWaves_DS,"DS")
		
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
	
	DFREF NPC = $CW
	DFREF NPD = $DSF
	DFREF NTS = root:Packages:NT:Settings
	NVAR dataPanelWidth = NPC:dataPanelWidth
	NVAR offsetY = NTS:offsetY
	NVAR hf =  NTS:hf
	
	//listbox resize positions
	NVAR WM_Position = NPC:WM_Position
			
	SVAR listFocus = NPC:listFocus
	
	//return if the selection wasn't changed
	If(!cmpstr(selection,listFocus))
		return 0
	EndIf
	
	SetDrawLayer/W=NTP UserBack
	//Delete only the selection dots, not the rest of the draw layer
	DrawAction/W=NTP/L=UserBack getgroup=selectionDots
	DrawAction/W=NTP/L=UserBack delete=V_startPos,V_endPos
	
	ControlInfo/W=NTP#Data MatchListBox
	Variable boxTop = V_top
			
	strswitch(selection)
		case "WaveMatch":
		
			DrawAction/W=NTP#Data getgroup=dataSetLabels,delete;DrawAction/W=NTP#Data getgroup=dataSetLabels,delete
			
			SetDrawEnv/W=NTP#Data gstart,gname=dataSetLabels
			SetDrawEnv/W=NTP#Data xcoord= abs,ycoord= abs, fsize=16, textxjust= 1,textyjust= 1,fname=$LIGHT,fstyle=0
			DrawText/W=NTP#Data dataPanelWidth/2,20,"DATA SET BUILDER"
			SetDrawEnv/W=NTP#Data xcoord= abs,ycoord= abs,fstyle=1, fsize=16, textxjust= 1,textyjust= 1,textrgb=(0,54000,0),fname=$LIGHT
			DrawText/W=NTP#Data 115,boxTop - 25,"MATCHED WAVES"
			SetDrawEnv/W=NTP#Data xcoord= abs,ycoord= abs, fsize=14, textxjust= 1,textyjust= 1,fname=$LIGHT,textrgb=(0,0,0),fstyle=0
			DrawText/W=NTP#Data 355,boxTop - 25,"DATA SET WAVES"
		//	SetDrawEnv/W=NTP#Data xcoord= abs,ycoord= abs, fsize=14, textxjust= 1,textyjust= 1,fname=$LIGHT
		//	DrawText/W=NTP#Data 540,135,"DATA SETS"
			SetDrawEnv/W=NTP#Data gstop
			If(switchFilterSettings)
				//Save the current filters/grouping settings before changing focus
				saveFilterSettings("DataSet")
				
				//Recall any saved filter settings for the WaveMatch list box
				recallFilterSettings("WaveMatch")
			EndIf
						
			listFocus = "WaveMatch"
			break
		case "DataSet":
			DrawAction/W=NTP#Data getgroup=dataSetLabels,delete;DrawAction/W=NTP#Data getgroup=dataSetLabels,delete
			
			SetDrawEnv/W=NTP#Data gstart,gname=dataSetLabels
			SetDrawEnv/W=NTP#Data xcoord= abs,ycoord= abs, fsize=16, textxjust= 1,textyjust= 1,fname=$LIGHT,fstyle=0
			DrawText/W=NTP#Data dataPanelWidth/2,20,"DATA SET BUILDER"
			SetDrawEnv/W=NTP#Data xcoord= abs,ycoord= abs, fsize=14, textxjust= 1,textyjust= 1,fstyle=0,textrgb=(0,0,0),fname=$LIGHT
			DrawText/W=NTP#Data 115,boxTop - 25,"MATCHED WAVES"
			SetDrawEnv/W=NTP#Data xcoord= abs,ycoord= abs,fstyle=1, fsize=16, textxjust= 1,textyjust= 1,textrgb=(0,54000,0),fname=$LIGHT
			DrawText/W=NTP#Data 355,boxTop - 25,"DATA SET WAVES"
		//	SetDrawEnv/W=NTP#Data xcoord= abs,ycoord= abs, fsize=14, textxjust= 1,textyjust= 1,fname=$LIGHT
		//	DrawText/W=NTP#Data 540,135,"DATA SETS"
			SetDrawEnv/W=NTP#Data gstop
			
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
	
	DFREF NPC = $CW
	DFREF NPD = $DSF
	
	SVAR filterSettings = NPC:filterSettings
	
	If(!cmpstr(selection,"WaveMatch"))
		filterSettings = getFilterSettings()
	ElseIf(!cmpstr(selection,"DataSet"))
		Wave/T DS_ORG = GetDataSetWave(GetDSName(),"ORG")
		Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
		
		Variable index = GetDSIndex()
		If(index != -1 && WaveExists(DS_ORG))
			String origFilterSettings = StringsFromList("11-17",DSNamesLB_ListWave[index][0][1],";")

			DSNamesLB_ListWave[index][0][1] = getFilterSettings() + origFilterSettings
		EndIf
	EndIf
End


//Recalls match/filter/grouping settings and applies them to the list box
Function/S recallFilterSettings(selection)
	String selection
	STRUCT filters filters
	
	DFREF NPC = $CW
	DFREF NPD = $DSF
	
	SVAR filterSettings = NPC:filterSettings
	String dsFilters = ""

	SetFilterStructure(filters,"")
	
	If(!cmpstr(selection,"WaveMatch"))
		//WaveMatch list and selection waves
		Wave/T listWave = NPC:MatchLB_ListWave
		Wave selWave = NPC:MatchLB_SelWave
		
		//Fill out the structure with the saved settings
		filters.match = StringFromList(0,filterSettings,";")
		filters.notMatch = StringFromList(1,filterSettings,";")
		filters.relFolder = StringFromList(2,filterSettings,";")
		filters.prefix = StringFromList(3,filterSettings,";")
		filters.group = StringFromList(4,filterSettings,";")
		filters.series = StringFromList(5,filterSettings,";")
		filters.sweep = StringFromList(6,filterSettings,";")
		filters.trace = StringFromList(7,filterSettings,";")
		filters.pos6 = StringFromList(8,filterSettings,";")
		filters.pos7 = StringFromList(9,filterSettings,";")
		filters.wg = StringFromList(10,filterSettings,";")
		
		//output the filter structure to a string list for the return value
		String filterSettingStr = getFilterSettings()
		
	ElseIf(!cmpstr(selection,"DataSet"))
		//Get the selected data set ORGANIZED wave
		String dataset = GetDSName()
		Wave/T/Z DS_ORG = GetDataSetWave(dataset,"ORG")
		Variable index = GetDSIndex(dataset=dataset)
		
		//Fill out the structure with the saved settings
		//WaveMatch list and selection waves
		Wave/T listWave = NPD:DataSetLB_ListWave
		Wave selWave = NPD:DataSetLB_SelWave
		
		Wave/T/Z DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
		
		//For data sets with no waves in them, set filters to empty
		If(index == -1 || !WaveExists(DS_ORG) || index > DimSize(DSNamesLB_ListWave,0))
			dsFilters = ";;;;;;;;;;;;;;;;;"
		ElseIf(DimSize(DSNamesLB_ListWave,0) == 0)
			dsFilters = ";;;;;;;;;;;;;;;;;"
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
		filters.pos6 = StringFromList(8,dsFilters,";")
		filters.pos7 = StringFromList(9,dsFilters,";")
		filters.wg = StringFromList(10,dsFilters,";")
		
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
		filters.prefix = StringFromList(11,dsFilters,";")
	Else
		filters.prefix = StringFromList(3,dsFilters,";")
	EndIf
	
	If(!strlen(StringFromList(4,dsFilters,";")))
		filters.group = StringFromList(12,dsFilters,";")
	Else
		filters.group = StringFromList(4,dsFilters,";")
	EndIf
	
	If(!strlen(StringFromList(5,dsFilters,";")))
		filters.series = StringFromList(13,dsFilters,";")
	Else
		filters.series = StringFromList(5,dsFilters,";")
	EndIf
	
	If(!strlen(StringFromList(6,dsFilters,";")))
		filters.sweep = StringFromList(14,dsFilters,";")
	Else
		filters.sweep = StringFromList(6,dsFilters,";")
	EndIf	
	
	If(!strlen(StringFromList(7,dsFilters,";")))
		filters.trace = StringFromList(15,dsFilters,";")
	Else
		filters.trace = StringFromList(7,dsFilters,";")
	EndIf	
	
	If(!strlen(StringFromList(8,dsFilters,";")))
		filters.pos6 = StringFromList(16,dsFilters,";")
	Else
		filters.pos6 = StringFromList(8,dsFilters,";")
	EndIf
	
	If(!strlen(StringFromList(9,dsFilters,";")))
		filters.pos7 = StringFromList(17,dsFilters,";")
	Else
		filters.pos7 = StringFromList(9,dsFilters,";")
	EndIf
	
	//Change the controls
	UpdateFilterControls(filters)
End

//Takes the current contents of the filters structure,
//and updates all the controls, except for the wave matching controls
Function UpdateFilterControls(filters)
	STRUCT filters &filters
	
	SetVariable prefixGroup win=NTP#Data,value=_STR:filters.prefix
	SetVariable groupGroup win=NTP#Data,value=_STR:filters.group
	SetVariable seriesGroup win=NTP#Data,value=_STR:filters.series
	SetVariable sweepGroup win=NTP#Data,value=_STR:filters.sweep
	SetVariable traceGroup win=NTP#Data,value=_STR:filters.trace
	SetVariable pos6Group win=NTP#Data,value=_STR:filters.pos6		
	SetVariable pos7Group win=NTP#Data,value=_STR:filters.pos7
	
	SetVariable waveGrouping win=NTP#Data,value=_STR:filters.wg	
	
	SetVariable waveMatch win=NTP#Data,value=_STR:filters.match
	SetVariable waveNotMatch win=NTP#Data,value=_STR:filters.notMatch
	SetVariable relativeFolderMatch win=NTP#Data,value=_STR:filters.relFolder
End

//Selects the folders in the folder list in the Navigator list box
Function SelectFolder(folderList)
	String folderList
	Variable i,j,numFolders = ItemsInList(folderList,";")
	
	DFREF NPC = $CW
	DFREF NPD = $DSF
	
	SVAR cdf = NPC:cdf
	
	//Data Set Name wave list and filter info
	Wave/T DSNamesLB_ListWave =NPD:DSNamesLB_ListWave
	
	//Folder list and selection waves
	Wave/T FolderLB_ListWave = NPC:FolderLB_ListWave
	Wave FolderLB_SelWave = NPC:FolderLB_SelWave
	
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
	
	If(!cmpstr(folder,"root:"))
		SetDataFolder root:
		cdf = "root:"
	Else
		SetDataFolder $parent
		cdf = parent
	EndIf
	
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
	DFREF NPC = $CW
	DFREF NPD = $DSF
	DFREF NTS = root:Packages:NeuroToolsPlus:Settings
	
	if (!DataFolderRefStatus(NTS))
		NewDataFolder/O root:Packages:NeuroToolsPlus:Settings
		DFREF NTS = root:Packages:NeuroToolsPlus:Settings
		Variable/G NTS:hf
	endif
	
	NVAR hf =  NTS:hf
	SVAR listFocus = NPC:listFocus
	Variable i = 0,row = -1
	
	//Select the list and selection waves
	strswitch(listFocus)
		case "WaveMatch":
			Wave/T listWave = NPC:MatchLB_ListWave
			Wave selWave = NPC:MatchLB_SelWave
			break
		case "DataSet":
			Wave/T listWave = NPD:DataSetLB_ListWave
			Wave selWave = NPD:DataSetLB_SelWave
			break	
	endswitch
	
	//Find the first selected row
	If(DimSize(selWave,0) > 0)
		Do
			If(selWave[i] > 0)
				row = i
				break
			EndIf
			i+=1
		While(i < DimSize(selWave,0))
	EndIf
	
	//no selection, delete text
	If(row == -1)
		DrawAction/W=NTP getGroup=fullPathText,delete
		return 0
	EndIf
	
	//Update the text box
	DrawAction/W=NTP getGroup=fullPathText,delete	
	SetDrawEnv/W=NTP fname=$LIGHT,fstyle=2,fsize=10,gname=fullPathText,gstart
	DrawText/W=NTP 14,464*hf,listWave[row][0][1]
	SetDrawEnv/W=NTP gstop
	
End	


//Returns a list of the waves to be operated on by a selected command function
Function/S GetWaveList(ds)
	STRUCT ds &ds
	Variable wsn //wave set number
	String list = ""
	
	DFREF NPC = $CW
	DFREF NPD = $DSF
	DFREF NTSI = root:Packages:NT:ScanImage
	
	//Wave Selector status
	SVAR WaveSelectorStr = NPC:WaveSelectorStr
	SVAR cdf = NPC:cdf
	
	Variable i
	
	For(i=0;i<ds.numDataSets;i+=1)
		strswitch(ds.name[i])
			case "Wave Match":
				Wave/T listWave = NPC:MatchLB_ListWave
				break
			case "Navigator":
				Wave/T WavesLB_ListWave = NPC:WavesLB_ListWave
				Wave selWave = NPC:WavesLB_SelWave
					
				Duplicate/FREE/T WavesLB_ListWave,listWave
				For(i=DimSize(selWave,0) - 1;i > -1;i-=1) //go backwards
					If(selWave[i] != 1)
						DeletePoints/M=0 i,1,listWave
					Else
						listWave[i] = cdf + listWave[i]
					EndIf
				EndFor
				break
			case "Image Browser":
				Execute/Q/Z "root:Packages:NT:returnStr = SelectedScanFields(fullpath=1)"
				SVAR returnStr = NPC:returnStr
				return returnStr
				break
			default:
				//Data Set
				Wave/T listWave = GetDataSetWave(ds.name[i],"ORG")
				break
		endswitch
		
		Wave/T/Z ws = GetWaveSet(listWave,ds.wsn)
		If(!WaveExists(ws))
			return ""
		EndIf
		
		list = TextWaveToStringList(ws,";",layer=1)
	EndFor
	
	
	
	return list
End

//Returns info about the data set
//Automatically chooses whatever option is selected in the Wave Selector menu
//Function GetDataSetInfo(ds[,extFunc])
//	STRUCT ds &ds 
//	Variable extFunc //is this an external function? We ignore the wavelistselector in this case
//	
//	DFREF NPC = $CW
//	DFREF NPD = $DSF
//	
//	//Wave Selector status
//	SVAR WaveSelectorStr = NPC:WaveSelectorStr
//	SVAR cdf = NPC:cdf
//	
//	Variable i
//	
//	If(ParamIsDefault(extFunc))
//		extFunc = 0
//	EndIf
//	
//	If(!extFunc)
//		strswitch(WaveSelectorStr)
//			case "Wave Match":
//				Wave/T listWave = NPC:MatchLB_ListWave
//				break
//			case "Navigator":
//				Wave/T WavesLB_ListWave = NPC:WavesLB_ListWave
//				Wave selWave = NPC:WavesLB_SelWave
//					
//				Duplicate/FREE/T WavesLB_ListWave,listWave
//				For(i=DimSize(selWave,0) - 1;i > -1;i-=1) //go backwards
//					If(selWave[i] > 0)
//						listWave[i] = cdf + listWave[i]
//					Else
//						DeletePoints/M=0 i,1,listWave
//					EndIf
//				EndFor
//	
//				break
//			case "Image Browser":
//				Execute/Q/Z "root:Packages:NT:returnStr = SelectedScanFields(fullpath=1)"
//				SVAR returnStr = NPC:returnStr
//				
//				Wave/T listWave = StringListToTextWave(returnStr,";")
//				break
//			default:
//				//Data Set
//				Wave/T listWave = GetDataSetWave(WaveSelectorStr,"ORG")
//				
//		endswitch
//	Else
//		//external function call
//		Wave/T listWave = getExtFuncDataSet()
//		Wave/T ds.listWave = listWave
//	EndIf
//	
//	If(DimSize(listWave,0) == 0)
//		SVAR ds.paths = NPD:DataSetWaves
//		ds.paths = "NULL" //prevents error in 'Run Cmd'
//		return -1
//	EndIf
//	
//	//Fill out the data set structure
//	Wave/T ds.listWave = listWave
//	SVAR ds.name = NPC:WaveSelectorStr
//	SVAR ds.paths = NPD:DataSetWaves
//	ds.numWaveSets= GetNumWaveSets(listWave)
//	ds.wsn = 0
//	ds.wsi = 0
//	ds.numWaves = GetNumWaves(listWave,ds.wsn)
//	Wave/WAVE ds.waves = GetWaveSetRefs(listWave,ds.wsn)
//	ds.paths = GetWaveSetList(listWave,ds.wsn,1)
//	
//	If(extFunc)
//		ds.name = StringFromList(1,NameOfWave(ds.listWave),"_")
//	EndIf
//	
//	//Fill out the progress bar structure	
//	ds.progress.steps = ceil((ds.numWaveSets* ds.numWaves) / 10) //number of steps that must be processed for each update to progress bar
//	ds.progress.increment = 10 //set to 10 increments to limit overhead for ControlUpdate (~5 ms per call)
//	
//	NVAR ds.progress.value = NPC:progressVal
//	ds.progress.value = 0
//	
//	NVAR ds.progress.count = NPC:progressCount
//	ds.progress.count = 0
//	
//	ValDisplay progress win=NT,disable=0	
//	return 0
//End

//Uses the data set input and suffix to create a new output wave of the correct size
Function/WAVE MakeOutputWave(ds,suffix,size)
	STRUCT ds &ds
	String suffix
	Variable size //0=number of waves in waveset
					  //1=size of the first wave in waveset
					  
	SetDataFolder GetWavesDataFolder(ds.waves[0][0],1)
	
	String outName = NameOfWave(ds.waves[0][0]) + "_" + suffix
	
	If(!size)
		Make/O/N=(ds.numWaves[0]) $outName/Wave=outWave
	Else
		Make/O/N=(DimSize(ds.waves[0][0],0)) $outName/Wave=outWave
	EndIf
	
	return outWave
End

Function GetDataSetInfo(ds)
	STRUCT ds &ds 
	
	DFREF NPC = $CW
	DFREF NPD = $DSF
	
	//Return all of the defined data sets for the function
	Wave/T listWave = getExtFuncDataSet()
	Wave/T ds.listWave = listWave
	
	//Number of returned data sets
	ds.numDataSets = DimSize(listWave,1)
	ds.numDataSets = (!ds.numDataSets) ? 1 : ds.numDataSets
	
	//Each data set gets it's own parameter for how many waves it has in the current waveset
	Make/N=(ds.numDataSets)/O NPD:numDataSetWaves
	Wave ds.numWaves = NPD:numDataSetWaves
	
	Make/WAVE/N=(0)/O NPD:outputWaves
	Wave/WAVE ds.output = NPD:outputWaves
	
	Variable i
	//Loop through each data set
	For(i=0;i<ds.numDataSets;i+=1)
		//Full paths
		String fullPaths = GetWaveSetList(listWave,ds.wsn,1,dsNum=i)	
		Variable numItems = ItemsInList(fullPaths,";")
		
		If(i == 0)
			//Full paths
			Make/O/T/N=(numItems,ds.numDataSets) NPD:DataSetWavePaths
			Wave/T ds.paths = NPD:DataSetWavePaths
			
			//Number of waves in the waveset of each data set
			Make/O/N=(ds.numDataSets) NPD:numDataSetWaves
			Wave ds.numWaves = NPD:numDataSetWaves
			
			//Data Set Names
			Make/T/O/N=(ds.numDataSets) NPD:DataSetNames
			Wave/T ds.name = NPD:DataSetNames
			
			//Number of wavesets per data set
			Make/O/N=(ds.numDataSets) NPD:NumWaveSets
			Wave ds.numWaveSets= NPD:NumWaveSets
		Else
			If(numItems > DimSize(ds.paths,0))
				Redimension/N=(numItems,-1) ds.paths
			EndIf
		EndIf
				
		Wave/T tempPaths = StringListToTextWave(fullPaths,";")
		Redimension/N=(DimSize(ds.paths,0)) tempPaths
		
		If(DimSize(ds.paths,0) > 0)
			ds.paths[][i] = tempPaths[p][0]
		EndIf
		
		If(DimSize(ds.numWaves,0) > 0)
			ds.numWaves[i] = numItems
		EndIf
		
		If(DimSize(ds.name,0) > 0)
			ds.name[i] = GetDimLabel(ds.listWave,1,i)
		EndIf
		
		If(DimSize(ds.numWaveSets,0) > 0)
			ds.numWaveSets[i] = GetNumWaveSets(listWave,dsNum=i)
		EndIf
	EndFor
	
	ds.wsn = 0
	ds.wsi = 0
	
	Wave/WAVE ds.waves = GetWaveSetRefs(listWave,ds.wsn,ds.name)
	
	//Copy over the dimension labels to the other waves that are indexed by data set
	For(i=0;i<DimSize(ds.waves,1);i+=1)
		String theLabel = GetDimLabel(ds.waves,1,i)
		SetDimLabel 0,i,$theLabel,ds.numWaves
		SetDimLabel 1,i,$theLabel,ds.paths
	EndFor
	
	return 0
	
End
//USES ds structure, which is better for handling multiple data set definitions
//Returns info about the data set
//Automatically chooses whatever option is selected in the Wave Selector menu
//Function GetDataSetInfo(ds[,extFunc])
	STRUCT ds &ds 
	Variable extFunc //is this an external function? We ignore the wavelistselector in this case
	
	DFREF NPC = $CW
	DFREF NPD = $DSF
	
	//Wave Selector status
	SVAR WaveSelectorStr = NPC:WaveSelectorStr
	SVAR cdf = NPC:cdf
	
	Variable i
	
	If(ParamIsDefault(extFunc))
		extFunc = 0
	EndIf
	
	If(!extFunc)
		strswitch(WaveSelectorStr)
			case "Wave Match":
				Wave/T listWave = NPC:MatchLB_ListWave
				break
			case "Navigator":
				Wave/T listWave = GetNavigatorWaveSelection()
				
				break
			case "Image Browser":
				Execute/Q/Z "root:Packages:NT:returnStr = SelectedScanFields(fullpath=1)"
				SVAR returnStr = NPC:returnStr
				
				Wave/T listWave = StringListToTextWave(returnStr,";")
				break
			default:
				//Data Set
				Wave/T listWave = GetDataSetWave(WaveSelectorStr,"ORG")
				
		endswitch
	Else
		//external function call
		Wave/T listWave = getExtFuncDataSet()
		Wave/T ds.listWave = listWave
	EndIf
	
	If(DimSize(listWave,0) == 0)
		Wave/T ds.paths = NPD:DataSetWaves
		ds.paths = "NULL" //prevents error in 'Run Cmd'
		return -1
	EndIf
	
	//Fill out the data set structure
	ds.numDataSets = DimSize(listWave,1)
	Wave/T ds.listWave = listWave
	
	Make/N=(ds.numDataSets)/O NPD:numDataSetWaves
	Wave ds.numWaves = NPD:numDataSetWaves
	
	For(i=0;i<ds.numDataSets;i+=1)
		//Full paths
		String fullPaths = GetWaveSetList(listWave,ds.wsn,1,dsNum=i)	
		Variable numItems = ItemsInList(fullPaths,";")
		
		If(i == 0)
			//Full paths
			Make/O/T/N=(numItems,ds.numDataSets) NPD:DataSetWavePaths
			Wave/T ds.paths = NPD:DataSetWavePaths
			
			//Number of waves in the waveset of each data set
			Make/O/N=(ds.numDataSets) NPD:numDataSetWaves
			Wave ds.numWaves = NPD:numDataSetWaves
			
			//Data Set Names
			Make/T/O/N=(ds.numDataSets) NPD:DataSetNames
			Wave/T ds.name = NPD:DataSetNames
			
			//Number of wavesets per data set
			Make/O/N=(ds.numDataSets) NPD:NumWaveSets
			Wave ds.numWaveSets= NPD:NumWaveSets
		Else
			If(numItems > DimSize(ds.paths,0))
				Redimension/N=(numItems,-1) ds.paths
			EndIf
		EndIf
				
		Wave/T tempPaths = StringListToTextWave(fullPaths,";")
		Redimension/N=(DimSize(ds.paths,0)) tempPaths
		
		ds.paths[][i] = tempPaths[p][0]
		ds.numWaves[i] = numItems
		ds.name[i] = GetDimLabel(ds.listWave,1,i)
		ds.numWaveSets[i] = GetNumWaveSets(listWave,dsNum=i)
	EndFor
	
	ds.wsn = 0
	ds.wsi = 0
	
	Wave/WAVE ds.waves = GetWaveSetRefs(listWave,ds.wsn,ds.name)
	
//	If(extFunc)
//		ds.name = StringFromList(1,NameOfWave(ds.listWave),"_")
//	EndIf
	
	//Fill out the progress bar structure	
	ds.progress.steps = ceil((ds.numWaveSets[0] * ds.numWaves[0]) / 10) //number of steps that must be processed for each update to progress bar
	ds.progress.increment = 10 //set to 10 increments to limit overhead for ControlUpdate (~5 ms per call)
	
	NVAR ds.progress.value = NPC:progressVal
	ds.progress.value = 0
	
	NVAR ds.progress.count = NPC:progressCount
	ds.progress.count = 0
	
	ValDisplay progress win=NT,disable=0	
	return 0
End

Function/WAVE GetNavigatorWaveSelection()
	DFREF NPC = $CW
	Wave/T WavesLB_ListWave = NPC:WavesLB_ListWave
	Wave selWave = NPC:WavesLB_SelWave
	SVAR cdf = NPC:cdf
	
	Variable i
	Duplicate/O/T WavesLB_ListWave,NPC:NavigatorSelection_ListWave
	Wave/T listWave = NPC:NavigatorSelection_ListWave
	
	For(i=DimSize(selWave,0) - 1;i > -1;i-=1) //go backwards
		If(selWave[i] > 0)
			listWave[i] = cdf + listWave[i]
		Else
			DeletePoints/M=0 i,1,listWave
		EndIf
	EndFor
	
	return listWave
End

//Updates the progress bar value, which is then accessed by a background function to update the control
//Function updateProgress(ds)
//	STRUCT ds &ds
//	
//	ds.progress.count += 1
//	If(!mod(ds.progress.count,ds.progress.steps))
//		ds.progress.value += ds.progress.increment
//		ControlUpdate/W=NTP progress
//	EndIf
//End

//Removes the spacer and drop down symbol from the button titles on data set defined buttons
Function/S removeSpacer(dsName)
	String dsName
	
	If(!strlen(dsName))
		return ""
	EndIf
	
	//must remove the leading spacer
	dsName = dsName[6,strlen(dsName)-1]
	Do
		String c = dsName[0]
		If(!cmpstr(c," "))
			dsName = dsName[1,strlen(dsName)-1]
		Else
			break	
		EndIf
	While(1)	
	return dsName
End

//For the selected external function, finds any data sets and returns their listwave
Function/WAVE getExtFuncDataSet([func])
	String func 
	If(ParamIsDefault(func))
		func = CurrentExtFunc()
	EndIf
	
	Variable i,j,numParams = str2num(getParam("N_PARAMS",func))
	
	DFREF NPC = $CW
	DFREF NPD = $DSF	
	
	SVAR cdf = NPC:cdf
	
	Make/T/O/N=(0,0,2) NPD:extFuncDataSets /Wave=extFuncDataSets
	Variable count = 0
	
	For(i=0;i<numParams;i+=1)
		String ctrlName = "param" + num2str(i)
	
		//check if it's a pop up menu
		ControlInfo/W=NTP#Func $ctrlName
		
		If(abs(V_flag) == 1 || abs(V_flag) == 3) 
			
			//Check if the name is a data set reference or current data folder references. If it's not either it is a user defined pop up menu			
			String name = getParam("PARAM_" + num2str(i) + "_NAME",func)
			
			If(stringmatch(name,"CDF_*"))
				Variable isCDF = 1
			Else
				isCDF = 0
			EndIf
			
			If(!stringmatch(name,"DS_*") && !stringmatch(name,"CDF_*"))
				continue
			EndIf
			
			String dsName = getParam("PARAM_" + num2str(i) + "_VALUE",func)
			
			If(!strlen(dsName))
				dsName = S_Title
				
				//must remove the leading spacer
				dsName = removeSpacer(dsName)
			EndIf
			
			
			If(stringmatch(dsName,"**Wave Match**"))
				Wave/T ds = NPC:MatchLB_ListWave
			ElseIf(stringmatch(dsName,"**Navigator**"))
				Wave/T WavesLB_ListWave = NPC:WavesLB_ListWave
				Wave WavesLB_SelWave = NPC:WavesLB_SelWave
				
				//get selected waves in the navigator
				Variable navCount = 0
				Make/N=0/T/O NPC:NavigatorSelectionWave/Wave = navSelect
				
				For(j=0;j<DimSize(WavesLB_ListWave,0);j+=1)
					If(WavesLB_SelWave[j] > 0)
						navCount += 1
						Redimension/N=(navCount) navSelect
						navSelect[navCount - 1] = cdf + WavesLB_ListWave[j][1]
					EndIf
				EndFor
				
				Wave/T ds = NPC:NavigatorSelectionWave
			Else
				//Determine if the data set name is actually a wave path or list of wave paths
				Variable numItems = ItemsInList(dsName,";") 
				If(numItems == 1)
					If(WaveExists($StringFromList(0,dsName,";")))
						Variable isWaveList = 1
					Else
						isWaveList = 0
					EndIf
				Else
					isWaveList = 1
				EndIf
				
				//standard data set definition
				If(!isCDF && !isWaveList)
					Wave/T ds = GetDataSetWave(dsName,"ORG")
				Else
					//wave list definition
					Make/N=(numItems,1,2)/O/T NPC:FunctionWaveList/Wave=FunctionWaveList
					Wave/T list = StringListToTextWave(dsName,";")
					FunctionWaveList[][] = list[p][0]
					Wave/T ds = FunctionWaveList
				EndIf
			EndIf
					
			If(DimSize(ds,0) > DimSize(extFuncDataSets,0))
				Redimension/N=(DimSize(ds,0),DimSize(extFuncDataSets,1)+1,2) extFuncDataSets
			ElseIf(isCDF)
				Redimension/N=(-1,DimSize(extFuncDataSets,1)+1,2) extFuncDataSets
			Else
				Redimension/N=(-1,DimSize(extFuncDataSets,1)+1,2) extFuncDataSets
			EndIf
			
			If(isCDF)
				Variable size = 1
			Else
				size = DimSize(ds,0)
			EndIf
			
			If(size > 0)
				If(isCDF)
					extFuncDataSets[0][count][0] = dsName
					extFuncDataSets[0][count][1] = GetDataFolder(1) + dsName
				Else
					extFuncDataSets[0,DimSize(ds,0)-1][count][] = ds[p][0][r]
				EndIf
			EndIf
			
			//Truncate the DS_ from the data set variable name
			name = StringsFromList("1-*",name,"_",noEnding=1)
			SetDimLabel 1,count,$name,extFuncDataSets
			
			count += 1
//			return ds
		EndIf
	EndFor	
	
	return extFuncDataSets
//	
//	If(count == 0)
//		return $""
//	Else
//		return extFuncDataSets
//	EndIf
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
	
	DFREF saveDF = GetDataFolderDFR()
	
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

	
	KillWaves/Z filterWave,coefs
	
	SetDataFolder saveDF
End

Function ResetAllTimers()
	Variable i
	For(i=0;i<10;i+=1)
		Variable ref = StopMSTimer(i)
	EndFor
End


//Kills wave even if it is a part of a graph or window
Function ReallyKillWaves(w)
  Wave/Z w
	
  If(!WaveExists(w))
  	return 0
  EndIf
  
  string name=nameofwave(w)
  string graphs=WinList("*",";","WIN:1") // A list of all graphs
  
  //NeuroToolsPlus Viewer needs to be checked
  graphs += "NTP#Nav#Viewer"
  
  variable i,j
  for(i=0;i<itemsinlist(graphs);i+=1)
    string graph=stringfromlist(i,graphs)
    string traces=TraceNameList(graph,";",3)
    string images = ImageNameList(graph,";")
    
    //check all the twoP graph subwindows
    strswitch(graph)
    	case "twoPScanGraph":
    	
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
	    	
    		break
    	case "":
    		break
    	default:    
		    if(whichlistitem(name,traces) != -1) // Assumes that each wave is plotted at most once on a graph.  
		      RemoveFromGraph/Z /W=$graph $name
		    endif
		    
		    if(whichlistitem(name,images) != -1) // Assumes that each wave is plotted at most once on a graph.  
		      RemoveImage/Z /W=$graph $name
		    endif
    		break
    endswitch
    
  endfor
  

  string tables=WinList("*",";","WIN:2") // A list of all tables
  for(i=0;i<itemsinlist(tables);i+=1)
    string table=stringfromlist(i,tables)
    j=0
    do
      
      String info = TableInfo(table,j)
      
      If(!strlen(info))
      	break
      EndIf
      
      //Name of wave in the column
      name = StringByKey("WAVE",info,":",";")
      
      If(!cmpstr(GetWavesDataFolder(w,2),name))
      	 RemoveFromTable/Z/W=$table $name.d,$name.l
      	
      EndIf
      
      
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
      
      
      //Check 
    while(1)
  endfor 

  killwaves /z w
End  

//Returns a list of the #waves in each waveset of the data set
Function/S GetDataSetDims(dsName,[WM,Nav])
	String dsName
	Variable WM,Nav
	String dims = ""
	
	WM = (ParamIsDefault(WM)) ? 0 : 1
	Nav = (ParamIsDefault(Nav)) ? 0 : 1
	
	If(!strlen(dsName))
		return ""
	EndIf
	
	If(WM)
		Wave/T/Z ds = root:Packages:NeuroToolsPlus:ControlWaves:MatchLB_ListWave
	ElseIf(Nav)
		Wave/T/Z ds = root:Packages:NeuroToolsPlus:ControlWaves:NavigatorSelection_ListWave
	Else
		Wave/T/Z ds = GetDataSetWave(dsName,"ORG")
	EndIf
	
	If(!WaveExists(ds))
		return ""
	EndIf	
	
	Variable i,numWaveSets = GetNumWaveSets(ds)
	For(i=0;i<numWaveSets;i+=1)
		dims += num2str(GetNumWaves(ds,i)) + ";"
	EndFor
	
	return dims
End

//Returns a string list of angles according to the input expression or list in 'Measure' command for the 'Vector Sum' measurement.
Function/S GetVectorSumAngles(ds,angleExpression)
	STRUCT ds &ds
	String angleExpression
	
	//Number of angles to use
	Variable size = DimSize(ds.waves[ds.wsi],0)
	
	//Is it a list?
	If(stringmatch(angleExpression,"*,*"))
		String separator = ","
	ElseIf(stringmatch(angleExpression,"*;*"))
		separator = ";"
	Else
		separator = ""
	EndIf
	
	//If not expression was input, use the native X scaling of the data wave
	If(!strlen(angleExpression))
		angleExpression = num2str(DimOffset(ds.waves[ds.wsi],0)) + " + "
		angleExpression += num2str(DimDelta(ds.waves[ds.wsi],0)) + "*x"
	EndIf
	
	//If there was no list separator (comma or semi-colon), must be an expression
	If(!strlen(separator))
		//resolves a mathematical expression into a semi-colon list of angles
		String angles = ResolveAngleExpression(angleExpression,size)
	Else
		angles = ReplaceString(separator,angleExpression,";")
	EndIf

	return angles
End

//Resolves a mathematical expression into a semi-colon list of angles
Function/S ResolveAngleExpression(expression,size)
	String expression
	Variable size
	
	Make/O/N=(size) root:Packages:NeuroToolsPlus:angleResult
	
	If(stringmatch(expression,"*,*"))
		//It's a list
		Execute "root:Packages:NeuroToolsPlus:angleResult = {" + expression + "}"
	Else
		//It's an expression
		Execute "root:Packages:NeuroToolsPlus:angleResult = " + expression
	EndIf
	
	Wave angleResult = root:Packages:NeuroToolsPlus:angleResult
	
	//Ensure that all angles are within 0-360 range, wrap circularly
	Variable i
	For(i=0;i<size;i+=1)
		//If the angle is greater than 360°
		If(angleResult[i] >= 360)
			Variable remainder = angleResult[i]
			Do
				remainder -= 360
			While(remainder >= 360)
			angleResult[i] = remainder
			
		//If the angle is less than -360°
		ElseIf(angleResult[i] <= - 360)
			remainder = angleResult[i]
			Do
				remainder += 360
			While(remainder <= 360)
			angleResult[i] = remainder
		EndIf	
	EndFor
	
	//Get rid of negative zeros
	angleResult = (angleResult == -0) ? 0 : angleResult

	//Convert numeric wave to a text wave
	Make/FREE/T/O/N=(size) angles
	angles = num2str(angleResult)
	
	//Convert text wave to a string list
	String angleList = TextWaveToStringList(angles,";")
	return angleList
End

//Resolves the syntax used in the Cmd input for 'Run Cmd Line' function
//Replaces data set references <DataSet> with the name of the wave
//<DataSet>{wsn,wsi}
Function/S resolveCmdLine(cmdLineStr,wsn,wsi)
	String cmdLineStr
	Variable wsn,wsi
	
	DFREF NPC = $CW
	
	//WaveSet data
	//ControlInfo/W=NTP extFuncDS
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
			
			strswitch(dsName)
				case "WM":
					//wave match
					Wave/T/Z ds = NPC:MatchLB_ListWave
					break
				case "NAV":
					Wave/T/Z ds = GetNavigatorWaveSelection()
					break
				default:
					Wave/T/Z ds = GetDataSetWave(dsName,"ORG")
					break
			endswitch
			
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

				String theWaveSet = GetWaveSetList(ds,wsnIndex,1)
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
					theWaveSet = GetWaveSetList(ds,wsn,1)
					
					//If we're using two data sets, and one is longer than the other, this may occur
					//Or if we have a single wave data set operating on all waves of a second data set
					If(wsi > ItemsInList(theWaveSet,";") - 1)
						theWaveStr = StringFromList(ItemsInList(theWaveSet,";") - 1,theWaveSet,";")
					Else
						theWaveStr = StringFromList(wsi,theWaveSet,";")
					EndIf
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
	DFREF NPC = $CW
	SVAR masterCmdLineStr = NPC:masterCmdLineStr
	
	ControlInfo/W=NTP cmdLineStr
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

	DFREF NPC = $CW
	SVAR masterCmdLineStr = NPC:masterCmdLineStr
	
	Variable i,xPos,yPos
	xPos = 461
	yPos = 159
	
	//Clear previous command string text
	DrawAction/W=NTP getgroup=CmdLineText,delete
	
	//Draw the command string text in lines
	SetDrawEnv/W=NTP gname=CmdLineText,gstart
	For(i=0;i<ItemsInList(masterCmdLineStr,";/;");i+=1)
		SetDrawEnv/W=NTP fname=$LIGHT,fsize=10
		DrawText/W=NTP xPos,yPos,"\f01" + num2str(i) + ": \f00" + StringFromList(i,masterCmdLineStr,";/;")
		yPos += 20
	EndFor
	SetDrawEnv/W=NTP gstop
End

//Clears the master command line entry
Function clearCommandLineEntry()
	DFREF NPC = $CW
	SVAR masterCmdLineStr = NPC:masterCmdLineStr
	masterCmdLineStr = ""
	
	SetVariable cmdLineStr win=NT,value=_STR:""
	
	//Clear previous command string text
	DrawAction/W=NTP getgroup=CmdLineText,delete
	
	//Set the window hook for deleting and editing specific entries
	SetWindow NT hook(cmdLineEntryHook) = $""
End


//VIEWER FUNCTIONS------------------------------------------------

//Opens the Trace Viewer window
Function openViewer()
	DFREF NPC = $CW
	DFREF NTS = root:Packages:NT:Settings
	
	NVAR viewerOpen = NPC:viewerOpen
	SVAR viewerRecall = NPC:viewerRecall
	NVAR hf = NTS:hf
	
	Variable r = ScreenResolution / 72
	
	//Define guides
//	DefineGuide/W=NTP VT = {FT,0.6315,FB}
//	DefineGuide/W=NTP VB = {FT,0.97,FB}
	DefineGuide/W=NTP VT = {FT,515*hf}
	DefineGuide/W=NTP VB = {FT,790*hf}
		
	//Add an additional 200 pixels to the toolbox on the bottom
	GetWindow NT wsize
	MoveWindow/W=NTP V_left,V_top,V_right,V_bottom + 300*hf/r
	
	//Open the display window only if it wasn't already open
	If(viewerOpen == 0)
		Display/HOST=NT/FG=(FL,VT,FR,VB)/N=Viewer
	EndIf	
	
	//adjust guide for scanListPanel so it doesn't get in the viewer's way
	DefineGuide/W=NTP listboxBottom={FT,0.61,FB}
	
	//Display the window controls
	Button ntViewerAutoScaleButton win=NT,size={50,20},pos={3,793*hf},title="AUTO",proc=ntButtonProc
	Button ntViewerDisplayTracesButton win=NT,size={50,20},pos={60,793*hf},title="DISP",proc=ntButtonProc
	Button ntViewerClearTracesButton win=NT,size={50,20},pos={117,793*hf},title="CLEAR",proc=ntButtonProc
	
	CheckBox ntViewerSeparateVert win=NT,size={50,20},font=$LIGHT,fsize=12,pos={174,795*hf},title="Vert",proc=ntCheckProc
	CheckBox ntViewerSeparateHoriz win=NT,size={50,20},font=$LIGHT,fsize=12,pos={220,795*hf},title="Horiz",proc=ntCheckProc
	
	//Recall previous display
	If(strlen(viewerRecall))
		Execute/Z viewerRecall
	EndIf
	
	viewerOpen = 1
End

//Closes the Trace Viewer window
Function closeViewer()
	DFREF NPC = $CW
	DFREF NTS = root:Packages:NT:Settings
	SVAR viewerRecall = NPC:viewerRecall
	NVAR viewerOpen = NPC:viewerOpen
	NVAR hf = NTS:hf
	
	Variable r = ScreenResolution / 72
	
	viewerRecall = WinRecreation("NTP#Nav#Viewer",0)
	//viewerRecall = ReplaceString("Display/W=(162,200,488,600)/FG=(FL,VT,FR,VB)/HOST=#",viewerRecall,"AppendToGraph/W=NTP#Nav#Viewer")
	
	Variable pos1 = strsearch(viewerRecall,"Display",0)
	Variable pos2 = strsearch(viewerRecall,"#",0)
	String matchStr = viewerRecall[pos1,pos2]
	viewerRecall = ReplaceString(matchStr,viewerRecall,"AppendToGraph/W=NTP#Nav#Viewer")
	
	KillWindow/Z NTP#Nav#Viewer
	//Remove 200 pixels to the toolbox on the bottom
	GetWindow NT wsize
	MoveWindow/W=NTP V_left,V_top,V_right,V_top + 515*hf/r
	
	//adjust guide for scanListPanel so it doesn't get in the viewer's way
	DefineGuide/W=NTP listboxBottom={FB,-10}
	
	viewerOpen = 0
End

Function AppendToViewer(listWave,selWave)
	Wave/T listWave //listwave associated with the clicked listbox
	Wave selWave
	
	DFREF NPC = $CW
	SVAR cdf = NPC:cdf
	
	NVAR areHorizSeparated = NPC:areHorizSeparated
	NVAR areVertSeparated = NPC:areVertSeparated
	
	Variable i,j,type,numTraces

	DoWindow/W=NTP#Nav#Viewer Viewer
	
//	Variable timerRef = StartMSTimer	
	
	//Does the window exist?
	If(V_flag)
		String traceList = TraceNameList("NTP#Nav#Viewer",";",1)
		traceList += ImageNameList("NTP#Nav#Viewer",";")
		
		//Remove all traces
		For(i=ItemsInList(traceList)-1;i>-1;i-=1)
			RemoveFromGraph/Z/W=NTP#Nav#Viewer $StringFromList(i,traceList,";")
			RemoveImage/Z/W=NTP#Nav#Viewer $StringFromList(i,traceList,";")
		EndFor
		
		traceList = ""
		String theTracePath = ""
		
		//Append selected traces
		For(i=0;i<DimSize(selWave,0);i+=1)
			//If selected
			If(selWave[i] > 0)
					//ignore text waves
				If(WaveType($listWave[i][0][1],1) == 2)
					continue 
				ElseIf(stringmatch(listWave[i][0][1],"*WAVE SET*"))
					Variable wsn = str2num(StringByKey("WAVE SET",listWave[i][0][1]," ","-"))
					Wave/T ws = GetWaveSet(listWave,wsn)
					
					For(j=0;j<DimSize(ws,0);j+=1)
						//Prevent duplicates waves from being appended
						If(!stringmatch(traceList,"*" + ws[j][0][1] + "*"))
							If(WaveType($ws[j][0][1],1) == 1)
								AppendToGraph/W=NTP#Nav#Viewer $ws[j][0][1]
								traceList += ws[j][0][1] + ";"
							EndIf
						EndIf
					EndFor
				Else
					//only append numeric waves
					Wave w = $listWave[i][0][1]
					CheckDisplayed/W=NTP#Nav#Viewer w
					
					//Prevent duplicates waves from being appended
					If(WhichListItem(listWave[i][0][1],traceList	) == -1)
						
						If(WaveExists($listWave[i][0][1]))
							If(WaveType($listWave[i][0][1],1) == 1)
								AppendToGraph/W=NTP#Nav#Viewer $listWave[i][0][1]
								traceList += listWave[i][0][1] + ";"
							EndIf
						EndIf
					EndIf
				EndIf
			EndIf	
		EndFor
		
		//if last selected wave has more than a single dimension (image or volume)
		Wave finalWave = $StringFromList(ItemsInList(traceList,";") - 1,traceList,";")
		
		If(WaveDims(finalWave) > 1)
			traceList = TraceNameList("NTP#Nav#Viewer",";",1)
			traceList += ImageNameList("NTP#Nav#Viewer",";")
		
			//Remove all traces
			For(i=ItemsInList(traceList)-1;i>-1;i-=1)
				RemoveFromGraph/Z/W=NTP#Nav#Viewer $StringFromList(i,traceList,";")
				RemoveImage/Z/W=NTP#Nav#Viewer $StringFromList(i,traceList,";")
			EndFor
			
			AppendImage/W=NTP#Nav#Viewer/L/B finalWave
			traceList = ImageNameList("NTP#Nav#Viewer",";")
		EndIf
	EndIf	
	
	If(!strlen(traceList))
		return 0
	EndIf
	
	ModifyGraph/W=NTP#Nav#Viewer zero(left)=3,zeroThick(left)=0.5
	
	//Separation of traces? 
	If(areVertSeparated)
		SeparateTraces("vert")
		Button horizSpread win=NTP#Nav,valueColor=(0,0,0) //sets to standard color
		Button vertSpread win=NTP#Nav,valueColor=(0,0xbbbb,0) //sets to green color
	EndIf
	
	If(areHorizSeparated)
		SeparateTraces("horiz")
		Button vertSpread win=NTP#Nav,valueColor=(0,0,0) //sets to standard color
		Button horizSpread win=NTP#Nav,valueColor=(0,0xbbbb,0) //sets to green color
	EndIf
	
	colorViewerGraph()
	
	addThresholdLine()
	
//	print StopMSTimer(timerRef) / (1e3),"ms"
End

//Expands all horizontal or vertical axes
Function expandAxis(axis)
	String axis
	Variable coord1,coord2
	
	String list = AxisList("NTP#Nav#Viewer")
	list = ListMatch(list,axis + "*",";")
	
	//Find which axis hold the marquee
	Variable i
	For(i=0;i<ItemsInList(list,";");i+=1)
		String ax = StringFromList(i,list,";")
		GetMarquee/W=NTP#Nav#Viewer/Z $ax
		
		If(!V_flag)
			continue
		EndIf
		
		GetAxis/W=NTP#Nav#Viewer/Q $ax
		
		If(V_left > V_min && V_right < V_max)
			break
		EndIf
	EndFor
	
	//adjust the axis range for each axis according to the marquee limits
	For(i=0;i<ItemsInList(list,";");i+=1)
		ax = StringFromList(i,list,";")
		
		If(!cmpstr(axis,"bottom"))
			SetAxis/Z/W=NTP#Nav#Viewer $ax V_left,V_right
		Else
			SetAxis/Z/W=NTP#Nav#Viewer $ax V_top,V_bottom
		EndIf
	EndFor
	
	SetMarquee/W=NTP#Nav#Viewer 0,0,0,0
End

Function expandAxisWheel(axis,steps)
	String axis //horizontal or vertical
	Variable steps //each step will be a 5% change in range
	
	String list = AxisList("NTP#Nav#Viewer")
	list = ListMatch(list,axis + "*",";")
	
	Variable i
	For(i=0;i<ItemsInList(list,";");i+=1)
		String ax = StringFromList(i,list,";")
		
		GetAxis/W=NTP#Nav#Viewer/Q $ax
		Variable range = V_max - V_min
		
		SetAxis/Z/W=NTP#Nav#Viewer $ax V_min + (range * 0.025 * steps),V_max - (range * 0.025 * steps)
	EndFor

End

Function colorViewerGraph()
	DFREF NPC = root:Packages:NeuroToolsPlus:ControlWaves
	NVAR areColored = NPC:areColored
	
	String theTraces = TraceNameList("NTP#Nav#Viewer",";",1)
	Variable i,numTraces = ItemsInList(theTraces,";")
	
	If(!DataFolderExists("root:Packages:NeuroToolsPlus:CustomColors"))
		NewDataFolder root:Packages:NeuroToolsPlus:CustomColors
	EndIf
	
	String whichColor = "Geo" //more pleasant color contrast than Rainbow or Spectrum
	Wave/Z colorTab = root:Packages:NeuroToolsPlus:CustomColors:$whichColor
	If(!WaveExists(colorTab))
		DFREF saveDF = GetDataFolderDFR()
		SetDataFolder root:Packages:NeuroToolsPlus:CustomColors
		ColorTab2Wave $whichColor
		Duplicate/O root:Packages:NeuroToolsPlus:CustomColors:M_colors,root:Packages:NeuroToolsPlus:CustomColors:$whichColor
		Wave colorTab = root:Packages:NeuroToolsPlus:CustomColors:$whichColor
		KillWaves/Z root:Packages:NeuroToolsPlus:CustomColors:M_colors
		SetDataFolder saveDF
	EndIf
	
	//Clip Geo at the red shades so we don't use the whiter part of the color table
	Variable clip = 0.9 //90%
	
	Variable colorDelta = round(clip * DimSize(colorTab,0) / numTraces)
	Variable tableSize = floor(clip * DimSize(colorTab,0))
	
	
	
	For(i=0;i<numTraces;i+=1)
		String traceName = StringFromlist(i,theTraces,";")
		
		Variable index = i * colorDelta
		
		//Repeats the color table from the start if there are too many waves displayed
		Variable overRunTimes = floor(index/tableSize)
	
		index -= tableSize * overRunTimes
		
		If(areColored)
			ModifyGraph/W=NTP#NaV#Viewer rgb($traceName)=(colorTab[index][0],colorTab[index][1],colorTab[index][2])
		Else
			ModifyGraph/W=NTP#NaV#Viewer rgb($traceName)=(0,0,0) //return to black
		EndIf
	EndFor

End


//Adds range line for user to drag around to visually change the start and end values for a function input
//Function variable must have the range line assigned to it in the function code itself
Function addRangeLines()
	DFREF NPC = $CW
	NVAR activeRange = NPC:activeRange
	NVAR rangeLeft = NPC:rangeLeft
	NVAR rangeRight = NPC:rangeRight
		
	If(activeRange)
		SetWindow NTP hook(viewerHook) = viewerHook
		Button addRange win=NTP#Nav,valueColor=(0,0xbbbb,0)
	Else
		DrawAction/W=NTP#NaV#Viewer getgroup=rangeLines,delete
		Button addRange win=NTP#Nav,valueColor=(0,0,0)
		return 0
	EndIf
	
	//Get the range of the x and y axes
	GetAxis/W=NTP#NaV#Viewer/Q bottom
	
	If(V_flag)
		return 0	
	EndIf
	
	Variable xMin,xMax,xRange,xBottom,xTop
	xMin = V_min
	xMax = V_max
	
	rangeLeft = (rangeLeft < xMin) ? xMin : rangeLeft
	rangeRight = (rangeRight > xMax) ? xMax : rangeRight
	
	DrawAction/W=NTP#NaV#Viewer getgroup=rangeLines,delete
	
	SetDrawEnv/W=NTP#NaV#Viewer xcoord=bottom,ycoord=rel,linethick=1,fillfgc=(0,0,0,0x1000),linefgc=(0,0,0,0x4000)
	SetDrawEnv/W=NTP#NaV#Viewer gstart,gname=rangeLines
	DrawRect/W=NTP#NaV#Viewer rangeLeft,0,rangeRight,1
	SetDrawEnv/W=NTP#NaV#Viewer gstop
	DoUpdate/W=NTP#NaV#Viewer
End

//Adds threshold line for user to drag around to visually change the threshold value for a function input
//Function variable must have the threshold line assigned to it in the function code itself
Function addThresholdLine()
	DFREF NPC = $CW
	NVAR threshold = NPC:threshold
	
	NVAR activeThreshold = NPC:activeThreshold
	
	//Set window hook for moving threshold bar
	If(activeThreshold)
		SetWindow NTP hook(viewerHook) = viewerHook
		Button addThreshold win=NTP#Nav,valueColor=(0,0xbbbb,0)
	Else
		DrawAction/W=NTP#NaV#Viewer getgroup=threshold,delete
//		SetWindow NTP hook(viewerHook) = $""
		Button addThreshold win=NTP#Nav,valueColor=(0,0,0)
		return 0
	EndIf
	
	//Get the range of the x and y axes
	GetAxis/W=NTP#NaV#Viewer/Q left
	
	If(V_flag)
		return 0	
	EndIf
	
	Variable yMin,yMax,yRange,yBottom,yTop
	yMin = V_min
	yMax = V_max
	
	threshold = (threshold < yMin) ? yMin : threshold
	threshold = (threshold > yMax) ? yMax : threshold
	
	DrawAction/W=NTP#NaV#Viewer getgroup=threshold,delete
	
	SetDrawEnv/W=NTP#NaV#Viewer xcoord=rel,ycoord=left,linethick=1,linefgc=(0,0,0,0x4000)
	SetDrawEnv/W=NTP#NaV#Viewer gstart,gname=threshold
	DrawLine/W=NTP#NaV#Viewer 0,threshold,1,threshold
	SetDrawEnv/W=NTP#NaV#Viewer gstop
	DoUpdate/W=NTP#NaV#Viewer
End

//Duplicates the Viewer graph outside of the viewer
Function displayViewerGraph()
	String theTraces = TraceNameList("NTP#Nav#Viewer",";",1)
		
	String winRec = WinRecreation("NTP#Nav#Viewer",0)
	
	Variable pos1 = strsearch(winRec,"/W",0)
	Variable pos2 = strsearch(winRec,"/HOST",0) - 1
	
	String matchStr = winRec[pos1,pos2]
	winRec = ReplaceString(matchStr,winRec,"/K=1/W=(" + num2str(10) + "," + num2str(10) + "," + num2str(360) + "," + num2str(200) + ")")
	winRec = ReplaceString("/HOST=#",winRec,"")
	Execute/Q/Z winRec
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
	DFREF NPC = $CW
	
	NVAR areHorizSeparated = NPC:areHorizSeparated
	NVAR areVertSeparated = NPC:areVertSeparated

	String traceList = TraceNameList("NTP#Nav#Viewer",";",1)
	String theTrace,prevTrace
	Variable numTraces,i,traceMax,traceMin,traceMinPrev,traceMaxPrev,offset
	offset = 0
	
	numTraces = ItemsInList(traceList,";")
	
	Variable separateAxis = 1
	
	strswitch(orientation)
		case "vert":
			If(!areVertSeparated)
				For(i=1;i<numTraces;i+=1)
					theTrace = StringFromList(i,traceList,";")
					offset = 0
					ModifyGraph/W=NTP#Nav#Viewer offset($theTrace)={0,offset}
				EndFor	
			Else
				For(i=1;i<numTraces;i+=1)
					theTrace = StringFromList(i,traceList,";")
					Wave theTraceWave = TraceNameToWaveRef("NTP#Nav#Viewer",theTrace)
					traceMin = WaveMin(theTraceWave)
					traceMax = WaveMax(theTraceWave)
					Wave prevTraceWave = TraceNameToWaveRef("NTP#Nav#Viewer",StringFromList(i-1,traceList,";"))
					traceMinPrev = WaveMin(prevTraceWave)
					traceMaxPrev = WaveMax(prevTraceWave)
					offset -= abs(traceMax - traceMinPrev)
					
					String axisName = "left_" + num2str(i)
					
					ModifyGraph/W=NTP#Nav#Viewer offset($theTrace)={0,offset}
					
				EndFor
								
			EndIf
			
			break
		case "horiz":
			If(!areHorizSeparated)
//				For(i=0;i<numTraces;i+=1)
//					theTrace = StringFromList(i,traceList,";")
//					offset = 0
//					changeAxis(theTrace,"NTP#Nav#Viewer","bottom","hor")
//					ModifyGraph/W=NTP#Nav#Viewer offset($theTrace)={offset,0},zero(left)=3,zeroThick(left)=0.5
//				EndFor
				
				For(i=numTraces - 1;i > -1;i-=1)
					theTrace = StringFromList(i,traceList,";")
					offset = 0
					changeAxis(theTrace,"NTP#Nav#Viewer","bottom","hor")
					ModifyGraph/W=NTP#Nav#Viewer offset($theTrace)={offset,0},zero(left)=3,zeroThick(left)=0.5
				EndFor		
			Else
				For(i=1;i<numTraces;i+=1)
					theTrace = StringFromList(i,traceList,";")
					Wave theTraceWave = TraceNameToWaveRef("NTP#Nav#Viewer",theTrace)
					traceMin = DimOffset(theTraceWave,0)
					traceMax = IndexToScale(theTraceWave,DimSize(theTraceWave,0)-1,0)
					Wave prevTraceWave = TraceNameToWaveRef("NTP#Nav#Viewer",StringFromList(i-1,traceList,";"))
					traceMinPrev = DimOffset(prevTraceWave,0)
					traceMaxPrev = IndexToScale(prevTraceWave,DimSize(prevTraceWave,0)-1,0)
//					offset += abs(traceMinPrev+traceMax)
					ModifyGraph/W=NTP#Nav#Viewer zero(left)=3,zeroThick(left)=0.5
				EndFor
				
				If(separateAxis)
//					For(i=0;i<numTraces;i+=1)
//						theTrace = StringFromList(i,traceList,";")
//						axisName = "bottom_" + num2str(i)
//						changeAxis(theTrace,"NTP#Nav#Viewer",axisName,"hor")
//						ModifyGraph/W=NTP#Nav#Viewer axisEnab($axisName)={(i)/numTraces,(i+1)/numTraces},zero(left)=3,zeroThick(left)=0.5,freePos($axisName)=0,lblPosMode($axisName)=1
//					EndFor
					
					
					For(i=numTraces - 1;i > -1;i-=1)
						theTrace = StringFromList(i,traceList,";")
						axisName = "bottom_" + num2str(i)
						changeAxis(theTrace,"NTP#Nav#Viewer",axisName,"hor")
						ModifyGraph/W=NTP#Nav#Viewer axisEnab($axisName)={(i)/numTraces,(i+1)/numTraces},zero(left)=3,zeroThick(left)=0.5,freePos($axisName)=0,lblPosMode($axisName)=1
					EndFor
				EndIf
				
			EndIf
			break
	endswitch
End

//Clears all the traces from the Viewer window
Function clearTraces()
	String traceList = TraceNameList("NTP#Nav#Viewer",";",1)
	Variable numTraces = ItemsInList(traceList,";")
	Variable i
	
	For(i=numTraces - 1;i>-1;i-=1)
		String theTrace = StringFromList(i,traceList,";")
		RemoveFromGraph/W=NTP#Nav#Viewer $theTrace
	EndFor	
	
	String imageList = ImageNameList("NTP#Nav#Viewer",";")
	numTraces = ItemsInList(imageList,";")
	For(i=numTraces - 1;i>-1;i-=1)
		theTrace = StringFromList(i,imageList,";")
		RemoveImage/Z/W=NTP#Nav#Viewer $theTrace
	EndFor
End

//Adds the output wave from a function to the data set structure
//This is used to create an output data set after a function runs
Function AddOutput(outWave,ds)
	Wave outWave
	STRUCT ds &ds
	
	Variable size = DimSize(ds.output,0)
	Redimension/N=(size + 1) ds.output
	
	ds.output[size] = outWave
End

//Saves the ds structure for later recall by an external function
Function SaveStruct(ds)
	STRUCT ds &ds
	STRUCT ds_numOnly dsNums
//	STRUCT ds_progress_numOnly progress
	
	DFREF NPD = $DSF
	
//	ds.numWaveSets= ds.num
	dsNums.wsi = ds.wsi
	dsNums.wsn = ds.wsn
	dsNums.numDataSets = ds.numDataSets
//	ds.numWaves = ds.numWaves
	
//	progress.value = ds.progress.value
//	progress.count = ds.progress.count
//	progress.steps = ds.progress.steps
//	progress.increment = ds.progress.increment
//	
	//numeric data gets saved
	Make/O NPD:ds//,NPD:progress
	
	StructPut dsNums,NPD:ds
//	StructPut progress,NPD:progress
	
	//waves and strings get saved
	DFREF NPC = $CW
		
	Make/O/N=7/T NPC:ds_refs
	Wave/T ds_refs = NPC:ds_refs
	ds_refs[0] = GetWavesDataFolder(ds.listWave,2) //listwave
	ds_refs[1] =  "root:Packages:NeuroToolsPlus:DataSets:DataSetNames" //data set names
	ds_refs[2] =  "root:Packages:NeuroToolsPlus:DataSets:DataSetWavePaths" //paths
	ds_refs[3] =  GetWavesDataFolder(ds.waves,2) //name
//	ds_refs[4] = "root:Packages:NeuroToolsPlus:DataSets:progressVal" //progress bar value
//	ds_refs[5] = "root:Packages:NeuroToolsPlus:DataSets:progressCount" //progress bar count
//	ds_refs[6] = "root:Packages:NeuroToolsPlus:DataSets:numDataSetWaves"//num waves per data set
//	ds_refs[7] = "root:Packages:NeuroToolsPlus:DataSets:NumWaveSets" //num wave sets per data set
	
	ds_refs[4] = "root:Packages:NeuroToolsPlus:DataSets:numDataSetWaves"//num waves per data set
	ds_refs[5] = "root:Packages:NeuroToolsPlus:DataSets:NumWaveSets" //num wave sets per data set
	ds_refs[6] = "root:Packages:NeuroToolsPlus:DataSets:outputWaves" //any output waves that the functions have generated
End

//fills out the ds structure with the save data
Function GetStruct(ds[,waves])
	STRUCT ds &ds
	String waves //optional if a function is being called outside of the NTP GUI from another function
				    //uses a string list of waves instead of a data set definition to run.
	
	STRUCT ds_numOnly dsNums
//	STRUCT ds_progress_numOnly progress
	
	DFREF NPC = $CW
	DFREF NPD = $DSF
	
	Wave/T ds_refs = NPC:ds_refs
	
	//fills numeric data
	StructGet dsNums,NPD:ds
//	StructGet progress,NPD:progress
	
//	ds.numWaveSets= ds.num
	ds.wsi = dsNums.wsi
	ds.wsn = dsNums.wsn
	ds.numDataSets = dsNums.numDataSets
//	ds.numWaves = ds.numWaves
	
//	ds.progress.value = progress.value
//	ds.progress.count = progress.count
//	ds.progress.steps = progress.steps
//	ds.progress.increment = progress.increment
	
	
	Wave/T ds.listWave = $ds_refs[0]
	Wave/T ds.name = $ds_refs[1]
	Wave/T ds.paths = $ds_refs[2]
	Wave/WAVE ds.waves = $ds_refs[3]
	Wave ds.numWaves = $ds_refs[4]
	Wave ds.numWaveSets= $ds_refs[5]
	Wave/WAVE ds.output = $ds_refs[6]
	
	If(!ParamIsDefault(waves) && ItemsInList(waves,";") > 0)		
		Variable i,numWaveRefs = ItemsInList(waves,";")
		Redimension/N=(numWaveRefs) ds.waves,ds.paths
		
		For(i=0;i<numWaveRefs;i+=1)
			ds.waves[i] = $StringFromList(i,waves,";")
			ds.paths[i] = StringFromList(i,waves,";")
		EndFor
		
		ds.numWaves = numWaveRefs
		ds.numWaveSets = 1
	EndIf
	
//	NVAR ds.progress.value = $ds_refs[4]
//	NVAR ds.progress.count = $ds_refs[5]
//	Wave ds.numWaves = $ds_refs[6]
//	Wave ds.numWaveSets= $ds_refs[7]

End

//Runs the selected external function (user provided)
Function RunExternalFunction(cmd)
	String cmd

	cmd = getExtFuncCmdStr(cmd)
	Execute/Q/Z cmd
	
	return 1
End

//Saves a wave reference variable of an input wave so that it can be recalled later.
//Userful for external functions that output values according to wave set number as opposed
//to wave set index
Function saveWaveRef(theWave)
	Wave theWave
	
	Make/O/N=1/WAVE root:Packages:NeuroToolsPlus:savedRefs
	Wave/Wave savedRefs = root:Packages:NeuroToolsPlus:savedRefs
	savedRefs[0] = theWave
End

//Pairs with saveWaveRef to recall that reference
Function/WAVE recallSavedWaveRef()
	Wave/Wave/Z savedRefs = root:Packages:NeuroToolsPlus:savedRefs
	
	If(!WaveExists(savedRefs))
		Abort "Must save a wave reference before recalling one"
	EndIf
	
	return savedRefs[0]
End

//Switches the title of the function list in the 'External Functions' command window
Function SwitchExternalFunction(cmd)
	String cmd
	
	//Calculates spacer to ensure centered text on the drop down menu
	String spacer = ""
	Variable cmdLen = strlen(cmd)
	cmdLen = 25 - cmdLen
	
	Do
		spacer += " "
		cmdLen -= 1
	While(cmdLen > 0)
	
	//previous selection
	KillExtParams()
	
	//switches text in the drop down menu
	Button functionPopUp win=NTP#Func,font=$LIGHT,pos={35,40},size={185,20},fsize=12,proc=ntButtonProc,title="\\JL▼   " + spacer + cmd,disable=0
	
	//switches controls
	BuildExtFuncControls(cmd)
	
End

//Returns the list of external functions
Function/S GetExternalFunctions()
	String theFileList,theFile,theList="",masterList=""
	Variable i
	
	//these files are the ones searched for NT_ based functions for inclusion in the function menu
	theFileList = "NTP_Functions.ipf;"
	
	For(i=0;i<ItemsInList(theFileList,";");i+=1)
		theFile = StringFromList(i,theFileList,";")
		theList = FunctionList("NT_*", ";","WIN:" + theFile)
		theList = ReplaceString("NT_",theList,"") //remove NT_ prefixes for the menu
		masterList += theList
	EndFor
	
	//Get user installed package functions
	String userFunctionPath = SpecialDirPath("Igor Pro User Files",0,0,0)	
	userFunctionPath += "User Procedures:NeuroTools+:Functions"
	
	GetFileFolderInfo/Q/Z userFunctionPath

	If(V_isFolder)
		NewPath/O/Q userPath,userFunctionPath
		String userFileList = IndexedFile(userPath,-1,".ipf")
		
		For(i=0;i<ItemsInList(userFileList,";");i+=1)
			theFile = StringFromList(i,userFileList,";")
			
			String userFunctionList = FunctionList("NT_*", ";","WIN:" + theFile)
			userFunctionList = ReplaceString("NT_",userFunctionList,"") //remove NT_ prefixes for the menu
			masterList += userFunctionList
		EndFor
		
		//Find any package folders within the Functions folder
		String UserPackageFolders = IndexedDir(userPath,-1,1)
		Variable numUserPackages = ItemsInList(UserPackageFolders,";")
		If(numUserPackages > 0)
			For(i=0;i<numUserPackages;i+=1)
				String userFolder = StringFromList(i,UserPackageFolders,";")
		
				NewPath/O/Q userPath,userFolder
				
				userFileList = IndexedFile(userPath,-1,".ipf")
				
				Variable j
				For(j=0;j<ItemsInList(userFileList,";");j+=1)
					theFile = StringFromList(j,userFileList,";")
					userFunctionList = FunctionList("NT_*", ";","WIN:" + theFile)
					userFunctionList = ReplaceString("NT_",userFunctionList,"") //remove NT_ prefixes for the menu
					masterList += userFunctionList
				EndFor
			EndFor
		EndIf
	EndIf
	
	return masterList
End


//returns the current selection of the 'MeasureType' drop down menu
Function/S CurrentMeasureType()
	ControlInfo/W=NTP measureType
	String func = TrimString(StringFromList(1,S_Title,"\u005cJL▼"))
	return func
End

//returns the current selection of the 'Commands' drop down menu
Function/S CurrentCommand()
	DoWindow NT
	If(!V_flag)
		return ""
	EndIf
	
	ControlInfo/W=NTP#Func CommandMenu
	String func = TrimString(StringFromList(1,S_Title,"\u005cJL▼"))
	return func
End

//returns the current selection of the external functions drop down menu
Function/S CurrentExtFunc()
	ControlInfo/W=NTP#Func functionPopUp
	String title = TrimString(StringFromList(1,S_Title,"\u005cJL▼"))
	String func = GetFunctionFromTitle(title)
//	func = StringsFromList("1-*",func,"_",noEnding=1)
	
	return func
End

//returns the parameter number for the provided control name for an external function
Function ExtFuncParamIndex(ctrlName)
	String ctrlName
	
	ctrlName = ReplaceString("param",ctrlName,"")
	Variable index = str2num(ctrlName)
	
	If(!numtype(index))
		return index
	EndIf
	
	Do
		Variable len = strlen(ctrlName)
		
		If(len == 0)
			break
		EndIf
		
		String c = ctrlName[0]
		
		//test for numeric
		Variable n = str2num(c)
		
		If(numtype(n) == 2) //nan 
			ctrlName = ctrlName[1,len-1]
		Else
			index = str2num(ctrlName)
			If(!numtype(index))
				return index
			EndIf
		EndIf
	While(1)
End

//Initializes the external functions module, and fills out a text wave with the data for each 
//main function in NT_ExternalFunctions.ipf'
Function/Wave GetExternalFunctionData(param)
	Wave/T param
	Variable i,j,k,m
	
	//Make a copy of the parameters table if it hasn't already been done
	DFREF NPC = $CW
	Wave/Z/T copy = NPC:ExtFunc_Parameters_copy
	If(WaveExists(copy))		
		//Copy all currently available functions into the copy table
		//This may be a shorter list if package manager has been used
		Redimension/N=(DimSize(param,0),-1) copy //param may have changed row length
		CopyDimLabels/ROWS=0 param,copy
		
		For(i=0;i<DimSize(param,1);i+=1)
			String pFn = GetDimLabel(param,1,i)
			
			If(!strlen(pFn))
				continue
			EndIf
			
			Variable col = FindDimLabel(copy,1,pfN)
			
			If(col == -2)
				InsertPoints/M=1 i,1,copy
				SetDimLabel 1,i,$pfn,copy
				i += 1
				continue
			EndIf
			
			copy[][%$pFn] = param[p][%$pFn]
		EndFor
	Else
		Wave/T copy = param
	EndIf
	
	//function list
	String funcs = GetExternalFunctions()
	
	Redimension/N=(-1,ItemsInList(funcs,";")) param
	
	//Will keep track if there are empty variables in the text wave across all functions
	Variable isEmpty = 0
	Variable emptySlots = 100
	
	//Keeps track of pop up menus, buttons, and listboxes
	Variable isPopMenu = 0
	String ctxPopUpStr = ""
	String popUpStr = ""
	String buttonStr = ""
	String listBoxStr = ""
	String funcRefStr = ""
	
	//function data
	For(i=0;i<ItemsInList(funcs,";");i+=1)
		String theFunction = StringFromList(i,funcs,";")
		
		//Dimension label for the function that we will use to index specific columns in the table
		String fnLabel = "NT_" + theFunction
		
		//Check if this is a new function for the copy table		
		col = FindDimLabel(copy,1,fnLabel)
		
		//Insert a new column for that function if it's new
		If(col == -2)
			InsertPoints/M=1 i,1,copy
			SetDimLabel 1,i,$fnLabel,copy
		EndIf
		
		//Function info
		String info = FunctionInfo(fnLabel)
		
		//Gets the actual code for the beginning of the function to extract parameter names
		String fullFunctionStr = ProcedureText(fnLabel,0)
		Variable pos = strsearch(fullFunctionStr,")",0)
		String functionStr = fullFunctionStr[0,pos]
		functionStr = RemoveEnding(StringFromList(1,functionStr,"("),")")
		
		//Determine if there is a submenu definition
		String subMenuStr = NT_GetFlagString("SUBMENU",fullFunctionStr)
		
		//Determine if there is a submenu grouping
		String subGroupStr = NT_GetFlagString("SUBGROUP",fullFunctionStr)
		
		//Determine if there is a title string
		String titleStr = NT_GetFlagString("TITLE",fullFunctionStr)
		If(!strlen(titleStr))
			titleStr = theFunction
		EndIf
		
		//Resize according to the parameter number
		Variable numParams = str2num(StringByKey("N_PARAMS",info,":",";"))
		If(numtype(numParams) == 2)
			numParams = 0
		EndIf
		
		//Backwards compatability with the control title parameter, which is a 2022 new addition.
		k = FindDimLabel(copy,0,"PARAM_0_TITLE")
		If(k == -2)
			k = DimSize(copy,0) - 1 //cycle backwards through the wave
			Do
				//Find all instances of the Name parameter, and insert a row for the title parameter
				String dimLabel = GetDimLabel(copy,0,k)
				If(stringmatch(dimLabel,"PARAM_*_NAME"))
					//Insert new dimension label for the TITLE parameter
					InsertPoints/M=0 k+1,1,param
					
					String dimLabelNew = ReplaceString("NAME",dimLabel,"TITLE")
					SetDimLabel 0,k+1,$dimLabelNew,param	
					
					//Duplicate the name and title parameters for each function on first initialization
					param[%$dimLabelNew][] = copy[%$dimLabel][q]
					
					//Remove the control prefixes
					param[%$dimLabelNew][] = ReplaceString("ctxmenu_",copy[%$dimLabelNew][q],"")
					param[%$dimLabelNew][] = ReplaceString("menu_",copy[%$dimLabelNew][q],"")
					param[%$dimLabelNew][] = ReplaceString("bt_",copy[%$dimLabelNew][q],"")
					param[%$dimLabelNew][] = ReplaceString("cb_",copy[%$dimLabelNew][q],"")
					param[%$dimLabelNew][] = ReplaceString("lb_",copy[%$dimLabelNew][q],"")
					param[%$dimLabelNew][] = ReplaceString("DS_",copy[%$dimLabelNew][q],"")
					param[%$dimLabelNew][] = ReplaceString("fn_",copy[%$dimLabelNew][q],"")
				EndIf
				
				k -= 1
			While(k > -1)
		EndIf

		String keys = "NAME;TITLE;TYPE;THREADSAFE;RETURNTYPE;N_PARAMS;N_OPT_PARAMS;SUBMENU;SUBGROUP;"
		Variable nKeys = ItemsInList(keys,";")
		String descriptorList = "TYPE;NAME;TITLE;ITEMS;PROC;VALUE;LISTWAVE;SELWAVE;DIMLABELS;COORDS;ASSIGN;ARGS;"
		Variable nDescriptors = ItemsInList(descriptorList,";")
		
		For(j=0;j<numParams;j+=1)
			For(m=0;m<nDescriptors;m+=1)
				keys += "PARAM_" + num2str(j) + "_" + StringFromList(m,descriptorList,";") + ";"
			EndFor
		EndFor
		
		If(nKeys + numParams * nDescriptors > DimSize(copy,0))
			Redimension/N=(nKeys + numParams * nDescriptors,-1) param
		EndIf

		//Label the dimension for each function column
		SetDimLabel 1,i,$fnLabel,param
		
		Variable whichParam = 0
		For(j=0;j < nKeys + numParams * nDescriptors;j+=1)
			String theKey = StringFromList(j,keys,";")
			
			//base name for the parameter, not including the suffix indicating TYPE,NAME,ITEMS,PROC,etc.
			//Allows me to use dimension labels to identify rows
			If(stringmatch(theKey,"*PARAM_*_*"))
				String paramBase = StringsFromList("0-1",theKey,"_")
			Else
				paramBase = ""
			EndIf
					
			//Label the dimension
			SetDimLabel 0,j,$theKey,param
			SetDimLabel 1,i,$("NT_" + theFunction),param
			
			//Add the function data to the wave
		
			If(stringmatch(theKey,"*PARAM*NAME*"))
				String paramLabel = paramBase + "NAME"
				String ctrlName = StringFromList(whichParam,functionStr,",")
				param[%$paramLabel][%$fnLabel] = ctrlName
				whichParam += 1
				
				Variable isContextual  = 0
				
				//Is it a pop up menu or contextual pop up menu
				If(stringmatch(copy[%$paramLabel][%$fnLabel],"menu_*"))
					popUpStr = copy[%$paramLabel][%$fnLabel]
					isContextual = 0
				ElseIf(stringmatch(copy[%$paramLabel][%$fnLabel],"ctxmenu_*"))
					popUpStr = copy[%$paramLabel][%$fnLabel]
					isContextual = 1
				Else
					popUpStr = ""
					isContextual = 0
				EndIf 
				
				//Is it a button
				If(stringmatch(copy[%$paramLabel][%$fnLabel],"bt_*"))
					buttonStr = copy[%$paramLabel][%$fnLabel]
				Else
					buttonStr = ""
				EndIf 
				
				//Is it a list box
				If(stringmatch(copy[%$paramLabel][%$fnLabel],"lb_*"))
					listBoxStr = copy[%$paramLabel][%$fnLabel]
				Else
					listBoxStr = ""
				EndIf
				
				//Is it a function reference
				If(stringmatch(copy[%$paramLabel][%$fnLabel],"fn_*"))
					funcRefStr = copy[%$paramLabel][%$fnLabel]
				Else
					funcRefStr = ""
				EndIf

			ElseIf(stringmatch(theKey,"*PARAM*TITLE*"))
				paramLabel = paramBase + "TITLE"				
				//Extract any control title information from the code
				String ctrlTitleStr = NT_GetControlFlag(ctrlName,fullFunctionStr,"Title")
				
				If(!strlen(ctrlTitleStr))
					//If no title is specified, inherit the ctrl name as the title, minus the controller type prefix
					
					param[%$paramLabel][%$fnLabel] = ReplaceString("ctxmenu_",ctrlName,"")
					param[%$paramLabel][%$fnLabel] = ReplaceString("menu_",param[%$paramLabel][%$fnLabel],"")
					param[%$paramLabel][%$fnLabel] = ReplaceString("bt_",param[%$paramLabel][%$fnLabel],"")
					param[%$paramLabel][%$fnLabel] = ReplaceString("cb_",param[%$paramLabel][%$fnLabel],"")
					param[%$paramLabel][%$fnLabel] = ReplaceString("fn_",param[%$paramLabel][%$fnLabel],"")
					param[%$paramLabel][%$fnLabel] = ReplaceString("lb_",param[%$paramLabel][%$fnLabel],"")
					param[%$paramLabel][%$fnLabel] = ReplaceString("DS_",param[%$paramLabel][%$fnLabel],"")
				Else
					param[%$paramLabel][%$fnLabel] =	 ctrlTitleStr			
				EndIf
				
			ElseIf(stringmatch(theKey,"*PARAM*ITEMS*"))
				paramLabel = paramBase + "ITEMS"

				If(strlen(popUpStr))
					param[%$paramLabel][%$fnLabel] = NT_GetPopUpValue(popUpStr,fullFunctionStr)
					
					//	//Are the items a literal string expression or a function call?
					If(stringmatch(copy[%$paramLabel][%$fnLabel],"*(*") && stringmatch(copy[%$paramLabel][%$fnLabel],"*)*"))
						Variable isFunctionCall = 1
					Else
						isFunctionCall = 0
					EndIf
					
				ElseIf(strlen(funcRefStr))
					param[%$paramLabel][%$fnLabel] = funcs
				Else
					param[%$paramLabel][%$fnLabel] = ""
				EndIf
				
			ElseIf(stringmatch(theKey,"*PARAM*VALUE*"))
				
				paramLabel = paramBase + "VALUE"
				If(strlen(popUpStr))	
					//Extract the first entry to the actual control
					If(!strlen(copy[%$paramLabel][%$fnLabel]) || ItemsInList(copy[%$paramLabel][%$fnLabel],";") > 1 && !isContextual)
						If(isFunctionCall)
							param[%$paramLabel][%$fnLabel] = ""
						Else
							param[%$paramLabel][%$fnLabel] = StringFromList(0,copy[%$(paramBase + "ITEMS")][%$fnLabel],";")
						EndIf
					Else
						//Goes here if the menu is contextual and there is either a blank or single entry in the Value row.
						If(strlen(copy[%$paramLabel][%$fnLabel]))
							param[%$paramLabel][%$fnLabel] = copy[%$paramLabel][%$fnLabel]
						Else
							param[%$paramLabel][%$fnLabel] = ""
						EndIf
					EndIf
					
					isContextual = 0
					popUpStr = "" //reset
					
				ElseIf(strlen(funcRefStr))
					If(!strlen(copy[%$paramLabel][%$fnLabel]) || ItemsInList(copy[%$paramLabel][%$fnLabel],";") > 1)
						param[%$paramLabel][%$fnLabel] = StringFromList(0,copy[%$(paramBase + "ITEMS")][%$fnLabel],";")
					EndIf
					
					funcRefStr = "" //reset
				
				Else
					If(!strlen(buttonStr)) //set all parameter variables that aren't buttons to zero by default
						String varType = copy[%$("PARAM_" + num2str(whichParam-1) + "_TYPE")][%$fnLabel]
						
						//Set empty values to 0
						If(!strlen(copy[%$paramLabel][%$fnLabel]) && str2num(varType) == 4)
							param[%$paramLabel][%$fnLabel] = "0"
						Else
							//otherwise leave them be, copy them over
							param[%$paramLabel][%$fnLabel] = copy[%$paramLabel][%$fnLabel]
						EndIf
						
						//set non-numeric or NaN values to 0
						If(numtype(str2num(copy[%$paramLabel][%$fnLabel])) == 2 && str2num(varType) == 4)
							param[%$paramLabel][%$fnLabel] = "0"
						EndIf
						
					EndIf
				EndIf
				
			ElseIf(stringmatch(theKey,"*PARAM*PROC*"))
				paramLabel = paramBase + "PROC"
				If(strlen(popUpStr))	
					param[%$paramLabel][%$fnLabel] = NT_GetSpecialProc(popUpStr,fullFunctionStr)
				ElseIf(strlen(buttonStr))	
					param[%$paramLabel][%$fnLabel] = NT_GetSpecialProc(buttonStr,fullFunctionStr)
				ElseIf(strlen(listBoxStr))	
					param[%$paramLabel][%$fnLabel] = NT_GetSpecialProc(listBoxStr,fullFunctionStr)
				Else
					param[%$paramLabel][%$fnLabel] = NT_GetSpecialProc(ctrlName,fullFunctionStr)
				EndIf
				
			ElseIf(stringmatch(theKey,"SUBMENU"))
				param[%SUBMENU][%$fnLabel] = subMenuStr
			ElseIf(stringmatch(theKey,"SUBGROUP"))
				param[%SUBGROUP][%$fnLabel] = subGroupStr
			ElseIf(stringmatch(theKey,"TITLE"))
				param[%TITLE][%$fnLabel] = titleStr
				
			ElseIf(stringmatch(theKey,"*PARAM*LISTWAVE*"))
				paramLabel = paramBase + "LISTWAVE"
				If(strlen(listBoxStr))
					param[%$paramLabel][%$fnLabel] = NT_GetListBoxWaves(listBoxStr,"ListWave",fullFunctionStr)
				Else
					param[%$paramLabel][%$fnLabel] = ""
				EndIf
				
			ElseIf(stringmatch(theKey,"*PARAM*SELWAVE*"))
				paramLabel = paramBase + "SELWAVE"
				If(strlen(listBoxStr))
					param[%$paramLabel][%$fnLabel] = NT_GetListBoxWaves(listBoxStr,"SelWave",fullFunctionStr)
				Else
					param[%$paramLabel][%$fnLabel] = ""
				EndIf
			ElseIf(stringmatch(theKey,"*PARAM*DIMLABELS*"))
				paramLabel = paramBase + "DIMLABELS"
				If(strlen(listBoxStr))
					param[%$paramLabel][%$fnLabel] = NT_GetControlFlag(ctrlName,fullFunctionStr,"DimLabels")
				Else
					param[%$paramLabel][%$fnLabel] = ""
				EndIf
			ElseIf(stringmatch(theKey,"*PARAM*COORDS*"))
				paramLabel = paramBase + "COORDS"
				param[%$paramLabel][%$fnLabel] = NT_GetControlFlag(ctrlName,fullFunctionStr,"Pos")

			ElseIf(stringmatch(theKey,"*PARAM*ASSIGN*"))
				paramLabel = paramBase + "ASSIGN"
				param[%$paramLabel][%$fnLabel] = NT_GetControlFlag(ctrlName,fullFunctionStr,"Assign")
				
			ElseIf(stringmatch(theKey,"*PARAM*ARGS*"))
				paramLabel = paramBase + "ARGS"
				param[%$paramLabel][%$fnLabel] = ""
				//do nothing
			Else
				param[%$theKey][%$fnLabel] = StringByKey(theKey,info,":",";")
			EndIf	
		EndFor
		
		Variable diff = DimSize(param,0) - (nKeys + numParams * nDescriptors)
		If(diff)
			param[nKeys + numParams * nDescriptors,DimSize(param,0)-1][%$fnLabel] = ""
		EndIf
		
		If(diff < emptySlots)
			emptySlots = diff
		EndIf
	EndFor

	
	Redimension/N=(DimSize(param,0) - emptySlots,-1) param
	
	//if the param table copy exists, it needs to incorporate any new changes
	Wave/Z/T copy = NPC:ExtFunc_Parameters_copy
	If(WaveExists(copy))
		Redimension/N=(DimSize(param,0),DimSize(param,1)) copy
		copy = param
		CopyDimLabels param,copy
	EndIf
	
	//Update visible packages
	SVAR HideUserPackages = NPC:HideUserPackages
	If(SVAR_Exists(HideUserPackages))
		UpdatePackages(HideUserPackages)
	EndIf
	
	return param
End

//Returns the actual function name for a given function title
Function/S GetFunctionFromTitle(title)
	String title
	DFREF NPC = $CW
	DFREF NPD = $DSF
	String func = ""
	
	Wave/T param = NPC:ExtFunc_Parameters
	Make/T/FREE/N=(2,DimSize(param,1)) paramTitleRow
	paramTitleRow[0] = param[%NAME][q]
	paramTitleRow[1] = param[%TITLE][q]
//	
	//find the column that contains that title
	Variable col = tableMatch(title,paramTitleRow,returnCol=1)
	Variable row = FindDimLabel(param,0,"NAME")
	
	If(col < 0 || row < 0)
		return ""
	EndIf
	
	func = param[row][col]
	
	return func
End

//Builds the parameters for the selected external function
Function BuildExtFuncControls(theFunction)
	String theFunction
	DFREF NPC = $CW
	DFREF NPD = $DSF
	
	//theFunction is just the title of the function, we need the actual function command name
	theFunction = GetFunctionFromTitle(theFunction)
	
	//In case we've added a new function after compiling initially, this will find it.
//	Wave/T param = GetExternalFunctionData(NPC:ExtFunc_Parameters)
	Wave/T param = NPC:ExtFunc_Parameters
	
	String info = FunctionInfo(theFunction)

	Variable i,pos
	
	Variable numParams,numOptParams
	numParams = str2num(getParam("N_PARAMS",theFunction))
	numOptParams = str2num(getParam("N_OPT_PARAMS",theFunction))
		
	//Kill existing controls
	KillExtParams()
	//Function has no extra parameters declared
//	If(numParams == 0 && numOptParams == 0)
//		
//		return 1
//	EndIf
	
	String paramType,functionStr
	paramType = ""

	//gets the type for each input parameter
	SVAR isOptional = NPC:isOptional
	isOptional = ""
	
	//Gets the names of each inputs in the selected function
	functionStr = ProcedureText(theFunction,0)
	
	//Get the optional function note to display
	String functionNote = GetFunctionNote(functionStr)
	
	pos = strsearch(functionStr,")",0)
	functionStr = functionStr[0,pos]
	functionStr = RemoveEnding(StringFromList(1,functionStr,"("),")")
	
	String extParamNames = functionStr
	
	Variable left=60,top=70 //top left starting position of the controls
	
	Variable fontSize = 12
	String type,name,ctrlName,items,title
	
	String menuProcEngageList = ""
	
	For(i=0;i<numParams;i+=1)
		String paramBase = "PARAM_" + num2str(i) + "_"
	
		name = param[%$paramBase + "NAME"][%$theFunction]
		ctrlName = "param" + num2str(i)
		type = param[%$paramBase + "TYPE"][%$theFunction]
		items = param[%$paramBase + "ITEMS"][%$theFunction]
		title = param[%$paramBase + "TITLE"][%$theFunction]
		
		If(stringmatch(name,"*[*]*")) //is it an optional parameter?
			continue
		EndIf
		
		//Check if the control is a pop up menu or button or not
		Variable isMenu = 0
		Variable isContextualMenu =  0
		Variable isButton = 0
		Variable isListBox = 0
		Variable isFuncRef = 0
		
		If(stringmatch(name,"fn_*"))
			isFuncRef = 1
		Else
			isFuncRef = 0
		EndIf
		
		If(stringmatch(name,"*menu_*")) //also captures contextual menu
			isMenu = 1
		Else
			isMenu = 0
		EndIf
		
		If(stringmatch(name,"ctxmenu_*"))
			isContextualMenu = 1
		Else
			isContextualMenu = 0
		EndIf
		
		If(stringmatch(name,"bt_*"))
			isButton = 1
		Else
			isButton = 0
		EndIf
		
		If(stringmatch(name,"lb_*"))
			isListBox = 1
		Else
			isListBox = 0
		EndIf

		strswitch(type)
			case "4"://variable
				Variable valueNum = str2num(getParam("PARAM_" + num2str(i) + "_VALUE",theFunction))
				
				//check for a coordinates definition
				String coordStr = getParam2(name,"COORDS",theFunction)
				
				If(!strlen(coordStr))
					Variable leftPos = left
					Variable topPos = top
				Else
					//coordinates are relative so they maintain their position when placed in a different order
					leftPos = (numtype(str2num(StringFromList(0,coordStr,";"))) == 2) ? left : left + str2num(StringFromList(0,coordStr,";"))
					topPos = (numtype(str2num(StringFromList(1,coordStr,";"))) == 2) ? top : top + str2num(StringFromList(1,coordStr,";"))
				EndIf
				
				//CheckBox designation
				If(stringmatch(name,"cb_*"))		
					valueNum = (valueNum > 0) ? 1 : 0
					SetParam("PARAM_" + num2str(i) + "_VALUE",theFunction,num2str(valueNum))
					
					CheckBox/Z $ctrlName win=NTP#Func,pos={leftPos+65,topPos},align=1,size={90,20},bodywidth=50,fsize=fontSize,font=$LIGHT,side=1,title=title,value=valueNum,disable=0,proc=ntExtParamCheckProc
				Else
					//Check for procedure assignments
					String theProc = getParam("PARAM_" + num2str(i) + "_PROC",theFunction)	 //special procedure reference
					If(!strlen(theProc))
						theProc = "ntExtParamProc"//default procedure
					EndIf
	
					SetVariable/Z $ctrlName win=NTP#Func,focusRing=0,pos={leftPos+125,topPos},align=1,size={90,20},fsize=fontSize,font=$LIGHT,bodywidth=75,title=title,value=_NUM:valueNum,disable=0,proc=$theProc
					
					//Is there an assignment with this variable?
					String controlAssignment = getParam("PARAM_" + num2str(i) + "_ASSIGN",theFunction)
					
					If(strlen(controlAssignment))
						Button/Z $(ctrlname + "_assign") win=NTP#Func,pos={left+175,top-2},align=1,size={45,20},fsize=fontSize,font=$LIGHT,title="Get",disable=0,mode=1,proc=ControlAssignmentButtonProc
					EndIf
					
				EndIf
								
				break
			case "8192"://string
			
				//Popup menu designation
				If(isMenu || isFuncRef)
					
					//Are the items a literal string expression or a function call?
					If(stringmatch(items,"*(*") && stringmatch(items,"*)*"))
						String itemStr = items
					Else
						itemStr = "\"" + items + "\""	
					EndIf
					
					String valueStr = getParam("PARAM_" + num2str(i) + "_VALUE",theFunction)	
					
					//check for a coordinates definition
					coordStr = getParam2(name,"COORDS",theFunction)
					
					If(!strlen(coordStr))
					   leftPos = left
						topPos = top
					Else
						leftPos = (numtype(str2num(StringFromList(0,coordStr,";"))) == 2) ? left : left + str2num(StringFromList(0,coordStr,";"))
						topPos = (numtype(str2num(StringFromList(1,coordStr,";"))) == 2) ? top : top + str2num(StringFromList(1,coordStr,";"))
					EndIf
					
					theProc = getParam("PARAM_" + num2str(i) + "_PROC",theFunction)	 //special procedure reference
					
					name = RemoveListItem(0,name,"_") //removes the "menu" prefix
					
					If(!strlen(theProc))
						If(isContextualMenu)
							theProc = "ntContextualMenuProc"//contextual menu procedure
						Else
							theProc = "ntExtParamPopProc"//default procedure
						EndIf
					Else
						If(isMenu && !isContextualMenu)
							menuProcEngageList += "menu_" + name + ";"
						ElseIf(isFuncRef)
							menuProcEngageList += "fn_" + name + ";"
						EndIf
					EndIf
				
					If(isMenu)
						If(isContextualMenu)
							String spacedStr = getSpacer(valueStr,18)
							Button/Z $ctrlName win=NTP#Func,pos={leftPos+200,topPos},align=1,size={150,20},fsize=fontSize,font=$LIGHT,title=spacedStr,disable=0,mode=1,proc=$theProc	 
							
							ControlInfo/W=NTP#Func $ctrlname
					
							//Text label for the contextual menu
							SetDrawLayer/W=NTP#Func UserBack
							DrawAction/W=NTP#Func getGroup=$("ContextualMenu" + num2str(i)),delete
							SetDrawEnv/W=NTP#Func gname=$("ContextualMenu" + num2str(i)),gstart
							SetDrawEnv/W=NTP#Func xcoord= abs,ycoord= abs, fsize=fontSize, textxjust= 2,textyjust= 1,fname=$LIGHT //right aligned
							DrawText/W=NTP#Func V_left - 5,V_top + 10,title
							SetDrawEnv/W=NTP#Func gname=$("ContextualMenu" + num2str(i)),gstop
							
						Else
							PopUpMenu/Z $ctrlName win=NTP#Func,pos={leftPos+200,topPos},align=1,size={185,20},fsize=fontSize,font=$LIGHT,bodywidth=150,title=title,value=#itemStr,disable=0,proc=$theProc	
						EndIf
						
						If(!strlen(valueStr)) //no set pop up selection
							ControlInfo/W=NTP#Func $ctrlName
							
							//insert the existing selection in the control into the parameter table
							If(isContextualMenu)
								setParam("PARAM_" + num2str(i) + "_VALUE",theFunction,S_Title)
							Else
								setParam("PARAM_" + num2str(i) + "_VALUE",theFunction,S_Value)
							EndIf
						Else
							If(isContextualMenu)
								Button/Z $ctrlName win=NTP#Func,title=valueStr
							Else
								PopUpMenu/Z $ctrlName win=NTP#Func,popmatch=valueStr
							EndIf
						EndIf					
						
					ElseIf(isFuncRef)				
						PopUpMenu/Z $ctrlName win=NTP#Func,pos={leftPos+200,topPos},align=1,size={185,20},fsize=fontSize,font=$LIGHT,bodywidth=150,title=title,value=GetExternalFunctions(),disable=0,proc=$theProc
						PopUpMenu/Z $ctrlName win=NTP#Func,popmatch=valueStr
						Button/Z $(ctrlName + "_goto") win=NTP#Func,pos={leftPos+250,topPos},align=1,size={45,20},fsize=fontSize,font=$LIGHT,title="GoTo",disable=0,mode=1,proc=DataSetButtonProc
						
						//place the arguments input directly below the function
						topPos += 25
						String argStr = getParam("PARAM_" + num2str(i) + "_ARGS",theFunction)
						
						Variable argWidth = 310
						SetVariable/Z $(ctrlName+ "_args") win=NTP#Func,pos={leftPos+argWidth+25,topPos},align=1,size={0,20},fsize=fontSize,font=$LIGHT,bodywidth=argWidth,title="Args",value=_STR:argStr,disable=0,proc=ntExtParamProc
						top += 30
					EndIf
					
				ElseIf(isButton)
					
					theProc = getParam("PARAM_" + num2str(i) + "_PROC",theFunction)	 //special procedure reference
					If(!strlen(theProc))
						theProc = "ntButtonProc"//default procedure
					EndIf
					
					//check for a coordinates definition
					coordStr = getParam2(name,"COORDS",theFunction)
					
					Variable width = 185
					Variable height = 20
					leftPos = left
					topPos = top
						
					If(strlen(coordStr))
//						leftPos = str2num(StringFromList(0,coordStr,";"))
						leftPos = (numtype(str2num(StringFromList(0,coordStr,";"))) == 2) ? leftPos : leftPos + str2num(StringFromList(0,coordStr,";"))
//						topPos = str2num(StringFromList(1,coordStr,";"))
						topPos = (numtype(str2num(StringFromList(1,coordStr,";"))) == 2) ? topPos : topPos + str2num(StringFromList(1,coordStr,";"))
//						width = str2num(StringFromList(2,coordStr,";"))
						width = (numtype(str2num(StringFromList(2,coordStr,";"))) == 2) ? width : str2num(StringFromList(2,coordStr,";"))
//						height = str2num(StringFromList(3,coordStr,";"))
						height = (numtype(str2num(StringFromList(3,coordStr,";"))) == 2) ? height : str2num(StringFromList(3,coordStr,";"))
					EndIf
					
//					print(leftPos)
					name = RemoveListItem(0,name,"_") //removes the "bt" prefix
					
					Button/Z $ctrlName win=NTP#Func,pos={leftPos+200,topPos},align=1,size={width,height},fsize=fontSize,font=$LIGHT,bodywidth=150,title=title,disable=0,proc=$theProc
					
				ElseIf(isListBox)
					
					String listWaveStr = getParam2(name,"LISTWAVE",theFunction)
					String selWaveStr = getParam2(name,"SELWAVE",theFunction)
					
					If(strlen(listWaveStr) && !WaveExists($listWaveStr))
						Make/N=0/T $listWaveStr
					EndIf
					
					If(strlen(selWaveStr) && !WaveExists($selWaveStr))
						Make/N=0 $selWaveStr
					EndIf
					
					If(WaveExists($listWaveStr) && WaveExists($selWaveStr))
						Wave listWave=$listWaveStr
						Wave selWave=$selWaveStr
						Redimension/N=(DimSize(listWave,0)) selWave
					EndIf
					
					coordStr = getParam2(name,"COORDS",theFunction)
					
					If(!strlen(coordStr))
						DoAlert 0,"Must supply a coordinates flag in the function for all list boxes"
						continue
					EndIf
					
					String dimLabelStr = getParam2(name,"DIMLABELS",theFunction)
					
					If(strlen(dimLabelStr))
						If(ItemsInList(dimLabelStr,";") == DimSize(listWave,1))
							Variable j
							For(j=0;j<ItemsInList(dimLabelStr,";");j+=1)
								SetDimLabel 1,j,$StringFromList(j,dimLabelStr,";"),listWave
							EndFor
						EndIf
					EndIf
					
					name = RemoveListItem(0,name,"_") //removes the "lb" prefix
					
					Variable mode
					If(!strlen(selWaveStr))
						mode = 0 //no selection possible
					Else
						mode = 9 //multiple, disjointed selections with shift selection 
					EndIf
					
				
					leftPos = str2num(StringFromList(0,coordStr,";"))
					topPos = str2num(StringFromList(1,coordStr,";"))
					width = str2num(StringFromList(2,coordStr,";"))
					height = str2num(StringFromList(3,coordStr,";"))
					
					theProc = getParam("PARAM_" + num2str(i) + "_PROC",theFunction)	 //special procedure reference
					If(!strlen(theProc))
						theProc = "ntListBoxProc"//default procedure
					EndIf
					
					//position is added to the base positioning of all other controls using 'left' and 'top' variables
					ListBox/Z $ctrlName win=NTP#Func,pos={left + leftPos,top + topPos},userColumnResize=1,size={width,height},listWave=$listWaveStr,selWave=$selWaveStr,fsize=fontSize,font=$LIGHT,disable=0,mode=mode,proc=$theProc
					top -=25
				Else
					valueStr = getParam("PARAM_" + num2str(i) + "_VALUE",theFunction)
					
				EndIf
				
				//test if the string is a data set reference, in which case make it a popup menu
				If(stringmatch(name,"DS_*"))		
					//Data Set Menu			
					SVAR DSNameList = NPD:DSNameList
					DSNameList = textWaveToStringList(NPD:DSNamesLB_ListWave,";")
					DSNameList = "**Wave Match**;**Navigator**;" + DSNameList
					
					String selection = getParam("PARAM_" + num2str(i) + "_VALUE",theFunction)
					If(!strlen(selection))
						selection = StringFromList(0,DSNameList,";") //will always at least have Wave Match as the first item
					EndIf
					
					Variable selectionIndex = WhichListItem(selection,DSNameList,";")
				
					
//					PopUpMenu/Z $ctrlName win=NTP#Func,pos={left+200,top},align=1,size={185,20},fsize=fontSize,font=$LIGHT,bodywidth=150,title=StringFromList(1,name,"_"),value=GetDataSetNamesList(),disable=0,mode=1,popValue=selection,proc=ntExtParamPopProc
					//Make a button with a contextual pop up menu, so we can have submenus
					spacedStr = getSpacer(selection,18)
					Button/Z $ctrlname win=NTP#Func,pos={left+200,top},align=1,size={150,20},fsize=fontSize,font=$LIGHT,title=spacedStr,disable=0,mode=1,proc=DataSetButtonProc
					//extra button comes with data set definitions to automatically load up that data set to the list box
					Button/Z $(ctrlname + "_show") win=NTP#Func,pos={left+250,top},align=1,size={45,20},fsize=fontSize,font=$LIGHT,title="Show",disable=0,mode=1,proc=DataSetButtonProc
					
					ControlInfo/W=NTP#Func $ctrlname
					
					//Text label for the data set input
					SetDrawLayer/W=NTP#Func UserBack
					DrawAction/W=NTP#Func getGroup=$("DSNameLabel" + num2str(i)),delete
					SetDrawEnv/W=NTP#Func gname=$("DSNameLabel" + num2str(i)),gstart
					SetDrawEnv/W=NTP#Func xcoord= abs,ycoord= abs, fsize=fontSize, textxjust= 2,textyjust= 1,fname=$LIGHT //right aligned
					DrawText/W=NTP#Func V_left - 5,V_top + 10,title
					SetDrawEnv/W=NTP#Func gname=$("DSNameLabel" + num2str(i)),gstop
					
				ElseIf(stringmatch(name,"CDF_*"))
					SVAR DSNameList = NPD:DSNameList
					DSNameList = textWaveToStringList(NPD:DSNamesLB_ListWave,";")
					DSNameList = "**Wave Match**;**Navigator**;" + DSNameList
					
					//Current Data Folder Waves Menu
					selection = getParam("PARAM_" + num2str(i) + "_VALUE",theFunction)
					selectionIndex = WhichListItem(selection,DSNameList,";")
					
					If(selectionIndex == -1)
						selectionIndex = 0
					EndIf
					
					PopUpMenu/Z $ctrlName win=NTP#Func,pos={left,top},size={185,20},font=$LIGHT,fsize=fontSize,bodywidth=150,title=title,value=WaveList("*",";",""),disable=0,mode=1,popValue=selection,proc=ntExtParamPopProc
				ElseIf(!isButton && !isMenu && !isFuncRef && !isListBox)
						//Potential custom coordinates
					coordStr = getParam2(name,"COORDS",theFunction)
					
					width = 150
					height = 20
					leftPos = left
					topPos = top
					
					If(strlen(coordStr))
						leftPos = (numtype(str2num(StringFromList(0,coordStr,";"))) == 2) ? leftPos : leftPos + str2num(StringFromList(0,coordStr,";"))
						topPos = (numtype(str2num(StringFromList(1,coordStr,";"))) == 2) ? topPos : topPos + str2num(StringFromList(1,coordStr,";"))
						width = (numtype(str2num(StringFromList(2,coordStr,";"))) == 2) ? width : str2num(StringFromList(2,coordStr,";"))
						height = (numtype(str2num(StringFromList(3,coordStr,";"))) == 2) ? height : str2num(StringFromList(3,coordStr,";"))
					EndIf
					
//					leftPos = str2num(StringFromList(0,coordStr,";"))
//					topPos = str2num(StringFromList(1,coordStr,";"))
//					width = str2num(StringFromList(2,coordStr,";"))
//					height = str2num(StringFromList(3,coordStr,";"))
					
					If(strlen(coordStr))
						SetVariable/Z $ctrlName win=NTP#Func,focusRing=0,pos={leftPos+200,topPos},align=1,size={width+40,height},fsize=fontSize,font=$LIGHT,bodywidth=width,title=title,value=_STR:valueStr,disable=0,proc=ntExtParamProc
					Else
						SetVariable/Z $ctrlName win=NTP#Func,focusRing=0,pos={left+200,top},align=1,size={190,20},fsize=fontSize,font=$LIGHT,bodywidth=150,title=title,value=_STR:valueStr,disable=0,proc=ntExtParamProc
					EndIf	
				EndIf
				
				break
			case "16386"://wave
				valueStr = getParam("PARAM_" + num2str(i) + "_VALUE",theFunction)
				//this will convert a wave path to a wave reference pointer
				SetVariable/Z $ctrlName win=NTP#Func,pos={left+290,top},size={0,20},focusRing=0,fsize=fontSize,align=1,font=$LIGHT,bodywidth=240,title=title,value=_STR:valueStr,disable=0,proc=ntExtParamProc
				ControlUpdate/W=NTP#Func $ctrlName
				ControlInfo/W=NTP#Func $ctrlName
//				leftPos = V_left * ScreenREsolution/72
				Button/Z $(ctrlname + "_Nav") win=NTP#Func,pos={V_right+5,top-2},size={60,20},fsize=fontSize,font=$LIGHT,title="From Nav",disable=0,mode=1,proc=DataSetButtonProc
				
				//confirm validity of the wave reference
				validWaveText("",0,deleteText=1,parentCtrl=ctrlName)
				ControlInfo/W=NTP#Func $ctrlName
				validWaveText(valueStr,V_top+13,parentCtrl=ctrlName)
				
				break
			case "4608"://structure
				top -= 25 //reset back				
				break
		endswitch
		top += 25
		
	EndFor
	
	//intitiate structure for pop up menus
	STRUCT WMPopupAction pa
	 
	For(i=0;i<ItemsInList(menuProcEngageList,";");i+=1)
		name = StringFromList(i,menuProcEngageList,";")
		ctrlName = getParam2(name,"CTRL",theFunction)
		theProc = getParam2(name,"PROC",theFunction)
		selection = getParam2(name,"VALUE",theFunction)
		
		//set the pop up menu structure
		pa.ctrlName = ctrlName 
		pa.eventCode = 2 //mouse up
		pa.popStr = selection //selection
		pa.popNum = 0 //default to zero, don't need it
		
		FUNCREF popUpProtoFunc f = $theProc
		f(pa)
	EndFor
	
	//Display the function note where the data set notes usually go
	DisplayFunctionNote(theFunction,functionNote)
	
End

//Proto function for engaging arbitrary pop up menu procs programatically
Function popUpProtoFunc(pa)
	STRUCT WMPopupAction &pa
End

Function/S GetDataSetNamesList()
	DFREF NPD = $DSF
	SVAR DSNameList = NPD:DSNameList
	
	DSNameList = "**Wave Match**;" + GetDataGroup("All")
	return DSNameList
End

Function DisplayFunctionNote(func,functionNote)
	String func,functionNote
	
	DFREF NPD = $DSF
	DFREF NPC = $CW
	
	NVAR funcPanelWidth = NPC:funcPanelWidth
	
	Variable startBold = 0
	Variable endBold = 0
	Variable loc = 0
	String subNote = ""
	
	Notebook NTP#Func#DSNotebook,selection={startOfFile,endOfFile},setData=""
	Notebook NTP#Func#DSNotebook writeProtect=1,selection={(0,0),(0,0)}
	Do
		startBold = strsearch(functionNote,"\f01",endBold)
		
		//No bold character escape sequence
		If(startBold == -1)
			subNote = functionNote[loc,strlen(functionNote)-1]
			Notebook NTP#Func#DSNotebook,fStyle=0,fSize=12,spacing={0,6,0},font="Helvetica Light"
			Notebook NTP#Func#DSNotebook,setData=subNote
			break
		EndIf
		
		//Note up to the bold escape sequence
		subNote = functionNote[loc,startBold - 1]
		Notebook NTP#Func#DSNotebook,fStyle=0,fSize=12,spacing={0,6,0},font="Helvetica Light"
		Notebook NTP#Func#DSNotebook,setData=subNote
		
		
		//Bold text itself, must find end bold escape sequence
		endBold = strsearch(functionNote,"\f00",startBold)
		
		//Case of no end bold sequence, all is bold
		If(endBold == -1)
			subNote = functionNote[startBold,strlen(functionNote)-1]
			Notebook NTP#Func#DSNotebook,fStyle=1,fSize=12,spacing={0,6,0},font="Helvetica Light"
			Notebook NTP#Func#DSNotebook,setData=subNote
			break
		EndIf
		
		//Found end bold escape sequence
		subNote = functionNote[startBold+4,endBold-1]
		loc = endBold + 4
		Notebook NTP#Func#DSNotebook,fStyle=1,fSize=12,spacing={0,6,0},font="Helvetica Light"
		Notebook NTP#Func#DSNotebook,setData=subNote
		
	While(loc < strlen(functionNote))
	
	//Draw the function name or data set name above the note
	ControlInfo/W=NTP#Func DSNotesBox
	Variable topPos = V_top + 8
	
	//Delete the existing title and refresh
	SetDrawLayer/W=NTP#Func Overlay
	DrawAction/W=NTP#Func getgroup=dsNotesText,delete
	
	SetDrawLayer/W=NTP#Func Overlay
	SetDrawEnv/W=NTP#Func gstart,gname=dsNotesText,xcoord= abs,ycoord= abs, fsize=16, textxjust= 0,textyjust= 2,fname="Helvetica Light"
	DrawText/W=NTP#Func 15,topPos,"Function:    \f01" + func
	SetDrawEnv/W=NTP#Func gstop
	
		
	//Disable and hide save notes button
	Button SaveNotes win=NTP#Func,disable=3
End

//Returns the optional function note from the procedural text
//Syntax is Note = {this is the note to be displayed}
Function/S GetFunctionNote(functionStr)
	String functionStr
	String funcNote = ""
	
	Variable loc = strsearch(functionStr,"Note",0)
	
	If(loc == -1)
		return ""
	EndIf
	
	Variable startLoc = strsearch(functionStr,"{",loc) + 1
	
	If(startLoc == -1 || startLoc - loc > 10) //prevents other instances of { from triggering the note search
		return ""
	EndIf
	
	Variable endLoc = strsearch(functionStr,"}",startLoc) - 1
	
	If(endLoc == -1)
		return ""
	EndIf
	
	funcNote = functionStr[startLoc,endLoc]
	
	//Remove starting return
	If(!cmpstr(funcNote[0],"\r"))
		funcNote = ReplaceString("\r",funcNote,"",0,1)
	EndIf
	
	//Remove comment lines
	funcNote = ReplaceString("//",funcNote,"")
	
	//Remove all tabs
	funcNote = ReplaceString("\t",funcNote,"")
	
	return funcNote
End

//Gets flags from functions. //SUBMENU or //TITLE flags return their value 
//e.g. //SUBMENU=Imaging returns imaging for NT_GetFlagString("SUBMENU",functionStr)
Function/S NT_GetFlagString(flag,functionStr)
	String flag
	String functionStr
	
	String flagStr = ""
	
	//Determine if there is a submenu definition
	Variable locStart = strsearch(functionStr,flag,0)
	Variable locEnd = strsearch(functionStr,"\r",locStart)
	
	If(locStart == -1)
		return ""
	Else
		flagStr = functionStr[locStart,locEnd]
	EndIf
	
	//Remove whitespace between the flag and the '='
	Variable checkLeft = 0
	Variable checkRight = 0
	Do
		If(stringmatch(flagStr,"* =*"))
			flagStr = ReplaceString(" =",flagStr,"=")
		Else
			checkLeft = 1
		EndIf
		
		If(stringmatch(flagStr,"*= *"))
			flagStr = ReplaceString("= ",flagStr,"=")
		Else
			checkRight = 1
		EndIf
		
	While(!checkLeft || !checkRight)
	
	flagStr = StringByKey(flag,flagStr,"=")
	flagStr = RemoveEnding(flagStr," ") //remove whitespace
	flagStr = RemoveEnding(flagStr,"\r") //remove carraige return
	flagStr = RemoveEnding(flagStr,"\n") //remove new line
	
	return flagStr
End

//Finds the control title from the code

//Finds the pop up menu values from the code
Function/S NT_GetPopUpValue(popUpStr,functionStr)
	String popUpStr,functionStr
	String values = ""
	
	If(!strlen(popUpStr) || !strlen(functionStr))
		return ""
	EndIf
	
	//Syntax for referencing the list items in a user defined menu
	String list = popUpStr + "_List"
	
	Variable pos = strsearch(functionStr,list,0)
	
	If(pos == -1)
		print "Couldn't find the pop up menu items for " + popUpStr + ". Make sure the syntax for referencing them is correct."
		return ""
	EndIf
	
	//Extracts the referenced item list using string quotations as a list separator
	values = functionStr[pos,pos + 400]
	
	//Get the equals sign position
	pos = strsearch(values,"=",0)
	
	If(pos == -1)
		print "Couldn't find the pop up menu items for " + popUpStr + ". Make sure the syntax for referencing them is correct."
		return ""
	Else
		pos += 1
	EndIf
	
	values = values[pos,400 - pos]
	
	Variable endPt = strlen(values)
	
	//If this is a true string list, there will be quotations as the first character
	//Eliminate leading white space
	Variable i
	Do
		String char = values[0]
		
		If(!cmpstr(char," "))
			values = values[1,endPt]
			endPt = strlen(values)
		EndIf
	While(!cmpstr(char," "))
	
	If(!cmpstr(values[0],"\""))
		//The menu items are a string list
		values = StringFromList(1,values,"\"")
	Else
		//The menu items are a function return
		
		//Finds the trailing parentheses
		pos = strsearch(values,")",0)
		
		If(pos == -1)
			print "Couldn't find the pop up menu items for " + popUpStr + ". Make sure the syntax for referencing them is correct."
			return ""
		EndIf
		
		values = values[0,pos]
	EndIf
	
	return values
End


Function/S NT_GetControlFlag(ctrlStr,functionStr,flagStr)
	String ctrlStr,functionStr,flagStr
	
	//flagStr is the variable to be extracted from the code about a specific control.
	//flagStr takes one of the following values:
	//
	//Assign
	//Title
	//Pos
	//DimLabels
	
	If(!strlen(ctrlStr) || !strlen(functionStr) || !strlen(flagStr))
		return ""
	EndIf
	
	//Ensure valid entry for the flagStr
	strswitch(flagStr)
		case "Assign":
		case "Title":
		case "Pos":
		case "DimLabels":
			break
		default:
			return ""
	endswitch
	
	//Syntax for referencing the list box coordinates
	String ref = ctrlStr + "_" + flagStr
	
	Variable pos = strsearch(functionStr,ref,0,2)
	
	If(pos == -1)
		return ""
	EndIf
	
	//Extracts the referenced item list using string quotations as a list separator
	String text = functionStr[pos,pos + 400]
	
	//Get the equals sign position searching forward
	pos = strsearch(text,"=",0)
	
	//From here find the first quotations mark for the procedure reference
	Variable firstQuote = strsearch(text,"\"",pos)
	If(firstQuote == -1)
		return ""
	Else
		firstQuote += 1//move up a space because of the quote
	EndIf
	
	Variable secondQuote = strsearch(text,"\"",firstQuote + 1)
	If(secondQuote == -1)
		return ""
	Else
		secondQuote -= 1//move up a space because of the quote
	EndIf
	
	String returnStr = text[firstQuote,secondQuote]
	
	
	//Ensure no leading or trailing quotations
	If(!cmpstr(returnStr[0],"\""))
		returnStr = returnStr[1,strlen(returnStr) - 1]
	EndIf
	
	returnStr = RemoveEnding(returnStr,"\"")
	
	If(strlen(returnStr) > 1)
		returnStr = RemoveEnding(returnStr," ")
	EndIf
	
	return returnStr
End

Function/S NT_GetControlAssignment(ctrlStr,functionStr)
	String ctrlStr,functionStr
	
	If(!strlen(ctrlStr) || !strlen(functionStr))
		return ""
	EndIf
	
	//Syntax for referencing the list box coordinates
	String ref = ctrlStr + "_Assign"
	Variable pos = strsearch(functionStr,ref,0)
	
	If(pos == -1)
		return ""
	EndIf
	
	//Extracts the referenced item list using string quotations as a list separator
	String text = functionStr[pos,pos + 400]
	
	//Get the equals sign position searching forward
	pos = strsearch(text,"=",0)
	
	//From here find the first quotations mark for the procedure reference
	Variable firstQuote = strsearch(text,"\"",pos)
	If(firstQuote == -1)
		return ""
	Else
		firstQuote += 1//move up a space because of the quote
	EndIf
	
	Variable secondQuote = strsearch(text,"\"",firstQuote + 1)
	If(secondQuote == -1)
		return ""
	Else
		secondQuote -= 1//move up a space because of the quote
	EndIf
	
	String assignStr = text[firstQuote,secondQuote]
	
	
	//Ensure no leading or trailing quotations
	If(!cmpstr(assignStr[0],"\""))
		assignStr = assignStr[1,strlen(assignStr) - 1]
	EndIf
	
	assignStr = RemoveEnding(assignStr,"\"")
	assignStr = RemoveEnding(assignStr," ")
	
	return assignStr
End

Function/S  NT_GetSpecialCoords(ctrlStr,functionStr)
	String ctrlStr,functionStr
	
	If(!strlen(ctrlStr) || !strlen(functionStr))
		return ""
	EndIf
	
	//Syntax for referencing the list box coordinates
	String ref = ctrlStr + "_Pos"
	Variable pos = strsearch(functionStr,ref,0)
	
	If(pos == -1)
		return ""
	EndIf
	
	//Extracts the referenced item list using string quotations as a list separator
	String text = functionStr[pos,pos + 400]
	
	//Get the equals sign position searching forward
	pos = strsearch(text,"=",0)
	
	//From here find the first quotations mark for the procedure reference
	Variable firstQuote = strsearch(text,"\"",pos)
	If(firstQuote == -1)
		return ""
	Else
		firstQuote += 1//move up a space because of the quote
	EndIf
	
	Variable secondQuote = strsearch(text,"\"",firstQuote + 1)
	If(secondQuote == -1)
		return ""
	Else
		secondQuote -= 1//move up a space because of the quote
	EndIf
	
	String coordStr = text[firstQuote,secondQuote]
	
	
	//Ensure no leading or trailing quotations
	If(!cmpstr(coordStr[0],"\""))
		coordStr = coordStr[1,strlen(coordStr) - 1]
	EndIf
	
	coordStr = RemoveEnding(coordStr,"\"")
	coordStr = RemoveEnding(coordStr," ")
	
	return coordStr
	
End

Function/S NT_GetListBoxWaves(ctrlStr,key,functionStr)
	String ctrlStr,key,functionStr
	
	If(!strlen(ctrlStr) || !strlen(functionStr))
		return ""
	EndIf
	
	//Syntax for referencing a the list box waves
	String ref = ctrlStr + "_" + key
	Variable pos = strsearch(functionStr,ref,0)
	
	If(pos == -1)
		return ""
	EndIf
	
	//Extracts the referenced item list using string quotations as a list separator
	String text = functionStr[pos,pos + 400]
	
	//Get the equals sign position searching forward
	pos = strsearch(text,"=",0)
	
	//From here find the first quotations mark for the procedure reference
	Variable firstQuote = strsearch(text,"\"",pos)
	If(firstQuote == -1)
		return ""
	Else
		firstQuote += 1//move up a space because of the quote
	EndIf
	
	Variable secondQuote = strsearch(text,"\"",firstQuote + 1)
	If(secondQuote == -1)
		return ""
	Else
		secondQuote -= 1//move up a space because of the quote
	EndIf
	
	String theWaveStr = text[firstQuote,secondQuote]
	
	//Ensure no leading or trailing quotations
	If(!cmpstr(theWaveStr[0],"\""))
		theWaveStr = theWaveStr[1,strlen(theWaveStr) - 1]
	EndIf
	
	theWaveStr = RemoveEnding(theWaveStr,"\"")
	theWaveStr = RemoveEnding(theWaveStr," ") //white space check
	
	//Make sure the wave exists
	Wave/Z theWave = $theWaveStr
	If(!WaveExists(theWave))
	
		//Make sure the path to the wave exists
		String folderPath = ParseFilePath(1,theWaveStr,":",1,0)
		CreateFolder(folderPath)
		
		//make the wave if it doesn't exist
		If(!cmpstr(key,"ListWave"))
			Make/O/N=0/T $theWaveStr
		ElseIf(!cmpstr(key,"SelWave"))
			Make/O/N=0 $theWaveStr
		EndIf
	EndIf
	
	return theWaveStr
End

Function/S NT_GetSpecialProc(ctrlStr,functionStr)
	String ctrlStr,functionStr
	
	If(!strlen(ctrlStr) || !strlen(functionStr))
		return ""
	EndIf
	
	//Syntax for referencing a procedure for a user defined menu
	String ref = ctrlStr + "_Proc"
	Variable pos = strsearch(functionStr,ref,0)
	
	If(pos == -1)
		return ""
	EndIf
	
	//Extracts the referenced item list using string quotations as a list separator
	String text = functionStr[pos,pos + 400]
	
	//Get the equals sign position searching forward
	pos = strsearch(text,"=",0)
	
	//From here find the first quotations mark for the procedure reference
	Variable firstQuote = strsearch(text,"\"",pos)
	If(firstQuote == -1)
		return ""
	Else
		firstQuote += 1//move up a space because of the quote
	EndIf
	
	Variable secondQuote = strsearch(text,"\"",firstQuote + 1)
	If(secondQuote == -1)
		return ""
	Else
		secondQuote -= 1//move up a space because of the quote
	EndIf
	
	String theProc = text[firstQuote,secondQuote]
	
	//Ensure no leading or trailing quotations
	If(!cmpstr(theProc[0],"\""))
		theProc = theProc[1,strlen(theProc) - 1]
	EndIf
	
	theProc = RemoveEnding(theProc,"\"")
	theProc = RemoveEnding(theProc," ")
	
	//Make sure this checks out as a real function in the procedure file
	String info = FunctionInfo(theProc)
	
	//Is it a pop up menu type procedure?
	String type = StringByKey("SUBTYPE",info,":",";")
	If(!cmpstr(type,"PopupMenuControl") || !cmpstr(type,"ButtonControl") || !cmpstr(type,"ListBoxControl") || !cmpstr(type,"SetVariableControl"))
		return theProc
	Else
		print "GetPopUpProc Error: The procedure file " + theProc + " must be a PopupMenuControl procedure"
		return ""
	EndIf
End

//Returns the named parameter from the external functions data wave
Function/S getParam(key,func)
	String key,func
	DFREF NPC = $CW
	Wave/T param = NPC:ExtFunc_Parameters
	
	Variable row = FindDimLabel(param,0,key)
	Variable col = FindDimLabel(param,1,func)
	
	If(row < 0 || col < 0)
		return ""
	EndIf
	
	return param[row][col]
End

//Returns the named parameter from the external functions data wave for the named control
//extra functionality for this version of the function for returning the control name and control index
Function/S getParam2(ctrlName,key,func)
	String ctrlName,key,func
	
	DFREF NPC = $CW
	Wave/T param = NPC:ExtFunc_Parameters
	

	Variable col = FindDimLabel(param,1,func)
	If(col < 0)
		return ""
	EndIf
	
	Variable row = tableMatch(ctrlName,param,whichCol=col)
	
	If(row < 0)
		return ""
	EndIf
	
	String paramLabel = GetDimLabel(param,0,row)
	String whichParam = StringFromList(1,paramLabel,"_")
	If(!strlen(whichParam))
		return ""
	EndIf
	
	strswitch(key)
		case "CTRL":
			//returns the control name as in param0, or param1
			return "param" + whichParam
			break
		case "INDEX":
			return whichParam
			break
		default:
			key = "PARAM_" + whichParam  + "_" + key 
	
			row = FindDimLabel(param,0,key)
			If(row < 0 || col < 0)
				return ""
			EndIf
			
			return param[row][col]
	endswitch
End


//Sets the named parameter for an external function with the specified value
Function setParam(key,func,value)
	String key,func,value
	
	DFREF NPC = $CW
	Wave/T param = NPC:ExtFunc_Parameters
//	
//	Variable row = FindDimLabel(param,0,key)
//	Variable col = FindDimLabel(param,1,func)
//	
	param[%$key][%$func] = value
End

//Returns a string list of the control names for the indicated external function
Function/S getParamCtrlList(func)
	String func	
	String list = ""
	Variable i,numParams = str2num(getParam("N_PARAMS",func))
	
	For(i=0;i<numParams;i+=1)
		list += "param" + num2str(i) + ";"
	EndFor 
	return list
End

Function/S SetExtFuncCmd()
	Variable option//is this from external command, or is it from a built in command
	
	NVAR numExtParams = root:Packages:NT:numExtParams
	SVAR extParamTypes = root:Packages:NT:extParamTypes
	SVAR extParamNames = root:Packages:NT:extParamNames
	SVAR isOptional = root:Packages:NT:isOptional
	Variable i,type
	String runCmdStr = ""
	String name 
	
	SVAR builtInCmdStr = root:Packages:NT:runCmdStr
	
	//External function
	//ControlInfo/W=analysis_tools extFuncPopUp
	SVAR currentExtCmd = root:Packages:NT:currentExtCmd
	String theFunction = currentExtCmd
	runCmdStr = "NT_" + theFunction + "("

	For(i=0;i<numExtParams;i+=1)
		ControlInfo/W=NTP $("param" + num2str(i))
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
			case 16386://wave numeric
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

Function/S getExtFuncCmdStr(func)
	String func
	
	DFREF NPC = $CW
	Wave/T param = NPC:ExtFunc_Parameters
	
	Variable col = tableMatch(func,param,returnCol=1)
	If(col == -1)
		return ""
	EndIf
	
	String title = GetDimLabel(param,1,col)
	
	Variable i,numParams = str2num(getParam("N_PARAMS",title))
	
	String cmdStr = func + "("
	For(i=0;i<numParams;i+=1)
		String value = getParam("PARAM_" + num2str(i) + "_VALUE",title)
		String type = getParam("PARAM_" + num2str(i) + "_TYPE",title)
		String name = getParam("PARAM_" + num2str(i) + "_NAME",title)
		String args = getParam("PARAM_" + num2str(i) + "_ARGS",title)
		
		If(stringmatch(name,"*[*]*"))
			continue
		EndIf
		
		strswitch(type)
			case "4": //variable
				cmdStr += value + "," 
				break
			case "8192": //string
				If(!cmpstr(func,"RunCmdLine"))
					value = ReplaceString("\"",value,"\\\"")
					cmdStr += "\"" + value + "\"" + ","
				
				ElseIf(stringmatch(name,"fn_*"))
					
					//for function references, function will drop the return item into one of three possible containers, depending on type
					//this can be retrieved by the user in the same way for all functions by declaring this standard variable.
					String fnName = "NT_" + value
					String info = FunctionInfo(fnName)
					
					String returnType = StringByKey("RETURNTYPE",info)
					strswitch(returnType)
						case "4": //variable
							String returnStr = "root:Packages:NeuroToolsPlus:ControlWaves:returnVar"
							//Ensures that this drop return variable exists
							NVAR testVar = $returnStr
							If(!NVAR_Exists(testVar))
								Variable/G $returnStr
								NVAR testVar = $returnStr
								testVar = 0
							EndIf
							returnStr += " = "
							break
						case "8192": //string
							returnStr = "root:Packages:NeuroToolsPlus:ControlWaves:returnStr"
							//Ensures that this drop return variable exists
							SVAR testStr = $returnStr
							If(!SVAR_Exists(testStr))
								String/G $returnStr
								SVAR testStr = $returnStr
								testStr = ""
							EndIf
							returnStr += " = "
							break
						case "16384": //wave, for now only supports wave reference wave returns
							returnStr = "root:Packages:NeuroToolsPlus:ControlWaves:returnWave"
							
							Wave/Z/WAVE testWave
							If(!WaveExists(testWave))
								Make/O/N=0/WAVE $returnStr
							EndIf 
							returnStr += " = "
							break
					endswitch
					
					//find any data set references and replace them with the wave list
					Variable leftPos = 0
					Do
						leftPos = strsearch(args,"<",leftPos)
						If(leftPos != -1)
							Variable rightPos = strsearch(args,">",leftPos)
						Else
							break
						EndIf
						
						If(rightPos == -1)
							break
						EndIf
						
						//Name of the variable that refers to a data set
						String dsVarName = args[leftPos+1,rightPos-1]
						
						//Find the data set from that variable
						Variable index = tableMatch(dsVarName,param,whichCol=col)
						
						If(index != -1)
							//Found the reference, get the parameter #
							String theLabel = GetDimLabel(param,0,index)
							Variable paramIndex = ExtFuncParamIndex(theLabel)
							
							//Get the data set reference name
							String dsName = getParam("PARAM_" + num2str(paramIndex) + "_VALUE",func)
							
							Wave/T listWave = getExtFuncDataSet(func=func)
							DeletePoints/M=2 0,1,listWave
							
							String wList = TextWaveToStringList(listWave,";")
							args = ReplaceString("<" + dsVarName + ">",args,"\"" + wList + "\"",0,1)
						EndIf
						
						leftPos = rightPos
					While(1)
					
					//is a function reference, we will replace the function name with the full function argument command string
					value = returnStr + "NT_" + value + "(" + args + ")"
					value = ReplaceString("\"",value,"\\\"")
					cmdStr += "\"" + value + "\"" + "," 
				Else
					cmdStr += "\"" + value + "\"" + "," 
				EndIf
				break
			case "16386": //wave
				If(!strlen(value))
					value = "$\"\""
				EndIf
				
				cmdStr += value + "," 
				break
		endswitch

	EndFor
	
	cmdStr = RemoveEnding(cmdStr,",") + ")" //remove final comma
	return cmdStr
End

//Kills all the visible external function parameters controls
Function KillExtParams()

	Variable i
	Do

		KillControl/W=NTP#Func $("param" + num2str(i))
		
		SetDrawLayer/W=NTP#Func UserBack
		DrawAction/W=NTP#Func getGroup=$("DSNameLabel" + num2str(i)),delete
		DrawAction/W=NTP#Func getGroup=$("ContextualMenu" + num2str(i)),delete
		KillControl/W=NTP#Func $("param" + num2str(i) + "_show")
		KillControl/W=NTP#Func $("param" + num2str(i) + "_goto")
		KillControl/W=NTP#Func $("param" + num2str(i) + "_nav")
		KillControl/W=NTP#Func $("param" + num2str(i) + "_assign")
		KillControl/W=NTP#Func $("param" + num2str(i) + "_args")
		
		//Kill wave validity text
		validWaveText("",0,deleteText=1,parentCtrl="param" + num2str(i))
	
		i += 1
	While(i < 30) //maximum 30 different controls
	
	
End


//Updates the text showing valid and invalid wave references in the External Functions parameters
Function validWaveText(path,ypos,[,deleteText,parentCtrl])
	String path
	Variable ypos
	Variable deleteText
	String parentCtrl
	
	If(ParamIsDefault(parentCtrl))
		Variable leftPos = 400
	Else
		ControlInfo/W=NTP#Func $parentCtrl
		leftPos = V_right + 80
	EndIf
	
	If(!ParamIsDefault(deleteText))
		SetDrawLayer/W=NTP#Func UserBack
		DrawAction/W=NTP#Func getgroup=$("ValidWaveText_" + parentCtrl),delete
		SetDrawEnv/W=NTP#Func textrgb=(0,0,0), textxjust= 1,textyjust= 1,fstyle=0
		return 0
	EndIf
	
	If(WaveExists($path))
		SetDrawLayer/W=NTP#Func UserBack
		SetDrawEnv/W=NTP#Func textrgb= (3,52428,1),fstyle=2,fsize=10, textxjust= 0,textyjust= 0,gname=$("ValidWaveText_" + parentCtrl),gstart
		DrawText/W=NTP#Func leftPos,ypos,"Valid"
		SetDrawEnv/W=NTP#Func gstop
	Else
		SetDrawLayer/W=NTP#Func UserBack
		SetDrawEnv/W=NTP#Func textrgb= (65535,0,0),fstyle=2,fsize=10, textxjust= 0,textyjust= 0,gname=$("ValidWaveText_" + parentCtrl),gstart
		DrawText/W=NTP#Func leftPos,ypos,"Invalid"
		SetDrawEnv/W=NTP#Func gstop
	EndIf
	
	SetDrawEnv/W=NTP#Func textrgb=(0,0,0), textxjust= 1,textyjust= 1,fstyle=0
End

Function/S TT_GetStimList(fileID)
	Variable fileID
	
	//Open the data group
	Variable DataGroup_ID
	HDF5OpenGroup/Z fileID,"/Data",DataGroup_ID
	
	//Gets the series list
	HDF5ListGroup/TYPE=1/Z DataGroup_ID,"/Data"
	String seriesList = S_HDF5ListGroup
	
	Variable i,seriesID
	String protocolList = ""
	
	For(i=0;i<ItemsInList(seriesList,";");i+=1)
		String series = StringFromList(i,seriesList,";")
		HDF5LoadData/Q/A="Protocol"/N=prot/TYPE=1 fileID,"/Data/" + series
		Wave/T prot
		protocolList += prot[0] + ";"
		
		KillWaves prot
	EndFor

	KillWaves prot
	return protocolList
End

Function/S TT_GetProtocolList(fileID)
	Variable fileID
	
	//Open the data group
	Variable DataGroup_ID
	HDF5OpenGroup/Z fileID,"/Data",DataGroup_ID
	
	//Gets the series list
	HDF5ListGroup/TYPE=1/Z DataGroup_ID,"/Data"
	String seriesList = S_HDF5ListGroup
	seriesList = SortList(seriesList,";",16)
	
	Variable i,seriesID
	String protocolList = ""
	
	For(i=0;i<ItemsInList(seriesList,";");i+=1)
		String series = StringFromList(i,seriesList,";")
		HDF5LoadData/Q/A="Protocol"/N=prot/TYPE=1 fileID,"/Data/" + series
		Wave/T prot
		protocolList += prot[0] + ";"
		
		KillWaves prot
	EndFor

	KillWaves prot
	return protocolList

End

//Returns the list of data series in the provided turntable ephys file
Function/S TT_GetSeriesList(fileID,separator)
	Variable fileID
	String separator
	
	//Open the data group
	Variable DataGroup_ID
	HDF5OpenGroup/Z fileID,"/Data",DataGroup_ID
	
	//Gets the series list
	HDF5ListGroup/TYPE=1/Z DataGroup_ID,"/Data"
	String seriesList = S_HDF5ListGroup
	
	//alphanumeric sort
	seriesList = SortList(seriesList,";",2)
	
	seriesList = ReplaceString(";",seriesList,separator)
	return seriesList
End

//Returns a list of the number of sweeps in each series in the input list
Function/S TT_GetSweepNumbers(fileID,seriesList)
	Variable fileID
	String seriesList
	
	seriesList = ResolveListItems(seriesList,";")
	
	String sweepNums = ""
	
	Variable i
	For(i=0;i<ItemsInList(seriesList,";");i+=1)
		String series = StringFromList(i,seriesList,";")
		
		String sweepList = TT_GetSweepList(fileID,series,";")
		
		sweepNums += num2str(ItemsInList(sweepList,";")) + ";"
	EndFor
	
	return sweepNums
End

//Returns the list of sweeps in the provided turntable ephys file and series number
Function/S TT_GetSweepList(fileID,series,separator)
	Variable fileID
	String series,separator
	
	//Open the data group
	Variable DataGroup_ID
	HDF5OpenGroup/Z fileID,"/Data",DataGroup_ID

	//Gets the series list
	HDF5ListGroup/TYPE=1/Z DataGroup_ID,"/Data"
	HDF5CloseGroup/Z DataGroup_ID
	
	String seriesList = S_HDF5ListGroup
	
	//Is the series requested valid?
	Variable err = WhichListItem(series,seriesList,";")
	
	If(err == -1)
		return ""
	EndIf
	
	String address = "/Data/" + series + "/Ch1"
	HDF5OpenGroup/Z fileID,address,DataGroup_ID
	HDF5ListGroup/TYPE=2/Z DataGroup_ID,address
	String sweepList = ReplaceString(";",S_HDF5ListGroup,separator)
	
	HDF5CloseGroup/Z DataGroup_ID
	
	sweepList = SortList(sweepList,separator,2)
	return sweepList
End

//Returns the list of sweeps in the provided turntable ephys file and series number
Function/S TT_GetSeriesUnits(fileID,series)
	Variable fileID
	String series
	
	//Open the data group
	Variable DataGroup_ID
	HDF5OpenGroup/Z fileID,"/Data",DataGroup_ID
	
	//Gets the series list
	String sweepList = TT_GetSweepList(fileID,series,";")
	
	Variable i,seriesID
	String unitList = ""
	
	For(i=0;i<ItemsInList(sweepList,";");i+=1)
		String sweep = StringFromList(i,sweepList,";")
		
		HDF5LoadData/Q/A="IGORWaveUnits"/N=units/TYPE=2/O fileID,"/Data/" + series + "/Ch1/" + sweep
		Wave/T units
		unitList += units[0] + ";"
	
		KillWaves units
	EndFor
	
	return unitList
End

//Returns the list of sweeps in the provided turntable ephys file and series number
Function/S TT_GetSeriesScale(fileID,series)
	Variable fileID
	String series
	
	//Open the data group
	Variable DataGroup_ID
	HDF5OpenGroup/Z fileID,"/Data",DataGroup_ID
	
	//Gets the series list
	String sweepList = TT_GetSweepList(fileID,series,";")
	
	Variable i,seriesID
	String scaleList = ""
	
	For(i=0;i<ItemsInList(sweepList,";");i+=1)
		String sweep = StringFromList(i,sweepList,";")
		
		HDF5LoadData/Q/A="IGORWaveScaling"/N=scale/TYPE=2/O fileID,"/Data/" + series + "/Ch1/" + sweep
		Wave scale
		scaleList += num2str(scale[1][0]) + ";"
	
		KillWaves scale
	EndFor
	
	return scaleList
End

Function/S TT_GetChannelList(fileID,series)
	Variable fileID
	String series
	
	//Get the list of channels that were recorded for that series number
	HDF5ListGroup/R=0/TYPE=1 fileID,"/Data/" + series
	String channelList = ListMatch(S_HDF5ListGroup,"*Ch*",";")
	channelList = ReplaceString("Ch",channelList,"") //remove Ch to only get a list of channel numbers
	
	return channelList
	
End

//Opens a wavesurfer HDF5 file, and lists out the sweep contents in the list boxes
Function UpdateWaveSurferLists(fileID,path,file)
	Variable fileID
	String path,file
	
	DFREF NPC = $CW
	Wave/T param = NPC:ExtFunc_Parameters
			
	Wave/T wsSweepListWave = $getParam2("lb_SweepList","LISTWAVE","NT_LoadEphys")
	Wave/T wsFileListWave = $getParam2("lb_FileList","LISTWAVE","NT_LoadEphys")
	Wave wsFileSelWave = $getParam2("lb_FileList","SELWAVE","NT_LoadEphys")
	
	//Fill the file list box
	NewPath/O/Q wsPath,path
	
	String fileList = IndexedFile(wsPath,-1,".h5")
	Wave/T listWave = StringListToTextWave(fileList,";")
	Redimension/N=(DimSize(listWave,0)) wsFileListWave,wsFileSelWave
	wsFileListWave = listWave
	
	//Get the groups in the file
	HDF5ListGroup/F/R/TYPE=1 fileID,"/"
	
	//Finds the data sweep groups
	S_HDF5ListGroup = ListMatch(S_HDF5ListGroup,"/sweep*",";")
	
	//Clean up the back slashes
	S_HDF5ListGroup = ReplaceString("/",S_HDF5ListGroup,"")
	
	//Add sweeps to the list box
	Wave/T sweepList = StringListToTextWave(S_HDF5ListGroup,";")
	Redimension/N=(DimSize(sweepList,0)) wsSweepListWave
	wsSweepListWave = sweepList
		
	HDF5LoadData/Q/O/Z/A="Name"/TYPE=1 fileID,"/StimGen/Stimulus"
	Wave/Z/T name = $StringFromList(0,S_waveNames,";")
	
	If(WaveExists(name))
		wsSweepListWave += "/" + name[0]
	EndIf
	
	KillWaves/Z name
	
		
	//Get the possible channels, and adjust the drop down menu
	HDF5LoadData/Z/N=channels/Q fileID,"/header/AIChannelNames"
	Wave/T channels = :channels
	
	String quote = "\""
	String channelList = quote + "All;" + ReplaceString(",",textWaveToStringList(channels,","),";") + quote
	
	Variable col = FindDimLabel(param,1,"NT_LoadEphys")
	Variable row = tableMatch("menu_Channels",param,whichCol=col)
	String whichParam = GetDimLabel(param,0,row)
	String paramName = "param" + StringFromList(1,whichParam,"_")
	PopUpMenu $paramName win=NTP#Func,value=#channelList
	
	KillWaves/Z channels

End

//Function VectorSum(inputWave,doPrint,returnItem,[scaled,angleWave,PN])
	//Calculates a vector sum of the input wave, and returns the specified value (angle, radius, or DSI)
	Wave inputWave //tuning curve wave
	Variable doPrint //print the results
	String returnItem //'vAngle', 'DSI', or 'vRadius'
	Variable scaled //x scaling is the angle
	Wave angleWave //supply an angle wave
	Variable PN //preferred null Vector Sum
	
	SetDataFolder GetWavesDataFolder(inputWave,1)
	
	If(!DataFolderExists("root:var"))
		NewDataFolder root:var
	EndIf
	
	If(ParamIsDefault(angleWave))
	//angle not wave supplied
		Make/O/N=8 root:var:direction
		Wave angleWave = root:var:direction
		If(ParamIsDefault(scaled))
			//not scaled, assue 45° delta angle
			angleWave = 45*x
		Else
			Redimension/N=(DimSize(inputWave,0)) angleWave
			angleWave = DimOffset(inputWave,0) + DimDelta(inputWave,0) * x
		EndIf
	EndIf
	
	
	If(ParamIsDefault(PN))
		PN = 0
	Else
		PN = 1
	EndIf
	
	//PN vector sum, don't use full tuning curve
	If(PN == 1)
		Redimension/N=2 angleWave
		angleWave = 180 * x
	EndIf
	
	If(cmpstr(returnItem,"vAngle") !=0 && cmpstr(returnItem,"vRadius") !=0 && cmpstr(returnItem,"DSI") !=0)
		DoAlert 0,"Must indicate return value of 'vAngle','vRadius', or 'DSI'."
		return -1
	EndIf
	
	Variable i,j,numCols
	Variable vSumX,vSumY,totalSignal
	Variable numAngles = DimSize(angleWave,0)
	
	numCols = DimSize(inputWave,1)
	Make/FREE/N=(numCols) angles,dsi_cols
	If(DimSize(angles,0) == 0)
		numCols += 1
		Redimension/N=(numCols) angles,dsi_cols
	EndIf
	angles = 0
	
	For(j=0;j<numCols;j+=1)
		//loop through each column of the input wave, in case there are multiple tuning curves, one per column
	
		//get data from each column of input wave
		Make/FREE/N=(DimSize(inputWave,0)) data
		data[][0] = inputWave[p][j]
		SetScale/P x,DimOffset(inputWave,0),DimDelta(inputWave,0),data
		
		vSumX = 0
		vSumY = 0
		totalSignal = 0
		
		Variable nullPt
		
		If(PN)
			//PN vector sum
			WaveStats/Q data
			nullPt = polarMath(V_maxLoc,180,"deg","add",0)
			If(nullPt == 360)
				nullPt = 0
			EndIf
		
			nullPt = ScaleToIndex(data,nullPt,0)//180° off of the max value direction (preferred)
			
			vSumX += data[V_maxRowLoc] * cos(angleWave[0]*pi/180)
			vSumY += data[V_maxRowLoc] * sin(angleWave[0]*pi/180)
			totalSignal += data[V_maxRowLoc]
			
			vSumX += data[nullPt] * cos(angleWave[1]*pi/180)
			vSumY += data[nullPt] * sin(angleWave[1]*pi/180)
			totalSignal += data[nullPt]
			
		Else
			//full tuning curve vector sum
			For(i=0;i<numAngles;i+=1)
				If(numtype(data[i]) == 2) 
					continue
				EndIf
				vSumX += data[i]*cos(angleWave[i]*pi/180)
				vSumY += data[i]*sin(angleWave[i]*pi/180)
				totalSignal += data[i]
			EndFor
		EndIf
		
		Variable vRadius = sqrt(vSumX^2 + vSumY^2)
		Variable vAngle = -atan2(vSumY,vSumX)*180/pi
		Variable	DSI = vRadius/totalSignal
		
		If(vAngle < 0)
			vAngle +=360
		Endif
		
		vAngle = 360 - vAngle
		
		angles[j] = vAngle
		dsi_cols[j] = DSI
		
		If(doPrint)
			print "vAngle =",vAngle,"\r  vRadius =",vRadius,"\r  DSI =",DSI	
		EndIf
		
	EndFor
	
	If(cmpstr(returnItem,"vAngle") == 0)
		If(DimSize(inputWave,1) > 0)
			Make/O/N=(DimSize(inputWave,1)) vAng_columns
			Wave vAng_cols = vAng_columns
			vAng_cols = angles
		
//			Make/O/N=(DimSize(inputWave,1)) vDSI_columns
//			Wave vDSI_cols = vDSI_columns
//			vDSI_cols = dsi_cols
		EndIf
		return vAngle
	ElseIf(cmpstr(returnItem,"vRadius") == 0)
		return vRadius
	ElseIf(cmpstr(returnItem,"DSI") == 0)
		If(DimSize(inputWave,1) > 0)
			Make/O/N=(DimSize(inputWave,1)) vDSI_columns
			Wave vDSI_cols = vDSI_columns
			vAng_cols = dsi_cols
		EndIf
		return DSI
	EndIf
	
End Function

Function polarMath(pnt1,pnt2,degrad,op,signed)
	Variable pnt1,pnt2,signed
	String degrad,op
	Variable angOut
	
	strswitch(op)
		case "add":
			angOut = pnt1 + pnt2
			break
		case "distance":
			Variable x1,y1,x2,y2,D,A
			 //linear distance between the points
			
			D = 2*pi*1*A/360
			
			If(!cmpstr(degrad,"deg"))
				x1 = cos(pnt1 * pi/180)
				y1 = sin(pnt1 * pi/180)
				x2 = cos(pnt2 * pi/180)
				y2 = sin(pnt2 * pi/180)
				D = sqrt( (x2 - x1)^2 + (y2 - y1)^2 )
				angOut = acos( (2 * (1^2) - D^2) / (2 * (1^2)) ) * 180/pi
			Else
				x1 = cos(pnt1)
				y1 = sin(pnt1)
				x2 = cos(pnt2)
				y2 = sin(pnt2)
				D = sqrt( (x2 - x1)^2 + (y2 - y1)^2 )
				angOut = acos( (2 * (1^2) - D^2) / (2 * (1^2)) )
			EndIf
			break
	endswitch
	
	strswitch(degrad)
		case "deg":
			angOut = (angOut > 360) ? (angOut - 360) : angOut
			angOut = (angOut < 0) ? (angOut + 360) : angOut
			
			//Determine the sign. Direction of point 2 relative to point 1
			If(signed)	
				
				Variable signTest = pnt1 + angOut
				
				If(signTest > 360)
					signTest -= 360
				EndIf	

				If(abs(signTest - pnt2) < 0.0001) 
					Variable theSign = 1
				Else
					theSign = -1
				EndIf
//				
//					
//				 
//						
//				If(pnt1 + angOut > 360)
//					If(pnt2 > pnt1)
//						Variable theSign = 1
//					Else
//						theSign = -1
//					EndIf
//				Else
//					If(pnt2 + 180 > pnt1)
//						theSign = -1
//					Else
//						theSign = 1
//					EndIf
//				EndIf
				
				angOut *= theSign
			EndIf
			
						
			break
		case "rad":
			angOut = (angOut > 2*pi) ? (angOut - 2*pi) : angOut
			angOut = (angOut < 0) ? (angOut + 2*pi) : angOut
			
			//Determine the sign. Direction of point 2 relative to point 1
			If(signed)	
				
				signTest = pnt1 + angOut
				
				If(signTest > 2*pi)
					signTest -= 2*pi
				EndIf	

				If(abs(signTest - pnt2) < 0.0001) 
					theSign = 1
				Else
					theSign = -1
				EndIf
				
				angOut *= theSign
			EndIf
			break
	endswitch
	
	return angOut
End

Function/S hex2str(code)
	String code
	
	Variable i
	String output = ""
	For(i=0;i<strlen(code);i+=2)
		
		output += num2char(str2num("0x" + code[i,i+1]))
	EndFor
	return output
End

//returns a string for 2PLSM or ScanImage depending on file structure in the pxp.
Function/S whichImagingSoftware()
	If(DataFolderExists("root:twoP_Scans"))
		return "2PLSM"
	Else
		return "ScanImage"
	EndIf
End

//Retrieves stimulus data from a WaveSurfer HDF5 file that has logged StimGen data
Function/WAVE GetStimulusData(fileID)
	Variable fileID
	
	DFREF NPC = $CW
	Wave/T wsStimulusDataListWave = NPC:wsStimulusDataListWave
	
	If(!fileID)
		return $""
	EndIf
	
	//Get the groups in the file
	HDF5ListGroup/F/R/TYPE=1 fileID,"/"
	S_HDF5ListGroup = ListMatch(S_HDF5ListGroup,"/StimGen*",";")
	
	If(!strlen(S_HDF5ListGroup))
		Redimension/N=(0,2) wsStimulusDataListWave
		return $""
	EndIf
	
	HDF5ListGroup/TYPE=1/Z fileID,"/StimGen/Stimulus"
	Variable numGroups = ItemsInList(S_HDF5ListGroup,";")
	
	HDF5ListAttributes/TYPE=1/Z fileID,"/StimGen/Stimulus/0"
	If(V_flag)
		return $""
	EndIf
	
	Variable numAttr = ItemsInList(S_HDF5ListAttributes,";")
	
	Variable i,j
	
	//Get the stimulus name
	String path = "/StimGen/Stimulus"
	HDF5LoadData/Z/Q/O/A="Name"/TYPE=1 fileID, path
	Wave/T data = $StringFromList(0,S_waveNames,";")
	String stimName = data[0]
	KillWaves/Z data
	
	Redimension/N=(numAttr + 1,numGroups + 1) wsStimulusDataListWave
	
	wsStimulusDataListWave[0][0] = "Stimulus"
	wsStimulusDataListWave[0][1] = stimName
	
	For(j=0;j<numGroups;j+=1)
		Variable objectNum = str2num(StringFromList(j,S_HDF5ListGroup,";"))
		For(i=0;i<numAttr;i+=1)
			String attr = StringFromList(i,S_HDF5ListAttributes,";")
			String value = GetAttribute(fileID,objectNum,attr)
			wsStimulusDataListWave[i+1][0] = attr //+1 leaves room at the top for the stimulus name
			wsStimulusDataListWave[i+1][j + 1] = value	
		EndFor
	EndFor
	
	Variable cleanup = 1
	If(cleanup)
		cleanStimData(wsStimulusDataListWave,fileID)
	EndIf
	
	return wsStimulusDataListWave
End

//Returns an attribute
Function/S GetAttribute(fileID,objectNum,attr)
	Variable fileID,objectNum
	String attr
	
	DFREF saveDF = GetDataFolderDFR()
	DFREF NPC = $CW
	SetDataFolder NPC
	
	String path = "/StimGen/Stimulus/" + num2str(objectNum)

	HDF5LoadData/Z/Q/O/A=attr/TYPE=1 fileID, path
	String stimWave = StringFromList(0,S_waveNames,";")
	
	Variable type = WaveType($stimWave,1)
	
	switch(type)
		case 0:
			return ""
			break
		case 1:
			Wave data = $stimWave
			If(DimSize(data,0) == 0)
				String value = ""
				break
			EndIf
			
			value = num2str(data[0])
			break
		case 2:
			Wave/T textData = $stimWave
			
			If(DimSize(textData,0) == 0)
				value = ""
				break
			EndIf
			
			value = textData[0]
			break
	endswitch
	
	KillWaves/Z data,textData,stimWave
	SetDataFolder saveDF
	
	return value
End

//Returns a list of stimulus attributes for the given stimulus object
Function/S refineAttributeList(stimData,attrList)
	Wave/T stimData //table of full stimulus data
	String attrList
	
	//Is their temporal modulation?
	Variable index = WhichListItem("modulationType",attrList,";")
	If(cmpstr(stimData[tableMatch("modulationType",stimData)][1],"Static"))
		attrList = AddListItem("modulationFreq",attrList,";",index+1)
	EndIf
	
	//Is there motion?
	index = WhichListItem("motionType",attrList,";")
	If(cmpstr(stimData[tableMatch("motionType",stimData)][1],"Static"))
	
		//Is there a trajectory or a standard motion drift?
		If(cmpstr(stimData[tableMatch("trajectory",stimData)][1],"None"))
			attrList = AddListItem("trajectory",attrList,";",index+1)
			attrList = AddListItem("startRad",attrList,";",index+1)
			attrList = AddListItem("speed",attrList,";",index+2)
		Else
			attrList = AddListItem("angle",attrList,";",index+1)
		EndIf
	EndIf
	
	return attrList
End

//Redimensions and fills the stimulus data table according to the attribute list
Function refineStimDataTable(stimData,attrList)
	Wave/T stimData
	String attrList
	
	//Create a duplicate working stimulus data wave
	Duplicate/FREE/T stimData,temp
	
	Redimension/N=(ItemsInList(attrList,";"),2) stimData
	stimData = ""
	
	Variable i
	For(i=0;i<ItemsInList(attrList,";");i+=1)
		String attr = StringFromList(i,attrList,";")
 		String value = temp[tableMatch(attr,temp)][1]
 		stimData[i][0] = attr
 		stimData[i][1] = value
	EndFor
	
End

Function fillTrajectoryAssignments(stimData,attrList,fileID)
	Wave/T stimData
	String attrList
	Variable fileID
	
	Variable index = tableMatch("trajectory",stimData)
	If(index != -1)
		String trajName = stimData[index][1]
	Else
		return 0
	EndIf
	
	//If no trajectory is assigned, return
	If(!cmpstr(trajName,"None"))
		return 0
	EndIf
	
	//Load the contents of the trajectory
	String theTrajectory = getTrajectory(trajName,fileID)
	
	If(!strlen(theTrajectory))
		return 0
	EndIf
	
	//Add the trajectory to the stim data wave
	Variable rows = DimSize(stimData,0)
	Redimension/N=(rows + 1,-1) stimData
	stimData[rows][0] = trajName
	stimData[rows][1] = theTrajectory
	
	String angle = StringByKey("angle",theTrajectory,":","//")
	String duration = StringByKey("duration",theTrajectory,":","//")
	
	Variable numAngles = ItemsInList(angle,",")
	Variable i
	
	For(i=0;i<numAngles;i+=1)
		String angleStr = StringFromList(i,angle,",")
		Variable angleNum = str2num(angleStr)
		
		//Is the angle a number or text?
		If(numtype(angleNum) == 2)
			//text
			String sequence = GetSequence(angleStr,fileID)
			
			//Add the sequence to the stim data wave
			rows = DimSize(stimData,0)
			Redimension/N=(rows + 1,-1) stimData
			stimData[rows][0] = angleStr
			stimData[rows][1] = sequence
		Else
			//numeric
			continue
		EndIf
	EndFor
	
End

//Returns the angle and duration in a key-value list of the named trajectory
Function/S GetTrajectory(trajName,fileID)
	String trajName
	Variable fileID
	String theTrajectory = ""
	
	String path = "/StimGen/Trajectories"
	HDF5LoadData/Z/Q/O/A=trajName/TYPE=1/N=stimData fileID, path
	
	If(strlen(S_waveNames))
		Wave/T data = $StringFromList(0,S_waveNames,";")
		theTrajectory = data[0]
		KillWaves/Z data
	EndIf
	
	//format the trajectory into readable list
	theTrajectory = ReplaceString("{",theTrajectory,"")
	theTrajectory = ReplaceString("}",theTrajectory,"")
	theTrajectory = ReplaceString("'",theTrajectory,"")
	theTrajectory = ReplaceString("[",theTrajectory,"")
	theTrajectory = ReplaceString("],",theTrajectory,"//")
	theTrajectory = ReplaceString("]",theTrajectory,"")
	theTrajectory = ReplaceString(" ",theTrajectory,"")
	theTrajectory = ReplaceString(",duration",theTrajectory,";duration")
	
	return theTrajectory
End

Function fillSequenceAssignments(stimData,attrList,fileID)
	Wave/T stimData
	String attrList
	Variable fileID
	
	String path = "/StimGen/Sequence Assignments/0"
	
	Variable i,index
	For(i=0;i<ItemsInList(attrList,";");i+=1)
		String attr = StringFromList(i,attrList,";")
		HDF5LoadData/Z/Q/O/A=attr/TYPE=1/N=stimData fileID, path
		
		If(strlen(S_waveNames))
			Wave/T data = $StringFromList(0,S_waveNames,";")
			String seqName = data[0]
			KillWaves/Z data
			
			If(cmpstr(seqName,"None"))
				String sequence = GetSequence(seqName,fileID)
				
				//put the sequence into the appropriate slot in the stimulus data table
				index = tableMatch(attr,stimData)
				stimData[index][1] = sequence
			EndIf
		EndIf
	EndFor
End

//returns the sequence assignment of the named attribute (diameter, angle, etc.)
Function/S GetSequenceAssignment(fileID,objectNum,attr)
	Variable fileID,objectNum
	String attr
	String assign = ""
	
	String path = "/StimGen/Sequence Assignments/" + num2str(objectNum)
	HDF5LoadData/Z/Q/O/A=attr/TYPE=1/N=stimData fileID, path
	
	If(strlen(S_waveNames))
		Wave/T data = $StringFromList(0,S_waveNames,";")
		assign = data[0]
	EndIf
	
	return assign
End

//Returns the sequence definition of the named sequence
Function/S GetSequence(seqName,fileID)
	String seqName
	Variable fileID
	String sequence = ""
	
	String path = "/StimGen/Sequences"
	HDF5LoadData/Z/Q/O/A=seqName/TYPE=1/N=stimData fileID, path
	
	If(strlen(S_waveNames))
		Wave/T data = $StringFromList(0,S_waveNames,";")
		sequence = data[0]
	EndIf
	
	//format the sequence into semi-colon list
	sequence = ReplaceString("'",sequence,"")
	sequence = ReplaceString("[",sequence,"")
	sequence = ReplaceString("]",sequence,"")
	sequence = ReplaceString(",",sequence,";")
	sequence = ReplaceString(" ",sequence,"")
	
	return sequence
End

Function cleanStimData(stimData,fileID)
	Wave/T stimData
	Variable fileID //open HDF5 file that contains stimulus data

	//What type of object is it?
	Variable index = tableMatch("objectType",stimData)
	If(index == -1)
		return 0
	EndIf
	
	String type = stimData[index][1]
	
	String value = ""
	
	strswitch(type)
		case "Circle":
	 		String attrList = "Stimulus;objectType;diameter;xPos;yPos;contrastType;contrast;modulationType;motionType;delay;duration;trialTime;"
	 		
			break
		case "Rectangle":		
	 		attrList = "Stimulus;objectType;length;width;orientation;xPos;yPos;contrastType;contrast;modulationType;motionType;delay;duration;trialTime;"
	 		
			break
		case "Grating":
	 		attrList = "Stimulus;objectType;gratingType;spatialFreq;spatialPhase;orientation;xPos;yPos;contrastType;contrast;modulationType;motionType;delay;duration;trialTime;"
	 		
			break
		case "Noise":
			attrList = "Stimulus;objectType;noiseType;noiseSize;noiseFreq;noiseSeed;xPos;yPos;contrastType;contrast;delay;duration;trialTime;"
			break
			
		case "Cloud":
			attrList = "Stimulus;objectType;cloudSF;cloudSFBand;cloudSpeedX;cloudSpeedY;cloudSpeedBand;cloudOrient;cloudOrientBand;contrastType;contrast;delay;duration;trialTime;xPos;yPos;"
			break
	endswitch
	
	//Adds motion and modulation parameters to the attribute list according to the stimulus
	attrList = refineAttributeList(stimData,attrList)
	
	//Fills out the stimulus data table according to the refined attribute list
	refineStimDataTable(stimData,attrList)
	
	//Fill out any sequence assignments
	fillSequenceAssignments(stimData,attrList,fileID)
	
	//Fill out any trajectory assignments
	fillTrajectoryAssignments(stimData,attrList,fileID)
	
End
