import std/[sequtils, os]

# Package
version       = "0.1.0"
author        = "Michael Schwager"
description   = "Blocks"
license       = "MIT"
srcDir        = "src"
binDir        = "bin"
bin           = @["blocks"]

# Dependencies

requires "nim >= 2.2.6"
requires "wNim"
requires "sdl2"
requires "pixie"


type SdlAsset = tuple[name: string, url: string, dllNames: seq[string]]

const sdlAssets: seq[SdlAsset] = @[
  ("SDL2",       "https://github.com/libsdl-org/SDL/releases/download/release-2.30.9/SDL2-2.30.9-win32-x64.zip",           @["SDL2.dll"      ]),
  ("SDL2_ttf",   "https://github.com/libsdl-org/SDL_ttf/releases/download/release-2.24.0/SDL2_ttf-2.24.0-win32-x64.zip",   @["SDL2_ttf.dll"  ]),
  ("SDL2_image", "https://github.com/libsdl-org/SDL_image/releases/download/release-2.8.8/SDL2_image-2.8.8-win32-x64.zip", @["SDL2_image.dll"]),
]

proc fetchSdlAsset(asset: SdlAsset) =
  when defined(windows):
    mkDir binDir
    let allPresent = asset.dllNames.len > 0 and asset.dllNames.allIt(fileExists(binDir / it))
    if allPresent:
      echo asset.name & " already present -- skipping"
    else:
      let zipName = asset.name & "_tmp.zip"
      exec "curl -L " & asset.url & " -o " & zipName
      exec "tar -xf " & zipName  # extract everything; sort out which files you need
      for dll in asset.dllNames:
        mvFile dll, binDir / dll
      rmFile zipName

task setupDeps, "Download SDL2/SDL2_ttf/SDL2_image DLLs (Windows)":
  for asset in sdlAssets:
    fetchSdlAsset(asset)