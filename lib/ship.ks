FUNCTION SHP_getMaxThrust {
  LOCAL thr IS 0.
  LOCAL pressure IS CHOOSE 0 IF BODY:ATM:EXISTS ELSE BODY:ATM:ALTITUDEPRESSURE(ALTITUDE).
  FOR engine IN SHP_activeEngines() {
    SET thr TO thr + engine:AVAILABLETHRUSTAT(pressure).
  }
  return thr.
}

FUNCTION SHP_getMaxTWR {
  return SHP_getMaxThrust() / (SHIP:MASS * 1000.0).
}

FUNCTION SHP_getISP {
  LOCAL specificImpulse IS 0.
  LOCAL engineList IS SHP_activeEngines()
  IF engineList:LENGTH() = 0 { RETURN 0. }
  LOCAL pressure IS SHP_pressure().
  FOR engine IN engineList {
    SET specificImpulse TO specificImpulse + engine:ISPAT(pressure).
  }
  SET specificImpulse TO specificImpulse / engineList:LENGTH().
  return specificImpulse.
}

FUNCTION SHP_pressure()
{
  RETURN CHOOSE
    0 IF BODY:ATM:EXISTS OR BODY:ATM:HEIGHT < ALTITUDE 
    BODY:ATM:ALTITUDEPRESSURE(ALTITUDE).
}

// returns number of active engines that have not flamed out
FUNCTION SHP_activeEngines {
  LOCAL activeEngines IS LIST().
  LOCAL engineList    IS LIST().
  
  LIST ENGINES        TO engineList.
  
  FOR engine IN engineList {
    IF engine:IGNITION AND NOT engine:FLAMOUT {
      engineList:ADD(engine).
    }
  }
  
  return engineList.
}

// returns list of flamed out, active engines.
FUNCTION SHP_burnedOutEngines {
  LOCAL activeEngines IS LIST().
  LOCAL engineList    IS LIST().
  
  LIST ENGINES        TO engineList.
  
  FOR engine IN engineList {
    IF engine:IGNITION AND engine:FLAMOUT {
      engineList:ADD(engine).
    }
  }
  
  return engineList.
}

// returns if any engine has flamed out (for staging)
// this may be a problem if air breathing engines are brought to space, they need to be deactivated
// then they will not count as flamed out.
// may also be a problem with multi mode engines
FUNCTION SHP_burnout {
  RETURN SHP_burnedOutEngines():LENGTH() > 0.
}

GLOBAL SHP_boundingBox IS FALSE.
// remember to update when any of the following occur
// parts growing/shrinking:
//   - deploying gear [semi auto] (only if used with gear button, not manual gear extention)
//   - deploying solar [semi auto] (only if used with PANELS ON/OFF in script)
//   - deploying cargo doors
//   - moving robotic parts
// adding or removing parts:
//   - docking [auto]
//   - staging [auto]
//   - explosions/parts destroyed [auto]
//   - asteroid grabber claw [auto]
//   - deploying fairing [auto]
//  new control from orientation (navball jumps), changing the meaning of FORE, STAR and UP:
//   - docking port control from
//   - landing can
//   - probe core switching
//   - entering IVA (changes control from part, apparently)


// we can automatically handle a few of these.
GLOBAL SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME IS 0.
GLOBAL SHP_PARTSLIST_COUNT IS 0.
LOCK SHP_PARTSLIST_COUNT TO
{
  LOCAL partList IS LIST().
  LIST PARTS IN partList.
  RETURN partList:COUNT().
}().

// Add event handlers for different events that change the bounding box.
// add a few seconds extra for the panels or gears to fully deploy
ON GEAR                 DO { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON LEGS                 DO { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON PANELS               DO { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
// airbrakes are considered brakes, they extend
ON BRAKES               DO { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON BAYS                 DO { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON RADIATORS            DO { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON LADDERS              DO { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON DEPLOYDRILLS         DO { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
// some RCS thrusters deploy from a receeded position.
ON RCS                  DO { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON SHIP:STAGENUM        DO { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 0.25. RETURN TRUE. }
ON SHP_PARTSLIST_COUNT  DO { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 0.25. RETURN TRUE. }
// assume action groups do extend or retract something.
ON AG1                  DO { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON AG2                  DO { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON AG3                  DO { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON AG4                  DO { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON AG5                  DO { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON AG6                  DO { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON AG7                  DO { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON AG8                  DO { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON AG9                  DO { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON AG10                 DO { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }


// returns the size of the bounding box for the ship
FUNCTION SHP_size {
  PARAMETER updateBox IS FALSE. // updates bounding box. this is expensive, only do when above occurs
  IF NOT SHP_boundingBox OR updateBox OR SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME > TIME:SECONDS {
    SET SHP_boundingBox TO SHIP:BOUNDS.
    SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO 0.
  }
  RETURN SHP_boundingBox:SIZE.
}