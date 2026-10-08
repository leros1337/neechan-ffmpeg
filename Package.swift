// swift-tools-version: 6.2
import PackageDescription

// A trimmed, LGPL build of FFmpeg for Apple platforms.
//
// Only what an imageboard client meets: Matroska (WebM and MKV), MP4 and AVI
// in; VP8, VP9, AV1, H.264, HEVC and MPEG-4 Part 2 decoded, with VideoToolbox
// used wherever the device has a decoder; Vorbis, Opus, AAC, MP3 and the audio
// a Matroska file tends to hold (FLAC, ALAC, AC-3, DTS, PCM); and H.264
// written back through VideoToolbox for the WebM-to-MP4 conversion Photos
// insists on. No GPL components, no networking, no filters, no external
// libraries but zlib.
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
            url: "https://github.com/leros1337/neechan-ffmpeg/releases/download/9.0.4/Libavcodec.xcframework.zip",
            checksum: "0c9c6f2afbad045a7ff6f94368134171e30fec706842ec624ae46e49a4f9b8a0"
        ),
        .binaryTarget(
            name: "Libavformat",
            url: "https://github.com/leros1337/neechan-ffmpeg/releases/download/9.0.4/Libavformat.xcframework.zip",
            checksum: "370327fbbc045546bb675658edf13ad65337425920983f6b22dc7d92d4cf9aa1"
        ),
        .binaryTarget(
            name: "Libavutil",
            url: "https://github.com/leros1337/neechan-ffmpeg/releases/download/9.0.4/Libavutil.xcframework.zip",
            checksum: "233dfc46ed1da7585042c74eb1eefec443a72a10bde2b3f959585b17efd94651"
        ),
        .binaryTarget(
            name: "Libswresample",
            url: "https://github.com/leros1337/neechan-ffmpeg/releases/download/9.0.4/Libswresample.xcframework.zip",
            checksum: "716b4ca1c45b6754e7a94113549a5724cec514bfa9a4865cc64051df50db050b"
        ),
        .binaryTarget(
            name: "Libswscale",
            url: "https://github.com/leros1337/neechan-ffmpeg/releases/download/9.0.4/Libswscale.xcframework.zip",
            checksum: "5f9ec8e9f64b36c0197bb5fbd19d6e016519ed6cbe84258203acbd4e41bbb1a8"
        )
    ]
)
