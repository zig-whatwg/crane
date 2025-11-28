//! Implementation stub for WebIDL namespace: WebAssembly
//!
//! This file is AUTO-GENERATED. Do not edit manually.
//! Implement the functions below to provide actual functionality.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub fn call_compile(ctx: runtime.Context, bytes: *const anyopaque, options: webidl.Opt(*const anyopaque)) anyerror!*const anyopaque {
    _ = ctx;
    _ = bytes;
    _ = options;
    return error.NotImplemented;
}

pub fn call_instantiate_BufferSource_object_WebAssemblyCompileOptions(ctx: runtime.Context, bytes: *const anyopaque, importObject: webidl.Opt(*const anyopaque), options: webidl.Opt(*const anyopaque)) anyerror!*const anyopaque {
    _ = ctx;
    _ = bytes;
    _ = importObject;
    _ = options;
    return error.NotImplemented;
}

pub fn call_instantiate_Module_object(ctx: runtime.Context, moduleObject: *const anyopaque, importObject: webidl.Opt(*const anyopaque)) anyerror!*const anyopaque {
    _ = ctx;
    _ = moduleObject;
    _ = importObject;
    return error.NotImplemented;
}

pub fn call_validate(ctx: runtime.Context, bytes: *const anyopaque, options: webidl.Opt(*const anyopaque)) anyerror!bool {
    _ = ctx;
    _ = bytes;
    _ = options;
    return error.NotImplemented;
}
