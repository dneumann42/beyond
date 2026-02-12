# Beyond

A simple SDL3 application framework for Nim.

## What is Beyond?

Beyond is a game application framework built on SDL3. It provides a callback-based structure with a plugin system, scene management, and input handling. It handles the boilerplate of SDL3 initialization and main loop so you can focus on game logic.

## Features

- SDL3 callback-based architecture
- Plugin system with lifecycle hooks
- Scene stack for game states
- Plugin-specific state management
- Input abstraction
- Resource management
- Exception-safe logging
- Static or dynamic SDL3 linking

## Installation

```nim
requires "beyond"
```

## Basic Usage

### Create an Application

```nim
import beyond/application

type
  GameState = object
    score: int
    playerName: string

proc createGameState(): GameState =
  GameState(score: 0, playerName: "Player")

when isMainModule:
  let config = AppConfig(
    appId: "com.example.mygame",
    title: "My Game",
    width: 1024,
    height: 768
  )
  start(config)
```

### Plugin System

Plugins define game logic with lifecycle hooks. Plugin functions request parameters by name, and the framework provides them:

```nim
import beyond/application

plugin GameLogic:
  order = 0  # Execution order (lower runs first)

  proc load(resources: Resources) =
    # Called once at startup
    resources.load(Texture, "player.png", "player")

  proc loadScene(scenes: SceneStack) =
    # Called when scene loads
    echo "Scene loaded: ", scenes.currentScene()

  proc update(input: Input, scenes: var SceneStack) =
    # Called every frame (skipped when paused)
    if input.isPressed("quit"):
      scenes.pop()

  proc alwaysUpdate(input: Input, quit: var bool) =
    # Called every frame (even when paused)
    if input.isPressed("escape"):
      quit = true

  proc draw(drawing: Drawing) =
    # Called during rendering
    drawing.drawText(10, 10, "Hello World")
```

### Plugin Hooks

Available lifecycle hooks:

**load**
- Called once during SDL_AppInit
- Use for initialization and resource loading

**loadScene**
- Called when the scene changes
- Use for scene-specific setup

**update**
- Called every frame (skipped when paused)
- Main game logic goes here

**alwaysUpdate**
- Called every frame (even when paused)
- Use for UI, pause menus, etc.

**draw**
- Called during render phase
- All drawing operations go here

**drawHud**
- Additional draw phase for HUD elements
- Rendered after main draw

### Available Parameters

Plugin functions can request any of these parameters by name:

**Framework-provided:**
- `input: Input` - Input state (keyboard, mouse, scroll)
- `scenes: var SceneStack` - Scene management
- `resources: Resources` - Resource manager
- `drawing: Drawing` - Drawing interface
- `quit: var bool` - Set to true to quit application
- `deltaTime: float` - Frame delta time
- `fps: float` - Current frames per second
- `paused: var bool` - Pause state

**From GameState:**
- Any field from your GameState object
- Requested by field name (e.g., `score`, `entitySystem`, `ui`)

**Plugin state:**
- `state: var YourPluginState` - When plugin declares `state = YourPluginState()`

### Plugin State

Plugins can maintain their own state:

```nim
type
  CounterState = object
    count: int
    lastUpdate: float

plugin Counter:
  state = CounterState()

  proc update(state: var CounterState, deltaTime: float) =
    state.count += 1
    state.lastUpdate += deltaTime

  proc draw(drawing: Drawing, state: CounterState) =
    drawing.drawText(10, 10, "Count: " & $state.count)
```

### Accessing GameState Fields

GameState fields are automatically available by requesting them as parameters:

```nim
type
  GameState = object
    score: int
    lives: int
    playerName: string

proc createGameState(): GameState =
  GameState(score: 0, lives: 3, playerName: "Player")

plugin ScoreManager:
  proc update(input: Input, score: var int, lives: var int) =
    # score and lives come from GameState
    if input.isPressed("collect"):
      score += 10

    if input.isPressed("damage"):
      lives -= 1

  proc draw(drawing: Drawing, score: int, lives: int, playerName: string) =
    drawing.drawText(10, 10, "Score: " & $score)
    drawing.drawText(10, 30, "Lives: " & $lives)
    drawing.drawText(10, 50, "Player: " & playerName)
```

### Scene Management

```nim
plugin SceneManager:
  proc update(scenes: var SceneStack, input: Input) =
    if input.isPressed("start"):
      scenes.push("GameScene")

    if input.isPressed("back"):
      scenes.pop()

    if input.isPressed("menu"):
      scenes.replace("MenuScene")

  proc loadScene(scenes: SceneStack) =
    case scenes.currentScene()
    of "MenuScene":
      echo "Menu loaded"
    of "GameScene":
      echo "Game loaded"
    else:
      discard
```

### Input Handling

```nim
plugin InputHandler:
  proc load(input: var Input) =
    # Configure input mappings
    input.set("jump").key(SDLK_SPACE)
    input.set("fire").mouse(MouseButton.Left)

  proc update(input: Input) =
    # Check key presses
    if input.isPressed("jump"):
      echo "Jump pressed this frame"

    if input.isDown("jump"):
      echo "Jump held down"

    # Mouse input
    let (mx, my) = input.mousePosition()
    if input.mousePressed(MouseButton.Left):
      echo "Clicked at: ", mx, ", ", my

    # Scroll
    let scroll = input.scrollDelta()
    if scroll != 0:
      echo "Scrolled: ", scroll
```

### Resource Management

```nim
plugin ResourceLoader:
  proc load(resources: Resources, drawing: var Drawing) =
    # Load resources
    resources.load(Texture, "player.png", "player")
    resources.load(Font, "arial.ttf", "main-font", 16)

    # Set default font
    drawing.font = resources.get(Font, "main-font")

  proc draw(drawing: Drawing, resources: Resources) =
    # Use resources
    let texture = resources.get(Texture, "player")
    drawing.drawTexture(texture, 100, 100, 64, 64)
```

### Drawing

```nim
plugin Renderer:
  proc draw(drawing: Drawing) =
    # Clear screen
    drawing.clear(color(0.1, 0.1, 0.15))

    # Draw shapes
    drawing.drawRect(10, 10, 100, 50, color(1.0, 0, 0))
    drawing.drawCircle(200, 200, 50, color(0, 1.0, 0))

    # Draw text
    drawing.drawText(10, 10, "Score: 100")

    # Draw texture
    drawing.drawTexture(texture, x: 100, y: 100, w: 64, h: 64)
```

### Logging

Beyond provides exception-safe logging:

```nim
import beyond/log

proc myFunction() {.raises: [].} =
  info "Application started"
  debug "Debug info: ", someValue
  warn "Warning message"
  error "Error occurred: ", errorCode

  # Safe to use in {.raises: [].} functions
```

## Complete Example

```nim
import beyond/application
import beyond/log

type
  GameState = object
    score: int
    paused: bool

proc createGameState(): GameState =
  GameState(score: 0, paused: false)

plugin GameLogic:
  order = 0

  proc load(resources: Resources, input: var Input) =
    info "Game starting"
    resources.load(Texture, "player.png", "player")
    input.set("pause").key(SDLK_P)
    input.set("restart").key(SDLK_R)

  proc loadScene(scenes: SceneStack, score: var int) =
    info "Loaded scene: ", scenes.currentScene()
    score = 0

  proc update(
    input: Input,
    scenes: var SceneStack,
    score: var int,
    paused: var bool
  ) =
    if not paused:
      score += 1

    if input.isPressed("pause"):
      paused = not paused

    if input.isPressed("restart"):
      scenes.replace("GameScene")

  proc alwaysUpdate(input: Input, quit: var bool) =
    if input.isPressed("escape"):
      quit = true

  proc draw(drawing: Drawing, score: int, paused: bool) =
    drawing.clear(color(0.08, 0.08, 0.12))
    drawing.drawText(10, 10, "Score: " & $score)

    if paused:
      drawing.drawText(400, 300, "PAUSED")

when isMainModule:
  let config = AppConfig(
    appId: "com.example.game",
    title: "My Game",
    width: 800,
    height: 600
  )
  start(config)
```

## SDL3 Setup

Beyond uses SDL3. You can link statically or dynamically:

### Static Linking (Default)

Define `beyondStaticLinkSDL3` before importing:

```nim
{.define: beyondStaticLinkSDL3.}
import beyond/application
```

Requires `libSDL3.a` in `/usr/lib/` or your library path.

### Dynamic Linking

Don't define the symbol, SDL3 will be loaded dynamically:

```nim
import beyond/application
```

Requires `libSDL3.so` (Linux) or `SDL3.dll` (Windows) at runtime.

## Architecture

Beyond uses SDL3's callback-based API:

1. **SDL_AppInit** - Initialize window and renderer
2. **SDL_AppIterate** - Main loop (called every frame)
3. **SDL_AppEvent** - Handle events
4. **SDL_AppQuit** - Cleanup

Your plugins hook into these callbacks through the lifecycle system.

## Plugin Order

Control plugin execution order:

```nim
plugin First:
  order = 0

plugin Second:
  order = 100

plugin Third:
  order = 200
```

Lower order values run first. Default order is 0.

## Scene Macro

The `scene` macro creates scene-specific plugins:

```nim
scene MenuScene:
  proc loadScene() =
    echo "Menu scene loaded"

  proc update(input: Input) =
    # Only runs when MenuScene is active
    if input.isPressed("start"):
      scenes.push("GameScene")

  proc draw(drawing: Drawing) =
    drawing.drawText(100, 100, "Main Menu")
```

## Error Handling

Beyond uses exception-safe design:

- All SDL callbacks use `{.raises: [].}`
- Logging never raises exceptions
- Plugin errors are caught and logged
- Application continues running after errors

## Performance

- Plugins are statically compiled (zero overhead)
- Scene transitions are deferred to safe points
- Input state is cached per frame
- Resource loading is explicit (no surprises)

## Requirements

- Nim 2.0+
- SDL3 (static or dynamic)
- C compiler

## License

MIT
