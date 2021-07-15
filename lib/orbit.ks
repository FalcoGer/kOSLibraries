//returns direction with vector=AN vector, up=normal
REQUIRE("lib/math.ks").

function ORB_getDir {
  PARAMETER refNRM IS V(0,1,0).
  
  LOCAL normvec TO VCRS(BODY:POSITION - ORBIT:POSITION, VELOCITY:ORBIT).
  LOCAL anvec TO VCRS(normvec, refNRM).
  RETURN LOOKDIRUP(anvec, normvec).
}

function ORB_getTimeToTA {
  PARAMETER ta.
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

FUNCTION ORB_hohmann {
  PARAMETER desiredAltitude.
  
  LOCAL hohmann IS ORB_hohmann(desiredAltitude).
  
  IF desiredAltitude < ALTITUDE
  {
    SET hohmann[0] TO -1 * hohmann[0].
    SET hohmann[1] TO -1 * hohmann[1].
  }
  
  LOCAL n1 IS NODE(SHIP:ORBIT:ETA:PERIAPSIS, 0, 0, hohmann[0]).
  ADD n1.
  WAIT 0.03. // wait for orbits to update
  LOCAL n2 IS NODE(n1:ORBIT:ETA:APOAPSIS, 0, 0, hohmann[1]).
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
  LOCAL n1 IS NODE(ETA:PERIAPSIS, 0, 0, biecliptic[0]).
  ADD n1.
  WAIT 0.03.
  LOCAL n2 IS NODE(n1:ORBIT:ETA:APOAPSIS, 0, 0, v2).
  ADD n2.
  WAIT 0.03.
  LOCAL n3 IS NODE(n2:ORBIT:ETA:PERIAPSIS, 0, 0, -1 * v3).
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
    RETURN ORB_BiEliptical(desiredAltitude, rbCap).
  }
  ELSE
  {
    // hohmann is more efficient.
    RETURN ORB_hohmann(desiredAltitude).
  }
}

FUNCTION ORB_cirularize {
  PARAMETER mnvTime.
  
  LOCAL dV IS LIST(mnvTime,0,0,0).
  LOCAL numSteps IS 10.
  // calculate to 0.125m/s precision, starting with 128m/s step sizes
  // don't alter time value (step size 0)
  // don't alter normal value. this will not be required (incl change) and will fuck up maneuvers.
  LOCAL dVStep IS LIST(0, 2^(numSteps-3), 0, 2^(numSteps-3)).

  SET dV TO MATH_hillClimb(dV, dVStep, ORB_fitnessBestEcc@, numSteps).
  LOCAL n IS NODE(dV[0], dV[1], dV[2], dV[3]).
  ADD n.
}

LOCAL FUNCTION ORB_fitnessBestEcc {
  PARAMETER nodeValue.
  // generate node from data.
  LOCAL n IS NODE(nodeValue[0], nodeValue[1], nodeValue[2], nodeValue[3]).
  ADD n.        // need to add node to flight plan in order to check out how good it is.
  WAIT 0.03.    // maybe wait for ksp to figure shit out with this node?
  // best orbit is 0 eccentricity.
  // need to round because eccentricity calculation isn't exact
  // if left as is, hill climbing will forever loop because it finds the same maneuver plan is giving ever so slightly different (aka better) value.
  LOCAL fitness IS -1 * ROUND(n:ORBIT:ECCENTRICITY, 6).
  REMOVE n.
  RETURN fitness.
}

// get a vector pointing up from the orbital plane of an orbitable (CCW = UP)
FUNCTION ORB_getNormal {
  PARAMETER orbitable IS SHIP.
  
  RETURN VCRS(VELOCITYAT(orbitable, TIME:SECONDS + orbitable:ORBIT:PERIOD / 4):ORBIT, VELOCITYAT(orbitable, TIME:SECONDS):ORBIT):NORMALIZED.
}

// creates a maneuver at the specified time to change the inclination
// needs to be executed at the correct time (AN or DN)
FUNCTION ORB_changeIncl {
  PARAMETER t.                  // at which time the inclination change is performed
                                // needs to be accurate
  PARAMETER deltaInc.           // how much inclination to add at that time
                                // will perform NORMAL UP burn
  
  // get orbital speed at the time as a vector
  // all orbital speed is prograde from the ship's point of view.
  LOCAL orbSpeed IS V(0,0,VELOCITYAT(SHIP, t):ORBIT:MAG).
  LOCAL normalVector IS ORB_getNormal().
  
  // we want our prograde vector to change by deltaInc towards normal
  // we also want our orbital speed to remain as it is
  // we get our orbital speed and rotate it towards normal by deltaInc
  LOCAL desiredOrbitalSpeed IS MATH_vecRotToVec(orbSpeed, normalVector, deltaInc).
  
  // get desired burn by subtracting the vectors
  LOCAL desiredManeuver IS desiredOrbitalSpeed - orbSpeed.
  
  // radial, normal, prograde
  RETURN LIST(desiredManeuver:x, desiredManeuver:y, desiredManeuver:z).
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
