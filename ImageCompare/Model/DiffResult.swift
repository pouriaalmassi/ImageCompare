import CoreGraphics

nonisolated struct DiffResult: Sendable {
	/// The right image desaturated and dimmed, with pixels over the threshold painted red.
	let diffImage: CGImage
	/// Share of canvas pixels (0...1) whose ΔE exceeds the threshold, counting any area covered by only one image.
	let differingPixelFraction: Double
	/// Largest CIE ΔE 1994 value within the area both images cover (0...100).
	let maxDeltaE: Double
}
