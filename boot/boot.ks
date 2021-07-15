// Compile second stage bootloader to save disk space
GLOBAL DEBUG IS FALSE.

SWITCH TO CORE:VOLUME.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.

CLEARSCREEN.

PRINT "Boot Stage 1".
IF DEBUG = TRUE {
  PRINT "2nd Stage copy.".
  FROM {LOCAL i IS 10.} UNTIL (i = 0) STEP {SET i TO i-1. } DO PRINT "!!! DEBUG !!!".
  COPYPATH("0:/boot/generalBoot.ks", "/boot/").
} ELSE IF NOT CORE:VOLUME:EXISTS("generalBoot.ksm") OR HOMECONNECTION:ISCONNECTED() {
  PRINT "2nd Stage compile.".
  WAIT UNTIL HOMECONNECTION:ISCONNECTED().
  COMPILE "0:/boot/generalBoot.ks" TO "1:/boot/generalBoot.ksm".
}

PRINT "Stage 1 done.".

RUNPATH("boot/generalBoot").