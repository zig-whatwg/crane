# Storage Standard - Type Dependencies Analysis

**Generated**: 2025-11-26  
**Sources**: 
- `specs/idl/storage.idl` (WHATWG Storage Standard)
- `specs/idl/storage-buckets.idl` (Storage Buckets API)
- `specs/whatwg/storage.md` (Storage spec text)

---

## Executive Summary

The **Storage Standard** is **REMARKABLY SIMPLE** from a type dependency perspective. It is one of the **LEAST COMPLEX** WHATWG specifications, making it an **EXCELLENT STARTING POINT** for implementation.

### Critical Statistics

- **Core IDL Size**: 26 lines (storage.idl) + 46 lines (storage-buckets.idl) = **72 lines total**
- **Total External Specs Referenced**: **3-5** (minimal)
- **Total External Type References**: **~10 occurrences**
- **Most Critical Dependencies**: HTML (Navigator), WebIDL (Promise, types), File System (optional)
- **Complexity Level**: **VERY LOW** - One of the simplest WHATWG specs
- **Self-Contained**: **YES** - Almost entirely self-contained

### Comparison with Other Specs

| Spec | IDL Lines | External Deps | Type References | Complexity |
|------|-----------|---------------|-----------------|------------|
| **Storage** | 72 | 3-5 | ~10 | **VERY LOW** ✅ |
| File System | 272 | 8-10 | ~30 | MEDIUM |
| HTML | 3067 | 20+ | 150+ | VERY HIGH |

**🎯 Storage is 42x smaller than HTML and 3.5x smaller than File System!**

---

## Type-Level Dependencies (ALL External Types)

### 1. **HTML Standard** (MEDIUM - Navigator Integration)

**Spec**: https://html.spec.whatwg.org/

**Types Used**:
- `Navigator` - Browser navigator interface (extended with NavigatorStorage mixin)
- `WorkerNavigator` - Worker navigator interface (extended with NavigatorStorage mixin)

**Usage Frequency**: **LOW** (2 occurrences)

**Where Used**:
```idl
// storage.idl lines 7-11
[SecureContext]
interface mixin NavigatorStorage {
  [SameObject] readonly attribute StorageManager storage;
};
Navigator includes NavigatorStorage;
WorkerNavigator includes NavigatorStorage;

// storage-buckets.idl lines 7-11
[SecureContext]
interface mixin NavigatorStorageBuckets {
  [SameObject] readonly attribute StorageBucketManager storageBuckets;
};
Navigator includes NavigatorStorageBuckets;
WorkerNavigator includes NavigatorStorageBuckets;
```

**Blocker Level**: **MEDIUM** - Entry point only

**Implementation Impact**:
- Need `Navigator` interface to add `navigator.storage` property
- Need `WorkerNavigator` interface to add `navigator.storage` in workers
- **Can stub with minimal Navigator/WorkerNavigator interfaces**
- Don't need full HTML spec, just these two interfaces

**Alternative**: Could define standalone `StorageManager` without Navigator integration initially

---

### 2. **WebIDL Types** (CRITICAL - Type System)

**Spec**: https://webidl.spec.whatwg.org/

**Types Used**:
- `Promise<T>` - All async operations
- `DOMString` - String type
- `unsigned long long` - Large integers (quota, usage)
- `DOMHighResTimeStamp` - Timestamps (Storage Buckets API only)
- `sequence<T>` - Arrays
- Extended attributes: `[SecureContext]`, `[Exposed]`, `[SameObject]`

**Usage Frequency**: **UBIQUITOUS** (every interface and method)

**Critical Operations**:
```idl
// storage.idl
Promise<boolean> persisted();
Promise<boolean> persist();
Promise<StorageEstimate> estimate();

// storage-buckets.idl
Promise<StorageBucket> open(DOMString name, ...);
Promise<sequence<DOMString>> keys();
Promise<undefined> delete(DOMString name);
DOMHighResTimeStamp expires;  // Optional timestamp support
```

**Blocker Level**: **CRITICAL** - Cannot compile IDL without WebIDL types

**Implementation Impact**: Standard WebIDL dependency (same as all specs)

---

### 3. **File System Standard** (OPTIONAL - Storage Buckets Only)

**Spec**: https://fs.spec.whatwg.org/

**Types Used**:
- `FileSystemDirectoryHandle` - Directory handle for bucket file system

**Usage Frequency**: **VERY LOW** (1 occurrence)

**Where Used**:
```idl
// storage-buckets.idl line 44
interface StorageBucket {
  // ...
  Promise<FileSystemDirectoryHandle> getDirectory();
};
```

**Blocker Level**: **LOW** - Optional feature

**Implementation Impact**:
- Only needed for Storage Buckets API (extension spec)
- Core Storage Standard (storage.idl) doesn't reference File System
- **Can defer** or **stub** this method
- Without this: Storage Buckets can't access file system, but core storage still works

---

### 4. **IndexedDB** (OPTIONAL - Storage Buckets Only)

**Spec**: https://w3c.github.io/IndexedDB/

**Types Used**:
- `IDBFactory` - IndexedDB factory interface

**Usage Frequency**: **VERY LOW** (1 occurrence)

**Where Used**:
```idl
// storage-buckets.idl line 40
interface StorageBucket {
  // ...
  [SameObject] readonly attribute IDBFactory indexedDB;
};
```

**Blocker Level**: **LOW** - Optional feature

**Implementation Impact**:
- Only needed for Storage Buckets API
- Core Storage Standard doesn't reference IndexedDB
- **Can defer** or return `null`
- Without this: Storage Buckets can't access IndexedDB, but core storage still works

---

### 5. **Service Workers / Cache API** (OPTIONAL - Storage Buckets Only)

**Spec**: https://w3c.github.io/ServiceWorker/

**Types Used**:
- `CacheStorage` - Cache storage interface

**Usage Frequency**: **VERY LOW** (1 occurrence)

**Where Used**:
```idl
// storage-buckets.idl line 42
interface StorageBucket {
  // ...
  [SameObject] readonly attribute CacheStorage caches;
};
```

**Blocker Level**: **LOW** - Optional feature

**Implementation Impact**:
- Only needed for Storage Buckets API
- Core Storage Standard doesn't reference CacheStorage
- **Can defer** or return `null`
- Without this: Storage Buckets can't access Cache API, but core storage still works

---

### 6. **Permissions API** (DEPENDENCY - From Spec Text)

**Spec**: https://w3c.github.io/permissions/

**Types Referenced in Spec Text**:
- Persistence permission uses Permissions API concepts

**Usage in IDL**: **NONE** (no types in IDL)

**Usage in Spec Algorithms**:
- Line 26: `navigator.permissions.query({name: "persistent-storage"})`
- Spec defines "`persistent-storage`" as a powerful feature
- Permission state affects whether `persist()` succeeds

**Blocker Level**: **MEDIUM** - Conceptual dependency

**Implementation Impact**:
- Core Storage API **can work without Permissions**
- `persist()` can always return `false` or always grant permission
- `persisted()` can always return current state
- **Permissions integration can be added later**

---

## Dependency Frequency Analysis

### Ubiquitous (Every API)
1. **WebIDL** - Promise, DOMString, unsigned long long - Every method uses these

### Low Frequency (1-2 references)
2. **HTML** - Navigator, WorkerNavigator - 2 references (entry points)
3. **File System** - FileSystemDirectoryHandle - 1 reference (Storage Buckets only)
4. **IndexedDB** - IDBFactory - 1 reference (Storage Buckets only)
5. **Cache API** - CacheStorage - 1 reference (Storage Buckets only)

### Conceptual Only (Not in IDL)
6. **Permissions** - Referenced in algorithms, not in type system

---

## Critical Types vs Optional Types

### Critical Types (MUST HAVE for core functionality)

**WebIDL**:
- `Promise<T>` - **All async operations**
- `DOMString` - **Bucket names, identifiers**
- `unsigned long long` - **Quota and usage bytes**

**HTML (Minimal)**:
- `Navigator` interface (just the interface definition, not full implementation)
- `WorkerNavigator` interface (just the interface definition)

**That's it!** The core Storage Standard needs **only 2 external interfaces**.

### Optional Types (Can be stubbed/deferred)

**Storage Buckets API Extensions**:
- `FileSystemDirectoryHandle` - Only for bucket file system access
- `IDBFactory` - Only for bucket IndexedDB access
- `CacheStorage` - Only for bucket cache access
- `DOMHighResTimeStamp` - Only for bucket expiration times

**Permissions**:
- Can stub permission checks (always grant or always deny)

---

## Core Storage APIs vs Optional APIs

### Core Storage API (storage.idl - 26 lines)

**What It Provides**:
- `navigator.storage.persisted()` - Check if storage is persistent
- `navigator.storage.persist()` - Request persistent storage
- `navigator.storage.estimate()` - Get usage and quota estimates

**Dependencies**: 
- HTML (Navigator interface)
- WebIDL (Promise, types)

**Self-Contained**: **YES** - Minimal dependencies

**Complexity**: **VERY LOW**

**Example Usage**:
```javascript
// Check persistence
const isPersisted = await navigator.storage.persisted();

// Request persistence
const granted = await navigator.storage.persist();

// Check quota
const estimate = await navigator.storage.estimate();
console.log(estimate.usage);  // bytes used
console.log(estimate.quota);  // bytes available
```

---

### Storage Buckets API (storage-buckets.idl - 46 lines)

**What It Provides**:
- `navigator.storageBuckets.open(name)` - Create/open named storage bucket
- `navigator.storageBuckets.keys()` - List bucket names
- `navigator.storageBuckets.delete(name)` - Delete bucket
- Per-bucket quota, persistence, expiration
- Per-bucket IndexedDB, Cache, File System access

**Dependencies**:
- HTML (Navigator interface)
- WebIDL (Promise, types)
- File System (FileSystemDirectoryHandle) - Optional
- IndexedDB (IDBFactory) - Optional
- Cache API (CacheStorage) - Optional

**Self-Contained**: **NO** - Depends on other storage APIs

**Complexity**: **LOW-MEDIUM**

**Example Usage**:
```javascript
// Open a bucket
const bucket = await navigator.storageBuckets.open('drafts', {
  persisted: true,
  quota: 1024 * 1024 * 100  // 100 MB
});

// Access bucket's file system
const root = await bucket.getDirectory();

// Access bucket's IndexedDB
const db = bucket.indexedDB.open('my-db');

// Check bucket quota
const estimate = await bucket.estimate();
```

---

## Implementation Phases

### Phase 1: Core Storage Standard (RECOMMENDED START)

**Implement**: `storage.idl` only (26 lines)

**Required Dependencies**:
1. **WebIDL Types** - Promise, DOMString, unsigned long long
2. **HTML** - Navigator, WorkerNavigator (minimal stubs acceptable)

**Deliverable**:
- `navigator.storage` object
- `navigator.storage.persisted()` - Returns boolean
- `navigator.storage.persist()` - Returns boolean
- `navigator.storage.estimate()` - Returns { usage, quota }

**Implementation Complexity**: **VERY LOW**

**Estimated Time**: **1-3 days**

**What It Enables**:
- Web apps can check storage persistence
- Web apps can request persistent storage
- Web apps can monitor quota usage
- Provides foundation for all storage APIs

**Stub Strategy**:
```zig
// Minimal Navigator stub
pub const Navigator = struct {
    storage: *StorageManager,
};

// StorageManager implementation
pub const StorageManager = struct {
    pub fn persisted(self: *StorageManager) !Promise(bool) {
        // Return whether origin storage is persistent
        return Promise(bool).resolve(false);
    }
    
    pub fn persist(self: *StorageManager) !Promise(bool) {
        // Request persistence (can stub to always fail initially)
        return Promise(bool).resolve(false);
    }
    
    pub fn estimate(self: *StorageManager) !Promise(StorageEstimate) {
        // Return usage/quota estimate
        return Promise(StorageEstimate).resolve(.{
            .usage = 0,
            .quota = 1024 * 1024 * 1024, // 1 GB default
        });
    }
};

pub const StorageEstimate = struct {
    usage: u64,
    quota: u64,
};
```

---

### Phase 2: Storage Buckets API (Optional)

**Implement**: `storage-buckets.idl` (46 lines)

**Additional Dependencies**:
1. File System - FileSystemDirectoryHandle (can defer)
2. IndexedDB - IDBFactory (can defer)
3. Cache API - CacheStorage (can defer)

**Deliverable**:
- `navigator.storageBuckets` object
- Named storage buckets
- Per-bucket quota and persistence
- Per-bucket storage API access

**Implementation Complexity**: **MEDIUM** (depends on other APIs)

**Estimated Time**: **1-2 weeks** (assuming dependencies exist)

**Stub Strategy**: Can return null for indexedDB, caches, getDirectory() initially

---

### Phase 3: Storage Backend Implementation

**What Needs Implementation** (not in IDL, but required for functionality):

**Storage Shed Architecture**:
- Storage shed (origin-based storage isolation)
- Storage shelf (per-origin storage)
- Storage bucket (default bucket + named buckets)
- Storage bottles (per-API storage within bucket)

**Algorithms**:
- Obtain storage key
- Obtain storage shelf
- Create storage bucket
- Obtain storage bottle map
- Calculate storage quota
- Calculate storage usage

**Persistence**:
- Persistent vs best-effort mode
- Storage eviction under pressure
- User-facing clear storage UI

**Estimated Time**: **2-4 weeks** (backend implementation)

---

## Spec Dependency Graph

```
Storage Standard (storage.idl) - CORE
│
├─── HTML Standard (MINIMAL - ENTRY POINT ONLY)
│    ├─── Navigator → navigator.storage
│    └─── WorkerNavigator → worker navigator.storage
│
└─── WebIDL (CRITICAL - TYPE SYSTEM)
     ├─── Promise<T> → All async operations
     ├─── DOMString → Strings
     └─── unsigned long long → Quota/usage bytes

Storage Buckets API (storage-buckets.idl) - OPTIONAL EXTENSION
│
├─── Storage Standard → Extends StorageManager, uses StorageEstimate
│
├─── HTML Standard (MINIMAL)
│    ├─── Navigator → navigator.storageBuckets
│    └─── WorkerNavigator → worker navigator.storageBuckets
│
├─── WebIDL (CRITICAL)
│    ├─── Promise<T> → Async operations
│    ├─── DOMString → Bucket names
│    ├─── DOMHighResTimeStamp → Expiration times
│    └─── sequence<T> → Arrays
│
├─── File System (OPTIONAL)
│    └─── FileSystemDirectoryHandle → bucket.getDirectory()
│
├─── IndexedDB (OPTIONAL)
│    └─── IDBFactory → bucket.indexedDB
│
└─── Cache API (OPTIONAL)
     └─── CacheStorage → bucket.caches
```

---

## What Storage Standard Enables

The Storage Standard is **FOUNDATIONAL** for web storage. It provides:

### 1. **Storage Isolation Model**

Defines how storage is isolated by origin:
- Storage shed (user agent level)
- Storage shelf (per origin)
- Storage bucket (per policy)
- Storage bottle (per API)

**Who Uses This**:
- IndexedDB - Stores data in "`indexedDB`" bottle
- Cache API - Stores data in "`caches`" bottle
- localStorage - Stores data in "`localStorage`" bottle
- Service Workers - Store registrations in "`serviceWorkerRegistrations`" bottle
- File System - Uses storage bottles (via StorageManager integration)

### 2. **Quota Management**

Provides API to:
- Check storage usage: `navigator.storage.estimate()`
- Monitor available space
- Prevent quota exceeded errors

**Who Uses This**:
- All web apps that store data locally
- Progressive Web Apps (PWAs)
- Offline-capable apps

### 3. **Persistence Control**

Allows apps to request persistent storage:
- `navigator.storage.persist()` - Request persistence
- `navigator.storage.persisted()` - Check persistence status

**Why It Matters**:
- Without persistence: Browser can evict storage under pressure
- With persistence: Storage survives across sessions and low-disk scenarios
- Critical for offline apps, document editors, media libraries

### 4. **Registered Storage Endpoints**

From spec text (line 107-115):

| Identifier | Type | Quota | What Uses It |
|------------|------|-------|--------------|
| `"caches"` | local | null | Cache API |
| `"indexedDB"` | local | null | IndexedDB |
| `"localStorage"` | local | 5 MiB | localStorage |
| `"serviceWorkerRegistrations"` | local | null | Service Workers |
| `"sessionStorage"` | session | 5 MiB | sessionStorage |

**All of these APIs depend on Storage Standard for isolation and quota!**

---

## Comparison with Other Specs

### Storage vs File System

| Aspect | Storage Standard | File System Standard |
|--------|------------------|----------------------|
| **Complexity** | Very Low | Medium |
| **IDL Lines** | 72 | 272 |
| **External Dependencies** | 3-5 | 8-10 |
| **Type References** | ~10 | ~30 |
| **Hard Blockers** | None (can stub Navigator) | Streams (critical) |
| **Self-Contained** | Yes (core spec) | Mostly |
| **Implementation Time** | 1-3 days (core) | 4-6 weeks |

**Key Differences**:
1. Storage is **4x smaller** than File System
2. Storage has **NO hard blockers** (Navigator can be stubbed)
3. Storage is **foundational** (other APIs depend on it)
4. File System **depends on Storage** (for StorageManager integration)

### Storage vs HTML

| Aspect | Storage Standard | HTML Standard |
|--------|------------------|---------------|
| **Complexity** | Very Low | Very High |
| **IDL Lines** | 72 | 3067 |
| **External Dependencies** | 3-5 | 20+ |
| **Type References** | ~10 | 150+ |
| **Hard Blockers** | None | DOM (blocks everything) |

**Storage is 42x smaller and infinitely simpler than HTML!**

---

## Implementation Recommendations

### Strategy 1: Implement Core Storage First (HIGHLY RECOMMENDED)

**Approach**: Implement `storage.idl` (26 lines) as a foundational piece

**Pros**:
- ✅ **VERY SIMPLE** - Only 26 lines of IDL
- ✅ **NO HARD BLOCKERS** - Can stub Navigator initially
- ✅ **FOUNDATIONAL** - Other specs depend on this
- ✅ **IMMEDIATE VALUE** - Apps can check quota and persistence
- ✅ **FAST** - Can implement in 1-3 days
- ✅ **CLEAN** - Minimal dependencies

**Cons**:
- Backend implementation (storage shed, quota calculation) takes additional time
- Full functionality requires integration with other storage APIs

**Timeline**:
1. Stub Navigator/WorkerNavigator (1 hour)
2. Implement StorageManager interface (4 hours)
3. Implement basic quota estimation (4 hours)
4. Add persistence tracking (4 hours)
5. Total: **1-2 days for working API**
6. Backend storage shed: **1-2 weeks additional**

---

### Strategy 2: Defer Storage (NOT RECOMMENDED)

**Approach**: Skip Storage, implement other specs first

**Pros**:
- Can focus on more visible features first

**Cons**:
- ❌ Other storage APIs lose quota management
- ❌ No persistence control for apps
- ❌ Missing foundational infrastructure
- ❌ Will need to implement later anyway

**Not recommended** - Storage is too foundational to skip

---

### Strategy 3: Implement Storage + File System Together

**Approach**: Implement Storage Standard, then integrate with File System

**Pros**:
- ✅ File System gains StorageManager integration
- ✅ `navigator.storage.getDirectory()` works
- ✅ Clean integration from the start

**Cons**:
- File System needs Streams (hard blocker)
- Longer overall timeline

**Timeline**:
1. Implement Storage Standard (1-3 days)
2. Implement Streams (2-3 weeks)
3. Implement File System (1-2 weeks)
4. Total: **3-4 weeks for integrated storage**

---

## Recommended Implementation Path

**Phase 1: Storage Standard Core** (1-3 days)
- Implement `storage.idl` (26 lines)
- Stub Navigator/WorkerNavigator
- Basic quota estimation
- Basic persistence tracking

**Phase 2: Storage Backend** (1-2 weeks)
- Implement storage shed architecture
- Implement origin isolation
- Implement quota calculation
- Implement persistence mode

**Phase 3: Storage Buckets API** (Optional - 1-2 weeks)
- Implement `storage-buckets.idl` (46 lines)
- Named buckets
- Per-bucket quota
- Defer IndexedDB/Cache/FileSystem integration

**Phase 4: Integration with Other APIs** (Ongoing)
- Integrate with IndexedDB (when implemented)
- Integrate with Cache API (when implemented)
- Integrate with File System (when implemented)
- Integrate with localStorage/sessionStorage (when implemented)

**Total Estimated Time**:
- **Core API**: 1-3 days
- **Backend**: 1-2 weeks
- **Full Storage Standard**: 2-3 weeks
- **With Storage Buckets**: 3-4 weeks

---

## Summary

The Storage Standard is **REMARKABLY SIMPLE** with only **3-5 type-level dependencies**. It is one of the **SIMPLEST WHATWG specifications** and an **EXCELLENT STARTING POINT** for implementation.

### Critical Dependencies (Core Storage):

1. **HTML** (Navigator, WorkerNavigator) - Can stub with minimal interfaces
2. **WebIDL** - Standard type system

**That's it!** Only 2 dependencies for core functionality.

### Optional Dependencies (Storage Buckets):

3. **File System** (FileSystemDirectoryHandle) - Can defer
4. **IndexedDB** (IDBFactory) - Can defer
5. **Cache API** (CacheStorage) - Can defer

**Recommended Path**: 
1. Implement core Storage Standard first (1-3 days)
2. It's foundational for other storage APIs
3. Storage Buckets can be added later
4. NO hard blockers - can start immediately!

**Complexity**: **VERY LOW** - 72 lines of IDL, minimal dependencies, no hard blockers

**Value**: **VERY HIGH** - Foundational for all web storage APIs
