// script to make printing more sanely
// used to make ascii GUI

LOCAL regions IS LEXICON().

FUNCTION TERM_print
{
  PARAMETER msg.
  PARAMETER regionName IS "default".
  PARAMETER lineNo IS -1.
  // implement column?
  
  LOCAL region IS regions[regionName].
  
  IF lineNo < 0 {
    SET lineNo TO region["lines"]:LENGTH.
  }
  
  // add lines to have the index available.
  UNTIL region["lines"]:LENGTH > (lineNo - 1) {
    region["lines"]:ADD("").
  }
  
  // fit message into lines until message digested completely
  UNTIL msg:LENGTH = 0 {
    LOCAL partMsg IS msg:SUBSTRING(0, MIN(msg:LENGTH, region["w"] - 2)).
    SET msg TO msg:SUBSTRING(partMsg:LENGTH, msg:LENGTH - partMsg:LENGTH).
    
    IF lineNo >= region["lines"]:LENGTH { region["lines"]:ADD(partMsg). }
    ELSE { SET region["lines"][lineNo] TO partMsg. }
    
    SET lineNo TO lineNo + 1.
  }
  
  TERM_update(region).
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
  
  FOR termY IN RANGE(region["y"] + 1, region["y"] + region["h"] + 1, 1) {
    LOCAL lineNo IS termY - region["y"] - 1.
    LOCAL lineText IS "".
    IF lineNo < lineCount
    {
      SET lineText TO region["lines"][lineNo].
    }
    PRINT " " + lineText:PADRIGHT(region["w"] - 2) AT (region["x"] + 1, termY).
  }
}

LOCAL FUNCTION TERM_addBorder
{
  PARAMETER region.
  
  LOCAL left IS region["x"].
  LOCAL top IS region["y"].
  LOCAL right IS region["x"] + region["w"] + 1.
  LOCAL bottom IS region["y"] + region["h"] + 1.
  
  PRINT "+" AT (left, top).
  PRINT "+" AT (left, bottom).
  PRINT "+" AT (right, top).
  PRINT "+" AT (right, bottom).
  FOR x IN RANGE(left + 1, right, 1)
  {
    PRINT "-" AT (x, top).
    PRINT "-" AT (x, bottom).
  }
  
  FOR y IN RANGE (top + 1, bottom, 1)
  {
    PRINT "|" AT (left, y).
    PRINT "|" AT (right, y).
  }
  
  TERM_addTitle(region).
}

LOCAL FUNCTION TERM_addTitle
{
  PARAMETER region.
  PRINT region["title"] AT (ROUND(region["w"] / 2, 0) - ROUND(region["title"]:LENGTH / 2, 0) + region["x"], region["y"]).
}