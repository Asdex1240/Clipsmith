import Foundation

struct PreparedLookTable {
    let size: Int
    let cubeData: Data

    init(_ table: CubeLookTable) {
        size = table.size
        cubeData = table.rgbaValues.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
