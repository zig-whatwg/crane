//! The testing platform (decision 2, revised; docs/platform-protocol.md
//! section 9): the build machine's real OS services - darwin's or linux's -
//! plus compiled-in test capabilities, with all their state per Browser. The
//! WPT runner and the test tiers build against it.
//!
//! Step 0 of the platform protocol: the OS services are the same kit parts
//! darwin and linux compose; of the test capabilities the in-memory
//! clipboard (kit/memory_clipboard), the image decoders
//! (kit/image_decoding, decision 19) and encoder (kit/image_encoding: PNG,
//! the integrator 2026-11-12, as darwin and linux) and the media decoders
//! (kit/media_decoding: WAV linear PCM) - all three also darwin's and
//! linux's since the user's rulings D1, D2 and D4 (2026-11-09) - and the
//! fonts (fonts.zig: kit/sfnt and fixed installed faces, decision 20) are
//! here. The fake capture devices, the scripted permission policy (decision
//! 9), the dialogs, the picker queue and the console sink move in with
//! recipes step 7, with the control surface the WPT runner reaches as
//! `platform.adapter`.

const std = @import("std");
const platform = @import("platform");
const platform_options = @import("platform_options");
const posix = @import("kit_posix");
const headless = @import("kit_headless");
const brotli = @import("kit_brotli");
const memory_store = @import("kit_memory_store");
const curl = @import("kit_curl");
const crypto = @import("kit_crypto");
const browser_state = @import("kit_browser_state");
const memory_clipboard = @import("kit_memory_clipboard");
const environment_variables = @import("environment_variables.zig");
const VirtualClock = @import("virtual_clock.zig").VirtualClock;
const SeededRandom = @import("seeded_random.zig").SeededRandom;
const image_decoding = if (for (platform_options.platform_without) |capability| {
    if (std.mem.eql(u8, capability, "image_decoding")) break true;
} else false) headless else @import("kit_image_decoding");
/// kit/image_encoding (PNG), as darwin and linux build it in.
const image_encoding_built_in = for (platform_options.platform_without) |capability| {
    if (std.mem.eql(u8, capability, "image_encoding")) break false;
} else true;
const image_encoding = if (image_encoding_built_in) @import("kit_image_encoding") else headless;
/// kit/media_decoding (WAV linear PCM; D4), as darwin and linux build it in.
const media_decoding_built_in = for (platform_options.platform_without) |capability| {
    if (std.mem.eql(u8, capability, "media_decoding")) break false;
} else true;
const media_decoding = if (media_decoding_built_in) @import("kit_media_decoding") else headless;
const fonts = if (for (platform_options.platform_without) |capability| {
    if (std.mem.eql(u8, capability, "font_decoding")) break true;
} else false) headless else @import("fonts.zig");

/// Per-Browser test state: fresh for every Browser, so nothing one test does
/// reaches the next (WebKitTestRunner's process-global mocks need a reset).
const Extra = struct {
    clipboard: memory_clipboard.Clipboard,
    environment: environment_variables.Values,
    /// The Browser's virtual clock, when it asked for one (virtual_clock.zig).
    clock: VirtualClock,
    /// The Browser's random stream, when it has a seed (seeded_random.zig).
    random: SeededRandom,

    pub fn init(allocator: std.mem.Allocator, options: *const platform.BrowserOptions) error{OutOfMemory}!Extra {
        return .{
            .clipboard = .init(allocator),
            .environment = .init(allocator),
            .clock = .init(&options.platform),
            .random = .init(options.platform.random_seed),
        };
    }

    pub fn deinit(self: *Extra) void {
        self.clipboard.deinit();
        self.environment.deinit();
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
    pub const name = "testing";

    /// The testing platform's own per-Browser options. Step 7 adds the fake
    /// devices, the prompt policy and the console sink.
    pub const PlatformBrowserOptions = extern struct {
        /// Decision 9: an unscripted prompt grants camera and microphone (the
        /// fake devices) and denies everything else.
        grant_capture_prompts: bool = true,
        /// Opt-in deterministic execution (the approved test plan, section
        /// 5): the Browser's clock is virtual (virtual_clock.zig) - it stands
        /// still while the Browser works and moves only when its event loop
        /// is idle and a timer is due, or when a test calls `advanceClock`
        /// (Chromium's MOCK_TIME). Off, the default: real time, as every WPT
        /// run keeps (all three browsers run WPT in real time).
        virtual_clock: bool = false,
        /// The virtual clock's wall time when it starts, ms since the Unix
        /// epoch: 2026-01-01T00:00:00Z by default, so Date.now() replays too.
        virtual_clock_wall_start_ms: i64 = 1_767_225_600_000,
        /// The seed of the Browser's random stream (fillBrowserRandom), which
        /// seeds its agent's Math.random, so a run replays from it. 0, the
        /// default: no stream - the engine's and the OS's entropy, as V8's
        /// --random-seed=0.
        random_seed: u64 = 0,
    };

    pub const identity: platform.Identity = posix.identity;

    /// The host OS's services as darwin and linux declare them, and the test
    /// capabilities built so far.
    pub const capabilities: platform.Capabilities = blk: {
        var c = headless.capabilities;
        c.brotli = .native; // Pinned RFC 7932 codec; identical on every OS.
        c.persistent_storage = .native;
        c.file_urls = .native;
        c.http2 = if (platform_options.http2) .native else .unsupported;
        c.resident_memory = .native;
        // Reserved address space for each Browser's heap (6.11): kit/posix.
        c.address_space = .native;
        // kit/memory_clipboard per Browser. Deviation: nothing leaves the
        // Browser and nothing another application copies arrives.
        c.clipboard = .emulated;
        // kit/image_decoding, compiled in: PNG, BMP, GIF, JPEG and SVG.
        c.image_decoding = .native;
        // kit/image_encoding, compiled in: PNG.
        if (image_encoding_built_in) c.image_encoding = .native;
        // kit/media_decoding, compiled in: WAV linear PCM (D4).
        if (media_decoding_built_in) c.media_decoding = .native;
        // kit/sfnt (decision 20): web fonts in Zig, and fixed default,
        // installed and system faces, so no answer depends on the machine.
        c.font_decoding = .native;
        // layout: headless's, unsupported - no renderer plugs in here, and
        // Crane never computes a box itself (D3, the user 2026-11-09 22:21
        // UTC: geometry is a read on the compiled-in platform's renderer).
        break :blk c;
    };

    pub const createBrotliDecoder = brotli.createBrotliDecoder;
    pub const decompressBrotli = brotli.decompressBrotli;
    pub const destroyBrotliDecoder = brotli.destroyBrotliDecoder;
    pub const createBrotliEncoder = brotli.createBrotliEncoder;
    pub const compressBrotli = brotli.compressBrotli;
    pub const destroyBrotliEncoder = brotli.destroyBrotliEncoder;
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
    pub const sleepThread = posix.sleepThread;
    pub const fillRandom = posix.fillRandom;

    /// The Browser's virtual clock when it asked for one, else the OS's.
    pub fn browserClock(browser: *platform.BrowserPlatform) platform.BrowserClock {
        return State.of(browser).extra.clock.browserClock();
    }

    /// Test control: move a virtual-clock Browser's clock `nanoseconds` on
    /// (Chromium's FastForwardBy, without running what came due: the test
    /// turns the Browser's event loop next). Nothing for a real-clock one.
    pub fn advanceClock(browser: *platform.BrowserPlatform, nanoseconds: u64) void {
        State.of(browser).extra.clock.advance(nanoseconds);
    }

    /// The seeded Browser's stream, else none.
    pub fn fillBrowserRandom(browser: *platform.BrowserPlatform, bytes: []u8) bool {
        return State.of(browser).extra.random.fill(bytes);
    }
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

    pub fn cssEnvironmentVariable(browser: *platform.BrowserPlatform, tab: platform.TabId, variable: platform.CssEnvironmentVariable, x: u32, y: u32) ?f64 {
        return State.of(browser).extra.environment.get(browser, tab, variable, x, y);
    }

    pub fn cssEnvironmentRevision(browser: *platform.BrowserPlatform, tab: platform.TabId) u64 {
        _ = tab;
        return State.of(browser).extra.environment.revision.load(.acquire);
    }

    /// Test control: change this Browser's value (null makes it undefined).
    /// The reserved tab argument is ignored until recipes step 7.
    pub fn setCssEnvironmentVariable(browser: *platform.BrowserPlatform, tab: platform.TabId, variable: platform.CssEnvironmentVariable, x: u32, y: u32, value: ?f64) error{OutOfMemory}!void {
        return State.of(browser).extra.environment.set(browser, tab, variable, x, y, value);
    }

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
