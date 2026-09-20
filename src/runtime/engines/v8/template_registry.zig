//! V8 Template Registry
//!
//! Runtime registry for V8 FunctionTemplates, enabling dynamic wrapping
//! of Zig instances into properly typed V8 objects.
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
const instance_bridge = @import("dom").instance_bridge;
const ownership = @import("isolate_ownership.zig");

const log = std.log.scoped(.template_registry);

/// Maximum number of interface templates that can be registered
// Capacity is per-PROCESS, not per-isolate, and every isolate registers its own
// entry for every interface it uses. With ~1,263 generated interfaces a single
// isolate already approaches 2048; a worker would have exhausted it and silently
// dropped registrations, because the add below is a bounds check with no error.
const MAX_TEMPLATES = 8192;

/// Entry in the template registry
const TemplateEntry = struct {
    name: []const u8,
    template: *v8.FunctionTemplate,
    isolate: *v8.Isolate,
};

/// Global template registry
/// Maps interface names to their FunctionTemplates
var templates: [MAX_TEMPLATES]?TemplateEntry = [_]?TemplateEntry{null} ** MAX_TEMPLATES;
var template_count: usize = 0;
var initialized: bool = false;

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

/// Dispose and remove only the templates belonging to `isolate`.
///
/// `clear()` below wipes EVERY entry. That was harmless while the registry could
/// only ever hold one isolate's templates, but register() is now per-(interface,
/// isolate) - so disposing one isolate with clear() would dispose a still-live
/// worker isolate's FunctionTemplates too, and the next use of those would be a
/// use-after-free.
///
/// The cache generation is still bumped: per-interface caches in V8Interface(T)
/// compare against a cached isolate pointer, and V8 may hand the same address to a
/// new isolate, so they must be invalidated whenever any isolate goes away.
///
/// The process-wide C++ caches that clear() also resets - async iterator
/// templates, module resolve/dynamic-import callbacks, the namespace context -
/// are deliberately NOT touched here. They are not per-isolate, and tearing them
/// down while another isolate is still running would break it. Full teardown
/// still goes through clear().
pub fn clearForIsolate(isolate: *v8.Isolate) void {
    var write: usize = 0;
    for (templates[0..template_count]) |maybe_entry| {
        if (maybe_entry) |e| {
            if (e.isolate == isolate) {
                v8.v8_FunctionTemplate_Dispose(e.template);
                continue; // drop it
            }
            templates[write] = e;
            write += 1;
        }
    }
    // Null out the vacated tail so stale entries cannot be read back.
    var i = write;
    while (i < template_count) : (i += 1) templates[i] = null;
    template_count = write;

    cache_generation +%= 1;
}

/// Clear all registered templates
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
    // Dispose V8 FunctionTemplate handles before clearing entries
    // V8 Global handles must be explicitly disposed to release resources
    for (&templates) |*entry| {
        if (entry.*) |e| {
            v8.v8_FunctionTemplate_Dispose(e.template);
        }
        entry.* = null;
    }
    template_count = 0;
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

/// How many (interface, isolate) entries are currently registered.
///
/// Exposed for tests and diagnostics: the count is what distinguishes a genuine
/// re-registration (updates in place) from an append, and unbounded growth here is
/// how the registry would silently fill and start dropping templates.
pub fn registeredCount() usize {
    return template_count;
}

/// Capacity, so a test can assert two full interface sets fit rather than
/// hard-coding a number that drifts.
pub const capacity = MAX_TEMPLATES;

/// Remove every entry WITHOUT disposing any V8 handle.
///
/// `clear()` calls `v8_FunctionTemplate_Dispose` on each entry, which is correct
/// for real templates and fatal for a test using synthetic pointers. This exists
/// so a test can borrow the registry and put it back.
pub fn resetForTest() void {
    for (&templates) |*entry| entry.* = null;
    template_count = 0;
    cache_generation +%= 1;
}

/// Register a FunctionTemplate for an interface
///
/// Called by V8Interface.registerGlobal after creating the template.
/// This allows later wrapping of instances via wrapInstanceAsV8Object.
///
/// **Snapshot Mode**: When `snapshot_mode` is true, templates ARE still registered
/// for deduplication purposes (ensuring parent templates are reused). The Global
/// handles will be cleared by v8_Snapshot_ClearGlobalHandles() before CreateBlob().
/// After snapshot creation, the registry should be cleared via clear().
pub fn register(
    interface_name: []const u8,
    template: *v8.FunctionTemplate,
    isolate: *v8.Isolate,
) void {
    // NOTE: We register even in snapshot_mode for deduplication of parent templates.
    // The handles will be cleared by v8_Snapshot_ClearGlobalHandles() before CreateBlob().

    ensureInitialized();

    // Check if already registered (avoid duplicates on re-registration).
    //
    // Match on name AND isolate. Matching on name alone made this registry
    // single-isolate by construction: a second isolate registering "Element"
    // reassigned the FIRST isolate's entry to itself, and since lookup requires
    // both name and isolate to match (getTemplateForIsolate), the first isolate
    // then found NO template for an interface it had already registered.
    //
    // V8 Global<FunctionTemplate> handles are isolate-scoped and cannot be shared,
    // so one entry per (interface, isolate) is the only correct shape. This is the
    // structural half of Phase 5's exit criterion: two isolates each holding a full
    // interface template set at the same time.
    for (templates[0..template_count]) |*entry| {
        if (entry.*) |*e| {
            if (std.mem.eql(u8, e.name, interface_name) and e.isolate == isolate) {
                // Same interface, same isolate: genuine re-registration.
                e.template = template;
                return;
            }
        }
    }

    // Add new entry
    if (template_count < MAX_TEMPLATES) {
        templates[template_count] = .{
            .name = interface_name,
            .template = template,
            .isolate = isolate,
        };
        template_count += 1;
    } else {
        // Previously a silent no-op. A dropped template does not fail here - it
        // fails much later, as a lookup miss that looks like a missing interface.
        log.err(
            "template registry full ({d} entries): dropping '{s}'. Raise MAX_TEMPLATES - " ++
                "capacity is per-process and every isolate registers its own entries.",
            .{ MAX_TEMPLATES, interface_name },
        );
    }
}

/// Get a registered FunctionTemplate by interface name for the current isolate
///
/// IMPORTANT: Templates are isolate-specific! This function only returns
/// templates that were registered for the current V8 isolate.
/// This is critical for multi-isolate scenarios (Workers, etc.).
pub fn getTemplate(interface_name: []const u8) ?*v8.FunctionTemplate {
    const current_isolate = v8.v8_Isolate_GetCurrent();
    return getTemplateForIsolate(interface_name, current_isolate);
}

/// Get a registered FunctionTemplate by interface name for a specific isolate
///
/// Templates are isolate-specific in V8. A Global<FunctionTemplate> created
/// in one isolate cannot be used in another isolate. This function ensures
/// we only return templates that match the specified isolate.
pub fn getTemplateForIsolate(interface_name: []const u8, isolate: ?*v8.Isolate) ?*v8.FunctionTemplate {
    ensureInitialized();

    // If no isolate provided, can't match
    if (isolate == null) return null;

    // Only iterate over registered templates, not the full array
    for (templates[0..template_count]) |entry| {
        if (entry) |e| {
            // Must match BOTH name AND isolate
            if (std.mem.eql(u8, e.name, interface_name) and e.isolate == isolate.?) {
                return e.template;
            }
        }
    }
    return null;
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
    // Reached both from inside V8 callbacks (where the isolate is current by
    // construction) and from Crane's own code creating wrappers eagerly, which is
    // the half worth checking.
    ownership.assertOwned(isolate, "template_registry.wrapInstanceAsV8Object");

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
    // SPECIAL CASE: Document instances with bound V8 wrapper
    // ========================================
    // Documents for iframes are created in the child context. When accessed
    // from the parent context (iframe.contentDocument), we need to return
    // the wrapper created in the child context to avoid callback corruption.
    if (std.mem.eql(u8, interface_name, "Document")) {
        const DocumentImpl = @import("impls").Document;
        if (DocumentImpl.getBoundV8Wrapper(instance)) |bound_wrapper| {
            // Return the bound wrapper directly
            return @ptrCast(bound_wrapper);
        }
    }

    // ========================================
    // SPECIAL CASE: DOM Nodes with bound V8 wrapper (for cross-context identity)
    // ========================================
    // When a DOM node is wrapped in one context and accessed from another
    // (e.g., MutationObserver callback sees element created in parent context),
    // we need to return the SAME wrapper to ensure JavaScript === identity works.
    if (instance_bridge.getNodeBase(@ptrCast(instance))) |nodebase| {
        if (nodebase.bound_v8_wrapper) |bound_wrapper| {
            std.log.debug("[wrapInstanceAsV8Object] RETURNING bound_v8_wrapper for {s} Instance={*} NodeBase={*} wrapper={*}", .{ interface_name, instance, nodebase, bound_wrapper });
            return @ptrCast(bound_wrapper);
        } else {
            std.log.debug("[wrapInstanceAsV8Object] NodeBase found but bound_v8_wrapper is null for {s} Instance={*} NodeBase={*}", .{ interface_name, instance, nodebase });
        }
    } else {
        std.log.debug("[wrapInstanceAsV8Object] NO NodeBase found for {s} Instance={*}", .{ interface_name, instance });
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
                // IMPORTANT: Still update the prototype chain on cached wrappers
                // This ensures instanceof works even for wrappers created before the fix
                // Create null-terminated string for C function
                var cached_name_buf: [256]u8 = undefined;
                const cached_name_z = cached_blk: {
                    if (interface_name.len >= cached_name_buf.len) break :cached_blk null;
                    @memcpy(cached_name_buf[0..interface_name.len], interface_name);
                    cached_name_buf[interface_name.len] = 0;
                    break :cached_blk @as([*:0]const u8, @ptrCast(&cached_name_buf));
                };
                const cached_global_proto = if (cached_name_z) |nz| v8.v8_GetGlobalPrototype(context, nz) else null;
                if (cached_global_proto) |prototype| {
                    _ = v8.v8_Object_SetPrototype(cached_wrapper, context, @ptrCast(prototype));
                }

                return cached_wrapper;
            }
        }
    }

    // ========================================
    // CACHE MISS: Create new wrapper
    // ========================================

    // Look up the FunctionTemplate for this interface
    // First try the template registry (for templates already registered for this isolate)
    // Then fall back to on-demand creation for interfaces not yet registered
    const template = getTemplate(interface_name) orelse blk: {
        // Template not registered for this isolate - try on-demand creation
        // This handles multi-isolate scenarios (Workers) where templates are isolate-specific
        const interface_bindings = @import("interface_bindings.zig");
        const created_template = interface_bindings.createTemplateOnDemandByName(interface_name, isolate);
        if (created_template) |t| {
            break :blk t;
        }
        // Template still not found - interface not implemented or not registered
        return error.TemplateNotRegistered;
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

    // CRITICAL: Set up the prototype chain for instanceof to work correctly!
    // ObjectTemplate::NewInstance() doesn't automatically set the prototype chain.
    // We need to manually set __proto__ to the SAME prototype that's on the global constructor.
    //
    // GetPrototypeObject calls GetFunction() which creates a NEW function with a DIFFERENT
    // prototype. For instanceof to work, we need the prototype from globalThis.InterfaceName.
    //
    // Create null-terminated string for C function
    var name_buf: [256]u8 = undefined;
    const name_z = blk: {
        if (interface_name.len >= name_buf.len) break :blk null;
        @memcpy(name_buf[0..interface_name.len], interface_name);
        name_buf[interface_name.len] = 0;
        break :blk @as([*:0]const u8, @ptrCast(&name_buf));
    };

    // Get the prototype from the global object - this is the SAME prototype that JavaScript sees
    const global_proto = if (name_z) |nz| v8.v8_GetGlobalPrototype(context, nz) else null;
    if (global_proto) |prototype| {
        _ = v8.v8_Object_SetPrototype(v8_object, context, @ptrCast(prototype));
    } else {
        // Fall back to GetPrototypeObject for interfaces not exposed on global
        if (v8.v8_FunctionTemplate_GetPrototypeObject(template, context)) |prototype| {
            _ = v8.v8_Object_SetPrototype(v8_object, context, @ptrCast(prototype));
        }
    }

    // Store the Zig instance in internal field 0
    v8.v8_Object_SetAlignedPointerInInternalField(
        v8_object,
        0,
        @ptrCast(instance),
    );

    // Store WrapperTypeInfo in internal field 1 (for type-safe unwrapping)
    if (dom_type_info.getTypeInfoByName(interface_name)) |type_info| {
        v8.v8_Object_SetAlignedPointerInInternalField(
            v8_object,
            1,
            @ptrCast(@constCast(type_info)),
        );
    }

    // For legacy platform objects, wrap in a Proxy to ensure correct
    // [[OwnPropertyKeys]] enumeration order per WebIDL §3.9.6.
    const final_object = if (isLegacyPlatformObject(interface_name)) blk: {
        const lpo_proxy = @import("legacy_platform_object_proxy.zig");
        break :blk lpo_proxy.wrapInProxy(v8_object, isolate, context);
    } else v8_object;

    // Note: v8_ObjectTemplate_NewInstance already returns a Global<Object>* handle,
    // so final_object is already persistent across HandleScopes.

    // ========================================
    // CACHE THE WRAPPER: Store for future lookups
    // ========================================
    const is_iframe = std.mem.eql(u8, interface_name, "HTMLIFrameElement");
    if (ctx_mgr.get(context)) |runtime_ctx| {
        if (runtime_ctx.getV8WrapperCacheStorage()) |cache_storage| {
            const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
            const cache: *WrapperCache = @ptrCast(@alignCast(cache_storage));

            // Cache the final object (Proxy for LPOs, target for others)
            cache.set(instance, final_object, isolate) catch |err| {
                std.log.warn("Failed to cache V8 wrapper: {s}", .{@errorName(err)});
            };
            if (is_iframe) {
                log.debug("[wrapInstanceAsV8Object] Cached iframe instance={*} in cache={*}", .{ instance, cache });
            }
        } else {
            if (is_iframe) {
                log.debug("[wrapInstanceAsV8Object] NO cache storage for iframe instance={*}", .{instance});
            }
        }
    } else {
        if (is_iframe) {
            log.debug("[wrapInstanceAsV8Object] ctx_mgr.get returned null for iframe instance={*}", .{instance});
        }
    }

    // ========================================
    // BIND THE WRAPPER: Store on NodeBase for cross-context identity
    // ========================================
    // For DOM nodes, store the wrapper directly on the NodeBase so that
    // future lookups from ANY context return the same wrapper.
    // This ensures JavaScript === identity works across contexts
    // (e.g., MutationObserver callbacks seeing elements from parent context).
    if (instance_bridge.getNodeBase(@ptrCast(instance))) |nodebase| {
        if (nodebase.bound_v8_wrapper == null) {
            nodebase.bound_v8_wrapper = @ptrCast(final_object);
            std.log.debug("[wrapInstanceAsV8Object] SET bound_v8_wrapper for {s} Instance={*} NodeBase={*} wrapper={*}", .{ interface_name, instance, nodebase, final_object });
        }
    }

    return final_object;
}

/// Get the interface name from an Instance
///
/// This looks at the instance's vtable to determine which interface it belongs to.
/// Compares vtable addresses against known vtables to identify the interface.
pub fn getInstanceInterfaceName(instance: *runtime.Instance) []const u8 {
    // Safety check: validate instance pointer before dereferencing vtable
    if (@intFromPtr(instance) < 0x1000) {
        // Invalid pointer - return generic name
        return "Object";
    }

    // The interface knows its own name; the vtable carries it (runtime.VTable.name,
    // set from Meta.name by buildVTable).
    //
    // This replaced ~400 lines of hand-maintained
    //     if (inst_vtable == &interfaces.X.vtable) return "X";
    // branches ending in `return "Element"` for anything unlisted. That chain
    // covered 139 of 1,263 interfaces, so the other 1,124 were wrapped with
    // Element's template: window.performance was `[object Element]` with no
    // now(), and so were navigator and screen. A lookup table parallel to the
    // generated interfaces could only ever drift; the name travels with the
    // vtable instead.
    return instance.vtable.name;
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
