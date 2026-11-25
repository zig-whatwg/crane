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
const file = @import("file");
const FileReader = interfaces.FileReader;
const same_object = @import("dom").same_object;
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

/// FileReader's own teardown: the generated chain runs EventTarget's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        state.own._internal = null;
        internal.deinit();
    }
    // The event handlers and listeners go with EventTarget's state. GC layer
    // handles slab freeing - do NOT call runtime.Instance.deinit().
}

/// Constructor implementation
///
/// Spec: https://w3c.github.io/FileAPI/#dom-filereader-filereader
///
/// "The FileReader() constructor, when invoked, must return a new FileReader
/// object" - its state "empty", its result and error null.
pub fn call_constructor(instance: *runtime.Instance) !void {
    const ctx = instance.ctx;
    const internal = try InternalState.init(ctx.allocator);
    internal.reader = instance;
    instance.getState(State).own._internal = internal;
}

/// The readyState getter steps: 0 for "empty", 1 for "loading", 2 for
/// "done".
pub fn get_readyState(instance: *runtime.Instance) anyerror!u16 {
    const internal = getInternal(instance) orelse return @backingInt(ReadyState.empty);
    return @backingInt(internal.state);
}

/// The result getter steps are to return this's result. The reader keeps
/// holding it; the binding gets a hold of its own.
pub fn get_result(instance: *runtime.Instance) anyerror!?typedefs.DOMStringOrArrayBuffer {
    const internal = getInternal(instance) orelse return null;
    if (!internal.has_result) return null;
    const result = engine.tracedValue(instance, result_slot) orelse return null;
    // fr's result is a string or an ArrayBuffer (File API 6.2). A string is
    // its copy - the binding frees it, as a DOMString result's - and an
    // ArrayBuffer the hold handed over, released once set
    // (conv.unionReturnIsOwned).
    if (engine.typeOf(instance.ctx, result.value) == .string) {
        defer result.release();
        const text = try engine.convertToDOMString(instance.ctx, result.value, instance.ctx.allocator);
        return .{ .domstring = runtime.DOMString.initOwned(text) };
    }
    return .{ .array_buffer = result.take() };
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

// The event handler IDL attributes (onload, onprogress, ...) are the
// generated interface's: HTML's getter and setter, in EventTarget's map.

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
    // Retain the Blob's data now and defer reading to the queued task so a
    // file-backed Blob is read asynchronously (and abort() before the task
    // runs cancels cleanly without reading disk).
    const op = try ReadOperation.create(instance, blob, read_type, encoding_name);

    // 2. Set fr's state to "loading".
    internal.state = .loading;
    // 3. Set fr's result to null.
    internal.setResult(null);
    // 4. Set fr's error to null.
    internal.setError(null, null);

    internal.operation = op;
    // Queue the initial read task: on success it fires loadstart (step 10.2)
    // and queues progress (when non-empty) + done; on failure it runs step
    // 10.6 (state = done, error = DOMException, fire error, then loadend).
    op.queue(.start);
}

/// A read operation in flight: the retained BlobData, the bytes read once the
/// read starts, what "package data" needs, and the tasks it has queued. A
/// FileReader has at most one that abort() can reach; a task of a terminated
/// one does nothing.
const ReadOperation = struct {
    allocator: std.mem.Allocator,
    reader: *runtime.Instance,
    /// Holds the reader's wrapper while its tasks are to come: script need
    /// not keep the reader to hear its events (`new FileReader()` read and
    /// let go).
    keep: same_object.Pin = .{},
    read_type: ReadType,
    /// Retained BlobData to read when the initial task runs (released once
    /// read or when the operation is freed).
    blob_data: ?*file.BlobData,
    /// "bytes": the blob's, materialized when `.start` runs. Owned.
    bytes: []u8 = &.{},
    /// blob's type, for "package data". Owned.
    blob_type: []u8,
    /// encodingName, for "package data" (Text). Owned.
    encoding_name: ?[]u8,
    /// abort() terminated it, its last task ran, or the reader went: its
    /// tasks do nothing.
    terminated: bool = false,
    /// Tasks queued and not yet run or dropped.
    queued: u32 = 0,
    /// Active runStep calls on the stack: freeing waits until all return so a
    /// reentrant abort() inside a listener cannot free `self` under us.
    busy: u32 = 0,

    const Step = enum { start, progress, done };

    fn create(reader: *runtime.Instance, blob: *runtime.Instance, read_type: ReadType, encoding_name: ?[]const u8) !*ReadOperation {
        const allocator = reader.ctx.allocator;
        var blob_type = try interfaces.Blob.get_type(blob);
        defer blob_type.deinit(blob.ctx.allocator);
        const type_copy = try allocator.dupe(u8, blob_type.asSlice());
        errdefer allocator.free(type_copy);
        const encoding_copy: ?[]u8 = if (encoding_name) |e| try allocator.dupe(u8, e) else null;
        errdefer if (encoding_copy) |e| allocator.free(e);
        const self = try allocator.create(ReadOperation);
        const retained = if (blob_bytes.dataOf(blob)) |d| d.retain() else null;
        self.* = .{
            .allocator = allocator,
            .reader = reader,
            .read_type = read_type,
            .blob_data = retained,
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
        if (!self.terminated or self.queued > 0 or self.busy > 0) return;
        if (self.blob_data) |d| d.deinit();
        if (self.bytes.len > 0) self.allocator.free(self.bytes);
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
        self.busy += 1;
        defer {
            self.busy -= 1;
            self.maybeFree();
        }
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
                .start => op.startAndLoadStart(),
                .progress => fireProgressEvent(op.reader, "progress"),
                .done => op.finish(),
            }
        }
    };

    /// Step 10.1-10.6: read the Blob's bytes; on failure run step 10.6
    /// (error then loadend, no loadstart); on success fire loadstart (step
    /// 10.2) and queue progress (when non-empty) + done.
    fn startAndLoadStart(self: *ReadOperation) void {
        if (self.blob_data) |data| {
            self.blob_data = null;
            defer data.deinit();
            self.bytes = data.materialize(self.allocator) catch |err| {
                self.failRead(err);
                return;
            };
        }
        // Step 10.2: first chunk fulfilled -> fire loadstart.
        fireProgressEvent(self.reader, "loadstart");
        // A loadstart listener may have called abort() or started a new read.
        if (self.terminated) return;
        // Step 10.4.3: non-empty blob queues progress.
        if (self.bytes.len > 0) self.queue(.progress);
        // Step 10.5: end queues done.
        self.queue(.done);
    }

    /// Step 10.6: stream errored - set state to "done", set error to the
    /// DOMException, fire error, then loadend if state is not "loading".
    fn failRead(self: *ReadOperation, err: file.FileReadError) void {
        const reader = self.reader;
        const internal = getInternal(reader) orelse return;
        if (internal.operation == self) internal.operation = null;
        self.terminated = true;
        defer self.keep.release();

        // 10.6.1. Set fr's state to "done".
        internal.state = .done;
        // 10.6.2. Set fr's error to error.
        self.setDOMExceptionError(internal, err);
        // 10.6.3. Fire a progress event called error at fr.
        fireProgressEvent(reader, "error");
        // 10.6.4. If fr's state is not "loading", fire loadend at fr.
        if (internal.state != .loading) fireProgressEvent(reader, "loadend");
    }

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
            self.setDOMExceptionError(internal, error.NotReadableError);
            // 3.2. Fire a progress event called error at fr.
            fireProgressEvent(reader, "error");
        }
        // 5. If fr's state is not "loading", fire a progress event called
        //    loadend at the fr. (A load or error listener may have started
        //    another read.)
        if (internal.state != .loading) fireProgressEvent(reader, "loadend");
    }

    fn setDOMExceptionError(self: *ReadOperation, internal: *InternalState, err: file.FileReadError) void {
        const realm = self.reader.ctx;
        const name: []const u8 = switch (err) {
            error.NotFoundError => "NotFoundError",
            error.NotReadableError, error.OutOfMemory => "NotReadableError",
        };
        const message: []const u8 = switch (err) {
            error.NotFoundError => "A requested file or directory could not be found at the time an operation was processed.",
            error.NotReadableError, error.OutOfMemory => "The requested file could not be read, typically due to permission problems that have occurred after a reference to a file was acquired.",
        };
        const exception = engine.createDOMException(realm, name, message) catch return;
        internal.setError(exception, engine.convertToPlatformObject(realm, exception.value));
    }

    /// Blob "package data" given bytes, this's type, blob's type and
    /// encodingName, in the reader's realm. OWNED.
    ///
    /// Spec: https://w3c.github.io/FileAPI/#blob-package-data
    fn packageData(self: *ReadOperation) !engine.Owned {
        const realm = self.reader.ctx;
        // Creating the engine buffer already copies the bytes; do not make
        // an intermediate native copy for the ArrayBuffer arm.
        if (self.read_type == .array_buffer) return engine.createArrayBuffer(realm, self.bytes);
        const result = try file.algorithms.packageData(
            self.allocator,
            self.bytes,
            switch (self.read_type) {
                .array_buffer => unreachable,
                .binary_string => .BinaryString,
                .text => .Text,
                .data_url => .DataURL,
            },
            self.blob_type,
            self.encoding_name,
        );
        defer self.allocator.free(result.string);
        return engine.retainValue(realm, runtime.JSValue.fromStringRef(result.string));
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
    _ = @import("dom").fire_event.dispatchTrusted(reader, event) catch {};
    event.releaseIfUnwrapped(generation);
}
