//! V8 JavaScript Engine FFI Bindings
//!
//! This module provides Zig bindings to the V8 C++ API for JavaScript execution.
//! All types and functions here map directly to V8's public API.
//!
//! Reference: https://v8.github.io/api/head/

const std = @import("std");

/// V8 Isolate - Represents an isolated instance of the V8 JavaScript engine
pub const Isolate = opaque {};

/// V8 Context - Represents a JavaScript execution context
pub const Context = opaque {};

/// V8 Value - Base type for all JavaScript values
pub const Value = opaque {};

/// V8 Object - JavaScript object
pub const Object = opaque {};

/// V8 String - JavaScript string
pub const String = opaque {};

/// V8 Name - Base type for String and Symbol (used in property accessors)
pub const Name = opaque {};

/// V8 Symbol - JavaScript symbol
pub const Symbol = opaque {};

/// V8 Number - JavaScript number
pub const Number = opaque {};

/// V8 Boolean - JavaScript boolean
pub const Boolean = opaque {};

/// V8 Array - JavaScript array
pub const Array = opaque {};

/// V8 Function - JavaScript function
pub const Function = opaque {};

/// V8 Promise - JavaScript Promise object
pub const Promise = opaque {};

/// V8 PromiseResolver - Creates and resolves/rejects Promises
pub const PromiseResolver = opaque {};

/// V8 ArrayBuffer - JavaScript ArrayBuffer object
pub const ArrayBuffer = opaque {};

/// V8 FunctionTemplate - Template for creating JavaScript functions
pub const FunctionTemplate = opaque {};

/// V8 ObjectTemplate - Template for creating JavaScript objects
pub const ObjectTemplate = opaque {};

/// V8 Template - Base template type
pub const Template = opaque {};

/// V8 External - Wraps C++ pointers for storage in V8
pub const External = opaque {};

/// V8 Script - Compiled JavaScript code
pub const Script = opaque {};

/// V8 Module - ES Module
pub const Module = opaque {};

/// Property attributes (flags for property descriptors)
/// These match V8's PropertyAttribute enum
pub const PropertyAttribute = struct {
    pub const None: c_int = 0;
    pub const ReadOnly: c_int = 1 << 0;
    pub const DontEnum: c_int = 1 << 1;
    pub const DontDelete: c_int = 1 << 2;
};

/// FunctionCallbackInfo - Encapsulates information about a function call from JavaScript
pub const FunctionCallbackInfo = opaque {
    /// Get the V8 isolate for this callback
    pub extern fn v8_FunctionCallbackInfo_GetIsolate(self: *const FunctionCallbackInfo) *Isolate;

    /// Get the number of arguments passed to the function
    pub extern fn v8_FunctionCallbackInfo_Length(self: *const FunctionCallbackInfo) c_int;

    /// Get the argument at the specified index
    pub extern fn v8_FunctionCallbackInfo_GetArgument(self: *const FunctionCallbackInfo, index: c_int) *Value;

    /// Get the 'this' object for the function call
    pub extern fn v8_FunctionCallbackInfo_This(self: *const FunctionCallbackInfo) *Object;

    /// Get the holder object (the object on which the function is defined)
    pub extern fn v8_FunctionCallbackInfo_Holder(self: *const FunctionCallbackInfo) *Object;

    /// Set the return value for the function
    pub extern fn v8_FunctionCallbackInfo_SetReturnValue(self: *const FunctionCallbackInfo, value: *Value) void;

    /// Get data associated with the function template
    pub extern fn v8_FunctionCallbackInfo_Data(self: *const FunctionCallbackInfo) *Value;

    pub inline fn getIsolate(self: *const FunctionCallbackInfo) *Isolate {
        return v8_FunctionCallbackInfo_GetIsolate(self);
    }

    pub inline fn length(self: *const FunctionCallbackInfo) c_int {
        return v8_FunctionCallbackInfo_Length(self);
    }

    pub inline fn get(self: *const FunctionCallbackInfo, index: c_int) *Value {
        return v8_FunctionCallbackInfo_GetArgument(self, index);
    }

    pub inline fn getThis(self: *const FunctionCallbackInfo) *Object {
        return v8_FunctionCallbackInfo_This(self);
    }

    pub inline fn getHolder(self: *const FunctionCallbackInfo) *Object {
        return v8_FunctionCallbackInfo_Holder(self);
    }

    pub inline fn setReturnValue(self: *const FunctionCallbackInfo, value: *Value) void {
        v8_FunctionCallbackInfo_SetReturnValue(self, value);
    }

    pub inline fn getData(self: *const FunctionCallbackInfo) *Value {
        return v8_FunctionCallbackInfo_Data(self);
    }
};

/// PropertyCallbackInfo - Encapsulates information about a property access from JavaScript
pub const PropertyCallbackInfo = opaque {
    /// Get the V8 isolate for this callback
    pub extern fn v8_PropertyCallbackInfo_GetIsolate(self: *const PropertyCallbackInfo) *Isolate;

    /// Get the 'this' object for the property access
    pub extern fn v8_PropertyCallbackInfo_This(self: *const PropertyCallbackInfo) *Object;

    /// Get the holder object
    pub extern fn v8_PropertyCallbackInfo_Holder(self: *const PropertyCallbackInfo) ?*Object;

    /// Set the return value for the getter
    pub extern fn v8_PropertyCallbackInfo_SetReturnValue(self: *const PropertyCallbackInfo, value: *Value) void;

    /// Set return value to undefined (for prototype property access)
    pub extern fn v8_PropertyCallbackInfo_SetUndefined(self: *const PropertyCallbackInfo) void;

    /// Get data associated with the accessor
    pub extern fn v8_PropertyCallbackInfo_Data(self: *const PropertyCallbackInfo) *Value;

    pub inline fn getIsolate(self: *const PropertyCallbackInfo) *Isolate {
        return v8_PropertyCallbackInfo_GetIsolate(self);
    }

    pub inline fn getThis(self: *const PropertyCallbackInfo) *Object {
        return v8_PropertyCallbackInfo_This(self);
    }

    pub inline fn getHolder(self: *const PropertyCallbackInfo) ?*Object {
        return v8_PropertyCallbackInfo_Holder(self);
    }

    pub inline fn setReturnValue(self: *const PropertyCallbackInfo, value: *Value) void {
        v8_PropertyCallbackInfo_SetReturnValue(self, value);
    }

    pub inline fn setUndefined(self: *const PropertyCallbackInfo) void {
        v8_PropertyCallbackInfo_SetUndefined(self);
    }

    pub inline fn getData(self: *const PropertyCallbackInfo) *Value {
        return v8_PropertyCallbackInfo_Data(self);
    }
};

/// Function callback signature for V8 function calls
pub const FunctionCallback = *const fn (*const FunctionCallbackInfo) callconv(.c) void;

/// Getter callback signature for V8 property access (uses Name for modern V8 API)
pub const AccessorGetterCallback = *const fn (
    property_name: *Name,
    info: *const PropertyCallbackInfo,
) callconv(.c) void;

/// Setter callback signature for V8 property modification (uses Name for modern V8 API)
pub const AccessorSetterCallback = *const fn (
    property_name: *Name,
    value: *Value,
    info: *const PropertyCallbackInfoVoid,
) callconv(.c) void;

/// PropertyCallbackInfo for setters (returns void)
pub const PropertyCallbackInfoVoid = opaque {
    pub extern fn v8_PropertyCallbackInfo_Void_GetIsolate(self: *const PropertyCallbackInfoVoid) *Isolate;

    pub inline fn getIsolate(self: *const PropertyCallbackInfoVoid) *Isolate {
        return v8_PropertyCallbackInfo_Void_GetIsolate(self);
    }
};

// ============================================================================
// Named Property Handler Callbacks
// ============================================================================

/// Called when JavaScript accesses a named property (e.g., obj.propertyName or obj['propertyName'])
/// Should set the return value if the property exists, or do nothing to continue the lookup chain
pub const NamedPropertyGetterCallback = *const fn (
    property: *Name,
    info: *const PropertyCallbackInfo,
) callconv(.c) void;

/// Called when JavaScript sets a named property (e.g., obj.propertyName = value)
/// Should set a return value to indicate success/failure
pub const NamedPropertySetterCallback = *const fn (
    property: *Name,
    value: *Value,
    info: *const PropertyCallbackInfo,
) callconv(.c) void;

/// Called to check if a named property exists on the object
/// Should return an integer attribute value, or do nothing if property doesn't exist
pub const NamedPropertyQueryCallback = *const fn (
    property: *Name,
    info: *const PropertyCallbackInfo,
) callconv(.c) void;

/// Called when JavaScript deletes a named property (e.g., delete obj.propertyName)
/// Should set return value to true if deletion succeeds, false if it fails
pub const NamedPropertyDeleterCallback = *const fn (
    property: *Name,
    info: *const PropertyCallbackInfo,
) callconv(.c) void;

/// Called when JavaScript enumerates object properties (e.g., for...in loop, Object.keys())
/// Should set return value to an array of property names
pub const NamedPropertyEnumeratorCallback = *const fn (
    info: *const PropertyCallbackInfo,
) callconv(.c) void;

/// Called when JavaScript accesses an indexed property (e.g., obj[0], obj[1])
/// Should set the return value if the index exists, or do nothing to continue the lookup chain
pub const IndexedPropertyGetterCallback = *const fn (
    index: u32,
    info: *const PropertyCallbackInfo,
) callconv(.c) void;

// ============================================================================
// V8 API Function Declarations
// ============================================================================

// ObjectTemplate functions
pub extern fn v8_ObjectTemplate_New(isolate: *Isolate) *ObjectTemplate;
pub extern fn v8_ObjectTemplate_NewInstance(self: *ObjectTemplate, context: *Context) *Object;
pub extern fn v8_ObjectTemplate_SetInternalFieldCount(self: *ObjectTemplate, count: c_int) void;
pub extern fn v8_ObjectTemplate_Set(
    self: *ObjectTemplate,
    name: *String,
    value: *Value,
) void;

pub extern fn v8_ObjectTemplate_SetWithAttributes(
    self: *ObjectTemplate,
    name: *String,
    value: *Value,
    attributes: c_int,
) void;

pub extern fn v8_ObjectTemplate_SetAccessor(
    self: *ObjectTemplate,
    name: *String,
    getter: ?AccessorGetterCallback,
    setter: ?AccessorSetterCallback,
    data: ?*Value,
) void;

/// Set an accessor property on the ObjectTemplate (creates visible descriptor)
/// Unlike SetAccessor, this creates property descriptors visible to Object.getOwnPropertyDescriptor
/// with { get: [Function], set: [Function] }
///
/// Uses FunctionCallback signatures (same as methods) - the getter receives no arguments,
/// the setter receives the new value as first argument. Both can access 'this' via info.getThis().
pub extern fn v8_ObjectTemplate_SetAccessorProperty(
    self: *ObjectTemplate,
    name: *String,
    getter: ?FunctionCallback,
    setter: ?FunctionCallback,
) void;

/// Set a named property handler on the ObjectTemplate
/// This intercepts all property access operations that aren't explicitly defined
pub extern fn v8_ObjectTemplate_SetNamedPropertyHandler(
    self: *ObjectTemplate,
    getter: ?NamedPropertyGetterCallback,
    setter: ?NamedPropertySetterCallback,
    query: ?NamedPropertyQueryCallback,
    deleter: ?NamedPropertyDeleterCallback,
    enumerator: ?NamedPropertyEnumeratorCallback,
    data: ?*Value,
) void;

/// Set an indexed property handler on the ObjectTemplate
/// This intercepts indexed property access (e.g., obj[0], obj[1], etc.)
pub extern fn v8_ObjectTemplate_SetIndexedPropertyHandler(
    self: *ObjectTemplate,
    getter: IndexedPropertyGetterCallback,
) void;

// ============================================================================
// OLD API REMOVED - See unified API below
// ============================================================================

// ============================================================================
// Unified V8 C API - MixedCase Naming Convention
// All functions use Global<T>* handles for cross-scope persistence
// ============================================================================

// Platform initialization
pub extern fn v8_Platform_Initialize() void;
pub extern fn v8_Platform_Dispose() void;

// Isolate management
pub extern fn v8_Isolate_New() ?*Isolate;
pub extern fn v8_Isolate_Dispose(isolate: *Isolate) void;
pub extern fn v8_Isolate_Enter(isolate: *Isolate) void;
pub extern fn v8_Isolate_Exit(isolate: *Isolate) void;
pub extern fn v8_Isolate_GetCurrentContext(isolate: *Isolate) ?*Context;
pub extern fn v8_Isolate_GetCurrent() ?*Isolate;
pub extern fn v8_Isolate_ThrowException(isolate: *Isolate, exception: *Value) void;

// Isolate embedder data (for storing per-isolate state)
pub extern fn v8_Isolate_SetData(isolate: *Isolate, slot: c_int, data: ?*anyopaque) void;
pub extern fn v8_Isolate_GetData(isolate: *Isolate, slot: c_int) ?*anyopaque;

// Garbage collection (for WHATWG TestUtils Standard)
// NOTE: Only for testing, not for production use
pub extern fn v8_Isolate_RequestGarbageCollection(isolate: *Isolate) void;

// Context management
pub extern fn v8_Context_New(isolate: *Isolate) ?*Context;
pub extern fn v8_Context_NewWithGlobalTemplate(isolate: *Isolate, global_template: *ObjectTemplate) ?*Context;
pub extern fn v8_Context_Dispose(context: *Context) void;
pub extern fn v8_Context_Enter(context: *Context) void;
pub extern fn v8_Context_Exit(context: *Context) void;
pub extern fn v8_Context_Global(context: *Context) ?*Object;
pub extern fn v8_Context_GetRawAddress(context: *Context) ?*anyopaque;

// String management
pub extern fn v8_String_NewFromUtf8(isolate: *Isolate, data: [*]const u8, length: c_int) ?*String;
pub extern fn v8_String_Utf8Length(str: *String) c_int;
pub extern fn v8_String_WriteUtf8(str: *String, buffer: [*]u8, length: c_int) c_int;
pub extern fn v8_String_Dispose(str: *String) void;
pub extern fn v8_String_Empty(isolate: *Isolate) ?*String;

// Value operations
pub extern fn v8_Value_IsUndefined(value: *Value) bool;
pub extern fn v8_Value_IsNull(value: *Value) bool;
pub extern fn v8_Value_IsNullOrUndefined(value: *Value) bool;
pub extern fn v8_Value_IsBoolean(value: *Value) bool;
pub extern fn v8_Value_IsNumber(value: *Value) bool;
pub extern fn v8_Value_IsString(value: *Value) bool;
pub extern fn v8_Value_IsSymbol(value: *Value) bool;
pub extern fn v8_Value_IsBigInt(value: *Value) bool;

// Symbol operations
pub extern fn v8_Symbol_GetToStringTag(isolate: *Isolate) ?*Symbol;
pub extern fn v8_Symbol_GetIterator(isolate: *Isolate) ?*Symbol;
pub extern fn v8_Symbol_GetAsyncIterator(isolate: *Isolate) ?*Symbol;
pub extern fn v8_Symbol_Dispose(symbol: *Symbol) void;
pub extern fn v8_Value_IsObject(value: *Value) bool;
pub extern fn v8_Value_IsFunction(value: *Value) bool;
pub extern fn v8_Value_IsArray(value: *Value) bool;
pub extern fn v8_Value_IsPromise(value: *Value) bool;
pub extern fn v8_Value_BooleanValue(value: *Value, isolate: *Isolate) bool;
pub extern fn v8_Value_NumberValue(value: *Value, context: *Context) f64;
pub extern fn v8_Value_Int32Value(value: *Value, context: *Context) i32;
pub extern fn v8_Value_Uint32Value(value: *Value, context: *Context) u32;
pub extern fn v8_Value_IntegerValue(value: *Value, context: *Context) i64;
pub extern fn v8_Value_ToString(value: *Value, context: *Context) ?*String;
pub extern fn v8_Value_StrictEquals(value1: *Value, value2: *Value) bool;
pub extern fn v8_Value_Dispose(value: *Value) void;

// Name Functions
pub extern fn v8_Name_IsString(name: *Name) bool;

// String Functions (for raw pointers from callbacks)
pub extern fn v8_String_Utf8Length_Raw(str: *const String) c_int;
pub extern fn v8_String_WriteUtf8_Raw(str: *const String, buffer: [*]u8, length: c_int) c_int;

// Number value extraction for raw pointers (from callbacks/anyopaque)
pub extern fn v8_Value_NumberValue_Raw(value: *const anyopaque) f64;

// String value extraction for raw pointers (from callbacks/anyopaque)
// Returns -1 if not a string, otherwise UTF-8 byte length
pub extern fn v8_Value_StringLength_Raw(value: *const anyopaque) c_int;
// Writes UTF-8 to buffer, returns bytes written
pub extern fn v8_Value_StringWriteUtf8_Raw(value: *const anyopaque, buffer: [*]u8, buffer_len: c_int) c_int;

// Object operations
pub extern fn v8_Object_New(isolate: *Isolate) ?*Object;
pub extern fn v8_Object_Set(object: *Object, context: *Context, key: *Value, value: *Value) bool;
pub extern fn v8_Object_CreateDataProperty(object: *Object, context: *Context, key: *String, value: *Value) bool;
pub extern fn v8_Object_Get(object: *Object, context: *Context, key: *Value) ?*Value;
pub extern fn v8_Object_GetOwnPropertyNames(context: *Context, obj: *Object) ?*Array;
pub extern fn v8_Object_GetPropertyNames(context: *Context, obj: *Object) ?*Array;
pub extern fn v8_Object_SetAlignedPointerInInternalField(object: *Object, index: c_int, value: *anyopaque) void;
pub extern fn v8_Object_InternalFieldCount(object: *Object) c_int;
pub extern fn v8_Object_GetAlignedPointerFromInternalField(object: *Object, index: c_int) ?*anyopaque;
// Raw versions for property interceptors (take raw Local pointers not Global handles)
pub extern fn v8_Object_InternalFieldCount_Raw(object: *const anyopaque) c_int;
pub extern fn v8_Object_GetAlignedPointerFromInternalField_Raw(object: *const anyopaque, index: c_int) ?*anyopaque;
pub extern fn v8_Object_Dispose(obj: *Object) void;
pub extern fn v8_Object_DefineProperty(object: *Object, context: *Context, key: *Value, value: *Value, writable: bool, enumerable: bool, configurable: bool) bool;
pub extern fn v8_Object_SetPrototype(object: *Object, context: *Context, prototype: *Value) bool;
pub extern fn v8_Object_PreventExtensions(object: *Object, context: *Context) bool;
pub extern fn v8_Object_Has(context: *Context, obj: *Object, key: [*:0]const u8) bool;
pub extern fn v8_Object_GetPropertyWithSymbol(context: *Context, obj: *Object, symbol: *Symbol) ?*Value;

// Array operations
pub extern fn v8_Array_New(isolate: *Isolate, length: c_int) *Array;
pub extern fn v8_Array_Length(arr: *Array) u32;
pub extern fn v8_Array_Get(context: *Context, arr: *Array, index: u32) ?*Value;
pub extern fn v8_Array_Set(arr: *Array, context: *Context, index: u32, value: *Value) bool;
pub extern fn v8_Array_Dispose(arr: *Array) void;

// Script compilation and execution
pub extern fn v8_Script_Compile(context: *Context, source: *String) ?*Script;
/// Compile a script with source origin information (for error messages and source maps)
pub extern fn v8_Script_CompileWithOrigin(context: *Context, source: *String, resource_name: *String) ?*Script;
pub extern fn v8_Script_Run(context: *Context, script: *Script) ?*Value;
pub extern fn v8_Script_Dispose(script: *Script) void;

// ============================================================================
// ES Module API
// ============================================================================

/// Module status values
/// Spec: https://tc39.es/ecma262/#sec-moduleevaluation
pub const ModuleStatus = enum(c_int) {
    Uninstantiated = 0,
    Instantiating = 1,
    Instantiated = 2,
    Evaluating = 3,
    Evaluated = 4,
    Errored = 5,
};

/// Module resolve callback function type
/// Called by V8 when a module imports another module.
/// Arguments:
///   user_data: Context pointer passed to v8_Module_SetResolveCallback
///   specifier: The import specifier (e.g., "./module.js")
///   specifier_len: Length of specifier string
///   referrer_module: The module that contains the import
/// Returns:
///   Global<Module>* for the resolved module, or null on error
pub const ModuleResolveCallback = *const fn (
    user_data: ?*anyopaque,
    specifier: [*]const u8,
    specifier_len: c_int,
    referrer_module: ?*anyopaque,
) callconv(.c) ?*anyopaque;

/// Set the module resolve callback for import resolution
/// This callback is invoked when V8 needs to resolve module imports.
///
/// @param user_data - Context pointer passed to callback
/// @param callback - Function called to resolve imports
pub extern fn v8_Module_SetResolveCallback(
    user_data: ?*anyopaque,
    callback: ModuleResolveCallback,
) void;

/// Compile source code as an ES Module
/// Returns null on compilation error (syntax error, etc.)
///
/// @param context - V8 context for compilation
/// @param source - Module source code as V8 String
/// @param resource_name - Module specifier/URL (for error messages and source maps)
/// @return Global<Module>* or null on error
pub extern fn v8_Module_Compile(
    context: *Context,
    source: *String,
    resource_name: ?*String,
) ?*Module;

/// Get the number of import requests in a module
/// Used to iterate over module's import statements.
///
/// @param module - The compiled module
/// @return Number of imports
pub extern fn v8_Module_GetModuleRequestsLength(module: *Module) c_int;

/// Get the module specifier (import path) at the given index
/// Caller must free the returned string with v8_FreeString.
///
/// @param module - The compiled module
/// @param index - Import index (0 to GetModuleRequestsLength-1)
/// @return Import specifier string (owned by caller) or null
pub extern fn v8_Module_GetModuleRequest(module: *Module, index: c_int) ?[*:0]u8;

/// Free a string allocated by v8_Module_GetModuleRequest
pub extern fn v8_FreeString(str: ?[*:0]u8) void;

/// Get the module's current status
///
/// @param module - The module to query
/// @return ModuleStatus value
pub extern fn v8_Module_GetStatus(module: *Module) c_int;

/// Instantiate the module (link all imports)
/// This resolves all import statements using the registered resolve callback.
/// Returns false if linking fails (missing imports, circular dependency errors).
///
/// @param context - V8 context
/// @param module - The module to instantiate
/// @return true on success, false on error
pub extern fn v8_Module_Instantiate(context: *Context, module: *Module) bool;

/// Evaluate the module (execute top-level code)
/// The module must be instantiated first.
/// Returns the module's completion value, or null on error.
///
/// @param context - V8 context
/// @param module - The instantiated module
/// @return Evaluation result value, or null on error
pub extern fn v8_Module_Evaluate(context: *Context, module: *Module) ?*Value;

/// Get the module's exception (if status is Errored)
/// Only valid when GetStatus returns ModuleStatus.Errored.
///
/// @param module - The errored module
/// @return Exception value, or null if not errored
pub extern fn v8_Module_GetException(module: *Module) ?*Value;

/// Get the module's namespace object (exports)
/// Returns an object with the module's exported bindings.
///
/// @param module - The evaluated module
/// @return Namespace object, or null if not yet evaluated
pub extern fn v8_Module_GetModuleNamespace(module: *Module) ?*Object;

/// Get the module's identity hash (for use as map key)
/// This is a stable identifier for the module instance.
///
/// @param module - The module
/// @return Hash value suitable for use in hash maps
pub extern fn v8_Module_GetIdentityHash(module: *Module) c_int;

/// Dispose a module handle
///
/// @param module - The module to dispose
pub extern fn v8_Module_Dispose(module: *Module) void;

/// Check if a module or any of its dependencies has top-level await
///
/// Per TC39 TLA spec, this returns true if the module graph contains
/// any async module (i.e., module with top-level await).
/// Must be called after module instantiation.
///
/// @param module - Compiled and instantiated module handle
/// @return true if the module or any dependency has TLA
pub extern fn v8_Module_IsGraphAsync(module: *Module) bool;

// ============================================================================
// Dynamic Import (import() expression) Support
// ============================================================================

/// Callback function type for dynamic import (import() expression)
///
/// This callback is invoked by V8 whenever JavaScript code uses import().
/// The callback receives:
///   - user_data: Context passed when registering the callback
///   - context: V8 Context* where import() was called
///   - referrer_specifier: Module specifier of the calling module (or null)
///   - referrer_len: Length of referrer specifier
///   - specifier: The specifier passed to import()
///   - specifier_len: Length of specifier
///   - promise_resolver: V8 PromiseResolver* to resolve/reject with result
///
/// The callback must eventually call v8_DynamicImport_Resolve or v8_DynamicImport_Reject
/// to settle the promise.
pub const DynamicImportCallback = *const fn (
    user_data: ?*anyopaque,
    context: ?*anyopaque,
    referrer_specifier: ?[*]const u8,
    referrer_len: c_int,
    specifier: [*]const u8,
    specifier_len: c_int,
    promise_resolver: *anyopaque,
) callconv(.c) void;

/// Set the dynamic import callback for an isolate
///
/// This callback is invoked whenever import() is used in JavaScript.
/// Must be called on the isolate before any modules that use import() are executed.
///
/// @param isolate - V8 Isolate
/// @param user_data - Context passed to callback
/// @param callback - Function called to handle dynamic imports
pub extern fn v8_Isolate_SetHostImportModuleDynamicallyCallback(
    isolate: *Isolate,
    user_data: ?*anyopaque,
    callback: DynamicImportCallback,
) void;

/// Resolve a dynamic import promise with a module namespace
///
/// Called from Zig when module loading succeeds.
///
/// @param context - V8 Context* from callback
/// @param resolver - V8 PromiseResolver* from callback
/// @param module_namespace - V8 Object* (module namespace from v8_Module_GetModuleNamespace)
pub extern fn v8_DynamicImport_Resolve(
    context: *anyopaque,
    resolver: *anyopaque,
    module_namespace: *Object,
) void;

/// Reject a dynamic import promise with an error
///
/// Called from Zig when module loading fails.
///
/// @param context - V8 Context* from callback
/// @param resolver - V8 PromiseResolver* from callback
/// @param error_message - Error message string
/// @param error_message_len - Length of error message
pub extern fn v8_DynamicImport_Reject(
    context: *anyopaque,
    resolver: *anyopaque,
    error_message: [*]const u8,
    error_message_len: c_int,
) void;

// Exception handling
pub extern fn v8_Exception_TypeError(message: *String) ?*Value;
pub extern fn v8_Exception_RangeError(message: *String) ?*Value;
pub extern fn v8_Exception_SyntaxError(message: *String) ?*Value;
pub extern fn v8_Exception_Error(message: *String) ?*Value;
pub extern fn v8_TryCatch_Exception(context: *Context) ?*Value;

// Special values
pub extern fn v8_Undefined(isolate: *Isolate) ?*Value;
pub extern fn v8_Null(isolate: *Isolate) ?*Value;

// Boolean creation
pub extern fn v8_Boolean_New(isolate: *Isolate, value: bool) ?*Value;

// Number creation
pub extern fn v8_Number_New(isolate: *Isolate, value: f64) *Number;
pub extern fn v8_Integer_New(isolate: *Isolate, value: i32) *Number;

// FunctionTemplate (for namespace and interface bindings)
pub extern fn v8_FunctionTemplate_New(isolate: *Isolate, callback: ?FunctionCallback, data: ?*Value) ?*FunctionTemplate;
/// Create FunctionTemplate with Signature (receiver type checking)
/// The signature ensures the callback is only called when 'this' is an instance
/// of the receiver template (or a subclass via inheritance).
pub extern fn v8_FunctionTemplate_NewWithSignature(isolate: *Isolate, callback: ?FunctionCallback, data: ?*Value, receiver: *FunctionTemplate) ?*FunctionTemplate;
pub extern fn v8_FunctionTemplate_GetFunction(function_template: *FunctionTemplate, context: *Context) ?*Function;
pub extern fn v8_FunctionTemplate_Dispose(tpl: *FunctionTemplate) void;
pub extern fn v8_FunctionTemplate_SetClassName(tpl: *FunctionTemplate, name: *String) void;
pub extern fn v8_FunctionTemplate_InstanceTemplate(tpl: *FunctionTemplate) *ObjectTemplate;
pub extern fn v8_FunctionTemplate_PrototypeTemplate(tpl: *FunctionTemplate) *ObjectTemplate;
pub extern fn v8_FunctionTemplate_Inherit(tpl: *FunctionTemplate, parent: *FunctionTemplate) void;
pub extern fn v8_FunctionTemplate_SetLength(tpl: *FunctionTemplate, length: c_int) void;

// Function
pub extern fn v8_Function_Dispose(fn_ptr: *Function) void;

/// Call a JavaScript function from native code
///
/// This enables Zig to invoke JavaScript callbacks, essential for Streams API.
///
/// @param function - The JavaScript function to call
/// @param context - The V8 context in which to execute
/// @param recv - The 'this' value (use v8_Undefined for no 'this')
/// @param argc - Number of arguments
/// @param argv - Array of argument values
/// @return Return value from function, or null if exception occurred
pub extern fn v8_Function_Call(
    function: *Function,
    context: *Context,
    recv: *Value,
    argc: c_int,
    argv: [*]*Value,
) ?*Value;

/// Call a JavaScript function with custom receiver ('this' binding)
///
/// Similar to v8_Function_Call but allows specifying custom 'this' value.
/// Used for calling iterator.next() with iterator as 'this'.
///
/// @param context - The V8 context
/// @param function - The function to call
/// @param receiver - The 'this' value (null = undefined)
/// @param argc - Number of arguments
/// @param argv - Array of argument values
/// @return Return value, or null if exception occurred
pub extern fn v8_Function_CallWithReceiver(
    context: *Context,
    function: *Function,
    receiver: ?*Value,
    argc: c_int,
    argv: ?[*]*Value,
) ?*Value;

// ============================================================================
// Promise API (Phase 2: Runtime Callback Infrastructure)
// ============================================================================

/// Create a new Promise resolver
pub extern fn v8_PromiseResolver_New(context: *Context) ?*PromiseResolver;

/// Get Promise from resolver
pub extern fn v8_PromiseResolver_GetPromise(resolver: *PromiseResolver) ?*Promise;

/// Resolve a Promise with a value
pub extern fn v8_PromiseResolver_Resolve(
    resolver: *PromiseResolver,
    context: *Context,
    value: *Value,
) bool;

/// Reject a Promise with a reason
pub extern fn v8_PromiseResolver_Reject(
    resolver: *PromiseResolver,
    context: *Context,
    reason: *Value,
) bool;

/// Chain a .then() handler to a Promise
pub extern fn v8_Promise_Then(
    promise: *Promise,
    context: *Context,
    on_fulfilled: ?*Function,
    on_rejected: ?*Function,
) ?*Promise;

/// Chain a .catch() handler to a Promise
pub extern fn v8_Promise_Catch(
    promise: *Promise,
    context: *Context,
    on_rejected: *Function,
) ?*Promise;

/// Dispose a Promise
pub extern fn v8_Promise_Dispose(promise: *Promise) void;

/// Dispose a PromiseResolver
pub extern fn v8_PromiseResolver_Dispose(resolver: *PromiseResolver) void;

/// Create a JavaScript function that resolves a PromiseResolver
///
/// Returns a Function that, when called, will resolve the PromiseResolver
/// with the first argument passed to it. Used for chaining Promises.
pub extern fn v8_PromiseResolver_CreateResolveHandler(
    context: *Context,
    resolver: *PromiseResolver,
) ?*Function;

/// Create a JavaScript function that rejects a PromiseResolver
///
/// Returns a Function that, when called, will reject the PromiseResolver
/// with the first argument passed to it. Used for chaining Promises.
pub extern fn v8_PromiseResolver_CreateRejectHandler(
    context: *Context,
    resolver: *PromiseResolver,
) ?*Function;

// ============================================================================
// Zig Callback Bridge for Promise Handlers
// ============================================================================

/// Callback type for Zig promise fulfillment handler
/// Called when a V8 Promise fulfills
/// Arguments:
///   - context: The context pointer passed when creating the handler
///   - value: The fulfillment value (as a V8 Global<Value>*), or null for undefined
pub const ZigPromiseFulfillCallback = *const fn (context: ?*anyopaque, value: ?*anyopaque) callconv(.c) void;

/// Callback type for Zig promise rejection handler
/// Called when a V8 Promise rejects
/// Arguments:
///   - context: The context pointer passed when creating the handler
///   - reason: The rejection reason (as a V8 Global<Value>*), or null for undefined
pub const ZigPromiseRejectCallback = *const fn (context: ?*anyopaque, reason: ?*anyopaque) callconv(.c) void;

/// Create a V8 Function that invokes a Zig fulfill callback when called
///
/// When the returned function is called (e.g., from Promise.then()), it will:
/// 1. Extract the first argument (or undefined)
/// 2. Call the Zig fulfill_callback with the context and argument
///
/// @param context - V8 Context
/// @param fulfill_callback - Zig function to call on fulfillment
/// @param fulfill_context - Context pointer to pass to Zig callback
/// @return Global<Function>* that invokes the Zig callback, or null on failure
pub extern fn v8_CreateZigFulfillHandler(
    context: *Context,
    fulfill_callback: ZigPromiseFulfillCallback,
    fulfill_context: ?*anyopaque,
) ?*Function;

/// Create a V8 Function that invokes a Zig reject callback when called
///
/// When the returned function is called (e.g., from Promise.catch()), it will:
/// 1. Extract the first argument (rejection reason, or undefined)
/// 2. Call the Zig reject_callback with the context and reason
///
/// @param context - V8 Context
/// @param reject_callback - Zig function to call on rejection
/// @param reject_context - Context pointer to pass to Zig callback
/// @return Global<Function>* that invokes the Zig callback, or null on failure
pub extern fn v8_CreateZigRejectHandler(
    context: *Context,
    reject_callback: ZigPromiseRejectCallback,
    reject_context: ?*anyopaque,
) ?*Function;

/// Dispose a Zig callback handler function
///
/// Frees the V8 Global<Function> and associated callback data.
/// Must be called when the handler is no longer needed.
pub extern fn v8_DisposeZigCallbackHandler(handler: *Function) void;

// ============================================================================
// ArrayBuffer API (Phase 4: Runtime Infrastructure)
// ============================================================================

/// Create a new ArrayBuffer
///
/// Allocates a V8 ArrayBuffer with the specified byte length.
/// Caller must call v8_ArrayBuffer_Dispose when done.
///
/// @param isolate - The V8 isolate
/// @param byte_length - Size of the buffer in bytes
/// @return New ArrayBuffer, or null if allocation failed
pub extern fn v8_ArrayBuffer_New(isolate: *Isolate, byte_length: usize) ?*ArrayBuffer;

/// Get ArrayBuffer backing store pointer
///
/// Returns a pointer to the raw memory backing the ArrayBuffer.
/// Valid only while the ArrayBuffer is not detached.
///
/// @param buffer - The ArrayBuffer
/// @return Pointer to backing store, or null if detached
pub extern fn v8_ArrayBuffer_Data(buffer: *ArrayBuffer) ?*anyopaque;

/// Get ArrayBuffer byte length
///
/// @param buffer - The ArrayBuffer
/// @return Size of the buffer in bytes
pub extern fn v8_ArrayBuffer_ByteLength(buffer: *ArrayBuffer) usize;

/// Check if ArrayBuffer is detached
///
/// A detached ArrayBuffer has had its backing store transferred away
/// and can no longer be used.
///
/// @param buffer - The ArrayBuffer
/// @return true if detached, false otherwise
pub extern fn v8_ArrayBuffer_IsDetached(buffer: *ArrayBuffer) bool;

/// Detach an ArrayBuffer
///
/// Transfers ownership of the backing store, making the ArrayBuffer unusable.
/// Used for transferable ArrayBuffers in postMessage and structured clone.
///
/// @param buffer - The ArrayBuffer to detach
pub extern fn v8_ArrayBuffer_Detach(buffer: *ArrayBuffer) void;

/// Dispose ArrayBuffer
///
/// Releases the V8 ArrayBuffer handle.
/// Must be called to avoid memory leaks.
///
/// @param buffer - The ArrayBuffer to dispose
pub extern fn v8_ArrayBuffer_Dispose(buffer: *ArrayBuffer) void;

// ============================================================================
// TypedArray API (Phase 4: ArrayBufferView Introspection)
// ============================================================================

/// TypedArray - Base type for all typed arrays
pub const TypedArray = opaque {};

/// Check if a Value is a Uint8Array
pub extern fn v8_Value_IsUint8Array(value: *Value) bool;

/// Check if a Value is an Int8Array
pub extern fn v8_Value_IsInt8Array(value: *Value) bool;

/// Check if a Value is a Uint16Array
pub extern fn v8_Value_IsUint16Array(value: *Value) bool;

/// Check if a Value is an Int16Array
pub extern fn v8_Value_IsInt16Array(value: *Value) bool;

/// Check if a Value is a Uint32Array
pub extern fn v8_Value_IsUint32Array(value: *Value) bool;

/// Check if a Value is an Int32Array
pub extern fn v8_Value_IsInt32Array(value: *Value) bool;

/// Check if a Value is a Float32Array
pub extern fn v8_Value_IsFloat32Array(value: *Value) bool;

/// Check if a Value is a Float64Array
pub extern fn v8_Value_IsFloat64Array(value: *Value) bool;

/// Check if a Value is a Uint8ClampedArray
pub extern fn v8_Value_IsUint8ClampedArray(value: *Value) bool;

/// Check if a Value is a BigInt64Array
pub extern fn v8_Value_IsBigInt64Array(value: *Value) bool;

/// Check if a Value is a BigUint64Array
pub extern fn v8_Value_IsBigUint64Array(value: *Value) bool;

/// Check if a Value is any TypedArray
pub extern fn v8_Value_IsTypedArray(value: *Value) bool;

/// Check if a Value is a DataView
pub extern fn v8_Value_IsDataView(value: *Value) bool;

/// Get the underlying ArrayBuffer from a TypedArray
///
/// Returns a new Global<ArrayBuffer>* that must be disposed with v8_ArrayBuffer_Dispose.
///
/// @param typed_array - The TypedArray Value
/// @return ArrayBuffer handle, or null if not a TypedArray
pub extern fn v8_TypedArray_Buffer(typed_array: *Value) ?*ArrayBuffer;

/// Get the byte length of a TypedArray view
///
/// @param typed_array - The TypedArray Value
/// @return Byte length of the view, or 0 if invalid/detached
pub extern fn v8_TypedArray_ByteLength(typed_array: *Value) usize;

/// Get the byte offset of a TypedArray view
///
/// Returns the offset from the start of the underlying ArrayBuffer.
///
/// @param typed_array - The TypedArray Value
/// @return Byte offset, or 0 if invalid
pub extern fn v8_TypedArray_ByteOffset(typed_array: *Value) usize;

/// Get the element count of a TypedArray
///
/// Returns the number of elements (not bytes).
/// ByteLength = Length * ElementSize.
///
/// @param typed_array - The TypedArray Value
/// @return Element count, or 0 if invalid
pub extern fn v8_TypedArray_Length(typed_array: *Value) usize;

// ============================================================================
// TypedArray Construction
// ============================================================================

/// Create a Uint8Array view over an ArrayBuffer
///
/// @param isolate - V8 isolate
/// @param buffer - The ArrayBuffer to view
/// @param byte_offset - Offset into the buffer
/// @param length - Number of elements (bytes for Uint8Array)
/// @return Global handle to new Uint8Array, or null on error
pub extern fn v8_Uint8Array_New(isolate: *Isolate, buffer: *ArrayBuffer, byte_offset: usize, length: usize) ?*Value;

/// Create an Int8Array view over an ArrayBuffer
pub extern fn v8_Int8Array_New(isolate: *Isolate, buffer: *ArrayBuffer, byte_offset: usize, length: usize) ?*Value;

/// Create a Uint8ClampedArray view over an ArrayBuffer
pub extern fn v8_Uint8ClampedArray_New(isolate: *Isolate, buffer: *ArrayBuffer, byte_offset: usize, length: usize) ?*Value;

/// Create a Uint16Array view over an ArrayBuffer
pub extern fn v8_Uint16Array_New(isolate: *Isolate, buffer: *ArrayBuffer, byte_offset: usize, length: usize) ?*Value;

/// Create an Int16Array view over an ArrayBuffer
pub extern fn v8_Int16Array_New(isolate: *Isolate, buffer: *ArrayBuffer, byte_offset: usize, length: usize) ?*Value;

/// Create a Uint32Array view over an ArrayBuffer
pub extern fn v8_Uint32Array_New(isolate: *Isolate, buffer: *ArrayBuffer, byte_offset: usize, length: usize) ?*Value;

/// Create an Int32Array view over an ArrayBuffer
pub extern fn v8_Int32Array_New(isolate: *Isolate, buffer: *ArrayBuffer, byte_offset: usize, length: usize) ?*Value;

/// Create a Float32Array view over an ArrayBuffer
pub extern fn v8_Float32Array_New(isolate: *Isolate, buffer: *ArrayBuffer, byte_offset: usize, length: usize) ?*Value;

/// Create a Float64Array view over an ArrayBuffer
pub extern fn v8_Float64Array_New(isolate: *Isolate, buffer: *ArrayBuffer, byte_offset: usize, length: usize) ?*Value;

/// Create a BigInt64Array view over an ArrayBuffer
pub extern fn v8_BigInt64Array_New(isolate: *Isolate, buffer: *ArrayBuffer, byte_offset: usize, length: usize) ?*Value;

/// Create a BigUint64Array view over an ArrayBuffer
pub extern fn v8_BigUint64Array_New(isolate: *Isolate, buffer: *ArrayBuffer, byte_offset: usize, length: usize) ?*Value;

/// Create a DataView over an ArrayBuffer
pub extern fn v8_DataView_New(isolate: *Isolate, buffer: *ArrayBuffer, byte_offset: usize, byte_length: usize) ?*Value;

// ============================================================================
// Microtask Functions (Event Loop Integration)
// ============================================================================

/// Microtasks policy for isolate
pub const MicrotasksPolicy = enum(c_int) {
    /// Microtasks must be explicitly run via PerformMicrotaskCheckpoint
    Explicit = 0,
    /// Microtasks run automatically at the end of each MicrotasksScope
    Scoped = 1,
    /// Microtasks run automatically (deprecated, use Scoped)
    Auto = 2,
};

/// Enqueue a microtask callback
///
/// The callback will be invoked with the provided data pointer.
/// Caller is responsible for managing the lifetime of data.
///
/// Callback signature: void (*callback)(void* data)
pub extern fn v8_Isolate_EnqueueMicrotask(
    isolate: *Isolate,
    callback: ?*const anyopaque, // Function pointer passed as opaque
    data: ?*anyopaque,
) void;

/// Perform a microtask checkpoint
///
/// Runs all pending microtasks to completion.
pub extern fn v8_Isolate_PerformMicrotaskCheckpoint(isolate: *Isolate) void;

/// Set the microtasks policy for the isolate
pub extern fn v8_Isolate_SetMicrotasksPolicy(isolate: *Isolate, policy: c_int) void;

// ============================================================================
// External - Wrap C pointers for storage in V8
// ============================================================================

/// Create a new External value that wraps a C pointer
///
/// External values allow you to store arbitrary C pointers in V8 objects.
/// This is commonly used for callback user data.
///
/// Arguments:
///   isolate: The V8 isolate
///   value: Pointer to wrap (can be any C pointer)
///
/// Returns: External value, or null on failure
pub extern fn v8_External_New(isolate: *Isolate, value: ?*anyopaque) ?*External;

/// Extract the wrapped pointer from an External value
///
/// Arguments:
///   external: The External value
///
/// Returns: The wrapped pointer
pub extern fn v8_External_Value(external: *External) ?*anyopaque;

/// Dispose of an External value
pub extern fn v8_External_Dispose(external: *External) void;

// ============================================================================
// Weak Callbacks / Finalizers
// ============================================================================

/// Weak callback type for finalizers
///
/// Called when a V8 object is garbage collected. Used to clean up associated
/// native resources (like CallbackUserData).
///
/// Parameters:
///   data: User data pointer passed to SetWeak
///   length_in_bytes: Size estimate (unused in our case)
pub const WeakCallbackFn = *const fn (data: ?*anyopaque, length_in_bytes: usize) callconv(.c) void;

/// Make a Global handle weak and register a finalizer
///
/// When the V8 object is garbage collected, the finalizer will be called
/// with the provided data pointer. This is used to clean up native resources.
///
/// Arguments:
///   handle: The Global handle to make weak (Function, Object, etc.)
///   data: User data to pass to finalizer (e.g., CallbackUserData*)
///   callback: Finalizer function to call on GC
///
/// Note: The handle can be any Global<T>* since they're all opaque pointers
pub extern fn v8_Global_SetWeak(
    handle: *anyopaque,
    data: ?*anyopaque,
    callback: WeakCallbackFn,
) void;

/// Clear weak reference and restore strong reference
///
/// Arguments:
///   handle: The Global handle to make strong again
pub extern fn v8_Global_ClearWeak(handle: *anyopaque) void;

// ============================================================================
// Async Iterator Support
// ============================================================================

/// Zig async iterator next callback type
///
/// Called when JavaScript code calls iterator.next().
/// Should return a V8 Promise that resolves to { value, done }.
///
/// Parameters:
///   isolate: V8 isolate for creating promises
///   context: V8 context for promise creation
///   iterator_ptr: Opaque Zig iterator pointer
///
/// Returns:
///   V8 Promise that resolves to { value: any, done: boolean }
pub const ZigAsyncIteratorNextFn = *const fn (
    isolate: *Isolate,
    context: *Context,
    iterator_ptr: ?*anyopaque,
) callconv(.c) ?*Promise;

/// Zig async iterator return callback type (cleanup)
///
/// Called when JavaScript code calls iterator.return().
/// Should return a V8 Promise that resolves to { value: undefined, done: true }.
///
/// Parameters:
///   isolate: V8 isolate for creating promises
///   context: V8 context for promise creation
///   iterator_ptr: Opaque Zig iterator pointer
///
/// Returns:
///   V8 Promise that resolves to { value: undefined, done: true }
pub const ZigAsyncIteratorReturnFn = *const fn (
    isolate: *Isolate,
    context: *Context,
    iterator_ptr: ?*anyopaque,
) callconv(.c) ?*Promise;

/// Create a V8 async iterator object wrapping a Zig async iterator
///
/// Creates a JavaScript object with next() and return() methods that conform
/// to the ES async iterator protocol. The methods return Promises.
///
/// JavaScript Usage:
///   const result = await iterator.next(); // { value: ..., done: false }
///   await iterator.return(); // { value: undefined, done: true }
///
/// Arguments:
///   isolate: V8 isolate
///   context: V8 context for creating the object
///   iterator_ptr: Opaque Zig iterator pointer (stored in object)
///   next_fn: Zig callback for next() -> Promise<{ value, done }>
///   return_fn: Zig callback for return() -> Promise<{ value, done }>
///
/// Returns:
///   V8 Object with next() and return() methods (Global handle)
pub extern fn v8_AsyncIterator_New(
    isolate: *Isolate,
    context: *Context,
    iterator_ptr: ?*anyopaque,
    next_fn: ZigAsyncIteratorNextFn,
    return_fn: ZigAsyncIteratorReturnFn,
) ?*Object;

/// Dispose an async iterator object and free its internal data
///
/// Cleans up the AsyncIteratorData stored in the object's internal field.
///
/// Arguments:
///   iterator: The async iterator object to dispose (Global handle)
pub extern fn v8_AsyncIterator_Dispose(iterator: *Object) void;

/// Clear the async iterator template cache
///
/// MUST be called before disposing an isolate to prevent use-after-free crashes.
/// V8 FunctionTemplates are bound to specific isolates and cannot be reused
/// across isolate boundaries. Failure to clear this cache before disposing
/// an isolate and creating a new one will cause crashes when the stale
/// template pointer is dereferenced.
pub extern fn v8_ClearAsyncIteratorTemplateCache() void;

/// Clear the module resolve callback
/// MUST be called before disposing an isolate to prevent use-after-free crashes.
/// The user_data pointer becomes invalid when the Zig runtime is deinitialized.
pub extern fn v8_ClearModuleResolveCallback() void;

/// Clear the dynamic import callback
/// MUST be called before disposing an isolate to prevent use-after-free crashes.
/// The user_data pointer becomes invalid when the Zig runtime is deinitialized.
pub extern fn v8_ClearDynamicImportCallback() void;
