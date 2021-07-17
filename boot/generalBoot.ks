// generalized boot script
// secondary boot script, will be compiled and uploaded to craft by primary boot script
// using runlevels and mission sequencing to structure missions.

// script holds mission file
// when a new mission for the craft is found on the ARCHIVE then
// it will be downloaded and the mission will be reset.
//
// mission script must define function getSequence that will return the sequence list
// mission script must define any functions that appear in the sequence list
// sequence list must have a init stage, which may set up any events and then switch stage to whatever it might be.
LOCAL missionScript IS "mission.ks".

// file will hold name of current mission stage to reload after reboot, loss of power or
// vessel switching
LOCAL stageBackup IS "currentStage.txt".

// init archive for this vessel
IF HOMECONNECTION:ISCONNECTED() AND NOT ARCHIVE:EXISTS(SHIP:NAME) {
  ARCHIVE:CREATEDIR(SHIP:NAME).
  LOCAL fileHandle IS ARCHIVE:CREATE(SHIP:NAME + "/" + reloadMission.bat).
  fileHandle:WRITELN("@ECHO OFF").
  fileHandle:WRITELN("COPY _" + missionScript + " " + missionScript).
  
  COPYPATH("0:/mission_rump.ks", "0:/" + SHIP:NAME + "/" + "_" + missionScript).
}

LIST FILES.
PRINT "".
PRINT "".
CD ("/boot").
LIST FILES.
CD("/").

FROM {LOCAL i IS CHOOSE 30 IF DEBUG ELSE 0.} UNTIL (i <= 0) STEP { SET i TO i-1. } DO {
  PRINT "Booting stage 2 in " + i + "s. " AT (0, 0).
  WAIT 1.
}

// compile and load helperFunctions if not already on the file system (reboot).
IF NOT DEBUG {
  IF NOT EXISTS("helperFunctions.ksm") {
    PRINT "Fetching Helper Functions...".
    COPYPATH("0:/helperFunctions.ks", "helperFunctions.ks").
  }
}
ELSE {
  IF NOT EXISTS("helperFunctions.ksm") {
    PRINT "Fetching Helper Functions...".
    COMPILE "0:/helperFunctions.ks" TO "1:/helperFunctions.ksm".
  }
}

RUNONCEPATH("helperFunctions").

print "Helper Functions loaded.".

FUNCTION main
{
  PRINT "Starting mission runner.".
  mission_runner().
}

// mission holds pointers to helper functions and datastructures about the mission
GLOBAL mission IS LEXICON().

FUNCTION mission_runner
{
  // ========================================================
  // initialize mission functions
  SET mission["nextStage"] TO nextStage@.		// sets next stage in list
  SET mission["setStage"] TO setStage@.			// sets stage indicated by name
  SET mission["getStage"] TO getStage@.			// gets stage name
  SET mission["addEvent"] TO addEvent@.			// add event handler
  SET mission["removeEvent"] TO removeEvent@.	// remove event handler
  SET mission["terminate"] TO terminate@.		// end mission
  
  // initialize members
  
  // ========================================================
  // events are checked every loop and can be added or removed by the mission stages itself.
  // event functions take the mission
  // event functions will be deleted after execution if they do not return true
  
  // events = {"name": function@, "name2": function2@, ...}
  
  SET mission["events"] TO LEXICON().
  mission["addEvent"]("msnUpdate", evt_checkMissionUpdate@).
  
  // ========================================================
  
  // populate sequence
  
  // sequence holds a sequence of mission objectives, such as
  //   ascend, circularize, transfer, circularize, land, etc...
  // each of those functions must get mission as parameter and end with
  //   either next or setStage or terminate
  // if not the same instructions will be run again,
  //   which might be what you want (to wait for an event to occur)
  // to reuse a mission stage in different situations, (ascend from kirbin, land, ascend again from mun)
  //   the differentiation between the two must be made from within the sequence function
  //   and the next stage in the sequence may need to be set manually
  
  // sequence = ["name1", function1@, "name2", function2@, ...]
  
  // if mission file exists on disk, load that
  // otherwise do nothing (event will update mission script automatically)
  SET mission["sequence"] TO LIST().
  IF CORE:VOLUME:EXISTS (missionScript) {
    // will declare functions and populate sequence with function getSequence()
    RUNPATH (missionScript).
    SET mission["sequence"] TO getSequence().
  }
  ELSE IF CORE:VOLUME:EXISTS (missionScript + "m") {
    // will declare functions and populate sequence with function getSequence()
    RUNPATH (missionScript + "m").
    SET mission["sequence"] TO getSequence().
  }
  
  // execute runOnce
  {
    LOCAL idx IS mission["sequence"]:FIND("runOnce").
    IF idx >= 0 {
      mission["sequence"][idx + 1](mission).
    }
  }
  
  // ========================================================
  
  // restore mission stage from file if exists in case of power out/vessel swap
  // otherwise leave mission stage at "init".
  IF CORE:VOLUME:EXISTS(stageBackup) {
    SET mission["currentStage"] TO OPEN(stageBackup):READALL:STRING.
  }
  ELSE
  {
    SET mission["currentStage"] TO "init".
  }
  
  // ========================================================
  
  // main loop
  UNTIL FALSE // run forever
  {
    // do stage
    // find stage to do
    LOCAL stageIdx IS mission["sequence"]:FIND(mission["currentStage"]).
    // execute the function for that stage if the stage is found in the current profile
    IF stageIdx >= 0 {
      mission["sequence"][stageIdx + 1](mission).
    }
    // if none found, just keep in the loop anyway, but wait a bit to save power.
    // event checkMissionUpdate will check for mission updates from KSC
    ELSE {
      PRINT "No mission, waiting for " + SHIP:NAME + "/" + missionScript + " on archive." AT (0,1).
      PRINT lineDelim AT (0, 2).
    }
    
    // do events
    FOR key IN mission["events"]:KEYS {
      LOCAL keep IS mission["events"][key](mission).
      IF NOT keep {
        mission["removeEvent"](key).
      }
    }
    // don't trash the CPU
    WAIT 0. // wait for the rest of the physics tick
  }
  
}

// advances to the next stage in sequence or terminates the mission if no more stages
FUNCTION nextStage {
  LOCAL curStageName IS mission["currentStage"].
  LOCAL stageIdx IS mission["sequence"]:FIND(curStageName).
  LOCAL seqLen IS mission["sequence"]:LENGTH().
  
  SET stageIdx TO stageIdx + 2.
  IF stageIdx < seqLen
  {
    mission["setStage"](mission["sequence"][stageIdx]).
  }
  else
  {
    mission["terminate"]().
  }
}

// sets specified stage from the sequence. if not found will print error and terminate
FUNCTION setStage {
  PARAMETER stageName.
  
  // delete old backup
  IF EXISTS(stageBackup)
  {
    DELETEPATH(stageBackup).
  }
  
  // check if new stage actually exists
  IF mission["sequence"]:FIND(stageName) >= 0 {
    // actually set the stage
    SET mission["currentStage"] TO stageName.
  }
  ELSE
  {
    NOTIFY("Mission stage '" + stageName + "' doesn't exist!", 3).
  }
  
  // create new backup
  LOCAL fileHandle IS CORE:VOLUME:CREATE(stageBackup).
  fileHandle:WRITE(stageName).
}

FUNCTION getStage {
  RETURN mission["currentStage"].
}

FUNCTION addEvent {
  PARAMETER eventName.
  PARAMETER eventFunc.
  
  SET mission["events"][eventName] TO eventFunc.
}

FUNCTION removeEvent {
  PARAMETER eventName.
  
  IF mission["events"]:HASKEY(eventName) {
    mission["events"]:REMOVE(eventName).
  }
  ELSE
  {
    NOTIFY("Removing event '" + eventName + "' unable, not found.",2).
  }
}

FUNCTION terminate {
  // delete mission script so we don't start a new mission on reboot
  IF CORE:VOLUME:EXISTS (missionScript)
  {
    DELETEPATH(missionScript).
  }
  
  IF CORE:VOLUME:EXISTS (missionScript + "m")
  {
    DELETEPATH(missionScript + "m").
  }
  
  // delete backup so we don't try and load anything that doesn't exist next time around
  IF CORE:VOLUME:EXISTS (stageBackup)
  {
    DELETEPATH(stageBackup).
  }
  
  NOTIFY("Mission Completed. Reboot.", 1).
  
  // reboot, will await new instructions (as missions) via event handler.
  REBOOT.
}

// event to check for mission update
FUNCTION evt_checkMissionUpdate {
  PARAMETER mission.
  
  LOCAL archivePath IS "0:/" + SHIP:NAME + "/" + missionScript.
  // check if connected
  IF CHECK_CONNECTION() AND EXISTS(archivePath) {
    LOCAL localPath IS "/" + missionScript + "m".
    LOCAL executedDir IS "0:/" + SHIP:NAME + "/executed".
    LOCAL cnt IS getMissionCount().
    // check if new mission exists
    DOWNLOAD(archivePath, NOT DEBUG, localPath).
    
    // move script on archive into executed directory
    // this prevents missions from executing multiple time.
    // create directory if not exists
    IF NOT EXISTS(executedDir)
    {
      CREATEDIR(executedDir).
    }
    
    // move mission file on archive to new location
    MOVEPATH(archivePath, executedDir + "/mission." + cnt + ".ks").
    addMissionCounter().
    
    IF EXISTS(stageBackup)
    {
      DELETEPATH(stageBackup).
    }
    
    NOTIFY ("Found new mission, reboot.", 1).
    REBOOT.
  }
  
  RETURN TRUE.
}

main().