import bumpy, chroma, log
export bumpy, chroma

import sdl3

# This library currently uses the SDL3 renderer, its very simple, can't do rotated rectangles.
# later goal is to develop a powerful renderer using the SDL3 graphics api. my goal is that the current api
# wont change much when introducing the new renderer

const
  White* = parseHtmlColor "#FFFFFF"

type
  Drawing* = ref object
    renderer: SDL_Renderer

proc new*(T: typedesc[Drawing], renderer: SDL_Renderer): T =
  result = T(renderer: renderer)

proc setDrawColor*(self: Drawing, color = White) =
  sdlCall SDL_SetRenderDrawColorFloat(self.renderer, color.r, color.g, color.b, color.a)

proc draw*(self: Drawing, rect: Rect, color = White) =
  var frect = SDL_FRect(
    x: rect.x,
    y: rect.y,
    w: rect.w,
    h: rect.h
  )
  self.setDrawColor color
  sdlCall SDL_RenderFillRect(self.renderer, addr frect)
