import math
import strutils

import Vec3 as Vec3
import Vec4 as Vec4
import Quat as Quat

type 
  Mat4* = object
    data*: array[16, float]

proc identityMat4*(): Mat4 =
  return Mat4(data: [
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0
  ])

proc `*`*(self: Mat4, other: Mat4): Mat4 =
  result = identityMat4()
  for i in 0..3:
    for j in 0..3:
      var total = 0.0
      for k in 0..3:
        total += self.data[i*4+k] * other.data[k*4+j]
      result.data[i*4+j] = total

proc `*`*(self: Mat4, other: Vec4): Vec4 =
  proc rowDot(row: int): float =
    return
      other.x * self.data[row*4+0] +
      other.y * self.data[row*4+1] +
      other.z * self.data[row*4+2] +
      other.w * self.data[row*4+3]

  return initVec4(
    rowDot(0),
    rowDot(1),
    rowDot(2),
    rowDot(3)
  )

proc `*`*(self: Mat4, other: Vec3): Vec3 =
  return (self * initVec4(other, 0)).xyz

proc transpose*(self: Mat4): Mat4 =
  result = identityMat4()
  for i in 0..3:
    for j in 0..i:
      result.data[i*4+j] = self.data[j*4+i]
      result.data[j*4+i] = self.data[i*4+j]

proc getTransposedFloat32Data*(self: Mat4): seq[float32] =
  result = newSeq[float32](16)
  for i in 0..3:
    for j in 0..3:
      result[i*4+j] = float32(self.data[j*4+i])

proc translateMat4*(x: float, y: float, z: float): Mat4 =
  return Mat4(data: [
    1.0, 0.0, 0.0, x,
    0.0, 1.0, 0.0, y,
    0.0, 0.0, 1.0, z,
    0.0, 0.0, 0.0, 1.0
  ])

proc translateMat4*(t: Vec3): Mat4 =
  return translateMat4(t.x, t.y, t.z)

proc scaleMat4*(x: float, y: float, z: float): Mat4 =
  return Mat4(data: [
    x,   0.0, 0.0, 0.0,
    0.0, y,   0.0, 0.0,
    0.0, 0.0, z,   0.0,
    0.0, 0.0, 0.0, 1.0
  ])

proc scaleMat4*(s: float): Mat4 =
  return scaleMat4(s, s, s)

proc rotateMat4*(quat: Quat): Mat4 =
  var xs = quat.x*quat.x
  var ys = quat.y*quat.y
  var zs = quat.z*quat.z
  var xy = quat.x*quat.y
  var xz = quat.x*quat.z
  var xw = quat.x*quat.w
  var yw = quat.y*quat.w
  var yz = quat.y*quat.z
  var zw = quat.z*quat.w
  return Mat4(data: [
    1-2*ys-2*zs, 2*xy-2*zw, 2*xz+2*yw, 0.0,
    2*xy+2*zw, 1-2*xs-2*zs, 2*yz-2*xw, 0.0,
    2*xz-2*yw, 2*yz+2*xw, 1-2*xs-2*ys, 0.0,
    0.0, 0.0, 0.0, 1.0
  ])

proc rotateXMat4*(angle: float): Mat4 =
  var c = cos(angle)
  var s = sin(angle)
  return Mat4(data: [
    1.0, 0.0, 0.0, 0.0,
    0.0, c,   -s,  0.0,
    0.0, s,   c,   0.0,
    0.0, 0.0, 0.0, 1.0
  ])

proc rotateYMat4*(angle: float): Mat4 =
  var c = cos(angle)
  var s = sin(angle)
  return Mat4(data: [
    c,   0.0, s,   0.0,
    0.0, 1.0, 0.0, 0.0,
    -s,  0.0, c,   0.0,
    0.0, 0.0, 0.0, 1.0
  ])

proc rotateZMat4*(angle: float): Mat4 =
  var c = cos(angle)
  var s = sin(angle)
  return Mat4(data: [
    c,   -s,  0.0, 0.0,
    s,   c,   0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0
  ])

proc rotationsAsQuat*(self: Mat4): Quat =
  var w = sqrt(1+self.data[0]+self.data[5]+self.data[10])
  var w4 = 4*w;
  var x = (self.data[9] - self.data[6]) / w4
  var y = (self.data[2] - self.data[8]) / w4
  var z = (self.data[4] - self.data[1]) / w4
  result = initQuat(x, y, z, w)

proc print*(self: Mat4) =
  for row in 0..3:
    echo("$1, $2, $3, $4" % [$self.data[row*4+0], $self.data[row*4+1], $self.data[row*4+2], $self.data[row*4+3]])

# Taken from here: http://stackoverflow.com/a/1148405/1470715
proc inverse*(self: Mat4): Mat4 =
  var inverse = identityMat4()
  var det = 0.0

  inverse.data[0] =
    self.data[5]  * self.data[10] * self.data[15] -
    self.data[5]  * self.data[11] * self.data[14] -
    self.data[9]  * self.data[6]  * self.data[15] +
    self.data[9]  * self.data[7]  * self.data[14] +
    self.data[13] * self.data[6]  * self.data[11] -
    self.data[13] * self.data[7]  * self.data[10]

  inverse.data[4] =
    -self.data[4]  * self.data[10] * self.data[15] +
    self.data[4]  * self.data[11] * self.data[14] +
    self.data[8]  * self.data[6]  * self.data[15] -
    self.data[8]  * self.data[7]  * self.data[14] -
    self.data[12] * self.data[6]  * self.data[11] +
    self.data[12] * self.data[7]  * self.data[10]

  inverse.data[8] =
    self.data[4]  * self.data[9] * self.data[15] -
    self.data[4]  * self.data[11] * self.data[13] -
    self.data[8]  * self.data[5] * self.data[15] +
    self.data[8]  * self.data[7] * self.data[13] +
    self.data[12] * self.data[5] * self.data[11] -
    self.data[12] * self.data[7] * self.data[9]

  inverse.data[12] =
    -self.data[4]  * self.data[9] * self.data[14] +
    self.data[4]  * self.data[10] * self.data[13] +
    self.data[8]  * self.data[5] * self.data[14] -
    self.data[8]  * self.data[6] * self.data[13] -
    self.data[12] * self.data[5] * self.data[10] +
    self.data[12] * self.data[6] * self.data[9]

  inverse.data[1] =
    -self.data[1]  * self.data[10] * self.data[15] +
    self.data[1]  * self.data[11] * self.data[14] +
    self.data[9]  * self.data[2] * self.data[15] -
    self.data[9]  * self.data[3] * self.data[14] -
    self.data[13] * self.data[2] * self.data[11] +
    self.data[13] * self.data[3] * self.data[10]

  inverse.data[5] =
    self.data[0]  * self.data[10] * self.data[15] -
    self.data[0]  * self.data[11] * self.data[14] -
    self.data[8]  * self.data[2] * self.data[15] +
    self.data[8]  * self.data[3] * self.data[14] +
    self.data[12] * self.data[2] * self.data[11] -
    self.data[12] * self.data[3] * self.data[10]

  inverse.data[9] =
    -self.data[0]  * self.data[9] * self.data[15] +
    self.data[0]  * self.data[11] * self.data[13] +
    self.data[8]  * self.data[1] * self.data[15] -
    self.data[8]  * self.data[3] * self.data[13] -
    self.data[12] * self.data[1] * self.data[11] +
    self.data[12] * self.data[3] * self.data[9]

  inverse.data[13] =
    self.data[0]  * self.data[9] * self.data[14] -
    self.data[0]  * self.data[10] * self.data[13] -
    self.data[8]  * self.data[1] * self.data[14] +
    self.data[8]  * self.data[2] * self.data[13] +
    self.data[12] * self.data[1] * self.data[10] -
    self.data[12] * self.data[2] * self.data[9]

  inverse.data[2] =
    self.data[1]  * self.data[6] * self.data[15] -
    self.data[1]  * self.data[7] * self.data[14] -
    self.data[5]  * self.data[2] * self.data[15] +
    self.data[5]  * self.data[3] * self.data[14] +
    self.data[13] * self.data[2] * self.data[7] -
    self.data[13] * self.data[3] * self.data[6]

  inverse.data[6] =
    -self.data[0]  * self.data[6] * self.data[15] +
    self.data[0]  * self.data[7] * self.data[14] +
    self.data[4]  * self.data[2] * self.data[15] -
    self.data[4]  * self.data[3] * self.data[14] -
    self.data[12] * self.data[2] * self.data[7] +
    self.data[12] * self.data[3] * self.data[6]

  inverse.data[10] =
    self.data[0]  * self.data[5] * self.data[15] -
    self.data[0]  * self.data[7] * self.data[13] -
    self.data[4]  * self.data[1] * self.data[15] +
    self.data[4]  * self.data[3] * self.data[13] +
    self.data[12] * self.data[1] * self.data[7] -
    self.data[12] * self.data[3] * self.data[5]

  inverse.data[14] =
    -self.data[0]  * self.data[5] * self.data[14] +
    self.data[0]  * self.data[6] * self.data[13] +
    self.data[4]  * self.data[1] * self.data[14] -
    self.data[4]  * self.data[2] * self.data[13] -
    self.data[12] * self.data[1] * self.data[6] +
    self.data[12] * self.data[2] * self.data[5]

  inverse.data[3] =
    -self.data[1] * self.data[6] * self.data[11] +
    self.data[1] * self.data[7] * self.data[10] +
    self.data[5] * self.data[2] * self.data[11] -
    self.data[5] * self.data[3] * self.data[10] -
    self.data[9] * self.data[2] * self.data[7] +
    self.data[9] * self.data[3] * self.data[6]

  inverse.data[7] =
    self.data[0] * self.data[6] * self.data[11] -
    self.data[0] * self.data[7] * self.data[10] -
    self.data[4] * self.data[2] * self.data[11] +
    self.data[4] * self.data[3] * self.data[10] +
    self.data[8] * self.data[2] * self.data[7] -
    self.data[8] * self.data[3] * self.data[6]

  inverse.data[11] =
    -self.data[0] * self.data[5] * self.data[11] +
    self.data[0] * self.data[7] * self.data[9] +
    self.data[4] * self.data[1] * self.data[11] -
    self.data[4] * self.data[3] * self.data[9] -
    self.data[8] * self.data[1] * self.data[7] +
    self.data[8] * self.data[3] * self.data[5]

  inverse.data[15] =
    self.data[0] * self.data[5] * self.data[10] -
    self.data[0] * self.data[6] * self.data[9] -
    self.data[4] * self.data[1] * self.data[10] +
    self.data[4] * self.data[2] * self.data[9] +
    self.data[8] * self.data[1] * self.data[6] -
    self.data[8] * self.data[2] * self.data[5]

  det = self.data[0] * inverse.data[0] + self.data[1] * inverse.data[4] + self.data[2] * inverse.data[8] + self.data[3] * inverse.data[12]
  if det == 0:
    raise newException(FloatDivByZeroError, "Det is 0")
  det = 1.0 / det
  for i in 0..15:
    inverse.data[i] = inverse.data[i] * det
  return inverse
