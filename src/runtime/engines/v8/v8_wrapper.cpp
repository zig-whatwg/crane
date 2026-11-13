// Unified V8 C API Wrapper for Zig
//
// This provides a single, consistent C-compatible API for V8.
// All functions use MixedCase naming (v8_TypeName_MethodName).
// All handles use Global<T>* for cross-scope persistence.
//
// Used by:
// - REPL (persistent handles for context, isolate, etc.)
// - Namespace bindings (callbacks convert Local→Global→Local)

#include <atomic>
#include <array>
#include <cassert>
#include <chrono>
#include <mutex>
#include <new>
#include <v8.h>
#include <v8-snapshot.h>
#include <libplatform/libplatform.h>
#include <v8-profiler.h>
#include <v8-inspector.h>  // engine.evaluateReplScript (lane console1)
// Each agent's C++ heap (cppgc), the wrapper redesign's P3
// (tmp/redesign/wrapper-redesign-design.md 4.12): build.zig compiles this file
// with the archive's cppgc defines, so these headers agree with the library.
#include <v8-cppgc.h>
#include <v8-metrics.h>  // GCPhaseRecorder (lane wr1 batch 8)
#include <cppgc/explicit-management.h>  // freeDroppedAnchors (lane wr1 batch 8)
#include <v8-external-memory-accounter.h>  // external_memory.zig: one accounter per agent
#include <cppgc/allocation.h>
#include <cppgc/garbage-collected.h>
#include <cppgc/heap.h>
#include <cppgc/heap-state.h>
#include <cppgc/internal/base-page-handle.h>
#include <cppgc/member.h>
#include <cppgc/persistent.h>
#include <cppgc/platform.h>
#include <cppgc/testing.h>
#include <cppgc/visitor.h>
#include <thread>
#include <cstdio>
#include <cstring>
#include <deque>
#include <string>
#include <vector>
#include <set>
#include <span>
#include <unordered_map>
#include <unordered_set>
#include <algorithm>
#include <type_traits>
#include <execinfo.h>  // For backtrace on macOS/Linux

using namespace v8;

#if defined(CRANE_V8_WRAPPER_APART_FOR_TSAN) && defined(__linux__)
// -Dsanitize-thread on Linux (build.zig addV8Source, V8Link.wrapper_apart): the test executable links Zig's
// static ThreadSanitizer runtime, whose interceptors DEFINE __cxa_guard_acquire/release/abort
// (tsan_interceptors_posix.cpp: it models a function-local static's one-time initialization as a lock), and
// Chromium's libc++_chromium.a, whose libc++abi member cxa_guard.o defines them too. The archive comes first on
// the link line, so V8's and this file's references loaded cxa_guard.o, and the runtime's interceptor object
// then made them duplicate symbols (ld.lld, lane v8up b3e). These WEAK definitions are what those references
// resolve to while the archives are read - a defined symbol loads no archive member, so cxa_guard.o is never
// loaded - and the runtime's strong definitions replace them in the final link, which is what Zig's own libc++
// build gets under TSAN: the runtime's guards. They are never called (a TSAN build always links the runtime);
// if one ever is, it traps. macOS links the runtime as a dylib, which defines nothing in the executable.
extern "C" {
__attribute__((weak)) int __cxa_guard_acquire(uint64_t*) { __builtin_trap(); }
__attribute__((weak)) void __cxa_guard_release(uint64_t*) { __builtin_trap(); }
__attribute__((weak)) void __cxa_guard_abort(uint64_t*) { __builtin_trap(); }
}
#endif

// A native step that is not a script call - engine bookkeeping, a realm's
// properties being defined, a promise resolved from a task, a value
// serialized - entered from native code with no script on the stack. Under
// kAuto, leaving any API scope entered with do_callback=true (ENTER_V8 in
// 13.1 api.cc: Object::Set, Has, HasOwnProperty and so HasPrivate, Delete,
// DefineProperty with a descriptor, SetIntegrityLevel, Set::Has/Delete,
// Promise::Resolver::Resolve/Reject, Function::Call/NewInstance,
// Module::InstantiateModule/Evaluate, ValueSerializer::WriteValue) at call
// depth 0 performs a microtask checkpoint (api-inl.h
// CallDepthScope::~CallDepthScope -> isolate.cc
// FireCallCompletedCallbackInternal): queued microtasks ran from inside
// whatever DOM algorithm, realm creation or task step made the call. HTML
// performs a checkpoint only in "clean up after running script" (and so a
// callback's) and at the event loop's own points.
//
// This scope holds the call depth above 0 for its lifetime and fires nothing
// when it ends (13.1 api.cc:10100-10113,
// Isolate::SuppressMicrotaskExecutionScope), so the step's API calls return
// to depth >= 1 and what they queue waits for the next real checkpoint.
// Invoking a callback (v8_Function_Call*, v8_Function_CallCatching*,
// v8_Function_ConstructCatchingWithSite) does not use it: kAuto's checkpoint
// there is "clean up after running a callback". It must live on the C++
// stack - it records its own address as the isolate's last API entry
// (docs/lessons/architecture-suppressmicrotaskexecutionscope-must-live-on-the.md).
using NativeStepScope = Isolate::SuppressMicrotaskExecutionScope;

// V8 >= 14 checks the type of every pointer an External, an internal field or
// a context's embedder data holds against the tag it was stored with
// (External::New/Value f8fa8e7d227, internal fields and embedder data
// 4de1c836b12; ExternalPointerTypeTag, EmbedderDataTypeTag). The adapter
// stores pointers of many types through FFI functions whose callers alone know
// the type, so it uses the default tags V8 names for an embedder that does not
// type them ("If type tags are not used in the embedder, the default value
// kExternalPointerTypeTagDefault can be used", v8-external.h; the same for
// kEmbedderDataTypeTagDefault, v8-object.h).
static constexpr ExternalPointerTypeTag kCraneExternalTag = kExternalPointerTypeTagDefault;
static constexpr EmbedderDataTypeTag kCraneEmbedderDataTag = kEmbedderDataTypeTagDefault;

/// V8's platform and its start, once per process (v8_Platform_Start). V8
/// itself allows one start: V8::InitializePlatform and V8::Initialize advance
/// a process-wide state and FATAL on a second or concurrent start (13.1.203
/// src/init/v8.cc AdvanceStartupState), and its flags freeze when it starts
/// (V8::Initialize, FlagList::FreezeFlags). So the start and the flags it
/// applies are taken under one lock, by whichever thread asks first.
struct PlatformStart {
    /// Made by the start, under `mutex`, before `started` is published, and
    /// NEVER deleted - not by v8_Platform_Dispose, not at process exit. V8's
    /// worker threads run until the process ends, and a task on one may post
    /// to the platform at any time: on V8 15.7 MemoryPool's
    /// ReleasePooledChunksTask posts its next release from a worker
    /// (PostDelayedTaskOnWorkerThread). As a std::unique_ptr in this static
    /// object, the platform was destroyed by exit()'s static destructors
    /// while those threads ran: CranePlatform's backend_ went null first and
    /// a worker's post became a call on null - the tests-v8 processes that
    /// aborted AFTER their test passed ("member call on null pointer of type
    /// 'v8::Platform'", v8_wrapper.cpp PostDelayedTaskOnWorkerThreadImpl; lane
    /// v8up b3d: 21 of 1,813 in one loaded Linux run). Chrome never destroys
    /// its platform either (gin's V8Platform is a base::LazyInstance::Leaky;
    /// Chromium builds with -Wexit-time-destructors). Held here, it stays
    /// reachable to leak checkers.
    Platform* platform = nullptr;
    /// Whether V8 has started. Stored true (release) once, by the start,
    /// after V8::Initialize and after `platform` and `flags` are written;
    /// stored false only by v8_Platform_Dispose. Read without the lock
    /// (acquire): true means those are written and stay so.
    std::atomic<bool> started = false;
    /// Orders the start, v8_SetFlagsFromString and v8_Platform_Dispose.
    std::mutex mutex;
    /// The flags the start applied ("" for none), written once by it.
    std::string flags;
    /// v8_Platform_Dispose ran: V8 cannot start again in this process.
    bool disposed = false;
    /// How many times v8_SetFlagsFromString set flags outside the start
    /// (diagnostics: v8_Platform_FlagWrites). V8 has no public API to read
    /// its flags back; they freeze when it starts, so a write before the
    /// start is the only way a test can change the flags every later test of
    /// its process runs with.
    int64_t flag_writes = 0;
};
// process-wide: V8's platform - V8::InitializePlatform once per process, never again after V8::Dispose; its start, flags and end are ordered by its own mutex, and `started` is read with acquire.
static PlatformStart g_platform;

/// Enter `isolate` for a collection started outside script, if it is not
/// the current one already (the node wrapper walk finds its agent
/// through the current isolate: collectingRecord); leave it after.
class CollectingScope {
 public:
    explicit CollectingScope(Isolate* isolate) : isolate_(Isolate::TryGetCurrent() != isolate ? isolate : nullptr) {
        if (isolate_) isolate_->Enter();
    }
    ~CollectingScope() {
        if (isolate_) isolate_->Exit();
    }
    CollectingScope(const CollectingScope&) = delete;
    CollectingScope& operator=(const CollectingScope&) = delete;

 private:
    Isolate* isolate_;
};

// ============================================================================
// Snapshot Mode Global Handle Tracking
// ============================================================================
//
// V8's SnapshotCreator::CreateBlob() requires that there be no outstanding
// Global handles when called. Since our wrapper returns Global<T>* from most
// functions, we need a way to track and dispose them before snapshot creation.
//
// When snapshot mode is enabled:
// 1. All Global handles created are tracked in a vector
// 2. Before calling CreateBlob(), call v8_Snapshot_ClearGlobalHandles() to reset them all
// 3. This allows V8 to serialize the heap without complaining about Global handles

// process-wide: true only in the snapshot generator (a process of its own, one isolate, one thread), set and cleared by its v8_Snapshot_* calls before and after it builds the blob; every other process reads false.
static bool g_snapshot_mode = false;

// We store void* pointers along with type-specific reset functions
struct GlobalHandleEntry {
    void* handle;
    void (*reset_fn)(void*);
};
// process-wide: the snapshot generator's outstanding Globals (g_snapshot_mode), written only while it is on - in its process of its own, on its one thread.
static std::vector<GlobalHandleEntry> g_snapshot_handles;

// Defined with the weak-callback machinery below. Deleting a Global that still
// carries a weak arm leaves the arm's record pointing at freed memory, and this
// is a delete site like any other.
static void releaseWeakArmRaw(void* handle);

// Defined with the live string and object counts below: every delete site a
// Global<String> or Global<Object> can reach calls it, so the counts are of
// handles, not of entry points.
template <typename T>
static void forgetCountedHandle(Global<T>* handle);

// A Global's node carries a 16-bit wrapper class id that V8 reads and writes
// inline (PersistentBase::WrapperClassId / SetWrapperClassId: one load or store
// at Internals::kNodeClassIdOffset) and clears when it frees the node
// (NodeBase::ClearFields, src/handles/global-handles.cc), so a node V8 hands out
// again starts at 0 (tests/v8/perf3_dispose_marks_test.zig). Nothing else in
// Crane assigns wrapper class ids. The low byte is the ledger's KIND (a counted
// object or string handle, below); the top two bits say whether either of the
// process-wide maps a release consults holds an entry for the handle:
//
// - kArmedFlag: `armedWeakData` (a weak arm, or the record a `handle_survives`
//   detach leaves): set by armWeakData in the critical section that inserts the
//   entry, cleared where an erase leaves the handle alive;
// - kRealmTaggedFlag: `realmTaggedHandles`: set by v8_Global_TagRealm with the
//   insert, cleared by every erase.
//
// A release of a non-empty handle without the flag skips that map - its lock and
// its lookup - which was 13-37% of every perf row when every release paid both
// to find nothing (lane perf3, tmp/plans/perf3-design.md 1.3). The one direction
// that matters: an entry ALWAYS has its flag. A flag without an entry costs the
// old path, never a wrong answer; Debug builds check both directions at every
// release (checkHandleFlag).
static constexpr uint16_t kHandleKindMask = 0x00FF;
static constexpr uint16_t kArmedFlag = 0x8000;
static constexpr uint16_t kRealmTaggedFlag = 0x4000;


/// Whether `handle` (any Global<T>*: one slot pointer, as releaseWeakArmRaw
/// casts it) has `flag`. An empty handle has none.
static inline bool handleHasFlag(const void* handle, uint16_t flag) {
    return (static_cast<const Global<Value>*>(handle)->WrapperClassId() & flag) != 0;
}

static inline void setHandleFlag(const void* handle, uint16_t flag) {
    Global<Value>* global = const_cast<Global<Value>*>(static_cast<const Global<Value>*>(handle));
    global->SetWrapperClassId(global->WrapperClassId() | flag);
}

static inline void clearHandleFlag(const void* handle, uint16_t flag) {
    Global<Value>* global = const_cast<Global<Value>*>(static_cast<const Global<Value>*>(handle));
    global->SetWrapperClassId(static_cast<uint16_t>(global->WrapperClassId() & ~flag));
}

static inline bool handleIsEmpty(const void* handle) {
    return static_cast<const Global<Value>*>(handle)->IsEmpty();
}

/// Debug builds (no __OPTIMIZE__: Zig compiles Debug's C++ at -O0): `handle`'s
/// flag agrees with whether `map`'s entry exists, at a release that is about to
/// trust the flag. A disagreement is an entry without its flag - a lookup that
/// would be skipped, a silent leak or a record pointing at a freed box - or a
/// flag without its entry; either is a bug in this file, so it stops here.
#if !defined(__OPTIMIZE__)
#define CRANE_CHECK_HANDLE_FLAGS 1
#else
#define CRANE_CHECK_HANDLE_FLAGS 0
#endif
template <typename Map>
static void checkHandleFlag(const void* handle, uint16_t flag, std::mutex& lock, Map& map, const char* what) {
#if CRANE_CHECK_HANDLE_FLAGS
    if (handleIsEmpty(handle)) return;
    bool present;
    {
        std::lock_guard<std::mutex> guard(lock);
        present = map.find(handle) != map.end();
    }
    if (present != handleHasFlag(handle, flag)) {
        fprintf(stderr, "v8_wrapper: %s flag %s for handle %p, whose entry is %s\n", what,
                handleHasFlag(handle, flag) ? "set" : "clear", handle, present ? "present" : "absent");
        abort();
    }
#else
    (void)handle; (void)flag; (void)lock; (void)map; (void)what;
#endif
}

// ---- lane: realms (realm-tagged handles) ----
// Handles the engine protocol made for a realm's callbacks (an event
// listener, an event handler), tagged with the realm whose API stored them,
// so that the realm's detach can make them weak (v8_Object_WeakenTaggedHandles)
// rather than leave a strong root into it. A dispose drops the tag.
//
// Every thread's isolates tag here (docs/instances.md: a Browser's thread and
// each worker's), so the map is reached only under realmTagLock(); a dispose
// on a thread with nothing tagged skips the lock (`realmTagCount`).
static std::unordered_map<const void*, uintptr_t>& realmTaggedHandles() {
    // process-wide: handles tagged with the realm whose API stored them, by handle - every dispose untags (untagRealmHandle), and a dispose names only its Global; under realmTagLock(), held for one insert, erase or scan, never across a call into V8.
    static std::unordered_map<const void*, uintptr_t> map;
    return map;
}
static std::mutex& realmTagLock() {
    // process-wide: guards realmTaggedHandles(), which every isolate of the process shares; held for one insert, erase or scan, never across a call into V8.
    static std::mutex lock;
    return lock;
}
/// How many handles are tagged, read without the lock so the dispose of an
/// untagged handle - nearly every dispose - costs no lock.
static std::atomic<size_t>& realmTagCount() {
    // process-wide: the size of realmTaggedHandles(), kept beside it so a dispose can skip realmTagLock() when nothing is tagged.
    static std::atomic<size_t> count{0};
    return count;
}
static void untagRealmHandle(const void* handle) {
    // A live handle says whether it is tagged (kRealmTaggedFlag): one without
    // the flag has no entry, so no lock and no lookup. realmTagCount alone
    // skipped them only on a thread with nothing tagged anywhere in the process,
    // and one event listener is enough to tag (lane perf3: untagRealmHandle was
    // 2-7% of the perf rows). An empty handle keeps the lookup.
    if (!handleIsEmpty(handle) && !handleHasFlag(handle, kRealmTaggedFlag)) {
        checkHandleFlag(handle, kRealmTaggedFlag, realmTagLock(), realmTaggedHandles(), "realm-tag");
        return;
    }
    if (realmTagCount().load(std::memory_order_acquire) == 0) return;
    std::lock_guard<std::mutex> guard(realmTagLock());
    auto& tagged = realmTaggedHandles();
    if (tagged.erase(handle) > 0) realmTagCount().fetch_sub(1, std::memory_order_release);
    if (!handleIsEmpty(handle)) clearHandleFlag(handle, kRealmTaggedFlag);
}
// ---- end lane: realms ----

// Type-erased reset function template
template<typename T>
static void resetGlobalHandle(void* ptr) {
    releaseWeakArmRaw(ptr);
    Global<T>* handle = static_cast<Global<T>*>(ptr);
    forgetCountedHandle(handle);
    handle->Reset();
    delete handle;
}

// Track a handle for snapshot cleanup
//
// Every `Global<T>` this wrapper hands to Zig, CUMULATIVE creations.
//
// Not a live count: there are 54 separate `delete` sites and no choke point, and
// adding a decrement to each for a diagnostic risks a real bug for a nicer number.
// The creation RATE is what identifies the leak anyway - on a create-and-discard
// loop, a site creating N handles per element is creating N too many. Pair it with
// `mstats()` for what is actually still held.
//
// 139 of the 158 `new Global<...>` sites funnel through here, so one counter
// covers nearly all of them. Each is a C++ heap allocation AND a slot in V8's
// global handle table - and the table is not part of `used_heap_size`, which is
// why a leak here reads as flat V8 heap and climbing RSS.
// process-wide: a diagnostic count over every isolate of the process (std::atomic, relaxed), read by gc_bench, the WPT runner's per-file deltas and tests that hold the process to themselves (lesson testing-a-test-that-measures-a-process-wide-counter-assumes-it-is-alone); it carries no state any instance reads.
std::atomic<int64_t> g_live_globals{0};

// extern "C" explicitly: this sits above the file's main extern "C" block, so
// without it the symbol is C++-mangled and Zig cannot find it.
extern "C" int64_t v8_Debug_CreatedGlobals() {
    return g_live_globals.load(std::memory_order_relaxed);
}

// OFF unless -DCRANE_TRACK_GLOBALS=1. This runs on EVERY handle creation, and an
// atomic increment on that path is a real cost to pay in a browser for a
// number only the memory benchmark reads.
#ifndef CRANE_TRACK_GLOBALS
#define CRANE_TRACK_GLOBALS 0
#endif

// Live Global<String> handles (`live_string_globals`): gc_bench's build only,
// 0 in every other, as `globals_created` is.
//
// Counted by HANDLE. The counter used to add one in v8_String_NewFromUtf8 and
// take one away in v8_String_Dispose, but a binding releases the string it
// returns as a Value (v8_Global_Dispose), so it rose by one per string an
// operation or getter returned while V8's own count stayed flat: 200,000
// `el.getAttribute('title')` calls read +200,000 live_string_globals and +0
// global_handle_bytes (lane callleak, 2026-10-11). trackHandle now marks every
// Global<String> it makes with a wrapper class id - a field of the handle's own
// node in V8's global handle table, read and written inline, no lookup and no
// lock - and every dispose a string can reach (v8_String_Dispose,
// v8_Value_Dispose, v8_Global_Dispose, v8_FreeToStringResult, the snapshot's
// bulk reset) reads it back before Reset. So the type a handle is released as
// does not matter, and an unmarked handle costs one load. A registry of
// pointers did the same exactly and cost gc_bench 10-20% on string-heavy
// bodies (a lock and a hash probe on every dispose).
// process-wide: a diagnostic count over every isolate of the process (std::atomic, relaxed), read by gc_bench, the WPT runner's per-file deltas and tests that hold the process to themselves (lesson testing-a-test-that-measures-a-process-wide-counter-assumes-it-is-alone); it carries no state any instance reads.
static std::atomic<int64_t> g_live_string_globals{0};

// The ledger's kinds live in the low byte of a node's class id (kHandleKindMask, above
// the realm-tag map: the layout and the map flags are explained there).
static constexpr uint16_t kCountedStringClassId = 0x0053;  // 'S'

static void rememberStringHandle(Global<String>* handle) {
#if CRANE_TRACK_GLOBALS
    handle->SetWrapperClassId(kCountedStringClassId);
    g_live_string_globals.fetch_add(1, std::memory_order_relaxed);
#else
    (void)handle;
#endif
}

// Live Global<Object> handles (`live_object_globals`), in every build, and
// counted by HANDLE as the strings are. It used to be counted at six entry
// points (`This`, `Context::Global`, the prototype getters, NewInstance) and
// uncounted in v8_Object_Dispose, so it drifted both ways: NEGATIVE by one
// for every handle an uncounted entry point made (v8_Object_New and its
// siblings, Holder, NewInstance of a function, Proxy::New - fourteen of the
// twenty) that v8_Object_Dispose released (lane worklets), POSITIVE by one
// for every counted handle the binding released as a Value
// (v8_Global_Dispose) and for every v8_GetGlobalPrototype that counted
// before it returned null. So trackHandle marks every Global<Object> it makes
// - all twenty `new Global<Object>` go through it - and every dispose a
// handle can reach reads the mark back, whatever type it is released as.
// A weak handle V8 collects is no longer live: the weak callback reads the
// mark before it resets the node.
// process-wide: a diagnostic count over every isolate of the process (std::atomic, relaxed), read by gc_bench, the WPT runner's per-file deltas and tests that hold the process to themselves (lesson testing-a-test-that-measures-a-process-wide-counter-assumes-it-is-alone); it carries no state any instance reads.
static std::atomic<int64_t> g_live_object_globals{0};

static constexpr uint16_t kCountedObjectClassId = 0x004F;  // 'O'

static void rememberObjectHandle(Global<Object>* handle) {
    handle->SetWrapperClassId(kCountedObjectClassId);
    g_live_object_globals.fetch_add(1, std::memory_order_relaxed);
}

/// Take a counted handle out of its count, before its node is reset. An
/// empty handle answers class id 0: it was counted out when it was reset.
template <typename T>
static void forgetCountedHandle(Global<T>* handle) {
    const uint16_t class_id = handle->WrapperClassId() & kHandleKindMask;
    if (class_id == kCountedObjectClassId) {
        g_live_object_globals.fetch_sub(1, std::memory_order_relaxed);
        return;
    }
#if CRANE_TRACK_GLOBALS
    if (class_id == kCountedStringClassId) {
        g_live_string_globals.fetch_sub(1, std::memory_order_relaxed);
    }
#endif
}

template <typename T>
static Global<T>* trackHandle(Global<T>* handle) {
    if (handle) {
        // Every node starts with no kind and no flag, whatever V8 left on it
        // (it clears a freed node's class id; this does not rely on that).
        if constexpr (std::is_same_v<T, Object>) rememberObjectHandle(handle);
        else handle->SetWrapperClassId(0);
#if CRANE_TRACK_GLOBALS
        g_live_globals.fetch_add(1, std::memory_order_relaxed);
        if constexpr (std::is_same_v<T, String>) rememberStringHandle(handle);
#endif
    }
    if (g_snapshot_mode && handle) {
        g_snapshot_handles.push_back({handle, resetGlobalHandle<T>});
    }
    return handle;
}

// `v8_GetGlobalPrototype` returning null is an EXPECTED outcome, not an error:
// the caller (template_registry.zig) falls back to the template's own prototype
// for interfaces that are not exposed on the global object. Reporting it ran
// `fprintf(stderr)` once per wrapped element, so it is off unless asked for.
#ifndef CRANE_PROTO_MISS_LOG
#define CRANE_PROTO_MISS_LOG 0
#endif
#if CRANE_PROTO_MISS_LOG
#define CRANE_PROTO_MISS(...) fprintf(stderr, __VA_ARGS__)
#else
#define CRANE_PROTO_MISS(...) ((void)0)
#endif

// ============================================================================
// Debug Alignment Checks
// ============================================================================
//
// V8 uses pointer tagging on some platforms (arm64). When Zig code receives
// tagged pointers and casts them with @alignCast, it can trigger alignment
// errors. These macros help detect misaligned pointers at the FFI boundary.
//
// Usage: CHECK_ALIGNMENT(ptr, Type) at the start of functions that receive
// Global<T>* pointers from Zig.

#ifdef NDEBUG
// Release build: no-op
#define CHECK_ALIGNMENT(ptr, type) ((void)0)
#define CHECK_ALIGNMENT_LOG(ptr, type, func_name) ((void)0)
#else
// Debug build: check alignment and log errors
#define CHECK_ALIGNMENT(ptr, type) \
    do { \
        if (ptr && (reinterpret_cast<uintptr_t>(ptr) & (alignof(type) - 1)) != 0) { \
            fprintf(stderr, "V8_WRAPPER: Misaligned pointer %p for type %s (requires %zu-byte alignment, got %zu)\n", \
                    static_cast<const void*>(ptr), #type, alignof(type), \
                    reinterpret_cast<uintptr_t>(ptr) & (alignof(type) - 1)); \
        } \
    } while (0)

#define CHECK_ALIGNMENT_LOG(ptr, type, func_name) \
    do { \
        if (ptr && (reinterpret_cast<uintptr_t>(ptr) & (alignof(type) - 1)) != 0) { \
            fprintf(stderr, "V8_WRAPPER[%s]: Misaligned pointer %p for type %s (requires %zu-byte alignment)\n", \
                    func_name, static_cast<const void*>(ptr), #type, alignof(type)); \
        } \
    } while (0)
#endif

// ============================================================================
// Weak Callback Support (must be outside extern "C")
// ============================================================================

/// Weak callback function type (matches Zig WeakCallbackFn)
typedef void (*ZigWeakCallbackFn)(void* data, size_t length_in_bytes);

/// Weak callback data structure
///
/// `handle` is the `Global<T>` this record was armed on. It is NULL once that
/// Global has been disposed - see `releaseWeakArm` for why that case exists and
/// why the callback must honour it.
struct WeakCallbackData {
    // Runs in V8's FIRST pass, after the handle is Reset: Zig bookkeeping
    // only - no V8 API call (v8-weak-callback-info.h). May be null.
    ZigWeakCallbackFn callback;
    void* user_data;
    Global<Value>* handle;  // Store handle pointer so we can reset it
    // The isolate the arm belongs to. Disposing an isolate frees only its own
    // detached records: another isolate's may still have a callback queued.
    Isolate* isolate;
    // The finalizer proper (v8_Global_SetWeakFinalizer): runs AFTER the
    // collection, at its agent's safe point (`runQueuedFinalizers`), where
    // engine work is allowed - V8's first pass only queues it
    // (`queueFinalizer`). Null for a first-pass-only arm.
    ZigWeakCallbackFn finalize = nullptr;
};

// ---------------------------------------------------------------------------
// Ownership of a weak arm
// ---------------------------------------------------------------------------
//
// `v8_Global_SetWeak` heap-allocates a `WeakCallbackData` holding a RAW pointer
// back to a `Global<T>` that Zig owns and frees on its own schedule. Nothing
// made the two lifetimes agree, and they came apart in both directions:
//
//   * `PersistentBase::ClearWeak()` is `ClearWeak<void>()`, which DISCARDS the
//     parameter V8 hands back. Every disarm leaked a record, and
//     `wrapper_cache.zig` disarms in five places on every DOM wrapper.
//
//   * Disposing an armed Global deleted it with the record still pointing at it.
//     V8 COPIES the callback parameter into a pending list during GC and runs
//     every first-pass callback afterwards (`GlobalHandles::PendingPhantomCallback`
//     keeps `parameter_`, not the node's), so one callback's Zig side is free to
//     dispose a SECOND armed handle whose callback is still queued in the same
//     pass. That second callback then reset a `Global<Value>` whose memory had
//     already been recycled:
//
//         Segmentation fault at address 0x4dbacbca5b9a861c
//           GlobalHandles::NodeSpace<Node>::Release
//           PersistentBase<Value>::Reset
//           WeakCallbackWrapper                     (this file, below)
//           GlobalHandles::InvokeFirstPassWeakCallbacks
//
//     0x4dba is U+4DBA, a codepoint the encoding test was printing at the time.
//     The bytes in the freed handle were the test's own data.
//
// The rule now: a record is owned by the arm, and the arm ends when the handle
// is disarmed or disposed, whichever comes first. `armedWeakData` is what makes
// that enforceable - V8 cannot answer "is this handle still armed?" once the
// node reaches NEAR_DEATH, because `IsWeak()` is false from that moment and
// `ClearWeak()` can no longer reach the parameter.
//
// Both maps are the process's: each Browser thread and each worker thread
// (docs/instances.md) arms, releases and collects its own isolates' handles
// here, so every access holds `weakDataLock()`. A record and its handle belong
// to one isolate, used by one thread; the lock only keeps the containers whole.
//
// They stay the process's (instances B2 moved the rest of the adapter's
// per-isolate state into each isolate's record, kIsolateDataSlot): a release
// is reached from every delete site of a Global - fifty-odd `v8_*_Dispose`
// functions and resetGlobalHandle, most handed nothing but the handle - and V8
// cannot say which isolate a Global<T> is of, so the only key a release has is
// the handle itself.
static std::mutex& weakDataLock() {
    // process-wide: guards armedWeakData() and detachedWeakData(), which every isolate of the process shares; held for a find, an insert or an erase, never across a call into Zig or script.
    static std::mutex lock;
    return lock;
}

static std::unordered_map<const void*, WeakCallbackData*>& armedWeakData() {
    // process-wide: every isolate's armed weak records, by their Global - a release (fifty-odd delete sites) has only the handle, and V8 cannot say which isolate a handle is of; under weakDataLock(), held for one find, insert or erase, never across a call into Zig or script.
    static std::unordered_map<const void*, WeakCallbackData*> map;
    return map;
}

/// Records that a dispose detached from their Global while V8 still had their
/// callback queued. They must outlive the dispose - V8 WILL invoke them - so the
/// callback frees them. Held here so the count is a real live count and a record
/// whose callback never fires is still reachable.
static std::unordered_set<WeakCallbackData*>& detachedWeakData() {
    // process-wide: the records a release detached from their Global while V8 still had their callback queued - entered by the same handle-only releases as armedWeakData(); under weakDataLock(); v8_Isolate_Dispose frees its own isolate's.
    static std::unordered_set<WeakCallbackData*> set;
    return set;
}

/// Records whose first pass has run and whose finalizer waits on its agent's
/// queue, by the handle they were armed on. The handle is Reset by then; its
/// owner disposes it from the finalizer - or earlier, which cancels the
/// finalizer (`releaseWeakArm`): the owner is freeing `user_data` in the same
/// breath. A record whose finalizer never runs - its isolate disposed first,
/// or an isolate with no queue - is freed by `v8_Isolate_Dispose`.
///
/// Per thread: V8 runs an isolate's weak callbacks on the thread that holds
/// the isolate, and its owner disposes its handles there too, so each
/// thread's isolates keep their own (Browsers and workers run on threads of
/// their own).
static std::unordered_map<const void*, WeakCallbackData*>& pendingFinalizers() {
    // per-thread: V8 runs an isolate's weak callbacks on the thread that holds the isolate - each thread's isolates' pending finalizers, read and written only on that thread.
    static thread_local std::unordered_map<const void*, WeakCallbackData*> map;
    return map;
}

/// How deep this thread is in first-pass weak callbacks: what
/// v8_Debug_InFirstPassWeakCallback reads, so a test can tell that a finalizer
/// ran outside the collection.
// per-thread: a call-stack extent - whether V8's first-pass weak callbacks are running on this thread's stack (a diagnostic for tests).
static thread_local int g_first_pass_depth = 0;

/// The bytes `isolate`'s heap has committed to the space named `name`
/// (HeapSpaceStatistics::space_size), 0 for no such space (tests).
extern "C" size_t v8_Debug_HeapSpaceCommittedBytes(Isolate* isolate, const char* name) {
    if (!isolate || !name) return 0;
    for (size_t i = 0; i < isolate->NumberOfHeapSpaces(); i++) {
        HeapSpaceStatistics statistics;
        if (!isolate->GetHeapSpaceStatistics(&statistics, i)) continue;
        if (strcmp(statistics.space_name(), name) == 0) return statistics.space_size();
    }
    return 0;
}

extern "C" bool v8_Debug_InFirstPassWeakCallback() {
    return g_first_pass_depth > 0;
}

/// Live `WeakCallbackData` records: armed minus freed.
///
/// Cheap enough to leave always on, unlike `CRANE_TRACK_GLOBALS` - it moves once
/// per weak arm, not once per handle creation, and arming is already doing a V8
/// global-handle write.
// process-wide: a diagnostic count over every isolate of the process (std::atomic, relaxed), read by gc_bench, the WPT runner's per-file deltas and tests that hold the process to themselves (lesson testing-a-test-that-measures-a-process-wide-counter-assumes-it-is-alone); it carries no state any instance reads.
static std::atomic<int64_t> g_live_weak_callback_data{0};

extern "C" int64_t v8_Debug_LiveWeakCallbackData() {
    return g_live_weak_callback_data.load(std::memory_order_relaxed);
}

static void freeWeakData(WeakCallbackData* data) {
    delete data;
    g_live_weak_callback_data.fetch_sub(1, std::memory_order_relaxed);
}

/// What happens to the `Global` once its arm is released.
///
/// This is the difference between the two kinds of caller, and V8 cares about
/// it: whoever ends the arm while a first-pass callback is already queued
/// inherits the obligation to Reset the node.
enum class WeakArmEnd {
    /// The caller Resets and deletes the Global immediately after. Every
    /// `v8_*_Dispose` in this file does, and so does `resetGlobalHandle`.
    handle_dying,
    /// The caller keeps the Global. `v8_Global_ClearWeak` is the only one.
    handle_survives,
};

/// End the weak arm on `global`, if it has one.
///
/// Two cases, told apart by `IsWeak()`:
///
///   * still weak - V8 has queued nothing and will never invoke this record, so
///     take the parameter back off the node and free it.
///   * not weak - either never armed (we returned already), or the node is
///     NEAR_DEATH with a first-pass callback queued for this GC. V8 WILL invoke
///     that callback with this record, so the record has to outlive us. It must
///     not run the Zig finalizer either way: every caller here is tearing down
///     the `user_data` in the same breath, which is what made
///     `wrapper_cache.weakCallback` read a destroyed `CacheEntry`.
///
///     What the record keeps is where the two ends differ. `handle_dying` nulls
///     the back-pointer, because the caller's own `Reset()` discharges V8's
///     obligation and the Global is about to be freed. `handle_survives` KEEPS
///     it, because nothing else will ever reset that node - and a first-pass
///     callback that returns without resetting is fatal:
///
///         Check failed: Handle not reset in first callback.
///           See comments on |v8::WeakCallbackInfo|.
///           GlobalHandles::InvokeFirstPassWeakCallbacks
///
///     `wrapper_cache.zig` disarms on six paths on every DOM wrapper, so this
///     needs only a GC to land between V8 queuing the callback and running it.
///     Creating a child context is what made that reliable - registering 1,263
///     interface templates allocates enough to force a collection mid-`appendChild`.
///
/// An unrecognised state takes the second branch, which costs one 24-byte record
/// until the callback runs and never costs correctness. That is deliberate: the
/// cheap answer here is the one that leaks, not the one that frees.
template <typename T>
static void releaseWeakArm(Global<T>* global, WeakArmEnd end = WeakArmEnd::handle_dying) {
    if (!global) return;
    // A finalizer waiting on its agent's queue for this (already Reset)
    // handle: its owner is ending it now, freeing `user_data` with it, so it
    // must not run. The record stays listed on the queue; the drain that
    // reaches it frees it.
    auto& pending = pendingFinalizers();
    if (!pending.empty()) {
        auto pit = pending.find(static_cast<const void*>(global));
        if (pit != pending.end()) {
            WeakCallbackData* waiting = pit->second;
            waiting->finalize = nullptr;
            waiting->user_data = nullptr;
            waiting->handle = nullptr;
            pending.erase(pit);
            // Queued still, on its agent's queue: freed by the queue's
            // drain (`runQueuedFinalizers`), which finds it cancelled, or
            // with its isolate if no drain comes (v8_Isolate_Dispose).
            std::lock_guard<std::mutex> guard(weakDataLock());
            detachedWeakData().insert(waiting);
        }
    }
    // A live handle says whether `armedWeakData` holds it (kArmedFlag): one
    // without the flag has no entry, so no lock and no lookup - nearly every
    // release, which used to take weakDataLock and probe a map holding every
    // live wrapper of the process to find nothing (lane perf3: 9-12% of every
    // perf row; the find alone 16% of event-ctor). An empty handle - Reset by
    // its weak callback - keeps the lookup.
    if (!global->IsEmpty() && !(global->WrapperClassId() & kArmedFlag)) {
        checkHandleFlag(static_cast<const void*>(global), kArmedFlag, weakDataLock(), armedWeakData(), "weak-arm");
        return;
    }
    std::lock_guard<std::mutex> guard(weakDataLock());
    auto& armed = armedWeakData();
    auto it = armed.find(static_cast<const void*>(global));
    if (it == armed.end()) {
#if CRANE_CHECK_HANDLE_FLAGS
        // A live handle got here by its flag: its entry must exist.
        if (!global->IsEmpty()) {
            fprintf(stderr, "v8_wrapper: weak-arm flag set for handle %p, whose entry is absent\n", static_cast<const void*>(global));
            abort();
        }
#endif
        return;
    }

    WeakCallbackData* data = it->second;

    if (global->IsWeak()) {
        armed.erase(it);
        global->template ClearWeak<void>();
        clearHandleFlag(static_cast<const void*>(global), kArmedFlag);
        freeWeakData(data);
        return;
    }

    // Detached: V8 still owns this record for the rest of the collection.
    // The Zig side is going away with the caller, so silence it - its
    // finalizer too, or the first pass would schedule it.
    data->callback = nullptr;
    data->finalize = nullptr;
    data->user_data = nullptr;
    detachedWeakData().insert(data);

    if (end == WeakArmEnd::handle_dying) {
        armed.erase(it);
        clearHandleFlag(static_cast<const void*>(global), kArmedFlag);
        data->handle = nullptr;
        return;
    }

    // `handle_survives`: leave the record in `armedWeakData` under this handle.
    // It is no longer an arm - `callback` is null and nothing will call Zig -
    // but it is the ONLY way a later `v8_Global_Dispose` of the same handle can
    // find this record and cut the back-pointer before the Global is deleted.
    // Drop it here and a ClearWeak-then-Dispose in one tick would leave the
    // queued callback doing `data->handle->Reset()` on freed memory, which is
    // the same use-after-free the note above this function describes.
    // `WeakCallbackWrapper` erases it by handle on its way through.
}

/// `releaseWeakArm` for a caller that has lost the handle's type. Same cast
/// `v8_Global_SetWeak` makes: every `Global<T>` is one slot pointer, and neither
/// `IsWeak` nor `ClearWeak` reads T.
static void releaseWeakArmRaw(void* handle) {
    releaseWeakArm(reinterpret_cast<Global<Value>*>(handle));
}

/// Arm `handle` with `data`, replacing and releasing any arm already on it.
///
/// V8 keeps only the newest parameter, so a second `SetWeak` on the same handle
/// strands the first record where nothing can reach it.
static void armWeakData(void* handle, WeakCallbackData* data) {
    releaseWeakArm(reinterpret_cast<Global<Value>*>(handle));
    g_live_weak_callback_data.fetch_add(1, std::memory_order_relaxed);
    std::lock_guard<std::mutex> guard(weakDataLock());
    armedWeakData()[handle] = data;
    // With the entry, under the lock: an entry always has its flag.
    setHandleFlag(handle, kArmedFlag);
}

static void queueFinalizer(Isolate* isolate, WeakCallbackData* data);
static bool runQueuedFinalizers(Isolate* isolate);
static void oweWaitingAnchorFrees(Isolate* isolate);

/// Internal weak callback wrapper - V8 calls this, which then calls the Zig callback
template<typename T>
static void WeakCallbackWrapper(const WeakCallbackInfo<WeakCallbackData>& info) {
    WeakCallbackData* data = info.GetParameter();
    if (!data) return;

    // A null `handle` means a dispose got here first: `releaseWeakArm` detached
    // this record because V8 had already queued the callback for this GC.
    //
    // Free the record and RETURN. The Zig finalizer does not run, and that is
    // the point. Every disposer in this tree frees the Zig side in the same
    // breath as the handle - `disposeEntryWrapper` is followed by
    // `allocator.destroy(entry)` on all six `wrapper_cache` paths, and
    // `observable_array_exotic.cleanupAll` destroys the state right after its
    // `ClearWeak` - so `user_data` is freed memory by now. Running
    // `wrapper_cache.weakCallback` on a destroyed `CacheEntry` reads
    // `entry.cache` out of the freed allocation and then calls `fetchRemove` on
    // whatever HashMap that lands in.
    //
    // Skipping costs at most a leak of a `user_data` its owner did not free.
    // Calling is a use-after-free. Same trade as the rest of this file: the
    // unproven case takes the branch that costs memory.
    //
    // V8's own obligation is already discharged - the dispose reset the node -
    // so there is nothing to Reset here either.
    if (!data->handle) {
        {
            std::lock_guard<std::mutex> guard(weakDataLock());
            detachedWeakData().erase(data);
        }
        freeWeakData(data);
        return;
    }

    // v8-weak-callback-info.h: "When first called, the embedder MUST Reset() the
    // Global which triggered the callback."
    //
    // Erase BEFORE calling into Zig: the Zig finalizer routinely disposes this
    // very handle, and it must not find a stale arm to release.
    {
        std::lock_guard<std::mutex> guard(weakDataLock());
        armedWeakData().erase(static_cast<const void*>(data->handle));
    }
    // The node is reset here, not by the dispose that may follow: counted out
    // now (an inline read of the node's class id, no V8 call). Reset frees the
    // node, and V8 clears its class id, flags included.
    forgetCountedHandle(data->handle);
    data->handle->Reset();

    // A `handle_survives` detach (v8_Global_ClearWeak on an already-queued
    // node) leaves the record HERE with its handle intact, precisely so the
    // Reset above can happen. It nulls `callback` and `finalize`, so nothing
    // below runs and this erase is the only cleanup it needs. Erasing a key
    // that was never inserted is a no-op, so the armed path pays nothing.
    {
        std::lock_guard<std::mutex> guard(weakDataLock());
        detachedWeakData().erase(data);
    }

    // A finalizer waits for its agent's safe point from here - registered
    // before the first-pass callback runs, so that one disposing the handle
    // cancels it (`releaseWeakArm`) like any other owner.
    if (data->finalize) pendingFinalizers()[static_cast<const void*>(data->handle)] = data;

    // The first-pass callback: the same header allows no V8 API call here -
    // other handles of this collection may hold the 0xCA11 zap value until
    // their own callbacks run - so it is bookkeeping only.
    if (data->callback) {
        ++g_first_pass_depth;
        data->callback(data->user_data, 0);
        --g_first_pass_depth;
    }

    // The finalizer is QUEUED HERE, in the first pass, on its agent
    // (`queueFinalizer`: a list push and one byte stored - nothing of V8's
    // API, nothing of Zig's), and runs at the agent's next safe point
    // (`runQueuedFinalizers`). No second pass is set: "Should additional work
    // be required, the embedder must set a second pass callback"
    // (v8-weak-callback-info.h) is for work that needs V8 inside the
    // collection's own processing, and the adapter's work waits for its own
    // safe point instead. See "Why the first pass queues" below.
    if (data->finalize) {
        queueFinalizer(info.GetIsolate(), data);
        return;
    }

    // No finalizer, or one the callback cancelled (its record went to the
    // detached set): nothing more runs for it.
    {
        std::lock_guard<std::mutex> guard(weakDataLock());
        detachedWeakData().erase(data);
    }
    freeWeakData(data);
}

// Why the first pass queues, and V8's second pass is not used.
//
// NO ZIG FINALIZER RUNS INSIDE A COLLECTION OR IN V8'S SECOND PASS. V8 15.7
// runs both under DisallowJavascriptExecution and DisallowJSObjectModification
// (15.7.112.43 src/heap/heap.cc:1470-1477: "JS execution and object
// modifications are not allowed during GC or in any of the embedder callbacks
// triggered below: first-pass weak callbacks ..., second-pass phantom
// callbacks (PostGarbageCollectionProcessing) ..."; the pass V8 posts as a
// task, src/handles/global-handles.cc:890-900) and CHECKs the second scope
// wherever an object's map changes (src/objects/map.cc, lookup.cc,
// transitions.cc). A finalizer is an instance's teardown: a dropped
// Response's cancelled its open body transfer, which reported a
// resource-timing entry to its page and wrote a JS object ("Check failed:
// AllowJSObjectModification::IsAllowed(isolate)", 3 files in lane v8up b5's
// sweep). 13.1 had neither scope around its second pass, where the finalizers
// used to run. So a dead wrapper's finalizer waits on its agent's queue for
// the agent's safe point - a binding's return into script, the pump, a forced
// collection's return (`runQueuedFinalizers`).
//
// THE RECORD JOINS THAT QUEUE IN THE FIRST PASS (lane v8up b7). Lane b6 had
// V8's second pass do the queueing, and a second pass is late by a whole
// collection for a script that does not return to the event loop: V8 posts
// it as a task (global-handles.cc:892-901) and, when the next collection
// begins before that task has run, runs it at that collection's start
// (heap.cc:1509-1511). A wrapper found dead by scavenge k was finalized after
// scavenge k+1 began, so the native state of two young generations of dead
// wrappers was alive at once - and V8 15.7 keeps a larger young generation
// than 13.1 did (a semispace of up to 32 MB, heap.cc:4844-4860; 13.1 capped
// the scavenger at 8 MB, flag scavenger_max_new_space_capacity_mb). Measured
// (release consoles, chat.local, dom.event-ctor's end mark, 650,000 dropped
// Events): 113.5 MB of Event state blocks with the second pass queueing,
// 66.8 MB with the first.
//
// It is what the first pass is for. V8 hands the embedder each dead object's
// parameter there; the embedder Resets its handle and does its bookkeeping
// without V8's API (v8-weak-callback-info.h), and the second pass exists for
// work that needs that API. Node.js frees the native object itself in the
// first pass (src/base_object.cc:59-71, BaseObject::MakeWeak's callback ->
// OnGCCollect, base_object-inl.h:112-114 `delete this`; Node main
// ab11f834fc6 on V8 15.6). Blink has no pass at all: its
// wrappables are cppgc objects whose destructors "must not touch any other
// on-heap object" (platform/heap/BlinkGCAPIReference.md, GarbageCollected)
// and run when the page they are on is swept, inside the running script
// (cppgc-internal/object-allocator.cc TryRefillLinearAllocationBuffer ->
// Sweeper::SweepForAllocationIfRunning); its pre-Oilpan second pass only
// dropped the object's reference (ScriptWrappable.h, Chromium 45). WebKit
// marks a dead Weak in WeakBlock::reap and calls WeakHandleOwner::finalize
// from WeakBlock::sweep, after the collection (JavaScriptCore/heap/
// WeakBlock.cpp), where a DOM wrapper's owner only uncaches it
// (WebCore/bindings/js/JSDOMWrapperCache.h uncacheWrapper).
//
// What it changes and what it does not: WHEN a record joins the queue (in the
// collection that found its wrapper dead, not after V8's later task or next
// collection), and the ORDER within one collection (the first pass's own
// order; V8's second pass handed them over reversed, global-handles.cc:850,
// 765-767). The safe points and their rules are the same. A node wrapper's
// release joins the queue the same way - owed in the collection that found
// its wrapper dead (`noteNodeWrappersCollected`) - since lane wr1 b11 closed
// the hole in refcount step 7a's net that had made its timing matter.

// ============================================================================
// V8 Exception Information Structure
// ============================================================================
//
// When V8 operations throw JavaScript exceptions, we capture detailed error
// information including the message, stack trace, line/column numbers, and
// source line. This enables proper error reporting in Zig code.

struct V8ErrorInfo {
    bool has_error;
    char* message;         // malloc'd, Zig must free
    char* stack_trace;     // malloc'd, Zig must free
    int line_number;
    int column_number;
    char* source_line;     // malloc'd, Zig must free
    char* resource_name;   // malloc'd, Zig must free
    // The thrown value itself, or nullptr when there was none to capture.
    // Owned by this struct: v8_FreeErrorInfo disposes it, so a caller that only
    // wants the strings leaks nothing, and a caller that needs the value past
    // the free - "report an exception" puts it in ErrorEvent.error, and a
    // module script keeps its parse error to rethrow - must copy it into a
    // Global of its own first.
    Global<Value>* exception;
};

/// Extract exception information from a TryCatch
///
/// This function extracts all available information from a V8 exception:
/// - The exception message
/// - Stack trace (if available)
/// - Line and column numbers
/// - Source line text
/// - Resource name (filename/URL)
///
/// The caller is responsible for freeing the returned struct with v8_FreeErrorInfo.
static V8ErrorInfo* extractException(Isolate* isolate, TryCatch* try_catch) {
    HandleScope handle_scope(isolate);
    
    V8ErrorInfo* info = new V8ErrorInfo();
    info->has_error = true;
    info->message = nullptr;
    info->stack_trace = nullptr;
    info->line_number = -1;
    info->column_number = -1;
    info->source_line = nullptr;
    info->resource_name = nullptr;
    
    // Extract exception message
    Local<Value> exception = try_catch->Exception();
    String::Utf8Value exception_str(isolate, exception);
    info->message = strdup(*exception_str ? *exception_str : "Unknown error");
    info->exception = nullptr;
    if (!exception.IsEmpty()) {
        info->exception = trackHandle(new Global<Value>(isolate, exception));
    }
    
    // Extract detailed message information
    Local<Message> message = try_catch->Message();
    if (!message.IsEmpty()) {
        Local<Context> ctx = isolate->GetCurrentContext();
        
        // Line and column numbers
        info->line_number = message->GetLineNumber(ctx).FromMaybe(-1);
        info->column_number = message->GetStartColumn();
        
        // Source line
        MaybeLocal<String> source_line_maybe = message->GetSourceLine(ctx);
        if (!source_line_maybe.IsEmpty()) {
            String::Utf8Value source(isolate, source_line_maybe.ToLocalChecked());
            info->source_line = strdup(*source ? *source : "");
        }
        
        // Resource name (filename/URL)
        Local<Value> resource = message->GetScriptResourceName();
        String::Utf8Value resource_str(isolate, resource);
        info->resource_name = strdup(*resource_str ? *resource_str : "<unknown>");
        
        // Full stack trace
        MaybeLocal<Value> stack_trace_maybe = try_catch->StackTrace(ctx);
        if (!stack_trace_maybe.IsEmpty()) {
            String::Utf8Value stack(isolate, stack_trace_maybe.ToLocalChecked());
            info->stack_trace = strdup(*stack ? *stack : "");
        }
    }
    
    return info;
}

extern "C" {

// ============================================================================
// V8ErrorInfo Functions
// ============================================================================

/// Free a V8ErrorInfo structure
///
/// Frees all strings allocated within the structure and the structure itself.
void v8_FreeErrorInfo(V8ErrorInfo* info) {
    if (!info) return;

    if (info->message) free(info->message);
    if (info->stack_trace) free(info->stack_trace);
    if (info->source_line) free(info->source_line);
    if (info->resource_name) free(info->resource_name);
    if (info->exception) {
        releaseWeakArm(info->exception);
        info->exception->Reset();
        delete info->exception;
    }

    delete info;
}

/// "Extract error information" for a thrown value that did not arrive through a
/// TryCatch: a module script's evaluation promise rejecting, or the parse error
/// a module script keeps to rethrow.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#extract-error
/// The spec leaves message, filename, lineno and colno implementation-defined.
/// The message is the value's ToString, the same text extractException uses,
/// so an error reports identically whichever path it took. The location comes
/// from v8::Exception::CreateMessage, which for an Error object reads the stack
/// it captured when it was constructed - where it was thrown, for every
/// ordinary `throw new X()`.
///
/// Returns an info the caller frees with v8_FreeErrorInfo, whose `exception`
/// is a fresh Global of the value. Null only when there is nothing to work with.
V8ErrorInfo* v8_Exception_GetErrorInfo(Global<Context>* context, Global<Value>* exception) {
    Isolate* isolate = Isolate::GetCurrent();
    if (!isolate || !context || !exception || exception->IsEmpty()) return nullptr;
    HandleScope handle_scope(isolate);

    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);

    // ToString on an arbitrary thrown value can run script and throw again. That
    // second exception has nowhere to go and must not stay pending into the next
    // unrelated V8 call.
    TryCatch try_catch(isolate);

    Local<Value> value = exception->Get(isolate);

    V8ErrorInfo* info = new V8ErrorInfo();
    info->has_error = true;
    info->line_number = -1;
    info->column_number = -1;
    info->exception = trackHandle(new Global<Value>(isolate, value));

    String::Utf8Value text(isolate, value);
    info->message = strdup(*text ? *text : "Uncaught exception");

    Local<Message> message = Exception::CreateMessage(isolate, value);
    if (!message.IsEmpty()) {
        info->line_number = message->GetLineNumber(ctx).FromMaybe(-1);
        info->column_number = message->GetStartColumn();
        // A value made with no script on the stack has no script resource
        // name (undefined): its filename is "", as engine.ErrorInfo says -
        // not ToString(undefined), "undefined".
        Local<Value> resource_name = message->GetScriptResourceName();
        if (resource_name->IsString()) {
            String::Utf8Value resource(isolate, resource_name);
            info->resource_name = strdup(*resource ? *resource : "");
        } else {
            info->resource_name = strdup("");
        }
    }

    return info;
}

// ============================================================================
// Safe Script/Module Operations with TryCatch
// ============================================================================
// These "_Safe" variants wrap V8 operations with TryCatch to capture exception
// details when operations fail. This enables proper error reporting in Zig.

/// Result structure for safe script compilation
struct V8ScriptCompileResult {
    Global<Script>* script;      // nullptr if compilation failed
    V8ErrorInfo* error;          // nullptr if compilation succeeded
};

/// Result structure for safe script execution
struct V8ScriptRunResult {
    Global<Value>* value;        // nullptr if execution failed
    V8ErrorInfo* error;          // nullptr if execution succeeded
};

/// Result structure for safe function calls
struct V8FunctionCallResult {
    Global<Value>* value;        // nullptr if call failed
    V8ErrorInfo* error;          // nullptr if call succeeded
};

/// Result structure for safe module compilation
struct V8ModuleCompileResult {
    Global<Module>* module;      // nullptr if compilation failed
    V8ErrorInfo* error;          // nullptr if compilation succeeded
};

/// Result structure for safe module evaluation
struct V8ModuleEvaluateResult {
    Global<Value>* value;        // nullptr if evaluation failed
    V8ErrorInfo* error;          // nullptr if evaluation succeeded
};

/// Result structure for safe ToString conversion
/// 
/// Per WebIDL § 3.2.1, when converting a value to DOMString/USVString:
/// - If the value's toString() method throws, the exception MUST propagate
/// - We capture the exception so the caller can rethrow it
struct V8ToStringResult {
    Global<String>* value;       // nullptr if conversion failed
    Global<Value>* exception;    // The thrown exception value (nullptr if success)
};

/// Compile a script with TryCatch error handling
///
/// Returns both the compiled script (on success) and error details (on failure).
/// The caller must free the error with v8_FreeErrorInfo if non-null.
V8ScriptCompileResult* v8_Script_Compile_Safe(Global<Context>* context, Global<String>* source) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Context::Scope context_scope(local_context);  // Ensure context is entered for compilation
    Local<String> local_source = source->Get(isolate);
    
    V8ScriptCompileResult* result = new V8ScriptCompileResult();
    result->script = nullptr;
    result->error = nullptr;
    
    TryCatch try_catch(isolate);
    
    MaybeLocal<Script> maybe_script = Script::Compile(local_context, local_source);
    
    if (try_catch.HasCaught()) {
        result->error = extractException(isolate, &try_catch);
        return result;
    }
    
    if (maybe_script.IsEmpty()) {
        // No exception but empty result - create generic error
        result->error = new V8ErrorInfo();
        result->error->has_error = true;
        result->error->message = strdup("Script compilation failed");
        result->error->stack_trace = nullptr;
        result->error->line_number = -1;
        result->error->column_number = -1;
        result->error->source_line = nullptr;
        result->error->resource_name = nullptr;
        return result;
    }
    
    Local<Script> script = maybe_script.ToLocalChecked();
    result->script = trackHandle(new Global<Script>(isolate, script));
    return result;
}

/// Compile a script with origin and TryCatch error handling
V8ScriptCompileResult* v8_Script_CompileWithOrigin_Safe(
    Global<Context>* context,
    Global<String>* source,
    Global<String>* resource_name
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Context::Scope context_scope(local_context);  // Ensure context is entered for compilation
    Local<String> local_source = source->Get(isolate);
    Local<String> local_resource_name = resource_name->Get(isolate);
    
    V8ScriptCompileResult* result = new V8ScriptCompileResult();
    result->script = nullptr;
    result->error = nullptr;
    
    ScriptOrigin origin(local_resource_name);
    
    TryCatch try_catch(isolate);
    
    MaybeLocal<Script> maybe_script = Script::Compile(local_context, local_source, &origin);
    
    if (try_catch.HasCaught()) {
        result->error = extractException(isolate, &try_catch);
        return result;
    }
    
    if (maybe_script.IsEmpty()) {
        result->error = new V8ErrorInfo();
        result->error->has_error = true;
        result->error->message = strdup("Script compilation failed");
        result->error->stack_trace = nullptr;
        result->error->line_number = -1;
        result->error->column_number = -1;
        result->error->source_line = nullptr;
        result->error->resource_name = nullptr;
        return result;
    }
    
    Local<Script> script = maybe_script.ToLocalChecked();
    result->script = trackHandle(new Global<Script>(isolate, script));
    return result;
}

/// Free a V8ScriptCompileResult
void v8_FreeScriptCompileResult(V8ScriptCompileResult* result) {
    if (!result) return;
    // Note: script is owned by caller if non-null
    if (result->error) v8_FreeErrorInfo(result->error);
    delete result;
}

/// Run a compiled script with TryCatch error handling
V8ScriptRunResult* v8_Script_Run_Safe(Global<Context>* context, Global<Script>* script) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Context::Scope context_scope(local_context);  // Ensure context is entered for global resolution
    Local<Script> local_script = script->Get(isolate);
    
    V8ScriptRunResult* result = new V8ScriptRunResult();
    result->value = nullptr;
    result->error = nullptr;
    
    TryCatch try_catch(isolate);
    
    MaybeLocal<Value> maybe_result = local_script->Run(local_context);
    
    if (try_catch.HasCaught()) {
        result->error = extractException(isolate, &try_catch);
        return result;
    }
    
    if (maybe_result.IsEmpty()) {
        result->error = new V8ErrorInfo();
        result->error->has_error = true;
        result->error->message = strdup("Script execution failed");
        result->error->stack_trace = nullptr;
        result->error->line_number = -1;
        result->error->column_number = -1;
        result->error->source_line = nullptr;
        result->error->resource_name = nullptr;
        return result;
    }
    
    Local<Value> value = maybe_result.ToLocalChecked();
    result->value = trackHandle(new Global<Value>(isolate, value));
    return result;
}

/// Free a V8ScriptRunResult
void v8_FreeScriptRunResult(V8ScriptRunResult* result) {
    if (!result) return;
    // Note: value is owned by caller if non-null
    if (result->error) v8_FreeErrorInfo(result->error);
    delete result;
}

/// Call a function stored as Global<Value>* (casts to Function internally)
V8FunctionCallResult* v8_Function_Call_Safe(
    Global<Value>* function,
    Global<Context>* context,
    Global<Value>* recv,
    int argc,
    Global<Value>** argv
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);

    if (!function || function->IsEmpty()) {
        V8FunctionCallResult* result = new V8FunctionCallResult();
        result->value = nullptr;
        result->error = new V8ErrorInfo();
        result->error->has_error = true;
        result->error->message = strdup("Function handle is null or empty");
        return result;
    }

    Local<Value> fn_value = function->Get(isolate);

    if (!fn_value->IsFunction()) {
        V8FunctionCallResult* result = new V8FunctionCallResult();
        result->value = nullptr;
        result->error = new V8ErrorInfo();
        result->error->has_error = true;
        result->error->message = strdup("Value is not a function");
        return result;
    }
    
    Local<Function> fn = fn_value.As<Function>();
    
    Local<Context> ctx = context->Get(isolate);
    Local<Value> this_val = recv ? recv->Get(isolate) : Undefined(isolate).As<Value>();
    
    V8FunctionCallResult* result = new V8FunctionCallResult();
    result->value = nullptr;
    result->error = nullptr;
    
    // Convert argument array from Global to Local
    Local<Value>* local_argv = argc > 0 ? new Local<Value>[argc] : nullptr;
    for (int i = 0; i < argc; i++) {
        local_argv[i] = argv[i]->Get(isolate);
    }
    
    TryCatch try_catch(isolate);
    
    MaybeLocal<Value> maybe_result = fn->Call(ctx, this_val, argc, local_argv);
    
    delete[] local_argv;
    
    if (try_catch.HasCaught()) {
        result->error = extractException(isolate, &try_catch);
        return result;
    }
    
    if (maybe_result.IsEmpty()) {
        result->error = new V8ErrorInfo();
        result->error->has_error = true;
        result->error->message = strdup("Function call failed");
        result->error->stack_trace = nullptr;
        result->error->line_number = -1;
        result->error->column_number = -1;
        result->error->source_line = nullptr;
        result->error->resource_name = nullptr;
        return result;
    }
    
    Local<Value> value = maybe_result.ToLocalChecked();
    result->value = trackHandle(new Global<Value>(isolate, value));
    return result;
}

/// Call a function with receiver and TryCatch error handling
V8FunctionCallResult* v8_Function_CallWithReceiver_Safe(
    Global<Context>* context,
    Global<Function>* function,
    Global<Value>* receiver,
    int argc,
    Global<Value>** argv
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Function> fn = function->Get(isolate);
    Local<Value> recv = receiver ? receiver->Get(isolate) : Undefined(isolate).As<Value>();
    
    V8FunctionCallResult* result = new V8FunctionCallResult();
    result->value = nullptr;
    result->error = nullptr;
    
    std::vector<Local<Value>> args;
    args.reserve(argc);
    for (int i = 0; i < argc; i++) {
        args.push_back(argv[i]->Get(isolate));
    }
    
    TryCatch try_catch(isolate);
    
    MaybeLocal<Value> maybe_result = fn->Call(ctx, recv, argc, args.data());
    
    if (try_catch.HasCaught()) {
        result->error = extractException(isolate, &try_catch);
        return result;
    }
    
    if (maybe_result.IsEmpty()) {
        result->error = new V8ErrorInfo();
        result->error->has_error = true;
        result->error->message = strdup("Function call failed");
        result->error->stack_trace = nullptr;
        result->error->line_number = -1;
        result->error->column_number = -1;
        result->error->source_line = nullptr;
        result->error->resource_name = nullptr;
        return result;
    }
    
    Local<Value> value = maybe_result.ToLocalChecked();
    result->value = trackHandle(new Global<Value>(isolate, value));
    return result;
}

/// Free a V8FunctionCallResult
void v8_FreeFunctionCallResult(V8FunctionCallResult* result) {
    if (!result) return;
    // Note: value is owned by caller if non-null
    if (result->error) v8_FreeErrorInfo(result->error);
    delete result;
}

// ============================================================================
// Completion-returning primitives (WebIDL "invoke a callback function")
// ============================================================================
//
// `v8_Function_Call` leaves a throw pending on the isolate, where Zig can
// neither read nor clear it, and the `_Safe` variants catch it but report only
// its string form. WebIDL needs the thrown VALUE: a callback whose return type
// is a promise turns it into a rejected promise, and "rethrow" hands it back
// to the caller's caller unchanged (Streams: `start()` throwing `error1` must
// make the constructor throw `error1`, not a TypeError describing it).

/// Run `body(data)` under a TryCatch - the completion of native code rather
/// than of a JS function. Returns whether it threw; the thrown value is handed
/// back as a new Global in `*exception` (the caller owns it) and the exception
/// is cleared, for the caller to settle - a promise-returning operation
/// rejects with it (WebIDL 3.7.6). A terminating isolate is rethrown, not
/// caught, and reports false. A TryCatch keys off its own stack address, so
/// the FFI takes a callback rather than handing out a scope.
bool v8_RunCatching(Isolate* isolate, void (*body)(void*), void* data, Global<Value>** exception) {
    *exception = nullptr;
    TryCatch try_catch(isolate);
    body(data);
    if (!try_catch.HasCaught()) return false;
    if (try_catch.HasTerminated()) {
        try_catch.ReThrow();
        return false;
    }
    HandleScope handle_scope(isolate);
    *exception = trackHandle(new Global<Value>(isolate, try_catch.Exception()));
    try_catch.Reset();
    return true;
}

// ============================================================================
// Binding catch scopes (HTML 4.13.6 [CEReactions]; engine.withPendingExceptionSetAside)
// ============================================================================
//
// V8 hands an exception thrown inside an API callback only to a v8::TryCatch
// registered BEFORE the throw (Isolate::Throw ->
// PropagateExceptionToExternalTryCatch); the public API has no way to read or
// clear one afterwards, and the next Function::Call clears it silently
// (PrepareForExecutionScope -> clear_internal_exception). So a [CEReactions]
// member's dispatch runs in a catch scope, as Blink's CEReactionsScope holds
// a v8::TryCatch member for its life (ce_reactions_scope.cc): what the member
// leaves pending is held by the scope's TryCatch, withPendingExceptionSetAside
// sets it aside around the reactions and makes it pending there again, and on
// exit a caught exception is rethrown -
// what script sees is unchanged.
//
// The innermost scope is kept in the isolate's data slot 3 (a scope saves the
// outer one and restores it on exit). Slot 3 held a snapshot isolate's copy
// of its blob only "for cleanup", and nothing ever read it back; the blob is
// no longer copied at all (v8_Isolate_NewFromSnapshot), and its StartupData
// is in the isolate's record in slot 2 (kIsolateDataSlot).
static constexpr uint32_t kBindingCatchScopeSlot = 3;

/// Run `body(data)` in a binding catch scope. A caught exception is rethrown
/// when the scope ends (ReThrow keeps the throw's message).
void v8_RunInBindingCatchScope(Isolate* isolate, void (*body)(void*), void* data) {
    TryCatch try_catch(isolate);
    void* outer = isolate->GetData(kBindingCatchScopeSlot);
    isolate->SetData(kBindingCatchScopeSlot, &try_catch);
    body(data);
    isolate->SetData(kBindingCatchScopeSlot, outer);
    if (try_catch.HasCaught()) try_catch.ReThrow();
}

/// engine.withPendingExceptionSetAside on V8: run `steps(data)` with what the
/// innermost binding catch scope holds set aside, then make it pending again
/// in that same scope (ThrowException inside its still-active TryCatch, which
/// catches it again; the dispatch's exit ReThrow()s it as before). The steps
/// run under a TryCatch of their own, so whatever they leave pending is
/// cleared, never restored in the operation's place. 0: the steps ran.
/// -1: an exception is pending that no binding catch scope holds - V8 cannot
/// reach it; the steps did not run and it stays pending. -2: the isolate is
/// terminating; the steps did not run.
int v8_WithBindingExceptionSetAside(Isolate* isolate, void (*steps)(void*), void* data) {
    Isolate::Scope isolate_scope(isolate);
    HandleScope handle_scope(isolate);
    if (isolate->IsExecutionTerminating()) return -2;
    TryCatch* scope = static_cast<TryCatch*>(isolate->GetData(kBindingCatchScopeSlot));
    Local<Value> saved;
    if (scope && scope->HasCaught()) {
        if (scope->HasTerminated()) return -2;
        saved = scope->Exception();
        scope->Reset();
    } else if (isolate->HasPendingException()) {
        return -1;
    }
    {
        TryCatch steps_guard(isolate);
        steps(data);
        if (steps_guard.HasCaught() && steps_guard.HasTerminated()) {
            steps_guard.ReThrow();
            return -2;
        }
    }
    if (!saved.IsEmpty()) isolate->ThrowException(saved);
    return 0;
}

/// Call `function` with `recv` (null = undefined) under a TryCatch and return
/// the completion. On a normal return the result is returned and `*threw` is
/// false; on a throw the thrown value is returned and `*threw` is true - the
/// exception is caught, never left pending. Returns nullptr with `*threw` true
/// only when there is no value to report: `function` is not callable, or the
/// isolate is terminating. Every non-null result is a new Global the caller owns.
Global<Value>* v8_Function_CallCatching(
    Global<Context>* context,
    Global<Value>* function,
    Global<Value>* recv,
    int argc,
    Global<Value>** argv,
    bool* threw
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    *threw = true;

    if (!context || !function || function->IsEmpty()) return nullptr;
    Local<Value> fn_value = function->Get(isolate);
    if (!fn_value->IsFunction()) return nullptr;

    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);
    Local<Value> this_val = recv ? recv->Get(isolate) : Undefined(isolate).As<Value>();

    std::vector<Local<Value>> local_argv;
    local_argv.reserve(argc > 0 ? argc : 0);
    for (int i = 0; i < argc; i++) {
        local_argv.push_back(argv[i] ? argv[i]->Get(isolate) : Undefined(isolate).As<Value>());
    }

    TryCatch try_catch(isolate);
    MaybeLocal<Value> maybe_result = fn_value.As<Function>()->Call(
        ctx, this_val, argc, local_argv.empty() ? nullptr : local_argv.data());

    if (try_catch.HasCaught()) {
        if (!try_catch.CanContinue()) return nullptr;
        return trackHandle(new Global<Value>(isolate, try_catch.Exception()));
    }
    if (maybe_result.IsEmpty()) return nullptr;

    *threw = false;
    return trackHandle(new Global<Value>(isolate, maybe_result.ToLocalChecked()));
}

/// v8_Function_CallCatching for an ECMAScript Call that does not invoke a
/// callback - the iterator protocol a WebIDL conversion runs (GetIterator,
/// IteratorStep, IteratorClose) - so that no kAuto microtask checkpoint
/// follows it when native code makes it at call depth 0 (NativeStepScope).
/// What it returns and owns is v8_Function_CallCatching's.
Global<Value>* v8_Function_CallCatchingNativeStep(
    Global<Context>* context,
    Global<Value>* function,
    Global<Value>* recv,
    int argc,
    Global<Value>** argv,
    bool* threw
) {
    Isolate* isolate = Isolate::GetCurrent();
    NativeStepScope native_step(isolate);
    return v8_Function_CallCatching(context, function, recv, argc, argv, threw);
}

/// Get(object, key) under a TryCatch, returning the completion the way
/// v8_Function_CallCatching does: the property's value with `*threw` false, or
/// the thrown value with `*threw` true. WebIDL's "call a user object's
/// operation" performs this Get at call time and rethrows what it throws - a
/// getter on `handleEvent` or `acceptNode` may throw. `object` must hold an
/// object. nullptr with `*threw` true only when there is nothing to report.
/// Every non-null result is a new Global the caller owns.
Global<Value>* v8_Object_GetCatching(
    Global<Context>* context,
    Global<Value>* object,
    const char* key,
    int key_len,
    bool* threw
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    *threw = true;

    if (!context || !object || object->IsEmpty() || !key) return nullptr;
    Local<Value> obj_value = object->Get(isolate);
    if (!obj_value->IsObject()) return nullptr;

    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);
    Local<String> name;
    if (!String::NewFromUtf8(isolate, key, NewStringType::kInternalized, key_len).ToLocal(&name)) return nullptr;

    TryCatch try_catch(isolate);
    MaybeLocal<Value> maybe_value = obj_value.As<Object>()->Get(ctx, name);
    if (try_catch.HasCaught()) {
        if (!try_catch.CanContinue()) return nullptr;
        return trackHandle(new Global<Value>(isolate, try_catch.Exception()));
    }
    if (maybe_value.IsEmpty()) return nullptr;

    *threw = false;
    return trackHandle(new Global<Value>(isolate, maybe_value.ToLocalChecked()));
}

/// Run `body(data)` with V8's automatic microtask execution suppressed.
///
/// The scope has to live on the C++ stack: SuppressMicrotaskExecutionScope
/// records its own ADDRESS as the isolate's last API entry
/// (ThreadLocalTop::IncrementCallDepth), which V8 compares against real stack
/// positions - a heap-allocated one would corrupt that. So instead of
/// handing the scope out, this holds it for the duration of a callback.
///
/// HTML reports a script's exception while the script's realm is still on the
/// execution context stack, so microtasks queued by error handlers wait for
/// the checkpoint in "clean up after running script" rather than running after
/// each handler, as V8's kAuto policy would from a native-code caller.
void v8_RunWithMicrotasksSuppressed(Isolate* isolate, void (*body)(void*), void* data) {
    Isolate::SuppressMicrotaskExecutionScope scope(isolate);
    body(data);
}

/// The function a callback-function value holds, taken by the impl that keeps
/// it (engine.takeCallbackFunction): its handle MOVES into a Global of the
/// taker's own, and `global` - the binding's, borrowed for the call - is left
/// empty, for the binding to dispose when the call returns. No V8 handle is
/// made: Global's move constructor hands the node over
/// (api_internal::MoveGlobalReference), and with it the node's class id, so a
/// count kept by class id moves too. Returns nullptr for a null or empty
/// handle - a value taken already.
///
/// What the adapter keys by the BOX moves with it: a realm tag is re-keyed to
/// the taker's box. A weak Global - its arm is keyed by its box, with a
/// finalizer that may be pending - is never moved: the taker gets a strong
/// Global of its own and the box keeps its arm for its owner's dispose. The
/// binding's own Globals carry neither (each comes from GetArgument or a
/// member's Get; tags and arms go on the taker's box), so these are what keep
/// the bookkeeping right should one ever be handed to a take.
Global<Value>* v8_Global_TakeOver(Global<Value>* global) {
    if (!global || global->IsEmpty()) return nullptr;
    if (global->IsWeak()) {
        Isolate* isolate = Isolate::GetCurrent();
        HandleScope handle_scope(isolate);
        return trackHandle(new Global<Value>(isolate, global->Get(isolate)));
    }
    // A move, not a new handle: nothing for the creation counters
    // (trackHandle). Snapshot mode resets every box in bulk, so it tracks this
    // one too.
    Global<Value>* own = new Global<Value>(std::move(*global));
    // The node moved, its class id with it. A weak-arm entry stays keyed by the
    // emptied box (a weak handle is never moved, above; only a `handle_survives`
    // record could be), so the flag must not follow the node; the realm tag is
    // re-keyed below, so its flag does.
    clearHandleFlag(static_cast<const void*>(own), kArmedFlag);
    if (g_snapshot_mode) g_snapshot_handles.push_back({own, resetGlobalHandle<Value>});
    if (realmTagCount().load(std::memory_order_acquire) != 0) {
        std::lock_guard<std::mutex> guard(realmTagLock());
        auto& tagged = realmTaggedHandles();
        auto it = tagged.find(static_cast<const void*>(global));
        if (it != tagged.end()) {
            const uintptr_t realm_key = it->second;
            tagged.erase(it);
            // One entry out, one in: realmTagCount is unchanged.
            tagged.emplace(static_cast<const void*>(own), realm_key);
        }
    }
    return own;
}

void v8_Value_Dispose(Global<Value>* value);

/// The binding's Global for a callback-function value, once the call that
/// converted it is over (interface.freeConvertedArg). Moved from by a take
/// (v8_Global_TakeOver), it is an empty box with nothing keyed by it - the
/// take re-keyed a realm tag, and never moves a weak Global - so it is
/// deleted without the registries v8_Value_Dispose consults, two locks and two
/// lookups per call (lane leaks7: `el.onclick = f` cost +4.96% instructions
/// through the general dispose). Untaken, it is disposed as any Global is.
void v8_Global_DisposeCallbackValue(Global<Value>* global) {
    if (!global) return;
    if (g_snapshot_mode) return;
    if (global->IsEmpty()) {
        delete global;
        return;
    }
    v8_Value_Dispose(global);
}

/// How many Globals carry a realm tag. For tests: the tag map's size.
size_t v8_Debug_RealmTaggedHandleCount() {
    return realmTagCount().load(std::memory_order_acquire);
}

/// Whether `global` carries a realm tag. For tests.
bool v8_Debug_IsRealmTagged(Global<Value>* global) {
    if (!global) return false;
    std::lock_guard<std::mutex> guard(realmTagLock());
    return realmTaggedHandles().count(static_cast<const void*>(global)) != 0;
}

/// The wrapper class id on `handle`'s node (0 for a null or empty handle):
/// the ledger's kind and the map flags. For tests.
uint16_t v8_Debug_HandleClassId(void* handle) {
    if (!handle) return 0;
    return static_cast<Global<Value>*>(handle)->WrapperClassId();
}

/// Write `class_id` on `handle`'s node. For tests (V8's reset of a freed
/// node's class id).
void v8_Debug_SetHandleClassId(void* handle, uint16_t class_id) {
    if (!handle) return;
    static_cast<Global<Value>*>(handle)->SetWrapperClassId(class_id);
}

/// The address of `handle`'s node in V8's global-handle table (the slot its
/// box points at), or null: tells a test whether V8 handed a freed node out
/// again. For tests.
void* v8_Debug_HandleNode(void* handle) {
    if (!handle) return nullptr;
    return *static_cast<void**>(handle);
}

/// A second, independently owned Global for the value `global` holds. Both
/// must be disposed. Returns nullptr for a null or empty handle.
Global<Value>* v8_Global_Clone(Global<Value>* global) {
    if (!global || global->IsEmpty()) return nullptr;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    return trackHandle(new Global<Value>(isolate, global->Get(isolate)));
}

/// Set promise.[[PromiseIsHandled]] to true (WebIDL "mark as handled"), so a
/// rejection nobody awaits is not reported as unhandled. No-op for a
/// non-promise.
void v8_Promise_MarkAsHandled(Global<Value>* promise) {
    if (!promise || promise->IsEmpty()) return;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> value = promise->Get(isolate);
    if (value->IsPromise()) value.As<Promise>()->MarkAsHandled();
}

// ============================================================================
// ArrayBuffer / ArrayBufferView primitives (Streams § 8.3, WebIDL buffer types)
// ============================================================================

/// View kinds shared with Zig (ffi.ViewKind). Order is part of the ABI: a new
/// kind is appended (kCraneFloat16 came after kCraneDataView).
enum CraneViewKind : int {
    kCraneInt8 = 0, kCraneUint8, kCraneUint8Clamped, kCraneInt16, kCraneUint16,
    kCraneInt32, kCraneUint32, kCraneFloat32, kCraneFloat64, kCraneBigInt64,
    kCraneBigUint64, kCraneDataView, kCraneFloat16,
};

struct CraneViewInfo {
    int kind;                    // CraneViewKind
    size_t byte_offset;          // [[ByteOffset]]
    size_t byte_length;          // [[ByteLength]]
    size_t length;               // [[ArrayLength]], or byte length for a DataView
    size_t buffer_byte_length;   // [[ViewedArrayBuffer]].[[ArrayBufferByteLength]]
    bool buffer_detached;        // IsDetachedBuffer([[ViewedArrayBuffer]])
    bool buffer_shared;          // [[ViewedArrayBuffer]] is a SharedArrayBuffer
};

static int craneViewKindOf(Local<Value> v) {
    if (v->IsDataView()) return kCraneDataView;
    if (v->IsInt8Array()) return kCraneInt8;
    if (v->IsUint8Array()) return kCraneUint8;
    if (v->IsUint8ClampedArray()) return kCraneUint8Clamped;
    if (v->IsInt16Array()) return kCraneInt16;
    if (v->IsUint16Array()) return kCraneUint16;
    if (v->IsInt32Array()) return kCraneInt32;
    if (v->IsUint32Array()) return kCraneUint32;
    if (v->IsFloat16Array()) return kCraneFloat16;
    if (v->IsFloat32Array()) return kCraneFloat32;
    if (v->IsFloat64Array()) return kCraneFloat64;
    if (v->IsBigInt64Array()) return kCraneBigInt64;
    if (v->IsBigUint64Array()) return kCraneBigUint64;
    return -1;
}

/// Describe `view`. False when it is not an ArrayBufferView of a known kind.
bool v8_ArrayBufferView_Describe(Global<Value>* view, CraneViewInfo* out) {
    if (!view || view->IsEmpty() || !out) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> v = view->Get(isolate);
    if (!v->IsArrayBufferView()) return false;
    int kind = craneViewKindOf(v);
    if (kind < 0) return false;
    Local<ArrayBufferView> abv = v.As<ArrayBufferView>();
    out->kind = kind;
    out->byte_offset = abv->ByteOffset();
    out->byte_length = abv->ByteLength();
    out->length = v->IsTypedArray() ? v.As<TypedArray>()->Length() : abv->ByteLength();
    Local<Object> buffer_obj = abv->Buffer();
    out->buffer_shared = buffer_obj->IsSharedArrayBuffer();
    if (buffer_obj->IsArrayBuffer()) {
        Local<ArrayBuffer> ab = buffer_obj.As<ArrayBuffer>();
        out->buffer_byte_length = ab->ByteLength();
        out->buffer_detached = ab->WasDetached();
    } else {
        out->buffer_byte_length = abv->ByteLength();
        out->buffer_detached = false;
    }
    return true;
}

/// view.[[ViewedArrayBuffer]] as a new Global the caller owns.
Global<Value>* v8_ArrayBufferView_Buffer(Global<Value>* view) {
    if (!view || view->IsEmpty()) return nullptr;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> v = view->Get(isolate);
    if (!v->IsArrayBufferView()) return nullptr;
    Local<Object> buffer = v.As<ArrayBufferView>()->Buffer();
    return trackHandle(new Global<Value>(isolate, buffer));
}

/// Construct(ctor-of-kind, « buffer, byteOffset, length ») - `length` in
/// elements, or in bytes for a DataView. New owned Global, or nullptr when
/// `buffer` is not an ArrayBuffer or the range does not fit.
Global<Value>* v8_ArrayBufferView_New(int kind, Global<Value>* buffer, size_t byte_offset, size_t length) {
    if (!buffer || buffer->IsEmpty()) return nullptr;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> b = buffer->Get(isolate);
    if (!b->IsArrayBuffer()) return nullptr;
    Local<ArrayBuffer> ab = b.As<ArrayBuffer>();
    if (ab->WasDetached()) return nullptr;
    static const size_t element_sizes[] = {1, 1, 1, 2, 2, 4, 4, 4, 8, 8, 8, 1, 2};
    if (kind < 0 || kind > kCraneFloat16) return nullptr;
    size_t element_size = element_sizes[kind];
    if (byte_offset % element_size != 0) return nullptr;
    if (byte_offset > ab->ByteLength() || length > (ab->ByteLength() - byte_offset) / element_size) return nullptr;
    Local<Value> result;
    switch (kind) {
        case kCraneInt8: result = Int8Array::New(ab, byte_offset, length); break;
        case kCraneUint8: result = Uint8Array::New(ab, byte_offset, length); break;
        case kCraneUint8Clamped: result = Uint8ClampedArray::New(ab, byte_offset, length); break;
        case kCraneInt16: result = Int16Array::New(ab, byte_offset, length); break;
        case kCraneUint16: result = Uint16Array::New(ab, byte_offset, length); break;
        case kCraneInt32: result = Int32Array::New(ab, byte_offset, length); break;
        case kCraneUint32: result = Uint32Array::New(ab, byte_offset, length); break;
        case kCraneFloat32: result = Float32Array::New(ab, byte_offset, length); break;
        case kCraneFloat64: result = Float64Array::New(ab, byte_offset, length); break;
        case kCraneBigInt64: result = BigInt64Array::New(ab, byte_offset, length); break;
        case kCraneBigUint64: result = BigUint64Array::New(ab, byte_offset, length); break;
        case kCraneDataView: result = DataView::New(ab, byte_offset, length); break;
        case kCraneFloat16: result = Float16Array::New(ab, byte_offset, length); break;
        default: return nullptr;
    }
    return trackHandle(new Global<Value>(isolate, result));
}

/// AllocateArrayBuffer(%ArrayBuffer%, byteLength). New owned Global, or
/// nullptr when the allocation fails (the caller reports a RangeError).
Global<Value>* v8_ArrayBuffer_Allocate(size_t byte_length) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> ab;
    if (!ArrayBuffer::MaybeNew(isolate, byte_length).ToLocal(&ab)) return nullptr;
    return trackHandle(new Global<Value>(isolate, ab));
}

/// Streams § 8.3 CanTransferArrayBuffer(O), for an ArrayBuffer `buffer`.
bool v8_ArrayBuffer_CanTransfer(Global<Value>* buffer) {
    if (!buffer || buffer->IsEmpty()) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> b = buffer->Get(isolate);
    if (!b->IsArrayBuffer()) return false;
    Local<ArrayBuffer> ab = b.As<ArrayBuffer>();
    return !ab->WasDetached() && ab->IsDetachable();
}

/// Streams § 8.3 TransferArrayBuffer(O): detach `buffer` and return a new
/// ArrayBuffer (owned Global) over the same data block. nullptr when it
/// cannot be transferred - detached, not detachable, or not an ArrayBuffer.
Global<Value>* v8_ArrayBuffer_Transfer(Global<Value>* buffer) {
    if (!buffer || buffer->IsEmpty()) return nullptr;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> b = buffer->Get(isolate);
    if (!b->IsArrayBuffer()) return nullptr;
    Local<ArrayBuffer> ab = b.As<ArrayBuffer>();
    if (ab->WasDetached() || !ab->IsDetachable()) return nullptr;
    std::shared_ptr<BackingStore> store = ab->GetBackingStore();
    if (ab->Detach(Local<Value>()).IsNothing()) return nullptr;
    Local<ArrayBuffer> transferred = ArrayBuffer::New(isolate, store);
    return trackHandle(new Global<Value>(isolate, transferred));
}

/// Data pointer and byte length of an ArrayBuffer. False when detached or not
/// an ArrayBuffer. The pointer is valid until the buffer is detached.
bool v8_ArrayBuffer_Bytes(Global<Value>* buffer, void** data, size_t* byte_length) {
    if (!buffer || buffer->IsEmpty()) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> b = buffer->Get(isolate);
    if (!b->IsArrayBuffer()) return false;
    Local<ArrayBuffer> ab = b.As<ArrayBuffer>();
    if (ab->WasDetached()) return false;
    *data = ab->Data();
    *byte_length = ab->ByteLength();
    return true;
}

/// HTML "queue a microtask": run callback(data) from the isolate's microtask
/// queue. The callback owns `data`.
typedef void (*ZigMicrotaskCallback)(void* data);

void v8_Isolate_QueueMicrotask(Isolate* isolate, ZigMicrotaskCallback callback, void* data) {
    struct Task { ZigMicrotaskCallback callback; void* data; };
    auto* task = new Task{callback, data};
    isolate->EnqueueMicrotask([](void* raw) {
        auto* t = static_cast<Task*>(raw);
        ZigMicrotaskCallback cb = t->callback;
        void* d = t->data;
        delete t;
        cb(d);
    }, task);
}

/// Called once, with the settled value (a new Global the callee owns) and
/// whether the promise rejected.
typedef void (*ZigReactionCallback)(void* data, Global<Value>* value, bool rejected);

// A reaction's holder: the [[data]] both reaction functions share, a JS array
// the collector frees with them. Slot 0 is the host's record (an External),
// slot 1 the callback; disarming the reaction clears slot 0. Nothing on the C++
// heap outlives the call that made it, so nothing here can dangle: a reaction
// function run after its reaction ended - another realm's promise settling it
// after this realm's end - finds slot 0 cleared and does nothing.
static constexpr uint32_t kReactionData = 0;
static constexpr uint32_t kReactionCallback = 1;

static void zigReactionTrampoline(const FunctionCallbackInfo<Value>& info, bool rejected) {
    Isolate* isolate = info.GetIsolate();
    HandleScope scope(isolate);
    Local<Context> ctx = isolate->GetCurrentContext();
    if (!info.DataV2().As<Value>()->IsArray()) return;
    Local<Array> holder = info.DataV2().As<Value>().As<Array>();
    Local<Value> data_slot;
    Local<Value> callback_slot;
    if (!holder->Get(ctx, kReactionData).ToLocal(&data_slot) || !data_slot->IsExternal()) return;
    if (!holder->Get(ctx, kReactionCallback).ToLocal(&callback_slot) || !callback_slot->IsExternal()) return;
    void* data = data_slot.As<External>()->Value(kCraneExternalTag);
    auto callback = reinterpret_cast<ZigReactionCallback>(callback_slot.As<External>()->Value(kCraneExternalTag));
    // A promise settles once and `then` registered exactly one reaction, so the
    // other function sharing this holder never runs; disarm it anyway before
    // calling out, so nothing can reach the record the callback frees.
    if (holder->Set(ctx, kReactionData, Undefined(isolate)).IsNothing()) return;
    Local<Value> arg = info.Length() > 0 ? info[0] : Undefined(isolate).As<Value>();
    Global<Value>* value = trackHandle(new Global<Value>(isolate, arg));
    callback(data, value, rejected);
}

/// WebIDL "react to" a promise: promise.then(onFulfilled, onRejected), where
/// both call `callback(data, value, rejected)`. Exactly one of them runs,
/// exactly once - unless the reaction is disarmed first (its holder's
/// `kReactionData` cleared, `v8_Array_ClearElement`). Returns false - and `callback` never runs -
/// when the reaction could not be attached (`promise` is not a promise).
///
/// `*holder_out` receives the reaction's holder (see `kReactionData`) as a
/// new Global the caller owns - the handle to disarm it by. Strong as made:
/// the caller weakens it (a strong one would keep the realm alive) or
/// disposes it.
///
/// The promise `then` derives is marked handled: nothing observes it, and a
/// throw escaping `callback` must not surface as an unhandled rejection.
/// Uses Function::New rather than a FunctionTemplate per reaction - templates
/// are cached per context for the context's lifetime.
bool v8_Promise_React(
    Global<Context>* context,
    Global<Value>* promise,
    ZigReactionCallback callback,
    void* data,
    Global<Value>** holder_out
) {
    if (holder_out) *holder_out = nullptr;
    if (!context || !promise || promise->IsEmpty() || !callback || !holder_out) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);

    Local<Value> value = promise->Get(isolate);
    if (!value->IsPromise()) return false;

    Local<Value> slots[] = {
        External::New(isolate, data, kCraneExternalTag),
        External::New(isolate, reinterpret_cast<void*>(callback), kCraneExternalTag),
    };
    Local<Array> holder = Array::New(isolate, slots, 2);

    Local<Function> on_fulfilled;
    Local<Function> on_rejected;
    if (!Function::New(ctx, [](const FunctionCallbackInfo<Value>& info) {
            zigReactionTrampoline(info, false);
        }, holder, 1).ToLocal(&on_fulfilled) ||
        !Function::New(ctx, [](const FunctionCallbackInfo<Value>& info) {
            zigReactionTrampoline(info, true);
        }, holder, 1).ToLocal(&on_rejected)) {
        return false;
    }

    Local<Promise> derived;
    if (!value.As<Promise>()->Then(ctx, on_fulfilled, on_rejected).ToLocal(&derived)) {
        return false;
    }
    derived->MarkAsHandled();
    *holder_out = trackHandle(new Global<Value>(isolate, holder));
    return true;
}

/// Set `array[index]` to undefined, in the array's own creation context -
/// how a reaction (`kReactionData`) or an asynchronous iterator's state is
/// disarmed when its realm ends. `array` BORROWED; an empty handle (the
/// collector took the array) or a value that is no array is left alone. The
/// element is an own data element, so no setter - no script - runs.
void v8_Array_ClearElement(Global<Value>* array, uint32_t index) {
    if (!array || array->IsEmpty()) return;
    // No isolate entered (the manager's own end, after its agents): nothing
    // can run script to reach the array either.
    Isolate* isolate = Isolate::GetCurrent();
    if (!isolate) return;
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);
    Local<Value> value = array->Get(isolate);
    if (!value->IsArray()) return;
    Local<Object> object = value.As<Object>();
    // The array's own context: alive for as long as the array is.
    Local<Context> ctx;
    if (!object->GetCreationContext(isolate).ToLocal(&ctx)) return;
    Context::Scope context_scope(ctx);
    if (object->Set(ctx, index, Undefined(isolate)).IsNothing()) return;
}

/// Compile an ES module with TryCatch error handling
V8ModuleCompileResult* v8_Module_Compile_Safe(
    Global<Context>* context,
    Global<String>* source,
    Global<String>* resource_name
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<String> local_source = source->Get(isolate);
    Local<String> local_name = resource_name ? resource_name->Get(isolate) : String::Empty(isolate);
    
    V8ModuleCompileResult* result = new V8ModuleCompileResult();
    result->module = nullptr;
    result->error = nullptr;
    
    // Create ScriptOrigin for module (is_module = true)
    ScriptOrigin origin(
        local_name,        // resource name
        0,                 // line offset
        0,                 // column offset
        false,             // is_shared_cross_origin
        -1,                // script id
        Local<Value>(),    // source_map_url
        false,             // is_opaque
        false,             // is_wasm
        true               // is_module
    );
    
    ScriptCompiler::Source script_source(local_source, origin);
    
    TryCatch try_catch(isolate);
    
    MaybeLocal<Module> maybe_module = ScriptCompiler::CompileModule(isolate, &script_source);
    
    if (try_catch.HasCaught()) {
        result->error = extractException(isolate, &try_catch);
        return result;
    }
    
    if (maybe_module.IsEmpty()) {
        result->error = new V8ErrorInfo();
        result->error->has_error = true;
        result->error->message = strdup("Module compilation failed");
        result->error->stack_trace = nullptr;
        result->error->line_number = -1;
        result->error->column_number = -1;
        result->error->source_line = nullptr;
        result->error->resource_name = nullptr;
        return result;
    }
    
    Local<Module> module = maybe_module.ToLocalChecked();
    result->module = trackHandle(new Global<Module>(isolate, module));
    return result;
}

/// Free a V8ModuleCompileResult
void v8_FreeModuleCompileResult(V8ModuleCompileResult* result) {
    if (!result) return;
    // Note: module is owned by caller if non-null
    if (result->error) v8_FreeErrorInfo(result->error);
    delete result;
}

/// Evaluate a module with TryCatch error handling
V8ModuleEvaluateResult* v8_Module_Evaluate_Safe(Global<Context>* context, Global<Module>* module) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<Module> local_module = module->Get(isolate);
    
    V8ModuleEvaluateResult* result = new V8ModuleEvaluateResult();
    result->value = nullptr;
    result->error = nullptr;
    
    TryCatch try_catch(isolate);

    // v8::Module::Evaluate CHECKs on a module that was never instantiated; see
    // v8_Module_IsGraphAsync for what a failed CHECK costs.
    if (local_module->GetStatus() < Module::kInstantiated) {
        result->error = new V8ErrorInfo();
        result->error->has_error = true;
        result->error->message = strdup("Module was not instantiated");
        result->error->stack_trace = nullptr;
        result->error->line_number = -1;
        result->error->column_number = -1;
        result->error->source_line = nullptr;
        result->error->resource_name = nullptr;
        return result;
    }

    MaybeLocal<Value> maybe_result = local_module->Evaluate(local_context);
    
    if (try_catch.HasCaught()) {
        result->error = extractException(isolate, &try_catch);
        return result;
    }
    
    if (maybe_result.IsEmpty()) {
        result->error = new V8ErrorInfo();
        result->error->has_error = true;
        result->error->message = strdup("Module evaluation failed");
        result->error->stack_trace = nullptr;
        result->error->line_number = -1;
        result->error->column_number = -1;
        result->error->source_line = nullptr;
        result->error->resource_name = nullptr;
        return result;
    }
    
    Local<Value> value = maybe_result.ToLocalChecked();
    result->value = trackHandle(new Global<Value>(isolate, value));
    return result;
}

/// Free a V8ModuleEvaluateResult
void v8_FreeModuleEvaluateResult(V8ModuleEvaluateResult* result) {
    if (!result) return;
    // Note: value is owned by caller if non-null
    if (result->error) v8_FreeErrorInfo(result->error);
    delete result;
}

// ============================================================================
// Snapshot Mode Control
// ============================================================================

/// Enable snapshot mode - start tracking Global handles for later cleanup
void v8_Snapshot_EnableMode() {
    g_snapshot_mode = true;
    g_snapshot_handles.clear();
}

/// Disable snapshot mode and clear tracked handles
void v8_Snapshot_DisableMode() {
    g_snapshot_mode = false;
    g_snapshot_handles.clear();
}

/// Clear all tracked Global handles - MUST be called BEFORE exiting context/isolate
///
/// V8 requires no outstanding Global handles when creating a snapshot.
/// This MUST be called while still in the context/isolate, not after exiting.
void v8_Snapshot_ClearGlobalHandles() {
    for (auto& entry : g_snapshot_handles) {
        entry.reset_fn(entry.handle);
    }
    g_snapshot_handles.clear();
}

// ============================================================================
// Platform Management
// ============================================================================

/// Set V8 command-line flags from a string
///
/// This must be called BEFORE V8::Initialize(). Use this to configure V8
/// behavior like hash seeding, snapshot options, etc.
///
/// Example flags:
/// - "--hash-seed=0" - Use deterministic hash seed (may help with snapshots)
/// - "--no-lazy" - Disable lazy compilation
///
/// Prefer v8_Platform_Start(flags), which sets them as part of the start:
/// set here, they are not the start's (v8_Platform_StartFlags does not
/// name them), and after the start V8 refuses them fatally. Taken under the
/// start's lock, so a write never overlaps another thread's start reading
/// the flags.
///
/// @param flags - Null-terminated string of V8 command-line flags
void v8_SetFlagsFromString(const char* flags) {
    if (flags) {
        std::lock_guard<std::mutex> guard(g_platform.mutex);
        g_platform.flag_writes += 1;
        V8::SetFlagsFromString(flags);
    }
}

/// How many times v8_SetFlagsFromString has set flags, in this process: the
/// flags of a start (v8_Platform_Start) are not counted. Diagnostics only
/// (the adapter's `flag_writes` counter).
int64_t v8_Platform_FlagWrites() {
    std::lock_guard<std::mutex> guard(g_platform.mutex);
    return g_platform.flag_writes;
}

// Foreground tasks retain their wake target, never their isolate. The platform
// still owns execution; this layer records deadlines and posts a loop wake.
// V8 TaskRunner's public contract permits posting from any thread, but obtaining
// a runner only on the foreground thread. Node's node_platform.cc uses the same
// separation of task ownership, queue wake and delayed-work deadlines.
struct ForegroundTasks {
    using Clock = std::chrono::steady_clock;
    std::mutex mutex;
    bool closed = false;
    void* sink = nullptr;
    void (*wake)(void*) = nullptr;
    void (*release)(void*) = nullptr;
    std::multiset<Clock::time_point> deadlines;

    bool attach(void* target, void (*notify)(void*), void (*drop)(void*)) {
        std::lock_guard<std::mutex> guard(mutex);
        if (closed || sink) return false;
        sink = target;
        wake = notify;
        release = drop;
        if (!deadlines.empty()) wake(sink);
        return true;
    }
    ~ForegroundTasks() { close(); }
    void close() {
        void* owned;
        {
            std::lock_guard<std::mutex> guard(mutex);
            if (closed) return;
            closed = true;
            owned = sink;
            sink = nullptr;
        }
        if (owned) release(owned);
    }
    bool nextDelay(uint64_t* nanoseconds) {
        std::lock_guard<std::mutex> guard(mutex);
        if (closed || deadlines.empty()) return false;
        const auto remaining = *deadlines.begin() - Clock::now();
        *nanoseconds = remaining <= Clock::duration::zero() ? 0 :
            static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::nanoseconds>(remaining).count());
        return true;
    }
};

class ForegroundTask final : public Task {
 public:
    ForegroundTask(std::shared_ptr<ForegroundTasks> state, std::unique_ptr<Task> task,
                   std::multiset<ForegroundTasks::Clock::time_point>::iterator deadline)
        : state_(std::move(state)), task_(std::move(task)), deadline_(deadline) {}
    ~ForegroundTask() override {
        std::lock_guard<std::mutex> guard(state_->mutex);
        removeDeadline();
    }
    void Run() override {
        {
            std::lock_guard<std::mutex> guard(state_->mutex);
            removeDeadline();
            if (state_->closed) return;
        }
        // Run and close are both foreground-only; no close can race this call.
        task_->Run();
    }
 private:
    void removeDeadline() {
        if (!registered_) return;
        state_->deadlines.erase(deadline_);
        registered_ = false;
    }
    std::shared_ptr<ForegroundTasks> state_;
    std::unique_ptr<Task> task_;
    std::multiset<ForegroundTasks::Clock::time_point>::iterator deadline_;
    bool registered_ = true;
};

class ForegroundTaskRunner final : public TaskRunner {
 public:
    ForegroundTaskRunner(std::shared_ptr<ForegroundTasks> state, std::shared_ptr<TaskRunner> runner)
        : state_(std::move(state)), runner_(std::move(runner)) {}
    bool IdleTasksEnabled() override { return runner_->IdleTasksEnabled(); }
    bool NonNestableTasksEnabled() const override { return runner_->NonNestableTasksEnabled(); }
    bool NonNestableDelayedTasksEnabled() const override { return runner_->NonNestableDelayedTasksEnabled(); }
 protected:
    void PostTaskImpl(std::unique_ptr<Task> task, const SourceLocation& location) override {
        post(std::move(task), 0, false, false, location);
    }
    void PostNonNestableTaskImpl(std::unique_ptr<Task> task, const SourceLocation& location) override {
        post(std::move(task), 0, false, true, location);
    }
    void PostDelayedTaskImpl(std::unique_ptr<Task> task, double delay, const SourceLocation& location) override {
        post(std::move(task), delay, true, false, location);
    }
    void PostNonNestableDelayedTaskImpl(std::unique_ptr<Task> task, double delay, const SourceLocation& location) override {
        post(std::move(task), delay, true, true, location);
    }
    void PostIdleTaskImpl(std::unique_ptr<IdleTask> task, const SourceLocation& location) override {
        // The DefaultPlatform was created without idle tasks. Keep its contract;
        // an idle task cannot become a wake that makes an idle loop busy.
        assert(!runner_->IdleTasksEnabled());
        std::lock_guard<std::mutex> guard(state_->mutex);
        if (!state_->closed) runner_->PostIdleTask(std::move(task), location);
    }
 private:
    void post(std::unique_ptr<Task> task, double delay, bool delayed, bool nonnestable,
              const SourceLocation& location) {
        using Clock = ForegroundTasks::Clock;
        const auto now = Clock::now();
        const double maximum = std::chrono::duration<double>(Clock::time_point::max() - now).count();
        const double seconds = std::max(0.0, std::min(delay, maximum / 2));
        const auto deadline = now + std::chrono::duration_cast<Clock::duration>(std::chrono::duration<double>(seconds));
        std::lock_guard<std::mutex> guard(state_->mutex);
        if (state_->closed) return;
        const auto entry = state_->deadlines.insert(deadline);
        auto wrapped = std::make_unique<ForegroundTask>(state_, std::move(task), entry);
        // close holds the same lock before DefaultPlatform's isolate shutdown,
        // so an open runner accepts the task rather than destroying it here.
        if (delayed && nonnestable) runner_->PostNonNestableDelayedTask(std::move(wrapped), seconds, location);
        else if (delayed) runner_->PostDelayedTask(std::move(wrapped), seconds, location);
        else if (nonnestable) runner_->PostNonNestableTask(std::move(wrapped), location);
        else runner_->PostTask(std::move(wrapped), location);
        if (state_->sink) state_->wake(state_->sink);
    }
    std::shared_ptr<ForegroundTasks> state_;
    std::shared_ptr<TaskRunner> runner_;
};

class CranePlatform final : public Platform {
 public:
    /// `made_before_threads`: made by v8_Platform_InitializeBeforeThreadCreation,
    /// on the process's main thread before it made any other thread.
    explicit CranePlatform(bool made_before_threads)
        : backend_(platform::NewDefaultPlatform()), made_before_threads_(made_before_threads) {}
    Platform* backend() { return backend_.get(); }
    PageAllocator* GetPageAllocator() override { return backend_->GetPageAllocator(); }
    /// V8's thread isolation (13.1.203 src/common/code-memory-access.cc
    /// ThreadIsolation::Initialize): with an allocator whose memory
    /// protection key is valid - x86-64 Linux on a CPU with PKU - V8 tags
    /// its trusted memory with that key (the JSDispatchTable,
    /// src/common/segmented-table-inl.h WriteProtectMemory) and reads it
    /// only with access to the key. libplatform's DefaultThreadIsolatedAllocator
    /// allocates the key inside NewDefaultPlatform, with pkey_alloc(0,
    /// PKEY_DISABLE_WRITE): the calling thread gets read access, threads it
    /// creates later inherit it, and every thread that already existed keeps
    /// Linux's initial PKRU, which denies all access to keys 1-15 - its first
    /// read of the table faults (SEGV in
    /// JSDispatchTable::PreAllocatedEntryNeedsInitialization: every
    /// "two Browsers on two threads" test on x86-64 Linux, lane linux1).
    ///
    /// So V8 gets the allocator only from a platform made before any thread,
    /// as Chromium does it: content main calls
    /// gin::GetThreadIsolationData().InitializeBeforeThreadCreation() before
    /// it starts a thread, and gin's V8Platform::GetThreadIsolatedAllocator
    /// returns nullptr until that ran (gin/v8_platform.cc,
    /// gin/thread_isolation.cc). A platform made by V8's start on whichever
    /// thread came first gives none - V8 then runs without thread isolation
    /// (ThreadIsolation::Enabled() is false, WriteProtectMemory does
    /// nothing) and no thread faults - as Node's NodePlatform, which never
    /// overrides GetThreadIsolatedAllocator, runs V8 always (src/node_platform.h).
    ThreadIsolatedAllocator* GetThreadIsolatedAllocator() override {
        return made_before_threads_ ? backend_->GetThreadIsolatedAllocator() : nullptr;
    }
    /// V8 15.7's zero segment (v8-platform.h: the process's segment from
    /// address 0, read-only or no access, never reused): the backend's answer,
    /// as every other question is forwarded - libplatform answers 0 unless
    /// PartitionAlloc reserved one (S7, tmp/plans/v8-update-plan.md 2.2).
    size_t GetZeroSegmentSize() override { return backend_->GetZeroSegmentSize(); }
    void OnCriticalMemoryPressure() override { backend_->OnCriticalMemoryPressure(); }
    int NumberOfWorkerThreads() override { return backend_->NumberOfWorkerThreads(); }
    std::unique_ptr<ScopedBoostablePriority> CreateBoostablePriorityScope() override { return backend_->CreateBoostablePriorityScope(); }
    std::shared_ptr<TaskRunner> GetForegroundTaskRunner(Isolate*, TaskPriority) override;
    bool IdleTasksEnabled(Isolate* isolate) override { return backend_->IdleTasksEnabled(isolate); }
    std::unique_ptr<ScopedBlockingCall> CreateBlockingScope(BlockingType type) override { return backend_->CreateBlockingScope(type); }
    // V8's own clock (GC heuristics, compile timing): the backend's, always.
    // A host's clock (engine.AgentOptions.clock) is what a page reads - Date -
    // not what the engine schedules its own work by.
    double MonotonicallyIncreasingTime() override { return backend_->MonotonicallyIncreasingTime(); }
    // The wall clock Date reads (13.1 JSDate::CurrentTimeValue reads
    // CurrentClockTimeMilliseconds): the current isolate's clock when its
    // agent was given one, else the backend's - defined below IsolateData.
    double CurrentClockTimeMillis() override;
    int64_t CurrentClockTimeMilliseconds() override;
    double CurrentClockTimeMillisecondsHighResolution() override;
    StackTracePrinter GetStackTracePrinter() override { return backend_->GetStackTracePrinter(); }
    TracingController* GetTracingController() override { return backend_->GetTracingController(); }
    void DumpWithoutCrashing() override { backend_->DumpWithoutCrashing(); }
    HighAllocationThroughputObserver* GetHighAllocationThroughputObserver() override { return backend_->GetHighAllocationThroughputObserver(); }
 protected:
    std::unique_ptr<JobHandle> CreateJobImpl(TaskPriority priority, std::unique_ptr<JobTask> job,
                                           const SourceLocation& location) override {
        return backend_->CreateJob(priority, std::move(job), location);
    }
    // The backend's public entry points, which reach its Impl overrides with
    // the priority (the Call*OnWorkerThread forms are deprecated in 15.7,
    // "Use PostTaskOnWorkerThread instead", and the delayed one dropped the
    // priority).
    void PostTaskOnWorkerThreadImpl(TaskPriority priority, std::unique_ptr<Task> task,
                                    const SourceLocation& location) override {
        backend_->PostTaskOnWorkerThread(priority, std::move(task), location);
    }
    void PostDelayedTaskOnWorkerThreadImpl(TaskPriority priority, std::unique_ptr<Task> task,
                                           double delay, const SourceLocation& location) override {
        backend_->PostDelayedTaskOnWorkerThread(priority, std::move(task), delay, location);
    }
 private:
    std::unique_ptr<Platform> backend_;
    bool made_before_threads_;
};

static Platform* defaultPlatform() {
    return static_cast<CranePlatform*>(g_platform.platform)->backend();
}

/// The per-isolate seed V8 asks for (defined with IsolateData, below).
static bool craneEntropySource(unsigned char* buffer, size_t length);

/// The address space cppgc's cage asks for (cppgc::InitializeProcess): 16 GB,
/// as Chromium's on desktop (gin/cppgc.cc kCageSize).
static constexpr size_t kCppgcCageBytes = static_cast<size_t>(16) * 1024 * 1024 * 1024;

/// v8_Platform_Start's answer (ffi.zig PlatformStart).
enum PlatformStartResult : int {
    /// v8_Platform_Dispose ran: V8 cannot start again in this process.
    kPlatformDisposed = -2,
    /// V8 had started with other flags than the caller's, which are NOT in
    /// effect: V8's flags freeze when it starts. The caller reports it.
    kPlatformStartedWithOtherFlags = -1,
    /// V8 had started, with the caller's flags, or the caller named none.
    kPlatformAlreadyStarted = 0,
    /// This call started V8, with the caller's flags applied first.
    kPlatformStartedNow = 1,
};

/// Start V8 - `flags` (null: none), then its platform - unless it has
/// started: exactly once per process, from any thread, by whichever caller
/// is first. A caller that comes while the start is under way waits for it,
/// so every caller returns with V8 started; one whose `flags` are not the
/// start's is told so (kPlatformStartedWithOtherFlags), never silently
/// given the other set.
///
/// Chromium starts V8 this way - once, the flags set inside the start,
/// before V8::InitializePlatform (gin/v8_initializer.cc
/// V8Initializer::Initialize) - but from one thread, at process start,
/// behind an unlocked bool, and every IsolateHolder CHECKs that start came
/// first (gin/isolate_holder.cc). Crane's host starts it the same way
/// (engine.initializeEngine, from crane.Process.init), but an isolate made
/// before that - a test's, a tool's (v8_Isolate_New) - may be first, on any
/// thread, so the start is taken under a lock. It was an unlocked bool here
/// too: two threads making a process's first isolates at once both read it
/// false and the second V8::InitializePlatform aborted ("Wrong
/// initialization order": tests/v8/platform_start_once_test.zig).
int v8_Platform_Start(const char* flags) {
    if (!g_platform.started.load(std::memory_order_acquire)) {
        std::lock_guard<std::mutex> guard(g_platform.mutex);
        if (g_platform.disposed) return kPlatformDisposed;
        if (!g_platform.started.load(std::memory_order_relaxed)) {
            // Flags first: V8 reads them from InitializePlatform on and
            // freezes them in Initialize (crbug.com/v8/11043).
            if (flags && *flags) V8::SetFlagsFromString(flags);
            // Per-isolate seeds (engine.AgentOptions.random_seed), before V8
            // makes its first random number generator; an isolate without
            // one gets V8's own entropy, as before (craneEntropySource).
            V8::SetEntropySource(craneEntropySource);
            V8::InitializeICUDefaultLocation("");
            V8::InitializeExternalStartupData("");
            // The process start's platform when it made one
            // (v8_Platform_InitializeBeforeThreadCreation), else one made
            // here, on this thread, which hands V8 no thread-isolated
            // allocator (CranePlatform::GetThreadIsolatedAllocator).
            if (!g_platform.platform) g_platform.platform = new CranePlatform(false);
            V8::InitializePlatform(g_platform.platform);
            // cppgc's process start, before any agent's C++ heap is made
            // (CppHeap::Create - every isolate this file makes has one,
            // IsolateData::cpp_heap): the GC info table and the cage every
            // C++ heap of the process allocates in. V8 does not do it itself
            // (13.1.203 calls cppgc::InitializeProcess nowhere in src/); an
            // embedder does, once, with V8's platform's page allocator -
            // Chromium in gin::InitializeCppgcFromV8Platform (gin/cppgc.cc),
            // V8's cctest after InitializePlatform (test/cctest/cctest.cc).
            // Without it CppHeap::Create reads a CagedHeap that does not exist.
            // The cage is Chromium's desktop size, 16 GB of address space -
            // reserved, not committed; out/ios-arm64's smaller cage clamps it
            // (cppgc/platform.h: "clamped to minimum and maximum values").
            // The state is V8's own, process-wide by design, under this lock.
            cppgc::InitializeProcess(g_platform.platform->GetPageAllocator(), kCppgcCageBytes);
            V8::Initialize();
            g_platform.flags = flags ? flags : "";
            g_platform.started.store(true, std::memory_order_release);
            return kPlatformStartedNow;
        }
    }
    if (!flags) return kPlatformAlreadyStarted;
    // Written by the start before it published `started`, never after.
    return g_platform.flags == flags ? kPlatformAlreadyStarted : kPlatformStartedWithOtherFlags;
}

/// The engine protocol's initializeBeforeThreadCreation: make V8's platform
/// now - and with it the memory protection key of V8's thread isolation,
/// which libplatform allocates in NewDefaultPlatform - so that every thread
/// the process creates after this inherits access to it, and V8 gets the
/// thread-isolated allocator when it starts (CranePlatform). Called first in
/// a process's main, on its main thread, before it creates any thread. V8
/// does not start here (v8_Platform_Start does, on any thread, later): only
/// the platform object is made. Does nothing once a platform exists or V8
/// was disposed, so a late call cannot replace the one V8 runs on.
void v8_Platform_InitializeBeforeThreadCreation() {
    std::lock_guard<std::mutex> guard(g_platform.mutex);
    if (g_platform.disposed || g_platform.platform) return;
    g_platform.platform = new CranePlatform(true);
}

/// Whether V8 runs - or will run, once it starts - with thread isolation:
/// its platform hands V8 a thread-isolated allocator. Only a platform made
/// before any thread does (v8_Platform_InitializeBeforeThreadCreation), and
/// only where libplatform could allocate a memory protection key (x86-64
/// Linux on a CPU with PKU); false before any platform exists. For tests.
bool v8_Platform_HasThreadIsolation() {
    std::lock_guard<std::mutex> guard(g_platform.mutex);
    return g_platform.platform && g_platform.platform->GetThreadIsolatedAllocator() != nullptr;
}

/// The flags V8's start applied ("" for none), or null before it started.
/// Lives as long as the process.
const char* v8_Platform_StartFlags() {
    return g_platform.started.load(std::memory_order_acquire) ? g_platform.flags.c_str() : nullptr;
}

/// Write a V8 heap snapshot of |isolate| to |path| as JSON (the format
/// Chrome DevTools reads), for finding what retains memory: a leaked Global
/// shows up as a path from the "(Global handles)" root. Diagnosis only - it
/// walks the whole heap. Returns whether the file was written.
bool v8_Debug_WriteHeapSnapshot(Isolate* isolate, const char* path) {
    if (!isolate || !path) return false;
    FILE* file = fopen(path, "w");
    if (!file) return false;
    class FileStream final : public OutputStream {
     public:
        explicit FileStream(FILE* f) : f_(f) {}
        void EndOfStream() override {}
        WriteResult WriteAsciiChunk(char* data, int size) override {
            return fwrite(data, 1, static_cast<size_t>(size), f_) == static_cast<size_t>(size) ? kContinue : kAbort;
        }
     private:
        FILE* f_;
    };
    // TakeHeapSnapshot collects first: the collecting isolate is the current
    // one (collectingRecord).
    CollectingScope collecting(isolate);
    HandleScope scope(isolate);
    const HeapSnapshot* snapshot = isolate->GetHeapProfiler()->TakeHeapSnapshot();
    FileStream stream(file);
    snapshot->Serialize(&stream, HeapSnapshot::kJSON);
    const_cast<HeapSnapshot*>(snapshot)->Delete();
    fclose(file);
    return true;
}

/// Whether Atomics.wait() may block on |isolate| - HTML's [[CanBlock]] for
/// the agent the isolate hosts.
void v8_Isolate_SetAllowAtomicsWait(Isolate* isolate, bool allow) {
    if (isolate) isolate->SetAllowAtomicsWait(allow);
}

/// Run one foreground task V8 has posted to the platform for |isolate|, if
/// one is due, and report whether one ran. V8 finishes an asynchronous
/// WebAssembly compile, and runs FinalizationRegistry cleanup, through such
/// tasks; an embedder that never pumps never sees them. Never blocks. Call
/// with |isolate| entered, as d8's ProcessMessages does.
/// Whether V8 has background work under way for |isolate| that will post a
/// foreground task when it ends - an asynchronous WebAssembly compile, say.
/// d8 keeps its message loop waiting while this is true (CompleteMessageLoop).
bool v8_Isolate_HasPendingBackgroundTasks(Isolate* isolate) {
    return isolate && isolate->HasPendingBackgroundTasks();
}

/// Run one foreground task V8 posted for |isolate|, if any (the comment
/// above v8_Isolate_HasPendingBackgroundTasks).
///
/// The pump is also the agent's safe point for its collected wrappers'
/// finalizers (`runQueuedFinalizers`): V8's task has returned - a collection
/// it finished only queued them, in its first pass - so they run here,
/// before the caller's microtask checkpoint. Answers whether a task or a
/// finalizer ran.
bool v8_Platform_PumpMessageLoop(Isolate* isolate) {
    if (!g_platform.started.load(std::memory_order_acquire) || !isolate) return false;
    // V8's tasks may finish a collection (IncrementalMarkingJob::Task ->
    // AdvanceAndFinalizeIfComplete): the collecting isolate is the current
    // one (collectingRecord).
    CollectingScope collecting(isolate);
    const bool task_ran = platform::PumpMessageLoop(defaultPlatform(), isolate,
                                                    platform::MessageLoopBehavior::kDoNotWait);
    // The task may have been the C++ heap's sweeper finishing: node anchors
    // whose free it refused meanwhile are tried again (`oweWaitingAnchorFrees`).
    if (task_ran) oweWaitingAnchorFrees(isolate);
    const bool finalizers_ran = runQueuedFinalizers(isolate);
    return task_ran || finalizers_ran;
}

/// The pump WITHOUT its safe point: one platform task, and what its second
/// pass queued stays queued (v8_Debug_QueuedFinalizers). For tests of the
/// queue only - of a finalizer waiting, cancelled or outlived by its agent;
/// nothing in the engine pumps this way.
extern "C" bool v8_Debug_PumpMessageLoopHoldingFinalizers(Isolate* isolate) {
    if (!g_platform.started.load(std::memory_order_acquire) || !isolate) return false;
    // As the pump: a task may finish a collection (collectingRecord).
    CollectingScope collecting(isolate);
    return platform::PumpMessageLoop(defaultPlatform(), isolate,
                                     platform::MessageLoopBehavior::kDoNotWait);
}

/// A full collection WITHOUT the agent's safe point after it: the collection
/// V8 runs by itself when an allocation fails - Heap::CollectAllAvailableGarbage
/// (15.7.112.43 src/heap/heap.cc:1295-1330), which is both
/// Isolate::LowMemoryNotification (src/api/api.cc:10868-10875) and the last
/// resort of a failed allocation (src/heap/heap-allocator.cc:201-218, called
/// at :528 before the fatal "CALL_AND_RETRY_LAST" at :537). It runs its second
/// pass before it returns (kGCCallbackFlagCollectAllAvailableGarbage,
/// src/handles/global-handles.cc:881-889), in the
/// middle of whatever allocated, and the adapter is not there to run the
/// queue: what it found dead stays queued (v8_Debug_QueuedFinalizers) until
/// the agent's next safe point. For tests of the queue only - the engine
/// collects with v8_Isolate_RequestGarbageCollection.
extern "C" void v8_Debug_CollectHoldingFinalizers(Isolate* isolate) {
    if (!isolate) return;
    // The collecting isolate is the current one (collectingRecord).
    CollectingScope collecting(isolate);
    isolate->LowMemoryNotification();
}

/// End V8 for the process: it cannot start again (v8_Platform_Start answers
/// kPlatformDisposed). After every isolate is disposed, from one thread.
void v8_Platform_Dispose() {
    std::lock_guard<std::mutex> guard(g_platform.mutex);
    if (g_platform.started.load(std::memory_order_relaxed)) {
        V8::Dispose();
        // cppgc's process start's end, after every agent's C++ heap is gone
        // (gin::MaybeShutdownCppgc's place).
        cppgc::ShutdownProcess();
        V8::DisposePlatform();
        g_platform.started.store(false, std::memory_order_release);
        g_platform.disposed = true;
    }
}

// ============================================================================
// Isolate Management
// ============================================================================

// ----------------------------------------------------------------------------
// The adapter's per-isolate state
// ----------------------------------------------------------------------------
//
// One record per isolate in its embedder data slot 2 (`kIsolateDataSlot`), as
// Blink keeps V8PerIsolateData in `isolate->GetData(gin::kEmbedderBlink)`:
// made with the isolate (v8_Isolate_New, v8_Isolate_NewFromSnapshot), deleted
// by v8_Isolate_Dispose, read and written on the isolate's thread only - no
// lock, and nothing of another isolate reaches it (instances B2). What it
// holds used to be process-wide, under mutexes every Browser and worker
// thread took. Slots 0 and 1 are the Zig side's (isolate_allocator.zig,
// isolate_templates.zig); slot 3 is the binding catch scope.
//
// The isolates' ArrayBuffer::Allocators are no longer kept here or anywhere:
// each is handed to V8 as CreateParams::array_buffer_allocator_shared, so the
// isolate and every BackingStore it allocated hold it (v8-isolate.h) and the
// last of them frees it. It was a process-wide map, deleted at the isolate's
// dispose even while a BackingStore made with it (an ArrayBuffer transferred
// to another isolate) still lived; a snapshot isolate's was never deleted.
static constexpr uint32_t kIsolateDataSlot = 2;

/// A JSON module's parsed value, held from creation until V8 runs its
/// evaluation steps (see v8_Module_CreateJsonModule).
struct SyntheticJsonExport {
    Global<Module> module;
    Global<Value> value;
};

/// An isolate's full-collection pauses, for engine.diagnosticCounters'
/// `full_gc_count`, `full_gc_pause_max_us` and `full_gc_pause_p95_us` (the
/// wrapper redesign's P0, tmp/redesign/wrapper-redesign-design.md section 7:
/// its later phases put C++ marking and the host walk in this pause, risk
/// R4c). A pause is the time from the GC prologue to the GC epilogue of one
/// mark-compact: V8 13.1 src/heap/heap.cc Heap::CollectGarbage calls
/// CallGCPrologueCallbacks before StartObservablePause and
/// CallGCEpilogueCallbacks after StopObservablePause, so the two bracket the
/// collection's atomic pause. Only the isolate's own thread writes or reads
/// it: V8 calls the callbacks on the thread collecting, and
/// diagnosticCounters reads the current isolate.
struct GCPauses {
    /// How many pauses the p95 is taken over: the most recent ones.
    static constexpr size_t kRecent = 1024;
    std::chrono::steady_clock::time_point started{};
    /// Prologue minus epilogue: "These callbacks may trigger GC themselves"
    /// (heap.cc), so a nested collection is part of the outer one's pause.
    int depth = 0;
    uint64_t count = 0;
    uint64_t max_us = 0;
    /// The isolate's young-generation collections so far - scavenges and
    /// minor mark-sweeps, counted at their prologue (gcMinorPrologue): the
    /// collections in which a droppable node wrapper can be dropped (design
    /// 4.11, P8). For engine.diagnosticCounters' `minor_gc_count` and the
    /// tests that ask for scavenges (v8_test_Isolate_MinorGC).
    uint64_t minor_count = 0;
    /// The last kRecent pauses (us), a ring from `next`; reserved on the
    /// first pause, so an agent that never collects fully keeps none.
    std::vector<uint32_t> recent;
    size_t next = 0;

    void record(uint64_t us) {
        count += 1;
        if (us > max_us) max_us = us;
        const uint32_t kept = us > 0xFFFFFFFFull ? 0xFFFFFFFFu : static_cast<uint32_t>(us);
        if (recent.size() < kRecent) {
            if (recent.empty()) recent.reserve(kRecent);
            recent.push_back(kept);
        } else {
            recent[next] = kept;
            next = (next + 1) % kRecent;
        }
    }

    /// The 95th percentile of the recent pauses by nearest rank: the
    /// ceil(0.95 n)-th smallest. 0 with none.
    uint64_t p95() const {
        if (recent.empty()) return 0;
        std::vector<uint32_t> sorted(recent);
        const size_t rank = (sorted.size() * 95 + 99) / 100;
        std::nth_element(sorted.begin(), sorted.begin() + (rank - 1), sorted.end());
        return sorted[rank - 1];
    }
};

/// Where an isolate's full collections spend their atomic pause, and what
/// becomes of the node anchors scavenges free - engine.diagnosticCounters'
/// `node_anchor*` and `gc_atomic_*` / `cpp_atomic_*` (lane wr1 batch 8: P8's
/// full-collection pause grew with the wrappers scavenges had dropped since
/// the last one, and two parts of the pause could be why - the anchors'
/// weak processing walking their slots, or the C++ heap sweeping them). Each
/// `_max` is the largest one full collection has had so far; only the
/// isolate's own thread writes or reads it.
/// - The anchors' weak processing (NodeWrapperRegistry::ProcessWeak): its
///   time and the slots it read.
/// - The atomic pause's phases as V8 reports them to the embedder's metrics
///   recorder (GCPhaseRecorder; 13.1.203 src/heap/gc-tracer.cc
///   GCTracer::ReportFullCycleToRecorder, at the end of each full cycle):
///   `main_thread_atomic` for the whole heap - mark, weak (MC_CLEAR), compact
///   (MC_EVACUATE + MC_FINISH + MC_EPILOGUE), sweep (MC_SWEEP) - and
///   `main_thread_atomic_cpp` for the C++ heap's share, from cppgc's own
///   recorder: its marking (the walk among it), its weak processing (the
///   anchors' among it), its compaction and its sweep - atomic, inside the
///   pause, for a forced collection (cpp-heap.cc CppHeap::SelectSweepingType).
///   Only where the recorder is installed (CRANE_GC_PHASE_METRICS: gc_bench's
///   build); 0 elsewhere.
///   Diagnostics only: nothing reads them to decide anything.
struct GCPhaseStats {
    uint64_t anchor_weak_ns_max = 0;
    uint64_t anchor_weak_slots_max = 0;
    int64_t atomic_us_max = 0;
    int64_t atomic_mark_us_max = 0;
    int64_t atomic_weak_us_max = 0;
    int64_t atomic_compact_us_max = 0;
    int64_t atomic_sweep_us_max = 0;
    int64_t cpp_us_max = 0;
    int64_t cpp_mark_us_max = 0;
    int64_t cpp_weak_us_max = 0;
    int64_t cpp_compact_us_max = 0;
    int64_t cpp_sweep_us_max = 0;

    static void keepMax(int64_t& kept, int64_t value) {
        if (value > kept) kept = value;
    }
};

/// Whether isolates get the metrics recorder below: only in gc_bench's build
/// (-DCRANE_TRACK_GLOBALS=1, build.zig), never in Crane's. V8 names the
/// context each full cycle is reported for by a ContextId it keeps in a weak
/// Global of its own, one per context (13.1.203 isolate.cc
/// Isolate::GetOrRegisterRecorderContextId, called from gc-tracer.cc
/// GetContextId only when an embedder recorder is set): a global handle per
/// realm that the leak tests and the handle counters would count
/// (tests/v8/worker_iterator_template_test.zig saw 32 bytes a worker realm).
#ifndef CRANE_GC_PHASE_METRICS
#define CRANE_GC_PHASE_METRICS CRANE_TRACK_GLOBALS
#endif

/// The embedder's metrics recorder (v8-metrics.h; Chromium installs one per
/// isolate, V8MetricsRecorder): it keeps the largest of each atomic phase of
/// a full cycle in its isolate's GCPhaseStats. V8 owns it (a shared_ptr) and
/// tells it when the isolate goes (NotifyIsolateDisposal, from
/// Isolate::Deinit inside Isolate::Dispose): from there it writes nothing,
/// so the record, deleted after Dispose, is never written late.
class GCPhaseRecorder final : public metrics::Recorder {
 public:
    explicit GCPhaseRecorder(GCPhaseStats* stats) : stats_(stats) {}

    using metrics::Recorder::AddMainThreadEvent;

    void AddMainThreadEvent(const metrics::GarbageCollectionFullCycle& event, ContextId) override {
        if (!stats_) return;
        GCPhaseStats::keepMax(stats_->atomic_us_max, event.main_thread_atomic.total_wall_clock_duration_in_us);
        GCPhaseStats::keepMax(stats_->atomic_mark_us_max, event.main_thread_atomic.mark_wall_clock_duration_in_us);
        GCPhaseStats::keepMax(stats_->atomic_weak_us_max, event.main_thread_atomic.weak_wall_clock_duration_in_us);
        GCPhaseStats::keepMax(stats_->atomic_compact_us_max, event.main_thread_atomic.compact_wall_clock_duration_in_us);
        GCPhaseStats::keepMax(stats_->atomic_sweep_us_max, event.main_thread_atomic.sweep_wall_clock_duration_in_us);
        GCPhaseStats::keepMax(stats_->cpp_us_max, event.main_thread_atomic_cpp.total_wall_clock_duration_in_us);
        GCPhaseStats::keepMax(stats_->cpp_mark_us_max, event.main_thread_atomic_cpp.mark_wall_clock_duration_in_us);
        GCPhaseStats::keepMax(stats_->cpp_weak_us_max, event.main_thread_atomic_cpp.weak_wall_clock_duration_in_us);
        GCPhaseStats::keepMax(stats_->cpp_compact_us_max, event.main_thread_atomic_cpp.compact_wall_clock_duration_in_us);
        GCPhaseStats::keepMax(stats_->cpp_sweep_us_max, event.main_thread_atomic_cpp.sweep_wall_clock_duration_in_us);
    }

    void NotifyIsolateDisposal() override {
        stats_ = nullptr;
    }

 private:
    GCPhaseStats* stats_;
};

// ----------------------------------------------------------------------------
// CraneWrappable: the adapter's one base for every C++ object V8 holds by a
// CppHeap pointer - Object::WrapGlobal (a realm's global: GlobalAnchor),
// Object::Wrap (a node's wrapper: lane wr1's NodeAnchor; every other platform
// object's: lane wrap1's PlatformAnchor). Lane v8up b3b, item 1;
// tmp/plans/v8-global-object-design.md 3.1, tmp/plans/object-wrap-design.md
// 3.6; the contract the three kinds share is written out in
// tmp/plans/lane-v8up-handoff.md ("CraneWrappable CONTRACT").
//
// It carries NO data. What V8 needs is v8::Object::Wrappable's vptr (Wrap
// takes a Wrappable*, v8-object.h; cppgc's NameProvider makes it virtual) and
// a Trace; each kind lays out its own fields after it, so a NodeAnchor pays
// for no field it does not use (instance_ + generation_ in the base would make
// wr1's 24 B NodeAnchor 40 B, +16 B per wrapped node). Blink's ScriptWrappable
// is the same shape: the vptr, then the object's own members.
//
// Lifetime (the contract): MakeGarbageCollected on the isolate's CppHeap; OWNED
// by that heap, never freed by Zig, alive while a JS object holds its CppHeap
// pointer or a cppgc Member/Persistent reaches it. The virtual destructor is
// its finalizer: it runs at cppgc's sweep on the agent's thread (and in
// cppgc::subtle::FreeUnreferencedObject), touches no V8 API and no engine
// state - Zig bookkeeping only; engine work it implies is queued to a task.
// The Zig instance a kind points at keeps Zig's lifetime: Zig calls the
// kind's clear() before it frees the instance (one write severs every JS
// object that points at the anchor).
// ----------------------------------------------------------------------------

/// The tags (v8-sandbox.h: V8's embedder range is [kFirstEmbedderWrappableTag,
/// kLastEmbedderWrappableTag] = [1, 0x6eff], and a parent's range must hold
/// exactly its subclasses' tags). Object::Unwrap with a kind's range is V8's
/// type check; the base range answers "a Crane anchor of any kind".
namespace crane_tags {
constexpr uint16_t kCraneWrappableFirst = 0x0001;
constexpr uint16_t kCraneWrappableLast = 0x00ff;
/// A realm's global (Window, WorkerGlobalScope, a worklet's, ShadowRealm's).
constexpr uint16_t kGlobalAnchor = 0x0001;
/// A node's wrapper (lane wr1; it may split this range by node kind).
constexpr uint16_t kNodeAnchorFirst = 0x0002;
constexpr uint16_t kNodeAnchorLast = 0x007f;
/// Every other platform object's wrapper (lane wrap1, design 3.4).
constexpr uint16_t kPlatformAnchorFirst = 0x0080;
constexpr uint16_t kPlatformAnchorLast = 0x00ff;
/// A node's wrapper today: one tag for every node interface (NodeAnchor says
/// why), the first of the node range.
constexpr uint16_t kNodeAnchor = kNodeAnchorFirst;
/// A HOLDER's wrapper (HolderAnchor; the wrapper redesign's P6): a platform
/// object that holds nodes for script. The first tag of the platform range.
constexpr uint16_t kHolderAnchor = kPlatformAnchorFirst;
/// Every other non-node platform object's wrapper (PlatformAnchor; lane wrap1
/// b2): one tag for every interface - Crane's brand check is the instance's
/// state ancestry, as for a node's (kNodeAnchor).
constexpr uint16_t kPlatformAnchor = kPlatformAnchorFirst + 1;
/// tests/v8's droppable probe (DroppableProbeAnchor): the platform range's
/// last tag, which no production anchor uses.
constexpr uint16_t kTestProbeAnchor = kPlatformAnchorLast;

static_assert(kCraneWrappableFirst >= static_cast<uint16_t>(CppHeapPointerTag::kFirstEmbedderWrappableTag) &&
                  kCraneWrappableLast <= static_cast<uint16_t>(CppHeapPointerTag::kLastEmbedderWrappableTag),
              "Crane's anchors use V8's embedder Wrappable tag range only");
static_assert(kGlobalAnchor == kCraneWrappableFirst && kGlobalAnchor < kNodeAnchorFirst &&
                  kNodeAnchorLast + 1 == kPlatformAnchorFirst && kPlatformAnchorLast == kCraneWrappableLast,
              "the three kinds tile the base range: GlobalAnchor 1, NodeAnchor [2, 0x7f], PlatformAnchor [0x80, 0xff]");

constexpr CppHeapPointerTag tag(uint16_t value) { return static_cast<CppHeapPointerTag>(value); }
[[maybe_unused]] constexpr CppHeapPointerTagRange kCraneWrappableRange{tag(kCraneWrappableFirst), tag(kCraneWrappableLast)};
constexpr CppHeapPointerTagRange kGlobalAnchorRange{tag(kGlobalAnchor), tag(kGlobalAnchor)};
[[maybe_unused]] constexpr CppHeapPointerTagRange kNodeAnchorRange{tag(kNodeAnchorFirst), tag(kNodeAnchorLast)};
[[maybe_unused]] constexpr CppHeapPointerTagRange kPlatformAnchorRange{tag(kPlatformAnchorFirst), tag(kPlatformAnchorLast)};
/// The tags a platform object's wrapper is Wrapped with - a holder's and a
/// plain one's - and so the range the binding unwraps it under: both are a
/// PlatformAnchor. (Not the whole platform range: its last tag is a test
/// probe's, which is none.)
constexpr CppHeapPointerTagRange kPlatformObjectAnchorRange{tag(kHolderAnchor), tag(kPlatformAnchor)};
static_assert(kPlatformAnchor == kHolderAnchor + 1 && kPlatformAnchor < kTestProbeAnchor,
              "a platform object's anchors are two adjacent tags below the test probe's");
}  // namespace crane_tags

class CraneWrappable : public v8::Object::Wrappable {
 public:
    /// What the anchor keeps alive: per kind (a global's retained values, a
    /// node's tree, a platform object's keeps). The base keeps nothing.
    void Trace(cppgc::Visitor* visitor) const override { v8::Object::Wrappable::Trace(visitor); }
    const char* GetHumanReadableName() const override { return "Crane anchor"; }

 protected:
    CraneWrappable() = default;
};

// The base is Wrappable's vptr and nothing else (the contract: no data fields).
static_assert(sizeof(CraneWrappable) == sizeof(void*), "CraneWrappable carries no data: each kind lays out its own fields");
static_assert(!std::is_trivially_destructible_v<CraneWrappable>,
              "a Wrappable is a NameProvider: cppgc finalizes it (its destructor is the anchor's finalizer)");

// ----------------------------------------------------------------------------
// Node anchors: node wrappers on the agent's C++ heap (the wrapper redesign's
// P4, tmp/redesign/wrapper-redesign-design.md 4.1-4.5)
// ----------------------------------------------------------------------------

struct IsolateData;


static IsolateData* isolateData(Isolate* isolate);
static void traceAnchorTree(IsolateData* record, void* slot, cppgc::Visitor* visitor);

/// The record of the isolate whose collection's atomic pause runs a Trace
/// of `object` (a node anchor or the anchors' registry, on that isolate's
/// C++ heap) - the only place the walk may run (design 4.4, R6) - or null
/// when nothing is marking: a heap snapshot's graph builder calls Trace
/// too, and walks nothing.
///
/// Why only the pause: Crane's agents' C++ heaps are made with
/// CppHeapCreateParams.marking_support = kAtomic (agentCppHeapParams), so in
/// V8 15.7.112.43 - re-read at lane v8up's port; 13.1.203 said the same -
/// C++ Trace methods run only there: src/heap/cppgc-js/cpp-heap.cc:771-787
/// UpdateGCCapabilitiesFromFlags only lowers marking_support_ (std::min
/// with what --cppheap-incremental-marking / --cppheap-concurrent-marking
/// allow, which --incremental-marking implies by default,
/// flag-definitions.h:2916-2926: the explicit kAtomic is what holds it);
/// SelectMarkingType (:736-755) never returns more than marking_support();
/// AdvanceMarking - the only caller of MarkerBase::AdvanceMarkingWithLimits,
/// which pops the worklists and calls Trace - is reached outside the pause
/// only from IncrementalMarking::CppHeapStep (src/heap/
/// incremental-marking.cc:468-484), which returns at once when
/// !incremental_marking_supported() (cppgc-internal/heap-base.h:217-219);
/// MarkerBase::StartMarking (cppgc-internal/marker.cc:209-239) schedules no
/// incremental task, starts no concurrent marker and registers no
/// allocation observer for kAtomic (EnterIncrementalMarkingIfNeeded,
/// :39-48). V8's own markers - incremental steps, concurrent threads and the
/// Object::Wrap write barrier (CppHeap::WriteBarrier, cpp-heap.cc:960-964) -
/// only mark an anchor's header and push it (CppMarkingState::MarkAndPush,
/// cppgc-js/cpp-marking-state.h:37), so every anchor marked in a cycle is
/// traced once, in the pause, after every tree change of the cycle: Crane's
/// trees have no write barrier, and a walk done earlier would miss nodes
/// appended after it (the integrator, 2026-11-09 16:22). A V8 upgrade that
/// changes any of this fails the check below.
///
/// Why the current isolate: the pause runs on the collecting isolate's
/// thread with that isolate entered, as Blink's Trace reaches
/// ThreadState::Current() - an anchor holds only its slot (16 bytes, design
/// 4.1), so it cannot hold its record, and no Crane global may (the
/// integrator, 2026-11-09 16:45). Every entry that can start a full
/// collection outside script enters the isolate first (CollectingScope).
/// Checked: a mismatch is a loud failure, never a walk of the wrong agent.
static IsolateData* collectingRecord(const void* object) {
    const cppgc::HeapHandle& heap = cppgc::internal::BasePageHandle::FromPayload(object)->heap_handle();
    if (!cppgc::subtle::HeapState::IsMarking(heap)) return nullptr;
    if (!cppgc::subtle::HeapState::IsInAtomicPause(heap)) {
        fprintf(stderr, "v8_wrapper: a node anchor was traced outside the atomic pause - the agents' C++ heap must keep "
                        "CppHeapCreateParams.marking_support = kAtomic (the wrapper redesign's walk, design 4.4)\n");
        abort();
    }
    Isolate* isolate = Isolate::TryGetCurrent();
    CppHeap* current = isolate ? isolate->GetCppHeap() : nullptr;
    if (!current || &current->GetHeapHandle() != &heap) {
        fprintf(stderr, "v8_wrapper: a collection's atomic pause traced a node anchor while %s - the walk reaches its "
                        "agent through the current isolate (enter it before a collection: CollectingScope)\n",
                isolate ? "another isolate was current" : "no isolate was current");
        abort();
    }
    return isolateData(isolate);
}


/// The CppHeapPointerTag every node wrapper's anchor is wrapped with
/// (Object::Wrap) and unwrapped under (Object::Unwrap). One tag for every
/// node interface: Crane's brand check is the instance's state ancestry
/// (binding_plumbing `implements`, conversions.implements), so the tag only
/// says "a node anchor" - the role of Blink's type-unknown range,
/// `ToAnyScriptWrappable`'s kScriptWrappableTagRange
/// (third_party/blink/renderer/platform/bindings/wrapper_type_info.h), where
/// Blink's per-interface tags (WrapperTypeInfo::this_tag) are its brand.
/// The first tag of the adapter's node range (crane_tags, the CraneWrappable
/// contract: [2, 0x7f] inside V8's embedder Wrappable range).
static constexpr CppHeapPointerTag kNodeAnchorTag = crane_tags::tag(crane_tags::kNodeAnchor);
static constexpr CppHeapPointerTagRange kNodeAnchorTagRange(kNodeAnchorTag, kNodeAnchorTag);

/// What a node wrapper points at (design 4.1): a cppgc object behind the
/// wrapper's CppHeap pointer, so V8's marker consults the host about the
/// wrapper - the only way it can (design 2.6). It holds the node's wrapper
/// SLOT (engine.NodeWrapperSlot: the TracedReference in the node, 8 bytes),
/// from which the Zig side finds the node (runtime.lifetime.targetOfSlot) -
/// so its Trace reads its slot with no call into the host, once per live
/// anchor per major GC. With its place in the anchors' registry (`index_`,
/// for an O(1) removal when a scavenge drops its wrapper: lane wr1 batch 8)
/// and its keeps (`roots_`, Debug's check that a kept anchor is never
/// dropped) in the same word, after the vptr every v8::Object::Wrappable has
/// (V8 15.7's Object::Wrap takes a Wrappable*; CraneWrappable): 24 bytes of
/// payload, 32 with cppgc's header (13.1.203: 16 and 24, with no vptr).
///
/// Its wrapper's counted reference is the anchor's: taken before the anchor
/// exists (node_wrappers.adopt, design 4.2 step 1) and released after the
/// anchor dies (the registry's drain). `slot_` is null once its wrapper
/// ended outside a collection - its node's teardown (v8_NodeWrapper_End) or
/// its agent's end (v8_NodeWrappers_EndAll) - and the anchor then traces
/// nothing and is dropped when it dies; or once a young-generation
/// collection dropped its wrapper (NodeWrapperRootsHandler::ResetRoot), and
/// the anchor is then freed after that collection (freeDroppedAnchors).
/// Its destructor is the base's and does nothing (the CraneWrappable
/// contract: a Wrappable is a NameProvider, so cppgc finalizes every anchor
/// on the agent's thread - at its sweep, or in the explicit free - and the
/// finalizer touches no V8 API, no engine state and no node).
class NodeAnchor final : public CraneWrappable {
 public:
    /// `index_` of an anchor in no registry: made and not yet registered, or
    /// dropped by a scavenge (on the record's dropped list).
    static constexpr uint32_t kUnregistered = UINT32_MAX;

    explicit NodeAnchor(void* slot) : slot_(slot) {}

    /// Design 4.4, in order:
    /// 1. its own slot: a live anchor always marks its own TracedNode, so no
    ///    pruning mistake of the walk can leave a non-empty slot whose
    ///    TracedNode V8 freed (principle 3) - a mistake can only lose a
    ///    neighbour's wrapper;
    /// 2. the walk, in the collection's atomic pause: every wrapper its node
    ///    keeps (its host-including tree's and its node document's;
    ///    dom.wrapper_tracing), as Blink's Node::Trace reaches its tree's
    ///    wrappers through the tree's Member edges. Since P7 the walk alone
    ///    keeps trees (node tracing's JS edges are gone).
    void Trace(cppgc::Visitor* visitor) const override {
        CraneWrappable::Trace(visitor);
        if (!slot_) return;
        visitor->Trace(*static_cast<const TracedReference<Object>*>(slot_));
        IsolateData* record = collectingRecord(this);
        if (record) traceAnchorTree(record, slot_, visitor);
    }
    const char* GetHumanReadableName() const override { return "Crane NodeAnchor"; }

    void* slot_;
    /// Where the anchor is in its agent's registry (NodeWrapperRegistry::
    /// anchors), kUnregistered when in none. Only the registry writes it.
    uint32_t index_ = kUnregistered;
    /// The keeps' roots on the anchor (v8_NodeWrapper_Root/Unroot): a kept
    /// anchor's slot is non-droppable, so a scavenge never drops its
    /// wrapper - ResetRoot checks it in Debug.
    uint32_t roots_ = 0;
};

static_assert(sizeof(NodeAnchor) == 3 * sizeof(void*), "a node anchor is the vptr, its slot, its registry index and its roots: 24 bytes");
static_assert(sizeof(TracedReference<Object>) == sizeof(void*), "a node's wrapper slot holds exactly one TracedReference<Object>");

/// The CppHeapPointerTags a non-node platform object's wrapper is Wrapped
/// with: a holder of nodes' (crane_tags::kHolderAnchor) and every other's
/// (crane_tags::kPlatformAnchor); the binding unwraps under both
/// (crane_tags::kPlatformObjectAnchorRange).
static constexpr CppHeapPointerTag kHolderAnchorTag = crane_tags::tag(crane_tags::kHolderAnchor);
static constexpr CppHeapPointerTag kPlatformAnchorTag = crane_tags::tag(crane_tags::kPlatformAnchor);

static void traceHolderNodes(IsolateData* record, void* instance, uint64_t generation, cppgc::Visitor* visitor);

/// What a non-node platform object's wrapper points at (lane wrap1 b2,
/// tmp/plans/object-wrap-design.md 3.4): a cppgc object behind the wrapper's
/// CppHeap pointer that names the Zig instance - the link the binding reads
/// (`instanceOfObject`). Blink's wrapper points at the DOM object itself,
/// which is its cppgc object (V8DOMWrapper::SetNativeInfo: Object::Wrap with
/// the ScriptWrappable; platform/bindings/v8_dom_wrapper.h:103-110, Chromium
/// 157.0.8103.51); Crane's instances are Zig objects that live by their own
/// counts, so the wrapper points at this anchor and the anchor at the
/// instance. The interface's instance template has no internal field
/// (interface.zig), as Blink's has none.
///
/// It replaces V8 15.7's own box for an aligned pointer in an internal field
/// (EmbedderDataSlotWrapper {pointer, tag}: 16 bytes and cppgc's header,
/// 15.7.112.43 src/objects/embedder-data-slot-inl.h:209-227) byte for byte:
/// the Wrappable's vptr and the instance, 16 bytes of payload, 24 with the
/// header - and the wrapper loses its 8-byte field.
///
/// `instance_` is null once the instance went while the wrapper may live on
/// (its realm's end, a wrap that failed: v8_PlatformObject_Sever) - Blink's
/// ClearNativeInfo; the binding's read then answers null, a TypeError, never
/// the freed instance. The anchor owns nothing: the instance's lifetime is
/// the wrapper cache's (wrapper_cache.zig), whose weak handle on the wrapper
/// decides when it goes - until that lifetime moves here too (design 3.4,
/// the batch after this one). Its destructor is the base's and does nothing
/// (the CraneWrappable contract).
class PlatformAnchor : public CraneWrappable {
 public:
    explicit PlatformAnchor(void* instance) : instance_(instance) {}
    const char* GetHumanReadableName() const override { return "Crane PlatformAnchor"; }

    void* instance_;
};

static_assert(sizeof(PlatformAnchor) == 2 * sizeof(void*), "a platform anchor is the vptr and its instance: 16 bytes");

/// What a HOLDER's wrapper points at (the wrapper redesign's P6, design 4.4
/// "Holders"): the platform anchor of an object that holds nodes for script
/// - a static NodeList's nodes, a MutationRecord's, a live collection's root
/// (runtime.VTable.trace_held_nodes) - so V8's marker consults the host
/// about what the holder holds. Blink's holders are themselves cppgc objects
/// whose Trace visits their `Member<Node>`s (StaticNodeTypeList::Trace,
/// ChildListRecord::Trace; Chromium 131.0.6778.0); Crane's holders are Zig
/// instances, reached through this anchor. Until lane wrap1 b2 it stood
/// beside the instance in an internal field: a holder's wrapper paid V8's
/// box for the field and this anchor, and now pays this anchor alone.
///
/// It adds the holder's slab generation to the platform anchor - 24 bytes,
/// 32 with cppgc's header, one per holder wrapper, none per node. Its Trace
/// runs in the collection's atomic pause, under the node anchors' rule
/// (collectingRecord: kAtomic marking, the collecting isolate's record):
/// the host reads its holder's state, which has no write barrier either.
/// `instance_` null (PlatformAnchor) traces nothing; the generation is the
/// net for any other way the instance went - the Zig side compares it before
/// it reads the instance. Its destructor is the base's and does nothing.
class HolderAnchor final : public PlatformAnchor {
 public:
    HolderAnchor(void* instance, uint64_t generation) : PlatformAnchor(instance), generation_(generation) {}

    void Trace(cppgc::Visitor* visitor) const override {
        PlatformAnchor::Trace(visitor);
        if (!instance_) return;
        IsolateData* record = collectingRecord(this);
        if (record) traceHolderNodes(record, instance_, generation_, visitor);
    }
    const char* GetHumanReadableName() const override { return "Crane HolderAnchor"; }

    uint64_t generation_;
};

static_assert(sizeof(HolderAnchor) == 3 * sizeof(void*), "a holder anchor is the vptr, its instance and its generation: 24 bytes");

/// The agent's node anchors, for weak processing (design 4.5): a cppgc
/// object rooted by its record (IsolateData::node_anchors), whose Trace only
/// registers ProcessWeak - Blink's ActiveScriptWrappableManager pattern
/// (third_party/blink/renderer/platform/bindings/
/// active_script_wrappable_manager.h). The anchors are held raw and
/// untraced: a wrapper keeps its anchor, nothing here does.
class NodeWrapperRegistry final : public cppgc::GarbageCollected<NodeWrapperRegistry> {
 public:
    explicit NodeWrapperRegistry(IsolateData* record) : record_(record) {}

    /// The weak processing, and - the agent's NodeRoots (design 4.4, "Kept
    /// nodes") - the walk from every kept node in the collection's atomic
    /// pause: this registry is rooted by its record, so it is traced in
    /// every major collection.
    void Trace(cppgc::Visitor* visitor) const;

    void ProcessWeak(const cppgc::LivenessBroker& broker);

    /// Every anchor not yet found dead and whose wrapper no scavenge dropped:
    /// outside a collection's atomic pause each is alive (ProcessWeak runs
    /// in every major GC; cppgc collects only in major GCs - no cppgc young
    /// generation, --cppgc-young-generation is off). Each anchor's `index_`
    /// is its place here.
    std::vector<NodeAnchor*> anchors;

    /// The capacity kept after a collection empties most of `anchors`.
    static constexpr size_t kShrinkFloor = 1024;

    /// `anchor` joins the registry (its wrap, v8_NodeWrapper_Attach); room
    /// for it was reserved before it was made.
    void add(NodeAnchor* anchor) {
        if (anchors.size() >= NodeAnchor::kUnregistered) {
            fprintf(stderr, "v8_wrapper: more node anchors than a registry index holds\n");
            abort();
        }
        anchor->index_ = static_cast<uint32_t>(anchors.size());
        anchors.push_back(anchor);
    }

    /// `anchor` leaves the registry in O(1): the last anchor takes its place.
    /// An anchor whose index does not name it - in no registry, or the
    /// bookkeeping broken - is a loud failure: freeing it would leave a
    /// pointer to freed memory here.
    void remove(NodeAnchor* anchor) {
        const uint32_t at = anchor->index_;
        if (at >= anchors.size() || anchors[at] != anchor) {
            fprintf(stderr, "v8_wrapper: a node anchor left a registry it is not in (index %u of %zu)\n", at, anchors.size());
            abort();
        }
        NodeAnchor* last = anchors.back();
        anchors[at] = last;
        last->index_ = at;
        anchors.pop_back();
        anchor->index_ = NodeAnchor::kUnregistered;
    }

 private:
    IsolateData* record_;
};

class NodeWrapperRootsHandler;

struct IsolateData {
    // Installed before Isolate::Initialize: V8 caches runners while setting up
    // its heap. Their shared state receives the host's sink after creation.
    std::shared_ptr<ForegroundTasks> foreground_tasks = std::make_shared<ForegroundTasks>();
    std::array<std::shared_ptr<TaskRunner>, 3> foreground_runners;

    /// A snapshot isolate's StartupData (v8_Isolate_NewFromSnapshot), which
    /// V8 keeps a pointer to for the isolate's life (CreateParams::
    /// snapshot_blob) and reads again for every context it restores
    /// (Snapshot::NewContextFromSnapshot). Its `data` is the CALLER'S bytes,
    /// read in place, never copied; null for an isolate made afresh. It lives
    /// in the record, made before the isolate, and v8_Isolate_Dispose
    /// deletes the record only after Isolate::Dispose returns.
    StartupData startup_data{nullptr, 0};
    /// The isolate's JSON (and default-export) modules waiting for
    /// evaluation, until V8 runs their evaluation steps or the module is
    /// disposed - or the isolate is: v8_Isolate_Dispose resets what is left.
    std::vector<SyntheticJsonExport*> synthetic_json_exports;
    /// The isolate's null, BORROWED by whoever v8_Isolate_BorrowedNull hands
    /// it to: made on first use, reset by v8_Isolate_Dispose while the
    /// isolate lives. Never disposed by a caller.
    Global<Value> null_value;
    // Inert unless a tests/v8 lifecycle probe is installed. The test clears
    // the hook before its borrowed stack payload expires.
    void (*test_promise_hook)(int, void*) = nullptr;
    void* test_promise_hook_data = nullptr;

    /// engine.AgentOptions.random_seed: whether the isolate was made with a
    /// seed, and the seed. Set before Isolate::Initialize - V8 may make the
    /// isolate's random number generator while it initializes - and never
    /// changed. craneEntropySource answers it for every generator V8 makes
    /// while this isolate is current.
    bool seeded = false;
    uint64_t random_seed = 0;
    /// engine.AgentOptions.clock: the host's wall clock (ns since the epoch)
    /// that Date reads in this isolate, through CranePlatform's
    /// CurrentClockTimeMilli*. Null: the backend platform's clock. Set
    /// before Isolate::Initialize, never changed; the context is the host's,
    /// BORROWED until the isolate is disposed.
    int64_t (*clock_wall_now)(void*) = nullptr;
    void* clock_context = nullptr;
    /// Whether the isolate counts in the process's read-only heap record
    /// (g_read_only_heap): made by v8_Isolate_NewWithOptions or
    /// v8_Isolate_NewFromSnapshotWithOptions, given back by v8_Isolate_Dispose.
    bool holds_read_only_heap = false;
    /// [module_scripts] import.meta.resolve, only for an agent whose host
    /// resolves (engine.HostHooks.importMetaResolve): the dispatcher is the
    /// process's, so whether the builtin is made is the isolate's.
    bool import_meta_resolve = false;
    /// The isolate's full-collection pauses (GCPauses): the GC callbacks
    /// installGCPauseRecorder adds after Isolate::Initialize write it, with
    /// this record as their data until the record goes after Dispose.
    GCPauses gc_pauses;
    /// Where the full collections' atomic pauses go (GCPhaseStats): written
    /// by the anchors' weak processing and the isolate's metrics recorder
    /// (installGCPauseRecorder).
    GCPhaseStats gc_phases;
    /// How many context disposals this isolate was told of, by what V8 was
    /// told about dependants (v8_Isolate_ContextDisposedNotification): [0] a
    /// main frame's context (kNoDependants), [1] a child frame's
    /// (kSomeDependants). Written on the isolate's thread; a diagnostic the
    /// tests read (v8_Debug_ContextDisposals).
    uint64_t context_disposals[2] = {0, 0};
    /// navigation_collection.zig: a navigation replaced a main frame's
    /// document, and the agent's next engine-task step owes V8 a look at how
    /// much the heap holds - and, over the build's threshold, a critical
    /// memory-pressure notice. Written and read on the isolate's thread.
    bool navigation_collection_owed = false;
    /// The agent's C++ heap (newAgentCppHeap) until V8 takes it: handed to
    /// V8 as CreateParams::cpp_heap and attached from Isolate::Initialize on,
    /// after which V8 OWNS it ("V8 takes ownership of the CppHeap passed this
    /// way", v8-isolate.h) and deletes it in Isolate::Dispose: 15.7's
    /// Heap::TearDown detaches it and hands `owning_cpp_heap_` to
    /// RunReleaseCppHeapCallback, which with no callback lets the unique_ptr
    /// go (src/heap/heap.cc:6322-6324, src/execution/isolate.cc:7711; since
    /// 1c079f473b1, 13.4). So `adoptCppHeap` releases this record's hold right
    /// after Isolate::Initialize; the record frees the heap itself only when
    /// no isolate was made with it. (13.1.203 never freed it - the record
    /// did, after Dispose - and freeing it here now would free it twice.)
    std::unique_ptr<CppHeap> cpp_heap;
    /// The agent's node wrapper registry (node_wrappers.zig `Registry`, the
    /// wrapper redesign's P2 and P4), OWNED: made by the adapter's Zig side on
    /// the isolate's first node wrap or keep (v8_Isolate_SetNodeWrappers) with
    /// the four functions below, and ended by `node_wrappers_end` at the start
    /// of v8_Isolate_Dispose, while the isolate lives - every node wrapper's
    /// slot emptied, its anchor's slot cleared and its reference released
    /// first, so no weak processing is left to find the record gone. Read on
    /// the isolate's thread only.
    void* node_wrappers = nullptr;
    /// A node wrapper's anchor was found dead in a collection's atomic pause
    /// (NodeWrapperRegistry::ProcessWeak), or a young-generation collection
    /// dropped its wrapper (NodeWrapperRootsHandler::ResetRoot): `slot` is
    /// its node's slot. Zig bookkeeping only - the slot written empty (raw:
    /// V8 frees the TracedNode itself), the release recorded. No V8 call, no
    /// count change, no free.
    void (*node_wrapper_collected)(void* registry, void* slot) = nullptr;
    /// The agent's safe point (`runQueuedFinalizers`), once
    /// `node_wrappers_collected` is set: the agent's released references go
    /// (its drain).
    void (*node_wrappers_drain)(void* registry) = nullptr;
    /// The node wrappers' drain is owed to the agent's next safe point
    /// (`noteNodeWrappersCollected`, set by the collection itself): the
    /// registry holds releases a collection recorded, or anchors a scavenge
    /// dropped wait for their free.
    bool node_wrappers_collected = false;
    /// THE AGENT'S FINALIZER QUEUE: the records of collected wrappers, queued
    /// by V8's first pass (`WeakCallbackWrapper`), oldest first, each
    /// waiting for the agent's safe point to run its Zig finalizer
    /// (`runQueuedFinalizers`). BORROWED pointers: a record is owned as it
    /// always was - by pendingFinalizers() under its handle until it runs,
    /// or by detachedWeakData() once its owner cancelled it (it stays listed
    /// here, with a null `finalize`, until the drain frees it). Nothing is
    /// added to a live wrapper: a record joins when its wrapper has died.
    /// v8_Isolate_Dispose empties the list without calling Zig; the two
    /// owners free the records. Read and written on the isolate's thread.
    ///
    /// Two lists, run in this order by every full drain: `queued_finalizers`
    /// holds the records a callback's exit has looked at and found must wait
    /// for depth zero (`v8_Isolate_RunFreshFinalizers`); the first pass puts
    /// a record on `unjudged_finalizers`, where one that waits for an outer
    /// callback also stays. An agent that never looks from inside a callback
    /// keeps everything on the second list, in the first pass's order.
    std::deque<WeakCallbackData*> queued_finalizers;
    std::deque<WeakCallbackData*> unjudged_finalizers;
    /// WHERE THE FIRST PASS SAYS FINALIZERS WAIT: one byte of the agent's own
    /// - what its deferred teardown queue owes its next safe point
    /// (runtime.gc.DeferredTeardown.owedWord) - and the bit of it that means
    /// "finalizers" (`oweFinalizers`). BORROWED from the adapter's Zig side
    /// (v8_Isolate_SetFinalizersOwed: createAgent to the agent's end); null
    /// for an isolate with no queue, whose finalizers wait for the pump or a
    /// forced collection. The first pass calls nothing of Zig's for it: it
    /// stores.
    /// Read and written on the isolate's thread.
    uint8_t* finalizers_owed = nullptr;
    uint8_t finalizers_owed_mask = 0;
    /// The bit of the same byte that says "some finalizer has not been
    /// looked at by a callback's exit" (DeferredTeardown.Owed.fresh): set
    /// with the other when the first pass queues a record.
    uint8_t fresh_owed_mask = 0;
    /// `runQueuedFinalizers` is on the stack: a finalizer is running. The
    /// safe points inside a task - a binding's return into script, the
    /// external-memory report made there - run nothing beneath it
    /// (`runQueuedFinalizersInTask`).
    bool finalizers_running = false;
    /// The registry's end, and its memory.
    void (*node_wrappers_end)(void* registry) = nullptr;
    /// The instance of the node whose wrapper slot is `slot` - the last step
    /// of a node wrapper's unwrap (Object::Unwrap -> anchor -> slot -> node
    /// -> instance; design 4.3), the Zig side's: the adapter never reads a
    /// node's fields here.
    void* (*node_wrapper_instance)(void* slot) = nullptr;
    /// The agent's node anchors (the wrapper redesign's P4): the weak-callback
    /// registry on its C++ heap, rooted here while the Zig registry lives
    /// (v8_Isolate_SetNodeWrappers to v8_Isolate_Dispose's start, which
    /// clears it before Isolate::Dispose terminates the heap).
    cppgc::Persistent<NodeWrapperRegistry> node_anchors;
    /// The isolate's EmbedderRootsHandler (design 4.11, P8: Blink's
    /// BlinkRootsHandler), installed right after Isolate::Initialize
    /// (installNodeWrapperRootsHandler) and uninstalled before
    /// Isolate::Dispose; V8 does not own it (v8-isolate.h
    /// SetEmbedderRootsHandler).
    std::unique_ptr<NodeWrapperRootsHandler> roots_handler;
    /// Node wrappers V8 dropped in young-generation collections
    /// (NodeWrapperRootsHandler::ResetRoot), cumulative: diagnostics and
    /// tests/v8 (v8_test_NodeWrappers_Dropped).
    uint64_t node_wrappers_dropped = 0;
    /// The anchors of those wrappers, out of the registry, waiting for their
    /// free after the collection (freeDroppedAnchors, from the drain) - raw
    /// and untraced: nothing keeps them, so a full collection that comes
    /// first takes them (ProcessWeak drops them from here).
    std::vector<NodeAnchor*> dropped_anchors;
    /// The dropped anchors freed so far, and the frees cppgc refused because
    /// its heap was collecting (one per anchor per refusal): diagnostics and
    /// tests/v8 (engine.diagnosticCounters).
    uint64_t node_anchors_freed = 0;
    uint64_t node_anchor_frees_deferred = 0;
    /// What V8 was told of the pointer-table entries dropped wrappers left
    /// behind (`reportDroppedTableEntries`): the accounter, the bytes it
    /// holds now, and `node_wrappers_dropped` as it stood at the last full
    /// collection's start (the entries of every wrapper dropped before it
    /// were swept in it).
    ExternalMemoryAccounter table_accounter;
    size_t table_bytes_reported = 0;
    uint64_t table_dropped_base = 0;
#ifndef NDEBUG
    /// Debug: the v8_wrapper.cpp frames holding a NodeAnchor* now
    /// (NODE_ANCHOR_IN_FRAME) - none may be live across a requested
    /// collection, which is precise for the C++ heap
    /// (v8_Isolate_RequestGarbageCollection asserts it).
    int anchors_in_frames = 0;
#endif
    /// The walk (the wrapper redesign's P5; v8_Isolate_SetNodeWrapperTracing):
    /// a reached anchor's node's trees, from its Trace in the atomic pause
    /// (the record found as the current isolate's: collectingRecord); the
    /// kept nodes' trees, from the anchors' registry's Trace in the
    /// atomic pause; the end of each marking (the walk's per-collection sets
    /// go); and the oracle (-Dv8-wrapper-trace-check, else null), in the weak
    /// processing before any slot is emptied.
    void (*node_wrapper_trace_anchor)(void* registry, void* slot, cppgc::Visitor* visitor) = nullptr;
    void (*node_wrapper_trace_keeps)(void* registry, cppgc::Visitor* visitor) = nullptr;
    void (*node_wrappers_marked)(void* registry) = nullptr;
    void (*node_wrapper_trace_check)(void* registry, void* const* live, size_t live_len, void* const* dead, size_t dead_len) = nullptr;
    /// A holder wrapper's anchor was reached in a collection's atomic pause
    /// (HolderAnchor::Trace; the wrapper redesign's P6): the nodes its
    /// instance holds for script are traced through `visitor`
    /// (node_wrappers.zig `traceHolder`).
    void (*node_wrapper_trace_holder)(void* registry, void* instance, uint64_t generation, cppgc::Visitor* visitor) = nullptr;


    /// Take out the entry whose module is `module`, if any.
    SyntheticJsonExport* takeSyntheticExport(Local<Module> module) {
        for (size_t i = 0; i < synthetic_json_exports.size(); i++) {
            if (!(synthetic_json_exports[i]->module == module)) continue;
            SyntheticJsonExport* found = synthetic_json_exports[i];
            synthetic_json_exports.erase(synthetic_json_exports.begin() + i);
            return found;
        }
        return nullptr;
    }
};

// From 13.4 V8 frees a CppHeap given in CreateParams (1c079f473b1), so the
// record lets go of it once the isolate has it (IsolateData::cpp_heap).
static_assert(V8_MAJOR_VERSION > 13 || (V8_MAJOR_VERSION == 13 && V8_MINOR_VERSION >= 4),
              "a V8 before 13.4 never frees a CppHeap given in CreateParams: IsolateData::cpp_heap would have to own it");

/// Isolate::Initialize has attached `record`'s C++ heap: V8 owns it from now
/// on and deletes it in Isolate::Dispose (IsolateData::cpp_heap).
static void adoptCppHeap(IsolateData* record) {
    (void)record->cpp_heap.release();
}

/// `isolate`'s record, or null for an isolate this file did not make (the
/// snapshot creator's).
static IsolateData* isolateData(Isolate* isolate) {
    return isolate ? static_cast<IsolateData*>(isolate->GetData(kIsolateDataSlot)) : nullptr;
}

/// GCPauses' two callbacks, for mark-compacts only (kGCTypeMarkSweepCompact):
/// the prologue starts a pause, the matching epilogue records it.
static void gcPausePrologue(Isolate*, GCType, GCCallbackFlags, void* data) {
    GCPauses* pauses = static_cast<GCPauses*>(data);
    if (pauses->depth++ == 0) pauses->started = std::chrono::steady_clock::now();
}

/// A young-generation collection starts (GCPauses::minor_count).
static void gcMinorPrologue(Isolate*, GCType, GCCallbackFlags, void* data) {
    static_cast<GCPauses*>(data)->minor_count += 1;
}

static void gcPauseEpilogue(Isolate*, GCType, GCCallbackFlags, void* data) {
    GCPauses* pauses = static_cast<GCPauses*>(data);
    // An epilogue with no prologue of ours: a collection already running
    // when the callbacks were added.
    if (pauses->depth == 0) return;
    if (--pauses->depth != 0) return;
    const auto elapsed = std::chrono::steady_clock::now() - pauses->started;
    pauses->record(static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::microseconds>(elapsed).count()));
}

/// Record `isolate`'s full-collection pauses in its record from now on: right
/// after Isolate::Initialize, by each function that makes an isolate with a
/// record. The callbacks go with the isolate; the record outlives it
/// (v8_Isolate_Dispose deletes it after Isolate::Dispose). With them, the
/// isolate's metrics recorder (GCPhaseRecorder), which keeps the atomic
/// pause's phases in the record's GCPhaseStats.
static void installGCPauseRecorder(Isolate* isolate) {
    IsolateData* record = isolateData(isolate);
    if (!record) return;
    isolate->AddGCPrologueCallback(gcPausePrologue, &record->gc_pauses, kGCTypeMarkSweepCompact);
    isolate->AddGCEpilogueCallback(gcPauseEpilogue, &record->gc_pauses, kGCTypeMarkSweepCompact);
    isolate->AddGCPrologueCallback(gcMinorPrologue, &record->gc_pauses,
                                   static_cast<GCType>(kGCTypeScavenge | kGCTypeMinorMarkSweep));
#if CRANE_GC_PHASE_METRICS
    isolate->SetMetricsRecorder(std::make_shared<GCPhaseRecorder>(&record->gc_phases));
#endif
}

/// `isolate`'s full collections so far, their longest pause and the 95th
/// percentile of the most recent ones (GCPauses), in microseconds: all 0 for
/// a null isolate or one this file did not make. On the isolate's thread.
extern "C" void v8_Debug_FullGCPauses(Isolate* isolate, uint64_t* count, uint64_t* max_us, uint64_t* p95_us) {
    *count = 0;
    *max_us = 0;
    *p95_us = 0;
    IsolateData* record = isolateData(isolate);
    if (!record) return;
    *count = record->gc_pauses.count;
    *max_us = record->gc_pauses.max_us;
    *p95_us = record->gc_pauses.p95();
}

/// `isolate`'s young-generation collections so far (GCPauses::minor_count):
/// 0 for a null isolate or one this file did not make. On the isolate's
/// thread.
extern "C" uint64_t v8_Debug_MinorGCCount(Isolate* isolate) {
    IsolateData* record = isolateData(isolate);
    return record ? record->gc_pauses.minor_count : 0;
}

// ============================================================================
// The agent's finalizer queue and its safe points (lane v8up b6-b7)
// ============================================================================
//
// Every dead wrapper's Zig-side work waits here for the agent's safe point:
// a wrapper-cache entry's finalizer, queued by V8's first pass
// (`WeakCallbackWrapper`), and the node wrappers' releases, which the anchors'
// weak processing and the young generation's ResetRoot record and owe in
// the same collection ("Node wrappers on the agent's C++ heap", below;
// `noteNodeWrappersCollected`).

static void drainNodeWrappers(IsolateData* record);
static void noteNodeWrappersCollected(IsolateData* record);

/// The first pass queued a finalizer, or a collection recorded a node
/// wrapper's release: the agent's queue owes them to its next safe point - the
/// binding's return into script that finds the bit (dom_algorithm.zig
/// leaveToScript -> DeferredTeardown.leaveAlgorithmToScript). One store into
/// the agent's own byte; nothing of Zig's is called from V8's pass.
static inline void oweFinalizers(IsolateData* record, uint8_t bits) {
    if (record->finalizers_owed) *record->finalizers_owed |= bits;
}

/// Nothing waits any more - a drain ran every finalizer, at whichever safe
/// point: the queue owes none, so the next binding exit pays nothing for
/// them.
static inline void settleFinalizersOwed(IsolateData* record) {
    if (!record->finalizers_owed) return;
    if (!record->queued_finalizers.empty() || !record->unjudged_finalizers.empty() || record->node_wrappers_collected) return;
    *record->finalizers_owed &= static_cast<uint8_t>(~(record->finalizers_owed_mask | record->fresh_owed_mask));
}

/// A record's first pass has run: it waits on its agent's queue from here.
/// An isolate with no record - the snapshot creator's, or one whose disposal
/// has begun - has no safe point: the record stays where the first pass left
/// it (pendingFinalizers()), for its owner's end to cancel or
/// v8_Isolate_Dispose to free.
static void queueFinalizer(Isolate* isolate, WeakCallbackData* data) {
    IsolateData* record = isolateData(isolate);
    if (!record) return;
    record->unjudged_finalizers.push_back(data);
    oweFinalizers(record, record->finalizers_owed_mask | record->fresh_owed_mask);
}

/// Run the finalizer of `data`, a record a drain took off its list: the
/// record goes first, then the Zig finalizer runs unless its owner cancelled
/// it. Answers whether it ran.
static bool runFinalizerRecord(WeakCallbackData* data) {
    const ZigWeakCallbackFn finalize = data->finalize;
    void* const user_data = data->user_data;
    // Forgotten BEFORE calling into Zig, which disposes the handle and must
    // not find a finalizer to cancel. A cancelled record has no handle and
    // is in the detached set.
    if (data->handle) {
        auto& pending = pendingFinalizers();
        auto it = pending.find(static_cast<const void*>(data->handle));
        if (it != pending.end() && it->second == data) pending.erase(it);
    }
    {
        std::lock_guard<std::mutex> guard(weakDataLock());
        detachedWeakData().erase(data);
    }
    freeWeakData(data);
    if (!finalize) return false;
    finalize(user_data, 0);
    return true;
}

/// THE AGENT'S SAFE POINT for the finalizers of its collected wrappers: run
/// every queued one, oldest first, then the node wrappers' releases. Answers
/// whether anything ran. Call on the isolate's thread with the isolate
/// entered and nothing of V8's collector on the stack.
///
/// Where it is called, and so where a finalizer runs relative to tasks and
/// microtasks:
///   * v8_Platform_PumpMessageLoop, after the platform task it ran - a
///     collection V8's marking job finished among them - and before the
///     microtask checkpoint the event loop performs after each such task
///     (event_loop.pumpPlatformTasks): between two tasks of the agent, never
///     inside one or inside a checkpoint. It is where the task V8 posts for
///     FinalizationRegistry cleanup runs (HTML's
///     HostEnqueueFinalizationRegistryCleanupJob queues a task too).
///   * v8_Isolate_RequestGarbageCollection and
///     v8_Isolate_MemoryPressureNotification, after V8 returns: the
///     operations built on them promise what the collection found dead is
///     finalized when they return (engine.requestGarbageCollection,
///     notifyMemoryPressure) - as a browser's test-only gc() finalizes
///     before it returns.
///   * INSIDE A TASK (`runQueuedFinalizersInTask`): a binding's return into
///     script at DOM-algorithm depth zero, when a first pass has owed them
///     to the agent's queue (v8_Isolate_RunQueuedFinalizers, the queue's
///     finalizer steps), and the host's external-memory report made at that
///     same exit or at a microtask checkpoint outside a DOM algorithm
///     (v8_ExternalMemoryAccounter_Update, after V8 returns). Finalizers of
///     what a collection V8 ran by itself found dead - a scavenge an
///     allocation started, an allocation's last resort, the report's own -
///     run there, not a task later at the pump.
///   * INSIDE A CALLBACK (`v8_Isolate_RunFreshFinalizers`, not this
///     function): a binding's return into the script of the innermost
///     callback invocation runs the FRESH ones alone - objects a
///     script-called constructor made since that callback began.
/// A teardown hold (engine.deferTeardowns) is the Zig finalizer's own
/// business: it lists its entry for the hold's last resume, as before.
///
/// One record at a time, the next taken afresh: a finalizer may force a
/// collection, which runs this again beneath it (the collection promises
/// what it found dead is finalized when it returns), or end a realm, whose
/// cache cancels records still listed here. The safe points inside a task
/// never run it beneath itself (`finalizers_running`): what a collection
/// queues under a finalizer, the drain on the stack takes when that
/// finalizer returns.
static bool runQueuedFinalizers(Isolate* isolate) {
    IsolateData* record = isolateData(isolate);
    if (!record) return false;
    if (record->queued_finalizers.empty() && record->unjudged_finalizers.empty() && !record->node_wrappers_collected) {
        settleFinalizersOwed(record);
        return false;
    }
    HandleScope handle_scope(isolate);
    const bool was_running = record->finalizers_running;
    record->finalizers_running = true;
    bool ran = false;
    // The records a callback's exit set aside for depth zero first - they
    // are the older ones - then the rest, each list from its front.
    for (;;) {
        std::deque<WeakCallbackData*>& list =
            !record->queued_finalizers.empty() ? record->queued_finalizers : record->unjudged_finalizers;
        if (list.empty()) break;
        WeakCallbackData* data = list.front();
        list.pop_front();
        if (runFinalizerRecord(data)) ran = true;
    }
    if (record->node_wrappers_collected) {
        record->node_wrappers_collected = false;
        // The anchors scavenges dropped are freed and the recorded releases
        // go (`drainNodeWrappers`, "Node wrappers on the agent's C++ heap").
        drainNodeWrappers(record);
        ran = true;
    }
    record->finalizers_running = was_running;
    settleFinalizersOwed(record);
    return ran;
}

/// THE SAFE POINT INSIDE A TASK: `runQueuedFinalizers` for a caller on the
/// agent's stack while script runs - a binding returning into script at
/// DOM-algorithm depth zero, the external-memory report made there. False
/// when finalizers still wait because this is no place to run them:
///
///   * a finalizer is already on the stack (`finalizers_running`): one that
///     runs script, whose binding returns into it, runs no other finalizer
///     beneath itself. cppgc's sweeper has the same rule for a finalizer
///     that allocates - "Bail out for recursive sweeping calls. This can
///     happen when finalizers allocate new memory." (15.7.112.43 src/heap/
///     cppgc-internal/sweeper.cc:1197-1211, SweepForAllocationIfRunning,
///     `is_sweeping_on_mutator_thread_`) - and so has V8's own second pass,
///     which the adapter does not use
///     (src/handles/global-handles.cc:752-756, "Newly added callbacks will
///     always be run by the outermost GC run only");
///   * the returning binding left an exception pending (Isolate::
///     HasPendingException, src/api/api.cc:10065-10073): V8 hands an
///     exception thrown inside an API callback only to a TryCatch registered
///     before the throw, and the engine work of a finalizer - a script, a
///     call - would clear it silently ("Binding catch scopes", above): the
///     script would never see what its call threw.
/// The queue then keeps them owed, for the next exit or the pump.
static bool runQueuedFinalizersInTask(Isolate* isolate) {
    IsolateData* record = isolateData(isolate);
    if (!record) return true;
    if (record->finalizers_running) return false;
    if (isolate->HasPendingException()) {
        return record->queued_finalizers.empty() && record->unjudged_finalizers.empty() && !record->node_wrappers_collected;
    }
    runQueuedFinalizers(isolate);
    return true;
}

/// THE SAFE POINT INSIDE A CALLBACK: a binding returned into the script of
/// the innermost native-to-script callback invocation on the agent's stack,
/// with no other DOM algorithm between the two (DeferredTeardown.runFresh).
/// Only a FRESH finalizer runs here: one whose object a script-called
/// constructor made at or after that invocation began - every DOM algorithm
/// on the stack has been suspended in its call into script since before the
/// object existed, so none holds a pointer to it (finalizer_safe_point.zig,
/// "Inside a callback"). `stamp_of` answers when a record's object was made
/// on the agent's callback clock (0: never fresh - the default); `innermost`
/// and `outermost` are when the innermost and the outermost invocation on
/// the stack began.
///
/// Every record no callback's exit has looked at yet, and every one that
/// waited for an outer callback, is looked at once: stamped at or after
/// `innermost`, it runs; at or after `outermost`, it stays - script will be
/// back in a callback it is fresh for (`*waiting` gets the newest such
/// stamp, for DeferredTeardown.leaveCallback to owe the next look); anything
/// else joins the records that wait for depth zero and is not looked at
/// again. Nothing here touches the node wrappers' releases.
///
/// The two rules of `runQueuedFinalizersInTask` hold: not beneath a running
/// finalizer, not while the returning binding's exception is pending - then
/// nothing is looked at and the answer is false.
extern "C" bool v8_Isolate_RunFreshFinalizers(Isolate* isolate, uint32_t innermost, uint32_t outermost,
                                              uint32_t (*stamp_of)(ZigWeakCallbackFn finalize, void* user_data),
                                              uint32_t* waiting) {
    *waiting = 0;
    IsolateData* record = isolateData(isolate);
    if (!record || !stamp_of) return true;
    if (record->finalizers_running) return false;
    if (isolate->HasPendingException()) return record->unjudged_finalizers.empty();
    if (record->unjudged_finalizers.empty()) {
        if (record->finalizers_owed) *record->finalizers_owed &= static_cast<uint8_t>(~record->fresh_owed_mask);
        return true;
    }
    HandleScope handle_scope(isolate);
    record->finalizers_running = true;
    // Taken whole: a finalizer may collect, and what that collection's first
    // pass queues joins the (now empty) list behind the records kept here.
    std::deque<WeakCallbackData*> looking;
    looking.swap(record->unjudged_finalizers);
    std::deque<WeakCallbackData*> kept;
    uint32_t newest_kept = 0;
    while (!looking.empty()) {
        WeakCallbackData* data = looking.front();
        looking.pop_front();
        // Cancelled while it waited: the record goes, uncalled.
        const uint32_t stamp = data->finalize ? stamp_of(data->finalize, data->user_data) : UINT32_MAX;
        if (stamp != 0 && stamp >= innermost) {
            runFinalizerRecord(data);
        } else if (stamp != 0 && stamp >= outermost) {
            kept.push_back(data);
            if (stamp > newest_kept) newest_kept = stamp;
        } else {
            record->queued_finalizers.push_back(data);
        }
    }
    const bool arrived = !record->unjudged_finalizers.empty();
    for (WeakCallbackData* data : record->unjudged_finalizers) kept.push_back(data);
    record->unjudged_finalizers.swap(kept);
    record->finalizers_running = false;
    *waiting = newest_kept;
    // Looked at, every one - unless a finalizer's own collection queued more.
    if (!arrived && record->finalizers_owed) *record->finalizers_owed &= static_cast<uint8_t>(~record->fresh_owed_mask);
    settleFinalizersOwed(record);
    return true;
}

/// The agent's queue owes finalizers and a binding returned into script at
/// DOM-algorithm depth zero (the queue's finalizer steps,
/// finalizer_safe_point.zig): run them (`runQueuedFinalizersInTask`). False
/// when they still wait. On the isolate's thread, the isolate entered.
extern "C" bool v8_Isolate_RunQueuedFinalizers(Isolate* isolate) {
    if (!isolate) return true;
    return runQueuedFinalizersInTask(isolate);
}

/// Where `isolate`'s first passes say that finalizers wait
/// (IsolateData::finalizers_owed): `word`, a byte of the agent's that stays
/// valid until this is called again, and the bit `mask` of it; null
/// withdraws it (the agent's end, before its queue can go). What already
/// waits is owed at once. On the isolate's thread.
extern "C" void v8_Isolate_SetFinalizersOwed(Isolate* isolate, uint8_t* word, uint8_t mask, uint8_t fresh_mask) {
    IsolateData* record = isolateData(isolate);
    if (!record) return;
    record->finalizers_owed = word;
    record->finalizers_owed_mask = word ? mask : 0;
    record->fresh_owed_mask = word ? fresh_mask : 0;
    if (!record->queued_finalizers.empty() || record->node_wrappers_collected) oweFinalizers(record, record->finalizers_owed_mask);
    if (!record->unjudged_finalizers.empty()) oweFinalizers(record, record->finalizers_owed_mask | record->fresh_owed_mask);
}

/// Finalizers on `isolate`'s queue that their owners have not cancelled: a
/// collection's first pass has run and the agent's safe point has not
/// (tests). 0 for an isolate with no record.
extern "C" size_t v8_Debug_QueuedFinalizers(Isolate* isolate) {
    IsolateData* record = isolateData(isolate);
    if (!record) return 0;
    size_t waiting = 0;
    for (const WeakCallbackData* data : record->queued_finalizers) {
        if (data->finalize) waiting++;
    }
    for (const WeakCallbackData* data : record->unjudged_finalizers) {
        if (data->finalize) waiting++;
    }
    return waiting;
}

/// What v8_Debug_NodeAnchorStats reads (ffi.zig's NodeAnchorStats mirrors
/// it): the agent's node anchors now - in its registry, or dropped by a
/// scavenge and waiting for their free -, the frees so far and the ones
/// cppgc refused, and GCPhaseStats.
struct CraneNodeAnchorStats {
    uint64_t registered;
    uint64_t dropped_waiting;
    uint64_t freed;
    uint64_t frees_deferred;
    uint64_t weak_ns_max;
    uint64_t weak_slots_max;
    int64_t atomic_us_max;
    int64_t atomic_mark_us_max;
    int64_t atomic_weak_us_max;
    int64_t atomic_compact_us_max;
    int64_t atomic_sweep_us_max;
    int64_t cpp_us_max;
    int64_t cpp_mark_us_max;
    int64_t cpp_weak_us_max;
    int64_t cpp_compact_us_max;
    int64_t cpp_sweep_us_max;
};

/// `isolate`'s node anchors and the phases of its full collections' atomic
/// pauses (GCPhaseStats), for engine.diagnosticCounters: all 0 for a null
/// isolate or one this file did not make. On the isolate's thread.
extern "C" void v8_Debug_NodeAnchorStats(Isolate* isolate, CraneNodeAnchorStats* out) {
    *out = CraneNodeAnchorStats{};
    IsolateData* record = isolateData(isolate);
    if (!record) return;
    if (NodeWrapperRegistry* registry = record->node_anchors.Get()) out->registered = registry->anchors.size();
    out->dropped_waiting = record->dropped_anchors.size();
    out->freed = record->node_anchors_freed;
    out->frees_deferred = record->node_anchor_frees_deferred;
    const GCPhaseStats& phases = record->gc_phases;
    out->weak_ns_max = phases.anchor_weak_ns_max;
    out->weak_slots_max = phases.anchor_weak_slots_max;
    out->atomic_us_max = phases.atomic_us_max;
    out->atomic_mark_us_max = phases.atomic_mark_us_max;
    out->atomic_weak_us_max = phases.atomic_weak_us_max;
    out->atomic_compact_us_max = phases.atomic_compact_us_max;
    out->atomic_sweep_us_max = phases.atomic_sweep_us_max;
    out->cpp_us_max = phases.cpp_us_max;
    out->cpp_mark_us_max = phases.cpp_mark_us_max;
    out->cpp_weak_us_max = phases.cpp_weak_us_max;
    out->cpp_compact_us_max = phases.cpp_compact_us_max;
    out->cpp_sweep_us_max = phases.cpp_sweep_us_max;
}

// ============================================================================
// Node wrappers on the agent's C++ heap (the wrapper redesign's P4)
// ============================================================================
//
// tmp/redesign/wrapper-redesign-design.md section 7, P4 (4.1-4.5, 4.8, 4.9).
// A node's one wrapper per agent is a `TracedReference<Object>` in the node's
// own engine.NodeWrapperSlot (8 bytes of its NodeBase; node_wrappers.zig) -
// Blink's `ScriptWrappable::wrapper_` (a TraceWrapperV8Reference,
// third_party/blink/renderer/platform/bindings/script_wrappable.h) - and the
// wrapper points at a NodeAnchor on the agent's C++ heap through
// `Object::Wrap` (design 4.2): a node interface's template has NO internal
// fields (interface.zig), so the wrapper is 16 bytes, and unwrapping it is
// `Object::Unwrap` under kNodeAnchorTag (design 4.3).
//
// - Reachability is V8's: a reachable wrapper marks its anchor (V8's marker
//   follows the CppHeap pointer, MarkingVisitorBase::VisitCppHeapPointer),
//   whose Trace marks the TracedReference in the slot. A slot is never a
//   root: a TracedReference lives only while something traces it in every
//   major GC (TracedHandles::ResetDeadNodes frees every unmarked node).
// - Collection: the registry's ProcessWeak, in the atomic pause, finds the
//   anchors that died and hands each one's slot to the Zig side, which writes
//   it empty (raw: V8 frees the unmarked TracedNode in the same pause;
//   TracedReference::Reset would free it twice) and records the release. No
//   V8 call, no count change, no free. The drain - the counts' release -
//   runs after the collection, at the agent's safe point
//   (`runQueuedFinalizers`: lane v8up's finalizer queue), owed to it by the
//   collection that recorded them (`noteNodeWrappersCollected`).
// - Keeps (a node's pending activity): a cppgc::Persistent on the anchor
//   (v8_NodeWrapper_Root) - a traced root, its own slot only (design 7 P4).
// - The node's teardown under a live wrapper, and the agent's end: the
//   anchor's slot is cleared (the wrapper reaches no node through it: a
//   TypeError at the binding's unwrap) and the slot Reset - V8 frees its
//   TracedNode - before the counted reference goes (design 4.9).
//
// The slot's address doubles as the BORROWED handle the binding passes
// around (node_wrappers.wrapperOf), as it did with P2's in-place Global: a
// TracedReference and a Global are both an IndirectHandleBase - one
// `internal::Address*` - and the only operations a borrower may apply, Get /
// Local::New / IsEmpty / ReturnValue::Set, read that one word identically
// for both (IndirectHandleBase::value; v8-local-handle.h's two Local::New
// overloads, v8-function-callback.h's two ReturnValue::Set overloads). A
// borrower never disposes, re-arms or tags a node wrapper's handle - none
// ever did with P2's Global either: it lived in the node.

static_assert(std::is_base_of_v<api_internal::IndirectHandleBase, TracedReference<Object>> &&
                  std::is_base_of_v<api_internal::IndirectHandleBase, Global<Object>> &&
                  sizeof(TracedReference<Object>) == sizeof(Global<Object>),
              "a node wrapper's slot is read through the Global<Object>* every borrower holds");

/// Debug: a frame that holds a NodeAnchor* says so for its extent
/// (IsolateData::anchors_in_frames). The precise requested collection's
/// invariant, checked there: Crane's frames hold nodes (an Instance, a
/// NodeBase - counted while anything needs them), never a NodeAnchor*
/// across a collection; an anchor is kept by its wrapper, which a frame
/// that uses the node keeps (a receiver, an argument: V8's own handles).
#ifndef NDEBUG
struct NodeAnchorInFrame {
    explicit NodeAnchorInFrame(Isolate* isolate) : record_(isolateData(isolate)) {
        if (record_) ++record_->anchors_in_frames;
    }
    ~NodeAnchorInFrame() {
        if (record_) --record_->anchors_in_frames;
    }
    NodeAnchorInFrame(const NodeAnchorInFrame&) = delete;
    NodeAnchorInFrame& operator=(const NodeAnchorInFrame&) = delete;
    IsolateData* record_;
};
#define NODE_ANCHOR_IN_FRAME(isolate) NodeAnchorInFrame node_anchor_in_frame_(isolate)
#else
#define NODE_ANCHOR_IN_FRAME(isolate) ((void)0)
#endif

/// The node anchor `object` - a wrapper, or a legacy platform object's proxy
/// around one - points at, or null: not an API wrapper (Object::Unwrap reads
/// the CppHeap pointer field only API wrappers have), never wrapped, or
/// wrapped under another tag.
static NodeAnchor* nodeAnchorOf(Isolate* isolate, Local<Object> object) {
    if (object->IsProxy()) {
        Local<Value> target = object.As<Proxy>()->GetTarget();
        if (!target->IsObject()) return nullptr;
        object = target.As<Object>();
    }
    if (!object->IsApiWrapper()) return nullptr;
    return Object::Unwrap<NodeAnchor>(isolate, object, kNodeAnchorTagRange);
}

/// The platform anchor `object` - a wrapper, or a legacy platform object's
/// proxy around one - points at, or null: not an API wrapper, never bound, a
/// node's wrapper (its anchor is a NodeAnchor), or a realm's global.
static PlatformAnchor* platformAnchorOf(Isolate* isolate, Local<Object> object) {
    if (object->IsProxy()) {
        Local<Value> target = object.As<Proxy>()->GetTarget();
        if (!target->IsObject()) return nullptr;
        object = target.As<Object>();
    }
    if (!object->IsApiWrapper()) return nullptr;
    return Object::Unwrap<PlatformAnchor>(isolate, object, crane_tags::kPlatformObjectAnchorRange);
}

/// THE read of a platform object's instance: what `object` - a wrapper of any
/// kind, or a legacy platform object's proxy around one - reaches, or null.
/// Blink's ToAnyScriptWrappable is one Object::Unwrap under the range of every
/// wrappable's tag (platform/bindings/wrapper_type_info.h:206-223); Crane has
/// three kinds of wrapper, asked in this order:
/// 1. a non-node platform object's: its PlatformAnchor's instance (null once
///    severed);
/// 2. a node's: its NodeAnchor's slot, the node, its instance (design 4.3);
/// 3. a realm's global: internal field 0, which a [Global] interface's
///    template alone still has (realm_global.zig; v8_GlobalAnchor_Attach) -
///    and so any object made from a template with a field whose field 0 was
///    given an instance (tests/v8's own mock platform objects).
/// Which interface the instance implements is the caller's brand check, the
/// instance's state ancestry. `IsApiWrapper()` guards the Unwraps: only an
/// API object has the CppHeap pointer field they read.
static void* instanceOfObject(Isolate* isolate, Local<Object> object) {
    if (object->IsProxy()) {
        Local<Value> target = object.As<Proxy>()->GetTarget();
        if (!target->IsObject()) return nullptr;
        object = target.As<Object>();
    }
    if (object->IsApiWrapper()) {
        if (PlatformAnchor* anchor = Object::Unwrap<PlatformAnchor>(isolate, object, crane_tags::kPlatformObjectAnchorRange)) {
            return anchor->instance_;
        }
        NODE_ANCHOR_IN_FRAME(isolate);
        if (NodeAnchor* anchor = Object::Unwrap<NodeAnchor>(isolate, object, kNodeAnchorTagRange)) {
            if (!anchor->slot_) return nullptr;
            IsolateData* record = isolateData(isolate);
            if (!record || !record->node_wrapper_instance) return nullptr;
            return record->node_wrapper_instance(anchor->slot_);
        }
    }
    if (object->InternalFieldCount() < 1) return nullptr;
    return object->GetAlignedPointerFromInternalField(isolate, 0, kCraneEmbedderDataTag);
}

/// NodeAnchor::Trace's step 2: the walk from the anchor's node, through the
/// record's callback (node_wrappers.zig `traceAnchor`).
static void traceAnchorTree(IsolateData* record, void* slot, cppgc::Visitor* visitor) {
    if (record->node_wrappers && record->node_wrapper_trace_anchor) record->node_wrapper_trace_anchor(record->node_wrappers, slot, visitor);
}

/// HolderAnchor::Trace's work: the holder's held nodes, through the record's
/// callback (node_wrappers.zig `traceHolder`).
static void traceHolderNodes(IsolateData* record, void* instance, uint64_t generation, cppgc::Visitor* visitor) {
    if (record->node_wrappers && record->node_wrapper_trace_holder) record->node_wrapper_trace_holder(record->node_wrappers, instance, generation, visitor);
}

void NodeWrapperRegistry::Trace(cppgc::Visitor* visitor) const {
    visitor->RegisterWeakCallbackMethod<NodeWrapperRegistry, &NodeWrapperRegistry::ProcessWeak>(this);
    IsolateData* record = record_;
    if (!record->node_wrappers || !record->node_wrapper_trace_keeps) return;
    IsolateData* collecting = collectingRecord(this);
    if (!collecting) return;
    if (collecting != record) {
        fprintf(stderr, "v8_wrapper: an agent's node anchor registry was traced in another agent's collection\n");
        abort();
    }
    record->node_wrapper_trace_keeps(record->node_wrappers, visitor);
}

void NodeWrapperRegistry::ProcessWeak(const cppgc::LivenessBroker& broker) {
    IsolateData* record = record_;
    // The walk's oracle (-Dv8-wrapper-trace-check), while every slot still holds
    // what marking saw.
    if (record->node_wrappers && record->node_wrapper_trace_check) {
        std::vector<void*> live;
        std::vector<void*> dead;
        for (NodeAnchor* anchor : anchors) {
            if (!anchor->slot_) continue;
            (broker.IsHeapObjectAlive(anchor) ? live : dead).push_back(anchor->slot_);
        }
        record->node_wrapper_trace_check(record->node_wrappers, live.data(), live.size(), dead.data(), dead.size());
    }
    // GCPhaseStats: the time of the walk over the slots below (the oracle
    // above and the walk's end below are not the slots' cost), and how many.
    const auto started = std::chrono::steady_clock::now();
    std::vector<NodeAnchor*>& dropped = record->dropped_anchors;
    const uint64_t slots = anchors.size() + dropped.size();
    // Anchors whose wrapper a scavenge dropped and whose free has not run
    // (refused while the heap collected, or its drain still to come): nothing
    // reached them, so they die here and the sweep takes them - off the list,
    // which must not name freed memory. One a stale word of the stack kept
    // (a conservative scan) stays for a later free.
    size_t waiting = 0;
    for (NodeAnchor* anchor : dropped) {
        if (broker.IsHeapObjectAlive(anchor)) dropped[waiting++] = anchor;
    }
    dropped.resize(waiting);
    size_t kept = 0;
    bool released = false;
    for (NodeAnchor* anchor : anchors) {
        if (broker.IsHeapObjectAlive(anchor)) {
            anchor->index_ = static_cast<uint32_t>(kept);
            anchors[kept++] = anchor;
            continue;
        }
        anchor->index_ = NodeAnchor::kUnregistered;
        // A dead anchor's fields read as they were until sweeping (cppgc:
        // weak callbacks run before the sweep).
        void* slot = anchor->slot_;
        if (!slot) continue;
        if (record->node_wrappers && record->node_wrapper_collected) {
            record->node_wrapper_collected(record->node_wrappers, slot);
            released = true;
        }
    }
    anchors.resize(kept);
    // The bookkeeping follows the live count down (P2's note: its chunks
    // never shrank): a collection that leaves a quarter of the capacity
    // used gives the rest back, above a floor.
    if (anchors.capacity() > kShrinkFloor && anchors.size() * 4 < anchors.capacity()) {
        std::vector<NodeAnchor*> smaller;
        smaller.reserve(anchors.size() * 2 > kShrinkFloor ? anchors.size() * 2 : kShrinkFloor);
        smaller.insert(smaller.end(), anchors.begin(), anchors.end());
        anchors.swap(smaller);
    }
    const auto elapsed = std::chrono::steady_clock::now() - started;
    const uint64_t ns = static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::nanoseconds>(elapsed).count());
    if (ns > record->gc_phases.anchor_weak_ns_max) record->gc_phases.anchor_weak_ns_max = ns;
    if (slots > record->gc_phases.anchor_weak_slots_max) record->gc_phases.anchor_weak_slots_max = slots;
    // The releases recorded above - and the frees of anchors still waiting
    // (one a stale word of the stack kept) - are owed to the agent's next
    // safe point: one flag and one byte, nothing of Zig's runs in the pause.
    if (released || !dropped.empty()) noteNodeWrappersCollected(record);
    // Marking is over: the walk's per-collection sets end.
    if (record->node_wrappers && record->node_wrappers_marked) record->node_wrappers_marked(record->node_wrappers);
}

// ---- The young generation (design 4.11, P8) ----
//
// A node's slot is a DROPPABLE TracedReference (v8_NodeWrapper_Attach): in a
// young-generation collection V8 treats it as weak instead of as a root when
// its wrapper is an "unmodified API object" - 15.7.112.43
// src/handles/traced-handles.cc:519-533 ComputeWeaknessProcessor:
// `node->is_droppable()` once `JSObject::IsUnmodifiedApiObject` holds
// (src/objects/js-objects.cc:3152-3168: a JS_API_OBJECT whose map is still
// its constructor's initial map, with no elements and no identity hash - not
// a WeakMap key; 13.1.203 had the same rule). Such a wrapper script cannot
// tell from a fresh one: no
// expando, no changed prototype, nothing keyed by it. When nothing else
// reaches it, V8 reclaims it in the scavenge and calls the isolate's
// EmbedderRootsHandler::ResetRoot (TracedHandles::ProcessWeakYoungObjects), on
// the isolate's thread, inside the collection, with the C++ heap's GC and
// allocation disallowed (:621-624). Blink's design, read at Chromium 131.0.6778.0 (the
// release on V8 13.1) and 145.0.7608.0 (461c62b66d7c), the same in both:
// - third_party/blink/renderer/platform/heap/thread_state.cc BlinkRootsHandler:
//   ResetRoot unwraps the dying wrapper (ToAnyScriptWrappable: Object::Unwrap
//   on the TracedReference itself) and clears the ScriptWrappable's inline
//   wrapper slot if it holds that very handle
//   (DOMDataStore::ClearWrapperInAnyWorldIfEqualTo, dom_data_store.h), CHECKing
//   that it found it; TryResetRoot does the same opportunistically.
// - DOMDataStore::SetWrapperInInlineStorage (dom_data_store.h) makes the
//   reference droppable when the type `SupportsDroppingWrapper()`
//   (wrapper_type_info.h: every type with a wrapper class id); nothing else is
//   added on top of V8's unmodified rule - V8 decides what is observable.
// Here ResetRoot clears the anchor's slot (the dead wrapper reaches no node),
// Resets the node's slot - which V8 requires: the Reset is what frees the
// TracedNode (TracedHandles::Destroy -> FreeNode; 15.7 then zaps the node and
// DCHECKs it is no longer in use, :587-590; 13.1.203 CHECKed it) - and records the
// wrapper's release for the drain, exactly as a full collection's weak
// processing does (NodeWrapperRegistry::ProcessWeak). The anchor leaves the
// registry there and is freed after the collection (freeDroppedAnchors: lane
// wr1 batch 8, the integrator's option (a), 2026-11-09 23:48 UTC) - until
// then it waited on the C++ heap for the next full collection, which V8
// schedules rarely.
// Kept nodes are never dropped: a keep's root makes the slot non-droppable
// (v8_NodeWrapper_Root) - a cppgc::Persistent is not consulted in a scavenge.
//
// THE RULE: only ResetRoot touches node memory - the node's slot, the
// anchor, the registry, the record, the Zig side's collected callback - and
// it runs on the isolate's own thread (checked below in Debug). TryResetRoot
// touches none of them: it answers false, and V8 then calls ResetRoot on the
// isolate's thread for that handle. Why the rule must be written down: who
// calls TryResetRoot depends on the V8 version.
// - V8 13.1.203 (linked until lane v8up's port): nothing did.
//   ProcessYoungObjects was a serial loop on the isolate's thread calling
//   ResetRoot only.
// - V8 15.7.112.43, the one Crane links (since b1ea3fc1dbf, 2025-02-24,
//   "[heap] Parallelize processing of young wrapper reclamation"):
//   src/handles/traced-handles.cc ProcessWeakYoungObjects runs
//   ClearWeaknessProcessor as a platform Job - up to 3 tasks, one per 8 young
//   blocks left (:432-447, --parallel_reclaim_unmodified_wrappers, on by
//   default, flag-definitions.h:2892). The joining thread - the isolate's -
//   calls ResetRoot; every worker calls TryResetRoot (:578-586), "called in
//   parallel for different handles and as such must be thread-safe"
//   (v8-embedder-heap.h), and a handle it answers false for marks its block
//   for reprocessing on the isolate's thread with ResetRoot (:592, :683-690).
//   After a ResetRoot V8 zaps the node itself (:588); the embedder's Reset
//   is still what frees it (TracedHandles::Destroy -> FreeNode, with
//   disable_block_handling_on_free_), as Blink's
//   DOMDataStore::ClearInlineStorageWrapperIfEqualTo Resets `wrapper_`.
//   A TryResetRoot that touched a node would race the agent's thread on node
//   memory, which no other thread ever reads (the node pool's owner-thread
//   design, tmp/redesign/node-memory-architecture.md 3.5) - so it never does,
//   whatever it would make cheaper. Blink's TryResetRoot does the work
//   opportunistically because its ScriptWrappables' slots tolerate it;
//   Crane's node memory does not.
// Pinned by tests/v8/wr10_young_drop_thread_test.zig: a scavenge that drops
// more than 8 young blocks' worth of node wrappers empties every slot
// through ResetRoot on the agent's thread, however many of them V8's workers
// offered to TryResetRoot first (v8_test_NodeWrappers_TryResetRootCalls). A
// V8 upgrade re-reads TracedHandles::ProcessWeakYoungObjects and every
// caller of TryResetRoot before this compiles again.
static_assert(V8_MAJOR_VERSION == 15 && V8_MINOR_VERSION == 7,
              "the young-generation EmbedderRootsHandler contract was read from V8 15.7.112.43: re-read "
              "TracedHandles::ProcessWeakYoungObjects / TryResetRoot before upgrading");

class NodeWrapperRootsHandler final : public EmbedderRootsHandler {
 public:
    /// Made on the isolate's own thread, right after Isolate::Initialize
    /// (installNodeWrapperRootsHandler) - the agent's thread, the one thread
    /// that touches its nodes.
    explicit NodeWrapperRootsHandler(Isolate* isolate) : isolate_(isolate), owner_(std::this_thread::get_id()) {}

    void ResetRoot(const TracedReference<Value>& handle) final {
#ifndef NDEBUG
        // The rule above: node memory is touched on the agent's thread only.
        if (std::this_thread::get_id() != owner_) {
            fprintf(stderr, "v8_wrapper: ResetRoot called off the isolate's own thread - only TryResetRoot may run on "
                            "V8's workers, and it touches no node\n");
            abort();
        }
#endif
        const TracedReference<Object>& traced = handle.As<Object>();
        // Only node slots are droppable, and only node wrappers are Wrapped
        // under the anchors' tag. The dying wrapper's CppHeap pointer still
        // reads its anchor (Blink's ToAnyScriptWrappable, the same read).
        NodeAnchor* anchor = Object::Unwrap<NodeAnchor>(isolate_, traced, kNodeAnchorTagRange);
        void* slot = anchor ? anchor->slot_ : nullptr;
        TracedReference<Object>* reference = static_cast<TracedReference<Object>*>(slot);
        // V8 found the handle, so the node's slot must hold it (Blink:
        // CHECK(success)); a slot a teardown ended was Reset, and V8 never
        // finds its handle again.
        if (!reference || !(*reference == traced)) {
            fprintf(stderr, "v8_wrapper: ResetRoot for a wrapper whose node slot does not hold it\n");
            abort();
        }
#ifndef NDEBUG
        // A kept node's slot is non-droppable (v8_NodeWrapper_Root), so V8
        // never drops a wrapper whose anchor a keep's root holds - freeing
        // that anchor would leave the root naming freed memory.
        if (anchor->roots_ != 0) {
            fprintf(stderr, "v8_wrapper: ResetRoot for a kept node's wrapper (%u roots on its anchor)\n", anchor->roots_);
            abort();
        }
#endif
        anchor->slot_ = nullptr;
        reference->Reset();
        IsolateData* record = isolateData(isolate_);
        if (!record) return;
        record->node_wrappers_dropped += 1;
        // The anchor is garbage now: its wrapper is dead, its slot cleared,
        // and no root holds it. It leaves the registry here - O(1), the
        // registry's own bookkeeping, no V8 call and no C++-heap allocation
        // (V8 forbids both: ProcessYoungObjects enters cppgc's no-GC and
        // disallow-GC scopes around ResetRoot) - and waits on the record for
        // its free, which cppgc allows only outside a collection: the drain
        // (freeDroppedAnchors).
        if (NodeWrapperRegistry* registry = record->node_anchors.Get()) {
            registry->remove(anchor);
            record->dropped_anchors.push_back(anchor);
        }
        if (record->node_wrappers && record->node_wrapper_collected) record->node_wrapper_collected(record->node_wrappers, slot);
        // The anchor's free and the wrapper's release are owed to the agent's
        // next safe point (one flag and one byte: no V8 call, no allocation).
        noteNodeWrappersCollected(record);
    }

    /// Runs on V8's worker threads (15.7: the comment above). It reads
    /// nothing of the handle and touches no node, anchor, registry or
    /// record: it counts the call on the handler's own atomic and answers
    /// false, so the handle goes to ResetRoot on the isolate's thread.
    bool TryResetRoot(const TracedReference<Value>&) final {
        try_reset_root_calls_.fetch_add(1, std::memory_order_relaxed);
        return false;
    }

    /// TryResetRoot's calls so far (v8_test_NodeWrappers_TryResetRootCalls).
    uint64_t tryResetRootCalls() const { return try_reset_root_calls_.load(std::memory_order_relaxed); }

 private:
    Isolate* isolate_;
    std::thread::id owner_;
    std::atomic<uint64_t> try_reset_root_calls_{0};
};

/// Install `isolate`'s EmbedderRootsHandler: right after Isolate::Initialize,
/// by each function that makes an isolate with a record (Blink: ThreadState::
/// AttachToIsolate). v8_Isolate_Dispose uninstalls it.
static void installNodeWrapperRootsHandler(Isolate* isolate) {
    IsolateData* record = isolateData(isolate);
    if (!record) return;
    record->roots_handler = std::make_unique<NodeWrapperRootsHandler>(isolate);
    isolate->SetEmbedderRootsHandler(record->roots_handler.get());
}

/// Whether the C++ heap holding `handle` is collecting: in its atomic pause,
/// marking, or sweeping - when cppgc refuses an explicit free and returns
/// without freeing (15.7.112.43 src/heap/cppgc-internal/explicit-management.cc:21-35
/// InGC: `in_atomic_pause() || marker() || sweeper().IsSweepingInProgress()`).
/// The public HeapState reads the same three, with one difference: IsMarking
/// is `marker() && marker->IsMarking()`. The two agree wherever a drain runs:
/// the marker exists from MarkCompactCollector::StartMarking
/// (CppHeap::InitializeMarking) and is_marking_ from CppHeap::StartMarking,
/// and no embedder callback runs between them - an incremental start calls
/// the prologue callbacks before both and the epilogue callbacks after both
/// (incremental-marking.cc IncrementalMarking::StartMarkingMajor, heap.cc:3817-3825),
/// an atomic one calls the prologue before Prepare; the marker goes in the
/// atomic pause (CppHeap::FinishMarkingAndProcessWeakness) right after
/// is_marking_ (MarkerBase::LeaveAtomicPause).
static bool cppHeapCollecting(const cppgc::HeapHandle& handle) {
    return cppgc::subtle::HeapState::IsInAtomicPause(handle) || cppgc::subtle::HeapState::IsMarking(handle) ||
           cppgc::subtle::HeapState::IsSweeping(handle);
}

/// The anchors whose wrapper a young-generation collection dropped
/// (NodeWrapperRootsHandler::ResetRoot) are freed: cppgc::subtle::
/// FreeUnreferencedObject, the C++ heap's explicit free - Blink's only use is
/// its collection backings (HeapVectorBacking::Free, HeapHashTableBacking::
/// Free; third_party/blink/renderer/platform/heap/heap_allocator_impl.h,
/// Chromium 145.0.7608.0), whose memory it returns to the page's linear
/// allocation buffer or free list. Run from the drain, outside any
/// collection's atomic pause.
///
/// The embedder's guarantee, "no other reference" (explicit-management.h):
/// - its wrapper is dead - V8 dropped it, and ResetRoot cleared the anchor's
///   slot;
/// - no root: a kept node's slot is non-droppable, so its wrapper is never
///   dropped (ResetRoot checks it in Debug);
/// - the registry let go of it in ResetRoot, and this list is the only
///   other pointer to it - emptied here, or by the weak processing when a
///   full collection takes the anchor first;
/// - the dead wrapper's CppHeapPointerTable entry still holds the anchor's
///   address, as a number nothing reads: the wrapper is unreachable, so no
///   unwrap and no marker visits it, and the table frees the unmarked entry
///   at the next full collection without reading its payload (15.7.112.43
///   src/sandbox/cppheap-pointer-table.cc:16 CppHeapPointerTable::SweepAndCompact,
///   called only from mark-compact.cc:3419; a scavenge never touches the
///   table). An entry is born unmarked outside a marking cycle
///   (cppheap-pointer-table-inl.h:17-31, :143-147: mark_as_alive only while
///   the space allocates black), so a dead wrapper's entry goes at the FIRST
///   full collection after it - 13.1.203 born-marked every entry and kept it
///   for two (fixed upstream in 60611ef018b; lane wr1 batch 10);
/// - a stale word of the stack naming it is harmless: a conservative scan
///   ignores free-list entries and the linear allocation buffer
///   (BasePage::TryObjectHeaderFromInnerAddress).
///
/// While the C++ heap collects, cppgc refuses (cppHeapCollecting): each
/// refusal is counted and the anchors wait for the next drain - or for the
/// next full collection, which takes them (ProcessWeak drops them here).
/// Newest first: each anchor that ends at the linear allocation buffer's
/// start goes back into it (explicit-management.cc), so a run allocated
/// together and dropped together is reused by bump allocation.
static void freeDroppedAnchors(IsolateData* record) {
    std::vector<NodeAnchor*>& dropped = record->dropped_anchors;
    if (dropped.empty()) return;
    cppgc::HeapHandle& heap = cppgc::internal::BasePageHandle::FromPayload(dropped.front())->heap_handle();
    if (cppHeapCollecting(heap)) {
        record->node_anchor_frees_deferred += dropped.size();
        return;
    }
    for (auto it = dropped.rbegin(); it != dropped.rend(); ++it) {
        NodeAnchor* anchor = *it;
#ifndef NDEBUG
        if (anchor->slot_ || anchor->index_ != NodeAnchor::kUnregistered || anchor->roots_ != 0) {
            fprintf(stderr, "v8_wrapper: freeing a node anchor that is still in use\n");
            abort();
        }
#endif
        cppgc::subtle::FreeUnreferencedObject(heap, *anchor);
    }
    record->node_anchors_freed += dropped.size();
    dropped.clear();
    // The list follows the drops down, as the registry does.
    if (dropped.capacity() > NodeWrapperRegistry::kShrinkFloor) {
        std::vector<NodeAnchor*>().swap(dropped);
        dropped.reserve(NodeWrapperRegistry::kShrinkFloor);
    }
}

// ---- The pointer-table entries dropped wrappers leave (lane wr1 b11) ----
//
// A node wrapper is Wrapped (v8::Object::Wrap): V8 keeps its anchor's address
// in the isolate's CppHeapPointerTable, 8 bytes an entry. A young-generation
// collection that drops the wrapper leaves the entry: the table is swept by
// full collections only (15.7.112.43 src/heap/mark-compact.cc:3419, the one
// call of CppHeapPointerTable::SweepAndCompact; src/heap/scavenger.cc never
// names the table). And V8 counts the table toward no limit: what it weighs
// against its global limit is the old generation, the C++ heap and the
// external memory an embedder reports (src/heap/heap.cc:5353-5360
// GlobalSizeOfObjects).
//
// In Blink that is harmless, because a dropped wrapper's ScriptWrappable
// stays on the C++ heap until a full collection - BlinkRootsHandler::ResetRoot
// only clears the reference (third_party/blink/renderer/platform/heap/
// thread_state.cc:38-66, Chromium 157) - and the C++ heap's growth is what
// V8's limits see (src/heap/cppgc-js/cpp-heap.cc:1094-1150,
// CppHeap::ReportBufferedAllocationSizeIfPossible): the collection that
// frees those objects sweeps their entries. Crane frees a dropped wrapper's
// anchor at once (`freeDroppedAnchors`) and its node by the counts (WebKit's
// model: a dead wrapper's Weak is finalized at its block's sweep,
// Source/JavaScriptCore/heap/WeakBlock.cpp:176-199, and the node is
// reference-counted), so nothing V8 counts grows, no collection is asked
// for, and the entries pile up: 12,000,000 dropped wrappers ran 2 full
// collections and peaked at 135.7 MB where main ran 30 and peaked at 87.0
// (server1, gc_bench, 2026-11-13) - the table swept once, 64 MB at a time,
// in a 22.5 ms pause.
//
// So the adapter tells V8 what it cannot see: one table entry's size for
// every wrapper dropped since the last full collection, as external memory,
// through a v8::ExternalMemoryAccounter of its own (v8-external-memory-
// accounter.h: one per reporting owner; JavaScriptCore's counterpart is
// Heap::reportExtraMemoryAllocated, "to report non-GC memory referenced by
// GC objects", Source/JavaScriptCore/heap/Heap.h:448-459, WebKit main
// b7262265dfd). NEITHER Blink nor WebKit reports its wrapper table, and the
// reason Crane does what neither does is stated here because the user's
// standard is the browsers' behaviour: neither frees the wrapper's native
// half ahead of the collector; Crane does, and this is the account of what
// that leaves behind. (The alternative that IS Blink's shape - keep every
// dropped anchor until a full collection - was the redesign's state before
// lane wr1 b8 and cost 32 bytes a dropped wrapper instead of 8.) V8's own
// limit then paces the full collection that sweeps the table: the same run
// peaks at 74.3 MB with 14 full collections on server1, and on chat.local
// at 75.8 MiB against 137.2 without it and main's 82.3-82.7; over the perf
// suite x7 it reads time 0.978 and instructions 0.989 of main, no row
// slower (the integrator's ruling of 2026-11-13, measured first as a
// patch).
//
// The figure is an estimate, bounded both ways by one marking cycle's
// wrappers: an entry made while a full collection marks is born marked and
// outlives that collection (cppheap-pointer-table-inl.h:17-31), though its
// wrapper's drop was reported and taken back with the rest.
//
// Reported at the agent's drain (the report may start a collection: never
// from ResetRoot, which runs inside one). Taken back in the PROLOGUE of the
// next full collection - the entries are about to be swept in it - and not
// after it: V8 recomputes its limits before its epilogue callbacks
// (src/heap/heap.cc:1514 prologue callbacks, :1604 RecomputeLimits, :1621
// epilogue), so a figure taken back afterwards is still in the size the new
// limit is set from, and the limit ratchets (measured: the global limit
// alternated 20.2 / 27.8 MB against a steady 20.2, peak 83.4 against 74.3 MB;
// lane v8up b8's reading of heap-controller.cc:186-207).

/// The bytes of one CppHeapPointerTable entry; 0 in a build with no pointer
/// table (no pointer compression: an Object::Wrap pointer is stored in the
/// object itself).
#ifdef V8_COMPRESS_POINTERS
static constexpr size_t kWrapperTableEntryBytes = static_cast<size_t>(internal::kCppHeapPointerTableEntrySize);
#else
static constexpr size_t kWrapperTableEntryBytes = 0;
#endif

/// V8 is told of the entries the wrappers dropped since the last report
/// left. At the agent's safe point, the isolate entered: the report may run
/// a collection (Heap::UpdateExternalMemory), whose prologue takes the whole
/// figure back - so the figure is recorded before V8 is called.
static void reportDroppedTableEntries(IsolateData* record) {
    const size_t owed = static_cast<size_t>(record->node_wrappers_dropped - record->table_dropped_base) * kWrapperTableEntryBytes;
    if (owed <= record->table_bytes_reported) return;
    Isolate* isolate = Isolate::GetCurrent();
    if (!isolate) return;
    const size_t more = owed - record->table_bytes_reported;
    record->table_bytes_reported = owed;
    // The collecting isolate is the current one (collectingRecord).
    CollectingScope collecting(isolate);
    record->table_accounter.Increase(isolate, more);
}

/// The figure goes back to V8: a full collection is about to sweep the
/// table (its prologue), or the agent ends. A decrease starts no collection
/// (Heap::UpdateExternalMemory returns at `delta <= 0`), so it is safe in a
/// GC callback.
static void takeBackTableEntries(IsolateData* record, Isolate* isolate) {
    const size_t back = record->table_bytes_reported;
    record->table_bytes_reported = 0;
    record->table_dropped_base = record->node_wrappers_dropped;
    if (back) record->table_accounter.Decrease(isolate, back);
}

/// Before every full collection (kGCTypeMarkSweepCompact; an incremental
/// one calls it when its marking starts and again before its atomic pause).
static void tableEntriesPrologue(Isolate* isolate, GCType, GCCallbackFlags, void* data) {
    takeBackTableEntries(static_cast<IsolateData*>(data), isolate);
}

/// The agent's drain, now: V8 is told of the table entries the dropped
/// wrappers left, the anchors scavenges dropped are freed, and the releases
/// its collections recorded go (the Zig side defers them while a walk holds
/// the agent's teardowns). Only from the agent's safe point
/// (`runQueuedFinalizers`) - never inside a collection or one of V8's GC
/// callbacks.
static void drainNodeWrappers(IsolateData* record) {
    reportDroppedTableEntries(record);
    freeDroppedAnchors(record);
    if (record->node_wrappers && record->node_wrappers_drain) record->node_wrappers_drain(record->node_wrappers);
}

/// The node wrappers' drain is OWED to the agent's next safe point
/// (`runQueuedFinalizers`: a binding's return into script at DOM-algorithm
/// depth zero, the pump, a requested collection's return) - lane v8up's
/// finalizer queue, which the node wrappers' releases join where every other
/// finalizer does: in the collection that found the wrapper dead ("Why the
/// first pass queues", above). Called by that collection itself - the
/// anchors' weak processing in a full collection's atomic pause
/// (NodeWrapperRegistry::ProcessWeak) and the roots handler in a young one
/// (NodeWrapperRootsHandler::ResetRoot), both on the agent's thread - and it
/// only stores a flag and the agent's owed byte: no V8 call, no allocation,
/// nothing of Zig's.
///
/// Until lane wr1 b11 the releases were owed later, at the three points
/// where V8 runs a SECOND pass (the next collection's start, a forced
/// collection's end, a posted task: 15.7.112.43 src/handles/
/// global-handles.cc:874-903, src/heap/heap.cc:1509-1511), because WHEN a
/// node wrapper's reference was released decided what refcount step 7a's net
/// did with a detached tree only its realm's pending work still held:
/// released while the realm lived, the net declined and nothing looked
/// again (feature-queue "THE 7a NET'S HOLE"; lane v8up b7:
/// tests/html parser_implied_end_tags_test, 15 of 15 runs with the release
/// owed by the first pass). The net remembers such a tree now and looks
/// again at its realm's end (node_wrappers.zig `Registry.net_waiting`,
/// tests/v8/wr11_net_hole_test.zig), so the timing is the queue's own: a
/// dead tree's nodes go back to the allocator one collection sooner
/// (dom.clone-node 145.5 -> 126.7 MB, dom.create-element 84.0 -> 72.0 MB,
/// chat.local, 2026-11-13, x7). Nothing here depends on V8's second pass -
/// not on its being a task either (Isolate::SetMemorySaverMode makes it
/// synchronous, global-handles.cc:881-889).
static void noteNodeWrappersCollected(IsolateData* record) {
    record->node_wrappers_collected = true;
    oweFinalizers(record, record->finalizers_owed_mask);
}

/// Node anchors whose free cppgc refused - its lazy sweep was running
/// (`freeDroppedAnchors`) - are owed another try once a platform task has
/// run: V8 15.7's C++ heap finishes its sweep in foreground tasks
/// (src/heap/cppgc-internal/sweeper.cc:1028-1075, :1553-1576), so the pump
/// that ran one is where the refused free can succeed
/// (v8_Platform_PumpMessageLoop). Otherwise they wait for the next
/// collection that records anything, or for the full collection that takes
/// them (ProcessWeak).
static void oweWaitingAnchorFrees(Isolate* isolate) {
    IsolateData* record = isolateData(isolate);
    if (record && !record->dropped_anchors.empty()) noteNodeWrappersCollected(record);
}

/// The isolate's node wrapper registry (IsolateData::node_wrappers), or null
/// before the first node wrap and for an isolate this file did not make.
extern "C" void* v8_Isolate_NodeWrappers(Isolate* isolate) {
    IsolateData* record = isolateData(isolate);
    return record ? record->node_wrappers : nullptr;
}

/// The isolate takes `registry` over (IsolateData::node_wrappers), with its
/// collection callback, its drain, its end and its unwrap's last step - and
/// its anchors' registry is made on its C++ heap, rooted by the record.
/// False for an isolate with no record or no C++ heap (the snapshot
/// creator's): no node is wrapped there.
extern "C" bool v8_Isolate_SetNodeWrappers(Isolate* isolate, void* registry, void (*collected)(void*, void*),
                                           void (*drain)(void*), void (*end)(void*), void* (*instance_of)(void*)) {
    IsolateData* record = isolateData(isolate);
    if (!record) return false;
    CppHeap* heap = isolate->GetCppHeap();
    if (!heap) return false;
    record->node_anchors = cppgc::MakeGarbageCollected<NodeWrapperRegistry>(heap->GetAllocationHandle(), record);
    // The dropped wrappers' table entries leave V8's account as a full
    // collection begins (`reportDroppedTableEntries`).
    isolate->AddGCPrologueCallback(tableEntriesPrologue, record, kGCTypeMarkSweepCompact);
    record->node_wrappers = registry;
    record->node_wrapper_collected = collected;
    record->node_wrappers_drain = drain;
    record->node_wrappers_end = end;
    record->node_wrapper_instance = instance_of;
    return true;
}

/// The walk's four callbacks (node_wrappers.zig "The walk") into the
/// isolate's record, after v8_Isolate_SetNodeWrappers. False for an isolate
/// with no record.
extern "C" bool v8_Isolate_SetNodeWrapperTracing(Isolate* isolate, void (*trace_anchor)(void*, void*, cppgc::Visitor*),
                                                 void (*trace_keeps)(void*, cppgc::Visitor*),
                                                 void (*marked)(void*),
                                                 void (*check)(void*, void* const*, size_t, void* const*, size_t),
                                                 void (*trace_holder)(void*, void*, uint64_t, cppgc::Visitor*)) {
    IsolateData* record = isolateData(isolate);
    if (!record) return false;
    record->node_wrapper_trace_anchor = trace_anchor;
    record->node_wrapper_trace_keeps = trace_keeps;
    record->node_wrappers_marked = marked;
    record->node_wrapper_trace_check = check;
    record->node_wrapper_trace_holder = trace_holder;
    return true;
}

/// The API object a wrapper's anchor goes on: the wrapper itself, or - for
/// a legacy platform object (a NodeList, an HTMLCollection), whose wrapper
/// is a proxy - the API object behind it, which holds the internal fields
/// (the proxy keeps its target).
static Local<Object> anchorHolderOf(Local<Object> object) {
    if (object->IsProxy()) {
        Local<Value> target = object.As<Proxy>()->GetTarget();
        if (target->IsObject()) return target.As<Object>();
    }
    return object;
}

/// THE LINK (lane wrap1 b2; Blink's V8DOMWrapper::SetNativeInfo): `box`'s
/// object - a wrapper the binding made from an interface's instance template,
/// or the receiver V8 made for a constructor's NewTarget; a legacy platform
/// object's proxy stands for its target - reaches `instance` from here. Its
/// anchor is made on the isolate's C++ heap and the object Wrapped with it: a
/// HolderAnchor with the instance's slab `generation` when `holds_nodes` (its
/// type has VTable.trace_held_nodes), from which a collection that marks the
/// wrapper traces the nodes the instance holds; a PlatformAnchor otherwise.
/// A realm's global, whose template keeps internal field 0, has the instance
/// written there (its GlobalAnchor is v8_GlobalAnchor_Attach's).
///
/// False - and nothing bound - for an object that is no API object
/// (Object::Wrap needs one; every template's instance is) or an isolate with
/// no C++ heap. Made on the isolate's thread; `box` holds the object, so a
/// collection the anchor's allocation starts runs before the anchor exists
/// and takes nothing of it, and the Wrap's write barrier marks the anchor if
/// the wrapper is already marked.
extern "C" bool v8_PlatformObject_Bind(Isolate* isolate, Global<Object>* box, void* instance, uint64_t generation, bool holds_nodes) {
    HandleScope scope(isolate);
    Local<Object> wrappable = anchorHolderOf(box->Get(isolate));
    if (wrappable->InternalFieldCount() >= 1) {
        wrappable->SetAlignedPointerInInternalField(0, instance, kCraneEmbedderDataTag);
        return true;
    }
    CppHeap* heap = isolate->GetCppHeap();
    if (!heap || !wrappable->IsApiWrapper()) return false;
    if (holds_nodes) {
        HolderAnchor* anchor = cppgc::MakeGarbageCollected<HolderAnchor>(heap->GetAllocationHandle(), instance, generation);
        Object::Wrap<kHolderAnchorTag>(isolate, wrappable, anchor);
    } else {
        PlatformAnchor* anchor = cppgc::MakeGarbageCollected<PlatformAnchor>(heap->GetAllocationHandle(), instance);
        Object::Wrap<kPlatformAnchorTag>(isolate, wrappable, anchor);
    }
    return true;
}

/// `box`'s object reaches no instance from here (Blink's
/// V8DOMWrapper::ClearNativeInfo): its instance goes while the wrapper may
/// live on - its realm's end severing it (wrapper_cache.zig severWrapper, on
/// the realm's thread with its isolate current) - or the wrap that bound it
/// failed. One write on its anchor: the binding's next read answers null, and
/// a holder's anchor traces nothing. A realm's global has its field cleared.
/// Nothing for an object never bound, or a node's wrapper.
extern "C" void v8_PlatformObject_Sever(Global<Object>* box) {
    Isolate* isolate = Isolate::GetCurrent();
    if (!isolate || !box || box->IsEmpty()) return;
    HandleScope scope(isolate);
    Local<Object> wrappable = anchorHolderOf(box->Get(isolate));
    if (wrappable->InternalFieldCount() >= 1) {
        wrappable->SetAlignedPointerInInternalField(0, nullptr, kCraneEmbedderDataTag);
        return;
    }
    if (!isolate->GetCppHeap() || !wrappable->IsApiWrapper()) return;
    PlatformAnchor* anchor = Object::Unwrap<PlatformAnchor>(isolate, wrappable, crane_tags::kPlatformObjectAnchorRange);
    if (anchor) anchor->instance_ = nullptr;
}

/// The instance `obj` reaches, or null (`instanceOfObject`: the binding's one
/// read of a platform object's instance). The isolate is the current one.
extern "C" void* v8_Object_Instance(Global<Object>* obj) {
    Isolate* isolate = Isolate::GetCurrent();
    if (!isolate || !obj || obj->IsEmpty()) return nullptr;
    HandleScope scope(isolate);
    return instanceOfObject(isolate, obj->Get(isolate));
}

/// engine.traceNodeWrapper on V8 (design 3.3): the walk's visitor traces the
/// TracedReference in a non-empty node slot - Blink's ScriptWrappable::Trace
/// of its inline `wrapper_` (platform/bindings/script_wrappable.cc). Marks
/// the TracedNode and the wrapper, and through the wrapper its anchor.
extern "C" void v8_NodeTracer_TraceSlot(cppgc::Visitor* visitor, void* slot) {
    visitor->Trace(*static_cast<const TracedReference<Object>*>(slot));
}

/// Whether `box`'s object can be a node's wrapper: an API object (made from a
/// template), which Object::Wrap can point at an anchor - the binding's
/// always is; asked before the wrap takes the count.
extern "C" bool v8_NodeWrapper_Wrappable(Isolate* isolate, Global<Object>* box) {
    HandleScope scope(isolate);
    Local<Object> object = box->Get(isolate);
    if (object->IsProxy()) {
        Local<Value> target = object.As<Proxy>()->GetTarget();
        if (!target->IsObject()) return false;
        object = target.As<Object>();
    }
    return object->IsApiWrapper();
}

/// The node wrap's steps 3-6 (design 4.2; step 1, the count, and step 2, the
/// object - `box`, a fresh `new Global<Object>` the binding made from the
/// interface's template, with no internal field - are the caller's): the
/// anchor is made, `box`'s object is Wrapped with it, the node's empty
/// `slot` takes the object as a TracedReference, and the anchor joins the
/// registry. `box` stays the caller's, holding the wrapper strongly until it
/// disposes it: no collection can take the wrapper meanwhile.
///
/// No collection sees a half-made wrapper: the anchor's allocation is the
/// only one that can collect, and it runs before the anchor exists - the
/// object then reaches nothing of the node, and the slot is still empty.
/// From the Wrap on nothing allocates on either heap (the registry's
/// capacity is reserved first; a TracedNode block is malloc). The
/// TracedReference is made by assignment (Reset), whose store applies V8's
/// marking barrier when a collection is marking (TracedReferenceStoreMode
/// kAssigningStore: the slot's holder, the node, is no cppgc object).
extern "C" void v8_NodeWrapper_Attach(Isolate* isolate, Global<Object>* box, void* slot) {
    IsolateData* record = isolateData(isolate);
    NodeWrapperRegistry* registry = record ? record->node_anchors.Get() : nullptr;
    CppHeap* heap = isolate->GetCppHeap();
    if (!registry || !heap) {
        fprintf(stderr, "v8_wrapper: a node wrap on an isolate with no node anchor registry\n");
        abort();
    }
    HandleScope scope(isolate);
    Local<Object> object = box->Get(isolate);
    // A legacy platform object's wrapper is its proxy; the anchor goes on
    // the API object behind it (no node interface is one today).
    Local<Object> wrappable = object;
    if (object->IsProxy()) {
        Local<Value> target = object.As<Proxy>()->GetTarget();
        if (target->IsObject()) wrappable = target.As<Object>();
    }
    // Room for the anchor before anything is made (the push_back below must
    // not allocate), grown geometrically: an exact reserve(size + 1) per wrap
    // copied the whole vector at every node wrap - quadratic in the live
    // anchors (the perf pair's dom.create-element ran 9.6x, gc_bench's
    // wrapper-churn-nogc 4.7x, 83f1e0e187b).
    if (registry->anchors.size() == registry->anchors.capacity()) {
        registry->anchors.reserve(std::max<size_t>(NodeWrapperRegistry::kShrinkFloor, registry->anchors.capacity() * 2));
    }
    // 3. The anchor. A collection this allocation starts runs before it
    //    exists.
    NodeAnchor* anchor = cppgc::MakeGarbageCollected<NodeAnchor>(heap->GetAllocationHandle(), slot);
    NODE_ANCHOR_IN_FRAME(isolate);
    // 4. The wrapper points at it (WriteBarrier::ForCppHeapPointer marks it
    //    if the wrapper is already marked).
    Object::Wrap<kNodeAnchorTag>(isolate, wrappable, anchor);
    // 5. The node's slot holds the wrapper: droppable (design 4.11, P8) -
    //    V8 may reclaim it in a young-generation collection while it is an
    //    unmodified API object nothing reaches (NodeWrapperRootsHandler).
    TracedReference<Object>* traced = new (slot) TracedReference<Object>();
    traced->Reset(isolate, object, TracedReference<Object>::IsDroppable{});
    // 6. The registry (its index in the anchor: lane wr1 batch 8).
    registry->add(anchor);
}

/// A kept node's wrapper becomes a traced root (design 7 P4: "Kept nodes are
/// traced roots, their own slot only"): a cppgc::Persistent on its anchor,
/// whose Trace marks the slot. OWNED by the caller until
/// v8_NodeWrapper_Unroot. Null for an empty slot or no anchor.
extern "C" void* v8_NodeWrapper_Root(Isolate* isolate, void* slot) {
    TracedReference<Object>* traced = static_cast<TracedReference<Object>*>(slot);
    if (traced->IsEmpty()) return nullptr;
    HandleScope scope(isolate);
    NODE_ANCHOR_IN_FRAME(isolate);
    Local<Object> wrapper = traced->Get(isolate);
    NodeAnchor* anchor = nodeAnchorOf(isolate, wrapper);
    if (!anchor) return nullptr;
    // A kept node's wrapper is never dropped (design 4.11, P8): the slot is
    // made again, NOT droppable - a scavenge never asks the C++ heap, so the
    // Persistent below would not keep a droppable one. It stays so for the
    // wrapper's life (a full collection takes it once nothing reaches it).
    // The slot's address - every borrower's handle - is unchanged.
    traced->Reset(isolate, wrapper);
    anchor->roots_ += 1;
    return new cppgc::Persistent<NodeAnchor>(anchor);
}

/// A keep's root (v8_NodeWrapper_Root) goes. On the isolate's thread, while
/// its heap lives.
extern "C" void v8_NodeWrapper_Unroot(void* root) {
    cppgc::Persistent<NodeAnchor>* persistent = static_cast<cppgc::Persistent<NodeAnchor>*>(root);
    // The Persistent kept its anchor: it is alive here.
    if (NodeAnchor* anchor = persistent->Get()) anchor->roots_ -= 1;
    delete persistent;
}

/// The node's wrapper ends outside a collection: its node's teardown began
/// under it (a forced realm end's coordinated teardown). Its anchor lets go
/// of the slot - the wrapper reaches no node from here, so script that still
/// holds it gets a TypeError at the binding's unwrap, never the freed node
/// (Blink's V8DOMWrapper::ClearNativeInfo) - and the slot is Reset, V8
/// freeing its TracedNode. On the isolate's thread; it is entered for the
/// call if it is not current.
extern "C" void v8_NodeWrapper_End(Isolate* isolate, void* slot) {
    TracedReference<Object>* traced = static_cast<TracedReference<Object>*>(slot);
    if (traced->IsEmpty()) return;
    if (isolate) {
        const bool enter = Isolate::TryGetCurrent() != isolate;
        if (enter) isolate->Enter();
        {
            HandleScope scope(isolate);
            NODE_ANCHOR_IN_FRAME(isolate);
            if (NodeAnchor* anchor = nodeAnchorOf(isolate, traced->Get(isolate))) {
                if (anchor->slot_ == slot) anchor->slot_ = nullptr;
            }
        }
        if (enter) isolate->Exit();
    }
    traced->Reset();
}

/// The agent's end (design 4.9 step 2): every live anchor lets go of its
/// slot, which is Reset, and `ended` is told each slot - the Zig side
/// releases its reference. No node is read after this by anything of the
/// adapter: an anchor's Trace and the weak processing read only a slot an
/// anchor still holds. The anchors themselves go with their wrappers.
extern "C" void v8_NodeWrappers_EndAll(Isolate* isolate, void* registry_data, void (*ended)(void* registry, void* slot)) {
    IsolateData* record = isolateData(isolate);
    NodeWrapperRegistry* registry = record ? record->node_anchors.Get() : nullptr;
    if (!registry) return;
    NODE_ANCHOR_IN_FRAME(isolate);
    // By index: `ended` only counts (no V8 call, no wrap), but the vector is
    // read afresh at each step all the same.
    for (size_t i = 0; i < registry->anchors.size(); i++) {
        NodeAnchor* anchor = registry->anchors[i];
        void* slot = anchor->slot_;
        if (!slot) continue;
        anchor->slot_ = nullptr;
        static_cast<TracedReference<Object>*>(slot)->Reset();
        ended(registry_data, slot);
    }
}

/// The anchors' registry goes (v8_Isolate_Dispose, after the Zig registry's
/// end): unrooted, collected by the heap's termination with every anchor.
static void releaseNodeAnchors(IsolateData* record) {
    if (NodeWrapperRegistry* registry = record->node_anchors.Get()) registry->anchors.clear();
    // Dropped anchors not yet freed go with the heap's termination too.
    record->dropped_anchors.clear();
    record->node_anchors.Clear();
}

// ---- tests/v8/node_anchor_test.zig's probes ----

/// What v8_test_NodeWrapper_Probe saw; ffi.zig's NodeWrapperProbe mirrors it.
struct CraneNodeWrapperProbe {
    bool has_wrapper;
    bool api_wrapper;
    int32_t internal_fields;
    void* anchor;
    void* anchor_slot;
    /// The anchors the agent's registry holds (live, or dead and not yet
    /// found by a collection), and the room it has for them.
    uint64_t registered_anchors;
    uint64_t anchor_capacity;
};

/// The wrapper in node slot `slot` of the current isolate (entered by the
/// caller): its internal field count, whether it is an API wrapper, the
/// anchor Object::Unwrap finds under the node anchors' tag and the slot that
/// anchor holds.
extern "C" void v8_test_NodeWrapper_Probe(Isolate* isolate, void* slot, CraneNodeWrapperProbe* out) {
    *out = CraneNodeWrapperProbe{false, false, -1, nullptr, nullptr, 0, 0};
    IsolateData* record = isolateData(isolate);
    if (record && record->node_anchors.Get()) {
        out->registered_anchors = record->node_anchors->anchors.size();
        out->anchor_capacity = record->node_anchors->anchors.capacity();
    }
    // Read through the Global<Object>* every borrower holds (wrapperOf).
    Global<Object>* handle = static_cast<Global<Object>*>(slot);
    if (handle->IsEmpty()) return;
    out->has_wrapper = true;
    HandleScope scope(isolate);
    Local<Object> object = handle->Get(isolate);
    out->api_wrapper = object->IsApiWrapper();
    out->internal_fields = object->InternalFieldCount();
    NODE_ANCHOR_IN_FRAME(isolate);
    NodeAnchor* anchor = nodeAnchorOf(isolate, object);
    out->anchor = anchor;
    out->anchor_slot = anchor ? anchor->slot_ : nullptr;
}

/// A callback the test's own, at the end of every full collection of
/// `isolate` (after the collection's weak processing, before anything a
/// collection posts runs).
struct CraneFullGCEpilogueProbe {
    Isolate* isolate;
    void (*callback)(void*);
    void* data;
};

static void fullGCEpilogueProbe(Isolate*, GCType, GCCallbackFlags, void* data) {
    CraneFullGCEpilogueProbe* probe = static_cast<CraneFullGCEpilogueProbe*>(data);
    probe->callback(probe->data);
}

extern "C" CraneFullGCEpilogueProbe* v8_test_FullGCEpilogueProbe_New(Isolate* isolate, void (*callback)(void*), void* data) {
    auto* probe = new CraneFullGCEpilogueProbe{isolate, callback, data};
    isolate->AddGCEpilogueCallback(fullGCEpilogueProbe, probe, kGCTypeMarkSweepCompact);
    return probe;
}

extern "C" void v8_test_FullGCEpilogueProbe_Delete(CraneFullGCEpilogueProbe* probe) {
    probe->isolate->RemoveGCEpilogueCallback(fullGCEpilogueProbe, probe);
    delete probe;
}

/// A full collection of `isolate` (entered by the caller) with no
/// conservative scan of the stack - a stale anchor pointer in a frame must not
/// keep a test's wrapper (cppgc::testing::OverrideEmbedderStackStateScope) -
/// and, unlike v8_Isolate_RequestGarbageCollection, no safe point at its end:
/// what it collected waits for the agent's next one (the pump's, say).
extern "C" void v8_test_Isolate_CollectWithoutDrain(Isolate* isolate) {
    CollectingScope collecting(isolate);
    CppHeap* heap = isolate->GetCppHeap();
    if (!heap) {
        isolate->LowMemoryNotification();
        return;
    }
    cppgc::testing::OverrideEmbedderStackStateScope no_stack_scan(heap->GetHeapHandle(), cppgc::EmbedderStackState::kNoHeapPointers);
    isolate->LowMemoryNotification();
}

/// The node wrappers V8 has dropped in `isolate`'s young-generation
/// collections so far (NodeWrapperRootsHandler::ResetRoot).
/// The bytes V8 holds now as external memory for the pointer-table entries
/// of wrappers dropped since the last full collection began
/// (`reportDroppedTableEntries`). 0 for a null isolate or one the adapter
/// did not make.
extern "C" uint64_t v8_Debug_NodeWrapperTableBytes(Isolate* isolate) {
    IsolateData* record = isolate ? isolateData(isolate) : nullptr;
    return record ? record->table_bytes_reported : 0;
}

extern "C" uint64_t v8_test_NodeWrappers_Dropped(Isolate* isolate) {
    IsolateData* record = isolateData(isolate);
    return record ? record->node_wrappers_dropped : 0;
}

/// How many times V8 called `isolate`'s NodeWrapperRootsHandler::TryResetRoot
/// - from any thread - so far; 0 for an isolate with no record. The linked
/// V8 (15.7.112.43) calls it from its worker threads when a scavenge has
/// more than 8 young TracedNode blocks to process (the rule at
/// NodeWrapperRootsHandler).
extern "C" uint64_t v8_test_NodeWrappers_TryResetRootCalls(Isolate* isolate) {
    IsolateData* record = isolateData(isolate);
    return record && record->roots_handler ? record->roots_handler->tryResetRootCalls() : 0;
}

/// At least `n` young-generation collections of `isolate` (entered by the
/// caller), by filling its young generation with unreachable arrays - V8's
/// public API asks for a scavenge only with --expose-gc
/// (RequestGarbageCollectionForTesting), which Crane's process never sets.
/// Bounded: a young generation that never fills does not hang the test (it
/// sees fewer collections than it asked for).
extern "C" void v8_test_Isolate_MinorGC(Isolate* isolate, uint32_t n) {
    IsolateData* record = isolateData(isolate);
    if (!record) return;
    const uint64_t target = record->gc_pauses.minor_count + n;
    for (int round = 0; round < 1 << 16 && record->gc_pauses.minor_count < target; round++) {
        HandleScope scope(isolate);
        for (int i = 0; i < 256; i++) (void)Array::New(isolate, 128);
    }
}

/// The bytes of the objects alive on `isolate`'s C++ heap, counted object by
/// object (cppgc's detailed statistics: it finishes a running sweep and
/// gives back the linear allocation buffers first, so freed objects, free
/// lists and buffers count for nothing) - unlike `cpp_heap_used_bytes`
/// (kBrief), which counts a linear allocation buffer whole from the moment
/// it is taken and an explicit free only at the next allocation's safepoint
/// (13.1.203 stats-collector.cc NotifyExplicitFree,
/// NotifySafePointForConservativeCollection). For tests only: it changes
/// the heap's state.
extern "C" size_t v8_test_CppHeap_LiveBytes(Isolate* isolate) {
    CppHeap* heap = isolate ? isolate->GetCppHeap() : nullptr;
    if (!heap) return 0;
    return heap->CollectStatistics(cppgc::HeapStatistics::DetailLevel::kDetailed).used_size_bytes;
}

/// A full collection of `isolate` (entered by the caller) that V8 does not
/// force: its answer to critical memory pressure (13.1.203 heap.cc
/// Heap::CollectGarbageOnMemoryPressure, kReduceMemoryFootprint with no
/// kForced), after which the C++ heap sweeps concurrently and finalizes on
/// the agent's thread - not atomically, as a requested collection's does
/// (cpp-heap.cc CppHeap::SelectSweepingType). Whether the C++ heap is still
/// collecting - sweeping, or marking again - when it returns: what
/// tests/v8/wr8_anchor_free_test.zig needs to see a free refused.
extern "C" bool v8_test_Isolate_CollectUnforced(Isolate* isolate) {
    isolate->MemoryPressureNotification(MemoryPressureLevel::kCritical);
    CppHeap* heap = isolate->GetCppHeap();
    if (!heap) return false;
    const cppgc::HeapHandle& handle = heap->GetHeapHandle();
    return cppgc::subtle::HeapState::IsSweeping(handle) || cppgc::subtle::HeapState::IsMarking(handle);
}

// ---- tests/v8/wr8_young_generation_test.zig: what V8 lets a scavenge drop ----

/// The probe's wrappable: a node wrapper's shape (an API object Wrapped with
/// a C++-heap object), under a tag of its own.
static constexpr CppHeapPointerTag kDroppableProbeTag = crane_tags::tag(crane_tags::kTestProbeAnchor);

class DroppableProbeAnchor final : public CraneWrappable {
 public:
    DroppableProbeAnchor() = default;
};

/// The probe's roots handler, for the probe's scavenges only: the probe's
/// own reference it Resets and records; any other goes to the isolate's
/// handler (a node wrapper the scavenges drop meanwhile).
class DroppableProbeHandler final : public EmbedderRootsHandler {
 public:
    DroppableProbeHandler(TracedReference<Object>* probe, EmbedderRootsHandler* next) : probe_(probe), next_(next) {}

    void ResetRoot(const TracedReference<Value>& handle) final {
        const TracedReference<Object>& traced = handle.As<Object>();
        if (!probe_->IsEmpty() && *probe_ == traced) {
            probe_->Reset();
            dropped = true;
            return;
        }
        if (next_) next_->ResetRoot(handle);
    }

    bool TryResetRoot(const TracedReference<Value>&) final {
        return false;
    }

    bool dropped = false;

 private:
    TracedReference<Object>* probe_;
    EmbedderRootsHandler* next_;
};

/// Whether V8 drops, in a scavenge, an unreachable object made from `tpl`'s
/// instance template the way the binding makes a node wrapper
/// (template_registry.wrapInstanceAsV8Object: ObjectTemplate::NewInstance),
/// then - when given - with its prototype set to `prototype` (the binding
/// sets globalThis[interface].prototype) and with a private property (node
/// tracing's edges, wrapper_cache.zig), Wrapped with a C++-heap object and
/// held by a DROPPABLE TracedReference only: V8's unmodified-API-object rule
/// (13.1.203 JSObject::IsUnmodifiedApiObject) answered by V8 itself. 1:
/// dropped; 0: kept through the scavenges; -1: inconclusive (no C++ heap, a
/// failed step, or a full collection ran meanwhile). On the isolate's
/// thread, entered.
extern "C" int v8_test_NodeTemplateWrapperDroppable(Isolate* isolate, Global<Context>* context, Global<FunctionTemplate>* tpl,
                                                    Global<Object>* prototype, bool add_private, Global<Value>* apply) {
    IsolateData* record = isolateData(isolate);
    CppHeap* heap = isolate->GetCppHeap();
    if (!record || !heap) return -1;
    // No incremental marking may be running: V8 treats every young traced
    // reference as a root while it does (TracedHandles::
    // ComputeWeaknessForYoungObjects). A full collection ends it.
    {
        cppgc::testing::OverrideEmbedderStackStateScope no_stack_scan(heap->GetHeapHandle(), cppgc::EmbedderStackState::kNoHeapPointers);
        isolate->LowMemoryNotification();
    }
    // Heap-allocated: a full collection meanwhile would free its node
    // (nothing traces it), and the probe then never touches it again.
    auto* probe = new TracedReference<Object>();
    {
        HandleScope scope(isolate);
        Local<Context> ctx = context->Get(isolate);
        Context::Scope context_scope(ctx);
        Local<Object> object;
        if (!tpl->Get(isolate)->InstanceTemplate()->NewInstance(ctx).ToLocal(&object)) {
            delete probe;
            return -1;
        }
        if (prototype && object->SetPrototype(ctx, prototype->Get(isolate)).IsNothing()) {
            delete probe;
            return -1;
        }
        if (add_private) {
            Local<String> name = String::NewFromUtf8Literal(isolate, "crane:test:droppable-probe");
            (void)object->SetPrivate(ctx, Private::ForApi(isolate, name), Null(isolate));
        }
        auto* anchor = cppgc::MakeGarbageCollected<DroppableProbeAnchor>(heap->GetAllocationHandle());
        Object::Wrap<kDroppableProbeTag>(isolate, object, anchor);
        probe->Reset(isolate, object, TracedReference<Object>::IsDroppable{});
        // Script's use of the wrapper (a WeakMap key, a WeakRef, an
        // expando...): `apply(object)`, then the job's end - its WeakRef
        // targets are no longer kept (ClearKeptObjects, HTML's microtask
        // checkpoint step 6).
        if (apply) {
            Local<Value> fn = apply->Get(isolate);
            Local<Value> argv[1] = {object};
            if (!fn->IsFunction() || fn.As<Function>()->Call(ctx, Undefined(isolate), 1, argv).IsEmpty()) {
                probe->Reset();
                delete probe;
                return -1;
            }
        }
    }
    isolate->ClearKeptObjects();
    DroppableProbeHandler handler(probe, record->roots_handler.get());
    const uint64_t full_before = record->gc_pauses.count;
    isolate->SetEmbedderRootsHandler(&handler);
    v8_test_Isolate_MinorGC(isolate, 2);
    isolate->SetEmbedderRootsHandler(record->roots_handler.get());
    if (handler.dropped) {
        delete probe;
        return 1;
    }
    // A full collection freed the unmarked node; its address is not ours to
    // Reset (the TracedReference object is left, test-only and rare).
    if (record->gc_pauses.count != full_before) return -1;
    probe->Reset();
    delete probe;
    return 0;
}

/// The host's wall clock of the isolate current on this thread (ns since the
/// epoch) into `ns`, when its agent was given one (engine.AgentOptions.clock).
/// V8 asks its platform for the time with no isolate argument, so the
/// isolate is the one entered on the asking thread: script's own, for every
/// Date read. Another thread - a V8 worker, a thread with no isolate entered
/// - reads the backend's clock.
static bool currentHostClock(int64_t* ns) {
    const IsolateData* record = isolateData(Isolate::TryGetCurrent());
    if (!record || !record->clock_wall_now) return false;
    *ns = record->clock_wall_now(record->clock_context);
    return true;
}

double CranePlatform::CurrentClockTimeMillis() {
    int64_t ns;
    if (currentHostClock(&ns)) return static_cast<double>(ns) / 1e6;
    return backend_->CurrentClockTimeMillis();
}

int64_t CranePlatform::CurrentClockTimeMilliseconds() {
    int64_t ns;
    if (currentHostClock(&ns)) {
        // Floor, as Platform's default floors CurrentClockTimeMillis: the
        // millisecond before the epoch is -1.
        int64_t ms = ns / 1000000;
        if (ns % 1000000 < 0) ms -= 1;
        return ms;
    }
    return backend_->CurrentClockTimeMilliseconds();
}

double CranePlatform::CurrentClockTimeMillisecondsHighResolution() {
    int64_t ns;
    if (currentHostClock(&ns)) return static_cast<double>(ns) / 1e6;
    return backend_->CurrentClockTimeMillisecondsHighResolution();
}

/// V8::SetEntropySource's callback, installed once by v8_Platform_Start
/// before V8 initializes. V8 asks it for a seed each time it makes a random
/// number generator with no seed of its own (13.1 base/utils/random-number-
/// generator.cc). An isolate made with a seed (engine.AgentOptions.random_seed)
/// answers that seed for every generator made while it is the current
/// isolate - its own above all, made lazily on its thread (Isolate::
/// random_number_generator; Isolate::Initialize enters the isolate, 13.1
/// api.cc:9897), which seeds each context's Math.random state the first
/// time script asks (math-random.cc RefillCache) and the identity hashes.
/// The same bytes every time: whichever generator V8 happens to make first,
/// the isolate's own gets the seed, so a replay does not depend on what an
/// earlier isolate of the process made.
///
/// Per isolate, never per process: --random-seed would give every context of
/// every isolate one sequence (V8's own mjsunit.status skips d8-os in the
/// isolates variant for exactly that). Every other generator - no isolate
/// current, or one made without a seed - gets false, and V8 falls back to
/// its own entropy (arc4random_buf, /dev/urandom) exactly as with no
/// callback at all.
static bool craneEntropySource(unsigned char* buffer, size_t length) {
    const IsolateData* record = isolateData(Isolate::TryGetCurrent());
    if (!record || !record->seeded) return false;
    for (size_t i = 0; i < length; i++) {
        buffer[i] = static_cast<unsigned char>(record->random_seed >> (8 * (i % 8)));
    }
    return true;
}

std::shared_ptr<TaskRunner> CranePlatform::GetForegroundTaskRunner(Isolate* isolate, TaskPriority priority) {
    // Public contract: this lookup is foreground-only. A retained TaskRunner
    // may subsequently be posted to on any thread, without an isolate lookup.
    IsolateData* record = isolateData(isolate);
    if (!record) return backend_->GetForegroundTaskRunner(isolate, priority);
    const size_t index = static_cast<size_t>(priority);
    assert(index < record->foreground_runners.size());
    auto& runner = record->foreground_runners[index];
    if (!runner) runner = std::make_shared<ForegroundTaskRunner>(record->foreground_tasks,
                                                               backend_->GetForegroundTaskRunner(isolate, priority));
    return runner;
}

/// Attach one OWNED wake target. On failure the caller retains ownership.
bool v8_Isolate_AttachForegroundTaskSink(Isolate* isolate, void* sink,
                                        void (*wake)(void*), void (*release)(void*)) {
    IsolateData* record = isolateData(isolate);
    return record && record->foreground_tasks->attach(sink, wake, release);
}

/// Close before any host/realm teardown. Racing posts finish under the state
/// lock; after this returns neither the sink nor the isolate is touched again.
void v8_Isolate_CloseForegroundTasks(Isolate* isolate) {
    if (IsolateData* record = isolateData(isolate)) record->foreground_tasks->close();
}

bool v8_Isolate_NextForegroundTaskDelay(Isolate* isolate, uint64_t* nanoseconds) {
    IsolateData* record = isolateData(isolate);
    return record && record->foreground_tasks->nextDelay(nanoseconds);
}

/// Test-only owning runner reference. Require the runner V8 requested during
/// initialization, rather than manufacturing one that could hide that path.
std::shared_ptr<TaskRunner>* v8_test_ForegroundTaskRunner(Isolate* isolate) {
    IsolateData* record = isolateData(isolate);
    if (!record) return nullptr;
    auto& runner = record->foreground_runners[static_cast<size_t>(TaskPriority::kUserBlocking)];
    return runner ? new std::shared_ptr<TaskRunner>(runner) : nullptr;
}

void v8_test_TaskRunner_Release(std::shared_ptr<TaskRunner>* runner) { delete runner; }
void v8_test_TaskRunner_Post(std::shared_ptr<TaskRunner>* runner, void (*run)(void*),
                            void (*drop)(void*), void* data, double delay) {
    class ProbeTask final : public Task {
     public:
        ProbeTask(void (*run)(void*), void (*drop)(void*), void* data)
            : run_(run), drop_(drop), data_(data) {}
        ~ProbeTask() override { drop_(data_); }
        void Run() override { run_(data_); }
     private:
        void (*run_)(void*);
        void (*drop_)(void*);
        void* data_;
    };
    auto task = std::make_unique<ProbeTask>(run, drop, data);
    if (delay > 0) (*runner)->PostDelayedTask(std::move(task), delay);
    else (*runner)->PostTask(std::move(task));
}

static void deleteSyntheticExport(SyntheticJsonExport* entry) {
    entry->module.Reset();
    entry->value.Reset();
    delete entry;
}

/// What an agent asks of its isolate before it initializes (ffi.zig
/// IsolateOptions; engine.AgentOptions.random_seed and .clock, and the
/// build's limit for the young generation). Null, or every field zero: an
/// isolate exactly as v8_Isolate_New made it before.
struct CraneIsolateOptions {
    bool seeded;
    uint64_t random_seed;
    void* clock_context;
    int64_t (*clock_wall_now)(void*);
    size_t max_young_generation_bytes;
};

/// `options` into the record, before Isolate::Initialize.
static void applyIsolateOptions(IsolateData* record, const CraneIsolateOptions* options) {
    if (!options) return;
    record->seeded = options->seeded;
    record->random_seed = options->random_seed;
    record->clock_wall_now = options->clock_wall_now;
    record->clock_context = options->clock_context;
}

/// The build's ceiling for the young generation (-Dv8-young-generation-mb,
/// young_generation.zig) into the isolate's ResourceConstraints, which
/// Heap::ConfigureHeap reads once, inside Isolate::Initialize (15.7.112.43
/// src/heap/heap.cc:4886-4892: max_semi_space_size_ from
/// constraints.max_young_generation_size_in_bytes; include/v8-isolate.h:
/// 133-143). 0, or no options: no constraint - V8's own ceiling, 32 MB
/// semispaces (heap.cc:4844-4860). The embedder API for it: gin sets the
/// same field through ResourceConstraints::ConfigureDefaults (Chromium
/// 157.0.8103.50 gin/isolate_holder.cc:186-190). Not a V8 flag string: the
/// constraint is the isolate's own, set where the isolate is made.
static void applyHeapConstraints(Isolate::CreateParams& create_params, const CraneIsolateOptions* options) {
    if (!options || options->max_young_generation_bytes == 0) return;
    create_params.constraints.set_max_young_generation_size_in_bytes(options->max_young_generation_bytes);
}

// ---- one read-only heap per process (lane tsanfix1, M1) ----
//
// With pointer compression in one shared cage (Crane's V8:
// V8_COMPRESS_POINTERS with V8_ENABLE_SANDBOX) every isolate of the process is
// in ONE isolate group, and the group keeps ONE read-only heap: the first live
// isolate makes it from its snapshot's read-only part, every later one reuses
// it, and it goes when the group's last isolate ends (V8 13.1
// src/heap/read-only-heap.cc, ReadOnlyHeap::SetUp and ReadOnlyHeap::TearDown).
// An isolate restored from Crane's blob while that heap came from V8's built-in
// snapshot reads objects the heap does not have: Isolate::Initialize crashed in
// SharedHeapDeserializer::DeserializeStringTable (SIGSEGV 0x10488,
// docs/testing/test-variant-findings-2026-11-02.tsv M1) - a snapshot Browser
// made while a snapshot_path "" Browser's isolate was the process's first.
// V8's DEBUG build CHECKs that every isolate of a group restores the same
// read-only snapshot (src/heap/read-only-spaces.cc:76-104,
// ReadOnlyArtifacts::VerifyChecksum); the release build Crane links does not.
//
// So the adapter records which snapshot the live isolates' read-only heap came
// from, and refuses a restore from a blob that is not it: the caller makes the
// isolate without the blob (protocol_agents.createAgent says so at warn).
//
// The other direction - an isolate from V8's built-in snapshot while the heap
// came from Crane's blob, which is how every worker of a snapshot process is
// made today - is allowed, and rests on two facts of the linked V8 and nothing
// else:
//  - v8_enable_extensible_ro_snapshot = true (13.1 BUILD.gn:436): a
//    SnapshotCreator starts from V8's built-in snapshot and EXTENDS its
//    read-only space, never rearranges it, so Crane's read-only heap keeps
//    every object of the built-in one where the built-in startup data expects
//    it;
//  - VerifyChecksum's CHECK is compiled only #ifdef DEBUG
//    (read-only-spaces.cc:76-104): a DEBUG V8 aborts on it.
// Neither is a contract. The queued follow-up removes the dependency: every
// isolate of a process made from one blob, workers included, as Chromium's gin
// does - after the snapshot's default context is made plain, since Genesis
// copies the default global's properties onto every fresh context
// (bootstrapper.cc:7056-7062) and Crane's default global is a Window's.

/// What the live isolates' read-only heap came from, as seen by an isolate
/// that would restore `blob` (null: V8's built-in snapshot).
enum CraneReadOnlyOrigin : int {
    /// No isolate is alive: the next one makes the heap.
    kReadOnlyNone = 0,
    /// From the same snapshot.
    kReadOnlySame = 1,
    /// From V8's built-in snapshot, and `blob` is Crane's.
    kReadOnlyBuiltin = 2,
    /// From another blob than `blob` (Crane's, when `blob` is null).
    kReadOnlyOtherBlob = 3,
};

struct ReadOnlyHeapRecord {
    std::mutex lock;
    /// Isolates made here and not yet disposed.
    size_t live = 0;
    /// The blob the heap came from; null for V8's built-in snapshot (while
    /// `live` > 0).
    const char* blob = nullptr;
    int blob_size = 0;
};

// process-wide: V8's isolate group - one per process with Crane's single pointer-compression cage - keeps ONE read-only heap for every isolate of every Browser and thread; this records which snapshot made it, under its own lock, for every thread that makes or ends an isolate.
static ReadOnlyHeapRecord g_read_only_heap;

/// Whether two blobs are one snapshot: the same bytes, or equal ones.
static bool sameSnapshot(const char* a, int a_size, const char* b, int b_size) {
    if (a == b && a_size == b_size) return true;
    return a && b && a_size == b_size && std::memcmp(a, b, static_cast<size_t>(a_size)) == 0;
}

/// The origin of the live isolates' read-only heap for `blob`; the lock held.
static CraneReadOnlyOrigin readOnlyOriginLocked(const char* blob, int blob_size) {
    if (g_read_only_heap.live == 0) return kReadOnlyNone;
    if (!g_read_only_heap.blob) return blob ? kReadOnlyBuiltin : kReadOnlySame;
    if (!blob) return kReadOnlyOtherBlob;
    return sameSnapshot(g_read_only_heap.blob, g_read_only_heap.blob_size, blob, blob_size) ? kReadOnlySame : kReadOnlyOtherBlob;
}

/// Count an isolate about to be made from `blob` (null: V8's built-in
/// snapshot) in the read-only heap record - or refuse it: false when the live
/// isolates' heap came from another snapshot and `blob` is Crane's (the
/// comment above says why the built-in direction is let through).
static bool claimReadOnlyHeap(const char* blob, int blob_size) {
    std::lock_guard<std::mutex> guard(g_read_only_heap.lock);
    switch (readOnlyOriginLocked(blob, blob_size)) {
        case kReadOnlyNone:
            g_read_only_heap.blob = blob;
            g_read_only_heap.blob_size = blob ? blob_size : 0;
            break;
        case kReadOnlySame:
            break;
        case kReadOnlyOtherBlob:
            if (blob) return false;
            break;
        case kReadOnlyBuiltin:
            return false;
    }
    g_read_only_heap.live += 1;
    return true;
}

/// An isolate counted by claimReadOnlyHeap has ended (or was never made).
static void releaseReadOnlyHeap() {
    std::lock_guard<std::mutex> guard(g_read_only_heap.lock);
    if (g_read_only_heap.live == 0) return;
    g_read_only_heap.live -= 1;
    if (g_read_only_heap.live == 0) {
        g_read_only_heap.blob = nullptr;
        g_read_only_heap.blob_size = 0;
    }
}

/// What the live isolates' read-only heap came from, for an isolate that
/// would restore `blob` (null: V8's built-in snapshot): a CraneReadOnlyOrigin.
/// For a caller's message and for tests; another thread may change it at once.
int v8_Process_ReadOnlyHeapOrigin(const char* blob, int blob_size) {
    std::lock_guard<std::mutex> guard(g_read_only_heap.lock);
    return readOnlyOriginLocked(blob, blob_size);
}

/// How many isolates made by this file are alive in the process, for tests
/// that must make the process's first isolate.
size_t v8_Process_LiveIsolates() {
    std::lock_guard<std::mutex> guard(g_read_only_heap.lock);
    return g_read_only_heap.live;
}

/// A new agent's C++ heap (cppgc), for its isolate's CreateParams::cpp_heap -
/// the wrapper redesign's P3 (tmp/redesign/wrapper-redesign-design.md 4.12):
/// every agent has one, workers included (decision 6), as every Blink thread
/// with V8 has its ThreadState's. Nothing allocates on it yet.
///
/// Marking is ATOMIC: C++ Trace methods run in the final pause, on the
/// isolate's thread, with the mutator stopped - which the host's tree walk will
/// rely on (design 4.4, risk R6). V8's flags can only lower it
/// (CppHeap::UpdateGCCapabilitiesFromFlags takes the minimum), and they are
/// atomic by default. Sweeping is incremental and concurrent: P4's anchors
/// have no destructor. The platform is the one V8 runs on (CranePlatform), as
/// Blink hands its heap gin's V8Platform: cppgc's foreground tasks reach the
/// agent's loop through its task runner. Made after V8's start
/// (cppgc::InitializeProcess, v8_Platform_Start).
static void agentCppHeapParams(CppHeapCreateParams& params) {
    // kAtomic keeps every C++ Trace - the node anchors' walk (design 4.4) -
    // inside the atomic pause (collectingRecord says why, from the 13.1
    // source); tests/v8/wrapper_walk_test.zig pins it.
    params.marking_support = cppgc::Heap::MarkingType::kAtomic;
    params.sweeping_support = cppgc::Heap::SweepingType::kIncrementalAndConcurrent;
}

static std::unique_ptr<CppHeap> newAgentCppHeap() {
    CppHeapCreateParams params(std::vector<std::unique_ptr<cppgc::CustomSpaceBase>>{});
    agentCppHeapParams(params);
    return CppHeap::Create(g_platform.platform, params);
}

/// tests/v8: the MarkingType every agent's C++ heap is made with
/// (agentCppHeapParams).
extern "C" uint8_t v8_test_AgentCppHeapMarkingSupport() {
    CppHeapCreateParams params(std::vector<std::unique_ptr<cppgc::CustomSpaceBase>>{});
    agentCppHeapParams(params);
    return static_cast<uint8_t>(params.marking_support);
}

/// tests/v8: V8's incremental marking starts on `isolate` (entered), as a
/// moderate memory pressure notification starts it (13.1 src/heap/heap.cc
/// Heap::CheckMemoryPressure: StartIncrementalMarking when incremental
/// marking is on and stopped); whether its C++ heap is marking now.
extern "C" bool v8_test_Isolate_StartIncrementalMarking(Isolate* isolate) {
    CollectingScope collecting(isolate);
    isolate->MemoryPressureNotification(MemoryPressureLevel::kModerate);
    CppHeap* heap = isolate->GetCppHeap();
    return heap && cppgc::subtle::HeapState::IsMarking(heap->GetHeapHandle());
}

/// tests/v8: whether `isolate`'s C++ heap is marking now.
extern "C" bool v8_test_Isolate_CppHeapIsMarking(Isolate* isolate) {
    CppHeap* heap = isolate->GetCppHeap();
    return heap && cppgc::subtle::HeapState::IsMarking(heap->GetHeapHandle());
}

Isolate* v8_Isolate_NewWithOptions(const CraneIsolateOptions* options);

Isolate* v8_Isolate_New() {
    return v8_Isolate_NewWithOptions(nullptr);
}

Isolate* v8_Isolate_NewWithOptions(const CraneIsolateOptions* options) {
    // Thread-safe, and a no-op once V8 has started. ffi.zig's v8_Isolate_New
    // starts it first with the runtime flags; this is the net below it.
    if (v8_Platform_Start(nullptr) == kPlatformDisposed) return nullptr;

    Isolate::CreateParams create_params;
    create_params.array_buffer_allocator_shared =
        std::shared_ptr<ArrayBuffer::Allocator>(ArrayBuffer::Allocator::NewDefaultAllocator());
    auto record = std::make_unique<IsolateData>();
    applyIsolateOptions(record.get(), options);
    applyHeapConstraints(create_params, options);
    // The agent's C++ heap, attached from Isolate::Initialize on and V8's to
    // free from then (IsolateData::cpp_heap says why).
    record->cpp_heap = newAgentCppHeap();
    create_params.cpp_heap = record->cpp_heap.get();
    // V8's built-in snapshot: always allowed (g_read_only_heap says why).
    (void)claimReadOnlyHeap(nullptr, 0);
    record->holds_read_only_heap = true;
    // Isolate::New is exactly Allocate + Initialize (13.1 api.cc:9935).
    // Only GetData/SetData are allowed between them (v8-isolate.h:591).
    Isolate* isolate = Isolate::Allocate();
    if (!isolate) {
        releaseReadOnlyHeap();
        return nullptr;
    }
    IsolateData* data = record.release();
    isolate->SetData(kIsolateDataSlot, data);
    Isolate::Initialize(isolate, create_params);
    adoptCppHeap(data);
    installGCPauseRecorder(isolate);
    installNodeWrapperRootsHandler(isolate);
    return isolate;
}

/// Whether `isolate` was restored from a snapshot (v8_Isolate_NewFromSnapshot).
bool v8_Isolate_IsFromSnapshot(Isolate* isolate) {
    IsolateData* data = isolateData(isolate);
    return data && data->startup_data.data;
}

/// The bytes V8 restores `isolate` from - its StartupData's `data` - and
/// their size in `out_size`, for tests; null (size 0) for an isolate made
/// afresh.
const char* v8_Isolate_SnapshotBlob(Isolate* isolate, size_t* out_size) {
    IsolateData* data = isolateData(isolate);
    if (out_size) *out_size = 0;
    if (!data || !data->startup_data.data) return nullptr;
    if (out_size) *out_size = static_cast<size_t>(data->startup_data.raw_size);
    return data->startup_data.data;
}

/// How many of `isolate`'s JSON (and default-export) modules wait for
/// evaluation (IsolateData::synthetic_json_exports), for tests.
size_t v8_Isolate_PendingSyntheticModuleCount(Isolate* isolate) {
    IsolateData* data = isolateData(isolate);
    return data ? data->synthetic_json_exports.size() : 0;
}

/// `isolate`'s null as a Global<Value>*, BORROWED: the isolate's record keeps
/// it for the isolate's life (IsolateData::null_value), so a conversion that
/// answers null where it would answer a wrapper - a Window whose realm has
/// ended (conversions.windowProxyOrNull) - acquires nothing, as the wrapper
/// cache's wrappers it answers otherwise are borrowed. Blink's
/// DOMWindow::Wrap answers v8::Null as a Local, nothing to release
/// (core/frame/dom_window.cc). On the isolate's thread. Null for an isolate
/// this file did not make (the snapshot creator's), which has no record.
Global<Value>* v8_Isolate_BorrowedNull(Isolate* isolate) {
    IsolateData* data = isolateData(isolate);
    if (!data) return nullptr;
    if (data->null_value.IsEmpty()) {
        HandleScope handle_scope(isolate);
        data->null_value.Reset(isolate, Null(isolate));
    }
    return &data->null_value;
}

void v8_Isolate_Dispose(Isolate* isolate) {
    if (isolate) {
        // The adapter's per-isolate record: its handles reset while their
        // isolate lives, on its thread. The record itself is deleted after
        // Isolate::Dispose, below: it holds the StartupData V8 points at.
        IsolateData* record = isolateData(isolate);
        if (record) {
            // The node wrapper registry ends first, while the isolate and its
            // record live: every node wrapper's slot reset and its reference
            // released (an agent's end did it already; a test's own isolate
            // may not have), so no weak callback can find the record gone.
            if (record->node_wrappers && record->node_wrappers_end) record->node_wrappers_end(record->node_wrappers);
            record->node_wrappers = nullptr;
            // What V8 was told of dropped wrappers' table entries is taken
            // back: the accounter ends holding nothing.
            takeBackTableEntries(record, isolate);
            // Its anchors' registry, unrooted while the heap lives: the
            // heap's termination in Isolate::Dispose collects it and every
            // anchor (none holds a slot any more), and no Persistent of the
            // record outlives the heap.
            releaseNodeAnchors(record);
            // Finalizers still queued run no more: the isolate is not
            // entered here and its realms are gone, so nothing of Zig's is
            // called. An agent's end drained the queue in its last forced
            // collections (protocol_agents.endAgent); what a test's own
            // isolate leaves is its owners' - each ends what it still holds
            // before this (WrapperCache.deinit, the registries). Only the
            // list goes: the records are freed below, the cancelled ones with
            // the detached set and the rest with pendingFinalizers().
            record->queued_finalizers.clear();
            record->unjudged_finalizers.clear();
            // No pass of V8's stores into the agent's queue from here on (the
            // agent's end withdrew the byte already; a test's own isolate
            // never registered one).
            record->finalizers_owed = nullptr;
            record->finalizers_owed_mask = 0;
            record->fresh_owed_mask = 0;
            record->foreground_tasks->close();
            isolate->SetData(kIsolateDataSlot, nullptr);
            for (SyntheticJsonExport* entry : record->synthetic_json_exports) deleteSyntheticExport(entry);
            record->synthetic_json_exports.clear();
            record->null_value.Reset();
        }

        // Records that a dispose detached from their Global while V8 still had
        // their callback queued. Disposing THIS isolate is the point at which
        // its callbacks provably will not run, so it is where they are freed.
        // Only its own: a worker isolate can be disposed from inside the page
        // isolate's first-pass weak callbacks, while the page's detached
        // records are still queued in that same pass.
        {
            std::lock_guard<std::mutex> guard(weakDataLock());
            for (auto it = detachedWeakData().begin(); it != detachedWeakData().end();) {
                WeakCallbackData* data = *it;
                if (data->isolate == isolate) {
                    it = detachedWeakData().erase(it);
                    freeWeakData(data);
                } else {
                    ++it;
                }
            }
        }

        // DefaultPlatform keeps a foreground task runner per isolate, holding
        // what V8 posted for it; without this a later isolate at the same
        // address inherits it and its stale tasks. d8 does this before every
        // Dispose (Worker::ExecuteInThread).
        if (g_platform.started.load(std::memory_order_acquire)) platform::NotifyIsolateShutdown(defaultPlatform(), isolate);

        // Its roots handler goes with the record, after Dispose: V8 stops
        // asking it first (every node wrapper ended above, so no droppable
        // reference is left for it to find).
        isolate->SetEmbedderRootsHandler(nullptr);

        // Dispose the isolate first
        isolate->Dispose();

        // Finalizers this isolate's safe points never ran: the queue's list
        // went above, uncalled, and an isolate with no record never had one.
        // Their owners finalized what they hold before ending the realm
        // (WrapperCache.deinit), so only the records are left. After Dispose,
        // so a first pass V8 did run during it found its record intact.
        {
            auto& pending = pendingFinalizers();
            for (auto it = pending.begin(); it != pending.end();) {
                WeakCallbackData* data = it->second;
                if (data->isolate == isolate) {
                    it = pending.erase(it);
                    freeWeakData(data);
                } else {
                    ++it;
                }
            }
        }

        // The isolate has left the group's count (ReadOnlyHeap::TearDown ran
        // inside Dispose): so does the adapter's record of its read-only heap.
        if (record && record->holds_read_only_heap) releaseReadOnlyHeap();

        // The record last: a snapshot isolate's StartupData is in it, and V8
        // held a pointer to that until Dispose returned ("The embedder owns
        // the blob", v8-isolate.h CreateParams::snapshot_blob). The bytes it
        // points at are the caller's, freed by the caller after this. Its C++
        // heap is gone already: Dispose deleted it (IsolateData::cpp_heap).
        delete record;
    }
}

void v8_Isolate_Enter(Isolate* isolate) {
    isolate->Enter();
}

void v8_Isolate_Exit(Isolate* isolate) {
    isolate->Exit();
}

// ----------------------------------------------------------------------------
// The agent's C++ heap (the wrapper redesign's P3: used by nothing yet)
// ----------------------------------------------------------------------------

/// Whether `isolate` has a C++ heap (Isolate::GetCppHeap): every isolate this
/// file makes has one from Isolate::Initialize on (IsolateData::cpp_heap).
bool v8_Isolate_HasCppHeap(Isolate* isolate) {
    return isolate && isolate->GetCppHeap() != nullptr;
}

/// The bytes of the objects on `isolate`'s C++ heap: CppHeap::CollectStatistics
/// at the brief level, its allocated object size - counters only, it sweeps
/// nothing (13.1.203 src/heap/cppgc/heap-base.cc, CollectStatistics). 0 with no
/// heap. The diagnostics tier's `cpp_heap_used_bytes`.
size_t v8_Isolate_CppHeapUsedBytes(Isolate* isolate) {
    CppHeap* heap = isolate ? isolate->GetCppHeap() : nullptr;
    if (!heap) return 0;
    return heap->CollectStatistics(cppgc::HeapStatistics::DetailLevel::kBrief).used_size_bytes;
}

// ---- tests/v8/cpp_heap_test.zig's probe ----
//
// A holder rooted by a cppgc::Persistent holds a leaf through a cppgc::Member.
// It answers what P3's red tests ask (design section 7, P3; risks R6, R7):
// - whether a Member reads back the object it was given: the cppgc defines
//   build.zig compiles this file with must be the archive's, or the headers
//   compress Member pointers with another shift than the library decompresses
//   them with;
// - whether a forced collection keeps both while the holder is rooted, and
//   frees both once it is not (weak persistents observe them without keeping
//   them);
// - where the holder's Trace runs: on the agent's thread, inside a major GC's
//   pause (between the prologue and epilogue V8 calls for mark-compact), never
//   while script runs - the atomic marking the host's tree walk will rely on
//   (design 4.4, 4.12).

/// What the probe saw; ffi.zig's CppHeapProbeState mirrors it.
struct CraneCppHeapProbeState {
    bool holder_alive;
    bool leaf_alive;
    /// The holder's Member reads back the leaf MakeGarbageCollected made.
    bool member_matches;
    /// The holder's Trace calls, those on another thread than the probe's,
    /// and those outside a mark-compact's prologue..epilogue.
    uint32_t traces;
    uint32_t traces_off_thread;
    uint32_t traces_outside_pause;
};

namespace {

struct CppHeapProbe;

class ProbeLeaf final : public cppgc::GarbageCollected<ProbeLeaf> {
 public:
    void Trace(cppgc::Visitor*) const {}
};

class ProbeHolder final : public cppgc::GarbageCollected<ProbeHolder> {
 public:
    ProbeHolder(CppHeapProbe* probe, ProbeLeaf* leaf) : probe_(probe), leaf_(leaf) {}
    void Trace(cppgc::Visitor* visitor) const;
    const ProbeLeaf* leaf() const { return leaf_.Get(); }

 private:
    /// The probe outlives every collection it watches (v8_test_CppHeapProbe_Delete).
    CppHeapProbe* probe_;
    cppgc::Member<ProbeLeaf> leaf_;
};

struct CppHeapProbe {
    Isolate* isolate = nullptr;
    CppHeap* heap = nullptr;
    /// The agent's thread: the one that made the probe.
    std::thread::id thread;
    /// Set by the mark-compact GC prologue, cleared by its epilogue.
    std::atomic<bool> in_major_gc{false};
    std::atomic<uint32_t> traces{0};
    std::atomic<uint32_t> traces_off_thread{0};
    std::atomic<uint32_t> traces_outside_pause{0};
    const ProbeLeaf* leaf_address = nullptr;
    cppgc::Persistent<ProbeHolder> root;
    cppgc::WeakPersistent<ProbeHolder> holder;
    cppgc::WeakPersistent<ProbeLeaf> leaf;

    // Members, so that they have C++ linkage inside this extern "C" block.
    static void majorGCPrologue(Isolate*, GCType, GCCallbackFlags, void* data) {
        static_cast<CppHeapProbe*>(data)->in_major_gc.store(true, std::memory_order_relaxed);
    }
    static void majorGCEpilogue(Isolate*, GCType, GCCallbackFlags, void* data) {
        static_cast<CppHeapProbe*>(data)->in_major_gc.store(false, std::memory_order_relaxed);
    }
};

void ProbeHolder::Trace(cppgc::Visitor* visitor) const {
    probe_->traces.fetch_add(1, std::memory_order_relaxed);
    if (std::this_thread::get_id() != probe_->thread) probe_->traces_off_thread.fetch_add(1, std::memory_order_relaxed);
    if (!probe_->in_major_gc.load(std::memory_order_relaxed)) probe_->traces_outside_pause.fetch_add(1, std::memory_order_relaxed);
    visitor->Trace(leaf_);
}

}  // namespace

/// `sizeof(cppgc::Member<T>)` as this file is compiled: 4 with the archive's
/// CPPGC_POINTER_COMPRESSION (the ABI check, design 4.12).
size_t v8_test_CppgcMemberSize() {
    return sizeof(cppgc::Member<ProbeLeaf>);
}

}  // extern "C" - the cppgc registry's declaration below is C++

// CraneWrappable, the base of every anchor, and the anchors' tags (crane_tags)
// are defined above, before the node anchors that IsolateData holds.

// ----------------------------------------------------------------------------
// GlobalAnchor: a realm global's native info (lane v8up b3c;
// tmp/plans/v8-global-object-design.md 1.1-1.2, 2.1-2.5). V8 >= 14 gives the
// embedder no handle to a context's JSGlobalObject (crbug.com/333672197);
// what it gives is Object::WrapGlobal, which sets ONE CppHeap pointer on the
// JSGlobalProxy AND on its hidden prototype, the JSGlobalObject (v8-object.h
// 662-668). Blink attaches the DOMWindow that way at context creation
// (LocalWindowProxy::SetupWindowPrototypeChain, local_window_proxy.cc 405-449,
// V8DOMWrapper::SetNativeInfoForGlobal) and a worker's global scope the same
// (WorkerOrWorkletScriptController::Initialize...,
// worker_or_worklet_script_controller.cc 205-213). Crane attaches a
// GlobalAnchor through one function, `v8_GlobalAnchor_Attach`, for every
// realm global: Window (fresh or restored from the snapshot - Blink wraps a
// restored context's global by the same SetupWindowPrototypeChain, 1.5),
// worker, worklet, ShadowRealm.
//
// What it carries:
// - `instance_`: the Zig global instance (a Window, a WorkerGlobalScope...),
//   NOT owned - Zig frees it and calls clear() first. Read by the realm's
//   WindowProperties object, which Blink wraps with the window too
//   (SetupWindowPrototypeChain 434-437: SetNativeInfo), so one clear() severs
//   the proxy's, the hidden global's and WindowProperties' link at once.
// - `retained_`: the realm's retained store, a plain object made in the
//   realm. What the realm's global keeps alive hangs on it as private
//   properties - its Window's traced edges (protocol_tracing), and once the
//   realm is detached its wrappers and callbacks (WrapperCache.detach,
//   v8_Object_WeakenTaggedHandles). The anchor traces it, so it lives exactly
//   while the global object does - the hidden global after a navigation
//   handed the proxy on (Blink 1.2: the old JSGlobalObject keeps its CppHeap
//   pointer to the OLD window, and tracing keeps what the window holds; no
//   handle to the old global exists). Crane's Window is a Zig object, not a
//   cppgc one, so its edges are JS edges from this store - the same graph:
//   global object -> anchor -> store -> what the Window keeps. Set once, in
//   the constructor, before the anchor is reachable: a concurrent marker
//   never reads it mid-write (the contract's concurrency rule).
//
// Zig never keeps a raw pointer to the anchor: it keeps a GlobalAnchorRef, a
// cppgc::WeakPersistent, which cppgc clears in the atomic pause of the
// collection that finds the anchor dead. That is the signal "the old global
// object is gone" (it replaces the weak handle to the hidden global that V8
// >= 14 no longer lets Crane make); a raw pointer told by the finalizer would
// be stale from the atomic pause to the sweep, while the store's traced node
// is already freed. The destructor is therefore the base's: it does nothing.
// ----------------------------------------------------------------------------
class GlobalAnchor final : public CraneWrappable {
 public:
    GlobalAnchor(Isolate* isolate, void* instance, Local<Object> retained)
        : instance_(instance), retained_(isolate, retained) {}

    void Trace(cppgc::Visitor* visitor) const override {
        CraneWrappable::Trace(visitor);
        visitor->Trace(retained_);
    }
    const char* GetHumanReadableName() const override { return "Crane GlobalAnchor"; }

    void* instance() const { return instance_; }
    /// The realm ends - its Zig instance is about to be freed: every JS
    /// object wrapped with this anchor - the proxy while it is this realm's,
    /// the hidden global, WindowProperties - finds no instance from now on,
    /// and the retained store goes now rather than at the collection that
    /// takes the global (what it kept is the ended realm's: its wrapper cache
    /// is torn down). Its traced node counts in V8's used global handle bytes,
    /// which a realm's end must leave as it found them (worklet_realm_test,
    /// worker_iterator_template_test). Reset is safe while a concurrent
    /// marker may read the reference (TracedReferenceBase's thread-safe slot,
    /// as Blink resets a TraceWrapperV8Reference).
    void clear() {
        instance_ = nullptr;
        retained_.Reset();
    }
    Local<Object> retained(Isolate* isolate) const { return retained_.Get(isolate); }

 private:
    void* instance_;
    TracedReference<Object> retained_;
};

static_assert(sizeof(GlobalAnchor) == 3 * sizeof(void*), "GlobalAnchor: the vptr, instance_, retained_ (one per realm global)");

/// What Zig holds of an anchor: cleared by cppgc when the anchor dies.
using GlobalAnchorRef = cppgc::WeakPersistent<GlobalAnchor>;

extern "C" {

/// THE attach function for a realm's global (design 2.1): `instance` (the
/// Zig global instance, or null for a realm with none - a ShadowRealm's) in
/// the global proxy's internal field 0, which the bindings read for a
/// receiver and every conversion reads for a WindowProxy value (as every
/// Crane wrapper carries its instance until lanes wr1/wrap1 move wrappers to
/// Object::Wrap), and a new GlobalAnchor set on the proxy and its hidden
/// global object by Object::WrapGlobal. Returns Zig's reference to the anchor
/// (v8_GlobalAnchor_Dispose), or null when the isolate has no C++ heap.
GlobalAnchorRef* v8_GlobalAnchor_Attach(Global<Context>* context, void* instance) {
    if (!context || context->IsEmpty()) return nullptr;
    Isolate* isolate = Isolate::GetCurrent();
    if (!isolate) return nullptr;
    CppHeap* heap = isolate->GetCppHeap();
    if (!heap) return nullptr;
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);
    Local<Object> proxy = ctx->Global();
    if (proxy->InternalFieldCount() >= 1) proxy->SetAlignedPointerInInternalField(0, instance, kCraneEmbedderDataTag);
    Local<Object> retained = Object::New(isolate);
    GlobalAnchor* anchor = cppgc::MakeGarbageCollected<GlobalAnchor>(heap->GetAllocationHandle(), isolate, instance, retained);
    Object::WrapGlobal(isolate, proxy, anchor, crane_tags::tag(crane_tags::kGlobalAnchor));
    return new GlobalAnchorRef(anchor);
}

/// A navigation hands `context`'s WindowProxy to a new realm (Blink
/// LocalWindowProxy::DisposeContext, kGlobalObjectIsDetached, step 2:
/// ClearNativeInfo, local_window_proxy.cc 205-214): the PROXY's CppHeap
/// pointer is cleared; the hidden global object keeps the old anchor. Called
/// before Context::DetachGlobal, while the proxy is still `context`'s.
void v8_GlobalAnchor_ClearProxy(Global<Context>* context) {
    if (!context || context->IsEmpty()) return;
    Isolate* isolate = Isolate::GetCurrent();
    if (!isolate) return;
    HandleScope handle_scope(isolate);
    Local<Object> proxy = context->Get(isolate)->Global();
    Object::Wrap(isolate, proxy, nullptr, crane_tags::tag(crane_tags::kGlobalAnchor));
}

/// Wrap `object` with `ref`'s anchor (Blink SetupWindowPrototypeChain: the
/// WindowProperties object gets the window's native info). A no-op once the
/// anchor is gone.
void v8_GlobalAnchor_WrapObject(GlobalAnchorRef* ref, Global<Object>* object) {
    if (!ref || !object || object->IsEmpty()) return;
    GlobalAnchor* anchor = ref->Get();
    if (!anchor) return;
    Isolate* isolate = Isolate::GetCurrent();
    if (!isolate) return;
    HandleScope handle_scope(isolate);
    Object::Wrap(isolate, object->Get(isolate), anchor, crane_tags::tag(crane_tags::kGlobalAnchor));
}

/// The anchor's instance is about to be freed (GlobalAnchor::clear). A no-op
/// once the anchor is gone.
void v8_GlobalAnchor_Clear(GlobalAnchorRef* ref) {
    if (!ref) return;
    if (GlobalAnchor* anchor = ref->Get()) anchor->clear();
}

/// Whether the anchor - and so the global object that holds it - is alive.
bool v8_GlobalAnchor_IsAlive(GlobalAnchorRef* ref) {
    return ref && ref->Get() != nullptr;
}

/// The realm's retained store (see GlobalAnchor), as a Global the caller
/// releases (v8_Global_Dispose); null once the anchor is gone.
Global<Value>* v8_GlobalAnchor_Retained(GlobalAnchorRef* ref) {
    if (!ref) return nullptr;
    GlobalAnchor* anchor = ref->Get();
    if (!anchor) return nullptr;
    Isolate* isolate = Isolate::GetCurrent();
    if (!isolate) return nullptr;
    HandleScope handle_scope(isolate);
    Local<Object> retained = anchor->retained(isolate);
    if (retained.IsEmpty()) return nullptr;
    return trackHandle(new Global<Value>(isolate, retained));
}

/// Zig's reference ends (the realm's end, on the agent's thread - a
/// WeakPersistent belongs to its heap's thread).
void v8_GlobalAnchor_Dispose(GlobalAnchorRef* ref) {
    delete ref;
}

/// The instance of the GlobalAnchor `info`'s holder is wrapped with - a
/// WindowProperties object's Window (window_properties.zig) - or null: no
/// anchor, or one cleared. Only for a holder Crane wrapped (an interceptor
/// installed on WindowProperties alone): Unwrap reads the object's CppHeap
/// pointer field, which an arbitrary object does not have.
void* v8_PropertyCallbackInfo_HolderGlobalAnchorInstance(const PropertyCallbackInfo<Value>* info) {
    Local<Object> holder = info->Holder();
    GlobalAnchor* anchor = Object::Unwrap<GlobalAnchor>(info->GetIsolate(), holder, crane_tags::kGlobalAnchorRange);
    return anchor ? anchor->instance() : nullptr;
}

/// Tests (tests/v8): the instance of the GlobalAnchor `object` (BORROWED) is
/// wrapped with - a global proxy, or a WindowProperties object - or null: none,
/// or one cleared. With `check_global`, `object` must be an ATTACHED global
/// proxy, and V8's Object::CheckGlobalWrappable first checks that the proxy
/// and its hidden global object carry the same anchor (a fatal API check when
/// they do not; on a detached proxy, whose hidden prototype is gone, it is a
/// CHECK failure - pass false there).
void* v8_Debug_GlobalAnchorInstanceOf(Global<Object>* object, bool check_global) {
    if (!object || object->IsEmpty()) return nullptr;
    Isolate* isolate = Isolate::GetCurrent();
    if (!isolate) return nullptr;
    HandleScope handle_scope(isolate);
    Local<Object> local = object->Get(isolate);
    if (check_global) (void)Object::CheckGlobalWrappable(isolate, local, crane_tags::kGlobalAnchorRange);
    GlobalAnchor* anchor = Object::Unwrap<GlobalAnchor>(isolate, local, crane_tags::kGlobalAnchorRange);
    return anchor ? anchor->instance() : nullptr;
}

/// Tests: whether `proxy` carries any GlobalAnchor (a cleared one too).
bool v8_Debug_HasGlobalAnchor(Global<Object>* proxy) {
    if (!proxy || proxy->IsEmpty()) return false;
    Isolate* isolate = Isolate::GetCurrent();
    if (!isolate) return false;
    HandleScope handle_scope(isolate);
    return Object::Unwrap<GlobalAnchor>(isolate, proxy->Get(isolate), crane_tags::kGlobalAnchorRange) != nullptr;
}

}  // extern "C"

// cppgc's own registry of the process's live C++ heaps: every heap registers
// in its constructor and unregisters in its destructor (13.1.203
// src/heap/cppgc/process-heap.h and process-heap.cc, HeapRegistry::Subscription).
// Exported by the archive, internal to V8 (V8_EXPORT_PRIVATE, not in
// include/): declared here with the one member the probe calls. Its size is
// the only measure of whether an agent's end FREED its heap - leaks --atExit
// cannot tell, because a heap nobody deleted stays reachable from this
// registry (lane wr2, P3: the CreateParams-only build reported 0 leaks).
namespace cppgc::internal {
class HeapBase;
class HeapRegistry final {
 public:
    using Storage = std::vector<HeapBase*>;
    // "Does not take the registry mutex and is thus only useful for testing."
    static const Storage& GetRegisteredHeapsForTesting();
};
}  // namespace cppgc::internal

extern "C" {

/// How many C++ heaps the process has alive (cppgc's heap registry), for
/// tests/v8/cpp_heap_test.zig. Unlocked: only for a test that has its process
/// to itself (build.zig v8_alone).
size_t v8_test_CppgcLiveHeaps() {
    return cppgc::internal::HeapRegistry::GetRegisteredHeapsForTesting().size();
}

/// The probe on `isolate`'s C++ heap, made on the agent's thread with the
/// isolate entered; null when the isolate has no heap. OWNED:
/// v8_test_CppHeapProbe_Delete, before the agent ends.
CppHeapProbe* v8_test_CppHeapProbe_New(Isolate* isolate) {
    CppHeap* heap = isolate ? isolate->GetCppHeap() : nullptr;
    if (!heap) return nullptr;
    auto* probe = new CppHeapProbe();
    probe->isolate = isolate;
    probe->heap = heap;
    probe->thread = std::this_thread::get_id();
    ProbeLeaf* leaf = cppgc::MakeGarbageCollected<ProbeLeaf>(heap->GetAllocationHandle());
    ProbeHolder* holder = cppgc::MakeGarbageCollected<ProbeHolder>(heap->GetAllocationHandle(), probe, leaf);
    probe->leaf_address = leaf;
    probe->root = holder;
    probe->holder = holder;
    probe->leaf = leaf;
    isolate->AddGCPrologueCallback(CppHeapProbe::majorGCPrologue, probe, kGCTypeMarkSweepCompact);
    isolate->AddGCEpilogueCallback(CppHeapProbe::majorGCEpilogue, probe, kGCTypeMarkSweepCompact);
    return probe;
}

/// A full collection of the probe's isolate (LowMemoryNotification), with no
/// conservative scan of the stack: a pointer left in a frame must not keep the
/// test's objects (cppgc::testing::OverrideEmbedderStackStateScope; the
/// probe's objects are reached only through its persistents).
void v8_test_CppHeapProbe_Collect(CppHeapProbe* probe) {
    CollectingScope collecting(probe->isolate);
    cppgc::testing::OverrideEmbedderStackStateScope no_stack_scan(probe->heap->GetHeapHandle(),
                                                                  cppgc::EmbedderStackState::kNoHeapPointers);
    probe->isolate->LowMemoryNotification();
}

/// The holder is rooted no more.
void v8_test_CppHeapProbe_DropRoot(CppHeapProbe* probe) {
    probe->root.Clear();
}

void v8_test_CppHeapProbe_State(CppHeapProbe* probe, CraneCppHeapProbeState* out) {
    const ProbeHolder* holder = probe->holder.Get();
    out->holder_alive = holder != nullptr;
    out->leaf_alive = probe->leaf.Get() != nullptr;
    out->member_matches = holder && holder->leaf() == probe->leaf_address;
    out->traces = probe->traces.load(std::memory_order_relaxed);
    out->traces_off_thread = probe->traces_off_thread.load(std::memory_order_relaxed);
    out->traces_outside_pause = probe->traces_outside_pause.load(std::memory_order_relaxed);
}

/// The probe's end: its GC callbacks removed, its persistents released.
void v8_test_CppHeapProbe_Delete(CppHeapProbe* probe) {
    if (!probe) return;
    probe->isolate->RemoveGCPrologueCallback(CppHeapProbe::majorGCPrologue, probe);
    probe->isolate->RemoveGCEpilogueCallback(CppHeapProbe::majorGCEpilogue, probe);
    delete probe;
}

// Live Global<Context> handles: created minus disposed.
//
// The same instrument that settled the string question. Cumulative creations
// cannot distinguish "created 6 per element and released 6" from "created 6 and
// released none" - and for strings the cumulative number turned out to be almost
// entirely startup, which made a 4-per-element leak look real when there was none.
// process-wide: a diagnostic count over every isolate of the process (std::atomic, relaxed), read by gc_bench, the WPT runner's per-file deltas and tests that hold the process to themselves (lesson testing-a-test-that-measures-a-process-wide-counter-assumes-it-is-alone); it carries no state any instance reads.
static std::atomic<int64_t> g_live_context_globals{0};

// Live Global<Object> handles: g_live_object_globals, kept by handle with the
// string count (rememberObjectHandle). Same reason as the context counter:
// cumulative creations cannot tell a released handle from a leaked one.

extern "C" int64_t v8_Debug_LiveObjectGlobals() {
    return g_live_object_globals.load(std::memory_order_relaxed);
}

// Per-entry-point creation counts. The aggregate says one Global<Object> leaks
// per element but not WHICH of the six mints it, and they all allocate at about
// the same rate, so the aggregate alone cannot separate them.
// process-wide: a diagnostic count over every isolate of the process (std::atomic, relaxed), read by gc_bench, the WPT runner's per-file deltas and tests that hold the process to themselves (lesson testing-a-test-that-measures-a-process-wide-counter-assumes-it-is-alone); it carries no state any instance reads.
static std::atomic<int64_t> g_obj_src[6];

extern "C" int64_t v8_Debug_ObjSrc(int i) {
    return (i >= 0 && i < 6) ? g_obj_src[i].load(std::memory_order_relaxed) : -1;
}

extern "C" int64_t v8_Debug_LiveContextGlobals() {
    return g_live_context_globals.load(std::memory_order_relaxed);
}

// Every function that returns a new Global<Context> counts it, because
// v8_Context_Dispose uncounts whichever it is handed. Uncounted creations -
// v8_FunctionCallbackInfo_GetFunctionCreationContext, taken by every binding
// getter and method call, among them - made live_context_globals fall by one
// per call, and by one per worker realm (NewWithGlobalConstructor).
static inline void countContextGlobal() {
    g_live_context_globals.fetch_add(1, std::memory_order_relaxed);
}

Global<Context>* v8_Isolate_GetCurrentContext(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Context> ctx = isolate->GetCurrentContext();
    g_live_context_globals.fetch_add(1, std::memory_order_relaxed);
    return trackHandle(new Global<Context>(isolate, ctx));
}

// Get the entered or microtask context (the "incumbent" context per HTML spec)
// This returns the context that was most recently entered via Context::Enter,
// or the microtask context if we're in a microtask. This is used for postMessage
// to get the source window - the context from which the message was sent.
Global<Context>* v8_Isolate_GetEnteredOrMicrotaskContext(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Context> ctx = isolate->GetEnteredOrMicrotaskContext();
    if (ctx.IsEmpty()) {
        return nullptr;
    }
    // Counted like v8_Isolate_GetCurrentContext's, because v8_Context_Dispose
    // uncounts whichever it is handed.
    g_live_context_globals.fetch_add(1, std::memory_order_relaxed);
    return trackHandle(new Global<Context>(isolate, ctx));
}

Isolate* v8_Isolate_GetCurrent() {
    return Isolate::GetCurrent();
}

// V8's own accounting of its heap, for telling a LEAK apart from a RESERVATION.
//
// Resident memory alone cannot: a JS engine that collects everything correctly
// still holds on to the pages it has already taken. `used` falling while RSS stays
// put means the heap is fine and V8 is simply not returning memory; `used` rising
// with RSS means objects really are being retained.
void v8_Isolate_GetHeapUsage(Isolate* isolate, size_t* used, size_t* total,
                             size_t* external) {
    HeapStatistics stats;
    isolate->GetHeapStatistics(&stats);
    if (used) *used = stats.used_heap_size();
    if (total) *total = stats.total_heap_size();
    if (external) *external = stats.external_memory();
}

// The host's native memory its objects keep alive (engine.AgentOptions.
// external_memory, src/runtime/engines/v8/external_memory.zig): one
// v8::ExternalMemoryAccounter per agent, the API V8 >= 13.x gives an embedder in
// place of Isolate::AdjustAmountOfExternalAllocatedMemory (deprecated in 15.7;
// both reach Heap::UpdateExternalMemory, api.cc 9906-9920 and 12660-12690 at
// 15.7.112.43). V8 counts the figure toward its global allocation limit and
// starts incremental marking once it is reached (heap.cc UpdateExternalMemory),
// as Blink's V8GCController::reportDOMMemoryUsageToV8 told it about the DOM
// partition (Chromium 45). The archive is built without
// V8_ENABLE_MEMORY_ACCOUNTING_CHECKS (its v8-gn.h refuses the define), so the
// accounter holds no state of its own: what it reports is external_memory.zig's
// `external_reported`, which _Delete takes back.
ExternalMemoryAccounter* v8_ExternalMemoryAccounter_New() {
    return new (std::nothrow) ExternalMemoryAccounter();
}

void v8_ExternalMemoryAccounter_Update(ExternalMemoryAccounter* accounter, Isolate* isolate, int64_t change_in_bytes) {
    {
        // V8 may collect here (Heap::UpdateExternalMemory): the collecting
        // isolate is the current one (collectingRecord).
        CollectingScope collecting(isolate);
        accounter->Update(isolate, change_in_bytes);
    }
    // The agent's safe point inside a task (`runQueuedFinalizers`). The report
    // is made only where a collection it starts meets no DOM frame below
    // (external_memory.zig: the binding exit to script at DOM-algorithm depth
    // zero, the microtask checkpoint), and V8's collector is off the stack
    // once it returns. What runs here: the finalizers V8's first passes
    // queued since the last safe point - above all those of the collection
    // this very report ran (Heap::UpdateExternalMemory's
    // CollectGarbageWithRetry, 15.7.112.43 src/heap/heap.cc:7021-7038): the
    // trees and objects it found dead give their native memory back before
    // the next report measures it. Without a safe point inside the task
    // they all waited for the pump, and each kept its native state until
    // then (300,000 dropped Events in one loop: 392 MB at the loop's end
    // instead of 168 MB, lane v8up b6). The binding exit itself is that safe
    // point now, for every script (v8_Isolate_RunQueuedFinalizers); this one
    // runs under the same two rules - not beneath a running finalizer, not
    // while the returning binding's exception is pending
    // (`runQueuedFinalizersInTask`).
    runQueuedFinalizersInTask(isolate);
}

void v8_ExternalMemoryAccounter_Delete(ExternalMemoryAccounter* accounter, Isolate* isolate, uint64_t reported) {
    accounter->Decrease(isolate, static_cast<size_t>(reported));
    delete accounter;
}

// All the external memory V8 counts toward its collections: ArrayBuffer backing
// stores (its ArrayBufferSweeper reports them through an accounter of its own)
// and what the host reported. HeapStatistics::external_memory() is the backing
// stores alone (api.cc: backing_store_bytes()), so it never shows the host's
// figure. GetTotalAmountOfExternalAllocatedMemoryForTesting reads the same atomic
// total (Heap::external_memory(), external_memory_total_) that 13.1's
// AdjustAmountOfExternalAllocatedMemory(0) returned, and starts nothing; it is
// the one public read of it at 15.7.
size_t v8_Isolate_GetExternalMemory(Isolate* isolate) {
    const int64_t amount = ExternalMemoryAccounter::GetTotalAmountOfExternalAllocatedMemoryForTesting(isolate);
    return amount < 0 ? 0 : static_cast<size_t>(amount);
}

// Native contexts alive in the heap - one per window, frame, worker and
// ShadowRealm still reachable - and how many of them V8 counts as detached
// (their global proxy was detached, yet something still retains them).
void v8_Isolate_GetContextCounts(Isolate* isolate, size_t* native_contexts,
                                 size_t* detached_contexts) {
    HeapStatistics stats;
    isolate->GetHeapStatistics(&stats);
    if (native_contexts) *native_contexts = stats.number_of_native_contexts();
    if (detached_contexts) *detached_contexts = stats.number_of_detached_contexts();
}

// Bytes of V8's global handle table in use: every live Global<T>, whoever made
// it, counted by V8 itself (GlobalHandles::UsedSize, adjusted as each handle is
// created or reset). Unlike the CRANE_TRACK_GLOBALS counters it is in every
// build, so a test can assert that an operation leaves no handle behind.
size_t v8_Isolate_GetGlobalHandleBytes(Isolate* isolate) {
    HeapStatistics stats;
    isolate->GetHeapStatistics(&stats);
    return stats.used_global_handles_size();
}

// Get the raw internal address of a context (for stable identity)
// Returns a unique identifier for the context that stays constant across Global/Local conversions
// A context's identity for Crane's realm registry (context_manager and every
// cache keyed like it): a number stored in the context's embedder data the
// first time it is asked for, never reused. This used to return the
// NativeContext's heap address, which a compacting GC changes - a realm
// registered before a full collection was no longer found after it, and a
// context moved onto a freed address would alias another realm's entry. Blink
// keys its per-context data the same way (V8PerContextData in the context's
// embedder data). Index 0 is V8's old debugger slot. Contexts made while a
// snapshot is being built get no id: a snapshot must not carry pointer
// embedder data, and nothing compacts during generation.
static constexpr int kCraneContextIdIndex = 1;
// process-wide: an id counter whose only property is uniqueness in the process (an id is compared only as a key of its agent's realm registry); every agent's thread draws from it with an atomic fetch-add, and it carries no state of any instance.
static std::atomic<uintptr_t> g_next_context_id{1};

/// `ctx`'s Crane id (v8_Context_GetRawAddress), given it on first use.
static void* CraneContextIdOf(Local<Context> ctx) {
    if (g_snapshot_mode) return *reinterpret_cast<void**>(*ctx);
    // Only Crane writes embedder data at this index, so a slot within the
    // array's length is ours.
    if (ctx->GetNumberOfEmbedderDataFields() > static_cast<uint32_t>(kCraneContextIdIndex)) {
        if (void* id = ctx->GetAlignedPointerFromEmbedderData(kCraneContextIdIndex, kCraneEmbedderDataTag)) return id;
    }
    // Shifted so the value is an aligned pointer, as the embedder-data API
    // requires; never zero.
    void* id = reinterpret_cast<void*>(g_next_context_id.fetch_add(1, std::memory_order_relaxed) << 3);
    ctx->SetAlignedPointerInEmbedderData(kCraneContextIdIndex, id, kCraneEmbedderDataTag);
    return id;
}

void* v8_Context_GetRawAddress(Global<Context>* context_handle) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    return CraneContextIdOf(context_handle->Get(isolate));
}

void v8_Isolate_ThrowException(Isolate* isolate, Global<Value>* exception) {
    HandleScope handle_scope(isolate);
    Local<Value> exc = exception->Get(isolate);
    isolate->ThrowException(exc);
}

void v8_Isolate_SetData(Isolate* isolate, int slot, void* data) {
    isolate->SetData(slot, data);
}

void* v8_Isolate_GetData(Isolate* isolate, int slot) {
    return isolate->GetData(slot);
}

// ============================================================================
// Context Management
// ============================================================================

void DeserializeInternalFields(Local<Object> holder, int index, StartupData payload, void* data);

/// A new context whose global is a plain object - ECMAScript's intrinsics,
/// no platform objects of its own - in either kind of isolate the adapter
/// makes. Every context the adapter makes for itself with no global of a
/// particular shape (engine.parseJsonInNewGlobal's new global,
/// engine.matchesPatternAttribute's utility context) is made here.
///
/// Never a bare Context::New(isolate). With no global template, Genesis makes
/// the snapshot's DEFAULT context (context_snapshot_index 0) and keeps the
/// global object deserialized with it, around a new global proxy sized from
/// the template passed in - none, so no embedder fields (bootstrapper.cc,
/// Genesis::Genesis: "instance_size = JSGlobalProxy::SizeWithEmbedderFields(
/// global_proxy_template.IsEmpty() ? 0 : ...)", then HookUpGlobalProxy). In
/// an isolate restored from Crane's snapshot, every page's and every WPT
/// runner agent's, that default global is the snapshot generator's Window
/// global, an instance of Window's instance template with internal fields;
/// the bootstrapper's InitializeExperimentalGlobal then faulted installing
/// Math.f16round (EXC_BAD_ACCESS / V8_Fatal in String::WriteToFlat <-
/// MessageFormatter::Format <- AddDataProperty <-
/// InitializeGlobal_js_float16array; tests/v8/new_global_snapshot_test.zig and
/// pattern_attribute_snapshot_test.zig).
///
/// With a global template Genesis takes its other branch ("If a global proxy
/// template was passed in it's used to recreate the global object and its
/// prototype chain, and the data and the accessor properties from the
/// deserialized global are copied onto it"): CreateNewGlobals makes a new
/// global object and reinitializes the proxy from the template, and
/// DeserializeInternalFields answers any internal field the default context
/// carries. An empty template has no prototype template, so the new global's
/// prototype is a fresh object inheriting Object.prototype, as V8's own
/// default global's is. In an isolate made without Crane's snapshot (V8's
/// built-in one) this is an ordinary new context with a plain global. In a
/// snapshot isolate the new global carries copies of the default global's
/// properties (the WebIDL interface objects); nothing here reads them.
static Local<Context> NewPlainGlobalContext(Isolate* isolate, MicrotaskQueue* microtask_queue = nullptr) {
    Local<ObjectTemplate> global_template = ObjectTemplate::New(isolate);
    return Context::New(isolate, nullptr, global_template, MaybeLocal<Value>(),
                        DeserializeInternalFieldsCallback(DeserializeInternalFields, nullptr), microtask_queue);
}

/// A new context with a plain global (NewPlainGlobalContext), in either kind
/// of isolate. Null when V8 could not make one.
Global<Context>* v8_Context_New(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Context> context = NewPlainGlobalContext(isolate);
    if (context.IsEmpty()) return nullptr;
    countContextGlobal();
    return trackHandle(new Global<Context>(isolate, context));
}

Global<Context>* v8_Context_NewWithGlobalTemplate(Isolate* isolate, Global<ObjectTemplate>* global_template) {
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_template = global_template->Get(isolate);
    Local<Context> context = Context::New(isolate, nullptr, local_template);
    countContextGlobal();
    return trackHandle(new Global<Context>(isolate, context));
}

/// Create a context using a FunctionTemplate's InstanceTemplate as the global.
/// This ensures that the global object inherits from the FunctionTemplate's prototype,
/// which is necessary for cross-realm Window support where properties like `name`
/// are defined as getters on Window.prototype.
///
/// Unlike v8_Context_NewWithGlobalTemplate which uses a plain ObjectTemplate,
/// this function creates a global object that:
/// 1. Has the shape defined by the FunctionTemplate's InstanceTemplate
/// 2. Has the FunctionTemplate's prototype in its prototype chain
///
/// Args:
///   isolate: V8 isolate
///   global_constructor: FunctionTemplate to use as the global object's "constructor"
///
/// Returns: New context with global object based on the FunctionTemplate
Global<Context>* v8_Context_NewWithGlobalConstructor(Isolate* isolate, Global<FunctionTemplate>* global_constructor) {
    HandleScope handle_scope(isolate);
    Local<FunctionTemplate> local_template = global_constructor->Get(isolate);
    Local<ObjectTemplate> instance_template = local_template->InstanceTemplate();
    Local<Context> context = Context::New(isolate, nullptr, instance_template);
    countContextGlobal();
    return trackHandle(new Global<Context>(isolate, context));
}

void v8_Context_Dispose(Global<Context>* context) {
    if (!context) return;
    // Snapshot-mode guarded like the other disposals: trackHandle registers these
    // for bulk cleanup while the snapshot is built.
    if (g_snapshot_mode) return;
    g_live_context_globals.fetch_sub(1, std::memory_order_relaxed);
    releaseWeakArm(context);
    context->Reset();
    delete context;
}

void v8_Context_Enter(Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> local_context = context->Get(isolate);
    local_context->Enter();
}

void v8_Context_Exit(Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> local_context = context->Get(isolate);
    local_context->Exit();
}

// ============================================================================
// Context Disposal Functions (Chrome-style lifecycle management)
// ============================================================================

/// Detach the global object from the context.
///
/// Per Chrome's WindowProxy lifecycle, this is called during navigation to break
/// the link between the context and its global proxy. The global proxy is preserved
/// and can be reused with a new context on the next navigation.
///
/// This is step 1 of Chrome's context disposal sequence:
/// 1. DetachGlobal() - break context/global link
/// 2. Exit context
/// 3. ContextDisposedNotification() - hint GC
/// 4. Release persistent handle
///
/// @param context - The context to detach global from
void v8_Context_DetachGlobal(Global<Context>* context) {
    if (!context) return;

    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> local_context = context->Get(isolate);
    local_context->DetachGlobal();
}

/// Tell V8 a context was disposed, and whether it had dependants - Blink's
/// V8GCForContextDispose::NotifyContextDisposed (third_party/blink/renderer/
/// bindings/core/v8/v8_gc_for_context_dispose.cc, Chromium 157.0.8103.51),
/// which LocalWindowProxy::DisposeContext calls after it detached the global
/// and exited the context:
///
///     isolate->ContextDisposedNotification(
///         is_main_frame ? v8::ContextDependants::kNoDependants
///                       : v8::ContextDependants::kSomeDependants);
///
/// What V8 15.7 does with it (src/heap/heap.cc Heap::NotifyContextDisposed):
/// kNoDependants - a page went - forgets the survival statistics, takes the
/// allocation limits back to their initial values and tells the memory
/// reducer there may be garbage; kSomeDependants - a frame of a page that
/// lives on - posts a task that runs a young collection unless one ran since.
/// Neither collects anything here.
///
/// V8 takes the isolate's CURRENT context for the disposed one: with
/// kNoDependants it aborts that context's asynchronous WebAssembly
/// compilations (15.7 src/api/api.cc Isolate::ContextDisposedNotification:
/// "We left the current context, we can abort all WebAssembly compilations
/// of that context" - WasmEngine::DeleteCompileJobsOnContext), and with
/// either it drops that context's dirty FinalizationRegistries and retained
/// maps (Heap::NotifyContextDisposed). Blink is inside a ScriptState::Scope
/// of the context it disposes for the whole of DisposeContext; so `disposed`
/// is entered here for the call. Sent with another page's context entered,
/// it deleted that page's compile jobs, and their promises never settled
/// (tests/v8/page_realm_operations_test.zig, "a page that ends does not
/// abort another page's WebAssembly compilation"). A context the collector
/// already took is not told of: V8 collected it itself.
///
/// @param disposed - the context being disposed, still alive.
/// @param has_dependants - false for a main frame's context, true for a child
///     frame's.
void v8_Isolate_ContextDisposedNotification(Isolate* isolate, Global<Context>* disposed, bool has_dependants) {
    if (!isolate || !disposed || disposed->IsEmpty()) return;
    HandleScope handle_scope(isolate);
    Local<Context> context = disposed->Get(isolate);
    if (context.IsEmpty()) return;
    Context::Scope entered(context);
    if (IsolateData* record = isolateData(isolate)) ++record->context_disposals[has_dependants ? 1 : 0];
    isolate->ContextDisposedNotification(has_dependants ? ContextDependants::kSomeDependants : ContextDependants::kNoDependants);
}

/// navigation_collection.zig: a navigation replaced a main frame's document
/// (IsolateData::navigation_collection_owed). On the isolate's thread.
extern "C" void v8_Isolate_OweNavigationCollection(Isolate* isolate) {
    if (IsolateData* record = isolateData(isolate)) record->navigation_collection_owed = true;
}

/// Whether a navigation's collection was owed; it is not any more. Read at
/// every engine-task step, so it is one field of the isolate's own record,
/// no lock. On the isolate's thread.
extern "C" bool v8_Isolate_TakeNavigationCollectionOwed(Isolate* isolate) {
    IsolateData* record = isolateData(isolate);
    if (!record || !record->navigation_collection_owed) return false;
    record->navigation_collection_owed = false;
    return true;
}

/// `isolate`'s context disposals so far, by what V8 was told
/// (IsolateData::context_disposals): 0 for a null isolate or one this file
/// did not make. On the isolate's thread.
extern "C" void v8_Debug_ContextDisposals(Isolate* isolate, uint64_t* main_frame, uint64_t* child_frame) {
    *main_frame = 0;
    *child_frame = 0;
    IsolateData* record = isolateData(isolate);
    if (!record) return;
    *main_frame = record->context_disposals[0];
    *child_frame = record->context_disposals[1];
}

/// Tell V8 how short of memory the system is - Isolate::
/// MemoryPressureNotification, the one signal Blink sends for it
/// (content/renderer/blink_isolates_pressure_listener.cc OnReleaseMemory ->
/// blink::MemoryPressureNotificationToAllIsolates; Blink's MemoryPurgeManager
/// reaches the same call through a critical pressure notice when a renderer
/// has been in the background). `level`: 0 none, 1 moderate, 2 critical
/// (v8::MemoryPressureLevel; ffi.zig MemoryPressureLevel). On the isolate's
/// thread V8 answers at once (15.7 src/heap/heap.cc Heap::CheckMemoryPressure):
/// moderate starts an incremental collection that reduces the footprint,
/// which its marking job finishes in foreground tasks; critical drops its
/// caches and collects everything now, a second time when the first left
/// much to free (CollectGarbageOnMemoryPressure).
void v8_Isolate_MemoryPressureNotification(Isolate* isolate, int level) {
    if (!isolate) return;
    // A critical notice collects before it returns: the collecting isolate
    // is the current one (collectingRecord).
    CollectingScope collecting(isolate);
    isolate->MemoryPressureNotification(level >= 2 ? MemoryPressureLevel::kCritical
                                        : level == 1 ? MemoryPressureLevel::kModerate
                                                     : MemoryPressureLevel::kNone);
    // A critical notice collected before returning: the finalizers its
    // first pass queued run now, V8's collector off the stack
    // (`runQueuedFinalizers`).
    runQueuedFinalizers(isolate);
}

Global<Object>* v8_Context_Global(Global<Context>* context) {
    g_obj_src[2].fetch_add(1, std::memory_order_relaxed);
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> local_context = context->Get(isolate);
    Local<Object> global = local_context->Global();
    return trackHandle(new Global<Object>(isolate, global));
}

// Set the security token of a context
// Contexts with the same security token are considered same-origin
void v8_Context_SetSecurityToken(Global<Context>* context, Global<Value>* token) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> local_context = context->Get(isolate);
    Local<Value> local_token = token->Get(isolate);
    local_context->SetSecurityToken(local_token);
}

// Get the security token of a context
Global<Value>* v8_Context_GetSecurityToken(Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> local_context = context->Get(isolate);
    Local<Value> token = local_context->GetSecurityToken();
    return trackHandle(new Global<Value>(isolate, token));
}

// Give `to` the security token of `from`, both BORROWED: the token goes from
// one context to the other as a Local in this call's scope, so no handle is
// made for the caller to release. The ShadowRealm callback read it through
// v8_Context_GetSecurityToken and never released that Global: one box and
// one global-handle node per `new ShadowRealm()` (lane anim1's leaks
// --atExit: 148 leaks rooted there; tests/v8/perf3_security_token_copy_test.zig).
void v8_Context_InheritSecurityToken(Global<Context>* to, Global<Context>* from) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> from_context = from->Get(isolate);
    to->Get(isolate)->SetSecurityToken(from_context->GetSecurityToken());
}

// Use the default security token for a context
// This makes the context same-origin with itself only
void v8_Context_UseDefaultSecurityToken(Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> local_context = context->Get(isolate);
    local_context->UseDefaultSecurityToken();
}

// Allow or disallow code generation from strings (eval, Function constructor)
// This is needed for ShadowRealm contexts to enable eval() and new Function()
// which are standard JavaScript features per TC39 spec.
void v8_Context_AllowCodeGenerationFromStrings(Global<Context>* context, bool allow) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> local_context = context->Get(isolate);
    local_context->AllowCodeGenerationFromStrings(allow);
}

// ============================================================================
// String Functions
// ============================================================================

// Live Global<String> handles (rememberStringHandle above; 0 outside gc_bench).
//
// Every one of these is a C++ heap allocation AND a slot in V8's global handle
// table, which lives outside `used_heap_size` - so a leak here is invisible to
// GetHeapStatistics while being perfectly visible in RSS.
int64_t v8_Debug_LiveStringGlobals() {
    return g_live_string_globals.load(std::memory_order_relaxed);
}

Global<String>* v8_String_NewFromUtf8(Isolate* isolate, const uint8_t* data, int length) {
    HandleScope handle_scope(isolate);
    MaybeLocal<String> maybe_str = String::NewFromUtf8(
        isolate,
        reinterpret_cast<const char*>(data),
        NewStringType::kNormal,
        length
    );
    if (maybe_str.IsEmpty()) {
        return nullptr;
    }
    Local<String> str = maybe_str.ToLocalChecked();
    return trackHandle(new Global<String>(isolate, str));
}

void v8_String_Dispose(Global<String>* str) {
    if (str) {
        // See v8_ObjectTemplate_Dispose. Without this the handle is deleted here
        // AND again by v8_Snapshot_ClearGlobalHandles, which walks
        // g_snapshot_handles. tools/minimal_snapshot_test.zig:330 disposes a string
        // created inside snapshot mode and then clears the handles - a live
        // use-after-free that this guard fixes, independent of any new disposal.
        if (g_snapshot_mode) return;
        forgetCountedHandle(str);
        releaseWeakArm(str);
        str->Reset();
        delete str;
    }
}

/// V8 13.1's `String::WriteUtf8(isolate, buffer, capacity)` - no options - the
/// contract `v8_String_WriteUtf8`'s callers read (helpers.writtenUtf8,
/// intl_binding, observable_array, conversions, protocol_values): as many
/// whole characters as fit; then, if every character was written and a byte
/// is left, a NUL, COUNTED in the result; a capacity of -1 is unbounded
/// (13.1 src/api/api.cc WriteUtf8Impl: "Only null-terminate if there's
/// space"). V8 14 gave the name WriteUtf8 to the former WriteUtf8V2
/// (v8-primitive.h at 15.7.112.43), which writes no NUL unless asked
/// (kNullTerminate) and, asked, writes one even where it costs the last
/// character - so neither flag reproduces 13.1: the NUL is added here.
/// Lone surrogates stay three-byte sequences (no kReplaceInvalidUtf8), as
/// 13.1 wrote them without REPLACE_INVALID_UTF8.
static int writeUtf8NulIfRoom(Isolate* isolate, const String* str, char* buffer, int capacity) {
    const size_t cap = capacity < 0 ? str->Utf8Length(isolate) + 1 : static_cast<size_t>(capacity);
    size_t chars = 0;
    size_t written = str->WriteUtf8(isolate, buffer, cap, String::WriteFlags::kNone, &chars);
    if (chars == static_cast<size_t>(str->Length()) && written < cap) buffer[written++] = '\0';
    return static_cast<int>(written);
}

int v8_String_Utf8Length(Global<String>* str) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<String> local_str = str->Get(isolate);
    return local_str->Utf8Length(isolate);
}

int v8_String_WriteUtf8(Global<String>* str, char* buffer, int length) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<String> local_str = str->Get(isolate);
    return writeUtf8NulIfRoom(isolate, *local_str, buffer, length);
}

Global<String>* v8_String_Empty(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<String> empty = String::Empty(isolate);
    return trackHandle(new Global<String>(isolate, empty));
}

// ============================================================================
// Value Functions
// ============================================================================

bool v8_Value_IsUndefined(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsUndefined();
}

bool v8_Value_IsString(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsString();
}

bool v8_Value_IsNull(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsNull();
}

bool v8_Value_IsBoolean(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsBoolean();
}

bool v8_Value_IsNumber(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsNumber();
}

bool v8_Value_IsSymbol(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsSymbol();
}

bool v8_Value_IsBigInt(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsBigInt();
}

// NOTE: These v8_Value_Is* functions now accept EITHER a Global<Value>* OR a raw V8 tagged pointer
// (from a Local handle's internal slot). We use a heuristic to detect which:
// - Global<Value>* pointers are heap-allocated and have specific alignment
// - Raw V8 tagged pointers have the low bit set for SMIs or point to V8 heap objects
//
// Actually, this approach is fragile. Let's instead create separate functions for Local vs Global.
// For now, we'll add new _Local variants that take void* representing the raw tagged pointer.

bool v8_Value_IsObject(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsObject();
}

// Version for Local handle internal pointers
bool v8_Value_IsObject_Local(void* value_ptr) {
    if (!value_ptr) return false;
    // The value_ptr IS the internal Value* pointer from a Local<Value>
    // Cast it directly to Value* - V8 handles pointer tagging internally
    Value* val = reinterpret_cast<Value*>(value_ptr);
    return val->IsObject();
}

// Version for Local handle internal pointers - safe for Smis and raw V8 pointers
bool v8_Value_IsSymbol_Local(void* value_ptr) {
    if (!value_ptr) return false;
    // The value_ptr IS the internal Value* pointer from a Local<Value>
    // Cast it directly to Value* - V8 handles pointer tagging internally
    Value* val = reinterpret_cast<Value*>(value_ptr);
    return val->IsSymbol();
}

// Version for Local handle internal pointers - safe for Smis and raw V8 pointers
bool v8_Value_IsString_Local(void* value_ptr) {
    if (!value_ptr) return false;
    // The value_ptr IS the internal Value* pointer from a Local<Value>
    // Cast it directly to Value* - V8 handles pointer tagging internally
    Value* val = reinterpret_cast<Value*>(value_ptr);
    return val->IsString();
}

bool v8_Value_IsFunction(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    if (!isolate) return false;
    HandleScope handle_scope(isolate);
    if (value->IsEmpty()) return false;
    Local<Value> val = value->Get(isolate);
    return !val.IsEmpty() && val->IsFunction();
}

// ECMAScript IsConstructor(value): an object with a [[Construct]] internal
// method (v8::Object::IsConstructor); false for a non-object.
bool v8_Value_IsConstructor(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    if (!isolate) return false;
    HandleScope handle_scope(isolate);
    if (value->IsEmpty()) return false;
    Local<Value> val = value->Get(isolate);
    if (val.IsEmpty() || !val->IsObject()) return false;
    return val.As<Object>()->IsConstructor();
}

// Version for Local handle internal pointers
bool v8_Value_IsFunction_Local(void* value_ptr) {
    if (!value_ptr) return false;
    // Reconstruct Local from internal pointer
    Local<Value> val = *reinterpret_cast<Local<Value>*>(&value_ptr);
    return val->IsFunction();
}

bool v8_Value_IsArray(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsArray();
}

bool v8_Value_IsArrayBuffer(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsArrayBuffer();
}

bool v8_Value_IsSharedArrayBuffer(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsSharedArrayBuffer();
}

bool v8_Value_IsArrayBufferView(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsArrayBufferView();
}

// Version for Local handle internal pointers
bool v8_Value_IsArray_Local(void* value_ptr) {
    if (!value_ptr) return false;
    // Reconstruct Local from internal pointer
    Local<Value> val = *reinterpret_cast<Local<Value>*>(&value_ptr);
    return val->IsArray();
}

bool v8_Value_IsPromise(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsPromise();
}

bool v8_Value_IsNullOrUndefined(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsNullOrUndefined();
}

// Version for Local handle internal pointers
bool v8_Value_IsNullOrUndefined_Local(void* value_ptr) {
    if (!value_ptr) return false;
    Local<Value> val = *reinterpret_cast<Local<Value>*>(&value_ptr);
    return val->IsNullOrUndefined();
}

/// Check if a value has [[IsHTMLDDA]] internal slot (document.all)
/// Per ECMA-262, these "undetectable" objects are falsy despite being objects.
/// Used for WebIDL this-value validation - document.all should throw TypeError
/// when used as 'this' for incompatible operations.
bool v8_Value_IsUndetectable(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsObject() && val.As<Object>()->IsUndetectable();
}

// Version for Local handle internal pointers (raw V8 tagged pointer)
bool v8_Value_IsUndetectable_Local(void* value_ptr) {
    if (!value_ptr) return false;
    Local<Value> val = *reinterpret_cast<Local<Value>*>(&value_ptr);
    return val->IsObject() && val.As<Object>()->IsUndetectable();
}

bool v8_Value_BooleanValue(Global<Value>* value, Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->BooleanValue(isolate);
}

double v8_Value_NumberValue(Global<Value>* value, Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Value> val = value->Get(isolate);
    
    Maybe<double> maybe_num = val->NumberValue(ctx);
    return maybe_num.FromMaybe(0.0);
}

int32_t v8_Value_Int32Value(Global<Value>* value, Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Value> val = value->Get(isolate);
    
    Maybe<int32_t> maybe_int = val->Int32Value(ctx);
    return maybe_int.FromMaybe(0);
}

// ToInt32 for a WebIDL `long` argument (no [EnforceRange] or [Clamp]): ToNumber,
// then modulo 2^32 into the signed range - so 2**32 is 0. ToNumber runs user code
// (valueOf, Symbol.toPrimitive) and can throw, which v8_Value_Int32Value's
// FromMaybe(0) cannot tell from a real 0. False means it threw; the exception is
// left PENDING, so a FunctionCallback that returns at once rethrows it to script.
bool v8_Value_ToInt32(Global<Value>* value, Global<Context>* context, int32_t* out) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    Maybe<int32_t> result = value->Get(isolate)->Int32Value(ctx);
    if (result.IsNothing()) return false;
    *out = result.FromJust();
    return true;
}

uint32_t v8_Value_Uint32Value(Global<Value>* value, Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Value> val = value->Get(isolate);
    
    Maybe<uint32_t> maybe_uint = val->Uint32Value(ctx);
    return maybe_uint.FromMaybe(0);
}

int64_t v8_Value_IntegerValue(Global<Value>* value, Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Value> val = value->Get(isolate);
    
    Maybe<int64_t> maybe_int = val->IntegerValue(ctx);
    return maybe_int.FromMaybe(0);
}

Global<String>* v8_Value_ToString(Global<Value>* value, Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Value> val = value->Get(isolate);
    
    MaybeLocal<String> maybe_str = val->ToString(ctx);
    if (maybe_str.IsEmpty()) {
        return nullptr;
    }
    
    Local<String> str = maybe_str.ToLocalChecked();
    return trackHandle(new Global<String>(isolate, str));
}

// Version for raw V8 internal pointers (from interceptor callbacks)
Global<String>* v8_Value_ToString_Local(void* value_ptr, Global<Context>* context) {
    if (!value_ptr) return nullptr;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    // Cast raw pointer directly to Value* - V8 handles pointer tagging internally
    Value* val = reinterpret_cast<Value*>(value_ptr);
    
    MaybeLocal<String> maybe_str = val->ToString(ctx);
    if (maybe_str.IsEmpty()) {
        return nullptr;
    }
    
    Local<String> str = maybe_str.ToLocalChecked();
    return trackHandle(new Global<String>(isolate, str));
}

V8ToStringResult* v8_Value_ToString_Safe(Global<Value>* value, Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    V8ToStringResult* result = new V8ToStringResult();
    result->value = nullptr;
    result->exception = nullptr;
    
    Local<Context> ctx = context->Get(isolate);
    Local<Value> val = value->Get(isolate);
    
    TryCatch try_catch(isolate);
    
    MaybeLocal<String> maybe_str = val->ToString(ctx);
    
    if (try_catch.HasCaught()) {
        Local<Value> exception = try_catch.Exception();
        result->exception = trackHandle(new Global<Value>(isolate, exception));
        return result;
    }
    
    if (maybe_str.IsEmpty()) {
        return result;
    }
    
    Local<String> str = maybe_str.ToLocalChecked();
    result->value = trackHandle(new Global<String>(isolate, str));
    return result;
}

void v8_FreeToStringResult(V8ToStringResult* result) {
    if (!result) return;

    // Release the HANDLES, not just the struct that points at them.
    //
    // `v8_Value_ToString_Safe` fills both fields with `trackHandle(new Global<...>)`
    // - a C++ allocation plus a slot in V8's global handle table - and deleting the
    // struct alone leaked both. Every caller already does
    // `defer v8_FreeToStringResult(result)`, so this fixes them all at once, and it
    // measured at 1.2 handles per DOM object on the createElement path.
    //
    // Callers copy the string out before this runs (`v8_String_Utf8Length` +
    // `WriteUtf8`, or `fromV8String`), and `v8_Isolate_ThrowException` converts the
    // exception to a Local and hands it to V8, which roots it independently.
    //
    // Snapshot-mode guarded like every other disposal here: `trackHandle` registers
    // these for bulk cleanup while the snapshot is built, and freeing them twice
    // aborts inside `resetGlobalHandle`.
    if (!g_snapshot_mode) {
        if (result->value) {
            forgetCountedHandle(result->value);
            result->value->Reset();
            delete result->value;
        }
        if (result->exception) {
            result->exception->Reset();
            delete result->exception;
        }
    }
    delete result;
}

bool v8_Value_StrictEquals(Global<Value>* value1, Global<Value>* value2) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Value> v1 = value1->Get(isolate);
    Local<Value> v2 = value2->Get(isolate);
    
    return v1->StrictEquals(v2);
}

void v8_Value_Dispose(Global<Value>* value) {
    // Snapshot mode: trackHandle queued this handle for bulk cleanup (see
    // v8_ObjectTemplate_Dispose), so deleting it here too is a double free.
    if (g_snapshot_mode) return;
    if (value) {
        forgetCountedHandle(value);
        releaseWeakArm(value);
        untagRealmHandle(value);
        value->Reset();
        delete value;
    }
}

// ============================================================================
// Number Functions
// ============================================================================

Global<Number>* v8_Number_New(Isolate* isolate, double value) {
    HandleScope handle_scope(isolate);
    Local<Number> num = Number::New(isolate, value);
    return trackHandle(new Global<Number>(isolate, num));
}

Global<Number>* v8_Integer_New(Isolate* isolate, int32_t value) {
    HandleScope handle_scope(isolate);
    Local<Integer> num = Integer::New(isolate, value);
    return trackHandle(new Global<Number>(isolate, num.As<Number>()));
}

// ============================================================================
// Date Functions
// ============================================================================

bool v8_Value_IsDate(Global<Value>* value) {
    if (!value || value->IsEmpty()) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsDate();
}

bool v8_Value_IsDate_Local(void* value_ptr) {
    if (!value_ptr) return false;
    // Reconstruct Local<Value> from internal pointer (same pattern as v8_Value_IsFunction_Local)
    Local<Value> val = *reinterpret_cast<Local<Value>*>(&value_ptr);
    return val->IsDate();
}

// Create a new Date object from a timestamp (milliseconds since epoch)
// Uses the current context from the isolate (like v8_JSON_Stringify_ToBuffer)
Global<Value>* v8_Date_New(Isolate* isolate, Context* context_raw, double time) {
    HandleScope handle_scope(isolate);

    // Get the CURRENT context from the isolate (not the passed context!)
    // This avoids context mismatch issues when called from within script execution
    Local<Context> ctx = isolate->GetCurrentContext();
    if (ctx.IsEmpty()) {
        return nullptr;
    }
    Context::Scope context_scope(ctx);

    MaybeLocal<Value> maybe_date = Date::New(ctx, time);
    if (maybe_date.IsEmpty()) {
        return nullptr;
    }
    Local<Value> date = maybe_date.ToLocalChecked();
    return trackHandle(new Global<Value>(isolate, date));
}

// Get the timestamp (milliseconds since epoch) from a Date object
double v8_Date_ValueOf(Global<Value>* date_value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = date_value->Get(isolate);
    if (!val->IsDate()) {
        return std::numeric_limits<double>::quiet_NaN();
    }
    Local<Date> date = val.As<Date>();
    return date->ValueOf();
}

// ============================================================================
// RegExp Functions
// ============================================================================

bool v8_Value_IsRegExp(Global<Value>* value) {
    if (!value || value->IsEmpty()) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsRegExp();
}

// Get the source pattern string from a RegExp object
// Returns a Global<String>* that the caller must manage
Global<String>* v8_RegExp_GetSource(Global<Value>* regexp_value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = regexp_value->Get(isolate);
    if (!val->IsRegExp()) {
        return nullptr;
    }
    Local<RegExp> regexp = val.As<RegExp>();
    Local<String> source = regexp->GetSource();
    return trackHandle(new Global<String>(isolate, source));
}

// Get the flags from a RegExp object as a bitmask
// Returns V8's RegExp::Flags enum value
int v8_RegExp_GetFlags(Global<Value>* regexp_value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = regexp_value->Get(isolate);
    if (!val->IsRegExp()) {
        return 0;
    }
    Local<RegExp> regexp = val.As<RegExp>();
    return static_cast<int>(regexp->GetFlags());
}

// Create a new RegExp object from a pattern string and flags
// Uses the current context from the isolate
Global<Value>* v8_RegExp_New(Isolate* isolate, Context* context_raw, Global<String>* pattern, int flags) {
    HandleScope handle_scope(isolate);

    // Get the CURRENT context from the isolate (not the passed context!)
    Local<Context> ctx = isolate->GetCurrentContext();
    if (ctx.IsEmpty()) {
        return nullptr;
    }
    Context::Scope context_scope(ctx);

    // Get the pattern string from the Global handle
    Local<String> pattern_str = pattern->Get(isolate);

    MaybeLocal<RegExp> maybe_regexp = RegExp::New(ctx, pattern_str, static_cast<RegExp::Flags>(flags));
    if (maybe_regexp.IsEmpty()) {
        return nullptr;
    }
    Local<RegExp> regexp = maybe_regexp.ToLocalChecked();
    return trackHandle(new Global<Value>(isolate, regexp));
}

// ============================================================================
// ArrayBuffer Functions (for structuredClone)
// ============================================================================

// Check if an ArrayBuffer value is detached
// Detached buffers cannot be cloned per HTML spec
bool v8_ArrayBuffer_IsDetachedValue(Global<Value>* value) {
    if (!value || value->IsEmpty()) return true;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    if (!val->IsArrayBuffer()) {
        return true;
    }
    Local<ArrayBuffer> buffer = val.As<ArrayBuffer>();
    return buffer->WasDetached();
}

// Get the byte length from an ArrayBuffer value
size_t v8_ArrayBuffer_GetByteLength_Value(Global<Value>* value) {
    if (!value || value->IsEmpty()) return 0;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    if (!val->IsArrayBuffer()) {
        return 0;
    }
    Local<ArrayBuffer> buffer = val.As<ArrayBuffer>();
    return buffer->ByteLength();
}

// Get the data pointer from an ArrayBuffer value
void* v8_ArrayBuffer_GetData_Value(Global<Value>* value) {
    if (!value || value->IsEmpty()) return nullptr;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    if (!val->IsArrayBuffer()) {
        return nullptr;
    }
    Local<ArrayBuffer> buffer = val.As<ArrayBuffer>();
    if (buffer->WasDetached()) {
        return nullptr;
    }
    return buffer->Data();
}

// Create a new ArrayBuffer with copied data
// This is the key function for structuredClone
Global<Value>* v8_ArrayBuffer_NewWithData(Isolate* isolate, Context* context_raw, void* data, size_t byte_length) {
    HandleScope handle_scope(isolate);

    // Get the current context
    Local<Context> ctx = isolate->GetCurrentContext();
    if (ctx.IsEmpty()) {
        return nullptr;
    }
    Context::Scope context_scope(ctx);

    // Create a new ArrayBuffer with the specified size
    Local<ArrayBuffer> buffer = ArrayBuffer::New(isolate, byte_length);

    // Copy the data if provided and length > 0
    if (data != nullptr && byte_length > 0) {
        void* dest = buffer->Data();
        if (dest != nullptr) {
            memcpy(dest, data, byte_length);
        }
    }

    return trackHandle(new Global<Value>(isolate, buffer));
}

// ============================================================================
// Map Functions (for structuredClone)
// ============================================================================

// Check if a value is a Map
bool v8_Value_IsMap(Global<Value>* value) {
    if (!value || value->IsEmpty()) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsMap();
}

// Get the size of a Map
size_t v8_Map_GetSize(Global<Value>* value) {
    if (!value || value->IsEmpty()) return 0;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    if (!val->IsMap()) {
        return 0;
    }
    Local<Map> map = val.As<Map>();
    return map->Size();
}

// Get Map entries as an array [key1, value1, key2, value2, ...]
// Returns a Global<Array>* that must be managed by caller
Global<Array>* v8_Map_AsArray(Global<Value>* value) {
    if (!value || value->IsEmpty()) return nullptr;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    if (!val->IsMap()) {
        return nullptr;
    }
    Local<Map> map = val.As<Map>();
    Local<Array> arr = map->AsArray();
    return trackHandle(new Global<Array>(isolate, arr));
}

// Create a new empty Map
Global<Value>* v8_Map_New(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Map> map = Map::New(isolate);
    return trackHandle(new Global<Value>(isolate, map));
}

// Set a key-value pair in a Map
// Returns true on success, false on failure
bool v8_Map_Set(Global<Value>* map_value, Global<Value>* key, Global<Value>* value) {
    if (!map_value || map_value->IsEmpty()) return false;
    if (!key || key->IsEmpty()) return false;
    if (!value || value->IsEmpty()) return false;

    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);

    Local<Context> ctx = isolate->GetCurrentContext();
    if (ctx.IsEmpty()) return false;

    Local<Value> map_val = map_value->Get(isolate);
    if (!map_val->IsMap()) return false;

    Local<Map> map = map_val.As<Map>();
    Local<Value> local_key = key->Get(isolate);
    Local<Value> local_value = value->Get(isolate);

    MaybeLocal<Map> result = map->Set(ctx, local_key, local_value);
    return !result.IsEmpty();
}

// ============================================================================
// Set Functions (for structuredClone)
// ============================================================================

// Check if a value is a Set
bool v8_Value_IsSet(Global<Value>* value) {
    if (!value || value->IsEmpty()) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsSet();
}

// Get the size of a Set
size_t v8_Set_GetSize(Global<Value>* value) {
    if (!value || value->IsEmpty()) return 0;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    if (!val->IsSet()) {
        return 0;
    }
    Local<Set> set = val.As<Set>();
    return set->Size();
}

// Get Set values as an array [value1, value2, ...]
// Returns a Global<Array>* that must be managed by caller
Global<Array>* v8_Set_AsArray(Global<Value>* value) {
    if (!value || value->IsEmpty()) return nullptr;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    if (!val->IsSet()) {
        return nullptr;
    }
    Local<Set> set = val.As<Set>();
    Local<Array> arr = set->AsArray();
    return trackHandle(new Global<Array>(isolate, arr));
}

// Create a new empty Set
Global<Value>* v8_Set_New(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Set> set = Set::New(isolate);
    return trackHandle(new Global<Value>(isolate, set));
}

// Add a value to a Set
// Returns true on success, false on failure
bool v8_Set_Add(Global<Value>* set_value, Global<Value>* value) {
    if (!set_value || set_value->IsEmpty()) return false;
    if (!value || value->IsEmpty()) return false;

    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);

    Local<Context> ctx = isolate->GetCurrentContext();
    if (ctx.IsEmpty()) return false;

    Local<Value> set_val = set_value->Get(isolate);
    if (!set_val->IsSet()) return false;

    Local<Set> set = set_val.As<Set>();
    Local<Value> local_value = value->Get(isolate);

    MaybeLocal<Set> result = set->Add(ctx, local_value);
    return !result.IsEmpty();
}

// ============================================================================
// Structured Clone Functions (using V8 ValueSerializer/ValueDeserializer)
// ============================================================================

// Perform a full structured clone using V8's built-in serialization
// This handles circular references, Date, RegExp, Map, Set, ArrayBuffer, etc.
// Returns a new Global<Value>* that is a deep clone of the input
Global<Value>* v8_Value_StructuredClone(Global<Value>* value) {
    if (!value || value->IsEmpty()) return nullptr;

    Isolate* isolate = Isolate::GetCurrent();
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);

    Local<Context> ctx = isolate->GetCurrentContext();
    if (ctx.IsEmpty()) return nullptr;

    Local<Value> val = value->Get(isolate);

    // Step 1: Serialize the value using V8's ValueSerializer
    ValueSerializer serializer(isolate);
    serializer.WriteHeader();

    Maybe<bool> write_result = serializer.WriteValue(ctx, val);
    if (write_result.IsNothing() || !write_result.FromJust()) {
        // Serialization failed (e.g., contains functions, symbols, etc.)
        return nullptr;
    }

    // Get the serialized data
    std::pair<uint8_t*, size_t> buffer = serializer.Release();
    uint8_t* data = buffer.first;
    size_t size = buffer.second;

    if (data == nullptr || size == 0) {
        return nullptr;
    }

    // Step 2: Deserialize back into a new value using V8's ValueDeserializer
    ValueDeserializer deserializer(isolate, data, size);

    Maybe<bool> header_result = deserializer.ReadHeader(ctx);
    if (header_result.IsNothing() || !header_result.FromJust()) {
        free(data);
        return nullptr;
    }

    MaybeLocal<Value> result = deserializer.ReadValue(ctx);

    // Free the serialized buffer (serializer.Release() uses malloc)
    free(data);

    if (result.IsEmpty()) {
        return nullptr;
    }

    Local<Value> cloned = result.ToLocalChecked();
    return trackHandle(new Global<Value>(isolate, cloned));
}

// Structured Clone with Transfer - performs structured clone with ArrayBuffer transfer
// Per HTML spec StructuredSerializeWithTransfer:
// - Transfers ArrayBuffers from the source to the clone
// - Detaches the original ArrayBuffers after transfer
// - Throws DataCloneError if duplicate ArrayBuffers are in transfer list
//
// Parameters:
// - value: The value to clone
// - transfer_list: Array of Global<Value>* pointing to ArrayBuffers to transfer
// - transfer_count: Number of items in transfer_list
//
// Returns: A new Global<Value>* that is a deep clone with transferred ArrayBuffers,
//          or nullptr on error (duplicate in transfer list, non-ArrayBuffer in list, etc.)
//
// Error handling: Sets *error_code:
//   0 = success
//   1 = DataCloneError (duplicate in transfer list or non-transferable)
//   2 = Other serialization error
Global<Value>* v8_Value_StructuredCloneWithTransfer(
    Global<Value>* value,
    Global<Value>** transfer_list,
    size_t transfer_count,
    int* error_code
) {
    if (error_code) *error_code = 0;

    if (!value || value->IsEmpty()) {
        if (error_code) *error_code = 2;
        return nullptr;
    }

    Isolate* isolate = Isolate::GetCurrent();
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);

    Local<Context> ctx = isolate->GetCurrentContext();
    if (ctx.IsEmpty()) {
        if (error_code) *error_code = 2;
        return nullptr;
    }

    Local<Value> val = value->Get(isolate);

    // Check for duplicates in transfer list using pointer comparison
    // Per HTML spec step 2.3: If memory[transferable] exists, throw "DataCloneError"
    std::set<void*> seen_buffers;
    std::vector<Local<ArrayBuffer>> array_buffers_to_transfer;

    for (size_t i = 0; i < transfer_count; i++) {
        if (!transfer_list[i] || transfer_list[i]->IsEmpty()) {
            if (error_code) *error_code = 1;  // DataCloneError
            return nullptr;
        }

        Local<Value> transfer_val = transfer_list[i]->Get(isolate);

        if (!transfer_val->IsArrayBuffer()) {
            // Only ArrayBuffer can be transferred (SharedArrayBuffer uses different mechanism)
            if (error_code) *error_code = 1;  // DataCloneError
            return nullptr;
        }

        Local<ArrayBuffer> ab = transfer_val.As<ArrayBuffer>();

        // Get the backing store pointer for duplicate detection
        std::shared_ptr<BackingStore> backing_store = ab->GetBackingStore();
        void* data_ptr = backing_store ? backing_store->Data() : nullptr;

        // Check for duplicate - same backing store pointer means same buffer
        if (seen_buffers.find(data_ptr) != seen_buffers.end()) {
            // Duplicate found - per spec, throw DataCloneError
            if (error_code) *error_code = 1;  // DataCloneError
            return nullptr;
        }
        seen_buffers.insert(data_ptr);

        // Also check if buffer is already detached
        if (ab->WasDetached()) {
            if (error_code) *error_code = 1;  // DataCloneError
            return nullptr;
        }

        // A buffer that cannot be detached (a WebAssembly.Memory's): a
        // TypeError (ECMAScript DetachArrayBuffer) before anything is detached;
        // V8's Detach on one is a fatal CHECK. Code 3: the TypeError is pending.
        if (!ab->IsDetachable()) {
            isolate->ThrowException(Exception::TypeError(
                String::NewFromUtf8Literal(isolate, "An ArrayBuffer in the transfer list cannot be detached")));
            if (error_code) *error_code = 3;
            return nullptr;
        }

        array_buffers_to_transfer.push_back(ab);
    }

    // Step 1: Serialize the value using V8's ValueSerializer
    ValueSerializer serializer(isolate);
    serializer.WriteHeader();

    // Register ArrayBuffers for transfer BEFORE writing the value
    // This tells V8 to replace these ArrayBuffers with transfer IDs during serialization
    for (size_t i = 0; i < array_buffers_to_transfer.size(); i++) {
        serializer.TransferArrayBuffer(static_cast<uint32_t>(i), array_buffers_to_transfer[i]);
    }

    Maybe<bool> write_result = serializer.WriteValue(ctx, val);
    if (write_result.IsNothing() || !write_result.FromJust()) {
        // Serialization failed
        if (error_code) *error_code = 2;
        return nullptr;
    }

    // Get the serialized data
    std::pair<uint8_t*, size_t> buffer = serializer.Release();
    uint8_t* data = buffer.first;
    size_t size = buffer.second;

    if (data == nullptr || size == 0) {
        if (error_code) *error_code = 2;
        return nullptr;
    }

    // Step 2: Deserialize back into a new value
    ValueDeserializer deserializer(isolate, data, size);

    // Register the same ArrayBuffers for transfer on the deserializer side
    // V8 will use these as the targets for the transferred data
    for (size_t i = 0; i < array_buffers_to_transfer.size(); i++) {
        // Create a new ArrayBuffer to receive the transferred data
        // V8 will copy the data during deserialization
        Local<ArrayBuffer> source = array_buffers_to_transfer[i];
        std::shared_ptr<BackingStore> source_backing = source->GetBackingStore();
        size_t byte_length = source_backing ? source_backing->ByteLength() : 0;

        // Create new backing store with copied data
        Local<ArrayBuffer> target = ArrayBuffer::New(isolate, byte_length);
        if (byte_length > 0 && source_backing && target->GetBackingStore()) {
            memcpy(target->GetBackingStore()->Data(), source_backing->Data(), byte_length);
        }

        deserializer.TransferArrayBuffer(static_cast<uint32_t>(i), target);
    }

    Maybe<bool> header_result = deserializer.ReadHeader(ctx);
    if (header_result.IsNothing() || !header_result.FromJust()) {
        free(data);
        if (error_code) *error_code = 2;
        return nullptr;
    }

    MaybeLocal<Value> result = deserializer.ReadValue(ctx);

    // Free the serialized buffer
    free(data);

    if (result.IsEmpty()) {
        if (error_code) *error_code = 2;
        return nullptr;
    }

    // Detach the original ArrayBuffers after successful clone
    // Per HTML spec step 5.4.3: Perform DetachArrayBuffer(transferable)
    for (auto& ab : array_buffers_to_transfer) {
        ab->Detach(Local<Value>());
    }

    Local<Value> cloned = result.ToLocalChecked();
    return trackHandle(new Global<Value>(isolate, cloned));
}

// ============================================================================
// Object Functions
// ============================================================================

Global<Object>* v8_Object_New(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Object> obj = Object::New(isolate);
    return trackHandle(new Global<Object>(isolate, obj));
}

Global<Object>* v8_Object_NewWithNullPrototype(Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);
    
    // Create an object with null prototype using Object.create(null)
    Local<Object> obj = Object::New(isolate, v8::Null(isolate), nullptr, nullptr, 0);
    return trackHandle(new Global<Object>(isolate, obj));
}

// Create a plain object {} in a specific context (for cross-realm support).
// The object's prototype will be the target context's Object.prototype,
// which is essential for correct cross-realm toJSON behavior per WebIDL spec.
Global<Object>* v8_Object_NewInContext(Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    // Enter the target context to ensure the object is created
    // with that context's Object.prototype
    Context::Scope context_scope(ctx);
    
    Local<Object> obj = Object::New(isolate);
    return trackHandle(new Global<Object>(isolate, obj));
}

// Create an array [] in a specific context (for cross-realm support).
// The array's prototype will be the target context's Array.prototype.
Global<Array>* v8_Array_NewInContext(Global<Context>* context, int length) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    // Enter the target context to ensure the array is created
    // with that context's Array.prototype
    Context::Scope context_scope(ctx);
    
    Local<Array> arr = Array::New(isolate, length);
    return trackHandle(new Global<Array>(isolate, arr));
}

bool v8_Object_Set(Global<Object>* object, Global<Context>* context, Global<Value>* key, Global<Value>* value) {
    CHECK_ALIGNMENT_LOG(object, Global<Object>, "v8_Object_Set");
    CHECK_ALIGNMENT_LOG(context, Global<Context>, "v8_Object_Set");
    CHECK_ALIGNMENT_LOG(key, Global<Value>, "v8_Object_Set");
    CHECK_ALIGNMENT_LOG(value, Global<Value>, "v8_Object_Set");

    Isolate* isolate = Isolate::GetCurrent();
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);

    Local<Context> ctx = context->Get(isolate);
    Local<Object> obj = object->Get(isolate);
    Local<Value> k = key->Get(isolate);
    Local<Value> v = value->Get(isolate);

    Maybe<bool> result = obj->Set(ctx, k, v);
    return result.FromMaybe(false);
}

bool v8_Object_Delete(Global<Object>* object, Global<Context>* context, Global<Value>* key) {
    Isolate* isolate = Isolate::GetCurrent();
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Object> obj = object->Get(isolate);
    Local<Value> k = key->Get(isolate);
    
    Maybe<bool> result = obj->Delete(ctx, k);
    return result.FromMaybe(false);
}

bool v8_Object_CreateDataProperty(Global<Object>* object, Global<Context>* context, Global<String>* key, Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Object> obj = object->Get(isolate);
    Local<String> k = key->Get(isolate);
    Local<Value> v = value->Get(isolate);
    
    // Use DefineOwnProperty with explicit attributes to ensure we create an own property
    // that shadows any prototype accessor
    PropertyDescriptor desc(v, true); // writable = true
    desc.set_enumerable(true);
    desc.set_configurable(true);
    
    Maybe<bool> result = obj->DefineOwnProperty(ctx, k, v, static_cast<PropertyAttribute>(None));
    return result.FromMaybe(false);
}

Global<Value>* v8_Object_Get(Global<Object>* object, Global<Context>* context, Global<Value>* key) {
    CHECK_ALIGNMENT_LOG(object, Global<Object>, "v8_Object_Get");
    CHECK_ALIGNMENT_LOG(context, Global<Context>, "v8_Object_Get");
    CHECK_ALIGNMENT_LOG(key, Global<Value>, "v8_Object_Get");

    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);

    Local<Context> ctx = context->Get(isolate);
    Local<Object> obj = object->Get(isolate);
    Local<Value> k = key->Get(isolate);

    MaybeLocal<Value> maybe_val = obj->Get(ctx, k);
    if (maybe_val.IsEmpty()) {
        return nullptr;
    }

    Local<Value> val = maybe_val.ToLocalChecked();
    return trackHandle(new Global<Value>(isolate, val));
}

// Check if an object has an own property (not inherited)
bool v8_Object_HasOwnProperty(Global<Object>* object, Global<Context>* context, Global<Value>* key) {
    Isolate* isolate = Isolate::GetCurrent();
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Object> obj = object->Get(isolate);
    Local<Value> k = key->Get(isolate);
    
    // HasOwnProperty takes a Name (String or Symbol), not a generic Value
    if (!k->IsName()) {
        return false;
    }
    
    Maybe<bool> result = obj->HasOwnProperty(ctx, k.As<Name>());
    return result.FromMaybe(false);
}

// Get the own property descriptor for a property
// Returns an object with value, writable, enumerable, configurable, get, set
// or nullptr if the property doesn't exist as an own property
Global<Value>* v8_Object_GetOwnPropertyDescriptor(Global<Object>* object, Global<Context>* context, Global<Value>* key) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Object> obj = object->Get(isolate);
    Local<Value> k = key->Get(isolate);
    
    // GetOwnPropertyDescriptor takes a Name (String or Symbol)
    if (!k->IsName()) {
        return nullptr;
    }
    
    MaybeLocal<Value> maybe_desc = obj->GetOwnPropertyDescriptor(ctx, k.As<Name>());
    if (maybe_desc.IsEmpty()) {
        return nullptr;
    }
    
    Local<Value> desc = maybe_desc.ToLocalChecked();
    // If the property doesn't exist, GetOwnPropertyDescriptor returns undefined
    if (desc->IsUndefined()) {
        return nullptr;
    }
    
    return trackHandle(new Global<Value>(isolate, desc));
}

Global<Array>* v8_Object_GetOwnPropertyNames(Global<Context>* context, Global<Object>* obj) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<Object> local_obj = obj->Get(isolate);
    
    MaybeLocal<Array> maybe_names = local_obj->GetOwnPropertyNames(local_context);
    if (maybe_names.IsEmpty()) {
        return nullptr;
    }
    
    Local<Array> names = maybe_names.ToLocalChecked();
    return trackHandle(new Global<Array>(isolate, names));
}

// Get own property names with numeric indices converted to strings
// Required for Proxy ownKeys trap which must return only strings/symbols
Global<Array>* v8_Object_GetOwnPropertyNamesAsStrings(Global<Context>* context, Global<Object>* obj) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<Object> local_obj = obj->Get(isolate);
    
    // Use GetOwnPropertyNames with kConvertToString to ensure all keys are strings
    // PropertyFilter::ALL_PROPERTIES (value 0) includes both enumerable and non-enumerable
    MaybeLocal<Array> maybe_names = local_obj->GetOwnPropertyNames(
        local_context,
        PropertyFilter::ALL_PROPERTIES,
        KeyConversionMode::kConvertToString
    );
    if (maybe_names.IsEmpty()) {
        return nullptr;
    }
    
    Local<Array> names = maybe_names.ToLocalChecked();
    return trackHandle(new Global<Array>(isolate, names));
}

// Get all property names including prototype chain and non-enumerable
Global<Array>* v8_Object_GetPropertyNames(Global<Context>* context, Global<Object>* obj) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<Object> local_obj = obj->Get(isolate);
    
    // Include all properties from prototype chain, including non-enumerable ones
    MaybeLocal<Array> maybe_names = local_obj->GetPropertyNames(
        local_context,
        KeyCollectionMode::kIncludePrototypes,
        static_cast<PropertyFilter>(PropertyFilter::ALL_PROPERTIES | PropertyFilter::SKIP_SYMBOLS),
        IndexFilter::kIncludeIndices,
        KeyConversionMode::kConvertToString
    );
    if (maybe_names.IsEmpty()) {
        return nullptr;
    }
    
    Local<Array> names = maybe_names.ToLocalChecked();
    return trackHandle(new Global<Array>(isolate, names));
}

// Get own property symbols (for Object.getOwnPropertySymbols)
Global<Array>* v8_Object_GetOwnPropertySymbols(Global<Context>* context, Global<Object>* obj) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<Object> local_obj = obj->Get(isolate);
    
    // Get only symbol properties, own only
    MaybeLocal<Array> maybe_names = local_obj->GetOwnPropertyNames(
        local_context,
        static_cast<PropertyFilter>(PropertyFilter::ALL_PROPERTIES | PropertyFilter::SKIP_STRINGS),
        KeyConversionMode::kKeepNumbers  // Doesn't matter for symbols
    );
    if (maybe_names.IsEmpty()) {
        return nullptr;
    }
    
    Local<Array> names = maybe_names.ToLocalChecked();
    return trackHandle(new Global<Array>(isolate, names));
}

void v8_Object_SetAlignedPointerInInternalField(Global<Object>* obj, int index, void* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Object> local_obj = obj->Get(isolate);
    
    // Defensive check: verify object has enough internal fields
    int field_count = local_obj->InternalFieldCount();
    if (index >= field_count) {
        fprintf(stderr, "FATAL: SetAlignedPointerInInternalField index %d out of bounds (object has %d internal fields)\n", 
                index, field_count);
        fprintf(stderr, "  This usually means:\n");
        fprintf(stderr, "  1. Object was not created from a template with SetInternalFieldCount(1)\n");
        fprintf(stderr, "  2. Object is the global object (has 0 internal fields by default)\n");
        fprintf(stderr, "  3. Object is from a different isolate/context\n");
        
        // Print backtrace to identify caller
        fprintf(stderr, "\nBacktrace:\n");
        void* callstack[128];
        int frames = backtrace(callstack, 128);
        char** symbols = backtrace_symbols(callstack, frames);
        if (symbols) {
            for (int i = 0; i < frames; i++) {
                fprintf(stderr, "  %s\n", symbols[i]);
            }
            free(symbols);
        }
        fprintf(stderr, "\n");
        // Don't crash here - let V8's internal check provide the crash location
        // but we've logged useful debug info
    }
    
    local_obj->SetAlignedPointerInInternalField(index, value, kCraneEmbedderDataTag);
}

int v8_Object_InternalFieldCount(Global<Object>* obj) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Object> local_obj = obj->Get(isolate);
    // A legacy platform object's proxy has no fields; its target does, and
    // v8_Object_GetAlignedPointerFromInternalField reads them through it.
    if (local_obj->IsProxy()) {
        Local<Value> target = local_obj.As<Proxy>()->GetTarget();
        if (target->IsObject()) local_obj = target.As<Object>();
    }
    return local_obj->InternalFieldCount();
}

void* v8_Object_GetAlignedPointerFromInternalField(Global<Object>* obj, int index) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Object> local_obj = obj->Get(isolate);

    // CROSS-REALM FIX: If object is a Proxy, unwrap to get the target.
    // Proxies (used for legacy platform objects like CSSStyleDeclaration)
    // have no internal fields - the internal fields are on the target object.
    if (local_obj->IsProxy()) {
        Local<Proxy> proxy = local_obj.As<Proxy>();
        Local<Value> target = proxy->GetTarget();
        if (target->IsObject()) {
            local_obj = target.As<Object>();
        }
    }

    // An object with no such field has no pointer there. Only a realm's
    // global keeps one (field 0, its instance): a platform object's instance
    // is read through its anchor (v8_Object_Instance).
    if (local_obj->InternalFieldCount() <= index) return nullptr;

    void* result = local_obj->GetAlignedPointerFromInternalField(index, kCraneEmbedderDataTag);
    return result;
}

/// Record a strong edge from `holder` to `value` that script cannot see: a
/// private property keyed `key`. The garbage collector then keeps `value`
/// alive exactly as long as `holder` - the edge Blink draws by TRACING a
/// [SameObject] child from its owner (Node::Trace visits node_lists_).
/// Setting it again replaces the edge.
///
/// Both handles are read into Locals before anything here allocates: either
/// may be a wrapper the wrapper cache holds only weakly - the [SameObject]
/// child `recordSameObjectEdge` wrapped a moment ago, which nothing reaches
/// until this edge exists - and a collection started by the key's string or
/// its Private would take it and empty the handle under us - the window
/// template_registry's cache-hit prototype reset had (docs/lessons/
/// architecture-a-weakly-held-wrapper-dies-at-the-next-allocation.md).
void v8_Object_SetPrivateRef(Global<Object>* holder, const char* key, int key_len, Global<Value>* value) {
    if (!holder || !value) return;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Object> object = holder->Get(isolate);
    Local<Value> target = value->Get(isolate);
    if (object.IsEmpty() || target.IsEmpty()) return;
    Local<Context> context = isolate->GetCurrentContext();
    if (context.IsEmpty()) return;
    Local<String> name;
    if (!String::NewFromUtf8(isolate, key, NewStringType::kInternalized, key_len).ToLocal(&name)) return;
    Local<Private> priv = Private::ForApi(isolate, name);
    (void)object->SetPrivate(context, priv, target);
}

void v8_Object_Dispose(Global<Object>* obj) {
    if (!obj) return;
    // See v8_ObjectTemplate_Dispose: while the snapshot is being built every
    // handle is registered for bulk cleanup, so disposing one here as well is a
    // double free.
    if (g_snapshot_mode) return;
    forgetCountedHandle(obj);
    releaseWeakArm(obj);
    obj->Reset();
    delete obj;
}

// ============================================================================
// Array Functions
// ============================================================================

Global<Array>* v8_Array_New(Isolate* isolate, int length) {
    HandleScope handle_scope(isolate);
    Local<Array> arr = Array::New(isolate, length);
    return trackHandle(new Global<Array>(isolate, arr));
}

uint32_t v8_Array_Length(Global<Array>* arr) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Array> local_arr = arr->Get(isolate);
    return local_arr->Length();
}

Global<Value>* v8_Array_Get(Global<Context>* context, Global<Array>* arr, uint32_t index) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<Array> local_arr = arr->Get(isolate);
    
    MaybeLocal<Value> maybe_value = local_arr->Get(local_context, index);
    if (maybe_value.IsEmpty()) {
        return nullptr;
    }
    
    Local<Value> value = maybe_value.ToLocalChecked();
    return trackHandle(new Global<Value>(isolate, value));
}

/// Define element `index` of an Array the engine is building: ECMAScript
/// CreateDataProperty(A, index, value), as WebIDL's sequence-to-ECMAScript
/// conversion (3.2.28) and every list the adapter hands script ask - never a
/// [[Set]], which on a hole walks the prototype chain and runs a setter
/// script put on Array.prototype (IndexedDB/bindings-inject-keys-bypass).
/// Every caller fills an array it made itself (lane binding, 2026-10-04).
bool v8_Array_Set(Global<Array>* arr, Global<Context>* context, uint32_t index, Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);

    Local<Context> local_context = context->Get(isolate);
    Local<Array> local_arr = arr->Get(isolate);
    Local<Value> local_value = value->Get(isolate);

    Maybe<bool> result = local_arr->CreateDataProperty(local_context, index, local_value);
    return result.FromMaybe(false);
}

/// Object.freeze(object): SetIntegrityLevel(kFrozen). False if it could not be
/// frozen - a proxy trap can refuse, and can throw.
bool v8_Object_Freeze(Global<Object>* object, Global<Context>* context) {
    if (!object || !context) return false;
    Isolate* isolate = Isolate::GetCurrent();
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);
    Local<Context> local_context = context->Get(isolate);
    Local<Object> local_object = object->Get(isolate);
    return local_object->SetIntegrityLevel(local_context, IntegrityLevel::kFrozen).FromMaybe(false);
}

void v8_Array_Dispose(Global<Array>* arr) {
    // Snapshot mode: trackHandle queued this handle for bulk cleanup (see
    // v8_ObjectTemplate_Dispose), so deleting it here too is a double free.
    if (g_snapshot_mode) return;
    if (arr) {
        forgetCountedHandle(arr);
        releaseWeakArm(arr);
        arr->Reset();
        delete arr;
    }
}

// ============================================================================
// Script Functions
// ============================================================================

Global<Script>* v8_Script_Compile(Global<Context>* context, Global<String>* source) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Context::Scope context_scope(local_context);  // Ensure context is entered for compilation
    Local<String> local_source = source->Get(isolate);
    
    MaybeLocal<Script> maybe_script = Script::Compile(local_context, local_source);
    if (maybe_script.IsEmpty()) {
        return nullptr;
    }
    
    Local<Script> script = maybe_script.ToLocalChecked();
    return trackHandle(new Global<Script>(isolate, script));
}

/// Compile a script with a source URL (for error messages and source maps)
Global<Script>* v8_Script_CompileWithOrigin(Global<Context>* context, Global<String>* source, Global<String>* resource_name) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Context::Scope context_scope(local_context);  // Ensure context is entered for compilation
    Local<String> local_source = source->Get(isolate);
    Local<String> local_resource_name = resource_name->Get(isolate);
    
    // Create ScriptOrigin with the resource name (URL)
    // ScriptOrigin takes Local<Value> as first arg, not Isolate
    ScriptOrigin origin(local_resource_name);
    
    MaybeLocal<Script> maybe_script = Script::Compile(local_context, local_source, &origin);
    if (maybe_script.IsEmpty()) {
        return nullptr;
    }
    
    Local<Script> script = maybe_script.ToLocalChecked();
    return trackHandle(new Global<Script>(isolate, script));
}

Global<Value>* v8_Script_Run(Global<Context>* context, Global<Script>* script) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Context::Scope context_scope(local_context);  // Ensure context is entered for global resolution
    Local<Script> local_script = script->Get(isolate);
    
    MaybeLocal<Value> maybe_result = local_script->Run(local_context);
    if (maybe_result.IsEmpty()) {
        return nullptr;
    }
    
    Local<Value> result = maybe_result.ToLocalChecked();
    return trackHandle(new Global<Value>(isolate, result));
}

void v8_Script_Dispose(Global<Script>* script) {
    // Snapshot mode: trackHandle queued this handle for bulk cleanup (see
    // v8_ObjectTemplate_Dispose), so deleting it here too is a double free.
    if (g_snapshot_mode) return;
    if (script) {
        releaseWeakArm(script);
        script->Reset();
        delete script;
    }
}

// ============================================================================
// Module Functions (ES Modules support)
// ============================================================================

/// The value of the "type" entry in an import-attributes FixedArray, as a new[]
/// string the caller delete[]s, or nullptr when there is none. `stride` is 3 for
/// arrays that carry source positions (ModuleRequest::GetImportAttributes and
/// the resolve callback) and 2 for those that do not (dynamic import).
/// `has_unsupported_key` is set when any key other than "type" appears: the host
/// must reject those (HTML's HostLoadImportedModule step 7.1.1 throws a
/// SyntaxError) rather than ignore them.
static char* importTypeAttribute(Isolate* isolate, Local<Context> context, Local<FixedArray> attributes, int stride, bool* has_unsupported_key) {
    if (has_unsupported_key) *has_unsupported_key = false;
    if (attributes.IsEmpty()) return nullptr;
    char* type = nullptr;
    for (int i = 0; i + 1 < attributes->Length(); i += stride) {
        Local<Data> key_data = attributes->Get(i);
        Local<Data> value_data = attributes->Get(i + 1);
        if (key_data.IsEmpty() || !key_data->IsValue() || value_data.IsEmpty() || !value_data->IsValue()) continue;
        String::Utf8Value key(isolate, key_data.As<Value>());
        if (*key && strcmp(*key, "type") == 0) {
            String::Utf8Value value(isolate, value_data.As<Value>());
            int len = value.length();
            delete[] type;
            type = new char[len + 1];
            memcpy(type, *value ? *value : "", len);
            type[len] = '\0';
        } else if (has_unsupported_key) {
            *has_unsupported_key = true;
        }
    }
    return type;
}


/// Report an unresolvable module specifier as a JavaScript exception.
///
/// v8::Module::ResolveModuleCallback carries a hard contract: an empty
/// MaybeLocal means "I have already scheduled an exception". Returning empty
/// without one does not fail the instantiation - it trips a CHECK inside
/// v8::internal::Module::ResolveExport and takes the whole process down with
/// SIGTRAP. That is not a hypothetical: every `import` this engine could not
/// resolve crashed the runner, which is why the entire error half of
/// html/semantics/scripting-1/the-script-element/module/ (compilation-error-*,
/// choice-of-error-*, instantiation-error-*, fetch-error-*) crashed rather than
/// failing.
///
/// A TypeError is what the HTML spec's "resolve a module specifier" produces on
/// failure, so the exception is also the right one.
static void throwUnresolvedModuleSpecifier(Isolate* isolate, Local<String> specifier) {
    // Never clobber an exception the callee already scheduled: that one names
    // the real cause, and V8 only requires that *some* exception is pending.
    if (isolate->HasPendingException()) {
        return;
    }

    String::Utf8Value specifier_utf8(isolate, specifier);
    const char* name = *specifier_utf8 ? *specifier_utf8 : "";

    char buf[512];
    snprintf(buf, sizeof(buf), "Failed to resolve module specifier \"%s\"", name);

    Local<String> message;
    if (!String::NewFromUtf8(isolate, buf).ToLocal(&message)) {
        // Even the message could not be built; anything pending is enough.
        if (!isolate->HasPendingException()) {
            isolate->ThrowException(Exception::TypeError(String::Empty(isolate)));
        }
        return;
    }
    isolate->ThrowException(Exception::TypeError(message));
}

/// Compile source code as an ES Module
/// Returns nullptr on compilation error
Global<Module>* v8_Module_Compile(
    Global<Context>* context,
    Global<String>* source,
    Global<String>* resource_name
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);

    Local<Context> local_context = context->Get(isolate);
    Local<String> local_source = source->Get(isolate);
    Local<String> local_name = resource_name ? resource_name->Get(isolate) : String::Empty(isolate);

    // Enter the context for module compilation
    // This ensures the module is compiled in the right realm
    Context::Scope context_scope(local_context);

    // Create ScriptOrigin for module (is_module = true)
    ScriptOrigin origin(
        local_name,        // resource name
        0,                 // line offset
        0,                 // column offset
        false,             // is_shared_cross_origin
        -1,                // script id
        Local<Value>(),    // source_map_url
        false,             // is_opaque
        false,             // is_wasm
        true               // is_module
    );

    // Create ScriptCompiler::Source
    ScriptCompiler::Source script_source(local_source, origin);

    // A syntax error leaves an exception scheduled on the isolate, and this
    // signature can only say "nullptr". Without a TryCatch to absorb it, the
    // exception survives the return and the NEXT unrelated V8 call CHECKs -
    // the failure lands nowhere near the module that caused it. The TryCatch's
    // destructor clears it, which is exactly what "returns nullptr on
    // compilation error" already promised.
    TryCatch try_catch(isolate);

    // Compile the module
    MaybeLocal<Module> maybe_module = ScriptCompiler::CompileModule(isolate, &script_source);

    if (maybe_module.IsEmpty()) {
        return nullptr;
    }

    Local<Module> module = maybe_module.ToLocalChecked();
    return trackHandle(new Global<Module>(isolate, module));
}

/// Get the number of module requests (imports) in a module
int v8_Module_GetModuleRequestsLength(Global<Module>* module) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Module> local_module = module->Get(isolate);
    Local<FixedArray> requests = local_module->GetModuleRequests();
    return requests->Length();
}

/// Get the module specifier (import path) at the given index
/// Caller must free the returned string with v8_FreeString
char* v8_Module_GetModuleRequest(Global<Module>* module, int index) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Module> local_module = module->Get(isolate);
    Local<FixedArray> requests = local_module->GetModuleRequests();
    
    if (index < 0 || index >= requests->Length()) {
        return nullptr;
    }
    
    // FixedArray::Get returns Local<Data>, cast to ModuleRequest
    Local<Data> data = requests->Get(index);
    Local<ModuleRequest> request = data.As<ModuleRequest>();
    Local<String> specifier = request->GetSpecifier();
    
    String::Utf8Value utf8(isolate, specifier);
    int len = utf8.length();
    char* result = new char[len + 1];
    memcpy(result, *utf8, len);
    result[len] = '\0';
    
    return result;
}

/// Free a string allocated by v8_Module_GetModuleRequest
void v8_FreeString(char* str) {
    if (str) {
        delete[] str;
    }
}

/// Get the module's status (0=Uninstantiated, 1=Instantiating, 2=Instantiated, 3=Evaluating, 4=Evaluated, 5=Errored)
int v8_Module_GetStatus(Global<Module>* module) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Module> local_module = module->Get(isolate);
    return static_cast<int>(local_module->GetStatus());
}

/// Evaluate the module (execute the top-level code)
/// Returns the result value or nullptr on error
Global<Value>* v8_Module_Evaluate(Global<Context>* context, Global<Module>* module) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);

    Local<Context> local_context = context->Get(isolate);
    Local<Module> local_module = module->Get(isolate);

    // Enter the context for module evaluation
    // This is critical for globalThis to reference the correct global object
    Context::Scope context_scope(local_context);

    // See v8_Module_Compile. Evaluating a module whose graph is errored, or one
    // that throws at top level, schedules an exception this nullptr return
    // cannot carry.
    TryCatch try_catch(isolate);

    // v8::Module::Evaluate CHECKs that the module is instantiated or already
    // evaluated. A caller that ignored a failed InstantiateModule and evaluated
    // anyway would take the process down rather than get a null back.
    if (local_module->GetStatus() < Module::kInstantiated) {
        return nullptr;
    }

    MaybeLocal<Value> maybe_result = local_module->Evaluate(local_context);

    if (maybe_result.IsEmpty()) {
        return nullptr;
    }

    Local<Value> result = maybe_result.ToLocalChecked();
    return trackHandle(new Global<Value>(isolate, result));
}

/// Get the module's exception (if status is Errored)
Global<Value>* v8_Module_GetException(Global<Module>* module) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Module> local_module = module->Get(isolate);
    
    if (local_module->GetStatus() != Module::kErrored) {
        return nullptr;
    }
    
    Local<Value> exception = local_module->GetException();
    return trackHandle(new Global<Value>(isolate, exception));
}

/// Get the module's namespace object (exports)
Global<Object>* v8_Module_GetModuleNamespace(Global<Module>* module) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);

    Local<Module> local_module = module->Get(isolate);

    // Same contract as IsGraphAsync above: v8::Module::GetModuleNamespace
    // CHECKs that the module is at least instantiated, and the caller here is
    // the dynamic-import path, which reaches for the namespace on whatever it
    // was handed - including a module whose instantiation failed.
    if (local_module->GetStatus() < Module::kInstantiated) {
        return nullptr;
    }

    Local<Value> ns = local_module->GetModuleNamespace();

    if (!ns->IsObject()) {
        return nullptr;
    }

    return trackHandle(new Global<Object>(isolate, ns.As<Object>()));
}

/// Get the module's identity hash (for use as map key)
int v8_Module_GetIdentityHash(Global<Module>* module) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Module> local_module = module->Get(isolate);
    return local_module->GetIdentityHash();
}

/// Dispose a module handle
void v8_Module_Dispose(Global<Module>* module) {
    // Snapshot mode: trackHandle queued this handle for bulk cleanup (see
    // v8_ObjectTemplate_Dispose), so deleting it here too is a double free.
    if (g_snapshot_mode) return;
    if (module) {
        // A JSON module disposed before it was ever evaluated still holds its
        // parsed value in the synthetic-export table; drop it with the module.
        if (!module->IsEmpty()) {
            Isolate* isolate = Isolate::GetCurrent();
            if (IsolateData* data = isolateData(isolate)) {
                HandleScope handle_scope(isolate);
                Local<Module> local = module->Get(isolate);
                if (SyntheticJsonExport* entry = data->takeSyntheticExport(local)) deleteSyntheticExport(entry);
            }
        }
        releaseWeakArm(module);
        module->Reset();
        delete module;
    }
}

/// Check if a module or any of its dependencies has top-level await
/// 
/// Per TC39 TLA spec, this returns true if the module graph contains
/// any async module (i.e., module with top-level await).
/// Must be called after module instantiation.
/// 
/// @param module - Compiled and instantiated module handle
/// @return true if the module or any dependency has TLA
bool v8_Module_IsGraphAsync(Global<Module>* module) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);

    Local<Module> local_module = module->Get(isolate);

    // "Must be called after module instantiation" is not advice - it is a
    // v8::Module CHECK, and a failed CHECK is IMMEDIATE_CRASH():
    //
    //     # Fatal error in v8::Module::IsGraphAsync
    //     # v8::Module::IsGraphAsync must be used on an instantiated module
    //
    // `script_execution.runModuleFromSource` asks this straight after
    // compiling, before anything instantiates, so EVERY module script took the
    // process down with SIGTRAP - including inline ones with no imports at all,
    // which is what made it look like an import-resolution problem.
    //
    // An uninstantiated graph has no answer to give, and "false" is the safe
    // one: the caller then evaluates synchronously, and Evaluate() on a module
    // that does have top-level await returns a promise regardless.
    if (local_module->GetStatus() < Module::kInstantiated) {
        return false;
    }

    // V8's IsGraphAsync() checks if this module or any of its dependencies
    // contain top-level await, requiring async evaluation
    return local_module->IsGraphAsync();
}

/// The "type" import attribute of the module request at `index`, as a new[]
/// string freed with v8_FreeString, or nullptr when the request has none.
///
/// `*status` is 0 for no type, 1 for a type (returned), -1 for a request that
/// also names an attribute other than "type" - which the host must reject with
/// a SyntaxError (HTML HostLoadImportedModule step 7.1.1) - and -2 for an index
/// out of range.
char* v8_Module_GetModuleRequestType(Global<Module>* module, int index, int* status) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    *status = 0;

    Local<Module> local_module = module->Get(isolate);
    Local<FixedArray> requests = local_module->GetModuleRequests();
    if (index < 0 || index >= requests->Length()) {
        *status = -2;
        return nullptr;
    }

    Local<Context> context = isolate->GetCurrentContext();
    Local<ModuleRequest> request = requests->Get(index).As<ModuleRequest>();
    bool has_unsupported_key = false;
    char* type = importTypeAttribute(isolate, context, request->GetImportAttributes(), 3, &has_unsupported_key);
    if (has_unsupported_key) {
        delete[] type;
        *status = -1;
        return nullptr;
    }
    if (type) *status = 1;
    return type;
}

// ============================================================================
// Event handler content attributes
// ============================================================================

// ============================================================================
// JSON module scripts (synthetic modules)
// ============================================================================
//
// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#creating-a-json-module-script
// A JSON module script's record is a Synthetic Module Record whose single
// "default" export is the parsed value. V8 runs the evaluation steps below on
// Evaluate(); they look the parsed value up by module, set the export, and
// resolve. The value lives in this table from creation until evaluation (or
// until the module is disposed unevaluated). Same design as d8's
// json_module_to_parsed_json_map.

// V8 >= 15.7: the evaluation steps answer the evaluation's promise
// (Module::SyntheticModuleEvaluationSteps); the Value-returning form is
// LegacySyntheticModuleEvaluationSteps, deprecated.
static MaybeLocal<Promise> JsonModuleEvaluationSteps(Local<Context> context, Local<Module> module) {
    Isolate* isolate = Isolate::GetCurrent();  // V8 >= 14: no Context::GetIsolate (98282b9b8fa); a callback runs on its isolate

    Local<Value> value;
    bool found = false;
    IsolateData* data = isolateData(isolate);
    if (SyntheticJsonExport* entry = data ? data->takeSyntheticExport(module) : nullptr) {
        value = entry->value.Get(isolate);
        deleteSyntheticExport(entry);
        found = true;
    }

    // Returning empty promises V8 an exception is pending (the contract of
    // SyntheticModuleEvaluationSteps), so the failure path must throw.
    if (!found) {
        isolate->ThrowException(Exception::TypeError(
            String::NewFromUtf8Literal(isolate, "JSON module has no parsed value")));
        return MaybeLocal<Promise>();
    }

    Local<String> default_name = String::NewFromUtf8Literal(isolate, "default", NewStringType::kInternalized);
    if (module->SetSyntheticModuleExport(isolate, default_name, value).IsNothing()) {
        return MaybeLocal<Promise>();
    }

    Local<Promise::Resolver> resolver;
    if (!Promise::Resolver::New(context).ToLocal(&resolver)) return MaybeLocal<Promise>();
    if (resolver->Resolve(context, Undefined(isolate)).IsNothing()) return MaybeLocal<Promise>();
    return resolver->GetPromise();
}

/// Create a JSON module script's record from its source text.
///
/// Spec: "create a JSON module script" steps 3-6 - parse the text as JSON; on
/// failure the script's parse error is the thrown SyntaxError and its record is
/// null; on success the record is a synthetic module exporting the value as
/// "default".
///
/// Returns the module (Global<Module>*, caller owns - v8_Module_Dispose), or
/// nullptr with `*out_error` set (free with v8_FreeErrorInfo; its `exception`
/// is the SyntaxError).
Global<Module>* v8_Module_CreateJsonModule(
    Global<Context>* context,
    const char* source,
    int source_len,
    const char* name,
    int name_len,
    V8ErrorInfo** out_error
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    *out_error = nullptr;

    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);
    TryCatch try_catch(isolate);

    Local<String> text;
    Local<Value> parsed;
    if (!String::NewFromUtf8(isolate, source, NewStringType::kNormal, source_len).ToLocal(&text) ||
        !JSON::Parse(ctx, text).ToLocal(&parsed)) {
        if (try_catch.HasCaught()) {
            *out_error = extractException(isolate, &try_catch);
        } else {
            *out_error = new V8ErrorInfo();
            (*out_error)->has_error = true;
            (*out_error)->message = strdup("JSON module could not be parsed");
            (*out_error)->line_number = -1;
            (*out_error)->column_number = -1;
        }
        return nullptr;
    }

    Local<String> module_name;
    if (!String::NewFromUtf8(isolate, name, NewStringType::kNormal, name_len).ToLocal(&module_name)) {
        module_name = String::Empty(isolate);
    }
    Local<String> default_name = String::NewFromUtf8Literal(isolate, "default", NewStringType::kInternalized);
    Local<Module> module = Module::CreateSyntheticModule(
        isolate,
        module_name,
        std::span<const Local<String>>(&default_name, 1),
        JsonModuleEvaluationSteps
    );

    IsolateData* data = isolateData(isolate);
    if (!data) {
        *out_error = new V8ErrorInfo();
        (*out_error)->has_error = true;
        (*out_error)->message = strdup("JSON modules need an isolate made by v8_Isolate_New or v8_Isolate_NewFromSnapshot");
        (*out_error)->line_number = -1;
        (*out_error)->column_number = -1;
        return nullptr;
    }
    SyntheticJsonExport* entry = new SyntheticJsonExport();
    entry->module.Reset(isolate, module);
    entry->value.Reset(isolate, parsed);
    data->synthetic_json_exports.push_back(entry);

    return trackHandle(new Global<Module>(isolate, module));
}

/// ECMA-262 CreateDefaultExportSyntheticModule(defaultExport): a synthetic
/// module whose evaluation steps set its only export, "default", to `value` -
/// the JSON module's machinery (SyntheticJsonExport), with the value given.
/// HTML "create a CSS module script" step 6 makes one of its CSSStyleSheet.
///
/// Returns the module (Global<Module>*, caller owns - v8_Module_Dispose).
Global<Module>* v8_Module_CreateDefaultExportSyntheticModule(
    Global<Context>* context,
    Global<Value>* value,
    const char* name,
    int name_len
) {
    if (!context || !value) return nullptr;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    // `value` may be the wrapper cache's weak handle (a CSSStyleSheet's
    // wrapper): read it before anything below allocates, which can collect
    // the wrapper and reset the handle.
    if (value->IsEmpty()) return nullptr;
    Local<Value> default_export = value->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);

    Local<String> module_name;
    if (!String::NewFromUtf8(isolate, name, NewStringType::kNormal, name_len).ToLocal(&module_name)) {
        module_name = String::Empty(isolate);
    }
    Local<String> default_name = String::NewFromUtf8Literal(isolate, "default", NewStringType::kInternalized);
    Local<Module> module = Module::CreateSyntheticModule(
        isolate,
        module_name,
        std::span<const Local<String>>(&default_name, 1),
        JsonModuleEvaluationSteps
    );

    IsolateData* data = isolateData(isolate);
    if (!data) return nullptr;
    SyntheticJsonExport* entry = new SyntheticJsonExport();
    entry->module.Reset(isolate, module);
    entry->value.Reset(isolate, default_export);
    data->synthetic_json_exports.push_back(entry);

    return trackHandle(new Global<Module>(isolate, module));
}

// ============================================================================
// Dynamic Import (import() expression) Support
// ============================================================================

/// %Error.prototype% of `context`: the realm's intrinsic, not whatever script
/// has since stored at globalThis.Error. An Error made in the context has it
/// as its [[Prototype]].
Global<Object>* v8_Context_ErrorPrototype(Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);
    Local<Value> error = Exception::Error(String::Empty(isolate));
    if (!error->IsObject()) return nullptr;
    Local<Value> proto = error.As<Object>()->GetPrototype();
    if (!proto->IsObject()) return nullptr;
    return trackHandle(new Global<Object>(isolate, proto.As<Object>()));
}

/// Whether two module handles name the same module.
bool v8_Module_Equals(Global<Module>* a, Global<Module>* b) {
    if (!a || !b) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    return a->Get(isolate) == b->Get(isolate);
}

/// Resolve a dynamic import promise with a module namespace
/// Called from Zig when module loading succeeds
void v8_DynamicImport_Resolve(
    void* context_ptr,
    void* resolver_ptr,
    void* module_namespace_ptr
) {
    Isolate* isolate = Isolate::GetCurrent();
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);
    
    Global<Context>* context_global = static_cast<Global<Context>*>(context_ptr);
    Global<Promise::Resolver>* resolver_global = static_cast<Global<Promise::Resolver>*>(resolver_ptr);
    Global<Object>* namespace_global = static_cast<Global<Object>*>(module_namespace_ptr);
    
    Local<Context> context = context_global->Get(isolate);
    Local<Promise::Resolver> resolver = resolver_global->Get(isolate);
    Local<Object> module_namespace = namespace_global->Get(isolate);
    
    // Resolve the promise with the module namespace
    resolver->Resolve(context, module_namespace).Check();
    
    // Clean up Global handles
    delete context_global;
    resolver_global->Reset();
    delete resolver_global;
    // Don't delete namespace_global - caller owns it
}

/// Reject a dynamic import promise with a given VALUE (a Global<Value>* the
/// caller keeps). An import() whose module fails to parse, link or evaluate
/// rejects with that very exception, not a new Error describing it.
/// Consumes context_ptr and resolver_ptr, as Resolve and Reject do.
void v8_DynamicImport_RejectWithValue(
    void* context_ptr,
    void* resolver_ptr,
    Global<Value>* value
) {
    Isolate* isolate = Isolate::GetCurrent();
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);

    Global<Context>* context_global = static_cast<Global<Context>*>(context_ptr);
    Global<Promise::Resolver>* resolver_global = static_cast<Global<Promise::Resolver>*>(resolver_ptr);

    Local<Context> context = context_global->Get(isolate);
    Local<Promise::Resolver> resolver = resolver_global->Get(isolate);
    Local<Value> reason = value ? value->Get(isolate) : Undefined(isolate).As<Value>();

    resolver->Reject(context, reason).Check();

    delete context_global;
    resolver_global->Reset();
    delete resolver_global;
}

/// Reject a dynamic import promise with an error
/// Called from Zig when module loading fails
void v8_DynamicImport_Reject(
    void* context_ptr,
    void* resolver_ptr,
    const char* error_message,
    int error_message_len
) {
    Isolate* isolate = Isolate::GetCurrent();
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);
    
    Global<Context>* context_global = static_cast<Global<Context>*>(context_ptr);
    Global<Promise::Resolver>* resolver_global = static_cast<Global<Promise::Resolver>*>(resolver_ptr);
    
    Local<Context> context = context_global->Get(isolate);
    Local<Promise::Resolver> resolver = resolver_global->Get(isolate);
    
    // Create error from message
    Local<String> msg = String::NewFromUtf8(isolate, error_message, NewStringType::kNormal, error_message_len)
        .ToLocalChecked();
    Local<Value> error = Exception::Error(msg);
    
    // Reject the promise
    resolver->Reject(context, error).Check();
    
    // Clean up Global handles
    delete context_global;
    resolver_global->Reset();
    delete resolver_global;
}

// ============================================================================
// Exception Functions
// ============================================================================

Global<Value>* v8_Exception_TypeError(Global<String>* message) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<String> msg = message->Get(isolate);
    Local<Value> exception = Exception::TypeError(msg);
    return trackHandle(new Global<Value>(isolate, exception));
}

Global<Value>* v8_Exception_RangeError(Global<String>* message) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<String> msg = message->Get(isolate);
    Local<Value> exception = Exception::RangeError(msg);
    return trackHandle(new Global<Value>(isolate, exception));
}

Global<Value>* v8_Exception_SyntaxError(Global<String>* message) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<String> msg = message->Get(isolate);
    Local<Value> exception = Exception::SyntaxError(msg);
    return trackHandle(new Global<Value>(isolate, exception));
}

Global<Value>* v8_Exception_Error(Global<String>* message) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<String> msg = message->Get(isolate);
    Local<Value> exception = Exception::Error(msg);
    return trackHandle(new Global<Value>(isolate, exception));
}

// ============================================================================
// Cross-Realm Exception Functions
// ============================================================================
//
// These functions support throwing exceptions from a specific context/realm.
// Per WebIDL spec, when a method throws TypeError for invalid `this`, the
// TypeError must come from the method's realm (where it was defined), not
// the caller's realm. This is essential for cross-realm iframe support.

/// Get the context in which an object was created (for cross-realm support).
/// Returns nullptr if the object's creation context is unavailable.
Global<Context>* v8_Object_GetCreationContext(Global<Object>* obj) {
    if (!obj) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Object> local_obj = obj->Get(isolate);
    
    MaybeLocal<Context> maybe_ctx = local_obj->GetCreationContext(isolate);
    if (maybe_ctx.IsEmpty()) {
        return nullptr;
    }
    
    Local<Context> ctx = maybe_ctx.ToLocalChecked();
    countContextGlobal();
    return trackHandle(new Global<Context>(isolate, ctx));
}

/// Get the context in which a Global<Object> was created.
/// This is used in callbacks after converting the `this` object to a Global handle.
/// Returns nullptr if the object's creation context is unavailable.
///
/// Note: For FunctionCallbackInfo callbacks, use v8_FunctionCallbackInfo_Holder to get
/// the holder object, then call v8_Object_GetCreationContext on it.
///
/// This function is kept for compatibility but v8_Object_GetCreationContext (for Global handles)
/// should be preferred when possible.
Global<Context>* v8_Object_GetCreationContext_Raw(const void* obj_ptr) {
    // This function is deprecated - use v8_Object_GetCreationContext with a Global handle instead.
    // The raw pointer approach doesn't work reliably in modern V8.
    return nullptr;
}

/// Create TypeError in a specific context (for cross-realm errors).
/// This enters the context before creating the error, ensuring the
/// TypeError constructor comes from the correct realm.
///
/// @param context - The context/realm where the TypeError should originate
/// @param message - The error message as a V8 string
/// @returns A TypeError from the specified context's realm
Global<Value>* v8_Exception_TypeErrorInContext(Global<Context>* context, Global<String>* message) {
    if (!context || !message) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<String> msg = message->Get(isolate);
    
    // Enter the context to ensure TypeError comes from this realm
    Context::Scope context_scope(ctx);
    
    Local<Value> exception = Exception::TypeError(msg);
    return trackHandle(new Global<Value>(isolate, exception));
}

/// Create RangeError in a specific context (for cross-realm errors).
Global<Value>* v8_Exception_RangeErrorInContext(Global<Context>* context, Global<String>* message) {
    if (!context || !message) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<String> msg = message->Get(isolate);
    
    // Enter the context to ensure RangeError comes from this realm
    Context::Scope context_scope(ctx);
    
    Local<Value> exception = Exception::RangeError(msg);
    return trackHandle(new Global<Value>(isolate, exception));
}

/// Create SyntaxError in a specific context (for cross-realm errors).
Global<Value>* v8_Exception_SyntaxErrorInContext(Global<Context>* context, Global<String>* message) {
    if (!context || !message) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<String> msg = message->Get(isolate);
    
    // Enter the context to ensure SyntaxError comes from this realm
    Context::Scope context_scope(ctx);
    
    Local<Value> exception = Exception::SyntaxError(msg);
    return trackHandle(new Global<Value>(isolate, exception));
}

/// Create Error in a specific context (for cross-realm errors).
Global<Value>* v8_Exception_ErrorInContext(Global<Context>* context, Global<String>* message) {
    if (!context || !message) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<String> msg = message->Get(isolate);
    
    // Enter the context to ensure Error comes from this realm
    Context::Scope context_scope(ctx);
    
    Local<Value> exception = Exception::Error(msg);
    return trackHandle(new Global<Value>(isolate, exception));
}

/// A `stack` own property on `object` from the stack as it is now (v8::Exception::CaptureStackTrace), in
/// `context`'s realm: a DOMException's, as Blink's V8ThrowDOMException::AttachStackProperty gives one. Reads
/// no global property and runs no script, so it works in a realm whose WindowProxy went on to a new Window
/// (lane v8up b3e). False when V8 refused.
bool v8_Exception_CaptureStackTrace(Global<Context>* context, Global<Object>* object) {
    if (!context || !object) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    return Exception::CaptureStackTrace(ctx, object->Get(isolate)).FromMaybe(false);
}

/// Get the holder object from FunctionCallbackInfo.
/// The holder is the object where the property was found in the prototype chain.
/// For methods called on an instance, this is typically the prototype object
/// where the method is defined.
///
/// V8 stores the holder object at implicit_args_[kHolderIndex = 0].
///
/// For cross-realm support, we need the actual holder (e.g., other.DOMRectReadOnly.prototype)
/// not This() (the receiver, e.g., our rect object).
Global<Object>* v8_FunctionCallbackInfo_Holder(const FunctionCallbackInfo<Value>* info) {
    Isolate* isolate = info->GetIsolate();
    HandleScope handle_scope(isolate);
    
    // FunctionCallbackInfo memory layout (from v8-function-callback.h):
    // The class stores a pointer to implicit_args_ array which contains:
    //   - [0]: holder (kHolderIndex)
    //   - [1]: isolate (kIsolateIndex)
    //   - [2]: context (kContextIndex)
    //   - [3]: return value (kReturnValueIndex)
    //   - [4]: target (kTargetIndex)
    //   - [5]: new target (kNewTargetIndex)
    //
    // The holder is the prototype object where the method was found.
    // We access it via Data() and pointer arithmetic since Data() returns
    // implicit_args_[kTargetIndex].
    //
    // For methods installed via FunctionTemplate on prototype templates:
    // - The function is created from the FunctionTemplate
    // - Its "holder" in the callback context is the prototype object
    // - That prototype's creation context is the realm we want
    
    // Since V8 doesn't expose Holder() directly for FunctionCallbackInfo in modern versions,
    // we use the fact that NewTarget() for non-construct calls returns undefined,
    // and we can use the current context to determine the method's realm.
    //
    // When other.DOMRectReadOnly.prototype.toJSON.call(rect) is called:
    // - The current isolate context AT CALLBACK TIME is the caller's context
    // - But we want the context where the prototype method was instantiated
    //
    // The best we can do without holder access is to return This() and then
    // use GetPrototypeCreationContext to walk up to find the defining context.
    // This works because:
    // - rect's prototype is DOMRectReadOnly.prototype from main context
    // - but we're calling other.DOMRectReadOnly.prototype.toJSON on it
    //
    // Actually, for toJSON and similar, V8's Data() contains what we passed
    // when creating the function template. If we store the context there,
    // we could retrieve it here.
    //
    // For now, return This() and rely on GetPrototypeCreationContext in Zig
    // to find the method's realm by walking the prototype chain.
    Local<Object> this_obj = info->This();
    return trackHandle(new Global<Object>(isolate, this_obj));
}

/// Get the creation context of an object's prototype.
/// This walks up the prototype chain to find the first object with a
/// creation context different from the current context.
///
/// This is useful for cross-realm error handling, where we need to find
/// the context where the method/property was defined (on the prototype),
/// not the context where the `this` object was created.
///
/// For example:
///   const notElement = Object.create(other.HTMLElement.prototype);
///   // notElement is created in main context
///   // but its prototype is from iframe's context
///   // We want to throw TypeError from iframe's context
Global<Context>* v8_Object_GetPrototypeCreationContext(Global<Object>* obj) {
    if (!obj) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Object> local_obj = obj->Get(isolate);
    
    // Get the prototype of the object
    Local<Value> proto_val = local_obj->GetPrototype();
    if (proto_val.IsEmpty() || !proto_val->IsObject()) {
        return nullptr;
    }
    
    Local<Object> proto = proto_val.As<Object>();
    
    // Get the prototype's creation context
    MaybeLocal<Context> maybe_ctx = proto->GetCreationContext(isolate);
    if (maybe_ctx.IsEmpty()) {
        return nullptr;
    }
    
    Local<Context> ctx = maybe_ctx.ToLocalChecked();
    countContextGlobal();
    return trackHandle(new Global<Context>(isolate, ctx));
}

Global<Value>* v8_TryCatch_Exception(Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    TryCatch try_catch(isolate);
    
    if (try_catch.HasCaught()) {
        Local<Value> exception = try_catch.Exception();
        return trackHandle(new Global<Value>(isolate, exception));
    }
    
    return nullptr;
}

// ============================================================================
// Special Values
// ============================================================================

Global<Value>* v8_Undefined(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Value> undef = Undefined(isolate);
    return trackHandle(new Global<Value>(isolate, undef));
}

Global<Value>* v8_Null(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Value> null_val = Null(isolate);
    return trackHandle(new Global<Value>(isolate, null_val));
}

Global<Value>* v8_Boolean_New(Isolate* isolate, bool value) {
    HandleScope handle_scope(isolate);
    Local<Boolean> bool_val = Boolean::New(isolate, value);
    return trackHandle(new Global<Value>(isolate, bool_val));
}

/// Persist a Local value to a Global handle.
/// Takes a Local<Value> internal pointer and creates a tracked Global<Value>*.
/// Use this to safely store/return values that came from Local handles.
///
/// @param isolate - V8 Isolate
/// @param local_ptr - Internal pointer from a Local<Value> (from v8_Global_Get, etc.)
/// @return Global<Value>* that can be safely stored and used with setReturnValue
Global<Value>* v8_Value_Persist(Isolate* isolate, void* local_ptr) {
    if (!isolate || !local_ptr) return nullptr;

    HandleScope handle_scope(isolate);

    // Reconstruct Local from internal pointer
    Local<Value> local = *reinterpret_cast<Local<Value>*>(&local_ptr);

    // Create and track a Global handle
    return trackHandle(new Global<Value>(isolate, local));
}

// ============================================================================
// FunctionTemplate & FunctionCallbackInfo (for namespace bindings)
// ============================================================================

// Callback wrapper: converts V8 callback to our Global-based API
typedef void (*ZigCallback)(const FunctionCallbackInfo<Value>*);

Global<FunctionTemplate>* v8_FunctionTemplate_New(
    Isolate* isolate,
    ZigCallback callback,
    Global<Value>* data
) {
    HandleScope handle_scope(isolate);
    Local<FunctionTemplate> tpl = FunctionTemplate::New(
        isolate,
        reinterpret_cast<FunctionCallback>(callback),
        data ? data->Get(isolate) : Local<Value>()
    );
    return trackHandle(new Global<FunctionTemplate>(isolate, tpl));
}

// Create FunctionTemplate with Signature (receiver type checking)
// The signature ensures the callback is only called when 'this' is an instance
// of the receiver template (or a subclass via inheritance).
Global<FunctionTemplate>* v8_FunctionTemplate_NewWithSignature(
    Isolate* isolate,
    ZigCallback callback,
    Global<Value>* data,
    Global<FunctionTemplate>* receiver
) {
    HandleScope handle_scope(isolate);
    
    // Create signature from receiver template
    Local<FunctionTemplate> receiver_local = receiver->Get(isolate);
    Local<Signature> signature = Signature::New(isolate, receiver_local);
    
    // Create function template with signature
    Local<FunctionTemplate> tpl = FunctionTemplate::New(
        isolate,
        reinterpret_cast<FunctionCallback>(callback),
        data ? data->Get(isolate) : Local<Value>(),
        signature  // V8 will enforce receiver type
    );
    return trackHandle(new Global<FunctionTemplate>(isolate, tpl));
}

Global<Function>* v8_FunctionTemplate_GetFunction(Global<FunctionTemplate>* function_template, Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<FunctionTemplate> tpl = function_template->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    MaybeLocal<Function> maybe_fn = tpl->GetFunction(ctx);
    if (maybe_fn.IsEmpty()) {
        return nullptr;
    }
    
    Local<Function> fn = maybe_fn.ToLocalChecked();
    return trackHandle(new Global<Function>(isolate, fn));
}

void v8_FunctionTemplate_Dispose(Global<FunctionTemplate>* tpl) {
    // Snapshot mode: trackHandle queued this handle for bulk cleanup (see
    // v8_ObjectTemplate_Dispose), so deleting it here too is a double free.
    if (g_snapshot_mode) return;
    if (tpl) {
        releaseWeakArm(tpl);
        tpl->Reset();
        delete tpl;
    }
}

void v8_FunctionTemplate_SetClassName(Global<FunctionTemplate>* tpl, Global<String>* name) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<FunctionTemplate> local_tpl = tpl->Get(isolate);
    Local<String> local_name = name->Get(isolate);
    local_tpl->SetClassName(local_name);
}

// Release a Global<ObjectTemplate>.
//
// Typed rather than routing through v8_Global_Dispose: every `Global<T>` happens
// to have the same layout, but casting between them to pick a destructor is UB
// that works by accident, and this file has enough of those already.
//
// NO-OP IN SNAPSHOT MODE, and this is not optional. `trackHandle` pushes every
// handle it sees into `g_snapshot_handles` while the snapshot is being built, and
// `v8_Snapshot_ClearGlobalHandles` resets and deletes all of them at the end. A
// caller that also disposes gets a double free - which is exactly what happened
// the first time this function was added, and the snapshot generator aborted
// inside `resetGlobalHandle`. During generation the snapshot cleanup owns the
// handle; leaking for the lifetime of a one-shot build tool is the cheap side.
//
// ANY disposal added to this wrapper needs the same guard.
void v8_ObjectTemplate_Dispose(Global<ObjectTemplate>* tpl) {
    if (!tpl) return;
    if (g_snapshot_mode) return;
    releaseWeakArm(tpl);
    tpl->Reset();
    delete tpl;
}

Global<ObjectTemplate>* v8_FunctionTemplate_InstanceTemplate(Global<FunctionTemplate>* tpl) {
    Isolate* isolate = Isolate::GetCurrent();
    if (!isolate) {
        return nullptr;
    }
    HandleScope handle_scope(isolate);
    Local<FunctionTemplate> local_tpl = tpl->Get(isolate);
    Local<ObjectTemplate> instance_tpl = local_tpl->InstanceTemplate();
    return trackHandle(new Global<ObjectTemplate>(isolate, instance_tpl));
}

Global<ObjectTemplate>* v8_FunctionTemplate_PrototypeTemplate(Global<FunctionTemplate>* tpl) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<FunctionTemplate> local_tpl = tpl->Get(isolate);
    Local<ObjectTemplate> proto_tpl = local_tpl->PrototypeTemplate();
    return trackHandle(new Global<ObjectTemplate>(isolate, proto_tpl));
}

void v8_FunctionTemplate_Inherit(Global<FunctionTemplate>* tpl, Global<FunctionTemplate>* parent) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<FunctionTemplate> local_tpl = tpl->Get(isolate);
    Local<FunctionTemplate> local_parent = parent->Get(isolate);
    local_tpl->Inherit(local_parent);
}

void v8_FunctionTemplate_SetLength(Global<FunctionTemplate>* tpl, int length) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<FunctionTemplate> local_tpl = tpl->Get(isolate);
    local_tpl->SetLength(length);
}

// Check if a value is an instance of the given FunctionTemplate
// This is used for [LegacyLenientThis] attribute checking
bool v8_FunctionTemplate_HasInstance(Global<FunctionTemplate>* tpl, Global<Object>* object) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<FunctionTemplate> local_tpl = tpl->Get(isolate);
    Local<Object> local_obj = object->Get(isolate);
    return local_tpl->HasInstance(local_obj);
}

void v8_FunctionTemplate_ReadOnlyPrototype(Global<FunctionTemplate>* tpl) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<FunctionTemplate> local_tpl = tpl->Get(isolate);
    // ReadOnlyPrototype() makes the "prototype" property non-writable
    // and also removes "arguments" and "caller" properties from functions
    // created from this template, making them behave like strict mode functions.
    local_tpl->ReadOnlyPrototype();
}

// Get the prototype object from a FunctionTemplate.
// This calls GetFunction() and then gets the "prototype" property from the function.
// Used when wrapping Zig instances as V8 objects - we need to manually set the prototype
// because ObjectTemplate::NewInstance() doesn't automatically link to the FunctionTemplate's prototype.
Global<Object>* v8_FunctionTemplate_GetPrototypeObject(Global<FunctionTemplate>* tpl, Global<Context>* context) {
    g_obj_src[4].fetch_add(1, std::memory_order_relaxed);
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);

    Local<FunctionTemplate> local_tpl = tpl->Get(isolate);
    Local<Context> ctx = context->Get(isolate);

    // Get the function from the template
    MaybeLocal<Function> maybe_fn = local_tpl->GetFunction(ctx);
    if (maybe_fn.IsEmpty()) {
        return nullptr;
    }

    Local<Function> fn = maybe_fn.ToLocalChecked();

    // Get the "prototype" property from the function
    Local<String> prototype_str = String::NewFromUtf8Literal(isolate, "prototype");
    MaybeLocal<Value> maybe_proto = fn->Get(ctx, prototype_str);
    if (maybe_proto.IsEmpty()) {
        return nullptr;
    }

    Local<Value> proto_val = maybe_proto.ToLocalChecked();
    if (!proto_val->IsObject()) {
        return nullptr;
    }

    Local<Object> proto_obj = proto_val.As<Object>();
    return trackHandle(new Global<Object>(isolate, proto_obj));
}

// Get the prototype object by looking up the constructor from the global object.
// This ensures we get the SAME prototype that JavaScript sees on globalThis.ConstructorName.prototype.
// This is necessary for `instanceof` to work correctly.
Global<Object>* v8_GetGlobalPrototype(Global<Context>* context, const char* constructor_name) {
    g_obj_src[3].fetch_add(1, std::memory_order_relaxed);
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);

    Local<Context> ctx = context->Get(isolate);
    Local<Object> global = ctx->Global();

    // Get the constructor from global (e.g., globalThis.MessagePort)
    Local<String> name_str = String::NewFromUtf8(isolate, constructor_name).ToLocalChecked();
    MaybeLocal<Value> maybe_constructor = global->Get(ctx, name_str);
    if (maybe_constructor.IsEmpty()) {
        CRANE_PROTO_MISS("[v8_GetGlobalPrototype] %s: constructor not found\n", constructor_name);
        return nullptr;
    }

    Local<Value> constructor_val = maybe_constructor.ToLocalChecked();
    if (!constructor_val->IsFunction()) {
        CRANE_PROTO_MISS("[v8_GetGlobalPrototype] %s: not a function\n", constructor_name);
        return nullptr;
    }

    Local<Function> constructor = constructor_val.As<Function>();

    // Get the "prototype" property from the constructor
    Local<String> prototype_str = String::NewFromUtf8Literal(isolate, "prototype");
    MaybeLocal<Value> maybe_proto = constructor->Get(ctx, prototype_str);
    if (maybe_proto.IsEmpty()) {
        CRANE_PROTO_MISS("[v8_GetGlobalPrototype] %s: no prototype property\n", constructor_name);
        return nullptr;
    }

    Local<Value> proto_val = maybe_proto.ToLocalChecked();
    if (!proto_val->IsObject()) {
        CRANE_PROTO_MISS("[v8_GetGlobalPrototype] %s: prototype is not an object\n", constructor_name);
        return nullptr;
    }

    Local<Object> proto_obj = proto_val.As<Object>();

    return trackHandle(new Global<Object>(isolate, proto_obj));
}

void v8_FunctionTemplate_RemovePrototype(Global<FunctionTemplate>* tpl) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<FunctionTemplate> local_tpl = tpl->Get(isolate);
    // RemovePrototype() removes the "prototype" property entirely.
    // This also removes "arguments" and "caller" properties.
    // Use for methods and getters which should not have prototype.
    local_tpl->RemovePrototype();
}

/// Set a call handler on a FunctionTemplate.
/// This is required for objects marked as undetectable (like document.all)
/// because V8 requires undetectable objects to be callable.
void v8_FunctionTemplate_SetCallHandler(
    Global<FunctionTemplate>* tpl,
    FunctionCallback callback,
    void* data
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<FunctionTemplate> local_tpl = tpl->Get(isolate);
    Local<Value> callback_data = data ? Local<Value>(External::New(isolate, data, kCraneExternalTag)) : Local<Value>();
    local_tpl->SetCallHandler(callback, callback_data);
}

// FunctionCallbackInfo accessors
Isolate* v8_FunctionCallbackInfo_GetIsolate(const FunctionCallbackInfo<Value>* info) {
    return info->GetIsolate();
}

int v8_FunctionCallbackInfo_Length(const FunctionCallbackInfo<Value>* info) {
    return info->Length();
}

// FunctionCallbackInfo - the instance the receiver (This()) reaches
// (`instanceOfObject`: its platform anchor's, looked through a legacy platform
// object's proxy to its target; a node's; a realm's global's field); a
// receiver that is no wrapper - or not an object - reads as nullptr. The
// brand check is the instance's state ancestry (conv.implements). No Global:
// This() is a slot of the callback's arguments, and an attribute getter runs once per read
// - `list.length` ~6e7 times in NodeList-static-length-getter-tampered-[123].html,
// where v8_FunctionCallbackInfo_This's Global, made, tracked and disposed per
// call, and a HandleScope per field read were most of the binding's cost. A
// Local the proxy's target makes lives in the callback's own HandleScope (V8
// opens one around every API callback).
void* v8_FunctionCallbackInfo_ThisInstance(const FunctionCallbackInfo<Value>* info) {
    Local<Value> receiver = info->This();
    if (!receiver->IsObject()) return nullptr;
    return instanceOfObject(info->GetIsolate(), receiver.As<Object>());
}

// FunctionCallbackInfo - the receiver's node wrapper slot, for a member of a
// node interface (one whose instances are all nodes: the binding knows it at
// comptime, interface.zig): Object::Unwrap under the node anchors' tag, the
// anchor, its slot (design 4.3) - the node and its instance are the Zig
// side's to find (node_wrappers.instanceOfSlot). Null for a receiver that is
// no node wrapper, or one whose node's teardown severed it. No Global, no
// HandleScope (v8_FunctionCallbackInfo_ThisInstance says why).
void* v8_FunctionCallbackInfo_ThisNodeSlot(const FunctionCallbackInfo<Value>* info) {
    Local<Value> receiver = info->This();
    if (!receiver->IsObject()) return nullptr;
    NODE_ANCHOR_IN_FRAME(info->GetIsolate());
    NodeAnchor* anchor = nodeAnchorOf(info->GetIsolate(), receiver.As<Object>());
    return anchor ? anchor->slot_ : nullptr;
}

// FunctionCallbackInfo - set a primitive return value straight into the
// return slot (a Smi where it fits, else a heap number made in the callback's
// HandleScope): no Global for a number or boolean result.
void v8_FunctionCallbackInfo_SetReturnValueDouble(const FunctionCallbackInfo<Value>* info, double value) {
    info->GetReturnValue().Set(value);
}

// A value that fits 16 bits takes ReturnValue::Set(int16_t / uint16_t), a
// Smi with no range test: Set(int32_t)'s TryIntegralToSmi goes through
// std::optional, which at -O0 (the Debug build) is a chain of calls.
void v8_FunctionCallbackInfo_SetReturnValueInt32(const FunctionCallbackInfo<Value>* info, int32_t value) {
    if (value >= INT16_MIN && value <= INT16_MAX) {
        info->GetReturnValue().Set(static_cast<int16_t>(value));
    } else {
        info->GetReturnValue().Set(value);
    }
}

void v8_FunctionCallbackInfo_SetReturnValueUint32(const FunctionCallbackInfo<Value>* info, uint32_t value) {
    if (value <= UINT16_MAX) {
        info->GetReturnValue().Set(static_cast<uint16_t>(value));
    } else {
        info->GetReturnValue().Set(value);
    }
}

void v8_FunctionCallbackInfo_SetReturnValueBool(const FunctionCallbackInfo<Value>* info, bool value) {
    info->GetReturnValue().Set(value);
}

Global<Value>* v8_FunctionCallbackInfo_GetArgument(const FunctionCallbackInfo<Value>* info, int index) {
    Isolate* isolate = info->GetIsolate();
    Local<Value> arg = (*info)[index];
    return trackHandle(new Global<Value>(isolate, arg));
}

// ---- lane perf3, phase 1b: a binding call's own values, with no Global ----
//
// A binding callback runs inside the HandleScope V8 opens around every API
// callback (CallApiFunctionAndReturn "Allocates HandleScope, extracts returned
// value from handle and propagates exceptions"), as Blink's generated bindings
// rely on (they open none for an attribute or an operation). These functions
// make their Locals there - none opens a scope or makes a Global - and hand Zig
// plain data, never a Local: so no Local outlives the call that made it, and a
// return value is written into V8's own return slot (a root of the call frame)
// before any scope a caller opened around the body closes. Called only with the
// `info` of a live callback (call_frame.zig; tmp/plans/perf3-design.md 5.2).

/// A string result: `length` bytes of ASCII (`one_byte`: NewFromOneByte, a copy
/// with no decode) or well-formed UTF-8 (NewFromUtf8). WTF-8 with surrogate code
/// points takes the two-byte path the binding had (conversions.newStringFromWtf8).
/// Undefined when V8 refuses the length (String::kMaxLength), as before.
void v8_FunctionCallbackInfo_SetReturnString(const FunctionCallbackInfo<Value>* info, const uint8_t* bytes, int length, bool one_byte) {
    if (length == 0) {
        info->GetReturnValue().SetEmptyString();
        return;
    }
    Isolate* isolate = info->GetIsolate();
    MaybeLocal<String> made = one_byte
        ? String::NewFromOneByte(isolate, bytes, NewStringType::kNormal, length)
        : String::NewFromUtf8(isolate, reinterpret_cast<const char*>(bytes), NewStringType::kNormal, length);
    Local<String> str;
    if (!made.ToLocal(&str)) {
        info->GetReturnValue().SetUndefined();
        return;
    }
    info->GetReturnValue().Set(str);
}

/// A null result: the root, no handle.
void v8_FunctionCallbackInfo_SetReturnNull(const FunctionCallbackInfo<Value>* info) {
    info->GetReturnValue().SetNull();
}

/// What v8_FunctionCallbackInfo_ReadArgument read (call_frame.zig's
/// ArgumentRead, field for field).
struct ArgumentRead {
    int32_t kind;  // 0 missing, 1 undefined, 2 null, 3 boolean, 4 number, 5 string, 6 object, 7 other
    int32_t length;
    double number;
    bool boolean;
    bool fits;
    void* instance;
};

/// sizeof(ArgumentRead), so a test pins ffi.ArgumentRead's layout against it:
/// the struct crosses the FFI by pointer and both sides must agree.
size_t v8_ArgumentRead_Size() {
    return sizeof(ArgumentRead);
}

/// Argument `index` of the call, read with no handle: its kind; ToBoolean of it
/// (which runs no script); a Number's value; a String's WTF-8 into `buffer` (the
/// bytes v8_String_WriteUtf8 gives: no REPLACE_INVALID_UTF8, so a lone surrogate
/// is its three-byte form, as fromV8String reads it), whole or not at all
/// (`fits`; `length` is then the bytes a buffer needs); an object's internal
/// field 0 through a legacy platform object's proxy, as `this` is read
/// (v8_FunctionCallbackInfo_ThisInstance) - none for a function, which no
/// platform object is (conversions.platformObjectOf).
void v8_FunctionCallbackInfo_ReadArgument(const FunctionCallbackInfo<Value>* info, int index, ArgumentRead* out, char* buffer, int capacity) {
    out->kind = 0;
    out->length = 0;
    out->number = 0;
    out->boolean = false;
    out->fits = false;
    out->instance = nullptr;
    if (index < 0 || index >= info->Length()) return;
    Isolate* isolate = info->GetIsolate();
    Local<Value> value = (*info)[index];
    out->boolean = value->BooleanValue(isolate);
    if (value->IsUndefined()) {
        out->kind = 1;
    } else if (value->IsNull()) {
        out->kind = 2;
    } else if (value->IsBoolean()) {
        out->kind = 3;
    } else if (value->IsNumber()) {
        out->kind = 4;
        out->number = value.As<Number>()->Value();
    } else if (value->IsString()) {
        out->kind = 5;
        Local<String> str = value.As<String>();
        size_t chars = 0;
        const size_t written = capacity > 0 ? str->WriteUtf8(isolate, buffer, static_cast<size_t>(capacity), String::WriteFlags::kNone, &chars) : 0;
        if (chars == static_cast<size_t>(str->Length())) {
            out->fits = true;
            out->length = static_cast<int>(written);
        } else {
            out->length = static_cast<int>(str->Utf8Length(isolate));
        }
    } else if (value->IsObject()) {
        out->kind = 6;
        if (value->IsFunction()) return;
        // The platform object it is, if any: its wrapper's instance.
        out->instance = instanceOfObject(isolate, value.As<Object>());
    } else {
        out->kind = 7;
    }
}

/// A String argument too long for the first buffer: its whole WTF-8 into
/// `buffer` of `length` bytes (the length ReadArgument gave). Returns the bytes
/// written, or -1 when the argument is no longer a String of that length.
int v8_FunctionCallbackInfo_ReadArgumentString(const FunctionCallbackInfo<Value>* info, int index, char* buffer, int length) {
    if (index < 0 || index >= info->Length()) return -1;
    Local<Value> value = (*info)[index];
    if (!value->IsString()) return -1;
    Isolate* isolate = info->GetIsolate();
    Local<String> str = value.As<String>();
    if (length < 0) return -1;
    size_t chars = 0;
    const size_t written = str->WriteUtf8(isolate, buffer, static_cast<size_t>(length), String::WriteFlags::kNone, &chars);
    if (chars != static_cast<size_t>(str->Length())) return -1;
    return static_cast<int>(written);
}

void v8_FunctionCallbackInfo_SetReturnValue(const FunctionCallbackInfo<Value>* info, Global<Value>* value) {
    if (!value) {
        // Null value passed - set undefined and log warning
        fprintf(stderr, "WARNING: v8_FunctionCallbackInfo_SetReturnValue called with null value\n");
        return;
    }
    
    // Sanity checks for corrupted pointers
    uintptr_t ptr_val = reinterpret_cast<uintptr_t>(value);
    
    // Check 1: Pointer should be in a reasonable address range (not small integers or negative values)
    if (ptr_val < 0x1000 || ptr_val > 0x0000FFFFFFFFFFFF) {
        fprintf(stderr, "WARNING: v8_FunctionCallbackInfo_SetReturnValue called with suspicious pointer: %p (out of range)\n", value);
        // Don't try to access this pointer - it's clearly garbage
        // Just return undefined instead
        info->GetReturnValue().SetUndefined();
        return;
    }
    
    // Check 2: V8's Global handles should be aligned to at least 8 bytes on 64-bit
    if ((ptr_val & 0x7) != 0) {
        fprintf(stderr, "WARNING: v8_FunctionCallbackInfo_SetReturnValue called with misaligned pointer: %p (alignment=%lu)\n", value, ptr_val & 0x7);
        info->GetReturnValue().SetUndefined();
        return;
    }
    
    // Check if the Global handle is empty (was Reset() called on it?)
    if (value->IsEmpty()) {
        fprintf(stderr, "WARNING: v8_FunctionCallbackInfo_SetReturnValue called with empty Global handle\n");
        return;
    }

    Isolate* isolate = info->GetIsolate();
    Local<Value> val = value->Get(isolate);
    info->GetReturnValue().Set(val);
}

/// Set return value from a Local<Value> pointer
///
/// This is used when we have a Local<Value> (from v8_Global_Get or other operations)
/// instead of a Global<Value>*. The pointer is treated as the internal pointer
/// from a Local<Value> and wrapped in a Local to pass to ReturnValue::Set.
///
/// @param info - FunctionCallbackInfo pointer
/// @param local_ptr - Internal pointer from a Local<Value> (from v8_Global_Get, etc.)
void v8_FunctionCallbackInfo_SetReturnValueLocal(const FunctionCallbackInfo<Value>* info, void* local_ptr) {
    if (!local_ptr) {
        // Null value - set undefined
        info->GetReturnValue().SetUndefined();
        return;
    }
    
    // Sanity checks for corrupted pointers
    uintptr_t ptr_val = reinterpret_cast<uintptr_t>(local_ptr);
    
    // Check 1: Pointer should be in a reasonable address range
    if (ptr_val < 0x1000 || ptr_val > 0x0000FFFFFFFFFFFF) {
        info->GetReturnValue().SetUndefined();
        return;
    }
    
    // Check 2: Should be aligned to at least 4 bytes
    if ((ptr_val & 0x3) != 0) {
        info->GetReturnValue().SetUndefined();
        return;
    }
    
    // Wrap the raw pointer in a Local<Value>
    // This assumes the pointer came from a valid Local (like from v8_Global_Get)
    Local<Value> local = *reinterpret_cast<Local<Value>*>(&local_ptr);
    info->GetReturnValue().Set(local);
}

/// Set the return value from a Global handle.
/// 
/// This function properly converts a Global<Value> to a Local<Value> using the
/// isolate's current context, then sets it as the return value.
///
/// Use this when the value comes from v8_String_NewFromUtf8, v8_Number_New, etc.
/// which return Global<T>* handles.
///
/// @param info - FunctionCallbackInfo pointer
/// @param global_ptr - Pointer to a Global<Value> (from v8_String_NewFromUtf8, etc.)
void v8_FunctionCallbackInfo_SetReturnValueGlobal(const FunctionCallbackInfo<Value>* info, void* global_ptr) {
    if (!global_ptr) {
        info->GetReturnValue().SetUndefined();
        return;
    }

    // Sanity checks for corrupted pointers
    uintptr_t ptr_val = reinterpret_cast<uintptr_t>(global_ptr);

    // Pointer should be in a reasonable address range and aligned
    if (ptr_val < 0x1000 || ptr_val > 0x0000FFFFFFFFFFFF || (ptr_val & 0x7) != 0) {
        info->GetReturnValue().SetUndefined();
        return;
    }

    // (No address-range test: a node's wrapper is a Global constructed in
    // place in its NodeBase - the wrapper redesign's P2 - which lives in the
    // Browser's arena, wherever the system maps it; a guess that addresses
    // in [0x100000000, 0x110000000) are code turned every node wrapper there
    // into undefined.)

    Global<Value>* global = reinterpret_cast<Global<Value>*>(global_ptr);

    // Check if the Global handle is empty
    if (global->IsEmpty()) {
        fprintf(stderr, "[SetReturnValueGlobal] Global handle is EMPTY!\n");
        info->GetReturnValue().SetUndefined();
        return;
    }

    // ReturnValue::Set(const Global<S>&) reads the node's slot straight into
    // the return slot: no HandleScope and no Local copy (perf3 phase 1b; a
    // scope and a copy per wrapper or handle result before).
    info->GetReturnValue().Set(*global);
}

void v8_Function_Dispose(Global<Function>* fn) {
    // Snapshot mode: trackHandle queued this handle for bulk cleanup (see
    // v8_ObjectTemplate_Dispose), so deleting it here too is a double free.
    if (g_snapshot_mode) return;
    if (fn) {
        forgetCountedHandle(fn);
        releaseWeakArm(fn);
        fn->Reset();
        delete fn;
    }
}

// Set the name of a function
// This is used to set the .name property on functions for WebIDL compliance
void v8_Function_SetName(Global<Function>* func, Global<String>* name) {
    if (!func || !name) return;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Function> fn = func->Get(isolate);
    Local<String> n = name->Get(isolate);
    fn->SetName(n);
}

// FunctionCallbackInfo - get 'this' object
Global<Object>* v8_FunctionCallbackInfo_This(const FunctionCallbackInfo<Value>* info) {
    g_obj_src[0].fetch_add(1, std::memory_order_relaxed);
    Isolate* isolate = info->GetIsolate();
    HandleScope handle_scope(isolate);
    Local<Object> self = info->This();
    return trackHandle(new Global<Object>(isolate, self));
}

// FunctionCallbackInfo - check if called with 'new'
bool v8_FunctionCallbackInfo_IsConstructCall(const FunctionCallbackInfo<Value>* info) {
    return info->IsConstructCall();
}

// FunctionCallbackInfo - get callback data
Global<Value>* v8_FunctionCallbackInfo_Data(const FunctionCallbackInfo<Value>* info) {
    Isolate* isolate = info->GetIsolate();
    HandleScope handle_scope(isolate);
    Local<Value> data = info->DataV2().As<Value>();
    return trackHandle(new Global<Value>(isolate, data));
}

/// The realm of the function being called: the current context. Calling a
/// function enters its realm - the call sequence loads the JSFunction's own
/// context, and V8's API-callback builtins run the callback in it - so inside
/// a FunctionCallback the current context IS the callee's [[Realm]], the
/// realm WebIDL's operations, getters, setters and constructors throw and
/// create in ("the current realm"; Blink: ScriptState::ForCurrentRealm(info)
/// reads isolate->GetCurrentContext()). V8 >= 14 flattened
/// FunctionCallbackInfo into a view of the API exit frame (b9c4e374820) and
/// keeps its target slot private; the old read of `implicit_args_[kTargetIndex]`
/// through a copied layout would read garbage there.
Global<Context>* v8_FunctionCallbackInfo_GetFunctionCreationContext(const FunctionCallbackInfo<Value>* info) {
    Isolate* isolate = info->GetIsolate();
    HandleScope handle_scope(isolate);
    countContextGlobal();
    return trackHandle(new Global<Context>(isolate, isolate->GetCurrentContext()));
}

/// Get the NewTarget from a constructor call.
/// This returns the function that was actually called with 'new', which is important
/// for cross-realm construction: when using Reflect.construct(Ctor, args, NewTarget),
/// the object should be created in NewTarget's realm.
///
/// Returns nullptr for non-construct calls.
Global<Value>* v8_FunctionCallbackInfo_NewTarget(const FunctionCallbackInfo<Value>* info) {
    Isolate* isolate = info->GetIsolate();
    HandleScope handle_scope(isolate);
    
    // Use V8's public NewTarget() API which handles internal layout properly
    Local<Value> new_target = info->NewTarget();
    
    // For non-construct calls, NewTarget is undefined
    if (new_target.IsEmpty() || new_target->IsUndefined()) {
        return nullptr;
    }
    
    return trackHandle(new Global<Value>(isolate, new_target));
}

/// Check if a value is a bound function.
/// Bound functions are created via Function.prototype.bind() and have
/// a [[BoundTargetFunction]] internal slot.
///
/// This is used for implementing GetFunctionRealm algorithm per ECMA-262 §7.3.22,
/// which needs to recurse through bound functions to find the original realm.
bool v8_Value_IsBoundFunction(Global<Value>* value) {
    if (!value) return false;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> local_value = value->Get(isolate);
    
    if (!local_value->IsFunction()) return false;
    
    // V8 doesn't expose a direct IsBoundFunction check, but we can detect
    // bound functions by checking if they have the internal bound target.
    // Bound functions in V8 are JSBoundFunction objects with specific properties.
    //
    // A practical way to detect this: bound functions have name starting with "bound "
    // and their .length property is computed specially.
    // 
    // However, the most reliable way is to check internal fields.
    // V8's JSBoundFunction has [[BoundTargetFunction]], [[BoundThis]], [[BoundArguments]]
    //
    // For a simpler approach, we use the fact that GetBoundFunction() on a
    // non-bound function returns itself, while on bound function it returns the target.
    // But V8 12+ may not have GetBoundFunction exposed...
    //
    // Alternative: check Function::GetScriptOrigin() - bound functions have empty origin
    // But this isn't fully reliable either.
    //
    // Best approach: check internal class name via Object::GetConstructorName
    // But this could be spoofed...
    //
    // V8 12.x approach: JSBoundFunction is a separate type but not directly queryable
    // from the public API. We'll use a heuristic: try to get the name and check
    // if it starts with "bound ".
    
    Local<Function> func = local_value.As<Function>();
    Local<Value> name_val = func->GetName();
    
    if (name_val->IsString()) {
        Local<String> name_str = name_val.As<String>();
        String::Utf8Value utf8(isolate, name_str);
        if (*utf8 && strncmp(*utf8, "bound ", 6) == 0) {
            return true;
        }
    }
    
    // Additional check: bound functions typically don't have own 'prototype' property
    // (unless explicitly set), but this isn't definitive
    
    return false;
}

/// Get the [[BoundTargetFunction]] of a bound function.
/// This is used for implementing GetFunctionRealm algorithm per ECMA-262 §7.3.22,
/// which needs to recurse through bound functions to find the original function's realm.
///
/// Returns nullptr if the value is not a function or if we can't determine the bound target.
/// For non-bound functions, returns the function itself.
Global<Function>* v8_BoundFunction_GetBoundTargetFunction(Global<Function>* func) {
    if (!func) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Function> local_func = func->Get(isolate);
    
    // V8 doesn't expose GetBoundFunction() in the public API for v12+
    // We need to use internal APIs or workarounds
    //
    // Since we can't directly access [[BoundTargetFunction]], we return the
    // function itself. The caller should use v8_Value_IsBoundFunction first
    // to check, and if it's bound, we need another approach.
    //
    // For now, we'll use Function::GetCreationContext on the function directly.
    // Even for bound functions, GetCreationContext returns the realm where
    // the *bound function object* was created, which may be sufficient.
    //
    // If we need the true target, we could:
    // 1. Call toString() and parse it (hacky)
    // 2. Use V8 internals (not portable)
    // 3. Store a map of bound functions to targets (complex)
    
    // For now, just return the same function - the IsBoundFunction check
    // will indicate if further processing is needed
    return trackHandle(new Global<Function>(isolate, local_func));
}

/// Get the creation context (realm) of a function.
/// This is the context where the function was instantiated.
///
/// For cross-realm constructor support per WebIDL §3.7.2:
/// - Objects should be created in GetFunctionRealm(NewTarget) realm
/// - This function provides the realm for regular functions
/// - For bound functions and proxies, the caller must handle recursion
Global<Context>* v8_Function_GetCreationContext(Global<Function>* func) {
    if (!func) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Function> local_func = func->Get(isolate);
    
    MaybeLocal<Context> maybe_ctx = local_func->GetCreationContext(isolate);
    if (maybe_ctx.IsEmpty()) {
        return nullptr;
    }
    
    countContextGlobal();
    return trackHandle(new Global<Context>(isolate, maybe_ctx.ToLocalChecked()));
}

// ============================================================================
// External - Wrap C pointers for storage in V8
// ============================================================================

// Create External value wrapping a C pointer
Global<External>* v8_External_New(Isolate* isolate, void* value) {
    HandleScope handle_scope(isolate);
    Local<External> external = External::New(isolate, value, kCraneExternalTag);
    return trackHandle(new Global<External>(isolate, external));
}

// Extract wrapped pointer from External
void* v8_External_Value(Global<External>* external) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<External> local_ext = external->Get(isolate);
    return local_ext->Value(kCraneExternalTag);
}

// Dispose External
void v8_External_Dispose(Global<External>* external) {
    // Snapshot mode: trackHandle queued this handle for bulk cleanup (see
    // v8_ObjectTemplate_Dispose), so deleting it here too is a double free.
    if (g_snapshot_mode) return;
    if (external) {
        releaseWeakArm(external);
        external->Reset();
        delete external;
    }
}

// ObjectTemplate - create a new ObjectTemplate
Global<ObjectTemplate>* v8_ObjectTemplate_New(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> tpl = ObjectTemplate::New(isolate);
    return trackHandle(new Global<ObjectTemplate>(isolate, tpl));
}

// ObjectTemplate - set property (uses current isolate from the template's context)
void v8_ObjectTemplate_Set(Global<ObjectTemplate>* tpl, Global<String>* name, Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    Local<String> key = name->Get(isolate);
    Local<Value> val = value->Get(isolate);
    local_tpl->Set(key, val);
}

// ObjectTemplate - %Symbol.iterator% as %Array.prototype.values%, non-
// enumerable: WebIDL's "define the iteration methods" step 1 for an interface
// with an indexed property getter. An intrinsic, so each instantiation reads
// the function from its own context; and part of the template, so it
// survives the snapshot.
void v8_ObjectTemplate_SetIteratorToArrayValues(Global<ObjectTemplate>* tpl) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    local_tpl->SetIntrinsicDataProperty(Symbol::GetIterator(isolate), kArrayProto_values, DontEnum);
}

// WebIDL 3.7.9 "define the iteration methods" step 1.2: an interface with a
// value iterator takes %Array.prototype.entries%, %Array.prototype.keys%,
// %Array.prototype.values% and %Array.prototype.forEach% as its entries,
// keys, values and forEach - CreateDataPropertyOrThrow, so writable,
// enumerable and configurable (None). An intrinsic data property is resolved
// from the context each instantiation happens in (v8-template.h,
// SetIntrinsicDataProperty), so every realm's prototype holds that realm's
// own functions; Blink's bindings install the same four (bind_gen/interface.py).
void v8_ObjectTemplate_SetValueIteratorToArrayMethods(Global<ObjectTemplate>* tpl) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    local_tpl->SetIntrinsicDataProperty(String::NewFromUtf8Literal(isolate, "entries", NewStringType::kInternalized), kArrayProto_entries, None);
    local_tpl->SetIntrinsicDataProperty(String::NewFromUtf8Literal(isolate, "keys", NewStringType::kInternalized), kArrayProto_keys, None);
    local_tpl->SetIntrinsicDataProperty(String::NewFromUtf8Literal(isolate, "values", NewStringType::kInternalized), kArrayProto_values, None);
    local_tpl->SetIntrinsicDataProperty(String::NewFromUtf8Literal(isolate, "forEach", NewStringType::kInternalized), kArrayProto_forEach, None);
}

// ObjectTemplate - set property with attributes
void v8_ObjectTemplate_SetWithAttributes(
    Global<ObjectTemplate>* tpl,
    Global<String>* name,
    Global<Value>* value,
    int attributes
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    Local<String> key = name->Get(isolate);
    Local<Value> val = value->Get(isolate);
    local_tpl->Set(key, val, static_cast<PropertyAttribute>(attributes));
}

// ObjectTemplate - set FunctionTemplate property with attributes
// Used by GlobalTemplateRegistry to attach interface constructors to the global template
// FunctionTemplate is a subclass of Template, not Value, so we need a separate function
void v8_ObjectTemplate_SetFunctionTemplate(
    Global<ObjectTemplate>* tpl,
    Global<String>* name,
    Global<FunctionTemplate>* func_tpl,
    int attributes
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    Local<String> key = name->Get(isolate);
    Local<FunctionTemplate> local_func_tpl = func_tpl->Get(isolate);
    // Use ObjectTemplate::Set(Local<Name>, Local<Data>, PropertyAttribute)
    // FunctionTemplate is a Template, which inherits from Data
    local_tpl->Set(key, local_func_tpl, static_cast<PropertyAttribute>(attributes));
}

// ObjectTemplate - set internal field count
void v8_ObjectTemplate_SetInternalFieldCount(Global<ObjectTemplate>* tpl, int count) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    local_tpl->SetInternalFieldCount(count);
}

// ObjectTemplate - mark prototype as immutable
// This makes Object.setPrototypeOf(obj, newProto) throw TypeError
// when newProto !== Object.getPrototypeOf(obj)
// Required for WebIDL global objects (Window, WorkerGlobalScope)
void v8_ObjectTemplate_SetImmutableProto(Global<ObjectTemplate>* tpl) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    local_tpl->SetImmutableProto();
}

// ObjectTemplate - mark as undetectable
// Per ECMA-262, objects with [[IsHTMLDDA]] internal slot are "undetectable":
// - typeof returns "undefined"
// - == null and == undefined return true
// - ToBoolean returns false
// This is used for document.all (HTMLAllCollection).
// Spec: https://tc39.es/ecma262/#sec-IsHTMLDDA-internal-slot
void v8_ObjectTemplate_MarkAsUndetectable(Global<ObjectTemplate>* tpl) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    local_tpl->MarkAsUndetectable();
}

// Mark an ObjectTemplate's instances as "code-like" (TC39 Dynamic Code Brand
// Checks, [[HostDefinedIsCodeLike]]): eval and the Function constructors then
// pass them to the host's code generation check as code (V8's is_code_like),
// not as strings. Used for TrustedScript (Trusted Types: a TrustedScript is
// code-like, so CSP's EnsureCSPDoesNotBlockStringCompilation skips its
// Trusted Types check for it).
void v8_ObjectTemplate_SetCodeLike(Global<ObjectTemplate>* tpl) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    local_tpl->SetCodeLike();
}

// ObjectTemplate - set call-as-function handler
// This allows instances to be called like functions.
// Required for objects marked as undetectable (like document.all).
// The callback is invoked when instances are called with ().
void v8_ObjectTemplate_SetCallAsFunctionHandler(
    Global<ObjectTemplate>* tpl,
    FunctionCallback callback,
    void* data
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    Local<Value> callback_data = data ? Local<Value>(External::New(isolate, data, kCraneExternalTag)) : Local<Value>();
    local_tpl->SetCallAsFunctionHandler(callback, callback_data);
}

// Callback types for accessors (using Name instead of String for modern V8 API)
typedef void (*AccessorNameGetterCallback)(Local<Name> property, const PropertyCallbackInfo<Value>& info);
// V8 >= 14's native data property setter takes the info a setter gets,
// PropertyCallbackInfo<Boolean> (v8::AccessorNameSetterCallbackV2); the <void>
// one is deprecated. Named for this file so it is not v8's own typedef's twin.
using CraneAccessorNameSetterCallback = AccessorNameSetterCallbackV2;

// ObjectTemplate - set accessor (getter/setter) using SetNativeDataProperty
void v8_ObjectTemplate_SetAccessor(
    Global<ObjectTemplate>* tpl,
    Global<String>* name,
    AccessorNameGetterCallback getter,
    CraneAccessorNameSetterCallback setter,
    Global<Value>* data
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    Local<String> key = name->Get(isolate);
    Local<Value> local_data = data ? data->Get(isolate) : Local<Value>();
    
    local_tpl->SetNativeDataProperty(key, getter, setter, local_data);
}

// ObjectTemplate - set accessor property (creates visible accessor descriptor)
// This version creates a FunctionTemplate for the getter/setter, making them
// visible in Object.getOwnPropertyDescriptor as { get: [Function], set: [Function] }
//
// Uses FunctionCallback directly (same as methods) to avoid PropertyCallbackInfo issues.
// Getter: receives no arguments, returns value via info.GetReturnValue()
// Setter: receives new value as info[0], sets it on the object
// Per WebIDL spec, getter functions must have name "get <propname>" and setter "set <propname>"
void v8_ObjectTemplate_SetAccessorPropertyChecked(
    Global<ObjectTemplate>* tpl,
    Global<String>* name,
    FunctionCallback getter,
    FunctionCallback setter,
    bool getter_accepts_any_receiver,
    bool setter_accepts_any_receiver,
    int attributes
);

void v8_ObjectTemplate_SetAccessorProperty(
    Global<ObjectTemplate>* tpl,
    Global<String>* name,
    FunctionCallback getter,
    FunctionCallback setter
) {
    v8_ObjectTemplate_SetAccessorPropertyChecked(tpl, name, getter, setter, true, true, PropertyAttribute::None);
}

/// v8_ObjectTemplate_SetAccessorProperty, and for each of the two functions
/// whether it accepts any receiver (FunctionTemplate::SetAcceptAnyReceiver).
/// One that does not runs WebIDL's "perform a security check" (HTML 7.2.1.1)
/// before its callback: V8 asks the receiver's access check
/// (IsPlatformObjectSameOrigin) for a WindowProxy or Location of another
/// realm, and a failed check throws (the isolate's failed-access-check
/// callback: a SecurityError) [cross_origin_objects]. `attributes` are the
/// property's (PropertyAttribute): DontDelete for a [LegacyUnforgeable]
/// attribute on an instance template.
void v8_ObjectTemplate_SetAccessorPropertyChecked(
    Global<ObjectTemplate>* tpl,
    Global<String>* name,
    FunctionCallback getter,
    FunctionCallback setter,
    bool getter_accepts_any_receiver,
    bool setter_accepts_any_receiver,
    int attributes
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    Local<String> key = name->Get(isolate);
    
    // Get property name as UTF-8 for building "get <name>" / "set <name>"
    String::Utf8Value prop_name_utf8(isolate, key);
    const char* prop_name = *prop_name_utf8;
    
    // Create FunctionTemplate for getter using the callback directly
    // No wrapping or casting needed - FunctionCallback is the native type
    Local<FunctionTemplate> getter_tpl = FunctionTemplate::New(
        isolate,
        getter,
        Local<Value>()  // No data needed
    );
    
    // Per WebIDL spec, getter function name must be "get <attribute name>"
    // Build the getter name: "get " + property name
    std::string getter_name = std::string("get ") + prop_name;
    Local<String> getter_name_str = String::NewFromUtf8(
        isolate, getter_name.c_str(), NewStringType::kNormal
    ).ToLocalChecked();
    getter_tpl->SetClassName(getter_name_str);

    // Per WebIDL spec, getter.length should be 0
    getter_tpl->SetLength(0);
    getter_tpl->SetAcceptAnyReceiver(getter_accepts_any_receiver);

    // Create FunctionTemplate for setter (if provided)
    Local<FunctionTemplate> setter_tpl;
    if (setter != nullptr) {
        setter_tpl = FunctionTemplate::New(
            isolate,
            setter,
            Local<Value>()  // No data needed
        );

        // Per WebIDL spec, setter function name must be "set <attribute name>"
        std::string setter_name = std::string("set ") + prop_name;
        Local<String> setter_name_str = String::NewFromUtf8(
            isolate, setter_name.c_str(), NewStringType::kNormal
        ).ToLocalChecked();
        setter_tpl->SetClassName(setter_name_str);

        // Per WebIDL spec, setter.length should be 1
        setter_tpl->SetLength(1);
        setter_tpl->SetAcceptAnyReceiver(setter_accepts_any_receiver);
    }
    
    // Set as accessor property with proper attributes
    // PropertyAttribute::None means enumerable=true, configurable=true (WebIDL default)
    local_tpl->SetAccessorProperty(
        key.As<Name>(),
        getter_tpl,
        setter ? setter_tpl : Local<FunctionTemplate>(),
        static_cast<PropertyAttribute>(attributes)
    );
}

// v8::Intercepted as V8 defines it, for the Zig side's pin (ffi.Intercepted;
// tests/v8/v8up_interceptor_contract_test.zig). The Zig callbacks return the
// enum by value, so its width and both constants must be V8's: V8 8f35dec9947
// (2026-01-30, "[ic] Introduce CallNamedInterceptorGetter builtin", in 15.7)
// redefined it from `uint8_t { kNo = 0, kYes = 1 }` to
// `uint32_t { kNo = 1, kYes = 0 }`, and a header compile cannot see a Zig enum.
uint32_t v8_Intercepted_Value(bool yes) {
    return static_cast<uint32_t>(yes ? Intercepted::kYes : Intercepted::kNo);
}

size_t v8_Intercepted_Size() {
    return sizeof(Intercepted);
}

// ObjectTemplate - set named property handler (intercepts all property access)
// Using V8's callback types - these use the modern Intercepted return type
void v8_ObjectTemplate_SetNamedPropertyHandler(
    Global<ObjectTemplate>* tpl,
    NamedPropertyGetterCallback getter,
    NamedPropertySetterCallbackV2 setter,
    NamedPropertyQueryCallback query,
    NamedPropertyDeleterCallback deleter,
    NamedPropertyEnumeratorCallback enumerator,
    Global<Value>* data
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    Local<Value> local_data = data ? data->Get(isolate) : Local<Value>();
    
    // V8 NamedPropertyHandlerConfiguration constructor takes 9 parameters:
    // 7 callbacks (getter, setter, query, deleter, enumerator, definer, descriptor)
    // + data + flags
    local_tpl->SetHandler(NamedPropertyHandlerConfiguration(
        getter,
        setter,
        query,
        deleter,
        enumerator,
        nullptr,  // definer callback (not needed for lazy properties)
        nullptr,  // descriptor callback (not needed for lazy properties)
        local_data,
        PropertyHandlerFlags::kNone
    ));
}

// Named property handler with enumerator and descriptor support for legacy platform objects
// Uses Intercepted return type for query/descriptor callbacks to properly handle missing properties
typedef Intercepted (*InterceptedNamedQueryCallback)(Local<Name> property, const PropertyCallbackInfo<Integer>&);
typedef Intercepted (*InterceptedNamedDescriptorCallback)(Local<Name> property, const PropertyCallbackInfo<Value>&);

void v8_ObjectTemplate_SetNamedPropertyHandlerFull(
    Global<ObjectTemplate>* tpl,
    NamedPropertyGetterCallback getter,
    NamedPropertySetterCallbackV2 setter,
    InterceptedNamedQueryCallback query,
    NamedPropertyDeleterCallback deleter,
    NamedPropertyEnumeratorCallback enumerator,
    InterceptedNamedDescriptorCallback descriptor,
    PropertyHandlerFlags flags
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    
    local_tpl->SetHandler(NamedPropertyHandlerConfiguration(
        getter,
        setter,
        query,
        deleter,
        enumerator,
        nullptr,  // definer callback (see SetNamedPropertyHandlerWithDefiner for definer support)
        descriptor,
        Local<Value>(),  // data
        flags
    ));
}

// Named definer callback type for [[DefineOwnProperty]] trap on named properties
// Per WebIDL spec, accessor descriptors must throw TypeError
typedef Intercepted (*InterceptedNamedDefinerCallback)(
    Local<Name> property,
    const PropertyDescriptor& desc,
    const PropertyCallbackInfo<Boolean>& info);

// Named property handler with definer support for [[DefineOwnProperty]] per WebIDL §3.9.3
void v8_ObjectTemplate_SetNamedPropertyHandlerWithDefiner(
    Global<ObjectTemplate>* tpl,
    NamedPropertyGetterCallback getter,
    NamedPropertySetterCallbackV2 setter,
    InterceptedNamedQueryCallback query,
    NamedPropertyDeleterCallback deleter,
    NamedPropertyEnumeratorCallback enumerator,
    InterceptedNamedDefinerCallback definer,
    InterceptedNamedDescriptorCallback descriptor,
    PropertyHandlerFlags flags
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    
    local_tpl->SetHandler(NamedPropertyHandlerConfiguration(
        getter,
        setter,
        query,
        deleter,
        enumerator,
        definer,  // definer callback for Object.defineProperty() per WebIDL §3.9.3
        descriptor,
        Local<Value>(),  // data
        flags
    ));
}

// ObjectTemplate - set indexed property handler (for array-like access: obj[0], obj[1], etc.)
void v8_ObjectTemplate_SetIndexedPropertyHandler(
    Global<ObjectTemplate>* tpl,
    IndexedPropertyGetterCallback getter
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    
    local_tpl->SetHandler(IndexedPropertyHandlerConfiguration(
        getter,
        nullptr,  // setter callback (read-only for now)
        nullptr,  // query callback (not needed)
        nullptr,  // deleter callback (not needed)
        nullptr,  // enumerator callback (not needed)
        nullptr,  // definer callback (not needed)
        nullptr,  // descriptor callback (not needed)
        Local<Value>(),  // data (not needed)
        PropertyHandlerFlags::kNone
    ));
}

// IndexedPropertyEnumeratorCallbackV2 matches V8's expected signature
using IndexedPropertyEnumeratorCallbackV2 = void (*)(const PropertyCallbackInfo<Array>&);

// ObjectTemplate - set indexed property handler with enumerator (for array-like access with Reflect.ownKeys support)
void v8_ObjectTemplate_SetIndexedPropertyHandlerWithEnumerator(
    Global<ObjectTemplate>* tpl,
    IndexedPropertyGetterCallback getter,
    IndexedPropertyEnumeratorCallbackV2 enumerator
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    
    local_tpl->SetHandler(IndexedPropertyHandlerConfiguration(
        getter,
        nullptr,  // setter callback (read-only for now)
        nullptr,  // query callback (not needed)
        nullptr,  // deleter callback (not needed)
        enumerator,  // enumerator callback for Reflect.ownKeys
        nullptr,  // definer callback (not needed)
        nullptr,  // descriptor callback (not needed)
        Local<Value>(),  // data (not needed)
        PropertyHandlerFlags::kNone
    ));
}

// ObjectTemplate - set indexed property handler with full support (getter, setter, query, enumerator, descriptor)
// Uses V8's indexed property callback types with Intercepted return type
// Our Zig callbacks return Intercepted (u8 enum) to match V8's expectations
typedef Intercepted (*InterceptedIndexedQueryCallback)(uint32_t index, const PropertyCallbackInfo<Integer>&);
typedef Intercepted (*InterceptedIndexedDescriptorCallback)(uint32_t index, const PropertyCallbackInfo<Value>&);

// Forward declaration for setter callback type (defined below)
typedef Intercepted (*InterceptedIndexedSetterCallbackFull)(
    uint32_t index,
    Local<Value> value,
    const PropertyCallbackInfo<Boolean>& info);

void v8_ObjectTemplate_SetIndexedPropertyHandlerFull(
    Global<ObjectTemplate>* tpl,
    IndexedPropertyGetterCallback getter,
    InterceptedIndexedSetterCallbackFull setter,
    InterceptedIndexedQueryCallback query,
    IndexedPropertyEnumeratorCallbackV2 enumerator,
    InterceptedIndexedDescriptorCallback descriptor
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    
    // Callbacks now match V8's expected Intercepted return type
    local_tpl->SetHandler(IndexedPropertyHandlerConfiguration(
        getter,
        setter,   // setter callback for obj[index] = value (throws TypeError for read-only)
        query,    // query callback (returns Intercepted)
        nullptr,  // deleter callback (not needed)
        enumerator,  // enumerator callback for Reflect.ownKeys
        nullptr,  // definer callback (not needed)
        descriptor,  // descriptor callback (returns Intercepted)
        Local<Value>(),  // data (not needed)
        PropertyHandlerFlags::kNone
    ));
}

// Definer callback type for [[DefineOwnProperty]] trap
// Per WebIDL spec, accessor descriptors must throw TypeError
// Data descriptors work only if interface supports indexed setter
typedef Intercepted (*InterceptedIndexedDefinerCallback)(
    uint32_t index,
    const PropertyDescriptor& desc,
    const PropertyCallbackInfo<Boolean>& info);

// Setter callback type for indexed properties
typedef Intercepted (*InterceptedIndexedSetterCallback)(
    uint32_t index,
    Local<Value> value,
    const PropertyCallbackInfo<Boolean>& info);

// ObjectTemplate - set indexed property handler with definer support
// This enables proper [[DefineOwnProperty]] handling per WebIDL spec
void v8_ObjectTemplate_SetIndexedPropertyHandlerWithDefiner(
    Global<ObjectTemplate>* tpl,
    IndexedPropertyGetterCallback getter,
    InterceptedIndexedSetterCallback setter,
    InterceptedIndexedQueryCallback query,
    IndexedPropertyDeleterCallback deleter,
    IndexedPropertyEnumeratorCallbackV2 enumerator,
    InterceptedIndexedDefinerCallback definer,
    InterceptedIndexedDescriptorCallback descriptor
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    
    // Full indexed property handler configuration with definer support
    local_tpl->SetHandler(IndexedPropertyHandlerConfiguration(
        getter,
        setter,      // setter callback for obj[index] = value
        query,       // query callback (returns Intercepted)
        deleter,     // deleter callback: WebIDL 3.9.4 [[Delete]]
        enumerator,  // enumerator callback for Reflect.ownKeys
        definer,     // definer callback for Object.defineProperty()
        descriptor,  // descriptor callback (returns Intercepted)
        Local<Value>(),  // data (not needed)
        PropertyHandlerFlags::kNone
    ));
}

// ObjectTemplate - create instance from template
Global<Object>* v8_ObjectTemplate_NewInstance(Global<ObjectTemplate>* tpl, Global<Context>* context) {
    g_obj_src[5].fetch_add(1, std::memory_order_relaxed);
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    Local<Context> local_ctx = context->Get(isolate);
    Context::Scope context_scope(local_ctx);
    
    MaybeLocal<Object> maybe_obj = local_tpl->NewInstance(local_ctx);
    if (maybe_obj.IsEmpty()) {
        return nullptr;
    }
    return trackHandle(new Global<Object>(isolate, maybe_obj.ToLocalChecked()));
}

// PropertyCallbackInfo - get isolate
Isolate* v8_PropertyCallbackInfo_GetIsolate(const PropertyCallbackInfo<Value>* info) {
    return info->GetIsolate();
}

// PropertyCallbackInfo (void) - get isolate (for setters)
Isolate* v8_PropertyCallbackInfo_Boolean_GetIsolate(const PropertyCallbackInfo<Boolean>* info) {
    return info->GetIsolate();
}

// PropertyCallbackInfo - the aligned pointer in internal field `index` of the
// object that has the interceptor (HolderV2), or nullptr when it has no such
// field. That object is WebIDL's O for a legacy platform object's [[Get]] and
// [[HasProperty]]: `list[i]` asks the list, and so does `heir[i]` for an
// object whose prototype is the list (ES OrdinaryGet hands the lookup to the
// prototype with the heir as receiver; This() is then the heir, which has no
// fields). An interceptor's holder is the API object the interceptor is on -
// never a JS proxy: a legacy platform object's proxy forwards to its target,
// and the target is the holder.
//
// No Global and no HandleScope: the holder is a slot of the callback's
// arguments, and an indexed getter runs once per `list[i]` (~1e8 times in
// dom/nodes/NodeList-static-length-getter-tampered-*.html), where
// v8_PropertyCallbackInfo_This's Global - made, tracked and disposed per call
// - was a third of the read (gc_bench profile, 2026-10-11).
void* v8_PropertyCallbackInfo_HolderInstance(const PropertyCallbackInfo<Value>* info) {
    // The holder's instance: its platform anchor's, or - a node interface's
    // holder (Document's named properties, a form's or a select's indexed
    // ones) - its node anchor's; a realm's global's is its field.
    return instanceOfObject(info->GetIsolate(), info->Holder());
}

// A deleter interceptor's answer, the value `delete` evaluates to (WebIDL
// 3.9.4 [[Delete]]): set in the return slot, no handle. V8 throws nothing for
// false; a strict-mode caller's TypeError is the interceptor's to throw
// (v8-template.h, NamedPropertyDeleterCallback).
void v8_PropertyCallbackInfo_SetReturnValueBool(const PropertyCallbackInfo<Boolean>* info, bool value) {
    info->GetReturnValue().Set(value);
}

// A definer or setter interceptor's "return false" (WebIDL 3.9.3
// [[DefineOwnProperty]]): V8 makes it Object.defineProperty's TypeError, or
// Reflect.defineProperty's false (js-objects.cc OrdinaryDefineOwnProperty:
// InterceptorResult::kFalse -> CannotCreateProperty with should_throw).
void v8_PropertyCallbackInfo_Boolean_SetFalse(const PropertyCallbackInfo<Boolean>* info) {
    info->GetReturnValue().SetFalse();
}

// WebIDL 3.9.7 "named property visibility algorithm", the questions about O
// - the legacy platform object an interceptor runs for, its holder - for the
// name `units` (UTF-16: a DOMString's lone surrogates kept):
//   bit 0, step 2: "If O has an own property named P";
//   bit 1, steps 4-5: whether a prototype on O's chain has an own property
//   named P (never a named properties object here: a [Global]'s named
//   properties have no such interceptors).
// "Real" properties skip interceptors, so O's named properties count for
// neither. Blink asks the prototype chain the same way
// (bind_gen/interface.py, the named setter with [LegacyOverrideBuiltIns]:
// GetRealNamedPropertyAttributesInPrototypeChain).
uint8_t v8_LegacyPlatformObject_NamedPropertyState(const PropertyCallbackInfo<Value>* info, const uint16_t* units, int count) {
    Isolate* isolate = info->GetIsolate();
    HandleScope handle_scope(isolate);
    Local<Context> context = isolate->GetCurrentContext();
    Local<Object> holder = info->Holder();
    Local<String> name;
    if (!String::NewFromTwoByte(isolate, units, NewStringType::kNormal, count).ToLocal(&name)) return 0;
    uint8_t bits = 0;
    if (holder->HasRealNamedProperty(context, name).FromMaybe(false)) bits |= 1;
    if (holder->GetRealNamedPropertyAttributesInPrototypeChain(context, name).IsJust()) bits |= 2;
    return bits;
}

// PropertyCallbackInfo - whether the return value set so far is undefined.
// Reads the return slot; makes no handle.
bool v8_PropertyCallbackInfo_ReturnValueIsUndefined(const PropertyCallbackInfo<Value>* info) {
    return info->GetReturnValue().Get()->IsUndefined();
}

// PropertyCallbackInfo<Integer> - set a query interceptor's answer, the
// property's attributes (a v8::PropertyAttribute): a Smi written into the
// return slot, where v8_Integer_New made a Global per call.
void v8_PropertyCallbackInfo_SetReturnValueInt32(const PropertyCallbackInfo<Integer>* info, int32_t value) {
    // Attributes fit 16 bits: Set(int16_t) is a Smi with no range test (see
    // v8_FunctionCallbackInfo_SetReturnValueInt32).
    if (value >= INT16_MIN && value <= INT16_MAX) {
        info->GetReturnValue().Set(static_cast<int16_t>(value));
    } else {
        info->GetReturnValue().Set(value);
    }
}

// PropertyCallbackInfo - the object that has the interceptor or accessor.
// V8 >= 14 gives a property callback no receiver: PropertyCallbackInfo::This()
// is gone (24eb3c4ba35, "Remove deprecated v8::PropertyCallbackInfo<T>::This()";
// HolderV2 became Holder, 3d66b2bdda7). WebIDL's legacy platform object
// algorithms ask O, which is the holder ([[GetOwnProperty]] 3.9.1, [[Set]] 3.9.2
// step 1: V8 calls a setter, definer or deleter interceptor only when the holder
// is the receiver - objects.cc SetPropertyInternal, HolderIsReceiverOrHiddenPrototype),
// and for a property on the global object Holder() is the global proxy, the
// WindowProxy (v8-function-callback.h). Blink reads info.Holder() the same way.
// Returns nullptr if not available (e.g., accessing property on prototype).
Global<Object>* v8_PropertyCallbackInfo_Holder(const PropertyCallbackInfo<Value>* info) {
    g_obj_src[1].fetch_add(1, std::memory_order_relaxed);
    Isolate* isolate = info->GetIsolate();
    HandleScope handle_scope(isolate);
    Local<Object> holder = info->Holder();
    if (holder.IsEmpty()) return nullptr;
    return trackHandle(new Global<Object>(isolate, holder));
}

// A setter, definer or deleter's info (PropertyCallbackInfo<Boolean> in V8 >= 14)
// - get holder (v8_PropertyCallbackInfo_Holder says why the holder)
Global<Object>* v8_PropertyCallbackInfo_Boolean_Holder(const PropertyCallbackInfo<Boolean>* info) {
    g_obj_src[1].fetch_add(1, std::memory_order_relaxed);
    Isolate* isolate = info->GetIsolate();
    HandleScope handle_scope(isolate);
    Local<Object> holder = info->Holder();
    if (holder.IsEmpty()) return nullptr;
    return trackHandle(new Global<Object>(isolate, holder));
}

// PropertyCallbackInfo - set return value. The Global's value is written into
// the return slot (ReturnValue::Set(const Global&)): no Local, so no
// HandleScope - this runs once per interceptor answer, `list[i]` included.
// The caller keeps the handle; nothing here retains it.
void v8_PropertyCallbackInfo_SetReturnValue(const PropertyCallbackInfo<Value>* info, Global<Value>* value) {
    if (!value || value->IsEmpty()) {
        info->GetReturnValue().SetUndefined();
        return;
    }

    info->GetReturnValue().Set(*value);
}

// PropertyCallbackInfo - set return value to undefined
void v8_PropertyCallbackInfo_SetUndefined(const PropertyCallbackInfo<Value>* info) {
    Isolate* isolate = info->GetIsolate();
    HandleScope handle_scope(isolate);
    info->GetReturnValue().SetUndefined();
}

// Whether a [[Set]], [[DefineOwnProperty]] or [[Delete]] interceptor should
// throw (strict mode). Only those ask, and V8 >= 14 answers only for the
// instantiation it calls them with: PropertyCallbackInfo<T>::ShouldThrowOnError
// is `if constexpr (!HasShouldThrowOnError()) return false;` unless T is Boolean
// or void (v8-function-callback.h:720) - a PropertyCallbackInfo<Value> would
// say false in strict mode too. So the info is read as the Boolean one V8
// passes setters, definers and deleters (the same pointer the Zig callback got).
bool v8_PropertyCallbackInfo_ShouldThrowOnError(const PropertyCallbackInfo<Boolean>* info) {
    return info->ShouldThrowOnError();
}

// A setter or definer's info - check if errors should throw (strict mode)
// Returns true if we're in strict mode and should throw TypeError on failure
bool v8_PropertyCallbackInfo_Boolean_ShouldThrowOnError(const PropertyCallbackInfo<Boolean>* info) {
    return info->ShouldThrowOnError();
}

// ============================================================================
// Name Functions  
// ============================================================================

bool v8_Name_IsString(const void* name) {
    // CRITICAL INSIGHT: V8 callback passes Local<Name> BY VALUE, which at the C ABI level
    // means the pointer inside Local<Name> is what gets passed.
    // This pointer points to a V8 internal object.
    // We can safely cast this to Value* and call IsString() through operator->
    
    // The `name` parameter is the internal pointer from Local<Name>.
    // In V8's implementation, calling operator-> on a Local<> returns the internal pointer.
    // So we can treat `name` as if it were the result of local_name.operator->()
    
    const Value* value = reinterpret_cast<const Value*>(name);
    return value->IsString();
}

// Object internal field functions for raw/local pointers (from callbacks)
// Used in property interceptors where we have Local<Object> not Global<Object>
// String functions for raw pointers (from callbacks)
int v8_String_Utf8Length_Raw(const void* str) {
    Isolate* isolate = Isolate::GetCurrent();
    // str is the internal V8 String pointer
    const String* string_ptr = reinterpret_cast<const String*>(str);
    return string_ptr->Utf8Length(isolate);
}

int v8_String_WriteUtf8_Raw(const void* str, char* buffer, int length) {
    Isolate* isolate = Isolate::GetCurrent();
    const String* string_ptr = reinterpret_cast<const String*>(str);
    return writeUtf8NulIfRoom(isolate, string_ptr, buffer, length);
}

// Number value extraction for raw pointers (from callbacks/anyopaque)
// This works with Global<Value>* handles that are passed through as void*
double v8_Value_NumberValue_Raw(const void* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    // The value is a Global<Value>* passed as void*
    const Global<Value>* global_value = reinterpret_cast<const Global<Value>*>(value);
    Local<Value> val = global_value->Get(isolate);
    
    // Get the current context
    Local<Context> ctx = isolate->GetCurrentContext();
    
    Maybe<double> maybe_num = val->NumberValue(ctx);
    return maybe_num.FromMaybe(std::nan(""));
}

// String length extraction for raw pointers (from callbacks/anyopaque)
// Returns -1 if not a string, otherwise returns UTF-8 byte length
int v8_Value_StringLength_Raw(const void* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    const Global<Value>* global_value = reinterpret_cast<const Global<Value>*>(value);
    Local<Value> val = global_value->Get(isolate);
    
    if (!val->IsString()) {
        return -1;
    }
    
    Local<String> str = val.As<String>();
    return str->Utf8Length(isolate);
}

// String value extraction for raw pointers (from callbacks/anyopaque)
// Writes UTF-8 to buffer, returns bytes written. buffer_len should include space for null terminator.
int v8_Value_StringWriteUtf8_Raw(const void* value, char* buffer, int buffer_len) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    const Global<Value>* global_value = reinterpret_cast<const Global<Value>*>(value);
    Local<Value> val = global_value->Get(isolate);
    
    if (!val->IsString()) {
        if (buffer_len > 0) buffer[0] = '\0';
        return 0;
    }
    
    Local<String> str = val.As<String>();
    if (buffer_len <= 0) return 0;
    return static_cast<int>(str->WriteUtf8(isolate, buffer, static_cast<size_t>(buffer_len)));
}

// ============================================================================
// Object Property Descriptor Functions
// ============================================================================

bool v8_Object_DefineProperty(Global<Object>* object, Global<Context>* context, Global<Value>* key,
                               Global<Value>* value, bool writable, bool enumerable, bool configurable) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Object> obj = object->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<Name> name = key->Get(isolate).As<Name>();
    Local<Value> val = value->Get(isolate);
    
    // Create property descriptor
    v8::PropertyAttribute attributes = v8::None;
    if (!writable) attributes = static_cast<v8::PropertyAttribute>(attributes | v8::ReadOnly);
    if (!enumerable) attributes = static_cast<v8::PropertyAttribute>(attributes | v8::DontEnum);
    if (!configurable) attributes = static_cast<v8::PropertyAttribute>(attributes | v8::DontDelete);
    
    return obj->DefineOwnProperty(ctx, name, val, attributes).FromMaybe(false);
}

// Set an accessor property (getter/setter) on an existing V8 Object
// This is used to make Window properties own properties of the global object
// so that Object.getOwnPropertyDescriptor(window, "name") returns { get: [Function], set: [Function] }
bool v8_Object_SetAccessorPropertyChecked(
    Global<Object>* object,
    Global<Context>* context,
    Global<String>* name,
    FunctionCallback getter,
    FunctionCallback setter,
    bool getter_accepts_any_receiver,
    bool setter_accepts_any_receiver,
    int attributes
);

bool v8_Object_SetAccessorProperty(
    Global<Object>* object,
    Global<Context>* context,
    Global<String>* name,
    FunctionCallback getter,
    FunctionCallback setter
) {
    return v8_Object_SetAccessorPropertyChecked(object, context, name, getter, setter, true, true, None);
}

/// v8_Object_SetAccessorProperty with v8_ObjectTemplate_SetAccessorPropertyChecked's
/// receiver flags: a function that does not accept any receiver runs WebIDL's
/// security check first [cross_origin_objects].
bool v8_Object_SetAccessorPropertyChecked(
    Global<Object>* object,
    Global<Context>* context,
    Global<String>* name,
    FunctionCallback getter,
    FunctionCallback setter,
    bool getter_accepts_any_receiver,
    bool setter_accepts_any_receiver,
    int attributes
) {
    Isolate* isolate = Isolate::GetCurrent();
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);
    
    Local<Object> obj = object->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<String> key = name->Get(isolate);
    Context::Scope context_scope(ctx);
    
    // Get property name as UTF-8 for building "get <name>" / "set <name>"
    String::Utf8Value prop_name_utf8(isolate, key);
    const char* prop_name = *prop_name_utf8;
    
    // Create getter function
    Local<Function> getter_func;
    if (getter != nullptr) {
        Local<FunctionTemplate> getter_tpl = FunctionTemplate::New(isolate, getter);
        std::string getter_name = std::string("get ") + prop_name;
        Local<String> getter_name_str = String::NewFromUtf8(
            isolate, getter_name.c_str(), NewStringType::kNormal
        ).ToLocalChecked();
        getter_tpl->SetClassName(getter_name_str);
        // Per WebIDL spec, getter.length should be 0
        getter_tpl->SetLength(0);
        getter_tpl->SetAcceptAnyReceiver(getter_accepts_any_receiver);
        getter_func = getter_tpl->GetFunction(ctx).ToLocalChecked();
    }

    // Create setter function
    Local<Function> setter_func;
    if (setter != nullptr) {
        Local<FunctionTemplate> setter_tpl = FunctionTemplate::New(isolate, setter);
        std::string setter_name = std::string("set ") + prop_name;
        Local<String> setter_name_str = String::NewFromUtf8(
            isolate, setter_name.c_str(), NewStringType::kNormal
        ).ToLocalChecked();
        setter_tpl->SetClassName(setter_name_str);
        // Per WebIDL spec, setter.length should be 1
        setter_tpl->SetLength(1);
        setter_tpl->SetAcceptAnyReceiver(setter_accepts_any_receiver);
        setter_func = setter_tpl->GetFunction(ctx).ToLocalChecked();
    }
    
    // For accessor properties, V8 PropertyDescriptor requires getter/setter to be
    // either a function OR undefined (not empty). For missing setter, use Undefined.
    Local<Value> getter_value = getter ? Local<Value>(getter_func) : Undefined(isolate).As<Value>();
    Local<Value> setter_value = setter ? Local<Value>(setter_func) : Undefined(isolate).As<Value>();

    PropertyDescriptor desc(getter_value, setter_value);
    desc.set_enumerable((attributes & DontEnum) == 0);
    desc.set_configurable((attributes & DontDelete) == 0);

    // Define the property on the object
    return obj->DefineProperty(ctx, key.As<Name>(), desc).FromMaybe(false);
}

// Create a property descriptor object for Object.getOwnPropertyDescriptor callbacks
// Returns an object like: { value: <value>, writable: <bool>, enumerable: <bool>, configurable: <bool> }
// Takes a Global<Value>* for the value parameter - caller must ensure value is a valid global handle
//
// `value` may be the wrapper cache's own handle, held WEAKLY (a platform
// object's wrapper, made a moment ago and reachable from nothing yet): it is
// read into a Local BEFORE anything allocates, since an allocation can start
// a collection that takes the wrapper and resets that very handle
// (docs/lessons/architecture-a-weakly-held-wrapper-dies-at-the-next-allocation.md).
// Returns nullptr when it is empty.
Global<Object>* v8_CreateDataPropertyDescriptor(
    Global<Context>* context,
    Global<Value>* value,
    bool writable,
    bool enumerable,
    bool configurable
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    if (!value || value->IsEmpty()) return nullptr;
    Local<Value> val = value->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);
    
    // WebIDL 3.9.7 LegacyPlatformObjectGetOwnProperty's "newly created
    // Property Descriptor": a record. V8 takes it from an interceptor as an
    // object and reads it back with ToPropertyDescriptor - HasProperty and
    // Get of each field - so the object has NO prototype and its fields are
    // own data properties made by CreateDataProperty. An ordinary object
    // filled by [[Set]] was the page's to change: a `get` on
    // Object.prototype made every index's and name's descriptor "Invalid
    // property descriptor. Cannot both specify accessors and a value", and a
    // setter there named "value" was called instead of the field being made
    // (lane wrap1 b2, finding 3; the cross-origin descriptors below were
    // already made this way, NewCrossOriginDescriptor).
    Local<Object> desc = Object::New(isolate, Null(isolate), nullptr, nullptr, 0);
    auto field = [&](const char* name, Local<Value> field_value) {
        desc->CreateDataProperty(ctx, String::NewFromUtf8(isolate, name, NewStringType::kInternalized).ToLocalChecked(), field_value).Check();
    };
    field("value", val);
    field("writable", Boolean::New(isolate, writable));
    field("enumerable", Boolean::New(isolate, enumerable));
    field("configurable", Boolean::New(isolate, configurable));

    return trackHandle(new Global<Object>(isolate, desc));
}

// ============================================================================
// PropertyDescriptor Helper Functions
// For use with indexed/named property definer callbacks
// ============================================================================

// Check if a PropertyDescriptor is an accessor descriptor (has get or set)
bool v8_PropertyDescriptor_IsAccessorDescriptor(const PropertyDescriptor* desc) {
    // PropertyDescriptor* desc is passed from V8's definer callback
    // V8's PropertyDescriptor has has_get(), has_set(), has_value()
    return desc->has_get() || desc->has_set();
}

// ES 6.2.6.2 IsDataDescriptor: a descriptor with a [[Value]] or a
// [[Writable]] field ({writable: true} is one; {} and an accessor are not).
bool v8_PropertyDescriptor_IsDataDescriptor(const PropertyDescriptor* desc) {
    return desc->has_value() || desc->has_writable();
}

// Get the value from a data PropertyDescriptor
// Returns nullptr if the descriptor doesn't have a value
Global<Value>* v8_PropertyDescriptor_GetValue(const PropertyDescriptor* desc) {
    if (!desc->has_value()) {
        return nullptr;
    }
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = desc->value();
    if (val.IsEmpty()) {
        return nullptr;
    }
    return new Global<Value>(isolate, val);
}

// Check if PropertyDescriptor has a configurable field specified
bool v8_PropertyDescriptor_HasConfigurable(const PropertyDescriptor* desc) {
    return desc->has_configurable();
}

// Get the configurable value from PropertyDescriptor
bool v8_PropertyDescriptor_Configurable(const PropertyDescriptor* desc) {
    return desc->configurable();
}

// Check if PropertyDescriptor has an enumerable field specified
bool v8_PropertyDescriptor_HasEnumerable(const PropertyDescriptor* desc) {
    return desc->has_enumerable();
}

// Get the enumerable value from PropertyDescriptor
bool v8_PropertyDescriptor_Enumerable(const PropertyDescriptor* desc) {
    return desc->enumerable();
}

// Check if PropertyDescriptor has a writable field specified
bool v8_PropertyDescriptor_HasWritable(const PropertyDescriptor* desc) {
    return desc->has_writable();
}

// Get the writable value from PropertyDescriptor
bool v8_PropertyDescriptor_Writable(const PropertyDescriptor* desc) {
    return desc->writable();
}

// Set an object's prototype as immutable
bool v8_Object_SetImmutableProto(Global<Object>* object, Global<Context>* context) {
    if (!object || !context) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Object> obj = object->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    // Per V8 documentation, SetImmutableProto is only available on templates.
    // To make an EXISTING object have an immutable prototype, we can use 
    // Proxy or other techniques, but for normal objects V8 doesn't 
    // expose a public API to set this bit once created.
    
    // However, for the Global object, we set it via template.
    // For Window.prototype, we'll try to use a Proxy wrapper if needed, 
    // but first let's see if we can just use the template.
    return true; 
}

// ============================================================================
// Object Prototype Functions
// ============================================================================

bool v8_Object_SetPrototype(Global<Object>* object, Global<Context>* context, Global<Value>* prototype) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);

    Local<Object> obj = object->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<Value> proto = prototype->Get(isolate);

    return obj->SetPrototype(ctx, proto).FromMaybe(false);
}

/// Set the prototype of an object using SetPrototypeV2.
/// This is the newer API that works properly with global objects (JSGlobalObject).
/// The old SetPrototype is deprecated for global objects.
bool v8_Object_SetPrototypeV2(Global<Object>* object, Global<Context>* context, Global<Value>* prototype) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);

    Local<Object> obj = object->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<Value> proto = prototype->Get(isolate);

    return obj->SetPrototype(ctx, proto).FromMaybe(false);
}

Global<Value>* v8_Object_GetPrototype(Global<Object>* object) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Object> obj = object->Get(isolate);
    Local<Value> proto = obj->GetPrototype();
    
    if (proto.IsEmpty()) {
        return nullptr;
    }
    
    return new Global<Value>(isolate, proto);
}

/// The [[Prototype]] script sees. On a global proxy, GetPrototype() answers
/// with the hidden JSGlobalObject behind it, and handing that to
/// SetPrototypeV2 is a V8 CHECK failure ("from_javascript implies
/// !i::IsJSGlobalObject(*self)"); GetPrototypeV2() skips it.
Global<Value>* v8_Object_GetPrototypeV2(Global<Object>* object) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Object> obj = object->Get(isolate);
    Local<Value> proto = obj->GetPrototype();
    if (proto.IsEmpty()) {
        return nullptr;
    }
    return new Global<Value>(isolate, proto);
}

// ============================================================================
// Lazy Data Property Functions
// ============================================================================

// Set a lazy data property on an object. The getter callback is called on first
// access, and the property is then replaced with the returned value (becoming a
// regular data property). This is used for lazy interface constructor installation.
//
// This matches Chromium's pattern in idl_member_installer.cc for installing
// interface constructors on the global object.
void v8_Object_SetLazyDataProperty(
    Global<Object>* object,
    Global<Context>* context,
    Global<Name>* name,
    AccessorNameGetterCallback getter,
    Global<Value>* data
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Object> obj = object->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<Name> prop_name = name->Get(isolate);
    Local<Value> prop_data = data ? data->Get(isolate) : Local<Value>();
    
    // Use DontEnum to match browser behavior (constructors aren't enumerable)
    obj->SetLazyDataProperty(
        ctx,
        prop_name,
        getter,
        prop_data,
        static_cast<PropertyAttribute>(v8::DontEnum)
    );
}

// ============================================================================
// Object Extensibility Functions
// ============================================================================

bool v8_Object_PreventExtensions(Global<Object>* object, Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);
    
    Local<Object> obj = object->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    return obj->SetIntegrityLevel(ctx, v8::IntegrityLevel::kSealed).FromMaybe(false);
}

// ============================================================================
// Symbol Functions
// ============================================================================

Global<Symbol>* v8_Symbol_GetToStringTag(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Symbol> symbol = Symbol::GetToStringTag(isolate);
    return trackHandle(new Global<Symbol>(isolate, symbol));
}

Global<Symbol>* v8_Symbol_GetIterator(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Symbol> symbol = Symbol::GetIterator(isolate);
    return trackHandle(new Global<Symbol>(isolate, symbol));
}

Global<Symbol>* v8_Symbol_GetAsyncIterator(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Symbol> symbol = Symbol::GetAsyncIterator(isolate);
    return trackHandle(new Global<Symbol>(isolate, symbol));
}

Global<Symbol>* v8_Symbol_GetUnscopables(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Symbol> symbol = Symbol::GetUnscopables(isolate);
    return trackHandle(new Global<Symbol>(isolate, symbol));
}

void v8_Symbol_Dispose(Global<Symbol>* symbol) {
    // Snapshot mode: trackHandle queued this handle for bulk cleanup (see
    // v8_ObjectTemplate_Dispose), so deleting it here too is a double free.
    if (g_snapshot_mode) return;
    releaseWeakArm(symbol);
    delete symbol;  // ~Global resets the handle
}

Global<Value>* v8_Object_GetPropertyWithSymbol(
    Global<Context>* context,
    Global<Object>* obj,
    Global<Symbol>* symbol
) {
    CHECK_ALIGNMENT_LOG(context, Global<Context>, "v8_Object_GetPropertyWithSymbol");
    CHECK_ALIGNMENT_LOG(obj, Global<Object>, "v8_Object_GetPropertyWithSymbol");
    CHECK_ALIGNMENT_LOG(symbol, Global<Symbol>, "v8_Object_GetPropertyWithSymbol");
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Object> object = obj->Get(isolate);
    Local<Symbol> sym = symbol->Get(isolate);
    
    MaybeLocal<Value> result = object->Get(ctx, sym);
    if (result.IsEmpty()) {
        return nullptr;
    }
    
    return trackHandle(new Global<Value>(isolate, result.ToLocalChecked()));
}

bool v8_Object_Has(
    Global<Context>* context,
    Global<Object>* obj,
    const char* key
) {
    Isolate* isolate = Isolate::GetCurrent();
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Object> object = obj->Get(isolate);
    Local<String> key_str = String::NewFromUtf8(isolate, key).ToLocalChecked();
    
    Maybe<bool> result = object->Has(ctx, key_str);
    return result.FromMaybe(false);
}

Global<Value>* v8_Function_CallWithReceiver(
    Global<Context>* context,
    Global<Function>* function,
    Global<Value>* receiver,
    int argc,
    Global<Value>** argv
) {
    CHECK_ALIGNMENT_LOG(context, Global<Context>, "v8_Function_CallWithReceiver");
    CHECK_ALIGNMENT_LOG(function, Global<Function>, "v8_Function_CallWithReceiver");
    CHECK_ALIGNMENT_LOG(receiver, Global<Value>, "v8_Function_CallWithReceiver");
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Function> fn = function->Get(isolate);
    Local<Value> recv = receiver ? receiver->Get(isolate) : Undefined(isolate).As<Value>();
    
    std::vector<Local<Value>> args;
    args.reserve(argc);
    for (int i = 0; i < argc; i++) {
        CHECK_ALIGNMENT_LOG(argv[i], Global<Value>, "v8_Function_CallWithReceiver[argv]");
        args.push_back(argv[i]->Get(isolate));
    }
    
    MaybeLocal<Value> result = fn->Call(ctx, recv, argc, args.data());
    if (result.IsEmpty()) {
        return nullptr;
    }
    
    return trackHandle(new Global<Value>(isolate, result.ToLocalChecked()));
}

// ============================================================================
// Microtask Functions (Event Loop Integration)
// ============================================================================

/// Enqueue a microtask callback
///
/// Microtasks are high-priority tasks that run before the next JavaScript task.
/// This is used for promise reactions, mutation observers, etc.
///
/// The callback will be invoked with the provided data pointer.
/// The caller is responsible for managing the lifetime of data.
void v8_Isolate_EnqueueMicrotask(
    Isolate* isolate,
    void (*callback)(void*),
    void* data
) {
    // V8 expects a C function pointer, not a C++ lambda
    isolate->EnqueueMicrotask(callback, data);
}

/// Perform a microtask checkpoint
///
/// This runs all pending microtasks to completion. If microtasks enqueue
/// additional microtasks, those are also executed before returning.
///
/// This implements "perform a microtask checkpoint" from HTML spec:
/// https://html.spec.whatwg.org/#perform-a-microtask-checkpoint
void v8_Isolate_PerformMicrotaskCheckpoint(Isolate* isolate) {
    isolate->PerformMicrotaskCheckpoint();
}

/// Set the microtasks policy for the isolate
///
/// - kExplicit: Microtasks must be explicitly run via PerformMicrotaskCheckpoint
/// - kScoped: Microtasks run automatically at the end of each MicrotasksScope
/// - kAuto: Microtasks run automatically (deprecated, use kScoped)
///
/// Default is kAuto for backward compatibility.
/// For embedder control, use kExplicit.
void v8_Isolate_SetMicrotasksPolicy(Isolate* isolate, int policy) {
    MicrotasksPolicy v8_policy;
    switch (policy) {
        case 0: v8_policy = MicrotasksPolicy::kExplicit; break;
        case 1: v8_policy = MicrotasksPolicy::kScoped; break;
        case 2: v8_policy = MicrotasksPolicy::kAuto; break;
        default: return;  // Invalid policy
    }
    isolate->SetMicrotasksPolicy(v8_policy);
}

// ============================================================================
// Promise Rejection Tracking (for unhandledrejection/rejectionhandled events)
// ============================================================================

/// promise.[[PromiseIsHandled]] (HTML "notify about rejected promises" step
/// 4.1.1 and HostPromiseRejectionTracker). False for a non-promise.
bool v8_Promise_HasHandler(Global<Value>* promise) {
    if (!promise || promise->IsEmpty()) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> value = promise->Get(isolate);
    if (!value->IsPromise()) return false;
    return value.As<Promise>()->HasHandler();
}

/// Call `callback(isolate, data)` after every microtask checkpoint on the
/// isolate's default queue - automatic (kAuto) and explicit alike, including
/// checkpoints that found the queue empty (MicrotaskQueue::OnCompleted).
/// HTML performs "notify about rejected promises" at the end of each
/// microtask checkpoint; this is where that hooks in.
void v8_Isolate_AddMicrotasksCompletedCallback(Isolate* isolate, void (*callback)(Isolate*, void*), void* data) {
    isolate->AddMicrotasksCompletedCallback(callback, data);
}

void v8_Isolate_RemoveMicrotasksCompletedCallback(Isolate* isolate, void (*callback)(Isolate*, void*), void* data) {
    isolate->RemoveMicrotasksCompletedCallback(callback, data);
}

// ============================================================================
// Function Call Support (Phase 1: Runtime Callback Infrastructure)
// ============================================================================

/// Call a JavaScript function from native code
///
/// This enables Zig to invoke JavaScript callbacks, which is essential for
/// Streams API callbacks (write_algorithm, pull_algorithm, etc.).
///
/// @param function - The JavaScript function to call
/// @param context - The V8 context in which to execute the call
/// @param recv - The 'this' value for the function call (use v8_Undefined for no 'this')
/// @param argc - Number of arguments to pass
/// @param argv - Array of argument values
/// @return The return value from the function call, or nullptr if an exception occurred
Global<Value>* v8_Function_Call(
    Global<Function>* function,
    Global<Context>* context,
    Global<Value>* recv,
    int argc,
    Global<Value>** argv
) {
    CHECK_ALIGNMENT_LOG(function, Global<Function>, "v8_Function_Call");
    CHECK_ALIGNMENT_LOG(context, Global<Context>, "v8_Function_Call");
    CHECK_ALIGNMENT_LOG(recv, Global<Value>, "v8_Function_Call");

    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);

    // Convert Global handles to Local handles
    Local<Function> fn = function->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<Value> this_val = recv->Get(isolate);

    // Convert argument array from Global to Local
    Local<Value>* local_argv = new Local<Value>[argc];
    for (int i = 0; i < argc; i++) {
        CHECK_ALIGNMENT_LOG(argv[i], Global<Value>, "v8_Function_Call[argv]");
        local_argv[i] = argv[i]->Get(isolate);
    }

    // Call the function
    TryCatch try_catch(isolate);
    MaybeLocal<Value> maybe_result = fn->Call(ctx, this_val, argc, local_argv);

    // Clean up local argument array
    delete[] local_argv;

    // Check for exception
    if (try_catch.HasCaught()) {
        Local<Value> exception = try_catch.Exception();
        String::Utf8Value exception_str(isolate, exception);
        fprintf(stderr, "[v8_Function_Call] EXCEPTION: %s\n", *exception_str);

        // Get stack trace if available
        MaybeLocal<Value> maybe_stack = try_catch.StackTrace(ctx);
        if (!maybe_stack.IsEmpty()) {
            String::Utf8Value stack_str(isolate, maybe_stack.ToLocalChecked());
            fprintf(stderr, "[v8_Function_Call] Stack: %s\n", *stack_str);
        }
        return nullptr;
    }

    if (maybe_result.IsEmpty()) {
        fprintf(stderr, "[v8_Function_Call] Result is empty but no exception?\n");
        return nullptr;  // Exception occurred
    }

    // Return the result as a Global handle
    Local<Value> result = maybe_result.ToLocalChecked();
    return trackHandle(new Global<Value>(isolate, result));
}

// ============================================================================
// Function::NewInstance - Create object via constructor (sets up prototype chain)
// ============================================================================

/// Create a new instance of a function (like calling `new Func()`)
/// This properly sets up the prototype chain, unlike ObjectTemplate::NewInstance()
Global<Object>* v8_Function_NewInstance(
    Global<Function>* function,
    Global<Context>* context,
    int argc,
    Global<Value>** argv
) {
    Isolate* isolate = Isolate::GetCurrent();
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);
    Local<Function> func = function->Get(isolate);
    
    // Convert argv to Local<Value> array
    std::vector<Local<Value>> local_argv;
    if (argc > 0 && argv != nullptr) {
        local_argv.reserve(argc);
        for (int i = 0; i < argc; i++) {
            local_argv.push_back(argv[i]->Get(isolate));
        }
    }
    
    MaybeLocal<Object> maybe_obj = func->NewInstance(ctx, argc, argc > 0 ? local_argv.data() : nullptr);
    if (maybe_obj.IsEmpty()) {
        return nullptr;
    }
    
    return trackHandle(new Global<Object>(isolate, maybe_obj.ToLocalChecked()));
}

// ============================================================================
// Promise API (Phase 2: Runtime Callback Infrastructure  
// ============================================================================

/// Create a new Promise resolver
Global<Promise::Resolver>* v8_PromiseResolver_New(Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    MaybeLocal<Promise::Resolver> maybe_resolver = Promise::Resolver::New(ctx);
    if (maybe_resolver.IsEmpty()) {
        return nullptr;
    }
    
    Local<Promise::Resolver> resolver = maybe_resolver.ToLocalChecked();
    return trackHandle(new Global<Promise::Resolver>(isolate, resolver));
}

/// Get Promise from resolver
Global<Promise>* v8_PromiseResolver_GetPromise(Global<Promise::Resolver>* resolver) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Promise::Resolver> res = resolver->Get(isolate);
    Local<Promise> promise = res->GetPromise();
    return trackHandle(new Global<Promise>(isolate, promise));
}

/// Resolve a Promise with a value
bool v8_PromiseResolver_Resolve(
    Global<Promise::Resolver>* resolver,
    Global<Context>* context,
    Global<Value>* value
) {
    Isolate* isolate = Isolate::GetCurrent();
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);
    
    Local<Promise::Resolver> res = resolver->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<Value> val = value->Get(isolate);
    
    Maybe<bool> result = res->Resolve(ctx, val);
    return result.FromMaybe(false);
}

/// Reject a Promise with a reason
bool v8_PromiseResolver_Reject(
    Global<Promise::Resolver>* resolver,
    Global<Context>* context,
    Global<Value>* reason
) {
    Isolate* isolate = Isolate::GetCurrent();
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);
    
    Local<Promise::Resolver> res = resolver->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<Value> val = reason->Get(isolate);
    
    Maybe<bool> result = res->Reject(ctx, val);
    return result.FromMaybe(false);
}

/// Chain a .then() handler to a Promise
Global<Promise>* v8_Promise_Then(
    Global<Promise>* promise,
    Global<Context>* context,
    Global<Function>* on_fulfilled,
    Global<Function>* on_rejected
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Promise> prom = promise->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<Function> fulfilled = on_fulfilled ? on_fulfilled->Get(isolate) : Local<Function>();
    Local<Function> rejected = on_rejected ? on_rejected->Get(isolate) : Local<Function>();
    
    MaybeLocal<Promise> maybe_result = prom->Then(ctx, fulfilled, rejected);
    if (maybe_result.IsEmpty()) {
        return nullptr;
    }
    
    Local<Promise> result = maybe_result.ToLocalChecked();
    return trackHandle(new Global<Promise>(isolate, result));
}

/// Chain a .catch() handler to a Promise
Global<Promise>* v8_Promise_Catch(
    Global<Promise>* promise,
    Global<Context>* context,
    Global<Function>* on_rejected
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Promise> prom = promise->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<Function> rejected = on_rejected->Get(isolate);
    
    MaybeLocal<Promise> maybe_result = prom->Catch(ctx, rejected);
    if (maybe_result.IsEmpty()) {
        return nullptr;
    }
    
    Local<Promise> result = maybe_result.ToLocalChecked();
    return trackHandle(new Global<Promise>(isolate, result));
}

/// Dispose a Promise
void v8_Promise_Dispose(Global<Promise>* promise) {
    // Snapshot mode: trackHandle queued this handle for bulk cleanup (see
    // v8_ObjectTemplate_Dispose), so deleting it here too is a double free.
    if (g_snapshot_mode) return;
    if (promise) {
        forgetCountedHandle(promise);
        releaseWeakArm(promise);
        promise->Reset();
        delete promise;
    }
}

/// Get the state of a Promise
/// Returns: 0 = Pending, 1 = Fulfilled, 2 = Rejected
int v8_Promise_State(Global<Promise>* promise) {
    if (!promise) return 0;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Promise> prom = promise->Get(isolate);
    return static_cast<int>(prom->State());
}

/// Get the result of a settled Promise (fulfilled value or rejection reason)
/// Returns nullptr if the promise is still pending
Global<Value>* v8_Promise_Result(Global<Promise>* promise) {
    if (!promise) return nullptr;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Promise> prom = promise->Get(isolate);
    
    // Only get result if promise is settled (not pending)
    if (prom->State() == Promise::kPending) {
        return nullptr;
    }
    
    Local<Value> result = prom->Result();
    return trackHandle(new Global<Value>(isolate, result));
}

/// Dispose a PromiseResolver
void v8_PromiseResolver_Dispose(Global<Promise::Resolver>* resolver) {
    // Snapshot mode: trackHandle queued this handle for bulk cleanup (see
    // v8_ObjectTemplate_Dispose), so deleting it here too is a double free.
    if (g_snapshot_mode) return;
    if (resolver) {
        forgetCountedHandle(resolver);
        releaseWeakArm(resolver);
        resolver->Reset();
        delete resolver;
    }
}

// ============================================================================
// Promise Handler Creation (Phase 3: Callback Utilities)
// ============================================================================

/// Create a function that resolves a PromiseResolver
///
/// Returns a JavaScript function that, when called, resolves the given
/// PromiseResolver with its first argument.
///
/// Used for chaining Promises: source.then(createResolveHandler(target))
Global<Function>* v8_PromiseResolver_CreateResolveHandler(
    Global<Context>* context,
    Global<Promise::Resolver>* resolver
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    // Create External to hold resolver pointer
    // NOTE: We're storing a raw pointer - caller must ensure resolver outlives handler
    Local<External> data = External::New(isolate, resolver, kCraneExternalTag);
    
    // Create callback that resolves the PromiseResolver
    auto callback = [](const FunctionCallbackInfo<Value>& info) {
        Isolate* isolate = info.GetIsolate();
        HandleScope scope(isolate);
        
        // Extract resolver from data
        Local<External> external = Local<External>::Cast(info.DataV2().As<Value>());
        auto* resolver = static_cast<Global<Promise::Resolver>*>(external->Value(kCraneExternalTag));
        
        // Get value argument (or undefined if no args)
        Local<Value> value = info.Length() > 0 ? info[0] : Undefined(isolate).As<Value>();
        
        // Resolve the Promise
        Local<Promise::Resolver> res = resolver->Get(isolate);
        Local<Context> ctx = isolate->GetCurrentContext();
        Maybe<bool> result = res->Resolve(ctx, value);
        
        // Return undefined
        info.GetReturnValue().SetUndefined();
    };
    
    // Create FunctionTemplate
    Local<FunctionTemplate> tpl = FunctionTemplate::New(isolate, callback, data);
    MaybeLocal<Function> maybe_fn = tpl->GetFunction(ctx);
    if (maybe_fn.IsEmpty()) {
        return nullptr;
    }
    
    Local<Function> fn = maybe_fn.ToLocalChecked();
    return trackHandle(new Global<Function>(isolate, fn));
}

/// Create a function that rejects a PromiseResolver
///
/// Returns a JavaScript function that, when called, rejects the given
/// PromiseResolver with its first argument.
///
/// Used for chaining Promises: source.catch(createRejectHandler(target))
Global<Function>* v8_PromiseResolver_CreateRejectHandler(
    Global<Context>* context,
    Global<Promise::Resolver>* resolver
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    // Create External to hold resolver pointer
    Local<External> data = External::New(isolate, resolver, kCraneExternalTag);
    
    // Create callback that rejects the PromiseResolver
    auto callback = [](const FunctionCallbackInfo<Value>& info) {
        Isolate* isolate = info.GetIsolate();
        HandleScope scope(isolate);
        
        // Extract resolver from data
        Local<External> external = Local<External>::Cast(info.DataV2().As<Value>());
        auto* resolver = static_cast<Global<Promise::Resolver>*>(external->Value(kCraneExternalTag));
        
        // Get reason argument (or undefined if no args)
        Local<Value> reason = info.Length() > 0 ? info[0] : Undefined(isolate).As<Value>();
        
        // Reject the Promise
        Local<Promise::Resolver> res = resolver->Get(isolate);
        Local<Context> ctx = isolate->GetCurrentContext();
        Maybe<bool> result = res->Reject(ctx, reason);
        
        // Return undefined
        info.GetReturnValue().SetUndefined();
    };
    
    // Create FunctionTemplate
    Local<FunctionTemplate> tpl = FunctionTemplate::New(isolate, callback, data);
    MaybeLocal<Function> maybe_fn = tpl->GetFunction(ctx);
    if (maybe_fn.IsEmpty()) {
        return nullptr;
    }
    
    Local<Function> fn = maybe_fn.ToLocalChecked();
    return trackHandle(new Global<Function>(isolate, fn));
}

// ============================================================================
// Zig Callback Bridge for Promise Handlers
// ============================================================================

/// Type definition for Zig promise fulfill callback
/// Signature: fn(context: *anyopaque, value: ?*anyopaque) void
typedef void (*ZigPromiseFulfillCallback)(void* context, void* value);

/// Type definition for Zig promise reject callback  
/// Signature: fn(context: *anyopaque, reason: ?*anyopaque) void
typedef void (*ZigPromiseRejectCallback)(void* context, void* reason);

/// Data structure to hold Zig callback info
struct ZigPromiseCallbackData {
    ZigPromiseFulfillCallback fulfill_callback;
    ZigPromiseRejectCallback reject_callback;
    void* fulfill_context;
    void* reject_context;
};

/// Create a V8 Function that invokes a Zig fulfill callback when called
///
/// When the returned function is called (e.g., from Promise.then()), it will:
/// 1. Extract the first argument (or undefined)
/// 2. Call the Zig fulfill_callback with the context and argument
///
/// Arguments:
///   - context: V8 Context
///   - fulfill_callback: Zig function to call on fulfillment
///   - fulfill_context: Context pointer to pass to Zig callback
///
/// Returns:
///   - Global<Function>* that invokes the Zig callback, or nullptr on failure
Global<Function>* v8_CreateZigFulfillHandler(
    Global<Context>* context,
    ZigPromiseFulfillCallback fulfill_callback,
    void* fulfill_context
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    // Allocate callback data
    auto* data = new ZigPromiseCallbackData{
        fulfill_callback,
        nullptr,
        fulfill_context,
        nullptr
    };
    
    // Store in External
    Local<External> external = External::New(isolate, data, kCraneExternalTag);
    
    // Create callback that invokes the Zig function
    auto callback = [](const FunctionCallbackInfo<Value>& info) {
        Isolate* isolate = info.GetIsolate();
        HandleScope scope(isolate);
        
        // Extract callback data
        Local<External> external = Local<External>::Cast(info.DataV2().As<Value>());
        auto* data = static_cast<ZigPromiseCallbackData*>(external->Value(kCraneExternalTag));
        
        if (data && data->fulfill_callback) {
            // Get value argument (or nullptr if no args/undefined)
            void* value = nullptr;
            if (info.Length() > 0 && !info[0]->IsUndefined()) {
                // Store the Local<Value> as a Global for Zig to use
                // The Zig side will need to handle this appropriately
                value = new Global<Value>(isolate, info[0]);
            }
            
            // Call Zig callback
            data->fulfill_callback(data->fulfill_context, value);
        }
        
        // Return undefined
        info.GetReturnValue().SetUndefined();
    };
    
    // Create FunctionTemplate
    Local<FunctionTemplate> tpl = FunctionTemplate::New(isolate, callback, external);
    MaybeLocal<Function> maybe_fn = tpl->GetFunction(ctx);
    if (maybe_fn.IsEmpty()) {
        delete data;
        return nullptr;
    }
    
    Local<Function> fn = maybe_fn.ToLocalChecked();
    return trackHandle(new Global<Function>(isolate, fn));
}

/// Create a V8 Function that invokes a Zig reject callback when called
///
/// When the returned function is called (e.g., from Promise.catch()), it will:
/// 1. Extract the first argument (rejection reason, or undefined)
/// 2. Call the Zig reject_callback with the context and reason
///
/// Arguments:
///   - context: V8 Context
///   - reject_callback: Zig function to call on rejection
///   - reject_context: Context pointer to pass to Zig callback
///
/// Returns:
///   - Global<Function>* that invokes the Zig callback, or nullptr on failure
Global<Function>* v8_CreateZigRejectHandler(
    Global<Context>* context,
    ZigPromiseRejectCallback reject_callback,
    void* reject_context
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    // Allocate callback data
    auto* data = new ZigPromiseCallbackData{
        nullptr,
        reject_callback,
        nullptr,
        reject_context
    };
    
    // Store in External
    Local<External> external = External::New(isolate, data, kCraneExternalTag);
    
    // Create callback that invokes the Zig function
    auto callback = [](const FunctionCallbackInfo<Value>& info) {
        Isolate* isolate = info.GetIsolate();
        HandleScope scope(isolate);
        
        // Extract callback data
        Local<External> external = Local<External>::Cast(info.DataV2().As<Value>());
        auto* data = static_cast<ZigPromiseCallbackData*>(external->Value(kCraneExternalTag));
        
        if (data && data->reject_callback) {
            // Get reason argument (or nullptr if no args/undefined)
            void* reason = nullptr;
            if (info.Length() > 0 && !info[0]->IsUndefined()) {
                // Store the Local<Value> as a Global for Zig to use
                reason = new Global<Value>(isolate, info[0]);
            }
            
            // Call Zig callback
            data->reject_callback(data->reject_context, reason);
        }
        
        // Return undefined
        info.GetReturnValue().SetUndefined();
    };
    
    // Create FunctionTemplate
    Local<FunctionTemplate> tpl = FunctionTemplate::New(isolate, callback, external);
    MaybeLocal<Function> maybe_fn = tpl->GetFunction(ctx);
    if (maybe_fn.IsEmpty()) {
        delete data;
        return nullptr;
    }
    
    Local<Function> fn = maybe_fn.ToLocalChecked();
    return trackHandle(new Global<Function>(isolate, fn));
}

/// Dispose a Zig callback handler function
///
/// This frees both the V8 Global<Function> and the ZigPromiseCallbackData.
/// Must be called when the handler is no longer needed.
void v8_DisposeZigCallbackHandler(Global<Function>* handler) {
    if (handler) {
        // Note: We can't easily access the callback data from here to free it,
        // so it will be leaked. In a real implementation, we'd need weak callbacks
        // or a different architecture. For now, the data is small and persistent
        // for the lifetime of the stream.
        releaseWeakArm(handler);
        handler->Reset();
        delete handler;
    }
}

// ============================================================================
// ArrayBuffer API (Phase 4: Runtime Infrastructure)
// ============================================================================

/// Create a new ArrayBuffer
///
/// Allocates a V8 ArrayBuffer with the specified byte length.
/// Caller must call v8_ArrayBuffer_Dispose when done.
Global<ArrayBuffer>* v8_ArrayBuffer_New(Isolate* isolate, size_t byte_length) {
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> buffer = ArrayBuffer::New(isolate, byte_length);
    return trackHandle(new Global<ArrayBuffer>(isolate, buffer));
}

/// Get ArrayBuffer backing store pointer
///
/// Returns a pointer to the raw memory backing the ArrayBuffer.
/// Valid only while the ArrayBuffer is not detached.
void* v8_ArrayBuffer_Data(Global<ArrayBuffer>* buffer) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> buf = buffer->Get(isolate);
    
    // Get backing store
    std::shared_ptr<BackingStore> backing_store = buf->GetBackingStore();
    if (!backing_store) {
        return nullptr;
    }
    return backing_store->Data();
}

/// Get ArrayBuffer byte length
size_t v8_ArrayBuffer_ByteLength(Global<ArrayBuffer>* buffer) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> buf = buffer->Get(isolate);
    return buf->ByteLength();
}

/// Check if ArrayBuffer is detached
bool v8_ArrayBuffer_IsDetached(Global<ArrayBuffer>* buffer) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> buf = buffer->Get(isolate);
    return buf->WasDetached();
}

/// Detach an ArrayBuffer
///
/// Transfers ownership of the backing store, making the ArrayBuffer unusable.
/// Used for transferable ArrayBuffers in postMessage and structured clone.
void v8_ArrayBuffer_Detach(Global<ArrayBuffer>* buffer) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> buf = buffer->Get(isolate);
    
    // Detach with no key (nullptr indicates default detach)
    Maybe<bool> result = buf->Detach(Local<Value>());
    (void)result; // Ignore result for now
}

/// Dispose ArrayBuffer
void v8_ArrayBuffer_Dispose(Global<ArrayBuffer>* buffer) {
    // Snapshot mode: trackHandle queued this handle for bulk cleanup (see
    // v8_ObjectTemplate_Dispose), so deleting it here too is a double free.
    if (g_snapshot_mode) return;
    if (buffer) {
        releaseWeakArm(buffer);
        buffer->Reset();
        delete buffer;
    }
}

// ============================================================================
// TypedArray API (Phase 4: ArrayBufferView Introspection)
// ============================================================================

/// Check if Value is a Uint8Array
bool v8_Value_IsUint8Array(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsUint8Array();
}

/// Check if Value is an Int8Array
bool v8_Value_IsInt8Array(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsInt8Array();
}

/// Check if Value is a Uint16Array
bool v8_Value_IsUint16Array(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsUint16Array();
}

/// Check if Value is an Int16Array
bool v8_Value_IsInt16Array(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsInt16Array();
}

/// Check if Value is a Uint32Array
bool v8_Value_IsUint32Array(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsUint32Array();
}

/// Check if Value is an Int32Array
bool v8_Value_IsInt32Array(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsInt32Array();
}

/// Check if Value is a Float16Array (ES2025; shipped in V8 13.5)
bool v8_Value_IsFloat16Array(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsFloat16Array();
}

/// Check if Value is a Float32Array
bool v8_Value_IsFloat32Array(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsFloat32Array();
}

/// Check if Value is a Float64Array
bool v8_Value_IsFloat64Array(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsFloat64Array();
}

/// Check if Value is a Uint8ClampedArray
bool v8_Value_IsUint8ClampedArray(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsUint8ClampedArray();
}

/// Check if Value is a BigInt64Array
bool v8_Value_IsBigInt64Array(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsBigInt64Array();
}

/// Check if Value is a BigUint64Array
bool v8_Value_IsBigUint64Array(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsBigUint64Array();
}

/// Check if Value is any TypedArray
bool v8_Value_IsTypedArray(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsTypedArray();
}

/// Check if Value is a DataView
bool v8_Value_IsDataView(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsDataView();
}

/// Get the ArrayBuffer from a TypedArray
///
/// Returns the underlying ArrayBuffer that the TypedArray is viewing.
/// Caller must call v8_ArrayBuffer_Dispose when done.
Global<ArrayBuffer>* v8_TypedArray_Buffer(Global<Value>* typed_array) {
    if (!typed_array) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = typed_array->Get(isolate);
    
    if (!val->IsTypedArray()) {
        return nullptr;
    }
    
    Local<TypedArray> ta = val.As<TypedArray>();
    Local<ArrayBuffer> buffer = ta->Buffer();
    return trackHandle(new Global<ArrayBuffer>(isolate, buffer));
}

/// Get TypedArray byte length
///
/// Returns the number of bytes in the TypedArray view.
/// Returns 0 if the view is detached or invalid.
size_t v8_TypedArray_ByteLength(Global<Value>* typed_array) {
    if (!typed_array) return 0;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = typed_array->Get(isolate);
    
    if (!val->IsTypedArray()) {
        return 0;
    }
    
    Local<TypedArray> ta = val.As<TypedArray>();
    return ta->ByteLength();
}

/// Get TypedArray byte offset
///
/// Returns the offset in bytes from the start of the ArrayBuffer.
size_t v8_TypedArray_ByteOffset(Global<Value>* typed_array) {
    if (!typed_array) return 0;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = typed_array->Get(isolate);
    
    if (!val->IsTypedArray()) {
        return 0;
    }
    
    Local<TypedArray> ta = val.As<TypedArray>();
    return ta->ByteOffset();
}

/// Get TypedArray length (element count)
///
/// Returns the number of elements in the TypedArray.
/// Not the same as ByteLength (ByteLength = Length * ElementSize).
size_t v8_TypedArray_Length(Global<Value>* typed_array) {
    if (!typed_array) return 0;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = typed_array->Get(isolate);
    
    if (!val->IsTypedArray()) {
        return 0;
    }
    
    Local<TypedArray> ta = val.As<TypedArray>();
    return ta->Length();
}

// ============================================================================
// TypedArray Construction
// ============================================================================

/// Create a Uint8Array view over an ArrayBuffer
///
/// @param isolate - V8 isolate
/// @param buffer - The ArrayBuffer to view
/// @param byte_offset - Offset into the buffer
/// @param length - Number of elements (bytes for Uint8Array)
/// @return Global handle to new Uint8Array, or null on error
Global<Value>* v8_Uint8Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Uint8Array> arr = Uint8Array::New(local_buffer, byte_offset, length);
    return trackHandle(new Global<Value>(isolate, arr));
}

/// Create an Int8Array view over an ArrayBuffer
Global<Value>* v8_Int8Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Int8Array> arr = Int8Array::New(local_buffer, byte_offset, length);
    return trackHandle(new Global<Value>(isolate, arr));
}

/// Create a Uint8ClampedArray view over an ArrayBuffer
Global<Value>* v8_Uint8ClampedArray_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Uint8ClampedArray> arr = Uint8ClampedArray::New(local_buffer, byte_offset, length);
    return trackHandle(new Global<Value>(isolate, arr));
}

/// Create a Uint16Array view over an ArrayBuffer
Global<Value>* v8_Uint16Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Uint16Array> arr = Uint16Array::New(local_buffer, byte_offset, length);
    return trackHandle(new Global<Value>(isolate, arr));
}

/// Create an Int16Array view over an ArrayBuffer
Global<Value>* v8_Int16Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Int16Array> arr = Int16Array::New(local_buffer, byte_offset, length);
    return trackHandle(new Global<Value>(isolate, arr));
}

/// Create a Uint32Array view over an ArrayBuffer
Global<Value>* v8_Uint32Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Uint32Array> arr = Uint32Array::New(local_buffer, byte_offset, length);
    return trackHandle(new Global<Value>(isolate, arr));
}

/// Create an Int32Array view over an ArrayBuffer
Global<Value>* v8_Int32Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Int32Array> arr = Int32Array::New(local_buffer, byte_offset, length);
    return trackHandle(new Global<Value>(isolate, arr));
}

/// Create a Float32Array view over an ArrayBuffer
Global<Value>* v8_Float32Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Float32Array> arr = Float32Array::New(local_buffer, byte_offset, length);
    return trackHandle(new Global<Value>(isolate, arr));
}

/// Create a Float64Array view over an ArrayBuffer
Global<Value>* v8_Float64Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Float64Array> arr = Float64Array::New(local_buffer, byte_offset, length);
    return trackHandle(new Global<Value>(isolate, arr));
}

/// Create a BigInt64Array view over an ArrayBuffer
Global<Value>* v8_BigInt64Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<BigInt64Array> arr = BigInt64Array::New(local_buffer, byte_offset, length);
    return trackHandle(new Global<Value>(isolate, arr));
}

/// Create a BigUint64Array view over an ArrayBuffer
Global<Value>* v8_BigUint64Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<BigUint64Array> arr = BigUint64Array::New(local_buffer, byte_offset, length);
    return trackHandle(new Global<Value>(isolate, arr));
}

/// Create a DataView over an ArrayBuffer
Global<Value>* v8_DataView_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t byte_length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<DataView> view = DataView::New(local_buffer, byte_offset, byte_length);
    return trackHandle(new Global<Value>(isolate, view));
}

// ============================================================================
// Weak Callbacks / Finalizers
// ============================================================================

/// Make a Global handle weak with a finalizer callback
///
/// The record this allocates is owned by the arm: `v8_Global_ClearWeak` or the
/// handle's disposal ends it, and until then `armedWeakData` can find it. See
/// the ownership note above `armedWeakData`.
void v8_Global_SetWeak(void* handle, void* user_data, ZigWeakCallbackFn callback) {
    if (!handle || !callback) return;
    
    // Cast to Global<Value>* (all Global types are compatible for SetWeak)
    Global<Value>* global = reinterpret_cast<Global<Value>*>(handle);
    
    // Create wrapper data that holds callback, user data, AND the handle pointer
    // The handle pointer is needed so the weak callback can reset it (V8 requirement)
    WeakCallbackData* wrapper = new WeakCallbackData{callback, user_data, global, Isolate::GetCurrent()};
    armWeakData(handle, wrapper);
    
    // Make the Global handle weak with our wrapper callback
    global->SetWeak(wrapper, WeakCallbackWrapper<Value>, WeakCallbackType::kParameter);
}

/// Make a Global handle weak with a finalizer that runs after the collection:
/// `unlink` (may be null) in V8's first pass - bookkeeping, no V8 API - and
/// `finalize` at the agent's next safe point after it, where engine work is
/// allowed (`runQueuedFinalizers`; the first pass queues it). Disposing the
/// handle before then cancels `finalize` (`releaseWeakArm`). Owned by the
/// arm, as v8_Global_SetWeak's record is.
void v8_Global_SetWeakFinalizer(void* handle, void* user_data, ZigWeakCallbackFn unlink, ZigWeakCallbackFn finalize) {
    if (!handle || !finalize) return;
    Global<Value>* global = reinterpret_cast<Global<Value>*>(handle);
    WeakCallbackData* wrapper = new WeakCallbackData{unlink, user_data, global, Isolate::GetCurrent(), finalize};
    armWeakData(handle, wrapper);
    global->SetWeak(wrapper, WeakCallbackWrapper<Value>, WeakCallbackType::kParameter);
}

/// Clear weak reference and restore strong reference
///
/// `releaseWeakArm` does the `ClearWeak()` itself, because the parameter has to
/// come back with it: `PersistentBase::ClearWeak()` is `ClearWeak<void>()` and
/// drops the record on the floor, which leaked one per call on every DOM
/// wrapper.
///
/// `handle_survives` is what separates this from every other caller: they all
/// `Reset(); delete;` the Global on the next line, and this one hands it back.
/// If V8 has already queued the first-pass callback, that makes this record the
/// only thing left that can reset the node.
void v8_Global_ClearWeak(void* handle) {
    if (!handle) return;

    releaseWeakArm(reinterpret_cast<Global<Value>*>(handle), WeakArmEnd::handle_survives);
}

/// Check if a Global handle is weak
///
/// @param handle - Global handle to check
/// @return true if the handle is weak, false otherwise
bool v8_Global_IsWeak(void* handle) {
    if (!handle) return false;
    
    Global<Value>* global = reinterpret_cast<Global<Value>*>(handle);
    return global->IsWeak();
}

/// Create a weak Global<Value> from a Local<Value>
///
/// This creates a Global handle that is immediately weak. When V8 GC collects
/// the value (no more strong references), the callback is invoked with user_data.
///
/// @param isolate - Current V8 isolate
/// @param local - Local value pointer (from within an active HandleScope)
/// @param user_data - User data to pass to callback on GC
/// @param callback - Function to call when value is garbage collected
/// @return New weak Global<Value>* or nullptr if local is empty
Global<Value>* v8_Value_ToWeakGlobal(
    Isolate* isolate,
    void* local,
    void* user_data,
    ZigWeakCallbackFn callback
) {
    if (!isolate || !local) return nullptr;
    
    HandleScope handle_scope(isolate);
    
    // Cast the void* back to Value* - this is the internal pointer from a Local<Value>
    Value* value_ptr = reinterpret_cast<Value*>(local);
    Local<Value> local_value = *reinterpret_cast<Local<Value>*>(&value_ptr);
    
    if (local_value.IsEmpty()) return nullptr;
    
    // Create the Global handle
    Global<Value>* global = new Global<Value>(isolate, local_value);
    
    // If callback is provided, make it weak immediately
    if (callback != nullptr) {
        // `global`, not a defaulted null: an aggregate initialiser with two
        // members left `handle` null, so the callback skipped V8's mandatory
        // Reset and this Global survived every collection of its own value.
        WeakCallbackData* wrapper = new WeakCallbackData{callback, user_data, global, isolate};
        armWeakData(global, wrapper);
        global->SetWeak(wrapper, WeakCallbackWrapper<Value>, WeakCallbackType::kParameter);
    }
    
    return global;
}

// ============================================================================
// Async Iterator Support
// ============================================================================
//
// What is left of an async iterator object the adapter once made itself
// (v8_AsyncIterator_New, deleted with its process-wide template cache: no
// caller). Its three callbacks stay because the external references table
// registers them (external_references.zig), and a snapshot resolves every
// callback by its index there.

/// Zig async iterator next callback type
/// Returns a V8 Promise that resolves to { value, done }
typedef Global<Promise>* (*ZigAsyncIteratorNextFn)(
    Isolate* isolate,
    Global<Context>* context,
    void* iterator_ptr
);

/// Zig async iterator return callback type
/// Returns a V8 Promise that resolves to { value: undefined, done: true }
typedef Global<Promise>* (*ZigAsyncIteratorReturnFn)(
    Isolate* isolate,
    Global<Context>* context,
    void* iterator_ptr
);

/// Internal storage for async iterator callbacks
struct AsyncIteratorData {
    void* iterator_ptr;              // Zig iterator pointer
    ZigAsyncIteratorNextFn next_fn;  // Callback for next()
    ZigAsyncIteratorReturnFn return_fn; // Callback for return()
};

/// Callback wrapper for async iterator next() method
static void AsyncIteratorNextCallback(const FunctionCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    HandleScope handle_scope(isolate);
    
    // Extract iterator data from function's data (passed via External)
    Local<Value> data_value = info.DataV2().As<Value>();
    if (!data_value->IsExternal()) {
        isolate->ThrowException(Exception::TypeError(
            String::NewFromUtf8Literal(isolate, "Invalid async iterator callback data")
        ));
        return;
    }
    
    Local<External> external = Local<External>::Cast(data_value);
    AsyncIteratorData* data = static_cast<AsyncIteratorData*>(external->Value(kCraneExternalTag));
    

    
    if (!data || !data->next_fn) {
        isolate->ThrowException(Exception::TypeError(
            String::NewFromUtf8Literal(isolate, "Async iterator not properly initialized")
        ));
        return;
    }
    
    // Get current context as Global handle
    // NOTE: Do NOT delete this context handle immediately after calling the Zig function.
    // The Zig code stores this context pointer in a PromiseBridge and uses it later
    // when resolving the promise (in a microtask). Deleting it here causes use-after-free.
    // The context handle will be managed by V8's GC - we intentionally don't delete it.
    Local<Context> local_context = isolate->GetCurrentContext();
    Global<Context>* context = new Global<Context>(isolate, local_context);
    
    // Call Zig next function - it returns a V8 Promise
    Global<Promise>* promise_global = data->next_fn(isolate, context, data->iterator_ptr);
    
    if (!promise_global) {
        isolate->ThrowException(Exception::Error(
            String::NewFromUtf8Literal(isolate, "Iterator next() failed")
        ));
        return;
    }
    
    // Convert Global promise to Local
    Local<Promise> promise = promise_global->Get(isolate);
    
    // Return the promise directly (it already resolves to { value, done })
    info.GetReturnValue().Set(promise);
}

/// Callback wrapper for async iterator return() method
static void AsyncIteratorReturnCallback(const FunctionCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    HandleScope handle_scope(isolate);
    
    // Extract iterator data from function's data (passed via External)
    Local<Value> data_value = info.DataV2().As<Value>();
    if (!data_value->IsExternal()) {
        isolate->ThrowException(Exception::TypeError(
            String::NewFromUtf8Literal(isolate, "Invalid async iterator callback data")
        ));
        return;
    }
    
    Local<External> external = Local<External>::Cast(data_value);
    AsyncIteratorData* data = static_cast<AsyncIteratorData*>(external->Value(kCraneExternalTag));
    
    if (!data || !data->return_fn) {
        isolate->ThrowException(Exception::TypeError(
            String::NewFromUtf8Literal(isolate, "Async iterator not properly initialized")
        ));
        return;
    }
    
    // Get current context as Global handle
    // NOTE: Do NOT delete this context handle immediately after calling the Zig function.
    // Same reason as in AsyncIteratorNextCallback - the context is stored in PromiseBridge.
    Local<Context> local_context = isolate->GetCurrentContext();
    Global<Context>* context = new Global<Context>(isolate, local_context);
    
    // Call Zig return function - it returns a V8 Promise
    Global<Promise>* promise_global = data->return_fn(isolate, context, data->iterator_ptr);
    
    if (!promise_global) {
        isolate->ThrowException(Exception::Error(
            String::NewFromUtf8Literal(isolate, "Iterator return() failed")
        ));
        return;
    }
    
    // Convert Global promise to Local
    Local<Promise> promise = promise_global->Get(isolate);
    
    // Return the promise directly (it already resolves to { value: undefined, done: true })
    info.GetReturnValue().Set(promise);
}

/// Callback for Symbol.asyncIterator - returns 'this' (the iterator itself)
///
/// This makes the async iterator object both an iterator AND an iterable,
/// allowing `for await...of` to work directly on the iterator object.
/// ES spec: https://tc39.es/ecma262/#sec-%asynciteratorprototype%-@@asynciterator
static void AsyncIteratorSelfCallback(const FunctionCallbackInfo<Value>& info) {
    // Return the iterator object itself (this)
    info.GetReturnValue().Set(info.This());
}

// ============================================================================
// TestUtils API - GC for testing (WHATWG TestUtils Standard)
// ============================================================================

/// Request a full garbage collection on the isolate
///
/// This is for testing purposes only and should NOT be exposed to web content.
/// Per WHATWG TestUtils spec: https://testutils.spec.whatwg.org/
///
/// Note: V8's public API does not expose RequestGarbageCollectionForTesting
/// in production builds. We use LowMemoryNotification() which hints to V8
/// that it should perform GC as soon as possible.
///
/// This function is synchronous - LowMemoryNotification triggers immediate GC.
void v8_Isolate_RequestGarbageCollection(Isolate* isolate) {
    if (!isolate) return;
    // The collecting isolate is the current one (collectingRecord).
    CollectingScope collecting(isolate);
    
    // LowMemoryNotification triggers V8 to perform garbage collection
    // as aggressively as possible. Per V8 docs, this is a synchronous
    // call that attempts to reclaim as much memory as possible.
    //
    // A precise collection of the agent's C++ heap: no conservative scan of
    // the stack for its objects. A requested collection is a host's call
    // between its own steps (TestUtils.gc(), a memory-pressure notice, a
    // test), and no frame of Crane holds a C++-heap pointer across one - the
    // node anchors and their registry are held by wrappers and a
    // cppgc::Persistent only, their raw pointers live in v8_wrapper.cpp's
    // frames that never call a collection. A stale pointer the scan found
    // instead kept an anchor, its wrapper and its tree for a cycle
    // (tests/v8/node_wrapper_inline_test.zig). Chromium's web-test collector
    // runs on an empty stack the same way (content/web_test/renderer/
    // gc_controller.cc AsyncCollectAllWithEmptyStack: kNoHeapPointers).
#ifndef NDEBUG
    if (IsolateData* record = isolateData(isolate); record && record->anchors_in_frames != 0) {
        fprintf(stderr, "v8_wrapper: a requested collection with %d frame(s) holding a NodeAnchor*: it is precise for the C++ heap, and would free what they hold\n",
                record->anchors_in_frames);
        abort();
    }
#endif
    if (CppHeap* heap = isolate->GetCppHeap()) {
        cppgc::testing::OverrideEmbedderStackStateScope precise(heap->GetHeapHandle(), cppgc::EmbedderStackState::kNoHeapPointers);
        isolate->LowMemoryNotification();
    } else {
        isolate->LowMemoryNotification();
    }
    // The collection's first pass queued the finalizers of what it found
    // dead, and its weak processing owed the node wrappers' releases
    // (`noteNodeWrappersCollected`): they run now, V8's collector off the
    // stack, so that the caller finds them run as it always did
    // (`runQueuedFinalizers`).
    runQueuedFinalizers(isolate);
}

// ============================================================================
// V8 Snapshot API - Build-Time Heap Serialization
// ============================================================================
//
// This API enables creating V8 heap snapshots that include pre-registered
// WebIDL interfaces. At runtime, loading a snapshot is ~100-1000x faster
// than re-registering all interfaces via FFI calls.
//
// Usage Pattern:
//   Build Time:
//     1. Create SnapshotCreator with external references
//     2. Get the isolate, register all WebIDL interfaces
//     3. Set default context with registered interfaces
//     4. Create blob - returns StartupData with serialized heap
//     5. Save blob to file
//
//   Runtime:
//     1. Load blob from file
//     2. Create isolate from snapshot with same external references
//     3. Create context from snapshot - interfaces are already registered!
//
// CRITICAL: External references (C++ callback pointers) MUST be provided in
// the SAME ORDER at snapshot creation time and loading time.

/// C-compatible StartupData structure for FFI
/// Matches v8::StartupData layout
struct V8StartupData {
    const char* data;
    int raw_size;
};

/// Create a new SnapshotCreator
///
/// The SnapshotCreator owns an isolate that is set up for serialization.
/// The isolate is automatically entered when created.
///
/// @param external_references - Null-terminated array of external reference pointers.
///                              These are C++ callback function pointers that will be
///                              called from snapshotted code. MUST be in same order
///                              at snapshot creation and loading time.
/// @return Opaque pointer to SnapshotCreator (caller owns, must call Dispose)
void* v8_SnapshotCreator_New(const intptr_t* external_references) {
    // The snapshot generator starts V8 first, with its flags
    // (snapshot_loader.initializePlatformForSnapshots); this is the net.
    if (v8_Platform_Start(nullptr) == kPlatformDisposed) return nullptr;

    // Create isolate params with external references
    Isolate::CreateParams params;
    params.array_buffer_allocator = ArrayBuffer::Allocator::NewDefaultAllocator();
    params.external_references = external_references;
    
    // SnapshotCreator creates and enters its own isolate
    SnapshotCreator* creator = new SnapshotCreator(params);
    return creator;
}

/// Get the isolate from a SnapshotCreator
///
/// Use this isolate to set up the global object, register interfaces, etc.
/// The isolate is already entered when returned.
///
/// @param creator - SnapshotCreator handle from v8_SnapshotCreator_New
/// @return The isolate managed by this SnapshotCreator
Isolate* v8_SnapshotCreator_GetIsolate(void* creator) {
    if (!creator) return nullptr;
    SnapshotCreator* sc = static_cast<SnapshotCreator*>(creator);
    return sc->GetIsolate();
}

// =============================================================================
// Snapshot Internal Field Serialization/Deserialization
// =============================================================================
// These callbacks handle serialization of internal fields during snapshot
// creation and restoration. Without these, V8 cannot properly serialize
// objects with internal fields, leading to rehashability errors.

/// Serialize internal fields during snapshot creation
///
/// This callback is invoked by V8 for each object with internal fields.
/// For our minimal snapshots (no WebIDL objects in snapshot), we return
/// empty data to indicate no serialization needed.
StartupData SerializeInternalFields(Local<Object> holder, int index, void* data) {
    // For minimal snapshots without embedded objects, return empty
    // This tells V8 there's nothing to serialize for this field
    return {nullptr, 0};
}

/// Deserialize internal fields during snapshot loading
///
/// This callback is invoked by V8 when restoring objects with internal fields.
/// For our minimal snapshots, we just set the field to nullptr.
void DeserializeInternalFields(Local<Object> holder, int index,
                               StartupData payload, void* data) {
    // For minimal snapshots, set internal field to nullptr
    // WebIDL objects are registered at runtime, not from snapshot
    if (payload.raw_size == 0) {
        holder->SetAlignedPointerInInternalField(index, nullptr, kCraneEmbedderDataTag);
    }
}

/// Whether the snapshot may not hold an API object whose CppHeap pointer is
/// `cpp_heap_pointer`: any that has one. The blob carries templates and
/// intrinsics; an object Wrapped with a C++-heap object - a platform object's
/// wrapper (its PlatformAnchor or NodeAnchor), a realm's global (its
/// GlobalAnchor) - names an instance of this process, which no blob can.
static bool snapshotRefusesApiWrapper(void* cpp_heap_pointer) {
    return cpp_heap_pointer != nullptr;
}

/// The snapshot creator's serializer for API wrappers (v8-snapshot.h
/// SerializeAPIWrapperCallback): V8 calls it for every API object of a
/// context it writes, with the object's CppHeap pointer. It writes nothing,
/// and stops the generator on an object that has one - a guard, not a path:
/// the generator wraps no platform object. Without a serializer V8 calls a
/// null callback for such an object (15.7.112.43
/// src/snapshot/context-serializer.cc:237-252).
/// Blink's aborts likewise on any wrappable but the one kind it expects
/// (bindings/core/v8/v8_context_snapshot_impl.cc).
static StartupData RefuseApiWrapperInSnapshot(Local<Object> holder, void* cpp_heap_pointer, void* data) {
    (void)holder;
    (void)data;
    if (snapshotRefusesApiWrapper(cpp_heap_pointer)) {
        fprintf(stderr, "v8_wrapper: the snapshot would hold an API object wrapped with a C++-heap object - a platform "
                        "object's wrapper, or a realm's global. A blob carries templates and intrinsics only: the "
                        "generator must wrap no platform object in a context it snapshots.\n");
        abort();
    }
    return {nullptr, 0};
}

/// tests/v8/wrap1_platform_anchor_test.zig: whether the snapshot generator
/// refuses to write an API object whose CppHeap pointer is `cpp_heap_pointer`
/// into a blob (RefuseApiWrapperInSnapshot's rule).
extern "C" bool v8_test_SnapshotRefusesApiWrapper(void* cpp_heap_pointer) {
    return snapshotRefusesApiWrapper(cpp_heap_pointer);
}

/// Create a context and set it as default for snapshot
///
/// This function creates a new context using Local handles (not Global) and
/// immediately sets it as the default context for the snapshot. Using Local
/// handles avoids the "global handle not serialized" error during CreateBlob.
///
/// @param creator - SnapshotCreator handle
/// @return true on success, false on failure
bool v8_SnapshotCreator_CreateAndSetDefaultContext(void* creator) {
    if (!creator) {
        fprintf(stderr, "[v8_SnapshotCreator_CreateAndSetDefaultContext] ERROR: creator is null\n");
        return false;
    }
    
    SnapshotCreator* sc = static_cast<SnapshotCreator*>(creator);
    Isolate* isolate = sc->GetIsolate();
    
    HandleScope handle_scope(isolate);
    
    // Create context using Local handle only (no Global)
    Local<Context> context = Context::New(isolate);
    if (context.IsEmpty()) {
        fprintf(stderr, "[v8_SnapshotCreator_CreateAndSetDefaultContext] ERROR: Context::New failed\n");
        return false;
    }
    
    // Enter and exit context (V8 requirement)
    context->Enter();
    context->Exit();
    
    sc->SetDefaultContext(context, SerializeInternalFieldsCallback(), SerializeContextDataCallback(), SerializeAPIWrapperCallback(RefuseApiWrapperInSnapshot));
    return true;
}

/// Create a context and add it to snapshot at index
///
/// This function creates a new context using Local handles (not Global) and
/// immediately adds it to the snapshot's context array. Using Local handles
/// avoids the "global handle not serialized" error during CreateBlob.
///
/// @param creator - SnapshotCreator handle
/// @return The index at which the context was added, or SIZE_MAX on failure
size_t v8_SnapshotCreator_CreateAndAddContext(void* creator) {
    if (!creator) {
        fprintf(stderr, "[v8_SnapshotCreator_CreateAndAddContext] ERROR: creator is null\n");
        return SIZE_MAX;
    }
    
    SnapshotCreator* sc = static_cast<SnapshotCreator*>(creator);
    Isolate* isolate = sc->GetIsolate();
    
    HandleScope handle_scope(isolate);
    
    // Create context using Local handle only (no Global)
    Local<Context> context = Context::New(isolate);
    if (context.IsEmpty()) {
        fprintf(stderr, "[v8_SnapshotCreator_CreateAndAddContext] ERROR: Context::New failed\n");
        return SIZE_MAX;
    }
    
    // Enter and exit context (V8 requirement)
    context->Enter();
    context->Exit();
    
    size_t index = sc->AddContext(context, SerializeInternalFieldsCallback(), SerializeContextDataCallback(), SerializeAPIWrapperCallback(RefuseApiWrapperInSnapshot));
    return index;
}

/// Set the default context for the snapshot
///
/// The snapshot will contain this context's state. When loading the snapshot,
/// contexts created will start with this state.
///
/// IMPORTANT: This must be called outside of any HandleScope!
/// The context should be fully set up with all interfaces registered.
///
/// @param creator - SnapshotCreator handle
/// @param context - Global handle to the context to snapshot
void v8_SnapshotCreator_SetDefaultContext(void* creator, Global<Context>* context) {
    if (!creator || !context) {
        fprintf(stderr, "[v8_SnapshotCreator_SetDefaultContext] ERROR: creator or context is null\n");
        return;
    }
    
    SnapshotCreator* sc = static_cast<SnapshotCreator*>(creator);
    Isolate* isolate = sc->GetIsolate();
    
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    if (ctx.IsEmpty()) {
        fprintf(stderr, "[v8_SnapshotCreator_SetDefaultContext] ERROR: context is empty\n");
        return;
    }
    
    fprintf(stderr, "[v8_SnapshotCreator_SetDefaultContext] Setting default context\n");
    sc->SetDefaultContext(ctx, SerializeInternalFieldsCallback(), SerializeContextDataCallback(), SerializeAPIWrapperCallback(RefuseApiWrapperInSnapshot));
    fprintf(stderr, "[v8_SnapshotCreator_SetDefaultContext] Default context set successfully\n");
}

/// Add context to snapshot at specific index
///
/// This adds a context that can be retrieved via Context::FromSnapshot(isolate, index)
/// after deserialization. The first call returns index 0, second returns 1, etc.
///
/// @param creator - SnapshotCreator handle
/// @param context - Global handle to the context to snapshot
/// @return The index at which the context was added (0-based)
size_t v8_SnapshotCreator_AddContext(void* creator, Global<Context>* context) {
    if (!creator || !context) {
        fprintf(stderr, "[v8_SnapshotCreator_AddContext] ERROR: creator or context is null\n");
        return SIZE_MAX;
    }
    
    SnapshotCreator* sc = static_cast<SnapshotCreator*>(creator);
    Isolate* isolate = sc->GetIsolate();
    
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    if (ctx.IsEmpty()) {
        fprintf(stderr, "[v8_SnapshotCreator_AddContext] ERROR: context is empty\n");
        return SIZE_MAX;
    }
    
    fprintf(stderr, "[v8_SnapshotCreator_AddContext] Adding context to snapshot\n");
    size_t index = sc->AddContext(ctx, SerializeInternalFieldsCallback(), SerializeContextDataCallback(), SerializeAPIWrapperCallback(RefuseApiWrapperInSnapshot));
    fprintf(stderr, "[v8_SnapshotCreator_AddContext] Context added at index %zu\n", index);
    return index;
}

/// Create the snapshot blob
///
/// Serializes the V8 heap including the default context.
/// This MUST be called outside of any HandleScope.
///
/// @param creator - SnapshotCreator handle
/// @param function_code_handling - 0 = clear function code, 1 = keep function code
/// @param out_data - Output: pointer to snapshot data (caller must free with delete[])
/// @param out_size - Output: size of snapshot data in bytes
/// @return true on success, false on failure
bool v8_SnapshotCreator_CreateBlob(
    void* creator,
    int function_code_handling,
    const char** out_data,
    int* out_size
) {
    if (!creator || !out_data || !out_size) return false;
    
    SnapshotCreator* sc = static_cast<SnapshotCreator*>(creator);
    
    SnapshotCreator::FunctionCodeHandling handling = 
        function_code_handling == 1 
            ? SnapshotCreator::FunctionCodeHandling::kKeep
            : SnapshotCreator::FunctionCodeHandling::kClear;
    
    StartupData blob = sc->CreateBlob(handling);
    
    if (blob.data == nullptr || blob.raw_size <= 0) {
        *out_data = nullptr;
        *out_size = 0;
        return false;
    }
    
    // Copy the data - caller owns this memory
    char* data_copy = new char[blob.raw_size];
    memcpy(data_copy, blob.data, blob.raw_size);
    
    // Free the original V8-allocated data
    delete[] blob.data;
    
    *out_data = data_copy;
    *out_size = blob.raw_size;
    return true;
}

/// Dispose a SnapshotCreator
///
/// This also disposes the isolate owned by the SnapshotCreator.
/// Must be called after CreateBlob.
///
/// @param creator - SnapshotCreator handle to dispose
void v8_SnapshotCreator_Dispose(void* creator) {
    if (!creator) return;
    SnapshotCreator* sc = static_cast<SnapshotCreator*>(creator);
    delete sc;
}

/// Free snapshot data allocated by v8_SnapshotCreator_CreateBlob
///
/// @param data - Pointer returned in out_data from CreateBlob
void v8_Snapshot_FreeData(const char* data) {
    if (data) {
        delete[] data;
    }
}

/// Create a new isolate from a snapshot blob
///
/// This is the runtime counterpart to SnapshotCreator. The isolate
/// starts with the heap state from the snapshot, so all interfaces
/// that were registered at snapshot time are already available.
///
/// CRITICAL: external_references MUST be the same array (same order)
/// as was used when creating the snapshot.
///
/// The blob is read IN PLACE, never copied: V8 reads it when the isolate is
/// made (Snapshot::Initialize) and again for every context restored from it
/// (Snapshot::NewContextFromSnapshot), so `snapshot_data` is BORROWED until
/// v8_Isolate_Dispose of the returned isolate returns - the embedder owns
/// the blob (v8-isolate.h, CreateParams::snapshot_blob). Every caller's
/// blob already outlives its isolates: the engine's, lent by the host until
/// deinitializeEngine, which follows every agent's end (protocol_agents),
/// and snapshot_loader's, kept until cleanupSnapshotData. Chromium does the
/// same: every isolate's StartupData points into the one snapshot mapping,
/// which is never unmapped (gin/v8_initializer.cc, GetMappedFileData).
/// This function used to copy the 2.6 MB blob into a `new char[]` and a
/// `new StartupData` per isolate and free neither: one leak per Browser
/// (lesson testing-a-leak-total-that-grows-with-the-browsers-a-run-makes-
/// is-a-per-browser-leak).
///
/// @param snapshot_data - Snapshot blob data, BORROWED for the isolate's life
/// @param snapshot_size - Size of snapshot blob in bytes
/// @param external_references - Null-terminated array of external references
///                              (must match snapshot creation order exactly)
/// @return New isolate with snapshot state, or nullptr on failure
Isolate* v8_Isolate_NewFromSnapshotWithOptions(
    const char* snapshot_data,
    int snapshot_size,
    const intptr_t* external_references,
    const CraneIsolateOptions* options
);

Isolate* v8_Isolate_NewFromSnapshot(
    const char* snapshot_data,
    int snapshot_size,
    const intptr_t* external_references
) {
    return v8_Isolate_NewFromSnapshotWithOptions(snapshot_data, snapshot_size, external_references, nullptr);
}

/// v8_Isolate_NewFromSnapshot, with what the agent asks of its isolate
/// before it initializes (CraneIsolateOptions; null: none).
Isolate* v8_Isolate_NewFromSnapshotWithOptions(
    const char* snapshot_data,
    int snapshot_size,
    const intptr_t* external_references,
    const CraneIsolateOptions* options
) {
    // As v8_Isolate_New: the net below ffi.zig's start.
    if (v8_Platform_Start(nullptr) == kPlatformDisposed) return nullptr;

    if (!snapshot_data || snapshot_size <= 0) {
        fprintf(stderr, "[v8_Isolate_NewFromSnapshot] ERROR: Invalid snapshot data\n");
        return nullptr;
    }
    
    // Count external references (silently)
    int ref_count = 0;
    if (external_references) {
        while (external_references[ref_count] != 0) ref_count++;
    }
    
    // The adapter's per-isolate record (kIsolateDataSlot), made first: it
    // holds the StartupData, which V8 keeps a POINTER to for the isolate's
    // life, so the record must exist before the isolate and outlive it
    // (v8_Isolate_Dispose deletes it after Isolate::Dispose). The StartupData
    // points at the caller's bytes - no copy. Slots 0-1 are the Zig side's
    // (isolate_allocator.zig, isolate_templates.zig); slot 3 is the innermost
    // binding catch scope (kBindingCatchScopeSlot).
    IsolateData* isolate_data = new IsolateData();
    isolate_data->startup_data.data = snapshot_data;
    isolate_data->startup_data.raw_size = snapshot_size;
    applyIsolateOptions(isolate_data, options);
    
    // Validate the snapshot
    if (!isolate_data->startup_data.IsValid()) {
        fprintf(stderr, "[v8_Isolate_NewFromSnapshot] ERROR: Snapshot data is not valid\n");
        delete isolate_data;
        return nullptr;
    }

    // One read-only heap per process (g_read_only_heap): not from this blob
    // while the live isolates' heap came from another snapshot.
    if (!claimReadOnlyHeap(snapshot_data, snapshot_size)) {
        delete isolate_data;
        return nullptr;
    }
    isolate_data->holds_read_only_heap = true;
    
    // Create isolate params with snapshot and external references. The
    // ArrayBuffer allocator is V8's to free once the isolate and every
    // BackingStore it allocated are gone (v8_Isolate_New says why).
    Isolate::CreateParams create_params;
    create_params.array_buffer_allocator_shared =
        std::shared_ptr<ArrayBuffer::Allocator>(ArrayBuffer::Allocator::NewDefaultAllocator());
    create_params.snapshot_blob = &isolate_data->startup_data;
    create_params.external_references = external_references;
    applyHeapConstraints(create_params, options);
    // The agent's C++ heap, as v8_Isolate_NewWithOptions gives it.
    isolate_data->cpp_heap = newAgentCppHeap();
    create_params.cpp_heap = isolate_data->cpp_heap.get();
    
    Isolate* isolate = Isolate::Allocate();
    if (!isolate) {
        releaseReadOnlyHeap();
        delete isolate_data;
        return nullptr;
    }
    isolate->SetData(kIsolateDataSlot, isolate_data);
    Isolate::Initialize(isolate, create_params);
    adoptCppHeap(isolate_data);
    installGCPauseRecorder(isolate);
    installNodeWrapperRootsHandler(isolate);

    return isolate;
}

/// A context restored from the snapshot's context 0 - the Window context the
/// generator added (AddContext), with its global proxy and every WebIDL
/// interface - or null when it cannot be: an isolate made without the
/// snapshot (it has no context 0), a null isolate, or a failed
/// deserialization. Says nothing: the caller decides whether that matters and
/// logs it (protocol_realms builds the realm afresh, at debug). It printed
/// seven unguarded stderr lines per failure - every iframe and popup realm of
/// a snapshotless Browser tried, and printed them (AGENTS.md: no unguarded
/// fprintf in v8_wrapper.cpp; docs/testing/test-variant-findings-2026-11-02.tsv
/// F3).
///
/// @param isolate - Isolate created from v8_Isolate_NewFromSnapshot
/// @return New context with snapshot state, or null
Global<Context>* v8_Context_NewFromSnapshot(Isolate* isolate) {
    if (!isolate) return nullptr;
    // An isolate made afresh has no context 0 to restore.
    IsolateData* record = isolateData(isolate);
    if (record && !record->startup_data.data) return nullptr;

    // Enter the isolate before creating context
    Isolate::Scope isolate_scope(isolate);
    HandleScope handle_scope(isolate);
    // A failed deserialization's exception stays here.
    TryCatch try_catch(isolate);

    // Use Context::FromSnapshot(isolate, 0) to retrieve the context that was
    // added via AddContext() during snapshot creation. This preserves the
    // global proxy (unlike the default context from SetDefaultContext).
    // The DeserializeInternalFieldsCallback handles any internal field restoration.
    MaybeLocal<Context> maybe_context = Context::FromSnapshot(
        isolate, 0,
        DeserializeInternalFieldsCallback(DeserializeInternalFields, nullptr));

    Local<Context> context;
    if (!maybe_context.ToLocal(&context)) return nullptr;

    countContextGlobal();
    return trackHandle(new Global<Context>(isolate, context));
}

/// Create a context from the snapshot's context 0 around an EXISTING global
/// proxy - one whose previous context was detached with
/// v8_Context_DetachGlobal. The proxy keeps its identity: every reference to
/// it (iframe.contentWindow, window.open()'s return value, a parent's
/// window[name]) now reaches the new context's global object.
///
/// This is how a navigable's WindowProxy survives the Window it proxies being
/// replaced: HTML "create and initialize a Document object" makes a new realm
/// for the new document, "with the global this binding" the browsing
/// context's WindowProxy. Blink does the same in LocalWindowProxy::
/// CreateContext, which passes its detached global_proxy_ to
/// v8::Context::New (third_party/blink/renderer/bindings/core/v8/
/// local_window_proxy.cc). V8 (bootstrapper.cc, Genesis) hooks the snapshot's
/// native context up to the supplied proxy (HookUpGlobalProxy).
///
/// @param isolate      - Isolate created from a snapshot
/// @param global_proxy - The detached global proxy to reuse (not consumed)
/// @return A new context, owned by the caller (dispose with
///         v8_Context_Dispose), or null on failure
Global<Context>* v8_Context_NewFromSnapshotWithGlobal(Isolate* isolate, Global<Object>* global_proxy) {
    if (!isolate || !global_proxy) return nullptr;

    Isolate::Scope isolate_scope(isolate);
    HandleScope handle_scope(isolate);
    TryCatch try_catch(isolate);

    Local<Object> proxy = global_proxy->Get(isolate);
    MaybeLocal<Context> maybe_context = Context::FromSnapshot(
        isolate, 0,
        DeserializeInternalFieldsCallback(DeserializeInternalFields, nullptr),
        nullptr,
        MaybeLocal<Value>(proxy));

    Local<Context> context;
    if (!maybe_context.ToLocal(&context)) return nullptr;
    // Counted, since v8_Context_Dispose uncounts it.
    g_live_context_globals.fetch_add(1, std::memory_order_relaxed);
    return trackHandle(new Global<Context>(isolate, context));
}

/// Create a context from a specific index in the snapshot
///
/// This creates a new context based on the context that was added at the
/// specified index during snapshot creation. Use this to restore different
/// context types (e.g., window context at index 0, worker context at index 1).
///
/// @param isolate - Isolate created from v8_Isolate_NewFromSnapshot
/// @param context_index - The index of the context to restore (0-based)
/// @return New context with snapshot state, or nullptr if index is invalid
Global<Context>* v8_Context_NewFromSnapshotAt(Isolate* isolate, size_t context_index) {
    if (!isolate) {
        fprintf(stderr, "[v8_Context_NewFromSnapshotAt] ERROR: isolate is null\n");
        return nullptr;
    }
    
    // Enter the isolate before creating context
    Isolate::Scope isolate_scope(isolate);
    HandleScope handle_scope(isolate);
    
    // Add TryCatch to capture any exception
    TryCatch try_catch(isolate);
    
    // Use Context::FromSnapshot to retrieve the context at the specified index
    MaybeLocal<Context> maybe_context = Context::FromSnapshot(
        isolate, context_index,
        DeserializeInternalFieldsCallback(DeserializeInternalFields, nullptr));
    
    if (try_catch.HasCaught()) {
        fprintf(stderr, "[v8_Context_NewFromSnapshotAt] Exception caught during FromSnapshot(%zu)\n", context_index);
        Local<Message> message = try_catch.Message();
        if (!message.IsEmpty()) {
            String::Utf8Value msg_str(isolate, message->Get());
            fprintf(stderr, "[v8_Context_NewFromSnapshotAt] Exception: %s\n", *msg_str);
        }
    }
    
    Local<Context> context;
    if (!maybe_context.ToLocal(&context)) {
        fprintf(stderr, "[v8_Context_NewFromSnapshotAt] ERROR: Context::FromSnapshot(%zu) failed\n", context_index);
        fprintf(stderr, "  This usually means no context was added at index %zu during snapshot creation\n", context_index);
        return nullptr;
    }
    
    countContextGlobal();
    return trackHandle(new Global<Context>(isolate, context));
}

// Get the MicrotaskQueue associated with a context
// This is needed for ShadowRealm to share the initiator's microtask queue
MicrotaskQueue* v8_Context_GetMicrotaskQueue(Global<Context>* context) {
    if (!context) return nullptr;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> local_context = context->Get(isolate);
    return local_context->GetMicrotaskQueue();
}

/// Create a context from a specific snapshot index with a custom MicrotaskQueue
///
/// This is critical for ShadowRealm: the new context must share the initiator's
/// microtask queue so that wrapped functions can be called from inside the ShadowRealm.
/// See Chromium's shadow_realm_context.cc for reference.
///
/// @param isolate - Isolate created from v8_Isolate_NewFromSnapshot
/// @param context_index - The index of the context to restore (0-based)
/// @param microtask_queue - The microtask queue to use (usually from the initiator context)
/// @return New context with snapshot state, or nullptr if index is invalid
Global<Context>* v8_Context_NewFromSnapshotAtWithMicrotaskQueue(
    Isolate* isolate,
    size_t context_index,
    MicrotaskQueue* microtask_queue) {
    if (!isolate) {
        fprintf(stderr, "[v8_Context_NewFromSnapshotAtWithMicrotaskQueue] ERROR: isolate is null\n");
        return nullptr;
    }

    // Enter the isolate before creating context
    Isolate::Scope isolate_scope(isolate);
    HandleScope handle_scope(isolate);

    // Add TryCatch to capture any exception
    TryCatch try_catch(isolate);

    // Use Context::FromSnapshot with the microtask_queue parameter
    // Per V8 API: FromSnapshot(isolate, index, internal_fields_cb, extensions, global_object, microtask_queue)
    MaybeLocal<Context> maybe_context = Context::FromSnapshot(
        isolate,
        context_index,
        DeserializeInternalFieldsCallback(DeserializeInternalFields, nullptr),
        nullptr,  // extensions
        MaybeLocal<Value>(),  // global_object
        microtask_queue);  // Use the provided microtask queue

    if (try_catch.HasCaught()) {
        fprintf(stderr, "[v8_Context_NewFromSnapshotAtWithMicrotaskQueue] Exception caught during FromSnapshot(%zu)\n", context_index);
        Local<Message> message = try_catch.Message();
        if (!message.IsEmpty()) {
            String::Utf8Value msg_str(isolate, message->Get());
            fprintf(stderr, "[v8_Context_NewFromSnapshotAtWithMicrotaskQueue] Exception: %s\n", *msg_str);
        }
    }

    Local<Context> context;
    if (!maybe_context.ToLocal(&context)) {
        fprintf(stderr, "[v8_Context_NewFromSnapshotAtWithMicrotaskQueue] ERROR: Context::FromSnapshot(%zu) failed\n", context_index);
        return nullptr;
    }

    countContextGlobal();
    return trackHandle(new Global<Context>(isolate, context));
}

/// Create a fresh context with a custom MicrotaskQueue
///
/// This is used for ShadowRealm where we need a fresh context that shares
/// the initiator's microtask queue. Unlike FromSnapshot, Context::New creates
/// a truly fresh context which works better with V8's JSWrappedFunction mechanism.
///
/// @param isolate - V8 isolate
/// @param microtask_queue - The microtask queue to use (usually from the initiator context)
/// @return New fresh context, or nullptr on failure
/// Recursion guard for Context::NewWithMicrotaskQueue
/// This prevents crashes when ShadowRealm callback triggers context creation
// per-thread: a call-stack extent - whether v8_Context_NewWithMicrotaskQueue is running on this thread's stack (a context made inside it, from a ShadowRealm callback, takes the plain path); set and cleared around the call on the same thread.
static thread_local bool g_in_context_new = false;

Global<Context>* v8_Context_NewWithMicrotaskQueue(
    Isolate* isolate,
    MicrotaskQueue* microtask_queue) {
    if (!isolate) {
        fprintf(stderr, "[v8_Context_NewWithMicrotaskQueue] ERROR: isolate is null\n");
        return nullptr;
    }

    // Recursion guard: If we're already creating a context (e.g., from ShadowRealm callback),
    // create a simple context without the microtask queue to break the recursion.
    if (g_in_context_new) {
        fprintf(stderr, "[v8_Context_NewWithMicrotaskQueue] Recursive call detected, using simple context\n");
        Isolate::Scope isolate_scope(isolate);
        HandleScope handle_scope(isolate);

        // Create a minimal context without triggering ShadowRealm setup
        Local<Context> context = NewPlainGlobalContext(isolate);
        if (context.IsEmpty()) {
            return nullptr;
        }
        countContextGlobal();
        return trackHandle(new Global<Context>(isolate, context));
    }

    g_in_context_new = true;

    // Enter the isolate before creating context
    Isolate::Scope isolate_scope(isolate);
    HandleScope handle_scope(isolate);

    // Add TryCatch to capture any exception
    TryCatch try_catch(isolate);

    // Create a fresh context with the microtask queue: a plain global, with
    // a global template, never a bare Context::New - in an isolate restored
    // from Crane's snapshot that crashed (NewPlainGlobalContext says why).
    Local<Context> context = NewPlainGlobalContext(isolate, microtask_queue);

    g_in_context_new = false;

    if (context.IsEmpty()) {
        fprintf(stderr, "[v8_Context_NewWithMicrotaskQueue] ERROR: Context::New failed\n");
        if (try_catch.HasCaught()) {
            Local<Message> message = try_catch.Message();
            if (!message.IsEmpty()) {
                String::Utf8Value msg_str(isolate, message->Get());
                fprintf(stderr, "[v8_Context_NewWithMicrotaskQueue] Exception: %s\n", *msg_str);
            }
        }
        return nullptr;
    }

    countContextGlobal();
    return trackHandle(new Global<Context>(isolate, context));
}

/// Create a NEW context for an isolate that was created from a snapshot
///
/// Unlike v8_Context_NewFromSnapshot which restores a specific context from the
/// snapshot by index, this creates a completely new context. The new context will
/// have all the V8 builtins from the snapshot's default context as a template.
///
/// Use this when you need a fresh context but want to benefit from the snapshot's
/// pre-initialized V8 builtins.
///
/// @param isolate - Isolate created from v8_Isolate_NewFromSnapshot
/// @return New context (fresh, not from snapshot state)
Global<Context>* v8_Context_NewFromSnapshotDefault(Isolate* isolate) {
    if (!isolate) {
        fprintf(stderr, "[v8_Context_NewFromSnapshotDefault] ERROR: isolate is null\n");
        return nullptr;
    }
    
    fprintf(stderr, "[v8_Context_NewFromSnapshotDefault] Creating new context for snapshot isolate...\n");
    
    // The isolate should already be entered by the caller
    HandleScope handle_scope(isolate);
    
    // Add TryCatch to capture any exception
    TryCatch try_catch(isolate);
    
    // CRITICAL: When an isolate is created from a snapshot, Context::New() without
    // a global_template will try to deserialize from the snapshot, which fails with
    // "index < num_contexts" if no contexts were added via AddContext().
    //
    // To force V8 to create a FRESH context (not from snapshot), we provide an
    // empty global_template. This tells V8 to bootstrap a new context from scratch
    // while still benefiting from the snapshot's isolate-level optimizations
    // (pre-compiled builtins, heap state, etc.).
    //
    // Per V8 docs: "If a global template is provided, it will be used to create
    // the global object for the context from scratch."
    
    // Create an empty ObjectTemplate for the global object
    Local<ObjectTemplate> global_template = ObjectTemplate::New(isolate);
    
    fprintf(stderr, "[v8_Context_NewFromSnapshotDefault] Using empty global_template to force fresh context...\n");
    
    // Create context with the empty template and deserializer callback.
    // The DeserializeInternalFields callback is needed for snapshot isolates
    // to properly handle context creation.
    Local<Context> context = Context::New(
        isolate,
        nullptr,  // no extensions
        global_template,  // PROVIDE TEMPLATE to skip snapshot context
        MaybeLocal<Value>(),  // no global object
        DeserializeInternalFieldsCallback(DeserializeInternalFields, nullptr),
        nullptr  // no microtask queue
    );
    
    if (try_catch.HasCaught()) {
        fprintf(stderr, "[v8_Context_NewFromSnapshotDefault] Exception caught during Context::New\n");
        Local<Message> message = try_catch.Message();
        if (!message.IsEmpty()) {
            String::Utf8Value msg_str(isolate, message->Get());
            fprintf(stderr, "[v8_Context_NewFromSnapshotDefault] Exception: %s\n", *msg_str);
        }
        return nullptr;
    }
    
    if (context.IsEmpty()) {
        fprintf(stderr, "[v8_Context_NewFromSnapshotDefault] ERROR: Context::New returned empty context\n");
        return nullptr;
    }
    
    fprintf(stderr, "[v8_Context_NewFromSnapshotDefault] SUCCESS: New context created\n");
    countContextGlobal();
    return trackHandle(new Global<Context>(isolate, context));
}

/// Check if a snapshot blob is valid
///
/// Validates that the snapshot data can be used with the current V8 version.
///
/// @param snapshot_data - Pointer to snapshot blob data
/// @param snapshot_size - Size of snapshot blob in bytes
/// @return true if valid, false if invalid or corrupted
bool v8_Snapshot_IsValid(const char* snapshot_data, int snapshot_size) {
    if (!snapshot_data || snapshot_size <= 0) {
        return false;
    }
    
    StartupData startup_data;
    startup_data.data = snapshot_data;
    startup_data.raw_size = snapshot_size;
    
    return startup_data.IsValid();
}

/// Check if a snapshot blob can be rehashed during deserialization
///
/// If CanBeRehashed() returns false, the snapshot can only be loaded by an
/// isolate with the same hash seed that was used during snapshot creation.
/// This typically causes "rehashability" errors during context restoration.
///
/// @param snapshot_data - Pointer to snapshot blob data
/// @param snapshot_size - Size of snapshot blob in bytes
/// @return true if rehashable, false if not
bool v8_Snapshot_CanBeRehashed(const char* snapshot_data, int snapshot_size) {
    if (!snapshot_data || snapshot_size <= 0) {
        return false;
    }
    
    StartupData startup_data;
    startup_data.data = snapshot_data;
    startup_data.raw_size = snapshot_size;
    
    bool result = startup_data.CanBeRehashed();
    fprintf(stderr, "[v8_Snapshot_CanBeRehashed] Snapshot rehashability: %s\n", 
            result ? "true" : "false");
    return result;
}

// ============================================================================
// C++ Callback Pointers for External References
// ============================================================================
//
// These functions return pointers to C++ callbacks that are used by V8
// FunctionTemplates. For V8 snapshots to work correctly, ALL callback
// function pointers must be registered in the external references array.
//
// Since C++ static functions aren't directly accessible from Zig FFI,
// we expose them through these getter functions.

/// Get pointer to AsyncIteratorNextCallback
///
/// This callback is used when creating async iterator objects via
/// v8_CreateAsyncIterator. It wraps the Zig next function and handles
/// the V8-specific Promise wrapping.
///
/// @return Function pointer to AsyncIteratorNextCallback
void* v8_GetAsyncIteratorNextCallback() {
    return reinterpret_cast<void*>(&AsyncIteratorNextCallback);
}

/// Get pointer to AsyncIteratorReturnCallback
///
/// This callback is used when creating async iterator objects via
/// v8_CreateAsyncIterator. It wraps the Zig return function and handles
/// the V8-specific Promise wrapping.
///
/// @return Function pointer to AsyncIteratorReturnCallback
void* v8_GetAsyncIteratorReturnCallback() {
    return reinterpret_cast<void*>(&AsyncIteratorReturnCallback);
}

/// Get pointer to AsyncIteratorSelfCallback
///
/// This callback is used for Symbol.asyncIterator on async iterator objects.
/// It simply returns 'this', making the iterator both an iterator and iterable.
///
/// @return Function pointer to AsyncIteratorSelfCallback
void* v8_GetAsyncIteratorSelfCallback() {
    return reinterpret_cast<void*>(&AsyncIteratorSelfCallback);
}

// ============================================================================
// V8 Locker/Unlocker API - Thread Safety for Multi-Threaded Access
// ============================================================================
//
// V8 isolates are NOT thread-safe. When multiple threads need to access
// the same isolate, they MUST use v8::Locker to acquire exclusive access.
//
// Usage Pattern:
//   Thread 1: v8_Locker_New(isolate) -> do work -> v8_Locker_Dispose(locker)
//   Thread 2: blocks until Thread 1 releases, then acquires
//
// For blocking operations within locked sections, use Unlocker to temporarily
// release the lock so other threads can make progress:
//   v8_Unlocker_New(isolate) -> blocking I/O -> v8_Unlocker_Dispose(unlocker)

/// Create a new Locker for exclusive isolate access
///
/// This blocks if another thread holds the lock.
/// Returns an opaque pointer that must be passed to v8_Locker_Dispose.
///
/// @param isolate - The isolate to lock
/// @return Opaque Locker pointer (caller must dispose)
void* v8_Locker_New(Isolate* isolate) {
    return new Locker(isolate);
}

/// Dispose a Locker and release the lock
///
/// After calling this, other threads can acquire the lock.
///
/// @param locker - Locker pointer from v8_Locker_New
void v8_Locker_Dispose(void* locker) {
    if (locker) {
        delete static_cast<Locker*>(locker);
    }
}

/// Check if the current thread holds a lock on the isolate
///
/// @param isolate - The isolate to check
/// @return true if current thread holds the lock
bool v8_Locker_IsLocked(Isolate* isolate) {
    return Locker::IsLocked(isolate);
}

/// Create a new Unlocker to temporarily release the isolate lock
///
/// Use this when performing blocking operations that don't need V8 access.
/// The lock is automatically reacquired when the Unlocker is disposed.
///
/// IMPORTANT: Only call this when you already hold the lock (via Locker).
///
/// @param isolate - The isolate to temporarily unlock
/// @return Opaque Unlocker pointer (caller must dispose)
void* v8_Unlocker_New(Isolate* isolate) {
    return new Unlocker(isolate);
}

/// Dispose an Unlocker and reacquire the lock
///
/// This blocks if another thread acquired the lock while unlocked.
///
/// @param unlocker - Unlocker pointer from v8_Unlocker_New
void v8_Unlocker_Dispose(void* unlocker) {
    if (unlocker) {
        delete static_cast<Unlocker*>(unlocker);
    }
}

// ============================================================================
// Global Handle Conversion API
// ============================================================================
//
// These functions enable converting Local handles to Global handles for
// cross-scope persistence. This is critical for storing JavaScript callbacks
// (like stream start/write/close callbacks) that need to survive past the
// HandleScope that created them.
//
// V8 Handle Lifecycle:
// - Local<T>: Stack-bound, invalid after HandleScope ends
// - Global<T>: Heap-allocated, persists until explicitly Reset()
//
// Usage:
// 1. When extracting callback from dictionary: call v8_Value_ToGlobal()
// 2. When invoking callback: call v8_Global_Get() to get Local
// 3. When done with callback: call v8_Global_Dispose()

/// Convert a Local<Value> to a heap-allocated Global<Value>
///
/// The Local value comes from the current HandleScope. The returned Global
/// pointer persists independently of any HandleScope and must be disposed
/// with v8_Global_Dispose().
///
/// IMPORTANT: The 'local' parameter must be a valid Local<Value> internal pointer
/// from within an active HandleScope. This function creates a Global that persists
/// after the HandleScope ends.
///
/// @param isolate - Current V8 isolate
/// @param local - Local value pointer (from callback or conversion)
/// @return New Global<Value>* or nullptr if local is empty
Global<Value>* v8_Value_ToGlobal(Isolate* isolate, void* local) {
    if (!isolate || !local) return nullptr;

    HandleScope handle_scope(isolate);

    // Cast the void* back to Value* - this is the internal pointer from a Local<Value>
    // We can construct a Local from this internal pointer using the internal API
    Value* value_ptr = reinterpret_cast<Value*>(local);

    // Use internal::ValueHelper to construct a proper Local<Value>
    // This mirrors how V8 internally handles the conversion
    Local<Value> local_value = *reinterpret_cast<Local<Value>*>(&value_ptr);

    if (local_value.IsEmpty()) {
        return nullptr;
    }

    Global<Value>* global = new Global<Value>(isolate, local_value);

    // Verify the Global immediately after creation
    if (global->IsEmpty()) {
        delete global;
        return nullptr;
    }

    return trackHandle(global);
}

/// Dispose a Global<Value> handle
///
/// Releases the persistent reference, allowing the V8 value to be garbage
/// collected if no other references exist.
///
/// @param global - Global handle to dispose (null-safe)
void v8_Global_Dispose(Global<Value>* global) {
    // Snapshot mode: trackHandle queued this handle for bulk cleanup (see
    // v8_ObjectTemplate_Dispose), so deleting it here too is a double free.
    if (g_snapshot_mode) return;
    if (global != nullptr) {
        forgetCountedHandle(global);
        releaseWeakArm(global);
        untagRealmHandle(global);
        global->Reset();
        delete global;
    }
}

/// Check if a Global handle is empty or null
///
/// @param global - Global handle to check
/// @return true if null or empty, false if valid
bool v8_Global_IsEmpty(Global<Value>* global) {
    return global == nullptr || global->IsEmpty();
}

/// Get a Local<Value> from a Global<Value>
///
/// Creates a new Local handle in the current HandleScope. The returned
/// Local is valid only within the current HandleScope.
///
/// @param isolate - Current V8 isolate
/// @param global - Global handle to dereference
/// @return Local value pointer (as void*) or nullptr if global is empty
///
/// IMPORTANT: This function uses EscapableHandleScope to ensure the returned
/// Local handle is valid in the caller's HandleScope. The caller must have
/// an active HandleScope.
void* v8_Global_Get(Isolate* isolate, Global<Value>* global) {
    if (!isolate || !global) {
        return nullptr;
    }

    if (global->IsEmpty()) {
        return nullptr;
    }

    // Use EscapableHandleScope so we can return the Local to the caller's scope
    EscapableHandleScope handle_scope(isolate);
    Local<Value> local = global->Get(isolate);

    // Escape the local so it survives this function's HandleScope
    Local<Value> escaped = handle_scope.Escape(local);

    void* result = *reinterpret_cast<void**>(&escaped);

    // Return the internal pointer - now valid in caller's HandleScope
    // Use V8's slot-style representation (this is how V8 FFI handles work)
    return result;
}

/// Convert a Global<Value> to a Global<Function> if it contains a function
///
/// @param global - Global value handle
/// @return The same pointer cast to Global<Function>* if it's a function, nullptr otherwise
Global<Function>* v8_Global_ToFunction(Global<Value>* global) {
    if (!global || global->IsEmpty()) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> local = global->Get(isolate);
    
    if (!local->IsFunction()) return nullptr;
    
    // The Global<Value> and Global<Function> have the same internal representation
    // when the value is actually a function, so we can safely cast
    return reinterpret_cast<Global<Function>*>(global);
}

// ============================================================================
// JSON Serialization for Cross-Isolate Message Passing
// ============================================================================
//
// These functions enable serializing V8 values to JSON strings and back,
// which is useful for passing messages between worker isolates and the main
// thread when full structured clone is not available.

/// Serialize a V8 value to JSON string and copy to buffer
///
/// This function uses V8's JSON.stringify to convert a value to its JSON
/// representation, then copies the UTF-8 string to the provided buffer.
///
/// The function operates in two modes:
/// 1. If buffer_len is 0, returns the required buffer size
/// 2. If buffer_len > 0, writes JSON to buffer and returns bytes written
///
/// IMPORTANT: This function uses the CURRENT context from the current isolate.
/// It does NOT enter a new context - the caller must ensure the correct context
/// is already active. The context_raw parameter is used only for JSON::Stringify.
///
/// @param context_raw - Raw V8 Context pointer (passed to JSON::Stringify)
/// @param value_raw - Raw V8 Value pointer
/// @param buffer - Output buffer for UTF-8 JSON string
/// @param buffer_len - Size of output buffer (0 to query size)
/// @return Number of bytes written, -1 on error, or required size if buffer_len is 0
int v8_JSON_Stringify_ToBuffer(
    Context* context_raw,
    Value* value_raw,
    char* buffer,
    int buffer_len
) {
    // Get current isolate
    Isolate* isolate = Isolate::GetCurrent();
    if (!isolate) return -1;
    
    // Create HandleScope for local handles
    HandleScope handle_scope(isolate);
    
    // Get the CURRENT context from the isolate (not the passed context!)
    // This avoids context mismatch issues when called from within script execution
    Local<Context> context = isolate->GetCurrentContext();
    if (context.IsEmpty()) {
        return -1;  // No active context
    }
    
    // Convert value_raw to Local handle
    // value_raw is actually a Global<Value>* from v8_FunctionCallbackInfo_GetArgument
    // We need to dereference it and get the local handle
    Global<Value>* global_handle = reinterpret_cast<Global<Value>*>(value_raw);
    Local<Value> value = global_handle->Get(isolate);
    
    // Use V8's JSON.stringify with the current context
    // Do NOT enter a new context - we're already in one during script execution
    MaybeLocal<String> maybe_json = JSON::Stringify(context, value);
    if (maybe_json.IsEmpty()) {
        return -1;  // Stringify failed (e.g., circular reference, BigInt)
    }
    
    Local<String> json_str = maybe_json.ToLocalChecked();
    
    // Get the UTF-8 length
    int utf8_length = json_str->Utf8Length(isolate);
    
    // If buffer_len is 0, just return the required size
    if (buffer_len == 0) {
        return utf8_length;
    }
    
    // Check if buffer is large enough
    if (buffer_len < utf8_length) {
        // Return required size so caller can allocate larger buffer
        return utf8_length;
    }
    
    // Write UTF-8 to buffer
    if (buffer_len <= 0) return 0;
    return static_cast<int>(json_str->WriteUtf8(isolate, buffer, static_cast<size_t>(buffer_len)));
}

/// Parse JSON string from buffer and return V8 value
///
/// This function uses V8's JSON.parse to convert a JSON string to a V8 value.
/// The returned value is "escaped" from this function's HandleScope using
/// EscapableHandleScope, so it remains valid in the caller's HandleScope.
///
/// IMPORTANT: This function uses the CURRENT context from the current isolate.
/// The caller must ensure the correct isolate is entered and the correct
/// context is active before calling this function. The caller must also have
/// an active HandleScope.
///
/// @param context_raw - Raw V8 Context pointer (currently unused - uses current context)
/// @param json_str - UTF-8 JSON string
/// @param json_len - Length of JSON string
/// @return Local Value pointer (valid in caller's HandleScope) or nullptr on error
Value* v8_JSON_Parse_FromBuffer(
    Context* context_raw,
    const char* json_str,
    int json_len
) {
    (void)context_raw;  // Unused - we use current context
    
    // Get current isolate
    Isolate* isolate = Isolate::GetCurrent();
    if (!isolate) return nullptr;
    
    // Use EscapableHandleScope so we can return the handle to the caller's scope
    EscapableHandleScope handle_scope(isolate);
    
    // Get the CURRENT context from the isolate (not the passed context!)
    // This avoids context mismatch issues when called after isolate enter/exit
    Local<Context> context = isolate->GetCurrentContext();
    if (context.IsEmpty()) {
        return nullptr;  // No active context
    }
    
    // Create V8 string from JSON buffer
    MaybeLocal<String> maybe_str = String::NewFromUtf8(
        isolate,
        json_str,
        NewStringType::kNormal,
        json_len
    );
    
    if (maybe_str.IsEmpty()) {
        return nullptr;  // Failed to create string
    }
    
    Local<String> v8_json_str = maybe_str.ToLocalChecked();
    
    // Use V8's JSON.parse with the current context
    // Do NOT enter a new context - we should already be in the correct one
    MaybeLocal<Value> maybe_value = JSON::Parse(context, v8_json_str);
    
    if (maybe_value.IsEmpty()) {
        return nullptr;  // Parse failed (invalid JSON)
    }
    
    Local<Value> parsed_value = maybe_value.ToLocalChecked();
    
    // Escape the handle so it survives the destruction of our HandleScope
    // and remains valid in the caller's HandleScope
    Local<Value> escaped = handle_scope.Escape(parsed_value);
    
    // Return the internal pointer - valid in caller's HandleScope
    return *reinterpret_cast<Value**>(&escaped);
}

// ============================================================================
// HandleScope API for Zig Timer Callbacks
// ============================================================================
//
// V8 requires a HandleScope to be active when creating Local handles.
// When Zig timer callbacks fire from libuv, there's no active HandleScope.
// These functions allow Zig code to create and dispose HandleScopes.
//
// V8's HandleScope has private new/delete operators - it's designed for
// stack allocation only. We work around this by:
// 1. Using a derived class with public new/delete operators
// 2. Using the protected default constructor + Initialize() method
//
// Usage pattern in Zig:
//   const scope = v8_HandleScope_New(isolate);
//   defer v8_HandleScope_Dispose(scope);
//   // ... V8 operations that create Local handles ...

/// Derived HandleScope that can be heap-allocated
/// Uses the protected default constructor + Initialize() pattern
/// Provides public new/delete to override base class's private ones
class HeapHandleScope : public HandleScope {
 public:
    HeapHandleScope(Isolate* isolate) : HandleScope() {
        Initialize(isolate);
    }

    // Override base class's private new/delete with public versions
    // This is valid C++ - derived class can expose hidden base class members
    static void* operator new(size_t size) {
        return ::operator new(size);
    }

    static void operator delete(void* ptr) {
        ::operator delete(ptr);
    }
};

/// Create a new HandleScope for the given isolate
///
/// This must be called before any V8 operation that creates Local handles
/// when called from a non-V8 context (e.g., libuv timer callbacks).
///
/// @param isolate - The V8 isolate
/// @return Opaque pointer to HandleScope, or nullptr on failure
void* v8_HandleScope_New(Isolate* isolate) {
    if (!isolate) return nullptr;
    
    // Create heap-allocatable HandleScope via derived class
    return new HeapHandleScope(isolate);
}

/// Dispose a HandleScope created by v8_HandleScope_New
///
/// This must be called when done with V8 operations to properly clean up.
/// Typically used with defer in Zig.
///
/// @param scope_ptr - Pointer from v8_HandleScope_New
void v8_HandleScope_Dispose(void* scope_ptr) {
    if (!scope_ptr) return;
    
    HeapHandleScope* scope = static_cast<HeapHandleScope*>(scope_ptr);
    delete scope;
}

// ============================================================================
// V8 Proxy API - For ObservableArray Exotic Objects
// ============================================================================
//
// The Proxy API allows creating JavaScript Proxy objects from native code.
// This is required for implementing WebIDL ObservableArray which is specified
// as an exotic object backed by a Proxy.
//
// Spec: https://webidl.spec.whatwg.org/#idl-observable-array
//       https://webidl.spec.whatwg.org/#es-observable-array
//
// Key Requirements:
// - Proxy internals (target, handler) must NOT leak to JavaScript
// - Must support custom traps: get, set, deleteProperty, ownKeys, getPrototypeOf
// - ownKeys must return keys in order: indices (ascending) → "length" → strings (insertion)

/// Create a new V8 Proxy object
///
/// Creates a JavaScript Proxy with the specified target and handler.
///
/// @param context - The V8 context
/// @param target - The target object the proxy wraps
/// @param handler - The handler object with trap functions
/// @return Global handle to new Proxy object, or nullptr on error
Global<Object>* v8_Proxy_New(
    Global<Context>* context,
    Global<Object>* target,
    Global<Object>* handler
) {
    if (!context || !target || !handler) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Object> local_target = target->Get(isolate);
    Local<Object> local_handler = handler->Get(isolate);
    
    MaybeLocal<Proxy> maybe_proxy = Proxy::New(ctx, local_target, local_handler);
    if (maybe_proxy.IsEmpty()) {
        return nullptr;
    }
    
    Local<Proxy> proxy = maybe_proxy.ToLocalChecked();
    
    // Proxy inherits from Object, so we can cast
    return trackHandle(new Global<Object>(isolate, proxy.As<Object>()));
}

/// Check if a value is a Proxy
///
/// @param value - The value to check
/// @return true if the value is a Proxy, false otherwise
bool v8_Value_IsProxy(Global<Value>* value) {
    if (!value) return false;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    
    return val->IsProxy();
}

/// Get the target of a Proxy
///
/// @param proxy - The Proxy object
/// @return Global handle to the target, or nullptr if not a Proxy
Global<Value>* v8_Proxy_GetTarget(Global<Object>* proxy) {
    if (!proxy) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Object> obj = proxy->Get(isolate);
    
    if (!obj->IsProxy()) return nullptr;
    
    Local<Proxy> proxy_obj = obj.As<Proxy>();
    Local<Value> target = proxy_obj->GetTarget();
    
    return trackHandle(new Global<Value>(isolate, target));
}

/// Get the handler of a Proxy
///
/// @param proxy - The Proxy object
/// @return Global handle to the handler, or nullptr if not a Proxy
Global<Value>* v8_Proxy_GetHandler(Global<Object>* proxy) {
    if (!proxy) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Object> obj = proxy->Get(isolate);
    
    if (!obj->IsProxy()) return nullptr;
    
    Local<Proxy> proxy_obj = obj.As<Proxy>();
    Local<Value> handler = proxy_obj->GetHandler();
    
    return trackHandle(new Global<Value>(isolate, handler));
}

/// Revoke a Proxy (make it unusable)
///
/// After revocation, any operation on the Proxy will throw TypeError.
///
/// @param proxy - The Proxy object to revoke
void v8_Proxy_Revoke(Global<Object>* proxy) {
    if (!proxy) return;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Object> obj = proxy->Get(isolate);
    
    if (!obj->IsProxy()) return;
    
    Local<Proxy> proxy_obj = obj.As<Proxy>();
    proxy_obj->Revoke();
}

/// Check if a Proxy has been revoked
///
/// @param proxy - The Proxy object to check
/// @return true if revoked, false otherwise or if not a Proxy
bool v8_Proxy_IsRevoked(Global<Object>* proxy) {
    if (!proxy) return true;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Object> obj = proxy->Get(isolate);
    
    if (!obj->IsProxy()) return true;
    
    Local<Proxy> proxy_obj = obj.As<Proxy>();
    return proxy_obj->IsRevoked();
}

} // extern "C" - temporarily close for C++ helper functions

// ============================================================================
// Legacy Platform Object Proxy Support
// ============================================================================
//
// A legacy platform object with named properties is an API object - whose
// indexed and named interceptors are its [[GetOwnProperty]],
// [[DefineOwnProperty]] and [[Delete]] (WebIDL 3.9.1, 3.9.3, 3.9.4;
// interface.zig) - behind a Proxy that supplies the two internal methods V8's
// interceptors cannot: [[OwnPropertyKeys]] in WebIDL's order (3.9.6; V8 lists
// a named interceptor's names after the object's own string keys) and [[Set]]
// (3.9.2; V8 runs a named setter interceptor before a prototype's accessor).
// And [[PreventExtensions]] (3.9.5), which is one line.
//
// Every other internal method has NO trap, so the proxy forwards it to its
// target (ES 10.5: "If trap is undefined, return ? target.[[X]](...)"):
// - [[GetPrototypeOf]], [[SetPrototypeOf]], [[IsExtensible]], [[HasProperty]]
//   and [[Get]] are ordinary for a legacy platform object (WebIDL defines
//   none), and the ordinary ones are built on [[GetOwnProperty]];
// - [[GetOwnProperty]], [[DefineOwnProperty]] and [[Delete]] are WebIDL's, and
//   the target's interceptors are those steps.
//
// NOTHING HERE READS THE PAGE'S OBJECTS. The traps used to forward through
// the page's own `Reflect` - looked up on the current realm's global object
// when a trap ran, and cast unchecked - for seven internal methods a missing
// trap forwards natively, and for ownKeys, getOwnPropertyDescriptor and set:
// a page that deleted or replaced `Reflect` aborted the process at its next
// `"x" in collection` (an empty MaybeLocal into ToLocalChecked), and one that
// replaced `Reflect.has` was called for it with the proxy's raw target (lane
// wrap1 b2, finding 3; tests/v8/wrap1_legacy_proxy_traps_test.zig,
// tests/wpt/crane/wrap1-legacy-platform-object-no-script-calls.html). No
// browser calls script there: Blink's legacy platform objects are the API
// objects themselves. What the traps need of the target they ask V8's API,
// which reads the object and never a global.
// ============================================================================

namespace {

// The Proxy "ownKeys" trap: WebIDL 3.9.6, a legacy platform object's
// [[OwnPropertyKeys]]. The trap receives (target); O is the target.
//
// Its lists come from the target's own keys as V8 collects them
// (KeyAccumulator, own only, every property, numbers kept - what
// Reflect.ownKeys(target) reads): the elements and the indexed interceptor's
// enumerator as Numbers, the own string keys in creation order, the own
// symbols, then the named interceptor's enumerator as Strings. An object that
// supports indexed properties has no own property named by an array index
// ([[DefineOwnProperty]] step 1 refuses or sets the indexed property), so a
// Number is a supported property index; a String the target has no real own
// property for is a supported property name, visible by the interceptor's
// own rule (interface.zig isVisible, 3.9.7). No `length` is read: that is a
// property a page can replace, and Storage's is no index bound at all.
void LegacyPlatformObjectOwnKeys(const FunctionCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    HandleScope handle_scope(isolate);
    Local<Context> context = isolate->GetCurrentContext();

    if (info.Length() < 1 || !info[0]->IsObject()) {
        info.GetReturnValue().Set(Array::New(isolate, 0));
        return;
    }
    Local<Object> target = info[0].As<Object>();

    Local<Array> target_keys;
    if (!target->GetOwnPropertyNames(context, PropertyFilter::ALL_PROPERTIES, KeyConversionMode::kKeepNumbers).ToLocal(&target_keys)) {
        return;  // an enumerator's exception is pending
    }

    // 1. Let keys be a new empty list of JavaScript String and Symbol values.
    std::vector<uint32_t> indices;
    std::vector<Local<Value>> named;
    std::vector<Local<Value>> own_strings;
    std::vector<Local<Value>> own_symbols;
    const uint32_t count = target_keys->Length();
    for (uint32_t i = 0; i < count; i++) {
        Local<Value> key;
        if (!target_keys->Get(context, i).ToLocal(&key)) return;
        if (key->IsSymbol()) {
            own_symbols.push_back(key);
        } else if (key->IsNumber()) {
            const double number = key.As<Number>()->Value();
            if (number >= 0 && number < 4294967295.0) indices.push_back(static_cast<uint32_t>(number));
        } else if (key->IsString()) {
            if (target->HasRealNamedProperty(context, key.As<String>()).FromMaybe(false)) {
                own_strings.push_back(key);
            } else {
                named.push_back(key);
            }
        }
    }

    std::vector<Local<Value>> keys;
    keys.reserve(indices.size() + named.size() + own_strings.size() + own_symbols.size());
    // 2. If O supports indexed properties, then for each index of O's
    //    supported property indices, in ascending numerical order, append
    //    ! ToString(index) to keys.
    std::sort(indices.begin(), indices.end());
    for (uint32_t index : indices) {
        keys.push_back(String::NewFromUtf8(isolate, std::to_string(index).c_str()).ToLocalChecked());
    }
    // 3. If O supports named properties, then for each P of O's supported
    //    property names that is visible according to the named property
    //    visibility algorithm, append P to keys.
    keys.insert(keys.end(), named.begin(), named.end());
    // 4. For each P of O's own property keys that is a String, in ascending
    //    chronological order of property creation, append P to keys.
    keys.insert(keys.end(), own_strings.begin(), own_strings.end());
    // 5. For each P of O's own property keys that is a Symbol, in ascending
    //    chronological order of property creation, append P to keys.
    keys.insert(keys.end(), own_symbols.begin(), own_symbols.end());
    // 6. Assert: keys has no duplicate items. (V8's list has none.)
    // 7. Return keys. Made with its elements: a [[Set]] per element would
    //    run a setter a page put on Array.prototype.
    info.GetReturnValue().Set(Array::New(isolate, keys.data(), keys.size()));
}

// Whether `key` is an array index (ES 6.1.7: a canonical numeric string for an
// integer in [0, 2^32 - 2]).
bool IsArrayIndexKey(Isolate* isolate, Local<Value> key) {
    if (key->IsNumber()) return true;
    if (!key->IsString()) return false;
    String::Utf8Value utf8(isolate, key);
    if (utf8.length() == 0 || utf8.length() > 10) return false;
    const char* s = *utf8;
    if (utf8.length() > 1 && s[0] == '0') return false;
    uint64_t n = 0;
    for (int i = 0; i < utf8.length(); i++) {
        if (s[i] < '0' || s[i] > '9') return false;
        n = n * 10 + static_cast<uint64_t>(s[i] - '0');
    }
    return n < 0xFFFFFFFFull;
}

// The Proxy "set" trap: WebIDL 3.9.2 legacy platform object [[Set]](P, V,
// Receiver). The trap receives (target, P, V, Receiver); O is the target, and
// "O and Receiver are the same object" means Receiver is this proxy.
//
// It used to define an own data property on the target unconditionally, so
// no prototype setter ever ran on a legacy platform object: `tbody.vAlign =`,
// `classList.value =` (and so every [PutForwards=value] assignment:
// `el.relList = "a b"`), `options.length =`, `style.cssText =` all stored an
// own data property and changed nothing.
void TrapSet(const FunctionCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    HandleScope handle_scope(isolate);
    Local<Context> context = isolate->GetCurrentContext();

    if (info.Length() < 3 || !info[0]->IsObject()) {
        info.GetReturnValue().Set(false);
        return;
    }

    Local<Object> target = info[0].As<Object>();
    Local<Value> property = info[1];
    Local<Value> value = info[2];
    Local<Value> receiver = info.Length() > 3 ? info[3] : info[0];
    const bool receiver_is_o = receiver->IsProxy() &&
        receiver.As<Proxy>()->GetTarget()->StrictEquals(target);
    const bool is_index = IsArrayIndexKey(isolate, property);

    // Step 1: "If O and Receiver are the same object, then: if O implements
    // an interface with an indexed property setter and P is an array index,
    // invoke the indexed property setter with P and V; otherwise, if O
    // implements an interface with a named property setter and P is a String,
    // invoke the named property setter with P and V. Return true." The
    // target's own interceptors are those setters; defining the property on
    // the target runs them (a definer or setter interceptor, holder ==
    // receiver). An array index takes this path whether or not there is an
    // indexed setter: without one, the indexed interceptors answer as
    // [[DefineOwnProperty]] requires (WebIDL 3.9.3 [[DefineOwnProperty]] step
    // 1), which is what steps 2-3 would reach for a supported index.
    // Whether O implements an interface with a named property setter: the
    // trap's data, set when the proxy is made from the interface's
    // Meta.special_operations (template_registry.hasNamedPropertySetter).
    const bool has_named_setter = info.DataV2().As<Value>()->IsTrue();
    const bool via_own_setters = receiver_is_o &&
        (is_index || (property->IsString() && has_named_setter));

    if (!via_own_setters && property->IsName()) {
        // Step 2: "Let ownDesc be LegacyPlatformObjectGetOwnProperty(O, P,
        // true)" - own properties, supported indices, never named properties.
        // A real own property (an expando) keeps today's path below.
        const bool own = property->IsString()
            ? target->HasRealNamedProperty(context, property.As<String>()).FromMaybe(false)
            : target->HasOwnProperty(context, property.As<Name>()).FromMaybe(false);
        if (!own) {
            // Step 3: "Perform ? OrdinarySetWithOwnDescriptor(O, P, V,
            // Receiver, ownDesc)" with ownDesc undefined: ES 10.1.9.2 step 1
            // walks the prototype chain for P.
            Local<Value> proto = target->GetPrototype();
            while (proto->IsObject()) {
                Local<Object> holder = proto.As<Object>();
                Local<Value> desc_value;
                if (!holder->GetOwnPropertyDescriptor(context, property.As<Name>()).ToLocal(&desc_value)) {
                    return;  // an exception is pending
                }
                if (desc_value->IsUndefined()) {
                    proto = holder->GetPrototype();
                    continue;
                }
                // V8's descriptor object (FromPropertyDescriptor): its OWN
                // fields say what it is. Asked with [[HasProperty]], a `get`
                // a page put on Object.prototype made every data property
                // an accessor here.
                Local<Object> desc = desc_value.As<Object>();
                Local<Value> getter, setter;
                const bool has_get = desc->HasOwnProperty(context, String::NewFromUtf8Literal(isolate, "get")).FromMaybe(false);
                const bool has_set = desc->HasOwnProperty(context, String::NewFromUtf8Literal(isolate, "set")).FromMaybe(false);
                if (has_get || has_set) {
                    // ES 10.1.9.2 step 4: an accessor descriptor. "Let setter
                    // be ownDesc.[[Set]]. If setter is undefined, return
                    // false. Perform ? Call(setter, Receiver, « V »). Return
                    // true." - false is a TypeError in strict code.
                    if (!desc->Get(context, String::NewFromUtf8Literal(isolate, "set")).ToLocal(&setter)) return;
                    if (!setter->IsFunction()) {
                        info.GetReturnValue().Set(false);
                        return;
                    }
                    Local<Value> args[] = { value };
                    if (setter.As<Function>()->Call(context, receiver, 1, args).IsEmpty()) return;
                    info.GetReturnValue().Set(true);
                    return;
                }
                // ES 10.1.9.2 step 2.a: "If ownDesc.[[Writable]] is false,
                // return false."
                Local<Value> writable;
                if (!desc->Get(context, String::NewFromUtf8Literal(isolate, "writable")).ToLocal(&writable)) return;
                if (!writable->BooleanValue(isolate)) {
                    info.GetReturnValue().Set(false);
                    return;
                }
                // A writable data property further up: the value lands on
                // Receiver, below.
                break;
            }
        }
        if (!receiver_is_o) {
            // Receiver is another object that has this proxy on its prototype
            // chain: the data property is Receiver's own (ES 10.1.9.2 steps
            // 2.b-e), which the target's ordinary [[Set]] with that receiver
            // does - V8's own (Object::Set with a receiver), never the
            // page's Reflect.set.
            // ES 10.1.9.2 step 2.b: "If Receiver is not an Object, return
            // false."
            if (!receiver->IsObject()) {
                info.GetReturnValue().Set(false);
                return;
            }
            Maybe<bool> stored = target->Set(context, property, value, receiver.As<Object>());
            if (stored.IsNothing()) return;  // an exception is pending
            info.GetReturnValue().Set(stored.FromJust());
            return;
        }
    }

    // Step 1's setters, and step 3's "create or update an own data property
    // on Receiver" with Receiver the proxy (ES 10.1.9.2 steps 2.c-e,
    // CreateDataProperty): define it on the target, which runs the target's
    // definer and setter interceptors rather than bypassing them the way a
    // plain store to an object with a named property handler would. Its
    // false - a supported name with no named setter (WebIDL 3.9.3 step
    // 2.2.1) - is the trap's false, a TypeError only in strict code (ES
    // 10.5.9 step 9); Object.defineProperty threw it in sloppy code too.
    // Object::DefineProperty, not DefineOwnProperty: a named setter converts
    // its value, which can run script (toString), and DefineOwnProperty
    // enters V8 with script disallowed.
    if (!property->IsName()) {
        info.GetReturnValue().Set(false);
        return;
    }
    PropertyDescriptor descriptor(value, true);
    descriptor.set_enumerable(true);
    descriptor.set_configurable(true);
    Maybe<bool> defined = target->DefineProperty(context, property.As<Name>(), descriptor);
    if (defined.IsNothing()) return;  // an exception is pending
    info.GetReturnValue().Set(defined.FromJust());
}

// The Proxy "preventExtensions" trap: WebIDL 3.9.5, a legacy platform
// object's [[PreventExtensions]]. "This keeps legacy platform objects
// extensible by making [[PreventExtensions]] fail for them."
void LegacyPlatformObjectPreventExtensions(const FunctionCallbackInfo<Value>& info) {
    // 1. Return false.
    info.GetReturnValue().Set(false);
}

} // anonymous namespace

extern "C" {

/// The embedder data slots of a context that hold its legacy platform object
/// proxies' handlers: the one for interfaces with no named property setter,
/// and the one for those with one. (Index 1 is the context's Crane id,
/// kCraneContextIdIndex; 2 its cross-origin functions,
/// kCrossOriginFunctionsIndex; 0 is V8's old debugger slot.)
constexpr int kLegacyProxyHandlerIndex = 3;
constexpr int kLegacyProxyNamedSetterHandlerIndex = 4;

/// A new handler for legacy platform object proxies made in `ctx`:
/// `named_setter` says whether its "set" trap serves an interface with a
/// named property setter (WebIDL 3.9.2 [[Set]] step 1.2).
///
/// It has NO prototype. A proxy finds each trap with GetMethod(handler,
/// name) (ES 10.5.x), which reads the handler's prototype chain, and the
/// handler has no own "get" on purpose (below): made by Object::New it
/// inherited from the realm's %Object.prototype%, so a page's
/// `Object.prototype.get = f` became the [[Get]] trap of every legacy
/// platform object in the realm, called with the handler as `this` and the
/// proxy's target as its first argument. Blink has no such object to reach
/// (its legacy platform objects are API objects with interceptors).
static Local<Object> NewLegacyPlatformObjectHandler(Isolate* isolate, Local<Context> ctx, bool named_setter) {
    Local<Object> handler = Object::New(isolate);
    // Object::SetPrototype on a JSObject enters V8 with no script and no
    // callbacks (15.7.112.43 src/api/api.cc SetPrototypeImpl,
    // EnterV8NoScriptNoExceptionScope).
    handler->SetPrototype(ctx, Null(isolate)).Check();

    // Helper to create and set a function trap.
    //
    // CreateDataProperty, not Set: this runs from native code with no script
    // on the stack whenever a realm's first legacy platform object is wrapped
    // there (a tree mutation's record, a collection traced from a DOM
    // algorithm). Object::Set enters V8 with do_callback=true (13.1
    // api.cc:4469, ENTER_V8), and leaving that scope at call depth 0 fires
    // the call-completed callbacks - under kAuto a microtask checkpoint
    // (api-inl.h CallDepthScope::~CallDepthScope, isolate.cc
    // FireCallCompletedCallbackInternal), run from inside the DOM algorithm.
    // On a JSObject CreateDataProperty enters with ENTER_V8_NO_SCRIPT (13.1
    // api.cc:4526): do_callback=false. It also defines the trap as an own
    // data property whatever Object.prototype holds - a [[Set]] would have run
    // an accessor script installed there. GetFunction (PREPARE_FOR_EXECUTION,
    // api.cc:7503), Object::New and Proxy::New (api.cc:8866) fire nothing.
    auto set_trap = [&](const char* name, FunctionCallback callback, Local<Value> data = Local<Value>()) {
        Local<FunctionTemplate> tmpl = FunctionTemplate::New(isolate, callback, data);
        Local<Function> fn = tmpl->GetFunction(ctx).ToLocalChecked();
        handler->CreateDataProperty(ctx, String::NewFromUtf8(isolate, name).ToLocalChecked(), fn).Check();
    };

    // No "get" trap. A proxy with one makes V8 check the trap's result
    // against the target's own property descriptor on EVERY read
    // (JSProxy::CheckGetSetTrapResult, ES 10.5.8 step 9) - for a NodeList that
    // is the indexed descriptor interceptor building a descriptor object per
    // `list[i]`, two thirds of the cost of the read. Without the trap V8
    // forwards [[Get]] to the target natively with the proxy as receiver, and
    // every path that unwraps a receiver's instance looks through a proxy to
    // its target.
    // The three internal methods the target's interceptors do not answer
    // as WebIDL says ("Legacy Platform Object Proxy Support", above); every
    // other one has no trap and is the target's.
    set_trap("set", TrapSet, Boolean::New(isolate, named_setter));
    set_trap("ownKeys", LegacyPlatformObjectOwnKeys);
    set_trap("preventExtensions", LegacyPlatformObjectPreventExtensions);
    return handler;
}

/// The handler of the legacy platform object proxies of `ctx` with
/// (`named_setter`) or without a named property setter: ONE object per realm
/// and kind, made with the realm's first such proxy and kept in the context's
/// embedder data - so it lives exactly as long as the realm's context, and
/// each proxy keeps it besides.
///
/// A handler holds nothing of a proxy. ES 10.5 calls every trap as
/// Call(trap, handler, << target, ... >>): the traps read their target - the
/// API object whose interceptors answer for the platform object - as their
/// first argument, and the only datum a trap carries is "set"'s
/// `named_setter`, a fact of the interface. A handler per proxy - an object
/// and ten FunctionTemplates with their Functions - was 3,860 B of V8's heap
/// for every wrapped HTMLCollection, NamedNodeMap, DOMStringMap,
/// CSSStyleDeclaration or Storage (gc_bench, lane wrap1 b2 step 0).
///
/// Script cannot tell one handler from many: no ES operation returns a
/// proxy's [[ProxyHandler]], and a trap is an API function, which V8 leaves
/// out of Error.stack, Error.prepareStackTrace's call sites and
/// Function.prototype.caller (15.7.112.43 src/execution/isolate.cc
/// IsNotHidden: hidden unless --experimental-stack-trace-frames, which is off
/// by default and not among Crane's flags). A debugger does see a proxy's
/// [[Handler]] (the console's inspector session), so the handler is frozen:
/// what is reached that way cannot give another object's proxy a trap, or
/// change one. Each trap's realm is the handler's, the realm its platform
/// objects are of, as it was when each proxy made its own
/// (tests/v8/wrap1_legacy_proxy_handler_test.zig).
///
/// Not while the snapshot is being built: a context's embedder data goes into
/// the blob, and the traps' callbacks are no external references of it; the
/// generator wraps no platform object, and one made there would get a handler
/// of its own, as before.
static Local<Object> LegacyPlatformObjectHandlerOf(Isolate* isolate, Local<Context> ctx, bool named_setter) {
    if (g_snapshot_mode) return NewLegacyPlatformObjectHandler(isolate, ctx, named_setter);
    const int index = named_setter ? kLegacyProxyNamedSetterHandlerIndex : kLegacyProxyHandlerIndex;
    // Only Crane writes embedder data at these indices, so a slot within the
    // array's length is ours.
    if (ctx->GetNumberOfEmbedderDataFields() > static_cast<uint32_t>(index)) {
        Local<Value> slot = ctx->GetEmbedderDataV2(index).As<Value>();
        if (!slot.IsEmpty() && slot->IsObject()) return slot.As<Object>();
    }
    Local<Object> handler = NewLegacyPlatformObjectHandler(isolate, ctx, named_setter);
    {
        // Object::SetIntegrityLevel enters V8 as a script call would
        // (EnterV8Scope, api.cc), and this can be native code at call depth
        // 0: no kAuto microtask checkpoint when it leaves (NativeStepScope).
        NativeStepScope native_step(isolate);
        handler->SetIntegrityLevel(ctx, IntegrityLevel::kFrozen).Check();
    }
    ctx->SetEmbedderDataV2(index, handler);
    return handler;
}

/// Create a transparent Proxy for a legacy platform object
/// 
/// This wraps the target in a Proxy that forwards all operations to the target
/// except for [[OwnPropertyKeys]] which returns keys in WebIDL order:
/// indexed → named → own → symbols
///
/// @param context - The V8 context
/// @param target - The legacy platform object to wrap
/// @param named_setter - Its interface has a named property setter (WebIDL
///   3.9.2 [[Set]] step 1.2), from its Meta.special_operations
/// @return Global handle to the Proxy, or nullptr on failure
Global<Object>* v8_CreateLegacyPlatformObjectProxy(Global<Context>* context, Global<Object>* target, bool named_setter) {
    if (!context || !target) return nullptr;

    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);
    Local<Object> local_target = target->Get(isolate);

    // The handler: the realm's, shared by every proxy of this kind in it
    // (LegacyPlatformObjectHandlerOf).
    Local<Object> handler = LegacyPlatformObjectHandlerOf(isolate, ctx, named_setter);

    // Create the Proxy
    MaybeLocal<Proxy> maybe_proxy = Proxy::New(ctx, local_target, handler);
    if (maybe_proxy.IsEmpty()) {
        return nullptr;
    }
    
    Local<Proxy> proxy = maybe_proxy.ToLocalChecked();
    return trackHandle(new Global<Object>(isolate, proxy.As<Object>()));
}

} // extern "C"

extern "C" void v8_FunctionTemplate_SetPrototypeProviderTemplate(Global<FunctionTemplate>* tpl, Global<FunctionTemplate>* provider) {
    if (!tpl || !provider) return;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    tpl->Get(isolate)->SetPrototypeProviderTemplate(provider->Get(isolate));
}

// ============================================================================
// ShadowRealm Support
// ============================================================================

/// Create a NEW Global<Context>* handle from an existing Global<Context>*
///
/// This is used when Zig needs to pass a context back to C++ as a Global handle.
/// The new handle is a copy (both refer to the same context) and is tracked for cleanup.
///
/// NOTE: The input context_global is a Global<Context>* from v8_Context_New* functions,
/// not a raw Context* pointer. All our FFI context functions return Global handles.
///
/// @param isolate - V8 Isolate
/// @param context_global - Global<Context>* (from v8_Context_New*, v8_Context_NewFromSnapshotAt, etc.)
/// @return NEW Global<Context>* that the caller owns, or nullptr on failure
extern "C" Global<Context>* v8_Context_GlobalHandle_New(Isolate* isolate, Global<Context>* context_global) {
    if (!isolate || !context_global) return nullptr;

    HandleScope handle_scope(isolate);
    Local<Context> local = context_global->Get(isolate);
    if (local.IsEmpty()) return nullptr;
    countContextGlobal();
    return trackHandle(new Global<Context>(isolate, local));
}

/// Dispose a Global<Context>* handle
///
/// @param handle - Global<Context>* to dispose
extern "C" void v8_Context_GlobalHandle_Dispose(Global<Context>* handle) {
    if (handle) {
        handle->Reset();
        delete handle;
    }
}

/// HostCreateShadowRealmContextCallback's dispatcher: one Zig function for
/// every agent (shadow_realm.shadowRealmContextCallback), which finds the
/// agent's ShadowRealm data by its isolate. Handed the initiator context as a
/// Global<Context>* it may read during the call; returns a Global<Context>*
/// of the new context, or null.
typedef void* (*ShadowRealmContextDispatch)(void* initiator_context);
// process-wide: the one Zig dispatcher (shadow_realm.shadowRealmContextCallback) every agent's isolate calls, finding the agent's ShadowRealm data by isolate; written at process start (protocol_agents.initializeEngine, before any agent's thread exists). It was a heap record every createAgent rewrote, on whatever thread made the agent. Atomic: a test starts the engine again on its own thread while another Browser's isolate reads it (ThreadSanitizer beside the many-Browsers variant's busy Browser, lane tsanfix1), storing the same function.
static std::atomic<ShadowRealmContextDispatch> g_shadow_realm_dispatch{nullptr};

/// V8 internal callback for ShadowRealm context creation
/// This is called by V8 when JavaScript code executes `new ShadowRealm()`
static MaybeLocal<Context> V8HostCreateShadowRealmContextCallback(Local<Context> initiator_context) {
    Isolate* isolate = Isolate::GetCurrent();  // V8 >= 14: no Context::GetIsolate (98282b9b8fa); a callback runs on its isolate
    void* result = nullptr;
    if (ShadowRealmContextDispatch dispatch = g_shadow_realm_dispatch.load(std::memory_order_acquire)) {
        // The initiator, for Zig to read during the call.
        Global<Context>* initiator_global = new Global<Context>(isolate, initiator_context);
        result = dispatch(initiator_global);
        delete initiator_global;
    }
    if (!result) {
        // v8-callbacks.h: "If the creation fails, the embedder must propagate
        // that exception by returning an empty MaybeLocal" - an empty result
        // with nothing pending is not one V8 can propagate.
        if (!isolate->HasPendingException()) {
            isolate->ThrowException(Exception::TypeError(
                String::NewFromUtf8Literal(isolate, "The ShadowRealm's realm could not be created")));
        }
        return MaybeLocal<Context>();
    }

    // Result is a Global<Context>* to the new ShadowRealm context, kept by
    // the agent's ShadowRealm data (its end disposes it).
    Global<Context>* new_context_global = static_cast<Global<Context>*>(result);
    return new_context_global->Get(isolate);
}

// ============================================================================
// Cross-Isolate Structured Clone (for Worker transfer)
// ============================================================================
//
// These functions support transferring ArrayBuffers between V8 isolates.
// Unlike v8_Value_StructuredCloneWithTransfer (which serializes+deserializes
// in the same isolate), these functions:
// 1. SerializeWithTransfer: Serialize to bytes, detach ArrayBuffers, return bytes
// 2. DeserializeWithTransfer: Deserialize bytes in current isolate, create new ArrayBuffers
//
// This is how Chromium and Node.js handle cross-thread/cross-isolate messaging.

extern "C" {

/// Data structure for ArrayBuffer transfer (passed across isolate boundary)
struct ArrayBufferTransferData {
    void* data;
    size_t size;
};

// ---- lane: serializable ----
/// The host's half of structured serialization for platform objects (HTML
/// 2.7.1 serializable objects): V8 sees a platform object as a host object
/// (an API wrapper) and asks the delegate to write or read it.
///
/// `write` serializes the platform object behind `object` (its wrapper,
/// BORROWED for the call) into `serializer` with the v8_ValueSerializer_*
/// primitives - its own fields with Write{Uint32,Uint64,Double,RawBytes}, and
/// its sub-serializations with WriteValue on the SAME serializer - and
/// returns true; or leaves an exception pending and returns false.
///
/// `read` reads one back from `deserializer` with the v8_ValueDeserializer_*
/// primitives (sub-deserializations with ReadValue) and returns its wrapper
/// as a Global the caller disposes; or nullptr with an exception pending.
///
/// `data` is handed back to both: the host's state for this one
/// serialization (its realm, forStorage).
struct HostObjectSteps {
    bool (*write)(void* data, Global<Value>* object, ValueSerializer* serializer);
    Global<Value>* (*read)(void* data, ValueDeserializer* deserializer);
    void* data;
};
// ---- end lane: serializable ----

/// What a structured serialization needs to know beyond the value - HTML's
/// forStorage, and the current realm's agent cluster (the host's
/// engine.HostHooks.agentClusterOf; 0 when the host keeps none).
struct StructuredSerializeOptions {
    bool for_storage;
    uint64_t agent_cluster;
    bool cross_origin_isolated;
};

} // extern "C"

// HostEnsureCanCompileWasmBytes, as the agent's AllowWasmCodeGenerationCallback
// asks it (defined with the code generation checks below).
static bool ProtocolAllowWasmCodeGeneration(Local<Context> context, Local<String> source);

// ============================================================================
// The serialized form: V8's payload, behind an envelope of the adapter's own
// ============================================================================
//
// What a serialization cannot write into V8's stream travels in front of it:
// each WebAssembly.Module's bytes (WebAssembly Web API section 3: the
// serialization steps keep [[Bytes]] and [[AgentCluster]]; V8 writes only a
// transfer id for a module, Delegate::GetWasmModuleTransferId), and the shape
// of each transferred ArrayBuffer when one is resizable (V8 writes only a
// transfer id for a transferred buffer). A
// serialization with nothing of that kind is V8's payload alone, which starts
// with V8's version tag (0xFF): forStorage records - IndexedDB's, on disk -
// never carry the envelope, so their format is V8's and nothing else.
//
//   u8      kEnvelopeTag
//   u8      kEnvelopeVersion
//   u64 LE  [[AgentCluster]] of the realm that serialized (0: none known)
//   u32 LE  module count, then each module's u32 LE length and wire bytes
//   u32 LE  transferred buffer count, then each buffer's u8 resizable and
//           u64 LE [[ArrayBufferMaxByteLength]], in transfer-list order
//   ...     V8's payload
//
// The transferred buffers' shapes are there because a transferred buffer's
// contents leave the engine as bytes (SerializedWithTransfer.array_buffers):
// StructuredSerializeWithTransfer step 5.4.1 keeps a resizable buffer's
// [[ArrayBufferMaxByteLength]] in its data holder ("ResizableArrayBuffer"),
// and StructuredDeserializeWithTransfer step 3.3 makes it resizable again with
// that maximum - which V8 then checks a length-tracking view against.
//
// This envelope is inline, without pointers into any realm or thread. Shared
// buffers additionally require their independently owned backing-store sidecar.
// A message is read on any thread, as often as it is delivered (a
// BroadcastChannel delivers one serialization to every channel), and freed as
// the bytes it is. The deserialization steps compile a module from its bytes
// in the target realm; V8's NativeModuleCache (keyed by the wire bytes) shares
// the compiled code with the sender's module while that is alive, which is the
// reuse the spec's note recommends.
//
// Stated gap: a module compiled with compile options (builtins,
// importedStringConstants) is recompiled without them - the spec's [[Bytes]]
// carries none, and V8's public API compiles bytes only without
// (WasmModuleObject::Compile).

static constexpr uint8_t kEnvelopeTag = 0xC2;
/// 2: the transferred buffers' shapes follow the modules. Nothing stores an
/// envelope (forStorage records never carry one), so no reader of version 1
/// remains.
static constexpr uint8_t kEnvelopeVersion = 2;

/// A transferred ArrayBuffer's shape: whether it is resizable, and its
/// [[ArrayBufferMaxByteLength]] when it is.
struct TransferredBufferShape {
    bool resizable;
    uint64_t max_byte_length;
};

/// An owning message sidecar: shared backing stores, never V8 handles. The
/// store retains its allocator (Isolate::CreateParams uses a shared allocator),
/// so it survives the sending isolate. V8's d8 serializer uses this same design
/// (13.1 d8.cc GetSharedArrayBufferId / GetSharedArrayBufferFromId).
struct CraneSharedMemory {
    std::atomic<size_t> refs{1};
    uint64_t agent_cluster;
    std::vector<std::shared_ptr<BackingStore>> stores;
    explicit CraneSharedMemory(uint64_t cluster) : agent_cluster(cluster) {}
};

/// What travels in the envelope.
struct SerializationAttachments {
    uint64_t agent_cluster = 0;
    std::vector<std::vector<uint8_t>> wasm_modules;
    /// Empty unless a transferred buffer is resizable; else one per
    /// transferred buffer.
    std::vector<TransferredBufferShape> buffers;

    bool empty() const { return wasm_modules.empty() && buffers.empty(); }
};

static void appendLE(std::vector<uint8_t>& out, uint64_t value, int bytes) {
    for (int i = 0; i < bytes; i++) out.push_back(static_cast<uint8_t>(value >> (8 * i)));
}

static bool readLE(const uint8_t*& cursor, const uint8_t* end, int bytes, uint64_t* value) {
    if (end - cursor < bytes) return false;
    uint64_t result = 0;
    for (int i = 0; i < bytes; i++) result |= static_cast<uint64_t>(cursor[i]) << (8 * i);
    cursor += bytes;
    *value = result;
    return true;
}

/// `payload` (V8's, `size` bytes) behind the envelope of `attachments`, in a
/// malloc'd buffer v8_Free_SerializedBuffer frees; `payload` is freed. Null
/// when out of memory (`payload` freed too).
static uint8_t* wrapInEnvelope(const SerializationAttachments& attachments, uint8_t* payload, size_t size, size_t* out_size) {
    std::vector<uint8_t> header;
    header.push_back(kEnvelopeTag);
    header.push_back(kEnvelopeVersion);
    appendLE(header, attachments.agent_cluster, 8);
    appendLE(header, attachments.wasm_modules.size(), 4);
    for (const auto& bytes : attachments.wasm_modules) {
        appendLE(header, bytes.size(), 4);
        header.insert(header.end(), bytes.begin(), bytes.end());
    }
    appendLE(header, attachments.buffers.size(), 4);
    for (const auto& shape : attachments.buffers) {
        header.push_back(shape.resizable ? 1 : 0);
        appendLE(header, shape.max_byte_length, 8);
    }
    uint8_t* whole = static_cast<uint8_t*>(malloc(header.size() + size));
    if (!whole) {
        free(payload);
        return nullptr;
    }
    memcpy(whole, header.data(), header.size());
    memcpy(whole + header.size(), payload, size);
    free(payload);
    *out_size = header.size() + size;
    return whole;
}

/// Split `data` into its attachments and V8's payload. False for an envelope
/// that is malformed; a serialization without one is all payload.
static bool openEnvelope(const uint8_t* data, size_t size, SerializationAttachments* attachments, const uint8_t** payload, size_t* payload_size) {
    if (size == 0 || data[0] != kEnvelopeTag) {
        *payload = data;
        *payload_size = size;
        return true;
    }
    const uint8_t* cursor = data + 1;
    const uint8_t* end = data + size;
    uint64_t version = 0, count = 0;
    if (!readLE(cursor, end, 1, &version) || version != kEnvelopeVersion) return false;
    if (!readLE(cursor, end, 8, &attachments->agent_cluster)) return false;
    if (!readLE(cursor, end, 4, &count)) return false;
    for (uint64_t i = 0; i < count; i++) {
        uint64_t length = 0;
        if (!readLE(cursor, end, 4, &length)) return false;
        if (static_cast<uint64_t>(end - cursor) < length) return false;
        attachments->wasm_modules.emplace_back(cursor, cursor + length);
        cursor += length;
    }
    uint64_t buffers = 0;
    if (!readLE(cursor, end, 4, &buffers)) return false;
    for (uint64_t i = 0; i < buffers; i++) {
        uint64_t resizable = 0, max_byte_length = 0;
        if (!readLE(cursor, end, 1, &resizable) || resizable > 1) return false;
        if (!readLE(cursor, end, 8, &max_byte_length)) return false;
        attachments->buffers.push_back({resizable == 1, max_byte_length});
    }
    *payload = cursor;
    *payload_size = static_cast<size_t>(end - cursor);
    return true;
}

/// HTML StructuredSerializeInternal throws a "DataCloneError" DOMException for
/// a value it cannot serialize. V8's own default is a plain Error, so the
/// platform supplies the exception through the serializer's delegate - the
/// design Blink uses in V8ScriptValueSerializer::ThrowDataCloneError.
///
/// V8 also asks the delegate about host objects (platform objects - DOM
/// nodes and the like, which it sees as API wrappers) and SharedArrayBuffers,
/// and its defaults for both throw a plain Error too. Host objects use their
/// [Serializable] steps. Shared buffers use an owned backing-store sidecar only
/// for non-storage serialization in a cross-origin-isolated agent cluster;
/// unsupported platform objects and disallowed sharing throw DataCloneError.
class DataCloneErrorDelegate final : public ValueSerializer::Delegate {
 public:
    explicit DataCloneErrorDelegate(Isolate* isolate, const HostObjectSteps* host = nullptr,
                                    const StructuredSerializeOptions* options = nullptr, bool carries_shared_memory = false)
        : isolate_(isolate), host_(host) {
        if (options) {
            for_storage_ = options->for_storage;
            attachments_.agent_cluster = options->agent_cluster;
            shared_allowed_ = carries_shared_memory && options->cross_origin_isolated;
        }
    }

    /// What the serialization put in its envelope: its modules' bytes.
    const SerializationAttachments& attachments() const { return attachments_; }
    CraneSharedMemory* takeSharedMemory() { return shared_memory_.release(); }

    /// The serializer this delegate serves: WriteHostObject hands it to the
    /// host's steps, which write into it. Set right after the serializer is
    /// made (it takes the delegate in its constructor), as Blink's
    /// V8ScriptValueSerializer keeps its serializer_.
    void SetSerializer(ValueSerializer* serializer) { serializer_ = serializer; }

    void ThrowDataCloneError(Local<String> message) override {
        Local<Context> context = isolate_->GetCurrentContext();
        if (!context.IsEmpty()) {
            Local<Value> ctor;
            if (context->Global()
                    ->Get(context, String::NewFromUtf8Literal(isolate_, "DOMException"))
                    .ToLocal(&ctor) &&
                ctor->IsFunction()) {
                Local<Value> args[] = {message, String::NewFromUtf8Literal(isolate_, "DataCloneError")};
                Local<Object> exception;
                if (ctor.As<Function>()->NewInstance(context, 2, args).ToLocal(&exception)) {
                    isolate_->ThrowException(exception);
                    return;
                }
            }
        }
        // No DOMException to construct (a context without the interface): the
        // message still says what failed. ThrowException replaces anything the
        // lookup above left pending.
        isolate_->ThrowException(Exception::Error(message));
    }

    /// HTML StructuredSerializeInternal steps 19-20 and 26.3: a platform
    /// object whose primary interface is [Serializable] runs its
    /// serialization steps (the host's `write`); any other throws a
    /// "DataCloneError" DOMException. V8 has already written its host-object
    /// tag and assigned the object its id in the serializer's memory
    /// (value-serializer.cc, WriteJSReceiver then WriteHostObject), so a
    /// sub-serialization the steps write through WriteValue on this same
    /// serializer shares `memory` with the whole graph: identity and cycles
    /// hold across it.
    /// Which API objects are platform objects (13.1 value-serializer.cc
    /// ValueSerializer::IsHostObject, asked for a JS_API_OBJECT): V8's own
    /// answer, with no custom host objects, is "it has embedder fields" - and
    /// a node wrapper has none since the wrapper redesign's P4 (its instance
    /// is behind Object::Wrap), so V8 alone would serialize a node as an
    /// ordinary object instead of throwing. The delegate answers, as Blink's
    /// does (V8ScriptValueSerializer::HasCustomHostObject true; its
    /// IsHostObject answers IsApiWrapper, Blink's wrappers being all on the
    /// CppHeap): V8's embedder-field rule, so no other object's answer
    /// changes, or a node anchor behind Object::Wrap.
    bool HasCustomHostObject(Isolate*) override { return true; }

    Maybe<bool> IsHostObject(Isolate* isolate, Local<Object> object) override {
        NODE_ANCHOR_IN_FRAME(isolate);
        return Just(object->InternalFieldCount() > 0 || platformAnchorOf(isolate, object) != nullptr || nodeAnchorOf(isolate, object) != nullptr);
    }

    Maybe<bool> WriteHostObject(Isolate* isolate, Local<Object> object) override {
        if (host_ == nullptr || host_->write == nullptr || serializer_ == nullptr) {
            ThrowDataCloneError(String::NewFromUtf8Literal(isolate, "A platform object could not be cloned."));
            return Nothing<bool>();
        }
        Global<Value> borrowed(isolate, object);
        bool written = host_->write(host_->data, &borrowed, serializer_);
        borrowed.Reset();
        if (written) return Just(true);
        if (!isolate->HasPendingException()) {
            ThrowDataCloneError(String::NewFromUtf8Literal(isolate, "A platform object could not be cloned."));
        }
        return Nothing<bool>();
    }

    Maybe<uint32_t> GetSharedArrayBufferId(Isolate* isolate, Local<SharedArrayBuffer> shared_array_buffer) override {
        // HTML StructuredSerializeInternal: reject storage and non-isolated
        // settings before retaining any shared memory. An unknown cluster is
        // not sufficient authority to send it to another agent.
        if (for_storage_ || !shared_allowed_ || attachments_.agent_cluster == 0) {
            ThrowDataCloneError(String::NewFromUtf8Literal(isolate, "A SharedArrayBuffer could not be cloned."));
            return Nothing<uint32_t>();
        }
        if (!shared_memory_) shared_memory_ = std::make_unique<CraneSharedMemory>(attachments_.agent_cluster);
        const uint32_t id = static_cast<uint32_t>(shared_memory_->stores.size());
        shared_memory_->stores.push_back(shared_array_buffer->GetBackingStore());
        return Just(id);
    }

    /// WebAssembly Web API section 3, a Module's serialization steps. V8 has
    /// done StructuredSerializeInternal's memory (a module met twice is a
    /// back-reference, value-serializer.cc WriteJSReceiver), so this runs once
    /// per module of the value.
    ///   1. If forStorage is true, throw a "DataCloneError" DOMException.
    ///   2. serialized.[[Bytes]]: the sub-serialization of value.[[Bytes]] -
    ///      its wire bytes, in the envelope.
    ///   3. serialized.[[AgentCluster]]: the current realm's agent cluster -
    ///      the envelope's, one for the whole serialization.
    /// V8 writes the module as this transfer id, the bytes' index.
    Maybe<uint32_t> GetWasmModuleTransferId(Isolate* isolate, Local<WasmModuleObject> module) override {
        // 1.
        if (for_storage_) {
            ThrowDataCloneError(String::NewFromUtf8Literal(isolate, "A WebAssembly.Module cannot be serialized for storage."));
            return Nothing<uint32_t>();
        }
        // 2.
        std::span<const uint8_t> bytes = module->GetCompiledModule().GetWireBytesRef();
        attachments_.wasm_modules.emplace_back(bytes.data(), bytes.data() + bytes.size());
        return Just(static_cast<uint32_t>(attachments_.wasm_modules.size() - 1));
    }

 private:
    Isolate* isolate_;
    const HostObjectSteps* host_;
    ValueSerializer* serializer_ = nullptr;
    bool for_storage_ = false;
    bool shared_allowed_ = false;
    std::unique_ptr<CraneSharedMemory> shared_memory_;
    SerializationAttachments attachments_;
};

/// Throw HTML's "DataCloneError" DOMException in the current context, with
/// `message` - what the host's steps throw when a platform object cannot be
/// (de)serialized. The same exception DataCloneErrorDelegate throws.
static void throwDataCloneErrorIn(Isolate* isolate, Local<String> message) {
    DataCloneErrorDelegate thrower(isolate);
    thrower.ThrowDataCloneError(message);
}

/// A deserialization failure, thrown WITHOUT running script. V8 deserializes
/// inside a DisallowJavascriptExecutionScope (value-serializer.cc,
/// ValueDeserializer::ReadObject), and constructing the DOMException through
/// its JavaScript constructor (as DataCloneErrorDelegate does when
/// serializing) runs the binding's constructor callback, which runs script -
/// a V8 fatal error ("Invoke in DisallowJavascriptExecutionScope"). Every
/// caller of a deserialization catches the exception (TryCatch) and reports
/// the failure itself - a "messageerror" event, or a DataCloneError the
/// binding throws once V8 has returned - so an Error made by V8's factory,
/// which runs no script, is all that is needed here.
static void throwDeserializationError(Isolate* isolate, Local<String> message) {
    isolate->ThrowException(Exception::Error(message));
}

/// The deserializing half of HostObjectSteps: V8's ValueDeserializer asks
/// for a host object where the serializer wrote one.
///
/// HTML StructuredDeserialize steps 22-24: the host's `read` makes "a new
/// instance of the interface identified by" the record's [[Type]] in the
/// target realm and runs its deserialization steps, reading its
/// sub-deserializations with ReadValue on this same deserializer, so they
/// share `memory` with the whole graph.
///
/// Known gap: V8 takes the host object's id before calling this
/// (value-serializer.cc ReadHostObject: `next_id_++`) but registers the
/// object under it only after this returns (AddObjectWithID), whereas the
/// spec sets memory[serialized] before the deserialization steps (step 23
/// before 24). So a sub-value that refers back to its own platform object
/// cannot be resolved here. No [Serializable] interface's steps write one
/// today: their sub-values are made by the user agent (a quad's points, an
/// ImageData's data).
class HostObjectDeserializerDelegate final : public ValueDeserializer::Delegate {
 public:
    explicit HostObjectDeserializerDelegate(const HostObjectSteps* host, const SerializationAttachments* attachments = nullptr,
                                            uint64_t agent_cluster = 0, const CraneSharedMemory* shared_memory = nullptr,
                                            bool cross_origin_isolated = false)
        : host_(host), attachments_(attachments), agent_cluster_(agent_cluster),
          shared_memory_(shared_memory), cross_origin_isolated_(cross_origin_isolated) {}
    void SetDeserializer(ValueDeserializer* deserializer) { deserializer_ = deserializer; }

    /// WebAssembly Web API section 3, a Module's deserialization steps, in
    /// the target realm (the current context):
    ///   1-2. bytes: serialized.[[Bytes]] - the envelope's, by transfer id.
    ///   3. If targetRealm's agent cluster is not serialized.[[AgentCluster]],
    ///      throw a "DataCloneError" DOMException. (0 on either side: a host
    ///      that keeps no agent clusters, which checks nothing.)
    ///   4. Compile a WebAssembly module from bytes - whose step 1 in the CSP
    ///      integration is HostEnsureCanCompileWasmBytes(targetRealm), which
    ///      reports a "wasm-eval" violation and throws a CompileError when a
    ///      policy blocks it.
    /// Both throws run no script (V8 deserializes in a
    /// DisallowJavascriptExecutionScope): the caller reports the failure - a
    /// messageerror.
    MaybeLocal<WasmModuleObject> GetWasmModuleFromId(Isolate* isolate, uint32_t transfer_id) override {
        if (attachments_ == nullptr || transfer_id >= attachments_->wasm_modules.size()) {
            throwDeserializationError(isolate, String::NewFromUtf8Literal(isolate, "DataCloneError: a WebAssembly.Module's bytes are missing."));
            return MaybeLocal<WasmModuleObject>();
        }
        // 3.
        if (attachments_->agent_cluster != 0 && agent_cluster_ != 0 && attachments_->agent_cluster != agent_cluster_) {
            throwDeserializationError(isolate, String::NewFromUtf8Literal(isolate, "DataCloneError: a WebAssembly.Module cannot be received in another agent cluster."));
            return MaybeLocal<WasmModuleObject>();
        }
        // 4.
        Local<Context> context = isolate->GetCurrentContext();
        if (context.IsEmpty() || !ProtocolAllowWasmCodeGeneration(context, String::Empty(isolate))) {
            throwDeserializationError(isolate, String::NewFromUtf8Literal(isolate, "CompileError: WebAssembly compilation is blocked in the target realm."));
            return MaybeLocal<WasmModuleObject>();
        }
        const std::vector<uint8_t>& bytes = attachments_->wasm_modules[transfer_id];
        return WasmModuleObject::Compile(isolate, std::span<const uint8_t>(bytes.data(), bytes.size()));
    }

    MaybeLocal<SharedArrayBuffer> GetSharedArrayBufferFromId(Isolate* isolate, uint32_t id) override {
        // HTML StructuredDeserialize: target settings must permit sharing and
        // [[AgentCluster]] must match, before creating a receiver-side object.
        if (!cross_origin_isolated_ || !shared_memory_ ||
            shared_memory_->agent_cluster != agent_cluster_ || id >= shared_memory_->stores.size()) {
            throwDeserializationError(isolate, String::NewFromUtf8Literal(isolate, "DataCloneError: shared memory is not available in this agent cluster."));
            return {};
        }
        // SharedArrayBuffer::New preserves a growable BackingStore's maximum
        // and shared length; copying its bytes would lose both and atomicity.
        return SharedArrayBuffer::New(isolate, shared_memory_->stores[id]);
    }

    MaybeLocal<Object> ReadHostObject(Isolate* isolate) override {
        if (host_ == nullptr || host_->read == nullptr || deserializer_ == nullptr) {
            throwDeserializationError(isolate, String::NewFromUtf8Literal(isolate, "A platform object could not be deserialized."));
            return MaybeLocal<Object>();
        }
        Global<Value>* made = host_->read(host_->data, deserializer_);
        if (made == nullptr) {
            if (!isolate->HasPendingException()) {
                throwDeserializationError(isolate, String::NewFromUtf8Literal(isolate, "A platform object could not be deserialized."));
            }
            return MaybeLocal<Object>();
        }
        Local<Value> value = made->Get(isolate);
        v8_Global_Dispose(made);
        if (value.IsEmpty() || !value->IsObject()) {
            throwDeserializationError(isolate, String::NewFromUtf8Literal(isolate, "A platform object could not be deserialized."));
            return MaybeLocal<Object>();
        }
        return value.As<Object>();
    }

 private:
    const HostObjectSteps* host_;
    const SerializationAttachments* attachments_;
    uint64_t agent_cluster_;
    const CraneSharedMemory* shared_memory_;
    bool cross_origin_isolated_;
    ValueDeserializer* deserializer_ = nullptr;
};

/// Serialize a V8 value with ArrayBuffer transfer, returning raw bytes.
///
/// This function:
/// 1. Copies ArrayBuffer data before detaching (so it survives detach)
/// 2. Serializes the value using V8 ValueSerializer with transfer markers
/// 3. Detaches the original ArrayBuffers (making byteLength = 0)
/// 4. Returns the serialized bytes for cross-isolate transfer
///
/// @param value - The value to serialize
/// @param transfer_list - Array of ArrayBuffer Global handles to transfer
/// @param transfer_count - Number of ArrayBuffers to transfer
/// @param out_size - OUTPUT: Size of serialized data
/// @param out_arraybuffer_data - OUTPUT: Array of ArrayBufferTransferData (caller provides)
/// @param error_code - OUTPUT: 0=success, 1=DataCloneError, 2=other error
/// @param delegate - null for V8's defaults (a plain Error for anything
///                   uncloneable, reported as code 2); a DataCloneErrorDelegate
///                   for the spec's exceptions, reported as code 3
/// @return Pointer to serialized data (caller must free with v8_Free_SerializedBuffer)
static uint8_t* serializeWithTransfer(
    Global<Value>* value,
    Global<Value>** transfer_list,
    size_t transfer_count,
    size_t* out_size,
    ArrayBufferTransferData* out_arraybuffer_data,
    int* error_code,
    DataCloneErrorDelegate* delegate
) {
    if (error_code) *error_code = 0;
    if (out_size) *out_size = 0;

    if (!value || value->IsEmpty()) {
        if (error_code) *error_code = 2;
        return nullptr;
    }

    Isolate* isolate = Isolate::GetCurrent();
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);

    Local<Context> ctx = isolate->GetCurrentContext();
    if (ctx.IsEmpty()) {
        if (error_code) *error_code = 2;
        return nullptr;
    }

    Local<Value> val = value->Get(isolate);

    // Step 1: Collect and validate ArrayBuffers, copy their data
    std::set<void*> seen_buffers;
    std::vector<Local<ArrayBuffer>> array_buffers_to_transfer;
    std::vector<std::pair<void*, size_t>> copied_data;  // Data copied before detach
    // Step 5.4.1-5.4.2: each buffer's data holder type - "ResizableArrayBuffer"
    // with its [[ArrayBufferMaxByteLength]], or "ArrayBuffer".
    std::vector<TransferredBufferShape> shapes;
    bool any_resizable = false;

    for (size_t i = 0; i < transfer_count; i++) {
        if (!transfer_list[i] || transfer_list[i]->IsEmpty()) {
            if (error_code) *error_code = 1;  // DataCloneError
            return nullptr;
        }

        Local<Value> transfer_val = transfer_list[i]->Get(isolate);

        if (!transfer_val->IsArrayBuffer()) {
            if (error_code) *error_code = 1;  // DataCloneError
            return nullptr;
        }

        Local<ArrayBuffer> ab = transfer_val.As<ArrayBuffer>();

        // Check for duplicate
        std::shared_ptr<BackingStore> backing_store = ab->GetBackingStore();
        void* data_ptr = backing_store ? backing_store->Data() : nullptr;

        if (seen_buffers.find(data_ptr) != seen_buffers.end()) {
            if (error_code) *error_code = 1;  // DataCloneError - duplicate
            return nullptr;
        }
        seen_buffers.insert(data_ptr);

        // Check if already detached
        if (ab->WasDetached()) {
            for (auto& d : copied_data) {
                if (d.first) free(d.first);
            }
            if (error_code) *error_code = 1;  // DataCloneError
            return nullptr;
        }

        // ECMAScript DetachArrayBuffer (StructuredSerializeWithTransfer step
        // 5.4.3) throws a TypeError for a buffer whose [[ArrayBufferDetachKey]]
        // is not undefined - a WebAssembly.Memory's - and V8's Detach on one is
        // a fatal CHECK. Refused here, before anything is detached, so a
        // failed transfer leaves every buffer of the list attached. Code 3:
        // the TypeError is pending.
        if (!ab->IsDetachable()) {
            for (auto& d : copied_data) {
                if (d.first) free(d.first);
            }
            isolate->ThrowException(Exception::TypeError(
                String::NewFromUtf8Literal(isolate, "An ArrayBuffer in the transfer list cannot be detached")));
            if (error_code) *error_code = 3;
            return nullptr;
        }

        // Copy data BEFORE serialization/detach
        size_t byte_length = backing_store ? backing_store->ByteLength() : 0;
        void* data_copy = nullptr;
        if (byte_length > 0 && data_ptr) {
            data_copy = malloc(byte_length);
            if (!data_copy) {
                // Clean up previous allocations
                for (auto& d : copied_data) {
                    if (d.first) free(d.first);
                }
                if (error_code) *error_code = 2;  // Out of memory
                return nullptr;
            }
            memcpy(data_copy, data_ptr, byte_length);
        }

        array_buffers_to_transfer.push_back(ab);
        copied_data.push_back({data_copy, byte_length});
        const bool resizable = ab->IsResizableByUserJavaScript();
        shapes.push_back({resizable, resizable ? static_cast<uint64_t>(ab->MaxByteLength()) : 0});
        any_resizable = any_resizable || resizable;

        // Fill out the output arraybuffer data
        if (out_arraybuffer_data) {
            out_arraybuffer_data[i].data = data_copy;
            out_arraybuffer_data[i].size = byte_length;
        }
    }

    // Step 2: Serialize the value using V8's ValueSerializer
    ValueSerializer serializer(isolate, delegate);
    if (delegate) delegate->SetSerializer(&serializer);
    serializer.WriteHeader();

    // Register ArrayBuffers for transfer (tells V8 to use transfer IDs)
    for (size_t i = 0; i < array_buffers_to_transfer.size(); i++) {
        serializer.TransferArrayBuffer(static_cast<uint32_t>(i), array_buffers_to_transfer[i]);
    }

    Maybe<bool> write_result = serializer.WriteValue(ctx, val);
    if (write_result.IsNothing() || !write_result.FromJust()) {
        // Serialization failed - clean up copied data
        for (auto& d : copied_data) {
            if (d.first) free(d.first);
        }
        // WriteValue fails only by throwing: the delegate's DataCloneError, or
        // whatever script threw from a getter or a proxy trap mid-walk. With the
        // delegate that exception is the right one to surface, and code 3 tells
        // the caller it is already pending.
        if (error_code) *error_code = delegate ? 3 : 2;
        return nullptr;
    }

    // Get the serialized data
    std::pair<uint8_t*, size_t> buffer = serializer.Release();
    uint8_t* data = buffer.first;
    size_t size = buffer.second;

    // What V8's stream cannot hold - the modules' bytes, the transferred
    // buffers' shapes - goes in front of it.
    if (data != nullptr && size > 0) {
        SerializationAttachments attachments;
        if (delegate) attachments = delegate->attachments();
        if (any_resizable) attachments.buffers = shapes;
        if (!attachments.empty()) data = wrapInEnvelope(attachments, data, size, &size);
    }

    if (data == nullptr || size == 0) {
        for (auto& d : copied_data) {
            if (d.first) free(d.first);
        }
        if (error_code) *error_code = 2;
        return nullptr;
    }

    // Step 3: Detach the original ArrayBuffers
    // This makes buffer.byteLength === 0 in JavaScript
    for (auto& ab : array_buffers_to_transfer) {
        ab->Detach(Local<Value>());
    }

    *out_size = size;
    return data;
}

extern "C" {

/// Serialize a V8 value with ArrayBuffer transfer, returning raw bytes, with
/// V8's default exceptions. See serializeWithTransfer.
uint8_t* v8_Value_SerializeWithTransfer_CrossIsolate(
    Global<Value>* value,
    Global<Value>** transfer_list,
    size_t transfer_count,
    size_t* out_size,
    ArrayBufferTransferData* out_arraybuffer_data,
    int* error_code
) {
    return serializeWithTransfer(value, transfer_list, transfer_count, out_size,
                                 out_arraybuffer_data, error_code, nullptr);
}

/// HTML StructuredSerializeWithTransfer, with the exceptions the spec names.
///
/// The same wire format as v8_Value_SerializeWithTransfer_CrossIsolate -
/// v8_Value_DeserializeWithTransfer_CrossIsolate reads either - but a value
/// that cannot be serialized throws a "DataCloneError" DOMException, and an
/// exception script throws mid-serialization propagates as it is. Both leave
/// the exception pending and report error_code 3; the caller must return to
/// V8 without throwing another. Codes 0-2 are as for the CrossIsolate
/// function, and code 1 (a bad transfer list) has thrown nothing yet.
///
/// `host` (nullable) is how a platform object is serialized: its interface's
/// serialization steps, through the host's `write` (HostObjectSteps). With
/// none, every platform object throws DataCloneError.
///
/// `options`: forStorage (a WebAssembly.Module then throws DataCloneError),
/// and the current realm's agent cluster, which a module's record keeps.
uint8_t* v8_Value_StructuredSerializeWithTransfer(
    Global<Value>* value,
    Global<Value>** transfer_list,
    size_t transfer_count,
    size_t* out_size,
    ArrayBufferTransferData* out_arraybuffer_data,
    int* error_code,
    const HostObjectSteps* host,
    const StructuredSerializeOptions* options
) {
    DataCloneErrorDelegate delegate(Isolate::GetCurrent(), host, options);
    return serializeWithTransfer(value, transfer_list, transfer_count, out_size,
                                 out_arraybuffer_data, error_code, &delegate);
}

/// HTML's message serialization, with an independently owned shared-memory
/// sidecar. It is handed out only on success; every failure drops it here.
uint8_t* v8_Value_StructuredSerializeWithSharedMemory(
    Global<Value>* value, Global<Value>** transfer_list, size_t transfer_count,
    size_t* out_size, ArrayBufferTransferData* out_arraybuffer_data, int* error_code,
    const HostObjectSteps* host, const StructuredSerializeOptions* options,
    CraneSharedMemory** out_shared_memory) {
    *out_shared_memory = nullptr;
    DataCloneErrorDelegate delegate(Isolate::GetCurrent(), host, options, true);
    uint8_t* bytes = serializeWithTransfer(value, transfer_list, transfer_count, out_size,
                                          out_arraybuffer_data, error_code, &delegate);
    if (bytes) *out_shared_memory = delegate.takeSharedMemory();
    return bytes;
}

void v8_SharedMemory_Retain(CraneSharedMemory* memory) {
    memory->refs.fetch_add(1, std::memory_order_relaxed);
}
void v8_SharedMemory_Release(CraneSharedMemory* memory) {
    if (memory->refs.fetch_sub(1, std::memory_order_acq_rel) == 1) delete memory;
}
/// Test-only, while the caller owns a reference. No production counter added.
size_t v8_test_SharedMemory_RefCount(const CraneSharedMemory* memory) {
    return memory->refs.load(std::memory_order_acquire);
}

/// Deserialize V8 structured clone data with ArrayBuffer transfer.
///
/// This function is called in the DESTINATION isolate to recreate values.
///
/// @param serialized_data - The serialized bytes from v8_Value_SerializeWithTransfer_CrossIsolate
/// @param serialized_size - Size of serialized data
/// @param arraybuffer_data - Array of ArrayBuffer data to recreate
/// @param arraybuffer_count - Number of ArrayBuffers to recreate
/// @param error_code - OUTPUT: 0=success, 1=DataCloneError, 2=other error
/// @param host - nullable: how a platform object is deserialized (its
///               interface's deserialization steps, through the host's
///               `read`); with none, a serialized platform object fails
/// @param agent_cluster - the target realm's agent cluster (0: none known),
///               which a WebAssembly.Module's record must name
/// @return Global<Value>* to the deserialized value in current isolate
static Global<Value>* deserializeWithSharedMemory(
    const uint8_t* serialized_data,
    size_t serialized_size,
    const ArrayBufferTransferData* arraybuffer_data,
    size_t arraybuffer_count,
    int* error_code,
    const HostObjectSteps* host,
    uint64_t agent_cluster,
    const CraneSharedMemory* shared_memory,
    bool cross_origin_isolated
) {
    if (error_code) *error_code = 0;

    if (!serialized_data || serialized_size == 0) {
        if (error_code) *error_code = 2;
        return nullptr;
    }

    // The envelope's attachments, and V8's payload behind them.
    SerializationAttachments attachments;
    const uint8_t* payload = nullptr;
    size_t payload_size = 0;
    if (!openEnvelope(serialized_data, serialized_size, &attachments, &payload, &payload_size) || payload_size == 0) {
        if (error_code) *error_code = 2;
        return nullptr;
    }

    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);

    // A failure is reported through error_code and never left pending. Every
    // caller runs from a task or a timer, with no JavaScript frame to receive
    // an exception, and HTML's answer to a failed deserialize is a
    // `messageerror` event rather than a throw.
    TryCatch try_catch(isolate);

    Local<Context> ctx = isolate->GetCurrentContext();
    if (ctx.IsEmpty()) {
        if (error_code) *error_code = 2;
        return nullptr;
    }

    // Create ValueDeserializer
    HostObjectDeserializerDelegate delegate(host, &attachments, agent_cluster, shared_memory, cross_origin_isolated);
    ValueDeserializer deserializer(isolate, payload, payload_size, &delegate);
    delegate.SetDeserializer(&deserializer);

    // Create new ArrayBuffers in this isolate from the transferred data:
    // StructuredDeserializeWithTransfer steps 3.2-3.3, an "ArrayBuffer" data
    // holder fixed-length, a "ResizableArrayBuffer" one resizable with its
    // [[ArrayBufferMaxByteLength]].
    std::vector<Local<ArrayBuffer>> transferred_buffers;
    for (size_t i = 0; i < arraybuffer_count; i++) {
        size_t byte_length = arraybuffer_data[i].size;

        Local<ArrayBuffer> ab;
        if (i < attachments.buffers.size() && attachments.buffers[i].resizable) {
            const uint64_t max_byte_length = attachments.buffers[i].max_byte_length;
            // The sender's buffer had these lengths: anything else is not a
            // serialization of ours (NewResizableBackingStore CHECKs them).
            if (byte_length > max_byte_length || max_byte_length > TypedArray::kMaxByteLength) {
                if (error_code) *error_code = 2;
                return nullptr;
            }
            std::unique_ptr<BackingStore> store = ArrayBuffer::NewResizableBackingStore(byte_length, static_cast<size_t>(max_byte_length));
            ab = ArrayBuffer::New(isolate, std::shared_ptr<BackingStore>(std::move(store)));
        } else {
            ab = ArrayBuffer::New(isolate, byte_length);
        }
        if (byte_length > 0 && arraybuffer_data[i].data && ab->GetBackingStore()) {
            memcpy(ab->GetBackingStore()->Data(), arraybuffer_data[i].data, byte_length);
        }

        deserializer.TransferArrayBuffer(static_cast<uint32_t>(i), ab);
        transferred_buffers.push_back(ab);
    }

    // Read header
    Maybe<bool> header_result = deserializer.ReadHeader(ctx);
    if (header_result.IsNothing() || !header_result.FromJust()) {
        if (error_code) *error_code = 2;
        return nullptr;
    }

    // Read the value
    MaybeLocal<Value> result = deserializer.ReadValue(ctx);
    if (result.IsEmpty()) {
        if (error_code) *error_code = 2;
        return nullptr;
    }

    Local<Value> deserialized = result.ToLocalChecked();
    return trackHandle(new Global<Value>(isolate, deserialized));
}

Global<Value>* v8_Value_DeserializeWithTransfer_CrossIsolate(
    const uint8_t* bytes, size_t size, const ArrayBufferTransferData* buffers,
    size_t count, int* error_code, const HostObjectSteps* host, uint64_t cluster) {
    return deserializeWithSharedMemory(bytes, size, buffers, count, error_code, host, cluster, nullptr, false);
}

Global<Value>* v8_Value_DeserializeWithSharedMemory(
    const uint8_t* bytes, size_t size, const ArrayBufferTransferData* buffers,
    size_t count, int* error_code, const HostObjectSteps* host, uint64_t cluster,
    const CraneSharedMemory* shared_memory, bool cross_origin_isolated) {
    return deserializeWithSharedMemory(bytes, size, buffers, count, error_code, host, cluster,
                                       shared_memory, cross_origin_isolated);
}

// ---- lane: serializable ----
// The primitives a host's HostObjectSteps write and read a platform object's
// record with, for use only inside its `write` / `read` (V8: "For use during
// an override of Delegate::WriteHostObject" / "ReadHostObject"). Integers
// are V8's varints, doubles their bits, raw bytes as they are.

void v8_ValueSerializer_WriteUint32(ValueSerializer* serializer, uint32_t value) {
    serializer->WriteUint32(value);
}

void v8_ValueSerializer_WriteUint64(ValueSerializer* serializer, uint64_t value) {
    serializer->WriteUint64(value);
}

void v8_ValueSerializer_WriteDouble(ValueSerializer* serializer, double value) {
    serializer->WriteDouble(value);
}

void v8_ValueSerializer_WriteRawBytes(ValueSerializer* serializer, const void* source, size_t length) {
    if (length > 0) serializer->WriteRawBytes(source, length);
}

/// HTML "sub-serialization" of `value` (BORROWED): StructuredSerializeInternal
/// on the same serializer, so with the same memory. False with the exception
/// pending (a value that cannot be cloned, a getter that threw).
bool v8_ValueSerializer_WriteValue(ValueSerializer* serializer, Global<Value>* value) {
    if (!serializer || !value || value->IsEmpty()) return false;
    Isolate* isolate = Isolate::GetCurrent();
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);
    Local<Context> context = isolate->GetCurrentContext();
    if (context.IsEmpty()) return false;
    Maybe<bool> written = serializer->WriteValue(context, value->Get(isolate));
    return written.IsJust() && written.FromJust();
}

bool v8_ValueDeserializer_ReadUint32(ValueDeserializer* deserializer, uint32_t* value) {
    return deserializer->ReadUint32(value);
}

bool v8_ValueDeserializer_ReadUint64(ValueDeserializer* deserializer, uint64_t* value) {
    return deserializer->ReadUint64(value);
}

bool v8_ValueDeserializer_ReadDouble(ValueDeserializer* deserializer, double* value) {
    return deserializer->ReadDouble(value);
}

/// `length` raw bytes, BORROWED from the serialized data until the
/// deserialization ends.
bool v8_ValueDeserializer_ReadRawBytes(ValueDeserializer* deserializer, size_t length, const void** data) {
    if (length == 0) {
        *data = nullptr;
        return true;
    }
    return deserializer->ReadRawBytes(length, data);
}

/// HTML "sub-deserialization": the next value, made in the current context
/// with the same memory. OWNED; nullptr with the exception pending.
Global<Value>* v8_ValueDeserializer_ReadValue(ValueDeserializer* deserializer) {
    if (!deserializer) return nullptr;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> context = isolate->GetCurrentContext();
    if (context.IsEmpty()) return nullptr;
    Local<Value> value;
    if (!deserializer->ReadValue(context).ToLocal(&value)) return nullptr;
    return trackHandle(new Global<Value>(isolate, value));
}

/// Throw a "DataCloneError" DOMException with `message` in the current
/// context, as the serializer's delegate does. For a SERIALIZATION only: it
/// runs the DOMException constructor, which a deserialization forbids (use
/// v8_ThrowDeserializationError there).
void v8_ThrowDataCloneError(const char* message, size_t length) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<String> text;
    if (!String::NewFromUtf8(isolate, message, NewStringType::kNormal, static_cast<int>(length)).ToLocal(&text)) {
        text = String::NewFromUtf8Literal(isolate, "A value could not be cloned.");
    }
    throwDataCloneErrorIn(isolate, text);
}

/// Abort a DESERIALIZATION with `message`, running no script (see
/// throwDeserializationError): its caller reports the failure.
void v8_ThrowDeserializationError(const char* message, size_t length) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<String> text;
    if (!String::NewFromUtf8(isolate, message, NewStringType::kNormal, static_cast<int>(length)).ToLocal(&text)) {
        text = String::NewFromUtf8Literal(isolate, "A value could not be deserialized.");
    }
    throwDeserializationError(isolate, text);
}
// ---- end lane: serializable ----

/// Free serialized buffer from v8_Value_SerializeWithTransfer_CrossIsolate
void v8_Free_SerializedBuffer(uint8_t* buffer) {
    if (buffer) {
        free(buffer);
    }
}

/// Free ArrayBuffer transfer data (the copied data from source isolate)
void v8_Free_ArrayBufferTransferData(ArrayBufferTransferData* data, size_t count) {
    if (data) {
        for (size_t i = 0; i < count; i++) {
            if (data[i].data) {
                free(data[i].data);
            }
        }
    }
}

} // extern "C" - Cross-Isolate Structured Clone

extern "C" {

/// The process's ShadowRealm dispatcher: set once, while the process starts
/// (engine.initializeEngine), before any agent's thread runs - never per
/// agent, which with agents on their own threads would be concurrent writes
/// of one global.
void v8_SetShadowRealmContextDispatcher(ShadowRealmContextDispatch dispatch) {
    g_shadow_realm_dispatch.store(dispatch, std::memory_order_release);
}

/// Let `isolate` make ShadowRealms (HostCreateShadowRealmContextCallback,
/// through the process's dispatcher). With no dispatcher set - a host that
/// never called initializeEngine - `new ShadowRealm()` throws a TypeError.
void v8_Isolate_EnableShadowRealms(Isolate* isolate) {
    isolate->SetHostCreateShadowRealmContextCallback(V8HostCreateShadowRealmContextCallback);
}

} // extern "C"

// Lane regions for additive FFI (AGENTS.md "The engine boundary"): each lane adds
// its functions only inside its own region, so parallel lanes never edit the same lines.
// ---- lane: engine-boundary ----
extern "C" {

// The steps of WebIDL's record<K, V> conversion (3.2.23) that run script, each
// under a TryCatch so the caller converts between them exactly as the spec
// orders them. Each returns the completion the way v8_Function_CallCatching
// does: on a throw the thrown value (caught, not left pending) with `*threw`
// true - null only when there is nothing to report, a terminating isolate.
// Every non-null result is a new Global the caller owns.

/// O.[[OwnPropertyKeys]](): every own key - Symbols included, integer indices
/// as Strings - in the spec's order, as an Array. For a Proxy, its ownKeys
/// trap and nothing else (no filter, so no getOwnPropertyDescriptor calls).
Global<Value>* v8_Object_OwnPropertyKeysCatching(Global<Context>* context, Global<Value>* object, bool* threw) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    *threw = true;
    if (!context || !object || object->IsEmpty()) return nullptr;
    Local<Value> value = object->Get(isolate);
    if (!value->IsObject()) return nullptr;
    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);

    TryCatch try_catch(isolate);
    MaybeLocal<Array> keys = value.As<Object>()->GetOwnPropertyNames(
        ctx, PropertyFilter::ALL_PROPERTIES, KeyConversionMode::kConvertToString);
    if (try_catch.HasCaught()) {
        if (!try_catch.CanContinue()) return nullptr;
        return trackHandle(new Global<Value>(isolate, try_catch.Exception()));
    }
    if (keys.IsEmpty()) return nullptr;
    *threw = false;
    return trackHandle(new Global<Value>(isolate, keys.ToLocalChecked().As<Value>()));
}

/// O.[[GetOwnProperty]](key), answering what the record conversion asks of
/// it: whether the property exists AND is enumerable (`*enumerable`). `key` is
/// a String or Symbol from v8_Object_OwnPropertyKeysCatching. Returns the
/// thrown value (owned) when script threw, else null; `*threw` says which.
Global<Value>* v8_Object_IsOwnEnumerableCatching(
    Global<Context>* context,
    Global<Value>* object,
    Global<Value>* key,
    bool* enumerable,
    bool* threw
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    *enumerable = false;
    *threw = true;
    if (!context || !object || object->IsEmpty() || !key || key->IsEmpty()) return nullptr;
    Local<Value> value = object->Get(isolate);
    Local<Value> name = key->Get(isolate);
    if (!value->IsObject() || !name->IsName()) return nullptr;
    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);

    TryCatch try_catch(isolate);
    MaybeLocal<Value> maybe_desc = value.As<Object>()->GetOwnPropertyDescriptor(ctx, name.As<Name>());
    if (try_catch.HasCaught()) {
        if (!try_catch.CanContinue()) return nullptr;
        return trackHandle(new Global<Value>(isolate, try_catch.Exception()));
    }
    Local<Value> desc;
    if (!maybe_desc.ToLocal(&desc)) return nullptr;
    *threw = false;
    // Undefined: no such own property.
    if (!desc->IsObject()) return nullptr;
    // FromPropertyDescriptor's new ordinary object: its own `enumerable` data
    // property, so reading it runs no script.
    Local<Value> flag;
    if (desc.As<Object>()->Get(ctx, String::NewFromUtf8Literal(isolate, "enumerable")).ToLocal(&flag)) {
        *enumerable = flag->BooleanValue(isolate);
    }
    return nullptr;
}

/// Get(O, key) for a String or Symbol `key` - the property key itself, never
/// its UTF-8 rendering, which would lose a lone surrogate.
Global<Value>* v8_Object_GetByKeyCatching(Global<Context>* context, Global<Value>* object, Global<Value>* key, bool* threw) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    *threw = true;
    if (!context || !object || object->IsEmpty() || !key || key->IsEmpty()) return nullptr;
    Local<Value> value = object->Get(isolate);
    if (!value->IsObject()) return nullptr;
    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);

    TryCatch try_catch(isolate);
    MaybeLocal<Value> maybe_value = value.As<Object>()->Get(ctx, key->Get(isolate));
    if (try_catch.HasCaught()) {
        if (!try_catch.CanContinue()) return nullptr;
        return trackHandle(new Global<Value>(isolate, try_catch.Exception()));
    }
    if (maybe_value.IsEmpty()) return nullptr;
    *threw = false;
    return trackHandle(new Global<Value>(isolate, maybe_value.ToLocalChecked()));
}

/// A String of `length` UTF-16 code units, lone surrogates kept - what a
/// JavaScript string may hold and UTF-8 cannot carry
/// (String::NewFromTwoByte). A new Global the caller owns, as a Value:
/// released with v8_Global_Dispose / v8_Value_Dispose, so it is not counted
/// among the live String Globals. Null when V8 refuses it (longer than
/// String::kMaxLength).
Global<Value>* v8_Value_StringFromTwoByte(Isolate* isolate, const uint16_t* data, int length) {
    if (!isolate || length < 0 || (length > 0 && !data)) return nullptr;
    HandleScope handle_scope(isolate);
    Local<String> str;
    if (length == 0) {
        str = String::Empty(isolate);
    } else if (!String::NewFromTwoByte(isolate, data, NewStringType::kNormal, length).ToLocal(&str)) {
        return nullptr;
    }
    return trackHandle(new Global<Value>(isolate, str));
}

} // extern "C"
// ---- end lane: engine-boundary ----
// ---- lane: page-realm ----
// ============================================================================
// The engine protocol's realms and scripts (design 4.2-4.3): what the
// page-realm lane's adapter files (protocol_realms.zig, protocol_scripts.zig)
// need beyond the FFI above.
// ============================================================================
extern "C" {

/// ECMAScript GetFunctionRealm(obj): follows proxies and bound functions to
/// their targets and answers the realm of the function (or object) at the end
/// - V8's own JSReceiver::GetFunctionRealm walk, over the public API, which
/// has no call for it. A Global the caller owns; null for a value that is not
/// an object, and with `*revoked_proxy` set when the walk reaches a revoked
/// proxy (where the spec throws a TypeError).
Global<Context>* v8_Value_GetFunctionRealm(Global<Value>* value, bool* revoked_proxy) {
    *revoked_proxy = false;
    if (!value || value->IsEmpty()) return nullptr;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> current = value->Get(isolate);
    for (;;) {
        if (!current->IsObject()) return nullptr;
        if (current->IsProxy()) {
            Local<Proxy> proxy = current.As<Proxy>();
            // Step 4.a: a revoked proxy throws.
            if (proxy->IsRevoked()) {
                *revoked_proxy = true;
                return nullptr;
            }
            // Step 4.b-c: the proxy's target.
            current = proxy->GetTarget();
            continue;
        }
        if (current->IsFunction()) {
            // Step 3: a bound function's target function.
            Local<Value> target = current.As<Function>()->GetBoundFunction();
            if (!target->IsUndefined()) {
                current = target;
                continue;
            }
        }
        // Step 1-2 (a function's [[Realm]]), and step 5 (the current realm) -
        // which, for an object that is no function, V8 answers with the
        // object's creation context, as its own walk does.
        Local<Context> ctx;
        if (!current.As<Object>()->GetCreationContext(isolate).ToLocal(&ctx)) return nullptr;
        g_live_context_globals.fetch_add(1, std::memory_order_relaxed);
        return trackHandle(new Global<Context>(isolate, ctx));
    }
}

/// A context from `global_template`, around the detached global proxy
/// `global_proxy` (a WindowProxy kept across a navigation), for a realm made
/// afresh rather than from the snapshot. A Global the caller owns.
Global<Context>* v8_Context_NewWithGlobalTemplateAndProxy(Isolate* isolate, Global<ObjectTemplate>* global_template, Global<Object>* global_proxy) {
    if (!isolate || !global_template || !global_proxy) return nullptr;
    HandleScope handle_scope(isolate);
    Local<Context> context = Context::New(isolate, nullptr, global_template->Get(isolate), global_proxy->Get(isolate));
    if (context.IsEmpty()) return nullptr;
    g_live_context_globals.fetch_add(1, std::memory_order_relaxed);
    return trackHandle(new Global<Context>(isolate, context));
}

/// Whether JavaScript frames are on `isolate`'s stack: whether HTML's
/// JavaScript execution context stack still holds more than the realm
/// execution contexts the host pushed itself. Every realm's frames count:
/// without kExposeFramesAcrossSecurityOrigins V8 leaves out the frames whose
/// realm has another security token than the current one (isolate.cc,
/// VisitStack), and every Window realm has its own token
/// [cross_origin_objects] - a page's script calling into its frame's realm
/// read as an empty stack, and "clean up after running script" there ran a
/// microtask checkpoint in the middle of it.
bool v8_Isolate_HasJavaScriptOnStack(Isolate* isolate) {
    if (!isolate) return false;
    HandleScope handle_scope(isolate);
    return StackTrace::CurrentStackTrace(isolate, 1, StackTrace::kExposeFramesAcrossSecurityOrigins)->GetFrameCount() > 0;
}

/// An event handler content attribute's function (HTML "getting the current
/// value of the event handler" step 3.9): named `name`, with the parameters
/// `parameter_names` (event; evt for SVG; the five of a Window's onerror), its
/// body `body`, and its scope the global environment wrapped by the object
/// environments of `scopes`, OUTERMOST FIRST (document, form owner, element).
/// v8::ScriptCompiler::CompileFunction pushes context extensions in order, so
/// the last one is innermost - the order Blink's
/// JSEventHandlerForContentAttribute passes them in.
///
/// `scopes` may be the wrapper cache's own handles, held WEAKLY: each is read
/// into a Local before anything here allocates, and an empty one fails the
/// compile (as a body that does not compile does, with no error to report).
/// The body is compiled at `line_offset` / `column_offset` (0-based: the
/// engine protocol's SourcePosition less one) in a resource named
/// `resource_name` (null: none) - the document's URL - so what it throws and
/// a violation inside it report the document's URL and line, as Blink's
/// JSEventHandlerForContentAttribute compiles with the handler's
/// TextPosition. No host-defined options: the function has no
/// [[ScriptOrModule]], and an import() in it names no referrer
/// (ProtocolHostImportModuleDynamically reads only those).
///
/// Returns the function (Global<Value>*, caller owns), or nullptr with
/// `*out_error` set (v8_FreeErrorInfo; its `exception` is the SyntaxError)
/// when the body does not parse.
Global<Value>* v8_CompileEventHandlerWithParameters(
    Global<Context>* context,
    const char* name,
    int name_len,
    const char* body,
    int body_len,
    const char* const* parameter_names,
    int parameter_count,
    Global<Object>** scopes,
    int scope_count,
    const char* resource_name,
    int resource_name_len,
    int line_offset,
    int column_offset,
    V8ErrorInfo** out_error
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    *out_error = nullptr;

    // The scopes first, before anything allocates (see above).
    Local<Object> extensions_storage[8];
    if (scope_count < 0 || scope_count > 8) return nullptr;
    size_t extension_count = 0;
    for (int i = 0; i < scope_count; i++) {
        if (!scopes[i]) continue;
        if (scopes[i]->IsEmpty()) return nullptr;
        extensions_storage[extension_count++] = scopes[i]->Get(isolate);
    }

    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);
    TryCatch try_catch(isolate);

    Local<String> source_text;
    Local<String> function_name;
    if (!String::NewFromUtf8(isolate, body, NewStringType::kNormal, body_len).ToLocal(&source_text) ||
        !String::NewFromUtf8(isolate, name, NewStringType::kNormal, name_len).ToLocal(&function_name)) {
        return nullptr;
    }

    std::vector<Local<String>> params;
    for (int i = 0; i < parameter_count; i++) {
        Local<String> param;
        if (!String::NewFromUtf8(isolate, parameter_names[i]).ToLocal(&param)) return nullptr;
        params.push_back(param);
    }

    std::vector<Local<Object>> extensions(extensions_storage, extensions_storage + extension_count);

    Local<Value> origin_name = String::Empty(isolate);
    if (resource_name && resource_name_len > 0) {
        Local<String> named;
        if (!String::NewFromUtf8(isolate, resource_name, NewStringType::kNormal, resource_name_len).ToLocal(&named)) return nullptr;
        origin_name = named;
    }
    ScriptOrigin origin(origin_name, line_offset, column_offset);
    ScriptCompiler::Source source(source_text, origin);
    Local<Function> function;
    if (!ScriptCompiler::CompileFunction(
            ctx, &source, params.size(), params.empty() ? nullptr : params.data(),
            extensions.size(), extensions.empty() ? nullptr : extensions.data())
             .ToLocal(&function)) {
        if (try_catch.HasCaught()) {
            *out_error = extractException(isolate, &try_catch);
        } else {
            *out_error = new V8ErrorInfo();
            (*out_error)->has_error = true;
            (*out_error)->message = strdup("Event handler could not be compiled");
            (*out_error)->line_number = -1;
            (*out_error)->column_number = -1;
        }
        return nullptr;
    }

    function->SetName(function_name);
    return trackHandle(new Global<Value>(isolate, function.As<Value>()));
}

/// A script or module's ScriptOrigin host-defined options for the engine
/// protocol: [kind, host_defined, muted_errors], the host's pointer as a Number (exact: a
/// user-space address is below 2^53). `kind` is 0 for a classic script, 1
/// for a module - what HostLoadImportedModule's referrer is.
static Local<PrimitiveArray> protocolHostDefinedOptions(Isolate* isolate, int kind, void* host_defined, bool muted_errors = false) {
    Local<PrimitiveArray> options = PrimitiveArray::New(isolate, 3);
    options->Set(isolate, 0, Integer::New(isolate, kind));
    options->Set(isolate, 1, Number::New(isolate, static_cast<double>(reinterpret_cast<uintptr_t>(host_defined))));
    options->Set(isolate, 2, Boolean::New(isolate, muted_errors));
    return options;
}

/// HTML HostPromiseRejectionTracker step 2. The flag belongs to the running
/// script, including a function invoked after its initial evaluation ended.
/// Local handles only; the script itself keeps its host-defined options.
bool v8_Isolate_CurrentScriptHasMutedErrors(Isolate* isolate) {
    HandleScope scope(isolate);
    Local<Data> options;
    if (!isolate->GetCurrentHostDefinedOptions().ToLocal(&options) || !options->IsFixedArray()) return false;
    Local<PrimitiveArray> array = Local<PrimitiveArray>::Cast(options);
    if (array->Length() < 3) return false;
    Local<Primitive> kind = array->Get(isolate, 0);
    return kind->IsInt32() && kind.As<Int32>()->Value() == 0 &&
           array->Get(isolate, 2)->IsTrue();
}

/// Compile a classic script with a ScriptOrigin naming `resource_name` (null:
/// the empty string), at `line_offset` / `column_offset` in it (0-based: an
/// inline script's start in its document, the engine protocol's
/// SourcePosition less one; the column offset applies to the first line
/// only), and carrying `host_defined` (null: none) - so that an import()
/// from it names its host script as the referrer. As
/// v8_Script_CompileWithOrigin_Safe otherwise.
V8ScriptCompileResult* v8_Script_CompileWithHostDefined_Safe(
    Global<Context>* context,
    Global<String>* source,
    Global<String>* resource_name,
    int line_offset,
    int column_offset,
    void* host_defined,
    bool muted_errors
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);

    Local<Context> local_context = context->Get(isolate);
    Context::Scope context_scope(local_context);
    Local<String> local_source = source->Get(isolate);
    Local<Value> local_resource_name = resource_name ? resource_name->Get(isolate).As<Value>() : String::Empty(isolate).As<Value>();

    V8ScriptCompileResult* result = new V8ScriptCompileResult();
    result->script = nullptr;
    result->error = nullptr;

    Local<Data> host_defined_options;
    if (host_defined || muted_errors) host_defined_options = protocolHostDefinedOptions(isolate, 0, host_defined, muted_errors);
    ScriptOrigin origin(local_resource_name, line_offset, column_offset, false, -1, Local<Value>(), false, false, false, host_defined_options);

    TryCatch try_catch(isolate);
    MaybeLocal<Script> maybe_script = Script::Compile(local_context, local_source, &origin);
    if (try_catch.HasCaught()) {
        result->error = extractException(isolate, &try_catch);
        return result;
    }
    if (maybe_script.IsEmpty()) {
        result->error = new V8ErrorInfo();
        result->error->has_error = true;
        result->error->message = strdup("Script compilation failed");
        result->error->stack_trace = nullptr;
        result->error->line_number = -1;
        result->error->column_number = -1;
        result->error->source_line = nullptr;
        result->error->resource_name = nullptr;
        return result;
    }
    result->script = trackHandle(new Global<Script>(isolate, maybe_script.ToLocalChecked()));
    return result;
}

/// HTML "run a classic script" with rethrow errors true (steps 5-8), for the
/// engine protocol's runClassicScriptRethrowingErrors: compile `source` as a
/// classic script named `resource_name` and run it, under a TryCatch that
/// does not keep what it catches. Blink's V8ScriptRunner does the same for
/// importScripts() (RethrowErrorsOption): TryCatch::ReThrow puts the
/// exception back with the message of its ORIGINAL throw, where
/// Isolate::ThrowException would compute a new one at the calling frame.
/// Returns 0: a normal completion. 1: the script did not parse or threw, and
/// the exception is pending again, as thrown (8.1, muted errors false). 2: it
/// did, with `muted_errors`: nothing is pending (8.2: the host throws a
/// NetworkError). -1: the isolate is terminating; the termination goes on.
int v8_Script_RunRethrowingErrors(
    Global<Context>* context,
    Global<String>* source,
    Global<String>* resource_name,
    int line_offset,
    int column_offset,
    void* host_defined,
    bool muted_errors
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);

    Local<Context> local_context = context->Get(isolate);
    Context::Scope context_scope(local_context);
    Local<String> local_source = source->Get(isolate);
    Local<Value> local_resource_name = resource_name ? resource_name->Get(isolate).As<Value>() : String::Empty(isolate).As<Value>();

    Local<Data> host_defined_options;
    if (host_defined || muted_errors) host_defined_options = protocolHostDefinedOptions(isolate, 0, host_defined, muted_errors);
    ScriptOrigin origin(local_resource_name, line_offset, column_offset, false, -1, Local<Value>(), false, false, false, host_defined_options);

    TryCatch try_catch(isolate);
    Local<Script> script;
    if (Script::Compile(local_context, local_source, &origin).ToLocal(&script)) {
        (void)script->Run(local_context);
    }
    if (!try_catch.HasCaught()) return 0;
    if (try_catch.HasTerminated() || !try_catch.CanContinue()) {
        try_catch.ReThrow();
        return -1;
    }
    if (muted_errors) return 2;
    try_catch.ReThrow();
    return 1;
}

/// Whether V8's platform is initialized in this process. V8's flags must be
/// set before it is (they are frozen after), and it cannot be initialized
/// again once disposed.
bool v8_Platform_IsInitialized() {
    return g_platform.started.load(std::memory_order_acquire);
}

/// The engine protocol's HostPromiseRejectionTracker dispatcher: one Zig
/// function for every agent (protocol_agents.onPromiseReject), which finds the
/// agent's hooks by its isolate.
typedef void (*ProtocolPromiseRejectDispatch)(Isolate*, int, Global<Value>*, Global<Value>*);

// process-wide: the one Zig dispatcher every agent's isolate calls, finding its agent by isolate; set at process start (protocol_agents.initializeEngine), never per agent - every createAgent used to write it on its own thread, a data race between Browsers (ThreadSanitizer, docs/testing/test-variant-findings-2026-11-02.tsv F1). Atomic: a test may start the engine again on another thread, storing the same function.
static std::atomic<ProtocolPromiseRejectDispatch> g_protocol_promise_reject{nullptr};

static void ProtocolPromiseRejectCallback(PromiseRejectMessage message) {
    auto dispatch = g_protocol_promise_reject.load(std::memory_order_acquire);
    if (!dispatch) return;
    // The callback runs on the isolate's own thread, synchronously.
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Promise> promise = message.GetPromise();
    // The rejection's value, for a reject; empty for a handler added later.
    Local<Value> reason = message.GetValue();
    dispatch(
        isolate,
        static_cast<int>(message.GetEvent()),
        trackHandle(new Global<Value>(isolate, promise)),
        reason.IsEmpty() ? nullptr : trackHandle(new Global<Value>(isolate, reason))
    );
}

/// The process's HostPromiseRejectionTracker dispatcher: once, while the
/// process starts (engine.initializeEngine), before any agent's thread runs.
/// `dispatch(isolate, event, promise, reason)` - `event` a
/// v8::PromiseRejectEvent, `promise` and `reason` (null when V8 gives none)
/// Globals the dispatcher owns.
void v8_SetProtocolPromiseRejectDispatcher(ProtocolPromiseRejectDispatch dispatch) {
    g_protocol_promise_reject.store(dispatch, std::memory_order_release);
}

/// Install HostPromiseRejectionTracker on `isolate` alone, dispatched to the
/// process's dispatcher.
void v8_Isolate_SetProtocolPromiseRejectCallback(Isolate* isolate) {
    isolate->SetPromiseRejectCallback(ProtocolPromiseRejectCallback);
}

/// Remove HostPromiseRejectionTracker from `isolate` alone (the dispatcher,
/// and every other isolate's callback, stay).
void v8_Isolate_ClearProtocolPromiseRejectCallback(Isolate* isolate) {
    isolate->SetPromiseRejectCallback(nullptr);
}

// ---- modules through the engine protocol ----

/// The host's pointer in host-defined options protocolHostDefinedOptions
/// made: `*kind` 0 for a classic script, 1 for a module; -1 (and null) for
/// options it did not make - an event handler's, eval's, another path's.
static void protocolReadHostDefined(Isolate* isolate, Local<Data> options, int* kind, void** host_defined) {
    *kind = -1;
    *host_defined = nullptr;
    if (options.IsEmpty() || !options->IsFixedArray()) return;
    Local<PrimitiveArray> array = Local<PrimitiveArray>::Cast(options);
    if (array->Length() < 2) return;
    Local<Primitive> k = array->Get(isolate, 0);
    Local<Primitive> p = array->Get(isolate, 1);
    if (!k->IsInt32() || !p->IsNumber()) return;
    *kind = k.As<Int32>()->Value();
    *host_defined = reinterpret_cast<void*>(static_cast<uintptr_t>(p.As<Number>()->Value()));
}

/// ECMAScript ParseModule: compile `source` as a module whose ScriptOrigin
/// names `resource_name`, puts it at `line_offset` / `column_offset` (0-based,
/// as v8_Script_CompileWithHostDefined_Safe's: an inline module script's
/// start in its document) and carries `host_defined` as a module's (kind 1),
/// in `context`. Free with v8_FreeModuleCompileResult; its module is OWNED.
V8ModuleCompileResult* v8_Module_CompileWithHostDefined_Safe(
    Global<Context>* context,
    Global<String>* source,
    Global<String>* resource_name,
    int line_offset,
    int column_offset,
    void* host_defined
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> local_context = context->Get(isolate);
    Context::Scope context_scope(local_context);
    Local<String> local_source = source->Get(isolate);
    Local<String> local_name = resource_name ? resource_name->Get(isolate) : String::Empty(isolate);

    V8ModuleCompileResult* result = new V8ModuleCompileResult();
    result->module = nullptr;
    result->error = nullptr;

    Local<Data> host_defined_options;
    if (host_defined) host_defined_options = protocolHostDefinedOptions(isolate, 1, host_defined);
    ScriptOrigin origin(local_name, line_offset, column_offset, false, -1, Local<Value>(), false, false, true, host_defined_options);
    ScriptCompiler::Source script_source(local_source, origin);

    TryCatch try_catch(isolate);
    MaybeLocal<Module> maybe_module = ScriptCompiler::CompileModule(isolate, &script_source);
    if (try_catch.HasCaught()) {
        result->error = extractException(isolate, &try_catch);
        return result;
    }
    if (maybe_module.IsEmpty()) {
        result->error = new V8ErrorInfo();
        result->error->has_error = true;
        result->error->message = strdup("Module compilation failed");
        result->error->stack_trace = nullptr;
        result->error->line_number = -1;
        result->error->column_number = -1;
        result->error->source_line = nullptr;
        result->error->resource_name = nullptr;
        return result;
    }
    result->module = trackHandle(new Global<Module>(isolate, maybe_module.ToLocalChecked()));
    return result;
}

/// The host's answer for one module request during a Link: the resolved
/// module (a Global the host keeps), or null.
typedef Global<Module>* (*ProtocolResolveModule)(void* data, Global<Module>* referrer, const char* specifier, int specifier_len, const char* type_attribute);

struct ProtocolResolver {
    ProtocolResolveModule resolve;
    void* data;
};

/// The resolver of the Link in progress on this thread. V8 13.1 resolves a
/// graph's static imports synchronously inside InstantiateModule, with a
/// callback that carries no data, so the Link passes its resolver here; a
/// nested Link (from inside a resolve) saves and restores it.
// per-thread: a call-stack extent - the resolver of the Link running on this thread's stack (V8's ResolveModuleCallback carries no data), saved and restored around each Link, nested ones included.
static thread_local ProtocolResolver* t_protocol_resolver = nullptr;

static MaybeLocal<Module> ProtocolResolveModuleCallback(
    Local<Context> context,
    Local<String> specifier,
    Local<FixedArray> import_attributes,
    Local<Module> referrer
) {
    Isolate* isolate = Isolate::GetCurrent();  // V8 >= 14: no Context::GetIsolate (98282b9b8fa); a callback runs on its isolate
    ProtocolResolver* resolver = t_protocol_resolver;
    if (!resolver || !resolver->resolve) {
        throwUnresolvedModuleSpecifier(isolate, specifier);
        return MaybeLocal<Module>();
    }
    String::Utf8Value specifier_utf8(isolate, specifier);
    // A static import's attributes carry source positions: (key, value,
    // position) triples.
    char* type_attribute = importTypeAttribute(isolate, context, import_attributes, 3, nullptr);
    // The referrer, BORROWED for the call: the host names it by its record.
    Global<Module> referrer_handle(isolate, referrer);
    Global<Module>* resolved = resolver->resolve(
        resolver->data,
        &referrer_handle,
        *specifier_utf8 ? *specifier_utf8 : "",
        specifier_utf8.length(),
        type_attribute
    );
    delete[] type_attribute;
    if (!resolved) {
        throwUnresolvedModuleSpecifier(isolate, specifier);
        return MaybeLocal<Module>();
    }
    return resolved->Get(isolate);
}

/// ECMAScript Link() on `module`, each request resolved by `resolve(data,
/// ...)`. True on success; false with `*exception` the error (a Global the
/// caller owns; null when V8 threw nothing, as when terminating).
bool v8_Module_LinkWithResolver(
    Global<Context>* context,
    Global<Module>* module,
    ProtocolResolveModule resolve,
    void* data,
    Global<Value>** exception
) {
    *exception = nullptr;
    Isolate* isolate = Isolate::GetCurrent();
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);
    Local<Context> local_context = context->Get(isolate);
    Context::Scope context_scope(local_context);

    ProtocolResolver resolver{resolve, data};
    ProtocolResolver* previous = t_protocol_resolver;
    t_protocol_resolver = &resolver;
    TryCatch try_catch(isolate);
    bool linked = module->Get(isolate)->InstantiateModule(local_context, ProtocolResolveModuleCallback).FromMaybe(false);
    t_protocol_resolver = previous;
    if (linked) return true;
    if (try_catch.HasCaught() && !try_catch.HasTerminated()) {
        *exception = trackHandle(new Global<Value>(isolate, try_catch.Exception()));
    } else if (try_catch.HasTerminated()) {
        try_catch.ReThrow();
    }
    return false;
}

/// ECMAScript Evaluate() on a linked `module`, in `context`: 0 when its
/// promise is fulfilled; 1 when rejected (or it threw), with `*value` the
/// reason; 2 when pending on top-level await, with `*value` the promise;
/// -1 when V8 returned nothing (terminating). `*value` is a Global the caller
/// owns. A rejected promise is marked as handled: the reason is the host's
/// to report, and the promise is not script's to observe.
int v8_Module_EvaluateForProtocol(Global<Context>* context, Global<Module>* module, Global<Value>** value) {
    *value = nullptr;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> local_context = context->Get(isolate);
    Context::Scope context_scope(local_context);

    TryCatch try_catch(isolate);
    Local<Value> result;
    if (!module->Get(isolate)->Evaluate(local_context).ToLocal(&result)) {
        if (try_catch.HasCaught() && !try_catch.HasTerminated()) {
            *value = trackHandle(new Global<Value>(isolate, try_catch.Exception()));
            return 1;
        }
        if (try_catch.HasTerminated()) try_catch.ReThrow();
        return -1;
    }
    if (!result->IsPromise()) return 0;
    Local<Promise> promise = result.As<Promise>();
    switch (promise->State()) {
        case Promise::kFulfilled:
            return 0;
        case Promise::kRejected:
            promise->MarkAsHandled();
            *value = trackHandle(new Global<Value>(isolate, promise->Result()));
            return 1;
        default:
            *value = trackHandle(new Global<Value>(isolate, promise));
            return 2;
    }
}

/// ContinueDynamicImport's settle steps: data is [resolver, namespace].
static void ProtocolDynamicImportFulfilled(const FunctionCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    Local<Context> context = isolate->GetCurrentContext();
    Local<Array> data = info.DataV2().As<Value>().As<Array>();
    Local<Value> resolver, ns;
    if (!data->Get(context, 0).ToLocal(&resolver) || !data->Get(context, 1).ToLocal(&ns)) return;
    (void)resolver.As<Promise::Resolver>()->Resolve(context, ns);
}

static void ProtocolDynamicImportRejected(const FunctionCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    Local<Context> context = isolate->GetCurrentContext();
    Local<Array> data = info.DataV2().As<Value>().As<Array>();
    Local<Value> resolver;
    if (!data->Get(context, 0).ToLocal(&resolver)) return;
    (void)resolver.As<Promise::Resolver>()->Reject(context, info[0]);
}

/// ECMAScript ContinueDynamicImport(promiseCapability, module) for an
/// import() whose module the host loaded: Link (a graph the host linked
/// links again at no cost; one it did not fails here, having no resolver),
/// Evaluate, then settle the import() promise with the module namespace or
/// the evaluation's reason. Consumes `context_ptr` and `resolver_ptr`, as
/// v8_DynamicImport_Resolve does; `module` stays the caller's.
void v8_DynamicImport_ContinueWithModule(void* context_ptr, void* resolver_ptr, Global<Module>* module_global) {
    Isolate* isolate = Isolate::GetCurrent();
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);
    Global<Context>* context_global = static_cast<Global<Context>*>(context_ptr);
    Global<Promise::Resolver>* resolver_global = static_cast<Global<Promise::Resolver>*>(resolver_ptr);
    Local<Context> context = context_global->Get(isolate);
    Context::Scope context_scope(context);
    Local<Promise::Resolver> resolver = resolver_global->Get(isolate);
    Local<Module> module = module_global->Get(isolate);

    auto reject_with_caught = [&](TryCatch& try_catch, const char* fallback) {
        Local<Value> reason;
        if (try_catch.HasCaught() && !try_catch.HasTerminated()) {
            reason = try_catch.Exception();
            try_catch.Reset();
        } else {
            reason = Exception::TypeError(String::NewFromUtf8(isolate, fallback).ToLocalChecked());
        }
        (void)resolver->Reject(context, reason);
    };

    {
        TryCatch try_catch(isolate);
        // 1-2. Link().
        if (module->GetStatus() == Module::kUninstantiated) {
            ProtocolResolver* previous = t_protocol_resolver;
            t_protocol_resolver = nullptr;
            bool linked = module->InstantiateModule(context, ProtocolResolveModuleCallback).FromMaybe(false);
            t_protocol_resolver = previous;
            if (!linked) {
                reject_with_caught(try_catch, "The imported module could not be linked");
                goto done;
            }
        }
        // 3-4. Evaluate().
        Local<Value> evaluated;
        if (!module->Evaluate(context).ToLocal(&evaluated)) {
            reject_with_caught(try_catch, "The imported module could not be evaluated");
            goto done;
        }
        Local<Value> ns = module->GetModuleNamespace();
        if (!evaluated->IsPromise()) {
            (void)resolver->Resolve(context, ns);
            goto done;
        }
        // 5-8. Settle the import() promise when evaluation settles.
        Local<Array> data = Array::New(isolate, 2);
        (void)data->Set(context, 0, resolver);
        (void)data->Set(context, 1, ns);
        Local<Function> on_fulfilled, on_rejected;
        if (!Function::New(context, ProtocolDynamicImportFulfilled, data, 1).ToLocal(&on_fulfilled) ||
            !Function::New(context, ProtocolDynamicImportRejected, data, 1).ToLocal(&on_rejected)) {
            reject_with_caught(try_catch, "The imported module could not be awaited");
            goto done;
        }
        (void)evaluated.As<Promise>()->Then(context, on_fulfilled, on_rejected);
    }
done:
    delete context_global;
    resolver_global->Reset();
    delete resolver_global;
}

/// The engine protocol's module hook dispatchers: one Zig function each for
/// every agent, which finds the agent's hooks by its isolate.
typedef void (*ProtocolDynamicImportDispatch)(
    Isolate* isolate,
    Global<Context>* context,
    int referrer_kind,
    void* referrer,
    const char* specifier,
    int specifier_len,
    const char* type_attribute,
    Global<Promise::Resolver>* resolver
);
typedef const char* (*ProtocolImportMetaUrlDispatch)(Isolate* isolate, Global<Module>* module, int identity_hash, size_t* len);
/// import.meta.resolve's steps after ToString: the serialized URL (malloc'd,
/// the caller frees it) or null for failure.
typedef char* (*ProtocolImportMetaResolveDispatch)(Isolate* isolate, Global<Context>* context, const char* base_url, size_t base_url_len, const char* specifier, size_t specifier_len, size_t* len);

// process-wide: the one Zig dispatcher (protocol_modules.onDynamicImport) every agent's isolate calls, finding its agent by isolate; set at process start (protocol_agents.initializeEngine), never per agent (createAgent wrote it on each agent's thread: tsanfix1, F1). Atomic, as g_protocol_promise_reject.
static std::atomic<ProtocolDynamicImportDispatch> g_protocol_dynamic_import{nullptr};
// process-wide: the one Zig dispatcher (protocol_modules.onImportMetaUrl) every agent's isolate calls; set at process start beside g_protocol_dynamic_import, for the same reasons.
static std::atomic<ProtocolImportMetaUrlDispatch> g_protocol_import_meta_url{nullptr};
// process-wide: the one Zig dispatcher (protocol_modules.onImportMetaResolve) every agent's isolate calls; set at process start beside g_protocol_dynamic_import. Whether an isolate's import.meta has resolve is the isolate's (IsolateData::import_meta_resolve).
static std::atomic<ProtocolImportMetaResolveDispatch> g_protocol_import_meta_resolve{nullptr};

/// HostLoadImportedModule for an import(): the referrer from the host-defined
/// options the protocol compiled the script or module with, the realm from
/// the context import() was called in (HTML's current settings object), and
/// the promise - whose resolver, with the context, the dispatcher OWNS until
/// the host finishes the import.
static MaybeLocal<Promise> ProtocolHostImportModuleDynamically(
    Local<Context> context,
    Local<Data> host_defined_options,
    Local<Value> resource_name,
    Local<String> specifier,
    Local<FixedArray> import_attributes
) {
    (void)resource_name;
    Isolate* isolate = Isolate::GetCurrent();  // V8 >= 14: no Context::GetIsolate (98282b9b8fa); a callback runs on its isolate
    EscapableHandleScope handle_scope(isolate);
    Local<Promise::Resolver> resolver;
    if (!Promise::Resolver::New(context).ToLocal(&resolver)) return MaybeLocal<Promise>();

    auto dispatch = g_protocol_dynamic_import.load(std::memory_order_acquire);
    if (!dispatch) {
        (void)resolver->Reject(context, Exception::TypeError(String::NewFromUtf8Literal(isolate, "import() is not supported here")));
        return handle_scope.Escape(resolver->GetPromise());
    }
    int kind = -1;
    void* referrer = nullptr;
    protocolReadHostDefined(isolate, host_defined_options, &kind, &referrer);
    String::Utf8Value specifier_utf8(isolate, specifier);
    // A dynamic import's attributes are (key, value) pairs.
    bool has_unsupported_key = false;
    char* type_attribute = importTypeAttribute(isolate, context, import_attributes, 2, &has_unsupported_key);
    // HTML HostGetSupportedImportAttributes is « "type" »: an import() whose
    // attributes name any other key rejects with a TypeError and loads
    // nothing - the check Blink's HostImportModuleDynamically makes before
    // its host steps (ModuleRequest::HasInvalidImportAttributeKey, "Invalid
    // attribute key"); a static import's is parseModule's SyntaxError.
    // html/semantics/scripting-1/the-script-element/import-attributes/
    // dynamic-import-with-attributes-argument.any.js: all three browsers
    // pass with a TypeError.
    if (has_unsupported_key) {
        delete[] type_attribute;
        (void)resolver->Reject(context, Exception::TypeError(String::NewFromUtf8Literal(isolate, "Invalid import attribute key: only \"type\" is supported")));
        return handle_scope.Escape(resolver->GetPromise());
    }
    dispatch(
        isolate,
        new Global<Context>(isolate, context),
        kind,
        referrer,
        *specifier_utf8 ? *specifier_utf8 : "",
        specifier_utf8.length(),
        type_attribute,
        new Global<Promise::Resolver>(isolate, resolver)
    );
    delete[] type_attribute;
    return handle_scope.Escape(resolver->GetPromise());
}

/// HostGetImportMetaProperties steps 4-6: the builtin import.meta.resolve.
/// Its data is import.meta.url - the module script's base URL, serialized -
/// and the realm it runs in is the one it was made in: the module script's
/// settings object's.
static void ProtocolImportMetaResolve(const FunctionCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    HandleScope handle_scope(isolate);
    Local<Context> context = isolate->GetCurrentContext();
    // Step 4.1: Set specifier to ? ToString(specifier) - undefined when no
    // argument is given; a Symbol throws.
    Local<Value> argument = info.Length() > 0 ? info[0] : Local<Value>(Undefined(isolate));
    Local<String> specifier;
    if (!argument->ToString(context).ToLocal(&specifier)) return;
    // Step 4.2: resolve a module specifier given moduleScript and specifier.
    auto dispatch = g_protocol_import_meta_resolve.load(std::memory_order_acquire);
    String::Utf8Value base_utf8(isolate, info.DataV2().As<Value>());
    String::Utf8Value specifier_utf8(isolate, specifier);
    Global<Context> realm(isolate, context);
    size_t len = 0;
    char* url = dispatch
        ? dispatch(isolate, &realm, *base_utf8 ? *base_utf8 : "", base_utf8.length(), *specifier_utf8 ? *specifier_utf8 : "", specifier_utf8.length(), &len)
        : nullptr;
    if (!url) {
        isolate->ThrowException(Exception::TypeError(String::NewFromUtf8Literal(isolate, "Failed to resolve module specifier")));
        return;
    }
    // Step 4.3: return the serialization of url.
    Local<String> result;
    bool made = String::NewFromUtf8(isolate, url, NewStringType::kNormal, static_cast<int>(len)).ToLocal(&result);
    free(url);
    if (made) info.GetReturnValue().Set(result);
}

/// HostGetImportMetaProperties: import.meta.url, from the host's module
/// script (found by its record on the Zig side), and - step 5 -
/// CreateBuiltinFunction(steps, 1, "resolve", « »), when the host resolves.
static void ProtocolInitializeImportMeta(Local<Context> context, Local<Module> module, Local<Object> meta) {
    auto dispatch = g_protocol_import_meta_url.load(std::memory_order_acquire);
    if (!dispatch) return;
    Isolate* isolate = Isolate::GetCurrent();  // V8 >= 14: no Context::GetIsolate (98282b9b8fa); a callback runs on its isolate
    Global<Module> handle(isolate, module);
    size_t len = 0;
    const char* url = dispatch(isolate, &handle, module->GetIdentityHash(), &len);
    if (!url) return;
    Local<String> value;
    if (!String::NewFromUtf8(isolate, url, NewStringType::kNormal, static_cast<int>(len)).ToLocal(&value)) return;
    (void)meta->CreateDataProperty(context, String::NewFromUtf8Literal(isolate, "url"), value).FromMaybe(false);
    // Only for an agent whose host resolves (the isolate's flag).
    const IsolateData* record = isolateData(isolate);
    if (!record || !record->import_meta_resolve || !g_protocol_import_meta_resolve.load(std::memory_order_acquire)) return;
    Local<Function> resolve;
    if (!Function::New(context, ProtocolImportMetaResolve, value, 1, ConstructorBehavior::kThrow).ToLocal(&resolve)) return;
    resolve->SetName(String::NewFromUtf8Literal(isolate, "resolve"));
    (void)meta->CreateDataProperty(context, String::NewFromUtf8Literal(isolate, "resolve"), resolve).FromMaybe(false);
}

/// The process's import() and import.meta dispatchers: once, while the
/// process starts (engine.initializeEngine), before any agent's thread runs.
void v8_SetProtocolModuleDispatchers(ProtocolDynamicImportDispatch dynamic_import, ProtocolImportMetaUrlDispatch import_meta_url, ProtocolImportMetaResolveDispatch import_meta_resolve) {
    g_protocol_dynamic_import.store(dynamic_import, std::memory_order_release);
    g_protocol_import_meta_url.store(import_meta_url, std::memory_order_release);
    g_protocol_import_meta_resolve.store(import_meta_resolve, std::memory_order_release);
}

/// Install the protocol's import() and import.meta hooks on `isolate` alone,
/// each only when asked; import.meta.resolve only beside import.meta.url. The
/// dispatchers they reach are the process's.
void v8_Isolate_SetProtocolModuleHooks(Isolate* isolate, bool dynamic_import, bool import_meta_url, bool import_meta_resolve) {
    if (dynamic_import) isolate->SetHostImportModuleDynamicallyCallback(ProtocolHostImportModuleDynamically);
    if (import_meta_url) {
        if (IsolateData* record = isolateData(isolate)) record->import_meta_resolve = import_meta_resolve;
        isolate->SetHostInitializeImportMetaObjectCallback(ProtocolInitializeImportMeta);
    }
}

} // extern "C"
// ---- end lane: page-realm ----
// ---- lane: runtime-impls ----
// ============================================================================
// WebIDL "create a simple exception" (the runtime-impls lane's Engine
// operation createSimpleException): the error constructors v8::Exception
// reaches beyond TypeError and RangeError, created in a given realm.
// ============================================================================

extern "C" {

/// Create ReferenceError in a specific context: Construct(%ReferenceError%,
/// « message ») with that realm's intrinsic, as the TypeError and RangeError
/// variants above do.
Global<Value>* v8_Exception_ReferenceErrorInContext(Global<Context>* context, Global<String>* message) {
    if (!context || !message) return nullptr;

    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<String> msg = message->Get(isolate);

    Context::Scope context_scope(ctx);

    Local<Value> exception = Exception::ReferenceError(msg);
    return trackHandle(new Global<Value>(isolate, exception));
}

} // extern "C"

extern "C" {

/// WebIDL "write" `length` bytes into an ArrayBufferView, `starting_offset`
/// bytes into the view (the runtime-impls lane's writeIntoArrayBufferView):
/// SetValueInBuffer over [[ViewedArrayBuffer]] from [[ByteOffset]] +
/// startingOffset, for an ArrayBuffer or a SharedArrayBuffer alike. False when
/// `view` is not an ArrayBufferView, its buffer is detached, or the bytes do
/// not fit in the view.
bool v8_ArrayBufferView_WriteBytes(Global<Value>* view, const uint8_t* bytes, size_t length, size_t starting_offset) {
    if (!view || view->IsEmpty()) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> v = view->Get(isolate);
    if (!v->IsArrayBufferView()) return false;
    Local<ArrayBufferView> abv = v.As<ArrayBufferView>();
    size_t view_length = abv->ByteLength();
    if (starting_offset > view_length || length > view_length - starting_offset) return false;
    Local<Object> buffer = abv->Buffer();
    void* data = nullptr;
    if (buffer->IsSharedArrayBuffer()) {
        data = buffer.As<SharedArrayBuffer>()->Data();
    } else if (buffer->IsArrayBuffer()) {
        Local<ArrayBuffer> ab = buffer.As<ArrayBuffer>();
        if (ab->WasDetached()) return false;
        data = ab->Data();
    }
    if (length == 0) return true;
    if (!data || !bytes) return false;
    memcpy(static_cast<uint8_t*>(data) + abv->ByteOffset() + starting_offset, bytes, length);
    return true;
}

} // extern "C"
// ---- end lane: runtime-impls ----
// ---- lane: protocol ----
// The engine protocol's additive FFI (engine-protocol-design.md, decision 11).
extern "C" {

/// HTML "prepare to run a callback" for V8: run `body(data)` with `incumbent`
/// pushed onto the backup incumbent settings object stack
/// (v8::Context::BackupIncumbentScope), so Isolate::GetIncumbentContext
/// answers it for everything the body runs until a script frame is newer.
/// The scope keys off its own stack address, so it has to live here, around
/// the body - Blink's CallbackInvokeHelper holds it the same way. A null
/// `incumbent` runs the body with nothing pushed.
void v8_RunWithBackupIncumbent(Isolate* isolate, Global<Context>* incumbent, void (*body)(void*), void* data) {
    HandleScope handle_scope(isolate);
    if (!incumbent || incumbent->IsEmpty()) {
        body(data);
        return;
    }
    Local<Context> context = incumbent->Get(isolate);
    Context::BackupIncumbentScope scope(context);
    body(data);
}

/// Test-only public lifecycle probe. Context::SetPromiseHooks is unavailable
/// in the linked build (V8_ENABLE_JAVASCRIPT_PROMISE_HOOKS is disabled).
static void testPromiseHook(PromiseHookType type, Local<Promise> promise, Local<Value>) {
    IsolateData* data = isolateData(Isolate::GetCurrent());
    if (data && data->test_promise_hook)
        data->test_promise_hook(static_cast<int>(type), data->test_promise_hook_data);
}

bool v8_test_Isolate_SetPromiseHook(Isolate* isolate, void (*hook)(int, void*), void* payload) {
    IsolateData* data = isolateData(isolate);
    if (!data) return false;
    isolate->SetPromiseHook(hook ? testPromiseHook : nullptr);
    data->test_promise_hook = hook;
    data->test_promise_hook_data = hook ? payload : nullptr;
    return true;
}

/// HTML's incumbent realm here: Isolate::GetIncumbentContext - the realm of
/// the most recent script frame, or of the innermost backup incumbent scope
/// newer than it, or the entered context. A new Global the caller owns
/// (counted as GetCurrentContext's are); null when no context is entered.
Global<Context>* v8_Isolate_GetIncumbentContext(Isolate* isolate) {
    if (!isolate || !isolate->InContext()) return nullptr;
    HandleScope handle_scope(isolate);
    Local<Context> context = isolate->GetIncumbentContext();
    if (context.IsEmpty()) return nullptr;
    g_live_context_globals.fetch_add(1, std::memory_order_relaxed);
    return trackHandle(new Global<Context>(isolate, context));
}

/// A function of `context` whose steps are `callback`, with `data` as its
/// [[data]] (FunctionCallbackInfo::Data) and `length` as its "length" - made
/// with Function::New, which unlike a FunctionTemplate is not cached per
/// context, so a closure made per object or per step is collected with what
/// references it. Not a constructor. A new Global the caller owns; null on
/// failure.
Global<Value>* v8_Function_NewWithData(Global<Context>* context, ZigCallback callback, Global<Value>* data, int length) {
    if (!context || context->IsEmpty() || !callback) return nullptr;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<Value> data_value = (data && !data->IsEmpty()) ? data->Get(isolate) : Local<Value>();
    Local<Function> function;
    if (!Function::New(ctx, reinterpret_cast<FunctionCallback>(callback), data_value, length, ConstructorBehavior::kThrow).ToLocal(&function)) {
        return nullptr;
    }
    return trackHandle(new Global<Value>(isolate, function));
}

/// PerformPromiseThen(promise, onFulfilled, onRejected, capability), a null
/// handler being the spec's undefined: V8's one-handler Then (or Catch) for
/// it. v8_Promise_Then hands V8's two-handler Then an empty Local for a null
/// handler, which V8 dereferences. The derived promise - the capability's -
/// as a new Global the caller owns; null on failure.
Global<Value>* v8_Promise_ThenWithOptionalHandlers(Global<Context>* context, Global<Value>* promise, Global<Value>* on_fulfilled, Global<Value>* on_rejected) {
    if (!context || !promise || promise->IsEmpty()) return nullptr;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<Value> value = promise->Get(isolate);
    if (!value->IsPromise()) return nullptr;
    Local<Promise> target = value.As<Promise>();
    bool has_fulfilled = on_fulfilled && !on_fulfilled->IsEmpty() && on_fulfilled->Get(isolate)->IsFunction();
    bool has_rejected = on_rejected && !on_rejected->IsEmpty() && on_rejected->Get(isolate)->IsFunction();
    MaybeLocal<Promise> derived;
    if (has_fulfilled && has_rejected) {
        derived = target->Then(ctx, on_fulfilled->Get(isolate).As<Function>(), on_rejected->Get(isolate).As<Function>());
    } else if (has_fulfilled) {
        derived = target->Then(ctx, on_fulfilled->Get(isolate).As<Function>());
    } else if (has_rejected) {
        derived = target->Catch(ctx, on_rejected->Get(isolate).As<Function>());
    } else {
        return nullptr;
    }
    Local<Promise> result;
    if (!derived.ToLocal(&result)) return nullptr;
    return trackHandle(new Global<Value>(isolate, result));
}

/// ECMAScript ToObject(value) in `context`: an object itself, a primitive's
/// wrapper object (a String, Number, Boolean, Symbol or BigInt object of the
/// context's realm). Null for undefined and null - ToObject's TypeError,
/// which the caller throws (nothing is thrown here) - or on failure. A new
/// Global the caller owns.
Global<Value>* v8_Value_ToObject(Global<Context>* context, Global<Value>* value) {
    if (!context || !value || value->IsEmpty()) return nullptr;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> v = value->Get(isolate);
    if (v->IsNullOrUndefined()) return nullptr;
    Local<Object> object;
    if (!v->ToObject(context->Get(isolate)).ToLocal(&object)) return nullptr;
    return trackHandle(new Global<Value>(isolate, object));
}

/// HTML "extract error information" at the throw site: what the TryCatch
/// that caught an exception knows of where it was thrown - its Message's
/// script, line and column - taken while the TryCatch still holds it.
/// v8::Exception::CreateMessage, asked after the call has returned, can only
/// read a stack an Error object captured when it was made: a thrown string or
/// number has none, and no frame is left to capture. The message is the
/// value's ToString, as v8_Exception_GetErrorInfo makes it, under a TryCatch
/// of its own so that a throwing toString neither replaces the exception nor
/// stays pending. `exception` is null. Null when the TryCatch has no message.
static V8ErrorInfo* errorInfoAtThrowSite(Isolate* isolate, Local<Context> ctx, TryCatch& try_catch) {
    Local<Message> message = try_catch.Message();
    if (message.IsEmpty()) return nullptr;
    Local<Value> exception = try_catch.Exception();

    V8ErrorInfo* info = new V8ErrorInfo();
    info->has_error = true;
    info->message = nullptr;
    info->stack_trace = nullptr;
    info->source_line = nullptr;
    info->resource_name = nullptr;
    info->exception = nullptr;
    info->line_number = message->GetLineNumber(ctx).FromMaybe(-1);
    info->column_number = message->GetStartColumn();
    String::Utf8Value resource(isolate, message->GetScriptResourceName());
    info->resource_name = strdup(*resource ? *resource : "");
    {
        TryCatch to_string(isolate);
        String::Utf8Value text(isolate, exception);
        info->message = strdup(*text ? *text : "Uncaught exception");
    }
    return info;
}

/// v8_Function_CallCatching, and on a throw `*site` is where it was thrown
/// (errorInfoAtThrowSite; the caller frees it with v8_FreeErrorInfo, and it
/// may be null). Every non-null result is a new Global the caller owns.
Global<Value>* v8_Function_CallCatchingWithSite(
    Global<Context>* context,
    Global<Value>* function,
    Global<Value>* recv,
    int argc,
    Global<Value>** argv,
    bool* threw,
    V8ErrorInfo** site
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    *threw = true;
    *site = nullptr;

    if (!context || !function || function->IsEmpty()) return nullptr;
    Local<Value> fn_value = function->Get(isolate);
    if (!fn_value->IsFunction()) return nullptr;

    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);
    Local<Value> this_val = recv ? recv->Get(isolate) : Undefined(isolate).As<Value>();

    std::vector<Local<Value>> local_argv;
    local_argv.reserve(argc > 0 ? argc : 0);
    for (int i = 0; i < argc; i++) {
        local_argv.push_back(argv[i] ? argv[i]->Get(isolate) : Undefined(isolate).As<Value>());
    }

    TryCatch try_catch(isolate);
    try_catch.SetCaptureMessage(true);
    MaybeLocal<Value> maybe_result = fn_value.As<Function>()->Call(
        ctx, this_val, argc, local_argv.empty() ? nullptr : local_argv.data());

    if (try_catch.HasCaught()) {
        if (!try_catch.CanContinue()) return nullptr;
        Global<Value>* thrown = trackHandle(new Global<Value>(isolate, try_catch.Exception()));
        *site = errorInfoAtThrowSite(isolate, ctx, try_catch);
        return thrown;
    }
    if (maybe_result.IsEmpty()) return nullptr;

    *threw = false;
    return trackHandle(new Global<Value>(isolate, maybe_result.ToLocalChecked()));
}

/// WebIDL DOMString conversion inside the callback's prepared scopes. The
/// returned Global (string or thrown value) and copied throw site are owned
/// by the caller, exactly as in v8_Function_CallCatchingWithSite.
Global<Value>* v8_Value_ToStringCatchingWithSite(
    Global<Context>* context, Global<Value>* value, bool* threw,
    V8ErrorInfo** site
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    *threw = true;
    *site = nullptr;
    if (!context || !value || value->IsEmpty()) return nullptr;
    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);
    TryCatch try_catch(isolate);
    try_catch.SetCaptureMessage(true);
    Local<String> result;
    const bool converted = value->Get(isolate)->ToString(ctx).ToLocal(&result);
    if (try_catch.HasCaught()) {
        if (!try_catch.CanContinue()) return nullptr;
        Global<Value>* thrown = trackHandle(new Global<Value>(isolate, try_catch.Exception()));
        *site = errorInfoAtThrowSite(isolate, ctx, try_catch);
        return thrown;
    }
    if (!converted) return nullptr;
    *threw = false;
    return trackHandle(new Global<Value>(isolate, result));
}

/// ECMAScript Construct(`function`, `argv`) in `context` - newTarget the
/// function itself (Function::NewInstance) - under a TryCatch, as
/// v8_Function_CallCatchingWithSite calls: the result with `*threw` false, or
/// the thrown value with `*threw` true and `*site` where it was thrown. Null
/// (with `*threw` true) only when `function` is not a constructor or the
/// isolate is terminating. Every non-null result is a new Global the caller
/// owns. WebIDL "construct a callback function" steps 10-11.
Global<Value>* v8_Function_ConstructCatchingWithSite(
    Global<Context>* context,
    Global<Value>* function,
    int argc,
    Global<Value>** argv,
    bool* threw,
    V8ErrorInfo** site
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    *threw = true;
    *site = nullptr;

    if (!context || !function || function->IsEmpty()) return nullptr;
    Local<Value> fn_value = function->Get(isolate);
    if (!fn_value->IsObject() || !fn_value.As<Object>()->IsConstructor()) return nullptr;

    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);

    std::vector<Local<Value>> local_argv;
    local_argv.reserve(argc > 0 ? argc : 0);
    for (int i = 0; i < argc; i++) {
        local_argv.push_back(argv[i] ? argv[i]->Get(isolate) : Undefined(isolate).As<Value>());
    }

    TryCatch try_catch(isolate);
    try_catch.SetCaptureMessage(true);
    // A constructor is callable (IsConstructor implies IsCallable), so it is
    // a Function to V8 - a callable Proxy included.
    MaybeLocal<Object> maybe_result = fn_value.As<Function>()->NewInstance(
        ctx, argc, local_argv.empty() ? nullptr : local_argv.data());

    if (try_catch.HasCaught()) {
        if (!try_catch.CanContinue()) return nullptr;
        Global<Value>* thrown = trackHandle(new Global<Value>(isolate, try_catch.Exception()));
        *site = errorInfoAtThrowSite(isolate, ctx, try_catch);
        return thrown;
    }
    if (maybe_result.IsEmpty()) return nullptr;

    *threw = false;
    return trackHandle(new Global<Value>(isolate, maybe_result.ToLocalChecked().As<Value>()));
}

/// v8_Object_GetCatching, and on a throw `*site` is where it was thrown, as
/// v8_Function_CallCatchingWithSite has it.
Global<Value>* v8_Object_GetCatchingWithSite(
    Global<Context>* context,
    Global<Value>* object,
    const char* key,
    int key_len,
    bool* threw,
    V8ErrorInfo** site
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    *threw = true;
    *site = nullptr;

    if (!context || !object || object->IsEmpty() || !key) return nullptr;
    Local<Value> obj_value = object->Get(isolate);
    if (!obj_value->IsObject()) return nullptr;

    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);
    Local<String> name;
    if (!String::NewFromUtf8(isolate, key, NewStringType::kInternalized, key_len).ToLocal(&name)) return nullptr;

    TryCatch try_catch(isolate);
    try_catch.SetCaptureMessage(true);
    MaybeLocal<Value> maybe_value = obj_value.As<Object>()->Get(ctx, name);
    if (try_catch.HasCaught()) {
        if (!try_catch.CanContinue()) return nullptr;
        Global<Value>* thrown = trackHandle(new Global<Value>(isolate, try_catch.Exception()));
        *site = errorInfoAtThrowSite(isolate, ctx, try_catch);
        return thrown;
    }
    if (maybe_value.IsEmpty()) return nullptr;

    *threw = false;
    return trackHandle(new Global<Value>(isolate, maybe_value.ToLocalChecked()));
}

} // extern "C"
// ---- end lane: protocol ----
// ---- lane: networking ----
extern "C" {

/// Infra "serialize a JavaScript value to a JSON string", steps 1-2, as
/// ffi.zig documents. JSON::Stringify runs the intrinsic %JSON.stringify% and
/// turns its result into a String with ToString, so a result of undefined
/// arrives as the string "undefined" - which no JSON text can be (a string
/// is quoted), so that string is how undefined is recognised. What the
/// serializer throws is left pending: there is no TryCatch here.
Global<Value>* v8_JSON_StringifyValue(Global<Context>* context, Global<Value>* value, bool* no_representation) {
    *no_representation = false;
    Isolate* isolate = Isolate::GetCurrent();
    if (!isolate || !context || !value) return nullptr;
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);
    Local<String> json;
    if (!JSON::Stringify(ctx, value->Get(isolate)).ToLocal(&json)) return nullptr;
    static constexpr char kUndefined[] = "undefined";
    if (json->Length() == sizeof(kUndefined) - 1 && json->StringEquals(String::NewFromUtf8Literal(isolate, kUndefined))) {
        *no_representation = true;
        return nullptr;
    }
    return trackHandle(new Global<Value>(isolate, json));
}

} // extern "C"
// ---- end lane: networking ----
// ---- lane: realms ----
extern "C" {

/// End the edge `v8_Object_SetPrivateRef` drew from `holder` under `key`: the
/// private property is deleted, so the collector no longer reaches the value
/// through `holder` (the engine protocol's forgetTracedChild). A no-op when
/// there is none. Needs an entered context, as SetPrivateRef does.
void v8_Object_DeletePrivateRef(Global<Object>* holder, const char* key, int key_len) {
    if (!holder || holder->IsEmpty()) return;
    Isolate* isolate = Isolate::GetCurrent();
    if (!isolate) return;
    HandleScope handle_scope(isolate);
    // Read the holder before the name allocates: a weak one can be collected
    // and reset by then.
    Local<Object> object = holder->Get(isolate);
    Local<Context> context = isolate->GetCurrentContext();
    if (context.IsEmpty()) return;
    Local<String> name;
    if (!String::NewFromUtf8(isolate, key, NewStringType::kInternalized, key_len).ToLocal(&name)) return;
    Local<Private> priv = Private::ForApi(isolate, name);
    (void)object->DeletePrivate(context, priv);
}

/// The value `v8_Object_SetPrivateRef` keeps on `holder` under `key`, as a
/// Global the caller owns; null when `holder` has no such private property
/// (never set, or deleted). Script cannot reach it; this is how the engine
/// protocol's tracedValue reads a value traceValue keeps. Needs an entered
/// context, as SetPrivateRef does.
Global<Value>* v8_Object_GetPrivateRef(Global<Object>* holder, const char* key, int key_len) {
    if (!holder || holder->IsEmpty()) return nullptr;
    Isolate* isolate = Isolate::GetCurrent();
    if (!isolate) return nullptr;
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);
    // Read the holder before the name allocates (see DeletePrivateRef).
    Local<Object> object = holder->Get(isolate);
    Local<Context> context = isolate->GetCurrentContext();
    if (context.IsEmpty()) return nullptr;
    Local<String> name;
    if (!String::NewFromUtf8(isolate, key, NewStringType::kInternalized, key_len).ToLocal(&name)) return nullptr;
    Local<Private> priv = Private::ForApi(isolate, name);
    if (!object->HasPrivate(context, priv).FromMaybe(false)) return nullptr;
    Local<Value> value;
    if (!object->GetPrivate(context, priv).ToLocal(&value)) return nullptr;
    return trackHandle(new Global<Value>(isolate, value));
}

/// Keep `value` alive for exactly as long as `holder` (an object): it is
/// appended to an array held in `holder`'s private property `key`, made on
/// first use. An edge, never a root - what a Window realm whose navigable was
/// destroyed, or whose document a navigation replaced, holds its wrappers and
/// callbacks by: `holder` is its retained store, which its global object keeps
/// through its GlobalAnchor (never the global proxy, which a navigation hands
/// to the next realm - a private property set through it lands on whichever
/// global object it reaches now), so the collector can take the realm once
/// nothing reaches it (the engine protocol's Window realm ends). Runs in
/// `holder`'s creation context. A no-op for an empty holder - a store already
/// collected with its global.
void v8_Object_RetainInPrivateArray(Global<Value>* holder, const char* key, int key_len, Global<Value>* value) {
    if (!holder || holder->IsEmpty() || !value || value->IsEmpty()) return;
    Isolate* isolate = Isolate::GetCurrent();
    if (!isolate) return;
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);
    Local<Value> held = holder->Get(isolate);
    // Read before anything below allocates (see v8_Object_SetPrivateRef).
    Local<Value> retained = value->Get(isolate);
    if (!held->IsObject()) return;
    Local<Object> object = held.As<Object>();
    Local<Context> ctx;
    if (!object->GetCreationContext(isolate).ToLocal(&ctx)) {
        ctx = isolate->GetCurrentContext();
        if (ctx.IsEmpty()) return;
    }
    Context::Scope context_scope(ctx);
    Local<String> name;
    if (!String::NewFromUtf8(isolate, key, NewStringType::kInternalized, key_len).ToLocal(&name)) return;
    Local<Private> priv = Private::ForApi(isolate, name);
    Local<Value> existing;
    Local<Array> list;
    if (object->GetPrivate(ctx, priv).ToLocal(&existing) && existing->IsArray()) {
        list = existing.As<Array>();
    } else {
        list = Array::New(isolate);
        if (object->SetPrivate(ctx, priv, list).IsNothing()) return;
    }
    (void)list->Set(ctx, list->Length(), retained);
}

/// Set `holder`'s private property `key` to `value`, or delete it when
/// `value` is null: an edge from `holder` to `value`, never a root - a node's
/// wrapper keeping its parent's (the engine's node tracing). Runs in
/// `holder`'s creation context, so it needs none entered. A no-op for an
/// empty holder.
void v8_Object_PrivateRefUpdate(Global<Value>* holder, const char* key, int key_len, Global<Value>* value) {
    if (!holder || holder->IsEmpty()) return;
    Isolate* isolate = Isolate::GetCurrent();
    if (!isolate) return;
    HandleScope handle_scope(isolate);
    Local<Value> held = holder->Get(isolate);
    // Read before anything below allocates (see v8_Object_SetPrivateRef):
    // read after, a value a collection took in between read empty, and the
    // edge was deleted instead of set.
    Local<Value> target;
    if (value && !value->IsEmpty()) target = value->Get(isolate);
    if (!held->IsObject()) return;
    Local<Object> object = held.As<Object>();
    Local<Context> ctx;
    if (!object->GetCreationContext(isolate).ToLocal(&ctx)) {
        ctx = isolate->GetCurrentContext();
        if (ctx.IsEmpty()) return;
    }
    Context::Scope context_scope(ctx);
    Local<String> name;
    if (!String::NewFromUtf8(isolate, key, NewStringType::kInternalized, key_len).ToLocal(&name)) return;
    Local<Private> priv = Private::ForApi(isolate, name);
    if (!target.IsEmpty()) {
        (void)object->SetPrivate(ctx, priv, target);
    } else {
        (void)object->DeletePrivate(ctx, priv);
    }
}

/// Add `member` to (`add`), or remove it from, the JS Set held in `holder`'s
/// private property `key`, made on the first add. An edge from `holder` to
/// each member, never a root: how a parent node's wrapper keeps the wrappers
/// of its children (the engine's node tracing - Blink's Node::Trace visits a
/// node's children, WebKit keeps a node's wrapper for as long as its tree's
/// root is reachable). Runs in `holder`'s creation context. A no-op for an
/// empty holder or member, and for a remove that finds no set.
void v8_Object_PrivateSetUpdate(Global<Value>* holder, const char* key, int key_len, Global<Value>* member, bool add) {
    if (!holder || holder->IsEmpty() || !member || member->IsEmpty()) return;
    Isolate* isolate = Isolate::GetCurrent();
    if (!isolate) return;
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);
    Local<Value> held = holder->Get(isolate);
    // Read before anything below allocates (see v8_Object_SetPrivateRef).
    Local<Value> element = member->Get(isolate);
    if (!held->IsObject()) return;
    Local<Object> object = held.As<Object>();
    Local<Context> ctx;
    if (!object->GetCreationContext(isolate).ToLocal(&ctx)) {
        ctx = isolate->GetCurrentContext();
        if (ctx.IsEmpty()) return;
    }
    Context::Scope context_scope(ctx);
    Local<String> name;
    if (!String::NewFromUtf8(isolate, key, NewStringType::kInternalized, key_len).ToLocal(&name)) return;
    Local<Private> priv = Private::ForApi(isolate, name);
    Local<Value> existing;
    Local<Set> set;
    if (object->GetPrivate(ctx, priv).ToLocal(&existing) && existing->IsSet()) {
        set = existing.As<Set>();
    } else {
        if (!add) return;
        set = Set::New(isolate);
        if (object->SetPrivate(ctx, priv, set).IsNothing()) return;
    }
    if (add) {
        (void)set->Add(ctx, element);
    } else {
        (void)set->Delete(ctx, element);
    }
}

/// Make `context`'s handle weak: `callback(user_data)` runs (first pass,
/// after V8 reset the handle) once the collector takes the context. The
/// handle stays the caller's to dispose (v8_Context_Dispose ends the arm).
void v8_Context_SetWeak(Global<Context>* context, void* user_data, ZigWeakCallbackFn callback) {
    if (!context || context->IsEmpty()) return;
    v8_Global_SetWeak(static_cast<void*>(context), user_data, callback);
}

/// Tag `global` with `realm_key` (the context manager's key of the realm
/// whose API stored it). A dispose untags it.
void v8_Global_TagRealm(Global<Value>* global, uintptr_t realm_key) {
    if (!global || !realm_key) return;
    std::lock_guard<std::mutex> guard(realmTagLock());
    auto inserted = realmTaggedHandles().insert_or_assign(static_cast<const void*>(global), realm_key);
    if (inserted.second) realmTagCount().fetch_add(1, std::memory_order_release);
    // With the entry, under the lock: an entry always has its flag.
    setHandleFlag(global, kRealmTaggedFlag);
}

static void taggedHandleCollected(void*, size_t) {}

/// A Window realm that is detached (`realm_key` its context's key): every
/// handle tagged with it is kept by an edge from `holder` - its retained store
/// (v8_Object_RetainInPrivateArray, `key`) - instead, and made weak; its
/// holder still owns and disposes it, and it reads empty once the realm is
/// collected. Returns how many it weakened.
int v8_Object_WeakenTaggedHandles(Global<Value>* holder, uintptr_t realm_key, const char* key, int key_len) {
    if (!holder || holder->IsEmpty() || !realm_key) return 0;
    std::vector<const void*> handles;
    {
        // Taken out under the lock; made weak after it - SetWeak takes the
        // weak-arm lock, and nothing here may hold one lock into another.
        std::lock_guard<std::mutex> guard(realmTagLock());
        auto& tagged = realmTaggedHandles();
        for (const auto& kv : tagged) {
            if (kv.second == realm_key) handles.push_back(kv.first);
        }
        for (const void* h : handles) {
            tagged.erase(h);
            if (!handleIsEmpty(h)) clearHandleFlag(h, kRealmTaggedFlag);
        }
        realmTagCount().fetch_sub(handles.size(), std::memory_order_release);
    }
    for (const void* h : handles) {
        Global<Value>* global = const_cast<Global<Value>*>(static_cast<const Global<Value>*>(h));
        if (global->IsEmpty()) continue;
        v8_Object_RetainInPrivateArray(holder, key, key_len, global);
        v8_Global_SetWeak(static_cast<void*>(global), nullptr, taggedHandleCollected);
    }
    return static_cast<int>(handles.size());
}

} // extern "C"
// ---- end lane: realms ----

// ---- lane: speed ----
// HTML "abort a running script" (engine.abortRunningScript / resumeScripts).
extern "C" {

// Thread-safe in V8: callable from any thread without a Locker.
void v8_Isolate_TerminateExecution(Isolate* isolate) {
    if (isolate) isolate->TerminateExecution();
}

void v8_Isolate_CancelTerminateExecution(Isolate* isolate) {
    if (isolate) isolate->CancelTerminateExecution();
}

bool v8_Isolate_IsExecutionTerminating(Isolate* isolate) {
    return isolate && isolate->IsExecutionTerminating();
}

} // extern "C"
// ---- end lane: speed ----

// ---- lane: conversions ----
// engine.hasOwnProperty: ECMAScript HasOwnProperty(O, P), whose throw (a
// Proxy's getOwnPropertyDescriptor trap) v8_Object_HasOwnProperty swallows
// into false.
extern "C" {

int v8_Object_HasOwnPropertyOrThrow(Global<Object>* object, Global<Context>* context, Global<Value>* key) {
    Isolate* isolate = Isolate::GetCurrent();
    NativeStepScope native_step(isolate);  // not a script call: no kAuto checkpoint (NativeStepScope)
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<Object> obj = object->Get(isolate);
    Local<Value> k = key->Get(isolate);
    if (!k->IsName()) return -1;
    Maybe<bool> result = obj->HasOwnProperty(ctx, k.As<Name>());
    // Nothing: [[GetOwnProperty]] threw, and the exception stays pending.
    if (result.IsNothing()) return -1;
    return result.FromJust() ? 1 : 0;
}

/// The bytes a buffer source over a NON-shared buffer holds, in one call
/// (engine.borrowBufferSourceBytes reads TextDecoder.decode's input with it):
/// an ArrayBuffer's - none when detached - or the window [[ByteOffset]],
/// [[ByteLength]] of a view over an ArrayBuffer. False for a
/// SharedArrayBuffer, a view over one, and anything that is not a buffer
/// source. A view's Buffer() gives an on-heap typed array its off-heap store
/// first, so the pointer holds until script next runs or the buffer is
/// detached.
bool v8_BufferSource_UnsharedBytes(Global<Value>* value, void** data, size_t* byte_length) {
    *data = nullptr;
    *byte_length = 0;
    if (!value || value->IsEmpty()) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> v = value->Get(isolate);
    Local<ArrayBuffer> ab;
    size_t offset = 0;
    size_t length = 0;
    if (v->IsArrayBufferView()) {
        Local<ArrayBufferView> view = v.As<ArrayBufferView>();
        Local<Object> buffer = view->Buffer();
        if (!buffer->IsArrayBuffer()) return false;
        ab = buffer.As<ArrayBuffer>();
        offset = view->ByteOffset();
        length = view->ByteLength();
    } else if (v->IsArrayBuffer()) {
        ab = v.As<ArrayBuffer>();
        length = ab->ByteLength();
    } else {
        return false;
    }
    if (ab->WasDetached() || length == 0) return true;
    void* base = ab->Data();
    if (!base) return true;
    *data = static_cast<uint8_t*>(base) + offset;
    *byte_length = length;
    return true;
}

/// The bytes an AllowSharedBufferSource holds (engine.
/// getCopyOfAllowSharedBufferSourceBytes): an ArrayBuffer's - none when
/// detached - a SharedArrayBuffer's, or the window [[ByteOffset]],
/// [[ByteLength]] of a view over either. False when `value` is none of those.
bool v8_AllowSharedBufferSource_Bytes(Global<Value>* value, void** data, size_t* byte_length) {
    *data = nullptr;
    *byte_length = 0;
    if (!value || value->IsEmpty()) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> v = value->Get(isolate);
    if (v->IsArrayBuffer()) {
        Local<ArrayBuffer> ab = v.As<ArrayBuffer>();
        if (ab->WasDetached()) return true;
        *data = ab->Data();
        *byte_length = ab->ByteLength();
        return true;
    }
    if (v->IsSharedArrayBuffer()) {
        Local<SharedArrayBuffer> sab = v.As<SharedArrayBuffer>();
        *data = sab->Data();
        *byte_length = sab->ByteLength();
        return true;
    }
    if (v->IsArrayBufferView()) {
        Local<ArrayBufferView> view = v.As<ArrayBufferView>();
        Local<Object> buffer = view->Buffer();
        void* base = nullptr;
        if (buffer->IsSharedArrayBuffer()) {
            base = buffer.As<SharedArrayBuffer>()->Data();
        } else if (buffer->IsArrayBuffer()) {
            Local<ArrayBuffer> ab = buffer.As<ArrayBuffer>();
            if (ab->WasDetached()) return true;
            base = ab->Data();
        }
        size_t length = view->ByteLength();
        if (!base || length == 0) return true;
        *data = static_cast<uint8_t*>(base) + view->ByteOffset();
        *byte_length = length;
        return true;
    }
    return false;
}

} // extern "C"
// ---- end lane: conversions ----
// ---- lane: cspenforce ----
// ============================================================================
// The engine protocol's code generation checks [code_generation_checks]:
// HostEnsureCanCompileStrings and HostGetCodeForEval through V8's
// ModifyCodeGenerationFromStringsCallback, HostEnsureCanCompileWasmBytes
// through its AllowWasmCodeGenerationCallback - as Blink's
// V8Initializer::CodeGenerationCheckCallbackInMainThread and
// WasmCodeGenerationCheckCallback do. V8 asks the strings callback only for
// a context whose allow_code_gen_from_strings is false
// (Compiler::ValidateDynamicCompilationSource), so every realm of a hooked
// agent is made with it false (v8_Context_AllowCodeGenerationFromStrings).
// ============================================================================

extern "C" {

/// The strings dispatcher's answer: 0 blocked; 1 allowed, V8 compiling the
/// source it was given (or, for an object, returning it unchanged); 2
/// allowed with `*code` - malloc'd UTF-8 of `*code_len` bytes, freed here -
/// as the source. `source` is the source as UTF-8 when it is a string, else
/// null and `object` the value (BORROWED for the call).
typedef int (*ProtocolCodeGenerationDispatch)(
    Isolate* isolate,
    Global<Context>* context,
    const char* source,
    size_t source_len,
    Global<Value>* object,
    bool is_code_like,
    char** code,
    size_t* code_len
);
typedef bool (*ProtocolWasmCodeGenerationDispatch)(Isolate* isolate, Global<Context>* context);

// process-wide: the one Zig dispatcher (protocol_agents.onCodeGenerationFromStrings) every hooked agent's isolate calls, finding its agent by isolate; written at process start (protocol_agents.initializeEngine, before any agent thread exists). Atomic: a test may start the engine again on another thread, storing the same function (tsanfix1).
static std::atomic<ProtocolCodeGenerationDispatch> g_protocol_code_generation{nullptr};
// process-wide: the one Zig dispatcher (protocol_agents.onWasmCodeGeneration) every hooked agent's isolate calls, finding its agent by isolate; written at process start (protocol_agents.initializeEngine, before any agent thread exists). Atomic, as g_protocol_code_generation.
static std::atomic<ProtocolWasmCodeGenerationDispatch> g_protocol_wasm_code_generation{nullptr};

/// V8 calls this from eval (direct and indirect) and CreateDynamicFunction,
/// inside their own HandleScope: the modified source made here lives in it.
static ModifyCodeGenerationFromStringsResult ProtocolModifyCodeGenerationFromStrings(
    Local<Context> context,
    Local<Value> source,
    bool is_code_like
) {
    ModifyCodeGenerationFromStringsResult result;
    result.codegen_allowed = true;
    auto dispatch = g_protocol_code_generation.load(std::memory_order_acquire);
    if (!dispatch) return result;
    Isolate* isolate = Isolate::GetCurrent();  // V8 >= 14: no Context::GetIsolate (98282b9b8fa); a callback runs on its isolate
    Global<Context> realm(isolate, context);
    char* code = nullptr;
    size_t code_len = 0;
    int verdict = 1;
    if (source->IsString()) {
        String::Utf8Value utf8(isolate, source);
        verdict = dispatch(isolate, &realm, *utf8 ? *utf8 : "", *utf8 ? utf8.length() : 0, nullptr, is_code_like, &code, &code_len);
    } else if (source->IsObject()) {
        Global<Value> object(isolate, source);
        verdict = dispatch(isolate, &realm, nullptr, 0, &object, is_code_like, &code, &code_len);
    }
    // A primitive that is no string: eval returns it (PerformEval step 2),
    // unchecked.
    if (verdict == 0) {
        free(code);
        result.codegen_allowed = false;
        return result;
    }
    if (verdict == 2 && code) {
        Local<String> replacement;
        if (String::NewFromUtf8(isolate, code, NewStringType::kNormal, static_cast<int>(code_len)).ToLocal(&replacement)) {
            result.modified_source = replacement;
        } else {
            // No source to compile: compile nothing.
            result.codegen_allowed = false;
        }
    }
    free(code);
    return result;
}

static bool ProtocolAllowWasmCodeGeneration(Local<Context> context, Local<String> source) {
    (void)source;  // V8 passes the empty string (wasm-module.cc IsWasmCodegenAllowed).
    auto dispatch = g_protocol_wasm_code_generation.load(std::memory_order_acquire);
    if (!dispatch) return true;
    Isolate* isolate = Isolate::GetCurrent();  // V8 >= 14: no Context::GetIsolate (98282b9b8fa); a callback runs on its isolate
    Global<Context> realm(isolate, context);
    return dispatch(isolate, &realm);
}

/// The process's code generation dispatchers (one Zig function each, which
/// finds the agent's hooks by its isolate): set once, while the process
/// starts (engine.initializeEngine), before any agent's thread runs - never
/// per agent, which with agents on their own threads would be concurrent
/// writes of one global.
void v8_SetProtocolCodeGenerationDispatchers(ProtocolCodeGenerationDispatch strings, ProtocolWasmCodeGenerationDispatch wasm) {
    g_protocol_code_generation.store(strings, std::memory_order_release);
    g_protocol_wasm_code_generation.store(wasm, std::memory_order_release);
}

/// Install the protocol's code generation checks on `isolate`, each only
/// when asked. With no dispatcher set (a host that never called
/// initializeEngine), the callbacks allow everything.
void v8_Isolate_SetProtocolCodeGenerationHooks(Isolate* isolate, bool strings, bool wasm) {
    if (strings) isolate->SetModifyCodeGenerationFromStringsCallback(ProtocolModifyCodeGenerationFromStrings);
    if (wasm) isolate->SetAllowWasmCodeGenerationCallback(ProtocolAllowWasmCodeGeneration);
}

/// Whether `context` allows code generation from strings without asking
/// (Context::IsCodeGenerationFromStringsAllowed), for tests.
bool v8_Context_IsCodeGenerationFromStringsAllowed(Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    return context->Get(isolate)->IsCodeGenerationFromStringsAllowed();
}

} // extern "C"
// ---- end lane: cspenforce ----
// ---- WebAssembly JS API adaptation ----
// V8 chooses the constructor's own intrinsic prototype when
// NewTarget.prototype is primitive. Firefox/Safari and WebIDL instead use
// NewTarget's realm (wpt.fyi stable runs 5195601938743296/5351410937102336/
// 5184406099853312: proto-from-ctor-realm 45/120, 120/120, 120/120);
// recheck prototype fallback at every V8 upgrade.
// The memory64 `address` adaptation is gone (lane v8up b3c): V8 13.1 read the
// descriptor's old `index` spelling, so Memory/Table descriptors went through
// a Proxy that answered `index` with the converted `address`; V8 15.7 reads
// `address` itself (wasm-js.cc GetAddressType, 1483-1510 at 15.7.112.43), and
// the adaptation made it read twice - the shim's read, then V8's through the
// Proxy, which forwarded every key but `index` (wpt wasm/jsapi/memory/
// constructor.any.js and table/constructor.any.js "Order of evaluation").
// The JSPI Suspending adaptation is gone too (lane v8up b3d): V8 13.1 left JSPI
// "create a suspending function" step 3.15 to it (a Proxy around the callable
// whose apply trap ran PromiseResolve with the import realm's intrinsics); V8
// 15.7 runs the step itself (turboshaft wasm-wrappers.h BuildSuspend,
// PromiseResolve with the importing instance's native context), so the
// adaptation resolved twice, and a promise returned from another realm was
// assimilated by the import's realm first (tests/v8/wj1_wasm_constructor_test
// "resolves through the promising realm's intrinsics": the evidence).
extern "C" {

static Local<Private> wasmIntrinsicPrototypesKey(Isolate* isolate) {
    return Private::ForApi(isolate, String::NewFromUtf8Literal(isolate, "crane.wasm.intrinsicPrototypes"));
}

static Local<Private> wasmPreparationKey(Isolate* isolate) {
    return Private::ForApi(isolate, String::NewFromUtf8Literal(isolate, "crane.wasm.preparation"));
}

// Only traced references are retained before first use. The private constructor
// factory below reads these same slots into its original constant bindings.
enum WasmPreparationSlot : uint32_t {
    kWasmNamespace,
    kWasmConstruct, kWasmGet, kWasmApply, kWasmProxy, kWasmTypeError, kWasmObject,
    kWasmDefine, kWasmOwnKeys, kWasmDescriptor, kWasmSetPrototype, kWasmPrototype,
    kWasmFunctionPrototype, kWasmBind, kWasmHasInstanceKey, kWasmHasInstance, kWasmSlice,
    kWasmPreparationSize,
};

static bool ensureWasmAdapters(Local<Context> context);

static Local<Private> wasmExceptionStackKey(Isolate* isolate) {
    return Private::ForApi(isolate, String::NewFromUtf8Literal(isolate, "crane.wasm.exceptionStack"));
}

static bool wasmCaptureExceptionStack(Local<Context> context, Local<Object> exception) {
    Isolate* isolate = Isolate::GetCurrent();  // V8 >= 14: no Context::GetIsolate (98282b9b8fa); a callback runs on its isolate
    Local<String> stack_name = String::NewFromUtf8Literal(isolate, "stack");
    Maybe<bool> captured = exception->HasOwnProperty(context, stack_name);
    if (captured.IsNothing()) return false;
    if (!captured.FromJust()) return true;

    // JS API 5.9 constructor step 11: capture a DOMString now. V8 13.1.203
    // messages.cc:1203-1240 installs a lazy own accessor instead. Reading it
    // would invoke Error.prepareStackTrace, a callback the spec never calls.
    // No script runs between native construction and this public native-frame
    // snapshot. Its format is implementation-defined; no Error properties or
    // user functions participate. An untraced/native-wasm exception has no slot.
    Local<StackTrace> trace = StackTrace::CurrentStackTrace(isolate, 64, StackTrace::kDetailed);
    std::string formatted = "WebAssembly.Exception";
    if (!trace.IsEmpty()) {
        for (int i = 0; i < trace->GetFrameCount(); ++i) {
            Local<StackFrame> frame = trace->GetFrame(isolate, i);
            formatted += "\n    at ";
            Local<String> name = frame->GetFunctionName();
            if (!name.IsEmpty() && name->Length() > 0) {
                String::Utf8Value utf8(isolate, name);
                if (*utf8) formatted.append(*utf8, utf8.length());
            } else {
                formatted += "<anonymous>";
            }
            formatted += " (";
            Local<String> source = frame->GetScriptNameOrSourceURL();
            if (!source.IsEmpty() && source->Length() > 0) {
                String::Utf8Value utf8(isolate, source);
                if (*utf8) formatted.append(*utf8, utf8.length());
            } else {
                formatted += "<anonymous>";
            }
            formatted += ":" + std::to_string(frame->GetLineNumber()) + ":" + std::to_string(frame->GetColumn()) + ")";
        }
    }
    Local<String> stack;
    if (!String::NewFromUtf8(isolate, formatted.c_str(), NewStringType::kNormal,
            static_cast<int>(formatted.size())).ToLocal(&stack)) return false;
    return exception->SetPrivate(context, wasmExceptionStackKey(isolate), stack).FromMaybe(false) &&
        exception->Delete(context, stack_name).FromMaybe(false);
}

static void WasmExceptionStackGet(const FunctionCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    Local<Context> context = isolate->GetCurrentContext();
    Local<Array> brand = info.DataV2().As<Value>().As<Array>();
    Local<Value> is_exception, tag, ignored, stack;
    if (!brand->Get(context, 0).ToLocal(&is_exception) || !brand->Get(context, 1).ToLocal(&tag)) return;
    // The captured native is() performs the real internal-slot brand check.
    // The private tag never escapes, and the method's boolean result is unused.
    if (!is_exception.As<Function>()->Call(context, info.This(), 1, &tag).ToLocal(&ignored)) return;
    if (!info.This()->GetPrivate(context, wasmExceptionStackKey(isolate)).ToLocal(&stack)) return;
    info.GetReturnValue().Set(stack);
}

// ECMAScript GetFunctionRealm, following V8 13.1.203's iterative walk in
// src/objects/js-objects.cc:647-685, through public APIs only. No Global is
// acquired: these handles live only for the native construct trap.
static MaybeLocal<Context> wasmConstructorRealm(Isolate* isolate, Local<Value> target) {
    for (;;) {
        if (target->IsProxy()) {
            Local<Proxy> proxy = target.As<Proxy>();
            // GetFunctionRealm step 4.a: validation can fail after the
            // prototype getter revokes the proxy.
            if (proxy->IsRevoked()) {
                isolate->ThrowException(Exception::TypeError(
                    String::NewFromUtf8Literal(isolate, "Cannot construct with a revoked Proxy")));
                return {};
            }
            target = proxy->GetTarget();
            continue;
        }
        // Step 3: a bound function has its target's realm, including when
        // its bind method came from a third realm.
        if (target->IsFunction()) {
            Local<Value> bound = target.As<Function>()->GetBoundFunction();
            if (!bound->IsUndefined()) {
                target = bound;
                continue;
            }
        }
        return target.As<Object>()->GetCreationContext(isolate);
    }
}

static void WasmConstructorConstruct(const FunctionCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    Local<Context> context = isolate->GetCurrentContext();
    // The private derived constructor supplies the original, an argument
    // array and the actual NewTarget. This nonconstructor callback has no
    // preallocated receiver and causes no extra prototype Get.
    Local<Function> original = info[0].As<Function>();
    Local<Array> arguments = info[1].As<Array>();
    Local<Object> new_target = info[2].As<Object>();
    const uint32_t index = info.DataV2().As<Value>().As<Uint32>()->Value();

    // WebIDL "internally create a new object" steps 3.2-3.3: exactly one
    // Get, before any descriptor conversion; primitive values select the
    // original interface prototype in GetFunctionRealm(NewTarget).
    Local<Value> prototype;
    if (!new_target->Get(context, String::NewFromUtf8Literal(isolate, "prototype")).ToLocal(&prototype)) return;
    if (!prototype->IsObject()) {
        Local<Context> target_realm;
        if (!wasmConstructorRealm(isolate, new_target).ToLocal(&target_realm)) return;
        if (!ensureWasmAdapters(target_realm)) return;
        Local<Value> intrinsics;
        if (!target_realm->Global()->GetPrivate(target_realm, wasmIntrinsicPrototypesKey(isolate)).ToLocal(&intrinsics)) return;
        if (!intrinsics->IsArray()) {
            isolate->ThrowException(Exception::TypeError(
                String::NewFromUtf8Literal(isolate, "WebAssembly constructor realm is not initialized")));
            return;
        }
        if (!intrinsics.As<Array>()->Get(target_realm, index).ToLocal(&prototype)) return;
    }

    std::vector<Local<Value>> args;
    args.reserve(arguments->Length());
    for (uint32_t i = 0; i < arguments->Length(); ++i) {
        Local<Value> value;
        if (!arguments->Get(context, i).ToLocal(&value)) return;
        args.push_back(value);
    }
    // Memory's and Table's descriptors go to V8 as they are: it reads
    // `address` itself since 13.3 (see the section comment).
    Local<Object> made;
    if (!original->NewInstance(context, static_cast<int>(args.size()), args.data()).ToLocal(&made)) return;
    // Index 7 is Exception (5/6 held 13.1's JSPI Promise intrinsics: empty).
    if (index == 7 && !wasmCaptureExceptionStack(context, made)) return;
    // WebIDL step 9. The native constructor makes the Wasm internal slots;
    // only its externally observable prototype needs adapting.
    if (!made->GetPrototype()->StrictEquals(prototype) && !made->SetPrototype(context, prototype).FromMaybe(false)) return;
    info.GetReturnValue().Set(made);
}

static void WasmGlobalValueSet(const FunctionCallbackInfo<Value>& info) {
    // WebIDL's attribute setter steps now convert a missing argument as
    // undefined. PR whatwg/webidl#1498 (2025), WebAssembly/spec#2075 and WPT
    // 5078da54e150d8d380062402eb09ada3aa0857fd record this newer behavior:
    // Chrome ships it; Firefox bug 2078950 and Safari still lag. V8 13.1's
    // wasm-js.cc WebAssemblyGlobalSetValue rejects Length() == 0, so supply
    // exactly one argument and let V8 retain branding and value conversion.
    Isolate* isolate = info.GetIsolate();
    Local<Value> argument = info[0];
    Local<Value> result;
    if (!info.DataV2().As<Value>().As<Function>()->Call(isolate->GetCurrentContext(), info.This(), 1, &argument).ToLocal(&result)) return;
    info.GetReturnValue().Set(result);
}

// Materialize only on a namespace read or an indirect use of this realm's
// Wasm intrinsics. Public deletion/assignment never removes the private state.
static bool initializeWasmAdapters(Local<Context> context, Local<Array> preparation) {
    Isolate* isolate = Isolate::GetCurrent();  // V8 >= 14: no Context::GetIsolate (98282b9b8fa); a callback runs on its isolate
    Context::Scope context_scope(context);
    NativeStepScope native_step(isolate);
    Local<Value> wasm_value;
    if (!preparation->Get(context, kWasmNamespace).ToLocal(&wasm_value)) return false;
    Local<Object> wasm = wasm_value.As<Object>();
    const char* const names[] = {"Module", "Instance", "Memory", "Table", "Global", "Exception"};
    Local<Function> originals[6];
    Local<Value> prototypes[6];
    Local<Function> replacements[6];
    // These prototype-realm wrappers for Module, Instance, Memory, Table,
    // Global and Exception exist ONLY because V8 13.1 picks the wrong
    // prototype realm. RE-CHECK at EVERY V8 upgrade: delete the wrappers
    // when V8 supplies the native NewTarget-realm fallback. The independent
    // Memory/Table address and Exception stack adaptations need their own
    // upgrade checks; they are not reasons to retain prototype wrapping.
    // Ordinary new calls the original directly; only a custom NewTarget uses
    // the native prototype/realm adapter. A derived class returns the native
    // object without super, avoiding a receiver allocation/prototype Get before
    // its body. Expose its bound function so toString stays NativeFunction.
    // OrdinaryHasInstance follows the hidden class, whose private forwarder
    // uses the original's immutable prototype. The exposed function has only
    // the original interface's own properties, with their exact descriptors.
    Local<String> fast_source = String::NewFromUtf8Literal(isolate,
        "(function(saved) { 'use strict';"
        "const construct = saved[1], get = saved[2], apply = saved[3];"
        "const P = saved[4], TypeErrorCtor = saved[5], Base = saved[6];"
        "const define = saved[7], ownKeys = saved[8], descriptorOf = saved[9];"
        "const setPrototype = saved[10], prototypeOf = saved[11];"
        "const functionPrototype = saved[12], bind = saved[13];"
        "const hasInstanceKey = saved[14], hasInstance = saved[15], slice = saved[16];"
        "return function(target, native, kind) {"
        "const W = {[target.name]: class extends Base { constructor(a0, a1, a2) {"
        "const newTarget = new.target;"
        "if (newTarget !== W) return native(target, apply(slice, arguments, []), newTarget);"
        "const count = arguments.length;"
        // Exception's optional trace requires the captured-string adapter.
        // Missing/null/undefined options request no trace and need no work.
        "if (kind === 5 && count >= 3 && a2 !== undefined && a2 !== null) return native(target, apply(slice, arguments, []), replacement);"
        "if (count === 1) return new target(a0);"
        "if (count === 2) return new target(a0, a1);"
        "return construct(target, arguments);"
        "}}}[target.name];"
        "setPrototype(W, functionPrototype);"
        "define(W, hasInstanceKey, {__proto__:null, value(value) { return apply(hasInstance, target, [value]); }});"
        "const replacement = apply(bind, W, [undefined]);"
        "setPrototype(replacement, prototypeOf(target));"
        "const keys = ownKeys(target);"
        "for (let i = 0; i < keys.length; ++i) define(replacement, keys[i], setPrototype(descriptorOf(target, keys[i]), null));"
        "return replacement; }; })");
    Local<Script> fast_script;
    Local<Value> fast_maker, fast_factory;
    if (!Script::Compile(context, fast_source).ToLocal(&fast_script) ||
        !fast_script->Run(context).ToLocal(&fast_maker) || !fast_maker->IsFunction()) return false;
    Local<Value> fast_args[] = {preparation};
    if (!fast_maker.As<Function>()->Call(context, Undefined(isolate), 1, fast_args).ToLocal(&fast_factory) ||
        !fast_factory->IsFunction()) return false;
    // Prepare everything before publishing a replacement. The original
    // functions preserve name, length, statics and call-without-new errors.
    for (uint32_t i = 0; i < 6; ++i) {
        Local<String> name = String::NewFromUtf8(isolate, names[i]).ToLocalChecked();
        Local<Value> original;
        if (!wasm->Get(context, name).ToLocal(&original) || !original->IsFunction()) return false;
        originals[i] = original.As<Function>();
        if (!originals[i]->Get(context, String::NewFromUtf8Literal(isolate, "prototype")).ToLocal(&prototypes[i]) || !prototypes[i]->IsObject()) return false;
        Local<Function> construct;
        const uint32_t intrinsic_index = i == 5 ? 7 : i;
        if (!Function::New(context, WasmConstructorConstruct, Integer::NewFromUnsigned(isolate, intrinsic_index), 3, ConstructorBehavior::kThrow).ToLocal(&construct)) return false;
        Local<Value> factory_args[] = {originals[i], construct, Integer::NewFromUnsigned(isolate, i)};
        Local<Value> replacement;
        if (!fast_factory.As<Function>()->Call(context, Undefined(isolate), 3, factory_args).ToLocal(&replacement) || !replacement->IsFunction()) return false;
        replacements[i] = replacement.As<Function>();
    }
    // The private JS constructor is embedding machinery, not the script
    // responsible for a CSP violation. Retain its unforgeable script ID for
    // running-script attribution below, without retaining a native handle.
    // Slots 10/11 also serve a cloned Module/Memory's lazy constructor. They
    // must not consult the mutable namespace after initialization.
    // Slots 5/6 held V8 13.1's JSPI Promise intrinsics and slot 8 its address
    // descriptor factory: kept empty, so the slots after them keep their indices.
    Local<Value> intrinsic_values[] = {prototypes[0], prototypes[1], prototypes[2], prototypes[3], prototypes[4], Undefined(isolate), Undefined(isolate), prototypes[5], Undefined(isolate),
        Integer::New(isolate, fast_script->GetUnboundScript()->ScriptId()), replacements[0], replacements[2]};
    Local<Array> intrinsics = Array::New(isolate, intrinsic_values, 12);
    if (!intrinsics->SetIntegrityLevel(context, IntegrityLevel::kFrozen).FromMaybe(false)) return false;
    if (!context->Global()->SetPrivate(context, wasmIntrinsicPrototypesKey(isolate), intrinsics).FromMaybe(false)) return false;
    for (uint32_t i = 0; i < 6; ++i) {
        // A received Module/Memory can expose its prototype before namespace
        // access. Leave its lazy constructor alone: its getter returns the
        // private replacement, and any user overwrite/deletion must survive.
        if (i != 0 && i != 2) {
            if (!prototypes[i].As<Object>()->DefineOwnProperty(context, String::NewFromUtf8Literal(isolate, "constructor"), replacements[i], DontEnum).FromMaybe(false)) return false;
        }
        Local<String> name = String::NewFromUtf8(isolate, names[i]).ToLocalChecked();
        if (!wasm->DefineOwnProperty(context, name, replacements[i], DontEnum).FromMaybe(false)) return false;
    }
    Local<Object> global_prototype = prototypes[4].As<Object>();
    Local<String> value_name = String::NewFromUtf8Literal(isolate, "value");
    Local<Value> descriptor_value;
    if (!global_prototype->GetOwnPropertyDescriptor(context, value_name).ToLocal(&descriptor_value) || !descriptor_value->IsObject()) return false;
    Local<Object> descriptor = descriptor_value.As<Object>();
    Local<Value> getter, setter, enumerable, configurable;
    if (!descriptor->Get(context, String::NewFromUtf8Literal(isolate, "get")).ToLocal(&getter) ||
        !descriptor->Get(context, String::NewFromUtf8Literal(isolate, "set")).ToLocal(&setter) || !setter->IsFunction() ||
        !descriptor->Get(context, String::NewFromUtf8Literal(isolate, "enumerable")).ToLocal(&enumerable) ||
        !descriptor->Get(context, String::NewFromUtf8Literal(isolate, "configurable")).ToLocal(&configurable)) return false;
    Local<Function> setter_adapter;
    if (!Function::New(context, WasmGlobalValueSet, setter, 1, ConstructorBehavior::kThrow).ToLocal(&setter_adapter)) return false;
    setter_adapter->SetName(String::NewFromUtf8Literal(isolate, "set value"));
    PropertyDescriptor value_descriptor(getter, setter_adapter);
    value_descriptor.set_enumerable(enumerable->IsTrue());
    value_descriptor.set_configurable(configurable->IsTrue());
    if (!global_prototype->DefineProperty(context, value_name, value_descriptor).FromMaybe(false)) return false;

    // Exception.length is V8's own: 2 since V8 15.x, the JS API's
    // Exception(tag, payload, options) and WPT exception/constructor.tentative
    // "length" - Chrome 156 ships it; Firefox 159 and Safari 27 still answer 1,
    // behind the spec (golden rule 2: the spec; probe
    // tmp/probes/v8up-wasm-order, lane v8up b3c). The replacement copies it.
    // For stack, Chrome/Firefox expose a prototype member, but disagree on
    // enumerability; Safari has no member. With no enumerability majority,
    // follow the spec's enumerable getter (exception-handling PR 218, 2022).
    Local<Object> exception_prototype = prototypes[5].As<Object>();
    Local<Value> is_exception, tag_constructor;
    if (!exception_prototype->Get(context, String::NewFromUtf8Literal(isolate, "is")).ToLocal(&is_exception) || !is_exception->IsFunction() ||
        !wasm->Get(context, String::NewFromUtf8Literal(isolate, "Tag")).ToLocal(&tag_constructor) || !tag_constructor->IsFunction()) return false;
    Local<Name> tag_names[] = {String::NewFromUtf8Literal(isolate, "parameters")};
    Local<Value> tag_values[] = {Array::New(isolate)};
    Local<Value> tag_descriptor = Object::New(isolate, Null(isolate), tag_names, tag_values, 1);
    Local<Object> brand_tag;
    if (!tag_constructor.As<Function>()->NewInstance(context, 1, &tag_descriptor).ToLocal(&brand_tag)) return false;
    Local<Value> brand_values[] = {is_exception, brand_tag};
    Local<Array> brand = Array::New(isolate, brand_values, 2);
    if (!brand->SetIntegrityLevel(context, IntegrityLevel::kFrozen).FromMaybe(false)) return false;
    Local<Function> stack_getter;
    if (!Function::New(context, WasmExceptionStackGet, brand, 0, ConstructorBehavior::kThrow).ToLocal(&stack_getter)) return false;
    stack_getter->SetName(String::NewFromUtf8Literal(isolate, "get stack"));
    PropertyDescriptor stack_descriptor(stack_getter, Undefined(isolate));
    stack_descriptor.set_enumerable(true);
    stack_descriptor.set_configurable(true);
    if (!exception_prototype->DefineProperty(context, String::NewFromUtf8Literal(isolate, "stack"), stack_descriptor).FromMaybe(false)) return false;
    return true;
}

static bool ensureWasmAdapters(Local<Context> context) {
    Isolate* isolate = Isolate::GetCurrent();  // V8 >= 14: no Context::GetIsolate (98282b9b8fa); a callback runs on its isolate
    Local<Value> intrinsics, preparation;
    if (!context->Global()->GetPrivate(context, wasmIntrinsicPrototypesKey(isolate)).ToLocal(&intrinsics)) return false;
    if (intrinsics->IsArray()) return true;
    if (!context->Global()->GetPrivate(context, wasmPreparationKey(isolate)).ToLocal(&preparation)) return false;
    // Unprepared contexts retain the caller's existing missing-intrinsics
    // check. Do not recreate a deleted or overwritten public namespace.
    if (!preparation->IsArray()) return true;
    if (!initializeWasmAdapters(context, preparation.As<Array>())) return false;
    return context->Global()->DeletePrivate(context, wasmPreparationKey(isolate)).FromMaybe(false);
}

static void WasmNamespaceGet(Local<Name>, const PropertyCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    Local<Array> preparation = info.DataV2().As<Value>().As<Array>();
    Local<Context> context;
    // A different realm (or an inheriting receiver) may perform the first
    // read. All adapters and intrinsics must belong to the namespace's realm.
    if (!preparation->GetCreationContext(isolate).ToLocal(&context)) return;
    Context::Scope context_scope(context);
    if (!ensureWasmAdapters(context)) return;
    Local<Value> wasm;
    if (preparation->Get(context, kWasmNamespace).ToLocal(&wasm)) info.GetReturnValue().Set(wasm);
}

static void WasmPrototypeConstructorGet(const PropertyCallbackInfo<Value>& info, uint32_t intrinsic_index) {
    Isolate* isolate = info.GetIsolate();
    Local<Array> preparation = info.DataV2().As<Value>().As<Array>();
    Local<Context> context;
    if (!preparation->GetCreationContext(isolate).ToLocal(&context)) return;
    Context::Scope context_scope(context);
    if (!ensureWasmAdapters(context)) return;
    Local<Value> intrinsics, constructor;
    if (!context->Global()->GetPrivate(context, wasmIntrinsicPrototypesKey(isolate)).ToLocal(&intrinsics) || !intrinsics->IsArray()) return;
    if (intrinsics.As<Array>()->Get(context, intrinsic_index).ToLocal(&constructor)) info.GetReturnValue().Set(constructor);
}

static void WasmModuleConstructorGet(Local<Name>, const PropertyCallbackInfo<Value>& info) {
    WasmPrototypeConstructorGet(info, 10);
}

static void WasmMemoryConstructorGet(Local<Name>, const PropertyCallbackInfo<Value>& info) {
    WasmPrototypeConstructorGet(info, 11);
}

/// Prepare once before script in every Window, worker, worklet and ShadowRealm.
/// V8 13.1.203 v8-object.h:367-387 and test-accessors.cc:860-894 guarantee
/// that SetLazyDataProperty reads once, then becomes a data property; assignment
/// bypasses its getter. GetOwnPropertyDescriptor resolves it as a data property
/// (js-objects.cc:1890-1958). Deletion and replacement can skip initialization.
/// No scripts, class factories, Tags or adapter functions are made here. The
/// private array owns only traced references: no Global, registry or teardown.
void v8_WebAssembly_InstallAddressDescriptors(Isolate* isolate, Global<Context>* context_handle) {
    HandleScope handle_scope(isolate);
    Local<Context> context = context_handle->Get(isolate);
    Context::Scope context_scope(context);
    NativeStepScope native_step(isolate);
    TryCatch try_catch(isolate);
    Local<Object> global = context->Global();
    Local<Value> values[kWasmPreparationSize];
    Local<Value> reflect, function, array, array_prototype, symbol;
    auto get = [&](Local<Value> object, const char* name, Local<Value>* value) {
        return object->IsObject() && object.As<Object>()->Get(context,
            String::NewFromUtf8(isolate, name, NewStringType::kInternalized).ToLocalChecked()).ToLocal(value);
    };
    // Capture function references now, not mutable helper objects to inspect
    // on first access.
    if (!get(global, "WebAssembly", &values[kWasmNamespace]) || !values[kWasmNamespace]->IsObject() ||
        !get(global, "Reflect", &reflect) ||
        !get(reflect, "construct", &values[kWasmConstruct]) ||
        !get(reflect, "get", &values[kWasmGet]) ||
        !get(reflect, "apply", &values[kWasmApply]) ||
        !get(global, "Proxy", &values[kWasmProxy]) ||
        !get(global, "TypeError", &values[kWasmTypeError]) ||
        !get(global, "Object", &values[kWasmObject]) ||
        !get(values[kWasmObject], "defineProperty", &values[kWasmDefine]) ||
        !get(reflect, "ownKeys", &values[kWasmOwnKeys]) ||
        !get(values[kWasmObject], "getOwnPropertyDescriptor", &values[kWasmDescriptor]) ||
        !get(values[kWasmObject], "setPrototypeOf", &values[kWasmSetPrototype]) ||
        !get(values[kWasmObject], "getPrototypeOf", &values[kWasmPrototype]) ||
        !get(global, "Function", &function) ||
        !get(function, "prototype", &values[kWasmFunctionPrototype]) ||
        !get(values[kWasmFunctionPrototype], "bind", &values[kWasmBind]) ||
        !get(global, "Symbol", &symbol) ||
        !get(symbol, "hasInstance", &values[kWasmHasInstanceKey]) ||
        !values[kWasmFunctionPrototype].As<Object>()->Get(context, values[kWasmHasInstanceKey]).ToLocal(&values[kWasmHasInstance]) ||
        !get(global, "Array", &array) || !get(array, "prototype", &array_prototype) ||
        !get(array_prototype, "slice", &values[kWasmSlice])) return;
    Local<Array> preparation = Array::New(isolate, values, kWasmPreparationSize);
    if (!preparation->SetIntegrityLevel(context, IntegrityLevel::kFrozen).FromMaybe(false) ||
        !global->SetPrivate(context, wasmPreparationKey(isolate), preparation).FromMaybe(false)) return;
    // A native Module or shared Memory can arrive by structured clone before
    // this realm reads WebAssembly (V8 13.1.203 value-serializer.cc:654-658).
    // These are the only cloneable native Wasm object types. Their constructor
    // data properties are another first-use trigger; no deserializer runs JS.
    const char* const constructor_names[] = {"Module", "Memory"};
    AccessorNameGetterCallback constructor_getters[] = {WasmModuleConstructorGet, WasmMemoryConstructorGet};
    for (uint32_t i = 0; i < 2; ++i) {
        Local<Value> constructor, prototype;
        if (!get(values[kWasmNamespace], constructor_names[i], &constructor) || !constructor->IsFunction() ||
            !get(constructor, "prototype", &prototype) || !prototype->IsObject() ||
            !prototype.As<Object>()->SetLazyDataProperty(context, String::NewFromUtf8Literal(isolate, "constructor"),
                constructor_getters[i], preparation, DontEnum).FromMaybe(false)) return;
    }
    (void)global->SetLazyDataProperty(context, String::NewFromUtf8Literal(isolate, "WebAssembly"),
        WasmNamespaceGet, preparation, DontEnum).FromMaybe(false);
}

} // extern "C"
// ---- end WebAssembly JS API adaptation ----
// ---- lane: csp2 ----
extern "C" {

/// CSP 2.4.1 step 2's running script position: the top frame of the
/// current stack trace (the topmost application JavaScript frame; Blink's
/// SourceLocation::Capture reads the same). Skip only the private Wasm
/// adapter's exact ScriptId, never a caller-controlled name or sourceURL.
/// `*url` gets its GetScriptNameOrSourceURL as malloc'd UTF-8 (null
/// when the frame names none), `*line` and `*column` its 1-based position
/// (Message::kNoLineNumberInfo / kNoColumnInfo, 0, when unknown). False
/// when the stack has no frame. `isolate` must be the current isolate.
/// The frame is the agent's topmost, whichever realm it is in: V8 hides the
/// frames of realms with another security token unless asked
/// (kExposeFramesAcrossSecurityOrigins), and every Window realm has its own
/// [cross_origin_objects].
bool v8_Isolate_RunningScriptLocation(Isolate* isolate, char** url, size_t* url_len, int* line, int* column) {
    *url = nullptr;
    *url_len = 0;
    *line = 0;
    *column = 0;
    HandleScope handle_scope(isolate);
    const auto options = static_cast<StackTrace::StackTraceOptions>(
        StackTrace::kDetailed | StackTrace::kScriptId | StackTrace::kExposeFramesAcrossSecurityOrigins);
    Local<StackTrace> trace = StackTrace::CurrentStackTrace(isolate, 1, options);
    if (trace.IsEmpty() || trace->GetFrameCount() < 1) return false;
    Local<StackFrame> frame = trace->GetFrame(isolate, 0);
    if (frame.IsEmpty()) return false;
    Local<Context> context = isolate->GetCurrentContext();
    Local<Value> intrinsics, script_id;
    if (!context.IsEmpty() &&
        context->Global()->GetPrivate(context, wasmIntrinsicPrototypesKey(isolate)).ToLocal(&intrinsics) && intrinsics->IsArray() &&
        intrinsics.As<Array>()->Get(context, 9).ToLocal(&script_id) && script_id->IsInt32() &&
        frame->GetScriptId() == script_id.As<Int32>()->Value()) {
        // Usually just the constructor frame precedes the caller. Capture
        // more only on this rare path, and stop at the first different ID.
        trace = StackTrace::CurrentStackTrace(isolate, 64, options);
        if (trace.IsEmpty()) return false;
        frame.Clear();
        for (int i = 0; i < trace->GetFrameCount(); ++i) {
            Local<StackFrame> candidate = trace->GetFrame(isolate, i);
            if (!candidate.IsEmpty() && candidate->GetScriptId() != script_id.As<Int32>()->Value()) {
                frame = candidate;
                break;
            }
        }
        if (frame.IsEmpty()) return false;
    }
    *line = frame->GetLineNumber();
    *column = frame->GetColumn();
    Local<String> name = frame->GetScriptNameOrSourceURL();
    if (!name.IsEmpty() && name->Length() > 0) {
        String::Utf8Value utf8(isolate, name);
        if (*utf8 && utf8.length() > 0) {
            char* copy = static_cast<char*>(malloc(static_cast<size_t>(utf8.length())));
            if (copy) {
                memcpy(copy, *utf8, static_cast<size_t>(utf8.length()));
                *url = copy;
                *url_len = static_cast<size_t>(utf8.length());
            }
        }
    }
    return true;
}

} // extern "C"
// ---- end lane: csp2 ----

// ---- lane: cxsupport ----

/// What the adapter's regexp operations keep per agent (per isolate): one
/// utility context, made on first use, and the regexps compiled in it, by
/// kind and pattern - engine.matchesPatternAttribute's anchored regexps and
/// engine.regExpCreateCheck / regExpBuiltinExecCaptures' RegExpCreate ones
/// (URLPattern's). Blink's design: V8PerIsolateData::EnsureScriptRegexpContext
/// keeps one ScriptRegexp context per isolate, HTMLInputElement keeps its
/// compiled ScriptRegexp, and URLPattern's components keep theirs. The
/// adapter's AgentRecord owns it; the agent's end deletes it
/// (v8_PatternMatcher_Delete), before the isolate is disposed. Used only on
/// the agent's own thread.
struct PatternMatcher {
    /// At most this many compiled regexps, most recently used first. A
    /// URLPattern compiles eight (one per component), many of them shared
    /// between patterns ("^(.*)$" for every wildcard component), so this
    /// holds a page's routing table of several patterns without recompiling
    /// on every test() (lane regexop; the pattern attribute alone had 16).
    static constexpr size_t kCapacity = 64;
    /// Which compile an entry is: the same pattern string is a different
    /// regexp as a pattern attribute (anchored as a group) and under "v" or
    /// "vi".
    enum Kind : uint8_t {
        kPatternAttribute = 0,
        kRegExpCreateV = 1,
        kRegExpCreateVI = 2,
    };
    struct Entry {
        Kind kind;
        std::u16string pattern;
        /// The compiled regexp; empty for a pattern that is invalid (cached
        /// too: a page re-validating one bad pattern does not recompile it
        /// every time).
        Global<RegExp> regexp;
    };
    Global<Context> context;
    std::vector<Entry> entries;
    /// How often the cache missed, for the tests that pin "once per agent"
    /// as a count rather than a time (v8_PatternMatcher_Counts): regexps
    /// compiled (one per entry made: a pattern attribute's standalone and
    /// anchored regexps are one compile) and utility contexts made.
    uint64_t compiles = 0;
    uint64_t contexts = 0;
};

/// The most backtracks one match of a regexp the adapter compiles for the
/// platform (not for script) may do; past it the match fails. Blink's
/// value: ScriptRegexp compiles every regexp - the pattern attribute's and
/// URLPattern's components' included - with RegExp::NewWithBacktrackLimit
/// and kBacktrackLimit = 1'000'000
/// (third_party/blink/renderer/platform/bindings/script_regexp.cc;
/// core/url_pattern/url_pattern_component.cc makes a ScriptRegexp per
/// component). A page writes the pattern, and without a limit a
/// catastrophic one - `(\d+)*$` against a long run of digits ending in a
/// letter, ~2^n backtracks - holds the agent's thread for as long as it
/// runs: the page freezes
/// (html/semantics/forms/constraints/infinite_backtracking.tentative.html ran
/// into the WPT runner's timeout).
static constexpr uint32_t kScriptRegExpBacktrackLimit = 1'000'000;
static constexpr uint32_t kPatternAttributeBacktrackLimit = kScriptRegExpBacktrackLimit;

/// Compile `source` as HTML 4.10.5.3.6's steps 3-6 do, in `context` (entered,
/// under `try_catch`): 1 with the anchored regexp in `*regexp`; -1 when
/// RegExpCreate(pattern, "v") threw (no compiled pattern regular expression);
/// 0 when the isolate is terminating (rethrown).
static int CompilePatternAttribute(Isolate* isolate, Local<Context> context, TryCatch& try_catch, Local<String> source, Local<RegExp>* regexp) {
    const RegExp::Flags v = RegExp::kUnicodeSets;
    // 3. Let regexpCompletion be RegExpCreate(pattern, "v").
    Local<RegExp> standalone;
    if (!RegExp::New(context, source, v).ToLocal(&standalone)) {
        if (try_catch.HasTerminated()) {
            try_catch.ReThrow();
            return 0;
        }
        // 4. If regexpCompletion is an abrupt completion, then return
        //    nothing: no compiled pattern regular expression.
        try_catch.Reset();
        return -1;
    }
    // 5. Let anchoredPattern be "^(?:", followed by pattern, followed by ")$".
    Local<String> anchored = String::Concat(isolate, String::Concat(isolate, String::NewFromUtf8Literal(isolate, "^(?:"), source), String::NewFromUtf8Literal(isolate, ")$"));
    // 6. Return ! RegExpCreate(anchoredPattern, "v"). The "!" is the spec's
    //    claim; a failure anyway (an engine limit) is treated as step 4's.
    //    Compiled with a backtrack limit, which the spec does not have: a
    //    match past it fails (v8-regexp.h, NewWithBacktrackLimit: "a match
    //    failure is immediately returned"), so the value does not match and
    //    the input suffers from a pattern mismatch. That is the browsers'
    //    answer: Blink's ScriptRegexp::Match answers -1 for the failed match
    //    and BaseTextInputType::PatternMismatchPerValue reads it as a
    //    mismatch; wpt.fyi (stable runs, 2026-10-10) has Chrome 155 and
    //    Safari 27 passing infinite_backtracking.tentative.html (the input is
    //    :invalid) and Firefox 157 timing out. Only the anchored regexp is
    //    ever matched; step 3's is compiled to validate the pattern.
    if (!RegExp::NewWithBacktrackLimit(context, anchored, v, kPatternAttributeBacktrackLimit).ToLocal(regexp)) {
        if (try_catch.HasTerminated()) {
            try_catch.ReThrow();
            return 0;
        }
        try_catch.Reset();
        return -1;
    }
    return 1;
}

/// ECMAScript RegExpCreate(source, "v" or "vi") in `context` (entered, under
/// `try_catch`): 1 with the regexp in `*regexp`; -1 when it threw (a
/// SyntaxError); 0 when the isolate is terminating (rethrown). RegExp::New
/// is RegExpCreate with the intrinsic %RegExp% of `context` - RegExpAlloc
/// then RegExpInitialize - never a global `RegExp` lookup. Compiled with
/// Blink's backtrack limit (kScriptRegExpBacktrackLimit), which the spec does
/// not have: a match past it fails, and URLPattern reads that as no match,
/// as Blink's URLPattern does (its ScriptRegexp::Match answers -1).
static int CompileRegExpCreate(Local<Context> context, TryCatch& try_catch, Local<String> source, bool ignore_case, Local<RegExp>* regexp) {
    int flags = RegExp::kUnicodeSets;
    if (ignore_case) flags |= RegExp::kIgnoreCase;
    if (!RegExp::NewWithBacktrackLimit(context, source, static_cast<RegExp::Flags>(flags), kScriptRegExpBacktrackLimit).ToLocal(regexp)) {
        if (try_catch.HasTerminated()) {
            try_catch.ReThrow();
            return 0;
        }
        try_catch.Reset();
        return -1;
    }
    return 1;
}

/// The context the regexps are made and matched in: `matcher`'s utility
/// context, made on first use - or, for an isolate the adapter's createAgent
/// did not make (no matcher), a context made for the call. Empty when no
/// context could be made (the heap is exhausted).
static Local<Context> RegExpContext(Isolate* isolate, PatternMatcher* matcher) {
    if (!matcher) return NewPlainGlobalContext(isolate);
    if (matcher->context.IsEmpty()) {
        // A plain global, never a bare Context::New: that crashed in a
        // snapshot agent (NewPlainGlobalContext; lesson architecture-a-
        // bare-context-new-in-a-snapshot-agent-deserializes-crane-s-
        // window-context).
        Local<Context> made = NewPlainGlobalContext(isolate);
        if (made.IsEmpty()) return made;
        matcher->context.Reset(isolate, made);
        matcher->contexts += 1;
    }
    return matcher->context.Get(isolate);
}

/// The regexp of `kind` for `pattern` (UTF-16 code units), in `context` (the
/// RegExpContext, entered, under `try_catch`): from `matcher`'s cache, else
/// compiled and cached. 1 with it in `*regexp`; -1 the pattern is invalid;
/// 0 the isolate is terminating (rethrown); -2 no string could be made.
static int CachedRegExp(Isolate* isolate, PatternMatcher* matcher, Local<Context> context, TryCatch& try_catch, PatternMatcher::Kind kind, const uint16_t* pattern, int pattern_len, Local<RegExp>* regexp) {
    if (matcher) {
        const char16_t* units = reinterpret_cast<const char16_t*>(pattern);
        auto& entries = matcher->entries;
        for (size_t i = 0; i < entries.size(); ++i) {
            if (entries[i].kind != kind) continue;
            if (entries[i].pattern.size() != static_cast<size_t>(pattern_len)) continue;
            if (pattern_len > 0 && entries[i].pattern.compare(0, std::u16string::npos, units, static_cast<size_t>(pattern_len)) != 0) continue;
            // Most recently used first.
            if (i > 0) std::rotate(entries.begin(), entries.begin() + static_cast<std::ptrdiff_t>(i), entries.begin() + static_cast<std::ptrdiff_t>(i) + 1);
            if (entries[0].regexp.IsEmpty()) return -1;
            *regexp = entries[0].regexp.Get(isolate);
            return 1;
        }
    }
    Local<String> source = String::Empty(isolate);
    if (pattern_len > 0 && !String::NewFromTwoByte(isolate, pattern, NewStringType::kNormal, pattern_len).ToLocal(&source)) return -2;
    const int compiled = kind == PatternMatcher::kPatternAttribute
        ? CompilePatternAttribute(isolate, context, try_catch, source, regexp)
        : CompileRegExpCreate(context, try_catch, source, kind == PatternMatcher::kRegExpCreateVI, regexp);
    if (compiled == 0) return 0;
    if (matcher) {
        matcher->compiles += 1;
        auto& entries = matcher->entries;
        if (entries.size() >= PatternMatcher::kCapacity) {
            entries.back().regexp.Reset();
            entries.pop_back();
        }
        PatternMatcher::Entry entry;
        entry.kind = kind;
        if (pattern_len > 0) entry.pattern.assign(reinterpret_cast<const char16_t*>(pattern), static_cast<size_t>(pattern_len));
        if (compiled == 1) entry.regexp.Reset(isolate, *regexp);
        entries.insert(entries.begin(), std::move(entry));
    }
    return compiled;
}

extern "C" {

PatternMatcher* v8_PatternMatcher_New() {
    return new PatternMatcher();
}

void v8_PatternMatcher_Counts(const PatternMatcher* matcher, uint64_t* compiles, uint64_t* contexts) {
    *compiles = matcher ? matcher->compiles : 0;
    *contexts = matcher ? matcher->contexts : 0;
}

void v8_PatternMatcher_Delete(PatternMatcher* matcher) {
    if (!matcher) return;
    for (auto& entry : matcher->entries) entry.regexp.Reset();
    matcher->context.Reset();
    delete matcher;
}

/// HTML 4.10.5.3.6 (engine.matchesPatternAttribute): the compiled pattern
/// regular expression of `pattern` and whether it "matches" `value`, both as
/// UTF-16 code units (a lone surrogate kept). 1: it matches; 0: it does not;
/// -1: RegExpCreate(pattern, "v") threw - the element has no compiled pattern
/// regular expression; -2: no context could be made (the heap is exhausted).
///
/// RegExp::Exec is not RegExpBuiltinExec. It is ECMAScript RegExpExec: V8's
/// api.cc runs RegExpUtils::RegExpExec, which does Get(R, "exec") and calls
/// what it finds through Execution::Call (regexp-utils.cc), so in the page's
/// realm a replaced RegExp.prototype.exec would run - script - and decide the
/// answer, and the built-in exec would write the page's legacy RegExp statics
/// (RegExp.$1, lastMatch, input). So the regexps are made, and matched, in a
/// context of the adapter's own, whose intrinsics no script has touched or
/// can reach: Get(R, "exec") finds that context's %RegExp.prototype.exec%,
/// the built-in, whose steps are RegExpBuiltinExec; RegExp::New is
/// RegExpCreate with the intrinsic %RegExp%, never the page's global
/// `RegExp`. That is the browsers' design: Blink's ScriptRegexp compiles and
/// matches in V8PerIsolateData's own ScriptRegexpContext, Gecko in a junk
/// scope, WebKit with Yarr and no JS object at all - and in none of them does
/// the page see the value in its statics.
///
/// `matcher` is the agent's (one utility context, compiled patterns cached:
/// only a pattern's first use compiles). Null - an isolate the adapter's
/// createAgent did not make - matches in a new context made for the call.
/// A cached regexp is reused safely: it has neither "g" nor "y", so exec
/// neither reads a lastIndex it wrote nor writes one.
///
/// A native step (NativeStepScope): the API calls here return to call depth
/// >= 1, so none of them is a kAuto microtask checkpoint.
int v8_MatchesPatternAttribute(Isolate* isolate, PatternMatcher* matcher, const uint16_t* pattern, int pattern_len, const uint16_t* value, int value_len) {
    NativeStepScope native_step(isolate);
    HandleScope handle_scope(isolate);
    Local<Context> context = RegExpContext(isolate, matcher);
    if (context.IsEmpty()) return -2;
    Context::Scope context_scope(context);
    TryCatch try_catch(isolate);

    Local<RegExp> regexp;
    const int found = CachedRegExp(isolate, matcher, context, try_catch, PatternMatcher::kPatternAttribute, pattern, pattern_len, &regexp);
    if (found != 1) return found;

    Local<String> subject = String::Empty(isolate);
    if (value_len > 0 && !String::NewFromTwoByte(isolate, value, NewStringType::kNormal, value_len).ToLocal(&subject)) return -2;
    // "matches": ! RegExpBuiltinExec(regexp, input) is not null. Exec answers
    // null as a Local<Object> holding Null (api.cc's own TODO), and so it
    // does past kPatternAttributeBacktrackLimit. A throw the "!" rules out -
    // an engine limit hit while matching - is no match, as in Blink
    // (ScriptRegexp::Match answers -1, which PatternMismatchPerValue reads as
    // not matched).
    Local<Object> result;
    if (!regexp->Exec(context, subject).ToLocal(&result)) {
        if (try_catch.HasTerminated()) try_catch.ReThrow();
        return 0;
    }
    return result.As<Value>()->IsNull() ? 0 : 1;
}

} // extern "C"
// ---- end lane: cxsupport ----
// ---- lane: xorigin2 (HTML 7.2.1 cross-origin objects) ----
// ============================================================================
// Cross-origin objects [cross_origin_objects]: the WindowProxy's and
// Location's cross-origin internal methods (HTML 7.2.3, 7.2.4), on V8's
// access checks - Blink's design (V8Window / V8Location's cross-origin
// interceptors, BindingSecurity::ShouldAllowAccessTo; design only).
//
// Every Window realm keeps its own security token, so V8 runs the access
// check below on every access to a WindowProxy from another realm, and - as
// a Location's template has one too - on every access to a Location. The
// check answers IsPlatformObjectSameOrigin (7.2.1.3.3): the same realm at
// once, any other through the adapter's Zig half (cross_origin.zig), which
// asks the host each time - never a kept answer, since a document's domain
// changes at any time. A failed check hands the access to the interceptors
// here, which run the cross-origin steps: CrossOriginGet / CrossOriginSet
// (7.2.1.3.5-6), [[GetOwnProperty]] through CrossOriginGetOwnPropertyHelper
// and CrossOriginPropertyFallback (7.2.1.3.2, 7.2.1.3.4), and
// CrossOriginOwnPropertyKeys (7.2.1.3.7). What V8 does not hand to an
// interceptor - [[Delete]], [[DefineOwnProperty]], [[SetPrototypeOf]],
// [[PreventExtensions]], and a call whose function does not accept any
// receiver (WebIDL's "perform a security check") - reaches the isolate's
// failed-access-check callback, which throws a SecurityError.
// [[GetPrototypeOf]] answers null and [[IsExtensible]] true by V8's own
// access-check paths.
// ============================================================================

extern "C" {

/// One entry of CrossOriginProperties (7.2.1.3.1): the member's name and
/// the binding's own steps for it - an operation's callback, or an
/// attribute's getter ([[NeedsGetter]]) and setter ([[NeedsSetter]]).
struct CrossOriginMember {
    const char* name;
    size_t name_len;
    FunctionCallback method;
    FunctionCallback getter;
    FunctionCallback setter;
    int length;
};

/// The adapter's Zig half (cross_origin.zig).
struct CrossOriginDispatch {
    /// IsPlatformObjectSameOrigin(O) for a current realm that is not O's:
    /// the current realm's Crane id (v8_Context_GetRawAddress) and the
    /// platform object (a Window or a Location).
    bool (*same_origin)(Isolate* isolate, void* current_realm, void* object);
    /// Throw a SecurityError DOMException in the current realm.
    void (*throw_security_error)(Isolate* isolate);
    /// The WindowProxy of W's document-tree child navigable `index`, as the
    /// Window's indexed getter answers it into `info`; kNo when there is none.
    Intercepted (*child_at)(uint32_t index, const PropertyCallbackInfo<Value>* info);
    /// The number of W's document-tree child navigables.
    uint32_t (*child_count)(void* window);
    /// The active WindowProxy of W's named object `name` when `name` is in
    /// W's document-tree child navigable target name property set, OWNED
    /// (disposed here); null otherwise.
    Global<Value>* (*child_named)(Isolate* isolate, void* window, const char* name, size_t name_len);
    const CrossOriginMember* window_members;
    size_t window_member_count;
    const CrossOriginMember* location_members;
    size_t location_member_count;
};

} // extern "C"

namespace {

// process-wide: the adapter's one dispatch table (cross_origin.zig), the same for every agent; written at process start (protocol_agents.initializeEngine, before any agent thread exists). Atomic, as g_shadow_realm_dispatch: a test starts the engine again on its own thread while another Browser reads it (lane tsanfix1).
std::atomic<const CrossOriginDispatch*> g_cross_origin{nullptr};

/// Which object an interceptor serves: its handler configuration's data.
constexpr int32_t kCrossOriginWindow = 0;
constexpr int32_t kCrossOriginLocation = 1;

/// The embedder data slot of a context that holds its cross-origin
/// functions (a Map); index 1 is the context's Crane id.
constexpr int kCrossOriginFunctionsIndex = 2;

int32_t CrossOriginKindOf(Local<Value> data) {
    if (!data.IsEmpty() && data->IsInt32()) return data.As<Int32>()->Value();
    return kCrossOriginWindow;
}

void ThrowCrossOriginSecurityError(Isolate* isolate) {
    const CrossOriginDispatch* dispatch = g_cross_origin.load(std::memory_order_acquire);
    if (dispatch && dispatch->throw_security_error) {
        dispatch->throw_security_error(isolate);
        if (isolate->HasPendingException()) return;
    }
    isolate->ThrowException(Exception::TypeError(String::NewFromUtf8Literal(isolate, "SecurityError: blocked a cross-origin access")));
}

/// The platform object behind a WindowProxy (internal field 0) or a Location
/// (its platform anchor), or null - a Window freed with its page, a severed
/// global or Location.
void* CrossOriginPlatformObject(Isolate* isolate, Local<Object> object) {
    return instanceOfObject(isolate, object);
}

/// IsPlatformObjectSameOrigin (7.2.1.3.3) as V8's access check: whether the
/// current realm, `accessing_context`, may use `accessed_object` as an
/// ordinary object.
bool CrossOriginAccessCheck(Local<Context> accessing_context, Local<Object> accessed_object, Local<Value> data) {
    (void)data;
    Isolate* isolate = Isolate::GetCurrent();  // V8 >= 14: no Context::GetIsolate (98282b9b8fa); a callback runs on its isolate
    // A platform object of the current realm itself: same origin-domain by
    // definition. V8 never asks this for a global proxy of the accessing
    // context, but asks it on every access to a Location.
    Local<Context> creation;
    if (accessed_object->GetCreationContext(isolate).ToLocal(&creation) && creation == accessing_context) return true;
    const CrossOriginDispatch* dispatch = g_cross_origin.load(std::memory_order_acquire);
    // No host to ask (an engine no host started): every realm reaches every
    // other, as before access checks existed.
    if (!dispatch || !dispatch->same_origin) return true;
    void* object = CrossOriginPlatformObject(isolate, accessed_object);
    // Nothing behind it to compare - its Window went with its page: the
    // ordinary methods, which find no Window, as before.
    if (!object) return true;
    return dispatch->same_origin(isolate, CraneContextIdOf(accessing_context), object);
}

/// The isolate's failed-access-check callback: what V8 does not hand to an
/// interceptor throws a SecurityError in the current realm. For [[Delete]],
/// [[DefineOwnProperty]] and a security-checked call that is the spec's
/// answer. [[SetPrototypeOf]] and [[PreventExtensions]] reach this callback
/// too: there the spec answers false (a TypeError from Object.* and false from
/// Reflect.*), and V8 gives the callback no way to tell the operations apart.
/// So Crane throws a SecurityError there, as Chrome does on the same V8. That
/// is a deviation from the spec, which Firefox and Safari follow.
void CrossOriginFailedAccessCheck(Local<Object> target, AccessType type, Local<Value> data) {
    (void)type;
    (void)data;
    ThrowCrossOriginSecurityError(Isolate::GetCurrent());
}

/// `kind`'s CrossOriginProperties entry named `name`, if any.
const CrossOriginMember* FindCrossOriginMember(Isolate* isolate, int32_t kind, Local<Name> name, size_t* index_out) {
    const CrossOriginDispatch* dispatch = g_cross_origin.load(std::memory_order_acquire);
    if (!dispatch || !name->IsString()) return nullptr;
    const CrossOriginMember* members = kind == kCrossOriginLocation ? dispatch->location_members : dispatch->window_members;
    size_t count = kind == kCrossOriginLocation ? dispatch->location_member_count : dispatch->window_member_count;
    Local<String> string = name.As<String>();
    if (string->Length() > 32) return nullptr;
    char buffer[64];
    const size_t written = string->WriteUtf8(isolate, buffer, sizeof(buffer) - 1);
    for (size_t i = 0; i < count; i++) {
        if (members[i].name_len == static_cast<size_t>(written) && std::memcmp(members[i].name, buffer, members[i].name_len) == 0) {
            if (index_out) *index_out = i;
            return &members[i];
        }
    }
    return nullptr;
}

/// CrossOriginPropertyFallback (7.2.1.3.2) step 1's keys: "then",
/// %Symbol.toStringTag%, %Symbol.hasInstance%, %Symbol.isConcatSpreadable%.
bool IsCrossOriginFallbackKey(Isolate* isolate, Local<Name> name) {
    if (name->IsString()) {
        return name.As<String>()->StringEquals(String::NewFromUtf8Literal(isolate, "then"));
    }
    if (!name->IsSymbol()) return false;
    return name->StrictEquals(Symbol::GetToStringTag(isolate)) ||
           name->StrictEquals(Symbol::GetHasInstance(isolate)) ||
           name->StrictEquals(Symbol::GetIsConcatSpreadable(isolate));
}

/// Which of a member's functions: its operation, its getter, its setter.
enum class CrossOriginFunctionKind : char { kMethod = 'm', kGetter = 'g', kSetter = 's' };

/// CrossOriginGetOwnPropertyHelper (7.2.1.3.4) steps 1 and 2.1.1-2.1.6 for
/// one function of a member: "an anonymous built-in function, created in
/// the current realm, that performs the same steps as" the member on O -
/// made once per (current realm, O's realm, member, function) and kept in
/// the current realm (its [[CrossOriginPropertyDescriptorMap]] entries,
/// keyed by realm pair: the functions, never an access decision). The map
/// lives with the current realm; its keys are numbers and strings, so it
/// keeps nothing of O's realm alive.
MaybeLocal<Function> CrossOriginFunction(
    Isolate* isolate,
    Local<Context> current,
    Local<Object> holder,
    int32_t kind,
    size_t member_index,
    const CrossOriginMember& member,
    CrossOriginFunctionKind which
) {
    FunctionCallback callback = which == CrossOriginFunctionKind::kMethod ? member.method
        : which == CrossOriginFunctionKind::kGetter ? member.getter : member.setter;
    if (!callback) return MaybeLocal<Function>();
    Local<Context> object_realm;
    if (!holder->GetCreationContext(isolate).ToLocal(&object_realm)) object_realm = current;
    char key_text[96];
    snprintf(key_text, sizeof(key_text), "%llu:%d:%zu:%c",
        static_cast<unsigned long long>(reinterpret_cast<uintptr_t>(CraneContextIdOf(object_realm))),
        static_cast<int>(kind), member_index, static_cast<char>(which));
    Local<String> key;
    if (!String::NewFromUtf8(isolate, key_text).ToLocal(&key)) return MaybeLocal<Function>();

    Local<Map> map;
    if (current->GetNumberOfEmbedderDataFields() > static_cast<uint32_t>(kCrossOriginFunctionsIndex)) {
        Local<Value> slot = current->GetEmbedderDataV2(kCrossOriginFunctionsIndex).As<Value>();
        if (!slot.IsEmpty() && slot->IsMap()) map = slot.As<Map>();
    }
    if (map.IsEmpty()) {
        map = Map::New(isolate);
        current->SetEmbedderDataV2(kCrossOriginFunctionsIndex, map);
    }
    Local<Value> found;
    if (map->Get(current, key).ToLocal(&found) && found->IsFunction()) return found.As<Function>();

    int length = which == CrossOriginFunctionKind::kMethod ? member.length
        : which == CrossOriginFunctionKind::kGetter ? 0 : 1;
    Local<Function> function;
    if (!Function::New(current, callback, Local<Value>(), length, ConstructorBehavior::kThrow).ToLocal(&function)) {
        return MaybeLocal<Function>();
    }
    // WebIDL's names: the operation's identifier, "get <name>", "set <name>".
    std::string name;
    if (which == CrossOriginFunctionKind::kGetter) name = "get ";
    if (which == CrossOriginFunctionKind::kSetter) name = "set ";
    name.append(member.name, member.name_len);
    Local<String> name_string;
    if (String::NewFromUtf8(isolate, name.data(), NewStringType::kNormal, static_cast<int>(name.size())).ToLocal(&name_string)) {
        function->SetName(name_string);
    }
    if (map->Set(current, key, function).IsEmpty()) return MaybeLocal<Function>();
    return function;
}

/// A property descriptor object for V8's descriptor interceptor: no
/// [[Prototype]], so ToPropertyDescriptor reads only its own fields, not a
/// `get` or `value` script put on Object.prototype.
Local<Object> NewCrossOriginDescriptor(Isolate* isolate) {
    return Object::New(isolate, Null(isolate), nullptr, nullptr, 0);
}

void SetDescriptorField(Isolate* isolate, Local<Context> context, Local<Object> desc, const char* key, Local<Value> value) {
    Local<String> key_string = String::NewFromUtf8(isolate, key, NewStringType::kInternalized).ToLocalChecked();
    (void)desc->CreateDataProperty(context, key_string, value);
}

Local<Object> DataDescriptor(Isolate* isolate, Local<Context> context, Local<Value> value, bool enumerable) {
    Local<Object> desc = NewCrossOriginDescriptor(isolate);
    SetDescriptorField(isolate, context, desc, "value", value);
    SetDescriptorField(isolate, context, desc, "writable", False(isolate));
    SetDescriptorField(isolate, context, desc, "enumerable", Boolean::New(isolate, enumerable));
    SetDescriptorField(isolate, context, desc, "configurable", True(isolate));
    return desc;
}

/// W's named child navigable `name` (7.2.3.5 step 6), as a WindowProxy.
bool CrossOriginNamedChild(Isolate* isolate, Local<Object> holder, Local<Name> name, Local<Value>* out) {
    const CrossOriginDispatch* dispatch = g_cross_origin.load(std::memory_order_acquire);
    if (!dispatch || !dispatch->child_named || !name->IsString()) return false;
    void* window = CrossOriginPlatformObject(isolate, holder);
    if (!window) return false;
    String::Utf8Value text(isolate, name);
    if (!*text) return false;
    Global<Value>* child = dispatch->child_named(isolate, window, *text, static_cast<size_t>(text.length()));
    if (!child) return false;
    *out = child->Get(isolate);
    v8_Global_Dispose(child);
    return true;
}

// --- named interceptors ---

/// [[Get]] (7.2.3.7 step 4, 7.2.4.7 step 2): CrossOriginGet. A getter is
/// called on the HOLDER, not the Receiver (CrossOriginGet step 5): V8 >= 14
/// gives an interceptor no receiver - the KNOWN DEVIATION recorded at
/// CrossOriginNamedSetter, with the V8 lines that were checked.
Intercepted CrossOriginNamedGetter(Local<Name> name, const PropertyCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    int32_t kind = CrossOriginKindOf(info.DataV2().As<Value>());
    Local<Context> current = isolate->GetCurrentContext();
    Local<Object> holder = info.Holder();
    size_t index = 0;
    if (const CrossOriginMember* member = FindCrossOriginMember(isolate, kind, name, &index)) {
        // CrossOriginGet step 3: a data descriptor's [[Value]] - an
        // operation's function.
        if (member->method) {
            Local<Function> function;
            if (CrossOriginFunction(isolate, current, holder, kind, index, *member, CrossOriginFunctionKind::kMethod).ToLocal(&function)) {
                info.GetReturnValue().Set(function);
            }
            return Intercepted::kYes;
        }
        // Step 6: no getter (Location's href) - a SecurityError.
        if (!member->getter) {
            ThrowCrossOriginSecurityError(isolate);
            return Intercepted::kYes;
        }
        // Step 7: Call(getter, Receiver).
        Local<Function> getter;
        if (!CrossOriginFunction(isolate, current, holder, kind, index, *member, CrossOriginFunctionKind::kGetter).ToLocal(&getter)) {
            return Intercepted::kYes;
        }
        Local<Value> result;
        if (getter->Call(current, info.Holder(), 0, nullptr).ToLocal(&result)) info.GetReturnValue().Set(result);
        return Intercepted::kYes;
    }
    // 7.2.3.5 step 6: a named child navigable.
    if (kind == kCrossOriginWindow) {
        Local<Value> child;
        if (CrossOriginNamedChild(isolate, holder, name, &child)) {
            info.GetReturnValue().Set(child);
            return Intercepted::kYes;
        }
    }
    // CrossOriginPropertyFallback: undefined for the four keys, else a
    // SecurityError.
    if (IsCrossOriginFallbackKey(isolate, name)) {
        info.GetReturnValue().SetUndefined();
        return Intercepted::kYes;
    }
    ThrowCrossOriginSecurityError(isolate);
    return Intercepted::kYes;
}

/// [[Set]] (7.2.3.8 step 4, 7.2.4.8 step 2): CrossOriginSet - the setter of
/// a member that has one; a SecurityError for anything else (expandos
/// included).
///
/// KNOWN DEVIATION (the user's ruling, 2026-11-11; lane v8up b4): CrossOriginSet
/// step 3.1 is Call(desc.[[Set]], Receiver, V), and here the setter is called
/// on the HOLDER. V8 removed v8::PropertyCallbackInfo<T>::This() in 14
/// (24eb3c4ba35, "Remove deprecated v8::PropertyCallbackInfo<T>::This()"); on
/// V8 13.1 this function passed info.This(). So a write whose receiver only
/// inherits from a cross-origin Window or Location -
/// `Object.create(crossOriginWindow).location = url`,
/// `Object.create(crossOriginWindow.location).href = url` - performs the
/// navigation the direct write is allowed to perform, where the spec has the
/// setter's brand check throw a TypeError of the lexical realm. Nothing is
/// read and no capability is added. WPT
/// html/browsers/origin/cross-origin-objects/window-location-and-location-href-cross-realm-set.html,
/// the two "... setter throws TypeError in lexical realm on invalid |this|
/// value" subtests: Chrome 157 fails both (9/11; Blink reads info.Holder()
/// too), Firefox 160 and Safari 27.2 pass (11/11; wpt.fyi stable runs of
/// 2026-11-11). Pinned by tests/wpt/crane/v8up-cross-origin-setter-inherited-receiver-deviation.html.
///
/// Checked 2026-11-11 against V8 15.7.112.43 - NO public path gives the
/// receiver; delete this deviation the day one does:
/// - PropertyCallbackInfo's argument block has no receiver slot
///   (v8-function-callback.h 310-332: kPropertyKeyIndex, the frame slots,
///   kIsolateIndex, kReturnValueIndex, kCallbackInfoIndex, kHolderIndex,
///   kShouldThrowOnErrorIndex, kValueIndex), and V8 fills it from the holder
///   alone (js-objects.cc 1404, SetPropertyWithInterceptorInternal:
///   `PropertyCallbackArguments args(isolate, it->GetHolderForApi(), should_throw)`;
///   api-arguments.h 60-62 has no constructor that takes a receiver) - the
///   definer, descriptor and deleter callbacks get the same info;
/// - v8::AccessCheckCallback gets (accessing_context, accessed_object, data)
///   (v8-template.h 439-441), and accessed_object is the checked HOLDER
///   (isolate.cc 2461-2502, Isolate::MayAccess; js-objects.cc 2833,
///   `checked = it->GetHolder<JSObject>()`);
/// - PropertyHandlerFlags (v8-template.h 708-746: kNone, kNonMasking,
///   kOnlyInterceptStrings, kHasNoSideEffect, kHasDontDeleteProperty,
///   kInternalNewCallbacksSignatures) change which lookups reach the
///   interceptor, never what it is told;
/// - no Isolate-level state names the lookup's receiver while the callback runs.
Intercepted CrossOriginNamedSetter(Local<Name> name, Local<Value> value, const PropertyCallbackInfo<Boolean>& info) {
    Isolate* isolate = info.GetIsolate();
    int32_t kind = CrossOriginKindOf(info.DataV2().As<Value>());
    Local<Context> current = isolate->GetCurrentContext();
    size_t index = 0;
    const CrossOriginMember* member = FindCrossOriginMember(isolate, kind, name, &index);
    if (!member || !member->setter) {
        ThrowCrossOriginSecurityError(isolate);
        return Intercepted::kYes;
    }
    Local<Function> setter;
    if (!CrossOriginFunction(isolate, current, info.Holder(), kind, index, *member, CrossOriginFunctionKind::kSetter).ToLocal(&setter)) {
        return Intercepted::kYes;
    }
    Local<Value> argv[1] = {value};
    (void)setter->Call(current, info.Holder(), 1, argv);
    return Intercepted::kYes;
}

/// [[GetOwnProperty]] as attributes, for [[HasProperty]] and
/// hasOwnProperty: every cross-origin property is non-enumerable, a data
/// one read-only; anything else a SecurityError.
Intercepted CrossOriginNamedQuery(Local<Name> name, const PropertyCallbackInfo<Integer>& info) {
    Isolate* isolate = info.GetIsolate();
    int32_t kind = CrossOriginKindOf(info.DataV2().As<Value>());
    if (const CrossOriginMember* member = FindCrossOriginMember(isolate, kind, name, nullptr)) {
        int attributes = PropertyAttribute::DontEnum;
        if (member->method) attributes |= PropertyAttribute::ReadOnly;
        info.GetReturnValue().Set(attributes);
        return Intercepted::kYes;
    }
    Local<Value> child;
    if ((kind == kCrossOriginWindow && CrossOriginNamedChild(isolate, info.Holder(), name, &child)) || IsCrossOriginFallbackKey(isolate, name)) {
        info.GetReturnValue().Set(static_cast<int>(PropertyAttribute::DontEnum | PropertyAttribute::ReadOnly));
        return Intercepted::kYes;
    }
    ThrowCrossOriginSecurityError(isolate);
    return Intercepted::kYes;
}

/// [[GetOwnProperty]] (7.2.3.5 steps 4-7, 7.2.4.5 steps 2-4).
Intercepted CrossOriginNamedDescriptor(Local<Name> name, const PropertyCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    int32_t kind = CrossOriginKindOf(info.DataV2().As<Value>());
    Local<Context> current = isolate->GetCurrentContext();
    Local<Object> holder = info.Holder();
    size_t index = 0;
    if (const CrossOriginMember* member = FindCrossOriginMember(isolate, kind, name, &index)) {
        if (member->method) {
            // Step 2.1.4: { [[Value]]: the function, [[Enumerable]]: false,
            // [[Writable]]: false, [[Configurable]]: true }.
            Local<Function> function;
            if (!CrossOriginFunction(isolate, current, holder, kind, index, *member, CrossOriginFunctionKind::kMethod).ToLocal(&function)) {
                return Intercepted::kYes;
            }
            info.GetReturnValue().Set(DataDescriptor(isolate, current, function, false));
            return Intercepted::kYes;
        }
        // Step 2.1.5: { [[Get]], [[Set]], [[Enumerable]]: false,
        // [[Configurable]]: true }, each function or undefined.
        Local<Value> getter = Undefined(isolate);
        Local<Value> setter = Undefined(isolate);
        Local<Function> function;
        if (member->getter) {
            if (!CrossOriginFunction(isolate, current, holder, kind, index, *member, CrossOriginFunctionKind::kGetter).ToLocal(&function)) return Intercepted::kYes;
            getter = function;
        }
        if (member->setter) {
            if (!CrossOriginFunction(isolate, current, holder, kind, index, *member, CrossOriginFunctionKind::kSetter).ToLocal(&function)) return Intercepted::kYes;
            setter = function;
        }
        Local<Object> desc = NewCrossOriginDescriptor(isolate);
        SetDescriptorField(isolate, current, desc, "get", getter);
        SetDescriptorField(isolate, current, desc, "set", setter);
        SetDescriptorField(isolate, current, desc, "enumerable", False(isolate));
        SetDescriptorField(isolate, current, desc, "configurable", True(isolate));
        info.GetReturnValue().Set(desc);
        return Intercepted::kYes;
    }
    if (kind == kCrossOriginWindow) {
        Local<Value> child;
        if (CrossOriginNamedChild(isolate, holder, name, &child)) {
            info.GetReturnValue().Set(DataDescriptor(isolate, current, child, false));
            return Intercepted::kYes;
        }
    }
    if (IsCrossOriginFallbackKey(isolate, name)) {
        info.GetReturnValue().Set(DataDescriptor(isolate, current, Undefined(isolate), false));
        return Intercepted::kYes;
    }
    ThrowCrossOriginSecurityError(isolate);
    return Intercepted::kYes;
}

/// [[Delete]] (7.2.3.9 step 3, 7.2.4.9 step 2): a SecurityError.
Intercepted CrossOriginNamedDeleter(Local<Name> name, const PropertyCallbackInfo<Boolean>& info) {
    (void)name;
    ThrowCrossOriginSecurityError(info.GetIsolate());
    return Intercepted::kYes;
}

/// [[DefineOwnProperty]] (7.2.3.6 step 3, 7.2.4.6 step 2): a SecurityError.
Intercepted CrossOriginNamedDefiner(Local<Name> name, const PropertyDescriptor& desc, const PropertyCallbackInfo<Boolean>& info) {
    (void)name;
    (void)desc;
    ThrowCrossOriginSecurityError(info.GetIsolate());
    return Intercepted::kYes;
}

/// CrossOriginOwnPropertyKeys (7.2.1.3.7): CrossOriginProperties' names,
/// then "then" and the three symbols. Named child navigables are not listed
/// ([[HideFromKeys]]); the indices are the indexed enumerator's.
void CrossOriginNamedEnumerator(const PropertyCallbackInfo<Array>& info) {
    Isolate* isolate = info.GetIsolate();
    const CrossOriginDispatch* dispatch = g_cross_origin.load(std::memory_order_acquire);
    int32_t kind = CrossOriginKindOf(info.DataV2().As<Value>());
    std::vector<Local<Value>> keys;
    if (dispatch) {
        const CrossOriginMember* members = kind == kCrossOriginLocation ? dispatch->location_members : dispatch->window_members;
        size_t count = kind == kCrossOriginLocation ? dispatch->location_member_count : dispatch->window_member_count;
        for (size_t i = 0; i < count; i++) {
            Local<String> key;
            if (String::NewFromUtf8(isolate, members[i].name, NewStringType::kInternalized, static_cast<int>(members[i].name_len)).ToLocal(&key)) keys.push_back(key);
        }
    }
    keys.push_back(String::NewFromUtf8Literal(isolate, "then", NewStringType::kInternalized));
    keys.push_back(Symbol::GetToStringTag(isolate));
    keys.push_back(Symbol::GetHasInstance(isolate));
    keys.push_back(Symbol::GetIsConcatSpreadable(isolate));
    info.GetReturnValue().Set(Array::New(isolate, keys.data(), keys.size()));
}

// --- indexed interceptors ---

/// [[Get]] of an array index (7.2.3.5 step 2, through CrossOriginGet): a
/// child navigable's WindowProxy, else a SecurityError. A Location has no
/// cross-origin indexed property.
Intercepted CrossOriginIndexedGetter(uint32_t index, const PropertyCallbackInfo<Value>& info) {
    const CrossOriginDispatch* dispatch = g_cross_origin.load(std::memory_order_acquire);
    if (CrossOriginKindOf(info.DataV2().As<Value>()) == kCrossOriginWindow && dispatch && dispatch->child_at) {
        if (dispatch->child_at(index, &info) == Intercepted::kYes) return Intercepted::kYes;
        if (info.GetIsolate()->HasPendingException()) return Intercepted::kYes;
    }
    ThrowCrossOriginSecurityError(info.GetIsolate());
    return Intercepted::kYes;
}

/// [[GetOwnProperty]] of an array index (7.2.3.5 step 2): { [[Value]]: the
/// WindowProxy, [[Writable]]: false, [[Enumerable]]: true,
/// [[Configurable]]: true }, else a SecurityError.
Intercepted CrossOriginIndexedDescriptor(uint32_t index, const PropertyCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    const CrossOriginDispatch* dispatch = g_cross_origin.load(std::memory_order_acquire);
    if (CrossOriginKindOf(info.DataV2().As<Value>()) == kCrossOriginWindow && dispatch && dispatch->child_at) {
        if (dispatch->child_at(index, &info) == Intercepted::kYes) {
            Local<Value> child = info.GetReturnValue().Get();
            info.GetReturnValue().Set(DataDescriptor(isolate, isolate->GetCurrentContext(), child, true));
            return Intercepted::kYes;
        }
        if (isolate->HasPendingException()) return Intercepted::kYes;
    }
    ThrowCrossOriginSecurityError(isolate);
    return Intercepted::kYes;
}

Intercepted CrossOriginIndexedQuery(uint32_t index, const PropertyCallbackInfo<Integer>& info) {
    Isolate* isolate = info.GetIsolate();
    const CrossOriginDispatch* dispatch = g_cross_origin.load(std::memory_order_acquire);
    if (CrossOriginKindOf(info.DataV2().As<Value>()) == kCrossOriginWindow && dispatch && dispatch->child_count) {
        void* window = CrossOriginPlatformObject(isolate, info.Holder());
        if (window && index < dispatch->child_count(window)) {
            info.GetReturnValue().Set(static_cast<int>(PropertyAttribute::ReadOnly));
            return Intercepted::kYes;
        }
    }
    ThrowCrossOriginSecurityError(isolate);
    return Intercepted::kYes;
}

/// [[Set]] of an array index: CrossOriginSet finds no setter - a
/// SecurityError, as are [[Delete]] and [[DefineOwnProperty]].
Intercepted CrossOriginIndexedSetter(uint32_t index, Local<Value> value, const PropertyCallbackInfo<Boolean>& info) {
    (void)index;
    (void)value;
    ThrowCrossOriginSecurityError(info.GetIsolate());
    return Intercepted::kYes;
}

Intercepted CrossOriginIndexedDeleter(uint32_t index, const PropertyCallbackInfo<Boolean>& info) {
    (void)index;
    ThrowCrossOriginSecurityError(info.GetIsolate());
    return Intercepted::kYes;
}

Intercepted CrossOriginIndexedDefiner(uint32_t index, const PropertyDescriptor& desc, const PropertyCallbackInfo<Boolean>& info) {
    (void)index;
    (void)desc;
    ThrowCrossOriginSecurityError(info.GetIsolate());
    return Intercepted::kYes;
}

/// [[OwnPropertyKeys]] step 3 (7.2.3.10): the range 0 to the number of W's
/// document-tree child navigables. A Location has none.
void CrossOriginIndexedEnumerator(const PropertyCallbackInfo<Array>& info) {
    Isolate* isolate = info.GetIsolate();
    const CrossOriginDispatch* dispatch = g_cross_origin.load(std::memory_order_acquire);
    uint32_t count = 0;
    if (CrossOriginKindOf(info.DataV2().As<Value>()) == kCrossOriginWindow && dispatch && dispatch->child_count) {
        if (void* window = CrossOriginPlatformObject(isolate, info.Holder())) count = dispatch->child_count(window);
    }
    Local<Context> context = isolate->GetCurrentContext();
    Local<Array> keys = Array::New(isolate, static_cast<int>(count));
    for (uint32_t i = 0; i < count; i++) {
        (void)keys->Set(context, i, Integer::NewFromUnsigned(isolate, i));
    }
    info.GetReturnValue().Set(keys);
}

} // namespace

extern "C" {

/// The adapter's Zig half, once, at process start (engine.initializeEngine),
/// before any agent's thread runs.
void v8_SetCrossOriginDispatch(const CrossOriginDispatch* dispatch) {
    g_cross_origin.store(dispatch, std::memory_order_release);
}

/// Give `tpl`'s instances the cross-origin access check and interceptors:
/// kind 0 a Window global template (the WindowProxy), 1 Location's instance
/// template. Before the template is instantiated - and in the snapshot
/// generator too, since a restored context's templates come from the
/// snapshot (the callbacks are external references:
/// v8_CrossOrigin_ExternalReferences).
void v8_ObjectTemplate_SetCrossOriginAccessCheck(Global<ObjectTemplate>* tpl, int kind) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    Local<Value> data = Integer::New(isolate, kind);
    local_tpl->SetAccessCheckCallbackAndHandler(
        CrossOriginAccessCheck,
        NamedPropertyHandlerConfiguration(
            CrossOriginNamedGetter,
            CrossOriginNamedSetter,
            CrossOriginNamedQuery,
            CrossOriginNamedDeleter,
            CrossOriginNamedEnumerator,
            CrossOriginNamedDefiner,
            CrossOriginNamedDescriptor,
            data),
        IndexedPropertyHandlerConfiguration(
            CrossOriginIndexedGetter,
            CrossOriginIndexedSetter,
            CrossOriginIndexedQuery,
            CrossOriginIndexedDeleter,
            CrossOriginIndexedEnumerator,
            CrossOriginIndexedDefiner,
            CrossOriginIndexedDescriptor,
            data));
}

/// WebIDL's receiver check after the binding identifies Window/Location.
/// A Location Proxy does not itself carry the target's V8 access check, so
/// SetAcceptAnyReceiver(false) alone cannot protect borrowed member calls.
/// Only Local handles; the current context is the member function's realm.
bool v8_FunctionCallbackInfo_ReceiverIsAccessible(const FunctionCallbackInfo<Value>* info) {
    Isolate* isolate = info->GetIsolate();
    HandleScope handles(isolate);
    Local<Object> receiver = info->This();
    if (receiver->IsProxy()) {
        Local<Value> target = receiver.As<Proxy>()->GetTarget();
        if (!target->IsObject()) return true; // The binding rejects the brand.
        receiver = target.As<Object>();
    }
    return CrossOriginAccessCheck(isolate->GetCurrentContext(), receiver, {});
}

/// The isolate's failed-access-check callback: a SecurityError
/// (CrossOriginFailedAccessCheck).
void v8_Isolate_SetCrossOriginFailedAccessCheck(Isolate* isolate) {
    isolate->SetFailedAccessCheckCallbackFunction(CrossOriginFailedAccessCheck);
}

// HTML 7.2.4: Location's exotic methods on the single object exposed from
// creation. Traps are native functions in the CALLER'S current context, so a
// Reflect method borrowed from another realm keeps that builtin's realm.
static Local<Object> locationTarget(const FunctionCallbackInfo<Value>& info) {
    return info[0].As<Object>();
}
static bool locationSameOrigin(Isolate* isolate, Local<Object> target) {
    return CrossOriginAccessCheck(isolate->GetCurrentContext(), target, {});
}
static void LocationGetPrototype(const FunctionCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    Local<Object> target = locationTarget(info);
    info.GetReturnValue().Set(locationSameOrigin(isolate, target) ? target->GetPrototype() : Null(isolate).As<Value>());
}
static void LocationSetPrototype(const FunctionCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    Local<Object> target = locationTarget(info);
    // SetImmutablePrototype, including the cross-origin null prototype.
    Local<Value> current = locationSameOrigin(isolate, target) ? target->GetPrototype() : Null(isolate).As<Value>();
    info.GetReturnValue().Set(current->StrictEquals(info[1]));
}
static void LocationPreventExtensions(const FunctionCallbackInfo<Value>& info) {
    info.GetReturnValue().Set(false);
}
static void LocationOwnKeys(const FunctionCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    Local<Array> keys;
    if (locationTarget(info)->GetOwnPropertyNames(isolate->GetCurrentContext(), ALL_PROPERTIES,
                                                  KeyConversionMode::kConvertToString).ToLocal(&keys))
        info.GetReturnValue().Set(keys);
}
static void LocationOwnDescriptor(const FunctionCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    Local<Value> descriptor;
    // C/F/S all report configurable:false for same-origin href/hash/toString
    // (WPT location-stringifier and proxy-getOwnPropertyDescriptor, aligned
    // 5d23b743bb, 2026-10-21). Preserve that long-standing browser behavior:
    // https://github.com/whatwg/html/issues/4157. Cross-origin descriptors are
    // separately produced by CrossOriginNamedDescriptor, configurable:true.
    if (locationTarget(info)->GetOwnPropertyDescriptor(isolate->GetCurrentContext(), info[1].As<Name>()).ToLocal(&descriptor))
        info.GetReturnValue().Set(descriptor);
}
static void LocationDefineProperty(const FunctionCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    Local<Context> context = isolate->GetCurrentContext();
    Local<Object> target = locationTarget(info);
    if (!locationSameOrigin(isolate, target)) {
        ThrowCrossOriginSecurityError(isolate);
        return;
    }
    // V8 supplies FromPropertyDescriptor's fresh ordinary object. Read only
    // its own fields, so a polluted Object.prototype cannot add attributes.
    Local<Object> descriptor = info[2].As<Object>();
    auto field = [&](const char* name, Local<Value>* value) -> bool {
        Local<String> key = String::NewFromUtf8(isolate, name).ToLocalChecked();
        Maybe<bool> has = descriptor->HasOwnProperty(context, key);
        if (has.IsNothing()) return false;
        if (!has.FromJust()) return true;
        return descriptor->Get(context, key).ToLocal(value);
    };
    Local<Value> value, writable, get, set, enumerable, configurable;
    if (!field("value", &value) || !field("writable", &writable) ||
        !field("get", &get) || !field("set", &set) ||
        !field("enumerable", &enumerable) || !field("configurable", &configurable)) return;
    std::unique_ptr<PropertyDescriptor> native;
    if (!get.IsEmpty() || !set.IsEmpty()) native = std::make_unique<PropertyDescriptor>(get, set);
    else if (!writable.IsEmpty()) native = std::make_unique<PropertyDescriptor>(value, writable->BooleanValue(isolate));
    else if (!value.IsEmpty()) native = std::make_unique<PropertyDescriptor>(value);
    else native = std::make_unique<PropertyDescriptor>();
    if (!enumerable.IsEmpty()) native->set_enumerable(enumerable->BooleanValue(isolate));
    if (!configurable.IsEmpty()) native->set_configurable(configurable->BooleanValue(isolate));
    Maybe<bool> result = target->DefineProperty(context, info[1].As<Name>(), *native);
    if (result.IsJust()) info.GetReturnValue().Set(result.FromJust());
}
static Intercepted LocationTrapLookup(Local<Name> name, const PropertyCallbackInfo<Value>& info) {
    if (!name->IsString()) return Intercepted::kNo;
    Isolate* isolate = info.GetIsolate();
    Local<String> key = name.As<String>();
    FunctionCallback callback = nullptr;
    // Normal reads/writes ask for "get"/"set": no function allocation on
    // that path. The target keeps its existing access-check semantics.
    switch (key->Length()) {
        case 7:
            if (key->StringEquals(String::NewFromUtf8Literal(isolate, "ownKeys"))) callback = LocationOwnKeys;
            break;
        case 14:
            if (key->StringEquals(String::NewFromUtf8Literal(isolate, "getPrototypeOf"))) callback = LocationGetPrototype;
            else if (key->StringEquals(String::NewFromUtf8Literal(isolate, "setPrototypeOf"))) callback = LocationSetPrototype;
            else if (key->StringEquals(String::NewFromUtf8Literal(isolate, "defineProperty"))) callback = LocationDefineProperty;
            break;
        case 17:
            if (key->StringEquals(String::NewFromUtf8Literal(isolate, "preventExtensions"))) callback = LocationPreventExtensions;
            break;
        case 24:
            if (key->StringEquals(String::NewFromUtf8Literal(isolate, "getOwnPropertyDescriptor"))) callback = LocationOwnDescriptor;
            break;
    }
    if (!callback) return Intercepted::kNo;
    Local<Function> function;
    if (Function::New(isolate->GetCurrentContext(), callback, {}, 0, ConstructorBehavior::kThrow).ToLocal(&function))
        info.GetReturnValue().Set(function);
    return Intercepted::kYes;
}

Global<Object>* v8_CreateLocationObject(Global<Context>* realm, Global<Object>* target) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handles(isolate);
    NativeStepScope native_step(isolate);
    Local<Context> context = realm->Get(isolate);
    Local<ObjectTemplate> handler_template = ObjectTemplate::New(isolate);
    handler_template->SetHandler(NamedPropertyHandlerConfiguration(LocationTrapLookup));
    Local<Object> handler;
    if (!handler_template->NewInstance(context).ToLocal(&handler)) return nullptr;
    if (!handler->SetPrototype(context, Null(isolate)).FromMaybe(false)) return nullptr;
    Local<Proxy> result;
    if (!Proxy::New(context, target->Get(isolate), handler).ToLocal(&result)) return nullptr;
    return trackHandle(new Global<Object>(isolate, result));
}

/// HTML 7.2.4 "Location object setup" steps 3-4 on Location's instance
/// template: `valueOf` is %Object.prototype.valueOf% of the instance's realm
/// and %Symbol.toPrimitive% is undefined, each { [[Writable]]: false,
/// [[Enumerable]]: false, [[Configurable]]: false } - own properties, as its
/// [LegacyUnforgeable] members are.
void v8_ObjectTemplate_SetLocationValueOfAndToPrimitive(Global<ObjectTemplate>* tpl) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    PropertyAttribute attributes = static_cast<PropertyAttribute>(PropertyAttribute::ReadOnly | PropertyAttribute::DontEnum | PropertyAttribute::DontDelete);
    local_tpl->SetIntrinsicDataProperty(String::NewFromUtf8Literal(isolate, "valueOf", NewStringType::kInternalized), Intrinsic::kObjProto_valueOf, attributes);
    local_tpl->Set(Symbol::GetToPrimitive(isolate), Undefined(isolate), attributes);
}

/// Whether `tpl`'s functions accept any receiver: false makes V8 run the
/// receiver's access check before the callback (WebIDL "perform a security
/// check", HTML 7.2.1.1).
void v8_FunctionTemplate_SetAcceptAnyReceiver(Global<FunctionTemplate>* tpl, bool value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    tpl->Get(isolate)->SetAcceptAnyReceiver(value);
}

/// The callbacks v8_ObjectTemplate_SetCrossOriginAccessCheck puts in a
/// template, for the snapshot's external references, in a fixed order.
/// Writes at most `capacity` and answers how many there are.
size_t v8_CrossOrigin_ExternalReferences(uintptr_t* out, size_t capacity) {
    const uintptr_t refs[] = {
        reinterpret_cast<uintptr_t>(&CrossOriginAccessCheck),
        reinterpret_cast<uintptr_t>(&LocationGetPrototype),
        reinterpret_cast<uintptr_t>(&LocationSetPrototype),
        reinterpret_cast<uintptr_t>(&LocationPreventExtensions),
        reinterpret_cast<uintptr_t>(&LocationOwnKeys),
        reinterpret_cast<uintptr_t>(&LocationOwnDescriptor),
        reinterpret_cast<uintptr_t>(&LocationDefineProperty),
        reinterpret_cast<uintptr_t>(&LocationTrapLookup),
        reinterpret_cast<uintptr_t>(&CrossOriginNamedGetter),
        reinterpret_cast<uintptr_t>(&CrossOriginNamedSetter),
        reinterpret_cast<uintptr_t>(&CrossOriginNamedQuery),
        reinterpret_cast<uintptr_t>(&CrossOriginNamedDeleter),
        reinterpret_cast<uintptr_t>(&CrossOriginNamedEnumerator),
        reinterpret_cast<uintptr_t>(&CrossOriginNamedDefiner),
        reinterpret_cast<uintptr_t>(&CrossOriginNamedDescriptor),
        reinterpret_cast<uintptr_t>(&CrossOriginIndexedGetter),
        reinterpret_cast<uintptr_t>(&CrossOriginIndexedSetter),
        reinterpret_cast<uintptr_t>(&CrossOriginIndexedQuery),
        reinterpret_cast<uintptr_t>(&CrossOriginIndexedDeleter),
        reinterpret_cast<uintptr_t>(&CrossOriginIndexedEnumerator),
        reinterpret_cast<uintptr_t>(&CrossOriginIndexedDefiner),
        reinterpret_cast<uintptr_t>(&CrossOriginIndexedDescriptor),
    };
    size_t count = sizeof(refs) / sizeof(refs[0]);
    for (size_t i = 0; i < count && i < capacity; i++) out[i] = refs[i];
    return count;
}

} // extern "C"
// ---- end lane: xorigin2 ----

// ---- lane: regexop ----

extern "C" {

/// engine.regExpCreateCheck: ECMAScript RegExpCreate(`pattern`, "v", or "vi"
/// when `ignore_case`), `pattern` as UTF-16 code units (a lone surrogate
/// kept), in the agent's utility context (v8_MatchesPatternAttribute says why
/// not in the page's realm), the compiled regexp cached for
/// v8_RegExpBuiltinExecCaptures. 1: it compiled; -1: it threw (a
/// SyntaxError); -2: no context or string could be made (the heap is
/// exhausted); -3: the isolate is terminating (rethrown). A native step: no
/// kAuto microtask checkpoint.
int v8_RegExpCreateCheck(Isolate* isolate, PatternMatcher* matcher, const uint16_t* pattern, int pattern_len, bool ignore_case) {
    NativeStepScope native_step(isolate);
    HandleScope handle_scope(isolate);
    Local<Context> context = RegExpContext(isolate, matcher);
    if (context.IsEmpty()) return -2;
    Context::Scope context_scope(context);
    TryCatch try_catch(isolate);
    Local<RegExp> regexp;
    const int found = CachedRegExp(isolate, matcher, context, try_catch, ignore_case ? PatternMatcher::kRegExpCreateVI : PatternMatcher::kRegExpCreateV, pattern, pattern_len, &regexp);
    return found == 0 ? -3 : found;
}

/// engine.regExpBuiltinExecCaptures: ECMAScript RegExpBuiltinExec(R,
/// `input`) for R = RegExpCreate(`pattern`, "v" or "vi") - from the agent's
/// cache, or compiled and cached - both as UTF-16 code units, in the agent's
/// utility context. R has neither "g" nor "y", so its lastIndex is 0 for
/// every call (RegExpBuiltinExec steps 4-5 read it and ignore it; nothing in
/// that context writes it), and Exec - RegExpExec, which looks `exec` up on
/// R - finds that context's %RegExp.prototype.exec%, the built-in, whose
/// steps are RegExpBuiltinExec (v8_MatchesPatternAttribute says why the
/// page's realm would not do). 1: it matched, and `*out` is a malloc'd buffer
/// of `*out_len` bytes the caller frees with free(): a uint32 count n + 1,
/// then for each element 0..n of the result an int32 byte length - -1 for
/// undefined, a group that did not participate - and that many bytes of the
/// element as UTF-8 with a lone surrogate in its three-byte form (WTF-8:
/// String::WriteUtf8 without REPLACE_INVALID_UTF8), all unaligned and in the
/// host's byte order. 0: no match - null, or a match stopped at the
/// backtrack limit (kScriptRegExpBacktrackLimit). -1: RegExpCreate threw.
/// -2: no context, string or buffer could be made. -3: the isolate is
/// terminating (rethrown). A native step: no kAuto microtask checkpoint.
int v8_RegExpBuiltinExecCaptures(Isolate* isolate, PatternMatcher* matcher, const uint16_t* pattern, int pattern_len, bool ignore_case, const uint16_t* input, int input_len, char** out, size_t* out_len) {
    *out = nullptr;
    *out_len = 0;
    NativeStepScope native_step(isolate);
    HandleScope handle_scope(isolate);
    Local<Context> context = RegExpContext(isolate, matcher);
    if (context.IsEmpty()) return -2;
    Context::Scope context_scope(context);
    TryCatch try_catch(isolate);
    Local<RegExp> regexp;
    const int found = CachedRegExp(isolate, matcher, context, try_catch, ignore_case ? PatternMatcher::kRegExpCreateVI : PatternMatcher::kRegExpCreateV, pattern, pattern_len, &regexp);
    if (found != 1) return found == 0 ? -3 : found;

    Local<String> subject = String::Empty(isolate);
    if (input_len > 0 && !String::NewFromTwoByte(isolate, input, NewStringType::kNormal, input_len).ToLocal(&subject)) return -2;
    Local<Object> result;
    if (!regexp->Exec(context, subject).ToLocal(&result)) {
        if (try_catch.HasTerminated()) {
            try_catch.ReThrow();
            return -3;
        }
        // A throw RegExpBuiltinExec's "!"s rule out - an engine limit hit
        // while matching - is no match, as in Blink (ScriptRegexp::Match
        // answers -1).
        try_catch.Reset();
        return 0;
    }
    // Null: no match - also past the backtrack limit (v8-regexp.h).
    if (!result->IsArray()) return 0;
    Local<Array> array = result.As<Array>();
    const uint32_t count = array->Length();
    // The elements are the result's own data properties, made by
    // RegExpBuiltinExec's CreateDataPropertyOrThrow (steps 22, 33): reading
    // them runs nothing.
    std::vector<Local<Value>> elements;
    elements.reserve(count);
    size_t size = sizeof(uint32_t);
    for (uint32_t i = 0; i < count; ++i) {
        Local<Value> element;
        if (!array->Get(context, i).ToLocal(&element)) {
            if (try_catch.HasTerminated()) {
                try_catch.ReThrow();
                return -3;
            }
            try_catch.Reset();
            return -2;
        }
        size += sizeof(int32_t);
        if (element->IsString()) size += static_cast<size_t>(element.As<String>()->Utf8Length(isolate));
        elements.push_back(element);
    }
    char* buffer = static_cast<char*>(malloc(size));
    if (!buffer) return -2;
    char* at = buffer;
    std::memcpy(at, &count, sizeof(count));
    at += sizeof(count);
    for (const Local<Value>& element : elements) {
        int32_t length = -1;
        if (element->IsString()) {
            Local<String> string = element.As<String>();
            length = static_cast<int32_t>(string->Utf8Length(isolate));
            std::memcpy(at, &length, sizeof(length));
            at += sizeof(length);
            if (length > 0) string->WriteUtf8(isolate, at, static_cast<size_t>(length));
            at += length;
        } else {
            std::memcpy(at, &length, sizeof(length));
            at += sizeof(length);
        }
    }
    *out = buffer;
    *out_len = size;
    return 1;
}

} // extern "C"
// ---- end lane: regexop ----
// ---- lane: wasmweb1 (WebAssembly Web API 2: compileStreaming, instantiateStreaming) ----
//
// V8 defines WebAssembly.compileStreaming and instantiateStreaming itself, on
// every context it creates in an isolate with a WasmStreamingCallback
// (wasm-js.cc WasmJs::Install). Each call does Promise.resolve(source).then:
// a rejection rejects the call's promise (WasmStreamingPromiseFailedCallback),
// and a fulfilment calls the embedder's callback with the value and a
// WasmStreaming the embedder feeds bytes into - the design of Blink's
// v8_wasm_response_extensions.cc (StreamFromResponseCallback). Here the
// callback hands the value to the agent's
// HostHooks.compilePotentialWebAssemblyResponse through one process-wide
// dispatcher, and the host ends what it is handed with Finish or Abort below.

/// One compilation V8 handed the embedder: the WasmStreaming, kept until the
/// host (or the engine, at its realm's or agent's end) finishes or aborts it.
/// Opaque to Zig (ffi.WasmResponseCompilation); deleted by Finish and Abort.
struct CraneWasmResponseCompilation {
    Isolate* isolate;
    std::shared_ptr<WasmStreaming> streaming;
};

/// Hands `source` (borrowed for the call) and `compilation` (owned from here)
/// to the host of `isolate`'s agent; false when there is none, and then the
/// compilation is still the caller's.
typedef bool (*ProtocolWasmStreamingDispatch)(Isolate* isolate, Global<Context>* context, Global<Value>* source, CraneWasmResponseCompilation* compilation);

// process-wide: the one dispatcher (a Zig function finding the agent's hooks by isolate), set by engine.initializeEngine before any agent's thread runs, beside g_protocol_code_generation; every agent's isolate reads the same function. Atomic, as g_protocol_code_generation.
static std::atomic<ProtocolWasmStreamingDispatch> g_protocol_wasm_streaming{nullptr};

/// Reject a compilation no host took with a TypeError of the current
/// context, and delete it.
static void RefuseWasmStreaming(Isolate* isolate, CraneWasmResponseCompilation* compilation, const char* message) {
    {
        HandleScope scope(isolate);
        Local<Value> error = Exception::TypeError(String::NewFromUtf8(isolate, message).ToLocalChecked());
        compilation->streaming->Abort(error);
    }
    delete compilation;
}

/// Isolate::SetWasmStreamingCallback's callback: `info[0]` is what the call's
/// source fulfilled with, `info.DataV2().As<Value>()` the Managed<WasmStreaming>.
static void ProtocolWasmStreamingCallback(const FunctionCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    HandleScope scope(isolate);
    auto* compilation = new CraneWasmResponseCompilation{isolate, WasmStreaming::Unpack(isolate, info.DataV2().As<Value>())};
    Local<Context> context = isolate->GetCurrentContext();
    auto dispatch = g_protocol_wasm_streaming.load(std::memory_order_acquire);
    if (!dispatch || context.IsEmpty()) {
        RefuseWasmStreaming(isolate, compilation, "WebAssembly streaming compilation is not available here");
        return;
    }
    Global<Context> realm(isolate, context);
    Global<Value> source(isolate, info[0]);
    if (!dispatch(isolate, &realm, &source, compilation)) {
        RefuseWasmStreaming(isolate, compilation, "WebAssembly streaming compilation is not available here");
    }
}

extern "C" {

/// The process's dispatcher: once, at process start (initializeEngine).
void v8_SetProtocolWasmStreamingDispatcher(ProtocolWasmStreamingDispatch dispatch) {
    g_protocol_wasm_streaming.store(dispatch, std::memory_order_release);
}

/// Isolate::SetWasmStreamingCallback: every context made in `isolate` from
/// now on has WebAssembly.compileStreaming and instantiateStreaming.
void v8_Isolate_SetProtocolWasmStreaming(Isolate* isolate) {
    isolate->SetWasmStreamingCallback(ProtocolWasmStreamingCallback);
}

/// WasmStreaming::OnBytesReceived: `bytes` are copied.
void v8_WasmResponseCompilation_Append(CraneWasmResponseCompilation* compilation, const uint8_t* bytes, size_t length) {
    if (length == 0) return;
    compilation->streaming->OnBytesReceived(bytes, length);
}

/// WasmStreaming::SetUrl (when `url` is not empty) and Finish, then delete the
/// compilation. With `compilation`'s isolate entered.
void v8_WasmResponseCompilation_Finish(CraneWasmResponseCompilation* compilation, const char* url, size_t url_length) {
    {
        HandleScope scope(compilation->isolate);
        if (url_length != 0) compilation->streaming->SetUrl(url, url_length);
        compilation->streaming->Finish({});  // no code cache: no caching callback (d1834d91d32)
    }
    delete compilation;
}

/// WasmStreaming::Abort with `reason` (borrowed), or with none - the call's
/// promise is then never settled - and delete the compilation. With
/// `compilation`'s isolate entered.
void v8_WasmResponseCompilation_Abort(CraneWasmResponseCompilation* compilation, Global<Value>* reason) {
    {
        HandleScope scope(compilation->isolate);
        if (reason) {
            compilation->streaming->Abort(reason->Get(compilation->isolate));
        } else {
            compilation->streaming->Abort(MaybeLocal<Value>());
        }
    }
    delete compilation;
}

} // extern "C"
// ---- end lane: wasmweb1 ----
// ---- lane: console1 (engine.evaluateReplScript: REPL mode through the inspector) ----

/// What an agent's console keeps of V8's inspector (engine.evaluateReplScript,
/// protocol_repl.zig): an inspector of the agent's isolate, the client it
/// asks, and one session whose responses come back here.
///
/// REPL mode is Chrome DevTools' console evaluation - Runtime.evaluate with
/// `replMode` (js_protocol.pdl: "enables `let` re-declaration and top-level
/// `await`"). V8 13.1 compiles such a script with v8::debug::EvaluateGlobal's
/// repl flag, which is not public API (src/debug/debug-interface.h); its one
/// public door is the inspector. Deno's REPL, an embedder like Crane, goes
/// through it the same way: an in-process session that dispatches
/// Runtime.evaluate with replMode (deno cli/tools/repl/session.rs). A REPL
/// script always completes through a promise of {".repl_result": value}, and
/// the inspector answers once that settles (13.1 injected-script.cc,
/// ProtocolPromiseHandler::thenCallback unwraps `.repl_result`;
/// catchCallback reports a rejection) - so the answer comes in a
/// sendResponse, here, and is handed to `outcome`.
///
/// Per agent, never process-wide: the inspector is the isolate's
/// (V8Inspector::create(isolate, client) - v8::debug::SetInspector and
/// SetConsoleDelegate on that isolate alone), made on the console's first use
/// and deleted by the agent's end (v8_ReplSession_Delete) after its last
/// microtask checkpoint and before the isolate is disposed: a promise job of
/// the inspector's that ran after it was deleted would find no inspector
/// (13.1 thenCallback reads v8::debug::GetInspector). No V8 flag is set. No
/// domain is enabled, so the inspector reports nothing on its own (no
/// Runtime.consoleAPICalled, no exceptionThrown) and pauses nothing. Used on
/// the agent's own thread only.
class CraneReplSession final : public v8_inspector::V8InspectorClient,
                               public v8_inspector::V8Inspector::Channel {
public:
    /// What a response came to (protocol_repl.zig, Outcome).
    enum Kind : int { kCompleted = 0, kThrew = 1, kFailed = 2 };
    using Outcome = void (*)(void* host, int call_id, int kind, Global<Value>* value, bool incomplete);
    /// Every context of the agent is in the one group the session joins.
    static constexpr int kContextGroupId = 1;

    CraneReplSession(Isolate* isolate, Outcome outcome, void* host)
        : isolate_(isolate), outcome_(outcome), host_(host) {
        inspector_ = v8_inspector::V8Inspector::create(isolate, this);
        if (inspector_) {
            session_ = inspector_->connect(kContextGroupId, this, v8_inspector::StringView(),
                                           v8_inspector::V8Inspector::kFullyTrusted,
                                           v8_inspector::V8Inspector::kNotWaitingForDebugger);
        }
    }

    ~CraneReplSession() override {
        // From here on a response - the session's end fails what is still
        // pending - reaches nobody.
        closing_ = true;
        HandleScope handle_scope(isolate_);
        DetachContexts();
        if (session_) session_->releaseObjectGroup(ObjectGroup());
        session_.reset();
        inspector_.reset();
        utility_.Reset();
    }

    bool ok() const { return inspector_ && session_; }

    /// The inspector's execution context id for `context`, made known to the
    /// inspector first if it is not yet (contextCreated). 0 on failure.
    int Register(Local<Context> context) {
        int id = v8_inspector::V8ContextInfo::executionContextId(context);
        if (id != 0 && contexts_.count(id) != 0) return id;
        // InspectedContext's constructor gives the context's `console` a
        // createTask (async stack tagging, 13.1 inspected-context.cc). That
        // is Chrome's console object, not the Console Standard's, and nothing
        // of the console goes on the page: taken off again unless the page
        // had one of its own.
        Local<Object> console;
        bool had_create_task = true;
        {
            TryCatch try_catch(isolate_);
            Local<Value> found;
            if (context->Global()->Get(context, String::NewFromUtf8Literal(isolate_, "console")).ToLocal(&found) && found->IsObject()) {
                console = found.As<Object>();
                had_create_task = console->HasOwnProperty(context, String::NewFromUtf8Literal(isolate_, "createTask")).FromMaybe(true);
            }
        }
        const char* name = "crane-console";
        v8_inspector::V8ContextInfo info(context, kContextGroupId, v8_inspector::StringView(reinterpret_cast<const uint8_t*>(name), strlen(name)));
        inspector_->contextCreated(info);
        if (!console.IsEmpty() && !had_create_task) {
            TryCatch try_catch(isolate_);
            (void)console->Delete(context, String::NewFromUtf8Literal(isolate_, "createTask"));
        }
        id = v8_inspector::V8ContextInfo::executionContextId(context);
        if (id == 0) return 0;
        Global<Context> weak(isolate_, context);
        weak.SetWeak();
        contexts_[id] = std::move(weak);
        return id;
    }

    /// The realm of context `id` ended: the inspector forgets it now
    /// (contextDestroyed), while the context still exists, rather than when
    /// the collector takes it - which, at an agent's end, could be after the
    /// inspector itself.
    void ContextEnded(int id) {
        auto it = contexts_.find(id);
        if (it == contexts_.end()) return;
        Global<Context> handle = std::move(it->second);
        contexts_.erase(it);
        if (handle.IsEmpty()) return;
        HandleScope handle_scope(isolate_);
        inspector_->contextDestroyed(handle.Get(isolate_));
        handle.Reset();
    }

    /// Every context the inspector still knows of, forgotten (ContextEnded).
    void DetachContexts() {
        std::vector<int> ids;
        ids.reserve(contexts_.size());
        for (auto& entry : contexts_) ids.push_back(entry.first);
        for (int id : ids) ContextEnded(id);
    }

    /// Dispatch one protocol message (`json`, ASCII: protocol_repl.zig
    /// escapes everything else). What a previous response bound in the
    /// object group is released first: the host has taken its value.
    void Dispatch(const uint8_t* json, size_t length) {
        if (release_pending_) {
            session_->releaseObjectGroup(ObjectGroup());
            release_pending_ = false;
        }
        // Not a script call: no kAuto microtask checkpoint inside it
        // (NativeStepScope), so an evaluation's outcome comes back at the
        // agent's next checkpoint - or here, for input that does not parse.
        NativeStepScope native_step(isolate_);
        session_->dispatchProtocolMessage(v8_inspector::StringView(json, length));
    }

    // ---- V8Inspector::Channel ----

    void sendResponse(int call_id, std::unique_ptr<v8_inspector::StringBuffer> message) override {
        if (closing_ || !message) return;
        release_pending_ = true;
        HandleScope handle_scope(isolate_);
        int kind = kFailed;
        bool incomplete = false;
        Global<Value>* owned = nullptr;
        {
            TryCatch try_catch(isolate_);
            Local<Value> value;
            kind = Read(message->string(), &value);
            if (kind == kThrew) incomplete = IsIncompleteInput(value);
            if (kind != kFailed) owned = trackHandle(new Global<Value>(isolate_, value));
        }
        // In the context the inspector entered for the response - the
        // evaluation's - not the utility context Read parsed in.
        outcome_(host_, call_id, kind, owned, incomplete);
    }

    void sendNotification(std::unique_ptr<v8_inspector::StringBuffer>) override {}
    void flushProtocolNotifications() override {}

    // ---- V8InspectorClient ----

    /// The inspector's ids (each context's unique id, its isolate's) from a
    /// counter of the session's own: by default it draws them from the
    /// isolate's random number generator, which a seeded agent's Math.random
    /// is seeded from (engine.capabilities.seeded_random).
    int64_t generateUniqueId() override { return ++unique_id_; }

private:
    /// The object group every response's values are bound in (a string
    /// literal: static storage).
    static v8_inspector::StringView ObjectGroup() {
        const char* group = "crane-repl";
        return v8_inspector::StringView(reinterpret_cast<const uint8_t*>(group), strlen(group));
    }

    /// The context responses are parsed in: the session's own, made on first
    /// use - a plain global no script can reach, so reading the parsed JSON
    /// runs nothing of the page's (NewPlainGlobalContext). Empty when none
    /// could be made.
    Local<Context> Utility() {
        if (utility_.IsEmpty()) {
            Local<Context> made = NewPlainGlobalContext(isolate_);
            if (made.IsEmpty()) return made;
            utility_.Reset(isolate_, made);
        }
        return utility_.Get(isolate_);
    }

    static Local<Value> Field(Isolate* isolate, Local<Context> context, Local<Value> object, const char* name) {
        if (!object->IsObject()) return Undefined(isolate);
        Local<String> key;
        Local<Value> found;
        if (!String::NewFromUtf8(isolate, name).ToLocal(&key) || !object.As<Object>()->Get(context, key).ToLocal(&found)) return Undefined(isolate);
        return found;
    }

    /// A Runtime.evaluate response (`message`): kCompleted with the result,
    /// kThrew with the exception (`exceptionDetails.exception`), or kFailed
    /// (an error response, or one this cannot read).
    int Read(v8_inspector::StringView message, Local<Value>* value) {
        Local<Context> utility = Utility();
        if (utility.IsEmpty()) return kFailed;
        Context::Scope context_scope(utility);
        Local<String> text;
        const bool made = message.is8Bit()
            ? String::NewFromOneByte(isolate_, message.characters8(), NewStringType::kNormal, static_cast<int>(message.length())).ToLocal(&text)
            : String::NewFromTwoByte(isolate_, message.characters16(), NewStringType::kNormal, static_cast<int>(message.length())).ToLocal(&text);
        Local<Value> parsed;
        if (!made || !JSON::Parse(utility, text).ToLocal(&parsed)) return kFailed;
        Local<Value> result = Field(isolate_, utility, parsed, "result");
        if (!result->IsObject()) return kFailed;
        Local<Value> details = Field(isolate_, utility, result, "exceptionDetails");
        const bool threw = details->IsObject();
        Local<Value> remote = threw ? Field(isolate_, utility, details, "exception") : Field(isolate_, utility, result, "result");
        if (!remote->IsObject() || !FromRemoteObject(utility, remote, value)) return kFailed;
        return threw ? kThrew : kCompleted;
    }

    /// The value a Runtime.RemoteObject stands for: an object (or symbol)
    /// by its objectId, a primitive by its `value` or `unserializableValue`.
    bool FromRemoteObject(Local<Context> utility, Local<Value> remote, Local<Value>* out) {
        Local<Value> object_id = Field(isolate_, utility, remote, "objectId");
        if (object_id->IsString()) {
            String::Utf8Value id(isolate_, object_id);
            if (!*id) return false;
            std::unique_ptr<v8_inspector::StringBuffer> error;
            std::unique_ptr<v8_inspector::StringBuffer> group;
            Local<Context> context;
            return session_->unwrapObject(&error, v8_inspector::StringView(reinterpret_cast<const uint8_t*>(*id), static_cast<size_t>(id.length())), out, &context, &group);
        }
        Local<Value> unserializable = Field(isolate_, utility, remote, "unserializableValue");
        if (unserializable->IsString()) {
            String::Utf8Value text(isolate_, unserializable);
            if (!*text) return false;
            const std::string value(*text, static_cast<size_t>(text.length()));
            if (value == "NaN") *out = Number::New(isolate_, std::numeric_limits<double>::quiet_NaN());
            else if (value == "Infinity") *out = Number::New(isolate_, std::numeric_limits<double>::infinity());
            else if (value == "-Infinity") *out = Number::New(isolate_, -std::numeric_limits<double>::infinity());
            else if (value == "-0") *out = Number::New(isolate_, -0.0);
            else if (!value.empty() && value.back() == 'n') {
                // A BigInt, as its digits and "n": BigInt(digits), the
                // utility context's own %BigInt%.
                Local<Value> big_int;
                Local<String> digits;
                if (!utility->Global()->Get(utility, String::NewFromUtf8Literal(isolate_, "BigInt")).ToLocal(&big_int) || !big_int->IsFunction()) return false;
                if (!String::NewFromUtf8(isolate_, value.data(), NewStringType::kNormal, static_cast<int>(value.size() - 1)).ToLocal(&digits)) return false;
                Local<Value> argv[] = {digits};
                if (!big_int.As<Function>()->Call(utility, Undefined(isolate_), 1, argv).ToLocal(out)) return false;
            } else {
                return false;
            }
            return true;
        }
        if (remote.As<Object>()->HasOwnProperty(utility, String::NewFromUtf8Literal(isolate_, "value")).FromMaybe(false)) {
            *out = Field(isolate_, utility, remote, "value");
            return true;
        }
        Local<Value> type = Field(isolate_, utility, remote, "type");
        if (type->IsString()) {
            String::Utf8Value name(isolate_, type);
            if (*name && strcmp(*name, "undefined") == 0) {
                *out = Undefined(isolate_);
                return true;
            }
        }
        return false;
    }

    /// Whether `exception` - what the input threw - says the input ended
    /// before its syntax did: V8's SyntaxErrors "Unexpected end of input" and
    /// "Unterminated template literal", the two Chrome DevTools' console
    /// reads as "read another line" (JavaScriptREPL.isExpressionComplete:
    /// Runtime.compileScript, then the exception's description). Read from
    /// V8's own message for the value (Exception::CreateMessage: no script
    /// runs), never from properties the page could change.
    bool IsIncompleteInput(Local<Value> exception) {
        if (exception.IsEmpty() || !exception->IsNativeError()) return false;
        Local<Message> message = Exception::CreateMessage(isolate_, exception);
        if (message.IsEmpty()) return false;
        String::Utf8Value text(isolate_, message->Get());
        if (!*text) return false;
        return strcmp(*text, "Uncaught SyntaxError: Unexpected end of input") == 0 ||
               strcmp(*text, "Uncaught SyntaxError: Unterminated template literal") == 0;
    }

    Isolate* isolate_;
    Outcome outcome_;
    void* host_;
    bool closing_ = false;
    /// A response bound its value in the object group: released at the next
    /// dispatch (the host took the value in `outcome`).
    bool release_pending_ = false;
    int64_t unique_id_ = 0x63726e65;
    /// The contexts made known to the inspector, by its id: weak handles,
    /// for ContextEnded.
    std::unordered_map<int, Global<Context>> contexts_;
    Global<Context> utility_;
    std::unique_ptr<v8_inspector::V8Inspector> inspector_;
    std::unique_ptr<v8_inspector::V8InspectorSession> session_;
};

extern "C" {

/// A new console session for `isolate` (CraneReplSession), whose responses
/// go to `outcome(host, ...)`. Null when V8 could not make one. With the
/// isolate entered.
CraneReplSession* v8_ReplSession_New(Isolate* isolate, CraneReplSession::Outcome outcome, void* host) {
    if (!isolate || !outcome) return nullptr;
    auto* session = new CraneReplSession(isolate, outcome, host);
    if (!session->ok()) {
        delete session;
        return nullptr;
    }
    return session;
}

/// End the session: every context it made known is forgotten, its pending
/// evaluations fail silently, and the inspector is deleted. With the
/// isolate entered, before it is disposed.
void v8_ReplSession_Delete(CraneReplSession* session) {
    delete session;
}

/// The inspector's execution context id for `context` (registered on first
/// use); 0 on failure.
int v8_ReplSession_Register(CraneReplSession* session, Global<Context>* context) {
    if (!session || !context || context->IsEmpty()) return 0;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> local = context->Get(isolate);
    Context::Scope context_scope(local);
    return session->Register(local);
}

/// Dispatch a protocol message (ASCII JSON) to the session.
void v8_ReplSession_Dispatch(CraneReplSession* session, const uint8_t* json, size_t length) {
    if (!session || !json) return;
    session->Dispatch(json, length);
}

/// The realm whose context the inspector knows as `context_id` ended.
void v8_ReplSession_ContextEnded(CraneReplSession* session, int context_id) {
    if (!session) return;
    session->ContextEnded(context_id);
}

/// Every context the session made known, forgotten (the agent's end).
void v8_ReplSession_DetachContexts(CraneReplSession* session) {
    if (!session) return;
    session->DetachContexts();
}

} // extern "C"
// ---- end lane: console1 ----
