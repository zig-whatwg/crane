//! `namespaceIsEngineProvided` - does the JavaScript engine define this
//! namespace itself, so that the bindings must leave it alone?
//!
//! The WebAssembly JavaScript Interface (wasm-js-api.idl) is part of the
//! engine, as ECMAScript is: V8 installs `WebAssembly` and its constructors on
//! every context, and Blink binds none of it. Crane generated the namespace
//! from the IDL and registered it over V8's, so every `WebAssembly.*` call
//! reached a stub - `WebAssembly.compile(bytes)` threw "Not enough arguments".
//!
//! The default must stay "ours": a namespace answered true is never bound, so
//! a wrong default would silently delete an API.

const std = @import("std");
const v8 = @import("v8");

const bindings = v8.interface_bindings;

test "WebAssembly is the engine's" {
    try std.testing.expect(comptime bindings.namespaceIsEngineProvided("WebAssembly"));
}

test "every other namespace is ours by default" {
    try std.testing.expect(!comptime bindings.namespaceIsEngineProvided("console"));
    try std.testing.expect(!comptime bindings.namespaceIsEngineProvided("CSS"));
    try std.testing.expect(!comptime bindings.namespaceIsEngineProvided("webassembly"));
    try std.testing.expect(!comptime bindings.namespaceIsEngineProvided("NoSuchNamespace"));
}

// =============================================================================
// A namespace of ours, bound: CSS
// =============================================================================
//
// An overloaded namespace operation is bound ONCE, under its own name, and
// the overload resolution algorithm picks the overload (namespace.zig
// forwardToOverload, the interface binding's resolver and argument view).
// Codegen used to mangle each overload's types into its name, which would
// have put CSS.supports_CSSOMString_CSSOMString on the namespace object.
// A namespace operation's arguments convert with the context's allocator,
// whatever their size, and a string it returns is the binding's to free.

const runtime = @import("runtime");
const ffi = v8.ffi;
const namespace_binding = v8.namespace_mod;
const CSSBinding = v8.V8Namespace(namespace_binding.generated_namespaces.CSS);

/// A live isolate with an entered context and `CSS` on its global, one for
/// the whole file - V8 is never torn down here.
var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;

fn cssContext() !*ffi.Isolate {
    if (isolate_once) |i| return i;
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    CSSBinding.registerGlobal(i, context, "CSS");
    isolate_once = i;
    context_once = context;
    return i;
}

/// Run `source` with the namespace context on std.testing.allocator, and
/// return its completion value as a string (owned by std.testing.allocator;
/// an empty one is static).
/// The runtime context goes at the end, so a test that leaks fails.
fn evalToString(source: []const u8) ![]const u8 {
    const i = try cssContext();
    namespace_binding.context_allocator = std.testing.allocator;
    defer {
        namespace_binding.clearGlobalContext();
        namespace_binding.context_allocator = std.heap.page_allocator;
    }
    const context = context_once.?;
    const code = ffi.v8_String_NewFromUtf8(i, source.ptr, @intCast(source.len)) orelse return error.StringFailed;
    const script = ffi.v8_Script_Compile(context, code) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    const value = ffi.v8_Script_Run(context, script) orelse return error.RunFailed;
    defer ffi.v8_Value_Dispose(value);
    return v8.conversions.fromV8Value([]const u8, std.testing.allocator, i, context, value);
}

fn expectEval(source: []const u8, expected: []const u8) !void {
    const got = try evalToString(source);
    defer if (got.len > 0) std.testing.allocator.free(got);
    try std.testing.expectEqualStrings(expected, got);
}

test "CSS.supports: two arguments reach supports(property, value), one reaches supports(conditionText)" {
    try expectEval(
        \\[CSS.supports('color', 'red'), CSS.supports('color', '10px'),
        \\ CSS.supports('(color: red)'), CSS.supports('color: red'), CSS.supports('(color: 10px)'),
        \\ CSS.supports('not (color: 10px)'), CSS.supports('selector(div > p)')].join()
    , "true,false,true,true,false,true,true");
}

test "CSS.supports with no argument is a TypeError, before any overload runs" {
    try expectEval(
        \\try { CSS.supports(); 'no exception' } catch (e) { e instanceof TypeError ? 'TypeError' : String(e) }
    , "TypeError");
}

test "CSS has one supports, and no own property whose name the IDL does not give it" {
    try expectEval(
        \\typeof CSS.supports + ',' +
        \\Object.getOwnPropertyNames(CSS).filter(n => n.includes('_')).join('|')
    , "function,");
}

test "CSS.escape serializes an identifier" {
    try expectEval(
        \\[CSS.escape('0a'), CSS.escape('-'), CSS.escape('a b'), CSS.escape('\0')].join('|')
    , "\\30 a|\\-|a\\ b|\u{FFFD}");
}

test "64 CSS.escape calls leak nothing: the binding frees the string the impl returns" {
    try expectEval(
        \\let n = 0; for (let i = 0; i < 64; i++) n += CSS.escape('id' + i).length; String(n)
    , "246");
}

test "a 64 KB argument converts: CSS.escape and both CSS.supports overloads" {
    try expectEval(
        \\const s = 'a'.repeat(65536);
        \\[CSS.escape(s).length, CSS.supports('color', s), CSS.supports(' '.repeat(65536) + '(color: red)')].join()
    , "65536,false,true");
}
