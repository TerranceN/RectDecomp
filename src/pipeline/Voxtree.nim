import strutils
import sequtils
import tables

import math
import math.vecmath

import Model

type
  Voxtree* = object
    voxNodes*: Table[int, bool]
    voxelSize*: float
    maxDepth*: int
    model*: Model

var baseLevels: seq[int] = @[0]
proc baseLevel(level: int): int =
  if level >= baseLevels.len:
    for i in baseLevels.len..level:
      baseLevels.add(baseLevels[i-1] + 8^(i-1))
  return baseLevels[level]

proc range(lower: int, upper: int): seq[int] =
  var absDiff = abs(lower - upper)
  result = newSeq[int](absDiff)
  var diff = 1
  if lower > upper:
    diff = -1
  var current = lower
  for i in 0..absDiff-1:
    result[i] = current
    current += diff

proc nodeDepth*(tree: VoxTree, node: int): int =
  var base = 0
  var depth = 0
  while (node >= base):
    base = baseLevel(depth+1)
    depth += 1
  result = depth-1

proc nodeChildren*(tree: VoxTree, node: int): seq[int] =
  result = newSeq[int](8)
  var depth = tree.nodeDepth(node)
  if depth == 0:
    return range(1, 9)
  if depth == tree.maxDepth-1:
    return @[]
  var nth = node - baseLevel(depth)
  for i in 0..7:
    result[i] = i + baseLevel(depth+1) + nth*8

proc nodeSize*(tree: VoxTree, node: int): float =
  return tree.voxelSize * float(2^(tree.maxDepth - tree.nodeDepth(node))) / 2

proc nodeParent*(tree: VoxTree, node: int): int =
  var depth = tree.nodeDepth(node)
  var nthChild = (node - baseLevel(depth)) div 8
  return baseLevel(depth-1) + nthChild

proc nodeLower*(tree: VoxTree, node: int): Vec3 =
  var size = tree.nodeSize(node)
  if node == 0:
    return initVec3(-size/2)
  var depth = tree.nodeDepth(node)
  var nthChild = (node - baseLevel(depth)) mod 8
  var topLeft = tree.nodeLower(tree.nodeParent(node)) + initVec3(0)
  var sizeVec = initVec3(0)
  if (0b100 and nthChild) > 0:
    sizeVec.x = size
  if (0b010 and nthChild) > 0:
    sizeVec.y = size
  if (0b001 and nthChild) > 0:
    sizeVec.z = size
  return topLeft + sizeVec

proc `[]`*(tree: VoxTree, index: int): bool =
  try:
    result = tree.voxNodes[index]
  except KeyError:
    result = false

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

  var triNormal = (tri[0]-tri[1]).cross(tri[1]-tri[2]).normalize()
  var triOffset = triNormal.dot(tri[0])
  var (boxMin, boxMax) = minMaxOnAxis(boxVertices, triNormal)
  if (boxMax < triOffset or boxMin > triOffset):
    return false

  var triEdges = @[
    tri[0]-tri[1],
    tri[1]-tri[2],
    tri[2]-tri[0]
  ]

  for i in 0..2:
    for j in 0..2:
        var axis = triEdges[i].cross(boxNormals[j]).normalize()
        if axis.length() > 0:
          var (boxMin, boxMax) = minMaxOnAxis(boxVertices, axis)
          var (triMin, triMax) = minMaxOnAxis(tri, axis)
          if (boxMax <= triMin or boxMin >= triMax):
            #echo()
            #echo(axis)
            #echo((boxMin, boxMax))
            #echo((triMin, triMax))
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

proc voxelizeWithBounds*(m: Model, minCorner: Vec3, maxCorner: Vec3, voxelSize: float): Voxtree =
  var maxSize = voxelSize
  var maxDepth = 1
  var diff = maxCorner - minCorner
  var maxDiff = max(diff.x, diff.y, diff.z)
  while maxSize < maxDiff:
    maxSize *= 2
    maxDepth += 1
  var voxelizeSectionCalls = 0
  echo("Number of voxels: ")
  echo(baseLevel(maxDepth))
  var tree = Voxtree(voxNodes: initTable[int, bool](), voxelSize: voxelSize, maxDepth: maxDepth, model: m)
  proc voxelizeSection(index: int, faces: seq[int], lower: Vec3, size: float) =
    voxelizeSectionCalls += 1
    # figure out which of the parent's faces are in this voxel
    proc faceIntersects(faceId: int): bool =
      result = triOrQuadBoxIntersecion(lower, size, m.faces[faceId].map(proc(x:FaceVertex): Vec3 = m.vertices[x[0]]))
    var newFaces = faces.filter(faceIntersects)
    tree.voxNodes[index] = newFaces.len > 0
    # if we have faces and we're not at the target voxel size, recurse, spliting the area into eight children
    if newFaces.len > 0 and size > voxelSize:
      var children = tree.nodeChildren(index)
      var newSize = size/2
      # process each child and add it
      voxelizeSection(children[0], newFaces, lower + initVec3(0, 0, 0), newSize)
      voxelizeSection(children[1], newFaces, lower + initVec3(0, 0, newSize), newSize)
      voxelizeSection(children[2], newFaces, lower + initVec3(0, newSize, 0), newSize)
      voxelizeSection(children[3], newFaces, lower + initVec3(0, newSize, newSize), newSize)
      voxelizeSection(children[4], newFaces, lower + initVec3(newSize, 0, 0), newSize)
      voxelizeSection(children[5], newFaces, lower + initVec3(newSize, 0, newSize), newSize)
      voxelizeSection(children[6], newFaces, lower + initVec3(newSize, newSize, 0), newSize)
      voxelizeSection(children[7], newFaces, lower + initVec3(newSize, newSize, newSize), newSize)
  voxelizeSection(0, range(0, m.faces.len), initVec3(-maxSize/2), maxSize)
  echo("Voxelizing a model with voxelSize $1! maxSize: $2, maxDepth: $3 calculated for maxDiff: $4" % [$voxelSize, $maxSize, $maxDepth, $maxDiff])
  result = tree
  echo("voxelizeSectionCalls: $1" % $voxelizeSectionCalls)

proc voxelize*(m: Model, voxelSize: float): Voxtree =
  var (minBound, maxBound) = m.getBounds()
  result = m.voxelizeWithBounds(minBound, maxBound, voxelSize)

proc voxelize*(m: Model): Voxtree =
  var (minBound, maxBound) = m.getBounds()
  var diff = maxBound - minBound
  result = m.voxelizeWithBounds(minBound, maxBound, min(diff.x, diff.y, diff.z)/100.0)
