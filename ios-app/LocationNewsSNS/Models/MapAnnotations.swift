import Foundation
import MapKit
import CoreLocation

// MARK: - Map Annotations

/// 投稿アノテーション
class PostAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let post: Post

    init?(post: Post) {
        // 位置情報が有効な投稿のみアノテーションを作成
        guard let coordinate = post.coordinate, post.hasValidLocation else {
            return nil
        }

        self.post = post
        self.coordinate = coordinate
        self.title = post.content.prefix(50).description
        self.subtitle = post.category.displayName
        super.init()
    }
}

/// 投稿クラスターアノテーション
class PostClusterAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let posts: [Post]
    
    init(posts: [Post], coordinate: CLLocationCoordinate2D) {
        self.posts = posts
        self.coordinate = coordinate
        
        if posts.count == 1 {
            self.title = posts[0].content.prefix(50).description
            self.subtitle = posts[0].category.displayName
        } else {
            self.title = "\(posts.count)件の投稿"
            self.subtitle = "タップして詳細を表示"
        }
        
        super.init()
    }
    
    /// クラスター内の主要カテゴリを取得
    var primaryCategory: PostCategory {
        let categoryCounts = posts.reduce(into: [PostCategory: Int]()) { counts, post in
            counts[post.category, default: 0] += 1
        }
        
        return categoryCounts.max(by: { $0.value < $1.value })?.key ?? .other
    }
    
    /// 緊急投稿が含まれているかどうか
    var containsEmergencyPost: Bool {
        return posts.contains { $0.isUrgent }
    }
    
    /// 検証済み投稿が含まれているかどうか
    var containsVerifiedPost: Bool {
        return posts.contains { $0.isVerified }
    }
}

/// 緊急事態アノテーション
class EmergencyAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let emergencyEvent: EmergencyEvent

    init?(emergencyEvent: EmergencyEvent) {
        guard let firstLocation = emergencyEvent.affectedArea.first else {
            return nil
        }
        self.emergencyEvent = emergencyEvent
        self.coordinate = firstLocation
        self.title = emergencyEvent.title
        self.subtitle = emergencyEvent.eventType.displayName
        super.init()
    }
}

/// 避難所アノテーション
class ShelterAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let shelter: Shelter

    init(shelter: Shelter) {
        self.shelter = shelter
        self.coordinate = shelter.coordinate
        self.title = shelter.name
        self.subtitle = shelter.status == .open ? "開設中" : shelter.status.displayName
        super.init()
    }
}

