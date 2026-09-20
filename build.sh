#!/usr/bin/env bash
#
# Builds a trimmed, LGPL FFmpeg for Apple platforms and lays it out as
# xcframeworks a Swift package can carry.
#
# Trimmed means: only the containers and codecs the app actually meets, the
# VideoToolbox hardware paths, and nothing else. No GPL components, no network
# stack, no filters, no external libraries but zlib. What comes out is a few
# tens of megabytes instead of the gigabyte-and-a-bit a general-purpose build
# takes, and it carries no obligation beyond the LGPL's.
#
# Usage:
#   ./build.sh                 build every slice into Artifacts/
#   ./build.sh --slices ios    build one platform (ios, isimulator, macos)
#   ./build.sh --release 9.0.2 also zip each xcframework and print its checksum
#   ./build.sh --clean         start from a fresh checkout
set -euo pipefail

FFMPEG_TAG="n9.0.2"
IOS_MIN="26.0"
MACOS_MIN="26.0"
LIBRARIES=(Libavcodec Libavformat Libavutil Libswresample Libswscale)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="$ROOT/build"
SRC="$BUILD/src"
OUT="$ROOT/Artifacts"

SLICES="ios isimulator macos"
RELEASE_TAG=""
CLEAN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --slices) SLICES="$2"; shift 2 ;;
        --release) RELEASE_TAG="$2"; shift 2 ;;
        --clean) CLEAN=1; shift ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

log() { printf '\033[1m==>\033[0m %s\n' "$*"; }

# --- the source ------------------------------------------------------------

if [[ $CLEAN -eq 1 ]]; then
    log "removing $BUILD"
    rm -rf "$BUILD"
fi

if [[ ! -d "$SRC" ]]; then
    log "cloning FFmpeg $FFMPEG_TAG"
    mkdir -p "$BUILD"
    git clone --depth 1 --branch "$FFMPEG_TAG" https://github.com/FFmpeg/FFmpeg.git "$SRC"
fi

# The decoder asks for pixel buffers that can be used by OpenGL, which Apple
# has deprecated and which a Metal renderer cannot take. Asking for Metal
# compatibility instead costs nothing and keeps the buffers usable either way.
if grep -q kCVPixelBufferOpenGLESCompatibilityKey "$SRC/libavcodec/videotoolbox.c"; then
    log "patching videotoolbox.c for Metal-compatible pixel buffers"
    sed -i '' \
        -e 's/kCVPixelBufferOpenGLESCompatibilityKey/kCVPixelBufferMetalCompatibilityKey/g' \
        -e 's/kCVPixelBufferIOSurfaceOpenGLTextureCompatibilityKey/kCVPixelBufferMetalCompatibilityKey/g' \
        "$SRC/libavcodec/videotoolbox.c"
fi

# --- what goes in ----------------------------------------------------------

# Containers: the Matroska demuxer reads both .webm and .mkv, and MOV covers
# MP4. The MP4 muxer is for the converter, which turns a WebM into something
# Photos will accept.
#
# Codecs: what the boards serve, plus what a Matroska file picked up elsewhere
# is likely to carry. A .webm is VP8 or VP9 with Vorbis or Opus and nothing
# else; a .mkv is the same container with anything at all in it, most often
# H.264, HEVC or AV1 alongside FLAC, AC-3 or DTS. Decoding all of them costs
# about a megabyte and saves a file that opens to a black screen.
#
# The only encoders are the ones the WebM converter writes with, and H.264 is
# written by VideoToolbox, so no GPL encoder is involved anywhere.
COMPONENTS=(
    --disable-everything
    --enable-demuxer=matroska,mov
    --enable-muxer=mp4
    --enable-protocol=file
    --enable-decoder=vp8,vp9,av1,h264,hevc
    --enable-decoder=vorbis,opus,aac,aac_latm,mp3,mp3float,flac,alac,ac3,eac3,dca
    --enable-decoder=pcm_s16le,pcm_s16be,pcm_s24le,pcm_f32le
    --enable-parser=vp8,vp9,av1,h264,hevc,opus,vorbis,aac,aac_latm,mpegaudio,flac,ac3,dca
    --enable-bsf=h264_mp4toannexb,hevc_mp4toannexb,extract_extradata,vp9_superframe,vp9_superframe_split
    --enable-encoder=h264_videotoolbox,aac,pcm_s16le
    --enable-hwaccel=h264_videotoolbox,hevc_videotoolbox,vp9_videotoolbox,av1_videotoolbox
    --enable-videotoolbox
    --enable-zlib
)

# Licensing: no --enable-gpl and no --enable-version3, so what comes out is
# LGPL-2.1-or-later. Nothing here needs either.
LICENSE_FLAGS=(--disable-gpl --disable-nonfree --disable-version3)

# Everything the app does not use. Networking is off because the app reads
# bytes itself, through its own URLSession, and hands them to the demuxer.
TRIM_FLAGS=(
    --disable-autodetect
    --disable-programs --disable-doc --disable-htmlpages --disable-manpages
    --disable-podpages --disable-txtpages
    --disable-avdevice --disable-avfilter
    --disable-network --disable-iconv --disable-bzlib --disable-lzma
    --disable-sdl2 --disable-schannel --disable-securetransport
    --disable-xlib --disable-libxcb --disable-debug
    --enable-stripping --enable-pic --enable-static --disable-shared
    --enable-optimizations --enable-runtime-cpudetect
)

# --- one slice -------------------------------------------------------------

sdk_for() {
    case "$1" in
        ios) echo iphoneos ;;
        isimulator) echo iphonesimulator ;;
        macos) echo macosx ;;
    esac
}

target_for() {
    local platform="$1" arch="$2"
    case "$platform" in
        ios) echo "${arch}-apple-ios${IOS_MIN}" ;;
        isimulator) echo "${arch}-apple-ios${IOS_MIN}-simulator" ;;
        macos) echo "${arch}-apple-macos${MACOS_MIN}" ;;
    esac
}

archs_for() {
    case "$1" in
        ios) echo "arm64" ;;
        *) echo "arm64 x86_64" ;;
    esac
}

build_slice() {
    local platform="$1" arch="$2"
    local prefix="$BUILD/install/$platform/$arch"
    local work="$BUILD/work/$platform/$arch"

    if [[ -f "$prefix/lib/libavcodec.a" ]]; then
        log "$platform/$arch already built"
        return
    fi

    local sdk sdk_path target
    sdk="$(sdk_for "$platform")"
    sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"
    target="$(target_for "$platform" "$arch")"

    local asm_flag=()
    if [[ "$arch" == "x86_64" ]] && ! command -v nasm >/dev/null 2>&1; then
        echo "note: nasm is missing, building $platform/$arch without x86 assembly" >&2
        asm_flag=(--disable-x86asm)
    fi

    log "configuring $platform/$arch ($target)"
    mkdir -p "$work"
    (
        cd "$work"
        "$SRC/configure" \
            --prefix="$prefix" \
            --target-os=darwin \
            --arch="$arch" \
            --enable-cross-compile \
            --cc="xcrun -sdk $sdk clang" \
            --cxx="xcrun -sdk $sdk clang++" \
            --ar="xcrun -sdk $sdk ar" \
            --ranlib="xcrun -sdk $sdk ranlib" \
            --extra-cflags="-target $target -isysroot $sdk_path -fno-common -O3" \
            --extra-ldflags="-target $target -isysroot $sdk_path" \
            "${LICENSE_FLAGS[@]}" "${TRIM_FLAGS[@]}" "${COMPONENTS[@]}" \
            ${asm_flag[@]+"${asm_flag[@]}"} >configure.log 2>&1 \
            || { echo "configure failed for $platform/$arch:" >&2; tail -30 configure.log >&2; exit 1; }

        log "building $platform/$arch"
        make -j"$(sysctl -n hw.ncpu)" >make.log 2>&1 \
            || { echo "make failed for $platform/$arch:" >&2; tail -30 make.log >&2; exit 1; }
        make install >>make.log 2>&1
    )
}

# --- frameworks ------------------------------------------------------------

# A framework whose headers sit flat, the way the xcframeworks this replaces
# laid them out. FFmpeg's headers include each other as "libavutil/frame.h",
# which resolves as a framework include to Libavutil.framework/Headers/frame.h
# because the filesystem does not mind the capital. That is what makes the flat
# layout work, and why the framework names keep their capital Lib.
make_framework() {
    local name="$1" platform="$2" dir="$3"
    local lower
    lower="$(echo "$name" | tr '[:upper:]' '[:lower:]')"
    local framework="$dir/$name.framework"

    rm -rf "$framework"
    mkdir -p "$framework/Headers" "$framework/Modules"

    local inputs=()
    for arch in $(archs_for "$platform"); do
        inputs+=("$BUILD/install/$platform/$arch/lib/$lower.a")
    done
    lipo -create "${inputs[@]}" -output "$framework/$name"

    local first_arch
    first_arch="$(archs_for "$platform" | awk '{print $1}')"
    cp "$BUILD/install/$platform/$first_arch/include/$lower/"*.h "$framework/Headers/"

    local bundle_platform min_version
    case "$platform" in
        ios) bundle_platform=iPhoneOS; min_version="$IOS_MIN" ;;
        isimulator) bundle_platform=iPhoneSimulator; min_version="$IOS_MIN" ;;
        macos) bundle_platform=MacOSX; min_version="$MACOS_MIN" ;;
    esac

    cat > "$framework/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>$name</string>
    <key>CFBundleIdentifier</key><string>io.neechan.ffmpeg.$name</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>$name</string>
    <key>CFBundlePackageType</key><string>FMWK</string>
    <key>CFBundleShortVersionString</key><string>${FFMPEG_TAG#n}</string>
    <key>CFBundleVersion</key><string>${FFMPEG_TAG#n}</string>
    <key>CFBundleSupportedPlatforms</key><array><string>$bundle_platform</string></array>
    <key>MinimumOSVersion</key><string>$min_version</string>
</dict>
</plist>
PLIST

    # Headers that describe hardware this platform does not have, or that need
    # a header only another operating system ships. They are installed because
    # FFmpeg installs them; including them in the module would fail to compile.
    local excludes=""
    for header in "$framework/Headers"/*.h; do
        case "$(basename "$header")" in
            vdpau.h|qsv.h|dxva2.h|d3d11va.h|xvmc.h|mediacodec.h|jni.h|\
            hwcontext_vdpau.h|hwcontext_vaapi.h|hwcontext_qsv.h|hwcontext_opencl.h|\
            hwcontext_dxva2.h|hwcontext_d3d11va.h|hwcontext_d3d12va.h|hwcontext_cuda.h|\
            hwcontext_vulkan.h|hwcontext_mediacodec.h|hwcontext_drm.h|hwcontext_amf.h|\
            hwcontext_oh.h|vulkan.h)
                excludes+="    exclude header \"$(basename "$header")\"
"
                ;;
        esac
    done

    cat > "$framework/Modules/module.modulemap" <<MODULEMAP
framework module $name [system] {
    umbrella "."
$excludes    export *
}
MODULEMAP
}

# --- run -------------------------------------------------------------------

for platform in $SLICES; do
    for arch in $(archs_for "$platform"); do
        build_slice "$platform" "$arch"
    done
done

log "assembling xcframeworks"
mkdir -p "$OUT"
for name in "${LIBRARIES[@]}"; do
    args=()
    for platform in $SLICES; do
        dir="$BUILD/frameworks/$platform"
        mkdir -p "$dir"
        make_framework "$name" "$platform" "$dir"
        args+=(-framework "$dir/$name.framework")
    done
    rm -rf "$OUT/$name.xcframework"
    xcodebuild -create-xcframework "${args[@]}" -output "$OUT/$name.xcframework" >/dev/null
    echo "  $name.xcframework"
done

# --- what it must contain --------------------------------------------------

log "checking the result"
CONFIG_H="$BUILD/work/$(echo "$SLICES" | awk '{print $1}')/arm64/config.h"
for setting in "CONFIG_GPL 0" "CONFIG_VERSION3 0" "CONFIG_AVDEVICE 0" \
               "CONFIG_AVFILTER 0" "CONFIG_NETWORK 0" "CONFIG_VIDEOTOOLBOX 1"; do
    grep -q "^#define $setting\$" "$CONFIG_H" \
        || { echo "FAIL: expected '$setting' in config.h" >&2; exit 1; }
done

# Symbols are dumped once per library and then read from the file: piping nm
# straight into a grep that stops at the first match kills nm with SIGPIPE,
# which under `set -o pipefail` reads as a failure whether or not it matched.
first_slice="$(echo "$SLICES" | awk '{print $1}')"
slice_dir="$BUILD/frameworks/$first_slice"
symbols="$BUILD/symbols"
mkdir -p "$symbols"
for name in Libavcodec Libavformat; do
    nm -g "$slice_dir/$name.framework/$name" 2>/dev/null > "$symbols/$name.defined" || true
    nm -u "$slice_dir/$name.framework/$name" 2>/dev/null > "$symbols/$name.undefined" || true
done

require_symbol() {
    grep -q "_$2\$" "$symbols/$1.defined" \
        || { echo "FAIL: $2 is missing from $1" >&2; exit 1; }
}

for symbol in ff_h264_videotoolbox_encoder ff_aac_encoder ff_h264_videotoolbox_hwaccel \
              ff_hevc_videotoolbox_hwaccel ff_vp9_videotoolbox_hwaccel ff_av1_videotoolbox_hwaccel \
              ff_vp8_decoder ff_vp9_decoder ff_av1_decoder ff_h264_decoder ff_hevc_decoder \
              ff_opus_decoder ff_vorbis_decoder ff_mp3float_decoder ff_aac_decoder \
              ff_flac_decoder ff_alac_decoder ff_ac3_decoder ff_eac3_decoder ff_dca_decoder; do
    require_symbol Libavcodec "$symbol"
done
for symbol in ff_matroska_demuxer ff_mov_demuxer ff_mp4_muxer; do
    require_symbol Libavformat "$symbol"
done

# Nothing GPL, and nothing that would drag in a library this build does not
# ship. A leftover reference here would only show up as a link failure in
# whatever app adopted the package.
for forbidden in gnutls_ smbc_ srt_ x264_ x265_ dav1d_; do
    if grep -q "$forbidden" "$symbols/Libavformat.undefined" "$symbols/Libavcodec.undefined"; then
        echo "FAIL: a library still refers to $forbidden" >&2
        exit 1
    fi
done
echo "  licensing, codecs and containers are as expected"

du -sh "$OUT"/*.xcframework

# --- release -------------------------------------------------------------

if [[ -n "$RELEASE_TAG" ]]; then
    log "zipping for release $RELEASE_TAG"
    ( cd "$OUT"
      for name in "${LIBRARIES[@]}"; do
          rm -f "$name.xcframework.zip"
          zip -qry "$name.xcframework.zip" "$name.xcframework"
          printf '%-16s %s\n' "$name" "$(swift package compute-checksum "$name.xcframework.zip")"
      done )
fi

log "done"
