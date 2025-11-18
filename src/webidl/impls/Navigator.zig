//! Implementation for Navigator interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const Navigator = @import("interfaces").Navigator;

pub const State = Navigator.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance
pub fn init(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Initialize your instance state here
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Clean up your instance resources here
}

/// Getter for scheduling
pub fn get_scheduling(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for presentation
pub fn get_presentation(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for keyboard
pub fn get_keyboard(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for clipboard
pub fn get_clipboard(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for audioSession
pub fn get_audioSession(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for mediaCapabilities
pub fn get_mediaCapabilities(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for serial
pub fn get_serial(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for permissions
pub fn get_permissions(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for contacts
pub fn get_contacts(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for devicePosture
pub fn get_devicePosture(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxTouchPoints
pub fn get_maxTouchPoints(instance: *runtime.Instance) ImplError!i32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for attribution
pub fn get_attribution(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for smartCard
pub fn get_smartCard(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for usb
pub fn get_usb(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for windowControlsOverlay
pub fn get_windowControlsOverlay(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for xr
pub fn get_xr(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for deprecatedRunAdAuctionEnforcesKAnonymity
pub fn get_deprecatedRunAdAuctionEnforcesKAnonymity(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for protectedAudience
pub fn get_protectedAudience(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for hid
pub fn get_hid(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for credentials
pub fn get_credentials(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for wakeLock
pub fn get_wakeLock(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for virtualKeyboard
pub fn get_virtualKeyboard(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for preferences
pub fn get_preferences(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for managed
pub fn get_managed(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for serviceWorker
pub fn get_serviceWorker(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ink
pub fn get_ink(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for epubReadingSystem
pub fn get_epubReadingSystem(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for userActivation
pub fn get_userActivation(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for bluetooth
pub fn get_bluetooth(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for geolocation
pub fn get_geolocation(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for login
pub fn get_login(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for mediaSession
pub fn get_mediaSession(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for mediaDevices
pub fn get_mediaDevices(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for locks
pub fn get_locks(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for gpu
pub fn get_gpu(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for globalPrivacyControl
pub fn get_globalPrivacyControl(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for webdriver
pub fn get_webdriver(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for connection
pub fn get_connection(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ml
pub fn get_ml(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for deviceMemory
pub fn get_deviceMemory(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for storage
pub fn get_storage(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for storageBuckets
pub fn get_storageBuckets(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for appCodeName
pub fn get_appCodeName(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for appName
pub fn get_appName(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for appVersion
pub fn get_appVersion(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for platform
pub fn get_platform(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for product
pub fn get_product(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for productSub
pub fn get_productSub(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for userAgent
pub fn get_userAgent(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for vendor
pub fn get_vendor(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for vendorSub
pub fn get_vendorSub(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for oscpu
pub fn get_oscpu(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for language
pub fn get_language(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for languages
pub fn get_languages(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for onLine
pub fn get_onLine(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for cookieEnabled
pub fn get_cookieEnabled(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for plugins
pub fn get_plugins(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for mimeTypes
pub fn get_mimeTypes(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for pdfViewerEnabled
pub fn get_pdfViewerEnabled(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for hardwareConcurrency
pub fn get_hardwareConcurrency(instance: *runtime.Instance) ImplError!u64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for userAgentData
pub fn get_userAgentData(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: sendBeacon
pub fn call_sendBeacon(instance: *runtime.Instance, url: runtime.DOMString, data: anyopaque) ImplError!bool {
    _ = instance;
    _ = url;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getInstalledRelatedApps
pub fn call_getInstalledRelatedApps(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: queryHandwritingRecognizer
pub fn call_queryHandwritingRecognizer(instance: *runtime.Instance, constraint: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = constraint;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createHandwritingRecognizer
pub fn call_createHandwritingRecognizer(instance: *runtime.Instance, constraint: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = constraint;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: requestMIDIAccess
pub fn call_requestMIDIAccess(instance: *runtime.Instance, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: deprecatedReplaceInURN
pub fn call_deprecatedReplaceInURN(instance: *runtime.Instance, urnOrConfig: anyopaque, replacements: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = urnOrConfig;
    _ = replacements;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: deprecatedURNtoURL
pub fn call_deprecatedURNtoURL(instance: *runtime.Instance, urnOrConfig: anyopaque, send_reports: bool) ImplError!anyopaque {
    _ = instance;
    _ = urnOrConfig;
    _ = send_reports;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: adAuctionComponents
pub fn call_adAuctionComponents(instance: *runtime.Instance, numAdComponents: u16) ImplError!anyopaque {
    _ = instance;
    _ = numAdComponents;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: share
pub fn call_share(instance: *runtime.Instance, data: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: canShare
pub fn call_canShare(instance: *runtime.Instance, data: anyopaque) ImplError!bool {
    _ = instance;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: joinAdInterestGroup
pub fn call_joinAdInterestGroup(instance: *runtime.Instance, group: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = group;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: leaveAdInterestGroup
pub fn call_leaveAdInterestGroup(instance: *runtime.Instance, group: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = group;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: clearOriginJoinedAdInterestGroups
pub fn call_clearOriginJoinedAdInterestGroups(instance: *runtime.Instance, owner: runtime.DOMString, interestGroupsToKeep: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = owner;
    _ = interestGroupsToKeep;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: runAdAuction
pub fn call_runAdAuction(instance: *runtime.Instance, config: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = config;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: canLoadAdAuctionFencedFrame
pub fn call_canLoadAdAuctionFencedFrame(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getInterestGroupAdAuctionData
pub fn call_getInterestGroupAdAuctionData(instance: *runtime.Instance, config: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = config;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createAuctionNonce
pub fn call_createAuctionNonce(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: updateAdInterestGroups
pub fn call_updateAdInterestGroups(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getBattery
pub fn call_getBattery(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: requestMediaKeySystemAccess
pub fn call_requestMediaKeySystemAccess(instance: *runtime.Instance, keySystem: runtime.DOMString, supportedConfigurations: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = keySystem;
    _ = supportedConfigurations;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: vibrate
pub fn call_vibrate(instance: *runtime.Instance, pattern: anyopaque) ImplError!bool {
    _ = instance;
    _ = pattern;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getAutoplayPolicy
pub fn call_getAutoplayPolicy(instance: *runtime.Instance, type: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = type;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getAutoplayPolicy
pub fn call_getAutoplayPolicy(instance: *runtime.Instance, element: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = element;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getAutoplayPolicy
pub fn call_getAutoplayPolicy(instance: *runtime.Instance, context: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = context;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getGamepads
pub fn call_getGamepads(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: taintEnabled
pub fn call_taintEnabled(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: registerProtocolHandler
pub fn call_registerProtocolHandler(instance: *runtime.Instance, scheme: runtime.DOMString, url: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = scheme;
    _ = url;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: unregisterProtocolHandler
pub fn call_unregisterProtocolHandler(instance: *runtime.Instance, scheme: runtime.DOMString, url: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = scheme;
    _ = url;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: javaEnabled
pub fn call_javaEnabled(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setAppBadge
pub fn call_setAppBadge(instance: *runtime.Instance, contents: u64) ImplError!anyopaque {
    _ = instance;
    _ = contents;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: clearAppBadge
pub fn call_clearAppBadge(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

