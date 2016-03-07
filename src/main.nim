import os
import streams
import strutils

import pipeline
from Viewer as Viewer import nil

type
  ViewerType {.pure.} = enum
    model, voxels, rects
var useViewer = false
var viewerType = ViewerType.model

var params = commandLineParams()
if params.len < 1:
  echo("Need a .obj file to process")
  quit 1
else:
  for i in 0..params.len-2:
    var tokens = params[i].split(":")
    case tokens[0]:
      of "--view":
        useViewer = true
        if tokens.len > 1:
          case tokens[1]:
            of "model":
              viewerType = ViewerType.model
            of "voxels":
              viewerType = ViewerType.voxels
            of "rects":
              viewerType = ViewerType.rects

  echo("Processing $1" % params[params.len-1])
  var model = loadFirstModel(newFileStream(params[params.len-1], fmRead))
  var voxels = model.voxelize(0.01)
  echo("$1 Faces, $2 Vertices" % [$model.numFaces(), $model.numVertices()])
  if useViewer:
    Viewer.run(model, voxels)
