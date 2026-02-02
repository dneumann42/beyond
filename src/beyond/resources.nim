import std/[tables]
import sdl3_ttf

type
  AbstractResource* = ref object of RootObj
  Resource* [T] = ref object of AbstractResource
    data: T
    path: string
    name: string
  Font* = Resource[TTF_Font]
  Resources* = ref object
    mapping: Table[string, AbstractResource]

proc new*(T: typedesc[Resources]): T =
  T()

proc load*(resources: Resources, T: typedesc[Font],  path: string, name: string, fontSize: int = 12) =
  let font = TTF_OpenFont(path, cfloat(fontSize))
  resources.mapping[name] = AbstractResource Font(
    data: font, 
    path: path, 
    name: name
  )
  
proc get*(resources: Resources, T: typedesc[Font], name: string): TTF_Font =
  result = T(resources.mapping[name]).data
