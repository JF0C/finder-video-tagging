import Foundation

struct CoverageFile {
    var lines: [Int: Int] = [:]
}

enum GuardError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
        case let .message(message): message
        }
    }
}

func runGit(_ arguments: [String]) throws -> String {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = arguments
    process.standardOutput = output
    process.standardError = FileHandle.standardError
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw GuardError.message("git \(arguments.joined(separator: " ")) failed")
    }
    return String(decoding: data, as: UTF8.self)
}

func relativePath(_ path: String, projectPath: String) -> String {
    let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
    let prefix = projectPath + "/"
    return normalized.hasPrefix(prefix) ? String(normalized.dropFirst(prefix.count)) : normalized
}

func parseCoverage(at path: String, projectPath: String) throws -> [String: CoverageFile] {
    let contents = try String(contentsOfFile: path, encoding: .utf8)
    var files: [String: CoverageFile] = [:]
    var currentPath: String?

    for line in contents.split(separator: "\n") {
        if line.hasPrefix("SF:") {
            currentPath = relativePath(String(line.dropFirst(3)), projectPath: projectPath)
        } else if line.hasPrefix("DA:"), let currentPath {
            let values = line.dropFirst(3).split(separator: ",", maxSplits: 2)
            guard values.count >= 2, let lineNumber = Int(values[0]), let count = Int(values[1])
            else { continue }
            files[currentPath, default: CoverageFile()].lines[lineNumber, default: 0] += count
        }
    }
    return files
}

func changedLines(baseRef: String) throws -> [String: Set<Int>] {
    let diff = try runGit([
        "diff", "--unified=0", "--diff-filter=AMR", baseRef, "--", "Sources", "Package.swift",
    ])
    let hunkPattern = try NSRegularExpression(
        pattern: #"^@@ -[0-9]+(?:,[0-9]+)? \+([0-9]+)(?:,([0-9]+))? @@"#)
    var changed: [String: Set<Int>] = [:]
    var currentPath: String?

    for line in diff.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
        if line.hasPrefix("+++ b/") {
            currentPath = String(line.dropFirst(6))
            continue
        }
        guard line.hasPrefix("@@"), let currentPath else { continue }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = hunkPattern.firstMatch(in: line, range: range),
            let startRange = Range(match.range(at: 1), in: line),
            let start = Int(line[startRange])
        else { continue }
        let count: Int
        if match.range(at: 2).location == NSNotFound {
            count = 1
        } else if let countRange = Range(match.range(at: 2), in: line) {
            count = Int(line[countRange]) ?? 0
        } else {
            count = 0
        }
        if count > 0 {
            changed[currentPath, default: []].formUnion(start..<(start + count))
        }
    }

    let untracked = try runGit(["ls-files", "--others", "--exclude-standard", "--", "Sources"])
    for path in untracked.split(separator: "\n").map(String.init) where path.hasSuffix(".swift") {
        let contents = try String(contentsOfFile: path, encoding: .utf8)
        changed[path] = Set(
            1...max(1, contents.split(separator: "\n", omittingEmptySubsequences: false).count))
    }
    return changed
}

func percentage(covered: Int, total: Int) -> Double {
    total == 0 ? 100 : Double(covered) * 100 / Double(total)
}

do {
    guard CommandLine.arguments.count == 5,
        let overallMinimum = Double(CommandLine.arguments[3]),
        let changedMinimum = Double(CommandLine.arguments[4])
    else {
        throw GuardError.message(
            "Usage: CoverageGuard.swift <lcov> <base-ref> <overall-minimum> <changed-minimum>")
    }

    let projectPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .standardizedFileURL.path
    let files = try parseCoverage(at: CommandLine.arguments[1], projectPath: projectPath)
    let changed = try changedLines(baseRef: CommandLine.arguments[2])
    let allLines = files.values.flatMap(\.lines.values)
    let overallCovered = allLines.filter { $0 > 0 }.count
    let overall = percentage(covered: overallCovered, total: allLines.count)

    var changedTotal = 0
    var changedCovered = 0
    var uncoveredChanged: [String] = []
    for (path, coverage) in files {
        for line in changed[path, default: []] where coverage.lines[line] != nil {
            changedTotal += 1
            if coverage.lines[line, default: 0] > 0 {
                changedCovered += 1
            } else {
                uncoveredChanged.append("\(path):\(line)")
            }
        }
    }
    let changedCoverage = percentage(covered: changedCovered, total: changedTotal)

    print(
        String(
            format: "Overall coverage: %.2f%% (%d/%d lines)", overall, overallCovered,
            allLines.count))
    print(
        String(
            format: "Changed-line coverage: %.2f%% (%d/%d lines)",
            changedCoverage, changedCovered, changedTotal))
    if !uncoveredChanged.isEmpty {
        print("Uncovered changed lines: \(uncoveredChanged.sorted().joined(separator: ", "))")
    }

    var failures: [String] = []
    if overall + 0.000_001 < overallMinimum {
        failures.append(String(format: "overall coverage must be at least %.2f%%", overallMinimum))
    }
    if changedCoverage + 0.000_001 < changedMinimum {
        failures.append(
            String(format: "changed-line coverage must be at least %.2f%%", changedMinimum))
    }
    guard failures.isEmpty else {
        throw GuardError.message("Coverage check failed: \(failures.joined(separator: "; "))")
    }
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
