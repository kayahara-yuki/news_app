#!/bin/bash

# テスト用シェルスクリプト
# タスク6.1: auto-delete-status-posts Edge Functionのテスト

set -e

SUPABASE_URL="https://ikjxfoyfeliiovbwelyx.supabase.co"
SERVICE_ROLE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlranhmb3lmZWxpaW92YndlbHl4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDAxMjk0NSwiZXhwIjoyMDc1NTg4OTQ1fQ.9HS9-3V5jMUtnkIbIuBDZdz1kDX7eXfuETO4ATGzhhc"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlranhmb3lmZWxpaW92YndlbHl4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAwMTI5NDUsImV4cCI6MjA3NTU4ODk0NX0.E61qFPidet3gHJpqaBLeih2atXqx5LDc9zv5onEeM30"

echo "================================"
echo "テスト開始: auto-delete-status-posts"
echo "================================"
echo ""

# ステップ1: テストデータの削除（クリーンアップ）
echo "[1/5] テストデータのクリーンアップ..."

curl -s -X POST \
  -H "apikey: $SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: params=single-object" \
  "$SUPABASE_URL/rest/v1/rpc/exec_sql" \
  -d "{\"query\": \"DELETE FROM comments WHERE post_id IN (SELECT id FROM posts WHERE user_id = '00000000-0000-0000-0000-000000000001' AND content LIKE '%テスト%'); DELETE FROM likes WHERE post_id IN (SELECT id FROM posts WHERE user_id = '00000000-0000-0000-0000-000000000001' AND content LIKE '%テスト%'); DELETE FROM posts WHERE user_id = '00000000-0000-0000-0000-000000000001' AND content LIKE '%テスト%';\"}" \
  > /dev/null 2>&1 || true

echo "✓ クリーンアップ完了"
echo ""

# ステップ2: テストデータの作成
echo "[2/5] テストデータの作成..."

# 期限切れステータス投稿1（音声あり）
curl -s -X POST \
  -H "apikey: $SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  "$SUPABASE_URL/rest/v1/posts" \
  -d '{
    "user_id": "00000000-0000-0000-0000-000000000001",
    "content": "☕ カフェなう（テスト期限切れ1）",
    "latitude": 35.6812,
    "longitude": 139.7671,
    "location": "SRID=4326;POINT(139.7671 35.6812)",
    "address": "東京都渋谷区",
    "category": "food",
    "is_status_post": true,
    "expires_at": "2025-10-28T05:00:00Z",
    "audio_url": "https://ikjxfoyfeliiovbwelyx.supabase.co/storage/v1/object/public/audio/00000000-0000-0000-0000-000000000001/test_audio_1.m4a"
  }' > /dev/null

# 期限切れステータス投稿2（音声なし）
curl -s -X POST \
  -H "apikey: $SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  "$SUPABASE_URL/rest/v1/posts" \
  -d '{
    "user_id": "00000000-0000-0000-0000-000000000001",
    "content": "🚶 散歩中（テスト期限切れ2）",
    "latitude": 35.6895,
    "longitude": 139.6917,
    "location": "SRID=4326;POINT(139.6917 35.6895)",
    "address": "東京都新宿区",
    "category": "other",
    "is_status_post": true,
    "expires_at": "2025-10-28T10:00:00Z"
  }' > /dev/null

# 有効なステータス投稿
curl -s -X POST \
  -H "apikey: $SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  "$SUPABASE_URL/rest/v1/posts" \
  -d '{
    "user_id": "00000000-0000-0000-0000-000000000001",
    "content": "📚 勉強中（テスト有効）",
    "latitude": 35.6762,
    "longitude": 139.6503,
    "location": "SRID=4326;POINT(139.6503 35.6762)",
    "address": "東京都世田谷区",
    "category": "other",
    "is_status_post": true,
    "expires_at": "2025-12-31T23:59:59Z"
  }' > /dev/null

# 通常投稿
curl -s -X POST \
  -H "apikey: $SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  "$SUPABASE_URL/rest/v1/posts" \
  -d '{
    "user_id": "00000000-0000-0000-0000-000000000001",
    "content": "通常の投稿です（テスト）",
    "latitude": 35.6812,
    "longitude": 139.7671,
    "location": "SRID=4326;POINT(139.7671 35.6812)",
    "address": "東京都渋谷区",
    "category": "other",
    "is_status_post": false
  }' > /dev/null

echo "✓ テストデータ作成完了"
echo ""

# ステップ3: 削除前の状態確認
echo "[3/5] 削除前の状態確認..."

BEFORE_EXPIRED=$(curl -s \
  -H "apikey: $SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  "$SUPABASE_URL/rest/v1/posts?select=id&user_id=eq.00000000-0000-0000-0000-000000000001&is_status_post=eq.true&expires_at=lt.$(date -u +%Y-%m-%dT%H:%M:%SZ)&content=like.*テスト*" \
  | python3 -c "import sys, json; print(len(json.load(sys.stdin)))")

BEFORE_ACTIVE=$(curl -s \
  -H "apikey: $SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  "$SUPABASE_URL/rest/v1/posts?select=id&user_id=eq.00000000-0000-0000-0000-000000000001&is_status_post=eq.true&expires_at=gte.$(date -u +%Y-%m-%dT%H:%M:%SZ)&content=like.*テスト*" \
  | python3 -c "import sys, json; print(len(json.load(sys.stdin)))")

BEFORE_NORMAL=$(curl -s \
  -H "apikey: $SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  "$SUPABASE_URL/rest/v1/posts?select=id&user_id=eq.00000000-0000-0000-0000-000000000001&is_status_post=eq.false&content=like.*テスト*" \
  | python3 -c "import sys, json; print(len(json.load(sys.stdin)))")

echo "  期限切れステータス投稿: $BEFORE_EXPIRED 件"
echo "  有効なステータス投稿: $BEFORE_ACTIVE 件"
echo "  通常投稿: $BEFORE_NORMAL 件"
echo ""

# ステップ4: Edge Functionの実行
echo "[4/5] Edge Functionの実行..."
echo ""

RESPONSE=$(curl -i --location --request POST \
  "$SUPABASE_URL/functions/v1/auto-delete-status-posts" \
  --header "Authorization: Bearer $ANON_KEY" \
  --header "Content-Type: application/json" 2>&1)

echo "$RESPONSE"
echo ""

# ステップ5: 削除後の状態確認
echo "[5/5] 削除後の状態確認..."
sleep 2  # データ反映待ち

AFTER_EXPIRED=$(curl -s \
  -H "apikey: $SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  "$SUPABASE_URL/rest/v1/posts?select=id&user_id=eq.00000000-0000-0000-0000-000000000001&is_status_post=eq.true&expires_at=lt.$(date -u +%Y-%m-%dT%H:%M:%SZ)&content=like.*テスト*" \
  | python3 -c "import sys, json; print(len(json.load(sys.stdin)))")

AFTER_ACTIVE=$(curl -s \
  -H "apikey: $SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  "$SUPABASE_URL/rest/v1/posts?select=id&user_id=eq.00000000-0000-0000-0000-000000000001&is_status_post=eq.true&expires_at=gte.$(date -u +%Y-%m-%dT%H:%M:%SZ)&content=like.*テスト*" \
  | python3 -c "import sys, json; print(len(json.load(sys.stdin)))")

AFTER_NORMAL=$(curl -s \
  -H "apikey: $SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  "$SUPABASE_URL/rest/v1/posts?select=id&user_id=eq.00000000-0000-0000-0000-000000000001&is_status_post=eq.false&content=like.*テスト*" \
  | python3 -c "import sys, json; print(len(json.load(sys.stdin)))")

echo "  期限切れステータス投稿: $AFTER_EXPIRED 件（期待値: 0）"
echo "  有効なステータス投稿: $AFTER_ACTIVE 件（期待値: 1）"
echo "  通常投稿: $AFTER_NORMAL 件（期待値: 1）"
echo ""

# 結果判定
echo "================================"
if [ "$AFTER_EXPIRED" -eq 0 ] && [ "$AFTER_ACTIVE" -eq 1 ] && [ "$AFTER_NORMAL" -eq 1 ]; then
  echo "✓ テスト成功"
else
  echo "✗ テスト失敗"
  exit 1
fi
echo "================================"
