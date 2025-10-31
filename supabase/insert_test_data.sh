#!/bin/bash

# ========================================
# テストデータ投入スクリプト
# Supabase REST API経由でデータを投入
# ========================================

SUPABASE_URL="https://ikjxfoyfeliiovbwelyx.supabase.co"
SERVICE_ROLE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlranhmb3lmZWxpaW92YndlbHl4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDAxMjk0NSwiZXhwIjoyMDc1NTg4OTQ1fQ.9HS9-3V5jMUtnkIbIuBDZdz1kDX7eXfuETO4ATGzhhc"

echo "========================================="
echo "テストデータ投入開始"
echo "========================================="
echo ""

# ========================================
# 1. テストユーザーの投入
# ========================================
echo "1. ユーザーデータを投入中..."

curl -X POST "$SUPABASE_URL/rest/v1/users" \
  -H "apikey: $SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=minimal" \
  -d '[
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "email": "tanaka@example.com",
      "username": "tanaka_taro",
      "display_name": "田中太郎",
      "bio": "東京在住のサラリーマンです。地域の情報をシェアしています。",
      "location": "東京都渋谷区",
      "is_verified": false,
      "role": "user",
      "privacy_settings": {"locationSharing": true, "emergencyOverride": true, "locationPrecision": "city", "profileVisibility": "public"}
    },
    {
      "id": "22222222-2222-2222-2222-222222222222",
      "email": "yamada@example.com",
      "username": "yamada_hanako",
      "display_name": "山田花子",
      "bio": "横浜でカフェ巡りが好きです☕",
      "location": "神奈川県横浜市",
      "is_verified": true,
      "role": "user",
      "privacy_settings": {"locationSharing": true, "emergencyOverride": true, "locationPrecision": "city", "profileVisibility": "public"}
    },
    {
      "id": "33333333-3333-3333-3333-333333333333",
      "email": "sato@example.com",
      "username": "sato_jiro",
      "display_name": "佐藤次郎",
      "bio": "IT企業勤務。テクノロジーと地域活性化に興味があります。",
      "location": "東京都新宿区",
      "is_verified": false,
      "role": "user",
      "privacy_settings": {"locationSharing": true, "emergencyOverride": true, "locationPrecision": "approximate", "profileVisibility": "public"}
    },
    {
      "id": "44444444-4444-4444-4444-444444444444",
      "email": "moderator@example.com",
      "username": "mod_suzuki",
      "display_name": "鈴木（モデレーター）",
      "bio": "地域コミュニティのモデレーターです。",
      "location": "東京都千代田区",
      "is_verified": true,
      "role": "moderator",
      "privacy_settings": {"locationSharing": true, "emergencyOverride": true, "locationPrecision": "city", "profileVisibility": "public"}
    },
    {
      "id": "55555555-5555-5555-5555-555555555555",
      "email": "official@example.com",
      "username": "tokyo_official",
      "display_name": "東京都公式",
      "bio": "東京都の公式アカウントです。緊急情報や重要なお知らせを発信します。",
      "location": "東京都",
      "is_verified": true,
      "role": "official",
      "privacy_settings": {"locationSharing": true, "emergencyOverride": true, "locationPrecision": "city", "profileVisibility": "public"}
    }
  ]'

echo ""
echo "✓ ユーザーデータ投入完了"
echo ""

# ========================================
# 2. テスト投稿の投入
# ========================================
echo "2. 投稿データを投入中..."

curl -X POST "$SUPABASE_URL/rest/v1/posts" \
  -H "apikey: $SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=minimal" \
  -d '[
    {
      "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
      "user_id": "11111111-1111-1111-1111-111111111111",
      "content": "渋谷駅前で新しい商業施設がオープンしました！多くの人で賑わっています。",
      "category": "news",
      "latitude": 35.6580,
      "longitude": 139.7016,
      "address": "東京都渋谷区道玄坂",
      "is_urgent": false,
      "is_verified": false,
      "visibility": "public"
    },
    {
      "id": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
      "user_id": "22222222-2222-2222-2222-222222222222",
      "content": "週末に横浜でマルシェが開催されます🎪 地元の新鮮な野菜や手作り雑貨が並びます。ぜひお越しください！",
      "category": "event",
      "latitude": 35.4437,
      "longitude": 139.6380,
      "address": "神奈川県横浜市西区みなとみらい",
      "is_urgent": false,
      "is_verified": true,
      "visibility": "public"
    },
    {
      "id": "cccccccc-cccc-cccc-cccc-cccccccccccc",
      "user_id": "55555555-5555-5555-5555-555555555555",
      "content": "【緊急】新宿区で停電が発生しています。復旧作業中です。影響範囲: 新宿1-3丁目。復旧予定: 14:00頃",
      "category": "emergency",
      "latitude": 35.6938,
      "longitude": 139.7036,
      "address": "東京都新宿区新宿",
      "is_urgent": true,
      "is_verified": true,
      "visibility": "public"
    },
    {
      "id": "dddddddd-dddd-dddd-dddd-dddddddddddd",
      "user_id": "33333333-3333-3333-3333-333333333333",
      "content": "山手線の遅延情報です。現在、渋谷〜新宿間で15分程度の遅れが出ています。",
      "category": "traffic",
      "latitude": 35.6812,
      "longitude": 139.7671,
      "address": "東京都渋谷区",
      "is_urgent": false,
      "is_verified": false,
      "visibility": "public"
    },
    {
      "id": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee",
      "user_id": "11111111-1111-1111-1111-111111111111",
      "content": "今日の午後から雨が降りそうです☔ 傘を持ってお出かけください。",
      "category": "weather",
      "latitude": 35.6762,
      "longitude": 139.6503,
      "address": "東京都",
      "is_urgent": false,
      "is_verified": false,
      "visibility": "public"
    }
  ]'

echo ""
echo "✓ 投稿データ投入完了"
echo ""

echo "========================================="
echo "テストデータ投入完了！"
echo "========================================="
echo ""
echo "投入されたデータ:"
echo "- ユーザー: 5名"
echo "- 投稿: 5件"
echo ""
echo "データの確認:"
echo "curl -H \"apikey: $SERVICE_ROLE_KEY\" \"$SUPABASE_URL/rest/v1/users?select=username,email&limit=5\""
echo "curl -H \"apikey: $SERVICE_ROLE_KEY\" \"$SUPABASE_URL/rest/v1/posts?select=content,category&limit=5\""
