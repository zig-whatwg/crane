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
const webidl = @import("webidl");
const interface = @import("interface.zig");

/// The generated namespaces (for tests/v8, which reaches the namespace a
/// binding is made from through this module).
pub const generated_namespaces = @import("namespaces");

/// The allocator of the runtime context namespace operations receive - what
/// an impl allocates a result with, and what the binding frees it with.
/// Tests set it to std.testing.allocator (then clearGlobalContext() at the
/// end of the test) to see a leak.
pub var context_allocator: std.mem.Allocator = std.heap.page_allocator;

/// Global runtime context for V8 namespace operations
/// TODO: This should be stored per-isolate, not globally
var global_context: ?*runtime.ContextData = null;
var global_context_mutex: std.Io.Mutex = .init;

/// Get the global runtime context (may return null if not yet initialized)
pub fn getGlobalContext() ?runtime.Context {
    std.Io.Threaded.mutexLock(&global_context_mutex);
    defer std.Io.Threaded.mutexUnlock(&global_context_mutex);
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
    std.Io.Threaded.mutexLock(&global_context_mutex);
    defer std.Io.Threaded.mutexUnlock(&global_context_mutex);
    if (global_context) |ctx| {
        // Deinit the context data to free resources
        ctx.deinit();
        // Free the ContextData struct itself
        context_allocator.destroy(ctx);
    }
    global_context = null;
}

/// Whether the Global `conv.toV8Value(T, ...)` made of `result` is the
/// binding's to release once it is the call's return value: an error the
/// conversion turned into an object, a value the interface binding's
/// `getterValueIsOwned` says is made fresh, and a JSValue that is not a
/// platform object (a handle the impl handed over, or a primitive made here).
/// Anything else - a platform object, a type not named - is kept: releasing a
/// handle the binding does not own is a use-after-free, keeping one a leak.
fn resultIsOwned(comptime T: type, result: T) bool {
    switch (@typeInfo(T)) {
        .error_union => |eu| {
            const payload = result catch return true;
            return resultIsOwned(eu.payload, payload);
        },
        else => {},
    }
    if (T == runtime.JSValue) return result != .instance;
    return @import("interface.zig").getterValueIsOwned(T);
}

/// Free a string result an impl returned - a DOMString (owned), or a
/// USVString or ByteString slice - plain or optional, once the binding has
/// converted it. Anything else is not the binding's to free here (a JSValue
/// is released by `resultIsOwned`'s rule).
fn freeStringResult(comptime T: type, allocator: std.mem.Allocator, result: T) void {
    switch (@typeInfo(T)) {
        .error_union => |eu| {
            const payload = result catch return;
            return freeStringResult(eu.payload, allocator, payload);
        },
        .optional => |opt| {
            const payload = result orelse return;
            return freeStringResult(opt.child, allocator, payload);
        },
        else => {},
    }
    if (T == runtime.DOMString) {
        var owned = result;
        owned.deinit(allocator);
    } else if (T == []const u8 or T == []u8) {
        if (result.len > 0) allocator.free(result);
    }
}

/// `call_<name>__<k>`: overload k of an overloaded operation (AGENTS.md,
/// "Names are the binding map").
fn isFurtherOverload(comptime decl_name: []const u8) bool {
    const at = std.mem.lastIndexOf(u8, decl_name, "__") orelse return false;
    const suffix = decl_name[at + 2 ..];
    if (suffix.len == 0) return false;
    for (suffix) |c| if (!std.ascii.isDigit(c)) return false;
    return true;
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

    // Extract all call_* methods at compile time. A further overload
    // (`call_<name>__<k>`) is not a method of its own: the first overload's
    // binding reaches it through overload resolution (see forwardToOverload).
    const methods = comptime blk: {
        // CSS alone has ~75 operations, each name scanned for an overload suffix.
        @setEvalBranchQuota(100_000);
        var method_list: []const MethodInfo = &.{};
        for (ns_info.@"struct".decls) |decl| {
            if (std.mem.startsWith(u8, decl.name, "call_") and !isFurtherOverload(decl.name)) {
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

        /// The namespace's name, for error messages.
        const namespace_name: []const u8 = if (@hasDecl(Namespace, "Meta") and @hasDecl(Namespace.Meta, "name")) Namespace.Meta.name else @typeName(Namespace);

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
            // Owned handles, released once the property is defined: the
            // namespace object and the global live in `context`, so a leaked
            // handle to either kept the whole context alive.
            const ns_object = createObject(isolate, context);
            defer if (ns_object) |o| v8.v8_Object_Dispose(o);
            const global = v8.v8_Context_Global(context) orelse return;
            defer v8.v8_Object_Dispose(global);

            const key_str = v8.v8_String_NewFromUtf8(
                isolate,
                name.ptr,
                @intCast(name.len),
            ) orelse return;
            defer v8.v8_String_Dispose(key_str);

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
            defer v8.v8_FunctionTemplate_Dispose(fn_template);
            const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
            defer v8.v8_Context_Dispose(context);
            // Released once set: the function lives in the context, and one
            // leaked per method kept every context alive.
            const fn_obj = v8.v8_FunctionTemplate_GetFunction(
                fn_template,
                context,
            ) orelse return;
            defer v8.v8_Function_Dispose(fn_obj);

            // Add function to object
            const name_str = v8.v8_String_NewFromUtf8(
                isolate,
                method.name.ptr,
                @intCast(method.name.len),
            ) orelse return;
            defer v8.v8_String_Dispose(name_str);

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
        /// The overload set whose FIRST overload is `zig_name`, if any - see
        /// `overloads` in a generated namespace (codegen writes the table an
        /// interface carries).
        fn overloadSetFor(comptime zig_name: []const u8) ?[]const webidl.overload_resolution.Overload {
            if (!@hasDecl(Namespace, "overloads")) return null;
            inline for (Namespace.overloads) |entry| {
                const set: []const webidl.overload_resolution.Overload = entry[1];
                if (comptime std.mem.eql(u8, set[0].function, zig_name)) return set;
            }
            return null;
        }

        /// WebIDL "create an operation function" step 3, as the interface
        /// binding runs it (interface.zig forwardToOverload): the overload
        /// resolution algorithm over `set` with the call's arguments, through
        /// the same resolver (webidl.overload_resolution.select) and the same
        /// view of the arguments (interface.OverloadArgs). Returns true when
        /// the call was handled here - forwarded to a further overload, or a
        /// TypeError thrown - and false when the first overload is the one to
        /// run. A further overload runs its own delegate even before the impl
        /// declares it (the delegate answers NotImplemented): a namespace had
        /// no binding for any overload before, so there is nothing to keep.
        fn forwardToOverload(
            comptime set: []const webidl.overload_resolution.Overload,
            info: *const v8.FunctionCallbackInfo,
        ) bool {
            const isolate = info.getIsolate();
            var args = interface.OverloadArgs{ .info = info, .isolate = isolate };
            defer args.release();

            const chosen = webidl.overload_resolution.select(set, @intCast(info.length()), &args) catch |err| {
                switch (err) {
                    error.TypeError => conv.throwTypeError(isolate, "Failed to execute '" ++ comptime set[0].function["call_".len..] ++ "' on '" ++ namespace_name ++ "': no overload matches these arguments"),
                    // GetMethod threw; the exception is already pending.
                    error.JavaScriptException => {},
                }
                return true;
            };
            if (chosen == 0) return false;
            inline for (set, 0..) |overload, k| {
                if (k != 0 and k == chosen) {
                    const callback = comptime generateCallback(.{
                        .name = set[0].function["call_".len..],
                        .zig_name = overload.function,
                        .param_count = @typeInfo(@TypeOf(@field(Namespace, overload.function))).@"fn".params.len,
                    });
                    callback(info);
                    return true;
                }
            }
            return false;
        }

        fn generateCallback(comptime method: MethodInfo) v8.FunctionCallback {
            const namespace_fn = @field(Namespace, method.zig_name);
            const fn_type_info = @typeInfo(@TypeOf(namespace_fn)).@"fn";
            const return_type = fn_type_info.return_type orelse void;

            const Wrapper = struct {
                fn callback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
                    if (comptime overloadSetFor(method.zig_name)) |set| {
                        if (forwardToOverload(set, info)) return;
                    }
                    const isolate = info.getIsolate();
                    // OWNED (every v8_* return is a Global the caller owns),
                    // and a Global<Context> keeps its realm - the whole page -
                    // alive: one left per call kept every page that called
                    // TestUtils.gc() or console.log() to the end of the
                    // process. Released on the way out, unless it became the
                    // process-wide context below, which keeps it.
                    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
                        conv.throwTypeError(isolate, "Failed to get current context");
                        return;
                    };
                    var context_kept = false;
                    defer if (!context_kept) v8.v8_Context_Dispose(context);

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

                    // The arguments convert into an arena over the context's
                    // allocator, released when the call returns - borrowed for
                    // the call, as an interface operation's are - whatever
                    // their size: a 4 KB stack buffer made any longer string
                    // argument a TypeError ("Type error in argument").
                    var arena = std.heap.ArenaAllocator.init(context_allocator);
                    defer arena.deinit();
                    const allocator = arena.allocator();

                    // The context the impl receives; a string it returns was
                    // allocated with that context's allocator.
                    var impl_context: ?runtime.Context = null;

                    // Track JS argument index separately from param index
                    var js_arg_idx: c_int = 0;

                    // Extract each argument based on its type
                    inline for (fn_type_info.params, 0..) |param, i| {
                        const ParamType = param.type.?;

                        // Handle special case: runtime.Context
                        if (ParamType == runtime.Context) {
                            // Get or create the global context
                            std.Io.Threaded.mutexLock(&global_context_mutex);
                            defer std.Io.Threaded.mutexUnlock(&global_context_mutex);

                            if (global_context == null) {
                                // Initialize global context with colored logger
                                // TODO: proper lifecycle (one per realm).
                                const gpa = context_allocator;
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
                                // TODO: the first calling realm's context is
                                // kept for the process (one page, not one per
                                // call); a per-realm context is the fix.
                                context_kept = true;
                            }

                            args[i] = global_context.?;
                            impl_context = global_context.?;
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
                    // A string the impl returns is the binding's once it is
                    // converted, as an interface operation's is (interface.zig,
                    // needs_string_cleanup): freed with the allocator the impl
                    // allocated it with, its context's.
                    defer if (impl_context) |ctx| freeStringResult(return_type, ctx.getAllocator(), result);

                    // Handle return value
                    if (return_type == void) {
                        conv.setReturnUndefined(info);
                    } else {
                        const v8_value = conv.toV8Value(return_type, isolate, context, result) catch {
                            conv.throwError(isolate, "Failed to convert return value");
                            return;
                        };
                        info.setReturnValue(v8_value);
                        // setReturnValue reads the handle into a Local. What
                        // the conversion made, and what the impl returned as
                        // its own (engine.Owned.take: the binding releases
                        // every value an impl returns), is released here, as
                        // the interface binding does: TestUtils.gc()'s promise
                        // kept its page alive. A platform object's wrapper is
                        // the wrapper cache's, and kept.
                        if (resultIsOwned(return_type, result)) v8.v8_Global_Dispose(v8_value);
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
