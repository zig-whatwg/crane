//! What `event_utils`' synthesised null context is allowed to touch.
//!
//! `fireEvent`, `fireErrorEvent` and `reportException` all take an optional
//! `runtime.Context`, and when it is null they build one ON THE STACK:
//!
//!     var ctx_data: runtime.ContextData = undefined;
//!     const actual_ctx = if (ctx) |c| c else blk: {
//!         ctx_data = try runtime.createNullContext(allocator);
//!         break :blk &ctx_data;
//!     };
//!     defer if (ctx == null) ctx_data.deinit();
//!
//! `&ctx_data` is then handed to `Event.call_constructor`, which stores it in
//! `instance.ctx` - so the event holds a pointer into a stack frame that ends
//! the moment the call returns. `ContextEntry` is heap-allocated precisely
//! because `instance.ctx` points into it (see `ManagerState.contexts`), and
//! `cfa5c0b52` had to stop freeing those entries under live Instances for the
//! same reason.
//!
//! Three callers reach it with a null context, all in `script_execution.zig`:
//! `fireLoadEvent`, `fireErrorEvent` and `reportScriptError`. They run on real
//! script elements during a real page load, not only in tests.
//!
//! It is safe TODAY, and for one reason: `event_utils.dispatchEvent` is a stub
//! that sets the dispatch flags and reads the canceled flag, and invokes no
//! listeners at all. The event is therefore never handed to script, never
//! wrapped by V8 and never entered into a wrapper cache, so `instance.ctx` is
//! only ever read while the frame that owns the slot is still live. The two
//! defers are ordered correctly on top of that - `Event.deinit` is registered
//! second, so it runs before `ctx_data.deinit`.
//!
//! What this file pins is the half that is checkable from outside: the call
//! allocates and releases everything within the frame, so a change that starts
//! RETAINING the event shows up here as a leak rather than as a
//! `0xAAAA_AAAA_AAAA_AAAA` read somewhere else. 0xAA is both the DebugAllocator
//! poison byte and Zig's `undefined` fill, and it is non-null and 2 mod 4 - so a
//! stale `instance.ctx` sails past `orelse` and dies in an `@alignCast`, which
//! is how this family of bug always presents.
//!
//! The comment in `src/html/event_utils.zig` names the condition. If real
//! dispatch lands there, the stack context has to go with it.

const std = @import("std");
const testing = std.testing;
const html = @import("html");
const runtime = @import("runtime");
const interfaces = html.interfaces;
const event_utils = html.event_utils;

/// A document to fire at, in a context of its own that outlives every call.
const Fixture = struct {
    ctx_data: runtime.ContextData,
    document: *runtime.Instance,

    fn init(allocator: std.mem.Allocator) !*Fixture {
        const self = try allocator.create(Fixture);
        errdefer allocator.destroy(self);
        self.ctx_data = try runtime.ContextData.init(allocator, .{});
        errdefer self.ctx_data.deinit();
        self.document = try interfaces.Document.init(allocator, &self.ctx_data);
        return self;
    }

    fn deinit(self: *Fixture, allocator: std.mem.Allocator) void {
        interfaces.Document.deinit(self.document);
        self.ctx_data.deinit();
        allocator.destroy(self);
    }
};

test "fireSimpleEvent with a null context releases everything inside the call" {
    const allocator = testing.allocator;

    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();

    const fixture = try Fixture.init(allocator);
    defer fixture.deinit(allocator);

    // The `script_execution.fireLoadEvent` shape, verbatim: null context, real
    // target. `std.testing.allocator` is the assertion - anything the call
    // retains past its own frame is reported at the end of the test.
    try event_utils.fireSimpleEvent(allocator, null, fixture.document, "load");
    try event_utils.fireSimpleEvent(allocator, null, fixture.document, "error");
}

test "fireEvent with a null context returns not-cancelled and keeps nothing" {
    const allocator = testing.allocator;

    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();

    const fixture = try Fixture.init(allocator);
    defer fixture.deinit(allocator);

    // Nothing in the stub dispatch can cancel the event, so "not cancelled" is
    // the only answer available - assert it so that a future real dispatch has
    // to come past this test rather than around it.
    const not_cancelled = try event_utils.fireEvent(
        allocator,
        null,
        fixture.document,
        "cancelable-probe",
        true,
        true,
    );
    try testing.expect(not_cancelled);
}

test "fireEvent with a caller-supplied context never builds the stack one" {
    const allocator = testing.allocator;

    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();

    const fixture = try Fixture.init(allocator);
    defer fixture.deinit(allocator);

    // The `ctx != null` arm leaves `ctx_data` at `undefined` for the whole
    // call and its `deinit` guarded off. That is only correct while nothing
    // reads the slot, so exercise it: a build that dropped the guard would
    // deinitialise 0xAA bytes here.
    const not_cancelled = try event_utils.fireEvent(
        allocator,
        &fixture.ctx_data,
        fixture.document,
        "load",
        false,
        false,
    );
    try testing.expect(not_cancelled);
}

test "reportException with a null context releases everything inside the call" {
    const allocator = testing.allocator;

    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();

    const fixture = try Fixture.init(allocator);
    defer fixture.deinit(allocator);

    // `script_execution.reportScriptError`'s shape. The ErrorEvent path builds
    // its own stack context in `fireErrorEvent`, one frame deeper.
    const not_handled = try event_utils.reportException(
        allocator,
        null,
        fixture.document,
        runtime.JSValue.jsNull,
        "boom",
        "https://example.com/x.js",
        12,
        34,
        false,
        false,
    );
    try testing.expect(not_handled);
}
