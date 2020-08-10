#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Menu "Data"
	"Load ABF2", /Q, InitializeABFPanel()
End

Function InitializeABFPanel()
	DoWindow ABF2_Loader
	If(!V_flag)
		Build_ABF2_Loader()
	EndIf
End

Function Build_ABF2_Loader()
	//Make ABFvar folder
	If(!DataFolderExists("root:ABFvar"))
		NewDataFolder root:ABFvar
	EndIf
	String/G root:ABFvar:ABF_folderpath
	String/G root:ABFvar:ABF_filename
	String/G root:ABFvar:ABF_lines
	SVAR ABF_folderpath = root:ABFvar:ABF_folderpath
	SVAR ABF_filename = root:ABFvar:ABF_filename	
	SVAR ABF_lines = root:ABFvar:ABF_lines
	ABF_lines = "0"
	
	// Create the table folder
	if(!DataFolderExists("root:CmdTableWaves"))
       	NewDataFolder/S root:CmdTableWaves
	else
		SetDataFolder root:CmdTableWaves
	endif
	SetDataFolder root:CmdTableWaves
	
	String/G root:CmdTableWaves:DtabColumnLabels = "Prefix;Group;Series;Sweep;Trace;TF;Comment;File;"
	String/G root:CmdTableWaves:DtabColumnWidths = "40;40;40;40;40;20;120;500;"
	String/G root:CmdTableWaves:DtabColumnAlign = "1;1;1;1;1;0;0;0;"
	String/G root:CmdTableWaves:DtabWaveList = "DTable_Prefix;DTable_Group;DTable_Series;DTable_Sweep;DTable_Trace;DTable_TF;DTable_Comment;DTable_FilePath;"
	String/G root:CmdTableWaves:DtabWaveTypes = "TEXT;TEXT;TEXT;TEXT;TEXT;NUM;TEXT;TEXT;"

	If(!strlen(ABF_folderpath))
		ABF_filename = ""
	EndIf
	
	DoWindow ABF2Loader
	If(!V_flag)
		NewPanel/K=1/N=ABF2Loader/W=(0,0,380,100) as "ABF2 Loader"
		ModifyPanel/W=ABF2Loader fixedsize=1
		SetVariable ABF_folderpath win=ABF2Loader,pos={10,10},size={320,20},title="Path:",value=root:ABFvar:ABF_folderpath
		SetVariable ABF_filename win=ABF2Loader,pos={10,30},size={150,20},title="File:",value=root:ABFvar:ABF_filename
		SetVariable ABF_TableLines win=ABF2Loader,pos={10,50},size={100,20},title="Lines:",value=root:ABFvar:ABF_lines
		Button ABF_Browse win=ABF2Loader,pos={340,7},size={25,20},title="...",proc=ABF2_BrowseFiles
		Button ABF_Index win=ABF2Loader,pos={180,27},size={50,20},title="Index",proc=ABF2_BrowseFiles
		Button ABF_LoadWaves win=ABF2Loader,pos={180,47},size={50,20},title="Load",proc=ABF2_BrowseFiles
		
		PopUpMenu ABF_LoadStimData win=ABF2Loader,pos={10,70},size={100,20},title="Stimulus Data",value="None;1;2;3;4;"
	EndIf
End


Function ABFLoader(filepath,whichChannel,doLoad)
	String filepath
	String whichChannel
	Variable doLoad
	
	STRUCT headerPosition hpos
	STRUCT headerParameters h
	STRUCT protocolInfo p
	STRUCT ADCinfo a
	STRUCT tagInfo t
	STRUCT sectionInfo sectionInfo
	STRUCT DTableValues dTable
	
	Variable start,chunk,verbose,BLOCKSIZE,refnum,eof,size,numSections,i,j,offset
	String stop,sweeps,channels,machineF,sectionStr,adcStr,protStr,cdf
	
	
	cdf = GetDataFolder(1)
	
	sectionStr = "ProtocolSection;ADCSection;DACSection;EpochSection;ADCPerDACSection;EpochPerDACSection;UserListSection;StatsRegionSection;MathSection;"
	sectionStr += "StringsSection;DataSection;TagSection;ScopeSection;DeltaSection;VoiceTagSection;SynchArraySection;AnnotationSection;StatsSection;"
	
	adcStr = "ADCNum;telegraphEnable;telegraphInstrument;telegraphAdditGain;telegraphFilter;telegraphMembraneCap;telegraphMode;"
	adcStr += "telegraphAccessResistance;ADCPtoLChannelMap;ADCSamplingSeq;ADCProgrammableGain;ADCDisplayAmplification;ADCDisplayOffset;"
	adcStr += "instrumentScaleFactor;instrumentOffset;signalGain;signalOffset;signalLowpassFilter;signalHighpassFilter;lowpassFilterType;"
	adcStr += "highpassFilterType;postProcessLowpassFilter;postProcessLowpassFilterType;enabledDuringPN;StatsChannelPolarity;ADCChannelNameIndex;ADCUnitsIndex"
	
	protStr = "operationMode;ADCSequenceInterval;enableFileCompression;unused1;fileCompressionRatio;synchTimeUnit;secondsPerRun;numSamplesPerEpisode;preTriggerSamples;"
	protStr += "episodesPerRun;runsPerTrial;numberOfTrials;averagingMode;undoRunCount;firstEpisodeInRun;triggerThreshold;triggerSource;triggerAction;triggerPolarity;scopeOutputInterval;"
	protStr += "episodeStartToStart;runStartToStart;averageCount;trialStartToStart;autoTriggerStrategy;firstRunDelayS;channelStatsStrategy;samplesPerTrace;startDisplayNum;finishDisplayNum;"
	protStr += "showPNRawData;statisticsPeriod;statisticsMeasurements;statisticsSaveStrategy;ADCRange;DACRange;ADCResolution;DACResolution;experimentType;manualInfoStrategy;commentsEnable;"
	protStr += "fileCommentIndex;autoAnalyseEnable;signalType;digitalEnable;ActiveDACChannel;digitalHolding;digitalInterEpisode;digitalDACChannel;digitalTrainActiveLogic;statsEnable;statisticsClearStrategy;levelHysteresis;"
	protStr += "timeHysteresis;allowExternalTags;averageAlgorithm;averageWeighting;undoPromptStrategy;trialTriggerSource;statisticsDisplayStrategy;externalTagType;scopeTriggerOut;LTPType;"
	protStr += "alternateDACOutputState;alternateDigitalOutputState;cellID;digitizerADCs;digitizerDACs;digitizerTotalDigitalOuts;digitizerSynchDigitalOuts;digitizerType"
	
	//Make ABFvar folder
	If(!DataFolderExists("root:ABFvar"))
		NewDataFolder root:ABFvar
	EndIf
	
	//Make bitformat lookup table for the protocol parameters
	Make/O/N=(ItemsInList(protStr,";")) root:ABFvar:protocolSectionBitFormat
	Wave protocolSectionBitFormat = root:ABFvar:protocolSectionBitFormat
	protocolSectionBitFormat = {2,4,1,1,3,4,4,3,3,3,3,3,2,2,2,4,2,2,2,4,4,4,3,4,2,4,2,3,3,3,2,4,3,2,4,4,3,3,2,2,2,3,2,2,2,2,2,2,2,2,2,2,2,3,2,2,4,2,2,2,2,2,2,2,2,4,2,2,2,2,2}
	
	If(!DataFolderExists("root:ABFvar"))
		NewDataFolder root:ABFvar
	EndIf
	String/G root:ABFvar:fileSig
	SVAR fileSig = root:ABFvar:fileSig
	fileSig = ""
	
	start = 0
	chunk = 0.05
	stop = "e"
	sweeps = "a"
	channels = "a"
	machineF = "ieee-le"
	verbose = 1
	BLOCKSIZE = 512
	
	Open/R/Z=2 refnum as filepath
	FStatus refnum
	eof = V_logEOF
	
	size = 4
	fileSig = PadString(fileSig,size,0)
	FBInRead/B=3/F=4 refnum,fileSig
	fileSig= UnPadString(fileSig,0)
	If(!strlen(fileSig))
		Close refnum
		return -1
	EndIf
	
	FSetPos refnum,0
	
	//Set header positions
	hpos.fileSignature = 0
	hpos.fileVersionNumber = 4
	hpos.fileInfoSize = 8
	hpos.actualEpisodes = 12
	hpos.fileStartDate = 16
	hpos.fileStartTimeMS = 20
	hpos.stopWatchTime = 24
	hpos.fileType = 28
	hpos.dataFormat = 30
	hpos.simultaneousScan = 32
	hpos.CRCEnable = 34
	hpos.fileCRC = 36
	hpos.fileGUID = 40
	hpos.creatorVersion = 56
	hpos.creatorNameIndex = 60
	hpos.modifierVersion = 64
	hpos.modifierNameIndex = 68
	hpos.protocolPathIndex = 72
	
	Variable numParameters = 18 //num parameters in the headerParameters structure
	String hParamStr = "fileSignature;fileVersionNumber;fileInfoSize;actualEpisodes;fileStartDate;fileStartTimeMS;stopWatchTime;fileType;dataFormat;"
	hParamStr+= "simultaneousScan;CRCEnable;fileCRC;fileGUID;creatorVersion;creatorNameIndex;modifierVersion;modifierNameIndex;protocolPathIndex"
	
	String tempStr = ""
	Variable tempVar
	
	//Read header parameters into structure
	tempStr = PadString(tempStr,4,0)
	FBInRead/B=3/F=4 refnum,tempStr
	h.fileSignature = tempStr
 	
 	//tempStr = ""
 	//tempStr = PadString(tempStr,4,0)
	//FBInRead/B=3/F=4 refnum,tempStr
	//h.fileVersionNumber = tempStr
	//h.fileVersionNumber = num2str(h.fileVersionNumber[3]) + num2str(h.fileVersionNumber[2]*0.1) + num2str(h.fileVersionNumber[1]*0.001) + num2str(h.fileVersionNumber[0]*0.0001)
	h.fileVersionNumber = 2
	
	//fStatus refnum
	//fSetPos refnum,V_filePos + 1
	fSetPos refnum,8
	
	FBInRead/B=2/F=3/U refnum,tempVar
	h.fileInfoSize = tempVar
	
	FBInRead/B=3/F=3/U refnum,tempVar
	h.actualEpisodes = tempVar
	
	FBInRead/B=3/F=3/U refnum,tempVar
	h.fileStartDate = tempVar
	
	FBInRead/B=3/F=3/U refnum,tempVar
	h.fileStartTimeMS = tempVar
	
	FBInRead/B=3/F=3/U refnum,tempVar
	h.stopWatchTime = tempVar
	
	FBInRead/B=3/F=2 refnum,tempVar
	h.fileType = tempVar
	
	FBInRead/B=3/F=2 refnum,tempVar
	h.dataFormat = tempVar
	
	FBInRead/B=3/F=2 refnum,tempVar
	h.simultaneousScan = tempVar
	
	FBInRead/B=3/F=2 refnum,tempVar
	h.CRCEnable = tempVar
	
	FBInRead/B=3/F=3/U refnum,tempVar
	h.fileCRC = tempVar
	
	FBInRead/B=3/F=3/U refnum,tempVar
	h.fileGUID = tempVar
	
	FSetPos refnum,56
	FBInRead/B=3/F=3/U refnum,tempVar
	h.creatorVersion = tempVar
	
	FBInRead/B=3/F=3/U refnum,tempVar
	h.creatorNameIndex = tempVar
	
	FBInRead/B=3/F=3/U refnum,tempVar
	h.modifierVersion = tempVar
	
	FBInRead/B=3/F=3/U refnum,tempVar
	h.modifierNameIndex = tempVar
	
	FBInRead/B=3/F=3/U refnum,tempVar
	h.protocolPathIndex = tempVar
	
	//
	If(cmpstr(h.fileSignature,"ABF2") == 0)
		h.fileStartTime = h.fileStartTimeMS*1000
	EndIf
	
	If(h.fileVersionNumber >= 2)
		numSections = 17
		offset = 76
		//Creates section waves
		For(i=0;i<ItemsInList(sectionStr,";");i+=1)
			Make/O/N=3 $("root:ABFvar:" + StringFromList(i,sectionStr,";"))
			Wave theWave = $("root:ABFvar:" + StringFromList(i,sectionStr,";"))
			//uBlockIndex
			FSetPos refnum,offset
			FBInRead/B=3/F=3/U refnum,tempVar
			theWave[0] = tempVar
			//uBytes
			FSetPos refnum,offset+4
			FBInRead/B=3/F=3/U refnum,tempVar
			theWave[1] = tempVar
			//numEntries
			FSetPos refnum,offset+8
			FBInRead/B=3/F=6 refnum,tempVar
			theWave[2] = tempVar

			offset += 16
		EndFor
		
		//Read in some file and stimulus information into a wave called 'Strings'
		Wave StringsSection = root:ABFvar:StringsSection
		fSetPos refnum,StringsSection[0]*BLOCKSIZE
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
		Make/O/T/N=1 root:ABFvar:Strings
		Wave/T Strings = root:ABFvar:Strings
		Strings[0] = ""
		For(i=0;i<30;i+=1)
			Redimension/N=(i+1) Strings
			nextSpace = strsearch(bigString,"\u0000",lastSpace)
			If(nextSpace == -1)
				Redimension/N=(i) Strings
				break
			EndIf
			Strings[i] = bigString[lastSpace,nextSpace]
			lastSpace = nextSpace + 1
		EndFor
		
		//Reads in the ADCSection and gets some more header parameters
		Wave ADCSection = root:ABFvar:ADCSection
		Make/O/N=(ItemsInList(adcStr,";"),ADCSection[2]) root:ABFvar:ADCsec
		Wave ADCsec = root:ABFvar:ADCsec
		
		Make/O/N=(ADCSection[2]) root:ABFvar:ADCSamplingSeq
		Wave ADCSamplingSeq = root:ABFvar:ADCSamplingSeq
		
		h.recChNames = ""
		h.recChUnits = ""
		
		Variable bitFormat,unitsIndex
		String theStr
		For(i=0;i<ADCSection[2];i+=1)
			offset = ADCSection[0]*BLOCKSIZE + ADCSection[1]*i
			fSetPos refnum,offset
			
			For(j=0;j<ItemsInList(adcStr,";");j+=1)
				theStr = StringFromList(j,adcStr,";")
				If(stringMatch(theStr,"ADCNum") || stringMatch(theStr,"telegraphEnable") || stringMatch(theStr,"telegraphInstrument") || stringMatch(theStr,"telegraphMode"))
					bitFormat = 2
				ElseIf(stringMatch(theStr,"ADCPtoLChannelMap") || stringMatch(theStr,"ADCSamplingSeq") || stringMatch(theStr,"statsChannelPolarity"))
					bitFormat = 2
				ElseIf(stringMatch(theStr,"lowpassFilterType") || stringMatch(theStr,"highpassFilterType") || stringMatch(theStr,"postProcessLowpassFilterType") || stringMatch(theStr,"enabledDuringPN"))
					bitFormat = 1
				ElseIf(stringMatch(theStr,"ADCChannelNameIndex") || stringMatch(theStr,"ADCUnitsIndex"))
					bitFormat = 3
				Else
					bitFormat = 4
				EndIf
				FBInRead/B=3/F=(bitFormat) refnum,tempVar
				ADCSec[j][i] = tempVar
				
				If(stringMatch(theStr,"ADCChannelNameIndex"))
					h.recChNames += Strings[tempVar-1]
					h.recChNames = TrimString(h.recChNames) + ";"
				ElseIf(stringMatch(theStr,"ADCNum"))
					ADCSamplingSeq[i] = tempVar
				ElseIf(stringMatch(theStr,"ADCUnitsIndex"))
					If(tempVar > 0)
						h.recChUnits += Strings[tempVar-1]
						h.recChUnits = TrimString(h.recChUnits) + ";"
					Else
						h.recChUnits += ";"
					EndIf
				EndIf
				
			EndFor
			
			//Fill out more parameters into the header structure			
			Variable ii = ADCSec[WhichListItem("ADCNum",adcStr,";")][i] //- 1
			//If(ii == -1)
			//	ii = 0
			//EndIf
			
			h.telegraphEnable[ii] = ADCSec[WhichListItem("telegraphEnable",adcStr,";")][i]
			h.telegraphAdditGain[ii] = ADCSec[WhichListItem("telegraphAdditGain",adcStr,";")][i]
			h.instrumentScaleFactor[ii] = ADCSec[WhichListItem("instrumentScaleFactor",adcStr,";")][i]
			h.signalGain[ii] = ADCSec[WhichListItem("signalGain",adcStr,";")][i]
			h.ADCProgrammableGain[ii] = ADCSec[WhichListItem("ADCProgrammableGain",adcStr,";")][i]
			h.instrumentOffset[ii] = ADCSec[WhichListItem("instrumentOffset",adcStr,";")][i]
			h.signalOffset[ii] = ADCSec[WhichListItem("signalOffset",adcStr,";")][i]	
		EndFor
		h.recChNames = RemoveEnding(h.recChNames,";") 
		h.recChUnits = RemoveEnding(h.recChUnits,";") 
			
	//DTABLE INDEXING
	If(doLoad == 0)
		Make/O/T/N=(8) root:ABFvar:dTable_Values
		Wave/T dTable_Values = root:ABFvar:dTable_Values
		
		//Prefix
		If(StringMatch(h.recChUnits[0],"mV"))
			dTable_Values[0] = "Vmon"
		Else
			dTable_Values[0] = "Imon"
		EndIf
		//Group
		dTable_Values[1] = "1"
		//Series
		dTable_Values[2] = ParseFilePath(0,S_filename,"_",1,0)
		dTable_Values[2] = StringFromList(0,dTable_Values[2],".")
		dTable_Values[2] = num2str(str2num(dTable_Values[2]))
		//Sweep
		dTable_Values[3] = "1-" + num2str(h.actualEpisodes)
		//Trace
		dTable_Values[4] = "1-" + num2str(ADCSection[2])
		//TF
		dTable_Values[5] = "0"
		//Comment
		dTable_Values[6] = Strings[1]
		dTable_Values[6] = ParseFilePath(0,dTable_Values[6],"\\",1,0)
		dTable_Values[6] = RemoveEnding(dTable_Values[6],".pro")
		//Filepath
		dTable_Values[7] = RemoveEnding(S_path,":")
		return 0
	EndIf
				
		//Read protocol section and add some parameters to the header structure
		Wave ProtocolSection = root:ABFvar:ProtocolSection
		Make/O/N=(ItemsInList(protStr,";"),ProtocolSection[2]) root:ABFvar:protSec
		Wave protSec = root:ABFvar:protSec
		
		offset = ProtocolSection[0]*BLOCKSIZE
		fSetPos refnum,offset
		
		For(i=0;i<ItemsInList(protStr,";");i+=1)
			bitFormat = protocolSectionBitFormat[i]
		
			FBInRead/B=3/F=(bitFormat) refnum,tempVar
			protSec[i] = tempVar
			If(i == 3)
				fStatus refnum
				fSetPos refnum,V_filePos + 2
			ElseIf(i == 64)
				fStatus refnum
				fSetPos refnum,V_filePos + 8
			EndIf
		EndFor
		
		h.operationMode = protSec[WhichListItem("operationMode",protStr,";")]
		h.synchTimeUnit = protSec[WhichListItem("synchTimeUnit",protStr,";")]
		h.ADCNumChannels = ADCSection[2]
		Wave DataSection = root:ABFvar:DataSection
		h.actualAcqLength = DataSection[2]
		h.dataSectionPtr = DataSection[0]
		h.numPointsIgnored = 0
		h.ADCSampleInterval = protSec[WhichListItem("ADCSequenceInterval",protStr,";")]/h.ADCNumChannels
		h.ADCRange = protSec[WhichListItem("ADCRange",protStr,";")]
		h.ADCResolution = protSec[WhichListItem("ADCResolution",protStr,";")]
		Wave SynchArraySection = root:ABFvar:SynchArraySection
		h.synchArrayPtr = SynchArraySection[0]
		h.synchArraySize = SynchArraySection[2]
	Else
		DoAlert 0,"Wave is not ABF2 format, go back and figure out the code for this."
		return -1
	EndIf
	
	//Groom parameters and plausibility checks
	If(h.actualAcqLength < h.ADCNumChannels)
		Close refnum
		DoAlert 0,"Less data points than sampled channels in file"
		return -1
	EndIf
	
	Make/O/N=(DimSize(ADCSamplingSeq,0)) root:ABFvar:recChIdx, root:ABFvar:recChInd
	Wave recChIdx = root:ABFvar:recChIdx
	Wave recChInd = root:ABFvar:recChInd
	
	recChIdx = ADCSamplingSeq
	For(i=0;i<DimSize(recChIdx,0);i+=1)
		recChInd[i] = recChIdx[i]
	EndFor
	
	If(h.fileVersionNumber < 2)
		DoAlert 0,"Wave is not ABF2 format, go back and figure out the code for this."
		return -1
	EndIf
	
	Make/O/N=(DimSize(recChInd,0)) root:ABFvar:chInd
	Wave chInd = root:ABFvar:chInd
	If(cmpstr(channels,"a") == 0)
		chInd = recChInd
	Else
		DoAlert 0,"Problem with channels parameter, check code"
		return -1
	EndIf
	
	//edit to add 4 gain channels
	Make/O/N=15 root:ABFvar:addGain
	Wave addGain = root:ABFvar:addGain
	If(h.fileVersionNumber >= 1.65)		
		addGain[0] = h.telegraphEnable[0]*h.telegraphAdditGain[0]
		addGain[1] = h.telegraphEnable[1]*h.telegraphAdditGain[1]
		addGain[2] = h.telegraphEnable[2]*h.telegraphAdditGain[2]
		addGain[3] = h.telegraphEnable[3]*h.telegraphAdditGain[3]
		addGain[4] = h.telegraphEnable[4]*h.telegraphAdditGain[4]
		addGain[5] = h.telegraphEnable[5]*h.telegraphAdditGain[5]
		addGain[6] = h.telegraphEnable[6]*h.telegraphAdditGain[6]
		addGain[7] = h.telegraphEnable[7]*h.telegraphAdditGain[7]
		addGain[8] = h.telegraphEnable[8]*h.telegraphAdditGain[8]
		addGain[9] = h.telegraphEnable[9]*h.telegraphAdditGain[9]
		addGain[10] = h.telegraphEnable[10]*h.telegraphAdditGain[10]
		addGain[11] = h.telegraphEnable[11]*h.telegraphAdditGain[11]
		addGain[12] = h.telegraphEnable[12]*h.telegraphAdditGain[12]
		addGain[13] = h.telegraphEnable[13]*h.telegraphAdditGain[13]
		addGain[14] = h.telegraphEnable[14]*h.telegraphAdditGain[14]
		
		addGain = (addGain == 0) ? 1 : addGain
	Else
		addGain = 1
	EndIf
	
	Variable dataSz	
	switch(h.dataFormat)
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
	
	//Sample interval
	offset = h.dataSectionPtr*BLOCKSIZE + h.numPointsIgnored*dataSz
	h.si = h.ADCSampleInterval*h.ADCNumChannels
	Variable si = h.si
	
	//Number of sweeps
	Variable nSweeps
	If(cmpstr(sweeps,"a") == 0)
		nSweeps = h.actualEpisodes
		sweeps = ""
		For(i=1;i<=nSweeps;i+=1)
			sweeps += num2str(i) + ";"
		EndFor
	Else
		nSweeps = ItemsInList(sweeps,";")
	EndIf
	
	switch(h.synchTimeUnit)
		case 0:
			h.synchArrTimeBase = 1
			break
		default:
			h.synchArrTimeBase = h.synchTimeUnit
			break
	endswitch
	
	//Read in the data
	switch(h.operationMode)
		case 1:
			If(h.fileVersionNumber >= 2)
				DoAlert 0,"ABF Loader currently doesn't work with data acquired in event-driven variable-length mode and ABF version 2.0"
				return -1
			Else
				If(h.synchArrayPtr <= 0 || h.synchArraySize <= 0)
					DoAlert 0,"Internal variabless 'synchArray~' are zero or negative"
					return -1
				EndIf
				//byte offset where syncharray starts
				h.synchArrayPtrByte = BLOCKSIZE*h.synchArrayPtr
				//Is file big enough to be holding the synchArray parameters
				If(h.synchArrayPtrByte + 2*4*h.synchArraySize > eof)
					DoAlert 0,"File does not contain complete SynchArray Section"
					return -1
				EndIf
			EndIf
			//add in more code to do case 1.
			break
		case 2:
		case 4:
		case 5:
			If(h.synchArrayPtr <= 0 ||h.synchArraySize <= 0)
				DoAlert 0,"Internal variabless 'synchArray~' are zero or negative"
				return -1
			EndIf
			
			//byte offset where syncharray starts
			h.synchArrayPtrByte = BLOCKSIZE*h.synchArrayPtr
			//Is file big enough to be holding the synchArray parameters
			If(h.synchArrayPtrByte + 2*4*h.synchArraySize > eof)
				DoAlert 0,"File does not contain complete SynchArray Section"
				return -1
			EndIf
			fSetPos refnum,h.synchArrayPtrByte
			Make/O/N=(h.synchArraySize*2) root:ABFvar:synchArray
			Wave synchArray = root:ABFvar:synchArray
			FBInRead/B=3/F=3 refnum,synchArray
			
			Redimension/N=(-1,2) synchArray
			Make/O/N=(h.synchArraySize)/FREE temp1,temp2

			Variable count1,count2
			count1 = 0
			count2 = 0
			For(i=0;i<DimSize(synchArray,0);i+=1)
				If(mod(i,2) == 0)
					temp1[count1] = synchArray[i][0]
					count1 += 1 					
				Else
					temp2[count2] = synchArray[i][0] 	
					count2 += 1	
				EndIf
			EndFor
		
			Redimension/N=(h.synchArraySize,2) synchArray
			//Really stupid way of doing this, but I was getting bizarre errors	
			For(i=0;i<h.synchArraySize;i+=1)
				synchArray[i][0] = temp1[i]
				synchArray[i][1] = temp2[i]
			EndFor
			
			h.sweepLengthInPts = synchArray[0][1]/h.ADCNumChannels
			//Kept as wave instead of structure element because I have to dimension it according to the number of sweeps
			Make/O/N=(DimSize(synchArray,0)) root:ABFvar:sweepStartInPts
			Wave sweepStartInPts = root:ABFvar:sweepStartInPts
			sweepStartInPts = synchArray*(h.synchArrTimeBase/h.ADCSampleInterval/h.ADCNumChannels)
			
			h.recTime[0] = h.fileStartTimeMS*(1e-3)
			h.recTime[1] = h.recTime[0] + ((1e-6)*(sweepStartInPts[DimSize(sweepStartInPts,0)-1] + h.sweepLengthInPts))*h.ADCSampleInterval*h.ADCNumChannels
			
			Variable startPt = 0
			h.dataPts = h.actualAcqLength
			h.dataPtsPerChan = h.dataPts/h.ADCNumChannels
			
			If(mod(h.dataPts,h.ADCNumChannels) > 0 || mod(h.dataPtsPerChan,h.actualEpisodes) > 0)
				DoAlert 0,"Number of data points is not OK"
				return -1
			EndIf
			
			Variable dataPtsPerSweep = h.sweepLengthInPts*h.ADCNumChannels
			fSetPos refnum,startPt*dataSz+offset
			
			//Make data wave
			Make/O/N=(h.sweepLengthInPts,DimSize(chInd,0),nSweeps) root:ABFvar:d
			Wave d = root:ABFvar:d
			Make/O/N=(nSweeps)  root:ABFvar:selectedSegStartInPts
			Wave selectedSegStartInPts = root:ABFvar:selectedSegStartInPts
			
			//Sweep offsets
			For(i=0;i<nSweeps;i+=1)
				selectedSegStartInPts[i] = (str2num(StringFromList(i,sweeps,";")) - 1)*dataPtsPerSweep*dataSz + offset
			EndFor
			
			
			//Loads the data
			Make/O/N=(dataPtsPerSweep) root:ABFvar:tempd
			Wave tempd = root:ABFvar:tempd
			
			For(i=0;i<nSweeps;i+=1)
				fSetPos refnum,selectedSegStartInPts[i]
				FBInRead/B=3/F=(bitFormat) refnum,tempd	
				//Scale traces
				String traceName = GenerateTraceName(filepath,i,whichChannel)
				SeparateChannels(filepath,traceName,tempd,h,dataPtsPerSweep,whichChannel,chInd)
			EndFor
			
			break
	endswitch
	Close refnum
	//KillDataFolder/Z root:ABFvar
End

Structure sectionInfo
	uint32 uBlockIndex
	uint32 uBytes
	int64 numEntries
EndStructure

Structure headerPosition
	uint16 fileSignature
	uint16 fileVersionNumber
	uint16 fileInfoSize
	uint16 actualEpisodes
	uint16 fileStartDate
	uint16 fileStartTimeMS
	uint16 stopWatchTime
	uint16 fileType
	uint16 dataFormat
	uint16 simultaneousScan
	uint16 CRCEnable
	uint16 fileCRC
	uint16 fileGUID
	uint16 creatorVersion
	uint16 creatorNameIndex
	uint16 modifierVersion
	uint16 modifierNameIndex
	uint16 protocolPathIndex
EndStructure

Structure headerParameters
	string fileSignature
	int16 fileVersionNumber
	uint32 fileInfoSize
	uint32 actualEpisodes
	uint32 fileStartDate
	uint32 fileStartTimeMS
	uint32 fileStartTime
	uint32 stopWatchTime
	int16 fileType
	int16 dataFormat
	int16 simultaneousScan
	int16 CRCEnable
	uint32 fileCRC
	uint32 fileGUID
	uint32 creatorVersion
	uint32 creatorNameIndex
	uint32 modifierVersion
	uint32 modifierNameIndex
	uint32 protocolPathIndex
	
	//ADC extras
	string recChNames
	string recChUnits
	int16 telegraphEnable[15] //Good for up to 15 channels 
	float telegraphAdditGain[15]
	float instrumentScaleFactor[15]
	float signalGain[15]
	float ADCProgrammableGain[15]
	float instrumentOffset[15]
	float signalOffset[15]
	
	//ADC extras
	//string recChNames
	//string recChUnits
	//int16 telegraphEnable[3]
	//float telegraphAdditGain[3]
	//float instrumentScaleFactor[3]
	//float signalGain[3]
	//float ADCProgrammableGain[3]
	//float instrumentOffset[3]
	//float signalOffset[3]
	
	//Protocol extras
	int16 operationMode
	float synchTimeUnit
	int16 ADCNumChannels
	float actualAcqLength
	float dataSectionPtr
	int16 numPointsIgnored
	float ADCSampleInterval
	float ADCRange
	int32 ADCResolution
	float synchArrayPtr
	float synchArraySize
	
	//More extras
	float si
	float synchArrTimeBase
	float synchArrayPtrByte
	float sweepLengthInPts
	float recTime[2]
	float dataPts
	int32 dataPtsPerChan
EndStructure

Structure protocolInfo
	int16 operationMode
	float ADCSequenceInterval
	int16 enableFileCompression //bit1?
	char unused1[3]
	uint32 fileCompressionRatio
	float synchTimeUnit
	float secondsPerRun
	int32 numSamplesPerEpisode
	int32 preTriggerSamples
	int32 episodesPerRun
	int32 runsPerTrial
	int32 numberOfTrials
	int16 averagingMode
	int16 undoRunCount
	int16 firstEpisodeInRun
	float triggerThreshold
	int16 triggerSource
	int16 triggerAction
	int16 triggerPolarity
	float scopeOutputInterval
	float episodeStartToStart
	float runStartToStart
	int32 averageCount
	float trialStartToStart
	int16 autoTriggerStrategy
	float firstRunDelayS
	int16 channelStatsStrategy
	int32 samplesPerTrace
	int32 startDisplayNum
	int32 finishDisplayNum
	int16 showPNRawData
	float statisticsPeriod
	int32 statisticsMeasurements
	int16 statisticsSaveStrategy
	float ADCRange
	float DACRange
	int32 ADCResolution
	int32 DACResolution
	int16 experimentType
	int16 manualInfoStrategy
	int16 commentsEnable
	int32 fileCommentIndex
	int16 autoAnalyseEnable
	int16 signalType
	int16 digitalHolding
	int16 digitalInterEpisode
	int16 digitalDACChannel
	int16 digitalTrainActiveLogic
	int16 statsEnable
	int16 statisticsClearStrategy
	int16 levelHysteresis
	int32 timeHysteresis
	int16 allowExternalTags
	int16 averageAlgorithm
	float averageWeighting
	int16 undoPromptStrategy
	int16 trialTriggerSource
	int16 statisticsDisplayStrategy
	int16 externalTagType
	int16 scopeTriggerOut
	int16 LTPType
	int16 alternateDACOutputState
	int16 alternateDigitalOutputState
	float cellID[3]
	int16 digitizerADCs
	int16 digitizerDACs
	int16 digitizerTotalDigitalOuts
	int16 digitizerSynchDigitalOuts
	int16 digitizerType
	
EndStructure
	
Structure ADCinfo
	int16 ADCNum
	int16 telegraphEnable
	int16 telegraphInstrument
	float telegraphAdditGain
	float telegraphFilter
	float telegraphMembraneCap
	int16 telegraphMode
	float telegraphAccessResistance
	int16 ADCPtoLChannelMap
	int16 ADCSamplingSeq
	float ADCProgrammableGain
	float ADCDisplayAmplification
	float ADCDisplayOffset
	float instrumentScaleFactor
	float instrumentOffset
	float signalGain
	float signalOffset
	float signalLowpassFilter
	float signalHighpassFilter
	char lowpassFilterType
	char highpassFilterType
	float postProcessLowpassFilter
	char postProcessLowpassFilterType
	int16 enabledDuringPN //bit1?
	int16 StatsChannelPolarity
	int32 ADCChannelNameIndex
	int32 ADCUnitsIndex
EndStructure

Structure tagInfo
	int32 tagTime
	char comment
	int16 tagType
	int16 voiceTagNumber
EndStructure

Structure DTableValues
	String prefix
	String group
	String series
	String sweep
	String trace
	String TF
	String comment
	String filepath
EndStructure

Function LoadABF([fromAT])
	Variable fromAT
	SVAR alreadyLoaded = root:Packages:analysisTools:alreadyLoaded
	
	If(ParamIsDefault(fromAT))
		fromAT = 0
	EndIf
	
	Variable doLoad = 1

	//doLoad = 1 to actually load the data
	//doLoad = 0 to index the data and print a dTable
	
	SVAR ABF_filename = root:ABFvar:ABF_filename

	If(fromAT)
		String dtableName = "DTable_Browse"
	Else
		dtableName = "DTable_" + ABF_filename
	EndIf
	
	String info = TableInfo(dtableName,-2)
	Variable i,numRows = str2num(StringByKey("ROWS",info,":",";"))
	
	SVAR ABF_lines = root:ABFvar:ABF_lines
	//Load everything if it isn't specified
	
	If(!fromAT)
		If(!strlen(ABF_lines))
			ABF_lines = "0-" + num2str(numRows-1)
		EndIf
	Else
		//get line numbers from fileListBox selection in AT
		ABF_lines = ""
		Wave ABF_FileSelWave = root:Packages:analysisTools:ABF_FileSelWave
		For(i=0;i<DimSize(ABF_FileSelWave,0);i+=1)
			If(ABF_FileSelWave[i])
				ABF_lines += num2str(i) + ";"
			EndIf
		EndFor
		
	EndIf
	
	String lines = resolveListItems(ABF_lines,";")
	
	Variable numLines = ItemsInList(lines,";")
	Variable dti

	//Loop through each line on the dtable
	For(i=0;i<numLines;i+=1)
		Variable doSkip = 0	//doesn't reload if the waves are already there
		
		dti = str2num(StringFromList(i,lines,";"))
	
		If(dti > numRows - 1) 
			Abort "The row: " + num2str(dti) + " does not exist" 
		EndIf
		
		String folderPath = GetFolderPath(dti,fromAT=fromAT)
		If(!strlen(folderPath))
			break
		EndIf
		String filebase = GetFileBase(folderPath)
		String index = GetIndex(dti,fromAT=fromAT)
		String whichChannel = GetChannelStr(dti,fromAT=fromAT)
		String errorStr = ""
	
		//Set folder to new HekaFile according to filepath	
		If(fromAT)
			Variable j = 0
			String objName
			String hekaFile = "root:Packages:analysisTools:ABF_Browser"
			//check if the file already has been loaded, if so skip.
			SetDataFolder root:Packages:analysisTools:ABF_Browser
			Do
				objName = GetIndexedObjName("root:Packages:analysisTools:ABF_Browser:",1,j)
				If (strlen(objName) == 0)
					break
				EndIf
				
				String theNote = note($objName)
				
				If(str2num(index) < 10)
					String indexStr = "000" + index
				ElseIf(str2num(index) > 9 && str2num(index) < 100)
					indexStr = "00" + index
				ElseIf(str2num(index) > 99)
					indexStr = "0" + index
				Else
					indexStr = index
				EndIf
				
				String fullWavePath = folderPath + ":" + filebase + "_" + indexStr + ".abf"
				
				If(stringmatch(theNote,fullWavePath))
					//skip loading this one
					doSkip = 1
					break
				EndIf
				j+=1
			While(1)
		Else
			hekaFile = "root:HekaFile:" + ParseFilePath(0,folderPath,":",1,0)
			If(!DataFolderExists("root:HekaFile"))
				NewDataFolder root:HekaFile
			EndIf
		EndIf
		
		If(!DataFolderExists(hekaFile))
			NewDataFolder $hekaFile
		EndIf
		
		SetDataFolder $hekaFile
		
		If(!doSkip)
			errorStr = ABF_LoadWaves(folderPath,filebase,index,whichChannel,doLoad)
		
			If(strlen(errorStr))
				DoAlert 0,"Some waves were unable to be loaded."
				print errorStr
			EndIf
			
		EndIf
	EndFor
End

Function/S GetFolderPath(dti,[fromAT])
	Variable dti,fromAT
	SVAR ABF_filename = root:ABFvar:ABF_filename
	String dtableName
	
	If(ParamIsDefault(fromAT))
		fromAT = 0
	EndIf
	
	If(fromAT)
		dtableName = "DTable_Browse"
	Else
		dtableName = "DTable_" + ABF_filename
	EndIf
	
	//Data Table info
	String info = TableInfo(dtableName,7)
	If(!strlen(info))
		return ""
	EndIf
	
	Wave/T filePathWave = $StringByKey("WAVE",info,":",";")
	
	String folderPath = filePathWave[dti]
	
	return folderPath
End

Function/S GetFileBase(folderPath)
	String folderPath
	String filebase = ParseFilePath(0,folderPath,":",1,0)
	return filebase
End

Function/S GetIndex(dti,[fromAT])
	Variable dti,fromAT
	SVAR ABF_filename = root:ABFvar:ABF_filename
	String dtableName
	
	If(ParamIsDefault(fromAT))
		fromAT = 0
	EndIf
	
	If(fromAT)
		dtableName = "DTable_Browse"
	Else
		dtableName = "DTable_" + ABF_filename
	EndIf
	
	String info = TableInfo(dTableName,2)
	Wave/T sweepWave = $StringByKey("WAVE",info,":",";")
	
	String index = sweepWave[dti]
	return index
End

Function/S GetChannelStr(dti,[fromAT])
	Variable dti,fromAT
	SVAR ABF_filename = root:ABFvar:ABF_filename
	String dtableName
	
	If(fromAT)
		dtableName = "DTable_Browse"
	Else
		dtableName = "DTable_" + ABF_filename
	EndIf
	
	String info = TableInfo(dTableName,4)
	Wave/T traceWave = $StringByKey("WAVE",info,":",";")
	
	String whichChannel = traceWave[dti]
	return whichChannel
End

Function/S ABF_GetFilePath(folderpath,filebase,index)
	String folderpath,filebase,index
	Variable numel,i,j,first,last
	String item,itemList,lastCharacter,convertItem
	
	//Make sure folderpath has ":" at end to append filebase to it
	lastCharacter = folderpath[strlen(folderpath) - 1]
	If(!StringMatch(lastCharacter,":"))
		folderpath += ":"
	EndIf
	
	itemList = ""
	numel = ItemsInList(index,",")
	//Get index list
	For(i=0;i<numel;i+=1)
		item = StringFromList(i,index,",")
		If(stringmatch(item,"*-*"))
			first = str2num(StringFromList(0,item,"-"))
			last = str2num(StringFromList(1,item,"-"))
			For(j=first;j<=last;j+=1)
				If(j<10)
					itemList += folderpath + filebase + "_000" + num2str(j) + ".abf;"
				ElseIf(j<100)
					itemList += folderpath + filebase + "_00" + num2str(j) + ".abf;"
				ElseIf(j<1000)
					itemList += folderpath + filebase + "_0" + num2str(j) + ".abf;"
				EndIf
			EndFor
		Else
			If(str2num(item)<10)
				itemList += folderpath + filebase + "_000" + item + ".abf;"
			ElseIf(str2num(item)<100)
				itemList += folderpath + filebase + "_00" + item + ".abf;"
			ElseIf(str2num(item)<1000)
				itemList += folderpath + filebase + "_0" + item + ".abf;"
			EndIf
		EndIf
	EndFor

	itemList = RemoveEnding(itemList,";")
	return itemList	
End

Function/S ABF_LoadWaves(folderpath,filebase,index,whichChannel,doLoad)
	String folderpath,filebase,index
	String whichChannel
	Variable doLoad
	Variable i,numFiles
	String fileList,filepath
	String errorStr = ""
	//Variable refTime = StartMSTimer
	
	fileList = ABF_GetFilePath(folderpath,filebase,index)
	numFiles = ItemsInList(fileList,";")
	
	For(i=0;i<numFiles;i+=1)
		filepath = StringFromList(i,fileList,";")
		GetFileFolderInfo/Q/Z filepath
	
		If(V_flag != 0)	//file doesn't exist
			//Removes prefix in case I forgot to add R2 designation 
			String fileName = ParseFilePath(0,filepath,":",1,0)
			filepath = ParseFilePath(1,filepath,":",1,0)
			fileName = RemoveFromList(StringFromList(0,fileName,"_"),fileName,"_")
			filepath += fileName
		EndIf
		
		GetFileFolderInfo/Q/Z filepath
		If(V_flag != 0)	//file doesn't exist
			errorStr += "Couldn't find file: " + filepath + "\r"
			continue
		EndIf
		Variable refTime = StartMSTimer
		ABFLoader(filepath,whichChannel,doLoad)
		
		Variable duration = StopMSTimer(refTime)/1000000
		print "Loaded",filepath,"in",duration,"s"
	EndFor
	return errorStr
End

Function SeparateChannels(filepath,traceName,tempd,h,dataPtsPerSweep,whichChannel,chInd)
	String filepath,traceName
	Wave tempd
	STRUCT headerParameters &h
	Variable dataPtsPerSweep
	String whichChannel
	Wave chInd
	Variable i,j
	String cdf = GetDataFolder(1)
	
	j = 0
	Make/O/N=(dataPtsPerSweep/h.ADCNumChannels,h.ADCNumChannels) $(cdf + "allChannels")	//name from the first trace name
	Wave d = $(cdf + "allChannels")
	
	switch(h.ADCNumChannels)
		case 2:
			For(i=1;i<DimSize(tempd,0);i+=2)
				d[j][1] = tempd[i][0]
				d[j][0] = tempd[i-1][0]
				j+=1 
			EndFor
		break
		case 3:
			For(i=2;i<DimSize(tempd,0);i+=3)
				d[j][2] = tempd[i][0]
				d[j][1] = tempd[i-1][0]
				d[j][0] = tempd[i-2][0]
				j+=1
			EndFor
		break
		case 4:
			For(i=3;i<DimSize(tempd,0);i+=4)
				d[j][3] = tempd[i][0]
				d[j][2] = tempd[i-1][0]
				d[j][1] = tempd[i-2][0]
				d[j][0] = tempd[i-3][0]
				j+=1
			EndFor
		break
		default:
			d[] = tempd[p][0]
		break
	endswitch
	
	//Apply scale factors and gains
	Wave addGain = root:ABFvar:addGain
	For(i=0;i<DimSize(d,1);i+=1)
		//d[][i-1] = (1e-12)*(d[p][i-1])/(h.InstrumentScaleFactor[i]*h.signalGain[i]*h.ADCProgrammableGain[i]*addGain[i])*(h.ADCRange/h.ADCResolution) + h.instrumentOffset[i] - h.signalOffset[i]
		Variable index = chInd[i]// - 1
		
		//Scale by the units
		String unitStr = StringFromList(i,h.recChUnits,";")
		String unitChar = unitStr[0]
		Variable unitScaleFactor
		strswitch(unitChar)
			case "m":
			//milli
				unitScaleFactor = 1e-3
				break
			case "µ":
			//micro
				unitScaleFactor = 1e-6
				break
			case "n":
			//nano
				unitScaleFactor = 1e-9
				break
			case "p":
			//pico
				unitScaleFactor = 1e-12
				break
			default:
				unitScaleFactor = 1
				break
		endswitch
		
		d[][i] = unitScaleFactor*(d[p][i])/(h.InstrumentScaleFactor[index]*h.signalGain[index]*h.ADCProgrammableGain[index]*addGain[index])*(h.ADCRange/h.ADCResolution) + h.instrumentOffset[index] - h.signalOffset[index]
	EndFor
	
	
	ControlInfo/W=ABF2Loader ABF_LoadStimData
	String stimChannel = S_Value
	
	String channelList = resolveListItems(whichChannel,";")
	
	//extract the designated stimulus channel here
	If(cmpstr(stimChannel,"None"))
		Variable channelPos = str2num(stimChannel) - 1
		Make/FREE/N=(DimSize(d,0)) stimWave
		stimWave[] = d[p][channelPos]
		SetScale/P x,0,h.si/(1e6),"s",stimWave
		
		String stimName = decodeStimulusASCII(stimWave)
	EndIf
	
	For(j=0;j<ItemsInList(channelList,";");j+=1)
		Variable theChannel = str2num(StringFromList(j,channelList,";"))
		Make/O/N=(DimSize(d,0)) $StringFromList(j,traceName,";")
		Wave outWave = $StringFromList(j,traceName,";")
		
		outWave[] = d[p][theChannel-1]
		SetScale/P x,0,h.si/(1e6),"s",outWave
		Note/K outWave,filepath
		
		//Append stimulus name
		If(cmpstr(stimChannel,"None"))
			Note outWave,"Stimulus: " + stimName
		EndIf
	EndFor
	
	//Cleanup
	KillWaves/Z d

End

Function/S GenerateTraceName(filepath,i,whichChannel)
	String filepath
	Variable i
	String whichChannel
	String prefix,group,series,sweep,trace,traceName,traceByComma
	Variable totalChannels,j
	
	prefix = "Imon"
	group = "1"
	series = ParseFilePath(0,filePath,":",1,0)
	series = ParseFilePath(0,series,"_",1,0)
	series = ParseFilePath(0,series,".",0,0)
	series = num2str(str2num(series))
	sweep = num2str(i+1)
	//trace = num2str(whichChannel)
	
	traceName = ""
	trace = resolveListItems(whichChannel,";")
	
	//Get the list of trace names for every channel
	For(j=0;j<ItemsInList(trace,";");j+=1)
		traceName += prefix + "_" + group + "_" + series + "_" + sweep + "_" + StringFromList(j,trace,";") + ";"
	EndFor
	
	return traceName
End

Function/T ABF_MakeUniqueWave(name,type,npnts)
	String name,type; Variable npnts
	
	Variable j
	String newname=name
	for(j=0;exists(newname);j+=1)
		newname = name+"_"+num2str(j); 
	endfor
	if(cmpstr(type,"TEXT")==0)
		Make/T/N=(npnts) $newname
	else
		Make/N=(npnts) $newname
	endif
	return newname
End

// Makes the waves for a new command or data table. If a tablename is not supplied, it generates a unique name.
Function/S MakeNewTable(type,tablename,hookFunction,numLines[,left,top,right,bottom])
	Variable type; String tablename,hookFunction; Variable numLines,left,top,right,bottom

	SVAR CmdTab_tag = root:ABFvar:CmdTab_tag; 
	SVAR Dtab_tag = root:ABFvar:Dtab_tag
	Variable j, num
	String windowList,fldrwaveList,newWaveList, theWave, tableSize=""
	DFREF saveDFR = GetDataFolderDFR()
	
	if( !ParamIsDefault(left) && !ParamIsDefault(top) && !ParamIsDefault(right) && !ParamIsDefault(bottom) )
		tableSize="/W=("+num2str(left)+","+num2str(top)+","+num2str(right)+","+num2str(bottom)+")"
	endif
	// Get a unique name for the table.
	windowList = WinList("*",";","")

	if(!strlen(tablename))
		tablename = Dtab_tag+"Table"; num=strlen(Dtab_tag)
	endif

	for(j=0;ABF_WinExists(tableName);j+=1)
		tableName = tableName[0,num-1]+"Table"+num2str(j)
	endfor
	
	// Create the table folder
	if(!DataFolderExists("root:CmdTableWaves"))
       	NewDataFolder/S root:CmdTableWaves
	else
		SetDataFolder root:CmdTableWaves
	endif
	SetDataFolder root:CmdTableWaves
	
	SVAR tableColumnLabels = root:CmdTableWaves:DtabColumnLabels;
	SVAR tableColumnWidths = root:CmdTableWaves:DtabColumnWidths;
	SVAR tableColumnAlign = root:CmdTableWaves:DtabColumnAlign;
	SVAR theWaveList = root:CmdTableWaves:DtabWaveList;
	SVAR theWaveTypes = root:CmdTableWaves:DtabWaveTypes

	// Clean folder
	fldrwaveList=DataFolderDir(2)
	fldrwaveList = StringByKey("WAVES",fldrwaveList,":",";")
	for(j=0;j<itemsinlist(fldrwaveList,",");j+=1)
		Killwaves/Z $StringFromList(j,fldrwaveList,",")
	endfor
	
	// Make unique waves or over write existins ones
	newWaveList=""
	for(j=0;j<itemsinlist(theWaveList);j+=1)
			newWaveList += ABF_MakeUniqueWave(StringFromList(j,theWaveList),StringFromList(j,theWaveTypes),numLines)+";"
	endfor
	
	//BMB, added to handle .phys2 file types, this just allows me to pass the newWaveList on to the LoadPhysTable function.
	String/G root:ABFvar:tableWaveList
	SVAR  tableWaveList = root:ABFvar:tableWaveList
	tableWaveList = newWaveList
	////
	
	// Create the table
	// How wide?
	for(j=0, num=0;j<itemsinlist(tableColumnWidths);j+=1)
		num+=str2num(StringFromList(j,tableColumnWidths))
	endfor
	Execute "Edit/K=1"+tableSize+" as \""+tablename+"\""
	ModifyTable width[0]=20
	for(j=0;j<itemsinlist(newWaveList);j+=1)
		theWave = StringFromList(j,newWaveList)
		AppendToTable $theWave
		Execute "ModifyTable title("+theWave+")=\""+StringFromList(j,tableColumnLabels)+"\""
		ModifyTable width[j+1]=str2num(StringFromList(j,tableColumnWidths))
		ModifyTable alignment($theWave)=str2num(StringFromList(j,tableColumnAlign))
	endfor
	DoWindow/C $tablename; 
	if(!strlen(hookFunction))
		SetWindow $tablename, hook(defaultHook)=hookKillCmdTableWaves
	elseif(cmpstr(hookFunction,"NoHook"))
		SetWindow $tablename, hook(userHook)=$hookFunction
	endif
	
	SetDataFolder saveDFR
	return tablename
End

Function ABF_WinExists(theWindowName)//,theWindowType)
       String theWindowName;// Variable theWindowType
	
	return ((WhichListItem(stringfromlist(0,theWindowName,"#"), WinList("*",";",""))>=0) ? 1 : 0)
End

//Indexes the file without loading data, and prints out a dTable of the contents
Function/S IndexABF(ABF_filename,fullpath,fileList,[fromAT])
	String ABF_filename,fullpath,fileList
	Variable fromAT
	Variable i,j,doLoad
	String info,item
	
	If(ParamIsDefault(fromAT))
		fromAT = 0
	EndIf
	
	doLoad = 0
	For(i=0;i<ItemsInList(fileList,";");i+=1)
		String theFile = StringFromList(i,fileList,";")
		String filepath = fullpath + ":" + theFile
		ABFLoader(filepath,"1",doLoad)
	
	
		If(WaveExists(root:ABFvar:dTable_Values))
			Wave/T dTable_Values = root:ABFvar:dTable_Values
			
			If(!fromAT)
				String tableName = "DTable_" + ABF_filename
			Else
				tableName = "DTable_Browse"
			EndIf
			
			//Create dTable
			DoWindow $tableName
			If(!V_flag)
				MakeNewTable(1,tableName,"",1)
			EndIf
				
			//Fill out dTable
			For(j=0;j<8;j+=1)
				info = TableInfo(tableName,j)
				item = StringByKey("WAVE",info,":",";")
				
				//TF is a numeric wave, the rest are string waves
				If(StringMatch(item,"*TF*"))
					Wave columnWaveNUM = $item
					Redimension/N=(i+1) columnWaveNUM
					columnWaveNUM[i] = str2num(dTable_Values[j])
				Else
					Wave/T columnWaveSTR = $item
					Redimension/N=(i+1) columnWaveSTR
					columnWaveSTR[i] = dTable_Values[j]
				EndIf
				
			EndFor
		Else
			DoAlert 0,"Couldn't get dTable Values for: " + filepath
			break
		EndIf

	
	EndFor

End

Function ABF2_BrowseFiles(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	SVAR ABF_folderpath = root:ABFvar:ABF_folderpath
	SVAR ABF_filename = root:ABFvar:ABF_filename
	
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			strswitch(ba.ctrlName)
				case "ABF_Browse":
					Variable refnum
					String message = "Select the data folder to index"
					String fileFilters = "All Files:.*;"
					Open/D/R/F=fileFilters/M=message refnum
					ABF_folderpath = ParseFilePath(1,S_fileName,":",1,1)
					ABF_filename = ParseFilePath(0,S_fileName,":",1,1)
					Close/A
					break
				case "ABF_Index":
					String fullPath = ABF_folderpath + ABF_filename
					NewPath/O/Q/Z ABFpath,fullpath
					String fileList = IndexedFile(ABFpath,-1,".abf")
					fileList = SortList(fileList,";",16)
					IndexABF(ABF_filename,fullpath,fileList)
					break
				case "ABF_LoadWaves":
					LoadABF()
					break
			endswitch
		case -1: // control being killed
			break
	endswitch

	return 0
End


//Decodes binary data from the nidaq boards into ASCII codes
Function/S decodeStimulusASCII(inWave)
	Wave inWave
	String bits = ""
	
	//ending X point of the wave
	Variable startX,endX,delta,lastRise
	startX = DimOffset(inWave,0)
	endX = pnt2x(inWave,DimSize(inWave,0) - 1)
	delta = 0
	
	Do
		//initial rising edge of block indicating first bit
		FindLevel/Q/EDGE=1/R=(startX,endX) inWave,3
		startX = V_LevelX
		
		//no levels found
		If(V_flag)
			break
		EndIf
		
		//initial falling edge of block indicating first bit
		FindLevel/Q/EDGE=2/R=(startX,endX) inWave,3
		
		// duration for the block will be variable. Need to adjust bit detection accordingly
		delta = V_LevelX - startX
		
		//small delta means end of sequence
		If(delta < 0.0005)
			FindLevels/Q/EDGE=1/R=(lastRise - 2 * deltax(inWave),endX) inWave,3
			If(V_LevelsFound == 3)
				bits[strlen(bits)-1] = "0"
			EndIf
			break
		EndIf
		
		//replace start x point with previous falling level
		startX = V_LevelX
		
		//detects the leading edge of bit as high or low
		//time period it searches is adjusted according to previous block length
		FindLevel/Q/EDGE=1/R=(startX,startX + delta) inWave,3
		lastRise = V_LevelX
		
		If(numtype(lastRise) == 2)
			lastRise = startX
			bits += "0"
		EndIf
		
		//found edge within delta
		If(!V_flag) 
			//is there a corresponding falling edge with 1/3 delta?
			FindLevel/Q/EDGE=2/R=(lastRise,lastRise + delta/3) inWave,3
			
			If(!V_flag)
				bits += "1"
				//new start x is the falling edge of the bit
				startX = V_LevelX
			Else
				bits += "0"
				//last rising edge must have been start of next block
				startX = lastRise - 2 * deltax(inWave) //back up a couple points to redetect block rising edge on next loop
			EndIf
		EndIf
	While(1)
	
	KillWaves/Z W_FindLevels
	
	String outputStr = binaryToStr(bits)
	return outputStr
End

//Takes binary sequence and converts it to ASCII codes, then converts that to a string
Function/S binaryToStr(input)
	String input
	Variable len = strlen(input)
	Variable numChars = len / 8
	Variable i,j,total,startPos,endPos
	String asciiStr = ""
	String output = ""
	Variable asciiCode
	
	startPos = 0 
	endPos = 7
	
	For(i=0;i<numChars;i+=1)
		total = 0
		String word = input[startPos,endPos]
		
		For(j=0;j<8;j+=1)
			Variable char = str2num(word[j])
			total = total * 2 + char
		EndFor
		
		asciiStr += num2str(total) + ";"
		startPos += 8
		endPos += 8
	EndFor
	
	For(i=0;i<numChars;i+=1)
		asciiCode = str2num(StringFromList(i,asciiStr,";"))
		output += num2char(asciiCode)
	EndFor
	
	return output
End