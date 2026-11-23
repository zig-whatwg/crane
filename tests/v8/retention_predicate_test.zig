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
    // What this pins now is the SHAPE: an arm the predicate does not know (here
    // `*anyopaque`) makes the union retain. The real TimerHandler's arm is a
    // callback function, which has since been proven inert (see "callback
    // functions are inert" below) - that proof, and the timers regression
    // protocol, are what let its answer change; a guess would not.
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
    // returns `.handle = .{ .ptr = value }` and uses
    // `context` only transiently, so the context is free to release even though a
    // value handle survives. Conflating the two kept `createElement`, whose second
    // parameter is `webidl.Opt(JSValue)`, leaking on the DOM's hottest path.
    try std.testing.expect(!retains(runtime.JSValue));
}

test "Instance pointers are inert - the conversion reads the wrapper and keeps nothing" {
    // conv.fromV8Value's `*runtime.Instance` branch checks the object, reads its
    // internal field 0, and returns the pointer; the
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
        pub const webidl_dictionary = true;
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
    const WithUnknown = struct {
        pub const webidl_dictionary = true;
        a: ?bool = null,
        p: ?*anyopaque = null,
    };
    try std.testing.expect(retains(WithUnknown));
    const Nested = struct {
        pub const webidl_dictionary = true;
        inner: ?struct {
            pub const webidl_dictionary = true;
            x: u32,
            h: union(enum) { s: runtime.DOMString, f: *anyopaque },
        } = null,
    };
    try std.testing.expect(retains(Nested));
}

test "callback interfaces are inert: the value is its own handle, the context is not kept" {
    // conv.fromV8Value makes a callback interface value of the argument's
    // own Global (runtime.BorrowedCallbackInterface); the caller's context is
    // never stored. (Until lane bind1 it made a CallbackWrapper holding a
    // context handle of its own.)
    try std.testing.expect(!retains(runtime.BorrowedCallbackInterface));
    try std.testing.expect(!retains(?runtime.BorrowedCallbackInterface));
    const WithCallback = struct {
        pub const webidl_dictionary = true;
        a: ?bool = null,
        cb: ?runtime.BorrowedCallbackInterface = null,
    };
    try std.testing.expect(!retains(WithCallback));
}

test "callback functions are inert: the conversion keeps the value handle, not the context" {
    // A callback function converts to its own argument handle; the context
    // is not read. An impl that needs a context for a callback takes it from
    // the instance, never from the binding's handle.
    const Callback = runtime.BorrowedCallbackFunction;
    try std.testing.expect(!retains(Callback));
    try std.testing.expect(!retains(?Callback));
    const UnderlyingSourceShaped = struct {
        pub const webidl_dictionary = true;
        type: ?runtime.DOMString = null,
        start: ?Callback = null,
    };
    try std.testing.expect(!retains(UnderlyingSourceShaped));
    const TimerHandlerLike = union(enum) { domstring: runtime.DOMString, function: Callback, trusted_script: *runtime.Instance };
    try std.testing.expect(!retains(TimerHandlerLike));
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

    // And any pointer it does not know - to anything but an Instance, a
    // callback wrapper or a callback function.
    try std.testing.expect(retains(*anyopaque));
    try std.testing.expect(retains(*u32));
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
    // `.handle = .{ .ptr = value }`. Releasing the
    // argument handle would free what it points at.
    try std.testing.expect(!copied(runtime.JSValue));
    try std.testing.expect(!copied(?runtime.JSValue));
}

test "argHandleIsCopied - a callback value IS its argument's handle, never copied" {
    // The value is the Global v8_FunctionCallbackInfo_GetArgument made, freed
    // with the value (freeConvertedArg). A struct with one JSValue field, so
    // the dictionary rule would call it copied and release the handle at
    // conversion: it is named first.
    try std.testing.expect(!copied(runtime.BorrowedCallbackFunction));
    try std.testing.expect(!copied(?runtime.BorrowedCallbackFunction));
    try std.testing.expect(!copied(runtime.BorrowedCallbackInterface));
    // An unknown pointer keeps the conservative answer.
    try std.testing.expect(!copied(*const fn () callconv(.c) void));
}

test "argHandleIsCopied - an Instance pointer is copied: it comes from the wrapper, not the handle" {
    // conv.fromV8Value reads the wrapper's internal field and returns the
    // Instance; the argument's own Global is not referred to afterwards. Kept,
    // it was a handle to a page object per call - fetch(request), new
    // Response(body, init) - each pinning the page.
    try std.testing.expect(copied(*runtime.Instance));
    try std.testing.expect(copied(?*runtime.Instance));
}

test "argHandleIsCopied - handler unions are NOT copied" {
    const TimerHandlerShaped = union(enum) {
        domstring: runtime.DOMString,
        function: *anyopaque,
    };
    try std.testing.expect(!copied(TimerHandlerShaped));
}

test "argHandleIsCopied - a union of copied arms is copied" {
    const RequestInfoShaped = union(enum) { request: *runtime.Instance, url: runtime.DOMString };
    try std.testing.expect(copied(RequestInfoShaped));
}

test "argHandleIsCopied - a dictionary reads each member through its own handle" {
    // Dictionary conversion reads every member with Get, so a member - even a
    // JSValue, which keeps what it points at - aliases the member's handle,
    // never the dictionary's. Members are still held to the rule so that an
    // unknown pointer keeps the conservative answer.
    const RequestInitShaped = struct {
        pub const webidl_dictionary = true;
        method: ?[]const u8 = null,
        signal: ?*runtime.Instance = null,
        window: ?runtime.JSValue = null,
        keepalive: ?bool = null,
        issuers: ?[]const runtime.DOMString = null,
        reporting: ?struct {
            pub const webidl_dictionary = true;
            a: bool,
            b: bool,
        } = null,
    };
    try std.testing.expect(copied(RequestInitShaped));
    const WithUnknownPointer = struct {
        pub const webidl_dictionary = true;
        a: ?bool = null,
        b: ?*anyopaque = null,
    };
    try std.testing.expect(!copied(WithUnknownPointer));
}

test "argHandleIsCopied - a sequence of copied elements is copied" {
    try std.testing.expect(copied([]const runtime.DOMString));
    try std.testing.expect(copied([]const []const u8));
}

test "argHandleIsCopied - BodyInit is copied: its converter only ever makes strings" {
    // convertBodyInit returns an owned or empty USVString on every path; the
    // BufferSource arm, which would be a view, is never produced.
    try std.testing.expect(copied(v8.interface_mod.copied_arg_types.BodyInit));
}

test "argHandleIsCopied - AllowSharedBufferSource is a reference to its object, never copied" {
    // conv.convertAllowSharedBufferSource keeps the argument's handle as the
    // IDL value's reference to its object (WebIDL 3.2.26), released with the
    // value (bufferHandleIsKeptInValue). It was "copied" while the conversion
    // was a slice over the backing store - and a later argument's getter that
    // transferred the buffer left TextDecoder.decode reading the freed store.
    const webidl = @import("webidl");
    try std.testing.expect(!copied(webidl.AllowSharedBufferSource));
    try std.testing.expect(!copied(?webidl.AllowSharedBufferSource));
    try std.testing.expect(!copied(webidl.Opt(webidl.AllowSharedBufferSource)));
    try std.testing.expect(!copied(webidl.BufferSource));
    try std.testing.expect(!copied(webidl.ArrayBufferView));
    // All three keep the handle in the value, nullable and optional forms too,
    // so the binding releases it exactly once: with the value.
    const kept = v8.interface_mod.bufferHandleIsKeptInValue;
    try std.testing.expect(kept(webidl.AllowSharedBufferSource));
    try std.testing.expect(kept(?webidl.AllowSharedBufferSource));
    try std.testing.expect(kept(webidl.Opt(webidl.AllowSharedBufferSource)));
    try std.testing.expect(v8.interface_mod.argumentHandleIsKeptInValue(webidl.Opt(webidl.AllowSharedBufferSource)));
}

test "argHandleIsCopied - wrappers follow their payload" {
    try std.testing.expect(copied(?runtime.DOMString));
    try std.testing.expect(copied(?i32));
    try std.testing.expect(!copied(?runtime.JSValue));
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

// ---------------------------------------------------------------------------

const resultOwned = v8.interface_mod.getterValueIsOwned;

test "getterValueIsOwned - strings, numbers, booleans and enums are made fresh, so released" {
    // conv.toV8Value makes a new Global for each (newStringFromWtf8,
    // v8_Number_New, v8_Boolean_New), and setReturnValue only reads it into a
    // Local: kept, a named getter's string was one Global per `el.dataset.x`.
    try std.testing.expect(resultOwned(runtime.DOMString));
    try std.testing.expect(resultOwned(?runtime.DOMString));
    try std.testing.expect(resultOwned(runtime.USVString));
    try std.testing.expect(resultOwned(u32));
    try std.testing.expect(resultOwned(f64));
    try std.testing.expect(resultOwned(bool));
    const Direction = enum { forward, backward };
    try std.testing.expect(resultOwned(Direction));
}

test "getterValueIsOwned - an Instance converts to the wrapper cache's handle: kept" {
    // Releasing it frees the cache's entry, and the next read of the same
    // object hands out a freed handle.
    try std.testing.expect(!resultOwned(*runtime.Instance));
    try std.testing.expect(!resultOwned(?*runtime.Instance));
}

test "getterValueIsOwned - a JSValue may be the impl's handle or a wrapper: kept" {
    // The accessor getter decides a JSValue by its arm; the predicate cannot.
    try std.testing.expect(!resultOwned(runtime.JSValue));
    try std.testing.expect(!resultOwned(?runtime.JSValue));
}

test "getterValueIsOwned - an unknown type defaults to KEPT" {
    // TRUE releases the handle, so the fallthrough must be FALSE: a type
    // nobody listed keeps its handle and the old leak, which costs memory and
    // never correctness.
    const SomethingNew = struct { a: u32, b: *anyopaque };
    try std.testing.expect(!resultOwned(SomethingNew));
    try std.testing.expect(!resultOwned([]const runtime.DOMString));
    const Shape = union(enum) { node: *runtime.Instance, text: runtime.DOMString };
    try std.testing.expect(!resultOwned(Shape));
}

// ---------------------------------------------------------------------------
// `anyHandleIsKeptOnlyAsHandle` / `anyConversionKeepsHandle` - may the
// argument handle of an `any` go once it is converted? Only the value can
// say: a primitive is copied out, an object stays a `.handle` over the very
// Global the argument was. TRUE from the shape predicate lets the binding ask
// the value, so its fallthrough must be FALSE.

const anyShape = v8.interface_mod.anyHandleIsKeptOnlyAsHandle;
const anyKeeps = v8.interface_mod.anyConversionKeepsHandle;

test "anyHandleIsKeptOnlyAsHandle - an any, nullable or optional, is decided by its value" {
    try std.testing.expect(anyShape(runtime.JSValue));
    try std.testing.expect(anyShape(?runtime.JSValue));
    const webidl = @import("webidl");
    try std.testing.expect(anyShape(webidl.Opt(runtime.JSValue)));
    try std.testing.expect(anyShape(webidl.Opt(?runtime.JSValue)));
}

test "anyHandleIsKeptOnlyAsHandle - an unknown type, or one that merely contains an any, defaults to NO" {
    const SomethingNew = struct { a: u32, b: *anyopaque };
    try std.testing.expect(!anyShape(SomethingNew));
    try std.testing.expect(!anyShape([]const runtime.JSValue));
    const Shape = union(enum) { value: runtime.JSValue, text: runtime.DOMString };
    try std.testing.expect(!anyShape(Shape));
    const Dictionary = struct {
        pub const webidl_dictionary = true;
        detail: ?runtime.JSValue = null,
    };
    try std.testing.expect(!anyShape(Dictionary));
    try std.testing.expect(!anyShape(runtime.DOMString));
}

test "anyConversionKeepsHandle - only a .handle keeps the argument's handle" {
    var dummy: u64 = 0;
    const handle_value: runtime.JSValue = .{ .handle = .{ .ptr = @ptrCast(&dummy) } };
    try std.testing.expect(anyKeeps(runtime.JSValue, handle_value));
    try std.testing.expect(!anyKeeps(runtime.JSValue, runtime.JSValue.jsNull));
    try std.testing.expect(!anyKeeps(runtime.JSValue, .{ .number = 1 }));
    try std.testing.expect(!anyKeeps(runtime.JSValue, .{ .string = .{ .data = "x", .owned = false } }));
    try std.testing.expect(anyKeeps(?runtime.JSValue, handle_value));
    try std.testing.expect(!anyKeeps(?runtime.JSValue, null));
    const webidl = @import("webidl");
    try std.testing.expect(anyKeeps(webidl.Opt(runtime.JSValue), webidl.Opt(runtime.JSValue).passed(handle_value)));
    try std.testing.expect(!anyKeeps(webidl.Opt(runtime.JSValue), webidl.Opt(runtime.JSValue).notPassed()));
    try std.testing.expect(!anyKeeps(webidl.Opt(runtime.JSValue), webidl.Opt(runtime.JSValue).passed(runtime.JSValue.jsUndefined)));
}

// ---------------------------------------------------------------------------
// `setterValueLeavesHandle` - may an attribute setter release its value's
// handle once the value is converted, for a type whose conversion does not
// always copy? TRUE releases it, so every answer the value cannot prove must
// be FALSE.

const leaves = v8.interface_mod.setterValueLeavesHandle;

test "setterValueLeavesHandle - a primitive or null any refers to nothing" {
    try std.testing.expect(leaves(runtime.JSValue, runtime.JSValue.jsNull));
    try std.testing.expect(leaves(runtime.JSValue, .{ .boolean = false }));
    try std.testing.expect(leaves(runtime.JSValue, .{ .string = .{ .data = "x", .owned = false } }));
    try std.testing.expect(leaves(?runtime.JSValue, null));
    try std.testing.expect(leaves(?runtime.JSValue, .{ .number = 1 }));
}

test "setterValueLeavesHandle - an object any is the handle itself: kept" {
    var dummy: u64 = 0;
    const handle_value: runtime.JSValue = .{ .handle = .{ .ptr = @ptrCast(&dummy) } };
    try std.testing.expect(!leaves(runtime.JSValue, handle_value));
    try std.testing.expect(!leaves(?runtime.JSValue, handle_value));
}

test "setterValueLeavesHandle - a null EventHandler made nothing; a function is kept" {
    // typedefs.EventHandler, reconstructed: `?EventHandlerNonNull`, a
    // runtime.BorrowedCallbackFunction (the typedefs module is not this
    // test's import).
    const EventHandler = ?runtime.BorrowedCallbackFunction;
    try std.testing.expect(leaves(EventHandler, null));
    var dummy: u64 align(16) = 0;
    const function: EventHandler = .{ .function = .{ .handle = .{ .ptr = &dummy } } };
    try std.testing.expect(!leaves(EventHandler, function));
}

test "setterValueLeavesHandle - a copied type is released elsewhere, and answers no" {
    // argHandleIsCopied's types are released whatever their value
    // (makeSetterCallback's value_is_copied); this predicate is never theirs.
    try std.testing.expect(!leaves(runtime.DOMString, runtime.DOMString.empty));
    try std.testing.expect(!leaves(?i32, null));
}

test "setterValueLeavesHandle - an unknown type defaults to KEPT" {
    // The default must be FALSE: a type nobody listed keeps its handle and the
    // old leak, which costs memory and never correctness.
    var dummy: u64 = 0;
    const SomethingNew = struct { a: u32, b: *anyopaque };
    try std.testing.expect(!leaves(SomethingNew, .{ .a = 0, .b = @ptrCast(&dummy) }));
    const Shape = union(enum) { value: runtime.JSValue, text: runtime.DOMString };
    try std.testing.expect(!leaves(Shape, .{ .text = runtime.DOMString.empty }));
    const Dictionary = struct {
        pub const webidl_dictionary = true;
        detail: ?runtime.JSValue = null,
    };
    try std.testing.expect(!leaves(Dictionary, .{}));
}

// ---------------------------------------------------------------------------
// `setterValueIsBorrowed` - does an attribute setter whose value is of this
// type borrow it for the call, so that the binding releases the value's
// handle once the setter has returned (or failed)? TRUE releases a handle the
// value may point at, so a type whose setters were not read for keepers -
// every type not named - must answer FALSE (lane setterleak).

const borrowed = v8.interface_mod.setterValueIsBorrowed;

test "setterValueIsBorrowed - an any, nullable or optional, is borrowed for the call" {
    // Every setter of these types was read for a keeper (the predicate's doc
    // comment lists them); one that keeps its value takes its own hold
    // (engine.retainValue), as ShadowRoot.adoptedStyleSheets does.
    try std.testing.expect(borrowed(runtime.JSValue));
    try std.testing.expect(borrowed(?runtime.JSValue));
    const webidl = @import("webidl");
    try std.testing.expect(borrowed(webidl.Opt(runtime.JSValue)));
}

test "setterValueIsBorrowed - a union whose only non-copied arm is `object` is borrowed" {
    const ObjectOrString = union(enum) { object: runtime.JSValue, text: runtime.DOMString };
    try std.testing.expect(borrowed(ObjectOrString));
    try std.testing.expect(borrowed(?ObjectOrString));
}

test "setterValueIsBorrowed - a callback function is borrowed; the map keeps a hold of its own" {
    // typedefs.EventHandler, reconstructed: `?EventHandlerNonNull`. Its
    // conversion's value IS the argument's Global, BORROWED for the setter
    // since lane leaks7: the event handler map keeps a hold of its own
    // (`keep` moves the function out), and the binding releases its Global
    // once the setter has returned.
    const EventHandler = ?runtime.BorrowedCallbackFunction;
    try std.testing.expect(borrowed(EventHandler));
    try std.testing.expect(borrowed(runtime.BorrowedCallbackFunction));
    try std.testing.expect(borrowed(runtime.BorrowedCallbackInterface));
    // Not named, so handed over: an unknown pointer, and a union arm nobody
    // typed.
    try std.testing.expect(!borrowed(*const fn () callconv(.c) void));
    const TimerHandlerShaped = union(enum) { domstring: runtime.DOMString, function: *anyopaque };
    try std.testing.expect(!borrowed(TimerHandlerShaped));
}

test "setterValueIsBorrowed - a buffer source is a reference held in the value, not borrowed here" {
    const webidl = @import("webidl");
    try std.testing.expect(!borrowed(webidl.BufferSource));
    try std.testing.expect(!borrowed(webidl.ArrayBufferView));
}

test "setterValueIsBorrowed - a copied type is released whatever the value, and answers no" {
    // makeSetterCallback's value_is_copied releases these; answering yes too
    // must never be what releases them.
    try std.testing.expect(!borrowed(runtime.DOMString));
    try std.testing.expect(!borrowed(?runtime.DOMString));
    try std.testing.expect(!borrowed(bool));
    try std.testing.expect(!borrowed(*runtime.Instance));
    try std.testing.expect(!borrowed(?*runtime.Instance));
}

test "setterValueIsBorrowed - an unknown type, or one that merely contains an any, defaults to NOT borrowed" {
    // The default the design rests on: TRUE releases the handle, so the
    // fallthrough must be FALSE - an unread type keeps its handle and the old
    // leak, which costs memory and never correctness.
    const SomethingNew = struct { a: u32, b: *anyopaque };
    try std.testing.expect(!borrowed(SomethingNew));
    try std.testing.expect(!borrowed(*anyopaque));
    try std.testing.expect(!borrowed([]const runtime.JSValue));
    const Dictionary = struct {
        pub const webidl_dictionary = true;
        detail: ?runtime.JSValue = null,
    };
    try std.testing.expect(!borrowed(Dictionary));
    // A JSValue arm not named `object` (CryptoKeyID's `bigint`) is not a
    // reference to the argument's object.
    const BigIntShaped = union(enum) { bigint: runtime.JSValue, number: f64 };
    try std.testing.expect(!borrowed(BigIntShaped));
}

// ============================================================================
// unionValueIsOwned: is the value an operation's union result converts to a
// Global made for the call, which the binding releases once it is set as the
// result? TRUE releases it, so every member the rule cannot prove fresh must
// answer FALSE - a wrapper released under the wrapper cache is a
// use-after-free; a fresh value kept is a leak.

const unionOwned = v8.conversions.unionValueIsOwned;

test "unionValueIsOwned - a string, number, boolean or sequence member is made for the call" {
    // FormDataEntryValue, reconstructed: (File or USVString).
    const Entry = union(enum) { file: *runtime.Instance, usvstring: []const u8 };
    try std.testing.expect(unionOwned(Entry, .{ .usvstring = "b" }));
    const Numberish = union(enum) { double: f64, flag: bool, text: runtime.DOMString };
    try std.testing.expect(unionOwned(Numberish, .{ .double = 1 }));
    try std.testing.expect(unionOwned(Numberish, .{ .flag = true }));
    try std.testing.expect(unionOwned(Numberish, .{ .text = runtime.DOMString.empty }));
    const List = union(enum) { items: []const u32, one: u32 };
    try std.testing.expect(unionOwned(List, .{ .items = &.{} }));
}

test "unionValueIsOwned - an interface member is its wrapper: kept" {
    var dummy: u64 = 0;
    const Entry = union(enum) { file: *runtime.Instance, usvstring: []const u8 };
    try std.testing.expect(!unionOwned(Entry, .{ .file = @ptrCast(@alignCast(&dummy)) }));
}

test "unionValueIsOwned - a nested union answers by its own active member" {
    var dummy: u64 = 0;
    const Inner = union(enum) { text: []const u8, node: *runtime.Instance };
    const Outer = union(enum) { inner: Inner, flag: bool };
    try std.testing.expect(unionOwned(Outer, .{ .inner = .{ .text = "x" } }));
    try std.testing.expect(!unionOwned(Outer, .{ .inner = .{ .node = @ptrCast(@alignCast(&dummy)) } }));
}

test "unionValueIsOwned - an any or object member's handle or wrapper, or an unknown member, is KEPT" {
    var dummy: u64 = 0;
    const Shape = union(enum) { value: runtime.JSValue, opaque_member: *anyopaque };
    try std.testing.expect(!unionOwned(Shape, .{ .value = .{ .handle = .{ .ptr = @ptrCast(&dummy) } } }));
    try std.testing.expect(!unionOwned(Shape, .{ .value = .{ .instance = @ptrCast(&dummy) } }));
    try std.testing.expect(!unionOwned(Shape, .{ .opaque_member = @ptrCast(&dummy) }));
}

test "unionValueIsOwned - an any or object member answers by its arm: a primitive is made for the call" {
    // The member is converted as the runtime.JSValue it is, and
    // jsValueConversionIsFresh is that conversion's allowlist: toV8Null,
    // newStringFromWtf8 and the rest each make a Global
    // (record_value_ownership_test.zig). Kept by type, it was a leak, never a
    // safety boundary - the handle and instance arms above are that.
    const Shape = union(enum) { value: runtime.JSValue, opaque_member: *anyopaque };
    try std.testing.expect(unionOwned(Shape, .{ .value = runtime.JSValue.jsNull }));
    try std.testing.expect(unionOwned(Shape, .{ .value = runtime.JSValue.fromStringRef("x") }));
}

// ===========================================================================
// A dictionary is a struct that SAYS so (lane bind1)
// ===========================================================================
//
// "Any struct without Meta is a dictionary" misfired twice: argHandleIsCopied
// called a borrowed callback (a struct holding its argument's handle) a copied
// dictionary and would have released the handle under the impl, and the union
// conversion took it for TimerHandler's dictionary arm. Dictionary detection
// is positive now: codegen writes `pub const webidl_dictionary = true` into
// every generated dictionary, and every rule tests that marker.

test "a plain struct holding a JSValue is not a dictionary: no rule takes it for one" {
    const isDictionary = v8.interface_mod.isDictionaryType;
    const Plain = struct { value: runtime.JSValue };
    const Marked = struct {
        pub const webidl_dictionary = true;
        value: ?runtime.JSValue = null,
    };
    try std.testing.expect(!isDictionary(Plain));
    try std.testing.expect(isDictionary(Marked));
    // Its handle is never released at conversion as a copied dictionary's.
    try std.testing.expect(!copied(Plain));
    try std.testing.expect(copied(Marked));
    // Never walked member by member: an unknown type keeps the context.
    try std.testing.expect(retains(Plain));
    try std.testing.expect(!retains(Marked));
    // Never freed member by member.
    try std.testing.expect(!v8.interface_mod.needsArgCleanup(Plain));
    try std.testing.expect(v8.interface_mod.needsArgCleanup(Marked));
    // The callback values are structs and no dictionaries; every generated
    // dictionary says it is one.
    try std.testing.expect(!isDictionary(runtime.BorrowedCallbackFunction));
    try std.testing.expect(!isDictionary(runtime.BorrowedCallbackInterface));
    try std.testing.expect(isDictionary(v8.conversions.generated_dictionaries.QueuingStrategy));
    try std.testing.expect(isDictionary(v8.conversions.generated_dictionaries.EventInit));
}
