-- いいね数を自動更新するトリガー（RLS対応版）
-- SECURITY DEFINERを使用してRLSの影響を回避

-- 既存のトリガーと関数を削除
DROP TRIGGER IF EXISTS trigger_increment_post_like_count ON likes;
DROP TRIGGER IF EXISTS trigger_decrement_post_like_count ON likes;
DROP FUNCTION IF EXISTS increment_post_like_count();
DROP FUNCTION IF EXISTS decrement_post_like_count();

-- いいね追加時にlike_countをインクリメントする関数
-- SECURITY DEFINER: この関数は関数の所有者（通常はpostgres）の権限で実行される
CREATE OR REPLACE FUNCTION increment_post_like_count()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    -- postsテーブルのlike_countを更新（RLSの影響を受けない）
    UPDATE posts
    SET like_count = like_count + 1
    WHERE id = NEW.post_id;

    -- デバッグログ（本番環境では削除可能）
    RAISE NOTICE 'Incremented like_count for post_id: %', NEW.post_id;

    RETURN NEW;
END;
$$;

-- いいね削除時にlike_countをデクリメントする関数
-- SECURITY DEFINER: この関数は関数の所有者（通常はpostgres）の権限で実行される
CREATE OR REPLACE FUNCTION decrement_post_like_count()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    -- postsテーブルのlike_countを更新（RLSの影響を受けない）
    UPDATE posts
    SET like_count = GREATEST(0, like_count - 1)
    WHERE id = OLD.post_id;

    -- デバッグログ（本番環境では削除可能）
    RAISE NOTICE 'Decremented like_count for post_id: %', OLD.post_id;

    RETURN OLD;
END;
$$;

-- いいね追加時のトリガー
CREATE TRIGGER trigger_increment_post_like_count
    AFTER INSERT ON likes
    FOR EACH ROW
    WHEN (NEW.post_id IS NOT NULL)
    EXECUTE FUNCTION increment_post_like_count();

-- いいね削除時のトリガー
CREATE TRIGGER trigger_decrement_post_like_count
    AFTER DELETE ON likes
    FOR EACH ROW
    WHEN (OLD.post_id IS NOT NULL)
    EXECUTE FUNCTION decrement_post_like_count();

-- トリガーが正しく作成されたか確認
SELECT
    trigger_name,
    event_manipulation,
    action_timing
FROM information_schema.triggers
WHERE event_object_table = 'likes'
ORDER BY trigger_name;
