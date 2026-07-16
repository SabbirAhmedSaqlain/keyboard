//
//  SecurePinBuffer.swift
//  keyboard
//
//  Fixed-size in-memory PIN buffer. This avoids Swift String storage for PINs,
//  limits copies, compares in constant time, and clears bytes when discarded.
//

import Darwin
import Foundation

final class SecurePinBuffer {

    private let capacity: Int
    private var storage: [UInt8]
    private(set) var count = 0

    init(capacity: Int) {
        precondition(capacity > 0 && capacity < 256)
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

    func constantTimeEquals(_ other: SecurePinBuffer) -> Bool {
        var difference = UInt8(count ^ other.count)
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
