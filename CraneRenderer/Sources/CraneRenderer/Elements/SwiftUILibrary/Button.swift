import Crane
import SwiftUI

struct Button: View {
    let node: Node

    var body: some View {
        SwiftUI.Button(
            action: {
                node.evaluate(#"""
                this.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
                this.dispatchEvent(new MouseEvent("mouseup", { bubbles: true }));
                this.dispatchEvent(new MouseEvent("click", { bubbles: true }));
                """#)
            }, label: {
                node.children()
            }
        )
    }
}