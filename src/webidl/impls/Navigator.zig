//! Implementation for Navigator interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const Navigator = interfaces.Navigator;

// StorageManager interface
const StorageManagerInterface = interfaces.StorageManager;

pub const State = Navigator.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Stores cached instances like StorageManager
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// Cached StorageManager instance (singleton per Navigator)
    storage_manager: ?*runtime.Instance = null,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        // StorageManager cleanup handled by GC
        _ = self;
        _ = allocator;
    }
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    const state = instance.getState(StateType);

    // Create internal state
    state.own._internal = try allocator.create(InternalState);
    const internal = state.own._internal.?;
    internal.* = .{
        .allocator = allocator,
        .storage_manager = null,
    };

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(internal.allocator);
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Getter for scheduling
pub fn get_scheduling(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for presentation
pub fn get_presentation(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for keyboard
pub fn get_keyboard(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for clipboard
pub fn get_clipboard(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for audioSession
pub fn get_audioSession(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for mediaCapabilities
pub fn get_mediaCapabilities(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for serial
pub fn get_serial(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for permissions
pub fn get_permissions(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for contacts
pub fn get_contacts(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for devicePosture
pub fn get_devicePosture(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for maxTouchPoints
pub fn get_maxTouchPoints(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for attribution
pub fn get_attribution(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for smartCard
pub fn get_smartCard(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for usb
pub fn get_usb(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for windowControlsOverlay
pub fn get_windowControlsOverlay(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for xr
pub fn get_xr(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for deprecatedRunAdAuctionEnforcesKAnonymity
pub fn get_deprecatedRunAdAuctionEnforcesKAnonymity(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for protectedAudience
pub fn get_protectedAudience(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for hid
pub fn get_hid(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for credentials
pub fn get_credentials(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for wakeLock
pub fn get_wakeLock(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for virtualKeyboard
pub fn get_virtualKeyboard(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for preferences
pub fn get_preferences(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for managed
pub fn get_managed(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for serviceWorker
pub fn get_serviceWorker(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ink
pub fn get_ink(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for epubReadingSystem
pub fn get_epubReadingSystem(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for userActivation
pub fn get_userActivation(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for bluetooth
pub fn get_bluetooth(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for geolocation
pub fn get_geolocation(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for login
pub fn get_login(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for mediaSession
pub fn get_mediaSession(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for mediaDevices
pub fn get_mediaDevices(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for locks
pub fn get_locks(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for gpu
pub fn get_gpu(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for globalPrivacyControl
pub fn get_globalPrivacyControl(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for webdriver
pub fn get_webdriver(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for connection
pub fn get_connection(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ml
pub fn get_ml(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for deviceMemory
pub fn get_deviceMemory(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for storage
///
/// Returns the StorageManager for this Navigator.
/// Per WHATWG Storage Standard: https://storage.spec.whatwg.org/#dom-navigatorstorage-storage
///
/// The StorageManager provides methods for:
/// - persisted() - Check if storage is persistent
/// - persist() - Request persistent storage
/// - estimate() - Get storage usage/quota estimates
/// - getDirectory() - Get origin-private file system root
pub fn get_storage(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.NotImplemented;

    // Return cached StorageManager if available
    if (internal.storage_manager) |sm| {
        return sm;
    }

    // Create new StorageManager instance
    const ctx = instance.ctx;
    const allocator = internal.allocator;

    // Use StorageManager interface to create instance
    const storage_manager = try StorageManagerInterface.init(allocator, ctx);

    // Cache for future calls
    internal.storage_manager = storage_manager;

    return storage_manager;
}

/// Getter for storageBuckets
pub fn get_storageBuckets(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for appCodeName
/// Per HTML Standard: Returns "Mozilla" for compatibility.
pub fn get_appCodeName(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return runtime.DOMString.initInterned("Mozilla");
}

/// Getter for appName
/// Per HTML Standard: Returns "Netscape" for compatibility.
pub fn get_appName(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return runtime.DOMString.initInterned("Netscape");
}

/// Getter for appVersion
/// Per HTML Standard: Returns version info.
pub fn get_appVersion(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return runtime.DOMString.initInterned("5.0 (WhatWG-Zig/1.0)");
}

/// Getter for platform
/// Per HTML Standard: Returns the platform identifier.
pub fn get_platform(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    // Return platform based on compile target
    const builtin = @import("builtin");
    return runtime.DOMString.initInterned(switch (builtin.os.tag) {
        .macos => "MacIntel",
        .linux => "Linux x86_64",
        .windows => "Win32",
        else => "Unknown",
    });
}

/// Getter for product
/// Per HTML Standard: Returns "Gecko" for compatibility.
pub fn get_product(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return runtime.DOMString.initInterned("Gecko");
}

/// Getter for productSub
/// Per HTML Standard: Returns "20030107" for compatibility (historical Gecko date).
pub fn get_productSub(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return runtime.DOMString.initInterned("20030107");
}

/// Getter for userAgent
/// Per HTML Standard: Returns the user agent string identifying the browser.
/// Format: Mozilla/5.0 (platform) WhatWG-Zig/1.0
pub fn get_userAgent(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    const builtin = @import("builtin");
    return runtime.DOMString.initInterned(switch (builtin.os.tag) {
        .macos => "Mozilla/5.0 (Macintosh; Intel Mac OS X) WhatWG-Zig/1.0",
        .linux => "Mozilla/5.0 (X11; Linux x86_64) WhatWG-Zig/1.0",
        .windows => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) WhatWG-Zig/1.0",
        else => "Mozilla/5.0 WhatWG-Zig/1.0",
    });
}

/// Getter for vendor
/// Per HTML Standard: Returns the vendor name.
pub fn get_vendor(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return runtime.DOMString.initInterned("WhatWG-Zig");
}

/// Getter for vendorSub
/// Per HTML Standard: Returns empty string.
pub fn get_vendorSub(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return runtime.DOMString.initEmpty();
}

/// Getter for oscpu
/// Per HTML Standard: Returns OS/CPU information.
pub fn get_oscpu(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    const builtin = @import("builtin");
    return runtime.DOMString.initInterned(switch (builtin.os.tag) {
        .macos => "Intel Mac OS X",
        .linux => "Linux x86_64",
        .windows => "Windows NT 10.0; Win64; x64",
        else => "Unknown",
    });
}

/// Getter for language
/// Per HTML Standard: Returns the preferred language of the user.
pub fn get_language(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return runtime.DOMString.initInterned("en-US");
}

/// Getter for languages
/// Per HTML Standard: Returns a frozen array of preferred languages.
/// Note: For WPT tests, we return a pointer to a static array structure.
/// The V8 binding layer should convert this to a JS array.
pub fn get_languages(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    // Return pointer to static "en-US" string as a minimal implementation
    // The interface/binding layer needs to handle conversion to array
    const static_lang: []const u8 = "en-US";
    return runtime.JSValue.fromAnyopaque(@ptrCast(&static_lang));
}

/// Getter for onLine
/// Per HTML Standard: Returns true if the user agent is online.
pub fn get_onLine(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    // Default to online for WPT tests
    return true;
}

/// Getter for cookieEnabled
/// Per HTML Standard: Returns true if cookies are enabled.
pub fn get_cookieEnabled(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    // Default to enabled for WPT tests
    return true;
}

/// Getter for plugins
pub fn get_plugins(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for mimeTypes
pub fn get_mimeTypes(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for pdfViewerEnabled
pub fn get_pdfViewerEnabled(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for hardwareConcurrency
/// Per HTML Standard: Returns the number of logical processors available.
pub fn get_hardwareConcurrency(instance: *runtime.Instance) anyerror!u64 {
    _ = instance;
    // Use std.Thread.getCpuCount() to get actual CPU count
    const cpu_count = std.Thread.getCpuCount() catch 1;
    return @intCast(cpu_count);
}

/// Getter for userAgentData
pub fn get_userAgentData(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: requestMIDIAccess
pub fn call_requestMIDIAccess(instance: *runtime.Instance, options: webidl.Opt(dictionaries.MIDIOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: adAuctionComponents
pub fn call_adAuctionComponents(instance: *runtime.Instance, numAdComponents: u16) anyerror!runtime.JSValue {
    _ = instance;
    _ = numAdComponents;
    return error.NotImplemented;
}

/// Operation: joinAdInterestGroup
pub fn call_joinAdInterestGroup(instance: *runtime.Instance, group: dictionaries.AuctionAdInterestGroup) anyerror!runtime.JSValue {
    _ = instance;
    _ = group;
    return error.NotImplemented;
}

/// Operation: vibrate
pub fn call_vibrate(instance: *runtime.Instance, pattern: typedefs.VibratePattern) anyerror!bool {
    _ = instance;
    _ = pattern;
    return error.NotImplemented;
}

/// Operation: createHandwritingRecognizer
pub fn call_createHandwritingRecognizer(instance: *runtime.Instance, constraint: dictionaries.HandwritingModelConstraint) anyerror!runtime.JSValue {
    _ = instance;
    _ = constraint;
    return error.NotImplemented;
}

/// Operation: leaveAdInterestGroup
pub fn call_leaveAdInterestGroup(instance: *runtime.Instance, group: webidl.Opt(dictionaries.AuctionAdInterestGroupKey)) anyerror!runtime.JSValue {
    _ = instance;
    _ = group;
    return error.NotImplemented;
}

/// Operation: getGamepads
pub fn call_getGamepads(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: updateAdInterestGroups
pub fn call_updateAdInterestGroups(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getBattery
pub fn call_getBattery(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: taintEnabled
pub fn call_taintEnabled(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setAppBadge
pub fn call_setAppBadge(instance: *runtime.Instance, contents: webidl.Opt(u64)) anyerror!runtime.JSValue {
    _ = instance;
    _ = contents;
    return error.NotImplemented;
}

/// Operation: canLoadAdAuctionFencedFrame
pub fn call_canLoadAdAuctionFencedFrame(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createAuctionNonce
pub fn call_createAuctionNonce(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: sendBeacon
pub fn call_sendBeacon(instance: *runtime.Instance, url: runtime.USVString, data: webidl.Opt(?typedefs.BodyInit)) anyerror!bool {
    _ = instance;
    _ = url;
    _ = data;
    return error.NotImplemented;
}

/// Operation: unregisterProtocolHandler
pub fn call_unregisterProtocolHandler(instance: *runtime.Instance, scheme: runtime.DOMString, url: runtime.USVString) anyerror!void {
    _ = instance;
    _ = scheme;
    _ = url;
    return error.NotImplemented;
}

/// Operation: queryHandwritingRecognizer
pub fn call_queryHandwritingRecognizer(instance: *runtime.Instance, constraint: dictionaries.HandwritingModelConstraint) anyerror!runtime.JSValue {
    _ = instance;
    _ = constraint;
    return error.NotImplemented;
}

/// Operation: clearAppBadge
pub fn call_clearAppBadge(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: share
pub fn call_share(instance: *runtime.Instance, data: webidl.Opt(dictionaries.ShareData)) anyerror!runtime.JSValue {
    _ = instance;
    _ = data;
    return error.NotImplemented;
}

/// Operation: runAdAuction
pub fn call_runAdAuction(instance: *runtime.Instance, config: dictionaries.AuctionAdConfig) anyerror!runtime.JSValue {
    _ = instance;
    _ = config;
    return error.NotImplemented;
}

/// Operation: deprecatedReplaceInURN
pub fn call_deprecatedReplaceInURN(instance: *runtime.Instance, urnOrConfig: typedefs.UrnOrConfig, replacements: runtime.JSValue) anyerror!runtime.JSValue {
    _ = instance;
    _ = urnOrConfig;
    _ = replacements;
    return error.NotImplemented;
}

/// Operation: getAutoplayPolicy
pub fn call_getAutoplayPolicy(instance: *runtime.Instance, @"type": enums.AutoplayPolicyMediaType) anyerror!enums.AutoplayPolicy {
    _ = instance;
    _ = @"type";
    return error.NotImplemented;
}

/// Operation: javaEnabled
pub fn call_javaEnabled(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getInstalledRelatedApps
pub fn call_getInstalledRelatedApps(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: canShare
pub fn call_canShare(instance: *runtime.Instance, data: webidl.Opt(dictionaries.ShareData)) anyerror!bool {
    _ = instance;
    _ = data;
    return error.NotImplemented;
}

/// Operation: clearOriginJoinedAdInterestGroups
pub fn call_clearOriginJoinedAdInterestGroups(instance: *runtime.Instance, owner: runtime.USVString, interestGroupsToKeep: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    _ = instance;
    _ = owner;
    _ = interestGroupsToKeep;
    return error.NotImplemented;
}

/// Operation: getInterestGroupAdAuctionData
pub fn call_getInterestGroupAdAuctionData(instance: *runtime.Instance, config: webidl.Opt(dictionaries.AdAuctionDataConfig)) anyerror!runtime.JSValue {
    _ = instance;
    _ = config;
    return error.NotImplemented;
}

/// Operation: requestMediaKeySystemAccess
pub fn call_requestMediaKeySystemAccess(instance: *runtime.Instance, keySystem: runtime.DOMString, supportedConfigurations: runtime.JSValue) anyerror!runtime.JSValue {
    _ = instance;
    _ = keySystem;
    _ = supportedConfigurations;
    return error.NotImplemented;
}

/// Operation: deprecatedURNtoURL
pub fn call_deprecatedURNtoURL(instance: *runtime.Instance, urnOrConfig: typedefs.UrnOrConfig, send_reports: webidl.Opt(bool)) anyerror!runtime.JSValue {
    _ = instance;
    _ = urnOrConfig;
    _ = send_reports;
    return error.NotImplemented;
}

/// Operation: registerProtocolHandler
pub fn call_registerProtocolHandler(instance: *runtime.Instance, scheme: runtime.DOMString, url: runtime.USVString) anyerror!void {
    _ = instance;
    _ = scheme;
    _ = url;
    return error.NotImplemented;
}
