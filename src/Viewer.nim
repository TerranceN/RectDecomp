from sdl2 as sdl import nil

import math
import opengl

import math.vecmath
import util.glPerspective
import util.InputState

import pipeline
import Camera

const KEY_DEBUG = false

var vertShader = """
#version 150

in vec3 a_position;

uniform mat4 u_modelMatrix;
uniform mat4 u_viewMatrix;
uniform mat4 u_projectionMatrix;

out vec3 v_fragCoord;
out vec3 v_viewCoord;

void main() {
    vec4 fragCoord = u_modelMatrix * vec4(a_position, 1.0);
    vec4 viewCoord = u_viewMatrix * fragCoord;

    v_fragCoord = fragCoord.xyz;
    v_viewCoord = viewCoord.xyz;

    gl_Position = u_projectionMatrix * viewCoord;
}
"""

var fragShader = """
#version 150

in vec3 v_fragCoord;
in vec3 v_viewCoord;

uniform mat4 u_modelMatrix;
uniform mat4 u_viewMatrix;

out vec4 gl_FragColor;

void main() {
    vec3 diffuse = vec3(0.8);

    vec3 normal = normalize(cross(dFdx(v_fragCoord), dFdy(v_fragCoord)));
    normal = (inverse(transpose(u_viewMatrix * u_modelMatrix)) * vec4(normal, 1.0)).xyz;
    float intensity = max(0.2, dot(-normalize(v_viewCoord), normalize(normal)));

    gl_FragColor = vec4(intensity * diffuse, 1.0);
}
"""

proc run*(m: Model, v: Voxtree) =
  var window: sdl.WindowPtr = nil
  var runGame = true
  var modelMatrix = identityMat4()
  var projectionMatrix = identityMat4()
  var input = newInputState()
  let targetFramePeriod: uint32 = 17 # 16 milliseconds corresponds to 60 fps

  var screenWidth: cint = 1024
  var screenHeight: cint = 768

  var flatShaderLayout: ShaderDataLayout

  var modelMesh: Mesh

  var mainCamera = initCamera()
  mainCamera.position = initVec3(0, 0, -1)

  var mouseDown = false

  proc reshape(newWidth: cint, newHeight: cint) =
    var screenWidth = newWidth
    var screenHeight = newHeight
    glViewport(0, 0, screenWidth, screenHeight)
    projectionMatrix = glPerspective(PI/4, float(screenWidth)/float(screenHeight), 0.001, 1000.0)

  proc initGL() =
    discard sdl.glCreateContext(window)
    # Initialize OpenGL
    loadExtensions()
    glClearColor(0.0, 0.0, 0.0, 1.0)
    glEnable(GL_DEPTH_TEST)
    glShadeModel(GL_SMOOTH)
    glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST)
    glEnableClientState(GL_VERTEX_ARRAY)
    glEnable(GL_CULL_FACE)
    glCullFace(GL_BACK)
    discard sdl.glSetSwapInterval(0)
    reshape(screenWidth, screenHeight)

  proc loadGLData() =
    # load shaders to render gl data
    flatShaderLayout = initShaderDataLayout(loadProgramFromStrings(vertShader, fragShader), @[
      Attribute(name: "a_position", size: 3, attribType: cGL_FLOAT)
    ])
    modelMesh = getMeshFromModel(m, flatShaderLayout)
    # convert the models data into gl buffers to be rendered in the main loop
    discard

  proc handleEvents() =
    var evt = sdl.defaultEvent
    while sdl.pollEvent(evt).bool:
      input.handleEvent(evt)
      if evt.kind == sdl.MouseButtonDown:
        var mouseDownEvent = cast[sdl.MouseButtonEventPtr](addr(evt))
        if mouseDownEvent.button == 1:
          mouseDown = true
          discard sdl.setRelativeMouseMode(sdl.Bool32(true))
      if evt.kind == sdl.MouseButtonUp:
        var mouseUpEvent = cast[sdl.MouseButtonEventPtr](addr(evt))
        if mouseUpEvent.button == 1:
          mouseDown = false
          discard sdl.setRelativeMouseMode(sdl.Bool32(false))
      if evt.kind == sdl.MouseMotion:
        var motionEvent = cast[sdl.MouseMotionEventPtr](addr(evt))
        if mouseDown:
          mainCamera.handleMouseMovement(motionEvent.xrel, motionEvent.yrel)
      if evt.kind == sdl.QuitEvent:
        runGame = false
        break
      if evt.kind == sdl.KeyDown:
        var keydownEvent = cast[sdl.KeyboardEventPtr](addr(evt))
        if keydownEvent.keysym.scancode == sdl.SDL_SCANCODE_ESCAPE:
          runGame = false
        if KEY_DEBUG:
          echo("Down")
          echo(keydownEvent.keysym)
      if evt.kind == sdl.KeyUp:
        var keyupEvent = cast[sdl.KeyboardEventPtr](addr(evt))
        if KEY_DEBUG:
          echo("Up")
          echo(keyupEvent.keysym)
      if evt.kind == sdl.WindowEvent:
        var windowEvent = cast[sdl.WindowEventPtr](addr(evt))
        if windowEvent.event == sdl.WindowEvent_Resized:
          let newWidth = windowEvent.data1
          let newHeight = windowEvent.data2
          reshape(newWidth, newHeight)


  proc update(dt: float) =
    mainCamera.update(initVec3(0, 0, 0), 5.0)
    mainCamera.lookAt(initVec3(0, 0, 0), initVec3(0, 1, 0))
    #mainCamera.matrix.print()

  proc draw() =
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
    flatShaderLayout.use()
    flatShaderLayout.loadMatrix("u_modelMatrix", identityMat4())
    flatShaderLayout.loadMatrix("u_viewMatrix", mainCamera.matrix)
    flatShaderLayout.loadMatrix("u_projectionMatrix", projectionMatrix)
    modelMesh.render()
    sdl.glSwapWindow(window)

  discard sdl.init(sdl.INIT_EVERYTHING)
  window = sdl.createWindow(
    "SDL/OpenGL Skeleton",
    100,
    100,
    screenWidth,
    screenHeight,
    int(sdl.SDL_WINDOW_OPENGL) or int(sdl.SDL_WINDOW_RESIZABLE)
  )
  initGL()
  loadGLData()
  var timeElapsed = int(targetFramePeriod)
  while runGame:
    let start = sdl.getTicks()
    handleEvents()
    update(float(timeElapsed)/1000)
    draw()
    timeElapsed = int(sdl.getTicks())-int(start)
    #limitFrameRate(uint32(int(sdl.getTicks())-int(start)))
    # flush input for debugging
    flushFile(stdout)
  sdl.destroy window

