//! W3C Geolocation API implementation (specs/w3c/geolocation.md, CR 26 March 2026):
//! - §6.1 Internal slots ([[cachedPosition]], [[watchIDs]])
//! - §6.2 getCurrentPosition()
//! - §6.3 watchPosition()
//! - §6.4 clearWatch()
//! - §6.5 Request a position (Permissions Policy, secure context, visibility, permission, watch loop)
//! - §6.6 Acquire a position (emulation, cachedPosition, timeout, platform acquisition)
//! - §6.7 Call back with error
//! - §12 Emulation (set emulated position data, get emulated position data, significant-change notification)
//!
//! Per-Browser state lives in `Registry` (a BrowserScope supplement on the window thread).
//! All async tasks and timers reference requests by monotonic `request_id` rather than
//! raw pointers, preventing UAF across clearWatch, document unload, or Browser teardown.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const dom = @import("dom");
const platform = @import("platform");
const html_core = @import("html_core");
const platform_state = @import("platform_state.zig");
const user_activation = @import("user_activation.zig");
const report_exception = @import("report_exception.zig");

const Instance = runtime.Instance;
const BrowsingContext = html_core.window.BrowsingContext;
pub const Coordinates = html_core.window.host_overrides.GeolocationCoordinates;
pub const GeolocationOverride = html_core.window.host_overrides.GeolocationOverride;
pub const Owner = html_core.window.host_overrides.Owner;

/// Permission state for the "geolocation" powerful feature.
pub const PermissionState = enum { granted, denied, prompt };

/// Callback installed per-Registry by the Geolocation impl (which has access to
/// the `permissions` module) to read the Browser's permission override store.
pub const PermissionReader = *const fn (scope: *runtime.BrowserScope, key: []const u8) ?PermissionState;

/// Traced child slot for Geolocation's [[cachedPosition]] internal slot (§6.1).
const cached_position_slot: engine.TracedSlot = .{ .name = "Geolocation:cachedPosition" };

pub const ErrorCode = struct {
    pub const permission_denied: u16 = 1;
    pub const position_unavailable: u16 = 2;
    pub const timeout: u16 = 3;
};

pub const Options = struct {
    enable_high_accuracy: bool = false,
    timeout_ms: u32 = std.math.maxInt(u32),
    maximum_age_ms: u32 = 0,

    pub fn fromWebIDL(opt: webidl.Opt(dictionaries.PositionOptions)) Options {
        if (!opt.was_passed) return .{};
        return .{
            .enable_high_accuracy = opt.value.enableHighAccuracy orelse false,
            .timeout_ms = opt.value.timeout orelse std.math.maxInt(u32),
            .maximum_age_ms = opt.value.maximumAge orelse 0,
        };
    }
};

const GeolocationSlot = struct {
    geolocation: *Instance,
    generation: u64,
    realm: runtime.Context,
    /// §6.1 [[cachedPosition]], traced from `geolocation` via `cached_position_slot`.
    cached_position: ?*Instance = null,
    cached_position_generation: u64 = 0,
    cached_timestamp: u64 = 0,
    cached_is_high_accuracy: bool = false,

    fn isLive(self: *const GeolocationSlot) bool {
        return runtime.SlabAllocator.generationOf(self.geolocation) == self.generation;
    }

    fn clearCache(self: *GeolocationSlot) void {
        if (self.cached_position != null) {
            if (self.isLive() and self.realm.hasEngine()) {
                engine.forgetTracedChild(self.geolocation, cached_position_slot);
            }
            self.cached_position = null;
            self.cached_position_generation = 0;
            self.cached_timestamp = 0;
            self.cached_is_high_accuracy = false;
        }
    }

    fn setCache(self: *GeolocationSlot, pos: *Instance, timestamp: u64, is_high_accuracy: bool) void {
        if (!self.isLive() or !self.realm.hasEngine()) return;
        if (self.cached_position != null) {
            engine.forgetTracedChild(self.geolocation, cached_position_slot);
        }
        self.cached_position = pos;
        self.cached_position_generation = runtime.SlabAllocator.generationOf(pos);
        self.cached_timestamp = timestamp;
        self.cached_is_high_accuracy = is_high_accuracy;
        engine.traceChild(self.geolocation, pos, cached_position_slot);
    }

    fn liveCachedPosition(self: *const GeolocationSlot) ?*Instance {
        const pos = self.cached_position orelse return null;
        if (runtime.SlabAllocator.generationOf(pos) != self.cached_position_generation) return null;
        return pos;
    }
};

const Phase = enum {
    /// Waiting for initial async parallel task to run.
    pending_start,
    /// §6.5 step 5: document's visibility state is "hidden"; waiting for "visible".
    waiting_visible,
    /// §6.6: acquiring a position (platform request and/or timeout armed).
    acquiring,
    /// §6.5 step 7.5: watchPosition active, waiting for next significant change.
    watching,
};

const PositionRequest = struct {
    id: u64,
    geolocation: *Instance,
    geolocation_generation: u64,
    realm: runtime.Context,
    window: *Instance,
    window_generation: u64,
    document: *Instance,
    document_generation: u64,
    /// null for getCurrentPosition, positive watchId for watchPosition (§6.3).
    watch_id: ?i32,
    options: Options,
    success_cb: engine.CallbackFunction,
    error_cb: ?engine.CallbackFunction,
    phase: Phase = .pending_start,
    /// Armed acquisition timeout timer (0 when none armed).
    timeout_timer_id: runtime.TimerId = 0,
    timeout_ctx: ?*TimeoutCtx = null,
    /// Acquisition generation counter to ignore stale timers/platform replies.
    acq_seq: u64 = 0,
    /// Platform currentPosition request id if in flight (0 if none).
    platform_request_id: platform.RequestId = 0,
    /// Platform watchPosition id if registered with platform.
    platform_watch_id: ?platform.WatchId = null,
    /// Prevents duplicate TIMEOUT errors for the same watch acquisition
    /// (WPT watchposition-timeout.https.window.js).
    timeout_reported: bool = false,

    fn cancelTimer(self: *PositionRequest) void {
        if (self.timeout_timer_id == 0) return;
        const id = self.timeout_timer_id;
        const ctx = self.timeout_ctx;
        self.timeout_timer_id = 0;
        self.timeout_ctx = null;
        if (self.realm.getTimer()) |timer| {
            // NativeTimerManager.clearTimeout does not invoke `drop`; when it
            // returns true, the caller owns and frees user_data.
            if (timer.clearTimeout(id)) {
                if (ctx) |c| c.allocator.destroy(c);
            }
        } else |_| {}
    }

    fn cancelPlatformOps(self: *PositionRequest) void {
        if (self.platform_request_id != 0) {
            const req_id = self.platform_request_id;
            self.platform_request_id = 0;
            if (platform_state.of(self.realm)) |browser| {
                platform.cancelRequest(browser, req_id);
            }
        }
        if (self.platform_watch_id) |wid| {
            self.platform_watch_id = null;
            if (comptime platform.capabilities.geolocation != .unsupported) {
                if (platform_state.of(self.realm)) |browser| {
                    platform.clearWatch(browser, wid);
                }
            }
        }
    }

    fn deinit(self: *PositionRequest, allocator: std.mem.Allocator) void {
        self.cancelTimer();
        self.cancelPlatformOps();
        self.success_cb.release();
        if (self.error_cb) |cb| cb.release();
        allocator.destroy(self);
    }

    fn isGeolocationLive(self: *const PositionRequest) bool {
        return runtime.SlabAllocator.generationOf(self.geolocation) == self.geolocation_generation;
    }

    fn isDocumentLive(self: *const PositionRequest) bool {
        return runtime.SlabAllocator.generationOf(self.document) == self.document_generation;
    }

    fn isWindowLive(self: *const PositionRequest) bool {
        return runtime.SlabAllocator.generationOf(self.window) == self.window_generation;
    }
};

/// Per-Browser geolocation registry (BrowserScope supplement; window thread).
pub const Registry = struct {
    allocator: std.mem.Allocator,
    permission_reader: ?PermissionReader = null,
    next_request_id: u64 = 1,
    next_watch_id: i32 = 1,
    slots: std.ArrayListUnmanaged(*GeolocationSlot) = .empty,
    requests: std.ArrayListUnmanaged(*PositionRequest) = .empty,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Registry) void {
        for (self.requests.items) |req| req.deinit(self.allocator);
        self.requests.deinit(self.allocator);
        for (self.slots.items) |slot| {
            slot.clearCache();
            self.allocator.destroy(slot);
        }
        self.slots.deinit(self.allocator);
    }

    fn nextWatchId(self: *Registry) i32 {
        const id = self.next_watch_id;
        self.next_watch_id = if (self.next_watch_id == std.math.maxInt(i32)) 1 else self.next_watch_id + 1;
        return id;
    }

    fn nextRequestId(self: *Registry) u64 {
        const id = self.next_request_id;
        self.next_request_id += 1;
        return id;
    }

    fn ensureSlot(self: *Registry, geolocation: *Instance) !*GeolocationSlot {
        const gen = runtime.SlabAllocator.generationOf(geolocation);
        for (self.slots.items) |slot| {
            if (slot.geolocation == geolocation and slot.generation == gen) return slot;
        }
        self.pruneDeadSlots();
        const slot = try self.allocator.create(GeolocationSlot);
        errdefer self.allocator.destroy(slot);
        slot.* = .{
            .geolocation = geolocation,
            .generation = gen,
            .realm = geolocation.ctx,
        };
        try self.slots.append(self.allocator, slot);
        return slot;
    }

    fn findSlot(self: *Registry, geolocation: *Instance, generation: u64) ?*GeolocationSlot {
        for (self.slots.items) |slot| {
            if (slot.geolocation == geolocation and slot.generation == generation) return slot;
        }
        return null;
    }

    fn pruneDeadSlots(self: *Registry) void {
        var i: usize = 0;
        while (i < self.slots.items.len) {
            if (self.slots.items[i].isLive()) {
                i += 1;
            } else {
                const slot = self.slots.swapRemove(i);
                slot.clearCache();
                self.allocator.destroy(slot);
            }
        }
    }

    fn findRequest(self: *Registry, request_id: u64) ?*PositionRequest {
        for (self.requests.items) |req| {
            if (req.id == request_id) return req;
        }
        return null;
    }

    fn removeRequest(self: *Registry, request_id: u64) void {
        for (self.requests.items, 0..) |req, i| {
            if (req.id == request_id) {
                const removed = self.requests.swapRemove(i);
                removed.deinit(self.allocator);
                return;
            }
        }
    }
};

// ============================================================================
// Public WebIDL Entry Points (§6.2, §6.3, §6.4)
// ============================================================================

/// §6.2 getCurrentPosition(successCallback, errorCallback, options)
pub fn getCurrentPosition(
    geolocation: *Instance,
    success_callback: callbacks.PositionCallback,
    error_callback: webidl.Opt(?callbacks.PositionErrorCallback),
    options_opt: webidl.Opt(dictionaries.PositionOptions),
    permission_reader: PermissionReader,
) !void {
    const realm = geolocation.ctx;
    const err_cb_borrowed: ?callbacks.PositionErrorCallback = if (error_callback.was_passed) error_callback.value else null;

    // Step 1: If this's relevant global object's associated Document is not
    // fully active:
    //   1.1 Call back with error errorCallback and POSITION_UNAVAILABLE.
    //   1.2 Terminate this algorithm.
    const doc_info = associatedDocument(realm);
    if (doc_info == null or !isFullyActive(doc_info.?.document)) {
        if (err_cb_borrowed) |ecb| {
            queueErrorCallback(realm, ecb.keep(), ErrorCode.position_unavailable, "Document is not fully active", true);
        }
        return;
    }

    // Step 2: Request a position passing this, successCallback, errorCallback, options.
    try requestPosition(
        geolocation,
        doc_info.?.window,
        doc_info.?.document,
        success_callback,
        err_cb_borrowed,
        Options.fromWebIDL(options_opt),
        null,
        permission_reader,
    );
}

/// §6.3 watchPosition(successCallback, errorCallback, options)
pub fn watchPosition(
    geolocation: *Instance,
    success_callback: callbacks.PositionCallback,
    error_callback: webidl.Opt(?callbacks.PositionErrorCallback),
    options_opt: webidl.Opt(dictionaries.PositionOptions),
    permission_reader: PermissionReader,
) !i32 {
    const realm = geolocation.ctx;
    const err_cb_borrowed: ?callbacks.PositionErrorCallback = if (error_callback.was_passed) error_callback.value else null;

    // Step 1: If this's relevant global object's associated Document is not
    // fully active:
    //   1.1 Call back with error passing errorCallback and POSITION_UNAVAILABLE.
    //   1.2 Return 0.
    const doc_info = associatedDocument(realm);
    if (doc_info == null or !isFullyActive(doc_info.?.document)) {
        if (err_cb_borrowed) |ecb| {
            queueErrorCallback(realm, ecb.keep(), ErrorCode.position_unavailable, "Document is not fully active", true);
        }
        return 0;
    }

    // Step 2: Let watchId be an implementation-defined unsigned long > 0.
    const scope = runtime.BrowserScope.ofInstance(geolocation);
    const registry = try scope.of(Registry);
    registry.permission_reader = permission_reader;
    const watch_id = registry.nextWatchId();

    // Steps 3-4: Append watchId to [[watchIDs]] and request a position.
    try requestPosition(
        geolocation,
        doc_info.?.window,
        doc_info.?.document,
        success_callback,
        err_cb_borrowed,
        Options.fromWebIDL(options_opt),
        watch_id,
        permission_reader,
    );

    // Step 5: Return watchId.
    return watch_id;
}

/// §6.4 clearWatch(watchId)
pub fn clearWatch(geolocation: *Instance, watch_id: i32) void {
    if (watch_id <= 0) return;
    const scope = runtime.BrowserScope.ofInstance(geolocation);
    const registry = scope.existing(Registry) orelse return;
    const gen = runtime.SlabAllocator.generationOf(geolocation);

    // Step 1: Remove watchId from this's [[watchIDs]] (and cancel its timers/ops).
    var i: usize = 0;
    while (i < registry.requests.items.len) {
        const req = registry.requests.items[i];
        if (req.geolocation == geolocation and req.geolocation_generation == gen and req.watch_id == watch_id) {
            const removed = registry.requests.swapRemove(i);
            removed.deinit(registry.allocator);
            return;
        }
        i += 1;
    }
}

// ============================================================================
// §6.5 Request a position
// ============================================================================

fn requestPosition(
    geolocation: *Instance,
    window: *Instance,
    document: *Instance,
    success_callback: callbacks.PositionCallback,
    error_callback: ?callbacks.PositionErrorCallback,
    options: Options,
    watch_id: ?i32,
    permission_reader: PermissionReader,
) !void {
    const realm = geolocation.ctx;
    const scope = runtime.BrowserScope.ofInstance(geolocation);
    const registry = try scope.of(Registry);
    registry.permission_reader = permission_reader;
    _ = try registry.ensureSlot(geolocation);

    // Step 3: If document is not allowed to use the "geolocation" feature:
    //   3.1 If watchId was passed, remove watchId from watchIDs (never added yet).
    //   3.2 Call back with error passing errorCallback and PERMISSION_DENIED.
    //   3.3 Terminate this algorithm.
    const allowed_by_policy = dom.policy_containers.allowedToUse(document, .geolocation) catch false;
    if (!allowed_by_policy) {
        if (error_callback) |ecb| {
            queueErrorCallback(
                realm,
                ecb.keep(),
                ErrorCode.permission_denied,
                "Geolocation has been disabled in this document by permissions policy.",
                false,
            );
        }
        return;
    }

    // Step 4: If geolocation's environment settings object is a non-secure context:
    //   4.1 If watchId was passed, remove watchId from watchIDs.
    //   4.2 Call back with error passing errorCallback and PERMISSION_DENIED.
    //   4.3 Terminate this algorithm.
    if (!isSecureContext(window)) {
        if (error_callback) |ecb| {
            queueErrorCallback(
                realm,
                ecb.keep(),
                ErrorCode.permission_denied,
                "Only secure origins are allowed (see: https://goo.gl/Y0ZkNV).",
                false,
            );
        }
        return;
    }

    // Keep callbacks across async steps.
    var success_kept: ?engine.CallbackFunction = success_callback.keep();
    errdefer if (success_kept) |cb| cb.release();
    var error_kept: ?engine.CallbackFunction = if (error_callback) |ecb| ecb.keep() else null;
    errdefer if (error_kept) |cb| cb.release();

    const req = try registry.allocator.create(PositionRequest);
    errdefer registry.allocator.destroy(req);

    const hidden = interfaces.Document.get_hidden(document) catch false;
    req.* = .{
        .id = registry.nextRequestId(),
        .geolocation = geolocation,
        .geolocation_generation = runtime.SlabAllocator.generationOf(geolocation),
        .realm = realm,
        .window = window,
        .window_generation = runtime.SlabAllocator.generationOf(window),
        .document = document,
        .document_generation = runtime.SlabAllocator.generationOf(document),
        .watch_id = watch_id,
        .options = options,
        .success_cb = success_kept.?,
        .error_cb = error_kept,
        .phase = if (hidden) .waiting_visible else .pending_start,
    };
    success_kept = null;
    error_kept = null;

    try registry.requests.append(registry.allocator, req);

    // Step 5: If document's visibility state is "hidden", wait for page
    // visibility change steps to make document visible (`visibilityChanged`).
    if (hidden) return;

    // Steps 6-7: Run in parallel (queued task so callbacks are always async
    // and clearWatch called synchronously after watchPosition cancels cleanly).
    queueStartRequest(registry.allocator, scope, req);
}

fn queueStartRequest(allocator: std.mem.Allocator, scope: *runtime.BrowserScope, req: *PositionRequest) void {
    const loop = req.realm.getOptionalEventLoop() orelse {
        runParallelSteps(scope, req.id);
        return;
    };
    const task = allocator.create(StartTask) catch {
        return;
    };
    task.* = .{
        .allocator = allocator,
        .scope = scope,
        .request_id = req.id,
    };
    loop.queueTask(.{
        .callback = StartTask.run,
        .context = task,
        .drop = StartTask.drop,
        .document = @ptrCast(req.document),
        .document_generation = req.document_generation,
    });
}

const StartTask = struct {
    allocator: std.mem.Allocator,
    scope: *runtime.BrowserScope,
    request_id: u64,

    fn run(data: ?*anyopaque) void {
        const self: *StartTask = @ptrCast(@alignCast(data orelse return));
        const scope = self.scope;
        const request_id = self.request_id;
        self.allocator.destroy(self);
        runParallelSteps(scope, request_id);
    }

    fn drop(data: ?*anyopaque) void {
        const self: *StartTask = @ptrCast(@alignCast(data orelse return));
        self.allocator.destroy(self);
    }
};

/// §6.5 step 7: In parallel — request permission, then acquire a position.
fn runParallelSteps(scope: *runtime.BrowserScope, request_id: u64) void {
    const registry = scope.existing(Registry) orelse return;
    const req = registry.findRequest(request_id) orelse return;
    if (!req.isGeolocationLive() or !req.isDocumentLive() or !req.isWindowLive() or !req.realm.hasEngine()) {
        registry.removeRequest(request_id);
        return;
    }

    // Re-check visibility if document became hidden before parallel steps began.
    if (interfaces.Document.get_hidden(req.document) catch false) {
        req.phase = .waiting_visible;
        return;
    }

    // Step 7.1-7.2: Request permission to use { name: "geolocation" }.
    const perm = requestPermission(registry, scope, req.realm, req.window);
    if (perm == .denied) {
        deliverErrorAndFinish(registry, req, ErrorCode.permission_denied, "User denied Geolocation", true);
        return;
    }

    // Step 7.3: Acquire a position.
    acquirePosition(registry, scope, req);
}

// ============================================================================
// §6.6 Acquire a position
// ============================================================================

fn acquirePosition(registry: *Registry, scope: *runtime.BrowserScope, req: *PositionRequest) void {
    if (!req.isGeolocationLive() or !req.isDocumentLive() or !req.isWindowLive() or !req.realm.hasEngine()) {
        registry.removeRequest(req.id);
        return;
    }

    req.cancelTimer();
    req.phase = .acquiring;
    req.acq_seq += 1;
    req.timeout_reported = false;

    // Step 2: Let acquisitionTime be a new EpochTimeStamp that represents now.
    const acquisition_time = currentEpochMs(req.realm);

    // Step 5.1-5.2: Let permission be get the current permission state of "geolocation".
    const perm = currentPermissionState(registry, scope, req.realm, req.window);
    if (perm == .denied) {
        deliverErrorAndFinish(registry, req, ErrorCode.permission_denied, "User denied Geolocation", true);
        return;
    }
    if (perm != .granted) {
        // Prompt state without grant in headless mode cannot acquire.
        deliverErrorAndFinish(registry, req, ErrorCode.permission_denied, "User denied Geolocation", true);
        return;
    }

    // Step 5.3.1: Check if an emulated position should be used (§12).
    if (getEmulatedPositionData(req.window)) |emulated| {
        switch (emulated) {
            .position_unavailable => {
                deliverErrorForAcquisition(registry, req, ErrorCode.position_unavailable, "Position unavailable");
                return;
            },
            .coordinates => |coords| {
                deliverSuccessForAcquisition(registry, req, coords, null, 0, acquisition_time, false);
                return;
            },
        }
    }

    // Step 5.3.3: Check [[cachedPosition]] when maximumAge > 0.
    if (req.options.maximum_age_ms > 0) {
        if (registry.findSlot(req.geolocation, req.geolocation_generation)) |slot| {
            if (slot.liveCachedPosition()) |cached_pos| {
                const age_ms: i128 = @as(i128, acquisition_time) - @as(i128, slot.cached_timestamp);
                if (age_ms < @as(i128, req.options.maximum_age_ms) and
                    slot.cached_is_high_accuracy == req.options.enable_high_accuracy)
                {
                    deliverSuccessForAcquisition(
                        registry,
                        req,
                        undefined,
                        cached_pos,
                        slot.cached_position_generation,
                        slot.cached_timestamp,
                        false,
                    );
                    if (req.watch_id != null) ensurePlatformWatch(registry, req);
                    return;
                }
            }
        }
    }

    // Step 5.3.5 / §7.2 Note: timeout == 0 expires immediately if no emulated
    // position or fresh cache satisfied the request (WPT PositionOptions.https.html).
    if (req.options.timeout_ms == 0) {
        req.timeout_reported = true;
        deliverErrorForAcquisition(registry, req, ErrorCode.timeout, "Timeout expired");
        return;
    }

    // Step 5.3.4: Acquire from underlying platform if supported.
    if (comptime platform.capabilities.geolocation != .unsupported) {
        if (platform_state.of(req.realm)) |browser| {
            var requester_parts = (platform_state.requester(req.realm, false) catch null) orelse {
                deliverErrorForAcquisition(registry, req, ErrorCode.position_unavailable, "Position unavailable");
                return;
            };
            defer requester_parts.deinit();

            const plat_opts: platform.PositionOptions = .{
                .enable_high_accuracy = req.options.enable_high_accuracy,
                .timeout_ms = req.options.timeout_ms,
                .maximum_age_ms = req.options.maximum_age_ms,
            };

            // Arm timeout timer when timeout < 0xFFFFFFFF.
            if (req.options.timeout_ms != std.math.maxInt(u32)) {
                armTimeoutTimer(registry.allocator, scope, req, req.options.timeout_ms);
            }

            // If this is a watchPosition, also subscribe to platform watch events.
            if (req.watch_id != null) {
                ensurePlatformWatchWith(req, browser, &requester_parts, &plat_opts);
            }

            // Request current position asynchronously via platform Reply.
            const sink = if (req.realm.task_sink) |s| s.retain() else null;
            const reply_ctx = registry.allocator.create(PlatformReplyCtx) catch {
                if (sink) |s| s.release();
                deliverErrorForAcquisition(registry, req, ErrorCode.position_unavailable, "Position unavailable");
                return;
            };
            reply_ctx.* = .{
                .allocator = registry.allocator,
                .scope = scope,
                .sink = sink,
                .request_id = req.id,
                .acq_seq = req.acq_seq,
                .request_thread = std.Thread.getCurrentId(),
            };
            req.platform_request_id = requester_parts.request_id;
            const plat_req = requester_parts.requester();
            platform.currentPosition(browser, &plat_req, &plat_opts, .{
                .context = reply_ctx,
                .deliver = PlatformReplyCtx.deliver,
                .drop = PlatformReplyCtx.drop,
            });
            return;
        }
    }

    // Platform geolocation capability is .unsupported (default headless browser):
    // position unavailable.
    deliverErrorForAcquisition(registry, req, ErrorCode.position_unavailable, "Position unavailable");
}

fn ensurePlatformWatch(registry: *Registry, req: *PositionRequest) void {
    _ = registry;
    if (comptime platform.capabilities.geolocation == .unsupported) return;
    if (req.platform_watch_id != null) return;
    const browser = platform_state.of(req.realm) orelse return;
    var requester_parts = (platform_state.requester(req.realm, false) catch null) orelse return;
    defer requester_parts.deinit();
    const plat_opts: platform.PositionOptions = .{
        .enable_high_accuracy = req.options.enable_high_accuracy,
        .timeout_ms = req.options.timeout_ms,
        .maximum_age_ms = req.options.maximum_age_ms,
    };
    ensurePlatformWatchWith(req, browser, &requester_parts, &plat_opts);
}

fn ensurePlatformWatchWith(
    req: *PositionRequest,
    browser: *platform.BrowserPlatform,
    requester_parts: *const platform_state.RequesterParts,
    plat_opts: *const platform.PositionOptions,
) void {
    if (comptime platform.capabilities.geolocation == .unsupported) return;
    if (req.platform_watch_id != null) return;
    const plat_req = requester_parts.requester();
    req.platform_watch_id = platform.watchPosition(browser, &plat_req, plat_opts) catch null;
}

// ============================================================================
// Timeout Timer
// ============================================================================

const TimeoutCtx = struct {
    allocator: std.mem.Allocator,
    scope: *runtime.BrowserScope,
    request_id: u64,
    acq_seq: u64,

    fn fire(data: ?*anyopaque) void {
        const self: *TimeoutCtx = @ptrCast(@alignCast(data orelse return));
        const scope = self.scope;
        const request_id = self.request_id;
        const acq_seq = self.acq_seq;
        self.allocator.destroy(self);

        const registry = scope.existing(Registry) orelse return;
        const req = registry.findRequest(request_id) orelse return;
        if (req.acq_seq != acq_seq or req.phase != .acquiring) return;
        req.timeout_timer_id = 0;
        req.timeout_ctx = null;
        // Cancel in-flight platform single-shot request if any.
        if (req.platform_request_id != 0) {
            const plat_id = req.platform_request_id;
            req.platform_request_id = 0;
            if (platform_state.of(req.realm)) |browser| platform.cancelRequest(browser, plat_id);
        }
        if (req.timeout_reported) return;
        req.timeout_reported = true;
        deliverErrorForAcquisition(registry, req, ErrorCode.timeout, "Timeout expired");
    }

    fn drop(data: ?*anyopaque) void {
        const self: *TimeoutCtx = @ptrCast(@alignCast(data orelse return));
        self.allocator.destroy(self);
    }
};

fn armTimeoutTimer(allocator: std.mem.Allocator, scope: *runtime.BrowserScope, req: *PositionRequest, timeout_ms: u32) void {
    const timer = req.realm.getTimer() catch return;
    const ctx = allocator.create(TimeoutCtx) catch return;
    ctx.* = .{
        .allocator = allocator,
        .scope = scope,
        .request_id = req.id,
        .acq_seq = req.acq_seq,
    };
    const id = timer.setTimeoutOwned(timeout_ms, TimeoutCtx.fire, ctx, TimeoutCtx.drop);
    if (id == 0) {
        allocator.destroy(ctx);
        return;
    }
    req.timeout_timer_id = id;
    req.timeout_ctx = ctx;
}

// ============================================================================
// Platform Async Reply & Watch Position Events
// ============================================================================

const PlatformReplyCtx = struct {
    allocator: std.mem.Allocator,
    scope: *runtime.BrowserScope,
    sink: ?*runtime.TaskSink,
    request_id: u64,
    acq_seq: u64,
    request_thread: std.Thread.Id,

    fn deliver(context: *anyopaque, value: *const platform.PositionResult) callconv(.c) void {
        const self: *PlatformReplyCtx = @ptrCast(@alignCast(context));
        self.dispatch(value.*);
    }

    fn drop(context: *anyopaque) callconv(.c) void {
        const self: *PlatformReplyCtx = @ptrCast(@alignCast(context));
        self.dispatch(.{ .error_code = .position_unavailable });
    }

    fn dispatch(self: *PlatformReplyCtx, result: platform.PositionResult) void {
        const allocator = self.allocator;
        const sink = self.sink;
        const scope = self.scope;
        const request_id = self.request_id;
        const acq_seq = self.acq_seq;
        const request_thread = self.request_thread;
        allocator.destroy(self);

        if (sink) |held| {
            defer held.release();
            const task = allocator.create(PlatformReplyTask) catch return;
            task.* = .{
                .allocator = allocator,
                .scope = scope,
                .request_id = request_id,
                .acq_seq = acq_seq,
                .result = result,
            };
            _ = held.post(.{ .run = PlatformReplyTask.run, .drop = PlatformReplyTask.drop, .data = task });
        } else if (std.Thread.getCurrentId() == request_thread) {
            handlePlatformReply(scope, request_id, acq_seq, result);
        }
    }
};

const PlatformReplyTask = struct {
    allocator: std.mem.Allocator,
    scope: *runtime.BrowserScope,
    request_id: u64,
    acq_seq: u64,
    result: platform.PositionResult,

    fn run(data: ?*anyopaque) void {
        const self: *PlatformReplyTask = @ptrCast(@alignCast(data orelse return));
        const scope = self.scope;
        const request_id = self.request_id;
        const acq_seq = self.acq_seq;
        const result = self.result;
        self.allocator.destroy(self);
        handlePlatformReply(scope, request_id, acq_seq, result);
    }

    fn drop(data: ?*anyopaque) void {
        const self: *PlatformReplyTask = @ptrCast(@alignCast(data orelse return));
        self.allocator.destroy(self);
    }
};

fn handlePlatformReply(scope: *runtime.BrowserScope, request_id: u64, acq_seq: u64, result: platform.PositionResult) void {
    const registry = scope.existing(Registry) orelse return;
    const req = registry.findRequest(request_id) orelse return;
    if (req.acq_seq != acq_seq or req.phase != .acquiring) return;
    req.platform_request_id = 0;
    req.cancelTimer();

    // If an emulation override was installed while the platform call was in
    // flight, emulation wins (§6.6 step 5.3.1).
    if (req.isWindowLive()) {
        if (getEmulatedPositionData(req.window) != null) {
            acquirePosition(registry, scope, req);
            return;
        }
    }

    deliverPlatformResult(registry, req, result);
}

fn deliverPlatformResult(registry: *Registry, req: *PositionRequest, result: platform.PositionResult) void {
    switch (result.error_code) {
        .none => {
            const coords = coordsFromPlatform(result);
            const ts: u64 = if (result.timestamp.ns_since_epoch > 0)
                @intCast(@divFloor(result.timestamp.ns_since_epoch, std.time.ns_per_ms))
            else
                currentEpochMs(req.realm);
            deliverSuccessForAcquisition(registry, req, coords, null, 0, ts, true);
        },
        .permission_denied => {
            deliverErrorAndFinish(registry, req, ErrorCode.permission_denied, "User denied Geolocation", true);
        },
        .position_unavailable => {
            deliverErrorForAcquisition(registry, req, ErrorCode.position_unavailable, "Position unavailable");
        },
        .timeout => {
            deliverErrorForAcquisition(registry, req, ErrorCode.timeout, "Timeout expired");
        },
    }
}

fn coordsFromPlatform(result: platform.PositionResult) Coordinates {
    return .{
        .latitude = result.latitude,
        .longitude = result.longitude,
        .accuracy = result.accuracy,
        .altitude = if (std.math.isNan(result.altitude)) null else result.altitude,
        .altitude_accuracy = if (std.math.isNan(result.altitude_accuracy)) null else result.altitude_accuracy,
        .heading = if (std.math.isNan(result.heading)) null else result.heading,
        .speed = if (std.math.isNan(result.speed)) null else result.speed,
    };
}

/// Platform `PlatformEventKind.position` delivered on the window's event loop
/// from `src/browser/platform_events.zig`.
pub fn platformPositionEvent(scope: *runtime.BrowserScope, watch: platform.WatchId, result: platform.PositionResult) void {
    const registry = scope.existing(Registry) orelse return;
    // Collect matching request IDs first so delivery cannot invalidate iteration.
    var ids: std.ArrayListUnmanaged(u64) = .empty;
    defer ids.deinit(registry.allocator);
    for (registry.requests.items) |req| {
        if (req.platform_watch_id) |pw| {
            if (pw.id == watch.id) {
                ids.append(registry.allocator, req.id) catch continue;
            }
        }
    }
    for (ids.items) |req_id| {
        const req = registry.findRequest(req_id) orelse continue;
        if (!req.isDocumentLive() or !req.isWindowLive() or !req.realm.hasEngine()) {
            registry.removeRequest(req_id);
            continue;
        }
        // §6.5 step 7.5.2: position updates are exclusively for fully active visible documents.
        if (!isFullyActive(req.document) or (interfaces.Document.get_hidden(req.document) catch false)) continue;
        // Emulation override takes precedence over platform updates (§12).
        if (getEmulatedPositionData(req.window) != null) continue;
        // Re-check current permission state (§6.6 step 5.1-5.2).
        if (currentPermissionState(registry, scope, req.realm, req.window) != .granted) {
            deliverErrorAndFinish(registry, req, ErrorCode.permission_denied, "User denied Geolocation", true);
            continue;
        }
        deliverPlatformResult(registry, req, result);
    }
}

// ============================================================================
// §12 Emulation & Visibility / Teardown Hooks
// ============================================================================

/// §12 "set emulated position data" on `traversable` (a top-level traversable
/// BrowsingContext). Updates `host_overrides.geolocation` and treats a non-null
/// override as a significant change notifying active watches on `traversable`
/// and its inclusive descendant documents.
pub fn setEmulatedPositionData(traversable: *BrowsingContext, owner: Owner, data: ?GeolocationOverride) void {
    const top = traversable.getTop();
    top.host_overrides.setGeolocation(owner, data);
    if (data == null) return;
    notifySignificantChange(top);
}

/// Notify all active watches in `traversable` (top-level) that a significant
/// geographic position change occurred (§6.5 step 7.5.1, §12 step 3.2).
pub fn notifySignificantChange(traversable: *BrowsingContext) void {
    const top = traversable.getTop();
    const doc_ptr = top.getActiveDocument() orelse return;
    const active_doc: *Instance = @ptrCast(@alignCast(doc_ptr));
    const scope = runtime.BrowserScope.ofInstance(active_doc);
    const registry = scope.existing(Registry) orelse return;

    var ids: std.ArrayListUnmanaged(u64) = .empty;
    defer ids.deinit(registry.allocator);
    for (registry.requests.items) |req| {
        if (req.watch_id == null) continue;
        if (req.phase != .watching and req.phase != .acquiring) continue;
        if (!req.isWindowLive()) continue;
        const bc = dom.browser_state.browsingContextOf(req.window) orelse continue;
        if (bc.getTop() != top) continue;
        ids.append(registry.allocator, req.id) catch continue;
    }

    for (ids.items) |req_id| {
        const req = registry.findRequest(req_id) orelse continue;
        if (!req.isDocumentLive() or !req.isWindowLive() or !req.realm.hasEngine()) {
            registry.removeRequest(req_id);
            continue;
        }
        // §6.5 step 7.5.2: silently drop if not fully active or not visible.
        if (!isFullyActive(req.document)) continue;
        if (interfaces.Document.get_hidden(req.document) catch false) continue;
        acquirePosition(registry, scope, req);
    }
}

/// §12 "get emulated position data": read top-level traversable's override.
fn getEmulatedPositionData(window: *Instance) ?GeolocationOverride {
    const bc = dom.browser_state.browsingContextOf(window) orelse return null;
    return bc.getTop().host_overrides.geolocation;
}

/// HTML page visibility change steps (§6.5 step 5): called from
/// `Document.updateVisibilityState` whenever `document`'s visibility changes.
/// Resumes any requests waiting in `.waiting_visible` once `document` is visible.
pub fn visibilityChanged(document: *Instance) void {
    if (interfaces.Document.get_hidden(document) catch true) return;
    const scope = runtime.BrowserScope.ofInstance(document);
    const registry = scope.existing(Registry) orelse return;
    const doc_gen = runtime.SlabAllocator.generationOf(document);

    var ids: std.ArrayListUnmanaged(u64) = .empty;
    defer ids.deinit(registry.allocator);
    for (registry.requests.items) |req| {
        if (req.phase == .waiting_visible and req.document == document and req.document_generation == doc_gen) {
            ids.append(registry.allocator, req.id) catch continue;
        }
    }
    for (ids.items) |req_id| {
        const req = registry.findRequest(req_id) orelse continue;
        req.phase = .pending_start;
        queueStartRequest(registry.allocator, scope, req);
    }
}

/// HTML unloading document cleanup step (`dom.unloading_cleanup.installDocumentOnly`):
/// cancel all active watches, timers, platform requests, and cached positions
/// belonging to `environment`.
pub fn unloadingCleanup(environment: runtime.Context) void {
    const scope = environment.browserScope() orelse return;
    const registry = scope.existing(Registry) orelse return;

    var i: usize = 0;
    while (i < registry.requests.items.len) {
        if (registry.requests.items[i].realm == environment) {
            const removed = registry.requests.swapRemove(i);
            removed.deinit(registry.allocator);
        } else {
            i += 1;
        }
    }

    var j: usize = 0;
    while (j < registry.slots.items.len) {
        if (registry.slots.items[j].realm == environment) {
            const slot = registry.slots.swapRemove(j);
            slot.clearCache();
            registry.allocator.destroy(slot);
        } else {
            j += 1;
        }
    }
}

/// Called from `Geolocation.deinitOwn` when a Geolocation instance is collected.
pub fn geolocationDestroyed(geolocation: *Instance) void {
    const scope = geolocation.ctx.browserScope() orelse return;
    const registry = scope.existing(Registry) orelse return;
    const gen = runtime.SlabAllocator.generationOf(geolocation);

    var i: usize = 0;
    while (i < registry.requests.items.len) {
        const req = registry.requests.items[i];
        if (req.geolocation == geolocation and req.geolocation_generation == gen) {
            const removed = registry.requests.swapRemove(i);
            removed.deinit(registry.allocator);
        } else {
            i += 1;
        }
    }

    var j: usize = 0;
    while (j < registry.slots.items.len) {
        const slot = registry.slots.items[j];
        if (slot.geolocation == geolocation and slot.generation == gen) {
            const removed = registry.slots.swapRemove(j);
            removed.clearCache();
            registry.allocator.destroy(removed);
        } else {
            j += 1;
        }
    }
}

// ============================================================================
// Delivery Helpers (§6.6 & §6.7)
// ============================================================================

fn deliverSuccessForAcquisition(
    registry: *Registry,
    req: *PositionRequest,
    coords: Coordinates,
    cached_pos: ?*Instance,
    cached_pos_gen: u64,
    timestamp: u64,
    update_cache: bool,
) void {
    const is_watch = req.watch_id != null;
    const cb = if (is_watch)
        (cloneCallback(req.realm, req.success_cb) catch return)
    else blk: {
        // Move success_cb ownership into the task before removing the one-shot request.
        const moved = req.success_cb;
        req.success_cb = undefined;
        break :blk moved;
    };

    const realm = req.realm;
    const doc = req.document;
    const doc_gen = req.document_generation;
    const geo = req.geolocation;
    const geo_gen = req.geolocation_generation;
    const is_high_accuracy = req.options.enable_high_accuracy;

    if (is_watch) {
        req.phase = .watching;
    } else {
        // One-shot request completed; remove without releasing moved success_cb.
        removeRequestKeepingSuccessCb(registry, req.id);
    }

    queueSuccessCallback(
        realm,
        doc,
        doc_gen,
        geo,
        geo_gen,
        cb,
        coords,
        cached_pos,
        cached_pos_gen,
        timestamp,
        is_high_accuracy,
        update_cache,
    );
}

fn deliverErrorForAcquisition(
    registry: *Registry,
    req: *PositionRequest,
    code: u16,
    message: []const u8,
) void {
    // Non-fatal acquisition errors (POSITION_UNAVAILABLE, TIMEOUT) keep a
    // watch alive so subsequent updates can succeed (§6.5 step 7.5).
    deliverErrorAndFinish(registry, req, code, message, req.watch_id == null);
}

fn deliverErrorAndFinish(
    registry: *Registry,
    req: *PositionRequest,
    code: u16,
    message: []const u8,
    terminate_watch: bool,
) void {
    const realm = req.realm;
    const should_remove = terminate_watch or req.watch_id == null;

    var cb_to_call: ?engine.CallbackFunction = null;
    if (req.error_cb) |ecb| {
        if (should_remove) {
            cb_to_call = ecb;
            req.error_cb = null;
        } else {
            cb_to_call = cloneCallback(realm, ecb) catch null;
        }
    }

    if (should_remove) {
        registry.removeRequest(req.id);
    } else {
        req.phase = .watching;
    }

    if (cb_to_call) |cb| {
        queueErrorCallback(realm, cb, code, message, false);
    }
}

fn removeRequestKeepingSuccessCb(registry: *Registry, request_id: u64) void {
    for (registry.requests.items, 0..) |req, i| {
        if (req.id == request_id) {
            const removed = registry.requests.swapRemove(i);
            removed.cancelTimer();
            removed.cancelPlatformOps();
            if (removed.error_cb) |cb| cb.release();
            registry.allocator.destroy(removed);
            return;
        }
    }
}

fn cloneCallback(realm: runtime.Context, cb: engine.CallbackFunction) !engine.CallbackFunction {
    const target_realm = cb.context orelse realm;
    const retained = try engine.retainValue(target_realm, cb.function.borrow());
    return .{ .function = retained, .context = cb.context };
}

fn reportCallbackException(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
    const window_realm: runtime.Context = @ptrCast(@alignCast(host orelse return));
    const realm = info.realm orelse window_realm;
    const record = realm.getRealm() orelse return;
    const global: *Instance = @ptrCast(@alignCast(record.global_object orelse return));
    const extracted: runtime.ErrorInfo = .{
        .message = info.message,
        .filename = info.filename,
        .lineno = info.lineno,
        .colno = info.colno,
        .error_value = if (info.error_value == .undefined) null else info.error_value,
    };
    _ = report_exception.reportErrorInfo(global, &extracted, .{});
}

const ErrorTask = struct {
    allocator: std.mem.Allocator,
    realm: runtime.Context,
    exec_realm: runtime.Context,
    callback: engine.CallbackFunction,
    code: u16,
    message: []const u8,
    allow_inactive: bool,

    fn run(data: ?*anyopaque) void {
        const self: *ErrorTask = @ptrCast(@alignCast(data orelse return));
        defer self.finish();
        // For a non-fully-active document (§6.2/§6.3 step 1), the Geolocation
        // object's own realm may already be detached (e.g. a removed iframe),
        // in which case `runTaskInRealm(self.realm, ...)` returns
        // OperationFailed. Run in the callback's incumbent realm so cross-frame
        // callbacks in an active parent document still fire (WPT
        // geolocation/non-fully-active.https.html).
        if (self.allow_inactive) {
            if (self.callback.context) |cb_ctx| {
                if (cb_ctx.hasEngine()) {
                    self.exec_realm = cb_ctx;
                    engine.runTaskInRealm(cb_ctx, steps, self) catch {};
                    return;
                }
            }
        }
        if (self.realm.hasEngine()) {
            self.exec_realm = self.realm;
            engine.runTaskInRealm(self.realm, steps, self) catch {
                if (self.callback.context) |cb_ctx| {
                    if (cb_ctx != self.realm and cb_ctx.hasEngine()) {
                        self.exec_realm = cb_ctx;
                        engine.runTaskInRealm(cb_ctx, steps, self) catch {};
                    }
                }
            };
        }
    }

    fn steps(data: ?*anyopaque) void {
        const self: *ErrorTask = @ptrCast(@alignCast(data orelse return));
        const exec_realm = self.exec_realm;
        // §6.7 step 2: Let error be a newly created GeolocationPositionError
        // whose code attribute is initialized to code.
        const err_obj = interfaces.GeolocationPositionError.initWith(
            exec_realm.allocator,
            exec_realm,
            .{ .code = self.code, .message = self.message },
        ) catch return;
        const gen = runtime.SlabAllocator.generationOf(err_obj);
        defer err_obj.releaseIfUnwrapped(gen);
        // §6.7 step 3: Invoke callback with « error » and "report".
        const completion = engine.invokeCallbackFunction(
            exec_realm,
            &self.callback,
            .undefined,
            &.{.{ .instance = err_obj }},
            .{ .report = .{ .report = reportCallbackException, .host = exec_realm } },
        ) catch return;
        switch (completion) {
            inline else => |value| value.release(),
        }
    }

    fn drop(data: ?*anyopaque) void {
        const self: *ErrorTask = @ptrCast(@alignCast(data orelse return));
        self.finish();
    }

    fn finish(self: *ErrorTask) void {
        self.callback.release();
        self.allocator.destroy(self);
    }
};

/// §6.7 Call back with error: queue a task on the geolocation task source.
/// `allow_inactive` is true for §6.2/§6.3 step 1 (non-fully-active document),
/// so cross-frame callbacks in an active caller realm still execute.
fn queueErrorCallback(
    realm: runtime.Context,
    callback: engine.CallbackFunction,
    code: u16,
    message: []const u8,
    allow_inactive: bool,
) void {
    const task = realm.allocator.create(ErrorTask) catch {
        callback.release();
        return;
    };
    task.* = .{
        .allocator = realm.allocator,
        .realm = realm,
        .exec_realm = realm,
        .callback = callback,
        .code = code,
        .message = message,
        .allow_inactive = allow_inactive,
    };
    const loop = realm.getOptionalEventLoop() orelse
        (if (callback.context) |cb_ctx| cb_ctx.getOptionalEventLoop() else null) orelse
        {
            ErrorTask.run(task);
            return;
        };
    if (allow_inactive) {
        loop.queueTask(.{
            .callback = ErrorTask.run,
            .context = task,
            .drop = ErrorTask.drop,
            .document = null,
            .document_generation = 0,
        });
    } else {
        const window = user_activation.windowOfRealm(realm);
        const doc = if (window) |w| (interfaces.Window.get_document(w) catch null) else null;
        loop.queueTask(.{
            .callback = ErrorTask.run,
            .context = task,
            .drop = ErrorTask.drop,
            .document = if (doc) |d| @ptrCast(d) else null,
            .document_generation = if (doc) |d| runtime.SlabAllocator.generationOf(d) else 0,
        });
    }
}

const SuccessTask = struct {
    allocator: std.mem.Allocator,
    realm: runtime.Context,
    geolocation: *Instance,
    geolocation_generation: u64,
    callback: engine.CallbackFunction,
    coords: Coordinates,
    cached_pos: ?*Instance,
    cached_pos_gen: u64,
    timestamp: u64,
    is_high_accuracy: bool,
    update_cache: bool,

    fn run(data: ?*anyopaque) void {
        const self: *SuccessTask = @ptrCast(@alignCast(data orelse return));
        defer self.finish();
        if (!self.realm.hasEngine()) return;
        engine.runTaskInRealm(self.realm, steps, self) catch {};
    }

    fn steps(data: ?*anyopaque) void {
        const self: *SuccessTask = @ptrCast(@alignCast(data orelse return));
        const realm = self.realm;

        const pos: *Instance = blk: {
            if (self.cached_pos) |cached| {
                if (runtime.SlabAllocator.generationOf(cached) == self.cached_pos_gen) {
                    break :blk cached;
                }
            }
            // §9.6 Constructing a GeolocationPosition.
            const coords_obj = interfaces.GeolocationCoordinates.initWith(
                realm.allocator,
                realm,
                .{ .coordinates = self.coords },
            ) catch return;
            const coords_gen = runtime.SlabAllocator.generationOf(coords_obj);
            const pos_obj = interfaces.GeolocationPosition.initWith(
                realm.allocator,
                realm,
                .{
                    .coords = coords_obj,
                    .timestamp = self.timestamp,
                    .is_high_accuracy = self.is_high_accuracy,
                },
            ) catch {
                coords_obj.releaseIfUnwrapped(coords_gen);
                return;
            };
            if (self.update_cache) {
                if (realm.browserScope()) |scope| {
                    if (scope.existing(Registry)) |registry| {
                        if (registry.findSlot(self.geolocation, self.geolocation_generation)) |slot| {
                            slot.setCache(pos_obj, self.timestamp, self.is_high_accuracy);
                        }
                    }
                }
            }
            break :blk pos_obj;
        };

        const pos_gen = runtime.SlabAllocator.generationOf(pos);
        defer pos.releaseIfUnwrapped(pos_gen);
        // §6.6 step 5.3.1.2.3 / 5.3.3.2.1 / 5.3.8: Invoke successCallback with
        // « position » and "report".
        const completion = engine.invokeCallbackFunction(
            realm,
            &self.callback,
            .undefined,
            &.{.{ .instance = pos }},
            .{ .report = .{ .report = reportCallbackException, .host = realm } },
        ) catch return;
        switch (completion) {
            inline else => |value| value.release(),
        }
    }

    fn drop(data: ?*anyopaque) void {
        const self: *SuccessTask = @ptrCast(@alignCast(data orelse return));
        self.finish();
    }

    fn finish(self: *SuccessTask) void {
        self.callback.release();
        self.allocator.destroy(self);
    }
};

fn queueSuccessCallback(
    realm: runtime.Context,
    document: *Instance,
    document_generation: u64,
    geolocation: *Instance,
    geolocation_generation: u64,
    callback: engine.CallbackFunction,
    coords: Coordinates,
    cached_pos: ?*Instance,
    cached_pos_gen: u64,
    timestamp: u64,
    is_high_accuracy: bool,
    update_cache: bool,
) void {
    const task = realm.allocator.create(SuccessTask) catch {
        callback.release();
        return;
    };
    task.* = .{
        .allocator = realm.allocator,
        .realm = realm,
        .geolocation = geolocation,
        .geolocation_generation = geolocation_generation,
        .callback = callback,
        .coords = coords,
        .cached_pos = cached_pos,
        .cached_pos_gen = cached_pos_gen,
        .timestamp = timestamp,
        .is_high_accuracy = is_high_accuracy,
        .update_cache = update_cache,
    };
    const loop = realm.getOptionalEventLoop() orelse {
        SuccessTask.run(task);
        return;
    };
    loop.queueTask(.{
        .callback = SuccessTask.run,
        .context = task,
        .drop = SuccessTask.drop,
        .document = @ptrCast(document),
        .document_generation = document_generation,
    });
}

// ============================================================================
// Environment & Permission Helpers
// ============================================================================

const DocInfo = struct {
    window: *Instance,
    document: *Instance,
};

fn associatedDocument(realm: runtime.Context) ?DocInfo {
    const window = user_activation.windowOfRealm(realm) orelse return null;
    const document = interfaces.Window.get_document(window) catch return null;
    return .{ .window = window, .document = document };
}

fn isFullyActive(document: *Instance) bool {
    return dom.document_activity.fullyActive(document, runtime.SlabAllocator.generationOf(document));
}

fn isSecureContext(window: *Instance) bool {
    const settings = dom.global_settings.of(window) orelse return false;
    return settings.is_secure_context(window);
}

fn currentEpochMs(realm: runtime.Context) u64 {
    const wall = platform_state.clockOf(realm).wallNow();
    const ms = @divFloor(wall.ns_since_epoch, std.time.ns_per_ms);
    return if (ms < 0) 0 else @intCast(ms);
}

fn currentPermissionState(
    registry: *const Registry,
    scope: *runtime.BrowserScope,
    realm: runtime.Context,
    window: *Instance,
) PermissionState {
    const settings = dom.global_settings.of(window) orelse return .denied;
    if (!settings.is_secure_context(window)) return .denied;

    // Check BrowserStore override (same top-level origin key as Permissions.zig).
    if (registry.permission_reader) |reader| {
        const key: ?[]const u8 = blk: {
            if (settings.top_level_origin) |top_of| {
                break :blk top_of(window) catch null;
            }
            break :blk settings.origin(window) catch null;
        };
        defer if (key) |k| window.ctx.allocator.free(k);
        if (key) |k| {
            if (reader(scope, k)) |overridden| return overridden;
        }
    }

    // Consult OS permission state when the platform supports os_permissions.
    if (comptime platform.capabilities.os_permissions != .unsupported) {
        if (platform_state.of(realm)) |browser| {
            if (platform_state.requester(realm, false) catch null) |parts_const| {
                var parts = parts_const;
                defer parts.deinit();
                const plat_req = parts.requester();
                const desc: platform.PermissionDescriptor = .{ .name = .geolocation };
                const os_perm = platform.platformPermissionState(browser, &plat_req, &desc);
                if (os_perm.governed) {
                    return switch (os_perm.state) {
                        .granted => .granted,
                        .denied => .denied,
                        .prompt => .prompt,
                    };
                }
            }
        }
    }

    return .prompt;
}

fn requestPermission(
    registry: *const Registry,
    scope: *runtime.BrowserScope,
    realm: runtime.Context,
    window: *Instance,
) PermissionState {
    const state = currentPermissionState(registry, scope, realm, window);
    return switch (state) {
        .granted => .granted,
        .denied => .denied,
        // Headless / no UI prompt: a permission request in the prompt state is denied
        // (src/platform/protocol.zig Capabilities.os_permissions).
        .prompt => .denied,
    };
}

// ============================================================================
// Unit Tests
// ============================================================================

test "Options.fromWebIDL applies W3C Geolocation §7 defaults" {
    const defaults = Options.fromWebIDL(.notPassed());
    try std.testing.expect(!defaults.enable_high_accuracy);
    try std.testing.expectEqual(@as(u32, 0xFFFFFFFF), defaults.timeout_ms);
    try std.testing.expectEqual(@as(u32, 0), defaults.maximum_age_ms);

    const custom = Options.fromWebIDL(.passed(.{
        .enableHighAccuracy = true,
        .timeout = 5000,
        .maximumAge = 60000,
    }));
    try std.testing.expect(custom.enable_high_accuracy);
    try std.testing.expectEqual(@as(u32, 5000), custom.timeout_ms);
    try std.testing.expectEqual(@as(u32, 60000), custom.maximum_age_ms);
}

test "coordsFromPlatform converts NaN optional fields to null" {
    const result: platform.PositionResult = .{
        .error_code = .none,
        .latitude = 37.7749,
        .longitude = -122.4194,
        .accuracy = 15.0,
        .altitude = std.math.nan(f64),
        .altitude_accuracy = 5.0,
        .heading = 90.0,
        .speed = 2.5,
    };
    const coords = coordsFromPlatform(result);
    try std.testing.expectEqual(@as(f64, 37.7749), coords.latitude);
    try std.testing.expectEqual(@as(f64, -122.4194), coords.longitude);
    try std.testing.expectEqual(@as(f64, 15.0), coords.accuracy);
    try std.testing.expect(coords.altitude == null);
    try std.testing.expectEqual(@as(?f64, 5.0), coords.altitude_accuracy);
    try std.testing.expectEqual(@as(?f64, 90.0), coords.heading);
    try std.testing.expectEqual(@as(?f64, 2.5), coords.speed);
}
