//! The binding's interface-type tables and predicates (WebIDL 3.2.15), and
//! their coverage: codegen names the interface of every interface-typed
//! position (`interface_arguments`, `constructor_interface_arguments`,
//! `interface_members`), the binding converts one only to the interface named
//! (a position no table covers is a compile error in `conv.fromV8ValueAs`),
//! and `conv.implements` asks the state ancestry. Through script:
//! interface_type_conversion_test.zig.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const interfaces = @import("interfaces");
const conv = v8.conversions;
const binding = v8.interface_mod;

/// A test vtable with no state ancestry, as only a hand-made vtable has.
const no_ancestry_methods: u8 = 0;
const no_ancestry_vtable = runtime.VTable{ .name = "NoAncestry", .deinit = null, .methods_ptr = &no_ancestry_methods };

test "an instance whose vtable has no ancestry implements no interface" {
    // Every generated vtable has an ancestry (runtime.buildVTable). One
    // without was accepted as any interface - by the receiver check of an
    // accessor and by a union's arms - which only ever let a mock through.
    var state: [64]u8 align(16) = undefined;
    var instance = runtime.Instance{ .vtable = &no_ancestry_vtable, .state = &state, .ctx = undefined };
    try std.testing.expect(!conv.implements(&instance, interfaces.Blob));
    try std.testing.expect(!conv.implements(&instance, interfaces.Node));
}

/// An instance of `I`'s vtable over a state buffer nothing reads: what
/// `implements` asks is the vtable's ancestry.
fn instanceOf(comptime I: type, state: *[256]u8) runtime.Instance {
    return .{ .vtable = &I.vtable, .state = state, .ctx = undefined };
}

test "implements: the interface itself and every interface it inherits" {
    var state: [256]u8 align(16) = undefined;
    const file = instanceOf(interfaces.File, &state);
    try std.testing.expect(conv.implements(&file, interfaces.Blob));
    try std.testing.expect(conv.implements(&file, interfaces.File));
    const blob = instanceOf(interfaces.Blob, &state);
    try std.testing.expect(!conv.implements(&blob, interfaces.File));
    const params = instanceOf(interfaces.URLSearchParams, &state);
    try std.testing.expect(!conv.implements(&params, interfaces.Blob));
    const div = instanceOf(interfaces.HTMLDivElement, &state);
    try std.testing.expect(conv.implements(&div, interfaces.Node));
    try std.testing.expect(conv.implements(&div, interfaces.EventTarget));
    try std.testing.expect(!conv.implements(&div, interfaces.Text));
}

test "the tables: FormData's three-argument append names Blob for its second argument only" {
    try std.testing.expect(binding.argumentInterface(interfaces.FormData, "call_append__1", 1) == interfaces.Blob);
    try std.testing.expect(binding.argumentInterface(interfaces.FormData, "call_append__1", 0) == null);
    try std.testing.expect(binding.argumentInterface(interfaces.FormData, "call_append", 1) == null);
    // A function no table names has no interface argument.
    try std.testing.expect(binding.argumentInterface(interfaces.FormData, "call_no_such_function", 0) == null);
    // A typedef of an interface names the interface: MessageEventInit's
    // `source` is a union (its arms are named), its `ports` a sequence of
    // MessagePort.
    try std.testing.expect(conv.memberInterface(conv.generated_dictionaries.MessageEventInit, "ports") == interfaces.MessagePort);
    try std.testing.expect(conv.memberInterface(conv.generated_dictionaries.MessageEventInit, "source") == null);
    try std.testing.expect(binding.constructorArgumentInterface(interfaces.FormData, "", 0) == interfaces.HTMLFormElement);
    try std.testing.expect(binding.constructorArgumentInterface(interfaces.FormData, "", 1) == interfaces.HTMLElement);
}

test "needsInterface: the positions an interface type converts at, by default" {
    // The positions `fromV8ValueAs` must be told an interface for - a
    // conversion of one without is a compile error - and the default for
    // anything else: no interface.
    try std.testing.expect(conv.needsInterface(*runtime.Instance));
    try std.testing.expect(conv.needsInterface(?*runtime.Instance));
    try std.testing.expect(conv.needsInterface([]const *runtime.Instance));
    try std.testing.expect(conv.needsInterface(?[]const *runtime.Instance));
    try std.testing.expect(conv.needsInterface(@import("webidl").Opt(?*runtime.Instance)));
    try std.testing.expect(!conv.needsInterface(runtime.JSValue));
    try std.testing.expect(!conv.needsInterface(runtime.DOMString));
    try std.testing.expect(!conv.needsInterface([]const u8));
    try std.testing.expect(!conv.needsInterface(conv.generated_typedefs.BodyInit));
    try std.testing.expect(!conv.needsInterface(conv.generated_dictionaries.MouseEventInit));
}

/// The parameters of `function` (a generated delegate) from `first` on, as
/// IDL argument indexes from 0.
fn checkParams(comptime I: type, comptime name: []const u8, comptime first: usize, missing: *usize, checked: *usize) void {
    const params = @typeInfo(@TypeOf(@field(I, name))).@"fn".params;
    inline for (params[first..], 0..) |param, index| {
        if (comptime conv.needsInterface(param.type.?)) {
            if (comptime binding.argumentInterface(I, name, index) == null) {
                std.debug.print("{s}.{s} argument {d} names no interface\n", .{ I.Meta.name, name, index });
                missing.* += 1;
            }
            checked.* += 1;
        }
    }
}

test "every interface-typed position of every generated interface and dictionary names its interface" {
    // What makes the compile error in the binding a guarantee for the members
    // it binds holds for every generated one: nothing is left that converts
    // any platform object.
    @setEvalBranchQuota(100_000_000);
    var missing: usize = 0;
    var checked: usize = 0;
    inline for (comptime std.meta.declarations(interfaces)) |decl| {
        const I = @field(interfaces, decl.name);
        if (comptime @TypeOf(I) == type and @typeInfo(I) == .@"struct" and @hasDecl(I, "Meta") and @hasDecl(I, "State")) {
            inline for (comptime std.meta.declarations(I)) |member| {
                // Only the delegates are read: touching any other declaration
                // (`vtable`) would analyse interfaces nothing else compiles.
                const is_delegate = comptime std.mem.startsWith(u8, member.name, "call_") or std.mem.startsWith(u8, member.name, "set_");
                const is_fn = comptime is_delegate and @typeInfo(@TypeOf(@field(I, member.name))) == .@"fn";
                if (comptime is_fn and std.mem.eql(u8, member.name, "call_constructor")) {
                    const params = @typeInfo(@TypeOf(I.call_constructor)).@"fn".params;
                    inline for (params[1..], 0..) |param, index| {
                        const P = param.type.?;
                        if (comptime @hasDecl(I, "ConstructorArgs") and P == I.ConstructorArgs) {
                            inline for (@typeInfo(P).@"union".fields) |variant| {
                                if (comptime @typeInfo(variant.type) == .@"struct" and !@hasDecl(variant.type, "notPassed") and variant.type != void) {
                                    inline for (@typeInfo(variant.type).@"struct".fields, 0..) |field, i| {
                                        if (comptime conv.needsInterface(field.type)) {
                                            if (comptime binding.constructorArgumentInterface(I, variant.name, i) == null) {
                                                std.debug.print("{s} constructor {s} argument {d} names no interface\n", .{ I.Meta.name, variant.name, i });
                                                missing += 1;
                                            }
                                            checked += 1;
                                        }
                                    }
                                } else if (comptime conv.needsInterface(variant.type)) {
                                    if (comptime binding.constructorArgumentInterface(I, variant.name, 0) == null) {
                                        std.debug.print("{s} constructor {s} names no interface\n", .{ I.Meta.name, variant.name });
                                        missing += 1;
                                    }
                                    checked += 1;
                                }
                            }
                        } else if (comptime conv.needsInterface(P)) {
                            if (comptime binding.constructorArgumentInterface(I, "", index) == null) {
                                std.debug.print("{s} constructor argument {d} names no interface\n", .{ I.Meta.name, index });
                                missing += 1;
                            }
                            checked += 1;
                        }
                    }
                } else if (comptime is_fn) {
                    // (instance, arguments...): argument i is parameter i + 1.
                    checkParams(I, member.name, 1, &missing, &checked);
                }
            }
        }
    }
    const dictionaries = conv.generated_dictionaries;
    inline for (comptime std.meta.declarations(dictionaries)) |decl| {
        // RouterCondition has a member of its own type (`not:
        // RouterCondition?`), which Zig cannot lay out, and RouterRule holds
        // one: nothing converts either, and asking for their fields is a
        // compile error of its own.
        const unlaid = comptime std.mem.eql(u8, decl.name, "RouterCondition") or std.mem.eql(u8, decl.name, "RouterRule");
        const D = @field(dictionaries, decl.name);
        if (comptime !unlaid and @TypeOf(D) == type and @typeInfo(D) == .@"struct") {
            inline for (@typeInfo(D).@"struct".fields) |field| {
                if (comptime conv.needsInterface(field.type)) {
                    if (comptime conv.memberInterface(D, field.name) == null) {
                        std.debug.print("dictionary {s}.{s} names no interface\n", .{ decl.name, field.name });
                        missing += 1;
                    }
                    checked += 1;
                }
            }
        }
    }
    try std.testing.expectEqual(@as(usize, 0), missing);
    // ~950 delegate arguments and setter values and ~220 dictionary members
    // when this was written.
    try std.testing.expect(checked > 1000);
}
