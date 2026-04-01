# Post 4 — Opening Hooks: Four Layers of Security You Didn't Have to Build

**Topic**: 4 — Four Layers of Security You Didn't Have to Build

---

## Hook 1 — Pain-first

Every AI integration framework I've evaluated punts on authorization.
They give you a tool executor, wish you luck, and leave you building
a parallel permission system from scratch.

## Hook 2 — Misconception-first

"We need to build a new authorization layer for AI agents."
No, you don't — not if your data already lives in Salesforce.
Your org's existing security model handles it.

## Hook 3 — Architecture-first

Four authorization layers sit between an AI agent and your Salesforce data:
OAuth scopes, Profile/Permission Set visibility, Sharing Rules, and
developer-defined validate() methods. None of them are new.

## Hook 4 — Business-first

The first question in every AI security review: "How do you control what the agent can access?"
The best answer is the shortest one: "The same way we control our users."
That's what inheriting Salesforce's existing permission model gives you.

## Hook 5 — Curiosity-first

The most secure AI integration I've built required zero new security infrastructure.
No custom middleware, no shadow permission system, no new credential store.
Here's why building nothing was the right architectural decision.
