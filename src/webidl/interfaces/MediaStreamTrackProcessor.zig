//! Generated from: mediacapture-transform.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MediaStreamTrackProcessorImpl = @import("impls").MediaStreamTrackProcessor;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const MediaStreamTrackProcessorInit = @import("dictionaries").MediaStreamTrackProcessorInit;
const ReadableStream = @import("interfaces").ReadableStream;

pub const MediaStreamTrackProcessor = struct {
    pub const Meta = struct {
        pub const name = "MediaStreamTrackProcessor";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "DedicatedWorker" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .DedicatedWorker = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "readable", "get_readable", null },
            .{ "discardedFrames", "get_discardedFrames", null },
            .{ "totalFrames", "get_totalFrames", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "readable", "get_readable", null },
            .{ "discardedFrames", "get_discardedFrames", null },
            .{ "totalFrames", "get_totalFrames", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            readable: *runtime.Instance = undefined,
            discardedFrames: u64 = undefined,
            totalFrames: u64 = undefined,
            _internal: ?*MediaStreamTrackProcessorImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_discardedFrames = &get_discardedFrames,
        .get_readable = &get_readable,
        .get_totalFrames = &get_totalFrames,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("MediaStreamTrackProcessor has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(MediaStreamTrackProcessorImpl, "init") and @hasDecl(MediaStreamTrackProcessorImpl, "initOwn")) @compileError("MediaStreamTrackProcessorImpl defines both init and initOwn");
        if (comptime @hasDecl(MediaStreamTrackProcessorImpl, "init")) return MediaStreamTrackProcessorImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(MediaStreamTrackProcessorImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try MediaStreamTrackProcessorImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(MediaStreamTrackProcessorImpl, "init")) return false;
        if (comptime @hasDecl(MediaStreamTrackProcessorImpl, "construction_args")) {
            inline for (MediaStreamTrackProcessorImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(MediaStreamTrackProcessorImpl, "deinit") and @hasDecl(MediaStreamTrackProcessorImpl, "deinitOwn")) @compileError("MediaStreamTrackProcessorImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(MediaStreamTrackProcessorImpl, "deinit")) return MediaStreamTrackProcessorImpl.deinit(instance);
        if (comptime @hasDecl(MediaStreamTrackProcessorImpl, "deinitOwn")) MediaStreamTrackProcessorImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "MediaStreamTrackProcessor")) {
            if (comptime @hasDecl(impls.MediaStreamTrackProcessor, "installHooks")) impls.MediaStreamTrackProcessor.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 1;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, init_data: MediaStreamTrackProcessorInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MediaStreamTrackProcessorImpl.call_constructor(ctx, init_data);
    }

    pub fn get_readable(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try MediaStreamTrackProcessorImpl.get_readable(instance);
    }

    pub fn get_discardedFrames(instance: *runtime.Instance) anyerror!u64 {
        return try MediaStreamTrackProcessorImpl.get_discardedFrames(instance);
    }

    pub fn get_totalFrames(instance: *runtime.Instance) anyerror!u64 {
        return try MediaStreamTrackProcessorImpl.get_totalFrames(instance);
    }
};
