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

/// Maximum number of interface templates that can be registered
const MAX_TEMPLATES = 2048; // Need to support all WebIDL interfaces (~1100)

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
    if (snapshot_mode) return;

    ensureInitialized();

    // Check if already registered for THIS SPECIFIC ISOLATE
    // Key is (name, isolate) pair - each isolate can have its own template for the same interface
    for (&templates) |*entry| {
        if (entry.*) |*e| {
            if (std.mem.eql(u8, e.name, interface_name) and e.isolate == isolate) {
                // Update existing entry for this isolate
                e.template = template;
                return;
            }
        }
    }

    // Add new entry for this (name, isolate) pair
    if (template_count < MAX_TEMPLATES) {
        templates[template_count] = .{
            .name = interface_name,
            .template = template,
            .isolate = isolate,
        };
        template_count += 1;
    } else {
        std.log.err("[template_registry.register] Template registry full! Cannot register '{s}' for isolate {*}", .{ interface_name, isolate });
    }
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
    ensureInitialized();

    // Get the current isolate to verify template compatibility
    const current_isolate = v8.v8_Isolate_GetCurrent();
    if (current_isolate == null) {
        std.log.warn("[getTemplate] No current isolate!", .{});
        return null;
    }

    // Only iterate over registered templates, not the full array
    for (templates[0..template_count]) |entry| {
        if (entry) |e| {
            if (std.mem.eql(u8, e.name, interface_name)) {
                // CRITICAL: Verify isolate matches!
                // Templates are isolate-specific and cannot be used across isolates.
                if (e.isolate != current_isolate) {
                    // Template is from a different isolate - don't return it
                    continue;
                }
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
                return cached_wrapper;
            }
        }
    }

    // ========================================
    // CACHE MISS: Create new wrapper
    // ========================================

    // Look up the FunctionTemplate for this interface
    const template = getTemplate(interface_name) orelse {
        // Template not registered - this shouldn't happen for core interfaces
        // but can happen for interfaces not yet implemented
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
    if (dom_type_info.getTypeInfoByName(interface_name)) |type_info| {
        v8.v8_Object_SetAlignedPointerInInternalField(
            v8_object,
            1,
            @ptrCast(@constCast(type_info)),
        );
    }

    // ========================================
    // SET PROTOTYPE: Use FunctionTemplate's prototype, NOT Constructor.prototype from global
    // ========================================
    // When loading from a V8 snapshot, Constructor.prototype from the global may not have
    // the accessor properties registered. This is because accessor properties are registered
    // on FunctionTemplate's PrototypeTemplate, but only the Constructor function itself
    // gets serialized into the snapshot.
    //
    // Solution: Use v8_FunctionTemplate_GetFunction() to get a function from the runtime
    // template, then get its .prototype property. This prototype WILL have the accessor
    // properties because it's created from the runtime template.
    const func = v8.v8_FunctionTemplate_GetFunction(template, context);
    if (func) |constructor_func| {
        const prototype_str = v8.v8_String_NewFromUtf8(isolate, "prototype", 9);
        if (prototype_str) |proto_name| {
            const prototype_value = v8.v8_Object_Get(@ptrCast(constructor_func), context, @ptrCast(proto_name));
            if (prototype_value) |proto_val| {
                if (v8.v8_Value_IsObject(proto_val)) {
                    _ = v8.v8_Object_SetPrototype(v8_object, context, proto_val);
                }
            }
        }
    }

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
