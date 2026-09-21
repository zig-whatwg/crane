//! `typeRetainsContext` — can converting a value of this type make the engine
//! hold on to the V8 context past the call?
//!
//! This predicate decides whether a method dispatcher may release the context
//! handle it allocated. Getting it wrong in the permissive direction is a
//! use-after-free, and that is not hypothetical — it happened twice in one
//! session, both times because the test was written as a BLOCKLIST:
//!
//!   * "retains unless `PayloadType` is an Instance pointer or JSValue"
//!     → 2-3 crashes per run of `html/webappapis/timers/ --parallel=3`,
//!       against 0 without. Committed, then reverted.
//!   * "retains only for `*runtime.CallbackWrapper`"
//!     → 10 crashes out of 12 files, because `setTimeout`'s handler is
//!       `typedefs.TimerHandler`, a union whose `function` arm is a callback.
//!
//! A blocklist over an open set of types is wrong by default: every type nobody
//! thought of falls on the dangerous side. The predicate is now an allowlist, so
//! an unrecognised type answers "retains" and the old leak is preserved — which
//! costs memory and never correctness.
//!
//! These tests exist to keep it that way. The last one is the important one: it
//! asserts the DEFAULT, so a future edit that flips the fallthrough to `false`
//! fails here rather than in a WPT crash log.

const std = @import("std");
const v8 = @import("v8");
const runtime = @import("runtime");

const retains = v8.interface_mod.typeRetainsContext;

test "scalars are inert" {
    // Converting these yields a plain Zig value; no handle outlives the call.
    try std.testing.expect(!retains(bool));
    try std.testing.expect(!retains(i32));
    try std.testing.expect(!retains(u32));
    try std.testing.expect(!retains(i64));
    try std.testing.expect(!retains(f64));
    try std.testing.expect(!retains(void));
}

test "strings are inert - they own their bytes, not a V8 handle" {
    try std.testing.expect(!retains(runtime.DOMString));
    try std.testing.expect(!retains([]const u8));
}

test "a TimerHandler-shaped union retains - the case that caused 10 crashes of 12" {
    // `typedefs.TimerHandler` is `union(enum) { domstring, function, trusted_script }`,
    // and its `function` arm is a callback. The earlier predicate only looked for
    // `*runtime.CallbackWrapper`, answered "inert" here, and released a context
    // `setTimeout` goes on to use.
    //
    // Reconstructed locally rather than imported: the `typedefs` module is not in
    // this test target's import set, and what is being asserted is that the
    // predicate rejects the SHAPE - a union with a non-inert arm - rather than
    // that it knows one particular type's name. A predicate that only recognised
    // `TimerHandler` by name would pass an import-based test and still fail on the
    // next such union.
    const TimerHandlerShaped = union(enum) {
        domstring: runtime.DOMString,
        function: *anyopaque,
        trusted_script: *runtime.Instance,
    };
    try std.testing.expect(retains(TimerHandlerShaped));
}

test "JSValue does NOT retain the CONTEXT, though it carries a value handle" {
    // The distinction this predicate is about. `conv.fromV8Value`'s JSValue branch
    // returns `.handle = .{ .ptr = value, .handle_scope = .local }` and uses
    // `context` only transiently, so the context is free to release even though a
    // value handle survives. Conflating the two kept `createElement`, whose second
    // parameter is `webidl.Opt(JSValue)`, leaking on the DOM's hottest path.
    try std.testing.expect(!retains(runtime.JSValue));
}

test "Instance pointers retain" {
    try std.testing.expect(retains(*runtime.Instance));
    try std.testing.expect(retains(?*runtime.Instance));
}

test "optionals inherit their payload's answer" {
    try std.testing.expect(!retains(?i32));
    try std.testing.expect(!retains(?runtime.DOMString));
    try std.testing.expect(!retains(?runtime.JSValue));
}

test "an unknown type defaults to RETAINS" {
    // The property the whole design rests on. A struct the predicate has never
    // heard of must land on the safe side, because the set of types is open and
    // the next one added will not be in any list.
    const SomethingNew = struct { a: u32, b: *anyopaque };
    try std.testing.expect(retains(SomethingNew));

    const AUnion = union(enum) { x: u32, y: *anyopaque };
    try std.testing.expect(retains(AUnion));

    // Including slices: conversion allocates, and the element type is not the
    // whole story.
    try std.testing.expect(retains([]runtime.JSValue));
}
