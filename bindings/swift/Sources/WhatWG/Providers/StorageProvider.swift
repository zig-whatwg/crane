import Foundation

/// Protocol for providing storage functionality (localStorage/sessionStorage).
///
/// Implement this protocol to provide key-value storage support.
///
public protocol StorageProvider: AnyObject, Sendable {
    
    /// Gets a value from storage.
    ///
    /// - Parameter key: The key to retrieve.
    /// - Returns: The value, or `nil` if not found.
    func getItem(key: String) async throws -> String?
    
    /// Sets a value in storage.
    ///
    /// - Parameters:
    ///   - key: The key to set.
    ///   - value: The value to store.
    /// - Throws: If storage is full or denied.
    func setItem(key: String, value: String) async throws
    
    /// Removes a value from storage.
    ///
    /// - Parameter key: The key to remove.
    func removeItem(key: String) async throws
    
    /// Clears all storage.
    func clear() async throws
    
    /// Returns the number of items in storage.
    func length() async throws -> Int
    
    /// Returns the key at the given index.
    ///
    /// - Parameter index: The index.
    /// - Returns: The key, or `nil` if out of bounds.
    func key(at index: Int) async throws -> String?
}
