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

End

Function NT_function2()

End

Function nothing()

End

//Put your own functions here.

//Put the prefix 'NT_' on your functions that you want to include in the 'External Function' menu.

//Functions without the 'NT_' prefix aren't included in the list, and can be used as subroutines
	//for the main 'NT_' functions. 
	
