//! Generated from: window-management.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ScreenDetailedImpl = @import("impls").ScreenDetailed;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Screen = @import("interfaces").Screen;
const EventHandler = @import("typedefs").EventHandler;
const ScreenOrientation = @import("interfaces").ScreenOrientation;
const DOMString = @import("typedefs").DOMString;

pub const ScreenDetailed = struct {
    pub const Meta = struct {
        pub const name = "ScreenDetailed";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Screen.State;
        pub const ParentInterface = Screen;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "availLeft", "get_availLeft", null },
            .{ "availTop", "get_availTop", null },
            .{ "left", "get_left", null },
            .{ "top", "get_top", null },
            .{ "isPrimary", "get_isPrimary", null },
            .{ "isInternal", "get_isInternal", null },
            .{ "devicePixelRatio", "get_devicePixelRatio", null },
            .{ "label", "get_label", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "availLeft", "get_availLeft", null },
            .{ "availTop", "get_availTop", null },
            .{ "left", "get_left", null },
            .{ "top", "get_top", null },
            .{ "isPrimary", "get_isPrimary", null },
            .{ "isInternal", "get_isInternal", null },
            .{ "devicePixelRatio", "get_devicePixelRatio", null },
            .{ "label", "get_label", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            availLeft: i32 = undefined,
            availTop: i32 = undefined,
            left: i32 = undefined,
            top: i32 = undefined,
            isPrimary: bool = undefined,
            isInternal: bool = undefined,
            devicePixelRatio: f32 = undefined,
            label: runtime.DOMString = undefined,
            _internal: ?*ScreenDetailedImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_availLeft = &get_availLeft,
        .get_availTop = &get_availTop,
        .get_devicePixelRatio = &get_devicePixelRatio,
        .get_isInternal = &get_isInternal,
        .get_isPrimary = &get_isPrimary,
        .get_label = &get_label,
        .get_left = &get_left,
        .get_top = &get_top,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("ScreenDetailed has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(ScreenDetailedImpl, "init") and @hasDecl(ScreenDetailedImpl, "initOwn")) @compileError("ScreenDetailedImpl defines both init and initOwn");
        if (comptime @hasDecl(ScreenDetailedImpl, "init")) return ScreenDetailedImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(ScreenDetailedImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try ScreenDetailedImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ScreenDetailedImpl, "init")) return false;
        if (comptime @hasDecl(ScreenDetailedImpl, "construction_args")) {
            inline for (ScreenDetailedImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ScreenDetailedImpl, "deinit") and @hasDecl(ScreenDetailedImpl, "deinitOwn")) @compileError("ScreenDetailedImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ScreenDetailedImpl, "deinit")) return ScreenDetailedImpl.deinit(instance);
        if (comptime @hasDecl(ScreenDetailedImpl, "deinitOwn")) ScreenDetailedImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ScreenDetailed")) {
            if (comptime @hasDecl(impls.ScreenDetailed, "installHooks")) impls.ScreenDetailed.installHooks();
        }
    }

    pub fn get_availLeft(instance: *runtime.Instance) anyerror!i32 {
        return try ScreenDetailedImpl.get_availLeft(instance);
    }

    pub fn get_availTop(instance: *runtime.Instance) anyerror!i32 {
        return try ScreenDetailedImpl.get_availTop(instance);
    }

    pub fn get_left(instance: *runtime.Instance) anyerror!i32 {
        return try ScreenDetailedImpl.get_left(instance);
    }

    pub fn get_top(instance: *runtime.Instance) anyerror!i32 {
        return try ScreenDetailedImpl.get_top(instance);
    }

    pub fn get_isPrimary(instance: *runtime.Instance) anyerror!bool {
        return try ScreenDetailedImpl.get_isPrimary(instance);
    }

    pub fn get_isInternal(instance: *runtime.Instance) anyerror!bool {
        return try ScreenDetailedImpl.get_isInternal(instance);
    }

    pub fn get_devicePixelRatio(instance: *runtime.Instance) anyerror!f32 {
        return try ScreenDetailedImpl.get_devicePixelRatio(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try ScreenDetailedImpl.get_label(instance);
    }
};
