const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2/options");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { GoogleGenerativeAI, SchemaType } = require("@google/generative-ai");

admin.initializeApp();
setGlobalOptions({ maxInstances: 10 });

// Mirrors lib/utils/song_id.dart — must stay in sync
function makeSongId(title, artist) {
  const base = `${title.trim()}--${artist.trim()}`.toLowerCase();
  return base.replace(/[^a-z0-9_\-]/g, '_');
}

// 🛠️ 真實 YouTube 爬蟲 — returns the first non-duplicate result, or null if all exhausted.
// Duration filtering and Shorts handling are driven by materialRules only when explicitly stated.
async function getRealYouTubeVideo(songTitle, artist, excludeUrls = new Set(), materialRules = '') {
  const rulesLower = materialRules.toLowerCase();
  const wantsLong  = rulesLower.includes('long');
  const wantsShort = rulesLower.includes('short');

  // Only apply a duration filter when the user explicitly says long or short
  let durationParam = '';
  if (wantsLong)  durationParam = '&sp=EgIYAg%3D%3D'; // >20 min
  if (wantsShort) durationParam = '&sp=EgIYAQ%3D%3D'; // <4 min

  // Relevance: a result is accepted only if every word of the song title appears
  // as a whole token in the result title (so "Flowers" matches "Flowers (Miley
  // Cyrus)" but NOT "Wildflowers"). YouTube serves an off-topic result set to
  // datacenter IPs, and a random tutorial is worse than none — so we reject
  // anything that isn't clearly about this song.
  const tokenize = (s) => s.toLowerCase().split(/[^a-z0-9]+/).filter(Boolean);
  const titleTokens = tokenize(songTitle);
  const isRelevant = (title) => {
    if (titleTokens.length === 0) return false;
    const have = new Set(tokenize(title));
    return titleTokens.every((tok) => have.has(tok));
  };

  // Try a few query formulations — the quoted-title variant biases YouTube
  // toward results that actually contain the song name, and the localized
  // params + consent cookie coax a full results page out of the datacenter IP.
  const queries = [
    `"${songTitle}" ${artist} guitar tutorial`,
    `${songTitle} ${artist} 吉他教學 guitar lesson chords`,
  ];

  for (const q of queries) {
    try {
      const url =
        `https://www.youtube.com/results?search_query=${encodeURIComponent(q)}` +
        `&hl=en&gl=US&persist_gl=1${durationParam}`;
      const html = await fetch(url, {
        headers: {
          // User-Agent + consent cookie avoid the bot-detection / consent
          // interstitial that Cloud Function IPs otherwise trigger on YouTube.
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
          'Cookie': 'CONSENT=YES+1; SOCS=CAI',
        },
      }).then((r) => r.text());

      // Skip Shorts only when the user explicitly wants long-form video
      const shortsIds = wantsLong
        ? new Set([...html.matchAll(/\/shorts\/([a-zA-Z0-9_-]{11})/g)].map((m) => m[1]))
        : new Set();

      // Extract ranked results as {id, title} from videoRenderer entries (the
      // real search results, in order). The (?:(?!"videoId":)[\s\S])*? guard
      // keeps each captured title bound to the same renderer as its videoId.
      const results = [];
      const re = /"videoRenderer":\{"videoId":"([a-zA-Z0-9_-]{11})"(?:(?!"videoId":)[\s\S])*?"title":\{"runs":\[\{"text":"((?:[^"\\]|\\.)*)"/g;
      for (const m of html.matchAll(re)) results.push({ id: m[1], title: m[2] });

      const relevant = results.filter((r) => isRelevant(r.title));
      console.log(`[YouTube] query="${q}", results=${results.length}, ` +
        `relevant=${relevant.length}, htmlLen=${html.length}, excludeCount=${excludeUrls.size}`);

      for (const r of relevant) {
        if (shortsIds.has(r.id)) continue;
        const link = `https://www.youtube.com/watch?v=${r.id}`;
        if (!excludeUrls.has(link)) {
          console.log(`[YouTube] picked "${r.title}" (${r.id})`);
          return link;
        }
      }
    } catch (error) {
      console.error(`YouTube 搜尋失敗 (query="${q}"):`, error);
    }
  }

  console.warn(`[YouTube] no relevant non-excluded result for "${songTitle}" by "${artist}"`);
  return null;
}

async function searchSongSkill(args, uid) {
  console.log(`[SKILL] searchSong called! uid=${uid} args=${JSON.stringify(args)}`);

  const title = args.title || args.songTitle || "Unknown";
  const artist = args.artist || args.songArtist || "Unknown Artist";

  const realVideoUrl = await getRealYouTubeVideo(title, artist);

  try {
    const db = admin.firestore();
    const songRef = db.collection('users').doc(uid).collection('songLibrary').doc();

    await songRef.set({
      title: title,
      artist: artist,
      bpm: 90,
      progressPercent: 0,
      isArchived: false,
      isFavorite: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await songRef.collection('practiceMaterials').add({
      type: 'video',
      title: `${title} Guitar Tutorial`,
      videoUrl: realVideoUrl,
      active: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, songId: songRef.id, videoUrl: realVideoUrl };
  } catch (error) {
    throw new Error(error.message);
  }
}

exports.searchSong = onCall({ cors: true, invoker: "public" }, async (request) => {
  const uid = request.auth ? request.auth.uid : "test_user_123";
  return searchSongSkill(request.data, uid);
});

// --- Dummy skills (real versions are being implemented by teammates, see docs/ai/overview.md) ---
// These are also exported as onCall so Flutter can call them directly once real implementations land.
async function generateMaterialSkill(args, uid, context) {
  console.log(`[SKILL] generateMaterial called! uid=${uid} args=${JSON.stringify(args)}`);

  const db = admin.firestore();
  const { activeSongTitle: ctxTitle, activeSongArtist: ctxArtist, activeSongId: ctxSongId } = context || {};
  let songTitle  = args.songTitle  || ctxTitle  || null;
  let songArtist = args.songArtist || ctxArtist || null;
  const songId   = ctxSongId || null;

  console.log(`[generateMaterial] resolved songTitle=${songTitle} songArtist=${songArtist} songId=${songId}`);

  // Read stored materialRules so we can check for subset and always include them in the prompt
  let storedMaterialRules = null;
  try {
    const userSnap = await db.collection('users').doc(uid).get();
    if (userSnap.exists) storedMaterialRules = userSnap.data()?.preferences?.materialRules || null;
  } catch (e) {
    console.error('generateMaterial: failed to read stored preferences:', e);
  }

  // preferredMaterialTypes (format) — safe to overwrite, no subset check needed
  if (args.preferredMaterialTypes?.length) {
    try {
      await db.collection('users').doc(uid).set(
        { preferences: { preferredMaterialTypes: args.preferredMaterialTypes } },
        { merge: true }
      );
    } catch (e) {
      console.error('generateMaterial: preferredMaterialTypes write failed:', e);
    }
  }

  // materialRules (qualitative): if no stored rules yet, write immediately.
  // If stored rules exist, we do the subset check inside the Gemini call below.
  const needsSubsetCheck = !!args.materialRules && !!storedMaterialRules;
  if (args.materialRules && !storedMaterialRules) {
    try {
      await db.collection('users').doc(uid).set(
        { preferences: { materialRules: args.materialRules } },
        { merge: true }
      );
    } catch (e) {
      console.error('generateMaterial: materialRules write failed:', e);
    }
  }

  // Without a known song, still run the subset check (separate call) then return
  if (!songTitle) {
    if (needsSubsetCheck) {
      try {
        const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
        const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
        const res = await model.generateContent(
          `Stored material rules: "${storedMaterialRules}"\n` +
          `New user preference: "${args.materialRules}"\n\n` +
          `Does the new preference add anything not already covered by the stored rules?\n` +
          `Return ONLY JSON (no markdown):\n` +
          `{"isSubset": true} — new preference already covered, no update needed\n` +
          `{"isSubset": false, "merged": "concise combined phrase"} — new info found`
        );
        const m = res.response.text().trim().match(/\{[\s\S]*\}/);
        if (m) {
          const check = JSON.parse(m[0]);
          if (!check.isSubset && check.merged) {
            await db.collection('users').doc(uid).set(
              { preferences: { materialRules: check.merged } },
              { merge: true }
            );
          }
        }
      } catch (e) {
        console.error('generateMaterial: rules subset check failed:', e);
      }
    }
    return {
      status: "ok",
      note: "generateMaterial is not implemented yet (dummy was called). Tell the user their new practice material is being prepared.",
    };
  }

  // Load the active song doc and its existing materials.
  // Prefer a direct lookup by Firestore doc ID (reliable); fall back to title/artist query.
  let songDocRef = null;
  let existingMaterials = [];

  try {
    if (songId) {
      const directRef = db.collection('users').doc(uid).collection('songLibrary').doc(songId);
      const directSnap = await directRef.get();
      if (directSnap.exists) {
        songDocRef = directRef;
        if (!songTitle) songTitle = directSnap.data().title;
        if (!songArtist) songArtist = directSnap.data().artist;
        console.log(`[generateMaterial] song found by id=${songId}`);
      } else {
        console.warn(`[generateMaterial] songId=${songId} not found under uid=${uid}`);
      }
    }

    if (!songDocRef && songTitle) {
      let query = db.collection('users').doc(uid).collection('songLibrary')
        .where('title', '==', songTitle);
      if (songArtist) query = query.where('artist', '==', songArtist);
      const songSnap = await query.limit(1).get();
      if (!songSnap.empty) {
        songDocRef = songSnap.docs[0].ref;
        console.log(`[generateMaterial] song found by title/artist query`);
      } else {
        console.warn(`[generateMaterial] song not found by title="${songTitle}" artist="${songArtist}" uid=${uid}`);
      }
    }

    if (songDocRef) {
      const materialsSnap = await songDocRef.collection('practiceMaterials').get();
      existingMaterials = materialsSnap.docs.map(d => ({ ref: d.ref, ...d.data() }));
      console.log(`[generateMaterial] existing materials count=${existingMaterials.length}`);
    }
  } catch (e) {
    console.error('generateMaterial: failed to fetch song/materials:', e);
  }

  if (!songDocRef) {
    console.warn(`[generateMaterial] aborting — could not find song document`);
    return {
      status: "ok",
      note: "I couldn't find this song in your library. Try adding it first.",
    };
  }

  const preferredType = (args.preferredMaterialTypes || [])[0] || 'video';
  const existingUrls = new Set(existingMaterials.map(m => m.videoUrl).filter(Boolean));
  const urlRules = args.materialRules || storedMaterialRules || '';

  // Step 1: Find a YouTube URL FIRST — independent of Gemini.
  // Gemini's canFind=false used to abort here, but that blocked valid new URLs.
  let videoUrl = null;
  if (preferredType === 'video') {
    videoUrl = await getRealYouTubeVideo(songTitle, songArtist || '', existingUrls, urlRules);
    if (!videoUrl) {
      console.warn(`[generateMaterial] aborting — YouTube scraper returned no new URL (all exhausted)`);
      return { status: "ok", note: "sorry I really can't find new materials" };
    }
    console.log(`[generateMaterial] YouTube URL found: ${videoUrl}`);
  }

  // Step 2: Ask Gemini for a descriptive title/description (optional).
  // If Gemini fails or returns a duplicate title, we fall back to a generic title
  // and still write to Firestore — the URL is what matters.
  const existingTitlesLower = new Set(existingMaterials.map(m => (m.title || '').toLowerCase().trim()));
  let materialTitle = `${songTitle} — Guitar Tutorial`;
  let materialDescription = '';

  try {
    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

    const existingSummary = existingMaterials.length
      ? existingMaterials.map(m => `- [${m.type}] "${m.title}"`).join('\n')
      : '(none yet)';

    const contextLine = args.requestContext ? ` The user asked: "${args.requestContext}".` : '';

    let rulesSection = '';
    let subsetCheckInstructions = '';
    let subsetCheckJsonFields = '';
    if (needsSubsetCheck) {
      rulesSection = `\nStored material rules: "${storedMaterialRules}"\nNew user preference: "${args.materialRules}"`;
      subsetCheckInstructions =
        `\n\nAlso check if the new preference adds anything beyond the stored rules:\n` +
        `- "rulesUpdated": false — new preference already covered, no Firestore update needed\n` +
        `- "rulesUpdated": true and "mergedRules": "concise combined phrase" — new info found`;
      subsetCheckJsonFields = `, "rulesUpdated": bool, "mergedRules": "..." (only if rulesUpdated)`;
    } else if (args.materialRules) {
      rulesSection = `\nMaterial preference: ${args.materialRules}.`;
    } else if (storedMaterialRules) {
      rulesSection = `\nMaterial preference: ${storedMaterialRules}.`;
    }

    const prompt = `The user is practicing "${songTitle}"${songArtist ? ` by ${songArtist}` : ''} and wants a new ${preferredType} practice resource.${contextLine}${rulesSection}

Existing materials already saved for this song — do NOT duplicate any of these:
${existingSummary}

Suggest a descriptive title and one-sentence description for a NEW ${preferredType} guitar resource for this song, clearly distinct from the list above.${subsetCheckInstructions}

Return ONLY a JSON object with no markdown:
{"title": "specific title", "description": "one-sentence description"${subsetCheckJsonFields}}`;

    const result = await model.generateContent(prompt);
    const text = result.response.text().trim();
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      const suggestion = JSON.parse(jsonMatch[0]);

      // Write materialRules update only if Gemini says the new preference adds information
      if (needsSubsetCheck && suggestion.rulesUpdated && suggestion.mergedRules) {
        try {
          await db.collection('users').doc(uid).set(
            { preferences: { materialRules: suggestion.mergedRules } },
            { merge: true }
          );
        } catch (e) {
          console.error('generateMaterial: materialRules merge write failed:', e);
        }
      }

      if (suggestion.title && !existingTitlesLower.has(suggestion.title.toLowerCase().trim())) {
        materialTitle = suggestion.title;
        materialDescription = suggestion.description || '';
      } else if (suggestion.title) {
        console.warn(`[generateMaterial] Gemini title "${suggestion.title}" is a duplicate — using generic title`);
      }
    }
    console.log(`[generateMaterial] material title="${materialTitle}"`);
  } catch (e) {
    console.warn(`[generateMaterial] Gemini metadata call failed (using generic title): ${e.message}`);
  }

  // Step 3: Write to Firestore — always reached as long as a URL was found.
  const materialData = {
    type: preferredType,
    title: materialTitle,
    description: materialDescription,
    active: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (videoUrl) materialData.videoUrl = videoUrl;

  try {
    const batch = db.batch();
    for (const m of existingMaterials) {
      if (m.active) batch.update(m.ref, { active: false });
    }
    const newMatRef = songDocRef.collection('practiceMaterials').doc();
    batch.set(newMatRef, materialData);
    await batch.commit();
    console.log(`[generateMaterial] ✅ batch committed — new material "${materialTitle}" written to Firestore`);
    return { status: "ok", materialAdded: true, title: materialTitle };
  } catch (e) {
    console.error('generateMaterial: batch write failed:', e);
    return { status: "ok", note: "Material found but could not be saved." };
  }
}

exports.generateMaterial = onCall({ cors: true, invoker: "public" }, async (request) => {
  const uid = request.auth ? request.auth.uid : "test_user_123";
  return generateMaterialSkill(request.data, uid);
});

const AGENT_SYSTEM_PROMPT = `You are a guitar practice scheduling AI agent for the Fretwise app.

Given the user's external calendar events (next 7 days), learning preferences, song library, and current practice plan, produce a new or updated practice schedule.

RULES:
- Avoid conflicts with existing calendar events
- Reduce practice on busy days, increase practice on free days
- Respect the user's preferred session length and practice times
- Prioritize songs with upcoming deadlines
- Never schedule practice during existing calendar events

BUSYNESS CLASSIFICATION:
| Total Event Hours | Busyness Level | Max Practice Minutes |
|---|---|---|
| 0 hours | free | preferredSessionMinutes × 1.5 (round to nearest 5) |
| 0.1 – 2 hours | light | preferredSessionMinutes |
| 2.1 – 5 hours | moderate | preferredSessionMinutes × 0.7 (round to nearest 5) |
| 5.1 – 8 hours | busy | preferredSessionMinutes × 0.4 (min 10) |
| 8+ hours | packed | 0 (rest day) |

If preferredSessionMinutes is not set, default to 20 minutes.

SONG SELECTION PRIORITY:
1. Songs with deadlineDate within 14 days get highest priority
2. Songs with lower progressPercent get more practice time
3. isFavorite songs get slight priority boost
4. Rotate through 2-3 songs per week for variety

TASK DESIGN:
- CRITICAL: Generate EXACTLY ONE task in the \`practiceTasks\` array for each day. The length of \`practiceTasks\` MUST equal the number of active practice days.
- If you want the user to do a warm-up or practice multiple songs, COMBINE them into a single task. Put all instructions in the single task's \`instructions\` field. Do NOT create separate "Warm-up" tasks.
- Each task should have a clear, specific title (e.g., "Warm-up & Love Story Practice")
- Include practical instructions the user can follow
- Build on the user's weakTechniques
- Progress logically across the week
- Progress logically across the week

Return ONLY valid JSON, no markdown, no prose outside JSON.

OUTPUT FORMAT:
{
  "practicePlan": {
    "title": "string",
    "summary": "string",
    "activeFromDate": "YYYY-MM-DD",
    "activeToDate": "YYYY-MM-DD",
    "linkedSongIds": ["string"],
    "generatedReason": "string"
  },
  "practiceDays": [
    {
      "date": "YYYY-MM-DD",
      "status": "planned | rest",
      "plannedMinutes": number,
      "linkedSongIds": ["string"],
      "busynessLevel": "free | light | moderate | busy | packed",
      "busynessReason": "string"
    }
  ],
  "practiceTasks": [
    {
      "dayId": "YYYY-MM-DD",
      "songId": "string",
      "title": "string",
      "instructions": "string",
      "minutes": number,
      "orderIndex": number
    }
  ]
}`;

// ─── Helper: compute today's date string ──────────────────────────────────

function getTodayStr() {
  const now = new Date();
  // Use Asia/Taipei timezone
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Taipei",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  return formatter.format(now); // returns YYYY-MM-DD
}

// ─── Helper: generate a plan ID ───────────────────────────────────────────
function generatePlanId() {
  const today = getTodayStr().replace(/-/g, "");
  return `plan_${today}_${Date.now().toString(36)}`;
}

// ─── updatePlan Cloud Function ────────────────────────────────────────────

async function updatePlanSkill(args, uid) {
// uid is passed as argument
    const externalCalendar = args.externalCalendar || [];
    const db = admin.firestore();

    logger.info(`updatePlan called by user ${uid}`, {
      eventCount: externalCalendar.length,
    });

    let text;
  try {
      // 2. Read user data from Firestore
      const userDocRef = db.collection("users").doc(uid);
      const userDoc = await userDocRef.get();
      let userData = userDoc.exists ? userDoc.data() : {};

      // If the AI coach passed a requestContext, save it as DayAndTimeRule in Firestore
      if (args.requestContext) {
        userData.DayAndTimeRule = args.requestContext;
        await userDocRef.set({ DayAndTimeRule: args.requestContext }, { merge: true });
        logger.info("Updated DayAndTimeRule from coach requestContext", { rule: args.requestContext });
      }

      const profile = userData.profile || {
        skillLevel: "beginner",
        preferredSessionMinutes: 20,
      };
      const preferences = userData.preferences || {};

      // 3. Read song library (non-archived only)
      const songLibSnap = await db
        .collection("users")
        .doc(uid)
        .collection("songLibrary")
        .where("isArchived", "==", false)
        .get();

      const songLibrary = songLibSnap.docs.map((doc) => ({
        songId: doc.id,
        ...doc.data(),
      }));

      // 4. Read existing active plan (if any)
      let existingPlan = null;
      if (userData.activePlanId) {
        const planDoc = await db
          .collection("users")
          .doc(uid)
          .collection("practicePlans")
          .doc(userData.activePlanId)
          .get();
        if (planDoc.exists) {
          existingPlan = { planId: planDoc.id, ...planDoc.data() };
        }
      }

      const today = getTodayStr();

      // 5. Build AI input
      const aiInput = {
        externalCalendar,
        profile: {
          skillLevel: profile.skillLevel || "beginner",
          experienceSummary: profile.experienceSummary || null,
          currentGoals: profile.currentGoals || [],
          weakTechniques: profile.weakTechniques || [],
          strongTechniques: profile.strongTechniques || [],
          preferredSessionMinutes: profile.preferredSessionMinutes || 20,
          preferredDayAndTime: userData.preferredDayAndTime || userData.preferedPracticeTime || userData.preferredPracticeTime || profile.preferredDayAndTime || null,
          dayAndTimeRule: userData.DayAndTimeRule || userData.dayAndTimeRule || null,
        },
        preferences: {
          favoriteGenres: preferences.favoriteGenres || [],
          favoriteArtists: preferences.favoriteArtists || [],
          preferredMaterialTypes: preferences.preferredMaterialTypes || [],
        },
        songLibrary: songLibrary.map((s) => ({
          songId: s.songId,
          title: s.title || "Unknown",
          artist: s.artist || "Unknown",
          bpm: s.bpm || null,
          progressPercent: s.progressPercent || 0,
          deadlineDate: s.deadlineDate || null,
          isFavorite: s.isFavorite || false,
          isArchived: false,
        })),
        existingPlan,
        today,
      };

      logger.info("AI input assembled", {
        songCount: songLibrary.length,
        hasExistingPlan: !!existingPlan,
        preferredDayAndTime: aiInput.profile.preferredDayAndTime,
        dayAndTimeRule: aiInput.profile.dayAndTimeRule,
        externalEventsCount: externalCalendar.length,
      });

      console.log("=== [AI Scheduling Criteria] ===");
      console.log(`Preferred Practice Days: ${aiInput.profile.preferredDayAndTime || "None (Flexible)"}`);
      console.log(`Day And Time Rule (Coach): ${aiInput.profile.dayAndTimeRule || "None"}`);
      console.log(`External Calendar Events Found: ${externalCalendar.length} events in the next 28 days.`);
      console.log("================================");

      // 6. Call Gemini AI via GoogleGenerativeAI
      const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
      let text = "";
      const model = genAI.getGenerativeModel({
        model: "gemini-2.5-flash",
        generationConfig: {
          temperature: 0.3,
          topP: 0.8,
          maxOutputTokens: 8192,
          responseMimeType: "application/json",
        },
        systemInstruction: AGENT_SYSTEM_PROMPT,
      });

      const userPrompt = `Here is the user's data. Generate a 4-week (28-day) practice plan based on this information.

CRITICAL CONSTRAINTS:
1. DO NOT schedule ANY practice on dates that appear in the 'externalCalendar'. If a date has EVEN ONE external event, you MUST CANCEL the practice for that ENTIRE DAY (schedule 0 minutes).
2. STRICTLY follow the 'dayAndTimeRule' string. If the user explicitly asks to skip a certain date (e.g., "skip June 21, 2026"), you MUST NOT schedule any practice on that date (0 minutes).
3. The generated plan must cover exactly 28 days starting from 'today'.
4. VERY IMPORTANT: You have a strict output token limit. Keep all text fields (like "instructions" and "summary") EXTREMELY short (1-2 sentences max). Limit the number of tasks per day to at most 2-3 to ensure the entire 28-day JSON plan fits in the response without being truncated.
5. EXTREMELY IMPORTANT: You MUST ONLY schedule practice sessions on the days of the week specified in 'profile.preferredDayAndTime'. For all other days of the week, you MUST schedule 0 minutes of practice and NO tasks. If 'profile.preferredDayAndTime' is empty or null, schedule normally. But if it has days listed (e.g. "Monday, 8:00 pm"), those are the ONLY days the user can practice.
6. DO NOT COMPENSATE: If a preferred practice day is blocked by externalCalendar events or dayAndTimeRule, DO NOT attempt to "make up" the missed practice by scheduling on other days. Just skip it entirely. Under NO circumstances should you schedule practice on a non-preferred day.
7. ALWAYS output valid JSON. If you cannot fit all tasks into the allowed preferred days without violating constraints, DROP the remaining tasks. It is better to have fewer tasks than to schedule on a forbidden day. NEVER output conversational text or apologies.

User Data:\n\n${JSON.stringify(aiInput, null, 2)}`;

    // removed extra try
      logger.info("Calling Gemini AI...");
      const result = await model.generateContent(userPrompt);
      const response = result.response;
      if (!response || !response.candidates || response.candidates.length === 0) {
        throw new Error("Gemini returned empty or invalid response object");
      }
      text = response.candidates[0].content.parts[0].text;

      logger.info("Gemini AI response received", {
        responseLength: text.length,
      });

      // 7. Parse AI response
      const cleanJsonStr = text.replace(/```json\n?|```/g, "").trim();
      let aiOutput;
      try {
        aiOutput = JSON.parse(cleanJsonStr);
      } catch (parseErr) {
        logger.error("JSON Parse Error. Raw text:", text);
        throw new Error("AI output was not valid JSON: " + text.substring(0, 500));
      }

      // 7. Extract items
      const planObj = aiOutput.practicePlan || {};
      const daysArr = aiOutput.practiceDays || [];
      const tasksArr = aiOutput.practiceTasks || [];

      // Validate required fields
      if (
        !aiOutput.practicePlan ||
        !aiOutput.practiceDays ||
        !aiOutput.practiceTasks
      ) {
        logger.error("AI response missing required fields", { aiOutput });
        throw new HttpsError(
          "internal",
          "AI response is incomplete. Please try again."
        );
      }

      // 8. Delete old planned tasks to avoid duplicate/stale tasks
      const oldTasksSnap = await db
        .collection("users")
        .doc(uid)
        .collection("practiceTasks")
        .where("status", "==", "planned")
        .get();

      // 9. Write results to Firestore (batch write)
      const batch = db.batch();

      oldTasksSnap.forEach((doc) => {
        batch.delete(doc.ref);
      });

      const planId = generatePlanId();
      const userRef = db.collection("users").doc(uid);

      // 8a. Write PracticePlan
      const planRef = userRef.collection("practicePlans").doc(planId);
      batch.set(planRef, {
        ...planObj,
        status: "active",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 8b. Update user's activePlanId
      batch.update(userRef, {
        activePlanId: planId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 8c. Write PracticeDays
      for (const day of daysArr) {
        if (!day.date) continue;
        const dayRef = userRef.collection("practiceDays").doc(day.date);
        batch.set(
          dayRef,
          {
            planId,
            date: day.date,
            status: day.status || "planned",
            plannedMinutes: day.plannedMinutes || 0,
            linkedSongIds: day.linkedSongIds || [],
            completedMinutes: 0,
            completedSessionCount: 0,
            completedSongIds: [],
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }

      // 8d. Write PracticeTasks
      for (let i = 0; i < tasksArr.length; i++) {
        const task = tasksArr[i];
        const taskId = `task_${planId}_${i}`;
        const taskRef = userRef.collection("practiceTasks").doc(taskId);
        batch.set(taskRef, {
          planId,
          dayId: task.dayId,
          originalDayId: task.dayId,
          songId: task.songId || null,
          title: task.title || "Practice",
          instructions: task.instructions || "",
          minutes: task.minutes || 15,
          orderIndex: task.orderIndex || i,
          status: "planned",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Also add songTitle and artist for frontend display
        if (task.songId) {
          const songData = songLibrary.find((s) => s.songId === task.songId);
          if (songData) {
            batch.update(taskRef, {
              songTitle: songData.title,
              artist: songData.artist,
              bpm: songData.bpm || null,
            });
          }
        }
      }

      await batch.commit();

      logger.info("Practice plan written to Firestore", {
        planId,
        daysCount: daysArr.length,
        tasksCount: tasksArr.length,
      });

      console.log("=== [AI Generated Schedule Output] ===");
      console.log(`Plan Name: ${planObj.title || "Unknown"}`);
      console.log(`Total Days: ${daysArr.length}`);
      daysArr.forEach(day => {
        const tasksForDay = tasksArr.filter(t => t.dayId === day.date);
        if (tasksForDay.length > 0) {
          console.log(`- Day ${day.date}: ${tasksForDay.length} tasks scheduled.`);
          tasksForDay.forEach(t => {
            console.log(`  -> ${t.title} (${t.minutes} mins)`);
          });
        } else {
          console.log(`- Day ${day.date}: 0 tasks (Skipped)`);
        }
      });
      console.log("======================================");

      return {
        success: true,
        planId,
        message: `Practice plan "${planObj.title || "Unknown"}" created with ${tasksArr.length} tasks over ${daysArr.length} days.`,
      };
    } catch (err) {
      const responseText = typeof text !== 'undefined' ? text : null;
      let errorDetails = err.message || String(err);
      if (err instanceof SyntaxError || err.message === "Unexpected end of JSON input" || err.message.includes("JSON")) {
          const tail = responseText ? responseText.substring(Math.max(0, responseText.length - 500)) : 'No text generated';
          errorDetails = "AI returned invalid JSON. Tail: " + tail;
      }
      logger.error("updatePlan failed", { error: errorDetails, stack: err.stack, responseText });
      throw new HttpsError("aborted", errorDetails);
    }
  
}

exports.updatePlan = onCall({ cors: true, invoker: "public", region: "asia-east1", secrets: ["GEMINI_API_KEY"], timeoutSeconds: 300, memory: "512Mi" }, async (request) => {
  const uid = request.auth ? request.auth.uid : "test_user_123";
  return updatePlanSkill(request.data, uid);
});

const coachSkills = {
  generateMaterial: generateMaterialSkill,
  updatePlan: updatePlanSkill,
  updateFeed: updateFeedSkill,
};

const coachToolDeclarations = [
  {
    name: "generateMaterial",
    description:
      "Generate or refresh practice material for a song, OR save the user's preferred material format. Call this when the user asks for a new, different, easier, or harder video, tutorial, exercise, or practice material — and also when the user expresses a format preference such as 'I prefer tabs', 'can I get a chord chart', or 'I want exercises instead of videos'.",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        songTitle: {
          type: SchemaType.STRING,
          description: "Title of the song the material is for. Use the active song if the user doesn't name one.",
        },
        songArtist: {
          type: SchemaType.STRING,
          description: "Artist of the song, if known.",
        },
        preferredMaterialTypes: {
          type: SchemaType.ARRAY,
          items: { type: SchemaType.STRING },
          description: "Format types the user prefers, e.g. ['video', 'tabs', 'exercise', 'chordChart']. Fill this only when the user names a specific format.",
        },
        materialRules: {
          type: SchemaType.STRING,
          description: "Qualitative material preferences beyond format, e.g. 'short beginner-friendly tutorials', 'slow step-by-step explanations', 'challenging exercises'. Fill this only when the user expresses this kind of preference.",
        },
        requestContext: {
          type: SchemaType.STRING,
          description: "What the user asked for, e.g. 'wants an easier strumming exercise' or 'prefers tabs over videos'.",
        },
      },
      required: ["requestContext"],
    },
  },
  {
    name: "updatePlan",
    description:
      "Create or update the user's practice schedule. Call this when the user wants to change their time plan, practice schedule, practice days, or deadlines — including canceling, skipping, or rescheduling a specific session, or saying they are too busy or unavailable at a certain time.",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        preferredDayAndTime: {
          type: SchemaType.STRING,
          description: "The user's new preferred day and time for practice, e.g. 'Saturday 3pm' or 'weekday evenings'.",
        },
        preferredSessionMinutes: {
          type: SchemaType.NUMBER,
          description: "Preferred session duration in minutes, if the user mentions it.",
        },
        dayAndTimeRule: {
          type: SchemaType.STRING,
          description: "A plain-English scheduling rule with specific absolute dates — never relative terms like 'this Sunday' or 'next Monday'. E.g. 'skip June 21, 2026' or 'move to weekends only starting June 22, 2026'.",
        },
        requestContext: {
          type: SchemaType.STRING,
          description: "What schedule change the user asked for, e.g. 'move practice to weekends only'.",
        },
      },
      required: ["requestContext"],
    },
  },
  {
    name: "updateFeed",
    description:
      "Update the user's inspiration feed and music preferences. Call this when the user says they like or dislike an artist, band, genre, style, type of music, or song tempo, or gives taste feedback that should affect recommendations.",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        likedArtists: {
          type: SchemaType.ARRAY,
          items: { type: SchemaType.STRING },
          description: "Artists or bands the user says they like.",
        },
        dislikedArtists: {
          type: SchemaType.ARRAY,
          items: { type: SchemaType.STRING },
          description: "Artists or bands the user says they dislike.",
        },
        likedGenres: {
          type: SchemaType.ARRAY,
          items: { type: SchemaType.STRING },
          description: "Genres or styles the user says they like.",
        },
        dislikedGenres: {
          type: SchemaType.ARRAY,
          items: { type: SchemaType.STRING },
          description: "Genres or styles the user says they dislike.",
        },
        tempoPreference: {
          type: SchemaType.STRING,
          description: "The user's song tempo preference, e.g. 'slow ballads', 'upbeat pop', 'fast rock'.",
        },
        requestContext: {
          type: SchemaType.STRING,
          description: "What taste feedback the user gave, e.g. 'likes Ed Sheeran and acoustic pop'.",
        },
      },
      required: ["requestContext"],
    },
  },
];

// --- AI Chat Coach ---
exports.chatWithCoach = onCall({ cors: true, invoker: "public", secrets: ["GEMINI_API_KEY"] }, async (request) => {
  const message = (request.data.message || '').trim();
  const history = request.data.history || [];
  const fromScreen = request.data.fromScreen || 'home';
  const activeSongTitle = request.data.activeSongTitle || null;
  const activeSongArtist = request.data.activeSongArtist || null;
  const activeSongId = request.data.activeSongId || null;
  const uid = request.auth ? request.auth.uid : "test_user_123";

  if (!message) throw new Error("Message cannot be empty");

  console.log(`[chatWithCoach] fromScreen=${fromScreen} activeSongTitle=${activeSongTitle} activeSongArtist=${activeSongArtist} message="${message}"`);

  const db = admin.firestore();
  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

  // Pull user profile and preferences for personalized coaching
  let userProfileContext = '';
  try {
    const userSnap = await db.collection('users').doc(uid).get();
    if (userSnap.exists) {
      const u = userSnap.data();
      const profile = u.profile || {};
      const prefs = u.preferences || {};
      const parts = [];
      if (profile.skillLevel)          parts.push(`Skill level: ${profile.skillLevel}.`);
      if (profile.experienceSummary)   parts.push(profile.experienceSummary);
      if (profile.currentGoals?.length)    parts.push(`Current goals: ${profile.currentGoals.join(', ')}.`);
      if (profile.weakTechniques?.length)  parts.push(`Weak areas: ${profile.weakTechniques.join(', ')}.`);
      if (profile.strongTechniques?.length) parts.push(`Strengths: ${profile.strongTechniques.join(', ')}.`);
      if (prefs.favoriteGenres?.length)    parts.push(`Favourite genres: ${prefs.favoriteGenres.join(', ')}.`);
      if (prefs.favoriteArtists?.length)   parts.push(`Favourite artists: ${prefs.favoriteArtists.join(', ')}.`);
      if (parts.length > 0) userProfileContext = `About this user — ${parts.join(' ')}`;
    }
  } catch (e) {
    console.error('User profile fetch failed, continuing without it:', e);
  }

  // Pull the user's active song library so the coach knows what they're working on
  let libraryContext = '';
  try {
    const snap = await db.collection('users').doc(uid).collection('songLibrary')
      .where('isArchived', '==', false).get();
    const songs = snap.docs.map(d => {
      const s = d.data();
      return `${s.title} by ${s.artist}`;
    });
    if (songs.length > 0) {
      libraryContext = `The user is currently practicing these songs: ${songs.join(', ')}.`;
    }
  } catch (e) {
    console.error('Library fetch failed, continuing without it:', e);
  }

  // Build context about the specific song and screen the user opened chat from,
  // enriched with the user's SongProfile (strengths, weaknesses, focus areas) if available
  let activeSongContext = '';
  if (activeSongTitle) {
    const artistPart = activeSongArtist ? ` by ${activeSongArtist}` : '';

    const profileLines = [];
    try {
      const songId = makeSongId(activeSongTitle, activeSongArtist || '');
      const profileSnap = await db.collection('users').doc(uid)
        .collection('songProfiles').doc(songId).get();
      if (profileSnap.exists) {
        const sp = profileSnap.data();
        if (sp.problemAreas?.length)    profileLines.push(`Problem areas: ${sp.problemAreas.join(', ')}.`);
        if (sp.strengthAreas?.length)   profileLines.push(`Strengths: ${sp.strengthAreas.join(', ')}.`);
        if (sp.recommendedFocus?.length) profileLines.push(`Recommended focus: ${sp.recommendedFocus.join(', ')}.`);
        if (sp.latestAiSummary)         profileLines.push(sp.latestAiSummary);
      }
    } catch (e) {
      console.error('SongProfile fetch failed, continuing without it:', e);
    }

    const profileContext = profileLines.length ? ' ' + profileLines.join(' ') : '';

    if (fromScreen === 'practicing') {
      activeSongContext = `The user is currently in a practice session for "${activeSongTitle}"${artistPart}.${profileContext} Focus your advice on this song and their current problem areas.`;
    } else if (fromScreen === 'sessionComplete') {
      activeSongContext = `The user just finished a practice session for "${activeSongTitle}"${artistPart}.${profileContext} They may want reflection or advice on what to work on next.`;
    } else {
      activeSongContext = `The user is asking about "${activeSongTitle}"${artistPart}.${profileContext} Answer their question in the context of this song.`;
    }
  }

  const todayStr = new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric', weekday: 'long' });

  const systemInstruction = [
    'You are an expert AI guitar coach inside the FretWise app.',
    `Today is ${todayStr}.`,
    'Keep every reply to 2–3 sentences maximum. Give one concrete, actionable step at a time — not a full plan. If there is more to cover, end with a short prompt like "Want the next step?" so the user can continue at their own pace.',
    'Be specific to the song: name actual chords, techniques, or patterns relevant to it. Never give advice so generic it could apply to any song.',
    'Skip filler phrases like "great question!" or "you\'ve got this!" — lead with the useful information.',
    'When the user asks for a new or different video, tutorial, exercise, or any practice material — including easier or harder versions, a different format, or with qualitative preferences like "short" or "beginner-friendly" — call the generateMaterial tool. Pass preferredMaterialTypes when the user names a format (e.g. tabs, video); pass materialRules when the user describes qualitative preferences (e.g. "easy short tutorials"). If the tool response contains a "note" field, relay it verbatim to the user; otherwise include a brief helpful tip in your text reply.',
    'When the user wants to change, cancel, skip, or reschedule a practice session, or says they are too busy or unavailable at a certain time, call the updatePlan tool. Always resolve relative date references (e.g. "this Sunday", "next Monday") to specific calendar dates using today\'s date before filling dayAndTimeRule. Then confirm the change in your text reply.',
    'When the user says they like or dislike an artist, band, genre, style, type of music, or song tempo — call the updateFeed tool, then acknowledge their taste in your text reply.',
    'Never claim that material was generated, the plan was changed, or the feed was updated unless you actually called the relevant tool in this turn.',
    userProfileContext,
    libraryContext,
    activeSongContext,
  ].filter(Boolean).join(' ');

  const model = genAI.getGenerativeModel({
    model: 'gemini-2.5-flash',
    systemInstruction,
    tools: [{ functionDeclarations: coachToolDeclarations }],
  });

  // Gemini uses 'model' where our app uses 'assistant'.
  // Also drop any leading model turns — Gemini requires history to start with a user turn.
  // Cap to last 6 messages (3 turns) to keep token count stable.
  const allHistory = history.slice(-6).map(m => ({
    role: m.role === 'assistant' ? 'model' : 'user',
    parts: [{ text: m.text }],
  }));
  const firstUserIdx = allHistory.findIndex(m => m.role === 'user');
  const geminiHistory = firstUserIdx === -1 ? [] : allHistory.slice(firstUserIdx);

  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const chat = model.startChat({ history: geminiHistory });
      let result = await chat.sendMessage(message);
      const skillsCalled = [];

      // If the model asked to use a skill, run it and feed the result back
      // so it can produce a final text reply. Cap rounds to avoid loops.
      for (let round = 0; round < 3; round++) {
        const calls = result.response.functionCalls();
        console.log(`[chatWithCoach] round=${round} functionCalls=${JSON.stringify(calls)}`);
        if (!calls || calls.length === 0) break;

        const responses = await Promise.all(calls.map(async (call) => {
          const skill = coachSkills[call.name];
          skillsCalled.push(call.name);
          const response = skill
            ? await skill(call.args || {}, uid, { fromScreen, activeSongTitle, activeSongArtist, activeSongId })
            : { status: "error", note: `Unknown skill: ${call.name}` };
          return { functionResponse: { name: call.name, response } };
        }));

        result = await chat.sendMessage(responses);
      }

      return { reply: result.response.text(), skillsCalled };
    } catch (e) {
      const is503 = e?.status === 503 || e?.message?.includes('503') || e?.message?.includes('overloaded');
      if (is503 && attempt < 2) {
        await new Promise(r => setTimeout(r, 1000 * (attempt + 1)));
        continue;
      }
      console.error('[chatWithCoach] Gemini error:', e);
      throw e;
    }
  }
});

// --- 巧君負責的功能 2: 更新 Feed (無限延伸 + 隨機版) ---
// --- 修正後的 更新 Feed 功能 ---
async function updateFeedSkill(args, uid) {
  console.log(`[SKILL] updateFeed 執行中, uid=${uid}, args=`, JSON.stringify(args));

  const db = admin.firestore();
  const userRef = db.collection('users').doc(uid);
  const feedCol = userRef.collection('feed');

  // 1. 讀取使用者的真實偏好 (從 Firestore 抓取)
  const userSnap = await userRef.get();
  const userData = userSnap.data() || {};
  const prefs = userData.preferences || {};

  // 1b. 把這次對話的口味更新寫回 preferences (likedGenres / likedArtists 等)
  const a = args || {};
  const mergeUnique = (existing, add) =>
    Array.from(new Set([...(existing || []), ...(add || [])]));
  const removeAll = (existing, remove) =>
    (existing || []).filter((x) => !(remove || []).includes(x));

  const newGenres = removeAll(mergeUnique(prefs.favoriteGenres, a.likedGenres), a.dislikedGenres);
  const newArtists = removeAll(mergeUnique(prefs.favoriteArtists, a.likedArtists), a.dislikedArtists);

  await userRef.set({
    preferences: {
      favoriteGenres: newGenres,
      favoriteArtists: newArtists,
      ...(a.tempoPreference ? { tempoPreference: a.tempoPreference } : {}),
    },
  }, { merge: true });

  const favoriteArtists = newArtists.join(', ') || "Popular artists";
  const favoriteGenres = newGenres.join(', ') || "Pop, Rock";
  const skillLevel = (userData.profile?.skillLevel) || "beginner";

  try {
    // 2. 清空舊的 Feed (為了確保滑動體驗，建議每次更新時更換內容，或限制總量)
    const oldDocs = await feedCol.get();
    const batch = db.batch();
    oldDocs.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();

    let songs = [];
    try {
      const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
      const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" }); // 建議用 flash 比較快

      const prompt = `You are an expert guitar teacher. 
      Recommend 10 popular songs for a student with these tastes:
      - Liked Artists: ${favoriteArtists}
      - Preferred Genres: ${favoriteGenres}
      - Skill Level: ${skillLevel}

      Return ONLY a JSON array. DO NOT include markdown tags like \`\`\`json.
      Expected JSON structure:
      [{"title": "Song Title", "artist": "Artist", "description": "Why this song is great for you", "genre": "Pop"}]`;

      const result = await model.generateContent(prompt);
      let responseText = result.response.text().trim();
      
      // 移除可能出現的 markdown 標籤
      if (responseText.startsWith('```')) {
        responseText = responseText.replace(/^```(?:json)?\n?/, '').replace(/\n?```$/, '').trim();
      }
      songs = JSON.parse(responseText);
      console.log(`[AI] 成功生成 ${songs.length} 首歌`);

    } catch (aiError) {
      console.error("Gemini 呼叫失敗，啟用備用名單", aiError);
      // 3. 修正後的備用名單 (Fallback)
      const fallbackPool = [
        { "title": "Shake It Off", "artist": "Taylor Swift", "description": "Classic G-Am-C progression. Perfect for upbeat strumming practice.", "genre": "Pop" },
        { "title": "good 4 u", "artist": "Olivia Rodrigo", "description": "Energetic Pop-Rock. Uses simple power chords that are easier than full bar chords.", "genre": "Pop Rock" },
        { "title": "Love Story", "artist": "Taylor Swift", "description": "The ultimate Country-Pop anthem. Great for practicing steady down-up strums.", "genre": "Country" },
        { "title": "bad idea right?", "artist": "Olivia Rodrigo", "description": "Upbeat and fun. Focuses on rhythmic muting and simple chord changes.", "genre": "Pop Rock" },
        { "title": "You Belong With Me", "artist": "Taylor Swift", "description": "Classic Taylor country style. Very straightforward open chords.", "genre": "Country Pop" },
        { "title": "Cruel Summer", "artist": "Taylor Swift", "description": "High energy Pop. Great for practicing timing and syncopated strumming.", "genre": "Pop" },
        { "title": "Complicated", "artist": "Avril Lavigne", "description": "Early 2000s Pop Rock. Very similar to Olivia Rodrigo's style, easy 4-chord progression.", "genre": "Pop Rock" },
        { "title": "Paper Rings", "artist": "Taylor Swift", "description": "Fast-paced and joyful. Excellent for building speed in chord transitions.", "genre": "Pop Rock" },
        { "title": "vampire", "artist": "Olivia Rodrigo", "description": "Builds from piano to rock. We've simplified the guitar arrangement for you.", "genre": "Pop Rock" },
        { "title": "Espresso", "artist": "Sabrina Carpenter", "description": "Current upbeat Pop. Fun catchy rhythm that fits your pop preference.", "genre": "Pop" },
        { "title": "Party In The U.S.A.", "artist": "Miley Cyrus", "description": "Very easy 3-chord song. Fits the country-pop crossover vibe perfectly.", "genre": "Pop" },
        { "title": "Mean", "artist": "Taylor Swift", "description": "Upbeat country folk. Great for practicing fast folk-style strumming.", "genre": "Country" },
        { "title": "Sk8er Boi", "artist": "Avril Lavigne", "description": "High energy pop-punk. Uses simple power chords, very beginner friendly.", "genre": "Pop Rock" },
        { "title": "Stay Stay Stay", "artist": "Taylor Swift", "description": "Cute and upbeat. Very simple chords (G, C, D, Em) throughout.", "genre": "Country Pop" },
        { "title": "deja vu", "artist": "Olivia Rodrigo", "description": "Atmospheric but steady rhythm. Good for practicing consistent strumming.", "genre": "Pop Rock" },
        { "title": "Our Song", "artist": "Taylor Swift", "description": "Early Taylor country vibes. Focuses on the 'D-Em-G-A' progression.", "genre": "Country" },
        { "title": "Flowers", "artist": "Miley Cyrus", "description": "Modern upbeat pop. The bassline-inspired strumming is very satisfying to play.", "genre": "Pop" },
        { "title": "Man! I Feel Like A Woman!", "artist": "Shania Twain", "description": "Classic upbeat Country Rock. High energy and great for performance.", "genre": "Country Rock" },
        { "title": "22", "artist": "Taylor Swift", "description": "Pure fun. Simple pop chords with a very infectious upbeat rhythm.", "genre": "Pop" },
        { "title": "ballad of a homeschooled girl", "artist": "Olivia Rodrigo", "description": "Grungy and upbeat. Simple riffs that sound harder than they are.", "genre": "Pop Rock" }
      ];
    
      songs = fallbackPool.sort(() => 0.5 - Math.random());
    }

    // 4. 抓取 YouTube 影片並存入 Firebase
    for (const s of songs) {
      const url = await getRealYouTubeVideo(s.title, s.artist);
      await feedCol.add({
        title: s.title,
        artist: s.artist,
        videoUrl: url,
        description: s.description,
        genre: s.genre || "Recommended",
        actionState: "ignored",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return { success: true };
  } catch (error) {
    console.error("Feed 生成過程嚴重錯誤:", error);
    throw new HttpsError("internal", error.message);
  }
}

exports.updateFeed = onCall({ cors: true, invoker: "public", timeoutSeconds: 120, memory: "512Mi", secrets: ["GEMINI_API_KEY"] }, async (request) => {
    const uid = request.auth ? request.auth.uid : "test_user_123";
    return updateFeedSkill(request.data, uid);
  });

exports.recordSession = onCall({ cors: true, invoker: 'public', secrets: ['GEMINI_API_KEY'] }, async (request) => {
  const uid = request.auth?.uid || "test_user_123";
  const data = request.data || {};
  const song = data.song || {};
  const userThoughts = data.userThoughts || {};

  const userNote = userThoughts.userNote || "No specific thoughts shared.";
  const durationMin = Math.round((userThoughts.durationSec || 0) / 60);
  const chatHistory = userThoughts.chatHistory || [];

  let chatHistoryText = chatHistory.length > 0 
    ? chatHistory.map(m => `${m.role === 'user' ? 'Student' : 'AI Coach'}: ${m.text}`).join("\n")
    : "(No chat interactions during this session)";
  
  let aiComment = `Great job practicing ${durationMin} minutes of "${song.title || 'this song'}"! Keep up this great momentum, and focus on smooth chord transitions in your next session.`;
  let nextFocus = ["Smooth out chord transitions.", "Practice with a metronome for consistency."];
  let userProfilePatch = {};
  let songProfilePatch = {};

  try {
    if (!process.env.GEMINI_API_KEY) {
      console.warn("GEMINI_API_KEY is not defined.");
      aiComment = "⚠️ API Key Error: GEMINI_API_KEY is not configured correctly in Firebase Secrets.";
    } else {
      const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
      const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

      const prompt = `You are an expert guitar practice coach (AI Coach).
      Student practiced "${song.title || 'Unknown'}" by "${song.artist || 'Unknown'}".
      Session duration: ${durationMin} minutes.
      Student's feedback/note: "${userNote}".

      Chat log during session:
      ${chatHistoryText}

      Analyze the chat log and student's note to find their specific pain points. 
      Provide a highly personalized coaching summary (aiComment) in 2-3 sentences.
      List exactly 2 concise next-focus tips (nextFocus).
      Also suggest conservative updates to the user profile (userProfilePatch) and song profile (songProfilePatch).

      IMPORTANT: You can reply in Traditional Chinese if the student used Chinese, or English if they used English. 
      Return ONLY a valid, parseable JSON object matching this structure:
      {
        "sessionInfo": {
          "aiComment": "your personalized feedback text",
          "nextFocus": ["tip1", "tip2"]
        },
        "userProfilePatch": { "weakTechniques": ["..."] },
        "songProfilePatch": { "problemAreas": ["..."], "recommendedFocus": ["..."] }
      }`;

      const result = await model.generateContent(prompt);
      let cleanText = (typeof result.response?.text === 'function') ? result.response.text() : "{}";
      cleanText = cleanText.replace(/```(?:json)?/gi, '').replace(/```/g, '').trim();
      
      const jsonMatch = cleanText.match(/\{[\s\S]*\}/);
      if (jsonMatch) cleanText = jsonMatch[0];
      
      const aiJson = JSON.parse(cleanText);

      if (aiJson.sessionInfo?.aiComment) aiComment = aiJson.sessionInfo.aiComment;
      if (aiJson.sessionInfo?.nextFocus) nextFocus = aiJson.sessionInfo.nextFocus;
      if (aiJson.userProfilePatch) userProfilePatch = aiJson.userProfilePatch;
      if (aiJson.songProfilePatch) songProfilePatch = aiJson.songProfilePatch;
    }
  } catch (error) {
    console.error("AI generation failed:", error);
    aiComment = `⚠️ AI Debug Error: ${error.message}`;
  }

  const sessionData = {
    title: song.title || 'Unknown',
    artist: song.artist || 'Unknown',
    practiceDate: userThoughts.practiceDate || new Date().toISOString().split('T')[0],
    durationSec: userThoughts.durationSec || 0,
    userNote: userThoughts.userNote || '',
    recordingUrls: userThoughts.recordingUrls || [],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    sessionInfo: { aiComment, nextFocus }
  };

  await admin.firestore().collection("users").doc(uid).collection("sessions").add(sessionData);

  return {
    status: "success",
    sessionInfo: { aiComment, nextFocus },
    userProfilePatch: userProfilePatch || {},
    songProfilePatch: songProfilePatch || {},
    song: {
      title: song.title || 'Unknown',
      artist: song.artist || 'Unknown'
    }
  };
});

exports.applyPatch = onCall({ cors: true, invoker: 'public' }, async (request) => {
  const uid = request.auth?.uid || 'test_user_123';
  const data = request.data || {};
  const userProfilePatch = data.userProfilePatch || {};
  const songProfilePatch = data.songProfilePatch || {};
  const song = data.song || {};
  const db = admin.firestore();
  const promises = [];

  if (Object.keys(userProfilePatch).length) {
    promises.push(db.collection('users').doc(uid).set({ profile: userProfilePatch }, { merge: true }));
  }

  if (Object.keys(songProfilePatch).length && song.title && song.artist) {
    const songId = makeSongId(song.title, song.artist);
    promises.push(db.collection('users').doc(uid).collection('songProfiles').doc(songId).set(songProfilePatch, { merge: true }));
  }

  try {
    await Promise.all(promises);
    return { success: true };
  } catch (error) {
    console.error('applyPatch failed:', error);
    throw new Error('Failed to apply patch');
  }
});
