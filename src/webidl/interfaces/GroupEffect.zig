//! Generated from: web-animations-2.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GroupEffectImpl = @import("impls").GroupEffect;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AnimationNodeList = @import("interfaces").AnimationNodeList;
const AnimationEffect = @import("interfaces").AnimationEffect;
const EffectTiming = @import("dictionaries").EffectTiming;

pub const GroupEffect = struct {
    pub const Meta = struct {
        pub const name = "GroupEffect";
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
            .{ "children", "get_children", null },
            .{ "firstChild", "get_firstChild", null },
            .{ "lastChild", "get_lastChild", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "clone", "call_clone", 0 },
            .{ "prepend", "call_prepend", 0 },
            .{ "append", "call_append", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "clone",
            "prepend",
            "append",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "children", "get_children", null },
            .{ "firstChild", "get_firstChild", null },
            .{ "lastChild", "get_lastChild", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            children: *runtime.Instance = undefined,
            firstChild: ?*runtime.Instance = null,
            lastChild: ?*runtime.Instance = null,
            _internal: ?*GroupEffectImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_children = &get_children,
        .get_firstChild = &get_firstChild,
        .get_lastChild = &get_lastChild,

        .call_append = &call_append,
        .call_clone = &call_clone,
        .call_prepend = &call_prepend,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("GroupEffect has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(GroupEffectImpl, "init") and @hasDecl(GroupEffectImpl, "initOwn")) @compileError("GroupEffectImpl defines both init and initOwn");
        if (comptime @hasDecl(GroupEffectImpl, "init")) return GroupEffectImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(GroupEffectImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try GroupEffectImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(GroupEffectImpl, "init")) return false;
        if (comptime @hasDecl(GroupEffectImpl, "construction_args")) {
            inline for (GroupEffectImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(GroupEffectImpl, "deinit") and @hasDecl(GroupEffectImpl, "deinitOwn")) @compileError("GroupEffectImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(GroupEffectImpl, "deinit")) return GroupEffectImpl.deinit(instance);
        if (comptime @hasDecl(GroupEffectImpl, "deinitOwn")) GroupEffectImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "GroupEffect")) {
            if (comptime @hasDecl(impls.GroupEffect, "installHooks")) impls.GroupEffect.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 1;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, children: ?runtime.JSValue, timing: webidl.Opt(runtime.JSValue)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try GroupEffectImpl.call_constructor(ctx, children, timing);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "", 0, "AnimationEffect" },
    };

    pub fn get_children(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try GroupEffectImpl.get_children(instance);
    }

    pub fn get_firstChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try GroupEffectImpl.get_firstChild(instance);
    }

    pub fn get_lastChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try GroupEffectImpl.get_lastChild(instance);
    }

    pub fn call_prepend(instance: *runtime.Instance, effects: []const *runtime.Instance) anyerror!void {
        return try GroupEffectImpl.call_prepend(instance, effects);
    }

    pub fn call_clone(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try GroupEffectImpl.call_clone(instance);
    }

    pub fn call_append(instance: *runtime.Instance, effects: []const *runtime.Instance) anyerror!void {
        return try GroupEffectImpl.call_append(instance, effects);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_prepend", 0, "AnimationEffect" },
        .{ "call_append", 0, "AnimationEffect" },
    };
};
