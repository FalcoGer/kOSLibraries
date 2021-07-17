// Mission file for craft to execute.

REQUIRE("lib/maneuver.ks").
REQUIRE("lib/orbit.ks").
REQUIRE("lib/body.ks").
REQUIRE("lib/terminal.ks").
REQUIRE("lib/target.ks").

LOCAL telemetryName IS "general".
LOCAL telemetryDir IS "0:/" + SHIP:NAME + "/telem" + "." + getMissionCount().

FUNCTION getSequence {
  // sequence = ["name1", function1@, "name2", function2@, ...]
  RETURN LIST(
    "init", init@,
    "ascendFromKerbin", ascendFromKerbin@,
    "circularizeKerbin", circularizeKerbin@,
    "inclinationChangeTest", inclinationChangeTest@,
    "deorbit", deorbit@
  ).
}

FUNCTION init {
  PARAMETER mission.
  
  TERM_setup(80,50).
  TERM_show().
  
  TERM_addRegion("Orbit", 0, 0, 38, 24).
  TERM_addRegion("Ascend", 39, 0, 39, 24).
  TERM_addRegion("Default", 0, 25, 78, 20).
  
  mission["addEvent"]("printOrbitInfo", printOrbitInfo@).
  WAIT 0.1.
  LOCK THROTTLE TO 1.
  mission["nextStage"]().
}

FUNCTION ascendFromKerbin {
  PARAMETER mission.
  
  LOCAL ascend IS BDY_ascendGuidance(100_000).
  
  TERM_print("Stage: " + ascend["branch"], "Ascend", 0, FALSE).
  TERM_print("Desired Pitch: " + ROUND(ascend["desiredPitch"], 2) + "°", "Ascend", 1, FALSE).
  TERM_print("AoA: " + ROUND(ascend["AoA"], 2) + "°", "Ascend", 2, FALSE).
  TERM_print("AoA Limit: " + ROUND(ascend["AoADynamicLimit"], 2) + "°", "Ascend", 3, FALSE).
  TERM_print("Atm: " + ROUND(ascend["atmPressure"], 3) + " atm", "Ascend", 4, FALSE).
  TERM_print("Max TWR: " + ROUND(ascend["maxTWR"], 2), "Ascend", 5, FALSE).
  TERM_print("Throttle: " + ROUND(ascend["throttle"] * 100, 1) + "%", "Ascend", 6, TRUE).
  
  IF SHP_burnout()
  {
    STAGE.
  }
  
  IF ascend["done"]
  {
    TERM_removeRegion("Ascend").
    mission["nextStage"]().
  }
}

FUNCTION circularizeKerbin {
  PARAMETER mission.
  
  IF NOT HASNODE {
    ORB_cirularize(SHIP:ORBIT:ETA:APOAPSIS + TIME:SECONDS).
  }
  
  IF SHP_burnout()
  {
    STAGE.
  }
  
  IF MNV_nodeExec(TRUE)
  {
    mission["nextStage"]().
  }
}

FUNCTION inclinationChangeTest
{
  PARAMETER mission.
  
  IF NOT HASNODE {
    LOCAL anTime IS TGT_findAN_DN_time()[0].
    ORB_changeIncl(anTime, 25).
  }
  
  IF SHP_burnout()
  {
    STAGE.
  }
  
  IF MNV_nodeExec(TRUE)
  {
    TERM_print("Inclination change done.").
    TERM_print("INC: " + SHIP:ORBIT:INCLINATION).
    
    WAIT 10.
    mission["nextStage"]().
  }
}

FUNCTION deorbit
{
  PARAMETER mission.
  
  LOCK STEERING TO RETROGRADE.
  
  LOCK THROTTLE TO 1.
  
  IF PERIAPSIS < 30_000
  {
    UNLOCK STEERING.
    UNLOCK THROTTLE.
    mission["nextStage"]().
  }
}


FUNCTION printOrbitInfo 
{
  PARAMETER mission.
  TERM_print("Body: " + SHIP:BODY, "Orbit", 0, FALSE).
  TERM_print("AP: " + ROUND(SHIP:ORBIT:APOAPSIS,0), "Orbit", 1, FALSE).
  TERM_print("PE: " + ROUND(SHIP:ORBIT:PERIAPSIS,0), "Orbit", 2, FALSE).
  TERM_print("Time AP: " + ROUND(ETA:APOAPSIS,1), "Orbit", 3, FALSE).
  TERM_print("Time PE: " + ROUND(ETA:PERIAPSIS,1), "Orbit", 4, FALSE).
  TERM_print("ECC: " + ROUND(SHIP:ORBIT:ECCENTRICITY, 4), "Orbit", 5, FALSE).
  TERM_print("Period: " + ROUND(SHIP:ORBIT:PERIOD, 2), "Orbit", 6, FALSE).
  TERM_print("Velocity: " + ROUND(VELOCITYAT(SHIP, TIME:SECONDS):ORBIT:MAG, 1), "Orbit", 7, TRUE).
  
  RETURN true.
}
