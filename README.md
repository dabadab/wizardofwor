# C64 Wizard of Wor Disassembly

### About the disassembled code

This is an assembler source code for the C64 version of Wizard of Wor - however, it's _NOT_ the original source code but rather the result of a reverse engineering effort.

To read the code you should have a basic understanding of assembly programming of the C64 but I have tried to comment it extensively and there's also a high-level explanation of what's going on below in this readme so I think also beginners can follow it.

The code compiles with [64tass](https://sourceforge.net/projects/tass64/), a modern and very capable cross assembler running on PCs that uses (and largely extends) the syntax of the old and well-known Turbo Assembler, a popular macro assembler for the C64. The code makes heavy use of 64tass macros to make it as compact and readable as possible.

The source code is in `the wizard_of_wor.asm` file and the sprite data is included from the `inc.sprites*asm` files.

#### Compiling and running

To compile it:

`64tass -a wizard_of_wor.asm -b -o wow.bin`

This produces a raw binary file. You can flash it into a standard 16K cartridge or convert it into a CRT image to be used with emulators and modern cartridges like Easyflash, 1541 Ultimate, Turbo Chameleon 64 etc. For conversion you can use the `cartconv` utility from the [VICE](https://vice-emu.sourceforge.io/) package:

`cartconv -i wow.bin -o wow.crt -t normal`

## Introduction to the Code

### Overview

The code was written by Jeff Bruette as his first own project. It employs some clever trickery (like using conditional jumps with always triggering conditions instead of `JMP`s to save a byte and a clock cycle) there is some overcomplicated code, the structure is not always as clean as it could be, there are things that seem to be leftovers from earlier ideas and the occasional bug is also there. However generally it should not be too hard to follow - especially if you know what's going on. Actually playing the game is highly recommended as it is fun :) and also helps understanding what the code does.

The game supports the Magic Voice cartridge, an early speech synthesizer developed by a company in Texas that was bought by Commodore. It had a rather limited built-in vocabulary but you could also use your own speech definition. Wizard of Wor did the latter with the speech data provided by the Texan company - at first they wanted the speech to sound as natural as possible but Jeff pushed for a more robotic sound, just like in the arcade version of the mage. The labels and constants pertaining to Magic Voice are all beginning with `MV_` or `magic_voice`.

The code was made for NTSC C64's and there does not seem to be any consideration given to PAL systems: a second is assumed to be 60 frames. This affects the speed of music and sound effects and the speed of the players (but not of the monsters). The second values given in the disassembly and this document are valid for NTSC systems.

### Terminology

I have tried to come up with a consistent terminology to name things in WoW.

*Players* are well, the player characters.
*Monsters* are the various creatures that are not the players (even though the Wizard may not be actually a monster).
*Actors* are the players and the monsters together.
*Enemies* are the monsters and the other player.

*Playfield* is well, what you see on the screen: the dungeon, the radar and everything else.
*Cage* is the box from where the players at the beginning of a dungeon or after dying.
*Launch* is this process of emerging.
*Warp doors* are the two occasionally opening doors on the sides where an actor can warp through to the other side of the dungeon.

## Detailed workings

### Getting ready

#### Initialization

Wizard of Wor was distributed on 16 kB cartridges, so when starting besides the usual tasks of setting up the IRQ and NMI handlers, SID, VIC and CIA registers, it also copies sprite and charset data to the RAM.
The sprites are stored in a somewhat compressed way: as the last 3 lines are empty in all sprites that is not stored and also some sprites are mirrored vertically and/or horizontally.
The character set is stored similarly and in the end what WoW uses is actually an amalgam of three sets: the uppercase characters and numbers from the C64's built-in character set, a 2x1 custom character set the and the characters used to draw the huge titles ("ready", "go", "double score dungeon", "game over", etc).
The game uses multicolor character mode though most of the characters are in hi-res mode.

#### Title screen

Not much happens here: the title screen with the high scores and the table with the score values of enemies are shown alternatingly, each for 5 seconds and a busy loop checks if the fire button is pressed on any of the joysticks - if so, the game is started in one or two player made depending on which joystick's button was pressed.

It's also where the game's easter egg is displayed: if you press `Run/Stop` + `C=` + `Control` during gameplay (not here on the title screen) the copyright message is replaced with the lines "authored by jeff bruette" and "dedicated to mom and dad".

#### Dungeon setup

A dungeon layout is selected. For the first 8 dungeon a random layout is selected from a set of 15 layouts except for dungeon 4 that's the Arena (this layout is used only for this dungeon). Reaching the Arena also awards an extra life. Dungeons over 8 are the *worlord* dungeons, for these a random layout is selected from a different set of 8 layouts except for dungeon 13 and every sixth one (19, 25, 31 etc) after that which get the "empty" Pit layout. An extra life is awarded when reaching the Pit for the first time - so you can get only two extra lives during a single game. When selecting layouts the game makes sure that the same one is not used in two consecutive dungeons.
The initial speed of the monsters and the music increase for the first 8 dungeons then it reaches the maximum and it's the same for all worlord dungeons. For these during the "get ready ... go" sequence there is a "worlord" title above the radar.
After reaching dungeon 98 the game loops back to dungeon 97 so after reaching this point every second dungeon is a Pit.

The burwors are placed on their initial positions: it's always the same, for every dungeon and layout. (Have you noticed that?)

The per-dungeon variables are initialized, the "get ready ... go" is displayed, also the "double score dungeon" if appropriate and finally the game begins.

### Actual gameplay

The gameplay is controlled by the raster IRQ and a busy loop.

#### IRQ

The IRQ is responsible for a number of things, mostly those that need precise timing.
* Handle the music and sound effects
* Generate a "random number" (it's actually just an 8 bit number increased every frame)
* Maintain timers for bullet and player (but not monster!) movement - this is why the monster movement speed is not really affected by the PAL/NTSC differences
* Open the warp doors when the timer runs out. The timer is primed by the busy loop and is set to 10 seconds after the doors close or 4 seconds after Worluk appears. Opening the door also increases the speed of the music.
* Turn garwors and thorwors invisible every 10 seconds. The timer is per monster and is set to a semi-random value at the beginning of each dungeon so they don't all become invisible at once. When the monsters turn invisible they also get faster until they reach the maximum speed. The invisibility ends if they are on the same row or column as one of the players but that's handled in the busy loop described below.

#### The busy loop

The busy loop is actually three different loops: one for the normal gameplay, one for the Worluk and one for the Wizard. They are quite similar though and share many subroutines.

The normal loop does the following for each actor:

* Check keyboard. It's for pause and for activating the easter egg.
* Update the radar - this is called only for the last actor. Since it's not synched to the screen update it may clear and redraw the radar while it's being displayed, this is what causes its flickering. A happy accident, I guess.
* Move the bullets. The bullets are represented by characters and to a next character position (8 pixel) a time. The players' and the Wizard's bullets move every second frame the bullets of the other monsters move every 4th frame.
* Check for game over and exist the loop if it is.
* Check status of actor. It can either be:
  * dead: nothing to do
  * dying: play the explosion animation for a few frames, after that switch off the sprite, mark it as dead and update lives if necessary
  * alive: go on with processing
* Check if current actor collided with something deadly. If so, sets dying status and updates lives and/or scores if needed
* Decide if a monster should shoot. Monsters shoot only - with a 50% percent chance - when they are on the same row or column as one of the players. Odd numbered monsters shoot only on player 1, even numbered on player 2. Still, during single player games, all monsters shoot as player 2 does have a position then too, even though it's off-screen.
* Calculate monster and player movement. This is the most involved part of the game's code.
* Handle warp doors. This is only the half of it, handling the teleportation and closing the doors as opening them is done in the IRQ handler.
* Check if monsters' invisibility ends. They are turned invisible in the IRQ handler and here they are made visible again if they are on the same row or column as a monster.
* Do the collision check again.

The Worluk loop is basically the same with a few differences:
* The radar is switched off.
* The walls get a noisy red-black pattern. The walls are actually multi-color mode characters that use the two common colors ($D022 and $D023). During normal gameplay these both are set to blue but during the Worluk round they are alternatingly set to red and black.
* A warp door is chosen at the beginning of the round and the Worluk periodically turns towards this door.
* The Worluk will not be invisible.

If the Worluk round ends (either by it being killed or escaping) while a player is dying (the explosion animation is played) the player will not lose a life - this is probably a bug.

After the Worluk round there is some chance (25% is the Worluk was killed or 12.5% if it escaped) that the Wizard of Wor itself appears.
Its loop is also very similar to the normal loop with a few differences.

* The wizard is teleported every 160th frame.
* The warp doors open immediately after closing.
* This round lasts until either the Wizard or one of the players is shot.

#### Game Over

* The Game Over screen is shown and the music is played
* The high scores are updated.
* Back to the title screen.
