import std/[macros]
import log, plugins, drawing, resources
import sdl3, sdl3_image, sdl3_ttf

export macros, log, drawing, resources

{.push raises: [].}

type
  AppState*[T] = object
    config: AppConfig
    window: SDL_Window
    renderer: SDL_Renderer
    pluginStates: PluginStates
    messages: PluginMessages
    drawing: Drawing
    resources: Resources
    paused: bool
    state*: T

  AppConfig* = object
    appId*: string
    title*: string
    width*, height*: int

macro withFields*(o: typed, self, blk: untyped) =
  var bindings = nnkStmtList.newTree()
  var rebindings = nnkStmtList.newTree()
  let t = o.getTypeImpl()
  for binding in t[2]:
    let defs = binding[0]
    let id = ident(defs.repr)
    bindings.add quote do:
      var `id` {.inject.} = `self`.state.`id`
    rebindings.add quote do:
      `self`.state.`id` = `id`
  result = quote:
    block:
      `bindings`
      `blk`
      `rebindings`

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

    if not TTF_Init():
      info "Failed to initialize SDL3_ttf: ", SDL_GetError()
      return SDL_APP_FAILURE
      
    info "SDL3 & SDL3_ttf initialized successfully"

    gAppState.resources = Resources.new()
    gAppState.drawing = Drawing.new(renderer)

    generatePluginStateInitialize(gAppState.pluginStates)

    var 
      drawing {.inject.} = gAppState.drawing
      resources {.inject.} = gAppState.resources

    withFields(gAppState.state, gAppState):
      generatePluginStep(load)
    
    return SDL_APP_CONTINUE

  proc SDL_AppIterate(appstate: pointer): SDL_AppResult {.cdecl, gcsafe.} =
    let state = cast[ptr AppState[T]](appstate)

    # Update
    withFields(state.state, state):
      generatePluginStep(loadScene)
      generateListenStep(state.messages)
      if not state.paused:
        generatePluginStep(update)
      generatePluginStep(alwaysUpdate)

    # Render
    discard SDL_SetRenderDrawColor(state.renderer, 0, 0, 0, 255)
    discard SDL_RenderClear(state.renderer)
    
    var drawing {.inject.} = state.drawing
    withFields(state.state, state):
      generatePluginStep(draw)
    
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
