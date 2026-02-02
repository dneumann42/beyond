## SDL3 Bindings

import std/[hashes]

{.passL: "-lSDL3".}

type
  SDL_Window* = ptr object
  SDL_Renderer* = ptr object
  SDL_SurfaceFlags* = distinct uint32
  SDL_PixelFormat* = distinct uint32
  
  SDL_Surface* = ptr object
    flags*: SDL_SurfaceFlags
    format*: SDL_PixelFormat
    w*: cint
    h*: cint
    pitch*: cint
    pixels*: pointer
    userdata*: pointer
    locked*: cint
    list_blitmap*: pointer # private
    clip_rect*: SDL_Rect
    map*: pointer           # private, SDL_BlitMap
    refcount*: cint
        
  SDL_Texture* = ptr object
      
  SDL_WindowFlags* = distinct uint32
  SDL_FRect* = object
    x*: cfloat
    y*: cfloat
    w*: cfloat
    h*: cfloat

  SDL_Rect* = object
    x*: cint
    y*: cint
    w*: cint
    h*: cint

  SDL_Color* {.bycopy.} = object
    r*, g*, b*, a*: uint8

  SDL_AppResult* = enum
    SDL_APP_CONTINUE = 0
    SDL_APP_SUCCESS = 1
    SDL_APP_FAILURE = 2

  SDL_EventType* = enum
    SDL_EVENT_QUIT = 0x100
    SDL_EVENT_KEY_DOWN = 0x300
    SDL_EVENT_KEY_UP = 0x301
    SDL_EVENT_GAMEPAD_AXIS_MOTION = 0x650
    SDL_EVENT_GAMEPAD_BUTTON_DOWN = 0x651
    SDL_EVENT_GAMEPAD_BUTTON_UP = 0x652
    SDL_EVENT_GAMEPAD_ADDED = 0x653
    SDL_EVENT_GAMEPAD_REMOVED = 0x654

  SDL_Keycode* = distinct uint32
  SDL_GamepadButton* = distinct uint32

  SDL_KeyboardEvent* = object
    kind*: SDL_EventType
    timestamp*: uint64
    windowID*: uint32
    which*: uint32
    scancode*: uint32
    key*: SDL_Keycode
    mods*: uint16
    raw*: uint16
    down*: bool
    repeat*: bool

  SDL_GamepadButtonEvent* = object
    kind*: SDL_EventType
    timestamp*: uint64
    which*: uint32       # Gamepad instance ID
    button*: SDL_GamepadButton
    down*: bool
    padding1*: uint8
    padding2*: uint8

  SDL_GamepadAxisEvent* = object
    kind*: SDL_EventType
    timestamp*: uint64
    which*: uint32       # Gamepad instance ID
    axis*: uint8         # Axis index
    padding1*: uint8
    padding2*: uint8
    padding3*: uint8
    value*: int16        # Axis value (-32768 to 32767)
    padding4*: uint16

  SDL_GamepadDeviceEvent* = object
    kind*: SDL_EventType
    timestamp*: uint64
    which*: uint32       # Gamepad instance ID

  SDL_Event* {.union.} = object
    kind*: SDL_EventType
    key*: SDL_KeyboardEvent
    gbutton*: SDL_GamepadButtonEvent
    gaxis*: SDL_GamepadAxisEvent
    gdevice*: SDL_GamepadDeviceEvent
    padding: array[128, uint8]

  SDL_AppInit_func* = proc(appstate: ptr pointer, argc: cint, argv: cstringArray): SDL_AppResult {.cdecl.}
  SDL_AppIterate_func* = proc(appstate: pointer): SDL_AppResult {.cdecl.}
  SDL_AppEvent_func* = proc(appstate: pointer, event: ptr SDL_Event): SDL_AppResult {.cdecl.}
  SDL_AppQuit_func* = proc(appstate: pointer, result: SDL_AppResult) {.cdecl.}

const
  SDL_WINDOW_RESIZABLE* = 0x00000020'u32

  # Keycodes - Letters
  SDLK_A* = SDL_Keycode(0x00000061)
  SDLK_B* = SDL_Keycode(0x00000062)
  SDLK_C* = SDL_Keycode(0x00000063)
  SDLK_D* = SDL_Keycode(0x00000064)
  SDLK_E* = SDL_Keycode(0x00000065)
  SDLK_F* = SDL_Keycode(0x00000066)
  SDLK_G* = SDL_Keycode(0x00000067)
  SDLK_H* = SDL_Keycode(0x00000068)
  SDLK_I* = SDL_Keycode(0x00000069)
  SDLK_J* = SDL_Keycode(0x0000006A)
  SDLK_K* = SDL_Keycode(0x0000006B)
  SDLK_L* = SDL_Keycode(0x0000006C)
  SDLK_M* = SDL_Keycode(0x0000006D)
  SDLK_N* = SDL_Keycode(0x0000006E)
  SDLK_O* = SDL_Keycode(0x0000006F)
  SDLK_P* = SDL_Keycode(0x00000070)
  SDLK_Q* = SDL_Keycode(0x00000071)
  SDLK_R* = SDL_Keycode(0x00000072)
  SDLK_S* = SDL_Keycode(0x00000073)
  SDLK_T* = SDL_Keycode(0x00000074)
  SDLK_U* = SDL_Keycode(0x00000075)
  SDLK_V* = SDL_Keycode(0x00000076)
  SDLK_W* = SDL_Keycode(0x00000077)
  SDLK_X* = SDL_Keycode(0x00000078)
  SDLK_Y* = SDL_Keycode(0x00000079)
  SDLK_Z* = SDL_Keycode(0x0000007A)

  # Keycodes - Numbers
  SDLK_0* = SDL_Keycode(0x00000030)
  SDLK_1* = SDL_Keycode(0x00000031)
  SDLK_2* = SDL_Keycode(0x00000032)
  SDLK_3* = SDL_Keycode(0x00000033)
  SDLK_4* = SDL_Keycode(0x00000034)
  SDLK_5* = SDL_Keycode(0x00000035)
  SDLK_6* = SDL_Keycode(0x00000036)
  SDLK_7* = SDL_Keycode(0x00000037)
  SDLK_8* = SDL_Keycode(0x00000038)
  SDLK_9* = SDL_Keycode(0x00000039)

  # Keycodes - Special Keys
  SDLK_SPACE* = SDL_Keycode(0x00000020)
  SDLK_RETURN* = SDL_Keycode(0x0000000D)
  SDLK_ESCAPE* = SDL_Keycode(0x0000001B)
  SDLK_BACKSPACE* = SDL_Keycode(0x00000008)
  SDLK_TAB* = SDL_Keycode(0x00000009)
  SDLK_MINUS* = SDL_Keycode(0x0000002D)
  SDLK_EQUALS* = SDL_Keycode(0x0000003D)
  SDLK_LEFTBRACKET* = SDL_Keycode(0x0000005B)
  SDLK_RIGHTBRACKET* = SDL_Keycode(0x0000005D)
  SDLK_BACKSLASH* = SDL_Keycode(0x0000005C)
  SDLK_SEMICOLON* = SDL_Keycode(0x0000003B)
  SDLK_APOSTROPHE* = SDL_Keycode(0x00000027)
  SDLK_GRAVE* = SDL_Keycode(0x00000060)
  SDLK_COMMA* = SDL_Keycode(0x0000002C)
  SDLK_PERIOD* = SDL_Keycode(0x0000002E)
  SDLK_SLASH* = SDL_Keycode(0x0000002F)

  # Keycodes - Arrow Keys
  SDLK_RIGHT* = SDL_Keycode(0x4000004F)
  SDLK_LEFT* = SDL_Keycode(0x40000050)
  SDLK_DOWN* = SDL_Keycode(0x40000051)
  SDLK_UP* = SDL_Keycode(0x40000052)

  # Keycodes - Function Keys
  SDLK_F1* = SDL_Keycode(0x4000003A)
  SDLK_F2* = SDL_Keycode(0x4000003B)
  SDLK_F3* = SDL_Keycode(0x4000003C)
  SDLK_F4* = SDL_Keycode(0x4000003D)
  SDLK_F5* = SDL_Keycode(0x4000003E)
  SDLK_F6* = SDL_Keycode(0x4000003F)
  SDLK_F7* = SDL_Keycode(0x40000040)
  SDLK_F8* = SDL_Keycode(0x40000041)
  SDLK_F9* = SDL_Keycode(0x40000042)
  SDLK_F10* = SDL_Keycode(0x40000043)
  SDLK_F11* = SDL_Keycode(0x40000044)
  SDLK_F12* = SDL_Keycode(0x40000045)

  # Keycodes - Modifiers
  SDLK_LSHIFT* = SDL_Keycode(0x400000E1)
  SDLK_RSHIFT* = SDL_Keycode(0x400000E5)
  SDLK_LCTRL* = SDL_Keycode(0x400000E0)
  SDLK_RCTRL* = SDL_Keycode(0x400000E4)
  SDLK_LALT* = SDL_Keycode(0x400000E2)
  SDLK_RALT* = SDL_Keycode(0x400000E6)

  # Keycodes - Other
  SDLK_CAPSLOCK* = SDL_Keycode(0x40000039)
  SDLK_DELETE* = SDL_Keycode(0x0000007F)
  SDLK_INSERT* = SDL_Keycode(0x40000049)
  SDLK_HOME* = SDL_Keycode(0x4000004A)
  SDLK_END* = SDL_Keycode(0x4000004D)
  SDLK_PAGEUP* = SDL_Keycode(0x4000004B)
  SDLK_PAGEDOWN* = SDL_Keycode(0x4000004E)

  # Gamepad Buttons
  SDL_GAMEPAD_BUTTON_INVALID* = SDL_GamepadButton(0xFFFFFFFF'u32)
  SDL_GAMEPAD_BUTTON_SOUTH* = SDL_GamepadButton(0)      # A on Xbox, Cross on PlayStation
  SDL_GAMEPAD_BUTTON_EAST* = SDL_GamepadButton(1)       # B on Xbox, Circle on PlayStation
  SDL_GAMEPAD_BUTTON_WEST* = SDL_GamepadButton(2)       # X on Xbox, Square on PlayStation
  SDL_GAMEPAD_BUTTON_NORTH* = SDL_GamepadButton(3)      # Y on Xbox, Triangle on PlayStation
  SDL_GAMEPAD_BUTTON_BACK* = SDL_GamepadButton(4)       # Select, Back, Share
  SDL_GAMEPAD_BUTTON_GUIDE* = SDL_GamepadButton(5)      # Xbox, PS, Home button
  SDL_GAMEPAD_BUTTON_START* = SDL_GamepadButton(6)      # Start, Options
  SDL_GAMEPAD_BUTTON_LEFT_STICK* = SDL_GamepadButton(7) # L3
  SDL_GAMEPAD_BUTTON_RIGHT_STICK* = SDL_GamepadButton(8) # R3
  SDL_GAMEPAD_BUTTON_LEFT_SHOULDER* = SDL_GamepadButton(9) # L1, LB
  SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER* = SDL_GamepadButton(10) # R1, RB
  SDL_GAMEPAD_BUTTON_DPAD_UP* = SDL_GamepadButton(11)
  SDL_GAMEPAD_BUTTON_DPAD_DOWN* = SDL_GamepadButton(12)
  SDL_GAMEPAD_BUTTON_DPAD_LEFT* = SDL_GamepadButton(13)
  SDL_GAMEPAD_BUTTON_DPAD_RIGHT* = SDL_GamepadButton(14)
  SDL_GAMEPAD_BUTTON_MISC1* = SDL_GamepadButton(15)     # Xbox Elite paddle, PS5 touchpad, etc.
  SDL_GAMEPAD_BUTTON_RIGHT_PADDLE1* = SDL_GamepadButton(16)
  SDL_GAMEPAD_BUTTON_LEFT_PADDLE1* = SDL_GamepadButton(17)
  SDL_GAMEPAD_BUTTON_RIGHT_PADDLE2* = SDL_GamepadButton(18)
  SDL_GAMEPAD_BUTTON_LEFT_PADDLE2* = SDL_GamepadButton(19)
  SDL_GAMEPAD_BUTTON_TOUCHPAD* = SDL_GamepadButton(20)
  SDL_GAMEPAD_BUTTON_MISC2* = SDL_GamepadButton(21)
  SDL_GAMEPAD_BUTTON_MISC3* = SDL_GamepadButton(22)
  SDL_GAMEPAD_BUTTON_MISC4* = SDL_GamepadButton(23)
  SDL_GAMEPAD_BUTTON_MISC5* = SDL_GamepadButton(24)
  SDL_GAMEPAD_BUTTON_MISC6* = SDL_GamepadButton(25)
  SDL_GAMEPAD_BUTTON_COUNT* = SDL_GamepadButton(26)

proc `==`*(a, b: SDL_Keycode): bool {.borrow.}
proc `==`*(a, b: SDL_GamepadButton): bool {.borrow.}
proc hash*(s: SDL_Keycode): Hash = s.uint32.hash()
proc hash*(s: SDL_GamepadButton): Hash = s.uint32.hash()

template sdlCall*(blk: untyped) =
  if not bool(blk):
    error "SDL Error: ", SDL_GetError()

proc SDL_SetAppMetadata*(appname: cstring, appversion: cstring, appidentifier: cstring): cint {.importc, cdecl.}
proc SDL_CreateWindow*(title: cstring, w: cint, h: cint, flags: SDL_WindowFlags): SDL_Window {.importc, cdecl.}
proc SDL_DestroyWindow*(window: SDL_Window) {.importc, cdecl.}
proc SDL_CreateRenderer*(window: SDL_Window, name: cstring): SDL_Renderer {.importc, cdecl.}
proc SDL_DestroyRenderer*(renderer: SDL_Renderer) {.importc, cdecl.}
proc SDL_DestroySurface*(surface: SDL_Surface) {.importc, cdecl.}
proc SDL_DestroyTexture*(texture: SDL_Texture) {.importc, cdecl.}

# Render - Drawing Functions
proc SDL_SetRenderDrawColor*(renderer: SDL_Renderer, r: uint8, g: uint8, b: uint8, a: uint8): cint {.importc, cdecl.}
proc SDL_SetRenderDrawColorFloat*(renderer: SDL_Renderer, r: cfloat, g: cfloat, b: cfloat, a: cfloat): cint {.importc, cdecl.}
proc SDL_RenderClear*(renderer: SDL_Renderer): cint {.importc, cdecl.}
proc SDL_RenderPresent*(renderer: SDL_Renderer): cint {.importc, cdecl.}
proc SDL_RenderFillRect*(renderer: SDL_Renderer, rect: ptr SDL_FRect): cint {.importc: "SDL_RenderFillRect", cdecl.}
proc SDL_RenderRect*(renderer: SDL_Renderer, rect: ptr SDL_FRect): cint {.importc, cdecl.}
proc SDL_RenderLine*(renderer: SDL_Renderer, x1: cfloat, y1: cfloat, x2: cfloat, y2: cfloat): cint {.importc, cdecl.}
proc SDL_RenderPoint*(renderer: SDL_Renderer, x: cfloat, y: cfloat): cint {.importc, cdecl.}

proc SDL_RenderTexture*(
  renderer: SDL_Renderer, 
  texture: SDL_Texture, 
  srcrect, dstrect: ptr SDL_FRect
) {.importc, cdecl.}

# Render - Viewport and Scaling
proc SDL_SetRenderScale*(renderer: SDL_Renderer, scaleX: cfloat, scaleY: cfloat): cint {.importc, cdecl.}
proc SDL_GetRenderScale*(renderer: SDL_Renderer, scaleX: ptr cfloat, scaleY: ptr cfloat): cint {.importc, cdecl.}
proc SDL_SetRenderViewport*(renderer: SDL_Renderer, rect: ptr SDL_FRect): cint {.importc, cdecl.}
proc SDL_GetRenderViewport*(renderer: SDL_Renderer, rect: ptr SDL_FRect): cint {.importc, cdecl.}

proc SDL_RenderDebugText*(renderer: SDL_Renderer, x: cfloat, y: cfloat, text: cstring): cint {.importc, cdecl.}

proc SDL_GetError*(): cstring {.importc, cdecl.}
proc SDL_PollEvent*(event: ptr SDL_Event): bool {.importc, cdecl.}
proc SDL_EnterAppMainCallbacks*(argc: cint, argv: cstringArray,
                                appinit_func: SDL_AppInit_func,
                                appiterate_func: SDL_AppIterate_func,
                                appevent_func: SDL_AppEvent_func,
                                appquit_func: SDL_AppQuit_func): cint {.importc, cdecl.}
