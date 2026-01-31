import sdl3
import log, plugins

export log

{.push raises: [].}

type
  AppState*[T] = object
    config: AppConfig
    window: SDL_Window
    renderer: SDL_Renderer
    pluginStates: PluginStates
    state*: T

  AppConfig* = object
    appId*: string
    title*: string
    width*, height*: int

template generateApplication[T](cfg: AppConfig, initialState: T): auto =
  var gAppState {.global.}: ptr AppState[T]

  proc SDL_AppInit(appstate: ptr pointer, argc: cint, argv: cstringArray): SDL_AppResult {.cdecl, gcsafe.} =
    appstate[] = gAppState

    discard SDL_SetAppMetadata(gAppState.config.title.cstring, "1.0", gAppState.config.appId.cstring)

    let window = SDL_CreateWindow(gAppState.config.title.cstring, gAppState.config.width.cint, gAppState.config.height.cint, SDL_WindowFlags(SDL_WINDOW_RESIZABLE))
    if window.isNil:
      info "Failed to create window: ", SDL_GetError()
      return SDL_APP_FAILURE

    let renderer = SDL_CreateRenderer(window, nil)
    if renderer.isNil:
      SDL_DestroyWindow(window)
      info "Failed to create renderer: ", SDL_GetError()
      return SDL_APP_FAILURE

    gAppState.window = window
    gAppState.renderer = renderer

    info "SDL3 initialized successfully"

    generatePluginStateInitialize(gAppState.pluginStates)
    
    return SDL_APP_CONTINUE

  proc SDL_AppIterate(appstate: pointer): SDL_AppResult {.cdecl, gcsafe.} =
    let state = cast[ptr AppState[T]](appstate)

    discard SDL_SetRenderDrawColor(state.renderer, 0, 0, 0, 255)
    discard SDL_RenderClear(state.renderer)
    discard SDL_RenderPresent(state.renderer)

    return SDL_APP_CONTINUE

  proc SDL_AppEvent(appstate: pointer, event: ptr SDL_Event): SDL_AppResult {.cdecl, gcsafe.} =
    case event.kind
    of SDL_EVENT_QUIT:
      return SDL_APP_SUCCESS
    of SDL_EVENT_KEY_DOWN:
      if event.key.key == SDLK_ESCAPE:
        return SDL_APP_SUCCESS
    else:
      discard

    return SDL_APP_CONTINUE

  proc SDL_AppQuit(appstate: pointer, result: SDL_AppResult) {.cdecl, gcsafe.} =
    let state = cast[ptr AppState[T]](appstate)

    if not state.isNil:
      if not state.renderer.isNil:
        SDL_DestroyRenderer(state.renderer)
      if not state.window.isNil:
        SDL_DestroyWindow(state.window)
      dealloc(state)

    info "SDL3 quit"

  gAppState = cast[ptr AppState[T]](alloc0(sizeof(AppState[T])))
  gAppState.config = cfg
  gAppState.state = initialState
  discard SDL_EnterAppMainCallbacks(0, nil, SDL_AppInit, SDL_AppIterate, SDL_AppEvent, SDL_AppQuit)

template startApplication*[T](config: AppConfig, initialState: T) =
  initLogging()
  generateApplication(config, initialState)
