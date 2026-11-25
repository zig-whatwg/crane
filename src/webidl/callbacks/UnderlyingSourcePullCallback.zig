//! WebIDL callback: UnderlyingSourcePullCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const engine = @import("engine");
const typedefs = @import("typedefs");

/// callback UnderlyingSourcePullCallback = Promise<undefined> (ReadableStreamController controller)
pub const UnderlyingSourcePullCallback = runtime.BorrowedCallbackFunction;

pub const is_promise = true;

pub const Args = struct {
    controller: typedefs.ReadableStreamController,
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
