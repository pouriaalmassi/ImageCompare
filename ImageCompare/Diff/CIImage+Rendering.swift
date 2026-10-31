import CoreImage

nonisolated extension CIContext {
	/// Half-float working format so ΔE values (0...100) survive intermediate steps unclamped.
	static let shared = CIContext(options: [.workingFormat: CIFormat.RGBAh, .cacheIntermediates: false])

	/// Renders the single pixel at the origin of `image` with no color management, returning raw RGBA values.
	func renderPixel(of image: CIImage) -> SIMD4<Float> {
		var pixel = SIMD4<Float>(repeating: 0)
		withUnsafeMutableBytes(of: &pixel) { buffer in
			guard let baseAddress = buffer.baseAddress else { return }
			render(
				image,
				toBitmap: baseAddress,
				rowBytes: MemoryLayout<SIMD4<Float>>.size,
				bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
				format: .RGBAf,
				colorSpace: nil
			)
		}
		return pixel
	}
}

nonisolated extension CIImage {
	func movedToOrigin() -> CIImage {
		transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
	}

	/// The rect this image occupies when anchored to the top-left of `canvas`.
	/// Core Image's origin is bottom-left, so "top-left" means pushing the image up by the height difference.
	func topLeftAnchoredRect(in canvas: CGRect) -> CGRect {
		CGRect(
			x: canvas.minX,
			y: canvas.maxY - extent.height,
			width: extent.width,
			height: extent.height
		)
	}

	/// Anchors the image to the top-left of `canvas` and fills the remainder with transparent pixels.
	func padded(to canvas: CGRect) -> CIImage {
		let target = topLeftAnchoredRect(in: canvas)
		let moved = transformed(by: CGAffineTransform(translationX: target.minX - extent.minX, y: target.minY - extent.minY))
		return moved.composited(over: CIImage(color: .clear).cropped(to: canvas))
	}
}
