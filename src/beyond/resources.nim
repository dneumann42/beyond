import std/[tables, logging, json, strformat]
import sdl3, sdl3_ttf, sdl3_image
import beyond/spriteAnimations as sp
import drawing

type
  AbstractResource* = ref object of RootObj

  Resource* [T] = ref object of AbstractResource
    data: T
    path: string
    name: string

  Font* = Resource[TTF_Font]
  Texture* = Resource[SDL_Texture]
  Animation* = Resource[sp.Animation]

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

  let texture = SDL_CreateTextureFromSurface(resources.renderer, tex)
  # Set to nearest-neighbor filtering for pixel-perfect rendering
  discard SDL_SetTextureScaleMode(texture, SDL_SCALEMODE_NEAREST)

  resources.mapping[name] = AbstractResource Texture(
    data: texture,
    path: path,
    name: name
  )
  info "Loaded texture: " & name
    
proc get*(resources: Resources, T: typedesc[Texture], name: string): SDL_Texture =
  result = T(resources.mapping[name]).data

proc setTextureFiltering*(resources: Resources, name: string, filtering: ScaleMode) =
  ## Set the filtering mode for a loaded texture
  ## Nearest = sharp/pixelated, Linear = smooth/blended
  let texture = resources.get(Texture, name)
  setTextureFiltering(texture, filtering)

proc load*(resources: Resources, T: typedesc[Animation], path, name: string) =
  let js = readFile(path).parseJson()
  let anim = load(sp.Animation, js)

  # Store animation with .json suffix to avoid key collision with texture
  let animKey = name & ".json"
  resources.mapping[animKey] = AbstractResource Animation(
    data: anim,
    path: path,
    name: animKey
  )

  # Automatically load the corresponding texture PNG
  # Derive PNG path from JSON path (e.g., "path/anim.json" -> "path/anim.png")
  let pngPath = path[0..^6] & ".png"  # Replace .json with .png
  resources.load(Texture, pngPath, name)

  info "Loaded animation: " & animKey

proc get*(resources: Resources, T: typedesc[Animation], name: string): sp.Animation =
  # Append .json suffix when getting animations
  result = T(resources.mapping[name & ".json"]).data
