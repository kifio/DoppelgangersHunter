// The Swift Programming Language
// https://docs.swift.org/swift-book

import ArgumentParser
import Foundation
import SQLite

@main
struct EntryPoint: AsyncParsableCommand {

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

        let duplicates = await DoppelgangersHunter().hunt(url: url, skipsHiddenFiles: skipsHiddenFiles, useSQLite: useSQLite)

        for duplicate in duplicates {
            print("Hash: \(duplicate.hash):")
            for path in duplicate.paths {
                print(path)
            }
            print("------")
        }

        for duplicate in findDuplicateFiles(at: path) {
            print(duplicate)
        }

    }
}
