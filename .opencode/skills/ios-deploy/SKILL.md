---
name: ios-deploy
description: Build, install, and deploy the iOS app to the physical iPhone connected via USB
license: MIT
compatibility: opencode
---

## What I do

Execute the three-step build → install → deploy sequence to get code changes running on the owner's physical iPhone. I also know when a clean build is required and how to verify each step succeeded before moving to the next.

## Device

- **Name:** LeoDesignsTheWorld
- **ID:** `00008150-001E444A0AD2401C`
- **Connection:** USB (must be connected and trusted)

## When to use me

Use me whenever iOS source files have been changed and the owner needs to see the result on their device. Typical triggers:
- "Build and deploy"
- "Install this on the device"
- "Let me test this on my phone"
- After any set of Swift file edits is complete

## Step-by-step workflow

### Step 1 — Build

Run from `PlankChallenge/`:

```bash
cd "/Users/lbaceviciuscloudflare.com/Developer/Personal projects/plank-challenge/PlankChallenge" && \
xcodebuild \
  -project PlankChallenge.xcodeproj \
  -scheme PlankChallenge \
  -destination "id=00008150-001E444A0AD2401C" \
  -configuration Debug \
  build 2>&1 | grep -E "\.swift:[0-9]+:[0-9]+: error:|BUILD SUCCEEDED|BUILD FAILED"
```

**Before proceeding:** confirm the output contains `BUILD SUCCEEDED`. If it contains `BUILD FAILED` or any `.swift:N:N: error:` lines, stop and fix the errors. Do not install a failed build.

### Step 2 — Install

```bash
cd "/Users/lbaceviciuscloudflare.com/Developer/Personal projects/plank-challenge/PlankChallenge" && \
xcodebuild \
  -project PlankChallenge.xcodeproj \
  -scheme PlankChallenge \
  -destination "id=00008150-001E444A0AD2401C" \
  -configuration Debug \
  install 2>&1 | tail -3
```

Confirm output contains `INSTALL SUCCEEDED`.

### Step 3 — Deploy to device

```bash
xcrun devicectl device install app \
  --device 00008150-001E444A0AD2401C \
  "$(find ~/Library/Developer/Xcode/DerivedData/PlankChallenge-*/Build/Intermediates.noindex/ArchiveIntermediates/PlankChallenge/InstallationBuildProductsLocation/Applications -name 'PlankChallenge.app' | head -1)" \
  2>&1 | tail -5
```

Confirm output contains `databaseSequenceNumber` — this is the install confirmation. Note the sequence number so the owner can verify the device received the latest build.

## When to use `clean build`

Use `-clean` before the build step when any of the following were changed:
- A protocol definition (`ServiceProtocols.swift`)
- An enum with raw values (`APIGroupType`, `APIJoinMode`, `LeaderboardPeriod`, etc.)
- A type definition that other files depend on
- Any file in `Services/API/Models/APIModels.swift`

Clean build command (replaces Step 1):

```bash
cd "/Users/lbaceviciuscloudflare.com/Developer/Personal projects/plank-challenge/PlankChallenge" && \
xcodebuild \
  -project PlankChallenge.xcodeproj \
  -scheme PlankChallenge \
  -destination "id=00008150-001E444A0AD2401C" \
  -configuration Debug \
  clean build 2>&1 | grep -E "\.swift:[0-9]+:[0-9]+: error:|BUILD SUCCEEDED|BUILD FAILED"
```

For view or logic-only changes, skip the clean — incremental build is faster and sufficient.

## LSP errors — do not be alarmed

The editor LSP frequently shows false "Cannot find type" errors in Swift files because it runs without full project context. These are **not real compiler errors**. Always trust the `xcodebuild` output, not the LSP diagnostics.

## After deploying — commit and push

Once the build is verified on device, stage and commit the changed files:

```bash
cd "/Users/lbaceviciuscloudflare.com/Developer/Personal projects/plank-challenge" && \
git add <changed files> && \
git commit -m "<description of what changed>" && \
git push
```

Never commit `UserInterfaceState.xcuserstate` — it is git-ignored. Commit after each logical fix, not only at end of session.
