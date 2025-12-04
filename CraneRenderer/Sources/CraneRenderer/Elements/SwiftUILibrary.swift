import Crane
import SwiftUI

@MainActor
public struct SwiftUILibrary: ElementLibrary {
    public enum TagName: String {
        case text = "Text"
        case button = "Button"
    }

    @ViewBuilder
    static func render(_ tag: TagName, for node: Node) -> some View {
        switch tag {
        case .text:
            Text(node)
        case .button:
            Button(node)
        }
    }
}
