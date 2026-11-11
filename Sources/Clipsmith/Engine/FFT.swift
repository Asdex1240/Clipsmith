import Foundation

final class FFT {
    let size: Int
    private let cosTable: [Float]
    private let sinTable: [Float]
    private let bitReversed: [Int]

    init(size: Int) {
        precondition(size > 1 && size & (size - 1) == 0, "FFT size must be a power of two")
        self.size = size
        cosTable = (0..<size / 2).map { Float(cos(2 * Double.pi * Double($0) / Double(size))) }
        sinTable = (0..<size / 2).map { Float(sin(2 * Double.pi * Double($0) / Double(size))) }
        var bits = 0
        while 1 << bits < size { bits += 1 }
        bitReversed = (0..<size).map { index in
            var reversed = 0
            for bit in 0..<bits where index & (1 << bit) != 0 {
                reversed |= 1 << (bits - 1 - bit)
            }
            return reversed
        }
    }

    func forward(_ real: inout [Float], _ imaginary: inout [Float]) {
        transform(&real, &imaginary)
    }

    func inverse(_ real: inout [Float], _ imaginary: inout [Float]) {
        transform(&imaginary, &real)
        let scale = 1 / Float(size)
        for index in 0..<size {
            real[index] *= scale
            imaginary[index] *= scale
        }
    }

    private func transform(_ real: inout [Float], _ imaginary: inout [Float]) {
        let count = size
        real.withUnsafeMutableBufferPointer { re in
            imaginary.withUnsafeMutableBufferPointer { im in
                for index in 0..<count {
                    let other = bitReversed[index]
                    if other > index {
                        re.swapAt(index, other)
                        im.swapAt(index, other)
                    }
                }
                var length = 2
                while length <= count {
                    let half = length / 2
                    let step = count / length
                    var start = 0
                    while start < count {
                        for k in 0..<half {
                            let wr = cosTable[k * step]
                            let wi = -sinTable[k * step]
                            let a = start + k
                            let b = a + half
                            let tr = re[b] * wr - im[b] * wi
                            let ti = re[b] * wi + im[b] * wr
                            re[b] = re[a] - tr
                            im[b] = im[a] - ti
                            re[a] += tr
                            im[a] += ti
                        }
                        start += length
                    }
                    length <<= 1
                }
            }
        }
    }
}
