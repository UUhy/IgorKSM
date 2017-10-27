# IgorKSM
Keithley 2400 Source Meter device driver for Igor Pro Platform

Keithley2400.ipf
  Device driver for the Keithley 2400 Source Meter for the Igor Pro Platform
    Requires GPIB libraries from Igor Pro
    
GMR.ipf
  Modified Keithley2400.ipf to include a GMR data plotter
    Should install either GMR.ipf or Keithley2400.ipf, not both
    
Installation
  1) Place either Keithley2400.ipf (or GMR.ipf) into the /Igor Pro Folder/Igor Procedures/
  2) Install GPIB controller and connect Keithley 2400
    a) Use NI Max (see KSM_NIMax.png) to determine board and device address
  3) Run Igor Pro
    a) Open the Keithley2400.ipf file to configure the KSM_initGPIB() function (see KSM_GPIBInit.png)
      i) Configure gBoardAddress
      ii) Configure gDeviceAddress
    b) Go to Windows -> Panel Macros -> KSM_Panel
