// Mission file for craft to execute.

REQUIRE("lib/ship.ks").
REQUIRE("lib/pidcontroller.ks").
REQUIRE("lib/maneuver.ks").
REQUIRE("lib/orbit.ks").
REQUIRE("lib/body.ks").
REQUIRE("lib/telemetry.ks").

LOCAL telemetryName IS "general".
LOCAL telemetryDir IS "0:/" + SHIP:NAME + "/telem" + "." + getMissionCount().

FUNCTION getSequence {
  // sequence = ["name1", function1@, "name2", function2@, ...]
  PRINT "Loading mission...".
  RETURN LIST(
    "init", init@,
    "goToSpace", goToSpace@,
    "circularize", circularize@,
    "stopTelem", stopTelem@
  ).
}

FUNCTION init {
  PARAMETER mission.
  
  mission["addEvent"]("printInfo", printInfo@).
  mission["addEvent"]("logTelemetry", logTelemetry@).
  WAIT 0.1.
  LOCK THROTTLE TO 1.
  mission["nextStage"]().
}

FUNCTION goToSpace
{
  PARAMETER mission.
  
  IF SHP_burnout() OR SHP_activeEngines():LENGTH() = 0 {
    STAGE.
  }
  
  IF BDY_ascendGuidance(100_000)["done"]
  {
    mission["nextStage"]().
  }
}

FUNCTION circularize
{
  PARAMETER mission.
  
  IF NOT HASNODE {
    // plan maneuver
    ORB_cirularize(ETA:APOAPSIS + TIME:SECONDS).
  }
  
  // execute planned maneuver
  IF MNV_nodeExec(TRUE)
  {
    mission["nextStage"]().
  }
}

FUNCTION stopTelem {
  PARAMETER mission.
  mission["removeEvent"]("logTelemetry").
  TELEM_finish(telemetryName, telemetryDir).
  mission["nextStage"]().
}

FUNCTION printInfo {
  PARAMETER mission.
  PRINT "Mission Time: " + ROUND(getMissionTime(),2) + "s" AT (70,0).
  PRINT "Stage: " + mission["getStage"]() AT (70,1).
  PRINT "dV Stage: " + ROUND(SHIP:STAGEDELTAV(SHIP:STAGENUM):CURRENT, 2) + "m/s^2" AT (70,2).
  PRINT "dV Total: " + ROUND(SHIP:DELTAV:CURRENT, 2) + "m/s^2" AT (70,3).
  PRINT "MaxTWR: " + ROUND(SHP_getMaxTWR(),2) AT (70,4).
  PRINT "CurTWR: " + ROUND(THROTTLE * SHP_getMaxTWR(),2) AT (70,5).
  PRINT "AoA: " + ROUND(VANG(SHIP:FACING:VECTOR, SHIP:SRFPROGRADE:VECTOR), 2) AT (70,6).
  
  RETURN TRUE.
}

FUNCTION logTelemetry {
  PARAMETER mission.
  
  LOCAL telemetry IS LEXICON(
    // general stuff
    "Stage", SHIP:STAGENUM,
    
    // orbital stuff
    "Altitude", ROUND(ALTITUDE,2),
    "PE", ROUND(SHIP:ORBIT:PERIAPSIS,2),
    "AP", ROUND(SHIP:ORBIT:APOAPSIS,2),
    "ECC", ROUND(SHIP:ORBIT:ECCENTRICITY,5),
    "ETA:AP", ROUND(SHIP:ORBIT:ETA:APOAPSIS,2),
    "ETA:PE", ROUND(SHIP:ORBIT:ETA:PERIAPSIS,2),
    "IAS", ROUND(SHIP:AIRSPEED, 2),
    "OrbVel", ROUND(SHIP:ORBIT:VELOCITY:ORBIT:MAG,2),
    
    // maneuvering stuff
    "AoA", ROUND(VANG(SHIP:SRFPROGRADE:VECTOR, SHIP:FACING:VECTOR), 2),
    "dV Stage", ROUND(SHIP:STAGEDELTAV(SHIP:STAGENUM):CURRENT, 2),
    "dV Total", ROUND(SHIP:DELTAV:CURRENT, 2),
    "Throttle", ROUND(THROTTLE,3),
    "Max TWR", ROUND(SHP_getMaxTWR(),2),
    "Cur TWR", ROUND(THROTTLE * SHP_getMaxTWR(),2),
    "ISP", ROUND(SHP_getISP(), 2)
  ).
  
  IF CHECK_CONNECTION() {
    TELEM_write(telemetryName, telemetryDir, telemetry).
  }
  
  return TRUE.
}