// a variety of math functions

REQUIRE("lib/test.ks").

GLOBAL MATH_INFINITY IS 2^1023.

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
// pass a step size of 0 to just pass a particular value in the data along as an
// argument in the fitness function.
FUNCTION MATH_hillClimb {
  PARAMETER initialData.        // list of initial data points with best guess
  PARAMETER stepSize.           // list of step sizes
  PARAMETER fitnessFunction.    // determines how good a set of data points is.
  PARAMETER numOfSteps IS 1.    // how often to repeat finding the best fitting datapoints
  
  LOCAL bestFit IS initialData.
  LOCAL bestFitFitness IS fitnessFunction(bestFit).
  
  FROM { LOCAL stepNum IS 0. } UNTIL (stepNum >= numOfSteps) STEP { SET stepNum TO stepNum + 1. } DO {
    LOCAL betterFound IS TRUE.
    UNTIL NOT betterFound {           // until best neighbor with current step size is found.
      SET betterFound TO FALSE.       // we didn't find anything yet.
      
      // generate all neighbors by
      // going over every dimension of the data
      // and adding/sutbracting step size for that dimension
      // going over all neighbors in future loops will keep those adjustments in mind, adding the neighbors of those nodes.
      LOCAL neighbors IS LIST().    // list of datapoint lists
      neighbors:ADD(bestFit).       // add the current best fit as a starting point
      FROM { LOCAL dim IS 0. } UNTIL ( dim >= bestFit:LENGTH() ) STEP { SET dim TO dim + 1. } DO {
        // only find neighbors if step size is not 0.
        // this allows to pass arguments to the fitness function in the data
        // by providing 0 step size for that dimension
        // skipping those points will run faster.
        IF (stepSize[dim] <> 0) {
          LOCAL numNeighbors IS neighbors:LENGTH(). // store here to prevent endless loop. as more are added in the loop for every existing neighbor so far.
          FROM { LOCAL idx IS 0. } UNTIL ( idx >= numNeighbors ) STEP { SET idx TO idx + 1. } DO {
            // need a copy so not to affect members in the list already.
            LOCAL newNeighbor IS neighbors[idx]:COPY. 
            SET newNeighbor[dim] TO newNeighbor[dim] - stepSize[dim].
            neighbors:ADD(newNeighbor).
            
            SET newNeighbor TO neighbors[idx]:COPY.
            SET newNeighbor[dim] TO newNeighbor[dim] + stepSize[dim].
            neighbors:ADD(newNeighbor).
          }
        }
      }
      
      // find the best one
      FOR neighbor IN neighbors {
        LOCAL neighborFitness IS fitnessFunction(neighbor).
        IF neighborFitness > bestFitFitness {
          // better neighbor found
          SET betterFound TO TRUE.          // continue with current step size.
          SET bestFit TO neighbor.          // this is our new best.
          SET bestFitFitness TO neighborFitness.
        }
      }
    }
    
    // no better fit found for current step size
    // adjust step size
    // could do in place calculation with
    // data +/- stepSize / 2^(stepNum)
    // but that's more calculation in the loop. this is probably faster.
    FROM {LOCAL dim IS 0.} UNTIL ( dim >= stepSize:LENGTH() ) STEP {SET dim TO dim + 1.} DO {
      SET stepSize[dim] TO stepSize[dim] / 2.
    }
    
    // continue with next step
  }
  
  RETURN bestFit.
}

// determines distance from a point to a plane defined by normal vector out of the plane and a point q on the plane.
FUNCTION MATH_distancePointToPlane {
  PARAMETER p.      // point as 3d vector
  PARAMETER nVec.   // normal vector of the plane
  PARAMETER q.      // point from which the normal vector protrudes to define the plane
  
  SET nVec TO nVec:NORMALIZED.
  
  // vector from q to p
  LOCAL q2p IS p - q.
  
  // exclude normal vector
  LOCAL q2under_p IS VXCL(nVec, q2p) + q.
  LOCAL d IS (p - q2under_p):MAG.        // pure distance
  
  // figure out if below or above, diretion of nVec being up
  IF ((p+nVec)-q):MAG < q2p:MAG {
    // if adding the normal vector to the point decreases the distance
    // then the point is below plane
    SET d TO d * -1.
  }
  
  RETURN d.
}

FUNCTION MATH_nodeFromVector {
    PARAMETER nodeTime.
    PARAMETER vecTarget.
    LOCAL localBody IS ORBITAT(SHIP,nodeTime):BODY.
    LOCAL vecNodePrograde IS VELOCITYAT(SHIP,nodeTime):ORBIT:NORMALIZED.
    LOCAL vecNodeNormal IS VCRS(vecNodePrograde,(POSITIONAT(SHIP,nodeTime) - localBody:POSITION):NORMALIZED):NORMALIZED.
    LOCAL vecNodeRadial IS VCRS(vecNodeNormal,vecNodePrograde).

    LOCAL nodePrograde IS VDOT(vecTarget,vecNodePrograde).
    LOCAL nodeNormal IS VDOT(vecTarget,vecNodeNormal).
    LOCAL nodeRadial IS VDOT(vecTarget,vecNodeRadial).
    RETURN NODE(nodeTime,nodeRadial,nodeNormal,nodePrograde).
}
