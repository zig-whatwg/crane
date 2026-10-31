//! Generated from: webrtc-encoded-transform.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RTCRtpScriptTransformerImpl = @import("impls").RTCRtpScriptTransformer;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const Observable = @import("interfaces").Observable;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const ReadableStream = @import("interfaces").ReadableStream;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const WritableStream = @import("interfaces").WritableStream;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const RTCRtpScriptTransformer = struct {
    pub const Meta = struct {
        pub const name = "RTCRtpScriptTransformer";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "DedicatedWorker" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .DedicatedWorker = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "readable", "get_readable", null },
            .{ "writable", "get_writable", null },
            .{ "onkeyframerequest", "get_onkeyframerequest", "set_onkeyframerequest" },
            .{ "options", "get_options", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "generateKeyFrame", "call_generateKeyFrame", 0 },
            .{ "sendKeyFrameRequest", "call_sendKeyFrameRequest", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "generateKeyFrame",
            "sendKeyFrameRequest",
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
            .{ "readable", "get_readable", null },
            .{ "writable", "get_writable", null },
            .{ "onkeyframerequest", "get_onkeyframerequest", "set_onkeyframerequest" },
            .{ "options", "get_options", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            readable: *runtime.Instance = undefined,
            writable: *runtime.Instance = undefined,
            onkeyframerequest: typedefs.EventHandler = undefined,
            options: runtime.JSValue = undefined,
            _internal: ?*RTCRtpScriptTransformerImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onkeyframerequest = &get_onkeyframerequest,
        .get_options = &get_options,
        .get_readable = &get_readable,
        .get_writable = &get_writable,

        .set_onkeyframerequest = &set_onkeyframerequest,

        .call_generateKeyFrame = &call_generateKeyFrame,
        .call_sendKeyFrameRequest = &call_sendKeyFrameRequest,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("RTCRtpScriptTransformer has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(RTCRtpScriptTransformerImpl, "init") and @hasDecl(RTCRtpScriptTransformerImpl, "initOwn")) @compileError("RTCRtpScriptTransformerImpl defines both init and initOwn");
        if (comptime @hasDecl(RTCRtpScriptTransformerImpl, "init")) return RTCRtpScriptTransformerImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(RTCRtpScriptTransformerImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try RTCRtpScriptTransformerImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(RTCRtpScriptTransformerImpl, "init")) return false;
        if (comptime @hasDecl(RTCRtpScriptTransformerImpl, "construction_args")) {
            inline for (RTCRtpScriptTransformerImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(RTCRtpScriptTransformerImpl, "deinit") and @hasDecl(RTCRtpScriptTransformerImpl, "deinitOwn")) @compileError("RTCRtpScriptTransformerImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(RTCRtpScriptTransformerImpl, "deinit")) return RTCRtpScriptTransformerImpl.deinit(instance);
        if (comptime @hasDecl(RTCRtpScriptTransformerImpl, "deinitOwn")) RTCRtpScriptTransformerImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "RTCRtpScriptTransformer")) {
            if (comptime @hasDecl(impls.RTCRtpScriptTransformer, "installHooks")) impls.RTCRtpScriptTransformer.installHooks();
        }
    }

    pub fn get_readable(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RTCRtpScriptTransformerImpl.get_readable(instance);
    }

    pub fn get_writable(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RTCRtpScriptTransformerImpl.get_writable(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onkeyframerequest(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(RTCRtpScriptTransformerImpl, "get_onkeyframerequest")) return try RTCRtpScriptTransformerImpl.get_onkeyframerequest(instance);
        return event_handlers.value(EventHandler, instance, "onkeyframerequest");
    }

    pub fn set_onkeyframerequest(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(RTCRtpScriptTransformerImpl, "set_onkeyframerequest")) return try RTCRtpScriptTransformerImpl.set_onkeyframerequest(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onkeyframerequest", value);
    }

    pub fn get_options(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try RTCRtpScriptTransformerImpl.get_options(instance);
    }

    pub fn call_generateKeyFrame(instance: *runtime.Instance, rid: webidl.Opt(runtime.DOMString)) anyerror!runtime.JSValue {
        return try RTCRtpScriptTransformerImpl.call_generateKeyFrame(instance, rid);
    }

    pub fn call_sendKeyFrameRequest(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try RTCRtpScriptTransformerImpl.call_sendKeyFrameRequest(instance);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{"set_onkeyframerequest"};

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_generateKeyFrame",
        "call_sendKeyFrameRequest",
    };
};
