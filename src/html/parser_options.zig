//! The options the HTML insertion and streaming methods parse with (HTML
//! 8.5.2, 8.5.3: a SetHTMLOptions, SetHTMLUnsafeOptions or
//! ParseHTMLUnsafeOptions dictionary, or a TrustedHTMLParserOptions object),
//! HTML's "get a sanitizer config from options" over them, and Trusted
//! Types' algorithms that vet them: 3.4 "get trusted type compliant input",
//! 3.6 "get trusted type compliant parser options", 3.2 step 3 (a policy's
//! createParserOptions), "create a parser options callback argument" and
//! "get a sanitizer (config copy) from dictionary".
//!
//! A TrustedHTMLParserOptions object keeps its values natively (its impl
//! owns an html.sanitizer.Config); the dom side of Trusted Types reaches it
//! through dom.trusted_types' hooks, type-erased because dom is below html.
//! Only this file casts those pointers back.
//!
//! Spec: https://html.spec.whatwg.org/#get-a-sanitizer-config-from-options
//! Spec: https://w3c.github.io/trusted-types/dist/spec/#get-trusted-type-compliant-parser-options

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const engine = @import("engine");
const dom = @import("dom");
const sanitizer = @import("sanitizer.zig");

const trusted_types = dom.trusted_types;

/// The sink group every HTML parsing sink belongs to ("script").
const script_sink_group = trusted_types.script_sink_group;

/// Options as a parsing method took them, after WebIDL conversion.
pub const ParserOptions = struct {
    allocator: Allocator,
    value: union(enum) {
        dictionary: Dictionary,
        trusted: Trusted,
    },

    /// A SetHTMLOptions, SetHTMLUnsafeOptions or ParseHTMLUnsafeOptions
    /// dictionary.
    pub const Dictionary = struct {
        /// options["sanitizer"], converted by its union (Sanitizer or
        /// SanitizerConfig or SanitizerPresets) - WebIDL conversion comes
        /// before every step of the method, Trusted Types included; null
        /// when the member does not exist. A Sanitizer arm BORROWS the
        /// binding's value for the synchronous part of the method.
        sanitizer: ?sanitizer.Converted = null,
        /// options["runScripts"]: null when it does not exist (SetHTMLOptions
        /// has no such member).
        run_scripts: ?bool = null,
    };

    /// A TrustedHTMLParserOptions' associated values (Trusted Types 2.2.4).
    pub const Trusted = struct {
        run_scripts: bool,
        /// Its sanitizer configuration, OWNED; null for none.
        configuration: ?sanitizer.Config,
    };

    pub fn deinit(self: *ParserOptions) void {
        switch (self.value) {
            .dictionary => |*d| if (d.sanitizer) |*s| s.deinit(),
            .trusted => |*t| if (t.configuration) |*c| c.deinit(),
        }
        self.* = undefined;
    }

    /// A dictionary's options: `sanitizer_member` as the binding gave it
    /// (null when absent; a JS null converts as an empty dictionary) is
    /// converted now.
    pub fn fromDictionary(realm: runtime.Context, sanitizer_member: ?runtime.JSValue, run_scripts: ?bool) !ParserOptions {
        var converted: ?sanitizer.Converted = null;
        if (sanitizer_member) |member| converted = try sanitizer.Converted.fromJS(realm.allocator, realm, member, true);
        return .{ .allocator = realm.allocator, .value = .{ .dictionary = .{ .sanitizer = converted, .run_scripts = run_scripts } } };
    }

    /// The options a parsing method's (X or TrustedHTMLParserOptions)
    /// argument names, `X` being a dictionary with a `sanitizer` member and
    /// perhaps `runScripts`: a TrustedHTMLParserOptions' values copied, or
    /// the dictionary's converted. `value` is the binding's union, or null
    /// when the argument was not passed (its default: an empty dictionary).
    pub fn fromUnion(realm: runtime.Context, value: anytype) !ParserOptions {
        const T = @TypeOf(value);
        if (@typeInfo(T) == .optional) {
            if (value) |given| return fromUnion(realm, given);
            return .{ .allocator = realm.allocator, .value = .{ .dictionary = .{} } };
        }
        const info = @typeInfo(T).@"union";
        inline for (info.field_names, info.field_types) |field_name, field_type| {
            if (value == @field(std.meta.Tag(T), field_name)) {
                const arm = @field(value, field_name);
                if (field_type == *runtime.Instance) {
                    return (try fromTrustedObject(realm.allocator, arm)) orelse error.TypeError;
                }
                return fromDictionary(realm, arm.sanitizer, if (@hasField(field_type, "runScripts")) arm.runScripts else null);
            }
        }
        unreachable;
    }

    /// A TrustedHTMLParserOptions object's values, copied; null when
    /// `object` is not one.
    pub fn fromTrustedObject(allocator: Allocator, object: *runtime.Instance) !?ParserOptions {
        const value = trusted_types.parserOptionsValueOf(object) orelse return null;
        var configuration: ?sanitizer.Config = null;
        if (value.sanitizer_configuration) |erased| configuration = try configFromErased(erased).clone(allocator);
        return .{ .allocator = allocator, .value = .{ .trusted = .{ .run_scripts = value.run_scripts, .configuration = configuration } } };
    }

    /// Whether these are a TrustedHTMLParserOptions' values.
    pub fn isTrusted(self: *const ParserOptions) bool {
        return self.value == .trusted;
    }

    /// HTML "fragment parsing algorithm steps" step 4 / "stream HTML" step
    /// 5: "options's runScripts if options is a TrustedHTMLParserOptions;
    /// otherwise options["runScripts"] with default false."
    pub fn runScripts(self: *const ParserOptions) bool {
        return switch (self.value) {
            .trusted => |t| t.run_scripts,
            .dictionary => |d| d.run_scripts orelse false,
        };
    }

    /// Trusted Types 3.6 "needs vetting": options["runScripts"] exists and
    /// is true, or options["sanitizer"] exists and is not an empty
    /// SanitizerConfig.
    pub fn needsVetting(self: *const ParserOptions) bool {
        const d = switch (self.value) {
            .dictionary => |d| d,
            .trusted => return false,
        };
        if (d.run_scripts == true) return true;
        if (d.sanitizer) |*s| return !s.isEmptyDictionary();
        return false;
    }

    /// HTML "get a sanitizer config from options" given these options and
    /// `safe`: the configuration the parser sanitizes with, OWNED, with
    /// "remove unsafe" already applied when `safe` (step 14); null for none.
    pub fn sanitizerConfig(self: *const ParserOptions, realm: runtime.Context, safe: bool) !?sanitizer.Config {
        const allocator = realm.allocator;
        // 11. "Let permissiveDefaults be true if safe is false."
        const permissive = !safe;
        // 1-12: the configured sanitizer's configuration.
        var configuration: sanitizer.Config = switch (self.value) {
            // 2. A TrustedHTMLParserOptions: its sanitizer configuration, or
            // null (2.1.1 asserts a safe method never passes one without).
            .trusted => |t| blk: {
                const held = t.configuration orelse {
                    std.debug.assert(!safe);
                    return null;
                };
                // 9-12: configure a new Sanitizer with that dictionary.
                break :blk try sanitizer.Config.fromData(allocator, held.data, permissive);
            },
            .dictionary => |d| blk: {
                // 3. options["sanitizer"] when it exists.
                if (d.sanitizer) |*converted| break :blk try sanitizer.Config.fromConverted(allocator, realm, converted, permissive);
                // 4. "Otherwise, if safe is false, then return null."
                if (!safe) return null;
                // 5, 7: "default" - the built-in safe default configuration.
                var preset = try sanitizer.convertOptions(realm, null, true);
                defer preset.deinit();
                break :blk try sanitizer.Config.fromConverted(allocator, realm, &preset, permissive);
            },
        };
        errdefer configuration.deinit();
        // 14. "If safe is true, then remove unsafe from configuration."
        if (safe) _ = try configuration.removeUnsafe();
        return configuration;
    }
};

/// The html.sanitizer.Config behind a dom.trusted_types type-erased pointer.
pub fn configFromErased(erased: *const anyopaque) *const sanitizer.Config {
    return @ptrCast(@alignCast(erased));
}

/// The type-erased pointer dom.trusted_types carries for `config`.
pub fn erasedConfig(config: *const sanitizer.Config) *const anyopaque {
    return config;
}

// ============================================================================
// Trusted Types 3.6: get trusted type compliant parser options
// ============================================================================

/// What a sink's Trusted Types step yields for its options.
pub const Error = anyerror;

/// Trusted Types 3.6 "Get Trusted Type compliant parser options" given
/// `global`, `input` (MOVED in: returned as is, or freed and replaced),
/// `throw_if_missing`, `sink` and `options_from_author`.
/// error.TypeError: blocked; error.ExceptionPending: the default policy's
/// createParserOptions threw ("rethrow").
pub fn compliantParserOptions(
    global: ?*runtime.Instance,
    input: ParserOptions,
    throw_if_missing: bool,
    sink: []const u8,
    options_from_author: bool,
) Error!ParserOptions {
    var options = input;
    errdefer options.deinit();
    // 1. "If input is an instance of TrustedHTMLParserOptions, return input."
    if (options.isTrusted()) return options;
    // An object with no global (a realm that is gone) has no policies.
    const g = global orelse return options;
    // 2-3. "Does sink type require trusted types?" with global, "script" and
    // true; if not, return input.
    if (!trusted_types.doesSinkTypeRequireTrustedTypes(g, script_sink_group, true)) return options;
    // 4-5. requirePolicy: throwIfMissing, or author options that need
    // vetting.
    const require_policy = throw_if_missing or (options_from_author and options.needsVetting());
    // 6. "Let defaultPolicy be ... global's trusted type policy factory's
    // default policy."
    const default_policy = trusted_types.defaultPolicyOf(g);
    // 7-9. No default policy, or none with createParserOptions.
    if (default_policy == null or !trusted_types.policyHasParserOptions(default_policy.?)) {
        // 7.1 / 9.1: a policy is required: should sink type mismatch
        // violation be blocked by CSP? with the empty string as source;
        // "Allowed" returns input, else throw a TypeError.
        if (require_policy) {
            if (try trusted_types.sinkTypeMismatchBlocked(g.ctx.allocator, g, sink, script_sink_group, "")) return error.TypeError;
        }
        // 7.2 / 9.2. "Return input."
        return options;
    }
    const policy = default_policy.?;
    const realm = g.ctx;
    // 10. "Let argument be the result of creating a parser options callback
    // argument given global's relevant realm and input."
    const argument = try createCallbackArgument(realm, &options);
    defer argument.release();
    // 11-12. Invoke createParserOptions with « argument,
    // "TrustedHTMLParserOptions", sink » and "rethrow".
    const policy_value = (try trusted_types.parserOptionsPolicyValue(policy, argument.value, &.{
        runtime.JSValue.fromStringRef("TrustedHTMLParserOptions"),
        runtime.JSValue.fromStringRef(sink),
    }, false)) orelse return options;
    defer policy_value.release();
    // The callback's return type, SetHTMLUnsafeOptions?: null and undefined
    // are null. 14. "Let runScripts be policyValue["runScripts"], with
    // default false." 15. A new TrustedHTMLParserOptions with the sanitizer
    // configuration copied from policyValue and runScripts.
    const trusted = (try trustedFromPolicyValue(realm, policy_value.value)) orelse {
        // 13. A null or undefined value: the violation is reported; in
        // report-only mode input is used, else throw a TypeError.
        if (try trusted_types.sinkTypeMismatchBlocked(g.ctx.allocator, g, sink, script_sink_group, "")) return error.TypeError;
        return options;
    };
    options.deinit();
    return trusted;
}

/// Get trusted type compliant input's documentType.
pub const DocumentType = enum { html, xml };

/// Trusted Types 3.4 "Get Trusted Type compliant input" given `global`,
/// `input`, `options` (MOVED in), `sink`, `document_type` and
/// `options_from_author`: the markup (OWNED by `allocator`) and the options
/// to parse it with.
pub fn compliantInput(
    allocator: Allocator,
    global: ?*runtime.Instance,
    input: trusted_types.Input,
    options: ParserOptions,
    sink: []const u8,
    document_type: DocumentType,
    options_from_author: bool,
) Error!struct { html: []u8, options: ParserOptions } {
    // 1. "Let compliantOptions be options."
    var compliant_options = options;
    var owns_options = true;
    errdefer if (owns_options) compliant_options.deinit();
    // 2. For an HTML document:
    if (document_type == .html) {
        // 2.1. Get trusted type compliant parser options with global,
        // options, false, sink and optionsFromAuthor.
        owns_options = false;
        compliant_options = try compliantParserOptions(global, compliant_options, false, sink, options_from_author);
        owns_options = true;
        // 2.2. A TrustedHTMLParserOptions: (stringified input, it).
        if (compliant_options.isTrusted()) {
            return .{ .html = try allocator.dupe(u8, input.stringified()), .options = compliant_options };
        }
    }
    // 3-4. Get trusted type compliant string with TrustedHTML, global,
    // input, sink and "script"; its error is rethrown.
    const html = if (global) |g|
        try trusted_types.getCompliantString(allocator, .html, g, input, sink, script_sink_group)
    else
        try allocator.dupe(u8, input.stringified());
    // 5. "Return (compliantHTML, compliantOptions)."
    return .{ .html = html, .options = compliant_options };
}

// ============================================================================
// Trusted Types 3.2 step 3 / 3.3 step 4: createParserOptions
// ============================================================================

/// Trusted Types "create a parser options callback argument" given `realm`
/// and the dictionary `options`: a new object «[ "runScripts" ->
/// runScriptsInput, "sanitizer" -> a new configured Sanitizer ]», the
/// sanitizer member only when the dictionary has one. OWNED.
pub fn createCallbackArgument(realm: runtime.Context, options: *const ParserOptions) Error!engine.Owned {
    const dictionary = switch (options.value) {
        .dictionary => |*d| d,
        // 3.6 step 1 returns a TrustedHTMLParserOptions before this runs,
        // and 3.3 step 4's value is a dictionary.
        .trusted => unreachable,
    };
    // 1-2. «[ "runScripts" -> dictionary["runScripts"] with default false ]».
    var members: [2]engine.DictionaryMember = undefined;
    members[0] = .{ .name = "runScripts", .value = .{ .boolean = dictionary.run_scripts orelse false } };
    var count: usize = 1;
    // 3. "Let sanitizerInput be the result of getting a sanitizer from realm
    // and dictionary."
    const made = try sanitizerFromDictionary(realm, dictionary);
    defer if (made) |object| object.instance.releaseIfUnwrapped(object.generation);
    // 4. "If sanitizerInput is not null, set argument["sanitizer"] to
    // sanitizerInput."
    if (made) |object| {
        members[1] = .{ .name = "sanitizer", .value = .{ .instance = object.instance } };
        count = 2;
    }
    // 5. "Return argument."
    return engine.createDictionaryObject(realm, members[0..count]);
}

/// A Sanitizer made for script, with the slab generation that says whether
/// a wrapper took it over.
const MadeSanitizer = struct { instance: *runtime.Instance, generation: u64 };

/// Trusted Types "get a sanitizer from dictionary" given `realm` and the
/// dictionary: a new Sanitizer in `realm` configured with the dictionary's
/// sanitizer member and true, or null when it has none. Release it with
/// releaseIfUnwrapped once something holds its wrapper.
fn sanitizerFromDictionary(realm: runtime.Context, dictionary: *const ParserOptions.Dictionary) Error!?MadeSanitizer {
    // 1-2. dictionary["sanitizer"] defaulting to null; null returns null.
    const converted = if (dictionary.sanitizer) |*s| s else return null;
    // 3-7. Its configuration: the built-in safe default for a preset, a
    // Sanitizer's configuration, or the SanitizerConfig itself; 8-9. a new
    // Sanitizer configured with it and true.
    var configuration = try sanitizer.Config.fromConverted(realm.allocator, realm, converted, true);
    defer configuration.deinit();
    const instance = try trusted_types.createSanitizerObject(realm, erasedConfig(&configuration));
    // 10. "Return sanitizer."
    return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
}

/// A createParserOptions callback's value as TrustedHTMLParserOptions
/// values (Trusted Types 3.2 steps 3.2-3.3 / 3.6 steps 14-15): the value
/// converted to the callback's return type, SetHTMLUnsafeOptions? (WebIDL
/// 3.2.18: members in lexicographic order - runScripts, then sanitizer),
/// then its sanitizer configuration "got from realm and policyValue" (a new
/// Sanitizer configured with the member and true, its configuration taken)
/// and policyValue["runScripts"] with default false. Null for null or
/// undefined; a value that is no object is a TypeError. The member is
/// resolved while it is held: a Sanitizer arm borrows it.
fn trustedFromPolicyValue(realm: runtime.Context, value: runtime.JSValue) Error!?ParserOptions {
    switch (engine.typeOf(realm, value)) {
        .undefined, .null => return null,
        .object => {},
        else => return error.TypeError,
    }
    // runScripts (boolean, default false).
    const run_scripts = (try engine.getPropertyBoolean(realm, value, "runScripts")) orelse false;
    // sanitizer ((Sanitizer or SanitizerConfig or SanitizerPresets)).
    const member = try engine.getProperty(realm, value, "sanitizer");
    defer member.release();
    var configuration: ?sanitizer.Config = null;
    if (engine.typeOf(realm, member.value) != .undefined) {
        var converted = try sanitizer.Converted.fromJS(realm.allocator, realm, member.value, true);
        defer converted.deinit();
        configuration = try sanitizer.Config.fromConverted(realm.allocator, realm, &converted, true);
    }
    return .{ .allocator = realm.allocator, .value = .{ .trusted = .{ .run_scripts = run_scripts, .configuration = configuration } } };
}

/// TrustedTypePolicy createParserOptions(options, ...arguments): Trusted
/// Types 3.2 "create a trusted type" with "TrustedHTMLParserOptions" - the
/// policy's createParserOptions invoked with the callback argument made from
/// `options`, then a new TrustedHTMLParserOptions in the policy's relevant
/// realm. `options` is the SetHTMLUnsafeOptions argument's members.
pub fn createForPolicy(
    policy: *runtime.Instance,
    sanitizer_member: ?runtime.JSValue,
    run_scripts: ?bool,
    arguments: []const runtime.JSValue,
) Error!*runtime.Instance {
    const realm = policy.ctx;
    var options = try ParserOptions.fromDictionary(realm, sanitizer_member, run_scripts);
    defer options.deinit();
    // 3.3 step 4: "Set value to the result of creating a parser options
    // callback argument given policy's relevant realm and value."
    const argument = try createCallbackArgument(realm, &options);
    defer argument.release();
    // 3.2 steps 1-2: get trusted type policy value with throwIfMissing true;
    // its error is rethrown.
    const policy_value = (try trusted_types.parserOptionsPolicyValue(policy, argument.value, arguments, true)) orelse return error.TypeError;
    defer policy_value.release();
    // 3.1. "If policyValue is null, throw a TypeError." 3.2-3.3.
    var trusted = (try trustedFromPolicyValue(realm, policy_value.value)) orelse return error.TypeError;
    defer trusted.deinit();
    // 3.4. A new TrustedHTMLParserOptions in policy's relevant realm.
    const t = trusted.value.trusted;
    return trusted_types.createParserOptionsObject(realm, t.run_scripts, if (t.configuration) |*c| erasedConfig(c) else null);
}

// ============================================================================
// The legacy sinks: innerHTML, outerHTML, insertAdjacentHTML
// ============================================================================

/// What a legacy sink's Trusted Types step yields: the markup (OWNED), and
/// the options a default policy's createParserOptions gave - null when they
/// are the sink's own empty dictionary, which changes nothing about the
/// Legacy parse.
pub const LegacyInput = struct {
    html: []u8,
    options: ?ParserOptions = null,

    pub fn deinit(self: *LegacyInput, allocator: Allocator) void {
        allocator.free(self.html);
        if (self.options) |*options| options.deinit();
        self.* = undefined;
    }
};

/// The legacy sinks' step 1 (HTML 8.5.5-8.5.7): "Let (compliantString,
/// compliantOptions) be the result of invoking the get trusted type
/// compliant input algorithm with this's relevant global object, the given
/// value, a new SetHTMLUnsafeOptions dictionary, `sink`, this's node
/// document's type, and false." Without Trusted Types required for "script"
/// it is the value as given (3.4 step 2.1 returns the dictionary, 3.5 step
/// 3 the string), as the sinks always read it.
pub fn legacyCompliantInput(allocator: Allocator, this: *runtime.Instance, value: trusted_types.Input, sink: []const u8) Error!LegacyInput {
    const global = trusted_types.relevantGlobalOf(this) orelse return .{ .html = try allocator.dupe(u8, value.stringified()) };
    if (!trusted_types.doesSinkTypeRequireTrustedTypes(global, script_sink_group, true)) return .{ .html = try allocator.dupe(u8, value.stringified()) };
    const document = if (this.stateAs(@import("interfaces").Document.State) != null) this else (try @import("interfaces").Node.get_ownerDocument(this));
    const is_xml = if (document) |d| dom.document_internals.getDocumentType(d) == .xml else false;
    const options = try ParserOptions.fromDictionary(this.ctx, null, null);
    const compliant = try compliantInput(allocator, global, value, options, sink, if (is_xml) .xml else .html, false);
    if (compliant.options.isTrusted()) return .{ .html = compliant.html, .options = compliant.options };
    var plain = compliant.options;
    plain.deinit();
    return .{ .html = compliant.html };
}
