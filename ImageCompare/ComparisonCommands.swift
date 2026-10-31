import SwiftUI

extension FocusedValues {
	@Entry var viewport:       Binding<Viewport>?
	@Entry var comparisonMode: Binding<ComparisonMode>?
	@Entry var importingSide:  Binding<ImageSide?>?
	@Entry var imagePair:      Binding<ImagePair>?
}

/// Menu items and shortcuts that act on the frontmost comparison window.
struct ComparisonCommands: Commands {
	@FocusedValue(\.viewport)       private var viewport
	@FocusedValue(\.comparisonMode) private var mode
	@FocusedValue(\.importingSide)  private var importingSide
	@FocusedValue(\.imagePair)      private var imagePair

	var body: some Commands {
		CommandGroup(after: .newItem) {
			Button("Open Left Image…") { importingSide?.wrappedValue = .left }
				.keyboardShortcut("o")
				.disabled(importingSide == nil)
			Button("Open Right Image…") { importingSide?.wrappedValue = .right }
				.keyboardShortcut("o", modifiers: [.command, .shift])
				.disabled(importingSide == nil)
		}

		CommandMenu("Compare") {
			ForEach(Array(ComparisonMode.allCases.enumerated()), id: \.element) { index, comparisonMode in
				Button(comparisonMode.title) { mode?.wrappedValue = comparisonMode }
					.keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .option)
			}
			.disabled(mode == nil)

			Divider()

			Button("Swap Left and Right") { imagePair?.wrappedValue.swap() }
				.keyboardShortcut("s", modifiers: [.command, .control])
				.disabled(imagePair == nil)

			Divider()

			Group {
				Button("Zoom In") { viewport?.wrappedValue.zoomIn() }
					.keyboardShortcut("=")
				Button("Zoom Out") { viewport?.wrappedValue.zoomOut() }
					.keyboardShortcut("-")
				Button("Zoom to Fit") { viewport?.wrappedValue.fit() }
					.keyboardShortcut("0")
				Button("Actual Size") { viewport?.wrappedValue.actualSize() }
					.keyboardShortcut("1")
			}
			.disabled(viewport == nil)
		}
	}
}
