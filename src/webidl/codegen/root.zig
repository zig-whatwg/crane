//! WebIDL Codegen API
//!
//! This module provides compile-time functions for marking structs as WebIDL interfaces,
//! namespaces, and mixins. The actual code generation happens at build time via the
//! webidl-codegen executable.

const std = @import("std");

/// Exposure scope for WebIDL constructs ([Exposed] extended attribute)
pub const ExposureScope = enum {
    all, // [Exposed=*] - Available in all scopes
    Window, // [Exposed=Window] - Browser window context only
    Worker, // [Exposed=Worker] - Web Workers
    DedicatedWorker, // [Exposed=DedicatedWorker] - Dedicated Workers only
    SharedWorker, // [Exposed=SharedWorker] - Shared Workers only
    ServiceWorker, // [Exposed=ServiceWorker] - Service Workers only
};

/// WebIDL interface/namespace options (extended attributes)
///
/// These correspond to WebIDL extended attributes defined in:
/// https://webidl.spec.whatwg.org/#idl-extended-attributes
pub const InterfaceOptions = struct {
    /// [Exposed] - Which global scopes this interface is available in (REQUIRED)
    /// Examples: .exposed = &.{.all}, .exposed = &.{.Window}, .exposed = &.{.Window, .Worker}
    exposed: ?[]const ExposureScope = null,

    /// [Transferable] - Can be transferred between contexts (postMessage)
    /// Used by ReadableStream, WritableStream, TransformStream
    transferable: bool = false,

    /// [Serializable] - Can be serialized (structuredClone, postMessage)
    /// Used by DOMException, ImageData, etc.
    serializable: bool = false,

    /// [SecureContext] - Only available in secure contexts (HTTPS)
    secure_context: bool = false,

    /// [CrossOriginIsolated] - Only available when cross-origin isolated
    cross_origin_isolated: bool = false,

    /// [Global] - This interface is used as a global object (Window, WorkerGlobalScope)
    /// Takes identifier or identifier list specifying names
    global: ?[]const []const u8 = null,

    /// [LegacyFactoryFunction] - Legacy constructor function
    /// Example: [LegacyFactoryFunction=Image(unsigned long width, unsigned long height)]
    legacy_factory_function: ?[]const u8 = null,

    /// [LegacyNoInterfaceObject] - No interface object is created
    legacy_no_interface_object: bool = false,

    /// [LegacyWindowAlias] - Create alias on Window object
    /// Example: [LegacyWindowAlias=WebKitCSSMatrix]
    legacy_window_alias: ?[]const []const u8 = null,

    /// [LegacyNamespace] - Place interface object in a namespace
    /// Example: [LegacyNamespace=WebAssembly]
    legacy_namespace: ?[]const u8 = null,

    /// [LegacyOverrideBuiltIns] - For legacy platform objects
    legacy_override_builtins: bool = false,
};

/// Mark a struct as a WebIDL interface (supports inheritance, methods, properties)
///
/// Usage:
/// ```zig
/// pub const MyInterface = webidl.interface(struct {
///     // fields and methods
/// }, .{
///     .exposed = &.{.all},
///     .transferable = true,
/// });
/// ```
pub fn interface(comptime T: type, comptime options: InterfaceOptions) type {
    _ = options; // Options are parsed by codegen at build time
    return T;
}

/// Mark a struct as a WebIDL namespace (static-only API, no instances)
///
/// Usage:
/// ```zig
/// pub const MyNamespace = webidl.namespace(struct {
///     // static methods only
/// }, .{
///     .exposed = &.{.all},
/// });
/// ```
pub fn namespace(comptime T: type, comptime options: InterfaceOptions) type {
    _ = options; // Options are parsed by codegen at build time
    return T;
}

/// Mark a struct as a WebIDL interface mixin (reusable member bundles)
///
/// Mixins can optionally have [Exposed] attributes:
/// https://webidl.spec.whatwg.org/#idl-interface-mixins
///
/// Usage:
/// ```zig
/// pub const MyMixin = webidl.mixin(struct {
///     // mixin members
/// }, .{
///     .exposed = &.{.all},
/// });
/// ```
pub fn mixin(comptime T: type, comptime options: InterfaceOptions) type {
    _ = options; // Options are parsed by codegen at build time
    return T;
}

/// Configuration for WebIDL code generation
pub const ClassConfig = struct {
    /// Additional options (reserved for future use)
    options: ?*anyopaque = null,
};
