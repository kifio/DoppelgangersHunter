import Foundation

func findFilesWithProcess(at path: String = ".", skipsHiddenFiles: Bool = true) -> [String] {
    let process = Process()

    process.executableURL = URL(fileURLWithPath: "/usr/bin/find")
    process.arguments = [path, "-type", "f"]

    if skipsHiddenFiles {
        process.arguments!.append(contentsOf: ["!", "-path", "*/.*", "!", "-name", ".*"])
    }

    return executeProcess(process: process)
}

func findDuplicateFiles(at path: String = ".") -> [String] {
    let task = Process()

    task.executableURL = URL(fileURLWithPath: "/bin/bash")
    task.arguments = ["-c", "find \(path) -type f -exec cksum {} + | sort | tee /tmp/f.tmp | cut -d ' ' -f 1,2 | uniq -d | grep -hif - /tmp/f.tmp | awk '{print $3}'"]

    return executeProcess(process: task)
}

func executeProcess(process: Process) -> [String] {
    let pipe = Pipe()
    process.standardOutput = pipe

    do {
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return output.components(separatedBy: "\n").filter { !$0.isEmpty }
    } catch {
        print("Ошибка при выполнении программы find: \(error)")
        return []
    }
}
