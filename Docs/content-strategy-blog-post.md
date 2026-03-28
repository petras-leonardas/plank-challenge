# How We Rewrote Every Word in Plank Challenge — and Why It Mattered

When we started building Plank Challenge, we did what most developers do: we wrote placeholder copy, shipped it, and told ourselves we'd come back to polish the words later.

Later came.

We had a working app — daily plank timer, streak tracking, groups, leaderboards, badges. The core experience was solid. But when we went back and actually read the UI as a user would, something felt off. The app didn't sound like itself. It sounded like a committee had translated it from engineering tickets into English, one screen at a time, with no one watching the whole.

This is the story of how we fixed that — systematically, across every single screen.

---

## The problem with "good enough" copy

Here's a real example. Our delete account confirmation dialog said:

> **Delete Account**  
> This will permanently delete your account, all your planks, streaks, and badges. This cannot be undone.  
> **[Cancel]** **[Delete My Account]**

That's not terrible. It communicates the facts. But it's also not good. "This cannot be undone" is formal and slightly robotic. "Delete My Account" as a confirm button doesn't feel like a person wrote it — it feels like a label in a database schema.

Compare that to what we replaced it with:

> **Delete your account?**  
> Everything goes — your planks, streak, badges, and groups. This can't be undone.  
> **[Keep my account]** **[Yes, delete everything]**

Same information. Completely different feeling. The cancel button now says "Keep my account" — which forces the user to confront what they'd actually be losing. The confirm button is honest and decisive. The contraction ("can't" not "cannot") sounds like a human wrote it.

That's the whole premise of this project: **every word is a design decision**, and we had made thousands of small, lazy design decisions without realising it.

---

## How we approached it

We didn't start by changing copy. We started by understanding who we were writing for.

Plank Challenge is not a fitness app for serious athletes. It's for people who want to build one small habit — one exercise, every day. The target user is what we call **The Habit Starter**: someone who finds full workout plans overwhelming, responds to visible progress, and shuts down the moment an app makes them feel guilty for missing a day.

Once we knew who we were writing for, we could define how the app should sound. We landed on four voice traits:

**1. Encouraging without being a pushover.** We celebrate every win, but we don't manufacture fake enthusiasm. When someone misses a day, we acknowledge it honestly and move forward.

**2. Playful but not silly.** We have personality — wordplay, light humour, the occasional cheeky aside. But cleverness never gets in the way of clarity. This isn't a kids' app.

**3. Brief and confident.** Every word earns its place. "Remove Photo" not "Tap here to remove your current profile photo." Short sentences. Strong verbs.

**4. Honest and human.** We don't hide bad news behind corporate language. "Something went wrong. Try again." not "An unexpected error has occurred in the application." We treat users like adults.

From there, we wrote a tone guide — how the voice shifts by context. Celebration copy is warm and specific ("37 days. That's commitment."). Error copy is matter-of-fact and solution-focused ("Couldn't save that. Try again."). Destructive actions are plain and serious, with no dramatic flair.

We also established writing mechanics: how we handle capitalisation, when to use contractions, when emoji are allowed (rationed, maximum one per notification), how to write loading states (specific rather than generic — "Loading your progress..." not just "Loading...").

---

## The rename that changed everything

The single most meaningful terminology change in the whole project was one name.

**Before:** Streak Freeze Tokens  
**After:** Streak Shields

"Freeze tokens" is developer language. It describes what the feature is *called internally*, not what it *does for the user*. A token is an abstract unit. Freeze is mechanical.

A shield, though — a shield you immediately understand. It protects you. It's in your inventory. When it's gone, you're exposed. The shield metaphor communicates the entire mechanic without any explanation:

> 2 of 3 shields left  
> A shield automatically activates when you miss a day — so your streak survives.

That's it. No further explanation needed. The name does the work.

This kind of rename — from internal terminology to user-facing language — is one of the highest-leverage things you can do in a product. It costs nothing in engineering time, and it changes how users conceptually understand and care about a feature.

We found one more instance of this: the "Manual Entry" screen. That's what an engineer calls the feature. Users call it "adding a plank." So that's what we called it too.

---

## The new screen we didn't know we needed

One gap became obvious during the audit: we were dropping users into a plank timer with no explanation of how streaks, missed days, or shields actually worked. We assumed they'd figure it out. Most wouldn't.

The fix was a fourth onboarding screen — between "Your Name" and "Notifications" — called "Here's how it works." Three steps, each with an icon and two lines of copy:

1. **Hold a plank** — *"Tap the big button. Hold as long as you can. Done."*
2. **Do it every day** — *"One plank a day keeps your streak alive."*
3. **Miss a day? No panic** — *"Streak shields automatically cover missed days. You start with two."*

CTA: **"Got it, let's go."**

The whole screen takes about 10 seconds to read. It answers the three questions a new user will have before they've even asked them. It sets the correct expectations about how streaks work — which means fewer disappointed users when they discover the mechanic later.

This is the difference between onboarding that explains the interface and onboarding that explains the *mental model*. Users don't need to know how to tap a button. They need to understand what they're building and why it's worth protecting.

---

## What we changed, screen by screen

The full audit touched 26 files across the iOS codebase. Rather than list every change, here are the patterns that came up repeatedly:

**Titles went from Title Case to sentence case.** "Delete Plank?" became "Delete this plank?" Sentence case feels conversational. Title Case feels like a bureaucratic form.

**Exclamation marks got cut.** We had them everywhere — "Keep planking to earn badges!", "No planks yet — complete your first plank to get started!", "You're all caught up!" The only places they earned their way back were genuine celebrations (streak milestones, badge earned moments).

**"Please" got cut entirely.** "Please try again" is corporate politeness that adds nothing. "Try again" is honest and clear.

**Empty states became inviting instead of deflating.** "No planks yet — complete your first plank to get started!" became "No planks yet — your first one is the hardest." The original version is a command. The new version is an acknowledgement — it recognises that starting is the hard part, which makes the user feel understood rather than prompted.

**Error alerts got specific titles.** "Error" is not a title. It's a type. "Couldn't sign you in" tells the user exactly what failed, in their language.

**Loading states got specific.** "Loading..." became "Loading your progress...", "Loading your history...", "Loading badges..." The specificity makes the wait feel intentional rather than broken.

**Destructive confirmations got honest.** The pattern we followed: state the consequence plainly, use "can't" not "cannot", make the confirm button say what it actually does, and make the cancel button remind the user what they're keeping.

---

## The badge library

One of the most neglected content areas in any app is the badge system. Badges are a key retention mechanic — they give users things to work toward and celebrate when reached — but the copy that accompanies them is almost always an afterthought.

We wrote a full badge library: 21 badges across four categories (streak milestones, total plank count, single-session duration, and social/special), each with:

- A name (2–4 words, memorable)
- An earned description (past tense, warm, specific to what the user achieved)
- A locked description (present tense, motivational teaser)
- Progress copy (shown while working toward the badge)

Some examples:

**First Flame** (7-day streak)
- Earned: *"Seven days in a row. You've got a real streak going."*
- Locked: *"Hold a plank 7 days in a row."*

**Five Minute Legend** (5-minute single plank)
- Earned: *"5 minutes. That's genuinely superhuman. Show-off."*
- Locked: *"Hold a plank for 5 minutes. Only legends do this."*

**The Full Year** (365-day streak)
- Earned: *"365 days. A plank every single day for a year. You're in very rare company."*
- Locked: *"One plank, every single day, for a year. The ultimate badge."*

The earned descriptions do something specific: they reflect back to the user what they actually did, in human terms, rather than just confirming that a threshold was crossed. "Seven days in a row" is more meaningful than "7-day streak badge earned." It's the difference between a system acknowledging a data point and a voice saying *I noticed what you did.*

---

## Push notifications

We wrote a full notification library — 35+ notification variants across seven categories:

- **Daily reminders** (7 rotating variants, to avoid the desensitisation that comes with seeing the same notification every day)
- **Streak milestones** (one per milestone from 7 to 365 days)
- **Streak at-risk** (sent late evening if no plank that day, calibrated by streak length)
- **Streak lost** (recovery-focused, not guilt-focused)
- **Shield notifications** (earned, activated, last shield used)
- **Badge earned**
- **Social** (follows, group events, leaderboard)

The core philosophy for all of them: **no guilt, no fear, no fake urgency.** Notifications that guilt-trip users into opening an app create short-term opens and long-term churn. We want notifications that feel like a friend who knows what you care about sending a timely nudge — not a system nagging you because you haven't opened it today.

The at-risk notification for a 90-day streak looks very different from the one for a 3-day streak. We calibrated the urgency and tone to what the user actually has to lose, because that's the only message that lands correctly.

---

## App Store listing

We wrote a complete App Store listing from scratch: app name, subtitle, promotional text, full description, keyword field, and copy for six screenshot frames.

The full description leans into the simplicity that defines the app:

> *Plank Challenge is the simplest fitness habit you can build.*  
> *One exercise. Every day. That's the whole app.*

And it ends the same way:

> *Start today. Your first plank takes less than a minute.*

The keyword field is 99 of 100 allowed characters, targeting high-intent fitness habit searches. The subtitle — "Daily core habit tracker" — signals the streak mechanic, hits a fitness keyword, and lands in a high-value App Store search category, all in 24 characters.

---

## What this process taught us

A few things became clear over the course of this work:

**Content design is product design.** Every word is a decision about how the product behaves. "Cancel" and "Keep my account" are functionally identical — they both dismiss the dialog. But one of them is a design decision about what the user should be thinking when they make the choice.

**Developer language leaks into the UI more than you think.** "Manual Entry", "Freeze Token", "Authentication Required" — these are all internal concepts that made their way into user-facing screens because nobody stopped to ask what the user would actually call them.

**The absence of copy is also a design decision.** An empty state with no text, an error that just says "Error", a loading spinner with no label — these are content decisions that were made by not deciding. The question isn't whether to write copy for these states. It's whether to write it intentionally or by accident.

**Brevity is a skill.** The instinct when writing UI copy is to over-explain, to add "please", to soften every imperative. The result is copy that feels apologetic and takes twice as long to read. Trust the user. Say the thing. Stop.

---

## What's left

The frontend copy is done. The backend still has two content areas to implement:

1. **Badge names and descriptions** need to be seeded into the database — the copy library is written, it just needs to be imported.
2. **Push notification templates** need to be wired into the notification dispatch logic — the copy variants exist, they need to be connected to the triggers.

Both are straightforward data operations. The hard work — deciding what to say and how to say it — is done.

---

One plank. Every day. That's it.

The copy, at least, now sounds like it means it.
