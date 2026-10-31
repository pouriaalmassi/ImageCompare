import CoreImage
import Testing
@testable import ImageCompare

struct ImageDifferTests {
	private func solidImage(_ color: CIColor, width: CGFloat, height: CGFloat) -> CIImage {
		CIImage(color: color).cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
	}

	@Test("Identical images have no differing pixels")
	func identicalImages() async throws {
		let image = solidImage(CIColor(red: 0.2, green: 0.5, blue: 0.8), width: 10, height: 10)

		let result = try await ImageDiffer().diff(image, image, threshold: ImageDiffer.defaultThreshold)

		#expect(result.differingPixelFraction == 0)
		#expect(result.maxDeltaE < 0.01)
		#expect(result.diffImage.width == 10)
		#expect(result.diffImage.height == 10)
	}

	@Test("A single changed pixel out of 100 is reported as 1%")
	func singleDifferingPixel() async throws {
		let base = solidImage(.red, width: 10, height: 10)
		let changed = solidImage(.blue, width: 1, height: 1)
			.transformed(by: CGAffineTransform(translationX: 4, y: 6))
			.composited(over: base)

		let result = try await ImageDiffer().diff(base, changed, threshold: ImageDiffer.defaultThreshold)

		#expect(abs(result.differingPixelFraction - 0.01) < 0.001)
		#expect(result.maxDeltaE > 10)
	}

	@Test("Completely different colors differ everywhere")
	func fullyDifferentImages() async throws {
		let left = solidImage(.black, width: 8, height: 8)
		let right = solidImage(.white, width: 8, height: 8)

		let result = try await ImageDiffer().diff(left, right, threshold: ImageDiffer.defaultThreshold)

		#expect(abs(result.differingPixelFraction - 1) < 0.001)
	}

	@Test("Area covered by only one image counts as different")
	func differentSizes() async throws {
		let left = solidImage(.green, width: 10, height: 10)
		let right = solidImage(.green, width: 20, height: 10)

		let result = try await ImageDiffer().diff(left, right, threshold: ImageDiffer.defaultThreshold)

		#expect(result.diffImage.width == 20)
		#expect(result.diffImage.height == 10)
		#expect(abs(result.differingPixelFraction - 0.5) < 0.001)
		#expect(result.maxDeltaE < 0.01)
	}

	@Test("Differences below the threshold are ignored")
	func thresholdAboveMaximum() async throws {
		let left = solidImage(CIColor(red: 0.5, green: 0.5, blue: 0.5), width: 10, height: 10)
		let right = solidImage(CIColor(red: 0.52, green: 0.5, blue: 0.5), width: 10, height: 10)

		let lenient = try await ImageDiffer().diff(left, right, threshold: 20)
		let strict = try await ImageDiffer().diff(left, right, threshold: 0.1)

		#expect(lenient.differingPixelFraction == 0)
		#expect(abs(strict.differingPixelFraction - 1) < 0.001)
		#expect(lenient.maxDeltaE > 0.1 && lenient.maxDeltaE < 20)
	}
}

struct ViewportTests {
	@Test("Fit never enlarges small content past 100%")
	func fitSmallContent() {
		var viewport = Viewport()

		viewport.layout(contentSize: CGSize(width: 100, height: 100), containerSize: CGSize(width: 1000, height: 1000))

		#expect(viewport.scale == 1)
		#expect(viewport.offset == .zero)
	}

	@Test("Fit shrinks large content to the limiting dimension")
	func fitLargeContent() {
		var viewport = Viewport()

		viewport.layout(contentSize: CGSize(width: 4000, height: 1000), containerSize: CGSize(width: 1000, height: 1000))

		#expect(viewport.scale == 0.25)
	}

	@Test("A fitted viewport refits when the container resizes; a zoomed one does not")
	func refitOnResize() {
		let content = CGSize(width: 2000, height: 2000)
		var fitted = Viewport()
		var zoomed = Viewport()
		zoomed.layout(contentSize: content, containerSize: CGSize(width: 1000, height: 1000))
		zoomed.zoomIn()

		fitted.layout(contentSize: content, containerSize: CGSize(width: 500, height: 500))
		zoomed.layout(contentSize: content, containerSize: CGSize(width: 500, height: 500))

		#expect(fitted.scale == 0.25)
		#expect(fitted.isFitted)
		#expect(zoomed.scale == 1)
		#expect(!zoomed.isFitted)
	}

	@Test("Zooming scales the pan offset so the view center stays fixed")
	func zoomKeepsCenter() {
		var viewport = Viewport()
		viewport.actualSize()
		viewport.pan(by: CGSize(width: 50, height: -20))

		viewport.zoomIn()

		#expect(viewport.scale == 2)
		#expect(viewport.offset == CGSize(width: 100, height: -40))
	}
}

struct SwipeDividerTests {
	private let size = CGSize(width: 1000, height: 500)

	private func isOnFrame(_ point: CGPoint) -> Bool {
		let onVertical = abs(point.x) < 0.01 || abs(point.x - size.width) < 0.01
		let onHorizontal = abs(point.y) < 0.01 || abs(point.y - size.height) < 0.01
		return onVertical || onHorizontal
	}

	@Test("By default the right image fills the right half")
	func defaultRegion() {
		let region = SwipeDivider().rightImageRegion(in: size)

		#expect(region == [CGPoint(x: 500, y: 0), CGPoint(x: 1000, y: 0), CGPoint(x: 1000, y: 500), CGPoint(x: 500, y: 500)])
	}

	@Test("The region follows the frame clockwise from the first handle to the second")
	func cornerRegion() {
		let divider = SwipeDivider(
			first: .init(edge: .top, fraction: 0.5),
			second: .init(edge: .right, fraction: 0.5)
		)

		let region = divider.rightImageRegion(in: size)

		#expect(region == [CGPoint(x: 500, y: 0), CGPoint(x: 1000, y: 0), CGPoint(x: 1000, y: 250)])
	}

	@Test("A handle moves to the nearest point on any edge the other handle isn't on")
	func moveOntoSideEdge() {
		var divider = SwipeDivider()

		divider.moveHandle(.first, toward: CGPoint(x: 20, y: 300), in: size)

		#expect(divider.first == .init(edge: .left, fraction: 0.6))
		#expect(divider.second.edge == .bottom)
	}

	@Test("A handle can't join the other handle's edge")
	func cannotShareEdge() {
		var divider = SwipeDivider()

		divider.moveHandle(.first, toward: CGPoint(x: 500, y: 499), in: size)

		#expect(divider.first.edge != .bottom)
		#expect(divider.first.edgesTouched.isDisjoint(with: divider.second.edgesTouched))
	}

	@Test("A handle stops short of a corner shared with the other handle's edge")
	func cannotTakeSharedCorner() {
		var divider = SwipeDivider(
			first: .init(edge: .top, fraction: 0.5),
			second: .init(edge: .right, fraction: 0.5)
		)

		divider.moveHandle(.first, toward: CGPoint(x: 1200, y: -50), in: size)

		#expect(divider.first.edge == .top)
		#expect(divider.first.fraction < 1)
		#expect(divider.first.edgesTouched.isDisjoint(with: divider.second.edgesTouched))
	}

	@Test("Sliding a vertical line moves it sideways")
	func slideVertical() {
		let divider = SwipeDivider()

		let slid = divider.slid(by: CGSize(width: 100, height: 40), in: size)

		#expect(slid.first.edge == .top)
		#expect(slid.second.edge == .bottom)
		#expect(abs(slid.first.fraction - 0.6) < 1e-9)
		#expect(abs(slid.second.fraction - 0.6) < 1e-9)
	}

	@Test("Sliding keeps the angle and lets ends travel around corners")
	func slideAroundCorner() {
		let divider = SwipeDivider(
			first: .init(edge: .top, fraction: 0.6),
			second: .init(edge: .bottom, fraction: 0.9)
		)
		let before = (divider.first.point(in: size), divider.second.point(in: size))

		let slid = divider.slid(by: CGSize(width: 200, height: 0), in: size)
		let after = (slid.first.point(in: size), slid.second.point(in: size))

		#expect(slid.second.edge == .right)
		let crossProduct = (before.1.x - before.0.x) * (after.1.y - after.0.y) - (before.1.y - before.0.y) * (after.1.x - after.0.x)
		#expect(abs(crossProduct) < 1e-6)
		#expect(isOnFrame(after.0) && isOnFrame(after.1))
	}

	@Test("Sliding far past the frame stops with a valid divider")
	func slideClamps() {
		let divider = SwipeDivider(
			first: .init(edge: .top, fraction: 0.3),
			second: .init(edge: .bottom, fraction: 0.7)
		)

		let slid = divider.slid(by: CGSize(width: 5000, height: 0), in: size)

		#expect(slid != divider)
		#expect(slid.first.edgesTouched.isDisjoint(with: slid.second.edgesTouched))
		#expect(slid.first.point(in: size) != slid.second.point(in: size))
	}

	@Test("Handles are drawn on the line, inset from the frame")
	func handleCenter() {
		let divider = SwipeDivider()

		#expect(divider.handleCenter(.first, in: size, inset: 24) == CGPoint(x: 500, y: 24))
		#expect(divider.handleCenter(.second, in: size, inset: 24) == CGPoint(x: 500, y: 476))
	}

	@Test("Straightening makes the line vertical through its midpoint")
	func straighten() {
		var divider = SwipeDivider(
			first: .init(edge: .left, fraction: 0.3),
			second: .init(edge: .bottom, fraction: 0.8)
		)

		divider.straighten()

		#expect(divider.first == .init(edge: .top, fraction: 0.4))
		#expect(divider.second == .init(edge: .bottom, fraction: 0.4))
	}
}

