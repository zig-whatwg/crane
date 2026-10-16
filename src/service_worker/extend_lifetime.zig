//! An ExtendableEvent's extended lifetime (Service Workers 4.4): its extend
//! lifetime promises, its pending promises count and its timed out flag -
//! what "active" means, and what the dispatcher waits for after its dispatch
//! (Install and Activate, "WaitForAsynchronousExtensions").
//!
//! The dispatcher - the service worker's own thread, in its realm - makes
//! one for each event it fires and hands it to the event as a construction
//! argument (ExtendableEvent's `lifetime`): waitUntil() adds to it. Blink
//! keeps the same beside its ExtendableEvent, as the event's WaitUntilObserver
//! (modules/service_worker/wait_until_observer.cc). An ExtendableEvent script
//! constructs has none: its isTrusted is false, so waitUntil() throws before
//! asking.
//!
//! Reference counted, on one thread: the dispatcher holds one reference, the
//! event one (released by its teardown), each settling promise's reaction
//! one.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#extendableevent

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const engine = @import("engine");

const log = std.log.scoped(.service_worker);

pub const ExtendLifetime = struct {
    allocator: Allocator,
    refs: u32 = 1,
    /// The event's dispatch flag, as its dispatcher sets it around the
    /// dispatch.
    dispatching: bool = false,
    /// Its pending promises count.
    pending: u32 = 0,
    /// Its timed out flag. Crane imposes no delay, so it stays unset.
    timed_out: bool = false,
    /// One of its extend lifetime promises rejected: the promise to wait for
    /// all of them rejects (Install step 11.3.1.4.3).
    rejected: bool = false,
    /// What the dispatcher does once the event is no longer active after its
    /// dispatch - once.
    settled: ?Settled = null,

    pub const Settled = struct {
        ctx: *anyopaque,
        /// `failed`: a promise rejected, or the event timed out.
        run: *const fn (ctx: *anyopaque, failed: bool) void,
        /// It will never run: free `ctx`.
        drop: *const fn (ctx: *anyopaque) void,
    };

    pub fn create(allocator: Allocator, settled: ?Settled) Allocator.Error!*ExtendLifetime {
        const self = try allocator.create(ExtendLifetime);
        self.* = .{ .allocator = allocator, .settled = settled };
        return self;
    }

    pub fn retain(self: *ExtendLifetime) *ExtendLifetime {
        self.refs += 1;
        return self;
    }

    pub fn release(self: *ExtendLifetime) void {
        self.refs -= 1;
        if (self.refs > 0) return;
        if (self.settled) |settled| settled.drop(settled.ctx);
        self.allocator.destroy(self);
    }

    /// "Active": its timed out flag is unset, and its pending promises count
    /// is above zero or its dispatch flag is set.
    pub fn isActive(self: *const ExtendLifetime) bool {
        return !self.timed_out and (self.pending > 0 or self.dispatching);
    }

    /// The dispatch is over: if nothing extends the event, it is no longer
    /// active now.
    pub fn dispatchEnded(self: *ExtendLifetime) void {
        self.dispatching = false;
        self.checkSettled();
    }

    /// "Add lifetime promise" steps 3-5 - the caller checked 1-2 - for
    /// `value`, the waitUntil() argument, in `realm`: as a promise (WebIDL's
    /// Promise<any> conversion: PromiseResolve), counted until it settles.
    pub fn addLifetimePromise(self: *ExtendLifetime, realm: runtime.Context, value: runtime.JSValue) engine.Error!void {
        const completion = try engine.promiseResolve(realm, value);
        const promise = switch (completion) {
            .normal => |owned| owned,
            .throw => |thrown| {
                defer thrown.release();
                try engine.throwValue(realm, thrown.value);
                return error.ExceptionPending;
            },
        };
        defer promise.release();
        const reaction = try self.allocator.create(Reaction);
        reaction.* = .{ .lifetime = self.retain(), .realm = realm };
        engine.reactToPromise(realm, promise.borrow(), &reaction_steps, reaction) catch |err| {
            reaction.lifetime.release();
            self.allocator.destroy(reaction);
            return err;
        };
        // 3-4. Added; the count goes up even for a promise already settled
        // (its decrement is the reaction's microtask).
        self.pending += 1;
    }

    const reaction_steps: engine.PromiseReactionSteps = .{
        .fulfilled = Reaction.fulfilled,
        .rejected = Reaction.rejectedStep,
        .dropped = Reaction.dropped,
    };

    const decrement_steps: engine.PromiseReactionSteps = .{
        .fulfilled = Reaction.decrement,
        .dropped = Reaction.dropped,
    };

    /// One extend lifetime promise, until it settles.
    const Reaction = struct {
        lifetime: *ExtendLifetime,
        realm: runtime.Context,

        fn fulfilled(data: ?*anyopaque, _: runtime.JSValue) void {
            const self: *Reaction = @ptrCast(@alignCast(data.?));
            self.queueDecrement();
        }

        fn rejectedStep(data: ?*anyopaque, _: runtime.JSValue) void {
            const self: *Reaction = @ptrCast(@alignCast(data.?));
            self.lifetime.rejected = true;
            self.queueDecrement();
        }

        /// Step 5: "upon fulfillment or rejection of promise, queue a
        /// microtask" - one more turn, so a reaction script added to the same
        /// promise still finds the event active.
        fn queueDecrement(self: *Reaction) void {
            engine.queueRealmMicrotask(self.realm, &decrement_steps, self) catch {
                log.debug("no microtask for an extend lifetime promise; settled now", .{});
                decrement(self, runtime.JSValue.jsUndefined);
            };
        }

        /// 5.1-5.2: the count goes down; at zero the event may have settled.
        fn decrement(data: ?*anyopaque, _: runtime.JSValue) void {
            const self: *Reaction = @ptrCast(@alignCast(data.?));
            const lifetime = self.lifetime;
            lifetime.allocator.destroy(self);
            lifetime.pending -= 1;
            lifetime.checkSettled();
            lifetime.release();
        }

        /// The realm ended with the promise pending: the event never
        /// settles here (its worker's end tells the manager).
        fn dropped(data: ?*anyopaque) void {
            const self: *Reaction = @ptrCast(@alignCast(data.?));
            const lifetime = self.lifetime;
            lifetime.allocator.destroy(self);
            lifetime.release();
        }
    };

    /// WaitForAsynchronousExtensions: once the event is not active, its
    /// dispatcher hears whether it failed.
    fn checkSettled(self: *ExtendLifetime) void {
        if (self.isActive()) return;
        const settled = self.settled orelse return;
        self.settled = null;
        settled.run(settled.ctx, self.rejected or self.timed_out);
    }
};
