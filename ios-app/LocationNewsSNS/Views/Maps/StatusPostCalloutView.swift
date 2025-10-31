//
//  StatusPostCalloutView.swift
//  LocationNewsSNS
//
//  ステータス投稿用のカスタムコールアウトビュー
//

import UIKit

/// ステータス投稿ピンタップ時の簡易カード表示
///
/// ユーザー名 + ステータス + 残り時間を表示するカスタムCalloutView
///
/// - Requirements: 7.3
class StatusPostCalloutView: UIView {

    // MARK: - UI Components

    private let containerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let userNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Initialization

    /// イニシャライザ
    /// - Parameter post: ステータス投稿
    init?(post: Post) {
        // ステータス投稿でない場合はnilを返す
        guard post.isStatusPost else { return nil }

        super.init(frame: .zero)

        setupUI()
        configure(with: post)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        // コンテナスタックを追加
        addSubview(containerStack)

        // ラベルをスタックに追加
        containerStack.addArrangedSubview(userNameLabel)
        containerStack.addArrangedSubview(statusLabel)
        containerStack.addArrangedSubview(timeLabel)

        // 制約を設定
        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            containerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            containerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            containerStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            // 最小幅を設定
            widthAnchor.constraint(greaterThanOrEqualToConstant: 150)
        ])

        // 背景色
        backgroundColor = .systemBackground

        // 角丸
        layer.cornerRadius = 8
        clipsToBounds = true
    }

    private func configure(with post: Post) {
        // ユーザー名
        userNameLabel.text = post.user.displayName ?? post.user.username

        // ステータス
        statusLabel.text = post.content

        // 残り時間
        if let remainingTime = post.remainingTime {
            timeLabel.text = formatRemainingTime(remainingTime)

            // 1時間未満の場合は警告色
            if remainingTime < 3600 {
                timeLabel.textColor = .systemOrange
            } else {
                timeLabel.textColor = .tertiaryLabel
            }
        } else {
            timeLabel.text = "期限切れ"
            timeLabel.textColor = .systemRed
        }

        // アクセシビリティ
        isAccessibilityElement = true
        accessibilityLabel = "\(userNameLabel.text ?? ""), \(statusLabel.text ?? ""), \(timeLabel.text ?? "")"
    }

    // MARK: - Helper Methods

    /// 残り時間をフォーマット
    /// - Parameter timeInterval: 残り時間（秒）
    /// - Returns: フォーマットされた文字列（例: "あと2時間30分で削除"）
    private func formatRemainingTime(_ timeInterval: TimeInterval) -> String {
        if timeInterval <= 0 {
            return "まもなく削除"
        }

        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60

        if hours > 0 {
            if minutes > 0 {
                return "あと\(hours)時間\(minutes)分で削除"
            } else {
                return "あと\(hours)時間で削除"
            }
        } else if minutes > 0 {
            return "あと\(minutes)分で削除"
        } else {
            return "まもなく削除"
        }
    }
}
