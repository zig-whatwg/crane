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
