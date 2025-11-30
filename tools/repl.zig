//! JavaScript REPL with V8 Engine and WebIDL Bindings
//!
//! Interactive Read-Eval-Print Loop with:
//! - V8 JavaScript execution
//! - Console API (console.log, etc.)
//! - Tab completion for JavaScript globals
//! - Multi-line input support
//! - History support

const std = @import("std");
const v8 = @import("v8");
const context_manager = @import("v8").context_manager;
const runtime = @import("runtime");

/// Helper to extract a string property from a V8 object
fn getStringProperty(isolate: *v8.ffi.Isolate, context: *v8.ffi.Context, obj: *v8.ffi.Object, prop_name: []const u8, buf: []u8) ?[]const u8 {
    const key = v8.ffi.v8_String_NewFromUtf8(isolate, prop_name.ptr, @intCast(prop_name.len)) orelse return null;
    const value = v8.ffi.v8_Object_Get(obj, context, @ptrCast(key)) orelse return null;
    if (v8.ffi.v8_Value_IsUndefined(value) or v8.ffi.v8_Value_IsNull(value)) return null;
    if (!v8.ffi.v8_Value_IsString(value)) return null;

    const str = v8.ffi.v8_Value_ToString(value, context) orelse return null;
    const len: usize = @intCast(v8.ffi.v8_String_Utf8Length(str));
    if (len > buf.len) return null;
    _ = v8.ffi.v8_String_WriteUtf8(str, buf.ptr, @intCast(buf.len));
    return buf[0..len];
}

/// Fetch callback that makes real HTTP requests using std.http.Client.
/// Returns a Promise that resolves to a Response object.
fn fetchCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;

    // Get allocator from runtime context
    const runtime_ctx = context_manager.getOrCreate(context, std.heap.page_allocator) catch {
        info.setReturnValue(@ptrCast(v8.ffi.v8_Undefined(isolate)));
        return;
    };
    const allocator = runtime_ctx.allocator;

    // Get the first argument (input: RequestInfo - URL string or Request object)
    const argc = info.v8_FunctionCallbackInfo_Length();
    if (argc < 1) {
        const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Failed to execute 'fetch': 1 argument required", 47) orelse return;
        const err = v8.ffi.v8_Exception_TypeError(@ptrCast(err_msg)) orelse return;
        v8.ffi.v8_Isolate_ThrowException(isolate, err);
        return;
    }

    const arg0 = info.v8_FunctionCallbackInfo_GetArgument(0);

    // Extract URL string from the argument
    var url_buf: [4096]u8 = undefined;
    var url_len: usize = 0;

    if (v8.ffi.v8_Value_IsString(arg0)) {
        const str = v8.ffi.v8_Value_ToString(arg0, context) orelse {
            const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Invalid URL", 11) orelse return;
            const err = v8.ffi.v8_Exception_TypeError(@ptrCast(err_msg)) orelse return;
            v8.ffi.v8_Isolate_ThrowException(isolate, err);
            return;
        };
        // Get the actual string length first (without null terminator)
        url_len = @intCast(v8.ffi.v8_String_Utf8Length(str));
        if (url_len > url_buf.len) url_len = url_buf.len;
        _ = v8.ffi.v8_String_WriteUtf8(str, &url_buf, @intCast(url_buf.len));
    } else {
        const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "fetch() requires a URL string", 29) orelse return;
        const err = v8.ffi.v8_Exception_TypeError(@ptrCast(err_msg)) orelse return;
        v8.ffi.v8_Isolate_ThrowException(isolate, err);
        return;
    }

    const url_str = url_buf[0..url_len];

    // Parse second argument (RequestInit) if present
    var method: std.http.Method = .GET;
    var request_body: ?[]const u8 = null;
    var request_body_owned: ?[]u8 = null;
    defer if (request_body_owned) |b| allocator.free(b);

    // Storage for extra headers from RequestInit
    var extra_headers_storage: [32]std.http.Header = undefined;
    var extra_headers_count: usize = 0;

    // Redirect behavior: "follow" (default), "manual", "error"
    var redirect_behavior: std.http.Client.Request.RedirectBehavior = @enumFromInt(3); // default: follow 3 times

    if (argc >= 2) {
        const arg1 = info.v8_FunctionCallbackInfo_GetArgument(1);
        if (v8.ffi.v8_Value_IsObject(arg1) and !v8.ffi.v8_Value_IsNull(arg1)) {
            const init_obj: *v8.ffi.Object = @ptrCast(arg1);

            // Extract redirect option
            var redirect_buf: [16]u8 = undefined;
            if (getStringProperty(isolate, context, init_obj, "redirect", &redirect_buf)) |redirect_str| {
                if (std.ascii.eqlIgnoreCase(redirect_str, "manual")) {
                    redirect_behavior = .unhandled; // Don't follow redirects
                } else if (std.ascii.eqlIgnoreCase(redirect_str, "error")) {
                    redirect_behavior = .not_allowed; // Error on redirect
                }
                // "follow" is default, no change needed
            }

            // Extract method
            var method_buf: [16]u8 = undefined;
            if (getStringProperty(isolate, context, init_obj, "method", &method_buf)) |method_str| {
                if (std.ascii.eqlIgnoreCase(method_str, "GET")) {
                    method = .GET;
                } else if (std.ascii.eqlIgnoreCase(method_str, "POST")) {
                    method = .POST;
                } else if (std.ascii.eqlIgnoreCase(method_str, "PUT")) {
                    method = .PUT;
                } else if (std.ascii.eqlIgnoreCase(method_str, "DELETE")) {
                    method = .DELETE;
                } else if (std.ascii.eqlIgnoreCase(method_str, "PATCH")) {
                    method = .PATCH;
                } else if (std.ascii.eqlIgnoreCase(method_str, "HEAD")) {
                    method = .HEAD;
                } else if (std.ascii.eqlIgnoreCase(method_str, "OPTIONS")) {
                    method = .OPTIONS;
                }
            }

            // Extract body - handle string, URLSearchParams, and other objects
            const body_key = v8.ffi.v8_String_NewFromUtf8(isolate, "body", 4) orelse null;
            if (body_key) |bk| {
                const body_value = v8.ffi.v8_Object_Get(init_obj, context, @ptrCast(bk));
                if (body_value) |bv| {
                    if (!v8.ffi.v8_Value_IsUndefined(bv) and !v8.ffi.v8_Value_IsNull(bv)) {
                        // For URLSearchParams and other objects, call toString()
                        // For strings, use directly
                        var body_str_to_use: ?*v8.ffi.String = null;

                        if (v8.ffi.v8_Value_IsString(bv)) {
                            body_str_to_use = v8.ffi.v8_Value_ToString(bv, context);
                        } else if (v8.ffi.v8_Value_IsObject(bv)) {
                            // Check if it's URLSearchParams by calling toString() method
                            const obj: *v8.ffi.Object = @ptrCast(bv);
                            const to_string_key = v8.ffi.v8_String_NewFromUtf8(isolate, "toString", 8);
                            if (to_string_key) |ts_key| {
                                const to_string_fn = v8.ffi.v8_Object_Get(obj, context, @ptrCast(ts_key));
                                if (to_string_fn) |ts_fn| {
                                    if (v8.ffi.v8_Value_IsFunction(ts_fn)) {
                                        // Call toString() on the body object
                                        const func: *v8.ffi.Function = @ptrCast(ts_fn);
                                        var empty_args: [0]*v8.ffi.Value = undefined;
                                        const result = v8.ffi.v8_Function_Call(func, context, bv, 0, &empty_args);
                                        if (result) |r| {
                                            if (v8.ffi.v8_Value_IsString(r)) {
                                                body_str_to_use = v8.ffi.v8_Value_ToString(r, context);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        if (body_str_to_use) |bs| {
                            const body_len: usize = @intCast(v8.ffi.v8_String_Utf8Length(bs));
                            const body_buf = allocator.alloc(u8, body_len) catch null;
                            if (body_buf) |bb| {
                                _ = v8.ffi.v8_String_WriteUtf8(bs, bb.ptr, @intCast(bb.len));
                                request_body = bb;
                                request_body_owned = bb;
                            }
                        }
                    }
                }
            }

            // Extract headers object
            const headers_key = v8.ffi.v8_String_NewFromUtf8(isolate, "headers", 7) orelse null;
            if (headers_key) |hk| {
                const headers_value = v8.ffi.v8_Object_Get(init_obj, context, @ptrCast(hk));
                if (headers_value) |hv| {
                    if (v8.ffi.v8_Value_IsObject(hv) and !v8.ffi.v8_Value_IsNull(hv)) {
                        const headers_obj: *v8.ffi.Object = @ptrCast(hv);
                        // Get property names
                        const prop_names = v8.ffi.v8_Object_GetPropertyNames(context, headers_obj);
                        if (prop_names) |names| {
                            const len = v8.ffi.v8_Array_Length(names);
                            var i: u32 = 0;
                            while (i < len and extra_headers_count < extra_headers_storage.len) : (i += 1) {
                                const name_val = v8.ffi.v8_Array_Get(context, names, i) orelse continue;
                                if (!v8.ffi.v8_Value_IsString(name_val)) continue;

                                const name_str = v8.ffi.v8_Value_ToString(name_val, context) orelse continue;
                                const name_len: usize = @intCast(v8.ffi.v8_String_Utf8Length(name_str));

                                const header_val = v8.ffi.v8_Object_Get(headers_obj, context, name_val) orelse continue;
                                if (!v8.ffi.v8_Value_IsString(header_val)) continue;

                                const value_str = v8.ffi.v8_Value_ToString(header_val, context) orelse continue;
                                const value_len: usize = @intCast(v8.ffi.v8_String_Utf8Length(value_str));

                                // Allocate and copy header name and value
                                const name_buf = allocator.alloc(u8, name_len) catch continue;
                                const value_buf = allocator.alloc(u8, value_len) catch {
                                    allocator.free(name_buf);
                                    continue;
                                };

                                _ = v8.ffi.v8_String_WriteUtf8(name_str, name_buf.ptr, @intCast(name_buf.len));
                                _ = v8.ffi.v8_String_WriteUtf8(value_str, value_buf.ptr, @intCast(value_buf.len));

                                extra_headers_storage[extra_headers_count] = .{
                                    .name = name_buf,
                                    .value = value_buf,
                                };
                                extra_headers_count += 1;
                            }
                        }
                    }
                }
            }
        }
    }

    // Cleanup extra headers on exit
    defer {
        for (extra_headers_storage[0..extra_headers_count]) |h| {
            allocator.free(@constCast(h.name));
            allocator.free(@constCast(h.value));
        }
    }

    // Parse URL
    const uri = std.Uri.parse(url_str) catch {
        const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Invalid URL", 11) orelse return;
        const err = v8.ffi.v8_Exception_TypeError(@ptrCast(err_msg)) orelse return;
        v8.ffi.v8_Isolate_ThrowException(isolate, err);
        return;
    };

    // Create HTTP client and make request
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    // Make the request using low-level API but with proper buffer management
    var req = client.request(method, uri, .{
        .extra_headers = extra_headers_storage[0..extra_headers_count],
        .redirect_behavior = redirect_behavior,
    }) catch {
        // Return rejected promise with network error
        const resolver = v8.ffi.v8_PromiseResolver_New(context) orelse return;
        const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Network error: connection failed", 33) orelse return;
        const err = v8.ffi.v8_Exception_TypeError(@ptrCast(err_msg)) orelse return;
        _ = v8.ffi.v8_PromiseResolver_Reject(resolver, context, err);
        const promise = v8.ffi.v8_PromiseResolver_GetPromise(resolver);
        info.setReturnValue(@ptrCast(promise));
        return;
    };
    defer req.deinit();

    // Send the request with or without body
    // Methods that can have bodies: POST, PUT, PATCH
    // Methods that cannot: GET, HEAD, DELETE, OPTIONS
    const method_has_body = method == .POST or method == .PUT or method == .PATCH;

    if (request_body) |rb| {
        // Send with body
        req.transfer_encoding = .{ .content_length = rb.len };
        var body_writer = req.sendBodyUnflushed(&.{}) catch {
            const resolver = v8.ffi.v8_PromiseResolver_New(context) orelse return;
            const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Network error: send failed", 26) orelse return;
            const err = v8.ffi.v8_Exception_TypeError(@ptrCast(err_msg)) orelse return;
            _ = v8.ffi.v8_PromiseResolver_Reject(resolver, context, err);
            const promise = v8.ffi.v8_PromiseResolver_GetPromise(resolver);
            info.setReturnValue(@ptrCast(promise));
            return;
        };
        body_writer.writer.writeAll(rb) catch {
            const resolver = v8.ffi.v8_PromiseResolver_New(context) orelse return;
            const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Network error: body write failed", 32) orelse return;
            const err = v8.ffi.v8_Exception_TypeError(@ptrCast(err_msg)) orelse return;
            _ = v8.ffi.v8_PromiseResolver_Reject(resolver, context, err);
            const promise = v8.ffi.v8_PromiseResolver_GetPromise(resolver);
            info.setReturnValue(@ptrCast(promise));
            return;
        };
        body_writer.end() catch {};
        if (req.connection) |conn| conn.flush() catch {};
    } else if (method_has_body) {
        // Method can have body but none provided - send empty body
        req.transfer_encoding = .{ .content_length = 0 };
        var body_writer = req.sendBodyUnflushed(&.{}) catch {
            const resolver = v8.ffi.v8_PromiseResolver_New(context) orelse return;
            const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Network error: send failed", 26) orelse return;
            const err = v8.ffi.v8_Exception_TypeError(@ptrCast(err_msg)) orelse return;
            _ = v8.ffi.v8_PromiseResolver_Reject(resolver, context, err);
            const promise = v8.ffi.v8_PromiseResolver_GetPromise(resolver);
            info.setReturnValue(@ptrCast(promise));
            return;
        };
        body_writer.end() catch {};
        if (req.connection) |conn| conn.flush() catch {};
    } else {
        // Send without body (GET, HEAD, DELETE, OPTIONS)
        req.sendBodiless() catch {
            const resolver = v8.ffi.v8_PromiseResolver_New(context) orelse return;
            const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Network error: send failed", 26) orelse return;
            const err = v8.ffi.v8_Exception_TypeError(@ptrCast(err_msg)) orelse return;
            _ = v8.ffi.v8_PromiseResolver_Reject(resolver, context, err);
            const promise = v8.ffi.v8_PromiseResolver_GetPromise(resolver);
            info.setReturnValue(@ptrCast(promise));
            return;
        };
    }

    // Receive response headers
    var redirect_buffer: [4096]u8 = undefined;
    var http_response = req.receiveHead(&redirect_buffer) catch {
        const resolver = v8.ffi.v8_PromiseResolver_New(context) orelse return;
        const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Network error: receive failed", 30) orelse return;
        const err = v8.ffi.v8_Exception_TypeError(@ptrCast(err_msg)) orelse return;
        _ = v8.ffi.v8_PromiseResolver_Reject(resolver, context, err);
        const promise = v8.ffi.v8_PromiseResolver_GetPromise(resolver);
        info.setReturnValue(@ptrCast(promise));
        return;
    };

    // Extract status and headers BEFORE reading body (body read invalidates head.bytes)
    const status = @intFromEnum(http_response.head.status);

    // Copy all headers from the response (must be done before reading body)
    // because iterateHeaders returns slices into redirect_buffer which gets reused
    const HeaderCopy = struct { name: []u8, value: []u8 };
    var headers_list: std.ArrayListUnmanaged(HeaderCopy) = .empty;
    defer {
        for (headers_list.items) |h| {
            allocator.free(h.name);
            allocator.free(h.value);
        }
        headers_list.deinit(allocator);
    }

    var header_iter = http_response.head.iterateHeaders();
    while (header_iter.next()) |header| {
        const name_copy = allocator.dupe(u8, header.name) catch continue;
        const value_copy = allocator.dupe(u8, header.value) catch {
            allocator.free(name_copy);
            continue;
        };
        headers_list.append(allocator, .{ .name = name_copy, .value = value_copy }) catch {
            allocator.free(name_copy);
            allocator.free(value_copy);
            continue;
        };
    }

    // Read response body (skip for HEAD requests)
    var transfer_buffer: [4096]u8 = undefined;
    var body: []const u8 = "";
    var body_owned: ?[]u8 = null;
    defer if (body_owned) |b| allocator.free(b);

    if (method != .HEAD) {
        const reader = http_response.reader(&transfer_buffer);
        body_owned = reader.allocRemaining(allocator, std.Io.Limit.unlimited) catch null;
        if (body_owned) |b| {
            body = b;
        }
    }

    // Create Response object
    const Response = @import("interfaces").Response;
    const response_instance = Response.init(allocator, runtime_ctx) catch {
        const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Failed to create Response", 25) orelse return;
        const err = v8.ffi.v8_Exception_Error(@ptrCast(err_msg)) orelse return;
        v8.ffi.v8_Isolate_ThrowException(isolate, err);
        return;
    };

    // Set response properties via the internal state
    // The Response interface stores internal state in state.own._internal
    const state = response_instance.getState(Response.State);
    if (state.own._internal) |internal| {
        // Set status from HTTP response
        internal.response.status = status;

        // Set URL in URL list
        const url_copy = allocator.dupe(u8, url_str) catch null;
        if (url_copy) |u| {
            internal.response.url_list.append(allocator, u) catch {};
        }

        // Set body from response data
        if (body.len > 0) {
            const fetch = @import("fetch");
            const body_obj = fetch.internal.Body.fromBytes(allocator, body) catch null;
            if (body_obj) |b| {
                internal.response.body = b;
            }
        }

        // Add all response headers
        for (headers_list.items) |h| {
            internal.response.header_list.append(h.name, h.value) catch {};
        }
    }

    // Wrap the Response as a V8 object
    const v8_response = v8.template_registry.wrapInstanceAsV8Object(
        response_instance,
        "Response",
        isolate,
        context,
    ) catch {
        Response.deinit(response_instance);
        const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Failed to wrap Response", 23) orelse return;
        const err = v8.ffi.v8_Exception_Error(@ptrCast(err_msg)) orelse return;
        v8.ffi.v8_Isolate_ThrowException(isolate, err);
        return;
    };

    // Create a resolved Promise with the Response
    const resolver = v8.ffi.v8_PromiseResolver_New(context) orelse {
        const err_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Failed to create Promise", 24) orelse return;
        const err = v8.ffi.v8_Exception_Error(@ptrCast(err_msg)) orelse return;
        v8.ffi.v8_Isolate_ThrowException(isolate, err);
        return;
    };

    _ = v8.ffi.v8_PromiseResolver_Resolve(resolver, context, @ptrCast(v8_response));

    const promise = v8.ffi.v8_PromiseResolver_GetPromise(resolver);
    info.setReturnValue(@ptrCast(promise));
}

/// REPL state
const Repl = struct {
    allocator: std.mem.Allocator,
    isolate: *v8.ffi.Isolate,
    context: *v8.ffi.Context,
    input_buffer: std.ArrayListUnmanaged(u8),
    history: std.ArrayListUnmanaged([]const u8),
    /// Singleton instances that need to be cleaned up on exit
    indexeddb_instance: ?*runtime.Instance = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        // Initialize WebIDL runtime (SlabAllocator, ArenaAllocator)
        runtime.initializeRuntime(allocator);

        // Initialize V8 platform
        v8.ffi.v8_Platform_Initialize();

        // Initialize V8 isolate
        const isolate = v8.ffi.v8_Isolate_New() orelse return error.V8InitFailed;
        errdefer v8.ffi.v8_Isolate_Dispose(isolate);

        v8.ffi.v8_Isolate_Enter(isolate);
        errdefer v8.ffi.v8_Isolate_Exit(isolate);

        const context = v8.ffi.v8_Context_New(isolate) orelse return error.ContextCreateFailed;
        errdefer v8.ffi.v8_Context_Dispose(context);

        v8.ffi.v8_Context_Enter(context);

        // Initialize context manager for V8 callbacks
        context_manager.init(allocator) catch |err| {
            std.debug.print("Warning: Context manager init failed: {}\n", .{err});
            // Continue anyway - some interfaces may not work properly
        };

        // Register the V8 context with context manager to enable wrapper caching
        // This creates a runtime context with wrapper cache for object identity
        // Use getOrCreateWithIsolate to enable timer support (for AbortSignal.timeout, etc.)
        _ = context_manager.getOrCreateWithIsolate(context, isolate, allocator) catch |err| {
            std.debug.print("Warning: Context registration failed: {}\n", .{err});
            // Continue anyway - wrapper caching won't work but basic functionality will
        };

        // Register all interface bindings using comptime reflection
        // The @setEvalBranchQuota is needed because we iterate over 1231 declarations
        @setEvalBranchQuota(200_000);
        const interfaces = @import("interfaces");
        const iface_decls = @typeInfo(interfaces).@"struct".decls;

        // Interfaces to skip due to codegen issues (missing types, etc.)
        const skip_list = .{
            "CSSMarginRule", // References undefined CSSMarginDescriptors
            "ViewCSS", // References undefined AbstractView
            "AuthenticatorAssertionResponse", // ArrayBuffer type issues
            "AuthenticatorAttestationResponse", // ArrayBuffer type issues
            "AuthenticatorResponse", // ArrayBuffer type issues
            "CSSMediaRule", // Missing cached field
            "CSSViewTransitionRule", // DOMString array issues
            "ChapterInformation", // MediaImage array issues
            "CookieChangeEvent", // CookieListItem array issues
            "DeviceChangeEvent", // MediaDeviceInfo array issues
            "ExtendableCookieChangeEvent", // CookieListItem array issues
            "ExtendableMessageEvent", // Union type issues
            "FontFaceSetLoadEvent", // FontFace array issues
            "GamepadHapticActuator", // GamepadHapticEffectType array issues
            "MediaMetadata", // ChapterInformation array issues
            "Notification", // Missing unsignedlong type
            "PerformanceLongAnimationFrameTiming", // PerformanceScriptTiming array issues
            "PerformanceObserver", // Missing cached field
            "PressureObserver", // Missing cached field
            "PublicKeyCredential", // ArrayBuffer type issues
            "PushManager", // Missing cached field
            "PushSubscriptionOptions", // ArrayBuffer type issues
            "RTCTrackEvent", // MediaStream array issues
            "SVGPathElement", // Missing cached field
            "WindowClient", // Missing VisibilityState type
            "XRCPUDepthInformation", // ArrayBuffer type issues
            "XRInputSource", // DOMString array issues
            "XRInputSourcesChangeEvent", // XRInputSource array issues
            "XRRay", // TypedArray issues
            "XRViewerPose", // XRView array issues
            "XRVisibilityMaskChangeEvent", // TypedArray issues
        };

        inline for (iface_decls) |decl| {
            // Skip problematic interfaces
            const should_skip = comptime blk: {
                for (skip_list) |skip| {
                    if (std.mem.eql(u8, decl.name, skip)) break :blk true;
                }
                break :blk false;
            };
            if (should_skip) continue;

            const InterfaceType = @field(interfaces, decl.name);
            // Only bind types that have Meta (actual interfaces)
            if (@typeInfo(InterfaceType) == .@"struct" and @hasDecl(InterfaceType, "Meta")) {
                // Skip mixin interfaces - they should not be exposed as globals
                const is_mixin = comptime blk: {
                    const Meta = InterfaceType.Meta;
                    if (@hasDecl(Meta, "is_mixin")) {
                        break :blk Meta.is_mixin;
                    }
                    break :blk false;
                };
                if (is_mixin) continue;

                // Check if this interface has LegacyNamespace - if so, skip global registration
                const has_legacy_namespace = comptime blk: {
                    const Meta = InterfaceType.Meta;
                    if (@hasDecl(Meta, "extended_attributes")) {
                        const ext_attrs = Meta.extended_attributes;
                        for (ext_attrs) |attr| {
                            if (std.mem.eql(u8, attr.name, "LegacyNamespace")) {
                                break :blk true;
                            }
                        }
                    }
                    break :blk false;
                };

                // Skip interfaces with LegacyNamespace - they get attached to namespaces below
                if (has_legacy_namespace) continue;

                const Binding = v8.V8Interface(InterfaceType);
                Binding.registerGlobal(isolate, context, decl.name);
            }
        }

        // Register all namespace bindings
        const namespaces = @import("namespaces");
        const ns_decls = @typeInfo(namespaces).@"struct".decls;

        inline for (ns_decls) |decl| {
            const NamespaceType = @field(namespaces, decl.name);
            // Only bind types that have Meta (actual namespaces)
            if (@typeInfo(NamespaceType) == .@"struct" and @hasDecl(NamespaceType, "Meta")) {
                // Use V8Namespace to create object with all methods bound
                const NamespaceBinding = v8.V8Namespace(NamespaceType);
                NamespaceBinding.registerGlobal(isolate, context, decl.name);

                // Get the namespace object we just created
                const global_obj = v8.ffi.v8_Context_Global(context);
                const ns_key_str = v8.ffi.v8_String_NewFromUtf8(isolate, decl.name.ptr, @intCast(decl.name.len));
                const ns_obj_value = v8.ffi.v8_Object_Get(global_obj.?, context, @ptrCast(ns_key_str));
                const ns_obj = @as(?*v8.ffi.Object, @ptrCast(ns_obj_value));

                // Now attach interfaces with [LegacyNamespace=<this namespace>] as properties
                const namespace_name = decl.name;
                inline for (iface_decls) |iface_decl| {
                    const InterfaceType = @field(interfaces, iface_decl.name);
                    if (@typeInfo(InterfaceType) == .@"struct" and @hasDecl(InterfaceType, "Meta")) {
                        // Check if this interface belongs to this namespace
                        const belongs_here = comptime blk: {
                            const Meta = InterfaceType.Meta;
                            if (@hasDecl(Meta, "extended_attributes")) {
                                const ext_attrs = Meta.extended_attributes;
                                for (ext_attrs) |attr| {
                                    if (std.mem.eql(u8, attr.name, "LegacyNamespace")) {
                                        const val = attr.value;
                                        if (@hasField(@TypeOf(val), "identifier")) {
                                            if (std.mem.eql(u8, val.identifier, namespace_name)) {
                                                break :blk true;
                                            }
                                        }
                                    }
                                }
                            }
                            break :blk false;
                        };

                        if (belongs_here) {
                            // Create the interface constructor
                            const InterfaceBinding = v8.V8Interface(InterfaceType);
                            const template = InterfaceBinding.createTemplate(isolate);
                            const constructor = v8.ffi.v8_FunctionTemplate_GetFunction(template, context);

                            // Attach as property: WebAssembly.Instance = constructor
                            // Per WebIDL spec, namespace properties are non-writable, non-enumerable, non-configurable
                            const iface_key = v8.ffi.v8_String_NewFromUtf8(isolate, iface_decl.name.ptr, @intCast(iface_decl.name.len));
                            _ = v8.ffi.v8_Object_DefineProperty(
                                @ptrCast(ns_obj),
                                context,
                                @ptrCast(iface_key),
                                @ptrCast(constructor),
                                false, // writable
                                false, // enumerable
                                false, // configurable
                            );
                        }
                    }
                }

                // Make namespace object non-extensible (per WebIDL spec)
                _ = v8.ffi.v8_Object_PreventExtensions(@ptrCast(ns_obj), context);
            }
        }

        // Set up constructor inheritance chain after all interfaces are registered
        // This makes Element.__proto__ === Node, Node.__proto__ === EventTarget, etc.
        v8.interface_bindings.setupConstructorInheritance(isolate, context);

        // Register singleton instances (e.g., indexedDB)
        // These are WebIDL interfaces that are exposed as pre-created instances on the global scope
        // rather than as constructors. Per WindowOrWorkerGlobalScope: readonly attribute IDBFactory indexedDB;
        var self = Self{
            .allocator = allocator,
            .isolate = isolate,
            .context = context,
            .input_buffer = .{},
            .history = .{},
        };

        try self.registerSingletons();

        return self;
    }

    /// Register singleton instances on the global object
    ///
    /// Per WebIDL, some interfaces are exposed as pre-created instances rather than
    /// constructors. For example, WindowOrWorkerGlobalScope defines:
    ///   readonly attribute IDBFactory indexedDB;
    ///
    /// This creates those singleton instances and attaches them to the global scope.
    fn registerSingletons(self: *Self) !void {
        const global_obj = v8.ffi.v8_Context_Global(self.context) orelse return error.NoGlobal;

        // Get the runtime context for wrapper caching (required for IDBFactory.init)
        const runtime_ctx = context_manager.getOrCreate(self.context, self.allocator) catch |err| {
            std.debug.print("Warning: Failed to get runtime context for singletons: {}\n", .{err});
            return;
        };

        // Register indexedDB singleton (IDBFactory instance)
        // Per spec: readonly attribute IDBFactory indexedDB; on WindowOrWorkerGlobalScope
        {
            const IDBFactory = @import("interfaces").IDBFactory;

            // Create IDBFactory instance
            const idb_factory_instance = IDBFactory.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create indexedDB singleton: {}\n", .{err});
                return;
            };
            // Store for cleanup on exit
            self.indexeddb_instance = idb_factory_instance;

            // Wrap it as a V8 object using the template registry
            const v8_idb_factory = v8.template_registry.wrapInstanceAsV8Object(
                idb_factory_instance,
                "IDBFactory",
                self.isolate,
                self.context,
            ) catch |err| {
                std.debug.print("Warning: Failed to wrap indexedDB singleton: {}\n", .{err});
                return;
            };

            // Set it as 'indexedDB' property on the global object
            const key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "indexedDB", 9) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(key), @ptrCast(v8_idb_factory));
        }

        // Register fetch stub (normally on WindowOrWorkerGlobalScope, but Window not implemented)
        // This is a temporary stub until Window is properly implemented
        try self.registerFetchStub(global_obj);
    }

    /// Register fetch as a global function stub
    /// Per spec, fetch is defined on WindowOrWorkerGlobalScope mixin.
    /// Since Window is not yet implemented, we register it directly on global.
    fn registerFetchStub(self: *Self, global_obj: *v8.ffi.Object) !void {
        // Create function template for fetch
        const fetch_template = v8.ffi.v8_FunctionTemplate_New(self.isolate, fetchCallback, null) orelse return error.FunctionTemplateCreateFailed;
        v8.ffi.v8_FunctionTemplate_SetLength(fetch_template, 1); // fetch(input, init?)

        // Get the function from template
        const fetch_fn = v8.ffi.v8_FunctionTemplate_GetFunction(fetch_template, self.context) orelse return error.FunctionCreateFailed;

        // Set it as 'fetch' property on the global object
        const key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "fetch", 5) orelse return error.StringCreateFailed;
        _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(key), @ptrCast(fetch_fn));
    }

    pub fn deinit(self: *Self) void {
        // Cleanup history
        for (self.history.items) |item| {
            self.allocator.free(item);
        }
        self.history.deinit(self.allocator);
        self.input_buffer.deinit(self.allocator);

        // Cleanup singleton instances
        if (self.indexeddb_instance) |instance| {
            const IDBFactory = @import("interfaces").IDBFactory;
            IDBFactory.deinit(instance);
            self.indexeddb_instance = null;
        }

        // Cleanup context manager
        context_manager.deinit();

        // Cleanup V8
        v8.ffi.v8_Context_Exit(self.context);
        v8.ffi.v8_Context_Dispose(self.context);
        v8.ffi.v8_Isolate_Exit(self.isolate);
        v8.ffi.v8_Isolate_Dispose(self.isolate);

        // Cleanup WebIDL runtime
        runtime.deinitializeRuntime();
    }

    /// Execute JavaScript code and return result
    pub fn eval(self: *Self, code: []const u8) ![]const u8 {
        // Create V8 string from code
        const source_str = v8.ffi.v8_String_NewFromUtf8(self.isolate, code.ptr, @intCast(code.len)) orelse return error.StringCreateFailed;

        // Compile script
        const script = v8.ffi.v8_Script_Compile(self.context, source_str) orelse {
            // Get exception message
            const exception = v8.ffi.v8_TryCatch_Exception(self.context);
            if (exception) |exc| {
                const exc_str = v8.ffi.v8_Value_ToString(exc, self.context);
                if (exc_str) |str| {
                    const len = v8.ffi.v8_String_Utf8Length(str);
                    const buffer = try self.allocator.alloc(u8, @intCast(len));
                    _ = v8.ffi.v8_String_WriteUtf8(str, buffer.ptr, @intCast(len));
                    return buffer;
                }
            }
            return error.CompileError;
        };

        // Run script
        const result = v8.ffi.v8_Script_Run(self.context, script) orelse {
            // Get exception message
            const exception = v8.ffi.v8_TryCatch_Exception(self.context);
            if (exception) |exc| {
                const exc_str = v8.ffi.v8_Value_ToString(exc, self.context);
                if (exc_str) |str| {
                    const len = v8.ffi.v8_String_Utf8Length(str);
                    const buffer = try self.allocator.alloc(u8, @intCast(len));
                    _ = v8.ffi.v8_String_WriteUtf8(str, buffer.ptr, @intCast(len));
                    return buffer;
                }
            }
            return error.RuntimeError;
        };

        // Run microtasks to process any pending promises
        // This is required because we use explicit microtask policy
        v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(self.isolate);

        // Format the result for display (REPL-only formatting, doesn't affect JS semantics)
        return self.formatValueForDisplay(result);
    }

    /// Format a V8 value for REPL display (like Chrome DevTools)
    /// This is purely cosmetic - it doesn't change JavaScript semantics
    fn formatValueForDisplay(self: *Self, value: *v8.ffi.Value) ![]const u8 {
        // Handle primitives directly
        if (v8.ffi.v8_Value_IsUndefined(value)) {
            return try self.allocator.dupe(u8, "undefined");
        }
        if (v8.ffi.v8_Value_IsNull(value)) {
            return try self.allocator.dupe(u8, "null");
        }
        if (v8.ffi.v8_Value_IsBoolean(value) or v8.ffi.v8_Value_IsNumber(value)) {
            const str = v8.ffi.v8_Value_ToString(value, self.context) orelse {
                return try self.allocator.dupe(u8, "undefined");
            };
            const len = v8.ffi.v8_String_Utf8Length(str);
            const buffer = try self.allocator.alloc(u8, @intCast(len));
            _ = v8.ffi.v8_String_WriteUtf8(str, buffer.ptr, @intCast(len));
            return buffer;
        }
        if (v8.ffi.v8_Value_IsString(value)) {
            // Wrap strings in quotes for display
            const str: *v8.ffi.String = @ptrCast(value);
            const len = v8.ffi.v8_String_Utf8Length(str);
            // +2 for quotes
            const buffer = try self.allocator.alloc(u8, @intCast(len + 2));
            buffer[0] = '\'';
            _ = v8.ffi.v8_String_WriteUtf8(str, buffer.ptr + 1, @intCast(len));
            buffer[@intCast(len + 1)] = '\'';
            return buffer;
        }
        if (v8.ffi.v8_Value_IsFunction(value)) {
            // For functions, show [Function: name] or just [Function]
            const str = v8.ffi.v8_Value_ToString(value, self.context) orelse {
                return try self.allocator.dupe(u8, "[Function]");
            };
            const len = v8.ffi.v8_String_Utf8Length(str);
            const buffer = try self.allocator.alloc(u8, @intCast(len));
            _ = v8.ffi.v8_String_WriteUtf8(str, buffer.ptr, @intCast(len));
            return buffer;
        }

        // For objects (including arrays), use our inspector
        if (v8.ffi.v8_Value_IsObject(value)) {
            return self.formatObjectForDisplay(value);
        }

        // Fallback to toString
        const result_str = v8.ffi.v8_Value_ToString(value, self.context) orelse {
            return try self.allocator.dupe(u8, "undefined");
        };
        const len = v8.ffi.v8_String_Utf8Length(result_str);
        const buffer = try self.allocator.alloc(u8, @intCast(len));
        _ = v8.ffi.v8_String_WriteUtf8(result_str, buffer.ptr, @intCast(len));
        return buffer;
    }

    /// Format an object for REPL display using JavaScript's own introspection
    /// Produces output like: Event {isTrusted: false, type: 'foo', target: null, ...}
    fn formatObjectForDisplay(self: *Self, value: *v8.ffi.Value) ![]const u8 {
        // Store the value temporarily so our formatter can access it
        // We use a unique global name that's unlikely to conflict
        const global = v8.ffi.v8_Context_Global(self.context) orelse {
            return try self.allocator.dupe(u8, "[object]");
        };
        const temp_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "__repl_temp__", 13) orelse {
            return try self.allocator.dupe(u8, "[object]");
        };
        _ = v8.ffi.v8_Object_Set(global, self.context, @ptrCast(temp_key), value);
        defer {
            // Clean up temp variable by setting to undefined
            if (v8.ffi.v8_Undefined(self.isolate)) |undef| {
                _ = v8.ffi.v8_Object_Set(global, self.context, @ptrCast(temp_key), undef);
            }
        }

        // JavaScript code to format the object like Chrome DevTools
        // This runs in the same context, using JS introspection
        //
        // For WebIDL objects (DOM nodes), we show property values:
        // - Primitives (string, number, boolean, null, undefined) - show value
        // - Objects (other DOM nodes) - show constructor name only (don't recurse)
        //
        // This is safe because state memory is zero-initialized (see runtime/instance.zig),
        // preventing crashes from uninitialized pointer fields.
        const format_code =
            \\(function() {
            \\  const obj = __repl_temp__;
            \\  if (obj === null) return 'null';
            \\  if (obj === undefined) return 'undefined';
            \\  
            \\  // Get constructor name
            \\  let name = '';
            \\  if (obj.constructor && obj.constructor.name) {
            \\    name = obj.constructor.name;
            \\  } else {
            \\    name = Object.prototype.toString.call(obj).slice(8, -1);
            \\  }
            \\  
            \\  // Handle arrays specially
            \\  if (Array.isArray(obj)) {
            \\    if (obj.length === 0) return '[]';
            \\    if (obj.length <= 10) {
            \\      const items = obj.map(v => {
            \\        if (typeof v === 'string') return "'" + v + "'";
            \\        if (v === null) return 'null';
            \\        if (v === undefined) return 'undefined';
            \\        if (typeof v === 'object') return v.constructor ? v.constructor.name : '[object]';
            \\        return String(v);
            \\      });
            \\      return '[' + items.join(', ') + ']';
            \\    }
            \\    return 'Array(' + obj.length + ') [...]';
            \\  }
            \\  
            \\  // Collect property names (safe - no getters called yet)
            \\  const propNames = [];
            \\  const seen = new Set();
            \\  
            \\  // 1. Add all own property names
            \\  try {
            \\    const ownNames = Object.getOwnPropertyNames(obj);
            \\    for (const key of ownNames) {
            \\      if (!seen.has(key)) {
            \\        seen.add(key);
            \\        propNames.push({ key, own: true });
            \\      }
            \\    }
            \\  } catch (e) {}
            \\  
            \\  // 2. Walk prototype chain for accessor property names (WebIDL attributes)
            \\  try {
            \\    let proto = Object.getPrototypeOf(obj);
            \\    while (proto && proto !== Object.prototype) {
            \\      const protoNames = Object.getOwnPropertyNames(proto);
            \\      for (const key of protoNames) {
            \\        if (key === 'constructor') continue;
            \\        if (seen.has(key)) continue;
            \\        const desc = Object.getOwnPropertyDescriptor(proto, key);
            \\        // Only include accessor properties (getters) - these are WebIDL attributes
            \\        if (desc && (desc.get || desc.set)) {
            \\          seen.add(key);
            \\          propNames.push({ key, own: false, hasGetter: !!desc.get });
            \\        }
            \\      }
            \\      proto = Object.getPrototypeOf(proto);
            \\    }
            \\  } catch (e) {}
            \\  
            \\  // Filter to only include attributes (not methods)
            \\  const attrNames = propNames.filter(p => p.hasGetter !== false);
            \\  
            \\  // Format a value safely
            \\  function formatValue(val) {
            \\    if (val === null) return 'null';
            \\    if (val === undefined) return 'undefined';
            \\    if (typeof val === 'string') {
            \\      // Truncate long strings
            \\      if (val.length > 30) return "'" + val.slice(0, 27) + "...'";
            \\      return "'" + val + "'";
            \\    }
            \\    if (typeof val === 'number') return String(val);
            \\    if (typeof val === 'boolean') return String(val);
            \\    if (typeof val === 'function') return '[Function]';
            \\    if (typeof val === 'object') {
            \\      // For objects, just show type name (don't access properties - may crash)
            \\      if (Array.isArray(val)) return 'Array(' + val.length + ')';
            \\      return val.constructor ? val.constructor.name : '[object]';
            \\    }
            \\    return String(val);
            \\  }
            \\  
            \\  // Build props array with values
            \\  const props = [];
            \\  const maxProps = 8;
            \\  
            \\  for (const { key } of attrNames) {
            \\    if (props.length >= maxProps) break;
            \\    
            \\    let valStr;
            \\    try {
            \\      const val = obj[key];
            \\      // Skip methods
            \\      if (typeof val === 'function') continue;
            \\      valStr = formatValue(val);
            \\    } catch (e) {
            \\      // Property threw an error
            \\      valStr = '(...)';
            \\    }
            \\    props.push(key + ': ' + valStr);
            \\  }
            \\  
            \\  if (attrNames.length > maxProps) {
            \\    props.push('...');
            \\  }
            \\  
            \\  if (props.length === 0) {
            \\    return name + ' {}';
            \\  }
            \\  
            \\  return name + ' {' + props.join(', ') + '}';
            \\})()
        ;

        const format_str = v8.ffi.v8_String_NewFromUtf8(self.isolate, format_code.ptr, @intCast(format_code.len)) orelse {
            return try self.allocator.dupe(u8, "[object]");
        };

        const format_script = v8.ffi.v8_Script_Compile(self.context, format_str) orelse {
            return try self.allocator.dupe(u8, "[object]");
        };

        const format_result = v8.ffi.v8_Script_Run(self.context, format_script) orelse {
            return try self.allocator.dupe(u8, "[object]");
        };

        const result_str = v8.ffi.v8_Value_ToString(format_result, self.context) orelse {
            return try self.allocator.dupe(u8, "[object]");
        };

        const len = v8.ffi.v8_String_Utf8Length(result_str);
        const buffer = try self.allocator.alloc(u8, @intCast(len));
        _ = v8.ffi.v8_String_WriteUtf8(result_str, buffer.ptr, @intCast(len));
        return buffer;
    }

    /// Get completions for tab completion
    /// Handles both global completions and object property completions (e.g., "Event.")
    pub fn getCompletions(self: *Self, input: []const u8) !struct { completions: [][]const u8, prefix_len: usize } {
        var completions = std.ArrayList([]const u8).empty;
        errdefer {
            for (completions.items) |item| {
                self.allocator.free(item);
            }
            completions.deinit(self.allocator);
        }

        // Check if input contains a dot - if so, complete on object properties
        if (std.mem.lastIndexOfScalar(u8, input, '.')) |dot_pos| {
            const obj_expr = input[0..dot_pos];
            const prop_prefix = input[dot_pos + 1 ..];

            // Evaluate the object expression to get the object
            const obj = self.evalExpression(obj_expr) orelse {
                return .{ .completions = try completions.toOwnedSlice(self.allocator), .prefix_len = prop_prefix.len };
            };

            // Get property names from the object (including prototype chain)
            try self.getPropertyNames(obj, prop_prefix, &completions);

            return .{ .completions = try completions.toOwnedSlice(self.allocator), .prefix_len = prop_prefix.len };
        }

        // No dot - complete on globals
        const global = v8.ffi.v8_Context_Global(self.context) orelse return error.NoGlobal;
        try self.getPropertyNames(global, input, &completions);

        return .{ .completions = try completions.toOwnedSlice(self.allocator), .prefix_len = input.len };
    }

    /// Evaluate an expression and return the resulting object (or null if not an object)
    fn evalExpression(self: *Self, expr: []const u8) ?*v8.ffi.Object {
        if (expr.len == 0) return null;

        const source = v8.ffi.v8_String_NewFromUtf8(
            self.isolate,
            expr.ptr,
            @intCast(expr.len),
        ) orelse return null;

        const script = v8.ffi.v8_Script_Compile(self.context, source) orelse return null;
        const result = v8.ffi.v8_Script_Run(self.context, script) orelse return null;

        // Check if result is an object
        if (!v8.ffi.v8_Value_IsObject(result)) return null;

        return @ptrCast(result);
    }

    /// Get property names from an object that match prefix
    fn getPropertyNames(self: *Self, obj: *v8.ffi.Object, prefix: []const u8, completions: *std.ArrayList([]const u8)) !void {
        // Get all property names including prototype chain
        const names = v8.ffi.v8_Object_GetPropertyNames(self.context, obj) orelse return;
        const len = v8.ffi.v8_Array_Length(names);
        var i: u32 = 0;
        while (i < len) : (i += 1) {
            const name_val = v8.ffi.v8_Array_Get(self.context, names, i) orelse continue;
            const name_str = v8.ffi.v8_Value_ToString(name_val, self.context) orelse continue;

            const name_len = v8.ffi.v8_String_Utf8Length(name_str);
            const name_buf = try self.allocator.alloc(u8, @intCast(name_len));
            _ = v8.ffi.v8_String_WriteUtf8(name_str, name_buf.ptr, @intCast(name_len));

            // Check if matches prefix
            if (prefix.len == 0 or std.mem.startsWith(u8, name_buf, prefix)) {
                try completions.append(self.allocator, name_buf);
            } else {
                self.allocator.free(name_buf);
            }
        }
    }

    /// Legacy wrapper for backward compatibility
    pub fn getGlobalCompletions(self: *Self, prefix: []const u8) ![][]const u8 {
        const result = try self.getCompletions(prefix);
        return result.completions;
    }

    /// Sync file if supported (currently disabled due to Zig stdlib issues with pipes)
    /// File syncing works for interactive terminals but causes stack traces on pipes.
    /// Output flushing is automatic for line-buffered stdout, so explicit sync isn't needed.
    fn syncIfSupported(file: std.fs.File) void {
        _ = file;
        // Disabled: file.sync() causes unexpectedErrno stack traces on pipes (errno 45 ENOTSUP)
        // Interactive terminals handle flushing automatically, pipes work fine without it
    }

    /// Read a single byte from stdin
    fn readByte(stdin: std.fs.File) !u8 {
        var buf: [1]u8 = undefined;
        const n = try stdin.read(&buf);
        if (n == 0) return error.EndOfStream;
        return buf[0];
    }

    /// Write a single byte to file
    fn writeByte(file: std.fs.File, byte: u8) !void {
        const buf = [_]u8{byte};
        try file.writeAll(&buf);
    }

    /// Print formatted output to file
    fn print(allocator: std.mem.Allocator, file: std.fs.File, comptime format: []const u8, args: anytype) !void {
        const str = try std.fmt.allocPrint(allocator, format, args);
        defer allocator.free(str);
        try file.writeAll(str);
    }

    /// Clear current line and redraw with new content
    fn clearAndRedraw(self: *Self, stdout: std.fs.File, new_content: []const u8) !void {
        // Clear current line: move to start, clear to end
        const current_len = self.input_buffer.items.len;
        // Move cursor back to start of input
        if (current_len > 0) {
            try print(self.allocator, stdout, "\x1b[{d}D", .{current_len});
        }
        // Clear from cursor to end of line
        try stdout.writeAll("\x1b[K");
        // Update buffer and display new content
        self.input_buffer.clearRetainingCapacity();
        try self.input_buffer.appendSlice(self.allocator, new_content);
        try stdout.writeAll(new_content);
    }

    /// Read line with tab completion and history navigation
    pub fn readLine(self: *Self) !?[]const u8 {
        const stdout = std.fs.File.stdout();
        const stdin = std.fs.File.stdin();

        // Enable raw mode to capture tab key and arrow keys directly
        var original_termios: std.posix.termios = undefined;
        const is_tty = std.posix.isatty(stdin.handle);
        if (is_tty) {
            original_termios = try std.posix.tcgetattr(stdin.handle);
            var raw = original_termios;
            // Disable canonical mode and echo
            raw.lflag.ICANON = false;
            raw.lflag.ECHO = false;
            // Set minimum bytes and timeout
            raw.cc[@intFromEnum(std.posix.V.MIN)] = 1;
            raw.cc[@intFromEnum(std.posix.V.TIME)] = 0;
            try std.posix.tcsetattr(stdin.handle, .FLUSH, raw);
        }
        defer if (is_tty) {
            std.posix.tcsetattr(stdin.handle, .FLUSH, original_termios) catch {};
        };

        self.input_buffer.clearRetainingCapacity();

        // History navigation index (history.len means "current input", not in history)
        var history_index: usize = self.history.items.len;
        // Save current input when navigating history
        var saved_input: ?[]u8 = null;
        defer if (saved_input) |s| self.allocator.free(s);

        while (true) {
            const byte = readByte(stdin) catch |err| {
                if (err == error.EndOfStream) return null;
                return err;
            };

            switch (byte) {
                '\n' => {
                    try writeByte(stdout, '\n');
                    syncIfSupported(stdout);
                    break;
                },
                '\x1b' => {
                    // Escape sequence (arrow keys, etc.)
                    const seq1 = readByte(stdin) catch continue;
                    if (seq1 != '[') continue;
                    const seq2 = readByte(stdin) catch continue;

                    switch (seq2) {
                        'A' => {
                            // Up arrow - previous history
                            if (self.history.items.len > 0 and history_index > 0) {
                                // Save current input if we're leaving it
                                if (history_index == self.history.items.len) {
                                    if (saved_input) |s| self.allocator.free(s);
                                    saved_input = try self.allocator.dupe(u8, self.input_buffer.items);
                                }
                                history_index -= 1;
                                try self.clearAndRedraw(stdout, self.history.items[history_index]);
                            }
                        },
                        'B' => {
                            // Down arrow - next history
                            if (history_index < self.history.items.len) {
                                history_index += 1;
                                if (history_index == self.history.items.len) {
                                    // Restore saved input
                                    const content = saved_input orelse "";
                                    try self.clearAndRedraw(stdout, content);
                                } else {
                                    try self.clearAndRedraw(stdout, self.history.items[history_index]);
                                }
                            }
                        },
                        else => {},
                    }
                },
                '\t' => {
                    // Tab completion - handles both globals and object properties
                    const input = self.input_buffer.items;
                    const result = try self.getCompletions(input);
                    const completions = result.completions;
                    const prefix_len = result.prefix_len;
                    defer {
                        for (completions) |comp| {
                            self.allocator.free(comp);
                        }
                        self.allocator.free(completions);
                    }

                    if (completions.len == 1) {
                        // Single match - autocomplete
                        const completion = completions[0];
                        const remaining = completion[prefix_len..];
                        try self.input_buffer.appendSlice(self.allocator, remaining);
                        try stdout.writeAll(remaining);
                        syncIfSupported(stdout);
                    } else if (completions.len > 1) {
                        // Multiple matches - show options
                        try writeByte(stdout, '\n');
                        for (completions) |comp| {
                            try print(self.allocator, stdout, "  {s}\n", .{comp});
                        }
                        try stdout.writeAll(">>> ");
                        try stdout.writeAll(self.input_buffer.items);
                        syncIfSupported(stdout);
                    }
                },
                127, 8 => {
                    // Backspace
                    if (self.input_buffer.items.len > 0) {
                        _ = self.input_buffer.pop();
                        try stdout.writeAll("\x08 \x08");
                        syncIfSupported(stdout);
                    }
                },
                4 => {
                    // Ctrl+D - EOF
                    if (self.input_buffer.items.len == 0) {
                        return null;
                    }
                },
                32...126 => {
                    // Printable ASCII
                    try self.input_buffer.append(self.allocator, byte);
                    try writeByte(stdout, byte);
                    syncIfSupported(stdout);
                },
                else => {},
            }
        }

        const line = try self.allocator.dupe(u8, self.input_buffer.items);
        return line;
    }

    /// Add line to history
    pub fn addHistory(self: *Self, line: []const u8) !void {
        const dup = try self.allocator.dupe(u8, line);
        try self.history.append(self.allocator, dup);
    }

    /// Check if JavaScript code is syntactically complete using bracket counting
    /// Returns true if the code can be evaluated, false if more input is needed
    ///
    /// This uses a simple heuristic: count brackets, braces, and parens.
    /// If they're balanced and we're not inside a string/template literal/comment, the code is likely complete.
    fn isCompleteCode(_: *Self, code: []const u8) bool {
        if (code.len == 0) return true;

        var brace_count: i32 = 0; // { }
        var bracket_count: i32 = 0; // [ ]
        var paren_count: i32 = 0; // ( )

        var in_string: u8 = 0; // 0 = not in string, '"' or '\'' = in that string type
        var in_template: bool = false; // Inside template literal ``
        var in_line_comment: bool = false; // Inside // comment
        var in_block_comment: bool = false; // Inside /* */ comment
        var escape_next: bool = false;
        var prev_char: u8 = 0;

        for (code) |c| {
            // Handle newlines - they end single-line comments
            if (c == '\n') {
                in_line_comment = false;
                prev_char = c;
                continue;
            }

            // Skip everything inside single-line comments
            if (in_line_comment) {
                prev_char = c;
                continue;
            }

            // Handle block comment end
            if (in_block_comment) {
                if (prev_char == '*' and c == '/') {
                    in_block_comment = false;
                }
                prev_char = c;
                continue;
            }

            // Handle escape sequences
            if (escape_next) {
                escape_next = false;
                prev_char = c;
                continue;
            }

            if (c == '\\' and (in_string != 0 or in_template)) {
                escape_next = true;
                prev_char = c;
                continue;
            }

            // Handle string literals
            if (in_string != 0) {
                if (c == in_string) {
                    in_string = 0;
                }
                prev_char = c;
                continue;
            }

            // Handle template literals
            if (in_template) {
                if (c == '`') {
                    in_template = false;
                }
                // Note: We're ignoring ${} inside templates for simplicity
                prev_char = c;
                continue;
            }

            // Check for comment start (must be before string check since // could be in code)
            if (prev_char == '/') {
                if (c == '/') {
                    // Single-line comment starts
                    in_line_comment = true;
                    prev_char = c;
                    continue;
                } else if (c == '*') {
                    // Block comment starts
                    in_block_comment = true;
                    prev_char = c;
                    continue;
                }
            }

            // Check for string/template start
            if (c == '"' or c == '\'') {
                in_string = c;
                prev_char = c;
                continue;
            }
            if (c == '`') {
                in_template = true;
                prev_char = c;
                continue;
            }

            // Count brackets (but not if this is a potential comment start)
            if (c != '/') {
                switch (c) {
                    '{' => brace_count += 1,
                    '}' => brace_count -= 1,
                    '[' => bracket_count += 1,
                    ']' => bracket_count -= 1,
                    '(' => paren_count += 1,
                    ')' => paren_count -= 1,
                    else => {},
                }
            }

            prev_char = c;
        }

        // If we're inside a string or template, need more input
        if (in_string != 0 or in_template) {
            return false;
        }

        // If we're inside a block comment, need more input
        if (in_block_comment) {
            return false;
        }

        // If brackets are unbalanced (more opens than closes), need more input
        if (brace_count > 0 or bracket_count > 0 or paren_count > 0) {
            return false;
        }

        // Code appears complete
        return true;
    }

    /// Test result from running a test file
    const TestFileResult = struct {
        passed: usize,
        failed: usize,
        errors: usize,
    };

    /// Minimal assertion library injected into test files
    const assert_library =
        \\(function(g){
        \\  class AssertionError extends Error { constructor(m,a,e,o){super(m);this.name='AssertionError';this.actual=a;this.expected=e;this.operator=o;} }
        \\  function fmt(v){if(v===null)return'null';if(v===undefined)return'undefined';if(typeof v==='string')return JSON.stringify(v);if(typeof v==='object')try{return JSON.stringify(v)}catch(e){return Object.prototype.toString.call(v)}return String(v);}
        \\  function isPromise(v){return v&&typeof v==='object'&&typeof v.then==='function';}
        \\  g._pendingAsserts=[];g._assertsPassed=0;g._assertsFailed=0;
        \\  const assert=function(v,m){if(!v)throw new AssertionError(m||'Expected truthy, got '+fmt(v),v,true,'==');return true;};
        \\  assert.ok=assert;
        \\  assert.isTrue=function(v,m){if(isPromise(v)){g._pendingAsserts.push(v.then(function(r){if(r!==true)throw new AssertionError(m||'Expected true, got '+fmt(r),r,true,'===true');g._assertsPassed++;return true;}).catch(function(e){g._assertsFailed++;throw e;}));return true;}if(v!==true)throw new AssertionError(m||'Expected true, got '+fmt(v),v,true,'===true');return true;};
        \\  assert.isFalse=function(v,m){if(v!==false)throw new AssertionError(m||'Expected false, got '+fmt(v),v,false,'===false');return true;};
        \\  assert.equal=function(a,e,m){if(a!=e)throw new AssertionError(m||'Expected '+fmt(e)+', got '+fmt(a),a,e,'==');return true;};
        \\  assert.strictEqual=function(a,e,m){if(a!==e)throw new AssertionError(m||'Expected '+fmt(e)+' (===), got '+fmt(a),a,e,'===');return true;};
        \\  assert.notEqual=function(a,e,m){if(a==e)throw new AssertionError(m||'Expected '+fmt(a)+' to not equal '+fmt(e),a,e,'!=');return true;};
        \\  assert.notStrictEqual=function(a,e,m){if(a===e)throw new AssertionError(m||'Expected '+fmt(a)+' to not strictly equal '+fmt(e),a,e,'!==');return true;};
        \\  assert.deepEqual=function(a,e,m){if(JSON.stringify(a)!==JSON.stringify(e))throw new AssertionError(m||'Deep equal failed',a,e,'deepEqual');return true;};
        \\  assert.throws=function(fn,ee,m){let threw=false,err;try{fn()}catch(e){threw=true;err=e}if(!threw)throw new AssertionError(m||'Expected function to throw',undefined,ee||'error','throws');if(ee&&typeof ee==='function'&&!(err instanceof ee))throw new AssertionError(m||'Wrong error type',err,ee,'throws');if(ee instanceof RegExp&&!ee.test(err.message))throw new AssertionError(m||'Error message mismatch',err.message,ee,'throws');return true;};
        \\  assert.doesNotThrow=function(fn,m){try{fn()}catch(e){throw new AssertionError(m||'Expected no throw, got: '+e.message,e,undefined,'doesNotThrow')}return true;};
        \\  assert.isNull=function(v,m){if(v!==null)throw new AssertionError(m||'Expected null, got '+fmt(v),v,null,'===null');return true;};
        \\  assert.isNotNull=function(v,m){if(v===null)throw new AssertionError(m||'Expected non-null',v,'non-null','!==null');return true;};
        \\  assert.isUndefined=function(v,m){if(v!==undefined)throw new AssertionError(m||'Expected undefined, got '+fmt(v),v,undefined,'===undefined');return true;};
        \\  assert.isDefined=function(v,m){if(v===undefined)throw new AssertionError(m||'Expected defined value',v,'defined','!==undefined');return true;};
        \\  assert.isFunction=function(v,m){if(typeof v!=='function')throw new AssertionError(m||'Expected function, got '+typeof v,typeof v,'function','typeof');return true;};
        \\  assert.isObject=function(v,m){if(typeof v!=='object'||v===null)throw new AssertionError(m||'Expected object',typeof v,'object','typeof');return true;};
        \\  assert.isString=function(v,m){if(typeof v!=='string')throw new AssertionError(m||'Expected string, got '+typeof v,typeof v,'string','typeof');return true;};
        \\  assert.isNumber=function(v,m){if(typeof v!=='number')throw new AssertionError(m||'Expected number, got '+typeof v,typeof v,'number','typeof');return true;};
        \\  assert.isBoolean=function(v,m){if(typeof v!=='boolean')throw new AssertionError(m||'Expected boolean, got '+typeof v,typeof v,'boolean','typeof');return true;};
        \\  assert.isArray=function(v,m){if(!Array.isArray(v))throw new AssertionError(m||'Expected array, got '+typeof v,typeof v,'array','isArray');return true;};
        \\  assert.instanceOf=function(v,c,m){if(!(v instanceof c))throw new AssertionError(m||'Expected instance of '+c.name,v,c,'instanceof');return true;};
        \\  assert.match=function(v,r,m){if(!r.test(v))throw new AssertionError(m||'Expected "'+v+'" to match '+r,v,r,'match');return true;};
        \\  assert.includes=function(h,n,m){if(!(Array.isArray(h)?h.includes(n):String(h).includes(n)))throw new AssertionError(m||'Expected to include '+fmt(n),h,n,'includes');return true;};
        \\  assert.greaterThan=function(a,b,m){if(!(a>b))throw new AssertionError(m||'Expected '+a+' > '+b,a,b,'>');return true;};
        \\  assert.lessThan=function(a,b,m){if(!(a<b))throw new AssertionError(m||'Expected '+a+' < '+b,a,b,'<');return true;};
        \\  assert.AssertionError=AssertionError;
        \\  g.assert=assert;g.AssertionError=AssertionError;
        \\})(globalThis);
    ;

    /// Run a test file - execute each statement and check if it returns true
    /// Handles multi-line constructs by accumulating lines until they form complete code
    pub fn runTestFile(self: *Self, file_path: []const u8) !TestFileResult {
        const stdout = std.fs.File.stdout();

        // Inject the assertion library before running tests
        const assert_result = self.eval(assert_library) catch |err| {
            try print(self.allocator, stdout, "Error loading assert library: {}\n", .{err});
            return .{ .passed = 0, .failed = 0, .errors = 1 };
        };
        self.allocator.free(assert_result);

        // Read the file
        const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
            try print(self.allocator, stdout, "Error opening {s}: {}\n", .{ file_path, err });
            return .{ .passed = 0, .failed = 0, .errors = 1 };
        };
        defer file.close();

        const content = file.readToEndAlloc(self.allocator, 1024 * 1024) catch |err| {
            try print(self.allocator, stdout, "Error reading {s}: {}\n", .{ file_path, err });
            return .{ .passed = 0, .failed = 0, .errors = 1 };
        };
        defer self.allocator.free(content);

        var passed: usize = 0;
        var failed: usize = 0;
        var errors: usize = 0;

        // Buffer for accumulating multi-line statements
        var stmt_buffer = std.ArrayListUnmanaged(u8){};
        defer stmt_buffer.deinit(self.allocator);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);

            // Skip empty lines and comments
            if (trimmed.len == 0) {
                // Empty line might end a statement
                if (stmt_buffer.items.len > 0 and self.isCompleteCode(stmt_buffer.items)) {
                    const result = self.evalStatement(stmt_buffer.items, &passed, &failed, &errors);
                    _ = result;
                    stmt_buffer.clearRetainingCapacity();
                }
                continue;
            }
            if (std.mem.startsWith(u8, trimmed, "//")) continue;

            // Accumulate the line
            if (stmt_buffer.items.len > 0) {
                try stmt_buffer.append(self.allocator, '\n');
            }
            try stmt_buffer.appendSlice(self.allocator, trimmed);

            // Check if we have complete code
            if (self.isCompleteCode(stmt_buffer.items)) {
                const result = self.evalStatement(stmt_buffer.items, &passed, &failed, &errors);
                _ = result;
                stmt_buffer.clearRetainingCapacity();
            }
        }

        // Handle any remaining code
        if (stmt_buffer.items.len > 0) {
            const result = self.evalStatement(stmt_buffer.items, &passed, &failed, &errors);
            _ = result;
        }

        // Wait for async assertions to complete by pumping microtasks
        // This runs any pending promise callbacks
        var iterations: usize = 0;
        while (iterations < 100) : (iterations += 1) {
            // Pump V8 microtasks
            v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(self.isolate);
            std.Thread.sleep(10 * std.time.ns_per_ms);

            // Check if all pending asserts are done
            const check_code = "globalThis._pendingAsserts?globalThis._pendingAsserts.length:0";
            if (self.eval(check_code)) |check_result| {
                defer self.allocator.free(check_result);
                if (std.mem.eql(u8, check_result, "0")) break;
            } else |_| break;
        }

        // Get async test counts
        const passed_code = "globalThis._assertsPassed||0";
        const failed_code = "globalThis._assertsFailed||0";
        if (self.eval(passed_code)) |p| {
            defer self.allocator.free(p);
            if (std.fmt.parseInt(usize, p, 10)) |n| {
                passed += n;
            } else |_| {}
        } else |_| {}
        if (self.eval(failed_code)) |f| {
            defer self.allocator.free(f);
            if (std.fmt.parseInt(usize, f, 10)) |n| {
                failed += n;
            } else |_| {}
        } else |_| {}

        // Print summary for this file
        const total = passed + failed + errors;
        try print(self.allocator, stdout, "  {d}/{d} passed\n", .{ passed, total });

        return .{ .passed = passed, .failed = failed, .errors = errors };
    }

    /// Evaluate a statement and update counters
    fn evalStatement(self: *Self, code: []const u8, passed: *usize, failed: *usize, errors: *usize) bool {
        // Skip pure declarations (var/let/const without assertions)
        if (std.mem.startsWith(u8, code, "var ") or
            std.mem.startsWith(u8, code, "let ") or
            std.mem.startsWith(u8, code, "const "))
        {
            // Execute but don't count as assertion
            const result = self.eval(code) catch {
                errors.* += 1;
                return false;
            };
            self.allocator.free(result);
            return true;
        }

        // Check if this is an assignment expression (not a declaration)
        // Assignment expressions like "element.id = 'value'" return the assigned value
        // and should not be counted as assertions
        const is_assignment = self.isAssignmentExpression(code);

        // Evaluate the statement
        const result = self.eval(code) catch {
            errors.* += 1;
            return false;
        };
        defer self.allocator.free(result);

        // Check if result is "true"
        if (std.mem.eql(u8, result, "true")) {
            passed.* += 1;
            return true;
        } else if (std.mem.eql(u8, result, "undefined")) {
            // Statements like function calls that return undefined are not assertions
            return true;
        } else if (is_assignment) {
            // Assignment expressions return their assigned value, not true/undefined
            // Don't count them as failed assertions
            return true;
        } else {
            failed.* += 1;
            return false;
        }
    }

    /// Check if code is a simple assignment expression (not a declaration or comparison)
    /// Examples that return true: "element.id = 'value'", "obj.prop = 123"
    /// Examples that return false: "var x = 1", "x === y", "assert.equal(a, b)"
    fn isAssignmentExpression(self: *Self, code: []const u8) bool {
        _ = self;

        // Skip if it's a declaration
        if (std.mem.startsWith(u8, code, "var ") or
            std.mem.startsWith(u8, code, "let ") or
            std.mem.startsWith(u8, code, "const "))
        {
            return false;
        }

        // Skip if it looks like an assertion or function call
        if (std.mem.startsWith(u8, code, "assert.") or
            std.mem.startsWith(u8, code, "console."))
        {
            return false;
        }

        // Look for assignment operator (=) that's not part of == or === or != or !==
        var i: usize = 0;
        while (i < code.len) : (i += 1) {
            const c = code[i];

            // Skip string literals
            if (c == '"' or c == '\'') {
                const quote = c;
                i += 1;
                while (i < code.len and code[i] != quote) : (i += 1) {
                    if (code[i] == '\\' and i + 1 < code.len) i += 1; // Skip escaped chars
                }
                continue;
            }

            // Check for = that's not == or === or != or !== or <= or >= or =>
            if (c == '=') {
                // Check what comes before and after
                const prev = if (i > 0) code[i - 1] else ' ';
                const next = if (i + 1 < code.len) code[i + 1] else ' ';

                // Skip if it's ==, ===, !=, !==, <=, >=, =>
                if (next == '=' or prev == '=' or prev == '!' or prev == '<' or prev == '>' or next == '>') {
                    continue;
                }

                // This is an assignment
                return true;
            }
        }

        return false;
    }

    /// Run the REPL loop
    pub fn run(self: *Self) !void {
        const stdout = std.fs.File.stdout();

        try stdout.writeAll("JavaScript REPL with V8 and WebIDL\n");
        try stdout.writeAll("Type JavaScript code and press Enter\n");
        try stdout.writeAll("Press Tab for completions, Ctrl+D to exit\n\n");
        syncIfSupported(stdout); // Flush output (ignore errors on pipes)

        // Buffer for accumulating multi-line input
        var multiline_buffer = std.ArrayListUnmanaged(u8){};
        defer multiline_buffer.deinit(self.allocator);

        while (true) {
            // Show appropriate prompt
            if (multiline_buffer.items.len == 0) {
                try stdout.writeAll(">>> ");
            } else {
                try stdout.writeAll("... ");
            }
            syncIfSupported(stdout); // Flush prompt immediately

            const line = try self.readLine() orelse break;
            defer self.allocator.free(line);

            // Handle empty lines
            if (line.len == 0) {
                if (multiline_buffer.items.len == 0) {
                    continue;
                }
                // Empty line in multi-line mode - try to execute what we have
            } else {
                // Append line to buffer
                if (multiline_buffer.items.len > 0) {
                    try multiline_buffer.append(self.allocator, '\n');
                }
                try multiline_buffer.appendSlice(self.allocator, line);
            }

            // Check if code is complete
            if (!self.isCompleteCode(multiline_buffer.items)) {
                // Need more input
                continue;
            }

            // Code is complete - evaluate it
            const code = try self.allocator.dupe(u8, multiline_buffer.items);
            defer self.allocator.free(code);

            // Clear buffer for next input
            multiline_buffer.clearRetainingCapacity();

            // Skip if empty after trimming
            const trimmed = std.mem.trim(u8, code, &std.ascii.whitespace);
            if (trimmed.len == 0) continue;

            // Add to history
            try self.addHistory(code);

            // Evaluate
            const result = self.eval(code) catch |err| {
                try print(self.allocator, stdout, "Error: {}\n", .{err});
                syncIfSupported(stdout); // Flush error output
                continue;
            };
            defer self.allocator.free(result);

            try print(self.allocator, stdout, "{s}\n", .{result});
            syncIfSupported(stdout); // Flush result output
        }

        try stdout.writeAll("\nGoodbye!\n");
        syncIfSupported(stdout);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var repl = try Repl.init(allocator);
    defer repl.deinit();

    // Check for command-line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len > 1) {
        // Run test file(s) instead of interactive mode
        var total_passed: usize = 0;
        var total_failed: usize = 0;
        var total_errors: usize = 0;

        for (args[1..]) |file_path| {
            const result = try repl.runTestFile(file_path);
            total_passed += result.passed;
            total_failed += result.failed;
            total_errors += result.errors;
        }

        // Print summary if multiple files
        if (args.len > 2) {
            const stdout = std.fs.File.stdout();
            const summary = try std.fmt.allocPrint(allocator, "\n--- Total: {d} passed, {d} failed, {d} errors ---\n", .{ total_passed, total_failed, total_errors });
            defer allocator.free(summary);
            try stdout.writeAll(summary);
        }

        // Exit with error if any tests failed
        if (total_failed > 0 or total_errors > 0) {
            std.process.exit(1);
        }
    } else {
        // Interactive mode
        try repl.run();
    }
}
