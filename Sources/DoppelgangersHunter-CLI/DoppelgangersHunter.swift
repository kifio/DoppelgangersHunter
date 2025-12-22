// The Swift Programming Language
// https://docs.swift.org/swift-book
#if os(iOS)
#else
import ArgumentParser
import DoppelgangersHunter
import Foundation

@main
struct DoppelgangersHunter: AsyncParsableCommand {

    @Argument(help: "Путь к каталогу, где надо найти дубликаты", completion: .directory)
    var path: String

    @Flag(help: "Автоматически удалять найденные дубликаты")
    var delete: Bool = false

    @Flag(help: "Пропускать скрытые файлы")
    var skipsHiddenFiles: Bool = false

    func run() async {
        guard let url = URL(string: path) else {
            print("Не удалось открыть каталог \(path)")
            return
        }

        let results = await Hunt().hunt(
            url: url,
            skipsHiddenFiles: skipsHiddenFiles
        )

        results.enumerated().forEach { index, duplicates in
            duplicates.files.forEach { file in
                print(file.path)
            }

            if index < results.count - 1 {
                print()
            }
        }
    }
}
#endif
