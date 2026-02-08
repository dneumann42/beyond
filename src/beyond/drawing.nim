import bumpy, chroma, log, pretty, vmath
import std/[math, sequtils, algorithm]
export bumpy, chroma, vmath

import sdl3, sdl3_ttf, sdl3_image, plugins

# This library currently uses the SDL3 renderer, its very simple, can't do rotated rectangles.
# later goal is to develop a powerful renderer using the SDL3 graphics api. my goal is that the current api
# wont change much when introducing the new renderer

## Camera System Usage:
##
## The camera system allows you to create a viewport into your game world with zoom and position.
##
## Basic Usage:
##   # In your draw callback:
##   drawing.setCameraTarget(playerPosition)  # Camera will smoothly follow
##   drawing.setCameraZoom(2.0)               # 2x zoom
##   drawing.updateCamera(dt)                 # Update camera position with smoothing
##
##   drawing.applyCamera()                    # Apply camera transformations
##   # ... draw your game world here ...
##   drawing.resetCamera()                    # Reset for UI drawing
##
##   # ... draw UI elements here (not affected by camera) ...
##
## Multiple Cameras:
##   drawing.addCamera("gameplay", zoom = 1.5, smoothing = 0.2)
##   drawing.addCamera("minimap", zoom = 0.5, smoothing = 0.0)
##   drawing.setCamera("gameplay")
##
## Coordinate Conversion:
##   let worldPos = drawing.screenToWorld(mousePos)
##   let screenPos = drawing.worldToScreen(entityPos)

type
  Camera* = object
    name*: string
    target*, current*: Vec2
    zoom*, rotation*: float
    smoothing*: float  # 0.0 = instant, higher = more smoothing

  ScaleMode* = enum
    Nearest
    Linear

  LetterboxMode* = enum
    Stretch           ## Stretch canvas to fill window (may distort)
    LetterboxWidth    ## Fit to window width, add bars top/bottom
    LetterboxHeight   ## Fit to window height, add bars left/right
    LetterboxAuto     ## Automatically choose based on aspect ratio

  Canvas* = object
    name*: string
    order*: int
    offset*: IVec2
    texture*: SDL_Texture
    backgroundColor*: Color
    width*, height*: int  # Store canvas dimensions

  Drawing* = ref object
    currentFont*: TTF_Font
    currentCamera*: string
    cameras*: seq[Camera]
    renderer*: SDL_Renderer
    canvases*: seq[Canvas]
    viewportWidth*, viewportHeight*: float
    offset*: Vec2  # Drawing offset (typically set by camera)
    letterboxMode*: LetterboxMode  # How to fit canvases in window
    renderScale*: float  # Scale factor for all rendering operations

converter toSDLScaleMode*(mode: ScaleMode): SDL_ScaleMode =
  case mode:
    of Nearest:
      SDL_SCALEMODE_NEAREST
    of Linear:
      SDL_SCALEMODE_LINEAR

proc new*(T: typedesc[Drawing], renderer: SDL_Renderer): T =
  var w, h: cint
  discard SDL_GetRenderOutputSize(renderer, addr w, addr h)

  # Enable alpha blending globally for transparency support
  sdlCall SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND)

  result = T(
    renderer: renderer,
    currentCamera: "main",
    cameras: @[Camera(name: "main", zoom: 1.0, smoothing: 0.1)],
    viewportWidth: w.float,
    viewportHeight: h.float,
    offset: vec2(0, 0),
    letterboxMode: LetterboxAuto,  # Default to auto letterboxing
    renderScale: 1.0  # Default to 1:1 rendering
  )

proc addCanvas*(self: Drawing, name: string, width, height: int, order = 0, scaleMode = Nearest, backgroundColor: Color = chroma.color(0, 0, 0, 0)) =
  ## Create a new canvas (render target texture)
  ## First canvas defaults to black background, others default to transparent
  var texture = SDL_CreateTexture(
    self.renderer,
    SDL_PIXELFORMAT_RGBA32,
    SDL_TEXTUREACCESS_TARGET,
    width.cint,
    height.cint
  )

  if texture.isNil:
    error "Failed to create canvas texture: ", SDL_GetError()
    return

  sdlCall SDL_SetTextureScaleMode(texture, scaleMode)

  # Determine background color: first canvas is black, others are transparent
  var bgColor = backgroundColor
  if self.canvases.len == 0 and backgroundColor == chroma.color(0, 0, 0, 0):
    # First canvas and using default color -> use black instead of transparent
    bgColor = chroma.color(0, 0, 0, 1)

  self.canvases.add Canvas(
    name: name,
    texture: texture,
    order: order,
    backgroundColor: bgColor,
    width: width,
    height: height
  )

template beginCanvas*(self: Drawing, pname: string) =
  for canvas {.inject.} in self.canvases:
    if canvas.name != pname:
      continue
    sdlCall SDL_SetRenderTarget(self.renderer, canvas.texture)
    break

proc endCanvas*(self: Drawing) =
  sdlCall SDL_SetRenderTarget(self.renderer, nil)

template withCanvas*(self: Drawing, name: string, blk: untyped) =
  self.beginCanvas(name)
  blk
  self.endCanvas()

proc clearCanvas*(self: Drawing, name: string) =
  ## Clear a canvas with its background color
  for canvas in self.canvases:
    if canvas.name != name:
      continue

    # Set canvas as render target
    sdlCall SDL_SetRenderTarget(self.renderer, canvas.texture)

    # Set clear color and clear
    sdlCall SDL_SetRenderDrawColorFloat(
      self.renderer,
      canvas.backgroundColor.r,
      canvas.backgroundColor.g,
      canvas.backgroundColor.b,
      canvas.backgroundColor.a
    )
    sdlCall SDL_RenderClear(self.renderer)

    # Reset render target
    sdlCall SDL_SetRenderTarget(self.renderer, nil)
    break

proc clearCanvas*(self: Drawing, name: string, color: Color) =
  ## Clear a canvas with a custom color
  for canvas in self.canvases:
    if canvas.name != name:
      continue

    # Set canvas as render target
    sdlCall SDL_SetRenderTarget(self.renderer, canvas.texture)

    # Set clear color and clear
    sdlCall SDL_SetRenderDrawColorFloat(
      self.renderer,
      color.r,
      color.g,
      color.b,
      color.a
    )
    sdlCall SDL_RenderClear(self.renderer)

    # Reset render target
    sdlCall SDL_SetRenderTarget(self.renderer, nil)
    break

# Texture Scale Mode

proc setTextureScaleMode*(texture: SDL_Texture, scaleMode: SDL_ScaleMode) =
  ## Set the scale mode for a texture
  ## SDL_SCALEMODE_NEAREST = pixelated/sharp (good for pixel art)
  ## SDL_SCALEMODE_LINEAR = smooth/blurry (good for photos)
  sdlCall SDL_SetTextureScaleMode(texture, scaleMode)

proc setNearestNeighbor*(texture: SDL_Texture) =
  ## Set texture to use nearest neighbor (pixelated) rendering
  setTextureScaleMode(texture, SDL_SCALEMODE_NEAREST)

proc setLinearFiltering*(texture: SDL_Texture) =
  ## Set texture to use linear filtering (smooth) rendering
  setTextureScaleMode(texture, SDL_SCALEMODE_LINEAR)

# Camera Management

proc getCamera*(self: Drawing, name: string): ptr Camera =
  ## Get a camera by name. Returns nil if not found.
  for i in 0..<self.cameras.len:
    if self.cameras[i].name == name:
      return addr self.cameras[i]
  return nil

proc getCamera*(self: Drawing): ptr Camera =
  ## Get the current active camera
  return self.getCamera(self.currentCamera)

proc setCamera*(self: Drawing, name: string) =
  ## Set the active camera by name
  if self.getCamera(name) != nil:
    self.currentCamera = name

proc addCamera*(self: Drawing, name: string, zoom = 1.0, smoothing = 0.1) =
  ## Add a new camera
  self.cameras.add(Camera(
    name: name,
    zoom: zoom,
    smoothing: smoothing
  ))

proc updateCamera*(self: Drawing, dt: float = 0.016) =
  ## Update camera position with smoothing (call this each frame)
  let cam = self.getCamera()
  if cam.isNil:
    return

  # Smooth camera movement
  if cam.smoothing > 0.0:
    let factor = 1.0 - pow(cam.smoothing, dt * 60.0)
    cam.current = cam.current + (cam.target - cam.current) * factor
  else:
    cam.current = cam.target

proc setCameraTarget*(self: Drawing, target: Vec2) =
  ## Set the target position for the current camera
  let cam = self.getCamera()
  if not cam.isNil:
    cam.target = target

proc setCameraPosition*(self: Drawing, pos: Vec2) =
  ## Set the immediate position of the current camera (no smoothing)
  let cam = self.getCamera()
  if not cam.isNil:
    cam.current = pos
    cam.target = pos

proc setCameraZoom*(self: Drawing, zoom: float) =
  ## Set the zoom level of the current camera
  let cam = self.getCamera()
  if not cam.isNil:
    cam.zoom = zoom

proc setCameraRotation*(self: Drawing, rotation: float) =
  ## Set the rotation of the current camera (in radians)
  let cam = self.getCamera()
  if not cam.isNil:
    cam.rotation = rotation

proc setOffset*(self: Drawing, offset: Vec2) =
  ## Set the drawing offset (typically used for camera)
  self.offset = offset

proc applyCamera*(self: Drawing) =
  ## Apply camera transformations to the renderer and set drawing offset
  ## Call this before drawing your scene
  let cam = self.getCamera()
  if cam.isNil:
    return

  # Apply zoom via render scale
  sdlCall SDL_SetRenderScale(self.renderer, cam.zoom, cam.zoom)

  # Set offset from camera position
  self.offset = cam.current

proc resetCamera*(self: Drawing) =
  ## Reset camera transformations and offset
  ## Call this after drawing your scene (e.g., before drawing UI)
  sdlCall SDL_SetRenderScale(self.renderer, 1.0, 1.0)
  self.offset = vec2(0, 0)

proc getCameraOffset*(self: Drawing): Vec2 =
  ## Get the current camera offset for manual coordinate transformation
  let cam = self.getCamera()
  if cam.isNil:
    return vec2(0, 0)
  return cam.current

proc updateViewportSize*(self: Drawing) =
  ## Update viewport size (call when window is resized)
  var w, h: cint
  discard SDL_GetRenderOutputSize(self.renderer, addr w, addr h)
  self.viewportWidth = w.float
  self.viewportHeight = h.float

proc worldToScreen*(self: Drawing, worldPos: Vec2): Vec2 =
  ## Convert world coordinates to screen coordinates
  let cam = self.getCamera()
  if cam.isNil:
    return worldPos

  result = (worldPos - cam.current) * cam.zoom

proc screenToWorld*(self: Drawing, screenPos: Vec2): Vec2 =
  ## Convert screen coordinates to world coordinates
  let cam = self.getCamera()
  if cam.isNil:
    return screenPos

  result = screenPos / cam.zoom + cam.current

const
  White* = parseHtmlColor "#FFFFFF"

proc setDrawColor*(self: Drawing, color = White) =
  sdlCall SDL_SetRenderDrawColorFloat(self.renderer, color.r, color.g, color.b, color.a)

proc `drawColor=`*(self: Drawing, color: Color) =
  sdlCall SDL_SetRenderDrawColorFloat(self.renderer, color.r, color.g, color.b, color.a)

proc `font=`*(self: Drawing, font: TTF_Font) =
  self.currentFont = font

converter toSDLColor*(color: Color): SDL_Color =
  let col = color.rgba()
  result = SDL_Color(r: col.r, g: col.g, b: col.b, a: col.a)

proc measure*(self: Drawing, text: string): Vec2 =
  if self.currentFont.isNil:
    return
  var w: cint = 0
  var h: csize_t = 0
  discard TTF_MeasureString(
    self.currentFont,
    text.cstring,
    0,
    0,
    addr w,
    addr h
  )
  let he = TTF_GetFontHeight(self.currentFont)
  result = vec2(w.toFloat, float(he))

proc rotatePoint(x, y, cx, cy, angle: float32): (float32, float32) {.inline.} =
  ## Rotate a point around a center
  let cosAngle = cos(angle)
  let sinAngle = sin(angle)
  let dx = x - cx
  let dy = y - cy
  result = (
    cx + dx * cosAngle - dy * sinAngle,
    cy + dx * sinAngle + dy * cosAngle
  )

proc draw*(self: Drawing, rect: Rect, fill = true, color = White, borderRadius = 0.0'f32, rotation = 0.0'f32) =
  # TODO: SDL_RenderGeometry is not working correctly, disable for now
  # Always use simple rect rendering
  # Apply render scale to position and size
  var frect = SDL_FRect(
    x: (rect.x - self.offset.x) * self.renderScale,
    y: (rect.y - self.offset.y) * self.renderScale,
    w: rect.w * self.renderScale,
    h: rect.h * self.renderScale
  )
  self.setDrawColor color
  if fill:
    sdlCall SDL_RenderFillRect(self.renderer, addr frect)
  else:
    sdlCall SDL_RenderRect(self.renderer, addr frect)

proc drawText*(self: Drawing, x, y: float, text: string, color = White) =
  self.drawColor = color
  let screenX = (x - self.offset.x) * self.renderScale
  let screenY = (y - self.offset.y) * self.renderScale

  if self.currentFont.isNil:
    sdlCall SDL_RenderDebugText(self.renderer, screenX.cfloat, screenY.cfloat, text.cstring)
  else:
    var surface = TTF_RenderText_Blended(self.currentFont, text, 0, color)
    if surface.isNil:
      return
    var texture = SDL_CreateTextureFromSurface(self.renderer, surface)
    if texture.isNil:
      return
    var srcrect = SDL_FRect(
      x: 0,
      y: 0,
      w: surface.w.float32,
      h: surface.h.float32,
    )
    var dstrect = SDL_FRect(
      x: screenX,
      y: screenY,
      w: surface.w.float32 * self.renderScale,
      h: surface.h.float32 * self.renderScale,
    )
    SDL_DestroySurface(surface)
    discard SDL_RenderTexture(
      self.renderer,
      texture,
      addr srcrect,
      addr dstrect
    )
    SDL_DestroyTexture(texture)

# Fixed font metrics for debug text (typical monospace debug font)
const
  DebugCharWidth* = 8.0
  DebugCharHeight* = 16.0

proc measureText*(text: string): tuple[width: float, height: float] =
  ## Measure text dimensions using fixed debug font metrics
  ## Returns (width, height) in pixels
  result.width = text.len.float * DebugCharWidth
  result.height = DebugCharHeight

proc draw*(self: Drawing, texture: SDL_Texture,
                  srcX, srcY, srcW, srcH: float32,
                  dstX, dstY, dstW, dstH: float32) =
  ## Draw a portion of a texture to the screen
  ## srcX, srcY, srcW, srcH: source rectangle in the texture
  ## dstX, dstY, dstW, dstH: destination rectangle in world coordinates
  ## The drawing offset and render scale are automatically applied
  var srcrect = SDL_FRect(x: srcX, y: srcY, w: srcW, h: srcH)
  var dstrect = SDL_FRect(
    x: (dstX - self.offset.x) * self.renderScale,
    y: (dstY - self.offset.y) * self.renderScale,
    w: dstW * self.renderScale,
    h: dstH * self.renderScale
  )
  discard SDL_RenderTexture(
    self.renderer,
    texture,
    addr srcrect,
    addr dstrect
  )

proc drawCircle*(self: Drawing, centerX, centerY, radius: float32, fill = false, color = White, segments = 32) =
  ## Draw a circle using SDL3 line rendering
  ## segments: number of line segments to approximate the circle (higher = smoother)

  let scaledCenterX = (centerX - self.offset.x) * self.renderScale
  let scaledCenterY = (centerY - self.offset.y) * self.renderScale
  let scaledRadius = radius * self.renderScale

  discard SDL_SetRenderDrawColor(
    self.renderer,
    uint8(color.r * 255),
    uint8(color.g * 255),
    uint8(color.b * 255),
    uint8(color.a * 255)
  )

  if fill:
    # Draw filled circle by drawing lines from center to perimeter
    for i in 0..<segments:
      let angle1 = (i.float32 / segments.float32) * 2.0 * PI
      let angle2 = ((i + 1).float32 / segments.float32) * 2.0 * PI

      let x1 = scaledCenterX + cos(angle1) * scaledRadius
      let y1 = scaledCenterY + sin(angle1) * scaledRadius
      let x2 = scaledCenterX + cos(angle2) * scaledRadius
      let y2 = scaledCenterY + sin(angle2) * scaledRadius

      # Draw triangle from center to two perimeter points
      let sdlColor = SDL_Color(
        r: uint8(color.r * 255),
        g: uint8(color.g * 255),
        b: uint8(color.b * 255),
        a: uint8(color.a * 255)
      )
      var vertices = [
        SDL_Vertex(position: SDL_FPoint(x: scaledCenterX, y: scaledCenterY), color: sdlColor),
        SDL_Vertex(position: SDL_FPoint(x: x1, y: y1), color: sdlColor),
        SDL_Vertex(position: SDL_FPoint(x: x2, y: y2), color: sdlColor)
      ]
      discard SDL_RenderGeometry(self.renderer, nil, addr vertices[0], 3, nil, 0)
  else:
    # Draw circle outline by connecting perimeter points
    for i in 0..segments:
      let angle1 = (i.float32 / segments.float32) * 2.0 * PI
      let angle2 = ((i + 1).float32 / segments.float32) * 2.0 * PI

      let x1 = scaledCenterX + cos(angle1) * scaledRadius
      let y1 = scaledCenterY + sin(angle1) * scaledRadius
      let x2 = scaledCenterX + cos(angle2) * scaledRadius
      let y2 = scaledCenterY + sin(angle2) * scaledRadius

      discard SDL_RenderLine(self.renderer, x1, y1, x2, y2)

proc drawLine*(self: Drawing, x1, y1, x2, y2: float32, color = White) =
  ## Draw a line from (x1, y1) to (x2, y2)
  let scaledX1 = (x1 - self.offset.x) * self.renderScale
  let scaledY1 = (y1 - self.offset.y) * self.renderScale
  let scaledX2 = (x2 - self.offset.x) * self.renderScale
  let scaledY2 = (y2 - self.offset.y) * self.renderScale

  discard SDL_SetRenderDrawColor(
    self.renderer,
    uint8(color.r * 255),
    uint8(color.g * 255),
    uint8(color.b * 255),
    uint8(color.a * 255)
  )

  discard SDL_RenderLine(self.renderer, scaledX1, scaledY1, scaledX2, scaledY2)

proc saveScreenshot*(self: Drawing, filename: string) =
  ## Save the current renderer content to a BMP file
  let surface = SDL_RenderReadPixels(self.renderer, nil)
  if not surface.isNil:
    discard SDL_SaveBMP(surface, filename.cstring)
    SDL_DestroySurface(surface)
    echo "Screenshot saved to: ", filename
  else:
    echo "Failed to capture screenshot: ", SDL_GetError()

# Canvas Management

proc sortCanvases*(self: Drawing) =
  ## Sort canvases by their order field
  self.canvases.sort(proc(a, b: Canvas): int = cmp(a.order, b.order))

proc setLetterboxMode*(self: Drawing, mode: LetterboxMode) =
  ## Set how canvases should be fit into the window
  self.letterboxMode = mode

proc setRenderScale*(self: Drawing, scale: float) =
  ## Set the render scale for all drawing operations
  ## For example, scale=4 means rendering at 4x resolution
  self.renderScale = scale

proc setTextureFiltering*(texture: SDL_Texture, filtering: ScaleMode) =
  ## Set the filtering mode for a specific texture
  ## Nearest = sharp/pixelated, Linear = smooth/blended
  sdlCall SDL_SetTextureScaleMode(texture, filtering)

proc setAllCanvasFiltering*(self: Drawing, filtering: ScaleMode) =
  ## Set the filtering mode for all canvases
  for canvas in self.canvases:
    if not canvas.texture.isNil:
      sdlCall SDL_SetTextureScaleMode(canvas.texture, filtering)

proc drawCanvases*(self: Drawing) =
  ## Draw all canvases to the screen in order with letterboxing
  # Sort canvases by order before drawing
  self.sortCanvases()

  # Get window size
  var windowW, windowH: cint
  discard SDL_GetRenderOutputSize(self.renderer, addr windowW, addr windowH)

  # Safety check: if window size is invalid, skip drawing
  if windowW <= 0 or windowH <= 0:
    return

  for canvas in self.canvases:
    if canvas.texture.isNil:
      continue

    # Use stored canvas dimensions
    let canvasW = canvas.width
    let canvasH = canvas.height

    # Safety check: if canvas size is invalid, skip
    if canvasW <= 0 or canvasH <= 0:
      continue

    # Calculate destination rectangle based on letterbox mode
    let canvasAspect = canvasW.float / canvasH.float
    let windowAspect = windowW.float / windowH.float

    var dstX, dstY, dstW, dstH: float

    case self.letterboxMode:
    of Stretch:
      # Stretch to fill entire window
      dstX = 0.0
      dstY = 0.0
      dstW = windowW.float
      dstH = windowH.float

    of LetterboxWidth:
      # Fit to window width, add bars on top/bottom
      dstW = windowW.float
      dstH = dstW / canvasAspect
      dstX = 0.0
      dstY = (windowH.float - dstH) / 2.0

    of LetterboxHeight:
      # Fit to window height, add bars on left/right
      dstH = windowH.float
      dstW = dstH * canvasAspect
      dstX = (windowW.float - dstW) / 2.0
      dstY = 0.0

    of LetterboxAuto:
      # Automatically choose based on aspect ratio
      if canvasAspect > windowAspect:
        # Canvas is wider than window - fit to width
        dstW = windowW.float
        dstH = dstW / canvasAspect
        dstX = 0.0
        dstY = (windowH.float - dstH) / 2.0
      else:
        # Canvas is taller than window - fit to height
        dstH = windowH.float
        dstW = dstH * canvasAspect
        dstX = (windowW.float - dstW) / 2.0
        dstY = 0.0

    var dst = SDL_FRect(
      x: dstX.float32,
      y: dstY.float32,
      w: dstW.float32,
      h: dstH.float32
    )

    discard SDL_RenderTexture(
      self.renderer,
      canvas.texture,
      nil,  # Source rect (entire canvas)
      addr dst  # Destination rect (with letterboxing)
    )
