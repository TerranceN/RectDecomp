import opengl
import math
import math.vecmath

import Mesh
import ShaderDataLayout
import Voxtree
import RectDecomp

type
  InstancedMesh* = object
    mesh: Mesh
    positionIndex: int
    sizeIndex: int
    positionBuffer: GLuint
    sizeBuffer: GLuint
    numPositions: int
    numSizes: int

proc genVAO*(self: var InstancedMesh, layout: ShaderDataLayout, extra: proc() = nil) =
  self.positionIndex = glGetAttribLocation(layout.shader, "a_instancePosition")
  self.sizeIndex = glGetAttribLocation(layout.shader, "a_instanceScale")
  var safeSelf = self
  if self.positionIndex >= 0:
    self.mesh.genVAO(layout) do ():
      block:
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
      block:
        glBindBuffer(GL_ARRAY_BUFFER, safeSelf.sizeBuffer)
        glEnableVertexAttribArray(GLuint(safeSelf.sizeIndex))
        glVertexAttribPointer(
          GLuint(safeSelf.sizeIndex),
          3,
          cGL_FLOAT,
          false,
          3*sizeof(float32),
          cast[pointer](0)
        )
        glVertexAttribDivisor(GLuint(safeSelf.sizeIndex), GLuint(safeSelf.numPositions div safeSelf.numSizes))

proc renderHalf*(self: InstancedMesh) =
  self.mesh.bindArrayBuffer()
  glDrawElementsInstanced(GLenum(GL_TRIANGLES), GLsizei(self.mesh.numFaces * INDEX_DATA_SIZE), GLenum(GL_UNSIGNED_INT), cast[pointer](0), GLsizei(ceil(self.numPositions / 2)))
  glBindVertexArray(0)

proc render*(self: InstancedMesh) =
  self.mesh.bindArrayBuffer()
  glDrawElementsInstanced(GLenum(GL_TRIANGLES), GLsizei(self.mesh.numFaces * INDEX_DATA_SIZE), GLenum(GL_UNSIGNED_INT), cast[pointer](0), GLsizei(self.numPositions))
  glBindVertexArray(0)

proc initInstancedMesh*(m: Mesh, positions: seq[Vec3], sizes: seq[Vec3], layout: ShaderDataLayout): InstancedMesh =
  var positionData = newSeq[float32](3*positions.len)
  var sizeData = newSeq[float32](3*sizes.len)

  # init position data
  var positionBuffer = GLuint(0)
  block:
    var baseIndex = 0
    for p in positions:
      positionData[baseIndex+0] = p.x
      positionData[baseIndex+1] = p.y
      positionData[baseIndex+2] = p.z
      baseIndex += 3
    glGenBuffers(1, addr positionBuffer)
    glBindBuffer(GL_ARRAY_BUFFER, positionBuffer)
    glBufferData(GL_ARRAY_BUFFER, GLsizeiptr(positionData.len() * sizeof(float32)), addr positionData[0], GL_STATIC_DRAW)

  # init size data
  var sizeBuffer = GLuint(0)
  block:
    var baseIndex = 0
    for s in sizes:
      sizeData[baseIndex+0] = s.x
      sizeData[baseIndex+1] = s.y
      sizeData[baseIndex+2] = s.z
      baseIndex += 3
    glGenBuffers(1, addr sizeBuffer)
    glBindBuffer(GL_ARRAY_BUFFER, sizeBuffer)
    glBufferData(GL_ARRAY_BUFFER, GLsizeiptr(sizeData.len() * sizeof(float32)), addr sizeData[0], GL_STATIC_DRAW)

  result = InstancedMesh(
    mesh: m,
    positionIndex: -1,
    sizeIndex: -1,
    positionBuffer: positionBuffer,
    sizeBuffer: sizeBuffer,
    numPositions: positions.len,
    numSizes: sizes.len
  )
  result.genVAO(layout)

proc initInstancedMesh*(m: Mesh, positions: seq[Vec3], layout: ShaderDataLayout): InstancedMesh =
  result = m.initInstancedMesh(positions, @[initVec3(1, 1, 1)], layout)

proc initInstancedMesh*(m: Mesh, positions: seq[Vec3], size: Vec3, layout: ShaderDataLayout): InstancedMesh =
  result = m.initInstancedMesh(positions, @[size], layout)

proc cubeMesh(layout: ShaderDataLayout): Mesh =
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
  proc meshifyVoxNode(node: int) =
    var children = v.childrenOf(node)
    if v[node]:
      if children.len == 0:
        var lower = v.realLowerOf(node)
        var size = v.realSizeOf(node)
        positions.add(lower + initVec3(size)*0.5)
      else:
        for child in children:
          meshifyVoxNode(child)
  meshifyVoxNode(0)
  result = initInstancedMesh(cubeMesh(layout), positions, initVec3(v.voxelSize), layout)

proc getInstancedMeshFromRectDecomp*(r: RectDecomp, layout: ShaderDataLayout): InstancedMesh =
  var positions = newSeq[Vec3]()
  var sizes = newSeq[Vec3]()
  for rect in r:
    var (lower, size) = rect
    positions.add(lower + size*0.5)
    sizes.add(size)
  result = initInstancedMesh(cubeMesh(layout), positions, sizes, layout)
