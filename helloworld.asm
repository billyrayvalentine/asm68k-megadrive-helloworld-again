/*
 * helloworld.asm
 * Written for use with GNU AS

 * Copyright © 2025 Ben Sampson <github.com/billyrayvalentine>
 * This work is free. You can redistribute it and/or modify it under the
 * terms of the Do What The Fuck You Want To Public License, Version 2,
 * as published by Sam Hocevar. See the COPYING file for more details.
*/

.macro SetVpdWriteCramPaletteCommand palette_number
  move.l #(((\palette_number * 32) & 0x3FFF) << 16) | (((\palette_number * 32) & 0xC000) >> 14) | VDP_CRAM_WRITE_CMD, VDP_CTRL_PORT
.endm

.macro SetVpdWriteVramCommand address
  move.l #((\address & 0x3FFF) << 16) | ((\address & 0xC000) >> 14) | VDP_VSRAM_WRITE_CMD , VDP_CTRL_PORT
.endm


* This stops the linking complaining about missing start point label
.section .text
.global _start
_start:

.include "rom_header.asm"

* Everything kicks off here.  Must be at 0x200
cpu_entrypoint:
    * Setup the TMSS stuff
    jsr     tmss

    * Setup the VDP registers
    jsr     init_vdp

    * To use the VDP we:
    * 1. Load a colour palette to CRAM
    * 2. Load our font tiles (cells) to the beginning of VDP RAM
    * 3. Update the Plane A table in VRAM defining a tile id and palette id to display
    * No sprites are used


    * 1. Load the Colour Palette to CRAM
    * CRAM (Colour RAM) is used for storing up to 4 palettes.  Each are 32 bytes wide
    * so each palette is offset by 32 bytes
    *
    * Load the font palette in CRAM using the VPD Command 0xC0000000
    * The starting address of CRAM is not dynamic and is not set in a register so it's always 0xC0000000
    * For the first palette We just need to work out the command with the offset based
    * on which palette we want to store (0,1,3,4)
    *
    * Load the palette into CRAM as palette #0
    * The 32 bytes palette is then loaded four bytes at a time (long word)
    * Hence the loop is 8 not 32
    * The macro replaces this command
    * move.l  #0xC0200000, 0xC00004
    SetVpdWriteCramPaletteCommand 0

    lea     BRVFontPalette0, a0
    moveq   #8-1, d0

1:  move.l  (a0)+, VDP_DATA_PORT
    dbra    d0, 1b


    * 2. Load our font tiles (cells) to the beginning of VDP RAM
    * The command for the beginning of VRAM is always 0x40000000
    * Each tile is 32 bytes in size (there are 96 tiles)
    *
    * Load 4 bytes at a time (long word)
    * Hence the loop is 8 not 32
    * The macro replaces this command
    * move.l  #0x40000000, 0xC00004
    SetVpdWriteVramCommand 0

    lea     BRVFontImage0, a0
    move.w  #FONT_TILE_COUNT * 8 -1, d0

1:  move.l  (a0)+, VDP_DATA_PORT
    dbra    d0, 1b


    * 3. Update the Plane A table in VRAM defining a tile id and palette id
    * Now we have a font set loaded, let's print a string to the screen using the one defined
    * as HELLO_WORLD_STRING in globals.asm which we have defined as a string in ROM which is the
    * ASCII values terminated by a '0x00' (null terminated)
    * Load its address into a0 and loop through the values it points at
    * byte by byte and match the value (an ASCII code) with a tile ID in our font set
    lea HELLO_WORLD_STRING, a0

    * We want to write to Plane A which in init_vdp.asm is set to 0xC000 in VRAM which is the
    * VDP_REG_PLANEA register configuration option

    * This macro replaces this command
    * move.l  #0x40000003, VDP_CTRL_PORT
    SetVpdWriteVramCommand 0xC000

    * Set the palette ID
    * See https://www.plutiedev.com/tile-id
    * Palette 0 used here

    * loop through the bytes pointed to from a0 which are ASCII values until 0x00 (end of string)
    * The tile id for the character is the ASCII code - 0x20, e.g. 'A' in ASCII is 65 (0x41)
    * And the tile ID for A is 33 (0x21) in our font set so get the ASCII code and subtract 32 (0x20)
    *
    * see _ SCROLL PATTERN NAME _ in http://xi6.com/files/sega2f.html
    * Essentially, by using palette 0, the data we are sending to the VDP is just the tile number

    moveq   #0, d0
1:  move.b  (a0)+, d0
    * Test if the character is 0 (null) if so fall out of loop
    tst.b   d0
    beq     2f
    subi.b  #0x20, d0
    move.w  d0, VDP_DATA_PORT
    bra 1b
2:

* Loop forever
forever:
    jmp forever

.include "globals.asm"
.include "init_vdp.asm"
.include "tmss.asm"
.include "assets/brvfont.asm"

/*
 * Interrupt handler
*/
cpu_exception:
    rte
int_null:
    rte
int_hinterrupt:
    rte
int_vinterrupt:
    rte
rom_end:
