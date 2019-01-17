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

template chainl(alias p, alias op)
{
    import std.algorithm.iteration;

    alias chainl =
        map!(
            seq!(p, rep!(seq!(op, p))),
            vs => reduce!((acc, r) => r.left(acc, r.right))(vs.left, vs.right)
        );
}