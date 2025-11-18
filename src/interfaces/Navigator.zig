//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorImpl = @import("../impls/Navigator.zig");
const NavigatorLocks = @import("NavigatorLocks.zig");
const NavigatorGPU = @import("NavigatorGPU.zig");
const GlobalPrivacyControl = @import("GlobalPrivacyControl.zig");
const NavigatorAutomationInformation = @import("NavigatorAutomationInformation.zig");
const NavigatorNetworkInformation = @import("NavigatorNetworkInformation.zig");
const NavigatorML = @import("NavigatorML.zig");
const NavigatorDeviceMemory = @import("NavigatorDeviceMemory.zig");
const NavigatorStorage = @import("NavigatorStorage.zig");
const NavigatorStorageBuckets = @import("NavigatorStorageBuckets.zig");
const NavigatorID = @import("NavigatorID.zig");
const NavigatorLanguage = @import("NavigatorLanguage.zig");
const NavigatorOnLine = @import("NavigatorOnLine.zig");
const NavigatorContentUtils = @import("NavigatorContentUtils.zig");
const NavigatorCookies = @import("NavigatorCookies.zig");
const NavigatorPlugins = @import("NavigatorPlugins.zig");
const NavigatorConcurrentHardware = @import("NavigatorConcurrentHardware.zig");
const NavigatorBadge = @import("NavigatorBadge.zig");
const NavigatorUA = @import("NavigatorUA.zig");

pub const Navigator = struct {
    pub const Meta = struct {
        pub const name = "Navigator";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            NavigatorLocks,
            NavigatorGPU,
            GlobalPrivacyControl,
            NavigatorAutomationInformation,
            NavigatorNetworkInformation,
            NavigatorML,
            NavigatorDeviceMemory,
            NavigatorStorage,
            NavigatorStorageBuckets,
            NavigatorID,
            NavigatorLanguage,
            NavigatorOnLine,
            NavigatorContentUtils,
            NavigatorCookies,
            NavigatorPlugins,
            NavigatorConcurrentHardware,
            NavigatorBadge,
            NavigatorUA,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
            .{ .name = "IsolatedContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Properties that cannot be shadowed or deleted (configurable: false)
        pub const legacy_unforgeable_properties = .{
            "epubReadingSystem",
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            scheduling: Scheduling = undefined,
            presentation: Presentation = undefined,
            keyboard: Keyboard = undefined,
            clipboard: Clipboard = undefined,
            audioSession: AudioSession = undefined,
            mediaCapabilities: MediaCapabilities = undefined,
            serial: Serial = undefined,
            permissions: Permissions = undefined,
            contacts: ContactsManager = undefined,
            devicePosture: DevicePosture = undefined,
            maxTouchPoints: i32 = undefined,
            attribution: Attribution = undefined,
            smartCard: SmartCardResourceManager = undefined,
            usb: USB = undefined,
            windowControlsOverlay: WindowControlsOverlay = undefined,
            xr: XRSystem = undefined,
            deprecatedRunAdAuctionEnforcesKAnonymity: bool = undefined,
            protectedAudience: ProtectedAudience = undefined,
            hid: HID = undefined,
            credentials: CredentialsContainer = undefined,
            wakeLock: WakeLock = undefined,
            virtualKeyboard: VirtualKeyboard = undefined,
            preferences: PreferenceManager = undefined,
            managed: NavigatorManagedData = undefined,
            serviceWorker: ServiceWorkerContainer = undefined,
            ink: Ink = undefined,
            epubReadingSystem: EpubReadingSystem = undefined,
            userActivation: UserActivation = undefined,
            bluetooth: Bluetooth = undefined,
            geolocation: Geolocation = undefined,
            login: NavigatorLogin = undefined,
            mediaSession: MediaSession = undefined,
            mediaDevices: MediaDevices = undefined,
            locks: LockManager = undefined,
            gpu: GPU = undefined,
            globalPrivacyControl: bool = undefined,
            webdriver: bool = undefined,
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
            cookieEnabled: bool = undefined,
            plugins: PluginArray = undefined,
            mimeTypes: MimeTypeArray = undefined,
            pdfViewerEnabled: bool = undefined,
            hardwareConcurrency: u64 = undefined,
            userAgentData: NavigatorUAData = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Navigator, .{
        .deinit_fn = &deinit_wrapper,

        .get_appCodeName = &get_appCodeName,
        .get_appName = &get_appName,
        .get_appVersion = &get_appVersion,
        .get_attribution = &get_attribution,
        .get_audioSession = &get_audioSession,
        .get_bluetooth = &get_bluetooth,
        .get_clipboard = &get_clipboard,
        .get_connection = &get_connection,
        .get_contacts = &get_contacts,
        .get_cookieEnabled = &get_cookieEnabled,
        .get_credentials = &get_credentials,
        .get_deprecatedRunAdAuctionEnforcesKAnonymity = &get_deprecatedRunAdAuctionEnforcesKAnonymity,
        .get_deviceMemory = &get_deviceMemory,
        .get_devicePosture = &get_devicePosture,
        .get_epubReadingSystem = &get_epubReadingSystem,
        .get_geolocation = &get_geolocation,
        .get_globalPrivacyControl = &get_globalPrivacyControl,
        .get_gpu = &get_gpu,
        .get_hardwareConcurrency = &get_hardwareConcurrency,
        .get_hid = &get_hid,
        .get_ink = &get_ink,
        .get_keyboard = &get_keyboard,
        .get_language = &get_language,
        .get_languages = &get_languages,
        .get_locks = &get_locks,
        .get_login = &get_login,
        .get_managed = &get_managed,
        .get_maxTouchPoints = &get_maxTouchPoints,
        .get_mediaCapabilities = &get_mediaCapabilities,
        .get_mediaDevices = &get_mediaDevices,
        .get_mediaSession = &get_mediaSession,
        .get_mimeTypes = &get_mimeTypes,
        .get_ml = &get_ml,
        .get_onLine = &get_onLine,
        .get_oscpu = &get_oscpu,
        .get_pdfViewerEnabled = &get_pdfViewerEnabled,
        .get_permissions = &get_permissions,
        .get_platform = &get_platform,
        .get_plugins = &get_plugins,
        .get_preferences = &get_preferences,
        .get_presentation = &get_presentation,
        .get_product = &get_product,
        .get_productSub = &get_productSub,
        .get_protectedAudience = &get_protectedAudience,
        .get_scheduling = &get_scheduling,
        .get_serial = &get_serial,
        .get_serviceWorker = &get_serviceWorker,
        .get_smartCard = &get_smartCard,
        .get_storage = &get_storage,
        .get_storageBuckets = &get_storageBuckets,
        .get_usb = &get_usb,
        .get_userActivation = &get_userActivation,
        .get_userAgent = &get_userAgent,
        .get_userAgentData = &get_userAgentData,
        .get_vendor = &get_vendor,
        .get_vendorSub = &get_vendorSub,
        .get_virtualKeyboard = &get_virtualKeyboard,
        .get_wakeLock = &get_wakeLock,
        .get_webdriver = &get_webdriver,
        .get_windowControlsOverlay = &get_windowControlsOverlay,
        .get_xr = &get_xr,

        .call_adAuctionComponents = &call_adAuctionComponents,
        .call_canLoadAdAuctionFencedFrame = &call_canLoadAdAuctionFencedFrame,
        .call_canShare = &call_canShare,
        .call_clearAppBadge = &call_clearAppBadge,
        .call_clearOriginJoinedAdInterestGroups = &call_clearOriginJoinedAdInterestGroups,
        .call_createAuctionNonce = &call_createAuctionNonce,
        .call_createHandwritingRecognizer = &call_createHandwritingRecognizer,
        .call_deprecatedReplaceInURN = &call_deprecatedReplaceInURN,
        .call_deprecatedURNtoURL = &call_deprecatedURNtoURL,
        .call_getAutoplayPolicy = &call_getAutoplayPolicy,
        .call_getAutoplayPolicy = &call_getAutoplayPolicy,
        .call_getAutoplayPolicy = &call_getAutoplayPolicy,
        .call_getBattery = &call_getBattery,
        .call_getGamepads = &call_getGamepads,
        .call_getInstalledRelatedApps = &call_getInstalledRelatedApps,
        .call_getInterestGroupAdAuctionData = &call_getInterestGroupAdAuctionData,
        .call_javaEnabled = &call_javaEnabled,
        .call_joinAdInterestGroup = &call_joinAdInterestGroup,
        .call_leaveAdInterestGroup = &call_leaveAdInterestGroup,
        .call_queryHandwritingRecognizer = &call_queryHandwritingRecognizer,
        .call_registerProtocolHandler = &call_registerProtocolHandler,
        .call_requestMIDIAccess = &call_requestMIDIAccess,
        .call_requestMediaKeySystemAccess = &call_requestMediaKeySystemAccess,
        .call_runAdAuction = &call_runAdAuction,
        .call_sendBeacon = &call_sendBeacon,
        .call_setAppBadge = &call_setAppBadge,
        .call_share = &call_share,
        .call_taintEnabled = &call_taintEnabled,
        .call_unregisterProtocolHandler = &call_unregisterProtocolHandler,
        .call_updateAdInterestGroups = &call_updateAdInterestGroups,
        .call_vibrate = &call_vibrate,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        NavigatorImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        NavigatorImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_scheduling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigatorImpl.get_scheduling(state);
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_presentation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_presentation) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_presentation(state);
        state.cached_presentation = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_keyboard(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_keyboard) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_keyboard(state);
        state.cached_keyboard = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_clipboard(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_clipboard) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_clipboard(state);
        state.cached_clipboard = value;
        return value;
    }

    pub fn get_audioSession(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigatorImpl.get_audioSession(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_mediaCapabilities(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_mediaCapabilities) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_mediaCapabilities(state);
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
        const value = NavigatorImpl.get_serial(state);
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
        const value = NavigatorImpl.get_permissions(state);
        state.cached_permissions = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_contacts(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_contacts) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_contacts(state);
        state.cached_contacts = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_devicePosture(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_devicePosture) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_devicePosture(state);
        state.cached_devicePosture = value;
        return value;
    }

    pub fn get_maxTouchPoints(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return NavigatorImpl.get_maxTouchPoints(state);
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_attribution(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_attribution) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_attribution(state);
        state.cached_attribution = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_smartCard(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_smartCard) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_smartCard(state);
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
        const value = NavigatorImpl.get_usb(state);
        state.cached_usb = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_windowControlsOverlay(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_windowControlsOverlay) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_windowControlsOverlay(state);
        state.cached_windowControlsOverlay = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_xr(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_xr) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_xr(state);
        state.cached_xr = value;
        return value;
    }

    pub fn get_deprecatedRunAdAuctionEnforcesKAnonymity(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigatorImpl.get_deprecatedRunAdAuctionEnforcesKAnonymity(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_protectedAudience(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_protectedAudience) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_protectedAudience(state);
        state.cached_protectedAudience = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_hid(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_hid) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_hid(state);
        state.cached_hid = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_credentials(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_credentials) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_credentials(state);
        state.cached_credentials = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_wakeLock(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_wakeLock) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_wakeLock(state);
        state.cached_wakeLock = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_virtualKeyboard(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_virtualKeyboard) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_virtualKeyboard(state);
        state.cached_virtualKeyboard = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_preferences(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_preferences) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_preferences(state);
        state.cached_preferences = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_managed(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_managed) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_managed(state);
        state.cached_managed = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_serviceWorker(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_serviceWorker) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_serviceWorker(state);
        state.cached_serviceWorker = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_ink(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_ink) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_ink(state);
        state.cached_ink = value;
        return value;
    }

    /// Extended attributes: [LegacyUnforgeable], [SameObject]
    pub fn get_epubReadingSystem(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_epubReadingSystem) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_epubReadingSystem(state);
        state.cached_epubReadingSystem = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_userActivation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_userActivation) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_userActivation(state);
        state.cached_userActivation = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_bluetooth(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_bluetooth) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_bluetooth(state);
        state.cached_bluetooth = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_geolocation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_geolocation) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_geolocation(state);
        state.cached_geolocation = value;
        return value;
    }

    /// Extended attributes: [SecureContext]
    pub fn get_login(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigatorImpl.get_login(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_mediaSession(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_mediaSession) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_mediaSession(state);
        state.cached_mediaSession = value;
        return value;
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_mediaDevices(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_mediaDevices) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_mediaDevices(state);
        state.cached_mediaDevices = value;
        return value;
    }

    pub fn get_locks(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigatorImpl.get_locks(state);
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_gpu(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_gpu) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_gpu(state);
        state.cached_gpu = value;
        return value;
    }

    pub fn get_globalPrivacyControl(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigatorImpl.get_globalPrivacyControl(state);
    }

    pub fn get_webdriver(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigatorImpl.get_webdriver(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_connection(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_connection) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_connection(state);
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
        const value = NavigatorImpl.get_ml(state);
        state.cached_ml = value;
        return value;
    }

    pub fn get_deviceMemory(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return NavigatorImpl.get_deviceMemory(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_storage(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_storage) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_storage(state);
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
        const value = NavigatorImpl.get_storageBuckets(state);
        state.cached_storageBuckets = value;
        return value;
    }

    pub fn get_appCodeName(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return NavigatorImpl.get_appCodeName(state);
    }

    pub fn get_appName(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return NavigatorImpl.get_appName(state);
    }

    pub fn get_appVersion(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return NavigatorImpl.get_appVersion(state);
    }

    pub fn get_platform(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return NavigatorImpl.get_platform(state);
    }

    pub fn get_product(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return NavigatorImpl.get_product(state);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_productSub(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return NavigatorImpl.get_productSub(state);
    }

    pub fn get_userAgent(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return NavigatorImpl.get_userAgent(state);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_vendor(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return NavigatorImpl.get_vendor(state);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_vendorSub(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return NavigatorImpl.get_vendorSub(state);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_oscpu(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return NavigatorImpl.get_oscpu(state);
    }

    pub fn get_language(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return NavigatorImpl.get_language(state);
    }

    pub fn get_languages(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigatorImpl.get_languages(state);
    }

    pub fn get_onLine(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigatorImpl.get_onLine(state);
    }

    pub fn get_cookieEnabled(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigatorImpl.get_cookieEnabled(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_plugins(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_plugins) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_plugins(state);
        state.cached_plugins = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_mimeTypes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_mimeTypes) |cached| {
            return cached;
        }
        const value = NavigatorImpl.get_mimeTypes(state);
        state.cached_mimeTypes = value;
        return value;
    }

    pub fn get_pdfViewerEnabled(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigatorImpl.get_pdfViewerEnabled(state);
    }

    pub fn get_hardwareConcurrency(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return NavigatorImpl.get_hardwareConcurrency(state);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_userAgentData(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigatorImpl.get_userAgentData(state);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_requestMIDIAccess(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigatorImpl.call_requestMIDIAccess(state, options);
    }

    pub fn call_adAuctionComponents(instance: *runtime.Instance, numAdComponents: u16) anyopaque {
        const state = instance.getState(State);
        
        return NavigatorImpl.call_adAuctionComponents(state, numAdComponents);
    }

    pub fn call_joinAdInterestGroup(instance: *runtime.Instance, group: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigatorImpl.call_joinAdInterestGroup(state, group);
    }

    pub fn call_vibrate(instance: *runtime.Instance, pattern: anyopaque) bool {
        const state = instance.getState(State);
        
        return NavigatorImpl.call_vibrate(state, pattern);
    }

    pub fn call_createHandwritingRecognizer(instance: *runtime.Instance, constraint: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigatorImpl.call_createHandwritingRecognizer(state, constraint);
    }

    pub fn call_leaveAdInterestGroup(instance: *runtime.Instance, group: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigatorImpl.call_leaveAdInterestGroup(state, group);
    }

    pub fn call_getGamepads(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigatorImpl.call_getGamepads(state);
    }

    pub fn call_updateAdInterestGroups(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigatorImpl.call_updateAdInterestGroups(state);
    }

    pub fn call_getBattery(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigatorImpl.call_getBattery(state);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_taintEnabled(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigatorImpl.call_taintEnabled(state);
    }

    pub fn call_setAppBadge(instance: *runtime.Instance, contents: u64) anyopaque {
        const state = instance.getState(State);
        // [EnforceRange] on contents
        if (contents > std.math.maxInt(u53)) return error.TypeError;
        
        return NavigatorImpl.call_setAppBadge(state, contents);
    }

    pub fn call_canLoadAdAuctionFencedFrame(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigatorImpl.call_canLoadAdAuctionFencedFrame(state);
    }

    pub fn call_createAuctionNonce(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigatorImpl.call_createAuctionNonce(state);
    }

    pub fn call_sendBeacon(instance: *runtime.Instance, url: runtime.USVString, data: anyopaque) bool {
        const state = instance.getState(State);
        
        return NavigatorImpl.call_sendBeacon(state, url, data);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_unregisterProtocolHandler(instance: *runtime.Instance, scheme: runtime.DOMString, url: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return NavigatorImpl.call_unregisterProtocolHandler(state, scheme, url);
    }

    pub fn call_queryHandwritingRecognizer(instance: *runtime.Instance, constraint: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigatorImpl.call_queryHandwritingRecognizer(state, constraint);
    }

    pub fn call_clearAppBadge(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigatorImpl.call_clearAppBadge(state);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_share(instance: *runtime.Instance, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigatorImpl.call_share(state, data);
    }

    pub fn call_runAdAuction(instance: *runtime.Instance, config: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigatorImpl.call_runAdAuction(state, config);
    }

    pub fn call_deprecatedReplaceInURN(instance: *runtime.Instance, urnOrConfig: anyopaque, replacements: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigatorImpl.call_deprecatedReplaceInURN(state, urnOrConfig, replacements);
    }

    /// Arguments for getAutoplayPolicy (WebIDL overloading)
    pub const GetAutoplayPolicyArgs = union(enum) {
        /// getAutoplayPolicy(type)
        AutoplayPolicyMediaType: anyopaque,
        /// getAutoplayPolicy(element)
        HTMLMediaElement: anyopaque,
        /// getAutoplayPolicy(context)
        AudioContext: anyopaque,
    };

    pub fn call_getAutoplayPolicy(instance: *runtime.Instance, args: GetAutoplayPolicyArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .AutoplayPolicyMediaType => |arg| return NavigatorImpl.AutoplayPolicyMediaType(state, arg),
            .HTMLMediaElement => |arg| return NavigatorImpl.HTMLMediaElement(state, arg),
            .AudioContext => |arg| return NavigatorImpl.AudioContext(state, arg),
        }
    }

    pub fn call_javaEnabled(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigatorImpl.call_javaEnabled(state);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_getInstalledRelatedApps(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigatorImpl.call_getInstalledRelatedApps(state);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_canShare(instance: *runtime.Instance, data: anyopaque) bool {
        const state = instance.getState(State);
        
        return NavigatorImpl.call_canShare(state, data);
    }

    pub fn call_clearOriginJoinedAdInterestGroups(instance: *runtime.Instance, owner: runtime.USVString, interestGroupsToKeep: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigatorImpl.call_clearOriginJoinedAdInterestGroups(state, owner, interestGroupsToKeep);
    }

    pub fn call_getInterestGroupAdAuctionData(instance: *runtime.Instance, config: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigatorImpl.call_getInterestGroupAdAuctionData(state, config);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_requestMediaKeySystemAccess(instance: *runtime.Instance, keySystem: runtime.DOMString, supportedConfigurations: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigatorImpl.call_requestMediaKeySystemAccess(state, keySystem, supportedConfigurations);
    }

    pub fn call_deprecatedURNtoURL(instance: *runtime.Instance, urnOrConfig: anyopaque, send_reports: bool) anyopaque {
        const state = instance.getState(State);
        
        return NavigatorImpl.call_deprecatedURNtoURL(state, urnOrConfig, send_reports);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_registerProtocolHandler(instance: *runtime.Instance, scheme: runtime.DOMString, url: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return NavigatorImpl.call_registerProtocolHandler(state, scheme, url);
    }

};
