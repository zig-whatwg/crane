//! DOM § 6 "filter", steps 6 and 8, shared by NodeIterator and TreeWalker:
//! call the traverser's NodeFilter and convert what it answers.
//!
//! The filter is a WebIDL callback interface: a function, or an object whose
//! `acceptNode` is looked up when it is called. Either way the call is the
//! engine's "call a user object's operation", which performs that lookup,
//! and what the filter throws is rethrown - step 8.
//! The active flag (steps 1, 5 and 7) stays with each traverser.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");

/// A traverser's filter: the callback interface value kept as a TracedCallback
/// (lane rc9, item 15), traced from its NodeIterator/TreeWalker wrapper so a
/// filter closing over its own traverser collects cleanly.
const Filter = struct {
    callback: engine.TracedCallback,
    allocator: std.mem.Allocator,
};

/// Keep the filter argument the binding converted (BORROWED for the call) as
/// a traverser's traced filter: null for none. Registers `owner` while it has
/// no wrapper yet so full collections before first wrap keep the filter alive.
/// Freed by `release`.
pub fn store(allocator: std.mem.Allocator, owner: *runtime.Instance, given: ?runtime.BorrowedCallbackInterface) error{OutOfMemory}!?*anyopaque {
    const converted = given orelse return null;
    const filter = try allocator.create(Filter);
    filter.* = .{ .callback = converted.keepTraced(), .allocator = allocator };
    engine.noteUnwrappedTracedOwner(owner);
    return filter;
}

/// Trace the stored filter's callback hold from its owner's `traceHeldNodes`.
pub fn trace(tracer: *engine.Tracer, stored: ?*anyopaque) void {
    const filter: *const Filter = @ptrCast(@alignCast(stored orelse return));
    engine.traceHeld(tracer, filter.callback.hold);
}

/// Invoke the filter `stored` keeps with « node » and return its answer as an
/// unsigned short, or `error.ExceptionPending` once the exception it threw
/// has been rethrown.
///
/// The call is made from the current realm - the traversal method's - as
/// script calling the traverser would make it.
pub fn call(stored: *anyopaque, node: *runtime.Instance) Error!u16 {
    const filter: *Filter = @ptrCast(@alignCast(stored));
    if (filter.callback.hold.isEmpty()) return error.InvalidStateError;
    const realm = engine.currentRealm() orelse node.ctx;
    const callback = filter.callback.asInterface();

    // Step 6: "call a user object's operation" acceptNode with « node » and no
    // this value - the operation makes the filter object `this` when it gets
    // acceptNode from it, and converts the return value to `unsigned short`
    // inside the callback's prepared scopes (WebIDL 3.11 step 14). Step 8's
    // "If an exception was thrown, re-throw the exception" is `.rethrow`:
    // what the filter or its return conversion threw comes back as a throw
    // completion, and is thrown on.
    const completion = interfaces.NodeFilter.invoke_acceptNode(realm, &callback, .undefined, node, .rethrow, realm.allocator) catch |err|
        return traverserError(err);
    return switch (completion) {
        .normal => |held| blk: {
            defer held.release(realm.allocator);
            break :blk held.value;
        },
        .throw => |exception| {
            defer exception.release();
            engine.throwValue(realm, exception.value) catch |err| return traverserError(err);
            return error.ExceptionPending;
        },
    };
}

/// What `call` fails with: the traversers' own errors.
pub const Error = error{ ExceptionPending, InvalidStateError, NotImplemented, OutOfMemory };

/// An engine operation's failure as a traverser reports it: a pending
/// exception stays pending; anything else means the engine could not make
/// the call at all.
fn traverserError(err: engine.Error) Error {
    return switch (err) {
        error.ExceptionPending => error.ExceptionPending,
        error.OutOfMemory => error.OutOfMemory,
        else => error.InvalidStateError,
    };
}

/// The filter as script sees it - `nodeIterator.filter`, `treeWalker.filter`:
/// the object createNodeIterator() or createTreeWalker() was given, as the
/// getter's result - a hold of the binding's own, since the traverser keeps
/// its filter. Null for none.
pub fn fromStored(realm: runtime.Context, stored: ?*anyopaque) engine.Error!?runtime.JSValue {
    const filter: *Filter = @ptrCast(@alignCast(stored orelse return null));
    if (filter.callback.hold.isEmpty()) return null;
    return (try engine.retainValue(realm, filter.callback.hold.value())).take();
}

/// Release a stored filter: its callback interface value, then the record.
pub fn release(stored: ?*anyopaque) void {
    const filter: *Filter = @ptrCast(@alignCast(stored orelse return));
    filter.callback.release();
    filter.allocator.destroy(filter);
}
