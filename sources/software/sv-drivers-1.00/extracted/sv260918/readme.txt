SuperVidel Drivers v1.00
=========================

This is mostly a bugfix release, perhaps a good 10 years overdue :). As PeP's
focus is somewhere else these days, it was up to me (once again) to fix
something which I'd like to see fixed by myself.

The list of bugfixes is way too long, so just briefly:

- Vsync() fixed (it wouldn't stop on the sync signal at all; however the $70
  vector is still called from Videl's VBL, to be done later)

- Desktop video dialog, many fixes (I removed the weird 61 Hz modes, too)

- Bottom area of the screen cleared properly in various situations (starting a
  .TOS program, during boot, ...)

- VsetMode() clears 0xFFFF820E as TOS/EmuTOS does

- Use the cleaner svscreen.sys code from v4nvdi (released as a proof of
  concept by PeP as svscreen2.zip in 2023)

- Fix the Atari boot logo in 32bpp and other 32bpp fixes

- Reworked console code (uses NVDI's one thanks to one ugly hack), many things
  fixed thanks to it

- many invisible bugs fixed which were clearly wrong in the code

Feel free to reach me at miro.kropacek@gmail.com for bug reports or feature
ideas.

Enjoy!

Miro Kropacek aka MiKRO,
18.09.2026,
Brisbane / Australia
