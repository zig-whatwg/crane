//! Generated from: media-source.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ManagedMediaSourceImpl = @import("impls").ManagedMediaSource;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const MediaSource = @import("interfaces").MediaSource;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const EndOfStreamError = @import("enums").EndOfStreamError;
const MediaSourceHandle = @import("interfaces").MediaSourceHandle;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const SourceBufferList = @import("interfaces").SourceBufferList;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const SourceBuffer = @import("interfaces").SourceBuffer;
const EventListener = @import("interfaces").EventListener;
const ReadyState = @import("enums").ReadyState;
const EventHandler = @import("typedefs").EventHandler;

pub const ManagedMediaSource = struct {
    pub const Meta = struct {
        pub const name = "ManagedMediaSource";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = MediaSource.State;
        pub const ParentInterface = MediaSource;
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
            .{ "streaming", "get_streaming", null },
            .{ "onstartstreaming", "get_onstartstreaming", "set_onstartstreaming" },
            .{ "onendstreaming", "get_onendstreaming", "set_onendstreaming" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "addSourceBuffer",
            "removeSourceBuffer",
            "endOfStream",
            "setLiveSeekableRange",
            "clearLiveSeekableRange",
            "isTypeSupported",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "streaming", "get_streaming", null },
            .{ "onstartstreaming", "get_onstartstreaming", "set_onstartstreaming" },
            .{ "onendstreaming", "get_onendstreaming", "set_onendstreaming" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            streaming: bool = undefined,
            onstartstreaming: typedefs.EventHandler = undefined,
            onendstreaming: typedefs.EventHandler = undefined,
            _internal: ?*ManagedMediaSourceImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onendstreaming = &get_onendstreaming,
        .get_onstartstreaming = &get_onstartstreaming,
        .get_streaming = &get_streaming,

        .set_onendstreaming = &set_onendstreaming,
        .set_onstartstreaming = &set_onstartstreaming,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("ManagedMediaSource has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(ManagedMediaSourceImpl, "init") and @hasDecl(ManagedMediaSourceImpl, "initOwn")) @compileError("ManagedMediaSourceImpl defines both init and initOwn");
        if (comptime @hasDecl(ManagedMediaSourceImpl, "init")) return ManagedMediaSourceImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(ManagedMediaSourceImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try ManagedMediaSourceImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ManagedMediaSourceImpl, "init")) return false;
        if (comptime @hasDecl(ManagedMediaSourceImpl, "construction_args")) {
            inline for (ManagedMediaSourceImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ManagedMediaSourceImpl, "deinit") and @hasDecl(ManagedMediaSourceImpl, "deinitOwn")) @compileError("ManagedMediaSourceImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ManagedMediaSourceImpl, "deinit")) return ManagedMediaSourceImpl.deinit(instance);
        if (comptime @hasDecl(ManagedMediaSourceImpl, "deinitOwn")) ManagedMediaSourceImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ManagedMediaSource")) {
            if (comptime @hasDecl(impls.ManagedMediaSource, "installHooks")) impls.ManagedMediaSource.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ManagedMediaSourceImpl.call_constructor(ctx);
    }

    pub fn get_streaming(instance: *runtime.Instance) anyerror!bool {
        return try ManagedMediaSourceImpl.get_streaming(instance);
    }

    pub fn get_onstartstreaming(instance: *runtime.Instance) anyerror!EventHandler {
        return try ManagedMediaSourceImpl.get_onstartstreaming(instance);
    }

    pub fn set_onstartstreaming(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ManagedMediaSourceImpl.set_onstartstreaming(instance, value);
    }

    pub fn get_onendstreaming(instance: *runtime.Instance) anyerror!EventHandler {
        return try ManagedMediaSourceImpl.get_onendstreaming(instance);
    }

    pub fn set_onendstreaming(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ManagedMediaSourceImpl.set_onendstreaming(instance, value);
    }
};
