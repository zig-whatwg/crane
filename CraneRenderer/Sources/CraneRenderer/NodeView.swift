import Crane
import SwiftUI

public struct NodeView<Library: ElementLibrary>: View {
    let node: Node

    var body: some View {
        switch node.type {
        case .element:
            if let tagName = Library.TagName(rawValue: node.name) {
                Library.render(tagName, for: node)
            } else {
                node.children(library: Library.self)
            }
        case .text:
            if !node.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                SwiftUI.Text(node.value)
            }
        case .document, .documentFragment, .documentType:
            node.children(library: Library.self)
        default:
            EmptyView()
        }
    }
}

extension Node {
    func children<Library: ElementLibrary>(library: Library.Type = Library.self) -> some View {
        ForEach(self.children) { child in
            NodeView<Library>(node: child)
        }
    }
}