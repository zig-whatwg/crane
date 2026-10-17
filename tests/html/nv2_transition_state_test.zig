//! Ownership guard for Navigation.setTransition replacing its native record.
//! Navigation.zig:189-204,1623-1658 destroys only its edge and capabilities.
//! NavigationTransition.zig:38-55,101-122 owns its separate state: entries
//! and promises are wrapper edges; there is no pointer back to that record.
//! Pin the complete field sets so adding a back-pointer requires revisiting
//! the replacement-lifetime proof, rather than silently weakening it.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");

test "NavigationTransition state cannot refer to the replaceable native transition record" {
    const Own = @FieldType(interfaces.NavigationTransition.State, "own");
    try std.testing.expectEqual(@as(usize, 6), @typeInfo(Own).@"struct".fields.len);
    const NavigationType = @FieldType(Own, "navigationType");
    try std.testing.expect(@typeInfo(NavigationType) == .@"enum");
    try std.testing.expectEqual(@as(usize, 4), @typeInfo(NavigationType).@"enum".fields.len);
    // Generated enum fields use escaped Zig names; IDL spellings live in
    // NavigationType.idl_values instead.
    inline for (.{ "_push_", "_replace_", "_reload_", "_traverse_" }) |name| {
        try std.testing.expect(@hasField(NavigationType, name));
    }
    try std.testing.expect(@FieldType(Own, "from") == *runtime.Instance);
    try std.testing.expect(@FieldType(Own, "to") == *runtime.Instance);
    try std.testing.expect(@FieldType(Own, "committed") == runtime.JSValue);
    try std.testing.expect(@FieldType(Own, "finished") == runtime.JSValue);
    const InternalPointer = @typeInfo(@FieldType(Own, "_internal")).optional.child;
    const Internal = @typeInfo(InternalPointer).pointer.child;
    try std.testing.expectEqual(@as(usize, 4), @typeInfo(Internal).@"struct".fields.len);
    try std.testing.expect(@FieldType(Internal, "allocator") == std.mem.Allocator);
    try std.testing.expect(@FieldType(Internal, "has_promises") == bool);
    inline for (.{ "from_edge", "to_edge" }) |field| {
        const Edge = @FieldType(Internal, field);
        try std.testing.expectEqual(@as(usize, 2), @typeInfo(Edge).@"struct".fields.len);
        try std.testing.expect(@FieldType(Edge, "slot") == engine.TracedSlot);
        try std.testing.expect(@FieldType(Edge, "drawn") == bool);
    }
}
