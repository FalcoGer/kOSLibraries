// a variety of math functions

REQUIRE("lib/test.ks").

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
  return vRot.
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