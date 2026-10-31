import SwiftUI

/// Empty-state target for one side: shows a thumbnail once loaded, accepts dropped files, and offers a picker.
struct ImageDropSlot: View {
	private static let cornerRadius: CGFloat = 12

	let side:  ImageSide
	let image: ComparisonImage?
	let onDrop:   ([URL]) -> Void
	let onChoose: () -> Void

	@State private var isTargeted = false

	var body: some View {
		VStack(spacing: 12) {
			if let image {
				Image(decorative: image.cgImage, scale: 1)
					.resizable()
					.scaledToFit()
					.frame(maxWidth: .infinity, maxHeight: .infinity)
				Text(image.fileName)
					.font(.headline)
					.lineLimit(1)
					.truncationMode(.middle)
			} else {
				Image(systemName: "photo.badge.plus")
					.font(.system(size: 48))
					.foregroundStyle(.secondary)
				Text("Drop the \(side.title.lowercased()) image here")
					.font(.headline)
			}
			Button(image == nil ? "Choose…" : "Replace…", action: onChoose)
		}
		.padding(24)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background {
			RoundedRectangle(cornerRadius: Self.cornerRadius)
				.strokeBorder(isTargeted ? Color.accentColor : .secondary.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
				.fill(isTargeted ? Color.accentColor.opacity(0.08) : .clear)
		}
		.dropDestination(for: URL.self) { urls, _ in
			onDrop(urls)
			return !urls.isEmpty
		} isTargeted: { isTargeted = $0 }
	}
}
