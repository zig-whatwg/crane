//! HTML 4.10.21: shared native-control constraint validation algorithms.
const std = @import("std");
const runtime = @import("runtime");
const form_associated = @import("../form_associated.zig");
pub const ValidityFlags = @import("dictionaries").ValidityStateFlags;
pub const options = @import("options.zig");

/// HTML 4.10.5.1.14, update/serialize a color well control: parse without
/// an element context (steps 3–4), make it opaque (serialization step 3),
/// then clamp/round the limited-sRGB destination and serialize lower hex.
pub fn sanitizeColor(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    const color = @import("css").ColorParser.parseWithoutContext(value, allocator) catch return allocator.dupe(u8, "#000000");
    const rgb = color.quantize();
    const result = try allocator.alloc(u8, 7);
    const hex = "0123456789abcdef";
    result[0] = '#';
    for ([_]u8{ rgb.r, rgb.g, rgb.b }, 0..) |component, index| {
        result[index * 2 + 1] = hex[component >> 4];
        result[index * 2 + 2] = hex[component & 15];
    }
    return result;
}

/// HTML 4.10.5.3.8: test the remainder, not the rounded quotient. Number
/// and Range use the real-number tolerance and precision cutoff used by
/// Blink StepRange::StepMismatch and WebKit StepRange::stepMismatch.
/// Parse the original strings as f128 before calling: promoting an f64
/// quotient cannot recover the fraction it already lost (17 / 3e-15).
pub fn numericStepMismatch(value: f128, base: f128, step: f128) bool {
    const distance = @abs(value - base);
    if (distance > step * 9007199254740992.0) return false;
    const remainder = @mod(distance, step);
    const tolerance = step / 16777216.0;
    return remainder > tolerance and step - remainder > tolerance;
}

/// DOM "string replace all", steps 1–3, inside the caller's reaction scope.
/// An internal form algorithm must not open the textContent IDL setter's
/// nested CEReactions scope and run callbacks before the rest of form.reset.
pub fn replaceText(parent: *runtime.Instance, value: runtime.DOMString) !void {
    const interfaces = @import("interfaces");
    const dom = @import("dom");
    const parent_base = dom.instance_bridge.getNodeBase(@ptrCast(parent)) orelse return error.InvalidStateError;
    var text: ?*runtime.Instance = null;
    errdefer if (text) |node| dom.node_creation.destroyUninserted(node);
    if (!value.isEmpty()) {
        const document = (try interfaces.Node.get_ownerDocument(parent)) orelse return error.InvalidStateError;
        text = try interfaces.Document.call_createTextNode(document, value);
    }
    const text_base = if (text) |node| dom.instance_bridge.getNodeBase(@ptrCast(node)) orelse return error.InvalidStateError else null;
    try dom.mutation.replaceAll(text_base, parent_base);
}

/// The owning control stores this state; access never changes on mutation.
pub const Validation = struct {
    custom_error: runtime.DOMString = .empty,
    validity: ?*runtime.Instance = null,
    validity_generation: u64 = 0,
    validity_traced: bool = false,

    pub fn setCustomError(self: *Validation, allocator: std.mem.Allocator, message: []const u8) !void {
        const normalized = try normalizeMessage(allocator, message);
        self.custom_error.deinit(allocator);
        self.custom_error = normalized;
    }

    /// Engine-free owners release their native child. With an engine the
    /// wrapper graph owns its lifetime, as for ElementInternals.validity.
    pub fn deinit(self: *Validation, allocator: std.mem.Allocator) void {
        self.custom_error.deinit(allocator);
        if (!self.validity_traced) if (liveChild(self.validity, self.validity_generation)) |child| runtime.Instance.deinit(child);
    }
};

pub fn liveChild(child: ?*runtime.Instance, generation: u64) ?*runtime.Instance {
    const value = child orelse return null;
    if (runtime.SlabAllocator.generationOf(value) != generation or runtime.instance_lifecycle.isCleanedUp(value)) return null;
    return value;
}

/// Infra "normalize newlines", steps 1–2: CRLF becomes LF, then CR becomes
/// LF. DOMString is WTF-8 here; every other byte, including NUL and surrogate
/// encodings, is preserved rather than converted through a scalar string.
pub fn normalizeMessage(allocator: std.mem.Allocator, message: []const u8) !runtime.DOMString {
    if (std.mem.indexOfScalar(u8, message, '\r') == null) return runtime.DOMString.initDupe(allocator, message);
    var normalized = std.ArrayList(u8).empty;
    errdefer normalized.deinit(allocator);
    try normalized.ensureTotalCapacity(allocator, message.len);
    var index: usize = 0;
    while (index < message.len) : (index += 1) {
        if (message[index] == '\r') {
            normalized.appendAssumeCapacity('\n');
            if (index + 1 < message.len and message[index + 1] == '\n') index += 1;
        } else {
            normalized.appendAssumeCapacity(message[index]);
        }
    }
    return runtime.DOMString.initOwned(try normalized.toOwnedSlice(allocator));
}

pub fn isValid(flags: ValidityFlags) bool {
    inline for (std.meta.fields(ValidityFlags)) |field| {
        if (@field(flags, field.name) orelse false) return false;
    }
    return true;
}

/// HTML 4.10.5.1.5: empty is valid; with multiple, each comma-separated
/// value must be a valid email address. This is HTML's ASCII ABNF, not the
/// broader mail-header syntax from RFC 5322.
pub fn emailTypeMismatch(value: []const u8, multiple: bool) bool {
    if (value.len == 0) return false;
    if (!multiple) return !validEmailAddress(value);
    var values = std.mem.splitScalar(u8, value, ',');
    while (values.next()) |item| {
        if (!validEmailAddress(std.mem.trim(u8, item, "\t\n\x0c\r "))) return true;
    }
    return false;
}

fn validEmailAddress(value: []const u8) bool {
    const at = std.mem.indexOfScalar(u8, value, '@') orelse return false;
    if (at == 0) return false;
    for (value[0..at]) |byte| {
        if (!std.ascii.isAlphanumeric(byte) and std.mem.indexOfScalar(u8, ".!#$%&'*+/=?^_`{|}~-", byte) == null) return false;
    }
    var labels = std.mem.splitScalar(u8, value[at + 1 ..], '.');
    while (labels.next()) |label| {
        if (label.len == 0 or label.len > 63) return false;
        if (!std.ascii.isAlphanumeric(label[0]) or !std.ascii.isAlphanumeric(label[label.len - 1])) return false;
        for (label) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '-') return false;
    }
    return true;
}

/// HTML 4.10.5.1.4. Like Blink URLInputType::TypeMismatchFor (url_input_type.cc),
/// parse with no base URL. Recoverable URL validation errors do not make an
/// otherwise parsed absolute URL a type mismatch.
pub fn urlTypeMismatch(allocator: std.mem.Allocator, value: []const u8) error{OutOfMemory}!bool {
    if (value.len == 0) return false;
    var record = @import("api_parser").parseURL(allocator, value, null) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return true,
    };
    defer record.deinit();
    return false;
}

/// HTML 4.10.18.5 and 4.10.21.1: disabled controls and controls with a
/// datalist ancestor are barred, independently of their constraint flags.
pub fn isBarred(instance: *runtime.Instance) bool {
    if (form_associated.isDisabled(instance)) return true;
    var ancestor = form_associated.parentOf(instance);
    while (ancestor) |node| : (ancestor = form_associated.parentOf(node)) {
        if (form_associated.isElementNamed(node, "datalist")) return true;
    }
    return false;
}

pub fn validationMessage(allocator: std.mem.Allocator, candidate: bool, flags: ValidityFlags, custom_error: runtime.DOMString) !runtime.DOMString {
    // HTML 4.10.21.3: empty when barred or valid; otherwise describe a
    // constraint, using the custom error when there is one.
    if (!candidate or isValid(flags)) return .empty;
    if (!custom_error.isEmpty()) return custom_error.clone(allocator);
    if (flags.valueMissing orelse false) return runtime.DOMString.initInterned("Please fill out this field.");
    if (flags.typeMismatch orelse false) return runtime.DOMString.initInterned("Please enter a value of the correct type.");
    if (flags.patternMismatch orelse false) return runtime.DOMString.initInterned("Please match the requested format.");
    if (flags.tooLong orelse false) return runtime.DOMString.initInterned("Please shorten this text.");
    if (flags.tooShort orelse false) return runtime.DOMString.initInterned("Please lengthen this text.");
    if (flags.rangeUnderflow orelse false) return runtime.DOMString.initInterned("The value is below the minimum.");
    if (flags.rangeOverflow orelse false) return runtime.DOMString.initInterned("The value is above the maximum.");
    if (flags.stepMismatch orelse false) return runtime.DOMString.initInterned("Please enter a valid value.");
    return runtime.DOMString.initInterned("Please enter a valid value.");
}

/// HTML check validity steps 1–2. The result is decided before dispatch:
/// canceling the event or repairing the control in its listener still
/// returns false for this invocation.
pub fn checkValidity(instance: *runtime.Instance, candidate: bool, flags: ValidityFlags) !bool {
    if (!candidate or isValid(flags)) return true;
    // No engine means no listener can run. Do not make an event that
    // releaseIfUnwrapped would leave ownerless, following the pre-event break
    // in HTMLFormElement.validateCustomControls at base 63d0e68b2a.
    if (!instance.ctx.hasEngine()) return false;
    try form_associated.fireSimpleEvent(instance, "invalid", .{ .cancelable = true });
    return false;
}
