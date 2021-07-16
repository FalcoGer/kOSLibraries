// script to make printing more sanely
// used to make ascii GUI

LOCAL regions IS LEXICON().

FUNCTION TERM_setup
{
  PARAMETER w.
  PARAMETER h.
  
  SET TERMINAL:WIDTH TO w.
  SET TERMINAL:HEIGHT TO h.
}

FUNCTION TERM_show
{
  CORE:DOEVENT("Open Terminal").
}

FUNCTION TERM_hide
{
  CORE:DOEVENT("Close Terminal").
}

FUNCTION TERM_print
{
  PARAMETER msg.
  PARAMETER regionName IS "default".
  PARAMETER lineNo IS -1.
  PARAMETER updateRegion IS TRUE.
  // implement column?
  
  LOCAL region IS regions[regionName].
  LOCAL maxWidth IS region["w"] - 2.
  
  IF lineNo < 0 {
    SET lineNo TO region["lines"]:LENGTH.
  }
  
  // add lines to have the index available.
  UNTIL region["lines"]:LENGTH > (lineNo - 1) {
    region["lines"]:ADD("":PADRIGHT(maxWidth)).
  }
  
  // fit message into lines until message digested completely
  UNTIL msg:LENGTH = 0 {
    LOCAL partMsg IS msg:SUBSTRING(0, MIN(msg:LENGTH, maxWidth)).
    SET msg TO msg:SUBSTRING(partMsg:LENGTH, msg:LENGTH - partMsg:LENGTH).
    SET partMsg TO partMsg:PADRIGHT(maxWidth).
    IF lineNo >= region["lines"]:LENGTH { region["lines"]:ADD(partMsg). }
    ELSE { SET region["lines"][lineNo] TO partMsg. }
    
    SET lineNo TO lineNo + 1.
  }
  
  IF updateRegion {
    TERM_update(region).
  }
}

FUNCTION TERM_clear
{
  PARAMETER regionName IS "default".
  LOCAL region IS regions[regionName].
  region["lines"]:CLEAR().
  
  TERM_update(region).
}

FUNCTION TERM_addRegion
{
  PARAMETER title.
  PARAMETER x.
  PARAMETER y.
  PARAMETER width.
  PARAMETER height.
  
  IF width <= 2 { LOCAL failure IS 1 / 0. }
  IF height <= 0 { LOCAL failure IS 1 / 0. }
  
  SET region TO LEXICON("title", title, "x", x, "y", y, "w", width, "h", height, "lines", LIST()).
  
  SET regions[title] TO region.
  
  TERM_addBorder(region).
  TERM_update(region).
}

FUNCTION TERM_removeRegion
{
  PARAMETER regionName.
  
  IF regions:HASKEY(regionName) {
    regions:REMOVE(regionName).
  }
  
  CLEARSCREEN.
  
  FOR region IN regions:VALUES {
    TERM_addBorder(region).
    TERM_addTitle(region).
    TERM_update(region).
  }
}

LOCAL FUNCTION TERM_update
{
  PARAMETER region.
  
  // push old lines that don't fit out of the top
  UNTIL region["lines"]:LENGTH <= region["h"] {
    region["lines"]:REMOVE(0).
  }
  
  LOCAL lineCount IS region["lines"]:LENGTH.
  
  LOCAL termX IS region["x"] + 2.     // leave a space on the left (border + 1 space)
  LOCAL maxWidth IS region["w"] - 2.
  LOCAL emptyLine IS "":PADRIGHT(maxWidth).
  
  FOR termY IN RANGE(region["y"] + 1, region["y"] + region["h"] + 1, 1) {
    LOCAL lineNo IS termY - region["y"] - 1.
    LOCAL lineText IS emptyLine.
    IF lineNo < lineCount
    {
      SET lineText TO region["lines"][lineNo].
    }
    PRINT lineText AT (termX, termY).
  }
}

LOCAL FUNCTION TERM_addBorder
{
  PARAMETER region.
  
  LOCAL bottom IS region["y"] + region["h"] + 1.
  
  LOCAL topBottomBorder IS "+" + "":PADRIGHT(region["w"]):REPLACE(" ", "-") + "+".
  LOCAL leftRightBorder IS "|" + "":PADRIGHT(region["w"]) + "|".
  
  PRINT topBottomBorder AT (region["x"], region["y"]).
  FOR y IN RANGE (region["y"] + 1, bottom, 1) {
    PRINT leftRightBorder AT (region["x"], y).
  }
  PRINT topBottomBorder AT (region["x"], bottom).
  
  TERM_addTitle(region).
}

LOCAL FUNCTION TERM_addTitle
{
  PARAMETER region.
  PRINT region["title"] AT (region["x"] + ROUND(region["w"] / 2, 0) - ROUND(region["title"]:LENGTH / 2, 0), region["y"]).
}