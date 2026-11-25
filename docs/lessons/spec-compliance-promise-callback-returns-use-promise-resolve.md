# Spec Compliance: Promise-returning callback functions pass same-realm Promises through via PromiseResolve

**Date**: 2026-11-25
**Lesson**: Chrome and Firefox pass a same-realm `%Promise%` returned from a `Promise<T>`-returning WebIDL callback through unchanged (0 extra microtask ticks), so `invokeCallbackFunctionToPromise` uses `PromiseResolve(%Promise%, V)` rather than wrapping every return in a fresh `NewPromiseCapability`.

**Why**: WebIDL 3.2.24's literal text for converting a value to `Promise<T>` constructs a new promise resolved with `V`, which adds two microtask ticks whenever a callback already returns a same-realm `%Promise%`. Both Blink (`ScriptPromise<T>::FromV8Value` / `IsPromise`) and Gecko (`Promise::Resolve`) return a same-realm `%Promise%` unchanged across every Promise-returning callback API.

**What Happened**: While unifying all 12 Promise-returning callbacks in batch B6 (8 Streams callbacks, 2 Navigation handlers, `ViewTransitionUpdateCallback`, and `LockGrantedCallback`), a live probe against Chrome 157.0.8103.51 and Firefox 159.0.1/161.0 across all 5 APIs showed `delta = 0` microtask ticks and `thenGets = 0` for a same-realm `%Promise%` in both browsers (Firefox reads `.constructor` per `PromiseResolve`; Chrome checks `IsPromise`), while wpt.fyi `cc74d2669f` confirmed Chrome and Firefox pass all 8 `navigation-api/ordering-and-transition/*-intercept-reject.html` variants where Safari 27 fails.

**Fix**: Implemented `engine.invokeCallbackFunctionToPromise` with `support.promiseResolve` (`PromiseResolve(%Promise%, V)`) inside the callback's prepared realm and incumbent scopes: a same-realm `%Promise%` passes through unchanged; non-promises, thenables, subclasses, and cross-realm promises wrap in a new `%Promise%` of the callback's realm; and a synchronous throw (including a throwing `.constructor` getter) yields a rejected promise of the callback's associated realm.

**Takeaway**: **For Promise-returning WebIDL callbacks, follow the 2-of-3 browser majority (Chrome + Firefox) with `PromiseResolve(%Promise%, V)` inside the callback's prepared scopes so same-realm promises add zero extra microtask ticks.**
