#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//This file handles all of the control activation code (i.e. Buttons, setVariables, ListBoxes, etc.)
//There is a single function for all controls of the same type


//LIST BOXES------------------------------------------------------------
Function ntListBoxProc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave
	Variable errorCode = 0
	
	DFREF NTD = root:Packages:NT:DataSets
	Variable hookResult = 0
	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			
			break
		case 2: // mouse up
			//display the full path to the wave in a text box
			
			If(row > DimSize(selWave,0) - 1 || row == -1)
				break
			EndIf
			
			If(!cmpstr(lba.ctrlName,"MatchListBox") || !cmpstr(lba.ctrlName,"DataSetWavesListBox"))
				DrawAction/W=NT getGroup=fullPathText,delete
				SetDrawEnv/W=NT fname=$LIGHT,fstyle=2,fsize=10,xcoord=abs,ycoord=abs, textxjust= 0,gname=fullPathText,gstart
				DrawText/W=NT 14,464,listWave[row][0][1]
				SetDrawEnv/W=NT gstop
			EndIf
			break
		case 3: // double click
			If(HandleLBDoubleClick(lba))
				print "DOUBLE CLICK LIST BOX ERROR"
			EndIf
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
			If(HandleLBSelection(lba.ctrlName,listWave,row,lba.mouseLoc.h,lba.mouseLoc.v,lba.eventMod))
				print "SELECTION CHANGE ERROR"
			EndIf
			
			//Only selection updates for keyboard triggered selections
			If(lba.eventMod == 0)
				If(!cmpstr(lba.ctrlName,"MatchListBox") || !cmpstr(lba.ctrlName,"DataSetWavesListBox"))
				DrawAction/W=NT getGroup=fullPathText,delete
				SetDrawEnv/W=NT fname=$LIGHT,fstyle=2,fsize=10,xcoord=abs,ycoord=abs,textxjust= 0,gname=fullPathText,gstart
				DrawText/W=NT 14,464,listWave[row][0][1]
				SetDrawEnv/W=NT gstop
				EndIf
			EndIf
			break
		case 6: // begin edit
		
			break
		case 7: // finish edit
			break
		case 13: // checkbox clicked (Igor 6.2 or later)
			break
	endswitch
	
	return 1
End

//Handles list box selections
Function HandleLBSelection(ctrlName,listWave,row,mouseHor,mouseVert,eventMod)
	String ctrlName
	Wave/T listWave
	Variable row,mouseHor,mouseVert,eventMod
	
	Variable errorCode = 0
	DFREF NTF = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	
	SVAR listFocus = NTF:listFocus
	
	strswitch(ctrlName)
		case "matchListBox": //wave matches
			Wave/T MatchLB_ListWave = NTF:MatchLB_ListWave
			Wave MatchLB_SelWave = NTF:MatchLB_SelWave
			
			//out of range selection
			If(row > DimSize(listWave,0) - 1)
				//change the list box focus still
				changeFocus("WaveMatch",1)
				
				//Delete full path wave text
				DrawAction/W=NT getGroup=fullPathText,delete
				return 0
			EndIf
			
			If(eventMod == 17)
				//GOTO selected wave contextual menu
				PopupContextualMenu/C=(mouseHor, mouseVert) "GoTo;Edit;Display;"
				If(V_flag)
					HandleRightClick("matchListBox",V_flag,row=row)
				EndIf
			EndIf
			
			//change the list box focus
			If(!cmpstr(listFocus,"DataSet"))
				changeFocus("WaveMatch",1)
			EndIf
					
			NVAR viewerOpen = NTF:viewerOpen
			If(viewerOpen)
				AppendToViewer(MatchLB_ListWave,MatchLB_SelWave)
			EndIf
					
			break
		case "dataSetWavesListBox": //data set waves
			//out of range selection
			If(row > DimSize(listWave,0) - 1)
				//change the list box focus still
				changeFocus("DataSet",1)
			
				//Delete full path wave text
				DrawAction/W=NT getGroup=fullPathText,delete
				
				return 0
			EndIf
			
			If(eventMod == 17)
				//GOTO selected wave contextual menu
				PopupContextualMenu/C=(mouseHor, mouseVert) "GoTo;Edit;Display;"
				If(V_flag)
					HandleRightClick("dataSetWavesListBox",V_flag,row=row)
				EndIf
			EndIf
			
			//change the list box focus
			If(!cmpstr(listFocus,"WaveMatch"))
				changeFocus("DataSet",1)
			EndIf
					
			//display the full path to the wave in a text box
			Wave/T DataSetLB_ListWave = NTD:DataSetLB_ListWave
			Wave DataSetLB_SelWave = NTD:DataSetLB_SelWave
			
			
			NVAR viewerOpen = NTF:viewerOpen
			If(viewerOpen)
				AppendToViewer(DataSetLB_ListWave,DataSetLB_SelWave)
			EndIf
			
			break
		case "dataSetNamesListBox": //data set names
						
			If(eventMod == 17)
				//If the right click happens on a non-previously selected data set,
				//first loads those data set setttings into the GUI controls
				If(row > DimSize(listWave,0) - 1)	
					return 0
				EndIf
				
				changeDataSet(listWave[row][0][0])
					
				//GOTO selected wave contextual menu
				PopupContextualMenu/C=(mouseHor,mouseVert) "Send To WaveMatch;"
				If(V_flag)
					HandleRightClick("dataSetNamesListBox",V_flag,row=row)
				EndIf
			Else
			
				//change the list box focus
				If(!cmpstr(listFocus,"WaveMatch"))
					changeFocus("DataSet",1)
				EndIf
				
				//correct row if we selected outside of the listbox limits
				If(row > DimSize(listWave,0) - 1 && DimSize(listWave,0) > 0)	
					row = DimSize(listWave,0) - 1
				EndIf
				
				changeDataSet(listWave[row][0][0])		
			EndIf
			
			break
		case "folderListBox":  //folder navigation
			//out of range selection
			If(row > DimSize(listWave,0) - 1)
				return 0
			EndIf
			
			If(eventMod == 17)
				//GOTO selected wave contextual menu
				PopupContextualMenu/C=(mouseHor, mouseVert) "GoTo;"
				If(V_flag)
					HandleRightClick("folderListBox",V_flag,row=row)
				EndIf
			EndIf
			break
		case "waveListBox":	//waves navigation
			Wave/T WavesLB_ListWave = NTF:WavesLB_ListWave
			Wave WavesLB_SelWave = NTF:WavesLB_SelWave
			
			//out of range selection
			If(row > DimSize(listWave,0) - 1)
				return 0
			EndIf
			
			If(eventMod == 17)
				//GOTO selected wave contextual menu
				PopupContextualMenu/C=(mouseHor, mouseVert) "GoTo;Edit;Display;"
				If(V_flag)
					HandleRightClick("waveListBox",V_flag,row=row)
				EndIf
			EndIf
			
			NVAR viewerOpen = NTF:viewerOpen
			If(viewerOpen)
				AppendToViewer(WavesLB_ListWave,WavesLB_SelWave)
			EndIf
			
			break
	endswitch
	return errorCode
End

//Handles list box right clicks
Function HandleRightClick(controlName,command,[row])
	String controlName
	Variable command,row
	DFREF NTF = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	
	STRUCT filters filters
	SVAR listFocus = NTF:listFocus
	
	Variable errorCode = 0
	strswitch(controlName)
		case "dataSetWavesListBox": //data set waves
			//Get the full path list wave for the selected data set
			String dsName = GetDSName()
			
			Wave/T listWave = GetDataSetWave(dsName,"ORG")
			
			//out of range selection
			If(row > DimSize(listWave,0) - 1)
				return 0
			EndIf
			
			//Selected wave in the data set waves list box
			String list = listWave[row][0][1]
			
			//If a wave set was selected
			If(stringmatch(list,"*WAVE SET*"))
				Variable wsn = str2num(StringByKey("WAVE SET",list," ","-"))
				Wave/T ws = GetWaveSet(listWave,wsn)
				DeletePoints/M=2 0,1,ws
				list = TextWaveToStringList(ws,";")
			EndIf
			
			doRightClickAction(command,list)
			
			break
		case "dataSetNamesListBox": //data set names
			//Right click sends the selected data set's filters, groups, and 
			//original wave match settings to the WaveMatch list
			
			Wave/T DSNamesLB_ListWave = NTD:DSNamesLB_ListWave
			Variable index = GetDSIndex()
			
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
			
			break
		case "folderListBox":  //folder navigation
			Wave/T FolderLB_ListWave = NTF:FolderLB_ListWave
			Wave/T FolderLB_SelWave = NTF:FolderLB_SelWave
			SVAR cdf = NTF:currentDataFolder
			
			//Get the first wave in the data folder
			SetDataFolder $(cdf + FolderLB_ListWave[row])
			
			String theWaveList = DataFolderDir(2)
			theWaveList = StringByKey("WAVES",theWaveList,":",";") //waves in the data folder
			theWaveList = SortList(theWaveList,",",16) //alphabetical order
			list = cdf + FolderLB_ListWave[row] + ":" + StringFromList(0,theWaveList,",") + ";"
			doRightClickAction(command,list)
			SetDataFolder $cdf
			break
		case "matchListBox":
		case "waveListBox":	//waves navigation
			
			//Get a list of the selected waves
			If(!cmpstr(controlName,"matchListBox"))	
				Wave/T listWave = NTF:MatchLB_ListWave
				If(row > DimSize(listWave,0)-1)
					return 0
				EndIf
				
				list = listWave[row][0][1] + ";"
				
				//If a wave set was selected
				If(stringmatch(list,"*WAVE SET*"))
					wsn = str2num(StringByKey("WAVE SET",list," ","-"))
					Wave/T ws = GetWaveSet(listWave,wsn)
					DeletePoints/M=2 0,1,ws
					list = TextWaveToStringList(ws,";")
				EndIf
			
			ElseIf(!cmpstr(controlName,"waveListBox"))
				Wave/T listWave = NTF:WavesLB_ListWave
				If(row > DimSize(listWave,0)-1)
					return 0
				EndIf
				
				String theFolder = GetDataFolder(1)
				list = theFolder + listWave[row][0][1] + ";"
			EndIf
			
			//Perform selected right click action
			doRightClickAction(command,list)
			
	endswitch
	return errorCode
End

//Performs one of the actions in the contextual right click menu
Function doRightClickAction(command,list)
	Variable command
	String list
	
	//which option was clicked?
	switch(command)
		case 1: //GoTo
			Variable i = 0
			
			//Browse to the selected wave
			ModifyBrowser collapseAll//close all folders first
			CreateBrowser //activates the data browser focus
			ModifyBrowser clearSelection,selectList=list //selects waves
			break
		case 2: //Edit
			GetWindow NT wsize
			Wave theWave = $StringFromList(0,list,";")
			
			If(!WaveExists(theWave))
				return 0
			EndIf
			
			Edit/W=(V_right,V_top,V_right + 200,V_top + 200) theWave
			
			break
		case 3: //Display
			GetWindow NT wsize
			
			Wave theWave = $StringFromList(0,list,";")
			
			If(!WaveExists(theWave))
				return 0
			EndIf
			
			If(WaveDims(theWave) == 1) //1D
				Display/W=(V_right,V_top,V_right + 390,V_top + 205)
				For(i=0;i<ItemsInList(list,";");i+=1)
					AppendToGraph $StringFromList(i,list,";")
				EndFor
				
			Else //2D
				NewImage/N=$NameOfWave(theWave) theWave
			EndIf
			break
	endswitch
	
	return 0
End

//Handles list box double clicks
Function HandleLBDoubleClick(lba)
	STRUCT WMListboxAction &lba
	Variable errorCode = 0
	DFREF NTF = root:Packages:NT
	
	strswitch(lba.ctrlName)
		case "matchListBox": //wave matches
			break
		case "dataSetWavesListBox": //data set waves
			break
		case "dataSetNamesListBox": //data set names
			break
		case "folderListBox":  //folder navigation
			Wave/T FolderLB_ListWave = NTF:FolderLB_ListWave
			If(lba.row < DimSize(FolderLB_ListWave,0))
				switchFolders(FolderLB_ListWave[lba.row])
			EndIf
			break
		case "waveListBox":	//waves navigation
			break
	endswitch
	return errorCode
End

//BUTTONS------------------------------------------------------------
Function ntButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			//Immediately open the data set name input upon mouse down
			If(!cmpstr(ba.ctrlName,"addDataSet"))
				//animate a text box opening under the button
				SetVariable dsNameInput win=NT,disable=0,activate,value=_STR:"NewDS"
				GroupBox dsNameGroupBox win=NT,disable=0
			EndIf
			
			If(HandleButtonClick(ba))
				print "BUTTON ERROR"
			EndIf
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

//Handles button clicks
Function HandleButtonClick(ba)
	STRUCT WMButtonAction &ba
	DFREF NTF = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	
	SVAR selectedCmd = NTF:selectedCmd
	
	Variable errorCode = 0
	strswitch(ba.ctrlName)
		case "CommandMenu":
			
			SVAR selectedCmd = NTF:selectedCmd
			PopUpContextualMenu/C=(456,59)/N "CommandMenu"
			
			String popStr = S_Selection
			Variable popNum = V_flag
			
			If(V_flag == 0 || V_flag == -1)
				break
			EndIf
			
			//If the selection was a break line in the menu
			If(cmpstr(popStr[0],"-") == 0)
				return 0
			EndIf
			
			//Switches the Command Menu label
			switchCommandMenu(popStr)
			
			//Switches the parameters according to the selected command
			switchControls(popStr,selectedCmd)
			
			//Switch the help message
			switchHelpMessage(popStr)
			
			break
		case "WaveListSelector":
			NVAR foldStatus = NTF:foldStatus
			//Prevents weird bug where the Wave Selector menu opens even though parameter panel is closed
			If(!foldStatus)
				break
			EndIf
			
			PopUpContextualMenu/C=(507,95)/N "WaveListSelectorMenu"
			
			popStr = S_Selection
			popNum = V_flag
			
			If(V_flag == 0 || V_flag == -1)
				break
			EndIf
	
			//Switches the menu text, center aligned
			switchWaveListSelectorMenu(popStr)
			
			//auto loads the selected data set into the Data Set waves list box
			If(cmpstr(popStr,"Wave Match") && cmpstr(popStr,"Navigator"))
				Wave/T DSNamesLB_ListWave = NTD:DSNamesLB_ListWave
				ListBox DataSetNamesListBox win=NT,selRow=tableMatch(popStr,DSNamesLB_ListWave)
				changeDataSet(popStr)
			EndIf
			break
		case "extFuncPopUp":
			//external functions drop down menu selection
			SVAR selectedCmd = NTF:selectedCmd
			PopUpContextualMenu/C=(460,95)/N "ExternalFuncMenu"
			
			popStr = S_Selection
			popNum = V_flag
			
			If(V_flag == 0 || V_flag == -1)
				break
			EndIf
			
			SwitchExternalFunction(popStr)
			
			break
		case "RunCmd":
			RunCmd(selectedCmd)
			break
		case "scaleFactorUpdate":
			NVAR scaleFactor = root:Packages:NT:Settings:scaleFactor
			DoWindow/F/W=NT NT
			Variable dpi = ScreenResolution
			dpi = round(dpi * scaleFactor)
			String cmdStr = "SetIgorOption PanelResolution = 72"
			Execute cmdStr
		case "Reload":
			GetWindow NT wsize
			KillWindow/Z NT
			LoadNT(left=V_left,top=V_top)
			break
		case "Back":
			navigateBack()
			break
		case "NT_Settings":
			openSettingsPanel()
			break
		case "addDataSet":
			//adds a new data set with the contents of the WaveMatch list box
			SVAR dsNameInput = NTD:dsNameInput
			dsNameInput = ""
			
			//Hide the update and delete data set controls
			Button delDataSet win=NT,disable=1
			Button updateDataSet win=NT,disable=1	
			
			//Wait for user to enter the data set name on mouse up
			Do
				PauseForUser/C NT
			While(!strlen(dsNameInput))
			
			If(addDataSet(dsNameInput))
				print "ADD DATA SET ERROR"
			EndIf
			
			//close the text box
			SetVariable dsNameInput win=NT,disable=1
			GroupBox dsNameGroupBox win=NT,disable=1
			
			//Show the update and delete data set controls
			Button delDataSet win=NT,disable=0
			Button updateDataSet win=NT,disable=0
			break
		case "delDataSet":
			//Deletes a data set
			Wave/T DSNamesLB_ListWave = NTD:DSNamesLB_ListWave
			
			//No data sets exist to be deleted
			If(DimSize(DSNamesLB_ListWave,0) == 0)
				return 0
			EndIf
			
			String dsName = GetDSName()
			
			If(deleteDataSet(dsName))
				print "DELETE DATA SET ERROR"
			EndIf
			
			break
		case "updateDataSet":
			//Updates the selected data set with the contents of the WaveMatch list box
			Wave/T DSNamesLB_ListWave = NTD:DSNamesLB_ListWave
			
			//No data sets exist to be deleted
			If(DimSize(DSNamesLB_ListWave,0) == 0)
				return 0
			EndIf
			
			dsName = GetDSName()
			//Nothing selected
			If(!strlen(dsName))
				return 0
			EndIf
			
			If(updateDataSet(dsName))
				print "UPDATE DATA SET ERROR"
			EndIf
		
			break
		case "clearFilters":
			clearFilterControls()
			break
		case "appendCommand":
			appendCommandLineEntry()
			break
		case "clearCommand":
			clearCommandLineEntry()
			break
//		case "ntViewerButton":
			
//			break
		case "ntViewerAutoScaleButton":
			SetAxis/W=NT#ntViewerGraph/A
			break
		case "ntViewerSeparateVertButton":
			SeparateTraces("vert")
			break
		case "ntViewerSeparateHorizButton":
			SeparateTraces("horiz")
			break
		case "ntViewerDisplayTracesButton":
			String theTraces = TraceNameList("NT#ntViewerGraph",";",1)
	
			GetWindow/Z NT wsize
			//Duplicates the Viewer graph outside of the viewer
			String winRec = WinRecreation("NT#ntViewerGraph",0)
			
			Variable pos1 = strsearch(winRec,"/W",0)
			Variable pos2 = strsearch(winRec,"/FG",0) - 1
			
			String matchStr = winRec[pos1,pos2]
			winRec = ReplaceString(matchStr,winRec,"/W=(" + num2str(V_right+10) + "," + num2str(V_top) + "," + num2str(V_right+360) + "," + num2str(V_top+200) + ")")
			winRec = ReplaceString("/FG=(FL,VT,FR,VB)/HOST=#",winRec,"")
			Execute/Q/Z winRec
			break
		case "ntViewerClearTracesButton":
			clearTraces()
			NVAR areHorizSeparated = NTF:areHorizSeparated
			NVAR areVertSeparated = NTF:areVertSeparated
			areHorizSeparated = 0
			areVertSeparated = 0
			break
	endswitch
	return errorCode
End

//SET VARIABLES------------------------------------------------------------

Function ntSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	STRUCT filters filters
	
	DFREF NTF = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	SVAR listFocus = NTF:listFocus
	
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
					If(!cmpstr(listFocus,"DataSet"))
						saveFilterSettings("DataSet")
					EndIf
					
					//Don't want to recall the old WaveMatch here, since we've just edited it.
					changeFocus("WaveMatch",0)
					
				case "waveGrouping":
				case "prefixGroup":
				case "groupGroup":
				case "seriesGroup":
				case "sweepGroup":
				case "traceGroup":					
					//Builds the match list according to all search terms, groupings, and filters
					getWaveMatchList()
					
					//display the full path to the wave in a text box
					drawFullPathText()
					
					break
				case "dsNameInput":
					SVAR dsNameInput = NTD:dsNameInput
					dsNameInput = sval
					break
				case "cmdLineStr":
					SVAR masterCmdLineStr = NTF:masterCmdLineStr
					NVAR editingMasterCmdLineStr = NTF:editingMasterCmdLineStr
					
					//break if not in editing mode
					If(editingMasterCmdLineStr == -1)
						break
					EndIf
					
					//If we're in editing mode
					//Replace the specified entry
					masterCmdLineStr = ReplaceListItem(editingMasterCmdLineStr,masterCmdLineStr,";/;",sval)
					
					//ensure that the correct separator is on the end
					masterCmdLineStr = RemoveEnding(masterCmdLineStr,";/;") + ";/;"
					
					//Redraw the command list entries
					DrawMasterCmdLineEntry()
					
					//reset the editing mode
					editingMasterCmdLineStr = -1
					break
			endswitch
		case 3: // Live update
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

//Handles variable, string, and wave inputs to external function parameter inputs
Function ntExtParamProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	DFREF NTF = root:Packages:NT
	
	//holds the parameters of the external functions
	Wave/T param = NTF:ExtFunc_Parameters
	
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
			Variable dval = sva.dval
			String sval = sva.sval
			
			String name = sva.ctrlName
			Variable paramIndex = ExtFuncParamIndex(name)
			
			
			String func = CurrentExtFunc()
			String type = getParam("PARAM_" + num2str(paramIndex) + "_TYPE",func)
			
			strswitch(type)
				case "4"://variable
					setParam("PARAM_" + num2str(paramIndex) + "_VALUE",func,num2str(dval))
					break
				case "8192"://string
					setParam("PARAM_" + num2str(paramIndex) + "_VALUE",func,sval)
					break
				case "16386"://wave
					setParam("PARAM_" + num2str(paramIndex) + "_VALUE",func,sval)
					//confirm validity of the wave reference
					validWaveText("",0,deleteText=1)
					ControlInfo/W=NT $sva.ctrlName
					validWaveText(sval,V_top+13)
					break
			endswitch
		case 3: // Live update
			
			break
		case -1: // control being killed
			break
	endswitch	
	return 0
End

//POP UP MENUS---------------------------
Function ntPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			
			strswitch(pa.ctrlName)
				case "WaveListSelector":
					break
			endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function ntExtParamPopProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			
			//Set the value of the external function parameter
			DFREF NTF = root:Packages:NT
			Wave/T param = NTF:ExtFunc_Parameters
			
			String func = CurrentExtFunc()
			Variable index = ExtFuncParamIndex(pa.ctrlName)
			
			setParam("PARAM_" + num2str(index) + "_VALUE",func,popStr)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


//CUSTOM HOOK FUNCTIONS------------------------------------------------------------

//Hook function to initiate animated fold or unfold of the parameter panel
//Triggers the hook if the mouse is clicked on the vertical thick divider in the GUI
Function foldParametersHook(s)
	STRUCT WMWinHookStruct &s
	DFREF NTF = root:Packages:NT
	NVAR foldStatus = NTF:foldStatus
	
	Variable hookResult = 0
	
	switch(s.eventCode)
		case 0:
			//handle activate
			break
		case 1: 
			//handle deactivate
			break
		case 3:
			//handle mouse down
			
			//Extract the current size of the parameter panel from here
			//We'll need to shift the right-side mouse click area according to the selected command
			Wave/T controlAssignments = NTF:controlAssignments
			SVAR selectedCmd = NTF:selectedCmd
			Variable index = tableMatch(selectedCmd,controlAssignments)
			
			If(index != -1) 
				Variable rightEdge = str2num(controlAssignments[index][2])
			Else
				rightEdge = 210
			EndIf
		
			
			//Check mouse position
			GetMouse/W=NT
			If(V_left > 442 && V_left < 454 && V_top <= 510)
				If(foldStatus)
					closeParameterFold()
					foldStatus = 0
				Else
					openParameterFold(size=rightEdge)
					foldStatus = 1
				EndIf
				
			//checks right boundary as well for when the panel is open
			ElseIf(V_left > (448 + rightEdge-6) && V_left < (448 + rightEdge+6) && V_top <= 510 && foldStatus) 
				closeParameterFold()
				foldStatus = 0
				
			//mouse hook for toggling the listbox focus	
			ElseIf(V_left > 0 && V_left < 182 && V_top > 99 && V_top < 123) //Wave Match Click
				changeFocus("WaveMatch",1)
			ElseIf(V_left > 182 && V_left < 438 && V_top > 99 && V_top < 123) //Data Set Click
				changeFocus("DataSet",1)
			ElseIf(V_left < 58 && V_top > 469 && V_top < 486)//Grouping Click
				PopUpContextualMenu/C=(10,486)/N "GroupingMenu"
				
				String popStr = S_Selection
				Variable popNum = V_flag
				
				If(V_flag == 0 || V_flag == -1)
					break
				EndIf
				
				popStr = TrimString(StringFromList(0,popStr,"("))
				
				appendGroupSelection(popStr)
			ElseIf(V_left < 446 && V_top > 505 && V_top < 515)
				NVAR viewerOpen = NTF:viewerOpen
			
				If(!viewerOpen) 
					openViewer()
					viewerOpen = 1
				Else
					closeViewer()
					viewerOpen = 0
				EndIf		
			EndIf	
			break
	endswitch

	return hookResult
End

//Opens the parameter infold opening
Function openParameterFold([size])
	Variable size
	
	DFREF NTF =  root:Packages:NT:
	SVAR listFocus = NTF:listFocus
	
	NVAR ppr = root:Packages:NT:Settings:ppr//pixel shift per refresh; can adjust Settings panel
	
	If(ParamIsDefault(size))
		size = 210
	EndIf
	
	//Show the command menu and run button
	Button CommandMenu win=NT,disable=0
	Button RunCmd win=NT,disable=0
		
	//expand group box first
	GroupBox parameterBox win=NT,pos={455,69},size={size-13,437}
	
	//shift text label
	SetDrawEnv/W=NT  fstyle= 0
	DrawAction/W=NT delete,getgroup=parameterText
	SetDrawEnv/W=NT xcoord= abs,ycoord= abs, fsize=14, textrgb= (0,0,0), textxjust= 1,textyjust= 1,fname=$LIGHT,gstart,gname=parameterText
	DrawText/W=NT 455+(size/2)-6,15,"Parameters"
	SetDrawEnv/W=NT gstop
	
	//Draw the help message
	SVAR selectedCmd = NTF:selectedCmd	
	switchHelpMessage(selectedCmd)
	
	Do
		Variable i
	
		//Get original window coordinates
		GetWindow NT wsize
		Variable left,top,right,bottom
		left = V_left;right=V_right;top=V_top;bottom=V_bottom
		Variable expansion = (right - left) - 754 //current expansion relative to original width of the panel
		
		If(expansion >= size)
			break
		EndIf
		
		Variable pixelsLeft = size - expansion
		If(pixelsLeft < ppr)
			MoveWindow/W=NT left,top,right+pixelsLeft,bottom;DelayUpdate
			Variable shift = size
		Else
			//Extend right edge of the panel to make room
			MoveWindow/W=NT left,top,right+ppr,bottom;DelayUpdate
			shift = expansion + ppr
		EndIf
				
		//Shift the right line
		SetDrawEnv/W=NT  fstyle= 0
		DrawAction/W=NT delete,getgroup=rightLine
		SetDrawEnv/W=NT xcoord= abs,ycoord= abs,linefgc= (0,0,0,16384),linethick= 4,gname=rightLine,gstart
		DrawLine/W=NT 448 + shift,0, 448 + shift,515;DelayUpdate
		SetDrawEnv/W=NT gstop
		
		DoUpdate/W=NT
	While(expansion <= size)
	
	//Special case enabling and disabling
	strswitch(selectedCmd)
		case "Run Cmd Line":
		case "New Data Folder":
		case "Kill Data Folder":
		case "External Function":
			Button WaveListSelector win=NT,disable=3
			
			BuildExtFuncControls(CurrentExtFunc())
			
			break
		case "Get ROI":
			ListBox ROIListBox win=NT,disable=0
		case "dF Map":
			ListBox ScanListBox win=NT,disable=0
			Button WaveListSelector win=NT,disable=3
			break
		default:
			Button WaveListSelector win=NT,disable=0
			break
	endswitch
	
End

//Closes the parameter infold
Function closeParameterFold([size])
	Variable size
	DFREF NTF =  root:Packages:NT:
	
	NVAR ppr = root:Packages:NT:Settings:ppr //pixel shift per refresh; can adjust in Settings panel
	
	SVAR selectedCmd = NTF:selectedCmd	
		
	If(ParamIsDefault(size))
		size = 0
		
		//hide the command menu, run cmd button, and ROIListBox on full closure
		Button CommandMenu win=NT,disable=3
		Button RunCmd win=NT,disable=3
		ListBox ROIListBox win=NT,disable=3
		ListBox ScanListBox win=NT,disable=3
		
		If(!cmpstr(selectedCmd,"Get ROI"))
			ListBox ROIListBox win=NT,disable=3
		EndIf
	Else
		//shift text label if there is a non-zero size
		SetDrawEnv/W=NT  fstyle= 0
		DrawAction/W=NT delete,getgroup=parameterText
		SetDrawEnv/W=NT xcoord= abs,ycoord= abs, textrgb= (0,0,0), fsize=14, textxjust= 1,textyjust= 1,fname=$LIGHT,gstart,gname=parameterText
		DrawText/W=NT 455+(size/2)-6,15,"Parameters"
		SetDrawEnv/W=NT gstop	
	EndIf
	
	//hide the list selector menu unless the command is 'Run Cmd Line', in which case it is hidden
	If(cmpstr(selectedCmd,"Run Cmd Line") || cmpstr(selectedCmd,"New Data Folder") || cmpstr(selectedCmd,"Kill Data Folder") || cmpstr(selectedCmd,"External Function"))
		Button WaveListSelector win=NT,disable=3
	Else
		Button WaveListSelector win=NT,disable=0
	EndIf
	
	//Erase the help message
	switchHelpMessage("")
	
	Do
		Variable i
		
		//Get original window coordinates
		GetWindow NT wsize
		Variable left,top,right,bottom
		left = V_left;right=V_right;top=V_top;bottom=V_bottom
		Variable expansion = (right - left) - 754 //current expansion relative to original width of the panel
		
		If(expansion <= size)
			break
		EndIf
		
		Variable pixelsLeft = expansion - size
		If(pixelsLeft < ppr)
			MoveWindow/W=NT left,top,right-pixelsLeft,bottom;DelayUpdate
			Variable shift = size
		Else
			//Extend right edge of the panel to make room
			MoveWindow/W=NT left,top,right-ppr,bottom;DelayUpdate
			shift = expansion - ppr
		EndIf

		//Shift the right line
		SetDrawEnv/W=NT  fstyle= 0
		DrawAction/W=NT delete,getgroup=rightLine
		SetDrawEnv/W=NT xcoord= abs,ycoord= rel,textxjust= 1,textyjust= 1,linefgc= (0,0,0,16384),linethick= 4,gname=rightLine,gstart
		DrawLine/W=NT 448 + shift,0, 448 + shift,1;DelayUpdate
		SetDrawEnv/W=NT gstop,textxjust= 1,textyjust= 1

		DoUpdate/W=NT
	While(expansion > size )
	
	//delete midline after animation
	If(!size)
		DrawAction/W=NT delete,getgroup=rightLine
	EndIf
	
	//expand group box first
	If(size > 13)
		GroupBox parameterBox win=NT,pos={455,69},size={size-13,437}
	EndIf
	
End

//Allows user to click on command line entries while using 'Run Cmd Line'
// and selectively delete and edit entries
Function cmdLineEntryHook(s)
	STRUCT WMWinHookStruct &s
	DFREF NTF = root:Packages:NT
	NVAR foldStatus = NTF:foldStatus
	
	Variable hookResult = 0
	
	switch(s.eventCode)
		case 0:
			//handle activate
			break
		case 1: 
			//handle deactivate
			break
		case 3:
			//handle mouse down
			SVAR masterCmdLineStr = NTF:masterCmdLineStr

			If(s.eventMod == 17) //right click
				Variable numEntries = ItemsInList(masterCmdLineStr,";/;")
				GetMouse/W=NT
				
				Variable selection = whichCmdLineEntry(V_left,V_top,numEntries)
				
				//NaN, no valid selection
				If(numtype(selection) == 2)
					//Reset selection drawing
					DrawAction/W=NT getgroup=cmdEntrySelection,delete
					return 0
				EndIf
				
				PopupContextualMenu/C=(V_left,V_top) "Edit;Delete;"
				
					
				String popStr = S_Selection
				Variable popNum = V_flag
				
				If(V_flag == 0 || V_flag == -1)
					break
				EndIf
				
				//If the selection was a break line in the menu
				If(cmpstr(popStr[0],"-") == 0)
					//Reset selection drawing
					DrawAction/W=NT getgroup=cmdEntrySelection,delete
					return 0
				EndIf
				
				strswitch(popStr)
					case "Edit":
						EditCmdLineEntry(selection)
						break
					case "Delete":
						DeleteCmdLineEntry(selection)
						break
				endswitch
				
				//Reset selection drawing
				DrawAction/W=NT getgroup=cmdEntrySelection,delete
	
				hookResult = 1
			EndIf
			
			break
	endswitch
	return hookResult
End

//Figures out which command line entry was clicked on
//Draws a selection indicator
Function whichCmdLineEntry(left,top,num)
	Variable left,top,num
	
	Variable yPos = 144
	
	//Reset selection drawing
	DrawAction/W=NT getgroup=cmdEntrySelection,delete
	
	If(left > 455 && left < 624) 
		If(top > yPos && top < yPos + 20 && num > 0)
			SetDrawEnv linefgc= (3,52428,1),linethick= 3.00,xcoord=abs,ycoord=abs,gname=cmdEntrySelection,gstart
			DrawLine/W=NT 458,yPos,458,yPos+20
			SetDrawEnv gstop
			return 0
		ElseIf(top > yPos + 20 && top < yPos + 40 && num > 1)
			SetDrawEnv linefgc= (3,52428,1),linethick= 3.00,xcoord=abs,ycoord=abs,gname=cmdEntrySelection,gstart
			DrawLine/W=NT 458,yPos+20,458,yPos+40
			SetDrawEnv gstop
			return 1
		ElseIf(top > yPos + 40 && top < yPos + 60 && num > 2)
			SetDrawEnv linefgc= (3,52428,1),linethick= 3.00,xcoord=abs,ycoord=abs,gname=cmdEntrySelection,gstart
			DrawLine/W=NT 458,yPos+40,458,yPos+60
			SetDrawEnv gstop
			return 2
		ElseIf(top > yPos + 60 && top < yPos + 80 && num > 3)
			SetDrawEnv linefgc= (3,52428,1),linethick= 3.00,xcoord=abs,ycoord=abs,gname=cmdEntrySelection,gstart
			DrawLine/W=NT 458,yPos+60,458,yPos+80
			SetDrawEnv gstop
			return 3
		ElseIf(top > yPos + 80 && top < yPos + 100 && num > 4)
			SetDrawEnv linefgc= (3,52428,1),linethick= 3.00,xcoord=abs,ycoord=abs,gname=cmdEntrySelection,gstart
			DrawLine/W=NT 458,yPos+80,458,yPos+100
			SetDrawEnv gstop
			return 4
		ElseIf(top > yPos + 100 && top < yPos + 120 && num > 5)
			SetDrawEnv linefgc= (3,52428,1),linethick= 3.00,xcoord=abs,ycoord=abs,gname=cmdEntrySelection,gstart
			DrawLine/W=NT 458,yPos+100,458,yPos+120
			SetDrawEnv gstop
			return 5
		ElseIf(top > yPos + 120 && top < yPos + 140 && num > 6)
			SetDrawEnv linefgc= (3,52428,1),linethick= 3.00,xcoord=abs,ycoord=abs,gname=cmdEntrySelection,gstart
			DrawLine/W=NT 458,yPos+120,458,yPos+140
			SetDrawEnv gstop
			return 6
		ElseIf(top > yPos + 140 && top < yPos + 160 && num > 7)
			SetDrawEnv linefgc= (3,52428,1),linethick= 3.00,xcoord=abs,ycoord=abs,gname=cmdEntrySelection,gstart
			DrawLine/W=NT 458,yPos+140,458,yPos+160
			SetDrawEnv gstop
			return 7
		ElseIf(top > yPos + 160 && top < yPos + 180 && num > 8)
			SetDrawEnv linefgc= (3,52428,1),linethick= 3.00,xcoord=abs,ycoord=abs,gname=cmdEntrySelection,gstart
			DrawLine/W=NT 458,yPos+160,458,yPos+180
			SetDrawEnv gstop
			return 8
		ElseIf(top > yPos + 180 && top < yPos + 200 && num > 9)
			SetDrawEnv linefgc= (3,52428,1),linethick= 3.00,xcoord=abs,ycoord=abs,gname=cmdEntrySelection,gstart
			DrawLine/W=NT 458,yPos+180,458,yPos+200
			SetDrawEnv gstop
			return 9
		ElseIf(top > yPos + 200 && top < yPos + 220 && num > 10)
			SetDrawEnv linefgc= (3,52428,1),linethick= 3.00,xcoord=abs,ycoord=abs,gname=cmdEntrySelection,gstart
			DrawLine/W=NT 458,yPos+200,458,yPos+220
			SetDrawEnv gstop
			return 10
		EndIf
	EndIf
End

//Deletes a specific command from the master command line entry, redraws
Function DeleteCmdLineEntry(selection)
	Variable selection
	
	DFREF NTF = root:Packages:NT
	SVAR masterCmdLineStr = NTF:masterCmdLineStr
	
	masterCmdLineStr = RemoveListItem(selection,masterCmdLineStr,";/;")
	DrawMasterCmdLineEntry()
End

Function EditCmdLineEntry(selection)
	Variable selection
	
	DFREF NTF = root:Packages:NT
	SVAR masterCmdLineStr = NTF:masterCmdLineStr
	NVAR editingMasterCmdLineStr = NTF:editingMasterCmdLineStr
	
	//Pull the entry into the editing box
	SetVariable cmdLineStr win=NT,value=_STR:StringFromList(selection,masterCmdLineStr,";/;"),activate
	
	
	//Set editing details
	editingMasterCmdLineStr = selection
End

//SHORTCUTS-----------------------------------------------------------

//Function/S handleShortcut()
	DFREF NTF = root:Packages:NT
	DFREF NTD = root:Packages:NT:DataSets
	
	//Get the activated shortcut
	GetLastUserMenuInfo
	
	Wave/T shortCuts = NTF:shortCuts
	SVAR selectedCmd = NTF:selectedCmd
	SVAR prevCmd = NTF:prevCmd
	
	String theFunction = shortCuts[str2num(S_Value)-1][1]
	
	//Make sure we're in the function tab
	NVAR currentTab = NTF:currentTab
	
	//special case for Data Sets, need a tab switch, not a function switch
	If(!cmpstr(theFunction,"Data Sets"))
		TabControl tabMenu win=analysis_tools,value=0
		switchTabs(0)
		currentTab = 0
		return ""
	EndIf

	If(currentTab == 0)
		TabControl tabMenu win=analysis_tools,value=1
		switchTabs(1)
		currentTab = 1
	EndIf
	
	//kill previous text in the panel
	DrawAction/W=NTF delete
	
	prevCmd = selectedCmd
	selectedCmd = theFunction
	ChangeControls(selectedCmd,prevCmd)
	
	//Refresh external function page when it opens
	If(cmpstr(selectedCmd,"External Function") == 0)
		CheckExternalFunctionControls(selectedCmd)
	Else
		strswitch(selectedCmd)
			case "Apply Map Threshold":
			case "Denoise":
			case "Average":
			case "Mask Image":
			case "Dynamic ROI":
			case "Error":
			case "Move To Folder":
			case "Kill Waves":
			case "Run Cmd Line":
			case "Duplicate Rename":
				Wave/T DSNamesLB_ListWave = NTF:DSNamesLB_ListWave
				SVAR DSNames = NTD:DSNames
				DSNames = "--None--;--Scan List--;--Item List--;" + textWaveToStringList(DSNamesLB_ListWave,";")		
				break
		endswitch
	EndIf
	
	Button AT_CommandPop win=analysis_tools,title = "\\JL▼    " + selectedCmd
	DrawText/W=NT 15,53,"Commands:"
	ControlInfo/W=NT CommandMenu
						
	If(!cmpstr(selectedCmd,"External Function"))
		DrawText/W=NT 23,84,"Functions:"
	EndIf

End






