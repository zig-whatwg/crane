//! WebIDL callback: UnderlyingSourceCancelCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const engine = @import("engine");
const webidl = @import("webidl");

/// callback UnderlyingSourceCancelCallback = Promise<undefined> (optional any reason)
pub const UnderlyingSourceCancelCallback = runtime.BorrowedCallbackFunction;

pub const is_promise = true;

pub const Args = struct {
    reason: webidl.Opt(runtime.JSValue) = .notPassed(),
};

/// WebIDL 3.12 "invoke a callback function" for a Promise-returning callback.
pub fn invoke(
    realm: engine.Context,
    callback: *const engine.CallbackFunction,
    this_arg: engine.CallbackThis,
    args: Args,
) engine.Error!engine.Owned {
    return engine.invokeCallbackFunctionToPromise(realm, callback, this_arg, args);
}
