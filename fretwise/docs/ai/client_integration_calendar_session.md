說明：
這份文件描述前端與後端 AI 工作流程的 client-side integration（Calendar 的 `updatePlan` 與 Session 的 `recordSession`），包含請求/回應格式、Dart pseudocode、取消/稍後通知語意、以及手動與驗收測試步驟。

一、updatePlan（Calendar 外部行事曆同步）

目的
- 提醒後端考慮使用者裝置行事曆（未來 7 天）並自動產生/更新 `practicePlans`、`practiceDays`、`practiceTasks`。

Client 請求（payload）
- call name: `updatePlan`
- payload: { externalCalendar: [{ title, start, end }, ...] }

Client 行為規格
- 在呼叫前顯示 progress overlay（local progress 0.0→0.95 自增）。
- 呼叫完成時補足至 1.0，延遲收尾後關閉 overlay。
- 若使用者按下 Cancel：設置 cancel flag，當雲端回傳時忽略結果；overlay 立即關閉。
- 若使用者按下 Notify Later：設置 notify-later flag，overlay 關閉但不當場套用後端回傳（後端仍可在 background 更新 DB，UI 由 streams 自動刷新）。

伪碼（Dart）

- setState(_isUpdatingPlan=true, _updateProgress=0.02)
- start local Timer 每 300ms 增加 progress 到 0.95
- try { result = await functions.httpsCallable('updatePlan').call({'externalCalendar': events}); }
- catch (e) { log }
- finally {
    if (!_cancel) setState(_updateProgress=1.0); // show completion
    stop timer; setState(_isUpdatingPlan=false)
  }

後端期望行為
- `updatePlan` Cloud Function 讀取 users/{uid} profile 與偏好，根據 externalCalendar 產生或更新 Firestore 裡的 practicePlans/practiceDays/practiceTasks
- 後端直接寫入 Firestore；client 透過 StreamBuilder 觀察並反映

二、recordSession（Session 完成後的 AI 記錄）

目的
- 將單次練習的資料送進 AI agent（`recordSession`），產生 `sessionInfo` 與 conservative patches（user profile / songProfile），但 agent 不直接寫 DB；由後端或安全 apply endpoint 處理 patch。

Client 請求（payload）
- call name: `recordSession`
- payload shape (參照 docs/ai/record_session_agent.md)
  {
    song: { title, artist, progressPercent, defaultSectionLabel|null, deadlineDate|null },
    songProfile: null | { ... },
    profile: null | { ... },
    userThoughts: { practiceDate, durationSec, userNote|null, deadlineDate|null, recordingUrls: [], startedAt|null, endedAt }
  }

Client 行為規格
- 在 SessionComplete 按下儲存/離開時呼叫 `recordSession`（目前為 best-effort 呼叫，並紀錄結果於 log）。
- 若後端回傳 `songProfilePatch` 或 `userProfilePatch`：
  - 不直接在 client apply 變更到 Firestore（安全起見），而是把 agent 回傳的 patch 傳到一個後端 `applyPatch` endpoint 或讓後端 Cloud Function 根據 patch 審核並寫入 DB。
  - 若短期需要，可顯示一個「AI 建議已產生」摘要給使用者（1–3 條 nextFocus / aiComment），並在 UI 提供 "Apply Suggestion" 按鈕給使用者決定由後端 apply。

伪碼（Dart）

final callable = FirebaseFunctions.instance.httpsCallable('recordSession');
final resp = await callable.call(payload);
final data = resp.data; // JSON per agent spec
// 顯示 data.sessionInfo.summary to user
// 若要 apply patch: send data.songProfilePatch & data.userProfilePatch to backend apply endpoint

注意事項
- `recordSession` agent spec 要求 agent 僅回傳 JSON，不要直接寫 Firebase。
- client 應以 Firestore 寫入為最終真實來源（由後端受權 apply）。

三、songProfiles.firstCompleteDate（first-complete 行為）

- 當使用者第一次完成某首歌的練習時，client 可 best-effort 在 users/{uid}/songProfiles/{songId}.firstCompleteDate 寫入日期（如果 doc 不存在就建立）。
- 這是可選的補強，主要的學習狀態仍由後端 AI 及 server-side patches 管理。
- 建議 songId 產生規則（client 與 server 應一致）： `slug = (title + '--' + artist).toLowerCase().replaceAll(non-alnum, '_')`。

四、測試步驟與驗收標準（Manual）

1) Calendar / updatePlan
- 前置：開啟模擬裝置的行事曆，新增 2 個未來 7 天的 event
- 開啟 App → 允許行事曆權限
- 操作：將 App 切到 background（home 鍵）
- 預期：
  - CalendarScreen 顯示 overlay progress（短暫）
  - 後端 `updatePlan` 被呼叫（檢視 Cloud Functions logs 或 emulator logs）
  - Firestore 的 `users/{uid}/practiceDays` / `practiceTasks` 在幾秒到幾十秒內被更新（視後端運算），UI 自動 refresh
- 邊界：按下 overlay 的 Cancel，雲端回傳不應在 client 引起 UI 錯誤（但後端仍可繼續寫 DB）

驗收標準：overlay 按鈕會立刻關閉 overlay；後端寫入會被 stream 反映到 UI（或在 logs 看到成功）。

2) Session / recordSession
- 前置：登入帳號、選取一首歌
- 操作：完成一段練習，進入 Session Complete，填寫反思，點 Back to Home（或按下 Save）
- 預期：
  - `recordSession` cloud function 被呼叫（查看 logs）
  - 如果 songProfiles doc 不存在，client 應建立 users/{uid}/songProfiles/{songId} 並寫入 `firstCompleteDate` 為今天
  - 後端回傳的 patch 被記錄在 log；若存在 apply endpoint，patch 應被後端應用並寫入 Firestore
- 驗收標準：users/{uid}/songProfiles/{songId}.firstCompleteDate 存在且格式為 YYYY-MM-DD；Cloud Function logs 顯示 recordSession 成功；若後端 apply，songProfiles 更新被確認

五、自動化測試建議
- Unit: 抽離呼叫 cloud functions 的 wrapper，可 mock 返回值來測試 client 的 overlay 行為與 cancel/notify-later flags
- Integration: 使用 Firebase Emulator Suite 測試 `updatePlan` 與 `recordSession` 的 end-to-end（模擬 firestore 與 functions）

六、下一步建議
- 在後端建立一個受控的 `applyPatch` HTTP endpoint，專門接收 agent 回傳的 patch、做審核，並寫入 Firestore（比讓 client apply 安全）
- 將 `recordSession` 回傳的 `sessionInfo` 摘要在 `SessionCompleteScreen` 顯示給使用者，並提供「套用建議」按鈕

---
文件完成者：assistant
日期：2026-06-01
