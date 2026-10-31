# DJILutStudio

Native macOS SwiftUI application for the DJI LUT Studio workflow. The project targets macOS 26 and Swift 6.

## Build

Open `DJILutStudio.xcodeproj` in Xcode and build the `DJILutStudio` scheme. Video export uses a locally installed FFmpeg executable (`brew install ffmpeg`). The bundled `lut_manifest.json` and `lut_library` are taken from DJI-LUT-Studio-V2.

The app supports video import and drag and drop, filename based device profile suggestions, bundled DJI/creative LUT selection, look adjustments, HEVC/H.264/ProRes export settings, sharpening, and output folder selection. Gyroflow remains an optional integration point; the current export pipeline applies LUTs and encode settings directly through FFmpeg.
