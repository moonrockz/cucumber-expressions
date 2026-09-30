///|
fn strings(n : Int) -> Array[String?] {
  Array::makei(n, i => Some((i + 1).to_string()))
}

///|
test "captures arity: zip and map give a flat function" {
  let caps = Captures::int().zip(Captures::string()).zip(Captures::int())
  let joined = caps.map((a, b, c) => "\{a}-\{b}-\{c}")
  inspect(joined.count, content="3")
  inspect(joined.run("t", [Some("1"), Some("x"), Some("3")]), content="1-x-3")
}

///|
test "captures arity: eight values" {
  let caps = Captures::int()
    .zip(Captures::int())
    .zip(Captures::int())
    .zip(Captures::int())
    .zip(Captures::int())
    .zip(Captures::int())
    .zip(Captures::int())
    .zip(Captures::int())
    .map((a, b, c, d, e, f, g, h) => a + b + c + d + e + f + g + h)
  inspect(caps.count, content="8")
  inspect(caps.run("t", strings(8)), content="36")
}

///|
test "captures arity: the ninth value folds the first eight into a tuple" {
  let caps = Captures::int()
    .zip(Captures::int())
    .zip(Captures::int())
    .zip(Captures::int())
    .zip(Captures::int())
    .zip(Captures::int())
    .zip(Captures::int())
    .zip(Captures::int())
    .zip(Captures::int())
    .map((ah, i) => ah.0 + ah.7 + i)
  inspect(caps.count, content="9")
  inspect(caps.run("t", strings(9)), content="18")
}

///|
test "captures arity: 16 and 22 values" {
  let s = Captures::string()
  let c16 = s
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .map((ao, p) => {
      let (ah, i, j, k, l, m, n, o) = ao
      let (a, b, c, d, e, f, g, h) = ah
      [a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p].join(",")
    })
  inspect(c16.count, content="16")
  inspect(
    c16.run("t", strings(16)),
    content="1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16",
  )
  let c22 = s
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .zip(s)
    .map((ao, p, q, r, s2, t, u, v) => {
      let (ah, _, _, _, _, _, _, o) = ao
      "\{ah.0} \{o} \{p} \{q} \{r} \{s2} \{t} \{u} \{v}"
    })
  inspect(c22.count, content="22")
  inspect(c22.run("t", strings(22)), content="1 15 16 17 18 19 20 21 22")
}

///|
test "captures arity: mapped parts compose" {
  let pair = Captures::int().zip(Captures::int()).map((x, y) => (x, y))
  let name = Captures::string()
  let caps = pair
    .zip(name)
    .zip(pair)
    .map((a, n, b) => "\{n}:\{a.0},\{a.1}->\{b.0},\{b.1}")
  inspect(caps.count, content="5")
  inspect(
    caps.run("t", [Some("1"), Some("2"), Some("go"), Some("3"), Some("4")]),
    content="go:1,2->3,4",
  )
}

///|
test "captures arity: the index of a missing group counts all groups before it" {
  let caps = Captures::int()
    .zip(Captures::int())
    .zip(Captures::int())
    .map((a, b, c) => a + b + c)
  let message = try caps.run("sum", [Some("1"), Some("2"), None]) catch {
    e => e.to_string()
  } noraise {
    _ => fail("expected an error")
  }
  inspect(
    message,
    content="Capture group 3 of the parameter type {sum} did not match",
  )
}
