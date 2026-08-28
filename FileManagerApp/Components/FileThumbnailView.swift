import SwiftUI
import UIKit

/// Icon-first thumbnail for any item: a tinted glyph chip for most kinds, a
/// downsampled image preview for photos, plus an optional mini color-tag dot.
///
/// Image loading is done through `CGImageSource` downsampling so opening a
/// folder full of RAW photos never balloons memory.
struct FileThumbnailView: View {
    let item: FileItem
    var size: CGFloat = 56
    var tag: TagColor? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if item.kind == .image, !item.isDirectory {
                ImageThumbnail(url: item.url, size: size)
            } else {
                glyph
            }

            if let tag = tag, tag != .none {
                Circle()
                    .fill(tag.color)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Theme.surface, lineWidth: 2))
                    .padding(4)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var glyph: some View {
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [item.kind.tint.opacity(0.22), item.kind.tint.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .strokeBorder(item.kind.tint.opacity(0.35), lineWidth: 1)
            )
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: item.kind.symbolName)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(item.kind.tint)
            }
    }
}

/// Memory-safe image preview via thumbnail downsampling.
private struct ImageThumbnail: View {
    let url: URL
    let size: CGFloat

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(Color.black.opacity(0.4))
                    .overlay(ProgressView().tint(Theme.textTertiary))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .strokeBorder(Theme.surfaceStroke, lineWidth: 1)
        )
        .task {
            image = Self.downsample(url: url, pixelSize: Int(size * 2))
        }
    }

    /// Decode only the thumbnail pass of an image — a fraction of the memory.
    nonisolated static func downsample(url: URL, pixelSize: Int) -> UIImage? {
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        guard let source else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}