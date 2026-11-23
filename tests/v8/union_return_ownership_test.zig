//! A union an operation or a getter RETURNS is owned as its active member
//! would be, returned on its own (lane bind1 batch B, B2: every union is
//! typed in every position, so unions now carry what a JSValue, a DOMString
//! or a callback result carried before):
//!
//! - a runtime.JSValue member is the binding's (engine.Owned.take: "the
//!   binding releases what an impl returns"), but an instance's wrapper, the
//!   wrapper cache's;
//! - a callback function member is BORROWED, as an EventHandler getter's;
//! - an owned DOMString member is the binding's to free; an interned one is
//!   not freed;
//! - a nested union answers by its own active member.
//!
//! Before, a union's JSValue member was answered "kept", and ImageData.data
//! handed back a handle it kept; a string member's bytes were never freed.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const conv = v8.conversions;

const Nested = union(enum) {
    domstring: runtime.DOMString,
    long: i32,
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "domstring", .kind = .string },
        .{ .field = "long", .kind = .numeric },
    };
};

const Result = union(enum) {
    object: runtime.JSValue,
    function: runtime.BorrowedCallbackFunction,
    nested: Nested,
    element: *runtime.Instance,
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "object", .kind = .object },
        .{ .field = "function", .kind = .callback_function },
        .{ .field = "nested", .kind = .@"union" },
        .{ .field = "element", .kind = .{ .interface = "Element" } },
    };
};

test "a JSValue member's handle is the binding's; an instance's wrapper is not" {
    var slot: u64 align(16) = 0;
    const handle: runtime.JSValue = .{ .handle = .{ .ptr = @ptrCast(&slot) } };
    try testing.expect(conv.unionReturnIsOwned(Result, .{ .object = handle }));
    var instance: runtime.Instance = undefined;
    try testing.expect(!conv.unionReturnIsOwned(Result, .{ .object = .{ .instance = &instance } }));
    // An interface member is its wrapper: the cache's.
    try testing.expect(!conv.unionReturnIsOwned(Result, .{ .element = &instance }));
}

test "a callback function member is borrowed" {
    var slot: u64 align(16) = 0;
    const function: runtime.BorrowedCallbackFunction = .{ .function = .{ .handle = .{ .ptr = @ptrCast(&slot) } } };
    try testing.expect(!conv.unionReturnIsOwned(Result, .{ .function = function }));
}

test "a nested union answers by its active member: a String made for a string member is released" {
    try testing.expect(conv.unionReturnIsOwned(Result, .{ .nested = .{ .domstring = runtime.DOMString.initInterned("x") } }));
    try testing.expect(conv.unionReturnIsOwned(Result, .{ .nested = .{ .long = 5 } }));
}

test "an owned string member is freed; an interned one is left" {
    // std.testing.allocator: a copy left behind, or freed twice, fails.
    const bytes = try testing.allocator.dupe(u8, "until-found");
    conv.freeReturnedUnion(Result, testing.allocator, .{ .nested = .{ .domstring = runtime.DOMString.initOwned(bytes) } });
    conv.freeReturnedUnion(Result, testing.allocator, .{ .nested = .{ .domstring = runtime.DOMString.initInterned("kept") } });
    conv.freeReturnedUnion(Result, testing.allocator, .{ .nested = .{ .long = 1 } });
}
