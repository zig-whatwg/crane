//! Generated from: html.idl
//! Generated at: 2025-11-29T05:01:32Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorImpl = @import("impls").Navigator;
const mixins = @import("mixins");
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
const HID = @import("interfaces").HID;
const PreferenceManager = @import("interfaces").PreferenceManager;
const AuctionAdConfig = @import("dictionaries").AuctionAdConfig;
const USVString = @import("interfaces").USVString;
const MediaKeySystemAccess = @import("interfaces").MediaKeySystemAccess;
const VibratePattern = @import("typedefs").VibratePattern;
const BatteryManager = @import("interfaces").BatteryManager;
const NetworkInformation = @import("interfaces").NetworkInformation;
const ML = @import("interfaces").ML;
const StorageBucketManager = @import("interfaces").StorageBucketManager;
const BodyInit = @import("typedefs").BodyInit;
const HandwritingRecognizer = @import("interfaces").HandwritingRecognizer;
const MIDIAccess = @import("interfaces").MIDIAccess;
const AuctionAdInterestGroupKey = @import("dictionaries").AuctionAdInterestGroupKey;
const Attribution = @import("interfaces").Attribution;
const ShareData = @import("dictionaries").ShareData;
const Scheduling = @import("interfaces").Scheduling;
const VirtualKeyboard = @import("interfaces").VirtualKeyboard;
const AutoplayPolicy = @import("enums").AutoplayPolicy;
const Clipboard = @import("interfaces").Clipboard;
const HandwritingModelConstraint = @import("dictionaries").HandwritingModelConstraint;
const StorageManager = @import("interfaces").StorageManager;
const MediaKeySystemConfiguration = @import("dictionaries").MediaKeySystemConfiguration;
const AudioSession = @import("interfaces").AudioSession;
const CredentialsContainer = @import("interfaces").CredentialsContainer;
const ServiceWorkerContainer = @import("interfaces").ServiceWorkerContainer;
const HTMLMediaElement = @import("interfaces").HTMLMediaElement;
const MediaDevices = @import("interfaces").MediaDevices;
const NavigatorManagedData = @import("interfaces").NavigatorManagedData;
const DOMString = @import("typedefs").DOMString;
const Permissions = @import("interfaces").Permissions;
const LockManager = @import("interfaces").LockManager;
const AudioContext = @import("interfaces").AudioContext;
const HandwritingRecognizerQueryResult = @import("dictionaries").HandwritingRecognizerQueryResult;
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
const AdAuctionData = @import("dictionaries").AdAuctionData;
const MIDIOptions = @import("dictionaries").MIDIOptions;
const Ink = @import("interfaces").Ink;
const XRSystem = @import("interfaces").XRSystem;
const AuctionAdInterestGroup = @import("dictionaries").AuctionAdInterestGroup;
const Keyboard = @import("interfaces").Keyboard;
const WindowControlsOverlay = @import("interfaces").WindowControlsOverlay;
const UserActivation = @import("interfaces").UserActivation;
const MediaCapabilities = @import("interfaces").MediaCapabilities;

pub const Navigator = struct {
    pub const Meta = struct {
        pub const name = "Navigator";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{
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
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "scheduling", "get_scheduling", null },
            .{ "presentation", "get_presentation", null },
            .{ "keyboard", "get_keyboard", null },
            .{ "clipboard", "get_clipboard", null },
            .{ "audioSession", "get_audioSession", null },
            .{ "mediaCapabilities", "get_mediaCapabilities", null },
            .{ "serial", "get_serial", null },
            .{ "permissions", "get_permissions", null },
            .{ "contacts", "get_contacts", null },
            .{ "devicePosture", "get_devicePosture", null },
            .{ "maxTouchPoints", "get_maxTouchPoints", null },
            .{ "attribution", "get_attribution", null },
            .{ "smartCard", "get_smartCard", null },
            .{ "usb", "get_usb", null },
            .{ "windowControlsOverlay", "get_windowControlsOverlay", null },
            .{ "xr", "get_xr", null },
            .{ "deprecatedRunAdAuctionEnforcesKAnonymity", "get_deprecatedRunAdAuctionEnforcesKAnonymity", null },
            .{ "protectedAudience", "get_protectedAudience", null },
            .{ "hid", "get_hid", null },
            .{ "credentials", "get_credentials", null },
            .{ "wakeLock", "get_wakeLock", null },
            .{ "virtualKeyboard", "get_virtualKeyboard", null },
            .{ "preferences", "get_preferences", null },
            .{ "managed", "get_managed", null },
            .{ "serviceWorker", "get_serviceWorker", null },
            .{ "ink", "get_ink", null },
            .{ "epubReadingSystem", "get_epubReadingSystem", null },
            .{ "userActivation", "get_userActivation", null },
            .{ "bluetooth", "get_bluetooth", null },
            .{ "geolocation", "get_geolocation", null },
            .{ "login", "get_login", null },
            .{ "mediaSession", "get_mediaSession", null },
            .{ "mediaDevices", "get_mediaDevices", null },
            .{ "locks", "get_locks", null },
            .{ "gpu", "get_gpu", null },
            .{ "globalPrivacyControl", "get_globalPrivacyControl", null },
            .{ "webdriver", "get_webdriver", null },
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
            .{ "cookieEnabled", "get_cookieEnabled", null },
            .{ "plugins", "get_plugins", null },
            .{ "mimeTypes", "get_mimeTypes", null },
            .{ "pdfViewerEnabled", "get_pdfViewerEnabled", null },
            .{ "hardwareConcurrency", "get_hardwareConcurrency", null },
            .{ "userAgentData", "get_userAgentData", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "sendBeacon", "call_sendBeacon", 1 },
            .{ "getInstalledRelatedApps", "call_getInstalledRelatedApps", 0 },
            .{ "queryHandwritingRecognizer", "call_queryHandwritingRecognizer", 1 },
            .{ "createHandwritingRecognizer", "call_createHandwritingRecognizer", 1 },
            .{ "requestMIDIAccess", "call_requestMIDIAccess", 0 },
            .{ "deprecatedReplaceInURN", "call_deprecatedReplaceInURN", 2 },
            .{ "deprecatedURNtoURL", "call_deprecatedURNtoURL", 1 },
            .{ "adAuctionComponents", "call_adAuctionComponents", 1 },
            .{ "share", "call_share", 0 },
            .{ "canShare", "call_canShare", 0 },
            .{ "joinAdInterestGroup", "call_joinAdInterestGroup", 1 },
            .{ "leaveAdInterestGroup", "call_leaveAdInterestGroup", 0 },
            .{ "clearOriginJoinedAdInterestGroups", "call_clearOriginJoinedAdInterestGroups", 1 },
            .{ "runAdAuction", "call_runAdAuction", 1 },
            .{ "canLoadAdAuctionFencedFrame", "call_canLoadAdAuctionFencedFrame", 0 },
            .{ "getInterestGroupAdAuctionData", "call_getInterestGroupAdAuctionData", 0 },
            .{ "createAuctionNonce", "call_createAuctionNonce", 0 },
            .{ "updateAdInterestGroups", "call_updateAdInterestGroups", 0 },
            .{ "getBattery", "call_getBattery", 0 },
            .{ "requestMediaKeySystemAccess", "call_requestMediaKeySystemAccess", 2 },
            .{ "vibrate", "call_vibrate", 1 },
            .{ "getAutoplayPolicy", "call_getAutoplayPolicy", 1 },
            .{ "getAutoplayPolicy", "call_getAutoplayPolicy", 1 },
            .{ "getAutoplayPolicy", "call_getAutoplayPolicy", 1 },
            .{ "getGamepads", "call_getGamepads", 0 },
            .{ "taintEnabled", "call_taintEnabled", 0 },
            .{ "registerProtocolHandler", "call_registerProtocolHandler", 2 },
            .{ "unregisterProtocolHandler", "call_unregisterProtocolHandler", 2 },
            .{ "javaEnabled", "call_javaEnabled", 0 },
            .{ "setAppBadge", "call_setAppBadge", 0 },
            .{ "clearAppBadge", "call_clearAppBadge", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "sendBeacon",
            "getInstalledRelatedApps",
            "queryHandwritingRecognizer",
            "createHandwritingRecognizer",
            "requestMIDIAccess",
            "deprecatedReplaceInURN",
            "deprecatedURNtoURL",
            "adAuctionComponents",
            "share",
            "canShare",
            "joinAdInterestGroup",
            "leaveAdInterestGroup",
            "clearOriginJoinedAdInterestGroups",
            "runAdAuction",
            "canLoadAdAuctionFencedFrame",
            "getInterestGroupAdAuctionData",
            "createAuctionNonce",
            "updateAdInterestGroups",
            "getBattery",
            "requestMediaKeySystemAccess",
            "vibrate",
            "getAutoplayPolicy",
            "getAutoplayPolicy",
            "getAutoplayPolicy",
            "getGamepads",
            "taintEnabled",
            "registerProtocolHandler",
            "unregisterProtocolHandler",
            "javaEnabled",
            "setAppBadge",
            "clearAppBadge",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "scheduling", "get_scheduling", null },
            .{ "presentation", "get_presentation", null },
            .{ "keyboard", "get_keyboard", null },
            .{ "clipboard", "get_clipboard", null },
            .{ "audioSession", "get_audioSession", null },
            .{ "mediaCapabilities", "get_mediaCapabilities", null },
            .{ "serial", "get_serial", null },
            .{ "permissions", "get_permissions", null },
            .{ "contacts", "get_contacts", null },
            .{ "devicePosture", "get_devicePosture", null },
            .{ "maxTouchPoints", "get_maxTouchPoints", null },
            .{ "attribution", "get_attribution", null },
            .{ "smartCard", "get_smartCard", null },
            .{ "usb", "get_usb", null },
            .{ "windowControlsOverlay", "get_windowControlsOverlay", null },
            .{ "xr", "get_xr", null },
            .{ "deprecatedRunAdAuctionEnforcesKAnonymity", "get_deprecatedRunAdAuctionEnforcesKAnonymity", null },
            .{ "protectedAudience", "get_protectedAudience", null },
            .{ "hid", "get_hid", null },
            .{ "credentials", "get_credentials", null },
            .{ "wakeLock", "get_wakeLock", null },
            .{ "virtualKeyboard", "get_virtualKeyboard", null },
            .{ "preferences", "get_preferences", null },
            .{ "managed", "get_managed", null },
            .{ "serviceWorker", "get_serviceWorker", null },
            .{ "ink", "get_ink", null },
            .{ "epubReadingSystem", "get_epubReadingSystem", null },
            .{ "userActivation", "get_userActivation", null },
            .{ "bluetooth", "get_bluetooth", null },
            .{ "geolocation", "get_geolocation", null },
            .{ "login", "get_login", null },
            .{ "mediaSession", "get_mediaSession", null },
            .{ "mediaDevices", "get_mediaDevices", null },
            .{ "locks", "get_locks", null },
            .{ "gpu", "get_gpu", null },
            .{ "globalPrivacyControl", "get_globalPrivacyControl", null },
            .{ "webdriver", "get_webdriver", null },
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
            .{ "cookieEnabled", "get_cookieEnabled", null },
            .{ "plugins", "get_plugins", null },
            .{ "mimeTypes", "get_mimeTypes", null },
            .{ "pdfViewerEnabled", "get_pdfViewerEnabled", null },
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
            scheduling: *runtime.Instance = undefined,
            presentation: *runtime.Instance = undefined,
            keyboard: *runtime.Instance = undefined,
            clipboard: *runtime.Instance = undefined,
            audioSession: *runtime.Instance = undefined,
            mediaCapabilities: *runtime.Instance = undefined,
            serial: *runtime.Instance = undefined,
            permissions: *runtime.Instance = undefined,
            contacts: *runtime.Instance = undefined,
            devicePosture: *runtime.Instance = undefined,
            maxTouchPoints: i32 = undefined,
            attribution: *runtime.Instance = undefined,
            smartCard: *runtime.Instance = undefined,
            usb: *runtime.Instance = undefined,
            windowControlsOverlay: *runtime.Instance = undefined,
            xr: *runtime.Instance = undefined,
            deprecatedRunAdAuctionEnforcesKAnonymity: bool = undefined,
            protectedAudience: *runtime.Instance = undefined,
            hid: *runtime.Instance = undefined,
            credentials: *runtime.Instance = undefined,
            wakeLock: *runtime.Instance = undefined,
            virtualKeyboard: *runtime.Instance = undefined,
            preferences: *runtime.Instance = undefined,
            managed: *runtime.Instance = undefined,
            serviceWorker: *runtime.Instance = undefined,
            ink: *runtime.Instance = undefined,
            epubReadingSystem: *runtime.Instance = undefined,
            userActivation: *runtime.Instance = undefined,
            bluetooth: *runtime.Instance = undefined,
            geolocation: *runtime.Instance = undefined,
            login: *runtime.Instance = undefined,
            mediaSession: *runtime.Instance = undefined,
            mediaDevices: *runtime.Instance = undefined,
            locks: *runtime.Instance = undefined,
            gpu: *runtime.Instance = undefined,
            globalPrivacyControl: bool = undefined,
            webdriver: bool = undefined,
            connection: *runtime.Instance = undefined,
            ml: *runtime.Instance = undefined,
            deviceMemory: f64 = undefined,
            storage: *runtime.Instance = undefined,
            storageBuckets: *runtime.Instance = undefined,
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
            languages: runtime.FrozenArray(runtime.DOMString) = undefined,
            onLine: bool = undefined,
            cookieEnabled: bool = undefined,
            plugins: *runtime.Instance = undefined,
            mimeTypes: *runtime.Instance = undefined,
            pdfViewerEnabled: bool = undefined,
            hardwareConcurrency: u64 = undefined,
            userAgentData: *runtime.Instance = undefined,
            cached_presentation: ?*runtime.Instance = null,
            cached_keyboard: ?*runtime.Instance = null,
            cached_clipboard: ?*runtime.Instance = null,
            cached_mediaCapabilities: ?*runtime.Instance = null,
            cached_serial: ?*runtime.Instance = null,
            cached_permissions: ?*runtime.Instance = null,
            cached_contacts: ?*runtime.Instance = null,
            cached_devicePosture: ?*runtime.Instance = null,
            cached_attribution: ?*runtime.Instance = null,
            cached_smartCard: ?*runtime.Instance = null,
            cached_usb: ?*runtime.Instance = null,
            cached_windowControlsOverlay: ?*runtime.Instance = null,
            cached_xr: ?*runtime.Instance = null,
            cached_protectedAudience: ?*runtime.Instance = null,
            cached_hid: ?*runtime.Instance = null,
            cached_credentials: ?*runtime.Instance = null,
            cached_wakeLock: ?*runtime.Instance = null,
            cached_virtualKeyboard: ?*runtime.Instance = null,
            cached_preferences: ?*runtime.Instance = null,
            cached_managed: ?*runtime.Instance = null,
            cached_serviceWorker: ?*runtime.Instance = null,
            cached_ink: ?*runtime.Instance = null,
            cached_epubReadingSystem: ?*runtime.Instance = null,
            cached_userActivation: ?*runtime.Instance = null,
            cached_bluetooth: ?*runtime.Instance = null,
            cached_geolocation: ?*runtime.Instance = null,
            cached_mediaSession: ?*runtime.Instance = null,
            cached_mediaDevices: ?*runtime.Instance = null,
            cached_gpu: ?*runtime.Instance = null,
            cached_connection: ?*runtime.Instance = null,
            cached_ml: ?*runtime.Instance = null,
            cached_storage: ?*runtime.Instance = null,
            cached_storageBuckets: ?*runtime.Instance = null,
            cached_plugins: ?*runtime.Instance = null,
            cached_mimeTypes: ?*runtime.Instance = null,
            _internal: ?*NavigatorImpl.InternalState = null,
        },
    );

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NavigatorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorImpl.deinit(instance);
    }

    pub fn get_scheduling(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try NavigatorImpl.get_scheduling(instance);
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_presentation(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_presentation) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_presentation(instance);
        state.own.cached_presentation = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_keyboard(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_keyboard) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_keyboard(instance);
        state.own.cached_keyboard = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_clipboard(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_clipboard) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_clipboard(instance);
        state.own.cached_clipboard = value;
        return value;
    }

    pub fn get_audioSession(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try NavigatorImpl.get_audioSession(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_mediaCapabilities(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_mediaCapabilities) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_mediaCapabilities(instance);
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
        const value = try NavigatorImpl.get_serial(instance);
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
        const value = try NavigatorImpl.get_permissions(instance);
        state.own.cached_permissions = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_contacts(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_contacts) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_contacts(instance);
        state.own.cached_contacts = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_devicePosture(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_devicePosture) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_devicePosture(instance);
        state.own.cached_devicePosture = value;
        return value;
    }

    pub fn get_maxTouchPoints(instance: *runtime.Instance) anyerror!i32 {
        return try NavigatorImpl.get_maxTouchPoints(instance);
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_attribution(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_attribution) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_attribution(instance);
        state.own.cached_attribution = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_smartCard(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_smartCard) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_smartCard(instance);
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
        const value = try NavigatorImpl.get_usb(instance);
        state.own.cached_usb = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_windowControlsOverlay(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_windowControlsOverlay) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_windowControlsOverlay(instance);
        state.own.cached_windowControlsOverlay = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_xr(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_xr) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_xr(instance);
        state.own.cached_xr = value;
        return value;
    }

    pub fn get_deprecatedRunAdAuctionEnforcesKAnonymity(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorImpl.get_deprecatedRunAdAuctionEnforcesKAnonymity(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_protectedAudience(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_protectedAudience) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_protectedAudience(instance);
        state.own.cached_protectedAudience = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_hid(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_hid) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_hid(instance);
        state.own.cached_hid = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_credentials(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_credentials) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_credentials(instance);
        state.own.cached_credentials = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_wakeLock(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_wakeLock) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_wakeLock(instance);
        state.own.cached_wakeLock = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_virtualKeyboard(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_virtualKeyboard) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_virtualKeyboard(instance);
        state.own.cached_virtualKeyboard = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_preferences(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_preferences) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_preferences(instance);
        state.own.cached_preferences = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_managed(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_managed) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_managed(instance);
        state.own.cached_managed = value;
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_serviceWorker(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_serviceWorker) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_serviceWorker(instance);
        state.own.cached_serviceWorker = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_ink(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_ink) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_ink(instance);
        state.own.cached_ink = value;
        return value;
    }

    /// Extended attributes: [LegacyUnforgeable], [SameObject]
    pub fn get_epubReadingSystem(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_epubReadingSystem) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_epubReadingSystem(instance);
        state.own.cached_epubReadingSystem = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_userActivation(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_userActivation) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_userActivation(instance);
        state.own.cached_userActivation = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_bluetooth(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_bluetooth) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_bluetooth(instance);
        state.own.cached_bluetooth = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_geolocation(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_geolocation) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_geolocation(instance);
        state.own.cached_geolocation = value;
        return value;
    }

    /// Extended attributes: [SecureContext]
    pub fn get_login(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try NavigatorImpl.get_login(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_mediaSession(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_mediaSession) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_mediaSession(instance);
        state.own.cached_mediaSession = value;
        return value;
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_mediaDevices(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_mediaDevices) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_mediaDevices(instance);
        state.own.cached_mediaDevices = value;
        return value;
    }

    pub fn get_locks(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try NavigatorImpl.get_locks(instance);
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_gpu(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_gpu) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_gpu(instance);
        state.own.cached_gpu = value;
        return value;
    }

    pub fn get_globalPrivacyControl(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorImpl.get_globalPrivacyControl(instance);
    }

    pub fn get_webdriver(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorImpl.get_webdriver(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_connection(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_connection) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_connection(instance);
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
        const value = try NavigatorImpl.get_ml(instance);
        state.own.cached_ml = value;
        return value;
    }

    pub fn get_deviceMemory(instance: *runtime.Instance) anyerror!f64 {
        return try NavigatorImpl.get_deviceMemory(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_storage(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_storage) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_storage(instance);
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
        const value = try NavigatorImpl.get_storageBuckets(instance);
        state.own.cached_storageBuckets = value;
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

    pub fn get_languages(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try NavigatorImpl.get_languages(instance);
    }

    pub fn get_onLine(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorImpl.get_onLine(instance);
    }

    pub fn get_cookieEnabled(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorImpl.get_cookieEnabled(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_plugins(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_plugins) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_plugins(instance);
        state.own.cached_plugins = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_mimeTypes(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_mimeTypes) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_mimeTypes(instance);
        state.own.cached_mimeTypes = value;
        return value;
    }

    pub fn get_pdfViewerEnabled(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorImpl.get_pdfViewerEnabled(instance);
    }

    pub fn get_hardwareConcurrency(instance: *runtime.Instance) anyerror!u64 {
        return try NavigatorImpl.get_hardwareConcurrency(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_userAgentData(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try NavigatorImpl.get_userAgentData(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_requestMIDIAccess(instance: *runtime.Instance, options: webidl.Opt(MIDIOptions)) anyerror!*const anyopaque {
        
        return try NavigatorImpl.call_requestMIDIAccess(instance, options);
    }

    pub fn call_adAuctionComponents(instance: *runtime.Instance, numAdComponents: u16) anyerror!*const anyopaque {
        
        return try NavigatorImpl.call_adAuctionComponents(instance, numAdComponents);
    }

    pub fn call_joinAdInterestGroup(instance: *runtime.Instance, group: AuctionAdInterestGroup) anyerror!*const anyopaque {
        
        return try NavigatorImpl.call_joinAdInterestGroup(instance, group);
    }

    pub fn call_vibrate(instance: *runtime.Instance, pattern: VibratePattern) anyerror!bool {
        
        return try NavigatorImpl.call_vibrate(instance, pattern);
    }

    pub fn call_createHandwritingRecognizer(instance: *runtime.Instance, constraint: HandwritingModelConstraint) anyerror!*const anyopaque {
        
        return try NavigatorImpl.call_createHandwritingRecognizer(instance, constraint);
    }

    pub fn call_leaveAdInterestGroup(instance: *runtime.Instance, group: webidl.Opt(AuctionAdInterestGroupKey)) anyerror!*const anyopaque {
        
        return try NavigatorImpl.call_leaveAdInterestGroup(instance, group);
    }

    pub fn call_getGamepads(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try NavigatorImpl.call_getGamepads(instance);
    }

    pub fn call_updateAdInterestGroups(instance: *runtime.Instance) anyerror!void {
        return try NavigatorImpl.call_updateAdInterestGroups(instance);
    }

    pub fn call_getBattery(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try NavigatorImpl.call_getBattery(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_taintEnabled(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorImpl.call_taintEnabled(instance);
    }

    pub fn call_setAppBadge(instance: *runtime.Instance, contents: webidl.Opt(u64)) anyerror!*const anyopaque {
        // [EnforceRange] on contents
        if (!runtime.isInRange(u64, contents)) return error.TypeError;
        
        return try NavigatorImpl.call_setAppBadge(instance, contents);
    }

    pub fn call_canLoadAdAuctionFencedFrame(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorImpl.call_canLoadAdAuctionFencedFrame(instance);
    }

    pub fn call_createAuctionNonce(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try NavigatorImpl.call_createAuctionNonce(instance);
    }

    pub fn call_sendBeacon(instance: *runtime.Instance, url: runtime.USVString, data: webidl.Opt(?BodyInit)) anyerror!bool {
        
        return try NavigatorImpl.call_sendBeacon(instance, url, data);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_unregisterProtocolHandler(instance: *runtime.Instance, scheme: DOMString, url: runtime.USVString) anyerror!void {
        
        return try NavigatorImpl.call_unregisterProtocolHandler(instance, scheme, url);
    }

    pub fn call_queryHandwritingRecognizer(instance: *runtime.Instance, constraint: HandwritingModelConstraint) anyerror!*const anyopaque {
        
        return try NavigatorImpl.call_queryHandwritingRecognizer(instance, constraint);
    }

    pub fn call_clearAppBadge(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try NavigatorImpl.call_clearAppBadge(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_share(instance: *runtime.Instance, data: webidl.Opt(ShareData)) anyerror!*const anyopaque {
        
        return try NavigatorImpl.call_share(instance, data);
    }

    pub fn call_runAdAuction(instance: *runtime.Instance, config: AuctionAdConfig) anyerror!*const anyopaque {
        
        return try NavigatorImpl.call_runAdAuction(instance, config);
    }

    pub fn call_deprecatedReplaceInURN(instance: *runtime.Instance, urnOrConfig: UrnOrConfig, replacements: *const anyopaque) anyerror!*const anyopaque {
        
        return try NavigatorImpl.call_deprecatedReplaceInURN(instance, urnOrConfig, replacements);
    }

    pub fn call_getAutoplayPolicy(instance: *runtime.Instance, @"type": AutoplayPolicyMediaType) anyerror!AutoplayPolicy {
        
        return try NavigatorImpl.call_getAutoplayPolicy(instance, @"type");
    }

    pub fn call_javaEnabled(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorImpl.call_javaEnabled(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_getInstalledRelatedApps(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try NavigatorImpl.call_getInstalledRelatedApps(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_canShare(instance: *runtime.Instance, data: webidl.Opt(ShareData)) anyerror!bool {
        
        return try NavigatorImpl.call_canShare(instance, data);
    }

    pub fn call_clearOriginJoinedAdInterestGroups(instance: *runtime.Instance, owner: runtime.USVString, interestGroupsToKeep: webidl.Opt(*const anyopaque)) anyerror!*const anyopaque {
        
        return try NavigatorImpl.call_clearOriginJoinedAdInterestGroups(instance, owner, interestGroupsToKeep);
    }

    pub fn call_getInterestGroupAdAuctionData(instance: *runtime.Instance, config: webidl.Opt(AdAuctionDataConfig)) anyerror!*const anyopaque {
        
        return try NavigatorImpl.call_getInterestGroupAdAuctionData(instance, config);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_requestMediaKeySystemAccess(instance: *runtime.Instance, keySystem: DOMString, supportedConfigurations: *const anyopaque) anyerror!*const anyopaque {
        
        return try NavigatorImpl.call_requestMediaKeySystemAccess(instance, keySystem, supportedConfigurations);
    }

    pub fn call_deprecatedURNtoURL(instance: *runtime.Instance, urnOrConfig: UrnOrConfig, send_reports: webidl.Opt(bool)) anyerror!*const anyopaque {
        
        return try NavigatorImpl.call_deprecatedURNtoURL(instance, urnOrConfig, send_reports);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_registerProtocolHandler(instance: *runtime.Instance, scheme: DOMString, url: runtime.USVString) anyerror!void {
        
        return try NavigatorImpl.call_registerProtocolHandler(instance, scheme, url);
    }

};
