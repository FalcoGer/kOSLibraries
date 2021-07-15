// variety of functions in regards to target bodies or vessels

REQUIRE("lib/math.ks").
REQUIRE("lib/orbit.ks").
REQUIRE("lib/test.ks").
REQUIRE("lib/maneuver.ks").

RUNONCEPATH("0:/lib/rsvp/main.ks").

FUNCTION TGT_transfer
{
  PARAMETER bothNodes IS TRUE.                // if false, will only plot starting node
  PARAMETER final_orbit_periapsis IS 100_000.
  PARAMETER earliest_departure IS TIME:SECONDS + 120.
  PARAMETER search_duration IS -1.            // how long into the future will we search
  PARAMETER final_orbit_type IS "circular".   //  "none", "circular" or "elliptical"
  PARAMETER final_orbit_orientation IS "prograde". // "prograde", "polar", "retrograde"
  PARAMETER search_interval IS -1.
  PARAMETER max_time_of_flight IS -1.
  PARAMETER VERB IS FALSE.
  
  IF NOT HASTARGET { RETURN FALSE. }  // sanity check
  
  LOCAL options IS LEXICON(
    "verbose", VERB
    , "create_maneuver_nodes", CHOOSE "both" IF bothNodes ELSE "first"
    , "earliest_departure", earliest_departure
    , "final_orbit_periapsis", final_orbit_periapsis
    , "final_orbit_type", final_orbit_type
    , "final_orbit_orientation", final_orbit_orientation
  ).
  
  IF search_duration >= 0 {
    SET options["search_duration"] TO search_duration.
  }
  
  IF search_interval >= 0 {
    SET options["search_interval"] TO search_interval.
  }
  
  IF max_time_of_flight >= 0 {
    SET options["max_time_of_flight"] TO max_time_of_flight.
  }
  
  IF NOT HASTARGET { RETURN FALSE. }  // sanity check
  LOCAL ret IS rsvp["goto"](TARGET, options).
  
  RETURN ret.
}

// return the seperation at a specified time
// considering all maneuver nodes are executed as planned. (POSITIONAT does that)
FUNCTION TGT_seperationAt {
  PARAMETER t.                  // time to measure the seperation
  IF NOT HASTARGET { RETURN 0. }  // sanity check
  
  RETURN (POSITIONAT(SHIP, t) - POSITIONAT(TARGET, t)):MAG.
}

// return rate of change of range to target at time t.
// rate of change negative: moving away
// rate of change positive: moving closer
FUNCTION TGT_interceptRoC {
  PARAMETER t.
  IF NOT HASTARGET { RETURN 0. }  // sanity check
  
  RETURN (
    TGT_seperationAt(t + 0.5)
    - TGT_seperationAt(t - 0.5)
  ) / 2.
}

// returns closest approach distance and time to the target.
FUNCTION TGT_closestApproach {
  PARAMETER tStart.
  PARAMETER tEnd.
  
  IF NOT HASTARGET { RETURN LIST(0,0). }  // sanity check
  
  LOCAL tMiddle IS (tStart + tEnd) / 2.
  LOCAL rocStart IS TGT_interceptRoC(tStart).
  LOCAL rocEnd IS TGT_interceptRoC(tEnd).
  LOCAL rocMiddle IS TGT_interceptRoC(tMiddle).
  
  LOCAL LIMIT_TIME IS 0.1.    // when we found the closest approach time down to this many seconds
  LOCAL LIMIT_SLOPE IS 0.1.   // when we found the closest approach to this many m/s approach speed
  
  // use binary search to find out where the rate of change is closest to 0 
  UNTIL (tEnd - tStart < 0.1) OR (ABS(rocMiddle) < LIMIT_SLOPE) {
    IF (rocMiddle * rocStart) > 0 {
      // both were positive or negative, so we're still approaching/receeding
      // need change from positive to negative or the other way
      // for the roc to be 0.
      SET tStart TO tMiddle.
    } ELSE {
      SET tEnd TO tMiddle.
    }
    SET tMiddle TO (tStart + tEnd) / 2.
    SET rocMiddle TO TGT_interceptRoC(tMiddle).
  }
  
  RETURN LIST(TGT_seperationAt(tMiddle), tMiddle).
}

// returns true if the next patch is in the target's SOI
FUNCTION TGT_isSOIChangeToTgt {
  PARAMETER orbitToTest IS CHOOSE 
    NEXTNODE:ORBIT IF HASNODE ELSE SHIP:ORBIT.
  
  // sanity check
  IF (NOT HASTARGET) OR (TARGET:TYPENAME <> "Body") { RETURN FALSE. }
  
  RETURN ORBIT:HASNEXTPATCH AND ORBIT:NEXTPATCH:BODY = TARGET.
}

// finds times to AN and DN and returns them as a list.
FUNCTION TGT_findAN_DN_time
{
  // const indexes
  LOCAL AN IS 0.
  LOCAL DN is 1.
  LOCAL anDnTime IS LIST(-1, -1).
  
  LOCAL timeStep IS SHIP:ORBIT:PERIOD / 64. // very unlikely that an and dn are in the same 1/64th of the orbital period.
  
  // if we find a transition we set the node time to the time of the start of the loop
  // so not to go before the current time we add the time step to the start time.
  // and start from there.
  LOCAL startTime IS TIME:SECONDS + timeStep.
  LOCAL endTime IS startTime + SHIP:ORBIT:PERIOD.
  
  // to convert to body centric reference frame.
  LOCK sbp TO SHIP:BODY:POSITION.
  
  // parameters for orbital plane for
  // MATH_distancePointToPlane(POSITIONAT(SHIP, t) - sbp, tgtNorm, tgtPos)
  LOCAL tgtNorm IS CHOOSE ORB_getNormal(TARGET) IF HASTARGET AND TARGET <> SHIP:BODY ELSE ORB_getNormal(SHIP:BODY).
  LOCAL tgtPos IS CHOOSE POSITIONAT(TARGET, startTime) - sbp IF HASTARGET AND TARGET <> SHIP:BODY ELSE VCRS(POSITIONAT(SHIP, startTime) - sbp, tgtNorm).
  
  
  LOCAL lastD IS MATH_distancePointToPlane(POSITIONAT(SHIP, startTime - timeStep) - sbp, tgtNorm, tgtPos).
  
  // run through orbit and determine distance to target orbital plane at every step to find preliminary AN and DN
  // can not use binary search because AN and DN might be in the same half
  FROM { LOCAL t IS startTime. } UNTIL (t > endTime) STEP { SET t TO t + timeStep. } DO {
    LOCAL d IS MATH_distancePointToPlane(POSITIONAT(SHIP, t) - sbp, tgtNorm, tgtPos).
    IF d * lastD < 0 {
      // changed from below to above or from above to below, find out which.
      // and set the time to before the transition happened.
      IF (d > 0) { SET anDnTime[AN] TO t - timeStep. }
      ELSE { SET anDnTime[DN] TO t - timeStep. }
      
      IF (anDnTime[AN] > -1) AND (anDnTime[DN] > -1) {
        // found both, can exit loop.
        BREAK.
      }
    }
    
    SET lastD TO d.
  }
  
  // fine tune AN and DN to 0.1s precision.
  UNTIL timeStep < 0.1 {
    SET timeStep TO timeStep / 2.
    
    // binary search from last found An to An + timeStep
    LOCAL d0 IS MATH_distancePointToPlane(POSITIONAT(SHIP, anDnTime[AN]) - sbp, tgtNorm, tgtPos).
    LOCAL d1 IS MATH_distancePointToPlane(POSITIONAT(SHIP, anDnTime[AN] + timeStep) - sbp, tgtNorm, tgtPos).
    IF (d0 * d1) > 0 {
      // transition happens in the second half.
      SET anDnTime[AN] TO anDnTime[AN] + timeStep.
    }
    
    // binary search from last found Dn to DN + timeStep
    SET d0 TO MATH_distancePointToPlane(POSITIONAT(SHIP, anDnTime[DN]) - sbp, tgtNorm, tgtPos).
    SET d1 TO MATH_distancePointToPlane(POSITIONAT(SHIP, anDnTime[DN] + timeStep) - sbp, tgtNorm, tgtPos).
    IF (d0 * d1) > 0 {
      // transition happens in the second half.
      SET anDnTime[DN] TO anDnTime[DN] + timeStep.
    }
  }
  RETURN anDnTime.
}

// generate a node to match target inclination.
// TODO: fix no target inclination change to 0
FUNCTION TGT_matchInclination {
  LOCAL anDn IS TGT_findAN_DN_time().
  LOCAL deltaInc IS CHOOSE VANG(ORB_getNormal(), ORB_getNormal(TARGET)) IF HASTARGET AND TARGET <> SHIP:BODY ELSE SHIP:ORBIT:INCLINATION.
  
  // generate maneuver node at next slowest an or dn
  LOCAL vAN IS VELOCITYAT(SHIP, anDn[0]):ORBIT:MAG.
  LOCAL vDN IS VELOCITYAT(SHIP, anDn[1]):ORBIT:MAG.
  
  IF (vAN < vDN) {
    // do inclination change at AN
    LOCAL dV IS ORB_changeIncl(anDn[0], -1 * deltaInc).
    ADD NODE(anDn[0], dV[0], dV[1], dV[2]).
  } ELSE {
    // do inclination change at DN
    LOCAL dV IS ORB_changeIncl(anDn[1], deltaInc).
    ADD NODE(anDn[0], dV[0], dV[1], dV[2]).
  }
}