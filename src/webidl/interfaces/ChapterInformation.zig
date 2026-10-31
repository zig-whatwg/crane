//! Generated from: mediasession.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ChapterInformationImpl = @import("impls").ChapterInformation;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;
const MediaImage = @import("dictionaries").MediaImage;

pub const ChapterInformation = struct {
    pub const Meta = struct {
        pub const name = "ChapterInformation";
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
            .{ "title", "get_title", null },
            .{ "startTime", "get_startTime", null },
            .{ "artwork", "get_artwork", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "title", "get_title", null },
            .{ "startTime", "get_startTime", null },
            .{ "artwork", "get_artwork", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            title: runtime.DOMString = undefined,
            startTime: f64 = undefined,
            artwork: runtime.JSValue = undefined,
            cached_artwork: ?runtime.JSValue = null,
            _internal: ?*ChapterInformationImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_artwork = &get_artwork,
        .get_startTime = &get_startTime,
        .get_title = &get_title,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("ChapterInformation has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(ChapterInformationImpl, "init") and @hasDecl(ChapterInformationImpl, "initOwn")) @compileError("ChapterInformationImpl defines both init and initOwn");
        if (comptime @hasDecl(ChapterInformationImpl, "init")) return ChapterInformationImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(ChapterInformationImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try ChapterInformationImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ChapterInformationImpl, "init")) return false;
        if (comptime @hasDecl(ChapterInformationImpl, "construction_args")) {
            inline for (ChapterInformationImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ChapterInformationImpl, "deinit") and @hasDecl(ChapterInformationImpl, "deinitOwn")) @compileError("ChapterInformationImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(ChapterInformationImpl, "deinit")) return ChapterInformationImpl.deinit(instance);
        if (comptime @hasDecl(ChapterInformationImpl, "deinitOwn")) ChapterInformationImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ChapterInformation")) {
            if (comptime @hasDecl(impls.ChapterInformation, "installHooks")) impls.ChapterInformation.installHooks();
        }
    }

    pub fn get_title(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try ChapterInformationImpl.get_title(instance);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!f64 {
        return try ChapterInformationImpl.get_startTime(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_artwork(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ChapterInformationImpl.get_artwork(instance);
    }
};
