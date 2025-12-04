#if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
import Foundation

/// Timer provider implementation using GCD (Grand Central Dispatch).
///
/// This provider uses DispatchSourceTimer for precise timing.
/// Timers are executed on a background queue by default.
///
/// ## Example Usage
///
/// ```swift
/// let platform = WhatWGPlatform()
/// platform.timerProvider = DispatchTimerProvider()
/// ```
///
public final class DispatchTimerProvider: TimerProvider, @unchecked Sendable {
    
    private let queue: DispatchQueue
    private var timers: [UInt64: DispatchSourceTimer] = [:]
    private var nextId: UInt64 = 1
    private let lock = NSLock()
    
    /// Creates a new iOS timer provider.
    ///
    /// - Parameter queue: The dispatch queue for timer callbacks. Defaults to a background queue.
    public init(queue: DispatchQueue = DispatchQueue(label: "com.whatwg.timers", qos: .userInitiated)) {
        self.queue = queue
    }
    
    // MARK: - TimerProvider
    
    public func setTimeout(delay: UInt32, callback: @escaping @Sendable () -> Void) -> UInt64 {
        let id = generateId()
        
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .milliseconds(Int(delay)))
        timer.setEventHandler { [weak self] in
            callback()
            self?.clearTimeout(id: id)
        }
        
        lock.lock()
        timers[id] = timer
        lock.unlock()
        
        timer.resume()
        
        return id
    }
    
    public func setInterval(interval: UInt32, callback: @escaping @Sendable () -> Void) -> UInt64 {
        let id = generateId()
        
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(
            deadline: .now() + .milliseconds(Int(interval)),
            repeating: .milliseconds(Int(interval))
        )
        timer.setEventHandler {
            callback()
        }
        
        lock.lock()
        timers[id] = timer
        lock.unlock()
        
        timer.resume()
        
        return id
    }
    
    public func clearTimeout(id: UInt64) {
        clearTimer(id: id)
    }
    
    public func clearInterval(id: UInt64) {
        clearTimer(id: id)
    }
    
    // MARK: - Private
    
    private func generateId() -> UInt64 {
        lock.lock()
        let id = nextId
        nextId += 1
        lock.unlock()
        return id
    }
    
    private func clearTimer(id: UInt64) {
        lock.lock()
        if let timer = timers.removeValue(forKey: id) {
            timer.cancel()
        }
        lock.unlock()
    }
}

// MARK: - Backwards Compatibility

/// Deprecated: Use `DispatchTimerProvider` instead.
@available(*, deprecated, renamed: "DispatchTimerProvider")
public typealias iOSTimerProvider = DispatchTimerProvider
#endif
