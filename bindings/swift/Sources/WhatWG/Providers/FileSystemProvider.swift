import Foundation

/// Protocol for providing File System Access API functionality.
///
/// Implement this protocol to provide file system access support.
///
public protocol FileSystemProvider: AnyObject, Sendable {
    
    /// Shows a file picker dialog.
    ///
    /// - Parameter options: Picker options.
    /// - Returns: Array of selected file handles.
    /// - Throws: If the user cancels or access is denied.
    func showOpenFilePicker(options: FilePickerOptions) async throws -> [FileHandle]
    
    /// Shows a save file dialog.
    ///
    /// - Parameter options: Picker options.
    /// - Returns: A file handle for the save location.
    /// - Throws: If the user cancels or access is denied.
    func showSaveFilePicker(options: FilePickerOptions) async throws -> FileHandle
    
    /// Shows a directory picker dialog.
    ///
    /// - Parameter options: Picker options.
    /// - Returns: A directory handle.
    /// - Throws: If the user cancels or access is denied.
    func showDirectoryPicker(options: DirectoryPickerOptions) async throws -> DirectoryHandle
    
    /// Gets the origin-private file system root.
    ///
    /// - Returns: The OPFS root directory handle.
    /// - Throws: If access is denied.
    func getOriginPrivateDirectory() async throws -> DirectoryHandle
}

/// Options for file picker dialogs.
public struct FilePickerOptions: Sendable {
    /// Allowed file types.
    public var types: [FilePickerType]
    
    /// Whether to exclude all files option.
    public var excludeAcceptAllOption: Bool
    
    /// Whether multiple files can be selected.
    public var multiple: Bool
    
    /// Starting directory ID.
    public var startIn: String?
    
    public init(
        types: [FilePickerType] = [],
        excludeAcceptAllOption: Bool = false,
        multiple: Bool = false,
        startIn: String? = nil
    ) {
        self.types = types
        self.excludeAcceptAllOption = excludeAcceptAllOption
        self.multiple = multiple
        self.startIn = startIn
    }
}

/// A file type for the picker.
public struct FilePickerType: Sendable {
    /// Description of the file type.
    public var description: String?
    
    /// Accepted MIME types and extensions.
    public var accept: [String: [String]]
    
    public init(description: String? = nil, accept: [String: [String]]) {
        self.description = description
        self.accept = accept
    }
}

/// Options for directory picker dialogs.
public struct DirectoryPickerOptions: Sendable {
    /// Picker ID for persistence.
    public var id: String?
    
    /// Starting directory.
    public var startIn: String?
    
    /// Access mode.
    public var mode: String
    
    public init(id: String? = nil, startIn: String? = nil, mode: String = "read") {
        self.id = id
        self.startIn = startIn
        self.mode = mode
    }
}

/// A handle to a file.
public protocol FileHandle: AnyObject, Sendable {
    /// The file name.
    var name: String { get }
    
    /// The file kind ("file").
    var kind: String { get }
    
    /// Gets a File object for reading.
    func getFile() async throws -> Data
    
    /// Creates a writable stream.
    func createWritable() async throws -> FileWritableStream
}

/// A handle to a directory.
public protocol DirectoryHandle: AnyObject, Sendable {
    /// The directory name.
    var name: String { get }
    
    /// The handle kind ("directory").
    var kind: String { get }
    
    /// Gets a file handle within this directory.
    func getFileHandle(name: String, create: Bool) async throws -> FileHandle
    
    /// Gets a directory handle within this directory.
    func getDirectoryHandle(name: String, create: Bool) async throws -> DirectoryHandle
    
    /// Removes an entry from this directory.
    func removeEntry(name: String, recursive: Bool) async throws
    
    /// Lists entries in this directory.
    func entries() async throws -> [(String, Any)]
}

/// A writable stream for files.
public protocol FileWritableStream: AnyObject, Sendable {
    /// Writes data to the stream.
    func write(_ data: Data) async throws
    
    /// Seeks to a position.
    func seek(position: UInt64) async throws
    
    /// Truncates the file.
    func truncate(size: UInt64) async throws
    
    /// Closes the stream.
    func close() async throws
}
