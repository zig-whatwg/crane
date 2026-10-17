//! Generated from: background-fetch.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BackgroundFetchRegistrationImpl = @import("impls").BackgroundFetchRegistration;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const CacheQueryOptions = @import("dictionaries").CacheQueryOptions;
const RequestInfo = @import("typedefs").RequestInfo;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const BackgroundFetchFailureReason = @import("enums").BackgroundFetchFailureReason;
const BackgroundFetchResult = @import("enums").BackgroundFetchResult;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const BackgroundFetchRecord = @import("interfaces").BackgroundFetchRecord;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const BackgroundFetchRegistration = struct {
    pub const Meta = struct {
        pub const name = "BackgroundFetchRegistration";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "id", "get_id", null },
            .{ "uploadTotal", "get_uploadTotal", null },
            .{ "uploaded", "get_uploaded", null },
            .{ "downloadTotal", "get_downloadTotal", null },
            .{ "downloaded", "get_downloaded", null },
            .{ "result", "get_result", null },
            .{ "failureReason", "get_failureReason", null },
            .{ "recordsAvailable", "get_recordsAvailable", null },
            .{ "onprogress", "get_onprogress", "set_onprogress" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "abort", "call_abort", 0 },
            .{ "match", "call_match", 1 },
            .{ "matchAll", "call_matchAll", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "abort",
            "match",
            "matchAll",
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
            .{ "uploadTotal", "get_uploadTotal", null },
            .{ "uploaded", "get_uploaded", null },
            .{ "downloadTotal", "get_downloadTotal", null },
            .{ "downloaded", "get_downloaded", null },
            .{ "result", "get_result", null },
            .{ "failureReason", "get_failureReason", null },
            .{ "recordsAvailable", "get_recordsAvailable", null },
            .{ "onprogress", "get_onprogress", "set_onprogress" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            id: runtime.DOMString = undefined,
            uploadTotal: u64 = undefined,
            uploaded: u64 = undefined,
            downloadTotal: u64 = undefined,
            downloaded: u64 = undefined,
            result: enums.BackgroundFetchResult = undefined,
            failureReason: enums.BackgroundFetchFailureReason = undefined,
            recordsAvailable: bool = undefined,
            onprogress: typedefs.EventHandler = undefined,
            _internal: ?*BackgroundFetchRegistrationImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_downloadTotal = &get_downloadTotal,
        .get_downloaded = &get_downloaded,
        .get_failureReason = &get_failureReason,
        .get_id = &get_id,
        .get_onprogress = &get_onprogress,
        .get_recordsAvailable = &get_recordsAvailable,
        .get_result = &get_result,
        .get_uploadTotal = &get_uploadTotal,
        .get_uploaded = &get_uploaded,

        .set_onprogress = &set_onprogress,

        .call_abort = &call_abort,
        .call_match = &call_match,
        .call_matchAll = &call_matchAll,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("BackgroundFetchRegistration has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(BackgroundFetchRegistrationImpl, "init") and @hasDecl(BackgroundFetchRegistrationImpl, "initOwn")) @compileError("BackgroundFetchRegistrationImpl defines both init and initOwn");
        if (comptime @hasDecl(BackgroundFetchRegistrationImpl, "init")) return BackgroundFetchRegistrationImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(BackgroundFetchRegistrationImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try BackgroundFetchRegistrationImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(BackgroundFetchRegistrationImpl, "init")) return false;
        if (comptime @hasDecl(BackgroundFetchRegistrationImpl, "construction_args")) {
            inline for (BackgroundFetchRegistrationImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(BackgroundFetchRegistrationImpl, "deinit") and @hasDecl(BackgroundFetchRegistrationImpl, "deinitOwn")) @compileError("BackgroundFetchRegistrationImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(BackgroundFetchRegistrationImpl, "deinit")) return BackgroundFetchRegistrationImpl.deinit(instance);
        if (comptime @hasDecl(BackgroundFetchRegistrationImpl, "deinitOwn")) BackgroundFetchRegistrationImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "BackgroundFetchRegistration")) {
            if (comptime @hasDecl(impls.BackgroundFetchRegistration, "installHooks")) impls.BackgroundFetchRegistration.installHooks();
        }
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try BackgroundFetchRegistrationImpl.get_id(instance);
    }

    pub fn get_uploadTotal(instance: *runtime.Instance) anyerror!u64 {
        return try BackgroundFetchRegistrationImpl.get_uploadTotal(instance);
    }

    pub fn get_uploaded(instance: *runtime.Instance) anyerror!u64 {
        return try BackgroundFetchRegistrationImpl.get_uploaded(instance);
    }

    pub fn get_downloadTotal(instance: *runtime.Instance) anyerror!u64 {
        return try BackgroundFetchRegistrationImpl.get_downloadTotal(instance);
    }

    pub fn get_downloaded(instance: *runtime.Instance) anyerror!u64 {
        return try BackgroundFetchRegistrationImpl.get_downloaded(instance);
    }

    pub fn get_result(instance: *runtime.Instance) anyerror!BackgroundFetchResult {
        return try BackgroundFetchRegistrationImpl.get_result(instance);
    }

    pub fn get_failureReason(instance: *runtime.Instance) anyerror!BackgroundFetchFailureReason {
        return try BackgroundFetchRegistrationImpl.get_failureReason(instance);
    }

    pub fn get_recordsAvailable(instance: *runtime.Instance) anyerror!bool {
        return try BackgroundFetchRegistrationImpl.get_recordsAvailable(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onprogress(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(BackgroundFetchRegistrationImpl, "get_onprogress")) return try BackgroundFetchRegistrationImpl.get_onprogress(instance);
        return event_handlers.value(EventHandler, instance, "onprogress");
    }

    pub fn set_onprogress(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(BackgroundFetchRegistrationImpl, "set_onprogress")) return try BackgroundFetchRegistrationImpl.set_onprogress(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onprogress", value);
    }

    pub fn call_abort(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try BackgroundFetchRegistrationImpl.call_abort(instance);
    }

    pub fn call_match(instance: *runtime.Instance, request: RequestInfo, options: webidl.Opt(CacheQueryOptions)) anyerror!runtime.JSValue {
        return try BackgroundFetchRegistrationImpl.call_match(instance, request, options);
    }

    pub fn call_matchAll(instance: *runtime.Instance, request: webidl.Opt(RequestInfo), options: webidl.Opt(CacheQueryOptions)) anyerror!runtime.JSValue {
        return try BackgroundFetchRegistrationImpl.call_matchAll(instance, request, options);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_abort",
        "call_match",
        "call_matchAll",
    };
};
