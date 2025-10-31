// Test Script: Supabase Storage Audio Upload
// Feature: viral-quick-win-features
// Purpose: Verify audio bucket and RLS policies are correctly configured
//
// Usage:
// 1. Copy this file to your iOS project (for temporary testing)
// 2. Call testStorageSetup() from a View or ViewModel
// 3. Check console output for test results
// 4. Remove this file after verification

import Foundation
import Supabase

/// テスト用のストレージセットアップ検証関数
/// - Note: 本番コードには含めないこと。開発環境でのみ使用。
@MainActor
class StorageSetupTester {

    private let supabase: SupabaseClient

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    /// Supabase Storageのセットアップを検証
    /// - Returns: テスト結果（成功/失敗）
    func runTests() async -> Bool {
        print("========================================")
        print("🧪 Supabase Storage Setup Tests")
        print("========================================")

        var allTestsPassed = true

        // Test 1: 認証確認
        allTestsPassed = allTestsPassed && await testAuthentication()

        // Test 2: ファイルアップロード
        allTestsPassed = allTestsPassed && await testFileUpload()

        // Test 3: ファイル読み取り
        allTestsPassed = allTestsPassed && await testFileRead()

        // Test 4: ファイル削除
        allTestsPassed = allTestsPassed && await testFileDelete()

        // Test 5: 他人のフォルダへのアップロード（失敗することを確認）
        allTestsPassed = allTestsPassed && await testUnauthorizedUpload()

        print("========================================")
        if allTestsPassed {
            print("✅ All tests passed!")
        } else {
            print("❌ Some tests failed. Check logs above.")
        }
        print("========================================")

        return allTestsPassed
    }

    // MARK: - Individual Tests

    /// Test 1: 認証状態の確認
    private func testAuthentication() async -> Bool {
        print("\n[Test 1] Authentication Check")

        do {
            let session = try await supabase.auth.session
            print("✅ User authenticated: \(session.user.id)")
            return true
        } catch {
            print("❌ Authentication failed: \(error.localizedDescription)")
            print("   Make sure user is logged in before running tests")
            return false
        }
    }

    /// Test 2: ファイルアップロード（自分のフォルダ）
    private func testFileUpload() async -> Bool {
        print("\n[Test 2] File Upload (Own Folder)")

        do {
            // テスト用データ
            let testData = createTestAudioData()

            // ユーザーID取得
            let userId = try await supabase.auth.session.user.id

            // ファイルパス生成
            let fileName = "test_\(Date().timeIntervalSince1970).m4a"
            let filePath = "\(userId.uuidString)/\(fileName)"

            // アップロード実行
            let response = try await supabase.storage
                .from("audio")
                .upload(path: filePath, data: testData)

            print("✅ Upload successful: \(response)")
            print("   File path: audio/\(filePath)")

            // テスト用ファイルパスを保存（後続テストで使用）
            UserDefaults.standard.set(filePath, forKey: "test_audio_path")

            return true
        } catch {
            print("❌ Upload failed: \(error.localizedDescription)")
            print("   Check if 'audio' bucket exists and RLS policies are configured")
            return false
        }
    }

    /// Test 3: ファイル読み取り（公開URL取得）
    private func testFileRead() async -> Bool {
        print("\n[Test 3] File Read (Public URL)")

        guard let filePath = UserDefaults.standard.string(forKey: "test_audio_path") else {
            print("❌ No test file found. Run Test 2 first.")
            return false
        }

        do {
            // Public URL取得
            let publicURL = try supabase.storage
                .from("audio")
                .getPublicURL(path: filePath)

            print("✅ Public URL retrieved: \(publicURL)")

            // URLからデータダウンロードを試行
            let (data, response) = try await URLSession.shared.data(from: publicURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ Failed to download file from public URL")
                return false
            }

            print("✅ File downloaded successfully (\(data.count) bytes)")
            return true
        } catch {
            print("❌ Read failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Test 4: ファイル削除（自分のファイル）
    private func testFileDelete() async -> Bool {
        print("\n[Test 4] File Delete (Own File)")

        guard let filePath = UserDefaults.standard.string(forKey: "test_audio_path") else {
            print("❌ No test file found. Run Test 2 first.")
            return false
        }

        do {
            // 削除実行
            try await supabase.storage
                .from("audio")
                .remove(paths: [filePath])

            print("✅ Delete successful: audio/\(filePath)")

            // テスト用ファイルパスをクリア
            UserDefaults.standard.removeObject(forKey: "test_audio_path")

            return true
        } catch {
            print("❌ Delete failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Test 5: 他人のフォルダへのアップロード（失敗することを確認）
    private func testUnauthorizedUpload() async -> Bool {
        print("\n[Test 5] Unauthorized Upload (Should Fail)")

        do {
            // テスト用データ
            let testData = createTestAudioData()

            // 別のユーザーIDを使用（ダミー）
            let otherUserId = UUID().uuidString
            let fileName = "unauthorized_test.m4a"
            let filePath = "\(otherUserId)/\(fileName)"

            // アップロード試行（失敗するはず）
            let _ = try await supabase.storage
                .from("audio")
                .upload(path: filePath, data: testData)

            print("❌ Unauthorized upload succeeded (RLS policy not working!)")
            print("   This is a security issue - check RLS policies")
            return false
        } catch {
            print("✅ Unauthorized upload blocked (as expected)")
            print("   RLS policy is working correctly")
            return true
        }
    }

    // MARK: - Helper Methods

    /// テスト用のダミー音声データを生成
    private func createTestAudioData() -> Data {
        // 簡易的なAAC形式のヘッダー（実際の音声データではないが、テストには十分）
        var data = Data()

        // AAC-LC, 44.1kHz, Mono のヘッダー
        let header: [UInt8] = [
            0xFF, 0xF1, // ADTS sync word
            0x50, 0x80, // MPEG-4 AAC-LC, 44.1kHz
            0x00, 0x1F, 0xFC // Frame length
        ]

        data.append(contentsOf: header)

        // ダミーデータ追加（約1KB）
        let dummyBytes = [UInt8](repeating: 0x00, count: 1024)
        data.append(contentsOf: dummyBytes)

        return data
    }
}

// MARK: - Usage Example

/*
 使用例（ViewModelまたはViewから呼び出し）:

 import SwiftUI

 struct StorageTestView: View {
     @State private var testResult: String = ""

     var body: some View {
         VStack {
             Text(testResult)
                 .padding()

             Button("Run Storage Tests") {
                 Task {
                     let tester = StorageSetupTester(
                         supabase: SupabaseConfig.shared.client
                     )
                     let passed = await tester.runTests()
                     testResult = passed ? "✅ All tests passed" : "❌ Tests failed"
                 }
             }
         }
     }
 }
 */
