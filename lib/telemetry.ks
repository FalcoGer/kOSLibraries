// generate a file for telemetry viewing with HighCharts

FUNCTION TELEM_write {
  PARAMETER telemetryName.
  PARAMETER directory.  // where to put the file
  PARAMETER dataRow.    // lexicon with "name", value pairs
  
  LOCAL writeHeader IS FALSE.
  LOCAL pathToTelemJS IS directory + "/" + telemetryName + ".js".
  
  IF NOT EXISTS(directory) {
    CREATEDIR(directory).
  }
  
  IF NOT EXISTS(pathToTelemJS) {
    LOCAL pathToTelemHTML IS directory + "/" + telemetryName + ".html".
    
    LOCAL header IS "".
    FOR key in dataRow:KEYS {
      SET header TO header + ",'" + key + "'".
    }
    LOG "var data = [['Time'" + header + "]," TO pathToTelemJS.
    
    WHEN CHECK_CONNECTION() THEN {
      LOCAL highchartsContent IS OPEN("0:/highcharts.html"):READALL:STRING.
      SET highchartsContent TO highchartsContent:REPLACE("INSERT_FILEPATH_HERE", telemetryName + ".js")
                                                :REPLACE("INSERT_TELEMETRYNAME_HERE", telemetryName).
      IF EXISTS(pathToTelemHTML) {
        DELETEPATH(pathToTelemHTML).
      }
      LOCAL htmlFile IS CREATE(pathToTelemHTML).
      htmlFile:WRITE(highchartsContent).
    }
  }
  
  // write telemetry
  LOCAL line IS "[" + ROUND(getMissionTime(), 5).
  FOR value IN dataRow:VALUES {
    SET line TO line + "," + value.
  }
  SET line TO line + "],".
  
  LOG line TO pathToTelemJS.
}

FUNCTION TELEM_finish {
  PARAMETER telemetryName.
  PARAMETER directory.
  
  IF directory:SUBSTRING(0,2) = "0:"
  {
    WHEN CHECK_CONNECTION() THEN {
      LOCAL pathToTelemJS IS directory + "/" + telemetryName + ".js".
      LOG "];" TO pathToTelemJS.
    }
  }
  ELSE
  {
    LOCAL pathToTelemJS IS directory + "/" + telemetryName + ".js".
    LOG "];" TO pathToTelemJS.
  }
}


// P - Proportional, How much error is there currently (Distance)
// I - Integral, How much error has there been (Accumulative)
// D - Derivitive, How fast are we approaching the optimum (Change)

// kp factor: adjust command output by 1 unit for this much error
// ki factor: adjust command output by 1 unit for this many seconds spent at 1 unit error
// kd factor: adjust command output by 1 unit for every 1 / this much rate of change

// PID controllers are best to control linear relationships between effector and input error.
// So don't control the thrust lever (thrust changes as fuel is burned, gravity is changed, etc), instead control desired TWR
// g = BODY:MU / ((SHIP:ALTITUDE / BODY:RADIUS)^2).
// MaxTWR = SHIP:MAXTHRUST / (g * SHIP:MASS)
// DesiredThrottle = MIN(1, MaxTWR / DesiredTWR)

// The integral term can deal with error factors as they appear or disappear
// however it is best to use fixed logic and math if possible to mitigate error sources
// for example if you want to control ascend rate with PID to a desired set point (vertical speed)
// then (for a rocket) you need to consider the down vector of the engine thrust only.
// so you get the angle off the vertical vector
// shipTilt = VANG(UP:VECTOR, SHIP:FACING:FOREVECTOR) and adjust your PID value by it
// desiredTWR = pid:UPDATE(TIME:SECONDS, SHIP:VERTICALSPEED) / cos(shipTilt).
// this way the desired TWR is automatically updated for the ship tilt without the PID straining and messing up the stored integral error
// this will make the PID more stable.

// SET PID TO PIDLOOP(kp, ki, kd, minimum, maximum, epsilon).
// SET PID:SETPOINT TO TARGET.
// SET command TO 0.
// LOCK <EFFECTOR> TO command
// UNTIL COND {
//   SET command TO PID:UPDATE(TIME:SECONDS, INPUT).
//   wait 0.
// }

FUNCTION TELEM_PID {
  PARAMETER PID.
  PARAMETER name.
  PARAMETER path.
  
  LOCAL data IS LEXICON(
    "deltaTime", (TIME:SECONDS - PID:LASTSAMPLETIME),
    "setPoint" PID:SETPOINT,
    "Input", PID:INPUT,
    "Error", PID:ERROR,
    "ErrorSum", PID:ERRORSUM,
    "ChangeRate", PID:CHANGERATE,
    "P-Term", PID:PTERM,
    "I-Term", PID:ITERM,
    "D-Term", PID:DTERM,
    "Output", PID:OUTPUT
  ).
  
  TELEM_write(name, path, data).
}
