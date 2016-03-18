import opengl
import math.vecmath

import Mesh
import ShaderDataLayout
import Voxtree

type
  InstancedMesh* = object
    mesh: Mesh
    positionIndex: int
    positionBuffer: GLuint
    numPositions: int

proc genVAO*(self: var InstancedMesh, layout: ShaderDataLayout, extra: proc() = nil) =
  self.positionIndex = glGetAttribLocation(layout.shader, "a_instancePosition")
  var safeSelf = self
  if self.positionIndex >= 0:
    self.mesh.genVAO(layout) do ():
      glBindBuffer(GL_ARRAY_BUFFER, safeSelf.positionBuffer)
      glEnableVertexAttribArray(GLuint(safeSelf.positionIndex))
      glVertexAttribPointer(
        GLuint(safeSelf.positionIndex),
        3,
        cGL_FLOAT,
        false,
        3*sizeof(float32),
        cast[pointer](0)
      )
      glVertexAttribDivisor(GLuint(safeSelf.positionIndex), 1)

proc render*(self: InstancedMesh) =
  self.mesh.bindArrayBuffer()
  glDrawElementsInstanced(GLenum(GL_TRIANGLES), GLsizei(self.mesh.numFaces * INDEX_DATA_SIZE), GLenum(GL_UNSIGNED_INT), cast[pointer](0), GLsizei(self.numPositions))
  glBindVertexArray(0)

proc initInstancedMesh*(m: Mesh, positions: seq[Vec3], layout: ShaderDataLayout): InstancedMesh =
  var positionData = newSeq[float32](3*positions.len)
  var baseIndex = 0
  for p in positions:
    positionData[baseIndex+0] = p.x
    positionData[baseIndex+1] = p.y
    positionData[baseIndex+2] = p.z
    baseIndex += 3
  var positionBuffer = GLuint(0)
  glGenBuffers(1, addr positionBuffer)
  glBindBuffer(GL_ARRAY_BUFFER, positionBuffer)
  glBufferData(GL_ARRAY_BUFFER, GLsizeiptr(positionData.len() * sizeof(float32)), addr positionData[0], GL_STATIC_DRAW)
  result = InstancedMesh(
    mesh: m,
    positionIndex: -1,
    positionBuffer: positionBuffer,
    numPositions: positions.len
  )
  result.genVAO(layout)

proc cubeMode(layout: ShaderDataLayout): Mesh = 
  var vertexData = newSeq[float32]()
  var indexData = newSeq[int32]()

  var size = 1.0
  var lower = initVec3(-size) * 0.5

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
    indexData.add(int32(i))
  result = initMesh(vertexData, indexData, layout)

proc getInstancedMeshFromVoxtree*(v: Voxtree, layout: ShaderDataLayout): InstancedMesh =
  var positions = newSeq[Vec3]()
  proc meshifyVoxNode(node: VoxNode) =
    if node.children.len == 0:
      if node.faces.len != 0:
        positions.add(node.lower + initVec3(node.size)*0.5)
    else:
      for child in node.children:
        meshifyVoxNode(child)
  meshifyVoxNode(v.root)
  result = initInstancedMesh(cubeMode(layout), positions, layout)
