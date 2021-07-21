//returns direction with vector=AN vector, up=normal
REQUIRE("lib/math.ks").

function ORB_getDir {
  PARAMETER refNRM IS V(0,1,0).
  
  LOCAL normvec IS VCRS(BODY:POSITION - ORBIT:POSITION, VELOCITY:ORBIT).
  LOCAL anvec IS VCRS(normvec, refNRM).
  RETURN LOOKDIRUP(anvec, normvec).
}

function ORB_getTimeToTA {
  PARAMETER ta.
  PARAMETER orbit_in IS ship:orbit.
  
  LOCAL tanow IS orbit_in:TRUEANOMALY.
  LOCAL ecc   IS orbit_in:ECCENTRICITY.
  LOCAL ef    IS SQRT( (1-ecc) / (1+ecc) ).
  LOCAL eanow IS 2*ARCTAN( ef * TAN(tanow / 2) ).
  LOCAL eanew IS 2*ARCTAN( ef * TAN(ta / 2) ).
  
  LOCAL dt IS SQRT( orbit_in:SEMIMAJORAXIS^3 / orbit_in:BODY:MU ) * ((eanew - eanow)*CONSTANT:DEGTORAD - ecc * (SIN(eanew) - SIN(eanow))).
  UNTIL dt > 0 { SET dt TO dt + orbit_in:period. }
  RETURN dt.
}

FUNCTION ORB_hohmann {
  PARAMETER desiredAltitude.
  
  LOCAL hohmann IS ORB_hohmannDv(desiredAltitude).
  
  LOCAL goingUp IS desiredAltitude > SHIP:APOAPSIS.
  LOCAL n1Eta IS CHOOSE SHIP:ORBIT:ETA:PERIAPSIS IF goingUp ELSE SHIP:ORBIT:ETA:APOAPSIS.
  
  LOCAL n1 IS NODE(n1Eta + TIME:SECONDS, 0, 0, hohmann[0]).
  ADD n1.
  WAIT 0.03. // wait for orbits to update
  
  LOCAL n2Eta IS CHOOSE n1:ORBIT:ETA:APOAPSIS IF goingUp ELSE n1:ORBIT:ETA:PERIAPSIS.
  LOCAL n2 IS NODE(n2Eta + TIME:SECONDS, 0, 0, hohmann[1]).
  ADD n2.
  WAIT 0.03.
}

FUNCTION ORB_BiEliptical {
  PARAMETER desiredAltitude.
  PARAMETER rbCap.            // altitude of the transfer elipsis
  
  LOCAL r1 IS SHIP:ALTITUDE + BODY:RADIUS.
  LOCAL r2 IS desiredAltitude + BODY:RADIUS.
  
  // get deltaV for transfer
  LOCAL biecliptic IS ORB_BiElipticalTransferDv(desiredAltitude, rbCap).
  
  // set deltaV for second burn to negative if target orbit is reversed.
  LOCAL v2 IS biecliptic[1].
  IF r2 < r1 { SET v2 TO -1 * v2. }
  
  // create nodes and add them.
  LOCAL n1 IS NODE(ETA:PERIAPSIS + TIME:SECONDS, 0, 0, biecliptic[0]).
  ADD n1.
  WAIT 0.03.
  LOCAL n2 IS NODE(n1:ORBIT:ETA:APOAPSIS + TIME:SECONDS, 0, 0, v2).
  ADD n2.
  WAIT 0.03.
  LOCAL n3 IS NODE(n2:ORBIT:ETA:PERIAPSIS + TIME:SECONDS, 0, 0, -1 * v3).
  ADD n3.
  WAIT 0.03.
}

FUNCTION ORB_hohmannDv {
  PARAMETER desiredAltitude.
  SET r1 TO SHIP:ORBIT:SEMIMAJORAXIS.
  SET r2 TO desiredAltitude + BODY:RADIUS.
  
  SET v1 TO SQRT(BODY:MU / r1) * (SQRT((2 * r2) / (r1 + r2)) - 1).
  SET v2 TO SQRT(BODY:MU / r2) * (1 - SQRT((2 * r1) / (r1 + r2))).
  
  RETURN LIST(v1, v2).
}

// https://en.wikipedia.org/wiki/Bi-elliptic_transfer
FUNCTION ORB_BiElipticalTransferDv {
  PARAMETER desiredAltitude.
  PARAMETER rb.               // common apoapsis radius of the two transfer elipses
                              // aka how high to go on the initial burn
                              // if rb = r2 then v3 = 0m/s and maneuver is homann.
  
  LOCAL r1 IS SHIP:ORBIT:SEMIMAJORAXIS.
  LOCAL r2 IS desiredAltitude + BODY:RADIUS.
  
  LOCAL u IS BODY:MU.
  LOCAL a1 IS (r1 + rb) / 2.  // SMA of first transfer elipsis
  LOCAL a2 IS (r2 + rb) / 2.  // SMA of second transfer elipsis
  
  // first prograde burn
  LOCAL v1 IS SQRT((2 * u / r1) - u / a1) - SQRT(u / r1).
  // second burn brings PE of new orbit to desired altitude, may be positive or negative
  LOCAL v2 IS SQRT((2 * u / rb) - u / a2) - SQRT((2 * u / rb) - u / a1).
  // third burn is retrograde and circularizes.
  LOCAL v3 IS SQRT((2 * u / r2) - u / a2) - SQRT(u / r2).
  
  RETURN LIST(v1, v2, v3).
}

FUNCTION ORB_transferOrbit {
  PARAMETER desiredAltitude.
  PARAMETER rbCap IS BODY:SOIRADIUS * 0.90.
  
  LOCAL r1 IS ALTITUDE + BODY:RADIUS.
  LOCAL r2 IS desiredAltitude + BODY:RADIUS.
  
  // Ratio of radii   |   Minimal     | Comments
  // r2 / r1          |   α ≡ rb / r1 |
  // -----------------+---------------+------------------------------------
  // <11.94           |   N/A         | Hohmann transfer is always better
  // 11.94            |   ∞           | Bi-parabolic transfer
  // 12               |   815.81      |
  // 13               |   48.90       |
  // 14               |   26.10       |
  // 15               |   18.19       |
  // 15.58            |   15.58       |
  // > 15.58          |   > r2 / r1   | Any bi-elliptic transfer is better
  
  LOCAL ratio IS r2 / r1.
  LOCAL minimal IS rbCap / r1.
  
  IF ratio > 15.58 AND minimal > ratio
     OR ratio > 15 AND minimal > 18.19
     OR ratio > 14 AND minimal > 26.10
     OR ratio > 13 AND minimal > 48.90
     OR ratio > 12 AND minimal > 815.81
  {
    // bi-eliptical is more efficient
    ORB_BiEliptical(desiredAltitude, rbCap).
  }
  ELSE
  {
    // hohmann is more efficient.
    ORB_hohmann(desiredAltitude).
  }
}

FUNCTION ORB_cirularize {
  PARAMETER mnvTime.
  
  // orbital period:  t = 2*PI*SQRT(a^3 / MU)
  // orbit length:    s = 2*PI*r
  // velocity:        v = s/t = r / SQRT(r^3 / MU)
  
  LOCAL bdy IS ORBITAT(SHIP, mnvTime):BODY.
  LOCAL radiusAtMnv IS (POSITIONAT(SHIP, mnvTime) - bdy:POSITION):MAG.
  
  LOCAL requiredSpeed IS radiusAtMnv / SQRT(radiusAtMnv^3 / bdy:MU).
  
  // velocity needs to be parallel to the ground.
  // ship position to body vector X orbit normal will give a vector parallel to the body surface, which is the target direction.
  
  // OUT X NORM = PARALLEL to ground (left handed system)
  LOCAL desiredVelocityVector IS VCRS(POSITIONAT(SHIP, mnvTime) - bdy:POSITION, ORB_getNormal(SHIP)):NORMALIZED * requiredSpeed.
  
  LOCAL actualVelocityVector IS VELOCITYAT(SHIP, mnvTime):ORBIT.
  
  LOCAL dV IS desiredVelocityVector - actualVelocityVector.
  
  LOCAL n IS MATH_nodeFromVector(mnvTime, dV).
  ADD n.
}

// get a vector pointing up from the orbital plane of an orbitable (CCW = UP)
FUNCTION ORB_getNormal {
  PARAMETER orbitable IS SHIP.
  
  // RETURN VCRS(VELOCITYAT(orbitable, TIME:SECONDS + orbitable:ORBIT:PERIOD / 4):ORBIT, VELOCITYAT(orbitable, TIME:SECONDS):ORBIT):NORMALIZED.
  LOCAL now IS TIME:SECONDS.
  LOCAL progradeVector IS VELOCITYAT(orbitable,now):ORBIT:NORMALIZED.
  RETURN VCRS(progradeVector,(POSITIONAT(orbitable,now) - orbitable:BODY:POSITION):NORMALIZED):NORMALIZED.
}

// creates a maneuver at the specified time to change the inclination
// needs to be executed at the correct time (AN or DN)
FUNCTION ORB_changeIncl {
  PARAMETER t.                  // at which time the inclination change is performed
                                // needs to be accurate
  PARAMETER deltaInc.           // how much inclination to add at that time
                                // will perform NORMAL UP burn
  
  // get orbital speed at the time as a vector
  LOCAL orbSpeed IS VELOCITYAT(SHIP, t):ORBIT.
  LOCAL normalVector IS ORB_getNormal().
  
  // we want our prograde vector to change by deltaInc towards normal
  // we also want our orbital speed to remain as it is
  // we get our orbital speed and rotate it towards normal by deltaInc
  LOCAL desiredOrbitalSpeed IS MATH_vecRotToVec(orbSpeed, normalVector, deltaInc).
  
  // get desired burn by subtracting the vectors
  LOCAL desiredManeuver IS desiredOrbitalSpeed - orbSpeed.
  
  // radial, normal, prograde
  LOCAL n IS MATH_nodeFromVector(t, desiredManeuver).
  ADD n.
}

FUNCTION ORB_changeInclEfficient {
  PARAMETER newIncl IS 0.0.
  PARAMETER tgt IS SHIP:BODY.
  PARAMETER strategy IS ORB_INCL_STRAT_CIRC_AT_PA.
  
  // maneuver at DN/AN, whichever is lower
  // burn so that AP = DN/AN, whichever we didn't pick (make sure no SOI change)
  // maneuver at AP/(DN/AN) to change inclination
  
  // strategy: hill climb 1 or 2 maneuvers for best dV
  // needs only to adjust prograde/retrograde for 
  
  // TODO
}

// how many degrees the orbit advances per seconds
// only for circular orbits
FUNCTION ORB_angularVelocityCircular
{
  PARAMETER orbitable.
  LOCAL bdy IS orbitable:BODY.
  
  RETURN SQRT(bdy:MU / orbitable:ORBIT:SEMIMAJORAXIS^3) * CONSTANT:RadToDeg.
}
