import strutils
import sequtils

import math.vecmath

import Model

type
  VoxNode = object
    faces: seq[int]
    children: seq[VoxNode]
  Voxtree* = object
    model: Model
    root: VoxNode

proc triangleBoxIntersection(lower: Vec3, size: float, tri: seq[Vec3]): bool =
  # Test triangle box intersection using the separating axis theorem
  # Implementation taken and modified from here: http://stackoverflow.com/a/17503268

  # by default assume there's overlap, and then try to find a separating axis
  result = true

  proc minMaxOnAxis(points: seq[Vec3], axis: Vec3): (float, float) =
    assert(points.len > 0, "need at least one point to find min/max on given axis")
    var minProj = axis.dot(points[0])
    var maxProj = minProj
    for i in 1..points.len-1:
      var proj = axis.dot(points[i])
      if proj < minProj: minProj = proj
      if proj > maxProj: maxProj = proj
    result = (minProj, maxProj)

  var boxNormals = @[
    initVec3(1, 0, 0),
    initVec3(0, 1, 0),
    initVec3(0, 0, 1)
  ]

  for i in 0..boxNormals.len-1:
    var (triMin, triMax) = minMaxOnAxis(tri, boxNormals[i])
    if (triMax < lower[i] or triMin > lower[i]+size):
      return false

  var boxVertices = @[
    lower + initVec3(0, 0, 0),
    lower + initVec3(0, 0, size),
    lower + initVec3(0, size, 0),
    lower + initVec3(0, size, size),
    lower + initVec3(size, 0, 0),
    lower + initVec3(size, 0, size),
    lower + initVec3(size, size, 0),
    lower + initVec3(size, size, size)
  ]

  var triNormal = (tri[1]-tri[0]).cross(tri[2]-tri[1]).normalize()
  var triOffset = triNormal.dot(tri[0])
  var (boxMin, boxMax) = minMaxOnAxis(boxVertices, triNormal)
  if (boxMax < triOffset or boxMin > triOffset):
    return false

  var triEdges = @[
    tri[0]-tri[1],
    tri[1]-tri[2],
    tri[2]-tri[0]
  ]

  for i in 0..3:
    for j in 0..3:
        var axis = triEdges[i].cross(boxNormals[j])
        var (boxMin, boxMax) = minMaxOnAxis(boxVertices, axis)
        var (triMin, triMax) = minMaxOnAxis(tri, axis)
        if (boxMax <= triMin or boxMin >= triMax):
          return false

proc quadBoxIntersection(lower: Vec3, size: float, quad: seq[Vec3]): bool =
  result = triangleBoxIntersection(lower, size, quad[0..2]) or triangleBoxIntersection(lower, size, @[quad[2], quad[3], quad[0]])

proc triOrQuadBoxIntersecion(lower: Vec3, size: float, verts: seq[Vec3]): bool =
  assert(verts.len == 3 or verts.len == 4, "needs to be a tri or quad")
  case verts.len:
    of 3:
      result = triangleBoxIntersection(lower, size, verts)
    of 4:
      result = quadBoxIntersection(lower, size, verts)
    else:
      result = false

proc range(lower: int, upper: int): seq[int] =
  var absDiff = abs(lower - upper)
  result = newSeq[int](absDiff)
  var diff = 1
  if lower > upper:
    diff = -1
  var current = lower
  for i in 0..absDiff-1:
    result[i] = lower
    current += diff

proc voxelizeWithBounds*(m: Model, minCorner: Vec3, maxCorner: Vec3, voxelSize: float): Voxtree =
  var maxSize = voxelSize
  var maxDepth = 1
  var diff = maxCorner - minCorner
  var maxDiff = max(diff.x, diff.y, diff.z)
  while maxSize < maxDiff:
    maxSize *= 2
    maxDepth += 1
  proc voxelizeSection(faces: seq[int], lower: Vec3, size: float): VoxNode =
    #echo("Child with size: $1" % $size)
    result = VoxNode()
    # figure out which of the parent's faces are in this voxel
    proc faceIntersects(faceId: int): bool =
      result = triOrQuadBoxIntersecion(lower, size, m.faces[faceId].map(proc(x:FaceVertex): Vec3 = m.vertices[x[0]]))
    result.faces = faces.filter(faceIntersects)
    # if we have faces and we're not at the target voxel size, recurse, spliting the area into eight children
    if result.faces.len > 0 and size > voxelSize:
      result.children = newSeq[VoxNode]()
      var newSize = size/2
      # process each child and add it
      result.children.add(voxelizeSection(result.faces, lower + initVec3(0, 0, 0), newSize))
      result.children.add(voxelizeSection(result.faces, lower + initVec3(0, newSize, 0), newSize))
      result.children.add(voxelizeSection(result.faces, lower + initVec3(0, newSize, newSize), newSize))
      result.children.add(voxelizeSection(result.faces, lower + initVec3(0, 0, newSize), newSize))
      result.children.add(voxelizeSection(result.faces, lower + initVec3(newSize, 0, 0), newSize))
      result.children.add(voxelizeSection(result.faces, lower + initVec3(newSize, newSize, 0), newSize))
      result.children.add(voxelizeSection(result.faces, lower + initVec3(newSize, newSize, newSize), newSize))
      result.children.add(voxelizeSection(result.faces, lower + initVec3(newSize, 0, newSize), newSize))
  echo("Voxelizing a model with voxelSize $1! maxSize: $2, maxDepth: $3" % [$voxelSize, $maxSize, $maxDepth])
  result = Voxtree(model: m, root: voxelizeSection(range(0, m.faces.len), initVec3(-maxSize/2), maxSize))


proc voxelize*(m: Model, voxelSize: float): Voxtree =
  var (minBound, maxBound) = m.getBounds()
  result = m.voxelizeWithBounds(minBound, maxBound, voxelSize)

proc voxelize*(m: Model): Voxtree =
  var (minBound, maxBound) = m.getBounds()
  var diff = maxBound - minBound
  result = m.voxelizeWithBounds(minBound, maxBound, min(diff.x, diff.y, diff.z)/100.0)
