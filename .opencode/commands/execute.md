---
description: Implement everything agreed on in the current conversation — switches from planning to building
agent: build
---

We have finished discussing and planning. Now implement everything that was agreed on in this conversation.

Follow the agreed approach exactly. Do not re-propose, re-discuss, or ask for confirmation on decisions that have already been made — just build.

Work through the changes methodically:
- Make all agreed file changes
- If the changes are to iOS Swift files, use the ios-deploy skill to build, install, and deploy to the device when done
- If the changes include backend TypeScript files, use the backend-deploy skill to deploy to Cloudflare when done
- When everything is deployed and confirmed, run /done to commit and push

If anything is genuinely ambiguous — something not covered in the discussion — make a reasonable decision, implement it, and note what you decided at the end. Do not stop to ask about it mid-implementation.
