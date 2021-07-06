// Display a message
FUNCTION NOTIFY {
  PARAMETER message.
  PARAMETER priority IS 1.
  
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
  PRINT priorityStr + message.
}

FUNCTION CHECK_CONNECTION {
  PARAMETER tgt IS FALSE.
  
  LOCAL conn IS HOMECONNECTION.
  IF tgt {
    SET conn TO tgt:CONNECTION.
  }
  RETURN conn:ISCONNECTED().
}

// Get a file from KSC
FUNCTION DOWNLOAD {
  PARAMETER name.
  PARAMETER comp IS FALSE. // do you want to compile before downloading
  PARAMETER dest IS CHOOSE name + "m" IF comp ELSE name.
  
  // truncate "0:" if exists.
  IF name[0] = "0" AND name[1] = ":" {
    SET name TO name:SUBSTRING(2, name:LENGTH() - 2).
  }
  
  IF ARCHIVE:EXISTS(name) {
    IF comp {
	  SWITCH TO ARCHIVE.
	  COMPILE name TO "tmp.ksm".
	  SWITCH TO CORE:VOLUME.
	  MOVEPATH("0:/tmp.ksm", dest).
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
  IF CORE:VOLUME:EXISTS(name) {
    IF NOT ARCHIVE:EXISTS(SHIP:NAME) {
      ARCHIVE:CREATEDIR("0:/" + SHIP:NAME).
	}
	COPYPATH(name, "0:/" + SHIP:NAME + "/" + name).
  }
}

// Run a library, downloading it from KSC if necessary
FUNCTION REQUIRE {
  PARAMETER name.
  IF NOT CORE:VOLUME:EXISTS(name + "m")
  {
    WAIT UNTIL CHECK_CONNECTION.
	DOWNLOAD(name, NOT DEBUG).
  }
  RUNPATH (name + "m").
}