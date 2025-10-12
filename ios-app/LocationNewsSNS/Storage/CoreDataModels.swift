import Foundation
import CoreData
import CoreLocation

// MARK: - CachedPost Core Data Model

@objc(CachedPost)
public class CachedPost: NSManagedObject {
    
}

extension CachedPost {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CachedPost> {
        return NSFetchRequest<CachedPost>(entityName: "CachedPost")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var content: String
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var trustScore: Double
    @NSManaged public var likeCount: Int32
    @NSManaged public var commentCount: Int32
    @NSManaged public var shareCount: Int32
    @NSManaged public var visibility: String
    @NSManaged public var allowComments: Bool
    @NSManaged public var emergencyLevel: String?
    @NSManaged public var mediaFilesData: Data?
    @NSManaged public var tagsData: Data?
    @NSManaged public var userID: UUID
    @NSManaged public var username: String
    @NSManaged public var userDisplayName: String?
    @NSManaged public var userAvatarURL: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var cachedAt: Date
    
    func configure(from post: Post) {
        self.id = post.id
        self.content = post.content
        self.latitude = post.latitude ?? 0
        self.longitude = post.longitude ?? 0
        self.trustScore = post.trustScore
        self.likeCount = Int32(post.likeCount)
        self.commentCount = Int32(post.commentCount)
        self.shareCount = Int32(post.shareCount)
        self.visibility = post.visibility.rawValue
        self.emergencyLevel = post.emergencyLevel?.rawValue
        self.userID = post.user.id
        self.username = post.user.username
        self.userDisplayName = post.user.displayName
        self.userAvatarURL = post.user.avatarURL
        self.createdAt = post.createdAt
        self.updatedAt = post.updatedAt
        self.cachedAt = Date()
        
        // Encode media files as JSON data
        self.mediaFilesData = try? JSONEncoder().encode(post.mediaFiles)
    }
    
    func toPost() -> Post? {
        // Decode media files
        var mediaFiles: [MediaFile] = []

        if let mediaData = mediaFilesData {
            mediaFiles = (try? JSONDecoder().decode([MediaFile].self, from: mediaData)) ?? []
        }
        
        let user = UserProfile(
            id: userID,
            email: "", // Not cached
            username: username,
            displayName: userDisplayName,
            bio: nil,
            avatarURL: userAvatarURL,
            coverURL: nil,
            location: nil,
            locationPrecision: .approximate,
            isVerified: false,
            isOfficial: false,
            role: .user,
            privacySettings: PrivacySettings.default,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastActiveAt: nil
        )
        
        return Post(
            id: id,
            user: user,
            content: content,
            url: nil,
            latitude: latitude,
            longitude: longitude,
            address: nil,
            category: .other,
            visibility: PostVisibility(rawValue: visibility) ?? .public,
            isEmergency: false,
            emergencyLevel: emergencyLevel.flatMap { EmergencyLevel(rawValue: $0) },
            trustScore: trustScore,
            mediaFiles: mediaFiles,
            likeCount: Int(likeCount),
            commentCount: Int(commentCount),
            shareCount: Int(shareCount),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - PendingPost Core Data Model

@objc(PendingPost)
public class PendingPost: NSManagedObject {
    
}

extension PendingPost {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PendingPost> {
        return NSFetchRequest<PendingPost>(entityName: "PendingPost")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var content: String
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var visibility: String
    @NSManaged public var allowComments: Bool
    @NSManaged public var emergencyLevel: String?
    @NSManaged public var mediaFilesData: Data?
    @NSManaged public var tagsData: Data?
    @NSManaged public var createdAt: Date
    @NSManaged public var retryCount: Int32
    
    func configure(from request: CreatePostRequest) {
        self.id = UUID()
        self.content = request.content
        self.latitude = request.latitude ?? 0
        self.longitude = request.longitude ?? 0
        self.visibility = request.visibility.rawValue
        self.allowComments = request.allowComments
        self.emergencyLevel = request.emergencyLevel?.rawValue
        self.createdAt = Date()
        self.retryCount = 0
    }
    
    func toCreatePostRequest() -> CreatePostRequest? {
        return CreatePostRequest(
            content: content,
            latitude: latitude,
            longitude: longitude,
            locationName: nil,
            visibility: PostVisibility(rawValue: visibility) ?? .public,
            allowComments: allowComments,
            emergencyLevel: emergencyLevel.flatMap { EmergencyLevel(rawValue: $0) },
            tags: nil,
            images: []
        )
    }
}

// MARK: - PendingAction Core Data Model

@objc(PendingAction)
public class PendingAction: NSManagedObject {
    
}

extension PendingAction {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PendingAction> {
        return NSFetchRequest<PendingAction>(entityName: "PendingAction")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var actionType: String
    @NSManaged public var postID: UUID?
    @NSManaged public var content: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var retryCount: Int32
}

// MARK: - Extensions for easier initialization

extension CachedPost {
    nonisolated convenience init(context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "CachedPost", in: context)!
        self.init(entity: entity, insertInto: context)
    }
}

extension PendingPost {
    nonisolated convenience init(context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "PendingPost", in: context)!
        self.init(entity: entity, insertInto: context)
        self.id = UUID()
        self.createdAt = Date()
        self.retryCount = 0
    }
}

extension PendingAction {
    nonisolated convenience init(context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "PendingAction", in: context)!
        self.init(entity: entity, insertInto: context)
        self.id = UUID()
        self.createdAt = Date()
        self.retryCount = 0
    }
}