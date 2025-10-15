import SwiftUI
import MapKit

// MARK: - カスタム投稿アノテーションビュー

class PostMapAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "PostMapAnnotation"

    // パフォーマンス最適化: ビュー要素を再利用
    private var annotationImageView: UIView?
    private var calloutHostingController: UIHostingController<PostCalloutView>?

    override var annotation: MKAnnotation? {
        didSet {
            guard let postAnnotation = annotation as? PostAnnotation else { return }
            configureView(for: postAnnotation)
        }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    private func setupView() {
        canShowCallout = true
        
        // カスタムビューの設定
        let size: CGFloat = 40
        frame = CGRect(x: 0, y: 0, width: size, height: size)
        centerOffset = CGPoint(x: 0, y: -size / 2)
        
        // 右側のアクセサリビュー
        rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
    }
    
    private func configureView(for postAnnotation: PostAnnotation) {
        // パフォーマンス最適化: ビュー再利用
        // 既存のビューがあれば更新、なければ新規作成

        if let existingImageView = annotationImageView {
            // 既存ビューを更新（削除せずに内容を変更）
            updateAnnotationImageView(existingImageView, for: postAnnotation.post)
        } else {
            // 初回のみ新規作成
            let imageView = createAnnotationImageView(for: postAnnotation.post)
            annotationImageView = imageView
            addSubview(imageView)
        }

        // コールアウトビューの再利用
        if let existingController = calloutHostingController {
            // SwiftUIビューの内容を更新
            existingController.rootView = PostCalloutView(post: postAnnotation.post)
        } else {
            // 初回のみ新規作成
            let controller = UIHostingController(rootView: PostCalloutView(post: postAnnotation.post))
            controller.view.backgroundColor = .clear
            calloutHostingController = controller
            detailCalloutAccessoryView = controller.view
        }
    }
    
    private func updateAnnotationImageView(_ containerView: UIView, for post: Post) {
        // 既存のサブビューを更新（削除せずに再設定）
        guard containerView.subviews.count >= 2 else {
            // サブビューが不足している場合は再生成
            if let annotationImageView = annotationImageView {
                annotationImageView.removeFromSuperview()
            }
            let newView = createAnnotationImageView(for: post)
            self.annotationImageView = newView
            addSubview(newView)
            return
        }

        // 背景円の色を更新
        if let circleView = containerView.subviews.first {
            circleView.backgroundColor = post.isUrgent ? .systemRed : .systemBlue
        }

        // アイコンを更新
        if containerView.subviews.count > 1, let iconImageView = containerView.subviews[1] as? UIImageView {
            iconImageView.image = post.isUrgent ?
                UIImage(systemName: "exclamationmark.triangle.fill") :
                UIImage(systemName: "newspaper.fill")
        }

        // 認証バッジの表示/非表示
        if post.isVerified {
            if containerView.subviews.count < 3 {
                // バッジを追加
                let badgeView = UIView(frame: CGRect(x: 28, y: 0, width: 12, height: 12))
                badgeView.layer.cornerRadius = 6
                badgeView.backgroundColor = .systemGreen
                badgeView.layer.borderWidth = 2
                badgeView.layer.borderColor = UIColor.white.cgColor
                badgeView.tag = 999 // 識別用タグ
                containerView.addSubview(badgeView)
            }
        } else {
            // バッジを削除
            containerView.subviews.first { $0.tag == 999 }?.removeFromSuperview()
        }
    }

    private func createAnnotationImageView(for post: Post) -> UIView {
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        
        // 背景円
        let circleView = UIView(frame: containerView.bounds)
        circleView.layer.cornerRadius = 20
        circleView.backgroundColor = post.isUrgent ? .systemRed : .systemBlue
        containerView.addSubview(circleView)

        // アイコン
        let iconImageView = UIImageView(frame: CGRect(x: 8, y: 8, width: 24, height: 24))
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white

        if post.isUrgent {
            iconImageView.image = UIImage(systemName: "exclamationmark.triangle.fill")
        } else {
            iconImageView.image = UIImage(systemName: "newspaper.fill")
        }

        containerView.addSubview(iconImageView)

        // 信頼スコアインジケータ (trustScoreは削除されたため、isVerifiedで代用)
        if post.isVerified {
            let badgeView = UIView(frame: CGRect(x: 28, y: 0, width: 12, height: 12))
            badgeView.layer.cornerRadius = 6
            badgeView.backgroundColor = .systemGreen
            badgeView.layer.borderWidth = 2
            badgeView.layer.borderColor = UIColor.white.cgColor
            containerView.addSubview(badgeView)
        }
        
        return containerView
    }
}

// MARK: - SwiftUI Callout View

struct PostCalloutView: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ユーザー情報
            HStack {
                if let avatarURL = post.user.avatarURL {
                    CachedAsyncImage(url: URL(string: avatarURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                }
                
                VStack(alignment: .leading) {
                    Text(post.user.displayName ?? post.user.username)
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Text(post.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if post.user.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
            
            // 投稿内容プレビュー
            Text(post.content)
                .font(.caption)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            
            // 緊急度表示
            if post.isUrgent {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("緊急度: 緊急")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }

            // エンゲージメント情報
            HStack {
                Label("\(post.likeCount)", systemImage: "heart.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Label("\(post.commentCount)", systemImage: "bubble.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                // 認証バッジ (trustScoreの代わりにisVerifiedを使用)
                if post.isVerified {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                        Text("認証済み")
                            .foregroundColor(.green)
                    }
                    .font(.caption2)
                }
            }
        }
        .padding(12)
        .frame(width: 280)
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }

}

// MARK: - Cluster Annotation View

class PostClusterAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "PostClusterAnnotation"
    
    override var annotation: MKAnnotation? {
        didSet {
            guard let cluster = annotation as? MKClusterAnnotation else { return }
            configureView(for: cluster)
        }
    }
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    private func setupView() {
        canShowCallout = true
        
        let size: CGFloat = 50
        frame = CGRect(x: 0, y: 0, width: size, height: size)
        centerOffset = CGPoint(x: 0, y: -size / 2)
    }
    
    private func configureView(for cluster: MKClusterAnnotation) {
        // カウントに基づいてサイズを調整
        let count = cluster.memberAnnotations.count
        let size = sizeForClusterCount(count)
        frame = CGRect(x: 0, y: 0, width: size, height: size)
        
        // 背景円
        let circleView = UIView(frame: bounds)
        circleView.layer.cornerRadius = size / 2
        circleView.backgroundColor = colorForClusterCount(count)
        
        // カウントラベル
        let label = UILabel(frame: bounds)
        label.text = "\(count)"
        label.textAlignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: fontSizeForClusterCount(count), weight: .bold)
        
        // サブビューをクリア
        subviews.forEach { $0.removeFromSuperview() }
        
        // 新しいビューを追加
        addSubview(circleView)
        addSubview(label)
        
        // 緊急投稿が含まれているかチェック
        let hasEmergency = cluster.memberAnnotations.contains { annotation in
            (annotation as? PostAnnotation)?.post.isUrgent == true
        }
        
        if hasEmergency {
            circleView.layer.borderWidth = 3
            circleView.layer.borderColor = UIColor.systemRed.cgColor
        }
    }
    
    private func sizeForClusterCount(_ count: Int) -> CGFloat {
        switch count {
        case 0...5: return 40
        case 6...10: return 45
        case 11...20: return 50
        case 21...50: return 55
        default: return 60
        }
    }
    
    private func colorForClusterCount(_ count: Int) -> UIColor {
        switch count {
        case 0...5: return .systemBlue
        case 6...10: return .systemIndigo
        case 11...20: return .systemPurple
        default: return .systemOrange
        }
    }
    
    private func fontSizeForClusterCount(_ count: Int) -> CGFloat {
        switch count {
        case 0...5: return 14
        case 6...10: return 16
        case 11...20: return 18
        default: return 20
        }
    }
}