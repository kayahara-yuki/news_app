#!/usr/bin/env python3
"""
テストデータ作成スクリプト
タスク6.1: auto-delete-status-posts Edge Functionのテスト
"""

import requests
import json
from datetime import datetime, timedelta

SUPABASE_URL = "https://ikjxfoyfeliiovbwelyx.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlranhmb3lmZWxpaW92YndlbHl4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDAxMjk0NSwiZXhwIjoyMDc1NTg4OTQ1fQ.9HS9-3V5jMUtnkIbIuBDZdz1kDX7eXfuETO4ATGzhhc"

headers = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation"
}

def delete_test_data():
    """既存のテストデータを削除"""
    print("[1/4] クリーンアップ中...")

    # テスト投稿を検索
    response = requests.get(
        f"{SUPABASE_URL}/rest/v1/posts",
        headers=headers,
        params={
            "select": "id",
            "user_id": "eq.00000000-0000-0000-0000-000000000001",
            "content": "like.*テスト*"
        }
    )

    if response.status_code == 200:
        posts = response.json()
        for post in posts:
            # 関連データ削除
            requests.delete(
                f"{SUPABASE_URL}/rest/v1/comments",
                headers=headers,
                params={"post_id": f"eq.{post['id']}"}
            )
            requests.delete(
                f"{SUPABASE_URL}/rest/v1/likes",
                headers=headers,
                params={"post_id": f"eq.{post['id']}"}
            )
            # 投稿削除
            requests.delete(
                f"{SUPABASE_URL}/rest/v1/posts",
                headers=headers,
                params={"id": f"eq.{post['id']}"}
            )
        print(f"  削除完了: {len(posts)}件")
    else:
        print(f"  エラー: {response.status_code}")

def create_test_posts():
    """テストデータを作成"""
    print("[2/4] テストデータ作成中...")

    posts = [
        {
            "user_id": "00000000-0000-0000-0000-000000000001",
            "content": "☕ カフェなう（テスト期限切れ1）",
            "latitude": 35.6812,
            "longitude": 139.7671,
            "address": "東京都渋谷区",
            "category": "food",
            "is_status_post": True,
            "expires_at": (datetime.now() - timedelta(hours=1)).isoformat() + "Z",
            "audio_url": "https://ikjxfoyfeliiovbwelyx.supabase.co/storage/v1/object/public/audio/test_audio_1.m4a"
        },
        {
            "user_id": "00000000-0000-0000-0000-000000000001",
            "content": "🚶 散歩中（テスト期限切れ2）",
            "latitude": 35.6895,
            "longitude": 139.6917,
            "address": "東京都新宿区",
            "category": "other",
            "is_status_post": True,
            "expires_at": (datetime.now() - timedelta(minutes=30)).isoformat() + "Z",
        },
        {
            "user_id": "00000000-0000-0000-0000-000000000001",
            "content": "📚 勉強中（テスト有効）",
            "latitude": 35.6762,
            "longitude": 139.6503,
            "address": "東京都世田谷区",
            "category": "other",
            "is_status_post": True,
            "expires_at": (datetime.now() + timedelta(hours=2)).isoformat() + "Z",
        },
        {
            "user_id": "00000000-0000-0000-0000-000000000001",
            "content": "通常の投稿です（テスト）",
            "latitude": 35.6812,
            "longitude": 139.7671,
            "address": "東京都渋谷区",
            "category": "other",
            "is_status_post": False,
        }
    ]

    created = 0
    for post_data in posts:
        response = requests.post(
            f"{SUPABASE_URL}/rest/v1/posts",
            headers=headers,
            json=post_data
        )

        if response.status_code in [200, 201]:
            created += 1
            result = response.json()
            if isinstance(result, list) and len(result) > 0:
                print(f"  ✓ 作成成功: {post_data['content']} (ID: {result[0]['id']})")
            else:
                print(f"  ✓ 作成成功: {post_data['content']}")
        else:
            print(f"  ✗ 作成失敗: {post_data['content']} - {response.status_code}: {response.text}")

    print(f"  作成完了: {created}/{len(posts)}件")

def check_before_state():
    """削除前の状態確認"""
    print("[3/4] 削除前の状態確認...")

    now = datetime.now().isoformat() + "Z"

    # 期限切れステータス投稿
    response = requests.get(
        f"{SUPABASE_URL}/rest/v1/posts",
        headers=headers,
        params={
            "select": "id,content,expires_at",
            "user_id": "eq.00000000-0000-0000-0000-000000000001",
            "is_status_post": "eq.true",
            "expires_at": f"lt.{now}",
            "content": "like.*テスト*"
        }
    )

    if response.status_code == 200:
        expired_posts = response.json()
        print(f"  期限切れステータス投稿: {len(expired_posts)}件")
        for post in expired_posts:
            print(f"    - {post['content']} (expires: {post['expires_at']})")

    # 有効なステータス投稿
    response = requests.get(
        f"{SUPABASE_URL}/rest/v1/posts",
        headers=headers,
        params={
            "select": "id,content,expires_at",
            "user_id": "eq.00000000-0000-0000-0000-000000000001",
            "is_status_post": "eq.true",
            "expires_at": f"gte.{now}",
            "content": "like.*テスト*"
        }
    )

    if response.status_code == 200:
        active_posts = response.json()
        print(f"  有効なステータス投稿: {len(active_posts)}件")

    # 通常投稿
    response = requests.get(
        f"{SUPABASE_URL}/rest/v1/posts",
        headers=headers,
        params={
            "select": "id,content",
            "user_id": "eq.00000000-0000-0000-0000-000000000001",
            "is_status_post": "eq.false",
            "content": "like.*テスト*"
        }
    )

    if response.status_code == 200:
        normal_posts = response.json()
        print(f"  通常投稿: {len(normal_posts)}件")

def main():
    print("=" * 50)
    print("テストデータ作成スクリプト")
    print("=" * 50)
    print()

    delete_test_data()
    print()

    create_test_posts()
    print()

    check_before_state()
    print()

    print("=" * 50)
    print("✓ テストデータ作成完了")
    print("=" * 50)
    print()
    print("次のステップ:")
    print("1. Edge Functionをデプロイ（DEPLOY.md参照）")
    print("2. Edge Functionを実行")
    print("3. 削除後の状態を確認")

if __name__ == "__main__":
    main()
