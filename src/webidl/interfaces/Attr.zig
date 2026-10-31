//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AttrImpl = @import("impls").Attr;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Node = @import("interfaces").Node;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Document = @import("interfaces").Document;
const NodeList = @import("interfaces").NodeList;
const USVString = @import("typedefs").USVString;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const Element = @import("interfaces").Element;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const DOMString = @import("typedefs").DOMString;

pub const Attr = struct {
    pub const Meta = struct {
        pub const name = "Attr";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Node.State;
        pub const ParentInterface = Node;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "namespaceURI", "get_namespaceURI", null },
            .{ "prefix", "get_prefix", null },
            .{ "localName", "get_localName", null },
            .{ "name", "get_name", null },
            .{ "value", "get_value", "set_value" },
            .{ "ownerElement", "get_ownerElement", null },
            .{ "specified", "get_specified", null },
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
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "namespaceURI", "get_namespaceURI", null },
            .{ "prefix", "get_prefix", null },
            .{ "localName", "get_localName", null },
            .{ "name", "get_name", null },
            .{ "value", "get_value", "set_value" },
            .{ "ownerElement", "get_ownerElement", null },
            .{ "specified", "get_specified", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            namespaceURI: ?runtime.DOMString = null,
            prefix: ?runtime.DOMString = null,
            localName: runtime.DOMString = undefined,
            name: runtime.DOMString = undefined,
            value: runtime.DOMString = undefined,
            ownerElement: ?*runtime.Instance = null,
            specified: bool = undefined,
            _internal: ?*AttrImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_localName = &get_localName,
        .get_name = &get_name,
        .get_namespaceURI = &get_namespaceURI,
        .get_ownerElement = &get_ownerElement,
        .get_prefix = &get_prefix,
        .get_specified = &get_specified,
        .get_value = &get_value,

        .set_value = &set_value,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("Attr has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(AttrImpl, "init") and @hasDecl(AttrImpl, "initOwn")) @compileError("AttrImpl defines both init and initOwn");
        if (comptime @hasDecl(AttrImpl, "init")) return AttrImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(AttrImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try AttrImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(AttrImpl, "init")) return false;
        if (comptime @hasDecl(AttrImpl, "construction_args")) {
            inline for (AttrImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(AttrImpl, "deinit") and @hasDecl(AttrImpl, "deinitOwn")) @compileError("AttrImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(AttrImpl, "deinit")) return AttrImpl.deinit(instance);
        if (comptime @hasDecl(AttrImpl, "deinitOwn")) AttrImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Attr")) {
            if (comptime @hasDecl(impls.Attr, "installHooks")) impls.Attr.installHooks();
        }
    }

    pub fn get_namespaceURI(instance: *runtime.Instance) anyerror!?runtime.DOMString {
        return try AttrImpl.get_namespaceURI(instance);
    }

    pub fn get_prefix(instance: *runtime.Instance) anyerror!?runtime.DOMString {
        return try AttrImpl.get_prefix(instance);
    }

    pub fn get_localName(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try AttrImpl.get_localName(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try AttrImpl.get_name(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_value(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try AttrImpl.get_value(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_value(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try AttrImpl.set_value(instance, value);
    }

    pub fn get_ownerElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try AttrImpl.get_ownerElement(instance);
    }

    pub fn get_specified(instance: *runtime.Instance) anyerror!bool {
        return try AttrImpl.get_specified(instance);
    }

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "set_value",
    };
};
