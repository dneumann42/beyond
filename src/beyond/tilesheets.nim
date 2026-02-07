# generate tilesheets from lists of images

import std/[strutils, os, sequtils, algorithm, tables, math]
import sdl3, sdl3_image, log

const
  TILE_SIZE* = 32

type
  TileInfo* = object
    filename*: string
    x*, y*: int
    width*, height*: int
    index*: int

  Tilesheet* = object
    texture*: SDL_Texture
    tiles*: seq[TileInfo]
    textureWidth*: int
    textureHeight*: int
    
  DecomposedTile = object
    srcSurface: SDL_Surface
    srcRect: SDL_Rect
    filename: string

proc nextPowerOf2(n: int): int =
  ## Returns the next power of 2 >= n
  result = 1
  while result < n:
    result = result shl 1

proc generateTilesheet*(renderer: SDL_Renderer, sourceDir: string, outputPath: string = ""): Tilesheet =
  ## Generate a tilesheet texture from a directory of image files
  ## Images can be different sizes and are packed left-to-right, top-to-bottom
  ## Final texture size is a power of 2

  # Collect all PNG files
  var files = newSeq[string]()
  try:
    for kind, path in walkDir(sourceDir):
      if kind != pcFile:
        continue
      if not path.endsWith ".png":
        continue
      files.add(path)
  except OSError:
    error "Failed to read directory: ", sourceDir
    return

  if files.len == 0:
    warn "No PNG files found in: ", sourceDir
    return

  # Sort files alphabetically for consistent ordering
  files.sort()

  info "Loading ", files.len, " tiles..."

  # Load all images and get their sizes for packing
  var allDecomposedTiles = newSeq[DecomposedTile]()
  var originalSurfacesToFree = newSeq[SDL_Surface]() # To keep track of surfaces to free later

  for file in files:
    info "Attempting to load: ", file
    let surface = IMG_Load(file.cstring)
    if surface.isNil:
      warn "Failed to load: ", file
      continue
    
    info "Loaded ", file, " with dimensions: ", surface.w, "x", surface.h

    # Validate dimensions are multiples of TILE_SIZE
    if surface.w.int mod TILE_SIZE != 0 or surface.h.int mod TILE_SIZE != 0:
      warn "Image ", file, " dimensions (", surface.w, "x", surface.h, ") are not multiples of TILE_SIZE (", TILE_SIZE, "). Skipping."
      SDL_DestroySurface(surface)
      continue

    originalSurfacesToFree.add(surface) # Add to list to free later

    let tilesX = surface.w.int div TILE_SIZE
    let tilesY = surface.h.int div TILE_SIZE
    info "Decomposing into ", tilesX * tilesY, " tiles (", tilesX, "x", tilesY, ")"

    for y in 0 ..< tilesY:
      for x in 0 ..< tilesX:
        allDecomposedTiles.add(DecomposedTile(
          srcSurface: surface,
          srcRect: SDL_Rect(x: (x * TILE_SIZE).cint, y: (y * TILE_SIZE).cint, w: TILE_SIZE.cint, h: TILE_SIZE.cint),
          filename: file.extractFilename()
        ))

  if allDecomposedTiles.len == 0:
    error "No 32x32 tiles could be loaded or decomposed from source images."
    # Free any surfaces loaded before this error
    for surface in originalSurfacesToFree:
      SDL_DestroySurface(surface)
    return

  info "Loaded and decomposed ", allDecomposedTiles.len, " 32x32 tiles."

  # Calculate new tilesheet dimensions based on packing 32x32 tiles
  # Aim for a somewhat square layout
  let numTiles = allDecomposedTiles.len
  let tilesheetMaxCols = 32 # Max 32 tiles wide for the tilesheet (1024 pixels)
  var tilesheetCols = min(numTiles, tilesheetMaxCols)
  if tilesheetCols == 0: tilesheetCols = 1 # Avoid division by zero if no tiles

  let tilesheetRows = (numTiles + tilesheetCols - 1) div tilesheetCols # Ceiling division

  result.textureWidth = nextPowerOf2(tilesheetCols * TILE_SIZE)
  result.textureHeight = nextPowerOf2(tilesheetRows * TILE_SIZE)
  
  info "Tilesheet size: ", result.textureWidth, "x", result.textureHeight, " (", allDecomposedTiles.len, " tiles)"
  # Create the tilesheet surface
  let tilesheetSurface = SDL_CreateSurface(
    result.textureWidth.cint,
    result.textureHeight.cint,
    SDL_PIXELFORMAT_RGBA32
  )

  if tilesheetSurface.isNil:
    error "Failed to create tilesheet surface"
    for surface in originalSurfacesToFree:
      SDL_DestroySurface(surface)
    return

  # Pack 32x32 tiles onto the tilesheet surface
  var currentX = 0
  var currentY = 0
  var colCounter = 0

  for i, dTile in allDecomposedTiles:
    # Calculate destination rectangle on the tilesheet
    var dstRect = SDL_Rect(
      x: (currentX * TILE_SIZE).cint,
      y: (currentY * TILE_SIZE).cint,
      w: TILE_SIZE.cint,
      h: TILE_SIZE.cint
    )

    discard SDL_BlitSurface(dTile.srcSurface, addr dTile.srcRect, tilesheetSurface, addr dstRect)

    # Store tile info (always 32x32 for tilesheet tiles)
    result.tiles.add(TileInfo(
      filename: dTile.filename,
      x: dstRect.x.int,
      y: dstRect.y.int,
      width: TILE_SIZE,
      height: TILE_SIZE,
      index: i
    ))

    # Move to the next position on the tilesheet
    inc currentX
    inc colCounter
    if colCounter >= tilesheetCols: # Wrap to next row
      currentX = 0
      currentY += 1
      colCounter = 0
  
  # Free all original loaded surfaces
  for surface in originalSurfacesToFree:
    SDL_DestroySurface(surface)

  # Save as BMP if output path provided
  if outputPath.len > 0:
    try:
      createDir(outputPath.parentDir())
    except OSError:
      discard

    let pngOutputPath = outputPath.changeFileExt(".png")

    if not IMG_SavePNG(tilesheetSurface, pngOutputPath.cstring):
      warn "Failed to save tilesheet PNG: ", pngOutputPath
    else:
      info "Saved tilesheet to: ", pngOutputPath
  # Convert surface to texture
  result.texture = SDL_CreateTextureFromSurface(renderer, tilesheetSurface)
  SDL_DestroySurface(tilesheetSurface)

  if result.texture.isNil:
    error "Failed to create texture from tilesheet surface"
    return

  info "Tilesheet generated successfully with ", allDecomposedTiles.len, " tiles"

proc createSpriteSheet*(dir: string, output: string) =
  var
    surfaces = newSeq[SDL_Surface]()
    maxWidth = 0
    height = 0

  for (kind, path) in walkDir(dir):
    if kind != pcFile or not path.endsWith(".png"):
      continue
    let surface = IMG_Load(path.cstring)
    surfaces.add(surface)
    maxWidth = max(maxWidth, surface.w.int)
    height += surface.h.int
  
  let
    textureWidth = nextPowerOf2(maxWidth)
    textureHeight = nextPowerOf2(height)

  var cursorY = 0
  for surface in surfaces:
    
    cursorY += surface.h.int

  echo "TEXTURES: ", textureWidth, " ", textureHeight

