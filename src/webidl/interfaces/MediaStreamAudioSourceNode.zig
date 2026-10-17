//! Generated from: webaudio.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MediaStreamAudioSourceNodeImpl = @import("impls").MediaStreamAudioSourceNode;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AudioNode = @import("interfaces").AudioNode;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const ChannelCountMode = @import("enums").ChannelCountMode;
const AudioContext = @import("interfaces").AudioContext;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const MediaStream = @import("interfaces").MediaStream;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const MediaStreamAudioSourceOptions = @import("dictionaries").MediaStreamAudioSourceOptions;
const EventListener = @import("interfaces").EventListener;
const AudioParam = @import("interfaces").AudioParam;
const ChannelInterpretation = @import("enums").ChannelInterpretation;
const DOMString = @import("typedefs").DOMString;

pub const MediaStreamAudioSourceNode = struct {
    pub const Meta = struct {
        pub const name = "MediaStreamAudioSourceNode";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = AudioNode.State;
        pub const ParentInterface = AudioNode;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "mediaStream", "get_mediaStream", null },
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
            "connect",
            "connect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "mediaStream", "get_mediaStream", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            mediaStream: *runtime.Instance = undefined,
            cached_mediaStream: ?*runtime.Instance = null,
            _internal: ?*MediaStreamAudioSourceNodeImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_mediaStream = &get_mediaStream,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("MediaStreamAudioSourceNode has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(MediaStreamAudioSourceNodeImpl, "init") and @hasDecl(MediaStreamAudioSourceNodeImpl, "initOwn")) @compileError("MediaStreamAudioSourceNodeImpl defines both init and initOwn");
        if (comptime @hasDecl(MediaStreamAudioSourceNodeImpl, "init")) return MediaStreamAudioSourceNodeImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(MediaStreamAudioSourceNodeImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try MediaStreamAudioSourceNodeImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(MediaStreamAudioSourceNodeImpl, "init")) return false;
        if (comptime @hasDecl(MediaStreamAudioSourceNodeImpl, "construction_args")) {
            inline for (MediaStreamAudioSourceNodeImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(MediaStreamAudioSourceNodeImpl, "deinit") and @hasDecl(MediaStreamAudioSourceNodeImpl, "deinitOwn")) @compileError("MediaStreamAudioSourceNodeImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(MediaStreamAudioSourceNodeImpl, "deinit")) return MediaStreamAudioSourceNodeImpl.deinit(instance);
        if (comptime @hasDecl(MediaStreamAudioSourceNodeImpl, "deinitOwn")) MediaStreamAudioSourceNodeImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "MediaStreamAudioSourceNode")) {
            if (comptime @hasDecl(impls.MediaStreamAudioSourceNode, "installHooks")) impls.MediaStreamAudioSourceNode.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, context: *runtime.Instance, options: MediaStreamAudioSourceOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MediaStreamAudioSourceNodeImpl.call_constructor(ctx, context, options);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "", 0, "AudioContext" },
    };

    /// Extended attributes: [SameObject]
    pub fn get_mediaStream(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_mediaStream) |cached| {
            return cached;
        }
        const value = try MediaStreamAudioSourceNodeImpl.get_mediaStream(instance);
        state.own.cached_mediaStream = value;
        @import("dom").same_object_cache.made(instance, value, "mediaStream");
        return value;
    }
};
