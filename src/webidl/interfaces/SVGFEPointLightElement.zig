//! Generated from: filter-effects.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGFEPointLightElementImpl = @import("impls").SVGFEPointLightElement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const SVGElement = @import("interfaces").SVGElement;
const DOMStringMap = @import("interfaces").DOMStringMap;
const CSSOMString = @import("typedefs").CSSOMString;
const HTMLCollection = @import("interfaces").HTMLCollection;
const ViewTransitionUpdateCallbackOrStartViewTransitionOptions = @import("typedefs").ViewTransitionUpdateCallbackOrStartViewTransitionOptions;
const GeometryNode = @import("typedefs").GeometryNode;
const NamedNodeMap = @import("interfaces").NamedNodeMap;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const USVString = @import("typedefs").USVString;
const Element = @import("interfaces").Element;
const CheckVisibilityOptions = @import("dictionaries").CheckVisibilityOptions;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const FocusableAreasOption = @import("dictionaries").FocusableAreasOption;
const EventListenerOptionsOrBoolean = @import("typedefs").EventListenerOptionsOrBoolean;
const TrustedHTMLOrDOMString = @import("typedefs").TrustedHTMLOrDOMString;
const EventListener = @import("interfaces").EventListener;
const CSSStyleProperties = @import("interfaces").CSSStyleProperties;
const WritableStream = @import("interfaces").WritableStream;
const CSSPseudoElement = @import("interfaces").CSSPseudoElement;
const SetHTMLOptions = @import("dictionaries").SetHTMLOptions;
const Node = @import("interfaces").Node;
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const Range = @import("interfaces").Range;
const Animation = @import("interfaces").Animation;
const Event = @import("interfaces").Event;
const FocusOptions = @import("dictionaries").FocusOptions;
const TrustedTypeOrDOMString = @import("typedefs").TrustedTypeOrDOMString;
const DOMString = @import("typedefs").DOMString;
const DOMRectList = @import("interfaces").DOMRectList;
const Document = @import("interfaces").Document;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const SVGAnimatedNumber = @import("interfaces").SVGAnimatedNumber;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const ScrollToOptions = @import("dictionaries").ScrollToOptions;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const DOMQuad = @import("interfaces").DOMQuad;
const HTMLSlotElement = @import("interfaces").HTMLSlotElement;
const SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions = @import("typedefs").SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions;
const StylePropertyMapReadOnly = @import("interfaces").StylePropertyMapReadOnly;
const DOMTokenList = @import("interfaces").DOMTokenList;
const DOMRect = @import("interfaces").DOMRect;
const ViewTransition = @import("interfaces").ViewTransition;
const SpatialNavigationSearchOptions = @import("dictionaries").SpatialNavigationSearchOptions;
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;
const EventHandler = @import("typedefs").EventHandler;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const SVGAnimatedString = @import("interfaces").SVGAnimatedString;
const UnrestrictedDoubleOrKeyframeAnimationOptions = @import("typedefs").UnrestrictedDoubleOrKeyframeAnimationOptions;
const SpatialNavigationDirection = @import("enums").SpatialNavigationDirection;
const StylePropertyMap = @import("interfaces").StylePropertyMap;
const ShadowRoot = @import("interfaces").ShadowRoot;
const Attr = @import("interfaces").Attr;
const TrustedHTML = @import("interfaces").TrustedHTML;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const NodeList = @import("interfaces").NodeList;
const FullscreenOptions = @import("dictionaries").FullscreenOptions;
const AriaNotificationOptions = @import("dictionaries").AriaNotificationOptions;
const Observable = @import("interfaces").Observable;
const DOMPoint = @import("interfaces").DOMPoint;
const BooleanOrScrollIntoViewOptions = @import("typedefs").BooleanOrScrollIntoViewOptions;
const PointerLockOptions = @import("dictionaries").PointerLockOptions;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const ShadowRootInit = @import("dictionaries").ShadowRootInit;
const SVGSVGElement = @import("interfaces").SVGSVGElement;
const AddEventListenerOptionsOrBoolean = @import("typedefs").AddEventListenerOptionsOrBoolean;

pub const SVGFEPointLightElement = struct {
    pub const Meta = struct {
        pub const name = "SVGFEPointLightElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = SVGElement.State;
        pub const ParentInterface = SVGElement;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "x", "get_x", null },
            .{ "y", "get_y", null },
            .{ "z", "get_z", null },
        };

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
            "hasAttributes",
            "getAttributeNames",
            "getAttribute",
            "getAttributeNS",
            "setAttribute",
            "setAttributeNS",
            "removeAttribute",
            "removeAttributeNS",
            "toggleAttribute",
            "hasAttribute",
            "hasAttributeNS",
            "getAttributeNode",
            "getAttributeNodeNS",
            "setAttributeNode",
            "setAttributeNodeNS",
            "removeAttributeNode",
            "attachShadow",
            "closest",
            "matches",
            "webkitMatchesSelector",
            "getElementsByTagName",
            "getElementsByTagNameNS",
            "getElementsByClassName",
            "insertAdjacentElement",
            "insertAdjacentText",
            "getSpatialNavigationContainer",
            "focusableAreas",
            "spatialNavigationSearch",
            "pseudo",
            "computedStyleMap",
            "startViewTransition",
            "getClientRects",
            "getBoundingClientRect",
            "checkVisibility",
            "scrollIntoView",
            "scroll",
            "scroll",
            "scrollTo",
            "scrollTo",
            "scrollBy",
            "scrollBy",
            "requestFullscreen",
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
            "insertAdjacentHTML",
            "setPointerCapture",
            "releasePointerCapture",
            "hasPointerCapture",
            "requestPointerLock",
            "getRegionFlowRanges",
            "getBoxQuads",
            "convertQuadFromNode",
            "convertRectFromNode",
            "convertPointFromNode",
            "prepend",
            "append",
            "replaceChildren",
            "moveBefore",
            "querySelector",
            "querySelectorAll",
            "beforeHTML",
            "afterHTML",
            "replaceWithHTML",
            "streamBeforeHTML",
            "streamAfterHTML",
            "streamReplaceWithHTML",
            "beforeHTMLUnsafe",
            "afterHTMLUnsafe",
            "replaceWithHTMLUnsafe",
            "streamBeforeHTMLUnsafe",
            "streamAfterHTMLUnsafe",
            "streamReplaceWithHTMLUnsafe",
            "before",
            "after",
            "replaceWith",
            "remove",
            "ariaNotify",
            "animate",
            "getAnimations",
            "focus",
            "blur",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "x", "get_x", null },
            .{ "y", "get_y", null },
            .{ "z", "get_z", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*SVGFEPointLightElementImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_x = &get_x,
        .get_y = &get_y,
        .get_z = &get_z,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("SVGFEPointLightElement has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(SVGFEPointLightElementImpl, "init") and @hasDecl(SVGFEPointLightElementImpl, "initOwn")) @compileError("SVGFEPointLightElementImpl defines both init and initOwn");
        if (comptime @hasDecl(SVGFEPointLightElementImpl, "init")) return SVGFEPointLightElementImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(SVGFEPointLightElementImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try SVGFEPointLightElementImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SVGFEPointLightElementImpl, "init")) return false;
        if (comptime @hasDecl(SVGFEPointLightElementImpl, "construction_args")) {
            inline for (SVGFEPointLightElementImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(SVGFEPointLightElementImpl, "deinit") and @hasDecl(SVGFEPointLightElementImpl, "deinitOwn")) @compileError("SVGFEPointLightElementImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SVGFEPointLightElementImpl, "deinit")) return SVGFEPointLightElementImpl.deinit(instance);
        if (comptime @hasDecl(SVGFEPointLightElementImpl, "deinitOwn")) SVGFEPointLightElementImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SVGFEPointLightElement")) {
            if (comptime @hasDecl(impls.SVGFEPointLightElement, "installHooks")) impls.SVGFEPointLightElement.installHooks();
        }
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEPointLightElementImpl.get_x(instance);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEPointLightElementImpl.get_y(instance);
    }

    pub fn get_z(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEPointLightElementImpl.get_z(instance);
    }
};
