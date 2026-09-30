//! Who releases a JSValue handle is its holder's type, never the handle.
//!
//! AGENTS.md "The engine boundary", rule 3: a `runtime.JSValue` is BORROWED
//! wherever it is passed; what must be released is an `engine.Owned` (or
//! another owning type), released exactly once; and a JSValue an impl
//! returns is the binding's, which releases it once it is the call's result.
//! The handle itself carries no flag saying otherwise - one used to
//! (`needs_disposal`, and a `.local`/`.global` tag that meant "borrowed"),
//! and every getter that returned a kept value borrowed through it.

const std = @import("std");
const runtime = @import("runtime");
const JSValue = runtime.JSValue;

test "an engine handle is only the engine's pointer" {
    const fields = @typeInfo(JSValue.EngineHandle).@"struct".fields;
    try std.testing.expectEqual(@as(usize, 1), fields.len);
    try std.testing.expectEqualStrings("ptr", fields[0].name);
}

test "fromHandle names the pointer it is given" {
    var dummy: u8 = 0;
    const value = JSValue.fromHandle(&dummy);
    try std.testing.expect(value == .handle);
    try std.testing.expectEqual(@as(*anyopaque, &dummy), value.handle.ptr);
}
