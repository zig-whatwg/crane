package com.whatwg.providers

/**
 * Interface for providing File System Access API functionality.
 *
 * Implement this interface to provide file system access support.
 */
interface FileSystemProvider {

    /**
     * Shows a file picker dialog.
     *
     * @param options Picker options.
     * @return List of selected file handles.
     * @throws Exception If the user cancels or access is denied.
     */
    suspend fun showOpenFilePicker(options: FilePickerOptions): List<FileHandle>

    /**
     * Shows a save file dialog.
     *
     * @param options Picker options.
     * @return A file handle for the save location.
     * @throws Exception If the user cancels or access is denied.
     */
    suspend fun showSaveFilePicker(options: FilePickerOptions): FileHandle

    /**
     * Shows a directory picker dialog.
     *
     * @param options Picker options.
     * @return A directory handle.
     * @throws Exception If the user cancels or access is denied.
     */
    suspend fun showDirectoryPicker(options: DirectoryPickerOptions): DirectoryHandle

    /**
     * Gets the origin-private file system root.
     *
     * @return The OPFS root directory handle.
     * @throws Exception If access is denied.
     */
    suspend fun getOriginPrivateDirectory(): DirectoryHandle
}

/**
 * Options for file picker dialogs.
 */
data class FilePickerOptions(
    /**
     * Allowed file types.
     */
    val types: List<FilePickerType> = emptyList(),
    
    /**
     * Whether to exclude all files option.
     */
    val excludeAcceptAllOption: Boolean = false,
    
    /**
     * Whether multiple files can be selected.
     */
    val multiple: Boolean = false,
    
    /**
     * Starting directory ID.
     */
    val startIn: String? = null
)

/**
 * A file type for the picker.
 */
data class FilePickerType(
    /**
     * Description of the file type.
     */
    val description: String? = null,
    
    /**
     * Accepted MIME types and extensions.
     */
    val accept: Map<String, List<String>>
)

/**
 * Options for directory picker dialogs.
 */
data class DirectoryPickerOptions(
    /**
     * Picker ID for persistence.
     */
    val id: String? = null,
    
    /**
     * Starting directory.
     */
    val startIn: String? = null,
    
    /**
     * Access mode.
     */
    val mode: String = "read"
)

/**
 * A handle to a file.
 */
interface FileHandle {
    /**
     * The file name.
     */
    val name: String
    
    /**
     * The file kind ("file").
     */
    val kind: String get() = "file"
    
    /**
     * Gets file contents.
     */
    suspend fun getFile(): ByteArray
    
    /**
     * Creates a writable stream.
     */
    suspend fun createWritable(): FileWritableStream
}

/**
 * A handle to a directory.
 */
interface DirectoryHandle {
    /**
     * The directory name.
     */
    val name: String
    
    /**
     * The handle kind ("directory").
     */
    val kind: String get() = "directory"
    
    /**
     * Gets a file handle within this directory.
     */
    suspend fun getFileHandle(name: String, create: Boolean = false): FileHandle
    
    /**
     * Gets a directory handle within this directory.
     */
    suspend fun getDirectoryHandle(name: String, create: Boolean = false): DirectoryHandle
    
    /**
     * Removes an entry from this directory.
     */
    suspend fun removeEntry(name: String, recursive: Boolean = false)
    
    /**
     * Lists entries in this directory.
     */
    suspend fun entries(): List<Pair<String, Any>>
}

/**
 * A writable stream for files.
 */
interface FileWritableStream : AutoCloseable {
    /**
     * Writes data to the stream.
     */
    suspend fun write(data: ByteArray)
    
    /**
     * Seeks to a position.
     */
    suspend fun seek(position: Long)
    
    /**
     * Truncates the file.
     */
    suspend fun truncate(size: Long)
}
