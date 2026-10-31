//! Generated from: resize-observer.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ResizeObserverEntryImpl = @import("impls").ResizeObserverEntry;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Element = @import("interfaces").Element;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const ResizeObserverSize = @import("interfaces").ResizeObserverSize;

pub const ResizeObserverEntry = struct {
    pub const Meta = struct {
        pub const name = "ResizeObserverEntry";
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
            .{ "target", "get_target", null },
            .{ "contentRect", "get_contentRect", null },
            .{ "borderBoxSize", "get_borderBoxSize", null },
            .{ "contentBoxSize", "get_contentBoxSize", null },
            .{ "devicePixelContentBoxSize", "get_devicePixelContentBoxSize", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "target", "get_target", null },
            .{ "contentRect", "get_contentRect", null },
            .{ "borderBoxSize", "get_borderBoxSize", null },
            .{ "contentBoxSize", "get_contentBoxSize", null },
            .{ "devicePixelContentBoxSize", "get_devicePixelContentBoxSize", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            target: *runtime.Instance = undefined,
            contentRect: *runtime.Instance = undefined,
            borderBoxSize: runtime.JSValue = undefined,
            contentBoxSize: runtime.JSValue = undefined,
            devicePixelContentBoxSize: runtime.JSValue = undefined,
            _internal: ?*ResizeObserverEntryImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_borderBoxSize = &get_borderBoxSize,
        .get_contentBoxSize = &get_contentBoxSize,
        .get_contentRect = &get_contentRect,
        .get_devicePixelContentBoxSize = &get_devicePixelContentBoxSize,
        .get_target = &get_target,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("ResizeObserverEntry has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(ResizeObserverEntryImpl, "init") and @hasDecl(ResizeObserverEntryImpl, "initOwn")) @compileError("ResizeObserverEntryImpl defines both init and initOwn");
        if (comptime @hasDecl(ResizeObserverEntryImpl, "init")) return ResizeObserverEntryImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(ResizeObserverEntryImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try ResizeObserverEntryImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ResizeObserverEntryImpl, "init")) return false;
        if (comptime @hasDecl(ResizeObserverEntryImpl, "construction_args")) {
            inline for (ResizeObserverEntryImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ResizeObserverEntryImpl, "deinit") and @hasDecl(ResizeObserverEntryImpl, "deinitOwn")) @compileError("ResizeObserverEntryImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ResizeObserverEntryImpl, "deinit")) return ResizeObserverEntryImpl.deinit(instance);
        if (comptime @hasDecl(ResizeObserverEntryImpl, "deinitOwn")) ResizeObserverEntryImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ResizeObserverEntry")) {
            if (comptime @hasDecl(impls.ResizeObserverEntry, "installHooks")) impls.ResizeObserverEntry.installHooks();
        }
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ResizeObserverEntryImpl.get_target(instance);
    }

    pub fn get_contentRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ResizeObserverEntryImpl.get_contentRect(instance);
    }

    pub fn get_borderBoxSize(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ResizeObserverEntryImpl.get_borderBoxSize(instance);
    }

    pub fn get_contentBoxSize(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ResizeObserverEntryImpl.get_contentBoxSize(instance);
    }

    pub fn get_devicePixelContentBoxSize(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ResizeObserverEntryImpl.get_devicePixelContentBoxSize(instance);
    }
};
