import SwiftUI

struct SideBySideView: View {
	let left:       ComparisonImage
	let right:      ComparisonImage
	let canvasSize: CGSize
	@Binding var viewport: Viewport

	var body: some View {
		HStack(spacing: 0) {
			pane(for: left)
			Divider()
			pane(for: right)
		}
	}

	private func pane(for image: ComparisonImage) -> some View {
		ZoomableCanvas(viewport: $viewport, contentSize: canvasSize) {
			PixelImage(cgImage: image.cgImage, viewportScale: viewport.scale)
		}
	}
}
