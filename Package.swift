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
// The xcframeworks are produced by `./build.sh` from FFmpeg's own sources.
// See README.md for the exact configure line and how to rebuild them.
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
        .binaryTarget(name: "Libavcodec", path: "Artifacts/Libavcodec.xcframework"),
        .binaryTarget(name: "Libavformat", path: "Artifacts/Libavformat.xcframework"),
        .binaryTarget(name: "Libavutil", path: "Artifacts/Libavutil.xcframework"),
        .binaryTarget(name: "Libswresample", path: "Artifacts/Libswresample.xcframework"),
        .binaryTarget(name: "Libswscale", path: "Artifacts/Libswscale.xcframework")
    ]
)
