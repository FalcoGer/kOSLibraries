// Simple PID controller

@LAZYGLOBAL off.

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

FUNCTION pid_log {
  DECLARE PARAMETER PID
  DECLARE PARAMETER path.
  DECLARE PARAMETER header.
  
  IF header {
    LOG "# PID LOG" TO path.
	LOG "# kp: " + PID:KP TO path.
	LOG "# ki: " + PID:KI TO path.
	LOG "# kd: " + PID:KD TO path.
	LOG "# min: " + PID:MINOUTPUT TO path.
	LOG "# max: " + PID:MAXOUTPUT TO path.
	LOG "# epsilon: " + PID:EPSILON TO path.
	LOG "#T, DeltaT, SP, INPUT, ERROR, ERRORSUM, CHANGERATE, P, I, D, OUT".
  }
  
  SET line TO LIST(
    TIME:SECONDS,
	TIME:SECONDS-PID:LASTSAMPLETIME,
	PID:SETPOINT,
	PID:INPUT,
	PID:ERROR,
	PID:ERRORSUM,
	PID:CHANGERATE,
	PID:PTERM,
	PID:ITERM,
	PID:DTERM,
	PID:OUTPUT
  ).
  
  LOG line:JOIN(",") TO path.
}
