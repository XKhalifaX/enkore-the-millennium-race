# [Working Title] — Vision Document

> Status: **Draft v0.1** — living document, iterated agile-style. Nothing here is locked.
> Owner: (you) · Assistant: Claude · Last updated: 2026-07-31

---

## 1. One-line pitch (the "GIF test")

**A stylish roguelike combat racer where a crew of cool outlaws bond with living machines to tear apart the city — and the cops — one chaotic run at a time.**

If you can't picture the GIF from that sentence, the sentence is wrong. Iterate the sentence until the hook is obvious in 5 seconds.

---

## 2. Vision statement (north star)

A neon, high-style **combat racer** with the *character-bonded-to-vehicle* soul of Twisted Metal — but flipped from **grunge to cool**. Think **Jet Set Radio / Bomb Rush Cyberfunk / Crazy Taxi** attitude and **Jujutsu Kaisen**-grade characters: memorable silhouettes, signature abilities, swagger. Wrapped around that identity is a **run-based roguelike of destruction**: every run you pick a character, draft upgrades that warp their signature power into something broken, and cause spectacular, clippable carnage. Easy to grasp in ten seconds, deep to master over a hundred hours, and a highlight reel every single run.

---

## 3. Design pillars

1. **Rule of Cool, not Rule of Grim.** Style is the identity. Neon, cel-shaded, defiant, youthful. Anti-authority swagger, never nihilistic grime. If a design choice isn't *cool*, it's wrong.
2. **Character = Build.** Each racer is Driver + Vehicle + Signature Ability. The character you pick is the seed of your roguelike build. Memorable cast and deep replayability are the *same system*.
3. **Destruction is the objective, not the garnish.** Win conditions are built out of carnage, not in spite of it. (The mistake Rogue Shift made — it demoted destruction to a side effect of normal races.)
4. **The clip is the product.** Every run should produce a moment worth sharing. The hook must transmit to someone *watching*, not just playing.

---

## 4. Identity & tone

- **Aesthetic lane:** cel-shaded / stylized cyberpunk. Neon-soaked, saturated, high-contrast. Readable at speed.
- **Reference cocktail:** Jet Set Radio (cool rebellion vs. authority) + Crazy Taxi (arcade pick-up-and-play energy) + JJK (character coolness via signature techniques) + Twisted Metal (character-vehicle bond) + Wreckfest/BeamNG (destruction spectacle).
- **Emotional target:** "I feel *cool* playing this." Aspirational, not edgy.
- **The antagonist frame:** an authority to defy — cops / corporate / a controlling city. Gives the crew something to rebel *against* with style.
- **What we are NOT:** brown Mad Max wasteland, grimdark, nihilistic, "realistic." Those are taken and they're beige.

---

## 4b. Setting & framing (scope-controlled)

- **One place: a gigantic arena.** The entire game lives inside a single massive arena — **"The Millennium Tournament."** No open world, no track list. This is a deliberate scope decision: one hero environment we can make *great*, instead of many mediocre ones. (Interior variety — zones/sections of the arena — comes later if needed.)
- **The host / overlord:** a master-of-ceremonies figure who runs the tournament — Calypso-flavored (Twisted Metal) in *function*, but **explicitly not a copy**. Placeholder / **[PIN — to be redesigned]** for now: he needs his own identity, look, and hook so he's not derivative. His job: give the tournament a face, a voice, stakes, and a reason the crews show up.
- **Framing payoff:** a tournament inside one arena naturally justifies (a) roguelike runs = tournament brackets/rounds, (b) a recurring cast of rivals, and (c) an authority to defy — all without building a world.

---

## 5. The cast concept (Character = Build)

- Each **character** is a fully-realized identity: name, look, personality, and a **Signature Ability** (their "cursed technique") that defines a playstyle.
- The Signature Ability is the **seed of the roguelike run** — upgrades drafted mid-run amplify, mutate, and combine *with* that signature to reach broken, hilarious extremes.
- Distinct silhouettes and signature moves = memorable *and* mechanically meaningful. No two characters play the same.
- (Open: how many characters for MVP? Likely 1–2 to prove the system, then expand.)

### The "Ready Player One race" opponent model

The field is deliberately two-tier — this is both a **design principle** and a **scope lever**:

- **The bot pack** — a mass of faceless, weightless AI racers (the NASCAR-filler). Cheap to make, they create spectacle, density, and a sense of a crowded race. They are *scenery with wheels*.
- **The weighted rivals** — a *few* distinct **character** racers who carry real presence and threat (the Akira bike, the DeLorean, the monster-truck guy from the RPO race). When a rival is on screen, you feel it. They have identity, a signature ability, personality, and they're genuinely dangerous.

**Rule:** if the game is built on character, named rivals must arrive *with weight* — telegraphed entrances, distinct silhouettes, unique threat behavior, screen presence. Never let a character rival read as "just a faster bot."

**Double-duty efficiency:** every authored rival should also be an **unlockable playable character.** One art/design investment serves two roles (fought against, then played as). This is how a small team gets a "big cast" feel from a handful of characters — author ~3–5 rivals, and that *is* your roster.

---

## 6. Core loop

**Run structure (roguelike):**
1. Pick a character (playstyle seed).
2. Enter a run: a sequence of chaotic events/races.
3. Between events, **draft upgrades** that warp your signature ability and build toward synergy.
4. Destruction-based objectives escalate; builds spiral out of control.
5. Run ends (win or wreck) → **meta-progression** unlocks (new characters, upgrades, cosmetics) → run again.

**Moment-to-moment:** drive fast, cause carnage, trigger your signature, chain destruction, survive/dominate. Instantly graspable controls; low friction to fun (the opposite of Screamer's high skill floor).

### The power curve (start weak → earn broken)

The core of the fun is the **escalation arc** (the Vampire Survivors shape):

- **At the start of a run you are NOT special.** You're as weak and as breakable as every other racer on the grid — equal footing, no head start. Destruction can happen *to* you.
- **Power is earned, not given.** Only by stacking a good run — drafting synergistic upgrades on top of your signature — do you snowball into the destruction powerhouse who wrecks the field.
- The **"busted build" is the payoff**, not the baseline. This is what makes the run worth playing and the highlight worth clipping.
- Implication: the damage model is **two-way** — early runs are about *survival and finesse*, late runs about *domination and carnage*.

---

## 7. Design commandments (hard-won from market research)

These are guardrails derived from why comparable games underperformed. Break them only with a very good reason.

1. **Upgrades must change how you play, not just tune a number.** (Rogue Shift died on +stat% perks.)
2. **Never gate the fun.** The best moments are available in minute one. (Screamer locked destruction behind 3 hours.)
3. **Do NOT build an expensive voiced story campaign.** Racing audiences don't buy racers for plot; it's the worst ROI. Let the *run* be the story. (Screamer's costliest asset was its weakest.)
4. **Keep friction near zero.** Grasp in 10 seconds, master in 100 hours. Novelty with a steep skill wall gates your own audience.
5. **Price to the market: ~$15–25, not $60.** Deep indie roguelikes win at indie prices.
6. **The hook must be clippable.** If the magic is invisible to a viewer, it won't spread. Destruction *is* the clip — lean on it.
7. **Commit hard to a loud, specific identity.** Beige is death. (Rogue Shift's generic Mad Max look = invisible.)
8. **Scope the spectacle to run flawless.** A smaller destruction system that never stutters beats a grand one that chokes on the big boom. (Rogue Shift stuttered on its own explosions.)

---

## 8. Market positioning

- **Genre:** roguelike combat/destruction racer — an underserved intersection with proven demand on both sides (roguelikes are peak-hot; destruction sells via Wreckfest/BeamNG).
- **We do NOT compete on:** physics fidelity (Wreckfest 2), production budget (Screamer/Milestone), or content volume (AAA).
- **We DO compete on:** identity, build depth, low friction, clippability, price — all *design/art* advantages, cheap for a small team, and exactly what the comparable titles neglected.
- **Audience:** roguelike players + arcade-racing/destruction fans + the stylish-cyberpunk (Jet Set Radio / cel-shaded anime) crowd. Streamable-first.

---

## 9. Scope philosophy (agile / devops)

- Built in **iteration loops**: prototype the smallest playable slice, playtest, refine until *fun*, then expand.
- **Vertical slice / MVP first:** ONE character, ONE signature ability, a small pool of synergistic upgrades, ONE arena, destruction-based objective, a basic run loop. Prove the fun is real before scaling content.
- "Fun for me first" is a real requirement, not a slogan — if the loop isn't fun for the developer to replay, it ships to no one.
- Engine: Godot 4.6 (C# + GDScript), Jolt Physics. Reuse the existing simcade vehicle rig, re-tuned toward arcade feel.

---

## 10. Open decisions (to resolve as we iterate)

- **Working title.** (Current project name "Meridian Valley" is a leftover from the old direction.)
- **The overlord/host** — needs an original identity (not a Calypso copy). **[PINNED]**
- **Number of MVP characters** (recommend 1–2).
- **Run length target** (a satisfying run = ? minutes).
- **Per-round objective designs** beyond race/destruction — the "whatever" of round 3. **[PINNED — design later]**

### Resolved

- **Setting:** single gigantic arena — "The Millennium Tournament." No open world / no track list. *(Scope-controlled.)*
- **Opponents:** rival **AI racers** — two-tier: a weightless **bot pack** + a few **weighted character rivals** (the Ready Player One model). Rivals double as unlockable playable characters.
- **Power/damage model:** **two-way**, with an **earned power curve** — you start as weak as everyone else; destruction dominance is earned through a good run, not given at the start. (See §6 Power Curve.)
- **Win condition — phase-based tournament:** each round is a different *"driving + a goal"* objective (Round 1 = race, Round 2 = destruction, Round 3 = variant, etc.). The multi-phase structure is the vision. **[PINNED]** — **MVP iteration 1 is a single straight race**; the phase variety is layered on in later iterations.

---

## Appendix: reference case studies (why these choices)

- **Carmageddon: Rogue Shift** (2026, Mixed, 62%): right genre thesis, botched by shallow +stat% upgrades, amputated destruction win-conditions, generic Mad Max identity, stuttering explosions. → Commandments 1, 3(destruction), 7, 8.
- **Screamer** (2026, Milestone/Plaion, ~$60, Very Positive but only ~970 reviews): quality ≠ reach. Sank on AAA price into a niche, high control-friction, expensive-but-weak story, gated fun, invisible-in-a-clip hook. → Commandments 2, 3, 4, 5, 6.
- **Wreckfest 2 / BeamNG:** proof that destruction + physics spectacle sells durably and clips itself.
- **art of rally:** proof a near-solo dev wins on identity and feel, not content volume.
- **Vampire Survivors / Megabonk:** proof that "grasp in 10s, master in 100h" + synergistic build depth = viral roguelike.
