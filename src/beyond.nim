import beyond/[application, plugins, drawing, sdl3_image, sdl3_ttf, tilesheets, resources]
export application, plugins, drawing, sdl3_image, sdl3_ttf, tilesheets, resources

import beyond/inputs
export inputs

import std/[options]
export options

# Options extended api 
template withIt*(o: Option, ident, blk: untyped) =
  if o.isSome:
    let ident {.inject.} = o.get()
    blk

template withIt*(o: Option, blk: untyped) =
  if o.isSome:
    let it {.inject.} = o.get()
    blk

