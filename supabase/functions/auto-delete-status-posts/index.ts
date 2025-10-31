// auto-delete-status-posts
// ステータス投稿の自動削除機能
// タスク6.1: Supabase Edge Functionの実装

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1"

// 削除結果の型定義
interface DeleteResult {
  deletedPosts: number
  deletedLikes: number
  deletedComments: number
  deletedAudioFiles: number
  errors: string[]
}

// 削除対象の投稿の型定義
interface ExpiredPost {
  id: string
  content: string
  audio_url: string | null
  created_at: string
  expires_at: string
}

// Supabaseクライアントの初期化
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""

serve(async (req) => {
  try {
    console.log("[auto-delete-status-posts] Function started")

    // Supabaseクライアントの作成（サービスロールキーでRLSをバイパス）
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const result: DeleteResult = {
      deletedPosts: 0,
      deletedLikes: 0,
      deletedComments: 0,
      deletedAudioFiles: 0,
      errors: []
    }

    // =====================================================
    // ステップ1: 期限切れステータス投稿を検索
    // =====================================================
    console.log("[auto-delete-status-posts] Fetching expired status posts...")

    const { data: expiredPosts, error: fetchError } = await supabase
      .from("posts")
      .select("id, content, audio_url, created_at, expires_at")
      .eq("is_status_post", true)
      .not("expires_at", "is", null)
      .lt("expires_at", new Date().toISOString())
      .returns<ExpiredPost[]>()

    if (fetchError) {
      console.error("[auto-delete-status-posts] Error fetching expired posts:", fetchError)
      result.errors.push(`Failed to fetch expired posts: ${fetchError.message}`)

      return new Response(
        JSON.stringify({
          success: false,
          result,
          error: fetchError.message
        }),
        {
          status: 500,
          headers: { "Content-Type": "application/json" }
        }
      )
    }

    if (!expiredPosts || expiredPosts.length === 0) {
      console.log("[auto-delete-status-posts] No expired posts found")

      return new Response(
        JSON.stringify({
          success: true,
          result,
          message: "No expired posts to delete"
        }),
        {
          status: 200,
          headers: { "Content-Type": "application/json" }
        }
      )
    }

    console.log(`[auto-delete-status-posts] Found ${expiredPosts.length} expired posts`)

    // =====================================================
    // ステップ2: 各投稿について削除処理を実行
    // =====================================================
    for (const post of expiredPosts) {
      console.log(`[auto-delete-status-posts] Processing post ${post.id} (${post.content})`)

      try {
        // 2.1: 音声ファイルの削除（存在する場合）
        if (post.audio_url) {
          console.log(`[auto-delete-status-posts] Deleting audio file: ${post.audio_url}`)

          // audio URLからパスを抽出
          // 例: https://.../storage/v1/object/public/audio/user_id/filename.m4a
          const audioPath = extractAudioPath(post.audio_url)

          if (audioPath) {
            const { error: storageError } = await supabase.storage
              .from("audio")
              .remove([audioPath])

            if (storageError) {
              console.error(`[auto-delete-status-posts] Failed to delete audio file ${audioPath}:`, storageError)
              result.errors.push(`Failed to delete audio file for post ${post.id}: ${storageError.message}`)
            } else {
              result.deletedAudioFiles++
              console.log(`[auto-delete-status-posts] Audio file deleted: ${audioPath}`)
            }
          } else {
            console.warn(`[auto-delete-status-posts] Could not extract audio path from URL: ${post.audio_url}`)
          }
        }

        // 2.2: 関連するいいねを削除
        const { error: likesError, count: likesCount } = await supabase
          .from("likes")
          .delete({ count: "exact" })
          .eq("post_id", post.id)

        if (likesError) {
          console.error(`[auto-delete-status-posts] Failed to delete likes for post ${post.id}:`, likesError)
          result.errors.push(`Failed to delete likes for post ${post.id}: ${likesError.message}`)
        } else {
          result.deletedLikes += likesCount ?? 0
          console.log(`[auto-delete-status-posts] Deleted ${likesCount ?? 0} likes for post ${post.id}`)
        }

        // 2.3: 関連するコメントを削除
        const { error: commentsError, count: commentsCount } = await supabase
          .from("comments")
          .delete({ count: "exact" })
          .eq("post_id", post.id)

        if (commentsError) {
          console.error(`[auto-delete-status-posts] Failed to delete comments for post ${post.id}:`, commentsError)
          result.errors.push(`Failed to delete comments for post ${post.id}: ${commentsError.message}`)
        } else {
          result.deletedComments += commentsCount ?? 0
          console.log(`[auto-delete-status-posts] Deleted ${commentsCount ?? 0} comments for post ${post.id}`)
        }

        // 2.4: 投稿レコードを削除
        const { error: postError } = await supabase
          .from("posts")
          .delete()
          .eq("id", post.id)

        if (postError) {
          console.error(`[auto-delete-status-posts] Failed to delete post ${post.id}:`, postError)
          result.errors.push(`Failed to delete post ${post.id}: ${postError.message}`)
        } else {
          result.deletedPosts++
          console.log(`[auto-delete-status-posts] Post ${post.id} deleted successfully`)
        }

      } catch (error) {
        console.error(`[auto-delete-status-posts] Unexpected error processing post ${post.id}:`, error)
        result.errors.push(`Unexpected error for post ${post.id}: ${error instanceof Error ? error.message : String(error)}`)
      }
    }

    // =====================================================
    // 結果のログ出力
    // =====================================================
    console.log("[auto-delete-status-posts] Deletion completed:")
    console.log(`  - Deleted posts: ${result.deletedPosts}`)
    console.log(`  - Deleted likes: ${result.deletedLikes}`)
    console.log(`  - Deleted comments: ${result.deletedComments}`)
    console.log(`  - Deleted audio files: ${result.deletedAudioFiles}`)
    console.log(`  - Errors: ${result.errors.length}`)

    if (result.errors.length > 0) {
      console.error("[auto-delete-status-posts] Errors encountered:")
      result.errors.forEach((err, idx) => {
        console.error(`  ${idx + 1}. ${err}`)
      })
    }

    // =====================================================
    // レスポンスの返却
    // =====================================================
    const success = result.errors.length === 0

    return new Response(
      JSON.stringify({
        success,
        result,
        message: success
          ? `Successfully deleted ${result.deletedPosts} expired status posts`
          : `Completed with ${result.errors.length} errors`
      }),
      {
        status: success ? 200 : 207, // 207 Multi-Status (部分的成功)
        headers: { "Content-Type": "application/json" }
      }
    )

  } catch (error) {
    console.error("[auto-delete-status-posts] Fatal error:", error)

    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : String(error),
        message: "Fatal error occurred during deletion"
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" }
      }
    )
  }
})

/**
 * 音声ファイルURLからストレージパスを抽出
 *
 * @param audioURL - Supabase StorageのURL
 * @returns ストレージパス（例: "user_id/filename.m4a"）またはnull
 */
function extractAudioPath(audioURL: string): string | null {
  try {
    // URL例: https://ikjxfoyfeliiovbwelyx.supabase.co/storage/v1/object/public/audio/user_id/filename.m4a
    const url = new URL(audioURL)
    const pathParts = url.pathname.split("/audio/")

    if (pathParts.length === 2) {
      return pathParts[1] // "user_id/filename.m4a"
    }

    return null
  } catch (error) {
    console.error("[extractAudioPath] Failed to parse URL:", error)
    return null
  }
}
