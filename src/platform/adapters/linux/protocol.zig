//! The linux platform (docs/platform-protocol.md section 9).
//!
//! Step 0 of the platform protocol: a composition of kit parts implementing
//! today's behaviour - kit/posix for clocks, randomness, threads, files and
//! identity, kit/memory_store for the storage engine, kit/curl's event-loop
//! port, kit/crypto, and kit/headless for every capability offered to pages
//! but these: fonts are native - kit/sfnt, and fontconfig loaded at run time
//! (fonts.zig, decision 20); images decode through kit/image_decoding (D1,
//! the user 2026-11-09); the clipboard is kit/memory_clipboard per Browser
//! (D2, the user 2026-11-09), as headless Chrome's. The rest of the link plan
//! of contract 10.2 (system SQLite, OpenSSL 3, the distro CA bundle, the
//! X11/Wayland clipboard where a display is present) arrives with its
//! recipes steps.
//!
//! The adapter chooses, per capability, between built-in kit code and
//! linking out to the OS (the user, 2026-11-09 21:09 UTC: "The platform
//! itself that is compiled in will decide if these features are built within
//! the platform or dynamically link out to existing capabilities on the
//! platform. For example, the clipboard too."). This is Crane's default
//! platform - what Crane's own browser, the release console, and the
//! production WPT runner compile in - so the capabilities every browser
//! ships are built in here today: image decoding (kit/image_decoding, D1),
//! image encoding (kit/image_encoding: PNG, the integrator 2026-11-12),
//! media decoding (kit/media_decoding: WAV linear PCM, D4) and the
//! clipboard (kit/memory_clipboard per Browser, D2).

const std = @import("std");
const platform = @import("platform");
const platform_options = @import("platform_options");
const posix = @import("kit_posix");
const headless = @import("kit_headless");
const brotli = @import("kit_brotli");
const inflate = @import("kit_inflate");
const memory_store = @import("kit_memory_store");
const curl = @import("kit_curl");
/// The bundled libcurl is in the link, and with it the zlib build.zig.zon
/// pins (kit/curl/trust.zig `enabled`: the bundled libcurl and its mbedTLS).
const bundled_zlib = curl.share.trust.enabled;
const crypto = @import("kit_crypto");
const browser_state = @import("kit_browser_state");
const memory_clipboard = @import("kit_memory_clipboard");

/// kit/sfnt and fontconfig (fonts.zig, decision 20), unless font_decoding
/// is compiled out.
const font_decoding = for (platform_options.platform_without) |capability| {
    if (std.mem.eql(u8, capability, "font_decoding")) break false;
} else true;
const fonts = if (font_decoding) @import("fonts.zig") else headless;

/// kit/image_decoding's built-in decoders - PNG, BMP and GIF in Zig, JPEG and
/// SVG through kit/image_codecs (D1, the user 2026-11-09) - unless
/// image_decoding is compiled out: then kit/headless's answers, every image
/// broken, as the testing platform does.
const image_decoding_built_in = for (platform_options.platform_without) |capability| {
    if (std.mem.eql(u8, capability, "image_decoding")) break false;
} else true;
const image_decoding = if (image_decoding_built_in) @import("kit_image_decoding") else headless;

/// kit/image_encoding's built-in encoder - PNG in Zig, which HTML 4.12.5.5
/// requires (the integrator, 2026-11-12, D1's pattern) - unless
/// image_encoding is compiled out: then kit/headless's answers, every
/// serialization of a bitmap null, as the testing platform does.
const image_encoding_built_in = for (platform_options.platform_without) |capability| {
    if (std.mem.eql(u8, capability, "image_encoding")) break false;
} else true;
const image_encoding = if (image_encoding_built_in) @import("kit_image_encoding") else headless;

/// kit/media_decoding's built-in decoders - WAV linear PCM (D4, the user
/// 2026-11-09) - unless media_decoding is compiled out: then kit/headless's
/// answers, canPlayType "" for every type.
const media_decoding_built_in = for (platform_options.platform_without) |capability| {
    if (std.mem.eql(u8, capability, "media_decoding")) break false;
} else true;
const media_decoding = if (media_decoding_built_in) @import("kit_media_decoding") else headless;

/// Per-Browser state beyond kit/browser_state's, fresh for every Browser:
/// the in-memory clipboard (kit/memory_clipboard; the user's ruling D2,
/// 2026-11-09), as headless Chrome keeps one - components/headless/
/// clipboard/headless_clipboard.cc, a ui::ClipboardNonBacked that
/// headless/lib/browser/headless_browser_main_parts.cc installs.
const Extra = struct {
    clipboard: memory_clipboard.Clipboard,

    pub fn init(allocator: std.mem.Allocator, options: *const platform.BrowserOptions) error{OutOfMemory}!Extra {
        _ = options;
        return .{ .clipboard = .init(allocator) };
    }

    pub fn deinit(self: *Extra) void {
        self.clipboard.deinit();
    }
};

const State = browser_state.BrowserState(Extra);

/// openMediaDecoder: kit/media_decoding's, with the Browser's allocator.
fn openMedia(browser: *platform.BrowserPlatform, mime: platform.Str) platform.Error!*platform.MediaDecoder {
    if (!media_decoding_built_in) return headless.openMediaDecoder(browser, mime);
    return media_decoding.openMediaDecoder(State.of(browser).allocator, mime);
}

fn clipboardRead(browser: *platform.BrowserPlatform, requester: *const platform.Requester, types: []const platform.Str, reply: platform.Reply(platform.ClipboardItems)) void {
    _ = requester;
    State.of(browser).extra.clipboard.read(types, reply);
}

fn clipboardWrite(browser: *platform.BrowserPlatform, requester: *const platform.Requester, items: *const platform.ClipboardItems, reply: platform.Reply(platform.Unit)) void {
    _ = requester;
    State.of(browser).extra.clipboard.write(items, reply);
}

pub const protocol = struct {
    pub const name = "linux";

    /// No options of its own: the OS's permission system and native UI need
    /// none (contract 3.2).
    pub const PlatformBrowserOptions = extern struct {};

    pub const identity: platform.Identity = posix.identity;

    /// Today's behaviour, declared. Everything a page asks of a host is
    /// unsupported (kit/headless) until its recipes step builds it, but the
    /// fonts, image decoding and the in-memory clipboard.
    pub const capabilities: platform.Capabilities = blk: {
        var c = headless.capabilities;
        c.brotli = .native; // Pinned RFC 7932 codec; identical on every OS.
        // zlib's inflate for Fetch's gzip and deflate (kit/inflate/zlib.zig):
        // only where the bundled libcurl links the pinned zlib - not with
        // -Dsystem-curl, whose zlib is the system libcurl's own.
        c.zlib_inflate = if (bundled_zlib) .native else .unsupported;
        // Crane's stores persist under a profile directory today.
        c.persistent_storage = .native;
        // Fetch's scheme fetch "file" reads local files today.
        c.file_urls = .native;
        // The vendored nghttp2 (build.zig -Dhttp2, not with -Dsystem-curl).
        c.http2 = if (platform_options.http2) .native else .unsupported;
        // src/platform/memory.zig reads task_info / /proc/self/statm.
        c.resident_memory = .native;
        // Reserved address space for each Browser's heap (6.11): kit/posix.
        c.address_space = .native;
        // kit/memory_clipboard per Browser (D2, the user 2026-11-09), as
        // headless Chrome's. Deviation: nothing leaves the Browser and nothing
        // another application copies arrives.
        c.clipboard = .emulated;
        // kit/image_decoding, built in (D1, the user 2026-11-09): PNG, BMP,
        // GIF, JPEG and SVG, the testing platform's decoders.
        if (image_decoding_built_in) c.image_decoding = .native;
        // kit/image_encoding, built in: PNG, the testing platform's encoder.
        if (image_encoding_built_in) c.image_encoding = .native;
        // kit/media_decoding, built in (D4, the user 2026-11-09): WAV linear
        // PCM; WebM, Ogg and MP4 answer "" until a decoder for them exists.
        if (media_decoding_built_in) c.media_decoding = .native;
        // kit/sfnt, with fontconfig loaded at run time for installed faces
        // (fonts.zig). Without fontconfig there are none; web fonts load.
        if (font_decoding) c.font_decoding = .native;
        break :blk c;
    };

    pub const createBrotliDecoder = brotli.createBrotliDecoder;
    pub const decompressBrotli = brotli.decompressBrotli;
    pub const destroyBrotliDecoder = brotli.destroyBrotliDecoder;
    pub const createBrotliEncoder = brotli.createBrotliEncoder;
    pub const compressBrotli = brotli.compressBrotli;
    pub const destroyBrotliEncoder = brotli.destroyBrotliEncoder;
    pub const createInflateDecoder = if (bundled_zlib) inflate.zlib_inflate.createInflateDecoder else headless.createInflateDecoder;
    pub const inflateChunk = if (bundled_zlib) inflate.zlib_inflate.inflateChunk else headless.inflateChunk;
    pub const destroyInflateDecoder = if (bundled_zlib) inflate.zlib_inflate.destroyInflateDecoder else headless.destroyInflateDecoder;
    pub const createBrowserPlatform = State.create;
    pub const destroyBrowserPlatform = State.destroy;
    pub const initializePlatform = posix.initializePlatform;
    pub const deinitializePlatform = posix.deinitializePlatform;
    pub const defaultDataDirectory = posix.defaultDataDirectory;
    pub const preferredLanguages = posix.preferredLanguages;
    pub const defaultTimeZone = posix.defaultTimeZone;
    pub const localDateTime = posix.localDateTime;
    pub const logicalProcessorCount = posix.logicalProcessorCount;
    pub const deviceMemoryGiB = posix.deviceMemoryGiB;
    pub const residentMemory = posix.residentMemory;
    pub const monotonicNow = posix.monotonicNow;
    pub const wallNow = posix.wallNow;
    pub const browserClock = posix.browserClock;
    pub const sleepThread = posix.sleepThread;
    pub const fillRandom = posix.fillRandom;
    pub const fillBrowserRandom = posix.fillBrowserRandom;
    pub const spawnThread = posix.spawnThread;
    pub const joinThread = posix.joinThread;
    pub const attachSignalStack = posix.attachSignalStack;
    pub const detachSignalStack = posix.detachSignalStack;
    // 6.11 Address space: kit/posix's, which takes this OS's own path
    // (darwin: a VM tag per label, MADV_FREE_REUSABLE / MADV_FREE_REUSE;
    // Linux: VMA names, MADV_NOHUGEPAGE on the node cage, mprotect-only
    // commit), chosen by the target it is built for.
    pub const pageSize = posix.pageSize;
    pub const reserveAddressSpace = posix.reserveAddressSpace;
    pub const labelAddressSpace = posix.labelAddressSpace;
    pub const commitPages = posix.commitPages;
    pub const decommitPages = posix.decommitPages;
    pub const protectPages = posix.protectPages;
    pub const releaseAddressSpace = posix.releaseAddressSpace;
    pub const makeDirectoryPath = posix.makeDirectoryPath;
    pub const readFile = posix.readFile;
    pub const writeFileAtomic = posix.writeFileAtomic;
    pub const deleteFile = posix.deleteFile;
    pub const deleteTree = posix.deleteTree;
    pub const fileInfo = posix.fileInfo;
    pub const listDirectory = posix.listDirectory;
    pub const volumeSpace = posix.volumeSpace;
    pub const openStore = State.openStore;
    pub const closeStore = memory_store.closeStore;
    pub const deleteStore = State.deleteStore;
    pub const beginTransaction = memory_store.beginTransaction;
    pub const commitTransaction = memory_store.commitTransaction;
    pub const abortTransaction = memory_store.abortTransaction;
    pub const storeGet = memory_store.storeGet;
    pub const storePut = memory_store.storePut;
    pub const storeDelete = memory_store.storeDelete;
    pub const storeDeleteRange = memory_store.storeDeleteRange;
    pub const openCursor = memory_store.openCursor;
    pub const cursorNext = memory_store.cursorNext;
    pub const closeCursor = memory_store.closeCursor;
    pub const storeSize = memory_store.storeSize;
    pub const createEventLoopPort = curl.createEventLoopPort;
    pub const destroyEventLoopPort = curl.destroyEventLoopPort;
    pub const pollEventLoopPort = curl.pollEventLoopPort;
    pub const waitEventLoopPort = curl.waitEventLoopPort;
    pub const wakeEventLoopPort = curl.wakeEventLoopPort;
    pub const startTransfer = curl.startTransfer;
    pub const cancelTransfer = curl.cancelTransfer;
    pub const pauseTransfer = curl.pauseTransfer;
    pub const resumeTransfer = curl.resumeTransfer;
    pub const openWebSocket = curl.openWebSocket;
    pub const pollWebSocketHandshake = curl.pollWebSocketHandshake;
    pub const receiveWebSocketFrame = curl.receiveWebSocketFrame;
    pub const sendWebSocketFrame = curl.sendWebSocketFrame;
    pub const closeWebSocket = curl.closeWebSocket;
    pub const releaseWebSocket = curl.releaseWebSocket;
    pub const digest = crypto.digest;
    pub const hmacSign = crypto.hmacSign;
    pub const hmacVerify = crypto.hmacVerify;
    pub const hkdf = crypto.hkdf;
    pub const pbkdf2 = crypto.pbkdf2;
    pub const aesEncrypt = crypto.aesEncrypt;
    pub const aesDecrypt = crypto.aesDecrypt;
    pub const ecGenerate = crypto.ecGenerate;
    pub const ecPublicKey = crypto.ecPublicKey;
    pub const ecValidatePublic = crypto.ecValidatePublic;
    pub const ecdsaSign = crypto.ecdsaSign;
    pub const ecdsaVerify = crypto.ecdsaVerify;
    pub const ecdhDerive = crypto.ecdhDerive;
    pub const okpPublicKey = crypto.okpPublicKey;
    pub const ed25519Sign = crypto.ed25519Sign;
    pub const ed25519Verify = crypto.ed25519Verify;
    pub const x25519Derive = crypto.x25519Derive;
    pub const rsaGenerate = crypto.rsaGenerate;
    pub const rsaPublicKey = crypto.rsaPublicKey;
    pub const rsaSign = crypto.rsaSign;
    pub const rsaVerify = crypto.rsaVerify;
    pub const rsaEncrypt = crypto.rsaEncrypt;
    pub const rsaDecrypt = crypto.rsaDecrypt;
    pub const layoutBox = headless.layoutBox;
    pub const clientRects = headless.clientRects;
    pub const scrollPosition = headless.scrollPosition;
    pub const setScrollPosition = headless.setScrollPosition;
    pub const hitTest = headless.hitTest;
    pub const isRendered = headless.isRendered;
    pub const renderedText = headless.renderedText;
    pub const viewport = headless.viewport;
    pub const cssEnvironmentVariable = headless.cssEnvironmentVariable;
    pub const cssEnvironmentRevision = headless.cssEnvironmentRevision;
    pub const invalidateLayout = headless.invalidateLayout;
    pub const forceLayout = headless.forceLayout;
    pub const platformPermissionState = headless.platformPermissionState;
    pub const requestPermission = headless.requestPermission;
    pub const cancelRequest = headless.cancelRequest;
    pub const runSimpleDialog = headless.runSimpleDialog;
    pub const printDocument = headless.printDocument;
    pub const createTopLevelTraversable = headless.createTopLevelTraversable;
    pub const traversableChanged = headless.traversableChanged;
    pub const windowRect = headless.windowRect;
    pub const requestWindowRect = headless.requestWindowRect;
    pub const printConsoleMessage = headless.printConsoleMessage;
    pub const showFilePicker = headless.showFilePicker;
    pub const readPickedFile = headless.readPickedFile;
    pub const releasePickedFile = headless.releasePickedFile;
    pub const screenInfo = headless.screenInfo;
    pub const isOnline = headless.isOnline;
    pub const userPreferences = headless.userPreferences;
    pub const systemVisibility = headless.systemVisibility;
    pub const displayRefreshInterval = headless.displayRefreshInterval;
    pub const screenDetails = headless.screenDetails;
    pub const mediaCanPlayType = media_decoding.mediaCanPlayType;
    pub const openMediaDecoder = openMedia;
    pub const pushMediaData = media_decoding.pushMediaData;
    pub const mediaVideoSize = media_decoding.mediaVideoSize;
    pub const closeMediaDecoder = media_decoding.closeMediaDecoder;
    pub const imageMimeTypeSupported = image_decoding.imageMimeTypeSupported;
    pub const decodeImage = image_decoding.decodeImage;
    pub const imageEncodingMimeTypeSupported = image_encoding.imageEncodingMimeTypeSupported;
    pub const encodeImage = image_encoding.encodeImage;
    pub const decodeFont = fonts.decodeFont;
    pub const genericFontFace = fonts.genericFontFace;
    pub const installedFontFace = fonts.installedFontFace;
    pub const localFontFace = fonts.localFontFace;
    pub const systemFont = fonts.systemFont;
    pub const mediaDecodingInfo = headless.mediaDecodingInfo;
    pub const openCodec = headless.openCodec;
    pub const codecInput = headless.codecInput;
    pub const codecFlush = headless.codecFlush;
    pub const closeCodec = headless.closeCodec;
    pub const requestKeySystemAccess = headless.requestKeySystemAccess;
    pub const createKeySession = headless.createKeySession;
    pub const keySessionGenerateRequest = headless.keySessionGenerateRequest;
    pub const keySessionUpdate = headless.keySessionUpdate;
    pub const closeKeySession = headless.closeKeySession;
    pub const enumerateMediaDevices = headless.enumerateMediaDevices;
    pub const openCaptureSource = headless.openCaptureSource;
    pub const captureSettings = headless.captureSettings;
    pub const captureCapabilities = headless.captureCapabilities;
    pub const applyCaptureConstraints = headless.applyCaptureConstraints;
    pub const setCaptureSink = headless.setCaptureSink;
    pub const closeCaptureSource = headless.closeCaptureSource;
    pub const chooseDisplaySurface = headless.chooseDisplaySurface;
    pub const openAudioOutput = headless.openAudioOutput;
    pub const writeAudio = headless.writeAudio;
    pub const audioOutputLatency = headless.audioOutputLatency;
    pub const closeAudioOutput = headless.closeAudioOutput;
    pub const selectAudioOutput = headless.selectAudioOutput;
    pub const speechVoices = headless.speechVoices;
    pub const speak = headless.speak;
    pub const pauseSpeech = headless.pauseSpeech;
    pub const resumeSpeech = headless.resumeSpeech;
    pub const cancelSpeech = headless.cancelSpeech;
    pub const startRecognition = headless.startRecognition;
    pub const stopRecognition = headless.stopRecognition;
    pub const setMediaSession = headless.setMediaSession;
    pub const enterPictureInPicture = headless.enterPictureInPicture;
    pub const exitPictureInPicture = headless.exitPictureInPicture;
    pub const startPresentation = headless.startPresentation;
    pub const watchRemotePlaybackAvailability = headless.watchRemotePlaybackAvailability;
    pub const readClipboard = clipboardRead;
    pub const writeClipboard = clipboardWrite;
    pub const showNotification = headless.showNotification;
    pub const closeNotification = headless.closeNotification;
    pub const maxNotificationActions = headless.maxNotificationActions;
    pub const pushSubscribe = headless.pushSubscribe;
    pub const pushUnsubscribe = headless.pushUnsubscribe;
    pub const pushSubscription = headless.pushSubscription;
    pub const registerBackgroundSync = headless.registerBackgroundSync;
    pub const startBackgroundFetch = headless.startBackgroundFetch;
    pub const setAppBadge = headless.setAppBadge;
    pub const registerProtocolHandler = headless.registerProtocolHandler;
    pub const currentPosition = headless.currentPosition;
    pub const watchPosition = headless.watchPosition;
    pub const clearWatch = headless.clearWatch;
    pub const startSensor = headless.startSensor;
    pub const stopSensor = headless.stopSensor;
    pub const startDeviceOrientation = headless.startDeviceOrientation;
    pub const stopDeviceOrientation = headless.stopDeviceOrientation;
    pub const batteryStatus = headless.batteryStatus;
    pub const vibrate = headless.vibrate;
    pub const connectionInfo = headless.connectionInfo;
    pub const startPressureObserver = headless.startPressureObserver;
    pub const stopPressureObserver = headless.stopPressureObserver;
    pub const devicePosture = headless.devicePosture;
    pub const startIdleDetection = headless.startIdleDetection;
    pub const stopIdleDetection = headless.stopIdleDetection;
    pub const chooseDevice = headless.chooseDevice;
    pub const grantedDevices = headless.grantedDevices;
    pub const openDevice = headless.openDevice;
    pub const closeDevice = headless.closeDevice;
    pub const deviceRequest = headless.deviceRequest;
    pub const gamepads = headless.gamepads;
    pub const canMakePayment = headless.canMakePayment;
    pub const showPayment = headless.showPayment;
    pub const completePayment = headless.completePayment;
    pub const abortPayment = headless.abortPayment;
    pub const createCredential = headless.createCredential;
    pub const getCredential = headless.getCredential;
    pub const platformAuthenticatorAvailable = headless.platformAuthenticatorAvailable;
    pub const requestIdentityCredential = headless.requestIdentityCredential;
    pub const canShare = headless.canShare;
    pub const share = headless.share;
    pub const contactProperties = headless.contactProperties;
    pub const selectContacts = headless.selectContacts;
    pub const requestFullscreen = headless.requestFullscreen;
    pub const exitFullscreen = headless.exitFullscreen;
    pub const requestPointerLock = headless.requestPointerLock;
    pub const exitPointerLock = headless.exitPointerLock;
    pub const lockKeys = headless.lockKeys;
    pub const unlockKeys = headless.unlockKeys;
    pub const keyboardLayoutMap = headless.keyboardLayoutMap;
    pub const requestWakeLock = headless.requestWakeLock;
    pub const releaseWakeLock = headless.releaseWakeLock;
    pub const openEyeDropper = headless.openEyeDropper;
    pub const queryLocalFonts = headless.queryLocalFonts;
    pub const showVirtualKeyboard = headless.showVirtualKeyboard;
    pub const hideVirtualKeyboard = headless.hideVirtualKeyboard;
};
