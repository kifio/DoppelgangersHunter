import Foundation
import SQLite

struct DatabaseHelper {
    private let hashesTableName = "hashes"
    private let hashColumn = "hash"
    private let pathColumn = "path"
    
    private let dbConnection: SQLite.Connection
    
    init?(maxPathLength: Int) {
        do {
            dbConnection = try SQLite.Connection("db.sqlite3")
        } catch {
            print("Не удалось открыть базу данных: \(error)")
            return nil
        }
        
        do {
            try dbConnection.run("CREATE TABLE \(hashesTableName) (\(hashColumn) INTEGER NOT NULL, \(pathColumn) VARCHAR(\(maxPathLength)) PRIMARY KEY NOT NULL)")
        } catch {
            print("Не удалось создать базу данных для хэшей.")
        }
    }
    
    func saveToDatabase(hashesTable: [String: Int64]) {
        do {
            let insertStatement = try dbConnection.prepare("INSERT INTO \(hashesTableName) (\(pathColumn), \(hashColumn)) VALUES (?,?)")
            try hashesTable.forEach { path, hash in
                try insertStatement.run(path, hash)
            }
        } catch {
            print("Не удалось добавить запись в базу данных: \(error)")
        }
    }
    
    func queryDuplicates() -> [String: Int64] {
        do {
            let queryStatement = try dbConnection.prepare("""
            SELECT \(hashColumn), \(pathColumn)
            FROM (
                SELECT \(hashColumn), \(pathColumn), COUNT(*) OVER (PARTITION BY \(hashColumn)) as count
                FROM \(hashesTableName)
            )
            WHERE count > 1;
            """)
            
            return queryStatement
                .compactMap { row in
                    return if let path = row[1] as? String, let hash = row[0] as? Int64 {
                        (path: path, hash: hash)
                    } else { nil }
                }.reduce(into: [String: Int64]()) { result, element in
                    let (key, value) = element
                    result[key] = value
                }
            
        } catch {
            print("Произошла ошибка при поиске дубликато в базе данных: \(error)")
            return [:]
        }
    }
    
    func closeAndDeleteDatabase() {
        do {
            dbConnection.interrupt()
            try FileManager.default.removeItem(atPath: "db.sqlite3")
        } catch {
            print("Произошла ошибка при закрытии базы данных: \(error)")
        }
    }
}
