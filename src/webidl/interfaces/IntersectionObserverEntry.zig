//! Generated from: intersection-observer.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const IntersectionObserverEntryImpl = @import("impls").IntersectionObserverEntry;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Element = @import("interfaces").Element;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const IntersectionObserverEntryInit = @import("dictionaries").IntersectionObserverEntryInit;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;

pub const IntersectionObserverEntry = struct {
    pub const Meta = struct {
        pub const name = "IntersectionObserverEntry";
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
            .{ "time", "get_time", null },
            .{ "rootBounds", "get_rootBounds", null },
            .{ "boundingClientRect", "get_boundingClientRect", null },
            .{ "intersectionRect", "get_intersectionRect", null },
            .{ "isIntersecting", "get_isIntersecting", null },
            .{ "isVisible", "get_isVisible", null },
            .{ "intersectionRatio", "get_intersectionRatio", null },
            .{ "target", "get_target", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "time", "get_time", null },
            .{ "rootBounds", "get_rootBounds", null },
            .{ "boundingClientRect", "get_boundingClientRect", null },
            .{ "intersectionRect", "get_intersectionRect", null },
            .{ "isIntersecting", "get_isIntersecting", null },
            .{ "isVisible", "get_isVisible", null },
            .{ "intersectionRatio", "get_intersectionRatio", null },
            .{ "target", "get_target", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            time: typedefs.DOMHighResTimeStamp = undefined,
            rootBounds: ?*runtime.Instance = null,
            boundingClientRect: *runtime.Instance = undefined,
            intersectionRect: *runtime.Instance = undefined,
            isIntersecting: bool = undefined,
            isVisible: bool = undefined,
            intersectionRatio: f64 = undefined,
            target: *runtime.Instance = undefined,
            _internal: ?*IntersectionObserverEntryImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_boundingClientRect = &get_boundingClientRect,
        .get_intersectionRatio = &get_intersectionRatio,
        .get_intersectionRect = &get_intersectionRect,
        .get_isIntersecting = &get_isIntersecting,
        .get_isVisible = &get_isVisible,
        .get_rootBounds = &get_rootBounds,
        .get_target = &get_target,
        .get_time = &get_time,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("IntersectionObserverEntry has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(IntersectionObserverEntryImpl, "init") and @hasDecl(IntersectionObserverEntryImpl, "initOwn")) @compileError("IntersectionObserverEntryImpl defines both init and initOwn");
        if (comptime @hasDecl(IntersectionObserverEntryImpl, "init")) return IntersectionObserverEntryImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(IntersectionObserverEntryImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try IntersectionObserverEntryImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(IntersectionObserverEntryImpl, "init")) return false;
        if (comptime @hasDecl(IntersectionObserverEntryImpl, "construction_args")) {
            inline for (IntersectionObserverEntryImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(IntersectionObserverEntryImpl, "deinit") and @hasDecl(IntersectionObserverEntryImpl, "deinitOwn")) @compileError("IntersectionObserverEntryImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(IntersectionObserverEntryImpl, "deinit")) return IntersectionObserverEntryImpl.deinit(instance);
        if (comptime @hasDecl(IntersectionObserverEntryImpl, "deinitOwn")) IntersectionObserverEntryImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "IntersectionObserverEntry")) {
            if (comptime @hasDecl(impls.IntersectionObserverEntry, "installHooks")) impls.IntersectionObserverEntry.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 1;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, intersectionObserverEntryInit: IntersectionObserverEntryInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try IntersectionObserverEntryImpl.call_constructor(ctx, intersectionObserverEntryInit);
    }

    pub fn get_time(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try IntersectionObserverEntryImpl.get_time(instance);
    }

    pub fn get_rootBounds(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try IntersectionObserverEntryImpl.get_rootBounds(instance);
    }

    pub fn get_boundingClientRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try IntersectionObserverEntryImpl.get_boundingClientRect(instance);
    }

    pub fn get_intersectionRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try IntersectionObserverEntryImpl.get_intersectionRect(instance);
    }

    pub fn get_isIntersecting(instance: *runtime.Instance) anyerror!bool {
        return try IntersectionObserverEntryImpl.get_isIntersecting(instance);
    }

    pub fn get_isVisible(instance: *runtime.Instance) anyerror!bool {
        return try IntersectionObserverEntryImpl.get_isVisible(instance);
    }

    pub fn get_intersectionRatio(instance: *runtime.Instance) anyerror!f64 {
        return try IntersectionObserverEntryImpl.get_intersectionRatio(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try IntersectionObserverEntryImpl.get_target(instance);
    }
};
