//! Auto-generated mixin: WindowOrWorkerGlobalScope
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WindowOrWorkerGlobalScopeImpl = @import("impls").WindowOrWorkerGlobalScope;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ByteString = @import("typedefs").ByteString;
const VoidFunction = @import("callbacks").VoidFunction;
const StructuredSerializeOptions = @import("dictionaries").StructuredSerializeOptions;
const IDBFactory = @import("interfaces").IDBFactory;
const Performance = @import("interfaces").Performance;
const CacheStorage = @import("interfaces").CacheStorage;
const ImageBitmapSource = @import("typedefs").ImageBitmapSource;
const TrustedTypePolicyFactory = @import("interfaces").TrustedTypePolicyFactory;
const TimerHandler = @import("typedefs").TimerHandler;
const USVString = @import("typedefs").USVString;
const RequestInfo = @import("typedefs").RequestInfo;
const RequestInit = @import("dictionaries").RequestInit;
const Scheduler = @import("interfaces").Scheduler;
const Crypto = @import("interfaces").Crypto;
const ImageBitmapOptions = @import("dictionaries").ImageBitmapOptions;
const Response = @import("interfaces").Response;
const DOMString = @import("typedefs").DOMString;
const ImageBitmap = @import("interfaces").ImageBitmap;

pub const impl = @import("impls").WindowOrWorkerGlobalScope;

/// Extended attributes: [Replaceable]
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try WindowOrWorkerGlobalScopeImpl.get_origin(instance);
}

/// Extended attributes: [Replaceable]
pub fn set_origin(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
    // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
    // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
    //                                     [[Enumerable]]: true, [[Configurable]]: true}
    try runtime.defineOwnProperty(instance, "origin", value);
}

pub fn get_isSecureContext(instance: *runtime.Instance) anyerror!bool {
    return try WindowOrWorkerGlobalScopeImpl.get_isSecureContext(instance);
}

pub fn get_crossOriginIsolated(instance: *runtime.Instance) anyerror!bool {
    return try WindowOrWorkerGlobalScopeImpl.get_crossOriginIsolated(instance);
}

/// Extended attributes: [SameObject]
pub fn get_indexedDB(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try WindowOrWorkerGlobalScopeImpl.get_indexedDB(instance);
}

pub fn get_trustedTypes(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try WindowOrWorkerGlobalScopeImpl.get_trustedTypes(instance);
}

/// Extended attributes: [Replaceable]
pub fn get_performance(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try WindowOrWorkerGlobalScopeImpl.get_performance(instance);
}

/// Extended attributes: [Replaceable]
pub fn set_performance(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
    // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
    // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
    //                                     [[Enumerable]]: true, [[Configurable]]: true}
    try runtime.defineOwnProperty(instance, "performance", value);
}

/// Extended attributes: [SecureContext], [SameObject]
pub fn get_caches(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try WindowOrWorkerGlobalScopeImpl.get_caches(instance);
}

/// Extended attributes: [Replaceable]
pub fn get_scheduler(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try WindowOrWorkerGlobalScopeImpl.get_scheduler(instance);
}

/// Extended attributes: [Replaceable]
pub fn set_scheduler(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
    // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
    // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
    //                                     [[Enumerable]]: true, [[Configurable]]: true}
    try runtime.defineOwnProperty(instance, "scheduler", value);
}

/// Extended attributes: [SameObject]
pub fn get_crypto(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try WindowOrWorkerGlobalScopeImpl.get_crypto(instance);
}

pub fn call_setTimeout(instance: *runtime.Instance, handler: TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue) anyerror!i32 {
    return try WindowOrWorkerGlobalScopeImpl.call_setTimeout(instance, handler, timeout, arguments);
}

pub fn call_structuredClone(instance: *runtime.Instance, value: runtime.JSValue, options: webidl.Opt(StructuredSerializeOptions)) anyerror!runtime.JSValue {
    return try WindowOrWorkerGlobalScopeImpl.call_structuredClone(instance, value, options);
}

pub fn call_atob(instance: *runtime.Instance, data: DOMString) anyerror!runtime.ByteString {
    return try WindowOrWorkerGlobalScopeImpl.call_atob(instance, data);
}

pub fn call_setInterval(instance: *runtime.Instance, handler: TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue) anyerror!i32 {
    return try WindowOrWorkerGlobalScopeImpl.call_setInterval(instance, handler, timeout, arguments);
}

pub fn call_btoa(instance: *runtime.Instance, data: DOMString) anyerror!DOMString {
    return try WindowOrWorkerGlobalScopeImpl.call_btoa(instance, data);
}

pub fn call_reportError(instance: *runtime.Instance, e: runtime.JSValue) anyerror!void {
    return try WindowOrWorkerGlobalScopeImpl.call_reportError(instance, e);
}

pub fn call_queueMicrotask(instance: *runtime.Instance, callback: VoidFunction) anyerror!void {
    return try WindowOrWorkerGlobalScopeImpl.call_queueMicrotask(instance, callback);
}

pub fn call_createImageBitmap(instance: *runtime.Instance, image: ImageBitmapSource, options: webidl.Opt(ImageBitmapOptions)) anyerror!runtime.JSValue {
    return try WindowOrWorkerGlobalScopeImpl.call_createImageBitmap(instance, image, options);
}

/// Extended attributes: [NewObject]
pub fn call_fetch(instance: *runtime.Instance, input: RequestInfo, init_data: webidl.Opt(RequestInit)) anyerror!runtime.JSValue {
    // [NewObject] - Caller owns the returned object

    return try WindowOrWorkerGlobalScopeImpl.call_fetch(instance, input, init_data);
}

pub fn call_clearInterval(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    return try WindowOrWorkerGlobalScopeImpl.call_clearInterval(instance, id);
}

pub fn call_clearTimeout(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    return try WindowOrWorkerGlobalScopeImpl.call_clearTimeout(instance, id);
}

pub fn call_createImageBitmap__1(instance: *runtime.Instance, image: ImageBitmapSource, sx: i32, sy: i32, sw: i32, sh: i32, options: webidl.Opt(ImageBitmapOptions)) anyerror!runtime.JSValue {
    if (comptime @hasDecl(WindowOrWorkerGlobalScopeImpl, "call_createImageBitmap__1")) {
        return try WindowOrWorkerGlobalScopeImpl.call_createImageBitmap__1(instance, image, sx, sy, sw, sh, options);
    } else {
        return error.NotImplemented;
    }
}

/// WebIDL overload sets: every overload of each overloaded operation,
/// in IDL order, for the overload resolution algorithm
/// (webidl.overload_resolution). The binding is installed for the first
/// overload and forwards to the one the arguments select.
pub const overloads = .{
    .{ "createImageBitmap", &[_]webidl.overload_resolution.Overload{
        .{ .function = "call_createImageBitmap", .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.dictionary}, .optionality = .optional } } },
        .{ .function = "call_createImageBitmap__1", .implemented = @hasDecl(WindowOrWorkerGlobalScopeImpl, "call_createImageBitmap__1"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.dictionary}, .optionality = .optional } } },
    } },
};

/// WebIDL: operations whose return type is a promise - an exception in
/// their steps becomes a rejected promise.
pub const promise_returning = .{
    "call_createImageBitmap",
    "call_createImageBitmap__1",
    "call_fetch",
};
