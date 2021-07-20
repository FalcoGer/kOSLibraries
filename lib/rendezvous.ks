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
  PARAMETER dist.                           // final closest approach
  PARAMETER approachTime.                   // when the closest approach is supposed to be.
  PARAMETER mnvTime IS TIME:SECONDS + 120.  // when correction burn is scheduled
  // use hill climbing to fine tune approach
  
  LOCAL initialData IS LIST(mnvTime,0,0,0, dist, approachTime).
  LOCAL stepSize IS LIST(0, 4, 0, 4, 0, 0).
  LOCAL fitnessFunction IS RDV_fitnessClosestApproachAtTime@.
  LOCAL numOfSteps IS 6.
  
  LOCAL nodeData IS MATH_hillClimb(initialData, stepSize, fitnessFunction, numOfSteps).
  
  ADD NODE(nodeData[0], nodeData[1], nodeData[2], nodeData[3]).
}

LOCAL FUNCTION RDV_fitnessClosestApproachAtTime {
  PARAMETER nodeData.
  
  LOCAL aprTime IS nodeData[5].
  
  LOCAL n IS NODE(nodeData[0], nodeData[1], nodeData[2], nodeData[3]).
  ADD n.
  WAIT 0.03.
  
  LOCAL dist IS (POSITIONAT(SHIP, aprTime) - POSITIONAT(TARGET, aprTime)):MAG.
  REMOVE n.
  
  RETURN -1 * ABS(dist - nodeData[4]).
}

FUNCTION RDV_killRelativeSpeed
{
  LOCAL closestApproachData IS TGT_closestApproach(TIME:SECONDS, TIME:SECONDS + ORBIT:PERIOD).
  // LOCAL closestDistance IS closestApproachData[0].
  LOCAL closestTime IS closestApproachData[1].
  
  LOCAL tVel IS VELOCITYAT(TARGET, closestTime):ORBIT.
  LOCAL sVel IS VELOCITYAT(SHIP, closestTime):ORBIT.
  
  // queue maneuver node
  LOCAL n IS MATH_nodeFromVector(closestTime, tVel - sVel).
  ADD n.
}

// find a docking port to dock to.
FUNCTION RDV_getDockingPortTarget
{
  PARAMETER ownPort.
  PARAMETER name IS "".
  
  LOCAL tgt IS TARGET.
  
  IF tgt:TYPENAME <> "Vessel" { SET tgt TO tgt:SHIP. }
  
  LOCAL pList IS tgt:DOCKINGPORTS.
  FOR p IN pList {
    IF p:TARGETABLE AND NOT p:HASPARTNER AND p:NODETYPE = ownPort:NODETYPE
    {
      IF name = "" OR (p:NAME = name OR p:TITLE = name OR p:TAG = name)
      {
        RETURN p.
      }
    }
  }
}

FUNCTION RDV_docking
{
  PARAMETER ownPort.
  PARAMETER targetPort.
  PARAMETER safetyDistance IS 200.
  PARAMETER angle IS 0.             // angle at which to dock at.
  
  IF ownPort:TYPENAME <> "DockingPort" { LOCAL failure IS 1/0. }
  IF targetPort:TYPENAME <> "DockingPort" { LOCAL failure IS 1/0. }
  
  // some constants
  LOCAL maxSpeed IS 3.
  LOCAL finalApproachSpeed IS 0.5.
  LOCAL slowDownDistance IS safetyDistance / 2.
  
  // some measurements
  LOCAL ownPortPos IS ownPort:NODEPOSITION.
  LOCAL targetPortPos IS targetPort:NODEPOSITION - ownPortPos.
  
  LOCAL rVel IS SHIP:VELOCITY:ORBIT - targetPort:SHIP:VELOCITY:ORBIT.
  LOCAL t2s IS -1 * (targetPortPos - ownPortPos).
  LOCAL tgtFwd IS targetPort:PORTFACING:VECTOR.
  LOCAL tgtUp IS MATH_vecRotToVec(targetPort:PORTFACING:TOPVECTOR, targetPort:PORTFACING:STARVECTOR, angle).
  LOCAL angleOffset IS VANG(tgtFwd, t2s).
  LOCAL sideVector IS VCRS(VCRS(tgtFwd, t2s), tgtFwd):NORMALIZED * safetyDistance.
  
  IF
      (targetPortPos:MAG < 190)
    AND
      (NOT HASTARGET
        OR (HASTARGET AND TARGET <> targetPort)
      )
  {
    SET TARGET TO targetPort.
  }
  
  LOCAL targetPosition IS 
            // we are behind the target. Move to side position first.
            CHOOSE targetPortPos + sideVector IF angleOffset > 90 AND (t2s:MAG > 3)
            // we are way out of line
      ELSE  CHOOSE tgtFwd * safetyDistance + targetPortPos IF angleOffset > 30 AND targetPortPos:MAG > 3
            // we are in line and farther away than safetyDistance / 4
      ELSE  CHOOSE tgtFwd * (safetyDistance / 8) + targetPortPos IF targetPortPos:MAG > (safetyDistance / 4)
            // we are in front of the docking port, but not in line
            // move towards centerline
      ELSE  CHOOSE tgtFwd * (t2s:MAG * 0.95 * COS(angleOffset)) + targetPortPos
        IF angleOffset > (5 * (1 - t2s:MAG / (safetyDistance / 4))) AND targetPortPos:MAG > 3
            // we are in line and no farther than safetyDistance / 4
      ELSE  tgtFwd * (t2s:MAG * 0.5 * COS(angleOffset)) + targetPortPos.
  
  // point directly at the target port at the specified angle
  LOCK STEERING TO LOOKDIRUP(-1 * tgtFwd, tgtUp).
  
  // calculate speed
  LOCAL approachSpeed IS MIN(maxSpeed, MAX((targetPosition:MAG / slowDownDistance) * maxSpeed, finalApproachSpeed)).
  // calculate maneuvering
  LOCAL manVec IS (targetPosition:NORMALIZED * approachSpeed) - rVel.
  
  IF NOT RCS { RCS ON. }
  MNV_translation(manVec).
  
  RETURN ownPort:HASPARTNER.
}
