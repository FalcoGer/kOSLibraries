REQUIRE("lib/ship.ks").
REQUIRE("lib/math.ks").

// control pitch for eccentricity over altitude
FUNCTION BDY_ascendGuidance {
  PARAMETER desiredAltitude.        // should not be too high
  PARAMETER HDG IS 90.              // heading in compass degrees
  PARAMETER desiredTWR IS 1.8.      // TWR to use during ascend
  PARAMETER AoALimit IS 5.          // degrees of AoA deviation, is increased as atmos pressure decreases
  
  // calculate some stuff for AoA limiting
  LOCAL AoA IS VANG(SHIP:SRFPROGRADE:VECTOR, SHIP:FACING:VECTOR).
  LOCAL atmPressure IS SHP_pressure().
  LOCAL AoADynamicLimit IS CHOOSE 180 IF atmPressure < 0.001
        // 1 at sea level
        ELSE MIN(AoALimit / atmPressure, 180).
  
  LOCAL altRatio IS ALTITUDE/desiredAltitude.
  LOCAL desiredPitch IS 90 - ((MIN(altRatio, 1)^0.25) * 90).
  
  // throttle related
  LOCAL maxTWR IS SHP_getMaxTWR().
  
  
  LOCAL telemetry IS LEXICON("done", false, "branch", "init", "AoA", AoA, "atmPressure", atmPressure, "AoADynamicLimit", AoADynamicLimit, "maxTWR", maxTWR, "altRatio", altRatio, "ecc", SHIP:ORBIT:ECCENTRICITY, "desiredPitch", desiredPitch, "throttle", 0).
  
  IF desiredAltitude < SHIP:ORBIT:APOAPSIS {
    UNLOCK THROTTLE.
    IF BODY:ATM:EXISTS AND ALTITUDE < BODY:ATM:HEIGHT
    {
      // coasting to end of atmoshpere with minimum drag
      SET telemetry["branch"] TO "Coasting to end of atmosphere".
      LOCK STEERING TO SHIP:SRFPROGRADE.
      RETURN telemetry.   // we're not done until we're in space!
    }
    ELSE
    {
      // out of atmosphere and altitude reached, we're done.
      UNLOCK STEERING.
      SET telemetry["branch"] TO "Done".
      SET telemetry["done"] TO TRUE.
      RETURN telemetry.    // we're done, send true.
    }
  }
  
  // launch from ground
  IF ALT:RADAR < 500 {
    SET telemetry["branch"] TO "Launch from surface".
    LOCK STEERING TO HEADING(HDG, 90). // straight up
    SET telemetry["throttle"] TO 1.
    LOCK THROTTLE TO 1.
    RETURN telemetry.       // certainly not done here, send false.  
  } ELSE {
    SET telemetry["branch"] TO "Burning".
  }
  
  // maintain constant TWR burn.
  IF NOT (maxTWR < 0.001)
  {
    // throttle down as approaching desired altitude.
    LOCAL throt IS CHOOSE 1 IF maxTWR <= desiredTWR ELSE MIN((desiredTwr / maxTWR), MAX(1 - altRatio, 0)).
    LOCK THROTTLE TO throt.
    SET telemetry["throttle"] TO THROTTLE.
  }
  ELSE
  {
    LOCK THROTTLE TO 0.
  }
  
  LOCAL steeringVector IS HEADING(HDG, desiredPitch).
  LOCAL steer IS CHOOSE steeringVector
                    IF AoA < AoADynamicLimit
                    // when AoA over limit then rotate srfprograde towards steering vector
                    ELSE MATH_vecRotToVec(steeringVector:VECTOR, SHIP:SRFPROGRADE:VECTOR, AoADynamicLimit).
  LOCK STEERING TO steer.
  RETURN telemetry. // we're still doing stuff, send false.
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
  PARAMETER bdy IS SHIP:BODY.
  
  // 2 * pi * sqrt(sma^3 / mu) = bdy:rotationperiod, solve for sma
  RETURN ((bdy:ROTATIONPERIOD^(2/3) * bdy:mu^(1/3)) / (2* CONSTANT:PI)^(2/3)) - bdy:RADIUS.
}

// get a normalized vector pointing directly up from the surface
FUNCTION BDY_getRadialOutVector {
  RETURN -1 * SHIP:BODY:POSITION:NORMALIZED.
}

FUNCTION BDY_getNorthVector {
  PARAMETER bdy IS SHIP:BODY.
  
  RETURN bdy:GEOPOSITIONLATLNG(-90, 0):POSITION - SHIP:BODY:POSITION.
}