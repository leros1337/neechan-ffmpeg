# neechan-ffmpeg

A trimmed build of [FFmpeg](https://ffmpeg.org) **n9.0.2** for Apple platforms,
packaged as xcframeworks behind a Swift package. Built for
[Neechan](https://github.com/leros1337/neechan), and useful to anything else
that needs to decode WebM on iOS without carrying a general-purpose media stack.

## Why

A general-purpose Apple FFmpeg distribution comes to well over a gigabyte,
most of it libraries an imageboard client never touches: SMB, SRT, Vulkan,
shader compilers, subtitle renderers, a whole second player. It is also built
with `--enable-gpl`, which forces the GPL on anything that links it.

This build contains the containers and codecs an imageboard actually serves and
nothing else, and it is configured without any GPL component, so what comes out
is **LGPL-2.1-or-later**.

## What is in it

| | |
|---|---|
| Demuxers | Matroska (WebM and MKV), MOV (MP4) |
| Muxer | MP4 |
| Video decoders | VP8, VP9, AV1, H.264, HEVC |
| Audio decoders | Vorbis, Opus, AAC, MP3, FLAC, ALAC, AC-3, E-AC-3, DTS, PCM |
| Encoders | H.264 (through VideoToolbox), AAC, PCM |
| Hardware | VideoToolbox decode for H.264, HEVC, VP9 and AV1, where the device has the decoder |
| Modules | `Libavcodec`, `Libavformat`, `Libavutil`, `Libswresample`, `Libswscale` |
| Slices | iOS arm64, iOS simulator arm64 and x86\_64, macOS arm64 and x86\_64 |

The AV1 decoder is FFmpeg's own, which decodes nothing in software: it is there
so that a device with an AV1 decoder can use it through VideoToolbox, and a
device without one is told so cleanly rather than left with a clip that never
starts. The audio list is what a Matroska file tends to hold outside a WebM.

Deliberately absent: networking and TLS, every filter, `libavdevice`,
`libpostproc`, and every external library except zlib. A client that fetches
bytes itself and hands them to the demuxer needs none of it.

Minimum platforms are iOS 26 and macOS 26, matching the app it was built for.

## Use

```swift
.package(url: "https://github.com/leros1337/neechan-ffmpeg.git", from: "9.0.2")
```

The manifest names the xcframework zips attached to that release, with their
checksums, so nothing is built on the consumer's side. To build it yourself
instead, clone, run `./build.sh` (about forty minutes on an M-series Mac) and
point the five binary targets back at `Artifacts/`:

```swift
.package(path: "../neechan-ffmpeg")
```

Either way, depend on the one product:

```swift
.product(name: "FFmpeg", package: "neechan-ffmpeg")
```

It carries all five modules and the system frameworks they must be linked
against. Import the modules individually:

```swift
import Libavcodec
import Libavformat
```

The headers sit flat inside each framework, which is what lets FFmpeg's own
`#include "libavutil/frame.h"` resolve: it is read as a framework include and
finds `Libavutil.framework/Headers/frame.h`. That match depends on the
filesystem ignoring the capital, which is the default on macOS.

## Rebuilding

```sh
./build.sh                  # every slice, into Artifacts/
./build.sh --slices ios     # one platform: ios, isimulator, macos
./build.sh --clean          # from a fresh FFmpeg checkout
./build.sh --release 9.0.2  # also zip each xcframework and print its checksum
```

Needs Xcode and, for the x86\_64 slices, `nasm` (`brew install nasm`). Without
it those slices are built without x86 assembly and the script says so.

The script clones FFmpeg at its release tag, applies one patch (the decoder
asks for OpenGL-compatible pixel buffers, which Apple has deprecated; it is
asked for Metal-compatible ones instead), configures each slice, and checks the
result before writing anything: that the licensing flags came out off, that
every codec and container asked for is present, and that nothing GPL was linked
in. A missing symbol fails the build rather than shipping quietly.

The configure line is in `build.sh` and is the authoritative record of what
this build contains.

### Releasing

Versions follow FFmpeg's: `9.0.2` is FFmpeg n9.0.2, and a rebuild of the same
FFmpeg with a changed configuration bumps the last number. Swift Package Manager
reads the manifest at the tag, so the tag has to point at a manifest that names
the zips it will find on the release. The order is therefore:

1. `./build.sh --release 9.0.2` here, which zips each xcframework into
   `Artifacts/` and prints its checksum.
2. Replace the `path:` binary targets in `Package.swift` with `url:` and
   `checksum:` entries pointing at
   `https://github.com/leros1337/neechan-ffmpeg/releases/download/9.0.2/<Name>.xcframework.zip`.
3. Commit, tag `9.0.2`, push the tag.
4. `gh release create 9.0.2 Artifacts/*.xcframework.zip` with the zips whose
   checksums the manifest names.

The workflow in `.github/workflows/release.yml` is run by hand and builds every
slice on a clean runner, uploading the result as a workflow artifact: the check
that the build reproduces. It does not create the release itself, since a zip
built elsewhere has a different checksum from the one the manifest names, and it
does not run on a tag push, so cutting a release costs no runner time.

## Licensing

The xcframeworks are FFmpeg, under the **LGPL-2.1-or-later**; the licence text
is in `LICENSE.LGPL-2.1`. `build.sh`, the package manifest and this document are
MIT. `LICENSE` states both.

The libraries are static, so an application that links them must let its users
relink it against a modified FFmpeg. Publishing the application's source
satisfies that, and so does shipping the object files. `build.sh` plus the
FFmpeg tag reproduces these binaries exactly, so citing this repository is
enough to say how they were made.
