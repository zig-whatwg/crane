//! The HTTP cache of one Browser (RFC 9111; Fetch 2.8 "determine the HTTP
//! cache partition"): every partition's stored responses, in memory.
//!
//! Owned by the Browser's network context (`NetworkContext.http_cache`, made
//! by `configure` from BrowserConfig.http_cache) and so shared by every agent
//! and thread of that Browser and by no other Browser - Chromium's
//! network::NetworkContext owns its net::HttpCache the same way. A request
//! reaches it through the network context it carries.
//!
//! One stored response per key, the key being Fetch's network partition key
//! (the partition: "the unique HTTP cache associated with key") and the URL
//! without its fragment. GET only. Chrome 155, Firefox 158 and Safari 27 all
//! keep one response per URL: each fails fetch/http-cache/vary.any.html
//! "HTTP cache doesn't invalidate existing Vary response" (wpt.fyi
//! 23b0b89b1a), which needs two variants side by side - so a response that
//! varies replaces the one stored (golden rule 2: the browsers agree).
//!
//! Threads: one mutex guards the map, the LRU list and the byte count - no
//! allocation, copy or parse happens under it but the map insert. Stored
//! responses are immutable once published and reference-counted: `lookup`
//! hands out a reference taken under the lock, read outside it; a response
//! replaced or evicted while read stays alive until its reader releases it.
//!
//! The core is reference-counted too: the network context holds one
//! reference and each body writer still collecting a body (transaction.zig)
//! one more, so a writer that ends after the Browser's network did (a body
//! pipe can outlive its fetch while script holds the Response) finds the
//! cache closed and drops its response - no teardown order is assumed.
//!
//! Limits (Config): `max_bytes` (default 50 MiB, Chromium's in-memory
//! backend's cap - MemBackendImpl, kMaxMemoryCacheSize; Firefox's automatic
//! memory capacity caps at 32 MiB) and an entry cap of an eighth of it
//! (Chromium MemBackendImpl::MaxFileSize, max_size_ / 8; Gecko's
//! EntryIsTooBig derives the same eighth). Least recently used responses go
//! first, down to 90% of the cap (MemBackendImpl::EvictIfNeeded: "Evict 10%
//! more than necessary to avoid evicting on every insertion").

const std = @import("std");
const Allocator = std.mem.Allocator;
const StoredResponse = @import("stored_response.zig").StoredResponse;

pub const Config = struct {
    /// The cap on everything stored, in bytes. 0: no HTTP cache at all.
    max_bytes: usize = 50 * 1024 * 1024,
    /// The cap on one stored response; null: max_bytes / 8.
    max_entry_bytes: ?usize = null,
};

/// The cache key's URL: the URL with its fragment removed (a fragment is
/// never sent; RFC 9111 4's "target URI").
pub fn keyUrl(url: []const u8) []const u8 {
    return url[0 .. std.mem.indexOfScalar(u8, url, '#') orelse url.len];
}

pub const HttpCache = struct {
    allocator: Allocator,
    config: Config,
    refs: std.atomic.Value(u32) = .init(1),
    mutex: std.Io.Mutex = .init,
    /// Under `mutex`: the owner closed it.
    closed: bool = false,
    map: std.HashMapUnmanaged(Key, *Node, KeyContext, 80) = .empty,
    /// Most recently used first.
    lru_head: ?*Node = null,
    lru_tail: ?*Node = null,
    /// Under `mutex`: the sizes of the stored responses.
    bytes: usize = 0,
    /// How many responses are stored: read without the lock, so a lookup in
    /// an empty cache takes none.
    count: std.atomic.Value(usize) = .init(0),

    const Key = struct {
        partition: []const u8,
        url: []const u8,
    };

    const KeyContext = struct {
        pub fn hash(_: KeyContext, key: Key) u64 {
            var h = std.hash.Wyhash.init(0);
            std.hash.autoHash(&h, key.partition.len);
            h.update(key.partition);
            h.update(key.url);
            return h.final();
        }
        pub fn eql(_: KeyContext, a: Key, b: Key) bool {
            return std.mem.eql(u8, a.partition, b.partition) and std.mem.eql(u8, a.url, b.url);
        }
    };

    const Node = struct {
        entry: *StoredResponse,
        prev: ?*Node = null,
        next: ?*Node = null,
    };

    pub fn create(allocator: Allocator, config: Config) Allocator.Error!*HttpCache {
        const self = try allocator.create(HttpCache);
        self.* = .{ .allocator = allocator, .config = config };
        return self;
    }

    /// One more holder of the core (a body writer).
    pub fn retain(self: *HttpCache) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }

    /// A holder is done; the last frees the core.
    pub fn release(self: *HttpCache) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        std.debug.assert(self.map.count() == 0);
        self.map.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// The owner's end: every stored response goes, nothing is stored from
    /// here, and the owner's reference is dropped.
    pub fn close(self: *HttpCache) void {
        var gone: ?*Node = null;
        {
            lock(self);
            defer unlock(self);
            self.closed = true;
            gone = self.lru_head;
            self.lru_head = null;
            self.lru_tail = null;
            self.map.clearRetainingCapacity();
            self.bytes = 0;
            self.count.store(0, .release);
        }
        freeNodes(self.allocator, gone);
        self.release();
    }

    pub fn maxEntryBytes(self: *const HttpCache) usize {
        return self.config.max_entry_bytes orelse self.config.max_bytes / 8;
    }

    pub fn entryCount(self: *const HttpCache) usize {
        return self.count.load(.acquire);
    }

    pub fn byteCount(self: *HttpCache) usize {
        lock(self);
        defer unlock(self);
        return self.bytes;
    }

    /// The response stored for (`partition`, `url`) - the URL as `keyUrl`
    /// gives it - with a reference the caller releases; null when there is
    /// none. Marks it most recently used. Allocates nothing.
    pub fn lookup(self: *HttpCache, partition: []const u8, url: []const u8) ?*StoredResponse {
        if (self.entryCount() == 0) return null;
        lock(self);
        defer unlock(self);
        const node = self.map.get(.{ .partition = partition, .url = url }) orelse return null;
        self.moveToFront(node);
        node.entry.retain();
        return node.entry;
    }

    /// Store `entry` (its one reference taken), replacing what its key has,
    /// then evict the least recently used responses past the cap. A response
    /// over the entry cap, or a cache closed, keeps nothing.
    pub fn publish(self: *HttpCache, entry: *StoredResponse) void {
        self.insert(entry, null);
    }

    /// RFC 9111 4.3.4: `updated`, a 304's freshening of `old`, takes `old`'s
    /// place - if `old` is still the response its key has. Another stored
    /// since is newer, and is kept. (`updated`'s reference is taken.)
    pub fn replace(self: *HttpCache, old: *const StoredResponse, updated: *StoredResponse) void {
        self.insert(updated, old);
    }

    fn insert(self: *HttpCache, entry: *StoredResponse, only_if: ?*const StoredResponse) void {
        if (entry.size > self.maxEntryBytes() or entry.size > self.config.max_bytes) return entry.release();
        const node = self.allocator.create(Node) catch return entry.release();
        node.* = .{ .entry = entry };
        var replaced: ?*StoredResponse = null;
        var evicted: ?*Node = null;
        defer {
            if (replaced) |r| r.release();
            freeNodes(self.allocator, evicted);
        }
        lock(self);
        defer unlock(self);
        if (self.closed) {
            self.allocator.destroy(node);
            return entry.release();
        }
        const key: Key = .{ .partition = entry.partition, .url = entry.url };
        if (self.map.get(key)) |existing| {
            if (only_if) |old| if (existing.entry != old) {
                self.allocator.destroy(node);
                return entry.release();
            };
            // The node stays; its entry - and the key's strings - are the
            // new one's.
            self.allocator.destroy(node);
            replaced = existing.entry;
            self.bytes -= existing.entry.size;
            existing.entry = entry;
            self.map.getKeyPtr(key).?.* = key;
            self.bytes += entry.size;
            self.moveToFront(existing);
        } else {
            self.map.put(self.allocator, key, node) catch {
                self.allocator.destroy(node);
                return entry.release();
            };
            self.pushFront(node);
            self.bytes += entry.size;
            _ = self.count.fetchAdd(1, .release);
        }
        if (self.bytes > self.config.max_bytes) evicted = self.evictTo(self.config.max_bytes - self.config.max_bytes / 10);
    }

    /// RFC 9111 4.4: remove what the partition stores for `url`.
    pub fn invalidate(self: *HttpCache, partition: []const u8, url: []const u8) void {
        if (self.entryCount() == 0) return;
        var gone: ?*Node = null;
        {
            lock(self);
            defer unlock(self);
            if (self.map.fetchRemove(.{ .partition = partition, .url = url })) |kv| {
                self.unlink(kv.value);
                kv.value.next = null;
                gone = kv.value;
            }
        }
        freeNodes(self.allocator, gone);
    }

    /// Remove every response, in every partition, whose URL's origin is the
    /// serialized `origin` (Clear Site Data's "cache" type; its caller says
    /// whose rule).
    pub fn clearOrigin(self: *HttpCache, origin: []const u8) void {
        if (self.entryCount() == 0) return;
        var gone: ?*Node = null;
        {
            lock(self);
            defer unlock(self);
            var node = self.lru_head;
            while (node) |n| {
                node = n.next;
                if (!sameOrigin(n.entry.url, origin)) continue;
                _ = self.map.remove(.{ .partition = n.entry.partition, .url = n.entry.url });
                self.unlink(n);
                n.next = gone;
                gone = n;
            }
        }
        freeNodes(self.allocator, gone);
    }

    /// Under the lock: unlink from the cold end until `target` bytes remain;
    /// the nodes come back chained through `next`, freed after the unlock.
    fn evictTo(self: *HttpCache, target: usize) ?*Node {
        var gone: ?*Node = null;
        while (self.bytes > target) {
            const node = self.lru_tail orelse break;
            _ = self.map.remove(.{ .partition = node.entry.partition, .url = node.entry.url });
            self.unlink(node);
            node.next = gone;
            gone = node;
        }
        return gone;
    }

    fn unlink(self: *HttpCache, node: *Node) void {
        if (node.prev) |p| p.next = node.next else self.lru_head = node.next;
        if (node.next) |n| n.prev = node.prev else self.lru_tail = node.prev;
        node.prev = null;
        node.next = null;
        self.bytes -= node.entry.size;
        _ = self.count.fetchSub(1, .release);
    }

    fn pushFront(self: *HttpCache, node: *Node) void {
        node.prev = null;
        node.next = self.lru_head;
        if (self.lru_head) |h| h.prev = node;
        self.lru_head = node;
        if (self.lru_tail == null) self.lru_tail = node;
    }

    fn moveToFront(self: *HttpCache, node: *Node) void {
        if (self.lru_head == node) return;
        if (node.prev) |p| p.next = node.next;
        if (node.next) |n| n.prev = node.prev else self.lru_tail = node.prev;
        self.pushFront(node);
    }

    /// Free a chain of nodes (through `next`) and release their responses.
    fn freeNodes(allocator: Allocator, first: ?*Node) void {
        var node = first;
        while (node) |n| {
            node = n.next;
            n.entry.release();
            allocator.destroy(n);
        }
    }

    fn lock(self: *HttpCache) void {
        std.Io.Threaded.mutexLock(&self.mutex);
    }

    fn unlock(self: *HttpCache) void {
        std.Io.Threaded.mutexUnlock(&self.mutex);
    }
};

/// Whether the serialized `url`'s origin is the serialized `origin`: scheme,
/// host and port, a default port (80 for http, 443 for https) equal to none.
fn sameOrigin(url: []const u8, origin: []const u8) bool {
    const a = originParts(url) orelse return false;
    const b = originParts(origin) orelse return false;
    return std.ascii.eqlIgnoreCase(a.scheme, b.scheme) and std.ascii.eqlIgnoreCase(a.host, b.host) and a.port == b.port;
}

const OriginParts = struct { scheme: []const u8, host: []const u8, port: u16 };

fn originParts(url: []const u8) ?OriginParts {
    const sep = std.mem.indexOf(u8, url, "://") orelse return null;
    const scheme = url[0..sep];
    const rest = url[sep + 3 ..];
    const end = std.mem.indexOfAny(u8, rest, "/?#") orelse rest.len;
    var authority = rest[0..end];
    if (std.mem.lastIndexOfScalar(u8, authority, '@')) |at| authority = authority[at + 1 ..];
    var host = authority;
    var port: u16 = if (std.ascii.eqlIgnoreCase(scheme, "https")) 443 else if (std.ascii.eqlIgnoreCase(scheme, "http")) 80 else 0;
    // A port follows the last colon that is past an IPv6 literal's bracket.
    if (std.mem.lastIndexOfScalar(u8, authority, ':')) |colon| {
        const bracket = std.mem.lastIndexOfScalar(u8, authority, ']');
        if (bracket == null or colon > bracket.?) {
            host = authority[0..colon];
            port = std.fmt.parseInt(u16, authority[colon + 1 ..], 10) catch return null;
        }
    }
    return .{ .scheme = scheme, .host = host, .port = port };
}
