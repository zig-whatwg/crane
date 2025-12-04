import Foundation

/// Protocol for providing network/fetch functionality.
///
/// Implement this protocol to provide HTTP request support.
/// The default implementation uses URLSession.
///
public protocol NetworkProvider: AnyObject, Sendable {
    
    /// Performs an HTTP request.
    ///
    /// - Parameter request: The request configuration.
    /// - Returns: The response.
    /// - Throws: If the request fails.
    func fetch(request: NetworkRequest) async throws -> NetworkResponse
    
    /// Checks if the device is online.
    ///
    /// - Returns: `true` if network is available.
    func isOnline() -> Bool
}

/// Configuration for a network request.
public struct NetworkRequest: Sendable {
    /// The request URL.
    public var url: URL
    
    /// The HTTP method.
    public var method: String
    
    /// Request headers.
    public var headers: [String: String]
    
    /// Request body.
    public var body: Data?
    
    /// Request timeout in seconds.
    public var timeout: TimeInterval
    
    /// Creates a new network request.
    public init(
        url: URL,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 30
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }
}

/// Response from a network request.
public struct NetworkResponse: Sendable {
    /// HTTP status code.
    public var statusCode: Int
    
    /// Response headers.
    public var headers: [String: String]
    
    /// Response body.
    public var body: Data
    
    /// Creates a new network response.
    public init(statusCode: Int, headers: [String: String], body: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}
