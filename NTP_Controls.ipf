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
	
	DFREF NPD = $DSF
	DFREF NPC = $CW
	
	NVAR dragging = NPC:dragging
	SVAR listFocus = NPC:listFocus
	
	Variable hookResult = 0
	
	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			//set a potential drag variable
			
			If(!cmpstr(lba.ctrlName,"waveListBox"))
				dragging = 1
				//freeze selection

			EndIf
			
			break
		case 2: // mouse up
			//display the full path to the wave in a text box
			
			//reset the drag and drop variable on a mouse up
			dragging = 0
			
//			If(row > DimSize(selWave,0) - 1 || row == -1)
//				break
//			EndIf
//			
//			strswitch(lba.ctrlName)
//				case "MatchListBox":
//				case "DataSetWavesListBox":
//					DrawAction/W=NTP getGroup=fullPathText,delete
//					SetDrawEnv/W=NTP fname=$LIGHT,fstyle=2,fsize=10,xcoord=abs,ycoord=abs, textxjust= 0,gname=fullPathText,gstart
//					DrawText/W=NTP 14,464,listWave[row][0][1]
//					SetDrawEnv/W=NTP gstop
//					break
//			endswitch
					
			//change focus for the list box selection
			strswitch(lba.ctrlName)
				case "matchListBox": //wave matches
					
					AppendToViewer(listWave,selWave)
					
					//out of range selection
					If(row > DimSize(listWave,0) - 1)
						//change the list box focus still
						changeFocus("WaveMatch",1)
						
						//Delete full path wave text
						DrawAction/W=NTP getGroup=fullPathText,delete
						return 0
					EndIf
									
					//change the list box focus
					If(!cmpstr(listFocus,"DataSet"))
						changeFocus("WaveMatch",1)
					EndIf
							
					break
				case "dataSetWavesListBox": //data set waves
					//out of range selection
					
					AppendToViewer(listWave,selWave)
					
					If(row > DimSize(listWave,0) - 1)
						//change the list box focus still
						changeFocus("DataSet",1)
					
						//Delete full path wave text
						DrawAction/W=NTP getGroup=fullPathText,delete
						
						return 0
					EndIf
					
					//change the list box focus
					If(!cmpstr(listFocus,"WaveMatch"))
						changeFocus("DataSet",1)
					EndIf

					drawFullPathText()
		
					break
			endswitch
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
			If(HandleLBSelection(lba.ctrlName,listWave,row,lba.mouseLoc.h,lba.mouseLoc.v,lba.eventMod))
				print "SELECTION CHANGE ERROR"
			EndIf
			
			//Only selection updates for keyboard triggered selections
			If(lba.eventMod == 0)
				If(!cmpstr(lba.ctrlName,"MatchListBox") || !cmpstr(lba.ctrlName,"DataSetWavesListBox"))
					DrawAction/W=NTP getGroup=fullPathText,delete
					SetDrawEnv/W=NTP fname=$LIGHT,fstyle=2,fsize=10,xcoord=abs,ycoord=abs,textxjust= 0,gname=fullPathText,gstart
					DrawText/W=NTP 14,464,listWave[row][0][1]
					SetDrawEnv/W=NTP gstop
				EndIf
				
				AppendToViewer(listWave,selWave)
				
			EndIf
			break
		case 6: // begin edit
		
			break
		case 7: // finish edit
			break
		case 12: //keyboard
		
			If(!cmpstr(lba.ctrlName,"DataSetNamesListBox"))
				hookResult = 1
				return hookResult
			EndIf
			
			//Detect ASCII for 'w' or 'q' 
			//'q' jumps to previous waveset
			//'w' jumpts to next waveset
			Variable i
			If(row == 113 || row == 81)
				//JUMP TO PREVIOUS WAVE SET
				
				//Find the first row that is selected, and find the first wave set before or after that
				If(sum(lba.selWave) > 0)
					For(i=0; i < DimSize(lba.selWave,0); i+= 1)
						If(lba.selWave[i] > 0)
							
							If(row == 119 || row == 87) 	//w
								Variable index = i + 1
							ElseIf(row == 113|| row == 81) //q
								index = i - 1
							EndIf
							break
						EndIf
					EndFor
				Else
					index = 0
				EndIf			
			
				If(row == 113) // no shift, erase other selection
					lba.selWave = 0
				EndIf
				
				//Find the surrounding wave set
				For(i=index;i>-1;i-=1)
					If(stringmatch(lba.listWave[i][0][0],"*WAVE SET*")) 
						lba.selWave[i] = 1
						break
					EndIf
				EndFor
				
			ElseIf(row == 119 || row == 87)
				//JUMP TO NEXT WAVE SET
				
				//Find the last row that is selected, and find the first wave set after that
				If(sum(lba.selWave) > 0)
					For(i=DimSize(lba.selWave,0) - 1; i > - 1; i-= 1)
						If(lba.selWave[i] > 0)	
							If(row == 119 || row == 87) 	//w
								index = i + 1
							EndIf
							break
						EndIf
					EndFor
				Else
					index = 0
				EndIf			
						
				If(row == 119) // no shift
					lba.selWave = 0
				EndIf
									
				//Find the surrounding wave set
				For(i=index;i<DimSize(lba.selWave,0);i+=1)
					If(stringmatch(lba.listWave[i][0][0],"*WAVE SET*")) 
						lba.selWave[i] = 1
						break
					EndIf
				EndFor
							
			EndIf
			
			ListBox $lba.ctrlName win=NTP#Data,row=i
			
			If(HandleLBSelection(lba.ctrlName,listWave,i,lba.mouseLoc.h,lba.mouseLoc.v,lba.eventMod))
				print "SELECTION CHANGE ERROR"
			EndIf

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
	DFREF NPC = $CW
	DFREF NPD = $DSF
	
	SVAR listFocus = NPC:listFocus
	
	strswitch(ctrlName)
		case "matchListBox": //wave matches
			Wave/T MatchLB_ListWave = NPC:MatchLB_ListWave
			Wave MatchLB_SelWave = NPC:MatchLB_SelWave
			
			//out of range selection
			If(row > DimSize(listWave,0) - 1)
				//change the list box focus still
				changeFocus("WaveMatch",1)
				
				//Delete full path wave text
				DrawAction/W=NTP getGroup=fullPathText,delete
				return 0
			EndIf
			
			If(eventMod == 16 || eventMod == 17)
				//GOTO selected wave contextual menu
				PopupContextualMenu/C=(mouseHor, mouseVert) "GoTo;Edit;Delete;Display;"
				If(V_flag)
					HandleRightClick("matchListBox",V_flag,row=row)
				EndIf
			EndIf
			
			//change the list box focus
			If(!cmpstr(listFocus,"DataSet"))
				changeFocus("WaveMatch",1)
			EndIf
					
//			NVAR viewerOpen = NPC:viewerOpen
//			If(viewerOpen)
			If(eventMod == 0)
				AppendToViewer(MatchLB_ListWave,MatchLB_SelWave)
			EndIf
					
			break
		case "dataSetWavesListBox": //data set waves
			//out of range selection
			If(row > DimSize(listWave,0) - 1)
				//change the list box focus still
				changeFocus("DataSet",1)
			
				//Delete full path wave text
				DrawAction/W=NTP getGroup=fullPathText,delete
				
				return 0
			EndIf
			
			If(eventMod == 16 || eventMod == 17)
				//GOTO selected wave contextual menu
				PopupContextualMenu/C=(mouseHor, mouseVert) "GoTo;Edit;Delete;Display;"
				If(V_flag)
					HandleRightClick("dataSetWavesListBox",V_flag,row=row)
				EndIf
			EndIf
			
			//change the list box focus
			If(!cmpstr(listFocus,"WaveMatch"))
				changeFocus("DataSet",1)
			EndIf
					
			//display the full path to the wave in a text box
			Wave/T DataSetLB_ListWave = NPD:DataSetLB_ListWave
			Wave DataSetLB_SelWave = NPD:DataSetLB_SelWave
			
			
//			NVAR viewerOpen = NPC:viewerOpen
			If(eventMod == 0)
				AppendToViewer(MatchLB_ListWave,MatchLB_SelWave)
			EndIf

			
			break
		case "dataSetNamesListBox": //data set names
						
			If(eventMod == 16 || eventMod == 17)
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
			
			If(eventMod == 16 || eventMod == 17)
				//GOTO selected wave contextual menu
				PopupContextualMenu/C=(mouseHor, mouseVert) "GoTo;"
				If(V_flag)
					HandleRightClick("folderListBox",V_flag,row=row)
				EndIf
			EndIf
			break
		case "waveListBox":	//waves navigation
			Wave/T WavesLB_ListWave = NPC:WavesLB_ListWave
			Wave WavesLB_SelWave = NPC:WavesLB_SelWave
			
			//out of range selection
			If(row > DimSize(listWave,0) - 1)
				return 0
			EndIf
			
			If(eventMod == 16 || eventMod == 17)
				//GOTO selected wave contextual menu
				PopupContextualMenu/C=(mouseHor, mouseVert) "GoTo;Edit;Delete;Display;"
				If(V_flag)
					HandleRightClick("waveListBox",V_flag,row=row)
				EndIf
			EndIf
			
//			NVAR viewerOpen = NPC:viewerOpen
//			If(viewerOpen)
//				AppendToViewer(WavesLB_ListWave,WavesLB_SelWave)
//			EndIf
			
			break
		case "fileListBox":
			//browse files on disk for wavesurfer or pclamp loading
			Variable fileID
			
			SVAR wsFilePath = NPC:wsFilePath
			SVAR wsFileName = NPC:wsFileName
			
			If(row > DimSize(listWave,0) -1)
				return 0
			EndIf
			
			wsFileName = listWave[row]
			String fullPath = wsFilePath + wsFileName
			
			//What file type are we opening?
			ControlInfo/W=NTP fileType
			String fileType = S_Value
			
			strswitch(fileType)
				case "WaveSurfer":
					HDF5OpenFile/R fileID as fullPath
			
					If(V_flag == -1) //cancelled
						break
					EndIf
					
					//Save the path and filename
					wsFilePath = S_path
					wsFileName = S_fileName
					
					UpdateWaveSurferLists(fileID,wsFilePath,wsFileName)
					
					GetStimulusData(fileID)

					HDF5CloseFile/A fileID
					break
				case "PClamp":
//					Variable refnum
//					fullPath = RemoveEnding(fullPath,".abf") + ".abf"
//					Open/R/Z=2 refnum as fullPath
//
//					fSetPos refnum,12
//					
//					Variable numSweeps = 0					
//					FBInRead/B=3/F=3/U refnum,numSweeps
//					
//					Wave/T wsSweepListWave = NPC:wsSweepListWave
//					Redimension/N=(numSweeps) wsSweepListWave
//					
//					Variable i
//					For(i=0;i<numSweeps;i+=1)
//						wsSweepListWave[i] = "Sweep " + num2str(i + 1)
//					EndFor
//					
//					Close refnum
					break
				case "Presentinator":
					break
			endswitch
			break
	endswitch
	return errorCode
End

//Handles list box right clicks
Function HandleRightClick(controlName,command,[row])
	String controlName
	Variable command,row
	DFREF NPC = $CW
	DFREF NPD = $DSF
	
	STRUCT filters filters
	SVAR listFocus = NPC:listFocus
	
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
			
			Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
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
			Wave/T FolderLB_ListWave = NPC:FolderLB_ListWave
			Wave/T FolderLB_SelWave = NPC:FolderLB_SelWave
			SVAR cdf = NPC:cdf
			
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
				Wave/T listWave = NPC:MatchLB_ListWave
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
				Wave/T listWave = NPC:WavesLB_ListWave
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
			GetWindow NTP#Data wsize
			Wave theWave = $StringFromList(0,list,";")
			
			If(!WaveExists(theWave))
				return 0
			EndIf
			
			If(!strlen(GetDimLabel(theWave,0,0)))
				Edit/K=1/W=(V_right,V_top,V_right + 200,V_top + 200) theWave
			Else
				Edit/K=1/W=(V_right,V_top,V_right + 200,V_top + 200) theWave.ld
			EndIf
			
			
			break
		case 3: //Delete
			Wave theWave = $StringFromList(0,list,";")
			DoAlert/T="Delete Wave" 1,"Are you sure you want to delete the wave: " + StringFromList(0,list,";") + "?"
			
			If(V_flag == 1)
				ReallyKillWaves(theWave)
			EndIf
			
			CheckDataSetWaves()
			
			GetFolders()
			GetFolderWaves()
			
			break
		case 4: //Display
			GetWindow NTP#Data wsize
			
			Wave theWave = $StringFromList(0,list,";")
			
			If(!WaveExists(theWave))
				return 0
			EndIf
			
			If(WaveType(theWave,1) != 1)
				break
			ElseIf(WaveDims(theWave) == 1) //1D
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
	DFREF NPC = $CW
	
	strswitch(lba.ctrlName)
		case "matchListBox": //wave matches
			break
		case "dataSetWavesListBox": //data set waves
			break
		case "dataSetNamesListBox": //data set names
			break
		case "folderListBox":  //folder navigation
			Wave/T FolderLB_ListWave = NPC:FolderLB_ListWave
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
	DFREF NPC = $CW
	DFREF NPD = $DSF
	
	SVAR selectedCmd = NPC:selectedCmd
	Wave/T param = NPC:ExtFunc_Parameters
	
	Variable errorCode = 0
	strswitch(ba.ctrlName)
		
		case "WaveListSelector":
			NVAR foldStatus = NPC:foldStatus
			//Prevents weird bug where the Wave Selector menu opens even though parameter panel is closed
			If(!foldStatus)
				break
			EndIf
			
			PopUpContextualMenu/C=(507,95)/N "WaveListSelectorMenu"
			
			String popStr = S_Selection
			Variable popNum = V_flag
			
			If(V_flag == 0 || V_flag == -1)
				break
			EndIf
	
			//Switches the menu text, center aligned
			switchWaveListSelectorMenu(popStr)
			
			//auto loads the selected data set into the Data Set waves list box
			strswitch(popStr)
				case "Wave Match":
				case "Navigator":
				case "Image Browser":
					break
				default:
					Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
					ListBox DataSetNamesListBox win=NTP#Data,selRow=tableMatch(popStr,DSNamesLB_ListWave)
					changeDataSet(popStr)
			endswitch
			break
		case "functionPopUp":
			//external functions drop down menu selection
			Wave/T param = NPC:ExtFunc_Parameters
			GetExternalFunctionData(param)
			
			BuildMenu "FunctionMenu"
			
			SVAR selectedCmd = NPC:selectedCmd
			PopUpContextualMenu/C=(20,62)/W=NTP#Func/N "FunctionMenu"
			
			popStr = S_Selection
			popNum = V_flag
			
			If(V_flag == 0 || V_flag == -1)
				break
			EndIf
			
			SwitchExternalFunction(popStr)
			String func = GetFunctionFromTitle(popStr)
			selectedCmd = func
			
			SVAR currentFunc = NPC:currentFunc
			currentFunc = selectedCmd
			break
		case "gotoFunc": //opens the procedure window of the current external function
			func = CurrentExtFunc()
			DisplayProcedure/W=NTP_ExternalFunctions func
			break
		case "funcNotes":
			func = CurrentExtFunc()
			String functionStr = ProcedureText(func,0)
			String funcNote = GetFunctionNote(functionStr)
			DisplayFunctionNote(func,funcNote)
			break
		case "measureType": //pop up menu for the Measure function 
			PopUpContextualMenu/C=(487,125)/N "MeasureTypeMenu"
			
			popStr = S_Selection
			popNum = V_flag
			
			If(V_flag == 0 || V_flag == -1)
				break
			EndIf
			
			//Calculates spacer to ensure centered text on the drop down menu
			String spacer = ""
			Variable cmdLen = strlen(popStr)
			cmdLen = 15 - cmdLen
			
			Do
				spacer += " "
				cmdLen -= 1
			While(cmdLen > 0)
			
			//switch the text on the button/drop down menu
			Button measureType win=NT,title="\\JL▼   " + spacer + popStr
			
			setupMeasureControls(popStr)
			
			break
		case "runFunc":
			RunCmd(selectedCmd)
			break
		case "scaleFactorUpdate":
			NVAR scaleFactor = root:Packages:NT:Settings:scaleFactor
			DoWindow/F/W=NTP NT
			Variable dpi = ScreenResolution
			dpi = round(dpi * scaleFactor)
			String cmdStr = "SetIgorOption PanelResolution = 72"
			Execute cmdStr
		case "Reload":
			GetWindow NTP wsize
			KillWindow/Z NTP
			LoadNeuroPlus()
			
			DoWindow SI
			If(V_flag)
				KillWindow/Z SI
				LoadScanImagePackage()
			EndIf
			break
		case "Back":
			folderBack()
			break
		case "NT_Settings":
//			openSettingsPanel()
			break
		case "addDataSet":
			//adds a new data set with the contents of the WaveMatch list box
			SVAR dsNameInput = NPD:dsNameInput
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
			Wave/T DSNamesLB_ListWave = NPD:DSNamesLB_ListWave
			
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
			SetAxis/W=NTP#Nav#Viewer/A
			break
//		case "ntViewerSeparateVertButton":
//			SeparateTraces("vert")
//			break
//		case "ntViewerSeparateHorizButton":
//			SeparateTraces("horiz")
//			break
		case "ntViewerDisplayTracesButton":
			String theTraces = TraceNameList("NTP#Nav#Viewer",";",1)
	
			GetWindow/Z NT wsize
			//Duplicates the Viewer graph outside of the viewer
			String winRec = WinRecreation("NTP#Nav#Viewer",0)
			
			Variable pos1 = strsearch(winRec,"/W",0)
			Variable pos2 = strsearch(winRec,"/FG",0) - 1
			
			String matchStr = winRec[pos1,pos2]
			winRec = ReplaceString(matchStr,winRec,"/W=(" + num2str(V_right+10) + "," + num2str(V_top) + "," + num2str(V_right+360) + "," + num2str(V_top+200) + ")")
			winRec = ReplaceString("/FG=(FL,VT,FR,VB)/HOST=#",winRec,"")
			Execute/Q/Z winRec
			break
		case "ntViewerClearTracesButton":
			clearTraces()
			NVAR areHorizSeparated = NPC:areHorizSeparated
			NVAR areVertSeparated = NPC:areVertSeparated
			areHorizSeparated = 0
			areVertSeparated = 0
			break
		case "BrowseFiles":
			//browse files on disk for wavesurfer loading
			Variable fileID
			
			SVAR wsFilePath = NPC:wsFilePath
			SVAR wsFileName = NPC:wsFileName
			
			//What file type are we opening?
			ControlInfo/W=NTP fileType
			String fileType = S_Value
			
			BrowseEphys(fileType)
			
//			strswitch(fileType)
//				case "Load WaveSurfer":
//					HDF5OpenFile/I/R fileID as "theWave"
//					
//					If(V_flag == -1) //cancelled
//						return 0
//					EndIf
//					
//					wsFilePath = S_path
//					wsFileName = S_fileName
//			
//					UpdateWaveSurferLists(fileID,wsFilePath,wsFileName)
//					
//					HDF5CloseFile/A fileID
//					break
//					
//				case "Load pClamp":	
//					Variable refnum
//					String message = "Select the data folder to index"
//					String fileFilters = "All Files:.*;"
//					Open/D/R/F=fileFilters/M=message refnum
//					
//					wsFilePath = ParseFilePath(1,S_fileName,":",1,0)
//					wsFileName = ParseFilePath(0,S_fileName,":",1,0)
//					Close/A
//					
//					String fullPath = wsFilePath
//					NewPath/O/Q/Z ABFpath,fullpath
//					String fileList = IndexedFile(ABFpath,-1,".abf")
//					fileList = SortList(fileList,";",16)
//					
//					fileList = ReplaceString(".abf",fileList,"")
//					
//					Wave/T wsFileListWave = NPC:wsFileListWave
//					Wave wsFileSelWave = NPC:wsFileSelWave
//					
//					Wave/T textWave = StringListToTextWave(fileList,";")
//					Redimension/N=(DimSize(textWave,0) - 1) wsFileListWave,wsFileSelWave
//					wsFileListWave = textWave
//					wsFileSelWave[0] = 1
//					
//					//What channels are available for the selected file
//					
//					fullPath = wsFilePath + wsFileName
//					ABFLoader(fullPath,"1",0)
//					
//					Wave/T dTable_Values = root:ABFvar:dTable_Values
//					
//					String chList = dTable_Values[4]
//					
//					String quote = "\""
//					String channelList = quote + "All;" + ResolveListItems(chList,";") + quote
//	
//					PopUpMenu ChannelSelector win=NT,value=#channelList
//					
//					break
//			endswitch
			
			break
		case "copyToClipboard":
			Wave/T savedNameTable = NPC:savedNameTable
			ControlInfo/W=NTP savedNames
			
			Variable index = tablematch(S_Value,savedNameTable)
			
			If(index == -1)
				String str = ""
			Else
				str = savedNameTable[index][1]
			EndIf
			
			//Copy the string to the clipboard
			PutScrapText str
			break
		case "editSaveNames":
			Wave/T savedNameTable = NPC:savedNameTable
			If(!WaveExists(savedNameTable))
				Make/N=(0,2)/T/O NPC:savedNameTable /Wave = savedNameTable
			EndIf
			
			Edit savedNameTable
			break
		case "deleteSuffix":
			RunCmd("delSuffix")
			break
	endswitch
	return errorCode
End

//SET VARIABLES------------------------------------------------------------

Function ntSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	STRUCT filters filters
	
	DFREF NPC = $CW
	DFREF NPD = $DSF
	SVAR listFocus = NPC:listFocus
	
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
					
					//Don't recall previous settings, bc we just changed it.
					changeFocus("WaveMatch",0)
					
				case "waveGrouping":
				case "prefixGroup":
				case "groupGroup":
				case "seriesGroup":
				case "sweepGroup":
				case "traceGroup":	
				case "pos6Group":
				case "pos7Group":				
					//Builds the match list according to all search terms, groupings, and filters
					getWaveMatchList()
					
					//display the full path to the wave in a text box
					drawFullPathText()
					
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
		case -3: //received keyboard focus (Igor 8 and above only)
			strswitch(sva.ctrlName)
				case "waveMatch":
				case "waveNotMatch":
				case "relativeFolderMatch":
					changeFocus("WaveMatch",1)
					break
			endswitch
			break
	endswitch

	return 0
End



//Handles variable, string, and wave inputs to external function parameter inputs
Function ntExtParamProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	DFREF NPC = $CW
	
	//holds the parameters of the external functions
	Wave/T param = NPC:ExtFunc_Parameters
	
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
					ControlInfo/W=NTP $sva.ctrlName
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

//Handles external function checkboxes
Function ntExtParamCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	
	String name = cba.ctrlName
	Variable paramIndex = ExtFuncParamIndex(name)
	
	String func = CurrentExtFunc()
	String type = getParam("PARAM_" + num2str(paramIndex) + "_TYPE",func)
			
	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			setParam("PARAM_" + num2str(paramIndex) + "_VALUE",func,num2str(checked))
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
			DFREF NPC = $CW
			Wave/T param = NPC:ExtFunc_Parameters
			
			String func = CurrentExtFunc()
			Variable index = ExtFuncParamIndex(pa.ctrlName)
			
			setParam("PARAM_" + num2str(index) + "_VALUE",func,popStr)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


//CHECK BOXES -----------------------------

Function ntCheckProc(ca) : CheckBoxControl
	STRUCT WMCheckBoxAction &ca
	
	DFREF NPC = $CW
	
	NVAR areHorizSeparated = NPC:areHorizSeparated
	NVAR areVertSeparated = NPC:areVertSeparated
	
	switch( ca.eventCode )
		case 2: // mouse up
			strswitch( ca.ctrlName)
				case "ntViewerSeparateVert":
				
					//Remove any horizontal separation
					Checkbox ntViewerSeparateHoriz win=NT,value=0
					areHorizSeparated = 0
					SeparateTraces("horiz")

					If(ca.checked)
						areVertSeparated = 1
					Else
						areVertSeparated = 0
					EndIf
					
					//Apply or remove vertical separations
					SeparateTraces("vert")
					
					break
				case "ntViewerSeparateHoriz":
				
					//Remove any vertical separation
					Checkbox ntViewerSeparateVert win=NT,value=0
					areVertSeparated = 0
					SeparateTraces("vert")
					
					If(ca.checked)
						areHorizSeparated = 1
					Else
						areHorizSeparated = 0
					EndIf
					
					//Apply or remove horizontal separations
					SeparateTraces("horiz")
					
					break			
			endswitch
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End






//CUSTOM HOOK FUNCTIONS------------------------------------------------------------

//Hook function to initiate animated fold or unfold of the parameter panel
//Triggers the hook if the mouse is clicked on the vertical thick divider in the GUI
Function MouseClickHooks(s)
	STRUCT WMWinHookStruct &s
	DFREF NPC = $CW
	DFREF NTS = root:Packages:NT:Settings
	NVAR foldStatus = NPC:foldStatus
	
	NVAR hf = NTS:hf
	
	Variable hookResult = 0
	Variable r = ScreenResolution / 72
	
	switch(s.eventCode)
		case 0:
			//handle activate
			break
		case 1: 
			//handle deactivate
			break
		case 3:
			//handle mouse down
			
			//List box resizes and WaveMatch/DataSet List box positions
//			NVAR WM_Position = NPC:WM_Position
//			NVAR DSW_Position = NPC:DSW_Position
			
			
			//Extract the current size of the parameter panel from here
			//We'll need to shift the right-side mouse click area according to the selected command
//			Wave/T controlAssignments = NPC:controlAssignments
//			SVAR selectedCmd = NPC:selectedCmd
//			Variable index = tableMatch(selectedCmd,controlAssignments)
//			
//			If(index != -1) 
//				Variable rightEdge = str2num(controlAssignments[index][2])
//			Else
//				rightEdge = 210
//			EndIf
			
			//Check mouse position
			
//			If(V_left > 442 && V_left < 454 && V_top <= 510*hf)
//				If(foldStatus)
//					closeParameterFold()
//					foldStatus = 0
//				Else
//					openParameterFold(size=rightEdge)
//					foldStatus = 1
//				EndIf
//				
//			//checks right boundary as well for when the panel is open
//			ElseIf(V_left > (448 + rightEdge-6) && V_left < (448 + rightEdge+6) && V_top <= 510*hf && foldStatus) 
//				closeParameterFold()
//				foldStatus = 0
//			

			GetMouse/W=NTP#Data
			
			//mouse hook for toggling the listbox focus	
			If(V_left > 10 && V_left < 235 && V_top > 130 && V_top < 160) //Wave Match Click
				changeFocus("WaveMatch",1)
			ElseIf(V_left > 245 && V_left < 470 && V_top > 130 && V_top < 160) //Data Set Click
				changeFocus("DataSet",1)
			ElseIf(V_left < 58 && V_top > 469 && V_top < 486)//Grouping Click
//				PopUpContextualMenu/C=(10,486)/N "GroupingMenu"
//				
//				String popStr = S_Selection
//				Variable popNum = V_flag
//				
//				If(V_flag == 0 || V_flag == -1)
//					break
//				EndIf
//				
//				popStr = TrimString(StringFromList(0,popStr,"("))
//				
//				appendGroupSelection(popStr)
			ElseIf(V_left < 446 && V_top > 505 && V_top < 515)
//				NVAR viewerOpen = NPC:viewerOpen
//			
//				If(!viewerOpen) 
//					openViewer()
//					viewerOpen = 1
//					
//					//Set the Viewer hook
//					SetWindow NT, hook(viewerHook)=viewerHook
//				Else
//					closeViewer()
//					viewerOpen = 0
//					//Set the Viewer hook
//					SetWindow NT, hook(viewerHook)=$""
//				EndIf		
			EndIf
			
			
			//Resizing list boxes
//			NVAR WM_Resize = NPC:WM_Resize
//			NVAR DS_Resize = NPC:DS_Resize
//			NVAR Folders_Resize = NPC:Folders_Resize
//			NVAR Folders_Position = NPC:Folders_Position
//			
//			//Wave Match click
//			If(s.mouseLoc.h < WM_Position + 5 && s.mouseLoc.h > WM_Position - 5 && s.mouseLoc.v > 123 && s.mouseLoc.v <  452)
//				//Change the cursor to the left right drag icon
//				s.doSetCursor = 1
//				s.cursorCode = 5
//				
//				WM_Resize = (WM_Resize) ? 0:1	
//				hookResult = 1
//			EndIf
//			
//			//Folders list box hover
//			If(V_left > Folders_Position - 5 && V_left < Folders_Position + 5 && s.mouseLoc.v > 72)	
//				Folders_Resize = 1
//			Else
//				Folders_Resize = 0
//			EndIf
//	
//			break
			
		case 4:
			//mouse moved
			NVAR WM_Position = NPC:WM_Position
			NVAR DSW_Position = NPC:DSW_Position
			NVAR WM_Resize = NPC:WM_Resize
			NVAR DS_Resize = NPC:DS_Resize
			NVAR Waves_Resize = NPC:Waves_Resize
			NVAR Folders_Resize = NPC:Folders_Resize
			NVAR Folders_Position = NPC:Folders_Position
			NVAR hf =  NTS:hf
			
			//Wave Match Hover
			If(s.mouseLoc.h < WM_Position + 5 && s.mouseLoc.h > WM_Position - 5 && s.mouseLoc.v > 123 && s.mouseLoc.v <  452)
				//Change the cursor to the left right drag icon
				s.doSetCursor = 1
				s.cursorCode = 5
				
			//Navigator Folders Hover
			ElseIf(s.mouseLoc.h < Folders_Position + 5 && s.mouseLoc.h > Folders_Position - 5 && s.mouseLoc.v > 72)	
				//Change the cursor to the left right drag icon
				s.doSetCursor = 1
				s.cursorCode = 5
			EndIf
			
			If(WM_Resize)
				//Change the cursor to the left right drag icon
				s.doSetCursor = 1
				s.cursorCode = 5 
				
				If(s.mouseLoc.h < 80 || s.mouseLoc.h > 260)
					
					ControlInfo/W=NTP MatchListBox
					WM_Position = V_width + 6
					break
				EndIf
				
				ControlInfo/W=NTP MatchListBox
				ListBox MatchListBox win=NT,size={s.mouseLoc.h - 6,V_height}
				
				ControlInfo/W=NTP DataSetWavesListBox
				ListBox DataSetWavesListBox win=NT,pos={s.mouseLoc.h + 5,V_top},size={V_right - s.mouseLoc.h - 5,V_height}
				
				WM_Position = s.mouseLoc.h
				
				//move the focus box with it
				SVAR listFocus = NPC:listFocus
				strswitch(listFocus)
					case "WaveMatch":
						listFocus = "DataSet"
						changeFocus("WaveMatch",1)
						break
					case "DataSet":
						listFocus = "WaveMatch"
						changeFocus("DataSet",1)
						break
				endswitch
			ElseIf(Folders_Resize)
				//Change the cursor to the left right drag icon
				s.doSetCursor = 1
				s.cursorCode = 5
				
				//Mouse position in navigator panel coordinates
				GetMouse/W=NTP#navigatorPanel
				Variable mouseHor = V_left
				
				ControlInfo/W=NTP#navigatorPanel folderListBox
				Variable xExpand = mouseHor - V_right
				
				If(mouseHor < 60 || mouseHor > 220)
					break
				EndIf
				
				ListBox folderListBox win=NT#navigatorPanel,size={V_width + xExpand,V_height}
				
				Folders_Position += xExpand
				 
				ControlInfo/W=NTP#navigatorPanel waveListBox
				ListBox waveListBox win=NT#navigatorPanel,pos={V_left + xExpand,V_top},size={V_width - xExpand,V_height}	
				
			EndIf
			
			break
		case 5:
			//mouse up
			
			NVAR WM_Position = NPC:WM_Position
			NVAR DSW_Position = NPC:DSW_Position
			NVAR WM_Resize = NPC:WM_Resize
			NVAR DS_Resize = NPC:DS_Resize
			NVAR Folders_Resize = NPC:Folders_Resize
			
			//Change the cursor to the left right drag icon
			s.doSetCursor = 1
			s.cursorCode = 0
			Folders_Resize = 0
			
			//Wave Match Hover
			If(WM_Resize)
				//Change the cursor to the left right drag icon
				s.doSetCursor = 1
				s.cursorCode = 0
				
				ControlInfo/W=NTP MatchListBox
				WM_Position = V_width + 6
				
				WM_Resize = 0
				hookResult = 1
			EndIf
			
			
			break
	endswitch

	return hookResult
End

//Window hook for the Viewer
//Handles trace selections and horizontal shifting
//Function viewerHook(s)
//	STRUCT WMWinHookStruct &s
//	DFREF NPC = $CW
//	
//	SVAR selectedTrace = NPC:selectedTrace
//	SVAR selectedAxis = NPC:selectedAxis
//	
//	Variable hookResult = 0
//	Variable r = ScreenResolution / 72
//	
//	switch(s.eventCode)
//		case 0:
//			//handle activate
//			break
//		case 1: 
//			//handle deactivate
//			break
//		case 5:
//			//handle mouse up
//			GetMouse/W=NTP
//			If(V_top > 515 && V_top < 515 + 300 - 25)
//				If(strlen(selectedTrace))
//					ModifyGraph/W=NTP#Nav#Viewer lsize($selectedTrace)=1
//				EndIf
//				
//				String trace = TraceFromPixel(V_left,V_top,"WINDOW:NTP#Nav#Viewer;DELTAX:3;DELTAY:3")
//				trace = StringByKey("TRACE",trace)
//				
//				If(strlen(trace))
//					selectedTrace = trace
//					String axis = TraceInfo("NTP#Nav#Viewer",trace,0)
//					selectedAxis = StringByKey("/B",StringByKey("AXISFLAGS",axis),"=")
//					ModifyGraph/W=NTP#Nav#Viewer lsize($trace)=2
//				Else
//					selectedTrace = ""
//					selectedAxis = ""
//				EndIf
//			EndIf
//			hookResult = 1
//			break
//		case 11:
//			//handle keyboard input
//			If(strlen(selectedTrace) && strlen(selectedAxis))
//				Variable axisNum = str2num(StringFromList(1,selectedAxis,"_"))	
//				String list = AxisList("NTP#Nav#Viewer")
//				list = ListMatch(list,"bottom*",";")
//				
//				//wave ref for the trace we're moving
//				Wave selectedTraceWave = TraceNameToWaveRef("NTP#Nav#Viewer",selectedTrace)
//				
//				If(!strlen(list))
//					break
//				EndIf
//					
//				switch(s.keyCode)
//					case 28: //left arrow	
//						String newAxis = ReplaceListItem(1,selectedAxis,"_",num2str(axisNum - 1))
//						//If we are on the first axis moving left, wrap around to the right side
//						If(WhichListItem(newAxis,list) == -1)
//							newAxis = StringFromList(ItemsInList(list,";")-1,list,";")
//							Variable isWrap = 1
//						Else
//							isWrap = 0
//						EndIf
//						
//						//trace that is currently on the axis we're moving to
//						String traceOnNewAxis = AxisInfo("NTP#Nav#Viewer",newAxis)
//						traceOnNewAxis = StringByKey("CWAVE",traceOnNewAxis)
//						
//						//wave ref for the trace we're replacing
//						Wave traceOnNewAxisWave = TraceNameToWaveRef("NTP#Nav#Viewer",traceOnNewAxis)
//				
//						//Flip the traces, requires reordering traces as they are added/removed			
//						ReplaceWave/W=NTP#Nav#Viewer trace=$traceOnNewAxis,selectedTraceWave
//						
//						AppendToGraph/W=NTP#Nav#Viewer/B=$selectedAxis traceOnNewAxisWave
//						
//						If(isWrap)
//							ReorderTraces/W=NTP#Nav#Viewer _front_,{$selectedTrace}
//							ReorderTraces/W=NTP#Nav#Viewer _back_,{$traceOnNewAxis}
//						Else
//							ReorderTraces/W=NTP#Nav#Viewer $selectedTrace,{$selectedTrace,$traceOnNewAxis}					
//						EndIf
//						
//						RemoveFromGraph	/W=NTP#Nav#Viewer $(selectedTrace + "#1")					
//
//						//Bolden line to indicate selected trace
//						ModifyGraph/W=NTP#Nav#Viewer lsize($selectedTrace)=2
//						
//						//Change selected axis
//						selectedAxis = newAxis				
//						break
//					case 29: //right arrow
//						newAxis = ReplaceListItem(1,selectedAxis,"_",num2str(axisNum + 1))
//						//If we are on the last axis moving right, wrap around to the left side
//						If(WhichListItem(newAxis,list) == -1)
//							newAxis = StringFromList(0,list,";")
//							isWrap = 1
//						Else
//							isWrap = 0
//						EndIf
//						
//						//trace that is currently on the axis we're moving to
//						traceOnNewAxis = AxisInfo("NTP#Nav#Viewer",newAxis)
//						traceOnNewAxis = StringByKey("CWAVE",traceOnNewAxis)
//						
//						//wave ref for the trace we're replacing
//						Wave traceOnNewAxisWave = TraceNameToWaveRef("NTP#Nav#Viewer",traceOnNewAxis)
//					
//						//Flip the traces, requires reordering traces as they are added/removed						
//						ReplaceWave/W=NTP#Nav#Viewer trace=$traceOnNewAxis,selectedTraceWave
//						AppendToGraph/W=NTP#Nav#Viewer/B=$selectedAxis traceOnNewAxisWave	 
//												
//						If(isWrap)
//							RemoveFromGraph	/W=NTP#Nav#Viewer $(selectedTrace + "#1")
//						Else
//							ReorderTraces/W=NTP#Nav#Viewer $selectedTrace,{$traceOnNewAxis,$selectedTrace}
//							RemoveFromGraph	/W=NTP#Nav#Viewer $selectedTrace
//						EndIf
//						
//						//Bolden line to indicate selected trace
//						ModifyGraph/W=NTP#Nav#Viewer lsize($selectedTrace)=2
//						
//						//Change selected axis
//						selectedAxis = newAxis	
//						break
//				endswitch
//				
//			EndIf
//			hookResult = 1
//			break
//	endswitch
//	return hookResult
//End

//Opens the parameter infold opening
Function openParameterFold([size])
	Variable size
	
	DFREF NPC =  root:Packages:NT:
	SVAR listFocus = NPC:listFocus
	NVAR Folders_Position = NPC:Folders_Position
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
	SetDrawEnv/W=NTP  fstyle= 0
	DrawAction/W=NTP delete,getgroup=parameterText
	SetDrawEnv/W=NTP xcoord= abs,ycoord= abs, fsize=14, textrgb= (0,0,0), textxjust= 1,textyjust= 1,fname=$LIGHT,gstart,gname=parameterText
	DrawText/W=NTP 455+(size/2)-6,15,"Parameters"
	SetDrawEnv/W=NTP gstop
	
	//Draw the help message
	SVAR selectedCmd = NPC:selectedCmd	
//	switchHelpMessage(selectedCmd)
	
	Variable r = ScreenResolution/72
	Variable delta = ppr/r
	
	Do
		Variable i
	
		//Get original window coordinates
		GetWindow NT wsize
		Variable left,top,right,bottom
		left = V_left;right=V_right;top=V_top;bottom=V_bottom
		Variable expansion = (right*r - left*r) - 754 //current expansion relative to original width of the panel
		
		If(expansion >= size)
			ControlInfo/W=NTP#navigatorPanel folderListBox
			Folders_Position = 460 + V_width + size
			break
		EndIf
		
		Variable pixelsLeft = size - expansion
		If(pixelsLeft < ppr)
			MoveWindow/W=NTP left,top,right+(pixelsLeft/r),bottom;DelayUpdate
			Variable shift = size
		Else
			//Extend right edge of the panel to make room
			MoveWindow/W=NTP left,top,right+delta,bottom;DelayUpdate
			shift = expansion + delta
		EndIf
				
		//Shift the right line
		SetDrawEnv/W=NTP  fstyle= 0
		DrawAction/W=NTP delete,getgroup=rightLine
		SetDrawEnv/W=NTP xcoord= abs,ycoord= abs,linefgc= (0,0,0,16384),linethick= 4,gname=rightLine,gstart
		DrawLine/W=NTP 448 + shift,0, 448 + shift,515;DelayUpdate
		SetDrawEnv/W=NTP gstop
		
		DoUpdate/W=NTP
	While(expansion <= size)
	
	SVAR loadedPackages = NPC:loadedPackages
	
	//Special case enabling and disabling
	strswitch(selectedCmd)
		case "Run Cmd Line":
		case "New Data Folder":
		case "Load Suite2P":
		case "Kill Data Folder":
			break
		case "Load Scans":
			ListBox scanLoadListbox, win=NT,disable=0
			break
		case "External Function":
			BuildExtFuncControls(CurrentExtFunc())
			Button WaveListSelector win=NT,disable=3
			break
		case "Load Ephys":
		case "Load WaveSurfer":
//			ListBox sweepListBox win=NT,disable=0
			ListBox fileListBox win=NT,disable=0
			Button WaveListSelector win=NT,disable=3
			ListBox stimulusData win=NT,disable=0
			
			break
		case "Load pClamp":
			ListBox fileListBox win=NT,disable=0
			Button WaveListSelector win=NT,disable=3
			ListBox sweepListBox win=NT,disable=0
			break
		case "Population Vector Sum":
			break
		case "Get ROI":
			//only if this is 2PLSM package, not scanimage package
			If(stringmatch(loadedPackages,"*Imaging*"))
				ListBox ROIListBox win=NT,disable=0
				Button WaveListSelector win=NT,disable=3
			EndIf
			break
		default:
			Button WaveListSelector win=NT,disable=0
			break
	endswitch
	
End

//Closes the parameter infold
Function closeParameterFold([size])
	Variable size
	DFREF NPC =  root:Packages:NT:
	
	NVAR ppr = root:Packages:NT:Settings:ppr //pixel shift per refresh; can adjust in Settings panel
	NVAR Folders_Position = NPC:Folders_Position
	SVAR selectedCmd = NPC:selectedCmd	
	
	Variable r = ScreenResolution/72
	Variable delta = ppr/r
	
	If(ParamIsDefault(size))
		size = 0
		
		//hide the command menu, run cmd button, and ROIListBox on full closure
		Button CommandMenu win=NT,disable=3
		Button RunCmd win=NT,disable=3
		ListBox ROIListBox win=NT,disable=3
		ListBox sweepListBox win=NT,disable=3
		ListBox fileListBox win=NT,disable=3
		ListBox stimulusData win=NT,disable=3
		ListBox scanLoadListbox, win=NT,disable=3
	Else
		//shift text label if there is a non-zero size
		SetDrawEnv/W=NTP  fstyle= 0
		DrawAction/W=NTP delete,getgroup=parameterText
		SetDrawEnv/W=NTP xcoord= abs,ycoord= abs, textrgb= (0,0,0), fsize=14, textxjust= 1,textyjust= 1,fname=$LIGHT,gstart,gname=parameterText
		DrawText/W=NTP 455+(size/2)-6,15,"Parameters"
		SetDrawEnv/W=NTP gstop	
	EndIf
	
	//hide the list selector menu unless the command is 'Run Cmd Line', in which case it is hidden
	strswitch(selectedCmd)
		case "Run Cmd Line":
		case "New Data Folder":
		case "Kill Data Folder":
		case "External Function":
		case "Load Ephys":
		case "Load WaveSurfer":
		case "Load pClamp":
		case "Load Scans":
		case "Load Suite2P":
		case "Population Vector Sum":
			Button WaveListSelector win=NT,disable=3
			break
		default:
			Button WaveListSelector win=NT,disable=0
			break
	endswitch
	
	//Erase the help message
//	switchHelpMessage("")
	
	
	Variable i = 0
	Do
	
		//Get original window coordinates
		GetWindow NT wsize
		Variable left,top,right,bottom
		left = V_left;right=V_right;top=V_top;bottom=V_bottom
		Variable expansion = (r * right - r * left) - 754 //current expansion relative to original width of the panel
		
		If(!i)
			Variable totalReduction = expansion
		EndIf
		
		If(expansion <= size)
			ControlInfo/W=NTP#navigatorPanel folderListBox
			Folders_Position = 460 + V_width + size
			break
		EndIf
		
		Variable pixelsLeft = expansion - size
		If(pixelsLeft < ppr)
			MoveWindow/W=NTP left,top,right-(pixelsLeft/r),bottom;DelayUpdate
			Variable shift = size
		Else
			//Extend right edge of the panel to make room
			MoveWindow/W=NTP left,top,right-delta,bottom;DelayUpdate
			shift = expansion - delta
		EndIf

		//Shift the right line
		SetDrawEnv/W=NTP  fstyle= 0
		DrawAction/W=NTP delete,getgroup=rightLine
		SetDrawEnv/W=NTP xcoord= abs,ycoord= rel,textxjust= 1,textyjust= 1,linefgc= (0,0,0,16384),linethick= 4,gname=rightLine,gstart
		DrawLine/W=NTP 448 + shift,0, 448 + shift,1;DelayUpdate
		SetDrawEnv/W=NTP gstop,textxjust= 1,textyjust= 1

		DoUpdate/W=NTP
		i += 1
	While(expansion > size )
	
	//delete midline after animation
	If(!size)
		DrawAction/W=NTP delete,getgroup=rightLine
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
	DFREF NPC = $CW
	NVAR foldStatus = NPC:foldStatus
	
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
			SVAR masterCmdLineStr = NPC:masterCmdLineStr

			If(s.eventMod == 16 || s.eventMod == 17) //right click
				Variable numEntries = ItemsInList(masterCmdLineStr,";/;")
				GetMouse/W=NTP
				
				Variable selection = whichCmdLineEntry(V_left,V_top,numEntries)
				
				//NaN, no valid selection
				If(numtype(selection) == 2)
					//Reset selection drawing
					DrawAction/W=NTP getgroup=cmdEntrySelection,delete
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
					DrawAction/W=NTP getgroup=cmdEntrySelection,delete
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
				DrawAction/W=NTP getgroup=cmdEntrySelection,delete
	
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
	DrawAction/W=NTP getgroup=cmdEntrySelection,delete
	
	If(left > 455 && left < 624) 
		If(top > yPos && top < yPos + 20 && num > 0)
			SetDrawEnv linefgc= (3,52428,1),linethick= 3.00,xcoord=abs,ycoord=abs,gname=cmdEntrySelection,gstart
			DrawLine/W=NTP 458,yPos,458,yPos+20
			SetDrawEnv gstop
			return 0
		ElseIf(top > yPos + 20 && top < yPos + 40 && num > 1)
			SetDrawEnv linefgc= (3,52428,1),linethick= 3.00,xcoord=abs,ycoord=abs,gname=cmdEntrySelection,gstart
			DrawLine/W=NTP 458,yPos+20,458,yPos+40
			SetDrawEnv gstop
			return 1
		ElseIf(top > yPos + 40 && top < yPos + 60 && num > 2)
			SetDrawEnv linefgc= (3,52428,1),linethick= 3.00,xcoord=abs,ycoord=abs,gname=cmdEntrySelection,gstart
			DrawLine/W=NTP 458,yPos+40,458,yPos+60
			SetDrawEnv gstop
			return 2
		ElseIf(top > yPos + 60 && top < yPos + 80 && num > 3)
			SetDrawEnv linefgc= (3,52428,1),linethick= 3.00,xcoord=abs,ycoord=abs,gname=cmdEntrySelection,gstart
			DrawLine/W=NTP 458,yPos+60,458,yPos+80
			SetDrawEnv gstop
			return 3
		ElseIf(top > yPos + 80 && top < yPos + 100 && num > 4)
			SetDrawEnv linefgc= (3,52428,1),linethick= 3.00,xcoord=abs,ycoord=abs,gname=cmdEntrySelection,gstart
			DrawLine/W=NTP 458,yPos+80,458,yPos+100
			SetDrawEnv gstop
			return 4
		ElseIf(top > yPos + 100 && top < yPos + 120 && num > 5)
			SetDrawEnv linefgc= (3,52428,1),linethick= 3.00,xcoord=abs,ycoord=abs,gname=cmdEntrySelection,gstart
			DrawLine/W=NTP 458,yPos+100,458,yPos+120
			SetDrawEnv gstop
			return 5
		ElseIf(top > yPos + 120 && top < yPos + 140 && num > 6)
			SetDrawEnv linefgc= (3,52428,1),linethick= 3.00,xcoord=abs,ycoord=abs,gname=cmdEntrySelection,gstart
			DrawLine/W=NTP 458,yPos+120,458,yPos+140
			SetDrawEnv gstop
			return 6
		ElseIf(top > yPos + 140 && top < yPos + 160 && num > 7)
			SetDrawEnv linefgc= (3,52428,1),linethick= 3.00,xcoord=abs,ycoord=abs,gname=cmdEntrySelection,gstart
			DrawLine/W=NTP 458,yPos+140,458,yPos+160
			SetDrawEnv gstop
			return 7
		ElseIf(top > yPos + 160 && top < yPos + 180 && num > 8)
			SetDrawEnv linefgc= (3,52428,1),linethick= 3.00,xcoord=abs,ycoord=abs,gname=cmdEntrySelection,gstart
			DrawLine/W=NTP 458,yPos+160,458,yPos+180
			SetDrawEnv gstop
			return 8
		ElseIf(top > yPos + 180 && top < yPos + 200 && num > 9)
			SetDrawEnv linefgc= (3,52428,1),linethick= 3.00,xcoord=abs,ycoord=abs,gname=cmdEntrySelection,gstart
			DrawLine/W=NTP 458,yPos+180,458,yPos+200
			SetDrawEnv gstop
			return 9
		ElseIf(top > yPos + 200 && top < yPos + 220 && num > 10)
			SetDrawEnv linefgc= (3,52428,1),linethick= 3.00,xcoord=abs,ycoord=abs,gname=cmdEntrySelection,gstart
			DrawLine/W=NTP 458,yPos+200,458,yPos+220
			SetDrawEnv gstop
			return 10
		EndIf
	EndIf
End

//Deletes a specific command from the master command line entry, redraws
Function DeleteCmdLineEntry(selection)
	Variable selection
	
	DFREF NPC = $CW
	SVAR masterCmdLineStr = NPC:masterCmdLineStr
	
	masterCmdLineStr = RemoveListItem(selection,masterCmdLineStr,";/;")
	DrawMasterCmdLineEntry()
End

Function EditCmdLineEntry(selection)
	Variable selection
	
	DFREF NPC = $CW
	SVAR masterCmdLineStr = NPC:masterCmdLineStr
	NVAR editingMasterCmdLineStr = NPC:editingMasterCmdLineStr
	
	//Pull the entry into the editing box
	SetVariable cmdLineStr win=NT,value=_STR:StringFromList(selection,masterCmdLineStr,";/;"),activate
	
	
	//Set editing details
	editingMasterCmdLineStr = selection
End


Function SendNotificationTask(s)		// This is the function that will be called periodically
	STRUCT WMBackgroundStruct &s
	DFREF NPC = $CW
	
	NVAR maxNotificationSize = NPC:maxNotificationSize
	SVAR notificationEntry = NPC:notificationEntry
	NVAR funcPanelWidth = NPC:funcPanelWidth
	NVAR screenBottom = NPC:screenBottom
	NVAR notificationSize = NPC:notificationSize
	notificationSize += 20
	
	If(notificationSize > 1000)
		//end the notification after some additional time
		StopNotificationTask()
		
	ElseIf(notificationSize < maxNotificationSize)
		//Animate the notification box
		GroupBox notificationBox win=NTP#Func,align=1,size={notificationSize,50}
	Else
		//after reaching a certain size (maxNotificationSize), the text pops up in the notification box
		DrawAction/W=NTP#Func getgroup=notificationText,delete
		SetDrawEnv/W=NTP#Func gname=notificationText,gstart
		SetDrawEnv/W=NTP#Func xcoord= abs,ycoord= abs, fsize=16, textxjust= 0,textyjust= 1,fname="Helvetica Light"
		DrawText/W=NTP#Func funcPanelWidth - maxNotificationSize + 50,screenBottom-35,notificationEntry
		SetDrawEnv/W=NTP#Func gstop
	EndIf
	
	return 0	// Continue background task
End

Function SendNotification([maxSize])
	Variable maxSize //max width of the notification box to accomodate longer text
	
	DFREF NPC = $CW
	Variable/G NPC:maxNotificationSize
	NVAR maxNotificationSize = NPC:maxNotificationSize
	
	maxNotificationSize = (ParamIsDefault(maxSize)) ? 300 : maxSize
	
	Variable/G NPC:notificationSize
	NVAR notificationSize = NPC:notificationSize
	notificationSize = 0
	
	NVAR funcPanelWidth = NPC:funcPanelWidth
	NVAR screenBottom = NPC:screenBottom
	
	//Initialize the notifiaction
	GroupBox notificationBox win=NTP#Func,pos={funcPanelWidth - 10,screenBottom-60},align=1,size={notificationSize,50},disable=0,labelBack=(0,0xb000,0,0x4000)
	
	Variable numTicks = 1		// Run every two seconds (120 ticks)
	CtrlNamedBackground sendNotification, period=numTicks, proc=SendNotificationTask
	CtrlNamedBackground sendNotification, start
End

Function StopNotificationTask()
	CtrlNamedBackground sendNotification, stop
	DrawAction/W=NTP#Func getgroup=notificationText,delete
	KillControl/W=NTP#Func notificationBox
End


//SHORTCUTS-----------------------------------------------------------

//Function/S handleShortcut()
	DFREF NPC = $CW
	DFREF NPD = $DSF
	
	//Get the activated shortcut
	GetLastUserMenuInfo
	
	Wave/T shortCuts = NPC:shortCuts
	SVAR selectedCmd = NPC:selectedCmd
	SVAR prevCmd = NPC:prevCmd
	
	String theFunction = shortCuts[str2num(S_Value)-1][1]
	
	//Make sure we're in the function tab
	NVAR currentTab = NPC:currentTab
	
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
	DrawAction/W=NPC delete
	
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
				Wave/T DSNamesLB_ListWave = NPC:DSNamesLB_ListWave
				SVAR DSNames = NPD:DSNames
				DSNames = "--None--;--Scan List--;--Item List--;" + textWaveToStringList(DSNamesLB_ListWave,";")		
				break
		endswitch
	EndIf
	
	Button AT_CommandPop win=analysis_tools,title = "\\JL▼    " + selectedCmd
	DrawText/W=NTP 15,53,"Commands:"
	ControlInfo/W=NTP CommandMenu
						
	If(!cmpstr(selectedCmd,"External Function"))
		DrawText/W=NTP 23,84,"Functions:"
	EndIf

End



////Igor open hook
//Function AfterFileOpenHook(refnum,fileNameStr,pathNameStr,fileTypeStr,fileCreatorStr,fileKind)
//
//End

