//! HTML 4.8.11.5 load/resource-selection state, independent of DOM and engines.
//!
//! The owner supplies live DOM candidates and serialized URLs, performs fetch,
//! and queues the events/promise settlements requested here. In particular,
//! source children use a live DOM pointer, not a snapshot kept by this model.
//! Each asynchronous continuation carries its load generation. Calling load
//! again or cancelling makes every older continuation inert.
const std = @import("std");

pub const LoadState = struct {
    pub const Network = enum(u16) { empty = 0, idle = 1, loading = 2, no_source = 3 };
    pub const Ready = enum(u16) { nothing = 0, metadata = 1, current_data = 2, future_data = 3, enough_data = 4 };
    pub const ErrorCode = enum(u16) { aborted = 1, network = 2, decode = 3, source_not_supported = 4 };
    pub const Mode = enum { none, object, attribute, children };
    pub const Phase = enum { idle, stable_state, selecting, fetching, next_candidate, waiting, failure_task, failed };

    /// Presence is distinct from value: an empty src still beats source children.
    pub const Sources = struct {
        provider_object: bool = false,
        src_attribute: bool = false,
        source_child: bool = false,
    };

    /// The owner parses relative to the node document at the last src change.
    /// null denotes a missing/empty src or URL parse failure. A malformed type
    /// is not a known unsupported MIME type; that decision belongs to the parser
    /// and backend, not this state model.
    pub const Candidate = struct {
        url: ?[]const u8 = null,
        media_matches: bool = true,
        known_unsupported_type: bool = false,
    };

    pub const CandidateResult = enum { ignored, fetch, source_error, dedicated_failure };
    pub const NextCandidate = enum { ignored, process, wait };

    /// Instructions to the owner in load-algorithm order. Before acting on these,
    /// settle already-queued play promises and discard old tasks (steps 3–5).
    /// Queue abort, then emptied; stop fetch and forget tracks; reject the
    /// remaining play promises; queue timeupdate, then ratechange. Finally queue
    /// the generation's stable section. Resetting duration queues no event.
    pub const Reset = struct {
        generation: u64,
        queue_abort: bool,
        queue_emptied: bool,
        stop_fetch: bool,
        forget_tracks: bool,
        reject_play_with_abort: bool,
        queue_timeupdate: bool,
        queue_ratechange: bool,
    };

    allocator: std.mem.Allocator,
    current_src: ?[]u8 = null,
    generation: u64 = 0,
    network: Network = .empty,
    ready: Ready = .nothing,
    phase: Phase = .idle,
    mode: Mode = .none,
    error_code: ?ErrorCode = null,
    paused: bool = true,
    seeking: bool = false,
    stalled: bool = false,
    can_autoplay: bool = true,
    show_poster: bool = true,
    delaying_load_event: bool = false,
    position: f64 = 0,
    official_position: f64 = 0,
    default_start_position: f64 = 0,
    duration: f64 = std.math.nan(f64),
    timeline_offset: f64 = std.math.nan(f64),
    playback_rate: f64 = 1,
    default_playback_rate: f64 = 1,
    /// What the decoder has reported for this load: null, metadata, or data
    /// at the current playback position.
    data: ?Data = null,
    /// The decoder had data at the position on the end_of_stream push: every
    /// byte of the resource has arrived, and waiting longer will not get more.
    all_data: bool = false,
    /// loadeddata fires once per load (4.8.11.7, "the first time this occurs
    /// for this media element since the load algorithm was last invoked").
    loadeddata_fired: bool = false,
    /// Fences the seek algorithm: a newer seek aborts an older one (4.8.11.9
    /// step 3).
    seek_id: u64 = 0,

    /// The element owns its selected URL; all other fields are value state.
    pub fn init(allocator: std.mem.Allocator) LoadState {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *LoadState) void {
        self.clearCurrentSrc();
    }

    pub fn currentSrc(self: *const LoadState) []const u8 {
        return self.current_src orelse "";
    }

    /// Load algorithm steps 1–10. The owner settles/discards queued tasks and
    /// performs the returned effects without running script between state steps.
    pub fn beginLoad(self: *LoadState) Reset {
        const nonempty = self.network != .empty;
        var reset: Reset = .{
            .generation = undefined,
            .queue_abort = self.network == .loading or self.network == .idle,
            .queue_emptied = nonempty,
            .stop_fetch = nonempty,
            .forget_tracks = nonempty,
            .reject_play_with_abort = nonempty and !self.paused,
            .queue_timeupdate = nonempty and self.official_position != 0,
            .queue_ratechange = self.playback_rate != self.default_playback_rate,
        };
        // Step 1; beginSelection below invalidates the previous algorithm.
        self.stalled = false;
        if (nonempty) {
            // Steps 7.5–7.10. The default playback start position is separate.
            self.ready = .nothing;
            self.paused = true;
            self.seeking = false;
            self.position = 0;
            self.official_position = 0;
            self.timeline_offset = std.math.nan(f64);
            self.duration = std.math.nan(f64);
        }
        // The previous resource's decoder state goes with it.
        self.data = null;
        self.all_data = false;
        self.loadeddata_fired = false;
        // Steps 8–10. currentSrc remains until an actual candidate is selected.
        self.playback_rate = self.default_playback_rate;
        self.error_code = null;
        self.can_autoplay = true;
        reset.generation = self.beginSelection();
        return reset;
    }

    /// Resource selection steps 1–3. Also used by play/pause or source insertion
    /// when NETWORK_EMPTY, without the reset that an explicit load performs.
    pub fn beginSelection(self: *LoadState) u64 {
        self.generation +%= 1;
        self.delaying_load_event = false;
        self.network = .no_source;
        self.show_poster = true;
        self.mode = .none;
        self.phase = .stable_state;
        return self.generation;
    }

    /// Resource selection's stable section, steps 4–14. The owner populates
    /// pending tracks (step 5) and queues loadstart for every mode except none.
    /// delay_load is true for eager loading or disabled scripting (step 4).
    pub fn select(self: *LoadState, generation: u64, sources: Sources, delay_load: bool) ?Mode {
        if (generation != self.generation or self.phase != .stable_state) return null;
        if (delay_load) self.delaying_load_event = true;
        self.mode = if (sources.provider_object) .object else if (sources.src_attribute) .attribute else if (sources.source_child) .children else .none;
        if (self.mode == .none) {
            // Step 11: no candidate, no loadstart and no error.
            self.network = .empty;
            self.delaying_load_event = false;
            self.phase = .idle;
        } else {
            // Steps 12–14; the object branch's first step clears currentSrc.
            self.network = .loading;
            self.phase = .selecting;
            if (self.mode == .object) {
                self.clearCurrentSrc();
                self.phase = .fetching;
            }
        }
        return self.mode;
    }

    /// Attribute steps 1–5 or children steps 2–9. Validation failures request
    /// events on the correct target; they never fall back from src to children.
    /// On allocation failure the previous URL and selection phase stay intact.
    pub fn candidate(self: *LoadState, generation: u64, input: Candidate) std.mem.Allocator.Error!CandidateResult {
        if (generation != self.generation or self.phase != .selecting) return .ignored;
        std.debug.assert(self.mode == .attribute or self.mode == .children);
        const url = input.url orelse return self.failCandidate(generation);
        if (url.len == 0) return self.failCandidate(generation);
        if (self.mode == .children and (!input.media_matches or input.known_unsupported_type)) return self.failCandidate(generation);
        const owned = try self.allocator.dupe(u8, url);
        self.clearCurrentSrc();
        self.current_src = owned;
        self.phase = .fetching;
        return .fetch;
    }

    /// Initial resource failure, before a usable resource is established. Late
    /// network/decode errors (MEDIA_ERR_NETWORK/DECODE) are separate processing
    /// steps, not a reason to fall back to another source here.
    ///
    /// Object step 4 / attribute step 6: take promises now and queue dedicated
    /// failure. Children steps 10–11: queue source.error, then await stable
    /// state. Only the latter continues searching, leaving media.error null.
    pub fn failCandidate(self: *LoadState, generation: u64) CandidateResult {
        if (generation != self.generation or (self.phase != .selecting and self.phase != .fetching)) return .ignored;
        if (self.mode == .children) {
            self.phase = .next_candidate;
            return .source_error;
        }
        std.debug.assert(self.mode == .attribute or self.mode == .object);
        self.phase = .failure_task;
        return .dedicated_failure;
    }

    /// Children steps 12–26, called in the resumed stable section. The owner
    /// forgets resource-specific tracks and advances the live DOM pointer. A
    /// wait result queues a task calling endLoadDelay (step 20); it does NOT
    /// reject play promises or run dedicated media source failure steps.
    pub fn nextCandidate(self: *LoadState, generation: u64, has_candidate: bool, delay_load: bool) NextCandidate {
        if (generation != self.generation or (self.phase != .next_candidate and self.phase != .waiting)) return .ignored;
        if (self.phase == .waiting) {
            // Steps 24–25, after insertion has resumed the synchronous section.
            if (delay_load) self.delaying_load_event = true;
            self.network = .loading;
        }
        if (has_candidate) {
            self.phase = .selecting;
            return .process;
        }
        // Steps 18–22: keep waiting at the live pointer, possibly forever.
        self.network = .no_source;
        self.show_poster = true;
        self.phase = .waiting;
        return .wait;
    }

    /// Dedicated media source failure steps 1–4, only when its queued task runs.
    /// On true, the owner forgets tracks and fires error, then rejects the saved
    /// promises with NotSupportedError (steps 2, 5–6) and calls endLoadDelay.
    pub fn runDedicatedFailure(self: *LoadState, generation: u64) bool {
        if (generation != self.generation or self.phase != .failure_task) return false;
        self.error_code = .source_not_supported;
        self.network = .no_source;
        self.show_poster = true;
        self.phase = .failed;
        return true;
    }

    /// Dedicated failure step 7 / children step 20. A load from an error handler
    /// must not let an obsolete continuation clear the new load's delay flag.
    pub fn endLoadDelay(self: *LoadState, generation: u64) void {
        if (generation == self.generation) self.delaying_load_event = false;
    }

    /// Abort this selection silently. The owner cancels fetch/decoder activity
    /// and returns pending task holds through their normal run/drop paths.
    pub fn cancel(self: *LoadState) void {
        self.generation +%= 1;
        self.delaying_load_event = false;
        self.phase = .idle;
    }

    /// Resource fetch algorithm's fatal network/decode processing errors.
    /// The owner fires error and notifies the document when the flag clears.
    pub fn fatalFailure(self: *LoadState, generation: u64, code: ErrorCode) void {
        if (generation != self.generation) return;
        self.error_code = code;
        self.network = .idle;
        self.phase = .failed;
        self.delaying_load_event = false;
    }

    /// Resource fetch: suspend fetching, set NETWORK_IDLE and release the delay.
    pub fn suspendFetch(self: *LoadState, generation: u64) void {
        if (generation != self.generation) return;
        self.network = .idle;
        self.delaying_load_event = false;
    }

    /// What a decoder result says (platform.media_backend.Result): metadata
    /// only, or data at the current playback position.
    pub const Data = enum { metadata, current_data };

    /// The events a ready-state change queues, in this order (HTML 4.8.11.7,
    /// "When the ready state of a media element whose networkState is not
    /// NETWORK_EMPTY changes"). `notify_playing` is "notify about playing";
    /// `timeupdate_waiting` queues timeupdate, then waiting.
    pub const ReadyChange = struct {
        loadedmetadata: bool = false,
        loadeddata: bool = false,
        timeupdate_waiting: bool = false,
        canplay: bool = false,
        notify_playing: bool = false,
        canplaythrough: bool = false,
    };

    /// The duration attribute takes `duration`; true when it changed, and the
    /// owner queues durationchange (4.8.11.6: "When the length of the media
    /// resource changes to a known value ... queue a media element task ...
    /// to fire an event named durationchange").
    pub fn setDuration(self: *LoadState, duration: f64) bool {
        const same = (std.math.isNan(duration) and std.math.isNan(self.duration)) or duration == self.duration;
        if (same) return false;
        self.duration = duration;
        return true;
    }

    /// Media data processing: the decoder answered a push of this load with
    /// `data`, `end_of_stream` saying whether it was the last. Changes the
    /// ready state to what that data supports; null for a stale load.
    pub fn decoderData(self: *LoadState, generation: u64, data: Data, end_of_stream: bool, loop: bool) ?ReadyChange {
        if (generation != self.generation) return null;
        if (self.data == null or @intFromEnum(data) > @intFromEnum(self.data.?)) self.data = data;
        if (data == .current_data and end_of_stream) self.all_data = true;
        return self.changeReady(self.readyNow(loop), loop);
    }

    /// The ready state the decoded data supports at the current playback
    /// position (4.8.11.7):
    /// - metadata alone: HAVE_METADATA;
    /// - data at the position, with more of the resource still to arrive:
    ///   HAVE_CURRENT_DATA - nothing says the next frame is here;
    /// - data at the position and every byte arrived: HAVE_ENOUGH_DATA, by its
    ///   second condition ("the user agent has entered a state where waiting
    ///   longer will not result in further data being obtained") - Gecko's
    ///   UpdateReadyStateInternal does the same once the download is done
    ///   ("this state transition includes the case where we finished
    ///   downloaded the whole data stream");
    /// - except at the end in the direction of playback: HAVE_CURRENT_DATA
    ///   ("there is no more data to obtain in the direction of playback ...
    ///   when playback has ended"; HAVE_FUTURE_DATA "cannot be" reached then).
    ///   Gecko keeps HAVE_CURRENT_DATA in its ended state too.
    pub fn readyNow(self: *const LoadState, loop: bool) Ready {
        const data = self.data orelse return self.ready;
        if (data == .metadata) return .metadata;
        if (!self.all_data) return .current_data;
        if (self.endedPlayback(loop)) return .current_data;
        return .enough_data;
    }

    /// Set the ready state to `new`, returning the events to queue (4.8.11.7).
    pub fn changeReady(self: *LoadState, new: Ready, loop: bool) ReadyChange {
        const old = self.ready;
        var change: ReadyChange = .{};
        if (old == new) return change;
        const was_potentially_playing = self.potentiallyPlaying(loop);
        self.ready = new;
        const old_level = @intFromEnum(old);
        const new_level = @intFromEnum(new);
        // From HAVE_NOTHING: loadedmetadata (the processing steps reach
        // HAVE_METADATA before any later state).
        if (old == .nothing and new_level >= @intFromEnum(Ready.metadata)) change.loadedmetadata = true;
        // From HAVE_METADATA (or less) to HAVE_CURRENT_DATA or greater: the
        // first time since load, loadeddata. Data is not merely metadata, so
        // the element stops delaying the load event (resource fetch,
        // "once the readyState attribute reaches HAVE_CURRENT_DATA").
        if (old_level <= @intFromEnum(Ready.metadata) and new_level >= @intFromEnum(Ready.current_data)) {
            if (!self.loadeddata_fired) change.loadeddata = true;
            self.loadeddata_fired = true;
            self.delaying_load_event = false;
        }
        // From HAVE_FUTURE_DATA or more to HAVE_CURRENT_DATA or less, while it
        // was potentially playing and has not ended playback.
        if (old_level >= @intFromEnum(Ready.future_data) and new_level <= @intFromEnum(Ready.current_data)) {
            if (was_potentially_playing and !self.endedPlayback(loop)) change.timeupdate_waiting = true;
        }
        // From HAVE_CURRENT_DATA or less to HAVE_FUTURE_DATA or more: canplay,
        // and notify about playing when not paused.
        if (old_level <= @intFromEnum(Ready.current_data) and new_level >= @intFromEnum(Ready.future_data)) {
            change.canplay = true;
            if (!self.paused) change.notify_playing = true;
        }
        if (new == .enough_data) change.canplaythrough = true;
        return change;
    }

    /// 4.8.11.8 "ended playback": the end in the direction of playback, with
    /// no loop attribute (or the start, playing backwards).
    pub fn endedPlayback(self: *const LoadState, loop: bool) bool {
        if (@intFromEnum(self.ready) < @intFromEnum(Ready.metadata)) return false;
        if (self.playback_rate >= 0) return !loop and self.position >= self.duration;
        return self.position <= 0;
    }

    /// 4.8.11.8 "potentially playing": not paused, not ended, not blocked
    /// (HAVE_FUTURE_DATA or more). Crane pauses for no user interaction or
    /// in-band content.
    pub fn potentiallyPlaying(self: *const LoadState, loop: bool) bool {
        return !self.paused and !self.endedPlayback(loop) and @intFromEnum(self.ready) >= @intFromEnum(Ready.future_data);
    }

    pub const Boundary = enum { none, end, start };

    /// The media timeline's clock moved by `seconds`: while potentially
    /// playing, the current playback position moves at playbackRate (4.8.11.8,
    /// "must increase monotonically at the element's playbackRate units of
    /// media time per unit time"), up to the end or the earliest position.
    pub fn advance(self: *LoadState, seconds: f64, loop: bool) Boundary {
        if (!self.potentiallyPlaying(loop) or seconds <= 0) return .none;
        self.position += seconds * self.playback_rate;
        if (self.playback_rate > 0 and self.position >= self.duration) {
            self.position = self.duration;
            // With a loop attribute the owner seeks to the start instead.
            return .end;
        }
        if (self.playback_rate < 0 and self.position <= 0) {
            self.position = 0;
            return .start;
        }
        return .none;
    }

    /// What the internal play steps ask of the owner (4.8.11.8), in order.
    pub const Play = struct {
        /// Step 1: run resource selection.
        select: bool = false,
        /// Step 2: seek to the earliest possible position.
        seek_to_start: bool = false,
        /// Step 3.3: queue play.
        play_event: bool = false,
        /// Step 3.4: queue waiting, or notify about playing.
        waiting: bool = false,
        notify_playing: bool = false,
        /// Step 4: take pending play promises and queue their resolution.
        resolve_pending: bool = false,
    };

    /// The internal play steps' state changes.
    pub fn play(self: *LoadState, loop: bool) Play {
        var steps: Play = .{ .select = self.network == .empty };
        if (self.endedPlayback(loop) and self.playback_rate >= 0) steps.seek_to_start = true;
        if (self.paused) {
            self.paused = false;
            self.show_poster = false;
            steps.play_event = true;
            if (@intFromEnum(self.ready) <= @intFromEnum(Ready.current_data)) steps.waiting = true else steps.notify_playing = true;
        } else if (@intFromEnum(self.ready) >= @intFromEnum(Ready.future_data)) {
            steps.resolve_pending = true;
        }
        self.can_autoplay = false;
        return steps;
    }

    /// The internal pause steps' state changes: true when it was playing, and
    /// the owner queues timeupdate, pause and the promises' rejection.
    pub fn pause(self: *LoadState) bool {
        self.can_autoplay = false;
        if (self.paused) return false;
        self.paused = true;
        // Step 2.4: the official playback position is the current one.
        self.official_position = self.position;
        return true;
    }

    /// Seek steps 2–11 (4.8.11.9): null with no resource (HAVE_NOTHING);
    /// otherwise the seek's id, with the position set. Positions clamp to the
    /// media timeline [0, duration]. Every byte of a resource Crane plays is
    /// held, so the whole timeline is seekable (as the browsers' seekable
    /// reports it for such a resource; Crane's TimeRanges cannot list ranges
    /// yet, so step 9's check against `seekable` is not made).
    pub fn beginSeek(self: *LoadState, target: f64) ?u64 {
        if (self.ready == .nothing) return null;
        self.show_poster = false;
        self.seeking = true;
        var position = target;
        if (!std.math.isNan(self.duration) and position > self.duration) position = self.duration;
        if (position < 0) position = 0;
        self.position = position;
        self.official_position = position;
        self.seek_id +%= 1;
        return self.seek_id;
    }

    /// Seek step 14, in its stable state: false when a newer seek or a load
    /// aborted this one.
    pub fn finishSeek(self: *LoadState, id: u64) bool {
        if (id != self.seek_id or !self.seeking) return false;
        self.seeking = false;
        return true;
    }

    fn clearCurrentSrc(self: *LoadState) void {
        if (self.current_src) |url| self.allocator.free(url);
        self.current_src = null;
    }
};
