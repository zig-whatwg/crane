//! The darwin platform: macOS and iOS (docs/platform-protocol.md section 9).
//!
//! Step 0 of the platform protocol: a composition of kit parts implementing
//! today's behaviour - kit/posix for clocks, randomness, threads, files and
//! identity, kit/memory_store for the storage engine, kit/curl's event-loop
//! port, kit/crypto, and kit/headless for every capability offered to pages.
//! The native capabilities of the contract (SecTrust, the system SQLite,
//! CommonCrypto, NSPasteboard / UIPasteboard, the OS permission system, the
//! system UI) arrive with their recipes steps, each flipping its constant.

const platform = @import("platform");
const platform_options = @import("platform_options");
const posix = @import("kit_posix");
const headless = @import("kit_headless");
const memory_store = @import("kit_memory_store");
const curl = @import("kit_curl");
const crypto = @import("kit_crypto");
const browser_state = @import("kit_browser_state");

/// This platform keeps no per-Browser state beyond kit/browser_state's.
const State = browser_state.BrowserState(struct {});

pub const protocol = struct {
    pub const name = "darwin";

    /// No options of its own: the OS's permission system and native UI need
    /// none (contract 3.2).
    pub const PlatformBrowserOptions = extern struct {};

    pub const identity: platform.Identity = posix.identity;

    /// Today's behaviour, declared. Everything a page asks of a host is
    /// unsupported (kit/headless) until its recipes step builds it.
    pub const capabilities: platform.Capabilities = blk: {
        var c = headless.capabilities;
        // Crane's stores persist under a profile directory today.
        c.persistent_storage = .native;
        // Fetch's scheme fetch "file" reads local files today.
        c.file_urls = .native;
        // The vendored nghttp2 (build.zig -Dhttp2, not with -Dsystem-curl).
        c.http2 = if (platform_options.http2) .native else .unsupported;
        // src/platform/memory.zig reads task_info / /proc/self/statm.
        c.resident_memory = .native;
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
    pub const readClipboard = headless.readClipboard;
    pub const writeClipboard = headless.writeClipboard;
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
