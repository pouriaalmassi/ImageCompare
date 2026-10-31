import SwiftUI

/// Left image on one side of a draggable divider, right image on the other, both in the same viewport.
/// Like Kaleidoscope, each divider handle can be dragged anywhere along the frame (never both on the same edge).
struct SwipeView: View {
	private static let handleDiameter: CGFloat = 28
	/// Distance along the line from the frame to a handle's center.
	private static let handleInset:    CGFloat = 24
	private static let lineHitWidth:   CGFloat = 16
	private static let coordinateSpaceName = "swipe"

	let left:       ComparisonImage
	let right:      ComparisonImage
	let canvasSize: CGSize
	@Binding var viewport: Viewport
	@Binding var divider:  SwipeDivider

	/// Divider as it was when a line drag began; line drags move relative to it.
	@State private var dividerAtDragStart: SwipeDivider?
	/// Offset from the pointer to the dragged handle's frame point, so the handle doesn't jump when grabbed.
	@State private var handleGrabOffset: CGSize?

	var body: some View {
		GeometryReader { geometry in
			let size = geometry.size

			ZStack {
				canvas(for: left)
				canvas(for: right)
					.mask {
						RightImageRegion(divider: divider)
					}
				line(in: size)
				handle(.first, in: size)
				handle(.second, in: size)
			}
			.coordinateSpace(.named(Self.coordinateSpaceName))
		}
	}

	// MARK: Private Functions
	private func canvas(for image: ComparisonImage) -> some View {
		ZoomableCanvas(viewport: $viewport, contentSize: canvasSize) {
			PixelImage(cgImage: image.cgImage, viewportScale: viewport.scale)
		}
	}

	private func line(in size: CGSize) -> some View {
		let path = Path { path in
			path.move(to: divider.first.point(in: size))
			path.addLine(to: divider.second.point(in: size))
		}

		return path
			.stroke(.white, lineWidth: 2)
			.shadow(radius: 2)
			.contentShape(path.strokedPath(StrokeStyle(lineWidth: Self.lineHitWidth)))
			.pointerStyle(.grabIdle)
			.gesture(lineDrag(in: size))
	}

	private func handle(_ handle: SwipeDivider.Handle, in size: CGSize) -> some View {
		Circle()
			.fill(.white)
			.frame(width: Self.handleDiameter, height: Self.handleDiameter)
			.shadow(radius: 2)
			.overlay {
				// Arrows point along the edge the handle is on.
				Image(systemName: divider[handle].edge.isHorizontal ? "arrow.left.and.right" : "arrow.up.and.down")
					.font(.caption.bold())
					.foregroundStyle(.black)
			}
			.contentShape(Circle())
			.pointerStyle(.grabIdle)
			.help("Drag anywhere along the frame to angle the divider. Double-click to straighten.")
			.position(divider.handleCenter(handle, in: size, inset: Self.handleInset))
			.onTapGesture(count: 2) {
				divider.straighten()
			}
			.gesture(handleDrag(handle, in: size))
	}

	private func handleDrag(_ handle: SwipeDivider.Handle, in size: CGSize) -> some Gesture {
		DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.coordinateSpaceName))
			.onChanged { value in
				let offset = handleGrabOffset ?? grabOffset(for: handle, from: value.startLocation, in: size)
				handleGrabOffset = offset
				let target = CGPoint(x: value.location.x + offset.width, y: value.location.y + offset.height)
				divider.moveHandle(handle, toward: target, in: size)
			}
			.onEnded { _ in
				handleGrabOffset = nil
			}
	}

	private func grabOffset(for handle: SwipeDivider.Handle, from pointer: CGPoint, in size: CGSize) -> CGSize {
		let framePoint = divider[handle].point(in: size)
		return CGSize(width: framePoint.x - pointer.x, height: framePoint.y - pointer.y)
	}

	private func lineDrag(in size: CGSize) -> some Gesture {
		DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.coordinateSpaceName))
			.onChanged { value in
				let start = dividerAtDragStart ?? divider
				dividerAtDragStart = start
				divider = start.slid(by: value.translation, in: size)
			}
			.onEnded { _ in
				dividerAtDragStart = nil
			}
	}
}

/// The part of the view on the right image's side of the divider.
private nonisolated struct RightImageRegion: Shape {
	let divider: SwipeDivider

	func path(in rect: CGRect) -> Path {
		let points = divider.rightImageRegion(in: rect.size).map { CGPoint(x: rect.minX + $0.x, y: rect.minY + $0.y) }
		return Path { path in
			path.addLines(points)
			path.closeSubpath()
		}
	}
}
