module dparser.parser;

import dparser.pair;
import dparser.result;

/**
 * パーザを表す型
 */
abstract class Parser(T)
{
    Result!T opCall(string input);
}

Parser!string str(in string literal)
{
    return new StringParser(literal);
}

Parser!string reg(in string literal)
{
    return new RegexParser(literal);
}

Parser!(Pair!(T, U)) cat(T, U)(Parser!T self, Parser!U other)
{
    return new Cat!(T, U)(self, other);
}

Parser!T or(T)(Parser!T self, Parser!T other)
{
    return new Or!T(self, other);
}

Parser!(T[]) rep(T)(Parser!T self)
{
    return new Rep!T(self);
}

Parser!(T[]) oneand(T)(Parser!T self)
{
    return new OneAnd!T(self);
}

Parser!T any(T)(Parser!T head, Parser!T[] tail...)
{
    return new Any!T(head, tail);
}

Parser!U map(T, U)(Parser!T self, U delegate(T) f)
{
    return new Map!(T, U)(self, f);
}

Parser!T chainl(T, U)(Parser!T p, Parser!U q, Parser!(T delegate(T, U)) op)
{
    return new Chainl!(T, U)(p, q, op);
}

Parser!T chainl(T)(Parser!T p, Parser!(T delegate(T, T)) op)
{
    return new Chainl!(T, T)(p, op);
}

/**
 * 任意の文字列をパーズする。
 */
class StringParser: Parser!string
{
    string literal;

    this(in string literal) {
        this.literal = literal;
    }

    override
    Result!string opCall(in string input) {
        import std.algorithm.searching: startsWith;

        if (input.startsWith(this.literal)) {
            auto len = literal.length;
            return success(literal, input[len..$]);
        } else {
            return failure!string("expected: " ~ literal, input);
        }
    }
}

unittest
{
    auto res = str("Hello")("Hello, world!").toSuccess;
    assert(res.value == "Hello");
    assert(res.next == ", world!");

    auto res2 = str("Hello, ")("world!");
    assert(res2.isFailure);

    auto res3 = str("Hello, ")("Hello, world!").toSuccess;
    assert(res3.value == "Hello, ");
    assert(res3.next == "world!");
}

/**
 * 利便性のための正規表現パーザ。
 */
class RegexParser: Parser!string
{
    import std.regex;
    string literal;
    typeof(regex(literal)) reg;

    this (in string literal) {
        this.literal = literal;
        this.reg = regex(literal);
    }

    override
    Result!string opCall(in string input) {
        import std.range;

        auto m = input.matchFirst(reg);
        if (!m.empty && m.pre.empty) {
            return success(m.hit, m.post);
        } else {
            return failure!string("expected: " ~ this.literal, input);
        }
    }
}

unittest
{
    auto res = reg("[0-9]+")("123-456").toSuccess;
    assert(res.value == "123");
    assert(res.next == "-456");
}

class Cat(X, Y): Parser!(Pair!(X, Y))
{
    Parser!X left;
    Parser!Y right;

    this(Parser!X left, Parser!Y right) {
        this.left = left;
        this.right = right;
    }

    alias XY = Pair!(X, Y);

    override
    Result!XY opCall(in string input) {
        auto left_result = this.left(input);
        if (left_result.isFailure) {
            return left_result.toFailure.of!XY;
        }
        auto left_success = left_result.toSuccess;
        auto right_result = this.right(left_success.next);
        if (right_result.isFailure) {
            return right_result.toFailure.of!XY;
        }
        auto right_success = right_result.toSuccess;
        return success(pair(left_success.value, right_success.value), right_success.next);
    }
}

class Or(T): Parser!T
{
    Parser!T left;
    Parser!T right;

    this(Parser!T left, Parser!T right) {
        this.left = left;
        this.right = right;
    }

    override
    Result!T opCall(in string input) {
        auto result = this.left(input);
        if (result.isSuccess) return result;
        return this.right(input);
    }
}

class Rep(T): Parser!(T[])
{
    Parser!T parser;

    this(Parser!T parser) {
        this.parser = parser;
    }

    override
    Result!(T[]) opCall(in string input) {
        T[] values;
        string prev, next = input;
        for (;;) {
            auto result = this.parser(next);
            prev = next;
            if (result.isSuccess) {
                auto success = result.toSuccess;
                values ~= success.value;
                prev = next;
                next = success.next;
                if (next == "") prev = "";
            } else {
                next = "";
            }
            if (next == "") {
                return success(values, prev);
            }
        }
    }
}

unittest
{
    auto repp = str("Hello").rep!string;

    auto res1 = repp("HelloHelloHello").toSuccess;
    assert(res1.value == ["Hello", "Hello", "Hello"]);
    assert(res1.next == "");

    auto res2 = repp("HelloHelloHelloWorld").toSuccess;
    assert(res2.value == ["Hello", "Hello", "Hello"]);
    assert(res2.next == "World");

    auto res3 = repp("").toSuccess;
    assert(res3.value == []);
    assert(res3.next == "");
}

class OneAnd(T): Parser!(T[])
{
    Parser!T parser;

    this(Parser!T parser) {
        this.parser = parser;
    }

    override
    Result!(T[]) opCall(in string input) {

        import std.array: empty;

        auto res = this.parser.rep()(input);
        if (res.isFailure) return res;
        auto suc = res.toSuccess;
        if (suc.value.empty) return failure!(T[])("expected at least one element, but nothing.", input);
        return res;
    }
}

unittest
{
    auto repp = str("Hello").oneand!string;

    auto res1 = repp("HelloHelloHello").toSuccess;
    assert(res1.value == ["Hello", "Hello", "Hello"]);
    assert(res1.next == "");

    auto res2 = repp("HelloHelloHelloWorld").toSuccess;
    assert(res2.value == ["Hello", "Hello", "Hello"]);
    assert(res2.next == "World");

    auto res3 = repp("");
    assert(res3.isFailure);
}

class Any(T): Parser!T
{
    Parser!T[] parsers;

    this(Parser!T parser, Parser!T[] parsers...) {
        this.parsers = [parser] ~ parsers;
    }

    override
    Result!T opCall(in string input) {
        foreach (parser; parsers) {
            auto res = parser(input);
            if (res.isSuccess) {
                return res;
            }
        }
        return failure!T("expected: " ~ parsers[0].toString, input);
    }
}

unittest
{
    auto abc = any(str("A"), str("B"), str("C"));
    auto res1 = abc("A").toSuccess;
    assert(res1.value == "A");
    auto res2 = abc("C").toSuccess;
    assert(res2.value == "C");
    auto res3 = abc("D");
    assert(res3.isFailure);

    import std.array, std.algorithm, std.range, std.conv;
    auto nums = any(str("0"), str("1"), str("2"), str("3"), str("4"), str("5"), str("6"), str("7"), str("8"), str("9"));
    auto res4 = nums("42").toSuccess;
    assert(res4.value == "4");
    auto res5 = nums("99").toSuccess;
    assert(res5.value == "9");
    auto res6 = nums("hoge");
    assert(res6.isFailure);
}

class Map(T, U): Parser!U
{
    Parser!T parser;
    U delegate(T) f;

    this(Parser!T parser, U delegate(T) f) {
        this.parser = parser;
        this.f = f;

    }

    override
    Result!U opCall(in string input) {
        auto result = parser(input);
        if (result.isFailure) return result.toFailure.of!U;
        auto succ = result.toSuccess;
        return success(f(succ.value), succ.next);
    }
}

unittest
{
    import std.conv: to;

    auto res = str("123").map!string(s => s.to!int)("123456").toSuccess;
    assert(res.value == 123);
    assert(res.next == "456");
}

class Chainl(T, U): Parser!T
{
    alias OP = T delegate(T, U);

    Parser!T parser;
    this(Parser!T p, Parser!U q, Parser!OP op) {
        import std.algorithm.iteration: reduce;

        this.parser = p
            .cat(op.cat(q).rep)
            .map!(Pair!(T, Pair!(OP, U)[]))(vs => reduce!((acc, r) => r.left(acc, r.right))(vs.left, vs.right));
    }

    static if (is(T == U)) {
        this(Parser!T p, Parser!OP op) {
            this(p, p, op);
        }
    }

    override
    Result!T opCall(in string input) {
        return this.parser(input);
    }
}

unittest
{
    import std.conv: to;
    
    auto res = 
		reg("[0-9]+").map!string(s => s.to!int)
			.chainl(str("+").map!(string, int delegate(int, int))(_ => (a, b) => a + b))("1+2+3")
            .toSuccess;
    assert(res.value == 6);
    assert(res.next == "");
}