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
            url: "https://github.com/leros1337/neechan-ffmpeg/releases/download/9.0.2/Libavcodec.xcframework.zip",
            checksum: "816d57893e68a584ebd480b6b278c1d0775b1911308547dfea80522f145218e7"
        ),
        .binaryTarget(
            name: "Libavformat",
            url: "https://github.com/leros1337/neechan-ffmpeg/releases/download/9.0.2/Libavformat.xcframework.zip",
            checksum: "1c8431299c0c940004fe21a15465fd8399b4e26edd041208af6b500d7bdde396"
        ),
        .binaryTarget(
            name: "Libavutil",
            url: "https://github.com/leros1337/neechan-ffmpeg/releases/download/9.0.2/Libavutil.xcframework.zip",
            checksum: "de20412f31b418cb6dd6684c26bdfaaa2ca2bc6b5c10edd0de0239e16883120e"
        ),
        .binaryTarget(
            name: "Libswresample",
            url: "https://github.com/leros1337/neechan-ffmpeg/releases/download/9.0.2/Libswresample.xcframework.zip",
            checksum: "246bc732043f728c0ef3d9a9826e48b93f61a6aebb1fb51bcc3ba5bd2ca088d0"
        ),
        .binaryTarget(
            name: "Libswscale",
            url: "https://github.com/leros1337/neechan-ffmpeg/releases/download/9.0.2/Libswscale.xcframework.zip",
            checksum: "ed138d2421073ddf96ed1e274352f61988f9d28fa816586c3a9691a07a27abd4"
        )
    ]
)
