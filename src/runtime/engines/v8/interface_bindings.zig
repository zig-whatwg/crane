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
const build_options = @import("build_options");
const log = std.log.scoped(.v8_bindings);
const v8 = @import("ffi.zig");
const interface_mod = @import("interface.zig");
const V8Interface = interface_mod.V8Interface;
pub const V8Namespace = @import("namespace.zig").V8Namespace;
const webidl = @import("webidl");
const helpers = webidl.helpers;

// Import generated interfaces
const interfaces = @import("interfaces");
const global_constructor_handler = @import("global_constructor_handler.zig");

// ============================================================================
// Centralized Skip List
// ============================================================================

/// Interfaces to skip during registration due to codegen issues.
/// This is the SINGLE SOURCE OF TRUTH for problematic interfaces.
/// All entry points (WPT runner, REPL) use this list.
pub const interface_skip_list = .{
    "ViewCSS", // References undefined AbstractView
    "AbstractView", // Missing implementation
    "AuthenticatorAssertionResponse", // ArrayBuffer type issues
    "AuthenticatorAttestationResponse", // ArrayBuffer type issues
    "AuthenticatorResponse", // ArrayBuffer type issues
    "ChapterInformation", // MediaImage array issues
    "DeviceChangeEvent", // MediaDeviceInfo array issues
    "GamepadHapticActuator", // GamepadHapticEffectType array issues
    "MediaMetadata", // ChapterInformation array issues
    "PerformanceLongAnimationFrameTiming", // PerformanceScriptTiming array issues
    "PressureObserver", // Missing cached field
    "PublicKeyCredential", // ArrayBuffer type issues
    "PushManager", // Missing cached field
    "PushSubscriptionOptions", // ArrayBuffer type issues
    "RTCTrackEvent", // MediaStream array issues
    "XRCPUDepthInformation", // ArrayBuffer type issues
    "XRInputSource", // DOMString array issues
    "XRInputSourcesChangeEvent", // XRInputSource array issues
    "XRRay", // TypedArray issues
    "XRViewerPose", // XRView array issues
    "XRVisibilityMaskChangeEvent", // TypedArray issues
};

/// Namespaces the JavaScript engine defines itself, which the bindings must
/// leave alone.
///
/// The WebAssembly JavaScript Interface (wasm-js-api.idl) is part of the
/// engine, as ECMAScript is: V8 installs `WebAssembly`, and every constructor
/// its IDL puts in that namespace, on each context it creates. Blink binds none
/// of it - its only WebAssembly code is the streaming hook V8 asks the embedder
/// for. Registering the generated namespace over V8's replaced a working API
/// with stubs.
pub const engine_provided_namespaces = .{
    "WebAssembly",
};

/// Does the engine define namespace `name`? False unless listed: a namespace
/// answered true is never bound, so the default must be "ours".
pub fn namespaceIsEngineProvided(comptime name: []const u8) bool {
    return comptime blk: {
        for (engine_provided_namespaces) |provided| {
            if (std.mem.eql(u8, name, provided)) break :blk true;
        }
        break :blk false;
    };
}

/// Check if an interface name should be skipped
pub fn shouldSkipInterface(comptime name: []const u8) bool {
    // Using a simple array lookup since this is called at comptime
    // and the skip list is small
    return comptime blk: {
        for (interface_skip_list) |skip| {
            if (std.mem.eql(u8, name, skip)) break :blk true;
        }
        if (!interfaceAllowed(name)) break :blk true;
        break :blk false;
    };
}

/// Is `name` in the -Dinterfaces allow-list?
///
/// An empty allow-list means "everything", which is the default and is exactly the
/// behaviour that existed before this hook - so an ordinary build is unaffected.
///
/// This is where dead-code elimination actually bites. The `inline for` loops over
/// `@typeInfo(interfaces).decls` reference every interface, which is what forces all
/// 1,263 of them to be analysed and emitted; `interfaces/root.zig`'s unconditional
/// imports do not, because Zig analyses only referenced declarations. Narrowing the
/// loops is therefore the lever, and this is the single place they all consult.
pub fn interfaceAllowed(comptime name: []const u8) bool {
    return comptime blk: {
        const list = build_options.interface_allowlist;
        if (list.len == 0) break :blk true;

        // This runs once per interface, and there are 1,263 of them, each splitting
        // and comparing the list. The default 1,000-branch budget is nowhere near
        // enough - without this the build dies in std.mem with "evaluation exceeded
        // 200000 backwards branches", pointing at the stdlib rather than here.
        @setEvalBranchQuota(2_000_000);

        var it = std.mem.splitScalar(u8, list, ',');
        while (it.next()) |raw| {
            const entry = std.mem.trim(u8, raw, " \t");
            if (entry.len == 0) continue;
            if (std.mem.eql(u8, entry, name)) break :blk true;
            // An entry also admits everything it INHERITS FROM. Listing
            // "HTMLDivElement" without HTMLElement, Element, Node and EventTarget
            // would expose a constructor whose prototype chain is missing every
            // link above it - `div.addEventListener` would not exist. build.zig has
            // always documented the allow-list as covering "those names plus their
            // ancestors"; until now it did not, and the difference only showed up
            // at runtime as absent methods.
            if (isAncestorOf(name, entry)) break :blk true;
        }
        break :blk false;
    };
}

/// Is `name` an ancestor of the interface called `descendant_name`?
///
/// Walks `Meta.ParentInterface` from the descendant upwards. Returns false when the
/// descendant is not a known interface, which is the right answer for a typo in the
/// allow-list: an unknown entry admits nothing rather than everything.
fn isAncestorOf(comptime name: []const u8, comptime descendant_name: []const u8) bool {
    return comptime blk: {
        @setEvalBranchQuota(2_000_000);
        if (!@hasDecl(interfaces, descendant_name)) break :blk false;

        const Start = @field(interfaces, descendant_name);
        // `interfaces` also exposes non-container decls; `@hasDecl` on one is a
        // compile error, not a false, so the shape has to be checked first.
        if (@TypeOf(Start) != type) break :blk false;
        switch (@typeInfo(Start)) {
            .@"struct", .@"union", .@"enum", .@"opaque" => {},
            else => break :blk false,
        }

        var Cur = Start;
        // Bounded rather than `while (true)`: a cycle in generated Meta would
        // otherwise hang the compiler with no diagnostic. No real chain is close
        // to this deep.
        var depth: usize = 0;
        while (depth < 32) : (depth += 1) {
            if (!@hasDecl(Cur, "Meta")) break;
            if (!@hasDecl(Cur.Meta, "ParentInterface")) break;
            const Parent = Cur.Meta.ParentInterface;
            if (@TypeOf(Parent) != type) break;
            switch (@typeInfo(Parent)) {
                .@"struct", .@"union", .@"enum", .@"opaque" => {},
                else => break,
            }
            if (!@hasDecl(Parent, "Meta") or !@hasDecl(Parent.Meta, "name")) break;
            if (std.mem.eql(u8, Parent.Meta.name, name)) break :blk true;
            Cur = Parent;
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

/// CustomEvent V8 binding: an operation (`initCustomEvent`) and a dictionary
/// member (`CustomEventInit.detail`) of type `any`, for the tests that count
/// what argument conversion leaves behind.
pub const CustomEvent = V8Interface(interfaces.CustomEvent);

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
    const iface_decls = zig017DeclsOf(@typeInfo(interfaces).@"struct".decl_names);

    // OPTIMIZATION: Cache global object - don't fetch it 1231 times. OWNED:
    // a handle to the global kept pins the realm (its proxy until detached).
    const global = v8.v8_Context_Global(context) orelse return;
    defer v8.v8_Object_Dispose(global);

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

// ============================================================================
// Exposed constructs: lazy data properties on the global's template
// ============================================================================
//
// WebIDL 3.7: "For every interface that is exposed in a given realm and that
// is not declared with [LegacyNoInterfaceObject] or [LegacyNamespace], a
// corresponding property exists on the realm's global object" - and its
// [LegacyFactoryFunction]s and [LegacyWindowAlias]es too; for a construct the
// realm does not expose ("exposed" step 1: the global implements none of its
// exposure set; step 2: [SecureContext] in a realm that is not a secure
// context) there is none.
//
// Blink's model, which this is (read 2026-11-19 at chromium main, BSD):
// - every exposed construct of a global is a LAZY DATA PROPERTY of the
//   global's INSTANCE TEMPLATE, put there once per isolate
//   (IDLMemberInstaller::InstallExposedConstructs,
//   platform/bindings/idl_member_installer.cc), so a context made from the
//   template - or restored from a snapshot made from it - has them with no
//   work of its own, and an interface object is built only when script first
//   reads it (V8PerContextData::ConstructorForTypeSlowCase,
//   platform/bindings/v8_per_context_data.cc);
// - a construct only some realms of the kind expose (a [SecureContext] one)
//   goes on the one global, as the realm is made (the per-object overload);
// - an interface's template is made the first time an isolate needs it
//   (WrapperTypeInfo::GetV8ClassTemplate -> V8PerIsolateData::FindV8Template /
//   AddV8Template, platform/bindings/wrapper_type_info.cc), except the few a
//   snapshot holds, which the isolate takes back once
//   (V8ContextSnapshotImpl::InstallInterfaceTemplates,
//   bindings/modules/v8/v8_context_snapshot_impl.cc).
//
// It replaces registerAllTemplatesOnly (lane tmpl1, measured
// tmp/plans/tmpl1-measure.md): the snapshot held every interface object in
// both of its contexts, every restored realm deserialized them all and
// replaced them - keeping both, through its native context's template
// instantiation cache (860 KB per realm) - and the isolate's first realm made
// all 1,121 templates again beside the snapshot's (1.42 MB per isolate).

/// One exposed construct: a property of a global whose value is a function
/// made in the realm - an interface object, a legacy factory function, or an
/// alias of an interface object.
pub const Construct = struct {
    /// The global's property.
    name: [:0]const u8,
    /// The globals that expose it ([Exposed]).
    exposure: std.EnumSet(helpers.GlobalScope),
    /// [SecureContext]: only a realm whose settings object is a secure
    /// context exposes it (WebIDL 3.3.13; "exposed" step 2).
    secure: bool,
    /// Builds it in `context` (once per realm: a second call answers the
    /// same function): OWNED, or null.
    make: *const fn (isolate: *v8.Isolate, context: *v8.Context) ?*v8.Function,
};

fn hasExtendedAttribute(comptime T: type, comptime attribute: []const u8) bool {
    comptime {
        if (!@hasDecl(T.Meta, "extended_attributes")) return false;
        for (T.Meta.extended_attributes) |attr| {
            if (std.mem.eql(u8, attr.name, attribute)) return true;
        }
        return false;
    }
}

/// Whether the generated declaration `name` is an interface with an
/// interface object: not a mixin, not skipped, not [LegacyNamespace] (its
/// object is its namespace's property), and - for a callback interface - one
/// with constants (WebIDL 3.7: only a "legacy callback interface object").
fn hasInterfaceObject(comptime name: []const u8) bool {
    comptime {
        if (shouldSkipInterface(name)) return false;
        const T = @field(interfaces, name);
        if (@TypeOf(T) != type) return false;
        if (@typeInfo(T) != .@"struct" or !@hasDecl(T, "Meta")) return false;
        if (@hasDecl(T.Meta, "is_mixin") and T.Meta.is_mixin) return false;
        if (hasExtendedAttribute(T, "LegacyNamespace")) return false;
        if (@hasDecl(T.Meta, "is_callback_interface") and T.Meta.is_callback_interface and !@hasDecl(T.Meta, "constants")) return false;
        return true;
    }
}

/// Whether `T` is exposed only in a secure context: [SecureContext] on it or
/// on an interface it inherits from. WebIDL 3.3.13: "an interface without the
/// [SecureContext] extended attribute must not inherit from another interface
/// that does specify [SecureContext]" - six WebXR interfaces' IDL does
/// (XRJointSpace, XRBodySpace, XRCompositionLayer, XRJointPose,
/// XRGPUDepthInformation, XRWebGLDepthInformation: their parents are
/// [SecureContext], they are not); Chromium declares XRJointSpace,
/// XRJointPose, XRCompositionLayer and XRWebGLDepthInformation
/// [SecureContext] (third_party/blink/renderer/modules/xr/*.idl, main
/// 2026-11-19) and has no XRBodySpace or XRGPUDepthInformation. An insecure
/// realm exposed them without their parent interface objects.
fn isSecureContextOnly(comptime T: type) bool {
    comptime {
        var Cur = T;
        var depth: usize = 0;
        while (depth < 32) : (depth += 1) {
            if (hasExtendedAttribute(Cur, "SecureContext")) return true;
            if (!@hasDecl(Cur.Meta, "ParentInterface")) return false;
            const Parent = Cur.Meta.ParentInterface;
            if (@TypeOf(Parent) != type or @typeInfo(Parent) != .@"struct" or !@hasDecl(Parent, "Meta")) return false;
            Cur = Parent;
        }
        return false;
    }
}

fn exposureOf(comptime T: type) std.EnumSet(helpers.GlobalScope) {
    comptime {
        var set = std.EnumSet(helpers.GlobalScope).empty;
        for (std.enums.values(helpers.GlobalScope)) |scope| {
            if (helpers.isExposedIn(T, scope)) set.insert(scope);
        }
        return set;
    }
}

fn interfaceObjectMaker(comptime T: type) *const fn (*v8.Isolate, *v8.Context) ?*v8.Function {
    return struct {
        fn make(isolate: *v8.Isolate, context: *v8.Context) ?*v8.Function {
            return V8Interface(T).materializeInterfaceObject(isolate, context, T.Meta.name);
        }
    }.make;
}

fn factoryMaker(comptime factory_name: []const u8, comptime T: type) *const fn (*v8.Isolate, *v8.Context) ?*v8.Function {
    return struct {
        fn make(isolate: *v8.Isolate, context: *v8.Context) ?*v8.Function {
            const interface_object = V8Interface(T).materializeInterfaceObject(isolate, context, T.Meta.name) orelse return null;
            defer v8.v8_Function_Dispose(interface_object);
            return @import("legacy_factory_functions.zig").make(factory_name, isolate, context, interface_object);
        }
    }.make;
}

/// Every exposed construct of every global, in the order a global gets its
/// properties: the interface objects (declaration order), the
/// [LegacyFactoryFunction]s, then the aliases - HTML's HTMLDocument and the
/// [LegacyWindowAlias]es. A construct's index here is its lazy property's
/// data.
pub const constructs = blk: {
    @setEvalBranchQuota(100_000_000);
    const decl_names = @typeInfo(interfaces).@"struct".decl_names;
    var buf: [decl_names.len + 64]Construct = undefined;
    var n: usize = 0;
    for (decl_names) |name| {
        if (!hasInterfaceObject(name)) continue;
        const T = @field(interfaces, name);
        buf[n] = .{
            .name = name,
            .exposure = exposureOf(T),
            .secure = isSecureContextOnly(T),
            .make = interfaceObjectMaker(T),
        };
        n += 1;
    }
    // HTML (the HTMLImageElement, HTMLAudioElement and HTMLOptionElement
    // IDL): [LegacyFactoryFunction=Image(...)] and the others - exposed where
    // their interface is.
    for (.{ .{ "Image", "HTMLImageElement" }, .{ "Audio", "HTMLAudioElement" }, .{ "Option", "HTMLOptionElement" } }) |factory| {
        const T = @field(interfaces, factory[1]);
        buf[n] = .{
            .name = factory[0],
            .exposure = exposureOf(T),
            .secure = isSecureContextOnly(T),
            .make = factoryMaker(factory[0], T),
        };
        n += 1;
    }
    // HTML 3.1.1: "for historical reasons, Window objects must also have a
    // writable, configurable, non-enumerable property named HTMLDocument
    // whose value is the Document interface object".
    buf[n] = .{
        .name = "HTMLDocument",
        .exposure = std.EnumSet(helpers.GlobalScope).initOne(.Window),
        .secure = false,
        .make = interfaceObjectMaker(interfaces.Document),
    };
    n += 1;
    // [LegacyWindowAlias=Name] (WebIDL 3.4.11): a property of a Window global
    // whose value is the interface object. The identifier-list forms
    // (DOMMatrix's) wait for the geometry/SVG ruling, as before.
    for (decl_names) |name| {
        if (!hasInterfaceObject(name)) continue;
        const T = @field(interfaces, name);
        if (!@hasDecl(T.Meta, "extended_attributes")) continue;
        for (T.Meta.extended_attributes) |attr| {
            if (!std.mem.eql(u8, attr.name, "LegacyWindowAlias")) continue;
            if (!@hasField(@TypeOf(attr.value), "identifier")) continue;
            var exposure = exposureOf(T);
            exposure.setIntersection(std.EnumSet(helpers.GlobalScope).initOne(.Window));
            buf[n] = .{
                .name = attr.value.identifier,
                .exposure = exposure,
                .secure = isSecureContextOnly(T),
                .make = interfaceObjectMaker(T),
            };
            n += 1;
        }
    }
    const final = buf[0..n].*;
    break :blk final;
};

/// The index in `constructs` of the construct named `name`, by the global's
/// property name.
const construct_index = blk: {
    @setEvalBranchQuota(100_000_000);
    var entries: [constructs.len]struct { []const u8, u16 } = undefined;
    for (constructs, 0..) |c, i| entries[i] = .{ c.name, i };
    break :blk std.StaticStringMap(u16).initComptime(entries);
};

/// The construct `name` - a global's property - names, if any.
pub fn constructNamed(name: []const u8) ?u16 {
    return construct_index.get(name);
}

/// The indices of the constructs `scope` exposes unconditionally (on the
/// global's template) and of those it exposes in a secure context only (on
/// each secure realm's global).
fn ScopeConstructs(comptime scope: helpers.GlobalScope) type {
    return struct {
        const always = select(false);
        const secure_only = select(true);

        fn select(comptime secure: bool) [count(secure)]u16 {
            @setEvalBranchQuota(10_000_000);
            var out: [count(secure)]u16 = undefined;
            var n: usize = 0;
            for (constructs, 0..) |c, i| {
                if (c.exposure.contains(scope) and c.secure == secure) {
                    out[n] = i;
                    n += 1;
                }
            }
            return out;
        }

        fn count(comptime secure: bool) usize {
            @setEvalBranchQuota(10_000_000);
            var n: usize = 0;
            for (constructs) |c| {
                if (c.exposure.contains(scope) and c.secure == secure) n += 1;
            }
            return n;
        }
    };
}

/// `scope`'s exposed constructs that every realm of it has, as lazy data
/// properties of `global_template` - the template the scope's globals are
/// made from (Window's instance template): once per isolate, when the
/// template is made, and in the snapshot generator.
pub fn installExposedConstructs(comptime scope: helpers.GlobalScope, global_template: *v8.ObjectTemplate) void {
    const getter = global_constructor_handler.lazyConstructGetter;
    for (ScopeConstructs(scope).always) |i| {
        const c = constructs[i];
        v8.v8_ObjectTemplate_SetLazyDataPropertyIndexed(global_template, c.name.ptr, @intCast(c.name.len), getter, i);
    }
}

/// `scope`'s exposed constructs that only some of its realms have, on
/// `context`'s global, as the realm is made: the [SecureContext] ones, in a
/// realm whose settings object is a secure context (ContextData's
/// secure_context, recorded before this). A realm that is not one never has
/// them - nothing is installed and then hidden.
pub fn installConditionalConstructs(comptime scope: helpers.GlobalScope, context: *v8.Context) void {
    if (!interface_mod.realmIsSecureContext(context)) return;
    const global = v8.v8_Context_Global(context) orelse return;
    defer v8.v8_Object_Dispose(global);
    const getter = global_constructor_handler.lazyConstructGetter;
    for (ScopeConstructs(scope).secure_only) |i| {
        const c = constructs[i];
        _ = v8.v8_Object_SetLazyDataPropertyIndexed(global, context, c.name.ptr, @intCast(c.name.len), getter, i);
    }
}

/// The construct at `index` built in `context`: OWNED, or null for an index
/// that names none.
pub fn makeConstruct(index: i32, isolate: *v8.Isolate, context: *v8.Context) ?*v8.Function {
    if (index < 0 or index >= constructs.len) return null;
    return constructs[@intCast(index)].make(isolate, context);
}

/// The templates the snapshot generator attaches to the isolate snapshot
/// (v8_SnapshotCreator_AddFunctionTemplate), in this order, and createAgent
/// takes back into a restored isolate's registry by the same index: the
/// templates the snapshot's Window context was made from - its global is an
/// instance of Window's, which inherits from EventTarget's. Blink attaches
/// those and the document's chain (V8ContextSnapshotImpl's type_info_table);
/// Crane's snapshot holds no document wrapper, and every other template is
/// made on first use.
pub const snapshot_templates = [_][:0]const u8{ "EventTarget", "Window" };

/// A restored isolate's snapshot templates (`snapshot_templates`), taken
/// back once into its registry: the same templates its restored contexts
/// were made from, so a lazily built Window or EventTarget interface object
/// is the one its global's prototype chain already has (V8 answers
/// GetFunction from the native context's template instantiation cache, which
/// the snapshot carries). Blink: V8ContextSnapshotImpl::
/// InstallInterfaceTemplates. False when one was missing: the blob was not
/// made by this generator.
pub fn takeSnapshotTemplates(isolate: *v8.Isolate) bool {
    const template_registry = @import("template_registry.zig");
    for (snapshot_templates, 0..) |name, i| {
        const template = v8.v8_Isolate_TakeFunctionTemplateFromSnapshot(isolate, i) orelse return false;
        template_registry.register(name, template, isolate);
    }
    return true;
}

/// A worker's or a worklet's realm, as it is made: the realm's exposure scope
/// recorded (member-level [Exposed] reads it as interface objects are built),
/// and its conditional constructs installed - the [SecureContext] ones, in a
/// secure realm. The constructs every realm of `scope` has are lazy data
/// properties of its global's template (worker_realm.globalScopeTemplate,
/// installExposedConstructs): built when script first reads them. Before lane
/// tmpl1 this built every exposed interface object of the scope - 369 of a
/// dedicated worker's, 2.8 ms and 1.5 MB - and deleted the ones a restored
/// isolate's default context had copied on (that context is plain now).
pub fn installForScope(
    isolate: *v8.Isolate,
    context: *v8.Context,
    comptime scope: helpers.GlobalScope,
) void {
    _ = isolate;
    if (@import("context_manager.zig").getEntry(context)) |entry| entry.exposure_scope = scope;
    installConditionalConstructs(scope, context);
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

    // Step 4: Register legacy interface aliases
    // These are historical aliases that map to other interfaces
    // e.g., HTMLDocument is an alias for Document per HTML spec
    // (Intl and the built-ins' toLocaleString are V8's own, from ICU: lane
    // icu1 retired the Zig binding these steps installed.)
    registerLegacyInterfaceAliases(isolate, context);

    // Step 5: SKIP namespace registration during snapshot creation!
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

    // Step 6: WindowProperties insertion is deferred.
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

    // Step 4: Register legacy interface aliases
    // These are historical aliases that map to other interfaces
    // e.g., HTMLDocument is an alias for Document per HTML spec
    // (Intl and toLocaleString are V8's own: see initializeBindings.)
    registerLegacyInterfaceAliases(isolate, context);

    // Step 5: SKIP namespace registration - done at runtime via registerNamespacesGeneric()
    // (See comment in initializeBindings for explanation)

    // Step 6: WindowProperties insertion is deferred (same as initializeBindings)
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

    // Step 4: Register legacy interface aliases
    // These are historical aliases that map to other interfaces
    // e.g., HTMLDocument is an alias for Document per HTML spec
    // (Intl and toLocaleString are V8's own: see initializeBindings.)
    registerLegacyInterfaceAliases(isolate, context);

    // Step 5: SKIP namespace registration - done at runtime via registerNamespacesGeneric()
    // (See comment in initializeBindings for explanation)

    // Step 6: WindowProperties insertion is deferred (same as initializeBindings)
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
    // Get the global object from context (OWNED)
    const global = v8.v8_Context_Global(context) orelse {
        log.debug("[CORE-BINDINGS] Failed to get global object from context\n", .{});
        return;
    };
    defer v8.v8_Object_Dispose(global);

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
///
/// The eager form, for a context whose interface objects are all built
/// (initializeBindings, a test's registerAllInterfaces): a Window realm gets
/// them as lazy constructs (installExposedConstructs).
pub fn registerLegacyInterfaceAliases(
    isolate: *v8.Isolate,
    context: *v8.Context,
) void {
    @setEvalBranchQuota(200_000);
    // Every handle below is released: each points into `context`, and one
    // kept keeps the whole realm (docs/lessons/
    // debugging-find-what-keeps-a-page-alive-count-native.md).
    const global = v8.v8_Context_Global(context) orelse return;
    defer v8.v8_Object_Dispose(global);

    // HTMLDocument: "for historical reasons, Window objects must also have a
    // writable, configurable, non-enumerable property named HTMLDocument whose
    // value is the Document interface object" - defined, never assigned.
    defineAlias(isolate, context, global, "Document", "HTMLDocument");

    // webkitURL is a legacy alias for URL ([LegacyWindowAlias=webkitURL]).
    defineAlias(isolate, context, global, "URL", "webkitURL");

    // Register [LegacyWindowAlias] aliases from extended_attributes
    // Per WebIDL spec, [LegacyWindowAlias=Name] creates an alias on Window
    const iface_decls = zig017DeclsOf(@typeInfo(interfaces).@"struct".decl_names);
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

                        if (alias_name.len > 0) defineAlias(isolate, context, global, Meta.name, alias_name);
                    }
                }
            }
        }
    }
}

/// `alias` on the global: the interface object `interface_name`, writable,
/// configurable, not enumerable (WebIDL [LegacyWindowAlias]).
fn defineAlias(isolate: *v8.Isolate, context: *v8.Context, global: *v8.Object, interface_name: []const u8, alias: []const u8) void {
    const key = v8.v8_String_NewFromUtf8(isolate, interface_name.ptr, @intCast(interface_name.len)) orelse return;
    defer v8.v8_String_Dispose(key);
    const interface_object = v8.v8_Object_Get(global, context, @ptrCast(key)) orelse return;
    defer v8.v8_Value_Dispose(interface_object);
    const alias_key = v8.v8_String_NewFromUtf8(isolate, alias.ptr, @intCast(alias.len)) orelse return;
    defer v8.v8_String_Dispose(alias_key);
    _ = v8.v8_Object_DefineProperty(global, context, @ptrCast(alias_key), interface_object, true, false, true);
}

/// WebIDL [LegacyFactoryFunction]s - Image, Audio and Option - as their own
/// function objects (legacy_factory_functions.zig). They were aliases of the
/// interface objects, which are [HTMLConstructor]s, so `new Image()` threw.
pub fn registerLegacyFactoryFunctions(
    isolate: *v8.Isolate,
    context: *v8.Context,
) void {
    @import("legacy_factory_functions.zig").install(isolate, context);
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
    const ns_decls = zig017DeclsOf(@typeInfo(namespaces_mod).@"struct".decl_names);
    const iface_decls = zig017DeclsOf(@typeInfo(interfaces).@"struct".decl_names);

    // [inspector_protocol] (-Dcdp): V8's own console object, kept on the
    // realm's global object before the Console Standard's namespace replaces
    // it, so a host's inspector session hears the realm's console calls from
    // V8 itself (protocol_inspector.consoleMessage). Its cost: one private
    // property per realm, holding the object and the builtin functions V8
    // already made with the context - nothing is allocated for it.
    if (comptime build_options.cdp and @hasDecl(namespaces_mod, "console")) v8.v8_Context_KeepEngineConsole(context);

    inline for (ns_decls) |decl| {
        install_namespace: {
            const NamespaceType = @field(namespaces_mod, decl.name);

            // Only bind types that have Meta (actual namespaces), and never one the
            // engine already defines - that would shadow it, and its
            // [LegacyNamespace] interfaces with it.
            if (@typeInfo(NamespaceType) == .@"struct" and @hasDecl(NamespaceType, "Meta") and
                comptime !namespaceIsEngineProvided(decl.name))
            {
                if (!@import("namespace.zig").namespaceIsExposed(NamespaceType, context)) break :install_namespace;
                // Use V8Namespace to create object with all methods bound
                const NamespaceBinding = V8Namespace(NamespaceType);
                NamespaceBinding.registerGlobal(isolate, context, decl.name);

                // Get the namespace object we just created. Every handle here is
                // owned and released: each points into `context`, and one leaked
                // per namespace kept every context alive.
                const global_obj = v8.v8_Context_Global(context);
                defer if (global_obj) |g| v8.v8_Object_Dispose(g);
                // Note: This should always succeed for valid comptime string literals
                const ns_key_str = v8.v8_String_NewFromUtf8(isolate, decl.name.ptr, @intCast(decl.name.len)).?;
                defer v8.v8_String_Dispose(ns_key_str);
                const ns_obj_value = v8.v8_Object_Get(global_obj.?, context, @ptrCast(ns_key_str));
                defer if (ns_obj_value) |v| v8.v8_Value_Dispose(v);
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
                            defer if (constructor) |c| v8.v8_Function_Dispose(c);

                            // Attach as property: WebAssembly.Instance = constructor
                            // Per WebIDL spec, namespace properties are non-writable, non-enumerable, non-configurable
                            const iface_key = v8.v8_String_NewFromUtf8(isolate, iface_decl.name.ptr, @intCast(iface_decl.name.len));
                            defer if (iface_key) |k| v8.v8_String_Dispose(k);
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

                // The namespace object stays an ordinary, extensible object
                // (WebIDL 3.13.1: OrdinaryObjectCreate, then its attributes,
                // operations and constants - each configurable). It used to be
                // sealed here (v8_Object_PreventExtensions seals), which made
                // every operation and attribute non-configurable; idlharness
                // asserts Object.isExtensible(namespaceObject) and configurable
                // members, as Chrome, Firefox and Safari have them.
            }
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
    // Every handle is OWNED and released (see setupConstructorInheritance).
    // Get DOMException constructor
    const dom_exception_ctor = getConstructor(isolate, global, context, "DOMException") orelse return;
    defer v8.v8_Value_Dispose(@ptrCast(dom_exception_ctor));

    // Get Error constructor
    const error_ctor = getConstructor(isolate, global, context, "Error") orelse return;
    defer v8.v8_Value_Dispose(@ptrCast(error_ctor));

    // Get DOMException.prototype
    const dom_exception_proto = getPrototype(isolate, dom_exception_ctor, context) orelse return;
    defer v8.v8_Value_Dispose(@ptrCast(dom_exception_proto));

    // Get Error.prototype
    const error_proto = getPrototype(isolate, error_ctor, context) orelse return;
    defer v8.v8_Value_Dispose(@ptrCast(error_proto));

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
    // Every handle below is released: each points into `context`, and the
    // ~5,000 this used to keep (a key string, a constructor and a prototype
    // per interface with a parent) held every realm made without the
    // snapshot alive for the life of the process.
    const global = v8.v8_Context_Global(context) orelse return;
    defer v8.v8_Object_Dispose(global);

    // Helper to get a global constructor. OWNED.
    const GetConstructor = struct {
        fn call(iso: *v8.Isolate, global_obj: *v8.Object, ctx: *v8.Context, name: []const u8) ?*v8.Object {
            const key = v8.v8_String_NewFromUtf8(
                iso,
                name.ptr,
                @intCast(name.len),
            ) orelse return null;
            defer v8.v8_String_Dispose(key);

            const value = v8.v8_Object_Get(global_obj, ctx, @ptrCast(key)) orelse return null;

            // Cast to Object (constructors are Function objects, which are Objects)
            return @ptrCast(@alignCast(value));
        }
    };

    // Helper to get `prototype` property of a constructor. OWNED.
    const GetPrototype = struct {
        fn call(iso: *v8.Isolate, ctor: *v8.Object, ctx: *v8.Context) ?*v8.Object {
            const key = v8.v8_String_NewFromUtf8(iso, "prototype", 9) orelse return null;
            defer v8.v8_String_Dispose(key);
            const value = v8.v8_Object_Get(ctor, ctx, @ptrCast(key)) orelse return null;
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
    setupDOMExceptionInheritance(isolate, context, global, GetConstructor.call, GetPrototype.call, setProto);

    // Automatically set up inheritance chain for all interfaces
    // Iterate over all interface declarations and set Constructor.__proto__ based on Meta.BaseType
    //
    // Note: We skip interfaces in the centralized skip list.
    @setEvalBranchQuota(200_000); // Increase quota for large number of interfaces

    const decls = zig017DeclsOf(@typeInfo(interfaces).@"struct".decl_names);

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

                    // Set child.__proto__ = parent (constructor inheritance)
                    // AND child.prototype.__proto__ = parent.prototype (prototype chain for instanceof)
                    if (GetConstructor.call(isolate, global, context, decl.name)) |child_ctor| {
                        defer v8.v8_Value_Dispose(@ptrCast(child_ctor));
                        if (GetConstructor.call(isolate, global, context, parent_name)) |parent_ctor| {
                            defer v8.v8_Value_Dispose(@ptrCast(parent_ctor));
                            // Constructor inheritance: HTMLDivElement.__proto__ = HTMLElement
                            setProto(child_ctor, parent_ctor, context);

                            // Prototype chain for instanceof: HTMLDivElement.prototype.__proto__ = HTMLElement.prototype
                            // This is CRITICAL for `div instanceof HTMLElement` to return true
                            if (GetPrototype.call(isolate, child_ctor, context)) |child_proto| {
                                defer v8.v8_Value_Dispose(@ptrCast(child_proto));
                                if (GetPrototype.call(isolate, parent_ctor, context)) |parent_proto| {
                                    defer v8.v8_Value_Dispose(@ptrCast(parent_proto));
                                    setProto(child_proto, parent_proto, context);
                                }
                            }
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

/// One block of its own that a generated State names as an impl's internal
/// state: where the State keeps the pointer to it, and its size.
pub const StateBlock = struct {
    /// Byte offset, in the State, of the level's `own._internal` pointer.
    offset: u32,
    /// The size of the block it points at.
    bytes: u32,
};

/// The internal state blocks `State` - an interface's generated State - can
/// name: one for each level of its inheritance chain that keeps its impl's
/// internal state in a block of its own (runtime `InternalKind.pointer`: an
/// Event's dispatch state is one). A level that keeps the state by
/// value (a node's: it is inside the State block already), or has none,
/// names nothing. Read from the State's own types, so no impl is named and
/// nobody keeps a list. A hand-written State (no `internal_kind`) ends the
/// walk: it names no block the adapter can know.
pub fn stateBlocksOf(comptime State: type) []const StateBlock {
    comptime {
        var blocks: []const StateBlock = &.{};
        var Level = State;
        var offset: usize = 0;
        while (@typeInfo(Level) == .@"struct" and @hasDecl(Level, "internal_kind")) {
            if (Level.internal_kind == .pointer) {
                const Own = @FieldType(Level, "own");
                const Target = @typeInfo(@typeInfo(@FieldType(Own, "_internal")).optional.child).pointer.child;
                // A block whose size its type does not say (an opaque) is
                // not counted.
                if (@typeInfo(Target) != .@"opaque" and @sizeOf(Target) != 0) {
                    blocks = blocks ++ [_]StateBlock{.{
                        .offset = offset + @offsetOf(Level, "own") + @offsetOf(Own, "_internal"),
                        .bytes = @sizeOf(Target),
                    }};
                }
            }
            const Base = @FieldType(Level, "base");
            if (Base == void) break;
            offset += @offsetOf(Level, "base");
            Level = Base;
        }
        const final = blocks[0..blocks.len].*;
        return &final;
    }
}

/// The bytes of the internal state blocks `state` names NOW: each of
/// `blocks` whose pointer is set. `state` is the State `blocks` was read
/// from (an instance's `state`).
pub fn stateBlockBytes(blocks: []const StateBlock, state: *const anyopaque) usize {
    const base: [*]const u8 = @ptrCast(state);
    var total: usize = 0;
    for (blocks) |block| {
        const pointer: *const ?*anyopaque = @ptrCast(@alignCast(base + block.offset));
        if (pointer.* != null) total += block.bytes;
    }
    return total;
}

/// What the wrapper cache needs to know of an interface when it takes a
/// wrapper of it (wrapper_cache.zig `WrapperCache.setConstructed`), read once
/// per wrap by the interface's name.
pub const WrapperFacts = struct {
    /// The wrapper is not an unmodified API object from the moment it is
    /// made (`wrapperIsBornChanged`).
    born_changed: bool = false,
    /// The internal state blocks an instance's State can name
    /// (`stateBlocksOf`).
    state_blocks: []const StateBlock = &.{},
};

/// Every interface's WrapperFacts, by name. `born_changed`: every interface
/// whose instances are born with an own property
/// (interface.instancesAreBornWithOwnProperties: a [LegacyUnforgeable] member
/// of its own or inherited - Event and all that inherit from it, Location,
/// ...) and every legacy platform object whose wrapper is a Proxy
/// (template_registry.isLegacyPlatformObject). Built at compile time from
/// each interface's metadata and State; nobody keeps it by hand.
const wrapper_facts = blk: {
    @setEvalBranchQuota(100_000_000);
    const template_registry = @import("template_registry.zig");
    const decl_names = @typeInfo(interfaces).@"struct".decl_names;
    var entries: [decl_names.len]struct { []const u8, WrapperFacts } = undefined;
    var count: usize = 0;
    for (decl_names) |decl_name| {
        const InterfaceType = @field(interfaces, decl_name);
        if (@typeInfo(InterfaceType) != .@"struct" or !@hasDecl(InterfaceType, "Meta")) continue;
        if (!@hasDecl(InterfaceType.Meta, "name")) continue;
        const name: []const u8 = InterfaceType.Meta.name;
        const facts: WrapperFacts = .{
            .born_changed = interface_mod.instancesAreBornWithOwnProperties(InterfaceType) or template_registry.isLegacyPlatformObject(name),
            .state_blocks = if (@hasDecl(InterfaceType, "State")) stateBlocksOf(InterfaceType.State) else &.{},
        };
        if (!facts.born_changed and facts.state_blocks.len == 0) continue;
        entries[count] = .{ name, facts };
        count += 1;
    }
    const final = entries[0..count].*;
    break :blk std.StaticStringMap(WrapperFacts).initComptime(final);
};

/// The WrapperFacts of the interface named `interface_name`; the defaults -
/// an ordinary wrapper, no block - for a name no interface has.
pub fn wrapperFactsOf(interface_name: []const u8) WrapperFacts {
    return wrapper_facts.get(interface_name) orelse .{};
}

/// Whether a wrapper of the interface named `interface_name` is, from the
/// moment it is made, one V8 will not drop in a young-generation collection
/// (wrapper_cache.zig `heldByWeakHandle`: the rule and its reasons).
pub fn wrapperIsBornChanged(interface_name: []const u8) bool {
    return wrapperFactsOf(interface_name).born_changed;
}

/// Create a template on-demand by interface name.
///
/// This is called when wrapInstanceAsV8Object() needs a template that doesn't
/// exist in the template registry. Instead of failing, we create the template
/// fresh with all accessors correctly installed.
///
/// Uses inline for to match interface name at runtime and create the appropriate template.
pub inline fn installConditionalUnforgeablesByName(interface_name: []const u8, isolate: *v8.Isolate, context: *v8.Context, object: *v8.Object) void {
    @setEvalBranchQuota(10_000_000);
    inline for (@typeInfo(interfaces).@"struct".decl_names) |decl_name| {
        const InterfaceType = @field(interfaces, decl_name);
        if (@typeInfo(InterfaceType) != .@"struct" or !@hasDecl(InterfaceType, "Meta")) continue;
        if (comptime interface_mod.hasConditionalUnforgeables(InterfaceType)) {
            if (std.mem.eql(u8, decl_name, interface_name)) {
                V8Interface(InterfaceType).installConditionalUnforgeables(isolate, context, object);
                return;
            }
        }
    }
}

pub fn createTemplateOnDemandByName(
    interface_name: []const u8,
    isolate: *v8.Isolate,
) ?*v8.FunctionTemplate {
    @setEvalBranchQuota(10_000_000);
    const template_registry = @import("template_registry.zig");
    const iface_decls = zig017DeclsOf(@typeInfo(interfaces).@"struct".decl_names);

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

            // Debug: trace on-demand template creation
            if (comptime std.mem.eql(u8, decl.name, "Window") or std.mem.eql(u8, decl.name, "EventTarget")) {
                log.debug("[createTemplateOnDemandByName] Creating template for: {s}\n", .{interface_name});
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

/// The interface object named `interface_name` in `context`, fully set up
/// (V8Interface.materializeInterfaceObject), for the lazy data property a child
/// realm's global carries until script first reads it. The caller owns the
/// returned handle.
pub fn materializeInterfaceObjectByName(
    interface_name: []const u8,
    isolate: *v8.Isolate,
    context: *v8.Context,
) ?*v8.Function {
    @setEvalBranchQuota(10_000_000);
    // A global's construct by its name (an interface object or an alias of
    // one; never asked for a factory's name): O(1).
    if (constructNamed(interface_name)) |index| return makeConstruct(index, isolate, context);
    // An interface with no global property - a [LegacyNamespace] one - whose
    // wrapper still needs its interface object built.
    const iface_decls = zig017DeclsOf(@typeInfo(interfaces).@"struct".decl_names);

    inline for (iface_decls) |decl| {
        // At comptime: a skipped interface's binding is never analysed, and
        // some cannot be.
        if (comptime shouldSkipInterface(decl.name)) continue;
        const InterfaceType = @field(interfaces, decl.name);
        if (@typeInfo(InterfaceType) != .@"struct") continue;
        if (!@hasDecl(InterfaceType, "Meta")) continue;
        if (@hasDecl(InterfaceType.Meta, "is_mixin")) {
            if (InterfaceType.Meta.is_mixin) continue;
        }
        if (std.mem.eql(u8, decl.name, interface_name) or legacyWindowAliasMatches(InterfaceType, interface_name)) {
            return V8Interface(InterfaceType).materializeInterfaceObject(isolate, context, decl.name);
        }
    }
    return null;
}

/// Resolve an installed alias through the per-context interface object, not
/// a read of the target's global property: script may have deleted or replaced
/// that property before its first read of the alias. Keep the identifier-list
/// aliases out of this existing surface pending the geometry/SVG spec ruling.
fn legacyWindowAliasMatches(comptime Interface: type, name: []const u8) bool {
    if (comptime !@hasDecl(Interface.Meta, "extended_attributes")) return false;
    inline for (Interface.Meta.extended_attributes) |attr| {
        if (comptime std.mem.eql(u8, attr.name, "LegacyWindowAlias") and
            @hasField(@TypeOf(attr.value), "identifier"))
        {
            if (std.mem.eql(u8, name, attr.value.identifier)) return true;
        }
    }
    return false;
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

    const decls = zig017DeclsOf(@typeInfo(interfaces).@"struct".decl_names);

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

// Zig 0.17 compat: Zig 0.17's @typeInfo is struct-of-arrays. These rebuild 0.16's lists
// (comptime-only element types, so every call is evaluated at comptime).
const Zig017Param = struct { type: ?type, is_generic: bool, is_noalias: bool };
fn zig017ParamsOf(comptime info: @import("std").builtin.Type.Fn) [info.param_types.len]Zig017Param {
    var out: [info.param_types.len]Zig017Param = undefined;
    for (info.param_types, info.param_attrs, 0..) |t, a, i| out[i] = .{ .type = t, .is_generic = t == null, .is_noalias = a.@"noalias" };
    return out;
}
const Zig017Decl = struct { name: [:0]const u8, comptime_only: type = void };
fn zig017DeclsOf(comptime names: []const [:0]const u8) [names.len]Zig017Decl {
    var out: [names.len]Zig017Decl = undefined;
    for (names, 0..) |n, i| out[i] = .{ .name = n };
    return out;
}
