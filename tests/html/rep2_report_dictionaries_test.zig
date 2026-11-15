//! Lane rep2: a ReportingObserver gives script its reports as the Reporting
//! spec's dictionaries (w3c/reporting#284; the user's ruling of 2026-11-14;
//! WebKit 326027@main).
//!
//! Reporting §4.3 step 3 makes a Report dictionary for each report, and
//! WebIDL 3.2.18 converts it to a new ordinary object: Object.prototype, the
//! members in lexicographical order, no toJSON. Its body converts with the
//! body dictionary of its report type, as WebKit does (Report.idl's union of
//! body dictionaries): every member the reporting spec initialized exists,
//! null included, and nothing else. Plain objects structured-clone, so a
//! worker or frame can post its reports
//! (html/cross-origin-embedder-policy/reporting-to-worker-owner.https.html,
//! cache-storage-reporting-*.https.html). No Report or body interface object
//! exists (reporting/historical.any.js).
//!
//! Each test runs on a thread of its own (a Browser's agent belongs to the
//! thread that made it) and on std.testing.allocator.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const dom = @import("dom");
const helpers = @import("edges_node_holders_helpers.zig");

fn openPage() !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    _ = try browser.runEventLoopBlocking(20);
    return browser;
}

/// Runs `script`, an expression whose value is the list of failed checks
/// joined with "; " - empty when every check held.
fn expectNoFailures(browser: *browser_mod.Browser, script: []const u8) !void {
    const page = browser.current_context orelse return error.NoPage;
    const failures = try page.evaluateScriptToString(script, testing.allocator);
    defer testing.allocator.free(failures);
    try testing.expectEqualStrings("", failures);
}

fn globalOf(browser: *browser_mod.Browser) !*@import("runtime").Instance {
    const realm = browser.getRealm() orelse return error.NoRealm;
    return dom.reporting.globalOf(realm) orelse error.NoGlobal;
}

/// A csp-violation body as CSP §5.5 step 5.1 initializes it, the way
/// csp.violation_events.ReportBody.serializeModern writes it: every member,
/// the source location null for a load no script line started.
const csp_body =
    \\{"documentURL":"https://example.test/page","referrer":"","blockedURL":"https://example.test/fail.png",
    \\"effectiveDirective":"img-src","originalPolicy":"img-src 'none'; report-to csp-group","sample":"",
    \\"disposition":"enforce","statusCode":200,"sourceFile":null,"lineNumber":null,"columnNumber":null}
;

fn takenReportIsAPlainObject() !void {
    const browser = try openPage();
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    try page.runScript("globalThis.observer = new ReportingObserver(() => {}); observer.observe();");
    try dom.reporting.generate(try globalOf(browser), "csp-violation", "csp-group", "https://example.test/page", csp_body);
    try expectNoFailures(browser,
        \\(() => {
        \\  const failures = [];
        \\  const check = (ok, what) => { if (!ok) failures.push(what); };
        \\  const records = observer.takeRecords();
        \\  check(Array.isArray(records) && records.length === 1, "one record");
        \\  const report = records[0];
        \\  check(Object.getPrototypeOf(report) === Object.prototype, "report prototype");
        \\  check(JSON.stringify(Object.keys(report)) === '["body","type","url"]', "report keys " + JSON.stringify(Object.keys(report)));
        \\  check(!("toJSON" in report), "report toJSON");
        \\  check(report.type === "csp-violation", "type");
        \\  check(report.url === "https://example.test/page", "url");
        \\  const body = report.body;
        \\  check(Object.getPrototypeOf(body) === Object.prototype, "body prototype");
        \\  check(JSON.stringify(Object.keys(body)) === JSON.stringify(["blockedURL", "columnNumber", "disposition",
        \\    "documentURL", "effectiveDirective", "lineNumber", "originalPolicy", "referrer", "sample", "sourceFile",
        \\    "statusCode"]), "body keys " + JSON.stringify(Object.keys(body)));
        \\  check(!("toJSON" in body), "body toJSON");
        \\  check(body.sourceFile === null && body.lineNumber === null && body.columnNumber === null, "null members exist as null");
        \\  check(body.statusCode === 200 && body.disposition === "enforce" && body.effectiveDirective === "img-src", "member values");
        \\  check(JSON.stringify(structuredClone(report)) === JSON.stringify(report), "structured clone");
        \\  check(observer.takeRecords().length === 0, "takeRecords empties the queue");
        \\  for (const name of ["Report", "ReportBody", "CSPViolationReportBody", "CORPViolationReportBody",
        \\                      "COEPInheritenceViolationReportBody", "CoopAccessViolationReportBody"])
        \\    check(!(name in self), name + " is exposed");
        \\  return failures.join("; ");
        \\})()
    );
}

test "a report taken with takeRecords is a plain Report dictionary, and its csp-violation body has every CSPViolationReportBody member" {
    try helpers.onFreshThread(takenReportIsAPlainObject);
}

fn callbackReportsAreDictionaries() !void {
    const browser = try openPage();
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    try page.runScript(
        \\globalThis.seen = [];
        \\globalThis.observer = new ReportingObserver(reports => seen.push(...reports));
        \\observer.observe();
    );
    const global = try globalOf(browser);
    // Fetch's CORP violation body (with a member no body dictionary has),
    // HTML's inheritance violation body, and Chromium's access report body
    // as dom.coop_reporting writes it: the source location always, one
    // window URL.
    try dom.reporting.generate(global, "coep", "", "https://example.test/page",
        \\{"type":"corp","blockedURL":"https://other.test/a.png","destination":"image","disposition":"enforce","extra":1}
    );
    try dom.reporting.generate(global, "coep", "", "https://example.test/page",
        \\{"type":"worker initialization","blockedURL":"https://example.test/w.js","disposition":"reporting"}
    );
    try dom.reporting.generate(global, "coop-access-violation", "", "https://example.test/page",
        \\{"sourceFile":null,"lineNumber":null,"columnNumber":null,"type":"access-from-coop-page-to-openee","property":"postMessage","openeeURL":"https://example.test/openee"}
    );
    _ = try browser.runEventLoopBlocking(50);
    try expectNoFailures(browser,
        \\(() => {
        \\  const failures = [];
        \\  const check = (ok, what) => { if (!ok) failures.push(what); };
        \\  const keys = o => JSON.stringify(Object.keys(o));
        \\  check(seen.length === 3, "three reports, saw " + seen.length);
        \\  if (seen.length !== 3) return failures.join("; ");
        \\  for (const report of seen) {
        \\    check(Object.getPrototypeOf(report) === Object.prototype, report.type + " report prototype");
        \\    check(Object.getPrototypeOf(report.body) === Object.prototype, report.type + " body prototype");
        \\    check(!("toJSON" in report) && !("toJSON" in report.body), report.type + " toJSON");
        \\  }
        \\  const [corp, worker, access] = seen;
        \\  check(keys(corp.body) === '["blockedURL","destination","disposition","type"]', "corp keys " + keys(corp.body));
        \\  check(corp.body.destination === "image" && corp.body.type === "corp", "corp values");
        \\  check(keys(worker.body) === '["blockedURL","disposition","type"]', "inheritance keys " + keys(worker.body));
        \\  check(worker.body.type === "worker initialization" && worker.body.disposition === "reporting", "inheritance values");
        \\  check(keys(access.body) === '["columnNumber","lineNumber","openeeURL","property","sourceFile","type"]',
        \\    "access keys " + keys(access.body));
        \\  check(!("openerURL" in access.body) && !("otherDocumentURL" in access.body), "access window URLs it does not name");
        \\  check(access.body.openeeURL === "https://example.test/openee", "access openeeURL");
        \\  const cloned = structuredClone(seen);
        \\  check(JSON.stringify(cloned) === JSON.stringify(seen), "structured clone");
        \\  return failures.join("; ");
        \\})()
    );
}

test "a ReportingObserver callback gets plain dictionaries, each body with its own report type's dictionary members" {
    try helpers.onFreshThread(callbackReportsAreDictionaries);
}
