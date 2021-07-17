// execute a variety of maneuvers
// all functions should only wait for very small amounts of time if at all.
// such waits may be needed for maneuver planning (hill climbing for a few seconds) and for KSP to figure out orbital patches (stretches of orbits in different SOIs).

REQUIRE("lib/math.ks").
REQUIRE("lib/ship.ks").

SET MNV_INCL_STRAT_CIRC_AT_PA TO 0.
SET MNV_INCL_STRAT_CIRC_AT_AP TO 1.
SET MNV_INCL_STRAT_LEAVE_ECCENTRIC TO 2.

// when autowarping keep track of if the warp has been done before or not.
// this is to prevent repeatedly setting warping.
SET MNV_WARP_IS_SET TO FALSE.

// execute maneuver node
// does not stage automatically!
FUNCTION MNV_nodeExec {
  PARAMETER autowarp IS false.
  PARAMETER useRCS is FALSE.              // when true will use RCS translation for fine tuning.
  PARAMETER maxDvDeviationEngine IS 2.0.  // when this speed is reached
                                          // and the maneuver node is more than maxAngleEngine behind the craft, then
                                          // switch to RCS or consider maneuver completed.
  PARAMETER allowedDvError IS 0.01.       // when the maneuver is considered completed.
  
  LOCAL minAngleEngine IS 2.              // minimum angle between ship-facing and maneuver to keep
                                          // while doing large burns above maxDvDeviationEngine
  LOCAL maxAngleEngine IS 90.             // when this angle between ship-facing and maneuver 
                                          // and when remaining dV is below maxDvDeviationEngine
                                          // is reached then engine burn is completed
  LOCAL safetyMarginToStart IS 30.        // time in seconds that is subtracted from warpto time.
  // check if a node exists
  
  IF HASNODE {
    LOCK STEERING TO NEXTNODE:BURNVECTOR.   // steer to maneuver node
    LOCK mnvDv TO NEXTNODE:BURNVECTOR:MAG.  // fetch maneuver dV
    LOCK mnvTime TO MNV_getTimeForFixedDVManeuver(NEXTNODE:BURNVECTOR:MAG).
    LOCK deltaAngle TO VANG(SHIP:FACING:VECTOR, NEXTNODE:BURNVECTOR).
    LOCK startTime TO MNV_getNodeStartTime(NEXTNODE).
    
    // check if time has come to burn
    IF TIME:SECONDS > startTime
    {
      // Do engine burn
      // only use main throttle to chase node if node is
      // within minAngleEngine of ship facing
      LOCK engineBurnRequired TO
          ((deltaAngle < minAngleEngine) AND (mnvDv > allowedDvError))
        OR
          // or if there is only a tiny bit of maneuver left
          // and the node is within maxAngleEngine, and rcs is not selected
          ((deltaAngle < maxAngleEngine) AND (mnvDv <= maxDvDeviationEngine) AND NOT useRCS).
      
      LOCK THROTTLE TO CHOOSE
        MIN(mnvTime / 0.5, 1)
        IF engineBurnRequired 
        ELSE 0.
      
      // check if engine stage is done
      IF NOT engineBurnRequired {
        // abort engine if mnvDv reached and angle above maximum allowed
        LOCK STEERING TO "kill".
        IF NOT useRCS {
          UNLOCK THROTTLE.
          UNLOCK STEERING.
          REMOVE NEXTNODE.
          WAIT 0.03.
        }
        ELSE {
          // RCS required for final correction to below allowedDvError
          IF mnvDv < allowedDvError // need correction still?
          {
            IF NOT RCS { RCS ON. }
            MNV_translation(NEXTNODE:BURNVECTOR).
          }
          else {
            // RCS correction burn completed.
            RCS OFF.
            UNLOCK THROTTLE.
            UNLOCK STEERING.
            REMOVE NEXTNODE.
            WAIT 0.03.
          }
        }
      }
    }
    ELSE {  // start time not yet reached.
      LOCAL warpCondition IS // check if we are far enough away from start
          TIME:SECONDS < (startTime - safetyMarginToStart)
          // check if we are pointing in the right direction
          AND deltaAngle < minAngleEngine.
          
      // check if autowarp is enabled
      
      IF warpCondition {
        IF autowarp AND NOT MNV_WARP_IS_SET
        {
          KUNIVERSE:TimeWarp:WARPTO(startTime - safetyMarginToStart).
          SET MNV_WARP_IS_SET TO TRUE.
        }
      }
      ELSE
      {
        // condition is no longer true, stop warp
        KUNIVERSE:TimeWarp:CANCELWARP().
        SET MNV_WARP_IS_SET TO FALSE.
        
        // wait for condition to fix itself so not to constantly
        // start and stop warping.
        WAIT 1.
      }
    }
  }
  ELSE  // no node exists
  {
    UNLOCK STEERING.
    UNLOCK THROTTLE.
  }
  // if there are still nodes, then say we're still doing stuff by sending FALSE
  // send true when we're done maneuvering.
  
  RETURN NOT HASNODE.
}

FUNCTION MNV_getNodeStartTime {
  PARAMETER n.
  RETURN n:TIME - (MNV_getTimeForFixedDVManeuver(n:BURNVECTOR:MAG) / 2).
}

// get time for maneuver with constant force mass ejection using the rocket equation
// does not handle stages.
FUNCTION MNV_getTimeForFixedDVManeuver {
  PARAMETER dv.
  
  LOCAL engineTotalThrust     IS SHP_getMaxThrust().
  LOCAL engineISP             IS SHP_getISP().
  
  IF engineTotalThrust = 0 OR engineISP = 0 {
    NOTIFY("No engine available for maneuver time.", 3).
    RETURN 0.
  }
  
  // Rocket equation
  LOCAL f IS engineTotalThrust * 1000.  // [kg * m/s^2] - thrust is in kN, we need N
  LOCAL m IS SHIP:MASS * 1000.          // [kg]         - ship mass is in metric tonns, we need kg
  LOCAL e IS CONSTANT:E.                // [1]          - for simplicity
  LOCAL p IS engineISP.                 // [s]          - for simplicity
  LOCAL g IS BODY:MU/BODY:RADIUS^2.     // [m/s^2]      - gravitational constant.
  
  LOCAL t IS g * m * p * (1 - e^(-dV / (g * p))) / f.
  RETURN t.
}

FUNCTION MNV_translation {
  PARAMETER vector.
  
  IF vector:MAG > 1 { SET vector TO vector:NORMALIZED. }
  
  SET SHIP:CONTROL:STARBOARD  TO vector * SHIP:FACING:STARVECTOR.
  SET SHIP:CONTROL:FORE       TO vector * SHIP:FACING:FOREVECTOR.
  SET SHIP:CONTROL:TOP        TO vector * SHIP:FACING:TOPVECTOR.
}