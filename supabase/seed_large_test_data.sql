-- ============================================
-- 大量テストデータ投入用SQL（PostGIS対応版）
-- Location News SNS
-- ============================================
-- 目的: 5km圏内の投稿を増やしてマップ表示のテストを行う
-- 中心座標: 東京駅周辺（35.6812, 139.7671）
-- 範囲: 半径5km圏内
-- 投稿数: 約100件
-- ============================================

-- PostGIS拡張が有効か確認
CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================
-- 大量投稿データの作成（5km圏内にランダム配置）
-- ============================================

-- 中心座標: 東京駅（35.6812, 139.7671）
-- 5km = 約0.045度（緯度経度）

INSERT INTO public.posts (id, user_id, content, url, category, location, latitude, longitude, address, is_urgent, is_verified, visibility, like_count, comment_count, share_count, created_at, updated_at) VALUES

-- ニュースカテゴリー（12件）
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', '東京駅周辺で新しい商業施設がオープンしました！', null, 'news', ST_GeogFromText('POINT(139.7671 35.6812)'), 35.6812, 139.7671, '東京都千代田区丸の内', false, false, 'public', 5, 2, 1, NOW() - INTERVAL '2 hours', NOW() - INTERVAL '2 hours'),
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', '銀座に新しい美術館がオープン予定です。', null, 'news', ST_GeogFromText('POINT(139.7645 35.6720)'), 35.6720, 139.7645, '東京都中央区銀座', false, true, 'public', 8, 3, 2, NOW() - INTERVAL '5 hours', NOW() - INTERVAL '5 hours'),
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', '日比谷公園でイベント開催中です。', null, 'news', ST_GeogFromText('POINT(139.7556 35.6736)'), 35.6736, 139.7556, '東京都千代田区日比谷公園', false, false, 'public', 12, 5, 3, NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', '秋葉原に新しい電気街がオープン。', null, 'news', ST_GeogFromText('POINT(139.7731 35.6983)'), 35.6983, 139.7731, '東京都千代田区外神田', false, true, 'public', 15, 6, 4, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '3 hours'),
(uuid_generate_v4(), '55555555-5555-5555-5555-555555555555', '【公式】東京駅のリニューアル工事が完了しました。', null, 'news', ST_GeogFromText('POINT(139.7675 35.6815)'), 35.6815, 139.7675, '東京都千代田区丸の内1丁目', false, true, 'public', 20, 8, 5, NOW() - INTERVAL '12 hours', NOW() - INTERVAL '12 hours'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', '有楽町で新しいショッピングモールがオープン。', null, 'news', ST_GeogFromText('POINT(139.7634 35.6751)'), 35.6751, 139.7634, '東京都千代田区有楽町', false, false, 'public', 10, 4, 2, NOW() - INTERVAL '8 hours', NOW() - INTERVAL '8 hours'),
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', '大手町で新しいオフィスビル完成。', null, 'news', ST_GeogFromText('POINT(139.7653 35.6870)'), 35.6870, 139.7653, '東京都千代田区大手町', false, true, 'public', 7, 2, 1, NOW() - INTERVAL '6 hours', NOW() - INTERVAL '6 hours'),
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', '神田で地域イベントが開催されます。', null, 'news', ST_GeogFromText('POINT(139.7711 35.6916)'), 35.6916, 139.7711, '東京都千代田区神田', false, false, 'public', 9, 3, 2, NOW() - INTERVAL '4 hours', NOW() - INTERVAL '4 hours'),
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', '築地市場跡地の再開発情報。', null, 'news', ST_GeogFromText('POINT(139.7707 35.6654)'), 35.6654, 139.7707, '東京都中央区築地', false, true, 'public', 18, 7, 4, NOW() - INTERVAL '10 hours', NOW() - INTERVAL '10 hours'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', '皇居周辺の桜が見頃です。', null, 'news', ST_GeogFromText('POINT(139.7528 35.6852)'), 35.6852, 139.7528, '東京都千代田区千代田', false, false, 'public', 25, 10, 6, NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', '新橋駅前で再開発プロジェクトが始動。', null, 'news', ST_GeogFromText('POINT(139.7582 35.6660)'), 35.6660, 139.7582, '東京都港区新橋', false, true, 'public', 11, 4, 3, NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days'),
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', '浜松町に新しいタワーマンション建設中。', null, 'news', ST_GeogFromText('POINT(139.7566 35.6551)'), 35.6551, 139.7566, '東京都港区浜松町', false, false, 'public', 6, 2, 1, NOW() - INTERVAL '15 hours', NOW() - INTERVAL '15 hours'),

-- イベントカテゴリー（15件）
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', '週末に東京駅前でマルシェ開催！', null, 'event', ST_GeogFromText('POINT(139.7668 35.6810)'), 35.6810, 139.7668, '東京都千代田区丸の内', false, true, 'public', 30, 12, 8, NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', '銀座でアートフェスティバル開催中。', null, 'event', ST_GeogFromText('POINT(139.7640 35.6715)'), 35.6715, 139.7640, '東京都中央区銀座4丁目', false, false, 'public', 22, 9, 5, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '3 hours'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', '日比谷公園で音楽フェス開催決定！', null, 'event', ST_GeogFromText('POINT(139.7560 35.6740)'), 35.6740, 139.7560, '東京都千代田区日比谷公園1-6', false, true, 'public', 45, 20, 15, NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days'),
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', '秋葉原でアニメイベント開催。', null, 'event', ST_GeogFromText('POINT(139.7725 35.6980)'), 35.6980, 139.7725, '東京都千代田区外神田1丁目', false, false, 'public', 35, 15, 10, NOW() - INTERVAL '5 hours', NOW() - INTERVAL '5 hours'),
(uuid_generate_v4(), '55555555-5555-5555-5555-555555555555', '【公式】東京マラソン開催のお知らせ。', null, 'event', ST_GeogFromText('POINT(139.7670 35.6800)'), 35.6800, 139.7670, '東京都千代田区', false, true, 'public', 60, 25, 20, NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days'),
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', '有楽町でワインフェスティバル開催。', null, 'event', ST_GeogFromText('POINT(139.7630 35.6748)'), 35.6748, 139.7630, '東京都千代田区有楽町1丁目', false, false, 'public', 28, 11, 7, NOW() - INTERVAL '6 hours', NOW() - INTERVAL '6 hours'),
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', '神田明神で祭りが開催されます。', null, 'event', ST_GeogFromText('POINT(139.7670 35.7016)'), 35.7016, 139.7670, '東京都千代田区外神田2丁目', false, true, 'public', 40, 18, 12, NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', '大手町でビジネスセミナー開催。', null, 'event', ST_GeogFromText('POINT(139.7648 35.6865)'), 35.6865, 139.7648, '東京都千代田区大手町1丁目', false, false, 'public', 15, 6, 3, NOW() - INTERVAL '8 hours', NOW() - INTERVAL '8 hours'),
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', '築地でグルメフェス開催中。', null, 'event', ST_GeogFromText('POINT(139.7710 35.6650)'), 35.6650, 139.7710, '東京都中央区築地4丁目', false, true, 'public', 50, 22, 18, NOW() - INTERVAL '4 hours', NOW() - INTERVAL '4 hours'),
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', '皇居周辺でランニングイベント。', null, 'event', ST_GeogFromText('POINT(139.7525 35.6850)'), 35.6850, 139.7525, '東京都千代田区皇居外苑', false, false, 'public', 33, 14, 9, NOW() - INTERVAL '10 hours', NOW() - INTERVAL '10 hours'),
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', '新橋でビアガーデンオープン。', null, 'event', ST_GeogFromText('POINT(139.7580 35.6658)'), 35.6658, 139.7580, '東京都港区新橋1丁目', false, true, 'public', 26, 10, 6, NOW() - INTERVAL '12 hours', NOW() - INTERVAL '12 hours'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', '浜松町でフードトラックイベント。', null, 'event', ST_GeogFromText('POINT(139.7560 35.6548)'), 35.6548, 139.7560, '東京都港区浜松町1丁目', false, false, 'public', 20, 8, 5, NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days'),
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', '東京タワー周辺でイルミネーション。', null, 'event', ST_GeogFromText('POINT(139.7454 35.6586)'), 35.6586, 139.7454, '東京都港区芝公園', false, true, 'public', 55, 24, 16, NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),
(uuid_generate_v4(), '55555555-5555-5555-5555-555555555555', '【公式】日本橋で伝統工芸展開催。', null, 'event', ST_GeogFromText('POINT(139.7740 35.6830)'), 35.6830, 139.7740, '東京都中央区日本橋', false, true, 'public', 38, 16, 11, NOW() - INTERVAL '15 hours', NOW() - INTERVAL '15 hours'),
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', '人形町で桜まつり開催予定。', null, 'event', ST_GeogFromText('POINT(139.7820 35.6860)'), 35.6860, 139.7820, '東京都中央区日本橋人形町', false, false, 'public', 42, 19, 13, NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days'),

-- 緊急情報カテゴリー（10件）
(uuid_generate_v4(), '55555555-5555-5555-5555-555555555555', '【緊急】東京駅周辺で停電発生中。復旧作業中です。', null, 'emergency', ST_GeogFromText('POINT(139.7672 35.6813)'), 35.6813, 139.7672, '東京都千代田区丸の内1丁目', true, true, 'public', 80, 30, 25, NOW() - INTERVAL '30 minutes', NOW() - INTERVAL '30 minutes'),
(uuid_generate_v4(), '55555555-5555-5555-5555-555555555555', '【注意】銀座で火災発生。消防隊が対応中です。', null, 'emergency', ST_GeogFromText('POINT(139.7642 35.6718)'), 35.6718, 139.7642, '東京都中央区銀座5丁目', true, true, 'public', 120, 45, 40, NOW() - INTERVAL '1 hour', NOW() - INTERVAL '1 hour'),
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', '【警告】日比谷公園で不審物発見。警察が対応中。', null, 'emergency', ST_GeogFromText('POINT(139.7558 35.6738)'), 35.6738, 139.7558, '東京都千代田区日比谷公園', true, true, 'public', 95, 38, 32, NOW() - INTERVAL '2 hours', NOW() - INTERVAL '2 hours'),
(uuid_generate_v4(), '55555555-5555-5555-5555-555555555555', '【緊急】秋葉原で大規模停電。影響範囲を確認中。', null, 'emergency', ST_GeogFromText('POINT(139.7728 35.6982)'), 35.6982, 139.7728, '東京都千代田区外神田', true, true, 'public', 110, 42, 38, NOW() - INTERVAL '45 minutes', NOW() - INTERVAL '45 minutes'),
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', '【注意】有楽町でガス漏れ。周辺住民は避難してください。', null, 'emergency', ST_GeogFromText('POINT(139.7632 35.6750)'), 35.6750, 139.7632, '東京都千代田区有楽町', true, true, 'public', 150, 55, 50, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '3 hours'),
(uuid_generate_v4(), '55555555-5555-5555-5555-555555555555', '【公式】大手町で地震発生。震度3。被害状況確認中。', null, 'emergency', ST_GeogFromText('POINT(139.7650 35.6868)'), 35.6868, 139.7650, '東京都千代田区大手町', true, true, 'public', 200, 75, 65, NOW() - INTERVAL '5 hours', NOW() - INTERVAL '5 hours'),
(uuid_generate_v4(), '55555555-5555-5555-5555-555555555555', '【警告】神田で建物火災。避難指示が出ています。', null, 'emergency', ST_GeogFromText('POINT(139.7713 35.6918)'), 35.6918, 139.7713, '東京都千代田区神田', true, true, 'public', 130, 50, 45, NOW() - INTERVAL '4 hours', NOW() - INTERVAL '4 hours'),
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', '【注意】築地で水道管破裂。断水の可能性があります。', null, 'emergency', ST_GeogFromText('POINT(139.7708 35.6652)'), 35.6652, 139.7708, '東京都中央区築地', true, true, 'public', 85, 32, 28, NOW() - INTERVAL '6 hours', NOW() - INTERVAL '6 hours'),
(uuid_generate_v4(), '55555555-5555-5555-5555-555555555555', '【緊急】新橋で交通事故。救急車が到着しています。', null, 'emergency', ST_GeogFromText('POINT(139.7584 35.6662)'), 35.6662, 139.7584, '東京都港区新橋', true, true, 'public', 70, 28, 22, NOW() - INTERVAL '1 hour 30 minutes', NOW() - INTERVAL '1 hour 30 minutes'),
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', '【警告】浜松町で不審者情報。警察が巡回中です。', null, 'emergency', ST_GeogFromText('POINT(139.7562 35.6550)'), 35.6550, 139.7562, '東京都港区浜松町', true, true, 'public', 60, 25, 20, NOW() - INTERVAL '2 hours 30 minutes', NOW() - INTERVAL '2 hours 30 minutes'),

-- 交通情報カテゴリー（15件）
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', '東京駅で人身事故。JR各線に遅延が出ています。', null, 'traffic', ST_GeogFromText('POINT(139.7673 35.6814)'), 35.6814, 139.7673, '東京都千代田区丸の内', false, false, 'public', 40, 15, 10, NOW() - INTERVAL '1 hour', NOW() - INTERVAL '1 hour'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', '銀座周辺で交通規制実施中です。', null, 'traffic', ST_GeogFromText('POINT(139.7643 35.6719)'), 35.6719, 139.7643, '東京都中央区銀座', false, false, 'public', 22, 8, 5, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '3 hours'),
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', '日比谷線が遅延しています。復旧時刻未定。', null, 'traffic', ST_GeogFromText('POINT(139.7559 35.6739)'), 35.6739, 139.7559, '東京都千代田区日比谷', false, true, 'public', 35, 12, 8, NOW() - INTERVAL '2 hours', NOW() - INTERVAL '2 hours'),
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', '秋葉原駅で信号トラブル。運転見合わせ中。', null, 'traffic', ST_GeogFromText('POINT(139.7729 35.6984)'), 35.6984, 139.7729, '東京都千代田区外神田', false, false, 'public', 50, 20, 15, NOW() - INTERVAL '4 hours', NOW() - INTERVAL '4 hours'),
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', '有楽町駅周辺で渋滞が発生しています。', null, 'traffic', ST_GeogFromText('POINT(139.7633 35.6752)'), 35.6752, 139.7633, '東京都千代田区有楽町', false, true, 'public', 18, 7, 4, NOW() - INTERVAL '5 hours', NOW() - INTERVAL '5 hours'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', '大手町駅でエレベーター故障中。', null, 'traffic', ST_GeogFromText('POINT(139.7651 35.6869)'), 35.6869, 139.7651, '東京都千代田区大手町', false, false, 'public', 12, 5, 2, NOW() - INTERVAL '6 hours', NOW() - INTERVAL '6 hours'),
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', '神田駅で混雑が発生しています。', null, 'traffic', ST_GeogFromText('POINT(139.7714 35.6920)'), 35.6920, 139.7714, '東京都千代田区神田', false, false, 'public', 15, 6, 3, NOW() - INTERVAL '7 hours', NOW() - INTERVAL '7 hours'),
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', '築地市場周辺で交通規制あり。', null, 'traffic', ST_GeogFromText('POINT(139.7709 35.6653)'), 35.6653, 139.7709, '東京都中央区築地', false, true, 'public', 20, 8, 5, NOW() - INTERVAL '8 hours', NOW() - INTERVAL '8 hours'),
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', '新橋駅で乗り換えに時間がかかっています。', null, 'traffic', ST_GeogFromText('POINT(139.7585 35.6663)'), 35.6663, 139.7585, '東京都港区新橋', false, false, 'public', 25, 10, 6, NOW() - INTERVAL '9 hours', NOW() - INTERVAL '9 hours'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', '浜松町駅周辺で工事による渋滞。', null, 'traffic', ST_GeogFromText('POINT(139.7563 35.6552)'), 35.6552, 139.7563, '東京都港区浜松町', false, false, 'public', 14, 5, 3, NOW() - INTERVAL '10 hours', NOW() - INTERVAL '10 hours'),
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', '東京タワー周辺で観光バスによる渋滞。', null, 'traffic', ST_GeogFromText('POINT(139.7456 35.6588)'), 35.6588, 139.7456, '東京都港区芝公園', false, true, 'public', 30, 12, 8, NOW() - INTERVAL '11 hours', NOW() - INTERVAL '11 hours'),
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', '日本橋周辺で道路工事実施中。', null, 'traffic', ST_GeogFromText('POINT(139.7742 35.6832)'), 35.6832, 139.7742, '東京都中央区日本橋', false, false, 'public', 16, 6, 4, NOW() - INTERVAL '12 hours', NOW() - INTERVAL '12 hours'),
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', '人形町駅で混雑しています。時間に余裕を。', null, 'traffic', ST_GeogFromText('POINT(139.7822 35.6862)'), 35.6862, 139.7822, '東京都中央区日本橋人形町', false, false, 'public', 10, 4, 2, NOW() - INTERVAL '13 hours', NOW() - INTERVAL '13 hours'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', '首都高速で事故。銀座出口付近で渋滞。', null, 'traffic', ST_GeogFromText('POINT(139.7650 35.6725)'), 35.6725, 139.7650, '東京都中央区銀座', false, true, 'public', 45, 18, 12, NOW() - INTERVAL '14 hours', NOW() - INTERVAL '14 hours'),
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', '皇居周辺でマラソン大会。交通規制あり。', null, 'traffic', ST_GeogFromText('POINT(139.7527 35.6854)'), 35.6854, 139.7527, '東京都千代田区皇居外苑', false, false, 'public', 28, 11, 7, NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),

-- 天気情報カテゴリー（12件）
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', '東京駅周辺、午後から雨が降りそうです。', null, 'weather', ST_GeogFromText('POINT(139.7674 35.6816)'), 35.6816, 139.7674, '東京都千代田区丸の内', false, false, 'public', 18, 6, 4, NOW() - INTERVAL '2 hours', NOW() - INTERVAL '2 hours'),
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', '銀座は快晴です。お出かけ日和です。', null, 'weather', ST_GeogFromText('POINT(139.7644 35.6721)'), 35.6721, 139.7644, '東京都中央区銀座', false, false, 'public', 25, 8, 5, NOW() - INTERVAL '4 hours', NOW() - INTERVAL '4 hours'),
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', '日比谷公園周辺、強風に注意してください。', null, 'weather', ST_GeogFromText('POINT(139.7561 35.6741)'), 35.6741, 139.7561, '東京都千代田区日比谷公園', false, false, 'public', 20, 7, 4, NOW() - INTERVAL '6 hours', NOW() - INTERVAL '6 hours'),
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', '秋葉原で雷雨の可能性。傘を持参してください。', null, 'weather', ST_GeogFromText('POINT(139.7730 35.6986)'), 35.6986, 139.7730, '東京都千代田区外神田', false, true, 'public', 30, 10, 6, NOW() - INTERVAL '8 hours', NOW() - INTERVAL '8 hours'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', '有楽町周辺、気温が急上昇中。熱中症に注意。', null, 'weather', ST_GeogFromText('POINT(139.7635 35.6754)'), 35.6754, 139.7635, '東京都千代田区有楽町', false, false, 'public', 22, 8, 5, NOW() - INTERVAL '10 hours', NOW() - INTERVAL '10 hours'),
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', '大手町は曇り空。夕方から雨の予報。', null, 'weather', ST_GeogFromText('POINT(139.7652 35.6871)'), 35.6871, 139.7652, '東京都千代田区大手町', false, false, 'public', 15, 5, 3, NOW() - INTERVAL '12 hours', NOW() - INTERVAL '12 hours'),
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', '神田周辺、霧に注意してください。', null, 'weather', ST_GeogFromText('POINT(139.7715 35.6922)'), 35.6922, 139.7715, '東京都千代田区神田', false, false, 'public', 12, 4, 2, NOW() - INTERVAL '14 hours', NOW() - INTERVAL '14 hours'),
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', '築地は晴れ。絶好の散歩日和です。', null, 'weather', ST_GeogFromText('POINT(139.7711 35.6655)'), 35.6655, 139.7711, '東京都中央区築地', false, false, 'public', 28, 10, 6, NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', '新橋周辺、小雨が降っています。', null, 'weather', ST_GeogFromText('POINT(139.7586 35.6665)'), 35.6665, 139.7586, '東京都港区新橋', false, false, 'public', 16, 6, 3, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '3 hours'),
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', '浜松町は雨上がり。虹が見えるかも。', null, 'weather', ST_GeogFromText('POINT(139.7564 35.6554)'), 35.6554, 139.7564, '東京都港区浜松町', false, false, 'public', 32, 12, 8, NOW() - INTERVAL '5 hours', NOW() - INTERVAL '5 hours'),
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', '日本橋周辺、午後から気温上昇の予報。', null, 'weather', ST_GeogFromText('POINT(139.7744 35.6834)'), 35.6834, 139.7744, '東京都中央区日本橋', false, false, 'public', 19, 7, 4, NOW() - INTERVAL '7 hours', NOW() - INTERVAL '7 hours'),
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', '皇居周辺、風が強いです。帽子に注意。', null, 'weather', ST_GeogFromText('POINT(139.7529 35.6856)'), 35.6856, 139.7529, '東京都千代田区皇居外苑', false, false, 'public', 24, 9, 5, NOW() - INTERVAL '9 hours', NOW() - INTERVAL '9 hours'),

-- ソーシャルカテゴリー（18件）
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', '東京駅でランチ。美味しいお店見つけました！', null, 'social', ST_GeogFromText('POINT(139.7676 35.6818)'), 35.6818, 139.7676, '東京都千代田区丸の内', false, false, 'public', 35, 14, 9, NOW() - INTERVAL '1 hour', NOW() - INTERVAL '1 hour'),
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', '銀座でショッピング楽しんでます。', null, 'social', ST_GeogFromText('POINT(139.7646 35.6723)'), 35.6723, 139.7646, '東京都中央区銀座', false, false, 'public', 42, 16, 11, NOW() - INTERVAL '2 hours', NOW() - INTERVAL '2 hours'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', '日比谷公園で散歩中。気持ちいいです。', null, 'social', ST_GeogFromText('POINT(139.7562 35.6742)'), 35.6742, 139.7562, '東京都千代田区日比谷公園', false, false, 'public', 28, 11, 7, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '3 hours'),
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', '秋葉原でお買い物。楽しい！', null, 'social', ST_GeogFromText('POINT(139.7732 35.6988)'), 35.6988, 139.7732, '東京都千代田区外神田', false, false, 'public', 38, 15, 10, NOW() - INTERVAL '4 hours', NOW() - INTERVAL '4 hours'),
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', '有楽町でカフェタイム。おすすめです。', null, 'social', ST_GeogFromText('POINT(139.7636 35.6756)'), 35.6756, 139.7636, '東京都千代田区有楽町', false, false, 'public', 45, 18, 12, NOW() - INTERVAL '5 hours', NOW() - INTERVAL '5 hours'),
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', '大手町でランチミーティング。', null, 'social', ST_GeogFromText('POINT(139.7654 35.6873)'), 35.6873, 139.7654, '東京都千代田区大手町', false, false, 'public', 20, 8, 5, NOW() - INTERVAL '6 hours', NOW() - INTERVAL '6 hours'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', '神田で美味しいラーメン発見！', null, 'social', ST_GeogFromText('POINT(139.7716 35.6924)'), 35.6924, 139.7716, '東京都千代田区神田', false, false, 'public', 50, 20, 14, NOW() - INTERVAL '7 hours', NOW() - INTERVAL '7 hours'),
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', '築地で海鮮丼を食べました。最高！', null, 'social', ST_GeogFromText('POINT(139.7712 35.6657)'), 35.6657, 139.7712, '東京都中央区築地', false, false, 'public', 60, 24, 18, NOW() - INTERVAL '8 hours', NOW() - INTERVAL '8 hours'),
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', '新橋で飲み会。盛り上がってます！', null, 'social', ST_GeogFromText('POINT(139.7588 35.6667)'), 35.6667, 139.7588, '東京都港区新橋', false, false, 'public', 33, 13, 8, NOW() - INTERVAL '9 hours', NOW() - INTERVAL '9 hours'),
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', '浜松町でディナー。夜景が綺麗です。', null, 'social', ST_GeogFromText('POINT(139.7566 35.6556)'), 35.6556, 139.7566, '東京都港区浜松町', false, false, 'public', 48, 19, 13, NOW() - INTERVAL '10 hours', NOW() - INTERVAL '10 hours'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', '東京タワーからの眺め、最高です！', null, 'social', ST_GeogFromText('POINT(139.7458 35.6590)'), 35.6590, 139.7458, '東京都港区芝公園', false, false, 'public', 75, 30, 22, NOW() - INTERVAL '11 hours', NOW() - INTERVAL '11 hours'),
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', '日本橋で和菓子を買いました。', null, 'social', ST_GeogFromText('POINT(139.7746 35.6836)'), 35.6836, 139.7746, '東京都中央区日本橋', false, false, 'public', 26, 10, 6, NOW() - INTERVAL '12 hours', NOW() - INTERVAL '12 hours'),
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', '人形町で甘味処巡り。幸せ。', null, 'social', ST_GeogFromText('POINT(139.7824 35.6864)'), 35.6864, 139.7824, '東京都中央区日本橋人形町', false, false, 'public', 40, 16, 11, NOW() - INTERVAL '13 hours', NOW() - INTERVAL '13 hours'),
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', '皇居ランニング。爽快です！', null, 'social', ST_GeogFromText('POINT(139.7531 35.6858)'), 35.6858, 139.7531, '東京都千代田区皇居外苑', false, false, 'public', 52, 21, 15, NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', '丸の内でお散歩。おしゃれな街並み。', null, 'social', ST_GeogFromText('POINT(139.7678 35.6820)'), 35.6820, 139.7678, '東京都千代田区丸の内', false, false, 'public', 31, 12, 8, NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days'),
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', '銀座でティータイム。優雅なひととき。', null, 'social', ST_GeogFromText('POINT(139.7648 35.6726)'), 35.6726, 139.7648, '東京都中央区銀座', false, false, 'public', 44, 17, 12, NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days'),
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', '秋葉原でアニメグッズ購入。満足！', null, 'social', ST_GeogFromText('POINT(139.7734 35.6990)'), 35.6990, 139.7734, '東京都千代田区外神田', false, false, 'public', 36, 14, 9, NOW() - INTERVAL '4 days', NOW() - INTERVAL '4 days'),
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', '東京駅の夜景が綺麗でした。', null, 'social', ST_GeogFromText('POINT(139.7680 35.6822)'), 35.6822, 139.7680, '東京都千代田区丸の内', false, false, 'public', 55, 22, 16, NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days'),

-- ビジネスカテゴリー（10件）
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', '東京駅前に新しいコワーキングスペースがオープン。', null, 'business', ST_GeogFromText('POINT(139.7682 35.6824)'), 35.6824, 139.7682, '東京都千代田区丸の内', false, false, 'public', 22, 8, 5, NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', '銀座に新しいブティックがオープン。', null, 'business', ST_GeogFromText('POINT(139.7650 35.6728)'), 35.6728, 139.7650, '東京都中央区銀座', false, true, 'public', 18, 7, 4, NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days'),
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', '秋葉原に新しい家電量販店オープン予定。', null, 'business', ST_GeogFromText('POINT(139.7736 35.6992)'), 35.6992, 139.7736, '東京都千代田区外神田', false, false, 'public', 25, 10, 6, NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days'),
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', '有楽町に新しいカフェチェーンが進出。', null, 'business', ST_GeogFromText('POINT(139.7638 35.6758)'), 35.6758, 139.7638, '東京都千代田区有楽町', false, true, 'public', 30, 12, 8, NOW() - INTERVAL '4 days', NOW() - INTERVAL '4 days'),
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', '大手町でビジネスホテルが開業。', null, 'business', ST_GeogFromText('POINT(139.7656 35.6875)'), 35.6875, 139.7656, '東京都千代田区大手町', false, false, 'public', 15, 6, 3, NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', '神田に新しい書店がオープン。', null, 'business', ST_GeogFromText('POINT(139.7718 35.6926)'), 35.6926, 139.7718, '東京都千代田区神田', false, false, 'public', 20, 8, 5, NOW() - INTERVAL '6 days', NOW() - INTERVAL '6 days'),
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', '築地に新しいレストランがオープン。', null, 'business', ST_GeogFromText('POINT(139.7714 35.6659)'), 35.6659, 139.7714, '東京都中央区築地', false, true, 'public', 35, 14, 10, NOW() - INTERVAL '1 week', NOW() - INTERVAL '1 week'),
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', '新橋に新しい居酒屋チェーンがオープン。', null, 'business', ST_GeogFromText('POINT(139.7590 35.6669)'), 35.6669, 139.7590, '東京都港区新橋', false, false, 'public', 28, 11, 7, NOW() - INTERVAL '2 hours', NOW() - INTERVAL '2 hours'),
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', '日本橋に新しい百貨店がオープン予定。', null, 'business', ST_GeogFromText('POINT(139.7748 35.6838)'), 35.6838, 139.7748, '東京都中央区日本橋', false, true, 'public', 42, 16, 12, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '3 hours'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', '人形町に新しい和菓子店がオープン。', null, 'business', ST_GeogFromText('POINT(139.7826 35.6866)'), 35.6866, 139.7826, '東京都中央区日本橋人形町', false, false, 'public', 32, 13, 9, NOW() - INTERVAL '4 hours', NOW() - INTERVAL '4 hours'),

-- その他カテゴリー（8件）
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', '東京駅周辺で清掃ボランティア募集中。', null, 'other', ST_GeogFromText('POINT(139.7684 35.6826)'), 35.6826, 139.7684, '東京都千代田区丸の内', false, true, 'public', 16, 6, 4, NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', '銀座で迷子のペットを保護しました。', null, 'other', ST_GeogFromText('POINT(139.7652 35.6730)'), 35.6730, 139.7652, '東京都中央区銀座', false, false, 'public', 25, 10, 6, NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days'),
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', '日比谷公園で落とし物を拾いました。', null, 'other', ST_GeogFromText('POINT(139.7564 35.6744)'), 35.6744, 139.7564, '東京都千代田区日比谷公園', false, false, 'public', 12, 5, 2, NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days'),
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', '秋葉原で地域清掃活動を行います。', null, 'other', ST_GeogFromText('POINT(139.7738 35.6994)'), 35.6994, 139.7738, '東京都千代田区外神田', false, true, 'public', 20, 8, 5, NOW() - INTERVAL '4 days', NOW() - INTERVAL '4 days'),
(uuid_generate_v4(), '44444444-4444-4444-4444-444444444444', '有楽町で忘れ物を見つけました。', null, 'other', ST_GeogFromText('POINT(139.7640 35.6760)'), 35.6760, 139.7640, '東京都千代田区有楽町', false, false, 'public', 8, 3, 1, NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days'),
(uuid_generate_v4(), '11111111-1111-1111-1111-111111111111', '大手町で献血キャンペーン実施中。', null, 'other', ST_GeogFromText('POINT(139.7658 35.6877)'), 35.6877, 139.7658, '東京都千代田区大手町', false, true, 'public', 18, 7, 4, NOW() - INTERVAL '6 days', NOW() - INTERVAL '6 days'),
(uuid_generate_v4(), '22222222-2222-2222-2222-222222222222', '神田で地域イベントのボランティア募集。', null, 'other', ST_GeogFromText('POINT(139.7720 35.6928)'), 35.6928, 139.7720, '東京都千代田区神田', false, false, 'public', 14, 6, 3, NOW() - INTERVAL '1 week', NOW() - INTERVAL '1 week'),
(uuid_generate_v4(), '33333333-3333-3333-3333-333333333333', '皇居周辺でゴミ拾い活動を行います。', null, 'other', ST_GeogFromText('POINT(139.7533 35.6860)'), 35.6860, 139.7533, '東京都千代田区皇居外苑', false, true, 'public', 22, 9, 5, NOW() - INTERVAL '5 hours', NOW() - INTERVAL '5 hours');

-- ============================================
-- 完了メッセージ
-- ============================================

SELECT '✓ 大量テストデータ投入完了' AS status;
SELECT
  COUNT(*) AS total_posts,
  COUNT(CASE WHEN category = 'news' THEN 1 END) AS news_count,
  COUNT(CASE WHEN category = 'event' THEN 1 END) AS event_count,
  COUNT(CASE WHEN category = 'emergency' THEN 1 END) AS emergency_count,
  COUNT(CASE WHEN category = 'traffic' THEN 1 END) AS traffic_count,
  COUNT(CASE WHEN category = 'weather' THEN 1 END) AS weather_count,
  COUNT(CASE WHEN category = 'social' THEN 1 END) AS social_count,
  COUNT(CASE WHEN category = 'business' THEN 1 END) AS business_count,
  COUNT(CASE WHEN category = 'other' THEN 1 END) AS other_count,
  COUNT(CASE WHEN is_urgent = true THEN 1 END) AS urgent_count
FROM public.posts
WHERE user_id IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333',
  '44444444-4444-4444-4444-444444444444',
  '55555555-5555-5555-5555-555555555555'
);

-- ============================================
-- 動作確認クエリ例
-- ============================================
-- 東京駅周辺5km圏内の投稿を取得
-- SELECT * FROM nearby_posts_with_user(35.6812, 139.7671, 5000, 50);
