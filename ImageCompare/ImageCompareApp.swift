import SwiftUI

@main
struct ImageCompareApp: App {
	@NSApplicationDelegateAdaptor(ImageOpenDelegate.self) private var imageOpenDelegate

	var body: some Scene {
		WindowGroup(for: ImageOpenRequest.self) { $request in
			ComparisonWindow(request: request, imageOpenDelegate: imageOpenDelegate)
		}
		.defaultSize(width: 1200, height: 800)
		.commands {
			ComparisonCommands()
		}
	}
}

/// Keeps the files in one Finder/Dock open event together in a single comparison.
struct ImageOpenRequest: Codable, Hashable {
	var id = UUID()
	let urls: [URL]
}

final class ImageOpenDelegate: NSObject, NSApplicationDelegate {
	var openComparison: ((ImageOpenRequest) -> Void)? {
		didSet {
			guard let openComparison else { return }
			let requests = pendingRequests
			pendingRequests.removeAll()
			for request in requests { openComparison(request) }
		}
	}
	private var pendingRequests: [ImageOpenRequest] = []

	func application(_ application: NSApplication, open urls: [URL]) {
		guard !urls.isEmpty else { return }
		let request = ImageOpenRequest(urls: Array(urls.prefix(2)))
		if let openComparison {
			openComparison(request)
		} else {
			// Finder may deliver files before the first SwiftUI window is ready.
			pendingRequests.append(request)
		}
		application.activate(ignoringOtherApps: true)
	}
}

private struct ComparisonWindow: View {
	let request: ImageOpenRequest?
	let imageOpenDelegate: ImageOpenDelegate
	@Environment(\.openWindow) private var openWindow

	var body: some View {
		ContentView(initialURLs: request?.urls ?? [])
			.onAppear {
				imageOpenDelegate.openComparison = { request in
					openWindow(value: request)
				}
			}
	}
}
