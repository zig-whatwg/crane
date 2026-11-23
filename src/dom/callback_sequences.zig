//! The realm a callback's sequence (or dictionary) argument is made in, for
//! the hosts that build one before invoking the callback: the observers'
//! entries and records (IntersectionObserver, ResizeObserver,
//! MutationObserver), the ReportingObserver's reports and the
//! PerformanceObserver's callback options (lane fw2's sweep of every
//! callback invocation, 2026-11-22: the others hand a callback platform
//! objects, which the engine wraps in the callback's world itself, the
//! caller's own values, or primitives).
//!
//! WebIDL "invoke a callback function" step 5 takes F's associated realm,
//! step 8 prepares to run script there, and step 10 converts the IDL
//! arguments to JavaScript values - so a sequence<T> argument becomes "a new
//! Array object created as if by the expression []" (3.2.27) in F's realm,
//! not in the realm of the object that invokes it, and each platform object
//! in it is its wrapper as seen from there. Blink does the same: a generated
//! callback function's Invoke binds `script_state` to
//! CallbackRelevantScriptState() and converts each argument with
//! make_blink_to_v8_value in it (third_party/blink/renderer/bindings/scripts/
//! bind_gen/callback_function.py; BSD-3 - read, not copied), so in an
//! isolated world the Array and each element are the world's.
//!
//! Crane's engine protocol takes a callback's arguments as JavaScript values
//! the host has already made (engine.invokeCallbackFunction), and the
//! generated callback types (src/webidl/callbacks/) are only signatures, so
//! the host makes the sequence - in the realm this module names. An Array
//! made in the observer's realm and handed to a callback of an isolated world
//! crossed the world boundary as any ordinary object does
//! (protocol_worlds.acrossWorlds: a structured clone), and an Array of
//! platform objects cannot be cloned: the callback was handed null (lane
//! fw2, from Puppeteer's ElementHandle.isIntersectingViewport in Vue's e2e
//! suite: tests/html/fw2_world_callback_sequences_test.zig).
//!
//! A shared helper, so not in src/webidl/impls/ (AGENTS.md, "The impls
//! boundary", rule 3).

const engine = @import("engine");
const runtime = @import("runtime");

/// F's associated realm for `callback` (ECMAScript GetFunctionRealm), where
/// its sequence and dictionary arguments are made: `realm`, the invoking
/// object's, when the engine cannot name a function's realm exactly or the
/// function's realm is not one it hosts.
pub fn argumentRealm(realm: runtime.Context, callback: *const engine.CallbackFunction) runtime.Context {
    if (comptime engine.capabilities.exact_function_realm == .unsupported) return realm;
    return engine.functionRealm(callback.function.value) orelse realm;
}
