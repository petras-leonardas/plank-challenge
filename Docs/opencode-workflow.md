# How I Built a Production iOS App with OpenCode — and the Workflow That Made It Work

I've been building Plank Challenge — a daily plank streak tracker for iOS — using OpenCode as my primary development environment. The app is a native SwiftUI iOS app backed by a Cloudflare Workers API, and I built the majority of it through conversation with an AI coding agent.

What I want to share here isn't a tutorial on the app itself. It's the workflow I developed over time: the agents, skills, and commands I created to make AI-assisted development feel deliberate and reliable rather than chaotic.

---

## The problem with vanilla AI coding

When you start using an AI coding agent without any structure, the sessions are productive but brittle. You get fast results on the first pass, but a few things go wrong repeatedly:

- The AI implements something that looks right but has edge cases it didn't think through
- Code gets written that doesn't match your conventions — wrong patterns, inconsistent naming, hardcoded values instead of shared tokens
- You forget to commit after a working session, or the AI forgets to remind you, and you end up with a large accumulating pile of uncommitted changes
- The next session starts cold with no memory of what was established in the previous one

These aren't AI failures — they're workflow failures. The fix isn't a better model, it's better structure around how you work with the model.

---

## The foundation: AGENTS.md

The first thing I set up was an `AGENTS.md` file at the root of the repo. OpenCode reads this automatically at the start of every session, so it never needs to explore the codebase to understand the basics.

The file doesn't describe every feature or screen — that would go stale within a week. Instead it contains things that are **permanently true** about the project:

- The tech stack (SwiftUI iOS 17+, Cloudflare Workers, TypeScript, Hono)
- The exact build and deploy commands with my device ID hardcoded
- The service injection architecture (nine services, all via `@Environment`)
- A feature map — a lookup table of feature → file so the AI goes straight to the right place
- Known schema mismatch traps that burned us multiple times (more on those below)
- Key conventions: one plank per day, settings as sheets not NavigationLinks, AppStorage key names

The most valuable section is the **schema mismatch traps**. We spent significant time debugging decode errors that all had the same root cause: the iOS model didn't match the actual backend JSON shape. By documenting the specific patterns — `AvatarView` has two parameters and you must use `imageUrl` not `imageName` for remote photos, SQLite aggregate functions return `Double` not `Int`, leaderboard responses use `entries` not `leaderboard` — every future session starts with that hard-won knowledge already loaded.

---

## Skills: reusable step-by-step workflows

Skills are markdown files the AI loads on demand when a task matches. Unlike `AGENTS.md` which is always in context, skills are loaded lazily — the AI sees a short description of each and decides when to pull the full content.

I built three skills.

### `ios-deploy`

The most-used skill. Building and deploying to a physical iPhone via USB is a three-step sequence — build, install, then deploy via `devicectl` — and getting the order or flags wrong wastes time. The skill encodes the exact commands with my device ID, explains when to use `clean build` vs incremental build (type changes need clean, view changes don't), and ends with a reminder to commit.

The key insight that makes this valuable: the skill marks the build step as a checkpoint. If `BUILD SUCCEEDED` doesn't appear in the output, the next two steps don't run. Before the skill, the AI would sometimes proceed to install despite a failed build.

### `backend-deploy`

The Cloudflare Workers backend is always live — there's no local dev server. Every backend change goes straight to production. The skill enforces one critical rule I learned the hard way: **commit before deploying**. Wrangler deploys whatever is on disk at that moment, not what's committed. If you deploy before committing, the live Worker can be running code that differs from your git history, making rollback unreliable.

The skill makes commit-before-deploy step 1. Not step 3. Step 1.

### `debug-api`

This one exists because schema mismatches were the most expensive category of bugs in the entire project. When the iOS app shows "Failed to decode response — the data couldn't be read because it is missing", the correct first move is to curl the live API and look at the actual JSON. Not guess, not read the backend source. Look at the actual response.

The skill walks through: create a throwaway test account, get a token, curl the endpoint with that token, pipe through `python3 -m json.tool`, then compare the JSON against the iOS model with a specific checklist. It also contains a lookup table of every specific mismatch we hit, so the same error can't take as long to diagnose twice.

---

## Agents: specialists for specific review tasks

Beyond the built-in Build and Plan agents, I created three custom subagents. These are read-only reviewers — they can't make changes, only report findings. You invoke them with an `@mention`.

### `@review` — conventions compliance

Invoked before deploying. It checks whether the code follows the established project conventions:

- Schema models match the actual backend JSON shape
- Services are accessed via `@Environment`, never instantiated directly
- Protocols and mocks are updated when new service methods are added
- Settings screens are presented as `.sheet` not `NavigationLink` (a push triggers `.onDisappear` and clears service state — this caused a nasty bug where GroupSettingsView would immediately show "Group not found")
- One plank per day is enforced at the UI level
- AppStorage keys are updated consistently as a group
- Content uses the correct terminology (Streak Shield, not freeze token; Add Plank, not manual entry)

This agent runs at the end — after the feature works, before it's committed.

### `@bug-review` — implementation correctness

Invoked immediately after the AI implements something non-trivial, before you even test it on device. The question it asks is different from `@review`: not "does this follow our conventions?" but "is this actually going to work?"

It checks:

- Is every `async throws` call wrapped in `do/catch`, or is the error silently discarded with `try?`?
- Is every `isLoading = true` guaranteed a matching reset via `defer { isLoading = false }`?
- Could rapid double-taps race on shared state? Is there a `guard !isLoading else { return }` guard?
- Is `CancellationError` caught and silently ignored (not surfaced as a user error) when views disappear mid-load?
- What happens when the array is empty? When an optional is nil unexpectedly?
- After a delete operation, is all related state cleaned up?

You invoke it with a brief description of what was just implemented: `@bug-review I just rewrote the delete plank flow in SettingsView to call the backend`. That context lets it check whether the implementation actually achieves the stated goal, not just whether it compiles.

### `@design-review` — design system compliance

The app has a token system in `Constants.swift` and `ViewExtensions.swift` — named spacing values, semantic colours, shared card styles, avatar sizes. It's easy for the AI to hardcode `16` for padding instead of `Constants.UI.screenPadding`, or use `Color.blue` instead of `Color.appAccent`, especially in quickly-written code.

This agent knows every token — the exact values, the exact names — and flags violations: magic number spacing that should be a constant, raw hex colours that should be semantic names, inline card styles that should use `.appCardStyle()`, missing `AppBackground` on screens that need it.

The output is structured as ✅ / ⚠️ / 💡, which makes it fast to scan and act on.

---

## Commands: automation for the things you always forget

OpenCode supports custom slash commands — a single `/word` that injects a full prompt. I built one.

### `/done`

The single thing I forgot most consistently was committing and pushing after changes. The AI would finish implementing something, it would deploy and work on the phone, and then we'd move straight to the next problem without committing. Sessions would end with ten unpushed fixes.

`/done` fixes this. Type it at any natural stopping point. It runs `git status` and `git diff --stat`, shows the AI exactly what's changed, and the AI stages the files, writes a meaningful commit message grouped by what actually changed, commits, and pushes. If there's nothing to commit, it says so.

The `ios-deploy` skill now explicitly ends with: "After confirming the install, run `/done`." This ties committing to the natural completion of every deploy.

---

## The full workflow

Put together, a typical session now looks like this:

```
Describe a problem or feature to implement
  → AI implements it (Build mode)
  → @bug-review [brief description of what was just built]
      ↳ catches logic errors, missing error handlers, race conditions
      ↳ fix any issues found
  → ios-deploy skill (or backend-deploy skill if it's a backend change)
      ↳ build → install → deploy to device
  → test manually on iPhone
  → @review
      ↳ catches convention violations, schema issues, content problems
  → @design-review (if new UI was added)
      ↳ catches hardcoded values, wrong semantic colours
  → /done
      ↳ commits and pushes everything
```

The whole thing feels like having a small team — a developer (Build), an implementation reviewer (bug-review), a lead who enforces standards (review), a designer (design-review), and a DevOps person who makes sure nothing slips uncommitted (done). Except it's just one person and one AI, with structure that makes the AI reliably fill each of those roles when you need it.

---

## What made the difference

The honest answer is: **the structure matters more than the model**.

The same model that produces buggy, convention-breaking code in an unstructured session produces much cleaner output when it has a well-formed `AGENTS.md` loaded, knows to run specific review agents at specific moments, and has a `/done` command that makes committing trivial.

The `AGENTS.md` file is the most important investment. Every hard-won lesson — every schema mismatch that took an hour to diagnose, every navigation bug caused by a NavigationLink where a sheet should have been — gets written down once and then never has to be rediscovered.

The skills and agents compound on top of that. Each one represents a workflow that previously relied on memory — remembering the exact build commands, remembering to commit, remembering to check for missing mocks after adding a service method — and turns it into a reliable, repeatable process.

---

## The files

Everything described here lives in the repo at:

```
.opencode/
├── agents/
│   ├── review.md        conventions compliance
│   ├── bug-review.md    implementation correctness
│   └── design-review.md design token compliance
├── skills/
│   ├── ios-deploy/      build + install + deploy to physical iPhone
│   ├── backend-deploy/  commit → deploy → verify on Cloudflare
│   └── debug-api/       curl live API + diagnose schema mismatches
└── commands/
    └── done.md          /done: commit and push

AGENTS.md                project context loaded on every session
CONTENT_STRATEGY.md      voice, tone, and terminology for all UI copy
```

None of this is complex to build. The skills and agents are markdown files. The commands are markdown files. The `AGENTS.md` is a markdown file. The investment is a few hours of writing down what you know — and then having every future session start with that knowledge already loaded.
