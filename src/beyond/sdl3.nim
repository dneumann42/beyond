## SDL3 Bindings

{.passL: "-lSDL3".}

type
  SDL_Window* = ptr object
  SDL_Renderer* = ptr object
  SDL_WindowFlags* = distinct uint32

  SDL_AppResult* = enum
    SDL_APP_CONTINUE = 0
    SDL_APP_SUCCESS = 1
    SDL_APP_FAILURE = 2

  SDL_EventType* = enum
    SDL_EVENT_QUIT = 0x100
    SDL_EVENT_KEY_DOWN = 0x300
    SDL_EVENT_KEY_UP = 0x301

  SDL_Keycode* = distinct uint32

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

  SDL_Event* {.union.} = object
    kind*: SDL_EventType
    key*: SDL_KeyboardEvent
    padding: array[128, uint8]

  SDL_AppInit_func* = proc(appstate: ptr pointer, argc: cint, argv: cstringArray): SDL_AppResult {.cdecl.}
  SDL_AppIterate_func* = proc(appstate: pointer): SDL_AppResult {.cdecl.}
  SDL_AppEvent_func* = proc(appstate: pointer, event: ptr SDL_Event): SDL_AppResult {.cdecl.}
  SDL_AppQuit_func* = proc(appstate: pointer, result: SDL_AppResult) {.cdecl.}

const
  SDL_WINDOW_RESIZABLE* = 0x00000020'u32
  SDLK_ESCAPE* = SDL_Keycode(0x0000001B)

proc `==`*(a, b: SDL_Keycode): bool {.borrow.}

proc SDL_SetAppMetadata*(appname: cstring, appversion: cstring, appidentifier: cstring): cint {.importc, cdecl.}
proc SDL_CreateWindow*(title: cstring, w: cint, h: cint, flags: SDL_WindowFlags): SDL_Window {.importc, cdecl.}
proc SDL_DestroyWindow*(window: SDL_Window) {.importc, cdecl.}
proc SDL_CreateRenderer*(window: SDL_Window, name: cstring): SDL_Renderer {.importc, cdecl.}
proc SDL_DestroyRenderer*(renderer: SDL_Renderer) {.importc, cdecl.}
proc SDL_SetRenderDrawColor*(renderer: SDL_Renderer, r: uint8, g: uint8, b: uint8, a: uint8): cint {.importc, cdecl.}
proc SDL_RenderClear*(renderer: SDL_Renderer): cint {.importc, cdecl.}
proc SDL_RenderPresent*(renderer: SDL_Renderer): cint {.importc, cdecl.}
proc SDL_GetError*(): cstring {.importc, cdecl.}
proc SDL_PollEvent*(event: ptr SDL_Event): bool {.importc, cdecl.}
proc SDL_EnterAppMainCallbacks*(argc: cint, argv: cstringArray,
                                appinit_func: SDL_AppInit_func,
                                appiterate_func: SDL_AppIterate_func,
                                appevent_func: SDL_AppEvent_func,
                                appquit_func: SDL_AppQuit_func): cint {.importc, cdecl.}
