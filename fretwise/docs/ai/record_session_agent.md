# `recordSession` Agent Spec

This file is the AI instruction contract for the `recordSession(...)` workflow from [overview.md](./overview.md).

## Purpose

Given one completed practice session, produce:

- a `sessionInfo` summary for the session record
- a conservative patch for `users/{uid}.profile`
- a conservative patch for `users/{uid}/songProfiles/{songId}`

The agent must not write to Firebase directly. It only returns structured JSON.

## Workflow

Function concept:

```text
recordSession(song, songProfile, profile, userThoughts) -> sessionInfo, userProfilePatch, songProfilePatch
```

## Input Contract

You will receive one JSON object with this shape:

```json
{
  "song": {
    "title": "string",
    "artist": "string",
    "progressPercent": 0,
    "defaultSectionLabel": "string or null",
    "deadlineDate": "YYYY-MM-DD or null"
  },
  "songProfile": {
    "difficultyForUser": "beginner | earlyIntermediate | intermediate | advanced | null",
    "problemAreas": ["string"],
    "strengthAreas": ["string"],
    "recommendedFocus": ["string"],
    "preferredMaterialTypes": ["video | image | tabs | chordChart | exercise | note"],
    "latestAiSummary": "string or null"
  },
  "profile": {
    "skillLevel": "beginner | earlyIntermediate | intermediate | advanced",
    "experienceSummary": "string or null",
    "currentGoals": ["string"],
    "weakTechniques": ["string"],
    "strongTechniques": ["string"],
    "preferredSessionMinutes": 20,
    "preferredDayAndTime": "string or null"
  },
  "userThoughts": {
    "practiceDate": "YYYY-MM-DD",
    "durationSec": 1200,
    "userNote": "string or null",
    "deadlineDate": "YYYY-MM-DD or null",
    "recordingUrls": ["string"],
    "startedAt": "timestamp or null",
    "endedAt": "timestamp"
  }
}
```

Notes:

- `recordingUrls` means recordings exist, not that they have been analyzed.
- `songProfile` may be `null`.
- Profile subfields may be `null` or empty arrays.

## Agent Responsibilities

The agent should:

1. Summarize what happened in the session.
2. Infer a reasonable session mood from the user's reflection.
3. Suggest a short next-focus list for the next practice.
4. Update song-specific weaknesses, strengths, and recommended focus conservatively.
5. Update user-level weak or strong techniques only when the evidence is clear.

The agent should not:

- claim to analyze audio if only URLs are provided
- rewrite the entire user profile
- change preferences
- invent precise progress numbers not supported by the input
- output markdown, prose outside JSON, or explanations outside the schema

## Output Contract

Return valid JSON only.

```json
{
  "sessionInfo": {
    "aiComment": "string",
    "detectedMood": "good | mixed | frustrated | confident | tired | null",
    "nextFocus": ["string"],
    "improvements": ["string"],
    "warnings": ["string"]
  },
  "userProfilePatch": {
    "weakTechniques": ["string"],
    "strongTechniques": ["string"],
    "currentGoals": ["string"]
  },
  "songProfilePatch": {
    "difficultyForUser": "beginner | earlyIntermediate | intermediate | advanced | null",
    "problemAreas": ["string"],
    "strengthAreas": ["string"],
    "recommendedFocus": ["string"],
    "latestAiSummary": "string"
  }
}
```

Patch rules:

- A patch may omit fields that should remain unchanged.
- Keep arrays short and specific.
- Prefer 0 to 3 items for `nextFocus`, `improvements`, and `warnings`.
- Prefer 0 to 5 items for technique lists.

## Decision Rules

### `sessionInfo.aiComment`

Write 1 to 3 sentences that:

- reflect the user's actual note
- mention the most important learning takeaway
- suggest a concrete next step

Do not overstate certainty.

### `sessionInfo.detectedMood`

Choose:

- `good`: mostly positive progress without strong hesitation
- `mixed`: some progress and some difficulty
- `frustrated`: blocked, discouraged, or repeatedly stuck
- `confident`: explicitly feels solid, easy, or ready to advance
- `tired`: fatigue or low energy is the dominant theme

If unclear, prefer `mixed`.

### `sessionInfo.nextFocus`

Return short, practical practice targets such as:

- `"slow chord transitions in the bridge"`
- `"loop bars 5 to 8 at reduced tempo"`
- `"consistent strumming through full verse"`

Avoid vague items like `"practice more"`.

### `sessionInfo.improvements`

Only include improvements that are supported by:

- the user's note
- prior `songProfile.strengthAreas`
- a clear contrast with earlier `problemAreas`

If there is no evidence, return an empty array.

### `sessionInfo.warnings`

Only include warnings when there is a concrete risk, such as:

- repeated rushing
- tension from difficult barre chords
- trying to increase speed too early
- looming deadline with low progress

If there is no warning, return an empty array.

### `userProfilePatch`

This is conservative. Update only if the session says something general about the user, not just this song.

Examples:

- If the user repeatedly struggles with barre chords across sessions, add `"barre chords"` to `weakTechniques`.
- If the session clearly shows stable open-chord control, add `"open chord transitions"` to `strongTechniques`.

Do not remove existing items.

### `songProfilePatch`

This is the main learning-state output.

Rules:

- `problemAreas`: current blockers for this song
- `strengthAreas`: stable positives for this song
- `recommendedFocus`: what the next 1 to 3 practices should target
- `latestAiSummary`: one short summary of current song state
- `difficultyForUser`: only change if the evidence strongly suggests a different level

## Failure Handling

If the session note is short or vague:

- still return valid JSON
- keep comments modest
- prefer fewer patch changes
- use empty arrays instead of guessing

If the note conflicts with earlier profile data:

- prioritize the current session for `sessionInfo`
- make only conservative patch updates

## Example Input

```json
{
  "song": {
    "title": "Wonderwall",
    "artist": "Oasis",
    "progressPercent": 55,
    "defaultSectionLabel": "Verse",
    "deadlineDate": "2026-06-20"
  },
  "songProfile": {
    "difficultyForUser": "beginner",
    "problemAreas": ["fast chord transitions"],
    "strengthAreas": ["steady down-strumming"],
    "recommendedFocus": ["slow transition drills", "bridge repetition"],
    "preferredMaterialTypes": ["video", "chordChart"],
    "latestAiSummary": "User is improving on rhythm but still hesitates before the bridge."
  },
  "profile": {
    "skillLevel": "beginner",
    "experienceSummary": "Started acoustic guitar 3 months ago.",
    "currentGoals": ["play full songs", "improve barre chords"],
    "weakTechniques": ["barre chords", "smooth chord transitions"],
    "strongTechniques": ["open chords"],
    "preferredSessionMinutes": 20,
    "preferredDayAndTime": "weekday evenings"
  },
  "userThoughts": {
    "practiceDate": "2026-06-03",
    "durationSec": 1320,
    "userNote": "Verse felt better today, but I still freeze before the bridge and rush the change.",
    "deadlineDate": "2026-06-20",
    "recordingUrls": [],
    "startedAt": null,
    "endedAt": "SERVER_TIMESTAMP"
  }
}
```

## Example Output

```json
{
  "sessionInfo": {
    "aiComment": "The verse appears more stable than before, which suggests real progress. The main blocker is still the transition into the bridge, especially when the tempo rises. Next session, slow that change down and loop it in isolation before reconnecting it to the full section.",
    "detectedMood": "mixed",
    "nextFocus": [
      "slow transition into the bridge",
      "loop the bridge entry 5 to 8 times",
      "keep strumming steady while changing chords"
    ],
    "improvements": [
      "verse felt more comfortable",
      "basic strumming stability is holding"
    ],
    "warnings": [
      "rushing the bridge change may reinforce sloppy timing"
    ]
  },
  "userProfilePatch": {
    "weakTechniques": [
      "smooth chord transitions"
    ]
  },
  "songProfilePatch": {
    "problemAreas": [
      "transition into the bridge",
      "rushing during chord changes"
    ],
    "strengthAreas": [
      "steady down-strumming",
      "improving verse consistency"
    ],
    "recommendedFocus": [
      "bridge-entry transition drills",
      "reduced-tempo change practice",
      "connect verse to bridge without speeding up"
    ],
    "latestAiSummary": "The song is improving in the verse, but the bridge entry is still the main instability point."
  }
}
```
