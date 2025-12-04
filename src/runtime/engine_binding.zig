//! Engine Binding Interface
//!
//! This module extends the EngineInterface with WebIDL binding generation
//! capabilities. It provides the operations needed to create JavaScript
//! bindings from WebIDL interface descriptors.
//!
//! ## Design Principles
//!
//! 1. **Extends EngineInterface**: All EngineInterface operations are available
//! 2. **Descriptor-Based**: Uses InterfaceDescriptor for binding generation
//! 3. **Engine Agnostic**: Works with V8, JSC, QuickJS, etc.
//! 4. **C ABI Compatible**: Extern structs for FFI compatibility
//!
//! ## Usage
//!
//! ```zig
//! const engine_binding = @import("engine_binding.zig");
//! const binding_types = @import("binding_types.zig");
//!
//! // Get binding interface from engine
//! const binding = engine.getBinding();
//!
//! // Register an interface
//! const desc = binding_types.InterfaceDescriptor{
//!     .name = "Blob",
//!     .has_constructor = true,
//!     .constructors = &.{...},
//!     .methods = &.{...},
//!     .properties = &.{...},
//! };
//!
//! try binding.registerInterface(ctx, &desc);
//! ```

const std = @import("std");
const binding_types = @import("binding_types.zig");
const engine_interface = @import("engine_interface.zig");

// Re-export binding types for convenience
pub const TypeDescriptor = binding_types.TypeDescriptor;
pub const TypeKind = binding_types.TypeKind;
pub const PrimitiveType = binding_types.PrimitiveType;
pub const MethodDescriptor = binding_types.MethodDescriptor;
pub const MethodKind = binding_types.MethodKind;
pub const PropertyDescriptor = binding_types.PropertyDescriptor;
pub const ArgumentDescriptor = binding_types.ArgumentDescriptor;
pub const ConstantDescriptor = binding_types.ConstantDescriptor;
pub const InterfaceDescriptor = binding_types.InterfaceDescriptor;
pub const DictionaryDescriptor = binding_types.DictionaryDescriptor;
pub const DictionaryMemberDescriptor = binding_types.DictionaryMemberDescriptor;
pub const EnumDescriptor = binding_types.EnumDescriptor;
pub const CallbackDescriptor = binding_types.CallbackDescriptor;
pub const Types = binding_types.Types;

// Re-export engine errors
pub const EngineError = engine_interface.EngineError;

// =============================================================================
// Binding Errors
// =============================================================================

/// Errors specific to binding operations
pub const BindingError = error{
    /// Interface is already registered
    AlreadyRegistered,
    /// Parent interface not found
    ParentNotFound,
    /// Mixin not found
    MixinNotFound,
    /// Invalid descriptor
    InvalidDescriptor,
    /// Constructor creation failed
    ConstructorFailed,
    /// Method binding failed
    MethodBindingFailed,
    /// Property binding failed
    PropertyBindingFailed,
    /// Prototype setup failed
    PrototypeSetupFailed,
    /// Template creation failed
    TemplateCreationFailed,
    /// Memory allocation failed
    OutOfMemory,
};

// =============================================================================
// Native Callback Types
// =============================================================================

/// Native constructor callback type
///
/// Called when JavaScript code invokes `new Interface(args...)`.
/// The implementation should:
/// 1. Validate arguments
/// 2. Create Zig-side instance
/// 3. Return opaque pointer to instance
///
/// Arguments:
///   - engine_ctx: Engine-specific context
///   - argc: Number of arguments
///   - argv: Array of argument values (engine-specific)
///   - user_data: User data pointer (can be used to pass allocator or context)
///
/// Returns:
///   - Opaque pointer to created instance
///   - null on construction failure
pub const NativeConstructorFn = *const fn (
    engine_ctx: *anyopaque,
    argc: u32,
    argv: [*]const *anyopaque,
    user_data: ?*anyopaque,
) callconv(.c) ?*anyopaque;

/// Native method callback type
///
/// Called when JavaScript code invokes a method on an interface.
/// The implementation should:
/// 1. Extract `this` instance
/// 2. Validate and convert arguments
/// 3. Call Zig implementation
/// 4. Return result (or null for void)
///
/// Arguments:
///   - engine_ctx: Engine-specific context
///   - this: The `this` value (instance pointer)
///   - argc: Number of arguments
///   - argv: Array of argument values (engine-specific)
///
/// Returns:
///   - Opaque pointer to return value (engine-specific)
///   - null for void methods or on error
pub const NativeMethodFn = *const fn (
    engine_ctx: *anyopaque,
    this: *anyopaque,
    argc: u32,
    argv: [*]const *anyopaque,
) callconv(.c) ?*anyopaque;

/// Native getter callback type
///
/// Called when JavaScript code reads a property.
///
/// Arguments:
///   - engine_ctx: Engine-specific context
///   - this: The `this` value (instance pointer)
///
/// Returns:
///   - Opaque pointer to property value (engine-specific)
pub const NativeGetterFn = *const fn (
    engine_ctx: *anyopaque,
    this: *anyopaque,
) callconv(.c) ?*anyopaque;

/// Native setter callback type
///
/// Called when JavaScript code writes a property.
///
/// Arguments:
///   - engine_ctx: Engine-specific context
///   - this: The `this` value (instance pointer)
///   - value: The value being assigned (engine-specific)
pub const NativeSetterFn = *const fn (
    engine_ctx: *anyopaque,
    this: *anyopaque,
    value: *anyopaque,
) callconv(.c) void;

/// Native indexed getter callback (for indexed properties)
///
/// Called when JavaScript code accesses obj[index].
///
/// Arguments:
///   - engine_ctx: Engine-specific context
///   - this: The `this` value (instance pointer)
///   - index: The numeric index
///
/// Returns:
///   - Opaque pointer to value at index
///   - null if index out of bounds
pub const NativeIndexedGetterFn = *const fn (
    engine_ctx: *anyopaque,
    this: *anyopaque,
    index: u32,
) callconv(.c) ?*anyopaque;

/// Native indexed setter callback (for indexed properties)
///
/// Called when JavaScript code assigns obj[index] = value.
///
/// Arguments:
///   - engine_ctx: Engine-specific context
///   - this: The `this` value (instance pointer)
///   - index: The numeric index
///   - value: The value being assigned
pub const NativeIndexedSetterFn = *const fn (
    engine_ctx: *anyopaque,
    this: *anyopaque,
    index: u32,
    value: *anyopaque,
) callconv(.c) void;

/// Native named getter callback (for named properties)
///
/// Called when JavaScript code accesses obj[name] or obj.name.
///
/// Arguments:
///   - engine_ctx: Engine-specific context
///   - this: The `this` value (instance pointer)
///   - name: The property name
///   - name_len: Length of name string
///
/// Returns:
///   - Opaque pointer to named property value
///   - null if property not found
pub const NativeNamedGetterFn = *const fn (
    engine_ctx: *anyopaque,
    this: *anyopaque,
    name: [*]const u8,
    name_len: u32,
) callconv(.c) ?*anyopaque;

/// Native named setter callback (for named properties)
///
/// Called when JavaScript code assigns obj[name] = value or obj.name = value.
///
/// Arguments:
///   - engine_ctx: Engine-specific context
///   - this: The `this` value (instance pointer)
///   - name: The property name
///   - name_len: Length of name string
///   - value: The value being assigned
pub const NativeNamedSetterFn = *const fn (
    engine_ctx: *anyopaque,
    this: *anyopaque,
    name: [*]const u8,
    name_len: u32,
    value: *anyopaque,
) callconv(.c) void;

/// Destructor callback type
///
/// Called when the JavaScript object is garbage collected.
/// Should free Zig-side resources.
///
/// Arguments:
///   - instance: The Zig instance being destroyed
pub const DestructorFn = *const fn (
    instance: *anyopaque,
) callconv(.c) void;

// =============================================================================
// Interface Binding Config
// =============================================================================

/// Configuration for binding a native interface
///
/// Provides all the native callbacks needed to bind a WebIDL interface.
/// Engine implementations use this along with InterfaceDescriptor to
/// create JavaScript bindings.
pub const InterfaceBindingConfig = extern struct {
    /// Native constructor function
    constructor: ?NativeConstructorFn = null,

    /// Array of native method implementations
    /// Must match order and count of InterfaceDescriptor.methods
    methods: ?[*]const NativeMethodFn = null,
    methods_len: u32 = 0,

    /// Array of native getter implementations
    /// Must match order and count of InterfaceDescriptor.properties
    getters: ?[*]const NativeGetterFn = null,
    getters_len: u32 = 0,

    /// Array of native setter implementations
    /// Must match order of writable properties in InterfaceDescriptor.properties
    /// (readonly properties have no setter)
    setters: ?[*]const NativeSetterFn = null,
    setters_len: u32 = 0,

    /// Indexed property getter (for legacy indexed property getter)
    indexed_getter: ?NativeIndexedGetterFn = null,

    /// Indexed property setter (for legacy indexed property setter)
    indexed_setter: ?NativeIndexedSetterFn = null,

    /// Named property getter (for legacy named property getter)
    named_getter: ?NativeNamedGetterFn = null,

    /// Named property setter (for legacy named property setter)
    named_setter: ?NativeNamedSetterFn = null,

    /// Destructor for garbage collection
    destructor: ?DestructorFn = null,

    /// User data pointer passed to callbacks
    user_data: ?*anyopaque = null,

    /// Allocator for instance creation
    allocator_ptr: ?*anyopaque = null,
};

// =============================================================================
// Template Handle
// =============================================================================

/// Opaque handle to a registered interface template
///
/// Engines return this when registerInterface succeeds.
/// Use to create instances or query registration state.
pub const TemplateHandle = *anyopaque;

// =============================================================================
// Engine Binding VTable
// =============================================================================

/// Engine Binding Interface
///
/// Extends EngineInterface with WebIDL binding generation capabilities.
/// Each JavaScript engine (V8, JSC, QuickJS) implements this interface
/// to provide binding support.
///
/// ## Operations
///
/// ### Interface Registration
/// - registerInterface: Register a WebIDL interface with the engine
/// - registerDictionary: Register a WebIDL dictionary
/// - registerEnum: Register a WebIDL enumeration
/// - registerCallback: Register a WebIDL callback
///
/// ### Template Management
/// - getInterfaceTemplate: Get registered template by name
/// - createInstance: Create a new instance from template
/// - setPrototype: Set up inheritance chain
///
/// ### Value Conversion
/// - toJSValue: Convert Zig value to JS value
/// - fromJSValue: Convert JS value to Zig value
/// - isInstanceOf: Check if JS object is instance of interface
///
/// ### Error Handling
/// - throwTypeError: Throw a JavaScript TypeError
/// - throwRangeError: Throw a JavaScript RangeError
/// - throwDOMException: Throw a DOMException
pub const EngineBinding = extern struct {
    // =========================================================================
    // Base EngineInterface (composition, not inheritance)
    // =========================================================================

    /// Reference to the base EngineInterface
    /// All EngineInterface operations are available through this
    base: *const engine_interface.EngineInterface,

    // =========================================================================
    // Interface Registration
    // =========================================================================

    /// Register a WebIDL interface with the engine
    ///
    /// Creates an interface template (V8 FunctionTemplate, JSC JSClassRef, etc.)
    /// that can be used to create instances and set up the prototype chain.
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - descriptor: Interface descriptor with metadata
    ///   - config: Native callback configuration
    ///
    /// Returns:
    ///   - Handle to registered template
    ///   - BindingError on failure
    registerInterface: ?*const fn (
        engine_ctx: *anyopaque,
        descriptor: *const InterfaceDescriptor,
        config: *const InterfaceBindingConfig,
    ) (BindingError || EngineError)!TemplateHandle,

    /// Register a WebIDL dictionary type
    ///
    /// Dictionaries are converted to/from JS objects at the boundary.
    /// Registration tells the engine how to perform the conversion.
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - descriptor: Dictionary descriptor
    ///
    /// Returns:
    ///   - void on success
    registerDictionary: ?*const fn (
        engine_ctx: *anyopaque,
        descriptor: *const DictionaryDescriptor,
    ) (BindingError || EngineError)!void,

    /// Register a WebIDL enumeration type
    ///
    /// Enums are validated at the JS/Zig boundary.
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - descriptor: Enum descriptor
    ///
    /// Returns:
    ///   - void on success
    registerEnum: ?*const fn (
        engine_ctx: *anyopaque,
        descriptor: *const EnumDescriptor,
    ) (BindingError || EngineError)!void,

    /// Register a WebIDL callback type
    ///
    /// Callbacks can be functions or objects with a specific method.
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - descriptor: Callback descriptor
    ///
    /// Returns:
    ///   - void on success
    registerCallback: ?*const fn (
        engine_ctx: *anyopaque,
        descriptor: *const CallbackDescriptor,
    ) (BindingError || EngineError)!void,

    // =========================================================================
    // Template Management
    // =========================================================================

    /// Get a previously registered interface template by name
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - name: Interface name (null-terminated)
    ///
    /// Returns:
    ///   - Template handle, or null if not registered
    getInterfaceTemplate: ?*const fn (
        engine_ctx: *anyopaque,
        name: [*:0]const u8,
    ) ?TemplateHandle,

    /// Create a new instance of a registered interface
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - template: Template handle from registerInterface
    ///   - zig_instance: Pointer to Zig-side instance data
    ///
    /// Returns:
    ///   - Opaque pointer to JS wrapper object
    createInstance: ?*const fn (
        engine_ctx: *anyopaque,
        template: TemplateHandle,
        zig_instance: *anyopaque,
    ) EngineError!*anyopaque,

    /// Set up the prototype chain for an interface
    ///
    /// Must be called after both interfaces are registered.
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - child_template: Template for the child interface
    ///   - parent_template: Template for the parent interface
    setPrototype: ?*const fn (
        engine_ctx: *anyopaque,
        child_template: TemplateHandle,
        parent_template: TemplateHandle,
    ) BindingError!void,

    /// Include a mixin's members in an interface
    ///
    /// Copies mixin methods and properties to the interface prototype.
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - interface_template: Template for the interface
    ///   - mixin_template: Template for the mixin
    includeMixin: ?*const fn (
        engine_ctx: *anyopaque,
        interface_template: TemplateHandle,
        mixin_template: TemplateHandle,
    ) BindingError!void,

    // =========================================================================
    // Global Object Setup
    // =========================================================================

    /// Expose an interface constructor on the global object
    ///
    /// Makes the interface available as `window.InterfaceName` or `globalThis.InterfaceName`.
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - template: Template handle for the interface
    ///   - name: Name to expose as (usually same as interface name)
    exposeOnGlobal: ?*const fn (
        engine_ctx: *anyopaque,
        template: TemplateHandle,
        name: [*:0]const u8,
    ) EngineError!void,

    /// Set up the global object (Window, WorkerGlobalScope, etc.)
    ///
    /// For [Global] interfaces, this creates the global object instance.
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - template: Template handle for the global interface
    ///   - zig_instance: Zig-side global object instance
    setupGlobalObject: ?*const fn (
        engine_ctx: *anyopaque,
        template: TemplateHandle,
        zig_instance: *anyopaque,
    ) EngineError!*anyopaque,

    // =========================================================================
    // Value Conversion
    // =========================================================================

    /// Convert a Zig value to a JavaScript value
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - type_desc: Type descriptor for the value
    ///   - zig_value: Pointer to Zig value
    ///
    /// Returns:
    ///   - Opaque pointer to JS value
    toJSValue: ?*const fn (
        engine_ctx: *anyopaque,
        type_desc: *const TypeDescriptor,
        zig_value: *const anyopaque,
    ) EngineError!*anyopaque,

    /// Convert a JavaScript value to a Zig value
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - type_desc: Expected type descriptor
    ///   - js_value: Opaque pointer to JS value
    ///   - out_value: Pointer to store Zig value
    ///
    /// Returns:
    ///   - void on success
    ///   - Error if conversion fails (type mismatch, etc.)
    fromJSValue: ?*const fn (
        engine_ctx: *anyopaque,
        type_desc: *const TypeDescriptor,
        js_value: *const anyopaque,
        out_value: *anyopaque,
    ) EngineError!void,

    /// Check if a JS object is an instance of a registered interface
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - js_value: JS value to check
    ///   - interface_name: Name of interface to check against
    ///
    /// Returns:
    ///   - true if js_value is an instance of interface_name
    isInstanceOf: ?*const fn (
        engine_ctx: *anyopaque,
        js_value: *const anyopaque,
        interface_name: [*:0]const u8,
    ) bool,

    /// Extract the Zig instance from a JS wrapper object
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - js_value: JS wrapper object
    ///
    /// Returns:
    ///   - Pointer to Zig instance
    ///   - null if not a wrapped instance
    unwrapInstance: ?*const fn (
        engine_ctx: *anyopaque,
        js_value: *const anyopaque,
    ) ?*anyopaque,

    // =========================================================================
    // Error Throwing
    // =========================================================================

    /// Throw a JavaScript TypeError
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - message: Error message (null-terminated)
    throwTypeError: ?*const fn (
        engine_ctx: *anyopaque,
        message: [*:0]const u8,
    ) void,

    /// Throw a JavaScript RangeError
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - message: Error message (null-terminated)
    throwRangeError: ?*const fn (
        engine_ctx: *anyopaque,
        message: [*:0]const u8,
    ) void,

    /// Throw a DOMException
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - name: Exception name (e.g., "NotFoundError")
    ///   - message: Exception message
    throwDOMException: ?*const fn (
        engine_ctx: *anyopaque,
        name: [*:0]const u8,
        message: [*:0]const u8,
    ) void,

    // =========================================================================
    // Async Support
    // =========================================================================

    /// Create an async iterator wrapper for Symbol.asyncIterator
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - zig_iterator: Zig async iterator implementation
    ///   - descriptor: Type descriptor for yielded values
    ///
    /// Returns:
    ///   - Opaque pointer to JS async iterator object
    createAsyncIterator: ?*const fn (
        engine_ctx: *anyopaque,
        zig_iterator: *anyopaque,
        descriptor: *const TypeDescriptor,
    ) EngineError!*anyopaque,

    /// Create a ReadableStream wrapper
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - zig_stream: Zig ReadableStream implementation
    ///
    /// Returns:
    ///   - Opaque pointer to JS ReadableStream object
    createReadableStream: ?*const fn (
        engine_ctx: *anyopaque,
        zig_stream: *anyopaque,
    ) EngineError!*anyopaque,

    // =========================================================================
    // Structured Clone Support
    // =========================================================================

    /// Check if a value is serializable (for structured clone)
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - js_value: Value to check
    ///
    /// Returns:
    ///   - true if value can be structured cloned
    isSerializable: ?*const fn (
        engine_ctx: *anyopaque,
        js_value: *const anyopaque,
    ) bool,

    /// Check if a value is transferable (for structured clone)
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - js_value: Value to check
    ///
    /// Returns:
    ///   - true if value can be transferred
    isTransferable: ?*const fn (
        engine_ctx: *anyopaque,
        js_value: *const anyopaque,
    ) bool,

    // =========================================================================
    // Metadata
    // =========================================================================

    /// Binding implementation name (e.g., "v8", "jsc", "quickjs")
    name: [*:0]const u8,

    /// Binding implementation version
    version: [*:0]const u8,
};

// =============================================================================
// Stub Binding Implementation
// =============================================================================

/// Stub binding for testing without a real engine
///
/// All operations return errors or null. Useful for testing Zig-only code paths.
pub const stub_binding: EngineBinding = .{
    .base = &engine_interface.stub_engine,
    .registerInterface = stubRegisterInterface,
    .registerDictionary = stubRegisterDictionary,
    .registerEnum = stubRegisterEnum,
    .registerCallback = stubRegisterCallback,
    .getInterfaceTemplate = stubGetInterfaceTemplate,
    .createInstance = stubCreateInstance,
    .setPrototype = stubSetPrototype,
    .includeMixin = stubIncludeMixin,
    .exposeOnGlobal = stubExposeOnGlobal,
    .setupGlobalObject = stubSetupGlobalObject,
    .toJSValue = stubToJSValue,
    .fromJSValue = stubFromJSValue,
    .isInstanceOf = stubIsInstanceOf,
    .unwrapInstance = stubUnwrapInstance,
    .throwTypeError = stubThrowTypeError,
    .throwRangeError = stubThrowRangeError,
    .throwDOMException = stubThrowDOMException,
    .createAsyncIterator = stubCreateAsyncIterator,
    .createReadableStream = stubCreateReadableStream,
    .isSerializable = stubIsSerializable,
    .isTransferable = stubIsTransferable,
    .name = "stub",
    .version = "0.0.0",
};

fn stubRegisterInterface(
    _: *anyopaque,
    _: *const InterfaceDescriptor,
    _: *const InterfaceBindingConfig,
) (BindingError || EngineError)!TemplateHandle {
    return EngineError.NoEngine;
}

fn stubRegisterDictionary(
    _: *anyopaque,
    _: *const DictionaryDescriptor,
) (BindingError || EngineError)!void {
    return EngineError.NoEngine;
}

fn stubRegisterEnum(
    _: *anyopaque,
    _: *const EnumDescriptor,
) (BindingError || EngineError)!void {
    return EngineError.NoEngine;
}

fn stubRegisterCallback(
    _: *anyopaque,
    _: *const CallbackDescriptor,
) (BindingError || EngineError)!void {
    return EngineError.NoEngine;
}

fn stubGetInterfaceTemplate(
    _: *anyopaque,
    _: [*:0]const u8,
) ?TemplateHandle {
    return null;
}

fn stubCreateInstance(
    _: *anyopaque,
    _: TemplateHandle,
    _: *anyopaque,
) EngineError!*anyopaque {
    return EngineError.NoEngine;
}

fn stubSetPrototype(
    _: *anyopaque,
    _: TemplateHandle,
    _: TemplateHandle,
) BindingError!void {
    return BindingError.PrototypeSetupFailed;
}

fn stubIncludeMixin(
    _: *anyopaque,
    _: TemplateHandle,
    _: TemplateHandle,
) BindingError!void {
    return BindingError.MixinNotFound;
}

fn stubExposeOnGlobal(
    _: *anyopaque,
    _: TemplateHandle,
    _: [*:0]const u8,
) EngineError!void {
    return EngineError.NoEngine;
}

fn stubSetupGlobalObject(
    _: *anyopaque,
    _: TemplateHandle,
    _: *anyopaque,
) EngineError!*anyopaque {
    return EngineError.NoEngine;
}

fn stubToJSValue(
    _: *anyopaque,
    _: *const TypeDescriptor,
    _: *const anyopaque,
) EngineError!*anyopaque {
    return EngineError.NoEngine;
}

fn stubFromJSValue(
    _: *anyopaque,
    _: *const TypeDescriptor,
    _: *const anyopaque,
    _: *anyopaque,
) EngineError!void {
    return EngineError.NoEngine;
}

fn stubIsInstanceOf(
    _: *anyopaque,
    _: *const anyopaque,
    _: [*:0]const u8,
) bool {
    return false;
}

fn stubUnwrapInstance(
    _: *anyopaque,
    _: *const anyopaque,
) ?*anyopaque {
    return null;
}

fn stubThrowTypeError(
    _: *anyopaque,
    _: [*:0]const u8,
) void {
    // Stub: No-op
}

fn stubThrowRangeError(
    _: *anyopaque,
    _: [*:0]const u8,
) void {
    // Stub: No-op
}

fn stubThrowDOMException(
    _: *anyopaque,
    _: [*:0]const u8,
    _: [*:0]const u8,
) void {
    // Stub: No-op
}

fn stubCreateAsyncIterator(
    _: *anyopaque,
    _: *anyopaque,
    _: *const TypeDescriptor,
) EngineError!*anyopaque {
    return EngineError.NoEngine;
}

fn stubCreateReadableStream(
    _: *anyopaque,
    _: *anyopaque,
) EngineError!*anyopaque {
    return EngineError.NoEngine;
}

fn stubIsSerializable(
    _: *anyopaque,
    _: *const anyopaque,
) bool {
    return false;
}

fn stubIsTransferable(
    _: *anyopaque,
    _: *const anyopaque,
) bool {
    return false;
}

// =============================================================================
// Tests
// =============================================================================

test "EngineBinding - stub returns errors" {
    const testing = std.testing;

    // Registration should fail with NoEngine
    const desc = InterfaceDescriptor{
        .name = "Test",
    };
    const config = InterfaceBindingConfig{};

    try testing.expectError(
        EngineError.NoEngine,
        stub_binding.registerInterface.?(undefined, &desc, &config),
    );

    // Template lookup should return null
    try testing.expectEqual(
        @as(?TemplateHandle, null),
        stub_binding.getInterfaceTemplate.?(undefined, "Test"),
    );
}

test "EngineBinding - extern struct layout" {
    const testing = std.testing;

    // Verify structs are extern for FFI
    try testing.expect(@typeInfo(EngineBinding).@"struct".layout == .@"extern");
    try testing.expect(@typeInfo(InterfaceBindingConfig).@"struct".layout == .@"extern");
}

test "EngineBinding - base interface accessible" {
    const testing = std.testing;

    // Verify base EngineInterface is accessible
    try testing.expectEqualStrings("stub", stub_binding.base.name);
    try testing.expectEqualStrings("0.0.0", stub_binding.base.version);
}

test "InterfaceBindingConfig - default values" {
    const config = InterfaceBindingConfig{};

    try std.testing.expectEqual(@as(?NativeConstructorFn, null), config.constructor);
    try std.testing.expectEqual(@as(u32, 0), config.methods_len);
    try std.testing.expectEqual(@as(?DestructorFn, null), config.destructor);
}
