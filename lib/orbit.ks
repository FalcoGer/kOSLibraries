//returns direction with vector=AN vector, up=normal
function ORB_getDir {
  PARAMETER refNRM IS V(0,1,0).
  
  LOCAL normvec TO VCRS(BODY:POSITION - ORBIT:POSITION, VELOCITY:ORBIT).
  LOCAL anvec TO VCRS(normvec, refNRM).
  RETURN LOOKDIRUP(anvec, normvec).
}

function ORB_getTimeToTA {
  PARAMETER ta
  PARAMETER orbit_in IS ship:orbit.
  
  LOCAL tanow TO orbit_in:TRUEANOMALY.
  LOCAL ecc   TO orbit_in:ECCENTRICITY.
  LOCAL ef    TO SQRT( (1-ecc) / (1+ecc) ).
  LOCAL eanow TO 2*ARCTAN( ef * TAN(tanow / 2) ).
  LOCAL eanew TO 2*ARCTAN( ef * TAN(ta / 2) ).
  
  local dt to SQRT( orbit_in:SEMIMAJORAXIS^3 / orbit_in:BODY:MU ) * ((eanew - eanow)*CONSTANT:DEGTORAD - ecc * (SIN(eanew) - SIN(eanow))).
  until dt > 0 { set dt to dt + orbit_in:period. }
  return dt.
}

// refNRM is the normal vector of the "equator" that we measure against
function ORB_getTimeToAN {
  parameter refNRM to V(0,1,0).
  
  local AN_NRM to ORB_getDir(refNRM).
  local ANvec to AN_NRM:vector.
  local taAN to ARCTAN2( VDOT(AN_NRM:upvector, VCRS(body:position, ANvec)), -VDOT(body:position, ANvec) ) + orbit:TRUEANOMALY.
  return ORB_getTimeToTA(taAN).
}

// refNRM is the normal vector of the "equator" that we measure against
function ORB_getTimeToDN {
  parameter refNRM to V(0,1,0).
  
  local DN_NRM to ORB_getDir(refNRM).
  local DNvec to -DN_NRM:vector.
  local taDN to ARCTAN2( VDOT(DN_NRM:upvector, VCRS(body:position, DNvec)), -VDOT(body:position, DNvec) ) + orbit:TRUEANOMALY.
  return ORB_getTimeToTA(taDN).
}