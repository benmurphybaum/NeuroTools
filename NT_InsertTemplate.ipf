#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.


//Template code for writing your own functions in NeuroTools.
//Copy and paste this into 'NT_ExternalProcedures.ipf', and add in your function to the loop.

Function NT_MyFunction()
	//Data set info structure
	STRUCT ds ds 
	
	//Fills the data set structure
	GetStruct(ds)
	
	//Reset wave set index
	ds.wsi = 0
	
	//Name of the output wave that will hold the results
	String outputName = NameOfWave(ds.waves[0]) + "_out"
	
	//Make the output wave 
	Make/O/N=(DimSize(ds.waves[0],0),DimSize(ds.waves[0],1),DimSize(ds.waves[0],2)) $outputName/Wave = outWave
	
	//Function Loop
	Do
		//declare each wave in the wave set
		Wave theWave = ds.waves[ds.wsi]
		
		//YOUR CODE GOES HERE....
		
		
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves)
	
End