// ============================================================================
//  hd90_enclosure.scad
//  FULL two-part enclosure for the AlorAir HD90 ESPHome controller.
//  Supersedes hd90_mount.scad (the open base plate).
//
//  Holds THREE boards:
//    1. Adafruit ESP32 Feather V2   (5400)  -- bottom of stack
//    2. Adafruit CAN Bus FeatherWing (5709) -- stacks on the Feather
//    3. Adafruit RJ45 -> Terminal Block adapter (4511)
//
//  Design:
//    - Tray (floor + 4 walls) with print-in-place standoffs for both boards.
//    - Removable LID, screwed down into 4 corner bosses -> full service access.
//    - RJ45 jack exits the RIGHT short wall (the dehumidifier cable plugs in
//      from OUTSIDE); USB-C exits the LEFT short wall (permanent power/debug).
//    - ALL CAN wiring (wing terminal <-> 4511 terminal) stays INSIDE, short.
//    - External wall-mount flanges (4x M4) to screw the box near the unit.
//
//  UNITS: millimetres. Tray and lid both print FLAT, NO supports. The two
//  connector windows have short bridged tops (13-16 mm span) which FDM handles
//  cleanly; if your printer bridges poorly, raise them to the rim by hand.
//
//  ####################  READ BEFORE PRINTING  ###############################
//  Everything tagged  // VERIFY  is an ESTIMATE (board sizes, hole positions,
//  connector heights, and especially the 4511 which has no published mech
//  drawing). MEASURE with calipers and update before a final print. See README.
//  ###########################################################################

// Which part(s) to emit. Override on the CLI:
//   openscad -D 'part="tray"' -o tray.stl hd90_enclosure.scad
//   openscad -D 'part="lid"'  -o lid.stl  hd90_enclosure.scad
part = "both";            // "tray" | "lid" | "both" (both = exploded preview)

/* ============================ PARAMETERS ============================ */

// ---- Shell ----
wall            = 2.4;   // side-wall thickness
floor_th        = 3.0;   // tray floor thickness
lid_th          = 2.4;   // lid thickness
inner_height    = 34.0;  // INTERNAL clear height, floor-top to wall-top. Must
                         // clear the full stack (see height budget in README).
                         // VERIFY once assembled; easy to trim/grow.
ext_r           = 3.0;   // outer corner radius
inner_r         = 2.0;   // inner cavity corner radius
inner_margin    = 6.5;   // board footprint -> inner wall (also keeps boards
                         // clear of the corner lid bosses)
route_gap       = 16.0;  // internal gap between the two terminal blocks for the
                         // CAN-H/CAN-L/GND jumpers (keeps runs < ~4 cm)

// ---- Lid fixing (4 corner bosses) ----
boss_od         = 7.0;
boss_pilot_d    = 2.5;   // M3 self-tap into the boss. For heat-set inserts set
                         // this to your insert's pilot (~4.0) instead.
boss_pilot_depth= 14.0;  // blind, from the boss top down
lid_screw_clear = 3.4;   // M3 clearance through the lid

// ---- Feather V2 (5400) footprint + holes (from base plate; VERIFY) ----
feather_len     = 50.8;  // VERIFY
feather_wid     = 22.9;  // VERIFY
feather_holes = [        // [x,y] from board lower-left corner. VERIFY EACH.
  [  2.6,             2.6            ],
  [ feather_len-2.6,  2.6            ],
  [  2.6,             feather_wid-2.6],
  [ feather_len-2.6,  feather_wid-2.6],
];
feather_standoff_h  = 7.0;   // clears USB-C shell + JST jack underneath. VERIFY.
feather_standoff_od = 6.0;
feather_pilot_d     = 2.1;   // M2.5 self-tap

// ---- RJ45 adapter (4511) -- MEASURED with calipers ----------------------
// The 4511 has NO mounting holes, so it is held by a CAPTURE POCKET, not screws.
// The board is nearly square. It drops into the pocket: side walls box it in,
// the front WINDOW wall takes the unplug PULL, rear blocks take the plug PUSH,
// floor pads set the jack height, and a rib on the LID presses it down.
//
// LENGTH INTERPRETATION: "total length 31.9" was read as OVERALL (jack tip to
// terminal tip), so the PCB length = 31.9 - 2.2 (jack) - 2.5 (terminal) = 27.2.
// If your 31.9 was the PCB itself, set rj45_len = 31.9 and re-render.
rj45_len        = 27.2;  // PCB length: jack edge -> terminal edge (see note)
rj45_wid        = 27.6;  // widest PCB width (narrows to ~24.9 at the very back)
pcb_th          = 1.6;   // ASSUMED (not measured) -- standard Adafruit PCB
rj45_standoff_h = 2.0;   // pad height under the board (4511 underside is FLAT, no
                         // pins) -- kept low so the jack sits lower in the window
jack_front_prot = 2.2;   // RJ45 jack protrusion past the front PCB edge (measured)
term_back_prot  = 2.5;   // terminal block protrusion past the back edge (measured)
jack_top_h      = 15.7;  // top of the RJ45 jack above the board underside (measured)
board_top_h     = 17.9;  // TALLEST feature on top near the jack (measured) -- the
                         // lid hold-down clears this so the lid always seats

// capture-pocket fit + walls
rj_fit           = 0.4;  // clearance per side, board <-> pocket walls
cradle_wall      = 2.0;  // pocket wall thickness
cradle_end_inset = 2.0;  // side walls stop this far short of the board ends
rear_block_w     = 5.0;  // width of each rear stop block (centre left open for
                         // the terminal levers, which protrude into the gap)
rj45_front_gap   = 0.2;  // board front edge <-> window-wall inner face. With the
                         // 2.4 mm wall, the 2.2 mm jack sits ~flush in the window.
lid_clamp        = true; // lid rib that presses the 4511 down when closed
lid_clamp_w      = 7.0;  // rib footprint along the board length

// ---- Connector windows (positions/sizes are ESTIMATES; VERIFY) ----
// USB-C on the LEFT short wall, centred on the Feather's short edge.
usb_win_w       = 13.0;  // VERIFY (a touch oversize for tolerance)
usb_win_h       = 9.0;   // VERIFY
usb_win_z_bot   = 5.0;   // window bottom, measured from FLOOR TOP. VERIFY.
usb_win_y_shift = 0.0;   // nudge along the wall if the port isn't centred. VERIFY.

// RJ45 jack on the RIGHT short wall. Jack opening measured ~16 wide x 13 tall;
// window sized with margin for the plug body + latch.
rj45_win_w      = 18.0;  // 16 wide jack opening + clearance
// v1 (h=15, pads=3) put the window top BELOW the jack top, so the plug hit it.
// Fix = lower the board (pads 3->2) AND open the window: with pads=2 the jack
// top is ~ floor + 2 + 15.7 = 20.7 abs; window spans z 6..24, clearing the plug
// body + latch by ~3.3 mm up top.
rj45_win_h      = 18.0;
rj45_win_z_bot  = 3.0;    // from FLOOR TOP (board underside sits at floor+standoff)
rj45_win_y_shift= 0.0;

// ---- External wall-mount flanges ----
add_flanges     = true;
flange_ext      = 9.0;   // how far each flange sticks out past the wall
flange_hole_d   = 4.5;   // M4 clearance
flange_inset    = 12.0;  // flange centre, in from each short end

// ---- Connector window tops ----
// true  = each window top is a 45-degree gable (peak) -> fully self-supporting,
//         no bridge, so no slicer will add (or need) supports. The functional
//         rectangular opening below is unchanged; the triangle is dead space.
// false = flat window tops (short bridges; needs a slicer that trusts bridging).
self_supporting_windows = false;

// ---- Optional extras (off by default) ----
add_vents       = false; // slot vents in the long walls. Off: this box lives in
                         // a humid basement; you probably DON'T want airflow.
add_lid_lip     = true;  // small alignment rails under the lid, along the long
                         // walls (keeps the lid from sliding). Skips the ends so
                         // it never fouls the corner bosses.

$fn = 48;

/* ============================ DERIVED LAYOUT ======================== */
board_area_wid = max(feather_wid, rj45_wid);
inner_wid = board_area_wid + 2*inner_margin;

feather_x0 = inner_margin;
feather_y0 = inner_margin + (board_area_wid - feather_wid)/2;
rj45_x0    = feather_x0 + feather_len + route_gap;
rj45_y0    = inner_margin + (board_area_wid - rj45_wid)/2;

// The 4511 sits hard against the window wall (small front gap) so the wall
// itself stops the board on unplug.
inner_len = rj45_x0 + rj45_len + rj45_front_gap;

ext_len   = inner_len + 2*wall;
ext_wid   = inner_wid + 2*wall;
wall_top  = floor_th + inner_height;      // z of the wall/boss top

// interior->exterior helpers
function xi(x) = wall + x;
function yi(y) = wall + y;

// corner-boss centres (interior corners, just inside the walls)
boss_c = boss_od/2 + 0.6;
boss_pos = [
  [xi(boss_c),           yi(boss_c)          ],
  [xi(inner_len-boss_c), yi(boss_c)          ],
  [xi(boss_c),           yi(inner_wid-boss_c)],
  [xi(inner_len-boss_c), yi(inner_wid-boss_c)],
];

/* ============================== MODULES ============================= */

module rbox(L, W, H, r) {
  linear_extrude(H)
    hull() for (p = [[r,r],[L-r,r],[r,W-r],[L-r,W-r]])
      translate(p) circle(r = r);
}

// screw post with a blind pilot (1 mm floor -> nothing pokes through)
module post(x, y, h, od, pilot) {
  translate([x, y, 0])
    difference() {
      cylinder(h = h, d = od);
      translate([0, 0, 1.0]) cylinder(h = h, d = pilot);
    }
}

// 45-degree gable cut sitting on top of a window: a triangular prism (base = W
// at height Zt, apex a line at Zt + W/2), extruded through the wall along X.
// Its underside slopes at 45deg, so the wall above closes without a bridge.
module gable(x0, depth, Yc, W, Zt) {
  hull() {
    translate([x0, Yc - W/2,     Zt        ]) cube([depth, W,    0.02]);  // base
    translate([x0, Yc - 0.01,    Zt + W/2  ]) cube([depth, 0.02, 0.02]);  // apex
  }
}

// Captured pocket for the 4511. Board drops straight in (no snaps to print).
// Held: sides by two walls, unplug (+X) by the window wall, plug-push (-X) by
// two rear corner blocks, down by floor pads + the lid clamp rib, up by the lid.
module rj45_cradle() {
  bx0 = xi(rj45_x0);              bx1 = xi(rj45_x0 + rj45_len);
  by0 = yi(rj45_y0);             by1 = yi(rj45_y0 + rj45_wid);
  h_wall = rj45_standoff_h + pcb_th;          // pocket wall height above floor
  // floor support pads (set jack height; board rests on these 4 corners)
  for (px = [bx0 + 3, bx1 - 3])
    for (py = [by0 + 3, by1 - 3])
      translate([px - 2.5, py - 2.5, floor_th]) cube([5, 5, rj45_standoff_h]);
  // side walls (+/-Y) capture the board laterally and stop rotation
  translate([bx0 + cradle_end_inset, by0 - rj_fit - cradle_wall, floor_th])
    cube([rj45_len - 2*cradle_end_inset, cradle_wall, h_wall]);
  translate([bx0 + cradle_end_inset, by1 + rj_fit, floor_th])
    cube([rj45_len - 2*cradle_end_inset, cradle_wall, h_wall]);
  // rear stop blocks (gap side, -X) -- two, at the corners, centre left open
  for (py = [by0, by1 - rear_block_w])
    translate([bx0 - rj_fit - cradle_wall, py, floor_th])
      cube([cradle_wall, rear_block_w, h_wall]);
}

module usb_window() {
  Yc = yi(feather_y0 + feather_wid/2 + usb_win_y_shift);
  translate([-1, Yc - usb_win_w/2, floor_th + usb_win_z_bot])
    cube([wall + 2, usb_win_w, usb_win_h]);
  if (self_supporting_windows)
    gable(-1, wall + 2, Yc, usb_win_w, floor_th + usb_win_z_bot + usb_win_h);
}

module rj45_window() {
  Yc = yi(rj45_y0 + rj45_wid/2 + rj45_win_y_shift);
  translate([ext_len - wall - 1, Yc - rj45_win_w/2, floor_th + rj45_win_z_bot])
    cube([wall + 2, rj45_win_w, rj45_win_h]);
  if (self_supporting_windows)
    gable(ext_len - wall - 1, wall + 2, Yc, rj45_win_w,
          floor_th + rj45_win_z_bot + rj45_win_h);
}

module vents() {
  // three slots low on each long wall (only if enabled)
  for (side = [0, 1])
    for (i = [-1, 0, 1])
      translate([ext_len/2 + i*14 - 1.5,
                 side == 0 ? -1 : ext_wid - wall - 1,
                 floor_th + 4])
        cube([3, wall + 2, inner_height - 8]);
}

module flange(cx, base_y, dir) {   // dir = -1 (-Y side) or +1 (+Y side)
  tip_y = base_y + dir * flange_ext;
  difference() {
    linear_extrude(floor_th)
      hull() {
        translate([cx, base_y]) circle(r = 6);      // root, merges into wall
        translate([cx, tip_y])  circle(r = 5);      // tab tip
      }
    translate([cx, tip_y, -1]) cylinder(h = floor_th + 2, d = flange_hole_d);
  }
}

module flanges() {
  if (add_flanges)
    for (cx = [flange_inset, ext_len - flange_inset]) {
      flange(cx, 0,       -1);   // -Y side
      flange(cx, ext_wid, +1);   // +Y side
    }
}

/* ================================ TRAY ============================== */
module tray() {
  difference() {
    union() {
      // hollow shell = outer solid minus inner cavity, plus flanges
      difference() {
        rbox(ext_len, ext_wid, wall_top, ext_r);
        // cavity: open at the top (+2 so it breaks the top surface)
        translate([wall, wall, floor_th])
          rbox(inner_len, inner_wid, inner_height + 2, inner_r);
        usb_window();
        rj45_window();
        if (add_vents) vents();
      }
      flanges();

      // inside features (added AFTER hollowing so the cavity can't remove them)
      // Feather + FeatherWing stack standoffs:
      for (h = feather_holes)
        post(xi(feather_x0 + h[0]), yi(feather_y0 + h[1]),
             floor_th + feather_standoff_h, feather_standoff_od, feather_pilot_d);
      // RJ45 adapter: captured pocket (the 4511 has no mounting holes)
      rj45_cradle();
      // corner lid bosses (rise to the wall top):
      for (p = boss_pos)
        translate([p[0], p[1], 0]) cylinder(h = wall_top, d = boss_od);
    }
    // blind pilots for the lid screws, from each boss TOP down
    for (p = boss_pos)
      translate([p[0], p[1], wall_top - boss_pilot_depth])
        cylinder(h = boss_pilot_depth + 0.1, d = boss_pilot_d);
    // flange holes are cut inside flange(); nothing more here
  }
}

/* ================================ LID =============================== */
module lid() {
  difference() {
    union() {
      rbox(ext_len, ext_wid, lid_th, ext_r);
      // alignment rails: two strips just inside the long walls, ends kept clear
      if (add_lid_lip)
        for (yc = [wall + 1.0, ext_wid - wall - 1.0])
          translate([flange_inset, yc - 0.8, -3.0])
            cube([ext_len - 2*flange_inset, 1.6, 3.0]);
      // clamp rib: presses the 4511 down onto its pads when the lid is closed.
      // Sits near the jack (front) end, away from the gap-side terminals.
      if (lid_clamp) {
        // Hold-down over the JACK end. It stops 0.3 mm above the tallest feature
        // on top of the board there (board_top_h) -- NOT the bare PCB, which the
        // jack housing covers -- so the lid always seats and the 4511 can't lift
        // out of the pocket. Lower board_top_h toward the jack top (15.7) for a
        // firmer press once you've confirmed what actually sits under the rib.
        rib_drop = wall_top - (floor_th + rj45_standoff_h + board_top_h) - 0.3;
        translate([xi(rj45_x0 + rj45_len) - lid_clamp_w - 1,
                   yi(rj45_y0 + 3), -rib_drop])
          cube([lid_clamp_w, rj45_wid - 6, rib_drop]);
      }
    }
    // lid screw clearance holes over the bosses
    for (p = boss_pos)
      translate([p[0], p[1], -1]) cylinder(h = lid_th + 2, d = lid_screw_clear);
    if (add_vents)   // mirror vents on the lid if enabled
      for (i = [-2:2])
        translate([ext_len/2 + i*12 - 1.5, ext_wid/2 - 10, -1])
          cube([3, 20, lid_th + 2]);
  }
}

/* ===================== FIT-TEST COUPON ============================= */
// Just the RJ45 pocket + the window wall on a small base. Print this (~15 min)
// to confirm the 4511 drops in and the jack lines up BEFORE reprinting the tray.
module fittest() {
  m = 8;                                   // margin of base around the pocket
  x0 = xi(rj45_x0) - m;   x1 = xi(inner_len) + wall + 2;
  y0 = yi(rj45_y0) - m;   y1 = yi(rj45_y0 + rj45_wid) + m;
  difference() {
    union() {
      translate([x0, y0, 0]) cube([x1 - x0, y1 - y0, floor_th]);   // base slab
      // front window wall segment (full height so the window + gable render)
      translate([xi(inner_len), y0, 0]) cube([wall, y1 - y0, wall_top]);
      rj45_cradle();                                               // the pocket
    }
    rj45_window();                                                 // jack window
  }
}

/* ============================== EMIT =============================== */
if (part == "tray") tray();
else if (part == "lid") lid();
else if (part == "fittest") fittest();
else {
  // exploded preview: lid floated above the tray
  tray();
  translate([0, 0, wall_top + 22])
    // flip the lid so its rails point down toward the tray, as it assembles
    translate([0, ext_wid, lid_th]) rotate([180, 0, 0]) lid();
}

/* ============================ ECHO SUMMARY ========================== */
echo(str("External box (mm): ", ext_len, " x ", ext_wid, " x ", wall_top,
         "  (+", lid_th, " lid)"));
echo(str("Internal clear height (mm): ", inner_height));
echo(str("Feather stack origin (interior mm): ", feather_x0, ", ", feather_y0));
echo(str("RJ45 adapter origin (interior mm): ", rj45_x0, ", ", rj45_y0));
