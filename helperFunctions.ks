// Display a message
FUNCTION NOTIFY {
  PARAMETER message.
  PARAMETER priority.
  
  SET colour TO
    CHOOSE BLUE IF priority <= 0 ELSE
	CHOOSE GREEN IF priority <= 1 ELSE
	CHOOSE YELLOW IF priority <= 2 ELSE
	CHOOSE RGB(255,128,0) IF priority <= 3 ELSE
	RED.
  
  // https://ksp-kos.github.io/KOS/commands/terminalgui.html
  HUDTEXT("kOS: " + message, 5, 2, 50, colour, true).
}

// Get a file from KSC
FUNCTION DOWNLOAD {
  PARAMETER name.
  PARAMETER comp. // do you want to compile before downloading
  IF EXISTS("0:/" + name) {
    IF comp {
	  SWITCH TO ARCHIVE
	  compile name TO (name + "m").
	  SWITCH TO 1.
	  SET name TO name + "m".
	  MOVEPATH("0:/" + name, "1:/" + name).
	}
	else
	{
      COPYPATH("0:/" + name, "1:/" + name).
	}
  }
}

// Put a file on KSC
FUNCTION UPLOAD {
  PARAMETER name.
  IF EXISTS("1:/" + name) {
    COPYPATH("1:/" + name, "0:/" + name).
  }
}

// Run a library, downloading it from KSC if necessary
FUNCTION REQUIRE {
  PARAMETER name.
  IF NOT EXISTS("1:/" + name + "m")
  {
	DOWNLOAD(name, TRUE).
  }
  RUNPATH ("1:/" + name + "m").
}