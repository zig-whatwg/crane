//! WebIDL callback: LockGrantedCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const engine = @import("engine");

/// callback LockGrantedCallback = Promise<any> (Lock? lock)
pub const LockGrantedCallback = runtime.BorrowedCallbackFunction;

pub const is_promise = true;

pub const Args = struct {
    lock: ?*runtime.Instance,
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
