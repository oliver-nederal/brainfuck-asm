# Just-In-Time Compiler for Brainfuck in X86_64 Assembly

Implemented for the CSE11C course at the Delft University of Technology.

Just in time compiler for Brainfuck written in x86_64 AT&T Assembly. Implements a decoder which does two passes over the given Brainfuck program, and then writes machine code to a code buffer. Thereafter, this buffer is made executable, and executes. This gives roughly a 34x speedup for average Brainfuck programs (compared to a interpreter) and potentially even more for even longer and more complicated code.

| Intepreter | Compiler | Speedup |   |   |
|------------|----------|---------|---|---|
| 0s         | 0s       | 1x      |   |   |
| 0s         | 0s       | 1x      |   |   |
| 0s         | 0s       | 1x      |   |   |
| 0s         | 0s       | 1x      |   |   |

Done by [Oliver Nederal](https://github.com/oliver-nederal) and [Boris Krisanov](https://github.com/boriskrisanov)

## Performance tests (LLM-Assisted)

Build the compiler/interpreter and run the correctness and performance suite with:

```sh
make benchmark
```

The suite runs several deterministic programs, including programs that consume
stdin and the bundled Mandelbrot program, checks their output, and reports
median, minimum, and maximum end-to-end time over five measured runs. Each
measurement includes reading the source, compiling it to machine code, and
executing it. Use `python3 tests/performance.py --help` to change the binary,
number of runs, or warmups. The I/O workloads use fixed-size input because the
interpreter's input instruction leaves the cell unchanged at EOF.
