# AlorAir HD90 ESPHome Controller

Home-Assistant controller for an AlorAir Sentinel **HD90** dehumidifier, talking
to the unit over its RJ45 remote port (CAN bus) using an Adafruit ESP32 Feather
V2 + CAN Bus FeatherWing.

## Contents

| File | What it is |
|---|---|
| `hd90_enclosure.scad` | Parametric **full enclosure** (tray + lid), OpenSCAD source |
| `hd90_enclosure_tray.stl` | Tray — floor, walls, standoffs, connector windows, flanges |
| `hd90_enclosure_lid.stl` | Screw-down lid |
| `hd90_rj45_fittest.stl` | **Fit-test coupon** — just the 4511 pocket + window (print first) |
| `hd90_enclosure_preview.png` | Exploded render (tray + floating lid) |
| `hd90_mount.scad` / `.stl` | *Superseded* open base plate — kept for reference only |
| `hd90-controller-sniffer.yaml` | **Phase 1** — CAN sniffer / bring-up |
| `hd90-controller.yaml` | **Phase 2** — production MQTT controller |
| `secrets.yaml.example` | Template for WiFi / OTA / MQTT credentials |

---

## Wiring

### RJ45 → CAN FeatherWing (confirmed pinout, HD55 teardown)

| RJ45 pin | Signal | Goes to |
|---|---|---|
| 4 | CAN-L | FeatherWing terminal **L** |
| 5 | CAN-H | FeatherWing terminal **H** |
| 7 | +5V VCC | *(optional)* Feather **USB / 5V** pin |
| 8 | GND | FeatherWing terminal **−** |
| 1,2,3,6 | N/C | — |

The FeatherWing's 3-pos screw terminal is silk-labeled, in order, **CANL / − /
CANH**. Keep the three jumpers under ~4 cm — the mount's routing gap is sized for
that.

### Feather V2 ↔ CAN FeatherWing (via stacking headers — confirmed from Adafruit docs)

| Function | Feather V2 GPIO | Notes |
|---|---|---|
| SPI SCK | **GPIO5** | silk "SCK" |
| SPI MOSI | **GPIO19** | silk "MO" |
| SPI MISO | **GPIO21** | silk "MI" |
| MCP2515 **CS** | **GPIO14** | wing's CS jumper → classic Feather "pin 5" position = GPIO14 on the V2 |
| MCP2515 **INT** | **GPIO32** | wing's INT jumper → "pin 6" = GPIO32. **Unused** — ESPHome's `mcp2515` driver polls |
| MCP2515 crystal | 16 MHz | Adafruit_MCP2515 library default |

These are the pins baked into both YAML files. They're derived from Adafruit's
ESP32 Feather V2 datasheet and the CAN Bus FeatherWing guide, not from probing
your specific board — worth a continuity check with a meter, but high confidence.

---

## Part 1 — Full enclosure

Two printed parts: a **tray** and a screw-down **lid** (`hd90_enclosure.scad`
emits both). The tray holds the Feather+Wing **stack** (on the Feather's own
mounting holes) plus the 4511 RJ45 adapter, with an internal routing gap for the
CAN-H/CAN-L/GND jumpers. All CAN wiring stays **inside** the box.

Layout (external ≈ **125 × 43 × 39 mm**):

```
        LEFT short wall                 RIGHT short wall
        ┌── USB-C window                 RJ45 jack window ──┐
        v                                                   v
   ┌─────────────────────────────────────────────────────────┐
   │  [ Feather + CAN FeatherWing stack ] gap [ 4511 adapter ] │
   └─────────────────────────────────────────────────────────┘
     • 4 corner bosses take the lid screws
     • 4 external flanges (M4) screw the box to a wall/stud
```

- **RJ45 jack** exits the **right** short wall — the dehumidifier's cable plugs
  straight in from outside. **USB-C** exits the **left** short wall for permanent
  power / debugging (independent of the unverified RJ45 5 V tap).
- **4511 retention**: the 4511 has **no mounting holes**, and the RJ45 jack takes
  real plug/unplug force, so it's held in a **capture pocket** (not screws). The
  board drops in: side walls box it in, the **window wall itself stops the unplug
  pull**, rear blocks stop the plug-in push, floor pads set the jack height, and a
  **rib on the lid presses it down** when closed. Pocket dimensions are from
  measured values (`rj45_len/rj45_wid/…`). The Feather+Wing stack stays on posts.
- **Lid**: removable, 4× M3 into the corner bosses → full service access. Small
  alignment rails keep it from sliding.
- **Mounting**: 4 external flanges (M4) to screw the box up near the unit.

### Print settings
- Material: PLA/PETG fine. Layer height 0.2 mm, ≥3 walls (bosses/standoffs take
  screw load), 20–30% infill.
- Orientation: both parts print **flat, NO supports** — tray floor-down; lid
  **outer face down** so its alignment rails and the 4511 clamp rib point up and
  print as simple vertical features. **Set your slicer's Support to None.** The
  connector windows have flat tops that bridge cleanly (13–18 mm spans), as
  confirmed on the bench. (Set `self_supporting_windows = true` to switch the
  window tops to 45° gables if a future printer bridges poorly.)

### Internal height budget (`inner_height`, default 34 mm — VERIFY)
Set by the tallest thing in the box, roughly:
`standoff 7 + Feather PCB 1.6 + stacking headers ≈ 11 + Wing PCB 1.6 + Wing
terminal block ≈ 10 + clearance ≈ 2 ≈ 33 mm`. Re-measure your assembled stack
and adjust `inner_height` before the final print.

### Editing / re-rendering
All critical dimensions are variables at the top of `hd90_enclosure.scad`. After
measuring, re-render each part:

```bash
OSC="/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD"
"$OSC" -D 'part="tray"'    -o hd90_enclosure_tray.stl hd90_enclosure.scad
"$OSC" -D 'part="lid"'     -o hd90_enclosure_lid.stl  hd90_enclosure.scad
"$OSC" -D 'part="fittest"' -o hd90_rj45_fittest.stl   hd90_enclosure.scad
```

**Print the fit-test coupon first.** It's just the 4511 pocket + window wall
(~15 min). Confirm the board drops in with a light slip fit and the RJ45 jack
lines up with the window before you commit to the full tray reprint.

Useful knobs: `inner_height`, `wall`, `route_gap`, the `*_win_*` connector-window
position/size vars, `add_flanges`, `add_lid_lip`, `add_vents` (off by default —
you likely don't want airflow into a basement box), and the `feather_holes` /
`rj45_holes` lists (trim to 2 entries if a board has only 2 usable holes).

---

## Part 2 — Firmware

### Phase 1: sniff first
1. `cp secrets.yaml.example secrets.yaml` and fill it in.
2. Flash `hd90-controller-sniffer.yaml`. It uses the **native HA API** so you can
   confirm the board is alive (Uptime / WiFi / Free Heap / Status appear in HA).
3. Watch the log (`esphome logs hd90-controller-sniffer.yaml`). It dumps **every**
   CAN frame (standard *and* extended) as `id=… dlc=… data=[…]`.
4. Exercise the stock remote (change setpoint, power, mode) and note which
   frame ids / bytes change. Cross-check with a `candump` or logic-analyzer
   capture. **This capture is what unlocks Phase 2.**
5. If you see **nothing**: try `can_bitrate: "50KBPS"`, and/or set
   `mode: LISTENONLY`. If the log warns about an invalid clock/bitrate combo,
   re-check `mcp_clock`.

### Phase 2: production
Once you've decoded the frames, fill in the **FRAME MAP** substitutions block at
the top of `hd90-controller.yaml` (every entry is marked `# TODO: verify`), then
flash it. It:
- publishes humidity, temperature, reported setpoint, compressor state, and
  fault code to HA over **MQTT** (discovery on);
- exposes a **number** (target humidity), **switch** (power), and **button**
  (mode) that translate into outbound CAN frames;
- sends a periodic poll/heartbeat frame; and
- raises `binary_sensor "HD90 Communication Fault"` if no valid frame arrives
  within `comm_timeout_ms` (default 60 s).

> **Validate before flashing:** the ESPHome CLI wasn't available in the
> environment these files were written in, so run `esphome config
> hd90-controller.yaml` yourself once — it will catch any schema typo and, at
> runtime, warn about invalid clock/bitrate combinations.

---

## ⚠️ Must-verify-before-permanent-service checklist

Nothing below was measured/probed on your actual hardware — confirm each:

**Mechanical (`hd90_enclosure.scad`, every `// VERIFY`):**
- [ ] Feather V2 board size and **mounting-hole coordinates** (`feather_holes`) —
      read off the fab print, *not* a dimensioned drawing.
- [ ] 4511 pocket **fit** — dims are measured, but **print the fit-test coupon
      first** (`part="fittest"`) and confirm the board drops in with a light slip
      fit and the jack lines up with the window. Tune `rj_fit` if tight/loose.
- [ ] `rj45_len` **length interpretation** — set to 27.2 assuming the 31.9 mm
      "total length" was jack-tip-to-terminal-tip. If 31.9 was the PCB itself,
      change `rj45_len` to 31.9.
- [ ] `pcb_th` is **assumed 1.6 mm** (wasn't measured) — check it.
- [ ] Rear blocks / lid rib clear the 4511's **spring-lever terminals** (they're
      on the gap-facing edge and protrude ~2.5 mm into the routing gap).
- [ ] Standoff height actually clears the Feather's USB-C shell + JST jack.
- [ ] `inner_height` clears the fully assembled stack (measure it — see budget).
- [ ] **Connector windows** line up with the real ports: `usb_win_*` (left wall)
      and `rj45_win_*` (right wall) — position, size, and height off the floor.
- [ ] The 4511's **RJ45 jack faces +X** (away from the Feather). If it's
      reversed, rotate the board or move the window to another wall.
- [ ] Which way the FeatherWing terminal block faces (flip the stack if needed).

**Electrical:**
- [ ] CAN **bit rate** (125 kbps is an HD55 figure, unconfirmed on HD90).
- [ ] MCP2515 crystal is 16 MHz (verify via the ESPHome log warning).
- [ ] RJ45 pin-7 **5V current capacity** before relying on the power tap — treat
      as optional until proven; otherwise power the Feather over USB-C.
- [ ] SCK/MOSI/MISO/CS continuity from Feather to MCP2515.

**Protocol (`hd90-controller.yaml`, every `# TODO: verify`):**
- [ ] Standard (11-bit) vs extended (29-bit) frame ids.
- [ ] Status frame id, length, and byte offsets for RH / temp / status bits /
      setpoint / fault.
- [ ] Temperature encoding (raw °F? °C? `/2`? `−40` offset?).
- [ ] Command frame ids + payloads for setpoint / power / mode, and the
      poll/heartbeat payload the stock remote sends.

> Safety: while sniffing a live bus you don't fully understand, prefer
> `mode: LISTENONLY` so the ESP32 never transmits (incl. ACKs). Only switch to
> `NORMAL` once you trust the frame map.
