# **Confessions of a Fake Network Engineer: How I Built a NetDevOps Lab, Hated It, and Pivoted to Bare Metal**

If you spend enough time looking at IT and Network Engineering portfolios, you start to see a pattern. It’s the classic "Right of Passage" project: someone fires up Cisco Packet Tracer or Modeling Labs, copy-pastes some standard OSPF or BGP configurations into a simulated router, and calls it a day.

I didn't want to do that. I wanted to build something *modern*. I wanted to do "NetDevOps."

So, I set out to build a fully containerized, automated network observability stack. The goal was to prove I could handle the intersection of software development and network engineering—and maybe, just maybe, convince myself that my goal of becoming a real Network Engineer wasn't just a pipe dream fueled by too much caffeine.

What I ended up building was technically impressive. But the real breakthrough wasn't the code; it was the existential crisis it caused, which ultimately led to the birth of the Sovereign Lab.

Here’s the story of how I built a pristine software sandbox—and then immediately tore it down.

## **The Proof of Concept: Building the Sandbox**

The plan was solid. I was going to use a localized Linux host to run a decoupled stack that handled everything from a definitive Source of Truth to custom API scripting and real-time observability.

Here is what the stack looked like:

* **The Foundation:** Linux and systemd to keep my background processes running (because relying on nohup commands is no way to live).  
* **The Environment:** Docker and Docker Compose to containerize everything. I wanted reproducible environments, not a fragile house of cards.  
* **The Brain:** NetBox, acting as my Network Source of Truth (NSoT) to track IP addresses and device metadata.  
* **The Glue:** Python 3.12, armed with python-dotenv so I wasn't accidentally uploading hardcoded API tokens to GitHub like a rookie.  
* **The Pretty Colors:** InfluxDB for time-series data storage and Grafana to translate all those raw metrics into beautiful, real-time dashboards.

## **Making the Network+ Flashcards Real**

It was a beast of a project, but it was also the exact moment my CompTIA Network+ studies transformed from dry theory into actual practice. While I was taking the course, I was building this stack, and step-by-step, the abstract concepts started to click together like Lego bricks.

Take NetBox, for example. In the Net+ material, you spend hours memorizing subnetting, CIDR notation, and the overarching concept of IPAM (IP Address Management). But when I stood up the NetBox container, I couldn't just memorize it—I had to *design* it. I was carving out subnets, assigning IPs to specific simulated devices, and defining the boundaries of my network. Suddenly, CIDR notation wasn't just a math problem on a flashcard to pass an exam; it was the architectural blueprint of my entire lab.

Then came the pollers. I had to figure out how to poll the NetBox APIs, parse the JSON payloads, and normalize the data so my systems knew what to monitor. I built a custom Python "Device Manager" to simulate bringing network devices up and down. While the Net+ course was teaching me about ICMP, network availability, and baseline metrics, writing the actual Python scripts to programmatically measure and log these states gave those concepts immediate, practical weight.

Finally, there was the database engineering with InfluxDB and Grafana. Structuring time-series data with the right tags and fields meant I had to deeply understand what metrics actually mattered. The Net+ exam objectives talk endlessly about latency, jitter, and network performance. Building out the database schemas and Grafana dashboards allowed me to visualize those exact metrics in real-time. I wasn't just reading about network health anymore; I was engineering the system that monitored it.

## **The AI Crutch and the Creeping Imposter Syndrome**

I’m going to be completely honest here: in the early stages of putting all this together, I leaned *hard* on AI. Basically blew out my whole token budget for the month in the two weeks I worked on this project.

When you're staring at a blank Python file, and you know an LLM can spit out the API integration in four seconds, the temptation is overwhelming. For a while, I was basically "vibe coding"—feeding prompts into an AI and watching it build out my scripts.

And it worked\! I had a functioning pipeline. My Python scripts were talking to NetBox, dumping metrics into InfluxDB, and Grafana was lighting up like a Christmas tree with simulated latency metrics and device health statuses.

But as I sat there looking at my beautiful "single pane of glass," a creeping sense of dissatisfaction washed over me.

I looked at the simulated 1.5ms latency, I looked at the AI-written Python scripts, and I had a sobering realization: *I was basically playing Network Engineer dress-up.*

Fundamentally, what I had done was no different than those basic Packet Tracer copy-paste jobs I had been trying to avoid. Sure, my environment was containerized and used modern APIs, but it was still a completely sanitized software simulation. I had no idea what was happening at the hardware level. I was a fraud in a Docker container.

## **The Breaking Point (and The Pivot)**

I didn't want to just be someone who knew how to write a good AI prompt to deploy a script in a simulated bubble. I wanted to understand the physical constraints of memory and storage. I wanted to wrestle with the Linux kernel. I wanted to know the actual mechanics of operating a datacenter environment.

That realization was the death knell for my NetDevOps project.

But weirdly, it was also the exact moment my imposter syndrome evaporated. Recognizing the limitations of my own project meant I actually understood the engineering principles enough to know what was *missing*.

I didn't just need software. I needed iron.

So, I officially ended the NetDevOps simulation. I went into my house, found an old, dusty computer I had lying around, and decided to do it the hard way. No more purely simulated network traffic. No more entirely AI-generated environments. I was going to build a true, bare-metal datacenter from the ground up.

## **Moving Forward**

The NetDevOps project wasn't a failure; it was a mandatory stepping stone. It proved to me that I could grasp the high-level concepts of telemetry, containers, NSoT, and APIs. It taught me how to normalize data and write complex database queries.

But acknowledging its limitations gave me the confidence to dive into the deep end. It gave me the validation I needed to aggressively pursue my CompTIA Network+ certification, knowing I wasn't just memorizing definitions, but learning the theory behind the actual systems I was building.

The simulated dashboards are gone. In their place is the **Sovereign Lab**—a real, physical infrastructure project running on bare metal.

Already, the contrast is staggering. Instead of just watching numbers on a simulated graph artificially go up and down, I'm dealing with actual, unpredictable network behavior. I'm actively troubleshooting VLAN tags in my core router. I'm tearing my hair out trying to figure out why Tailscale suddenly started blocking outbound access for new services—a headache that ultimately forced me to stand up and configure my own internal DNS server just to restore connectivity.

I'm verifying routing tables, untangling DNS resolution, and operating in real environments. And let me tell you, fixing a real routing issue on a physical machine—even if it takes hours of staring at logs—feels infinitely better than watching a simulated dashboard perfectly turn green.