//! WebIDL callback: LanguageModelToolFunction
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const engine = @import("engine");

/// callback LanguageModelToolFunction = Promise<DOMString> (any... arguments)
pub const LanguageModelToolFunction = runtime.BorrowedCallbackFunction;

pub const is_promise = true;

pub const Args = struct {
    arguments: []const runtime.JSValue = &.{},
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
