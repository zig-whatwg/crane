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
const NavigatorLocks = @import("mixins").NavigatorLocks;
const NavigatorGPU = @import("mixins").NavigatorGPU;
const GlobalPrivacyControl = @import("mixins").GlobalPrivacyControl;
const NavigatorNetworkInformation = @import("mixins").NavigatorNetworkInformation;
const NavigatorML = @import("mixins").NavigatorML;
const NavigatorDeviceMemory = @import("mixins").NavigatorDeviceMemory;
const NavigatorStorage = @import("mixins").NavigatorStorage;
const NavigatorStorageBuckets = @import("mixins").NavigatorStorageBuckets;
const NavigatorID = @import("mixins").NavigatorID;
const NavigatorLanguage = @import("mixins").NavigatorLanguage;
const NavigatorOnLine = @import("mixins").NavigatorOnLine;
const NavigatorConcurrentHardware = @import("mixins").NavigatorConcurrentHardware;
const NavigatorBadge = @import("mixins").NavigatorBadge;
const NavigatorUA = @import("mixins").NavigatorUA;
const LockManager = @import("interfaces").LockManager;
const Serial = @import("interfaces").Serial;
const SmartCardResourceManager = @import("interfaces").SmartCardResourceManager;
const HID = @import("interfaces").HID;
const NetworkInformation = @import("interfaces").NetworkInformation;
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
            NavigatorLocks,
            NavigatorGPU,
            GlobalPrivacyControl,
            NavigatorNetworkInformation,
            NavigatorML,
            NavigatorDeviceMemory,
            NavigatorStorage,
            NavigatorStorageBuckets,
            NavigatorID,
            NavigatorLanguage,
            NavigatorOnLine,
            NavigatorConcurrentHardware,
            NavigatorBadge,
            NavigatorUA,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Worker" } },
            .{ .name = "SecureContext" },
            .{ .name = "IsolatedContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Worker = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "mediaCapabilities", "get_mediaCapabilities", null },
            .{ "serial", "get_serial", null },
            .{ "permissions", "get_permissions", null },
            .{ "smartCard", "get_smartCard", null },
            .{ "usb", "get_usb", null },
            .{ "hid", "get_hid", null },
            .{ "serviceWorker", "get_serviceWorker", null },
            .{ "locks", "get_locks", null },
            .{ "gpu", "get_gpu", null },
            .{ "globalPrivacyControl", "get_globalPrivacyControl", null },
            .{ "connection", "get_connection", null },
            .{ "ml", "get_ml", null },
            .{ "deviceMemory", "get_deviceMemory", null },
            .{ "storage", "get_storage", null },
            .{ "storageBuckets", "get_storageBuckets", null },
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
            .{ "userAgentData", "get_userAgentData", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "taintEnabled", "call_taintEnabled", 0 },
            .{ "setAppBadge", "call_setAppBadge", 0 },
            .{ "clearAppBadge", "call_clearAppBadge", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "taintEnabled",
            "setAppBadge",
            "clearAppBadge",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "mediaCapabilities", "get_mediaCapabilities", null },
            .{ "serial", "get_serial", null },
            .{ "permissions", "get_permissions", null },
            .{ "smartCard", "get_smartCard", null },
            .{ "usb", "get_usb", null },
            .{ "hid", "get_hid", null },
            .{ "serviceWorker", "get_serviceWorker", null },
            .{ "locks", "get_locks", null },
            .{ "gpu", "get_gpu", null },
            .{ "globalPrivacyControl", "get_globalPrivacyControl", null },
            .{ "connection", "get_connection", null },
            .{ "ml", "get_ml", null },
            .{ "deviceMemory", "get_deviceMemory", null },
            .{ "storage", "get_storage", null },
            .{ "storageBuckets", "get_storageBuckets", null },
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
            .{ "userAgentData", "get_userAgentData", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            mediaCapabilities: *runtime.Instance = undefined,
            serial: *runtime.Instance = undefined,
            permissions: *runtime.Instance = undefined,
            smartCard: *runtime.Instance = undefined,
            usb: *runtime.Instance = undefined,
            hid: *runtime.Instance = undefined,
            serviceWorker: *runtime.Instance = undefined,
            locks: *runtime.Instance = undefined,
            gpu: *runtime.Instance = undefined,
            globalPrivacyControl: bool = undefined,
            connection: *runtime.Instance = undefined,
            ml: *runtime.Instance = undefined,
            deviceMemory: f64 = undefined,
            storage: *runtime.Instance = undefined,
            storageBuckets: *runtime.Instance = undefined,
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
            userAgentData: *runtime.Instance = undefined,
            cached_mediaCapabilities: ?*runtime.Instance = null,
            cached_serial: ?*runtime.Instance = null,
            cached_permissions: ?*runtime.Instance = null,
            cached_smartCard: ?*runtime.Instance = null,
            cached_usb: ?*runtime.Instance = null,
            cached_hid: ?*runtime.Instance = null,
            cached_serviceWorker: ?*runtime.Instance = null,
            cached_gpu: ?*runtime.Instance = null,
            cached_connection: ?*runtime.Instance = null,
            cached_ml: ?*runtime.Instance = null,
            cached_storage: ?*runtime.Instance = null,
            cached_storageBuckets: ?*runtime.Instance = null,
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
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WorkerNavigatorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return WorkerNavigatorImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WorkerNavigatorImpl.deinit(instance);
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
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_serial(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_serial) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_serial(instance);
        state.own.cached_serial = value;
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
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_smartCard(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_smartCard) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_smartCard(instance);
        state.own.cached_smartCard = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_usb(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_usb) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_usb(instance);
        state.own.cached_usb = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_hid(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_hid) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_hid(instance);
        state.own.cached_hid = value;
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
        return value;
    }

    pub fn get_locks(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WorkerNavigatorImpl.get_locks(instance);
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_gpu(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_gpu) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_gpu(instance);
        state.own.cached_gpu = value;
        return value;
    }

    pub fn get_globalPrivacyControl(instance: *runtime.Instance) anyerror!bool {
        return try WorkerNavigatorImpl.get_globalPrivacyControl(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_connection(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_connection) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_connection(instance);
        state.own.cached_connection = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_ml(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_ml) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_ml(instance);
        state.own.cached_ml = value;
        return value;
    }

    pub fn get_deviceMemory(instance: *runtime.Instance) anyerror!f64 {
        return try WorkerNavigatorImpl.get_deviceMemory(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_storage(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_storage) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_storage(instance);
        state.own.cached_storage = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_storageBuckets(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_storageBuckets) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_storageBuckets(instance);
        state.own.cached_storageBuckets = value;
        return value;
    }

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

    /// Extended attributes: [SecureContext]
    pub fn get_userAgentData(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WorkerNavigatorImpl.get_userAgentData(instance);
    }

    pub fn call_clearAppBadge(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try WorkerNavigatorImpl.call_clearAppBadge(instance);
    }

    pub fn call_setAppBadge(instance: *runtime.Instance, contents: webidl.Opt(u64)) anyerror!runtime.JSValue {
        // [EnforceRange] on contents
        if (!runtime.isInRange(u64, contents)) return error.TypeError;
        
        return try WorkerNavigatorImpl.call_setAppBadge(instance, contents);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_taintEnabled(instance: *runtime.Instance) anyerror!bool {
        return try WorkerNavigatorImpl.call_taintEnabled(instance);
    }

};
