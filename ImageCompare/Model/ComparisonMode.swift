import Foundation

nonisolated enum ComparisonMode: String, CaseIterable, Identifiable {
	case swipe
	case sideBySide
	case onionSkin
	case difference

	var id: Self { self }

	var title: String {
		switch self {
			case .swipe:      "Swipe"
			case .sideBySide: "Side by Side"
			case .onionSkin:  "Onion Skin"
			case .difference: "Difference"
		}
	}

	var systemImage: String {
		switch self {
			case .swipe:      "slider.horizontal.below.rectangle"
			case .sideBySide: "rectangle.split.2x1"
			case .onionSkin:  "square.2.layers.3d"
			case .difference: "plusminus.circle"
		}
	}
}
