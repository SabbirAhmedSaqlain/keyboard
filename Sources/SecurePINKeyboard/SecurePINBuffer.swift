import Darwin
import Foundation

/// Fixed-capacity digit storage that zeroes its memory on clear and on deinit,
/// so the PIN never lives in a `String` and never lingers after use.
///
/// Deliberately not actor-isolated so `deinit` can always wipe the bytes,
/// even when the host app uses main-actor default isolation.
final class SecurePINBuffer {

    private let capacity: Int
    private var storage: [UInt8]
    private(set) var count = 0

    init(capacity: Int) {
        precondition(capacity > 0 && capacity <= SecureKeyboardConfiguration.maximumPINLength)
        self.capacity = capacity
        self.storage = Array(repeating: 0, count: capacity)
    }

    deinit {
        removeAll()
    }

    var isEmpty: Bool {
        count == 0
    }

    var isFull: Bool {
        count == capacity
    }

    func append(digit: Int) {
        guard count < capacity, (0...9).contains(digit) else { return }
        storage[count] = UInt8(digit)
        count += 1
    }

    func removeLast() {
        guard count > 0 else { return }
        count -= 1
        storage[count] = 0
    }

    func removeAll() {
        zeroize()
        count = 0
    }

    func copyBytes() -> [UInt8] {
        Array(storage.prefix(count))
    }

    /// Compares without early exit so timing does not reveal where the PINs differ.
    func constantTimeEquals(_ other: SecurePINBuffer) -> Bool {
        var difference = UInt8(truncatingIfNeeded: count ^ other.count)
        let maxCapacity = max(capacity, other.capacity)

        for index in 0..<maxCapacity {
            let lhs = index < capacity ? storage[index] : 0
            let rhs = index < other.capacity ? other.storage[index] : 0
            difference |= lhs ^ rhs
        }

        return difference == 0
    }

    private func zeroize() {
        guard !storage.isEmpty else { return }
        storage.withUnsafeMutableBytes { bytes in
            if let baseAddress = bytes.baseAddress {
                _ = memset(baseAddress, 0, bytes.count)
            }
        }
    }
}

public extension Array where Element == UInt8 {
    /// Overwrites the bytes with zeros and empties the array. Call on the PIN
    /// returned by `copyPINBytes()` / the entry delegate once you are done.
    mutating func secureWipe() {
        withUnsafeMutableBytes { bytes in
            if let baseAddress = bytes.baseAddress {
                _ = memset(baseAddress, 0, bytes.count)
            }
        }
        removeAll()
    }
}
