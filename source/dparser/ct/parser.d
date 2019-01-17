module dparser.ct.parser;

import std.traits;
import std.meta;
import std.functional;

import dparser.pair;
import dparser.result;

template ParserType(alias parser)
{
    static if (is(ReturnType!parser == Result!T, T))
        alias ParserType = T;
    else {
        import std.format : format;
        static assert(false, format!"Expected any Parser, but: %s"(R.stringof));
    }
}

/**
 * 任意の文字列をパーズする。
 */
Result!string stringParser(string literal)(in string input)
{
    import std.algorithm.searching : startsWith;

    if (input.startsWith(literal)) {
        auto len = literal.length;
        return success(literal, input[len..$]);
    } else {
        return failure!string("expected: " ~ literal, input);
    }
}

alias s = stringParser;

unittest
{

    auto hello = &s!("Hello");
    auto res = hello("Hello, world!").toSuccess;
    assert(res.value == "Hello");
    assert(res.next == ", world!");
}

/**
 * 利便性の為の正規表現パーザ。
 */
Result!string regexParser(string literal)(in string input)
{
    import std.regex;
    import std.range;

    auto r = ctRegex!literal;
    auto m = input.matchFirst(r);
    if (!m.empty && m.pre.empty) {
        return success(m.hit, m.post);
    } else {
        return failure!string("expected: " ~ literal, input);
    }
}

alias reg = regexParser;

unittest
{
    auto f = &reg!("[0-9]+");
    auto res1 = f("123-4567").toSuccess;
    assert(res1.value == "123");
    assert(res1.next == "-4567");
}

template seq(alias left, alias right)
{
    alias X = ParserType!left;
    alias Y = ParserType!right;
    alias XY = Pair!(X, Y);

    Result!XY seq(in string input)
    {
        auto left_result = left(input);
        if (left_result.isFailure) {
            return left_result.toFailure.of!XY;
        }
        auto left_success = left_result.toSuccess;
        auto right_result = right(left_success.next);
        if (right_result.isFailure) {
            return right_result.toFailure.of!XY;
        }
        auto right_success = right_result.toSuccess;
        return success(pair(left_success.value, right_success.value), right_success.next);
    }
}

unittest
{

    auto res1 = seq!(s!("Hello, "), s!("world!"))("Hello, world!").toSuccess;
    assert(res1.value == pair("Hello, ", "world!"));
    assert(res1.next == "");

    auto res2 = seq!(s!"hoge", s!"fuga")("hogehoge");
    assert(res2.isFailure);
}

template alt(alias left, alias right)
if(is(ReturnType!left == ReturnType!right))
{
    alias T = ParserType!left;

    Result!T alt(in string input)
    {
        auto result = left(input);
        if (result.isSuccess) return result;
        return right(input);
    }
}

unittest
{
    auto f = &alt!(s!"Hello", s!"World");
    auto res1 = f("Hello, world!").toSuccess;
    assert(res1.value == "Hello");
    assert(res1.next == ", world!");

    auto res2 = f("WorldHello").toSuccess;
    assert(res2.value == "World");
    assert(res2.next == "Hello");

    auto res3 = f("hogehoge");
    assert(res3.isFailure);
}

template rep(alias parser)
{
    alias T = ParserType!parser;

    Result!(T[]) rep(in string input)
    {
        T[] values;
        string prev, next = input;
        for (;;) {
            auto result = parser(next);
            prev = next;
            if (result.isSuccess) {
                auto succ = result.toSuccess;
                values ~= succ.value;
                prev = next;
                next = succ.next;
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
    auto f = &rep!(s!"Hello");

    auto res1 = f("Hello, world!").toSuccess;
    assert(res1.value == ["Hello"]);
    assert(res1.next == ", world!");

    auto res2 = f("HelloHelloHello").toSuccess;
    assert(res2.value == ["Hello", "Hello", "Hello"]);
    assert(res2.next == "");

    auto res3 = f("HelloHelloHelloWorld").toSuccess;
    assert(res3.value == ["Hello", "Hello", "Hello"]);
    assert(res3.next == "World");

    auto res4 = f("WorldHello").toSuccess;
    assert(res4.value == []);
    assert(res4.next == "WorldHello");
}

template map(alias parser, alias fun)
{
    alias f = binaryFun!fun;
    alias T = ParserType!parser;
    alias U = typeof(f(T.init));

    Result!U map(in string input)
    {
        auto result = parser(input);
        if (result.isFailure) return result.toFailure.of!U;
        auto succ = result.toSuccess;
        return success(f(succ.value), succ.next);
    }
}

unittest
{
    import std.conv: to;

    auto f = &map!(s!"123", s => s.to!int);
    auto res1 = f("1234567").toSuccess;
    assert(res1.value == 123);
    assert(res1.next == "4567");
}

template chainl(alias p, alias op)
{
    import std.algorithm.iteration;

    alias chainl =
        map!(
            seq!(p, rep!(seq!(op, p))),
            vs => reduce!((acc, r) => r.left(acc, r.right))(vs.left, vs.right)
        );
}

unittest
{
    import std.conv;

    auto f = &chainl!(
        map!(reg!"[0-9]+", s => s.to!int),
        map!(s!"+", _ => (int a, int b) => a + b)
    );
    auto res1 = f("1+2+3").toSuccess;
    assert(res1.value == 6);
}