// functions to intercept and dock with targets

REQUIRE("lib/target.ks").
REQUIRE("lib/maneuver.ks").
REQUIRE("lib/orbit.ks").
REQUIRE("lib/math.ks").

// plot intercept node
FUNCTION RDV_intercept {
  LOCAL EccLimit IS 0.01.
  LOCAL DIncLimit IS 0.2.
  
  IF NOT HASTARGET OR (TARGET:TYPENAME = "Body") { RETURN FALSE. }
  IF SHIP:ORBIT:ECCENTRICITY > EccLimit { RETURN FALSE. }
  
  LOCAL useLambert IS FALSE. // try to avoid super slow lambert solver if possible
  
  // check if target orbit is circular
  IF TARGET:ORBIT:ECCENTRICITY > EccLimit { SET useLambert TO TRUE. }
  
  // check if inclination is matching
  {
    LOCAL normShip IS ORB_getNormal().
    LOCAL normTgt IS ORB_getNormal(TARGET).
    
    LOCAL deltaInc IS VANG(normShip, normTgt).
    IF deltaInc > DIncLimit { SET useLambert TO TRUE. }
  }
  
  // difference between periods is how much the orbit shifts.
  // dividing the period by that number is how many orbits until every solution has been tried
  // multiplying that with the orbit period is how long to search.
  LOCAL searchDuration IS (MAX(SHIP:ORBIT:PERIOD, TARGET:ORBIT:PERIOD)^2) / ABS(SHIP:ORBIT:PERIOD - TARGET:ORBIT:PERIOD).
  
  // allow some time for maneuver node calculation
  LOCAL earliestDeparture IS TIME:SECONDS + 300.
  
  IF useLambert {
    LOCAL bothNodes IS FALSE.
    LOCAL finalPE IS 0.
    LOCAL orbitType IS "none".
    LOCAL orbitOrient IS "prograde".
    LOCAL searchInterval IS -1.
    LOCAL maxTimeOfFlight IS -1.
    LOCAL verb IS FALSE.
    TGT_transfer(
      bothNodes
      , finalPE
      , orbitType
      , orbitOrient
      , earliestDeparture
      , searchDuration
      , searchInterval
      , maxTimeOfFlight
      , verb
    ).
  } ELSE {
    // we are in the same plane and we are both circular.
    // this makes it faster to get the closest approach maneuver
    TGT_hohmannTransfer().
  }
}

FUNCTION RDV_fineTuneApproach {
  PARAMETER mnvTime IS TIME:SECONDS + 120.
  // use hill climbing to fine tune approach
  
  LOCAL initialData IS LIST(mnvTime,0,0,0).
  LOCAL stepSize IS LIST(0, 4, 4, 4).
  LOCAL fitnessFunction IS RDV_fitnessClosestApproachAtAP@.
  LOCAL numOfSteps IS 6.
  
  LOCAL nodeData IS MATH_hillClimb(initialData, stepSize, fitnessFunction, numOfSteps).
  
  ADD NODE(nodeData[0], nodeData[1], nodeData[2], nodeData[3]).
}

LOCAL FUNCTION RDV_fitnessClosestApproachAtAP {
  PARAMETER nodeData.
  
  LOCAL n IS NODE(nodeData[0], nodeData[1], nodeData[2], nodeData[3]).
  ADD n.
  WAIT 0.03.
  
  LOCAL apTime IS n:ORBIT:ETA:APOAPSIS + TIME:SECONDS.
  
  LOCAL dist IS (POSITIONAT(SHIP, apTime) - POSITIONAT(TARGET, apTime)):MAG.
  REMOVE n.
  
  RETURN -1 * dist.
}

FUNCTION RDV_killRelativeSpeed
{
  PARAMETER dist IS 100.  // at what distance do we want the speed to be 0.
  
  LOCAL closestApproachData IS TGT_closestApproach(TIME:SECONDS, TIME:SECONDS + ORBIT:PERIOD).
  LOCAL closestDistance IS closestApproachData[0].
  LOCAL closestTime IS closestApproachData[1].
  
  //TODO
}