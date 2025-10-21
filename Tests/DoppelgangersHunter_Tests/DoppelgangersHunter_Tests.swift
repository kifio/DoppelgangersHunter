import Foundation
import Testing

@testable import DoppelgangersHunter

@Test func testTraverse() {
    testTraverse(skipsHiddenFiles: true)
    testTraverse(skipsHiddenFiles: false)
}

private func testTraverse(skipsHiddenFiles: Bool) {
    let findResults = findFilesWithProcess(at: ".")
        .compactMap { contents(of: $0) }

    let traverseResults = URL(string: ".")!.traverse(skipsHiddenFiles: true)
        .paths
        .compactMap { contents(of: $0) }

    #expect(Set(findResults) == Set(traverseResults))
}

@Test func testDoppelgangersHunt() async {
    let url = URL(string: ".")!

    let findResults = findDuplicateFiles(at: ".")
        .compactMap { contents(of: $0) }

    let doppelgangersHuntResults = await DoppelgangersHunter().hunt(url: url)
        .reduce(into: [String]()) { result, element in
            result.append(contentsOf: element.paths)
        }
        .compactMap { contents(of: $0) }

    #expect(Set(findResults) == Set(doppelgangersHuntResults))
}

@inlinable
func contents(of path: String) -> Data? {
    FileManager.default.contents(atPath: path)
}
