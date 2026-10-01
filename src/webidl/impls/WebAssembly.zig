//! Implementation stub for WebIDL namespace: WebAssembly
//!
//! Never bound: V8 provides WebAssembly itself (interface_bindings
//! engine_provided_namespaces). These exist because the generated namespace
//! delegates here.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub fn call_compile(ctx: runtime.Context, bytes: runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    _ = ctx;
    _ = bytes;
    _ = options;
    return error.NotImplemented;
}

pub fn call_instantiate(ctx: runtime.Context, bytes: runtime.JSValue, importObject: webidl.Opt(runtime.JSValue), options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    _ = ctx;
    _ = bytes;
    _ = importObject;
    _ = options;
    return error.NotImplemented;
}

pub fn call_instantiate__1(ctx: runtime.Context, moduleObject: runtime.JSValue, importObject: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    _ = ctx;
    _ = moduleObject;
    _ = importObject;
    return error.NotImplemented;
}

pub fn call_validate(ctx: runtime.Context, bytes: runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!bool {
    _ = ctx;
    _ = bytes;
    _ = options;
    return error.NotImplemented;
}

pub fn call_compileStreaming(ctx: runtime.Context, source: runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    _ = ctx;
    _ = source;
    _ = options;
    return error.NotImplemented;
}

pub fn call_instantiateStreaming(ctx: runtime.Context, source: runtime.JSValue, importObject: webidl.Opt(runtime.JSValue), options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    _ = ctx;
    _ = source;
    _ = importObject;
    _ = options;
    return error.NotImplemented;
}
