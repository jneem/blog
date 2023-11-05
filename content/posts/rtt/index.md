---
layout: post
title: "Rtt and defmt"
date: 2023-11-04
---

In the first post, we printed a "Hello world" message to our computer using the `esp_println::println!`
macro. But there's another (better? I'm not sure. But at least, different and therefore worth trying) way
to make code running on our `esp32c3` show up on our screen.

The [Real Time Transfer](https://wiki.segger.com/RTT) (RTT) protocol is a simple method of transferring
data from an embedded device to the host system. It works by sort of not transferring data at all: it just
writes buffers in the embedded device's memory. So then how does that data make it to the host? Well, the
host connects to the device using a debug probe that's capable of reading to and writing from the device's
memory. As the embedded device is writing its data to memory, the debug probe is reading it out to the host
and then modifying the device's memory to tell it that the data's been read.

The advantage of this is that the data transfer code on the device is simple, fast, and small: just write
a few bytes to memory.

There are several device-side implementations of RTT in rust. [`defmt-rtt`](https://crates.io/crates/defmt-rtt)
and [`rtt-target`](https://crates.io/crates/rtt-target) appear to be two of the more popular options, but
the `esp_println` crate we were using before also has support for RTT as long as you set its features correctly.

## probe-rs

There are a few options for RTT on the device side, but on the host side the only implementation
I could find was the one in the [`probe-rs`](https://probe.rs/) family of tools.
When I first started writing this post a couple of months ago, the released version of `probe-rs` didn't
work out-of-the-box with the binaries that `esp-hal` produces by default. (The `esp32c3` supports two
different binary formats; details [here](https://docs.espressif.com/projects/esptool/en/latest/esp32c3/advanced-topics/firmware-image-format.html).
The latest release -- `0.21.1` as of me writing this -- of `probe-rs` works, though, as long as you pass
the `--format idf` argument: here we can run one of the led-blinking examples from the previous post.
```
❯ probe-rs run --chip esp32c3 --format idf target/riscv32imc-unknown-none-elf/debug/rmt
DEBUG probe_rs::architecture::riscv: Before requesting halt, the Dmcontrol register value was: Dmcontrol { .0: 1, hartreset: false, hasel: false, hartsello: 0, hartselhi: 0, ndmreset: false, dmactive: true }
     Erasing sectors ⠁ [00:00:00] [##################################################################]      0 B/     0 B @      0 B/s (eta 0s )
 Programming pages   ⠁ [00:00:00] [##################################################################]      0 B/     0 B @      0 B/s (eta 0s )DEBUG probe_rs::architecture::riscv: Before requesting halt, the Dmcontrol register value was: Dmcontrol { .0: 1, hartreset: false, hasel: fals     Erasing sectors ✔ [00:00:01] [#############################################################] 116.00 KiB/116.00 KiB @ 58.25 KiB/s (eta 0s )
 Programming pages   ✔ [00:00:04] [#############################################################] 112.00 KiB/112.00 KiB @ 26.82 KiB/s (eta 0s )    Finished in 6.181s
ERROR probe_rs::cmd::run: Failed to enable_vector_catch: NotImplemented("vector catch")
```
Despite the scary-looking error message, it does run and blink the LED.
(Regarding the spurious debug messages, I'll spare you the account of my late-night debugging and
just link to the [`tracing_subscriber`](https://github.com/tokio-rs/tracing/issues/2704) issue report that came out of it.)

## RTT on the device using esp-println

Since we've been using the `esp-println` crate already, the easiest way to get RTT working on the device is just to twiddle
some features: remove the default `uart` feature from `esp-println` and replace it with the `rtt` feature (and if using
`esp-backtrace`, remove its `print-uart` feature and replace it with `print-rtt`). There's a full runnable example, complete
with `.cargo/config.toml` and everything, [here](https://github.com/jneem/esp-examples/tree/main/rtt-esp-println).

## RTT on the device using defmt

One of the exciting parts about using RTT is that it unlocks using [defmt]
(https://defmt.ferrous-systems.com/), the "deferred" formatting system that
makes formatting small and fast by doing the formatting on the host instead of
the device: when you run `println!("{}, ah ha ha", x)` using, say, `esp-println`,
it compiles down to code that formats the integer `x`, builds the string with that
formatting in it, and sends that string back to the host somehow. When you run
the same code using `defmt::println!`, it sends back the integer `x` without formatting
it, and all the formatting and string concatenation is done on the host.
This removes the formatting code from the embedded device, and it also reduces the
amount of data that has to go from the device to the host.


So let's give it a try! We need to add in the defmt linker script in `.cargo/config.toml`
```toml
# ...
[build]
  rustflags = [
     "-C", "link-arg=-Tdefmt.x",
     # ... whatever was in rustflags before
  ]
```

Then we need to open our `Cargo.toml` and replace the `esp-println` dependency by `defmt`, as they can't really coexist. More precisely,
we can't use `defmt` with `rtt` support at the same time as we use `esp-println` with `rtt` support
(the binary will fail to link, as both crates expect to own the `rtt` block of memory).
We *can* use `defmt` with `rtt` support and `esp-println` with some other method of printing. But then
we can only see one of the two outputs -- as far as I could tell, there's nothing on the host end
that will print them both.

We also need to remove `esp-backtrace`, since it only supports printing things using `esp-println`.
This also means we'll have to add our own backtrace implementation. Fortunately, it isn't too
difficult to just copy one of the implementations out there. The full runnable example is
[here](https://github.com/jneem/esp-examples/tree/main/rtt-defmt).

## Gripes with probe-rs

It's great that `probe-rs` and `defmt` support the `esp32c3` with minimal setup pain, but I did have
a couple of gripes that will keep me using `espflash` for now:

- `probe-rs` is slower to flash: this `rtt-defmt` binary in the previous example takes about 2 seconds to
     flash with `espflash`, but about 6 seconds to flash with `probe-rs`. Not such a big deal for this example,
     but it's more painful for larger programs.
- there's one situation that I often run into where `espflash` has a decent error message but `probe-rs` doesn't:
     if I put my board into boot-from-flash mode by holding down the button on the right and the tapping the reset button
     (more on this in a future post) then on the next `cargo run` it won't actually boot up.
     When using `espflash` you get a somewhat cryptic error message in this situation:

     ```
     ESP-ROM:esp32c3-api1-20210207
     Build:Feb  7 2021
     rst:0x15 (USB_UART_CHIP_RESET),boot:0x7 (DOWNLOAD(USB/UART0/1))
     Saved PC:0x40380836
     0x40380836 - _start_trap_rust_hal
         at /home/me/.cargo/registry/src/index.crates.io-6f17d22bba15001f/esp-hal-common-0.13.1/src/interrupt/riscv.rs:433
     waiting for download
     ```

     At least it's an error message, though. `probe-rs` just sits there saying nothing.
