// generate a file for telemetry viewing with HighCharts

FUNCTION TELEM_write {
  PARAMETER telemetryName.
  PARAMETER directory.
  PARAMETER dataRow.
  
  LOCAL writeHeader IS FALSE.
  LOCAL pathToTelemJS IS directory + "/" + telemetryName + ".js".
  
  IF NOT EXISTS(directory) {
    CREATEDIR(directory).
  }
  
  IF NOT EXISTS(pathToTelemJS) {
    LOCAL pathToTelemHTML IS directory + "/" + telemetryName + ".html".
    
    LOCAL header IS "".
    FOR key in dataRow:KEYS {
      SET header TO header + "'" + key + "',".
    }
    // remove last, trailing colon
    SET header TO header:SUBSTRING(0, header:LENGTH() - 1).
    LOG "var data = [[" + header + "]," TO pathToTelemJS.
    
    WHEN CHECK_CONNECTION() THEN {
      LOCAL highchartsContent IS OPEN("0:/highcharts.html"):READALL:STRING.
      SET highchartsContent TO highchartsContent:REPLACE("INSERT_FILEPATH_HERE", telemetryName + ".js")
                                                :REPLACE("INSERT_TELEMETRYNAME_HERE", telemetryName).
      IF EXISTS(pathToTelemHTML) {
        DELETEPATH(pathToTelemHTML).
      }
      LOCAL htmlFile IS CREATE(pathToTelemHTML).
      htmlFile:WRITE(highchartsContent).
    }
  }
  
  // write telemetry
  LOCAL line IS "[".
  FOR value IN dataRow:VALUES {
    SET line TO line + value + ",".
  }
  // remove trailing colon
  SET line TO line:SUBSTRING(0, line:LENGTH() - 1).
  SET line TO line + "],".
  
  LOG line TO pathToTelemJS.
}

FUNCTION TELEM_finish {
  PARAMETER telemetryName.
  PARAMETER directory.
  
  LOCAL pathToTelemJS IS directory + "/" + telemetryName + ".js".
  LOG "];" TO pathToTelemJS.
}