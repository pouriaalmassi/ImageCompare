import CoreImage
import Foundation

nonisolated enum ComparisonImageError: LocalizedError {
	case unreadable(URL)

	var errorDescription: String? {
		switch self {
			case .unreadable(let url):
				"“\(url.lastPathComponent)” couldn’t be opened as an image."
		}
	}
}

/// One side of a comparison: the decoded image plus the file metadata shown in the info bar.
nonisolated struct ComparisonImage: Identifiable, Sendable {
	// MARK: Public Variables
	let id:       UUID
	let url:      URL
	let ciImage:  CIImage
	let cgImage:  CGImage
	let fileSize: Int?

	var fileName:  String { url.lastPathComponent }
	var pixelSize: CGSize { ciImage.extent.size }

	// MARK: Loading
	@concurrent
	static func load(from url: URL, context: CIContext = .shared) async throws -> ComparisonImage {
		let isSecurityScoped = url.startAccessingSecurityScopedResource()
		defer {
			if isSecurityScoped {
				url.stopAccessingSecurityScopedResource()
			}
		}

		guard let decoded = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else {
			throw ComparisonImageError.unreadable(url)
		}

		// Applying EXIF orientation can move the extent away from the origin; the diff pipeline assumes (0, 0).
		let oriented = decoded.movedToOrigin()
		guard let cgImage = context.createCGImage(oriented, from: oriented.extent) else {
			throw ComparisonImageError.unreadable(url)
		}

		// Rebuild from the decoded bitmap so later renders don't lazily re-read the file after
		// security-scoped access has ended.
		let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
		return ComparisonImage(id: UUID(), url: url, ciImage: CIImage(cgImage: cgImage), cgImage: cgImage, fileSize: fileSize)
	}
}
