# Hack Assembler

This is an implementation in Zig of a Hack Assembler, an assembler that translates Hack Assembly to Hack Machine code, this is project 6 of the Nan2Tetris course. The produced machine code was validated against the output from the online Nand2Tetris assembler https://nand2tetris.github.io/web-ide/asm.

## Running the assembler

To run the program you can first compile it running `zig build`, that will create the executable at zig-out/bin, then you can compile a Hack assembly program like this `zig-out/bin/hack-assembler programs/Add.asm`, that will create a `.hack` file with the same name as the compiled program e.g. `Add.hack`. Alternatively you can compile and run in one step with `zig build run`, like this `zig build run -- programs/Add.asm`.
