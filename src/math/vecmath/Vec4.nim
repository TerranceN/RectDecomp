import Vec3 as Vec3

type
  Vec4* = object
    w*: float
    x*: float
    y*: float
    z*: float

proc initVec4*(x: float, y: float, z: float, w: float): Vec4 =
  return Vec4(w: w, x: x, y: y, z: z);

proc initVec4*(v: Vec3, w: float): Vec4 =
  return initVec4(v.x, v.y, v.z, w)

proc xyz*(self: Vec4): Vec3 =
  return initVec3(self.x, self.y, self.z)

proc `+`*(self: Vec4, other: Vec4): Vec4 =
  return Vec4(w: self.w + other.w, x: self.x + other.x, y: self.y + other.y, z: self.z + other.z)

proc `-`*(self: Vec4, other: Vec4): Vec4 =
  return Vec4(w: self.w - other.w, x: self.x - other.x, y: self.y - other.y, z: self.z - other.z)

proc `*`*(self: Vec4, scale: float): Vec4 =
  return Vec4(w: self.w * scale, x: self.x * scale, y: self.y * scale, z: self.z * scale)
