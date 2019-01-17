module dparser.peg;

import std.traits;
import std.meta;
import std.conv;

import dparser.pair;
import dparser.parser;
import dparser.result;

unittest
{
    auto e = new E;

    assert(e("42+99").toSuccess.value == 141);
    assert(e("1+2*3+4").toSuccess.value == 11);
    assert(e("(1+2)*(3+4)").toSuccess.value == 21);
}

class E: Parser!int
{
    override
    Result!int opCall(in string input) {
        return new A()(input);
    }
}

class A: Parser!int
{
    alias OP = int delegate(int, int);
    
    override
    Result!int opCall(in string input) {
        return new M().chainl(
            str("+").map!(string, OP)(_ => (a, b) => a + b).or(
                str("-").map!(string, OP)(_ => (a, b) => a - b)
            )
        )(input);
    }
}

class M: Parser!int
{
    alias OP = int delegate(int, int);

    override
    Result!int opCall(in string input) {
        return new P().chainl(
            str("*").map!(string, OP)(_ => (a, b) => a * b).or(
                str("/").map!(string, OP)(_ => (a, b) => a / b)
            )
        )(input);
    }
}

class P: Parser!int
{
    alias PAR = Pair!(Pair!(string, int), string);

    override
    Result!int opCall(in string input) {
        return str("(").cat(new E).cat(str(")")).map!(PAR, int)(r => r.left.right).or(new N)(input);
    }
}

class N: Parser!int
{
    override
    Result!int opCall(in string input) {
        return reg("[0-9]+").map!string(s => s.to!int)(input);
    }
}