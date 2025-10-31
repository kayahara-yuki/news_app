-- いいね数を自動更新するトリガー

-- いいね追加時にlike_countをインクリメントする関数
CREATE OR REPLACE FUNCTION increment_post_like_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE posts
    SET like_count = like_count + 1
    WHERE id = NEW.post_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- いいね削除時にlike_countをデクリメントする関数
CREATE OR REPLACE FUNCTION decrement_post_like_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE posts
    SET like_count = GREATEST(0, like_count - 1)
    WHERE id = OLD.post_id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- 既存のトリガーを削除（存在する場合）
DROP TRIGGER IF EXISTS trigger_increment_post_like_count ON likes;
DROP TRIGGER IF EXISTS trigger_decrement_post_like_count ON likes;

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
