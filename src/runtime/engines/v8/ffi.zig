//! V8 JavaScript Engine FFI Bindings
//!
//! This module provides Zig bindings to the V8 C++ API for JavaScript execution.
//! All types and functions here map directly to V8's public API.
//!
//! **TYPE SAFETY NOTE**: All `anyopaque` usage in this file is LEGITIMATE and should
//! NOT be refactored. This is an FFI boundary where C interop requires opaque pointers.
//! See docs/type-safety.md for details.
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

    /// Check if this is a constructor call (called with 'new')
    pub extern fn v8_FunctionCallbackInfo_IsConstructCall(self: *const FunctionCallbackInfo) bool;

    /// Get the holder object (the object on which the function is defined)
    pub extern fn v8_FunctionCallbackInfo_Holder(self: *const FunctionCallbackInfo) *Object;

    /// Set the return value for the function (takes Global<Value>* - DEPRECATED)
    /// DEPRECATED: Use v8_FunctionCallbackInfo_SetReturnValueLocal for Local values
    pub extern fn v8_FunctionCallbackInfo_SetReturnValue(self: *const FunctionCallbackInfo, value: *Value) void;

    /// Set the return value from a Local<Value> internal pointer
    /// This accepts the raw pointer from Local values (from v8_Global_Get, v8_Number_New, etc.)
    pub extern fn v8_FunctionCallbackInfo_SetReturnValueLocal(self: *const FunctionCallbackInfo, local_ptr: ?*anyopaque) void;

    /// Set the return value from a Global<Value>* handle
    /// This properly converts the Global to a Local before setting.
    /// Use this for values from v8_String_NewFromUtf8, v8_Number_New, etc. which return Global handles.
    pub extern fn v8_FunctionCallbackInfo_SetReturnValueGlobal(self: *const FunctionCallbackInfo, global_ptr: ?*anyopaque) void;

    /// Get data associated with the function template
    pub extern fn v8_FunctionCallbackInfo_Data(self: *const FunctionCallbackInfo) *Value;

    /// Get the function being called
    pub extern fn v8_FunctionCallbackInfo_GetFunction(self: *const FunctionCallbackInfo) ?*Function;

    /// Get the creation context of the target function being called.
    /// This is critical for cross-realm support: when calling
    /// other.SomeInterface.prototype.method.call(obj), we need the context
    /// where 'method' was instantiated (the iframe's context).
    pub extern fn v8_FunctionCallbackInfo_GetFunctionCreationContext(self: *const FunctionCallbackInfo) ?*Context;

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

    pub inline fn isConstructCall(self: *const FunctionCallbackInfo) bool {
        return v8_FunctionCallbackInfo_IsConstructCall(self);
    }

    pub inline fn getHolder(self: *const FunctionCallbackInfo) *Object {
        return v8_FunctionCallbackInfo_Holder(self);
    }

    pub inline fn setReturnValue(self: *const FunctionCallbackInfo, value: *Value) void {
        // Use the Global variant - our FFI functions (v8_String_NewFromUtf8, v8_Number_New, etc.)
        // return Global<T>* handles, not Local<Value> internal pointers.
        // The Global variant properly converts Global to Local before setting.
        //
        // IMPORTANT: The value MUST be a Global<Value>* (from v8_String_NewFromUtf8, etc.)
        // NOT a Local pointer (from v8_Global_Get). If you're getting crashes here,
        // check that all code paths returning to setReturnValue go through proper
        // Global handle creation.
        v8_FunctionCallbackInfo_SetReturnValueGlobal(self, @ptrCast(value));
    }

    pub inline fn getData(self: *const FunctionCallbackInfo) *Value {
        return v8_FunctionCallbackInfo_Data(self);
    }

    /// Get the function being called.
    pub inline fn getFunction(self: *const FunctionCallbackInfo) ?*Function {
        return v8_FunctionCallbackInfo_GetFunction(self);
    }

    /// Get the creation context of the target function being called.
    /// For cross-realm support: returns the context where the method was instantiated.
    pub inline fn getFunctionCreationContext(self: *const FunctionCallbackInfo) ?*Context {
        return v8_FunctionCallbackInfo_GetFunctionCreationContext(self);
    }

    /// Get the NewTarget for constructor calls.
    /// Returns the function that was called with 'new', which may be different from
    /// the constructor when subclassing (Reflect.construct) or using bound functions.
    /// Returns null for non-construct calls.
    pub extern fn v8_FunctionCallbackInfo_NewTarget(self: *const FunctionCallbackInfo) ?*Value;

    /// Get the NewTarget value for this constructor call.
    /// For cross-realm constructor support per WebIDL §3.7.2:
    /// - Objects should be created in GetFunctionRealm(NewTarget) realm
    /// - Returns null for non-construct calls
    pub inline fn getNewTarget(self: *const FunctionCallbackInfo) ?*Value {
        return v8_FunctionCallbackInfo_NewTarget(self);
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

    /// Check if errors should throw (indicates strict mode)
    /// Returns true if we're in strict mode and should throw TypeError on failure
    pub extern fn v8_PropertyCallbackInfo_ShouldThrowOnError(self: *const PropertyCallbackInfo) bool;

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

    /// Check if errors should throw (indicates strict mode)
    /// Returns true if we're in strict mode and should throw TypeError on failure
    pub inline fn shouldThrowOnError(self: *const PropertyCallbackInfo) bool {
        return v8_PropertyCallbackInfo_ShouldThrowOnError(self);
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

    /// Check if errors should throw (indicates strict mode)
    /// Returns true if we're in strict mode and should throw TypeError on failure
    pub extern fn v8_PropertyCallbackInfo_Void_ShouldThrowOnError(self: *const PropertyCallbackInfoVoid) bool;

    /// Get the 'this' object
    pub extern fn v8_PropertyCallbackInfo_Void_This(self: *const PropertyCallbackInfoVoid) *Object;

    /// Get the holder object
    pub extern fn v8_PropertyCallbackInfo_Void_Holder(self: *const PropertyCallbackInfoVoid) ?*Object;

    pub inline fn getIsolate(self: *const PropertyCallbackInfoVoid) *Isolate {
        return v8_PropertyCallbackInfo_Void_GetIsolate(self);
    }

    pub inline fn getThis(self: *const PropertyCallbackInfoVoid) *Object {
        return v8_PropertyCallbackInfo_Void_This(self);
    }

    pub inline fn getHolder(self: *const PropertyCallbackInfoVoid) ?*Object {
        return v8_PropertyCallbackInfo_Void_Holder(self);
    }

    /// Check if errors should throw (indicates strict mode)
    /// Returns true if we're in strict mode and should throw TypeError on failure
    pub inline fn shouldThrowOnError(self: *const PropertyCallbackInfoVoid) bool {
        return v8_PropertyCallbackInfo_Void_ShouldThrowOnError(self);
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
) callconv(.c) Intercepted;

/// Called when JavaScript sets a named property (e.g., obj.propertyName = value)
/// Should set a return value to indicate success/failure
pub const NamedPropertySetterCallback = *const fn (
    property: *Name,
    value: *Value,
    info: *const PropertyCallbackInfo,
) callconv(.c) Intercepted;

/// Called to check if a named property exists on the object
/// Should return an integer attribute value, or do nothing if property doesn't exist
pub const NamedPropertyQueryCallback = *const fn (
    property: *Name,
    info: *const PropertyCallbackInfo,
) callconv(.c) Intercepted;

/// Called when JavaScript deletes a named property (e.g., delete obj.propertyName)
/// Should set return value to true if deletion succeeds, false if it fails
pub const NamedPropertyDeleterCallback = *const fn (
    property: *Name,
    info: *const PropertyCallbackInfo,
) callconv(.c) Intercepted;

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
) callconv(.c) Intercepted;

/// Indexed property setter callback with Intercepted return type
/// Called when JavaScript sets an indexed property (e.g., obj[0] = value)
/// Return Intercepted::kYes if the set was handled (or rejected with exception)
/// Return Intercepted::kNo to let V8 continue normal property setting
pub const IndexedPropertySetterCallbackIntercepted = *const fn (
    index: u32,
    value: *Value,
    info: *const PropertyCallbackInfo,
) callconv(.c) Intercepted;

// ============================================================================
// V8 API Function Declarations
// ============================================================================

// ObjectTemplate functions
pub extern fn v8_ObjectTemplate_New(isolate: *Isolate) *ObjectTemplate;
pub extern fn v8_ObjectTemplate_NewInstance(self: *ObjectTemplate, context: *Context) ?*Object;
pub extern fn v8_ObjectTemplate_SetInternalFieldCount(self: *ObjectTemplate, count: c_int) void;

// Function::NewInstance - Create object via constructor (sets up prototype chain properly)
pub extern fn v8_Function_NewInstance(function: *Function, context: *Context, argc: c_int, argv: ?[*]*Value) ?*Object;

/// Mark the object template's prototype as immutable.
/// This makes Object.setPrototypeOf(obj, newProto) throw TypeError
/// when newProto !== Object.getPrototypeOf(obj).
/// Required for WebIDL global objects (Window, WorkerGlobalScope).
pub extern fn v8_ObjectTemplate_SetImmutableProto(self: *ObjectTemplate) void;

/// Mark objects created from this template as undetectable.
/// Per ECMA-262, objects with [[IsHTMLDDA]] internal slot are "undetectable":
/// - typeof returns "undefined"
/// - == null and == undefined return true
/// - ToBoolean returns false
/// This is used for document.all (HTMLAllCollection).
/// Spec: https://tc39.es/ecma262/#sec-IsHTMLDDA-internal-slot
pub extern fn v8_ObjectTemplate_MarkAsUndetectable(self: *ObjectTemplate) void;

/// Set a call-as-function handler on an ObjectTemplate.
/// This allows instances to be called like functions.
/// Required for objects marked as undetectable (like document.all).
/// The callback is invoked when instances are called with ().
pub extern fn v8_ObjectTemplate_SetCallAsFunctionHandler(
    self: *ObjectTemplate,
    callback: FunctionCallback,
    data: ?*anyopaque,
) void;

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

/// Set a FunctionTemplate property on the ObjectTemplate with attributes.
/// Used by GlobalTemplateRegistry to attach interface constructors to the global template.
/// This is the correct way to attach FunctionTemplates (vs SetWithAttributes which expects Values).
pub extern fn v8_ObjectTemplate_SetFunctionTemplate(
    self: *ObjectTemplate,
    name: *String,
    func_tpl: *FunctionTemplate,
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

/// Named property query callback with Intercepted return type
/// Returns Intercepted::kYes if property exists, Intercepted::kNo otherwise
pub const NamedPropertyQueryCallbackIntercepted = *const fn (
    property: *Name,
    info: *const PropertyCallbackInfo,
) callconv(.c) Intercepted;

/// Named property descriptor callback with Intercepted return type
/// Should set return value to a property descriptor object with value/writable/enumerable/configurable
/// Returns Intercepted::kYes if property exists and descriptor was set, Intercepted::kNo otherwise
pub const NamedPropertyDescriptorCallback = *const fn (
    property: *Name,
    info: *const PropertyCallbackInfo,
) callconv(.c) Intercepted;

/// V8 PropertyHandlerFlags for named property handlers
/// Must match v8-template.h PropertyHandlerFlags enum values
/// These are bit flags that can be combined (e.g., kNonMasking | kOnlyInterceptStrings = 3)
pub const PropertyHandlerFlags = enum(c_int) {
    kNone = 0,
    kNonMasking = 1, // 1 << 0 = 1 - Only intercept properties not on prototype
    kOnlyInterceptStrings = 2, // 1 << 1 = 2 - Only intercept string keys (not symbols)
    kNonMaskingAndOnlyInterceptStrings = 3, // kNonMasking | kOnlyInterceptStrings
    kHasNoSideEffect = 4, // 1 << 2 = 4
};

/// Set a named property handler with full support for legacy platform objects
/// This enables proper behavior for:
/// - obj.name (getter)
/// - Object.getOwnPropertyDescriptor(obj, name) (descriptor)
/// - Reflect.ownKeys(obj) (enumerator)
/// - 'name' in obj (query)
pub extern fn v8_ObjectTemplate_SetNamedPropertyHandlerFull(
    self: *ObjectTemplate,
    getter: ?NamedPropertyGetterCallback,
    setter: ?NamedPropertySetterCallback,
    query: ?NamedPropertyQueryCallbackIntercepted,
    deleter: ?NamedPropertyDeleterCallback,
    enumerator: ?NamedPropertyEnumeratorCallback,
    descriptor: ?NamedPropertyDescriptorCallback,
    flags: PropertyHandlerFlags,
) void;

pub const NamedPropertyDefinerCallback = *const fn (
    property: *Name,
    desc: *const PropertyDescriptor,
    info: *const PropertyCallbackInfoVoid,
) callconv(.c) Intercepted;

pub extern fn v8_ObjectTemplate_SetNamedPropertyHandlerWithDefiner(
    self: *ObjectTemplate,
    getter: ?NamedPropertyGetterCallback,
    setter: ?NamedPropertySetterCallback,
    query: ?NamedPropertyQueryCallbackIntercepted,
    deleter: ?NamedPropertyDeleterCallback,
    enumerator: ?NamedPropertyEnumeratorCallback,
    definer: ?NamedPropertyDefinerCallback,
    descriptor: ?NamedPropertyDescriptorCallback,
    flags: PropertyHandlerFlags,
) void;

/// Set an indexed property handler on the ObjectTemplate
/// This intercepts indexed property access (e.g., obj[0], obj[1], etc.)
pub extern fn v8_ObjectTemplate_SetIndexedPropertyHandler(
    self: *ObjectTemplate,
    getter: IndexedPropertyGetterCallback,
) void;

/// Indexed property enumerator callback for Reflect.ownKeys and for...in enumeration
/// Should return an array of indices that exist on the object
pub const IndexedPropertyEnumeratorCallback = *const fn (
    info: *const PropertyCallbackInfo,
) callconv(.c) void;

/// V8 Intercepted enum - indicates whether a property interceptor handled the request
/// kNo (0) = not intercepted, continue normal lookup
/// kYes (1) = intercepted, use the return value
pub const Intercepted = enum(u8) {
    kNo = 0,
    kYes = 1,
};

/// Indexed property query callback for Object.getOwnPropertyDescriptor attribute queries
/// Should return property attributes (None=0, ReadOnly=1, DontEnum=2, DontDelete=4)
/// Return value via info.GetReturnValue().Set(v8::Integer::New(isolate, attributes))
/// Returns Intercepted::kYes if property exists, Intercepted::kNo otherwise
pub const IndexedPropertyQueryCallback = *const fn (
    index: u32,
    info: *const PropertyCallbackInfo,
) callconv(.c) Intercepted;

/// Indexed property descriptor callback for Object.getOwnPropertyDescriptor
/// Should set return value to a property descriptor object with value/writable/enumerable/configurable
/// Returns Intercepted::kYes if property exists and descriptor was set, Intercepted::kNo otherwise
pub const IndexedPropertyDescriptorCallback = *const fn (
    index: u32,
    info: *const PropertyCallbackInfo,
) callconv(.c) Intercepted;

/// Set an indexed property handler with enumerator support on the ObjectTemplate
/// This intercepts indexed property access and enables Reflect.ownKeys enumeration
pub extern fn v8_ObjectTemplate_SetIndexedPropertyHandlerWithEnumerator(
    self: *ObjectTemplate,
    getter: IndexedPropertyGetterCallback,
    enumerator: IndexedPropertyEnumeratorCallback,
) void;

/// Set an indexed property handler with full support (getter, setter, query, enumerator, descriptor)
/// This enables proper behavior for:
/// - obj[index] (getter)
/// - obj[index] = value (setter - throws TypeError in strict mode if read-only)
/// - Object.getOwnPropertyDescriptor(obj, index) (descriptor)
/// - Reflect.ownKeys(obj) (enumerator)
/// - 'index' in obj (query)
pub extern fn v8_ObjectTemplate_SetIndexedPropertyHandlerFull(
    self: *ObjectTemplate,
    getter: IndexedPropertyGetterCallback,
    setter: ?IndexedPropertySetterCallbackIntercepted,
    query: ?IndexedPropertyQueryCallback,
    enumerator: ?IndexedPropertyEnumeratorCallback,
    descriptor: ?IndexedPropertyDescriptorCallback,
) void;

/// V8 PropertyDescriptor - represents a property descriptor from Object.defineProperty
/// This is an opaque type; use helper functions to extract fields
pub const PropertyDescriptor = opaque {};

/// Indexed property definer callback for Object.defineProperty() interception
/// This handles [[DefineOwnProperty]] per WebIDL spec
/// Returns Intercepted::kYes if the define was handled, Intercepted::kNo otherwise
pub const IndexedPropertyDefinerCallback = *const fn (
    index: u32,
    desc: *const PropertyDescriptor,
    info: *const PropertyCallbackInfoVoid,
) callconv(.c) Intercepted;

/// Check if PropertyDescriptor is an accessor descriptor (has get or set)
pub extern fn v8_PropertyDescriptor_IsAccessorDescriptor(desc: *const PropertyDescriptor) bool;

/// Check if PropertyDescriptor is a data descriptor (has value)
pub extern fn v8_PropertyDescriptor_IsDataDescriptor(desc: *const PropertyDescriptor) bool;

/// Get the value from a data PropertyDescriptor (returns null if not present)
pub extern fn v8_PropertyDescriptor_GetValue(desc: *const PropertyDescriptor) ?*Value;

/// Check if PropertyDescriptor has a configurable field specified
pub extern fn v8_PropertyDescriptor_HasConfigurable(desc: *const PropertyDescriptor) bool;

/// Get the configurable value from PropertyDescriptor (only valid if HasConfigurable returns true)
pub extern fn v8_PropertyDescriptor_Configurable(desc: *const PropertyDescriptor) bool;

/// Check if PropertyDescriptor has an enumerable field specified
pub extern fn v8_PropertyDescriptor_HasEnumerable(desc: *const PropertyDescriptor) bool;

/// Get the enumerable value from PropertyDescriptor (only valid if HasEnumerable returns true)
pub extern fn v8_PropertyDescriptor_Enumerable(desc: *const PropertyDescriptor) bool;

/// Check if PropertyDescriptor has a writable field specified
pub extern fn v8_PropertyDescriptor_HasWritable(desc: *const PropertyDescriptor) bool;

/// Get the writable value from PropertyDescriptor (only valid if HasWritable returns true)
pub extern fn v8_PropertyDescriptor_Writable(desc: *const PropertyDescriptor) bool;

/// Set indexed property handler with definer support for [[DefineOwnProperty]]
/// This enables proper behavior for:
/// - obj[index] (getter)
/// - obj[index] = value (setter) - throws TypeError in strict mode if no setter defined
/// - Object.defineProperty(obj, index, desc) (definer) - handles [[DefineOwnProperty]]
/// - Object.getOwnPropertyDescriptor(obj, index) (descriptor)
/// - Reflect.ownKeys(obj) (enumerator)
/// - 'index' in obj (query)
pub extern fn v8_ObjectTemplate_SetIndexedPropertyHandlerWithDefiner(
    self: *ObjectTemplate,
    getter: IndexedPropertyGetterCallback,
    setter: ?IndexedPropertySetterCallbackIntercepted,
    query: ?IndexedPropertyQueryCallback,
    enumerator: ?IndexedPropertyEnumeratorCallback,
    definer: ?IndexedPropertyDefinerCallback,
    descriptor: ?IndexedPropertyDescriptorCallback,
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

/// Set V8 command-line flags from a string
///
/// Must be called BEFORE v8_Platform_Initialize() for flags to take effect.
/// Example: "--hash-seed=0" for deterministic hashing (helps with snapshots)
pub extern fn v8_SetFlagsFromString(flags: [*:0]const u8) void;

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
/// Create a context using a FunctionTemplate's InstanceTemplate as the global.
/// This ensures that the global object inherits from the FunctionTemplate's prototype,
/// which is necessary for cross-realm Window support.
pub extern fn v8_Context_NewWithGlobalConstructor(isolate: *Isolate, global_constructor: *FunctionTemplate) ?*Context;
pub extern fn v8_Context_Dispose(context: *Context) void;
pub extern fn v8_Context_Enter(context: *Context) void;
pub extern fn v8_Context_Exit(context: *Context) void;
pub extern fn v8_Context_Global(context: *Context) ?*Object;
pub extern fn v8_Context_GetRawAddress(context: *Context) ?*anyopaque;
pub extern fn v8_Context_SetSecurityToken(context: *Context, token: *Value) void;
pub extern fn v8_Context_GetSecurityToken(context: *Context) ?*Value;
pub extern fn v8_Context_UseDefaultSecurityToken(context: *Context) void;

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
pub extern fn v8_Symbol_GetUnscopables(isolate: *Isolate) ?*Symbol;
pub extern fn v8_Symbol_Dispose(symbol: *Symbol) void;
pub extern fn v8_Value_IsObject(value: *Value) bool;
pub extern fn v8_Value_IsFunction(value: *Value) bool;
pub extern fn v8_Value_IsArray(value: *Value) bool;
pub extern fn v8_Value_IsArrayBuffer(value: *Value) bool;
pub extern fn v8_Value_IsArrayBufferView(value: *Value) bool;

// Local-handle versions (take raw internal pointer from Local<Value>)
pub extern fn v8_Value_IsObject_Local(value_ptr: *anyopaque) bool;
pub extern fn v8_Value_IsFunction_Local(value_ptr: *anyopaque) bool;
pub extern fn v8_Value_IsArray_Local(value_ptr: *anyopaque) bool;
pub extern fn v8_Value_IsNullOrUndefined_Local(value_ptr: *anyopaque) bool;
pub extern fn v8_Value_IsSymbol_Local(value_ptr: *anyopaque) bool;
pub extern fn v8_Value_IsString_Local(value_ptr: *anyopaque) bool;
pub extern fn v8_Value_ToString_Local(value_ptr: *anyopaque, context: *Context) ?*String;
pub extern fn v8_Value_IsPromise(value: *Value) bool;

/// Check if a value has [[IsHTMLDDA]] internal slot (document.all).
/// Per ECMA-262, these "undetectable" objects are falsy despite being objects.
/// Used for WebIDL this-value validation - document.all should throw TypeError
/// when used as 'this' for incompatible operations.
pub extern fn v8_Value_IsUndetectable(value: *Value) bool;

/// Version for Local handle internal pointers (raw V8 tagged pointer)
pub extern fn v8_Value_IsUndetectable_Local(value_ptr: *anyopaque) bool;

/// Check if a value is a bound function (created via Function.prototype.bind).
/// Used for implementing GetFunctionRealm algorithm per ECMA-262 §7.3.22.
pub extern fn v8_Value_IsBoundFunction(value: *Value) bool;

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
pub extern fn v8_Object_NewWithNullPrototype(context: *Context) ?*Object;

/// Create a plain object {} in a specific context (for cross-realm support).
/// The object's prototype will be the target context's Object.prototype,
/// which is essential for correct cross-realm toJSON behavior per WebIDL spec.
///
/// Example: When calling other.DOMRectReadOnly.prototype.toJSON.call(rect),
/// the result object must have other's Object.prototype, not the caller's.
pub extern fn v8_Object_NewInContext(context: *Context) ?*Object;

/// Create an array [] in a specific context (for cross-realm support).
/// The array's prototype will be the target context's Array.prototype.
pub extern fn v8_Array_NewInContext(context: *Context, length: c_int) ?*Array;

pub extern fn v8_Object_Set(object: *Object, context: *Context, key: *Value, value: *Value) bool;
pub extern fn v8_Object_Delete(object: *Object, context: *Context, key: *Value) bool;
pub extern fn v8_Object_CreateDataProperty(object: *Object, context: *Context, key: *String, value: *Value) bool;
pub extern fn v8_Object_Get(object: *Object, context: *Context, key: *Value) ?*Value;
pub extern fn v8_Object_HasOwnProperty(object: *Object, context: *Context, key: *Value) bool;
pub extern fn v8_Object_GetOwnPropertyDescriptor(object: *Object, context: *Context, key: *Value) ?*Value;
pub extern fn v8_Object_GetOwnPropertyNames(context: *Context, obj: *Object) ?*Array;
pub extern fn v8_Object_GetOwnPropertyNamesAsStrings(context: *Context, obj: *Object) ?*Array;
pub extern fn v8_Object_GetOwnPropertySymbols(context: *Context, obj: *Object) ?*Array;
pub extern fn v8_Object_GetPropertyNames(context: *Context, obj: *Object) ?*Array;
pub extern fn v8_Object_SetAlignedPointerInInternalField(object: *Object, index: c_int, value: *anyopaque) void;
pub extern fn v8_Object_InternalFieldCount(object: *Object) c_int;
pub extern fn v8_Object_GetAlignedPointerFromInternalField(object: *Object, index: c_int) ?*anyopaque;
// Raw versions for property interceptors (take raw Local pointers not Global handles)
pub extern fn v8_Object_InternalFieldCount_Raw(object: *const anyopaque) c_int;
pub extern fn v8_Object_GetAlignedPointerFromInternalField_Raw(object: *const anyopaque, index: c_int) ?*anyopaque;
pub extern fn v8_Object_Dispose(obj: *Object) void;
pub extern fn v8_Object_DefineProperty(object: *Object, context: *Context, key: *Value, value: *Value, writable: bool, enumerable: bool, configurable: bool) bool;

/// Set an accessor property (getter/setter) on an existing V8 Object
/// This creates an own property with getter/setter functions, visible to Object.getOwnPropertyDescriptor
/// Used to make Window properties own properties of the global object for cross-realm compliance
pub extern fn v8_Object_SetAccessorProperty(
    object: *Object,
    context: *Context,
    name: *String,
    getter: ?FunctionCallback,
    setter: ?FunctionCallback,
) bool;

pub extern fn v8_Object_SetPrototype(object: *Object, context: *Context, prototype: *Value) bool;
/// Set the prototype using the newer V2 API that works properly with global objects
pub extern fn v8_Object_SetPrototypeV2(object: *Object, context: *Context, prototype: *Value) bool;
pub extern fn v8_Object_GetPrototype(object: *Object) ?*Value;
pub extern fn v8_Object_PreventExtensions(object: *Object, context: *Context) bool;
pub extern fn v8_Object_Has(context: *Context, obj: *Object, key: [*:0]const u8) bool;
pub extern fn v8_Object_GetPropertyWithSymbol(context: *Context, obj: *Object, symbol: *Symbol) ?*Value;

/// Create a property descriptor object for Object.getOwnPropertyDescriptor
/// Returns an object like: { value: <value>, writable: <bool>, enumerable: <bool>, configurable: <bool> }
/// This is the format expected by V8 when returning from descriptor callbacks
pub extern fn v8_CreateDataPropertyDescriptor(
    context: *Context,
    value: *Value,
    writable: bool,
    enumerable: bool,
    configurable: bool,
) ?*Object;

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
// V8 Exception Handling with TryCatch
// ============================================================================
//
// These types and functions provide detailed exception information when V8
// operations fail. The "_Safe" variants wrap operations with TryCatch to
// capture error messages, stack traces, and source location information.

/// V8 error information extracted from exceptions
/// Captures detailed exception data including message, stack trace, and source location.
/// All string fields are heap-allocated and must be freed via v8_FreeErrorInfo.
pub const V8ErrorInfo = extern struct {
    /// Whether an error occurred
    has_error: bool,
    /// Exception message (heap-allocated, null-terminated)
    message: ?[*:0]u8,
    /// Stack trace string (heap-allocated, null-terminated, may be null)
    stack_trace: ?[*:0]u8,
    /// Line number where error occurred (-1 if unknown)
    line_number: c_int,
    /// Column number where error occurred (-1 if unknown)
    column_number: c_int,
    /// Source line text (heap-allocated, null-terminated, may be null)
    source_line: ?[*:0]u8,
    /// Resource name/URL (heap-allocated, null-terminated, may be null)
    resource_name: ?[*:0]u8,

    /// Get the message as a Zig slice
    pub fn getMessage(self: *const V8ErrorInfo) ?[]const u8 {
        if (self.message) |msg| {
            return std.mem.sliceTo(msg, 0);
        }
        return null;
    }

    /// Get the stack trace as a Zig slice
    pub fn getStackTrace(self: *const V8ErrorInfo) ?[]const u8 {
        if (self.stack_trace) |st| {
            return std.mem.sliceTo(st, 0);
        }
        return null;
    }

    /// Get the source line as a Zig slice
    pub fn getSourceLine(self: *const V8ErrorInfo) ?[]const u8 {
        if (self.source_line) |sl| {
            return std.mem.sliceTo(sl, 0);
        }
        return null;
    }

    /// Get the resource name as a Zig slice
    pub fn getResourceName(self: *const V8ErrorInfo) ?[]const u8 {
        if (self.resource_name) |rn| {
            return std.mem.sliceTo(rn, 0);
        }
        return null;
    }
};

/// Free a V8ErrorInfo structure and all its allocated strings
pub extern fn v8_FreeErrorInfo(info: ?*V8ErrorInfo) void;

/// Result of safe script compilation
pub const V8ScriptCompileResult = extern struct {
    /// Compiled script (null if compilation failed)
    script: ?*Script,
    /// Error information (null if compilation succeeded)
    error_info: ?*V8ErrorInfo,
};

/// Result of safe script execution
pub const V8ScriptRunResult = extern struct {
    /// Execution result value (null if execution failed)
    value: ?*Value,
    /// Error information (null if execution succeeded)
    error_info: ?*V8ErrorInfo,
};

/// Result of safe function calls
pub const V8FunctionCallResult = extern struct {
    /// Return value (null if call failed)
    value: ?*Value,
    /// Error information (null if call succeeded)
    error_info: ?*V8ErrorInfo,
};

/// Result of safe module compilation
pub const V8ModuleCompileResult = extern struct {
    /// Compiled module (null if compilation failed)
    module: ?*Module,
    /// Error information (null if compilation succeeded)
    error_info: ?*V8ErrorInfo,
};

/// Result of safe module instantiation
pub const V8ModuleInstantiateResult = extern struct {
    /// Whether instantiation succeeded
    success: bool,
    /// Error information (null if instantiation succeeded)
    error_info: ?*V8ErrorInfo,
};

/// Result of safe module evaluation
pub const V8ModuleEvaluateResult = extern struct {
    /// Evaluation result value (null if evaluation failed)
    value: ?*Value,
    /// Error information (null if evaluation succeeded)
    error_info: ?*V8ErrorInfo,
};

/// Compile a script with TryCatch error handling
/// Returns both the compiled script (on success) and detailed error info (on failure).
/// Caller must free the result with v8_FreeScriptCompileResult.
pub extern fn v8_Script_Compile_Safe(context: *Context, source: *String) *V8ScriptCompileResult;

/// Compile a script with origin and TryCatch error handling
pub extern fn v8_Script_CompileWithOrigin_Safe(context: *Context, source: *String, resource_name: *String) *V8ScriptCompileResult;

/// Free a V8ScriptCompileResult (does not free the script if non-null)
pub extern fn v8_FreeScriptCompileResult(result: ?*V8ScriptCompileResult) void;

/// Run a compiled script with TryCatch error handling
/// Returns both the result value (on success) and detailed error info (on failure).
/// Caller must free the result with v8_FreeScriptRunResult.
pub extern fn v8_Script_Run_Safe(context: *Context, script: *Script) *V8ScriptRunResult;

/// Free a V8ScriptRunResult (does not free the value if non-null)
pub extern fn v8_FreeScriptRunResult(result: ?*V8ScriptRunResult) void;

/// Call a JavaScript function with TryCatch error handling
/// Returns both the return value (on success) and detailed error info (on failure).
/// Caller must free the result with v8_FreeFunctionCallResult.
pub extern fn v8_Function_Call_Safe(
    function: *Function,
    context: *Context,
    recv: ?*Value,
    argc: c_int,
    argv: ?[*]*Value,
) *V8FunctionCallResult;

/// Call a function with receiver and TryCatch error handling
pub extern fn v8_Function_CallWithReceiver_Safe(
    context: *Context,
    function: *Function,
    receiver: ?*Value,
    argc: c_int,
    argv: ?[*]*Value,
) *V8FunctionCallResult;

/// Free a V8FunctionCallResult (does not free the value if non-null)
pub extern fn v8_FreeFunctionCallResult(result: ?*V8FunctionCallResult) void;

/// Get the [[BoundTargetFunction]] of a bound function.
/// Used for implementing GetFunctionRealm algorithm per ECMA-262 §7.3.22.
/// Returns null if the value is not a bound function.
pub extern fn v8_BoundFunction_GetBoundTargetFunction(func: *Function) ?*Function;

/// Get the creation context (realm) of a function.
/// This is the context where the function was instantiated, which is critical
/// for cross-realm constructor support per WebIDL §3.7.2.
pub extern fn v8_Function_GetCreationContext(func: *Function) ?*Context;

/// Compile an ES module with TryCatch error handling
/// Returns both the compiled module (on success) and detailed error info (on failure).
/// Caller must free the result with v8_FreeModuleCompileResult.
pub extern fn v8_Module_Compile_Safe(
    context: *Context,
    source: *String,
    resource_name: ?*String,
) *V8ModuleCompileResult;

/// Free a V8ModuleCompileResult (does not free the module if non-null)
pub extern fn v8_FreeModuleCompileResult(result: ?*V8ModuleCompileResult) void;

/// Instantiate a module with TryCatch error handling
/// Returns whether instantiation succeeded and detailed error info (on failure).
/// Caller must free the result with v8_FreeModuleInstantiateResult.
pub extern fn v8_Module_Instantiate_Safe(context: *Context, module: *Module) *V8ModuleInstantiateResult;

/// Free a V8ModuleInstantiateResult
pub extern fn v8_FreeModuleInstantiateResult(result: ?*V8ModuleInstantiateResult) void;

/// Evaluate a module with TryCatch error handling
/// Returns both the result value (on success) and detailed error info (on failure).
/// Caller must free the result with v8_FreeModuleEvaluateResult.
pub extern fn v8_Module_Evaluate_Safe(context: *Context, module: *Module) *V8ModuleEvaluateResult;

/// Free a V8ModuleEvaluateResult (does not free the value if non-null)
pub extern fn v8_FreeModuleEvaluateResult(result: ?*V8ModuleEvaluateResult) void;

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

// Cross-realm exception handling
// These functions support throwing exceptions from a specific context/realm.
// Per WebIDL spec, when a method throws TypeError for invalid `this`, the
// TypeError must come from the method's realm (where it was defined), not
// the caller's realm.

/// Get the context in which an object was created (for cross-realm support).
/// Returns null if the object's creation context is unavailable.
pub extern fn v8_Object_GetCreationContext(obj: *Object) ?*Context;

/// Get the context in which an object was created (raw pointer version).
/// Used in callbacks where we have raw Local<Object> pointers, not Global handles.
/// Returns null if the object's creation context is unavailable.
pub extern fn v8_Object_GetCreationContext_Raw(obj_ptr: *const anyopaque) ?*Context;

/// Create TypeError in a specific context (for cross-realm errors).
/// This enters the context before creating the error, ensuring the
/// TypeError constructor comes from the correct realm.
pub extern fn v8_Exception_TypeErrorInContext(context: *Context, message: *String) ?*Value;

/// Get the creation context of an object's prototype.
/// This walks up the prototype chain to find the context where the method/property
/// was defined, which is needed for cross-realm error handling.
pub extern fn v8_Object_GetPrototypeCreationContext(obj: *Object) ?*Context;

// Special values
pub extern fn v8_Undefined(isolate: *Isolate) ?*Value;
pub extern fn v8_Null(isolate: *Isolate) ?*Value;

// Boolean creation
pub extern fn v8_Boolean_New(isolate: *Isolate, value: bool) ?*Value;

// Value persistence - convert Local to Global
/// Persist a Local value to a Global handle.
/// Takes a Local<Value> internal pointer and creates a tracked Global<Value>*.
/// Use this to safely store/return values that came from Local handles.
pub extern fn v8_Value_Persist(isolate: *Isolate, local_ptr: ?*anyopaque) ?*Value;

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
/// Get the prototype object from a FunctionTemplate.
/// This is used when wrapping Zig instances as V8 objects - ObjectTemplate::NewInstance()
/// doesn't automatically link to the FunctionTemplate's prototype, so we need to get
/// the prototype object and set it manually.
pub extern fn v8_FunctionTemplate_GetPrototypeObject(tpl: *FunctionTemplate, context: *Context) ?*Object;
pub extern fn v8_FunctionTemplate_Inherit(tpl: *FunctionTemplate, parent: *FunctionTemplate) void;
pub extern fn v8_FunctionTemplate_SetPrototypeProviderTemplate(self: *FunctionTemplate, provider: *FunctionTemplate) void;
pub extern fn v8_FunctionTemplate_SetLength(tpl: *FunctionTemplate, length: c_int) void;

/// Check if an object is an instance of this FunctionTemplate.
/// Used for [LegacyLenientThis] attribute checking per WebIDL §4.3.10.
pub extern fn v8_FunctionTemplate_HasInstance(tpl: *FunctionTemplate, object: *Object) bool;

/// Mark this function template as having a read-only "prototype" property.
/// This also removes the legacy "arguments" and "caller" properties, making
/// the function behave like a strict mode ES6+ function.
/// Call this for WebIDL interface constructors.
pub extern fn v8_FunctionTemplate_ReadOnlyPrototype(tpl: *FunctionTemplate) void;

/// Remove the "prototype" property from functions created by this template.
/// Use for methods and getters which should not have a prototype property.
/// This also removes "arguments" and "caller".
pub extern fn v8_FunctionTemplate_RemovePrototype(tpl: *FunctionTemplate) void;

/// Set a call handler on a FunctionTemplate.
/// This is required for objects marked as undetectable (like document.all)
/// because V8 requires undetectable objects to be callable.
/// The callback is invoked when instances are called like functions.
pub extern fn v8_FunctionTemplate_SetCallHandler(
    tpl: *FunctionTemplate,
    callback: FunctionCallback,
    data: ?*anyopaque,
) void;

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

/// Get the state of a Promise
/// Returns: 0 = Pending, 1 = Fulfilled, 2 = Rejected
pub extern fn v8_Promise_State(promise: *Promise) c_int;

/// Get the result of a settled Promise (fulfilled value or rejection reason)
/// Returns null if the promise is still pending
pub extern fn v8_Promise_Result(promise: *Promise) ?*Value;

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

/// Check if a Global handle is weak
///
/// A weak handle allows V8 GC to collect the value when no strong references exist.
/// When collected, the weak callback registered via SetWeak is invoked.
///
/// Arguments:
///   handle: The Global handle to check
///
/// Returns:
///   true if the handle is weak, false if strong or null
pub extern fn v8_Global_IsWeak(handle: ?*anyopaque) bool;

/// Create a weak Global<Value> handle from a Local<Value>
///
/// This creates a Global handle that is immediately weak. When V8 GC collects
/// the value (no more strong references), the callback is invoked with user_data.
/// This is more efficient than calling v8_Value_ToGlobal followed by v8_Global_SetWeak.
///
/// Arguments:
///   isolate: Current V8 isolate
///   local: Local value pointer (from within an active HandleScope)
///   user_data: User data to pass to callback on GC (can be null)
///   callback: Function to call when value is garbage collected (can be null for weak without callback)
///
/// Returns:
///   New weak Global<Value>* or null if local is empty
pub extern fn v8_Value_ToWeakGlobal(
    isolate: *Isolate,
    local: *anyopaque,
    user_data: ?*anyopaque,
    callback: ?WeakCallbackFn,
) ?*Value;

// ============================================================================
// Global Handle Conversion API
// ============================================================================
//
// These functions enable converting Local handles to Global handles for
// cross-scope persistence. This is critical for storing JavaScript callbacks
// (like stream start/write/close callbacks) that need to survive past the
// HandleScope that created them.
//
// V8 Handle Lifecycle:
// - Local<T>: Stack-bound, invalid after HandleScope ends
// - Global<T>: Heap-allocated, persists until explicitly Reset()

/// Convert a Local<Value> to a heap-allocated Global<Value>
///
/// The Local value comes from the current HandleScope. The returned Global
/// pointer persists independently of any HandleScope and must be disposed
/// with v8_Global_Dispose().
///
/// @param isolate - Current V8 isolate
/// @param local - Local value pointer (from callback or conversion)
/// @return New Global<Value>* or null if local is empty
pub extern fn v8_Value_ToGlobal(isolate: *Isolate, local: *anyopaque) ?*Value;

/// Dispose a Global<Value> handle
///
/// Releases the persistent reference, allowing the V8 value to be garbage
/// collected if no other references exist.
///
/// @param global - Global handle to dispose (null-safe)
pub extern fn v8_Global_Dispose(global: ?*Value) void;

/// Check if a Global handle is empty or null
///
/// @param global - Global handle to check
/// @return true if null or empty, false if valid
pub extern fn v8_Global_IsEmpty(global: ?*Value) bool;

/// Get a Local<Value> from a Global<Value>
///
/// Creates a new Local handle in the current HandleScope. The returned
/// Local is valid only within the current HandleScope.
///
/// @param isolate - Current V8 isolate
/// @param global - Global handle to dereference
/// @return Local value pointer or null if global is empty
pub extern fn v8_Global_Get(isolate: *Isolate, global: ?*Value) ?*anyopaque;

/// Convert a Global<Value> to a Global<Function> if it contains a function
///
/// @param global - Global value handle
/// @return The same pointer cast to Global<Function>* if it's a function, null otherwise
pub extern fn v8_Global_ToFunction(global: ?*Value) ?*Function;

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

// ============================================================================
// V8 Snapshot API - Build-Time Heap Serialization
// ============================================================================
//
// This API enables creating V8 heap snapshots that include pre-registered
// WebIDL interfaces. At runtime, loading a snapshot is ~100-1000x faster
// than re-registering all interfaces via FFI calls.
//
// Usage Pattern:
//   Build Time:
//     1. Create SnapshotCreator with external references
//     2. Get the isolate, register all WebIDL interfaces
//     3. Set default context with registered interfaces
//     4. Create blob - returns snapshot data
//     5. Save blob to file
//
//   Runtime:
//     1. Load blob from file
//     2. Create isolate from snapshot with same external references
//     3. Create context from snapshot - interfaces are already registered!
//
// CRITICAL: External references (C++ callback pointers) MUST be provided in
// the SAME ORDER at snapshot creation time and loading time.

/// V8 SnapshotCreator - Opaque handle for snapshot creation
/// Created by v8_SnapshotCreator_New, disposed by v8_SnapshotCreator_Dispose
pub const SnapshotCreator = opaque {};

/// Create a new SnapshotCreator for heap serialization
///
/// The SnapshotCreator owns an isolate that is set up for serialization.
/// The isolate is automatically entered when created.
///
/// @param external_references - Null-terminated array of external reference pointers.
///                              These are C++ callback function pointers that will be
///                              called from snapshotted code. MUST be in same order
///                              at snapshot creation and loading time.
/// @return Opaque pointer to SnapshotCreator (caller owns, must call Dispose)
pub extern fn v8_SnapshotCreator_New(external_references: ?[*]const isize) ?*SnapshotCreator;

/// Get the isolate from a SnapshotCreator
///
/// Use this isolate to set up the global object, register interfaces, etc.
/// The isolate is already entered when returned.
///
/// @param creator - SnapshotCreator handle
/// @return The isolate managed by this SnapshotCreator
pub extern fn v8_SnapshotCreator_GetIsolate(creator: *SnapshotCreator) ?*Isolate;

/// Set the default context for the snapshot
///
/// The snapshot will contain this context's state. When loading the snapshot,
/// contexts created will start with this state.
///
/// IMPORTANT: The context should be fully set up with all interfaces registered.
///
/// @param creator - SnapshotCreator handle
/// @param context - Global handle to the context to snapshot
pub extern fn v8_SnapshotCreator_SetDefaultContext(creator: *SnapshotCreator, context: *Context) void;

/// Create a context and set it as default for snapshot
///
/// This function creates a new context using Local handles (not Global) and
/// immediately sets it as the default context for the snapshot. Using Local
/// handles avoids the "global handle not serialized" error during CreateBlob.
///
/// @param creator - SnapshotCreator handle
/// @return true on success, false on failure
pub extern fn v8_SnapshotCreator_CreateAndSetDefaultContext(creator: *SnapshotCreator) bool;

/// Create a context and add it to snapshot at index
///
/// This function creates a new context using Local handles (not Global) and
/// immediately adds it to the snapshot's context array. Using Local handles
/// avoids the "global handle not serialized" error during CreateBlob.
///
/// @param creator - SnapshotCreator handle
/// @return The index at which the context was added, or maxInt on failure
pub extern fn v8_SnapshotCreator_CreateAndAddContext(creator: *SnapshotCreator) usize;

/// Add context to snapshot at specific index
///
/// This adds a context that can be retrieved via Context::FromSnapshot(isolate, index)
/// after deserialization. The first call returns index 0, second returns 1, etc.
///
/// @param creator - SnapshotCreator handle
/// @param context - Global handle to the context to snapshot
/// @return The index at which the context was added (0-based), or maxInt on error
pub extern fn v8_SnapshotCreator_AddContext(creator: *SnapshotCreator, context: *Context) usize;

/// FunctionCodeHandling for snapshot creation
pub const FunctionCodeHandling = enum(c_int) {
    /// Clear compiled function code (smaller snapshot, slower first execution)
    Clear = 0,
    /// Keep compiled function code (larger snapshot, faster first execution)
    Keep = 1,
};

/// Create the snapshot blob
///
/// Serializes the V8 heap including the default context.
///
/// @param creator - SnapshotCreator handle
/// @param function_code_handling - 0 = clear function code, 1 = keep function code
/// @param out_data - Output: pointer to snapshot data (caller must free with v8_Snapshot_FreeData)
/// @param out_size - Output: size of snapshot data in bytes
/// @return true on success, false on failure
pub extern fn v8_SnapshotCreator_CreateBlob(
    creator: *SnapshotCreator,
    function_code_handling: c_int,
    out_data: *?[*]const u8,
    out_size: *c_int,
) bool;

/// Dispose a SnapshotCreator
///
/// This also disposes the isolate owned by the SnapshotCreator.
/// Must be called after CreateBlob.
///
/// @param creator - SnapshotCreator handle to dispose
pub extern fn v8_SnapshotCreator_Dispose(creator: *SnapshotCreator) void;

/// Free snapshot data allocated by v8_SnapshotCreator_CreateBlob
///
/// @param data - Pointer returned in out_data from CreateBlob
pub extern fn v8_Snapshot_FreeData(data: ?[*]const u8) void;

/// Enable snapshot mode - track Global handles for later cleanup
///
/// When enabled, all Global handles created by the wrapper will be tracked
/// so they can be disposed before calling SnapshotCreator_CreateBlob.
/// V8 requires that there be no outstanding Global handles when creating a snapshot.
pub extern fn v8_Snapshot_EnableMode() void;

/// Disable snapshot mode
///
/// Clears the tracked handles and disables tracking.
pub extern fn v8_Snapshot_DisableMode() void;

/// Clear all tracked Global handles before CreateBlob
///
/// This disposes all Global handles created since EnableMode was called.
/// MUST be called before v8_SnapshotCreator_CreateBlob to avoid
/// "CheckGlobalAndEternalHandles failed" error.
pub extern fn v8_Snapshot_ClearGlobalHandles() void;

/// Create a new isolate from a snapshot blob
///
/// This is the runtime counterpart to SnapshotCreator. The isolate
/// starts with the heap state from the snapshot, so all interfaces
/// that were registered at snapshot time are already available.
///
/// CRITICAL: external_references MUST be the same array (same order)
/// as was used when creating the snapshot.
///
/// @param snapshot_data - Pointer to snapshot blob data
/// @param snapshot_size - Size of snapshot blob in bytes
/// @param external_references - Null-terminated array of external references
///                              (must match snapshot creation order exactly)
/// @return New isolate with snapshot state, or null on failure
pub extern fn v8_Isolate_NewFromSnapshot(
    snapshot_data: [*]const u8,
    snapshot_size: c_int,
    external_references: ?[*]const isize,
) ?*Isolate;

/// Create a context from the snapshot's default context
///
/// This creates a new context based on the default context that was
/// set in the snapshot. The context starts with all the state
/// (including registered interfaces) from snapshot creation time.
///
/// @param isolate - Isolate created from v8_Isolate_NewFromSnapshot
/// @return New context with snapshot state
pub extern fn v8_Context_NewFromSnapshot(isolate: *Isolate) ?*Context;

/// Create a NEW context for an isolate that was created from a snapshot
///
/// Unlike v8_Context_NewFromSnapshot which restores a specific context from the
/// snapshot by index, this creates a completely new context. The new context will
/// have all the V8 builtins from the snapshot's default context as a template.
///
/// @param isolate - Isolate created from v8_Isolate_NewFromSnapshot
/// @return New context (fresh, not from snapshot state)
pub extern fn v8_Context_NewFromSnapshotDefault(isolate: *Isolate) ?*Context;

/// Check if a snapshot blob is valid
///
/// Validates that the snapshot data can be used with the current V8 version.
///
/// @param snapshot_data - Pointer to snapshot blob data
/// @param snapshot_size - Size of snapshot blob in bytes
/// @return true if valid, false if invalid or corrupted
pub extern fn v8_Snapshot_IsValid(
    snapshot_data: [*]const u8,
    snapshot_size: c_int,
) bool;

/// Check if a snapshot blob can be rehashed during deserialization
///
/// If CanBeRehashed() returns false, the snapshot can only be loaded by an
/// isolate with the same hash seed that was used during snapshot creation.
///
/// @param snapshot_data - Pointer to snapshot blob data
/// @param snapshot_size - Size of snapshot blob in bytes
/// @return true if rehashable, false if not
pub extern fn v8_Snapshot_CanBeRehashed(
    snapshot_data: [*]const u8,
    snapshot_size: c_int,
) bool;

// ============================================================================
// C++ Callback Pointers for External References
// ============================================================================
//
// These functions return pointers to C++ callbacks that are used by V8
// FunctionTemplates. For V8 snapshots to work correctly, ALL callback
// function pointers must be registered in the external references array.

/// Get pointer to AsyncIteratorNextCallback
///
/// This callback is used when creating async iterator objects via
/// v8_CreateAsyncIterator. It wraps the Zig next function and handles
/// the V8-specific Promise wrapping.
///
/// @return Function pointer to AsyncIteratorNextCallback
pub extern fn v8_GetAsyncIteratorNextCallback() FunctionCallback;

/// Get pointer to AsyncIteratorReturnCallback
///
/// This callback is used when creating async iterator objects via
/// v8_CreateAsyncIterator. It wraps the Zig return function and handles
/// the V8-specific Promise wrapping.
///
/// @return Function pointer to AsyncIteratorReturnCallback
pub extern fn v8_GetAsyncIteratorReturnCallback() FunctionCallback;

/// Get pointer to AsyncIteratorSelfCallback
///
/// This callback is used for Symbol.asyncIterator on async iterator objects.
/// It simply returns 'this', making the iterator both an iterator and iterable.
///
/// @return Function pointer to AsyncIteratorSelfCallback
pub extern fn v8_GetAsyncIteratorSelfCallback() FunctionCallback;

// ============================================================================
// V8 Locker/Unlocker API - Thread Safety for Multi-Threaded Access
// ============================================================================
//
// V8 isolates are NOT thread-safe. When multiple threads need to access
// the same isolate, they MUST use v8::Locker to acquire exclusive access.
//
// DESIGN NOTE: Locker and Unlocker are typed opaque types rather than
// *anyopaque to provide compile-time type safety at FFI boundaries.
// This follows the same pattern as other V8 types (Isolate, Context, etc.).

/// V8 Locker - Provides exclusive thread access to an isolate
///
/// When created, the locker acquires exclusive access to the isolate.
/// When disposed, the lock is released allowing other threads to acquire it.
/// V8 Lockers are recursive - the same thread can acquire multiple lockers.
pub const Locker = opaque {};

/// V8 Unlocker - Temporarily releases isolate lock for blocking operations
///
/// Used within a locked section to temporarily release the lock so other
/// threads can access the isolate while the current thread performs I/O
/// or other blocking operations that don't require V8 access.
pub const Unlocker = opaque {};

/// Create a new Locker for exclusive isolate access
///
/// This blocks if another thread holds the lock.
/// Returns a typed Locker pointer that must be passed to v8_Locker_Dispose.
///
/// @param isolate - The isolate to lock
/// @return Locker pointer (caller must dispose), or null on failure
pub extern fn v8_Locker_New(isolate: *Isolate) ?*Locker;

/// Dispose a Locker and release the lock
///
/// After calling this, other threads can acquire the lock.
///
/// @param locker - Locker pointer from v8_Locker_New
pub extern fn v8_Locker_Dispose(locker: ?*Locker) void;

/// Check if the current thread holds a lock on the isolate
///
/// @param isolate - The isolate to check
/// @return true if current thread holds the lock
pub extern fn v8_Locker_IsLocked(isolate: *Isolate) bool;

/// Create a new Unlocker to temporarily release the isolate lock
///
/// Use this when performing blocking operations that don't need V8 access.
/// The lock is automatically reacquired when the Unlocker is disposed.
///
/// IMPORTANT: Only call this when you already hold the lock (via Locker).
///
/// @param isolate - The isolate to temporarily unlock
/// @return Unlocker pointer (caller must dispose), or null on failure
pub extern fn v8_Unlocker_New(isolate: *Isolate) ?*Unlocker;

/// Dispose an Unlocker and reacquire the lock
///
/// This blocks if another thread acquired the lock while unlocked.
///
/// @param unlocker - Unlocker pointer from v8_Unlocker_New
pub extern fn v8_Unlocker_Dispose(unlocker: ?*Unlocker) void;

// ============================================================================
// JSON Serialization for Cross-Isolate Message Passing
// ============================================================================
//
// These functions enable serializing V8 values to JSON strings and back,
// which is useful for passing messages between worker isolates and the main
// thread when full structured clone is not available.

/// Serialize a V8 value to JSON string and copy to buffer
///
/// This function uses V8's JSON.stringify to convert a value to its JSON
/// representation, then copies the UTF-8 string to the provided buffer.
///
/// @param context - Raw V8 Context pointer
/// @param value - Raw V8 Value pointer (from callback)
/// @param buffer - Output buffer for UTF-8 JSON string
/// @param buffer_len - Size of output buffer
/// @return Number of bytes written, or -1 on error, or required size if buffer too small
pub extern fn v8_JSON_Stringify_ToBuffer(
    context: *Context,
    value: *Value,
    buffer: [*]u8,
    buffer_len: c_int,
) c_int;

/// Parse JSON string from buffer and return V8 value
///
/// This function uses V8's JSON.parse to convert a JSON string to a V8 value.
///
/// @param context - Raw V8 Context pointer
/// @param json_str - UTF-8 JSON string
/// @param json_len - Length of JSON string
/// @return New Global<Value>* with parsed value or nullptr on error
pub extern fn v8_JSON_Parse_FromBuffer(
    context: *Context,
    json_str: [*]const u8,
    json_len: c_int,
) ?*Value;

// ============================================================================
// HandleScope API for Zig Timer Callbacks
// ============================================================================
//
// V8 requires a HandleScope to be active when creating Local handles.
// When Zig timer callbacks fire from libuv, there's no active HandleScope.
// These functions allow Zig code to create and dispose HandleScopes.
//
// Usage pattern:
//   const scope = v8_HandleScope_New(isolate);
//   defer v8_HandleScope_Dispose(scope);
//   // ... V8 operations that create Local handles ...

/// Opaque HandleScope wrapper
pub const HandleScope = opaque {};

/// Create a new HandleScope for the given isolate
///
/// This must be called before any V8 operation that creates Local handles
/// when called from a non-V8 context (e.g., libuv timer callbacks).
///
/// @param isolate - The V8 isolate
/// @return Opaque pointer to HandleScope wrapper, or null on failure
pub extern fn v8_HandleScope_New(isolate: *Isolate) ?*HandleScope;

/// Dispose a HandleScope created by v8_HandleScope_New
///
/// This must be called when done with V8 operations to properly clean up.
/// Typically used with defer in Zig.
///
/// @param scope - Pointer from v8_HandleScope_New
pub extern fn v8_HandleScope_Dispose(scope: ?*HandleScope) void;

// ============================================================================
// V8 Proxy API - For ObservableArray Exotic Objects
// ============================================================================
//
// The Proxy API allows creating JavaScript Proxy objects from native code.
// This is required for implementing WebIDL ObservableArray which is specified
// as an exotic object backed by a Proxy.
//
// Spec: https://webidl.spec.whatwg.org/#idl-observable-array
//       https://webidl.spec.whatwg.org/#es-observable-array
//
// Key Requirements:
// - Proxy internals (target, handler) must NOT leak to JavaScript
// - Must support custom traps: get, set, deleteProperty, ownKeys, getPrototypeOf
// - ownKeys must return keys in order: indices (ascending) → "length" → strings (insertion)

/// Create a new V8 Proxy object
///
/// Creates a JavaScript Proxy with the specified target and handler.
///
/// @param context - The V8 context
/// @param target - The target object the proxy wraps
/// @param handler - The handler object with trap functions
/// @return Global handle to new Proxy object, or null on error
pub extern fn v8_Proxy_New(context: *Context, target: *Object, handler: *Object) ?*Object;

/// Check if a value is a Proxy
///
/// @param value - The value to check
/// @return true if the value is a Proxy, false otherwise
pub extern fn v8_Value_IsProxy(value: *Value) bool;

/// Get the target of a Proxy
///
/// @param proxy - The Proxy object
/// @return Global handle to the target, or null if not a Proxy
pub extern fn v8_Proxy_GetTarget(proxy: *Object) ?*Value;

/// Get the handler of a Proxy
///
/// @param proxy - The Proxy object
/// @return Global handle to the handler, or null if not a Proxy
pub extern fn v8_Proxy_GetHandler(proxy: *Object) ?*Value;

/// Revoke a Proxy (make it unusable)
///
/// After revocation, any operation on the Proxy will throw TypeError.
///
/// @param proxy - The Proxy object to revoke
pub extern fn v8_Proxy_Revoke(proxy: *Object) void;

/// Check if a Proxy has been revoked
///
/// @param proxy - The Proxy object to check
/// @return true if revoked, false otherwise or if not a Proxy
pub extern fn v8_Proxy_IsRevoked(proxy: *Object) bool;

/// Create a transparent Proxy for legacy platform objects with WebIDL-compliant
/// [[OwnPropertyKeys]] enumeration order: indexed → named → own → symbols
pub extern fn v8_CreateLegacyPlatformObjectProxy(context: *Context, target: *Object) ?*Object;
