# Moving Beyond the Handshake: Why I Finally Switched to Native Linux

There’s a specific kind of frustration that only a help desk tech truly understands. It’s that moment when you’ve been fighting a "handshake" for two hours, only to realize a single character was out of place.

Today was a day of those moments, but it ended with something I’ve wanted for a long time: a lab that manages itself.

### The Shift to Leviathan

For a while, I’ve been running my lab management through WSL. It worked, but it always felt like I was looking at the Linux world through a window. Today, I broke the glass. I migrated my primary workstation to a native Ubuntu install on a machine I've named **Leviathan**.

The transition wasn't just about changing an OS; it was about standardizing how I interact with my network. We (my mentor and I) moved everything over to Ed25519 keys. If you’re still using passwords for your internal SSH traffic, do yourself a favor: spend the afternoon setting up key-based auth. It turns "log in, type password, typo, try again" into a seamless `ssh ops`.

### The "Sovereign" Automation

The highlight of the day was building an automated backup pipeline for my Core-Router. I’ve realized that as a sysadmin—even a "junior" one in my own lab—my memory is my weakest link. If I change a routing table at 2:00 AM and break the internet, I need a way back.

We built a Bash script that:

1. Reaches into the router (out-of-band via the Proxmox host).
    
2. Grabs the configuration.
    
3. Timestamps it.
    
4. Pushes it to a public GitHub repository.
    

By scheduling this with `cron` (running on UTC, because I’ve learned my lesson about timezone-shifting logs), I now have a version-controlled history of my network.

### Learning in Public

The most important part of today wasn't the code or the keys. It was the mindset. It’s easy to just "fix" things until they work. It’s much harder to slow down, document the process in Obsidian, and build a system that prevents the problem from happening again.

I’m currently diving into Chapter 1 of _Practical Linux System Administration_. If today was any indication, the "Sysadmin Mindset" isn't about knowing every command—it's about building a lab that respects the "Gold Master Rule" and protects you from your own mistakes.

Next up: The Filesystem. Wish me luck.

_Eric Rivera_ _Sovereign Lab Architect (in training)_