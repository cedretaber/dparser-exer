module dparser.pair;

import std.conv : to;

struct Pair(X, Y)
{
    X left;
    Y right;

    @property
    string toString() {
        return "<" ~ left.to!string ~ ", " ~ right.to!string ~ ">";
    } 
}

Pair!(X, Y) pair(X, Y)(X x, Y y)
{
    return Pair!(X, Y)(x, y);
}