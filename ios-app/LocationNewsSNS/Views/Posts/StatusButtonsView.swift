import SwiftUI

/// ワンタップステータス共有のプリセットステータスボタン一覧
///
/// 横スクロール可能なレイアウトで8種類のステータスボタンを表示します。
/// ユーザーがボタンをタップすると、選択されたステータスが親Viewに通知されます。
///
/// - Requirements: 4.1, 4.2, 4.3, 4.4, 10.5, 12.3
struct StatusButtonsView: View {
    /// 選択されたステータス（親Viewとバインド）
    @Binding var selectedStatus: StatusType?

    /// ボタンが有効かどうか（位置情報パーミッションに依存）
    var isEnabled: Bool = true

    /// ボタンがタップされたときのコールバック（オプション）
    var onStatusTapped: ((StatusType) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(StatusType.allCases, id: \.self) { status in
                    StatusButton(
                        status: status,
                        isSelected: selectedStatus == status,
                        isEnabled: isEnabled
                    ) {
                        // 単一選択ロジック: タップされたステータスを選択
                        guard isEnabled else { return }
                        selectedStatus = status
                        onStatusTapped?(status)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}

// MARK: - StatusButton

/// 個別のステータスボタン
private struct StatusButton: View {
    let status: StatusType
    let isSelected: Bool
    let isEnabled: Bool
    let onTap: () -> Void

    // Dynamic Type対応のための環境変数
    @Environment(\.sizeCategory) private var sizeCategory

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: dynamicSpacing) {
                Text(status.emoji)
                    .font(.body)
                Text(status.text)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, dynamicHorizontalPadding)
            .padding(.vertical, dynamicVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.15))
            )
            .foregroundColor(isSelected ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(status.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
        .accessibilityHint("ダブルタップで選択")
    }

    // MARK: - Dynamic Type対応

    /// Dynamic Typeに応じた間隔
    private var dynamicSpacing: CGFloat {
        sizeCategory.isAccessibilityCategory ? 10 : 6
    }

    /// Dynamic Typeに応じた水平パディング
    private var dynamicHorizontalPadding: CGFloat {
        sizeCategory.isAccessibilityCategory ? 16 : 12
    }

    /// Dynamic Typeに応じた垂直パディング
    private var dynamicVerticalPadding: CGFloat {
        sizeCategory.isAccessibilityCategory ? 10 : 6
    }
}

// MARK: - Preview

#Preview("Default") {
    StatusButtonsViewPreview()
}

#Preview("With Selection") {
    StatusButtonsViewPreviewWithSelection()
}

private struct StatusButtonsViewPreview: View {
    @State private var selectedStatus: StatusType? = nil

    var body: some View {
        VStack(spacing: 20) {
            Text("選択されたステータス: \(selectedStatus?.rawValue ?? "なし")")
                .font(.headline)

            StatusButtonsView(selectedStatus: $selectedStatus)

            Spacer()
        }
        .padding()
    }
}

private struct StatusButtonsViewPreviewWithSelection: View {
    @State private var selectedStatus: StatusType? = .cafe

    var body: some View {
        VStack(spacing: 20) {
            Text("選択されたステータス: \(selectedStatus?.rawValue ?? "なし")")
                .font(.headline)

            StatusButtonsView(selectedStatus: $selectedStatus)

            Button("選択をクリア") {
                selectedStatus = nil
            }
            .padding()

            Spacer()
        }
        .padding()
    }
}
