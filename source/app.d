import std.stdio;

void main()
{
	// ct();
	peg();
	// runtime();
}

void runtime()
{
	import dparser.parser;

	auto str = "Hello, world!";
	auto hello = new StringParser("Hello");

	auto res = hello(str);
	writeln(res);

	hello = new StringParser("Hello, ");
	auto world = new StringParser("world!");
	auto hw = hello.cat(world);

	auto res2 = hw(str);
	writeln(res2);

	auto hello2 = new StringParser("Hello").rep!string();
	auto res3 = hello2("HelloHelloHello");
	writeln(res3);
	res3 = hello2("HelloHelloHelloWorld");
	writeln(res3);
	res3 = hello2("");
	writeln(res3);

	import std.conv;
	auto onetwothree = new StringParser("123").map((string s) => s.to!int);
	auto res4 = onetwothree("123456");
	writeln(res4);

	auto somenum = new RegexParser("[0-9]+");
	auto res5 = somenum("123-456");
	writeln(res5);

	auto snums =
		somenum.map((string s) => s.to!int)
			.chainl(new StringParser("+").map!(string, int delegate(int, int))(_ => (a, b) => a + b));
	auto res6 = snums("1+2+3");
	writeln(res6);

	auto pmnums =
		new RegexParser("[0-9]+").map((string s) => s.to!int).chainl(
			new StringParser("+").or(new StringParser("-")).map!(string, int delegate(int, int))((op) {
				return (a, b) {
					switch (op) {
						case "+": return a + b;
						case "-": return a - b;
						default: return 0;
					}
				};
			})
		);
	auto res7 = pmnums("13+4-5");
	writeln(res7);
}

void peg()
{
	import dparser.peg;

	writeln(new E()("42+99"));
	writeln(new E()("1+2*3+4"));
	writeln(new E()("(1+2)*(3+4)"));
}

void ct()
{
	import dparser.ct.parser;

	auto str = "Hello, world!";

	{
		auto hello = &s!("Hello");
		auto res = hello(str);
		writeln(res);
	}

	{
		auto res1 = seq!(s!("Hello, "), s!("world!"))(str);
		writeln(res1);

		auto res2 = seq!(s!"hoge", s!"fuga")("hogehoge");
		writeln(res2);
	}

	{
		auto f = &alt!(s!"Hello", s!"World");
		auto res1 = f(str);
		writeln(res1);

		auto res2 = f("WorldHello");
		writeln(res2);

		auto res3 = f("hogehoge");
		writeln(res3);
	}

	{
		auto f = &rep!(s!"Hello");

		auto res1 = f(str);
		writeln(res1);

		auto res2 = f("HelloHelloHello");
		writeln(res2);

		auto res3 = f("HelloHelloHelloWorld");
		writeln(res3);

		auto res4 = f("WorldHello");
		writeln(res4);
	}

	{
		import std.conv;
		auto f = &map!(s!"123", s => s.to!int);
		auto res1 = f("1234567");
		writeln(res1);
		writeln(res1.toSuccess.value + 2);
	}

	{
		auto f = &reg!("[0-9]+");
		auto res1 = f("123-4567");
		writeln(res1);
	}

	{
		import std.conv;

		auto f = &chainl!(
			map!(reg!"[0-9]+", s => s.to!int),
			map!(s!"+", _ => (int a, int b) => a + b)
		);
		auto res1 = f("1+2+3");
		writeln(res1);

		auto res2 = f("1+2*3+4");
		writeln(res2);
	}
}