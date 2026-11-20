// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Darwin
import Foundation

// Zenith fork: reads the process behind a dev server's listener from the
// kernel, without launching anything: its arguments (`KERN_PROCARGS2`), its
// current folder (`PROC_PIDVNODEPATHINFO`), its owner, parent and start
// (`PROC_PIDTBSDINFO`) and its executable. Only the person's own processes
// answer; anyone else's give nothing. Compiled into the tests, which read a
// listener the test itself opened.

enum DevServersProbe {
    /// Folder markers a JavaScript runtime's project has.
    static let projectFiles = ["package.json", "deno.json", "deno.jsonc", "bun.lockb", "bun.lock"]

    /// Everything the classifier asks about one process, or nil once it has gone.
    static func process(pid: Int32, name: String) -> DevServerProcess? {
        guard pid > 0, let info = bsdInfo(pid) else { return nil }
        let cwd = currentDirectory(pid)
        let parent = Int32(info.pbi_ppid)
        let micros = info.pbi_start_tvsec &* 1_000_000 &+ info.pbi_start_tvusec
        return DevServerProcess(pid: pid, name: name.isEmpty ? commandName(info) : name, path: path(pid),
                                arguments: arguments(pid), cwd: cwd, uid: info.pbi_uid, parentPID: parent,
                                parentName: parent > 0 ? processName(parent) : "",
                                startedAt: Date(timeIntervalSince1970: TimeInterval(info.pbi_start_tvsec)
                                                + TimeInterval(info.pbi_start_tvusec) / 1_000_000),
                                startMicros: micros,
                                hasProjectFile: cwd.map(hasProjectFile(in:)) ?? false)
    }

    static func bsdInfo(_ pid: Int32) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return info
    }

    /// The process's current folder.
    static func currentDirectory(_ pid: Int32) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        let path = withUnsafeBytes(of: &info.pvi_cdir.vip_path) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
        return path.isEmpty ? nil : path
    }

    /// argv, read from the kernel's copy of the process's arguments.
    static func arguments(_ pid: Int32) -> [String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return [] }
        var bytes = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &bytes, &size, nil, 0) == 0 else { return [] }
        return DevServersProcArgs.arguments(Array(bytes.prefix(size)))
    }

    static func path(_ pid: Int32) -> String {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return "" }
        return String(cString: buffer)
    }

    static func processName(_ pid: Int32) -> String {
        var buffer = [CChar](repeating: 0, count: 2 * Int(MAXCOMLEN) + 1)
        guard proc_name(pid, &buffer, UInt32(buffer.count)) > 0 else { return "" }
        return String(cString: buffer)
    }

    private static func commandName(_ info: proc_bsdinfo) -> String {
        var info = info
        return withUnsafeBytes(of: &info.pbi_name) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    static func hasProjectFile(in folder: String) -> Bool {
        guard folder != "/" else { return false }
        return projectFiles.contains { FileManager.default.fileExists(atPath: (folder as NSString).appendingPathComponent($0)) }
    }
}
