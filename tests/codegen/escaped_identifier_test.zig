//! An escaped identifier's value drops its leading underscore.
//!
//! WebIDL §2.2: an identifier token may begin with "_" so that a keyword can
//! be used as a name, and "the identifier's value is the token's value with
//! the leading U+005F (_) removed". dom.idl declares AbortSignal's `any()` as
//! `static AbortSignal _any(...)`, so script must see `AbortSignal.any`, not
//! `AbortSignal._any`.

const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

test "a leading underscore is not part of the identifier" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const idl =
        \\interface AbortSignal {
        \\  static AbortSignal _any(sequence<AbortSignal> signals);
        \\  readonly attribute any _object;
        \\};
    ;
    const file = try codegen.idl_parser.Parser.parse(arena.allocator(), idl);
    const members = file.interfaces[0].members;
    try testing.expectEqualStrings("any", members[0].operation.?.name.?);
    try testing.expectEqualStrings("object", members[1].attribute.?.name);
}
