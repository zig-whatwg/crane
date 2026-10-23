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

/// Generated namespaces obey both [Exposed] and [SecureContext]. A small
/// hand-written binding test with no metadata keeps its existing behavior.
pub fn namespaceIsExposed(comptime Namespace: type, context: *v8.Context) bool {
    if (@hasDecl(Namespace, "Meta") and @hasDecl(Namespace.Meta, "extended_attributes")) {
        if (!interface.interfaceIsExposedInScope(Namespace, interface.realmExposureScope(context))) return false;
        inline for (Namespace.Meta.extended_attributes) |attr| {
            if (comptime std.mem.eql(u8, attr.name, "SecureContext")) {
                if (!interface.realmIsSecureContext(context)) return false;
            }
        }
    }
    return true;
}

/// The realm a namespace operation that takes one (`runtime.Context`) is
/// handed: the CURRENT realm - V8 enters the operation's creation context
/// while the callback runs (current_realm.zig) - as WebIDL runs a namespace
/// operation in it, and the Console Standard keeps each console namespace
/// object's count map, timer table and group stack per realm.
///
/// It was one runtime context for the process, made by the first call and
/// kept to the end (`global_context`): every realm of every agent shared one
/// console state, mutated from every agent's thread unlocked - the mutex
/// covered only the context's creation (instances B2,
/// tests/v8/namespace_current_realm_test.zig).
///
/// A context no realm was made for (a binding test's bare context) gets a
/// runtime context for the call alone (`CallRealm`).
const context_manager = @import("context_manager.zig");
const isolate_allocator = @import("isolate_allocator.zig");

/// The runtime context a namespace call runs with: the realm's, or one made
/// for a context no realm was made for - over the isolate's allocator (the C
/// allocator for an isolate without one) - and ended with the call.
const CallRealm = struct {
    realm: ?runtime.Context = null,
    scoped: ?runtime.ContextData = null,

    /// What the operation's allocations come from.
    fn allocatorOf(isolate: *v8.Isolate, context: *v8.Context) std.mem.Allocator {
        if (context_manager.get(context)) |realm| return realm.getAllocator();
        return isolate_allocator.getIsolateAllocator(isolate) orelse std.heap.c_allocator;
    }

    /// The realm of `context`, made for the call if it has none.
    fn of(self: *CallRealm, isolate: *v8.Isolate, context: *v8.Context) !runtime.Context {
        if (self.realm) |realm| return realm;
        if (context_manager.get(context)) |realm| {
            self.realm = realm;
            return realm;
        }
        self.scoped = try runtime.ContextData.init(allocatorOf(isolate, context), .{ .engine_ctx = @ptrCast(context) });
        self.realm = &self.scoped.?;
        return self.realm.?;
    }

    fn end(self: *CallRealm) void {
        if (self.scoped) |*scoped| scoped.deinit();
    }
};

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
    // The undefined `conv.toV8Value` makes for a void payload (an
    // `anyerror!void` that succeeded) is made for the call. Kept, every
    // `console.groupEnd()` left one.
    if (T == void) return true;
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
/// One regular attribute of a namespace: its JavaScript name and the
/// generated getter (`get_<name>`).
const AttributeInfo = struct {
    name: []const u8,
    zig_name: []const u8,
};

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

    // The regular attributes the namespace's impl implements (WebIDL 3.13.1:
    // each is an accessor property of the namespace object, its getter
    // running the attribute's getter steps). Codegen lists every attribute
    // in `Meta.attributes` with whether the impl declares its getter; one
    // that is not implemented gets no property, as before attributes were
    // bound.
    const attributes = comptime blk: {
        var list: []const AttributeInfo = &.{};
        if (@hasDecl(Namespace, "Meta") and @hasDecl(Namespace.Meta, "attributes")) {
            for (Namespace.Meta.attributes) |entry| {
                if (!entry[2]) continue;
                list = list ++ [_]AttributeInfo{.{ .name = entry[0], .zig_name = entry[1] }};
            }
        }
        break :blk list;
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
            inline for (attributes) |attribute| {
                ext_refs.registerCallbackRuntime(generateGetter(attribute));
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
            if (!namespaceIsExposed(Namespace, context)) return;
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
            const object = v8.v8_Object_New(isolate) orelse return null;

            // Register all methods at compile time
            inline for (all_methods) |method| {
                if (comptime !@hasDecl(Namespace, "Meta") or !@hasDecl(Namespace.Meta, "exposed_members")) {
                    registerMethod(isolate, object, method);
                } else if (interface.memberIsExposed(Namespace, method.name, false, interface.realmExposureScope(context))) {
                    registerMethod(isolate, object, method);
                }
            }
            // WebIDL 3.13.1: each regular attribute an accessor property -
            // [[Enumerable]] and [[Configurable]] true, a getter and no
            // setter (a namespace attribute is readonly).
            inline for (attributes) |attribute| {
                install_attribute: {
                    if (comptime @hasDecl(Namespace.Meta, "exposed_members")) {
                        if (!interface.memberIsExposed(Namespace, attribute.name, false, interface.realmExposureScope(context))) break :install_attribute;
                    }
                    if (v8.v8_String_NewFromUtf8(isolate, attribute.name.ptr, @intCast(attribute.name.len))) |name_str| {
                        defer v8.v8_String_Dispose(name_str);
                        _ = v8.v8_Object_SetAccessorProperty(object, context, name_str, comptime generateGetter(attribute), null);
                    }
                }
            }

            return object;
        }

        /// The getter of a namespace attribute: its getter steps, run with the
        /// current realm - the namespace object's, which V8 enters for its
        /// functions (current_realm.zig) - and the value converted as an
        /// operation's result is.
        fn generateGetter(comptime attribute: AttributeInfo) v8.FunctionCallback {
            const getter_fn = @field(Namespace, attribute.zig_name);
            const return_type = @typeInfo(@typeInfo(@TypeOf(getter_fn)).@"fn".return_type.?).error_union.payload;

            const Wrapper = struct {
                fn callback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
                    const isolate = info.getIsolate();
                    // OWNED, released on the way out: a Global<Context> keeps
                    // its realm alive.
                    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
                        conv.throwTypeError(isolate, "Failed to get current context");
                        return;
                    };
                    defer v8.v8_Context_Dispose(context);
                    var call_realm: CallRealm = .{};
                    defer call_realm.end();
                    const realm = call_realm.of(isolate, context) catch {
                        conv.throwTypeError(isolate, "Failed to create runtime context");
                        return;
                    };
                    const result = getter_fn(realm) catch |err| {
                        conv.throwWebIDLErrorFromContext(isolate, context, @errorName(err));
                        return;
                    };
                    defer freeStringResult(return_type, realm.getAllocator(), result);
                    const v8_value = conv.toV8Value(return_type, isolate, context, result) catch {
                        conv.throwError(isolate, "Failed to convert return value");
                        return;
                    };
                    info.setReturnValue(v8_value);
                    // As an operation's result: a platform object's wrapper is
                    // the wrapper cache's; what was made for the call goes.
                    if (resultIsOwned(return_type, result)) v8.v8_Global_Dispose(v8_value);
                }
            };
            return Wrapper.callback;
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
                    // process. Released on the way out.
                    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
                        conv.throwTypeError(isolate, "Failed to get current context");
                        return;
                    };
                    defer v8.v8_Context_Dispose(context);
                    // The realm the operation runs in, if it takes one; ended
                    // after everything below that may use it.
                    var call_realm: CallRealm = .{};
                    defer call_realm.end();

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

                    // The arguments convert into an arena, released when the
                    // call returns - borrowed for the call, as an interface
                    // operation's are - whatever their size: a 4 KB stack
                    // buffer made any longer string argument a TypeError
                    // ("Type error in argument"). Over the C allocator: the
                    // arena never outlives the call, and the realm's (the
                    // runner's DebugAllocator) made every console.log or
                    // CSS.escape half again as slow in gc_bench.
                    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
                    defer arena.deinit();
                    const allocator = arena.allocator();

                    // The context the impl receives; a string it returns was
                    // allocated with that context's allocator.
                    var impl_context: ?runtime.Context = null;

                    // Track JS argument index separately from param index
                    var js_arg_idx: c_int = 0;

                    // Every `info.get(i)` is an owned Global, and the
                    // arguments are the call's, BORROWED by the impl as an
                    // interface operation's are (AGENTS.md "The engine
                    // boundary", rule 3): what a conversion copied out was
                    // released as it converted (`convertArgReleasing`), and
                    // the rest - an `any`'s `.handle` - goes once the call
                    // returns (`releaseArguments`). Kept, each argument was a
                    // Global for the agent's life: `CSS.escape("a")` left 32
                    // bytes of global handles per call (lane callleak).
                    // `converted` counts the parameters whose value is set.
                    var converted: usize = 0;
                    defer releaseArguments(&args, converted, allocator);

                    // Extract each argument based on its type
                    inline for (fn_type_info.params, 0..) |param, i| {
                        const ParamType = param.type.?;

                        // Handle special case: runtime.Context - the
                        // current realm.
                        if (ParamType == runtime.Context) {
                            const realm = call_realm.of(isolate, context) catch {
                                conv.throwTypeError(isolate, "Failed to create runtime context");
                                return;
                            };
                            args[i] = realm;
                            impl_context = realm;
                            converted = i + 1;
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
                                // Convert V8 value to runtime.JSValue using proper conversion.
                                // A primitive's handle goes here; an object's `.handle`
                                // is the element's until the call is over.
                                arg_slice[j] = interface.convertArgReleasing(runtime.JSValue, allocator, isolate, context, v8_value) catch {
                                    for (arg_slice[0..j]) |done| interface.releaseAnyArgument(runtime.JSValue, done);
                                    conv.throwTypeError(isolate, "Failed to convert value to JSValue");
                                    return;
                                };
                            }
                            args[i] = arg_slice;
                            converted = i + 1;
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

                        // Regular typed argument - extract and convert. Its
                        // handle goes as the operation path's does: at once
                        // for a conversion that copies (and on a failed one),
                        // after the call for one whose value refers to it.
                        const v8_value = info.get(js_arg_idx);
                        args[i] = interface.convertArgReleasing(
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
                        converted = i + 1;
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

        /// Release what the first `converted` arguments of a call still hold
        /// once it has returned: what `interface.freeArgument` releases for
        /// an operation's argument (an `any`'s `.handle`, a buffer source's
        /// reference, a callback's wrapper), and each element of a variadic
        /// `any`. The impls are BORROWERS: every namespace operation taking
        /// an `any` was read for a keeper (2026-10-11) - console's print the
        /// value and drop it (an object as "[object]"; table, dir and dirxml
        /// ignore theirs), CSS's are NotImplemented stubs, TestUtils.gc takes
        /// none, and WebAssembly is the engine's own (never bound here).
        ///
        /// A parameter handed the raw handle (`anyopaque`, a ConsoleValue
        /// slice) is not released: no namespace takes one today, and such an
        /// impl's use of the handle cannot be read off its value.
        fn releaseArguments(args: anytype, converted: usize, allocator: std.mem.Allocator) void {
            const params = @typeInfo(@typeInfo(@TypeOf(args)).pointer.child).@"struct".fields;
            inline for (params, 0..) |field, i| {
                const P = field.type;
                if (i < converted) {
                    if (comptime P == runtime.Context or P == []const runtime.ConsoleValue or
                        P == []const *const anyopaque or P == *anyopaque or P == *const anyopaque)
                    {
                        // Not a converted argument, or one whose handle is the impl's to read.
                    } else if (comptime P == []const runtime.JSValue) {
                        for (args.*[i]) |value| interface.releaseAnyArgument(runtime.JSValue, value);
                    } else {
                        // `allocator` is the call's arena, which the
                        // conversions allocated from: freeing into it is
                        // harmless, and the arena goes after this.
                        interface.freeArgument(P, allocator, args.*[i]);
                    }
                }
            }
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
