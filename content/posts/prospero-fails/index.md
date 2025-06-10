---
layout: post
title: "The Prospero challenge, failures"
date: 2025-06-09
draft: true
---

# Summary of the problem

Interval arithmetic, etc, but we're going to do brute force.
Goal is to experiment with GPU implementation. There
was an attempt and some discussion [here](https://github.com/mkeeter/fidget/issues/243),
so maybe that will give us some clues.

# Chapter 1: a fast and easy CPU interpreter

Let's start with a baseline implementation on the CPU. That will give us something
to test against, and also some performance targets. But we won't put too much effort
into optimizing it, with the secret goal of making our GPU implementation look better.

## Registers and their allocation

A *completely* naive implementation would say "this program has about 8000 variables. Let's
allocate a slot for each of them and compute them one-by-one:"

```rust
let mut slot = vec![0.0; 7866];
for x in xs {
  for y in ys {
    for (op_idx, op) in ops.enumerate() {
      match op {
        Op::Const(c) => { slot[op_idx] = c; }
        Op::VarX => { slot[op_idx] = x; }
        Op::Add(arg0_idx, arg1_idx) => { slot[op_idx] = slot[arg0_idx] + slot[arg1_idx]; }
        _ => todo!() // and so on...
      }
    }
  }
}
```

This wastes a lot of memory, because many of the variables are used once or twice
and then never again. We can save a lot of memory with a very simple two-pass algorithm
that figure out which slots can be re-used.
Several other solutions (todo: link) are doing something similar, but let's quickly
describe it anyway.

The first pass of our algorithm iterates through the ops, and computes the last time
that each one is used. On our second pass, we simultaneously figure out the number
of necessary slots and allocate slots to ops: for each op in order, we assign it
to a slot, reusing an old unused slot if there is one, or allocating a fresh slot
if necessary.
Then if any of that op's arguments were just used for the last time, we mark their
slots as unread.
This simple and fast algorithm gets us down from 7866 slots to 157.

Reusing registers complicates our op representation slightly, because now
each op needs to know its output slot.

```rust
let mut slot = vec![0.0; 157];
for x in xs {
  for y in ys {
    for op in ops.enumerate() {
      match op {
        Op::Const(out_idx, c) => { slot[out_idx] = c; }
        Op::VarX(out_idx) => { slot[out_idx] = x; }
        Op::Add(out_idx, arg0_idx, arg1_idx) => { slot[out_idx] = slot[arg0_idx] + slot[arg1_idx]; }
        _ => todo!() // and so on...
      }
    }
  }
}
```

That should be good enough for our baseline implementation. It isn't fancy, but at least it
should be way faster than the python [reference implementation][Prospero challenge]
that took 15 seconds for a 1024×1024 image.

```console
❯ time target/release/cpu prospero.vm

________________________________________________________
Executed in   23.65 secs    fish           external
   usr time   23.57 secs    0.00 millis   23.57 secs
   sys time    0.01 secs    1.49 millis    0.01 secs
```

Wait, what? What happened to "blazing fast"?

Ok, so besides being implemented in different languages, the main difference between
our implementation and the reference is that the loops are ordered differently.
Although it's hidden in numpy's implicit parallelism, the python reference essentially
has the pixel loop on the inside:

```rust
let mut slot = vec![vec![0.0; 1024 * 1024]; 157];
    for op in ops.enumerate() {
      match op {
        Op::Add(out_idx, arg0_idx, arg1_idx) => {
          for pix_idx in 0..(1024 * 1024) {
            slot[out_idx][pix_idx] = slot[arg0_idx][pix_idx] + slot[arg1_idx][pix_idx];
          }
        }
        _ => todo!() // and so on...

  }
}
```

Having the pixel loop in the inside should be faster because it's a tight loop that
should be easy to unroll and autovectorize. It does come with a cost, though, because
each of our 157 slots needs to allocate a full image instead of just a single pixel.
After a bit of experimentation, it turns out that a hybrid strategy works well:
we process pixels in blocks of 512. This uses 512 times as much memory as doing
them one at a time, but 2048 times less memory than doing them all at a time.
And at least on my machine, it's just as fast as the most memory-hungry version.

Compiling with `RUSTFLAGS="-C target-cpu=native"` brought another substantial
speed boost, and adding multithreading with rayon helped too.

| version | execution time |
|---------|----------------|
| pixel-at-a-time | 23570ms |
| chunks | 703ms |
| chunks and target-cpu=native | 325ms |
| chunks and target-cpu=native and rayon | 57ms |
| vectorized JIT | 38ms |

The last row is Ken Micklas's [vectorized JIT] implementation
TODO: put it in context.

We had 2.5B instructions and had 203M L1 cache misses, while Ken
had 2.1B instructions and 89M L1 cache misses.


[vectorized JIT] https://tech.kmicklas.com/posts/prospero/

Still, I think our implementation is plenty good enough for a CPU baseline.
Let's move onto the GPU.

# Chapter 2: GPU interpreter: more complex, but also slower

Programming a GPU is pretty simple in principle: you write single-threaded code
and then you tell the GPU "run this for me 1024×1024 times in parallel with
slightly different input values." My plan, therefore, is to take the un-chunked,
single-pixel version of my baseline and run it on the GPU.

As a GPU novice, the tallest hurdle to getting started was choosing a tech
stack. I have an AMD GPU, so I looked at [ROCm], [wgpu], various different
Vulkan-compatible shader languages, and Rust-on-GPU systems like [Rust GPU]
and [CubeCL]. I ended up moving forward with [GLSL] and the [vulkano] crate,
mostly because there was lots of beginner-friendly documentation available.

[rocm]: https://www.amd.com/en/products/software/rocm.html
[wgpu]: https://wgpu.rs
[rust gpu]: https://rust-gpu.github.io/
[cubecl]: https://github.com/tracel-ai/cubecl
[glsl]: https://en.wikipedia.org/wiki/OpenGL_Shading_Language
[vulkano]: https://vulkano.rs

# Part 3: JITting to GPU

