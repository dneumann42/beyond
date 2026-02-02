import std/[macros, sets]
import log, plugins, drawing, resources, inputs
import sdl3, sdl3_image, sdl3_ttf

export macros, log, drawing, resources

export sdl3.`==`
export sdl3.hash

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
    input: Input
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
      input {.inject.} = gAppState.input

    withFields(gAppState.state, gAppState):
      generatePluginStep(load)

    gAppState.input = input
    return SDL_APP_CONTINUE

  proc SDL_AppIterate(appstate: pointer): SDL_AppResult {.cdecl, gcsafe.} =
    var state = cast[ptr AppState[T]](appstate)

    var 
      input {.inject.} = state.input
      quit {.inject.} = false

    withFields(state.state, state):
      generatePluginStep(loadScene)
      generateListenStep(state.messages)
      if not state.paused:
        generatePluginStep(update)
      generatePluginStep(alwaysUpdate)

    if quit:
      return SDL_APP_SUCCESS

    # Render
    discard SDL_SetRenderDrawColor(state.renderer, 0, 0, 0, 255)
    discard SDL_RenderClear(state.renderer)
    
    var drawing {.inject.} = state.drawing
    withFields(state.state, state):
      generatePluginStep(draw)
    
    discard SDL_RenderPresent(state.renderer)
    state.input.pressedKey.clear()
    state.input.releasedKey.clear()

    return SDL_APP_CONTINUE

  proc SDL_AppEvent(appstate: pointer, event: ptr SDL_Event): SDL_AppResult {.cdecl, gcsafe.} =
    let state = cast[ptr AppState[T]](appstate)
    
    case event.kind
    of SDL_EVENT_QUIT:
      return SDL_APP_SUCCESS
    of SDL_EVENT_KEY_DOWN:
      let wasDown = state.input.downKey.contains(event.key.key)
      state.input.downKey.incl(event.key.key)
      if not wasDown:
        state.input.pressedKey.incl(event.key.key)
    of SDL_EVENT_KEY_UP:
      if state.input.downKey.contains(event.key.key):
        state.input.downKey.excl(event.key.key)
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
