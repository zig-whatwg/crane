//! CSP §5.5 "Report a violation", the global's side: a violation of a
//! global's policy (csp.violation_events.Violation) becomes a
//! securitypolicyviolation event, fired in a queued task at the element
//! that caused it - while that element is connected to the Window's
//! document - else at the Window's document, or at the WorkerGlobalScope.
//!
//! Finders reach a global through a `Reporter` (`reporterFor`): a request
//! takes its client's ("populate request from client"), the inline script
//! check its document's window's. Everything is reached through interfaces
//! and dom.fire_event; no impl is named.
//!
//! The violation's global-side fields (§2.4.1): its url is the global's
//! (the realm's document URL - a worker's creation URL), its referrer a
//! Window's document's referrer. Not modelled, stated: its status - the
//! HTTP status of the resource the global was made from is not kept, so a
//! global whose URL is HTTP(S) reports 200 and any other 0; source file,
//! line and column (§2.4.1 step 2); report-uri and report-to (§5.5 steps
//! 4-5).
//!
//! Spec: https://w3c.github.io/webappsec-csp/#report-violation

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const enums = @import("enums");
const webidl = @import("webidl");
const csp = @import("csp");
const fire_event = @import("fire_event.zig");

const log = std.log.scoped(.csp_violations);

pub const Reporter = csp.violation_events.Reporter;
pub const Violation = csp.violation_events.Violation;

/// The reporter for violations of `global`'s policies (a Window's or a
/// WorkerGlobalScope's).
pub fn reporterFor(global: *runtime.Instance) Reporter {
    return .{ .context = global, .report = &report };
}

/// The reporter for violations of the policies of `realm`'s global, if the
/// realm has one.
pub fn reporterForRealm(realm: runtime.Context) ?Reporter {
    const record = realm.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    return reporterFor(global);
}

/// Report `violation` of `global`'s policy: §5.5 steps 1-3, the event in a
/// queued task. Nothing is reported when the task cannot be made.
pub fn reportViolation(global: *runtime.Instance, violation: *const Violation) void {
    queueViolationTask(global, violation) catch |err| {
        log.debug("securitypolicyviolation not queued: {s}", .{@errorName(err)});
    };
}

fn report(context: *anyopaque, violation: *const Violation) void {
    reportViolation(@ptrCast(@alignCast(context)), violation);
}

/// What the queued task fires, copied out of the violation and its global
/// when the violation happens: by the time the task runs the policy may be
/// gone (a request's clone of its client's container is), and the
/// document's URL may have moved on.
const ViolationTask = struct {
    allocator: std.mem.Allocator,
    global: *runtime.Instance,
    global_generation: u64,
    /// The violation's element and its slab generation: the element is not
    /// kept alive by the task, so one collected meanwhile (its generation
    /// moved on) is no target.
    element: ?*runtime.Instance,
    element_generation: u64,
    document_uri: []const u8,
    referrer: []const u8,
    blocked_uri: []const u8,
    effective_directive: []const u8,
    original_policy: []const u8,
    sample: []const u8,
    disposition: enums.SecurityPolicyViolationEventDisposition,
    status_code: u16,

    fn deinit(self: *ViolationTask) void {
        const allocator = self.allocator;
        for ([_][]const u8{ self.document_uri, self.referrer, self.blocked_uri, self.effective_directive, self.original_policy, self.sample }) |owned| {
            allocator.free(owned);
        }
        allocator.destroy(self);
    }

    fn run(data: ?*anyopaque) void {
        const self: *ViolationTask = @ptrCast(@alignCast(data.?));
        defer self.deinit();
        // The global can go while the task waits; a realm that has gone runs
        // nothing.
        if (runtime.SlabAllocator.generationOf(self.global) != self.global_generation) return;
        if (!self.global.ctx.hasEngine()) return;
        engine.runTaskInRealm(self.global.ctx, steps, self) catch {};
    }

    fn drop(data: ?*anyopaque) void {
        const self: *ViolationTask = @ptrCast(@alignCast(data.?));
        self.deinit();
    }

    /// §5.5 step 3's steps, in the global's realm.
    fn steps(data: ?*anyopaque) void {
        const self: *ViolationTask = @ptrCast(@alignCast(data.?));
        const at = self.eventTarget() orelse return;
        self.fire(at) catch |err| log.debug("securitypolicyviolation not fired: {s}", .{@errorName(err)});
    }

    /// Steps 3.1-3.2: the target.
    fn eventTarget(self: *ViolationTask) ?*runtime.Instance {
        const document = windowDocument(self.global);
        var element = self.element;
        if (element) |e| {
            if (runtime.SlabAllocator.generationOf(e) != self.element_generation) element = null;
        }
        // 3.1. "If target is not null, and global is a Window, and target's
        // shadow-including root is not global's associated Document, set
        // target to null."
        if (element) |e| {
            if (document) |d| {
                const root = interfaces.Node.call_getRootNode(e, webidl.Opt(dictionaries.GetRootNodeOptions).passed(.{ .composed = true })) catch null;
                if (root == null or root.? != d) element = null;
            }
        }
        if (element) |e| return e;
        // 3.2. "If target is null: set target to violation's global object;
        // if target is a Window, set target to its associated Document."
        return document orelse self.global;
    }

    /// Step 3.3: "fire an event named securitypolicyviolation that uses the
    /// SecurityPolicyViolationEvent interface at target", bubbles and
    /// composed true, its attributes from the violation.
    fn fire(self: *ViolationTask, at: *runtime.Instance) !void {
        const init: dictionaries.SecurityPolicyViolationEventInit = .{
            .base = .{ .bubbles = true, .composed = true },
            .documentURI = self.document_uri,
            .referrer = self.referrer,
            .blockedURI = self.blocked_uri,
            // "Both effectiveDirective and violatedDirective are the same
            // value."
            .effectiveDirective = runtime.DOMString.initInterned(self.effective_directive),
            .violatedDirective = runtime.DOMString.initInterned(self.effective_directive),
            .originalPolicy = runtime.DOMString.initInterned(self.original_policy),
            .sourceFile = "",
            .sample = runtime.DOMString.initInterned(self.sample),
            .disposition = self.disposition,
            .statusCode = self.status_code,
            .lineNumber = 0,
            .columnNumber = 0,
        };
        const event = try interfaces.SecurityPolicyViolationEvent.call_constructor(
            self.global.ctx,
            runtime.DOMString.initInterned("securitypolicyviolation"),
            webidl.Opt(dictionaries.SecurityPolicyViolationEventInit).passed(init),
        );
        // A listener can keep the event; its wrapper then owns it.
        const generation = runtime.SlabAllocator.generationOf(event);
        defer event.releaseIfUnwrapped(generation);
        _ = try fire_event.dispatchTrusted(at, event);
    }
};

/// The Window `global`'s associated Document, or null for any other global.
fn windowDocument(global: *runtime.Instance) ?*runtime.Instance {
    if (!std.mem.eql(u8, global.vtable.name, "Window")) return null;
    return interfaces.Window.get_document(global) catch null;
}

/// §5.5 steps 1-3: copy what the event needs, then queue the task.
fn queueViolationTask(global: *runtime.Instance, violation: *const Violation) !void {
    const allocator = global.ctx.allocator;
    const task = try allocator.create(ViolationTask);
    task.* = .{
        .allocator = allocator,
        .global = global,
        .global_generation = runtime.SlabAllocator.generationOf(global),
        .element = if (violation.element) |e| @ptrCast(@alignCast(e)) else null,
        .element_generation = 0,
        .document_uri = "",
        .referrer = "",
        .blocked_uri = "",
        .effective_directive = "",
        .original_policy = "",
        .sample = "",
        .disposition = switch (violation.policy.disposition) {
            .enforce => ._enforce_,
            .report => ._report_,
        },
        .status_code = 0,
    };
    errdefer task.deinit();
    if (task.element) |e| task.element_generation = runtime.SlabAllocator.generationOf(e);

    // documentURI: §5.4 on the violation's url, the global's URL.
    const url = global.ctx.documentUrl() orelse "";
    task.document_uri = try csp.violation_events.stripUrlForReports(allocator, url);
    // statusCode: stated above.
    task.status_code = if (std.mem.startsWith(u8, url, "http:") or std.mem.startsWith(u8, url, "https:")) 200 else 0;
    // referrer: §2.4.1 step 3, a Window's document's referrer, stripped.
    if (windowDocument(global)) |document| {
        const referrer = interfaces.Document.get_referrer(document) catch "";
        defer if (referrer.len > 0) allocator.free(referrer);
        if (referrer.len > 0) task.referrer = try csp.violation_events.stripUrlForReports(allocator, referrer);
    }
    task.blocked_uri = try csp.violation_events.blockedUri(allocator, violation.resource);
    task.effective_directive = try allocator.dupe(u8, violation.effective_directive);
    task.original_policy = try csp.parsing.serializePolicy(allocator, violation.policy);
    task.sample = try allocator.dupe(u8, violation.sample);

    // 3. "Queue a task": on the global's event loop. A worker's realm has
    // none of its own and runs its tasks as timers on the page's.
    if (global.ctx.getOptionalEventLoop()) |loop| {
        loop.queueTask(.{ .callback = ViolationTask.run, .context = task, .drop = ViolationTask.drop });
        return;
    }
    if (global.ctx.getOptionalTimer()) |timer| {
        // Known leak window (the Q14 class): a timer that never fires - its
        // worker torn down first - never frees its task; the queued
        // worker-event-loop fix covers it.
        if (timer.setTimeout(0, ViolationTask.run, task) != 0) return;
    }
    // Neither: the realm is in its event loop's step already, a task
    // boundary - fire now.
    ViolationTask.run(task);
}
