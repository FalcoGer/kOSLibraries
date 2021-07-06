// Mission file for craft to execute.

SET startTime TO 0.

FUNCTION getSequence {
  // sequence = ["name1", function1@, "name2", function2@, ...]
  PRINT "Loading mission...".
  RETURN LIST(
    "init", init@
  ).
}

FUNCTION init {
  PARAMETER mission.
  
  IF startTime = 0 {
    SET startTime TO TIME:SECONDS.
	NOTIFY("INIT", 0).
  }
}