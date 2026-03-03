import Foundation

class IPCServer {
    private let socketPath: String
    private var socketFD: Int32 = -1
    private var listeningSource: DispatchSourceRead?
    var onCommand: ((String, String?) -> Void)?  // (command, argument)

    init(socketPath: String = "\(NSHomeDirectory())/.moji/moji.sock") {
        self.socketPath = socketPath
    }

    func start() {
        // Clean up old socket
        unlink(socketPath)
        let dir = (socketPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        socketFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketFD >= 0 else { return }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathCString = socketPath.utf8CString
        withUnsafeMutableBytes(of: &addr) { buf in
            let sunPathOffset = 2 // sun_len (UInt8) + sun_family (UInt8)
            for i in 0..<min(pathCString.count, 104) {
                buf[sunPathOffset + i] = UInt8(bitPattern: pathCString[i])
            }
        }

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else { close(socketFD); return }
        guard listen(socketFD, 5) == 0 else { close(socketFD); return }

        let source = DispatchSource.makeReadSource(fileDescriptor: socketFD, queue: .main)
        source.setEventHandler { [weak self] in self?.acceptConnection() }
        source.resume()
        self.listeningSource = source
    }

    private func acceptConnection() {
        let clientFD = accept(socketFD, nil, nil)
        guard clientFD >= 0 else { return }

        var buffer = [UInt8](repeating: 0, count: 1024)
        let bytesRead = read(clientFD, &buffer, buffer.count)
        close(clientFD)

        guard bytesRead > 0 else { return }
        let message = String(bytes: buffer.prefix(bytesRead), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if message.hasPrefix("OPEN_SEARCH:") {
            let keyword = String(message.dropFirst("OPEN_SEARCH:".count))
            onCommand?("OPEN_SEARCH", keyword.isEmpty ? nil : keyword)
        } else if message == "OPEN_SEARCH" {
            onCommand?("OPEN_SEARCH", nil)
        }
    }

    func stop() {
        listeningSource?.cancel()
        listeningSource = nil
        if socketFD >= 0 { close(socketFD) }
        unlink(socketPath)
    }
}
