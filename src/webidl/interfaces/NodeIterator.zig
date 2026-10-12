//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NodeIteratorImpl = @import("impls").NodeIterator;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Node = @import("interfaces").Node;
const NodeFilter = @import("interfaces").NodeFilter;

pub const NodeIterator = struct {
    pub const Meta = struct {
        pub const name = "NodeIterator";
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
            .{ "referenceNode", "get_referenceNode", null },
            .{ "pointerBeforeReferenceNode", "get_pointerBeforeReferenceNode", null },
            .{ "whatToShow", "get_whatToShow", null },
            .{ "filter", "get_filter", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "nextNode", "call_nextNode", 0 },
            .{ "previousNode", "call_previousNode", 0 },
            .{ "detach", "call_detach", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "nextNode",
            "previousNode",
            "detach",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "root", "get_root", null },
            .{ "referenceNode", "get_referenceNode", null },
            .{ "pointerBeforeReferenceNode", "get_pointerBeforeReferenceNode", null },
            .{ "whatToShow", "get_whatToShow", null },
            .{ "filter", "get_filter", null },
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
            referenceNode: *runtime.Instance = undefined,
            pointerBeforeReferenceNode: bool = undefined,
            whatToShow: u32 = undefined,
            filter: ?runtime.JSValue = null,
            cached_root: ?*runtime.Instance = null,
            _internal: ?*NodeIteratorImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_filter = &get_filter,
        .get_pointerBeforeReferenceNode = &get_pointerBeforeReferenceNode,
        .get_referenceNode = &get_referenceNode,
        .get_root = &get_root,
        .get_whatToShow = &get_whatToShow,

        .call_detach = &call_detach,
        .call_nextNode = &call_nextNode,
        .call_previousNode = &call_previousNode,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("NodeIterator has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(NodeIteratorImpl, "init") and @hasDecl(NodeIteratorImpl, "initOwn")) @compileError("NodeIteratorImpl defines both init and initOwn");
        if (comptime @hasDecl(NodeIteratorImpl, "init")) return NodeIteratorImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(NodeIteratorImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try NodeIteratorImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(NodeIteratorImpl, "init")) return false;
        if (comptime @hasDecl(NodeIteratorImpl, "construction_args")) {
            inline for (NodeIteratorImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(NodeIteratorImpl, "deinit") and @hasDecl(NodeIteratorImpl, "deinitOwn")) @compileError("NodeIteratorImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(NodeIteratorImpl, "deinit")) return NodeIteratorImpl.deinit(instance);
        if (comptime @hasDecl(NodeIteratorImpl, "deinitOwn")) NodeIteratorImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "NodeIterator")) {
            if (comptime @hasDecl(impls.NodeIterator, "installHooks")) impls.NodeIterator.installHooks();
        }
    }

    /// Extended attributes: [SameObject]
    pub fn get_root(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_root) |cached| {
            return cached;
        }
        const value = try NodeIteratorImpl.get_root(instance);
        state.own.cached_root = value;
        return value;
    }

    pub fn get_referenceNode(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try NodeIteratorImpl.get_referenceNode(instance);
    }

    pub fn get_pointerBeforeReferenceNode(instance: *runtime.Instance) anyerror!bool {
        return try NodeIteratorImpl.get_pointerBeforeReferenceNode(instance);
    }

    pub fn get_whatToShow(instance: *runtime.Instance) anyerror!u32 {
        return try NodeIteratorImpl.get_whatToShow(instance);
    }

    pub fn get_filter(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try NodeIteratorImpl.get_filter(instance);
    }

    pub fn call_previousNode(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try NodeIteratorImpl.call_previousNode(instance);
    }

    pub fn call_detach(instance: *runtime.Instance) anyerror!void {
        return try NodeIteratorImpl.call_detach(instance);
    }

    pub fn call_nextNode(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try NodeIteratorImpl.call_nextNode(instance);
    }
};
