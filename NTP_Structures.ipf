#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//Holds parameters of the ROIs for call by functions
Structure IMAGING
	STRUCT ROI roi
	STRUCT SCAN scan
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
	Wave/T listWave //listwave being used by the data set (Wave Match, Navigator, or a Data Set)
	Wave/T name //holds data set names
	Wave/T paths //string list of the waves in the wsn
	Wave/WAVE output //holds the wave references for any output waves
	Wave/WAVE waves //wave of wave references for the wsn
	Wave numWaveSets //number of wave sets
	int16 wsi //current wave set index
	int16 wsn //current wave set number
	Wave numWaves //number of waves in the current wsn for each data set
	int16 numDataSets //number of datasets defined
EndStructure 

//Data set info structure
Structure ds_numOnly
	int16 numWaveSets //number of wave sets
	int16 wsi //current wave set index
	int16 wsn //current wave set number
	int16 numWaves //number of waves in the current wsn6 
	int16 numDataSets //number of data sets 
//	int16 value
//	int16 count
//	int16 steps
//	float increment
EndStructure

//Data set info structure
//Structure ds_progress_numOnly
//	int16 value
//	int16 count
//	int16 steps
//	float increment
//EndStructure

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
	SVAR pos6
	SVAR pos7
	SVAR wg
	
	SVAR name
	SVAR path
EndStructure

//holds progress bar data
//Structure progress
//	//Since we're running SI functions using 'Execute', we need changing variables to be saved as global variables,
//	//that way we won't lose the current value between subsequent function calls.
//	
//	NVAR value //current value of the progress bar
//	NVAR count //current step during the task
//	int16 steps //total number of increments to complete the task
//	float increment //size of each increment	
//EndStructure


//Workflow info structure
Structure workflow
	int16 numCmds	//total number of commands in workflow
	int16 i //command index
	Wave/T cmds //holds the commands in workflow
EndStructure
