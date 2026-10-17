# HOS-EGG-002 stage 3 edit-mode dry run (17 Oct, before the playtest)
Real MatchLogic + a fresh clone of EggService, 4 bot Runners + the starting Catcher, driven through 3 crossings by hand
(EggService._watch / _onCrossing, no playtest). Result: 18 / 18.

ok   two jukes count, the third doesn't (charge 0.5)
ok   a revive adds 0.5
ok   crossing 1: Common -> Rare always (level 3)
ok   charge resets after the roll
ok   the Hero who got across alone rolls at charge 1.0
ok   a Runner already safe gains no charge
ok   a catch is pending while the Runner is down
ok   a revive cancels the snatch (Q4)
ok   the conversion makes the snatch final
ok   the caught Runner's held egg is recorded for their cap
ok   a new crossing resets charge and the juke count
ok   a timed-out Runner turns Catcher holding a recorded egg (Q2)
ok   the +1 cap: a Catcher who held Common snatches an Epic as Rare
ok   a survivor gets a shard of the egg they hold
ok   a caught Runner with no snatch gets no shard
ok   a timed-out Runner with no snatch gets no shard
ok   a converted Catcher gets their best snatch
ok   the starting Catcher gets their best snatch
settlements: { 1: no shard, 2: no shard, 3: rare, 4: rare (survivor), 100: common }; no material / bonus pieces sent
