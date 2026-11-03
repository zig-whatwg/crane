# WebIDL: codegen, generated files, the binding map and the impls boundary

Moved verbatim from AGENTS.md (2026-11-03). The core keeps each rule as one line and points here. The check that holds the impls boundary, `zig build lint-impls`, and its baseline are in [tools/AGENTS.md](../../tools/AGENTS.md).

## WebIDL codegen

```
specs/idl/            334 webref .idl files, committed, pinned (specs/idl/WEBREF.md)
specs/supplementary/  Crane's own definitions (7 files)
        |
        v             src/webidl/codegen/
        |
src/webidl/interfaces/    1,263  generated
src/webidl/typedefs/             generated
src/webidl/dictionaries/         generated
src/webidl/callbacks/            generated
src/webidl/impls/         1,270  HAND-WRITTEN, never overwritten
src/webidl/impls_tmp/            generated stubs, gitignored, NOT built
```

Generated files **are** committed. `impls/` is yours; codegen writes stubs to
`impls_tmp/` for you to diff and merge by hand.

### Never edit generated files directly

Fix the codegen in `src/webidl/codegen/` or the source IDL, then regenerate.

You *may* edit a generated file to test a fix, but the fix must then move into
the codegen and the temporary edit must be overwritten by a regeneration —
that is how you know the codegen actually produces it. Never commit a
hand-edited generated file.

Regenerate - **one invocation, both sources, one model**:

```bash
zig build codegen -- --dest-root src/webidl/
```

With no source named, codegen reads `specs/idl` and `specs/supplementary`
together, so a name in one resolves against the other (`typedef Window
WindowProxy` needs Window) and every `root.zig` lists both. Its output is
`zig fmt`-clean, so `git status` after a regeneration shows only real changes.
Never regenerate from one source alone: that run resolves against that source
only and rewrites every root with its entries.

The model does not depend on the order files are read in (`ir.zig`,
"Merging"): every partial definition merges into its definition, members go
definition first, then partials by (file name, position), and overloads are
numbered in that order. Two non-partial definitions of one name are an error
unless `src/webidl/codegen/duplicates.zig` names the definer (from webref's
curated idlnames); codegen stops and says so.

**`zig build codegen-check`** (part of `zig build test`) regenerates the whole
tree from scratch into a temporary directory and compares it byte for byte with
the committed generated directories. A hand-edited generated file, an IDL or
codegen change committed without its regeneration, and a stale generated file
all fail it, and it prints the command above. `specs/idl` is a pinned webref
snapshot: update it only by the procedure in specs/idl/WEBREF.md.

When codegen behaviour is in question, **delete the generated directories and
regenerate from scratch.** Partial regeneration hides systemic issues — that is
how a parent-vs-child signature bug stayed hidden behind 12 "unrelated" type
mismatches. `codegen-check` does exactly that against the committed tree; then
build (`zig build wpt-runner -j2`) to confirm no interface/impl signature drift.

### New interfaces

1. Run codegen. 2. Copy the stub from `impls_tmp/X.zig` to `impls/X.zig`.
3. Implement it. 4. Commit the file in `impls/`.

When an IDL signature changes, diff `impls_tmp/X.zig` against `impls/X.zig` and
merge by hand, preserving your implementation.

### Names are the binding map

The binding finds an impl's functions by the names its generated file gives
them. There is no separate table saying which Zig function backs which member,
and none may be added - so the prefixes mean "exposed to script" and nothing
else:

| Member | Impl function |
|--------|---------------|
| regular attribute | `get_<name>`, `set_<name>` |
| operation | `call_<name>`; a further overload `call_<name>__<k>` (optional: until it exists, overload 0 runs) |
| static attribute | `get_static_<name>`, `set_static_<name>` - accessors of the interface object |
| static operation | `call_static_<name>` |
| constant | none - the generated interface answers it (`get_<NAME>()`) |
| special operation (indexed/named getter, setter, deleter) | bound from the generated `Meta.special_operations`, never by name; an anonymous one's delegate is `call_<keyword>`, or `call_<keyword>__<k>` for the k-th of its keyword |

- **A private function never takes one of those prefixes.** Name helpers in
  camelCase.
- **A public one the generated file never calls is a map entry pointing
  nowhere**: a stale copy, a member that belongs to another type - or a
  broken map. Find out which before deleting it - see
  [An API name nothing binds is a bug report](../../docs/lessons/codegen-an-api-name-nothing-binds-is-a-bug-report-not.md).
- **Mixin members are inherited.** WebIDL `includes` makes a mixin's members
  the includer's own: on its prototype, under its brand check, with its
  instance as `this`. So the includer's generated interface takes each one
  from the mixin's generated module by alias -
  `pub const get_onclick = mixins.GlobalEventHandlers.get_onclick;` - and the
  member is implemented ONCE, in the mixin's impl. Nothing calls a mixin on its
  own, and an includer's impl never implements or overrides a member it
  includes (WebIDL forbids redeclaring one); behaviour the spec keys on the
  receiver is written in the mixin impl. Event handler IDL attributes
  (EventHandler, OnErrorEventHandler, OnBeforeUnloadEventHandler) are the
  exception: codegen emits them through `dom.event_handlers`, which also holds
  the receiver-keyed rule for body/frameset's window-reflecting handlers, so an
  impl declares an `on*` accessor only to add behaviour (impls B5). The move is
  under way: a mixin joins
  `src/webidl/codegen/inherited_mixins.zig` in the commit that moves its
  implementation out of its includers' impls, and until then its includers'
  delegates still call their own impls.

`zig build lint-impls` (part of `zig build test`) checks this: strictly for
interface, namespace and helper impls and for the impls of inherited mixins
(bound by their generated module), and as a ratchet over
`tools/impls_naming_baseline.txt` for the other mixin impls, whose unrouted
functions predate the rule.

## The impls boundary

**An interface's impl is reached ONLY through that interface's own generated
file. Nothing else references it - no other impl, not an ancestor's impl, not
src/dom, src/html, src/browser, the engine adapter, tools or tests.** (The
user's rule, 2026-09-29. It replaces the old exception that let an impl call its
ancestors' impls directly.)

```
Anything -> an IDL member of any type  ->  interfaces.X.<member>
Anything -> a step with no IDL member  ->  a src/dom hook the owning impl installs
The generated interface X.zig          ->  its own impl (the one allowed reference)
```

1. **IDL members: the interface.** `interfaces.Node.get_ownerDocument(n)`, never
   `NodeImpl.getOwnerDocument(n)` - from Range, from Text (Node's own
   descendant), from anywhere. IDL constants too: `interfaces.Node.get_DOCUMENT_NODE()`.
   Interfaces are the stable API and carry CEReactions, validation and the other
   cross-cutting concerns; a direct impl call bypasses all of it.
2. **No IDL member: a hook the owner installs** - except facts given at construction (node document, node type), which travel as construction arguments through the generated construction chain (the user, 2026-10-11; tmp/plans/impls-boundary-design.md). Setting a node's document,
   joining a live range to its document, setting up a traverser, making a
   collection live, an element's form reset steps - the owning impl installs the
   step into a hook module in `src/dom/` (`node_document.zig`,
   `range_boundaries.zig`, `traversal.zig`, `live_collections.zig`,
   `abort_algorithms.zig`, ...), each declaring its owners on a
   `//! lint-impls: hook for <Owner>` line. Callers call the hook and never name
   the impl. Add a hook module for a new step rather than an import. This holds
   for a type's own descendants too: Text sets its node document through the
   hook, not through NodeImpl.
3. **Shared helpers do not live in `src/webidl/impls/`.** A helper that serves
   several types goes in `src/dom/`, `src/html/` or its subsystem, and reaches
   types through interfaces and hooks like any other code.

Never `@import("impls")` or name an `XImpl` outside the generated layers in new
code, and never cast another type's `_internal` to its `InternalState`.

**Construction and destruction are the generated chain.** `interfaces.X.init`
runs the parent interface's chain, then `XImpl.initOwn(instance, allocator,
comptime StateType, args)`; `deinit` runs `XImpl.deinitOwn`, then the parent's.
An impl writes only its own part (or none), never an ancestor's init or deinit;
a fact given at construction is listed in `pub const construction_args` and
passed with `interfaces.X.initWith(.., .{ .name = value })`. An impl still
defining `init`/`deinit` chains by hand, and the chain honours it
([lesson](../../docs/lessons/codegen-the-generated-interface-is-the-class.md)).

**Existing references are debt, not precedent.** About 200 files outside the
generated layers still reference impls (most of them impls reaching ancestors,
which the old rule allowed). A change that touches such a line converts it.
