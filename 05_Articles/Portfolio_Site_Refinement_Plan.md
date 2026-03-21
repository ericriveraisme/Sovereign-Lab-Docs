# Portfolio Site Refinement Plan

**Date:** 2026-03-21
**Goal:** Sharpen the portfolio site for senior/mid-level infrastructure roles — specifically a NOC 1 Technician promotion — while keeping the RPG identity that makes it memorable.

**Core Principle:** The RPG theme is the frame. The professional content is the painting. Right now the frame is stealing attention from the painting. Every change below keeps the theme but makes sure a hiring manager gets the information they need without having to "translate" the game language first.

---

## 1. Rewrite the Character Sheet Bio

**Current:**
> Detail-oriented IT professional with 12 years of experience bridging high-level Network Operations (NOC) and corporate systems administration. Specialist in high-availability infrastructure, hybrid identity (Active Directory/Entra ID), and technical documentation, with proven ownership across internal IT operations.

**Problem:** Generic resume language. "Detail-oriented IT professional" is invisible to hiring managers — it's on every resume they've read today. "Bridging" is vague. Nothing connects to what you're building right now.

**Rewrite:**
> Infrastructure engineer with 12 years across NOC operations, systems administration, and hybrid identity (AD/Entra ID). Currently building a self-hosted virtual data center — designing Layer 3 routing, authoritative DNS, automated backup pipelines, and the documentation to match. 12 years of keeping systems running; now engineering them from the ground up.

**Why this works:**
- Drops the filler ("detail-oriented," "proven ownership")
- Leads with the job family you want (infrastructure engineer), not where you've been (IT professional)
- The Sovereign Lab project becomes proof, not a side project
- The last sentence tells a career story in one line: operations experience + engineering ambition

---

## 2. Rework the Skills Section

**Current:** RPG-style level bars with "LVL" labels. Looks cool but communicates nothing measurable. A manager can't tell if "Infrastructure (Layer 2/3, BGP, VPNs) — LVL" means you've labbed BGP or ran it in a production NOC.

**Proposed Approach — Keep the RPG aesthetic, add real context:**

Instead of abstract level bars, use a structure like:

```
⚔️ SKILLS

Infrastructure (Layer 2/3, BGP, VPNs)         ████████████░░  Production NOC
Hybrid Identity (AD / Entra ID)                ██████████████  6+ years
Firewall Admin (Meraki, Pan-OS)                ████████████░░  Enterprise
DNS & Network Services                         ██████████████  Self-hosted Authority
Endpoint Management (Intune, SCCM)             ██████████░░░░  Corporate Fleet
Linux Systems Administration                   ████████████░░  Proxmox / Ubuntu / Debian
Automation (Bash, Git, Cron)                    ████████████░░  Production Scripts
Technical Documentation                        ██████████████  SOPs, Runbooks, Articles
```

**Key change:** Each skill bar gets a **qualifier** — not a vague level, but a context tag that tells the manager *where* you used it. "Production NOC" is worth 10x more than "LVL 7" to someone deciding whether to promote you.

If the RPG bar component supports a tooltip or subtitle, use that. If not, put the qualifier as right-aligned text on the same line.

---

## 3. Reframe the Subtitle / Class Line

**Current:** `<IT Systems Administrator / Infrastructure & Operations Specialist>`

**Problem:** Describes where you are. For someone trying to move up, it should signal where you're going.

**Options (pick the one that fits the promotion you're targeting):**

- `<Infrastructure Engineer / NOC Operations>` — if the NOC 1 role is network-focused
- `<Systems & Network Engineer / Infrastructure Operations>` — broader
- `<NOC Engineer / Infrastructure & Automation>` — if you want to lead with the NOC identity

The "Class" field in the Character Sheet can stay as a fun RPG label, but the subtitle in the header is the first thing anyone reads. Make it match the job title you want, not the one you have.

---

## 4. Tighten the Adventure Log (Job History)

**Current issue:** Three roles in 12 months (Ritter → Visual Edge → Irby) after 6 years at Teleflora. This will be noticed. The site should help you control the narrative.

**Suggestions:**

### A. Add a one-line "why" to each short-tenure role
Not a paragraph — just a brief line that explains the intentional move:

- **Ritter Communications:** *"Moved into ISP infrastructure to get hands-on NOC experience with BGP, VPLS, and Ciena/Nokia platforms."*
- **Visual Edge IT:** *"Took a field role to broaden hardware and on-site troubleshooting across diverse business environments."*
- **Irby Utilities:** *"Current role — supporting regional ISP infrastructure with a focus on uptime and reliability."*

This turns "job hopping" into "deliberate skill building" — which is exactly what it looks like when you read the actual achievements.

### B. Consider grouping the narrative
If your site framework allows it, you could group the three recent roles under a section header like:

**"Infrastructure Sprint (2024–Present)"** — A deliberate series of roles to build hands-on experience across NOC operations, field service, and ISP infrastructure after 6 years in corporate IT.

Then list the three roles under that umbrella. It reframes the pattern as a strategy.

---

## 5. Add a "What I'm Building Toward" Signal

**What's missing:** The site shows what you've done but never says what you want. A manager reviewing you for a NOC 1 promotion wants to see ambition aligned with *their* needs.

**Where to add it:** Either as a short section below the Character Sheet, or as the last line of the bio.

**Example:**
> **Next Mission:** A senior infrastructure role where I can bring NOC operations experience, automation discipline, and the ownership mindset I've built across 12 years of keeping systems alive.

This can be styled as an RPG "quest objective" if you want to keep the theme. The point is: tell them you're ready for the next level. Don't make them guess.

---

## 6. Make the Sovereign Lab the Hero

**Currently:** The Sovereign Lab has a card at the top with "Enter The Portal." That's good placement.

**Improvement:** The card description says:
> "The ultimate grimoire for the public documentation of my home lab (virtual data center) with a focus on infrastructure as code (IaC), network automation, and hybrid identity."

"Ultimate grimoire" is fun but a manager reads "home lab" and may mentally downgrade it. Rewrite to emphasize what it *proves*:

> A self-hosted virtual data center built on Proxmox — Layer 3 routing, authoritative DNS, automated backup pipelines, and full documentation. Designed, deployed, and documented from scratch.

Keep the "Enter The Portal" button — that's the RPG touch that works because it's functional (it tells you to click) rather than decorative.

---

## 7. Active Quests Section

**Currently:** Shows the five most recent articles with newest at the top, dated. These link to the Lab Logs section hosted on your site — not the GitHub repo.

**This is already working well.** The dated entries show active, ongoing work (which is exactly what a manager wants to see). No changes needed here — the Active Quests section proves you're consistently building and writing, which reinforces everything else on the site.

---

## Summary: Changes Ranked by Impact

| Priority | Change | Effort | Impact |
|----------|--------|--------|--------|
| 1 | Rewrite the Character Sheet bio | 10 min | High — first thing a manager reads |
| 2 | Update the subtitle/Class to target role | 5 min | High — sets expectations immediately |
| 3 | Add context qualifiers to skill bars | 30 min | High — turns decoration into evidence |
| 4 | Add "why" lines to short-tenure roles | 15 min | High — defuses the only red flag |
| 5 | Rewrite the Sovereign Lab card description | 10 min | Medium — positions the project as professional work |
| 6 | Add "What I'm Building Toward" line | 5 min | Medium — signals ambition and direction |
| 7 | Verify article links point to repo | 10 min | Low — quality of life |

---

## The RPG Theme: Final Word

Keep it. It works because it's yours — it's authentic, it's memorable, and in a stack of 50 identical portfolio sites, yours is the one they'll remember. The risk isn't the theme; it's letting the theme carry weight that should be carried by content. Every change above keeps the frame but sharpens the painting inside it.

When your managers at Irby pull up your site, they should see a gamer who happens to build serious infrastructure — not a gamer who happens to work in IT. The Sovereign Lab repo is already telling that story. The website just needs to match it.

---

*Eric Rivera — Sovereign Lab Architect (in training)*
