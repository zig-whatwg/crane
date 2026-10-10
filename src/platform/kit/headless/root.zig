//! kit/headless: every gated operation's unsupported answer, and the headless
//! defaults of the required screen and system state (docs/platform-protocol.md
//! sections 5 and 6.10). A platform aliases these until it implements a
//! capability (`pub const openCaptureSource = headless.openCaptureSource;`)
//! with that capability `.unsupported`.
//!
//! Each answer is what the capability's spec does without the capability, so
//! that even a call that slipped past the gate gives the spec's unsupported
//! path: a Reply the platform cannot answer is dropped (Crane takes the
//! spec's failure path), a query answers the spec's default.

const std = @import("std");
const platform = @import("platform");

const Str = platform.Str;
const Bytes = platform.Bytes;
const Error = platform.Error;
const BrowserPlatform = platform.BrowserPlatform;
const Requester = platform.Requester;
const Reply = platform.Reply;
const TabId = platform.TabId;
const LayoutNode = platform.LayoutNode;

fn drop(reply: anytype) void {
    reply.drop(reply.context);
}

fn deliver(reply: anytype, value: anytype) void {
    reply.deliver(reply.context, value);
}

// ---------------------------------------------------------------------------
// Defaults of the required state (6.10.4): today's constants
// ---------------------------------------------------------------------------

/// src/webidl/impls/Screen.zig's defaults.
pub const default_screen: platform.ScreenInfo = .{
    .width = 1920,
    .height = 1080,
    .avail_width = 1920,
    .avail_height = 1040,
    .color_depth = 24,
    .pixel_depth = 24,
    .device_pixel_ratio = 1.0,
    .orientation = .landscape_primary,
    .orientation_angle = 0,
};

/// src/webidl/impls/Window.zig's defaults (innerWidth 1024, innerHeight 768,
/// devicePixelRatio 1).
pub const default_viewport: platform.Viewport = .{
    .width = 1024,
    .height = 768,
    .device_pixel_ratio = 1.0,
    .visual = .{ .width = 1024, .height = 768 },
};

pub fn screenInfo(browser: *BrowserPlatform) platform.ScreenInfo {
    _ = browser;
    return default_screen;
}

pub fn isOnline(browser: *BrowserPlatform) bool {
    _ = browser;
    return true;
}

pub fn userPreferences(browser: *BrowserPlatform) platform.UserPreferences {
    _ = browser;
    return .{};
}

pub fn systemVisibility(browser: *BrowserPlatform, tab: TabId) platform.Visibility {
    _ = browser;
    _ = tab;
    return .visible;
}

/// Window Management unsupported: the one screen `screenInfo` gives.
pub fn screenDetails(browser: *BrowserPlatform, requester: *const Requester, reply: Reply(platform.ScreenList)) void {
    _ = requester;
    const screens = [_]platform.ScreenInfo{screenInfo(browser)};
    deliver(reply, &platform.ScreenList{ .ptr = &screens, .len = 1 });
}

/// The Console Standard's printer with no host sink: standard error.
pub fn printConsoleMessage(browser: *BrowserPlatform, source: *const platform.ConsoleSource, level: platform.ConsoleLevel, text: Str) void {
    _ = browser;
    _ = source;
    std.debug.print("[console.{s}] {s}\n", .{ @tagName(level), text.slice() });
}

/// Nothing is pending on a platform that answers everything at once.
pub fn cancelRequest(browser: *BrowserPlatform, id: platform.RequestId) void {
    _ = browser;
    _ = id;
}

// ---------------------------------------------------------------------------
// 6.9 Layout: no layout box anywhere (today's answer)
// ---------------------------------------------------------------------------

pub fn layoutBox(browser: *BrowserPlatform, document: LayoutNode, node: LayoutNode) ?platform.BoxMetrics {
    _ = .{ browser, document, node };
    return null;
}

pub fn clientRects(browser: *BrowserPlatform, document: LayoutNode, node: LayoutNode, allocator: std.mem.Allocator) Error![]platform.Rect {
    _ = .{ browser, document, node };
    return allocator.alloc(platform.Rect, 0);
}

pub fn scrollPosition(browser: *BrowserPlatform, document: LayoutNode, node: LayoutNode) platform.Point {
    _ = .{ browser, document, node };
    return .{};
}

pub fn setScrollPosition(browser: *BrowserPlatform, document: LayoutNode, node: LayoutNode, point: platform.Point, behavior: platform.ScrollBehavior) void {
    _ = .{ browser, document, node, point, behavior };
}

pub fn hitTest(browser: *BrowserPlatform, document: LayoutNode, point: platform.Point, allocator: std.mem.Allocator) Error![]LayoutNode {
    _ = .{ browser, document, point };
    return allocator.alloc(LayoutNode, 0);
}

pub fn isRendered(browser: *BrowserPlatform, document: LayoutNode, node: LayoutNode) bool {
    _ = .{ browser, document, node };
    return false;
}

pub fn renderedText(browser: *BrowserPlatform, document: LayoutNode, node: LayoutNode, allocator: std.mem.Allocator) Error!?[]u8 {
    _ = .{ browser, document, node, allocator };
    return null;
}

pub fn viewport(browser: *BrowserPlatform, tab: TabId) platform.Viewport {
    _ = .{ browser, tab };
    return default_viewport;
}

pub fn invalidateLayout(browser: *BrowserPlatform, document: LayoutNode, node: LayoutNode, reason: platform.InvalidationReason) void {
    _ = .{ browser, document, node, reason };
}

pub fn forceLayout(browser: *BrowserPlatform, document: LayoutNode) void {
    _ = .{ browser, document };
}

// ---------------------------------------------------------------------------
// 6.1 resident memory: diagnostics report nothing
// ---------------------------------------------------------------------------

pub fn residentMemory() ?platform.MemoryReading {
    return null;
}

// ---------------------------------------------------------------------------
// 6.10.1 Permissions: no OS permission system
// ---------------------------------------------------------------------------

/// Ungoverned; the headless default state is prompt (Permissions 5.1 step 8).
pub fn platformPermissionState(browser: *BrowserPlatform, requester: *const Requester, descriptor: *const platform.PermissionDescriptor) platform.PlatformPermission {
    _ = .{ browser, requester, descriptor };
    return .{ .governed = false, .state = .prompt };
}

/// Every descriptor denied - the spec's "otherwise denied" with no UI.
pub fn requestPermission(browser: *BrowserPlatform, requester: *const Requester, descriptors: []const platform.PermissionDescriptor, reply: Reply(platform.PermissionDecisions)) void {
    _ = .{ browser, requester };
    var states: [64]platform.PermissionState = undefined;
    if (descriptors.len > states.len) return drop(reply);
    @memset(states[0..descriptors.len], .denied);
    deliver(reply, &platform.PermissionDecisions{ .ptr = &states, .len = descriptors.len });
}

// ---------------------------------------------------------------------------
// 6.10.2 Dialogs, printing and windows
// ---------------------------------------------------------------------------

/// HTML 8.9.1: "cannot show simple dialogs".
pub fn runSimpleDialog(browser: *BrowserPlatform, requester: *const Requester, request: *const platform.DialogRequest, reply: Reply(platform.DialogResult)) void {
    _ = .{ browser, requester, request };
    drop(reply);
}

/// The printing steps end without output.
pub fn printDocument(browser: *BrowserPlatform, requester: *const Requester, reply: Reply(platform.Unit)) void {
    _ = .{ browser, requester };
    deliver(reply, &platform.Unit{});
}

/// Every popup allowed.
pub fn createTopLevelTraversable(browser: *BrowserPlatform, requester: *const Requester, request: *const platform.TraversableRequest) platform.TraversableDecision {
    _ = .{ browser, requester, request };
    return .allow;
}

pub fn traversableChanged(browser: *BrowserPlatform, tab: TabId, change: *const platform.TraversableChange) void {
    _ = .{ browser, tab, change };
}

/// The viewport's rect.
pub fn windowRect(browser: *BrowserPlatform, tab: TabId) platform.Rect {
    _ = .{ browser, tab };
    return .{ .width = default_viewport.width, .height = default_viewport.height };
}

/// Ignored.
pub fn requestWindowRect(browser: *BrowserPlatform, tab: TabId, rect: platform.Rect) void {
    _ = .{ browser, tab, rect };
}

// ---------------------------------------------------------------------------
// 6.10.3 File pickers: none chosen
// ---------------------------------------------------------------------------

pub fn showFilePicker(browser: *BrowserPlatform, requester: *const Requester, options: *const platform.FilePickerOptions, reply: Reply(platform.PickedFiles)) void {
    _ = .{ browser, requester, options };
    deliver(reply, &platform.PickedFiles{ .ptr = &[_]platform.PickedFile{}, .len = 0 });
}

pub fn readPickedFile(browser: *BrowserPlatform, file: platform.FileToken, offset: u64, length: u32, reply: Reply(Bytes)) void {
    _ = .{ browser, file, offset, length };
    drop(reply);
}

pub fn releasePickedFile(browser: *BrowserPlatform, file: platform.FileToken) void {
    _ = .{ browser, file };
}

// ---------------------------------------------------------------------------
// 6.10.5 Media
// ---------------------------------------------------------------------------

/// canPlayType "".
pub fn mediaCanPlayType(browser: *BrowserPlatform, mime: Str) platform.MediaSupport {
    _ = .{ browser, mime };
    return .unsupported;
}

pub fn openMediaDecoder(browser: *BrowserPlatform, mime: Str) Error!*platform.MediaDecoder {
    _ = .{ browser, mime };
    return error.NotSupported;
}

pub fn pushMediaData(decoder: *platform.MediaDecoder, bytes: Bytes, end_of_stream: bool, metadata: *platform.MediaMetadata) platform.MediaResult {
    _ = .{ decoder, bytes, end_of_stream, metadata };
    return .unsupported;
}

pub fn mediaVideoSize(decoder: *platform.MediaDecoder, seconds: f64, size: *platform.VideoSize) bool {
    _ = .{ decoder, seconds, size };
    return false;
}

pub fn closeMediaDecoder(decoder: *platform.MediaDecoder) void {
    _ = decoder;
}

/// supported false.
pub fn mediaDecodingInfo(browser: *BrowserPlatform, config: *const platform.MediaDecodingConfig) platform.DecodingInfo {
    _ = .{ browser, config };
    return .{};
}

/// isConfigSupported false; configure NotSupportedError.
pub fn openCodec(browser: *BrowserPlatform, config: *const platform.CodecConfig, output: platform.CodecSink) Error!*platform.Codec {
    _ = .{ browser, config, output };
    return error.NotSupported;
}

pub fn codecInput(codec: *platform.Codec, chunk: *const platform.EncodedChunk, reply: Reply(platform.Unit)) void {
    _ = .{ codec, chunk };
    drop(reply);
}

pub fn codecFlush(codec: *platform.Codec, reply: Reply(platform.Unit)) void {
    _ = codec;
    drop(reply);
}

pub fn closeCodec(codec: *platform.Codec) void {
    _ = codec;
}

/// requestMediaKeySystemAccess NotSupportedError.
pub fn requestKeySystemAccess(browser: *BrowserPlatform, requester: *const Requester, request: *const platform.KeySystemRequest, reply: Reply(platform.KeySystemAccess)) void {
    _ = .{ browser, requester, request };
    drop(reply);
}

pub fn createKeySession(browser: *BrowserPlatform, key_system: Str, session_type: platform.KeySessionType, reply: Reply(platform.KeySessionId)) void {
    _ = .{ browser, key_system, session_type };
    drop(reply);
}

pub fn keySessionGenerateRequest(browser: *BrowserPlatform, session: platform.KeySessionId, init_data_type: Str, init_data: Bytes, reply: Reply(platform.Unit)) void {
    _ = .{ browser, session, init_data_type, init_data };
    drop(reply);
}

pub fn keySessionUpdate(browser: *BrowserPlatform, session: platform.KeySessionId, response: Bytes, reply: Reply(platform.Unit)) void {
    _ = .{ browser, session, response };
    drop(reply);
}

pub fn closeKeySession(browser: *BrowserPlatform, session: platform.KeySessionId, reply: Reply(platform.Unit)) void {
    _ = .{ browser, session };
    drop(reply);
}

/// enumerateDevices() empty.
pub fn enumerateMediaDevices(browser: *BrowserPlatform, requester: *const Requester, reply: Reply(platform.MediaDeviceList)) void {
    _ = .{ browser, requester };
    deliver(reply, &platform.MediaDeviceList{ .ptr = &[_]platform.MediaDeviceInfo{}, .len = 0 });
}

/// getUserMedia NotFoundError.
pub fn openCaptureSource(browser: *BrowserPlatform, requester: *const Requester, request: *const platform.CaptureRequest, reply: Reply(platform.CaptureOpened)) void {
    _ = .{ browser, requester, request };
    drop(reply);
}

pub fn captureSettings(source: *platform.CaptureSource) platform.TrackSettings {
    _ = source;
    return .{};
}

pub fn captureCapabilities(source: *platform.CaptureSource) platform.TrackCapabilities {
    _ = source;
    return .{};
}

pub fn applyCaptureConstraints(source: *platform.CaptureSource, constraints: *const platform.CaptureConstraints, reply: Reply(platform.ConstraintResult)) void {
    _ = .{ source, constraints };
    drop(reply);
}

pub fn setCaptureSink(source: *platform.CaptureSource, sink: platform.FrameSink) void {
    _ = .{ source, sink };
}

pub fn closeCaptureSource(source: *platform.CaptureSource) void {
    _ = source;
}

/// getDisplayMedia NotAllowedError.
pub fn chooseDisplaySurface(browser: *BrowserPlatform, requester: *const Requester, options: *const platform.DisplayMediaOptions, reply: Reply(platform.CaptureOpened)) void {
    _ = .{ browser, requester, options };
    drop(reply);
}

/// No output device: media plays silently.
pub fn openAudioOutput(browser: *BrowserPlatform, requester: *const Requester, format: *const platform.AudioFormat, device_id: ?Str) Error!*platform.AudioOutput {
    _ = .{ browser, requester, format, device_id };
    return error.NotSupported;
}

pub fn writeAudio(output: *platform.AudioOutput, frames: Bytes) usize {
    _ = output;
    return frames.len;
}

pub fn audioOutputLatency(output: *platform.AudioOutput) f64 {
    _ = output;
    return 0;
}

pub fn closeAudioOutput(output: *platform.AudioOutput) void {
    _ = output;
}

/// selectAudioOutput NotAllowedError.
pub fn selectAudioOutput(browser: *BrowserPlatform, requester: *const Requester, reply: Reply(platform.MediaDeviceChoice)) void {
    _ = .{ browser, requester };
    drop(reply);
}

/// No voices.
pub fn speechVoices(browser: *BrowserPlatform, allocator: std.mem.Allocator) Error![]platform.Voice {
    _ = browser;
    return allocator.alloc(platform.Voice, 0);
}

/// `error` "synthesis-unavailable".
pub fn speak(browser: *BrowserPlatform, requester: *const Requester, utterance: *const platform.Utterance, reply: Reply(platform.SpeechEnd)) void {
    _ = .{ browser, requester, utterance };
    deliver(reply, &platform.SpeechEnd{ .kind = .failed, .error_code = Str.from("synthesis-unavailable") });
}

pub fn pauseSpeech(browser: *BrowserPlatform) void {
    _ = browser;
}

pub fn resumeSpeech(browser: *BrowserPlatform) void {
    _ = browser;
}

pub fn cancelSpeech(browser: *BrowserPlatform) void {
    _ = browser;
}

/// `error` "service-not-allowed".
pub fn startRecognition(browser: *BrowserPlatform, requester: *const Requester, options: *const platform.RecognitionOptions) Error!platform.RecognitionId {
    _ = .{ browser, requester, options };
    return error.NotSupported;
}

pub fn stopRecognition(browser: *BrowserPlatform, id: platform.RecognitionId) void {
    _ = .{ browser, id };
}

/// Ignored.
pub fn setMediaSession(browser: *BrowserPlatform, tab: TabId, state: *const platform.MediaSessionState) void {
    _ = .{ browser, tab, state };
}

/// NotSupportedError.
pub fn enterPictureInPicture(browser: *BrowserPlatform, requester: *const Requester, reply: Reply(platform.PictureInPictureWindow)) void {
    _ = .{ browser, requester };
    drop(reply);
}

pub fn exitPictureInPicture(browser: *BrowserPlatform, tab: TabId, reply: Reply(platform.Unit)) void {
    _ = .{ browser, tab };
    drop(reply);
}

/// NotFoundError.
pub fn startPresentation(browser: *BrowserPlatform, requester: *const Requester, urls: platform.StrList, reply: Reply(platform.PresentationConnection)) void {
    _ = .{ browser, requester, urls };
    drop(reply);
}

/// NotSupportedError.
pub fn watchRemotePlaybackAvailability(browser: *BrowserPlatform, requester: *const Requester, media_url: Str, reply: Reply(platform.Availability)) void {
    _ = .{ browser, requester, media_url };
    drop(reply);
}

// ---------------------------------------------------------------------------
// 6.10.6 Clipboard: read and write reject with NotAllowedError
// ---------------------------------------------------------------------------

pub fn readClipboard(browser: *BrowserPlatform, requester: *const Requester, types: []const Str, reply: Reply(platform.ClipboardItems)) void {
    _ = .{ browser, requester, types };
    drop(reply);
}

pub fn writeClipboard(browser: *BrowserPlatform, requester: *const Requester, items: *const platform.ClipboardItems, reply: Reply(platform.Unit)) void {
    _ = .{ browser, requester, items };
    drop(reply);
}

// ---------------------------------------------------------------------------
// 6.10.7 Notifications, push and background work
// ---------------------------------------------------------------------------

/// Never shown.
pub fn showNotification(browser: *BrowserPlatform, requester: *const Requester, notification: *const platform.NotificationData, reply: Reply(bool)) void {
    _ = .{ browser, requester, notification };
    deliver(reply, &false);
}

pub fn closeNotification(browser: *BrowserPlatform, id: platform.NotificationId) void {
    _ = .{ browser, id };
}

pub fn maxNotificationActions(browser: *BrowserPlatform) u32 {
    _ = browser;
    return 0;
}

/// The Push API's no-push-service rejection.
pub fn pushSubscribe(browser: *BrowserPlatform, requester: *const Requester, options: *const platform.PushSubscriptionOptions, reply: Reply(platform.PushSubscription)) void {
    _ = .{ browser, requester, options };
    drop(reply);
}

pub fn pushUnsubscribe(browser: *BrowserPlatform, requester: *const Requester, scope: Str, reply: Reply(bool)) void {
    _ = .{ browser, requester, scope };
    drop(reply);
}

pub fn pushSubscription(browser: *BrowserPlatform, requester: *const Requester, scope: Str, reply: Reply(platform.PushSubscriptionState)) void {
    _ = .{ browser, requester, scope };
    drop(reply);
}

/// The registration rejects.
pub fn registerBackgroundSync(browser: *BrowserPlatform, requester: *const Requester, tag: Str, reply: Reply(platform.Unit)) void {
    _ = .{ browser, requester, tag };
    drop(reply);
}

pub fn startBackgroundFetch(browser: *BrowserPlatform, requester: *const Requester, request: *const platform.BackgroundFetchRequest, reply: Reply(platform.Unit)) void {
    _ = .{ browser, requester, request };
    drop(reply);
}

/// Nothing shown.
pub fn setAppBadge(browser: *BrowserPlatform, requester: *const Requester, value: ?u64) void {
    _ = .{ browser, requester, value };
}

/// Ignored, as HTML permits.
pub fn registerProtocolHandler(browser: *BrowserPlatform, requester: *const Requester, scheme: Str, url: Str) void {
    _ = .{ browser, requester, scheme, url };
}

// ---------------------------------------------------------------------------
// 6.10.8 Location, sensors and device state
// ---------------------------------------------------------------------------

/// POSITION_UNAVAILABLE.
pub fn currentPosition(browser: *BrowserPlatform, requester: *const Requester, options: *const platform.PositionOptions, reply: Reply(platform.PositionResult)) void {
    _ = .{ browser, requester, options };
    deliver(reply, &platform.PositionResult{ .error_code = .position_unavailable });
}

pub fn watchPosition(browser: *BrowserPlatform, requester: *const Requester, options: *const platform.PositionOptions) Error!platform.WatchId {
    _ = .{ browser, requester, options };
    return error.NotSupported;
}

pub fn clearWatch(browser: *BrowserPlatform, id: platform.WatchId) void {
    _ = .{ browser, id };
}

/// NotReadableError.
pub fn startSensor(browser: *BrowserPlatform, requester: *const Requester, sensor_type: platform.SensorType, frequency: f64) Error!*platform.SensorHandle {
    _ = .{ browser, requester, sensor_type, frequency };
    return error.NotSupported;
}

pub fn stopSensor(sensor: *platform.SensorHandle) void {
    _ = sensor;
}

/// No events.
pub fn startDeviceOrientation(browser: *BrowserPlatform, requester: *const Requester) Error!void {
    _ = .{ browser, requester };
    return error.NotSupported;
}

pub fn stopDeviceOrientation(browser: *BrowserPlatform) void {
    _ = browser;
}

/// The Battery Status default: charging, level 1.0.
pub fn batteryStatus(browser: *BrowserPlatform) platform.BatteryStatus {
    _ = browser;
    return .{};
}

/// No vibration mechanism.
pub fn vibrate(browser: *BrowserPlatform, pattern: []const u32) bool {
    _ = .{ browser, pattern };
    return false;
}

/// type "unknown".
pub fn connectionInfo(browser: *BrowserPlatform) platform.ConnectionInfo {
    _ = browser;
    return .{};
}

/// NotSupportedError.
pub fn startPressureObserver(browser: *BrowserPlatform, requester: *const Requester, source: platform.PressureSource, sample_interval_ms: u32) Error!platform.PressureObserverId {
    _ = .{ browser, requester, source, sample_interval_ms };
    return error.NotSupported;
}

pub fn stopPressureObserver(browser: *BrowserPlatform, id: platform.PressureObserverId) void {
    _ = .{ browser, id };
}

/// "continuous".
pub fn devicePosture(browser: *BrowserPlatform) platform.Posture {
    _ = browser;
    return .continuous;
}

/// NotAllowedError.
pub fn startIdleDetection(browser: *BrowserPlatform, requester: *const Requester, threshold_ms: u64) Error!platform.IdleDetectorId {
    _ = .{ browser, requester, threshold_ms };
    return error.NotSupported;
}

pub fn stopIdleDetection(browser: *BrowserPlatform, id: platform.IdleDetectorId) void {
    _ = .{ browser, id };
}

// ---------------------------------------------------------------------------
// 6.10.9 Devices: no device chosen
// ---------------------------------------------------------------------------

pub fn chooseDevice(browser: *BrowserPlatform, requester: *const Requester, kind: platform.DeviceKind, filters: *const platform.DeviceFilters, reply: Reply(platform.DeviceChoice)) void {
    _ = .{ browser, requester, filters };
    deliver(reply, &platform.DeviceChoice{ .chosen = false, .device = .{ .id = .{ .id = 0 }, .kind = kind } });
}

pub fn grantedDevices(browser: *BrowserPlatform, requester: *const Requester, kind: platform.DeviceKind, reply: Reply(platform.DeviceList)) void {
    _ = .{ browser, requester, kind };
    deliver(reply, &platform.DeviceList{ .ptr = &[_]platform.DeviceInfo{}, .len = 0 });
}

pub fn openDevice(browser: *BrowserPlatform, device: platform.DeviceId, reply: Reply(platform.OpenedDevice)) void {
    _ = .{ browser, device };
    drop(reply);
}

pub fn closeDevice(handle: *platform.DeviceHandle) void {
    _ = handle;
}

pub fn deviceRequest(handle: *platform.DeviceHandle, request: *const platform.DeviceRequest, reply: Reply(platform.DeviceResponse)) void {
    _ = .{ handle, request };
    drop(reply);
}

/// No gamepads.
pub fn gamepads(browser: *BrowserPlatform, out: []platform.GamepadState) usize {
    _ = .{ browser, out };
    return 0;
}

// ---------------------------------------------------------------------------
// 6.10.10 Payments, credentials, sharing, input and UI
// ---------------------------------------------------------------------------

pub fn canMakePayment(browser: *BrowserPlatform, requester: *const Requester, request: *const platform.PaymentRequestData, reply: Reply(bool)) void {
    _ = .{ browser, requester, request };
    deliver(reply, &false);
}

/// show() NotSupportedError.
pub fn showPayment(browser: *BrowserPlatform, requester: *const Requester, request: *const platform.PaymentRequestData, reply: Reply(platform.PaymentResponse)) void {
    _ = .{ browser, requester, request };
    drop(reply);
}

pub fn completePayment(browser: *BrowserPlatform, id: platform.PaymentId, result: platform.PaymentComplete, reply: Reply(platform.Unit)) void {
    _ = .{ browser, id, result };
    deliver(reply, &platform.Unit{});
}

pub fn abortPayment(browser: *BrowserPlatform, id: platform.PaymentId, reply: Reply(bool)) void {
    _ = .{ browser, id };
    deliver(reply, &false);
}

/// NotAllowedError.
pub fn createCredential(browser: *BrowserPlatform, requester: *const Requester, options: *const platform.CredentialOptions, reply: Reply(platform.CredentialResult)) void {
    _ = .{ browser, requester, options };
    drop(reply);
}

pub fn getCredential(browser: *BrowserPlatform, requester: *const Requester, options: *const platform.CredentialOptions, reply: Reply(platform.CredentialResult)) void {
    _ = .{ browser, requester, options };
    drop(reply);
}

/// Availability false.
pub fn platformAuthenticatorAvailable(browser: *BrowserPlatform, reply: Reply(bool)) void {
    _ = browser;
    deliver(reply, &false);
}

pub fn requestIdentityCredential(browser: *BrowserPlatform, requester: *const Requester, request: *const platform.IdentityRequest, reply: Reply(platform.IdentityCredential)) void {
    _ = .{ browser, requester, request };
    drop(reply);
}

/// canShare false; share rejects.
pub fn canShare(browser: *BrowserPlatform, data: *const platform.ShareData) bool {
    _ = .{ browser, data };
    return false;
}

pub fn share(browser: *BrowserPlatform, requester: *const Requester, data: *const platform.ShareData, reply: Reply(bool)) void {
    _ = .{ browser, requester, data };
    drop(reply);
}

/// Empty properties; select rejects.
pub fn contactProperties(browser: *BrowserPlatform, reply: Reply(platform.ContactPropertyList)) void {
    _ = browser;
    deliver(reply, &platform.ContactPropertyList{ .properties = .{} });
}

pub fn selectContacts(browser: *BrowserPlatform, requester: *const Requester, request: *const platform.ContactsRequest, reply: Reply(platform.ContactList)) void {
    _ = .{ browser, requester, request };
    drop(reply);
}

/// The fullscreen error path.
pub fn requestFullscreen(browser: *BrowserPlatform, requester: *const Requester, tab: TabId, reply: Reply(bool)) void {
    _ = .{ browser, requester, tab };
    deliver(reply, &false);
}

pub fn exitFullscreen(browser: *BrowserPlatform, tab: TabId) void {
    _ = .{ browser, tab };
}

/// `pointerlockerror`.
pub fn requestPointerLock(browser: *BrowserPlatform, requester: *const Requester, reply: Reply(bool)) void {
    _ = .{ browser, requester };
    deliver(reply, &false);
}

pub fn exitPointerLock(browser: *BrowserPlatform, tab: TabId) void {
    _ = .{ browser, tab };
}

/// Rejects.
pub fn lockKeys(browser: *BrowserPlatform, requester: *const Requester, keys: platform.StrList, reply: Reply(platform.Unit)) void {
    _ = .{ browser, requester, keys };
    drop(reply);
}

pub fn unlockKeys(browser: *BrowserPlatform, tab: TabId) void {
    _ = .{ browser, tab };
}

/// An empty map.
pub fn keyboardLayoutMap(browser: *BrowserPlatform, reply: Reply(platform.KeyboardMap)) void {
    _ = browser;
    deliver(reply, &platform.KeyboardMap{ .ptr = &[_]platform.KeyboardMapEntry{}, .len = 0 });
}

/// NotAllowedError.
pub fn requestWakeLock(browser: *BrowserPlatform, requester: *const Requester, kind: platform.WakeLockType, reply: Reply(platform.WakeLockId)) void {
    _ = .{ browser, requester, kind };
    drop(reply);
}

pub fn releaseWakeLock(browser: *BrowserPlatform, id: platform.WakeLockId) void {
    _ = .{ browser, id };
}

/// AbortError.
pub fn openEyeDropper(browser: *BrowserPlatform, requester: *const Requester, reply: Reply(platform.EyeDropperResult)) void {
    _ = .{ browser, requester };
    drop(reply);
}

/// An empty list.
pub fn queryLocalFonts(browser: *BrowserPlatform, requester: *const Requester, reply: Reply(platform.FontList)) void {
    _ = .{ browser, requester };
    deliver(reply, &platform.FontList{ .ptr = &[_]platform.FontData{}, .len = 0 });
}

/// No-op.
pub fn showVirtualKeyboard(browser: *BrowserPlatform, tab: TabId) void {
    _ = .{ browser, tab };
}

pub fn hideVirtualKeyboard(browser: *BrowserPlatform, tab: TabId) void {
    _ = .{ browser, tab };
}

// ---------------------------------------------------------------------------
// The headless declaration: every capability unsupported
// ---------------------------------------------------------------------------

/// Every capability `.unsupported`: a platform starts from this and declares
/// what it has.
pub const capabilities: platform.Capabilities = blk: {
    var all: platform.Capabilities = undefined;
    for (@typeInfo(platform.Capabilities).@"struct".fields) |field| @field(all, field.name) = .unsupported;
    break :blk all;
};
