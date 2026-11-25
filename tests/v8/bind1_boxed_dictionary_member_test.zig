//! A dictionary member whose type is its own dictionary converts, boxed, and
//! is freed with its dictionary (lane bind1, batch B5 group 3a).
//!
//! Zig cannot lay out a struct that contains itself, so codegen types such a
//! member as an optional pointer and lists it in `boxed_members` (Service
//! Workers' RouterCondition: `RouterCondition not;`, typed `not: ?*const
//! RouterCondition`). The binding had no conversion for it: a pointer to a
//! struct was a TypeError ("buffer source conversion ... not yet
//! implemented"), so `{not: {...}}` threw. Nothing reached that while
//! service_worker/add_routes.zig read InstallEvent.addRoutes()'s rules by
//! hand; once the binding converted them, addRoutes([{condition: {not: ...},
//! source: ...}]) rejected, and six subtests failed (crane/sw1b4-routes
//! .https.html 4, service-workers/service-worker/static-router-main-resource
//! and -subresource 1 each).
//!
//! The conversion converts the pointee as its dictionary and boxes it with
//! the argument's allocator; `interface.freeConvertedArg` frees the
//! pointee's members and then the box - with the dictionary on success, and
//! when a later member (or a member inside the box) fails to convert. The
//! member's Get handle is released at conversion like any copying member's:
//! `argHandleIsCopied` answers for the pointee, with the self-reference
//! skipped while the dictionary is walked.
//!
//! std.testing.allocator sees the boxes; V8's own count of global handle
//! bytes sees the handles (the form of
//! tests/v8/argument_conversion_failure_handle_test.zig).

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const interfaces = @import("interfaces");
const iface = v8.interface_mod;

/// event.addRoutes(rules)'s `rules`: (RouterRule or sequence<RouterRule>).
const Rules = @typeInfo(@TypeOf(interfaces.InstallEvent.call_addRoutes)).@"fn".param_types[1].?;
const RouterRule = @FieldType(Rules, "router_rule");
/// RouterCondition: `not` is its own type, boxed; `or` a sequence of it.
const RouterCondition = @FieldType(RouterRule, "condition");

const Env = struct {
    isolate: *ffi.Isolate,
    context: *ffi.Context,
};

var test_env: ?Env = null;

/// The test's own agent, ended with the test (test_process.TestAgent);
/// `reset` clears what the file caches of it.
var test_agent: test_process.TestAgent = .{ .reset = reset };

fn reset() void {
    test_env = null;
}

fn env() !Env {
    const isolate = try test_agent.open(.{});
    if (test_env == null) test_env = .{ .isolate = isolate, .context = test_agent.context.? };
    return test_env.?;
}

/// Script's value of `code`, OWNED - a Global, as `info.get(i)` makes one.
fn eval(code: []const u8) !*ffi.Value {
    const e = try env();
    const text = ffi.v8_String_NewFromUtf8(e.isolate, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(e.context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(e.context, script) orelse error.RunFailed;
}

/// `code` converted to a `T` as the binding converts an argument: the
/// argument's handle released as its type says.
fn converted(comptime T: type, code: []const u8) !T {
    const e = try env();
    const arg = try eval(code);
    return iface.convertArgReleasingWith(T, .{}, testing.allocator, e.isolate, e.context, arg);
}

test "the ownership rules know a boxed dictionary member: it is freed, and its handle is copied out of" {
    // The box is an allocation, so the member and its dictionary need
    // cleanup; and the conversion copies everything out of the member's
    // handle, so the handle is released at conversion - RouterCondition has
    // no member that keeps one.
    try testing.expect(comptime iface.needsArgCleanup(?*const RouterCondition));
    try testing.expect(comptime iface.needsArgCleanup(RouterCondition));
    try testing.expect(comptime iface.argHandleIsCopied(?*const RouterCondition));
    try testing.expect(comptime iface.argHandleIsCopied(RouterCondition));
    try testing.expect(comptime iface.argHandleIsCopied(RouterRule));
}

test "{not: {...}} converts: the member is a box of its dictionary" {
    defer test_agent.close();
    const condition = try converted(RouterCondition, "({ not: { requestMode: 'cors', requestMethod: 'POST' } })");
    defer iface.freeConvertedArg(RouterCondition, testing.allocator, condition);
    try testing.expect(condition.requestMode == null);
    const inner = condition.not orelse return error.NotConverted;
    try testing.expect(inner.requestMode.? == ._cors_);
    try testing.expectEqualStrings("POST", inner.requestMethod.?);
    try testing.expect(inner.not == null);
}

test "a boxed member nests, beside a sequence of the dictionary" {
    defer test_agent.close();
    const condition = try converted(RouterCondition,
        \\({ not: { not: { runningStatus: 'running' }, or: [{ requestMode: 'navigate' }, { not: { requestMethod: 'GET' } }] } })
    );
    defer iface.freeConvertedArg(RouterCondition, testing.allocator, condition);
    const first = condition.not.?;
    const second = first.not.?;
    try testing.expect(second.runningStatus.? == ._running_);
    try testing.expect(second.not == null);
    const any_of = first.@"or".?;
    try testing.expectEqual(@as(usize, 2), any_of.len);
    try testing.expect(any_of[0].requestMode.? == ._navigate_);
    try testing.expectEqualStrings("GET", any_of[1].not.?.requestMethod.?);
}

test "a boxed member that is undefined is not present; null is the dictionary with no member" {
    defer test_agent.close();
    const absent = try converted(RouterCondition, "({ not: undefined, requestMode: 'cors' })");
    defer iface.freeConvertedArg(RouterCondition, testing.allocator, absent);
    try testing.expect(absent.not == null);
    // WebIDL 3.2.18: only undefined is "not present"; null converts by the
    // member's type, a dictionary - which null converts to with no member.
    const empty = try converted(RouterCondition, "({ not: null })");
    defer iface.freeConvertedArg(RouterCondition, testing.allocator, empty);
    const inner = empty.not orelse return error.NullReadAsAbsent;
    try testing.expect(inner.not == null and inner.requestMode == null and inner.urlPattern == null);
}

test "a failure inside the box, after the box, and a value that is no dictionary free every box" {
    defer test_agent.close();
    // Inside: requestMode is no RequestMode. std.testing.allocator fails the
    // test if the box, or the method string converted before it, is kept.
    try testing.expectError(error.TypeError, converted(RouterCondition, "({ not: { requestMethod: 'GET', requestMode: 'bogus' } })"));
    // After: `not` converts (members go in lexicographic order), then
    // requestMode fails.
    try testing.expectError(error.TypeError, converted(RouterCondition, "({ not: { not: { requestMethod: 'GET' } }, requestMode: 'bogus' })"));
    // Not a dictionary at all.
    try testing.expectError(error.TypeError, converted(RouterCondition, "({ not: 5 })"));
    // In a rule, and in a sequence of rules, the second of which fails.
    try testing.expectError(error.TypeError, converted(Rules, "([{ condition: { not: { requestMode: 'cors' } }, source: 'network' }, { condition: { not: { requestMode: 'bogus' } }, source: 'network' }])"));
}

/// The global handle bytes `rounds` conversions of `code` as a `T`, each
/// freed, leave after a warm-up.
fn bytesLeftBy(comptime T: type, code: []const u8, rounds: usize) !i64 {
    const e = try env();
    for (0..32) |_| {
        const value = try converted(T, code);
        iface.freeConvertedArg(T, testing.allocator, value);
    }
    const before: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(e.isolate));
    for (0..rounds) |_| {
        const value = try converted(T, code);
        iface.freeConvertedArg(T, testing.allocator, value);
    }
    const after: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(e.isolate));
    return after - before;
}

test "64 conversions of rules with boxed conditions leave no handle" {
    defer test_agent.close();
    // The control: the same rules without a boxed member.
    const plain = try bytesLeftBy(Rules, "([{ condition: { requestMode: 'cors' }, source: 'network' }, { condition: { or: [{ requestMethod: 'GET' }] }, source: { cacheName: 'c' } }])", 64);
    // One handle kept per conversion would be 64 handles: 1 KiB and more.
    try testing.expect(plain < 128);
    const boxed = try bytesLeftBy(Rules, "([{ condition: { not: { requestMode: 'cors' } }, source: 'network' }, { condition: { not: { not: { or: [{ requestMethod: 'GET' }] } } }, source: { cacheName: 'c' } }])", 64);
    if (boxed >= 128) std.debug.print("{d} global handle bytes left over 64 conversions with boxed members\n", .{boxed});
    try testing.expect(boxed < 128);
    const single = try bytesLeftBy(RouterCondition, "({ not: { not: { requestMode: 'cors' } } })", 64);
    try testing.expect(single < 128);
}
