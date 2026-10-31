import CoreGraphics

/// Zoom and pan shared by every comparison mode so switching modes keeps the same region in view.
/// `scale` is screen points per image pixel; `offset` is the pan in points from the centered position.
/// While `isFitted` is true the viewport refits whenever the content or container size changes.
nonisolated struct Viewport: Equatable {
	static let minimumScale: CGFloat = 0.02
	static let maximumScale: CGFloat = 64
	private static let zoomStep: CGFloat = 2

	// MARK: Public Variables
	private(set) var scale:    CGFloat = 1
	private(set) var offset:   CGSize  = .zero
	private(set) var isFitted: Bool    = true

	// MARK: Private Variables
	private var contentSize:   CGSize = .zero
	private var containerSize: CGSize = .zero

	// MARK: Layout
	mutating func layout(contentSize: CGSize, containerSize: CGSize) {
		self.contentSize = contentSize
		self.containerSize = containerSize
		if isFitted {
			fit()
		}
	}

	/// Fits the content inside the container, never enlarging past 100%.
	mutating func fit() {
		isFitted = true
		offset = .zero
		guard contentSize.width > 0, contentSize.height > 0, containerSize.width > 0, containerSize.height > 0 else { return }
		let fittingScale = min(containerSize.width / contentSize.width, containerSize.height / contentSize.height)
		scale = Self.clamped(min(fittingScale, 1))
	}

	// MARK: Zoom and Pan
	mutating func zoomIn() {
		setScale(scale * Self.zoomStep)
	}

	mutating func zoomOut() {
		setScale(scale / Self.zoomStep)
	}

	mutating func actualSize() {
		isFitted = false
		scale = 1
		offset = .zero
	}

	mutating func setScale(_ newScale: CGFloat) {
		isFitted = false
		let clamped = Self.clamped(newScale)
		// Scale the pan too so the point at the center of the view stays put.
		let factor = clamped / scale
		offset = CGSize(width: offset.width * factor, height: offset.height * factor)
		scale = clamped
	}

	mutating func pan(by translation: CGSize) {
		guard translation != .zero else { return }
		isFitted = false
		offset = CGSize(width: offset.width + translation.width, height: offset.height + translation.height)
	}

	// MARK: Private Functions
	private static func clamped(_ scale: CGFloat) -> CGFloat {
		min(max(scale, minimumScale), maximumScale)
	}
}
