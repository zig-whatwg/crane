//! The testing platform (decision 2, revised; docs/platform-protocol.md
//! section 9): the build machine's real OS services - darwin's or linux's -
//! plus compiled-in test capabilities, with all their state per Browser. The
//! WPT runner and the test tiers build against it.
//!
//! Step 0 of the platform protocol: the OS services are the same kit parts
//! darwin and linux compose; of the test capabilities only the in-memory
//! clipboard (kit/memory_clipboard) is here. The fake capture devices, the WAV
//! and WebM decoders, the scripted permission policy (decision 9), the
//! dialogs, the picker queue and the console sink move in with recipes step 7,
//! with the control surface the WPT runner reaches as `platform.adapter`.

const std = @import("std");
const platform = @import("platform");
const platform_options = @import("platform_options");
const posix = @import("kit_posix");
const headless = @import("kit_headless");
const memory_store = @import("kit_memory_store");
const curl = @import("kit_curl");
const crypto = @import("kit_crypto");
const browser_state = @import("kit_browser_state");
const memory_clipboard = @import("kit_memory_clipboard");

/// Per-Browser test state: fresh for every Browser, so nothing one test does
/// reaches the next (WebKitTestRunner's process-global mocks need a reset).
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
    };

    pub const identity: platform.Identity = posix.identity;

    /// The host OS's services as darwin and linux declare them, and the test
    /// capabilities built so far.
    pub const capabilities: platform.Capabilities = blk: {
        var c = headless.capabilities;
        c.persistent_storage = .native;
        c.file_urls = .native;
        c.http2 = if (platform_options.http2) .native else .unsupported;
        c.resident_memory = .native;
        // kit/memory_clipboard per Browser. Deviation: nothing leaves the
        // Browser and nothing another application copies arrives.
        c.clipboard = .emulated;
        break :blk c;
    };

    pub const createBrowserPlatform = State.create;
    pub const destroyBrowserPlatform = State.destroy;
    pub const initializePlatform = posix.initializePlatform;
    pub const deinitializePlatform = posix.deinitializePlatform;
    pub const defaultDataDirectory = posix.defaultDataDirectory;
    pub const preferredLanguages = posix.preferredLanguages;
    pub const defaultTimeZone = posix.defaultTimeZone;
    pub const logicalProcessorCount = posix.logicalProcessorCount;
    pub const deviceMemoryGiB = posix.deviceMemoryGiB;
    pub const residentMemory = posix.residentMemory;
    pub const monotonicNow = posix.monotonicNow;
    pub const wallNow = posix.wallNow;
    pub const sleepThread = posix.sleepThread;
    pub const fillRandom = posix.fillRandom;
    pub const spawnThread = posix.spawnThread;
    pub const joinThread = posix.joinThread;
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
    pub const screenDetails = headless.screenDetails;
    pub const mediaCanPlayType = headless.mediaCanPlayType;
    pub const openMediaDecoder = headless.openMediaDecoder;
    pub const pushMediaData = headless.pushMediaData;
    pub const mediaVideoSize = headless.mediaVideoSize;
    pub const closeMediaDecoder = headless.closeMediaDecoder;
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
