# Hooks: Post 10 — Per-User OAuth: When the AI Agent Should Run as You, Not as a Service Account

**Topic**: 10 — Per-User OAuth

## 1. Pain-First

Your AI agent connects to Salesforce with a single service account. Every user gets the same access. Now try explaining to your security team why the intern's AI assistant can see the CEO's pipeline.

## 2. Misconception-First

"We'll just use a restricted service account for the AI agent." That solves oversharing — until someone needs access to records the service account can't see. Then you're either escalating the service account's permissions or building a custom authorization layer on top.

## 3. Architecture-First

The proxy auto-detects auth mode from a single flag: `--client-secret` present means client_credentials, absent means Authorization Code with PKCE. Same `AuthStrategy` interface, same runtime behavior. The switch is a config change, not a code change.

## 4. Business-First

When MCP requests run under each user's own Salesforce identity, you inherit per-user profiles, permission sets, and sharing rules for free. Zero custom security infrastructure. Zero audit findings about shared credentials.

## 5. Curiosity-First

What if the right authorization model for your AI agent already exists — and you built it years ago when you set up Salesforce profiles and sharing rules? The missing piece wasn't a new security layer. It was letting the AI agent authenticate as the actual user.
