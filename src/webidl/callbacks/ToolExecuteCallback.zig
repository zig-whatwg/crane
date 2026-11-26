//! WebIDL callback: ToolExecuteCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const engine = @import("engine");
const dictionaries = @import("dictionaries");

/// callback ToolExecuteCallback = Promise<any> (object inputObject, ToolExecuteCallbackOptions options)
pub const ToolExecuteCallback = runtime.BorrowedCallbackFunction;

pub const is_promise = true;

pub const Args = struct {
    inputObject: runtime.JSValue,
    options: dictionaries.ToolExecuteCallbackOptions,
};

/// WebIDL 3.12 "invoke a callback function" for a Promise-returning callback (WebIDL 3.2.24).
pub fn invoke(
    realm: engine.Context,
    callback: *const engine.CallbackFunction,
    this_arg: engine.CallbackThis,
    args: Args,
) engine.Error!engine.Owned {
    return engine.invokeCallbackFunctionToPromise(.webidl, realm, callback, this_arg, args);
}

/// WebIDL 3.12 "invoke a callback function" using ECMAScript PromiseResolve (0 extra ticks for same-realm %Promise%).
pub fn invokePromiseResolve(
    realm: engine.Context,
    callback: *const engine.CallbackFunction,
    this_arg: engine.CallbackThis,
    args: Args,
) engine.Error!engine.Owned {
    return engine.invokeCallbackFunctionToPromise(.promise_resolve, realm, callback, this_arg, args);
}
