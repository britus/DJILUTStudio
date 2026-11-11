import SwiftUI

struct UserGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.cyan)
                    .frame(width: 44, height: 44)
                    .background(.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "DJI LUT Studio User Guide"))
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                    Text(String(localized: "From camera footage to a finished video"))
                        .font(.system(size: 12))
                        .foregroundStyle(DS.textSecondary)
                }
                Spacer()
                Button(String(localized: "Done")) { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
            }
            .padding(22)
            .overlay(alignment: .bottom) { DS.divider.frame(height: 1) }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    guideCard(String(localized: "1. Add a video"), icon: "film", accent: .cyan) {
                        Text("Open Color Grading and drop a MOV, MP4 or M4V clip into Source Footage, or choose Browse. You can also use the video button in the toolbar. The app may suggest a camera profile based on the filename; check the selection before exporting.")
                    }

                    guideCard(String(localized: "2. Choose a camera profile and LUT"), icon: "camera", accent: .cyan) {
                        Text("Under Camera Profile, select the DJI device used to record the clip, then choose its conversion LUT. A recommended profile is selected when available. The conversion LUT transforms the camera’s flat or log footage into a more natural starting point.")
                    }

                    guideCard(String(localized: "3. Set the creative look"), icon: "slider.horizontal.3", accent: .purple) {
                        Text("Under Creative Grade, choose an optional look to add a visual style. Select No Creative Grade Look to use only the camera conversion LUT. Fine detail sharpening is optional and can be switched on or off.")
                    }

                    guideCard(String(localized: "4. Choose export settings"), icon: "square.and.arrow.up", accent: .orange) {
                        Text("Choose H.264 for broad compatibility, HEVC (H.265) for efficient files, or ProRes 422 / ProRes 422 HQ for editing workflows. Choose a destination folder. macOS asks for access to the folders you select; the app remembers the chosen output folder for later sessions.")
                    }

                    guideCard(String(localized: "5. Export and find your result"), icon: "play.rectangle", accent: DS.green) {
                        Text("Select Apply LUT & Export and wait for progress to finish. The app keeps the source clip unchanged and writes a graded copy to the destination folder. When export completes, use the result action to reveal or open the exported file. Previous exports are available in Export History.")
                    }

                    guideCard(String(localized: "Manage LUTs and folder access"), icon: "square.stack.3d.up", accent: .cyan) {
                        Text("LUT Library lets you browse the installed profiles and add supported LUT files. Security Bookmarks lets you review saved folder permissions if a library or destination folder has moved or is no longer accessible. Re-select the folder in macOS when access needs to be restored.")
                    }

                    Text("For best results, select the camera profile that matches the footage. Export time depends on clip length, resolution, codec and Mac performance.")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }
                .padding(22)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 620, idealWidth: 720, minHeight: 560, idealHeight: 680)
        .background(DS.chatBg)
        .preferredColorScheme(.dark)
    }

    private func guideCard<Content: View>(
        _ title: String,
        icon: String,
        accent: Color,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        DS.Card(icon: icon, title: title, accent: accent) {
            content()
                .font(.system(size: 13))
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
