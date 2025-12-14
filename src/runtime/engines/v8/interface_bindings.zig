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

// Import generated interfaces
const interfaces = @import("interfaces");

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
pub const EventTarget = V8Interface(interfaces.EventTarget.EventTarget);

/// Event V8 binding
pub const Event = V8Interface(interfaces.Event.Event);

/// Node V8 binding
pub const Node = V8Interface(interfaces.Node.Node);

/// Element V8 binding
pub const Element = V8Interface(interfaces.Element.Element);

/// Document V8 binding
pub const Document = V8Interface(interfaces.Document.Document);

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
pub fn registerAllInterfaces(
    isolate: *v8.Isolate,
    context: *v8.Context,
) void {
    @setEvalBranchQuota(200_000);
    const iface_decls = @typeInfo(interfaces).@"struct".decls;

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

            // Register the interface as a global constructor
            const Binding = V8Interface(InterfaceType);
            Binding.registerGlobal(isolate, context, decl.name);
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

    // NOTE: Window properties as own properties on the global are registered
    // in createChildContext AFTER the Window instance is bound to the global.
    // This is necessary because the property getter/setter callbacks require
    // a valid Window instance in internal field 0 of the global object.
    // For the main context, property access works through the prototype chain.
}

/// Register legacy interface aliases
///
/// Per HTML spec, some interfaces have historical aliases that should be
/// available on the global object. For example:
/// - HTMLDocument is an alias for Document
fn registerLegacyInterfaceAliases(
    isolate: *v8.Isolate,
    context: *v8.Context,
) void {
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
}

/// Register legacy factory function aliases
///
/// Per WebIDL spec, [LegacyFactoryFunction=Name] creates a separate constructor
/// that creates instances of the interface. For example:
/// - Image creates HTMLImageElement instances
/// - Audio creates HTMLAudioElement instances
/// - Option creates HTMLOptionElement instances
fn registerLegacyFactoryFunctions(
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
