//! engine.evaluateReplScript on V8 [repl_mode]: console input evaluated in
//! REPL mode through an inspector session of the agent's own.
//!
//! V8 13.1 has REPL scripts - top-level `await`, a `let` or `class` declared
//! again - only behind its inspector: v8::debug::EvaluateGlobal's repl flag
//! is internal (src/debug/debug-interface.h), and the public route is the
//! DevTools protocol's Runtime.evaluate with `replMode: true`, dispatched to
//! a V8InspectorSession (v8-inspector.h). That is Chrome DevTools' console
//! and Deno's REPL (deno cli/tools/repl/session.rs, an in-process session the
//! same way). The session and its inspector are the AGENT's: made on the
//! console's first use (protocol_agents.replSessionOf), ended with the agent
//! (protocol_agents.endAgent) - never process-wide, never per thread.
//!
//! A REPL script always completes through a promise (of {".repl_result":
//! value}), so the inspector answers when that settles - from a promise job,
//! at a microtask checkpoint of the agent - and the C++ side
//! (v8_wrapper.cpp, CraneReplSession) turns the answer back into the value:
//! the completion value or the exception, unwrapped from the response's
//! remote object. Each evaluation is an `Evaluation` record here, by its
//! protocol call id, and ends one of three ways - exactly one of the
//! host's steps runs (engine.PromiseReactionSteps):
//! - the answer comes: `fulfilled` with the completion value, or `rejected`
//!   with the exception;
//! - its realm ends first: the record is on the realm's list
//!   (realm_finalizers.zig), which the realm's end drains, and `dropped`
//!   runs - the inspector's answer for it, if one ever comes, finds no
//!   record;
//! - the agent ends first: `Session.end` drops every record still waiting.
//! The one exception is the answer that comes back inside the dispatch:
//! input that does not parse. When it is input that ended too soon
//! (`incomplete`, decided by the C++ side from V8's message), or the session
//! could not evaluate at all, no step runs and the operation says so.

const std = @import("std");
const engine = @import("engine");

const ffi = @import("ffi.zig");
const support = @import("protocol_support.zig");
const realm_finalizers = @import("realm_finalizers.zig");
const protocol_scripts = @import("protocol_scripts.zig");
const protocol_agents = @import("protocol_agents.zig");

const Context = engine.Context;
const Error = engine.Error;

/// What CraneReplSession's responses come to (ffi.ReplOutcome `kind`).
const Kind = enum(c_int) { completed = 0, threw = 1, failed = 2 };

/// An agent's console session: the C++ inspector session, and the
/// evaluations it has not answered. On the agent's AgentRecord
/// (`repl`); every field is read and written on the agent's own thread.
pub const Session = struct {
    allocator: std.mem.Allocator,
    isolate: *ffi.Isolate,
    native: *ffi.ReplSession,
    /// The next protocol call id.
    next_id: c_int = 1,
    /// The evaluations not answered yet. A list, not a map: a console has
    /// one input waiting, and a few more only when it stopped waiting for
    /// some (their realm's end or the agent's drops them).
    evaluations: std.ArrayListUnmanaged(*Evaluation) = .empty,
    /// The realms made known to the inspector, each on its realm's list
    /// (its end tells the inspector).
    realms: std.ArrayListUnmanaged(*KnownRealm) = .empty,
    /// The call `evaluateReplScript` is dispatching (0: none), and what its
    /// answer came to when it came inside the dispatch.
    dispatching: c_int = 0,
    dispatched: Dispatched = .waiting,
    /// `end` ran: no evaluation is waited for any more.
    ended: bool = false,

    const Dispatched = enum { waiting, answered, incomplete, failed };

    /// A session for `isolate` (entered), its state allocated with
    /// `allocator`.
    pub fn create(allocator: std.mem.Allocator, isolate: *ffi.Isolate) Error!*Session {
        const self = try allocator.create(Session);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .isolate = isolate, .native = undefined };
        self.native = ffi.v8_ReplSession_New(isolate, onOutcome, self) orelse return error.OperationFailed;
        return self;
    }

    /// The agent's end begins (before protocol_agents.forgetAgent): every
    /// evaluation still waiting is dropped - its host's `dropped` runs - and
    /// every realm still known is forgotten by the inspector, while the
    /// realms' contexts still exist. Answers that come after this find no
    /// record.
    pub fn end(self: *Session) void {
        self.ended = true;
        while (self.evaluations.pop()) |evaluation| {
            evaluation.node.unlink();
            const host = evaluation.take();
            if (host.steps.dropped) |dropped| dropped(host.data);
        }
        for (self.realms.items) |known| {
            known.node.unlink();
            self.allocator.destroy(known);
        }
        self.realms.clearRetainingCapacity();
        ffi.v8_ReplSession_DetachContexts(self.native);
    }

    /// The agent's end, last (protocol_agents.endAgent: after its final
    /// microtask checkpoints, before its isolate is disposed, with the
    /// isolate entered): the inspector is deleted, then this.
    pub fn destroy(self: *Session) void {
        if (!self.ended) self.end();
        ffi.v8_ReplSession_Delete(self.native);
        self.evaluations.deinit(self.allocator);
        self.realms.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// The evaluation answered by call `id`, taken off the list; null when
    /// none waits for it.
    fn takeEvaluation(self: *Session, id: c_int) ?*Evaluation {
        for (self.evaluations.items, 0..) |evaluation, i| {
            if (evaluation.id == id) return self.evaluations.swapRemove(i);
        }
        return null;
    }

    /// The inspector's context id for `realm` (whose context is entered as
    /// `context`), made known to it on first use - and then put on the
    /// realm's list, so that its end tells the inspector.
    fn contextIdOf(self: *Session, context: *ffi.Context, list: ?*realm_finalizers.List) Error!c_int {
        const id = ffi.v8_ReplSession_Register(self.native, context);
        if (id <= 0) return error.OperationFailed;
        for (self.realms.items) |known| if (known.context_id == id) return id;
        const l = list orelse return id;
        const known = try self.allocator.create(KnownRealm);
        errdefer self.allocator.destroy(known);
        known.* = .{ .session = self, .context_id = id };
        try self.realms.append(self.allocator, known);
        l.add(&known.node) catch {
            _ = self.realms.pop();
            return error.OperationFailed;
        };
        return id;
    }
};

/// A realm the inspector knows: on the realm's list until it ends.
const KnownRealm = struct {
    session: *Session,
    context_id: c_int,
    node: realm_finalizers.Node = .{ .drop = ended },

    /// The realm ended (realm_finalizers.List.drain; unlinked already): the
    /// inspector forgets its context now, while it exists - any evaluation
    /// of it still waiting is answered as failed, and its own record, on the
    /// same list, is dropped by the drain.
    fn ended(node: *realm_finalizers.Node) void {
        const self: *KnownRealm = @fieldParentPtr("node", node);
        const session = self.session;
        for (session.realms.items, 0..) |known, i| {
            if (known == self) {
                _ = session.realms.swapRemove(i);
                break;
            }
        }
        const id = self.context_id;
        session.allocator.destroy(self);
        ffi.v8_ReplSession_ContextEnded(session.native, id);
    }
};

/// One evaluation the inspector has not answered.
const Evaluation = struct {
    session: *Session,
    id: c_int,
    steps: *const engine.PromiseReactionSteps,
    data: ?*anyopaque,
    /// On its realm's list until it ends.
    node: realm_finalizers.Node = .{ .drop = droppedByRealm },

    const Host = struct { steps: *const engine.PromiseReactionSteps, data: ?*anyopaque };

    /// Free the record; what the host's step needs.
    fn take(self: *Evaluation) Host {
        const host: Host = .{ .steps = self.steps, .data = self.data };
        self.session.allocator.destroy(self);
        return host;
    }

    /// The realm ended first (realm_finalizers.List.drain; unlinked already).
    fn droppedByRealm(node: *realm_finalizers.Node) void {
        const self: *Evaluation = @fieldParentPtr("node", node);
        _ = self.session.takeEvaluation(self.id);
        const host = self.take();
        if (host.steps.dropped) |dropped| dropped(host.data);
    }
};

/// engine.evaluateReplScript.
pub fn evaluateReplScript(realm: Context, source: []const u8, steps: *const engine.PromiseReactionSteps, data: ?*anyopaque) Error!engine.ReplInput {
    const entered = try support.enter(realm);
    defer entered.leave();
    // A realm whose end is under way evaluates nothing: its list is drained.
    const list = realm_finalizers.listOf(realm);
    if (list) |l| if (l.ended) return error.OperationFailed;
    const session = protocol_agents.replSessionOf(entered.isolate) orelse return error.OperationFailed;
    const context_id = try session.contextIdOf(entered.context(), list);

    const id = session.next_id;
    session.next_id +%= 1;
    if (session.next_id <= 0) session.next_id = 1;
    var message: std.Io.Writer.Allocating = .init(session.allocator);
    defer message.deinit();
    writeRequest(&message.writer, id, context_id, source) catch return error.OutOfMemory;

    const evaluation = try session.allocator.create(Evaluation);
    evaluation.* = .{ .session = session, .id = id, .steps = steps, .data = data };
    session.evaluations.append(session.allocator, evaluation) catch {
        session.allocator.destroy(evaluation);
        return error.OutOfMemory;
    };
    if (list) |l| l.add(&evaluation.node) catch {
        _ = session.takeEvaluation(id);
        session.allocator.destroy(evaluation);
        return error.OperationFailed;
    };

    // The answer for input that does not parse comes back inside the
    // dispatch (`dispatched`); any other at a later microtask checkpoint.
    session.dispatching = id;
    session.dispatched = .waiting;
    defer session.dispatching = 0;
    const written = message.written();
    ffi.v8_ReplSession_Dispatch(session.native, written.ptr, written.len);
    return switch (session.dispatched) {
        .waiting, .answered => .evaluating,
        .incomplete => .incomplete,
        .failed => error.OperationFailed,
    };
}

/// The answer to call `call_id` (CraneReplSession::sendResponse): run the
/// host's step for it, in the job running now - or, inside the dispatch of
/// input that ended too soon or could not be evaluated, none.
fn onOutcome(host: ?*anyopaque, call_id: c_int, kind_raw: c_int, value: ?*ffi.Value, incomplete: bool) callconv(.c) void {
    const session: *Session = @ptrCast(@alignCast(host.?));
    defer if (value) |v| ffi.v8_Global_Dispose(v);
    const kind: Kind = std.enums.fromInt(Kind, kind_raw) orelse .failed;
    const evaluation = session.takeEvaluation(call_id) orelse return;
    evaluation.node.unlink();
    if (call_id == session.dispatching) {
        // Inside evaluateReplScript's dispatch: the input did not parse, or
        // the session could not evaluate it. Neither is an outcome: no step
        // runs, and `data` stays the caller's.
        if (kind == .failed or (kind == .threw and incomplete)) {
            session.dispatched = if (kind == .failed) .failed else .incomplete;
            session.allocator.destroy(evaluation);
            return;
        }
        session.dispatched = .answered;
    }
    const steps = evaluation.take();
    // HTML HostEnqueuePromiseJob: the host's step runs as a promise job does,
    // between "prepare to run script" and "clean up after running script",
    // as protocol_promises.zig's reactions run.
    const scope = protocol_scripts.prepareToRunJob(session.isolate);
    defer if (scope) |s| protocol_scripts.cleanUpAfterRunningJob(s);
    const argument: engine.JSValue = if (value) |v| support.borrowed(v) else engine.JSValue.jsUndefined;
    switch (kind) {
        .completed => if (steps.steps.fulfilled) |fulfilled| return fulfilled(steps.data, argument),
        .threw => if (steps.steps.rejected) |rejected| return rejected(steps.data, argument),
        .failed => {},
    }
    if (steps.steps.dropped) |dropped| dropped(steps.data);
}

/// The DevTools protocol request: Runtime.evaluate of `source` in context
/// `context_id`, in REPL mode, its values bound in the session's object
/// group - ASCII JSON, every other character escaped (\uXXXX), so that
/// V8's 8-bit StringView reads it as written.
fn writeRequest(out: *std.Io.Writer, id: c_int, context_id: c_int, source: []const u8) std.Io.Writer.Error!void {
    try out.print("{{\"id\":{d},\"method\":\"Runtime.evaluate\",\"params\":{{\"expression\":", .{id});
    try writeJsonString(out, source);
    try out.print(",\"contextId\":{d},\"replMode\":true,\"objectGroup\":\"crane-repl\",\"returnByValue\":false,\"generatePreview\":false,\"includeCommandLineAPI\":false,\"silent\":false}}}}", .{context_id});
}

/// `text` (UTF-8) as an ASCII JSON string: every non-ASCII code point as
/// \uXXXX (a surrogate pair past U+FFFF), an invalid byte as U+FFFD.
fn writeJsonString(out: *std.Io.Writer, text: []const u8) std.Io.Writer.Error!void {
    try out.writeByte('"');
    var i: usize = 0;
    while (i < text.len) {
        const c = text[i];
        if (c < 0x80) {
            switch (c) {
                '"' => try out.writeAll("\\\""),
                '\\' => try out.writeAll("\\\\"),
                '\n' => try out.writeAll("\\n"),
                '\r' => try out.writeAll("\\r"),
                '\t' => try out.writeAll("\\t"),
                0...8, 0x0b, 0x0c, 0x0e...0x1f, 0x7f => try out.print("\\u{x:0>4}", .{c}),
                else => try out.writeByte(c),
            }
            i += 1;
            continue;
        }
        const length = std.unicode.utf8ByteSequenceLength(c) catch {
            try out.writeAll("\\ufffd");
            i += 1;
            continue;
        };
        if (i + length > text.len) {
            try out.writeAll("\\ufffd");
            i += 1;
            continue;
        }
        const code_point = std.unicode.utf8Decode(text[i .. i + length]) catch {
            try out.writeAll("\\ufffd");
            i += 1;
            continue;
        };
        if (code_point > 0xFFFF) {
            const v = code_point - 0x10000;
            try out.print("\\u{x:0>4}\\u{x:0>4}", .{ 0xD800 + (v >> 10), 0xDC00 + (v & 0x3FF) });
        } else {
            try out.print("\\u{x:0>4}", .{code_point});
        }
        i += length;
    }
    try out.writeByte('"');
}

test "a request's expression is ASCII JSON, every other character escaped" {
    var buffer: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer buffer.deinit();
    try writeJsonString(&buffer.writer, "a\"\\\n\x01é😀\xff");
    try std.testing.expectEqualStrings("\"a\\\"\\\\\\n\\u0001\\u00e9\\ud83d\\ude00\\ufffd\"", buffer.written());
}
