# Plank Challenge — Content Guide

**Version:** 2.0  
**Last updated:** March 2026  
**Owner:** Product / Content Design

> **How to use this document**  
> This is the single source of truth for all content decisions in Plank Challenge. Before writing any new copy — a screen, a feature, a notification, a badge, an alert — start here. The first three sections tell you *how* to write. Everything after is reference copy and templates you can build from.

---

## Table of Contents

1. [Brand Foundation](#1-brand-foundation)
2. [Voice & Tone](#2-voice--tone)
3. [Writing Mechanics](#3-writing-mechanics)
4. [Checklist: New Feature or Screen](#4-checklist-new-feature-or-screen)
5. [Patterns & Templates](#5-patterns--templates)
6. [Screen Copy Reference](#6-screen-copy-reference)
7. [Badge Content Library](#7-badge-content-library)
8. [Push Notification Library](#8-push-notification-library)
9. [Onboarding & Retention Sequences](#9-onboarding--retention-sequences)
10. [App Store Listing](#10-app-store-listing)

---

# 1. Brand Foundation

## 1.1 What we are

Plank Challenge exists to make one thing stupidly simple: hold a plank every day. Not a workout plan. Not a calorie counter. Just one exercise, done consistently, tracked beautifully.

Every content decision should serve that mission. If a word, label, or message doesn't help the user build a daily plank habit, question whether it needs to be there.

## 1.2 Who we're writing for

**Primary persona: The Habit Starter**

- Any fitness level, typically 22–45
- Wants to build a consistent fitness habit but finds full workout routines overwhelming
- Motivated by visible progress, streak numbers, and light social accountability
- Responds well to celebration and gentle nudges
- Shuts down with guilt and pressure — never make them feel bad for missing a day

**What they want to feel:** Accomplished after 30 seconds. Like the app is rooting for them. Like missing one day isn't the end of the world — but maintaining their streak is genuinely satisfying.

**Design implication:** When in doubt, write for someone who is new to fitness habits, not someone who already has one.

## 1.3 Key terminology (use these exact terms everywhere)

Consistency in naming matters. These are the terms we use in the app, documentation, notifications, and App Store copy. Do not introduce synonyms.

| Concept | Correct term | Do not use |
|---|---|---|
| The daily protection mechanic | **Streak Shield** | Freeze token, streak freeze, token |
| The daily exercise screen | **Plank timer** | Timer screen, workout screen |
| Adding a plank without the timer | **Add Plank** | Manual entry, log plank, record plank |
| The record of past planks | **Plank History** | Plank log, history, sessions |
| A completed exercise session | **Plank** | Session, workout, rep |
| The consecutive-day count | **Streak** | Combo, chain, run |
| Milestone awards | **Badges** | Achievements, rewards, trophies |
| Group competitive ranking | **Leaderboard** | Rankings, scoreboard |

---

# 2. Voice & Tone

## 2.1 The four voice traits

The Plank Challenge voice is defined by four traits. **Every piece of copy should reflect at least one of them.** If it doesn't, rewrite it.

---

### Trait 1: Encouraging without being a pushover

We celebrate every win, including the small ones. But we don't manufacture fake enthusiasm or pile on hollow compliments. When someone misses a day, we acknowledge it honestly and move forward. We don't guilt-trip. We don't catastrophise.

| Do | Don't |
|---|---|
| "You're back. Let's go." | "You REALLY need to do better!" |
| "Day 1 again. That's how legends start." | "You broke your streak. Shame." |
| "Well done." | "Amazing incredible fantastic plank!!!" |
| "Your shield saved your streak." | "Lucky you had a shield or you'd have lost everything!" |

---

### Trait 2: Playful but not silly

We have personality. Wordplay, light humour, and an occasional cheeky tone are all allowed. But cleverness never gets in the way of clarity. The plank is a serious exercise. The tone just makes it less boring.

| Do | Don't |
|---|---|
| "One plank a day keeps the slump away." | Puns every other sentence |
| "Hold on tight. Literally." | Cartoon-level exclamations ("WOWZA!!") |
| "Still here? So is your streak." | Mocking the user, even affectionately |
| "Get into position" (countdown) | Anything that feels like a kids' app |

---

### Trait 3: Brief and confident

Every word earns its place. We trust the user to understand without over-explaining. No waffle, no redundancy. Short sentences. Strong verbs. Lead with the most important thing.

| Do | Don't |
|---|---|
| "Remove Photo" | "Tap here to remove your current profile photo" |
| "Hold a plank. Every day." | "Please try to hold a plank exercise each and every day if you can" |
| "No planks yet." | "It looks like you haven't completed any planks yet!" |
| "Try again" | "Please try again later" |

---

### Trait 4: Honest and human

We don't hide bad news behind corporate language. Errors are clear. Consequences are stated plainly. We treat users like adults who can handle the truth. When something is permanent, we say so without melodrama.

| Do | Don't |
|---|---|
| "This can't be undone." | "Please note that this action may be irreversible." |
| "Something went wrong. Try again." | "An unexpected error has occurred in the application." |
| "We'll remind you once a day, that's it." | "We may occasionally send you helpful tips and reminders." |
| "Couldn't sign you in." | "Authentication failed." |

---

## 2.2 Tone shifts by context

The voice stays constant. The tone adjusts to match the moment.

| Context | Tone direction | Example |
|---|---|---|
| **Celebration** — plank done, badge earned, milestone | Warm, energetic, specific to what was achieved | "37 days. That's commitment." |
| **Motivation** — pre-plank, streak reminders, empty states | Direct, confident, zero pressure | "Time to plank." |
| **Instruction** — onboarding, plank types, how-to copy | Clear, concise, no jargon | "Tap the big button. Hold as long as you can. Done." |
| **Error** — network fail, auth issue, save fail | Matter-of-fact, solution-focused | "Couldn't save that. Try again." |
| **Empty state** — no data yet | Inviting, not deflating | "No planks yet — your first one is the hardest" |
| **Destructive action** — delete account, discard planks | Plain, serious, no fluff or softening | "Everything goes — your planks, streak, badges, and groups. This can't be undone." |
| **Social** — follow, group join, leaderboard | Light, competitive, a bit fun | "See how you stack up." |
| **Settings** | Neutral, functional, brief — no sales energy | "Daily reminder" |
| **Onboarding** | Warm, simple, explains the mental model not the UI | "Miss a day? No panic. Streak shields cover missed days." |

---

## 2.3 What we never do

These are absolute rules, not guidelines.

- **No guilt.** Never make the user feel bad for missing a day, having a short streak, or being inactive. Frame recovery positively, always.
- **No fake urgency.** "ACT NOW" energy is off-brand. If something is time-sensitive (streak at risk tonight), state the fact plainly — don't manufacture panic.
- **No passive voice in errors.** "Your plank couldn't be saved" beats "An error occurred while saving your plank."
- **No "please" in UI copy.** It's a filler word that reads as anxious. Say the thing directly.
- **No exclamation marks in error states.** Ever.
- **No developer language in the UI.** If an engineer would use the term in a ticket, it probably doesn't belong in a label. (See: "Manual Entry" → "Add Plank", "Freeze Token" → "Streak Shield".)

---

# 3. Writing Mechanics

## 3.1 Capitalisation

| Element | Rule | Example |
|---|---|---|
| Screen titles | Title Case | `Plank History`, `Edit Profile` |
| Primary action buttons | Title Case | `Save Changes`, `Create Group` |
| Secondary / destructive buttons | Sentence case | `Maybe later`, `Delete account` |
| Body copy & descriptions | Sentence case | `Your streak is waiting.` |
| Section headers | ALL CAPS only where design already uses it | `YOUR STATS`, `MY GROUPS` |
| Error alert titles | Sentence case | `Couldn't sign you in` |
| Empty state headings | Sentence case | `No planks yet` |
| Badge names | Title Case | `First Flame`, `Month of Planks` |
| Notification titles | Sentence case | `Time to plank 🔥` |

> **Rule of thumb:** If it's a label the user acts on (button, toggle, link), it's Title Case for primary actions, sentence case for everything else. If it's copy the user reads (descriptions, alerts, empty states), it's always sentence case.

## 3.2 Punctuation

- **Full stops:** Only in multi-sentence body copy and legal text. Not on single-sentence labels, headings, or buttons.
- **Exclamation marks:** Only in genuine celebration moments (badge earned, streak milestone). Maximum one per screen. Never in errors, empty states, or settings.
- **Em dash (—):** Use for pauses and asides. Not en dash (–) or double hyphen (--).
- **Oxford comma:** Always in lists of three or more items.
- **Apostrophes in contractions:** Use them. "Can't" not "cannot". "Won't" not "will not". "You'll" not "you will". Contractions sound human. Full forms sound corporate.
- **Question marks in alert titles:** Only when the title is genuinely a question. "Delete this group?" ✓ "Are you sure you want to delete this group?" ✗ (too long for a title)

## 3.3 Numbers

- Spell out one through nine in body copy. Use numerals for 10 and above.
- Always use numerals (regardless of size) for: streak counts, plank durations, badge progress, leaderboard ranks, shield counts.
- Time in UI copy: natural language (`3 minutes 20 seconds`) except in the active timer display, which uses the formatted countdown.

## 3.4 Emoji

- Maximum one emoji per notification. Never two.
- Avoid emoji in: error states, legal copy, settings, destructive confirmations.
- Approved emoji and their contexts:

| Emoji | Context |
|---|---|
| 🔥 | Streak energy, daily reminders, streak milestone notifications |
| 🏅 | Badge earned (streak badges) |
| 🏆 | Leaderboard wins, 90-day badge |
| ✅ | First plank completion |
| 🛡️ | Streak Shield — earned, activated, used |
| 👑 | The Full Year badge (365 days) |
| ⭐ | Half Year Hero badge (180 days) |
| 💪 | Two Months, No Excuses badge (60 days) |

- Do not use emoji as a substitute for clear copy. If removing the emoji makes the message unclear, the copy isn't strong enough.

## 3.5 Placeholders and loading states

- Loading states must be specific: `Loading your progress...` not `Loading...` — the user should know what to expect.
- Form field placeholders should use genuine examples, not meta-instructions:
  - `e.g. London, UK` ✓ not `Enter your location here` ✗
  - `you@example.com` ✓ not `Enter your email address` ✗
  - `What should we call you?` ✓ not `Enter your display name` ✗

## 3.6 Person and address

- Address the user as **"you"** — never "the user", "one", or their username in system messages.
- Use **"we"** only for trust and legal moments (onboarding consent, privacy notices). Everywhere else, prefer second person ("your streak") over first person plural ("we saved your streak").
- Never write in third person about the user in UI copy.

---

# 4. Checklist: New Feature or Screen

Use this before writing any new copy. Work through it in order.

## Step 1 — Understand the user goal
- What is the user trying to accomplish on this screen or with this feature?
- What do they need to know to succeed?
- What could go wrong, and how will we tell them?

## Step 2 — Map the copy states
Every screen or feature needs copy for all possible states. Do not ship with missing states.

- [ ] **Default / idle state** — what does the screen say before the user does anything?
- [ ] **Loading state** — specific to what's loading, not just "Loading..."
- [ ] **Empty state** — no data yet; inviting, not deflating
- [ ] **Error state** — what went wrong and what the user can do about it
- [ ] **Success state** — confirmation that the action worked (if needed)
- [ ] **Destructive confirmation** — if the action is permanent, it needs an honest alert

## Step 3 — Check the terminology
- Does the copy use the correct terms from the [Key Terminology](#13-key-terminology-use-these-exact-terms-everywhere) table?
- Does it introduce any new terms? If so, add them to the terminology table before shipping.

## Step 4 — Check the voice
- Read the copy aloud. Does it sound like a person wrote it?
- Apply the four traits: is it encouraging without being hollow? Playful without being silly? Brief? Honest?
- Check the [What we never do](#23-what-we-never-do) list. Does any copy break those rules?

## Step 5 — Check the mechanics
- [ ] Capitalisation follows the rules in §3.1
- [ ] No full stops on single-sentence labels or headings
- [ ] No "please" anywhere
- [ ] No developer language
- [ ] Emoji used correctly (or not at all)
- [ ] Loading state is specific
- [ ] Placeholders are genuine examples

## Step 6 — Check for internal language leaks
Ask: would an engineer use this term in a GitHub issue? If yes, find the user-facing equivalent.

| Internal term (do not use) | User-facing term |
|---|---|
| Manual entry | Add Plank |
| Freeze token / streak freeze | Streak Shield |
| Authentication | Sign in |
| Session | Plank |
| Confirmation dialog | (just write the alert — don't name it) |
| Pagination | (invisible to the user — handle it silently) |

---

# 5. Patterns & Templates

## 5.1 Alert dialogs

All alerts follow the same pattern:

```
Title:   [What happened or what you're asking] — sentence case, 5 words max
Body:    [The consequence or context the user needs] — one sentence, honest
Buttons: [Destructive action] / [Cancel or keep action]
```

**Destructive confirmation pattern:**
- Title: Question form — "Delete this group?"
- Body: State the consequence — "All 12 members will be removed. This can't be undone."
- Confirm: What the action actually does — "Delete Group"
- Cancel: What the user is keeping — "Keep group" (not just "Cancel")

**Error alert pattern:**
- Title: What couldn't be done — "Couldn't sign you in"
- Body: What to do next — "Check your email and password and try again."
- Button: "OK" (or "Retry" if retrying makes sense)

**Coming soon pattern:**
- Title: "Coming soon"
- Body: "[Feature] isn't available yet. We'll add it in a future update."
- Button: "Got it"

---

## 5.2 Empty states

Empty states should feel inviting, not like a failure message.

**Structure:**
```
Heading:  [What's missing] — factual, no drama
Subtext:  [Why it's a good thing / what to do about it] — one sentence, warm or actionable
CTA:      [Primary action] — optional, only if there's a direct action to take
```

**Examples:**
- `No planks yet — your first one is the hardest` (History)
- `Nothing yet today — go hold a plank` (Settings, today's planks)
- `You're all caught up / Nothing new right now` (Notifications)
- `No groups yet / Groups are where things get competitive. Create one or join an existing group.` (Groups)

**Rule:** Never end an empty state with an exclamation mark. Never blame the user for the state being empty.

---

## 5.3 Loading states

Always name what's loading.

| Generic (don't use) | Specific (use) |
|---|---|
| `Loading...` | `Loading your progress...` |
| `Loading...` | `Loading your history...` |
| `Loading...` | `Loading badges...` |
| `Loading...` | `Loading groups...` |
| `Loading...` | `Loading leaderboard...` |
| `Signing in...` | `Signing you in...` |
| `Deleting...` | `Deleting your account...` |

---

## 5.4 Error states (global ErrorView)

| Error type | Title | Body |
|---|---|---|
| No internet | `No connection` | `Check your internet connection and try again.` |
| Auth expired | `Session expired` | `Sign in again to continue.` |
| HTTP error (server) | `Something went wrong` | `Our servers hit a snag (error {N}). Try again in a moment.` |
| Unknown / generic | `Something went wrong` | `An unexpected error occurred. Try again.` |

---

## 5.5 Streak-related copy patterns

**Streak messages on the timer screen:**
- Active streak: `Protect your {N}-day streak`
- No streak yet: `Start your streak today`
- Day after losing a streak: `Your {N}-day streak ended yesterday. Today, you start fresh — and faster.`

**Streak Shield copy pattern:**
- Counter: `{N} of {max} shields left`
- Description: `A shield automatically activates when you miss a day — so your streak survives.`

**Celebration milestones (in-app overlay):**
- 7 days: `7 days straight` / `You've earned the First Flame badge and built yourself a real streak. Don't stop now.`
- 14 days: `Two weeks, no breaks` / `You're in the top 10% of Plank Challenge users. This is officially a habit.`
- 30 days: `30 days. A full month.` / `You've done something most people can't: shown up every day for a month.`

---

## 5.6 Privacy toggle footers

When a user configures group privacy in Create Group or Group Settings, the footer copy must match the selected state exactly:

| Private | Requires approval | Footer |
|---|---|---|
| No | No | `Anyone can find and join this group.` |
| No | Yes | `Anyone can find it, but you'll approve each request.` |
| Yes | No | `Only people you invite can find or join this group.` |
| Yes | Yes | `Invite-only. You'll still approve each person.` |

---

## 5.7 Writing new badge content

When adding a new badge, write four things:

1. **Name** — 2–4 words, Title Case, memorable. Should evoke the achievement, not describe it literally.
2. **Earned description** — Past tense. Warm. Specific to the number or action. 1–2 sentences max.
3. **Locked description** — Present tense. Brief motivational teaser. States the requirement clearly.
4. **Progress copy** — Shown during progress toward the badge. Format: `{N} of {total} — [short encouragement]`

**Template:**
```
Name:     [Title Case, 2-4 words]
Earned:   [What they did, past tense, warm, 1-2 sentences]
Locked:   [What they need to do, present tense, brief]
Progress: [{N} of {total} [units] — [short encouragement]]
```

**Quality check:** Read the earned description aloud. Does it feel like a person saying something meaningful, or like a system confirming a data point? It should feel like the former.

---

## 5.8 Writing new push notifications

All push notifications follow this structure:

- **Title:** 30 characters max. Direct. No fluff.
- **Body:** 90 characters ideal, 178 max. One thought. Specific to the user's situation where possible.
- **Emoji:** Maximum one, in title or body — not both. Use sparingly.
- **Tone:** No guilt. No fake urgency. Nudge, don't nag.

**Template for a new notification type:**
```
Trigger:  [When does this fire?]
Title:    [30 char max — what's happening]
Body:     [90 char ideal — what the user should know or do]
Emoji:    [Which one, if any]
```

**Before shipping a new notification, ask:**
- Would I be annoyed if I received this?
- Is there any guilt or manufactured urgency?
- Does the timing make sense (is it actually relevant right now)?
- Is it truly additive, or is it just noise?

---

# 6. Screen Copy Reference

> This section records the live copy for every screen. When copy changes in the app, update the corresponding entry here. This is the canonical record — not the code.

---

## 6.1 Authentication Screen

**Tagline:** `One exercise. / Every day. / That's it.`

**Sign-in buttons:** `Sign in with Apple` / `Continue with Google`

**Email sign-in link:** `Sign in with email`

**Legal footer:** `By continuing, you agree to our Terms of Service and Privacy Policy.`

**Loading overlay:** `Signing you in...`

**Error alert:** `Couldn't sign you in` / `Something went wrong. Try again, or use a different sign-in method.` / `OK`

---

## 6.2 Email Sign-In

**Title:** `Sign in`

**Placeholders:** `you@example.com` / `Your password`

**Forgot password note:** `Forgot your password? Sign in with Apple or Google if you linked your account.`

**Error alert:** `Couldn't sign you in` / `Check your email and password and try again.` / `OK`

---

## 6.3 Email Sign-Up

**Title:** `Create account`

**Placeholders:** `What should we call you?` / `you@example.com` / `At least 8 characters` / `Repeat your password`

**Legal footer:** `By creating an account, you agree to our Terms of Service and Privacy Policy.`

**Error alert:** `Couldn't create your account` / `Something went wrong. Try again.`

---

## 6.4 Onboarding — Welcome

**Value props:**
1. `Hold a plank` — *"One exercise. Timed right in the app."*
2. `Build your streak` — *"Miss a day, use a shield. Your streak survives."*
3. `Beat your friends` — *"Leaderboards, groups, and badges. Optional but addictive."*

**CTA:** `Get started`

---

## 6.5 Onboarding — Your Name

**Headline:** `What should we call you?`

**Subtext:** `This shows up on leaderboards and to friends. You can change it any time.`

**Placeholder:** `Your name`

**Error:** `Couldn't save your name. Try again.`

---

## 6.6 Onboarding — How It Works

**Headline:** `Here's how it works`

**Steps:**
1. `Hold a plank` — *"Tap the big button. Hold as long as you can. Done."*
2. `Do it every day` — *"One plank a day keeps your streak alive."*
3. `Miss a day? No panic` — *"Streak shields automatically cover missed days. You start with two."*

**CTA:** `Got it, let's go`

---

## 6.7 Onboarding — Notifications

**Headline:** `Never miss a day`

**Subtext:** `Set a daily reminder and we'll nudge you once — just once — to hold your plank.`

**Primary button:** `Turn on reminders`

**Secondary:** `Maybe later`

**Notification preview:** `Time to plank 🔥` / `Your streak is waiting.`

---

## 6.8 Plank Timer

| State | Copy |
|---|---|
| Ready — active streak | `Tap to plank` + `Protect your {N}-day streak` |
| Ready — no streak | `Tap to plank` + `Start your streak today` |
| Countdown | `Get into position` |
| Active | `Tap to stop` |
| Celebration | `Well done` |
| Save failed (alert) | `Plank not saved` / `Your plank couldn't be saved. Check your connection and try again.` / `OK` |

---

## 6.9 Progress Screen

**Loading:** `Loading your progress...`

**Badges empty state:** `Keep planking to earn badges`

**Recent planks empty state:** `No planks yet — your first one is the hardest`

**Error alert:** `Couldn't load your progress` / `Something went wrong. Pull down to try again.`

---

## 6.10 Profile Screen

**Section header (freeze mechanic):** `STREAK SHIELDS`

**Shield counter:** `{N} of {max} shields left`

**Shield description:** `A shield automatically activates when you miss a day — so your streak survives.`

**Badges empty:** `Complete streaks and planks to earn your first badge`

**Error alert:** `Couldn't load your profile` / `Something went wrong. Try again.`

---

## 6.11 Edit Profile

**Placeholders:** `Your name` / `e.g. London, UK` / `A sentence or two about you`

**Error alert:** `Couldn't save your profile` / `Something went wrong. Try again.`

---

## 6.12 Settings

**Toggles:** `Daily reminder` / `Timer sounds`

**Timer footer:** `Plays countdown beeps and a chime when your plank ends`

**Today's planks empty:** `Nothing yet today — go hold a plank`

**Swipe hint:** `Swipe left on a plank to delete it`

**Delete plank alert:** `Delete this plank?` / `Removes your {time} plank. It can't be undone.` / `Delete` / `Cancel`

**Discard all alert:** `Discard all today's planks?` / `This removes all {N} plank(s) from today ({duration} total). It can't be undone.` / `Discard All` / `Cancel`

**Sign out loading:** `Signing out...`

**Sign out alert:** `Sign out?` / `You'll need to sign in again to access your account.` / `Sign Out` / `Cancel`

**Delete account footer:** `Permanently deletes your account, all your planks, streaks, and badges. This can't be undone.`

**Delete account loading:** `Deleting your account...`

**Delete account alert:** `Delete your account?` / `Everything goes — your planks, streak, badges, and groups. This can't be undone.` / `Yes, delete everything` / `Keep my account`

---

## 6.13 Groups Screen

**Empty state heading:** `No groups yet`

**Empty state body:** `Groups are where things get competitive. Create one or join an existing group to get on a shared leaderboard.`

**Empty CTA:** `Create a group`

**Approval label:** `Approval required`

**Join buttons:** `Join` (open) / `Request to join` (approval required)

**Join error alert:** `Couldn't join` / `Something went wrong. Try again.`

---

## 6.14 Create Group

**Title:** `New Group`

**Placeholders:** `e.g. Office Core Club` / `What's this group about? (optional)`

**Toggles:** `Private group` / `Require approval to join`

**Privacy footers:** *(see §5.6)*

---

## 6.15 Group Detail

**Leaderboard empty:** `No data yet — complete planks to get on the board`

**Leave alert:** `Leave this group?` / `You'll be removed from the leaderboard. You can always rejoin.` / `Leave` / `Cancel`

**Action error:** `Something went wrong` / `Couldn't complete that action. Try again.`

---

## 6.16 Group Settings

**Delete footer:** `Permanently deletes this group and removes all members. This can't be undone.`

**Delete alert:** `Delete this group?` / `All {N} members will be removed and notified. This can't be undone.` / `Delete Group` / `Cancel`

**Coming soon alert:** `Coming soon` / `{Feature} isn't available yet. We'll add it in a future update.` / `Got it`

---

## 6.17 Search

**Placeholder:** `People, groups...`

**No suggestions:** `No suggestions yet` / `Search above to find people to follow`

**No results:** `No results for "{query}"` / `Try a different name or check your spelling`

**Minimum characters:** `Type at least 2 characters to search`

**Error alert:** `Search failed` / `Couldn't run that search. Try again.`

---

## 6.18 Notifications

**Mark all button:** `Mark all as read`

**Empty state:** `You're all caught up` / `Nothing new right now`

---

## 6.19 Leaderboard

**Your rank label:** `Your rank`

**Global empty:** `No one here yet` / `Complete planks to appear on the leaderboard`

**Friends empty:** `No friends yet` / `Follow people to see how you stack up against them`

**Error alert:** `Couldn't load leaderboard` / `Something went wrong. Try again.`

---

## 6.20 Badges Screen

**Error alert:** `Couldn't load badges` / `Something went wrong. Try again.` / `Retry`

---

## 6.21 Plank History

**Empty state:** `No planks yet — your first one is waiting`

**Error alert:** `Couldn't load your history` / `Something went wrong. Pull down to try again.`

---

## 6.22 Add Plank (formerly Manual Entry)

**Title:** `Add Plank`

**Submit button:** `Add Plank`

**Duration footer:** `Min: 10 seconds · Max: 60 minutes`

**Today-only note:** `You can only add planks for today. You can edit or delete them until midnight.`

**Validation error:** `Duration must be between 10 seconds and 60 minutes.`

**Error alert:** `Couldn't add plank`

---

## 6.23 User Profile (other users)

**Stat labels:** `Current streak` / `Longest plank`

**Error alert:** `Something went wrong` / `Couldn't complete that action. Try again.`

---

## 6.24 Follow Lists

**Following empty:** `Not following anyone yet` / `Find people to follow in Search`

**Followers empty:** `No followers yet` / `When someone follows you, they'll appear here`

---

# 7. Badge Content Library

Every badge has four required content states. Do not add a badge to the database without all four.

**Format:**
```
Name:     [Title Case, 2-4 words]
Type:     [internal type key]
Earned:   [Past tense, warm, 1-2 sentences]
Locked:   [Present tense, clear requirement]
Progress: [{N} of {total} — [encouragement]] or — (binary)
```

---

## 7.1 Streak Badges

| Badge | Type | Earned | Locked | Progress |
|---|---|---|---|---|
| **First Flame** | `streak_7` | Seven days in a row. You've got a real streak going. | Hold a plank 7 days in a row. | `{N} of 7 days — keep the flame alive` |
| **Two Weeks Strong** | `streak_14` | Two full weeks. This is starting to feel like a habit. | Keep your streak alive for 14 days. | `{N} of 14 days — halfway there` |
| **Month of Planks** | `streak_30` | 30 days straight. You've officially made this a habit. | Reach a 30-day streak. | `{N} of 30 days — you're building something real` |
| **Two Months, No Excuses** | `streak_60` | 60 days. At this point, planking is just part of who you are. | Keep your streak going for 60 days. | `{N} of 60 days — this is the hard part, and you're doing it` |
| **The Quarter** | `streak_90` | 90 days straight. Three months of showing up, no matter what. | 90 days. One plank at a time. | `{N} of 90 days — you're in the top tier` |
| **Half Year Hero** | `streak_180` | 180 days. Six months of not skipping once. That's exceptional. | Reach a 180-day streak. This one takes real dedication. | `{N} of 180 days — this badge is rare` |
| **The Full Year** | `streak_365` | 365 days. A plank every single day for a year. You're in very rare company. | One plank, every single day, for a year. The ultimate badge. | `{N} of 365 days — you're writing history` |

---

## 7.2 Count Badges

| Badge | Type | Earned | Locked | Progress |
|---|---|---|---|---|
| **Off the Ground** | `count_1` | You did your first plank. The hardest one is done. | Complete your first plank. | — (binary) |
| **Ten Down** | `count_10` | 10 planks completed. You're past the "just trying it" stage. | Complete 10 planks total. | `{N} of 10 planks` |
| **The Fifty** | `count_50` | 50 planks in the bag. This is a real body of work. | Complete 50 total planks. | `{N} of 50 planks` |
| **The Century** | `count_100` | 100 planks. That's a lot of holding on. | Reach 100 total planks. | `{N} of 100 planks` |
| **Five Hundred Club** | `count_500` | 500 planks. You've been doing this long enough to call yourself a plank person. | Complete 500 total planks. | `{N} of 500 planks` |
| **One Thousand Strong** | `count_1000` | 1,000 planks. An extraordinary number. Your core must be granite by now. | Reach 1,000 total planks. | `{N} of 1,000 planks` |

---

## 7.3 Duration Badges

| Badge | Type | Earned | Locked | Progress |
|---|---|---|---|---|
| **First Minute** | `duration_60` | A full minute, held from start to finish. Harder than it sounds. | Hold a plank for 1 minute in a single session. | — (binary) |
| **Two Minutes Solid** | `duration_120` | Two full minutes without giving up. Most people can't do this. | Hold a plank for 2 minutes. | `Your best is {N} seconds — keep pushing` |
| **Three and Counting** | `duration_180` | 3 minutes. At this point your abs are not normal abs. | Hold a plank for 3 minutes. | `Your best is {N} seconds — almost there` |
| **Five Minute Legend** | `duration_300` | 5 minutes. That's genuinely superhuman. Show-off. | Hold a plank for 5 minutes. Only legends do this. | `Your best is {N} seconds` |

---

## 7.4 Special / Social Badges

| Badge | Type | Earned | Locked | Progress |
|---|---|---|---|---|
| **Social Creature** | `social_follow_10` | Following 10 people. Your leaderboard just got competitive. | Follow 10 people. | `Following {N} of 10 people` |
| **Group Player** | `groups_joined_1` | Joined your first group. Now the pressure's on. | Join a group. | — (binary) |
| **Shield Bearer** | `freeze_used` | Used your first streak shield. Saved your streak, lived to fight another day. | Use a streak shield. | — (binary) |
| **Early Adopter** | `early_adopter` | You were here before this app was cool. Respect. | — (auto-awarded, not shown in locked state) | — (binary) |

---

# 8. Push Notification Library

**Before adding a new notification type, complete the template in §5.8 and verify it passes the "would I be annoyed by this?" test.**

---

## 8.1 Daily Reminders (7 rotating variants)

Sent once daily at the user's chosen reminder time. Rotated to prevent desensitisation.

| # | Title | Body |
|---|---|---|
| 1 | `Time to plank 🔥` | `Your streak is waiting. It'll take less than a minute.` |
| 2 | `Still haven't planked today` | `Tap to get it done. Your streak depends on you.` |
| 3 | `One plank. That's all.` | `You've done this before. You can do it again today.` |
| 4 | `Your streak is waiting 🔥` | `Don't let it slip. Tap here to start your plank.` |
| 5 | `Quick question` | `Did you plank today? Because your streak thinks you didn't.` |
| 6 | `This is your plank reminder` | `Hold it for as long as you can. We'll track the rest.` |
| 7 | `One plank a day` | `Keep the slump away. Tap to go.` |

---

## 8.2 Streak Milestone Notifications

Sent immediately after saving a plank that reaches a milestone streak.

| Milestone | Title | Body |
|---|---|---|
| 7 days | `7-day streak 🔥` | `One week straight. You've earned your First Flame badge.` |
| 14 days | `14-day streak 🔥` | `Two weeks without missing a day. That's discipline.` |
| 30 days | `30-day streak 🏅` | `A full month. You've officially built a habit.` |
| 60 days | `60-day streak 💪` | `Two months. You're past the point of giving up now.` |
| 90 days | `90-day streak 🏆` | `Three months straight. The Quarter badge is yours.` |
| 180 days | `180-day streak ⭐` | `Six months. Half Year Hero. You're rare.` |
| 365 days | `365-day streak 👑` | `A full year of planking. There are no words. You're a legend.` |

---

## 8.3 Streak At-Risk Notifications

Sent late evening if the user hasn't planked. Only sent once. Not sent if a daily reminder was already delivered that day.

| Scenario | Title | Body |
|---|---|---|
| Streak < 7 days | `Plank before midnight` | `Still time to keep your streak alive. Won't take long.` |
| Streak ≥ 7 days | `Your streak is at risk` | `Hold a {N}-day streak? Don't lose it now. Quick plank before midnight.` |
| Streak ≥ 30 days | `Don't lose your {N}-day streak` | `Tonight's the night you need to plank. Midnight's coming.` |
| Has shield | `Running low on time` | `Quick reminder — plank tonight or your shield will kick in. Either way, you're covered.` |

---

## 8.4 Streak Lost Notifications

Sent the morning after a missed day with no shield remaining.

| Scenario | Title | Body |
|---|---|---|
| Streak lost | `Streak gone` | `Your {N}-day streak ended. Today's a fresh start — let's build it back.` |
| Last shield auto-used | `Shield activated 🛡️` | `You missed yesterday, but your streak shield saved your {N}-day streak. One shield left.` |
| No shields left, streak lost | `Streak ended` | `Your {N}-day streak is gone. You're out of shields. Today, start fresh.` |

---

## 8.5 Streak Shield Notifications

| Scenario | Title | Body |
|---|---|---|
| Shield earned (20-day bonus) | `New streak shield 🛡️` | `You hit 20 days — here's a bonus streak shield. You've got {N} total.` |
| Shield auto-used | `Streak saved 🛡️` | `You missed a day, but your shield activated. Streak stays at {N} days. {remaining} shield(s) left.` |
| Last shield used | `Last shield used 🛡️` | `Your final shield just saved your streak. You're out of shields now — don't miss again.` |

---

## 8.6 Badge Earned Notifications

| Trigger | Title | Body |
|---|---|---|
| Any streak badge | `New badge: {Badge Name} 🏅` | `{Earned description from §7}` |
| Any count badge | `New badge: {Badge Name}` | `{Earned description from §7}` |
| Any duration badge | `New badge: {Badge Name} ⏱️` | `{Earned description from §7}` |
| First plank | `First plank done ✅` | `You've started. That's the most important step.` |

---

## 8.7 Social Notifications

| Scenario | Title | Body |
|---|---|---|
| New follower | `New follower` | `{Name} is now following you.` |
| Group join request (admin) | `Join request` | `{Name} wants to join {Group Name}.` |
| Request approved | `Request approved` | `You're now a member of {Group Name}.` |
| Request denied | `Request not approved` | `Your request to join {Group Name} wasn't approved.` |
| Added to group | `Added to a group` | `{Name} added you to {Group Name}.` |
| Removed from group | `Removed from group` | `You've been removed from {Group Name}.` |
| Group deleted | `Group closed` | `{Group Name} has been deleted by its owner.` |
| Leaderboard #1 (group) | `You're #1 🏆` | `You've taken the top spot in {Group Name}. Hold on to it.` |

---

# 9. Onboarding & Retention Sequences

## 9.1 In-app onboarding flow (4 screens)

**Screen 1 — Welcome**  
Value props → CTA: `Get started`

**Screen 2 — Your Name**  
Headline: `What should we call you?`  
CTA: `Continue`

**Screen 3 — How It Works**  
Explains the plank mechanic, streaks, and shields.  
CTA: `Got it, let's go`  
*(See §6.6 for full copy)*

**Screen 4 — Notifications**  
Headline: `Never miss a day`  
CTA: `Turn on reminders` / `Maybe later`

---

## 9.2 Day-1 Re-engagement (push)

*Trigger: 24 hours after sign-up with no plank recorded*

| Title | Body |
|---|---|
| `Your streak is at zero` | `You haven't done your first plank yet. One tap, one hold, you're on the board.` |

---

## 9.3 Streak milestone celebrations (in-app)

*Triggered on saving a plank that hits the milestone*

| Milestone | Title | Body | CTA |
|---|---|---|---|
| 7 days | `7 days straight` | `You've earned the First Flame badge and built yourself a real streak. Don't stop now.` | `Keep going` |
| 14 days | `Two weeks, no breaks` | `You're in the top 10% of Plank Challenge users. This is officially a habit.` | `Let's go` |
| 30 days | `30 days. A full month.` | `You've done something most people can't: shown up every day for a month. The Month of Planks badge is yours.` | `See my badges` |

---

## 9.4 Streak recovery sequences

**Short streak lost (< 30 days)**

- In-app sub-message: `Your {N}-day streak ended yesterday. Today, you start fresh — and faster.`
- Push (3 days later, no new plank): `Still waiting` / `Your last streak was {N} days. You can beat it. Start today.`

**Long streak lost (≥ 30 days)**

- In-app sub-message: `Your {N}-day streak ended. That was a serious run — you know you can do it again.`
- Push (day after): `{N} days. That was real.` / `You lost your streak, but you proved you can hit {N} days. Start again. We're here.`

---

## 9.5 Lapsed user re-engagement (push)

| Days inactive | Title | Body |
|---|---|---|
| 7 | `Been a while` | `Your last plank was {N} days ago. Takes 20 seconds to get back on track.` |
| 14 | `Your streak is a distant memory` | `But you can build a new one. Today's plank takes 20 seconds.` |
| 30 | `Still here, if you want it` | `We haven't deleted anything. Your account, your history — all still yours. One plank whenever you're ready.` |

---

# 10. App Store Listing

## 10.1 App name & subtitle

**App name:** `Plank Challenge`

**Subtitle (24 of 30 characters):** `Daily core habit tracker`

---

## 10.2 Promotional text (170 character max)

```
Hold a plank. Every day. Track your streak, earn badges, and compete with friends. The simplest fitness habit you'll ever build.
```
*(128 characters)*

---

## 10.3 Full description

```
Plank Challenge is the simplest fitness habit you can build.

One exercise. Every day. That's the whole app.

TAP. HOLD. STOP.
Tap the big button, get into position, and hold as long as you can. The app times you. When you're done, tap stop. Your plank is saved.

BUILD YOUR STREAK
Come back the next day and do it again. And the day after that. Watch your streak grow on a satisfying monthly calendar. Miss a day? Streak Shields automatically protect your streak — you start with two.

EARN BADGES
Hit milestones and unlock badges: First Flame (7 days), Month of Planks (30 days), The Full Year (365 days), and more. Duration badges for your longest holds. Count badges for your total planks.

COMPETE WITH FRIENDS
Follow friends and see how your streaks compare. Join groups or create your own. Group leaderboards for streak length and longest single plank. Global leaderboards too.

FIVE PLANK TYPES
Elbow plank, high plank, left side, right side, reverse plank. Track each one separately.

NO SUBSCRIPTION. NO UPSELLS.
Just a plank app that does one thing really well.

---

Start today. Your first plank takes less than a minute.
```

---

## 10.4 Keywords (99 of 100 characters)

```
plank,timer,streak,core,ab,workout,habit,fitness,daily,counter,challenge,tracker,badge,leaderboard
```

---

## 10.5 Screenshot copy (6 frames)

| Frame | Headline | Subline |
|---|---|---|
| 1 — Timer | `One tap. One plank.` | `The simplest fitness habit you'll build.` |
| 2 — Streak calendar | `Build your streak.` | `A daily plank habit on a satisfying calendar.` |
| 3 — Progress / badges | `Earn badges.` | `Hit milestones. Unlock rewards. Keep going.` |
| 4 — Leaderboard | `Beat your friends.` | `Global and group leaderboards. May the best streak win.` |
| 5 — Groups | `Compete in groups.` | `Create a group, invite friends, own the leaderboard.` |
| 6 — Streak hero | `365 days of showing up.` | `The Full Year badge awaits. It starts with one plank today.` |

---

## 10.6 Release notes templates

**v1.0 launch:**
```
Welcome to Plank Challenge 👋

This is version 1.0. Here's what's in the box:

• Daily plank timer with countdown
• Streak tracking with Streak Shields
• Badges for milestones, duration, and total planks
• Global and group leaderboards
• Follow friends and compare streaks
• Five plank types supported
• Manual plank entry

Go hold a plank.
```

**Future updates:**
```
What's new in {version}:

• {Specific improvement, plain English}
• {Bug fix: "Fixed a crash that happened when..."}
• {Feature addition}

As always, thanks for planking with us.
```

---

*Plank Challenge Content Guide — v2.0 — Last updated March 2026*  
*To propose a change to this document, update the relevant section and note the date.*
