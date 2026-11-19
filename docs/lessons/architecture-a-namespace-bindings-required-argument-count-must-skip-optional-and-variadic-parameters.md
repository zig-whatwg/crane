# Architecture: A namespace binding's required-argument count must skip optional and variadic parameters

**Date**: 2026-11-18
**Lesson**: The V8 namespace binding counts its required arguments from the impl's Zig signature; a `webidl.Opt(T)` parameter and every variadic slice (`[]const runtime.JSValue` too) take no required argument, or the operation throws "Not enough arguments" for a call the IDL allows.

**Why**: Interface operations get their argument counts from codegen; namespace operations (console, CSS, WebAssembly-adjacent helpers) are bound by `src/runtime/engines/v8/namespace.zig`, which derives "required" from the parameter types. It skipped the realm and two of the three variadic slice types, and nothing else - so an optional label counted as required.

**What Happened**: console.count(), countReset(), time() and timeEnd() with no argument, and console.timeLog() with none, threw "TypeError: Not enough arguments: expected 1" in every Crane page. No WPT file noticed until lane dom1 gave the runner WebDriver BiDi's log.entryAdded: console/console-count-logging.html, -countReset-logging and -timing-logging then reached their console calls and failed there (b7aa8cf9b4d for Opt, e32ca54ef97 for the JSValue slice, which the first fix missed).

**Fix**: In the comptime `required_params` count, `continue` for `interface.isOptionalWrapper(ParamType)` and for each variadic slice type (`[]const *const anyopaque`, `[]const runtime.ConsoleValue`, `[]const runtime.JSValue`). A missing optional argument then reads as undefined, which the Opt conversion makes "not passed".

**Takeaway**: **When a binding derives arity from types, every parameter kind that can be absent - Opt, each variadic slice - must be excluded; check the list against every slice type the converters handle, not the ones the first caller used.**
