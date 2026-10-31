import SwiftUI

struct InfoBar: View {
	let left:       ComparisonImage
	let right:      ComparisonImage
	let mode:       ComparisonMode
	let diffResult: DiffResult?
	@Binding var onionSkinOpacity: Double
	@Binding var threshold:        Double

	var body: some View {
		HStack(spacing: 16) {
			ImageSummary(image: left, alignment: .leading)
			Spacer(minLength: 0)
			modeControls
			Spacer(minLength: 0)
			ImageSummary(image: right, alignment: .trailing)
		}
		.padding(.horizontal)
		.padding(.vertical, 8)
		.background(.bar)
	}

	@ViewBuilder
	private var modeControls: some View {
		switch mode {
			case .onionSkin:
				HStack {
					Text("Left")
					Slider(value: $onionSkinOpacity, in: 0...1)
						.frame(width: 180)
					Text("Right")
				}
				.font(.caption)
			case .difference:
				HStack(spacing: 12) {
					DiffSummary(diffResult: diffResult)
						.lineLimit(1)
						.fixedSize()
					Slider(value: $threshold, in: ImageDiffer.thresholdRange) {
						Text("Threshold")
					}
					.frame(width: 160)
					Text("ΔE \(threshold.formatted(.number.precision(.fractionLength(1))))")
						.monospacedDigit()
						.frame(minWidth: 48, alignment: .leading)
				}
				.font(.caption)
			case .sideBySide, .swipe:
				EmptyView()
		}
	}
}

private struct ImageSummary: View {
	let image:     ComparisonImage
	let alignment: HorizontalAlignment

	var body: some View {
		VStack(alignment: alignment, spacing: 2) {
			Text(image.fileName)
				.font(.callout.bold())
				.lineLimit(1)
				.truncationMode(.middle)
			Text(details)
				.font(.caption)
				.foregroundStyle(.secondary)
				.monospacedDigit()
		}
		.frame(maxWidth: 260, alignment: Alignment(horizontal: alignment, vertical: .center))
	}

	private var details: String {
		let dimensions = "\(Int(image.pixelSize.width)) × \(Int(image.pixelSize.height)) px"
		guard let fileSize = image.fileSize else { return dimensions }
		return "\(dimensions) · \(Int64(fileSize).formatted(.byteCount(style: .file)))"
	}
}

private struct DiffSummary: View {
	let diffResult: DiffResult?

	var body: some View {
		if let diffResult {
			if diffResult.differingPixelFraction == 0 {
				Label("No differences above threshold", systemImage: "checkmark.circle")
					.foregroundStyle(.green)
			} else {
				Text("\(diffResult.differingPixelFraction.formatted(.percent.precision(.fractionLength(2)))) different · max ΔE \(diffResult.maxDeltaE.formatted(.number.precision(.fractionLength(1))))")
					.monospacedDigit()
			}
		} else {
			Text("Comparing…")
				.foregroundStyle(.secondary)
		}
	}
}
