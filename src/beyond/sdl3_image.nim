## SDL3_image Bindings

import sdl3

{.passL: "-lSDL3_image".}

# Image loading functions
proc IMG_Load*(file: cstring): SDL_Surface {.importc, cdecl.}
proc IMG_SavePNG*(surface: SDL_Surface, file: cstring): bool {.importc: "IMG_SavePNG", cdecl.}


proc SDL_BlitSurface*(src: SDL_Surface, srcrect: ptr SDL_Rect, dst: SDL_Surface, dstrect: ptr SDL_Rect): cint {.importc, cdecl.}

# IMG_Init flags
const
  IMG_INIT_JPG* = 0x00000001
  IMG_INIT_PNG* = 0x00000002
  IMG_INIT_TIF* = 0x00000004
  IMG_INIT_WEBP* = 0x00000008
  IMG_INIT_JXL* = 0x00000010
  IMG_INIT_AVIF* = 0x00000020
