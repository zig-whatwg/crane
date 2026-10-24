//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorImpl = @import("impls").Navigator;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const NavigatorBadge = @import("mixins").NavigatorBadge;
const NavigatorCrossOriginStorage = @import("mixins").NavigatorCrossOriginStorage;
const NavigatorDeviceMemory = @import("mixins").NavigatorDeviceMemory;
const GlobalPrivacyControl = @import("mixins").GlobalPrivacyControl;
const NavigatorID = @import("mixins").NavigatorID;
const NavigatorLanguage = @import("mixins").NavigatorLanguage;
const NavigatorOnLine = @import("mixins").NavigatorOnLine;
const NavigatorContentUtils = @import("mixins").NavigatorContentUtils;
const NavigatorCookies = @import("mixins").NavigatorCookies;
const NavigatorPlugins = @import("mixins").NavigatorPlugins;
const NavigatorConcurrentHardware = @import("mixins").NavigatorConcurrentHardware;
const NavigatorNetworkInformation = @import("mixins").NavigatorNetworkInformation;
const NavigatorStorageBuckets = @import("mixins").NavigatorStorageBuckets;
const NavigatorStorage = @import("mixins").NavigatorStorage;
const NavigatorUA = @import("mixins").NavigatorUA;
const NavigatorLocks = @import("mixins").NavigatorLocks;
const NavigatorAutomationInformation = @import("mixins").NavigatorAutomationInformation;
const NavigatorGPU = @import("mixins").NavigatorGPU;
const NavigatorML = @import("mixins").NavigatorML;
const MimeTypeArray = @import("interfaces").MimeTypeArray;
const UrnOrConfig = @import("typedefs").UrnOrConfig;
const Serial = @import("interfaces").Serial;
const Presentation = @import("interfaces").Presentation;
const PreferenceManager = @import("interfaces").PreferenceManager;
const MediaKeySystemAccess = @import("interfaces").MediaKeySystemAccess;
const WebInstallResult = @import("dictionaries").WebInstallResult;
const VibratePattern = @import("typedefs").VibratePattern;
const HID = @import("interfaces").HID;
const USVString = @import("typedefs").USVString;
const NetworkInformation = @import("interfaces").NetworkInformation;
const ML = @import("interfaces").ML;
const BatteryManager = @import("interfaces").BatteryManager;
const StorageBucketManager = @import("interfaces").StorageBucketManager;
const BodyInit = @import("typedefs").BodyInit;
const HandwritingRecognizer = @import("interfaces").HandwritingRecognizer;
const MIDIAccess = @import("interfaces").MIDIAccess;
const Attribution = @import("interfaces").Attribution;
const VirtualKeyboard = @import("interfaces").VirtualKeyboard;
const AutoplayPolicy = @import("enums").AutoplayPolicy;
const Scheduling = @import("interfaces").Scheduling;
const ShareData = @import("dictionaries").ShareData;
const Clipboard = @import("interfaces").Clipboard;
const HandwritingModelConstraint = @import("dictionaries").HandwritingModelConstraint;
const CrossOriginStorageManager = @import("interfaces").CrossOriginStorageManager;
const StorageManager = @import("interfaces").StorageManager;
const MediaKeySystemConfiguration = @import("dictionaries").MediaKeySystemConfiguration;
const AudioSession = @import("interfaces").AudioSession;
const CredentialsContainer = @import("interfaces").CredentialsContainer;
const ServiceWorkerContainer = @import("interfaces").ServiceWorkerContainer;
const HTMLMediaElement = @import("interfaces").HTMLMediaElement;
const MediaDevices = @import("interfaces").MediaDevices;
const DOMString = @import("typedefs").DOMString;
const Permissions = @import("interfaces").Permissions;
const NavigatorManagedData = @import("interfaces").NavigatorManagedData;
const LockManager = @import("interfaces").LockManager;
const AudioContext = @import("interfaces").AudioContext;
const HandwritingRecognizerQueryResult = @import("dictionaries").HandwritingRecognizerQueryResult;
const ContactsManager = @import("interfaces").ContactsManager;
const DevicePosture = @import("interfaces").DevicePosture;
const Geolocation = @import("interfaces").Geolocation;
const PluginArray = @import("interfaces").PluginArray;
const NavigatorUAData = @import("interfaces").NavigatorUAData;
const WakeLock = @import("interfaces").WakeLock;
const GPU = @import("interfaces").GPU;
const MediaSession = @import("interfaces").MediaSession;
const NavigatorLogin = @import("interfaces").NavigatorLogin;
const EpubReadingSystem = @import("interfaces").EpubReadingSystem;
const Bluetooth = @import("interfaces").Bluetooth;
const USB = @import("interfaces").USB;
const AutoplayPolicyMediaType = @import("enums").AutoplayPolicyMediaType;
const MIDIOptions = @import("dictionaries").MIDIOptions;
const Ink = @import("interfaces").Ink;
const XRSystem = @import("interfaces").XRSystem;
const Keyboard = @import("interfaces").Keyboard;
const WindowControlsOverlay = @import("interfaces").WindowControlsOverlay;
const UserActivation = @import("interfaces").UserActivation;
const MediaCapabilities = @import("interfaces").MediaCapabilities;
const InstallParams = @import("dictionaries").InstallParams;

pub const Navigator = struct {
    pub const Meta = struct {
        pub const name = "Navigator";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{
            NavigatorBadge,
            NavigatorCrossOriginStorage,
            NavigatorDeviceMemory,
            GlobalPrivacyControl,
            NavigatorID,
            NavigatorLanguage,
            NavigatorOnLine,
            NavigatorContentUtils,
            NavigatorCookies,
            NavigatorPlugins,
            NavigatorConcurrentHardware,
            NavigatorNetworkInformation,
            NavigatorStorageBuckets,
            NavigatorStorage,
            NavigatorUA,
            NavigatorLocks,
            NavigatorAutomationInformation,
            NavigatorGPU,
            NavigatorML,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "attribution", "get_attribution", null },
            .{ "audioSession", "get_audioSession", null },
            .{ "clipboard", "get_clipboard", null },
            .{ "contacts", "get_contacts", null },
            .{ "cpuPerformance", "get_cpuPerformance", null },
            .{ "credentials", "get_credentials", null },
            .{ "devicePosture", "get_devicePosture", null },
            .{ "epubReadingSystem", "get_epubReadingSystem", null },
            .{ "geolocation", "get_geolocation", null },
            .{ "userActivation", "get_userActivation", null },
            .{ "ink", "get_ink", null },
            .{ "scheduling", "get_scheduling", null },
            .{ "keyboard", "get_keyboard", null },
            .{ "login", "get_login", null },
            .{ "managed", "get_managed", null },
            .{ "mediaCapabilities", "get_mediaCapabilities", null },
            .{ "mediaDevices", "get_mediaDevices", null },
            .{ "preferences", "get_preferences", null },
            .{ "mediaSession", "get_mediaSession", null },
            .{ "permissions", "get_permissions", null },
            .{ "maxTouchPoints", "get_maxTouchPoints", null },
            .{ "presentation", "get_presentation", null },
            .{ "wakeLock", "get_wakeLock", null },
            .{ "serial", "get_serial", null },
            .{ "serviceWorker", "get_serviceWorker", null },
            .{ "virtualKeyboard", "get_virtualKeyboard", null },
            .{ "bluetooth", "get_bluetooth", null },
            .{ "hid", "get_hid", null },
            .{ "usb", "get_usb", null },
            .{ "xr", "get_xr", null },
            .{ "windowControlsOverlay", "get_windowControlsOverlay", null },
            .{ "crossOriginStorage", "get_crossOriginStorage", null },
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
            .{ "cookieEnabled", "get_cookieEnabled", null },
            .{ "plugins", "get_plugins", null },
            .{ "mimeTypes", "get_mimeTypes", null },
            .{ "pdfViewerEnabled", "get_pdfViewerEnabled", null },
            .{ "hardwareConcurrency", "get_hardwareConcurrency", null },
            .{ "connection", "get_connection", null },
            .{ "storageBuckets", "get_storageBuckets", null },
            .{ "storage", "get_storage", null },
            .{ "userAgentData", "get_userAgentData", null },
            .{ "locks", "get_locks", null },
            .{ "webdriver", "get_webdriver", null },
            .{ "gpu", "get_gpu", null },
            .{ "ml", "get_ml", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getAutoplayPolicy", "call_getAutoplayPolicy", 1 },
            .{ "getBattery", "call_getBattery", 0 },
            .{ "sendBeacon", "call_sendBeacon", 1 },
            .{ "requestMediaKeySystemAccess", "call_requestMediaKeySystemAccess", 2 },
            .{ "deprecatedReplaceInURN", "call_deprecatedReplaceInURN", 2 },
            .{ "deprecatedURNtoURL", "call_deprecatedURNtoURL", 1 },
            .{ "adAuctionComponents", "call_adAuctionComponents", 1 },
            .{ "getGamepads", "call_getGamepads", 0 },
            .{ "getInstalledRelatedApps", "call_getInstalledRelatedApps", 0 },
            .{ "queryHandwritingRecognizer", "call_queryHandwritingRecognizer", 1 },
            .{ "createHandwritingRecognizer", "call_createHandwritingRecognizer", 1 },
            .{ "install", "call_install", 0 },
            .{ "vibrate", "call_vibrate", 1 },
            .{ "share", "call_share", 0 },
            .{ "canShare", "call_canShare", 0 },
            .{ "requestMIDIAccess", "call_requestMIDIAccess", 0 },
            .{ "setAppBadge", "call_setAppBadge", 0 },
            .{ "clearAppBadge", "call_clearAppBadge", 0 },
            .{ "taintEnabled", "call_taintEnabled", 0 },
            .{ "registerProtocolHandler", "call_registerProtocolHandler", 2 },
            .{ "unregisterProtocolHandler", "call_unregisterProtocolHandler", 2 },
            .{ "javaEnabled", "call_javaEnabled", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getAutoplayPolicy",
            "getBattery",
            "sendBeacon",
            "requestMediaKeySystemAccess",
            "deprecatedReplaceInURN",
            "deprecatedURNtoURL",
            "adAuctionComponents",
            "getGamepads",
            "getInstalledRelatedApps",
            "queryHandwritingRecognizer",
            "createHandwritingRecognizer",
            "install",
            "vibrate",
            "share",
            "canShare",
            "requestMIDIAccess",
            "setAppBadge",
            "clearAppBadge",
            "taintEnabled",
            "registerProtocolHandler",
            "unregisterProtocolHandler",
            "javaEnabled",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "attribution", "get_attribution", null },
            .{ "audioSession", "get_audioSession", null },
            .{ "clipboard", "get_clipboard", null },
            .{ "contacts", "get_contacts", null },
            .{ "cpuPerformance", "get_cpuPerformance", null },
            .{ "credentials", "get_credentials", null },
            .{ "devicePosture", "get_devicePosture", null },
            .{ "epubReadingSystem", "get_epubReadingSystem", null },
            .{ "geolocation", "get_geolocation", null },
            .{ "userActivation", "get_userActivation", null },
            .{ "ink", "get_ink", null },
            .{ "scheduling", "get_scheduling", null },
            .{ "keyboard", "get_keyboard", null },
            .{ "login", "get_login", null },
            .{ "managed", "get_managed", null },
            .{ "mediaCapabilities", "get_mediaCapabilities", null },
            .{ "mediaDevices", "get_mediaDevices", null },
            .{ "preferences", "get_preferences", null },
            .{ "mediaSession", "get_mediaSession", null },
            .{ "permissions", "get_permissions", null },
            .{ "maxTouchPoints", "get_maxTouchPoints", null },
            .{ "presentation", "get_presentation", null },
            .{ "wakeLock", "get_wakeLock", null },
            .{ "serial", "get_serial", null },
            .{ "serviceWorker", "get_serviceWorker", null },
            .{ "virtualKeyboard", "get_virtualKeyboard", null },
            .{ "bluetooth", "get_bluetooth", null },
            .{ "hid", "get_hid", null },
            .{ "usb", "get_usb", null },
            .{ "xr", "get_xr", null },
            .{ "windowControlsOverlay", "get_windowControlsOverlay", null },
            .{ "crossOriginStorage", "get_crossOriginStorage", null },
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
            .{ "cookieEnabled", "get_cookieEnabled", null },
            .{ "plugins", "get_plugins", null },
            .{ "mimeTypes", "get_mimeTypes", null },
            .{ "pdfViewerEnabled", "get_pdfViewerEnabled", null },
            .{ "hardwareConcurrency", "get_hardwareConcurrency", null },
            .{ "connection", "get_connection", null },
            .{ "storageBuckets", "get_storageBuckets", null },
            .{ "storage", "get_storage", null },
            .{ "userAgentData", "get_userAgentData", null },
            .{ "locks", "get_locks", null },
            .{ "webdriver", "get_webdriver", null },
            .{ "gpu", "get_gpu", null },
            .{ "ml", "get_ml", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
        pub const unforgeable_members = .{"epubReadingSystem"};

        /// [SecureContext] members - their own, their partial interface's or
        /// their mixin's: hidden in a realm that is not a secure context
        /// (WebIDL 3.3.13).
        pub const secure_context_members = .{
            "attribution",
            "clipboard",
            "contacts",
            "cpuPerformance",
            "credentials",
            "devicePosture",
            "keyboard",
            "login",
            "managed",
            "mediaDevices",
            "preferences",
            "presentation",
            "wakeLock",
            "serial",
            "serviceWorker",
            "virtualKeyboard",
            "bluetooth",
            "hid",
            "usb",
            "xr",
            "windowControlsOverlay",
            "crossOriginStorage",
            "deviceMemory",
            "storageBuckets",
            "storage",
            "userAgentData",
            "locks",
            "gpu",
            "ml",
            "getBattery",
            "requestMediaKeySystemAccess",
            "getInstalledRelatedApps",
            "queryHandwritingRecognizer",
            "createHandwritingRecognizer",
            "share",
            "canShare",
            "requestMIDIAccess",
            "setAppBadge",
            "clearAppBadge",
            "registerProtocolHandler",
            "unregisterProtocolHandler",
        };
        /// Member-level [Exposed] overrides; unlisted members inherit the interface.
        pub const exposed_members = .{
            .{ "audioSession", .{"Window"} },
            .{ "contacts", .{"Window"} },
            .{ "cpuPerformance", .{"Window"} },
            .{ "devicePosture", .{"Window"} },
            .{ "ink", .{"Window"} },
            .{ "mediaCapabilities", .{"Window"} },
            .{ "preferences", .{"Window"} },
            .{ "mediaSession", .{"Window"} },
            .{ "permissions", .{"Window"} },
            .{ "serial", .{"Window"} },
            .{ "usb", .{"Window"} },
            .{ "windowControlsOverlay", .{"Window"} },
            .{ "deviceMemory", .{ "Window", "Worker" } },
            .{ "productSub", .{"Window"} },
            .{ "vendor", .{"Window"} },
            .{ "vendorSub", .{"Window"} },
            .{ "oscpu", .{"Window"} },
            .{ "getAutoplayPolicy", .{"Window"} },
            .{ "requestMediaKeySystemAccess", .{"Window"} },
            .{ "getGamepads", .{"Window"} },
            .{ "getInstalledRelatedApps", .{"Window"} },
            .{ "taintEnabled", .{"Window"} },
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            attribution: *runtime.Instance = undefined,
            audioSession: *runtime.Instance = undefined,
            clipboard: *runtime.Instance = undefined,
            contacts: *runtime.Instance = undefined,
            cpuPerformance: u16 = undefined,
            credentials: *runtime.Instance = undefined,
            devicePosture: *runtime.Instance = undefined,
            epubReadingSystem: *runtime.Instance = undefined,
            geolocation: *runtime.Instance = undefined,
            userActivation: *runtime.Instance = undefined,
            ink: *runtime.Instance = undefined,
            scheduling: *runtime.Instance = undefined,
            keyboard: *runtime.Instance = undefined,
            login: *runtime.Instance = undefined,
            managed: *runtime.Instance = undefined,
            mediaCapabilities: *runtime.Instance = undefined,
            mediaDevices: *runtime.Instance = undefined,
            preferences: *runtime.Instance = undefined,
            mediaSession: *runtime.Instance = undefined,
            permissions: *runtime.Instance = undefined,
            maxTouchPoints: i32 = undefined,
            presentation: *runtime.Instance = undefined,
            wakeLock: *runtime.Instance = undefined,
            serial: *runtime.Instance = undefined,
            serviceWorker: *runtime.Instance = undefined,
            virtualKeyboard: *runtime.Instance = undefined,
            bluetooth: *runtime.Instance = undefined,
            hid: *runtime.Instance = undefined,
            usb: *runtime.Instance = undefined,
            xr: *runtime.Instance = undefined,
            windowControlsOverlay: *runtime.Instance = undefined,
            crossOriginStorage: *runtime.Instance = undefined,
            deviceMemory: f64 = undefined,
            globalPrivacyControl: bool = undefined,
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
            languages: runtime.JSValue = undefined,
            onLine: bool = undefined,
            cookieEnabled: bool = undefined,
            plugins: *runtime.Instance = undefined,
            mimeTypes: *runtime.Instance = undefined,
            pdfViewerEnabled: bool = undefined,
            hardwareConcurrency: u64 = undefined,
            connection: *runtime.Instance = undefined,
            storageBuckets: *runtime.Instance = undefined,
            storage: *runtime.Instance = undefined,
            userAgentData: *runtime.Instance = undefined,
            locks: *runtime.Instance = undefined,
            webdriver: bool = undefined,
            gpu: *runtime.Instance = undefined,
            ml: *runtime.Instance = undefined,
            cached_attribution: ?*runtime.Instance = null,
            cached_clipboard: ?*runtime.Instance = null,
            cached_contacts: ?*runtime.Instance = null,
            cached_credentials: ?*runtime.Instance = null,
            cached_devicePosture: ?*runtime.Instance = null,
            cached_epubReadingSystem: ?*runtime.Instance = null,
            cached_geolocation: ?*runtime.Instance = null,
            cached_userActivation: ?*runtime.Instance = null,
            cached_ink: ?*runtime.Instance = null,
            cached_keyboard: ?*runtime.Instance = null,
            cached_managed: ?*runtime.Instance = null,
            cached_mediaCapabilities: ?*runtime.Instance = null,
            cached_mediaDevices: ?*runtime.Instance = null,
            cached_preferences: ?*runtime.Instance = null,
            cached_mediaSession: ?*runtime.Instance = null,
            cached_permissions: ?*runtime.Instance = null,
            cached_presentation: ?*runtime.Instance = null,
            cached_wakeLock: ?*runtime.Instance = null,
            cached_serial: ?*runtime.Instance = null,
            cached_serviceWorker: ?*runtime.Instance = null,
            cached_virtualKeyboard: ?*runtime.Instance = null,
            cached_bluetooth: ?*runtime.Instance = null,
            cached_hid: ?*runtime.Instance = null,
            cached_usb: ?*runtime.Instance = null,
            cached_xr: ?*runtime.Instance = null,
            cached_windowControlsOverlay: ?*runtime.Instance = null,
            cached_crossOriginStorage: ?*runtime.Instance = null,
            cached_plugins: ?*runtime.Instance = null,
            cached_mimeTypes: ?*runtime.Instance = null,
            cached_connection: ?*runtime.Instance = null,
            cached_storageBuckets: ?*runtime.Instance = null,
            cached_storage: ?*runtime.Instance = null,
            cached_gpu: ?*runtime.Instance = null,
            cached_ml: ?*runtime.Instance = null,
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
        .get_cpuPerformance = &get_cpuPerformance,
        .get_credentials = &get_credentials,
        .get_crossOriginStorage = &get_crossOriginStorage,
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
        .get_scheduling = &get_scheduling,
        .get_serial = &get_serial,
        .get_serviceWorker = &get_serviceWorker,
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
        .call_canShare = &call_canShare,
        .call_clearAppBadge = &call_clearAppBadge,
        .call_createHandwritingRecognizer = &call_createHandwritingRecognizer,
        .call_deprecatedReplaceInURN = &call_deprecatedReplaceInURN,
        .call_deprecatedURNtoURL = &call_deprecatedURNtoURL,
        .call_getAutoplayPolicy = &call_getAutoplayPolicy,
        .call_getBattery = &call_getBattery,
        .call_getGamepads = &call_getGamepads,
        .call_getInstalledRelatedApps = &call_getInstalledRelatedApps,
        .call_install = &call_install,
        .call_javaEnabled = &call_javaEnabled,
        .call_queryHandwritingRecognizer = &call_queryHandwritingRecognizer,
        .call_registerProtocolHandler = &call_registerProtocolHandler,
        .call_requestMIDIAccess = &call_requestMIDIAccess,
        .call_requestMediaKeySystemAccess = &call_requestMediaKeySystemAccess,
        .call_sendBeacon = &call_sendBeacon,
        .call_setAppBadge = &call_setAppBadge,
        .call_share = &call_share,
        .call_taintEnabled = &call_taintEnabled,
        .call_unregisterProtocolHandler = &call_unregisterProtocolHandler,
        .call_vibrate = &call_vibrate,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("Navigator has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(NavigatorImpl, "init") and @hasDecl(NavigatorImpl, "initOwn")) @compileError("NavigatorImpl defines both init and initOwn");
        if (comptime @hasDecl(NavigatorImpl, "init")) return NavigatorImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(NavigatorImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try NavigatorImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(NavigatorImpl, "init")) return false;
        if (comptime @hasDecl(NavigatorImpl, "construction_args")) {
            inline for (NavigatorImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(NavigatorImpl, "deinit") and @hasDecl(NavigatorImpl, "deinitOwn")) @compileError("NavigatorImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(NavigatorImpl, "deinit")) return NavigatorImpl.deinit(instance);
        if (comptime @hasDecl(NavigatorImpl, "deinitOwn")) NavigatorImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Navigator")) {
            if (comptime @hasDecl(impls.Navigator, "installHooks")) impls.Navigator.installHooks();
        }
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
        @import("dom").same_object_cache.made(instance, value, "attribution");
        return value;
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_audioSession(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try NavigatorImpl.get_audioSession(instance);
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
        @import("dom").same_object_cache.made(instance, value, "clipboard");
        return value;
    }

    /// Extended attributes: [SecureContext], [SameObject], [Exposed=Window]
    pub fn get_contacts(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_contacts) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_contacts(instance);
        state.own.cached_contacts = value;
        @import("dom").same_object_cache.made(instance, value, "contacts");
        return value;
    }

    /// Extended attributes: [SecureContext], [Exposed=Window]
    pub fn get_cpuPerformance(instance: *runtime.Instance) anyerror!u16 {
        return try NavigatorImpl.get_cpuPerformance(instance);
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
        @import("dom").same_object_cache.made(instance, value, "credentials");
        return value;
    }

    /// Extended attributes: [SameObject], [SecureContext], [Exposed=(Window)]
    pub fn get_devicePosture(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_devicePosture) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_devicePosture(instance);
        state.own.cached_devicePosture = value;
        @import("dom").same_object_cache.made(instance, value, "devicePosture");
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
        @import("dom").same_object_cache.made(instance, value, "epubReadingSystem");
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
        @import("dom").same_object_cache.made(instance, value, "geolocation");
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
        @import("dom").same_object_cache.made(instance, value, "userActivation");
        return value;
    }

    /// Extended attributes: [SameObject], [Exposed=Window]
    pub fn get_ink(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_ink) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_ink(instance);
        state.own.cached_ink = value;
        @import("dom").same_object_cache.made(instance, value, "ink");
        return value;
    }

    pub fn get_scheduling(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try NavigatorImpl.get_scheduling(instance);
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
        @import("dom").same_object_cache.made(instance, value, "keyboard");
        return value;
    }

    /// Extended attributes: [SecureContext]
    pub fn get_login(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try NavigatorImpl.get_login(instance);
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
        @import("dom").same_object_cache.made(instance, value, "managed");
        return value;
    }

    /// Extended attributes: [SameObject], [Exposed=Window]
    pub fn get_mediaCapabilities(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_mediaCapabilities) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_mediaCapabilities(instance);
        state.own.cached_mediaCapabilities = value;
        @import("dom").same_object_cache.made(instance, value, "mediaCapabilities");
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
        @import("dom").same_object_cache.made(instance, value, "mediaDevices");
        return value;
    }

    /// Extended attributes: [SameObject], [Exposed=Window], [SecureContext]
    pub fn get_preferences(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_preferences) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_preferences(instance);
        state.own.cached_preferences = value;
        @import("dom").same_object_cache.made(instance, value, "preferences");
        return value;
    }

    /// Extended attributes: [SameObject], [Exposed=Window]
    pub fn get_mediaSession(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_mediaSession) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_mediaSession(instance);
        state.own.cached_mediaSession = value;
        @import("dom").same_object_cache.made(instance, value, "mediaSession");
        return value;
    }

    /// Extended attributes: [SameObject], [Exposed=(Window)]
    pub fn get_permissions(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_permissions) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_permissions(instance);
        state.own.cached_permissions = value;
        @import("dom").same_object_cache.made(instance, value, "permissions");
        return value;
    }

    pub fn get_maxTouchPoints(instance: *runtime.Instance) anyerror!i32 {
        return try NavigatorImpl.get_maxTouchPoints(instance);
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
        @import("dom").same_object_cache.made(instance, value, "presentation");
        return value;
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_wakeLock(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_wakeLock) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_wakeLock(instance);
        state.own.cached_wakeLock = value;
        @import("dom").same_object_cache.made(instance, value, "wakeLock");
        return value;
    }

    /// Extended attributes: [SameObject], [Exposed=Window], [SecureContext]
    pub fn get_serial(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_serial) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_serial(instance);
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
        const value = try NavigatorImpl.get_serviceWorker(instance);
        state.own.cached_serviceWorker = value;
        @import("dom").same_object_cache.made(instance, value, "serviceWorker");
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
        @import("dom").same_object_cache.made(instance, value, "virtualKeyboard");
        return value;
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_bluetooth(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_bluetooth) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_bluetooth(instance);
        state.own.cached_bluetooth = value;
        @import("dom").same_object_cache.made(instance, value, "bluetooth");
        return value;
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_hid(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_hid) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_hid(instance);
        state.own.cached_hid = value;
        @import("dom").same_object_cache.made(instance, value, "hid");
        return value;
    }

    /// Extended attributes: [SameObject], [Exposed=Window], [SecureContext]
    pub fn get_usb(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_usb) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_usb(instance);
        state.own.cached_usb = value;
        @import("dom").same_object_cache.made(instance, value, "usb");
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
        @import("dom").same_object_cache.made(instance, value, "xr");
        return value;
    }

    /// Extended attributes: [SameObject], [SecureContext], [Exposed=(Window)]
    pub fn get_windowControlsOverlay(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_windowControlsOverlay) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_windowControlsOverlay(instance);
        state.own.cached_windowControlsOverlay = value;
        @import("dom").same_object_cache.made(instance, value, "windowControlsOverlay");
        return value;
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_crossOriginStorage(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_crossOriginStorage) |cached| {
            return cached;
        }
        const value = try NavigatorImpl.get_crossOriginStorage(instance);
        state.own.cached_crossOriginStorage = value;
        @import("dom").same_object_cache.made(instance, value, "crossOriginStorage");
        return value;
    }

    /// Extended attributes: [SecureContext], [Exposed=(Window,Worker)]
    pub const get_deviceMemory = mixins.NavigatorDeviceMemory.get_deviceMemory;

    pub const get_globalPrivacyControl = mixins.GlobalPrivacyControl.get_globalPrivacyControl;

    pub fn get_appCodeName(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try NavigatorImpl.get_appCodeName(instance);
    }

    pub fn get_appName(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try NavigatorImpl.get_appName(instance);
    }

    pub fn get_appVersion(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try NavigatorImpl.get_appVersion(instance);
    }

    pub fn get_platform(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try NavigatorImpl.get_platform(instance);
    }

    pub fn get_product(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try NavigatorImpl.get_product(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_productSub(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try NavigatorImpl.get_productSub(instance);
    }

    pub fn get_userAgent(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try NavigatorImpl.get_userAgent(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_vendor(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try NavigatorImpl.get_vendor(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_vendorSub(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try NavigatorImpl.get_vendorSub(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_oscpu(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try NavigatorImpl.get_oscpu(instance);
    }

    pub fn get_language(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try NavigatorImpl.get_language(instance);
    }

    pub fn get_languages(instance: *runtime.Instance) anyerror!runtime.JSValue {
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
        const value = try mixins.NavigatorPlugins.get_plugins(instance);
        state.own.cached_plugins = value;
        @import("dom").same_object_cache.made(instance, value, "plugins");
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_mimeTypes(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_mimeTypes) |cached| {
            return cached;
        }
        const value = try mixins.NavigatorPlugins.get_mimeTypes(instance);
        state.own.cached_mimeTypes = value;
        @import("dom").same_object_cache.made(instance, value, "mimeTypes");
        return value;
    }

    pub const get_pdfViewerEnabled = mixins.NavigatorPlugins.get_pdfViewerEnabled;

    pub fn get_hardwareConcurrency(instance: *runtime.Instance) anyerror!u64 {
        return try NavigatorImpl.get_hardwareConcurrency(instance);
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
        const value = try NavigatorImpl.get_storage(instance);
        state.own.cached_storage = value;
        @import("dom").same_object_cache.made(instance, value, "storage");
        return value;
    }

    /// Extended attributes: [SecureContext]
    pub const get_userAgentData = mixins.NavigatorUA.get_userAgentData;

    /// Extended attributes: [SecureContext]
    pub const get_locks = mixins.NavigatorLocks.get_locks;

    pub const get_webdriver = mixins.NavigatorAutomationInformation.get_webdriver;

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

    pub fn call_deprecatedReplaceInURN(instance: *runtime.Instance, urnOrConfig: UrnOrConfig, replacements: runtime.JSValue) anyerror!runtime.JSValue {
        return try NavigatorImpl.call_deprecatedReplaceInURN(instance, urnOrConfig, replacements);
    }

    pub fn call_deprecatedURNtoURL(instance: *runtime.Instance, urnOrConfig: UrnOrConfig, send_reports: webidl.Opt(bool)) anyerror!runtime.JSValue {
        return try NavigatorImpl.call_deprecatedURNtoURL(instance, urnOrConfig, send_reports);
    }

    /// Extended attributes: [SecureContext], [Exposed=Window]
    pub fn call_requestMediaKeySystemAccess(instance: *runtime.Instance, keySystem: runtime.DOMString, supportedConfigurations: runtime.JSValue) anyerror!runtime.JSValue {
        return try NavigatorImpl.call_requestMediaKeySystemAccess(instance, keySystem, supportedConfigurations);
    }

    pub const call_clearAppBadge = mixins.NavigatorBadge.call_clearAppBadge;

    /// Extended attributes: [SecureContext]
    pub fn call_canShare(instance: *runtime.Instance, data: webidl.Opt(ShareData)) anyerror!bool {
        return try NavigatorImpl.call_canShare(instance, data);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_taintEnabled(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorImpl.call_taintEnabled(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_queryHandwritingRecognizer(instance: *runtime.Instance, constraint: HandwritingModelConstraint) anyerror!runtime.JSValue {
        return try NavigatorImpl.call_queryHandwritingRecognizer(instance, constraint);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_requestMIDIAccess(instance: *runtime.Instance, options: webidl.Opt(MIDIOptions)) anyerror!runtime.JSValue {
        return try NavigatorImpl.call_requestMIDIAccess(instance, options);
    }

    pub fn call_install(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try NavigatorImpl.call_install(instance);
    }

    pub fn call_adAuctionComponents(instance: *runtime.Instance, numAdComponents: u16) anyerror!runtime.JSValue {
        return try NavigatorImpl.call_adAuctionComponents(instance, numAdComponents);
    }

    pub const call_registerProtocolHandler = mixins.NavigatorContentUtils.call_registerProtocolHandler;

    pub const call_setAppBadge = mixins.NavigatorBadge.call_setAppBadge;

    pub fn call_vibrate(instance: *runtime.Instance, pattern: VibratePattern) anyerror!bool {
        return try NavigatorImpl.call_vibrate(instance, pattern);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_getAutoplayPolicy(instance: *runtime.Instance, @"type": AutoplayPolicyMediaType) anyerror!AutoplayPolicy {
        return try NavigatorImpl.call_getAutoplayPolicy(instance, @"type");
    }

    pub fn call_sendBeacon(instance: *runtime.Instance, url: runtime.USVString, data: webidl.Opt(?BodyInit)) anyerror!bool {
        return try NavigatorImpl.call_sendBeacon(instance, url, data);
    }

    /// Extended attributes: [SecureContext], [Exposed=Window]
    pub fn call_getInstalledRelatedApps(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try NavigatorImpl.call_getInstalledRelatedApps(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_getBattery(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try NavigatorImpl.call_getBattery(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_share(instance: *runtime.Instance, data: webidl.Opt(ShareData)) anyerror!runtime.JSValue {
        return try NavigatorImpl.call_share(instance, data);
    }

    pub const call_unregisterProtocolHandler = mixins.NavigatorContentUtils.call_unregisterProtocolHandler;

    /// Extended attributes: [Exposed=Window]
    pub fn call_getGamepads(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try NavigatorImpl.call_getGamepads(instance);
    }

    pub const call_javaEnabled = mixins.NavigatorPlugins.call_javaEnabled;

    /// Extended attributes: [SecureContext]
    pub fn call_createHandwritingRecognizer(instance: *runtime.Instance, constraint: HandwritingModelConstraint) anyerror!runtime.JSValue {
        return try NavigatorImpl.call_createHandwritingRecognizer(instance, constraint);
    }

    pub fn call_install__1(instance: *runtime.Instance, options: InstallParams) anyerror!runtime.JSValue {
        if (comptime @hasDecl(NavigatorImpl, "call_install__1")) {
            return try NavigatorImpl.call_install__1(instance, options);
        } else {
            return error.NotImplemented;
        }
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_getAutoplayPolicy__1(instance: *runtime.Instance, element: *runtime.Instance) anyerror!AutoplayPolicy {
        if (comptime @hasDecl(NavigatorImpl, "call_getAutoplayPolicy__1")) {
            return try NavigatorImpl.call_getAutoplayPolicy__1(instance, element);
        } else {
            return error.NotImplemented;
        }
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_getAutoplayPolicy__2(instance: *runtime.Instance, context: *runtime.Instance) anyerror!AutoplayPolicy {
        if (comptime @hasDecl(NavigatorImpl, "call_getAutoplayPolicy__2")) {
            return try NavigatorImpl.call_getAutoplayPolicy__2(instance, context);
        } else {
            return error.NotImplemented;
        }
    }

    /// WebIDL overload sets: every overload of each overloaded operation,
    /// in IDL order, for the overload resolution algorithm
    /// (webidl.overload_resolution). The binding is installed for the first
    /// overload and forwards to the one the arguments select.
    pub const overloads = .{
        .{ "install", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_install", .args = &.{} },
            .{ .function = "call_install__1", .implemented = @hasDecl(NavigatorImpl, "call_install__1"), .args = &.{.{ .kinds = &.{.dictionary} }} },
        } },
        .{ "getAutoplayPolicy", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_getAutoplayPolicy", .args = &.{.{ .kinds = &.{.string} }} },
            .{ .function = "call_getAutoplayPolicy__1", .implemented = @hasDecl(NavigatorImpl, "call_getAutoplayPolicy__1"), .args = &.{.{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "HTMLMediaElement")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").HTMLMediaElement.State) } else .other)} }} },
            .{ .function = "call_getAutoplayPolicy__2", .implemented = @hasDecl(NavigatorImpl, "call_getAutoplayPolicy__2"), .args = &.{.{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "AudioContext")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").AudioContext.State) } else .other)} }} },
        } },
    };

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_getAutoplayPolicy__1", 0, "HTMLMediaElement" },
        .{ "call_getAutoplayPolicy__2", 0, "AudioContext" },
    };

    /// WebIDL [EnforceRange]: the integer arguments and attribute values
    /// whose conversion takes that branch of ConvertToInt (bit i = argument i;
    /// an attribute setter's value is bit 0).
    pub const enforce_range = .{
        .{ "call_setAppBadge", 0b1 },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_deprecatedReplaceInURN",
        "call_deprecatedURNtoURL",
        "call_requestMediaKeySystemAccess",
        "call_clearAppBadge",
        "call_queryHandwritingRecognizer",
        "call_requestMIDIAccess",
        "call_install",
        "call_install__1",
        "call_setAppBadge",
        "call_getInstalledRelatedApps",
        "call_getBattery",
        "call_share",
        "call_createHandwritingRecognizer",
    };
};
