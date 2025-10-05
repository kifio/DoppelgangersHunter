import Foundation
import Testing

@testable import DoppelgangersHunter

@Test func testTraverse() {
    testTraverse(skipsHiddenFiles: true)
    testTraverse(skipsHiddenFiles: false)
}

private func testTraverse(skipsHiddenFiles: Bool) {
    let findResults = findFilesWithProcess(at: ".")
        .compactMap { FileManager.default.contents(atPath: $0) }

    let traverseResults = URL(string: ".")!.traverse(skipsHiddenFiles: true)
        .compactMap { FileManager.default.contents(atPath: $0) }

    #expect(Set(findResults) == Set(traverseResults))
}

func findFilesWithProcess(at path: String = ".", skipsHiddenFiles: Bool = true) -> [String] {
    let process = Process()
    let pipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/usr/bin/find")
    process.arguments = [path, "-type", "f"]

    if skipsHiddenFiles {
        process.arguments!.append(contentsOf: ["!", "-path", "*/.*", "!", "-name", ".*"])
    }

    process.standardOutput = pipe

    do {
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            return output.components(separatedBy: "\n").filter { !$0.isEmpty }
        }
    } catch {
        print("Ошибка при выполнении программы find: \(error)")
    }

    return []
}
