module dparser.pair;

import std.conv : to;
import std.typecons: Tuple;

template Pair(X, Y) {
    alias Pair = Tuple!(X, "left", Y, "right");
}

Pair!(X, Y) pair(X, Y)(X x, Y y)
{
    return Pair!(X, Y)(x, y);
}