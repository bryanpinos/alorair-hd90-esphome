// ============================================================================
//  hd90_mount.scad
//  Mounting base for the AlorAir HD90 ESPHome controller.
//
//  Holds THREE boards on one FDM-printable plate:
//    1. Adafruit ESP32 Feather V2   (Product 5400)  -- bottom of the stack
//    2. Adafruit CAN Bus FeatherWing (Product 5709) -- stacks on the Feather
//    3. Adafruit RJ45 -> Terminal Block adapter (Product 4511)
//
//  The Feather + FeatherWing mount as ONE stack (the wing sits on the Feather's
//  own stacking headers), so the stack is held by the Feather's mounting holes.
//  The RJ45 adapter mounts flat beside it, with an open routing gap between the
//  two screw-terminal blocks for the three jumpers (CAN-H / CAN-L / GND).
//
//  UNITS: millimetres. Designed to print FLAT on the bed with NO supports.
//
//  ####################  READ BEFORE PRINTING  ###############################
//  Every value tagged  // VERIFY  is an ESTIMATE. Adafruit does not publish a
//  full mechanical drawing for the 4511, and the Feather V2 hole coordinates
//  below are read off the fab print, not a dimensioned drawing. MEASURE your
//  actual parts with calipers and update these numbers before committing to a
//  final print. See README.md.
//  ###########################################################################

/* ============================ PARAMETERS ============================ */

// ---- Base plate --------------------------------------------------------
base_thick    = 3.0;   // plate thickness. Prints flat, no supports.
plate_margin  = 5.0;   // clear border around each board footprint
route_gap     = 16.0;  // OPEN gap between the two terminal blocks for the 3
                       // jumpers. Keeps CAN-H/CAN-L/GND runs well under ~4 cm.
end_clear     = 10.0;  // clear plate at each short end for mounting hardware
corner_r      = 4.0;   // rounded plate corners (cosmetic + less sharp)

// ---- Adafruit Feather V2 form factor (5400) ---------------------------
// PCB nominal is 2.0" x 0.9" = 50.8 x 22.86 mm.  // VERIFY
feather_len   = 50.8;  // long axis   // VERIFY
feather_wid   = 22.9;  // short axis  // VERIFY

// Feather mounting holes: [x, y] measured from the board's lower-left corner
// (USB-C end = low X). The V2 has multiple mounting holes; these positions are
// read off the fab print and are APPROXIMATE.  // VERIFY EACH ONE.
// If, with the wing stacked, only 2 holes are usable, delete the other 2 rows.
feather_holes = [
  [  2.6,             2.6            ],  // VERIFY  (near USB-C / lower-left)
  [ feather_len-2.6,  2.6            ],  // VERIFY
  [  2.6,             feather_wid-2.6],  // VERIFY
  [ feather_len-2.6,  feather_wid-2.6],  // VERIFY  (near STEMMA / upper-right)
];

// Stack standoffs. Height must clear the USB-C shell and JST battery jack that
// sit on the Feather's underside. Target 6-8 mm.  M2.5 self-tapping screw bites
// straight into the printed pilot hole (no insert needed).
feather_standoff_h  = 7.0;   // clearance under the Feather PCB   // VERIFY fit
feather_standoff_od = 6.0;   // outer dia of each standoff post
feather_pilot_d     = 2.1;   // M2.5 self-tap pilot. Use 2.5 for a heat-set/nut.

// ---- Adafruit RJ45 -> Terminal Block adapter (4511) -------------------
// No official mech drawing was available; the whole footprint is an ESTIMATE.
rj45_len      = 40.0;  // VERIFY
rj45_wid      = 25.0;  // VERIFY
// Its mounting holes, [x, y] from ITS lower-left corner. Adjust to match the
// actual diagonal (or 4-corner) pattern on your board.  // VERIFY EACH ONE.
rj45_holes = [
  [  3.0,          3.0          ],  // VERIFY
  [ rj45_len-3.0,  rj45_wid-3.0 ],  // VERIFY
];
rj45_standoff_h  = 4.0;  // 4511 underside is fairly flat; keep it low  // VERIFY
rj45_standoff_od = 6.0;
rj45_pilot_d     = 2.1;

// ---- Plate-to-box / plate-to-wall mounting ----------------------------
// "screws"  -> plain M3 through-holes at both ends (screw the plate down)
// "keyhole" -> keyhole slots at both ends (hang on two pre-set screws)
mount_style   = "screws";   // "screws" | "keyhole"
box_hole_d    = 3.4;        // clearance for an M3 screw
keyhole_head_d= 8.0;        // clearance for the screw HEAD
keyhole_slot_w= 4.2;        // clearance for the screw SHANK
keyhole_travel= 10.0;       // how far the plate slides down onto the screw

// Two extra M3 hold-down holes inside the routing gap (always added).
gap_holes_edge_inset = 4.0; // from the long edges

// ---- Zip-tie strain relief in the routing gap -------------------------
add_tie_slots = true;
tie_slot_w    = 3.0;
tie_slot_l    = 8.0;

$fn = 48;

/* ============================ DERIVED LAYOUT ========================= */
// Both boards lie long-axis along X, end to end:
//   [ end_clear | FEATHER stack | route_gap | RJ45 adapter | end_clear ]
// Feather USB-C faces the LEFT (low X) short edge so it stays reachable.
// The FeatherWing terminal block is assumed to face the gap (high X). If your
// wing's terminal block faces the other way, rotate the stack 180 deg on
// assembly -- the mount is symmetric enough that it still fits.

feather_x0 = end_clear + plate_margin;
feather_y0 = plate_margin;

rj45_x0 = feather_x0 + feather_len + route_gap;
rj45_y0 = plate_margin;                       // bottom-aligned with the Feather

board_wid = max(feather_wid, rj45_wid);
plate_wid = plate_margin*2 + board_wid;
plate_len = rj45_x0 + rj45_len + plate_margin + end_clear;

gap_cx = (feather_x0 + feather_len + rj45_x0) / 2;   // centre of the routing gap

/* ============================== MODULES ============================= */

// Rounded-rectangle plate body (2D), for hull.
module plate_outline() {
  hull() {
    for (p = [[corner_r,           corner_r],
              [plate_len-corner_r,  corner_r],
              [corner_r,            plate_wid-corner_r],
              [plate_len-corner_r,  plate_wid-corner_r]])
      translate(p) circle(r = corner_r);
  }
}

// One screw standoff with a BLIND pilot hole (1 mm floor -> flat plate bottom,
// nothing pokes through, and no bridging needed for FDM).
module standoff(pos, h, od, pilot) {
  translate([pos[0], pos[1], 0])
    difference() {
      cylinder(h = base_thick + h, d = od);
      translate([0, 0, 1.0])
        cylinder(h = base_thick + h, d = pilot);   // blind from 1mm up
    }
}

// A vertical through-hole in the plate.
module thru_hole(x, y, d) {
  translate([x, y, -0.1]) cylinder(h = base_thick + 0.2, d = d);
}

// A keyhole slot: big head circle, then a slot the plate slides down along.
// Oriented so the plate drops DOWN (-Y) onto a pre-installed screw.
module keyhole(x, y) {
  translate([x, y, -0.1]) {
    cylinder(h = base_thick + 0.2, d = keyhole_head_d);                 // head
    translate([-keyhole_slot_w/2, -keyhole_travel, 0])
      cube([keyhole_slot_w, keyhole_travel, base_thick + 0.2]);         // slot
    translate([0, -keyhole_travel, 0])
      cylinder(h = base_thick + 0.2, d = keyhole_slot_w);              // rounded end
  }
}

/* ============================ ASSEMBLY ============================== */

difference() {
  union() {
    // --- base plate ---
    linear_extrude(base_thick) plate_outline();
    // --- Feather + FeatherWing stack standoffs ---
    for (h = feather_holes)
      standoff([feather_x0 + h[0], feather_y0 + h[1]],
               feather_standoff_h, feather_standoff_od, feather_pilot_d);
    // --- RJ45 adapter standoffs ---
    for (h = rj45_holes)
      standoff([rj45_x0 + h[0], rj45_y0 + h[1]],
               rj45_standoff_h, rj45_standoff_od, rj45_pilot_d);
  }

  // --- plate-to-box mounting at the two short ends ---
  if (mount_style == "screws") {
    thru_hole(end_clear/2,             plate_wid/2, box_hole_d);
    thru_hole(plate_len - end_clear/2, plate_wid/2, box_hole_d);
  } else { // keyhole
    keyhole(end_clear/2,             plate_wid/2 + keyhole_travel/2);
    keyhole(plate_len - end_clear/2, plate_wid/2 + keyhole_travel/2);
  }

  // --- two hold-down holes inside the routing gap ---
  thru_hole(gap_cx, gap_holes_edge_inset,             box_hole_d);
  thru_hole(gap_cx, plate_wid - gap_holes_edge_inset, box_hole_d);

  // --- zip-tie strain relief slots in the routing gap ---
  if (add_tie_slots) {
    for (dx = [-4, 4])
      translate([gap_cx + dx, plate_wid/2 - tie_slot_l/2, -0.1])
        cube([tie_slot_w, tie_slot_l, base_thick + 0.2]);
  }
}

/* ============================ ECHO SUMMARY ========================== */
echo(str("Plate size (mm): ", plate_len, " x ", plate_wid, " x ", base_thick));
echo(str("Feather stack origin (mm): ", feather_x0, ", ", feather_y0));
echo(str("RJ45 adapter origin (mm): ", rj45_x0, ", ", rj45_y0));
echo(str("Routing gap width (mm): ", route_gap, "  (jumper runs stay < 4 cm)"));
