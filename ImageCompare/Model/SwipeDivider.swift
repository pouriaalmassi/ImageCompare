import CoreGraphics

/// The swipe line between two handles, each sitting somewhere on the view's frame.
///
/// The handles may be on any edges except the same one. That rule is geometric: a corner belongs to both
/// of its edges, so a handle can't sit on the corner it would share with the other handle's edge.
/// Without it the line could lie along the frame and the swipe would collapse.
///
/// The right image fills the region clockwise from `first` to `second`. The default (top center to
/// bottom center) is therefore a vertical line with the left image on the left and the right on the right.
nonisolated struct SwipeDivider: Equatable {
	/// Frame edges in clockwise order.
	enum Edge: CaseIterable {
		case top
		case right
		case bottom
		case left
	}

	enum Handle {
		case first
		case second
	}

	/// A point on the frame. `fraction` runs left→right on the top and bottom edges and top→bottom on
	/// the left and right edges, so it can be stored independently of the view's size.
	struct FramePoint: Equatable {
		var edge:     Edge
		var fraction: Double

		func point(in size: CGSize) -> CGPoint {
			switch edge {
				case .top:    CGPoint(x: size.width * fraction, y: 0)
				case .right:  CGPoint(x: size.width, y: size.height * fraction)
				case .bottom: CGPoint(x: size.width * fraction, y: size.height)
				case .left:   CGPoint(x: 0, y: size.height * fraction)
			}
		}

		/// Its own edge, plus the neighboring edge when it sits on a corner.
		var edgesTouched: Set<Edge> {
			var edges: Set<Edge> = [edge]
			if fraction <= 0 {
				edges.insert(edge.isHorizontal ? .left : .top)
			}
			if fraction >= 1 {
				edges.insert(edge.isHorizontal ? .right : .bottom)
			}
			return edges
		}

		/// Position along the frame going clockwise from the top-left corner, in edge lengths (0..<4).
		fileprivate var perimeterPosition: Double {
			switch edge {
				case .top:    fraction
				case .right:  1 + fraction
				case .bottom: 2 + (1 - fraction)
				case .left:   3 + (1 - fraction)
			}
		}
	}

	/// Closest a handle may get, in points, to a corner it isn't allowed to occupy.
	private static let cornerClearance: CGFloat = 1

	// MARK: Public Variables
	var first  = FramePoint(edge: .top, fraction: 0.5)
	var second = FramePoint(edge: .bottom, fraction: 0.5)

	// MARK: Geometry
	subscript(handle: Handle) -> FramePoint {
		get {
			switch handle {
				case .first:  first
				case .second: second
			}
		}
		set {
			switch handle {
				case .first:  first = newValue
				case .second: second = newValue
			}
		}
	}

	/// Where to draw a handle: on the line, `inset` points in from the frame, so it's never clipped.
	func handleCenter(_ handle: Handle, in size: CGSize, inset: CGFloat) -> CGPoint {
		let end = self[handle].point(in: size)
		let other = self[handle.other].point(in: size)
		let length = end.distance(to: other)
		guard length > 0 else { return end }
		let travel = min(inset, length / 2) / length
		return CGPoint(x: end.x + (other.x - end.x) * travel, y: end.y + (other.y - end.y) * travel)
	}

	/// The polygon where the right image shows: the line plus the frame clockwise from `first` to `second`.
	func rightImageRegion(in size: CGSize) -> [CGPoint] {
		let start = first.perimeterPosition
		var finish = second.perimeterPosition
		if finish <= start {
			finish += 4
		}

		var points = [first.point(in: size)]
		var corner = start.rounded(.down) + 1
		while corner < finish {
			points.append(Self.corner(at: Int(corner) % 4, in: size))
			corner += 1
		}
		points.append(second.point(in: size))
		return points
	}

	// MARK: Dragging
	/// Moves a handle to the point on the frame nearest `target`, skipping edges the other handle touches.
	mutating func moveHandle(_ handle: Handle, toward target: CGPoint, in size: CGSize) {
		guard size.width > 0, size.height > 0 else { return }
		let forbidden = self[handle.other].edgesTouched

		let candidates = Edge.allCases
			.filter { !forbidden.contains($0) }
			.map { Self.nearestPoint(on: $0, to: target, in: size, avoiding: forbidden) }

		guard let nearest = candidates.min(by: { $0.point(in: size).distance(to: target) < $1.point(in: size).distance(to: target) }) else { return }
		self[handle] = nearest
	}

	/// Slides the line perpendicular to itself, keeping its on-screen angle. Ends move around corners onto
	/// other edges as needed, and the slide stops just before the line would leave the frame.
	func slid(by translation: CGSize, in size: CGSize) -> SwipeDivider {
		let start = first.point(in: size)
		let end = second.point(in: size)
		let direction = CGVector(dx: end.x - start.x, dy: end.y - start.y)
		let length = hypot(direction.dx, direction.dy)
		guard length > 0, size.width > 0, size.height > 0 else { return self }

		let normal = CGVector(dx: -direction.dy / length, dy: direction.dx / length)
		let cornerOffsets = (0..<4).map { Self.corner(at: $0, in: size).projected(onto: normal) }
		guard let lowest = cornerOffsets.min(), let highest = cornerOffsets.max() else { return self }

		let currentOffset = start.projected(onto: normal)
		let requestedOffset = currentOffset + translation.width * normal.dx + translation.height * normal.dy
		let clampedOffset = min(max(requestedOffset, lowest + Self.cornerClearance), highest - Self.cornerClearance)
		let shift = clampedOffset - currentOffset
		let origin = CGPoint(x: start.x + normal.dx * shift, y: start.y + normal.dy * shift)

		guard let (entry, exit) = Self.frameIntersections(from: origin, direction: direction, in: size) else { return self }
		return SwipeDivider(first: entry, second: exit)
	}

	/// Makes the line vertical through its midpoint, in the default orientation (right image on the right).
	mutating func straighten() {
		// In a unit square, point coordinates are the width/height fractions.
		let unitSquare = CGSize(width: 1, height: 1)
		let middleX = (first.point(in: unitSquare).x + second.point(in: unitSquare).x) / 2
		first = FramePoint(edge: .top, fraction: middleX)
		second = FramePoint(edge: .bottom, fraction: middleX)
	}

	// MARK: Private Functions
	/// Corner `index` clockwise from the top-left: 0 top-left, 1 top-right, 2 bottom-right, 3 bottom-left.
	private static func corner(at index: Int, in size: CGSize) -> CGPoint {
		switch index {
			case 1:  CGPoint(x: size.width, y: 0)
			case 2:  CGPoint(x: size.width, y: size.height)
			case 3:  CGPoint(x: 0, y: size.height)
			default: .zero
		}
	}

	private static func nearestPoint(on edge: Edge, to target: CGPoint, in size: CGSize, avoiding forbidden: Set<Edge>) -> FramePoint {
		let edgeLength = edge.isHorizontal ? size.width : size.height
		let coordinate = edge.isHorizontal ? target.x : target.y
		let clearance = Double(cornerClearance / edgeLength)

		// Each end of this edge is a corner shared with a neighbor; stay clear of it if that neighbor is off-limits.
		let lowerBound = forbidden.contains(edge.isHorizontal ? .left : .top) ? clearance : 0
		let upperBound = forbidden.contains(edge.isHorizontal ? .right : .bottom) ? 1 - clearance : 1
		let fraction = min(max(Double(coordinate / edgeLength), lowerBound), upperBound)
		return FramePoint(edge: edge, fraction: fraction)
	}

	/// Where the infinite line through `origin` along `direction` crosses the frame, ordered along `direction`.
	private static func frameIntersections(from origin: CGPoint, direction: CGVector, in size: CGSize) -> (FramePoint, FramePoint)? {
		var hits: [(t: CGFloat, point: FramePoint)] = []
		for edge in Edge.allCases {
			let isHorizontal = edge.isHorizontal
			let fixed: CGFloat = switch edge {
				case .top:    0
				case .right:  size.width
				case .bottom: size.height
				case .left:   0
			}
			let originAxis = isHorizontal ? origin.y : origin.x
			let directionAxis = isHorizontal ? direction.dy : direction.dx
			guard directionAxis != 0 else { continue }

			let t = (fixed - originAxis) / directionAxis
			let along = isHorizontal ? origin.x + direction.dx * t : origin.y + direction.dy * t
			let edgeLength = isHorizontal ? size.width : size.height
			guard along >= -0.001, along <= edgeLength + 0.001 else { continue }
			hits.append((t, FramePoint(edge: edge, fraction: min(max(Double(along / edgeLength), 0), 1))))
		}

		guard let entry = hits.min(by: { $0.t < $1.t }), let exit = hits.max(by: { $0.t < $1.t }) else { return nil }
		guard entry.point.edgesTouched.isDisjoint(with: exit.point.edgesTouched) else { return nil }
		return (entry.point, exit.point)
	}
}

nonisolated extension SwipeDivider.Edge {
	/// Top and bottom run horizontally; left and right run vertically.
	var isHorizontal: Bool {
		switch self {
			case .top, .bottom: true
			case .left, .right: false
		}
	}
}

nonisolated extension SwipeDivider.Handle {
	var other: Self {
		switch self {
			case .first:  .second
			case .second: .first
		}
	}
}

private nonisolated extension CGPoint {
	func distance(to other: CGPoint) -> CGFloat {
		hypot(other.x - x, other.y - y)
	}

	func projected(onto vector: CGVector) -> CGFloat {
		x * vector.dx + y * vector.dy
	}
}
