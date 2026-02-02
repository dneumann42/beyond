# SDL3_image Setup

## Overview

SDL3_image bindings have been added to the Beyond framework for loading images (PNG, JPG, etc.). **SDL3_image is now required** for the Beyond framework.

## Installation

### Installing SDL3_image

SDL3_image is not yet widely available in package managers. You may need to build it from source:

```bash
git clone https://github.com/libsdl-org/SDL_image.git
cd SDL_image
mkdir build && cd build
cmake .. -DSDL3IMAGE_INSTALL=ON
make
sudo make install
```

## Features

### Automatic Initialization

SDL_image is automatically:
- **Initialized** during application startup (in `SDL_AppInit`)
- **Cleaned up** during application shutdown (in `SDL_AppQuit`)

No manual initialization required in your code!

### Available Functions

```nim
import beyond

# Load an image (returns SDL_Surface)
let surface = IMG_Load("path/to/image.png")

# Convert surface to texture
let texture = SDL_CreateTextureFromSurface(renderer, surface)

# Free the surface
SDL_FreeSurface(surface)
```

### Tilesheet Generation

The `generateTilesheet` function creates a tilesheet from a directory of images:

```nim
import beyond

# Generate tilesheet from images
let tilesheet = generateTilesheet(
  renderer,
  sourceDir = "assets/tiles",
  tileWidth = 32,
  tileHeight = 32
)

# Access tile information
for tile in tilesheet.tiles:
  echo "Tile: ", tile.filename
  echo "  Position: (", tile.x, ", ", tile.y, ")"
  echo "  Index: ", tile.index
```

## Tilemap Ordering Solution

To maintain stable tile ordering when renaming files, use **numeric prefixes**:

```
tiles/
  000_grass.png
  001_water.png
  002_stone.png
```

When renaming:
- ✓ `000_grass.png` → `000_green_grass.png` (keeps same position)
- ✗ `grass.png` → `green_grass.png` (position changes due to alphabetical sort)

The `generateTilesheet` function sorts files alphabetically, so the numeric prefix ensures consistent ordering.

## Current Limitations

- Tilesheet generation currently only collects metadata (doesn't create combined texture yet)
- Only PNG format is initialized by default
- Requires SDL3_image to be installed on the system

## Future Enhancements

- [ ] Complete texture atlas generation (combine tiles into single texture)
- [ ] Support for additional image formats (JPG, WEBP, etc.)
- [ ] Metadata file support for stable tile IDs
- [ ] Animation frame support
