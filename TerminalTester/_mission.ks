// Mission file for craft to execute.

REQUIRE("lib/terminal.ks").

FUNCTION getSequence {
  // sequence = ["name1", function1@, "name2", function2@, ...]
  PRINT "Loading mission...".
  RETURN LIST(
    "init", init@,
    "printingTest", printingTest@
  ).
}

FUNCTION init {
  PARAMETER mission.
  
  TERM_addRegion("Test 0", 0, 0, 98, 2).
  TERM_addRegion("Test 1", 0, 3, 48, 27).
  TERM_addRegion("Test 2", 49, 3, 49, 13).
  TERM_addRegion("Test 3", 49, 17, 49, 13).
  TERM_addRegion("Default", 0, 31, 98, 26).
  
  TERM_print("Setup Test Complete").
  
  mission["nextStage"]().
}

FUNCTION printingTest {
  PARAMETER mission.
  
  DELETEPATH("currentStage.txt").
  
  TERM_print("Printing 3 lines to Test 0.").
  TERM_print("Line 1 should drop off the top.").
  TERM_print("Press RCS to continue.").
  
  UNTIL RCS { WAIT 1. }
  RCS OFF.
  TERM_print("Test 0 line 1", "Test 0").
  TERM_print("Test 0 line 2", "Test 0").
  TERM_print("Test 0 line 3", "Test 0").
  
  TERM_print("Messages should have been dropped off the top.").
  TERM_PRINT("Printing some text to Test 2.").
    
  TERM_print("Printing some text", "Test 2").
  TERM_print("Press RCS to clear.", "Test 2").
  
  TERM_print("Test clearing of Test 2.").
  TERM_print("Press RCS to continue.").
  
  UNTIL RCS { WAIT 1. }
  RCS OFF.
  
  TERM_clear("Test 2").
  TERM_print("Test 2 should be clear.").
  
  TERM_print("Printing some text to Test 1.").
  TERM_print("Press RCS to continue.").
  
  UNTIL RCS { WAIT 1. }
  RCS OFF.
  FOR i IN RANGE(0, 27, 1) {
    TERM_print("Hello" + i, "Test 1").
  }
  
  TERM_print("Overwriting line 10 (0 indexed.).").
  TERM_print("Press RCS to continue.").
  
  UNTIL RCS { WAIT 1. }
  RCS OFF.
  
  TERM_print("This should be in line 10", "Test 1", 10).
  
  TERM_print("Message should have appeared in line 10.").
  TERM_print("Testing printing to line 5 (0 indexed) of Test 2, which is empty.").
  TERM_print("Press RCS to continue.").
  
  UNTIL RCS { WAIT 1. }
  RCS OFF.
  
  TERM_print("This should be in line 5", "Test 2", 5).
  
  TERM_print("Message should have appeared in line 5.").
  TERM_print("Testing printing a text that doesn't fit width wise into Test 1 at line 5").
  TERM_print("Press RCS to continue.").
  
  UNTIL RCS { WAIT 1. }
  RCS OFF.
  
  TERM_print("This is a really long text that should"
  + " probably not fit into the terminal with 48 characters width"
  + " and thus should be broken into multiple lines, starting from line 5.", "Test 1", 5).
  
  TERM_print("Message should have wrapped.").
  TERM_print("Testing if writing to line 5 and 6 clears all characters behind the message in Test 2.").
  
  TERM_print("This is a long text in line 5.", "Test 2", 5).
  TERM_print("This is a long text in line 6.", "Test 2", 6).
  
  TERM_print("Press RCS to continue.").
  
  UNTIL RCS { WAIT 1. }
  RCS OFF.
  
  TERM_print("A = 5", "Test 2", 5).
  TERM_print("B = 6", "Test 2", 6).
  
  TERM_print("Test 2 lines 5 and 6 should contain A = 5 and B = 6 with no other characters. in those lines.").
  TERM_print("The next test will delete Test 3 region.").
  TERM_print("Press RCS to continue.").
  
  TERM_PRINT("This Test Region will be deleted upon pressing RCS", "Test 3").
  TERM_PRINT("All remaining text should remain where it is.", "Test 3").
  
  UNTIL RCS { WAIT 1. }
  RCS OFF.
  
  TERM_removeRegion("Test 3").
  TERM_print("Test 3 deleted.").
  TERM_print("Default will be cleared.").
  TERM_print("Press RCS to continue.").
  
  UNTIL RCS { WAIT 1. }
  RCS OFF.
  
  TERM_clear().
  TERM_print("This should appear in the first line.").
  TERM_print("Will print a long text to line 10.").
  TERM_print("Press RCS to continue.").
  
  UNTIL RCS { WAIT 1. }
  RCS OFF.
  TERM_print("This is a really long text that should"
  + " probably not fit into the terminal with 100 characters width"
  + " and thus should be broken into multiple lines, starting from line 10.", "Default", 10).
  TERM_print("This line should appear after the long text.").
  TERM_print("").
  TERM_print("We're done.").
  TERM_print("Press RCS to end the mission.").
  
  UNTIL RCS { WAIT 1. }
  RCS OFF.
  mission["nextStage"]().
}