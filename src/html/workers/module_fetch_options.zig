//! Values needed by a dedicated/shared worker's initial module graph.
//! Copied across worker start; no creating-thread settings object is kept.
const fetch = @import("fetch");
const RequestCredentials = @import("types.zig").RequestCredentials;

pub const ModuleFetchOptions = struct {
    /// HTML "fetch a worklet/module worker script graph" step 1: the
    /// WorkerOptions credentials mode becomes the script fetch options'.
    credentials: RequestCredentials = .same_origin,
    /// The root response's policy, before its container moves to the
    /// worker global. Empty when the response has no Referrer-Policy.
    response_referrer_policy: fetch.internal.ReferrerPolicy = .empty,
    /// The creator's policy is a default for the initial static graph's
    /// requests only. It must not become the module record's policy:
    /// import() falls back to the worker's own settings instead.
    static_referrer_policy: fetch.internal.ReferrerPolicy = .empty,
};
