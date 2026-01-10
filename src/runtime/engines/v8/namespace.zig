//! Comptime V8 Namespace Binding Generator
//!
//! This module uses Zig's comptime reflection to automatically generate V8 bindings
//! for WebIDL namespaces. It introspects generated namespace structs and creates
//! V8 function callbacks for all operations.
//!
//! ## How It Works
//!
//! 1. Takes a generated namespace struct (e.g., `console.console`)
//! 2. Uses `@typeInfo()` to find all `call_*` methods
//! 3. Generates V8 callback wrappers at compile time
//! 4. Returns a type with methods to register the namespace in V8
//!
//! ## Usage Example
//!
//! ```zig
//! const ConsoleBinding = V8Namespace(@import("generated/namespaces/console.zig").console);
//!
//! // In your V8 initialization code:
//! ConsoleBinding.registerGlobal(isolate, context, "console");
//! ```
//!
//! ## Benefits
//!
//! - Zero generated C++ code
//! - Type-safe at compile time
//! - Direct Zig ↔ V8 integration
//! - Full error checking
//! - Optimal performance (no intermediate layers)

const std = @import("std");
const v8 = @import("ffi.zig");
const conv = @import("conversions.zig");
const runtime = @import("runtime");

/// Global runtime context for V8 namespace operations
/// TODO: This should be stored per-isolate, not globally
var global_context: ?*runtime.ContextData = null;
var global_context_mutex = std.Thread.Mutex{};

/// Get the global runtime context (may return null if not yet initialized)
pub fn getGlobalContext() ?runtime.Context {
    global_context_mutex.lock();
    defer global_context_mutex.unlock();
    return global_context;
}

/// Clear the global runtime context
///
/// MUST be called before disposing an isolate to prevent use-after-free.
/// The global context holds pointers to V8-specific data that becomes invalid
/// when the isolate is disposed.
///
/// Called by template_registry.clear() as part of isolate cleanup.
pub fn clearGlobalContext() void {
    global_context_mutex.lock();
    defer global_context_mutex.unlock();
    if (global_context) |ctx| {
        // Deinit the context data to free resources
        ctx.deinit();
        // Free the ContextData struct itself
        std.heap.page_allocator.destroy(ctx);
    }
    global_context = null;
}

/// Comptime V8 namespace binding generator
///
/// Takes a WebIDL namespace struct and generates V8 bindings for all its operations.
///
/// Template:
/// - `Namespace`: Generated namespace struct type (e.g., `console.console`)
///
/// Returns:
/// A type with methods to register the namespace in V8:
/// - `registerGlobal(isolate, context, name)` - Register as global object
/// - `createObject(isolate, context)` - Create namespace object
pub fn V8Namespace(comptime Namespace: type) type {
    // Method metadata extracted at compile time
    const MethodInfo = struct {
        name: []const u8, // JavaScript name (e.g., "log")
        zig_name: []const u8, // Zig function name (e.g., "call_log")
        param_count: usize, // Number of parameters
    };

    // Validate namespace type at compile time
    const ns_info = @typeInfo(Namespace);
    if (ns_info != .@"struct") {
        @compileError("V8Namespace requires a struct type, got: " ++ @typeName(Namespace));
    }

    // Extract all call_* methods at compile time
    const methods = comptime blk: {
        var method_list: []const MethodInfo = &.{};
        for (ns_info.@"struct".decls) |decl| {
            if (std.mem.startsWith(u8, decl.name, "call_")) {
                const method_name = decl.name[5..]; // Remove "call_" prefix
                const method_fn = @field(Namespace, decl.name);
                const fn_info = @typeInfo(@TypeOf(method_fn));

                if (fn_info != .@"fn") {
                    @compileError("Expected function for " ++ decl.name);
                }

                method_list = method_list ++ [_]MethodInfo{.{
                    .name = method_name,
                    .zig_name = decl.name,
                    .param_count = fn_info.@"fn".params.len,
                }};
            }
        }
        break :blk method_list;
    };

    return struct {
        const Self = @This();

        /// All methods in this namespace
        const all_methods = methods;

        /// Register all namespace callbacks as external references
        ///
        /// This MUST be called before creating a V8 snapshot. V8 snapshots
        /// require all callback function pointers to be registered in the
        /// external references array. Without this, snapshot creation fails
        /// with "Unknown external reference" errors.
        ///
        /// ## Usage
        ///
        /// ```zig
        /// // Before creating snapshot:
        /// const ConsoleBinding = V8Namespace(console.console);
        /// ConsoleBinding.registerExternalReferences();
        /// ```
        pub fn registerExternalReferences() void {
            const ext_refs = @import("external_references.zig");

            // Register callback for each method in the namespace
            inline for (all_methods) |method| {
                const callback = generateCallback(method);
                ext_refs.registerCallbackRuntime(callback);
            }
        }

        /// Register namespace as a global object in V8
        ///
        /// Creates a new object with all namespace methods and attaches it
        /// to the global object with the specified name.
        ///
        /// Example:
        /// ```zig
        /// ConsoleBinding.registerGlobal(isolate, context, "console");
        /// // Now JavaScript can call: console.log("Hello")
        /// ```
        pub fn registerGlobal(
            isolate: *v8.Isolate,
            context: *v8.Context,
            name: []const u8,
        ) void {
            const ns_object = createObject(isolate, context);
            const global = v8.v8_Context_Global(context) orelse return;

            const key_str = v8.v8_String_NewFromUtf8(
                isolate,
                name.ptr,
                @intCast(name.len),
            ) orelse return;

            // Per WebIDL spec, namespaces on global object must be:
            // - writable: true
            // - enumerable: false (not in for...in loops or Object.keys)
            // - configurable: true
            _ = v8.v8_Object_DefineProperty(
                global,
                context,
                @ptrCast(key_str),
                @ptrCast(ns_object),
                true, // writable = true
                false, // enumerable = false (per WebIDL spec)
                true, // configurable = true
            );
        }

        /// Create a new namespace object with all methods
        ///
        /// Returns a V8 object with all namespace operations attached as methods.
        pub fn createObject(
            isolate: *v8.Isolate,
            context: *v8.Context,
        ) ?*v8.Object {
            _ = context;

            const object = v8.v8_Object_New(isolate) orelse return null;

            // Register all methods at compile time
            inline for (all_methods) |method| {
                registerMethod(isolate, object, method);
            }

            return object;
        }

        /// Register a single method on the namespace object
        fn registerMethod(
            isolate: *v8.Isolate,
            object: *v8.Object,
            comptime method: MethodInfo,
        ) void {
            // Create V8 function template for this method
            const callback = comptime generateCallback(method);
            const fn_template = v8.v8_FunctionTemplate_New(isolate, callback, null) orelse return;
            const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
            const fn_obj = v8.v8_FunctionTemplate_GetFunction(
                fn_template,
                context,
            ) orelse return;

            // Add function to object
            const name_str = v8.v8_String_NewFromUtf8(
                isolate,
                method.name.ptr,
                @intCast(method.name.len),
            ) orelse return;

            _ = v8.v8_Object_Set(
                object,
                context,
                @ptrCast(name_str),
                @ptrCast(fn_obj),
            );
        }

        /// Generate V8 callback wrapper for a namespace method
        ///
        /// This is the magic that makes it all work! We create a callback function
        /// at compile time that:
        /// 1. Extracts arguments from V8
        /// 2. Converts them to Zig types
        /// 3. Calls the actual namespace implementation
        /// 4. Converts return value back to V8
        ///
        /// All type checking happens at compile time!
        fn generateCallback(comptime method: MethodInfo) v8.FunctionCallback {
            const namespace_fn = @field(Namespace, method.zig_name);
            const fn_type_info = @typeInfo(@TypeOf(namespace_fn)).@"fn";
            const return_type = fn_type_info.return_type orelse void;

            const Wrapper = struct {
                fn callback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
                    const isolate = info.getIsolate();
                    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
                        conv.throwTypeError(isolate, "Failed to get current context");
                        return;
                    };

                    // Calculate required params: count params before variadic slice
                    const argc = info.length();
                    const required_params = comptime blk: {
                        var count: usize = 0;
                        for (fn_type_info.params) |param| {
                            const ParamType = param.type.?;
                            // Stop counting at variadic parameters or runtime.Context
                            if (ParamType == []const *const anyopaque or
                                ParamType == []const runtime.ConsoleValue or
                                ParamType == runtime.Context)
                            {
                                continue;
                            }
                            count += 1;
                        }
                        break :blk count;
                    };

                    if (argc < required_params) {
                        conv.throwTypeError(
                            isolate,
                            "Not enough arguments: expected " ++
                                std.fmt.comptimePrint("{d}", .{required_params}),
                        );
                        return;
                    }

                    // Extract and convert arguments at compile time based on parameter types
                    var args: std.meta.ArgsTuple(@TypeOf(namespace_fn)) = undefined;

                    // Use stack allocator for temporary allocations during argument extraction
                    var stack_buffer: [4096]u8 = undefined;
                    var fba = std.heap.FixedBufferAllocator.init(&stack_buffer);
                    const allocator = fba.allocator();

                    // Track JS argument index separately from param index
                    var js_arg_idx: c_int = 0;

                    // Extract each argument based on its type
                    inline for (fn_type_info.params, 0..) |param, i| {
                        const ParamType = param.type.?;

                        // Handle special case: runtime.Context
                        if (ParamType == runtime.Context) {
                            // Get or create the global context
                            global_context_mutex.lock();
                            defer global_context_mutex.unlock();

                            if (global_context == null) {
                                // Initialize global context with colored logger
                                // Use a leaked allocator for now (TODO: proper lifecycle)
                                const gpa = std.heap.page_allocator;
                                global_context = gpa.create(runtime.ContextData) catch {
                                    conv.throwTypeError(isolate, "Failed to create runtime context");
                                    return;
                                };
                                global_context.?.* = runtime.ContextData.init(gpa, .{
                                    .colored = true,
                                    .engine_ctx = @ptrCast(context),
                                }) catch {
                                    conv.throwTypeError(isolate, "Failed to initialize runtime context");
                                    return;
                                };
                            }

                            args[i] = global_context.?;
                            // runtime.Context doesn't consume a JS argument
                            continue;
                        }

                        // Handle slice of ConsoleValue (used for console.log, etc.)
                        if (ParamType == []const runtime.ConsoleValue) {
                            // Convert remaining JS arguments to ConsoleValues
                            const remaining = argc - js_arg_idx;
                            const remaining_args: usize = if (remaining > 0) @intCast(remaining) else 0;
                            const arg_slice = allocator.alloc(runtime.ConsoleValue, remaining_args) catch {
                                conv.throwTypeError(isolate, "Failed to allocate console values");
                                return;
                            };
                            for (0..remaining_args) |j| {
                                const v8_value = info.get(@intCast(js_arg_idx + @as(c_int, @intCast(j))));
                                arg_slice[j] = conv.toConsoleValue(allocator, isolate, context, v8_value) catch {
                                    conv.throwTypeError(isolate, "Failed to convert value to ConsoleValue");
                                    return;
                                };
                            }
                            args[i] = arg_slice;
                            js_arg_idx += @intCast(remaining_args);
                            continue;
                        }

                        // Handle slice of JSValue (used for variadic any[] parameters like console.log)
                        if (ParamType == []const runtime.JSValue) {
                            // Convert remaining JS arguments to JSValues
                            const remaining = argc - js_arg_idx;
                            const remaining_args: usize = if (remaining > 0) @intCast(remaining) else 0;
                            const arg_slice = allocator.alloc(runtime.JSValue, remaining_args) catch {
                                conv.throwTypeError(isolate, "Failed to allocate JSValue arguments");
                                return;
                            };
                            for (0..remaining_args) |j| {
                                const v8_value = info.get(@intCast(js_arg_idx + @as(c_int, @intCast(j))));
                                // Convert V8 value to runtime.JSValue using proper conversion
                                arg_slice[j] = conv.fromV8Value(runtime.JSValue, allocator, isolate, context, v8_value) catch {
                                    conv.throwTypeError(isolate, "Failed to convert value to JSValue");
                                    return;
                                };
                            }
                            args[i] = arg_slice;
                            js_arg_idx += @intCast(remaining_args);
                            continue;
                        }

                        // Handle slice of anyopaque (used for variadic ...any parameters)
                        if (ParamType == []const *const anyopaque) {
                            // Collect remaining JS arguments into a slice
                            const remaining = argc - js_arg_idx;
                            const remaining_args: usize = if (remaining > 0) @intCast(remaining) else 0;
                            const arg_slice = allocator.alloc(*const anyopaque, remaining_args) catch {
                                conv.throwTypeError(isolate, "Failed to allocate variadic arguments");
                                return;
                            };
                            for (0..remaining_args) |j| {
                                const v8_value = info.get(@intCast(js_arg_idx + @as(c_int, @intCast(j))));
                                arg_slice[j] = @ptrCast(v8_value);
                            }
                            args[i] = arg_slice;
                            js_arg_idx += @intCast(remaining_args);
                            continue;
                        }

                        // Handle anyopaque type (used for single any parameter)
                        if (ParamType == anyopaque or ParamType == *anyopaque or ParamType == *const anyopaque) {
                            // For anyopaque, just pass a pointer to the V8 value
                            const v8_value = info.get(js_arg_idx);
                            args[i] = @ptrCast(v8_value);
                            js_arg_idx += 1;
                            continue;
                        }

                        // Regular typed argument - extract and convert
                        const v8_value = info.get(js_arg_idx);
                        args[i] = conv.fromV8Value(
                            ParamType,
                            allocator,
                            isolate,
                            context,
                            v8_value,
                        ) catch {
                            // Type conversion failed
                            conv.throwTypeError(isolate, "Type error in argument");
                            return;
                        };
                        js_arg_idx += 1;
                    }

                    // Call the namespace function with extracted arguments
                    const result = @call(.auto, namespace_fn, args);

                    // Handle return value
                    if (return_type == void) {
                        conv.setReturnUndefined(info);
                    } else {
                        conv.setReturnValue(return_type, info, result) catch {
                            conv.throwError(isolate, "Failed to convert return value");
                        };
                    }
                }
            };

            return Wrapper.callback;
        }
    };
}

// ============================================================================
// Argument Extraction Helpers (Comptime)
// ============================================================================

/// Extract a single argument from V8 callback info
///
/// This function uses compile-time type information to extract and convert
/// arguments from V8 to Zig types.
fn extractArgument(
    comptime T: type,
    info: *const v8.FunctionCallbackInfo,
    index: c_int,
    allocator: std.mem.Allocator,
) conv.ConversionError!T {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate);
    const v8_value = info.get(index);

    return conv.fromV8Value(T, allocator, isolate, context, v8_value);
}

/// Check if argument matches expected type
fn validateArgumentType(
    comptime T: type,
    info: *const v8.FunctionCallbackInfo,
    index: c_int,
) bool {
    if (index >= info.length()) {
        return false;
    }

    const v8_value = info.get(index);

    return switch (T) {
        runtime.Boolean => v8.v8_Value_IsBoolean(v8_value),
        runtime.Long, runtime.UnsignedLong, runtime.LongLong, runtime.Double, runtime.Float => v8.v8_Value_IsNumber(v8_value),
        runtime.DOMString => v8.v8_Value_IsString(v8_value),
        runtime.Object => v8.v8_Value_IsObject(v8_value),
        runtime.Any => true, // Any accepts all types
        else => false,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "V8Namespace compiles" {
    const testing = std.testing;
    testing.refAllDecls(@This());
}

test "V8Namespace extracts methods from namespace struct" {
    // Create a mock namespace for testing
    const MockNamespace = struct {
        pub fn call_foo(ctx: runtime.Context) void {
            _ = ctx;
        }

        pub fn call_bar(ctx: runtime.Context, x: runtime.Long) void {
            _ = ctx;
            _ = x;
        }

        // Non-call method should be ignored
        pub fn helper() void {}
    };

    const Binding = V8Namespace(MockNamespace);

    // Verify methods were extracted correctly
    const testing = std.testing;
    try testing.expectEqual(@as(usize, 2), Binding.all_methods.len);
    try testing.expectEqualStrings("foo", Binding.all_methods[0].name);
    try testing.expectEqualStrings("bar", Binding.all_methods[1].name);
}
