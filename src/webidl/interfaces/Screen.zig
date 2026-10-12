//! Generated from: cssom-view.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ScreenImpl = @import("impls").Screen;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ScreenOrientation = @import("interfaces").ScreenOrientation;
const EventHandler = @import("typedefs").EventHandler;

pub const Screen = struct {
    pub const Meta = struct {
        pub const name = "Screen";
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
            .{ "availWidth", "get_availWidth", null },
            .{ "availHeight", "get_availHeight", null },
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "colorDepth", "get_colorDepth", null },
            .{ "pixelDepth", "get_pixelDepth", null },
            .{ "orientation", "get_orientation", null },
            .{ "isExtended", "get_isExtended", null },
            .{ "onchange", "get_onchange", "set_onchange" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "availWidth", "get_availWidth", null },
            .{ "availHeight", "get_availHeight", null },
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "colorDepth", "get_colorDepth", null },
            .{ "pixelDepth", "get_pixelDepth", null },
            .{ "orientation", "get_orientation", null },
            .{ "isExtended", "get_isExtended", null },
            .{ "onchange", "get_onchange", "set_onchange" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            availWidth: i32 = undefined,
            availHeight: i32 = undefined,
            width: i32 = undefined,
            height: i32 = undefined,
            colorDepth: u32 = undefined,
            pixelDepth: u32 = undefined,
            orientation: *runtime.Instance = undefined,
            isExtended: bool = undefined,
            onchange: typedefs.EventHandler = undefined,
            cached_orientation: ?*runtime.Instance = null,
            _internal: ?*ScreenImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_availHeight = &get_availHeight,
        .get_availWidth = &get_availWidth,
        .get_colorDepth = &get_colorDepth,
        .get_height = &get_height,
        .get_isExtended = &get_isExtended,
        .get_onchange = &get_onchange,
        .get_orientation = &get_orientation,
        .get_pixelDepth = &get_pixelDepth,
        .get_width = &get_width,

        .set_onchange = &set_onchange,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("Screen has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(ScreenImpl, "init") and @hasDecl(ScreenImpl, "initOwn")) @compileError("ScreenImpl defines both init and initOwn");
        if (comptime @hasDecl(ScreenImpl, "init")) return ScreenImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(ScreenImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try ScreenImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ScreenImpl, "init")) return false;
        if (comptime @hasDecl(ScreenImpl, "construction_args")) {
            inline for (ScreenImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ScreenImpl, "deinit") and @hasDecl(ScreenImpl, "deinitOwn")) @compileError("ScreenImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ScreenImpl, "deinit")) return ScreenImpl.deinit(instance);
        if (comptime @hasDecl(ScreenImpl, "deinitOwn")) ScreenImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Screen")) {
            if (comptime @hasDecl(impls.Screen, "installHooks")) impls.Screen.installHooks();
        }
    }

    pub fn get_availWidth(instance: *runtime.Instance) anyerror!i32 {
        return try ScreenImpl.get_availWidth(instance);
    }

    pub fn get_availHeight(instance: *runtime.Instance) anyerror!i32 {
        return try ScreenImpl.get_availHeight(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!i32 {
        return try ScreenImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!i32 {
        return try ScreenImpl.get_height(instance);
    }

    pub fn get_colorDepth(instance: *runtime.Instance) anyerror!u32 {
        return try ScreenImpl.get_colorDepth(instance);
    }

    pub fn get_pixelDepth(instance: *runtime.Instance) anyerror!u32 {
        return try ScreenImpl.get_pixelDepth(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_orientation(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_orientation) |cached| {
            return cached;
        }
        const value = try ScreenImpl.get_orientation(instance);
        state.own.cached_orientation = value;
        return value;
    }

    /// Extended attributes: [SecureContext]
    pub fn get_isExtended(instance: *runtime.Instance) anyerror!bool {
        return try ScreenImpl.get_isExtended(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    /// Extended attributes: [SecureContext]
    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(ScreenImpl, "get_onchange")) return try ScreenImpl.get_onchange(instance);
        return event_handlers.value(EventHandler, instance, "onchange");
    }

    /// Extended attributes: [SecureContext]
    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(ScreenImpl, "set_onchange")) return try ScreenImpl.set_onchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onchange", value);
    }
};
