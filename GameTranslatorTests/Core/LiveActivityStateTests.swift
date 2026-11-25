import Foundation
import SwiftUI
import Testing
import UIKit
@testable import GameTranslator

struct LiveActivityStateTests {
    private func state(_ lines: [String], at seconds: Double = 0) -> LiveActivityAttributes.ContentState {
        .init(
            lines: lines, pendingCount: 2, isPaused: false, needsApp: false,
            updated: Date(timeIntervalSince1970: seconds)
        )
    }

    @Test func fitsActivityKitLimitAtTheLargestSetting() throws {
        let long = String(repeating: "ترجمة ", count: 200)
        let lines = Array(repeating: long, count: LiveSettings.lineCountRange.upperBound)
        #expect(try JSONEncoder().encode(state(lines)).count < 4096)
    }

    @Test func timeAloneIsNotNewContent() {
        #expect(state(["a"], at: 0).hasSameContent(as: state(["a"], at: 9)))
        #expect(!state(["a"]).hasSameContent(as: state(["b"])))
    }

    /// iOS cuts off anything taller than 160 points.
    @MainActor
    @Test(arguments: [0, 1, 2, LiveSettings.lineCountRange.upperBound], [false, true])
    func lockScreenViewFits(lineCount: Int, needsApp: Bool) {
        let long = String(repeating: "عد إلى المخبأ ", count: 12)
        let view = LiveActivityLockScreenView(state: .init(
            lines: Array(repeating: long, count: lineCount), pendingCount: 12, isPaused: true,
            needsApp: needsApp, updated: .now
        ))
        let size = UIHostingController(rootView: view).sizeThatFits(in: CGSize(width: 366, height: 2000))
        #expect(size.height <= 160)
    }
}
