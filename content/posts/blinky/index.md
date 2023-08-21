---
layout: post
title: "Blinky"
date: 2023-08-26
draft: true
---

[Last time](@/posts/small-thing/index.md) we left off by failing to get the integrated LED to light up.
The example in `esp32c3-hal` is pretty simple; the main loop looks just toggles the pin's voltage from
low to high and back again, one cycle per second.

Our first hint comes from the pin diagram, on which pin 7 is marked as an `RGB_LED` instead of just a LED.
(There's also a [Lolin C3 mini v1.0.0](https://www.wemos.cc/en/latest/c3/c3_mini_1_0_0.html) that has a normal LED, but we're using the v2.1.0.)
What's an RGB LED? A google search turned up LEDs with [four pins](https://www.sparkfun.com/products/105): a common ground and then
one pin for each color. But our RGB LED has only one pin besides the ground, so we must have something different.

Our next hint comes from the schematic, which shows IO 7 connected to something that's labelled `WS2812B-3535`.
A quick google turns up a [datasheet](ws2812b-spec.pdf) that's pretty useful, if a little cryptic (to me, at least).
Instead of a mere analog LED,
it appears we have an "Intelligent control LED integrated light source," which we control using a simple communication
protocol described in that linked datasheet. The main parts are this:

which says we need to send 24 bits of color data by transmitting (in big-endian order) a byte of green, a byte of
red, and then a byte of blue. And then this:

tells us how to send each bit: a 1 bit is sent by setting the pin high for 850ns and then low for 400ns, and a 0 bit
is sent by setting the pin high for 400ns and then high for 850ns. After sending all 24 bits, we finish up by setting
the pin low for 50µs. There's also something in the datasheet about the "cascade method," which I think is for when
you want to control several LEDs from a single pin. We only have one LED, though.

## Bit-banging the WS2812

Since the procotol is simple, we can implement it bare-hands:

```rust
// Transmit a 1 to the LED.
let mut one = || {
  io7.set_high().unwrap();
  delay.delay_ns(850);
  io7.set_low().unwrap();
  delay.delay_ns(400);
};

// Transmit a 0 to the LED.
let mut zero = || {
  io7.set_high().unwrap();
  delay.delay_ns(400);
  io7.set_low().unwrap();
  delay.delay_ns(850);
}

// Send G = 0, R = 255, B = 0.
zero(); zero(); zero(); zero(); zero(); zero(); zero(); zero();
one(); one(); one(); one(); one(); one(); one(); one();
zero(); zero(); zero(); zero(); zero(); zero(); zero(); zero();
// 40µ of "low" to finish.
delay.delay_us(40);
```

Unfortunately, we can't do this because there is no `delay_ns` function:
`esp32c3`'s [`Delay`](https://docs.rs/esp32c3-hal/latest/esp32c3_hal/struct.Delay.html) only supports microsecond
resolution. I'm not completely sure why, because [apparently](https://github.com/esp-rs/esp-hal/blob/0c47ceda3afbc71dc2f540589811257eab51199f/esp-hal-common/src/delay.rs#L72)
the underlying timer runs at 16MHz, but anyway there are less brute-force ways to speak to our WS2812B.

## The SPI protocol

I learned about this first method from the [ws2812-spi-rs](https://github.com/smart-leds-rs/ws2812-spi-rs) crate,
which I found by searching for "ws2812" on crates.io. The idea is that the [Serial Peripheral Interface](https://en.wikipedia.org/wiki/Serial_Peripheral_Interface)
is close enough to what we want that we can manipulate it into talking to our LED.
The SPI protocol has a fixed clock speed and it sends one bit per clock tick by setting a pin high for a 1 or low for a 0.
In contrast, each bit in the WS2812's protocol needs the pin to be high and then low (for durations depending on the
bit we're sending).
For example, the nibble `1101` gets represented like this in our two protocols:

![Diagram of SPI and WS2812 waveforms coming from the nibble `1101`](spi_ws2812.webp)

Clearly they aren't the *same* protocol, but just from looking at the diagram you can see how the WS2812's protocol
can be emulated using SPI: we set the SPI frequency higher; then we send a WS2812 1 by sending several
SPI 1s followed by an SPI 0, and we send a WS2812 0 by sending an SPI 1 followed by several SPI 0s.

We have to do a little math to get the timings to line up. First up, I lied a little bit earlier: the WS2812's timings
don't need to be exactly 850ns for the long pulse and 400ns for the short pulse: you get ±150ns of slack on both of those timings.
So if we set the SPI clock to 3.33 MHz then one clock cycle (300ns) is suitable for a short pulse and three clock cycles (900ns) is
suitable for a long pulse. Then we can sent a WS2812 1 by sending `1110` on this faster SPI interface,
and a WS2812 0 by sending `1000`. For example, to send the nibble `1101` as above, we replace each 1 by `1110` and each `0`
by `1000` to get `1110111010001110` and then we send that along our faster SPI interface like this:

![Diagram the SPI waveform for `1110111010001110`](spi_faster.webp)

And it works! I implemented it [here](https://github.com/jneem/esp-examples/blob/main/blinky/src/bin/spi.rs); running
`cargo run --bin spi` finally gives me a life sign from the onboard LED.

## The RMT peripheral