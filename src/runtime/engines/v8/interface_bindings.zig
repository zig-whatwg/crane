//! V8 Interface Bindings Registry
//!
//! This module provides centralized registration for all WebIDL interfaces.
//! It is the **single source of truth** for interface registration and the
//! centralized skip list for problematic interfaces.
//!
//! Entry points (WPT runner, REPL) should use `initializeBindings` to set up
//! all interface bindings, then call their own namespace registration.
//!
//! ## Usage
//!
//! ```zig
//! const interface_bindings = @import("v8/interface_bindings.zig");
//!
//! // Initialize interface bindings (interfaces + inheritance)
//! interface_bindings.initializeBindings(isolate, context);
//!
//! // Then register namespaces (entry point specific)
//! // registerNamespaces(isolate, context);
//!
//! // Now JavaScript can use:
//! // const target = new EventTarget();
//! // const event = new Event('click');
//! // target.addEventListener('click', handler);
//! ```

const std = @import("std");
const v8 = @import("ffi.zig");
const V8Interface = @import("interface.zig").V8Interface;
pub const V8Namespace = @import("namespace.zig").V8Namespace;
const webidl = @import("webidl");
const helpers = webidl.helpers;

// Import generated interfaces
const interfaces = @import("interfaces");
const interface_catalog = @import("interface_catalog.zig");

// ============================================================================
// Centralized Skip List
// ============================================================================

/// Interfaces to skip during registration due to codegen issues.
/// This is the SINGLE SOURCE OF TRUTH for problematic interfaces.
/// All entry points (WPT runner, REPL) use this list.
pub const interface_skip_list = .{
    "CSSMarginRule", // References undefined CSSMarginDescriptors
    "ViewCSS", // References undefined AbstractView
    "AbstractView", // Missing implementation
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

/// Check if an interface name should be skipped
pub fn shouldSkipInterface(comptime name: []const u8) bool {
    // Using a simple array lookup since this is called at comptime
    // and the skip list is small
    return comptime blk: {
        for (interface_skip_list) |skip| {
            if (std.mem.eql(u8, name, skip)) break :blk true;
        }
        break :blk false;
    };
}

// ============================================================================
// Interface Bindings (Comptime Generated)
// ============================================================================

/// EventTarget V8 binding
pub const EventTarget = V8Interface(interfaces.EventTarget);

/// Event V8 binding
pub const Event = V8Interface(interfaces.Event);

/// Node V8 binding
pub const Node = V8Interface(interfaces.Node);

/// Element V8 binding
pub const Element = V8Interface(interfaces.Element);

/// Document V8 binding
pub const Document = V8Interface(interfaces.Document);

/// Window V8 binding
pub const Window = V8Interface(interfaces.Window);

// Note: Individual bindings above are kept for backward compatibility.
// New code should use initializeBindings() which registers ALL interfaces.

// ============================================================================
// Registration
// ============================================================================

/// Register all core DOM interfaces in the global scope
///
/// This function registers the most commonly used DOM interfaces:
/// - EventTarget
/// - Event
/// - Node
/// - Element
/// - Document
/// - Window
///
/// **DEPRECATED**: Use initializeBindings() instead for full interface registration.
///
/// Example JavaScript usage after initialization:
/// ```javascript
/// const target = new EventTarget();
/// const event = new Event('test');
/// target.dispatchEvent(event);
/// ```
pub fn registerCoreDOMInterfaces(
    isolate: *v8.Isolate,
    context: *v8.Context,
) void {
    // EventTarget is the base for all event-handling interfaces
    EventTarget.registerGlobal(isolate, context, "EventTarget");

    // Event is the base event object
    Event.registerGlobal(isolate, context, "Event");

    // Node is the base for all DOM nodes
    Node.registerGlobal(isolate, context, "Node");

    // Element represents HTML/XML elements
    Element.registerGlobal(isolate, context, "Element");

    // Document represents the document tree
    Document.registerGlobal(isolate, context, "Document");

    // Window is the global object in browsers
    Window.registerGlobal(isolate, context, "Window");

    // Set up constructor inheritance chain
    // In browsers, child constructors have their __proto__ set to parent constructors
    // Example: Element.__proto__ === Node, Node.__proto__ === EventTarget
    setupConstructorInheritance(isolate, context);
}

/// Register ALL WebIDL interfaces as global constructors
///
/// This registers all generated interfaces (except those in the skip list)
/// as constructors on the global object. Interfaces with [LegacyNamespace]
/// are skipped here and attached to their namespace in registerAllNamespaces().
///
/// This is the **single source of truth** for interface registration.
///
/// OPTIMIZATION: This function caches the global object and uses registerGlobalFast()
/// which skips the (always-failing) attempts to delete arguments/caller properties.
/// This reduces FFI calls from ~9 per interface to ~5 per interface.
pub fn registerAllInterfaces(
    isolate: *v8.Isolate,
    context: *v8.Context,
) void {
    @setEvalBranchQuota(200_000);
    const iface_decls = @typeInfo(interfaces).@"struct".decls;

    // OPTIMIZATION: Cache global object - don't fetch it 1231 times
    const global = v8.v8_Context_Global(context) orelse return;

    inline for (iface_decls) |decl| {
        // Skip problematic interfaces using centralized skip list
        if (comptime shouldSkipInterface(decl.name)) continue;

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
            // These interfaces get attached to their namespace in registerAllNamespaces()
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
            if (has_legacy_namespace) continue;

            // Register the interface as a global constructor using fast path
            const Binding = V8Interface(InterfaceType);
            Binding.registerGlobalFast(isolate, context, global, decl.name);
        }
    }
}

/// Register ALL WebIDL interface templates AND reinstall constructors on global
///
/// This is used when loading from a V8 snapshot. The snapshot contains
/// interface constructors on the global object, but their callback pointers
/// are STALE (point to addresses from snapshot creation time, not runtime).
///
/// This function:
/// - Creates fresh templates with working callbacks
/// - Registers them in template_registry for wrapInstanceAsV8Object()
/// - REINSTALLS constructors on the global object to replace stale snapshot versions
///
/// The reinstallation is critical: without it, calling `new Worker()` from JS
/// would invoke a stale callback pointer, never reaching our Zig code.
pub fn registerAllTemplatesOnly(
    isolate: *v8.Isolate,
    context: *v8.Context,
) void {
    @setEvalBranchQuota(200_000);
    const template_registry = @import("template_registry.zig");
    const iface_decls = @typeInfo(interfaces).@"struct".decls;

    // Get global object for reinstalling constructors
    const global = v8.v8_Context_Global(context) orelse return;

    inline for (iface_decls) |decl| {
        // Skip problematic interfaces using centralized skip list
        if (comptime shouldSkipInterface(decl.name)) continue;

        const InterfaceType = @field(interfaces, decl.name);

        // Only bind types that have Meta (actual interfaces)
        if (@typeInfo(InterfaceType) == .@"struct" and @hasDecl(InterfaceType, "Meta")) {
            // Skip mixin interfaces - they don't need templates
            const is_mixin = comptime blk: {
                const Meta = InterfaceType.Meta;
                if (@hasDecl(Meta, "is_mixin")) {
                    break :blk Meta.is_mixin;
                }
                break :blk false;
            };
            if (is_mixin) continue;

            // Skip LegacyNamespace interfaces (they're namespaced, not on global)
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
            if (has_legacy_namespace) continue;

            // Create template with fresh callbacks and register it
            const Binding = V8Interface(InterfaceType);
            const template = Binding.createTemplate(isolate);
            template_registry.register(decl.name, template, isolate);

            // NOTE: Previously skipped URL reinstallation for LegacyWindowAlias (webkitURL === URL).
            // However, this caused callbacks to not work after snapshot restore.
            // Now reinstall URL like other interfaces.
            // webkitURL alias is handled separately in registerLegacyInterfaceAliases().

            // CRITICAL: Reinstall constructor on global to replace stale snapshot version
            // This ensures `new Worker()` etc. invoke our Zig callbacks, not stale pointers
            Binding.registerGlobalFast(isolate, context, global, decl.name);
        }
    }
}

/// Install interfaces filtered by scope exposure
///
/// This function registers only the interfaces that are exposed in the given
/// GlobalScopeKind. Uses the [Exposed] WebIDL extended attribute to determine
/// which interfaces should be available in each scope.
///
/// For example:
/// - Window scope: Document, HTMLElement, etc.
/// - Worker scope: WorkerGlobalScope, MessagePort, etc.
/// - ServiceWorker scope: ServiceWorkerGlobalScope, Cache, etc.
///
/// This is the exposure-driven interface installation from BSCOPE-03.
pub fn installForScope(
    isolate: *v8.Isolate,
    context: *v8.Context,
    comptime scope: helpers.GlobalScope,
) void {
    @setEvalBranchQuota(200_000);
    const iface_decls = @typeInfo(interfaces).@"struct".decls;
    const global = v8.v8_Context_Global(context) orelse return;

    inline for (iface_decls) |decl| {
        if (comptime shouldSkipInterface(decl.name)) continue;

        const InterfaceType = @field(interfaces, decl.name);

        if (@typeInfo(InterfaceType) == .@"struct" and @hasDecl(InterfaceType, "Meta")) {
            const is_mixin = comptime blk: {
                const Meta = InterfaceType.Meta;
                if (@hasDecl(Meta, "is_mixin")) {
                    break :blk Meta.is_mixin;
                }
                break :blk false;
            };
            if (is_mixin) continue;

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
            if (has_legacy_namespace) continue;

            if (comptime helpers.isExposedIn(InterfaceType, scope)) {
                const Binding = V8Interface(InterfaceType);
                Binding.registerGlobalFast(isolate, context, global, decl.name);
            }
        }
    }
}

/// Initialize ALL V8 interface bindings
///
/// This is the **main entry point** for V8 interface binding setup.
/// Entry points (WPT runner, REPL) should call this, then register
/// namespaces separately using registerNamespacesGeneric.
///
/// Steps performed:
/// 1. Register all interfaces as global constructors (except mixins and LegacyNamespace)
/// 2. Set up constructor inheritance chain (Element.__proto__ = Node, etc.)
///
/// Example:
/// ```zig
/// // In WPT runner, REPL, or any V8 entry point:
/// interface_bindings.initializeBindings(isolate, context);
/// // Then register namespaces:
/// interface_bindings.registerNamespacesGeneric(namespaces, isolate, context);
/// ```
pub fn initializeBindings(
    isolate: *v8.Isolate,
    context: *v8.Context,
) void {
    // Step 1: Register all interfaces
    registerAllInterfaces(isolate, context);

    // Step 2: Set up constructor inheritance chain
    setupConstructorInheritance(isolate, context);

    // Step 3: Register legacy factory functions
    // These are separate constructors that create instances of other interfaces
    // e.g., Image creates HTMLImageElement, Audio creates HTMLAudioElement
    registerLegacyFactoryFunctions(isolate, context);

    // Step 4: Register Intl namespace (pure Zig i18n - replaces ICU)
    const intl_binding = @import("intl_binding.zig");
    intl_binding.registerGlobal(isolate, context);

    // Step 5: Register toLocaleString methods on built-in prototypes
    intl_binding.registerToLocaleStringMethods(isolate, context);

    // Step 6: Register legacy interface aliases
    // These are historical aliases that map to other interfaces
    // e.g., HTMLDocument is an alias for Document per HTML spec
    registerLegacyInterfaceAliases(isolate, context);

    // Step 7: SKIP namespace registration during snapshot creation!
    //
    // Namespaces (console, CSS, WebAssembly, etc.) contain function callbacks
    // with memory addresses specific to the snapshot creator binary.
    // These callbacks cannot be invoked at runtime because they point to
    // different addresses in the runtime binary.
    //
    // Instead, namespaces are registered at runtime via registerNamespacesGeneric()
    // in browser/Context.zig, which uses the runtime binary's callback addresses.
    //
    // NOTE: We still need to register namespace external references so V8 knows
    // about them during snapshot creation for interface method callbacks that
    // might reference namespace types.

    // Step 8: WindowProperties insertion is deferred.
    // WindowProperties must be inserted AFTER the Window instance is created and bound
    // to the global's internal field. This is done in context_manager.zig after Window.init().
    // See createChildContext() for the call to window_properties.insertIntoPrototypeChain().

    // NOTE: Window properties as own properties on the global are registered
    // in createChildContext AFTER the Window instance is bound to the global.
    // This is necessary because the property getter/setter callbacks require
    // a valid Window instance in internal field 0 of the global object.
    // For the main context, property access works through the prototype chain.
}

/// Initialize bindings for a context created with GlobalTemplateRegistry
///
/// This is the FAST path for context initialization. When using GlobalTemplateRegistry,
/// FunctionTemplates are pre-created and cached at isolate level, so registerAllInterfaces()
/// is fast because it retrieves templates from cache instead of creating them.
///
/// NOTE: We still call registerAllInterfaces() because interfaces need to be attached
/// to the global object. The optimization is that template CREATION is cached, not
/// that registration is skipped.
///
/// Use this instead of initializeBindings() when the context was created from
/// a GlobalTemplateRegistry's global template.
///
/// Performance: ~5ms vs ~40ms for cold start (templates cached after first context)
pub fn initializeBindingsWithGlobalTemplate(
    isolate: *v8.Isolate,
    context: *v8.Context,
) void {
    // Step 1: Register all interfaces - this is FAST because templates are cached
    // GlobalTemplateRegistry.precreateAllTemplates() already created all FunctionTemplates
    // and cached them at isolate level, so this just retrieves them and attaches to global
    registerAllInterfaces(isolate, context);

    // Step 2: Set up constructor inheritance chain
    // This sets Element.__proto__ = Node, etc. on the constructor functions
    setupConstructorInheritance(isolate, context);

    // Step 3: Register legacy factory functions
    // These are separate constructors that create instances of other interfaces
    // e.g., Image creates HTMLImageElement, Audio creates HTMLAudioElement
    registerLegacyFactoryFunctions(isolate, context);

    // Step 4: Register Intl namespace (pure Zig i18n - replaces ICU)
    const intl_binding = @import("intl_binding.zig");
    intl_binding.registerGlobal(isolate, context);

    // Step 5: Register toLocaleString methods on built-in prototypes
    intl_binding.registerToLocaleStringMethods(isolate, context);

    // Step 6: Register legacy interface aliases
    // These are historical aliases that map to other interfaces
    // e.g., HTMLDocument is an alias for Document per HTML spec
    registerLegacyInterfaceAliases(isolate, context);

    // Step 7: SKIP namespace registration - done at runtime via registerNamespacesGeneric()
    // (See comment in initializeBindings for explanation)

    // Step 8: WindowProperties insertion is deferred (same as initializeBindings)
}

/// Initialize bindings for a specific scope context (used by snapshot generator)
///
/// This is the SCOPE-FILTERED path for context initialization. Only interfaces
/// that are exposed to the given scope are registered on the global object.
///
/// This enables proper scope isolation:
/// - Window context gets Document, Window-specific APIs
/// - DedicatedWorker context gets WorkerGlobalScope, but NOT Document
/// - ServiceWorker context gets ServiceWorkerGlobalScope, clients, etc.
/// - AudioWorklet context gets AudioWorkletGlobalScope, but NOT DOM APIs
///
/// Per WebIDL spec, the [Exposed] extended attribute controls which global
/// scopes an interface is available in.
pub fn initializeBindingsForScope(
    isolate: *v8.Isolate,
    context: *v8.Context,
    comptime scope: helpers.GlobalScope,
) void {
    // Step 1: Register only interfaces exposed to this scope
    installForScope(isolate, context, scope);

    // Step 2: Set up constructor inheritance chain
    // This sets Element.__proto__ = Node, etc. on the constructor functions
    setupConstructorInheritance(isolate, context);

    // Step 3: Register legacy factory functions
    // These are separate constructors that create instances of other interfaces
    // e.g., Image creates HTMLImageElement, Audio creates HTMLAudioElement
    registerLegacyFactoryFunctions(isolate, context);

    // Step 4: Register Intl namespace (pure Zig i18n - replaces ICU)
    const intl_binding = @import("intl_binding.zig");
    intl_binding.registerGlobal(isolate, context);

    // Step 5: Register toLocaleString methods on built-in prototypes
    intl_binding.registerToLocaleStringMethods(isolate, context);

    // Step 6: Register legacy interface aliases
    // These are historical aliases that map to other interfaces
    // e.g., HTMLDocument is an alias for Document per HTML spec
    registerLegacyInterfaceAliases(isolate, context);

    // Step 7: SKIP namespace registration - done at runtime via registerNamespacesGeneric()
    // (See comment in initializeBindings for explanation)

    // Step 8: WindowProperties insertion is deferred (same as initializeBindings)
}

/// Initialize only core DOM interface bindings for a scope.
///
/// This is the Chromium-style minimal snapshot architecture where only core
/// interfaces are included in the V8 snapshot, with scope-specific variations:
///
/// **Window/Worker/Worklet scopes:**
/// - EventTarget (base for all event dispatchers)
/// - Node (base for DOM tree)
/// - Element (base for elements)
/// - Document (the document)
/// - Window (the global object)
///
/// **ShadowRealm scope** (TC39 Stage 3 proposal, WHATWG ShadowRealmGlobalScope):
/// Per https://tc39.es/proposal-shadowrealm/ and WHATWG HTML spec, ShadowRealm
/// only has access to computational/non-DOM interfaces:
/// - EventTarget (base for AbortSignal)
/// - DOMException (error handling)
/// - URL, URLSearchParams (URL manipulation)
/// - TextEncoder, TextDecoder (encoding/decoding)
/// - AbortController, AbortSignal (abort handling)
///
/// All other interfaces are created on-demand when first accessed via
/// `createTemplateOnDemand()`.
pub fn initializeCoreBindingsForScope(
    isolate: *v8.Isolate,
    context: *v8.Context,
    comptime scope: helpers.GlobalScope,
) void {
    // Get the global object from context
    const global = v8.v8_Context_Global(context) orelse {
        std.debug.print("[CORE-BINDINGS] Failed to get global object from context\n", .{});
        return;
    };

    if (scope == .ShadowRealm) {
        // ShadowRealm gets computational interfaces only (no DOM)
        // Per TC39 ShadowRealm proposal and WHATWG ShadowRealmGlobalScope spec
        initializeShadowRealmBindings(isolate, context, global);
    } else {
        // Standard scopes get core DOM interfaces
        // These form the essential prototype chain that must exist in the snapshot
        EventTarget.registerGlobalFast(isolate, context, global, "EventTarget");
        Node.registerGlobalFast(isolate, context, global, "Node");
        Element.registerGlobalFast(isolate, context, global, "Element");
        Document.registerGlobalFast(isolate, context, global, "Document");
        Window.registerGlobalFast(isolate, context, global, "Window");

        // URL must be registered eagerly (not lazy) so webkitURL === URL works
        // Per WebIDL [LegacyWindowAlias=webkitURL] - both must reference same object
        const URL = V8Interface(interfaces.URL);
        URL.registerGlobalFast(isolate, context, global, "URL");

        // NOTE: Constructor inheritance is already set up through V8Interface.createTemplate()
        // which calls v8_FunctionTemplate_Inherit() to establish the prototype chain at the
        // FunctionTemplate level. No additional setup needed here.

        // Register HTMLDocument as alias for Document (legacy compatibility)
        // Also registers webkitURL = URL
        registerLegacyInterfaceAliases(isolate, context);
    }
}

/// Initialize ShadowRealm-specific interface bindings.
///
/// Per TC39 ShadowRealm proposal (Stage 3) and WHATWG HTML ShadowRealmGlobalScope spec,
/// ShadowRealm provides an isolated JavaScript execution environment with limited
/// web platform APIs. Only computational (non-DOM) interfaces are exposed:
///
/// - EventTarget: Base interface for event dispatching (used by AbortSignal)
/// - DOMException: Standard exception type for web platform errors
/// - URL, URLSearchParams: URL parsing and manipulation
/// - TextEncoder, TextDecoder: String/binary encoding conversion
/// - AbortController, AbortSignal: Cooperative cancellation
///
/// DOM interfaces (Node, Element, Document, Window) are intentionally NOT exposed
/// to ShadowRealm for security and isolation reasons.
///
/// References:
/// - TC39 ShadowRealm: https://tc39.es/proposal-shadowrealm/
/// - WHATWG ShadowRealmGlobalScope: https://html.spec.whatwg.org/multipage/webappapis.html#shadowrealmglobalscope
fn initializeShadowRealmBindings(
    isolate: *v8.Isolate,
    context: *v8.Context,
    global: *v8.Object,
) void {
    // EventTarget - base for event-dispatching interfaces (required by AbortSignal)
    EventTarget.registerGlobalFast(isolate, context, global, "EventTarget");

    // DOMException - standard web platform exception type
    const DOMException = V8Interface(interfaces.DOMException);
    DOMException.registerGlobalFast(isolate, context, global, "DOMException");

    // URL APIs - URL parsing and manipulation
    const URL = V8Interface(interfaces.URL);
    URL.registerGlobalFast(isolate, context, global, "URL");

    const URLSearchParams = V8Interface(interfaces.URLSearchParams);
    URLSearchParams.registerGlobalFast(isolate, context, global, "URLSearchParams");

    // Encoding APIs - text encoding/decoding
    const TextEncoder = V8Interface(interfaces.TextEncoder);
    TextEncoder.registerGlobalFast(isolate, context, global, "TextEncoder");

    const TextDecoder = V8Interface(interfaces.TextDecoder);
    TextDecoder.registerGlobalFast(isolate, context, global, "TextDecoder");

    // Abort APIs - cooperative cancellation
    const AbortController = V8Interface(interfaces.AbortController);
    AbortController.registerGlobalFast(isolate, context, global, "AbortController");

    const AbortSignal = V8Interface(interfaces.AbortSignal);
    AbortSignal.registerGlobalFast(isolate, context, global, "AbortSignal");

    // Set up DOMException to inherit from Error per WebIDL spec
    // This is important for proper error handling in ShadowRealm
    setupDOMExceptionInheritance(
        isolate,
        context,
        global,
        struct {
            fn call(iso: *v8.Isolate, global_obj: *v8.Object, ctx: *v8.Context, name: []const u8) ?*v8.Object {
                const key = v8.v8_String_NewFromUtf8(iso, name.ptr, @intCast(name.len)) orelse return null;
                const value = v8.v8_Object_Get(global_obj, ctx, @ptrCast(key));
                if (value == null) return null;
                return @ptrCast(@alignCast(value));
            }
        }.call,
        struct {
            fn call(iso: *v8.Isolate, ctor: *v8.Object, ctx: *v8.Context) ?*v8.Object {
                const key = v8.v8_String_NewFromUtf8(iso, "prototype", 9) orelse return null;
                const value = v8.v8_Object_Get(ctor, ctx, @ptrCast(key));
                if (value == null) return null;
                return @ptrCast(@alignCast(value));
            }
        }.call,
        struct {
            fn set(child: *v8.Object, parent: *v8.Object, ctx: *v8.Context) void {
                _ = v8.v8_Object_SetPrototype(child, ctx, @ptrCast(parent));
            }
        }.set,
    );
}

/// Register legacy interface aliases
///
/// Per HTML spec, some interfaces have historical aliases that should be
/// available on the global object. For example:
/// - HTMLDocument is an alias for Document
/// - webkitURL is an alias for URL (via [LegacyWindowAlias])
pub fn registerLegacyInterfaceAliases(
    isolate: *v8.Isolate,
    context: *v8.Context,
) void {
    @setEvalBranchQuota(200_000);
    const global = v8.v8_Context_Global(context) orelse return;

    // HTMLDocument is a legacy alias for Document
    // Per HTML spec: "The HTMLDocument interface is an historical alias for Document."
    const doc_key = v8.v8_String_NewFromUtf8(isolate, "Document", 8);
    if (doc_key) |key| {
        const doc_ctor = v8.v8_Object_Get(global, context, @ptrCast(key));
        if (doc_ctor) |ctor| {
            const html_doc_key = v8.v8_String_NewFromUtf8(isolate, "HTMLDocument", 12);
            if (html_doc_key) |hkey| {
                _ = v8.v8_Object_Set(global, context, @ptrCast(hkey), ctor);
            }
        }
    }

    // webkitURL is a legacy alias for URL
    // Per WebIDL spec: [LegacyWindowAlias=webkitURL]
    // Set webkitURL = URL with non-enumerable attribute (per WebIDL spec for legacy aliases)
    const url_key = v8.v8_String_NewFromUtf8(isolate, "URL", 3);
    if (url_key) |key| {
        const url_ctor = v8.v8_Object_Get(global, context, @ptrCast(key));
        if (url_ctor) |ctor| {
            const webkit_url_key = v8.v8_String_NewFromUtf8(isolate, "webkitURL", 9);
            if (webkit_url_key) |wkey| {
                // Per WebIDL spec, LegacyWindowAlias should be:
                // - writable: true
                // - enumerable: false (not enumerable per legacy alias rules)
                // - configurable: true
                _ = v8.v8_Object_DefineProperty(
                    global,
                    context,
                    @ptrCast(wkey),
                    ctor,
                    true, // writable
                    false, // enumerable
                    true, // configurable
                );
            }
        }
    }

    // Register [LegacyWindowAlias] aliases from extended_attributes
    // Per WebIDL spec, [LegacyWindowAlias=Name] creates an alias on Window
    const iface_decls = @typeInfo(interfaces).@"struct".decls;
    inline for (iface_decls) |decl| {
        if (comptime shouldSkipInterface(decl.name)) continue;

        const InterfaceType = @field(interfaces, decl.name);

        if (@typeInfo(InterfaceType) == .@"struct" and @hasDecl(InterfaceType, "Meta")) {
            const Meta = InterfaceType.Meta;

            // Check for LegacyWindowAlias in extended_attributes
            if (@hasDecl(Meta, "extended_attributes")) {
                const ext_attrs = Meta.extended_attributes;
                inline for (ext_attrs) |attr| {
                    if (comptime std.mem.eql(u8, attr.name, "LegacyWindowAlias")) {
                        // Get the alias name from the attribute value
                        const alias_name: []const u8 = comptime blk: {
                            if (@hasField(@TypeOf(attr.value), "identifier")) {
                                break :blk attr.value.identifier;
                            }
                            break :blk "";
                        };

                        if (alias_name.len > 0) {
                            // Get the original interface constructor
                            const iface_name = Meta.name;
                            const iface_key = v8.v8_String_NewFromUtf8(isolate, iface_name.ptr, @intCast(iface_name.len));
                            if (iface_key) |ikey| {
                                const iface_ctor = v8.v8_Object_Get(global, context, @ptrCast(ikey));
                                if (iface_ctor) |ctor| {
                                    // Create the alias with non-enumerable property
                                    // Per WebIDL spec, LegacyWindowAlias should be:
                                    // - writable: true
                                    // - enumerable: false
                                    // - configurable: true
                                    const alias_key = v8.v8_String_NewFromUtf8(isolate, alias_name.ptr, @intCast(alias_name.len));
                                    if (alias_key) |akey| {
                                        _ = v8.v8_Object_DefineProperty(
                                            global,
                                            context,
                                            @ptrCast(akey),
                                            ctor,
                                            true, // writable
                                            false, // enumerable
                                            true, // configurable
                                        );
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Register legacy factory function aliases
///
/// Per WebIDL spec, [LegacyFactoryFunction=Name] creates a separate constructor
/// that creates instances of the interface. For example:
/// - Image creates HTMLImageElement instances
/// - Audio creates HTMLAudioElement instances
/// - Option creates HTMLOptionElement instances
pub fn registerLegacyFactoryFunctions(
    isolate: *v8.Isolate,
    context: *v8.Context,
) void {
    @setEvalBranchQuota(200_000);
    const iface_decls = @typeInfo(interfaces).@"struct".decls;
    const global = v8.v8_Context_Global(context) orelse return;

    inline for (iface_decls) |decl| {
        if (comptime shouldSkipInterface(decl.name)) continue;

        const InterfaceType = @field(interfaces, decl.name);

        if (@typeInfo(InterfaceType) == .@"struct" and @hasDecl(InterfaceType, "Meta")) {
            const Meta = InterfaceType.Meta;

            // Check for LegacyFactoryFunction extended attribute
            if (@hasDecl(Meta, "extended_attributes")) {
                const ext_attrs = Meta.extended_attributes;
                inline for (ext_attrs) |attr| {
                    if (comptime std.mem.eql(u8, attr.name, "LegacyFactoryFunction")) {
                        // Get the factory function name
                        const factory_name = comptime attr.value.identifier;

                        // Get the existing constructor for this interface
                        const iface_name = Meta.name;
                        const iface_key = v8.v8_String_NewFromUtf8(isolate, iface_name.ptr, @intCast(iface_name.len));
                        if (iface_key) |key| {
                            const ctor = v8.v8_Object_Get(global, context, @ptrCast(key));
                            if (ctor) |constructor| {
                                // Register the constructor under the legacy factory name
                                const factory_key = v8.v8_String_NewFromUtf8(isolate, factory_name.ptr, @intCast(factory_name.len));
                                if (factory_key) |fkey| {
                                    _ = v8.v8_Object_Set(global, context, @ptrCast(fkey), constructor);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Register all WebIDL namespaces as global objects (generic version)
///
/// This is a comptime generic function that takes the namespaces module as a parameter,
/// allowing it to be called from entry points that have access to the namespaces module.
///
/// This registers all namespaces (e.g., console, WebAssembly, CSS) and attaches
/// interfaces with [LegacyNamespace] attribute to their parent namespace.
///
/// Example:
/// ```zig
/// const namespaces = @import("namespaces");
/// interface_bindings.registerNamespacesGeneric(namespaces, isolate, context);
/// ```
pub fn registerNamespacesGeneric(
    comptime namespaces_mod: type,
    isolate: *v8.Isolate,
    context: *v8.Context,
) void {
    @setEvalBranchQuota(50_000_000);
    const ns_decls = @typeInfo(namespaces_mod).@"struct".decls;
    const iface_decls = @typeInfo(interfaces).@"struct".decls;

    inline for (ns_decls) |decl| {
        const NamespaceType = @field(namespaces_mod, decl.name);

        // Only bind types that have Meta (actual namespaces)
        if (@typeInfo(NamespaceType) == .@"struct" and @hasDecl(NamespaceType, "Meta")) {
            // Use V8Namespace to create object with all methods bound
            const NamespaceBinding = V8Namespace(NamespaceType);
            NamespaceBinding.registerGlobal(isolate, context, decl.name);

            // Get the namespace object we just created
            const global_obj = v8.v8_Context_Global(context);
            // Note: This should always succeed for valid comptime string literals
            const ns_key_str = v8.v8_String_NewFromUtf8(isolate, decl.name.ptr, @intCast(decl.name.len)).?;
            const ns_obj_value = v8.v8_Object_Get(global_obj.?, context, @ptrCast(ns_key_str));
            const ns_obj: ?*v8.Object = @ptrCast(ns_obj_value);

            // Attach interfaces with [LegacyNamespace=<this namespace>] as properties
            const namespace_name = decl.name;
            inline for (iface_decls) |iface_decl| {
                // Skip interfaces in skip list
                if (comptime shouldSkipInterface(iface_decl.name)) continue;

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
                        const InterfaceBinding = V8Interface(InterfaceType);
                        const template = InterfaceBinding.createTemplate(isolate);
                        const constructor = v8.v8_FunctionTemplate_GetFunction(template, context);

                        // Attach as property: WebAssembly.Instance = constructor
                        // Per WebIDL spec, namespace properties are non-writable, non-enumerable, non-configurable
                        const iface_key = v8.v8_String_NewFromUtf8(isolate, iface_decl.name.ptr, @intCast(iface_decl.name.len));
                        _ = v8.v8_Object_DefineProperty(
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
            _ = v8.v8_Object_PreventExtensions(@ptrCast(ns_obj), context);
        }
    }
}

/// Set up DOMException prototype inheritance from Error per WebIDL spec.
///
/// Per https://webidl.spec.whatwg.org/#idl-DOMException:
/// - DOMException.prototype must have Error.prototype in its prototype chain
///   (so `new DOMException() instanceof Error === true`)
/// - DOMException constructor itself should NOT inherit from Error
///   (so `Object.getPrototypeOf(DOMException) === Function.prototype`)
///
/// Only the prototype-side inherits from Error, not the class-side.
///
/// After setting up inheritance, we make the prototype immutable per WebIDL §3.7.1.
fn setupDOMExceptionInheritance(
    isolate: *v8.Isolate,
    context: *v8.Context,
    global: *v8.Object,
    comptime getConstructor: fn (*v8.Isolate, *v8.Object, *v8.Context, []const u8) ?*v8.Object,
    comptime getPrototype: fn (*v8.Isolate, *v8.Object, *v8.Context) ?*v8.Object,
    comptime setProto: fn (*v8.Object, *v8.Object, *v8.Context) void,
) void {
    // Get DOMException constructor
    const dom_exception_ctor = getConstructor(isolate, global, context, "DOMException") orelse return;

    // Get Error constructor
    const error_ctor = getConstructor(isolate, global, context, "Error") orelse return;

    // Get DOMException.prototype
    const dom_exception_proto = getPrototype(isolate, dom_exception_ctor, context) orelse return;

    // Get Error.prototype
    const error_proto = getPrototype(isolate, error_ctor, context) orelse return;

    // Set DOMException.prototype.__proto__ = Error.prototype
    // This makes: new DOMException() instanceof Error === true
    setProto(dom_exception_proto, error_proto, context);

    // NOTE: We do NOT set DOMException.__proto__ = Error
    // Per WebIDL spec and WPT tests, the class-side inheritance should remain Function.prototype
    // See: DOMException-custom-bindings.any.js "does not inherit from Error: class-side"
    // The test expects: Object.getPrototypeOf(DOMException) === Function.prototype

    // NOTE: Unlike other interfaces, we cannot make DOMException.prototype immutable after
    // setting up Error inheritance because V8's SetImmutableProto is only available on
    // ObjectTemplate, not Object. The prototype template was created without SetImmutableProto
    // specifically to allow this Error inheritance setup. This is acceptable per WebIDL spec
    // which only requires the prototype chain to be correct, not necessarily immutable.
}

/// Set up constructor inheritance chain after all constructors are registered
///
/// This automatically sets the __proto__ of child constructors to parent constructors
/// based on each interface's Meta.BaseType field.
///
/// For example:
/// - Element.__proto__ = Node (because Element.Meta.BaseType = Node)
/// - Node.__proto__ = EventTarget (because Node.Meta.BaseType = EventTarget)
/// - HTMLElement.__proto__ = Element (because HTMLElement.Meta.BaseType = Element)
///
/// Special case: DOMException inherits from Error per WebIDL spec.
///
/// This matches browser behavior where constructors inherit from each other.
pub fn setupConstructorInheritance(
    isolate: *v8.Isolate,
    context: *v8.Context,
) void {
    const global = v8.v8_Context_Global(context);

    // Helper to get a global constructor
    const GetConstructor = struct {
        fn call(iso: *v8.Isolate, global_obj: *v8.Object, ctx: *v8.Context, name: []const u8) ?*v8.Object {
            const key = v8.v8_String_NewFromUtf8(
                iso,
                name.ptr,
                @intCast(name.len),
            ) orelse return null;

            const value = v8.v8_Object_Get(global_obj, ctx, @ptrCast(key));
            if (value == null) return null;

            // Cast to Object (constructors are Function objects, which are Objects)
            return @ptrCast(@alignCast(value));
        }
    };

    // Helper to get `prototype` property of a constructor
    const GetPrototype = struct {
        fn call(iso: *v8.Isolate, ctor: *v8.Object, ctx: *v8.Context) ?*v8.Object {
            const key = v8.v8_String_NewFromUtf8(iso, "prototype", 9) orelse return null;
            const value = v8.v8_Object_Get(ctor, ctx, @ptrCast(key));
            if (value == null) return null;
            return @ptrCast(@alignCast(value));
        }
    };

    // Helper to set __proto__ on an object
    const setProto = struct {
        fn set(child: *v8.Object, parent: *v8.Object, ctx: *v8.Context) void {
            // Use V8's SetPrototype method
            // This is equivalent to Object.setPrototypeOf(child, parent) in JavaScript
            _ = v8.v8_Object_SetPrototype(child, ctx, @ptrCast(parent));
        }
    }.set;

    // Special case: DOMException must inherit from Error per WebIDL spec
    // https://webidl.spec.whatwg.org/#idl-DOMException
    // "The prototype of DOMException should be Error.prototype"
    setupDOMExceptionInheritance(isolate, context, global.?, GetConstructor.call, GetPrototype.call, setProto);

    // Automatically set up inheritance chain for all interfaces
    // Iterate over all interface declarations and set Constructor.__proto__ based on Meta.BaseType
    //
    // Note: We skip interfaces in the centralized skip list.
    @setEvalBranchQuota(200_000); // Increase quota for large number of interfaces

    const decls = @typeInfo(interfaces).@"struct".decls;

    inline for (decls) |decl| {
        // Skip problematic interfaces using centralized skip list
        if (comptime shouldSkipInterface(decl.name)) continue;

        const InterfaceType = @field(interfaces, decl.name);

        // Only process types that have Meta (actual interfaces)
        if (@typeInfo(InterfaceType) == .@"struct" and @hasDecl(InterfaceType, "Meta")) {
            // Skip mixins - they don't have constructors
            const is_mixin = comptime blk: {
                const Meta = InterfaceType.Meta;
                if (@hasDecl(Meta, "is_mixin")) {
                    break :blk Meta.is_mixin;
                }
                break :blk false;
            };
            if (is_mixin) continue;

            // Check if this interface has a parent (ParentInterface)
            // ParentInterface is the actual interface type (e.g., Node), while
            // BaseType is the state type (e.g., Node.State). We need ParentInterface
            // to get the interface name for constructor prototype chain setup.
            const has_parent = comptime @hasDecl(InterfaceType.Meta, "ParentInterface");

            if (has_parent) {
                const ParentTypeRaw = InterfaceType.Meta.ParentInterface;

                // Dereference pointer types (*Element -> Element)
                const ParentType = comptime blk: {
                    const type_info = @typeInfo(ParentTypeRaw);
                    if (type_info == .pointer) {
                        break :blk type_info.pointer.child;
                    }
                    break :blk ParentTypeRaw;
                };

                // Only proceed if ParentType is an actual interface (struct type)
                // Some interfaces have ParentInterface = ?*anyopaque which means no parent
                const parent_is_interface = comptime blk: {
                    const type_info = @typeInfo(ParentType);
                    if (type_info != .@"struct") break :blk false;
                    if (!@hasDecl(ParentType, "Meta")) break :blk false;
                    break :blk true;
                };

                if (parent_is_interface) {
                    // Get parent interface name from its Meta.name field
                    const parent_name = comptime ParentType.Meta.name;

                    // Set child.__proto__ = parent
                    if (GetConstructor.call(isolate, global.?, context, decl.name)) |child_ctor| {
                        if (GetConstructor.call(isolate, global.?, context, parent_name)) |parent_ctor| {
                            setProto(child_ctor, parent_ctor, context);
                        }
                    }
                }
            }
        }
    }
}

/// Register all interfaces
///
/// **DEPRECATED**: Use initializeBindings() instead for full setup including namespaces.
///
/// This function is kept for backward compatibility.
pub fn registerAll(
    isolate: *v8.Isolate,
    context: *v8.Context,
) void {
    // Use the new consolidated initialization
    initializeBindings(isolate, context);
}

// ============================================================================
// Metadata
// ============================================================================

/// Get list of all registered interfaces
pub fn getRegisteredInterfaces() []const InterfaceInfo {
    return &.{
        .{ .name = "EventTarget", .method_count = EventTarget.all_methods.len },
        .{ .name = "Event", .method_count = Event.all_methods.len },
        .{ .name = "Node", .method_count = Node.all_methods.len },
        .{ .name = "Element", .method_count = Element.all_methods.len },
        .{ .name = "Document", .method_count = Document.all_methods.len },
        .{ .name = "Window", .method_count = Window.all_methods.len },
    };
}

/// Information about a registered interface
pub const InterfaceInfo = struct {
    name: []const u8,
    method_count: usize,
};

// ============================================================================
// Testing
// ============================================================================

test "interface bindings module compiles" {
    const testing = std.testing;
    testing.refAllDecls(@This());
}

test "EventTarget binding has methods" {
    const testing = std.testing;

    // Verify EventTarget has methods extracted
    try testing.expect(EventTarget.all_methods.len > 0);

    // Check for known EventTarget methods
    var has_addEventListener = false;
    var has_removeEventListener = false;
    var has_dispatchEvent = false;

    for (EventTarget.all_methods) |method| {
        if (std.mem.eql(u8, method.name, "addEventListener")) has_addEventListener = true;
        if (std.mem.eql(u8, method.name, "removeEventListener")) has_removeEventListener = true;
        if (std.mem.eql(u8, method.name, "dispatchEvent")) has_dispatchEvent = true;
    }

    try testing.expect(has_addEventListener);
    try testing.expect(has_removeEventListener);

    try testing.expect(has_dispatchEvent);
}

/// Reinstall accessor callbacks on ALL interface prototypes
///
/// This is used after loading from a V8 snapshot. V8 snapshots serialize JavaScript
/// objects but native callback pointers become stale. This function re-installs
// NOTE: reinstallAllAccessorCallbacks and reinstallAllMethodCallbacks have been REMOVED.
// These functions were obsoleted by the Chromium pattern fix (whatwg-41la6).
// Calling GetFunction() before NewInstance() in template_registry.zig correctly
// materializes prototype chains during snapshot creation. Accessors set on
// PrototypeTemplate are preserved through snapshot restore without reinstallation.

// ============================================================================
// ON-DEMAND TEMPLATE CREATION
// ============================================================================
// These functions support creating templates at runtime for interfaces that
// were not included in the V8 snapshot. This is part of the Chromium-style
// minimal snapshot architecture where only core DOM interfaces are snapshotted,
// and other interfaces are created on-demand.

/// Get or create a template by interface name.
///
/// This function first checks the template registry for a cached template.
/// If found, it returns the cached template. If not found, it creates a new
/// template and caches it.
///
/// This is crucial for maintaining object identity - calling GetFunction on the
/// same template returns the same constructor function, which is required for
/// webkitURL === URL to pass.
pub fn getOrCreateTemplateByName(
    interface_name: []const u8,
    isolate: *v8.Isolate,
) ?*v8.FunctionTemplate {
    const template_registry = @import("template_registry.zig");

    // First check the cache (getTemplate uses the current isolate internally)
    if (template_registry.getTemplate(interface_name)) |cached| {
        return cached;
    }

    // Not in cache, create and cache it
    return createTemplateOnDemandByName(interface_name, isolate);
}

/// Create a template on-demand by interface name.
///
/// This is called when wrapInstanceAsV8Object() needs a template that doesn't
/// exist in the template registry. Instead of failing, we create the template
/// fresh with all accessors correctly installed.
///
/// Uses inline for to match interface name at runtime and create the appropriate template.
pub fn createTemplateOnDemandByName(
    interface_name: []const u8,
    isolate: *v8.Isolate,
) ?*v8.FunctionTemplate {
    @setEvalBranchQuota(10_000_000);
    const template_registry = @import("template_registry.zig");
    const iface_decls = @typeInfo(interfaces).@"struct".decls;

    inline for (iface_decls) |decl| {
        const InterfaceType = @field(interfaces, decl.name);

        // Skip non-interface types
        if (@typeInfo(InterfaceType) != .@"struct") continue;
        if (!@hasDecl(InterfaceType, "Meta")) continue;

        const meta = InterfaceType.Meta;

        // Skip mixins
        if (@hasDecl(InterfaceType.Meta, "is_mixin")) {
            if (meta.is_mixin) continue;
        }

        // Check if this is the interface we're looking for
        if (std.mem.eql(u8, decl.name, interface_name)) {
            // Skip problematic interfaces
            if (shouldSkipInterface(decl.name)) {
                return null;
            }

            // Debug: Log on-demand template creation
            if (std.mem.eql(u8, interface_name, "MessageEvent")) {
                std.debug.print("[ON-DEMAND] Creating MessageEvent template on-demand\n", .{});
            }

            // Create the template
            const Binding = V8Interface(InterfaceType);
            const template = Binding.createTemplate(isolate);

            // Register it in the template registry for future use
            template_registry.register(interface_name, template, isolate);

            return template;
        }
    }

    return null;
}

/// Register accessor properties directly on a prototype object by interface name.
///
/// This is needed because V8's ObjectTemplate::SetAccessorProperty() does not transfer
/// accessors to objects created via InstanceTemplate->NewInstance() when the prototype
/// is manually set via SetPrototype(). The accessors are registered on the template
/// but never appear on the materialized prototype.
///
/// This function looks up the interface by name and calls registerPropertiesAsOwnOnObject
/// to install accessors directly on the prototype object.
///
/// @param isolate The V8 isolate
/// @param context The V8 context
/// @param interface_name The name of the interface (e.g., "MessageEvent")
/// @param prototype_object The prototype object to install accessors on
/// @return true if the interface was found and accessors were registered
pub fn registerPropertiesOnPrototypeByName(
    isolate: *v8.Isolate,
    context: *v8.Context,
    interface_name: []const u8,
    prototype_object: *v8.Object,
) bool {
    @setEvalBranchQuota(200000);

    const decls = @typeInfo(interfaces).@"struct".decls;

    inline for (decls) |decl| {
        const T = @field(interfaces, decl.name);
        if (@typeInfo(@TypeOf(T)) == .type) {
            if (@hasDecl(T, "Meta")) {
                const meta = T.Meta;
                const is_mixin = if (@hasDecl(meta, "is_mixin")) meta.is_mixin else false;
                if (!is_mixin) {
                    if (std.mem.eql(u8, meta.name, interface_name)) {
                        // Found the interface - register its properties on the prototype
                        const Binding = V8Interface(T);
                        Binding.registerPropertiesAsOwnOnObject(isolate, context, prototype_object);
                        return true;
                    }
                }
            }
        }
    }

    return false;
}
