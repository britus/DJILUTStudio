# DJILutStudio

Native macOS SwiftUI application for the DJI LUT Studio workflow. The project targets macOS 26 and Swift 6.

## Build

Open `DJILutStudio.xcodeproj` in Xcode and build the `DJILutStudio` scheme. Video export uses macOS AVFoundation and Core Image; no external FFmpeg installation is required. The bundled `lut_manifest.json` and `lut_library` are taken from DJI-LUT-Studio-V2.

The app supports video import and drag and drop, filename based device profile suggestions, bundled DJI/creative LUT selection, `.cube` LUT grading, look adjustments, HEVC/H.264/ProRes 422 and ProRes 422 HQ export settings, sharpening, audio export, and output folder selection. Gyroflow remains an optional integration point.
