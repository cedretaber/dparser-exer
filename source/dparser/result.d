module dparser.result;

import std.conv : to;

abstract class Result(T)
{
    @property @safe pure bool isSuccess();
    @property @safe pure bool isFailure();
    @property pure Success!T toSuccess();
    @property pure Failure!T toFailure();
}

template ResultType(R)
{
    static if (is(R == Result!T, T))
        alias ResultType = T;
    else {
        import std.format : format;
        static assert(false, format!"Expected any Result, but: %s"(R.stringof));
    }
}

/**
 * パーズ成功を表す型
 */
class Success(T): Result!T
{
    T value;
    string next;

    this(T value, string next) {
        this.value = value;
        this.next = next;
    }

    @property @safe
    override pure
    bool isSuccess() {
        return true;
    }

    @property @safe
    override pure
    bool isFailure() {
        return false;
    }

    @property
    override pure
    Success!T toSuccess() {
        return this;
    }

    @property
    override pure
    Failure!T toFailure() {
        throw new Exception("Call Success#toFailure.");
    }

    @property
    override
    string toString() {
        return "Success(" ~ this.value.to!string ~ ", " ~ next ~ ")";
    }
}

Success!T success(T)(T value, string next)
{
    return new Success!T(value, next);
}

/**
 * パーズ失敗を表す型
 */
class Failure(T): Result!T
{
    string message;
    string next;

    this(in string message, in string next) {
        this.message = message;
        this.next = next;
    }

    @property @safe
    override pure
    bool isSuccess() {
        return false;
    }

    @property @safe
    override pure
    bool isFailure() {
        return true;
    }

    @property
    override pure
    Success!T toSuccess() {
        throw new Exception("Call Failure#toSuccess.");
    }

    @property
    override pure
    Failure!T toFailure() {
        return this;
    }

    @property
    pure
    Result!U of(U)() {
        return failure!U(this.message, this.next);
    }

    @property
    override
    string toString() {
        return "Failure(" ~ message ~ ", " ~ next ~ ")";
    }
}

Failure!T failure(T)(string message, string next)
{
    return new Failure!T(message, next);
}