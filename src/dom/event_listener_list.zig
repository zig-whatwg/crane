//! DOM 2.7 "event listener list": an EventTarget's listeners - its event
//! handlers' listeners among them - in ONE block made with the first one
//! (lane lis1, plan-v2 N5; tmp/redesign/nodedata/framework-pages.md finding 3).
//!
//! What a target keeps is `List`, one pointer (8 bytes): null for a target
//! that never had a listener, which is nearly every node. The block is a
//! small header and the listeners themselves, 32 bytes each, in the order
//! the spec gives them, every event type in the same array:
//!
//! - Gecko keeps listeners as values in arrays, an event handler being a
//!   listener of its own kind in the same array (EventListenerManager.h:
//!   `struct Listener` with `mListenerIsHandler` and `mHandlerIsString`;
//!   `SetEventHandlerInternal` finds the handler's listener and swaps the
//!   handler inside it, so it keeps its position). Its arrays were one
//!   `nsAutoTObserverArray<Listener, 2>` for every type until it moved to
//!   one `ListenerArray` per type atom (`EventListenerMap`).
//! - Blink keeps a vector of (type, listener vector) pairs because "an
//!   EventTarget rarely has event listeners for many event types, and
//!   HeapVector is faster in such cases" (event_listener_map.h:
//!   `HeapVector<std::pair<AtomicString, Member<EventListenerVector>>, 2>`),
//!   each listener a `RegisteredEventListener` whose capture, passive, once
//!   and removed flags are one-bit fields (registered_event_listener.h).
//! - WebKit: the same pair vector (EventListenerMap.h: `Vector<std::pair<
//!   AtomString, EventListenerVector>, 0, CrashOnOverflow, 4>`), inside the
//!   weak-pointer control block, made on first use (EventTarget.h:
//!   `WeakPtrImplWithEventTargetData`); an attribute handler is a listener
//!   in the same vector whose function is replaced in place
//!   (`setAttributeEventListener` -> `replaceJSFunctionForAttributeListener`).
//! - Servo: per type, a `Vec<Rc<RefCell<EventListenerEntry>>>` with phase,
//!   once, passive and removed, an inline handler being an entry kind
//!   (`EventListenerType::Inline`) replaced in place.
//!
//! One array for every type, as Gecko's first shape: a page's target holds a
//! listener or two (two in five elements on React, Vue and Preact pages hold
//! exactly one, framework-pages.md table D), and a type map would be a
//! second block for the one list. A type is an 8-byte `EventType`: an id for
//! the types the platform fires, an owned copy for any other.
//!
//! Dispatch's "clone" (DOM 2.9 "invoke" step 8) copies nothing: see `Cursor`.
//!
//! The list knows nothing of the engine: a listener's callback is an opaque
//! engine handle and its callback context, which EventTarget turns back into
//! the engine protocol's owned values. It keeps them, frees nothing of them,
//! and hands each removed listener back BY VALUE for its owner to release.
const std = @import("std");
const builtin = @import("builtin");
const runtime = @import("runtime");
const RawSource = @import("event_handlers.zig").RawSource;

// ============================================================================
// Event types
// ============================================================================

/// The event types a listener's type is kept as an id for: those the
/// platform's own algorithms fire (HTML's event handler table, the event
/// index, UI Events, Pointer Events, Touch Events, CSS animations and
/// transitions, the workers, storage, media, network and service worker
/// events). A type not listed costs one small copy; which types are listed
/// changes no behaviour.
const static_types = [_][]const u8{
    // HTML GlobalEventHandlers
    "abort",                       "auxclick",                   "beforeinput",              "beforematch",
    "beforetoggle",                "blur",                       "cancel",                   "canplay",
    "canplaythrough",              "change",                     "click",                    "close",
    "command",                     "contextlost",                "contextmenu",              "contextrestored",
    "copy",                        "cuechange",                  "cut",                      "dblclick",
    "drag",                        "dragend",                    "dragenter",                "dragleave",
    "dragover",                    "dragstart",                  "drop",                     "durationchange",
    "emptied",                     "ended",                      "error",                    "focus",
    "formdata",                    "input",                      "invalid",                  "keydown",
    "keypress",                    "keyup",                      "load",                     "loadeddata",
    "loadedmetadata",              "loadstart",                  "mousedown",                "mouseenter",
    "mouseleave",                  "mousemove",                  "mouseout",                 "mouseover",
    "mouseup",                     "paste",                      "pause",                    "play",
    "playing",                     "progress",                   "ratechange",               "reset",
    "resize",                      "scroll",                     "scrollend",                "securitypolicyviolation",
    "seeked",                      "seeking",                    "select",                   "slotchange",
    "stalled",                     "submit",                     "suspend",                  "timeupdate",
    "toggle",                      "volumechange",               "waiting",                  "wheel",
    "webkitAnimationEnd",          "webkitAnimationIteration",   "webkitAnimationStart",     "webkitTransitionEnd",
    // HTML WindowEventHandlers
    "afterprint",                  "beforeprint",                "beforeunload",             "hashchange",
    "languagechange",              "message",                    "messageerror",             "offline",
    "online",                      "pagehide",                   "pagereveal",               "pageshow",
    "pageswap",                    "popstate",                   "rejectionhandled",         "storage",
    "unhandledrejection",          "unload",                     "orientationchange",
    // Documents
           "readystatechange",
    "visibilitychange",            "DOMContentLoaded",           "selectionchange",          "selectstart",
    "fullscreenchange",            "fullscreenerror",            "pointerlockchange",        "pointerlockerror",
    "prerenderingchange",
    // UI Events, Pointer Events, Touch Events
             "focusin",                    "focusout",                 "compositionstart",
    "compositionupdate",           "compositionend",             "textInput",                "mousewheel",
    "DOMMouseScroll",              "DOMActivate",                "DOMFocusIn",               "DOMFocusOut",
    "pointerdown",                 "pointerup",                  "pointermove",              "pointerover",
    "pointerout",                  "pointerenter",               "pointerleave",             "pointercancel",
    "pointerrawupdate",            "gotpointercapture",          "lostpointercapture",       "touchstart",
    "touchend",                    "touchmove",                  "touchcancel",
    // CSS animations and transitions
                 "animationstart",
    "animationend",                "animationiteration",         "animationcancel",          "transitionrun",
    "transitionstart",             "transitionend",              "transitioncancel",
    // Mutation events
            "DOMNodeInserted",
    "DOMNodeRemoved",              "DOMSubtreeModified",         "DOMCharacterDataModified", "DOMAttrModified",
    "DOMNodeInsertedIntoDocument", "DOMNodeRemovedFromDocument",
    // Network, workers, storage
    "loadend",                  "timeout",
    "open",                        "connect",                    "statechange",              "updatefound",
    "controllerchange",            "install",                    "activate",                 "fetch",
    "push",                        "sync",                       "success",                  "upgradeneeded",
    "blocked",                     "versionchange",              "complete",                 "update",
    "updateend",                   "updatestart",                "sourceopen",               "sourceended",
    "sourceclose",                 "addsourcebuffer",            "removesourcebuffer",       "addtrack",
    "removetrack",                 "enter",                      "exit",                     "start",
    "end",                         "result",                     "dataavailable",            "stop",
    "resume",                      "mute",                       "unmute",                   "encrypted",
    "waitingforkey",               "enterpictureinpicture",      "leavepictureinpicture",    "devicemotion",
    "deviceorientation",           "gamepadconnected",           "gamepaddisconnected",      "icecandidate",
    "track",                       "negotiationneeded",          "datachannel",              "bufferedamountlow",
    "closing",                     "keystatuseschange",          "levelchange",              "chargingchange",
    "voiceschanged",               "boundary",                   "mark",                     "nomatch",
    "finish",                      "remove",                     "show",                     "search",
    "beforecopy",                  "beforecut",                  "beforepaste",              "contentvisibilityautostatechange",
    // The Navigation API
    "navigate",                    "navigatesuccess",            "navigateerror",            "currententrychange",
    "dispose",
};

const static_ids = std.StaticStringMap(u16).initComptime(kvs: {
    @setEvalBranchQuota(100_000);
    var list: [static_types.len]struct { []const u8, u16 } = undefined;
    for (static_types, 0..) |name, i| list[i] = .{ name, i };
    break :kvs list;
});

comptime {
    // An id is the name's index: a name listed twice would have two.
    @setEvalBranchQuota(1_000_000);
    for (static_types, 0..) |name, i| {
        if (static_ids.get(name).? != i) @compileError("event type listed twice: " ++ name);
    }
}

/// A listener's type (DOM 2.7 "type (a string)"), 8 bytes: an id for a
/// type in `static_types` (the low bit set), else the address of an owned
/// copy (`Custom`, 4-byte aligned, so the low bit is clear). Which
/// representation a string gets depends only on the string, so two types
/// are the same string exactly when they are the same id or equal copies.
pub const EventType = struct {
    bits: usize,

    /// An owned copy of a type the table does not list: its length, then
    /// its bytes.
    const Custom = extern struct {
        len: u32,

        fn bytes(self: *const Custom) []const u8 {
            const base: [*]const u8 = @ptrCast(self);
            return base[@sizeOf(Custom)..][0..self.len];
        }
    };

    /// `bytes` as a listener keeps it: a listed type costs nothing, any
    /// other is copied (`deinit` frees the copy).
    pub fn init(allocator: std.mem.Allocator, bytes: []const u8) error{OutOfMemory}!EventType {
        if (static_ids.get(bytes)) |id| return .{ .bits = (@as(usize, id) << 1) | 1 };
        const len = std.math.cast(u32, bytes.len) orelse return error.OutOfMemory;
        const block = try allocator.alignedAlloc(u8, .of(Custom), @sizeOf(Custom) + bytes.len);
        const copy: *Custom = @ptrCast(block.ptr);
        copy.len = len;
        @memcpy(block[@sizeOf(Custom)..], bytes);
        return .{ .bits = @intFromPtr(copy) };
    }

    /// Free an owned copy; a listed type has none.
    pub fn deinit(self: EventType, allocator: std.mem.Allocator) void {
        const copy = self.ownedCopy() orelse return;
        const base: [*]align(@alignOf(Custom)) u8 = @ptrCast(@constCast(copy));
        allocator.free(base[0 .. @sizeOf(Custom) + copy.len]);
    }

    fn ownedCopy(self: EventType) ?*const Custom {
        if (self.bits & 1 == 1) return null;
        return @ptrFromInt(self.bits);
    }

    /// The type's string, BORROWED: static, or the copy's (valid while the
    /// listener keeps it).
    pub fn slice(self: EventType) []const u8 {
        if (self.ownedCopy()) |owned| return owned.bytes();
        return static_types[self.bits >> 1];
    }

    /// Whether this is the type `key` was looked up for.
    pub fn matches(self: EventType, key: Key) bool {
        if (key.static_bits != 0) return self.bits == key.static_bits;
        const owned = self.ownedCopy() orelse return false;
        return std.mem.eql(u8, owned.bytes(), key.bytes);
    }

    /// Whether two kept types are the same string.
    pub fn eql(self: EventType, other: EventType) bool {
        if (self.bits == other.bits) return true;
        const a = self.ownedCopy() orelse return false;
        const b = other.ownedCopy() orelse return false;
        return std.mem.eql(u8, a.bytes(), b.bytes());
    }
};

/// A type looked up once - an event's, for a whole dispatch; an argument's,
/// for one call - and matched against kept types without copying or a
/// lookup per listener. `bytes` is BORROWED.
pub const Key = struct {
    /// The listed type's bits, or 0 for a type the table does not list.
    static_bits: usize,
    bytes: []const u8,

    pub fn of(bytes: []const u8) Key {
        const id = static_ids.get(bytes) orelse return .{ .static_bits = 0, .bytes = bytes };
        return .{ .static_bits = (@as(usize, id) << 1) | 1, .bytes = bytes };
    }
};

// ============================================================================
// Listeners
// ============================================================================

/// Whether a listener was added with addEventListener or is an event
/// handler's (HTML "activate an event handler").
pub const Kind = enum(u1) { listener, handler };

/// An event handler's value, kept in its listener (HTML 8.1.8.1 "event
/// handler": a value and a listener): null, a callback the binding converted
/// (`compiled`), or an internal raw uncompiled handler (`raw`). A
/// compilation that fails leaves the value null and the listener in place
/// ("This does not deactivate the event handler").
pub const HandlerValue = enum(u2) { none, compiled, raw };

/// The highest id a listener can have: ids come from EventTarget's
/// process-wide counter, from 1.
pub const max_id = std.math.maxInt(u56);

pub const Bits = packed struct(u64) {
    /// Unique in the process, and increasing along a list: a listener is
    /// appended with the next id, and nothing is ever inserted before
    /// another. An event handler's listener keeps its id while its value is
    /// replaced; a handler deactivated and activated again is a new listener
    /// with a new id.
    id: u56,
    /// capture (a boolean, initially false)
    capture: bool = false,
    /// passive, resolved when the listener is added ("add an event
    /// listener" step 4 sets the default passive value).
    passive: bool = false,
    /// once (a boolean, initially false)
    once: bool = false,
    kind: Kind = .listener,
    /// An event handler's value (`kind` handler only).
    value: HandlerValue = .none,
    _: u2 = 0,
};

/// One event listener (DOM 2.7), 32 bytes, BY VALUE: what the list hands
/// out is a copy, so no reader holds a pointer into storage that moves.
///
/// Its signal is not kept: only "add an event listener" reads it (step 6
/// gives the signal abort steps naming the listener's id). Its removed flag
/// is not kept either: a listener the spec removes leaves the list at once,
/// and dispatch's clone (`Cursor`) holds only listeners still in it - the
/// two ways the spec's "whose removed is false" is read.
pub const Listener = struct {
    type: EventType,
    /// A listener's callback (DOM: "callback (null or an EventListener
    /// object)"): the engine handle of the callback interface's object, an
    /// owned hold - null when the binding's value had no object. An event
    /// handler's value: the compiled function's handle (`compiled`), the
    /// `RawHandler` (`raw`), or null.
    object: ?*anyopaque,
    /// The callback context (WebIDL 3.2.16, 3.2.19) of `object`'s value.
    context: ?runtime.Context,
    bits: Bits,

    /// The raw uncompiled handler a `raw` event handler keeps.
    pub fn rawHandler(self: Listener) ?*RawHandler {
        if (self.bits.kind != .handler or self.bits.value != .raw) return null;
        return @ptrCast(@alignCast(self.object.?));
    }
};

comptime {
    if (@sizeOf(Listener) != 32) @compileError(std.fmt.comptimePrint("a listener grew past 32 bytes: {d}", .{@sizeOf(Listener)}));
}

/// HTML's internal raw uncompiled handler, kept by an event handler's
/// listener (`HandlerValue.raw`): its body and its location, in one block.
/// The body is kept rather than re-read from the content attribute: CSP may
/// reject a replacement, and a body or frameset element's Window handler
/// outlives the element (dom.event_handlers.RawSource).
pub const RawHandler = extern struct {
    body_len: u32,
    url_len: u32,
    lineno: u32,
    _pad: u32 = 0,

    pub fn create(allocator: std.mem.Allocator, raw: RawSource) error{OutOfMemory}!*RawHandler {
        const body_len = std.math.cast(u32, raw.body.len) orelse return error.OutOfMemory;
        const url_len = std.math.cast(u32, raw.url.len) orelse return error.OutOfMemory;
        const block = try allocator.alignedAlloc(u8, .of(RawHandler), @sizeOf(RawHandler) + raw.body.len + raw.url.len);
        const self: *RawHandler = @ptrCast(block.ptr);
        self.* = .{ .body_len = body_len, .url_len = url_len, .lineno = raw.lineno };
        @memcpy(block[@sizeOf(RawHandler)..][0..raw.body.len], raw.body);
        @memcpy(block[@sizeOf(RawHandler) + raw.body.len ..][0..raw.url.len], raw.url);
        return self;
    }

    pub fn destroy(self: *RawHandler, allocator: std.mem.Allocator) void {
        const base: [*]align(@alignOf(RawHandler)) u8 = @ptrCast(self);
        allocator.free(base[0 .. @sizeOf(RawHandler) + self.body_len + self.url_len]);
    }

    /// Its body and location, BORROWED from the block.
    pub fn source(self: *const RawHandler) RawSource {
        const base: [*]const u8 = @ptrCast(self);
        const body = base[@sizeOf(RawHandler)..][0..self.body_len];
        return .{ .body = body, .url = base[@sizeOf(RawHandler) + self.body_len ..][0..self.url_len], .lineno = self.lineno };
    }
};

// ============================================================================
// The list
// ============================================================================

/// The block: this header, then `capacity` listeners.
const Header = packed struct(u64) {
    len: u32,
    capacity: u31,
    /// The target's owner hears every change of the list
    /// (dom.event_listener_changes.watch). In the block, not in every
    /// target: an owner that asks makes the block (lesson
    /// architecture-keep-while-listening-needs-the-listener-list-to-tell-its-owner.md).
    watched: bool,
};

const block_align: std.mem.Alignment = .of(Listener);

comptime {
    if (@sizeOf(Header) % @alignOf(Listener) != 0) @compileError("listeners after the header would be misaligned");
}

/// A target's event listener list: null until its first listener, event
/// handler or watching owner. 8 bytes.
pub const List = struct {
    header: ?*Header = null,

    fn entries(header: *Header) [*]Listener {
        const base: [*]align(@alignOf(Listener)) u8 = @ptrCast(@alignCast(header));
        return @ptrCast(@alignCast(base + @sizeOf(Header)));
    }

    fn blockBytes(capacity: usize) usize {
        return @sizeOf(Header) + capacity * @sizeOf(Listener);
    }

    fn block(header: *Header) []align(@alignOf(Listener)) u8 {
        const base: [*]align(@alignOf(Listener)) u8 = @ptrCast(@alignCast(header));
        return base[0..blockBytes(header.capacity)];
    }

    /// How many listeners it holds.
    pub fn len(self: List) usize {
        const header = self.header orelse return 0;
        return header.len;
    }

    /// The listeners, BORROWED: valid until the list next changes, so never
    /// across a call that can run script or change it - scan, then act.
    pub fn view(self: List) []const Listener {
        const header = self.header orelse return &.{};
        return entries(header)[0..header.len];
    }

    /// The listener at `index`, by value.
    pub fn at(self: List, index: usize) Listener {
        return self.view()[index];
    }

    /// The bytes the list has allocated (its block), for measurements.
    pub fn allocatedBytes(self: List) usize {
        const header = self.header orelse return 0;
        return blockBytes(header.capacity);
    }

    pub fn watched(self: List) bool {
        const header = self.header orelse return false;
        return header.watched;
    }

    /// Mark the list watched, making its block (with room for nothing) if
    /// the target has none yet.
    pub fn watch(self: *List, allocator: std.mem.Allocator) error{OutOfMemory}!void {
        if (self.header == null) try self.grow(allocator, 0);
        self.header.?.watched = true;
    }

    /// Room for `count` more listeners, so that the appends after it cannot
    /// fail (a step that must change nothing when it fails makes room first).
    pub fn ensureUnusedCapacity(self: *List, allocator: std.mem.Allocator, count: usize) error{OutOfMemory}!void {
        const length = self.len();
        const capacity: usize = if (self.header) |header| header.capacity else 0;
        if (length + count <= capacity and self.header != null) return;
        // The first listener's block holds exactly one (most targets that
        // have one have only one); after that, double.
        var wanted: usize = if (capacity == 0) 1 else capacity * 2;
        while (wanted < length + count) wanted *= 2;
        try self.grow(allocator, wanted);
    }

    fn grow(self: *List, allocator: std.mem.Allocator, capacity: usize) error{OutOfMemory}!void {
        const new_capacity = std.math.cast(u31, capacity) orelse return error.OutOfMemory;
        if (self.header) |header| {
            const moved = try allocator.realloc(block(header), blockBytes(capacity));
            const new_header: *Header = @ptrCast(moved.ptr);
            new_header.capacity = new_capacity;
            self.header = new_header;
            return;
        }
        const made = try allocator.alignedAlloc(u8, block_align, blockBytes(capacity));
        const header: *Header = @ptrCast(made.ptr);
        header.* = .{ .len = 0, .capacity = new_capacity, .watched = false };
        self.header = header;
    }

    /// Append `listener`, whose id must be greater than every id in the list.
    pub fn append(self: *List, allocator: std.mem.Allocator, listener: Listener) error{OutOfMemory}!void {
        try self.ensureUnusedCapacity(allocator, 1);
        self.appendAssumeCapacity(listener);
    }

    pub fn appendAssumeCapacity(self: *List, listener: Listener) void {
        const header = self.header.?;
        if (builtin.mode == .debug) {
            std.debug.assert(header.len < header.capacity);
            if (header.len > 0) std.debug.assert(entries(header)[header.len - 1].bits.id < listener.bits.id);
        }
        entries(header)[header.len] = listener;
        header.len += 1;
    }

    /// Take the listener at `index` out of the list, keeping the order of
    /// the rest. Returns it, BY VALUE: what it owns is the caller's.
    pub fn removeAt(self: *List, index: usize) Listener {
        const header = self.header.?;
        const items = entries(header)[0..header.len];
        const removed = items[index];
        std.mem.copyForwards(Listener, items[index .. items.len - 1], items[index + 1 ..]);
        header.len -= 1;
        return removed;
    }

    /// Replace what the listener at `index` keeps (an event handler's new
    /// value), keeping its place and its id. Returns the old one, BY VALUE.
    pub fn replaceAt(self: *List, index: usize, listener: Listener) Listener {
        const header = self.header.?;
        const slot = &entries(header)[index];
        if (builtin.mode == .debug) std.debug.assert(slot.bits.id == listener.bits.id);
        const old = slot.*;
        slot.* = listener;
        return old;
    }

    /// Forget every listener, keeping the block (its owner has released
    /// what they owned).
    pub fn clearRetainingCapacity(self: *List) void {
        const header = self.header orelse return;
        header.len = 0;
    }

    /// Free the block. What its listeners own must have been released.
    pub fn deinit(self: *List, allocator: std.mem.Allocator) void {
        const header = self.header orelse return;
        allocator.free(block(header));
        self.header = null;
    }

    /// The index of the listener whose id is `id`, if it is still in the
    /// list: ids increase along it, so a binary search.
    pub fn indexOfId(self: List, id: u56) ?usize {
        if (id == 0) return null;
        return firstAfter(self.view(), id - 1, id);
    }

    /// The index of the first listener whose id is greater than `after`,
    /// if that id is at most `limit`.
    fn firstAfter(items: []const Listener, after: u56, limit: u56) ?usize {
        var low: usize = 0;
        var high: usize = items.len;
        while (low < high) {
            const mid = low + (high - low) / 2;
            if (items[mid].bits.id <= after) low = mid + 1 else high = mid;
        }
        if (low == items.len or items[low].bits.id > limit) return null;
        return low;
    }

    /// The event handler listener of the type `key` was made for, if one is
    /// activated (an event handler map has one handler per name, and Crane
    /// keys handlers by their event type).
    pub fn indexOfHandler(self: List, key: Key) ?usize {
        for (self.view(), 0..) |listener, i| {
            if (listener.bits.kind == .handler and listener.type.matches(key)) return i;
        }
        return null;
    }

    /// DOM 2.9 "invoke" step 8: "Let listeners be a clone of event's
    /// currentTarget attribute value's event listener list", without
    /// copying it. The clone is every listener in the list now: ids increase
    /// along the list, so it is the listeners whose id is at most the last
    /// one's. Walking it with `next`, a listener appended after the clone was
    /// taken has a greater id and is never reached; one removed has left the
    /// list and is never reached - the spec's "whose removed is false",
    /// since a clone's listener is the same struct the list holds; one whose
    /// handler value was replaced is the same listener, reached once. Null
    /// for a list with no listener.
    ///
    /// The browsers copy: Blink a `HeapVector<Member<RegisteredEventListener>,
    /// 1>` per dispatch (EventTarget::FireEventListeners, "Calling
    /// FireEventListener causes a clone of listeners_vector"), WebKit a
    /// `Vector<Ref<RegisteredEventListener>, 1>` ("Intentionally creates a
    /// copy of the listeners vector to avoid event listeners added after this
    /// point from being run"), Servo its `Vec` of `Rc`s; each copy holds the
    /// listeners by reference so a removal's flag is seen. Gecko copies
    /// nothing: it walks the live array with an end-limited observer iterator
    /// (`HandleEventWithListenerArray`, `aListeners->EndLimitedRange()`),
    /// which removals adjust. This is Gecko's walk, with the list's
    /// increasing ids in place of a registered iterator: nothing is copied
    /// and nothing registered, and a list that moves (it grows by
    /// reallocation) or shifts under a callback is found again by id.
    pub fn clone(self: List) ?Cursor {
        const items = self.view();
        if (items.len == 0) return null;
        return .{ .limit = items[items.len - 1].bits.id };
    }

    /// The next listener of the clone `cursor` walks, BY VALUE, or null at
    /// its end. Reads the list as it is now: the caller may have run script
    /// since the last call.
    pub fn next(self: List, cursor: *Cursor) ?Listener {
        const items = self.view();
        var index: usize = cursor.index;
        // The list shifted under the walk - a listener at or before the last
        // one visited was removed - or nothing was visited yet: find the
        // place again by id.
        if (index == 0 or index > items.len or items[index - 1].bits.id != cursor.last) {
            index = firstAfter(items, cursor.last, cursor.limit) orelse return null;
        } else if (index == items.len or items[index].bits.id > cursor.limit) {
            return null;
        }
        const listener = items[index];
        cursor.index = index + 1;
        cursor.last = listener.bits.id;
        return listener;
    }
};

/// A walk over a list's clone (`List.clone`): where it is, and where the
/// clone ends.
pub const Cursor = struct {
    /// One past the listener visited last, when the list has not shifted.
    index: usize = 0,
    /// The id of the listener visited last; 0 before the first.
    last: u56 = 0,
    /// The clone's last listener's id.
    limit: u56,
};

comptime {
    if (@sizeOf(List) != 8) @compileError("an event listener list is one pointer");
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

fn testListener(id: u56, @"type": EventType) Listener {
    return .{ .type = @"type", .object = @ptrFromInt(id * 16), .context = null, .bits = .{ .id = id } };
}

fn ids(list: List, buffer: []u56) []u56 {
    for (list.view(), 0..) |listener, i| buffer[i] = listener.bits.id;
    return buffer[0..list.len()];
}

test "a listed type is an id and costs nothing; any other is an owned copy" {
    const click = try EventType.init(testing.allocator, "click");
    try testing.expect(click.bits & 1 == 1);
    try testing.expectEqualStrings("click", click.slice());
    click.deinit(testing.allocator);

    const custom = try EventType.init(testing.allocator, "my-event");
    defer custom.deinit(testing.allocator);
    try testing.expect(custom.bits & 1 == 0);
    try testing.expectEqualStrings("my-event", custom.slice());

    try testing.expect(click.matches(Key.of("click")));
    try testing.expect(!click.matches(Key.of("Click")));
    try testing.expect(!click.matches(Key.of("my-event")));
    try testing.expect(custom.matches(Key.of("my-event")));
    try testing.expect(!custom.matches(Key.of("my-even")));
    try testing.expect(!custom.matches(Key.of("click")));

    const again = try EventType.init(testing.allocator, "my-event");
    defer again.deinit(testing.allocator);
    try testing.expect(custom.eql(again));
    try testing.expect(!custom.eql(click));

    // The empty string is a type too.
    const empty = try EventType.init(testing.allocator, "");
    defer empty.deinit(testing.allocator);
    try testing.expect(empty.matches(Key.of("")));
    try testing.expectEqualStrings("", empty.slice());
}

test "the legacy mixed-case types are listed as they are spelled" {
    try testing.expect(Key.of("webkitAnimationEnd").static_bits != 0);
    try testing.expect(Key.of("webkitanimationend").static_bits == 0);
}

test "a list is one pointer; an empty list has no block; the first listener's block holds exactly one" {
    try testing.expectEqual(@as(usize, 8), @sizeOf(List));
    try testing.expectEqual(@as(usize, 32), @sizeOf(Listener));
    var list: List = .{};
    try testing.expectEqual(@as(usize, 0), list.allocatedBytes());
    try testing.expect(list.clone() == null);

    try list.append(testing.allocator, testListener(1, try EventType.init(testing.allocator, "click")));
    defer list.deinit(testing.allocator);
    // The header and one listener: 40 bytes (a 48-byte malloc class).
    try testing.expectEqual(@as(usize, 40), list.allocatedBytes());
    try list.append(testing.allocator, testListener(2, try EventType.init(testing.allocator, "click")));
    try testing.expectEqual(@as(usize, 8 + 2 * 32), list.allocatedBytes());
    try list.append(testing.allocator, testListener(3, try EventType.init(testing.allocator, "click")));
    try testing.expectEqual(@as(usize, 8 + 4 * 32), list.allocatedBytes());
}

test "watching makes a block with room for nothing, and the first listener grows it to one" {
    var list: List = .{};
    defer list.deinit(testing.allocator);
    try testing.expect(!list.watched());
    try list.watch(testing.allocator);
    try testing.expect(list.watched());
    try testing.expectEqual(@as(usize, 8), list.allocatedBytes());
    try list.append(testing.allocator, testListener(5, try EventType.init(testing.allocator, "change")));
    try testing.expect(list.watched());
    try testing.expectEqual(@as(usize, 40), list.allocatedBytes());
}

test "removeAt keeps the order of the rest; indexOfId finds by id" {
    var list: List = .{};
    defer list.deinit(testing.allocator);
    for (1..7) |id| try list.append(testing.allocator, testListener(@intCast(id * 10), try EventType.init(testing.allocator, "click")));
    var buffer: [8]u56 = undefined;
    _ = list.removeAt(2);
    try testing.expectEqualSlices(u56, &.{ 10, 20, 40, 50, 60 }, ids(list, &buffer));
    try testing.expectEqual(@as(?usize, 2), list.indexOfId(40));
    try testing.expectEqual(@as(?usize, null), list.indexOfId(30));
    try testing.expectEqual(@as(?usize, 4), list.indexOfId(60));
    try testing.expectEqual(@as(?usize, null), list.indexOfId(70));
    try testing.expectEqual(@as(?usize, 0), list.indexOfId(10));
}

test "the clone visits the listeners present when it was taken, in order, and none appended after" {
    var list: List = .{};
    defer list.deinit(testing.allocator);
    for (1..4) |id| try list.append(testing.allocator, testListener(@intCast(id), try EventType.init(testing.allocator, "click")));
    var cursor = list.clone().?;
    try testing.expectEqual(@as(u56, 1), list.next(&cursor).?.bits.id);
    // Appended during the walk - the list reallocates and moves.
    for (4..20) |id| try list.append(testing.allocator, testListener(@intCast(id), try EventType.init(testing.allocator, "click")));
    try testing.expectEqual(@as(u56, 2), list.next(&cursor).?.bits.id);
    try testing.expectEqual(@as(u56, 3), list.next(&cursor).?.bits.id);
    try testing.expect(list.next(&cursor) == null);
    try testing.expect(list.next(&cursor) == null);
}

test "the clone skips a listener removed before it is reached, and survives the removal of the one it is on" {
    var list: List = .{};
    defer list.deinit(testing.allocator);
    for (1..7) |id| try list.append(testing.allocator, testListener(@intCast(id), try EventType.init(testing.allocator, "click")));
    var cursor = list.clone().?;
    try testing.expectEqual(@as(u56, 1), list.next(&cursor).?.bits.id);
    try testing.expectEqual(@as(u56, 2), list.next(&cursor).?.bits.id);
    // The current one (a once listener, or one removing itself) and one ahead.
    _ = list.removeAt(list.indexOfId(2).?);
    _ = list.removeAt(list.indexOfId(4).?);
    try testing.expectEqual(@as(u56, 3), list.next(&cursor).?.bits.id);
    // One behind: the list shifts left under the walk.
    _ = list.removeAt(list.indexOfId(1).?);
    try testing.expectEqual(@as(u56, 5), list.next(&cursor).?.bits.id);
    // Removed and appended again: a new listener, past the clone.
    _ = list.removeAt(list.indexOfId(6).?);
    try list.append(testing.allocator, testListener(7, try EventType.init(testing.allocator, "click")));
    try testing.expect(list.next(&cursor) == null);
}

test "the clone ends when every listener is removed under it, and a list refilled after is new" {
    var list: List = .{};
    defer list.deinit(testing.allocator);
    for (1..4) |id| try list.append(testing.allocator, testListener(@intCast(id), try EventType.init(testing.allocator, "click")));
    var cursor = list.clone().?;
    _ = list.next(&cursor).?;
    list.clearRetainingCapacity();
    try testing.expect(list.next(&cursor) == null);
    try list.append(testing.allocator, testListener(8, try EventType.init(testing.allocator, "click")));
    try testing.expect(list.next(&cursor) == null);
}

test "an event handler's listener keeps its place and id when its value is replaced" {
    var list: List = .{};
    defer list.deinit(testing.allocator);
    try list.append(testing.allocator, testListener(1, try EventType.init(testing.allocator, "click")));
    var handler = testListener(2, try EventType.init(testing.allocator, "click"));
    handler.bits.kind = .handler;
    handler.bits.value = .compiled;
    try list.append(testing.allocator, handler);
    try list.append(testing.allocator, testListener(3, try EventType.init(testing.allocator, "click")));
    const index = list.indexOfHandler(Key.of("click")).?;
    try testing.expectEqual(@as(usize, 1), index);
    try testing.expectEqual(@as(?usize, null), list.indexOfHandler(Key.of("input")));
    var replacement = handler;
    replacement.object = @ptrFromInt(0x1230);
    var cursor = list.clone().?;
    _ = list.next(&cursor).?;
    const old = list.replaceAt(index, replacement);
    try testing.expectEqual(handler.object, old.object);
    const reached = list.next(&cursor).?;
    try testing.expectEqual(@as(u56, 2), reached.bits.id);
    try testing.expectEqual(replacement.object, reached.object);
}

test "a raw handler keeps its body and location in one block" {
    const raw = try RawHandler.create(testing.allocator, .{ .body = "alert(1)", .url = "https://example.test/", .lineno = 7 });
    defer raw.destroy(testing.allocator);
    const source = raw.source();
    try testing.expectEqualStrings("alert(1)", source.body);
    try testing.expectEqualStrings("https://example.test/", source.url);
    try testing.expectEqual(@as(u32, 7), source.lineno);
}
