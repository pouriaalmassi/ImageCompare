import SwiftUI

struct DifferenceView: View {
	let diffResult: DiffResult?
	let isDiffing:  Bool
	let canvasSize: CGSize
	@Binding var viewport: Viewport

	var body: some View {
		if let diffResult {
			ZoomableCanvas(viewport: $viewport, contentSize: canvasSize) {
				PixelImage(cgImage: diffResult.diffImage, viewportScale: viewport.scale)
			}
			.overlay(alignment: .topTrailing) {
				if isDiffing {
					ProgressView()
						.controlSize(.small)
						.padding()
				}
			}
		} else {
			ProgressView("Comparing…")
				.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
	}
}
