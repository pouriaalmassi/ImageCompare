import SwiftUI
import UniformTypeIdentifiers

/// One comparison window. Owns the window's state; the mode views below only render it.
struct ContentView: View {
	private static let diffDebounce: Duration = .milliseconds(120)

	var initialURLs: [URL] = []
	@State private var didLoadInitialURLs = false

	@State private var pair             = ImagePair()
	@State private var mode             = ComparisonMode.swipe
	@State private var viewport         = Viewport()
	@State private var swipeDivider     = SwipeDivider()
	@State private var onionSkinOpacity = 0.5
	@State private var threshold        = ImageDiffer.defaultThreshold
	@State private var diffResult:       DiffResult?
	@State private var isDiffing        = false
	@State private var importingSide:    ImageSide?
	/// Survives the importer's dismissal, which clears `importingSide` before the completion handler runs.
	@State private var importTargetSide = ImageSide.left
	@State private var errorMessage:     String?
	@State private var comparisonWidth:  CGFloat = 0

	var body: some View {
		Group {
			if let left = pair.left, let right = pair.right {
				comparison(left: left, right: right)
			} else {
				setup
			}
		}
		.frame(minWidth: 640, minHeight: 420)
		// Still names the window in the Window menu and Mission Control.
		.navigationTitle(windowTitle)
		.toolbar(removing: .title)
		.toolbar { toolbarContent }
		.fileImporter(isPresented: isImporterPresented, allowedContentTypes: [.image]) { result in
			switch result {
				case .success(let url):
					load(url, into: importTargetSide)
				case .failure(let error):
					errorMessage = error.localizedDescription
			}
		}
		.alert("Couldn’t Open Image", isPresented: isErrorPresented, presenting: errorMessage) { _ in
			Button("OK") {}
		} message: { message in
			Text(message)
		}
		.onChange(of: importingSide) {
			if let importingSide {
				importTargetSide = importingSide
			}
		}
		.task {
			guard !didLoadInitialURLs else { return }
			didLoadInitialURLs = true
			handleDrop(initialURLs, preferredSide: .left)
		}
		.task(id: diffRequest) {
			await updateDiff()
		}
		.onChange(of: [pair.left?.id, pair.right?.id]) {
			diffResult = nil
		}
		.focusedSceneValue(\.importingSide, $importingSide)
		.focusedSceneValue(\.imagePair, $pair)
		.focusedSceneValue(\.viewport, pair.isComplete ? $viewport : nil)
		.focusedSceneValue(\.comparisonMode, pair.isComplete ? $mode : nil)
	}

	// MARK: Content
	private var setup: some View {
		HStack(spacing: 16) {
			ForEach(ImageSide.allCases, id: \.self) { side in
				ImageDropSlot(side: side, image: pair[side]) { urls in
					handleDrop(urls, preferredSide: side)
				} onChoose: {
					importingSide = side
				}
			}
		}
		.padding(24)
	}

	private func comparison(left: ComparisonImage, right: ComparisonImage) -> some View {
		VStack(spacing: 0) {
			modeView(left: left, right: right)
				.background(Color(nsColor: .underPageBackgroundColor))
				.dropDestination(for: URL.self) { urls, location in
					handleDrop(urls, preferredSide: location.x < comparisonWidth / 2 ? .left : .right)
					return !urls.isEmpty
				}
				.onGeometryChange(for: CGFloat.self, of: \.size.width) { comparisonWidth = $0 }
			Divider()
			InfoBar(
				left: left,
				right: right,
				mode: mode,
				diffResult: diffResult,
				onionSkinOpacity: $onionSkinOpacity,
				threshold: $threshold
			)
		}
	}

	@ViewBuilder
	private func modeView(left: ComparisonImage, right: ComparisonImage) -> some View {
		switch mode {
			case .sideBySide:
				SideBySideView(left: left, right: right, canvasSize: pair.canvasSize, viewport: $viewport)
			case .swipe:
				SwipeView(left: left, right: right, canvasSize: pair.canvasSize, viewport: $viewport, divider: $swipeDivider)
			case .onionSkin:
				OnionSkinView(left: left, right: right, canvasSize: pair.canvasSize, viewport: $viewport, opacity: onionSkinOpacity)
			case .difference:
				DifferenceView(diffResult: diffResult, isDiffing: isDiffing, canvasSize: pair.canvasSize, viewport: $viewport)
		}
	}

	@ToolbarContentBuilder
	private var toolbarContent: some ToolbarContent {
		ToolbarItem(placement: .principal) {
			Picker("Mode", selection: $mode) {
				ForEach(ComparisonMode.allCases) { mode in
					Label(mode.title, systemImage: mode.systemImage)
						.tag(mode)
				}
			}
			.pickerStyle(.segmented)
			.disabled(!pair.isComplete)
		}

		ToolbarItemGroup {
			Button("Swap", systemImage: "arrow.left.arrow.right") { pair.swap() }
				.help("Swap left and right images")
				.disabled(!pair.isComplete)

			ControlGroup {
				Button("Zoom Out", systemImage: "minus.magnifyingglass") { viewport.zoomOut() }
				Button("Zoom to Fit", systemImage: "arrow.up.left.and.down.right.magnifyingglass") { viewport.fit() }
				Button("Zoom In", systemImage: "plus.magnifyingglass") { viewport.zoomIn() }
			}
			.disabled(!pair.isComplete)

			Text(Double(viewport.scale).formatted(.percent.precision(.fractionLength(0))))
				.monospacedDigit()
				.foregroundStyle(.secondary)
				.frame(minWidth: 48)
				.opacity(pair.isComplete ? 1 : 0)
		}
	}

	// MARK: Private Variables
	private var windowTitle: String {
		guard let left = pair.left, let right = pair.right else { return "ImageCompare" }
		return "\(left.fileName) ↔ \(right.fileName)"
	}

	private var isImporterPresented: Binding<Bool> {
		Binding {
			importingSide != nil
		} set: { isPresented in
			if !isPresented {
				importingSide = nil
			}
		}
	}

	private var isErrorPresented: Binding<Bool> {
		Binding {
			errorMessage != nil
		} set: { isPresented in
			if !isPresented {
				errorMessage = nil
			}
		}
	}

	/// Identifies the diff that should currently be shown; nil when the Difference mode isn't visible.
	private var diffRequest: DiffRequest? {
		guard mode == .difference, let left = pair.left, let right = pair.right else { return nil }
		return DiffRequest(leftID: left.id, rightID: right.id, threshold: threshold)
	}

	// MARK: Private Functions
	/// Two dropped files fill both sides; one file goes to the side it was dropped on.
	private func handleDrop(_ urls: [URL], preferredSide: ImageSide) {
		if urls.count >= 2 {
			load(urls[0], into: .left)
			load(urls[1], into: .right)
		} else if let url = urls.first {
			load(url, into: preferredSide)
		}
	}

	private func load(_ url: URL, into side: ImageSide) {
		Task {
			do {
				pair[side] = try await ComparisonImage.load(from: url)
				viewport.fit()
			} catch {
				errorMessage = error.localizedDescription
			}
		}
	}

	private func updateDiff() async {
		guard let request = diffRequest, let left = pair.left, let right = pair.right else {
			isDiffing = false
			return
		}
		isDiffing = true
		do {
			// Debounce so dragging the threshold slider doesn't queue a diff per tick.
			try await Task.sleep(for: Self.diffDebounce)
			diffResult = try await ImageDiffer().diff(left.ciImage, right.ciImage, threshold: request.threshold)
		} catch is CancellationError {
			// A newer request replaced this one; it owns `isDiffing` now.
			return
		} catch {
			errorMessage = error.localizedDescription
		}
		isDiffing = false
	}
}

private struct DiffRequest: Equatable {
	let leftID:    UUID
	let rightID:   UUID
	let threshold: Double
}

#Preview {
	ContentView()
}
