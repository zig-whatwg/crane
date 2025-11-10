//! WebIDL Codegen API
//!
//! This module provides compile-time functions for marking structs as WebIDL interfaces,
//! namespaces, and mixins. The actual code generation happens at build time via the
//! webidl-codegen executable.

const std = @import("std");

/// Mark a struct as a WebIDL interface (supports inheritance, methods, properties)
///
/// Usage:
/// ```zig
/// pub const MyInterface = webidl.interface(struct {
///     // fields and methods
/// });
/// ```
pub fn interface(comptime T: type) type {
    return T;
}

/// Mark a struct as a WebIDL namespace (static-only API, no instances)
///
/// Usage:
/// ```zig
/// pub const MyNamespace = webidl.namespace(struct {
///     // static methods only
/// });
/// ```
pub fn namespace(comptime T: type) type {
    return T;
}

/// Mark a struct as a WebIDL interface mixin (reusable member bundles)
///
/// Usage:
/// ```zig
/// pub const MyMixin = webidl.mixin(struct {
///     // mixin members
/// });
/// ```
pub fn mixin(comptime T: type) type {
    return T;
}

/// Configuration for WebIDL code generation
pub const ClassConfig = struct {
    /// Additional options (reserved for future use)
    options: ?*anyopaque = null,
};
