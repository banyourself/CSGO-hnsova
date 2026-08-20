# hnsova

Hide and Seek for CS:GO, with a second gamemode called **OVA** (One Versus All) built on top
of it.

This is a fork of ceLoFaN's original hidenseek plugin. It grew a lot: **2,422 lines upstream,
4,223 here**, with about 2,600 lines added and 780 removed.

## Install

Drop the `addons` folder into your `csgo` folder:

```
addons/sourcemod/plugins/hnsova.smx                       the compiled plugin
addons/sourcemod/scripting/hnsova.sp                      source
addons/sourcemod/translations/hidenseek.phrases.txt       required
```

Discord leaderboards need the **REST in Pawn** extension and a webhook. Everything else works
out of the box.

## The two gamemodes

**HNS** is the normal one. CTs are seekers with knives only, Ts hide, there is a countdown at
round start where CTs are frozen, and the round ends when the timer runs out or everyone is
found.

**OVA (One Versus All)** is mine. Exactly one player is T, everyone else is CT, and the CT who
stabs the T **takes the role on the spot, where they stand**. You are not scored on winning
the round, you are scored on how long you managed to hold T. Rounds run ten minutes on their
own clock, so the game never really ends, it just keeps changing hands.

The handover is the whole feel of it: no teleport, no respawn, the killer just becomes the
hunted instantly. That took more work than it sounds. `CS_SwitchTeam` moves a player without
killing them, which keeps it seamless, but it leaves the old team's model on them, so the
model has to be refreshed by hand at every switch point.

Switch modes with `ova_gamemode`, or let players vote.

## What I added

**The OVA gamemode**, 26 new convars worth. T drafting, in-place role handover, a short
immunity window after taking the role so a second CT standing nearby cannot instantly take it
back, per-player time-held tracking, and a stats database with a Discord leaderboard.

**Stab through teammates.** Friendly fire is off, so the engine's knife trace stops at the
first solid entity, which means a teammate standing in the lane silently eats a swing meant
for the enemy behind them. This re-traces with teammates transparent and applies the same
damage the engine had already worked out.

This one has to be done in exactly the right place. The re-trace runs inside `TraceAttack`,
which the engine calls between `StartLagCompensation` and `FinishLagCompensation`, so every
other player is still rewound to where the attacker actually saw them. Doing it from a timer
or a post-frame hook would read present-time positions instead, which is wrong and unfair.

**A slow-stab fix.** The stab rewrite is server side only, so the client predicts a primary
swing gated at about 0.4s while the server executes a secondary stab gated at about 1.0s.
Clicks landing in that gap were silently eaten, and the window got worse with ping. Mirroring
the stab timer onto the primary timer means the client and the server gate on the same value.

**A cosmetic loadout.** `!hns` lets players pick a gun and pistol per team. They are given on
spawn and stripped of ammo immediately, so they are purely for looks. Nobody can shoot, and
guns can never be picked up off the ground because drops are blocked and ownerless gun
entities get deleted.

**HUD hiding**, a money panel fix, and various round-clock work so OVA's ten minute rounds
actually display correctly instead of counting down the old 2:30.

## What I removed

The respawn system: `hns_respawn_mode`, respawn points saved and loaded from file, respawn
invisibility, and the points and bonus multiplier system. None of it fit how my servers play,
and OVA has its own scoring.

## Plays nicely with

hnsova hands the round over to other plugins instead of fighting them:

* **hnsmix** owns the teams, rounds and spawns during a mix, so OVA stands down for the whole
  match and comes back afterwards if it was on before
* **KevFJ** owns the round clock during a funjump session, so OVA stops re-pinning its own ten
  minutes over the top

Both of those took real debugging. OVA used to draft a T, force teams and re-pin the round
cvars straight through an active funjump session, which cut a 30 minute session down to a
couple of minutes.

## Commands

```
!ova         toggle menu for admins, command list for everyone else
!ovahelp     always the command list
!hns         cosmetic loadout menu
!ovatop      OVA leaderboard
```

## Credits

Original **hidenseek** plugin by **ceLoFaN** ([github.com/ceLoFaN](https://github.com/ceLoFaN)),
published on AlliedModders.

The OVA gamemode, stab-through-teammates, the cosmetic loadout and the Discord leaderboard are
mine. Discord and HTTP work goes through **REST in Pawn**.

## License

GPL-3.0, see `LICENSE`.
