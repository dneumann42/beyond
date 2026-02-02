import bumpy, chroma, log, pretty, vmath
export bumpy, chroma

import sdl3, sdl3_ttf, sdl3_image

# This library currently uses the SDL3 renderer, its very simple, can't do rotated rectangles.
# later goal is to develop a powerful renderer using the SDL3 graphics api. my goal is that the current api
# wont change much when introducing the new renderer

type
  Drawing* = ref object
    currentFont*: TTF_Font
    renderer*: SDL_Renderer

proc new*(T: typedesc[Drawing], renderer: SDL_Renderer): T =
  result = T(renderer: renderer)

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

proc draw*(self: Drawing, rect: Rect, fill = true, color = White) =
  var frect = SDL_FRect(
    x: rect.x,
    y: rect.y,
    w: rect.w,
    h: rect.h
  )
  self.setDrawColor color
  if fill:
    sdlCall SDL_RenderFillRect(self.renderer, addr frect)
  else:
    sdlCall SDL_RenderRect(self.renderer, addr frect)

proc drawText*(self: Drawing, x, y: float, text: string, color = White) =
  self.drawColor = color
  if self.currentFont.isNil:
    sdlCall SDL_RenderDebugText(self.renderer, x.cfloat, y.cfloat, text.cstring)
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
      x: x,
      y: y,
      w: surface.w.float32,
      h: surface.h.float32,
    )
    SDL_DestroySurface(surface) 
    SDL_RenderTexture(
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
