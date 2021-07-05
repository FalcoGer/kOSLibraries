// generalized boot script

PRINT "Booting...".

// Set pilot set throttle to 0 to avoid unnessesary accidents
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.

SET HF TO "helperFunctions".

// compile and load helperFunctions if not already on the file system (reboot).

if not EXISTS("1:/helperFunctions.ksm") {
  PRINT "Fetching Helper Functions...".
  SWITCH TO 0.
  COMPILE "helperFunctions.ks" TO "helperFunctions.ksm".
  SWITCH TO 1.
  MOVEPATH("0:/helperFunctions.ksm", "1:/helperFunctions.ksm").
  RUNONCEPATH("1:/helperFunctions.ksm").
}
// script to look for
SET updateScript TO SHIP:NAME + ".update.ks".
SET startupScript TO "startup.ks".

// actual booting
// look for update scripts on KSC
IF HOMECONNECTION:IsConnected {
  IF HAS_FILE(updateScript, 0) {
    PRINT "New instructions found.".
    DOWNLOAD(updateScript, TRUE).
	SWITCH TO 0.
	IF HAS_FILE(updateScript, 0) { DELETE updateScript. }
	SET updateScript TO updateScript + "m".
	IF HAS_FILE(updateScript, 0) { DELETE updateScript. }
	SWITCH TO 1.
	RUNPATH(updateScript).
	PRINT "Instructions completed.".
	DELETE updateScript.
  }
}

// if startup script exists then run it.
IF HAS_FILE("startup.ksm", 1) OR HAS_FILE("startup.ks") {
  PRINT "Starting STARTUP routine...".
  RUNPATH("startup").
  PRINT "Startup finished...".
} ELSE {
  WAIT UNTIL HOMECONNECTION:IsConnected.
  WAIT 10. // Avoid thrashing the CPU (when no startup.ks, but we have a
           // persistent connection, it will continually reboot).
  REBOOT.
}