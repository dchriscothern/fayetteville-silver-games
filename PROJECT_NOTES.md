# Fayetteville Girls Silver — Games Hub: Project Notes

Repo: `dchriscothern/fayetteville-silver-games` · Live: https://dchriscothern.github.io/fayetteville-silver-games/

This file is a working handoff doc, not a one-time writeup — update it whenever the
architecture or the WIDE play family changes, the same way you'd update a README.

## What this is

A set of 9 standalone browser games for an 11-year-old girls basketball team, played
through a hub page (`index.html`). Eight are decision-training scenario games
(Advantage Hunter, Rotation Rescue, Beat the Closeout, Last 90 Seconds, Spacing
Detective, Post Player Power, Shot Medal Challenge, Shooting Form). The ninth,
`wide_base.html`, is a different kind of thing: a full baseline-out-of-bounds play
family with six variations and three ways to study each one.

## Architecture (read this before editing any game file)

- Each game is **one self-contained `.html` file** — inline `<style>` and
  `<script>`, no external JS. Every file is ~200–245KB because the same large
  base64-encoded face images (`FACES`, in `assets/faces_b64.json` conceptually,
  inlined per file) are duplicated into each one.
- **These files are too large to edit with a normal text-editor patch tool.** The
  base64 image data lives on a handful of single lines each 50,000+ characters
  long, which breaks "read then edit" tools that need the whole file in one piece.
  The reliable way to edit any of these nine files: write a small Python script
  that opens the file with `encoding="utf-8"`, does an exact-string
  `assert old in content` check, then `content.replace(old, new)`, then writes it
  back. Don't try to open and edit the whole file directly.
- Games report back to the hub via
  `window.postMessage({source:"silver-games", type:"summary"|"ready", gameId, mode, tally, rounds}, "*")`.
  `rounds` is the actual number of scenarios/questions completed — added so the
  hub doesn't have to guess it from the tally object (see "Fixes this session"
  below for why that mattered).
- My Progress has a "How we keep your daughter's information safe" card, shown
  signed in or out. If what gets stored changes (new columns, analytics, any
  external script), update that card so it stays true.
- The hub only saves a score to Supabase when a parent is signed in **and** has a
  player selected; otherwise it shows a "played offline" toast and nothing is lost
  except the save.
- Every game has a `<a href="index.html" target="_top" class="back-link">` as the
  first element inside `<header>`, laid out in normal flow (not absolutely
  positioned — that collided with the team-label text at narrow widths in the
  games whose header font hasn't been shrunk). If a 10th game gets added, copy
  this same `<header>` opening and the `.back-link` CSS rule from any existing
  game file.

## WIDE (`wide_base.html`) — the play family

Six plays, picked from a play-picker screen, each with three modes:
**Watch the Play** (auto-plays through, Pause / Slow Motion available),
**Know Your Position** (pick your own jersey number, get stopped and asked about
just your job), **Read the Defense** (you make the inbounder's read yourself).

Court convention: `BLOCK_R`/`BLOCK_L` are near the basket (top of the lane, small
y). `ELBOW_L` is at the free-throw line (bottom of the lane, larger y). This is
easy to get backwards — it was a real, repeated bug during development.

**Timing rule (coach's call, reflected in all narration and quiz text):** in WIDE
and WIDE SLIP (and their vs Defense versions), nobody waits after the ball smack.
5 and 4 move immediately and 5 rolls quickly to the bucket after the screen,
because the inbounder only has five seconds. In WIDE UP and WIDE UNDER there is
no smack: everyone stays still, and 5 gets big only when the ref hands 3 the
ball, never before, so the defense has no time to adjust. The animations were
left as they were; only the words say this.

**WIDE** (the base call): 3 inbounds on the baseline. 5 starts near the inbounder
(ball-side block), 4 at the opposite elbow. 5 sprints across and sets a screen
next to 4. 4 works her defender right away, then cuts off the screen to the near
block (first read). 5 rolls hard in a straight line to the far block
(second read, usually the most open). 1 and 2 are corner safety outlets. Final
read order: 4, then 5, then a safety pass or a lob — never a forced pass at a
defender.

**WIDE vs Defense**: same play, but with two actual defenders on the floor
(labeled `X4` and `X5` — see "two defenders" gotcha below). 5's screen lands
directly on the defender guarding 4, not on her own defender. 4 cuts off that
contact to the near block while her defender is stuck on the pick. 5's own
defender — who started right next to the block 4 is now cutting to — rotates
over to help, which is exactly why 5 is wide open once she finishes rolling to
the far block. This is the only WIDE variant where Read the Defense is reading
actual defender positions each phase instead of narration text alone.

**WIDE UP**: trigger is a size mismatch — 5's defender is smaller. 5 posts up
strong and high, 3 reads it and throws a lob (not a bounce pass, which just
gives a smaller defender something to reach for).

**WIDE UNDER**: trigger is a defender badly positioned (on the outside, away
from the basket). 3 reads it and delivers a quick, low bounce pass through the
lane before the defense can recover — a lob would be the wrong tool here (that's
the WIDE UP answer, not this one).

**WIDE SLIP**: 5 starts the same trip as the base screen, but stops at the
middle of the lane and cuts away to the far block instead of completing the
screen — never making contact, never getting defended there.

**WIDE SLIP vs Defense**: same slip, but now both defenders are shown cheating
toward a switch early (anticipating the screen that never lands), leaving
nobody within reach of 5 once she bails and cuts to the far block alone.

### Technical gotchas specific to this file

- **`tweenPhase()` matches players between phases by `label`.** Every
  simultaneously-visible player needs a *unique* label, or two players sharing a
  label will incorrectly tween from the same origin point. This is why the two
  defenders in the "vs Defense" plays are labeled `X4`/`X5` (who they're
  guarding), not both the hub's usual generic `"X"` — WIDE is the first game in
  the hub to put two defenders on screen at the same time.
- **Token spacing**: the court SVG is capped to `min(30vh, 300px)` on screen (for
  the one-screen-fit work this session), which shrinks the effective on-screen
  distance between tokens compared to earlier in development. Two tokens need
  roughly **45–50+ viewBox units** of separation to read as clearly distinct.
  Closer spacing (~35–40) is only OK for an intentional "contact" moment (a
  screen, a contested catch) where crowding is the point, and only when not also
  squeezed against a third token. Check new coordinates with a quick
  distance script before trusting a screenshot.
- **Answer order is randomized** (`shuffled()`) in Know Your Position and Read
  the Defense specifically because every quiz in the file originally had the
  correct answer hardcoded as the first button — fixed so a player can't just
  learn "always tap the top one."
- Watch-mode auto-advance timing (`dwellFor()`) is 150ms per word of the text on
  screen, counted from when the text appears, so the 2200ms move (`MOVE_MS`)
  already covers part of it. At a decision phase it counts the revealed answer
  text too. Tuned to "just enough to read," since Pause and Slow motion exist
  for anyone who needs longer.
- All nine games share the same one-screen layout: compact header and mode bar,
  and the court capped at `min(30vh, 300px)` (`min(48vh, 560px)` at 540px+ wide).
  The other eight get it from a "One-screen fit" CSS block at the end of their
  `<style>`, and every game hides its footer while a court is showing.

## This session's fixes to the other 8 games

- Found and fixed a real bug: the hub (`index.html`) computed each saved game's
  `scenario_count` by summing every key in the game's tally object. Seven of the
  eight games intentionally track two separate things per round (e.g. read
  quality *and* shot quality, in two separate tally keys) — summing them
  double-counted. Not visible anywhere today (nothing displays `scenario_count`
  yet), but it was wrong data going into Supabase. Fixed by having each game
  report its own real count directly (`rounds: SCENARIOS.length`) instead of the
  hub inferring it.
- Audited game length: only Advantage Hunter and Rotation Rescue actually have 10
  scenarios; the other six have 6. Confirmed the ending logic and the in-game
  summary math are correct either way — this was a deliberate choice to leave as
  is, not a bug.

## Supabase setup (parent/coach sign-in)

- Project: `https://qpykhrjggibsjklhazww.supabase.co` (the key in `index.html` is
  the public/anon key — safe to be visible client-side, it is not the secret).
- Schema already written in the repo: `supabase/schema.sql` and
  `supabase/addendum_is_admin_rpc.sql`. Run each once in the Supabase dashboard's
  SQL Editor if the tables don't exist yet (check Table Editor first — if
  `players`, `player_guardians`, `game_results`, `coach_feedback`, `admins`
  already exist, skip this).
- **Checklist to confirm the live sign-in flow actually works:**
  1. Open https://supabase.com/dashboard, select this project.
  2. **Authentication → URL Configuration**: Site URL should be
     `https://dchriscothern.github.io/fayetteville-silver-games/` and that same
     URL should also be in the Redirect URLs allow-list. Without this, the magic
     link email either won't send or will redirect somewhere wrong. This is the
     one thing most likely to silently break sign-in and can't be checked from
     the code.
  3. Open the live site in an incognito window, go to **My Progress**, enter a
     real email, click "Email me a sign-in link." Check the inbox (and spam) —
     click the link — confirm it lands back on the live site already signed in.
  4. To make yourself the coach: after signing in once with your own email (so
     `auth.users` has a row for you), run in the SQL Editor:
     `insert into public.admins (user_id) select id from auth.users where email = 'YOUR EMAIL';`
     Then reload the site and check **Coach Area** unlocks.
  5. To link a parent to her daughter (this is coach-side only, not
     self-service by design — see `schema.sql`'s comment on `player_guardians`):
     the parent must sign in once first (so her `auth.users` row exists), then
     in the SQL Editor:
     `insert into public.player_guardians (parent_user_id, player_id) select u.id, p.id from auth.users u, public.players p where u.email = 'parent@example.com' and p.player_code = 'SILVER-01';`
     If a parent reports "signed in but no player showing," this step is almost
     always why — check `player_guardians` for her row before anything else.
  6. Supabase's default email sender is shared and rate-limited — fine for
     testing, but if delivery becomes unreliable at real scale, configure a
     custom SMTP sender under Authentication → Settings.

## Open items (not done, by explicit choice or not yet asked for)

- Game length standardization (bringing the six 6-scenario games up to 10 to
  match Advantage Hunter / Rotation Rescue) — explicitly declined this session;
  revisit if that preference changes.
- Defender-included variants only exist for WIDE and WIDE SLIP. WIDE UP and WIDE
  UNDER could get their own version (an actual smaller/misplaced defender on 5,
  not a screen) if wanted later.
- The Supabase checklist above needs to actually be run through once by hand —
  nothing in this repo can verify the dashboard-side settings from code.
