# DJI LUT Studio for macOS

Native macOS SwiftUI application for the DJI LUT Studio workflow. The project targets macOS 26 and Swift 6. The app is inspired by the [GitHub project DJI LUT Studio V2](https://github.com/gal756/DJI-LUT-Studio-V2). Many thanks, @gal756 👍

## Build

Open `DJILutStudio.xcodeproj` in Xcode and build the `DJILutStudio` scheme. Video export uses macOS AVFoundation and Core Image; no external FFmpeg installation is required. The bundled `lut_manifest.json` and `lut_library` are taken from DJI-LUT-Studio-V2.

The app supports video import and drag and drop, filename based device profile suggestions, bundled DJI/creative LUT selection, `.cube` LUT grading, look adjustments, HEVC/H.264/ProRes 422 and ProRes 422 HQ export settings, sharpening, audio export, and output folder selection. Gyroflow remains an optional integration point.

## License, Copyright and Trademarks

This macOS application is maintained by EoF Software Lab. Copyright © 2026 EoF Software Lab. It is based on the original DJI LUT Studio project, © 2026 DJI LUT Studio Contributors, created by gal756. The original project's application code is offered under the [MIT License](https://github.com/gal756/DJI-LUT-Studio-V2/blob/main/LICENSE). That license applies to the upstream code and does not by itself relicense third-party materials bundled with or referenced by the project. See the original project's [third-party license and legal notices](https://github.com/gal756/DJI-LUT-Studio-V2/blob/main/THIRD_PARTY_LICENSES.md) for upstream details.

DJI LUT Studio is an independent community project and is not affiliated with, endorsed by, or sponsored by SZ DJI Technology Co., Ltd. DJI, Osmo, Mavic, Avata, Phantom, Zenmuse, D-Log, D-Log M, RockSteady, and HorizonSteady are trademarks of SZ DJI Technology Co., Ltd. Product and camera names are used only to identify compatibility. Official DJI conversion LUTs remain the intellectual property of SZ DJI Technology Co., Ltd.; their inclusion is for interoperability with the supported camera workflows and does not imply that they are covered by the MIT License.

The macOS application uses Apple's AVFoundation and Core Image frameworks for video processing. No external FFmpeg installation is required. For the upstream project's notices about third-party components such as FFmpeg and Gyroflow, refer to its [third-party license file](https://github.com/gal756/DJI-LUT-Studio-V2/blob/main/THIRD_PARTY_LICENSES.md).

## Your workflow, step by step

• Open MOV, MP4, or M4V videos via the file picker or by dragging and dropping.
• Select the DJI camera profile and the appropriate conversion LUT.
• Add an optional creative look and fine-tune the sharpness.
• Export as H.264, HEVC (H.265), ProRes 422, or ProRes 422 HQ.
• Open completed exports directly and locate previous results in your export history.

Video processing leverages Apple’s native video and image processing technologies. Your source file remains untouched; the output is saved as a new video file in your chosen folder. A LUT library and saved folder access help keep your workflow organized. For the best results, select the camera profile that matches the one used to record your clip. The available LUTs and export times will vary depending on your specific setup and your Mac.
