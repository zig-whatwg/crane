import Crane
import SwiftUI

public protocol ElementLibrary {
    associatedtype TagName: RawRepresentable where TagName.RawValue == String
    
    associatedtype Body: View
    
    @MainActor
    @ViewBuilder
    static func render(_ tag: TagName, for node: Node) -> Body
}
