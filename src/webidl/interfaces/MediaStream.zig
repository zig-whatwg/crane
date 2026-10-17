//! Generated from: mediacapture-streams.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MediaStreamImpl = @import("impls").MediaStream;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const Observable = @import("interfaces").Observable;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const MediaStreamTrack = @import("interfaces").MediaStreamTrack;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const MediaStream = struct {
    pub const Meta = struct {
        pub const name = "MediaStream";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "id", "get_id", null },
            .{ "active", "get_active", null },
            .{ "onaddtrack", "get_onaddtrack", "set_onaddtrack" },
            .{ "onremovetrack", "get_onremovetrack", "set_onremovetrack" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getAudioTracks", "call_getAudioTracks", 0 },
            .{ "getVideoTracks", "call_getVideoTracks", 0 },
            .{ "getTracks", "call_getTracks", 0 },
            .{ "getTrackById", "call_getTrackById", 1 },
            .{ "addTrack", "call_addTrack", 1 },
            .{ "removeTrack", "call_removeTrack", 1 },
            .{ "clone", "call_clone", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getAudioTracks",
            "getVideoTracks",
            "getTracks",
            "getTrackById",
            "addTrack",
            "removeTrack",
            "clone",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "id", "get_id", null },
            .{ "active", "get_active", null },
            .{ "onaddtrack", "get_onaddtrack", "set_onaddtrack" },
            .{ "onremovetrack", "get_onremovetrack", "set_onremovetrack" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            id: typedefs.DOMString = undefined,
            active: bool = undefined,
            onaddtrack: typedefs.EventHandler = undefined,
            onremovetrack: typedefs.EventHandler = undefined,
            _internal: ?*MediaStreamImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_active = &get_active,
        .get_id = &get_id,
        .get_onaddtrack = &get_onaddtrack,
        .get_onremovetrack = &get_onremovetrack,

        .set_onaddtrack = &set_onaddtrack,
        .set_onremovetrack = &set_onremovetrack,

        .call_addTrack = &call_addTrack,
        .call_clone = &call_clone,
        .call_getAudioTracks = &call_getAudioTracks,
        .call_getTrackById = &call_getTrackById,
        .call_getTracks = &call_getTracks,
        .call_getVideoTracks = &call_getVideoTracks,
        .call_removeTrack = &call_removeTrack,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("MediaStream has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(MediaStreamImpl, "init") and @hasDecl(MediaStreamImpl, "initOwn")) @compileError("MediaStreamImpl defines both init and initOwn");
        if (comptime @hasDecl(MediaStreamImpl, "init")) return MediaStreamImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(MediaStreamImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try MediaStreamImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(MediaStreamImpl, "init")) return false;
        if (comptime @hasDecl(MediaStreamImpl, "construction_args")) {
            inline for (MediaStreamImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(MediaStreamImpl, "deinit") and @hasDecl(MediaStreamImpl, "deinitOwn")) @compileError("MediaStreamImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(MediaStreamImpl, "deinit")) return MediaStreamImpl.deinit(instance);
        if (comptime @hasDecl(MediaStreamImpl, "deinitOwn")) MediaStreamImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "MediaStream")) {
            if (comptime @hasDecl(impls.MediaStream, "installHooks")) impls.MediaStream.installHooks();
        }
    }

    /// Arguments for constructor (WebIDL overloading)
    pub const ConstructorArgs = union(enum) {
        /// constructor()
        no_params: void,
        /// constructor(stream)
        MediaStream: *runtime.Instance,
        /// constructor(tracks)
        sequence: runtime.JSValue,
    };

    /// WebIDL overload set of the constructor: one entry per variant of
    /// ConstructorArgs, in its order, for the overload resolution algorithm
    /// (webidl.overload_resolution) the binding runs to pick the variant.
    pub const constructor_overloads = &[_]webidl.overload_resolution.Overload{
        .{ .function = "no_params", .args = &.{} },
        .{ .function = "MediaStream", .args = &.{.{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "MediaStream")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").MediaStream.State) } else .other)} }} },
        .{ .function = "sequence", .args = &.{.{ .kinds = &.{.sequence} }} },
    };

    /// WebIDL constructor (overloaded)
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, args: ConstructorArgs) !*runtime.Instance {
        // Pass args union directly to impl
        return try MediaStreamImpl.call_constructor(ctx, args);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "MediaStream", 0, "MediaStream" },
        .{ "sequence", 0, "MediaStreamTrack" },
    };

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try MediaStreamImpl.get_id(instance);
    }

    pub fn get_active(instance: *runtime.Instance) anyerror!bool {
        return try MediaStreamImpl.get_active(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onaddtrack(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(MediaStreamImpl, "get_onaddtrack")) return try MediaStreamImpl.get_onaddtrack(instance);
        return event_handlers.value(EventHandler, instance, "onaddtrack");
    }

    pub fn set_onaddtrack(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(MediaStreamImpl, "set_onaddtrack")) return try MediaStreamImpl.set_onaddtrack(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onaddtrack", value);
    }

    pub fn get_onremovetrack(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(MediaStreamImpl, "get_onremovetrack")) return try MediaStreamImpl.get_onremovetrack(instance);
        return event_handlers.value(EventHandler, instance, "onremovetrack");
    }

    pub fn set_onremovetrack(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(MediaStreamImpl, "set_onremovetrack")) return try MediaStreamImpl.set_onremovetrack(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onremovetrack", value);
    }

    pub fn call_getTracks(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try MediaStreamImpl.call_getTracks(instance);
    }

    pub fn call_getVideoTracks(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try MediaStreamImpl.call_getVideoTracks(instance);
    }

    pub fn call_addTrack(instance: *runtime.Instance, track: *runtime.Instance) anyerror!void {
        return try MediaStreamImpl.call_addTrack(instance, track);
    }

    pub fn call_removeTrack(instance: *runtime.Instance, track: *runtime.Instance) anyerror!void {
        return try MediaStreamImpl.call_removeTrack(instance, track);
    }

    pub fn call_getTrackById(instance: *runtime.Instance, trackId: DOMString) anyerror!?*runtime.Instance {
        return try MediaStreamImpl.call_getTrackById(instance, trackId);
    }

    pub fn call_getAudioTracks(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try MediaStreamImpl.call_getAudioTracks(instance);
    }

    pub fn call_clone(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try MediaStreamImpl.call_clone(instance);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_addTrack", 0, "MediaStreamTrack" },
        .{ "call_removeTrack", 0, "MediaStreamTrack" },
    };
};
