import CoreImage
import SwiftUI
import Testing
@testable import ImageCompare

@MainActor
struct SwipeViewTests {
	@Test("A smaller right image does not reveal the left image across the divider")
	func smallerRightImage() throws {
		let pixels = try render(rightColor: .blue, rightWidth: 120)
		expectColor(pixels, x: 50, red: 255, green: 0, blue: 0)
		expectColor(pixels, x: 110, red: 0, green: 0, blue: 255)
		expectColor(pixels, x: 170, red: 255, green: 255, blue: 255)
	}

	@Test("Transparent right pixels do not reveal the left image across the divider")
	func transparentRightImage() throws {
		let pixels = try render(rightColor: .clear, rightWidth: 200)
		expectColor(pixels, x: 50, red: 255, green: 0, blue: 0)
		expectColor(pixels, x: 170, red: 255, green: 255, blue: 255)
	}

	private func image(color: CIColor, width: Int) throws -> ComparisonImage {
		let ciImage = CIImage(color: color).cropped(to: CGRect(x: 0, y: 0, width: width, height: 100))
		let cgImage = try #require(CIContext.shared.createCGImage(ciImage, from: ciImage.extent))
		return ComparisonImage(id: UUID(), url: URL(fileURLWithPath: "/test.png"),
			ciImage: ciImage, cgImage: cgImage, fileSize: nil)
	}

	private func render(rightColor: CIColor, rightWidth: Int) throws -> [UInt8] {
		let view = SwipeView(
			left: try image(color: .red, width: 200),
			right: try image(color: rightColor, width: rightWidth),
			canvasSize: CGSize(width: 200, height: 100),
			viewport: .constant(Viewport()), divider: .constant(SwipeDivider())
		)
		.frame(width: 200, height: 100)
		.background(.white)
		let rendered = try #require(ImageRenderer(content: view).cgImage)
		var bytes = [UInt8](repeating: 0, count: 200 * 100 * 4)
		try bytes.withUnsafeMutableBytes { buffer in
			let context = try #require(CGContext(data: buffer.baseAddress, width: 200, height: 100,
				bitsPerComponent: 8, bytesPerRow: 200 * 4, space: CGColorSpaceCreateDeviceRGB(),
				bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
			context.draw(rendered, in: CGRect(x: 0, y: 0, width: 200, height: 100))
		}
		return bytes
	}

	private func expectColor(_ pixels: [UInt8], x: Int, red: UInt8, green: UInt8, blue: UInt8) {
		let offset = (50 * 200 + x) * 4
		#expect(abs(Int(pixels[offset]) - Int(red)) < 5)
		#expect(abs(Int(pixels[offset + 1]) - Int(green)) < 5)
		#expect(abs(Int(pixels[offset + 2]) - Int(blue)) < 5)
	}
}
