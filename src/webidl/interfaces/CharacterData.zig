//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CharacterDataImpl = @import("impls").CharacterData;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Node = @import("interfaces").Node;
const NonDocumentTypeChildNode = @import("mixins").NonDocumentTypeChildNode;
const ChildNode = @import("mixins").ChildNode;
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

pub const CharacterData = struct {
    pub const Meta = struct {
        pub const name = "CharacterData";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Node.State;
        pub const ParentInterface = Node;
        pub const MixinTypes = &.{
            NonDocumentTypeChildNode,
            ChildNode,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "data", "get_data", "set_data" },
            .{ "length", "get_length", null },
            .{ "previousElementSibling", "get_previousElementSibling", null },
            .{ "nextElementSibling", "get_nextElementSibling", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "substringData", "call_substringData", 2 },
            .{ "appendData", "call_appendData", 1 },
            .{ "insertData", "call_insertData", 2 },
            .{ "deleteData", "call_deleteData", 2 },
            .{ "replaceData", "call_replaceData", 3 },
            .{ "before", "call_before", 0 },
            .{ "after", "call_after", 0 },
            .{ "replaceWith", "call_replaceWith", 0 },
            .{ "remove", "call_remove", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "substringData",
            "appendData",
            "insertData",
            "deleteData",
            "replaceData",
            "before",
            "after",
            "replaceWith",
            "remove",
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
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "data", "get_data", "set_data" },
            .{ "length", "get_length", null },
            .{ "previousElementSibling", "get_previousElementSibling", null },
            .{ "nextElementSibling", "get_nextElementSibling", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// Members marked with [Unscopable] extended attribute
        pub const unscopables = .{
            "before",
            "after",
            "replaceWith",
            "remove",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            data: typedefs.DOMString = undefined,
            length: u32 = undefined,
            previousElementSibling: ?*runtime.Instance = null,
            nextElementSibling: ?*runtime.Instance = null,
            _internal: ?*CharacterDataImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_data = &get_data,
        .get_length = &get_length,
        .get_nextElementSibling = &get_nextElementSibling,
        .get_previousElementSibling = &get_previousElementSibling,

        .set_data = &set_data,

        .call_after = &call_after,
        .call_appendData = &call_appendData,
        .call_before = &call_before,
        .call_deleteData = &call_deleteData,
        .call_insertData = &call_insertData,
        .call_remove = &call_remove,
        .call_replaceData = &call_replaceData,
        .call_replaceWith = &call_replaceWith,
        .call_substringData = &call_substringData,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("CharacterData has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(CharacterDataImpl, "init") and @hasDecl(CharacterDataImpl, "initOwn")) @compileError("CharacterDataImpl defines both init and initOwn");
        if (comptime @hasDecl(CharacterDataImpl, "init")) return CharacterDataImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(CharacterDataImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try CharacterDataImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CharacterDataImpl, "init")) return false;
        if (comptime @hasDecl(CharacterDataImpl, "construction_args")) {
            inline for (CharacterDataImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(CharacterDataImpl, "deinit") and @hasDecl(CharacterDataImpl, "deinitOwn")) @compileError("CharacterDataImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CharacterDataImpl, "deinit")) return CharacterDataImpl.deinit(instance);
        if (comptime @hasDecl(CharacterDataImpl, "deinitOwn")) CharacterDataImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CharacterData")) {
            if (comptime @hasDecl(impls.CharacterData, "installHooks")) impls.CharacterData.installHooks();
        }
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_data(instance: *runtime.Instance) anyerror!DOMString {
        return try CharacterDataImpl.get_data(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_data(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CharacterDataImpl.set_data(instance, value);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try CharacterDataImpl.get_length(instance);
    }

    pub const get_previousElementSibling = mixins.NonDocumentTypeChildNode.get_previousElementSibling;

    pub const get_nextElementSibling = mixins.NonDocumentTypeChildNode.get_nextElementSibling;

    pub fn call_replaceData(instance: *runtime.Instance, offset: u32, count: u32, data: DOMString) anyerror!void {
        return try CharacterDataImpl.call_replaceData(instance, offset, count, data);
    }

    pub const call_before = mixins.ChildNode.call_before;

    pub fn call_deleteData(instance: *runtime.Instance, offset: u32, count: u32) anyerror!void {
        return try CharacterDataImpl.call_deleteData(instance, offset, count);
    }

    pub const call_remove = mixins.ChildNode.call_remove;

    pub const call_after = mixins.ChildNode.call_after;

    pub fn call_appendData(instance: *runtime.Instance, data: DOMString) anyerror!void {
        return try CharacterDataImpl.call_appendData(instance, data);
    }

    pub fn call_substringData(instance: *runtime.Instance, offset: u32, count: u32) anyerror!DOMString {
        return try CharacterDataImpl.call_substringData(instance, offset, count);
    }

    pub fn call_insertData(instance: *runtime.Instance, offset: u32, data: DOMString) anyerror!void {
        return try CharacterDataImpl.call_insertData(instance, offset, data);
    }

    pub const call_replaceWith = mixins.ChildNode.call_replaceWith;

    /// WebIDL [LegacyNullToEmptyString]: the values null converts to "" for
    /// (bit i = argument i; an attribute setter's value is bit 0).
    pub const legacy_null_to_empty = .{
        .{ "set_data", 0b1 },
    };

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "call_before",
        "call_remove",
        "call_after",
        "call_replaceWith",
    };
};
