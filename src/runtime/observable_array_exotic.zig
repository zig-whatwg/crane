//! ObservableArray Exotic Object - the engine-neutral entry point
//!
//! WebIDL "create an observable array exotic object" (§ 3.10): a Proxy over
//! an Array whose traps keep a backing list. The Proxy and its native traps
//! are engine machinery, so they live in the adapter
//! (src/runtime/engines/v8/observable_array.zig for V8) behind the Engine
//! table's `createObservableArray`; this is how runtime code and impls reach
//! it (AGENTS.md, "The engine boundary").
//!
//! Spec: https://webidl.spec.whatwg.org/#es-observable-array

const Context = @import("context.zig").Context;
const JSValue = @import("js_value.zig").JSValue;
const EngineError = @import("engine_interface.zig").EngineError;

/// A new observable array exotic object in `ctx`'s realm, with an empty
/// backing list.
///
/// ENGINE-OWNED, as `createObservableArray` states: the engine frees the
/// object's state when script can no longer reach it, and whatever is left
/// when the realm's agent is torn down. The caller never releases the handle.
pub fn create(ctx: Context) EngineError!JSValue {
    const engine = ctx.getEngine() orelse return EngineError.NoEngine;
    const create_observable_array = engine.createObservableArray orelse return EngineError.NotSupported;
    return create_observable_array(ctx);
}
