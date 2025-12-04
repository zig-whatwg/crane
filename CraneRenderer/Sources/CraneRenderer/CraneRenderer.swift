import Crane
import SwiftUI

/// A SwiftUI View that operates a CraneContext.
public struct CraneRenderer<Platform: CranePlatform, Library: ElementLibrary>: View {
    /// The context that acts as the source-of-truth for this View.
    /// 
    /// The context contains the active document, and a JS runtime.
    @State private var context: CraneContext<Platform>

    init(
        platform: Platform,
        library: Library.Type = Library.self
    ) {
        self.context = .init(wrappedValue: CraneContext(platform: platform))
    }

    var body: some View {
        SwiftUI.Group {
            NodeView<Library>(node: context.document)
        }
    }
}