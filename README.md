# Beyond

A simple SDL3 application framework for Nim.

## What is Beyond?

Beyond is a game application framework built on SDL3. It provides a callback-based structure with a plugin system, scene management, and input handling. It handles the boilerplate of SDL3 initialization and main loop so you can focus on game logic.

## Features

- SDL3 callback-based architecture
- Plugin system with lifecycle hooks
- Scene stack for game states
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

when isMainModule:
  let config = AppConfig(
    appId: "com.example.mygame",
    title: "My Game",
    width: 1024,
    height: 768
  )
  start(config)
```

### Define Game State

Your game state holds all runtime data:

```nim
type
  GameState = object
    score: int
    playerName: string
```

proc createGameState(): GameState =
  GameState(score: 0, playerName: "Player")
```

### Plugin System

Plugins define game logic with lifecycle hooks:

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

  proc draw(drw: Drawing) =
    # Called during rendering
    drw.drawText(10, 10, "Hello World")
```

### Plugin Hooks

Available hooks and their injected parameters:

**load**
- `resources: Resources` - Resource manager
- `pluginStates: PluginStates` - Plugin state storage
- Custom game state fields (via `withFields`)

**loadScene**
- `scenes: SceneStack` - Scene stack
- `pluginStates: PluginStates`
- Custom game state fields

**update** (skipped when paused)
- `input: Input` - Input state
- `scenes: var SceneStack` - Scene stack (mutable)
- `pluginStates: PluginStates`
- `resources: Resources`
- `quit: var bool` - Set to true to quit
- Custom game state fields

**alwaysUpdate** (runs when paused)
- Same as `update`

**draw**
- `drawing: Drawing` - Rendering interface
- Custom game state fields

**Important**: Parameter names must match exactly as listed above.

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
      # Setup menu
    of "GameScene":
      # Setup game
    else:
      discard
```

### Input Handling

```nim
plugin InputHandler:
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
import beyond/resources

plugin ResourceLoader:
  proc load(resources: Resources) =
    # Load resources
    resources.load(Texture, "player.png", "player")
    resources.load(Sound, "jump.wav", "jump")
    resources.load(Font, "arial.ttf", "main-font")

  proc draw(drw: Drawing, resources: Resources) =
    # Use resources
    let texture = resources.get(Texture, "player")
    drw.drawTexture(texture, 100, 100)
```

### Drawing

```nim
plugin Renderer:
  proc draw(drw: Drawing) =
    # Clear screen
    drw.clear(rgb(0, 0, 0))

    # Draw shapes
    drw.drawRect(10, 10, 100, 50, rgb(255, 0, 0))
    drw.drawCircle(200, 200, 50, rgb(0, 255, 0))

    # Draw text
    drw.drawText(10, 10, "Score: 100", rgb(255, 255, 255))

    # Draw texture
    drw.drawTexture(texture, x: 100, y: 100, w: 64, h: 64)
```

### Custom Game State with Plugins

Use `withFields` to inject game state fields into plugins:

```nim
type
  GameState = object
    score: int
    lives: int

plugin ScoreManager:
  withFields(score, lives)

  proc update(input: Input) =
    # Direct access to score and lives
    if input.isPressed("collect"):
      score += 10

  proc draw(drw: Drawing) =
    drw.drawText(10, 10, "Score: " & $score)
    drw.drawText(10, 30, "Lives: " & $lives)
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
  withFields(score, paused)
  order = 0

  proc load(resources: Resources) =
    info "Game starting"
    resources.load(Texture, "player.png", "player")

  proc loadScene(scenes: SceneStack) =
    info "Loaded scene: ", scenes.currentScene()
    score = 0

  proc update(input: Input, scenes: var SceneStack) =
    if not paused:
      score += 1

    if input.isPressed("pause"):
      paused = not paused

    if input.isPressed("restart"):
      scenes.replace("GameScene")

  proc alwaysUpdate(input: Input, quit: var bool) =
    if input.isPressed("escape"):
      quit = true

  proc draw(drw: Drawing, resources: Resources) =
    drw.clear(rgb(20, 20, 30))
    drw.drawText(10, 10, "Score: " & $score)

    if paused:
      drw.drawText(400, 300, "PAUSED")

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
