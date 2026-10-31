//! Generated from: SVG.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGUseElementShadowRootImpl = @import("impls").SVGUseElementShadowRoot;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ShadowRoot = @import("interfaces").ShadowRoot;
const Document = @import("interfaces").Document;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const HTMLCollection = @import("interfaces").HTMLCollection;
const USVString = @import("typedefs").USVString;
const Element = @import("interfaces").Element;
const ShadowRootMode = @import("enums").ShadowRootMode;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const TrustedHTMLOrDOMString = @import("typedefs").TrustedHTMLOrDOMString;
const EventListener = @import("interfaces").EventListener;
const StyleSheetList = @import("interfaces").StyleSheetList;
const EventHandler = @import("typedefs").EventHandler;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const SetHTMLOptions = @import("dictionaries").SetHTMLOptions;
const TrustedHTML = @import("interfaces").TrustedHTML;
const Node = @import("interfaces").Node;
const NodeList = @import("interfaces").NodeList;
const SetHTMLUnsafeOptions = @import("dictionaries").SetHTMLUnsafeOptions;
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const Animation = @import("interfaces").Animation;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const DOMString = @import("typedefs").DOMString;
const SlotAssignmentMode = @import("enums").SlotAssignmentMode;

pub const SVGUseElementShadowRoot = struct {
    pub const Meta = struct {
        pub const name = "SVGUseElementShadowRoot";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ShadowRoot.State;
        pub const ParentInterface = ShadowRoot;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

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
            "setHTML",
            "setHTMLUnsafe",
            "getHTML",
            "getAnimations",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*SVGUseElementShadowRootImpl.InternalState = null,
        },
    );

    const delegates = .{
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
            if (comptime !takesConstructionArg(field_name)) @compileError("SVGUseElementShadowRoot has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(SVGUseElementShadowRootImpl, "init") and @hasDecl(SVGUseElementShadowRootImpl, "initOwn")) @compileError("SVGUseElementShadowRootImpl defines both init and initOwn");
        if (comptime @hasDecl(SVGUseElementShadowRootImpl, "init")) return SVGUseElementShadowRootImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(SVGUseElementShadowRootImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try SVGUseElementShadowRootImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SVGUseElementShadowRootImpl, "init")) return false;
        if (comptime @hasDecl(SVGUseElementShadowRootImpl, "construction_args")) {
            inline for (SVGUseElementShadowRootImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(SVGUseElementShadowRootImpl, "deinit") and @hasDecl(SVGUseElementShadowRootImpl, "deinitOwn")) @compileError("SVGUseElementShadowRootImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SVGUseElementShadowRootImpl, "deinit")) return SVGUseElementShadowRootImpl.deinit(instance);
        if (comptime @hasDecl(SVGUseElementShadowRootImpl, "deinitOwn")) SVGUseElementShadowRootImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SVGUseElementShadowRoot")) {
            if (comptime @hasDecl(impls.SVGUseElementShadowRoot, "installHooks")) impls.SVGUseElementShadowRoot.installHooks();
        }
    }
};
