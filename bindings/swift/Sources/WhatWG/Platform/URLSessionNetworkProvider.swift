#if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
import Foundation
import Network

/// Network provider implementation using URLSession.
///
/// This provider uses URLSession for HTTP requests and NWPathMonitor
/// for network connectivity monitoring.
///
/// ## Example Usage
///
/// ```swift
/// let platform = WhatWGPlatform()
/// platform.networkProvider = URLSessionNetworkProvider()
/// ```
///
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public final class URLSessionNetworkProvider: NetworkProvider, @unchecked Sendable {
    
    private let session: URLSession
    private let monitor: NWPathMonitor
    private let monitorQueue: DispatchQueue
    private var currentPath: NWPath?
    
    /// Creates a new iOS network provider.
    ///
    /// - Parameter session: The URL session to use. Defaults to `URLSession.shared`.
    public init(session: URLSession = .shared) {
        self.session = session
        self.monitor = NWPathMonitor()
        self.monitorQueue = DispatchQueue(label: "com.whatwg.network.monitor")
        
        // Start monitoring network status
        monitor.pathUpdateHandler = { [weak self] path in
            self?.currentPath = path
        }
        monitor.start(queue: monitorQueue)
    }
    
    deinit {
        monitor.cancel()
    }
    
    // MARK: - NetworkProvider
    
    public func fetch(request: NetworkRequest) async throws -> NetworkResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = request.timeout
        
        // Set headers
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        // Perform request
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // Convert headers
        var headers: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            if let keyStr = key as? String, let valueStr = value as? String {
                headers[keyStr.lowercased()] = valueStr
            }
        }
        
        return NetworkResponse(
            statusCode: httpResponse.statusCode,
            headers: headers,
            body: data
        )
    }
    
    public func isOnline() -> Bool {
        return currentPath?.status == .satisfied
    }
}

// MARK: - Backwards Compatibility

/// Deprecated: Use `URLSessionNetworkProvider` instead.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(*, deprecated, renamed: "URLSessionNetworkProvider")
public typealias iOSNetworkProvider = URLSessionNetworkProvider
#endif
