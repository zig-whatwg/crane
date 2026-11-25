//! WebIDL callback: GenerateAssertionCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const engine = @import("engine");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");

/// callback GenerateAssertionCallback = Promise<RTCIdentityAssertionResult> (DOMString contents, DOMString origin, optional RTCIdentityProviderOptions options)
pub const GenerateAssertionCallback = runtime.BorrowedCallbackFunction;

pub const is_promise = true;

pub const Args = struct {
    contents: runtime.DOMString,
    origin: runtime.DOMString,
    options: webidl.Opt(dictionaries.RTCIdentityProviderOptions) = .notPassed(),
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
