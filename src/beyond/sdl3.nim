## SDL3 Bindings

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
proc SDL_RenderFillRect*(renderer: SDL_Renderer, rect: ptr SDL_FRect): cint {.importc, cdecl.}
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
