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