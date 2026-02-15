import std/options

# Options extended api 
template withIt*(o: Option, ident, blk: untyped) =
  if o.isSome:
    let ident {.inject.} = o.get()
    blk

template withIt*(o: Option, blk: untyped) =
  if o.isSome:
    let it {.inject.} = o.get()
    blk
