//! An animation's current ready promise and current finished promise (Web
//! Animations 4.5.7, 4.5.11): one Promise object at a time, replaced by a
//! new one at the steps that say so.
//!
//! Made lazily: until script reads the attribute, nothing can observe the
//! object, so only its STATE is kept (a ready promise "initially resolved",
//! a finished promise "initially pending") and the object is made on the
//! first read in that state. Once made, the resolving state is owned only
//! while the promise is pending; a settled promise is kept by a traced edge
//! from the animation (dom.style.font_loading.OwnerPromise's model, Q7), so
//! no root keeps an animation's realm.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");

pub const Status = enum { pending, fulfilled, rejected };

pub const Slot = struct {
    /// The traced edge the settled object hangs on (one per member).
    slot: engine.TracedSlot,
    status: Status,
    /// A promise object exists: pending (`capability`) or settled (traced).
    made: bool = false,
    /// OWNED while the made promise is pending.
    capability: ?engine.PromiseCapability = null,

    /// The current promise, made now if script never asked for it. OWNED.
    pub fn get(self: *Slot, owner: *runtime.Instance) !engine.Owned {
        if (!self.made) {
            switch (self.status) {
                .pending => self.capability = try engine.createPromise(owner.ctx),
                .fulfilled => {
                    const promise = try engine.createResolvedPromise(owner.ctx, .{ .instance = owner });
                    defer promise.release();
                    engine.traceValue(owner, promise.borrow(), self.slot);
                },
                // A rejected promise is always replaced at once (cancel,
                // reset pending tasks): never read in this state unmade.
                .rejected => return error.InvalidStateError,
            }
            self.made = true;
        }
        if (self.capability) |capability| return engine.retainValue(owner.ctx, capability.promise);
        return engine.tracedValue(owner, self.slot) orelse error.InvalidStateError;
    }

    /// "Resolve the current ... promise with animation". Nothing for a
    /// promise already settled.
    pub fn resolve(self: *Slot, owner: *runtime.Instance) void {
        if (self.status != .pending) return;
        self.status = .fulfilled;
        const capability = if (self.capability) |*pending| pending else return;
        engine.resolvePromise(capability, .{ .instance = owner }) catch {};
        self.keepSettled(owner);
    }

    /// "Reject the current ... promise with a DOMException named
    /// AbortError" and "set its [[PromiseIsHandled]] to true".
    pub fn rejectAbort(self: *Slot, owner: *runtime.Instance) void {
        if (self.status != .pending) return;
        self.status = .rejected;
        const capability = if (self.capability) |*pending| pending else return;
        if (engine.createDOMException(owner.ctx, "AbortError", "The animation was aborted.")) |exception| {
            defer exception.release();
            engine.rejectPromise(capability, exception.borrow()) catch {};
        } else |_| {}
        engine.markPromiseAsHandled(owner.ctx, capability.promise);
        self.keepSettled(owner);
    }

    /// The current promise is replaced by a new one in `status` (pending,
    /// or "a new resolved Promise"). Script keeps the old object, if it read
    /// it; the animation keeps nothing of it.
    pub fn replace(self: *Slot, owner: *runtime.Instance, status: Status) void {
        self.forget(owner);
        self.status = status;
    }

    pub fn isResolved(self: *const Slot) bool {
        return self.status == .fulfilled;
    }

    /// The owner goes: its own teardown. `owner_live` is false when the
    /// collector took the owner's wrapper (and the edge with it).
    pub fn deinit(self: *Slot, owner: *runtime.Instance, owner_live: bool) void {
        if (self.capability) |*capability| {
            engine.releasePromiseCapability(capability);
        } else if (self.made and owner_live) engine.forgetTracedChild(owner, self.slot);
        self.capability = null;
        self.made = false;
    }

    fn keepSettled(self: *Slot, owner: *runtime.Instance) void {
        const capability = if (self.capability) |*pending| pending else return;
        engine.traceValue(owner, capability.promise, self.slot);
        engine.releasePromiseCapability(capability);
        self.capability = null;
    }

    fn forget(self: *Slot, owner: *runtime.Instance) void {
        // A pending made promise has no edge yet; a settled one has.
        if (self.capability) |*capability| {
            engine.releasePromiseCapability(capability);
        } else if (self.made) engine.forgetTracedChild(owner, self.slot);
        self.capability = null;
        self.made = false;
    }
};
