#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//RESERVED FUNCTION, don't change or remove. 
Function ArrangeProcWindows()
	MoveWindow/P=$"NT_InsertTemplate.ipf" 0,0,600,600
	MoveWindow/P=$"NT_ExternalFunctions.ipf" 600,0,1200,600
	
End

Function NT_function1(param1,param2,param3,theWave,ds_myDS)
	Variable param1,param3
	String param2
	Wave theWave
	String ds_myDS //this is a data set
	
	//Gets the structure
	STRUCT ds ds
	GetStruct(ds)
	
	print "Param1:",param1
	print "Param2:",param2
	print NameOfWave(theWave)

	Variable i
	For(i=0;i<DimSize(ds.waves,0);i+=1)
		Wave myWave = ds.waves[i]
		print "DS Wave:",GetWavesDataFolder(myWave,2)
	EndFor
End

Function NT_function2()

End

Function nothing()

End

//Put your own functions here.

//Put the prefix 'NT_' on your functions that you want to include in the 'External Function' menu.

//Functions without the 'NT_' prefix aren't included in the list, and can be used as subroutines
	//for the main 'NT_' functions. 
	
Function NT_PrintNames(ds_DataSetEntry)
	String ds_DataSetEntry
	
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
	
	//YOUR CODE GOES HERE....
	print ds.wsn,"---------------"
		
	//Function Loop
	Do
		//declare each wave in the wave set
		Wave theWave = ds.waves[ds.wsi]
		
		
		print GetWavesDataFolder(ds.waves[ds.wsi],2)
		
		
		ds.wsi += 1
	While(ds.wsi < ds.numWaves)
	
End