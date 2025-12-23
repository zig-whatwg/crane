//! Auto-generated mixin: WindowOrWorkerGlobalScope
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const WindowOrWorkerGlobalScopeImpl = @import("impls").WindowOrWorkerGlobalScope;

// Re-export types from impl
pub const impl = @import("impls").WindowOrWorkerGlobalScope;

pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    return WindowOrWorkerGlobalScopeImpl.get_origin(instance);
}

pub fn get_isSecureContext(instance: *runtime.Instance) anyerror!bool {
    return WindowOrWorkerGlobalScopeImpl.get_isSecureContext(instance);
}

pub fn get_crossOriginIsolated(instance: *runtime.Instance) anyerror!bool {
    return WindowOrWorkerGlobalScopeImpl.get_crossOriginIsolated(instance);
}

pub fn get_indexedDB(instance: *runtime.Instance) !*runtime.Instance {
    return WindowOrWorkerGlobalScopeImpl.get_indexedDB(instance);
}

pub fn get_trustedTypes(instance: *runtime.Instance) !*runtime.Instance {
    return WindowOrWorkerGlobalScopeImpl.get_trustedTypes(instance);
}

pub fn get_performance(instance: *runtime.Instance) !*runtime.Instance {
    return WindowOrWorkerGlobalScopeImpl.get_performance(instance);
}

pub fn get_caches(instance: *runtime.Instance) !*runtime.Instance {
    return WindowOrWorkerGlobalScopeImpl.get_caches(instance);
}

pub fn get_scheduler(instance: *runtime.Instance) !*runtime.Instance {
    return WindowOrWorkerGlobalScopeImpl.get_scheduler(instance);
}

pub fn get_crypto(instance: *runtime.Instance) !*runtime.Instance {
    return WindowOrWorkerGlobalScopeImpl.get_crypto(instance);
}

pub fn call_setTimeout(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: runtime.JSValue, arguments: runtime.JSValue) anyerror!i32 {
    return WindowOrWorkerGlobalScopeImpl.call_setTimeout(instance, handler, timeout, arguments);
}

pub fn call_structuredClone(instance: *runtime.Instance, value: runtime.JSValue, options: dictionaries.StructuredSerializeOptions) anyerror!runtime.JSValue {
    return WindowOrWorkerGlobalScopeImpl.call_structuredClone(instance, value, options);
}

pub fn call_atob(instance: *runtime.Instance, data: typedefs.DOMString) anyerror!runtime.ByteString {
    return WindowOrWorkerGlobalScopeImpl.call_atob(instance, data);
}

pub fn call_setInterval(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: runtime.JSValue, arguments: runtime.JSValue) anyerror!i32 {
    return WindowOrWorkerGlobalScopeImpl.call_setInterval(instance, handler, timeout, arguments);
}

pub fn call_btoa(instance: *runtime.Instance, data: typedefs.DOMString) anyerror!typedefs.DOMString {
    return WindowOrWorkerGlobalScopeImpl.call_btoa(instance, data);
}

pub fn call_reportError(instance: *runtime.Instance, e: runtime.JSValue) anyerror!void {
    return WindowOrWorkerGlobalScopeImpl.call_reportError(instance, e);
}

pub fn call_queueMicrotask(instance: *runtime.Instance, callback: callbacks.VoidFunction) anyerror!void {
    return WindowOrWorkerGlobalScopeImpl.call_queueMicrotask(instance, callback);
}

/// Arguments for createImageBitmap (WebIDL overloading)
pub const CreateImageBitmapArgs = union(enum) {
    /// createImageBitmap(image, options)
    ImageBitmapSource_ImageBitmapOptions: struct {
        image: typedefs.ImageBitmapSource,
        options: webidl.Opt(dictionaries.ImageBitmapOptions),
    },
    /// createImageBitmap(image, sx, sy, sw, sh, options)
    ImageBitmapSource_long_long_long_long_ImageBitmapOptions: struct {
        image: typedefs.ImageBitmapSource,
        sx: runtime.JSValue,
        sy: runtime.JSValue,
        sw: runtime.JSValue,
        sh: runtime.JSValue,
        options: webidl.Opt(dictionaries.ImageBitmapOptions),
    },
};

pub fn call_createImageBitmap(instance: *runtime.Instance, args: CreateImageBitmapArgs) anyerror!void {
    return WindowOrWorkerGlobalScopeImpl.call_createImageBitmap(instance, args);
}

pub fn call_fetch(instance: *runtime.Instance, input: typedefs.RequestInfo, init: dictionaries.RequestInit) anyerror!void {
    return WindowOrWorkerGlobalScopeImpl.call_fetch(instance, input, init);
}

pub fn call_clearInterval(instance: *runtime.Instance, id: runtime.JSValue) anyerror!void {
    return WindowOrWorkerGlobalScopeImpl.call_clearInterval(instance, id);
}

pub fn call_clearTimeout(instance: *runtime.Instance, id: runtime.JSValue) anyerror!void {
    return WindowOrWorkerGlobalScopeImpl.call_clearTimeout(instance, id);
}

