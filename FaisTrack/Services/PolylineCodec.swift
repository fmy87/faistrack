import CoreLocation

/// Encodes/decodes coordinate paths using the standard polyline algorithm
/// (the same compact encoding popularized by Google Maps, but it's just a
/// generic lossy-compression format for lat/lng paths — no Google API or
/// account is involved). Used to store a drive's route compactly in
/// Firestore (`Drive.polylineEncoded`) and reconstruct it for MapKit.
enum PolylineCodec {
    private static let precision: Double = 1e5

    static func encode(_ coordinates: [CLLocationCoordinate2D]) -> String {
        var result = ""
        var previousLat = 0
        var previousLng = 0

        for coordinate in coordinates {
            let lat = Int(round(coordinate.latitude * precision))
            let lng = Int(round(coordinate.longitude * precision))
            result += encodeValue(lat - previousLat)
            result += encodeValue(lng - previousLng)
            previousLat = lat
            previousLng = lng
        }
        return result
    }

    static func decode(_ encoded: String) -> [CLLocationCoordinate2D] {
        guard !encoded.isEmpty else { return [] }
        var coordinates: [CLLocationCoordinate2D] = []
        var index = encoded.startIndex
        var lat = 0
        var lng = 0

        while index < encoded.endIndex {
            let (deltaLat, nextIndex1) = decodeValue(encoded, from: index)
            lat += deltaLat
            guard nextIndex1 < encoded.endIndex || nextIndex1 == encoded.endIndex else { break }
            let (deltaLng, nextIndex2) = decodeValue(encoded, from: nextIndex1)
            lng += deltaLng
            index = nextIndex2
            coordinates.append(CLLocationCoordinate2D(
                latitude: Double(lat) / precision,
                longitude: Double(lng) / precision
            ))
        }
        return coordinates
    }

    private static func encodeValue(_ value: Int) -> String {
        var v = value << 1
        if value < 0 { v = ~v }
        var result = ""
        while v >= 0x20 {
            let charValue = (0x20 | (v & 0x1f)) + 63
            result.append(Character(UnicodeScalar(charValue)!))
            v >>= 5
        }
        result.append(Character(UnicodeScalar(v + 63)!))
        return result
    }

    private static func decodeValue(_ encoded: String, from start: String.Index) -> (Int, String.Index) {
        var index = start
        var result = 0
        var shift = 0
        var byte: Int

        repeat {
            guard index < encoded.endIndex, let ascii = encoded[index].asciiValue else {
                return (0, encoded.endIndex)
            }
            byte = Int(ascii) - 63
            result |= (byte & 0x1f) << shift
            shift += 5
            index = encoded.index(after: index)
        } while byte >= 0x20

        let value = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
        return (value, index)
    }
}
