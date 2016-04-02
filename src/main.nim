import os
import streams
import strutils

import pipeline
from Viewer as Viewer import nil
from Viewer import ViewerType

var voxelSize: float = 0.1

var useViewer = false
var viewerType = ViewerType.model

var outputFile = ""

var params = commandLineParams()
if params.len < 1:
  echo("Need a .obj file to process")
  quit 1
else:
  for i in 0..params.len-2:
    var tokens = params[i].split(":")
    case tokens[0]:
      of "--out":
        outputFile = tokens[1]
      of "--voxelSize":
        voxelSize = parseFloat(tokens[1])
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

  echo("Processing $1..." % params[params.len-1])
  var model = loadFirstModel(newFileStream(params[params.len-1], fmRead))
  echo("Done! $1 Faces, $2 Vertices" % [$model.numFaces(), $model.numVertices()])
  var voxels = model.voxelize(voxelSize)
  var rects = voxels.rectDecomp()
  if outputFile != "":
    var stream = newFileStream(outputFile, fmWrite)
    for rect in rects:
      stream.writeLn("$1 $2 $3 $4 $5 $6" % [
        # lower
        $rect[0].x,
        $rect[0].y,
        $rect[0].z,
        # size
        $rect[1].x,
        $rect[1].y,
        $rect[1].z
      ])
  if useViewer:
    Viewer.run(model, voxels, rects, viewerType)
