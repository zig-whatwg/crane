//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XMLDocumentImpl = @import("impls").XMLDocument;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Document = @import("interfaces").Document;
const HTMLOrSVGScriptElement = @import("typedefs").HTMLOrSVGScriptElement;
const ModelContext = @import("interfaces").ModelContext;
const HTMLCollection = @import("interfaces").HTMLCollection;
const HTMLHeadElement = @import("interfaces").HTMLHeadElement;
const NodeIterator = @import("interfaces").NodeIterator;
const FontMetrics = @import("interfaces").FontMetrics;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const Text = @import("interfaces").Text;
const GeometryNode = @import("typedefs").GeometryNode;
const USVString = @import("typedefs").USVString;
const Element = @import("interfaces").Element;
const XPathExpression = @import("interfaces").XPathExpression;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const XPathResult = @import("interfaces").XPathResult;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const TrustedHTMLOrDOMString = @import("typedefs").TrustedHTMLOrDOMString;
const Location = @import("interfaces").Location;
const EventListener = @import("interfaces").EventListener;
const StyleSheetList = @import("interfaces").StyleSheetList;
const FragmentDirective = @import("interfaces").FragmentDirective;
const Comment = @import("interfaces").Comment;
const NamedFlowMap = @import("interfaces").NamedFlowMap;
const SetHTMLOptions = @import("dictionaries").SetHTMLOptions;
const ViewTransitionUpdateCallback = @import("callbacks").ViewTransitionUpdateCallback;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const ImportNodeOptions = @import("dictionaries").ImportNodeOptions;
const DOMImplementation = @import("interfaces").DOMImplementation;
const Node = @import("interfaces").Node;
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const Range = @import("interfaces").Range;
const Animation = @import("interfaces").Animation;
const Event = @import("interfaces").Event;
const PermissionsPolicy = @import("interfaces").PermissionsPolicy;
const XPathNSResolver = @import("interfaces").XPathNSResolver;
const DocumentType = @import("interfaces").DocumentType;
const HTMLAllCollection = @import("interfaces").HTMLAllCollection;
const DOMString = @import("typedefs").DOMString;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DocumentFragment = @import("interfaces").DocumentFragment;
const ParseHTMLUnsafeOptions = @import("dictionaries").ParseHTMLUnsafeOptions;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const FontFaceSet = @import("interfaces").FontFaceSet;
const DOMQuad = @import("interfaces").DOMQuad;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const StartViewTransitionOptions = @import("dictionaries").StartViewTransitionOptions;
const StylePropertyMapReadOnly = @import("interfaces").StylePropertyMapReadOnly;
const CDATASection = @import("interfaces").CDATASection;
const DocumentTimeline = @import("interfaces").DocumentTimeline;
const ViewTransition = @import("interfaces").ViewTransition;
const TreeWalker = @import("interfaces").TreeWalker;
const EventHandler = @import("typedefs").EventHandler;
const DocumentReadyState = @import("enums").DocumentReadyState;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const HTMLElement = @import("interfaces").HTMLElement;
const WindowProxy = @import("typedefs").WindowProxy;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const Attr = @import("interfaces").Attr;
const NodeList = @import("interfaces").NodeList;
const AriaNotificationOptions = @import("dictionaries").AriaNotificationOptions;
const Observable = @import("interfaces").Observable;
const ElementCreationOptions = @import("dictionaries").ElementCreationOptions;
const DOMPoint = @import("interfaces").DOMPoint;
const CaretPosition = @import("interfaces").CaretPosition;
const CaretPositionFromPointOptions = @import("dictionaries").CaretPositionFromPointOptions;
const ProcessingInstruction = @import("interfaces").ProcessingInstruction;
const SVGSVGElement = @import("interfaces").SVGSVGElement;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const Selection = @import("interfaces").Selection;
const DocumentVisibilityState = @import("enums").DocumentVisibilityState;
const NodeFilter = @import("interfaces").NodeFilter;

pub const XMLDocument = struct {
    pub const Meta = struct {
        pub const name = "XMLDocument";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Document.State;
        pub const ParentInterface = Document;
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
            "getElementsByTagName",
            "getElementsByTagNameNS",
            "getElementsByClassName",
            "createElement",
            "createElementNS",
            "createDocumentFragment",
            "createTextNode",
            "createCDATASection",
            "createComment",
            "createProcessingInstruction",
            "importNode",
            "adoptNode",
            "createAttribute",
            "createAttributeNS",
            "createEvent",
            "createRange",
            "createNodeIterator",
            "createTreeWalker",
            "startViewTransition",
            "elementFromPoint",
            "elementsFromPoint",
            "caretPositionFromPoint",
            "execCommand",
            "measureElement",
            "measureText",
            "exitFullscreen",
            "parseHTMLUnsafe",
            "parseHTML",
            "getElementsByName",
            "open",
            "open",
            "close",
            "write",
            "writeln",
            "hasFocus",
            "queryCommandEnabled",
            "queryCommandIndeterm",
            "queryCommandState",
            "queryCommandSupported",
            "queryCommandValue",
            "clear",
            "captureEvents",
            "releaseEvents",
            "exitPictureInPicture",
            "exitPointerLock",
            "hasUnpartitionedCookieAccess",
            "getSelection",
            "hasStorageAccess",
            "requestStorageAccess",
            "hasPrivateToken",
            "hasRedemptionRecord",
            "getBoxQuads",
            "convertQuadFromNode",
            "convertRectFromNode",
            "convertPointFromNode",
            "getElementById",
            "getAnimations",
            "prepend",
            "append",
            "replaceChildren",
            "moveBefore",
            "querySelector",
            "querySelectorAll",
            "createExpression",
            "createNSResolver",
            "evaluate",
            "ariaNotify",
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
            _internal: ?*XMLDocumentImpl.InternalState = null,
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
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("XMLDocument has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(XMLDocumentImpl, "init") and @hasDecl(XMLDocumentImpl, "initOwn")) @compileError("XMLDocumentImpl defines both init and initOwn");
        if (comptime @hasDecl(XMLDocumentImpl, "init")) return XMLDocumentImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(XMLDocumentImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try XMLDocumentImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XMLDocumentImpl, "init")) return false;
        if (comptime @hasDecl(XMLDocumentImpl, "construction_args")) {
            inline for (XMLDocumentImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(XMLDocumentImpl, "deinit") and @hasDecl(XMLDocumentImpl, "deinitOwn")) @compileError("XMLDocumentImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(XMLDocumentImpl, "deinit")) return XMLDocumentImpl.deinit(instance);
        if (comptime @hasDecl(XMLDocumentImpl, "deinitOwn")) XMLDocumentImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XMLDocument")) {
            if (comptime @hasDecl(impls.XMLDocument, "installHooks")) impls.XMLDocument.installHooks();
        }
    }
};
