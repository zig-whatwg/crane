//! WebIDL callback: LoadDocumentCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const engine = @import("engine");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");

/// callback LoadDocumentCallback = Promise<RemoteDocument> (USVString url, optional LoadDocumentOptions options)
pub const LoadDocumentCallback = runtime.BorrowedCallbackFunction;

pub const is_promise = true;

pub const Args = struct {
    url: runtime.USVString,
    options: webidl.Opt(dictionaries.LoadDocumentOptions) = .notPassed(),
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
