
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

FUNCTION SHP_getPartsCount {
  LOCAL partList IS LIST().
  LIST PARTS IN partList.
  RETURN partList:LENGTH().
}

LOCK SHP_PARTSLIST_COUNT TO SHP_getPartsCount().

// Add event handlers for different events that change the bounding box.
// add a few seconds extra for the panels or gears to fully deploy
ON GEAR                 { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON LEGS                 { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON PANELS               { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
// airbrakes are considered brakes, they extend
ON BRAKES               { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON BAYS                 { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON RADIATORS            { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON LADDERS              { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON DEPLOYDRILLS         { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
// some RCS thrusters deploy from a receeded position.
ON RCS                  { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON SHIP:STAGENUM        { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 0.25. RETURN TRUE. }
ON SHP_PARTSLIST_COUNT  { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 0.25. RETURN TRUE. }
// assume action groups do extend or retract something.
ON AG1                  { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON AG2                  { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON AG3                  { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON AG4                  { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON AG5                  { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON AG6                  { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON AG7                  { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON AG8                  { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON AG9                  { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }
ON AG10                 { SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO TIME:SECONDS + 5.    RETURN TRUE. }


// returns the size of the bounding box for the ship
FUNCTION SHP_size {
  PARAMETER updateBox IS FALSE. // updates bounding box. this is expensive, only do when above occurs
  IF NOT SHP_boundingBox OR updateBox OR SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME > TIME:SECONDS {
    SET SHP_boundingBox TO SHIP:BOUNDS.
    SET SHP_SCHEDULE_SHIP_SIZE_UPDATE_TIME TO 0.
  }
  RETURN SHP_boundingBox:SIZE.
}