# Codegen: The generated interface is the class - its construction chain and construction arguments are emitted

**Date**: 2026-10-12
**Lesson**: A type's construction and destruction are its generated interface's chain: `initChain` runs the parent interface's chain, then the impl's `initOwn`; `deinitChain` runs the impl's `deinitOwn`, then the parent's. An impl never names an ancestor's impl to chain, and facts given at construction (the node type, a CookieStore's secure context) are arguments of that chain, not post-construction setters or factories.

**Why**: C++ engines get this from the language - `HTMLDivElement(...) : HTMLElement(tagName, document)` - and a derived class never names its base's private parts. Crane's impls chained by hand: 138 inits began with `ParentImpl.init`, 158 deinits ended with `ParentImpl.deinit` (each a reference into another type's impl, which the impls boundary forbids), and 492 impls of types with a parent never chained at all, leaving their ancestors' state unmade and unfreed. A hand-written chain can be forgotten; a generated one cannot.

**What Happened**: Lane implsb2 (impls boundary B2, tmp/plans/impls-boundary-design.md 3.2.3). The generated lifecycle (src/webidl/codegen/writer.zig `writeLifecycleFunctions`) now emits:

- `init(allocator, ctx)`, `initWith(allocator, ctx, args)` and `initWithState(...)` (for impls still chaining by hand) - all run `initChain`;
- `initChain`, `inline`: a legacy `XImpl.init` if the impl still has one, else the parent's chain (the root: `runtime.Instance.init`), then `XImpl.initOwn(instance, allocator, StateType, args)`, whose failure unwinds the parent's part and frees the slot;
- `deinit` (the vtable's destructor) and `deinitChain`, `inline`: a legacy `XImpl.deinit`, else `XImpl.deinitOwn` then the parent's chain;
- `takesConstructionArg(name)`: whether an impl on the chain lists `name` in its `construction_args`; `initWith` makes any other field a compile error.

A mixin gets none of it (and no vtable): it is never instantiated. Converting showed what the hand chains had hidden: CDATASection's init chained to CharacterData's past Text's, so a CDATASection had no Text part; a Text made by `interfaces.Text.init` was an ELEMENT_NODE until its constructor set the type, because 13 creation paths set the node type after construction. Node's own steps now read the type off the most-derived State at comptime (WebKit's `Node(Document&, NodeType, ...)`), and the setters, EventTarget's duplicate copy and the `node_creation.set_type` hook went. 219 references left the baseline (1,063 -> 844).

**Fix**: For an impl with state of its own:

```zig
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;
    const internal = try Registry.createIn(instance, runtime.arenaOf(instance));
    internal.* = InternalState.init(allocator);
}
pub fn deinitOwn(instance: *runtime.Instance) void {
    if (Registry.get(instance)) |internal| internal.deinit();
    Registry.remove(instance);
}
```

and none of either for an impl with none. Its own state is `instance.getState(State)`, never `getState(StateType)` (the most-derived type's `own` is a descendant's). A fact given at construction: `pub const construction_args = .{"is_secure_context"};` and `@hasField(@TypeOf(args), "is_secure_context")` in `initOwn`; callers use `interfaces.CookieStore.initWith(.., .{ .is_secure_context = s })`. An impl whose teardown must stop early (HTMLIFrameElement refuses a finished one, Node's guards until refcount step 7) keeps a `deinit` of its own and reaches its parent's part through `interfaces.P.deinitChain`.

**Takeaway**: **The generated interface is the class: an impl writes only its own construction and destruction steps, and what it is given at construction arrives as an argument of the generated chain.**
