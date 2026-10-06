// swift-tools-version: 6.2
import PackageDescription

// A trimmed, LGPL build of FFmpeg for Apple platforms.
//
// Only what an imageboard client meets: Matroska (WebM and MKV) and MP4 in;
// VP8, VP9, AV1, H.264 and HEVC decoded, with VideoToolbox used wherever the
// device has a decoder; Vorbis, Opus, AAC, MP3 and the audio a Matroska file
// tends to hold (FLAC, ALAC, AC-3, DTS, PCM); and H.264 written back through
// VideoToolbox for the WebM-to-MP4 conversion Photos insists on. No GPL
// components, no networking, no filters, no external libraries but zlib.
//
// The xcframeworks are produced by `./build.sh` from FFmpeg's own sources and
// attached to the release this manifest names. See README.md for the exact
// configure line, how to rebuild them, and how a release is cut.
let package = Package(
    name: "neechan-ffmpeg",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        // Everything at once: the five modules plus the frameworks they have
        // to be linked against. Import the modules individually
        // (`import Libavcodec`); depend on this one product.
        .library(
            name: "FFmpeg",
            targets: [
                "FFmpegLinkage",
                "Libavcodec", "Libavformat", "Libavutil", "Libswresample", "Libswscale"
            ]
        )
    ],
    targets: [
        // Binary targets cannot say what they need linking against, so this
        // empty target carries it for them. Anything that links FFmpeg gets
        // the system frameworks its VideoToolbox and CoreMedia paths call
        // into, and zlib for Matroska's compressed headers.
        .target(
            name: "FFmpegLinkage",
            dependencies: [
                "Libavcodec", "Libavformat", "Libavutil", "Libswresample", "Libswscale"
            ],
            linkerSettings: [
                .linkedFramework("AudioToolbox"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("Foundation"),
                .linkedFramework("VideoToolbox"),
                .linkedFramework("CoreServices", .when(platforms: [.macOS])),
                .linkedLibrary("z")
            ]
        ),
        .binaryTarget(
            name: "Libavcodec",
            url: "https://github.com/leros1337/neechan-ffmpeg/releases/download/9.0.3/Libavcodec.xcframework.zip",
            checksum: "1973d276f5ac9cfcf7e76e6bd8c6f8670c9105e8239fe44e9d733b952caf3e58"
        ),
        .binaryTarget(
            name: "Libavformat",
            url: "https://github.com/leros1337/neechan-ffmpeg/releases/download/9.0.3/Libavformat.xcframework.zip",
            checksum: "6f6fd3febf975c7c9377f44bfbd577c3b14dbb2047d430b05779bd723d96f838"
        ),
        .binaryTarget(
            name: "Libavutil",
            url: "https://github.com/leros1337/neechan-ffmpeg/releases/download/9.0.3/Libavutil.xcframework.zip",
            checksum: "12c2beeec0c1a2a78ad4f1d2e6bd5c759bc4859c93a54129a6a9907cd7904d0f"
        ),
        .binaryTarget(
            name: "Libswresample",
            url: "https://github.com/leros1337/neechan-ffmpeg/releases/download/9.0.3/Libswresample.xcframework.zip",
            checksum: "1fda83a90e62cb682e57a454dfb4c1303565bdd34d76d1aeb5c614e54844c0ad"
        ),
        .binaryTarget(
            name: "Libswscale",
            url: "https://github.com/leros1337/neechan-ffmpeg/releases/download/9.0.3/Libswscale.xcframework.zip",
            checksum: "427da5d594637bdd0c4d24f7f44851a8e5d81f98729ec1141f54862db56eace5"
        )
    ]
)
