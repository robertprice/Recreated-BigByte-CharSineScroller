# Recreated-BigByte-CharSineScroller

In 1988 Big-Byte coded a character sine scroller in 68000 assembly language. In 2022 I found this on DemoZoo and decided to try to disassemble it. This is my attempt to recreate the demo.

https://demozoo.org/productions/224978/

## 

This source code has been developed using the [Amiga Assembly](https://github.com/prb28/vscode-amiga-assembly) extension for Visual Studio Code on a Mac with FS-UAE.

The code was originally disassembled using the [IRA V1.05beta decompiler](http://aminet.net/package/dev/asm/ira105_src). It has been worked on a lot since then.

The soundtracker mod file "DemonDownloader" was ripped from the binary using an Action Replay 3 tracker command running in FS-UAE.

The font was ripped from the binary using an Action Replay 3 to view the memory then adjusting the modulo until the image could be saved as an IFF file. This IFF file was then converted to RAW format using [IFF Converter](http://janeway.exotica.org.uk/release.php?id=19257) by Kefrens.

The original font was 320x200, but the image is actually 320x160, so I have adjusted the assembly code accordingly.

I have included the custom.i include file from Commodore and the hw_example.i from the Hardware Reference Manual. Offsets to the Amiga Custom Chips have been changed to try to use the descriptive names from these include files.