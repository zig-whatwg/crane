//! Does the derived-to-base state pun actually hold?
//!
//! `runtime.Instance.getState(T)` is a bare `@ptrCast` of `instance.state` to `*T`.
//! For an instance of a DERIVED interface that only reads the right bytes if the base
//! state sits at byte offset 0 of the derived state - at every level of the chain.
//!
//! Nothing guarantees that. `runtime.FlattenedState` returns a plain
//! `struct { base, mixins, own }` with Zig's default (auto) layout, and auto layout may
//! reorder fields. It generally orders by descending alignment, so a LOW-alignment base
//! combined with HIGH-alignment own fields pushes `base` off zero.
//!
//! That is not hypothetical - reduced to three synthetic types it reproduces exactly:
//!
//!     base        = struct { flag: u8, kind2: u8 }      // align 1
//!     derived.own = struct { big: u64, ptr: ?*anyopaque } // align 8
//!     => @offsetOf(Derived, "base") == 16, NOT 0
//!     => the pun reads 0xAD (a byte of the derived's 0xDEAD) where 0xAB should be
//!
//! Crane survives today only because the base states in its real chains happen to lead
//! with pointer-aligned fields. That is a coincidence of field types, not a guarantee,
//! and adding a single u8 to the front of an ancestor's `own` can silently break it.
//! The symptom would be cross-type reads, not a crash.
//!
//! This is a REGRESSION GUARD. If it fails, do NOT relax it - it means `getState` must
//! become the offset-corrected, brand-checked `stateAs` before anything is trusted.
//! The replacement mechanism (a comptime ancestor-offset table on the VTable) is
//! proven; see the Phase 4 notes in tmp/analysis/WORKLOG-zig016.md.
//!
//! Scope note: this checks the deep, hot inheritance chains rather than reflecting over
//! all 1,263 generated interfaces. Forcing analysis of every one of them also forces
//! analysis of five dead SVG filter-effects interfaces whose impl symbols
//! (`impls.SVGFEFuncAElement` and four siblings) are not exported by impls/root.zig -
//! a real pre-existing codegen-integrity defect, but a different bug from this one.

const std = @import("std");
const interfaces = @import("interfaces");

/// Byte offset of `base` within `T`, or null if `T` has no base.
fn baseOffset(comptime T: type) ?usize {
    if (!@hasField(T, "base")) return null;
    if (@FieldType(T, "base") == void) return null;
    return @offsetOf(T, "base");
}

/// The chains the pun is actually exercised on. Every one of these is reached through
/// `getState` from an impl that belongs to an ancestor - e.g. EventTarget's listener
/// code runs against an Element instance.
const checked_interfaces = [_][]const u8{
    // DOM core: the deepest and hottest chain in the engine.
    "EventTarget", "Node",           "Element",      "CharacterData",
    "Text",        "Comment",        "Document",     "DocumentFragment",
    "ShadowRoot",  "DocumentType",   "Attr",         "Range",
    // HTML: Element -> HTMLElement -> HTMLxxxElement, the longest chains generated.
    "HTMLElement", "HTMLDivElement", "HTMLScriptElement", "HTMLIFrameElement",
    "HTMLInputElement", "HTMLAnchorElement", "HTMLFormElement", "HTMLImageElement",
    // Events: another multi-level chain with real subclassing.
    "Event",       "MouseEvent",     "PointerEvent", "MessageEvent",
    "CloseEvent",  "ProgressEvent",  "ErrorEvent",   "CustomEvent",
    // Misc types with bases that carry state.
    "AbortSignal", "Window",         "Performance",  "XMLHttpRequest",
};

test "base state sits at offset 0 in every hot inheritance chain" {
    @setEvalBranchQuota(200_000);

    var with_base: usize = 0;
    var offenders: usize = 0;

    inline for (checked_interfaces) |name| {
        if (@hasDecl(interfaces, name)) {
            const Iface = @field(interfaces, name);
            if (@hasDecl(Iface, "State")) {
                const S = Iface.State;
                if (comptime baseOffset(S)) |off| {
                    with_base += 1;
                    if (off != 0) {
                        offenders += 1;
                        std.debug.print(
                            "  OFFENDER {s}: @offsetOf(State,\"base\") = {d}, expected 0 - " ++
                                "getState() now reads the wrong bytes for every ancestor of this type\n",
                            .{ name, off },
                        );
                    }
                }
            }
        }
    }

    // Guard against the check silently going vacuous: if the names drift or the
    // generated shape changes, this must fail loudly rather than pass having
    // verified nothing.
    try std.testing.expect(with_base >= 20);
    try std.testing.expectEqual(@as(usize, 0), offenders);
}

test "the offset-0 assumption is a coincidence, not a guarantee" {
    // Demonstrates, with types shaped exactly like FlattenedState, that a low-alignment
    // base under a high-alignment derived DOES move `base` off zero. This is what the
    // test above is guarding against; it exists so the guard's rationale cannot be
    // dismissed as theoretical.
    const Flattened = struct {
        fn T(comptime Base: ?type, comptime Own: type) type {
            return struct {
                base: if (Base) |B| B else void,
                mixins: struct {},
                own: Own,
            };
        }
    };

    const BaseState = Flattened.T(null, struct { flag: u8 = 0 });
    const DerivedState = Flattened.T(BaseState, struct { big: u64 = 0 });

    // If this ever becomes 0, Zig's layout rules changed and the guard above is
    // weaker than it looks - worth knowing.
    try std.testing.expect(@offsetOf(DerivedState, "base") != 0);
}
