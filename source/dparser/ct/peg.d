module dparser.ct.peg;

import std.traits;
import std.meta;
import std.conv;

import dparser.ct.parser;

// auto e() {
//     return &a;
// }

// auto a() {
//     return &chainl!(
//         m(),
//         alt!(
//             map!(s!"+", (string _) => (int a, int b) => a + b),
//             map!(s!"-", (string _) => (int a, int b) => a - b)
//         )
//     );
// }

// auto m() {
//     return &chainl!(
//         p(),
//         alt!(
//             map!(s!"*", (string _) => (int a, int b) => a * b),
//             map!(s!"/", (string _) => (int a, int b) => a / b)
//         )
//     );
// }

// auto p() {
//     return &alt!(
//         map!(
//             seq!(seq!(s!"(", e()), s!")"),
//             r => r.right.left
//         ),
//         n()
//     );
// }

// auto n() {
//     return &map!(
//         reg!"[0-9]+",
//         (string s) => s.to!int
//     );
// }