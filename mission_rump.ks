// Mission file for craft to execute.

REQUIRE("lib/body.ks").
REQUIRE("lib/orbit.ks").
REQUIRE("lib/maneuver.ks").
REQUIRE("lib/terminal.ks").


// provides mission step sequence to mission runner
FUNCTION getSequence {
  // sequence = ["name1", function1@, "name2", function2@, ...]
  
  RETURN LIST(
    "runOnce", runOnce@,
    "init", init@,
    "ascendFromKerbin", ascendFromKerbin@,
    "circularizeKerbin", circularizeKerbin@
  ).
}

// will run once every reboot if in mission sequence
FUNCTION runOnce {
  PARAMETER mission.
  
  TERM_setup(80,50).
  TERM_show().
  
  TERM_addRegion("Orbit", 0, 0, 38, 24).
  TERM_addRegion("Default", 0, 25, 78, 20).
  
  mission["addEvent"]("deployDeployables", deployDeployables@).
  mission["addEvent"]("printOrbitInfo", printOrbitInfo@).
  mission["addEvent"]("drawTerm", drawTerm@).
}

// ===================================================
// mission steps

FUNCTION init {
  PARAMETER mission.
  
  mission["nextStage"]().
}

FUNCTION ascendFromKerbin {
  PARAMETER mission.
  
  LOCAL ascend IS BDY_ascendGuidance(100_000).
  
  LOCAL ascendRegion IS "Ascend".
  IF NOT TERM_keyExists(ascendRegion)
  {
    TERM_addRegion("Ascend", 39, 0, 39, 24).
  }
  
  TERM_print("Stage: " + ascend["branch"], ascendRegion, 0).
  TERM_print("Desired Pitch: " + ROUND(ascend["desiredPitch"], 2) + "°", ascendRegion, 1).
  TERM_print("AoA: " + ROUND(ascend["AoA"], 2) + "°", ascendRegion, 2).
  TERM_print("AoA Limit: " + ROUND(ascend["AoADynamicLimit"], 2) + "°", ascendRegion, 3).
  TERM_print("Atm: " + ROUND(ascend["atmPressure"], 3) + " atm", ascendRegion, 4).
  TERM_print("Max TWR: " + ROUND(ascend["maxTWR"], 2), ascendRegion, 5).
  TERM_print("Throttle: " + ROUND(ascend["throttle"] * 100, 1) + "%", ascendRegion, 6).
  
  IF SHP_burnout()
  {
    STAGE.
    WAIT 0.2.
  }
  
  IF ascend["done"]
  {
    TERM_removeRegion(ascendRegion).
    mission["nextStage"]().
  }
}

LOCAL FUNCTION circularizeKerbin
{
  PARAMETER mission.
  
  IF NOT HASNODE {
    ORB_cirularize(ETA:APOAPSIS + TIME:SECONDS).
  }
  
  execNodeWithAutostage(mission, 0).
}



// ===================================================
// events

LOCAL FUNCTION deployDeployables {
  PARAMETER mission.
  
  LOCAL solarDeployModuleName IS "ModuleDeployableSolarPanel".
  LOCAL solarDeployEventName IS "extend solar panel".
  
  LOCAL antennaDeployModuleName IS "ModuleDeployableAntenna".
  LOCAL antennaDeployEventName IS "extend antenna".
  
  LOCAL fairingsModuleName IS "ModuleProceduralFairing".
  LOCAL fairingsEventName IS "deploy".
  
  IF (NOT SHIP:BODY:ATM:EXISTS) OR ALTITUDE > (SHIP:BODY:ATM:HEIGHT  * 1.05)
  {
    FOR p IN SHIP:PARTS {
      // deploy fairing
      IF p:HASMODULE(fairingsModuleName)
      {
        LOCAL m IS p:GETMODULE(fairingsModuleName).
        IF m:HASEVENT(fairingsEventName) {
          m:DOEVENT(fairingsEventName).
        }
        WAIT 0.5.
      }
      
      // deploy solar
      IF p:HASMODULE(solarDeployModuleName) {
        LOCAL m IS p:GETMODULE(solarDeployModuleName).
        IF m:HASEVENT(solarDeployEventName) {
          m:DOEVENT(solarDeployEventName).
        }
      }
      
      // deploy antenna
      IF p:HASMODULE(antennaDeployModuleName)
      {
        LOCAL m IS p:GETMODULE(antennaDeployModuleName).
        IF m:HASEVENT(antennaDeployEventName) {
          m:DOEVENT(antennaDeployEventName).
        }
      }
    }
    
    mission["addEvent"]("retractRetractables", retractRetractables@).
    RETURN FALSE.
  }
  RETURN TRUE.
}

LOCAL FUNCTION retractRetractables {
  PARAMETER mission.
  
  LOCAL solarDeployModuleName IS "ModuleDeployableSolarPanel".
  LOCAL solarRetractEventName IS "retract solar panel".
  
  LOCAL antennaDeployModuleName IS "ModuleDeployableAntenna".
  LOCAL antennaRetractEventName IS "retract antenna".
  IF SHIP:BODY:ATM:EXISTS AND ALTITUDE < (SHIP:BODY:ATM:HEIGHT * 1.01)
  {
    FOR p IN SHIP:PARTS {
      // deploy solar
      IF p:HASMODULE(solarDeployModuleName) {
        LOCAL m IS p:GETMODULE(solarDeployModuleName).
        IF m:HASEVENT(solarRetractEventName) {
          m:DOEVENT(solarRetractEventName).
        }
      }
      
      // deploy antenna
      IF p:HASMODULE(antennaDeployModuleName)
      {
        LOCAL m IS p:GETMODULE(antennaDeployModuleName).
        IF m:HASEVENT(antennaRetractEventName) {
          m:DOEVENT(antennaRetractEventName).
        }
      }
    }
    
    mission["addEvent"]("deployDeployables", deployDeployables@).
    RETURN FALSE.
  }
  RETURN TRUE.
}

LOCAL FUNCTION printOrbitInfo 
{
  PARAMETER mission.
  TERM_print("Body: " + SHIP:BODY:NAME, "Orbit", 0).
  TERM_print("AP: " + ROUND(SHIP:ORBIT:APOAPSIS,0) + "m", "Orbit", 1).
  TERM_print("PE: " + ROUND(SHIP:ORBIT:PERIAPSIS,0) + "m", "Orbit", 2).
  TERM_print("Time AP: " + ROUND(ETA:APOAPSIS,1) + "s", "Orbit", 3).
  TERM_print("Time PE: " + ROUND(ETA:PERIAPSIS,1) + "s", "Orbit", 4).
  TERM_print("ECC: " + ROUND(SHIP:ORBIT:ECCENTRICITY, 4), "Orbit", 5).
  TERM_print("INC: " + ROUND(SHIP:ORBIT:INCLINATION, 4) + "°", "Orbit", 6).
  LOCAL periodString IS
    CHOOSE (ROUND(SHIP:ORBIT:PERIOD, 2) + "s")
      IF SHIP:ORBIT:ECCENTRICITY < 0.999 AND NOT SHIP:ORBIT:HASNEXTPATCH
      ELSE "N/A".
  TERM_print("Period: " + periodString, "Orbit", 7).
  TERM_print("Velocity: " + ROUND(VELOCITYAT(SHIP, TIME:SECONDS):ORBIT:MAG, 1) + "m/s", "Orbit", 8).
  // 9 empty
  TERM_print("Mission Time: " + ROUND(getMissionTime(), 1) + "s", "Orbit", 10).
  TERM_print("Mission Step: " + mission["getStage"](), "Orbit", 11).
  
  RETURN TRUE.
}

LOCAL FUNCTION drawTerm
{
  PARAMETER mission.
  
  TERM_draw().
  RETURN TRUE.
}

LOCAL FUNCTION execNodeWithAutostage
{
  PARAMETER mission.
  PARAMETER maxStageNum IS 0.
  
  autostage(maxStageNum).
  
  IF MNV_nodeExec(TRUE)
  {
    mission["nextStage"]().
  }
}

LOCAL FUNCTION autostage
{
  PARAMETER maxStageNum.
  
  IF SHP_burnout() AND SHIP:STAGENUM >= maxStageNum
  {
    STAGE.
    WAIT 0.2.
  }
}