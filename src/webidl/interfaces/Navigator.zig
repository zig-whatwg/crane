//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorImpl = @import("impls").Navigator;
const NavigatorLocks = @import("interfaces").NavigatorLocks;
const NavigatorGPU = @import("interfaces").NavigatorGPU;
const GlobalPrivacyControl = @import("interfaces").GlobalPrivacyControl;
const NavigatorAutomationInformation = @import("interfaces").NavigatorAutomationInformation;
const NavigatorNetworkInformation = @import("interfaces").NavigatorNetworkInformation;
const NavigatorML = @import("interfaces").NavigatorML;
const NavigatorDeviceMemory = @import("interfaces").NavigatorDeviceMemory;
const NavigatorStorage = @import("interfaces").NavigatorStorage;
const NavigatorStorageBuckets = @import("interfaces").NavigatorStorageBuckets;
const NavigatorID = @import("interfaces").NavigatorID;
const NavigatorLanguage = @import("interfaces").NavigatorLanguage;
const NavigatorOnLine = @import("interfaces").NavigatorOnLine;
const NavigatorContentUtils = @import("interfaces").NavigatorContentUtils;
const NavigatorCookies = @import("interfaces").NavigatorCookies;
const NavigatorPlugins = @import("interfaces").NavigatorPlugins;
const NavigatorConcurrentHardware = @import("interfaces").NavigatorConcurrentHardware;
const NavigatorBadge = @import("interfaces").NavigatorBadge;
const NavigatorUA = @import("interfaces").NavigatorUA;
const MimeTypeArray = @import("interfaces").MimeTypeArray;
const UrnOrConfig = @import("typedefs").UrnOrConfig;
const Serial = @import("interfaces").Serial;
const Presentation = @import("interfaces").Presentation;
const SmartCardResourceManager = @import("interfaces").SmartCardResourceManager;
const AdAuctionDataConfig = @import("dictionaries").AdAuctionDataConfig;
const Promise<HandwritingRecognizerQueryResult?> = @import("interfaces").Promise<HandwritingRecognizerQueryResult?>;
const HID = @import("interfaces").HID;
const AuctionAdConfig = @import("dictionaries").AuctionAdConfig;
const Promise<MIDIAccess> = @import("interfaces").Promise<MIDIAccess>;
const PreferenceManager = @import("interfaces").PreferenceManager;
const VibratePattern = @import("typedefs").VibratePattern;
const NetworkInformation = @import("interfaces").NetworkInformation;
const ML = @import("interfaces").ML;
const Promise<DOMString> = @import("interfaces").Promise<DOMString>;
const StorageBucketManager = @import("interfaces").StorageBucketManager;
const BodyInit = @import("typedefs").BodyInit;
const Promise<sequence<RelatedApplication>> = @import("interfaces").Promise<sequence<RelatedApplication>>;
const AuctionAdInterestGroupKey = @import("dictionaries").AuctionAdInterestGroupKey;
const Promise<AdAuctionData> = @import("interfaces").Promise<AdAuctionData>;
const Attribution = @import("interfaces").Attribution;
const ShareData = @import("dictionaries").ShareData;
const Scheduling = @import("interfaces").Scheduling;
const VirtualKeyboard = @import("interfaces").VirtualKeyboard;
const AutoplayPolicy = @import("enums").AutoplayPolicy;
const Clipboard = @import("interfaces").Clipboard;
const HandwritingModelConstraint = @import("dictionaries").HandwritingModelConstraint;
const StorageManager = @import("interfaces").StorageManager;
const FrozenArray<DOMString> = @import("interfaces").FrozenArray<DOMString>;
const AudioSession = @import("interfaces").AudioSession;
const CredentialsContainer = @import("interfaces").CredentialsContainer;
const ServiceWorkerContainer = @import("interfaces").ServiceWorkerContainer;
const HTMLMediaElement = @import("interfaces").HTMLMediaElement;
const MediaDevices = @import("interfaces").MediaDevices;
const NavigatorManagedData = @import("interfaces").NavigatorManagedData;
const Permissions = @import("interfaces").Permissions;
const LockManager = @import("interfaces").LockManager;
const Promise<(USVStringorFencedFrameConfig)?> = @import("interfaces").Promise<(USVStringorFencedFrameConfig)?>;
const AudioContext = @import("interfaces").AudioContext;
const Promise<MediaKeySystemAccess> = @import("interfaces").Promise<MediaKeySystemAccess>;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const ContactsManager = @import("interfaces").ContactsManager;
const DevicePosture = @import("interfaces").DevicePosture;
const Geolocation = @import("interfaces").Geolocation;
const PluginArray = @import("interfaces").PluginArray;
const GPU = @import("interfaces").GPU;
const WakeLock = @import("interfaces").WakeLock;
const NavigatorUAData = @import("interfaces").NavigatorUAData;
const ProtectedAudience = @import("interfaces").ProtectedAudience;
const NavigatorLogin = @import("interfaces").NavigatorLogin;
const EpubReadingSystem = @import("interfaces").EpubReadingSystem;
const Bluetooth = @import("interfaces").Bluetooth;
const MediaSession = @import("interfaces").MediaSession;
const USB = @import("interfaces").USB;
const AutoplayPolicyMediaType = @import("enums").AutoplayPolicyMediaType;
const MIDIOptions = @import("dictionaries").MIDIOptions;
const Ink = @import("interfaces").Ink;
const XRSystem = @import("interfaces").XRSystem;
const AuctionAdInterestGroup = @import("dictionaries").AuctionAdInterestGroup;
const Keyboard = @import("interfaces").Keyboard;
const WindowControlsOverlay = @import("interfaces").WindowControlsOverlay;
const UserActivation = @import("interfaces").UserActivation;
const Promise<USVString> = @import("interfaces").Promise<USVString>;
const MediaCapabilities = @import("interfaces").MediaCapabilities;
const Promise<HandwritingRecognizer> = @import("interfaces").Promise<HandwritingRecognizer>;
const Promise<BatteryManager> = @import("interfaces").Promise<BatteryManager>;

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
        
        // Initialize the instance (Impl receives full instance)
        NavigatorImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_scheduling(instance: *runtime.Instance) anyerror!Scheduling {
        return try NavigatorImpl.get_scheduling(instance);
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_presentation(instance: *runtime.Instance) anyerror!Presentation {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_presentation) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_presentation(instance);
        state.cached_presentation = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_keyboard(instance: *runtime.Instance) anyerror!Keyboard {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_keyboard) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_keyboard(instance);
        state.cached_keyboard = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_clipboard(instance: *runtime.Instance) anyerror!Clipboard {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_clipboard) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_clipboard(instance);
        state.cached_clipboard = value;
        return value;
    }

    pub fn get_audioSession(instance: *runtime.Instance) anyerror!AudioSession {
        return try NavigatorImpl.get_audioSession(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_mediaCapabilities(instance: *runtime.Instance) anyerror!MediaCapabilities {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_mediaCapabilities) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_mediaCapabilities(instance);
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
        const value = try NavigatorImpl.get_serial(instance);
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
        const value = try NavigatorImpl.get_permissions(instance);
        state.cached_permissions = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_contacts(instance: *runtime.Instance) anyerror!ContactsManager {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_contacts) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_contacts(instance);
        state.cached_contacts = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_devicePosture(instance: *runtime.Instance) anyerror!DevicePosture {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_devicePosture) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_devicePosture(instance);
        state.cached_devicePosture = value;
        return value;
    }

    pub fn get_maxTouchPoints(instance: *runtime.Instance) anyerror!i32 {
        return try NavigatorImpl.get_maxTouchPoints(instance);
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_attribution(instance: *runtime.Instance) anyerror!Attribution {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_attribution) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_attribution(instance);
        state.cached_attribution = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_smartCard(instance: *runtime.Instance) anyerror!SmartCardResourceManager {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_smartCard) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_smartCard(instance);
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
        const value = try NavigatorImpl.get_usb(instance);
        state.cached_usb = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_windowControlsOverlay(instance: *runtime.Instance) anyerror!WindowControlsOverlay {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_windowControlsOverlay) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_windowControlsOverlay(instance);
        state.cached_windowControlsOverlay = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_xr(instance: *runtime.Instance) anyerror!XRSystem {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_xr) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_xr(instance);
        state.cached_xr = value;
        return value;
    }

    pub fn get_deprecatedRunAdAuctionEnforcesKAnonymity(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorImpl.get_deprecatedRunAdAuctionEnforcesKAnonymity(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_protectedAudience(instance: *runtime.Instance) anyerror!ProtectedAudience {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_protectedAudience) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_protectedAudience(instance);
        state.cached_protectedAudience = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_hid(instance: *runtime.Instance) anyerror!HID {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_hid) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_hid(instance);
        state.cached_hid = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_credentials(instance: *runtime.Instance) anyerror!CredentialsContainer {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_credentials) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_credentials(instance);
        state.cached_credentials = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_wakeLock(instance: *runtime.Instance) anyerror!WakeLock {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_wakeLock) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_wakeLock(instance);
        state.cached_wakeLock = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_virtualKeyboard(instance: *runtime.Instance) anyerror!VirtualKeyboard {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_virtualKeyboard) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_virtualKeyboard(instance);
        state.cached_virtualKeyboard = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_preferences(instance: *runtime.Instance) anyerror!PreferenceManager {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_preferences) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_preferences(instance);
        state.cached_preferences = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_managed(instance: *runtime.Instance) anyerror!NavigatorManagedData {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_managed) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_managed(instance);
        state.cached_managed = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_serviceWorker(instance: *runtime.Instance) anyerror!ServiceWorkerContainer {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_serviceWorker) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_serviceWorker(instance);
        state.cached_serviceWorker = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_ink(instance: *runtime.Instance) anyerror!Ink {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_ink) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_ink(instance);
        state.cached_ink = value;
        return value;
    }

    /// Extended attributes: [LegacyUnforgeable], [SameObject]
    pub fn get_epubReadingSystem(instance: *runtime.Instance) anyerror!EpubReadingSystem {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_epubReadingSystem) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_epubReadingSystem(instance);
        state.cached_epubReadingSystem = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_userActivation(instance: *runtime.Instance) anyerror!UserActivation {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_userActivation) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_userActivation(instance);
        state.cached_userActivation = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_bluetooth(instance: *runtime.Instance) anyerror!Bluetooth {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_bluetooth) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_bluetooth(instance);
        state.cached_bluetooth = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_geolocation(instance: *runtime.Instance) anyerror!Geolocation {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_geolocation) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_geolocation(instance);
        state.cached_geolocation = value;
        return value;
    }

    /// Extended attributes: [SecureContext]
    pub fn get_login(instance: *runtime.Instance) anyerror!NavigatorLogin {
        return try NavigatorImpl.get_login(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_mediaSession(instance: *runtime.Instance) anyerror!MediaSession {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_mediaSession) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_mediaSession(instance);
        state.cached_mediaSession = value;
        return value;
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_mediaDevices(instance: *runtime.Instance) anyerror!MediaDevices {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_mediaDevices) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_mediaDevices(instance);
        state.cached_mediaDevices = value;
        return value;
    }

    pub fn get_locks(instance: *runtime.Instance) anyerror!LockManager {
        return try NavigatorImpl.get_locks(instance);
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_gpu(instance: *runtime.Instance) anyerror!GPU {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_gpu) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_gpu(instance);
        state.cached_gpu = value;
        return value;
    }

    pub fn get_globalPrivacyControl(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorImpl.get_globalPrivacyControl(instance);
    }

    pub fn get_webdriver(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorImpl.get_webdriver(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_connection(instance: *runtime.Instance) anyerror!NetworkInformation {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_connection) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_connection(instance);
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
        const value = try NavigatorImpl.get_ml(instance);
        state.cached_ml = value;
        return value;
    }

    pub fn get_deviceMemory(instance: *runtime.Instance) anyerror!f64 {
        return try NavigatorImpl.get_deviceMemory(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_storage(instance: *runtime.Instance) anyerror!StorageManager {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_storage) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_storage(instance);
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
        const value = try NavigatorImpl.get_storageBuckets(instance);
        state.cached_storageBuckets = value;
        return value;
    }

    pub fn get_appCodeName(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorImpl.get_appCodeName(instance);
    }

    pub fn get_appName(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorImpl.get_appName(instance);
    }

    pub fn get_appVersion(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorImpl.get_appVersion(instance);
    }

    pub fn get_platform(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorImpl.get_platform(instance);
    }

    pub fn get_product(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorImpl.get_product(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_productSub(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorImpl.get_productSub(instance);
    }

    pub fn get_userAgent(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorImpl.get_userAgent(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_vendor(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorImpl.get_vendor(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_vendorSub(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorImpl.get_vendorSub(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_oscpu(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorImpl.get_oscpu(instance);
    }

    pub fn get_language(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorImpl.get_language(instance);
    }

    pub fn get_languages(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigatorImpl.get_languages(instance);
    }

    pub fn get_onLine(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorImpl.get_onLine(instance);
    }

    pub fn get_cookieEnabled(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorImpl.get_cookieEnabled(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_plugins(instance: *runtime.Instance) anyerror!PluginArray {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_plugins) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_plugins(instance);
        state.cached_plugins = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_mimeTypes(instance: *runtime.Instance) anyerror!MimeTypeArray {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_mimeTypes) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_mimeTypes(instance);
        state.cached_mimeTypes = value;
        return value;
    }

    pub fn get_pdfViewerEnabled(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorImpl.get_pdfViewerEnabled(instance);
    }

    pub fn get_hardwareConcurrency(instance: *runtime.Instance) anyerror!u64 {
        return try NavigatorImpl.get_hardwareConcurrency(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_userAgentData(instance: *runtime.Instance) anyerror!NavigatorUAData {
        return try NavigatorImpl.get_userAgentData(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_requestMIDIAccess(instance: *runtime.Instance, options: MIDIOptions) anyerror!anyopaque {
        
        return try NavigatorImpl.call_requestMIDIAccess(instance, options);
    }

    pub fn call_adAuctionComponents(instance: *runtime.Instance, numAdComponents: u16) anyerror!anyopaque {
        
        return try NavigatorImpl.call_adAuctionComponents(instance, numAdComponents);
    }

    pub fn call_joinAdInterestGroup(instance: *runtime.Instance, group: AuctionAdInterestGroup) anyerror!anyopaque {
        
        return try NavigatorImpl.call_joinAdInterestGroup(instance, group);
    }

    pub fn call_vibrate(instance: *runtime.Instance, pattern: VibratePattern) anyerror!bool {
        
        return try NavigatorImpl.call_vibrate(instance, pattern);
    }

    pub fn call_createHandwritingRecognizer(instance: *runtime.Instance, constraint: HandwritingModelConstraint) anyerror!anyopaque {
        
        return try NavigatorImpl.call_createHandwritingRecognizer(instance, constraint);
    }

    pub fn call_leaveAdInterestGroup(instance: *runtime.Instance, group: AuctionAdInterestGroupKey) anyerror!anyopaque {
        
        return try NavigatorImpl.call_leaveAdInterestGroup(instance, group);
    }

    pub fn call_getGamepads(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigatorImpl.call_getGamepads(instance);
    }

    pub fn call_updateAdInterestGroups(instance: *runtime.Instance) anyerror!void {
        return try NavigatorImpl.call_updateAdInterestGroups(instance);
    }

    pub fn call_getBattery(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigatorImpl.call_getBattery(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_taintEnabled(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorImpl.call_taintEnabled(instance);
    }

    pub fn call_setAppBadge(instance: *runtime.Instance, contents: u64) anyerror!anyopaque {
        // [EnforceRange] on contents
        if (!runtime.isInRange(contents)) return error.TypeError;
        
        return try NavigatorImpl.call_setAppBadge(instance, contents);
    }

    pub fn call_canLoadAdAuctionFencedFrame(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorImpl.call_canLoadAdAuctionFencedFrame(instance);
    }

    pub fn call_createAuctionNonce(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigatorImpl.call_createAuctionNonce(instance);
    }

    pub fn call_sendBeacon(instance: *runtime.Instance, url: runtime.USVString, data: anyopaque) anyerror!bool {
        
        return try NavigatorImpl.call_sendBeacon(instance, url, data);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_unregisterProtocolHandler(instance: *runtime.Instance, scheme: DOMString, url: runtime.USVString) anyerror!void {
        
        return try NavigatorImpl.call_unregisterProtocolHandler(instance, scheme, url);
    }

    pub fn call_queryHandwritingRecognizer(instance: *runtime.Instance, constraint: HandwritingModelConstraint) anyerror!anyopaque {
        
        return try NavigatorImpl.call_queryHandwritingRecognizer(instance, constraint);
    }

    pub fn call_clearAppBadge(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigatorImpl.call_clearAppBadge(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_share(instance: *runtime.Instance, data: ShareData) anyerror!anyopaque {
        
        return try NavigatorImpl.call_share(instance, data);
    }

    pub fn call_runAdAuction(instance: *runtime.Instance, config: AuctionAdConfig) anyerror!anyopaque {
        
        return try NavigatorImpl.call_runAdAuction(instance, config);
    }

    pub fn call_deprecatedReplaceInURN(instance: *runtime.Instance, urnOrConfig: UrnOrConfig, replacements: anyopaque) anyerror!anyopaque {
        
        return try NavigatorImpl.call_deprecatedReplaceInURN(instance, urnOrConfig, replacements);
    }

    /// Arguments for getAutoplayPolicy (WebIDL overloading)
    pub const GetAutoplayPolicyArgs = union(enum) {
        /// getAutoplayPolicy(type)
        AutoplayPolicyMediaType: AutoplayPolicyMediaType,
        /// getAutoplayPolicy(element)
        HTMLMediaElement: HTMLMediaElement,
        /// getAutoplayPolicy(context)
        AudioContext: AudioContext,
    };

    pub fn call_getAutoplayPolicy(instance: *runtime.Instance, args: GetAutoplayPolicyArgs) anyerror!AutoplayPolicy {
        switch (args) {
            .AutoplayPolicyMediaType => |arg| return try NavigatorImpl.AutoplayPolicyMediaType(instance, arg),
            .HTMLMediaElement => |arg| return try NavigatorImpl.HTMLMediaElement(instance, arg),
            .AudioContext => |arg| return try NavigatorImpl.AudioContext(instance, arg),
        }
    }

    pub fn call_javaEnabled(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorImpl.call_javaEnabled(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_getInstalledRelatedApps(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigatorImpl.call_getInstalledRelatedApps(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_canShare(instance: *runtime.Instance, data: ShareData) anyerror!bool {
        
        return try NavigatorImpl.call_canShare(instance, data);
    }

    pub fn call_clearOriginJoinedAdInterestGroups(instance: *runtime.Instance, owner: runtime.USVString, interestGroupsToKeep: anyopaque) anyerror!anyopaque {
        
        return try NavigatorImpl.call_clearOriginJoinedAdInterestGroups(instance, owner, interestGroupsToKeep);
    }

    pub fn call_getInterestGroupAdAuctionData(instance: *runtime.Instance, config: AdAuctionDataConfig) anyerror!anyopaque {
        
        return try NavigatorImpl.call_getInterestGroupAdAuctionData(instance, config);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_requestMediaKeySystemAccess(instance: *runtime.Instance, keySystem: DOMString, supportedConfigurations: anyopaque) anyerror!anyopaque {
        
        return try NavigatorImpl.call_requestMediaKeySystemAccess(instance, keySystem, supportedConfigurations);
    }

    pub fn call_deprecatedURNtoURL(instance: *runtime.Instance, urnOrConfig: UrnOrConfig, send_reports: bool) anyerror!anyopaque {
        
        return try NavigatorImpl.call_deprecatedURNtoURL(instance, urnOrConfig, send_reports);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_registerProtocolHandler(instance: *runtime.Instance, scheme: DOMString, url: runtime.USVString) anyerror!void {
        
        return try NavigatorImpl.call_registerProtocolHandler(instance, scheme, url);
    }

};
