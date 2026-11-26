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

pub const State = Navigator.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

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
/// Keyboard Lock: "[SecureContext, SameObject] readonly attribute Keyboard
/// keyboard" - one Keyboard per Navigator, made in its relevant realm on
/// first use. The generated getter keeps it (`cached_keyboard`), and the
/// binding ties its wrapper to the Navigator's with the [SameObject] edge,
/// so it lives exactly as long as the Navigator's wrapper does.
pub fn get_keyboard(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return interfaces.Keyboard.init(instance.ctx.allocator, instance.ctx);
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
    return interfaces.Permissions.init(instance.ctx.allocator, instance.ctx);
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
///
/// Pointer Events 3: "the maximum number of simultaneous touch contacts
/// supported by the device" - none on a headless device (0, as headless
/// Chrome answers), unless the host emulates touch for the tab
/// (html.window.host_overrides: CDP Emulation.setTouchEmulationEnabled).
pub fn get_maxTouchPoints(instance: *runtime.Instance) anyerror!i32 {
    if (hostOverridesOf(instance)) |overrides| if (overrides.max_touch_points) |points| return points;
    return 0;
}

/// The host's overrides for the tab this navigator's Window shows
/// (html.window.host_overrides: CDP's Emulation, WebDriver BiDi's
/// emulation), if it is a Window's.
fn hostOverridesOf(instance: *runtime.Instance) ?*const @import("html").window.host_overrides.HostOverrides {
    const window = @import("html").user_activation.windowOfRealm(instance.ctx) orelse return null;
    const bc = @import("dom").browser_state.browsingContextOf(window) orelse return null;
    return &bc.getTop().host_overrides;
}

/// Getter for attribution
pub fn get_attribution(instance: *runtime.Instance) anyerror!*runtime.Instance {
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

/// Getter for serviceWorker (Service Workers 3.3): "the
/// ServiceWorkerContainer object that is associated with this" - made in its
/// relevant realm on first use and kept by the generated getter
/// ([SameObject]), which the binding ties to this object's wrapper.
pub fn get_serviceWorker(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return interfaces.ServiceWorkerContainer.init(instance.ctx.allocator, instance.ctx);
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

/// Getter for userActivation (HTML 6.4.4): "[SameObject] readonly attribute
/// UserActivation userActivation" - "a Navigator object has an associated
/// user activation, which is a UserActivation object", made in its relevant
/// realm on first use. The generated getter keeps it
/// (`cached_userActivation`), and the binding ties its wrapper to the
/// Navigator's with the [SameObject] edge.
pub fn get_userActivation(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return interfaces.UserActivation.init(instance.ctx.allocator, instance.ctx);
}

/// Getter for bluetooth
pub fn get_bluetooth(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for geolocation (W3C Geolocation §5): "[SameObject] readonly
/// attribute Geolocation geolocation". Generated getter caches the instance
/// (`cached_geolocation`) and ties its wrapper via `same_object_cache.made`.
pub fn get_geolocation(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return interfaces.Geolocation.init(instance.ctx.allocator, instance.ctx);
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

/// Operation: getGamepads
pub fn call_getGamepads(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getBattery
pub fn call_getBattery(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Beacon §3.2: parse in the relevant settings object's base URL, extract
/// the body with keepalive, then hand the request to the shared fetch owner.
pub fn call_sendBeacon(instance: *runtime.Instance, url: runtime.USVString, data: webidl.Opt(?typedefs.BodyInit)) anyerror!bool {
    const ctx = instance.ctx;
    const allocator = ctx.allocator;
    const fetch = @import("fetch");
    const api_parser = @import("api_parser");
    const global: ?*runtime.Instance = if (ctx.getRealm()) |realm|
        if (realm.global_object) |raw| @ptrCast(@alignCast(raw)) else null
    else
        null;
    var base: ?[]const u8 = null;
    if (global) |g| {
        if (std.mem.eql(u8, g.vtable.name, "Window")) {
            if (interfaces.Window.get_document(g) catch null) |document|
                base = try interfaces.Node.get_baseURI(document);
        }
    }
    defer if (base) |b| allocator.free(b);
    var parsed_base: ?@import("url_record").URLRecord = null;
    defer if (parsed_base) |*b| b.deinit();
    if (base orelse ctx.documentUrl()) |b| parsed_base = api_parser.parseURL(allocator, b, null) catch null;
    var parsed = api_parser.parseURL(allocator, url, if (parsed_base) |*b| b else null) catch |err| {
        if (err == error.OutOfMemory) return error.OutOfMemory;
        return error.TypeError;
    };
    defer parsed.deinit();
    if (!std.mem.eql(u8, parsed.scheme(), "http") and !std.mem.eql(u8, parsed.scheme(), "https")) return error.TypeError;
    const serialized = try @import("url_serializer").serialize(allocator, &parsed, false);
    defer allocator.free(serialized);
    const relevant_global = global orelse return error.InvalidState;
    const request = try fetch.internal.InternalRequest.init(allocator, serialized);
    var owns_request = true;
    defer if (owns_request) request.deinit();
    try request.setMethod("POST");
    request.keepalive = true;
    request.mode = .no_cors;
    request.credentials_mode = .include;
    request.initiator_type = .beacon;
    // Script-supplied non-safelisted Content-Type must take Fetch's CORS
    // preflight path (Beacon §4); it is not a UA-generated trusted header.
    request.unsafe_request = true;
    if (data.wasPassed()) {
        if (data.getValue()) |body_init| {
            var extracted = try @import("fetch_body").extract(allocator, body_init, true);
            defer extracted.deinit();
            if (extracted.content_type) |content_type| {
                if (!fetch.internal.isCORSSafelistedRequestHeader("Content-Type", content_type)) request.mode = .cors;
                try request.header_list.append("Content-Type", content_type);
            }
            if (extracted.takeBody()) |body| {
                // Extracted byte bodies own their storage; their replay source
                // must point at that storage after the BodyInit call ends.
                body.source = .{ .bytes = body.data.items };
                request.body = .{ .body = body };
            }
        }
    }
    var client = try @import("dom").global_settings.requestClient(relevant_global);
    defer client.deinit();
    try fetch.internal.populateRequestFromClient(request, client.request);
    // Beacon §3.2: Fetch's shared keepalive owner checks the fetch group's
    // in-flight quota synchronously, and takes the request on every path.
    owns_request = false;
    return @import("dom").keepalive_fetch.send(relevant_global, request, .{});
}

/// Operation: queryHandwritingRecognizer
pub fn call_queryHandwritingRecognizer(instance: *runtime.Instance, constraint: dictionaries.HandwritingModelConstraint) anyerror!runtime.JSValue {
    _ = instance;
    _ = constraint;
    return error.NotImplemented;
}

/// Operation: share
pub fn call_share(instance: *runtime.Instance, data: webidl.Opt(dictionaries.ShareData)) anyerror!runtime.JSValue {
    _ = instance;
    _ = data;
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

/// Getter for cpuPerformance
pub fn get_cpuPerformance(instance: *runtime.Instance) anyerror!u16 {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: install
pub fn call_install(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}
