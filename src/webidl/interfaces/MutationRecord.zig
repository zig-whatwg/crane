//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MutationRecordImpl = @import("impls").MutationRecord;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Node = @import("interfaces").Node;
const NodeList = @import("interfaces").NodeList;
const DOMString = @import("typedefs").DOMString;

pub const MutationRecord = struct {
    pub const Meta = struct {
        pub const name = "MutationRecord";
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
            .{ "type", "get_type", null },
            .{ "target", "get_target", null },
            .{ "addedNodes", "get_addedNodes", null },
            .{ "removedNodes", "get_removedNodes", null },
            .{ "previousSibling", "get_previousSibling", null },
            .{ "nextSibling", "get_nextSibling", null },
            .{ "attributeName", "get_attributeName", null },
            .{ "attributeNamespace", "get_attributeNamespace", null },
            .{ "oldValue", "get_oldValue", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "type", "get_type", null },
            .{ "target", "get_target", null },
            .{ "addedNodes", "get_addedNodes", null },
            .{ "removedNodes", "get_removedNodes", null },
            .{ "previousSibling", "get_previousSibling", null },
            .{ "nextSibling", "get_nextSibling", null },
            .{ "attributeName", "get_attributeName", null },
            .{ "attributeNamespace", "get_attributeNamespace", null },
            .{ "oldValue", "get_oldValue", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            type: typedefs.DOMString = undefined,
            target: *runtime.Instance = undefined,
            addedNodes: *runtime.Instance = undefined,
            removedNodes: *runtime.Instance = undefined,
            previousSibling: ?*runtime.Instance = null,
            nextSibling: ?*runtime.Instance = null,
            attributeName: ?typedefs.DOMString = null,
            attributeNamespace: ?typedefs.DOMString = null,
            oldValue: ?typedefs.DOMString = null,
            cached_target: ?*runtime.Instance = null,
            cached_addedNodes: ?*runtime.Instance = null,
            cached_removedNodes: ?*runtime.Instance = null,
            _internal: ?*MutationRecordImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_addedNodes = &get_addedNodes,
        .get_attributeName = &get_attributeName,
        .get_attributeNamespace = &get_attributeNamespace,
        .get_nextSibling = &get_nextSibling,
        .get_oldValue = &get_oldValue,
        .get_previousSibling = &get_previousSibling,
        .get_removedNodes = &get_removedNodes,
        .get_target = &get_target,
        .get_type = &get_type,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("MutationRecord has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(MutationRecordImpl, "init") and @hasDecl(MutationRecordImpl, "initOwn")) @compileError("MutationRecordImpl defines both init and initOwn");
        if (comptime @hasDecl(MutationRecordImpl, "init")) return MutationRecordImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(MutationRecordImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try MutationRecordImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(MutationRecordImpl, "init")) return false;
        if (comptime @hasDecl(MutationRecordImpl, "construction_args")) {
            inline for (MutationRecordImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(MutationRecordImpl, "deinit") and @hasDecl(MutationRecordImpl, "deinitOwn")) @compileError("MutationRecordImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(MutationRecordImpl, "deinit")) return MutationRecordImpl.deinit(instance);
        if (comptime @hasDecl(MutationRecordImpl, "deinitOwn")) MutationRecordImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "MutationRecord")) {
            if (comptime @hasDecl(impls.MutationRecord, "installHooks")) impls.MutationRecord.installHooks();
        }
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try MutationRecordImpl.get_type(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_target(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_target) |cached| {
            return cached;
        }
        const value = try MutationRecordImpl.get_target(instance);
        state.own.cached_target = value;
        @import("dom").same_object_cache.made(instance, value, "target");
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_addedNodes(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_addedNodes) |cached| {
            return cached;
        }
        const value = try MutationRecordImpl.get_addedNodes(instance);
        state.own.cached_addedNodes = value;
        @import("dom").same_object_cache.made(instance, value, "addedNodes");
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_removedNodes(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_removedNodes) |cached| {
            return cached;
        }
        const value = try MutationRecordImpl.get_removedNodes(instance);
        state.own.cached_removedNodes = value;
        @import("dom").same_object_cache.made(instance, value, "removedNodes");
        return value;
    }

    pub fn get_previousSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try MutationRecordImpl.get_previousSibling(instance);
    }

    pub fn get_nextSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try MutationRecordImpl.get_nextSibling(instance);
    }

    pub fn get_attributeName(instance: *runtime.Instance) anyerror!?DOMString {
        return try MutationRecordImpl.get_attributeName(instance);
    }

    pub fn get_attributeNamespace(instance: *runtime.Instance) anyerror!?DOMString {
        return try MutationRecordImpl.get_attributeNamespace(instance);
    }

    pub fn get_oldValue(instance: *runtime.Instance) anyerror!?DOMString {
        return try MutationRecordImpl.get_oldValue(instance);
    }
};
