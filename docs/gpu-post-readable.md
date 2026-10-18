# A 29-year-old attack got 17 times cheaper on one NVIDIA Blackwell card, and the math didn't change

Nothing anyone uses is weaker than it was last week. This post is about why that is still worth your attention.

[Read the paper on IACR ePrint](https://eprint.iacr.org/2026/2469)

In 1997, Certicom published a set of elliptic curve challenges. Here are some curves, here are some public keys, go find the private ones. Two fell quickly, in 1998 and 2000. The one called ECC2K-130 has been open ever since, and it is now the cheapest of the ones still standing.

We did not solve it. What we did was make the program that attacks it run 17.2 times faster on one NVIDIA RTX PRO 6000 Blackwell, from 0.85 to 14.64 billion steps per second, with a later build reaching 15.88. The attack itself is unchanged: same method, same number of steps expected, same answer at the end. Every bit of the gain came from rewriting how the arithmetic is stored and scheduled on the chip.

Two pieces of fine print, up front, because they decide what the number is worth.

The 17.2 is against our own earlier program. Nobody has published what the standard design does on a 2026 card, so what got 17 times cheaper is our own baseline, not a world record.

And none of this improves on the mathematical floor for this kind of attack. We say so in the paper, and we are not claiming otherwise.

## What that actually buys

The useful way to state the result is not a multiplier. It is how long the whole thing would now take.

| Fleet | Expected time to a solution |
|---|---|
| 1 card | about 4.3 years |
| 5 cards | about a year |
| 56 cards | about a month |
| 290 cards | about a week |
| 1,000 cards | about three days |

These estimates use 15.88 billion steps per second and include a modeled delay for the final walk to reach a distinguished point. For comparison, dividing the expected 2^60.9 steps by aggregate peak throughput alone gives about 1.57 days for 1,000 cards; the roughly three-day figure is a wall-clock model, not a simple work/rate division. At that fleet size, roughly half the quoted time is attributed to final-walk detection latency. Actual completion times are random, and the delay depends on the distinguished-point cutoff and the scheduling assumptions.

In 2010, the best published GPU implementation of this same attack ran at 0.064 billion steps per second on a GTX 295, and the whole job was reckoned at 1,066 card-years. **The audited 14.64-billion-step/s build is about 229 times as fast** (14.64/0.064 = 228.75); **the later 15.88-billion-step/s build is about 248 times as fast**. These are different comparison baselines, not interchangeable measurements.

The 229 comparison is the one we would most expect someone to challenge, so here is the split. About 6 times of it is simply a bigger, faster chip: 188 processing units at 2.4 GHz against 60 at 1.24 GHz. The remaining approximately 38 times, after that simple units-times-clock normalization, is the per-unit-time performance difference. It is not a controlled measurement that attributes all of that residual to arithmetic alone: architectural changes, scheduling, and differences in the implementations also matter. Using the later 15.88 rate would instead give approximately 41 times after the same normalization.

## The part that is actually interesting

The difficulty of this attack is set by two numbers: how many steps it needs, and how long each step takes.

The first number is the one cryptographers argue about, the one security estimates are built on, and the one that decides whether a curve is safe. We did not move it. We could not have. It is untouched, and we measured it to confirm it had not shifted.

The second number is the one nobody had looked at in sixteen years. It is set by how a chip stores numbers, which instructions it has, and how fast it can reach memory, and all of that changes with every hardware generation.

So the finding is not that a curve got weaker. It is that a historical hardware cost estimate is dramatically different on modern hardware, without requiring new mathematics.

## Everyone was optimising the wrong thing

Count the operations in a single step of this attack and multiplication dominates. So for fifteen years, implementations have treated this as a multiplication problem. We assumed the same thing when we started.

It was not. Our starting program was using about 6% of what the chip can do. The multiplier was fine. The problem was that each walk's working numbers were too big to keep in the chip's fastest storage, so they spilled into slower memory and the chip spent its time waiting rather than computing.

Sixteen changes, measured one at a time, closed that gap. Grouped by what they did:

- **Representation and arithmetic: 6.3 times.** Pack the numbers so they fit in registers. Replace a chain of repeated squarings with a fixed wiring diagram that shuffles bits in one pass. Use three-input logic instructions for everything around it.
- **Launch geometry and batch size: 1.5 times.** How many walks run together, and in what shape.
- **Memory layout: 1.3 times.** Where the working state lives and how threads reach it.
- **The native carry-less multiply: 1.2 times.** Blackwell chips have an instruction built for exactly the kind of multiplication this attack needs. It forms the core product in six instructions.

Three things we should admit about that list. We cannot attribute all of the gain: a factor of about 1.16 is left over and we say so rather than assigning it to whichever change was nearby. Three of the sixteen steps changed more than one thing at a time, so they do not isolate what we claim. And several of the step-by-step figures come from different runs on the machine, so the head-to-head comparisons carry the evidence, not the summary chart.

## What it costs, and why there are several answers

The answer to "what would it cost to break this" is a table, not a number, because the figure moves with which chip you rent, which market you rent it in, and on what day.

| What it prices | Cost | On what basis |
|---|---|---|
| Cheapest quote we saw | about $38k | An L4 in eu-north-1, 18 September 2026, at 56 trillion steps per dollar |
| An FPGA, spot | about $51k | 72,400 AWS F2 hours at $0.709/hour, 11 September, at our measured 8.25 billion steps/s |
| The card we tested, spot | about $56k | 42,400 GPU-hours at $1.31/hour, 11 September, at our campaign rate of 14.11 billion steps/s |
| The same work at published list price | about $114k | Modal list price, 19 September, at 15.88 billion steps/s |
| The card we tested, on demand | $142k to $175k | Same hours, on-demand pricing, 11 September |

These are expected *compute-only* costs at the stated rates and historical quotes, not guarantees of what a completed campaign will cost. At ideal utilization, fleet size changes elapsed time but not total GPU-hours; in practice, distinguished-point latency, interruptions, duplicated walks, coordination, and pricing can change the bill. Eight cards taking 221 days and 512 cards taking 3.4 days are illustrative work/rate calculations, not identical all-in operating costs.

The fastest card is not necessarily the cheapest card, which is why the campaign ran mixed hardware. We publish rates for twelve GPUs from Turing to Blackwell, per card, per processing unit and per dollar, and the workstation part wins on the stated throughput measures for this particular job.

All of the spot figures hold only while spot capacity does. Ours did not, which is the next-to-last section.

## The finding that travels

The native carry-less instruction issues ten to eighteen times faster on NVIDIA's data-centre chips than on the workstation chip we tested. On the card we used it costs as much time as 37.8 ordinary instructions. On a B200 it costs 3.8, and on an H100, 2.0.

That means the same change can win on one Blackwell part and lose on another. Two changes we built, measured and threw away as losses on our card are wins on a data-centre part.

One trade we priced but have not shipped makes the point cleanly. It costs 19 extra of the new instructions and saves 290 ordinary ones, so it pays off wherever the new instruction is worth less than 290/19, or about 15.3 ordinary ones. On a B200 it is worth 3.8, so the cost model predicts a win. On our card it is worth 37.8, so it predicts a loss. This is a model-based prediction, not a measured deployment of that particular trade.

This is why we publish the changes that failed alongside the ones that worked. A list of what worked tells you nothing about hardware you have not tested. We should be honest that we built the cost model first and then read the result off it, rather than writing the prediction down in advance.

## The curves people actually use

ECC2K-130 is a museum piece. Nobody deploys it. So we took the same techniques to Pollard rho on NIST P-256 and P-384, which are in essentially every browser, phone and payment terminal.

Most of the techniques transferred. The speedups were 1.52 times on P-256 and 2.61 times on P-384.

Those curves are exactly as safe as they were. P-256 needs roughly 2^67 times as many *iterations* as ECC2K-130. But iteration counts and wall-clock time are not interchangeable across different fields: the measured P-256 rate is approximately **1.632 billion iterations/s**, rather than ECC2K-130's 15.88 billion/s. Using expected work sqrt(pi*n/4) and that P-256 rate yields approximately **6 × 10^21 card-years**. A billion such cards would still need about six trillion years, more than four hundred times the age of the universe. At the separate theoretical throughput bound of 12.2 billion P-256 iterations/s, the estimate is approximately **8 × 10^20 card-years**. P-384, using its measured 0.548-billion-iteration/s rate, is around **3 × 10^41 card-years**.

The crucial distinction is that the 2^67 ratio refers to **work**, not **time**: multiplying ECC2K-130's 4.3 card-years by 2^67 would incorrectly assume equal iteration speeds. The paper's NIST estimates use curve-specific arithmetic rates.

That is the whole lesson in one comparison. The same engineering that brings one curve within a small fleet's reach does nothing at all to another, because the gap between them is in the exponent, and engineering only ever touches the constant in front of it.

## Why we think this is worth doing

Cost estimates get computed once, published, and cited for decades. The mathematics behind them is usually sound. The hardware assumptions underneath them quietly rot. And people choose key sizes and parameters against those estimates.

This is not hypothetical. Germany's federal cybersecurity agency recommended an algorithm called Classic McEliece for years and withdrew that recommendation in September 2026, after a run of results dropped its estimated attack cost below the level their own guidance requires. No deployment changed. No software was updated. The number changed.

A great deal of new cryptographic code is being written right now, on deadlines that start in 2027, much of it by teams implementing these algorithms for the first time. The distance between what a specification promises and what an implementation delivers is where the real risk sits, and almost nobody measures it.

We want to be careful about how far that goes. We have measured one attack on one obsolete curve, two deployed curves it does not threaten, and a dozen cards. We have measured no post-quantum implementation at all. Whether the same gap matters as much for the new lattice-based algorithms is an open question and we have not answered it.

Closing that measurement gap is what we built this lab to do.

## What we checked, and the number we had to withdraw

A faster program that gets a different answer is worthless, so the bar we set was that the fast version has to produce exactly the same output as the slow one. Not similar. Identical, down to the byte. A change that gained 30% and altered a single result was rejected rather than investigated. The whole pipeline is also tested on smaller versions of the same problem where we already know the answer, including one challenge from the same 1997 set that was solved in 1998 and has a published solution.

Here is the part we would rather not write, and the reason you should trust the rest.

We built a variant of the walk that measured 20.08 billion steps per second, well above anything else in the paper. Then we found that the rule it used for escaping dead-end loops was unsound. With the rule corrected, the same variant runs at 8.24, which is slower than the build we actually ship. The 20.08 is not a valid throughput result for the intended attack. It is in the paper, labelled, next to the explanation, because a reader skimming our tables would otherwise see the biggest number and draw the wrong conclusion.

That is also the clearest lesson in the work. Speed is not the thing to optimise. Cost per answer is, and the two can point in opposite directions.

## The campaign

Alongside this work we ran a distributed attack on ECC2K-130 using the new code, with clients for ordinary CPUs, NVIDIA GPUs and FPGAs. Every client's arithmetic is checked against a reference model, and any result a client reports can be independently re-run from its starting point.

It is paused rather than finished. The cloud provider reclaimed our entire fleet on 18 September when the spot market turned, the account went onto a verification hold that has blocked new machines since, and the last result landed on 7 October. At that point we had walked about 5.4% of the **unconditional expected** work with no collision found.

Finding nothing at that point is unsurprising. Under the usual Rayleigh approximation for rho collision time, reaching 5.4% of the mean corresponds to only about a **0.23%** probability of having found a collision already. Checkpoints preserve completed walks and prevent paying to repeat those same trajectories, but this is **not** equivalent to eliminating 5.4% of a fixed search space or guaranteeing a 5.4% reduction in conditional expected remaining time. That requires the collision-time distribution and the campaign's actual walk accounting. A new fleet can continue from the saved checkpoints; the work remains probabilistic.

Every number in the paper cites an evidence record. The code, the data, the evidence and a Dockerfile whose image starts the walk are at [github.com/aburan28/rho-blackwell](https://github.com/aburan28/rho-blackwell).

[Read the paper on IACR ePrint](https://eprint.iacr.org/2026/2469)
