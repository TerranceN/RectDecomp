import math
import optional_t

import math.vecmath

type
  Camera* = object
    position*: Vec3
    rotation*: Quat
    targetRotation*: Quat
    matrix*: Mat4

proc initCamera*(): Camera =
  result = Camera(position: initVec3(0, 0, 0), rotation: identityQuat(), targetRotation: identityQuat(), matrix: identityMat4())

proc lookAt*(self: var Camera, look: Vec3, up: Vec3) =
  var f = (look - self.position).normalize()
  var s = f.cross(up).normalize()
  var u = s.cross(f)
  self.matrix = Mat4(data: [
    s.x, s.y, s.z, 0,
    u.x, u.y, u.z, 0,
    -f.x, -f.y, -f.z, 0,
    0, 0, 0, 1
  ]) * translateMat4(-self.position)

proc update*(self: var Camera, target: Vec3, dist: float) =
  self.position = target + (rotateMat4(self.rotation) * initVec4(initVec3(0, 0, dist), 0)).xyz
  var diff = (self.position - target)

proc handleMouseMovement*(self: var Camera, xrel: int, yrel: int) =
  self.rotation = self.rotation.normalize() * axisAngleQuat(initVec3(0, 1, 0), -xrel.float/(160*PI)).normalize()
  self.rotation = self.rotation.normalize() * axisAngleQuat(initVec3(1, 0, 0), -yrel.float/(160*PI)).normalize()
