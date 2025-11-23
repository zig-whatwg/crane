//! V8 JavaScript Engine Implementation
//!
//! Concrete implementation of the abstract JSEngine interface for V8.
//! Implements all required interfaces defined in src/runtime/jsengine.zig.
//!
//! ## Architecture
//!
//! This module provides V8-specific implementations of:
//! - Context management (bidirectional Instance ↔ V8 Object mapping)
//! - FunctionTemplate generation (WebIDL interface → V8 templates)
//! - Type conversion (Zig ↔ V8 values)
//! - Callback system (constructors, getters, setters, methods)
//! - Error handling (Zig errors → V8 exceptions)
//! - Persistent handles (long-lived object references)
//! - EventListener management (addEventListener/removeEventListener)
//!
//! ## Usage
//!
//! ```zig
//! const jsengine = @import("runtime").jsengine;
//! const V8 = jsengine.select(.v8);
//!
//! // Initialize V8 context
//! const ctx = try V8.Context.init(allocator);
//! defer ctx.deinit();
//!
//! // Type conversions
//! const v8_value = try V8.types.toV8(allocator, 42);
//! const zig_value = try V8.types.fromV8(i32, allocator, v8_value);
//! ```

const std = @import("std");

/// V8 Engine Information
pub const info = @import("../../jsengine.zig").EngineInfo{
    .name = "V8",
    .version = "12.0.0", // Mock version for testing
    .supports_jit = true,
    .supports_modules = true,
    .supports_workers = true,
};

/// V8 Context - bidirectional Instance ↔ V8 Object mapping
pub const Context = @import("context.zig").V8Context;

/// V8 FunctionTemplate builder
pub const TemplateBuilder = @import("template.zig").TemplateBuilder;
pub const TemplateRegistry = @import("template.zig").TemplateRegistry;
pub const FunctionTemplate = @import("template.zig").FunctionTemplate;
pub const AttributeDescriptor = @import("template.zig").AttributeDescriptor;
pub const MethodDescriptor = @import("template.zig").MethodDescriptor;

/// V8 Type system
pub const types = struct {
    pub const Value = @import("types/root.zig").V8Value;
    pub const V8Value = @import("types/root.zig").V8Value; // Backward compatibility
    pub const MockV8Array = @import("types/root.zig").MockV8Array;

    // Type conversion functions
    pub const toV8 = @import("types/root.zig").toV8;
    pub const fromV8 = @import("types/root.zig").fromV8;
    pub const sequenceToV8 = @import("types/root.zig").sequenceToV8;
    pub const sequenceFromV8 = @import("types/root.zig").sequenceFromV8;
    pub const unionToV8 = @import("types/root.zig").unionToV8;
    pub const unionFromV8 = @import("types/root.zig").unionFromV8;
    pub const recordToV8 = @import("types/root.zig").recordToV8;
};

/// V8 Callback system
pub const callbacks = struct {
    pub const CallbackInfo = @import("callbacks/root.zig").CallbackInfo;
    pub const PropertyCallbackInfo = @import("callbacks/root.zig").PropertyCallbackInfo;
    pub const ConstructorCallback = @import("callbacks/root.zig").ConstructorCallback;
    pub const GetterCallback = @import("callbacks/root.zig").GetterCallback;
    pub const SetterCallback = @import("callbacks/root.zig").SetterCallback;
    pub const MethodCallback = @import("callbacks/root.zig").MethodCallback;
};

/// V8 Error handling
pub const errors = struct {
    pub const V8Exception = @import("errors/root.zig").V8Exception;
    pub const DOMException = @import("errors/root.zig").DOMException;
    pub const throwV8Exception = @import("errors/root.zig").throwV8Exception;
    pub const mapZigError = @import("errors/root.zig").mapZigError;
};

/// V8 Persistent handles
pub const persistent = struct {
    pub const PersistentHandle = @import("persistent.zig").PersistentHandle;
    pub const PersistentFunction = @import("persistent.zig").PersistentFunction;
    pub const PersistentRegistry = @import("persistent.zig").PersistentRegistry;
};

/// V8 EventListener management
pub const eventlistener = struct {
    pub const EventListener = @import("eventlistener.zig").EventListener;
    pub const EventListenerOptions = @import("eventlistener.zig").EventListenerOptions;
    pub const EventListenerRegistry = @import("eventlistener.zig").EventListenerRegistry;
    pub const Event = @import("eventlistener.zig").Event;
    pub const EventPhase = @import("eventlistener.zig").EventPhase;
};
