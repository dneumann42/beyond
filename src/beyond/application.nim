import std/[macros, sets]
import log, plugins, drawing, inputs
from resources import Resources
import sdl3, sdl3_image, sdl3_ttf

export macros, log, drawing, Resources

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
    scenes: SceneStack
    input: Input
    paused: bool
    state*: T

    # Performance metrics
    lastFrameTime: uint64
    deltaTime*: float  ## Time since last frame in seconds
    fps*: float        ## Current frames per second

  AppConfig* = object
    appId*: string
    title*: string
    width*, height*: int
    renderWidth*, renderHeight*: int  ## Logical render resolution (defaults to width/height if 0)

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

    # Set nearest-neighbor filtering for pixel-perfect rendering
    discard SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "0")

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

    # No logical presentation - we're using manual letterboxing in drawCanvases

    if not TTF_Init():
      info "Failed to initialize SDL3_ttf: ", SDL_GetError()
      return SDL_APP_FAILURE
      
    info "SDL3 & SDL3_ttf initialized successfully"

    gAppState.resources = Resources.new(renderer)
    gAppState.drawing = Drawing.new(renderer)
    gAppState.scenes = SceneStack.new()

    # Initialize performance counters
    gAppState.lastFrameTime = SDL_GetPerformanceCounter()
    gAppState.deltaTime = 0.0
    gAppState.fps = 0.0

    generatePluginStateInitialize(gAppState.pluginStates)

    var
      drawing {.inject.} = gAppState.drawing
      resources {.inject.} = gAppState.resources
      input {.inject.} = gAppState.input
      scenes {.inject.} = gAppState.scenes
      pluginStates {.inject.} = gAppState.pluginStates

    withFields(gAppState.state, gAppState):
      generatePluginStep(load)

    gAppState.input = input
    gAppState.scenes = scenes
    gAppState.pluginStates = pluginStates
    return SDL_APP_CONTINUE

  proc SDL_AppIterate(appstate: pointer): SDL_AppResult {.cdecl, gcsafe.} =
    var state = cast[ptr AppState[T]](appstate)

    # Target 60 FPS (16.67ms per frame)
    const targetFrameTime = 1.0 / 60.0
    let frequency = SDL_GetPerformanceFrequency()

    # Calculate delta time from last frame (includes previous frame's sleep)
    let frameStartTime = SDL_GetPerformanceCounter()
    let deltaCounter = frameStartTime - state.lastFrameTime
    state.lastFrameTime = frameStartTime  # Update immediately for next frame

    # Calculate delta time in seconds
    state.deltaTime = deltaCounter.float / frequency.float

    # Clamp delta time to prevent spiral of death
    if state.deltaTime > 0.1:  # Max 100ms
      state.deltaTime = 0.1

    # Calculate FPS (smooth with exponential moving average)
    if state.deltaTime > 0.0:
      let instantFPS = 1.0 / state.deltaTime
      # Smooth FPS with 10% weight to new value
      state.fps = state.fps * 0.9 + instantFPS * 0.1

    var
      input {.inject.} = state.input
      scenes {.inject.} = state.scenes
      pluginStates {.inject.} = state.pluginStates
      resources {.inject.} = state.resources
      quit {.inject.} = false
      fps {.inject.} = state.fps
      deltaTime {.inject.} = state.deltaTime
      paused {.inject.} = state.paused

    state.scenes.startFrame()
    state.scenes.handlePushed()

    withFields(state.state, state):
      generatePluginStep(loadScene)
      generateListenStep(state.messages)
      if not state.paused:
        generatePluginStep(update)
      generatePluginStep(alwaysUpdate)

    state.scenes = scenes
    state.pluginStates = pluginStates
    state.paused = paused 

    if quit:
      return SDL_APP_SUCCESS

    # Render
    discard SDL_SetRenderDrawColor(state.renderer, 0, 0, 0, 255)
    discard SDL_RenderClear(state.renderer)

    var drawing {.inject.} = state.drawing
    withFields(state.state, state):
      generatePluginStep(draw)

    state.pluginStates = pluginStates

    # Draw all canvases after scene drawing
    state.drawing.drawCanvases()

    discard SDL_RenderPresent(state.renderer)

    # Clear per-frame input state
    state.input.pressedKey.clear()
    state.input.releasedKey.clear()

    # Clear per-frame UI input state
    when compiles(state.state.ui):
      state.state.ui.input.actionPressed = false
      state.state.ui.input.dragPressed = false
      state.state.ui.input.backspacePressed = false
      state.state.ui.input.enterPressed = false
      state.state.ui.input.tabPressed = false
      state.state.ui.input.textInput = ""
      state.state.ui.input.scrollY = 0.0

    # Frame rate limiting - cap at 60 FPS for smooth, consistent gameplay
    let frameEndTime = SDL_GetPerformanceCounter()
    let frameElapsed = (frameEndTime - frameStartTime).float / frequency.float
    let frameRemaining = targetFrameTime - frameElapsed

    if frameRemaining > 0.0:
      # Sleep for remaining time (convert to milliseconds)
      let sleepMs = (frameRemaining * 1000.0).uint32
      if sleepMs > 0:
        SDL_Delay(sleepMs)

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

      # Update UI input for special keys
      when compiles(state.state.ui):
        if event.key.key == SDLK_BACKSPACE:
          state.state.ui.input.backspacePressed = true
        elif event.key.key == SDLK_RETURN:
          state.state.ui.input.enterPressed = true
        elif event.key.key == SDLK_TAB:
          state.state.ui.input.tabPressed = true
    of SDL_EVENT_KEY_UP:
      if state.input.downKey.contains(event.key.key):
        state.input.downKey.excl(event.key.key)
    of SDL_EVENT_TEXT_INPUT:
      # Accumulate text input for UI
      when compiles(state.state.ui):
        let text = $cast[cstring](addr event.text.text[0])
        state.state.ui.input.textInput &= text
    of SDL_EVENT_MOUSE_MOTION:
      when compiles(state.state.ui):
        state.state.ui.input.mousePosition = (event.motion.x.int, event.motion.y.int)
    of SDL_EVENT_MOUSE_BUTTON_DOWN:
      when compiles(state.state.ui):
        if event.button.button == SDL_BUTTON_LEFT:
          state.state.ui.input.actionDown = true
          state.state.ui.input.actionPressed = true
        elif event.button.button == SDL_BUTTON_RIGHT:
          state.state.ui.input.dragDown = true
          state.state.ui.input.dragPressed = true
    of SDL_EVENT_MOUSE_BUTTON_UP:
      when compiles(state.state.ui):
        if event.button.button == SDL_BUTTON_LEFT:
          state.state.ui.input.actionDown = false
        elif event.button.button == SDL_BUTTON_RIGHT:
          state.state.ui.input.dragDown = false
    of SDL_EVENT_MOUSE_WHEEL:
      when compiles(state.state.ui):
        state.state.ui.input.scrollY = event.wheel.y.float * 20.0
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
