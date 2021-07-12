FUNCTION SHP_getMaxThrust {
  LOCAL thr IS 0.
  LOCAL pressure IS CHOOSE 0 IF BODY:ATM:EXISTS ELSE BODY:ATM:ALTITUDEPRESSURE(ALTITUDE).
  FOR engine IN SHP_activeEngines() {
    SET thr TO thr + engine:AVAILABLETHRUSTAT(pressure).
  }
  return thr.
}

FUNCTION SHP_getMaxTWR {
  LOCAL g IS BODY:mu / ((SHIP:ALTITUDE + BODY:RADIUS)^2).
  return SHP_getMaxThrust() / (g * SHIP:MASS).
}

FUNCTION SHP_getISP {
  LOCAL specificImpulse IS 0.
  LOCAL engineList IS SHP_activeEngines().
  IF engineList:LENGTH() = 0 { RETURN 0. }
  LOCAL pressure IS SHP_pressure().
  FOR engine IN engineList {
    SET specificImpulse TO specificImpulse + engine:ISPAT(pressure).
  }
  SET specificImpulse TO specificImpulse / engineList:LENGTH().
  return specificImpulse.
}

FUNCTION SHP_pressure
{
  RETURN CHOOSE
    0 IF NOT BODY:ATM:EXISTS OR BODY:ATM:HEIGHT < ALTITUDE
    ELSE BODY:ATM:ALTITUDEPRESSURE(ALTITUDE).
}

// returns number of active engines that have not flamed out
FUNCTION SHP_activeEngines {
  LOCAL activeEngines IS LIST().
  LOCAL engineList    IS LIST().
  
  LIST ENGINES        IN engineList.
  
  FOR engine IN engineList {
    IF engine:IGNITION AND NOT engine:FLAMEOUT {
      activeEngines:ADD(engine).
    }
  }
  
  return activeEngines.
}

// returns list of flamed out, active engines.
FUNCTION SHP_burnedOutEngines {
  LOCAL burnedOutEngines  IS LIST().
  LOCAL engineList        IS LIST().
  
  LIST ENGINES        IN engineList.
  
  FOR engine IN engineList {
    IF engine:IGNITION AND engine:FLAMEOUT {
      burnedOutEngines:ADD(engine).
    }
  }
  
  return burnedOutEngines.
}

// returns if any engine has flamed out (for staging)
// this may be a problem if air breathing engines are brought to space, they need to be deactivated
// then they will not count as flamed out.
// may also be a problem with multi mode engines
FUNCTION SHP_burnout {
  RETURN SHP_burnedOutEngines():LENGTH() > 0.
}

FUNCTION SHP_throttleStepping {
  PARAMETER current.
  PARAMETER setPoint.
  
  RETURN MAX(MIN(1 - (current / setPoint * 0.99), 1), 0).
}