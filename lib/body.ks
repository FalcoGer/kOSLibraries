LOCK gSrf TO BDY_getGAtAltitude(SHIP:BODY, 0).
LOCK gCur TO BDY_getGAtAltitude(SHIP:BODY, SHIP:ALTITUDE).

REQUIRE("lib/math.ks").
REQUIRE("lib/ship.ks").

// control pitch for eccentricity over altitude
FUNCTION BDY_ascendGuidance {
  PARAMETER desiredAltitude.        // should not be too high
  PARAMETER PID_twr.                // let the user worry about setting up the PIDs
  PARAMETER PID_pitch.
  PARAMETER HDG IS 90.              // heading in compass degrees
  PARAMETER AoALimit IS 10.         // degrees of AoA deviation, is increased as atmos pressure decreases
  
  IF desiredAltitude < SHIP:ORBIT:APOAPSIS {
    LOCK THROTTLE TO 0.
    WAIT 0.
    UNLOCK THROTTLE.
    UNLOCK STEERING.
    RETURN TRUE.    // we're done, send true.
  }
  
  // calculate some stuff for AoA limiting
  LOCK AoA TO VANG(SHIP:SRFPROGRADE:VECTOR, SHIP:FACING:VECTOR).
  LOCK atmPressure TO SHP_pressure().
  LOCK AoADynamicLimit TO CHOOSE 180 IF atmPressure < 0.001 ELSE
        // 1 at sea level
        MIN(AoALimit / atmPressure, 180).
  
  PRINT "Pressure: " + ROUND(atmPressure, 2) AT (70,8).
  PRINT "DynAoA limit: " + ROUND(AoADynamicLimit, 2) AT (70,9).
  
  // launch from ground
  IF ALT:RADAR < 500 {
    LOCK STEERING TO HEADING (HDG, 90).
    LOCK THROTTLE TO 1.
    WAIT 3.
    SET PID_pitch:MINOUTPUT TO 0.
    SET PID_pitch:MAXOUTPUT TO 1.
    SET PID_twr:MINOUTPUT TO 0.
    SET PID_twr:MAXOUTPUT TO 1.
    SET PID_twr:SETPOINT TO 0.
    SET PID_pitch:SETPOINT TO 0.
    PID_pitch:RESET().
    PID_twr:RESET().
    RETURN FALSE.
  }
  
  // compute throttle via twr so that SHIP:ORBIT:APOAPSIS - 5_000 - SHIP:ALTITUDE = 0
  // aka: keep apoapsis always 5km above current ship altitude.
  // may be better to have a fixed time to AP instead?
  LOCK throttlePidInput TO SHIP:ORBIT:APOAPSIS - 5_000 - SHIP:ALTITUDE.
  LOCK desiredTwr TO PID_twr:UPDATE(TIME:SECONDS, throttlePidInput).
  LOCK THROTTLE TO (desiredTwr * SHP_getMaxTWR()) / MIN(SHP_getMaxTWR(), 0.0001).
  
  // compute desired pitch angle, limited by dynamic limit
  IF AoA > AoADynamicLimit {
    // steer towards srfprograde to reduce pitch.
    LOCK STEERING TO SHIP:SRFPROGRADE.
    PID_pitch:RESET().
  }
  ELSE
  {
    // eccentricity at ground level = 1, circular = 0
    // comput desired pitch angle so that currentAP/desiredAlt - eccentricity = 0
    // aka: at ground it's 0 and as current apoapsis increases it goes to 1 to move eccentricity to 0
    LOCK desiredEccentricity TO MATH_gaussian(SHIP:ORBIT:APOAPSIS/desiredAltitude, 1, 0, 0.4).
    PRINT "Desired ECC: " + ROUND(desiredEccentricity,3) AT (70,11).
    LOCK pitchPidInput TO desiredEccentricity - SHIP:ORBIT:ECCENTRICITY.
    LOCK desiredPitch TO PID_pitch:UPDATE(TIME:SECONDS, pitchPidInput).
    LOCK STEERING TO HEADING(HDG, 90 - 90*desiredPitch).
  }
  RETURN FALSE.     // we're still doing stuff, send false.
}
// get gravitational constant at specific altitude
FUNCTION BDY_getGAtAltitude {
  PARAMETER bdy.
  PARAMETER altitude.
  
  LOCAL dist IS bdy:RADIUS - altitude.
  RETURN bdy:MU / dist^2.
}

// get orbital period (in seconds) for specific semi major axis (in m from center)
FUNCTION BDY_getOrbPeriod {
  PARAMETER bdy.
  PARAMETER SMA IS SHIP:ORBIT:SEMIMAJORAXIS.
  
  RETURN 2 * CONSTANT:PI * SQRT(SMA^3 / bdy:MU).
}

// get the altitude of a geostationary orbit for the body.
FUNCTION BDY_getGeoStationaryAlt {
  PARAMETER bdy.
  
  // 2 * pi * sqrt(sma^3 / mu) = bdy:rotationperiod, solve for sma
  RETURN (bdy:ROTATIONPERIOD^(2/3) * bdy:mu^(1/3)) / (2* CONSTANT:PI)^(2/3).
}

// get surface slope vector pointing away from the surface.
FUNCTION BDY_getSurfaceSlopeNormal {
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
FUNCTION BDY_getSurfaceSlopeAngle {
  PARAMETER geo.
  PARAMETER areaSize IS 10.0.
  
  // get an UP vector to compare angles to.
  LOCAL vRadialOut IS BDY_getRadialOutVector(geo).
  LOCAL vNorm IS BDY_getSurfaceSlopeNormal(geo, areaSize).
  return VANG(vRadialOut, vNorm).
}

// get direction of the slope (downwards) as a non normalized vector.
FUNCTION BDY_getSurfaceSlopeDirectionVector {
  PARAMETER geo.
  PARAMETER areaSize IS 10.0.
  
  // vector exclude, project vector 2 onto the plane that is orthogonal to vector 1
  // or in other words remove the v1 component from v2
  RETURN VXCL (BDY_getRadialOutVector(geo), BDY_getSurfaceSlopeNormal(geo, areaSize)).
}

// get a normalized vector pointing directly up from the surface
FUNCTION BDY_getRadialOutVector {
  PARAMETER geo.
  RETURN (geo:ALTITUDEPOSITION(0) - geo:ALTITUDEPOSITION(100_000)):NORMALIZED.
}

FUNCTION BDY_getTimeToImpact {
  // TODO
}