LOCK gSrf TO BDY_getGAtAltitude(SHIP:BODY, 0).
LOCK gCur TO BDY_getGAtAltitude(SHIP:BODY, SHIP:ALTITUDE).

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
  PARAMETER SMA.
  
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
  RETURN vUp IS (geo:ALTITUDEPOSITION(0) - geo:ALTITUDEPOSITION(100_000)):NORMALIZED.
}

FUNCTION BDY_getTimeToImpact {
  // TODO
}