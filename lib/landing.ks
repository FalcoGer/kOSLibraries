// various functions in regard to landing
REQUIRE("lib/ship.ks").

// LOCAL PID_hover IS PIDLOOP(2.7, 4.4, 0.12, 0, 1).
LOCAL PID_hover IS PIDLOOP(2.4, 4.5, 0.12, 0, 1).
LOCAL resetPID IS FALSE.

FUNCTION LDG_descendGuidance
{
  PARAMETER maxSlope IS 10.
  PARAMETER touchDownSpeed IS 1.
  PARAMETER shipSize IS 25.
  PARAMETER safetyAltitude IS 200.
  // 3a. descend on PID handling throttle, controlling for vSpeed.
  // 3b. tilt ship in direction of surface slope until max slope angle reached
  // watch speed
  
  IF (SHIP:STATUS = "ORBITING")
  {
    // 1. Deorbit
    LOCK STEERING TO RETROGRADE.
    LOCK THROTTLE TO 1.
  } ELSE IF
    (SHIP:STATUS = "SUB_ORBITAL" OR SHIP:STATUS = "FLYING")
    AND (ALT:RADAR > safetyAltitude)
  {
    // 2. Suicide burn
    
    LOCK STEERING TO LDG_descendVector().
    LOCK THROTTLE TO
      CHOOSE 0 IF (LDG_impactTime(safetyAltitude) < 0.5)
      ELSE CHOOSE 1 IF ALT:RADAR > safetyAltitude
      ELSE MIN(1 / SHP_getMaxTWR(), 1).
    SET resetPID TO TRUE.
  } ELSE IF (SHIP:STATUS = "SUB_ORBITAL" OR SHIP:STATUS = "FLYING")
    AND ((ALT:RADAR - shipSize) > 10)
  {
    // 3. hover descend
    IF NOT GEAR { GEAR ON. }
    IF resetPID { PID_hover:RESET. SET resetPID TO FALSE. }
    
    LOCK STEERING TO LDG_descendVector().
    LOCK descendSpeed TO MIN(((ALT:RADAR - shipSize) / safetyAltitude)* -50, -1).
    LOCK THROTTLE TO LDG_hover(descendSpeed).
  } ELSE {
    // 4. hover landing
    LOCK STEERING TO LOOKDIRUP(UP:VECTOR, SHIP:FACING:TOPVECTOR).
    LOCK THROTTLE TO LDG_hover(-1 * touchDownSpeed).
  }
  
  IF SHIP:STATUS = "LANDED" OR SHIP:STATUS = "SPLASHED" {
    LOCK STEERING TO LOOKDIRUP(UP:VECTOR, SHIP:FACING:TOPVECTOR).
    LOCK THROTTLE TO 0.
    WAIT 3.
    UNLOCK STEERING.
    UNLOCK THROTTLE.
    RCS OFF.
    RETURN TRUE.
  } ELSE {
    RETURN FALSE.
  }
}

LOCAL FUNCTION LDG_hover {
  PARAMETER setPoint.
  SET PID_hover:SETPOINT TO setPoint.
  LOCAL maxTWR IS SHP_getMaxTWR().
  SET PID_hover:MAXOUTPUT TO maxTWR.
  
  LOCAL pidOutput IS PID_hover:UPDATE(TIME:SECONDS, SHIP:VERTICALSPEED).
  RETURN MIN(
              pidOutput /
              MAX (COS(VANG(UP:VECTOR, SHIP:FACING:VECTOR)), 0.0001) /
              MAX (maxTWR, 0.0001)
              , 1
            ).
}

LOCAL FUNCTION LDG_descendVector
{
  IF VANG(SRFRETROGRADE:VECTOR, UP:VECTOR) > 90
  {
    RETURN LOOKDIRUP(UP:VECTOR, SHIP:FACING:TOPVECTOR).
  } ELSE
  {
    // LOCAL g IS BODY:MU / (BODY:POSITION:MAG^2).
    // RETURN LOOKDIRUP(UP:VECTOR * g - VELOCITY:SURFACE, SHIP:FACING:TOPVECTOR).
    RETURN LOOKDIRUP(SRFRETROGRADE:VECTOR, SHIP:FACING:TOPVECTOR).
  }
}

// get surface slope vector pointing away from the surface.
FUNCTION LDG_getSurfaceSlopeNormal {
  // contains body. make with
  // - SHIP:GEOPOSITION. for the current position over ground
  // - LATLON(lat, lon). for the current body
  // - <BODY>:GEOPOSITIONOF (vector3).
  // - <BODY>:GEOPOSITIONLATLON (lat, lon).
  PARAMETER geo.
  PARAMETER areaSize IS 10.0.
  
  LOCAL east IS VCRS(NORTH:VECTOR, UP:VECTOR). // cross product produces vector orthogonal to both.
  
  // create 3 points in a triangle around the position
  LOCAL pointA IS geo:BODY:GEOPOSITIONOF(geo:POSITION + ((areaSize / 2) * NORTH:VECTOR)).
  LOCAL pointB IS geo:BODY:GEOPOSITIONOF(geo:POSITION - ((areaSize / 2) * NORTH:VECTOR) + ((areaSize / 2) * east)).
  LOCAL pointC IS geo:BODY:GEOPOSITIONOF(geo:POSITION - ((areaSize / 2) * NORTH:VECTOR) - ((areaSize / 2) * east)).
  
  // get the vectors to the terrain positions
  LOCAL vecA IS pointA:ALTITUDEPOSITION(pointA:TERRAINHEIGHT).
  LOCAL vecB IS pointB:ALTITUDEPOSITION(pointB:TERRAINHEIGHT).
  LOCAL vecC IS pointC:ALTITUDEPOSITION(pointC:TERRAINHEIGHT).
  
  LOCAL vecNormal IS VCRS(vecC - vecA, vecB - vecA).
  RETURN vecNormal:NORMALIZED.
}

// get angle of slope
FUNCTION LDG_getSurfaceSlopeAngle {
  PARAMETER geo.
  PARAMETER areaSize IS 10.0.
  
  // get an UP vector to compare angles to.
  LOCAL vRadialOut IS BDY_getRadialOutVector(geo).
  LOCAL vNorm IS BDY_getSurfaceSlopeNormal(geo, areaSize).
  return VANG(vRadialOut, vNorm).
}

// get direction of the slope (downwards) as a non normalized vector.
FUNCTION LDG_getSurfaceSlopeDirectionVector {
  PARAMETER geo.
  PARAMETER areaSize IS 10.0.
  
  // vector exclude, project vector 2 onto the plane that is orthogonal to vector 1
  // or in other words remove the v1 component from v2
  RETURN VXCL (BDY_getRadialOutVector(geo), BDY_getSurfaceSlopeNormal(geo, areaSize)).
}

// when the ship reaches the altitude provided with full TWR at current ship angle
FUNCTION LDG_impactTime {
  PARAMETER cutoff.     // impact speed calculated to this point
  
  LOCAL g IS BODY:MU / (BODY:POSITION:MAG^2).
  LOCAL vSpeed IS -1 * VERTICALSPEED.
  LOCAL dist IS ALT:RADAR - cutoff.
  LOCAL maxTwr IS SHP_getMaxTWR().
  // gravity pulls down
  // TWR = 1 means gravity is negated exactly
  // anything > 1 means 1 - TWR is the current g force upwards
  // thrust up is the upward component (COS) of the ship facing vector.
  LOCAL accel IS
    g * (
      1 - (
            maxTwr * MAX(COS(VANG(UP:VECTOR, SHIP:FACING:VECTOR)), 0.0001)
          )
        ).
  
  // RETURN vSpeed^2 + 2 * accel * dist.
  
  LOCAL tmp IS 2 * accel * dist + vSpeed^2.
  // kinematic equation
  RETURN CHOOSE
    (dist / vSpeed) IF accel = 0 AND vSpeed <> 0
    ELSE CHOOSE 2^64 IF accel = 0 AND vSpeed = 0
    ELSE CHOOSE ((SQRT(ABS(tmp)) - vSpeed) / accel) IF tmp < 0
    ELSE ((-1 * SQRT(ABS(tmp)) - vSpeed) / accel).
}