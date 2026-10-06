//
//  StickerViews.swift
//  Gameboxd
//
//  A sticker (tap to copy), its holographic foil and a locked slot. Used by the game's
//  page and the album.
//

import SwiftUI
import UniformTypeIdentifiers

struct StickerView: View {
    let sticker: Sticker
    let game: Game
    var height: CGFloat = 130
    @State private var copied = false

    var body: some View {
        Button(action: copy) {
            art
                .shadow(color: .black.opacity(0.45), radius: 6, y: 4)
                .rotationEffect(.degrees(sticker.tilt))
                .overlay { if copied { CopiedBadge() } }
        }
        .buttonStyle(.plain)
        .accessibilityElement()
        .accessibilityLabel("Autocollant \(game.title), \(sticker.reason.label)\(sticker.isHolo ? ", holographique" : "")")
        .accessibilityHint("Copie l'autocollant dans le presse-papiers")
    }

    /// Puts the sticker on the pasteboard as a transparent PNG, ready to paste in Messages.
    private func copy() {
        let png: Data?
        if sticker.hasArt, let file = sticker.imageFile {
            png = try? Data(contentsOf: StickerService.shared.url(for: file))
        } else {
            // Cover stand-in: render it as drawn (white border included), without tilt or shadow.
            let renderer = ImageRenderer(content: art)
            renderer.scale = 3
            png = renderer.uiImage?.pngData()
        }
        guard let png else { return }
        copyPNG(png, flag: $copied)
    }

    @ViewBuilder private var art: some View {
        if sticker.hasArt, let file = sticker.imageFile,
           let image = UIImage(contentsOfFile: StickerService.shared.url(for: file).path) {
            let picture = Image(uiImage: image).resizable().scaledToFit()
            picture
                .frame(height: height)
                .overlay { if sticker.isHolo { HoloSheen().mask(picture) } }
        } else {
            // No cut-out (no art, or the simulator): the cover as a plain die-cut sticker.
            CachedAsyncImage(url: game.artURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                game.coverColor
            }
            .frame(width: height * 0.7, height: height * 0.92)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay { if sticker.isHolo { HoloSheen().clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous)) } }
            .padding(5)
            .background(.white, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }
}

/// Rainbow foil for platinum stickers: the colours and a bright band slide as the phone tilts.
private struct HoloSheen: View {
    private let tilt = TiltMotion.shared

    var body: some View {
        let dx = tilt.x * 0.6, dy = tilt.y * 0.6
        ZStack {
            LinearGradient(colors: ([.pink, .yellow, .mint, .cyan, .purple, .pink] as [Color]).map { $0.opacity(0.55) },
                           startPoint: UnitPoint(x: dx, y: dy), endPoint: UnitPoint(x: 1 + dx, y: 1 + dy))
                .blendMode(.overlay)
            LinearGradient(colors: [.clear, .white.opacity(0.55), .clear],
                           startPoint: UnitPoint(x: 0.2 - dx, y: 0.2 - dy), endPoint: UnitPoint(x: 0.8 - dx, y: 0.8 - dy))
                .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
        .onAppear { tilt.start() }
        .onDisappear { tilt.stop() }
    }
}

struct LockedStickerSlot: View {
    let reason: Sticker.Reason

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            Image(systemName: "lock.fill")
                .font(.title3)
            Text(reason.label)
                .font(DS.Typography.caption)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Color.textTertiary)
        .frame(width: 96, height: 120)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(Color.gbBorder, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Autocollant verrouillé : \(reason.label)")
    }
}

// MARK: - Copy feedback

/// Puts a PNG on the pasteboard (transparency kept, pastes as a sticker in Messages),
/// buzzes, and raises `flag` for a moment so the view can show "Copié".
func copyPNG(_ png: Data, flag: Binding<Bool>) {
    UIPasteboard.general.setData(png, forPasteboardType: UTType.png.identifier)
    HapticManager.notification(.success)
    withAnimation(.spring(response: 0.3)) { flag.wrappedValue = true }
    Task {
        try? await Task.sleep(for: .seconds(1.2))
        withAnimation(.easeOut(duration: 0.25)) { flag.wrappedValue = false }
    }
}

struct CopiedBadge: View {
    var body: some View {
        Text("Copié")
            .font(DS.Typography.captionMedium)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 6)
            .background(.black.opacity(0.75), in: Capsule())
            .foregroundStyle(.white)
            .transition(.scale.combined(with: .opacity))
    }
}
