//! `conversions.jsValueConversionIsFresh` - does toV8Value(runtime.JSValue)
//! make a new Global for this value, one the converter releases once the
//! object it was put in has it?
//!
//! A record<K, any> an operation returns (URLPattern exec()'s groups,
//! record<USVString, (USVString or undefined)>) is converted entry by entry,
//! and a JSValue's type cannot answer: `.handle` is the impl's own handle and
//! `.instance` converts to the wrapper cache's wrapper - releasing either is
//! a use-after-free - while undefined, null, booleans, numbers and strings are
//! made for the call (toV8Undefined, toV8Null, toV8Boolean, v8_Number_New,
//! newStringFromWtf8 each make a Global). Kept, those were one Global per
//! group per successful exec(): 9 per call on crane/up-exec-result-retention.html
//! (leaks --atExit, 182 for 20 calls; Codex row 26 Q14).
//!
//! The predicate is an ALLOWLIST of arms (retention_predicate_test.zig says
//! why): an arm it does not name answers false - keep the handle, keep the
//! leak - so the last test pins that default.

const std = @import("std");
const v8 = @import("v8");
const runtime = @import("runtime");

const fresh = v8.conversions.jsValueConversionIsFresh;

test "primitives and strings are made for the call" {
    try std.testing.expect(fresh(.{ .undefined = {} }));
    try std.testing.expect(fresh(.{ .null = {} }));
    try std.testing.expect(fresh(.{ .boolean = true }));
    try std.testing.expect(fresh(.{ .number = 1.5 }));
    try std.testing.expect(fresh(runtime.JSValue.fromStringRef("group")));
    try std.testing.expect(fresh(runtime.JSValue.fromStringRef("")));
}

test "a handle is the impl's and an instance's wrapper the cache's: kept" {
    var slot: u64 align(8) = 0;
    try std.testing.expect(!fresh(.{ .handle = .{ .ptr = @ptrCast(&slot) } }));
    try std.testing.expect(!fresh(.{ .instance = @ptrCast(&slot) }));
}

test "the default is kept: every arm not named answers false" {
    // Each arm of runtime.JSValue, by name: a new arm fails here until it is
    // classified, instead of falling on the releasing side.
    const named = [_][]const u8{ "undefined", "null", "boolean", "number", "string", "handle", "instance" };
    inline for (std.meta.fields(runtime.JSValue)) |field| {
        var found = false;
        for (named) |name| found = found or std.mem.eql(u8, name, field.name);
        if (!found) {
            std.debug.print("runtime.JSValue arm '{s}' is not classified\n", .{field.name});
            return error.UnclassifiedArm;
        }
    }
}
