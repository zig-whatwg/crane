//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WorkerNavigatorImpl = @import("impls").WorkerNavigator;
const NavigatorLocks = @import("interfaces").NavigatorLocks;
const NavigatorGPU = @import("interfaces").NavigatorGPU;
const GlobalPrivacyControl = @import("interfaces").GlobalPrivacyControl;
const NavigatorNetworkInformation = @import("interfaces").NavigatorNetworkInformation;
const NavigatorML = @import("interfaces").NavigatorML;
const NavigatorDeviceMemory = @import("interfaces").NavigatorDeviceMemory;
const NavigatorStorage = @import("interfaces").NavigatorStorage;
const NavigatorStorageBuckets = @import("interfaces").NavigatorStorageBuckets;
const NavigatorID = @import("interfaces").NavigatorID;
const NavigatorLanguage = @import("interfaces").NavigatorLanguage;
const NavigatorOnLine = @import("interfaces").NavigatorOnLine;
const NavigatorConcurrentHardware = @import("interfaces").NavigatorConcurrentHardware;
const NavigatorBadge = @import("interfaces").NavigatorBadge;
const NavigatorUA = @import("interfaces").NavigatorUA;
const LockManager = @import("interfaces").LockManager;
const Serial = @import("interfaces").Serial;
const SmartCardResourceManager = @import("interfaces").SmartCardResourceManager;
const HID = @import("interfaces").HID;
const NetworkInformation = @import("interfaces").NetworkInformation;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const ML = @import("interfaces").ML;
const NavigatorUAData = @import("interfaces").NavigatorUAData;
const GPU = @import("interfaces").GPU;
const StorageBucketManager = @import("interfaces").StorageBucketManager;
const USB = @import("interfaces").USB;
const StorageManager = @import("interfaces").StorageManager;
const FrozenArray<DOMString> = @import("interfaces").FrozenArray<DOMString>;
const ServiceWorkerContainer = @import("interfaces").ServiceWorkerContainer;
const MediaCapabilities = @import("interfaces").MediaCapabilities;
const Permissions = @import("interfaces").Permissions;

pub const WorkerNavigator = struct {
    pub const Meta = struct {
        pub const name = "WorkerNavigator";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
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
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Worker = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            mediaCapabilities: MediaCapabilities = undefined,
            serial: Serial = undefined,
            permissions: Permissions = undefined,
            smartCard: SmartCardResourceManager = undefined,
            usb: USB = undefined,
            hid: HID = undefined,
            serviceWorker: ServiceWorkerContainer = undefined,
            locks: LockManager = undefined,
            gpu: GPU = undefined,
            globalPrivacyControl: bool = undefined,
            connection: NetworkInformation = undefined,
            ml: ML = undefined,
            deviceMemory: f64 = undefined,
            storage: StorageManager = undefined,
            storageBuckets: StorageBucketManager = undefined,
            appCodeName: runtime.DOMString = undefined,
            appName: runtime.DOMString = undefined,
            appVersion: runtime.DOMString = undefined,
            platform: runtime.DOMString = undefined,
            product: runtime.DOMString = undefined,
            productSub: runtime.DOMString = undefined,
            userAgent: runtime.DOMString = undefined,
            vendor: runtime.DOMString = undefined,
            vendorSub: runtime.DOMString = undefined,
            oscpu: runtime.DOMString = undefined,
            language: runtime.DOMString = undefined,
            languages: FrozenArray<DOMString> = undefined,
            onLine: bool = undefined,
            hardwareConcurrency: u64 = undefined,
            userAgentData: NavigatorUAData = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WorkerNavigator, .{
        .deinit_fn = &deinit_wrapper,

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
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        WorkerNavigatorImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WorkerNavigatorImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_mediaCapabilities(instance: *runtime.Instance) anyerror!MediaCapabilities {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_mediaCapabilities) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_mediaCapabilities(instance);
        state.cached_mediaCapabilities = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_serial(instance: *runtime.Instance) anyerror!Serial {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_serial) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_serial(instance);
        state.cached_serial = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_permissions(instance: *runtime.Instance) anyerror!Permissions {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_permissions) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_permissions(instance);
        state.cached_permissions = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_smartCard(instance: *runtime.Instance) anyerror!SmartCardResourceManager {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_smartCard) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_smartCard(instance);
        state.cached_smartCard = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_usb(instance: *runtime.Instance) anyerror!USB {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_usb) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_usb(instance);
        state.cached_usb = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_hid(instance: *runtime.Instance) anyerror!HID {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_hid) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_hid(instance);
        state.cached_hid = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_serviceWorker(instance: *runtime.Instance) anyerror!ServiceWorkerContainer {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_serviceWorker) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_serviceWorker(instance);
        state.cached_serviceWorker = value;
        return value;
    }

    pub fn get_locks(instance: *runtime.Instance) anyerror!LockManager {
        return try WorkerNavigatorImpl.get_locks(instance);
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_gpu(instance: *runtime.Instance) anyerror!GPU {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_gpu) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_gpu(instance);
        state.cached_gpu = value;
        return value;
    }

    pub fn get_globalPrivacyControl(instance: *runtime.Instance) anyerror!bool {
        return try WorkerNavigatorImpl.get_globalPrivacyControl(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_connection(instance: *runtime.Instance) anyerror!NetworkInformation {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_connection) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_connection(instance);
        state.cached_connection = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_ml(instance: *runtime.Instance) anyerror!ML {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_ml) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_ml(instance);
        state.cached_ml = value;
        return value;
    }

    pub fn get_deviceMemory(instance: *runtime.Instance) anyerror!f64 {
        return try WorkerNavigatorImpl.get_deviceMemory(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_storage(instance: *runtime.Instance) anyerror!StorageManager {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_storage) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_storage(instance);
        state.cached_storage = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_storageBuckets(instance: *runtime.Instance) anyerror!StorageBucketManager {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_storageBuckets) |cached| {
            return cached;
        }
        const value = try WorkerNavigatorImpl.get_storageBuckets(instance);
        state.cached_storageBuckets = value;
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

    pub fn get_languages(instance: *runtime.Instance) anyerror!anyopaque {
        return try WorkerNavigatorImpl.get_languages(instance);
    }

    pub fn get_onLine(instance: *runtime.Instance) anyerror!bool {
        return try WorkerNavigatorImpl.get_onLine(instance);
    }

    pub fn get_hardwareConcurrency(instance: *runtime.Instance) anyerror!u64 {
        return try WorkerNavigatorImpl.get_hardwareConcurrency(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_userAgentData(instance: *runtime.Instance) anyerror!NavigatorUAData {
        return try WorkerNavigatorImpl.get_userAgentData(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_taintEnabled(instance: *runtime.Instance) anyerror!bool {
        return try WorkerNavigatorImpl.call_taintEnabled(instance);
    }

    pub fn call_setAppBadge(instance: *runtime.Instance, contents: u64) anyerror!anyopaque {
        // [EnforceRange] on contents
        if (!runtime.isInRange(contents)) return error.TypeError;
        
        return try WorkerNavigatorImpl.call_setAppBadge(instance, contents);
    }

    pub fn call_clearAppBadge(instance: *runtime.Instance) anyerror!anyopaque {
        return try WorkerNavigatorImpl.call_clearAppBadge(instance);
    }

};
