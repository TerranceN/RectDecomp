import opengl
import strutils
import sequtils

import math.vecmath

import ShaderProgram
import ShaderDataLayout
import Model

const INDEX_DATA_SIZE = 3

type
  Mesh* = object
    numFaces*: int
    vertexData*: seq[float32]
    vertexBuffer: GLuint
    vertexDataSize*: int
    indexData*: seq[int16]
    indexDataSize*: int
    indexBuffer: GLuint
    arrayBuffer: GLuint

proc bindBuffers*(m: Mesh) =
  glBindBuffer(GL_ARRAY_BUFFER, m.vertexBuffer)
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, m.indexBuffer)

proc genVAO*(self: Mesh, layout: ShaderDataLayout): GLuint =
  result = GLuint(0)
  glGenVertexArrays(1, addr result)
  glBindVertexArray(result)
  self.bindBuffers()
  layout.assignAttribPointers()
  glBindVertexArray(0)

proc initMesh*(vertices: var seq[float32], indices: var seq[int16], layout: ShaderDataLayout): Mesh =
  var vertexBuffer = GLuint(0)
  glGenBuffers(1, addr vertexBuffer)
  glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer)
  glBufferData(GL_ARRAY_BUFFER, GLsizeiptr(vertices.len() * sizeof(float32)), addr vertices[0], GL_STATIC_DRAW)
  var indexBuffer = GLuint(0)
  glGenBuffers(1, addr indexBuffer)
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer)
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, GLsizeiptr(indices.len() * sizeof(float32)), addr indices[0], GL_STATIC_DRAW)
  result = Mesh(
    numFaces: int(indices.len() / INDEX_DATA_SIZE),
    vertexData: vertices,
    vertexDataSize: layout.vertexSize,
    vertexBuffer: vertexBuffer,
    indexData: indices,
    indexDataSize: INDEX_DATA_SIZE,
    indexBuffer: indexBuffer
  )
  result.arrayBuffer = result.genVAO(layout)

proc render*(m: Mesh) =
  glBindVertexArray(m.arrayBuffer)
  glDrawElements(GLenum(GL_TRIANGLES), GLsizei(m.numFaces * INDEX_DATA_SIZE), GLenum(GL_UNSIGNED_SHORT), cast[pointer](0))
  glBindVertexArray(0)

proc getMeshFromModel*(m: Model, layout: ShaderDataLayout): Mesh =
  var vertexData = newSeq[float32](m.vertices.len*layout.vertexSize)
  for i in 0..m.vertices.len-1:
    for j in 0..2:
      vertexData[i*layout.vertexSize+j] = m.vertices[i][j]
  var indexData = newSeq[int16]()
  for face in m.faces:
    var vertexIndices = face.map(proc(f: FaceVertex): int = f[0])
    for i in 0..2:
      indexData.add(int16(vertexIndices[i]))
    if vertexIndices.len == 4:
      for i in 0..2:
        indexData.add(int16(vertexIndices[(i+2) mod 4]))
  result = initMesh(vertexData, indexData, layout)
