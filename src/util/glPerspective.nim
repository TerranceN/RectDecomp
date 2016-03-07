import math
import math.vecmath.Mat4

proc glPerspective*(fovy: float, aspect: float, near: float, far: float): Mat4 =
  var f = 1/tan(fovy/2)
  var nmf = near - far
  result = Mat4(data: [
    f/aspect, 0.0, 0.0, 0.0,
    0.0, f, 0.0, 0.0,
    0.0, 0.0, (far + near)/nmf, (2*far*near)/nmf,
    0.0, 0.0, -1.0, 0.0
  ])
