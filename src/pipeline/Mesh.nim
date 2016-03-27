import opengl
import strutils
import sequtils

import math
import math.vecmath

import ShaderProgram
import ShaderDataLayout
import Model
import Voxtree

const INDEX_DATA_SIZE* = 3

type
  Mesh* = object
    numFaces*: int
    vertexData*: seq[float32]
    vertexBuffer: GLuint
    vertexDataSize*: int
    indexData*: seq[int32]
    indexDataSize*: int
    indexBuffer: GLuint
    arrayBuffer: GLuint

proc bindBuffers*(m: Mesh) =
  glBindBuffer(GL_ARRAY_BUFFER, m.vertexBuffer)
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, m.indexBuffer)

proc genVAO*(self: var Mesh, layout: ShaderDataLayout, extra: proc() = nil) =
  self.arrayBuffer = GLuint(0)
  glGenVertexArrays(1, addr self.arrayBuffer)
  glBindVertexArray(self.arrayBuffer)
  self.bindBuffers()
  layout.assignAttribPointers()
  if extra != nil:
    extra()
  glBindVertexArray(0)

proc initMesh*(vertices: var seq[float32], indices: var seq[int32], layout: ShaderDataLayout): Mesh =
  var vertexBuffer = GLuint(0)
  glGenBuffers(1, addr vertexBuffer)
  glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer)
  glBufferData(GL_ARRAY_BUFFER, GLsizeiptr(vertices.len() * sizeof(float32)), addr vertices[0], GL_STATIC_DRAW)
  var indexBuffer = GLuint(0)
  glGenBuffers(1, addr indexBuffer)
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer)
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, GLsizeiptr(indices.len() * sizeof(int32)), addr indices[0], GL_STATIC_DRAW)
  result = Mesh(
    numFaces: int(indices.len() / INDEX_DATA_SIZE),
    vertexData: vertices,
    vertexDataSize: layout.vertexSize,
    vertexBuffer: vertexBuffer,
    indexData: indices,
    indexDataSize: INDEX_DATA_SIZE,
    indexBuffer: indexBuffer
  )
  result.genVAO(layout)

proc bindArrayBuffer*(m: Mesh) =
  glBindVertexArray(m.arrayBuffer)

proc render*(m: Mesh) =
  m.bindArrayBuffer()
  glDrawElements(GLenum(GL_TRIANGLES), GLsizei(m.numFaces * INDEX_DATA_SIZE), GLenum(GL_UNSIGNED_INT), cast[pointer](0))
  glBindVertexArray(0)

proc getMeshFromModel*(m: Model, layout: ShaderDataLayout): Mesh =
  var vertexData = newSeq[float32](m.vertices.len*layout.vertexSize)
  for i in 0..m.vertices.len-1:
    for j in 0..2:
      vertexData[i*layout.vertexSize+j] = m.vertices[i][j]
  var indexData = newSeq[int32]()
  for face in m.faces:
    var vertexIndices = face.map(proc(f: FaceVertex): int = f[0])
    for i in 0..2:
      indexData.add(int32(vertexIndices[i]))
    if vertexIndices.len == 4:
      for i in 0..2:
        indexData.add(int32(vertexIndices[(i+2) mod 4]))
  result = initMesh(vertexData, indexData, layout)

proc getMeshFromVoxtree*(v: Voxtree, layout: ShaderDataLayout): Mesh =
  var vertexData = newSeq[float32]()
  var indexData = newSeq[int32]()
  proc meshifyVoxNode(node: int) =
    var children = v.nodeChildren(node)
    if children.len == 0:
      if v[node]:
        var baseIndex = int(vertexData.len / 3)
        # add vertices
        var lower = v.nodeLower(node)
        var size = v.nodeSize(node)
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
        for vertex in boxVertices:
          for i in 0..2:
            vertexData.add(float32(vertex[i]))
        # add faces
        for i in @[
          # left face
          0, 1, 3,
          3, 2, 0,

          # right face
          4, 6, 7,
          7, 5, 4,

          # front face
          0, 2, 6,
          6, 4, 0,
          
          # back face
          1, 5, 7,
          7, 3, 1,

          # top face
          0, 4, 5,
          5, 1, 0,

          # bottom face
          2, 3, 7,
          7, 6, 2
          ]:
          indexData.add(int32(baseIndex+i))
    else:
      for child in children:
        meshifyVoxNode(child)
  meshifyVoxNode(0)
  echo($vertexData.len)
  echo($indexData.len)
  result = initMesh(vertexData, indexData, layout)
