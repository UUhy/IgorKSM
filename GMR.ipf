#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function KSM_init()
	// Initialize the Keithley 2400 SourceMeter (KSM)
	
	// Initialize the data folder for the KSM
	String savDF= GetDataFolder(1) 			// Save current DF for restore.
	NewDataFolder/O/S root:Packages 			// Create and set data folder to root:Packages
	
	if(!DataFolderExists("Keithley2400") ) 		// Does data folder Keithley2400 exist?
		NewDataFolder/S Keithley2400 		// Create data folder and all variables
		
		//General settings
		String/G terminal = "front"				// Set the terminals to "front" or "back"
		String/G remoteSensing = "on"			// Turn "on" or "off" remote sensing
		String/G autoZero = "on"				// Turn "on" or "off" auto zero function
		String/G autoOutputOff = "off"			// Turn "on" or "off" auto output zero function
		String/G displayEnable = "on"			// Turn "on" or "off" display
		Variable/G displayDigit = 7				// Set the display digits to 4, 5, 6 or 7
		String/G NPLC = "1"					// Set the NPLC to 0.01, 0.1, 1, or 10
		
		//Source settings
		String/G sourceMode = "current"		// Set the source mode to "current" or "voltage"
		String/G sourceAutoDelay = "off"		// Set the source auto delay to "on" or "off"
		Variable/G sourceDelay = 0			// Set the source delay
		Variable/G sourceCurrentLevel = 1e-3	// Set the source current level
		String/g output = "off"					// Set the output "on" or "off"
		
		//Sense settings
		String/G senseMode = "voltage"
		Variable/G senseVoltageCompl = 2
		Variable/G senseVoltageRange = 500e-3
		
		//Data storage settings
		String/G bufferEnable = "off"				// Stop the buffer
		Variable/G bufferSize = 100
		String/G bufferTimestamp = "delta"			// Use the delta timestamp
		Variable/G samplingRate = 5
		Variable/G triggerDelay = 0
		Variable/G triggerCount = 100
		Variable/G readStartTime = DateTime		// read start time
		
	else
		SetDataFolder Keithley2400 				// Set data folder and initialize all variables
		SVAR terminal, remoteSensing, autoZero, autoOutputOff, displayEnable, NPLC
		NVAR displayDigit
		terminal = "front"
		remoteSensing = "on"
		autoZero = "off"
		autoOutputOff = "off"
		displayEnable = "on"
		displayDigit = 7
		NPLC = "1"
		
		SVAR sourceMode, sourceAutoDelay, output
		NVAR sourceDelay, currentLevel
		sourceMode = "current"
		sourceAutoDelay = "off"
		sourceDelay = 0
		sourceCurrentLevel = 1e-3
		output = "off"
		
		SVAR senseMode
		NVAR senseVoltageCompl, senseVoltageRange
		senseMode = "voltage"
		senseVoltageCompl = 2
		senseVoltageRange = 500e-3
		
		SVAR bufferEnable, bufferTimestamp
		NVAR bufferSize, samplingRate, triggerDelay, triggerCount, readStartTime
		bufferEnable = "off"
		bufferSize = 100
		bufferTimestamp = "delta"
		samplingRate = 5
		triggerDelay = 0
		triggerCount = 100
		readStartTime = DateTime
	endif
	SetDataFolder savDF 							// Restore current DF
	
	KSM_initGPIB()								// Initialize GPIB communcation
End

Function KSM_initGPIB()
	//Initialize communication with the KSM Sourcemeter

	// Declare variables
	Variable gBoardAddress = 0			//Board address
	Variable gDeviceAddress = 24			//Device address
	Variable gBoardUnitDescriptor			//GPIB board descriptor
	Variable gDeviceKSM			//Device descriptor

	// Determine the unit descriptors.
	NI4882 ibfind={"gpib0"}; gBoardUnitDescriptor = V_flag
	NI4882 ibdev={gBoardAddress,gDeviceAddress,0,13,1,0}; gDeviceKSM = V_flag

	// Set active board and device for high-level GPIB operations
	GPIB2 board=gBoardUnitDescriptor		// Board to use for GPIB commands
	GPIB2 device=gDeviceKSM		// Device to use for GPIB commands

	// Make sure we are in a clean state.
	GPIB2 KillIO								// Initialize GPIB and sends Interface Clear message.
		
	// Query the identification of the device
	String status
	GPIBWrite2 "*IDN?"
	GPIBRead2 /T="\r" status
	Print status
End

Function KSM_initSource()
	// Initialize the device to source current and measure voltage
	
	String savDF= GetDataFolder(1) 			// Save current DF for restore.
	SetDataFolder root:Packages:Keithley2400
	
	NVAR sourceCurrentLevel, senseVoltageRange, senseVoltageCompl
	SVAR terminal
	
	KSM_reset()
	KSM_remoteSensing("on")
	KSM_autoZero("on")
	KSM_sourceMode("current")
	KSM_sourceCurrentLevel(sourceCurrentLevel)
	KSM_senseMode("voltage")
	KSM_senseVoltageRange(senseVoltageRange)
	KSM_senseVoltageCompl(senseVoltageCompl)
	KSM_dispDigit(7)
	KSM_bufferEnable("off")
	KSM_terminal(terminal)
	
	SetDataFolder savDF						// Restore DF
End

Function KSM_readInit()
	// Prepare the device for an experiment to source current and measure voltage
	
	String savDF= GetDataFolder(1) 			// Save current DF for restore.
	SetDataFolder root:Packages:Keithley2400
	
	NVAR sourceCurrentLevel, senseVoltageRange, bufferSize, samplingRate
	
	KSM_NPLC("1")
	KSM_bufferEnable("off")						// Stop the buffer
	KSM_bufferClear()							// Clear the buffer
	KSM_bufferFeed()							// Configure buffer to store raw readings
	KSM_bufferDataElement()						// Configure buffer to store Voltage, Current, Timestamp
	KSM_bufferTimestamp("absolute")				// Use the absolute timestamp

	KSM_sourceCurrentLevel(sourceCurrentLevel)	// Set the source current
	KSM_senseVoltageRange(senseVoltageRange)	// Set the voltage range
	
	KSM_triggerDelay(1/samplingRate-33e-3)		// Set the trigger delay to configure sampling rate
	KSM_bufferSize(bufferSize)					// Set the buffer size
	KSM_triggerCounter(bufferSize)				// Set the trigger count
	KSM_bufferEnable("on")						// Start the buffer (need to trigger device via KSM_readStart() to start adding record to buffer)
	
	SetDataFolder savDF
End

Function KSM_highSpeedMode()
	// Configure the device to operate as quickly as possible by disabling auto-functions
	
	KSM_autoZero("off")
	KSM_displayEnable("off")
	KSM_autoOutputOff("off")
	KSM_sourceAutoDelay("off")
	KSM_sourceDelay(0)
End

Function KSM_test()

	String savDF= GetDataFolder(1) 			// Save current DF for restore.
	SetDataFolder root:Packages:Keithley2400

	NVAR bufferSize

	KSM_readInit()
	KSM_output("on")
	Sleep/S 1
	Variable now = DateTime
	KSM_readStart()
	Sleep/S/C=0 10
	KSM_output("off")
	Sleep/S 1
	KSM_dataToWave(bufferSize, KSM_bufferRead(bufferSize), now)
	
	SetDataFolder savDF
End

Function KSM_dataToWave(size, results, dt)
	// Split the data into waves
	
	// Parameters
	Variable size		// integer	:	size of data buffer
	String results		// string	:	string of data from KSM
	Variable dt		// integer:	date time integer
	
	String savDF= GetDataFolder(1) 			// Save current DF for restore.
	SetDataFolder root:Packages:Keithley2400
	
	Make/D/O/N=(size) voltageWaveKSM, currentWaveKSM, timeWaveKSM
	
	Variable index = 0
	Variable tmpValue
	
	do
		sscanf StringFromList(3*index+0, results,","), "%f", tmpValue
		voltageWaveKSM[index] = {tmpValue}
		
		sscanf StringFromList(3*index+1, results,","), "%f", tmpValue
		currentWaveKSM[index] = {tmpValue}
		
		sscanf StringFromList(3*index+2, results,","), "%f", tmpValue
		timeWaveKSM[index] = {tmpValue + dt}
		
		index = index + 1
	while(index < size)
	
	SetDataFolder savDF
End
//=============================================================================
//=============================================================================

Function KSM_reset()
	// Reset the device
	
	String reset = "*RST;"
	
	GPIBWrite2 reset
End

Function KSM_remoteSensing(state)
	// Enable or disable remote sensing
	
	// Parameters
	String state		// string	:	"on" or "off"
	
	String command
	if (StringMatch(LowerStr(state),"off"))
		command = ":SYST:RSEN OFF;"
	else
		command = ":SYST:RSEN ON;"
	endif
	
	GPIBWrite2 command
End

Function KSM_sourceMode(mode)
	// Set the source to either current or voltage and set the mode to "fixed"
	//	The device supports a "sweep" mode that can be added later
	
	// Parameters
	String mode		// string	:	"current" or "voltage"
	
	String command
	if (StringMatch(LowerStr(mode),"voltage"))
		command = ":SOUR:FUNC VOLT;"
		GPIBWrite2 command
		command = ":SOUR:VOLT:MODE FIX;"
		GPIBWrite2 command
	else
		command = ":SOUR:FUNC CURR;"
		GPIBWrite2 command
		command = ":SOUR:CURR:MODE FIX;"
		GPIBWrite2 command
	endif
End

Function KSM_sourceCurrentRange(value)
	// Set the output current range
	//	The current range vary from 0.1 [uA] to 1 [A]
	
	// Parameters
	Variable value		// string	:	source current range in units of [A]
	
	String sValue
	sprintf sValue, "%1.2e", value
	
	String command = ":SOUR:CURR:RANG " + sValue + ";"
	
	GPIBWrite2 command
End

Function KSM_sourceCurrentLevel(value)
	// Set the output current level
	
	// Parameters
	Variable value		// float	:	source current level in units of [A]
	
	String sValue
	sprintf sValue, "%1.2e", value
	String command = ":SOUR:CURR:LEV " + sValue + ";"
	
	GPIBWrite2 command
	KSM_sourceCurrentRange(value)
End

Function KSM_senseMode(mode)
	// Set the sense/measure to either current, voltage, or resistance
	
	// Parameters
	String mode		// string	:	"current", "resistance" or "voltage"
	
	String command
	if (StringMatch(LowerStr(mode),"current"))
		command = ":SENS:FUNC \"CURR\";"
	elseif (StringMatch(LowerStr(mode),"resistance"))
		command = ":SENS:FUNC \"RES\";"
	else
		command = ":SENS:FUNC \"VOLT\";"
	endif
	
	GPIBWrite2 command
End

Function KSM_senseVoltageRange(value)
	// Set the sense/measurement voltage range
	//	The voltage range varies from 210 [mV] to 210 [V]
	
	// Parameters
	Variable value		// string	:	scientific formatted value such as 1e-3 for 1 [mV]
	
	String sValue
	sprintf sValue, "%1.2e", value
	String command = ":SENS:VOLT:RANG " + sValue + ";"
	
	GPIBWrite2 command
End

Function KSM_senseVoltageCompl(value)
	// Set the sense voltage compliance value
	//	If the sense voltage exceeds compliance value, the source current will be reduced to ensure voltage does not exceed compliance
	
	// Parameters
	Variable value		// float	:	compliance voltage in units of [V]
	
	String sValue
	sprintf sValue, "%1.2e", value
	String command = ":SENS:VOLT:PROT " + sValue + ";"
	
	GPIBWrite2 command
End

Function KSM_dispDigit(value)
	// Set the number of digits in the display
	
	// Parameters
	Variable value		// integer	:	4, 5, 6, or 7
	 
	String command
	if (value == 4)
		command = ":DISP:DIG " + num2str(value) + ";"
	elseif (value == 5)
		command = ":DISP:DIG " + num2str(value) + ";"
	elseif (value == 6)
	 	command = ":DISP:DIG " + num2str(value) + ";"
	else
	 	command = ":DISP:DIG 7;"
	endif	
	
	GPIBWrite2 command
End

Function KSM_bufferEnable(state)
	// Enable or disable the trace buffer for storing data
	
	// Parameters
	String state		// string	:	"on" or "off"
	
	String command
	if (StringMatch(LowerStr(state),"on"))
		command = ":TRAC:FEED:CONT NEXT;"
	else
		command = ":TRAC:FEED:CONT NEV;"
	endif
	
	GPIBWrite2 command
End

Function KSM_bufferClear()
	// Clear the trace buffer
	
	GPIBWrite2 ":TRAC:CLE;"
End

Function KSM_bufferFeed()
	// Put raw readings in buffer as opposed to calculated readings
	
	GPIBWrite2 ":TRAC:FEED SENS;"
End

Function KSM_bufferTimestamp(mode)
	// Select the type of timestamp for the buffer data
	//	Absolute timestamp is referenced to first reading
	//	Delta timestamp is the time between buffer reading
	
	// Parameters
	String mode		// string	:	"absolute" or "delta"
	
	String command
	if (StringMatch(LowerStr(mode),"absolute"))
		command = ":TRAC:TST:FORM ABS;"
	else
		command = ":TRAC:TST:FORM DELT;"
	endif
	
	GPIBWrite2 command
End

Function KSM_triggerCounter(value)
	// Set the trigger counter
	//	A trigger counter of 10 performs 10 measurements
	//	The trigger counter is normally equal to the buffer size
	
	// Parameters
	Variable value		// integer	:	number of triggers
	
	String command = ":TRIG:COUN " + num2str(value) + ";"
	
	GPIBWrite2 command
End

Function KSM_bufferSize(value)
	// Set the buffer size
	//	Maximum buffer size is 2500
	
	// Parameters
	Variable value		// integer	:	size of buffer

	String command = ":TRAC:POIN " + num2str(value) + ";"
	
	GPIBWrite2 command
End

Function/S KSM_bufferRead(size)
	// Read data from the buffer
	
	// Parameters
	Variable size								// size	:	size of buffer
	Variable maxChar = size*3*14				// each data string from KSM is 14 characters long
	
	String data
	
	GPIBWrite2 ":TRAC:DATA?;"
	Sleep/S 1
	GPIBRead2/T="\r"/N=(maxChar) data
	
	return data
End

Function KSM_NPLC(value)
	// Specify the A/D converter integration time in units of number of power line cycle (NPLC)
	//	This also sets the sampling rate of the A/D converter
	//	In the US, a power line cycle is 60 Hz
	//		Minimum is 0.01		167 [us]			High speed measurement
	//		Maximum is 10		167 [ms]			High accuracy measurement
	//		Normal is 1			16.7 [ms]
	//
	//	The actual measurement time is not equal to the calculated time although all auto-functions were turned off
	//	Testing by measuring voltage across resistor using 1 [mA] source
	//		Read 100 points
	//		NPLC		Time [ms]		V.std [mV]
	//		10			334				2.5
	//		1			33				2.3
	//		0.5			18				6.5
	//		0.1			4.8				9.7
	//		0.001		1.9				10.2
	
	String value 	// string :	scientific formatted value such as 1e-3 for 1 [mS]
	
	String command = ":SENS:VOLT:NPLC " + value + ";"
	
	GPIBWrite2 command
End

Function KSM_terminal(mode)
	// Enable the front or rear terminals
	
	// Parameters
	String mode		// string	:	"front" or "rear"
	
	String command
	if (StringMatch(LowerStr(mode),"back"))
		command = ":ROUT:TERM REAR;"
	else
		command = ":ROUT:TERM FRON;"
	endif
	
	GPIBWrite2 command
End

Function KSM_Output(state)
	// Turn on or off the source
	
	// Parameters
	String state		// string :	"on" or "off"
	
	String command
	if (stringMatch(state,"on"))
		command = ":OUTP ON;"
	else
		command = ":OUTP OFF;"	
	endif
	
	GPIBWrite2 command
End

Function KSM_displayEnable(state)
	// Enable/disable the front panel display
	//	Disable for faster operation
	
	// Parameters
	String state		// string	:	"on" or "off"
	
	String command
	if (StringMatch(LowerStr(state),"off"))
		command = ":DISP:ENAB OFF;"
	else
		command = ":DISP:ENAB On;"
	endif
	
	GPIBWrite2 command
End

Function KSM_bufferDataElement()
	// Set the data elements to store in buffer
	//	VOLT	include voltage measurement or source level
	//	CURR	include current measurement or source level
	//	RES	include resistance measurement
	//	TIME	include timestamp relative to zero
	//	STAT	include status information
	//	Multiple data elements must be separated by comma such as TIME,CURR,VOLT
	
	GPIBWrite2 ":FORM:ELEM:SENS VOLT,CURR,TIME;"		// specify data elements
End

Function KSM_triggerDelay(value)
	// Set the trigger delay
	//	The delay occurs between triggering a measurement and recording a measurement
	
	Variable value 	// float	:	trigger delay in units of [seconds]
	
	String sValue
	sprintf sValue, "%1.2e", value
	String command = ":TRIG:DEL " + sValue + ";"
	
	GPIBWrite2 command
End

Function KSM_autoZero(state)
	// Enable or disable auto zero
	//	With auto zero on, reading consists of signal, zero and reference which is used to calculate accurate reading
	//	With auto zero off, reading consists of only signal and device operates faster
	
	// Parameters
	String state		// string	:	"on" or "off"
	
	String command
	if (StringMatch(LowerStr(state),"off"))
		command = ":SYST:AZER OFF;"
	else
		command = ":SYST:AZER ON;"
	endif
	
	GPIBWrite2 command
End

Function KSM_autoOutputOff(state)
	// Enable/disable the auto output off
	//	Auto output off turns off the source after each measurement
	
	// Parameters
	String state		// string	:	"on" or "off"
	
	String command
	if (StringMatch(LowerStr(state),"on"))
		command = ":SOUR:CLE:AUTO ON;"
	else
		command = ":SOUR:CLE:AUTO OFF;"
	endif
	
	GPIBWrite2 command
End

Function KSM_sourceAutoDelay(state)
	// Enable/disable the auto source delay
	
	// Parameters
	String state		// string	:	"on" or "off"
	
	String command
	if (StringMatch(LowerStr(state),"on"))
		command = ":SOUR:DEL:AUTO ON;"
	else
		command = ":SOUR:DEL:AUTO OFF;"
	endif
	
	GPIBWrite2 command
End

Function KSM_sourceDelay(value)
	// Set the source delay
	//	Source delay is used to enable the source to stabilize before each measurement
	
	Variable value 	// float	:	source delay in units of [seconds]
	
	String sValue
	sprintf sValue, "%1.2e", value
	String command = ":SOUR:DEL " + sValue + ";"
	
	GPIBWrite2 command
End

Function KSM_readStart()
	// Start reading data into the buffer
	
	GPIBWrite2 ":INIT;"
End

Function/D KSM_samplingRate(samplingRate)
	// Start reading data into the buffer
	
	// Parameters
	Variable samplingRate 	// float	:	sampling rate in units of [samples/seconds]
	
	Variable NPLC = 60/samplingRate 		// sampling rate is expressed in number of power line cycles
										// 0.01 NPLC is samples once every 0.01/60 seconds for a 60Hz power line
	String sValue
	sprintf sValue, "%1.2e", NPLC									
	GPIBWrite2 ":SENS:VOLT:NPLC " + ".1" + ";"
End

Function/S KSM_readData()
	// Trigger and take a single reading
	
	String data
	
	GPIBWrite2 ":READ?;"
	GPIBRead2/T="\r" data
	
	return data
End

//======================================================================================================
//	GUI Functions
//======================================================================================================

Window KSM_panel() : Panel
	// Initialize KSM
	KSM_init()
	KSM_initSource()
	KSM_highSpeedMode()
			
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(400,300,650,500)
	SetDrawLayer UserBack
	DrawRect 20,10,230,40
	DrawRect 20,40,230,110
	DrawRect 20,110,230,180
	Button buttonInit,pos={100,15},size={50,20},proc=ButtonProc_init,title="Initialize"
	Button buttonInit,help={"Initialize the Keithley 2400 Sourcemeter"}
	//CheckBox setHighSpeed,pos={110,18},size={104,14},title="High Speed Mode"
	//CheckBox setHighSpeed,value= 0
	SetVariable setCurrentLevel,pos={27,45},size={193,16},bodyWidth=50,proc=SetVarProc_currentLevel,title="Current [mA]                           "
	SetVariable setCurrentLevel,help={"Set the source current level"}
	SetVariable setCurrentLevel,limits={0.001,1000,0},value= root:Packages:Keithley2400:sourceCurrentLevel
	SetVariable setVoltageRange,pos={28,65},size={192,16},bodyWidth=50,proc=SetVarProc_voltageRange,title="Voltage Range [V]                 "
	SetVariable setVoltageRange,help={"Set the measuring voltage range"}
	SetVariable setVoltageRange,limits={0.001,200,0},value= root:Packages:Keithley2400:senseVoltageRange
	SetVariable setVoltageCompliance,pos={29,85},size={191,16},bodyWidth=50,proc=SetVarProc_voltageCompl,title="Voltage Compliance [V]         "
	SetVariable setVoltageCompliance,help={"Set the compliance voltage. If measured voltage exceeds compliance voltage, the source current will be reduced to comply."}
	SetVariable setVoltageCompliance,limits={1,200,0},value= root:Packages:Keithley2400:senseVoltageCompl
	SetVariable setBufferSize,pos={30,115},size={190,16},bodyWidth=50,title="Sample Size                          "
	SetVariable setBufferSize,help={"Set the number of samples to record."}
	SetVariable setBufferSize,format="%d"
	SetVariable setBufferSize,limits={1,2500,0},value= root:Packages:Keithley2400:bufferSize
	SetVariable setSamplingRate,pos={31,135},size={189,16},bodyWidth=50,title="Sampling Rate [N/s]             "
	SetVariable setSamplingRate,help={"Set the number of samples to record per second"}
	SetVariable setSamplingRate,format="%.1f"
	SetVariable setSamplingRate,limits={0.1,25,0},value= root:Packages:Keithley2400:samplingRate
	Button buttonRun,pos={30,155},size={50,20},proc=ButtonProc_save,title="Save"
	Button buttonStart,pos={100,155},size={50,20},proc=ButtonProc_start,title="Start"
	Button buttonStop,pos={170,155},size={50,20},disable=2,proc=ButtonProc_stop,title="Stop"
EndMacro

Function ButtonProc_init(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	String savDF= GetDataFolder(1) 			// Save current DF for restore.
	SetDataFolder root:Packages:Keithley2400
	
	switch( ba.eventCode )
		case 2: // mouse up
			KSM_init()
			KSM_initSource()
			KSM_highSpeedMode()
			break
		case -1: // control being killed
			break
	endswitch
	
	SetDataFolder savDF
	return 0
End

Function ButtonProc_save(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	String savDF= GetDataFolder(1) 			// Save current DF for restore.
	SetDataFolder root:Packages:Keithley2400
	
	switch( ba.eventCode )
		case 2: // mouse up
			Save/J/M="\r\n"/W/F :timeWaveKSM,:currentWaveKSM,:voltageWaveKSM as "data.txt"
			break
		case -1: // control being killed
			break
	endswitch
	
	SetDataFolder savDF
	return 0
End

Function ButtonProc_start(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	String savDF= GetDataFolder(1) 			// Save current DF for restore.
	SetDataFolder root:Packages:Keithley2400
	
	NVAR readStartTime

	switch( ba.eventCode )
		case 2: // mouse up
			ModifyControl buttonStart disable=2
			ModifyControl buttonStop disable=0
	
			KSM_readInit()
			KSM_output("on")
			Sleep/S 1
			readStartTime = DateTime
			KSM_readStart()
			break
		case -1: // control being killed
			break
	endswitch
	
	SetDataFolder savDF
	return 0
End

Function ButtonProc_stop(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	String savDF= GetDataFolder(1) 			// Save current DF for restore.
	SetDataFolder root:Packages:Keithley2400
	
	NVAR bufferSize, readStartTime

	switch( ba.eventCode )
		case 2: // mouse up
			ModifyControl buttonStart disable=0
			ModifyControl buttonStop disable=2
			
			KSM_output("off")
			Sleep/S 1
			KSM_dataToWave(bufferSize, KSM_bufferRead(bufferSize), readStartTime)
			break
		case -1: // control being killed
			break
	endswitch
	
	SetDataFolder savDF
	return 0
End

Function SetVarProc_currentLevel(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	
	String savDF= GetDataFolder(1) 			// Save current DF for restore.
	SetDataFolder root:Packages:Keithley2400
	
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			NVAR sourceCurrentLevel
			Sleep/S 0.2						// It takes a little bit of time for value to update?
			KSM_sourceCurrentLevel(sourceCurrentLevel)
			break
		case -1: // control being killed
			break
	endswitch

	SetDataFolder savDF
	return 0
End

Function SetVarProc_voltageRange(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	
	String savDF= GetDataFolder(1) 			// Save current DF for restore.
	SetDataFolder root:Packages:Keithley2400
	
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			NVAR senseVoltageRange
			Sleep/S 0.2						// It takes a little bit of time for value to update?
			KSM_senseVoltageRange(senseVoltageRange)
			break
		case -1: // control being killed
			break
	endswitch

	SetDataFolder savDF
	return 0
End

Function SetVarProc_voltageCompl(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	
	String savDF= GetDataFolder(1) 			// Save current DF for restore.
	SetDataFolder root:Packages:Keithley2400
	
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			NVAR senseVoltageCompl
			Sleep/S 0.2						// It takes a little bit of time for value to update?
			KSM_senseVoltageCompl(senseVoltageCompl)
			break
		case -1: // control being killed
			break
	endswitch

	SetDataFolder savDF
	return 0
End

Function KSM_table()
	Edit/N=KSM_Table :Keithley2400:timeWaveKSM,:Keithley2400:currentWaveKSM;DelayUpdate
	AppendToTable :Keithley2400:voltageWaveKSM
	ModifyTable format(:Keithley2400:timeWaveKSM)=3
End

//======================================================================================================
//	GMR Functions
//======================================================================================================

Window GMR_panel() : Panel
	// Initialize KSM
	KSM_init()
	KSM_initSource()
	KSM_highSpeedMode()
	GMR_init()
			
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(400,300,650,530)
	SetDrawLayer UserBack
	DrawRect 20,10,230,40
	DrawRect 20,40,230,110
	DrawRect 20,110,230,180
	DrawRect 20,180,230,210
	Button buttonInit,pos={100,15},size={50,20},proc=ButtonProc_init,title="Initialize"
	Button buttonInit,help={"Initialize the Keithley 2400 Sourcemeter"}
	//CheckBox setHighSpeed,pos={110,18},size={104,14},title="High Speed Mode"
	//CheckBox setHighSpeed,value= 0
	SetVariable setCurrentLevel,pos={27,45},size={193,16},bodyWidth=50,proc=SetVarProc_currentLevel,title="Current [mA]                           "
	SetVariable setCurrentLevel,help={"Set the source current level"}
	SetVariable setCurrentLevel,limits={0.001,1000,0},value= root:Packages:Keithley2400:sourceCurrentLevel
	SetVariable setVoltageRange,pos={28,65},size={192,16},bodyWidth=50,proc=SetVarProc_voltageRange,title="Voltage Range [V]                 "
	SetVariable setVoltageRange,help={"Set the measuring voltage range"}
	SetVariable setVoltageRange,limits={0.001,200,0},value= root:Packages:Keithley2400:senseVoltageRange
	SetVariable setVoltageCompliance,pos={29,85},size={191,16},bodyWidth=50,proc=SetVarProc_voltageCompl,title="Voltage Compliance [V]         "
	SetVariable setVoltageCompliance,help={"Set the compliance voltage. If measured voltage exceeds compliance voltage, the source current will be reduced to comply."}
	SetVariable setVoltageCompliance,limits={1,200,0},value= root:Packages:Keithley2400:senseVoltageCompl
	SetVariable setBufferSize,pos={30,115},size={190,16},bodyWidth=50,title="Sample Size                          "
	SetVariable setBufferSize,help={"Set the number of samples to record."}
	SetVariable setBufferSize,format="%d"
	SetVariable setBufferSize,limits={1,2500,0},value= root:Packages:Keithley2400:bufferSize
	SetVariable setSamplingRate,pos={31,135},size={189,16},bodyWidth=50,title="Sampling Rate [N/s]             "
	SetVariable setSamplingRate,help={"Set the number of samples to record per second"}
	SetVariable setSamplingRate,format="%.1f"
	SetVariable setSamplingRate,limits={0.1,25,0},value= root:Packages:Keithley2400:samplingRate
	Button buttonRun,pos={30,155},size={50,20},proc=ButtonProc_save,title="Save"
	Button buttonStart,pos={100,155},size={50,20},proc=ButtonProc_start,title="Start"
	Button buttonStop,pos={170,155},size={50,20},disable=2,proc=ButtonProc_stop,title="Stop"
	Button buttonPlot,pos={100,185},size={50,20},proc=ButtonProc_plot,title="Plot GMR"
	Button buttonPlot,help={"Plot GMR Data"}
EndMacro

Function GMR_init()
	// Initialize the GMR module
	
	// Initialize the data folder for the KSM
	String savDF= GetDataFolder(1) 			// Save current DF for restore.
	NewDataFolder/O/S root:Packages 			// Create and set data folder to root:Packages
	
	if(!DataFolderExists("GMR") ) 				// Does data folder GMR exist?
		NewDataFolder/S GMR 				// Create data folder and all variables
	else
		SetDataFolder GMR 					// Set data folder and initialize all variables
	endif
	SetDataFolder savDF 							// Restore current DF
End

Function GMR_plot()

	String savDF= GetDataFolder(1) 			// Save current DF for restore.
	SetDataFolder root:Packages:GMR

	WAVE VFM_field = root:Packages:MFP3D:VFM:FieldWave
	WAVE VFM_time = root:Packages:MFP3D:VFM:TimeWave
	WAVE KSM_time = root:Packages:Keithley2400:timeWaveKSM
	WAVE KSM_voltage = root:Packages:Keithley2400:voltageWaveKSM
	WAVE KSM_current = root:Packages:Keithley2400:currentWaveKSM

	Make/D/O/N=(numpnts(KSM_time)) fieldWaveGMR
	Make/D/O/N=(numpnts(KSM_time)) resistanceWaveGMR
	
	Variable i
	for (i=0;i<numpnts(KSM_time);i+=1)
		fieldWaveGMR[i] = interp(KSM_time(i),VFM_time,VFM_field)
		resistanceWaveGMR[i] = KSM_voltage(i)/KSM_current(i)
	endfor

	Display resistanceWaveGMR vs fieldWaveGMR
	Label bottom "Field [G]"
	Label left "Resistance [Ohm]"
	
	Display KSM_voltage vs KSM_time
	Label bottom "Time"
	Label left "Voltage [V]"

	SetDataFolder savDF
End

Function ButtonProc_plot(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	String savDF= GetDataFolder(1) 			// Save current DF for restore.
	
	switch( ba.eventCode )
		case 2: // mouse up
			GMR_plot()
			break
		case -1: // control being killed
			break
	endswitch
	
	SetDataFolder savDF
	return 0
End
