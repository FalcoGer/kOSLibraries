// simple test
// connect probe core to clamps
// connect SRB to probe
// clamp stage above SRB stage
// connect computer and set boot.ks as boot script.

SET startTime TO 0.
SET printCtr TO 0.

FUNCTION getSequence {
  // sequence = ["name1", function1@, "name2", function2@, ...]
  PRINT "Loading mission...".
  RETURN LIST(
    "init", init@,
	"stage_booster", stage_booster@,
	"print_hello", print_hello@
  ).
}

FUNCTION init {
  PARAMETER mission.
  IF startTime = 0 {
    SET startTime TO TIME:SECONDS.
	NOTIFY("INIT", 0).
  }
  
  PRINT ROUND(TIME:SECONDS - startTime,2) AT (70, 0).
  
  // wait until 30 seconds have passed
  IF startTime + 30 <= TIME:SECONDS {
    STAGE.
    mission["nextStage"]().
  }
}

FUNCTION stage_booster {
  PARAMETER mission.
  
  LOCAL dV IS SHIP:STAGEDELTAV(SHIP:STAGENUM):CURRENT.
  
  IF (dV < 0.001) {
    mission["setStage"]("print_hello").
  }
}

FUNCTION print_hello {
  PARAMETER mission.
  PRINT "Hello, nr " + printCtr.
  SET printCtr TO printCtr + 1.
  IF printCtr >= 10 {
    mission["terminate"]().
  }
}