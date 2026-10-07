import AppKit
import SwiftUI

/// The look of the app: warm neutrals, one accent, soft corners.
enum Theme {
    static let accent = Color(red: 0.89, green: 0.40, blue: 0.24)

    static let chrome = dynamic(light: 0xF4F2EE, dark: 0x262624)
    static let panel = dynamic(light: 0xFBFAF8, dark: 0x1E1D1C)
    static let field = dynamic(light: 0xE9E6E0, dark: 0x383735)
    static let raised = dynamic(light: 0xFFFFFF, dark: 0x2E2D2B)
    static let line = Color.primary.opacity(0.09)

    private static func dynamic(light: Int, dark: Int) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
}

/// The app's mark: an open ring with a spark where it opens.
struct LogoMark: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: s * 0.225, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.98, green: 0.62, blue: 0.38), Color(red: 0.84, green: 0.31, blue: 0.19)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle()
                    .trim(from: 0.11, to: 0.89)
                    .stroke(.white, style: StrokeStyle(lineWidth: s * 0.075, lineCap: .round))
                    .rotationEffect(.degrees(-45))
                    .frame(width: s * 0.48, height: s * 0.48)
                Sparkle()
                    .fill(.white)
                    .frame(width: s * 0.25, height: s * 0.25)
                    .offset(x: s * 0.19, y: -s * 0.19)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

struct Sparkle: Shape {
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY)
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.midY), control: c)
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY), control: c)
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.midY), control: c)
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY), control: c)
        return p
    }
}

/// A small toolbar button that only shows its background on hover.
struct IconButton: View {
    let symbol: String
    var help = ""
    var active = false
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(active ? Theme.accent : Color.primary.opacity(isEnabled ? 0.75 : 0.25))
                .frame(width: 28, height: 28)
                .background(Color.primary.opacity(hovering && isEnabled ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

/// Makes the window one clean surface with the controls in the title area.
struct WindowSetup: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.toolbar = NSToolbar()
            window.toolbarStyle = .unified
            window.isMovableByWindowBackground = true
            // Set the Dock icon directly, so it never depends on the system's icon cache.
            if let icon = Bundle.main.image(forResource: "AppIcon") {
                NSApplication.shared.applicationIconImage = icon
            }
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}

@MainActor
enum IconExport {
    /// Draws the app icon as a PNG, used by the build script.
    static func write(to path: String) {
        let icon = LogoMark()
            .frame(width: 824, height: 824)
            .shadow(color: .black.opacity(0.22), radius: 16, y: 10)
            .frame(width: 1024, height: 1024)
        let renderer = ImageRenderer(content: icon)
        renderer.scale = 1
        guard let image = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else { exit(1) }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}
