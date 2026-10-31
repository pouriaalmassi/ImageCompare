import SwiftUI

struct OnionSkinView: View {
	let left:       ComparisonImage
	let right:      ComparisonImage
	let canvasSize: CGSize
	@Binding var viewport: Viewport
	/// Opacity of the right image drawn over the left.
	let opacity: Double

	var body: some View {
		ZoomableCanvas(viewport: $viewport, contentSize: canvasSize) {
			ZStack(alignment: .topLeading) {
				PixelImage(cgImage: left.cgImage, viewportScale: viewport.scale)
				PixelImage(cgImage: right.cgImage, viewportScale: viewport.scale)
					.opacity(opacity)
			}
		}
	}
}
