from sdl2 as sdl import nil

import math
import opengl

import math.vecmath
import util.glPerspective
import util.InputState

import pipeline
import Camera

const KEY_DEBUG = false

type
  ViewerType* {.pure.} = enum
    model, voxels, rects
var viewerType = ViewerType.model

var vertShader = """
#version 150

in vec3 a_position;
in vec3 a_instancePosition;
in vec3 a_instanceScale;
in int gl_InstanceID;

uniform mat4 u_modelMatrix;
uniform mat4 u_viewMatrix;
uniform mat4 u_projectionMatrix;

out vec3 v_fragCoord;
out vec3 v_viewCoord;
flat out float v_hue;

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void main() {
    vec4 fragCoord = u_modelMatrix * vec4(a_instanceScale*a_position + a_instancePosition, 1.0);
    vec4 viewCoord = u_viewMatrix * fragCoord;

    v_fragCoord = fragCoord.xyz;
    v_viewCoord = viewCoord.xyz;
    v_hue = sign(gl_InstanceID)*rand(vec2(gl_InstanceID)) + (1-sign(gl_InstanceID))*0.0;

    gl_Position = u_projectionMatrix * viewCoord;
}
"""

var fragShader = """
#version 150

in vec3 v_fragCoord;
in vec3 v_viewCoord;
flat in float v_hue;

uniform mat4 u_modelMatrix;
uniform mat4 u_viewMatrix;
uniform float u_randomColors;

out vec4 gl_FragColor;

vec4 hsv_to_rgb(float h, float s, float v, float a)
{
	float c = v * s;
	h = mod((h * 6.0), 6.0);
	float x = c * (1.0 - abs(mod(h, 2.0) - 1.0));
	vec4 color;

	if (0.0 <= h && h < 1.0) {
		color = vec4(c, x, 0.0, a);
	} else if (1.0 <= h && h < 2.0) {
		color = vec4(x, c, 0.0, a);
	} else if (2.0 <= h && h < 3.0) {
		color = vec4(0.0, c, x, a);
	} else if (3.0 <= h && h < 4.0) {
		color = vec4(0.0, x, c, a);
	} else if (4.0 <= h && h < 5.0) {
		color = vec4(x, 0.0, c, a);
	} else if (5.0 <= h && h < 6.0) {
		color = vec4(c, 0.0, x, a);
	} else {
		color = vec4(0.0, 0.0, 0.0, a);
	}

	color.rgb += v - c;

	return color;
}

void main() {
    vec3 hsv = hsv_to_rgb(v_hue, 1.0, 1.0, 1.0).rgb;
    vec3 grey = vec3(0.8);
    vec3 diffuse = u_randomColors*hsv + (1-u_randomColors)*grey;

    vec3 normal = normalize(cross(dFdx(v_fragCoord), dFdy(v_fragCoord)));
    normal = (inverse(transpose(u_viewMatrix * u_modelMatrix)) * vec4(normal, 1.0)).xyz;
    float intensity = max(0.2, dot(-normalize(v_viewCoord), normalize(normal)));

    gl_FragColor = vec4(intensity * diffuse, 1.0);
}
"""

proc run*(m: Model, v: Voxtree, r: RectDecomp) =
  var window: sdl.WindowPtr = nil
  var runGame = true
  var modelMatrix = identityMat4()
  var projectionMatrix = identityMat4()
  var input = newInputState()
  let targetFramePeriod: uint32 = 17 # 16 milliseconds corresponds to 60 fps

  var screenWidth: cint = 1024
  var screenHeight: cint = 768

  var flatShaderLayout: ShaderDataLayout

  var modelMesh: InstancedMesh
  var voxtreeMesh: InstancedMesh
  var rectMesh: InstancedMesh

  var renderHalf = false
  var randomColors = false

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
    # convert the models data into gl buffers to be rendered in the main loop
    modelMesh = initInstancedMesh(getMeshFromModel(m, flatShaderLayout), @[initVec3(0, 0, 0)], flatShaderLayout)
    voxtreeMesh = getInstancedMeshFromVoxtree(v, flatShaderLayout)
    rectMesh = getInstancedMeshFromRectDecomp(r, flatShaderLayout)

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
        if keyupEvent.keysym.scancode == sdl.SDL_SCANCODE_H:
          renderHalf = not renderHalf
        if keyupEvent.keysym.scancode == sdl.SDL_SCANCODE_C:
          randomColors = not randomColors
        if keyupEvent.keysym.scancode == sdl.SDL_SCANCODE_M:
          if viewerType == ViewerType.rects:
            viewerType = ViewerType.model
          else:
            viewerType = viewerType.succ
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

  proc draw() =
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
    flatShaderLayout.use()
    flatShaderLayout.loadMatrix("u_modelMatrix", identityMat4())
    flatShaderLayout.loadMatrix("u_viewMatrix", mainCamera.matrix)
    flatShaderLayout.loadMatrix("u_projectionMatrix", projectionMatrix)
    case viewerType:
      of ViewerType.model:
        flatShaderLayout.shader.uniform1f("u_randomColors", 0.0)
        modelMesh.render()
      of ViewerType.voxels:
        flatShaderLayout.shader.uniform1f("u_randomColors", if randomColors: 1.0 else: 0.0)
        if renderHalf:
          voxtreeMesh.renderHalf()
        else:
          voxtreeMesh.render()
      of ViewerType.rects:
        flatShaderLayout.shader.uniform1f("u_randomColors", if randomColors: 1.0 else: 0.0)
        if renderHalf:
          rectMesh.renderHalf()
        else:
          rectMesh.render()
      else:
        discard
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

proc run*(m: Model, v: Voxtree, r: RectDecomp, t: ViewerType) =
  viewerType = t
  run(m, v, r)
