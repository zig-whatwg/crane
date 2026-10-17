//! Generated from: web-animations.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AnimationTimelineImpl = @import("impls").AnimationTimeline;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AnimationEffect = @import("interfaces").AnimationEffect;
const CSSNumberish = @import("typedefs").CSSNumberish;
const Animation = @import("interfaces").Animation;

pub const AnimationTimeline = struct {
    pub const Meta = struct {
        pub const name = "AnimationTimeline";
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
            .{ "currentTime", "get_currentTime", null },
            .{ "duration", "get_duration", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "play", "call_play", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "play",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "currentTime", "get_currentTime", null },
            .{ "duration", "get_duration", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            currentTime: ?f64 = null,
            duration: ?typedefs.CSSNumberish = null,
            _internal: ?*AnimationTimelineImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_currentTime = &get_currentTime,
        .get_duration = &get_duration,

        .call_play = &call_play,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("AnimationTimeline has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(AnimationTimelineImpl, "init") and @hasDecl(AnimationTimelineImpl, "initOwn")) @compileError("AnimationTimelineImpl defines both init and initOwn");
        if (comptime @hasDecl(AnimationTimelineImpl, "init")) return AnimationTimelineImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(AnimationTimelineImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try AnimationTimelineImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(AnimationTimelineImpl, "init")) return false;
        if (comptime @hasDecl(AnimationTimelineImpl, "construction_args")) {
            inline for (AnimationTimelineImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(AnimationTimelineImpl, "deinit") and @hasDecl(AnimationTimelineImpl, "deinitOwn")) @compileError("AnimationTimelineImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(AnimationTimelineImpl, "deinit")) return AnimationTimelineImpl.deinit(instance);
        if (comptime @hasDecl(AnimationTimelineImpl, "deinitOwn")) AnimationTimelineImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "AnimationTimeline")) {
            if (comptime @hasDecl(impls.AnimationTimeline, "installHooks")) impls.AnimationTimeline.installHooks();
        }
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyerror!?f64 {
        return try AnimationTimelineImpl.get_currentTime(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!?CSSNumberish {
        return try AnimationTimelineImpl.get_duration(instance);
    }

    pub fn call_play(instance: *runtime.Instance, effect: webidl.Opt(?*runtime.Instance)) anyerror!*runtime.Instance {
        return try AnimationTimelineImpl.call_play(instance, effect);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_play", 0, "AnimationEffect" },
    };
};
