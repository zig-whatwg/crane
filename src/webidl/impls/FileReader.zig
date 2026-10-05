//! Implementation for FileReader interface
//!
//! File API §6.2: The FileReader API
//! https://w3c.github.io/FileAPI/#APIASynch
//!
//! A FileReader reads a Blob through its "read operation": the state and
//! result change as the steps say, and loadstart, progress, load or error,
//! and loadend are fired as tasks on the file reading task source, in the
//! reader's relevant realm (`engine.runTaskInRealm`). abort() terminates the
//! operation, and a task it queued then does nothing.
//!
//! The reader's event handlers live in EventTarget's map, as every
//! EventTarget's do.

const std = @import("std");
const webidl = @import("webidl");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dictionaries = @import("dictionaries");
const engine = @import("engine");
const encoding = @import("encoding");
const mimesniff = @import("mimesniff");
const infra = @import("infra");
const FileReader = interfaces.FileReader;
const EventTargetImpl = @import("EventTarget.zig");
const same_object = @import("same_object.zig");
const blob_bytes = @import("dom").blob_bytes;
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;

pub const State = FileReader.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

/// fr's state.
const ReadyState = enum(u16) { empty = 0, loading = 1, done = 2 };

/// The read method, which "package data" switches on.
const ReadType = enum { array_buffer, binary_string, text, data_url };

pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// fr's state: "empty", "loading" or "done".
    state: ReadyState = .empty,
    /// The reader this state is: the owner of the edges below.
    reader: ?*runtime.Instance = null,
    /// fr's result is non-null: the string or ArrayBuffer a read made, kept
    /// by an edge from the reader's wrapper (`result_slot`,
    /// engine.traceValue), never a root. Held as a root (an engine.Owned), a
    /// finished reader's result kept its realm alive for as long as the
    /// reader's instance lived - a removed frame whose own global held the
    /// reader was never collected.
    has_result: bool = false,
    /// fr's error: null, or the DOMException a failed read set, kept by an
    /// edge from the reader's wrapper (`error_slot`, engine.traceChild).
    error_instance: ?*runtime.Instance = null,
    /// The read operation whose tasks are queued, from the read method until
    /// its last task runs or abort() terminates it.
    operation: ?*ReadOperation = null,

    pub fn init(allocator: std.mem.Allocator) !*InternalState {
        const self = try allocator.create(InternalState);
        self.* = .{ .allocator = allocator };
        return self;
    }

    pub fn deinit(self: *InternalState) void {
        // A read in flight when the reader goes: its tasks do nothing.
        if (self.operation) |op| op.terminate();
        self.operation = null;
        self.setResult(null);
        self.setError(null, null);
        self.allocator.destroy(self);
    }

    /// Set fr's result, taking `value`: the reader's wrapper keeps it from
    /// here, and the hold `value` is goes.
    fn setResult(self: *InternalState, value: ?engine.Owned) void {
        const reader = self.reader orelse {
            if (value) |v| v.release();
            return;
        };
        if (value) |v| {
            defer v.release();
            engine.traceValue(reader, v.value, result_slot);
            self.has_result = true;
        } else if (self.has_result) {
            engine.forgetTracedChild(reader, result_slot);
            self.has_result = false;
        }
    }

    /// Set fr's error to `instance`, taking `value` (its wrapper): the
    /// reader's wrapper keeps it from here.
    fn setError(self: *InternalState, value: ?engine.Owned, instance: ?*runtime.Instance) void {
        // The hold goes only once the edge is drawn: until then it is what
        // keeps the exception.
        defer if (value) |v| v.release();
        const reader = self.reader orelse return;
        if (instance) |exception| {
            engine.traceChild(reader, exception, error_slot);
        } else if (self.error_instance != null) {
            engine.forgetTracedChild(reader, error_slot);
        }
        self.error_instance = instance;
    }
};

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// Initialize instance (creates the instance). A FileReader is an
/// EventTarget: EventTarget's state is initialized, and later freed, with it.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return EventTargetImpl.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        state.own._internal = null;
        internal.deinit();
    }
    // The event handlers and listeners go with EventTarget's state. GC layer
    // handles slab freeing - do NOT call runtime.Instance.deinit().
    EventTargetImpl.deinit(instance);
}

/// Constructor implementation
///
/// Spec: https://w3c.github.io/FileAPI/#dom-filereader-filereader
///
/// "The FileReader() constructor, when invoked, must return a new FileReader
/// object" - its state "empty", its result and error null.
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &FileReader.vtable, ctx);
    errdefer deinit(instance);
    const internal = try InternalState.init(ctx.allocator);
    internal.reader = instance;
    instance.getState(State).own._internal = internal;
    return instance;
}

/// The readyState getter steps: 0 for "empty", 1 for "loading", 2 for
/// "done".
pub fn get_readyState(instance: *runtime.Instance) anyerror!u16 {
    const internal = getInternal(instance) orelse return @intFromEnum(ReadyState.empty);
    return @intFromEnum(internal.state);
}

/// The result getter steps are to return this's result. The reader keeps
/// holding it; the binding gets a hold of its own.
pub fn get_result(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    const internal = getInternal(instance) orelse return null;
    if (!internal.has_result) return null;
    const result = engine.tracedValue(instance, result_slot) orelse return null;
    return result.take();
}

/// Where a reader keeps its result and its error (Blink: FileReader's
/// result is a TraceWrapperV8Reference-backed value, its error_ a Member).
const result_slot: engine.TracedSlot = .{ .name = "result" };
const error_slot: engine.TracedSlot = .{ .name = "error" };

/// The error getter steps are to return this's error.
pub fn get_error(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    return internal.error_instance;
}

// ============================================================================
// Event Handlers - in EventTarget's map (this impl's ancestor)
// ============================================================================

pub fn get_onloadstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "loadstart");
}

pub fn set_onloadstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "loadstart", value);
}

pub fn get_onprogress(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "progress");
}

pub fn set_onprogress(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "progress", value);
}

pub fn get_onload(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "load");
}

pub fn set_onload(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "load", value);
}

pub fn get_onabort(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "abort");
}

pub fn set_onabort(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "abort", value);
}

pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "error");
}

pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "error", value);
}

pub fn get_onloadend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "loadend");
}

pub fn set_onloadend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "loadend", value);
}

// ============================================================================
// Read methods (§6.2.3)
// ============================================================================

/// "The readAsArrayBuffer(blob) method, when invoked, must initiate a read
/// operation for blob with ArrayBuffer."
pub fn call_readAsArrayBuffer(instance: *runtime.Instance, blob: *runtime.Instance) anyerror!void {
    return readOperation(instance, blob, .array_buffer, null);
}

/// "The readAsBinaryString(blob) method, when invoked, must initiate a read
/// operation for blob with BinaryString."
pub fn call_readAsBinaryString(instance: *runtime.Instance, blob: *runtime.Instance) anyerror!void {
    return readOperation(instance, blob, .binary_string, null);
}

/// "The readAsDataURL(blob) method, when invoked, must initiate a read
/// operation for blob with DataURL."
pub fn call_readAsDataURL(instance: *runtime.Instance, blob: *runtime.Instance) anyerror!void {
    return readOperation(instance, blob, .data_url, null);
}

/// "The readAsText(blob, encoding) method, when invoked, must initiate a
/// read operation for blob with Text and encoding."
pub fn call_readAsText(instance: *runtime.Instance, blob: *runtime.Instance, encoding_name: webidl.Opt(runtime.DOMString)) anyerror!void {
    return readOperation(instance, blob, .text, if (encoding_name.wasPassed()) encoding_name.value.asSlice() else null);
}

/// The abort() method steps.
///
/// Spec: https://w3c.github.io/FileAPI/#dfn-abort
pub fn call_abort(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return;
    // 1. If this's state is "empty" or if this's state is "done" set this's
    //    result to null and terminate this algorithm.
    if (internal.state != .loading) {
        internal.setResult(null);
        return;
    }
    // 2. If this's state is "loading" set this's state to "done" and set
    //    this's result to null.
    internal.state = .done;
    internal.setResult(null);
    // 3. If there are any tasks from this on the file reading task source in
    //    an affiliated task queue, then remove those tasks from that task
    //    queue.
    // 4. Terminate the algorithm for the read method being processed.
    if (internal.operation) |op| {
        internal.operation = null;
        op.terminate();
    }
    // 5. Fire a progress event called abort at this.
    fireProgressEvent(instance, "abort");
    // 6. If this's state is not "loading", fire a progress event called
    //    loadend at this.
    if (internal.state != .loading) fireProgressEvent(instance, "loadend");
}

/// fr's "read operation" given `blob`, `read_type` and an optional
/// `encoding_name`, steps 1-10.
///
/// Spec: https://w3c.github.io/FileAPI/#readOperation
fn readOperation(instance: *runtime.Instance, blob: *runtime.Instance, read_type: ReadType, encoding_name: ?[]const u8) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // 1. If fr's state is "loading", throw an InvalidStateError DOMException.
    if (internal.state == .loading) return error.InvalidStateError;

    // 5-9, and 10's reading. "Let stream be the result of calling get stream
    // on blob", read chunk by chunk "in parallel", appending each to bytes:
    // a Blob's bytes are in memory and never change, so the chunks its
    // stream yields are those bytes, in order, and reading them here is
    // reading them in parallel with nothing between. What stays observable
    // is the tasks 10 queues, which `ReadOperation` queues.
    const op = try ReadOperation.create(instance, blob, read_type, encoding_name);

    // 2. Set fr's state to "loading".
    internal.state = .loading;
    // 3. Set fr's result to null.
    internal.setResult(null);
    // 4. Set fr's error to null.
    internal.setError(null, null);

    internal.operation = op;
    // 10.2. The first chunk read - or the end, for an empty blob - queues a
    //       task to fire a progress event called loadstart at fr.
    op.queue(.loadstart);
    // 10.4.3. A chunk read queues a progress event, "if roughly 50ms have
    //         passed since these steps were last invoked" - they never were,
    //         at the first chunk, and the rest arrive within the same
    //         instant. An empty blob has no chunk, and no progress.
    if (op.bytes.len > 0) op.queue(.progress);
    // 10.5. The end queues a task to run the rest.
    op.queue(.done);
}

/// A read operation in flight: the bytes read, what "package data" needs,
/// and the tasks it has queued. A FileReader has at most one that abort()
/// can reach; a task of a terminated one does nothing.
const ReadOperation = struct {
    allocator: std.mem.Allocator,
    reader: *runtime.Instance,
    /// Holds the reader's wrapper while its tasks are to come: script need
    /// not keep the reader to hear its events (`new FileReader()` read and
    /// let go).
    keep: same_object.Pin = .{},
    read_type: ReadType,
    /// "bytes": the blob's, read. Owned.
    bytes: []u8,
    /// blob's type, for "package data". Owned.
    blob_type: []u8,
    /// encodingName, for "package data" (Text). Owned.
    encoding_name: ?[]u8,
    /// abort() terminated it, its last task ran, or the reader went: its
    /// tasks do nothing.
    terminated: bool = false,
    /// Tasks queued and not yet run or dropped.
    queued: u32 = 0,

    const Step = enum { loadstart, progress, done };

    fn create(reader: *runtime.Instance, blob: *runtime.Instance, read_type: ReadType, encoding_name: ?[]const u8) !*ReadOperation {
        const allocator = reader.ctx.allocator;
        const bytes = try allocator.dupe(u8, blob_bytes.bytesOf(blob) orelse "");
        errdefer allocator.free(bytes);
        var blob_type = try interfaces.Blob.get_type(blob);
        defer blob_type.deinit(blob.ctx.allocator);
        const type_copy = try allocator.dupe(u8, blob_type.asSlice());
        errdefer allocator.free(type_copy);
        const encoding_copy: ?[]u8 = if (encoding_name) |e| try allocator.dupe(u8, e) else null;
        errdefer if (encoding_copy) |e| allocator.free(e);
        const self = try allocator.create(ReadOperation);
        self.* = .{
            .allocator = allocator,
            .reader = reader,
            .read_type = read_type,
            .bytes = bytes,
            .blob_type = type_copy,
            .encoding_name = encoding_copy,
        };
        self.keep.hold(reader);
        return self;
    }

    /// Queue a task on the file reading task source to run `step`, on the
    /// reader's realm's event loop - a window's, or a worker's own (every
    /// worker runs its own loop on its own thread).
    fn queue(self: *ReadOperation, step: Step) void {
        const task = self.allocator.create(Task) catch return;
        task.* = .{ .op = self, .step = step };
        const ctx = self.reader.ctx;
        if (ctx.getOptionalEventLoop()) |loop| {
            self.queued += 1;
            loop.queueTask(.{ .callback = Task.run, .context = task, .drop = Task.drop });
            return;
        }
        // Nowhere to queue it (a bare realm with no event loop - a unit
        // test's): the steps run now, which is better than never.
        self.allocator.destroy(task);
        self.runStep(step);
        self.maybeFree();
    }

    /// abort() step 3-4, the reader going, or the operation's end: its
    /// queued tasks do nothing, and it is freed once none is left.
    fn terminate(self: *ReadOperation) void {
        self.terminated = true;
        self.keep.release();
        self.maybeFree();
    }

    fn maybeFree(self: *ReadOperation) void {
        if (!self.terminated or self.queued > 0) return;
        self.allocator.free(self.bytes);
        self.allocator.free(self.blob_type);
        if (self.encoding_name) |e| self.allocator.free(e);
        self.allocator.destroy(self);
    }

    /// A task from the event loop: enter the reader's realm and run `step`,
    /// ending as a task there does. A realm whose tasks are not run any more
    /// - its document was destroyed (HTML "destroy a document" step 7) or its
    /// realm ended - never sees the read finish: the operation ends here, and
    /// with it the hold on the reader's wrapper (Blink: FileReader's
    /// ContextDestroyed terminates it). The caller frees it (`maybeFree`).
    fn runStep(self: *ReadOperation, step: Step) void {
        if (self.terminated) return;
        var run: StepRun = .{ .op = self, .step = step };
        engine.runTaskInRealm(self.reader.ctx, StepRun.steps, &run) catch {
            // The reader - held until here - must not name an operation that
            // is about to be freed.
            if (getInternal(self.reader)) |internal| {
                if (internal.operation == self) internal.operation = null;
            }
            self.terminated = true;
            self.keep.release();
        };
    }

    const Task = struct {
        op: *ReadOperation,
        step: Step,

        fn run(context: ?*anyopaque) void {
            const task: *Task = @ptrCast(@alignCast(context.?));
            const op = task.op;
            const step = task.step;
            op.allocator.destroy(task);
            op.queued -= 1;
            defer op.maybeFree();
            op.runStep(step);
        }

        /// A task that will never run: its loop is going, and so is the
        /// reader's realm.
        fn drop(context: ?*anyopaque) void {
            const task: *Task = @ptrCast(@alignCast(context.?));
            const op = task.op;
            op.allocator.destroy(task);
            op.queued -= 1;
            op.maybeFree();
        }
    };

    const StepRun = struct {
        op: *ReadOperation,
        step: Step,

        fn steps(data: ?*anyopaque) void {
            const self: *StepRun = @ptrCast(@alignCast(data.?));
            const op = self.op;
            switch (self.step) {
                .loadstart => fireProgressEvent(op.reader, "loadstart"),
                .progress => fireProgressEvent(op.reader, "progress"),
                .done => op.finish(),
            }
        }
    };

    /// Step 10.5: the stream is done - "set fr's state ... and abort this
    /// algorithm".
    fn finish(self: *ReadOperation) void {
        const reader = self.reader;
        const internal = getInternal(reader) orelse return;
        // The algorithm ends here: abort() no longer reaches it, and no task
        // of it is left to run. (The reader's wrapper stays held until this
        // task's steps are over: `terminate` runs after them, in Task.run.)
        if (internal.operation == self) internal.operation = null;
        self.terminated = true;
        defer self.keep.release();

        // 1. Set fr's state to "done".
        internal.state = .done;
        // 2. Let result be the result of package data given bytes, type,
        //    blob's type, and encodingName.
        if (self.packageData()) |result| {
            // 4.1. Set fr's result to result.
            internal.setResult(result);
            // 4.2. Fire a progress event called load at the fr.
            fireProgressEvent(reader, "load");
        } else |_| {
            // 3. If package data threw an exception error: (only failing to
            //    allocate the value can: a NotReadableError, as for a read
            //    that fails)
            // 3.1. Set fr's error to error.
            self.setReadError(internal);
            // 3.2. Fire a progress event called error at fr.
            fireProgressEvent(reader, "error");
        }
        // 5. If fr's state is not "loading", fire a progress event called
        //    loadend at the fr. (A load or error listener may have started
        //    another read.)
        if (internal.state != .loading) fireProgressEvent(reader, "loadend");
    }

    fn setReadError(self: *ReadOperation, internal: *InternalState) void {
        const realm = self.reader.ctx;
        const exception = engine.createDOMException(realm, "NotReadableError", "The blob could not be read.") catch return;
        internal.setError(exception, engine.convertToPlatformObject(realm, exception.value));
    }

    /// Blob "package data" given bytes, this's type, blob's type and
    /// encodingName, in the reader's realm. OWNED.
    ///
    /// Spec: https://w3c.github.io/FileAPI/#blob-package-data
    fn packageData(self: *ReadOperation) !engine.Owned {
        const realm = self.reader.ctx;
        const allocator = self.allocator;
        switch (self.read_type) {
            // ArrayBuffer: a new ArrayBuffer whose contents are bytes.
            .array_buffer => return engine.createArrayBuffer(realm, self.bytes),
            // BinaryString: bytes as a binary string, every byte a code
            // unit of equal value.
            .binary_string => {
                const text = try infra.bytes.isomorphicDecodeToUtf8(allocator, self.bytes);
                defer allocator.free(text);
                return engine.retainValue(realm, runtime.JSValue.fromStringRef(text));
            },
            .text => {
                const text = try self.decodeText();
                defer allocator.free(text);
                return engine.retainValue(realm, runtime.JSValue.fromStringRef(text));
            },
            // DataURL: bytes as a data: URL, with the blob's type. For a
            // blob with no type the spec returns one "without a media-type"
            // (and calls this underspecified: FileAPI issue 104); every
            // browser, and WPT's filereader_readAsDataURL.any.js, uses
            // application/octet-stream, which is what this does.
            .data_url => {
                const media_type = if (self.blob_type.len > 0) self.blob_type else "application/octet-stream";
                const Base64 = std.base64.standard.Encoder;
                const prefix = try std.fmt.allocPrint(allocator, "data:{s};base64,", .{media_type});
                defer allocator.free(prefix);
                const url = try allocator.alloc(u8, prefix.len + Base64.calcSize(self.bytes.len));
                defer allocator.free(url);
                @memcpy(url[0..prefix.len], prefix);
                _ = Base64.encode(url[prefix.len..], self.bytes);
                return engine.retainValue(realm, runtime.JSValue.fromStringRef(url));
            },
        }
    }

    /// Package data's Text steps: bytes decoded with the encoding named,
    /// else the blob type's charset, else UTF-8 - a BOM overriding each.
    /// OWNED, as UTF-8.
    fn decodeText(self: *ReadOperation) ![]u8 {
        const allocator = self.allocator;
        // 1. Let encoding be failure.
        var charset: ?*const encoding.encoding.Encoding = null;
        // 2. If the encodingName is present, set encoding to the result of
        //    getting an encoding from encodingName.
        if (self.encoding_name) |name| charset = encoding.getEncoding(name);
        // 3. If encoding is failure, and mimeType is present:
        if (charset == null and self.blob_type.len > 0) {
            // 3.1. Let type be the result of parse a MIME type given
            //      mimeType.
            if (try mimesniff.parseMimeType(allocator, self.blob_type)) |parsed| {
                var mime_type = parsed;
                defer mime_type.deinit();
                // 3.2. If type is not failure, set encoding to the result of
                //      getting an encoding from type's parameters["charset"].
                if (charsetOf(mime_type)) |label| {
                    const label_bytes = try allocator.alloc(u8, label.len);
                    defer allocator.free(label_bytes);
                    for (label, label_bytes) |c, *b| b.* = @truncate(c);
                    charset = encoding.getEncoding(label_bytes);
                }
            }
        }
        // 4. If encoding is failure, then set encoding to UTF-8.
        // 5. Decode bytes using fallback encoding encoding, and return the
        //    result.
        const code_units = encoding.hooks.decode(allocator, self.bytes, charset orelse &encoding.encoding.UTF_8) catch return error.OutOfMemory;
        defer allocator.free(code_units);
        // A decoder's output is scalar values: no surrogate is unpaired.
        return std.unicode.utf16LeToUtf8Alloc(allocator, code_units) catch |err| switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            else => unreachable,
        };
    }

    /// `mime_type`'s parameters["charset"], if it exists. (Its map compares
    /// slice keys by address, so this compares the text.)
    fn charsetOf(mime_type: mimesniff.MimeType) ?[]const u16 {
        const name = std.unicode.utf8ToUtf16LeStringLiteral("charset");
        for (mime_type.parameters.entries.items()) |entry| {
            if (std.mem.eql(u16, entry.key, name)) return entry.value;
        }
        return null;
    }
};

/// "Fire a progress event called e" at `reader`: a ProgressEvent that does
/// not bubble and is not cancelable, fired by the user agent (trusted).
/// An event nothing wrapped is freed after; one a listener kept is the
/// wrapper cache's.
fn fireProgressEvent(reader: *runtime.Instance, comptime name: []const u8) void {
    const event = interfaces.ProgressEvent.call_constructor(
        reader.ctx,
        runtime.DOMString.initInterned(name),
        webidl.Opt(dictionaries.ProgressEventInit).notPassed(),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    _ = EventTargetImpl.dispatchTrusted(reader, event) catch {};
    event.releaseIfUnwrapped(generation);
}
