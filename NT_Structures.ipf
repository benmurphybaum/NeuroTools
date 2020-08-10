#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//Holds parameters of the ROIs for call by functions
Structure IMAGING
	STRUCT ROI roi
	STRUCT SCAN scan
	uint16 channel
	uint16 mode
	uint16 bsSt
	uint16 bsEnd
	uint16 pkSt
	uint16 pkEnd
	uint16 filter
	uint16 preFilter
	uint16 postFilter
	SVAR measure
	Wave/T rois
EndStructure

Structure ROI
	Wave/WAVE x
	Wave/WAVE y
	uint16 num
EndStructure

Structure SCAN
	Wave/WAVE ch1
	Wave/WAVE ch2
	uint16 num
EndStructure

//Data set info structure
Structure ds
	STRUCT progress progress
	Wave/T listWave //listwave being used by the data set (Wave Match, Navigator, or a Data Set)
	SVAR name	 //data set name
	SVAR paths //string list of the waves in the wsn
	Wave/WAVE waves //wave of wave references for the wsn
	int16 num //number of wave sets
	int16 wsi //current wave set index
	int16 wsn //current wave set number
	int16 numWaves //number of waves in the current wsn
EndStructure

//Data set info structure
Structure ds_numOnly
	int16 num //number of wave sets
	int16 wsi //current wave set index
	int16 wsn //current wave set number
	int16 numWaves //number of waves in the current wsn6 
	int16 value
	int16 count
	int16 steps
	float increment
EndStructure

//Data set info structure
Structure ds_progress_numOnly
	int16 value
	int16 count
	int16 steps
	float increment
EndStructure

//Structure to hold all of the filter terms, wave grouping terms, and match terms
Structure filters
	SVAR match
	SVAR notMatch
	SVAR relFolder
	
	SVAR prefix
	SVAR group
	SVAR series
	SVAR sweep
	SVAR trace
	SVAR wg
	
	SVAR name
	SVAR path
EndStructure

//holds progress bar data
Structure progress
	//Since we're running SI functions using 'Execute', we need changing variables to be saved as global variables,
	//that way we won't lose the current value between subsequent function calls.
	
	NVAR value //current value of the progress bar
	NVAR count //current step during the task
	int16 steps //total number of increments to complete the task
	float increment //size of each increment	
EndStructure


//Workflow info structure
Structure workflow
	int16 numCmds	//total number of commands in workflow
	int16 i //command index
	Wave/T cmds //holds the commands in workflow
EndStructure