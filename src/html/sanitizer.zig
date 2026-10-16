//! HTML 8.6: owned sanitizer configurations and tree filtering.
//! https://html.spec.whatwg.org/multipage/sanitizer.html
//!
//! Configuration transactions contain only copied strings and lists. They
//! retain neither engine handles nor DOM objects. Replacing the transaction's
//! arena also reclaims strings removed by modifiers before instance teardown.
const std = @import("std");
const infra = @import("infra");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const dom = @import("dom");
const Allocator = std.mem.Allocator;
const DOMString = runtime.DOMString;

pub const html_namespace = "http://www.w3.org/1999/xhtml";
const svg_namespace = "http://www.w3.org/2000/svg";
const math_namespace = "http://www.w3.org/1998/Math/MathML";
const xlink_namespace = "http://www.w3.org/1999/xlink";

pub const Name = struct {
    local: []const u8,
    namespace: ?[]const u8 = null,

    fn eql(a: Name, b: Name) bool {
        return std.mem.eql(u8, a.local, b.local) and optionalStringEqual(a.namespace, b.namespace);
    }

    fn clone(self: Name, allocator: Allocator) !Name {
        return .{ .local = try allocator.dupe(u8, self.local), .namespace = if (self.namespace) |ns| try allocator.dupe(u8, ns) else null };
    }

    fn isData(self: Name) bool {
        return self.namespace == null and std.mem.startsWith(u8, self.local, "data-");
    }

    fn nonReplaceable(self: Name) bool {
        return self.eql(.{ .local = "html", .namespace = html_namespace }) or
            self.eql(.{ .local = "svg", .namespace = svg_namespace }) or
            self.eql(.{ .local = "math", .namespace = math_namespace });
    }
};

pub const Element = struct {
    name: Name,
    attributes: ?[]Name = null,
    remove_attributes: ?[]Name = null,
};

pub const Data = struct {
    elements: ?[]Element = null,
    remove_elements: ?[]Name = null,
    replace_elements: ?[]Name = null,
    attributes: ?[]Name = null,
    remove_attributes: ?[]Name = null,
    processing_instructions: ?[][]const u8 = null,
    remove_processing_instructions: ?[][]const u8 = null,
    comments: ?bool = null,
    data_attributes: ?bool = null,
    javascript_urls: ?bool = null,

    /// HTML "canonicalize the configuration", steps 1–13. Entry
    /// canonicalization has already copied and normalized each name.
    fn canonicalize(self: *Data, permissive: bool) void {
        if (self.elements == null and self.remove_elements == null) self.remove_elements = &.{};
        if (self.attributes == null and self.remove_attributes == null) self.remove_attributes = &.{};
        if (self.processing_instructions == null and self.remove_processing_instructions == null) {
            if (permissive) self.remove_processing_instructions = &.{} else self.processing_instructions = &.{};
        }
        if (self.elements) |elements| for (elements) |*element| {
            if (element.attributes == null and element.remove_attributes == null) element.remove_attributes = &.{};
        };
        if (self.comments == null) self.comments = permissive;
        if (self.attributes != null and self.data_attributes == null) self.data_attributes = permissive;
        if (self.javascript_urls == null) self.javascript_urls = permissive;
    }

    /// HTML "valid", steps 2–17. Empty and absent lists remain different.
    fn valid(self: Data) bool {
        if (self.elements != null and self.remove_elements != null) return false;
        if (self.attributes != null and self.remove_attributes != null) return false;
        if (self.processing_instructions != null and self.remove_processing_instructions != null) return false;
        if (self.elements) |elements| for (elements, 0..) |element, i| {
            for (elements[0..i]) |previous| if (element.name.eql(previous.name)) return false;
        };
        inline for (.{ self.remove_elements, self.replace_elements, self.attributes, self.remove_attributes }) |list| {
            if (hasDuplicates(list)) return false;
        }
        inline for (.{ self.processing_instructions, self.remove_processing_instructions }) |list| {
            if (list) |items| for (items, 0..) |item, i| {
                for (items[0..i]) |previous| if (std.mem.eql(u8, item, previous)) return false;
            };
        }
        if (self.replace_elements) |names| for (names) |name| {
            if (name.nonReplaceable() or elementIndex(self.elements, name) != null or contains(self.remove_elements, name)) return false;
        };
        if (self.attributes) |global| {
            if (self.data_attributes == true) for (global) |name| {
                if (name.isData()) return false;
            };
            if (self.elements) |elements| for (elements) |element| {
                if (hasDuplicates(element.attributes) or hasDuplicates(element.remove_attributes)) return false;
                if (element.attributes) |local| for (local) |name| {
                    if (contains(global, name) or (self.data_attributes == true and name.isData())) return false;
                };
                if (element.remove_attributes) |local| for (local) |name| {
                    if (!contains(global, name)) return false;
                };
            };
        } else {
            if (self.data_attributes != null) return false;
            if (self.elements) |elements| for (elements) |element| {
                if (element.attributes != null and element.remove_attributes != null) return false;
                if (hasDuplicates(element.attributes) or hasDuplicates(element.remove_attributes)) return false;
                inline for (.{ element.attributes, element.remove_attributes }) |list| {
                    if (list) |names| for (names) |name| {
                        if (contains(self.remove_attributes, name)) return false;
                    };
                }
            };
        }
        return true;
    }

    fn clone(self: Data, allocator: Allocator) !Data {
        var result = self;
        if (self.elements) |elements| {
            result.elements = try allocator.alloc(Element, elements.len);
            for (elements, result.elements.?) |element, *copy| copy.* = .{
                .name = try element.name.clone(allocator),
                .attributes = try cloneNames(allocator, element.attributes),
                .remove_attributes = try cloneNames(allocator, element.remove_attributes),
            };
        }
        inline for (.{ "remove_elements", "replace_elements", "attributes", "remove_attributes" }) |field| {
            @field(result, field) = try cloneNames(allocator, @field(self, field));
        }
        inline for (.{ "processing_instructions", "remove_processing_instructions" }) |field| {
            if (@field(self, field)) |items| {
                const copies = try allocator.alloc([]const u8, items.len);
                for (items, copies) |item, *copy| copy.* = try allocator.dupe(u8, item);
                @field(result, field) = copies;
            }
        }
        return result;
    }
};

pub const Change = union(enum) {
    allow_element: Element,
    remove_element: Name,
    replace_element: Name,
    allow_attribute: Name,
    remove_attribute: Name,
    allow_pi: []const u8,
    remove_pi: []const u8,
    comments: bool,
    data_attributes: bool,
    javascript_urls: bool,
    remove_unsafe,
};

pub const Config = struct {
    arena: std.heap.ArenaAllocator,
    data: Data,

    pub fn deinit(self: *Config) void {
        self.arena.deinit();
        self.* = undefined;
    }

    pub fn fromData(allocator: Allocator, input: Data, permissive: bool) !Config {
        var result = Config{ .arena = .init(allocator), .data = undefined };
        errdefer result.deinit();
        result.data = try input.clone(result.arena.allocator());
        result.data.canonicalize(permissive);
        if (!result.data.valid()) return error.TypeError;
        return result;
    }

    /// Only the immediate, synchronous copy of Sanitizer.get() below uses
    /// this bridge. No callback runs while its borrowed result is copied.
    fn fromDictionary(allocator: Allocator, input: anytype, permissive: bool) !Config {
        comptime {
            const fields = .{ "elements", "removeElements", "replaceWithChildrenElements", "attributes", "removeAttributes", "comments", "dataAttributes", "processingInstructions", "removeProcessingInstructions", "javascriptURLs" };
            if (std.meta.fields(@TypeOf(input)).len != fields.len) @compileError("Update the SanitizerConfig native copy for its changed members");
            for (fields) |field| if (!@hasField(@TypeOf(input), field)) @compileError("SanitizerConfig is missing " ++ field);
        }
        var result = Config{ .arena = .init(allocator), .data = .{} };
        errdefer result.deinit();
        const a = result.arena.allocator();
        result.data = .{
            .comments = input.comments,
            .data_attributes = input.dataAttributes,
            .javascript_urls = input.javascriptURLs,
            .attributes = try typedNames(a, input.attributes, false),
            .remove_attributes = try typedNames(a, input.removeAttributes, false),
            .remove_elements = try typedNames(a, input.removeElements, true),
            .replace_elements = try typedNames(a, input.replaceWithChildrenElements, true),
            .processing_instructions = try typedPIs(a, input.processingInstructions),
            .remove_processing_instructions = try typedPIs(a, input.removeProcessingInstructions),
        };
        if (input.elements) |elements| {
            result.data.elements = try a.alloc(Element, elements.len);
            for (elements, result.data.elements.?) |element, *copy| copy.* = try typedElement(a, element);
        }
        result.data.canonicalize(permissive);
        if (!result.data.valid()) return error.TypeError;
        return result;
    }

    pub fn clone(self: *const Config, allocator: Allocator) !Config {
        var result = Config{ .arena = .init(allocator), .data = undefined };
        errdefer result.arena.deinit();
        result.data = try self.data.clone(result.arena.allocator());
        return result;
    }

    /// Constructor convenience: WebIDL conversion, then HTML configuration.
    pub fn fromJS(allocator: Allocator, realm: runtime.Context, input: runtime.JSValue, permissive: bool, allow_instance: bool) !Config {
        var converted = try Converted.fromJS(allocator, realm, input, allow_instance);
        defer converted.deinit();
        return fromConverted(allocator, realm, &converted, permissive);
    }

    fn fromConverted(allocator: Allocator, realm: runtime.Context, converted: *const Converted, permissive: bool) !Config {
        return switch (converted.value) {
            .preset => defaultConfig(allocator),
            .dictionary => |data| fromData(allocator, data, permissive),
            .sanitizer => |value| blk: {
                // The binding keeps the JSValue alive across any Trusted Types
                // callback. Resolve it only now; that callback may have changed
                // the Sanitizer's configuration. Copy the borrowed get() result
                // immediately, with no callback between reading and copying.
                const instance = engine.convertToPlatformObject(realm, value) orelse return error.TypeError;
                break :blk fromDictionary(allocator, try interfaces.Sanitizer.call_get(instance), permissive);
            },
        };
    }

    /// get(), steps 3–10: sort a copy so the returned dictionary and every
    /// string it borrows live in the caller's result arena.
    pub fn toData(self: *const Config, allocator: Allocator) !Data {
        const copy = try self.data.clone(allocator);
        inline for (.{ "attributes", "remove_attributes", "remove_elements", "replace_elements" }) |field| {
            if (@field(copy, field)) |names| std.mem.sort(Name, names, {}, nameLess);
        }
        if (copy.elements) |elements| {
            std.mem.sort(Element, elements, {}, elementLess);
            for (elements) |element| {
                if (element.attributes) |names| std.mem.sort(Name, names, {}, nameLess);
                if (element.remove_attributes) |names| std.mem.sort(Name, names, {}, nameLess);
            }
        }
        inline for (.{ "processing_instructions", "remove_processing_instructions" }) |field| {
            if (@field(copy, field)) |items| std.mem.sort([]const u8, items, {}, stringLess);
        }
        return copy;
    }

    /// The old configuration is unchanged if any allocation fails. Nothing
    /// allocated by a successful, later-reversed modifier accumulates forever.
    pub fn apply(self: *Config, change: Change) !bool {
        var next = try self.clone(self.arena.child_allocator);
        errdefer next.deinit();
        const changed = try next.applyToCopy(change);
        if (!changed) {
            next.deinit();
            return false;
        }
        std.debug.assert(next.data.valid());
        self.deinit();
        self.* = next;
        return true;
    }

    fn applyToCopy(self: *Config, change: Change) !bool {
        const a = self.arena.allocator();
        const d = &self.data;
        switch (change) {
            .comments => |allow| {
                if (d.comments == allow) return false;
                d.comments = allow;
                return true;
            },
            .javascript_urls => |allow| {
                if (d.javascript_urls == allow) return false;
                d.javascript_urls = allow;
                return true;
            },
            .allow_pi, .remove_pi => |input| {
                // allow/removeProcessingInstruction, steps 3–5.
                const target = try a.dupe(u8, input);
                const allow = change == .allow_pi;
                const list = if (d.processing_instructions != null) &d.processing_instructions else &d.remove_processing_instructions;
                const adding = allow == (d.processing_instructions != null);
                var found: ?usize = null;
                for (list.*.?, 0..) |item, i| if (std.mem.eql(u8, item, target)) {
                    found = i;
                    break;
                };
                if (adding) {
                    if (found != null) return false;
                    list.* = try appended([]const u8, a, list.*.?, target);
                } else {
                    const index = found orelse return false;
                    list.* = removed([]const u8, list.*.?, index);
                }
                return true;
            },
            .allow_element => |input| {
                // allowElement, step 3 followed by its allow/remove-list arms.
                var element = Element{ .name = try input.name.clone(a), .attributes = try cloneNames(a, input.attributes), .remove_attributes = try cloneNames(a, input.remove_attributes) };
                if (element.attributes == null and element.remove_attributes == null) element.remove_attributes = &.{};
                if (d.elements != null) {
                    const changed = removeName(&d.replace_elements, element.name);
                    deduplicate(&element.attributes);
                    deduplicate(&element.remove_attributes);
                    if (d.attributes) |global| {
                        subtract(&element.attributes, global);
                        if (d.data_attributes == true) removeData(&element.attributes);
                        intersect(&element.remove_attributes, global);
                    } else {
                        if (element.attributes != null) {
                            subtract(&element.attributes, element.remove_attributes orelse &.{});
                            element.remove_attributes = null;
                            subtract(&element.attributes, d.remove_attributes.?);
                        }
                        subtract(&element.remove_attributes, d.remove_attributes.?);
                    }
                    if (elementIndex(d.elements, element.name)) |index| {
                        const current = d.elements.?[index];
                        if (sameNames(current.attributes, element.attributes) and sameNames(current.remove_attributes, element.remove_attributes)) return changed;
                        d.elements.?[index] = element;
                    } else d.elements = try appended(Element, a, d.elements.?, element);
                    return true;
                }
                if (element.attributes != null) return false;
                if (element.remove_attributes) |attributes| if (attributes.len != 0) return false;
                const changed = removeName(&d.replace_elements, element.name);
                return removeName(&d.remove_elements, element.name) or changed;
            },
            .remove_element => |input| return self.removeElement(try input.clone(a)),
            .replace_element => |input| {
                // replaceElementWithChildren, steps 3–8.
                const name = try input.clone(a);
                if (name.nonReplaceable()) return false;
                var changed = removeElementEntry(&d.elements, name);
                changed = removeName(&d.remove_elements, name) or changed;
                if (contains(d.replace_elements, name)) return changed;
                d.replace_elements = try appended(Name, a, d.replace_elements orelse &.{}, name);
                return true;
            },
            .allow_attribute => |input| {
                const name = try input.clone(a);
                if (d.attributes) |global| {
                    if ((d.data_attributes == true and name.isData()) or contains(global, name)) return false;
                    if (d.elements) |elements| for (elements) |*element| {
                        _ = removeName(&element.attributes, name);
                    };
                    d.attributes = try appended(Name, a, global, name);
                    return true;
                }
                return removeName(&d.remove_attributes, name);
            },
            .remove_attribute => |input| return self.removeAttribute(try input.clone(a)),
            .data_attributes => |allow| {
                // setDataAttributes, steps 3–7.
                if (d.attributes == null or d.data_attributes == allow) return false;
                if (allow) {
                    removeData(&d.attributes);
                    if (d.elements) |elements| for (elements) |*element| removeData(&element.attributes);
                }
                d.data_attributes = allow;
                return true;
            },
            .remove_unsafe => return self.removeUnsafe(),
        }
    }

    fn removeElement(self: *Config, name: Name) !bool {
        // HTML "remove an element", steps 3–5.
        const changed = removeName(&self.data.replace_elements, name);
        if (self.data.elements != null) return removeElementEntry(&self.data.elements, name) or changed;
        if (contains(self.data.remove_elements, name)) return changed;
        self.data.remove_elements = try appended(Name, self.arena.allocator(), self.data.remove_elements.?, name);
        return true;
    }

    fn removeAttribute(self: *Config, name: Name) !bool {
        // HTML "remove an attribute", steps 3–4.
        const d = &self.data;
        if (d.attributes != null) {
            var changed = removeName(&d.attributes, name);
            if (d.elements) |elements| for (elements) |*element| {
                changed = removeName(&element.attributes, name) or changed;
                _ = removeName(&element.remove_attributes, name);
            };
            return changed;
        }
        if (contains(d.remove_attributes, name)) return false;
        if (d.elements) |elements| for (elements) |*element| {
            _ = removeName(&element.attributes, name);
            _ = removeName(&element.remove_attributes, name);
        };
        d.remove_attributes = try appended(Name, self.arena.allocator(), d.remove_attributes.?, name);
        return true;
    }

    fn removeUnsafe(self: *Config) !bool {
        // HTML "remove unsafe", steps 2–7. The known event-handler names,
        // not an arbitrary `on` prefix, form the unsafe attribute list.
        var changed = false;
        for ([_][]const u8{ "base", "iframe", "embed", "object", "script", "frame" }) |local| {
            changed = try self.removeElement(.{ .local = local, .namespace = html_namespace }) or changed;
        }
        for ([_][]const u8{ "script", "use" }) |local| {
            changed = try self.removeElement(.{ .local = local, .namespace = svg_namespace }) or changed;
        }
        for (event_handler_names) |local| changed = try self.removeAttribute(.{ .local = local }) or changed;
        if (self.data.javascript_urls == true) {
            self.data.javascript_urls = false;
            changed = true;
        }
        return changed;
    }
};

/// WebIDL conversion is earlier than the HTML algorithm's validation. In
/// particular it runs before Trusted Types and the script-context early return.
/// Dictionaries own only native strings; the Sanitizer arm borrows the JSValue
/// already held by the binding for this synchronous operation.
pub const Converted = struct {
    arena: std.heap.ArenaAllocator,
    value: union(enum) { dictionary: Data, preset, sanitizer: runtime.JSValue },

    pub fn deinit(self: *Converted) void {
        self.arena.deinit();
        self.* = undefined;
    }

    fn fromJS(allocator: Allocator, realm: runtime.Context, input: runtime.JSValue, allow_instance: bool) engine.Error!Converted {
        var result = Converted{ .arena = .init(allocator), .value = .{ .dictionary = .{} } };
        errdefer result.deinit();
        const kind = engine.typeOf(realm, input);
        if (allow_instance and kind == .object) {
            if (engine.convertToPlatformObject(realm, input)) |instance| {
                if (std.mem.eql(u8, instance.vtable.name, "Sanitizer")) {
                    result.value = .{ .sanitizer = input };
                    return result;
                }
            }
        }
        const a = result.arena.allocator();
        if (kind != .object and kind != .null and kind != .undefined) {
            const preset = try engine.convertToDOMString(realm, input, a);
            if (!std.mem.eql(u8, preset, "default")) return error.TypeError;
            result.value = .preset;
        } else if (kind == .object) {
            const d = &result.value.dictionary;
            // WebIDL dictionary conversion: lexicographic member order.
            d.attributes = try readNames(a, realm, input, "attributes", false);
            d.comments = try engine.getPropertyBoolean(realm, input, "comments");
            d.data_attributes = try engine.getPropertyBoolean(realm, input, "dataAttributes");
            d.elements = try readElements(a, realm, input);
            d.javascript_urls = try engine.getPropertyBoolean(realm, input, "javascriptURLs");
            d.processing_instructions = try readPIs(a, realm, input, "processingInstructions");
            d.remove_attributes = try readNames(a, realm, input, "removeAttributes", false);
            d.remove_elements = try readNames(a, realm, input, "removeElements", true);
            d.remove_processing_instructions = try readPIs(a, realm, input, "removeProcessingInstructions");
            d.replace_elements = try readNames(a, realm, input, "replaceWithChildrenElements", true);
        }
        return result;
    }
};

pub fn convertOptions(realm: runtime.Context, option: ?runtime.JSValue, safe: bool) engine.Error!Converted {
    return Converted.fromJS(realm.allocator, realm, option orelse
        (if (safe) runtime.JSValue.fromStringRef("default") else runtime.JSValue.jsNull), true);
}

fn optionalStringEqual(a: ?[]const u8, b: ?[]const u8) bool {
    if (a) |left| return if (b) |right| std.mem.eql(u8, left, right) else false;
    return b == null;
}

const ListKind = enum { element_names, attribute_names, elements, processing_instructions };

fn ListItem(comptime kind: ListKind) type {
    return switch (kind) {
        .element_names, .attribute_names => Name,
        .elements => Element,
        .processing_instructions => []const u8,
    };
}

/// WebIDL sequence conversion performs each item's conversion before asking
/// the iterator for its next item. Abrupt conversion stops without calling
/// iterator.return, per WebIDL 3.2.21.1; no JS value is retained.
fn readList(comptime kind: ListKind, allocator: Allocator, realm: runtime.Context, object: runtime.JSValue, key: []const u8) engine.Error!?[]ListItem(kind) {
    const property = try engine.getProperty(realm, object, key);
    defer property.release();
    if (engine.typeOf(realm, property.value) == .undefined) return null;
    const Collector = struct {
        allocator: Allocator,
        realm: runtime.Context,
        items: infra.List(ListItem(kind)),

        fn each(data: ?*anyopaque, value: runtime.JSValue) engine.Error!void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            const item = switch (kind) {
                .element_names, .attribute_names => try readName(self.allocator, self.realm, value, kind == .element_names),
                .elements => try readElement(self.allocator, self.realm, value),
                .processing_instructions => try readPI(self.allocator, self.realm, value),
            };
            try self.items.append(item);
        }
    };
    var collector = Collector{ .allocator = allocator, .realm = realm, .items = .init(allocator) };
    defer collector.items.deinit();
    if (!try engine.iterate(realm, property.value, Collector.each, &collector)) return error.TypeError;
    return try collector.items.toOwnedSlice();
}

fn readNames(allocator: Allocator, realm: runtime.Context, object: runtime.JSValue, key: []const u8, comptime is_element: bool) engine.Error!?[]Name {
    return readList(if (is_element) .element_names else .attribute_names, allocator, realm, object, key);
}

fn readName(allocator: Allocator, realm: runtime.Context, input: runtime.JSValue, comptime is_element: bool) engine.Error!Name {
    const kind = engine.typeOf(realm, input);
    if (kind == .null or kind == .undefined) return error.TypeError; // required name
    if (kind != .object) return .{
        .local = try engine.convertToDOMString(realm, input, allocator),
        .namespace = if (is_element) html_namespace else null,
    };
    const name = try engine.getProperty(realm, input, "name");
    defer name.release();
    if (engine.typeOf(realm, name.value) == .undefined) return error.TypeError;
    const local = try engine.convertToDOMString(realm, name.value, allocator);
    const ns = try engine.getProperty(realm, input, "namespace");
    defer ns.release();
    const ns_kind = engine.typeOf(realm, ns.value);
    if (ns_kind == .undefined) return .{ .local = local, .namespace = if (is_element) html_namespace else null };
    if (ns_kind == .null) return .{ .local = local };
    const namespace = try engine.convertToDOMString(realm, ns.value, allocator);
    return .{ .local = local, .namespace = if (namespace.len == 0) null else namespace };
}

fn readElements(allocator: Allocator, realm: runtime.Context, input: runtime.JSValue) engine.Error!?[]Element {
    return readList(.elements, allocator, realm, input, "elements");
}

fn readElement(allocator: Allocator, realm: runtime.Context, value: runtime.JSValue) engine.Error!Element {
    // Inherited dictionary members (name and namespace) precede own ones.
    var element = Element{ .name = try readName(allocator, realm, value, true) };
    if (engine.typeOf(realm, value) == .object) {
        element.attributes = try readNames(allocator, realm, value, "attributes", false);
        element.remove_attributes = try readNames(allocator, realm, value, "removeAttributes", false);
    }
    return element;
}

fn readPIs(allocator: Allocator, realm: runtime.Context, input: runtime.JSValue, key: []const u8) engine.Error!?[][]const u8 {
    return readList(.processing_instructions, allocator, realm, input, key);
}

fn readPI(allocator: Allocator, realm: runtime.Context, value: runtime.JSValue) engine.Error![]const u8 {
    return switch (engine.typeOf(realm, value)) {
        .null, .undefined => error.TypeError,
        .object => blk: {
            const member = try engine.getProperty(realm, value, "target");
            defer member.release();
            if (engine.typeOf(realm, member.value) == .undefined) return error.TypeError;
            break :blk try engine.convertToDOMString(realm, member.value, allocator);
        },
        else => try engine.convertToDOMString(realm, value, allocator),
    };
}

fn nameLess(_: void, a: Name, b: Name) bool {
    if (a.namespace) |left| {
        const right = b.namespace orelse return false;
        if (!std.mem.eql(u8, left, right)) return stringLess({}, left, right);
    } else if (b.namespace != null) return true;
    return stringLess({}, a.local, b.local);
}

fn elementLess(_: void, a: Element, b: Element) bool {
    return nameLess({}, a.name, b.name);
}

fn stringLess(_: void, a: []const u8, b: []const u8) bool {
    var left = CodeUnits{ .points = std.unicode.Wtf8View.initUnchecked(a).iterator() };
    var right = CodeUnits{ .points = std.unicode.Wtf8View.initUnchecked(b).iterator() };
    while (left.next()) |l| {
        const r = right.next() orelse return false;
        if (l != r) return l < r;
    }
    return right.next() != null;
}

const CodeUnits = struct {
    points: std.unicode.Wtf8Iterator,
    trailing: ?u16 = null,

    fn next(self: *CodeUnits) ?u16 {
        if (self.trailing) |unit| {
            self.trailing = null;
            return unit;
        }
        const point = self.points.nextCodepoint() orelse return null;
        if (point <= 0xffff) return @intCast(point);
        const offset = point - 0x10000;
        self.trailing = @intCast(0xdc00 + (offset & 0x3ff));
        return @intCast(0xd800 + (offset >> 10));
    }
};

fn normalizedNamespace(value: ?DOMString) ?[]const u8 {
    const string = value orelse return null;
    return if (string.isEmpty()) null else string.asSlice();
}

fn typedName(allocator: Allocator, input: anytype, comptime is_element: bool) !Name {
    if (input == .domstring) return (Name{
        .local = input.domstring.asSlice(),
        .namespace = if (is_element) html_namespace else null,
    }).clone(allocator);
    const dictionary = if (is_element) input.sanitizer_element_namespace else input.sanitizer_attribute_namespace;
    const name = Name{
        .local = dictionary.name.asSlice(),
        .namespace = if (is_element)
            (if (dictionary.namespace.was_passed) normalizedNamespace(dictionary.namespace.value) else html_namespace)
        else
            normalizedNamespace(dictionary.namespace),
    };
    return name.clone(allocator);
}

fn typedNames(allocator: Allocator, input: anytype, comptime is_element: bool) !?[]Name {
    const items = input orelse return null;
    const result = try allocator.alloc(Name, items.len);
    for (items, result) |item, *copy| copy.* = try typedName(allocator, item, is_element);
    return result;
}

fn typedElement(allocator: Allocator, input: anytype) !Element {
    return switch (input) {
        .domstring => |string| .{ .name = try (Name{ .local = string.asSlice(), .namespace = html_namespace }).clone(allocator), .remove_attributes = &.{} },
        .sanitizer_element_namespace_with_attributes => |dictionary| .{
            .name = try (Name{ .local = dictionary.base.name.asSlice(), .namespace = if (dictionary.base.namespace.was_passed) normalizedNamespace(dictionary.base.namespace.value) else html_namespace }).clone(allocator),
            .attributes = try typedNames(allocator, dictionary.attributes, false),
            .remove_attributes = try typedNames(allocator, dictionary.removeAttributes, false),
        },
    };
}

fn piString(input: anytype) []const u8 {
    return switch (input) {
        .domstring => |string| string.asSlice(),
        .sanitizer_processing_instruction => |dictionary| dictionary.target.asSlice(),
    };
}

fn typedPIs(allocator: Allocator, input: anytype) !?[][]const u8 {
    const items = input orelse return null;
    const result = try allocator.alloc([]const u8, items.len);
    for (items, result) |item, *copy| copy.* = try allocator.dupe(u8, piString(item));
    return result;
}

fn cloneNames(allocator: Allocator, input: ?[]Name) !?[]Name {
    const items = input orelse return null;
    const result = try allocator.alloc(Name, items.len);
    for (items, result) |item, *copy| copy.* = try item.clone(allocator);
    return result;
}

fn contains(list: ?[]const Name, name: Name) bool {
    for (list orelse &.{}) |item| if (item.eql(name)) return true;
    return false;
}

fn elementIndex(list: ?[]const Element, name: Name) ?usize {
    for (list orelse &.{}, 0..) |item, i| if (item.name.eql(name)) return i;
    return null;
}

fn hasDuplicates(list: ?[]const Name) bool {
    for (list orelse &.{}, 0..) |item, i| if (contains(list.?[0..i], item)) return true;
    return false;
}

fn sameNames(a: ?[]const Name, b: ?[]const Name) bool {
    if (a == null or b == null) return a == null and b == null;
    if (a.?.len != b.?.len) return false;
    for (a.?) |name| if (!contains(b, name)) return false;
    return true;
}

fn appended(comptime T: type, allocator: Allocator, items: []const T, item: T) ![]T {
    var list = infra.List(T).init(allocator);
    defer list.deinit();
    try list.appendSlice(items);
    try list.append(item);
    return list.toOwnedSlice();
}

fn removed(comptime T: type, items: []T, index: usize) []T {
    std.mem.copyForwards(T, items[index .. items.len - 1], items[index + 1 ..]);
    return items[0 .. items.len - 1];
}

fn removeName(list: *?[]Name, name: Name) bool {
    const items = list.* orelse return false;
    for (items, 0..) |item, i| if (item.eql(name)) {
        list.* = removed(Name, items, i);
        return true;
    };
    return false;
}

fn removeElementEntry(list: *?[]Element, name: Name) bool {
    const index = elementIndex(list.*, name) orelse return false;
    list.* = removed(Element, list.*.?, index);
    return true;
}

fn deduplicate(list: *?[]Name) void {
    const items = list.* orelse return;
    var len: usize = 0;
    for (items) |item| if (!contains(items[0..len], item)) {
        items[len] = item;
        len += 1;
    };
    list.* = items[0..len];
}

fn subtract(list: *?[]Name, other: []const Name) void {
    const items = list.* orelse return;
    var len: usize = 0;
    for (items) |item| if (!contains(other, item)) {
        items[len] = item;
        len += 1;
    };
    list.* = items[0..len];
}

fn intersect(list: *?[]Name, other: []const Name) void {
    const items = list.* orelse return;
    var len: usize = 0;
    for (items) |item| if (contains(other, item)) {
        items[len] = item;
        len += 1;
    };
    list.* = items[0..len];
}

fn removeData(list: *?[]Name) void {
    const items = list.* orelse return;
    var len: usize = 0;
    for (items) |item| if (!item.isData()) {
        items[len] = item;
        len += 1;
    };
    list.* = items[0..len];
}

// Use the same generated content-handler surface as Trusted Types. Only
// static names are kept; no live DOM or engine state is introduced.
const event_handler_names = blk: {
    @setEvalBranchQuota(200_000);
    var names: []const []const u8 = &.{};
    for (.{ interfaces.HTMLElement, interfaces.Element, interfaces.HTMLBodyElement, interfaces.HTMLMediaElement, interfaces.SVGAnimationElement }) |Interface| {
        for (Interface.Meta.properties) |property| {
            const name: []const u8 = property[0];
            if (name.len <= 2 or !std.mem.startsWith(u8, name, "on")) continue;
            var seen = false;
            for (names) |previous| if (std.mem.eql(u8, previous, name)) {
                seen = true;
                break;
            };
            if (!seen) names = names ++ .{name};
        }
    }
    break :blk names;
};

/// HTML 8.6.5, built-in safe default configuration. HTML entries come from
/// their individual normative sanitization categories; foreign entries and
/// global attributes come from the tables in this section.
fn defaultConfig(allocator: Allocator) !Config {
    var result = Config{ .arena = .init(allocator), .data = .{
        .attributes = null,
        .comments = false,
        .data_attributes = false,
        .javascript_urls = false,
        .processing_instructions = &.{},
    } };
    errdefer result.deinit();
    const a = result.arena.allocator();
    result.data.attributes = try namesFromWords(a, default_attributes);
    var elements = infra.List(Element).init(a);
    defer elements.deinit();
    inline for (.{
        .{ html_namespace, default_html_elements },
        .{ math_namespace, default_math_elements },
        .{ svg_namespace, default_svg_elements },
    }) |group| {
        var rows = std.mem.tokenizeScalar(u8, group[1], '\n');
        while (rows.next()) |row| {
            var words = std.mem.tokenizeScalar(u8, row, ' ');
            const local = words.next() orelse continue;
            try elements.append(.{
                .name = .{ .local = local, .namespace = group[0] },
                // Even the empty default attribute list is present.
                .attributes = try namesFromWords(a, words.rest()),
            });
        }
    }
    result.data.elements = try elements.toOwnedSlice();
    std.debug.assert(result.data.valid());
    return result;
}

fn namesFromWords(allocator: Allocator, input: []const u8) ![]Name {
    var list = infra.List(Name).init(allocator);
    defer list.deinit();
    var words = std.mem.tokenizeAny(u8, input, " \n");
    while (words.next()) |local| try list.append(.{ .local = local });
    return list.toOwnedSlice();
}

const default_attributes =
    "dir lang title alignment-baseline baseline-shift clip-path clip-rule color " ++
    "color-interpolation cursor direction display displaystyle dominant-baseline " ++
    "fill fill-opacity fill-rule font-family font-size font-size-adjust font-stretch " ++
    "font-style font-variant font-weight letter-spacing marker-end marker-mid marker-start " ++
    "mathbackground mathcolor mathsize opacity paint-order pointer-events scriptlevel " ++
    "shape-rendering stop-color stop-opacity stroke stroke-dasharray stroke-dashoffset " ++
    "stroke-linecap stroke-linejoin stroke-miterlimit stroke-opacity stroke-width text-anchor " ++
    "text-decoration text-overflow text-rendering transform transform-origin unicode-bidi " ++
    "vector-effect visibility white-space word-spacing writing-mode";

const default_html_elements =
    \\html
    \\head
    \\title
    \\body
    \\article
    \\section
    \\nav
    \\aside
    \\h1
    \\h2
    \\h3
    \\h4
    \\h5
    \\h6
    \\hgroup
    \\header
    \\footer
    \\address
    \\p
    \\hr
    \\pre
    \\blockquote cite
    \\ol reversed start type
    \\ul
    \\menu
    \\li value
    \\dl
    \\dt
    \\dd
    \\figure
    \\figcaption
    \\main
    \\search
    \\div
    \\a href hreflang type
    \\em
    \\strong
    \\small
    \\s
    \\cite
    \\q
    \\dfn
    \\abbr
    \\ruby
    \\rt
    \\rp
    \\data value
    \\time datetime
    \\code
    \\var
    \\samp
    \\kbd
    \\sub
    \\sup
    \\i
    \\b
    \\u
    \\mark
    \\bdi
    \\bdo
    \\span
    \\br
    \\wbr
    \\ins cite datetime
    \\del cite datetime
    \\table
    \\caption
    \\colgroup span
    \\col span
    \\tbody
    \\thead
    \\tfoot
    \\tr
    \\td colspan headers rowspan
    \\th abbr colspan headers rowspan scope
;

const default_math_elements =
    \\math
    \\merror
    \\mfrac
    \\mi
    \\mmultiscripts
    \\mn
    \\mo fence form largeop lspace maxsize minsize movablelimits rspace separator stretchy symmetric
    \\mover accent
    \\mpadded depth height lspace voffset width
    \\mphantom
    \\mprescripts
    \\mroot
    \\mrow
    \\ms
    \\mspace depth height width
    \\msqrt
    \\mstyle
    \\msub
    \\msubsup
    \\msup
    \\mtable
    \\mtd columnspan rowspan
    \\mtext
    \\mtr
    \\munder accentunder
    \\munderover accent accentunder
    \\semantics
;

const default_svg_elements =
    \\a href hreflang type
    \\circle cx cy pathLength r
    \\defs
    \\desc
    \\ellipse cx cy pathLength rx ry
    \\foreignObject height width x y
    \\g
    \\line pathLength x1 x2 y1 y2
    \\marker markerHeight markerUnits markerWidth orient preserveAspectRatio refX refY viewBox
    \\metadata
    \\path d pathLength
    \\polygon pathLength points
    \\polyline pathLength points
    \\rect height pathLength rx ry width x y
    \\svg height preserveAspectRatio viewBox width x y
    \\text dx dy lengthAdjust rotate textLength x y
    \\textPath lengthAdjust method path side spacing startOffset textLength
    \\title
    \\tspan dx dy lengthAdjust rotate textLength x y
;

/// HTML "set and filter HTML", steps 1–9. Only this API calls the filter.
/// The existing parser marks scripts already-started but still schedules
/// resources and custom-element work before filtering. An inert-document
/// parser is required before these safe entry points can ship (row 41 Q12).
pub fn setHTML(receiver: *runtime.Instance, target: *runtime.Instance, source: []const u8, converted: *const Converted, safe: bool) !void {
    const context = if (receiver.stateAs(interfaces.ShadowRoot.State) != null) try interfaces.ShadowRoot.get_host(receiver) else receiver;
    if (safe) {
        const name = dom.node_creation.elementNames(context) orelse return error.InvalidStateError;
        if (std.mem.eql(u8, name.local_name, "script") and
            (optionalStringEqual(name.namespace, html_namespace) or optionalStringEqual(name.namespace, svg_namespace))) return;
    }
    var config = try Config.fromConverted(receiver.ctx.allocator, receiver.ctx, converted, !safe);
    defer config.deinit();
    const fragment = try @import("custom_elements.zig").parseFragmentUnsafe(receiver, source);
    defer dom.node_creation.destroyUninserted(fragment);
    // Steps 7–8 parse the complete fragment before filtering. Chrome 154's
    // streaming sanitizer and Firefox 157 split on adoption-agency cases
    // 6, 12 and 13; the tie follows the spec's tree, also Firefox's result.
    try sanitize(fragment, &config, safe);
    const parent = dom.instance_bridge.getNodeBase(target) orelse return error.InvalidStateError;
    const contents = dom.instance_bridge.getNodeBase(fragment) orelse return error.InvalidStateError;
    try dom.mutation.replaceAll(@as(?*dom.NodeBase, contents), parent);
}

/// Document.parseHTML[Unsafe], steps 4–6 after parsing the inactive document.
pub fn filterDocument(document: *runtime.Instance, converted: *const Converted, safe: bool) !void {
    var config = try Config.fromConverted(document.ctx.allocator, document.ctx, converted, !safe);
    defer config.deinit();
    try sanitize(document, &config, safe);
}

/// HTML "sanitize", steps 1–4. Safe mode copies the configuration before
/// applying its baseline, matching Blink Sanitizer::SanitizeSafe and keeping
/// a caller-supplied Sanitizer immutable (sanitizer-base-immutable WPT).
pub fn sanitize(node: *runtime.Instance, config: *const Config, safe: bool) !void {
    const base = dom.instance_bridge.getNodeBase(node) orelse return error.InvalidStateError;
    if (safe) {
        var safe_config = try config.clone(node.ctx.allocator);
        defer safe_config.deinit();
        _ = try safe_config.removeUnsafe();
        try innerSanitize(base, &safe_config.data);
    } else try innerSanitize(base, &config.data);
}

/// HTML "inner sanitize steps". Use the existing DOM mutation and attribute
/// hooks, which keep observer, custom-element and ownership bookkeeping in
/// their owners. No wrappers are created to inspect nodes or attributes.
/// Removal leaves adjacent Text nodes separate: HTML specifies no normalize
/// step. Chrome 154 coalesces them and Firefox 157 does not (basic-filtering
/// comments/1 and sethtml-safety); the shipping-browser tie follows the spec.
fn innerSanitize(node: *dom.NodeBase, config: *const Data) anyerror!void {
    var child = node.first_child;
    while (child) |current| {
        child = current.next_sibling;
        switch (current.node_type) {
            3, 10 => continue, // step 1.2: Text and DocumentType
            8 => { // step 1.3: comments
                if (config.comments != true) try dom.mutation.remove(current, false);
            },
            7 => { // step 1.4: processing instructions
                const instance = dom.instance_bridge.getInstanceTyped(runtime.Instance, current) orelse return error.InvalidStateError;
                var target = try interfaces.ProcessingInstruction.get_target(instance);
                defer target.deinit(instance.ctx.allocator);
                const allowed = if (config.processing_instructions) |list|
                    hasTarget(list, target.asSlice())
                else
                    !hasTarget(config.remove_processing_instructions.?, target.asSlice());
                if (!allowed) try dom.mutation.remove(current, false);
            },
            1 => {
                const instance = dom.instance_bridge.getInstanceTyped(runtime.Instance, current) orelse return error.InvalidStateError;
                const names = dom.node_creation.elementNames(instance) orelse return error.InvalidStateError;
                const name = Name{ .local = names.local_name, .namespace = names.namespace };
                // Step 1.5.2: filter children before replacing their container.
                if (contains(config.replace_elements, name)) {
                    try innerSanitize(current, config);
                    const parent_instance = dom.instance_bridge.getInstanceTyped(runtime.Instance, node) orelse return error.InvalidStateError;
                    const document = try interfaces.Node.get_ownerDocument(parent_instance) orelse return error.InvalidStateError;
                    const fragment = try interfaces.Document.call_createDocumentFragment(document);
                    defer dom.node_creation.destroyUninserted(fragment);
                    const fragment_base = dom.instance_bridge.getNodeBase(fragment) orelse return error.InvalidStateError;
                    while (current.first_child) |inner| _ = try dom.mutation.append(inner, fragment_base);
                    _ = try dom.mutation.replace(current, fragment_base, node);
                    continue;
                }
                const local_index = elementIndex(config.elements, name);
                // Steps 1.5.3–4: the global element allow/remove list.
                if (if (config.elements != null) local_index == null else contains(config.remove_elements, name)) {
                    try dom.mutation.remove(current, false);
                    continue;
                }
                // Steps 1.5.5–6: both hosted trees, including closed roots.
                if (dom.template_contents.contentOf(instance)) |template| {
                    try innerSanitize(dom.instance_bridge.getNodeBase(template) orelse return error.InvalidStateError, config);
                }
                if (dom.shadow_hosts.rootForHost(instance)) |shadow| {
                    try innerSanitize(dom.instance_bridge.getNodeBase(shadow) orelse return error.InvalidStateError, config);
                }
                const local = if (local_index) |index| config.elements.?[index] else Element{ .name = name };
                // Steps 1.5.7–9: a removed attribute shifts the next one into
                // this index. Its borrowed name/value are not used afterwards.
                var index: usize = 0;
                while (dom.element_attributes.at(instance, index)) |attribute| {
                    const attribute_name = Name{ .local = attribute.local_name, .namespace = attribute.namespace };
                    var allowed = !contains(local.remove_attributes, attribute_name);
                    if (allowed) {
                        if (config.attributes) |global| {
                            allowed = contains(global, attribute_name) or contains(local.attributes, attribute_name) or
                                (config.data_attributes == true and attribute_name.isData());
                        } else {
                            allowed = (local.attributes == null or contains(local.attributes, attribute_name)) and
                                !contains(config.remove_attributes, attribute_name);
                        }
                    }
                    if (allowed and config.javascript_urls != true) {
                        if (isNavigatingAttribute(name, attribute_name) and try hasJavascriptURL(instance.ctx.allocator, attribute.value)) allowed = false;
                        // Browser deviation from HTML's literal href/xlink:href:
                        // Chrome 154 and Firefox 157 strip arbitrary prefixes
                        // (sanitizer-svg-animate #8/#10/#12/#14/#16). Retain
                        // xlink:href:x: their #18/#20 split goes to the spec.
                        // Gecko uses this suffix rule in
                        // dom/security/sanitizer/Sanitizer.cpp,
                        // ShouldRemoveJavascriptNavigationURLAttribute, step 3.
                        if (optionalStringEqual(name.namespace, svg_namespace) and attribute_name.eql(.{ .local = "attributeName" }) and
                            (std.mem.eql(u8, name.local, "animate") or std.mem.eql(u8, name.local, "animateTransform") or std.mem.eql(u8, name.local, "set")) and
                            (std.mem.eql(u8, attribute.value, "href") or std.mem.endsWith(u8, attribute.value, ":href"))) allowed = false;
                    }
                    if (allowed) index += 1 else dom.element_attributes.remove(instance, attribute.namespace, attribute.local_name);
                }
                // Step 1.5.10.
                try innerSanitize(current, config);
            },
            else => {},
        }
    }
}

fn hasTarget(list: []const []const u8, target: []const u8) bool {
    for (list) |item| if (std.mem.eql(u8, item, target)) return true;
    return false;
}

fn isNavigatingAttribute(element: Name, attribute: Name) bool {
    if (optionalStringEqual(element.namespace, math_namespace) or
        (optionalStringEqual(element.namespace, svg_namespace) and std.mem.eql(u8, element.local, "a")))
    {
        return std.mem.eql(u8, attribute.local, "href") and
            (attribute.namespace == null or optionalStringEqual(attribute.namespace, xlink_namespace));
    }
    if (!optionalStringEqual(element.namespace, html_namespace) or attribute.namespace != null) return false;
    if (std.mem.eql(u8, attribute.local, "href")) {
        return std.mem.eql(u8, element.local, "a") or std.mem.eql(u8, element.local, "area") or std.mem.eql(u8, element.local, "base");
    }
    if (std.mem.eql(u8, attribute.local, "formaction")) return std.mem.eql(u8, element.local, "button") or std.mem.eql(u8, element.local, "input");
    return (std.mem.eql(u8, attribute.local, "action") and std.mem.eql(u8, element.local, "form")) or
        (std.mem.eql(u8, attribute.local, "src") and std.mem.eql(u8, element.local, "iframe"));
}

fn hasJavascriptURL(allocator: Allocator, input: []const u8) !bool {
    // HTML "contains a javascript: URL", steps 1–3: use the URL parser,
    // including its whitespace/control-character handling and failure rules.
    var parsed = @import("url").parser.basic_url_parser.parse(allocator, input, null) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return false,
    };
    defer parsed.deinit();
    return std.mem.eql(u8, parsed.scheme(), "javascript");
}
