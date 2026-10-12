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
const interfaces = @import("interfaces");
const specialBinding = @import("interface.zig").specialBinding;

const log = std.log.scoped(.template_registry);

/// Each isolate's registry is its own: the `registered` map of its template
/// storage (isolate_templates.zig, the isolate's data slot 1), entries that
/// live exactly as long as their isolate and grow with it.
///
/// It was one fixed array of 8,192 (interface, isolate) entries for the whole
/// process, and every isolate registers ~1,260. A file with many shared
/// workers alive at once (workers/modules/shared-worker-options-credentials.html)
/// filled it, and every later registration was DROPPED with a log line - so
/// the next file's dedicated worker found no template for a constructible
/// interface it had just registered, made a second one (createTemplateFresh),
/// and XMLHttpRequestEventTarget.prototype's [[Prototype]] was not that
/// realm's EventTarget.prototype (xhr/idlharness.any.worker.html 151/160
/// after it, 153/160 alone). Then it was a process-wide map of per-isolate
/// maps under a mutex, taken on every wrap of every agent's thread. An
/// isolate's own map cannot fill, needs no lock - an isolate is used on one
/// thread at a time - and nothing of another isolate reaches it (instances
/// B2).
const isolate_templates = @import("isolate_templates.zig");

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

/// Dispose and remove `isolate`'s templates, before it is disposed, on its
/// thread: its template storage ends (isolate_templates.cleanupTemplateStorage).
/// No other isolate's entry is touched.
pub fn clearForIsolate(isolate: *v8.Isolate) void {
    isolate_templates.cleanupTemplateStorage(isolate, std.heap.c_allocator);
}

/// clearForIsolate without disposing anything: for a test whose templates are
/// synthetic pointers.
pub fn forgetIsolateForTest(isolate: *v8.Isolate) void {
    isolate_templates.forgetTemplateStorage(isolate);
}

/// How many interfaces `isolate` has registered.
///
/// Exposed for tests and diagnostics: the count is what distinguishes a genuine
/// re-registration (updates in place) from an append.
pub fn registeredCount(isolate: *v8.Isolate) usize {
    const storage = isolate_templates.getTemplateStorage(isolate) orelse return 0;
    return storage.registered.count();
}

/// Register a FunctionTemplate for an interface
///
/// Called by V8Interface.registerGlobal after creating the template.
/// This allows later wrapping of instances via wrapInstanceAsV8Object.
///
/// **Snapshot Mode**: When `snapshot_mode` is true, templates ARE still registered
/// for deduplication purposes (ensuring parent templates are reused). The Global
/// handles will be cleared by v8_Snapshot_ClearGlobalHandles() before CreateBlob().
pub fn register(
    interface_name: []const u8,
    template: *v8.FunctionTemplate,
    isolate: *v8.Isolate,
) void {
    // NOTE: We register even in snapshot_mode for deduplication of parent templates.
    // The handles will be cleared by v8_Snapshot_ClearGlobalHandles() before CreateBlob().

    // One entry per (interface, isolate): V8 Global<FunctionTemplate> handles
    // are isolate-scoped and cannot be shared, and each isolate's entries are
    // in its own storage. Registering the same interface again in the same
    // isolate replaces its entry.
    const storage = isolate_templates.storageFor(isolate) orelse {
        log.err("template registry: out of memory registering '{s}'", .{interface_name});
        return;
    };
    storage.registered.put(storage.allocator, interface_name, template) catch {
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
    const storage = isolate_templates.getTemplateStorage(key) orelse return null;
    return storage.registered.get(interface_name);
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
    // The length first (conversions.instanceToV8Checked says why).
    if (interface_name.len == "Window".len and std.mem.eql(u8, interface_name, "Window")) {
        const WindowImpl = @import("impls").Window;
        if (WindowImpl.getBoundV8Global(instance)) |bound_global| {
            // Return the bound global directly - this is the key for cross-realm!
            // bound_global is a Global<Object>* which is the correct type for return values
            return @ptrCast(bound_global);
        }
    }

    // (A Document is a node: its one wrapper is the node's bound wrapper,
    // below. Its impl's own bound-wrapper slot was never set.)

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
        const proxy = lpo_proxy.wrapInProxy(v8_object, isolate, context, hasNamedPropertySetter(interface_name));
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

            // Cache the final object (Proxy for LPOs, target for others). The
            // cache owns the instance through it from here - and the
            // wrapper's counted reference (refcount step 4) is taken only
            // once the insert succeeded (WrapperCache.set). A failed insert
            // is this wrap's failure: handing the wrapper back anyway left
            // the instance owned by nothing, and the caller's error path
            // never ran (Codex row 15 Q22: an OOM trial leaked a stream graph
            // and an AbortController). The wrapper made here goes, its
            // fields cleared first so nothing can reach the instance
            // through it.
            cache.set(instance, final_object, isolate) catch |err| {
                if (err == error.AlreadyWrapped) {
                    // Wrapped while this one was being made: that wrapper is
                    // the instance's one wrapper.
                    if (cache.existingWrapper(instance)) |existing| {
                        discardUncachedWrapper(final_object);
                        return existing;
                    }
                }
                log.warn("the wrapper of a {s} was not cached: {s}", .{ interface_name, @errorName(err) });
                discardUncachedWrapper(final_object);
                return err;
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

/// A wrapper `wrapInstanceAsV8Object` made but could not cache: its internal
/// fields cleared (a proxy's on its target), so script that already reached
/// it - nothing has yet - finds no instance through it, and its handle
/// released.
fn discardUncachedWrapper(wrapper: *v8.Object) void {
    var object: *v8.Object = wrapper;
    var target: ?*v8.Value = null;
    if (v8.v8_Value_IsProxy(@ptrCast(wrapper))) {
        target = v8.v8_Proxy_GetTarget(wrapper);
        if (target) |t| object = @ptrCast(t);
    }
    defer if (target) |t| v8.v8_Value_Dispose(t);
    const count = v8.v8_Object_InternalFieldCount(object);
    if (count >= 1) v8.v8_Object_SetAlignedPointerInInternalField(object, 0, null);
    if (count >= 2) v8.v8_Object_SetAlignedPointerInInternalField(object, 1, null);
    v8.v8_Object_Dispose(wrapper);
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

/// The legacy platform objects that support NAMED properties - an interface
/// whose binding has a named property getter, its own or inherited (WebIDL
/// 3.9), or Crane's own: CSSStyleDeclaration's camelCase CSS properties
/// (call_namedItem / call_setNamedItem). Their
/// wrapper is a Proxy, so that [[OwnPropertyKeys]] answers in WebIDL's order
/// (3.9.6: supported indices, then supported names, then own string keys,
/// then symbols): V8 lists a named interceptor's names AFTER the object's
/// own string keys (KeyAccumulator::CollectOwnPropertyNames, 13.1 keys.cc).
///
/// A legacy platform object with an indexed getter and no named one - NodeList
/// and RadioNodeList, DOMTokenList, DOMStringList, DOMRectList,
/// StyleSheetList, CSSRuleList, MediaList, FileList, TouchList,
/// DataTransferItemList - is NOT wrapped (tests/v8/indexed_property_semantics_
/// test.zig checks that none of them has a named getter). V8's own order is already
/// WebIDL's for it: an object's elements, then its indexed interceptor's
/// indices, then its own string keys, then symbols - and it can have no own
/// elements, since its indexed definer rejects every array index (3.9.3
/// [[DefineOwnProperty]] step 1, no indexed setter). Unwrapped, V8 reaches its
/// indexed interceptor from the inline cache (LoadIndexedInterceptorIC) where
/// a proxy went through the runtime on every `list[i]`
/// (Runtime_GetPropertyWithReceiver, JSProxy::GetProperty) and every `i in
/// list` called the proxy's `has` trap, which looked up and called
/// Reflect.has: 55% of an Array.prototype.indexOf over a NodeList (gc_bench
/// profile, 2026-10-11; NodeList-static-length-getter-tampered-indexOf-*.html
/// do ~2.5e8 of them). And its [[Set]] and [[DefineOwnProperty]] are then
/// V8's with the interceptors, as WebIDL says: a sloppy-mode `list[0] = x`
/// fails quietly and Object.defineProperty(list, "0", ...) throws a
/// TypeError, where the proxy's set trap threw in sloppy mode too and its
/// defineProperty trap (Reflect.defineProperty) answered success
/// (webidl/ecmascript-binding/legacy-platform-object/DefineOwnProperty.html).
///
/// HTMLTableSectionElement ("has rows collection" - but `rows` is an
/// attribute), Selection and MimeType have neither kind of getter, and
/// wrapping them only cost them the proxy's semantics.
const legacy_platform_objects = .{
    interfaces.HTMLCollection,
    interfaces.HTMLFormControlsCollection,
    interfaces.HTMLOptionsCollection,
    interfaces.NamedNodeMap,
    interfaces.Storage,
    interfaces.Plugin,
    interfaces.PluginArray,
    interfaces.MimeTypeArray,
    // Named properties of Crane's binding, not of the IDL. Unwrapped, V8 runs
    // its named setter interceptor before a prototype accessor, so
    // `style.cssText = ...` set an unknown property "css-text" instead
    // (content-security-policy/style-src/style-src-inline-style-with-csstext
    // .html); the proxy's set trap finds the accessor first.
    interfaces.CSSStyleDeclaration,
    // NOTE: Window is NOT included here because it's the global object
    // and wrapping it in a Proxy breaks method invocation semantics.
    // Window's OwnPropertyKeys order needs special handling in V8 C++.
};

/// Whether an interface's wrapper is a Proxy: a legacy platform object with
/// named properties (see legacy_platform_objects).
pub fn isLegacyPlatformObject(interface_name: []const u8) bool {
    inline for (legacy_platform_objects) |Interface| {
        if (std.mem.eql(u8, interface_name, Interface.Meta.name)) return true;
    }
    return false;
}

/// Whether a proxied legacy platform object's interface has a named property
/// setter (WebIDL 3.9.2 [[Set]] step 1.2: then every String P assigned on
/// the object itself goes to it) - from its Meta.special_operations, as the
/// binding installs it, never from its name. Not CSSStyleDeclaration's:
/// those stand in for attributes, reached through the prototype chain
/// (crane_css_properties).
pub fn hasNamedPropertySetter(interface_name: []const u8) bool {
    inline for (legacy_platform_objects) |Interface| {
        if (std.mem.eql(u8, interface_name, Interface.Meta.name)) {
            const binding = comptime specialBinding(Interface);
            return comptime binding.named_setter != null and !binding.crane_css_properties;
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
