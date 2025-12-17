// The Swift Programming Language
// https://docs.swift.org/swift-book
#if os(iOS)
#else
import ArgumentParser
import DoppelgangersHunter
import Foundation
import SQLite

@main
struct DoppelgangersHunter: AsyncParsableCommand {

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

        let results = await Hunt().hunt(
            url: url,
            skipsHiddenFiles: skipsHiddenFiles,
            useSQLite: useSQLite
        )

        results.enumerated().forEach { index, duplicates in
            duplicates.paths.forEach { path in
                print(path)
            }

            if index < results.count - 1 {
                print()
            }
        }
    }
}
#endif
