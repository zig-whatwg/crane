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

    /// Ready state change to HAVE_CURRENT_DATA: data, not merely metadata.
    pub fn haveCurrentData(self: *LoadState, generation: u64) void {
        if (generation != self.generation) return;
        self.ready = .current_data;
        self.delaying_load_event = false;
    }

    fn clearCurrentSrc(self: *LoadState) void {
        if (self.current_src) |url| self.allocator.free(url);
        self.current_src = null;
    }
};
