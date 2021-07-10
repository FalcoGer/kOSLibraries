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
      SET header TO header + ",'" + key + "'".
    }
    LOG "var data = [['Time'" + header + "]," TO pathToTelemJS.
    
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
  LOCAL line IS "[" + ROUND(getMissionTime(), 5).
  FOR value IN dataRow:VALUES {
    SET line TO line + "," + value.
  }
  SET line TO line + "],".
  
  LOG line TO pathToTelemJS.
}

FUNCTION TELEM_finish {
  PARAMETER telemetryName.
  PARAMETER directory.
  
  IF directory:SUBSTRING(0,2) = "0:"
  {
    WHEN CHECK_CONNECTION() THEN {
      LOCAL pathToTelemJS IS directory + "/" + telemetryName + ".js".
      LOG "];" TO pathToTelemJS.
    }
  }
  ELSE
  {
    LOCAL pathToTelemJS IS directory + "/" + telemetryName + ".js".
    LOG "];" TO pathToTelemJS.
  }
  
}