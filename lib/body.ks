LOCK gSrf TO BDY_getGAtAltitude(SHIP:BODY, 0).
LOCK gCur TO BDY_getGAtAltitude(SHIP:BODY, SHIP:ALTITUDE).

REQUIRE("lib/ship.ks").
REQUIRE("lib/math.ks").

// control pitch for eccentricity over altitude
FUNCTION BDY_ascendGuidance {
  PARAMETER desiredAltitude.        // should not be too high
  PARAMETER HDG IS 90.              // heading in compass degrees
  PARAMETER desiredTWR IS 1.8.      // TWR to use during ascend
  PARAMETER AoALimit IS 5.          // degrees of AoA deviation, is increased as atmos pressure decreases
  
  IF desiredAltitude < SHIP:ORBIT:APOAPSIS {
    UNLOCK THROTTLE.
    IF BODY:ATM:EXISTS AND ALTITUDE < BODY:ATM:HEIGHT
    {
      // coasting to end of atmoshpere with minimum drag
      LOCK STEERING TO SHIP:SRFPROGRADE.
      RETURN FALSE.   // we're not done until we're in space!
    }
    ELSE
    {
      // out of atmosphere and altitude reached, we're done.
      UNLOCK STEERING.
      RETURN TRUE.    // we're done, send true.
    }
  }
  
  // calculate some stuff for AoA limiting
  LOCK AoA TO VANG(SHIP:SRFPROGRADE:VECTOR, SHIP:FACING:VECTOR).
  LOCAL atmPressure IS SHP_pressure().
  LOCK AoADynamicLimit TO CHOOSE 180 IF atmPressure < 0.001
        // 1 at sea level
        ELSE MIN(AoALimit / atmPressure, 180).
  
  PRINT "Pressure: " + ROUND(atmPressure, 2) + "    " AT (70,8).
  PRINT "DynAoA limit: " + ROUND(AoADynamicLimit, 2) + "   " AT (70,9).
  
  // launch from ground
  IF ALT:RADAR < 500 {
    LOCK STEERING TO HEADING(HDG, 90). // straight up
    LOCK THROTTLE TO 1.
    RETURN FALSE.       // certainly not done here, send false.  
  }
  
  // maintain constant TWR burn.
  LOCAL maxTWR IS SHP_getMaxTWR().
  LOCK altRatio TO ALTITUDE/desiredAltitude.
  IF NOT (maxTWR < 0.001)
  {
    // throttle down as approaching desired altitude.
    LOCK THROTTLE TO MIN((desiredTwr / maxTWR), MAX(1 - altRatio, 0)).
  }
  ELSE
  {
    LOCK THROTTLE TO 0.
  }
  
  // compute desired pitch angle via ratio altitude/desiredAltitude
  PRINT "ECC: " + ROUND(SHIP:ORBIT:ECCENTRICITY,3) AT (70,10).
  
  
  LOCK desiredPitch TO 90 - ((altRatio^0.3) * 90).
  PRINT "Desired Pitch: " + ROUND(desiredPitch,2) AT (70,11).
  LOCK steeringVector TO HEADING(HDG, desiredPitch).
  LOCK STEERING TO CHOOSE steeringVector
                    IF AoA < AoADynamicLimit
                    // when AoA over limit then rotate srfprograde towards steering vector
                    ELSE MATH_vecRotToVec(steeringVector:VECTOR, SHIP:SRFPROGRADE:VECTOR, AoADynamicLimit).
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