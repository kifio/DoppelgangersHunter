#if os(iOS)
#else
import Foundation

public struct Hunt {
    
    public init() {}

    public struct Duplicates: Decodable {
        let hash: Int64
        private(set) public var paths: [String]

        public init(hash: Int64, paths: [String]) {
            self.hash = hash
            self.paths = paths
        }

        mutating func append(path: String) {
            self.paths.append(path)
        }

        mutating func remove(paths: Set<String>) {
            self.paths.removeAll(where: { !paths.contains($0)})
        }
    }

    @discardableResult
    public func hunt(url: URL, skipsHiddenFiles: Bool = false, useSQLite: Bool = false) async-> [Duplicates] {
        let traverseResult = url.traverse(skipsHiddenFiles: skipsHiddenFiles)
        var duplicatesByHash: [Duplicates] = []

        _ = await withTaskGroup(of: (path: String, hash: Int64)?.self) { group in
            for path in traverseResult.paths {
                group.addTask {
                    return if let hash = await computeHash(for: path) {
                        (path: path, hash: hash)
                    } else { nil }
                }
            }

            var sqliteHashesTable: [String: Int64]? = useSQLite ? [:] : nil
            var inMemoryHashesTable: [Int64: String]? = useSQLite ? nil : [:]

            for await hashWithPath in group {
                guard let path = hashWithPath?.path, let hash = hashWithPath?.hash else {
                    continue
                }

                if useSQLite {
                    sqliteHashesTable?[path] = hash
                } else {
                    if let existedPathWithSameHash = inMemoryHashesTable![hash] {
                        handlePotentialDuplicate(path, hash, &duplicatesByHash) {
                            Duplicates(hash: hash, paths: [path, existedPathWithSameHash])
                        }
                    } else {
                        inMemoryHashesTable?[hash] = path
                    }
                }
            }

            if
                let sqliteHashesTable,
                let databaseHelper = DatabaseHelper(maxPathLength: traverseResult.maxPathLength)
            {
                databaseHelper.saveToDatabase(hashesTable: sqliteHashesTable)

                let duplicatesHashesTable = databaseHelper.queryDuplicates()
                databaseHelper.closeAndDeleteDatabase()

                duplicatesHashesTable.forEach { path, hash in
                    handlePotentialDuplicate(path, hash, &duplicatesByHash) {
                        Duplicates(hash: hash, paths: [path])
                    }
                }
            }

            _ = await withTaskGroup(of: (Int64, Set<String>).self) { group in
                for duplicates in duplicatesByHash {
                    let paths = duplicates.paths
                    let hash = duplicates.hash
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
                        if duplicatesByHash[potentialDuplicatesIndex].paths.isEmpty {
                            duplicatesByHash.remove(at: potentialDuplicatesIndex)
                        }
                    }
                }
            }
        }

        return duplicatesByHash
    }

    private func handlePotentialDuplicate(
        _ path: String,
        _ hash: Int64,
        _ duplicatesByHash: inout [Duplicates],
        _ duplicatesListInit: () -> Duplicates
    ) {
        if let potentialDuplicatesIndex = duplicatesByHash.firstIndex(where: { $0.hash == hash }) {
            duplicatesByHash[potentialDuplicatesIndex].append(path: path)
        } else {
            duplicatesByHash.append(duplicatesListInit())
        }
    }
}

private func computeHash(for path: String) async -> Int64? {
    guard let content = FileManager.default.contents(atPath: path) else {
        print("Не удалось прочитать файл \(path)")
        return nil
    }

    return Int64(content.hashValue)
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
// Fallback for macOS/tvOS/watchOS
// Use cross-platform alternatives
#endif
