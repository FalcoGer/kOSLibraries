// a variety of math functions

REQUIRE("lib/test.ks").

GLOBAL MATH_INFINITY IS 2^64.

// rotate a vector towards another vector by a specified angle (deg)
FUNCTION MATH_vecRotToVec {
  PARAMETER vSrc.           // vector we want to rotate
  PARAMETER vDest.          // vector we want to rotate to
  PARAMETER theta.          // angle to rotate
  
  TEST_ASSERT_NOTEQUAL(vSrc:NORMALIZED, vDest:NORMALIZED, "Vectors " + vSrc + " and " + vDest + " need to point in different directions.").
  
  // perform axis-angle rotation around cross product vector (perpendicular to both)
  // to do that we use the https://en.wikipedia.org/wiki/Rodrigues%27_rotation_formula
  
  // vRot = v * cos(theta) + (k cross v) * sin(theta) + k * (k dot v) * (1 - cos(theta)).
  //
  // v is the vector we want to rotate
  // k is a unit vector for the axis we want to rotate around
  // theta is the angle of rotation
  
  LOCAL axis IS VCRS(vSrc, vDest):NORMALIZED.
  
  // ^ vSrc x vDest (axis of rotation)
  // |
  // |      ^ vDest
  // |    /    _- > vRot
  // |  /  _--/ ^
  // |/_--/      ) theta
  // +------------> vSrc
  
  LOCAL vRot IS vSrc * COS(theta)                     // reduce size
        + VCRS(axis, vSrc) * SIN(theta)               // skew vector
        + axis * VDOT(axis, vSrc) * (1 - COS(theta)). // increase size
  RETURN vRot.
}

FUNCTION MATH_gaussian {
  PARAMETER x.                    // x value for which to get the y value
  PARAMETER magnitude IS 1.0.     // height of the peak
  PARAMETER xOffset IS 0.0.       // position of the curve's peak
  PARAMETER stdDev IS 1.0.        // standard deviation (width of the bell)
  
  // f(x)  = a * e^(-(x - b)^2 / (2*c^2))
  // f'(x) = a * (b-x) *e^(-(b-x)^2 / (2*c^2)) / c^2
  
  RETURN magnitude * CONSTANT:E^((-(x - xOffset)^2) / (2*stdDev^2)).
}

FUNCTION MATH_APROX {
  PARAMETER a, b.
  PARAMETER margin IS 0.00001.
  
  RETURN (a + margin > b) AND (a - margin < b).
}

// finds neighbors and then determines the best fitness. for each one until best neighbor is found
// then divide step size by 2 and repeat until numOfSteps is reached.
FUNCTION MATH_hillClimb {
  PARAMETER initialData.        // list of initial data points with best guess
  PARAMETER stepSize.           // list of step sizes
  PARAMETER fitnessFunction.    // determines how good a set of data points is.
  PARAMETER numOfSteps IS 1.    // how often to repeat finding the best fitting datapoints
  
  LOCAL bestFit IS initialData.
  FROM { LOCAL stepNum IS numOfSteps. } UNTIL (stepNum <= 0) STEP { SET stepNum TO stepNum - 1. } DO {
    LOCAL betterFound IS TRUE.
    UNTIL betterFound {           // until best neighbor with current step size is found.
      SET betterFound TO FALSE.   // we didn't find anything yet.
      
      // generate all neighbors by
      // going over every dimension of the data
      // and adding/sutbracting step size for that dimension
      // going over all neighbors in the future will keep those adjustments in mind.
      LOCAL neighbors IS LIST().    // list of datapoint lists
      neighbors:ADD(bestFit).
      FROM { LOCAL dim IS 0. } UNTIL ( dim >= data:LENGTH() ) STEP { SET dim TO dim + 1. } DO {
        FROM { LOCAL idx IS 0. } UNTIL ( idx >= neighbors:LENGTH() ) STEP { SET idx TO idx + 1. } DO {
          LOCAL newNeighbor IS neighbors[idx].
          SET newNeighbor[dim] TO newNeighbor[dim] - stepSize[dim].
          neighbors:ADD(newNeighbor).
          SET newNeighbor[dim] TO newNeighbor[dim] + (stepSize[dim] * 2).
          neighbors:ADD(newNeighbor).
        }
      }
      
      // find the best one
      FOR neighbor IN neighbors {
        IF fitnessFunction(neighbor) >= fitnessFunction(bestFit) {
          // better neighbor found
          SET betterFound TO TRUE.    // continue with current step size.
          SET bestFit TO neighbor.    // this is our new best.
        }
      }
    }
    
    // adjust step size
    FROM {LOCAL dim IS 0.} UNTIL ( dim >= stepSize:LENGTH() ) STEP {SET dim TO dim + 1.} DO {
      SET stepSize[dim] TO stepSize[dim] / 2.
    }
    
    // continue with next step
  }
  
  RETURN bestFit.
}