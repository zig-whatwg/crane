//! engine.completionOf - ECMAScript Completion(...) - as V8 implements it:
//! the steps run under a TryCatch (v8_RunCatching), and what they leave
//! pending comes back as the thrown value instead of reaching the next script
//! to run.

const engine = @import("engine");

const ffi = @import("ffi.zig");
const support = @import("protocol_support.zig");

const Context = engine.Context;
const Owned = engine.Owned;
const Error = engine.Error;

/// ECMAScript Completion(steps): null for a normal completion; for a throw
/// completion, the thrown value, OWNED, with nothing left pending.
///
/// The steps' errors follow the protocol's meaning (recipes, 0.6):
/// ExceptionPending is the thrown value, caught here; TypeError and
/// DataCloneError are "the spec throws one here, nothing is thrown yet", so
/// they are a throw completion of a new TypeError / "DataCloneError"
/// DOMException of the realm; anything else (OutOfMemory, OperationFailed,
/// NotSupported) is the engine failing, not script completing, and
/// propagates. A thrown value the TryCatch caught wins over whatever the steps
/// returned: it is what script saw.
pub fn completionOf(realm: Context, steps: *const fn (data: ?*anyopaque) Error!void, data: ?*anyopaque) Error!?Owned {
    const entered = try support.enter(realm);
    defer entered.leave();

    const Body = struct {
        steps: *const fn (data: ?*anyopaque) Error!void,
        data: ?*anyopaque,
        result: Error!void = {},

        pub fn run(self: *@This()) void {
            self.result = self.steps(self.data);
        }
    };
    var body = Body{ .steps = steps, .data = data };
    var thrown: ?*ffi.Value = null;
    if (support.catching(entered.isolate, &body, &thrown)) {
        // A throw with nothing to hand back is a terminating agent.
        const value = thrown orelse return error.ExceptionPending;
        return support.owned(value);
    }
    body.result catch |err| switch (err) {
        error.TypeError => return support.owned(try support.newTypeError(entered.isolate, entered.context(), "TypeError")),
        error.DataCloneError => return try engine.createDOMException(realm, "DataCloneError", "The value could not be cloned."),
        // Pending, but nothing was caught: the agent is terminating, and
        // v8_RunCatching left the termination in flight.
        else => return err,
    };
    return null;
}
