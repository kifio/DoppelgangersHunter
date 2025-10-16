// The Swift Programming Language
// https://docs.swift.org/swift-book

import ArgumentParser
import Foundation
import SQLite

@main
struct DoppelgangersHunter: AsyncParsableCommand {

    typealias PathWithHash = (path: String, hash: Int64)

    class Duplicates: Decodable {
        let hash: Int64
        var paths: [String]

        init(hash: Int64, paths: [String]) {
            self.hash = hash
            self.paths = paths
        }
    }

    @Argument(help: "Путь к каталогу, где надо найти дубликаты", completion: .directory)
    var path: String

    @Flag(help: "Автоматически удалять найденные дубликаты")
    var delete: Bool = false

    @Flag(help: "Пропускать скрытые файлы")
    var skipsHiddenFiles: Bool = false

    @Flag(name: .customLong("use-sqlite"), help: "Использовать SQLite базу данных")
    var useSQLite: Bool = false

    func run() async {
        guard let url = URL(string: path) else {
            print("Не удалось открыть каталог \(path)")
            return
        }

        let traverseResult = url.traverse(skipsHiddenFiles: skipsHiddenFiles)
        print("Найдено файлов: \(traverseResult.paths.count)")
        _ = await withTaskGroup(of: PathWithHash?.self) { group in
            for path in traverseResult.paths {
                group.addTask {
                    return if let hash = await computeHash(for: path) {
                        (path: path, hash: hash)
                    } else { nil }
                }
            }

            var sqliteHashesTable: [String: Int64]? = useSQLite ? [:] : nil
            var inMemoryHashesTable: [Int64: String]? = useSQLite ? nil : [:]
            var duplicatesByHash: [Duplicates] = []

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
        }
    }

    private func handlePotentialDuplicate(
        _ path: String,
        _ hash: Int64,
        _ duplicatesByHash: inout [Duplicates],
        _ duplicatesListInit: () -> Duplicates
    ) {
        if let potentialDuplicates = duplicatesByHash.first(where: { $0.hash == hash }) {
            print("Добавить файл с хэшем : \(hash);")
            potentialDuplicates.paths.append(path)
        } else {
            print("Создать список файлов с хэшем: \(hash);")
            duplicatesByHash.append(duplicatesListInit())
        }
    }

    // func batchDuplicates(duplicatesByHash: [Duplicates]) async {
    //     _ = await withTaskGroup(of: [[(String, Data)]].self) { group in
    //         for duplicates in duplicatesByHash {
    //             group.addTask {
    //                 duplicates.paths.batchDuplicates()
    //             }
    //         }
    //     }
    // }
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
