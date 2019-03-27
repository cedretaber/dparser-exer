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
    override
    Result!int opCall(in string input) {
        return str("(").cat(new E).cat(str(")"))
            .map!(Pair!(Pair!(string, int), string))(r => r.left.right).or(new N)(input);
    }
}

class N: Parser!int
{
    override
    Result!int opCall(in string input) {
        
        import std.array: join;

        auto numbers =
            str("1").or(str("2")).or(str("3"))
                .or(str("4")).or(str("5")).or(str("6"))
                .or(str("7")).or(str("8")).or(str("9"))
                .or(str("0"));

        return numbers.cat(numbers.rep)
            .map!(Pair!(string, string[]))(ss => ([ss.left] ~ ss.right).join.to!int)(input);
    }
}