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
pub fn register(
    interface_name: []const u8,
    template: *v8.FunctionTemplate,
    isolate: *v8.Isolate,
) void {
    // In snapshot mode, don't cache templates - they're not needed for snapshot creation
    // and would cause V8 to complain about Global handles
    if (snapshot_mode) return;

    ensureInitialized();

    // Check if already registered (avoid duplicates on re-registration)
    for (&templates) |*entry| {
        if (entry.*) |*e| {
            if (std.mem.eql(u8, e.name, interface_name)) {
                // Update existing entry
                e.template = template;
                e.isolate = isolate;
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

/// Get the interface name from an Instance
///
/// This looks at the instance's vtable to determine which interface it belongs to.
/// Compares vtable addresses against known vtables to identify the interface.
pub fn getInstanceInterfaceName(instance: *runtime.Instance) []const u8 {
    // Import generated interfaces to get their vtables
    const interfaces = @import("interfaces");

    // Safety check: validate instance pointer before dereferencing vtable
    if (@intFromPtr(instance) < 0x1000) {
        // Invalid pointer - return generic name
        return "Object";
    }

    // Get the instance's vtable address
    const inst_vtable = instance.vtable;

    // Compare against known vtable addresses
    // NOTE: This compares pointer addresses, which works because vtables are comptime constants

    // Check NodeList first (most common for querySelectorAll)
    if (inst_vtable == &interfaces.NodeList.vtable) {
        return "NodeList";
    }

    // Check specific HTML element types (before generic Element check)
    // These must be checked BEFORE HTMLElement and Element since subclasses
    // have different vtables than their parents
    if (inst_vtable == &interfaces.HTMLDivElement.vtable) return "HTMLDivElement";
    if (inst_vtable == &interfaces.HTMLSpanElement.vtable) return "HTMLSpanElement";
    if (inst_vtable == &interfaces.HTMLParagraphElement.vtable) return "HTMLParagraphElement";
    if (inst_vtable == &interfaces.HTMLAnchorElement.vtable) return "HTMLAnchorElement";
    if (inst_vtable == &interfaces.HTMLImageElement.vtable) return "HTMLImageElement";
    if (inst_vtable == &interfaces.HTMLInputElement.vtable) return "HTMLInputElement";
    if (inst_vtable == &interfaces.HTMLButtonElement.vtable) return "HTMLButtonElement";
    if (inst_vtable == &interfaces.HTMLFormElement.vtable) return "HTMLFormElement";
    if (inst_vtable == &interfaces.HTMLScriptElement.vtable) return "HTMLScriptElement";
    if (inst_vtable == &interfaces.HTMLStyleElement.vtable) return "HTMLStyleElement";
    if (inst_vtable == &interfaces.HTMLLinkElement.vtable) return "HTMLLinkElement";
    if (inst_vtable == &interfaces.HTMLIFrameElement.vtable) return "HTMLIFrameElement";
    if (inst_vtable == &interfaces.HTMLHtmlElement.vtable) return "HTMLHtmlElement";
    if (inst_vtable == &interfaces.HTMLHeadElement.vtable) return "HTMLHeadElement";
    if (inst_vtable == &interfaces.HTMLBodyElement.vtable) return "HTMLBodyElement";
    if (inst_vtable == &interfaces.HTMLTitleElement.vtable) return "HTMLTitleElement";
    if (inst_vtable == &interfaces.HTMLMetaElement.vtable) return "HTMLMetaElement";
    if (inst_vtable == &interfaces.HTMLBaseElement.vtable) return "HTMLBaseElement";
    if (inst_vtable == &interfaces.HTMLHeadingElement.vtable) return "HTMLHeadingElement";
    if (inst_vtable == &interfaces.HTMLBRElement.vtable) return "HTMLBRElement";
    if (inst_vtable == &interfaces.HTMLHRElement.vtable) return "HTMLHRElement";
    if (inst_vtable == &interfaces.HTMLPreElement.vtable) return "HTMLPreElement";
    if (inst_vtable == &interfaces.HTMLQuoteElement.vtable) return "HTMLQuoteElement";
    if (inst_vtable == &interfaces.HTMLOListElement.vtable) return "HTMLOListElement";
    if (inst_vtable == &interfaces.HTMLUListElement.vtable) return "HTMLUListElement";
    if (inst_vtable == &interfaces.HTMLLIElement.vtable) return "HTMLLIElement";
    if (inst_vtable == &interfaces.HTMLDListElement.vtable) return "HTMLDListElement";
    if (inst_vtable == &interfaces.HTMLMenuElement.vtable) return "HTMLMenuElement";
    if (inst_vtable == &interfaces.HTMLTableElement.vtable) return "HTMLTableElement";
    if (inst_vtable == &interfaces.HTMLTableCaptionElement.vtable) return "HTMLTableCaptionElement";
    if (inst_vtable == &interfaces.HTMLTableColElement.vtable) return "HTMLTableColElement";
    if (inst_vtable == &interfaces.HTMLTableSectionElement.vtable) return "HTMLTableSectionElement";
    if (inst_vtable == &interfaces.HTMLTableRowElement.vtable) return "HTMLTableRowElement";
    if (inst_vtable == &interfaces.HTMLTableCellElement.vtable) return "HTMLTableCellElement";
    if (inst_vtable == &interfaces.HTMLLabelElement.vtable) return "HTMLLabelElement";
    if (inst_vtable == &interfaces.HTMLSelectElement.vtable) return "HTMLSelectElement";
    if (inst_vtable == &interfaces.HTMLDataListElement.vtable) return "HTMLDataListElement";
    if (inst_vtable == &interfaces.HTMLOptGroupElement.vtable) return "HTMLOptGroupElement";
    if (inst_vtable == &interfaces.HTMLOptionElement.vtable) return "HTMLOptionElement";
    if (inst_vtable == &interfaces.HTMLTextAreaElement.vtable) return "HTMLTextAreaElement";
    if (inst_vtable == &interfaces.HTMLOutputElement.vtable) return "HTMLOutputElement";
    if (inst_vtable == &interfaces.HTMLProgressElement.vtable) return "HTMLProgressElement";
    if (inst_vtable == &interfaces.HTMLMeterElement.vtable) return "HTMLMeterElement";
    if (inst_vtable == &interfaces.HTMLFieldSetElement.vtable) return "HTMLFieldSetElement";
    if (inst_vtable == &interfaces.HTMLLegendElement.vtable) return "HTMLLegendElement";
    if (inst_vtable == &interfaces.HTMLEmbedElement.vtable) return "HTMLEmbedElement";
    if (inst_vtable == &interfaces.HTMLObjectElement.vtable) return "HTMLObjectElement";
    if (inst_vtable == &interfaces.HTMLParamElement.vtable) return "HTMLParamElement";
    if (inst_vtable == &interfaces.HTMLVideoElement.vtable) return "HTMLVideoElement";
    if (inst_vtable == &interfaces.HTMLAudioElement.vtable) return "HTMLAudioElement";
    if (inst_vtable == &interfaces.HTMLSourceElement.vtable) return "HTMLSourceElement";
    if (inst_vtable == &interfaces.HTMLTrackElement.vtable) return "HTMLTrackElement";
    if (inst_vtable == &interfaces.HTMLCanvasElement.vtable) return "HTMLCanvasElement";
    if (inst_vtable == &interfaces.CanvasRenderingContext2D.vtable) return "CanvasRenderingContext2D";
    if (inst_vtable == &interfaces.HTMLMapElement.vtable) return "HTMLMapElement";
    if (inst_vtable == &interfaces.HTMLAreaElement.vtable) return "HTMLAreaElement";
    if (inst_vtable == &interfaces.HTMLTemplateElement.vtable) return "HTMLTemplateElement";
    if (inst_vtable == &interfaces.HTMLSlotElement.vtable) return "HTMLSlotElement";
    if (inst_vtable == &interfaces.HTMLDialogElement.vtable) return "HTMLDialogElement";
    if (inst_vtable == &interfaces.HTMLDetailsElement.vtable) return "HTMLDetailsElement";
    if (inst_vtable == &interfaces.HTMLDataElement.vtable) return "HTMLDataElement";
    if (inst_vtable == &interfaces.HTMLTimeElement.vtable) return "HTMLTimeElement";
    if (inst_vtable == &interfaces.HTMLModElement.vtable) return "HTMLModElement";
    if (inst_vtable == &interfaces.HTMLPictureElement.vtable) return "HTMLPictureElement";
    if (inst_vtable == &interfaces.HTMLMediaElement.vtable) return "HTMLMediaElement";
    if (inst_vtable == &interfaces.HTMLUnknownElement.vtable) return "HTMLUnknownElement";

    // Check Element and subclasses (generic fallbacks)
    if (inst_vtable == &interfaces.Element.vtable) {
        return "Element";
    }

    if (inst_vtable == &interfaces.HTMLElement.vtable) {
        return "HTMLElement";
    }

    // Check Document
    if (inst_vtable == &interfaces.Document.vtable) {
        return "Document";
    }

    // Check other common types
    if (inst_vtable == &interfaces.Text.vtable) {
        return "Text";
    }

    if (inst_vtable == &interfaces.Comment.vtable) {
        return "Comment";
    }

    if (inst_vtable == &interfaces.DocumentFragment.vtable) {
        return "DocumentFragment";
    }

    if (inst_vtable == &interfaces.Attr.vtable) {
        return "Attr";
    }

    if (inst_vtable == &interfaces.CharacterData.vtable) {
        return "CharacterData";
    }

    if (inst_vtable == &interfaces.ProcessingInstruction.vtable) {
        return "ProcessingInstruction";
    }

    if (inst_vtable == &interfaces.CDATASection.vtable) {
        return "CDATASection";
    }

    if (inst_vtable == &interfaces.DocumentType.vtable) {
        return "DocumentType";
    }

    if (inst_vtable == &interfaces.ShadowRoot.vtable) {
        return "ShadowRoot";
    }

    if (inst_vtable == &interfaces.Range.vtable) {
        return "Range";
    }

    if (inst_vtable == &interfaces.StaticRange.vtable) {
        return "StaticRange";
    }

    if (inst_vtable == &interfaces.TreeWalker.vtable) {
        return "TreeWalker";
    }

    if (inst_vtable == &interfaces.NodeIterator.vtable) {
        return "NodeIterator";
    }

    if (inst_vtable == &interfaces.DOMTokenList.vtable) {
        return "DOMTokenList";
    }

    if (inst_vtable == &interfaces.HTMLCollection.vtable) {
        return "HTMLCollection";
    }

    if (inst_vtable == &interfaces.NamedNodeMap.vtable) {
        return "NamedNodeMap";
    }

    if (inst_vtable == &interfaces.DOMImplementation.vtable) {
        return "DOMImplementation";
    }

    // DOM Events and AbortController/AbortSignal
    if (inst_vtable == &interfaces.AbortController.vtable) {
        return "AbortController";
    }

    if (inst_vtable == &interfaces.AbortSignal.vtable) {
        return "AbortSignal";
    }

    if (inst_vtable == &interfaces.Event.vtable) {
        return "Event";
    }

    if (inst_vtable == &interfaces.EventTarget.vtable) {
        return "EventTarget";
    }

    // Web Storage types
    if (inst_vtable == &interfaces.Storage.vtable) {
        return "Storage";
    }

    // IndexedDB types
    if (inst_vtable == &interfaces.IDBKeyRange.vtable) {
        return "IDBKeyRange";
    }

    if (inst_vtable == &interfaces.IDBFactory.vtable) {
        return "IDBFactory";
    }

    if (inst_vtable == &interfaces.IDBDatabase.vtable) {
        return "IDBDatabase";
    }

    if (inst_vtable == &interfaces.IDBObjectStore.vtable) {
        return "IDBObjectStore";
    }

    if (inst_vtable == &interfaces.IDBIndex.vtable) {
        return "IDBIndex";
    }

    if (inst_vtable == &interfaces.IDBRequest.vtable) {
        return "IDBRequest";
    }

    if (inst_vtable == &interfaces.IDBOpenDBRequest.vtable) {
        return "IDBOpenDBRequest";
    }

    if (inst_vtable == &interfaces.IDBTransaction.vtable) {
        return "IDBTransaction";
    }

    if (inst_vtable == &interfaces.IDBCursor.vtable) {
        return "IDBCursor";
    }

    if (inst_vtable == &interfaces.IDBCursorWithValue.vtable) {
        return "IDBCursorWithValue";
    }

    // Fetch types
    if (inst_vtable == &interfaces.Headers.vtable) {
        return "Headers";
    }

    if (inst_vtable == &interfaces.Request.vtable) {
        return "Request";
    }

    if (inst_vtable == &interfaces.Response.vtable) {
        return "Response";
    }

    if (inst_vtable == &interfaces.Blob.vtable) {
        return "Blob";
    }

    if (inst_vtable == &interfaces.File.vtable) {
        return "File";
    }

    if (inst_vtable == &interfaces.FormData.vtable) {
        return "FormData";
    }

    // Message passing types
    if (inst_vtable == &interfaces.MessageChannel.vtable) {
        return "MessageChannel";
    }

    if (inst_vtable == &interfaces.MessagePort.vtable) {
        return "MessagePort";
    }

    // Streams types
    if (inst_vtable == &interfaces.ReadableStream.vtable) {
        return "ReadableStream";
    }

    if (inst_vtable == &interfaces.ReadableStreamDefaultReader.vtable) {
        return "ReadableStreamDefaultReader";
    }

    if (inst_vtable == &interfaces.ReadableStreamDefaultController.vtable) {
        return "ReadableStreamDefaultController";
    }

    if (inst_vtable == &interfaces.WritableStream.vtable) {
        return "WritableStream";
    }

    if (inst_vtable == &interfaces.WritableStreamDefaultWriter.vtable) {
        return "WritableStreamDefaultWriter";
    }

    if (inst_vtable == &interfaces.WritableStreamDefaultController.vtable) {
        return "WritableStreamDefaultController";
    }

    if (inst_vtable == &interfaces.TransformStream.vtable) {
        return "TransformStream";
    }

    if (inst_vtable == &interfaces.TransformStreamDefaultController.vtable) {
        return "TransformStreamDefaultController";
    }

    // XHR types
    if (inst_vtable == &interfaces.XMLHttpRequest.vtable) {
        return "XMLHttpRequest";
    }

    if (inst_vtable == &interfaces.XMLHttpRequestUpload.vtable) {
        return "XMLHttpRequestUpload";
    }

    if (inst_vtable == &interfaces.XMLHttpRequestEventTarget.vtable) {
        return "XMLHttpRequestEventTarget";
    }

    // Progress events
    if (inst_vtable == &interfaces.ProgressEvent.vtable) {
        return "ProgressEvent";
    }

    // URL types
    if (inst_vtable == &interfaces.URL.vtable) {
        return "URL";
    }

    if (inst_vtable == &interfaces.URLSearchParams.vtable) {
        return "URLSearchParams";
    }

    // CSSOM types
    if (inst_vtable == &interfaces.CSSStyleDeclaration.vtable) {
        return "CSSStyleDeclaration";
    }

    // Geometry types (CSSOM View)
    if (inst_vtable == &interfaces.DOMRect.vtable) {
        return "DOMRect";
    }

    if (inst_vtable == &interfaces.DOMRectReadOnly.vtable) {
        return "DOMRectReadOnly";
    }

    if (inst_vtable == &interfaces.DOMRectList.vtable) {
        return "DOMRectList";
    }

    if (inst_vtable == &interfaces.DOMPoint.vtable) {
        return "DOMPoint";
    }

    if (inst_vtable == &interfaces.DOMPointReadOnly.vtable) {
        return "DOMPointReadOnly";
    }

    if (inst_vtable == &interfaces.DOMQuad.vtable) {
        return "DOMQuad";
    }

    // Window - critical for cross-realm support
    if (inst_vtable == &interfaces.Window.vtable) {
        return "Window";
    }

    // Default to "Element" for unknown types (backwards compat)
    return "Element";
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
