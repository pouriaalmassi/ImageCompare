import SwiftUI

/// Lays content out on a canvas of `contentSize` points (anchored top-left), then applies the shared
/// viewport's zoom and pan. Pinch to zoom, drag to pan.
struct ZoomableCanvas<Content: View>: View {
	@Binding var viewport: Viewport
	let contentSize: CGSize
	@ViewBuilder let content: Content

	@GestureState private var magnification:   CGFloat = 1
	@GestureState private var dragTranslation: CGSize  = .zero

	var body: some View {
		let displayed = displayedViewport

		content
			.frame(width: contentSize.width, height: contentSize.height, alignment: .topLeading)
			.scaleEffect(displayed.scale)
			.offset(displayed.offset)
			// minWidth/minHeight 0 let the canvas be smaller than the image; otherwise the frame grows to fit it.
			.frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
			.clipped()
			.contentShape(Rectangle())
			.gesture(magnifyGesture.simultaneously(with: dragGesture))
			.onGeometryChange(for: CGSize.self, of: \.size) { containerSize in
				viewport.layout(contentSize: contentSize, containerSize: containerSize)
			}
	}

	// MARK: Private Variables
	/// The committed viewport with any in-progress gesture applied, so zooming and panning track the fingers live.
	private var displayedViewport: Viewport {
		var displayed = viewport
		if magnification != 1 {
			displayed.setScale(viewport.scale * magnification)
		}
		displayed.pan(by: dragTranslation)
		return displayed
	}

	private var magnifyGesture: some Gesture {
		MagnifyGesture()
			.updating($magnification) { value, state, _ in
				state = value.magnification
			}
			.onEnded { value in
				viewport.setScale(viewport.scale * value.magnification)
			}
	}

	private var dragGesture: some Gesture {
		DragGesture(minimumDistance: 1)
			.updating($dragTranslation) { value, state, _ in
				state = value.translation
			}
			.onEnded { value in
				viewport.pan(by: value.translation)
			}
	}
}
