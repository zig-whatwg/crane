//! Generated from: webcodecs.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const VideoColorSpaceImpl = @import("impls").VideoColorSpace;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const VideoTransferCharacteristics = @import("enums").VideoTransferCharacteristics;
const VideoColorSpaceInit = @import("dictionaries").VideoColorSpaceInit;
const VideoMatrixCoefficients = @import("enums").VideoMatrixCoefficients;
const VideoColorPrimaries = @import("enums").VideoColorPrimaries;

pub const VideoColorSpace = struct {
    pub const Meta = struct {
        pub const name = "VideoColorSpace";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "primaries", "get_primaries", null },
            .{ "transfer", "get_transfer", null },
            .{ "matrix", "get_matrix", null },
            .{ "fullRange", "get_fullRange", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toJSON",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "primaries", "get_primaries", null },
            .{ "transfer", "get_transfer", null },
            .{ "matrix", "get_matrix", null },
            .{ "fullRange", "get_fullRange", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            primaries: ?enums.VideoColorPrimaries = null,
            transfer: ?enums.VideoTransferCharacteristics = null,
            matrix: ?enums.VideoMatrixCoefficients = null,
            fullRange: ?bool = null,
            _internal: ?*VideoColorSpaceImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for VideoColorSpace
    /// Generated from [Default] toJSON extended attribute
    pub const VideoColorSpaceToJSON = struct {
        primaries: ?VideoColorPrimaries,
        transfer: ?VideoTransferCharacteristics,
        matrix: ?VideoMatrixCoefficients,
        fullRange: ?bool,

        pub const default_to_json = true;
    };

    const delegates = .{
        .get_fullRange = &get_fullRange,
        .get_matrix = &get_matrix,
        .get_primaries = &get_primaries,
        .get_transfer = &get_transfer,

        .call_toJSON = &call_toJSON,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("VideoColorSpace has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(VideoColorSpaceImpl, "init") and @hasDecl(VideoColorSpaceImpl, "initOwn")) @compileError("VideoColorSpaceImpl defines both init and initOwn");
        if (comptime @hasDecl(VideoColorSpaceImpl, "init")) return VideoColorSpaceImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(VideoColorSpaceImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try VideoColorSpaceImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(VideoColorSpaceImpl, "init")) return false;
        if (comptime @hasDecl(VideoColorSpaceImpl, "construction_args")) {
            inline for (VideoColorSpaceImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(VideoColorSpaceImpl, "deinit") and @hasDecl(VideoColorSpaceImpl, "deinitOwn")) @compileError("VideoColorSpaceImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(VideoColorSpaceImpl, "deinit")) return VideoColorSpaceImpl.deinit(instance);
        if (comptime @hasDecl(VideoColorSpaceImpl, "deinitOwn")) VideoColorSpaceImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "VideoColorSpace")) {
            if (comptime @hasDecl(impls.VideoColorSpace, "installHooks")) impls.VideoColorSpace.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 0;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, init_data: webidl.Opt(VideoColorSpaceInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try VideoColorSpaceImpl.call_constructor(ctx, init_data);
    }

    pub fn get_primaries(instance: *runtime.Instance) anyerror!?VideoColorPrimaries {
        return try VideoColorSpaceImpl.get_primaries(instance);
    }

    pub fn get_transfer(instance: *runtime.Instance) anyerror!?VideoTransferCharacteristics {
        return try VideoColorSpaceImpl.get_transfer(instance);
    }

    pub fn get_matrix(instance: *runtime.Instance) anyerror!?VideoMatrixCoefficients {
        return try VideoColorSpaceImpl.get_matrix(instance);
    }

    pub fn get_fullRange(instance: *runtime.Instance) anyerror!?bool {
        return try VideoColorSpaceImpl.get_fullRange(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!VideoColorSpaceToJSON {
        return try VideoColorSpaceImpl.call_toJSON(instance);
    }
};
