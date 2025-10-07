// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import ArgumentParser

@main
struct DoppelgangersHunter: ParsableCommand {

    @Argument(help: "Путь к каталогу, где надо найти дубликаты", completion: .directory)
    var path: String

    @Flag(help: "Автоматически удалять найденные дубликаты")
    var delete: Bool = false

    @Flag(help: "Пропускать скрытые файлы")
    var skipsHiddenFiles: Bool = false

    func run() {
        guard let url = URL(string: path) else {
            print("Не удалсь открыть каталог \(path)")
            return
        }

        url.traverse(skipsHiddenFiles: skipsHiddenFiles)
        .compactMap { path in
            guard let content = FileManager.default.contents(atPath: path) else {
                return nil
            }

            return (path, content)
        }
        .forEach { (path: String, content: Data) in
            print("Хэш файла \(path) = \(content.hashValue)")
        }
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

    func traverse(skipsHiddenFiles: Bool) -> [String] {
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
            .map { $0.path } ?? []
    }
}
