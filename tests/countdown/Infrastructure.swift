// Only platform visuals/haptics are faked. The complete production countdown
// file and its XCTest suite compile unchanged in the host-free runner.
import SwiftUI

enum UIAccessibility { static let isReduceMotionEnabled = false }
enum SGTheme {
    static let spring = Animation.spring(response: 0.45, dampingFraction: 0.8)
    static let caption = Font.caption
    static let paper = Color.white
    static let paperSecondary = Color.gray
    static let mintDeep = Color.green
    static let emberDeep = Color.orange
    static func display(_ size: CGFloat) -> Font { .system(size: size) }
    static func tickUpHaptic() {}
    static func tickDownHaptic(progress: Double) {}
}
