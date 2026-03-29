---
description: Commit and push all current changes with a descriptive commit message
agent: build
---

Review the current git status and commit all uncommitted changes to the Plank Challenge repo.

Current status:
!`git -C "/Users/lbaceviciuscloudflare.com/Developer/Personal projects/plank-challenge" status --short`

Changes since last commit:
!`git -C "/Users/lbaceviciuscloudflare.com/Developer/Personal projects/plank-challenge" diff --stat HEAD`

Instructions:
- Review what has changed and group into one logical commit (or multiple if the changes are clearly unrelated — e.g. an iOS fix and a backend fix that are independent)
- Write a clear, concise commit message that describes what changed and why — not just what files changed
- Never commit `UserInterfaceState.xcuserstate` — it is git-ignored, but confirm it is not staged
- Stage all relevant changed files, commit, and push to origin
- Report back exactly what was committed and confirm the push succeeded
- If there is nothing to commit, say so clearly
