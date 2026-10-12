//! Generated from: webrtc.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RTCDTMFSenderImpl = @import("impls").RTCDTMFSender;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const EventHandler = @import("typedefs").EventHandler;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("interfaces").Observable;

pub const RTCDTMFSender = struct {
    pub const Meta = struct {
        pub const name = "RTCDTMFSender";
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
            .{ "ontonechange", "get_ontonechange", "set_ontonechange" },
            .{ "canInsertDTMF", "get_canInsertDTMF", null },
            .{ "toneBuffer", "get_toneBuffer", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "insertDTMF", "call_insertDTMF", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "insertDTMF",
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
            .{ "ontonechange", "get_ontonechange", "set_ontonechange" },
            .{ "canInsertDTMF", "get_canInsertDTMF", null },
            .{ "toneBuffer", "get_toneBuffer", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            ontonechange: typedefs.EventHandler = undefined,
            canInsertDTMF: bool = undefined,
            toneBuffer: typedefs.DOMString = undefined,
            _internal: ?*RTCDTMFSenderImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_canInsertDTMF = &get_canInsertDTMF,
        .get_ontonechange = &get_ontonechange,
        .get_toneBuffer = &get_toneBuffer,

        .set_ontonechange = &set_ontonechange,

        .call_insertDTMF = &call_insertDTMF,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("RTCDTMFSender has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(RTCDTMFSenderImpl, "init") and @hasDecl(RTCDTMFSenderImpl, "initOwn")) @compileError("RTCDTMFSenderImpl defines both init and initOwn");
        if (comptime @hasDecl(RTCDTMFSenderImpl, "init")) return RTCDTMFSenderImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(RTCDTMFSenderImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try RTCDTMFSenderImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(RTCDTMFSenderImpl, "init")) return false;
        if (comptime @hasDecl(RTCDTMFSenderImpl, "construction_args")) {
            inline for (RTCDTMFSenderImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(RTCDTMFSenderImpl, "deinit") and @hasDecl(RTCDTMFSenderImpl, "deinitOwn")) @compileError("RTCDTMFSenderImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(RTCDTMFSenderImpl, "deinit")) return RTCDTMFSenderImpl.deinit(instance);
        if (comptime @hasDecl(RTCDTMFSenderImpl, "deinitOwn")) RTCDTMFSenderImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "RTCDTMFSender")) {
            if (comptime @hasDecl(impls.RTCDTMFSender, "installHooks")) impls.RTCDTMFSender.installHooks();
        }
    }

    pub fn get_ontonechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCDTMFSenderImpl.get_ontonechange(instance);
    }

    pub fn set_ontonechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCDTMFSenderImpl.set_ontonechange(instance, value);
    }

    pub fn get_canInsertDTMF(instance: *runtime.Instance) anyerror!bool {
        return try RTCDTMFSenderImpl.get_canInsertDTMF(instance);
    }

    pub fn get_toneBuffer(instance: *runtime.Instance) anyerror!DOMString {
        return try RTCDTMFSenderImpl.get_toneBuffer(instance);
    }

    pub fn call_insertDTMF(instance: *runtime.Instance, tones: DOMString, duration: webidl.Opt(u32), interToneGap: webidl.Opt(u32)) anyerror!void {
        return try RTCDTMFSenderImpl.call_insertDTMF(instance, tones, duration, interToneGap);
    }
};
