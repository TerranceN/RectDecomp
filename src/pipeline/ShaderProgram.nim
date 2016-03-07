import strutils
import opengl

import math.vecmath

type
  ShaderProgram* = GLuint

proc use*(s: ShaderProgram) =
  glUseProgram(s)

proc uniform1i*(s: ShaderProgram, name: string, value: int) =
  glUniform1i(glGetUniformLocation(s, name), GLint(value))

proc uniform1f*(s: ShaderProgram, name: string, value: float) =
  glUniform1f(glGetUniformLocation(s, name), value)

proc uniform3f*(s: ShaderProgram, name: string, value: Vec3) =
  glUniform3f(glGetUniformLocation(s, name), value.x, value.y, value.z)

proc uniformMatrix4fv*(s: ShaderProgram, name: string, values: openarray[Mat4]) =
  var buffer = newSeq[float32](16*values.len)
  var i = 0
  for mat in values:
    var tmpData = mat.getTransposedFloat32Data()
    copyMem(cast[pointer](addr buffer[16*i]), cast[pointer](addr tmpData[0]), 16*sizeof(float32))
    i += 1
  glUniformMatrix4fv(glGetUniformLocation(s, name), GLsizei(values.len), GLboolean(false), cast[ptr GLfloat](addr buffer[0]))

proc linkProgram(vert: GLuint, frag: GLuint): ShaderProgram =
  result = ShaderProgram(glCreateProgram())
  glAttachShader(result, vert)
  glAttachShader(result, frag)
  glLinkProgram(result)
  var status: GLint = 0
  glGetProgramiv(result, GL_LINK_STATUS, addr status)
  if (status == 0):
    echo("Shader linker error!")
    var length = GLint(0)
    glGetProgramiv(result, GL_INFO_LOG_LENGTH, addr length)
    var data: cstring = spaces(length)
    glGetProgramInfoLog(result, length, addr length, data)
    echo(data)

proc loadShaderFromString(contents: string, ty: GLenum): GLuint =
  result = glCreateShader(ty)
  var stringArray: array[1, string] = [contents]
  var fileCString = allocCStringArray(stringArray)
  glShaderSource(result, 1, fileCString, nil)
  glCompileShader(result)
  var status: GLint = 0
  glGetShaderiv(result, GL_COMPILE_STATUS, addr status)
  if (status == 0):
    echo("Shader compilation error!!!")
    var length = GLint(0)
    glGetShaderiv(result, GL_INFO_LOG_LENGTH, addr length)
    var data: cstring = spaces(length)
    glGetShaderInfoLog(result, length, addr length, data)
    echo(data)

proc loadShaderFromFile(fileName: string, ty: GLenum): GLuint =
  result = loadShaderFromString(readFile(fileName).string, ty)
  var status: GLint = 0
  glGetShaderiv(result, GL_COMPILE_STATUS, addr status)
  if (status == 0):
    echo("Shader compilation error in file: $1" % fileName)

proc loadProgramFromStrings*(vert: string, frag: string): ShaderProgram =
  var vert = loadShaderFromString(vert, GL_VERTEX_SHADER)
  var frag = loadShaderFromString(frag, GL_FRAGMENT_SHADER)
  result = linkProgram(vert, frag)

proc loadProgramFromFile*(name: string): ShaderProgram =
  var vert = loadShaderFromFile("$1.vert" % name, GL_VERTEX_SHADER)
  var frag = loadShaderFromFile("$1.frag" % name, GL_FRAGMENT_SHADER)
  result = linkProgram(vert, frag)
  var status: GLint = 0
  glGetProgramiv(result, GL_LINK_STATUS, addr status)
  if (status == 0):
    echo("Shader linker error: $1" % name)
