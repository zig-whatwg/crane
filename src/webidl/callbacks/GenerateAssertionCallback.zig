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
