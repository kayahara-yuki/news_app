//
//  LocationExtensions.swift
//  LocationNewsSNS
//
//  Created by Claude Code on 2025-10-16.
//

import Foundation
import CoreLocation

extension CLLocationCoordinate2D {
    /// 2つの座標間の距離を計算（メートル単位）
    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        let from = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let to = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return from.distance(from: to)
    }
}
