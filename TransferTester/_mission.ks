// Mission file for craft to execute.

REQUIRE("lib/ship.ks").
REQUIRE("lib/maneuver.ks").
REQUIRE("lib/orbit.ks").
REQUIRE("lib/body.ks").
REQUIRE("lib/target.ks").

FUNCTION getSequence {
  // sequence = ["name1", function1@, "name2", function2@, ...]
  PRINT "Loading mission...".
  RETURN LIST(
    "init", init@,
    "goToSpace", goToSpace@,
    "circularize", circularize@,
    "transferToMinmus", transferToMinmus@,
    "waitMinmusSOI", waitMinmusSOI@,
    "circularizeAtMinmus", circularizeAtMinmus@,
    "fixInclinationAtMinmus", fixInclinationAtMinmus@
  ).
}


FUNCTION init {
  PARAMETER mission.
  
  mission["addEvent"]("printInfo", printInfo@).
  WAIT 0.1.
  mission["nextStage"]().
}

FUNCTION goToSpace
{
  PARAMETER mission.
  
  IF SHP_burnout() OR SHP_activeEngines():LENGTH() = 0 {
    LOCK THROTTLE TO 1.
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

FUNCTION transferToMinmus
{
  PARAMETER mission.
  
  IF NOT HASTARGET {
    LOCAL tgtBody IS BODY("Minmus").
    SET TARGET TO tgtBody.
    WAIT 0.03.
  }
  
  IF NOT HASNODE {
    TGT_transferToTarget().
  }
  
  // execute planned maneuver
  IF MNV_nodeExec(TRUE)
  {
    mission["nextStage"]().
  }
}

FUNCTION waitMinmusSOI {
  PARAMETER mission.
  
  IF SHIP:BODY = Minmus {
    WAIT 5.
    mission["nextStage"]().
  }
}

FUNCTION circularizeAtMinmus
{
  PARAMETER mission.
  
  IF NOT HASNODE {
    ORB_cirularize(TIME:SECONDS + ETA:PERIAPSIS).
  }
  IF MNV_nodeExec(TRUE)
  {
    mission["nextStage"]().
  }
}

FUNCTION fixInclinationAtMinmus
{
  PARAMETER mission.
  IF NOT HASNODE {
    TGT_matchInclination().
  }
  IF MNV_nodeExec(TRUE)
  {
    mission["nextStage"]().
  }
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
