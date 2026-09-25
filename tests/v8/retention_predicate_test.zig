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

test "Instance pointers are inert - the conversion reads the wrapper and keeps nothing" {
    // conv.fromV8Value's `*runtime.Instance` branch checks the object, reads its
    // WrapperTypeInfo and internal field 0, and returns the pointer; the
    // context is never stored. This was pinned "retains" as a precaution, which
    // kept every fetch(request) and new Headers(init) leaking its context - each
    // one pinning the page. (The use-after-frees in this predicate's history
    // came from a union's callback arm, not from Instance pointers.)
    try std.testing.expect(!retains(*runtime.Instance));
    try std.testing.expect(!retains(?*runtime.Instance));
}

test "a dictionary of inert members is inert" {
    // Dictionary conversion converts member by member with the same rules, and
    // the context is used only while it does.
    const RequestInitShaped = struct {
        method: ?[]const u8 = null,
        headers: ?union(enum) { pairs: []const []const []const u8, record: []const runtime.DOMString } = null,
        signal: ?*runtime.Instance = null,
        window: ?runtime.JSValue = null,
        keepalive: ?bool = null,
    };
    try std.testing.expect(!retains(RequestInitShaped));
}

test "buffer sources are inert - views made without the context" {
    const webidl = @import("webidl");
    try std.testing.expect(!retains(webidl.BufferSource));
    try std.testing.expect(!retains(webidl.AllowSharedBufferSource));
    const BodyInitShaped = union(enum) { stream: *runtime.Instance, bytes: webidl.BufferSource, text: runtime.DOMString };
    try std.testing.expect(!retains(BodyInitShaped));
}

test "a union of inert arms is inert" {
    const RequestInfoShaped = union(enum) { request: *runtime.Instance, url: runtime.DOMString };
    try std.testing.expect(!retains(RequestInfoShaped));
}

test "a sequence is as inert as its element" {
    // fromV8Sequence converts each element with the element's own rules.
    try std.testing.expect(!retains([]const runtime.DOMString));
    try std.testing.expect(!retains([]const []const u8));
    try std.testing.expect(!retains([]runtime.JSValue));
    try std.testing.expect(retains([]const *anyopaque));
}

test "one member that may keep the context makes the whole dictionary retain" {
    const UnderlyingSourceShaped = struct {
        type: ?runtime.DOMString = null,
        start: ?*const fn () callconv(.c) void = null,
    };
    try std.testing.expect(retains(UnderlyingSourceShaped));
    const WithCallback = struct { a: ?bool = null, cb: ?*runtime.CallbackWrapper = null };
    try std.testing.expect(retains(WithCallback));
    const Nested = struct { inner: ?struct { x: u32, h: union(enum) { s: runtime.DOMString, f: *anyopaque } } = null };
    try std.testing.expect(retains(Nested));
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

    // And any pointer it does not know - to anything but an Instance.
    try std.testing.expect(retains(*anyopaque));
    try std.testing.expect(retains(*runtime.CallbackWrapper));
}

// ---------------------------------------------------------------------------
// `argHandleIsCopied` - may the Global<Value> that `info.get(N)` allocated be
// released once conversion returns?
//
// The sibling predicate, and the riskier one. `typeRetainsContext` asks whether
// the CONTEXT survives; this asks whether the ARGUMENT HANDLE does, and for
// some types `conv.fromV8Value` does not copy out of it at all - it adopts the
// pointer. Releasing one of those is a use-after-free.
//
// Same allowlist discipline, same reason, and the polarity is inverted from the
// predicate above: here TRUE means "safe to release", so an unrecognised type
// must answer FALSE. The last test pins that.
// ---------------------------------------------------------------------------

const copied = v8.interface_mod.argHandleIsCopied;

test "argHandleIsCopied - scalars are copied out of the handle" {
    try std.testing.expect(copied(bool));
    try std.testing.expect(copied(i32));
    try std.testing.expect(copied(u32));
    try std.testing.expect(copied(f64));
}

test "argHandleIsCopied - DOMString is copied: initOwned, not a borrow" {
    // `fromV8Value` -> `fromV8String` -> `DOMString.initOwned(buffer)`. The bytes
    // are the DOMString's own, and the V8 string they came from is released by
    // `v8_FreeToStringResult` before the conversion returns. Nothing points into
    // the argument handle afterwards.
    try std.testing.expect(copied(runtime.DOMString));
    try std.testing.expect(copied([]const u8));
}

test "argHandleIsCopied - JSValue is NOT, it keeps the pointer" {
    // The distinction that makes this a separate predicate from the one above.
    // JSValue does not retain the CONTEXT - `typeRetainsContext(JSValue)` is
    // false, asserted earlier in this file - but it absolutely retains the VALUE:
    // `.handle = .{ .ptr = value, .handle_scope = .local }`. Releasing the
    // argument handle would free what it points at.
    try std.testing.expect(!copied(runtime.JSValue));
    try std.testing.expect(!copied(?runtime.JSValue));
}

test "argHandleIsCopied - function pointers adopt the handle outright" {
    // conversions.zig is explicit: "The value is already a Global<Value>* from
    // v8_FunctionCallbackInfo_GetArgument. We don't need to create another
    // Global - just use this one directly." Ownership transfers to the callback
    // wrapper, which disposes it later.
    const FnPtr = *const fn () callconv(.c) void;
    try std.testing.expect(!copied(FnPtr));
}

test "argHandleIsCopied - Instance pointers and handler unions are NOT copied" {
    try std.testing.expect(!copied(*runtime.Instance));
    const TimerHandlerShaped = union(enum) {
        domstring: runtime.DOMString,
        function: *anyopaque,
    };
    try std.testing.expect(!copied(TimerHandlerShaped));
}

test "argHandleIsCopied - wrappers follow their payload" {
    try std.testing.expect(copied(?runtime.DOMString));
    try std.testing.expect(copied(?i32));
    try std.testing.expect(!copied(?*runtime.Instance));
}

test "argHandleIsCopied - an unknown type defaults to NOT copied" {
    // The property the design rests on, in its inverted form. TRUE here means
    // "release the handle", so the fallthrough must be FALSE: an unrecognised
    // type keeps its handle and keeps the old leak, which costs memory and never
    // correctness.
    const SomethingNew = struct { a: u32, b: *anyopaque };
    try std.testing.expect(!copied(SomethingNew));
    try std.testing.expect(!copied([]runtime.JSValue));
}
