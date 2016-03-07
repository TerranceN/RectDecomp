import sequtils
import opengl
import ShaderProgram

import math.vecmath

type
  Attribute* = object
    name*: string
    size*: int
    attribType*: GLenum
  AttribLayout = object
    index*: GLuint
    size*: int
    attribType*: GLenum
    stride*: int
    offset*: int
  ShaderDataLayout* = object
    shader*: ShaderProgram
    attribs*: seq[AttribLayout]
    vertexSize*: int

proc initShaderDataLayout*(shader: ShaderProgram, attribs: seq[Attribute]): ShaderDataLayout =
  var vertexSize = 0
  var stride = 0
  for attrib in attribs.items:
    vertexSize += attrib.size
    stride += attrib.size * sizeof(attrib.attribType)
  var sizeSoFar = 0
  var layouts = attribs.map(proc (x: Attribute): AttribLayout =
    result = AttribLayout(
      index: Gluint(glGetAttribLocation(shader, x.name)),
      size: x.size,
      attribType: x.attribType,
      stride: stride,
      offset: sizeSoFar
    )
    sizeSoFar += x.size * sizeof(x.attribType)
  )
  result = ShaderDataLayout(
    shader: shader,
    attribs: layouts,
    vertexSize: vertexSize
  )

proc assignAttribPointers*(s: ShaderDataLayout) =
  for attrib in s.attribs.items:
    glEnableVertexAttribArray(attrib.index)
    glVertexAttribPointer(
      attrib.index,
      GLint(attrib.size),
      attrib.attribType,
      false,
      GLsizei(attrib.stride),
      cast[pointer](attrib.offset)
    )

proc unassignAttribPointers*(s: ShaderDataLayout) =
  for attrib in s.attribs.items:
    glDisableVertexAttribArray(attrib.index)

proc use*(s: ShaderDataLayout) =
  s.shader.use()

proc loadMatrix*(l: ShaderDataLayout, name: string, matrix: Mat4) =
  var tmp = matrix.getTransposedFloat32Data()
  glUniformMatrix4fv(
    glGetUniformLocation(l.shader, name),
    GLsizei(1),
    GLboolean(GL_FALSE),
    #addr data[0]
    (ptr GLfloat)(addr tmp[0])
  )
