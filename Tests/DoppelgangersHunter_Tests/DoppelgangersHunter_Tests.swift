import Foundation
import Testing

@testable import DoppelgangersHunter

@usableFromInline
let url = URL(string: "TestData")!

@Test func testTraverse() {
    #expect(testTraverse(skipsHiddenFiles: true) == 9)
    #expect(testTraverse(skipsHiddenFiles: false) == 11)
}

@inlinable
func testTraverse(skipsHiddenFiles: Bool) -> Int {
    url.traverse(skipsHiddenFiles: skipsHiddenFiles).paths.filter { !$0.contains("DS_Store") }.count
}

@Test func testDoppelgangersHunt() async {
    #expect(await testDoppelgangersHunt(useSQLite: false, skipsHiddenFiles: true) == 6)
    #expect(await testDoppelgangersHunt(useSQLite: false, skipsHiddenFiles: false) == 8)
}

@Test func testDoppelgangersHuntWithSQLite() async {
    #expect(await testDoppelgangersHunt(useSQLite: true, skipsHiddenFiles: true) == 6)
    #expect(await testDoppelgangersHunt(useSQLite: true, skipsHiddenFiles: false) == 8)
}

@inlinable
func testDoppelgangersHunt(useSQLite: Bool, skipsHiddenFiles: Bool) async -> Int {
    await Hunt().hunt(url: url, skipsHiddenFiles: skipsHiddenFiles, useSQLite: useSQLite)
        .reduce(into: [String]()) { result, element in
            result.append(contentsOf: element.paths)
        }.count
}

@inlinable
func contents(of path: String) -> Data? {
    FileManager.default.contents(atPath: path)
}
