import math

import Vec3

type 
  Quat* = object
    w*: float
    x*: float
    y*: float
    z*: float

proc initQuat*(x: float, y: float, z: float, w: float): Quat =
  return Quat(x: x, y: y, z: z, w: w)

proc identityQuat*(): Quat =
  return Quat(w: 1.0, x: 0.0, y: 0.0, z: 0.0)

proc dot*(self: Quat, other: Quat): float =
  return self.w*other.w + self.x*other.x + self.y*other.y + self.z*other.z

proc length*(self: Quat): float =
  return sqrt(self.dot(self))

proc `+`*(self: Quat, other: Quat): Quat =
  return Quat(w: self.w + other.w, x: self.x + other.x, y: self.y + other.y, z: self.z + other.z)

proc `-`*(self: Quat, other: Quat): Quat =
  return Quat(w: self.w - other.w, x: self.x - other.x, y: self.y - other.y, z: self.z - other.z)

proc `*`*(self: Quat, scale: float): Quat =
  return Quat(w: self.w * scale, x: self.x * scale, y: self.y * scale, z: self.z * scale)

proc normalize*(self: Quat): Quat =
  var l = self.length
  if l > 0:
    return self * (1/l)
  else:
    return self

proc lerp*(self: Quat, other: Quat, t: float): Quat =
  var diff = other - self
  return self + diff * t

proc slerp*(self: Quat, other: Quat, t: float): Quat =
  var dot = self.dot(other)
  if (dot < 0):
    return slerp(self * -1, other, t)
  const DOT_THRESHOLD = 0.9995
  if (dot > DOT_THRESHOLD):
    return self.lerp(other, t)
  dot = min(max(dot, -1), 1)
  var theta_0 = arccos(dot)
  var theta = theta_0*t
  var v2 = other - self * dot
  v2 = v2.normalize()
  return self*cos(theta) + v2*sin(theta)

proc conjugate*(self: Quat): Quat =
  result = Quat(x: -self.x, y: -self.y, z: -self.z, w: self.w)

proc axisAngleQuat*(axis: Vec3, angle: float): Quat =
  var s = sin(angle/2)
  result = initQuat(axis.x*s, axis.y*s, axis.z*s, cos(angle/2))

proc `*`*(self: Quat, other: Quat): Quat =
  result = identityQuat()
  result.w = self.w*other.w - self.x*other.x - self.y*other.y - self.z*other.z
  result.x = self.x*other.w + self.w*other.x - self.z*other.y + self.y*other.z
  result.y = self.y*other.w + self.z*other.x + self.w*other.y - self.x*other.z
  result.z = self.z*other.w - self.y*other.x + self.x*other.y + self.w*other.z
