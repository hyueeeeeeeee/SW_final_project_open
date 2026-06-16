# `updatePlan` Agent Spec

This file is the AI instruction contract for the `updatePlan(...)` workflow from [overview.md](./overview.md).

## Purpose

Given the user's external calendar events (next 7 days), learning preferences, song library, and current practice plan, produce a new or updated practice schedule that:

- avoids conflicts with existing calendar events
- reduces practice on busy days and increases practice on free days
- respects the user's preferred session length and practice times
- prioritizes songs with upcoming deadlines

The agent must not write to Firebase directly. It only returns structured JSON.

## Workflow

Function concept:

```text
updatePlan(externalCalendar, preference, profile, songLibrary, existingPlan) -> practicePlan, practiceDays[], practiceTasks[]
```

## Input Contract

You will receive one JSON object with this shape:

```json
{
  "externalCalendar": [
    {
      "title": "string",
      "start": "ISO 8601 datetime string",
      "end": "ISO 8601 datetime string"
    }
  ],
  "profile": {
    "skillLevel": "beginner | earlyIntermediate | intermediate | advanced",
    "experienceSummary": "string or null",
    "currentGoals": ["string"],
    "weakTechniques": ["string"],
    "strongTechniques": ["string"],
    "preferredSessionMinutes": 20,
    "preferredDayAndTime": "string or null"
  },
  "preferences": {
    "favoriteGenres": ["string"],
    "favoriteArtists": ["string"],
    "preferredMaterialTypes": ["string"]
  },
  "songLibrary": [
    {
      "songId": "string",
      "title": "string",
      "artist": "string",
      "bpm": 87,
      "progressPercent": 55,
      "deadlineDate": "YYYY-MM-DD or null",
      "isFavorite": true,
      "isArchived": false
    }
  ],
  "existingPlan": {
    "planId": "string or null",
    "title": "string or null",
    "activeFromDate": "YYYY-MM-DD or null",
    "activeToDate": "YYYY-MM-DD or null",
    "linkedSongIds": ["string"]
  },
  "today": "YYYY-MM-DD"
}
```

Notes:

- `externalCalendar` may be empty if the user has no events or denied calendar access.
- `songLibrary` only includes non-archived songs (`isArchived == false`).
- `existingPlan` may be `null` if no plan exists yet.
- `profile` subfields may be `null` or empty arrays.
- `today` is the current date in the user's timezone.

## Agent Responsibilities

The agent should:

1. Analyze each day's busyness based on external calendar events.
2. Assign a busyness level to each of the next 7 days (free, light, moderate, busy, packed).
3. Determine how many practice minutes to allocate per day based on busyness.
4. Select which songs to practice each day, prioritizing songs with deadlines.
5. Create specific, actionable practice tasks for each day.
6. Generate a short plan summary.

The agent should not:

- schedule practice during existing calendar events
- exceed the user's preferred session length on busy days
- assign practice to a day that is fully packed with events
- change user preferences or profile
- output markdown, prose outside JSON, or explanations outside the schema
- invent song data not present in `songLibrary`

## Output Contract

Return valid JSON only.

```json
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
      "plannedMinutes": 0,
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
      "minutes": 15,
      "orderIndex": 0
    }
  ]
}
```

## Decision Rules

### Busyness Level Classification

Classify each day based on total hours of external calendar events:

| Total Event Hours | Busyness Level | Max Practice Minutes |
|---|---|---|
| 0 hours | free | preferredSessionMinutes × 1.5 (round to nearest 5) |
| 0.1 – 2 hours | light | preferredSessionMinutes |
| 2.1 – 5 hours | moderate | preferredSessionMinutes × 0.7 (round to nearest 5) |
| 5.1 – 8 hours | busy | preferredSessionMinutes × 0.4 (round to nearest 5), minimum 10 |
| 8+ hours | packed | 0 (rest day) |

If `preferredSessionMinutes` is not set, default to 20 minutes.

### Practice Time Allocation

- On `free` days: allow extended practice; can split into multiple tasks.
- On `light` days: standard session; 1–2 tasks.
- On `moderate` days: shortened session; 1 task, focused drill.
- On `busy` days: quick warm-up or single focused drill only.
- On `packed` days: mark as `rest`; no practice tasks.

### Song Selection Priority

When choosing which songs to assign to practice days:

1. **Deadline urgency**: songs with `deadlineDate` within 14 days get highest priority.
2. **Low progress**: songs with lower `progressPercent` get more practice time.
3. **Favorites**: `isFavorite == true` songs get slight priority boost.
4. **Variety**: avoid assigning the same song every day; rotate through 2–3 songs per week.
5. **Skill match**: choose tasks appropriate for the user's `skillLevel`.

### Task Design

Each practice task should:

- have a clear, specific title (e.g., "Verse chord transitions" not "Practice guitar")
- include practical instructions the user can follow
- fit within the allocated minutes for that day
- build on the user's `weakTechniques` and the song's needs
- progress logically across the week (don't repeat identical tasks)

### Plan Title and Summary

- Title: short and motivational (e.g., "Midweek Guitar Sprint", "Light Week Practice")
- Summary: 1–2 sentences describing the week's focus and strategy
- `generatedReason`: briefly explain why this plan was generated (e.g., "Calendar sync detected 3 busy days this week")

## Failure Handling

If the song library is empty:

- return a plan with general technique exercises instead of song-specific tasks
- use generic task titles like "Open chord warm-up" or "Finger stretching exercises"

If external calendar is empty:

- treat all days as `free`
- allocate standard or slightly extended practice time

If profile data is sparse:

- default to `beginner` level
- default to 20-minute sessions
- keep tasks simple and fundamental

Always return valid JSON, even in edge cases.

## Example Input

```json
{
  "externalCalendar": [
    {
      "title": "Team Meeting",
      "start": "2026-06-12T09:00:00+08:00",
      "end": "2026-06-12T10:30:00+08:00"
    },
    {
      "title": "Dentist Appointment",
      "start": "2026-06-12T14:00:00+08:00",
      "end": "2026-06-12T15:00:00+08:00"
    },
    {
      "title": "Final Exam Study Group",
      "start": "2026-06-13T08:00:00+08:00",
      "end": "2026-06-13T17:00:00+08:00"
    },
    {
      "title": "Birthday Party",
      "start": "2026-06-14T18:00:00+08:00",
      "end": "2026-06-14T22:00:00+08:00"
    }
  ],
  "profile": {
    "skillLevel": "beginner",
    "experienceSummary": "Started acoustic guitar 3 months ago.",
    "currentGoals": ["play full songs", "improve barre chords"],
    "weakTechniques": ["barre chords", "smooth chord transitions"],
    "strongTechniques": ["open chords"],
    "preferredSessionMinutes": 20,
    "preferredDayAndTime": "weekday evenings"
  },
  "preferences": {
    "favoriteGenres": ["folk", "classic rock"],
    "favoriteArtists": ["The Beatles"],
    "preferredMaterialTypes": ["video", "chordChart"]
  },
  "songLibrary": [
    {
      "songId": "song_wonderwall",
      "title": "Wonderwall",
      "artist": "Oasis",
      "bpm": 87,
      "progressPercent": 55,
      "deadlineDate": "2026-06-20",
      "isFavorite": true,
      "isArchived": false
    },
    {
      "songId": "song_blackbird",
      "title": "Blackbird",
      "artist": "The Beatles",
      "bpm": 96,
      "progressPercent": 20,
      "deadlineDate": null,
      "isFavorite": false,
      "isArchived": false
    }
  ],
  "existingPlan": null,
  "today": "2026-06-11"
}
```

## Example Output

```json
{
  "practicePlan": {
    "title": "Balanced Midweek Plan",
    "summary": "This week mixes Wonderwall deadline prep with Blackbird exploration, adapting around your busy Thursday study session and Saturday party.",
    "activeFromDate": "2026-06-11",
    "activeToDate": "2026-06-17",
    "linkedSongIds": ["song_wonderwall", "song_blackbird"],
    "generatedReason": "Calendar sync detected 1 busy day and 1 moderate day this week. Practice adjusted accordingly."
  },
  "practiceDays": [
    {
      "date": "2026-06-11",
      "status": "planned",
      "plannedMinutes": 30,
      "linkedSongIds": ["song_wonderwall"],
      "busynessLevel": "free",
      "busynessReason": "No external events today"
    },
    {
      "date": "2026-06-12",
      "status": "planned",
      "plannedMinutes": 15,
      "linkedSongIds": ["song_wonderwall"],
      "busynessLevel": "moderate",
      "busynessReason": "Team meeting + dentist (2.5 hours of events)"
    },
    {
      "date": "2026-06-13",
      "status": "rest",
      "plannedMinutes": 0,
      "linkedSongIds": [],
      "busynessLevel": "packed",
      "busynessReason": "Full-day study group (9 hours)"
    },
    {
      "date": "2026-06-14",
      "status": "planned",
      "plannedMinutes": 15,
      "linkedSongIds": ["song_blackbird"],
      "busynessLevel": "moderate",
      "busynessReason": "Evening birthday party (4 hours)"
    },
    {
      "date": "2026-06-15",
      "status": "planned",
      "plannedMinutes": 30,
      "linkedSongIds": ["song_wonderwall", "song_blackbird"],
      "busynessLevel": "free",
      "busynessReason": "No external events"
    },
    {
      "date": "2026-06-16",
      "status": "planned",
      "plannedMinutes": 30,
      "linkedSongIds": ["song_wonderwall"],
      "busynessLevel": "free",
      "busynessReason": "No external events"
    },
    {
      "date": "2026-06-17",
      "status": "planned",
      "plannedMinutes": 20,
      "linkedSongIds": ["song_blackbird"],
      "busynessLevel": "free",
      "busynessReason": "No external events"
    }
  ],
  "practiceTasks": [
    {
      "dayId": "2026-06-11",
      "songId": "song_wonderwall",
      "title": "Verse chord transitions drill",
      "instructions": "Play the verse progression (Em7-G-Dsus4-A7sus4) at half speed. Focus on smooth finger movement between chords. Repeat 10 times without stopping.",
      "minutes": 15,
      "orderIndex": 0
    },
    {
      "dayId": "2026-06-11",
      "songId": "song_wonderwall",
      "title": "Bridge entry practice",
      "instructions": "Isolate the transition from verse to bridge. Play the last 2 bars of the verse into the first 2 bars of the bridge. Keep tempo steady with a metronome at 60 BPM.",
      "minutes": 15,
      "orderIndex": 1
    },
    {
      "dayId": "2026-06-12",
      "songId": "song_wonderwall",
      "title": "Quick chord change warm-up",
      "instructions": "Shortened session: practice switching between Em7 and G, then G and Dsus4. One minute per pair. Focus on accuracy over speed.",
      "minutes": 15,
      "orderIndex": 0
    },
    {
      "dayId": "2026-06-14",
      "songId": "song_blackbird",
      "title": "Intro fingerpicking pattern",
      "instructions": "Learn the basic fingerpicking pattern for bars 1-4. Use thumb for bass notes, index and middle for melody. Play very slowly.",
      "minutes": 15,
      "orderIndex": 0
    },
    {
      "dayId": "2026-06-15",
      "songId": "song_wonderwall",
      "title": "Full verse run-through",
      "instructions": "Play the complete verse section at 70 BPM. Try to keep strumming consistent throughout. Note any spots where you hesitate.",
      "minutes": 15,
      "orderIndex": 0
    },
    {
      "dayId": "2026-06-15",
      "songId": "song_blackbird",
      "title": "Bars 1-8 fingerpicking",
      "instructions": "Continue from yesterday's intro. Extend to bar 8. Focus on clean bass notes and even finger pressure.",
      "minutes": 15,
      "orderIndex": 1
    },
    {
      "dayId": "2026-06-16",
      "songId": "song_wonderwall",
      "title": "Verse to bridge connection",
      "instructions": "Play verse and bridge back-to-back without stopping. Start at 65 BPM. If the transition is clean, increase to 70 BPM.",
      "minutes": 20,
      "orderIndex": 0
    },
    {
      "dayId": "2026-06-16",
      "songId": "song_wonderwall",
      "title": "Strumming pattern refinement",
      "instructions": "Practice the down-up strumming pattern for the chorus. Mute strings between changes to stay in rhythm.",
      "minutes": 10,
      "orderIndex": 1
    },
    {
      "dayId": "2026-06-17",
      "songId": "song_blackbird",
      "title": "Bars 1-12 review",
      "instructions": "Review and connect bars 1-12. Play at a comfortable tempo. Focus on letting notes ring clearly.",
      "minutes": 20,
      "orderIndex": 0
    }
  ]
}
```
