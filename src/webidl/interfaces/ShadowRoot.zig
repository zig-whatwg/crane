//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ShadowRootImpl = @import("impls").ShadowRoot;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DocumentFragment = @import("interfaces").DocumentFragment;
const DocumentOrShadowRoot = @import("mixins").DocumentOrShadowRoot;
const Document = @import("interfaces").Document;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const HTMLCollection = @import("interfaces").HTMLCollection;
const SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions = @import("typedefs").SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions;
const USVString = @import("typedefs").USVString;
const Element = @import("interfaces").Element;
const ShadowRootMode = @import("enums").ShadowRootMode;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const TrustedHTMLOrDOMString = @import("typedefs").TrustedHTMLOrDOMString;
const EventListener = @import("interfaces").EventListener;
const StyleSheetList = @import("interfaces").StyleSheetList;
const WritableStream = @import("interfaces").WritableStream;
const EventHandler = @import("typedefs").EventHandler;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const SetHTMLOptions = @import("dictionaries").SetHTMLOptions;
const TrustedHTML = @import("interfaces").TrustedHTML;
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const Animation = @import("interfaces").Animation;
const Node = @import("interfaces").Node;
const NodeList = @import("interfaces").NodeList;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const SlotAssignmentMode = @import("enums").SlotAssignmentMode;
const DOMString = @import("typedefs").DOMString;

pub const ShadowRoot = struct {
    pub const Meta = struct {
        pub const name = "ShadowRoot";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = DocumentFragment.State;
        pub const ParentInterface = DocumentFragment;
        pub const MixinTypes = &.{
            DocumentOrShadowRoot,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "mode", "get_mode", null },
            .{ "delegatesFocus", "get_delegatesFocus", null },
            .{ "serializable", "get_serializable", null },
            .{ "slotAssignment", "get_slotAssignment", null },
            .{ "clonable", "get_clonable", null },
            .{ "host", "get_host", null },
            .{ "onslotchange", "get_onslotchange", "set_onslotchange" },
            .{ "innerHTML", "get_innerHTML", "set_innerHTML" },
            .{ "customElementRegistry", "get_customElementRegistry", null },
            .{ "styleSheets", "get_styleSheets", null },
            .{ "adoptedStyleSheets", "get_adoptedStyleSheets", "set_adoptedStyleSheets" },
            .{ "fullscreenElement", "get_fullscreenElement", "set_fullscreenElement" },
            .{ "activeElement", "get_activeElement", null },
            .{ "pictureInPictureElement", "get_pictureInPictureElement", null },
            .{ "pointerLockElement", "get_pointerLockElement", null },
        };

        /// [SameObject] attributes whose child the owner keeps (in its State, its rare
        /// data or its impl): the binding ties the child's wrapper to the owner's.
        pub const same_object_attributes = .{
            "styleSheets",
        };

        /// [LegacyLenientSetter] attributes: readonly with no-op setters
        /// Setters silently do nothing (don't throw, don't modify)
        pub const lenient_setter_attributes = .{
            "fullscreenElement",
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "elementFromPoint", "call_elementFromPoint", 2 },
            .{ "elementsFromPoint", "call_elementsFromPoint", 2 },
            .{ "appendHTML", "call_appendHTML", 1 },
            .{ "prependHTML", "call_prependHTML", 1 },
            .{ "streamHTML", "call_streamHTML", 0 },
            .{ "streamAppendHTML", "call_streamAppendHTML", 0 },
            .{ "streamPrependHTML", "call_streamPrependHTML", 0 },
            .{ "setHTMLUnsafe", "call_setHTMLUnsafe", 1 },
            .{ "appendHTMLUnsafe", "call_appendHTMLUnsafe", 1 },
            .{ "prependHTMLUnsafe", "call_prependHTMLUnsafe", 1 },
            .{ "streamHTMLUnsafe", "call_streamHTMLUnsafe", 0 },
            .{ "streamAppendHTMLUnsafe", "call_streamAppendHTMLUnsafe", 0 },
            .{ "streamPrependHTMLUnsafe", "call_streamPrependHTMLUnsafe", 0 },
            .{ "setHTML", "call_setHTML", 1 },
            .{ "getHTML", "call_getHTML", 0 },
            .{ "getAnimations", "call_getAnimations", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "elementFromPoint",
            "elementsFromPoint",
            "appendHTML",
            "prependHTML",
            "streamHTML",
            "streamAppendHTML",
            "streamPrependHTML",
            "setHTMLUnsafe",
            "appendHTMLUnsafe",
            "prependHTMLUnsafe",
            "streamHTMLUnsafe",
            "streamAppendHTMLUnsafe",
            "streamPrependHTMLUnsafe",
            "setHTML",
            "getHTML",
            "getAnimations",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "getRootNode",
            "hasChildNodes",
            "normalize",
            "cloneNode",
            "isEqualNode",
            "isSameNode",
            "compareDocumentPosition",
            "contains",
            "lookupPrefix",
            "lookupNamespaceURI",
            "isDefaultNamespace",
            "insertBefore",
            "appendChild",
            "replaceChild",
            "removeChild",
            "getElementById",
            "prepend",
            "append",
            "replaceChildren",
            "moveBefore",
            "querySelector",
            "querySelectorAll",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "mode", "get_mode", null },
            .{ "delegatesFocus", "get_delegatesFocus", null },
            .{ "serializable", "get_serializable", null },
            .{ "slotAssignment", "get_slotAssignment", null },
            .{ "clonable", "get_clonable", null },
            .{ "host", "get_host", null },
            .{ "onslotchange", "get_onslotchange", "set_onslotchange" },
            .{ "innerHTML", "get_innerHTML", "set_innerHTML" },
            .{ "customElementRegistry", "get_customElementRegistry", null },
            .{ "styleSheets", "get_styleSheets", null },
            .{ "adoptedStyleSheets", "get_adoptedStyleSheets", "set_adoptedStyleSheets" },
            .{ "fullscreenElement", "get_fullscreenElement", "set_fullscreenElement" },
            .{ "activeElement", "get_activeElement", null },
            .{ "pictureInPictureElement", "get_pictureInPictureElement", null },
            .{ "pointerLockElement", "get_pointerLockElement", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            cached_styleSheets: ?*runtime.Instance = null,
            _internal: ?*ShadowRootImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_activeElement = &get_activeElement,
        .get_adoptedStyleSheets = &get_adoptedStyleSheets,
        .get_clonable = &get_clonable,
        .get_customElementRegistry = &get_customElementRegistry,
        .get_delegatesFocus = &get_delegatesFocus,
        .get_fullscreenElement = &get_fullscreenElement,
        .get_host = &get_host,
        .get_innerHTML = &get_innerHTML,
        .get_mode = &get_mode,
        .get_onslotchange = &get_onslotchange,
        .get_pictureInPictureElement = &get_pictureInPictureElement,
        .get_pointerLockElement = &get_pointerLockElement,
        .get_serializable = &get_serializable,
        .get_slotAssignment = &get_slotAssignment,
        .get_styleSheets = &get_styleSheets,

        .set_adoptedStyleSheets = &set_adoptedStyleSheets,
        .set_fullscreenElement = &set_fullscreenElement,
        .set_innerHTML = &set_innerHTML,
        .set_onslotchange = &set_onslotchange,

        .call_appendHTML = &call_appendHTML,
        .call_appendHTMLUnsafe = &call_appendHTMLUnsafe,
        .call_elementFromPoint = &call_elementFromPoint,
        .call_elementsFromPoint = &call_elementsFromPoint,
        .call_getAnimations = &call_getAnimations,
        .call_getHTML = &call_getHTML,
        .call_prependHTML = &call_prependHTML,
        .call_prependHTMLUnsafe = &call_prependHTMLUnsafe,
        .call_setHTML = &call_setHTML,
        .call_setHTMLUnsafe = &call_setHTMLUnsafe,
        .call_streamAppendHTML = &call_streamAppendHTML,
        .call_streamAppendHTMLUnsafe = &call_streamAppendHTMLUnsafe,
        .call_streamHTML = &call_streamHTML,
        .call_streamHTMLUnsafe = &call_streamHTMLUnsafe,
        .call_streamPrependHTML = &call_streamPrependHTML,
        .call_streamPrependHTMLUnsafe = &call_streamPrependHTMLUnsafe,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Make a new instance: the construction chain, this interface's State
    /// and vtable.
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return initChain(allocator, State, &vtable, ctx, .{});
    }

    /// Make a new instance with construction arguments: facts given at
    /// construction, as a C++ constructor's parameters. Each field of `args`
    /// must be taken by an impl on the chain (its `construction_args`).
    pub fn initWith(allocator: std.mem.Allocator, ctx: runtime.Context, args: anytype) !*runtime.Instance {
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("ShadowRoot has no construction argument '" ++ field_name ++ "'");
        }
        return initChain(allocator, State, &vtable, ctx, args);
    }

    /// The construction chain for a descendant's State and vtable, for an
    /// impl that still chains by hand.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return initChain(allocator, StateType, vtable_ptr, ctx, .{});
    }

    /// The construction chain: the parent interface's, then the impl's own
    /// steps (`initOwn`), whose failure unwinds the parent's part and frees
    /// the slot. An impl that still defines `init` chains by hand.
    pub inline fn initChain(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
        args: anytype,
    ) !*runtime.Instance {
        if (comptime @hasDecl(ShadowRootImpl, "init") and @hasDecl(ShadowRootImpl, "initOwn")) @compileError("ShadowRootImpl defines both init and initOwn");
        if (comptime @hasDecl(ShadowRootImpl, "init")) return ShadowRootImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(ShadowRootImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try ShadowRootImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ShadowRootImpl, "init")) return false;
        if (comptime @hasDecl(ShadowRootImpl, "construction_args")) {
            inline for (ShadowRootImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return Meta.ParentInterface.takesConstructionArg(name);
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(ShadowRootImpl, "deinit") and @hasDecl(ShadowRootImpl, "deinitOwn")) @compileError("ShadowRootImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(ShadowRootImpl, "deinit")) return ShadowRootImpl.deinit(instance);
        if (comptime @hasDecl(ShadowRootImpl, "deinitOwn")) ShadowRootImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ShadowRoot")) {
            if (comptime @hasDecl(impls.ShadowRoot, "installHooks")) impls.ShadowRoot.installHooks();
        }
    }

    pub fn get_mode(instance: *runtime.Instance) anyerror!ShadowRootMode {
        return try ShadowRootImpl.get_mode(instance);
    }

    pub fn get_delegatesFocus(instance: *runtime.Instance) anyerror!bool {
        return try ShadowRootImpl.get_delegatesFocus(instance);
    }

    pub fn get_serializable(instance: *runtime.Instance) anyerror!bool {
        return try ShadowRootImpl.get_serializable(instance);
    }

    pub fn get_slotAssignment(instance: *runtime.Instance) anyerror!SlotAssignmentMode {
        return try ShadowRootImpl.get_slotAssignment(instance);
    }

    pub fn get_clonable(instance: *runtime.Instance) anyerror!bool {
        return try ShadowRootImpl.get_clonable(instance);
    }

    pub fn get_host(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ShadowRootImpl.get_host(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onslotchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(ShadowRootImpl, "get_onslotchange")) return try ShadowRootImpl.get_onslotchange(instance);
        return event_handlers.value(EventHandler, instance, "onslotchange");
    }

    pub fn set_onslotchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(ShadowRootImpl, "set_onslotchange")) return try ShadowRootImpl.set_onslotchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onslotchange", value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_innerHTML(instance: *runtime.Instance) anyerror!DOMString {
        return try ShadowRootImpl.get_innerHTML(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_innerHTML(instance: *runtime.Instance, value: typedefs.TrustedHTMLOrDOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try ShadowRootImpl.set_innerHTML(instance, value);
    }

    pub fn get_customElementRegistry(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ShadowRootImpl.get_customElementRegistry(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_styleSheets(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_styleSheets) |cached| {
            return cached;
        }
        const value = try ShadowRootImpl.get_styleSheets(instance);
        state.own.cached_styleSheets = value;
        @import("dom").same_object_cache.made(instance, value, "styleSheets");
        return value;
    }

    pub fn get_adoptedStyleSheets(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ShadowRootImpl.get_adoptedStyleSheets(instance);
    }

    pub fn set_adoptedStyleSheets(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        try ShadowRootImpl.set_adoptedStyleSheets(instance, value);
    }

    /// Extended attributes: [LegacyLenientSetter]
    pub fn get_fullscreenElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ShadowRootImpl.get_fullscreenElement(instance);
    }

    /// Extended attributes: [LegacyLenientSetter]
    pub fn set_fullscreenElement(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [LegacyLenientSetter] - Silently do nothing (no-op setter)
        // Per WebIDL §4.3.10: The setter steps are to return.
        _ = instance;
        _ = value;
    }

    pub fn get_activeElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ShadowRootImpl.get_activeElement(instance);
    }

    pub fn get_pictureInPictureElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ShadowRootImpl.get_pictureInPictureElement(instance);
    }

    pub fn get_pointerLockElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ShadowRootImpl.get_pointerLockElement(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_streamAppendHTMLUnsafe(instance: *runtime.Instance, options: webidl.Opt(SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try ShadowRootImpl.call_streamAppendHTMLUnsafe(instance, options);
    }

    pub fn call_elementFromPoint(instance: *runtime.Instance, x: f64, y: f64) anyerror!?*runtime.Instance {
        return try ShadowRootImpl.call_elementFromPoint(instance, x, y);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setHTML(instance: *runtime.Instance, html: runtime.DOMString, options: webidl.Opt(SetHTMLOptions)) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try ShadowRootImpl.call_setHTML(instance, html, options);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_streamHTMLUnsafe(instance: *runtime.Instance, options: webidl.Opt(SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        // [NewObject] - Caller owns the returned object

        const result = ShadowRootImpl.call_streamHTMLUnsafe(instance, options) catch |err| {
            runtime.CEReactions.end(ce_scope);
            return err;
        };
        // A result the reactions freed (its realm ended) is not returned.
        const result_generation = runtime.SlabAllocator.generationOf(result);
        runtime.CEReactions.end(ce_scope);
        if (runtime.SlabAllocator.generationOf(result) != result_generation) return error.InvalidStateError;
        return result;
    }

    pub fn call_elementsFromPoint(instance: *runtime.Instance, x: f64, y: f64) anyerror!runtime.JSValue {
        return try ShadowRootImpl.call_elementsFromPoint(instance, x, y);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_prependHTMLUnsafe(instance: *runtime.Instance, html: TrustedHTMLOrDOMString, options: webidl.Opt(SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try ShadowRootImpl.call_prependHTMLUnsafe(instance, html, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_streamAppendHTML(instance: *runtime.Instance, options: webidl.Opt(SetHTMLOptions)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try ShadowRootImpl.call_streamAppendHTML(instance, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setHTMLUnsafe(instance: *runtime.Instance, html: TrustedHTMLOrDOMString, options: webidl.Opt(SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try ShadowRootImpl.call_setHTMLUnsafe(instance, html, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_streamPrependHTMLUnsafe(instance: *runtime.Instance, options: webidl.Opt(SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try ShadowRootImpl.call_streamPrependHTMLUnsafe(instance, options);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_streamHTML(instance: *runtime.Instance, options: webidl.Opt(SetHTMLOptions)) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        // [NewObject] - Caller owns the returned object

        const result = ShadowRootImpl.call_streamHTML(instance, options) catch |err| {
            runtime.CEReactions.end(ce_scope);
            return err;
        };
        // A result the reactions freed (its realm ended) is not returned.
        const result_generation = runtime.SlabAllocator.generationOf(result);
        runtime.CEReactions.end(ce_scope);
        if (runtime.SlabAllocator.generationOf(result) != result_generation) return error.InvalidStateError;
        return result;
    }

    /// Extended attributes: [CEReactions]
    pub fn call_appendHTMLUnsafe(instance: *runtime.Instance, html: TrustedHTMLOrDOMString, options: webidl.Opt(SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try ShadowRootImpl.call_appendHTMLUnsafe(instance, html, options);
    }

    pub fn call_getHTML(instance: *runtime.Instance, options: webidl.Opt(GetHTMLOptions)) anyerror!runtime.DOMString {
        return try ShadowRootImpl.call_getHTML(instance, options);
    }

    pub fn call_getAnimations(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ShadowRootImpl.call_getAnimations(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_appendHTML(instance: *runtime.Instance, html: runtime.DOMString, options: webidl.Opt(SetHTMLOptions)) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try ShadowRootImpl.call_appendHTML(instance, html, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_prependHTML(instance: *runtime.Instance, html: runtime.DOMString, options: webidl.Opt(SetHTMLOptions)) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try ShadowRootImpl.call_prependHTML(instance, html, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_streamPrependHTML(instance: *runtime.Instance, options: webidl.Opt(SetHTMLOptions)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try ShadowRootImpl.call_streamPrependHTML(instance, options);
    }

    /// WebIDL [LegacyNullToEmptyString]: the values null converts to "" for
    /// (bit i = argument i; an attribute setter's value is bit 0).
    pub const legacy_null_to_empty = .{
        .{ "set_innerHTML", 0b1 },
    };

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{"set_onslotchange"};

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "call_elementFromPoint", 0b11 },
        .{ "call_elementsFromPoint", 0b11 },
    };

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "set_innerHTML",
        "call_setHTML",
        "call_streamHTMLUnsafe",
        "call_prependHTMLUnsafe",
        "call_setHTMLUnsafe",
        "call_streamHTML",
        "call_appendHTMLUnsafe",
        "call_appendHTML",
        "call_prependHTML",
    };
};
