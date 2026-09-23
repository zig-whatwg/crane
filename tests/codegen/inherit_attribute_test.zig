//! `inherit attribute` is writable.
//!
//! WebIDL §2.5.2: "A regular attribute that is not read only can be declared
//! to inherit its getter from an ancestor interface. This can be used to make
//! a read only attribute in an ancestor interface be writable on a derived
//! interface." DOMPoint, DOMRect and DOMMatrix make their read-only parents'
//! coordinates writable that way.

const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

test "an inherit attribute is not read only" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const idl =
        \\interface DOMRectReadOnly { readonly attribute unrestricted double x; };
        \\interface DOMRect : DOMRectReadOnly { inherit attribute unrestricted double x; };
    ;
    const file = try codegen.idl_parser.Parser.parse(arena.allocator(), idl);
    try testing.expectEqual(@as(usize, 2), file.interfaces.len);
    try testing.expect(file.interfaces[0].members[0].attribute.?.readonly);
    const inherited = file.interfaces[1].members[0].attribute.?;
    try testing.expectEqualStrings("x", inherited.name);
    try testing.expect(!inherited.readonly);
    try testing.expect(!inherited.static);
}
