import SwiftUI

/// Draws an image at one point per pixel. Pixels stay crisp when zoomed in, like Kaleidoscope.
struct PixelImage: View {
	let cgImage:       CGImage
	let viewportScale: CGFloat

	var body: some View {
		Image(decorative: cgImage, scale: 1)
			.interpolation(viewportScale > 1 ? .none : .high)
	}
}
