import streams
import strutils

import math.vecmath

type
  FaceVertex* = (int, int, int)
  Face* = seq[FaceVertex]
  Model* = object
    vertices*: seq[Vec3]
    texCoords*: seq[Vec3]
    faces*: seq[Face]

proc numVertices*(m: Model): int =
  result = m.vertices.len

proc numFaces*(m: Model): int =
  result = m.faces.len

proc getBounds*(m: Model): (Vec3, Vec3) =
  assert(m.vertices.len > 0, "Getting bounds of an empty object, this should never happen!!!")
  var minCorner = m.vertices[0]
  var maxCorner = m.vertices[0]
  for i in 1..m.vertices.len-1:
    # record minimums
    minCorner.x = min(minCorner.x, m.vertices[i].x)
    minCorner.y = min(minCorner.y, m.vertices[i].y)
    minCorner.z = min(minCorner.z, m.vertices[i].z)
    # record maximums
    maxCorner.x = max(maxCorner.x, m.vertices[i].x)
    maxCorner.y = max(maxCorner.y, m.vertices[i].y)
    maxCorner.z = max(maxCorner.z, m.vertices[i].z)
  result = (minCorner, maxCorner)

proc loadFirstModel*(s: Stream): Model =
  result = Model()
  var line = ""
  result.vertices = newSeq[Vec3]()
  result.texCoords = newSeq[Vec3]()
  result.faces = newSeq[Face]()
  # go until there's an object definition
  while s.readLine(line) and not line.startsWith("o"):
    discard
  # process all the lines
  while s.readLine(line):
    var tokens = line.split(" ")
    case tokens[0]:
      of "v":
        result.vertices.add(initVec3(parseFloat(tokens[1]), parseFloat(tokens[2]), parseFloat(tokens[3])))
      of "f":
        var face = newSeq[FaceVertex]()
        for i in 1..tokens.len-1:
          var indexes = tokens[i].split("/")
          for j in 0..indexes.len-1:
            if indexes[j] == "":
              indexes[j] = "0"
          # these are all -1 because by obj files' indexes are 1-indexed, and 0-indexed is a lot easier to work with
          face.add((parseInt(indexes[0])-1, parseInt(indexes[1])-1, parseInt(indexes[2])-1))
        result.faces.add(face)
