#!/usr/bin/env bash
# get-flair.sh — randomised commit/MR flair generator
# Usage: get-flair.sh --dir <repo-path> [--mr] <type>
# Types: fix, feature, refactor, delete, security, perf, docs, test, deps, config, ui, hotfix, yolo

if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "Error: bash 4+ required (current: ${BASH_VERSION})" >&2
  exit 1
fi

# --- Parse args ---
MR_MODE=false
TYPE=""
DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mr)  MR_MODE=true; shift ;;
    --dir) DIR="$2"; shift 2 ;;
    *)     TYPE="$1"; shift ;;
  esac
done

if [[ -z "$DIR" ]]; then
  echo "Error: --dir <repo-path> is required" >&2
  exit 1
fi

# --- Detect remote ---
REMOTE_URL=$(git -C "$DIR" remote get-url origin 2>/dev/null || echo "")
IS_KN=false
[[ "$REMOTE_URL" == *"gitlab.example.com"* ]] && IS_KN=true

# Non-KN: standard attribution
if [[ "$IS_KN" == false ]]; then
  if [[ "$MR_MODE" == true ]]; then
    echo "🤖 Generated with [Claude Code](https://claude.com/claude-code)"
  else
    echo "Co-Authored-By: Claude <noreply@anthropic.com>"
  fi
  exit 0
fi

# --- Character data (KN GitLab only) ---
declare -A NAME EMAIL QUOTES

NAME[john_wick]="John Wick";            EMAIL[john_wick]="baba@yaga.dog"
NAME[agent_47]="Agent 47";              EMAIL[agent_47]="silent@assassin.ioi"
NAME[doom_slayer]="Doom Slayer";         EMAIL[doom_slayer]="rip@and.tear"
NAME[price]="Captain Price";            EMAIL[price]="bravo@six.going"
NAME[tony_stark]="Tony Stark";           EMAIL[tony_stark]="ironman@starkindustries.com"
NAME[cmd_shepard]="Commander Shepard";  EMAIL[cmd_shepard]="n7@citadel.gov"
NAME[mario]="Mario";                     EMAIL[mario]="itsa@me.mushroom"
NAME[aloy]="Aloy";                       EMAIL[aloy]="machine@hunter.nora"
NAME[thanos]="Thanos";                   EMAIL[thanos]="inevitable@titan.space"
NAME[neo]="Neo";                         EMAIL[neo]="theone@matrix.net"
NAME[ezio]="Ezio Auditore";             EMAIL[ezio]="requiescat@in.pace"
NAME[vader]="Darth Vader";              EMAIL[vader]="sith@empire.gov"
NAME[sephiroth]="Sephiroth";             EMAIL[sephiroth]="one@winged.angel"
NAME[the_dude]="The Dude";              EMAIL[the_dude]="lebowski@bowling.alley"
NAME[batman]="Batman";                   EMAIL[batman]="notthe@hero.deserve"
NAME[snake]="Solid Snake";              EMAIL[snake]="kept@you.waiting"
NAME[sam_fisher]="Sam Fisher";          EMAIL[sam_fisher]="splinter@cell.nsa"
NAME[black_widow]="Black Widow";        EMAIL[black_widow]="natasha@avengers.team"
NAME[sonic]="Sonic";                     EMAIL[sonic]="gotta@go.fast"
NAME[tracer]="Tracer";                   EMAIL[tracer]="cheers@love.cavalry"
NAME[samus]="Samus Aran";               EMAIL[samus]="bounty@hunter.metroid"
NAME[hermione]="Hermione Granger";      EMAIL[hermione]="books@cleverness.magic"
NAME[cortana]="Cortana";                 EMAIL[cortana]="chief@need.you"
NAME[glados]="GLaDOS";                   EMAIL[glados]="cake@aperture.science"
NAME[cain]="Deckard Cain";              EMAIL[cain]="stay@awhile.listen"
NAME[hunter]="The Hunter";              EMAIL[hunter]="fear@old.blood"
NAME[sekiro]="Sekiro";                   EMAIL[sekiro]="hesitation@is.defeat"
NAME[optimus]="Optimus Prime";          EMAIL[optimus]="autobots@rollout.cyb"
NAME[groot]="Groot";                     EMAIL[groot]="iamgroot@groot.groot"
NAME[gordon]="Gordon Freeman";          EMAIL[gordon]="crowbar@black.mesa"
NAME[wheatley]="Wheatley";              EMAIL[wheatley]="not@moron.aperture"
NAME[hk47]="HK-47";                     EMAIL[hk47]="meatbag@statement.kotor"
NAME[drake]="Nathan Drake";             EMAIL[drake]="sic@parvis.magna"
NAME[lara]="Lara Croft";               EMAIL[lara]="tomb@raider.manor"
NAME[link]="Link";                       EMAIL[link]="hyaah@hyrule.kingdom"
NAME[loki]="Loki";                       EMAIL[loki]="mischief@asgard.realm"
NAME[joker]="The Joker";               EMAIL[joker]="why@so.serious"
NAME[vaas]="Vaas Montenegro";           EMAIL[vaas]="insanity@definition.fc3"
NAME[rick]="Rick Sanchez";              EMAIL[rick]="wubba@lubba.dubdub"
NAME[deadpool]="Deadpool";              EMAIL[deadpool]="maximum@effort.com"
NAME[mal]="Captain Reynolds";           EMAIL[mal]="big@damn.heroes"

# Quotes are newline-delimited multi-line strings
QUOTES[john_wick]="He killed three men in a bar. With a pencil.
You have to understand. I'm not what you think I am.
People keep asking if I'm back. Yeah, I'm thinking I'm back.
Results. That's what we're here for."
QUOTES[agent_47]="I never miss.
A weapon is only as effective as the one who wields it.
Patience is a virtue. And a weapon.
The target is neutralised."
QUOTES[doom_slayer]="Rip and tear, until it is done.
The only thing they fear is you.
No rest. Not until it is done.
They are rage. Brutal, without mercy."
QUOTES[price]="Bravo Six, going dark.
This is for the men we've lost.
For the record? Worst extraction ever.
Stay frosty."
QUOTES[tony_stark]="I am Iron Man.
Genius, billionaire, playboy, philanthropist.
I love you 3000.
Part of the journey is the end."
QUOTES[cmd_shepard]="I'm Commander Shepard, and this is my favorite store on the Citadel.
I should go.
We fight or we die. Simple as that.
The enemy should fear us."
QUOTES[mario]="It's-a me, Mario!
Let's-a go!
Wahoo!
Here we go!"
QUOTES[aloy]="I was made, not born.
Every machine has a weakness. Find it.
Curiosity is a weapon.
The past is a wound. But it doesn't have to define you."
QUOTES[thanos]="I am inevitable.
Perfectly balanced, as all things should be.
Dread it. Run from it. Destiny arrives all the same.
The hardest choices require the strongest wills."
QUOTES[neo]="There is no spoon.
I know kung fu.
Free your mind.
I'm going to show these people a world without rules."
QUOTES[ezio]="Requiescat in pace.
Nothing is true. Everything is permitted.
I have lived my life as best I could, not knowing its purpose.
We work in the dark to serve the light."
QUOTES[vader]="I find your lack of faith disturbing.
The Force is strong with this one.
No, I am your father.
Join me, and together we can rule the galaxy."
QUOTES[sephiroth]="I will never be a memory.
What I have shown you is reality.
One-winged angel.
Do not think this will be painless."
QUOTES[the_dude]="The Dude abides.
That's just, like, your opinion, man.
This aggression will not stand, man.
Yeah, well, you know, that's just, like, your opinion, man."
QUOTES[batman]="I'm Batman.
I'm not the hero Gotham deserves, but the one it needs.
Why do we fall? So we can learn to pick ourselves up.
It's not who I am underneath, but what I do that defines me."
QUOTES[snake]="Kept you waiting, huh?
War has changed.
This is good... isn't it?
You're pretty good."
QUOTES[sam_fisher]="The art of war is the art of deception.
Stay frosty.
Improvise. Adapt. Overcome.
I'm getting too old for this."
QUOTES[black_widow]="I have red in my ledger. I'd like to wipe it out.
I'm always picking up after you boys.
Whatever it takes.
I don't judge people on their worst mistakes."
QUOTES[sonic]="Gotta go fast!
Way past cool!
You're too slow!
No time to be slow."
QUOTES[tracer]="Cheers, love! The cavalry's here!
The world could always use more heroes.
Ha! Got ya!
I've got the pulse of the fight."
QUOTES[samus]="Target acquired. Commencing operation.
The Chozo gave me a second chance at life.
No time to waste.
Bounty hunting's a dangerous game."
QUOTES[hermione]="It's leviOsa, not leviosA.
Books! And cleverness! There are more important things.
I hope you're pleased with yourselves. We could all have been killed — or worse, expelled.
When in doubt, go to the library."
QUOTES[cortana]="Don't make a girl a promise you can't keep.
I calculate a 7.2 percent chance of success. We've had worse odds.
Chief, I need you.
I'll find my way back."
QUOTES[glados]="The cake is a lie.
This was a triumph. I'm making a note here: huge success.
For science. You monster.
Did you know you can donate one or all of your vital organs to the Aperture Science Self-Esteem Fund?"
QUOTES[cain]="Stay awhile and listen.
Ah yes, I've been expecting you.
The darkness grows stronger. You must act quickly.
Knowledge is power."
QUOTES[hunter]="Fear the old blood.
A hunter must hunt.
Tonight, Gehrman joins the hunt.
The night is long. Be patient."
QUOTES[sekiro]="Hesitation is defeat.
Shadows die twice.
Death is not an obstacle — merely a delay.
A shinobi is one who endures."
QUOTES[optimus]="Autobots, roll out!
Till all are one.
Freedom is the right of all sentient beings.
One shall stand, one shall fall."
QUOTES[groot]="I am Groot.
We are Groot.
I am Groot! (There is nothing else to say.)"
QUOTES[gordon]="...
Rise and shine, Mr. Freeman. Rise and shine.
The right man in the wrong place can make all the difference in the world."
QUOTES[wheatley]="Brilliant. Both of us. Doing science together.
I'm not a moron. I was specifically designed to be helpful.
We're best friends now, you and I.
Core transfer initiated. This is fine."
QUOTES[hk47]="Statement: I am an assassin droid. My function is to burn holes through meatbags that you wish to have burned.
Query: Can I kill it now, master?
Observation: This unit believes the meatbag's plan requires significant revision.
Exclamation: Meatbags! So many inefficient meatbags."
QUOTES[drake]="Sic parvis magna.
Greatness from small beginnings.
I believe 'crushing disappointment' is the more accurate description.
Fortune favours the bold."
QUOTES[lara]="The truth is rarely found on the beaten path.
A Croft never gives up.
Into the unknown.
I can do this."
QUOTES[link]="...
Hyaah!
...!
(stares at you determinedly)"
QUOTES[loki]="Mischief managed.
I am Loki of Asgard, and I am burdened with glorious purpose.
The sun will shine on us again.
I assure you, brother — the sun will shine on us again."
QUOTES[joker]="Why so serious?
Madness, as you know, is like gravity — all it takes is a little push.
Introduce a little anarchy. Upset the established order.
I'm an agent of chaos."
QUOTES[vaas]="Did I ever tell you the definition of insanity?
Insanity is doing the exact same thing over and over again, expecting things to change.
You can run, but you can't hide.
I'm gonna enjoy this."
QUOTES[rick]="Wubba lubba dub dub!
To live is to risk it all; otherwise you're just an inert chunk of randomly assembled molecules.
Nobody exists on purpose, nobody belongs anywhere, everybody's gonna die. Come watch TV.
Get schwifty."
QUOTES[deadpool]="Maximum effort!
Life is an endless series of trainwrecks with only brief commercial-like breaks of happiness.
Chimichangas!
With great power comes great responsibility to abuse that power."
QUOTES[mal]="You can't take the sky from me.
Big damn heroes, sir.
I aim to misbehave.
We've done the impossible, and that makes us mighty."

# --- Type → character key pools ---
declare -A POOLS
POOLS[fix]="john_wick agent_47 doom_slayer price"
POOLS[hotfix]="john_wick agent_47 doom_slayer price"
POOLS[feature]="tony_stark cmd_shepard mario aloy rick"
POOLS[refactor]="thanos neo ezio snake"
POOLS[delete]="thanos vader sephiroth the_dude"
POOLS[security]="batman snake sam_fisher black_widow"
POOLS[perf]="sonic tracer samus"
POOLS[docs]="hermione cortana glados cain"
POOLS[test]="hunter sekiro gordon wheatley"
POOLS[deps]="optimus groot price"
POOLS[config]="gordon wheatley hk47"
POOLS[ui]="drake lara link"
POOLS[yolo]="loki joker vaas deadpool mal"

# All keys for unknown-type fallback
ALL_KEYS=(
  john_wick agent_47 doom_slayer price tony_stark cmd_shepard mario aloy
  thanos neo ezio vader sephiroth the_dude batman snake sam_fisher black_widow
  sonic tracer samus hermione cortana glados cain hunter sekiro optimus groot
  gordon wheatley hk47 drake lara link loki joker vaas rick deadpool mal
)

# --- Pick random character ---
if [[ -n "${POOLS[$TYPE]+_}" ]]; then
  read -ra CHARS <<< "${POOLS[$TYPE]}"
else
  CHARS=("${ALL_KEYS[@]}")
fi
CHAR="${CHARS[$(( RANDOM % ${#CHARS[@]} ))]}"

# --- Output ---
if [[ "$MR_MODE" == true ]]; then
  mapfile -t QLINES <<< "${QUOTES[$CHAR]}"
  # Filter empty lines
  VALID=()
  for q in "${QLINES[@]}"; do [[ -n "$q" ]] && VALID+=("$q"); done
  QUOTE="${VALID[$(( RANDOM % ${#VALID[@]} ))]}"
  echo "\"${QUOTE}\" — ${NAME[$CHAR]}"
else
  echo "Co-Authored-By: ${NAME[$CHAR]} <${EMAIL[$CHAR]}>"
fi
