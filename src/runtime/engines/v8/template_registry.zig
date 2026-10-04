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

/// One isolate's templates, by interface name. The names are BORROWED: they
/// are the generated interfaces' comptime names, which outlive the registry.
const IsolateTemplates = std.StringHashMapUnmanaged(*v8.FunctionTemplate);

/// What the registry's tables are allocated with: the process's, as the
/// registry is (instances B2 moves it onto the agent record).
const table_allocator = std.heap.c_allocator;

/// The template registry: per isolate, its FunctionTemplates by interface
/// name - entries that live exactly as long as their isolate
/// (`clearForIsolate`) and grow with it.
///
/// It was one fixed array of 8,192 (interface, isolate) entries for the whole
/// process, and every isolate registers ~1,260. A file with many shared
/// workers alive at once (workers/modules/shared-worker-options-credentials.html)
/// filled it, and every later registration was DROPPED with a log line - so
/// the next file's dedicated worker found no template for a constructible
/// interface it had just registered, made a second one (createTemplateFresh),
/// and XMLHttpRequestEventTarget.prototype's [[Prototype]] was not that
/// realm's EventTarget.prototype (xhr/idlharness.any.worker.html 151/160
/// after it, 153/160 alone). A map per isolate cannot fill, and finds an
/// entry without scanning every other isolate's.
///
/// Isolates are made, read and ended on several threads (a worker's runs on
/// its own), so the table of isolates is read and written under
/// `templates_lock`, held only for a find, an insert or a removal. Each
/// isolate's map is heap-allocated - a rehash of the table never moves it -
/// and is read and written only on its isolate's thread, without the lock.
// process-wide: interface templates per live isolate, keyed by isolate, under templates_lock (instances B2 moves each isolate's map onto its agent record).
var templates: std.AutoHashMapUnmanaged(*v8.Isolate, *IsolateTemplates) = .empty;
// process-wide: guards `templates` (the table of isolates), shared by every isolate's thread.
var templates_lock: std.Io.Mutex = .init;

/// `isolate`'s map, or null.
fn setOf(isolate: *v8.Isolate) ?*IsolateTemplates {
    std.Io.Threaded.mutexLock(&templates_lock);
    defer std.Io.Threaded.mutexUnlock(&templates_lock);
    return templates.get(isolate);
}

/// `isolate`'s map, made if it has none. Null when out of memory.
fn setFor(isolate: *v8.Isolate) ?*IsolateTemplates {
    std.Io.Threaded.mutexLock(&templates_lock);
    defer std.Io.Threaded.mutexUnlock(&templates_lock);
    const slot = templates.getOrPut(table_allocator, isolate) catch return null;
    if (slot.found_existing) return slot.value_ptr.*;
    const set = table_allocator.create(IsolateTemplates) catch {
        templates.removeByPtr(slot.key_ptr);
        return null;
    };
    set.* = .empty;
    slot.value_ptr.* = set;
    return set;
}

/// Take `isolate`'s map out of the table: the caller frees it.
fn takeSet(isolate: *v8.Isolate) ?*IsolateTemplates {
    std.Io.Threaded.mutexLock(&templates_lock);
    defer std.Io.Threaded.mutexUnlock(&templates_lock);
    const kv = templates.fetchRemove(isolate) orelse return null;
    return kv.value;
}

fn destroySet(set: *IsolateTemplates, dispose: bool) void {
    if (dispose) {
        var iter = set.valueIterator();
        while (iter.next()) |template| v8.v8_FunctionTemplate_Dispose(template.*);
    }
    set.deinit(table_allocator);
    table_allocator.destroy(set);
}

/// Every isolate's map out of the table, each freed (`dispose`: its
/// templates disposed first).
fn destroyAllSets(dispose: bool) void {
    std.Io.Threaded.mutexLock(&templates_lock);
    defer std.Io.Threaded.mutexUnlock(&templates_lock);
    var sets = templates.valueIterator();
    while (sets.next()) |set| destroySet(set.*, dispose);
    templates.deinit(table_allocator);
    templates = .empty;
}

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
    if (takeSet(isolate)) |set| destroySet(set, true);
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
    destroyAllSets(true);
    // Increment generation to invalidate all per-interface static caches
    cache_generation +%= 1;
    // Clear the async iterator template cache in C++ layer
    // This cache is also isolate-specific and must be cleared
    v8.v8_ClearAsyncIteratorTemplateCache();
    // Clear module callbacks - their user_data pointers become invalid
    // when the Zig runtime is deinitialized
    v8.v8_ClearModuleResolveCallback();
    v8.v8_ClearDynamicImportCallback();

    // Clear Zig-side global state that holds V8 references: the global
    // namespace context (holds V8 context references).
    const namespace = @import("namespace.zig");
    namespace.clearGlobalContext();
}

/// clearForIsolate without disposing anything: for a test whose templates are
/// synthetic pointers.
pub fn forgetIsolateForTest(isolate: *v8.Isolate) void {
    if (takeSet(isolate)) |set| destroySet(set, false);
}

/// How many (interface, isolate) entries are currently registered.
///
/// Exposed for tests and diagnostics: the count is what distinguishes a genuine
/// re-registration (updates in place) from an append.
pub fn registeredCount() usize {
    std.Io.Threaded.mutexLock(&templates_lock);
    defer std.Io.Threaded.mutexUnlock(&templates_lock);
    var count: usize = 0;
    var sets = templates.valueIterator();
    while (sets.next()) |set| count += set.*.count();
    return count;
}

/// Remove every entry WITHOUT disposing any V8 handle.
///
/// `clear()` calls `v8_FunctionTemplate_Dispose` on each entry, which is correct
/// for real templates and fatal for a test using synthetic pointers. This exists
/// so a test can borrow the registry and put it back.
pub fn resetForTest() void {
    destroyAllSets(false);
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

    // One entry per (interface, isolate): V8 Global<FunctionTemplate> handles
    // are isolate-scoped and cannot be shared, and a second isolate
    // registering "Element" must not take the first one's entry. Registering
    // the same interface again in the same isolate replaces its entry.
    const set = setFor(isolate) orelse {
        log.err("template registry: out of memory registering '{s}'", .{interface_name});
        return;
    };
    set.put(table_allocator, interface_name, template) catch {
        log.err("template registry: out of memory registering '{s}'", .{interface_name});
    };
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
    // If no isolate provided, can't match
    const key = isolate orelse return null;
    const set = setOf(key) orelse return null;
    return set.get(interface_name);
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
/// A V8 Object wrapping the instance (cached if already wrapped, new if first time),
/// BORROWED: the wrapper cache's own handle, which it holds weakly (unless
/// something holds the wrapper strongly, see wrapper_cache.shouldBeStrong). Take
/// a reference of your own - read it into a Local, or `v8_Global_Clone` it -
/// before anything that can allocate on the V8 heap: a collection in between can
/// take a wrapper nothing else reaches, and its first pass empties this handle.
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

            // Cache hit: the one wrapper this instance has in this realm,
            // returned as it is.
            //
            // Nothing else may happen to it here. Its prototype was fixed when
            // it was made - the interface's prototype on the fresh-wrap path
            // below, NewTarget's for an object a constructor made (WebIDL
            // "internally create a new object implementing the interface",
            // GetPrototypeFromConstructor) - and resetting it to
            // `globalThis[interface_name].prototype` on every hand-back turned
            // an instance of `class MyEvent extends Event` into a plain Event
            // the first time it reached a listener
            // (crane/c5-subclass-wrapper-keeps-prototype.html).
            //
            // And the cache holds this wrapper WEAKLY: only script keeps it,
            // and between two hand-backs script may not. Anything that
            // allocates on the V8 heap before the caller takes its own
            // reference can run a collection that takes the wrapper - its
            // first-pass callback empties this very handle. The reset did:
            // v8_GetGlobalPrototype makes a string (and may materialize the
            // interface object) before SetPrototype read the handle, which
            // was then empty - "member call on null pointer of type
            // 'v8::Object'" in v8_Object_SetPrototype, for a MessageEvent
            // handed to a listener after it had been wrapped once, in
            // workers/semantics/structured-clone/dedicated.html: 7 runs in 48
            // after the eleven worker files that precede it in a sweep shard,
            // each one an emptied handle right after the lookup.
            if (cache.get(instance)) |cached_wrapper| return cached_wrapper;
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
    // Owned handle. This is the per-element wrapper path, so leaking it here is
    // one leaked handle for every DOM object the page creates.
    defer v8.v8_ObjectTemplate_Dispose(instance_template);
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
    // Both prototype getters allocate a fresh Global<Object> - V8's own APIs return
    // a borrowed Local - and this runs once per wrapped DOM object, so leaking them
    // leaks per element. `SetPrototype` converts Global to Local and stores nothing
    // (v8_wrapper.cpp:5984-5988), so releasing straight after is correct.
    const global_proto = if (name_z) |nz| v8.v8_GetGlobalPrototype(context, nz) else null;
    defer if (global_proto) |p| v8.v8_Object_Dispose(p);

    if (global_proto) |prototype| {
        _ = v8.v8_Object_SetPrototype(v8_object, context, @ptrCast(prototype));
    } else {
        // Fall back to GetPrototypeObject for interfaces not exposed on global
        if (v8.v8_FunctionTemplate_GetPrototypeObject(template, context)) |prototype| {
            defer v8.v8_Object_Dispose(prototype);
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
        const proxy = lpo_proxy.wrapInProxy(v8_object, isolate, context);
        // The proxy holds its target, and nothing below uses the target's own
        // handle - kept, it was one leaked Global per legacy platform object
        // (every HTMLCollection, NodeList, ...), each pinning its page.
        if (proxy != v8_object) v8.v8_Object_Dispose(v8_object);
        break :blk proxy;
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
///
/// WebIDL 3.9: a legacy platform object is one that supports indexed or named
/// properties - an interface with an indexed or named property getter, its
/// own or inherited. Nothing else belongs here: HTMLTableSectionElement
/// ("has rows collection" - but `rows` is an attribute), Selection and
/// MimeType have neither, and wrapping them only cost them the proxy's
/// semantics (HTMLTableRowsCollection and HTMLTableCellsCollection are not
/// interfaces at all).
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
    // File API
    "FileList",
    // Storage
    "Storage",
    // Plugin-related (legacy)
    "Plugin",
    "PluginArray",
    "MimeTypeArray",
    // Touch events
    "TouchList",
    // Data transfer
    "DataTransferItemList",
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

    // Verify initial state
    const template = getTemplate("NonExistent");
    try std.testing.expectEqual(@as(?*v8.FunctionTemplate, null), template);
}
