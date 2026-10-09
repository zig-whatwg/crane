//! HTML media loading and resource selection. The host owns decoding; default
//! support is empty. Every asynchronous continuation is fenced by its load ID.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const webidl = @import("webidl");
const dom = @import("dom");
const html = @import("html");
const common = html.media_runtime;
const LoadState = @import("html_core").media.LoadState;
const backend = @import("platform").media_backend;
const same_object = @import("same_object.zig");
const clock = @import("clock");
const hooks = dom.media_elements;
pub const State = interfaces.HTMLMediaElement.State;
const Kind = enum(u16) { event, failure, read, next_source, release_delay, pause, track_event, select_tracks, track_change, progress_tick, stalled, fatal_network, fatal_decode, playing, resolve_play, reached_end, select };
/// "time marches on" fires timeupdate every 15 to 250ms of normal playback
/// (4.8.11.8 step 6); Chromium and Gecko both use 250ms.
const timeupdate_interval_ms: u64 = 250;

pub const InternalState = struct {
    activity: common.Activity,
    resource: common.Resource,
    load: LoadState,
    src_url: ?[]const u8 = null,
    src_object: ?typedefs.MediaProvider = null,
    object_edge: same_object.Traced = .{ .slot = .{ .name = "srcObject" } },
    error_object: ?*runtime.Instance = null,
    error_edge: same_object.Traced = .{ .slot = .{ .name = "error" } },
    before: ?same_object.Link = null,
    after: ?same_object.Link = null,
    candidate: ?same_object.Link = null,
    decoder: ?backend.Decoder = null,
    pending_play: std.ArrayList(engine.PromiseCapability) = .empty,
    read_queued: bool = false,
    volume: f64 = 1,
    muted: ?bool = null,
    preserves_pitch: bool = true,
    delay_document: ?same_object.Link = null,
    progress: @import("html_core").media.Progress = .{},
    progress_timer: @import("html_core").media.Deadline(runtime.TimerInterface) = .{},
    stall_timer: @import("html_core").media.Deadline(runtime.TimerInterface) = .{},
    text_tracks: ?*runtime.Instance = null,
    tracks_keep: same_object.KeptChild = .{},
    tracks: @import("html_core").media.track_selection.State = .{},
    fetch_document: ?same_object.Link = null,
    document_abort_pending: ?u64 = null,
    /// The media timeline's clock while potentially playing: the monotonic
    /// time the current playback position was last advanced to, and the
    /// timer that runs "time marches on". Crane plays nothing out loud; the
    /// host's decoder holds the data, and the position moves on this clock.
    clock_anchor: ?i128 = null,
    clock_timer: @import("html_core").media.Deadline(runtime.TimerInterface) = .{},
    /// The official playback position was set from the clock in this task;
    /// a stable state clears it (4.8.11.8: "Any time the user agent provides a
    /// stable state, the official playback position must be set to the
    /// current playback position").
    official_fresh: bool = false,
    /// The video's natural size (HTML 4.8.8): the size of the frame at the
    /// current playback position, as the host's decoder reports it; 0x0 for
    /// a resource with no video.
    video_size: backend.VideoSize = .{ .width = 0, .height = 0 },

    fn queue(self: *InternalState, kind: Kind, target: ?*runtime.Instance, name: ?[]const u8) !void {
        return self.activity.queue(@intFromEnum(kind), self.load.generation, target, name);
    }
    fn event(self: *InternalState, name: []const u8) !void {
        _ = try self.queue(.event, null, name);
    }
    /// Stop fetching and drop the resource's decoder.
    fn endFetch(self: *InternalState) void {
        self.stopFetch();
        if (self.decoder) |*decoder| decoder.deinit();
        self.decoder = null;
    }
    /// Stop fetching. A resource fetched to its end keeps its decoder: it
    /// holds the media data, and playback asks it about positions (the
    /// size of the frame at each, videoSizeAt) until the next load,
    /// a failure, or teardown drops it (endFetch).
    fn stopFetch(self: *InternalState) void {
        self.document_abort_pending = null;
        self.progress_timer.cancel();
        self.stall_timer.cancel();
        self.progress.reset();
        self.resource.stop();
        self.activity.fetching = false;
        self.read_queued = false;
    }
    fn syncDelay(self: *InternalState) void {
        const instance = self.activity.instance orelse return;
        if (self.load.delaying_load_event) {
            if (self.delay_document == null) if (common.documentOf(instance)) |doc| {
                self.delay_document = same_object.Link.to(doc);
            };
        } else if (self.delay_document) |link| {
            self.delay_document = null;
            if (link.isLive()) dom.document_lifecycle.loadDelayMayHaveEnded(link.instance);
        }
    }
    fn register(self: *InternalState) !void {
        const instance = self.activity.instance orelse return error.InvalidStateError;
        if (common.liveRegistry(instance.ctx)) |registry| try registry.add(instance, instance.ctx);
    }
    fn unregister(self: *InternalState) void {
        const instance = self.activity.instance orelse return;
        if (common.liveRegistry(instance.ctx)) |registry| registry.remove(instance);
    }
    fn finish(self: *InternalState, generation: u64) void {
        if (generation != self.load.generation) return;
        self.stopFetch();
        self.load.endLoadDelay(generation);
        // A playing element stays in the live registry, so the document's
        // unload and discard reach it (syncClock).
        if (!self.activity.playing) self.unregister();
        self.syncDelay();
        self.activity.sync();
    }
    fn cancel(self: *InternalState) void {
        self.stopClock();
        self.activity.discardTasks(false);
        self.tracks.takeChange();
        self.load.cancel();
        self.endFetch();
        self.unregister();
        self.syncDelay();
        for (self.pending_play.items) |*promise| engine.releasePromiseCapability(promise);
        self.pending_play.clearRetainingCapacity();
        self.activity.sync();
    }
    fn selectLater(self: *InternalState) !void {
        const generation = self.load.beginSelection();
        self.syncDelay();
        try self.register();
        self.delayUntilSelection();
        try self.awaitSelection(generation);
    }
    fn resumeSelection(self: *InternalState) !void {
        // Children steps 22–25 resume ONE waiting algorithm. Multiple child
        // insertions before its stable section cannot advance its pointer twice.
        // Step 24 can delay document load again, so restore the live registry.
        try self.register();
        self.delayUntilSelection();
        try self.awaitSelection(self.load.generation);
    }
    /// With selection's wait a task (awaitSelection), the document's load
    /// event could fire between the invocation and the synchronous section
    /// that sets the delaying-the-load-event flag (step 4; children step 24).
    /// Chromium sets the flag when the algorithm is invoked
    /// (InvokeResourceSelectionAlgorithm: "3 - Set the media element's
    /// delaying-the-load-event flag to true"), the step's place before HTML
    /// moved it for lazy loading; Crane loads media eagerly, so it does the
    /// same. resource-selection-invoke-set-src.html, -insert-source.html,
    /// -audio-constructor.html and others wait for loadstart before
    /// window.onload; Chrome and Safari pass them. Without an event loop the
    /// microtask runs before any load event can, and nothing changes.
    fn delayUntilSelection(self: *InternalState) void {
        if (!self.hasEventLoop()) return;
        self.load.delaying_load_event = true;
        self.syncDelay();
    }
    /// The resource selection algorithm's "await a stable state" (4.8.11.5:
    /// step 4, and children steps 11 and 25), for load(), the insertion
    /// steps, a src attribute set, and a source inserted or failed while
    /// waiting.
    /// Deviation: HTML defines awaiting a stable state as queueing a microtask
    /// (8.1.7.3), which the parser's checkpoint before an inline script runs -
    /// so a parsed <source> fails before that script can give it a src. The
    /// browsers all wait for the current task to end instead: Chromium's
    /// HTMLMediaElement::InvokeResourceSelectionAlgorithm and
    /// ScheduleNextSourceChild start a 0-delay load_timer_ (a TODO there,
    /// crbug.com/593289, would move it to a microtask), Gecko's
    /// QueueSelectResourceTask uses RunInStableState (after the current
    /// task), and WebKit queues a task. media-src-7_1_2.sub.html depends on it:
    /// Chrome, Firefox and Safari pass it 3/3 (wpt.fyi aligned stable runs,
    /// 2026-10-09). So the synchronous section runs in a media element task,
    /// on the element's task source, like its other tasks. A host with no
    /// event loop keeps the stable-state microtask.
    fn hasEventLoop(self: *InternalState) bool {
        const instance = self.activity.instance orelse return false;
        return instance.ctx.getOptionalEventLoop() != null;
    }
    fn awaitSelection(self: *InternalState, generation: u64) !void {
        const instance = self.activity.instance orelse return error.InvalidStateError;
        if (instance.ctx.getOptionalEventLoop() == null) {
            if (self.activity.hasStableFor(generation, stable)) return;
            return self.activity.stable(generation, stable);
        }
        // One pending selection task per load generation.
        var task = self.activity.head;
        while (task) |pending| : (task = pending.next) {
            if (pending.kind == @intFromEnum(Kind.select) and pending.generation == generation and !pending.cancelled) return;
        }
        try self.queue(.select, null, null);
    }
    fn fail(self: *InternalState) void {
        if (self.load.ready != .nothing) {
            self.fatal(.fatal_network);
            return;
        }
        self.endFetch();
        switch (self.load.failCandidate(self.load.generation)) {
            .fetch => unreachable,
            .ignored => {},
            .source_error => {
                const target = if (self.candidate) |link| (if (link.isLive()) link.instance else null) else null;
                // Children steps 10–11: error belongs to the source, then await
                // stable state before advancing the live child-list pointer.
                _ = self.queue(.next_source, target, if (target != null) "error" else null) catch {
                    self.cancel();
                    return;
                };
                // With an event loop the stable-state wait is a task
                // (awaitSelection), queued now, right behind the error task,
                // as the algorithm reaches step 11 (Chromium starts its
                // load_timer_ when the source fails, not after its error
                // event). Without one, the error task awaits the microtask.
                if (self.hasEventLoop()) self.awaitSelection(self.load.generation) catch {
                    self.cancel();
                    return;
                };
            },
            .dedicated_failure => {
                self.activity.queuePlay(@intFromEnum(Kind.failure), self.load.generation, "error", &self.pending_play, "NotSupportedError") catch {
                    self.cancel();
                    return;
                };
            },
        }
        self.activity.sync();
    }
    fn fatal(self: *InternalState, kind: Kind) void {
        self.endFetch();
        self.queue(kind, null, "error") catch self.cancel();
        self.activity.sync();
    }
    fn armProgress(self: *InternalState) !void {
        const instance = self.activity.instance orelse return;
        const timer = instance.ctx.getOptionalTimer() orelse return;
        try self.progress_timer.start(self.load.allocator, timer, 350, progressDue, self);
    }
    fn armStall(self: *InternalState) !void {
        const instance = self.activity.instance orelse return;
        const timer = instance.ctx.getOptionalTimer() orelse return;
        try self.stall_timer.start(self.load.allocator, timer, 3000, stallDue, self);
    }
    fn progressDue(context: *anyopaque) void {
        const self: *InternalState = @ptrCast(@alignCast(context));
        if (!self.activity.fetching or self.activity.instance == null) return;
        if (self.progress.bytes_pending) self.queue(.progress_tick, null, "progress") catch self.cancel();
        if (self.activity.fetching) self.armProgress() catch self.cancel();
    }
    fn stallDue(context: *anyopaque) void {
        const self: *InternalState = @ptrCast(@alignCast(context));
        if (self.activity.fetching and self.activity.instance != null) self.queue(.stalled, null, "stalled") catch self.cancel();
    }
    fn candidateResult(self: *InternalState, result: LoadState.CandidateResult) !void {
        switch (result) {
            .ignored => {},
            .fetch => try self.fetchCurrent(),
            .source_error, .dedicated_failure => {
                // candidate() already chose the failure branch; let fail() own
                // its task creation without changing which mode was selected.
                self.load.phase = .selecting;
                self.fail();
            },
        }
    }
    fn fetchCurrent(self: *InternalState) !void {
        const instance = self.activity.instance orelse return;
        var cors = try get_crossOrigin(instance);
        defer if (cors) |*value| value.deinit(instance.ctx.allocator);
        const setting = html.script_request.corsSettingFromAttribute(if (cors) |value| value.asSlice() else null);
        const destination: @import("fetch").internal.Destination = if (std.mem.eql(u8, instance.vtable.name, "HTMLAudioElement")) .audio else .video;
        const request = try common.requestFor(instance, self.load.currentSrc(), destination, setting);
        self.fetch_document = if (common.documentOf(instance)) |document| same_object.Link.to(document) else null;
        self.activity.fetching = true;
        self.activity.sync();
        self.resource.start(request) catch {
            self.fail();
            return;
        };
        try self.armProgress();
        try self.armStall();
    }
    fn queueRead(context: *anyopaque) void {
        const self: *InternalState = @ptrCast(@alignCast(context));
        if (self.read_queued or self.activity.instance == null) return;
        self.read_queued = true;
        _ = self.queue(.read, null, null) catch self.cancel();
    }
    fn read(self: *InternalState) !void {
        while (try self.resource.next()) |piece| {
            switch (piece) {
                .headers => |response| {
                    if (response.response_type == .@"error" or response.status < 200 or response.status >= 300) {
                        self.fail();
                        return;
                    }
                    const mime = (try @import("fetch").internal.mime.extractMimeEssence(self.load.allocator, &response.header_list)) orelse try self.load.allocator.dupe(u8, "");
                    defer self.load.allocator.free(mime);
                    self.decoder = try common.forRealm(self.activity.instance.?.ctx).open(self.load.allocator, mime);
                },
                .bytes => |bytes| {
                    if (bytes.len != 0) {
                        self.progress.received();
                        try self.armStall();
                    }
                    if (self.decoder) |decoder| if (try self.decoded(decoder.push(bytes, false), false)) return;
                },
                .eof => {
                    if (self.decoder) |decoder| if (try self.decoded(decoder.push("", true), true)) return;
                    if (self.load.ready == .nothing) {
                        self.fail();
                        return;
                    }
                    // "Once the entire media resource has been fetched (but
                    // potentially before any of it has been decoded)": fire
                    // progress, then set networkState to NETWORK_IDLE and fire
                    // suspend (4.8.11.5, the media data processing steps). A
                    // body that arrives before the 350ms progress timer first
                    // fires gets its progress here. networkState is already
                    // NETWORK_IDLE when progress dispatches, as in Chrome and
                    // Safari (networkState_during_progress.html: Chrome 2/4,
                    // Safari 2/4, Firefox 4/4 on wpt.fyi, 2026-10-09).
                    try self.event("progress");
                    self.load.suspendFetch(self.load.generation);
                    self.syncDelay();
                    try self.event("suspend");
                    self.finish(self.load.generation);
                    return;
                },
                .failed => {
                    self.fail();
                    return;
                },
            }
        }
    }
    /// Media data processing for one decoder answer; `end_of_stream` says it
    /// answered the last push. True when the resource failed.
    fn decoded(self: *InternalState, result: backend.Result, end_of_stream: bool) !bool {
        switch (result) {
            .unsupported, .decode_error => {
                // Before metadata the resource is unusable: the candidate
                // fails (the dedicated failure, or the next source). After
                // it, this is the fatal decode error steps (MEDIA_ERR_DECODE),
                // never a network error.
                if (self.load.ready == .nothing) self.fail() else self.fatal(.fatal_decode);
                return true;
            },
            .need_more => {},
            .metadata, .current_data => |metadata| {
                // The duration first, then the ready state (processing steps:
                // durationchange is queued before loadedmetadata).
                if (self.load.setDuration(metadata.duration)) try self.event("durationchange");
                const data_kind: LoadState.Data = if (result == .current_data) .current_data else .metadata;
                const reported: backend.VideoSize = .{ .width = metadata.width, .height = metadata.height };
                const change = self.load.decoderData(self.load.generation, data_kind, end_of_stream, self.looping()) orelse {
                    self.followSize(reported);
                    return false;
                };
                if (change.loadedmetadata) try self.metadataSize(reported) else self.followSize(reported);
                try self.readyChanged(change);
            },
        }
        return false;
    }

    fn isVideo(self: *InternalState) bool {
        const instance = self.activity.instance orelse return false;
        return std.mem.eql(u8, instance.vtable.name, "HTMLVideoElement");
    }

    /// The size of the frame at the current playback position: what the
    /// decoder knows of it, else what its last answer reported.
    fn frameSize(self: *InternalState, reported: ?backend.VideoSize) ?backend.VideoSize {
        if (self.decoder) |decoder| if (decoder.videoSizeAt(self.load.position)) |size| return size;
        const size = reported orelse return null;
        if (size.width == 0 and size.height == 0) return null;
        return size;
    }

    /// Media data processing, "once enough of the media data has been
    /// fetched to determine the duration of the media resource and its
    /// dimensions", step 5 (4.8.11.5): "For video elements, set the
    /// videoWidth and videoHeight attributes, and queue a media element
    /// task given the media element to fire an event named resize at the
    /// media element." Between durationchange and loadedmetadata.
    /// Deviation: only when the resource has video, as Gecko does
    /// (HTMLMediaElement::MetadataLoaded: `if (IsVideo() && HasVideo())
    /// QueueEvent(u"resize")`) and Chromium does (WebMediaPlayerImpl reports
    /// a natural size, so HTMLMediaElement::SizeChanged fires resize, only for
    /// a pipeline with video): an audio resource in a video element fires none.
    fn metadataSize(self: *InternalState, reported: backend.VideoSize) !void {
        if (!self.isVideo()) return;
        const size = self.frameSize(reported) orelse {
            self.video_size = .{ .width = 0, .height = 0 };
            return;
        };
        self.video_size = size;
        try self.event("resize");
    }

    /// HTML 4.8.8: "Whenever the natural width or natural height of the
    /// video changes ..., if the element's readyState attribute is not
    /// HAVE_NOTHING, the user agent must queue a media element task given the
    /// media element to fire an event named resize at the media element."
    /// Fired only on a real change (Gecko HTMLMediaElement::UpdateMediaSize
    /// compares with the size it holds). A position whose size the decoder
    /// does not know keeps the last one.
    fn followSize(self: *InternalState, reported: ?backend.VideoSize) void {
        if (!self.isVideo() or self.load.ready == .nothing) return;
        const size = self.frameSize(reported) orelse return;
        if (size.width == self.video_size.width and size.height == self.video_size.height) return;
        self.video_size = size;
        self.event("resize") catch self.cancel();
    }

    /// Queue what a ready-state change asks (4.8.11.7), in its order.
    fn readyChanged(self: *InternalState, change: LoadState.ReadyChange) !void {
        if (change.loadedmetadata) try self.event("loadedmetadata");
        if (change.loadeddata) {
            self.syncDelay();
            try self.event("loadeddata");
        }
        if (change.timeupdate_waiting) {
            try self.event("timeupdate");
            try self.event("waiting");
        }
        if (change.canplay) try self.event("canplay");
        if (change.notify_playing) try self.notifyPlaying();
        if (change.canplaythrough) {
            try self.event("canplaythrough");
            try self.autoplay();
        }
        self.syncClock();
    }

    /// The autoplay substeps after canplaythrough (4.8.11.7; LoadState.autoplay
    /// numbers them). "Eligible for autoplay": the model checks the can
    /// autoplay flag and paused; here, the autoplay attribute, that the node
    /// document's active sandboxing flag set lacks the sandboxed automatic
    /// features flag (set by a sandbox without allow-scripts), and that the
    /// document is allowed to use the "autoplay" feature. The lazy loading
    /// condition always holds: Crane loads every media element eagerly.
    fn autoplay(self: *InternalState) !void {
        const instance = self.activity.instance orelse return;
        if (!(try interfaces.Element.call_hasAttribute(instance, .initInterned("autoplay")))) return;
        if (automaticFeaturesSandboxed(instance)) return;
        // TODO(permissions-policy): "allowed to use" the "autoplay" feature
        // (default allowlist 'self'). No document carries a permissions policy
        // yet (src/html/permissions_policy.zig is not delivered), so every
        // document is allowed, as a top-level or same-origin one is.
        const steps = self.load.autoplay() orelse return;
        // Step 2's time marches on has nothing to do yet: Crane does not
        // process text track cues there (a follow-up), and outside normal
        // playback it fires no timeupdate.
        _ = steps.time_marches_on;
        if (steps.play_event) try self.event("play");
        if (steps.notify_playing) try self.notifyPlaying();
    }

    /// The official playback position, just set, stays until the next stable
    /// state: script reading currentTime in this task sees it.
    fn holdOfficial(self: *InternalState) void {
        self.official_fresh = true;
        if (self.activity.hasStableFor(self.load.generation, clearOfficial)) return;
        self.activity.stable(self.load.generation, clearOfficial) catch {
            self.official_fresh = false;
        };
    }

    /// Notify about playing: take the pending play promises; a task fires
    /// playing, then resolves them.
    fn notifyPlaying(self: *InternalState) !void {
        try self.activity.queueResolve(@intFromEnum(Kind.playing), self.load.generation, "playing", &self.pending_play);
    }

    fn looping(self: *InternalState) bool {
        const instance = self.activity.instance orelse return false;
        return interfaces.Element.call_hasAttribute(instance, .initInterned("loop")) catch false;
    }

    // ------------------------------------------------------------------
    // The media timeline's clock (4.8.11.8)
    // ------------------------------------------------------------------

    /// Move the current playback position to now, if potentially playing.
    fn advanceClock(self: *InternalState) void {
        const anchor = self.clock_anchor orelse return;
        const now = clock.monotonicNanos();
        self.clock_anchor = now;
        const elapsed = @as(f64, @floatFromInt(now - anchor)) / std.time.ns_per_s;
        switch (self.load.advance(elapsed, self.looping())) {
            .none => {},
            .end => self.reachedEnd(),
            // Playing backwards to the start: a timeupdate task only.
            .start => {
                self.load.official_position = self.load.position;
                self.event("timeupdate") catch self.cancel();
                self.syncClock();
            },
        }
    }

    /// Start or stop the clock to match "potentially playing".
    fn syncClock(self: *InternalState) void {
        const playing = self.load.potentiallyPlaying(self.looping());
        if (playing) {
            if (self.clock_anchor == null) self.clock_anchor = clock.monotonicNanos();
            if (!self.clock_timer.pending()) self.armClock() catch self.cancel();
        } else {
            self.clock_anchor = null;
            self.clock_timer.cancel();
        }
        if (self.activity.playing != playing) {
            self.activity.playing = playing;
            // While it plays, the element is in its agent's live registry,
            // as while it fetches: unloading and discarding its document
            // cancel it (cancelRealm), stopping the clock and its timer.
            if (playing) {
                self.register() catch self.cancel();
            } else if (!self.activity.fetching) self.unregister();
            self.activity.sync();
        }
    }

    fn stopClock(self: *InternalState) void {
        self.clock_anchor = null;
        self.clock_timer.cancel();
        if (self.activity.playing) {
            self.activity.playing = false;
            self.activity.sync();
        }
    }

    /// The next "time marches on": 250ms from now, or sooner if the end of
    /// the media resource comes first.
    fn armClock(self: *InternalState) !void {
        const instance = self.activity.instance orelse return;
        const timer = instance.ctx.getOptionalTimer() orelse return;
        var delay = timeupdate_interval_ms;
        const rate = self.load.playback_rate;
        if (rate > 0 and !std.math.isNan(self.load.duration)) {
            const remaining_ms = (self.load.duration - self.load.position) / rate * std.time.ms_per_s;
            if (remaining_ms < @as(f64, @floatFromInt(delay))) delay = @intFromFloat(@max(0, @ceil(remaining_ms)));
        }
        try self.clock_timer.start(self.load.allocator, timer, delay, clockDue, self);
    }

    fn clockDue(context: *anyopaque) void {
        const self: *InternalState = @ptrCast(@alignCast(context));
        if (self.activity.instance == null) return;
        self.advanceClock();
        // The frame at the new position may have another size.
        self.followSize(null);
        if (!self.load.potentiallyPlaying(self.looping())) return;
        // Time marches on, during normal playback: timeupdate.
        self.load.official_position = self.load.position;
        self.event("timeupdate") catch {
            self.cancel();
            return;
        };
        self.armClock() catch self.cancel();
    }

    /// "When the current playback position reaches the end of the media
    /// resource when the direction of playback is forwards" (4.8.11.8).
    fn reachedEnd(self: *InternalState) void {
        self.load.official_position = self.load.position;
        // Step 1: a loop attribute seeks to the earliest possible position.
        if (self.looping()) {
            self.seek(0) catch self.cancel();
            return;
        }
        // No more data in the direction of playback: HAVE_CURRENT_DATA, which
        // queues nothing since playback has ended.
        _ = self.load.changeReady(self.load.readyNow(false), false);
        self.syncClock();
        // Step 3: the task that fires timeupdate, pauses, and fires ended.
        self.queue(.reached_end, null, null) catch self.cancel();
    }

    // ------------------------------------------------------------------
    // Seeking (4.8.11.9)
    // ------------------------------------------------------------------

    /// The seek algorithm, to `target`. Every byte of the resource is held,
    /// so the data for any position is available at once (step 12).
    fn seek(self: *InternalState, target: f64) !void {
        // Steps 2-11: nothing with no resource; the position moves now.
        self.advanceClock();
        _ = self.load.beginSeek(target) orelse return;
        self.holdOfficial();
        try self.seekInParallel();
    }

    /// Seek steps 10-13, once the position is set.
    fn seekInParallel(self: *InternalState) !void {
        try self.event("seeking");
        // The data at the new position decides the ready state (HAVE_ENOUGH_DATA
        // again after the end, for a resource fully held).
        try self.readyChanged(self.load.changeReady(self.load.readyNow(self.looping()), self.looping()));
        // Step 13: await a stable state.
        try self.activity.stable(self.load.generation, seekStable);
    }
};

fn seekStable(context: *anyopaque, generation: u64) void {
    const self: *InternalState = @ptrCast(@alignCast(context));
    if (generation != self.load.generation) return;
    // Step 14: only the newest seek finishes.
    if (!self.load.finishSeek(self.load.seek_id)) return;
    // The frame at the new position may have another size.
    self.followSize(null);
    // Steps 16-17: timeupdate, then seeked.
    self.event("timeupdate") catch {
        self.cancel();
        return;
    };
    self.event("seeked") catch self.cancel();
    self.syncClock();
}

fn clearOfficial(context: *anyopaque, _: u64) void {
    const self: *InternalState = @ptrCast(@alignCast(context));
    self.official_fresh = false;
}

fn data(instance: *runtime.Instance) *InternalState {
    return instance.getState(State).own._internal.?;
}
fn abortOwner(context: *anyopaque) void {
    const self: *InternalState = @ptrCast(@alignCast(context));
    self.cancel();
}
fn freeOwner(context: *anyopaque) void {
    const self: *InternalState = @ptrCast(@alignCast(context));
    self.resource.stop();
    self.load.deinit();
    if (self.src_url) |url| self.load.allocator.free(url);
    self.pending_play.deinit(self.load.allocator);
    self.activity.microtasks.deinit(self.load.allocator);
    self.load.allocator.destroy(self);
}
pub fn init(allocator: std.mem.Allocator, comptime StateType: type, vtable: *const runtime.VTable, ctx: runtime.Context) !*runtime.Instance {
    const instance = try interfaces.HTMLElement.initWithState(allocator, StateType, vtable, ctx);
    instance.getState(State).own._internal = null;
    errdefer instance.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(instance));
    const self = try allocator.create(InternalState);
    self.* = .{ .activity = .{ .allocator = allocator, .instance = instance, .owner = self, .run = runTask, .abort = abortOwner, .free = freeOwner }, .resource = .{ .allocator = allocator, .ctx = ctx, .owner = self, .notify = InternalState.queueRead }, .load = LoadState.init(allocator) };
    instance.getState(State).own._internal = self;
    return instance;
}
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |self| {
        state.own._internal = null;
        self.cancel();
        self.object_edge.release(instance);
        self.error_edge.release(instance);
        if (self.text_tracks) |list| self.tracks_keep.release(list, severList);
        self.activity.detach();
        self.activity.maybeFree();
    }
    interfaces.HTMLElement.deinit(instance);
}
pub fn installHooks() void {
    dom.attribute_change_steps.install("audio", attributeChanged);
    dom.attribute_change_steps.install("video", attributeChanged);
    dom.media_elements.installMediaElement(delaysLoad, trackParentChanged, trackModeChanged, naturalSize);
    dom.mutation.registerInsertionStepsCallback(inserted) catch @panic("media insertion hook allocation");
    dom.mutation.registerRemovingStepsCallback(removed) catch @panic("media removing hook allocation");
    dom.document_fetches.install(.{ .discard = cancelRealm, .prepare_abort = prepareDocumentAbort, .abort = abortDocument });
    dom.unloading_cleanup.install(cancelRealm);
}
fn cancelRealm(ctx: runtime.Context) void {
    const registry = common.liveRegistry(ctx) orelse return;
    var index = registry.entries.len;
    while (index > 0) {
        index -= 1;
        if (index >= registry.entries.len) continue;
        const entry = registry.entries.get(index).?;
        if (entry.realm != @as(*anyopaque, @ptrCast(ctx))) continue;
        const instance: *runtime.Instance = @ptrCast(@alignCast(entry.instance));
        if (common.isMedia(instance)) data(instance).cancel();
    }
}
fn prepareDocumentAbort(document: *runtime.Instance) bool {
    const registry = common.liveRegistry(document.ctx) orelse return false;
    var canceled = false;
    for (registry.entries.toSlice()) |entry| {
        const instance: *runtime.Instance = @ptrCast(@alignCast(entry.instance));
        if (!common.isMedia(instance)) continue;
        const self = data(instance);
        const link = self.fetch_document orelse continue;
        if (!self.activity.fetching or link.instance != document or !link.isLive()) continue;
        self.document_abort_pending = self.load.generation;
        canceled = true;
    }
    return canceled;
}
fn abortDocument(document: *runtime.Instance) void {
    const registry = common.liveRegistry(document.ctx) orelse return;
    while (true) {
        const self: *InternalState = blk: {
            for (registry.entries.toSlice()) |entry| {
                const instance: *runtime.Instance = @ptrCast(@alignCast(entry.instance));
                if (!common.isMedia(instance)) continue;
                const candidate = data(instance);
                const link = candidate.fetch_document orelse continue;
                if (candidate.document_abort_pending != null and link.instance == document and link.isLive()) break :blk candidate;
            }
            return;
        };
        const generation = self.document_abort_pending.?;
        self.document_abort_pending = null;
        if (generation != self.load.generation or !self.activity.fetching) continue;
        const instance = self.activity.instance orelse continue;
        engine.runInRealm(instance.ctx, documentAbortSteps, self) catch self.cancel();
    }
}
fn documentAbortSteps(context: ?*anyopaque) void {
    const self: *InternalState = @ptrCast(@alignCast(context.?));
    const instance = self.activity.instance orelse return;
    // User-aborted media fetching, steps 1–6. Only resource tasks are
    // invalidated; text-track list notifications are independent of this load.
    var task = self.activity.head;
    while (task) |pending| : (task = pending.next) {
        if (pending.resource_bound) pending.cancelled = true;
    }
    self.endFetch();
    self.load.cancel();
    self.load.error_code = .aborted;
    self.load.phase = .failed;
    const object = hooks.createError(instance.ctx, .aborted) catch {
        self.cancel();
        return;
    };
    self.error_object = object;
    self.error_edge.hold(instance, object);
    self.event("abort") catch {
        self.cancel();
        return;
    };
    if (self.load.ready == .nothing) {
        self.load.network = .empty;
        self.load.show_poster = true;
        self.event("emptied") catch {
            self.cancel();
            return;
        };
    } else self.load.network = .idle;
    self.unregister();
    self.syncDelay();
    self.activity.sync();
}
/// The video's natural size, for HTMLVideoElement's videoWidth and
/// videoHeight (dom.media_elements.videoSize).
fn naturalSize(instance: *runtime.Instance) dom.media_elements.VideoSize {
    const self = instance.getState(State).own._internal orelse return .{};
    return .{ .width = self.video_size.width, .height = self.video_size.height };
}
/// Whether the element's node document's active sandboxing flag set has the
/// sandboxed automatic features browsing context flag: its navigable is
/// sandboxed without allow-scripts (HTML 7.1.5, "parse a sandboxing
/// directive": the sandboxed automatic features browsing context flag,
/// "unless tokens contains the allow-scripts keyword"). Document.zig's
/// automaticFeaturesSandboxed reads it the same way for meta refresh.
/// Also the CSP-derived sandboxing flags (HTML 7.1.5, "the CSP-derived
/// sandboxing flags" of a response; CSP 3 6.3.2 sandbox): an enforced
/// sandbox directive without allow-scripts sets the flag - the document's
/// active sandboxing flag set is not recorded, so its policy container is
/// read (content-security-policy/sandbox/autoplay-disabled-by-csp.html;
/// Chrome, Firefox and Safari block that autoplay).
fn automaticFeaturesSandboxed(instance: *runtime.Instance) bool {
    const document = common.documentOf(instance) orelse return false;
    if (dom.policy_containers.of(document)) |container| for (container.csp_list.policies.items) |*policy| {
        if (policy.disposition != .enforce) continue;
        const directive = policy.getDirective("sandbox") orelse continue;
        const allows_scripts = for (directive.value.expressions.items) |token| {
            if (std.ascii.eqlIgnoreCase(token.raw_value, "allow-scripts")) break true;
        } else false;
        if (!allows_scripts) return true;
    };
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse return false;
    const browsing_context = @import("html_core").window.BrowsingContext.ofWindow(@ptrCast(window)) orelse return false;
    return !browsing_context.allowsScripts();
}
fn delaysLoad(document: *runtime.Instance) bool {
    const registry = common.liveRegistry(document.ctx) orelse return false;
    for (registry.entries.toSlice()) |entry| {
        const instance: *runtime.Instance = @ptrCast(@alignCast(entry.instance));
        if (common.isMedia(instance) and common.documentOf(instance) == document and data(instance).load.delaying_load_event) return true;
    }
    return false;
}
fn attributeChanged(instance: *runtime.Instance, name: []const u8, _: ?[]const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    if (namespace != null or !std.mem.eql(u8, name, "src") or value == null) return;
    const self = data(instance);
    const url = if (value.?.len != 0) html.encoding_parse.encodingParseAndSerialize(instance, value.?) catch null else null;
    if (self.src_url) |old| self.load.allocator.free(old);
    self.src_url = url;
    call_load(instance) catch self.cancel();
}
fn child(instance: *runtime.Instance, first: bool) ?*runtime.Instance {
    return if (first) interfaces.Node.get_firstChild(instance) catch null else interfaces.Node.get_nextSibling(instance) catch null;
}
fn parent(instance: *runtime.Instance) ?*runtime.Instance {
    return interfaces.Node.get_parentNode(instance) catch null;
}
fn isSource(instance: *runtime.Instance) bool {
    return std.mem.eql(u8, instance.vtable.name, "HTMLSourceElement");
}
fn firstSource(instance: *runtime.Instance) ?*runtime.Instance {
    var cursor = child(instance, true);
    while (cursor) |node| : (cursor = child(node, false)) if (isSource(node)) return node;
    return null;
}
fn setCursor(self: *InternalState, before: ?*runtime.Instance, after: ?*runtime.Instance) void {
    self.before = if (before) |node| same_object.Link.to(node) else null;
    self.after = if (after) |node| same_object.Link.to(node) else null;
    const instance = self.activity.instance orelse return;
    if (before) |node| engine.traceChild(instance, node, .{ .name = "sourceBefore" }) else engine.forgetTracedChild(instance, .{ .name = "sourceBefore" });
    if (after) |node| engine.traceChild(instance, node, .{ .name = "sourceAfter" }) else engine.forgetTracedChild(instance, .{ .name = "sourceAfter" });
}
fn nextSource(self: *InternalState) ?*runtime.Instance {
    const instance = self.activity.instance orelse return null;
    var cursor = if (self.before) |link| (if (link.isLive() and parent(link.instance) == instance) child(link.instance, false) else child(instance, true)) else child(instance, true);
    while (cursor) |node| : (cursor = child(node, false)) {
        setCursor(self, node, child(node, false));
        if (isSource(node)) return node;
    }
    return null;
}
fn inserted(node: *dom.NodeBase) void {
    const instance = dom.instance_bridge.getInstanceTyped(runtime.Instance, node) orelse return;
    if (common.isMedia(instance)) {
        if (data(instance).load.network == .empty) data(instance).selectLater() catch data(instance).cancel();
        return;
    }
    const owner = parent(instance) orelse return;
    if (!common.isMedia(owner)) return;
    const self = data(owner);
    if (self.load.mode == .children) {
        const before = if (self.before) |link| (if (link.isLive()) link.instance else null) else null;
        if ((interfaces.Node.get_previousSibling(instance) catch null) == before) setCursor(self, before, instance);
    }
    if (!isSource(instance)) return;
    if (self.load.network == .empty) self.selectLater() catch self.cancel() else if (self.load.phase == .waiting) self.resumeSelection() catch self.cancel();
}
fn removed(node: *dom.NodeBase, old_parent: ?*dom.NodeBase) void {
    const instance = dom.instance_bridge.getInstanceTyped(runtime.Instance, node) orelse return;
    if (common.isMedia(instance)) {
        data(instance).cancel();
        return;
    }
    const old = old_parent orelse return;
    const owner = dom.instance_bridge.getInstanceTyped(runtime.Instance, old) orelse return;
    if (!common.isMedia(owner)) return;
    const self = data(owner);
    if (self.before) |link| if (link.instance == instance) {
        const after = if (self.after) |a| (if (a.isLive() and parent(a.instance) == owner) a.instance else null) else null;
        const before = if (after) |a| interfaces.Node.get_previousSibling(a) catch null else interfaces.Node.get_lastChild(owner) catch null;
        setCursor(self, before, after);
        return;
    };
    if (self.after) |link| if (link.instance == instance) {
        const before = if (self.before) |b| (if (b.isLive()) b.instance else null) else null;
        setCursor(self, before, if (before) |b| child(b, false) else child(owner, true));
    };
}
fn stable(context: *anyopaque, generation: u64) void {
    const self: *InternalState = @ptrCast(@alignCast(context));
    if (generation != self.load.generation) return;
    selection(self) catch self.cancel();
}
fn selection(self: *InternalState) !void {
    const instance = self.activity.instance orelse return;
    const generation = self.load.generation;
    if (self.load.phase == .stable_state) {
        const mode = self.load.select(generation, .{ .provider_object = self.src_object != null, .src_attribute = try interfaces.Element.call_hasAttribute(instance, .initInterned("src")), .source_child = firstSource(instance) != null }, true) orelse return;
        self.syncDelay();
        if (mode == .none) {
            self.finish(generation);
            return;
        }
        try self.event("loadstart");
        switch (mode) {
            .object => {
                self.fail();
                return;
            },
            .attribute => {
                try self.candidateResult(try self.load.candidate(generation, .{ .url = self.src_url }));
                return;
            },
            .children => setCursor(self, null, child(instance, true)),
            .none => unreachable,
        }
    }
    if (self.load.mode != .children) return;
    const candidate = nextSource(self);
    if (self.load.phase == .next_candidate or self.load.phase == .waiting) {
        _ = self.load.nextCandidate(generation, candidate != null, true);
        self.syncDelay();
    } else if (candidate == null) {
        self.load.phase = .next_candidate;
        _ = self.load.nextCandidate(generation, false, true);
    }
    const source = candidate orelse {
        _ = try self.queue(.release_delay, null, null);
        return;
    };
    self.candidate = same_object.Link.to(source);
    engine.traceChild(instance, source, .{ .name = "sourceCandidate" });
    var type_value = try interfaces.HTMLSourceElement.get_type(source);
    defer type_value.deinit(source.ctx.allocator);
    var unsupported = false;
    if (try @import("mimesniff").parseMimeType(self.load.allocator, type_value.asSlice())) |parsed| {
        var mime = parsed;
        defer mime.deinit();
        unsupported = (try call_canPlayType(instance, type_value)) == .__;
    }
    var media = try interfaces.HTMLSourceElement.get_media(source);
    defer media.deinit(source.ctx.allocator);
    var matches = true;
    if (media.len() != 0) if (common.globalOf(instance.ctx)) |window| {
        const query = try interfaces.Window.call_matchMedia(window, media);
        defer query.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(query));
        matches = try interfaces.MediaQueryList.get_matches(query);
    };
    try self.candidateResult(try self.load.candidate(generation, .{ .url = hooks.sourceURL(source), .media_matches = matches, .known_unsupported_type = unsupported }));
}
fn runTask(context: *anyopaque, task: *common.Task) void {
    const self: *InternalState = @ptrCast(@alignCast(context));
    const kind: Kind = @enumFromInt(task.kind);
    // Track list membership is independent of the current media resource.
    if (kind == .track_event) {
        if (task.event) |event| event.dispatch();
        return;
    }
    if (kind == .select_tracks) {
        selectTracks(self) catch {};
        return;
    }
    if (kind == .track_change) {
        self.tracks.takeChange();
        if (task.event) |event| event.dispatch();
        return;
    }
    if (task.generation != self.load.generation) return;
    const instance = self.activity.instance orelse return;
    switch (kind) {
        .track_event, .select_tracks, .track_change => unreachable,
        .progress_tick => {
            if (self.activity.fetching and self.progress.takeProgress()) {
                self.load.stalled = false;
                if (task.event) |event| event.dispatch();
            }
        },
        .stalled => {
            if (self.activity.fetching and self.progress.takeStalled()) {
                self.load.stalled = true;
                if (task.event) |event| event.dispatch();
            }
        },
        .fatal_network, .fatal_decode => {
            const code: hooks.ErrorCode = if (kind == .fatal_network) .network else .decode;
            self.load.fatalFailure(task.generation, if (kind == .fatal_network) .network else .decode);
            self.syncDelay();
            const object = hooks.createError(instance.ctx, code) catch {
                self.cancel();
                return;
            };
            self.error_object = object;
            self.error_edge.hold(instance, object);
            if (task.event) |event| event.dispatch();
            self.finish(task.generation);
        },
        .event => if (task.event) |event| event.dispatch(),
        // Resource selection's synchronous section (awaitSelection).
        .select => {
            // Running: no longer pending (awaitSelection's scan).
            task.cancelled = true;
            selection(self) catch self.cancel();
        },
        .read => {
            self.read_queued = false;
            self.read() catch self.fail();
        },
        .failure => {
            if (!self.load.runDedicatedFailure(task.generation)) return;
            const error_object = hooks.createError(instance.ctx, .source_not_supported) catch {
                self.cancel();
                return;
            };
            self.error_object = error_object;
            self.error_edge.hold(instance, error_object);
            if (task.event) |event| event.dispatch();
            task.rejectPromises("NotSupportedError");
            self.finish(task.generation);
        },
        .next_source => {
            if (task.event) |event| event.dispatch();
            if (task.generation == self.load.generation) {
                // Children steps 10–11: the error task kept the failed source
                // through script; selection now needs only its list position.
                // A removed candidate must not stay alive while we wait.
                self.candidate = null;
                engine.forgetTracedChild(instance, .{ .name = "sourceCandidate" });
                // With an event loop, fail() queued the selection task already.
                if (!self.hasEventLoop()) self.awaitSelection(task.generation) catch self.cancel();
            }
        },
        .release_delay => {
            // Children step 20 changes only the delay flag. A new source may
            // have resumed this generation before the queued task runs; it
            // must not terminate that fetch or remove its live registration.
            self.load.endLoadDelay(task.generation);
            self.syncDelay();
            if (self.load.phase == .waiting and !self.activity.fetching) self.unregister();
            self.activity.sync();
        },
        .pause => {
            // Internal pause steps 2.3: timeupdate, pause, then the promises'
            // rejection - one task.
            fire(instance, "timeupdate");
            if (task.event) |event| event.dispatch();
            task.rejectPromises("AbortError");
        },
        .playing => {
            // Notify about playing, step 2: playing, then resolve.
            if (task.event) |event| event.dispatch();
            task.resolvePromises();
        },
        .resolve_play => task.resolvePromises(),
        .reached_end => {
            // Reaching the end, step 3.
            fire(instance, "timeupdate");
            if (self.load.endedPlayback(self.looping()) and self.load.playback_rate >= 0 and !self.load.paused) {
                self.load.paused = true;
                self.syncClock();
                fire(instance, "pause");
                rejectPending(self, "AbortError") catch {};
            }
            fire(instance, "ended");
        },
    }
}

/// Fire a trusted event made now, inside a running task.
fn fire(instance: *runtime.Instance, name: []const u8) void {
    const event = common.Event.init(instance, name) catch return;
    defer event.deinit();
    event.dispatch();
}

pub fn call_load(instance: *runtime.Instance) anyerror!void {
    const self = data(instance);
    self.stopClock();
    self.official_fresh = false;
    // Load steps 1–5: settle queued play outcomes before invalidating tasks.
    self.activity.discardTasks(true);
    self.endFetch();
    self.unregister();
    const reset = self.load.beginLoad();
    self.syncDelay();
    self.error_object = null;
    self.error_edge.release(instance);
    setCursor(self, null, null);
    self.candidate = null;
    engine.forgetTracedChild(instance, .{ .name = "sourceCandidate" });
    // Steps 6–10: old resource event order, then the stable selection section.
    if (reset.queue_abort) try self.event("abort");
    if (reset.queue_emptied) try self.event("emptied");
    if (reset.reject_play_with_abort) try rejectPending(self, "AbortError");
    if (reset.queue_timeupdate) try self.event("timeupdate");
    if (reset.queue_ratechange) try self.event("ratechange");
    try self.register();
    self.delayUntilSelection();
    try self.awaitSelection(reset.generation);
}
fn rejectPending(self: *InternalState, name: []const u8) !void {
    const exception = try engine.createDOMException(self.activity.instance.?.ctx, name, "");
    defer exception.release();
    for (self.pending_play.items) |*promise| {
        engine.rejectPromise(promise, exception.value) catch {};
        engine.releasePromiseCapability(promise);
    }
    self.pending_play.clearRetainingCapacity();
}
pub fn call_play(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const self = data(instance);
    // Step 2: the dedicated media source failure steps ran.
    if (self.load.error_code == .source_not_supported) {
        const exception = try engine.createDOMException(instance.ctx, "NotSupportedError", "");
        defer exception.release();
        return (try engine.createRejectedPromise(instance.ctx, exception.value)).take();
    }
    // Step 5: a new promise in the list of pending play promises.
    var promise = try engine.createPromise(instance.ctx);
    errdefer engine.releasePromiseCapability(&promise);
    const result = try engine.retainValue(instance.ctx, promise.promise);
    errdefer result.release();
    try self.pending_play.append(self.load.allocator, promise);
    // Step 6: the internal play steps.
    self.advanceClock();
    const loop = self.looping();
    const steps = self.load.play(loop);
    if (steps.select) self.selectLater() catch self.cancel();
    // Step 2's seek sets the position now; the rest of it runs in parallel
    // (seek step 5), so its events and ready-state change follow step 3's.
    if (steps.seek_to_start) {
        _ = self.load.beginSeek(0);
        self.holdOfficial();
    }
    if (steps.play_event) self.event("play") catch self.cancel();
    if (steps.waiting) self.event("waiting") catch self.cancel();
    if (steps.notify_playing) self.notifyPlaying() catch self.cancel();
    if (steps.resolve_pending) self.activity.queueResolve(@intFromEnum(Kind.resolve_play), self.load.generation, null, &self.pending_play) catch self.cancel();
    if (steps.seek_to_start) self.seekInParallel() catch self.cancel();
    self.syncClock();
    return result.take();
}
pub fn call_pause(instance: *runtime.Instance) anyerror!void {
    const self = data(instance);
    if (self.load.network == .empty) try self.selectLater();
    // The current playback position up to now, before it stops moving.
    self.advanceClock();
    if (!self.load.pause()) return;
    self.syncClock();
    // Internal pause steps 2.2-2.3: take the pending play promises; one task
    // fires timeupdate and pause, then rejects them.
    try self.activity.queuePlay(@intFromEnum(Kind.pause), self.load.generation, "pause", &self.pending_play, "AbortError");
}
pub fn call_canPlayType(instance: *runtime.Instance, mime: runtime.DOMString) anyerror!enums.CanPlayTypeResult {
    return switch (common.forRealm(instance.ctx).canPlayType(mime.asSlice())) {
        .unsupported => .__,
        .maybe => ._maybe_,
        .probably => ._probably_,
    };
}
pub fn get_error(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return data(instance).error_object;
}
pub fn get_currentSrc(instance: *runtime.Instance) anyerror!runtime.USVString {
    return instance.ctx.allocator.dupe(u8, data(instance).load.currentSrc());
}
pub fn get_networkState(instance: *runtime.Instance) anyerror!u16 {
    return @intFromEnum(data(instance).load.network);
}
pub fn get_readyState(instance: *runtime.Instance) anyerror!u16 {
    return @intFromEnum(data(instance).load.ready);
}
pub fn get_paused(instance: *runtime.Instance) anyerror!bool {
    return data(instance).load.paused;
}
pub fn get_seeking(instance: *runtime.Instance) anyerror!bool {
    return data(instance).load.seeking;
}
/// True when playback has ended in the forwards direction (4.8.11.8).
pub fn get_ended(instance: *runtime.Instance) anyerror!bool {
    const self = data(instance);
    self.advanceClock();
    return self.load.playback_rate >= 0 and self.load.endedPlayback(self.looping());
}
pub fn get_duration(instance: *runtime.Instance) anyerror!f64 {
    return data(instance).load.duration;
}
/// The official playback position (4.8.11.6), or the default playback start
/// position with no media data. While playing, the official position is the
/// clock's position at the first read in a task, kept until the next stable
/// state, as Chromium does (official_playback_position_needs_update_).
pub fn get_currentTime(instance: *runtime.Instance) anyerror!f64 {
    const self = data(instance);
    const load = &self.load;
    if (load.ready == .nothing) return load.default_start_position;
    if (self.clock_anchor != null and !self.official_fresh) {
        self.advanceClock();
        load.official_position = load.position;
        if (self.clock_anchor != null) self.holdOfficial();
    }
    return load.official_position;
}
/// Setting currentTime: the default playback start position with no media
/// data; otherwise the official playback position, and a seek (4.8.11.6).
pub fn set_currentTime(instance: *runtime.Instance, value: f64) anyerror!void {
    const self = data(instance);
    if (self.load.ready == .nothing) {
        self.load.default_start_position = value;
        return;
    }
    self.load.official_position = value;
    try self.seek(value);
}
pub fn get_buffered(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return interfaces.TimeRanges.init(instance.ctx.allocator, instance.ctx);
}
pub fn get_seekable(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return interfaces.TimeRanges.init(instance.ctx.allocator, instance.ctx);
}
pub fn get_played(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return interfaces.TimeRanges.init(instance.ctx.allocator, instance.ctx);
}
pub fn get_volume(instance: *runtime.Instance) anyerror!f64 {
    return data(instance).volume;
}
pub fn set_volume(instance: *runtime.Instance, value: f64) anyerror!void {
    if (value < 0 or value > 1) return error.IndexSizeError;
    const self = data(instance);
    if (self.volume == value) return;
    self.volume = value;
    try self.event("volumechange");
}
pub fn get_muted(instance: *runtime.Instance) anyerror!bool {
    return data(instance).muted orelse try interfaces.HTMLMediaElement.get_defaultMuted(instance);
}
pub fn set_muted(instance: *runtime.Instance, value: bool) anyerror!void {
    const previous = try get_muted(instance);
    data(instance).muted = value;
    if (previous != value) try data(instance).event("volumechange");
}
pub fn get_defaultPlaybackRate(instance: *runtime.Instance) anyerror!f64 {
    return data(instance).load.default_playback_rate;
}
pub fn set_defaultPlaybackRate(instance: *runtime.Instance, value: f64) anyerror!void {
    if (data(instance).load.default_playback_rate == value) return;
    data(instance).load.default_playback_rate = value;
    try data(instance).event("ratechange");
}
pub fn get_playbackRate(instance: *runtime.Instance) anyerror!f64 {
    return data(instance).load.playback_rate;
}
pub fn set_playbackRate(instance: *runtime.Instance, value: f64) anyerror!void {
    const self = data(instance);
    if (self.load.playback_rate == value) return;
    // The position so far moved at the old rate.
    self.advanceClock();
    self.load.playback_rate = value;
    try self.event("ratechange");
    if (self.clock_anchor != null) {
        // The end comes at another time now.
        self.clock_timer.cancel();
    }
    self.syncClock();
}
pub fn get_preservesPitch(instance: *runtime.Instance) anyerror!bool {
    return data(instance).preserves_pitch;
}
pub fn set_preservesPitch(instance: *runtime.Instance, value: bool) anyerror!void {
    data(instance).preserves_pitch = value;
}
pub fn get_srcObject(instance: *runtime.Instance) anyerror!?typedefs.MediaProvider {
    return data(instance).src_object;
}
pub fn set_srcObject(instance: *runtime.Instance, value: ?typedefs.MediaProvider) anyerror!void {
    const self = data(instance);
    self.src_object = value;
    if (value) |provider| {
        const object = switch (provider) {
            inline else => |object| object,
        };
        self.object_edge.hold(instance, object);
    } else self.object_edge.release(instance);
    try call_load(instance);
}
pub fn get_crossOrigin(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    var value = (try interfaces.Element.call_getAttribute(instance, .initInterned("crossorigin"))) orelse return null;
    defer value.deinit(instance.ctx.allocator);
    return .initInterned(if (std.ascii.eqlIgnoreCase(value.asSlice(), "use-credentials")) "use-credentials" else "anonymous");
}
pub fn set_crossOrigin(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    if (value) |text| try interfaces.Element.call_setAttribute(instance, .initInterned("crossorigin"), .{ .domstring = text }) else try interfaces.Element.call_removeAttribute(instance, .initInterned("crossorigin"));
}
pub fn get_preload(instance: *runtime.Instance) anyerror!runtime.DOMString {
    var value = (try interfaces.Element.call_getAttribute(instance, .initInterned("preload"))) orelse return .initInterned("metadata");
    defer value.deinit(instance.ctx.allocator);
    if (std.ascii.eqlIgnoreCase(value.asSlice(), "none")) return .initInterned("none");
    if (std.ascii.eqlIgnoreCase(value.asSlice(), "metadata")) return .initInterned("metadata");
    return .initInterned("auto");
}
pub fn set_preload(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, .initInterned("preload"), .{ .domstring = value });
}
/// fastSeek: a seek with the approximate-for-speed flag; every position of a
/// held resource is as fast as any other, so it is the exact seek.
pub fn call_fastSeek(instance: *runtime.Instance, time: f64) anyerror!void {
    if (data(instance).load.ready == .nothing) return;
    try data(instance).seek(time);
}

pub fn get_audioTracks(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

pub fn get_videoTracks(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

pub fn get_textTracks(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const self = data(instance);
    if (self.text_tracks == null) {
        const list = try hooks.createTextTrackList(instance.ctx);
        self.text_tracks = list;
        self.tracks_keep.made(list);
    }
    const list = self.text_tracks.?;
    self.tracks_keep.handOut(instance, list, .{ .name = "textTracks" });
    return list;
}

pub fn get_sinkId(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

pub fn get_remote(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

pub fn get_disableRemotePlayback(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

pub fn get_mediaKeys(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

pub fn get_onencrypted(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

pub fn get_onwaitingforkey(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

pub fn set_disableRemotePlayback(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

pub fn set_onencrypted(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

pub fn set_onwaitingforkey(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

pub fn call_setSinkId(instance: *runtime.Instance, sinkId: runtime.DOMString) anyerror!runtime.JSValue {
    _ = instance;
    _ = sinkId;
    return error.NotImplemented;
}

pub fn call_setMediaKeys(instance: *runtime.Instance, mediaKeys: ?*runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    _ = mediaKeys;
    return error.NotImplemented;
}

pub fn call_captureStream(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

pub fn call_getStartDate(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

pub fn call_addTextTrack(instance: *runtime.Instance, kind: enums.TextTrackKind, label: webidl.Opt(runtime.DOMString), language: webidl.Opt(runtime.DOMString)) anyerror!*runtime.Instance {
    _ = instance;
    _ = kind;
    _ = label;
    _ = language;
    return error.NotImplemented;
}

fn severList(_: *runtime.Instance) void {}
fn trackParentChanged(element: *runtime.Instance, old_parent: ?*runtime.Instance, new_parent: ?*runtime.Instance) void {
    const was_media = if (old_parent) |old| common.isMedia(old) else false;
    const is_media = if (new_parent) |new| common.isMedia(new) else false;
    if (!was_media and !is_media) return;
    const track = interfaces.HTMLTrackElement.get_track(element) catch return;
    if (old_parent) |old| if (common.isMedia(old)) {
        const list = get_textTracks(old) catch return;
        hooks.removeTextTrack(list, track);
        if (old.ctx.hasEngine()) data(old).activity.queueTrack(@intFromEnum(Kind.track_event), 0, list, "removetrack", track) catch {};
    };
    if (new_parent) |media| if (common.isMedia(media)) {
        const list = get_textTracks(media) catch return;
        appendInTreeOrder(media, list, track) catch return;
        // Sourcing out-of-band tracks: selection task precedes addtrack.
        if (media.ctx.hasEngine()) {
            data(media).activity.queueIndependent(@intFromEnum(Kind.select_tracks), null, null) catch {};
            data(media).activity.queueTrack(@intFromEnum(Kind.track_event), 0, list, "addtrack", track) catch {};
        }
    };
}
fn appendInTreeOrder(media: *runtime.Instance, list: *runtime.Instance, added: *runtime.Instance) !void {
    // The list starts with child-track order; script-created tracks follow it.
    // Temporary holds protect every existing track across removal of its edge.
    const Held = struct { track: *runtime.Instance, hold: ?engine.Owned };
    var old: std.ArrayList(Held) = .empty;
    defer {
        for (old.items) |item| if (item.hold) |hold| hold.release();
        old.deinit(media.ctx.allocator);
    }
    const length = try interfaces.TextTrackList.get_length(list);
    try old.ensureTotalCapacity(media.ctx.allocator, length);
    for (0..length) |index| {
        const track = try interfaces.TextTrackList.call_getter(list, @intCast(index));
        const hold = if (media.ctx.hasEngine()) try engine.retainValue(media.ctx, .{ .instance = track }) else null;
        old.appendAssumeCapacity(.{ .track = track, .hold = hold });
    }
    for (old.items) |item| hooks.removeTextTrack(list, item.track);
    var cursor = child(media, true);
    while (cursor) |node| : (cursor = child(node, false)) if (std.mem.eql(u8, node.vtable.name, "HTMLTrackElement")) {
        try hooks.appendTextTrack(list, try interfaces.HTMLTrackElement.get_track(node));
    };
    try hooks.appendTextTrack(list, added);
    for (old.items) |item| try hooks.appendTextTrack(list, item.track);
}
fn trackModeChanged(media: *runtime.Instance) void {
    const self = data(media);
    if (!media.ctx.hasEngine()) return;
    const list = get_textTracks(media) catch return;
    // Mode-change steps 1–3: one notification until its task clears the flag.
    if (!self.tracks.requestChange()) return;
    self.activity.queueIndependent(@intFromEnum(Kind.track_change), list, "change") catch {
        self.tracks.takeChange();
    };
}
fn selectTracks(self: *InternalState) !void {
    if (self.tracks.blocked_on_parser or self.tracks.automatic_selected) return;
    const media = self.activity.instance orelse return;
    const list = try get_textTracks(media);
    const length = try interfaces.TextTrackList.get_length(list);
    // Honor user preferences steps 1–2. The host has no preference configured;
    // the spec's default-attribute branch chooses the first disabled default.
    for (0..2) |group| {
        var showing = false;
        for (0..length) |index| {
            const track = try interfaces.TextTrackList.call_getter(list, @intCast(index));
            const kind = try interfaces.TextTrack.get_kind(track);
            const matches = if (group == 0) kind == ._subtitles_ or kind == ._captions_ else kind == ._descriptions_;
            if (matches and (try interfaces.TextTrack.get_mode(track)) == ._showing_) showing = true;
        }
        if (showing) continue;
        var cursor = child(media, true);
        while (cursor) |node| : (cursor = child(node, false)) if (std.mem.eql(u8, node.vtable.name, "HTMLTrackElement")) {
            const track = try interfaces.HTMLTrackElement.get_track(node);
            const kind = try interfaces.TextTrack.get_kind(track);
            const matches = if (group == 0) kind == ._subtitles_ or kind == ._captions_ else kind == ._descriptions_;
            if (matches and (try interfaces.TextTrack.get_mode(track)) == ._disabled_ and (try interfaces.HTMLTrackElement.get_default(node))) {
                try interfaces.TextTrack.set_mode(track, ._showing_);
                break;
            }
        };
    }
    // Step 3: default chapter and metadata tracks are all enabled, hidden.
    var cursor = child(media, true);
    while (cursor) |node| : (cursor = child(node, false)) if (std.mem.eql(u8, node.vtable.name, "HTMLTrackElement")) {
        const track = try interfaces.HTMLTrackElement.get_track(node);
        const kind = try interfaces.TextTrack.get_kind(track);
        if ((kind == ._chapters_ or kind == ._metadata_) and (try interfaces.TextTrack.get_mode(track)) == ._disabled_ and (try interfaces.HTMLTrackElement.get_default(node))) try interfaces.TextTrack.set_mode(track, ._hidden_);
    };
    self.tracks.automatic_selected = true; // Step 4. Parser integration is deferred (Q19).
}
