import CoreLocation

// MARK: - CLLocationCoordinate2D + Equatable

extension CLLocationCoordinate2D: Equatable {
    /// CLLocationCoordinate2DをEquatableに準拠させる
    /// これによりSwiftUIの.onChange(of:)で監視可能になる
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
