import Foundation

/// Protocol for providing timer functionality.
///
/// Implement this protocol to provide setTimeout/setInterval support.
/// The default implementation uses GCD (Grand Central Dispatch).
///
public protocol TimerProvider: AnyObject, Sendable {
    
    /// Schedules a one-time callback.
    ///
    /// - Parameters:
    ///   - delay: Delay in milliseconds.
    ///   - callback: The callback to invoke.
    /// - Returns: A timer ID that can be used to cancel.
    func setTimeout(delay: UInt32, callback: @escaping @Sendable () -> Void) -> UInt64
    
    /// Schedules a repeating callback.
    ///
    /// - Parameters:
    ///   - interval: Interval in milliseconds.
    ///   - callback: The callback to invoke.
    /// - Returns: A timer ID that can be used to cancel.
    func setInterval(interval: UInt32, callback: @escaping @Sendable () -> Void) -> UInt64
    
    /// Cancels a timeout.
    ///
    /// - Parameter id: The timer ID returned by `setTimeout`.
    func clearTimeout(id: UInt64)
    
    /// Cancels an interval.
    ///
    /// - Parameter id: The timer ID returned by `setInterval`.
    func clearInterval(id: UInt64)
}
