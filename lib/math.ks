// a variety of math functions

// rotate a vector towards another vector by a specified angle (deg)
FUNCTION MATH_vecRotToVec {
  PARAMETER vSrc.           // vector we want to rotate
  PARAMETER vDest.          // vector we want to rotate to
  PARAMETER theta.          // angle to rotate
  
  // perform axis-angle rotation around cross product vector (perpendicular to both)
  // to do that we use the https://en.wikipedia.org/wiki/Rodrigues%27_rotation_formula
  
  // vRot = v * cos(theta) + (k cross v) * sin(theta) + k * (k dot v) * (1 - cos(theta)).
  //
  // v is the vector we want to rotate
  // k is a unit vector for the axis we want to rotate around
  // theta is the angle of rotation
  
  LOCAL axis IS VCRS(vSrc, vDest):NORMALIZED.
  
  // ^ vSrc x vDest
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