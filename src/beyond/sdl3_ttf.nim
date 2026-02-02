import sdl3

{.passL: "-lSDL3_ttf".}

type
  TTF_Font* = ptr object

proc TTF_Init*(): bool {.importc, cdecl.}

proc TTF_OpenFont*(file: cstring, ptsize: cfloat): TTF_Font {.importc, cdecl.}
proc TTF_GetFontHeight*(font: TTF_Font): cint {.importc, cdecl.}

proc TTF_RenderText_Blended*(font: TTF_Font, text: cstring, length: csize_t, fg: SDL_Color): SDL_Surface {.importc, cdecl.}

proc TTF_MeasureString*(
  font: TTF_Font, 
  text: cstring, 
  length: csize_t,
  maxWidth: cint,
  measuredWidth: ptr cint,
  measuredLength: ptr csize_t
): bool {.importc, cdecl.}
