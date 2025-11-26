# File System Specification - Type Dependencies Analysis

**Generated**: 2025-11-26  
**Sources**: 
- `specs/idl/fs.idl` (WHATWG File System Standard)
- `specs/idl/FileAPI.idl` (W3C File API)
- `specs/idl/file-system-access.idl` (WICG File System Access)
- `specs/whatwg/fs.md` (File System spec text)

---

## Executive Summary

The **File System Standard** has a **moderate number of type-level dependencies** compared to HTML. The implementation is **reasonably self-contained** but requires several critical WHATWG specifications to function.

### Critical Statistics

- **Core Spec Files**: 3 (fs.idl, FileAPI.idl, file-system-access.idl)
- **Total External Specs Referenced**: 8-10
- **Total External Type References**: ~30 occurrences
- **Most Critical Dependencies**: Streams, WebIDL, DOM, Storage, Permissions
- **Complexity Level**: **MEDIUM** - Much simpler than HTML

---

## Type-Level Blockers (Critical Dependencies)

### 1. **Streams Standard** (CRITICAL - Core Functionality)

**Spec**: https://streams.spec.whatwg.org/

**Types Used**:
- `WritableStream` - Base class for FileSystemWritableFileStream
- `ReadableStream` - Returned by Blob.stream()

**Usage Frequency**: **HIGH** (5+ occurrences)

**Where Used**:
```idl
// fs.idl line 71
interface FileSystemWritableFileStream : WritableStream {
  Promise<undefined> write(FileSystemWriteChunkType data);
  Promise<undefined> seek(unsigned long long position);
  Promise<undefined> truncate(unsigned long long size);
};

// FileAPI.idl line 20
[NewObject] ReadableStream stream();  // Blob.stream()
```

**Critical APIs**:
- `FileSystemWritableFileStream` extends `WritableStream` - **Core file writing API**
- `Blob.stream()` returns `ReadableStream` - **Core file reading API**

**Blocker Level**: **CRITICAL** - File writing and streaming completely broken without

**Implementation Impact**: 
- Without Streams: Cannot implement `FileSystemWritableFileStream` (file writing)
- Without Streams: Cannot implement `Blob.stream()` (streaming file reading)
- **This is a hard blocker** - the File System API fundamentally depends on Streams

---

### 2. **WebIDL Types** (CRITICAL - Type System)

**Spec**: https://webidl.spec.whatwg.org/

**Types Used**:
- `Promise<T>` - All async operations
- `DOMString`, `USVString` - String types
- `BufferSource`, `AllowSharedBufferSource` - Binary data
- `ArrayBuffer`, `Uint8Array` - Binary data arrays
- `sequence<T>` - Arrays
- `record<K, V>` - Maps/dictionaries
- Extended attributes: `[Exposed]`, `[SecureContext]`, `[Serializable]`, `[EnforceRange]`, `[Clamp]`, `[NewObject]`

**Usage Frequency**: **UBIQUITOUS** (every interface and method)

**Critical Operations**:
- All async operations return `Promise<T>`
- File content uses `BufferSource` (FileAPI.idl line 33)
- Synchronous file access uses `AllowSharedBufferSource` (fs.idl lines 83, 85)
- File names use `USVString`
- File types use `DOMString`

**Blocker Level**: **CRITICAL** - Cannot compile IDL without WebIDL types

---

### 3. **File API (Internal to this analysis)** (CRITICAL - Core Types)

**Spec**: https://w3c.github.io/FileAPI/

**Note**: This is part of the File System specification family, but provides foundational types.

**Types Defined**:
- `Blob` - Binary large object (base type)
- `File` - File with metadata (extends Blob)
- `FileList` - Collection of files
- `FileReader` - Async file reading
- `FileReaderSync` - Sync file reading (workers only)

**Dependencies**:
- `BlobPart` typedef: `(BufferSource or Blob or USVString)`
- Extends `EventTarget` (for FileReader)

**Usage in File System**:
```idl
// fs.idl line 25
Promise<File> getFile();  // FileSystemFileHandle returns File

// fs.idl line 66
(BufferSource or Blob or USVString)? data;  // WriteParams uses Blob

// FileAPI.idl line 99
static DOMString createObjectURL((Blob or MediaSource) obj);
```

**Blocker Level**: **CRITICAL** - File System APIs return `File` objects

**Circular Note**: `FileAPI.idl` references `MediaSource` (from Media Source Extensions), creating a minor external dependency.

---

### 4. **DOM Standard** (CRITICAL - Event System & Exceptions)

**Spec**: https://dom.spec.whatwg.org/

**Types Used**:
- `EventTarget` - Base for FileReader
- `EventHandler` - Event handler attributes
- `DOMException` - Error handling

**Usage Frequency**: **MEDIUM** (10+ occurrences)

**Where Used**:
```idl
// FileAPI.idl line 55
interface FileReader: EventTarget {
  // ...
  readonly attribute DOMException? error;
  attribute EventHandler onloadstart;
  attribute EventHandler onprogress;
  attribute EventHandler onload;
  attribute EventHandler onabort;
  attribute EventHandler onerror;
  attribute EventHandler onloadend;
};
```

**From Spec Text** (fs.md):
- Line 25: `DOMException` names table referenced for error handling
- File system access results include error names from `DOMException`

**Blocker Level**: **CRITICAL** - FileReader event system and error handling broken without

---

### 5. **Storage Standard** (CRITICAL - Storage Manager Integration)

**Spec**: https://storage.spec.whatwg.org/

**Types Used**:
- `StorageManager` - Storage management interface

**Usage Frequency**: **LOW** (1 occurrence)

**Where Used**:
```idl
// fs.idl line 95
[SecureContext]
partial interface StorageManager {
  Promise<FileSystemDirectoryHandle> getDirectory();
};
```

**Blocker Level**: **CRITICAL** - Entry point to origin-private file system

**Implementation Impact**:
- Without StorageManager: Cannot access `navigator.storage.getDirectory()`
- This is **the primary API entry point** for origin-private file system
- Without this, File System API is only accessible via File System Access API (picker dialogs)

---

### 6. **Permissions API** (HIGH - File System Access)

**Spec**: https://w3c.github.io/permissions/

**Types Used**:
- `PermissionState` - Permission status enum ("granted", "denied", "prompt")
- `PermissionDescriptor` - Permission descriptor base

**Usage Frequency**: **LOW-MEDIUM** (5+ occurrences)

**Where Used**:
```idl
// file-system-access.idl lines 11-14
dictionary FileSystemPermissionDescriptor : PermissionDescriptor {
  required FileSystemHandle handle;
  FileSystemPermissionMode mode = "read";
};

// file-system-access.idl lines 22-23
partial interface FileSystemHandle {
  Promise<PermissionState> queryPermission(optional FileSystemHandlePermissionDescriptor descriptor = {});
  Promise<PermissionState> requestPermission(optional FileSystemHandlePermissionDescriptor descriptor = {});
};
```

**From Spec Text** (fs.md):
- Line 22: "A file system access result is a struct with a `PermissionState`"
- Permission queries and requests are core to File System Access API

**Blocker Level**: **HIGH** - File System Access (picker API) unusable without

**Note**: The WHATWG File System Standard (origin-private file system) doesn't strictly require permissions, but File System Access API does.

---

### 7. **HTML Standard** (MEDIUM - Integration Points)

**Spec**: https://html.spec.whatwg.org/

**Types Used**:
- `Window` - For file picker methods
- `DataTransferItem` - For drag-and-drop integration

**Usage Frequency**: **LOW** (2 occurrences)

**Where Used**:
```idl
// file-system-access.idl lines 64-68
[SecureContext]
partial interface Window {
  Promise<sequence<FileSystemFileHandle>> showOpenFilePicker(optional OpenFilePickerOptions options = {});
  Promise<FileSystemFileHandle> showSaveFilePicker(optional SaveFilePickerOptions options = {});
  Promise<FileSystemDirectoryHandle> showDirectoryPicker(optional DirectoryPickerOptions options = {});
};

// file-system-access.idl lines 70-72
partial interface DataTransferItem {
  Promise<FileSystemHandle?> getAsFileSystemHandle();
};
```

**Blocker Level**: **MEDIUM** - Only for File System Access API (picker dialogs), not core File System

**Implementation Impact**:
- Origin-private file system (via StorageManager) doesn't need Window or DataTransferItem
- File System Access API needs these for user interaction

---

### 8. **URL Standard** (MEDIUM - Object URLs)

**Spec**: https://url.spec.whatwg.org/

**Types Used**:
- `URL` interface (extended with blob URL methods)

**Usage Frequency**: **LOW** (1 occurrence)

**Where Used**:
```idl
// FileAPI.idl lines 98-101
[Exposed=(Window,DedicatedWorker,SharedWorker)]
partial interface URL {
  static DOMString createObjectURL((Blob or MediaSource) obj);
  static undefined revokeObjectURL(DOMString url);
};
```

**Blocker Level**: **MEDIUM** - Only for Blob URL creation (convenience API)

**Implementation Impact**:
- Core File System API doesn't need blob URLs
- Blob URLs enable creating temporary URLs for files (useful for `<img>`, `<video>`, etc.)

---

### 9. **Media Source Extensions** (LOW - Optional)

**Spec**: https://w3c.github.io/media-source/

**Types Used**:
- `MediaSource` - Media source object

**Usage Frequency**: **VERY LOW** (1 occurrence)

**Where Used**:
```idl
// FileAPI.idl line 99
static DOMString createObjectURL((Blob or MediaSource) obj);
```

**Blocker Level**: **LOW** - Only for media-specific blob URLs

**Implementation Impact**:
- Not needed for File System API
- Only needed if implementing full `URL.createObjectURL()` with media support

---

## Dependency Frequency Analysis

### Very High Frequency (Every API)
1. **WebIDL** - Promise, DOMString, USVString, BufferSource - Ubiquitous

### High Frequency (10+ references)
2. **Streams** - WritableStream, ReadableStream - 5+ direct references
3. **DOM** - EventTarget, EventHandler, DOMException - 10+ references

### Medium Frequency (3-10 references)
4. **File API** - Blob, File - 5+ references (internal to file system family)
5. **Permissions** - PermissionState, PermissionDescriptor - 5+ references

### Low Frequency (1-2 references)
6. **Storage** - StorageManager - 1 reference (but critical entry point)
7. **HTML** - Window, DataTransferItem - 2 references
8. **URL** - URL interface - 1 reference
9. **Media Source** - MediaSource - 1 reference

---

## Critical Types vs Optional Types

### Critical Types (MUST HAVE for core functionality)

**Streams Standard**:
- `WritableStream` - **Required for FileSystemWritableFileStream** (file writing)
- `ReadableStream` - **Required for Blob.stream()** (streaming reads)

**File API** (part of file system family):
- `Blob` - **Base type for file content**
- `File` - **Returned by FileSystemFileHandle.getFile()**
- `FileReader` - **Async file reading**

**DOM**:
- `EventTarget` - **FileReader event system**
- `EventHandler` - **Event handler attributes**
- `DOMException` - **Error handling**

**Storage**:
- `StorageManager` - **Entry point for origin-private file system**

**WebIDL**:
- `Promise<T>` - **All async operations**
- `BufferSource`, `AllowSharedBufferSource` - **Binary file content**
- String types, sequences, records - **Core type system**

### Optional Types (Can be stubbed/deferred)

**Permissions API**:
- `PermissionState`, `PermissionDescriptor` - Only for File System Access API (picker)
- Can stub with "granted" for origin-private file system

**HTML Integration**:
- `Window` - Only for file picker dialogs
- `DataTransferItem` - Only for drag-and-drop

**URL Standard**:
- `URL.createObjectURL()` - Convenience API, not core functionality

**Media Source**:
- `MediaSource` - Only for media-specific blob URLs

---

## Core File System APIs vs Edge Case APIs

### Core APIs (High Priority)

**Origin-Private File System (WHATWG File System)**:
- `navigator.storage.getDirectory()` → `FileSystemDirectoryHandle`
- `FileSystemDirectoryHandle.getFileHandle()` → `FileSystemFileHandle`
- `FileSystemFileHandle.getFile()` → `File`
- `FileSystemFileHandle.createWritable()` → `FileSystemWritableFileStream`
- `FileSystemWritableFileStream.write()` - Write to file
- Depends on: **Streams, File API, DOM, Storage, WebIDL**

**File Reading**:
- `File` / `Blob` content reading
- `Blob.stream()` → `ReadableStream`
- `Blob.text()`, `Blob.arrayBuffer()`, `Blob.bytes()` → `Promise<T>`
- `FileReader` - Event-based async reading
- Depends on: **Streams, DOM, WebIDL**

### Edge Case APIs (Lower Priority)

**File System Access API (Picker Dialogs)**:
- `window.showOpenFilePicker()` → `FileSystemFileHandle`
- `window.showSaveFilePicker()` → `FileSystemFileHandle`
- `window.showDirectoryPicker()` → `FileSystemDirectoryHandle`
- Permission queries and requests
- Depends on: **HTML, Permissions**

**Synchronous File Access (Workers Only)**:
- `FileSystemSyncAccessHandle` - Synchronous file I/O in workers
- Only available in `DedicatedWorker` context
- Lower priority (advanced use case)

**Blob URLs**:
- `URL.createObjectURL()`, `URL.revokeObjectURL()`
- Convenience API for creating temporary URLs
- Lower priority

**Drag-and-Drop Integration**:
- `DataTransferItem.getAsFileSystemHandle()`
- Nice-to-have, not core functionality

---

## Implementation Phases

### Phase 1: Core Foundation (CRITICAL - Must implement first)

**Required Specs**:
1. **Streams Standard** - WritableStream, ReadableStream
2. **File API** - Blob, File (without FileReader initially)
3. **Storage Standard** - StorageManager
4. **WebIDL Types** - Promise, BufferSource, strings

**Deliverable**: 
- Origin-private file system accessible via `navigator.storage.getDirectory()`
- File reading via `File` / `Blob` promises (text, arrayBuffer, bytes)
- File writing via `FileSystemWritableFileStream`

**APIs Enabled**:
- `FileSystemDirectoryHandle` - Directory operations
- `FileSystemFileHandle` - File operations
- `FileSystemWritableFileStream` - File writing
- `Blob.text()`, `Blob.arrayBuffer()`, `Blob.bytes()` - Simple file reading
- `Blob.stream()` - Streaming file reading

**Blocker Dependencies**:
- **Streams**: Cannot proceed without WritableStream
- **Storage**: No entry point without StorageManager

---

### Phase 2: Event-Based File Reading (HIGH Priority)

**Required Specs**:
1. **DOM Standard** - EventTarget, EventHandler, DOMException

**Deliverable**:
- `FileReader` - Event-based async file reading
- Error handling with `DOMException`

**APIs Enabled**:
- `FileReader.readAsArrayBuffer()`
- `FileReader.readAsText()`
- `FileReader.readAsDataURL()`
- Event handlers: `onload`, `onerror`, `onprogress`, etc.

---

### Phase 3: File System Access (MEDIUM Priority)

**Required Specs**:
1. **Permissions API** - PermissionState, PermissionDescriptor
2. **HTML Standard** - Window interface (partial)

**Deliverable**:
- File picker dialogs
- Permission queries and requests

**APIs Enabled**:
- `window.showOpenFilePicker()`
- `window.showSaveFilePicker()`
- `window.showDirectoryPicker()`
- `FileSystemHandle.queryPermission()`
- `FileSystemHandle.requestPermission()`

---

### Phase 4: Advanced & Integration (LOW Priority)

**Optional Specs**:
1. **URL Standard** - Blob URL creation
2. **HTML Standard** - DataTransferItem (drag-and-drop)
3. **Media Source Extensions** - MediaSource (for media blob URLs)

**Deliverable**:
- Blob URLs
- Drag-and-drop file system integration
- Synchronous file access in workers

**APIs Enabled**:
- `URL.createObjectURL()`, `URL.revokeObjectURL()`
- `DataTransferItem.getAsFileSystemHandle()`
- `FileSystemSyncAccessHandle` (workers)

---

## Spec Dependency Graph

```
File System Standard (fs.idl)
│
├─── Streams Standard (CRITICAL - HARD BLOCKER)
│    ├─── WritableStream → FileSystemWritableFileStream extends
│    └─── ReadableStream → Blob.stream() returns
│
├─── File API (CRITICAL - INTERNAL)
│    ├─── Blob → Base file content type
│    ├─── File → FileSystemFileHandle.getFile() returns
│    ├─── FileReader → Event-based file reading
│    └─── (depends on DOM for EventTarget, EventHandler)
│
├─── Storage Standard (CRITICAL - ENTRY POINT)
│    └─── StorageManager → navigator.storage.getDirectory()
│
├─── DOM Standard (CRITICAL - EVENTS & ERRORS)
│    ├─── EventTarget → FileReader extends
│    ├─── EventHandler → Event handler attributes
│    └─── DOMException → Error handling
│
├─── WebIDL (CRITICAL - TYPE SYSTEM)
│    ├─── Promise<T> → All async operations
│    ├─── BufferSource, AllowSharedBufferSource → Binary data
│    ├─── DOMString, USVString → Strings
│    └─── Extended attributes → Spec semantics
│
├─── Permissions API (HIGH - FILE SYSTEM ACCESS)
│    ├─── PermissionState → Permission status
│    └─── PermissionDescriptor → Permission queries
│
├─── HTML Standard (MEDIUM - INTEGRATION)
│    ├─── Window → File picker dialogs
│    └─── DataTransferItem → Drag-and-drop
│
├─── URL Standard (MEDIUM - CONVENIENCE)
│    └─── URL.createObjectURL() → Blob URLs
│
└─── Media Source Extensions (LOW - OPTIONAL)
     └─── MediaSource → Media blob URLs
```

---

## Comparison with HTML Standard

| Aspect | HTML Standard | File System Standard |
|--------|---------------|---------------------|
| **Complexity** | Very High | Medium |
| **External Dependencies** | 20+ specs | 8-10 specs |
| **Type References** | 150+ | ~30 |
| **Critical Dependencies** | 5 (DOM, File API, Fetch, CSSOM, WebIDL) | 5 (Streams, File API, Storage, DOM, WebIDL) |
| **Hard Blockers** | DOM (blocks everything) | Streams (blocks file writing) |
| **Self-Contained** | No (heavily integrated) | Mostly (File API + Streams) |
| **Implementation Phases** | 4+ phases | 3-4 phases |
| **Estimated Complexity** | Very High | Medium |

**Key Differences**:
1. File System has **fewer dependencies** (8-10 vs 20+)
2. File System has **one critical hard blocker** (Streams), HTML has many
3. File System is **more self-contained** (mostly File API + Streams)
4. File System has **clearer separation** (core vs access API)

---

## Implementation Recommendations

### Strategy 1: Implement Streams First (Recommended)

**Approach**: Implement WHATWG Streams Standard, then File System

**Pros**:
- Unlocks file writing API (`FileSystemWritableFileStream`)
- Streams is useful for many other specs (Fetch, etc.)
- Clean separation of concerns

**Cons**:
- Streams is a complex spec (backpressure, queuing, etc.)
- Significant upfront work

**Timeline**:
1. Implement Streams (2-4 weeks)
2. Implement File API (1 week)
3. Implement File System (1 week)
4. Total: 4-6 weeks

---

### Strategy 2: Stub Streams Initially (Faster MVP)

**Approach**: Create minimal Streams stubs, implement File System, replace later

**Pros**:
- Faster initial progress
- Can get File System API compiling quickly
- Iterative development

**Cons**:
- Stub Streams won't actually work for file writing
- Technical debt (need to replace stubs)
- May need rework when real Streams implemented

**Timeline**:
1. Create Streams stubs (1 day)
2. Implement File API (1 week)
3. Implement File System (1 week)
4. Replace Streams stubs with real implementation (2-3 weeks)
5. Total: 4-5 weeks (but with working File System sooner)

---

### Strategy 3: Implement File API Only First (Minimal)

**Approach**: Implement just File/Blob/FileReader, defer File System

**Pros**:
- Provides File and Blob types (needed by HTML)
- No Streams dependency initially
- Enables HTML `<input type="file">` support

**Cons**:
- No File System API (major feature missing)
- Still need Streams for Blob.stream()
- Limited usefulness without File System

**Timeline**:
1. Implement File API without Streams (1 week)
2. Enables HTML file inputs
3. Defer File System until Streams ready

---

## Recommended Implementation Path

**Phase 1: Core Streams** (2-3 weeks)
- Implement ReadableStream, WritableStream
- This is the hard blocker for File System

**Phase 2: File API** (1 week)
- Implement Blob, File
- Implement promise-based reading (text, arrayBuffer, bytes)
- Implement Blob.stream() (requires Streams)
- Defer FileReader (requires DOM EventTarget)

**Phase 3: Storage Integration** (1 day)
- Implement StorageManager.getDirectory()
- This is the entry point

**Phase 4: File System Core** (1 week)
- Implement FileSystemHandle, FileSystemFileHandle, FileSystemDirectoryHandle
- Implement FileSystemWritableFileStream
- Core file system now functional

**Phase 5: Event-Based Reading** (3 days)
- Implement FileReader (requires DOM EventTarget)
- Event-based file reading now available

**Phase 6: File System Access** (1 week)
- Implement file picker dialogs
- Implement permission queries
- Full File System Access API now available

**Total Estimated Time: 5-6 weeks**

---

## Summary

The File System Standard has **moderate complexity** with **8-10 type-level dependencies**. The most critical blocker is:

1. **Streams Standard** (CRITICAL - HARD BLOCKER) - Cannot implement file writing without WritableStream

Other critical dependencies:
2. **File API** (Blob, File) - Core types
3. **Storage Standard** (StorageManager) - Entry point
4. **DOM Standard** (EventTarget, DOMException) - Events and errors
5. **WebIDL** - Type system

**Recommended Path**: Implement Streams first (it's the hard blocker), then File API, then File System. This provides a clean, functional implementation with minimal technical debt.

**Complexity**: **MUCH SIMPLER than HTML** - File System has ~30 external type references vs HTML's 150+, and only one critical hard blocker (Streams) vs HTML's many.
