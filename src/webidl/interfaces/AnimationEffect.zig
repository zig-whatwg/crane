//! Generated from: web-animations.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AnimationEffectImpl = @import("impls").AnimationEffect;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GroupEffect = @import("interfaces").GroupEffect;
const ComputedEffectTiming = @import("dictionaries").ComputedEffectTiming;
const EffectTiming = @import("dictionaries").EffectTiming;
const OptionalEffectTiming = @import("dictionaries").OptionalEffectTiming;

pub const AnimationEffect = struct {
    pub const Meta = struct {
        pub const name = "AnimationEffect";
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
            .{ "parent", "get_parent", null },
            .{ "previousSibling", "get_previousSibling", null },
            .{ "nextSibling", "get_nextSibling", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getTiming", "call_getTiming", 0 },
            .{ "getComputedTiming", "call_getComputedTiming", 0 },
            .{ "updateTiming", "call_updateTiming", 0 },
            .{ "before", "call_before", 0 },
            .{ "after", "call_after", 0 },
            .{ "replace", "call_replace", 0 },
            .{ "remove", "call_remove", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getTiming",
            "getComputedTiming",
            "updateTiming",
            "before",
            "after",
            "replace",
            "remove",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "parent", "get_parent", null },
            .{ "previousSibling", "get_previousSibling", null },
            .{ "nextSibling", "get_nextSibling", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
        /// Member-level [Exposed] overrides; unlisted members inherit the interface.
        pub const exposed_members = .{
            .{ "parent", .{"Window"} },
            .{ "previousSibling", .{"Window"} },
            .{ "nextSibling", .{"Window"} },
            .{ "before", .{"Window"} },
            .{ "after", .{"Window"} },
            .{ "replace", .{"Window"} },
            .{ "remove", .{"Window"} },
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            parent: ?*runtime.Instance = null,
            previousSibling: ?*runtime.Instance = null,
            nextSibling: ?*runtime.Instance = null,
            _internal: ?*AnimationEffectImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_nextSibling = &get_nextSibling,
        .get_parent = &get_parent,
        .get_previousSibling = &get_previousSibling,

        .call_after = &call_after,
        .call_before = &call_before,
        .call_getComputedTiming = &call_getComputedTiming,
        .call_getTiming = &call_getTiming,
        .call_remove = &call_remove,
        .call_replace = &call_replace,
        .call_updateTiming = &call_updateTiming,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("AnimationEffect has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(AnimationEffectImpl, "init") and @hasDecl(AnimationEffectImpl, "initOwn")) @compileError("AnimationEffectImpl defines both init and initOwn");
        if (comptime @hasDecl(AnimationEffectImpl, "init")) return AnimationEffectImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(AnimationEffectImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try AnimationEffectImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(AnimationEffectImpl, "init")) return false;
        if (comptime @hasDecl(AnimationEffectImpl, "construction_args")) {
            inline for (AnimationEffectImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(AnimationEffectImpl, "deinit") and @hasDecl(AnimationEffectImpl, "deinitOwn")) @compileError("AnimationEffectImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(AnimationEffectImpl, "deinit")) return AnimationEffectImpl.deinit(instance);
        if (comptime @hasDecl(AnimationEffectImpl, "deinitOwn")) AnimationEffectImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "AnimationEffect")) {
            if (comptime @hasDecl(impls.AnimationEffect, "installHooks")) impls.AnimationEffect.installHooks();
        }
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_parent(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try AnimationEffectImpl.get_parent(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_previousSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try AnimationEffectImpl.get_previousSibling(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_nextSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try AnimationEffectImpl.get_nextSibling(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_before(instance: *runtime.Instance, effects: []const *runtime.Instance) anyerror!void {
        return try AnimationEffectImpl.call_before(instance, effects);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_replace(instance: *runtime.Instance, effects: []const *runtime.Instance) anyerror!void {
        return try AnimationEffectImpl.call_replace(instance, effects);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_remove(instance: *runtime.Instance) anyerror!void {
        return try AnimationEffectImpl.call_remove(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_after(instance: *runtime.Instance, effects: []const *runtime.Instance) anyerror!void {
        return try AnimationEffectImpl.call_after(instance, effects);
    }

    pub fn call_getComputedTiming(instance: *runtime.Instance) anyerror!ComputedEffectTiming {
        return try AnimationEffectImpl.call_getComputedTiming(instance);
    }

    pub fn call_updateTiming(instance: *runtime.Instance, timing: webidl.Opt(OptionalEffectTiming)) anyerror!void {
        return try AnimationEffectImpl.call_updateTiming(instance, timing);
    }

    pub fn call_getTiming(instance: *runtime.Instance) anyerror!EffectTiming {
        return try AnimationEffectImpl.call_getTiming(instance);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_before", 0, "AnimationEffect" },
        .{ "call_replace", 0, "AnimationEffect" },
        .{ "call_after", 0, "AnimationEffect" },
    };
};
