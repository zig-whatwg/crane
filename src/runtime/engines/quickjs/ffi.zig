//! QuickJS C API FFI Bindings
//!
//! This module provides Zig bindings to the QuickJS C API.
//! QuickJS is a lightweight embeddable JavaScript engine.
//!
//! Reference: https://bellard.org/quickjs/
//!
//! ## Key Differences from V8/JSC
//!
//! - QuickJS is single-threaded (no isolates or context groups)
//! - Uses JSRuntime + JSContext model
//! - Reference counting via JS_FreeValue/JS_DupValue
//! - All values are 64-bit tagged (JSValue is a union, not a pointer)
//! - Classes are registered with JS_NewClass
//! - Much smaller footprint than V8/JSC

const std = @import("std");

// ============================================================================
// Core Types
// ============================================================================

/// QuickJS Runtime - manages memory and GC
/// Each runtime is single-threaded
pub const JSRuntime = opaque {};

/// QuickJS Context - JavaScript execution context
/// Multiple contexts can share a runtime
pub const JSContext = opaque {};

/// QuickJS Value - 64-bit tagged value
/// Unlike V8/JSC, this is a value type, not a pointer
/// It can hold primitives directly or reference objects
pub const JSValue = extern struct {
    u: extern union {
        int32: i32,
        float64: f64,
        ptr: ?*anyopaque,
    },
    tag: i64,

    /// Undefined value constant
    pub const UNDEFINED = JSValue{ .u = .{ .int32 = 0 }, .tag = JS_TAG_UNDEFINED };

    /// Null value constant
    pub const NULL = JSValue{ .u = .{ .int32 = 0 }, .tag = JS_TAG_NULL };

    /// True value constant
    pub const TRUE = JSValue{ .u = .{ .int32 = 1 }, .tag = JS_TAG_BOOL };

    /// False value constant
    pub const FALSE = JSValue{ .u = .{ .int32 = 0 }, .tag = JS_TAG_BOOL };

    /// Exception value constant
    pub const EXCEPTION = JSValue{ .u = .{ .int32 = 0 }, .tag = JS_TAG_EXCEPTION };

    /// Check if value is undefined
    pub fn isUndefined(self: JSValue) bool {
        return self.tag == JS_TAG_UNDEFINED;
    }

    /// Check if value is null
    pub fn isNull(self: JSValue) bool {
        return self.tag == JS_TAG_NULL;
    }

    /// Check if value is a boolean
    pub fn isBool(self: JSValue) bool {
        return self.tag == JS_TAG_BOOL;
    }

    /// Check if value is an integer
    pub fn isInt(self: JSValue) bool {
        return self.tag == JS_TAG_INT;
    }

    /// Check if value is a float
    pub fn isFloat(self: JSValue) bool {
        return self.tag == JS_TAG_FLOAT64;
    }

    /// Check if value is a number (int or float)
    pub fn isNumber(self: JSValue) bool {
        return self.tag == JS_TAG_INT or self.tag == JS_TAG_FLOAT64;
    }

    /// Check if value is a string
    pub fn isString(self: JSValue) bool {
        return self.tag == JS_TAG_STRING;
    }

    /// Check if value is an object
    pub fn isObject(self: JSValue) bool {
        return self.tag == JS_TAG_OBJECT;
    }

    /// Check if value is a symbol
    pub fn isSymbol(self: JSValue) bool {
        return self.tag == JS_TAG_SYMBOL;
    }

    /// Check if value is an exception
    pub fn isException(self: JSValue) bool {
        return self.tag == JS_TAG_EXCEPTION;
    }

    /// Get boolean value
    pub fn toBool(self: JSValue) bool {
        return self.u.int32 != 0;
    }

    /// Get integer value
    pub fn toInt32(self: JSValue) i32 {
        return self.u.int32;
    }

    /// Get float value
    pub fn toFloat64(self: JSValue) f64 {
        return self.u.float64;
    }
};

/// QuickJS Atom - interned string identifier
/// Used for property names and symbols
pub const JSAtom = u32;

/// Class ID for custom classes
pub const JSClassID = u32;

/// Module definition opaque type
pub const JSModuleDef = opaque {};

// ============================================================================
// Value Tags
// ============================================================================

pub const JS_TAG_FIRST: i64 = -11;
pub const JS_TAG_BIG_DECIMAL: i64 = -11;
pub const JS_TAG_BIG_INT: i64 = -10;
pub const JS_TAG_BIG_FLOAT: i64 = -9;
pub const JS_TAG_SYMBOL: i64 = -8;
pub const JS_TAG_STRING: i64 = -7;
pub const JS_TAG_MODULE: i64 = -3;
pub const JS_TAG_FUNCTION_BYTECODE: i64 = -2;
pub const JS_TAG_OBJECT: i64 = -1;
pub const JS_TAG_INT: i64 = 0;
pub const JS_TAG_BOOL: i64 = 1;
pub const JS_TAG_NULL: i64 = 2;
pub const JS_TAG_UNDEFINED: i64 = 3;
pub const JS_TAG_UNINITIALIZED: i64 = 4;
pub const JS_TAG_CATCH_OFFSET: i64 = 5;
pub const JS_TAG_EXCEPTION: i64 = 6;
pub const JS_TAG_FLOAT64: i64 = 7;

// ============================================================================
// Property Flags
// ============================================================================

pub const JS_PROP_CONFIGURABLE: c_int = 1 << 0;
pub const JS_PROP_WRITABLE: c_int = 1 << 1;
pub const JS_PROP_ENUMERABLE: c_int = 1 << 2;
pub const JS_PROP_C_W_E: c_int = JS_PROP_CONFIGURABLE | JS_PROP_WRITABLE | JS_PROP_ENUMERABLE;
pub const JS_PROP_LENGTH: c_int = 1 << 3;
pub const JS_PROP_TMASK: c_int = 3 << 4;
pub const JS_PROP_NORMAL: c_int = 0 << 4;
pub const JS_PROP_GETSET: c_int = 1 << 4;
pub const JS_PROP_VARREF: c_int = 2 << 4;
pub const JS_PROP_AUTOINIT: c_int = 3 << 4;

pub const JS_PROP_HAS_SHIFT: c_int = 8;
pub const JS_PROP_HAS_CONFIGURABLE: c_int = 1 << 8;
pub const JS_PROP_HAS_WRITABLE: c_int = 1 << 9;
pub const JS_PROP_HAS_ENUMERABLE: c_int = 1 << 10;
pub const JS_PROP_HAS_GET: c_int = 1 << 11;
pub const JS_PROP_HAS_SET: c_int = 1 << 12;
pub const JS_PROP_HAS_VALUE: c_int = 1 << 13;

pub const JS_PROP_THROW: c_int = 1 << 14;
pub const JS_PROP_THROW_STRICT: c_int = 1 << 15;
pub const JS_PROP_NO_ADD: c_int = 1 << 16;
pub const JS_PROP_NO_EXOTIC: c_int = 1 << 17;

// ============================================================================
// Eval Flags
// ============================================================================

pub const JS_EVAL_TYPE_GLOBAL: c_int = 0 << 0;
pub const JS_EVAL_TYPE_MODULE: c_int = 1 << 0;
pub const JS_EVAL_TYPE_DIRECT: c_int = 2 << 0;
pub const JS_EVAL_TYPE_INDIRECT: c_int = 3 << 0;
pub const JS_EVAL_TYPE_MASK: c_int = 3 << 0;

pub const JS_EVAL_FLAG_STRICT: c_int = 1 << 3;
pub const JS_EVAL_FLAG_STRIP: c_int = 1 << 4;
pub const JS_EVAL_FLAG_COMPILE_ONLY: c_int = 1 << 5;
pub const JS_EVAL_FLAG_BACKTRACE_BARRIER: c_int = 1 << 6;
pub const JS_EVAL_FLAG_ASYNC: c_int = 1 << 7;

// ============================================================================
// GC Flags
// ============================================================================

pub const JS_GC_PHASE_NONE: c_int = 0;
pub const JS_GC_PHASE_DECREF: c_int = 1;
pub const JS_GC_PHASE_REMOVE_CYCLES: c_int = 2;

// ============================================================================
// Callback Types
// ============================================================================

/// C function callback type
pub const JSCFunction = *const fn (
    ctx: *JSContext,
    this_val: JSValue,
    argc: c_int,
    argv: [*]JSValue,
) callconv(.c) JSValue;

/// C function with magic number callback type
pub const JSCFunctionMagic = *const fn (
    ctx: *JSContext,
    this_val: JSValue,
    argc: c_int,
    argv: [*]JSValue,
    magic: c_int,
) callconv(.c) JSValue;

/// C function with data callback type
pub const JSCFunctionData = *const fn (
    ctx: *JSContext,
    this_val: JSValue,
    argc: c_int,
    argv: [*]JSValue,
    magic: c_int,
    func_data: [*]JSValue,
) callconv(.c) JSValue;

/// Getter callback type
pub const JSGetterFunction = *const fn (
    ctx: *JSContext,
    this_val: JSValue,
) callconv(.c) JSValue;

/// Setter callback type
pub const JSSetterFunction = *const fn (
    ctx: *JSContext,
    this_val: JSValue,
    val: JSValue,
) callconv(.c) JSValue;

/// Class finalizer callback
pub const JSClassFinalizer = *const fn (
    rt: *JSRuntime,
    val: JSValue,
) callconv(.c) void;

/// Class GC mark callback
pub const JSClassGCMark = *const fn (
    rt: *JSRuntime,
    val: JSValue,
    mark_func: *const fn (*JSRuntime, *JSGCObjectHeader) callconv(.c) void,
) callconv(.c) void;

/// Class call callback (for callable objects)
pub const JSClassCall = *const fn (
    ctx: *JSContext,
    func_obj: JSValue,
    this_val: JSValue,
    argc: c_int,
    argv: [*]JSValue,
    flags: c_int,
) callconv(.c) JSValue;

/// GC object header (internal)
pub const JSGCObjectHeader = opaque {};

// ============================================================================
// Class Definition
// ============================================================================

/// Exotic methods for special object behavior
pub const JSClassExoticMethods = extern struct {
    get_own_property: ?*const fn (*JSContext, *JSPropertyDescriptor, JSValue, JSAtom) callconv(.c) c_int = null,
    get_own_property_names: ?*const fn (*JSContext, *[*]JSPropertyEnum, *u32, JSValue) callconv(.c) c_int = null,
    delete_property: ?*const fn (*JSContext, JSValue, JSAtom) callconv(.c) c_int = null,
    define_own_property: ?*const fn (*JSContext, JSValue, JSAtom, JSValue, JSValue, JSValue, c_int) callconv(.c) c_int = null,
    has_property: ?*const fn (*JSContext, JSValue, JSAtom) callconv(.c) c_int = null,
    get_property: ?*const fn (*JSContext, JSValue, JSAtom, JSValue) callconv(.c) JSValue = null,
    set_property: ?*const fn (*JSContext, JSValue, JSAtom, JSValue, JSValue, c_int) callconv(.c) c_int = null,
};

/// Property descriptor
pub const JSPropertyDescriptor = extern struct {
    flags: c_int = 0,
    value: JSValue = JSValue.UNDEFINED,
    getter: JSValue = JSValue.UNDEFINED,
    setter: JSValue = JSValue.UNDEFINED,
};

/// Property enumeration entry
pub const JSPropertyEnum = extern struct {
    is_enumerable: bool = false,
    atom: JSAtom = 0,
};

/// Class definition structure
pub const JSClassDef = extern struct {
    class_name: [*:0]const u8,
    finalizer: ?JSClassFinalizer = null,
    gc_mark: ?JSClassGCMark = null,
    call: ?JSClassCall = null,
    exotic: ?*const JSClassExoticMethods = null,
};

// ============================================================================
// C Function Entry Definition
// ============================================================================

/// Function list entry for bulk registration
pub const JSCFunctionListEntry = extern struct {
    name: [*:0]const u8,
    prop_flags: u8,
    def_type: u8,
    magic: i16,
    u: extern union {
        func: extern struct {
            length: u8,
            cproto: u8,
            cfunc: JSCFunction,
        },
        getset: extern struct {
            get: JSGetterFunction,
            set: JSSetterFunction,
        },
        alias: extern struct {
            name: [*:0]const u8,
            base: c_int,
        },
        prop_list: extern struct {
            tab: [*]const JSCFunctionListEntry,
            len: c_int,
        },
        str: [*:0]const u8,
        i32_val: i32,
        i64_val: i64,
        f64_val: f64,
    },
};

/// C function prototype types
pub const JS_CFUNC_generic: u8 = 0;
pub const JS_CFUNC_generic_magic: u8 = 1;
pub const JS_CFUNC_constructor: u8 = 2;
pub const JS_CFUNC_constructor_magic: u8 = 3;
pub const JS_CFUNC_constructor_or_func: u8 = 4;
pub const JS_CFUNC_constructor_or_func_magic: u8 = 5;
pub const JS_CFUNC_f_f: u8 = 6;
pub const JS_CFUNC_f_f_f: u8 = 7;
pub const JS_CFUNC_getter: u8 = 8;
pub const JS_CFUNC_setter: u8 = 9;
pub const JS_CFUNC_getter_magic: u8 = 10;
pub const JS_CFUNC_setter_magic: u8 = 11;
pub const JS_CFUNC_iterator_next: u8 = 12;

/// Definition types
pub const JS_DEF_CFUNC: u8 = 0;
pub const JS_DEF_CGETSET: u8 = 1;
pub const JS_DEF_CGETSET_MAGIC: u8 = 2;
pub const JS_DEF_PROP_STRING: u8 = 3;
pub const JS_DEF_PROP_INT32: u8 = 4;
pub const JS_DEF_PROP_INT64: u8 = 5;
pub const JS_DEF_PROP_DOUBLE: u8 = 6;
pub const JS_DEF_PROP_UNDEFINED: u8 = 7;
pub const JS_DEF_OBJECT: u8 = 8;
pub const JS_DEF_ALIAS: u8 = 9;

// ============================================================================
// Runtime Functions
// ============================================================================

/// Create a new QuickJS runtime
pub extern "quickjs" fn JS_NewRuntime() ?*JSRuntime;

/// Free a QuickJS runtime
pub extern "quickjs" fn JS_FreeRuntime(rt: *JSRuntime) void;

/// Set runtime info (for debugging)
pub extern "quickjs" fn JS_SetRuntimeInfo(rt: *JSRuntime, info: [*:0]const u8) void;

/// Set memory limit for runtime
pub extern "quickjs" fn JS_SetMemoryLimit(rt: *JSRuntime, limit: usize) void;

/// Set GC threshold
pub extern "quickjs" fn JS_SetGCThreshold(rt: *JSRuntime, gc_threshold: usize) void;

/// Set maximum stack size
pub extern "quickjs" fn JS_SetMaxStackSize(rt: *JSRuntime, stack_size: usize) void;

/// Run garbage collection
pub extern "quickjs" fn JS_RunGC(rt: *JSRuntime) void;

/// Check if runtime is in GC
pub extern "quickjs" fn JS_IsLiveObject(rt: *JSRuntime, obj: JSValue) bool;

// ============================================================================
// Context Functions
// ============================================================================

/// Create a new context in the runtime
pub extern "quickjs" fn JS_NewContext(rt: *JSRuntime) ?*JSContext;

/// Free a context
pub extern "quickjs" fn JS_FreeContext(ctx: *JSContext) void;

/// Duplicate a context (increase ref count)
pub extern "quickjs" fn JS_DupContext(ctx: *JSContext) *JSContext;

/// Get runtime from context
pub extern "quickjs" fn JS_GetRuntime(ctx: *JSContext) *JSRuntime;

/// Set class prototype
pub extern "quickjs" fn JS_SetClassProto(ctx: *JSContext, class_id: JSClassID, obj: JSValue) void;

/// Get class prototype
pub extern "quickjs" fn JS_GetClassProto(ctx: *JSContext, class_id: JSClassID) JSValue;

// ============================================================================
// Class Functions
// ============================================================================

/// Allocate a new class ID
pub extern "quickjs" fn JS_NewClassID(pclass_id: *JSClassID) JSClassID;

/// Create a new class
pub extern "quickjs" fn JS_NewClass(rt: *JSRuntime, class_id: JSClassID, class_def: *const JSClassDef) c_int;

/// Check if a class is registered
pub extern "quickjs" fn JS_IsRegisteredClass(rt: *JSRuntime, class_id: JSClassID) bool;

// ============================================================================
// Value Creation Functions
// ============================================================================

/// Create a new object with class
pub extern "quickjs" fn JS_NewObjectClass(ctx: *JSContext, class_id: c_int) JSValue;

/// Create a new object with prototype
pub extern "quickjs" fn JS_NewObjectProto(ctx: *JSContext, proto: JSValue) JSValue;

/// Create a new object with class and prototype
pub extern "quickjs" fn JS_NewObjectProtoClass(ctx: *JSContext, proto: JSValue, class_id: JSClassID) JSValue;

/// Create a new plain object
pub extern "quickjs" fn JS_NewObject(ctx: *JSContext) JSValue;

/// Create a new array
pub extern "quickjs" fn JS_NewArray(ctx: *JSContext) JSValue;

/// Check if value is an array
pub extern "quickjs" fn JS_IsArray(ctx: *JSContext, val: JSValue) c_int;

/// Create a boolean value
pub inline fn JS_NewBool(ctx: *JSContext, val: bool) JSValue {
    _ = ctx;
    return if (val) JSValue.TRUE else JSValue.FALSE;
}

/// Create an integer value
pub inline fn JS_NewInt32(ctx: *JSContext, val: i32) JSValue {
    _ = ctx;
    return JSValue{ .u = .{ .int32 = val }, .tag = JS_TAG_INT };
}

/// Create a float value
pub inline fn JS_NewFloat64(ctx: *JSContext, val: f64) JSValue {
    _ = ctx;
    return JSValue{ .u = .{ .float64 = val }, .tag = JS_TAG_FLOAT64 };
}

/// Create a string value from C string
pub extern "quickjs" fn JS_NewString(ctx: *JSContext, str: [*:0]const u8) JSValue;

/// Create a string value from length-delimited data
pub extern "quickjs" fn JS_NewStringLen(ctx: *JSContext, str: [*]const u8, len: usize) JSValue;

/// Create an ArrayBuffer
pub extern "quickjs" fn JS_NewArrayBuffer(
    ctx: *JSContext,
    buf: [*]u8,
    len: usize,
    free_func: ?*const fn (*JSRuntime, ?*anyopaque, ?*anyopaque) callconv(.c) void,
    user_data: ?*anyopaque,
    is_shared: bool,
) JSValue;

/// Create an ArrayBuffer by copying data
pub extern "quickjs" fn JS_NewArrayBufferCopy(ctx: *JSContext, buf: [*]const u8, len: usize) JSValue;

/// Get ArrayBuffer data
pub extern "quickjs" fn JS_GetArrayBuffer(ctx: *JSContext, psize: *usize, obj: JSValue) ?[*]u8;

/// Create a typed array
pub extern "quickjs" fn JS_NewTypedArray(
    ctx: *JSContext,
    argc: c_int,
    argv: [*]JSValue,
    magic: c_int,
) JSValue;

// ============================================================================
// Value Manipulation Functions
// ============================================================================

/// Duplicate a value (increase ref count for objects)
pub extern "quickjs" fn JS_DupValue(ctx: *JSContext, v: JSValue) JSValue;

/// Free a value (decrease ref count for objects)
pub extern "quickjs" fn JS_FreeValue(ctx: *JSContext, v: JSValue) void;

/// Free a value (runtime version, for use in finalizers)
pub extern "quickjs" fn JS_FreeValueRT(rt: *JSRuntime, v: JSValue) void;

/// Convert value to boolean
pub extern "quickjs" fn JS_ToBool(ctx: *JSContext, val: JSValue) c_int;

/// Convert value to int32
pub extern "quickjs" fn JS_ToInt32(ctx: *JSContext, pres: *i32, val: JSValue) c_int;

/// Convert value to int64
pub extern "quickjs" fn JS_ToInt64(ctx: *JSContext, pres: *i64, val: JSValue) c_int;

/// Convert value to float64
pub extern "quickjs" fn JS_ToFloat64(ctx: *JSContext, pres: *f64, val: JSValue) c_int;

/// Convert value to string
pub extern "quickjs" fn JS_ToString(ctx: *JSContext, val: JSValue) JSValue;

/// Get C string from value (must be freed with JS_FreeCString)
pub extern "quickjs" fn JS_ToCString(ctx: *JSContext, val: JSValue) ?[*:0]const u8;

/// Get C string with length from value
pub extern "quickjs" fn JS_ToCStringLen(ctx: *JSContext, plen: *usize, val: JSValue) ?[*:0]const u8;

/// Free C string obtained from JS_ToCString
pub extern "quickjs" fn JS_FreeCString(ctx: *JSContext, ptr: [*:0]const u8) void;

// ============================================================================
// Object Functions
// ============================================================================

/// Set opaque data on object
pub extern "quickjs" fn JS_SetOpaque(obj: JSValue, user_opaque: ?*anyopaque) void;

/// Get opaque data from object
pub extern "quickjs" fn JS_GetOpaque(obj: JSValue, class_id: JSClassID) ?*anyopaque;

/// Get opaque data with class check
pub extern "quickjs" fn JS_GetOpaque2(ctx: *JSContext, obj: JSValue, class_id: JSClassID) ?*anyopaque;

/// Get property by atom
pub extern "quickjs" fn JS_GetProperty(ctx: *JSContext, this_obj: JSValue, prop: JSAtom) JSValue;

/// Get property by string
pub extern "quickjs" fn JS_GetPropertyStr(ctx: *JSContext, this_obj: JSValue, prop: [*:0]const u8) JSValue;

/// Get property by index
pub extern "quickjs" fn JS_GetPropertyUint32(ctx: *JSContext, this_obj: JSValue, idx: u32) JSValue;

/// Set property by atom
pub extern "quickjs" fn JS_SetProperty(ctx: *JSContext, this_obj: JSValue, prop: JSAtom, val: JSValue) c_int;

/// Set property by string
pub extern "quickjs" fn JS_SetPropertyStr(ctx: *JSContext, this_obj: JSValue, prop: [*:0]const u8, val: JSValue) c_int;

/// Set property by index
pub extern "quickjs" fn JS_SetPropertyUint32(ctx: *JSContext, this_obj: JSValue, idx: u32, val: JSValue) c_int;

/// Define property
pub extern "quickjs" fn JS_DefineProperty(
    ctx: *JSContext,
    this_obj: JSValue,
    prop: JSAtom,
    val: JSValue,
    getter: JSValue,
    setter: JSValue,
    flags: c_int,
) c_int;

/// Define property by string
pub extern "quickjs" fn JS_DefinePropertyValueStr(
    ctx: *JSContext,
    this_obj: JSValue,
    prop: [*:0]const u8,
    val: JSValue,
    flags: c_int,
) c_int;

/// Has property
pub extern "quickjs" fn JS_HasProperty(ctx: *JSContext, this_obj: JSValue, prop: JSAtom) c_int;

/// Delete property
pub extern "quickjs" fn JS_DeleteProperty(ctx: *JSContext, this_obj: JSValue, prop: JSAtom, flags: c_int) c_int;

/// Set prototype
pub extern "quickjs" fn JS_SetPrototype(ctx: *JSContext, obj: JSValue, proto_val: JSValue) c_int;

/// Get prototype
pub extern "quickjs" fn JS_GetPrototype(ctx: *JSContext, val: JSValue) JSValue;

// ============================================================================
// Function Functions
// ============================================================================

/// Create a new C function
pub extern "quickjs" fn JS_NewCFunction(ctx: *JSContext, func: JSCFunction, name: [*:0]const u8, length: c_int) JSValue;

/// Create a new C function with magic
pub extern "quickjs" fn JS_NewCFunction2(
    ctx: *JSContext,
    func: JSCFunction,
    name: [*:0]const u8,
    length: c_int,
    cproto: c_int,
    magic: c_int,
) JSValue;

/// Create a new C function with data
pub extern "quickjs" fn JS_NewCFunctionData(
    ctx: *JSContext,
    func: JSCFunctionData,
    length: c_int,
    magic: c_int,
    data_len: c_int,
    data: [*]JSValue,
) JSValue;

/// Set constructor bit on function
pub extern "quickjs" fn JS_SetConstructorBit(ctx: *JSContext, func_obj: JSValue, val: bool) void;

/// Call a function
pub extern "quickjs" fn JS_Call(
    ctx: *JSContext,
    func_obj: JSValue,
    this_obj: JSValue,
    argc: c_int,
    argv: [*]const JSValue,
) JSValue;

/// Invoke a method
pub extern "quickjs" fn JS_Invoke(
    ctx: *JSContext,
    this_obj: JSValue,
    atom: JSAtom,
    argc: c_int,
    argv: [*]const JSValue,
) JSValue;

/// Call a constructor
pub extern "quickjs" fn JS_CallConstructor(
    ctx: *JSContext,
    func_obj: JSValue,
    argc: c_int,
    argv: [*]const JSValue,
) JSValue;

/// Call a constructor with new target
pub extern "quickjs" fn JS_CallConstructor2(
    ctx: *JSContext,
    func_obj: JSValue,
    new_target: JSValue,
    argc: c_int,
    argv: [*]const JSValue,
) JSValue;

/// Check if object is a function
pub extern "quickjs" fn JS_IsFunction(ctx: *JSContext, val: JSValue) bool;

/// Check if object is a constructor
pub extern "quickjs" fn JS_IsConstructor(ctx: *JSContext, val: JSValue) bool;

// ============================================================================
// Promise Functions
// ============================================================================

/// Create a new promise with resolving functions
pub extern "quickjs" fn JS_NewPromiseCapability(ctx: *JSContext, resolving_funcs: *[2]JSValue) JSValue;

/// Check if value is a promise (unresolved)
pub extern "quickjs" fn JS_IsPromise(ctx: *JSContext, val: JSValue) bool;

/// Get promise state (-1=pending, 0=fulfilled, 1=rejected)
pub extern "quickjs" fn JS_PromiseState(ctx: *JSContext, promise: JSValue) c_int;

/// Get promise result (only valid if not pending)
pub extern "quickjs" fn JS_PromiseResult(ctx: *JSContext, promise: JSValue) JSValue;

// ============================================================================
// Exception Functions
// ============================================================================

/// Throw an exception
pub extern "quickjs" fn JS_Throw(ctx: *JSContext, obj: JSValue) JSValue;

/// Get the current exception (and clear it)
pub extern "quickjs" fn JS_GetException(ctx: *JSContext) JSValue;

/// Check if there's a pending exception
pub extern "quickjs" fn JS_IsException(val: JSValue) bool;

/// Reset uncatchable error flag
pub extern "quickjs" fn JS_ResetUncatchableError(ctx: *JSContext) void;

/// Create a new Error object
pub extern "quickjs" fn JS_NewError(ctx: *JSContext) JSValue;

/// Throw a SyntaxError
pub extern "quickjs" fn JS_ThrowSyntaxError(ctx: *JSContext, fmt: [*:0]const u8, ...) JSValue;

/// Throw a TypeError
pub extern "quickjs" fn JS_ThrowTypeError(ctx: *JSContext, fmt: [*:0]const u8, ...) JSValue;

/// Throw a ReferenceError
pub extern "quickjs" fn JS_ThrowReferenceError(ctx: *JSContext, fmt: [*:0]const u8, ...) JSValue;

/// Throw a RangeError
pub extern "quickjs" fn JS_ThrowRangeError(ctx: *JSContext, fmt: [*:0]const u8, ...) JSValue;

/// Throw an InternalError
pub extern "quickjs" fn JS_ThrowInternalError(ctx: *JSContext, fmt: [*:0]const u8, ...) JSValue;

/// Throw an OutOfMemory error
pub extern "quickjs" fn JS_ThrowOutOfMemory(ctx: *JSContext) JSValue;

// ============================================================================
// Eval Functions
// ============================================================================

/// Evaluate JavaScript code
pub extern "quickjs" fn JS_Eval(
    ctx: *JSContext,
    input: [*]const u8,
    input_len: usize,
    filename: [*:0]const u8,
    eval_flags: c_int,
) JSValue;

/// Evaluate a script file
pub extern "quickjs" fn JS_EvalFile(ctx: *JSContext, filename: [*:0]const u8, eval_flags: c_int) JSValue;

// ============================================================================
// Global Object Functions
// ============================================================================

/// Get the global object
pub extern "quickjs" fn JS_GetGlobalObject(ctx: *JSContext) JSValue;

/// Set function property on object
pub extern "quickjs" fn JS_SetPropertyFunctionList(
    ctx: *JSContext,
    obj: JSValue,
    tab: [*]const JSCFunctionListEntry,
    len: c_int,
) void;

// ============================================================================
// Atom Functions
// ============================================================================

/// Create atom from string
pub extern "quickjs" fn JS_NewAtom(ctx: *JSContext, str: [*:0]const u8) JSAtom;

/// Create atom from string with length
pub extern "quickjs" fn JS_NewAtomLen(ctx: *JSContext, str: [*]const u8, len: usize) JSAtom;

/// Free an atom
pub extern "quickjs" fn JS_FreeAtom(ctx: *JSContext, atom: JSAtom) void;

/// Free an atom (runtime version)
pub extern "quickjs" fn JS_FreeAtomRT(rt: *JSRuntime, atom: JSAtom) void;

/// Get atom string
pub extern "quickjs" fn JS_AtomToCString(ctx: *JSContext, atom: JSAtom) ?[*:0]const u8;

/// Convert atom to value
pub extern "quickjs" fn JS_AtomToValue(ctx: *JSContext, atom: JSAtom) JSValue;

/// Convert atom to string
pub extern "quickjs" fn JS_AtomToString(ctx: *JSContext, atom: JSAtom) JSValue;

// ============================================================================
// JSON Functions
// ============================================================================

/// Parse JSON string
pub extern "quickjs" fn JS_ParseJSON(ctx: *JSContext, buf: [*]const u8, buf_len: usize, filename: [*:0]const u8) JSValue;

/// Stringify to JSON
pub extern "quickjs" fn JS_JSONStringify(ctx: *JSContext, obj: JSValue, replacer: JSValue, space0: JSValue) JSValue;

// ============================================================================
// Module Functions
// ============================================================================

// Note: Module functions use JS_Eval with JS_EVAL_TYPE_MODULE flag
// The JS_Eval function is already declared in the Eval Functions section

// ============================================================================
// Type Checking Functions
// ============================================================================

/// Check if value is an instance of a class
pub extern "quickjs" fn JS_IsInstanceOf(ctx: *JSContext, val: JSValue, obj: JSValue) c_int;

/// Get the class ID of an object
pub fn JS_GetClassID(val: JSValue) JSClassID {
    if (val.tag != JS_TAG_OBJECT) return 0;
    // This would need internal QuickJS header access
    // For now return 0 as placeholder
    return 0;
}

// ============================================================================
// Symbol Functions
// ============================================================================

/// Get well-known symbol (e.g., Symbol.iterator)
pub extern "quickjs" fn JS_GetPropertyInternal(
    ctx: *JSContext,
    obj: JSValue,
    prop: JSAtom,
    receiver: JSValue,
    throw_ref_error: bool,
) JSValue;

// ============================================================================
// Helper Functions (implemented in Zig)
// ============================================================================

/// Create a JSValue from a Zig slice (creates new string)
pub fn createString(ctx: *JSContext, bytes: []const u8) JSValue {
    if (bytes.len == 0) {
        return JS_NewString(ctx, "");
    }
    return JS_NewStringLen(ctx, bytes.ptr, bytes.len);
}

/// Extract a Zig slice from a JSValue string (must free result with allocator)
pub fn extractString(ctx: *JSContext, val: JSValue, allocator: std.mem.Allocator) ![]u8 {
    var len: usize = 0;
    const cstr = JS_ToCStringLen(ctx, &len, val) orelse return error.InvalidString;
    defer JS_FreeCString(ctx, cstr);

    const result = try allocator.alloc(u8, len);
    @memcpy(result, cstr[0..len]);
    return result;
}

// ============================================================================
// Tests
// ============================================================================

test "JSValue - tag checks" {
    const testing = std.testing;

    try testing.expect(JSValue.UNDEFINED.isUndefined());
    try testing.expect(JSValue.NULL.isNull());
    try testing.expect(JSValue.TRUE.isBool());
    try testing.expect(JSValue.FALSE.isBool());
    try testing.expect(JSValue.EXCEPTION.isException());
}

test "JSValue - bool conversion" {
    const testing = std.testing;

    try testing.expect(JSValue.TRUE.toBool() == true);
    try testing.expect(JSValue.FALSE.toBool() == false);
}

test "JSClassDef - struct layout" {
    const testing = std.testing;

    try testing.expect(@typeInfo(JSClassDef).@"struct".layout == .@"extern");
}
