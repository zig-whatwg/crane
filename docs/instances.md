# Instances and tabs

Status: design (2026-10-01). Batch B0 built (2026-10-02): `zig build lint-global-state` and
`crane.Process` (src/browser/process.zig) with every src/dom hook written once at start-up.
B1 started (2026-10-04, workers lane 1B): `runtime.BrowserScope` (src/runtime/browser_scope.zig),
owned by each Browser and carried by every realm as `ContextData.browser_scope` (frames copy their
parent's, a worker realm its creator's), with its supplements - `html.WorkerRegistry`, the
Browser's live workers; the BroadcastChannel registry; `html.SharedWorkerManager`, HTML's shared
worker manager with each shared worker's owner set. B1's allocators and registries join it as
supplements. Workers 1B-ii (2026-10-05): every dedicated worker runs its agent, realm and event loop
on a thread of its own (src/html/worker_thread.zig); workers batch 2 (2026-10-05): every shared
worker does too, and every worker realm has its own event loop. B3 started (2026-10-11, lane inst3):
the storage shed and bucket file systems (`storage.UserAgentStorage`), the blob URL store and the
cookie jar with its CookieStore listeners (`dom.cookie_change_listeners`) are supplements of the
BrowserScope, reached from a realm through `dom.browser_state`; a request carries its client's
blob URL store; rejection tracking lives on each agent's host (`AgentHost.rejections`).
B1's allocator half (2026-10-11, lane inst4): the BrowserScope owns the slab and arena every platform
object of its Browser comes from (`Instance.init` allocates from the realm's scope; an object's Browser is
read from its address, `BrowserScope.ofInstance` / `runtime.arenaOf`), and every address-keyed side table
the DOM keeps (InstanceRegistry, EventTarget's, the NodeBase bridge, internal_state, StaticRange's, the
option and textarea maps) is a `BrowserScope.Table` of it; a Browser's end sweeps only its own tables
(dom.teardown_sweeps). Two whole Browsers run at once on two threads. `runtime.initializeRuntime` makes the
standalone scope for tests and runtime-only hosts.
B3's rest (2026-10-12, lane inst5): each Browser's browsing contexts are its own
(`html.window.Navigables`, a BrowserScope side table; every context carries its list, lookups go
through the realm - `dom.browser_state.navigablesOf` / `browsingContextOf` - and a Browser's end
frees only its own retired contexts). The network is split by its thread rule: per Browser,
`fetch.network.NetworkContext` (a BrowserScope supplement) holds the connection share (curl's
connection and DNS caches with locks of their own, src/platform/kit/curl/share.zig, and the
kit's options.zig applies the Browser's proxy, TLS and user agent to every handle), the TLS
options, the proxy, the user agent string and WebSocket's CONNECTING gate, and a request carries
its client's context as it carries the cookie jar; per agent, `fetch.algorithms.AgentFetches` on
`AgentHost.fetches` (the curl multi handle and the fetches in flight), pumped by that agent's own
event loop, since a multi handle is driven by one thread and every worker has its own (the design
put these on the Browser before workers had threads). curl's global init is crane.Process's.
BrowserConfig takes `user_agent`, `proxy` (explicit: system, direct, manual; a PAC file and
auto-detection are NotSupported) and `accept_insecure_certs`, read by navigator and WorkerNavigator,
fetch's `User-Agent`, the WebSocket handshake and report bodies.
B2's rest (2026-10-12, lane inst6): the V8 adapter's per-isolate state is each isolate's own, kept
where V8 keeps an embedder's per-isolate data (Blink's V8PerIsolateData): the template registry is
a second map of the isolate's template storage (data slot 1) - no process-wide table, lock or
generation counter, so one agent's end no longer rebuilds another's templates; the JSON modules
awaiting evaluation are in v8_wrapper.cpp's per-isolate record (slot 2), which also holds a
snapshot isolate's StartupData; the ObservableArray states are on the agent record beside the Intl
objects; a namespace operation (console, CSS, TestUtils) is handed the current realm, so console's
count map, timer table and group stack are each realm's; the isolate teardown steps are a constant
table; the ShadowRealm dispatcher is set once by initializeEngine; each isolate's ArrayBuffer
allocator is V8's to free (CreateParams::array_buffer_allocator_shared). The weak-callback and
realm-tag maps stay process-wide under their mutexes (`// process-wide:`): a release names only its
handle. Dead legacy paths with globals of their own (the CallbackManager, the pre-protocol module,
import.meta, dynamic import and promise-rejection callbacks, the C++ async iterator template)
are deleted.
The full design, with the inventory of every
process-global and threadlocal variable in src/, was written by the instances lane; this note is
the part every lane needs to know before it adds state.

## The model

| Owner | What it is | What it owns |
|---|---|---|
| **Process** (`crane.Process`) | everything that is the same for every instance and never changes after start-up | the V8 platform and snapshot, curl's global init, immutable tables, every src/dom hook (installed once by `Process.init`, before any instance) |
| **Browser** | one Crane instance: one thread for its window agent (isolate) and event loop, plus one thread per worker - a WebDriver BiDi "user context" | the web's shared state a browser profile holds: the storage shed (localStorage, IndexedDB, Cache API, buckets), the cookie jar, the HTTP cache and network, the blob URL store, BroadcastChannel delivery, SharedWorker instances, Web Locks, service worker registrations and clients, permissions, the browsing context groups and the tabs; and its runtime allocators and engine registries |
| **Tab** | one top-level traversable | session history, sessionStorage (its traversable storage shed, cloned into a popup that has an opener), the frame clock, visibility and system focus, its frames |
| **Agent** (event loop) | the window agent, or a worker's - each worker agent on its own thread | the custom element reactions stack, mutation observer state, the timer nesting level, the execution context stack |
| **Realm** | a Window, a WorkerGlobalScope, a ShadowRealm | its map of active timers, animation frame callbacks, module map, fetch group |

A tab the host creates starts a new browsing context group; a popup joins its opener's group,
unless it was opened with noopener. Two Browsers in one process share nothing mutable. In memory by
default; an optional profile directory persists the Browser's stores, one live Browser per
directory.

## Rules for new state

1. **Do not add a `threadlocal` or a container-level `var`.** A threadlocal is per thread, which is
   neither per instance nor per tab: a value installed on one thread is null on the next, and a
   page's state on it is shared with every other page the thread runs (see
   lessons/architecture-a-threadlocal-is-per-thread-not-per-instance-or-tab.md). A process global
   is shared by every instance.
2. **Reach state through the realm you run in**: a platform object's relevant realm is `instance.ctx`;
   a realm will carry its Browser's scope and its Tab's scope. Per-Browser and per-Tab state of a
   subsystem is a supplement of that scope (Blink's `Supplementable`), made on first use and
   destroyed with the scope.
3. **A hook is process-wide and written once**, at process start - never installed lazily by the
   first owner, never per instance.
4. `zig build lint-global-state` (part of `zig build test`; tools/lint_global_state.zig) counts
   every process-global and threadlocal mutable variable in src/ - Zig through std.zig.Ast, C++
   by a scan of the code - per file and qualified name, against
   tools/global_state_baseline.txt, and only lets the count go down. A key the baseline lacks
   fails. `-- --update` records a paid-down tree; it records a NEW key only when its declaration
   has a `// process-wide: <why>` line directly above it (a variable that genuinely belongs to
   the process; the integrator reviews it). `-- --rename '<old key>' '<new key>'` records a
   rename in place: same file, kind, declaration (type and initialiser) and count.

## Hooks: how they are installed

A hook is a function table in a src/dom module (or src/html/script_element.zig) that the owning
impl fills so code that may not name the impl can reach a step. Since B0:

- The owning impl declares `pub fn installHooks() void` and makes every install there - never in
  `init`, never on first use, never by making a throwaway object of the owner's type.
- The generated interface (or mixin module) exposes it, and the generated root's
  `process_hooks.install()` calls each one. `crane.Process.init` calls that once, before any
  Browser exists; the browser layer's own hooks (Context.installHooks) follow.
- The hook module's variable is a plain process `var`, and its install calls
  `dom.process_start.assertInstalling()`: an install after start-up panics outside tests.
- A host starts the process itself (`var process = try crane.Process.init(.{}); defer
  process.deinit();`, as the WPT runner does); `Browser.init` still calls
  `Process.ensureStarted` for hosts that do not (removed in B6).

## Decisions (the user, 2026-10-01)

- **Every worker has its own thread**, as in commercial browsers ("we want to have each worker have its own
  thread similar to commercial browsers"): each dedicated, shared and service worker runs its agent - isolate,
  event loop, timers - on a thread of its own, owned by the Browser. A busy loop or `Atomics.wait` in a worker
  never stalls a tab. Messages cross threads through the Browser's thread-safe task queues (postMessage,
  MessagePort, BroadcastChannel); a worker is terminated by aborting its running script and ending its thread.
  This replaces the design's interim "workers stay on the Browser's thread for 0.1".
- **Hooks are process-wide**, written once at process start (B0), later bound at comptime (B9).
- **C ABI**: `crane_browser_*` and `crane_tab_*` in a new `include/crane.h`; the unimplemented `whatwg_context_*`
  and header-less `whatwg_browser_*` go.
- **Every popup is a tab**, `noopener` included, as WebDriver BiDi reports them.
- **Background tabs are visible by default** (headless Chrome's behaviour); the host can mark a tab hidden.
- **Proxies**: explicit configurations only; PAC files and auto-detection are NotSupported in 0.1.
- **The WPT runner gives each test file a fresh tab** from B5, once a sweep shows no file's status changes.
- **One live Browser per profile directory**: a second is refused (ProfileInUse), as Chrome's profile lock does.
