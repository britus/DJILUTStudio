// Adapted from EoF MCP Studio's DesignComponents.swift
// EoF Software Lab 2026
import SwiftUI
internal import AppKit

private func adaptiveNSColor(light: NSColor, dark: NSColor) -> NSColor {
    NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
    }
}

public enum SyntaxHighlightColors {
    static let keyword = adaptiveNSColor(light: NSColor(red: 0.48, green: 0.22, blue: 0.70, alpha: 0.95), dark: NSColor(red: 0.80, green: 0.50, blue: 1.00, alpha: 0.85))
    static let string_ = adaptiveNSColor(light: NSColor(red: 0.58, green: 0.38, blue: 0.08, alpha: 0.95), dark: NSColor(red: 0.85, green: 0.72, blue: 0.45, alpha: 0.85))
    static let number = adaptiveNSColor(light: NSColor(red: 0.18, green: 0.48, blue: 0.22, alpha: 0.95), dark: NSColor(red: 0.55, green: 0.90, blue: 0.65, alpha: 0.85))
    static let comment = NSColor.textColor.withAlphaComponent(0.35)
    static let type_ = adaptiveNSColor(light: NSColor(red: 0.02, green: 0.45, blue: 0.58, alpha: 0.95), dark: NSColor(red: 0.35, green: 0.82, blue: 0.95, alpha: 0.85))
    static let func_ = adaptiveNSColor(light: NSColor(red: 0.05, green: 0.32, blue: 0.72, alpha: 0.95), dark: NSColor(red: 0.25, green: 0.65, blue: 1.00, alpha: 0.85))
    static let literal = adaptiveNSColor(light: NSColor(red: 0.70, green: 0.30, blue: 0.02, alpha: 0.95), dark: NSColor(red: 1.00, green: 0.60, blue: 0.20, alpha: 0.85))
    static let punct = NSColor.textColor.withAlphaComponent(0.50)
    static let plain = NSColor.textColor.withAlphaComponent(0.85)
}

public enum DS {
    private static func adaptiveColor(light: NSColor, dark: NSColor) -> Color { Color(adaptiveNSColor(light: light, dark: dark)) }
    static let sidebarBg = Color(NSColor.controlBackgroundColor)
    static let sidebarBorder = Color(NSColor.separatorColor)
    static let chatBg = Color(NSColor.controlBackgroundColor)
    static let accent = Color.accentColor
    static let accentDim = Color.accentColor.opacity(0.25)
    static let textPrimary = Color(NSColor.controlTextColor)
    static let textSecondary = Color(NSColor.secondaryLabelColor)
    static let divider = Color(NSColor.separatorColor)
    static let green = Color(NSColor.systemGreen)
    static let red = Color(NSColor.systemRed)
    static let yellow = Color(NSColor.systemYellow)
    static let orange = Color(NSColor.systemOrange)
    static let purple = Color(NSColor.systemPurple)
    static let buttonBg = Color(NSColor.controlTextColor).opacity(0.18)
    static let border = Color(NSColor.separatorColor)
    static let sheetCard = Color(NSColor.windowBackgroundColor)
    static let codeBg = adaptiveColor(light: NSColor(calibratedWhite: 0.96, alpha: 1), dark: NSColor(red: 0.09, green: 0.10, blue: 0.12, alpha: 1))

    struct Card<Content: View>: View {
        let icon: String
        let title: String
        let accent: Color
        @ViewBuilder let content: () -> Content

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(accent)
                    Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(DS.textPrimary)
                }
                content()
            }
            .padding(14)
            .background(DS.sheetCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.border, lineWidth: 1))
        }
    }
    
    @ViewBuilder
    static public func workspaceHeader<Trailing: View>(title: String, subtitle: String, icon: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.cyan)
                .frame(width: 44, height: 44)
                .background(.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 12)).foregroundStyle(DS.textSecondary)
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .overlay(alignment: .bottom) {
            DS.divider.frame(height: 1)
        }
    }
    
    @ViewBuilder
    static public func ToolbarButton(
        icon: String,
        help: String,
        disabled: Bool = false,
        foregroundColor: Color? = nil,
        size: CGFloat = 12,
        fill: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                ZStack {
                    if fill {
                        Circle().fill(DS.buttonBg)
                            .frame(width: size * 2, height: size * 2)
                    }
                    if let foregroundColor {
                        Image(systemName: icon)
                            .font(.system(size: size, weight: .medium))
                            .frame(width: size * 2 + 2, height: size * 2 + 2)
                            .foregroundColor(foregroundColor)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: size, weight: .medium))
                            .frame(width: size * 2 + 2, height: size * 2 + 2)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .transition(.opacity)
        .disabled(disabled)
        .help(help)
    }
}

extension Font {
    static func appFont(size legacySize: CGFloat, weight: Font.Weight? = nil, design: Font.Design = .default) -> Font {
        let relativeOffset = (max(legacySize, 10) - 13)
        return .system(size: NSFont.systemFontSize + relativeOffset + 1, weight: weight, design: design)
    }
}
