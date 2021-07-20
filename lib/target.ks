// variety of functions in regards to target bodies or vessels

REQUIRE("lib/math.ks").
REQUIRE("lib/orbit.ks").
REQUIRE("lib/maneuver.ks").

FUNCTION TGT_transfer
{
  PARAMETER bothNodes IS TRUE.                // if false, will only plot starting node
  PARAMETER final_orbit_periapsis IS 100_000.
  PARAMETER final_orbit_type IS "circular".   //  "none", "circular" or "elliptical"
  PARAMETER final_orbit_orientation IS "prograde". // "prograde", "polar", "retrograde"
  PARAMETER earliest_departure IS -1.
  PARAMETER search_duration IS -1.            // how long into the future will we search
  PARAMETER search_interval IS -1.
  PARAMETER max_time_of_flight IS -1.
  PARAMETER VERB IS FALSE.
  
  IF NOT HASTARGET { RETURN FALSE. }  // sanity check
  
  LOCAL options IS LEXICON(
    "verbose", VERB
    , "create_maneuver_nodes", CHOOSE "both" IF bothNodes ELSE "first"
    , "final_orbit_periapsis", final_orbit_periapsis
    , "final_orbit_type", final_orbit_type
    , "final_orbit_orientation", final_orbit_orientation
  ).
  
  IF earliest_departure >= 0 {
    SET options["earliest_departure"] TO earliest_departure.
  }
  
  IF search_duration >= 0 {
    SET options["search_duration"] TO search_duration.
  }
  
  IF search_interval >= 0 {
    SET options["search_interval"] TO search_interval.
  }
  
  IF max_time_of_flight >= 0 {
    SET options["max_time_of_flight"] TO max_time_of_flight.
  }
  
  WAIT UNTIL CHECK_CONNECTION() {
    RUNONCEPATH("0:/lib/rsvp/main.ks").
  }
  
  LOCAL ret IS rsvp["goto"](TARGET, options).
  
  RETURN ret.
}

// only works for coplanar, circular orbits
FUNCTION TGT_hohmannTransfer {
  PARAMETER tgt IS TARGET.
  // https://www.faa.gov/about/office_org/headquarters_offices/avs/offices/aam/cami/library/online_libraries/aerospace_medicine/tutorial/media/III.4.1.5_Maneuvering_in_Space.pdf
    
  LOCAL r1 IS SHIP:ORBIT:SEMIMAJORAXIS.
  LOCAL r2 IS tgt:ORBIT:SEMIMAJORAXIS.
  LOCAL dV IS ORB_hohmannDv(r2 - BODY:RADIUS)[0].
  
  // angular velocity
  LOCAL w1 IS ORB_angularVelocityCircular(SHIP).
  LOCAL w2 IS ORB_angularVelocityCircular(tgt).
  
  LOCAL transferTime IS CONSTANT:PI * SQRT( ((r1+r2)/2)^3 / BODY:MU ).
  // how much the target moves during the maneuver
  LOCAL leadAngle IS transferTime * w2.
  // we move 180°, so that's compensated for in the phase angle
  LOCAL phaseAngle IS 180 - leadAngle.
  SET phaseAngle TO MOD(phaseAngle + 360, 360).
  
  // calculate the wait time for the phase angle to be perfect
  LOCAL currentPhaseAngle IS TGT_phaseAngle(tgt).
  
  // current difference to perfect angle / phase angle change rate
  LOCAL etaMnv IS (phaseAngle - currentPhaseAngle) / (w2 - w1).
  IF etaMnv < 0 {
    // add 360 to make node be in the next orbit.
    SET etaMnv TO (phaseAngle + 360 - currentPhaseAngle) / (w2 - w1).
  }
  
  LOCAL n IS NODE(TIME:SECONDS + etaMnv, 0, 0, dV).
  ADD n.
  WAIT 0.02.
}

FUNCTION TGT_fineTuneApproach {
  PARAMETER finalPE.                        // final closest approach
  PARAMETER finalInclination IS 0.
  PARAMETER mnvTime IS TIME:SECONDS + 120.  // when correction burn is scheduled
  // use hill climbing to fine tune approach
  PARAMETER tgt IS TARGET.
  
  LOCAL initialData IS LIST(mnvTime,0,0,0, finalPE, finalInclination, tgt).
  LOCAL stepSize IS LIST(0, 16, 16, 16, 0, 0, 0).
  LOCAL fitnessFunction IS TGT_fitnessFineTuneApproach@.
  LOCAL numOfSteps IS 10.
  
  LOCAL nodeData IS MATH_hillClimb(initialData, stepSize, fitnessFunction, numOfSteps).
  
  LOCAL n IS NODE(nodeData[0], nodeData[1], nodeData[2], nodeData[3]).
  ADD n.
  WAIT 0.02.
}

LOCAL FUNCTION TGT_fitnessFineTuneApproach {
  PARAMETER data.
  
  // unpack data
  LOCAL n IS NODE(data[0], data[1], data[2], data[3]).
  LOCAL finalPE IS data[4].
  LOCAL finalInclination IS data[5].
  LOCAL tgt IS data[6].
  
  ADD n.
  WAIT 0.05.
  
  // calculate fitness
  LOCAL actualPE IS CHOOSE n:ORBIT:NEXTPATCH:PERIAPSIS IF n:ORBIT:HASNEXTPATCH ELSE ORBIT:PERIAPSIS.
  LOCAL actualINC IS CHOOSE n:ORBIT:NEXTPATCH:INCLINATION IF n:ORBIT:HASNEXTPATCH ELSE ORBIT:INCLINATION.
  LOCAL dV IS n:BURNVECTOR:MAG.
  
  LOCAL fitness IS CHOOSE
    -1 * MATH_infinity
    // if we have left SOI change
    IF (n:ORBIT:HASNEXTPATCH AND n:ORBIT:NEXTPATCH:BODY <> tgt) OR (NOT n:ORBIT:HASNEXTPATCH AND n:ORBIT:BODY <> tgt)
    // else optimize for PE, INC and dV
    ELSE -1 * (ABS(actualPE - finalPE) * ABS(actualINC - finalInclination) + (dV / 4)).
  
  REMOVE n.
  WAIT 0.02.
  
  RETURN fitness.
}

// return the seperation at a specified time
// considering all maneuver nodes are executed as planned. (POSITIONAT does that)
FUNCTION TGT_seperationAt {
  PARAMETER t.                  // time to measure the seperation
  PARAMETER tgt IS TARGET.
  
  RETURN (POSITIONAT(SHIP, t) - POSITIONAT(tgt, t)):MAG.
}

// return rate of change of range to target at time t.
// rate of change negative: moving away
// rate of change positive: moving closer
FUNCTION TGT_interceptRoC {
  PARAMETER t.
  PARAMETER tgt IS TARGET.
  
  RETURN (
    TGT_seperationAt(t + 0.5, tgt)
    - TGT_seperationAt(t - 0.5, tgt)
  ) / 2.
}

// returns closest approach distance and time to the target.
FUNCTION TGT_closestApproach {
  PARAMETER tStart.
  PARAMETER tEnd.
  PARAMETER tgt IS TARGET.
  
  // can't rely on binary search alone, orbit may intersect twice, giving 2 local minima
  
  // run over the entire timeFrame to find roughly where the closest approach is
  {
    LOCAL bestSeperation IS MATH_infinity.
    LOCAL bestTime IS tStart.
    // at least 36 steps per orbit or 36 steps
    LOCAL deltaTime IS MIN((tEnd - tStart), SHIP:ORBIT:PERIOD) / 36.
    FROM { LOCAL t IS tStart. } UNTIL ( t >= tEnd ) STEP { SET t TO t + deltaTime. } DO {
      LOCAL sep IS TGT_seperationAt(t, tgt).
      IF sep < bestSeperation
      {
        SET bestSeperation TO sep.
        SET bestTime TO t.
      }
    }
    
    SET tStart TO bestTime.
    SET tEnd TO bestTime + deltaTime.
  }
  
  // run binary search to find the precise position.
  LOCAL tMiddle IS (tStart + tEnd) / 2.
  LOCAL rocStart IS TGT_interceptRoC(tStart, tgt).
  LOCAL rocEnd IS TGT_interceptRoC(tEnd, tgt).
  LOCAL rocMiddle IS TGT_interceptRoC(tMiddle, tgt).
  
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
    SET rocMiddle TO TGT_interceptRoC(tMiddle, tgt).
  }
  
  RETURN LIST(TGT_seperationAt(tMiddle, tgt), tMiddle).
}

// returns true if the next patch is in the target's SOI
FUNCTION TGT_isSOIChangeToTgt {
  PARAMETER orbitToTest IS CHOOSE 
    NEXTNODE:ORBIT IF HASNODE ELSE SHIP:ORBIT.
  PARAMETER tgt IS TARGET.
  
  // sanity check
  IF (NOT HASTARGET) OR (tgt:TYPENAME <> "Body") { RETURN FALSE. }
  
  RETURN ORBIT:HASNEXTPATCH AND ORBIT:NEXTPATCH:BODY = tgt.
}

// finds times to AN and DN and returns them as a list.
FUNCTION TGT_findAN_DN_time
{
  PARAMETER tgt IS CHOOSE TARGET IF HASTARGET ELSE SHIP.
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
  LOCAL tgtNorm IS CHOOSE ORB_getNormal(tgt) IF tgt <> SHIP AND tgt <> SHIP:BODY ELSE ORB_getNormal(SHIP:BODY).
  LOCAL tgtPos IS CHOOSE POSITIONAT(tgt, startTime) - sbp IF tgt <> SHIP AND tgt <> SHIP:BODY ELSE VCRS(POSITIONAT(SHIP, startTime) - sbp, tgtNorm).
  
  
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
FUNCTION TGT_matchInclination {
  PARAMETER tgt IS CHOOSE TARGET IF HASTARGET ELSE SHIP.
  
  LOCAL anDn IS TGT_findAN_DN_time(tgt).
  LOCAL deltaInc IS CHOOSE VANG(ORB_getNormal(), ORB_getNormal(tgt)) IF tgt <> SHIP AND tgt <> SHIP:BODY ELSE SHIP:ORBIT:INCLINATION.
  
  // generate maneuver node at next slowest an or dn
  LOCAL vAN IS VELOCITYAT(SHIP, anDn[0]):ORBIT:MAG.
  LOCAL vDN IS VELOCITYAT(SHIP, anDn[1]):ORBIT:MAG.
  
  IF (vAN < vDN) {
    // do inclination change at AN
    ORB_changeIncl(anDn[0], -1 * deltaInc).
  } ELSE {
    // do inclination change at DN
    ORB_changeIncl(anDn[1], deltaInc).
  }
}

FUNCTION TGT_phaseAngle {
  PARAMETER tgt IS CHOOSE TARGET IF HASTARGET ELSE SHIP.
  IF tgt = SHIP { RETURN 0. }
  
  LOCAL bdyPos IS SHIP:BODY:POSITION.
  LOCAL bdyToShip IS bdyPos * -1.
  LOCAL bdyToTgt IS tgt:POSITION - bdyPos.
  
  LOCAL angle IS VANG(bdyToShip, bdyToTgt).
  LOCAL crs IS VCRS(bdyToShip, bdyToTgt). // points down if ahead, up otherwise.
  LOCAL nrm IS ORB_getNormal().
  
  IF VANG(nrm, crs) > 90 {
    // target ahead
    RETURN angle.
  } ELSE {
    // target behind
    RETURN 360 - angle.
  }
}