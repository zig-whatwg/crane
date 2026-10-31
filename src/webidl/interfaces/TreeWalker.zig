//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TreeWalkerImpl = @import("impls").TreeWalker;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Node = @import("interfaces").Node;
const NodeFilter = @import("interfaces").NodeFilter;

pub const TreeWalker = struct {
    pub const Meta = struct {
        pub const name = "TreeWalker";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "root", "get_root", null },
            .{ "whatToShow", "get_whatToShow", null },
            .{ "filter", "get_filter", null },
            .{ "currentNode", "get_currentNode", "set_currentNode" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "parentNode", "call_parentNode", 0 },
            .{ "firstChild", "call_firstChild", 0 },
            .{ "lastChild", "call_lastChild", 0 },
            .{ "previousSibling", "call_previousSibling", 0 },
            .{ "nextSibling", "call_nextSibling", 0 },
            .{ "previousNode", "call_previousNode", 0 },
            .{ "nextNode", "call_nextNode", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "parentNode",
            "firstChild",
            "lastChild",
            "previousSibling",
            "nextSibling",
            "previousNode",
            "nextNode",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "root", "get_root", null },
            .{ "whatToShow", "get_whatToShow", null },
            .{ "filter", "get_filter", null },
            .{ "currentNode", "get_currentNode", "set_currentNode" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            root: *runtime.Instance = undefined,
            whatToShow: u32 = undefined,
            filter: ?runtime.JSValue = null,
            currentNode: *runtime.Instance = undefined,
            cached_root: ?*runtime.Instance = null,
            _internal: ?*TreeWalkerImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_currentNode = &get_currentNode,
        .get_filter = &get_filter,
        .get_root = &get_root,
        .get_whatToShow = &get_whatToShow,

        .set_currentNode = &set_currentNode,

        .call_firstChild = &call_firstChild,
        .call_lastChild = &call_lastChild,
        .call_nextNode = &call_nextNode,
        .call_nextSibling = &call_nextSibling,
        .call_parentNode = &call_parentNode,
        .call_previousNode = &call_previousNode,
        .call_previousSibling = &call_previousSibling,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("TreeWalker has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(TreeWalkerImpl, "init") and @hasDecl(TreeWalkerImpl, "initOwn")) @compileError("TreeWalkerImpl defines both init and initOwn");
        if (comptime @hasDecl(TreeWalkerImpl, "init")) return TreeWalkerImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(TreeWalkerImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try TreeWalkerImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(TreeWalkerImpl, "init")) return false;
        if (comptime @hasDecl(TreeWalkerImpl, "construction_args")) {
            inline for (TreeWalkerImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return false;
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(TreeWalkerImpl, "deinit") and @hasDecl(TreeWalkerImpl, "deinitOwn")) @compileError("TreeWalkerImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(TreeWalkerImpl, "deinit")) return TreeWalkerImpl.deinit(instance);
        if (comptime @hasDecl(TreeWalkerImpl, "deinitOwn")) TreeWalkerImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "TreeWalker")) {
            if (comptime @hasDecl(impls.TreeWalker, "installHooks")) impls.TreeWalker.installHooks();
        }
    }

    /// Extended attributes: [SameObject]
    pub fn get_root(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_root) |cached| {
            return cached;
        }
        const value = try TreeWalkerImpl.get_root(instance);
        state.own.cached_root = value;
        @import("dom").same_object_cache.made(instance, value, "root");
        return value;
    }

    pub fn get_whatToShow(instance: *runtime.Instance) anyerror!u32 {
        return try TreeWalkerImpl.get_whatToShow(instance);
    }

    pub fn get_filter(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try TreeWalkerImpl.get_filter(instance);
    }

    pub fn get_currentNode(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try TreeWalkerImpl.get_currentNode(instance);
    }

    pub fn set_currentNode(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try TreeWalkerImpl.set_currentNode(instance, value);
    }

    pub fn call_firstChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try TreeWalkerImpl.call_firstChild(instance);
    }

    pub fn call_previousSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try TreeWalkerImpl.call_previousSibling(instance);
    }

    pub fn call_lastChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try TreeWalkerImpl.call_lastChild(instance);
    }

    pub fn call_nextNode(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try TreeWalkerImpl.call_nextNode(instance);
    }

    pub fn call_previousNode(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try TreeWalkerImpl.call_previousNode(instance);
    }

    pub fn call_nextSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try TreeWalkerImpl.call_nextSibling(instance);
    }

    pub fn call_parentNode(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try TreeWalkerImpl.call_parentNode(instance);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "set_currentNode", 0, "Node" },
    };
};
