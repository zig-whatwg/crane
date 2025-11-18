//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WorkerNavigatorImpl = @import("../impls/WorkerNavigator.zig");
const NavigatorLocks = @import("NavigatorLocks.zig");
const NavigatorGPU = @import("NavigatorGPU.zig");
const GlobalPrivacyControl = @import("GlobalPrivacyControl.zig");
const NavigatorNetworkInformation = @import("NavigatorNetworkInformation.zig");
const NavigatorML = @import("NavigatorML.zig");
const NavigatorDeviceMemory = @import("NavigatorDeviceMemory.zig");
const NavigatorStorage = @import("NavigatorStorage.zig");
const NavigatorStorageBuckets = @import("NavigatorStorageBuckets.zig");
const NavigatorID = @import("NavigatorID.zig");
const NavigatorLanguage = @import("NavigatorLanguage.zig");
const NavigatorOnLine = @import("NavigatorOnLine.zig");
const NavigatorConcurrentHardware = @import("NavigatorConcurrentHardware.zig");
const NavigatorBadge = @import("NavigatorBadge.zig");
const NavigatorUA = @import("NavigatorUA.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        WorkerNavigatorImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WorkerNavigatorImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_mediaCapabilities(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_mediaCapabilities) |cached| {
            return cached;
        }
        const value = WorkerNavigatorImpl.get_mediaCapabilities(state);
        state.cached_mediaCapabilities = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_serial(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_serial) |cached| {
            return cached;
        }
        const value = WorkerNavigatorImpl.get_serial(state);
        state.cached_serial = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_permissions(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_permissions) |cached| {
            return cached;
        }
        const value = WorkerNavigatorImpl.get_permissions(state);
        state.cached_permissions = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_smartCard(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_smartCard) |cached| {
            return cached;
        }
        const value = WorkerNavigatorImpl.get_smartCard(state);
        state.cached_smartCard = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_usb(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_usb) |cached| {
            return cached;
        }
        const value = WorkerNavigatorImpl.get_usb(state);
        state.cached_usb = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_hid(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_hid) |cached| {
            return cached;
        }
        const value = WorkerNavigatorImpl.get_hid(state);
        state.cached_hid = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_serviceWorker(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_serviceWorker) |cached| {
            return cached;
        }
        const value = WorkerNavigatorImpl.get_serviceWorker(state);
        state.cached_serviceWorker = value;
        return value;
    }

    pub fn get_locks(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WorkerNavigatorImpl.get_locks(state);
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_gpu(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_gpu) |cached| {
            return cached;
        }
        const value = WorkerNavigatorImpl.get_gpu(state);
        state.cached_gpu = value;
        return value;
    }

    pub fn get_globalPrivacyControl(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WorkerNavigatorImpl.get_globalPrivacyControl(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_connection(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_connection) |cached| {
            return cached;
        }
        const value = WorkerNavigatorImpl.get_connection(state);
        state.cached_connection = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_ml(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_ml) |cached| {
            return cached;
        }
        const value = WorkerNavigatorImpl.get_ml(state);
        state.cached_ml = value;
        return value;
    }

    pub fn get_deviceMemory(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return WorkerNavigatorImpl.get_deviceMemory(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_storage(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_storage) |cached| {
            return cached;
        }
        const value = WorkerNavigatorImpl.get_storage(state);
        state.cached_storage = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_storageBuckets(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_storageBuckets) |cached| {
            return cached;
        }
        const value = WorkerNavigatorImpl.get_storageBuckets(state);
        state.cached_storageBuckets = value;
        return value;
    }

    pub fn get_appCodeName(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return WorkerNavigatorImpl.get_appCodeName(state);
    }

    pub fn get_appName(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return WorkerNavigatorImpl.get_appName(state);
    }

    pub fn get_appVersion(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return WorkerNavigatorImpl.get_appVersion(state);
    }

    pub fn get_platform(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return WorkerNavigatorImpl.get_platform(state);
    }

    pub fn get_product(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return WorkerNavigatorImpl.get_product(state);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_productSub(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return WorkerNavigatorImpl.get_productSub(state);
    }

    pub fn get_userAgent(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return WorkerNavigatorImpl.get_userAgent(state);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_vendor(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return WorkerNavigatorImpl.get_vendor(state);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_vendorSub(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return WorkerNavigatorImpl.get_vendorSub(state);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_oscpu(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return WorkerNavigatorImpl.get_oscpu(state);
    }

    pub fn get_language(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return WorkerNavigatorImpl.get_language(state);
    }

    pub fn get_languages(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WorkerNavigatorImpl.get_languages(state);
    }

    pub fn get_onLine(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WorkerNavigatorImpl.get_onLine(state);
    }

    pub fn get_hardwareConcurrency(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return WorkerNavigatorImpl.get_hardwareConcurrency(state);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_userAgentData(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WorkerNavigatorImpl.get_userAgentData(state);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_taintEnabled(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WorkerNavigatorImpl.call_taintEnabled(state);
    }

    pub fn call_setAppBadge(instance: *runtime.Instance, contents: u64) anyopaque {
        const state = instance.getState(State);
        // [EnforceRange] on contents
        if (contents > std.math.maxInt(u53)) return error.TypeError;
        
        return WorkerNavigatorImpl.call_setAppBadge(state, contents);
    }

    pub fn call_clearAppBadge(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WorkerNavigatorImpl.call_clearAppBadge(state);
    }

};
