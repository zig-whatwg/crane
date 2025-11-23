//! V8 FFI Interface Layer
//!
//! Provides extern function declarations and type definitions for the V8 C API.
//! This layer can be linked to real V8 when available, or used with a mock implementation.
//!
//! ## Conditional Compilation
//!
//! Set `use_real_v8 = true` to link against real V8.
//! When false, uses mock implementations for testing and development.
//!
//! ## V8 C API Reference
//!
//! Based on V8's C API (v8-c.h):
//! - https://chromium.googlesource.com/v8/v8/+/refs/heads/main/include/v8-c.h
//! - Minimal subset needed for WebIDL bindings
//!
//! ## Usage
//!
//! ```zig
//! const v8 = @import("ffi.zig");
//!
//! // Create isolate
//! const isolate = v8.v8_Isolate_New(null);
//! defer v8.v8_Isolate_Dispose(isolate);
//!
//! // Create context
//! const context = v8.v8_Context_New(isolate);
//! defer v8.v8_Context_Dispose(context);
//! ```

const std = @import("std");

/// Use real V8 C API or mock implementation
pub const use_real_v8 = false;

// ============================================================================
// V8 Opaque Types
// ============================================================================

/// V8 Isolate - represents an isolated instance of the V8 engine
pub const v8_Isolate = opaque {};

/// V8 Context - represents a JavaScript execution context
pub const v8_Context = opaque {};

/// V8 Value - base type for all JavaScript values
pub const v8_Value = opaque {};

/// V8 Object - JavaScript object
pub const v8_Object = opaque {};

/// V8 Array - JavaScript array
pub const v8_Array = opaque {};

/// V8 String - JavaScript string
pub const v8_String = opaque {};

/// V8 Number - JavaScript number
pub const v8_Number = opaque {};

/// V8 Boolean - JavaScript boolean
pub const v8_Boolean = opaque {};

/// V8 Function - JavaScript function
pub const v8_Function = opaque {};

/// V8 FunctionTemplate - template for creating functions
pub const v8_FunctionTemplate = opaque {};

/// V8 ObjectTemplate - template for creating objects
pub const v8_ObjectTemplate = opaque {};

/// V8 External - wrapper for native pointers
pub const v8_External = opaque {};

// ============================================================================
// V8 Callback Types
// ============================================================================

/// Function callback info
pub const v8_FunctionCallbackInfo = opaque {};

/// Property callback info
pub const v8_PropertyCallbackInfo = opaque {};

/// Function callback type
pub const v8_FunctionCallback = *const fn (info: *const v8_FunctionCallbackInfo) callconv(.C) void;

/// Property getter callback type
pub const v8_AccessorGetterCallback = *const fn (
    property: *v8_String,
    info: *const v8_PropertyCallbackInfo,
) callconv(.C) void;

/// Property setter callback type
pub const v8_AccessorSetterCallback = *const fn (
    property: *v8_String,
    value: *v8_Value,
    info: *const v8_PropertyCallbackInfo,
) callconv(.C) void;

// ============================================================================
// V8 Isolate Functions
// ============================================================================

/// Create a new V8 isolate
pub extern fn v8_Isolate_New(params: ?*anyopaque) ?*v8_Isolate;

/// Dispose of a V8 isolate
pub extern fn v8_Isolate_Dispose(isolate: *v8_Isolate) void;

/// Enter an isolate (required before any operations)
pub extern fn v8_Isolate_Enter(isolate: *v8_Isolate) void;

/// Exit an isolate
pub extern fn v8_Isolate_Exit(isolate: *v8_Isolate) void;

/// Get current context from isolate
pub extern fn v8_Isolate_GetCurrentContext(isolate: *v8_Isolate) ?*v8_Context;

// ============================================================================
// V8 Context Functions
// ============================================================================

/// Create a new V8 context
pub extern fn v8_Context_New(isolate: *v8_Isolate) ?*v8_Context;

/// Dispose of a V8 context
pub extern fn v8_Context_Dispose(context: *v8_Context) void;

/// Enter a context
pub extern fn v8_Context_Enter(context: *v8_Context) void;

/// Exit a context
pub extern fn v8_Context_Exit(context: *v8_Context) void;

/// Get global object from context
pub extern fn v8_Context_Global(context: *v8_Context) *v8_Object;

/// Get isolate from context
pub extern fn v8_Context_GetIsolate(context: *v8_Context) *v8_Isolate;

// ============================================================================
// V8 Value Functions
// ============================================================================

/// Check if value is undefined
pub extern fn v8_Value_IsUndefined(value: *const v8_Value) bool;

/// Check if value is null
pub extern fn v8_Value_IsNull(value: *const v8_Value) bool;

/// Check if value is boolean
pub extern fn v8_Value_IsBoolean(value: *const v8_Value) bool;

/// Check if value is number
pub extern fn v8_Value_IsNumber(value: *const v8_Value) bool;

/// Check if value is string
pub extern fn v8_Value_IsString(value: *const v8_Value) bool;

/// Check if value is object
pub extern fn v8_Value_IsObject(value: *const v8_Value) bool;

/// Check if value is array
pub extern fn v8_Value_IsArray(value: *const v8_Value) bool;

/// Check if value is function
pub extern fn v8_Value_IsFunction(value: *const v8_Value) bool;

// ============================================================================
// V8 Primitive Creation Functions
// ============================================================================

/// Create undefined value
pub extern fn v8_Undefined(isolate: *v8_Isolate) *v8_Value;

/// Create null value
pub extern fn v8_Null(isolate: *v8_Isolate) *v8_Value;

/// Create boolean value
pub extern fn v8_Boolean_New(isolate: *v8_Isolate, value: bool) *v8_Boolean;

/// Create integer value
pub extern fn v8_Integer_New(isolate: *v8_Isolate, value: i32) *v8_Number;

/// Create number value
pub extern fn v8_Number_New(isolate: *v8_Isolate, value: f64) *v8_Number;

/// Create string from UTF-8
pub extern fn v8_String_NewFromUtf8(
    isolate: *v8_Isolate,
    data: [*]const u8,
    length: c_int,
) ?*v8_String;

// ============================================================================
// V8 Object Functions
// ============================================================================

/// Create new object
pub extern fn v8_Object_New(isolate: *v8_Isolate) *v8_Object;

/// Set property on object
pub extern fn v8_Object_Set(
    object: *v8_Object,
    context: *v8_Context,
    key: *v8_Value,
    value: *v8_Value,
) bool;

/// Get property from object
pub extern fn v8_Object_Get(
    object: *v8_Object,
    context: *v8_Context,
    key: *v8_Value,
) ?*v8_Value;

/// Set internal field (for storing native pointers)
pub extern fn v8_Object_SetInternalField(
    object: *v8_Object,
    index: c_int,
    value: *v8_Value,
) void;

/// Get internal field
pub extern fn v8_Object_GetInternalField(
    object: *v8_Object,
    index: c_int,
) ?*v8_Value;

/// Get number of internal fields
pub extern fn v8_Object_InternalFieldCount(object: *const v8_Object) c_int;

// ============================================================================
// V8 Array Functions
// ============================================================================

/// Create new array
pub extern fn v8_Array_New(isolate: *v8_Isolate, length: c_int) *v8_Array;

/// Get array length
pub extern fn v8_Array_Length(array: *const v8_Array) u32;

// ============================================================================
// V8 External Functions (for wrapping native pointers)
// ============================================================================

/// Wrap native pointer in V8 External
pub extern fn v8_External_New(isolate: *v8_Isolate, value: *anyopaque) *v8_External;

/// Unwrap native pointer from V8 External
pub extern fn v8_External_Value(external: *v8_External) *anyopaque;

// ============================================================================
// V8 FunctionTemplate Functions
// ============================================================================

/// Create function template
pub extern fn v8_FunctionTemplate_New(
    isolate: *v8_Isolate,
    callback: ?v8_FunctionCallback,
) *v8_FunctionTemplate;

/// Get function from template
pub extern fn v8_FunctionTemplate_GetFunction(
    template: *v8_FunctionTemplate,
    context: *v8_Context,
) ?*v8_Function;

/// Set class name
pub extern fn v8_FunctionTemplate_SetClassName(
    template: *v8_FunctionTemplate,
    name: *v8_String,
) void;

/// Get instance template
pub extern fn v8_FunctionTemplate_InstanceTemplate(
    template: *v8_FunctionTemplate,
) *v8_ObjectTemplate;

/// Get prototype template
pub extern fn v8_FunctionTemplate_PrototypeTemplate(
    template: *v8_FunctionTemplate,
) *v8_ObjectTemplate;

/// Inherit from parent template
pub extern fn v8_FunctionTemplate_Inherit(
    template: *v8_FunctionTemplate,
    parent: *v8_FunctionTemplate,
) void;

// ============================================================================
// V8 ObjectTemplate Functions
// ============================================================================

/// Create object template
pub extern fn v8_ObjectTemplate_New(isolate: *v8_Isolate) *v8_ObjectTemplate;

/// Set internal field count
pub extern fn v8_ObjectTemplate_SetInternalFieldCount(
    template: *v8_ObjectTemplate,
    count: c_int,
) void;

/// Set accessor (property getter/setter)
pub extern fn v8_ObjectTemplate_SetAccessor(
    template: *v8_ObjectTemplate,
    name: *v8_String,
    getter: ?v8_AccessorGetterCallback,
    setter: ?v8_AccessorSetterCallback,
) void;

/// Set method
pub extern fn v8_ObjectTemplate_Set(
    template: *v8_ObjectTemplate,
    name: *v8_String,
    value: *v8_Value,
) void;

// ============================================================================
// V8 Callback Info Functions
// ============================================================================

/// Get isolate from callback info
pub extern fn v8_FunctionCallbackInfo_GetIsolate(
    info: *const v8_FunctionCallbackInfo,
) *v8_Isolate;

/// Get 'this' object from callback info
pub extern fn v8_FunctionCallbackInfo_This(
    info: *const v8_FunctionCallbackInfo,
) *v8_Object;

/// Get argument count
pub extern fn v8_FunctionCallbackInfo_Length(
    info: *const v8_FunctionCallbackInfo,
) c_int;

/// Get argument at index
pub extern fn v8_FunctionCallbackInfo_GetArgument(
    info: *const v8_FunctionCallbackInfo,
    index: c_int,
) *v8_Value;

/// Set return value
pub extern fn v8_FunctionCallbackInfo_GetReturnValue(
    info: *const v8_FunctionCallbackInfo,
) *v8_Value;

/// Get holder object from property callback info
pub extern fn v8_PropertyCallbackInfo_Holder(
    info: *const v8_PropertyCallbackInfo,
) *v8_Object;

/// Get isolate from property callback info
pub extern fn v8_PropertyCallbackInfo_GetIsolate(
    info: *const v8_PropertyCallbackInfo,
) *v8_Isolate;

// ============================================================================
// V8 Conversion Functions
// ============================================================================

/// Get boolean value
pub extern fn v8_Boolean_Value(boolean: *v8_Boolean) bool;

/// Get integer value
pub extern fn v8_Integer_Value(number: *v8_Number) i64;

/// Get number value
pub extern fn v8_Number_Value(number: *v8_Number) f64;

/// Get UTF-8 length
pub extern fn v8_String_Utf8Length(string: *v8_String, isolate: *v8_Isolate) c_int;

/// Write UTF-8 to buffer
pub extern fn v8_String_WriteUtf8(
    string: *v8_String,
    isolate: *v8_Isolate,
    buffer: [*]u8,
    length: c_int,
) c_int;

// ============================================================================
// V8 Exception Functions
// ============================================================================

/// Create TypeError
pub extern fn v8_Exception_TypeError(message: *v8_String) *v8_Value;

/// Create RangeError
pub extern fn v8_Exception_RangeError(message: *v8_String) *v8_Value;

/// Create SyntaxError
pub extern fn v8_Exception_SyntaxError(message: *v8_String) *v8_Value;

/// Create ReferenceError
pub extern fn v8_Exception_ReferenceError(message: *v8_String) *v8_Value;

/// Create generic Error
pub extern fn v8_Exception_Error(message: *v8_String) *v8_Value;

// ============================================================================
// Type Casting (safe casts between V8 types)
// ============================================================================

/// Cast Value to Object
pub fn valueToObject(value: *v8_Value) *v8_Object {
    return @ptrCast(value);
}

/// Cast Value to Array
pub fn valueToArray(value: *v8_Value) *v8_Array {
    return @ptrCast(value);
}

/// Cast Value to String
pub fn valueToString(value: *v8_Value) *v8_String {
    return @ptrCast(value);
}

/// Cast Value to Number
pub fn valueToNumber(value: *v8_Value) *v8_Number {
    return @ptrCast(value);
}

/// Cast Value to Boolean
pub fn valueToBoolean(value: *v8_Value) *v8_Boolean {
    return @ptrCast(value);
}

/// Cast Value to Function
pub fn valueToFunction(value: *v8_Value) *v8_Function {
    return @ptrCast(value);
}

/// Cast Value to External
pub fn valueToExternal(value: *v8_Value) *v8_External {
    return @ptrCast(value);
}

/// Cast Object to Value
pub fn objectToValue(object: *v8_Object) *v8_Value {
    return @ptrCast(object);
}

/// Cast Array to Value
pub fn arrayToValue(array: *v8_Array) *v8_Value {
    return @ptrCast(array);
}

/// Cast String to Value
pub fn stringToValue(string: *v8_String) *v8_Value {
    return @ptrCast(string);
}

/// Cast Number to Value
pub fn numberToValue(number: *v8_Number) *v8_Value {
    return @ptrCast(number);
}

/// Cast Boolean to Value
pub fn booleanToValue(boolean: *v8_Boolean) *v8_Value {
    return @ptrCast(boolean);
}

/// Cast Function to Value
pub fn functionToValue(function: *v8_Function) *v8_Value {
    return @ptrCast(function);
}

/// Cast External to Value
pub fn externalToValue(external: *v8_External) *v8_Value {
    return @ptrCast(external);
}
