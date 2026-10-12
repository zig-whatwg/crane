//! Each Browser's network is its own (instances B3): two Browsers on two
//! threads at once, each with its own options, never share what the network
//! keeps for a profile - the TLS trust its requests are verified with, the
//! connection share its transfers join, WebSocket's CONNECTING gate - and
//! each agent's fetches are pumped by that agent's loop alone.
//!
//! Before, all of it was the process's or the thread's: one trust store the
//! host set for every Browser (fetch.network.setDefaultCertOptions), one curl
//! share every Browser reused connections from, one scheduler and fetch list
//! per thread, one handshake gate per thread.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const dom = @import("dom");
const fetch = @import("fetch");

const refused_url = "http://127.0.0.1:65533/inst5";

const Shared = struct {
    arrived: std.atomic.Value(u32) = .init(0),
    /// Each Browser's network context, for the other to compare.
    networks: [2]std.atomic.Value(?*fetch.network.NetworkContext) = .{ .init(null), .init(null) },

    fn meet(self: *Shared, point: u32) !void {
        _ = self.arrived.fetchAdd(1, .acq_rel);
        var spins: usize = 0;
        while (self.arrived.load(.acquire) < 2 * point) : (spins += 1) {
            if (spins > 20_000_000) return error.TheOtherBrowserNeverArrived;
            std.Thread.yield() catch {};
        }
    }
};

const Side = struct {
    index: usize,
    shared: *Shared,
    failure: ?anyerror = null,

    fn run(self: *Side) void {
        self.steps() catch |err| {
            self.failure = err;
            _ = self.shared.arrived.fetchAdd(4, .acq_rel);
        };
    }

    /// Browser 0 trusts a certificate authority of its own; Browser 1 the
    /// system's alone.
    fn caPath(self: *const Side) ?[]const u8 {
        return if (self.index == 0) "/inst5/certs/a.pem" else null;
    }

    fn steps(self: *Side) !void {
        const shared = self.shared;
        const browser = try browser_mod.Browser.init(testing.allocator, .{
            .persist_storage = false,
            .snapshot_path = "",
            .ca_bundle_path = self.caPath(),
        });
        defer browser.deinit();
        try browser.navigateWithOptions("http://inst5.test/page.html", .window, .{ .skip_load = true });
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body><iframe></iframe></body>", .{ .base_url = "http://inst5.test/page.html" });
        const window = page.window_instance orelse return error.NoWindow;

        // The page's realm reaches its Browser's network context - the same
        // one its request carries - and its trust is its Browser's.
        const network = dom.browser_state.networkOf(window.ctx) orelse return error.NoNetwork;
        if (self.caPath()) |path| {
            try testing.expectEqualStrings(path, network.certOptions().ca_bundle_path orelse return error.NoTrust);
        } else {
            try testing.expectEqual(@as(?[]const u8, null), network.certOptions().ca_bundle_path);
        }
        var client = try dom.global_settings.requestClient(window);
        defer client.deinit();
        try testing.expectEqual(network, client.request.network.?);
        shared.networks[self.index].store(network, .release);

        // Each Browser's CONNECTING gate is its own: both take the same host
        // and port at once.
        var holder: u8 = 0;
        var other_holder: u8 = 0;
        try testing.expect(try network.tryAcquireConnecting("inst5.test:80", &holder));
        try shared.meet(1);
        try testing.expect(!try network.tryAcquireConnecting("inst5.test:80", &other_holder));
        const other = shared.networks[1 - self.index].load(.acquire) orelse return error.NoOtherNetwork;
        try testing.expect(other != network);

        // A fetch the page starts is on its own agent's fetches - pumped by
        // its own loop - while the other Browser's are its own.
        const fetches = &browser.agent_host.fetches;
        const before = fetches.inFlight();
        try page.runScript("globalThis.r = new XMLHttpRequest(); r.open('GET', '" ++ refused_url ++ "'); r.send();");
        try testing.expectEqual(before + 1, fetches.inFlight());
        try shared.meet(2);
        var turns: usize = 0;
        while (fetches.inFlight() != before and turns < 200) : (turns += 1) {
            _ = try browser.runEventLoopBlocking(10);
        }
        try testing.expectEqual(before, fetches.inFlight());
        try shared.meet(3);
        network.releaseConnecting(&holder);
    }
};

test "two Browsers on two threads have networks of their own: trust, connections, gate and fetches" {
    var shared: Shared = .{};
    var sides = [_]Side{ .{ .index = 0, .shared = &shared }, .{ .index = 1, .shared = &shared } };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*thread, *side| thread.* = try std.Thread.spawn(.{}, Side.run, .{side});
    for (threads) |thread| thread.join();
    for (sides) |side| if (side.failure) |err| return err;
}
