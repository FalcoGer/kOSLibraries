GLOBAL lineDelim IS "==================================================".

// Display a message
FUNCTION NOTIFY {
  PARAMETER message.
  PARAMETER priority IS 1.
  PARAMETER terminalPrint IS FALSE.
  
  LOCAL colour IS
    CHOOSE BLUE           IF priority <= 0.5 ELSE
    CHOOSE GREEN          IF priority <= 1.5 ELSE
    CHOOSE YELLOW         IF priority <= 2.5 ELSE
    CHOOSE RGB(255,128,0) IF priority <= 3.5 ELSE
           RED.
  
  LOCAL priorityStr IS
    CHOOSE "DEBUG: " IF priority <= 0.5 ELSE
    CHOOSE "INFO:  " IF priority <= 1.5 ELSE
    CHOOSE "WARN:  " IF priority <= 2.5 ELSE
    CHOOSE "ERR:   " IF priority <= 3.5 ELSE
           "CRIT:  ".
  
  // https://ksp-kos.github.io/KOS/commands/terminalgui.html
  HUDTEXT("kOS: " + message, 5, 2, 50, colour, false).
  IF terminalPrint
  {
    PRINT priorityStr + message.
  }
}

FUNCTION CHECK_CONNECTION {
  PARAMETER tgt IS FALSE.
  
  LOCAL conn IS HOMECONNECTION.
  IF tgt {
    SET conn TO tgt:CONNECTION.
  }
  // high timewarp fucks with things.
  RETURN KUNIVERSE:TIMEWARP:RATE = 1 AND conn:ISCONNECTED().
}

// Get a file from KSC
FUNCTION DOWNLOAD {
  PARAMETER name.
  PARAMETER comp IS FALSE. // do you want to compile before downloading
  PARAMETER dest IS CHOOSE name + "m" IF comp ELSE name.
  
  // truncate "0:/" if exists.
  IF name[0] = "0" AND name[1] = ":" AND name[2] = "/" {
    SET name TO name:SUBSTRING(3, name:LENGTH() - 3).
  }
  
  IF ARCHIVE:EXISTS(name) {
    IF comp {
	  COMPILE "0:/" + name TO dest.
	}
	else
	{
      COPYPATH("0:/" + name, dest).
	}
  }
}

// Put a file on KSC
FUNCTION UPLOAD {
  PARAMETER name.
  LOCAL uploadDir IS "0:/" + SHIP:NAME + "/Uploads." + getMissionCount().
  IF CORE:VOLUME:EXISTS(name) {
    IF NOT EXISTS(uploadDir) {
      CREATEDIR(uploadDir).
    }
    COPYPATH(name, "0:/" + SHIP:NAME + "/" + name).
  }
}

// Run a library, downloading it from KSC if necessary or if connection exists already.
FUNCTION REQUIRE {
  PARAMETER name.
  IF NOT CORE:VOLUME:EXISTS(name + "m") OR CHECK_CONNECTION()
  {
    LOCAL comp IS NOT DEBUG.
    WAIT UNTIL CHECK_CONNECTION().
    PRINT "Fetching " + name + ", Compile: " + comp.
    DOWNLOAD(name, comp).
  }
  RUNONCEPATH (name + "m").
}

FUNCTION getMissionCount
{
  // cnt file is to count how many mission files have been executed so far so not to overwrite previously executed scripts, telemetry and other such data.
  LOCAL cntFilePath IS "0:/" + SHIP:NAME + "/count.txt".
  LOCAL cnt IS 0.
  IF EXISTS(cntFilePath)
  {
    // read count
    LOCAL cntFile IS OPEN(cntFilePath).
    SET cnt TO cntFile:READALL:STRING():TONUMBER().
  }
  RETURN cnt.
}

FUNCTION addMissionCounter
{
  LOCAL cntFilePath IS "0:/" + SHIP:NAME + "/count.txt".
  LOCAL cnt IS getMissionCount().
  DELETEPATH(cntFilePath).
  CREATE(cntFilePath):WRITE("" + (cnt + 1)).
}

FUNCTION getMissionTime
{
  RETURN TIME:SECONDS - getMissionStartTime().
}

FUNCTION getMissionStartTime
{
  RETURN OPEN("/starttime.txt"):READALL:STRING():TONUMBER().
}

// save the current time as the start time for this mission if it doesn't already exist, so that it can be recovered later.
IF NOT EXISTS("/starttime.txt") { LOG TIME:SECONDS TO "/starttime.txt". }