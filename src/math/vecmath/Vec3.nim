import math

type
  Vec3* = object
    x*: float
    y*: float
    z*: float

proc initVec3*(x: float, y: float, z: float): Vec3 =
  return Vec3(x: x, y: y, z: z)

proc initVec3*(x: float): Vec3 =
  return Vec3(x: x, y: x, z: x)

proc `[]`*(self: Vec3, i: int): float =
  assert(i >= 0 and i < 3, "Vec3's only have 3 components, the index given is invalid")
  case i:
    of 0: return self.x
    of 1: return self.y
    of 2: return self.z
    else: return 0

proc `[]=`*(self: var Vec3, i: int, rightSide: float) =
  assert(i >= 0 and i < 3, "Vec3's only have 3 components, the index given is invalid")
  case i:
    of 0: self.x = rightSide
    of 1: self.y = rightSide
    of 2: self.z = rightSide
    else: discard

proc `+`*(self: Vec3, other: Vec3): Vec3 =
  return Vec3(x: self.x + other.x, y: self.y + other.y, z: self.z + other.z)

proc `-`*(self: Vec3, other: Vec3): Vec3 =
  return Vec3(x: self.x - other.x, y: self.y - other.y, z: self.z - other.z)

proc `*`*(self: Vec3, scale: float): Vec3 =
  return Vec3(x: self.x * scale, y: self.y * scale, z: self.z * scale)

proc `-`*(self: Vec3): Vec3 =
  return self * -1

proc dot*(self: Vec3, other: Vec3): float =
  return self.x*other.x + self.y*other.y + self.z*other.z

proc lengthSq*(self: Vec3): float =
  return self.dot(self)

proc length*(self: Vec3): float =
  return sqrt(self.dot(self))

proc cross*(self: Vec3, other: Vec3): Vec3 =
  return Vec3(
    x: self.y*other.z - self.z*other.y,
    y: self.z*other.x - self.x*other.z,
    z: self.x*other.y - self.y*other.x
  )

proc normalize*(self: Vec3): Vec3 =
  var l = self.length
  if l > 0:
    return self * (1 / self.length)
  else:
    return self

proc multEach*(self: Vec3, other: Vec3): Vec3 =
  result = Vec3(x: self.x*other.x, y: self.y*other.y, z: self.z*other.z)

proc invertEach*(self: Vec3): Vec3 =
  result = Vec3(x: 1/self.x, y: 1/self.y, z: 1/self.z)

proc squareEach*(self: Vec3): Vec3 =
  result = Vec3(x: self.x*self.x, y: self.y*self.y, z: self.z*self.z)

proc lerp*(self: Vec3, other: Vec3, t: float): Vec3 =
  var diff = other - self
  return self + diff * t
