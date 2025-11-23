//! JS Bindings - Engine-Agnostic JavaScript Binding System
//!
//! This module provides an engine-agnostic system for exposing WebIDL
//! interfaces and namespaces to JavaScript engines (V8, JSC, SpiderMonkey, etc.).
//!
//! ## Architecture
//!
//! 1. **types.zig** - Binding descriptor types (NamespaceBinding, InterfaceBinding, etc.)
//! 2. **metadata.zig** - Comptime reflection to extract binding metadata from Zig modules
//! 3. **builder.zig** - High-level API for registering bindings (TODO)
//! 4. **Engine adapters** - V8, JSC, etc. (TODO)
//!
//! ## Usage
//!
//! ```zig
//! const js_bindings = @import("js_bindings");
//!
//! // Extract namespace binding metadata at comptime
//! const console_module = @import("generated/namespaces/console.zig");
//! const console_binding = js_bindings.extractNamespaceMetadata(@TypeOf(console_module.console));
//!
//! // Register with engine (via adapter)
//! try engine.registerNamespace(console_binding);
//! ```

const std = @import("std");

pub const types = @import("types.zig");
pub const metadata = @import("metadata.zig");
pub const registry = @import("registry.zig");

// Re-export main types
pub const NamespaceBinding = types.NamespaceBinding;
pub const InterfaceBinding = types.InterfaceBinding;
pub const MethodDescriptor = types.MethodDescriptor;
pub const AttributeDescriptor = types.AttributeDescriptor;
pub const ConstantDescriptor = types.ConstantDescriptor;
pub const ConstructorDescriptor = types.ConstructorDescriptor;
pub const ParameterDescriptor = types.ParameterDescriptor;
pub const TypeDescriptor = types.TypeDescriptor;
pub const TypeKind = types.TypeKind;

// Re-export metadata extraction functions
pub const extractNamespaceMetadata = metadata.extractNamespaceMetadata;
pub const extractInterfaceMetadata = metadata.extractInterfaceMetadata;

// Re-export registration functions
pub const registerNamespace = registry.registerNamespace;
pub const registerInterface = registry.registerInterface;

test {
    std.testing.refAllDecls(@This());
}
