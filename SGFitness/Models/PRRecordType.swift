import Foundation

enum PRRecordType: String, Codable, CaseIterable {
    case maxWeight  = "maxWeight"
    case bestVolume = "bestVolume"
    case cardioTime = "cardioTime"
}
