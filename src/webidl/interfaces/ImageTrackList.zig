//! Generated from: webcodecs.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ImageTrackListImpl = @import("impls").ImageTrackList;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ImageTrack = @import("interfaces").ImageTrack;

pub const ImageTrackList = struct {
    pub const Meta = struct {
        pub const name = "ImageTrackList";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "ready", "get_ready", null },
            .{ "length", "get_length", null },
            .{ "selectedIndex", "get_selectedIndex", null },
            .{ "selectedTrack", "get_selectedTrack", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "ready", "get_ready", null },
            .{ "length", "get_length", null },
            .{ "selectedIndex", "get_selectedIndex", null },
            .{ "selectedTrack", "get_selectedTrack", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// WebIDL 2.5.6 special operations, own or inherited (the derived-most):
        /// the function that runs each. The binding installs indexed and named
        /// property handlers from this table (webidl.SpecialOperations).
        pub const special_operations: webidl.SpecialOperations = .{
            .indexed_getter = .{ .function = "call_getter", .implemented = @hasDecl(ImageTrackListImpl, "call_getter") },
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            ready: runtime.JSValue = undefined,
            length: u32 = undefined,
            selectedIndex: i32 = undefined,
            selectedTrack: ?*runtime.Instance = null,
            _internal: ?*ImageTrackListImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_length = &get_length,
        .get_ready = &get_ready,
        .get_selectedIndex = &get_selectedIndex,
        .get_selectedTrack = &get_selectedTrack,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("ImageTrackList has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(ImageTrackListImpl, "init") and @hasDecl(ImageTrackListImpl, "initOwn")) @compileError("ImageTrackListImpl defines both init and initOwn");
        if (comptime @hasDecl(ImageTrackListImpl, "init")) return ImageTrackListImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(ImageTrackListImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try ImageTrackListImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ImageTrackListImpl, "init")) return false;
        if (comptime @hasDecl(ImageTrackListImpl, "construction_args")) {
            inline for (ImageTrackListImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ImageTrackListImpl, "deinit") and @hasDecl(ImageTrackListImpl, "deinitOwn")) @compileError("ImageTrackListImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ImageTrackListImpl, "deinit")) return ImageTrackListImpl.deinit(instance);
        if (comptime @hasDecl(ImageTrackListImpl, "deinitOwn")) ImageTrackListImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ImageTrackList")) {
            if (comptime @hasDecl(impls.ImageTrackList, "installHooks")) impls.ImageTrackList.installHooks();
        }
    }

    pub fn get_ready(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ImageTrackListImpl.get_ready(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try ImageTrackListImpl.get_length(instance);
    }

    pub fn get_selectedIndex(instance: *runtime.Instance) anyerror!i32 {
        return try ImageTrackListImpl.get_selectedIndex(instance);
    }

    pub fn get_selectedTrack(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ImageTrackListImpl.get_selectedTrack(instance);
    }

    pub fn call_getter(instance: *runtime.Instance, index: u32) anyerror!*runtime.Instance {
        if (comptime @hasDecl(ImageTrackListImpl, "call_getter")) {
            return try ImageTrackListImpl.call_getter(instance, index);
        } else {
            return error.NotImplemented;
        }
    }
};
