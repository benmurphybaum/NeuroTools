#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function NT_MyNewFunction(DS_Waves,Threshold,Amplitude)
	//SUBMENU=DS Functions
	//TITLE=New Function
	
	String DS_Waves
	Variable Threshold,Amplitude

	STRUCT ds ds
	GetStruct(ds)
	
	print ds
End