//! ECMAScript IteratorRecord
//!
//! Spec: ES §27.1.1.2 The Iterator Record Specification Type
//! WHATWG Streams: Used in ReadableStreamFromIterable
//!
//! Stores iterator state and provides protocol operations.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const V8Resources = @import("v8_resources").V8Resources;
const v8_mod = @import("v8");
const v8 = v8_mod.ffi; // Use FFI functions directly
const v8_engine = v8_mod.engine; // V8 engine helpers

// V8 FFI types from v8 module
const V8Object = v8_mod.Object;
const V8Function = v8_mod.Function;
const V8Value = v8_mod.Value;
const V8Isolate = v8_mod.Isolate;
const V8Context = v8_mod.Context;
const V8Symbol = v8_mod.Symbol;
const V8String = v8_mod.String;

/// Iterator Record - ECMAScript iterator state
///
/// Captures V8 iterator object and next method for async iteration
pub const IteratorRecord = struct {
    /// [[Iterator]] - The iterator object (V8 Global<Object>)
    iterator: *V8Object,

    /// [[NextMethod]] - The next() method (V8 Global<Function>)
    next_method: *V8Function,

    /// [[Done]] - Whether iteration is complete
    done: bool,

    /// V8 context for calls
    isolate: *V8Isolate,
    context: *V8Context,

    /// Resource tracking (for cleanup)
    resources: V8Resources,

    allocator: Allocator,

    /// Create IteratorRecord from async iterable
    /// Spec: GetIterator(obj, async)
    /// ES §7.4.1 GetIterator(obj, kind)
    pub fn fromAsyncIterable(
        allocator: Allocator,
        ctx: runtime.Context,
        async_iterable: *const anyopaque,
    ) !*IteratorRecord {
        const isolate = v8_engine.getIsolate(ctx) orelse return error.NoV8Engine;
        const v8_context = v8_engine.getV8Context(ctx) orelse return error.NoV8Context;

        // Cast to V8 Object
        const iterable_obj: *V8Object = @ptrCast(@alignCast(@constCast(async_iterable)));

        // Step 1: Let method = GetMethod(obj, @@asyncIterator)
        const async_iterator_symbol = v8.v8_Symbol_GetAsyncIterator(isolate) orelse
            return error.TypeError;
        defer v8.v8_Symbol_Dispose(async_iterator_symbol);

        const iterator_method = v8.v8_Object_GetPropertyWithSymbol(
            v8_context,
            iterable_obj,
            async_iterator_symbol,
        ) orelse return error.TypeError;
        defer v8.v8_Value_Dispose(iterator_method);

        // Step 2: If method is undefined, throw TypeError
        if (v8.v8_Value_IsUndefined(iterator_method)) {
            return error.TypeError;
        }

        // Step 3: Let iterator = Call(method, obj)
        if (!v8.v8_Value_IsFunction(iterator_method)) {
            return error.TypeError;
        }

        const iterator_fn: *V8Function = @ptrCast(iterator_method);
        const iterator_result = v8.v8_Function_CallWithReceiver(
            v8_context,
            iterator_fn,
            @ptrCast(iterable_obj),
            0,
            null,
        ) orelse return error.TypeError;
        // Don't defer - we keep this alive

        // Step 4: If iterator is not Object, throw TypeError
        if (!v8.v8_Value_IsObject(iterator_result)) {
            v8.v8_Value_Dispose(iterator_result);
            return error.TypeError;
        }

        const iterator_obj: *V8Object = @ptrCast(iterator_result);

        // Step 5: Let nextMethod = GetV(iterator, "next")
        const next_key = v8.v8_String_NewFromUtf8(isolate, "next", 4) orelse
            return error.OutOfMemory;
        defer v8.v8_String_Dispose(next_key);

        const next_method = v8.v8_Object_Get(
            iterator_obj,
            v8_context,
            @ptrCast(next_key),
        ) orelse {
            v8.v8_Object_Dispose(iterator_obj);
            return error.TypeError;
        };
        // Don't defer - we keep this alive

        // Step 6: If nextMethod is not callable, throw TypeError
        if (!v8.v8_Value_IsFunction(next_method)) {
            v8.v8_Value_Dispose(next_method);
            v8.v8_Object_Dispose(iterator_obj);
            return error.TypeError;
        }

        const next_fn: *V8Function = @ptrCast(next_method);

        // Create IteratorRecord
        const record = try allocator.create(IteratorRecord);
        errdefer allocator.destroy(record);

        // Initialize resource tracking
        var resources = V8Resources.init(allocator);
        errdefer resources.deinit();

        try resources.addObject(iterator_obj);
        try resources.addFunction(next_fn);

        record.* = .{
            .iterator = iterator_obj,
            .next_method = next_fn,
            .done = false,
            .isolate = isolate,
            .context = v8_context,
            .resources = resources,
            .allocator = allocator,
        };

        return record;
    }

    pub fn deinit(self: *IteratorRecord) void {
        self.resources.deinit();
        self.allocator.destroy(self);
    }

    /// IteratorNext - Call next() method
    /// Spec: ES §7.4.2 IteratorNext
    pub fn next(self: *IteratorRecord) !*V8Value {
        if (self.done) {
            return error.IteratorDone;
        }

        // Call iteratorRecord.[[NextMethod]].call(iteratorRecord.[[Iterator]])
        const result = v8.v8_Function_CallWithReceiver(
            self.context,
            self.next_method,
            @ptrCast(self.iterator),
            0,
            null,
        ) orelse return error.CallFailed;

        // Check result is object
        if (!v8.v8_Value_IsObject(result)) {
            v8.v8_Value_Dispose(result);
            return error.TypeError;
        }

        return result;
    }

    /// IteratorComplete - Get "done" property
    /// Spec: ES §7.4.3 IteratorComplete
    pub fn complete(iter_result: *V8Object, context: *V8Context, isolate: *V8Isolate) !bool {
        const done_key = v8.v8_String_NewFromUtf8(isolate, "done", 4) orelse
            return false;
        defer v8.v8_String_Dispose(done_key);

        const done_value = v8.v8_Object_Get(
            iter_result,
            context,
            @ptrCast(done_key),
        ) orelse return false;
        defer v8.v8_Value_Dispose(done_value);

        return v8.v8_Value_BooleanValue(done_value, isolate);
    }

    /// IteratorValue - Get "value" property
    /// Spec: ES §7.4.4 IteratorValue
    pub fn value(iter_result: *V8Object, context: *V8Context, isolate: *V8Isolate) !*V8Value {
        const value_key = v8.v8_String_NewFromUtf8(isolate, "value", 5) orelse
            return error.OutOfMemory;
        defer v8.v8_String_Dispose(value_key);

        return v8.v8_Object_Get(
            iter_result,
            context,
            @ptrCast(value_key),
        ) orelse error.TypeError;
    }

    /// IteratorClose - Call return() method
    /// Spec: ES §7.4.6 IteratorClose
    pub fn close(self: *IteratorRecord, reason: *V8Value) !void {
        if (self.done) {
            return;
        }

        self.done = true;

        // Get return method
        const return_key = v8.v8_String_NewFromUtf8(
            self.isolate,
            "return",
            6,
        ) orelse return;
        defer v8.v8_String_Dispose(return_key);

        const return_method = v8.v8_Object_Get(
            self.iterator,
            self.context,
            @ptrCast(return_key),
        ) orelse return; // No return method
        defer v8.v8_Value_Dispose(return_method);

        if (v8.v8_Value_IsUndefined(return_method)) {
            return; // No return method
        }

        if (!v8.v8_Value_IsFunction(return_method)) {
            return error.TypeError;
        }

        // Call return method with reason
        const return_fn: *V8Function = @ptrCast(return_method);
        var args = [_]*V8Value{reason};

        const result = v8.v8_Function_CallWithReceiver(
            self.context,
            return_fn,
            @ptrCast(self.iterator),
            1,
            &args,
        ) orelse return error.CallFailed;
        defer v8.v8_Value_Dispose(result);

        // Check result is object (or ignore if error)
        if (!v8.v8_Value_IsObject(result)) {
            return error.TypeError;
        }
    }
};
