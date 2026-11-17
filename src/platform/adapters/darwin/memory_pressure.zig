//! The darwin platform's memory-pressure observer (docs/platform-protocol.md
//! 3.3 and 7): one DISPATCH_SOURCE_TYPE_MEMORYPRESSURE source per Browser,
//! whose handler posts a `memory_pressure` event through the Browser's
//! EventSink.
//!
//! All three browsers listen to the same source on macOS (read 2026-11-16):
//!
//! - Chromium: components/memory_pressure/
//!   system_memory_pressure_evaluator_mac.cc - mask WARN | CRITICAL | NORMAL,
//!   on the default global queue; its handler reads the level again from
//!   sysctl kern.memorystatus_vm_pressure_level.
//! - WebKit: Source/WTF/wtf/cocoa/MemoryPressureHandlerCocoa.mm - the same
//!   three (and the process-limit ones); its handler reads the event with
//!   dispatch_source_get_data.
//! - Firefox: widget/cocoa/nsAppShell.mm - the same three, on the main
//!   queue; its handler reads dispatch_source_get_data.
//!
//! Crane's: the three levels, on the default global queue (no main queue is
//! Crane's to use: a host may not run one), the level read from the event's
//! data (WebKit and Firefox; the majority). The data is a mask: when two
//! events were merged before the handler ran, the highest level named wins.
//!
//! `stop` cancels the source and waits for its cancel handler, which
//! libdispatch runs only after a running event handler has returned and
//! after which it runs no other: no post is made after `stop` returns.
//!
//! The observer's fields are written on the Browser's thread and read by the
//! handlers on a dispatch queue's threads. libdispatch orders the two - a
//! handler runs only after dispatch_resume, the cancel handler only after
//! dispatch_source_cancel, `stop` goes on only after the cancel handler -
//! but it does so inside itself, where the order is no part of this file
//! and ThreadSanitizer does not see it (Zig's libtsan has no libdispatch
//! interceptors: every darwin-bound test that made a Browser's platform
//! state was reported as a race between `start` and the cancel handler).
//! So each hand-over is also an acquire/release on one word of the
//! observer (`order`): `start` releases what it wrote, a handler acquires on
//! entry and releases on exit, and `stop` acquires after the cancel handler
//! before it touches the observer again or its owner frees it. This is not
//! there to quiet the sanitizer: the pairs are correct on their own - they
//! give the hand-overs the ordering the language's memory model asks for
//! without relying on what libdispatch does inside - and they make the
//! order visible to any tool that reads this file's own operations. Four
//! atomic adds in a Browser's life (one in `start`, two in the cancel
//! handler, one in `stop`) and two for each event the OS reports.
//!
//! The source is compiled in only for a darwin target: the conformance test
//! builds every platform on every host.

const std = @import("std");
const builtin = @import("builtin");
const platform = @import("platform");

const enabled = builtin.os.tag.isDarwin();

// <dispatch/source.h>: DISPATCH_MEMORYPRESSURE_*.
const pressure_normal: usize = 0x01;
const pressure_warn: usize = 0x02;
const pressure_critical: usize = 0x04;

/// DISPATCH_TIME_FOREVER.
const time_forever: u64 = ~@as(u64, 0);

// libdispatch (libSystem), the plain C entry points: no blocks.
extern "c" fn dispatch_get_global_queue(identifier: isize, flags: usize) ?*anyopaque;
extern "c" fn dispatch_source_create(source_type: *const anyopaque, handle: usize, mask: usize, queue: ?*anyopaque) ?*anyopaque;
extern "c" fn dispatch_set_context(object: *anyopaque, context: ?*anyopaque) void;
extern "c" fn dispatch_source_set_event_handler_f(source: *anyopaque, handler: *const fn (?*anyopaque) callconv(.c) void) void;
extern "c" fn dispatch_source_set_cancel_handler_f(source: *anyopaque, handler: *const fn (?*anyopaque) callconv(.c) void) void;
extern "c" fn dispatch_source_get_data(source: *anyopaque) usize;
extern "c" fn dispatch_source_cancel(source: *anyopaque) void;
extern "c" fn dispatch_resume(object: *anyopaque) void;
extern "c" fn dispatch_release(object: *anyopaque) void;
extern "c" fn dispatch_semaphore_create(value: isize) ?*anyopaque;
extern "c" fn dispatch_semaphore_signal(semaphore: *anyopaque) isize;
extern "c" fn dispatch_semaphore_wait(semaphore: *anyopaque, timeout: u64) isize;

/// The level a memory-pressure event's data names: the highest of the
/// levels in the mask.
pub fn levelOf(data: usize) platform.MemoryPressureLevel {
    if (data & pressure_critical != 0) return .critical;
    if (data & pressure_warn != 0) return .warning;
    return .normal;
}

pub const Observer = struct {
    /// The Browser's sink, BORROWED until `stop` returns.
    events: platform.EventSink = undefined,
    /// The dispatch source, from `start` until `stop` has seen it canceled.
    source: ?*anyopaque = null,
    /// Signaled by the source's cancel handler.
    canceled: ?*anyopaque = null,
    /// The hand-overs between the Browser's thread and the handlers' (the
    /// header): its value means nothing, its acquire/release order does.
    order: std.atomic.Value(u32) = .init(0),

    /// One side of a hand-over: take what the other side published, and
    /// publish what this side wrote.
    fn handOver(self: *Observer) void {
        _ = self.order.fetchAdd(1, .acq_rel);
    }

    /// Make the source and resume it. `self` is at its final address: it is
    /// the source's context. With no source to be had the Browser has no
    /// observer, and is told nothing.
    pub fn start(self: *Observer, events: platform.EventSink) void {
        if (comptime !enabled) return;
        self.events = events;
        const canceled = dispatch_semaphore_create(0) orelse return;
        // DISPATCH_SOURCE_TYPE_MEMORYPRESSURE is the address of this symbol.
        const source_type = @extern(*const anyopaque, .{ .name = "_dispatch_source_type_memorypressure" });
        // DISPATCH_QUEUE_PRIORITY_DEFAULT: the default global queue.
        const source = dispatch_source_create(source_type, 0, pressure_normal | pressure_warn | pressure_critical, dispatch_get_global_queue(0, 0)) orelse {
            dispatch_release(canceled);
            return;
        };
        self.canceled = canceled;
        self.source = source;
        dispatch_set_context(source, self);
        dispatch_source_set_event_handler_f(source, handleEvent);
        dispatch_source_set_cancel_handler_f(source, handleCancel);
        // Published: the handlers may run from the resume on.
        self.handOver();
        dispatch_resume(source);
    }

    /// Cancel the source and wait until its cancel handler has run: no
    /// event handler runs then or later, so nothing is posted after this
    /// returns. Nothing for an observer that never started.
    pub fn stop(self: *Observer) void {
        if (comptime !enabled) return;
        const source = self.source orelse return;
        const canceled = self.canceled.?;
        dispatch_source_cancel(source);
        _ = dispatch_semaphore_wait(canceled, time_forever);
        // The handlers are done with the observer: what they read is this
        // thread's again, to write and to free.
        self.handOver();
        // Only now: the event handler reads `source` until it is canceled.
        self.source = null;
        self.canceled = null;
        dispatch_release(source);
        dispatch_release(canceled);
    }

    fn handleEvent(context: ?*anyopaque) callconv(.c) void {
        const self: *Observer = @ptrCast(@alignCast(context.?));
        self.handOver();
        defer self.handOver();
        const source = self.source orelse return;
        const event: platform.PlatformEvent = .{ .kind = .memory_pressure, .memory_pressure = levelOf(dispatch_source_get_data(source)) };
        self.events.post(self.events.context, &event);
    }

    fn handleCancel(context: ?*anyopaque) callconv(.c) void {
        const self: *Observer = @ptrCast(@alignCast(context.?));
        self.handOver();
        const canceled = self.canceled.?;
        // The last touch of the observer on this thread: `stop` wakes on
        // the signal and takes it back.
        self.handOver();
        _ = dispatch_semaphore_signal(canceled);
    }
};
