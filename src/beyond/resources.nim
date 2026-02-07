import std/[tables, logging]
import sdl3, sdl3_ttf, sdl3_image

type
  AbstractResource* = ref object of RootObj

  Resource* [T] = ref object of AbstractResource
    data: T
    path: string
    name: string

  Font* = Resource[TTF_Font]
  Texture* = Resource[SDL_Texture]

  Resources* = ref object
    renderer: SDL_Renderer
    mapping: Table[string, AbstractResource]

proc new*(T: typedesc[Resources], renderer: SDL_Renderer): T =
  T(renderer: renderer)

proc load*(resources: Resources, T: typedesc[Font],  path: string, name: string, fontSize: int = 12) =
  let font = TTF_OpenFont(path, cfloat(fontSize))
  resources.mapping[name] = AbstractResource Font(
    data: font, 
    path: path, 
    name: name
  )
  info "Loaded font: " & name
  
proc get*(resources: Resources, T: typedesc[Font], name: string): TTF_Font =
  result = T(resources.mapping[name]).data

proc load*(resources: Resources, T: typedesc[Texture],  path: string, name: string, fontSize: int = 12) =
  let tex = IMG_Load(path.cstring)
  if tex.isNil:
    echo SDL_GetError()
    return
  defer: SDL_DestroySurface(tex)
  resources.mapping[name] = AbstractResource Texture(
    data: SDL_CreateTextureFromSurface(resources.renderer, tex),
    path: path, 
    name: name
  )
  info "Loaded texture: " & name
    
proc get*(resources: Resources, T: typedesc[Texture], name: string): SDL_Texture =
  result = T(resources.mapping[name]).data
