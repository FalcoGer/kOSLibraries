// Mission file for craft to execute.

FUNCTION getSequence {
  // sequence = ["name1", function1@, "name2", function2@, ...]
  PRINT "Loading mission...".
  RETURN LIST(
    "init", init@
  ).
}

FUNCTION init {
  PARAMETER mission.
  
}