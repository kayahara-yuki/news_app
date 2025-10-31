import SwiftUI
import MapKit
import Combine

// MARK: - MapKit統合ビュー

struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var posts: [Post]
    @Binding var selectedPost: Post?

    let showUserLocation: Bool
    let showEmergencies: Bool
    let showShelters: Bool
    let onPostSelected: ((Post) -> Void)?
    let onRegionChanged: ((CLLocationCoordinate2D) -> Void)?

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: MapView

        init(_ parent: MapView) {
            self.parent = parent
        }

        // MARK: - UIGestureRecognizerDelegate

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // 地図の他のジェスチャーと同時に認識を許可
            return true
        }

        // MARK: - Annotation Views

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            if let postAnnotation = annotation as? PostAnnotation {
                let post = postAnnotation.post

                // ステータス投稿の場合は専用ピンを表示
                if post.isStatusPost, let statusType = post.statusType {
                    let identifier = "StatusPostAnnotation"
                    let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)

                    if let markerView = view as? MKMarkerAnnotationView {
                        // 絵文字をテキストとして表示
                        markerView.glyphText = statusType.emoji

                        // 残り時間が1時間未満の場合は透明度を50%に
                        if let remainingTime = post.remainingTime, remainingTime < 3600 {
                            markerView.alpha = 0.5
                        } else {
                            markerView.alpha = 1.0
                        }

                        // ステータス投稿は緑色のマーカー
                        markerView.markerTintColor = .systemGreen
                        markerView.titleVisibility = .adaptive
                    }

                    view.canShowCallout = true
                    // ステータス投稿用のカスタムCalloutViewを設定
                    if let calloutView = StatusPostCalloutView(post: post) {
                        view.detailCalloutAccessoryView = calloutView
                    }

                    return view
                }

                // 通常投稿の場合
                let identifier = "PostAnnotation"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)

                if let markerView = view as? MKMarkerAnnotationView {
                    markerView.glyphImage = UIImage(systemName: "newspaper.fill")
                    markerView.markerTintColor = post.isUrgent ? .red : .blue
                    markerView.titleVisibility = .adaptive
                }

                view.canShowCallout = true
                view.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)

                return view
            }

            if let shelterAnnotation = annotation as? ShelterAnnotation {
                let identifier = "ShelterAnnotation"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)

                if let markerView = view as? MKMarkerAnnotationView {
                    markerView.glyphImage = UIImage(systemName: "house.fill")
                    markerView.markerTintColor = .green
                    markerView.titleVisibility = .adaptive
                }

                view.canShowCallout = true

                return view
            }

            return nil
        }

        // MARK: - User Interaction

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            if let postAnnotation = view.annotation as? PostAnnotation {
                parent.selectedPost = postAnnotation.post
                parent.onPostSelected?(postAnnotation.post)
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region

            // マップ移動時に周辺の投稿を取得
            parent.onRegionChanged?(mapView.region.center)
        }

        // MARK: - Overlay Rendering

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circleOverlay = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circleOverlay)
                renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.7)
                renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.2)
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // MARK: - Clustering

        func mapView(_ mapView: MKMapView, clusterAnnotationForMemberAnnotations memberAnnotations: [MKAnnotation]) -> MKClusterAnnotation {
            let cluster = MKClusterAnnotation(memberAnnotations: memberAnnotations)
            cluster.title = "\(memberAnnotations.count) 件の投稿"
            cluster.subtitle = "タップして詳細を表示"
            return cluster
        }

        // MARK: - Map Tap Gesture

        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }

            // タップ位置を取得
            let location = gesture.location(in: mapView)

            // タップ位置にアノテーションがあるかチェック
            let tapPoint = CGPoint(x: location.x, y: location.y)
            var tappedAnnotation = false

            for annotation in mapView.annotations {
                if let annotationView = mapView.view(for: annotation) {
                    let annotationPoint = annotationView.frame
                    if annotationPoint.contains(tapPoint) {
                        tappedAnnotation = true
                        break
                    }
                }
            }

            // アノテーション以外の場所をタップした場合、選択を解除
            if !tappedAnnotation, let selectedAnnotations = mapView.selectedAnnotations.first {
                mapView.deselectAnnotation(selectedAnnotations, animated: true)
            }
        }
    }

    // MARK: - UIViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showUserLocation
        mapView.userTrackingMode = .none
        mapView.mapType = .standard

        // iOS 17+ の新機能活用
        if #available(iOS 17.0, *) {
            mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic)
        }

        // 地図の基本設定
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsTraffic = false
        mapView.showsBuildings = true
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        if #available(iOS 17.0, *) {
            mapView.showsUserTrackingButton = showUserLocation
        }

        // 新規投稿作成の通知を監視
        NotificationCenter.default.addObserver(
            forName: .newPostCreated,
            object: nil,
            queue: .main
        ) { [weak mapView] notification in
            print("[MapView] 📬 newPostCreated notification received")

            if let post = notification.userInfo?["post"] as? Post {
                print("[MapView] 📍 Post data: id=\(post.id), content=\(post.content.prefix(30))...")
                print("[MapView] 📍 Location: lat=\(post.latitude ?? 0), lng=\(post.longitude ?? 0)")
                print("[MapView] 📍 Address: \(post.address ?? "nil")")
                print("[MapView] 📍 canShowOnMap: \(post.canShowOnMap)")

                if let annotation = PostAnnotation(post: post) {
                    print("[MapView] ✅ PostAnnotation created successfully")
                    mapView?.addAnnotation(annotation)
                    print("[MapView] ✅ Annotation added to map")
                } else {
                    print("[MapView] ❌ Failed to create PostAnnotation")
                }
            } else {
                print("[MapView] ❌ Failed to extract post from notification")
            }
        }

        // 投稿更新の通知を監視（いいね数などの更新）
        // Note: このMapViewは現在使用されていません（ContentViewではSwiftUIのMapを使用）
        // 将来的にUIKit版のMapViewに切り替える場合のために残しています
        NotificationCenter.default.addObserver(
            forName: .postUpdated,
            object: nil,
            queue: .main
        ) { [weak mapView] notification in
            guard let postId = notification.userInfo?["postId"] as? UUID,
                  let likeCount = notification.userInfo?["likeCount"] as? Int else {
                return
            }

            // 該当する投稿のアノテーションを探して更新
            if let postAnnotation = mapView?.annotations.first(where: { annotation in
                (annotation as? PostAnnotation)?.post.id == postId
            }) as? PostAnnotation {
                // コールアウトが表示されているか確認
                let isCalloutVisible = mapView?.selectedAnnotations.contains(where: { $0 === postAnnotation }) == true

                // アノテーションを削除して再追加することで、コールアウトビューを更新
                mapView?.removeAnnotation(postAnnotation)

                // 投稿データを更新（新しいインスタンスを作成）
                let originalPost = postAnnotation.post
                let updatedPost = Post(
                    id: originalPost.id,
                    user: originalPost.user,
                    content: originalPost.content,
                    url: originalPost.url,
                    latitude: originalPost.latitude,
                    longitude: originalPost.longitude,
                    address: originalPost.address,
                    category: originalPost.category,
                    visibility: originalPost.visibility,
                    isUrgent: originalPost.isUrgent,
                    isVerified: originalPost.isVerified,
                    likeCount: likeCount,
                    commentCount: originalPost.commentCount,
                    shareCount: originalPost.shareCount,
                    createdAt: originalPost.createdAt,
                    updatedAt: originalPost.updatedAt,
                    audioURL: originalPost.audioURL,
                    isStatusPost: originalPost.isStatusPost,
                    expiresAt: originalPost.expiresAt
                )

                // 新しいアノテーションを追加
                if let newAnnotation = PostAnnotation(post: updatedPost) {
                    mapView?.addAnnotation(newAnnotation)

                    // コールアウトが表示されていた場合は再度選択
                    if isCalloutVisible {
                        mapView?.selectAnnotation(newAnnotation, animated: false)
                    }
                }
            }
        }

        // 地図タップジェスチャーを追加（吹き出しを閉じるため）
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMapTap(_:))
        )
        tapGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    static func dismantleUIView(_ mapView: MKMapView, coordinator: Coordinator) {
        // 通知の監視を解除
        NotificationCenter.default.removeObserver(mapView, name: .newPostCreated, object: nil)
        NotificationCenter.default.removeObserver(mapView, name: .postUpdated, object: nil)
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // リージョンの更新
        if mapView.region.center.latitude != region.center.latitude ||
           mapView.region.center.longitude != region.center.longitude {
            mapView.setRegion(region, animated: true)
        }

        // 5km圏内の円を表示
        update5kmCircle(mapView: mapView)

        // アノテーションの更新
        updateAnnotations(mapView: mapView)
    }

    // MARK: - Private Methods

    private func update5kmCircle(mapView: MKMapView) {
        // 既存の円オーバーレイを削除
        mapView.overlays.forEach { overlay in
            if overlay is MKCircle {
                mapView.removeOverlay(overlay)
            }
        }

        // マップの中心座標に5km圏内の円を追加
        let circle = MKCircle(center: region.center, radius: 5000) // 5km = 5000m
        mapView.addOverlay(circle)
    }

    private func updateAnnotations(mapView: MKMapView) {
        // パフォーマンス最適化: 差分更新を実装
        // 全削除・全追加ではなく、変更があった部分のみ更新

        // 既存の投稿アノテーションを取得（ユーザー位置以外）
        let existingPostAnnotations = mapView.annotations.compactMap { $0 as? PostAnnotation }
        let existingPostIDs = Set(existingPostAnnotations.map { $0.post.id })

        // 新しい投稿アノテーションを生成（位置情報が有効な投稿のみ）
        let newPostAnnotations = posts.compactMap { PostAnnotation(post: $0) }
        let newPostIDs = Set(newPostAnnotations.map { $0.post.id })

        // 削除すべきアノテーション（既存にあるが新規にない）
        let annotationsToRemove = existingPostAnnotations.filter { !newPostIDs.contains($0.post.id) }
        if !annotationsToRemove.isEmpty {
            mapView.removeAnnotations(annotationsToRemove)
        }

        // 追加すべきアノテーション（新規にあるが既存にない）
        let annotationsToAdd = newPostAnnotations.filter { !existingPostIDs.contains($0.post.id) }
        if !annotationsToAdd.isEmpty {
            mapView.addAnnotations(annotationsToAdd)
        }

        // 既存のアノテーションのうち、いいね数などが変更された可能性があるものを更新
        // PostAnnotationはクラスなのでPostオブジェクトが更新されても参照は同じ
        // そのため、いいね数などが変更された投稿は削除→再追加して更新
        let postsMap = Dictionary(uniqueKeysWithValues: posts.map { ($0.id, $0) })
        let annotationsToUpdate = existingPostAnnotations.filter { annotation in
            guard let updatedPost = postsMap[annotation.post.id] else { return false }
            // いいね数、コメント数、シェア数が異なる場合は更新が必要
            return annotation.post.likeCount != updatedPost.likeCount ||
                   annotation.post.commentCount != updatedPost.commentCount ||
                   annotation.post.shareCount != updatedPost.shareCount
        }

        if !annotationsToUpdate.isEmpty {
            // 更新が必要なアノテーションを削除
            mapView.removeAnnotations(annotationsToUpdate)
            // 最新データで再作成して追加
            let updatedAnnotations = annotationsToUpdate.compactMap { oldAnnotation -> PostAnnotation? in
                guard let updatedPost = postsMap[oldAnnotation.post.id] else { return nil }
                return PostAnnotation(post: updatedPost)
            }
            mapView.addAnnotations(updatedAnnotations)
        }

        // 緊急事態のアノテーションを追加
        if showEmergencies {
            // TODO: 緊急事態のアノテーション追加
        }

        // 避難所のアノテーションを追加
        if showShelters {
            // TODO: 避難所のアノテーション追加
        }
    }
}

// MARK: - Post Annotation
// Note: PostAnnotationは Models/MapAnnotations.swift で定義されています
