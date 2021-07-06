// Compile second stage bootloader to save disk space
GLOBAL DEBUG IS FALSE.

SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.

SET TERMINAL:WIDTH TO 120.
SET TERMINAL:HEIGHT TO 32.

WAIT 0.1.

CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
WAIT 0.7.

CLEARSCREEN.

PRINT "Boot Stage 1".
IF DEBUG = TRUE {
  PRINT "2nd Stage copy.".
  FROM {LOCAL i IS 10.} UNTIL (i = 0) STEP {SET i TO i-1. } DO PRINT "!!! DEBUG !!!".
  COPYPATH("0:/boot/generalBoot.ks", "/boot/").
} ELSE IF NOT CORE:VOLUME:EXISTS("generalBoot.ksm") OR HOMECONNECTION:ISCONNECTED() {
  PRINT "2nd Stage compile.".
  WAIT UNTIL HOMECONNECTION:ISCONNECTED().
  SWITCH TO ARCHIVE.
  COMPILE "boot/generalBoot.ks".
  SWITCH TO CORE:VOLUME.
  MOVEPATH("0:/boot/generalBoot.ksm", "boot/generalBoot.ksm").
}

PRINT "Stage 1 done.".

RUNPATH("boot/generalBoot").