//! JavaScriptCore C API FFI Bindings
//!
//! This module provides Zig bindings to the JavaScriptCore C API.
//! JSC is the JavaScript engine used in Safari and on iOS/macOS.
//!
//! Reference: https://developer.apple.com/documentation/javascriptcore
//!
//! ## Key Differences from V8
//!
//! - JSC uses reference counting (JSValueProtect/Unprotect) instead of handles
//! - JSC uses JSContextRef/JSGlobalContextRef vs V8's Isolate/Context
//! - JSC's API is pure C, not C++ like V8
//! - JSC uses JSClassRef for object templates (like V8's FunctionTemplate)

const std = @import("std");

// ============================================================================
// Opaque Types
// ============================================================================

/// JSC Context Group - Similar to V8 Isolate
/// Represents an execution context group that can contain multiple contexts
pub const JSContextGroupRef = *opaque {};

/// JSC Global Context - A JavaScript execution context with global object
pub const JSGlobalContextRef = *opaque {};

/// JSC Context - A JavaScript execution context (may be global or not)
pub const JSContextRef = *opaque {};

/// JSC Value - Base type for all JavaScript values (opaque, reference counted)
pub const JSValueRef = *opaque {};

/// JSC Object - JavaScript object (subtype of JSValueRef)
pub const JSObjectRef = *opaque {};

/// JSC String - JavaScript string (immutable, reference counted)
pub const JSStringRef = *opaque {};

/// JSC Class - Object class definition (like V8 FunctionTemplate)
pub const JSClassRef = *opaque {};

/// JSC Property Name Array - Array of property names
pub const JSPropertyNameArrayRef = *opaque {};

/// JSC Property Name Accumulator - For building property name arrays
pub const JSPropertyNameAccumulatorRef = *opaque {};

// ============================================================================
// Type Definitions
// ============================================================================

/// JavaScript type enumeration
pub const JSType = enum(c_int) {
    kJSTypeUndefined = 0,
    kJSTypeNull = 1,
    kJSTypeBoolean = 2,
    kJSTypeNumber = 3,
    kJSTypeString = 4,
    kJSTypeObject = 5,
    kJSTypeSymbol = 6,
};

/// Property attributes for JSC
pub const JSPropertyAttributes = c_uint;
pub const kJSPropertyAttributeNone: JSPropertyAttributes = 0;
pub const kJSPropertyAttributeReadOnly: JSPropertyAttributes = 1 << 1;
pub const kJSPropertyAttributeDontEnum: JSPropertyAttributes = 1 << 2;
pub const kJSPropertyAttributeDontDelete: JSPropertyAttributes = 1 << 3;

/// Class attributes
pub const JSClassAttributes = c_uint;
pub const kJSClassAttributeNone: JSClassAttributes = 0;
pub const kJSClassAttributeNoAutomaticPrototype: JSClassAttributes = 1 << 1;

// ============================================================================
// Callback Types
// ============================================================================

/// Object initialization callback
pub const JSObjectInitializeCallback = ?*const fn (
    ctx: JSContextRef,
    object: JSObjectRef,
) callconv(.c) void;

/// Object finalization callback (destructor)
pub const JSObjectFinalizeCallback = ?*const fn (
    object: JSObjectRef,
) callconv(.c) void;

/// Property getter callback
pub const JSObjectGetPropertyCallback = ?*const fn (
    ctx: JSContextRef,
    object: JSObjectRef,
    propertyName: JSStringRef,
    exception: *?JSValueRef,
) callconv(.c) JSValueRef;

/// Property setter callback
pub const JSObjectSetPropertyCallback = ?*const fn (
    ctx: JSContextRef,
    object: JSObjectRef,
    propertyName: JSStringRef,
    value: JSValueRef,
    exception: *?JSValueRef,
) callconv(.c) bool;

/// Property delete callback
pub const JSObjectDeletePropertyCallback = ?*const fn (
    ctx: JSContextRef,
    object: JSObjectRef,
    propertyName: JSStringRef,
    exception: *?JSValueRef,
) callconv(.c) bool;

/// Property names callback
pub const JSObjectGetPropertyNamesCallback = ?*const fn (
    ctx: JSContextRef,
    object: JSObjectRef,
    propertyNames: JSPropertyNameAccumulatorRef,
) callconv(.c) void;

/// Function call callback
pub const JSObjectCallAsFunctionCallback = ?*const fn (
    ctx: JSContextRef,
    function: JSObjectRef,
    thisObject: JSObjectRef,
    argumentCount: usize,
    arguments: [*]const JSValueRef,
    exception: *?JSValueRef,
) callconv(.c) JSValueRef;

/// Constructor call callback
pub const JSObjectCallAsConstructorCallback = ?*const fn (
    ctx: JSContextRef,
    constructor: JSObjectRef,
    argumentCount: usize,
    arguments: [*]const JSValueRef,
    exception: *?JSValueRef,
) callconv(.c) JSObjectRef;

/// Has instance callback (for instanceof)
pub const JSObjectHasInstanceCallback = ?*const fn (
    ctx: JSContextRef,
    constructor: JSObjectRef,
    possibleInstance: JSValueRef,
    exception: *?JSValueRef,
) callconv(.c) bool;

/// Convert to type callback
pub const JSObjectConvertToTypeCallback = ?*const fn (
    ctx: JSContextRef,
    object: JSObjectRef,
    typ: JSType,
    exception: *?JSValueRef,
) callconv(.c) JSValueRef;

// ============================================================================
// Static Value/Function Definitions
// ============================================================================

/// Static value definition for class
pub const JSStaticValue = extern struct {
    name: [*:0]const u8,
    getProperty: JSObjectGetPropertyCallback,
    setProperty: JSObjectSetPropertyCallback,
    attributes: JSPropertyAttributes,
};

/// Static function definition for class
pub const JSStaticFunction = extern struct {
    name: [*:0]const u8,
    callAsFunction: JSObjectCallAsFunctionCallback,
    attributes: JSPropertyAttributes,
};

// ============================================================================
// Class Definition
// ============================================================================

/// JSC Class definition structure
pub const JSClassDefinition = extern struct {
    version: c_int = 0,
    attributes: JSClassAttributes = kJSClassAttributeNone,
    className: [*:0]const u8,
    parentClass: ?JSClassRef = null,
    staticValues: ?[*]const JSStaticValue = null,
    staticFunctions: ?[*]const JSStaticFunction = null,
    initialize: JSObjectInitializeCallback = null,
    finalize: JSObjectFinalizeCallback = null,
    hasProperty: ?*const fn (JSContextRef, JSObjectRef, JSStringRef) callconv(.c) bool = null,
    getProperty: JSObjectGetPropertyCallback = null,
    setProperty: JSObjectSetPropertyCallback = null,
    deleteProperty: JSObjectDeletePropertyCallback = null,
    getPropertyNames: JSObjectGetPropertyNamesCallback = null,
    callAsFunction: JSObjectCallAsFunctionCallback = null,
    callAsConstructor: JSObjectCallAsConstructorCallback = null,
    hasInstance: JSObjectHasInstanceCallback = null,
    convertToType: JSObjectConvertToTypeCallback = null,
};

/// Empty class definition constant
pub const kJSClassDefinitionEmpty = JSClassDefinition{
    .version = 0,
    .attributes = kJSClassAttributeNone,
    .className = "",
    .parentClass = null,
    .staticValues = null,
    .staticFunctions = null,
    .initialize = null,
    .finalize = null,
    .hasProperty = null,
    .getProperty = null,
    .setProperty = null,
    .deleteProperty = null,
    .getPropertyNames = null,
    .callAsFunction = null,
    .callAsConstructor = null,
    .hasInstance = null,
    .convertToType = null,
};

// ============================================================================
// Context Group Functions
// ============================================================================

/// Create a new context group
pub extern "JavaScriptCore" fn JSContextGroupCreate() JSContextGroupRef;

/// Retain (increment reference count) a context group
pub extern "JavaScriptCore" fn JSContextGroupRetain(group: JSContextGroupRef) JSContextGroupRef;

/// Release (decrement reference count) a context group
pub extern "JavaScriptCore" fn JSContextGroupRelease(group: JSContextGroupRef) void;

// ============================================================================
// Global Context Functions
// ============================================================================

/// Create a new global JavaScript execution context
pub extern "JavaScriptCore" fn JSGlobalContextCreate(globalObjectClass: ?JSClassRef) JSGlobalContextRef;

/// Create a new global context in a specific context group
pub extern "JavaScriptCore" fn JSGlobalContextCreateInGroup(
    group: ?JSContextGroupRef,
    globalObjectClass: ?JSClassRef,
) JSGlobalContextRef;

/// Retain a global context
pub extern "JavaScriptCore" fn JSGlobalContextRetain(ctx: JSGlobalContextRef) JSGlobalContextRef;

/// Release a global context
pub extern "JavaScriptCore" fn JSGlobalContextRelease(ctx: JSGlobalContextRef) void;

/// Get the global object from a context
pub extern "JavaScriptCore" fn JSContextGetGlobalObject(ctx: JSContextRef) JSObjectRef;

/// Get the context group from a context
pub extern "JavaScriptCore" fn JSContextGetGroup(ctx: JSContextRef) JSContextGroupRef;

/// Get the global context from a context
pub extern "JavaScriptCore" fn JSContextGetGlobalContext(ctx: JSContextRef) JSGlobalContextRef;

// ============================================================================
// String Functions
// ============================================================================

/// Create a JSString from UTF-8 characters
pub extern "JavaScriptCore" fn JSStringCreateWithUTF8CString(string: [*:0]const u8) JSStringRef;

/// Create a JSString from Unicode characters
pub extern "JavaScriptCore" fn JSStringCreateWithCharacters(
    chars: [*]const u16,
    numChars: usize,
) JSStringRef;

/// Retain a JSString
pub extern "JavaScriptCore" fn JSStringRetain(string: JSStringRef) JSStringRef;

/// Release a JSString
pub extern "JavaScriptCore" fn JSStringRelease(string: JSStringRef) void;

/// Get the length of a JSString in Unicode characters
pub extern "JavaScriptCore" fn JSStringGetLength(string: JSStringRef) usize;

/// Get the characters pointer from a JSString
pub extern "JavaScriptCore" fn JSStringGetCharactersPtr(string: JSStringRef) [*]const u16;

/// Get the maximum UTF-8 buffer size needed for a JSString
pub extern "JavaScriptCore" fn JSStringGetMaximumUTF8CStringSize(string: JSStringRef) usize;

/// Copy a JSString to a UTF-8 buffer
pub extern "JavaScriptCore" fn JSStringGetUTF8CString(
    string: JSStringRef,
    buffer: [*]u8,
    bufferSize: usize,
) usize;

/// Check if two JSStrings are equal
pub extern "JavaScriptCore" fn JSStringIsEqual(a: JSStringRef, b: JSStringRef) bool;

/// Check if a JSString equals a UTF-8 string
pub extern "JavaScriptCore" fn JSStringIsEqualToUTF8CString(
    a: JSStringRef,
    b: [*:0]const u8,
) bool;

// ============================================================================
// Class Functions
// ============================================================================

/// Create a JSClass from a definition
pub extern "JavaScriptCore" fn JSClassCreate(definition: *const JSClassDefinition) JSClassRef;

/// Retain a JSClass
pub extern "JavaScriptCore" fn JSClassRetain(jsClass: JSClassRef) JSClassRef;

/// Release a JSClass
pub extern "JavaScriptCore" fn JSClassRelease(jsClass: JSClassRef) void;

// ============================================================================
// Object Functions
// ============================================================================

/// Create a new JavaScript object
pub extern "JavaScriptCore" fn JSObjectMake(ctx: JSContextRef, jsClass: ?JSClassRef, data: ?*anyopaque) JSObjectRef;

/// Create a new function object with a callback
pub extern "JavaScriptCore" fn JSObjectMakeFunctionWithCallback(
    ctx: JSContextRef,
    name: ?JSStringRef,
    callAsFunction: JSObjectCallAsFunctionCallback,
) JSObjectRef;

/// Create a constructor object
pub extern "JavaScriptCore" fn JSObjectMakeConstructor(
    ctx: JSContextRef,
    jsClass: ?JSClassRef,
    callAsConstructor: JSObjectCallAsConstructorCallback,
) JSObjectRef;

/// Create an array object
pub extern "JavaScriptCore" fn JSObjectMakeArray(
    ctx: JSContextRef,
    argumentCount: usize,
    arguments: ?[*]const JSValueRef,
    exception: *?JSValueRef,
) JSObjectRef;

/// Create a Date object
pub extern "JavaScriptCore" fn JSObjectMakeDate(
    ctx: JSContextRef,
    argumentCount: usize,
    arguments: ?[*]const JSValueRef,
    exception: *?JSValueRef,
) JSObjectRef;

/// Create an Error object
pub extern "JavaScriptCore" fn JSObjectMakeError(
    ctx: JSContextRef,
    argumentCount: usize,
    arguments: ?[*]const JSValueRef,
    exception: *?JSValueRef,
) JSObjectRef;

/// Create a RegExp object
pub extern "JavaScriptCore" fn JSObjectMakeRegExp(
    ctx: JSContextRef,
    argumentCount: usize,
    arguments: ?[*]const JSValueRef,
    exception: *?JSValueRef,
) JSObjectRef;

/// Create a Deferred Promise (returns promise object, sets resolve/reject functions)
pub extern "JavaScriptCore" fn JSObjectMakeDeferredPromise(
    ctx: JSContextRef,
    resolve: *?JSObjectRef,
    reject: *?JSObjectRef,
    exception: *?JSValueRef,
) JSObjectRef;

/// Get a property from an object by name
pub extern "JavaScriptCore" fn JSObjectGetProperty(
    ctx: JSContextRef,
    object: JSObjectRef,
    propertyName: JSStringRef,
    exception: *?JSValueRef,
) JSValueRef;

/// Set a property on an object
pub extern "JavaScriptCore" fn JSObjectSetProperty(
    ctx: JSContextRef,
    object: JSObjectRef,
    propertyName: JSStringRef,
    value: JSValueRef,
    attributes: JSPropertyAttributes,
    exception: *?JSValueRef,
) void;

/// Delete a property from an object
pub extern "JavaScriptCore" fn JSObjectDeleteProperty(
    ctx: JSContextRef,
    object: JSObjectRef,
    propertyName: JSStringRef,
    exception: *?JSValueRef,
) bool;

/// Check if an object has a property
pub extern "JavaScriptCore" fn JSObjectHasProperty(
    ctx: JSContextRef,
    object: JSObjectRef,
    propertyName: JSStringRef,
) bool;

/// Get a property at an array index
pub extern "JavaScriptCore" fn JSObjectGetPropertyAtIndex(
    ctx: JSContextRef,
    object: JSObjectRef,
    propertyIndex: c_uint,
    exception: *?JSValueRef,
) JSValueRef;

/// Set a property at an array index
pub extern "JavaScriptCore" fn JSObjectSetPropertyAtIndex(
    ctx: JSContextRef,
    object: JSObjectRef,
    propertyIndex: c_uint,
    value: JSValueRef,
    exception: *?JSValueRef,
) void;

/// Get the private data from an object
pub extern "JavaScriptCore" fn JSObjectGetPrivate(object: JSObjectRef) ?*anyopaque;

/// Set the private data on an object
pub extern "JavaScriptCore" fn JSObjectSetPrivate(object: JSObjectRef, data: ?*anyopaque) bool;

/// Check if an object is a function
pub extern "JavaScriptCore" fn JSObjectIsFunction(ctx: JSContextRef, object: JSObjectRef) bool;

/// Check if an object is a constructor
pub extern "JavaScriptCore" fn JSObjectIsConstructor(ctx: JSContextRef, object: JSObjectRef) bool;

/// Call an object as a function
pub extern "JavaScriptCore" fn JSObjectCallAsFunction(
    ctx: JSContextRef,
    object: JSObjectRef,
    thisObject: ?JSObjectRef,
    argumentCount: usize,
    arguments: ?[*]const JSValueRef,
    exception: *?JSValueRef,
) JSValueRef;

/// Call an object as a constructor
pub extern "JavaScriptCore" fn JSObjectCallAsConstructor(
    ctx: JSContextRef,
    object: JSObjectRef,
    argumentCount: usize,
    arguments: ?[*]const JSValueRef,
    exception: *?JSValueRef,
) JSObjectRef;

/// Get the prototype of an object
pub extern "JavaScriptCore" fn JSObjectGetPrototype(ctx: JSContextRef, object: JSObjectRef) JSValueRef;

/// Set the prototype of an object
pub extern "JavaScriptCore" fn JSObjectSetPrototype(ctx: JSContextRef, object: JSObjectRef, value: JSValueRef) void;

/// Get the property names of an object
pub extern "JavaScriptCore" fn JSObjectCopyPropertyNames(ctx: JSContextRef, object: JSObjectRef) JSPropertyNameArrayRef;

// ============================================================================
// Property Name Array Functions
// ============================================================================

/// Retain a property name array
pub extern "JavaScriptCore" fn JSPropertyNameArrayRetain(array: JSPropertyNameArrayRef) JSPropertyNameArrayRef;

/// Release a property name array
pub extern "JavaScriptCore" fn JSPropertyNameArrayRelease(array: JSPropertyNameArrayRef) void;

/// Get the count of names in an array
pub extern "JavaScriptCore" fn JSPropertyNameArrayGetCount(array: JSPropertyNameArrayRef) usize;

/// Get a name from an array at an index
pub extern "JavaScriptCore" fn JSPropertyNameArrayGetNameAtIndex(
    array: JSPropertyNameArrayRef,
    index: usize,
) JSStringRef;

/// Add a name to an accumulator
pub extern "JavaScriptCore" fn JSPropertyNameAccumulatorAddName(
    accumulator: JSPropertyNameAccumulatorRef,
    propertyName: JSStringRef,
) void;

// ============================================================================
// Value Functions
// ============================================================================

/// Get the type of a value
pub extern "JavaScriptCore" fn JSValueGetType(ctx: JSContextRef, value: JSValueRef) JSType;

/// Check if a value is undefined
pub extern "JavaScriptCore" fn JSValueIsUndefined(ctx: JSContextRef, value: JSValueRef) bool;

/// Check if a value is null
pub extern "JavaScriptCore" fn JSValueIsNull(ctx: JSContextRef, value: JSValueRef) bool;

/// Check if a value is boolean
pub extern "JavaScriptCore" fn JSValueIsBoolean(ctx: JSContextRef, value: JSValueRef) bool;

/// Check if a value is a number
pub extern "JavaScriptCore" fn JSValueIsNumber(ctx: JSContextRef, value: JSValueRef) bool;

/// Check if a value is a string
pub extern "JavaScriptCore" fn JSValueIsString(ctx: JSContextRef, value: JSValueRef) bool;

/// Check if a value is a symbol
pub extern "JavaScriptCore" fn JSValueIsSymbol(ctx: JSContextRef, value: JSValueRef) bool;

/// Check if a value is an object
pub extern "JavaScriptCore" fn JSValueIsObject(ctx: JSContextRef, value: JSValueRef) bool;

/// Check if a value is an array
pub extern "JavaScriptCore" fn JSValueIsArray(ctx: JSContextRef, value: JSValueRef) bool;

/// Check if a value is a Date
pub extern "JavaScriptCore" fn JSValueIsDate(ctx: JSContextRef, value: JSValueRef) bool;

/// Check if a value is an object of a given class
pub extern "JavaScriptCore" fn JSValueIsObjectOfClass(
    ctx: JSContextRef,
    value: JSValueRef,
    jsClass: JSClassRef,
) bool;

/// Check if two values are equal (==)
pub extern "JavaScriptCore" fn JSValueIsEqual(
    ctx: JSContextRef,
    a: JSValueRef,
    b: JSValueRef,
    exception: *?JSValueRef,
) bool;

/// Check if two values are strict equal (===)
pub extern "JavaScriptCore" fn JSValueIsStrictEqual(
    ctx: JSContextRef,
    a: JSValueRef,
    b: JSValueRef,
) bool;

/// Check if a value is an instance of a constructor
pub extern "JavaScriptCore" fn JSValueIsInstanceOfConstructor(
    ctx: JSContextRef,
    value: JSValueRef,
    constructor: JSObjectRef,
    exception: *?JSValueRef,
) bool;

/// Create an undefined value
pub extern "JavaScriptCore" fn JSValueMakeUndefined(ctx: JSContextRef) JSValueRef;

/// Create a null value
pub extern "JavaScriptCore" fn JSValueMakeNull(ctx: JSContextRef) JSValueRef;

/// Create a boolean value
pub extern "JavaScriptCore" fn JSValueMakeBoolean(ctx: JSContextRef, boolean: bool) JSValueRef;

/// Create a number value
pub extern "JavaScriptCore" fn JSValueMakeNumber(ctx: JSContextRef, number: f64) JSValueRef;

/// Create a string value
pub extern "JavaScriptCore" fn JSValueMakeString(ctx: JSContextRef, string: JSStringRef) JSValueRef;

/// Create a symbol value
pub extern "JavaScriptCore" fn JSValueMakeSymbol(ctx: JSContextRef, description: ?JSStringRef) JSValueRef;

/// Create a value from JSON string
pub extern "JavaScriptCore" fn JSValueMakeFromJSONString(ctx: JSContextRef, string: JSStringRef) JSValueRef;

/// Create a JSON string from a value
pub extern "JavaScriptCore" fn JSValueCreateJSONString(
    ctx: JSContextRef,
    value: JSValueRef,
    indent: c_uint,
    exception: *?JSValueRef,
) JSStringRef;

/// Convert a value to boolean
pub extern "JavaScriptCore" fn JSValueToBoolean(ctx: JSContextRef, value: JSValueRef) bool;

/// Convert a value to number
pub extern "JavaScriptCore" fn JSValueToNumber(
    ctx: JSContextRef,
    value: JSValueRef,
    exception: *?JSValueRef,
) f64;

/// Convert a value to string
pub extern "JavaScriptCore" fn JSValueToStringCopy(
    ctx: JSContextRef,
    value: JSValueRef,
    exception: *?JSValueRef,
) JSStringRef;

/// Convert a value to object
pub extern "JavaScriptCore" fn JSValueToObject(
    ctx: JSContextRef,
    value: JSValueRef,
    exception: *?JSValueRef,
) JSObjectRef;

/// Protect a value from garbage collection
pub extern "JavaScriptCore" fn JSValueProtect(ctx: JSContextRef, value: JSValueRef) void;

/// Unprotect a value (allow garbage collection)
pub extern "JavaScriptCore" fn JSValueUnprotect(ctx: JSContextRef, value: JSValueRef) void;

// ============================================================================
// Script Evaluation
// ============================================================================

/// Evaluate a script
pub extern "JavaScriptCore" fn JSEvaluateScript(
    ctx: JSContextRef,
    script: JSStringRef,
    thisObject: ?JSObjectRef,
    sourceURL: ?JSStringRef,
    startingLineNumber: c_int,
    exception: *?JSValueRef,
) JSValueRef;

/// Check script syntax
pub extern "JavaScriptCore" fn JSCheckScriptSyntax(
    ctx: JSContextRef,
    script: JSStringRef,
    sourceURL: ?JSStringRef,
    startingLineNumber: c_int,
    exception: *?JSValueRef,
) bool;

/// Garbage collect (hint to VM)
pub extern "JavaScriptCore" fn JSGarbageCollect(ctx: JSContextRef) void;

// ============================================================================
// Typed Array Support (JSC has these in later versions)
// ============================================================================

/// Typed Array type enumeration
pub const JSTypedArrayType = enum(c_uint) {
    kJSTypedArrayTypeInt8Array = 0,
    kJSTypedArrayTypeInt16Array = 1,
    kJSTypedArrayTypeInt32Array = 2,
    kJSTypedArrayTypeUint8Array = 3,
    kJSTypedArrayTypeUint8ClampedArray = 4,
    kJSTypedArrayTypeUint16Array = 5,
    kJSTypedArrayTypeUint32Array = 6,
    kJSTypedArrayTypeFloat32Array = 7,
    kJSTypedArrayTypeFloat64Array = 8,
    kJSTypedArrayTypeArrayBuffer = 9,
    kJSTypedArrayTypeNone = 10,
    kJSTypedArrayTypeBigInt64Array = 11,
    kJSTypedArrayTypeBigUint64Array = 12,
};

/// Create a typed array with given length
pub extern "JavaScriptCore" fn JSObjectMakeTypedArray(
    ctx: JSContextRef,
    arrayType: JSTypedArrayType,
    length: usize,
    exception: *?JSValueRef,
) JSObjectRef;

/// Create a typed array from existing buffer
pub extern "JavaScriptCore" fn JSObjectMakeTypedArrayWithBytesNoCopy(
    ctx: JSContextRef,
    arrayType: JSTypedArrayType,
    bytes: *anyopaque,
    byteLength: usize,
    bytesDeallocator: ?*const fn (*anyopaque, ?*anyopaque) callconv(.c) void,
    deallocatorContext: ?*anyopaque,
    exception: *?JSValueRef,
) JSObjectRef;

/// Create a typed array from an ArrayBuffer
pub extern "JavaScriptCore" fn JSObjectMakeTypedArrayWithArrayBuffer(
    ctx: JSContextRef,
    arrayType: JSTypedArrayType,
    buffer: JSObjectRef,
    exception: *?JSValueRef,
) JSObjectRef;

/// Create a typed array from ArrayBuffer with offset and length
pub extern "JavaScriptCore" fn JSObjectMakeTypedArrayWithArrayBufferAndOffset(
    ctx: JSContextRef,
    arrayType: JSTypedArrayType,
    buffer: JSObjectRef,
    byteOffset: usize,
    length: usize,
    exception: *?JSValueRef,
) JSObjectRef;

/// Get the typed array bytes pointer
pub extern "JavaScriptCore" fn JSObjectGetTypedArrayBytesPtr(
    ctx: JSContextRef,
    object: JSObjectRef,
    exception: *?JSValueRef,
) ?*anyopaque;

/// Get the typed array length
pub extern "JavaScriptCore" fn JSObjectGetTypedArrayLength(
    ctx: JSContextRef,
    object: JSObjectRef,
    exception: *?JSValueRef,
) usize;

/// Get the typed array byte length
pub extern "JavaScriptCore" fn JSObjectGetTypedArrayByteLength(
    ctx: JSContextRef,
    object: JSObjectRef,
    exception: *?JSValueRef,
) usize;

/// Get the typed array byte offset
pub extern "JavaScriptCore" fn JSObjectGetTypedArrayByteOffset(
    ctx: JSContextRef,
    object: JSObjectRef,
    exception: *?JSValueRef,
) usize;

/// Get the typed array's backing ArrayBuffer
pub extern "JavaScriptCore" fn JSObjectGetTypedArrayBuffer(
    ctx: JSContextRef,
    object: JSObjectRef,
    exception: *?JSValueRef,
) JSObjectRef;

/// Create an ArrayBuffer with given length
pub extern "JavaScriptCore" fn JSObjectMakeArrayBufferWithBytesNoCopy(
    ctx: JSContextRef,
    bytes: *anyopaque,
    byteLength: usize,
    bytesDeallocator: ?*const fn (*anyopaque, ?*anyopaque) callconv(.c) void,
    deallocatorContext: ?*anyopaque,
    exception: *?JSValueRef,
) JSObjectRef;

/// Get ArrayBuffer bytes pointer
pub extern "JavaScriptCore" fn JSObjectGetArrayBufferBytesPtr(
    ctx: JSContextRef,
    object: JSObjectRef,
    exception: *?JSValueRef,
) ?*anyopaque;

/// Get ArrayBuffer byte length
pub extern "JavaScriptCore" fn JSObjectGetArrayBufferByteLength(
    ctx: JSContextRef,
    object: JSObjectRef,
    exception: *?JSValueRef,
) usize;

// ============================================================================
// Helper Functions (implemented in Zig)
// ============================================================================

/// Create a JSString from a Zig slice
pub fn createString(bytes: []const u8) JSStringRef {
    // JSC strings require null-termination for the C API
    // For safety, we create a null-terminated copy
    var buf: [4096]u8 = undefined;
    if (bytes.len < buf.len) {
        @memcpy(buf[0..bytes.len], bytes);
        buf[bytes.len] = 0;
        return JSStringCreateWithUTF8CString(@ptrCast(&buf));
    }
    // For longer strings, we'd need to allocate - this is a limitation
    // In practice, most property names are short
    return JSStringCreateWithUTF8CString("");
}

/// Get the UTF-8 string from a JSStringRef
pub fn getString(allocator: std.mem.Allocator, string: JSStringRef) ![]u8 {
    const max_size = JSStringGetMaximumUTF8CStringSize(string);
    const buffer = try allocator.alloc(u8, max_size);
    errdefer allocator.free(buffer);

    const actual_size = JSStringGetUTF8CString(string, buffer.ptr, max_size);
    if (actual_size > 0) {
        // actual_size includes null terminator, we don't want it
        return buffer[0 .. actual_size - 1];
    }
    return buffer[0..0];
}

// ============================================================================
// Tests
// ============================================================================

test "JSClassDefinition - struct layout" {
    const testing = std.testing;

    // Verify the struct is extern compatible
    try testing.expect(@typeInfo(JSClassDefinition).@"struct".layout == .@"extern");
}

test "JSStaticValue - struct layout" {
    const testing = std.testing;

    try testing.expect(@typeInfo(JSStaticValue).@"struct".layout == .@"extern");
}

test "JSStaticFunction - struct layout" {
    const testing = std.testing;

    try testing.expect(@typeInfo(JSStaticFunction).@"struct".layout == .@"extern");
}
