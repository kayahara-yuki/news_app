-- ========================================
-- テストデータ投入用SQL
-- Location News SNS
-- ========================================

-- 既存のテストデータをクリア（開発環境のみ）
TRUNCATE TABLE public.comments CASCADE;
TRUNCATE TABLE public.likes CASCADE;
TRUNCATE TABLE public.posts CASCADE;
TRUNCATE TABLE public.users CASCADE;

-- ========================================
-- 1. テストユーザーの作成
-- ========================================

INSERT INTO public.users (id, email, username, display_name, bio, avatar_url, location, is_verified, role, privacy_settings, created_at, updated_at) VALUES
-- 一般ユーザー
('11111111-1111-1111-1111-111111111111', 'tanaka@example.com', 'tanaka_taro', '田中太郎', '東京在住のサラリーマンです。地域の情報をシェアしています。', 'https://i.pravatar.cc/150?img=1', '東京都渋谷区', false, 'user', '{"locationSharing": true, "emergencyOverride": true, "locationPrecision": "city", "profileVisibility": "public"}', NOW() - INTERVAL '30 days', NOW()),

('22222222-2222-2222-2222-222222222222', 'yamada@example.com', 'yamada_hanako', '山田花子', '横浜でカフェ巡りが好きです☕', 'https://i.pravatar.cc/150?img=5', '神奈川県横浜市', true, 'user', '{"locationSharing": true, "emergencyOverride": true, "locationPrecision": "city", "profileVisibility": "public"}', NOW() - INTERVAL '60 days', NOW()),

('33333333-3333-3333-3333-333333333333', 'sato@example.com', 'sato_jiro', '佐藤次郎', 'IT企業勤務。テクノロジーと地域活性化に興味があります。', 'https://i.pravatar.cc/150?img=12', '東京都新宿区', false, 'user', '{"locationSharing": true, "emergencyOverride": true, "locationPrecision": "approximate", "profileVisibility": "public"}', NOW() - INTERVAL '45 days', NOW()),

-- モデレーター
('44444444-4444-4444-4444-444444444444', 'moderator@example.com', 'mod_suzuki', '鈴木（モデレーター）', '地域コミュニティのモデレーターです。', 'https://i.pravatar.cc/150?img=8', '東京都千代田区', true, 'moderator', '{"locationSharing": true, "emergencyOverride": true, "locationPrecision": "city", "profileVisibility": "public"}', NOW() - INTERVAL '90 days', NOW()),

-- 公式アカウント
('55555555-5555-5555-5555-555555555555', 'official@example.com', 'tokyo_official', '東京都公式', '東京都の公式アカウントです。緊急情報や重要なお知らせを発信します。', 'https://i.pravatar.cc/150?img=20', '東京都', true, 'official', '{"locationSharing": true, "emergencyOverride": true, "locationPrecision": "city", "profileVisibility": "public"}', NOW() - INTERVAL '180 days', NOW());

-- ========================================
-- 2. テスト投稿の作成
-- ========================================

INSERT INTO public.posts (id, user_id, content, url, category, latitude, longitude, address, is_urgent, is_verified, visibility, like_count, comment_count, share_count, created_at, updated_at) VALUES

-- ニュース投稿
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', '渋谷駅前で新しい商業施設がオープンしました！多くの人で賑わっています。', null, 'news', 35.6580, 139.7016, '東京都渋谷区道玄坂', false, false, 'public', 12, 3, 2, NOW() - INTERVAL '2 hours', NOW() - INTERVAL '2 hours'),

-- イベント投稿
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', '週末に横浜でマルシェが開催されます🎪 地元の新鮮な野菜や手作り雑貨が並びます。ぜひお越しください！', null, 'event', 35.4437, 139.6380, '神奈川県横浜市西区みなとみらい', false, true, 'public', 25, 8, 5, NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),

-- 緊急情報（公式アカウント）
('cccccccc-cccc-cccc-cccc-cccccccccccc', '55555555-5555-5555-5555-555555555555', '【緊急】新宿区で停電が発生しています。復旧作業中です。影響範囲: 新宿1-3丁目。復旧予定: 14:00頃', null, 'emergency', 35.6938, 139.7036, '東京都新宿区新宿', true, true, 'public', 45, 12, 20, NOW() - INTERVAL '30 minutes', NOW() - INTERVAL '30 minutes'),

-- 交通情報
('dddddddd-dddd-dddd-dddd-dddddddddddd', '33333333-3333-3333-3333-333333333333', '山手線の遅延情報です。現在、渋谷〜新宿間で15分程度の遅れが出ています。', null, 'traffic', 35.6812, 139.7671, '東京都渋谷区', false, false, 'public', 8, 2, 1, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '3 hours'),

-- 天気情報
('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '11111111-1111-1111-1111-111111111111', '今日の午後から雨が降りそうです☔ 傘を持ってお出かけください。', null, 'weather', 35.6762, 139.6503, '東京都', false, false, 'public', 15, 4, 3, NOW() - INTERVAL '5 hours', NOW() - INTERVAL '5 hours'),

-- ソーシャル投稿
('ffffffff-ffff-ffff-ffff-ffffffffffff', '22222222-2222-2222-2222-222222222222', '代々木公園でお花見🌸 満開でとても綺麗です！', null, 'social', 35.6717, 139.6966, '東京都渋谷区代々木公園', false, false, 'public', 32, 7, 4, NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),

-- ビジネス投稿
('10000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', '表参道に新しいカフェがオープン☕ おしゃれな内装で居心地が良いです。おすすめ！', null, 'business', 35.6654, 139.7100, '東京都渋谷区神宮前', false, false, 'public', 18, 5, 2, NOW() - INTERVAL '6 hours', NOW() - INTERVAL '6 hours'),

-- その他の投稿
('10000000-0000-0000-0000-000000000002', '44444444-4444-4444-4444-444444444444', '地域の清掃活動ボランティア募集中です。毎週日曜日の朝8時から行っています。', null, 'other', 35.6938, 139.7036, '東京都新宿区', false, true, 'public', 10, 3, 1, NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days'),

-- 緊急度の高い投稿
('10000000-0000-0000-0000-000000000003', '55555555-5555-5555-5555-555555555555', '【注意】品川駅周辺で不審物が発見されました。警察が対応中です。周辺の方はご注意ください。', null, 'emergency', 35.6284, 139.7387, '東京都港区高輪', true, true, 'public', 67, 15, 30, NOW() - INTERVAL '1 hour', NOW() - INTERVAL '1 hour'),

-- 天気（別の場所）
('10000000-0000-0000-0000-000000000004', '22222222-2222-2222-2222-222222222222', '横浜は今日は快晴です！海沿いを散歩するのに最高の天気☀️', null, 'weather', 35.4437, 139.6380, '神奈川県横浜市中区', false, false, 'public', 20, 6, 2, NOW() - INTERVAL '8 hours', NOW() - INTERVAL '8 hours'),

-- イベント（今後の予定）
('10000000-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111', '来週末、六本木ヒルズでアートフェスティバルが開催されます🎨 入場無料です。', null, 'event', 35.6604, 139.7292, '東京都港区六本木', false, false, 'public', 28, 9, 6, NOW() - INTERVAL '12 hours', NOW() - INTERVAL '12 hours'),

-- ニュース（地域活動）
('10000000-0000-0000-0000-000000000006', '44444444-4444-4444-4444-444444444444', '渋谷区が新しい子育て支援施設をオープンしました。利用登録受付中です。', null, 'news', 35.6617, 139.7040, '東京都渋谷区渋谷', false, true, 'public', 22, 7, 4, NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),

-- 交通情報2
('10000000-0000-0000-0000-000000000007', '33333333-3333-3333-3333-333333333333', '首都高速3号線で事故が発生しています。渋滞が予想されます。', null, 'traffic', 35.6532, 139.7390, '東京都港区', false, false, 'public', 14, 3, 5, NOW() - INTERVAL '4 hours', NOW() - INTERVAL '4 hours'),

-- ソーシャル2
('10000000-0000-0000-0000-000000000008', '22222222-2222-2222-2222-222222222222', 'みなとみらいの夜景が素敵でした✨ デートにおすすめです！', null, 'social', 35.4590, 139.6368, '神奈川県横浜市西区みなとみらい', false, false, 'public', 35, 10, 6, NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),

-- ビジネス2
('10000000-0000-0000-0000-000000000009', '11111111-1111-1111-1111-111111111111', '秋葉原に新しい家電量販店がオープン。セール中です！', null, 'business', 35.6983, 139.7731, '東京都千代田区外神田', false, false, 'public', 16, 4, 3, NOW() - INTERVAL '18 hours', NOW() - INTERVAL '18 hours');

-- ========================================
-- 3. コメントの作成
-- ========================================

INSERT INTO public.comments (id, post_id, user_id, content, like_count, created_at, updated_at) VALUES
-- 渋谷の商業施設に対するコメント
('c0000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', '行ってみたいです！どんなお店が入ってるんですか？', 3, NOW() - INTERVAL '1 hour', NOW() - INTERVAL '1 hour'),
('c0000000-0000-0000-0000-000000000002', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333333', 'さっき前を通りました。確かに混雑してますね。', 2, NOW() - INTERVAL '1 hour 30 minutes', NOW() - INTERVAL '1 hour 30 minutes'),
('c0000000-0000-0000-0000-000000000003', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'ファッションブランドとカフェが多いですよ！', 5, NOW() - INTERVAL '45 minutes', NOW() - INTERVAL '45 minutes'),

-- マルシェイベントに対するコメント
('c0000000-0000-0000-0000-000000000004', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', '何時からですか？', 1, NOW() - INTERVAL '20 hours', NOW() - INTERVAL '20 hours'),
('c0000000-0000-0000-0000-000000000005', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '33333333-3333-3333-3333-333333333333', '家族で行きたいです！', 4, NOW() - INTERVAL '18 hours', NOW() - INTERVAL '18 hours'),
('c0000000-0000-0000-0000-000000000006', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', '午前10時からです！お待ちしています😊', 6, NOW() - INTERVAL '17 hours', NOW() - INTERVAL '17 hours'),

-- 停電情報に対するコメント
('c0000000-0000-0000-0000-000000000007', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', '新宿2丁目ですが影響ありません。', 2, NOW() - INTERVAL '25 minutes', NOW() - INTERVAL '25 minutes'),
('c0000000-0000-0000-0000-000000000008', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '33333333-3333-3333-3333-333333333333', '早く復旧するといいですね。', 3, NOW() - INTERVAL '20 minutes', NOW() - INTERVAL '20 minutes'),

-- お花見投稿に対するコメント
('c0000000-0000-0000-0000-000000000009', 'ffffffff-ffff-ffff-ffff-ffffffffffff', '11111111-1111-1111-1111-111111111111', '綺麗ですね！私も行きたいです🌸', 4, NOW() - INTERVAL '20 hours', NOW() - INTERVAL '20 hours'),
('c0000000-0000-0000-0000-000000000010', 'ffffffff-ffff-ffff-ffff-ffffffffffff', '33333333-3333-3333-3333-333333333333', '今週末まで見頃でしょうか？', 2, NOW() - INTERVAL '18 hours', NOW() - INTERVAL '18 hours');

-- ========================================
-- 4. いいね（Likes）の作成
-- ========================================

INSERT INTO public.likes (id, user_id, post_id, created_at) VALUES
-- 渋谷の商業施設へのいいね
('l0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NOW() - INTERVAL '1 hour 30 minutes'),
('l0000000-0000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NOW() - INTERVAL '1 hour 20 minutes'),
('l0000000-0000-0000-0000-000000000003', '44444444-4444-4444-4444-444444444444', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NOW() - INTERVAL '1 hour'),

-- マルシェイベントへのいいね
('l0000000-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', NOW() - INTERVAL '20 hours'),
('l0000000-0000-0000-0000-000000000005', '33333333-3333-3333-3333-333333333333', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', NOW() - INTERVAL '19 hours'),
('l0000000-0000-0000-0000-000000000006', '44444444-4444-4444-4444-444444444444', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', NOW() - INTERVAL '18 hours'),

-- 停電情報へのいいね（情報共有として）
('l0000000-0000-0000-0000-000000000007', '11111111-1111-1111-1111-111111111111', 'cccccccc-cccc-cccc-cccc-cccccccccccc', NOW() - INTERVAL '25 minutes'),
('l0000000-0000-0000-0000-000000000008', '22222222-2222-2222-2222-222222222222', 'cccccccc-cccc-cccc-cccc-cccccccccccc', NOW() - INTERVAL '22 minutes'),
('l0000000-0000-0000-0000-000000000009', '33333333-3333-3333-3333-333333333333', 'cccccccc-cccc-cccc-cccc-cccccccccccc', NOW() - INTERVAL '20 minutes'),

-- お花見投稿へのいいね
('l0000000-0000-0000-0000-000000000010', '11111111-1111-1111-1111-111111111111', 'ffffffff-ffff-ffff-ffff-ffffffffffff', NOW() - INTERVAL '20 hours'),
('l0000000-0000-0000-0000-000000000011', '33333333-3333-3333-3333-333333333333', 'ffffffff-ffff-ffff-ffff-ffffffffffff', NOW() - INTERVAL '18 hours'),
('l0000000-0000-0000-0000-000000000012', '44444444-4444-4444-4444-444444444444', 'ffffffff-ffff-ffff-ffff-ffffffffffff', NOW() - INTERVAL '16 hours'),
('l0000000-0000-0000-0000-000000000013', '55555555-5555-5555-5555-555555555555', 'ffffffff-ffff-ffff-ffff-ffffffffffff', NOW() - INTERVAL '14 hours');

-- ========================================
-- 完了メッセージ
-- ========================================

-- テストデータ投入完了
-- 作成されたデータ:
-- - ユーザー: 5名（一般3名、モデレーター1名、公式1名）
-- - 投稿: 15件（様々なカテゴリ、位置情報）
-- - コメント: 10件
-- - いいね: 13件
