-- ========================================
-- テストデータ投入用SQL（PostGIS対応版）
-- Supabase Dashboard > SQL Editorで実行してください
-- Location News SNS
-- ========================================

-- PostGIS拡張が有効か確認（既に有効なはずですが念のため）
CREATE EXTENSION IF NOT EXISTS postgis;

-- 既存のテストデータをクリア（開発環境のみ）
DELETE FROM public.comments WHERE user_id IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333',
  '44444444-4444-4444-4444-444444444444',
  '55555555-5555-5555-5555-555555555555'
);

DELETE FROM public.likes WHERE user_id IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333',
  '44444444-4444-4444-4444-444444444444',
  '55555555-5555-5555-5555-555555555555'
);

DELETE FROM public.posts WHERE user_id IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333',
  '44444444-4444-4444-4444-444444444444',
  '55555555-5555-5555-5555-555555555555'
);

DELETE FROM public.users WHERE id IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333',
  '44444444-4444-4444-4444-444444444444',
  '55555555-5555-5555-5555-555555555555'
);

-- ========================================
-- 1. テストユーザーの作成
-- ========================================

INSERT INTO public.users (id, email, username, display_name, bio, avatar_url, location, is_verified, role, privacy_settings, created_at, updated_at) VALUES
('11111111-1111-1111-1111-111111111111', 'tanaka@example.com', 'tanaka_taro', '田中太郎', '東京在住のサラリーマンです。地域の情報をシェアしています。', 'https://i.pravatar.cc/150?img=1', '東京都渋谷区', false, 'user', '{"locationSharing": true, "emergencyOverride": true, "locationPrecision": "city", "profileVisibility": "public"}', NOW() - INTERVAL '30 days', NOW()),
('22222222-2222-2222-2222-222222222222', 'yamada@example.com', 'yamada_hanako', '山田花子', '横浜でカフェ巡りが好きです☕', 'https://i.pravatar.cc/150?img=5', '神奈川県横浜市', true, 'user', '{"locationSharing": true, "emergencyOverride": true, "locationPrecision": "city", "profileVisibility": "public"}', NOW() - INTERVAL '60 days', NOW()),
('33333333-3333-3333-3333-333333333333', 'sato@example.com', 'sato_jiro', '佐藤次郎', 'IT企業勤務。テクノロジーと地域活性化に興味があります。', 'https://i.pravatar.cc/150?img=12', '東京都新宿区', false, 'user', '{"locationSharing": true, "emergencyOverride": true, "locationPrecision": "approximate", "profileVisibility": "public"}', NOW() - INTERVAL '45 days', NOW()),
('44444444-4444-4444-4444-444444444444', 'moderator@example.com', 'mod_suzuki', '鈴木（モデレーター）', '地域コミュニティのモデレーターです。', 'https://i.pravatar.cc/150?img=8', '東京都千代田区', true, 'moderator', '{"locationSharing": true, "emergencyOverride": true, "locationPrecision": "city", "profileVisibility": "public"}', NOW() - INTERVAL '90 days', NOW()),
('55555555-5555-5555-5555-555555555555', 'official@example.com', 'tokyo_official', '東京都公式', '東京都の公式アカウントです。緊急情報や重要なお知らせを発信します。', 'https://i.pravatar.cc/150?img=20', '東京都', true, 'official', '{"locationSharing": true, "emergencyOverride": true, "locationPrecision": "city", "profileVisibility": "public"}', NOW() - INTERVAL '180 days', NOW());

-- ========================================
-- 2. テスト投稿の作成（PostGIS location付き）
-- ========================================

INSERT INTO public.posts (id, user_id, content, url, category, location, latitude, longitude, address, is_urgent, is_verified, visibility, like_count, comment_count, share_count, created_at, updated_at) VALUES
-- ニュース投稿（渋谷）
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', '渋谷駅前で新しい商業施設がオープンしました！多くの人で賑わっています。', null, 'news', ST_GeogFromText('POINT(139.7016 35.6580)'), 35.6580, 139.7016, '東京都渋谷区道玄坂', false, false, 'public', 0, 0, 0, NOW() - INTERVAL '2 hours', NOW() - INTERVAL '2 hours'),

-- イベント投稿（横浜）
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', '週末に横浜でマルシェが開催されます🎪 地元の新鮮な野菜や手作り雑貨が並びます。ぜひお越しください！', null, 'event', ST_GeogFromText('POINT(139.6380 35.4437)'), 35.4437, 139.6380, '神奈川県横浜市西区みなとみらい', false, true, 'public', 0, 0, 0, NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),

-- 緊急情報（新宿）
('cccccccc-cccc-cccc-cccc-cccccccccccc', '55555555-5555-5555-5555-555555555555', '【緊急】新宿区で停電が発生しています。復旧作業中です。影響範囲: 新宿1-3丁目。復旧予定: 14:00頃', null, 'emergency', ST_GeogFromText('POINT(139.7036 35.6938)'), 35.6938, 139.7036, '東京都新宿区新宿', true, true, 'public', 0, 0, 0, NOW() - INTERVAL '30 minutes', NOW() - INTERVAL '30 minutes'),

-- 交通情報（渋谷）
('dddddddd-dddd-dddd-dddd-dddddddddddd', '33333333-3333-3333-3333-333333333333', '山手線の遅延情報です。現在、渋谷〜新宿間で15分程度の遅れが出ています。', null, 'traffic', ST_GeogFromText('POINT(139.7671 35.6812)'), 35.6812, 139.7671, '東京都渋谷区', false, false, 'public', 0, 0, 0, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '3 hours'),

-- 天気情報（東京）
('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '11111111-1111-1111-1111-111111111111', '今日の午後から雨が降りそうです☔ 傘を持ってお出かけください。', null, 'weather', ST_GeogFromText('POINT(139.6503 35.6762)'), 35.6762, 139.6503, '東京都', false, false, 'public', 0, 0, 0, NOW() - INTERVAL '5 hours', NOW() - INTERVAL '5 hours'),

-- ソーシャル投稿（代々木公園）
('ffffffff-ffff-ffff-ffff-ffffffffffff', '22222222-2222-2222-2222-222222222222', '代々木公園でお花見🌸 満開でとても綺麗です！', null, 'social', ST_GeogFromText('POINT(139.6966 35.6717)'), 35.6717, 139.6966, '東京都渋谷区代々木公園', false, false, 'public', 0, 0, 0, NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),

-- ビジネス投稿（表参道）
('10000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', '表参道に新しいカフェがオープン☕ おしゃれな内装で居心地が良いです。おすすめ！', null, 'business', ST_GeogFromText('POINT(139.7100 35.6654)'), 35.6654, 139.7100, '東京都渋谷区神宮前', false, false, 'public', 0, 0, 0, NOW() - INTERVAL '6 hours', NOW() - INTERVAL '6 hours'),

-- その他の投稿（新宿）
('10000000-0000-0000-0000-000000000002', '44444444-4444-4444-4444-444444444444', '地域の清掃活動ボランティア募集中です。毎週日曜日の朝8時から行っています。', null, 'other', ST_GeogFromText('POINT(139.7036 35.6938)'), 35.6938, 139.7036, '東京都新宿区', false, true, 'public', 0, 0, 0, NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days'),

-- 緊急度の高い投稿（品川）
('10000000-0000-0000-0000-000000000003', '55555555-5555-5555-5555-555555555555', '【注意】品川駅周辺で不審物が発見されました。警察が対応中です。周辺の方はご注意ください。', null, 'emergency', ST_GeogFromText('POINT(139.7387 35.6284)'), 35.6284, 139.7387, '東京都港区高輪', true, true, 'public', 0, 0, 0, NOW() - INTERVAL '1 hour', NOW() - INTERVAL '1 hour'),

-- 天気（横浜）
('10000000-0000-0000-0000-000000000004', '22222222-2222-2222-2222-222222222222', '横浜は今日は快晴です！海沿いを散歩するのに最高の天気☀️', null, 'weather', ST_GeogFromText('POINT(139.6380 35.4437)'), 35.4437, 139.6380, '神奈川県横浜市中区', false, false, 'public', 0, 0, 0, NOW() - INTERVAL '8 hours', NOW() - INTERVAL '8 hours');

-- ========================================
-- 3. コメントの作成
-- ========================================

INSERT INTO public.comments (id, post_id, user_id, content, like_count, created_at, updated_at) VALUES
('c0000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', '行ってみたいです！どんなお店が入ってるんですか？', 0, NOW() - INTERVAL '1 hour', NOW() - INTERVAL '1 hour'),
('c0000000-0000-0000-0000-000000000002', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333333', 'さっき前を通りました。確かに混雑してますね。', 0, NOW() - INTERVAL '1 hour 30 minutes', NOW() - INTERVAL '1 hour 30 minutes'),
('c0000000-0000-0000-0000-000000000003', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'ファッションブランドとカフェが多いですよ！', 0, NOW() - INTERVAL '45 minutes', NOW() - INTERVAL '45 minutes'),
('c0000000-0000-0000-0000-000000000004', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', '何時からですか？', 0, NOW() - INTERVAL '20 hours', NOW() - INTERVAL '20 hours'),
('c0000000-0000-0000-0000-000000000005', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '33333333-3333-3333-3333-333333333333', '家族で行きたいです！', 0, NOW() - INTERVAL '18 hours', NOW() - INTERVAL '18 hours'),
('c0000000-0000-0000-0000-000000000006', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', '新宿2丁目ですが影響ありません。', 0, NOW() - INTERVAL '25 minutes', NOW() - INTERVAL '25 minutes'),
('c0000000-0000-0000-0000-000000000007', 'ffffffff-ffff-ffff-ffff-ffffffffffff', '11111111-1111-1111-1111-111111111111', '綺麗ですね！私も行きたいです🌸', 0, NOW() - INTERVAL '20 hours', NOW() - INTERVAL '20 hours');

-- ========================================
-- 4. いいね（Likes）の作成
-- ========================================

INSERT INTO public.likes (id, user_id, post_id, created_at) VALUES
('10000000-0000-0000-0000-00000000000a', '22222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NOW() - INTERVAL '1 hour 30 minutes'),
('10000000-0000-0000-0000-00000000000b', '33333333-3333-3333-3333-333333333333', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NOW() - INTERVAL '1 hour 20 minutes'),
('10000000-0000-0000-0000-00000000000c', '11111111-1111-1111-1111-111111111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', NOW() - INTERVAL '20 hours'),
('10000000-0000-0000-0000-00000000000d', '33333333-3333-3333-3333-333333333333', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', NOW() - INTERVAL '19 hours'),
('10000000-0000-0000-0000-00000000000e', '11111111-1111-1111-1111-111111111111', 'cccccccc-cccc-cccc-cccc-cccccccccccc', NOW() - INTERVAL '25 minutes'),
('10000000-0000-0000-0000-00000000000f', '22222222-2222-2222-2222-222222222222', 'cccccccc-cccc-cccc-cccc-cccccccccccc', NOW() - INTERVAL '22 minutes'),
('10000000-0000-0000-0000-000000000010', '11111111-1111-1111-1111-111111111111', 'ffffffff-ffff-ffff-ffff-ffffffffffff', NOW() - INTERVAL '20 hours'),
('10000000-0000-0000-0000-000000000011', '33333333-3333-3333-3333-333333333333', 'ffffffff-ffff-ffff-ffff-ffffffffffff', NOW() - INTERVAL '18 hours');

-- ========================================
-- 5. いいね数とコメント数を更新
-- ========================================

UPDATE public.posts SET like_count = (SELECT COUNT(*) FROM public.likes WHERE post_id = posts.id);
UPDATE public.posts SET comment_count = (SELECT COUNT(*) FROM public.comments WHERE post_id = posts.id);

-- ========================================
-- 完了メッセージ
-- ========================================

SELECT '✓ テストデータ投入完了' AS status;
SELECT
  (SELECT COUNT(*) FROM public.users WHERE id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', '44444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555555')) AS users_count,
  (SELECT COUNT(*) FROM public.posts WHERE user_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', '44444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555555')) AS posts_count,
  (SELECT COUNT(*) FROM public.comments WHERE user_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', '44444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555555')) AS comments_count,
  (SELECT COUNT(*) FROM public.likes WHERE user_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', '44444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555555')) AS likes_count;
