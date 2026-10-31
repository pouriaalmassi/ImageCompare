import CoreGraphics

nonisolated enum ImageSide: CaseIterable {
	case left
	case right

	var title: String {
		switch self {
			case .left:  "Left"
			case .right: "Right"
		}
	}
}

/// The two images being compared. Either side may be empty while the user is still choosing files.
nonisolated struct ImagePair {
	var left:  ComparisonImage?
	var right: ComparisonImage?

	subscript(side: ImageSide) -> ComparisonImage? {
		get {
			switch side {
				case .left:  left
				case .right: right
			}
		}
		set {
			switch side {
				case .left:  left = newValue
				case .right: right = newValue
			}
		}
	}

	var isComplete: Bool { left != nil && right != nil }

	/// Both images anchored top-left share a canvas this big, matching `ImageDiffer`'s alignment.
	var canvasSize: CGSize {
		let sizes = [left, right].compactMap { $0?.pixelSize }
		return CGSize(
			width: sizes.map(\.width).max() ?? 0,
			height: sizes.map(\.height).max() ?? 0
		)
	}

	mutating func swap() {
		(left, right) = (right, left)
	}
}
