//! Commands a page session holds while its tab navigates (lane fw2).
//!
//! Chrome holds them. From the moment a cross-document navigation of the
//! page's frame starts its request until it finishes (it commits, fails or is
//! dropped), every command the browser process does not answer itself waits
//! in its session, and goes to the page's agent - the document that
//! committed - only after the navigation finished:
//! - render_frame_devtools_agent_host.cc,
//!   RenderFrameDevToolsAgentHost::DidStartNavigation:
//!   `session->SuspendSendingMessagesToAgent(DevToolsSession::SuspendMode::
//!   kAll)` for every session, for a navigation that is not same-document;
//! - RenderFrameDevToolsAgentHost::DidFinishNavigation: once no navigation is
//!   pending (`navigation_requests_.empty()`),
//!   `session->ResumeSendingMessagesToAgent()`;
//! - devtools_session.cc, DevToolsSession::FallThrough: a command no
//!   browser handler answered goes into `pending_messages_`, and is held
//!   unless ShouldSendOnIO lists it (or, in kExecutionOnly,
//!   unless it may run script); ResumeSendingMessagesToAgent sends them, in
//!   order.
//! (chromium/src 65b1b80ff52b, BSD-3-Clause; the algorithm is reproduced,
//! no code is copied.) The navigation starts there after its beforeunload:
//! navigator.cc Navigator::Navigate runs the beforeunload handler first and
//! calls NavigationRequest::BeginNavigation from its answer, and
//! NavigationRequest::StartNavigation calls the delegate's
//! DidStartNavigation - Crane's `request_started` milestone
//! (html.navigation.observer). So a command sent after Page.navigate's
//! answer (which Chrome and Crane give at ready-to-commit:
//! NavigationRequest::ReadyToCommitNavigation ->
//! FrameTreeNode::TransferNavigationRequestOwnership ->
//! PageHandler::NavigationReset) reaches the new document, never the one it
//! replaces.
//!
//! What the browser process answers is Chrome's browser-side handlers
//! (content/browser/devtools/protocol_config.json and
//! chrome/browser/devtools/inspector_protocol_config.json name them; the
//! handlers are content/browser/devtools/protocol/*_handler.cc and
//! chrome/browser/devtools/protocol/*_handler.cc), less each method whose
//! handler returns Response::FallThrough() (or calls the callback's
//! fallThrough()) on its successful path: those reach the agent too.
//! `answered_in_browser` lists the rest, read at that revision.
//! `decoded_in_browser` lists the methods a browser handler takes and then
//! lets through: their params are decoded in the browser, so params that do
//! not parse are answered at once, held or not, as Chrome's crdtp dispatcher
//! answers them (`PageSession.holds` asks the dispatcher to decode them
//! before it holds). So are Emulation.setDeviceMetricsOverride and
//! clearDeviceMetricsOverride that change nothing - the same params again,
//! or no override to clear: EmulationHandler answers those itself, and so
//! does the emulation domain here, at once (emulation.changesNothing).
//! One difference remains, stated: a check a Chrome browser handler makes
//! on params that do decode (Network.setExtraHTTPHeaders' header names,
//! Emulation.setDeviceMetricsOverride's ranges, DOM.setFileInputFiles
//! refused) is answered at once there; here it is the domain handler's, so
//! its error comes after the navigation. Answering it at once needs each
//! such handler split into a check and its effect.
//!
//! kExecutionOnly is the mode of a session attached to an agent host made
//! for a navigation already in flight - one whose host is created at the
//! navigation's ready-to-commit (RenderFrameDevToolsAgentHost::
//! CreateForLocalRootOrEmbeddedPageNavigation sets
//! is_initial_provisional_navigation_; AttachSession picks the mode). Those
//! are out-of-process iframes' and embedded pages' targets. Crane has none
//! yet: every page target exists before its navigations, as a Chrome page's
//! host does once discovery or auto-attach is on, so a session attaching
//! mid-navigation holds in `all`. `Mode.execution_only` is classified here
//! for the iframe targets to come, which are to begin their record in it.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Chrome's DevToolsSession::SuspendMode, while a navigation is pending.
pub const Mode = enum {
    /// kAll: every command the page's agent answers waits.
    all,
    /// kExecutionOnly: only the commands that may run script wait
    /// (MayCauseJavascriptExecution).
    execution_only,
};

/// Whether a session in `mode` holds `method` until the navigation ends.
pub fn holds(mode: Mode, method: []const u8) bool {
    if (answeredInBrowser(method)) return false;
    // ShouldSuspendDuringNavigation: what goes on the IO thread is never
    // held.
    if (sent_on_io.has(method)) return false;
    return switch (mode) {
        .all => true,
        .execution_only => may_run_script.has(method),
    };
}

/// Whether Chrome's browser process answers `method` itself.
pub fn answeredInBrowser(method: []const u8) bool {
    // devtools_session.cc kBrowserOnlyDomainPrefixes: "Target." is the
    // browser's alone (and target_handler.cc answers all of it).
    if (std.mem.startsWith(u8, method, "Target.")) return true;
    return answered_in_browser.has(method);
}

/// devtools_session.cc ShouldSendOnIO: sent to the agent even while held,
/// "so that the renderer can be woken up via the IO thread even if the
/// renderer does not process message loops" - a debugger paused in the page
/// is resumed through these (crbug.com/1354043).
const sent_on_io = setOf(&.{
    "Debugger.getPossibleBreakpoints",
    "Debugger.getScriptSource",
    "Debugger.getStackTrace",
    "Debugger.pause",
    "Debugger.removeBreakpoint",
    "Debugger.resume",
    "Debugger.setBreakpoint",
    "Debugger.setBreakpointByUrl",
    "Debugger.setBreakpointsActive",
    "Emulation.setScriptExecutionDisabled",
    "Page.crash",
    "Performance.getMetrics",
    "Runtime.terminateExecution",
});

/// devtools_session.cc MayCauseJavascriptExecution: what kExecutionOnly
/// holds.
const may_run_script = setOf(&.{
    "Runtime.awaitPromise",
    "Runtime.callFunctionOn",
    "Runtime.evaluate",
    "Runtime.runScript",
    "Runtime.terminateExecution",
    "WebMCP.invokeTool",
});

/// The methods a browser-side handler answers without falling through to
/// the agent (Target.* aside: `answeredInBrowser`).
const answered_in_browser = setOf(&.{
    // Ads
    "Ads.getAdMetrics",

    // Autofill
    "Autofill.disable",
    "Autofill.enable",
    "Autofill.setAddresses",
    "Autofill.trigger",

    // BackgroundService
    "BackgroundService.clearEvents",
    "BackgroundService.setRecording",
    "BackgroundService.startObserving",
    "BackgroundService.stopObserving",

    // BluetoothEmulation
    "BluetoothEmulation.addCharacteristic",
    "BluetoothEmulation.addDescriptor",
    "BluetoothEmulation.addService",
    "BluetoothEmulation.disable",
    "BluetoothEmulation.enable",
    "BluetoothEmulation.removeCharacteristic",
    "BluetoothEmulation.removeDescriptor",
    "BluetoothEmulation.removeService",
    "BluetoothEmulation.setSimulatedCentralState",
    "BluetoothEmulation.simulateAdvertisement",
    "BluetoothEmulation.simulateCharacteristicOperationResponse",
    "BluetoothEmulation.simulateDescriptorOperationResponse",
    "BluetoothEmulation.simulateGATTDisconnection",
    "BluetoothEmulation.simulateGATTOperationResponse",
    "BluetoothEmulation.simulatePreconnectedPeripheral",

    // Browser
    "Browser.addMockCamera",
    "Browser.cancelDownload",
    "Browser.close",
    "Browser.crash",
    "Browser.crashGpuProcess",
    "Browser.executeBrowserCommand",
    "Browser.getBrowserCommandLine",
    "Browser.getGlobalPrivacyControl",
    "Browser.getHistogram",
    "Browser.getHistograms",
    "Browser.getVersion",
    "Browser.getWindowBounds",
    "Browser.getWindowForTarget",
    "Browser.grantPermissions",
    "Browser.resetPermissions",
    "Browser.setContentsSize",
    "Browser.setDockTile",
    "Browser.setDownloadBehavior",
    "Browser.setGlobalPrivacyControl",
    "Browser.setPermission",
    "Browser.setWindowBounds",

    // Cast
    "Cast.disable",
    "Cast.enable",
    "Cast.setSinkToUse",
    "Cast.startDesktopMirroring",
    "Cast.startTabMirroring",
    "Cast.stopCasting",

    // DeviceAccess
    "DeviceAccess.cancelPrompt",
    "DeviceAccess.disable",
    "DeviceAccess.enable",
    "DeviceAccess.selectPrompt",

    // DigitalCredentials
    "DigitalCredentials.setVirtualWalletBehavior",

    // Emulation
    "Emulation.addScreen",
    "Emulation.canEmulate",
    "Emulation.clearDevicePostureOverride",
    "Emulation.clearDisplayFeaturesOverride",
    "Emulation.clearGeolocationOverride",
    "Emulation.clearIdleOverride",
    "Emulation.getOverriddenSensorInformation",
    "Emulation.getScreenInfos",
    "Emulation.removeScreen",
    "Emulation.setDevicePostureOverride",
    "Emulation.setDisplayFeaturesOverride",
    "Emulation.setEmitTouchEventsForMouse",
    "Emulation.setGeolocationOverride",
    "Emulation.setIdleOverride",
    "Emulation.setPressureSourceOverrideEnabled",
    "Emulation.setPressureStateOverride",
    "Emulation.setPrimaryScreen",
    "Emulation.setSensorOverrideEnabled",
    "Emulation.setSensorOverrideReadings",
    "Emulation.setVisibleSize",
    "Emulation.updateScreen",

    // Extensions
    "Extensions.clearStorageItems",
    "Extensions.getExtensions",
    "Extensions.getStorageItems",
    "Extensions.loadUnpacked",
    "Extensions.removeStorageItems",
    "Extensions.setStorageItems",
    "Extensions.triggerAction",
    "Extensions.uninstall",

    // FedCm
    "FedCm.clickDialogButton",
    "FedCm.disable",
    "FedCm.dismissDialog",
    "FedCm.enable",
    "FedCm.openUrl",
    "FedCm.resetCooldown",
    "FedCm.selectAccount",

    // Fetch
    "Fetch.continueRequest",
    "Fetch.continueResponse",
    "Fetch.continueWithAuth",
    "Fetch.disable",
    "Fetch.enable",
    "Fetch.failRequest",
    "Fetch.fulfillRequest",
    "Fetch.getResponseBody",
    "Fetch.takeResponseBodyAsStream",

    // FindInPage
    "FindInPage.findFirst",
    "FindInPage.findNext",
    "FindInPage.findPrev",
    "FindInPage.stop",

    // Input
    "Input.cancelDragging",
    "Input.dispatchDragEvent",
    "Input.dispatchKeyEvent",
    "Input.dispatchMouseEvent",
    "Input.dispatchTouchEvent",
    "Input.emulateTouchFromMouseEvent",
    "Input.imeSetComposition",
    "Input.insertText",
    "Input.setIgnoreInputEvents",
    "Input.setInterceptDrags",
    "Input.synthesizePinchGesture",
    "Input.synthesizeScrollGesture",
    "Input.synthesizeTapGesture",

    // Inspector
    "Inspector.disable",
    "Inspector.enable",

    // IO
    "IO.close",
    "IO.read",

    // Memory
    "Memory.getBrowserSamplingProfile",
    "Memory.getDOMCountersForLeakDetection",
    "Memory.prepareForLeakDetection",
    "Memory.setPressureNotificationsSuppressed",
    "Memory.simulatePressureNotification",

    // Network
    "Network.canEmulateNetworkConditions",
    "Network.clearBrowserCache",
    "Network.clearBrowserCookies",
    "Network.configureDurableMessages",
    "Network.deleteCookies",
    "Network.deleteDeviceBoundSession",
    "Network.emulateNetworkConditionsByRule",
    "Network.enableDeviceBoundSessions",
    "Network.enableReportingApi",
    "Network.fetchSchemefulSite",
    "Network.getAllCookies",
    "Network.getCookies",
    "Network.getSecurityIsolationStatus",
    "Network.loadNetworkResource",
    "Network.setCookie",
    "Network.setCookieControls",
    "Network.setCookies",

    // Page
    "Page.bringToFront",
    "Page.captureScreenshot",
    "Page.captureSnapshot",
    "Page.close",
    "Page.getAnnotatedPageContent",
    "Page.getAppId",
    "Page.getAppManifest",
    "Page.getInstallabilityErrors",
    "Page.getManifestIcons",
    "Page.getNavigationHistory",
    "Page.getSiblingSubApps",
    "Page.getSubApps",
    "Page.handleJavaScriptDialog",
    "Page.navigate",
    "Page.navigateToHistoryEntry",
    "Page.printToPDF",
    "Page.removeScriptToEvaluateOnLoad",
    "Page.resetNavigationHistory",
    "Page.screencastFrameAck",
    "Page.setAdBlockingEnabled",
    "Page.setDownloadBehavior",
    "Page.setPrerenderingAllowed",
    "Page.setRPHRegistrationMode",
    "Page.setSPCTransactionMode",
    "Page.setWebLifecycleState",
    "Page.startScreencast",
    "Page.startScreenRecording",
    "Page.stopLoading",
    "Page.stopScreencast",
    "Page.stopScreenRecording",

    // PWA
    "PWA.changeAppUserSettings",
    "PWA.getOsAppState",
    "PWA.install",
    "PWA.launch",
    "PWA.launchFilesInApp",
    "PWA.openCurrentPageInApp",
    "PWA.uninstall",

    // Schema
    "Schema.getDomains",

    // Security
    "Security.disable",
    "Security.enable",
    "Security.handleCertificateError",
    "Security.setIgnoreCertificateErrors",
    "Security.setOverrideCertificateErrors",

    // ServiceWorker
    "ServiceWorker.deliverPushMessage",
    "ServiceWorker.disable",
    "ServiceWorker.dispatchPeriodicSyncEvent",
    "ServiceWorker.dispatchSyncEvent",
    "ServiceWorker.enable",
    "ServiceWorker.setForceUpdateOnPageLoad",
    "ServiceWorker.skipWaiting",
    "ServiceWorker.startWorker",
    "ServiceWorker.stopAllWorkers",
    "ServiceWorker.stopWorker",
    "ServiceWorker.unregister",
    "ServiceWorker.updateRegistration",

    // SmartCardEmulation
    "SmartCardEmulation.disable",
    "SmartCardEmulation.enable",
    "SmartCardEmulation.reportBeginTransactionResult",
    "SmartCardEmulation.reportConnectResult",
    "SmartCardEmulation.reportDataResult",
    "SmartCardEmulation.reportError",
    "SmartCardEmulation.reportEstablishContextResult",
    "SmartCardEmulation.reportGetStatusChangeResult",
    "SmartCardEmulation.reportListReadersResult",
    "SmartCardEmulation.reportPlainResult",
    "SmartCardEmulation.reportReleaseContextResult",
    "SmartCardEmulation.reportStatusResult",

    // Storage
    "Storage.clearCookies",
    "Storage.clearDataForOrigin",
    "Storage.clearDataForStorageKey",
    "Storage.clearPrivateVerificationTokens",
    "Storage.clearTrustTokens",
    "Storage.deletePrivateVerificationToken",
    "Storage.deleteStorageBucket",
    "Storage.getCookies",
    "Storage.getPrivateVerificationTokens",
    "Storage.getPrivateVerificationTokensIssuerConfigs",
    "Storage.getStorageKey",
    "Storage.getStorageKeyForFrame",
    "Storage.getTrustTokens",
    "Storage.getUsageAndQuota",
    "Storage.overrideQuotaForOrigin",
    "Storage.runBounceTrackingMitigations",
    "Storage.setCookies",
    "Storage.setPrivateVerificationTokensTracking",
    "Storage.setStorageBucketTracking",
    "Storage.trackCacheStorageForOrigin",
    "Storage.trackCacheStorageForStorageKey",
    "Storage.trackIndexedDBForOrigin",
    "Storage.trackIndexedDBForStorageKey",
    "Storage.untrackCacheStorageForOrigin",
    "Storage.untrackCacheStorageForStorageKey",
    "Storage.untrackIndexedDBForOrigin",
    "Storage.untrackIndexedDBForStorageKey",

    // SystemInfo
    "SystemInfo.getFeatureState",
    "SystemInfo.getInfo",
    "SystemInfo.getProcessInfo",

    // Tethering
    "Tethering.bind",
    "Tethering.unbind",

    // Tracing
    "Tracing.end",
    "Tracing.getCategories",
    "Tracing.getTrackEventDescriptor",
    "Tracing.recordClockSyncMarker",
    "Tracing.requestMemoryDump",
    "Tracing.start",

    // WebAuthn
    "WebAuthn.addCredential",
    "WebAuthn.addVirtualAuthenticator",
    "WebAuthn.clearCredentials",
    "WebAuthn.disable",
    "WebAuthn.enable",
    "WebAuthn.getCredential",
    "WebAuthn.getCredentials",
    "WebAuthn.removeCredential",
    "WebAuthn.removeVirtualAuthenticator",
    "WebAuthn.setAutomaticPresenceSimulation",
    "WebAuthn.setCredentialProperties",
    "WebAuthn.setResponseOverrideBits",
    "WebAuthn.setUserVerified",

    // WebMCP
    "WebMCP.invokeTool",
});

/// Whether Chrome's browser process decodes `method`'s params before the
/// command goes on to the page: the browser handles it (a browser handler's
/// generated dispatcher parses the params, crdtp) but falls through on
/// success. Params that do not parse are answered there, at once (-32602),
/// held or not (DevToolsSession::HandleCommand -> UberDispatcher).
pub fn decodedInBrowser(method: []const u8) bool {
    return decoded_in_browser.has(method);
}

/// The methods a browser-side handler takes, then lets through to the page
/// (content/browser/devtools/protocol_config.json and chrome/browser/
/// devtools/inspector_protocol_config.json name them; their handlers return
/// FallThrough on success). Their params are decoded in the browser.
const decoded_in_browser = setOf(&.{
    // Audits
    "Audits.disable",
    "Audits.enable",

    // DOM
    "DOM.getFileInfo",
    "DOM.setFileInputFiles",

    // Debugger
    "Debugger.removeBreakpoint",
    "Debugger.setBreakpointByUrl",

    // DeviceOrientation
    "DeviceOrientation.clearDeviceOrientationOverride",
    "DeviceOrientation.setDeviceOrientationOverride",

    // Emulation
    "Emulation.clearDeviceMetricsOverride",
    "Emulation.setAutomationOverride",
    "Emulation.setDeviceMetricsOverride",
    "Emulation.setEmulatedMedia",
    "Emulation.setFocusEmulationEnabled",
    "Emulation.setUserAgentOverride",

    // Log
    "Log.disable",
    "Log.enable",

    // Network
    "Network.disable",
    "Network.emulateNetworkConditions",
    "Network.enable",
    "Network.getResponseBody",
    "Network.searchInResponseBody",
    "Network.setBypassServiceWorker",
    "Network.setCacheDisabled",
    "Network.setExtraHTTPHeaders",

    // Overlay
    "Overlay.enable",
    "Overlay.setInspectMode",
    "Overlay.setPausedInDebuggerMessage",

    // Page
    "Page.addCompilationCache",
    "Page.addScriptToEvaluateOnLoad",
    "Page.addScriptToEvaluateOnNewDocument",
    "Page.crash",
    "Page.disable",
    "Page.enable",
    "Page.reload",
    "Page.removeScriptToEvaluateOnNewDocument",
    "Page.setBypassCSP",

    // Preload
    "Preload.disable",
    "Preload.enable",

    // WebMCP
    "WebMCP.cancelInvocation",
    "WebMCP.disable",
    "WebMCP.enable",
});

fn setOf(comptime names: []const []const u8) std.StaticStringMap(void) {
    @setEvalBranchQuota(names.len * 2000);
    comptime var pairs: [names.len]struct { []const u8, void } = undefined;
    inline for (names, 0..) |name, i| pairs[i] = .{ name, {} };
    return std.StaticStringMap(void).initComptime(pairs);
}

/// One Browser's cross-document navigations in flight, by navigable: from
/// their request's start (`request_started`) to their commit or their end
/// without one (`committed`, `aborted`), or their navigable's end. Chrome's
/// RenderFrameDevToolsAgentHost::navigation_requests_. On the Browser's
/// thread (BrowserSide.navigations).
pub const InFlight = struct {
    entries: std.ArrayListUnmanaged(Entry) = .empty,

    pub const Entry = struct {
        navigable: u64,
        navigation_id: u64,
        mode: Mode = .all,
    };

    pub fn deinit(self: *InFlight, allocator: Allocator) void {
        self.entries.deinit(allocator);
        self.* = .{};
    }

    /// Navigation `navigation_id` of `navigable` started its request.
    pub fn begin(self: *InFlight, allocator: Allocator, navigable: u64, navigation_id: u64) Allocator.Error!void {
        for (self.entries.items) |entry| if (entry.navigable == navigable and entry.navigation_id == navigation_id) return;
        try self.entries.append(allocator, .{ .navigable = navigable, .navigation_id = navigation_id });
    }

    /// It ended. True when it was in flight and `navigable` has no other
    /// navigation in flight now: its sessions' held commands may go.
    pub fn end(self: *InFlight, navigable: u64, navigation_id: u64) bool {
        for (self.entries.items, 0..) |entry, i| if (entry.navigable == navigable and entry.navigation_id == navigation_id) {
            _ = self.entries.swapRemove(i);
            return self.modeOf(navigable) == null;
        };
        return false;
    }

    /// `navigable` is gone (its tab closed, its frame removed): its
    /// navigations with it.
    pub fn forget(self: *InFlight, navigable: u64) void {
        var i: usize = 0;
        while (i < self.entries.items.len) {
            if (self.entries.items[i].navigable == navigable) {
                _ = self.entries.swapRemove(i);
            } else i += 1;
        }
    }

    /// The mode `navigable`'s sessions hold commands in, null when none of
    /// its navigations is in flight.
    pub fn modeOf(self: *const InFlight, navigable: u64) ?Mode {
        var mode: ?Mode = null;
        for (self.entries.items) |entry| {
            if (entry.navigable != navigable) continue;
            if (entry.mode == .all) return .all;
            mode = entry.mode;
        }
        return mode;
    }

    pub fn count(self: *const InFlight) usize {
        return self.entries.items.len;
    }
};

const testing = std.testing;

test "kAll holds every command the agent answers, and none the browser answers or the IO thread carries" {
    for ([_][]const u8{ "Runtime.evaluate", "Runtime.enable", "DOM.getDocument", "Page.getFrameTree", "Page.enable", "Page.reload", "Network.enable", "Network.getResponseBody", "Emulation.setUserAgentOverride", "Page.addScriptToEvaluateOnNewDocument", "Runtime.runIfWaitingForDebugger", "Debugger.enable", "Debugger.stepOver", "No.suchMethod" }) |method| {
        try testing.expect(holds(.all, method));
    }
    for ([_][]const u8{ "Page.navigate", "Page.stopLoading", "Page.handleJavaScriptDialog", "Page.getNavigationHistory", "Page.close", "Target.getTargets", "Target.sendMessageToTarget", "Fetch.continueRequest", "Input.dispatchMouseEvent", "Network.getCookies", "Browser.getVersion", "Storage.getCookies" }) |method| {
        try testing.expect(!holds(.all, method));
    }
    for ([_][]const u8{ "Debugger.pause", "Debugger.resume", "Debugger.setBreakpointByUrl", "Debugger.removeBreakpoint", "Runtime.terminateExecution", "Emulation.setScriptExecutionDisabled", "Page.crash", "Performance.getMetrics" }) |method| {
        try testing.expect(!holds(.all, method));
    }
}

test "kExecutionOnly holds only what may run script: Runtime.terminateExecution goes on the IO thread, WebMCP.invokeTool is the browser's" {
    for ([_][]const u8{ "Runtime.awaitPromise", "Runtime.callFunctionOn", "Runtime.evaluate", "Runtime.runScript" }) |method| {
        try testing.expect(holds(.execution_only, method));
    }
    // MayCauseJavascriptExecution lists WebMCP.invokeTool, but the browser's
    // WebMCP handler answers it (webmcp_handler.cc): it never falls through
    // to be held.
    for ([_][]const u8{ "WebMCP.invokeTool", "Runtime.terminateExecution", "Runtime.enable", "Runtime.runIfWaitingForDebugger", "DOM.getDocument", "Page.getFrameTree", "Page.enable", "Network.enable", "Debugger.enable", "Debugger.stepOver", "Page.navigate", "Target.getTargets", "No.suchMethod" }) |method| {
        try testing.expect(!holds(.execution_only, method));
    }
}

test "what a browser handler takes and lets through has its params decoded in the browser; what the page alone takes does not" {
    for ([_][]const u8{ "Page.enable", "Page.reload", "Page.addScriptToEvaluateOnNewDocument", "Network.enable", "Network.setExtraHTTPHeaders", "Network.setCacheDisabled", "Emulation.setUserAgentOverride", "Emulation.setDeviceMetricsOverride", "DOM.setFileInputFiles" }) |method| {
        try testing.expect(decodedInBrowser(method));
    }
    // The page's alone, and the browser's alone (answered there, never held).
    for ([_][]const u8{ "Runtime.evaluate", "DOM.getDocument", "Page.getFrameTree", "Page.navigate", "Target.getTargets", "Fetch.continueRequest" }) |method| {
        try testing.expect(!decodedInBrowser(method));
    }
}

test "the record holds a navigable while any of its navigations is in flight, and forgets a navigable that went" {
    var record: InFlight = .{};
    defer record.deinit(testing.allocator);
    try testing.expectEqual(@as(?Mode, null), record.modeOf(7));
    try record.begin(testing.allocator, 7, 1);
    try record.begin(testing.allocator, 7, 1);
    try testing.expectEqual(@as(usize, 1), record.count());
    try record.begin(testing.allocator, 7, 2);
    try record.begin(testing.allocator, 9, 3);
    try testing.expectEqual(@as(?Mode, .all), record.modeOf(7));
    // The first ends; the second is still in flight.
    try testing.expect(!record.end(7, 1));
    try testing.expectEqual(@as(?Mode, .all), record.modeOf(7));
    try testing.expect(record.end(7, 2));
    try testing.expectEqual(@as(?Mode, null), record.modeOf(7));
    // An end it never began changes nothing.
    try testing.expect(!record.end(7, 2));
    // A navigable that went takes its navigations along.
    try record.begin(testing.allocator, 9, 4);
    record.forget(9);
    try testing.expectEqual(@as(usize, 0), record.count());
    try testing.expectEqual(@as(?Mode, null), record.modeOf(9));
}

test "a navigable whose navigations are all kExecutionOnly holds in that mode; one kAll among them makes it kAll" {
    var record: InFlight = .{};
    defer record.deinit(testing.allocator);
    try record.entries.append(testing.allocator, .{ .navigable = 5, .navigation_id = 1, .mode = .execution_only });
    try testing.expectEqual(@as(?Mode, .execution_only), record.modeOf(5));
    try record.begin(testing.allocator, 5, 2);
    try testing.expectEqual(@as(?Mode, .all), record.modeOf(5));
}
