import strutils

import math
import math.vecmath
import tables
import times

import Voxtree

type
  Rect* = (Vec3, Vec3)
  RectDecomp* = seq[Rect]

proc minusOne(v: Voxtree, node: int, direction: int): int =
  var directionStack = newSeq[int]()
  var current = node
  while (current > 0):
    var nth = v.childIndexOf(current)
    if (nth and direction) > 0:
      var siblings = v.childrenOf(v.parentOf(current))
      var child = siblings[nth and (0b111 xor direction)]
      current = child
      var children = v.childrenOf(current)
      while (directionStack.len > 0):
        var nextDirection = directionStack.pop()
        current = children[nextDirection or direction]
        children = v.childrenOf(current)
      return current
    else:
      directionStack.add(nth)
    current = v.parentOf(current)
  return -1

proc nodeAtIndex(v: Voxtree, index: VoxIndex): int =
  var node = 0
  var children = v.childrenOf(node)
  var size = 2^(v.maxDepth-1)
  var target = index
  while (children.len > 0):
    var nth = 0
    if target.x >= size div 2:
      nth = nth or XAXIS
      target.x -= size div 2
    if target.y >= size div 2:
      nth = nth or YAXIS
      target.y -= size div 2
    if target.z >= size div 2:
      nth = nth or ZAXIS
      target.z -= size div 2
    node = children[nth]
    children = v.childrenOf(node)
    size = size div 2
  result = node

proc plusOne(v: Voxtree, node: int, direction: int): int =
  #v.plusN(node, direction, 1)
  var directionStack = newSeq[int]()
  var current = node
  while (current > 0):
    var nth = v.childIndexOf(current)
    if (nth and direction) == 0:
      var siblings = v.childrenOf(v.parentOf(current))
      var child = siblings[nth or direction]
      current = child
      var children = v.childrenOf(current)
      while (directionStack.len > 0):
        var nextDirection = directionStack.pop()
        current = children[nextDirection and (0b111 xor direction)]
        children = v.childrenOf(current)
      return current
    else:
      directionStack.add(nth)
    current = v.parentOf(current)
  return -1

proc firstInDirWhere(v: Voxtree, node: int, dir: int, s: int, t: int): int =
  result = -1
  var children = v.childrenOf(node)
  if children.len > 0:
    var indexTuple = v.indexLowerOf(node)
    var index = [indexTuple.x, indexTuple.y, indexTuple.z]
    var size = v.indexSizeOf(node)
    var nth = 0
    var sFinished = false
    for i in 0..AXES.len-1:
      var comparison = if not sFinished: s else: t
      if (dir and AXES[i]) == 0:
        if comparison >= index[i] + (size div 2):
          nth = nth or AXES[i]
        sFinished = true
    if v[children[nth]]:
      result = v.firstInDirWhere(children[nth], dir, s, t)
    nth = nth or dir
    if result < 0 and v[children[nth]]:
        result = v.firstInDirWhere(children[nth], dir, s, t)
  else:
    if v[node]:
      result = node

proc firstInDirWhere(v: Voxtree, dir: int, s: int, t: int): int =
  result = v.firstInDirWhere(0, dir, s, t)

proc lastWhere(v: Voxtree, node: int, dir: int, s: int, t: int): int =
  result = -1
  var children = v.childrenOf(node)
  if children.len > 0:
    var indexTuple = v.indexLowerOf(node)
    var index = [indexTuple.x, indexTuple.y, indexTuple.z]
    var size = v.indexSizeOf(node)
    var nth = 0
    var sFinished = false
    for i in 0..AXES.len-1:
      var comparison = if not sFinished: s else: t
      if (dir and AXES[i]) == 0:
        if comparison >= index[i] + (size div 2):
          nth = nth or AXES[i]
        sFinished = true
    nth = nth or dir
    if result < 0:
        result = v.lastWhere(children[nth], dir, s, t)
  else:
    if v[node]:
      result = node

proc lastWhere(v: Voxtree, dir: int, s: int, t: int): int =
  result = v.lastWhere(0, dir, s, t)

proc nextInDir(v: Voxtree, node: int, dir: int): int =
  var index = v.indexLowerOf(node)
  var indexLst = [index.x, index.y, index.z]
  var current = node
  while (current > 0):
    var nth = v.childIndexOf(current)
    if (nth and dir) == 0:
      var siblings = v.childrenOf(v.parentOf(current))
      var child = siblings[nth or dir]
      if v[child]:
        var otherDirs = newSeq[int]()
        for i in 0..AXES.len-1:
          if (AXES[i] and dir) == 0:
            otherDirs.add(indexLst[i])
        var first = v.firstInDirWhere(child, dir, otherDirs[0], otherDirs[1])
        if first >= 0:
          return first
    current = v.parentOf(current)
  return -1

proc rectDecomp*(v: Voxtree): (RectDecomp, seq[(VoxIndex, VoxIndex)]) =
  echo("Decomposing into rectangles...")
  # build jump hashmaps for each direction to speed up box finding
  #
  # follow algorithm here: http://www.montefiore.ulg.ac.be/~pierard/rectangles/
  # Once a rect is found, change the jump maps to remove that rect

  # these hashmaps store, for a given node id, the node id of the next wall
  var nextForAxis = initTable[int, Table[int, int]]()
  var firstForAxis = initTable[int, Table[(int, int), int]]()
  var segForAxis = initTable[int, Table[int, (VoxIndex, int)]]()

  var voxelsPerAxis = 2^(v.maxDepth-1)
  var fifthVoxels = voxelsPerAxis div 20

  var rects = newSeq[Rect]()
  var indexRects = newSeq[(VoxIndex, VoxIndex)]()

  var startTime = cpuTime()

  echo("  Step 1) Precomputing jump hashmaps...")
  for i in 0..AXES.len-1:
    if AXES[i] == XAXIS:
      echo("    Working on XAXIS")
    elif AXES[i] == YAXIS:
      echo("    Working on YAXIS")
    elif AXES[i] == ZAXIS:
      echo("    Working on ZAXIS")
    firstForAxis[AXES[i]] = initTable[(int, int), int]()
    nextForAxis[AXES[i]] = initTable[int, int]()
    segForAxis[AXES[i]] = initTable[int, (VoxIndex, int)]()
    var firsts = addr firstForAxis[AXES[i]]
    var nexts = addr nextForAxis[AXES[i]]
    var segments = addr segForAxis[AXES[i]]
    for y in 0..voxelsPerAxis-1:
      for i in 1..19:
        if (y > i*fifthVoxels) and ((y-1) <= i*fifthVoxels):
          echo("      $1%" % $(i*5))
      for z in 0..voxelsPerAxis-1:
        var start = v.firstInDirWhere(AXES[i], y, z)
        if start >= 0:
          while start != -1:
            var index = v.indexLowerOf(start)
            start = v.plusOne(start, AXES[i])
            if not v[start]:
              if not v.isInsideModel(start):
                start = v.nextInDir(start, AXES[i])
              else:
                break
          if start >= 0:
            firsts[][(y, z)] = start
        var node = start
        while (node != -1):
          var next = v.nextInDir(node, AXES[i])
          if next >= 0:
            var tmp = v.minusOne(next, AXES[i])
            var i1 = v.indexLowerOf(node)
            var i2 = v.indexLowerOf(tmp)
            var diff = 0
            if (AXES[i] and XAXIS) > 0:
              diff = i2.x-i1.x
            if (AXES[i] and YAXIS) > 0:
              diff = i2.y-i1.y
            if (AXES[i] and ZAXIS) > 0:
              diff = i2.z-i1.z
            segments[][node] = (i1, diff)
            while next >= 0:
              next = v.plusOne(next, AXES[i])
              if not v[next]:
                if not v.isInsideModel(next):
                  next = v.nextInDir(next, AXES[i])
                else:
                  break
            if next >= 0:
              nexts[][node] = next
          node = next
  echo("  Done!")

  echo("  Step 2) Generate rectangles")

  #block:
  #  for x in 0..voxelsPerAxis-1:
  #    for y in 0..voxelsPerAxis-1:
  #      for z in 0..voxelsPerAxis-1:
  #        var node = v.nodeAtIndex((x, y, z))
  #        if v.isInsideModel(node):
  #          var startLower = v.realLowerOf(node)
  #          rects.add((startLower, initVec3(v.voxelSize)))

  #block:
  #  var axis = XAXIS
  #  var firsts = addr firstForAxis[axis]
  #  var nexts = addr nextForAxis[axis]
  #  var segments = addr segForAxis[axis]
  #  for y in 0..voxelsPerAxis-1:
  #    for z in 0..voxelsPerAxis-1:
  #      if (y, z) in firsts[]:
  #        var start = firsts[][(y, z)]
  #        while (start >= 0 and start in segments[]):
  #          var seg = segments[][start]
  #          var startLower = v.realLowerOf(start)
  #          var finish = start
  #          var index = seg[0]
  #          if (axis and XAXIS) > 0:
  #            index.x += seg[1]
  #          if (axis and YAXIS) > 0:
  #            index.y += seg[1]
  #          if (axis and ZAXIS) > 0:
  #            index.z += seg[1]
  #          finish = v.nodeAtIndex(index)
  #          var finishLower = v.realLowerOf(finish)
  #          rects.add((startLower, finishLower + initVec3(v.voxelSize) - startLower))
  #          start = if start in nexts[]: nexts[][start] else: -1

  block:
    var finished = false

    while not finished:
      var maxRectIndexLower = (x: 0, y: 0, z: 0)
      var maxRectIndexSize = (x: 0, y: 0, z:0)
      var maxRectLower = initVec3(0)
      var maxRectSize = initVec3(0)
      var maxSize = 0

      finished = true
      for z in 0..voxelsPerAxis-1:
        for y in 0..voxelsPerAxis-1:
          if (y, z) in firstForAxis[XAXIS]:
            var start = firstForAxis[XAXIS][(y, z)]
            while (start >= 0 and start in segForAxis[XAXIS]):
              if (y, z) == (23, 24):
                echo("omgwtfbbq")
              var seg = segForAxis[XAXIS][start]
              var corner = seg[0]
              var zlen = 0
              var ylen = 0
              block:
                var minLen = -1
                for xOffset in 0..seg[1]:
                  var xyIndex = (corner.x+xOffset, y)
                  # TODO: remove
                  if not (xyIndex in firstForAxis[ZAXIS]):
                    break
                  var tmp = firstForAxis[ZAXIS][xyIndex]
                  var seg = segForAxis[ZAXIS][tmp]
                  var last = tmp
                  while tmp >= 0 and seg[0].z < corner.z:
                    last = tmp
                    tmp = if tmp in nextForAxis[ZAXIS]: nextForAxis[ZAXIS][tmp] else: -1
                    if tmp in segForAxis[ZAXIS]:
                      seg = segForAxis[ZAXIS][tmp]
                  seg = segForAxis[ZAXIS][last]
                  var zlen = seg[0].z + seg[1] - corner.z
                  if minLen == -1 or zlen < minLen:
                    minLen = zlen
                zlen = minLen
              block:
                var minLen = -1
                for xOffset in 0..seg[1]:
                  for zOffset in 0..zlen:
                    var xzIndex = (corner.x+xOffset, z+zOffset)
                    # TODO: remove
                    if not (xzIndex in firstForAxis[YAXIS]):
                      break
                    var tmp = firstForAxis[YAXIS][xzIndex]
                    var seg = segForAxis[YAXIS][tmp]
                    var last = tmp
                    while tmp >= 0 and seg[0].y < corner.y:
                      last = tmp
                      tmp = if tmp in nextForAxis[YAXIS]: nextForAxis[YAXIS][tmp] else: -1
                      if tmp in segForAxis[YAXIS]:
                        seg = segForAxis[YAXIS][tmp]
                    seg = segForAxis[YAXIS][last]
                    var ylen = seg[0].y + seg[1] - corner.y
                    if minLen == -1 or ylen < minLen:
                      minLen = ylen
                ylen = minLen
              var rectSize = (seg[1]+1)*(ylen+1)*(zlen+1)
              if rectSize > maxSize:
                finished = false
                maxSize = rectSize
                var finish = v.nodeAtIndex((corner.x+seg[1], corner.y+ylen, corner.z+zlen))
                var finishLower = v.realLowerOf(finish)
                maxRectLower = v.realLowerOf(start)
                maxRectSize = finishLower + initVec3(v.voxelSize) - maxRectLower
                maxRectIndexLower = corner
                maxRectIndexSize = (seg[1], ylen, zlen)
              start = if start in nextForAxis[XAXIS]: nextForAxis[XAXIS][start] else: -1
      if not finished:
        echo("    Rekt: ($1, $2)" % [$maxRectLower, $maxRectSize])
        rects.add((maxRectLower, maxRectSize))
        indexRects.add((maxRectIndexLower, maxRectIndexSize))
        # remove rect from scene by updating first and next hashmaps
        var indexSizeLst = [maxRectIndexSize[0], maxRectIndexSize[1], maxRectIndexSize[2]]
        var indexLowerLst = [maxRectIndexLower[0], maxRectIndexLower[1], maxRectIndexLower[2]]
        for i in 0..AXES.len-1:
          var otherAxes = newSeq[int]()
          for j in 0..AXES.len-1:
            if i != j:
              otherAxes.add(j)
          for yOffset in 0..indexSizeLst[otherAxes[0]]:
            for zOffset in 0..indexSizeLst[otherAxes[1]]:
              var yzIndex = (indexLowerLst[otherAxes[0]] + yOffset, indexLowerLst[otherAxes[1]] + zOffset)
              var first = firstForAxis[AXES[i]][yzIndex]
              var node = first
              var prev = node
              var seg = segForAxis[AXES[i]][node]
              var lowerLst = [seg[0].x, seg[0].y, seg[0].z]
              while node >= 0 and indexLowerLst[i] > lowerLst[i] + seg[1]:
                prev = node
                node = if node in nextForAxis[AXES[i]]: nextForAxis[AXES[i]][node] else: -1
                if node in segForAxis[AXES[i]]:
                  seg = segForAxis[AXES[i]][node]
                  lowerLst = [seg[0].x, seg[0].y, seg[0].z]
              if indexLowerLst[i]+indexSizeLst[i] != lowerLst[i] + seg[1]:
                # add a segment that fills the gap
                var next = if node in nextForAxis[AXES[i]]: nextForAxis[AXES[i]][node] else: -1
                var indexLst = [0, 0, 0]
                var size = (lowerLst[i] + seg[1]) - (indexLowerLst[i] + indexSizeLst[i]) - 1
                for j in 0..AXES.len-1:
                  if i == j:
                    indexLst[j] = indexLowerLst[i]+indexSizeLst[i]+1
                  else:
                    indexLst[j] = lowerLst[j]
                var index = (indexLst[0], indexLst[1], indexLst[2])
                var start = v.nodeAtIndex(index)
                nextForAxis[AXES[i]][node] = start
                if next >= 0:
                  nextForAxis[AXES[i]][start] = next
                segForAxis[AXES[i]][start] = (index, size)
              if indexLowerLst[i] != lowerLst[i]:
                # doesn't touch front edge, make this segment smaller
                segForAxis[AXES[i]][node][1] = indexLowerLst[i] - lowerLst[i] - 1
              else:
                # touches front edge, so remove this segment
                if node == first:
                  if node in nextForAxis[AXES[i]]:
                    firstForAxis[AXES[i]][yzIndex] = nextForAxis[AXES[i]][node]
                  else:
                    firstForAxis[AXES[i]].del(yzIndex)
                else:
                  if node in nextForAxis[AXES[i]]:
                    nextForAxis[AXES[i]][prev] = nextForAxis[AXES[i]][node]
                  else:
                    nextForAxis[AXES[i]].del(node)

  echo("  Done!")

  echo("Done!")
  var totalTime = cpuTime() - startTime
  echo("Total intersection test time: $1/$2" % [$v.getIsInsideModelTime(), $totalTime])
  echo("Ray poly intersection test time: $1/$2" % [$v.getRayPolyIntersectionTime(), $totalTime])
  echo("Ray poly intersection test call count: $1" % $v.getRayPolyCallCount())
  echo(rects.len)
  result = (rects, indexRects)
