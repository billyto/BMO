import XCTest
import SwiftUI
import AppKit
@testable import BMOLib

/// The popover follows the hosting controller's preferred size, so a long
/// translation must make the main view taller than the classic 400pt
/// instead of being clipped, and a short one must keep it at 400pt.
@MainActor
final class PopoverSizingTests: XCTestCase {

    private func height(forTranslation text: String) -> CGFloat {
        let viewModel = TranslatorViewModel(translationService: nil)
        viewModel.translatedText = text
        let controller = NSHostingController(rootView: TranslatorView(viewModel: viewModel))
        controller.sizingOptions = .preferredContentSize
        controller.view.layoutSubtreeIfNeeded()
        return controller.view.fittingSize.height
    }

    func testShortTranslationKeepsDefaultHeight() {
        XCTAssertEqual(height(forTranslation: "Hello"), 400, accuracy: 1)
    }

    func testLongTranslationGrowsPopover() {
        let long = Array(repeating: "This is a fairly long translated sentence.", count: 12)
            .joined(separator: " ")
        let tall = height(forTranslation: long)
        print("Long translation popover height:", tall)
        XCTAssertGreaterThan(tall, 500)
    }
}
