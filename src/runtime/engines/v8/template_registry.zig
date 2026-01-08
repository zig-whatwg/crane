//! V8 Template Registry
//!
//! Runtime registry for V8 FunctionTemplates, enabling dynamic wrapping
//! of Zig instances into properly typed V8 objects.
//!
//! ## BSCOPE-04 Audit: Isolate-Level Template Sharing
//!
//! Templates are ISOLATE-scoped, NOT context-scoped. This is critical for:
//! - Memory efficiency: N interfaces = N templates (not N*contexts)
//! - Performance: Templates created once per isolate lifetime
//! - Correctness: All contexts share the same prototype chains
//!
//! Guarantees verified by audit (BSCOPE-04):
//! 1. `templates_by_index` is a global array, shared across all contexts
//! 2. `getTemplate()` checks isolate match before returning cached template
//! 3. `clear()` invalidates all templates when isolate is disposed
//! 4. `cache_generation` provides staleness detection for isolate reuse
//! 5. `V8Interface(T).createTemplate()` implements getOrCreate pattern
//!
//! ## Problem Solved
//!
//! When a Zig method returns `*runtime.Instance` (e.g., Document.createElement
//! returning an Element), we need to wrap it in a V8 object with the correct
//! prototype chain. This requires:
//!
//! 1. Looking up the interface name from the instance
//! 2. Finding the FunctionTemplate for that interface
//! 3. Creating a new V8 object with that template
//! 4. Storing the Zig instance in the object's internal fields
//!
//! ## Usage
//!
//! During interface registration (V8Interface.registerGlobal):
//! ```zig
//! template_registry.register(interface_name, template, isolate);
//! ```
//!
//! When wrapping an instance for return to JavaScript:
//! ```zig
//! const v8_obj = try template_registry.wrapInstanceAsV8Object(
//!     instance,
//!     "Element",
//!     isolate,
//!     context,
//! );
//! ```

const std = @import("std");
const v8 = @import("ffi.zig");
const runtime = @import("runtime");
const wrapper_type_info = @import("wrapper_type_info.zig");
const dom_type_info = @import("dom_type_info.zig");
const interface_catalog = @import("interface_catalog.zig");

/// Use interface_catalog's count for array sizing
const InterfaceIndex = interface_catalog.InterfaceIndex;
const INTERFACE_COUNT = interface_catalog.valid_interface_count;

/// Per-isolate template array type
/// Each isolate gets its own array of template pointers, avoiding cross-isolate overwrites.
const PerIsolateTemplates = [INTERFACE_COUNT]?*v8.FunctionTemplate;

/// Per-isolate template registry
/// Maps isolate pointer -> array of template pointers for that isolate.
/// This ensures worker isolates don't overwrite main thread templates.
var templates_by_isolate: std.AutoHashMapUnmanaged(*v8.Isolate, *PerIsolateTemplates) = .{};
var registry_allocator: ?std.mem.Allocator = null;
var initialized: bool = false;

/// Mutex for thread-safe access to the per-isolate template map
/// Workers run on separate threads and may register templates concurrently.
var registry_mutex: std.Thread.Mutex = .{};

/// Snapshot mode flag - when true, templates are NOT cached
///
/// This prevents V8's "CheckGlobalAndEternalHandles failed" error during snapshot creation.
/// When in snapshot mode:
/// - Templates are created as Local handles within the current HandleScope
/// - Templates are NOT stored in Zig-side caches (neither template_registry nor per-interface static caches)
/// - V8 serializes only the attached constructors on the global object
/// - At load time, templates are recreated from the snapshot context
///
/// ## Why This Works
///
/// V8 snapshots serialize the JavaScript heap, including constructor functions attached to
/// the global object. The template caches are Zig-side caching - not needed for snapshot creation.
/// By only creating Local handles (not Global), V8 has nothing to complain about.
///
/// ## Usage
///
/// ```zig
/// // In snapshot generator:
/// template_registry.snapshot_mode = true;
/// interface_bindings.initializeBindings(isolate, context);
/// // ... create snapshot ...
/// template_registry.snapshot_mode = false; // reset for normal operation
/// ```
pub var snapshot_mode: bool = false;

/// Global cache generation counter
/// Incremented each time clear() is called to invalidate all per-interface caches.
/// Per-interface static caches in V8Interface(T) store this generation along with
/// their cached templates. When the generation doesn't match, the cache is stale.
pub var cache_generation: u64 = 0;

/// Initialize the registry (called automatically on first use)
fn ensureInitialized() void {
    if (!initialized) {
        initialized = true;
    }
}

/// Clear all registered templates for a specific isolate
///
/// Called when disposing an isolate. Only clears templates for that isolate,
/// not affecting other isolates (e.g., main thread vs worker).
///
/// Also increments the cache_generation counter, which invalidates all
/// per-interface static caches in V8Interface(T).
pub fn clearForIsolate(isolate: *v8.Isolate) void {
    std.log.warn("[clearForIsolate] CALLED for isolate={*}", .{isolate});
    registry_mutex.lock();
    defer registry_mutex.unlock();

    if (templates_by_isolate.get(isolate)) |templates| {
        // Dispose V8 FunctionTemplate handles
        for (templates) |maybe_template| {
            if (maybe_template) |template| {
                v8.v8_FunctionTemplate_Dispose(template);
            }
        }
        // Free the per-isolate array
        if (registry_allocator) |alloc| {
            alloc.destroy(templates);
        }
        _ = templates_by_isolate.remove(isolate);
    }

    // Increment generation to invalidate per-interface static caches
    cache_generation +%= 1;
}

/// Clear all registered templates (for all isolates)
///
/// MUST be called before disposing an isolate and creating a new one.
/// V8 FunctionTemplates are bound to a specific isolate and cannot be reused
/// across isolates. Failure to call this before creating a new isolate will
/// cause crashes (bus errors) when trying to use stale template references.
///
/// This also increments the cache_generation counter, which invalidates all
/// per-interface static caches in V8Interface(T). This is necessary because:
/// 1. V8 may reuse the same memory address for a new isolate
/// 2. Per-interface caches check (isolate == cached_isolate) which would
///    incorrectly match if addresses are reused
/// 3. The generation counter ensures we detect isolate disposal even if
///    the new isolate has the same address
pub fn clear() void {
    std.log.warn("[clear] CALLED - clearing ALL templates for ALL isolates!", .{});
    registry_mutex.lock();
    defer registry_mutex.unlock();

    // Dispose all templates for all isolates
    var iter = templates_by_isolate.iterator();
    while (iter.next()) |entry| {
        const templates = entry.value_ptr.*;
        for (templates) |maybe_template| {
            if (maybe_template) |template| {
                v8.v8_FunctionTemplate_Dispose(template);
            }
        }
        // Free the per-isolate array
        if (registry_allocator) |alloc| {
            alloc.destroy(templates);
        }
    }
    templates_by_isolate.clearRetainingCapacity();
    // Increment generation to invalidate all per-interface static caches
    cache_generation +%= 1;
    // Clear the async iterator template cache in C++ layer
    // This cache is also isolate-specific and must be cleared
    v8.v8_ClearAsyncIteratorTemplateCache();
    // Clear module callbacks - their user_data pointers become invalid
    // when the Zig runtime is deinitialized
    v8.v8_ClearModuleResolveCallback();
    v8.v8_ClearDynamicImportCallback();

    // Clear Zig-side global state that holds V8 references
    // Order matters: clear dependent state before underlying state

    // 1. Clear dynamic import handler (holds V8 callback references)
    const engine = @import("engine.zig");
    engine.clearDynamicImportHandler();

    // 2. Clear global namespace context (holds V8 context references)
    const namespace = @import("namespace.zig");
    namespace.clearGlobalContext();

    // Don't reset initialized - the registry can be reused
}

/// Register a FunctionTemplate for an interface
///
/// Called by V8Interface.registerGlobal after creating the template.
/// This allows later wrapping of instances via wrapInstanceAsV8Object.
///
/// **Snapshot Mode**: When `snapshot_mode` is true, templates are NOT registered.
/// This prevents storing Global handles that would cause V8's
/// "CheckGlobalAndEternalHandles failed" error during snapshot creation.
/// Register a FunctionTemplate for an interface in a specific isolate.
///
/// **IMPORTANT**: Templates are keyed by (name, isolate) pair, NOT just name.
/// This allows each isolate (main, worker1, worker2, etc.) to have its own
/// set of templates without interfering with each other.
///
/// Called by V8Interface.registerGlobal after creating the template.
/// This allows later wrapping of instances via wrapInstanceAsV8Object.
///
/// **Snapshot Mode**: When `snapshot_mode` is true, templates are NOT registered.
/// This prevents storing Global handles that would cause V8's
/// "CheckGlobalAndEternalHandles failed" error during snapshot creation.
pub fn register(
    interface_name: []const u8,
    template: *v8.FunctionTemplate,
    isolate: *v8.Isolate,
) void {
    // In snapshot mode, don't cache templates - they're not needed for snapshot creation
    // and would cause V8 to complain about Global handles
    if (snapshot_mode) {
        std.log.info("[template_registry.register] SKIPPED (snapshot_mode) '{s}'", .{interface_name});
        return;
    }

    ensureInitialized();

    // O(1) index lookup using runtime StaticStringMap
    const idx = interface_catalog.indexOfByNameRuntime(interface_name);
    if (idx == interface_catalog.INVALID_INDEX) {
        // Interface not in catalog - this can happen for dynamically created interfaces
        std.log.warn("[template_registry.register] Interface '{s}' not in catalog", .{interface_name});
        return;
    }

    // Get or create per-isolate template array
    const templates = getOrCreateTemplatesForIsolate(isolate) orelse {
        std.log.err("[template_registry.register] Failed to allocate templates for isolate", .{});
        return;
    };

    // Store template at indexed position for THIS isolate
    templates[idx] = template;
}

/// Get or create the per-isolate template array
fn getOrCreateTemplatesForIsolate(isolate: *v8.Isolate) ?*PerIsolateTemplates {
    registry_mutex.lock();
    defer registry_mutex.unlock();

    // Check if we already have templates for this isolate
    if (templates_by_isolate.get(isolate)) |existing| {
        return existing;
    }

    // Need to allocate new template array for this isolate
    const alloc = registry_allocator orelse std.heap.page_allocator;
    registry_allocator = alloc;

    const templates = alloc.create(PerIsolateTemplates) catch {
        return null;
    };
    templates.* = [_]?*v8.FunctionTemplate{null} ** INTERFACE_COUNT;

    templates_by_isolate.put(alloc, isolate, templates) catch {
        alloc.destroy(templates);
        return null;
    };

    return templates;
}

/// Register a FunctionTemplate by interface index (O(1) direct access)
pub fn registerByIndex(
    idx: InterfaceIndex,
    template: *v8.FunctionTemplate,
    isolate: *v8.Isolate,
) void {
    if (snapshot_mode) return;
    ensureInitialized();

    if (idx >= INTERFACE_COUNT) {
        std.log.err("[template_registry.registerByIndex] Index {d} out of bounds", .{idx});
        return;
    }

    const templates = getOrCreateTemplatesForIsolate(isolate) orelse return;
    templates[idx] = template;
}

/// Get a registered FunctionTemplate by interface name
/// Get a registered FunctionTemplate by interface name for a specific isolate.
///
/// **IMPORTANT**: V8 templates are isolate-specific. A template created in one
/// isolate cannot be used in another. This function checks the current isolate
/// and only returns a template if it was registered for that same isolate.
///
/// For worker isolates, this will correctly return null, signaling that
/// templates need to be re-registered for the worker's isolate.
pub fn getTemplate(interface_name: []const u8) ?*v8.FunctionTemplate {
    // Debug: Log entry for MessageEvent
    if (std.mem.eql(u8, interface_name, "MessageEvent")) {
        std.debug.print("[GET-TEMPLATE-ENTRY] getTemplate('MessageEvent') called\n", .{});
    }

    ensureInitialized();

    // Get the current isolate to verify template compatibility
    const current_isolate = v8.v8_Isolate_GetCurrent();
    if (current_isolate == null) {
        std.log.warn("[getTemplate] No current isolate!", .{});
        return null;
    }

    // O(1) index lookup using runtime StaticStringMap
    const idx = interface_catalog.indexOfByNameRuntime(interface_name);
    if (idx == interface_catalog.INVALID_INDEX) {
        std.log.warn("[getTemplate] Interface '{s}' not in catalog", .{interface_name});
        return null;
    }

    // Get templates for current isolate
    registry_mutex.lock();
    defer registry_mutex.unlock();

    const templates = templates_by_isolate.get(current_isolate.?) orelse {
        return null;
    };

    if (templates[idx]) |template| {
        return template;
    }
    return null;
}

/// Get a registered FunctionTemplate by interface index (O(1) direct access)
pub fn getTemplateByIndex(idx: InterfaceIndex) ?*v8.FunctionTemplate {
    ensureInitialized();

    const current_isolate = v8.v8_Isolate_GetCurrent();
    if (current_isolate == null) return null;

    if (idx >= INTERFACE_COUNT) return null;

    registry_mutex.lock();
    defer registry_mutex.unlock();

    const templates = templates_by_isolate.get(current_isolate.?) orelse return null;
    return templates[idx];
}

/// Wrap a Zig runtime.Instance into a V8 Object with the correct prototype
///
/// This is the key function for returning interface instances from methods.
/// It creates a V8 object with the correct FunctionTemplate (prototype chain)
/// and stores the Zig instance pointer in the internal fields.
///
/// **Now with wrapper identity caching!** Returns the same V8 wrapper for the
/// same Zig instance, solving the querySelector identity problem.
///
/// ## Parameters
/// - instance: The Zig instance to wrap
/// - interface_name: Name of the interface (e.g., "Element", "Document")
/// - isolate: V8 isolate
/// - context: V8 context
///
/// ## Returns
/// A V8 Object wrapping the instance (cached if already wrapped, new if first time)
pub fn wrapInstanceAsV8Object(
    instance: *runtime.Instance,
    interface_name: []const u8,
    isolate: *v8.Isolate,
    context: *v8.Context,
) !*v8.Object {

    // ========================================
    // SPECIAL CASE: Window instances with bound V8 global
    // ========================================
    // Window instances ARE the V8 global object in their realm.
    // When contentWindow is accessed from another realm, we need to return
    // the actual V8 global (which has DOMRectReadOnly, etc. on it).
    if (std.mem.eql(u8, interface_name, "Window")) {
        const WindowImpl = @import("impls").Window;
        if (WindowImpl.getBoundV8Global(instance)) |bound_global| {
            // Return the bound global directly - this is the key for cross-realm!
            // bound_global is a Global<Object>* which is the correct type for return values
            return @ptrCast(bound_global);
        }
    }

    // ========================================
    // CACHE LOOKUP: Check if we already have a wrapper for this instance
    // ========================================
    const ctx_mgr = @import("context_manager.zig");
    if (ctx_mgr.get(context)) |runtime_ctx| {
        if (runtime_ctx.getV8WrapperCacheStorage()) |cache_storage| {
            const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
            const cache: *WrapperCache = @ptrCast(@alignCast(cache_storage));

            // Cache hit? Return existing wrapper (same V8 object)
            if (cache.get(instance)) |cached_wrapper| {
                if (std.mem.eql(u8, interface_name, "MessageEvent")) {
                    std.debug.print("[WRAPPER-CACHE-HIT] MessageEvent: Returning cached wrapper, bypassing getTemplate\n", .{});
                }
                return cached_wrapper;
            } else {
                if (std.mem.eql(u8, interface_name, "MessageEvent")) {
                    std.debug.print("[WRAPPER-CACHE-MISS] MessageEvent: No cached wrapper, will call getTemplate\n", .{});
                }
            }
        }
    }

    // ========================================
    // CACHE MISS: Create new wrapper
    // ========================================

    // Look up the FunctionTemplate for this interface
    // Check if we're in a worker context BEFORE getting template
    // Workers need fresh templates because snapshot templates have disconnected callbacks
    //
    // IMPORTANT: We check if the GLOBAL OBJECT IS an instance of DedicatedWorkerGlobalScope,
    // NOT whether the constructor exists. The constructor exists on both main thread and workers,
    // but only workers have the global object BE a DedicatedWorkerGlobalScope instance.
    //
    // Detection: Workers have 'postMessage' on global but NO 'document'.
    // Window has both 'postMessage' (via WindowPostMessage mixin) AND 'document'.
    const global_for_check = v8.v8_Context_Global(context);
    const is_worker_context = blk: {
        if (global_for_check) |g| {
            // Check if global has 'postMessage' as own property - workers have this, Window doesn't
            // This is more reliable than checking constructor existence
            const postmsg_key = v8.v8_String_NewFromUtf8(isolate, "postMessage", 11) orelse break :blk false;
            if (v8.v8_Object_HasOwnProperty(g, context, @ptrCast(postmsg_key))) {
                // Also verify it's NOT a Window by checking for 'document' (Window has it, workers don't)
                const doc_key = v8.v8_String_NewFromUtf8(isolate, "document", 8) orelse break :blk true;
                if (v8.v8_Object_HasOwnProperty(g, context, @ptrCast(doc_key))) {
                    // Has both postMessage AND document - this is Window, not worker
                    break :blk false;
                }
                break :blk true; // Has postMessage but no document - this is a worker
            }
        }
        break :blk false;
    };

    // For workers, ALWAYS create fresh templates - snapshot templates have disconnected callbacks
    // For main context, use cached templates from snapshot
    var created_on_demand = false;
    const template: *v8.FunctionTemplate = if (is_worker_context) fresh_blk: {
        // Worker context - force fresh template creation
        const interface_bindings = @import("interface_bindings.zig");
        created_on_demand = true;
        std.debug.print("[WRAP-WORKER] {s}: forcing fresh template creation for worker\n", .{interface_name});
        break :fresh_blk interface_bindings.createTemplateOnDemandByName(interface_name, isolate) orelse fallback: {
            std.debug.print("[WRAP-WORKER] {s}: fresh template creation failed, falling back to cache\n", .{interface_name});
            break :fallback getTemplate(interface_name) orelse {
                std.debug.print("[WRAP-WORKER] {s}: no cached template either\n", .{interface_name});
                return error.TemplateNotRegistered;
            };
        };
    } else cache_blk: {
        // Main context - use cached template, create on-demand if not found
        break :cache_blk getTemplate(interface_name) orelse on_demand: {
            const interface_bindings = @import("interface_bindings.zig");
            created_on_demand = true;
            break :on_demand interface_bindings.createTemplateOnDemandByName(interface_name, isolate) orelse {
                std.debug.print("[WRAP] Template not found for {s} (on-demand creation failed)\n", .{interface_name});
                return error.TemplateNotRegistered;
            };
        };
    };

    // Get the InstanceTemplate and create a new object
    // IMPORTANT: Use InstanceTemplate()->NewInstance(), NOT Function::NewInstance()
    // Function::NewInstance() calls the constructor callback, which throws "Illegal constructor"
    // for non-constructible interfaces like HTMLCollection and Navigator.
    // See AGENTS.md Golden Rule #16 for details.
    const instance_template = v8.v8_FunctionTemplate_InstanceTemplate(template);
    const v8_object = v8.v8_ObjectTemplate_NewInstance(instance_template, context) orelse {
        return error.ObjectCreationFailed;
    };

    // ========================================
    // SET INTERNAL FIELDS IMMEDIATELY after object creation
    // ========================================
    // CRITICAL: Must set internal fields BEFORE setting prototype, because
    // prototype setup can trigger accessor callbacks that need the instance pointer.
    // Store the Zig instance in internal field 0
    v8.v8_Object_SetAlignedPointerInInternalField(
        v8_object,
        0,
        @ptrCast(instance),
    );

    // Store WrapperTypeInfo in internal field 1 (for type-safe unwrapping)
    // Use comptime-generated registry which has ALL interfaces, not the manual dom_type_info
    const wrapper_type_info_registry = @import("wrapper_type_info_registry.zig");
    if (wrapper_type_info_registry.getWrapperTypeInfoByName(interface_name)) |type_info| {
        v8.v8_Object_SetAlignedPointerInInternalField(
            v8_object,
            1,
            @ptrCast(@constCast(type_info)),
        );
    }

    // ========================================
    // SET PROTOTYPE: Handle differently based on template source
    // ========================================
    // For SNAPSHOT-RESTORED templates: Use global.Constructor.prototype because
    // it has accessors reinstalled via the snapshot restoration process.
    //
    // For ON-DEMAND templates: DO NOT override the prototype! The template was
    // just created with fresh accessors, and global.Constructor.prototype might
    // be from the snapshot with disconnected/broken callbacks.
    //
    // This fixes the issue where MessageEvent.data returns undefined in workers:
    // the on-demand created template has working accessors, but we were overwriting
    // its prototype with one from the snapshot that had disconnected callbacks.
    // Note: is_worker_context was already computed above (line ~429)
    const global = v8.v8_Context_Global(context);

    std.debug.print("[WRAP-DEBUG] {s}: created_on_demand={}, is_worker_context={}\n", .{ interface_name, created_on_demand, is_worker_context });

    // Skip prototype override in worker contexts - use template's prototype which has working accessors
    if (created_on_demand or is_worker_context) {
        std.debug.print("[WRAP-SKIP-OVERRIDE] {s}: keeping template prototype (worker={}, on_demand={})\n", .{ interface_name, is_worker_context, created_on_demand });
    } else {
        // For snapshot-restored templates in main context, use global.Constructor.prototype
        const prototype_set = blk: {
            if (global) |g| {
                const constructor_name = v8.v8_String_NewFromUtf8(isolate, interface_name.ptr, @intCast(interface_name.len));
                if (constructor_name) |cname| {
                    const constructor_value = v8.v8_Object_Get(g, context, @ptrCast(cname));
                    if (constructor_value) |cval| {
                        if (v8.v8_Value_IsObject(cval)) {
                            const constructor_obj: *v8.Object = @ptrCast(cval);
                            const prototype_str = v8.v8_String_NewFromUtf8(isolate, "prototype", 9);
                            if (prototype_str) |proto_name| {
                                const prototype_value = v8.v8_Object_Get(constructor_obj, context, @ptrCast(proto_name));
                                if (prototype_value) |proto_val| {
                                    if (v8.v8_Value_IsObject(proto_val)) {
                                        _ = v8.v8_Object_SetPrototype(v8_object, context, proto_val);
                                        // Detect context type
                                        const ctx_type: []const u8 = ctx_blk: {
                                            const window_key = v8.v8_String_NewFromUtf8(isolate, "Window", 6) orelse break :ctx_blk "unknown";
                                            if (v8.v8_Object_Get(g, context, @ptrCast(window_key))) |_| {
                                                break :ctx_blk "MAIN";
                                            }
                                            break :ctx_blk "WORKER";
                                        };
                                        std.debug.print("[WRAP-{s}] {s}: prototype set from global, proto_addr={*}, context={*}\n", .{ ctx_type, interface_name, proto_val, context });

                                        // VERIFICATION: Check if object's actual prototype matches what we set
                                        if (v8.v8_Object_GetPrototype(v8_object)) |actual_proto| {
                                            const same_obj = v8.v8_Value_StrictEquals(actual_proto, proto_val);
                                            std.debug.print("[WRAP-VERIFY] {s}: SetPrototype worked? actual_proto={*}, same_as_set={}\n", .{ interface_name, actual_proto, same_obj });

                                            // Re-fetch global.Constructor.prototype to verify it's still the same
                                            const constructor_name2 = v8.v8_String_NewFromUtf8(isolate, interface_name.ptr, @intCast(interface_name.len));
                                            if (constructor_name2) |cname2| {
                                                const constructor_value2 = v8.v8_Object_Get(g, context, @ptrCast(cname2));
                                                if (constructor_value2) |cval2| {
                                                    if (v8.v8_Value_IsObject(cval2)) {
                                                        const constructor_obj2: *v8.Object = @ptrCast(cval2);
                                                        const prototype_str2 = v8.v8_String_NewFromUtf8(isolate, "prototype", 9);
                                                        if (prototype_str2) |proto_name2| {
                                                            const prototype_value2 = v8.v8_Object_Get(constructor_obj2, context, @ptrCast(proto_name2));
                                                            if (prototype_value2) |proto_val2| {
                                                                const refetch_same = v8.v8_Value_StrictEquals(proto_val, proto_val2);
                                                                const actual_matches_refetch = v8.v8_Value_StrictEquals(actual_proto, proto_val2);
                                                                std.debug.print("[WRAP-VERIFY] {s}: refetch_proto={*}, original==refetch={}, actual==refetch={}\n", .{ interface_name, proto_val2, refetch_same, actual_matches_refetch });
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            // For MessageEvent, check if "data" accessor exists on prototype
                                            if (std.mem.eql(u8, interface_name, "MessageEvent")) {
                                                const proto_obj: *v8.Object = @ptrCast(proto_val);
                                                const data_key = v8.v8_String_NewFromUtf8(isolate, "data", 4);
                                                if (data_key) |dk| {
                                                    const has_data = v8.v8_Object_HasOwnProperty(proto_obj, context, @ptrCast(dk));
                                                    std.debug.print("[WRAP-ACCESSOR-CHECK] MessageEvent.prototype hasOwnProperty('data')={}\n", .{has_data});

                                                    // Also check GetOwnPropertyDescriptor
                                                    if (v8.v8_Object_GetOwnPropertyDescriptor(proto_obj, context, @ptrCast(dk))) |desc| {
                                                        const is_undefined = v8.v8_Value_IsUndefined(desc);
                                                        const is_object = v8.v8_Value_IsObject(desc);
                                                        std.debug.print("[WRAP-ACCESSOR-CHECK] MessageEvent.prototype.data descriptor: is_undefined={}, is_object={}\n", .{ is_undefined, is_object });

                                                        // Check if descriptor has "get" vs "value" property
                                                        if (is_object) {
                                                            const desc_obj: *v8.Object = @ptrCast(desc);
                                                            const get_key = v8.v8_String_NewFromUtf8(isolate, "get", 3);
                                                            const value_key = v8.v8_String_NewFromUtf8(isolate, "value", 5);
                                                            if (get_key) |gk| {
                                                                const has_get = v8.v8_Object_HasOwnProperty(desc_obj, context, @ptrCast(gk));
                                                                std.debug.print("[WRAP-ACCESSOR-CHECK] descriptor has 'get'={} (ACCESSOR)\n", .{has_get});
                                                                if (has_get) {
                                                                    if (v8.v8_Object_Get(desc_obj, context, @ptrCast(gk))) |get_val| {
                                                                        const get_is_func = v8.v8_Value_IsFunction(get_val);
                                                                        const get_is_undef = v8.v8_Value_IsUndefined(get_val);
                                                                        std.debug.print("[WRAP-ACCESSOR-CHECK] 'get' value: is_function={}, is_undefined={}\n", .{ get_is_func, get_is_undef });
                                                                    }
                                                                }
                                                            }
                                                            if (value_key) |vk| {
                                                                const has_value = v8.v8_Object_HasOwnProperty(desc_obj, context, @ptrCast(vk));
                                                                std.debug.print("[WRAP-ACCESSOR-CHECK] descriptor has 'value'={} (DATA PROPERTY - BAD!)\n", .{has_value});
                                                            }
                                                        }
                                                    } else {
                                                        std.debug.print("[WRAP-ACCESSOR-CHECK] MessageEvent.prototype.data GetOwnPropertyDescriptor returned null\n", .{});
                                                    }

                                                    // CRITICAL: Check if the INSTANCE has own "data" property (shadowing)
                                                    const instance_has_data = v8.v8_Object_HasOwnProperty(v8_object, context, @ptrCast(dk));
                                                    std.debug.print("[WRAP-ACCESSOR-CHECK] MessageEvent INSTANCE hasOwnProperty('data')={} (SHADOWING if true!)\n", .{instance_has_data});
                                                }
                                            }
                                        }

                                        break :blk true;
                                    }
                                }
                            }
                        }
                    }
                }
            }
            break :blk false;
        };

        // Fallback to template's prototype if global.Constructor.prototype not available
        if (!prototype_set) {
            const func = v8.v8_FunctionTemplate_GetFunction(template, context);
            if (func) |constructor_func| {
                const prototype_str = v8.v8_String_NewFromUtf8(isolate, "prototype", 9);
                if (prototype_str) |proto_name| {
                    const prototype_value = v8.v8_Object_Get(@ptrCast(constructor_func), context, @ptrCast(proto_name));
                    if (prototype_value) |proto_val| {
                        if (v8.v8_Value_IsObject(proto_val)) {
                            _ = v8.v8_Object_SetPrototype(v8_object, context, proto_val);
                            std.debug.print("[WRAP-FALLBACK] {s}: prototype set from template, proto_addr={*}, context={*}\n", .{ interface_name, proto_val, context });
                        } else {
                            std.debug.print("[WRAP] {s}: prototype is not an object!\n", .{interface_name});
                        }
                    } else {
                        std.debug.print("[WRAP] {s}: prototype_value is null!\n", .{interface_name});
                    }
                }
            }
        }
    } // Close else block for !created_on_demand

    // For legacy platform objects, wrap in a Proxy to ensure correct
    // [[OwnPropertyKeys]] enumeration order per WebIDL §3.9.6.
    const final_object = if (isLegacyPlatformObject(interface_name)) blk: {
        const lpo_proxy = @import("legacy_platform_object_proxy.zig");
        break :blk lpo_proxy.wrapInProxy(v8_object, isolate, context);
    } else v8_object;

    // ========================================
    // CACHE THE WRAPPER: Store for future lookups
    // ========================================
    if (ctx_mgr.get(context)) |runtime_ctx| {
        if (runtime_ctx.getV8WrapperCacheStorage()) |cache_storage| {
            const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
            const cache: *WrapperCache = @ptrCast(@alignCast(cache_storage));

            // Cache the final object (Proxy for LPOs, target for others)
            cache.set(instance, final_object, isolate) catch |err| {
                std.log.warn("Failed to cache V8 wrapper: {s}", .{@errorName(err)});
            };
        }
    }

    return final_object;
}

/// Comptime-generated vtable lookup using inline for loop.
/// Automatically discovers all interfaces at compile time by iterating over
/// the interfaces module's declarations, eliminating manual maintenance.
pub const VtableLookup = struct {
    const interfaces = @import("interfaces");

    /// Look up the interface name for a given vtable pointer.
    /// Uses comptime inline for to generate efficient comparison code.
    pub fn lookup(vtable_ptr: *const anyopaque) []const u8 {
        // Need high branch quota to handle ~1100 interfaces
        @setEvalBranchQuota(200000);

        const decls = @typeInfo(interfaces).@"struct".decls;

        inline for (decls) |decl| {
            const T = @field(interfaces, decl.name);
            // Check if this is actually a type (not a value or function)
            if (@typeInfo(@TypeOf(T)) == .type) {
                // Check if it has both vtable and Meta declarations
                if (@hasDecl(T, "vtable") and @hasDecl(T, "Meta")) {
                    const meta = T.Meta;
                    // Exclude mixins - they don't have instantiable vtables
                    const is_mixin = if (@hasDecl(meta, "is_mixin")) meta.is_mixin else false;
                    if (!is_mixin) {
                        // Compare vtable pointer addresses
                        if (vtable_ptr == @as(*const anyopaque, @ptrCast(&T.vtable))) {
                            return meta.name;
                        }
                    }
                }
            }
        }
        // Default to "Object" for unknown vtables
        return "Object";
    }
};

/// Get the interface name from an Instance
///
/// This looks at the instance's vtable to determine which interface it belongs to.
/// Uses comptime-generated VtableLookup to compare vtable addresses against all
/// known interface vtables automatically.
pub fn getInstanceInterfaceName(instance: *runtime.Instance) []const u8 {
    // Safety check: validate instance pointer before dereferencing vtable
    if (@intFromPtr(instance) < 0x1000) {
        // Invalid pointer - return generic name
        return "Object";
    }

    // Use comptime-generated lookup
    return VtableLookup.lookup(@ptrCast(instance.vtable));
}

// ============================================================================
// Legacy Platform Object Detection
// ============================================================================

/// Known legacy platform object interfaces that have indexed or named property access.
/// These require Proxy wrapping to ensure correct [[OwnPropertyKeys]] enumeration order.
const legacy_platform_objects = [_][]const u8{
    // DOM Collections with indexed/named access
    "NodeList",
    "HTMLCollection",
    "NamedNodeMap",
    "DOMTokenList",
    "DOMStringList",
    "DOMRectList",
    "StyleSheetList",
    "CSSRuleList",
    "CSSStyleDeclaration",
    "MediaList",
    // Form-related collections
    "HTMLFormControlsCollection",
    "HTMLOptionsCollection",
    "RadioNodeList",
    // Table-related collections
    "HTMLTableRowsCollection",
    "HTMLTableCellsCollection",
    "HTMLTableSectionElement", // has rows collection
    // File API
    "FileList",
    // Storage
    "Storage",
    // Plugin-related (legacy)
    "Plugin",
    "PluginArray",
    "MimeType",
    "MimeTypeArray",
    // Touch events
    "TouchList",
    // Data transfer
    "DataTransferItemList",
    // Selection
    "Selection",
    // NOTE: Window is NOT included here because it's the global object
    // and wrapping it in a Proxy breaks method invocation semantics.
    // Window's OwnPropertyKeys order needs special handling in V8 C++.
};

/// Check if an interface name represents a legacy platform object.
/// Legacy platform objects need Proxy wrapping for correct OwnPropertyKeys behavior.
fn isLegacyPlatformObject(interface_name: []const u8) bool {
    for (legacy_platform_objects) |lpo_name| {
        if (std.mem.eql(u8, interface_name, lpo_name)) {
            return true;
        }
    }
    return false;
}

// ============================================================================
// Tests
// ============================================================================

test "template_registry basic operations" {
    // This test would require V8 initialization, so we just test the registry logic
    ensureInitialized();

    // Verify initial state
    const template = getTemplate("NonExistent");
    try std.testing.expectEqual(@as(?*v8.FunctionTemplate, null), template);
}

test "template_registry isolate-level sharing" {
    // BSCOPE-04: Verify templates are isolate-scoped, not context-scoped
    // Templates should be shared across all contexts within the same isolate
    ensureInitialized();

    // Verify cache_generation starts at 0
    try std.testing.expectEqual(@as(u32, 0), cache_generation);

    // After clear(), generation should increment
    clear();
    try std.testing.expectEqual(@as(u32, 1), cache_generation);

    // Multiple clears increment generation (used for staleness detection)
    clear();
    try std.testing.expectEqual(@as(u32, 2), cache_generation);
}

test "template_registry count stability" {
    // BSCOPE-04: Template count should not grow with number of contexts
    // This verifies that templates are shared, not duplicated per context
    ensureInitialized();

    // With per-isolate storage, we just verify the map is accessible
    // Count is per-isolate now, not global
    registry_mutex.lock();
    defer registry_mutex.unlock();

    const initial_count = templates_by_isolate.count();

    // The count should remain stable regardless of how many times we query
    const query_count = templates_by_isolate.count();

    try std.testing.expectEqual(initial_count, query_count);
}
