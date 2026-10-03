# Imagend documentation

Everything you need to understand, run, fix and protect Imagend, written so you can pick it up months from now and still follow it.

| Doc | Read it when… |
|---|---|
| [01 · Journey](01-journey.md) | You want the story: every step from the first prototype to live payments, and why each decision was made. |
| [02 · How it works](02-architecture.md) | You need to understand the parts (site, database, payments) and how they talk to each other. |
| [03 · Setup and settings](03-setup.md) | You are setting up a new environment, or checking a setting in Vercel, Supabase, Flutterwave, Google or GoDaddy. |
| [04 · Runbooks](04-runbooks.md) | Something needs doing *now*: a customer paid but has no plan, a refund, changing prices, a webhook failing. |
| [05 · Editing the app](05-editing.md) | You want to change the Image or Video tool, or the shell (sign-in, plans, payments). |
| [06 · Legal, privacy and IP](06-legal-and-compliance.md) | You are dealing with regulators, lawyers, a data request, or protecting the brand and code. |

## The one-paragraph summary

Imagend (imagendai.com) is a prompt optimizer by **Made by Youni Ltd**. It is one HTML file (`index.html`) hosted on **Vercel**, with the Image and Video tools packed inside it. People sign in with Google through **Supabase**, which also stores plans, daily usage, teams and payment records. Payments go through **Flutterwave**; two small server files in `api/` re-check every payment with Flutterwave before a plan is switched on. Prompts are written in the user's browser, so their ideas never reach our servers.

## Repo map

```
index.html            The whole app (shell + packed Image and Video tools)
src/image.html        Editable copy of the Image tool  ─┐ edit these, then
src/video.html        Editable copy of the Video tool  ─┘ run tools/pack.py
api/                  Server code on Vercel (payment checks, webhook, config)
supabase/             The database setup (run once in Supabase SQL Editor)
terms.html, privacy.html, refunds.html, acceptable-use.html   Legal pages
vercel.json           Serves /terms instead of /terms.html
tools/                pack.py and unpack.py
docs/                 You are here
```
