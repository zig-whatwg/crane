//! SVG 2 4.6.7 getter steps 1-2: read a reflected attribute, falling back
//! to its deprecated namespace only when the primary attribute is absent.
const runtime = @import("runtime");
const element_data = @import("element_data.zig");

/// Borrowed until the element's attributes change. Null means neither
/// attribute exists; a present empty primary value still wins the fallback.
pub fn value(element: *runtime.Instance, local_name: []const u8, deprecated_namespace: ?[]const u8) !?[]const u8 {
    const data = element_data.of(element) orelse return error.InvalidStateError;
    if (element_data.getAttributeByNamespaceAndLocalName(data, null, local_name)) |attribute| return attribute.value;
    if (deprecated_namespace) |ns| {
        if (element_data.getAttributeByNamespaceAndLocalName(data, ns, local_name)) |attribute| return attribute.value;
    }
    return null;
}
