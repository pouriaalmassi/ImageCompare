import CoreImage
import CoreImage.CIFilterBuiltins

/// Compares two images on the GPU using perceptual (CIE ΔE 1994) color difference.
nonisolated struct ImageDiffer: Sendable {
	/// ΔE of about 2 is the commonly cited "just noticeable difference".
	static let defaultThreshold:  Double = 2
	static let thresholdRange:    ClosedRange<Double> = 0...50
	private static let backgroundOpacity: CGFloat = 0.35
	private static let highlightColor = CIColor(red: 1, green: 0.15, blue: 0.2)

	private let context: CIContext

	init(context: CIContext = .shared) {
		self.context = context
	}

	@concurrent
	func diff(_ left: CIImage, _ right: CIImage, threshold: Double) async throws -> DiffResult {
		let canvas = left.extent.size.union(right.extent.size)
		let paddedLeft = left.padded(to: canvas)
		let paddedRight = right.padded(to: canvas)
		let overlap = left.topLeftAnchoredRect(in: canvas).intersection(right.topLeftAnchoredRect(in: canvas))

		let deltaEFilter = CIFilter.labDeltaE()
		deltaEFilter.inputImage = paddedLeft
		deltaEFilter.image2 = paddedRight
		let deltaE = try output(of: deltaEFilter)

		let mask = try Self.thresholdMask(deltaE: deltaE, threshold: threshold)
			.cropped(to: overlap)
			.composited(over: Self.uncoveredAreaMask(canvas: canvas, overlap: overlap))

		try Task.checkCancellation()

		let averageFilter = CIFilter.areaAverage()
		averageFilter.inputImage = mask
		averageFilter.extent = canvas
		let differingPixelFraction = context.renderPixel(of: try output(of: averageFilter)).x

		let maximumFilter = CIFilter.areaMaximum()
		maximumFilter.inputImage = deltaE
		maximumFilter.extent = overlap
		let maxDeltaE = context.renderPixel(of: try output(of: maximumFilter)).x

		try Task.checkCancellation()

		let blendFilter = CIFilter.blendWithMask()
		blendFilter.inputImage = CIImage(color: Self.highlightColor).cropped(to: canvas)
		blendFilter.backgroundImage = try Self.dimmedBackground(paddedRight)
		blendFilter.maskImage = mask
		let highlighted = try output(of: blendFilter)

		guard let diffImage = context.createCGImage(highlighted, from: canvas) else {
			throw ImageDifferError.renderFailed
		}

		return DiffResult(
			diffImage: diffImage,
			differingPixelFraction: Double(differingPixelFraction),
			maxDeltaE: Double(maxDeltaE)
		)
	}

	// MARK: Private Functions
	private func output(of filter: some CIFilter) throws -> CIImage {
		guard let image = filter.outputImage else {
			throw ImageDifferError.renderFailed
		}
		return image
	}

	/// Opaque white where ΔE exceeds `threshold`, opaque black elsewhere.
	///
	/// CILabDeltaE writes ΔE into all four channels, alpha included, and Core Image un-premultiplies before
	/// color filters run, so CIColorThreshold only ever sees RGB = 1. Reading ΔE back out of alpha with a
	/// color matrix and scaling it steeply around the threshold gives a hard 0/1 mask after clamping.
	private static func thresholdMask(deltaE: CIImage, threshold: Double) throws -> CIImage {
		let steepness: CGFloat = 1000
		let bias = -steepness * threshold
		let alphaToColor = CIVector(x: 0, y: 0, z: 0, w: steepness)

		let matrix = CIFilter.colorMatrix()
		matrix.inputImage = deltaE
		matrix.rVector = alphaToColor
		matrix.gVector = alphaToColor
		matrix.bVector = alphaToColor
		matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
		matrix.biasVector = CIVector(x: bias, y: bias, z: bias, w: 1)

		let clamp = CIFilter.colorClamp()
		clamp.inputImage = matrix.outputImage
		guard let mask = clamp.outputImage else {
			throw ImageDifferError.renderFailed
		}
		return mask
	}

	/// White wherever only one image has pixels, so size mismatches count as differences.
	private static func uncoveredAreaMask(canvas: CGRect, overlap: CGRect) -> CIImage {
		let covered = CIImage(color: .black).cropped(to: overlap)
		return covered.composited(over: CIImage(color: .white).cropped(to: canvas))
	}

	private static func dimmedBackground(_ image: CIImage) throws -> CIImage {
		let grayscale = CIFilter.colorControls()
		grayscale.inputImage = image
		grayscale.saturation = 0

		let dim = CIFilter.colorMatrix()
		dim.inputImage = grayscale.outputImage
		dim.aVector = CIVector(x: 0, y: 0, z: 0, w: backgroundOpacity)

		guard let output = dim.outputImage else {
			throw ImageDifferError.renderFailed
		}
		return output
	}
}

nonisolated enum ImageDifferError: Error {
	case renderFailed
}

private nonisolated extension CGSize {
	/// The smallest rect at the origin that fits both sizes.
	func union(_ other: CGSize) -> CGRect {
		CGRect(x: 0, y: 0, width: max(width, other.width), height: max(height, other.height))
	}
}
