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
pub extern fn v8_ObjectTemplate_SetAccessorProperty(
    self: *ObjectTemplate,
    name: *String,
    getter: ?AccessorGetterCallback,
    setter: ?AccessorSetterCallback,
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
pub extern fn v8_Isolate_ThrowException(isolate: *Isolate, exception: *Value) void;

// Isolate embedder data (for storing per-isolate state)
pub extern fn v8_Isolate_SetData(isolate: *Isolate, slot: c_int, data: ?*anyopaque) void;
pub extern fn v8_Isolate_GetData(isolate: *Isolate, slot: c_int) ?*anyopaque;

// Context management
pub extern fn v8_Context_New(isolate: *Isolate) ?*Context;
pub extern fn v8_Context_Dispose(context: *Context) void;
pub extern fn v8_Context_Enter(context: *Context) void;
pub extern fn v8_Context_Exit(context: *Context) void;
pub extern fn v8_Context_Global(context: *Context) ?*Object;

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
pub extern fn v8_Value_IsObject(value: *Value) bool;
pub extern fn v8_Value_IsArray(value: *Value) bool;
pub extern fn v8_Value_BooleanValue(value: *Value, isolate: *Isolate) bool;
pub extern fn v8_Value_NumberValue(value: *Value, context: *Context) f64;
pub extern fn v8_Value_Int32Value(value: *Value, context: *Context) i32;
pub extern fn v8_Value_Uint32Value(value: *Value, context: *Context) u32;
pub extern fn v8_Value_IntegerValue(value: *Value, context: *Context) i64;
pub extern fn v8_Value_ToString(value: *Value, context: *Context) ?*String;
pub extern fn v8_Value_Dispose(value: *Value) void;

// Name Functions
pub extern fn v8_Name_IsString(name: *Name) bool;

// String Functions (for raw pointers from callbacks)
pub extern fn v8_String_Utf8Length_Raw(str: *const String) c_int;
pub extern fn v8_String_WriteUtf8_Raw(str: *const String, buffer: [*]u8, length: c_int) c_int;

// Object operations
pub extern fn v8_Object_New(isolate: *Isolate) ?*Object;
pub extern fn v8_Object_Set(object: *Object, context: *Context, key: *Value, value: *Value) bool;
pub extern fn v8_Object_Get(object: *Object, context: *Context, key: *Value) ?*Value;
pub extern fn v8_Object_GetOwnPropertyNames(context: *Context, obj: *Object) ?*Array;
pub extern fn v8_Object_GetPropertyNames(context: *Context, obj: *Object) ?*Array;
pub extern fn v8_Object_SetAlignedPointerInInternalField(object: *Object, index: c_int, value: *anyopaque) void;
pub extern fn v8_Object_GetAlignedPointerFromInternalField(object: *Object, index: c_int) ?*anyopaque;
pub extern fn v8_Object_Dispose(obj: *Object) void;
pub extern fn v8_Object_DefineProperty(object: *Object, context: *Context, key: *Value, value: *Value, writable: bool, enumerable: bool, configurable: bool) bool;
pub extern fn v8_Object_PreventExtensions(object: *Object, context: *Context) bool;

// Array operations
pub extern fn v8_Array_New(isolate: *Isolate, length: c_int) *Array;
pub extern fn v8_Array_Length(arr: *Array) u32;
pub extern fn v8_Array_Get(context: *Context, arr: *Array, index: u32) ?*Value;
pub extern fn v8_Array_Set(arr: *Array, context: *Context, index: u32, value: *Value) bool;
pub extern fn v8_Array_Dispose(arr: *Array) void;

// Script compilation and execution
pub extern fn v8_Script_Compile(context: *Context, source: *String) ?*Script;
pub extern fn v8_Script_Run(context: *Context, script: *Script) ?*Value;
pub extern fn v8_Script_Dispose(script: *Script) void;

// Exception handling
pub extern fn v8_Exception_TypeError(message: *String) ?*Value;
pub extern fn v8_Exception_RangeError(message: *String) ?*Value;
pub extern fn v8_Exception_Error(message: *String) ?*Value;
pub extern fn v8_TryCatch_Exception(context: *Context) ?*Value;

// Special values
pub extern fn v8_Undefined(isolate: *Isolate) ?*Value;
pub extern fn v8_Null(isolate: *Isolate) ?*Value;

// Number creation
pub extern fn v8_Number_New(isolate: *Isolate, value: f64) *Number;
pub extern fn v8_Integer_New(isolate: *Isolate, value: i32) *Number;

// FunctionTemplate (for namespace and interface bindings)
pub extern fn v8_FunctionTemplate_New(isolate: *Isolate, callback: ?FunctionCallback, data: ?*Value) ?*FunctionTemplate;
pub extern fn v8_FunctionTemplate_GetFunction(function_template: *FunctionTemplate, context: *Context) ?*Function;
pub extern fn v8_FunctionTemplate_Dispose(tpl: *FunctionTemplate) void;
pub extern fn v8_FunctionTemplate_SetClassName(tpl: *FunctionTemplate, name: *String) void;
pub extern fn v8_FunctionTemplate_InstanceTemplate(tpl: *FunctionTemplate) *ObjectTemplate;
pub extern fn v8_FunctionTemplate_PrototypeTemplate(tpl: *FunctionTemplate) *ObjectTemplate;
pub extern fn v8_FunctionTemplate_Inherit(tpl: *FunctionTemplate, parent: *FunctionTemplate) void;
pub extern fn v8_FunctionTemplate_SetLength(tpl: *FunctionTemplate, length: c_int) void;

// Function
pub extern fn v8_Function_Dispose(fn_ptr: *Function) void;
