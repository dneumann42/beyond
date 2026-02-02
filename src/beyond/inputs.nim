import std/[options, tables, sets]
import sdl3, pretty

export sdl3

type
  AbstractInputAction = ref object of RootObj
    repeat: bool
    repeatDelay = 0.2
    repeatTimer = 0.0
    repeatReady, wasDown: bool

  InputState* = ref object of AbstractInputAction
    key: Option[SDL_Keycode]
    btn: Option[SDL_GamepadButton]

  MouseMode* = enum
    Visible
    HiddenWrap

  Input* = object
    actions: Table[string, InputState]
    pressedKey*, releasedKey*, downKey*: HashSet[SDL_Keycode]

    textInput: string
    mouseMode*: MouseMode = Visible

  ActionBinder* = ref object
    inp: ref Input
    action: string

proc init*(T: typedesc[Input]): T =
  result = T()

proc set*(input: var Input, action: string): ActionBinder {.discardable.} =
  if not input.actions.hasKey(action):
    input.actions[action] = InputState()
  var inp: ref Input
  new(inp)
  inp[] = input
  result = ActionBinder(inp: inp, action: action)

proc key*(input: ActionBinder, key: SDL_Keycode): ActionBinder {.discardable.} =
  result = input
  if result.inp.actions.hasKey(input.action):
    result.inp.actions[input.action].key = some(key)
  else:
    result.inp.actions[input.action] = InputState(key: some(key))

proc pressed*(input: var Input, action: string): bool =
  if not input.actions.contains(action):
    input.actions[action] = InputState()
  var action = input.actions[action]
  let k: Option[SDL_Keycode] = action.key
  if k.isNone:
    return false
  result = input.pressedKey.contains(k.get())

proc down*(input: Input, action: string): bool =
  let key: Option[SDL_Keycode] = input.actions[action].key
  if key.isNone:
    return false
  result = input.downKey.contains(key.get())

