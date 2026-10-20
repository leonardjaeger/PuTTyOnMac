import Darwin
import XCTest

extension XCTestCase {
    /// Lokaler Socket auf einem freien Port; ohne `listen` weist der Port Verbindungen ab, sobald er zu ist.
    func localSocket(listening: Bool) throws -> (descriptor: Int32, port: Int) {
        let socketDescriptor: Int32 = socket(AF_INET, SOCK_STREAM, 0)
        XCTAssertGreaterThanOrEqual(socketDescriptor, 0)
        var address: sockaddr_in = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        var length: socklen_t = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bound: Int32 = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(socketDescriptor, $0, length) }
        }
        XCTAssertEqual(bound, 0)
        if listening { XCTAssertEqual(listen(socketDescriptor, 1), 0) }
        _ = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(socketDescriptor, $0, &length) }
        }
        return (socketDescriptor, Int(UInt16(bigEndian: address.sin_port)))
    }

    /// Nimmt die Verbindung von plink an (wartet höchstens `timeout`); Ergebnis nicht blockierend.
    func accept(on server: Int32, timeout: TimeInterval = 5) throws -> Int32 {
        _ = fcntl(server, F_SETFL, fcntl(server, F_GETFL) | O_NONBLOCK)
        let deadline: Date = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            let client: Int32 = Darwin.accept(server, nil, nil)
            if client >= 0 {
                _ = fcntl(client, F_SETFL, fcntl(client, F_GETFL) | O_NONBLOCK)
                return client
            }
            RunLoop.main.run(until: Date.now.addingTimeInterval(0.05))
        }
        throw NotConnected()
    }

    /// Was in `duration` auf dem Socket ankommt (die App läuft dabei weiter).
    func received(on client: Int32, within duration: TimeInterval) -> [UInt8] {
        var bytes: [UInt8] = []
        var buffer: [UInt8] = [UInt8](repeating: 0, count: 4_096)
        let deadline: Date = Date.now.addingTimeInterval(duration)
        while Date.now < deadline {
            let count: Int = read(client, &buffer, buffer.count)
            if count > 0 { bytes.append(contentsOf: buffer[0..<count]) }
            RunLoop.main.run(until: Date.now.addingTimeInterval(0.05))
        }
        return bytes
    }
}

/// plink hat sich in der Wartezeit nicht mit dem Test-Socket verbunden.
struct NotConnected: Error {}
