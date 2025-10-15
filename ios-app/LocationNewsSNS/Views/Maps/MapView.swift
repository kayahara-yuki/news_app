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
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        
        init(_ parent: MapView) {
            self.parent = parent
        }
        
        // MARK: - Annotation Views
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            
            if let postAnnotation = annotation as? PostAnnotation {
                let identifier = "PostAnnotation"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                
                if let markerView = view as? MKMarkerAnnotationView {
                    markerView.glyphImage = UIImage(systemName: "newspaper.fill")
                    markerView.markerTintColor = postAnnotation.post.isUrgent ? .red : .blue
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
            if let post = notification.userInfo?["post"] as? Post,
               let annotation = PostAnnotation(post: post) {
                mapView?.addAnnotation(annotation)
            }
        }

        return mapView
    }

    static func dismantleUIView(_ mapView: MKMapView, coordinator: Coordinator) {
        // 通知の監視を解除
        NotificationCenter.default.removeObserver(mapView, name: .newPostCreated, object: nil)
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

        // Note: 既に存在するアノテーションは再利用されるため、更新不要
        // MapKitが自動的にアノテーションビューを再利用します

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

