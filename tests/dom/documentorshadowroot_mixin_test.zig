//! Tests migrated from webidl/src/dom/DocumentOrShadowRoot.zig
//! WebIDL interface tests

const std = @import("std");
const dom = @import("dom");


test "DocumentOrShadowRoot - initial state" {
    const TestDocOrShadow = struct {
        doc_or_shadow: DocumentOrShadowRoot = .{},
    };

    var obj = TestDocOrShadow{};

    try std.testing.expectEqual(@as(?*anyopaque, null), obj.doc_or_shadow.get_customElementRegistry());
}
test "DocumentOrShadowRoot - set registry" {
    const TestDocOrShadow = struct {
        doc_or_shadow: DocumentOrShadowRoot = .{},
    };

    var obj = TestDocOrShadow{};
    var mock_registry: u32 = 42;

    obj.doc_or_shadow.setCustomElementRegistry(@ptrCast(&mock_registry));
    try std.testing.expect(obj.doc_or_shadow.get_customElementRegistry() != null);
    try std.testing.expect(obj.doc_or_shadow.getCustomElementRegistry() != null);
}