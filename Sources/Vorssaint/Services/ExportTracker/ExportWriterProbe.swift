// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Darwin
import Foundation

/// Zenith fork: who has a file open, and whether for writing, read from the
/// kernel's own tables through libproc, the way `lsof` does, without a
/// process of its own. Only processes of the same user can be read, which is
/// every app that exports for them. Compiled into the tests.
enum ExportWriterProbe {
    struct Opener: Equatable {
        let pid: Int32
        let executable: String
        let writing: Bool
    }

    /// The path as the kernel names it, `/private/var/…` for `/var/…`.
    static func canonical(_ path: String) -> String {
        guard let resolved = realpath(path, nil) else { return path }
        defer { free(resolved) }
        return String(cString: resolved)
    }

    /// Every process with `path` open, nil when the kernel would not say.
    /// This walks every process, so it is asked only now and then: once a
    /// writer is known, `isWriting(_:pid:)` asks that one alone.
    static func openers(of path: String) -> [Opener]? {
        let path = canonical(path)
        var pids = [Int32](repeating: 0, count: 512)
        let stride = MemoryLayout<Int32>.stride
        let bytes = pids.withUnsafeMutableBytes { buffer in
            proc_listpidspath(UInt32(PROC_ALL_PIDS), 0, path, UInt32(PROC_LISTPIDSPATH_EXCLUDE_EVTONLY),
                              buffer.baseAddress, Int32(buffer.count))
        }
        guard bytes >= 0 else { return nil }
        return pids.prefix(Int(bytes) / stride).filter { $0 > 0 }.map { pid in
            Opener(pid: pid, executable: executablePath(pid) ?? "", writing: isWriting(path, pid: pid) == true)
        }
    }

    /// Whether `pid` holds `path` open for writing: nil when its files
    /// cannot be read (it ended, or it is not ours).
    static func isWriting(_ path: String, pid: Int32) -> Bool? {
        let path = canonical(path)
        let stride = MemoryLayout<proc_fdinfo>.stride
        let needed = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard needed > 0 else { return nil }
        var descriptors = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(needed) / stride + 32)
        let read = descriptors.withUnsafeMutableBytes { buffer in
            proc_pidinfo(pid, PROC_PIDLISTFDS, 0, buffer.baseAddress, Int32(buffer.count))
        }
        guard read > 0 else { return nil }
        let infoSize = Int32(MemoryLayout<vnode_fdinfowithpath>.stride)
        for descriptor in descriptors.prefix(Int(read) / stride)
        where descriptor.proc_fdtype == UInt32(PROX_FDTYPE_VNODE) {
            var info = vnode_fdinfowithpath()
            guard proc_pidfdinfo(pid, descriptor.proc_fd, PROC_PIDFDVNODEPATHINFO, &info, infoSize) == infoSize else {
                continue
            }
            let open = withUnsafeBytes(of: &info.pvip.vip_path) { raw in
                String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
            }
            if open == path, ExportTrackerSupport.isWriteMode(openFlags: info.pfi.fi_openflags) { return true }
        }
        return false
    }

    static func executablePath(_ pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer)
    }

    /// The executables of this user's running processes, to credit a batch
    /// of images that landed whole to an app that can export them.
    static func runningExecutables() -> [String] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [Int32](repeating: 0, count: Int(count) + 64)
        let found = pids.withUnsafeMutableBytes { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count))
        }
        guard found > 0 else { return [] }
        return pids.prefix(Int(found)).filter { $0 > 0 }.compactMap(executablePath)
    }
}
