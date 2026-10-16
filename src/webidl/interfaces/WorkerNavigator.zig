//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WorkerNavigatorImpl = @import("impls").WorkerNavigator;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const NavigatorBadge = @import("mixins").NavigatorBadge;
const NavigatorDeviceMemory = @import("mixins").NavigatorDeviceMemory;
const GlobalPrivacyControl = @import("mixins").GlobalPrivacyControl;
const NavigatorID = @import("mixins").NavigatorID;
const NavigatorLanguage = @import("mixins").NavigatorLanguage;
const NavigatorOnLine = @import("mixins").NavigatorOnLine;
const NavigatorConcurrentHardware = @import("mixins").NavigatorConcurrentHardware;
const NavigatorNetworkInformation = @import("mixins").NavigatorNetworkInformation;
const NavigatorStorageBuckets = @import("mixins").NavigatorStorageBuckets;
const NavigatorStorage = @import("mixins").NavigatorStorage;
const NavigatorUA = @import("mixins").NavigatorUA;
const NavigatorLocks = @import("mixins").NavigatorLocks;
const NavigatorGPU = @import("mixins").NavigatorGPU;
const NavigatorML = @import("mixins").NavigatorML;
const NetworkInformation = @import("interfaces").NetworkInformation;
const Serial = @import("interfaces").Serial;
const SmartCardResourceManager = @import("interfaces").SmartCardResourceManager;
const HID = @import("interfaces").HID;
const LockManager = @import("interfaces").LockManager;
const ML = @import("interfaces").ML;
const NavigatorUAData = @import("interfaces").NavigatorUAData;
const GPU = @import("interfaces").GPU;
const StorageBucketManager = @import("interfaces").StorageBucketManager;
const USB = @import("interfaces").USB;
const StorageManager = @import("interfaces").StorageManager;
const ServiceWorkerContainer = @import("interfaces").ServiceWorkerContainer;
const MediaCapabilities = @import("interfaces").MediaCapabilities;
const DOMString = @import("typedefs").DOMString;
const Permissions = @import("interfaces").Permissions;

pub const WorkerNavigator = struct {
    pub const Meta = struct {
        pub const name = "WorkerNavigator";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{
            NavigatorBadge,
            NavigatorDeviceMemory,
            GlobalPrivacyControl,
            NavigatorID,
            NavigatorLanguage,
            NavigatorOnLine,
            NavigatorConcurrentHardware,
            NavigatorNetworkInformation,
            NavigatorStorageBuckets,
            NavigatorStorage,
            NavigatorUA,
            NavigatorLocks,
            NavigatorGPU,
            NavigatorML,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Worker" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Worker = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "mediaCapabilities", "get_mediaCapabilities", null },
            .{ "permissions", "get_permissions", null },
            .{ "serial", "get_serial", null },
            .{ "serviceWorker", "get_serviceWorker", null },
            .{ "smartCard", "get_smartCard", null },
            .{ "hid", "get_hid", null },
            .{ "usb", "get_usb", null },
            .{ "deviceMemory", "get_deviceMemory", null },
            .{ "globalPrivacyControl", "get_globalPrivacyControl", null },
            .{ "appCodeName", "get_appCodeName", null },
            .{ "appName", "get_appName", null },
            .{ "appVersion", "get_appVersion", null },
            .{ "platform", "get_platform", null },
            .{ "product", "get_product", null },
            .{ "productSub", "get_productSub", null },
            .{ "userAgent", "get_userAgent", null },
            .{ "vendor", "get_vendor", null },
            .{ "vendorSub", "get_vendorSub", null },
            .{ "oscpu", "get_oscpu", null },
            .{ "language", "get_language", null },
            .{ "languages", "get_languages", null },
            .{ "onLine", "get_onLine", null },
            .{ "hardwareConcurrency", "get_hardwareConcurrency", null },
            .{ "connection", "get_connection", null },
            .{ "storageBuckets", "get_storageBuckets", null },
            .{ "storage", "get_storage", null },
            .{ "userAgentData", "get_userAgentData", null },
            .{ "locks", "get_locks", null },
            .{ "gpu", "get_gpu", null },
            .{ "ml", "get_ml", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setAppBadge", "call_setAppBadge", 0 },
            .{ "clearAppBadge", "call_clearAppBadge", 0 },
            .{ "taintEnabled", "call_taintEnabled", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setAppBadge",
            "clearAppBadge",
            "taintEnabled",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "mediaCapabilities", "get_mediaCapabilities", null },
            .{ "permissions", "get_permissions", null },
            .{ "serial", "get_serial", null },
            .{ "serviceWorker", "get_serviceWorker", null },
            .{ "smartCard", "get_smartCard", null },
            .{ "hid", "get_hid", null },
            .{ "usb", "get_usb", null },
            .{ "deviceMemory", "get_deviceMemory", null },
            .{ "globalPrivacyControl", "get_globalPrivacyControl", null },
            .{ "appCodeName", "get_appCodeName", null },
            .{ "appName", "get_appName", null },
            .{ "appVersion", "get_appVersion", null },
            .{ "platform", "get_platform", null },
            .{ "product", "get_product", null },
            .{ "productSub", "get_productSub", null },
            .{ "userAgent", "get_userAgent", null },
            .{ "vendor", "get_vendor", null },
            .{ "vendorSub", "get_vendorSub", null },
            .{ "oscpu", "get_oscpu", null },
            .{ "language", "get_language", null },
            .{ "languages", "get_languages", null },
            .{ "onLine", "get_onLine", null },
            .{ "hardwareConcurrency", "get_hardwareConcurrency", null },
            .{ "connection", "get_connection", null },
            .{ "storageBuckets", "get_storageBuckets", null },
            .{ "storage", "get_storage", null },
            .{ "userAgentData", "get_userAgentData", null },
            .{ "locks", "get_locks", null },
            .{ "gpu", "get_gpu", null },
            .{ "ml", "get_ml", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// [SecureContext] members - their own, their partial interface's or
        /// their mixin's: hidden in a realm that is not a secure context
        /// (WebIDL 3.3.13).
        pub const secure_context_members = .{
            "serial",
            "serviceWorker",
            "smartCard",
            "hid",
            "usb",
            "deviceMemory",
            "storageBuckets",
            "storage",
            "userAgentData",
            "locks",
            "gpu",
            "ml",
            "setAppBadge",
            "clearAppBadge",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            mediaCapabilities: *runtime.Instance = undefined,
            permissions: *runtime.Instance = undefined,
            serial: *runtime.Instance = undefined,
            serviceWorker: *runtime.Instance = undefined,
            smartCard: *runtime.Instance = undefined,
            hid: *runtime.Instance = undefined,
            usb: *runtime.Instance = undefined,
            deviceMemory: f64 = undefined,
            globalPrivacyControl: bool = undefined,
            appCodeName: typedefs.DOMString = undefined,
            appName: typedefs.DOMString = undefined,
            appVersion: typedefs.DOMString = undefined,
            platform: typedefs.DOMString = undefined,
            product: typedefs.DOMString = undefined,
            productSub: typedefs.DOMString = undefined,
            userAgent: typedefs.DOMString = undefined,
            vendor: typedefs.DOMString = undefined,
            vendorSub: typedefs.DOMString = undefined,
            oscpu: typedefs.DOMString = undefined,
            language: typedefs.DOMString = undefined,
            languages: runtime.JSValue = undefined,
            onLine: bool = undefined,
            hardwareConcurrency: u64 = undefined,
            connection: *runtime.Instance = undefined,
            storageBuckets: *runtime.Instance = undefined,
            storage: *runtime.Instance = undefined,
            userAgentData: *runtime.Instance = undefined,
            locks: *runtime.Instance = undefined,
            gpu: *runtime.Instance = undefined,
            ml: *runtime.Instance = undefined,
            cached_mediaCapabilities: ?*runtime.Instance = null,
            cached_permissions: ?*runtime.Instance = null,
            cached_serial: ?*runtime.Instance = null,
            cached_serviceWorker: ?*runtime.Instance = null,
            cached_smartCard: ?*runtime.Instance = null,
            cached_hid: ?*runtime.Instance = null,
            cached_usb: ?*runtime.Instance = null,
            cached_connection: ?*runtime.Instance = null,
            cached_storageBuckets: ?*runtime.Instance = null,
            cached_storage: ?*runtime.Instance = null,
            cached_gpu: ?*runtime.Instance = null,
            cached_ml: ?*runtime.Instance = null,
            _internal: ?*WorkerNavigatorImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_appCodeName = &get_appCodeName,
        .get_appName = &get_appName,
        .get_appVersion = &get_appVersion,
        .get_connection = &get_connection,
        .get_deviceMemory = &get_deviceMemory,
        .get_globalPrivacyControl = &get_globalPrivacyControl,
        .get_gpu = &get_gpu,
        .get_hardwareConcurrency = &get_hardwareConcurrency,
        .get_hid = &get_hid,
        .get_language = &get_language,
        .get_languages = &get_languages,
        .get_locks = &get_locks,
        .get_mediaCapabilities = &get_mediaCapabilities,
        .get_ml = &get_ml,
        .get_onLine = &get_onLine,
        .get_oscpu = &get_oscpu,
        .get_permissions = &get_permissions,
        .get_platform = &get_platform,
        .get_product = &get_product,
        .get_productSub = &get_productSub,
        .get_serial = &get_serial,
        .get_serviceWorker = &get_serviceWorker,
        .get_smartCard = &get_smartCard,
        .get_storage = &get_storage,
        .get_storageBuckets = &get_storageBuckets,
        .get_usb = &get_usb,
        .get_userAgent = &get_userAgent,
        .get_userAgentData = &get_userAgentData,
        .get_vendor = &get_vendor,
        .get_vendorSub = &get_vendorSub,

        .call_clearAppBadge = &call_clearAppBadge,
        .call_setAppBadge = &call_setAppBadge,
        .call_taintEnabled = &call_taintEnabled,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("WorkerNavigator has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(WorkerNavigatorImpl, "init") and @hasDecl(WorkerNavigatorImpl, "initOwn")) @compileError("WorkerNavigatorImpl defines both init and initOwn");
        if (comptime @hasDecl(WorkerNavigatorImpl, "init")) return WorkerNavigatorImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(WorkerNavigatorImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try WorkerNavigatorImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(WorkerNavigatorImpl, "init")) return false;
        if (comptime @hasDecl(WorkerNavigatorImpl, "construction_args")) {
            inline for (WorkerNavigatorImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(WorkerNavigatorImpl, "deinit") and @hasDecl(WorkerNavigatorImpl, "deinitOwn")) @compileError("WorkerNavigatorImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(WorkerNavigatorImpl, "deinit")) return WorkerNavigatorImpl.deinit(instance);
        if (comptime @hasDecl(WorkerNavigatorImpl, "deinitOwn")) WorkerNavigatorImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "WorkerNavigator")) {
            if (comptime @hasDecl(impls.WorkerNavigator, "installHooks")) impls.WorkerNavigator.installHooks();
        }
    }

    /// Extended attributes: [SameObject]
    pub fn get_mediaCapabilities(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_mediaCapabilities) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_mediaCapabilities(instance);
        state.own.cached_mediaCapabilities = value;
        @import("dom").same_object_cache.made(instance, value, "mediaCapabilities");
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_permissions(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_permissions) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_permissions(instance);
        state.own.cached_permissions = value;
        @import("dom").same_object_cache.made(instance, value, "permissions");
        return value;
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_serial(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_serial) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_serial(instance);
        state.own.cached_serial = value;
        @import("dom").same_object_cache.made(instance, value, "serial");
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_serviceWorker(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_serviceWorker) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_serviceWorker(instance);
        state.own.cached_serviceWorker = value;
        @import("dom").same_object_cache.made(instance, value, "serviceWorker");
        return value;
    }

    /// Extended attributes: [SameObject], [SecureContext], [IsolatedContext]
    pub fn get_smartCard(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_smartCard) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_smartCard(instance);
        state.own.cached_smartCard = value;
        @import("dom").same_object_cache.made(instance, value, "smartCard");
        return value;
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_hid(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_hid) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_hid(instance);
        state.own.cached_hid = value;
        @import("dom").same_object_cache.made(instance, value, "hid");
        return value;
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_usb(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_usb) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_usb(instance);
        state.own.cached_usb = value;
        @import("dom").same_object_cache.made(instance, value, "usb");
        return value;
    }

    /// Extended attributes: [SecureContext]
    pub const get_deviceMemory = mixins.NavigatorDeviceMemory.get_deviceMemory;

    pub const get_globalPrivacyControl = mixins.GlobalPrivacyControl.get_globalPrivacyControl;

    pub fn get_appCodeName(instance: *runtime.Instance) anyerror!DOMString {
        return try WorkerNavigatorImpl.get_appCodeName(instance);
    }

    pub fn get_appName(instance: *runtime.Instance) anyerror!DOMString {
        return try WorkerNavigatorImpl.get_appName(instance);
    }

    pub fn get_appVersion(instance: *runtime.Instance) anyerror!DOMString {
        return try WorkerNavigatorImpl.get_appVersion(instance);
    }

    pub fn get_platform(instance: *runtime.Instance) anyerror!DOMString {
        return try WorkerNavigatorImpl.get_platform(instance);
    }

    pub fn get_product(instance: *runtime.Instance) anyerror!DOMString {
        return try WorkerNavigatorImpl.get_product(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_productSub(instance: *runtime.Instance) anyerror!DOMString {
        return try WorkerNavigatorImpl.get_productSub(instance);
    }

    pub fn get_userAgent(instance: *runtime.Instance) anyerror!DOMString {
        return try WorkerNavigatorImpl.get_userAgent(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_vendor(instance: *runtime.Instance) anyerror!DOMString {
        return try WorkerNavigatorImpl.get_vendor(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_vendorSub(instance: *runtime.Instance) anyerror!DOMString {
        return try WorkerNavigatorImpl.get_vendorSub(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_oscpu(instance: *runtime.Instance) anyerror!DOMString {
        return try WorkerNavigatorImpl.get_oscpu(instance);
    }

    pub fn get_language(instance: *runtime.Instance) anyerror!DOMString {
        return try WorkerNavigatorImpl.get_language(instance);
    }

    pub fn get_languages(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try WorkerNavigatorImpl.get_languages(instance);
    }

    pub fn get_onLine(instance: *runtime.Instance) anyerror!bool {
        return try WorkerNavigatorImpl.get_onLine(instance);
    }

    pub fn get_hardwareConcurrency(instance: *runtime.Instance) anyerror!u64 {
        return try WorkerNavigatorImpl.get_hardwareConcurrency(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_connection(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_connection) |cached| {
            return cached;
        }
        const value = try mixins.NavigatorNetworkInformation.get_connection(instance);
        state.own.cached_connection = value;
        @import("dom").same_object_cache.made(instance, value, "connection");
        return value;
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_storageBuckets(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_storageBuckets) |cached| {
            return cached;
        }
        const value = try mixins.NavigatorStorageBuckets.get_storageBuckets(instance);
        state.own.cached_storageBuckets = value;
        @import("dom").same_object_cache.made(instance, value, "storageBuckets");
        return value;
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_storage(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_storage) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_storage(instance);
        state.own.cached_storage = value;
        @import("dom").same_object_cache.made(instance, value, "storage");
        return value;
    }

    /// Extended attributes: [SecureContext]
    pub const get_userAgentData = mixins.NavigatorUA.get_userAgentData;

    /// Extended attributes: [SecureContext]
    pub const get_locks = mixins.NavigatorLocks.get_locks;

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_gpu(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_gpu) |cached| {
            return cached;
        }
        const value = try mixins.NavigatorGPU.get_gpu(instance);
        state.own.cached_gpu = value;
        @import("dom").same_object_cache.made(instance, value, "gpu");
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_ml(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_ml) |cached| {
            return cached;
        }
        const value = try mixins.NavigatorML.get_ml(instance);
        state.own.cached_ml = value;
        @import("dom").same_object_cache.made(instance, value, "ml");
        return value;
    }

    pub const call_clearAppBadge = mixins.NavigatorBadge.call_clearAppBadge;

    pub const call_setAppBadge = mixins.NavigatorBadge.call_setAppBadge;

    /// Extended attributes: [Exposed=Window]
    pub fn call_taintEnabled(instance: *runtime.Instance) anyerror!bool {
        return try WorkerNavigatorImpl.call_taintEnabled(instance);
    }

    /// WebIDL [EnforceRange]: the integer arguments and attribute values
    /// whose conversion takes that branch of ConvertToInt (bit i = argument i;
    /// an attribute setter's value is bit 0).
    pub const enforce_range = .{
        .{ "call_setAppBadge", 0b1 },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_clearAppBadge",
        "call_setAppBadge",
    };
};
