import Crane
import SwiftUI

struct Text: View {
    let node: Node

    var body: some View {
        SwiftUI.Text(node.textContent)
    }
}