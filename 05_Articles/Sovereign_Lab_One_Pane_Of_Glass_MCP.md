# 🔭 One Pane of Glass To Rule Them All: Wiring My Editor Into Proxmox Without Losing My Mind

**Date:** August 15, 2026

**Author:** Eric

**Category:** Systems Engineering / Learning in Public

---

There's a special kind of fatigue that only shows up after your fourth Alt-Tab of the hour: Proxmox tab, Chrome tab, a browser-based AI chat, back to the editor, back to Proxmox to check if the thing you just asked about is actually true. Multiply that by an evening of planning a network expansion, and it starts to feel less like systems engineering and more like flipping between chapters of a Tolkien book trying to remember who Théoden is and why the Ents are angry.

I wasn't trying to build something impressive here. I was trying to stop being my own bottleneck.

## 🧩 The Actual Problem

The Sovereign Lab is about to get more complicated. I'm planning a multi-site virtual WAN buildout — new bridges, a second router, BGP peering between them — the kind of change where you really want to cross-reference live cluster state against your own documentation before you touch anything. That means constantly asking "what's actually running right now?" and then going and checking it by hand.

Every one of those checks used to mean leaving the editor, opening Proxmox in a browser, squinting at a table, then coming back to paste half of what I found into a chat window somewhere else. It worked. It was also exhausting, and exhausting is exactly the condition under which people fat-finger a production interface.

## 🛠️ What I Actually Did

I connected my editor to my lab's Proxmox API through a local MCP (Model Context Protocol) bridge — the same general pattern a lot of modern software teams have started borrowing for AI-assisted development. Instead of the AI guessing about my infrastructure from memory, it can ask the API directly: what nodes exist, what's running, what's stopped, what storage backends are attached.

The part I want to be honest about, because "learning in public" only means something if you show the parts that almost went wrong: my first attempt didn't work. The token connected, Proxmox said hello, and then the API just... didn't show me any of my VMs. No errors, no drama, just an empty list where five running containers should have been.

Turns out the issue wasn't the lab, it wasn't the network, and it wasn't even really the AI tooling — it was privilege separation on the API token. Proxmox tokens can be scoped so tightly that they don't fully inherit the user's own permissions unless you explicitly tell them to. Once I found that setting and turned it off, the same query that returned nothing suddenly returned my entire cluster: the core router, the management workstation, DNS, the works.

That's a very "help desk brain" kind of bug, honestly — the fix wasn't clever, it was just reading the permission model correctly instead of assuming the token would behave the way I expected it to.

## 🔐 The Part I Care About More Than the Cool Factor

I didn't want an AI black box quietly living in my infrastructure without being mentioned in the same repo where I document everything else. That felt dishonest to the whole premise of this project. So the integration follows the same rule as everything else in the Sovereign Lab: the documentation lives in the open, and the secrets don't.

The actual connection — the API token, the local server config — lives in a folder on my machine that's explicitly excluded from Git. The repo gets the story: why this exists, how it's scoped, what it's allowed to do. It does not get the token.

And the permission itself starts as read-only. `PVEAuditor`, not admin. The AI can look at my lab and tell me what's true. It cannot quietly change anything. If I ever want it to help provision something directly, that's a separate, more narrowly scoped decision — not a default.

## 🪞 Why This Isn't Just a Convenience Hack

I think it's worth saying plainly: this pattern isn't me trying to look cutting-edge. It's the same instinct that led me to write runbooks and version my router configs in Git — reduce the number of places a mistake can hide. Bouncing between four tabs and re-typing the same context into each one is exactly the kind of manual, repetitive process that invites errors. A single, auditable, read-only connection between my tools and my lab does the opposite: it puts the live truth of my infrastructure one prompt away, in the same place I'm already documenting and reasoning about it.

It also gave me a genuinely useful side effect I didn't expect: a live drift check. I asked the assistant to compare what the API actually reports against what my own docs claim, and it caught a stopped monitoring container and a stale node name I'd been carrying in the README for a while. Small things, but exactly the kind of small things that quietly rot a lab's documentation if nobody ever double-checks them against reality.

I couldn't tell you how many times I've made a change in the lab, thought "I'll document that later," and then let "later" quietly turn into "never." If I want to actually document as I go — generate the checklist, the runbook, the change management doc, all of it — the moment the change happens instead of a week after I've half-forgotten why I did it, this was the only realistic way I could think of to make that happen. Relying on my own memory to keep the architecture, the history, and the intent all straight is exactly the kind of single point of failure this whole project is supposed to be pushing back against. I don't trust my future self to remember why I picked a static route over a NAT rule at 1 AM, and I shouldn't have to.

That's really the tradeoff I keep coming back to: let the machine do what it's actually good at — pulling live state, cross-referencing it against a pile of markdown, drafting the first pass of a checklist so I'm not staring at a blank page — and let the human brain do what it's actually good at: deciding whether a change is worth making, knowing when something "feels" wrong even before the metrics say so, and taking responsibility for what gets pushed to production. The AI can tell me my monitoring container is stopped. It can't tell me whether that's fine because I meant to pause it, or a problem because I forgot. That judgment call is still mine, and I want to keep it that way.

## 🎯 Where This Leaves Me

I'm not handing the keys over. I'm not letting an assistant touch BGP configs unsupervised. What I have now is closer to a very well-informed second set of eyes that lives in the same window as my code, my docs, and my terminal — instead of a browser tab I have to keep re-explaining myself to.

One pane of glass to rule them all! No more shepherding context across four different screens like I'm carrying the One Ring between them. If I'm going to lean on AI while I build this out, I'd rather do it transparently, scoped tightly, and documented in the open — the same way I've tried to approach everything else in this project.

**Next up:** using this same read-only view as a pre-flight check before the vWAN and BGP rollout actually begins.
