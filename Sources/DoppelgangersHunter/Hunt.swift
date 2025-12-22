#if os(iOS)
#else
import FileType
import Foundation

public struct Doppelganger: Decodable {
    public let path: String
    public let previewable: Bool
}

public struct Doppelgangers: Decodable {
    let hash: Int64
    private(set) public var files: [Doppelganger]

    fileprivate init(hash: Int64, files: [File]) {
        self.hash = hash
        self.files = files.map { Doppelganger(path: $0.path, previewable: $0.previewable) }
    }

    fileprivate mutating func append(file: File) {
        self.files.append(Doppelganger(path: file.path, previewable: file.previewable))
    }

    fileprivate mutating func remove(paths: Set<String>) {
        self.files.removeAll(where: { !paths.contains($0.path)})
    }
}

private typealias File = (path: String, hash: Int64, previewable: Bool)

public struct Hunt {
    
    public init() {}

    @discardableResult
    public func hunt(url: URL, skipsHiddenFiles: Bool = false) async-> [Doppelgangers] {
        let traverseResult = url.traverse(skipsHiddenFiles: skipsHiddenFiles)
        var duplicatesByHash: [Doppelgangers] = []

        _ = await withTaskGroup(of: File?.self) { group in
            for path in traverseResult.paths {
                group.addTask {
                    guard let content = FileManager.default.contents(atPath: path) else {
                        print("Не удалось прочитать файл \(path)")
                        return nil
                    }

                    return (
                        path: path,
                        hash: Int64(content.hashValue),
                        previewable: content.previewable
                    )
                }
            }

            var inMemoryHashesTable = [Int64: File]()

            for await file in group {
                guard let file else { continue }

                if let existedFileWithSameHash = inMemoryHashesTable[file.hash] {
                    if let potentialDuplicatesIndex = duplicatesByHash.firstIndex(where: { $0.hash == file.hash }) {
                        duplicatesByHash[potentialDuplicatesIndex].append(file: file)
                    } else {
                        duplicatesByHash.append(Doppelgangers(hash: file.hash, files: [file, existedFileWithSameHash]))
                    }
                } else {
                    inMemoryHashesTable[file.hash] = file
                }
            }

            _ = await withTaskGroup(of: (Int64, Set<String>).self) { group in
                for doppelgangers in duplicatesByHash {
                    let paths = doppelgangers.files.map { $0.path }
                    let hash = doppelgangers.hash
                    group.addTask {
                        var contents = [Data:String]()
                        var duplicatesPaths = Set<String>()

                        for path in paths {
                            if let content = FileManager.default.contents(atPath: path) {
                                if let alreadyExistedPath = contents[content] {
                                    duplicatesPaths.insert(alreadyExistedPath)
                                    duplicatesPaths.insert(path)
                                } else {
                                    contents[content] = path
                                }
                            }
                        }

                        return (hash, duplicatesPaths)
                    }
                }

                for await duplicatesPaths in group {
                    if let potentialDuplicatesIndex = duplicatesByHash.firstIndex(where: { $0.hash == duplicatesPaths.0 }) {
                        duplicatesByHash[potentialDuplicatesIndex].remove(paths: duplicatesPaths.1)
                        if duplicatesByHash[potentialDuplicatesIndex].files.isEmpty {
                            duplicatesByHash.remove(at: potentialDuplicatesIndex)
                        }
                    }
                }
            }
        }

        return duplicatesByHash
    }
}

extension URL {

    private static let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .nameKey]

    @usableFromInline
    static let resourceKeysSet: Set<URLResourceKey> = Set(resourceKeys)

    @inlinable
    func resourceValues() throws -> URLResourceValues {
        try resourceValues(forKeys: URL.resourceKeysSet)
    }

    func enumerator(skipsHiddenFiles: Bool) -> FileManager.DirectoryEnumerator? {
        FileManager.default.enumerator(
            at: self,
            includingPropertiesForKeys: URL.resourceKeys,
            options: skipsHiddenFiles ? [.skipsHiddenFiles] : []
        )
    }

    func traverse(skipsHiddenFiles: Bool) -> (maxPathLength: Int, paths: [String]) {
        var maxPathLength = 0

        let paths =
        enumerator(skipsHiddenFiles: skipsHiddenFiles)?
            .compactMap { $0 as? URL }
            .filter {
                do {
                    return try $0.resourceValues().isDirectory == false
                } catch {
                    print("Ошибка при обработке файла \($0.absoluteString)")
                    return false
                }
            }
            .map {
                if $0.path.count > maxPathLength {
                    maxPathLength = $0.path.count
                }
                return $0.path
            } ?? [String]()
        return (maxPathLength: maxPathLength, paths: paths)
    }
}

extension [String] {
    func batchDuplicates() -> [[(String, Data)]] {
        compactMap { path in
            return if let content = FileManager.default.contents(atPath: path) {
                (path: path, content: content)
            } else { nil }
        }
        .reduce(into: [[(String, Data)]]()) { result, element in
            if let index = result.firstIndex(where: { $0.contains(where: { element.content == $1 }) }) {
                result[index].append(element)
            } else {
                result.append([element])
            }
        }
    }
}

extension Data {
    
    private static let previewableMimePrefixes: Set<String> = ["video", "image"]
    
    var previewable: Bool {
        // "video" или "audio"
        guard let mimePrefix = FileType.mimeType(data: self)?.mime.prefix(5) else {
            return false
        }
        return Data.previewableMimePrefixes.contains(String(mimePrefix))
    }
}
#endif
