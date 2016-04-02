import strutils
import sequtils
import tables
import sets
import times

import math
import math.vecmath

import Model

type
  VoxIndex* = tuple[x: int, y: int, z: int]
  Voxtree* = object
    voxFaces: Table[int, seq[int]]
    voxelSize*: float
    maxDepth*: int
    model*: Model

const XAXIS* = 0b100
const YAXIS* = 0b010
const ZAXIS* = 0b001
const AXES* = [XAXIS, YAXIS, ZAXIS]

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

proc depthOf*(tree: VoxTree, node: int): int =
  var base = 0
  var depth = 0
  while (node >= base):
    base = baseLevel(depth+1)
    depth += 1
  result = depth-1

proc childIndexOf*(tree: VoxTree, node: int, depth: int): int =
  result = (node - baseLevel(depth)) mod 8

proc childIndexOf*(tree: VoxTree, node: int): int =
  var depth = tree.depthOf(node)
  result = tree.childIndexOf(node, depth)

proc childrenOf*(tree: VoxTree, node: int, depth: int): seq[int] =
  result = newSeq[int](8)
  if depth == 0:
    return range(1, 9)
  if depth == tree.maxDepth-1:
    return @[]
  var nth = node - baseLevel(depth)
  for i in 0..7:
    result[i] = i + baseLevel(depth+1) + nth*8

proc childrenOf*(tree: VoxTree, node: int): seq[int] =
  var depth = tree.depthOf(node)
  result = tree.childrenOf(node, depth)

proc indexSizeOf*(tree: VoxTree, node: int): int =
  return 2^(tree.maxDepth - tree.depthOf(node) - 1)

proc realSizeOf*(tree: VoxTree, node: int): float =
  return tree.voxelSize * float(tree.indexSizeOf(node))

proc parentOf*(tree: VoxTree, node: int, depth: int): int =
  var nthChild = (node - baseLevel(depth)) div 8
  return baseLevel(depth-1) + nthChild

proc parentOf*(tree: VoxTree, node: int): int =
  var depth = tree.depthOf(node)
  tree.parentOf(node, depth)

proc indexLowerOf*(tree: Voxtree, node: int): VoxIndex =
  var size = tree.indexSizeOf(node)
  if node == 0:
    return (0, 0, 0)
  var nthChild = tree.childIndexOf(node)
  var topLeft = tree.indexLowerOf(tree.parentOf(node))
  var x, y, z = 0
  if (0b100 and nthChild) > 0:
    x = size
  if (0b010 and nthChild) > 0:
    y = size
  if (0b001 and nthChild) > 0:
    z = size
  return (topLeft.x + x, topLeft.y + y, topLeft.z + z)

proc realLowerOf*(tree: VoxTree, node: int): Vec3 =
  var size = tree.realSizeOf(node)
  if node == 0:
    return initVec3(-size/2)
  var depth = tree.depthOf(node)
  var nthChild = (node - baseLevel(depth)) mod 8
  var topLeft = tree.realLowerOf(tree.parentOf(node))
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
    result = tree.voxFaces.contains(index)
  except KeyError:
    result = false

proc signum(x: float): int =
  if x < 0:
    return -1
  elif x > 0:
    return 1
  else:
    return 0

proc rayrayPolyIntersection(point: Vec3, dir: Vec3, poly: seq[Vec3], output: var float): bool =
  var EPSILON = 0.000001
  var e1 = poly[1] - poly[0]
  var e2 = poly[2] - poly[0]
  var p = dir.cross(e2)
  var det = e1.dot(p)
  if (det > -EPSILON and det < EPSILON):
    return false
  var invDet = 1/det
  var dist = point - poly[0]
  var u = dist.dot(p) * invDet
  if (u < 0.0 or u > 1.0):
    return false
  var q = dist.cross(e1)
  var v = dir.dot(q) * invDet
  if (v < 0.0 or u+v > 1.0):
    return false
  var t = e2.dot(q) * invDet
  if (t > EPSILON):
    output = t
    return true
  else:
    return false

var rayPolyIntersectionTime = 0.0
var rayPolyCallCount = 0
proc rayPolyIntersection(point: Vec3, dir: Vec3, poly: seq[Vec3], output: var float): bool =
  var start = cpuTime()
  result = rayrayPolyIntersection(point, dir, poly, output)
  rayPolyCallCount += 1
  rayPolyIntersectionTime += cpuTime() - start

proc getRayPolyIntersectionTime*(v: Voxtree): float =
  return rayPolyIntersectionTime

proc getRayPolyCallCount*(v: Voxtree): int =
  return rayPolyCallCount

var insideModelCache = initTable[(int, int), seq[float]]()
proc preComputeInsideModel(v: Voxtree) =
  echo("Precompute!")
  var voxelsPerAxis = 2^(v.maxDepth-1)
  var size = voxelsPerAxis
  var offset = initVec3(-float(voxelsPerAxis)*v.voxelSize/2)
  var depth = 0
  var nextNodes = @[(0, (0, 0, 0))]
  var facesTested = initTable[(int, int), HashSet[int]]()
  while nextNodes.len > 0:
    var currentNodes = nextNodes
    nextNodes = @[]
    for nodeAndLower in currentNodes:
      var (node, lower) = nodeAndLower
      var children = v.childrenOf(node, depth)
      if children.len > 0:
        for i in 0..children.len-1:
          if v[children[i]]:
            nextNodes.add((
              children[i], (
                lower[0] + (size div 2)*signum(float(XAXIS and i)),
                lower[1] + (size div 2)*signum(float(YAXIS and i)),
                lower[2] + (size div 2)*signum(float(ZAXIS and i)))))
      else:
        var realLower = initVec3(float(lower[0]), float(lower[1]), float(lower[2]))*v.voxelSize + offset
        var point = realLower + initVec3(v.voxelSize/2)
        point.x = offset.x
        var dir = initVec3(1, 0, 0)
        var index = (lower[1], lower[2])
        for face in v.voxFaces[node]:
          if not (index in facesTested):
            facesTested[index] = initSet[int]()
          if not (face in facesTested[index]):
            facesTested[index].incl(face)
            var t = 0.0
            if rayPolyIntersection(point, dir, v.model.faces[face].map(proc(x:FaceVertex): Vec3 = v.model.vertices[x[0]]), t):
              t = t + point.x
              if not (index in insideModelCache):
                insideModelCache[index] = newSeq[float]()
              var insertIndex = -1
              for i in 0..insideModelCache[index].len-1:
                if t < insideModelCache[index][i]:
                  insertIndex = i
                  break
              if insertIndex >= 0:
                insideModelCache[index].insert(@[t], insertIndex)
              else:
                insideModelCache[index].add(t)
    size = size div 2
    depth = depth+1
  echo("Done!")


proc isisInsideModel*(v: Voxtree, node: int): bool =
  if insideModelCache.len == 0:
    v.preComputeInsideModel()

  var count = 0
  var indexLower = v.indexLowerOf(node)
  var voxelsPerAxis = 2^(v.maxDepth-1)
  var offset = initVec3(-float(voxelsPerAxis)*v.voxelSize/2)
  var realLower = initVec3(float(indexLower[0]), float(indexLower[1]), float(indexLower[2]))*v.voxelSize + offset
  var p = realLower + initVec3(v.voxelSize/2)

  if (indexLower[1], indexLower[2]) in insideModelCache:
    for intersection in insideModelCache[(indexLower[1], indexLower[2])]:
      if p.x > intersection:
        discard
      else:
        count += 1

  return (count mod 2) == 1

var isInsideModelTime = 0.0
proc isInsideModel*(v: Voxtree, node: int): bool =
  var start = cpuTime()
  result = v.isisInsideModel(node)
  isInsideModelTime += cpuTime() - start

proc getIsInsideModelTime*(v: Voxtree): float =
  return isInsideModelTime

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
  echo("Voxelizing...")
  var maxSize = voxelSize
  var maxDepth = 1
  var diff = maxCorner - minCorner
  var maxDiff = max(diff.x, diff.y, diff.z)
  while maxSize < maxDiff:
    maxSize *= 2
    maxDepth += 1
  var voxelizeSectionCalls = 0
  echo("Number of voxels: $1" % $baseLevel(maxDepth))
  var tree = Voxtree(
    voxFaces: initTable[int, seq[int]](),
    voxelSize: voxelSize,
    maxDepth: maxDepth,
    model: m
  )
  proc voxelizeSection(index: int, faces: seq[int], lower: Vec3, size: float) =
    voxelizeSectionCalls += 1
    # figure out which of the parent's faces are in this voxel
    proc faceIntersects(faceId: int): bool =
      result = triOrQuadBoxIntersecion(lower, size, m.faces[faceId].map(proc(x:FaceVertex): Vec3 = m.vertices[x[0]]))
    proc getNormal(face: int): Vec3 =
      var f = m.faces[face]
      var e1 = m.vertices[f[1][0]]-m.vertices[f[0][0]]
      var e2 = m.vertices[f[2][0]]-m.vertices[f[1][0]]
      return e1.cross(e2).normalize()
    proc getNormals(faces: seq[int]): Vec3 =
      var total = initVec3(0)
      for face in faces:
        total = total + getNormal(face)
      return total.normalize()
    var newFaces = faces.filter(faceIntersects)
    if newFaces.len > 0:
      tree.voxFaces[index] = newFaces
      # if we have faces and we're not at the target voxel size, recurse, spliting the area into eight children
      if size > voxelSize:
        var children = tree.childrenOf(index)
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
  echo("Voxelizing with voxelSize: $1, maxSize: $2, maxDepth: $3 calculated for maxDiff: $4" % [$voxelSize, $maxSize, $maxDepth, $maxDiff])
  voxelizeSection(0, range(0, m.faces.len), initVec3(-maxSize/2), maxSize)
  result = tree
  echo("voxelizeSectionCalls: $1" % $voxelizeSectionCalls)
  echo("Done!")

proc voxelize*(m: Model, voxelSize: float): Voxtree =
  var (minBound, maxBound) = m.getBounds()
  result = m.voxelizeWithBounds(minBound, maxBound, voxelSize)

proc voxelize*(m: Model): Voxtree =
  var (minBound, maxBound) = m.getBounds()
  var diff = maxBound - minBound
  result = m.voxelizeWithBounds(minBound, maxBound, min(diff.x, diff.y, diff.z)/100.0)
