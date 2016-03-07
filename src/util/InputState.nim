from sdl2 as sdl import nil

import sets
import strutils

type
  InputState* = object
    keysPressed: HashSet[int]
    keysJustPressed: HashSet[int]

proc newInputState*(): InputState =
  result = InputState(
    keysPressed: initSet[int](),
    keysJustPressed: initSet[int]()
  )

proc handleEvent*(input: var InputState, evt: var sdl.Event) =
  if evt.kind == sdl.KeyDown:
    var keydownEvent = cast[sdl.KeyboardEventPtr](addr(evt))
    input.keysPressed.incl(keydownEvent.keysym.sym)
    input.keysJustPressed.incl(keydownEvent.keysym.sym)
  elif evt.kind == sdl.KeyUp:
    var keydownEvent = cast[sdl.KeyboardEventPtr](addr(evt))
    input.keysPressed.excl(keydownEvent.keysym.sym)

proc keyDown*(input: InputState, key: int): bool =
  result = input.keysPressed.contains(key)

proc keyDown*(input: InputState, key: sdl.ScanCode): bool =
  result = input.keyDown(sdl.getKeyFromScancode(key))

proc keyDownOnce*(input: var InputState, key: int): bool =
  result = input.keysJustPressed.contains(key)
  if result:
    input.keysJustPressed.excl(key)

proc keyDownOnce*(input: var InputState, key: sdl.ScanCode): bool =
  result = input.keyDownOnce(sdl.getKeyFromScancode(key))
