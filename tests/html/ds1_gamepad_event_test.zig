//! GamepadEvent uses DOM's Event constructor and inner event creation steps.
const helpers = @import("edges_node_holders_helpers.zig");

fn inheritedEventState() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const before = performance.now();
        \\const event = new GamepadEvent('gamepadconnected', {
        \\  bubbles: true, cancelable: true, composed: true
        \\});
        \\const after = performance.now();
        \\if (event.type !== 'gamepadconnected') throw new Error('Event type not initialized');
        \\if (event.timeStamp < before || event.timeStamp > after)
        \\  throw new Error('Event timestamp is outside its construction interval');
        \\if (!event.bubbles || !event.cancelable || !event.composed)
        \\  throw new Error('EventInit members not initialized');
        \\if (event.isTrusted) throw new Error('script event must be untrusted');
        \\let received = null;
        \\const target = new EventTarget();
        \\target.addEventListener('gamepadconnected', e => {
        \\  received = e;
        \\  e.preventDefault();
        \\});
        \\if (target.dispatchEvent(event)) throw new Error('cancelation not reflected');
        \\if (received !== event) throw new Error('event not delivered');
        \\const defaults = new GamepadEvent('disconnected');
        \\if (defaults.type !== 'disconnected' || defaults.bubbles || defaults.cancelable || defaults.composed)
        \\  throw new Error('EventInit defaults not applied');
    );
}

test "GamepadEvent initializes inherited state and can be dispatched" {
    try helpers.onFreshThread(inheritedEventState);
}
