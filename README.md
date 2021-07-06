# kOSLibraries
A number of Kerbal Operating System libraries to use in rockets.

# Quick Ref

## File System

### Volumes

There are different volumes. One volume per CPU.
Different CPUs on vessels can access each other's volumes with their ID

Volumes can be named
```
SET VOLUME("0"):NAME TO "SomeName"
```

To switch to a different volume use

```
SWITCH TO 1.
```

### Archive
Archive (volume 0) does not revert when loading a save file, however vessel's copies of the volumes will.
Scripts are in Ships/Script

### Boot
Files in Ships/Script/Boot will be selectable as the boot script when placing the KOS part.
It will execute whenever the vessel is loaded into physics range, or if the cpu is rebooted

It is best to avoid instant actions on parts until the vessel is fully loaded with physics.

### Compile
Compiling reduces the size of files, allowing it to be stored more effectively.
Compiling takes time and will behave like wait in that it stops mainline code if called in mainline or all code (incl. triggers) when called from a trigger.

### Files

List files with `LIST` or `LIST FILES`.

Running will autocomplete by guessing the filename.
If no path is given it will run the current directory.
If file extention is missing and there is no file without an extention, .ksm or .ks will be added.
If both files are present ksm takes precedence.

Log text to files with `LOG "string, string, string" TO "1:/path/to/file.csv".`

### Paths
Use with

CD(PATH)
COPYPATH(FROM, TO)
MOVEPATH(FROM, TO)
DELETEPATH(FROM, TO)
EXISTS(PATH)
CREATE(PATH)
CREATEDIR(PATH)
OPEN(PATH)
EDIT PATH
LOG STRING TO PATH

Get the current working directory with: PATH(): `PRINT PATH().`

Paths are absolute: `vol:/path/to/file.ext`
Paths are relative: `../../path/to/file.ext`, relative paths to the root of the volume are invalid: `0:/directory/../..`


## Syntax

scientific notation: `1.23e-4`
exponent operator: `2^3` (=8)
Division doesn't truncate, even with integer operands: `1/4` = 0.25
underscores may be used within numbers. they are ignored and can be used for visual aid: `set x to 100_000`

Identifiers like everything are case insensitive
Strings in comparison are CASE INSENSITIVE. `"hello" = "HELLO"` is TRUE

Commands end with a period (`.`)
suffixes can be accessed with the colon (`:`), like a structure: `print ship:velocity:orbit:x`
code blocks are denoted by `{}`. they can be used anywhere for scoping
functions are called by function names with parameters in parenthesis: `ROUND(123.123, 2). SIN(45).`
function calls without arguments can omit parenthesis if desired.
suffixes can be called as member functions (methods):
```
set x to ship:partsnamed("rtg").
print x:length().
x:remove(0).
x:clear().
```

## Logic operators
not A
=, <>, >=, <=, >, <
Do not use != or ==

true, false

any number non-zero is true

## keywords

add 			- ?
all 			- UNLOCK ALL
at  			- print at specified location (`PRINT "HELLO" AT (5,7).`)
break 			- break out of loops
choose			- ternary operator
clearscreen		- clears kos terminal
compile			- compiles source to destination
copy			- deprecated, use copypath, copy file
copypath		- copy file with paths (`copypath("0:/src.ks", "1:/dst.ks").`), contents overwritten. may copy directories recursively with directory name.
declare			- declare variables
defined			- ?
delete			- deprecated, use deletepath, delete file
deletepath		- delete file
do				- for use in from loop
edit			- open in game editor to edit file
if, else		- if, else
file			- ?
for				- for loops (iterator over container)
from			- from loop (classic for loop)
function		- declare function
global			- declare global variable
in				- for use in for loops, put special into list (LIST ENGINES IN eList)
is				- initialize with LOCAL or GLOBAL
list			- declare list
local			- declare local variable
lock			- set alias/variable to an expression and execute expression whenever accessed
log				- write to file
off				- turn things off (RCS OFF.)
on				- turn things on, declare trigger
once			- added to run optionally. deprecated. use runoncepath
parameter		- declare function or script parameter
preserve		- deprecated. do not use. see when/on
print			- print text to screen
reboot			- restart boot program
remove			- ?
rename			- rename file, deprecated. use MOVEPATH instead.
return			- return from function with value
run				- run script file, deprecated. use runpath or runoncepath
runoncepath		- run the given path only once. it will skip execution if the script has been run before
runpath			- run the given program.
set				- set variable to value
shutdown		- stop computer
stage			- stage rocket
step			- for use in from loops
switch			- switch volumes (`SWITCH TO 0.`)
then			- for use with When
to				- setting/locking
toggle			- toggle boolean. (useful with `AG1`, `LIGHTS`, etc)
unlock			- remove `LOCK` statement, `unlock all` to remove all locks
unset			- ?
until			- runs block until conditio true
volume			- ?
wait			- sleeps for some amount of seconds or until a condition is true
when			- define hardware interrupt (trigger)

## Variables

```
@LAZYGLOBAL off.  // turns off automatic, global variable declaration

DECLARE X TO 0.
DECLARE Y TO 0.

LOCAL Z IS 0.
GLOBAL W IS 0.

SET X TO 0.
LOCK Y TO X + 2. // Y is 2, will only keep Y as long as in SCOPE
SET X TO 2       // Y is 4 now
UNLOCK Y		 // Y is now ?
```

### Special variables
https://ksp-kos.github.io/KOS/bindings.html

SHIP		- vessel with the CPU
TARGET		- Target of the current ship (vessel, body or part)
HASTARGET	- Current ship has a target. If not current ship will always be false.

ALT			- Deprecated, use SHIP or SHIP shortcuts. Used to get APOAPSIS, PERIAPSIS, RADAR

Terminal 	- terminal structure
Core		- core structure of current cpu
Archive		- volume structure of the archive
Stage		- stage structure used to count resources in the current stage, not to be confused with the `stage` command
NextNode	- https://ksp-kos.github.io/KOS/structures/vessels/node.html#global:NEXTNODE
HasNode 	- https://ksp-kos.github.io/KOS/structures/vessels/node.html#global:HASNODE
AllNodes	- https://ksp-kos.github.io/KOS/structures/vessels/node.html#global:ALLNODES

#### Shortcuts for SHIP:Members

HEADING, PROGRADE, RETROGRADE, FACING, MAXTHRUST, VELOCITY, GEOPOSITION, LATITUDE, LONGITUDE, UP, NORTH, BODY, ANGULARMOMENTUM, ANGULARVEL, ANGULARVELOCITY, MASS, VERTICALSPEED, GROUNDSPEED, AIRSPEED, ALTITUDE, APOAPSIS, PERIAPSIS, SENSORS, SRFPROGRADE, SRFRETROGRADE, OBT, STATUS, SHIPNAME



Resource Types:
Can be queried with SHIP or STAGE prefix

LIQUIDFUEL
OXIDIZER
ELECTRICCHARGE
MONOPROPELLANT
INTAKEAIR
SOLIDFUEL



#### Constants

Access with `constant:pi`

G - Gravitational constant (6.67384E-11)
g0 - gravity at sea level on earth (9.80655 m/s^2), used mainly for ISP calculation (how much would this fuel weigh on earth)
E - natural log
pi - pi
c - speed of light
AtmToKPa - atmosphere to kilopascals
KPaToAtm - analog
DegToRad - Degree to radians
RadToDeg - analog
Avogardro - Avogardro's constant
Boltzmann - Boltzmann's constant
IdealGas - Ideal gas constant

## Structures
https://ksp-kos.github.io/KOS/structures.html

Can not make your own structures and classes yet.

### Lists
```
SET myList1 TO LIST().
SET myList2 TO LIST(1,2,3).
PRINT myList1:COUNT().
PRINT myList2[2].
```

#### Members
ADD(item)
INSERT(idx, item)
REMOVE(idx)
CLEAR()
COPY()
SUBLIST(idx, len)
JOIN(seperator)    					- create a string
FIND(item); INDEXOF(item)			- return first index found
FINDLAST(item), LASTINDEXOF(item)

### Lexicons
https://ksp-kos.github.io/KOS/structures/collections/lexicon.html

Lexicons are dictionaries

```
set MyLex to Lexicon("key1", "value1", "key2", "value2"). // initialization can be empty
MyLex:ADD("key3", "value3").

// Access as suffix or as index
print MyLex["key1"].
print MyLex:key1. 		// this has some limits
```

suffix syntax can not use keys with spaces
predefined suffixes like `LENGTH` will result in the predefined suffix to be used, not as a key

#### members
`ADD(key, value)`
`CASESENSITIVE`, `CASE` - clears lexicon, makes keys case senstitive if set to true
`CLEAR`
`COPY` - shallow copy
`DUMP` - string dump
`HASKEY`, `HASVALUE`
`KEYS` - list of keys
`VALUES` - list of values
`LENGTH` - number of pairs
`REMOVE` - removes key/value pair
`HASSUFFIX`	- returns if a suffix or key with the name exists
`SUFFIXNAMES` - get list of strings for all suffixes and keys that work as suffixes

## Functions

### Declaring functions

```
DECLARE FUNCTION f {
  DECLARE PARAMETER a
  
  PRINT "a = " + a.
}
```

### Builtin Functions

ABS(a)			- absolute
CEILING(a)  	- round up
CEILING(a,p)	- round up to precision
FLOOR(a)
FLOOR(a,p)
ROUND(a)
ROUND(a,p)
LN(a)			- natural log
LOG10(a)
MOD(a,b)		- a % b
MIN(a,b)
MAX(a,b)
RANDOM()		- 0 .. 1 , may accept a key parameter (deterministic random sequences by name)
RANDOMSEED()	- start new random sequence, may add key parameter. may additionally add seed integer.
SQRT(a)
CHAR(i)			- char from unicode
UNCHAR(c)		- unicode from character

SIN(a)			- sine of angle in deg
COS(a)
TAN(a)
ARCSIN(x)		- angle whose sine is x in deg
ARCCOS(x)
ARCTAN(x)
ARCTAN2(y,x)	- angle whose tagent is frac{y}{x}, http://en.wikipedia.org/wiki/Atan2

## Control structures
### UNTIL loop
```
UNTIL FALSE { // runs until expression is true
  IF ALT:RADAR < 1000 {
    SET GEAR TO TRUE.
	SET LIGHTS TO TRUE.
	BREAK. // breaks out of until loop
  }
}
```

### IF conditions
```
IF COND { CODE. }
IF COND { CODE. } ELSE IF COND { CODE. } ELSE { CODE. }
```

### Choose ternary operator
```
SET X TO   CHOOSE Y IF COND ELSE Z. // x = COND ? Y : Z;
```

### For loop
```
FOR item IN LIST (1,2,3) { print item. }
```

### From loop
```
PRINT "Countdown..."
FROM {LOCAL X IS 10.} UNTIL (x = 0) STEP { SET X TO X-1. } DO {
  print "T -" + X.
  WAIT 1.0.
}
```

### Wait
```
WAIT 1.0. // wait 1 second
WAIT UNTIL APOAPSIS > 150_000.
```

Wait will not halt triggers (`When`, `On`) unless it is called from within a trigger.

### When/On
Check in beckground for a condition that will execute code.

```
WHEN booleanExpression THEN {
  CODE.
}

ON anyExpression {
  CODE.
}
```

When - Checks in background and fires condition if true
On - Checks in background. If the condition is now different from last time it checked (even if false), the trigger fires and performs the statiement.

While code is executed, other code is interrupted and other triggers can not fire.
By default it will not fire multiple times.

To recheck multiple times use `RETURN`. if return is true, it will preserve the trigger.
If return is false it will then delete the trigger.

```
SET count TO 5.
ON AG1 {
  PRINT "You pressed '1', causing action group 1 to toggle.".
  PRINT "Action group 1 is now " + AG1.
  SET count TO count - 1.
  PRINT "I will only pay attention " + count + " more times.".
  if count > 0
    RETURN true. // will keep the trigger alive.
  else
    RETURN false. // will let the trigger die.
}
```

Triggers will expire if program is completed.

Preserve is a deprecated command. If run inside a trigger it will keep the trigger around. If not executed, the trigger will be deleted, even if the same trigger executed preserve before in another branch.

## Vessel steering and control
https://ksp-kos.github.io/KOS/commands/flight.html


## Misc
https://ksp-kos.github.io/KOS/commands/communication.html