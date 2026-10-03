//! Trusted Types, the global's side: the enforcement algorithms a sink runs
//! (3.4 "get trusted type compliant string", 3.5 "process value with a
//! default policy", 3.7 "get trusted type compliant attribute value"), over
//! the global's CSP list and its trusted type policy factory's default
//! policy.
//!
//! The API objects are impls, and nothing may name them, so each installs
//! what the algorithms need of it here: TrustedHTML, TrustedScript and
//! TrustedScriptURL make a value and read one's data; TrustedTypePolicy runs
//! a policy's callback (3.3 "get trusted type policy value"); the factory
//! answers its default policy. A global's factory is reached through its
//! settings (`global_settings.Settings.trusted_types`), its CSP list through
//! its policy container, and violations go to `csp_violations`.
//!
//! The CSP halves of the algorithms (4.2.3-4.2.5) are
//! csp.directives.{require_trusted_types,trusted_types}; the tables of 3.8
//! are trusted_types.attributes.
//!
//! Spec: https://w3c.github.io/trusted-types/dist/spec/#algorithms
//!
//! lint-impls: hook for TrustedTypePolicyFactory, TrustedTypePolicy, TrustedHTML, TrustedScript, TrustedScriptURL

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const csp = @import("csp");
const trusted_types = @import("trusted_types");
const process_start = @import("process_start.zig");
const global_settings = @import("global_settings.zig");
const csp_violations = @import("csp_violations.zig");

pub const Kind = trusted_types.Kind;

/// The sink group every sink in the spec belongs to, as the algorithms pass
/// it ("'script' as sinkGroup").
pub const script_sink_group = csp.directives.require_trusted_types.script_sink_group;

/// What TrustedHTML, TrustedScript and TrustedScriptURL each supply.
pub const ValueHooks = struct {
    /// "A new instance of an interface with a type name trustedTypeName,
    /// with its associated data value set to" a copy of `data`, in `realm`.
    create: *const fn (realm: runtime.Context, data: []const u8) anyerror!*runtime.Instance,
    /// `instance`'s associated data when it is an object of this interface -
    /// borrowed for as long as the object lives - else null.
    data_of: *const fn (instance: *runtime.Instance) ?[]const u8,
};

/// What TrustedTypePolicyFactory supplies.
pub const FactoryHooks = struct {
    /// The factory's default policy (2.3.1), or null.
    default_policy: *const fn (factory: *runtime.Instance) ?*runtime.Instance,
};

/// A policy's options (2.3.3) as createPolicy hands them over: each
/// callback BORROWED for the call.
pub const PolicyOptions = struct {
    html: ?engine.CallbackFunction = null,
    script: ?engine.CallbackFunction = null,
    script_url: ?engine.CallbackFunction = null,

    pub fn get(self: PolicyOptions, kind: Kind) ?engine.CallbackFunction {
        return switch (kind) {
            .html => self.html,
            .script => self.script,
            .script_url => self.script_url,
        };
    }
};

/// What TrustedTypePolicy supplies.
pub const PolicyHooks = struct {
    /// 3.1 steps 4-6: a new TrustedTypePolicy in `realm` named `name`, with
    /// `options` (which it keeps traced, taking no hold of the caller's).
    create: *const fn (realm: runtime.Context, name: []const u8, options: PolicyOptions) anyerror!*runtime.Instance,
    /// 3.3 "get trusted type policy value": `policy`'s option for `kind`
    /// invoked with « value » + `arguments`, its result converted to the
    /// callback's return type. Null for a null or undefined result, and for
    /// an option the policy lacks when `throw_if_missing` is false (a
    /// TypeError when true). OWNED by `allocator`. An exception the callback
    /// threw is pending when it returns error.ExceptionPending ("rethrow").
    policy_value: *const fn (
        policy: *runtime.Instance,
        kind: Kind,
        value: []const u8,
        arguments: []const runtime.JSValue,
        throw_if_missing: bool,
        allocator: std.mem.Allocator,
    ) anyerror!?[]u8,
};

const Table = struct {
    html: ?ValueHooks = null,
    script: ?ValueHooks = null,
    script_url: ?ValueHooks = null,
    factory: ?FactoryHooks = null,
    policy: ?PolicyHooks = null,

    fn values(self: *const Table, kind: Kind) ?ValueHooks {
        return switch (kind) {
            .html => self.html,
            .script => self.script,
            .script_url => self.script_url,
        };
    }
};

// process-wide: hook table written once at process start by the five Trusted Types impls' installHooks; read-only after
var table: Table = .{};

/// Called by TrustedHTML, TrustedScript and TrustedScriptURL.
pub fn installValue(kind: Kind, hooks: ValueHooks) void {
    process_start.assertInstalling();
    switch (kind) {
        .html => table.html = hooks,
        .script => table.script = hooks,
        .script_url => table.script_url = hooks,
    }
}

/// Called by TrustedTypePolicyFactory.
pub fn installFactory(hooks: FactoryHooks) void {
    process_start.assertInstalling();
    table.factory = hooks;
}

/// Called by TrustedTypePolicy.
pub fn installPolicy(hooks: PolicyHooks) void {
    process_start.assertInstalling();
    table.policy = hooks;
}

// ============================================================================
// Trusted values
// ============================================================================

/// A new object of `kind` in `realm` whose data is a copy of `data`.
pub fn createValue(realm: runtime.Context, kind: Kind, data: []const u8) anyerror!*runtime.Instance {
    const hooks = table.values(kind) orelse return error.NotImplemented;
    return hooks.create(realm, data);
}

/// 3.1 steps 4-6: a new TrustedTypePolicy named `name` with `options`.
pub fn createPolicy(realm: runtime.Context, name: []const u8, options: PolicyOptions) anyerror!*runtime.Instance {
    const hooks = table.policy orelse return error.NotImplemented;
    return hooks.create(realm, name, options);
}

/// `instance`'s data, when it is an object of `kind`.
pub fn dataOf(instance: *runtime.Instance, kind: Kind) ?[]const u8 {
    const hooks = table.values(kind) orelse return null;
    return hooks.data_of(instance);
}

/// The kind and data of `instance`, when it is a Trusted Type object.
pub fn trustedValueOf(instance: *runtime.Instance) ?struct { kind: Kind, data: []const u8 } {
    for ([_]Kind{ .html, .script, .script_url }) |kind| {
        if (dataOf(instance, kind)) |data| return .{ .kind = kind, .data = data };
    }
    return null;
}

/// A value handed to a sink: a string, or a platform object - a Trusted
/// Type object of any kind (the binding's union arms).
pub const Input = union(enum) {
    string: []const u8,
    object: *runtime.Instance,

    /// "Stringified input": a Trusted Type object's data, else the string.
    /// Borrowed.
    pub fn stringified(self: Input) []const u8 {
        return switch (self) {
            .string => |s| s,
            .object => |o| if (trustedValueOf(o)) |v| v.data else "",
        };
    }

    /// Whether the input is an instance of `kind`.
    pub fn isInstanceOf(self: Input, kind: Kind) bool {
        return switch (self) {
            .string => false,
            .object => |o| dataOf(o, kind) != null,
        };
    }
};

// ============================================================================
// The global's CSP list and factory
// ============================================================================

/// `global`'s CSP list (CSP 4.2.? "global object's CSP list": a Window's
/// associated Document's policy container's, a WorkerGlobalScope's own), or
/// null when it has none.
pub fn cspListOf(global: *runtime.Instance) ?*const csp.CSPList {
    const settings = global_settings.of(global) orelse return null;
    const container_of = settings.policy_container orelse return null;
    const container = container_of(global) orelse return null;
    return &container.csp_list;
}

/// 4.2.3 "Does sink type require trusted types?" for `global`.
pub fn doesSinkTypeRequireTrustedTypes(global: *runtime.Instance, sink_group: []const u8, include_report_only_policies: bool) bool {
    const list = cspListOf(global) orelse return false;
    return csp.directives.doesSinkTypeRequireTrustedTypes(list, sink_group, include_report_only_policies);
}

/// `global`'s trusted type policy factory (4.1), made on first use.
pub fn factoryOf(global: *runtime.Instance) ?*runtime.Instance {
    const settings = global_settings.of(global) orelse return null;
    const factory_of = settings.trusted_types orelse return null;
    return factory_of(global) catch null;
}

/// `global`'s trusted type policy factory's default policy, or null.
pub fn defaultPolicyOf(global: *runtime.Instance) ?*runtime.Instance {
    const hooks = table.factory orelse return null;
    const factory = factoryOf(global) orelse return null;
    return hooks.default_policy(factory);
}

/// `realm`'s global object.
pub fn globalOf(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    return @ptrCast(@alignCast(record.global_object orelse return null));
}

/// `instance`'s relevant global object.
pub fn relevantGlobalOf(instance: *runtime.Instance) ?*runtime.Instance {
    return globalOf(instance.ctx);
}

// ============================================================================
// 3.4, 3.5: get trusted type compliant string
// ============================================================================

/// 3.5 "Process value with a default policy", given the stringified input:
/// the default policy's value, OWNED by `allocator`, or null when there is
/// no default policy, it has no option for `expected`, or the option
/// returned null or undefined. error.ExceptionPending: the option threw.
pub fn processValueWithDefaultPolicy(
    allocator: std.mem.Allocator,
    expected: Kind,
    global: *runtime.Instance,
    input: []const u8,
    sink: []const u8,
) anyerror!?[]u8 {
    // 1. "Let defaultPolicy be the value of global's trusted type policy
    // factory's default policy." Null has no options: no value (3.3 step 3
    // with throwIfMissing false).
    const policy = defaultPolicyOf(global) orelse return null;
    const hooks = table.policy orelse return null;
    // 2. Get trusted type policy value with defaultPolicy, stringified input,
    // expectedType's type name, « trustedTypeName, sink », false.
    const arguments = [_]runtime.JSValue{
        runtime.JSValue.fromStringRef(expected.interfaceName()),
        runtime.JSValue.fromStringRef(sink),
    };
    // 3. "If the algorithm threw an error, rethrow the error" - the error
    // propagates. 4. A null or undefined value is returned as is.
    // 5-6. The data string: the new Trusted Type's data is all a sink reads.
    return hooks.policy_value(policy, expected, input, &arguments, false, allocator);
}

/// 3.4 "Get Trusted Type compliant string": the string `sink` may use,
/// OWNED by `allocator`. error.TypeError: blocked ("Throw a TypeError");
/// error.ExceptionPending: the default policy threw.
pub fn getCompliantString(
    allocator: std.mem.Allocator,
    expected: Kind,
    global: *runtime.Instance,
    input: Input,
    sink: []const u8,
    sink_group: []const u8,
) anyerror![]u8 {
    // 1. "If input is an instance of expectedType, return stringified input."
    if (input.isInstanceOf(expected)) return allocator.dupe(u8, input.stringified());
    const text = input.stringified();
    // 2-3. "Does sink type require trusted types?" with global, sinkGroup
    // and true; if not, return stringified input.
    if (!doesSinkTypeRequireTrustedTypes(global, sink_group, true)) return allocator.dupe(u8, text);
    // 4-5. Process value with a default policy; its error is rethrown.
    if (try processValueWithDefaultPolicy(allocator, expected, global, text, sink)) |converted| {
        // 7-8. Its data.
        return converted;
    }
    // 6. A null or undefined value: "should sink type mismatch violation be
    // blocked by CSP?" with stringified input as source. The list is read
    // again: the default policy ran script.
    const list = cspListOf(global) orelse return allocator.dupe(u8, text);
    const disposition = try csp.directives.shouldSinkTypeMismatchViolationBeBlocked(
        allocator,
        list,
        sink,
        sink_group,
        text,
        csp_violations.reporterFor(global),
    );
    // 6.2. "If disposition is “Allowed”, return stringified input" - the
    // report-only case: reported, then ignored.
    if (disposition == .allowed) return allocator.dupe(u8, text);
    // 6.3. "Throw a TypeError."
    return error.TypeError;
}

// ============================================================================
// 3.7, 3.8: attributes
// ============================================================================

/// The names of HTML's event handler content attributes: every event
/// handler IDL attribute an element exposes (GlobalEventHandlers,
/// DocumentAndElementEventHandlers, Element's own, the body element's
/// WindowEventHandlers, HTMLMediaElement's and SVGAnimationElement's).
const event_handler_names = blk: {
    @setEvalBranchQuota(200_000);
    var names: []const []const u8 = &.{};
    for (.{
        interfaces.HTMLElement,
        interfaces.Element,
        interfaces.HTMLBodyElement,
        interfaces.HTMLMediaElement,
        interfaces.SVGAnimationElement,
    }) |Interface| {
        for (Interface.Meta.properties) |property| {
            const name: []const u8 = property[0];
            if (name.len <= 2 or !std.mem.startsWith(u8, name, "on")) continue;
            var seen = false;
            for (names) |n| {
                if (std.mem.eql(u8, n, name)) seen = true;
            }
            if (!seen) names = names ++ .{name};
        }
    }
    break :blk names;
};

const event_handler_set = blk: {
    var entries: [event_handler_names.len]struct { []const u8 } = undefined;
    for (event_handler_names, 0..) |name, i| entries[i] = .{name};
    break :blk std.StaticStringMap(void).initComptime(entries);
};

/// Whether `name` is the name of an event handler content attribute.
pub fn isEventHandlerContentAttributeName(name: []const u8) bool {
    return event_handler_set.has(name);
}

/// 3.8 "Get Trusted Type data for attribute", for an element given by its
/// namespace and local name.
pub fn dataForAttribute(element_namespace: ?[]const u8, element_local_name: []const u8, attribute: []const u8, attribute_namespace: ?[]const u8) ?trusted_types.attributes.AttributeData {
    return trusted_types.attributes.dataForAttribute(element_namespace, element_local_name, attribute, attribute_namespace, &isEventHandlerContentAttributeName);
}

/// TrustedTypePolicyFactory getAttributeType (2.3.1).
pub fn getAttributeType(allocator: std.mem.Allocator, tag_name: []const u8, attribute: []const u8, element_namespace: ?[]const u8, attribute_namespace: ?[]const u8) error{OutOfMemory}!?Kind {
    return trusted_types.attributes.getAttributeType(allocator, tag_name, attribute, element_namespace, attribute_namespace, &isEventHandlerContentAttributeName);
}

/// TrustedTypePolicyFactory getPropertyType (2.3.1).
pub const getPropertyType = trusted_types.attributes.getPropertyType;

/// 3.7 "Get Trusted Type compliant attribute value", given the attribute's
/// local name and namespace, the element, and the new value: the string to
/// set, OWNED by `allocator`. Errors as getCompliantString's.
pub fn getCompliantAttributeValue(
    allocator: std.mem.Allocator,
    attribute_local_name: []const u8,
    attribute_namespace: ?[]const u8,
    element: *runtime.Instance,
    new_value: Input,
) anyerror![]u8 {
    // 1. "If attributeNs is the empty string, set attributeNs to null."
    const attr_ns: ?[]const u8 = if (attribute_namespace) |ns| (if (ns.len == 0) null else ns) else null;
    // 2. Get Trusted Type data for attribute, given element, attributeName
    // and attributeNs.
    var element_ns = try interfaces.Element.get_namespaceURI(element);
    defer if (element_ns) |*ns| ns.deinit(element.ctx.allocator);
    var local_name = try interfaces.Element.get_localName(element);
    defer local_name.deinit(element.ctx.allocator);
    const data = dataForAttribute(
        if (element_ns) |ns| ns.asSlice() else null,
        local_name.asSlice(),
        attribute_local_name,
        attr_ns,
    ) orelse {
        // 3. No data: a string is returned as is, a Trusted Type object's
        // data otherwise.
        return allocator.dupe(u8, new_value.stringified());
    };
    // 4-5. expectedType and sink.
    const sink = try data.allocSinkName(allocator);
    defer allocator.free(sink);
    // 6. Get trusted type compliant string, with element's node document's
    // relevant global object as global.
    const document = (try interfaces.Node.get_ownerDocument(element)) orelse return allocator.dupe(u8, new_value.stringified());
    const global = relevantGlobalOf(document) orelse return allocator.dupe(u8, new_value.stringified());
    return getCompliantString(allocator, data.kind, global, new_value, sink, script_sink_group);
}

test "event handler content attribute names: GlobalEventHandlers, the body's, Element's own; nothing else" {
    try std.testing.expect(isEventHandlerContentAttributeName("onclick"));
    try std.testing.expect(isEventHandlerContentAttributeName("onload"));
    try std.testing.expect(isEventHandlerContentAttributeName("onbeforeunload"));
    try std.testing.expect(isEventHandlerContentAttributeName("oncopy"));
    try std.testing.expect(isEventHandlerContentAttributeName("onfullscreenchange"));
    try std.testing.expect(!isEventHandlerContentAttributeName("ondoesnotexist"));
    try std.testing.expect(!isEventHandlerContentAttributeName("on"));
    try std.testing.expect(!isEventHandlerContentAttributeName("oNclick"));
    try std.testing.expect(!isEventHandlerContentAttributeName("one"));
}

// ============================================================================
// 4.2.1.1: the require-trusted-types-for pre-navigation check
// ============================================================================

/// What the pre-navigation check decided for a javascript: URL.
pub const PreNavigation = union(enum) {
    /// Navigate to the URL as it was.
    allowed,
    /// Navigate to this URL instead - the default policy's value, after
    /// "javascript:". OWNED by the allocator given.
    rewritten: []u8,
    /// Do not navigate.
    blocked,
};

/// The sink a javascript: URL's pre-navigation check names.
pub const javascript_url_sink = "Location href";

/// Trusted Types 4.2.1.1, the `require-trusted-types-for` pre-navigation
/// check, as CSP 4.2.4 "should navigation request of type be blocked by
/// Content Security Policy?" runs it for a navigation to `url`:
/// `csp_list` is the navigation request's policy container's, `client` its
/// client's global object - whose trusted type policy factory's default
/// policy runs, and where violations go (null: neither). `isValidUrl` is
/// the URL parser's verdict on a string (step 6).
///
/// Run once for every policy that requires Trusted Types for 'script'
/// (report-only ones too): a value from the default policy rewrites the URL;
/// none - no default policy, a null or undefined value, a throw (caught here:
/// "if that algorithm threw an error ... return Blocked") or an unparsable
/// result - is reported for each such policy as 4.2.4 reports a sink type
/// mismatch (sink "Location href", the source the URL's code - what Blink
/// and Gecko report and WPT reads), and blocks only under an enforced one.
pub fn javascriptUrlPreNavigationCheck(
    allocator: std.mem.Allocator,
    csp_list: *const csp.CSPList,
    client: ?*runtime.Instance,
    url: []const u8,
    isValidUrl: *const fn (allocator: std.mem.Allocator, url: []const u8) bool,
) error{OutOfMemory}!PreNavigation {
    // 1. "If request's url's scheme is not "javascript", return "Allowed"."
    const prefix = "javascript:";
    if (url.len < prefix.len or !std.ascii.eqlIgnoreCase(url[0..prefix.len], prefix)) return .allowed;
    // Only a policy with require-trusted-types-for 'script' has this check.
    if (!csp.directives.doesSinkTypeRequireTrustedTypes(csp_list, script_sink_group, true)) return .allowed;
    // 2-3. "Let encodedScriptSource be the result of removing the leading
    // "javascript:" from urlString."
    const encoded = url[prefix.len..];
    // 4. Process value with a default policy, TrustedScript, the client's
    // global, encodedScriptSource, "Location href".
    if (client) |global| {
        if (try defaultPolicyValueCaught(allocator, global, encoded)) |converted| {
            defer allocator.free(converted);
            // 5. "Set urlString to be the result of prepending "javascript:"
            // to stringified convertedScriptSource."
            const rewritten = try std.mem.concat(allocator, u8, &.{ prefix, converted });
            // 6-7. A URL that parses is the request's new URL.
            if (isValidUrl(allocator, rewritten)) return .{ .rewritten = rewritten };
            allocator.free(rewritten);
        }
    }
    // "Blocked", reported per requiring policy; only an enforced one blocks.
    const reporter: ?csp.violation_events.Reporter = if (client) |global| csp_violations.reporterFor(global) else null;
    const disposition = try csp.directives.shouldSinkTypeMismatchViolationBeBlocked(allocator, csp_list, javascript_url_sink, script_sink_group, encoded, reporter);
    return if (disposition == .blocked) .blocked else .allowed;
}

/// The default policy's createScript value for `source` (sink "Location
/// href"), OWNED; null for none, and for a policy that threw - its exception
/// caught and dropped.
fn defaultPolicyValueCaught(allocator: std.mem.Allocator, global: *runtime.Instance, source: []const u8) error{OutOfMemory}!?[]u8 {
    const Steps = struct {
        allocator: std.mem.Allocator,
        global: *runtime.Instance,
        source: []const u8,
        result: ?[]u8 = null,
        failed: bool = false,

        fn run(data: ?*anyopaque) engine.Error!void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            self.result = processValueWithDefaultPolicy(self.allocator, .script, self.global, self.source, javascript_url_sink) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.ExceptionPending => return error.ExceptionPending,
                else => {
                    self.failed = true;
                    return;
                },
            };
        }
    };
    var steps: Steps = .{ .allocator = allocator, .global = global, .source = source };
    if (!global.ctx.hasEngine()) return null;
    const thrown = engine.completionOf(global.ctx, Steps.run, &steps) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return null,
    };
    if (thrown) |exception| {
        exception.release();
        if (steps.result) |r| allocator.free(r);
        return null;
    }
    return steps.result;
}
