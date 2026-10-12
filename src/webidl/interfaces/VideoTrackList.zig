//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const VideoTrackListImpl = @import("impls").VideoTrackList;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const EventHandler = @import("typedefs").EventHandler;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const VideoTrack = @import("interfaces").VideoTrack;
const EventListener = @import("interfaces").EventListener;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("interfaces").Observable;

pub const VideoTrackList = struct {
    pub const Meta = struct {
        pub const name = "VideoTrackList";
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
            .{ "length", "get_length", null },
            .{ "selectedIndex", "get_selectedIndex", null },
            .{ "onchange", "get_onchange", "set_onchange" },
            .{ "onaddtrack", "get_onaddtrack", "set_onaddtrack" },
            .{ "onremovetrack", "get_onremovetrack", "set_onremovetrack" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getTrackById", "call_getTrackById", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getTrackById",
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
            .{ "length", "get_length", null },
            .{ "selectedIndex", "get_selectedIndex", null },
            .{ "onchange", "get_onchange", "set_onchange" },
            .{ "onaddtrack", "get_onaddtrack", "set_onaddtrack" },
            .{ "onremovetrack", "get_onremovetrack", "set_onremovetrack" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// WebIDL 2.5.6 special operations, own or inherited (the derived-most):
        /// the function that runs each. The binding installs indexed and named
        /// property handlers from this table (webidl.SpecialOperations).
        pub const special_operations: webidl.SpecialOperations = .{
            .indexed_getter = .{ .function = "call_getter", .implemented = @hasDecl(VideoTrackListImpl, "call_getter") },
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            length: u32 = undefined,
            selectedIndex: i32 = undefined,
            onchange: typedefs.EventHandler = undefined,
            onaddtrack: typedefs.EventHandler = undefined,
            onremovetrack: typedefs.EventHandler = undefined,
            _internal: ?*VideoTrackListImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_length = &get_length,
        .get_onaddtrack = &get_onaddtrack,
        .get_onchange = &get_onchange,
        .get_onremovetrack = &get_onremovetrack,
        .get_selectedIndex = &get_selectedIndex,

        .set_onaddtrack = &set_onaddtrack,
        .set_onchange = &set_onchange,
        .set_onremovetrack = &set_onremovetrack,

        .call_getTrackById = &call_getTrackById,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("VideoTrackList has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(VideoTrackListImpl, "init") and @hasDecl(VideoTrackListImpl, "initOwn")) @compileError("VideoTrackListImpl defines both init and initOwn");
        if (comptime @hasDecl(VideoTrackListImpl, "init")) return VideoTrackListImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(VideoTrackListImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try VideoTrackListImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(VideoTrackListImpl, "init")) return false;
        if (comptime @hasDecl(VideoTrackListImpl, "construction_args")) {
            inline for (VideoTrackListImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(VideoTrackListImpl, "deinit") and @hasDecl(VideoTrackListImpl, "deinitOwn")) @compileError("VideoTrackListImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(VideoTrackListImpl, "deinit")) return VideoTrackListImpl.deinit(instance);
        if (comptime @hasDecl(VideoTrackListImpl, "deinitOwn")) VideoTrackListImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "VideoTrackList")) {
            if (comptime @hasDecl(impls.VideoTrackList, "installHooks")) impls.VideoTrackList.installHooks();
        }
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try VideoTrackListImpl.get_length(instance);
    }

    pub fn get_selectedIndex(instance: *runtime.Instance) anyerror!i32 {
        return try VideoTrackListImpl.get_selectedIndex(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(VideoTrackListImpl, "get_onchange")) return try VideoTrackListImpl.get_onchange(instance);
        return event_handlers.value(EventHandler, instance, "onchange");
    }

    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(VideoTrackListImpl, "set_onchange")) return try VideoTrackListImpl.set_onchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onchange", value);
    }

    pub fn get_onaddtrack(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(VideoTrackListImpl, "get_onaddtrack")) return try VideoTrackListImpl.get_onaddtrack(instance);
        return event_handlers.value(EventHandler, instance, "onaddtrack");
    }

    pub fn set_onaddtrack(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(VideoTrackListImpl, "set_onaddtrack")) return try VideoTrackListImpl.set_onaddtrack(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onaddtrack", value);
    }

    pub fn get_onremovetrack(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(VideoTrackListImpl, "get_onremovetrack")) return try VideoTrackListImpl.get_onremovetrack(instance);
        return event_handlers.value(EventHandler, instance, "onremovetrack");
    }

    pub fn set_onremovetrack(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(VideoTrackListImpl, "set_onremovetrack")) return try VideoTrackListImpl.set_onremovetrack(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onremovetrack", value);
    }

    pub fn call_getter(instance: *runtime.Instance, index: u32) anyerror!*runtime.Instance {
        if (comptime @hasDecl(VideoTrackListImpl, "call_getter")) {
            return try VideoTrackListImpl.call_getter(instance, index);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_getTrackById(instance: *runtime.Instance, id: DOMString) anyerror!?*runtime.Instance {
        return try VideoTrackListImpl.call_getTrackById(instance, id);
    }
};
