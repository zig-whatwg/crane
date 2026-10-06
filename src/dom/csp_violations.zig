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
//! global whose URL is HTTP(S) reports 200 and any other 0; report-uri and
//! report-to (§5.5 steps 4-5). Its source file, line and column (§2.4.1
//! step 2) are the running script's, when the engine can say
//! (engine.runningScriptLocation: V8 can; JavaScriptCore and QuickJS
//! cannot, and report none).
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
const policy_containers = @import("policy_containers.zig");
const trusted_types = @import("trusted_types.zig");

const log = std.log.scoped(.csp_violations);

pub const Reporter = csp.violation_events.Reporter;
pub const Violation = csp.violation_events.Violation;

/// CSP §4.2.3 "Should element's inline type behavior be blocked by Content
/// Security Policy?" for `element`'s inline `inline_type` behaviour with
/// `source`: true for "Blocked". `matching` is what §6.7.3 reads of the
/// element - its nonce when it is nonceable, whether it is a parser-inserted
/// script.
///
/// For each policy of the element's node document's CSP list, the inline
/// check of the directive §6.8.4 picks (csp.inline_check); a policy it
/// blocks reports a violation - the effective directive for inline checks,
/// resource "inline", the element, a sample under 'report-sample' - and
/// blocks when it is enforced. A monitored policy reports and lets it
/// through.
///
/// The violation's global (step 3.1.3, "the current settings object's
/// global object") is the element's node document's window. That is what
/// Blink, Gecko and WebKit report to, and what WPT reads: an attribute set
/// from the parent on an element of a child frame's document reports to the
/// child frame (securitypolicyviolation/targeting-for-inline-handler-on-
/// subframe-element.html) - while the parent's script is the current one.
/// A document with no window reports to no one, and still blocks.
///
/// Spec: https://w3c.github.io/webappsec-csp/#should-block-inline
pub fn shouldBlockInline(
    element: *runtime.Instance,
    inline_type: csp.inline_check.InlineType,
    source: []const u8,
    matching: csp.inline_check.Element,
) bool {
    // 1. "Assert: element is not null."
    // "element's Document's global object's CSP list": a Window's is its
    // associated Document's policy container's (§4.2.2); a document with no
    // window is read the same way, its own container.
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return false;
    const container = policy_containers.of(document) orelse return false;
    if (container.csp_list.policies.items.len == 0) return false;
    const window: ?*runtime.Instance = interfaces.Document.get_defaultView(document) catch null;
    // 2. Let result be "Allowed".
    var blocked = false;
    // 3. For each policy of the CSP list:
    for (container.csp_list.policies.items) |*policy| {
        // 3.1.1. A directive whose inline check allows it is skipped.
        const directive = csp.inline_check.blockingDirective(policy, matching, inline_type, source) orelse continue;
        // 3.1.2-3.1.7. A violation of the effective directive for inline
        // checks, its resource "inline", its element the element, a sample
        // when the directive asks for one - reported.
        if (window) |w| reportViolation(w, &.{
            .policy = policy,
            .effective_directive = csp.inline_check.effectiveDirectiveForInlineCheck(inline_type),
            .resource = .@"inline",
            .element = element,
            .sample = csp.violation_events.sampleFor(directive, source),
        });
        // 3.1.8. "If policy's disposition is "enforce", then set result to
        // "Blocked"."
        if (policy.disposition == .enforce) blocked = true;
    }
    // 4. Return result.
    return blocked;
}

/// CSP 4.2.4 "Should navigation request of type be blocked by Content
/// Security Policy?" for HTML "navigate to a javascript: URL" step 5's
/// request: its URL `url` (serialized), its policy container's CSP list
/// `csp_list` - the initiator's - and its client's global `client`, whose
/// default policy runs and to which violations go (null: neither).
/// `isValidUrl` is the URL parser's verdict on a string.
///
/// Step 3 runs both pre-navigation checks a directive has:
/// require-trusted-types-for's (Trusted Types 4.2.1.1,
/// dom.trusted_types.javascriptUrlPreNavigationCheck), which may set the
/// request's URL to the default policy's value, and form-action's, for a
/// `navigation_type` of form submission. Step 4, for a result still
/// "Allowed", is the javascript: URL's inline check of type "navigation" -
/// on the URL as step 3 left it. Within step 3, the Trusted Types check
/// runs for every policy before form-action's does: the two never apply to
/// the same navigation except a form submitted to a javascript: URL.
///
/// Returns what the navigation goes on with: the URL as it was, a
/// rewritten one (OWNED by `allocator`), or nothing.
///
/// `container` is the navigated navigable's container - an iframe navigated
/// to the URL - or null (a popup, the top-level page). Not in the spec,
/// stated: step 4's violations name it as their element, so one whose
/// container is in the client's document fires at the container and bubbles
/// from there (CSP 5.5 step 3.1 sends one whose container is elsewhere to
/// the document). Blink's FrameLoader::StartNavigation passes the frame's
/// owner element to its javascript: URL inline check, and WPT listens on
/// the iframe (securitypolicyviolation/script-sample.html, "JavaScript URLs
/// in iframes").
///
/// Spec: https://w3c.github.io/webappsec-csp/#should-block-navigation-request
pub fn shouldJavascriptNavigationBeBlocked(
    allocator: std.mem.Allocator,
    csp_list: *const csp.CSPList,
    client: ?*runtime.Instance,
    container: ?*runtime.Instance,
    url: []const u8,
    navigation_type: csp.navigation_check.NavigationType,
    isValidUrl: *const fn (allocator: std.mem.Allocator, url: []const u8) bool,
) error{OutOfMemory}!trusted_types.PreNavigation {
    const reporter: ?Reporter = if (client) |global| reporterFor(global) else null;
    var with_element: ElementReporter = .{ .global = client, .element = container };
    // 1-3: require-trusted-types-for's pre-navigation check.
    const result = try trusted_types.javascriptUrlPreNavigationCheck(allocator, csp_list, client, url, isValidUrl);
    const current_url: []const u8 = switch (result) {
        .rewritten => |rewritten| rewritten,
        else => url,
    };
    const request = csp.navigation_check.NavigationRequest.ofSerialized(current_url);
    // 1-3: form-action's.
    var blocked = result == .blocked;
    if (csp.navigation_check.preNavigationChecks(csp_list, request, navigation_type, reporter) == .blocked) blocked = true;
    // 4. "If result is "Allowed"": the javascript: URL's inline check.
    if (!blocked and csp.navigation_check.javascriptUrlInlineChecks(csp_list, request, with_element.reporter()) == .blocked) blocked = true;
    // 5. Return result.
    if (!blocked) return result;
    if (result == .rewritten) allocator.free(result.rewritten);
    return .blocked;
}

/// A reporter for `global` (null: none) whose violations name `element`.
const ElementReporter = struct {
    global: ?*runtime.Instance,
    element: ?*runtime.Instance,

    fn reporter(self: *ElementReporter) ?Reporter {
        if (self.global == null) return null;
        return .{ .context = self, .report = &reportWithElement };
    }

    fn reportWithElement(context: *anyopaque, violation: *const Violation) void {
        const self: *ElementReporter = @ptrCast(@alignCast(context));
        var named = violation.*;
        if (named.element == null) named.element = self.element;
        reportViolation(self.global.?, &named);
    }
};

/// The javascript: URL's inline check against the TARGET's policies: the
/// CSP list of `target_window`'s document - the active document of the
/// navigable a javascript: URL is about to run in - for each policy the
/// inline check of type "navigation" upon `url`, each violation reported to
/// `target_window`. True when an enforced policy blocks it.
///
/// Not in the spec, stated: HTML "navigate to a javascript: URL" checks only
/// the initiator's policies (step 5, `shouldJavascriptNavigationBeBlocked`).
/// Chrome and Firefox check the target's as well, after the initiator's -
/// Blink's ScriptController::ExecuteJavaScriptURL asks the target window's
/// ContentSecurityPolicy::AllowInline(kNavigation) - and WPT asserts both and
/// that order (content-security-policy/navigation/to-javascript-parent-
/// initiated-child-csp.html, -check-csp-order.html); the spec gap is
/// whatwg/html#4651. Trusted Types' pre-navigation check stays the
/// initiator's alone (trusted-types/navigate-to-javascript-url-010.html).
/// A caller skips it when the target is the initiator: its list was just
/// checked.
pub fn shouldTargetBlockJavascriptUrl(target_window: *runtime.Instance, url: []const u8) bool {
    const document = windowDocument(target_window) orelse return false;
    const container = policy_containers.of(document) orelse return false;
    if (container.csp_list.policies.items.len == 0) return false;
    const request = csp.navigation_check.NavigationRequest.ofSerialized(url);
    return csp.navigation_check.javascriptUrlInlineChecks(&container.csp_list, request, reporterFor(target_window)) == .blocked;
}

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

/// A reporter for a global that can end before the reporter's last use: it
/// reports only while `global` is still the instance it was made for (its
/// slab generation unchanged) and its realm still runs.
///
/// A navigation's request holds one. Its client is the source document's
/// settings object (HTML "create navigation params by fetching": the source
/// snapshot params' fetch client), but the fetch's liveness follows the
/// navigable being navigated - so the source document, and its global, can
/// go while the fetch is in flight, and every redirect runs main fetch's
/// CSP check again. The holder keeps it at a fixed address for as long as a
/// request holds its `reporter()`.
pub const GuardedReporter = struct {
    global: *runtime.Instance,
    generation: u64,

    /// For violations of the policies of `realm`'s global - a document's
    /// relevant global, for its `ctx` - if the realm has one.
    pub fn forRealm(realm: runtime.Context) ?GuardedReporter {
        const record = realm.getRealm() orelse return null;
        const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
        return .{ .global = global, .generation = runtime.SlabAllocator.generationOf(global) };
    }

    pub fn reporter(self: *GuardedReporter) Reporter {
        return .{ .context = self, .report = &reportWhileAlive };
    }

    fn reportWhileAlive(context: *anyopaque, violation: *const Violation) void {
        const self: *GuardedReporter = @ptrCast(@alignCast(context));
        if (runtime.SlabAllocator.generationOf(self.global) != self.generation) return;
        if (!self.global.ctx.hasEngine()) return;
        reportViolation(self.global, violation);
    }
};

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
    /// §2.4.1 step 2: the running script's URL, stripped for reports, and
    /// position; "" and 0 when no script was running.
    source_file: []const u8 = "",
    line_number: u32 = 0,
    column_number: u32 = 0,

    fn deinit(self: *ViolationTask) void {
        const allocator = self.allocator;
        for ([_][]const u8{ self.document_uri, self.referrer, self.blocked_uri, self.effective_directive, self.original_policy, self.sample, self.source_file }) |owned| {
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
                const root = shadowIncludingRoot(e);
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
            .sourceFile = self.source_file,
            .sample = runtime.DOMString.initInterned(self.sample),
            .disposition = self.disposition,
            .statusCode = self.status_code,
            .lineNumber = self.line_number,
            .columnNumber = self.column_number,
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

/// DOM "shadow-including root": `node`'s root's host's shadow-including
/// root when its root is a shadow root, else its root. Walked here through
/// ShadowRoot's host: Node.getRootNode({composed: true}) does not cross a
/// shadow root yet (its TODO), so an element in a shadow tree read as
/// disconnected and its violation went to the document
/// (securitypolicyviolation/targeting-for-inline-style-in-shadow-dom.html).
fn shadowIncludingRoot(node: *runtime.Instance) ?*runtime.Instance {
    var current = node;
    // A chain of shadow roots is a handful deep; the bound only stops a
    // corrupt tree from looping here.
    var depth: usize = 0;
    while (depth < 64) : (depth += 1) {
        const root = interfaces.Node.call_getRootNode(current, webidl.Opt(dictionaries.GetRootNodeOptions).passed(.{})) catch return null;
        // A root that is no shadow root has no host: it is the answer.
        current = interfaces.ShadowRoot.get_host(root) catch return root;
    }
    return null;
}

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
    // §2.4.1 step 2: "If the user agent is currently executing script, and
    // can extract a source file's URL, line number, and column number from
    // the global, set violation's source file, line number, and column
    // number accordingly" - the script running in the global's agent, now,
    // as the violation is made.
    if (global.ctx.agent) |agent| {
        if (engine.runningScriptLocation(agent, allocator) catch null) |location| {
            defer location.deinit(allocator);
            task.source_file = try csp.violation_events.sourceFileForReports(allocator, location.url);
            task.line_number = location.line;
            task.column_number = location.column;
        }
    }

    // 3. "Queue a task": on the global's event loop - a window's, or a
    // worker's own (every worker runs its own loop on its own thread).
    if (global.ctx.getOptionalEventLoop()) |loop| {
        loop.queueTask(.{ .callback = ViolationTask.run, .context = task, .drop = ViolationTask.drop });
        return;
    }
    // None (a bare realm, a unit test's): the realm is in its event loop's
    // step already, a task boundary - fire now.
    ViolationTask.run(task);
}
