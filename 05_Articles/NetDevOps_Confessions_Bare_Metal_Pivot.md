# **Confessions of a Fake Network Engineer: How I Built a NetDevOps Lab, Hated It, and Pivoted to Bare Metal**

If you spend enough time looking at IT and Network Engineering portfolios, you start to see a pattern. It's the classic *rite* of passage project — someone fires up Cisco Packet Tracer or Modeling Labs, copy-pastes some garden-variety OSPF configs into a simulated router, and calls it a day. Sometimes literally the same day. The GitHub repository was created this morning.

I didn't want to do that. I wanted to build something *modern*. I wanted to do "NetDevOps."

So I set out to build a fully containerized, automated network observability stack. The goal: prove I could handle the intersection of software development and network engineering — and maybe, just maybe, convince myself that my goal of becoming a real Network Engineer wasn't just a pipe dream fueled by too much caffeine and twelve years of watching other people's actual problems get solved while I answered tickets.

What I built was technically impressive. The real breakthrough, though, wasn't the code. It was the existential crisis it caused — which ultimately gave birth to the Sovereign Lab.

Here's the story of how I built a pristine software sandbox and then immediately set it on fire.

## 🧪 The Proof of Concept: Building the Sandbox

The plan was solid. I was going to use a localized Linux host to run a decoupled stack that handled everything from a definitive Source of Truth to custom API scripting and real-time observability.

Here's what it looked like:

- **The Foundation:** Linux and systemd to keep my background processes alive. (Relying on `nohup` commands is no way to live your life.)
- **The Environment:** Docker and Docker Compose for containerized, reproducible everything. I wanted a system I could rebuild from scratch, not a fragile house of cards that collapsed if I sneezed near the terminal.
- **The Brain:** NetBox, acting as my Network Source of Truth (NSoT) — the canonical record for IP addresses and device metadata.
- **The Glue:** Python 3.12, armed with `python-dotenv` so I wasn't accidentally pushing hardcoded API tokens to a public GitHub repo like a rookie. (Asking for a friend.)
- **The Pretty Colors:** InfluxDB for time-series data storage and Grafana to translate raw metrics into beautiful, real-time dashboards with the energy of a Las Vegas slot machine.

## 📚 Making the Network+ Flashcards Real

It was a beast of a project — but it was also the exact moment my CompTIA Network+ studies stopped feeling like homework and started feeling like architecture. While I was taking the course, I was building the stack, and piece by piece, the abstract concepts started clicking together like LEGO bricks.

Take NetBox. The Net+ material spends a lot of time on subnetting, CIDR notation, and IPAM — IP Address Management — which is exactly as riveting to read about as it sounds. But when I stood up the NetBox container, I couldn't just *memorize* it. I had to *design* it. I was carving out subnets, assigning IPs to simulated devices, and defining the boundaries of my network. Suddenly, CIDR notation wasn't a math problem on a flashcard; it was the architectural blueprint of everything I was building.

Then came the pollers. I built a custom Python "Device Manager" to simulate bringing network devices up and down. While the Net+ course was teaching me about ICMP and network availability, writing the actual scripts to *measure* those states gave the theory immediate, practical weight. You don't forget what ICMP does when you've written the code that depends on it.

Finally, there was the database side — InfluxDB and Grafana. Structuring time-series data with the right tags and fields meant deeply understanding what metrics actually *mattered*. The Net+ exam talks endlessly about latency, jitter, and performance. Designing the database schemas and building out the Grafana dashboards forced me to operationalize those exact concepts in real time. I wasn't just reading about network health anymore — I was engineering the system that monitored it.

## 🤖 The AI Crutch and the Creeping Imposter Syndrome

I'm going to be completely honest: in the early stages, I leaned *hard* on AI. Basically burned through my entire token budget for the month in two weeks.

When you're staring at a blank Python file and an LLM can spit out the API integration in four seconds, the temptation is overwhelming. For a while, I was full-on "vibe coding" — feeding prompts into an AI and watching it assemble my scripts like a bored contractor who'd stopped caring about your feelings somewhere around hour two.

And it *worked*. I had a functioning pipeline. My Python scripts were talking to NetBox, metrics were flowing into InfluxDB, and Grafana was lighting up like a Christmas tree with simulated latency and device health statuses.

But as I sat there staring at my beautiful "single pane of glass," a creeping dissatisfaction set in.

I looked at the simulated 1.5ms latency. I looked at the AI-written Python scripts. And I had a sobering, slightly embarrassing realization:

*I was basically playing Network Engineer dress-up.*

Fundamentally, what I had built was no different from the Packet Tracer copy-paste jobs I'd set out to avoid. Sure, my environment was containerized and talked to real APIs — but it was still a completely sanitized software simulation. The network wasn't doing anything *real*. I was a fraud in a Docker container, admiring a dashboard that meant nothing.

Twelve years of help desk had trained me to patch the surface symptom and close the ticket. I had just done the same thing to my own portfolio — wrapped a slick UI around a hollow interior and called it engineering.

## 🔥 The Breaking Point (and the Pivot)

I didn't want to be someone who knew how to write a good AI prompt inside a carefully controlled bubble. I wanted to understand the physical constraints of memory and storage. I wanted to wrestle with the Linux kernel directly. I wanted to know the actual mechanics of operating a datacenter environment — not simulate them from the comfort of a Docker network.

That realization was the death knell for the NetDevOps project.

The weird part? It was also the moment my imposter syndrome quietly evaporated. Recognizing the *limitations* of what I'd built meant I actually understood the engineering principles well enough to know what was *missing*. You can't identify a gap if you don't understand the space it's supposed to fill.

I didn't just need software. I needed iron.

So I closed the Docker Compose file for the last time, walked into the other room, found an old dusty machine that had been collecting regret in the corner, and decided to do it the hard way. No more simulated traffic. No more entirely AI-generated environments. I was going to build a true, bare-metal home datacenter from the ground up — and I was going to understand every layer of what I built.

## 🛰️ Moving Forward

The NetDevOps project wasn't a failure — it was a mandatory stepping stone. It proved I could grasp the high-level concepts: telemetry, containers, NSoT, APIs, data normalization, time-series queries. It taught me how to build a system that *looks* like it works.

But acknowledging its limitations gave me the confidence to dive into the deep end. It gave me the validation I needed to aggressively pursue my CompTIA Network+ certification, knowing I wasn't just memorizing definitions — I was learning the theory behind systems I was *actually building*.

The simulated dashboards are gone. In their place is the **Sovereign Lab** — real, physical infrastructure running on bare metal, behaving exactly the way real hardware does: unpredictably, occasionally infuriatingly, and always honestly.

The contrast is immediate. Instead of watching numbers politely do what I told them to, I'm debugging actual VLAN tags in my core router. I'm tracing why Tailscale suddenly blocked outbound access for new services — a headache that eventually forced me to stand up my own internal DNS server just to restore basic connectivity. I'm reading real routing tables, untangling real DNS failures, and learning what "fixing a network issue" actually costs when the network doesn't care about your feelings.

Fixing a real routing problem on a physical machine — even if it takes hours of staring at logs at 2:00 AM — feels infinitely better than watching a simulated dashboard turn green on cue.

The Docker container was safe. The terminal is real.

See you there.

*Eric Rivera*
*Sovereign Lab Architect (in training)*
