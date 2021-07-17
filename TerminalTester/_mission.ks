// Mission file for craft to execute.

REQUIRE("lib/terminal.ks").

FUNCTION getSequence {
  // sequence = ["name1", function1@, "name2", function2@, ...]
  PRINT "Loading mission...".
  RETURN LIST(
    "init", init@,
    "lineDropoffTest", lineDropoffTest@,
    "clearTest", clearTest@,
    "lineExistsOverwriteTest", lineExistsOverwriteTest@,
    "lineNotExistsTest", lineNotExistsTest@,
    "textWrapTest", textWrapTest@,
    "linePrintClearingTest", linePrintClearingTest@,
    "regionRemoveTest", regionRemoveTest@,
    "endMission", endMission@
  ).
}

LOCAL firstRunOfStage IS TRUE.

FUNCTION init {
  PARAMETER mission.
  
  TERM_setup(80, 50).
  TERM_show().
  
  CLEARSCREEN.
  
  TERM_addRegion("Test 0", 0, 0, 78, 2).
  TERM_addRegion("Test 1", 0, 3, 38, 21).
  TERM_addRegion("Test 2", 39, 3, 39, 10).
  TERM_addRegion("Test 3", 39, 14, 39, 10).
  TERM_addRegion("Default", 0, 25, 78, 20).
  
  mission["addEvent"]("drawTerm", drawTerm@).
  
  TERM_print("Setup Test Complete").
  
  mission["nextStage"]().
}

FUNCTION lineDropoffTest {
  PARAMETER mission.
  IF firstRunOfStage
  {
    DELETEPATH("currentStage.txt").
    SET firstRunOfStage TO FALSE.
  
    TERM_print("Printing 3 lines to Test 0.").
    TERM_print("Line 1 should drop off the top.").
    TERM_print("Press RCS to continue.").
  }
  
  
  IF RCS {
    RCS OFF.
    SET firstRunOfStage TO TRUE.
    
    TERM_print("Test 0 line 1", "Test 0").
    TERM_print("Test 0 line 2", "Test 0").
    TERM_print("Test 0 line 3", "Test 0").
    
    TERM_print("Messages should have been dropped off the top.").
    mission["nextStage"]().
  }
}

FUNCTION clearTest {
  PARAMETER mission.
  
  IF firstRunOfStage
  {
    DELETEPATH("currentStage.txt").
    SET firstRunOfStage TO FALSE.
    
    TERM_print("Printing some text to Test 2.").
    TERM_print("Press RCS to clear Test 2").
    
    TERM_print("Printing some text", "Test 2").
    TERM_print("Press RCS to clear.", "Test 2").
  }
  
  IF RCS {
    RCS OFF.
    SET firstRunOfStage TO TRUE.
    
    TERM_clear("Test 2").
    TERM_print("Test 2 should be clear.").
    
    mission["nextStage"]().
  }
}

FUNCTION lineExistsOverwriteTest {
  PARAMETER mission.
  
  IF firstRunOfStage
  {
    DELETEPATH("currentStage.txt").
    SET firstRunOfStage TO FALSE.
    
    TERM_print("Printing some text to Test 1.").
    FOR i IN RANGE(0, 27, 1) {
      TERM_print("Hello #" + i, "Test 1").
    }
    
    TERM_print("Overwriting line 10 (0 indexed.).").
    TERM_print("Press RCS to continue.").
  }
  
  IF RCS {
    RCS OFF.
    SET firstRunOfStage TO TRUE.
    
    TERM_print("This should be in line 10", "Test 1", 10).
    TERM_print("Message should have appeared in line 10.").
    
    mission["nextStage"]().
  }
}

FUNCTION lineNotExistsTest {
  PARAMETER mission.
  
  IF firstRunOfStage
  {
    DELETEPATH("currentStage.txt").
    SET firstRunOfStage TO FALSE.
    
    TERM_print("Testing printing to line 5 (0 indexed) of Test 2, which is empty.").
    TERM_print("Press RCS to continue.").
  }
  
  IF RCS {
    RCS OFF.
    SET firstRunOfStage TO TRUE.
    TERM_print("This should be in line 5", "Test 2", 5).
    TERM_print("Message should have appeared in line 5.").
    mission["nextStage"]().
  }
}

FUNCTION textWrapTest {
  PARAMETER mission.
  
  IF firstRunOfStage
  {
    DELETEPATH("currentStage.txt").
    SET firstRunOfStage TO FALSE.
    
    TERM_print("Testing printing a text that doesn't fit width wise into Test 1 at line 5").
    TERM_clear("Test 1").
    TERM_print("Press RCS to continue.").
  }
  
  IF RCS {
    RCS OFF.
    SET firstRunOfStage TO TRUE.
    TERM_print("This is a really long text that should"
      + " probably not fit into the text box which is of a much smaller width"
      + " and thus should be broken into multiple lines, starting from line 5.", "Test 1", 5).
    TERM_print("This should be in the line after the long text.", "Test 1").
    TERM_print("Message should have wrapped.").
    TERM_print("Second message should be beneath the first.").
    
    mission["nextStage"]().
  }
}

FUNCTION linePrintClearingTest {
  PARAMETER mission.
  
  IF firstRunOfStage
  {
    DELETEPATH("currentStage.txt").
    SET firstRunOfStage TO FALSE.
    
    TERM_print("Testing if writing to line 5 and 6 clears all characters behind the message in Test 2.").
    TERM_print("Press RCS to continue.").
    
    TERM_print("This is a long text in line 5.", "Test 2", 5).
    TERM_print("This is a long text in line 6.", "Test 2", 6).
  }
  
  IF RCS {
    RCS OFF.
    SET firstRunOfStage TO TRUE.
    
    TERM_print("Clear 5", "Test 2", 5).
    TERM_print("Clear 6", "Test 2", 6).
    
    TERM_print("Test 2 lines 5 and 6 should contain Clear 5/6 with no other characters in those lines.").
    
    mission["nextStage"]().
  }
}

FUNCTION regionRemoveTest {
  PARAMETER mission.
  
  IF firstRunOfStage
  {
    DELETEPATH("currentStage.txt").
    SET firstRunOfStage TO FALSE.
    
    TERM_print("The next test will delete Test 3 region.").
    TERM_print("Press RCS to continue.").
    
    TERM_print("This Test Region will be deleted upon pressing RCS", "Test 3").
    TERM_print("All remaining text should remain where it is.", "Test 3").
  }
  
  IF RCS {
    RCS OFF.
    SET firstRunOfStage TO TRUE.
    
    TERM_removeRegion("Test 3").
    TERM_print("Test 3 deleted.").
    
    mission["nextStage"]().
  }
}

FUNCTION endMission {
  PARAMETER mission.
  
  IF firstRunOfStage {
    DELETEPATH("currentStage.txt").
    SET firstRunOfStage TO FALSE.
    
    TERM_print("We're done.").
    TERM_print("Press RCS to end the mission.").
  }

  IF RCS {
    RCS OFF.
    mission["nextStage"]().
  }
  RCS OFF.
}

FUNCTION drawTerm
{
  PARAMETER mission.
  
  TERM_draw().
  RETURN TRUE.
}