class_name Rules
extends RefCounted
## Шахматные правила и ИИ. Фигура = цвет * тип: белые > 0, чёрные < 0.
## Типы: 1 пешка, 2 конь, 3 слон, 4 ладья, 5 ферзь, 6 король.

const P := 1
const N := 2
const B := 3
const R := 4
const Q := 5
const K := 6
const VAL := [0, 100, 320, 330, 500, 900, 0]
const KN := [[-2,-1],[-2,1],[-1,-2],[-1,2],[1,-2],[1,2],[2,-1],[2,1]]
const KG := [[-1,-1],[-1,0],[-1,1],[0,-1],[0,1],[1,-1],[1,0],[1,1]]
const RD := [[-1,0],[1,0],[0,-1],[0,1]]
const BD := [[-1,-1],[-1,1],[1,-1],[1,1]]
const NAMES := ["", "Пешка", "Конь", "Слон", "Ладья", "Ферзь", "Король"]
const LETTERS := ["", "", "N", "B", "R", "Q", "K"]

static func init_state() -> Dictionary:
	var b := PackedInt32Array()
	b.resize(64)
	var back := [R, N, B, Q, K, B, N, R]
	for c in 8:
		b[c] = -back[c]
		b[8 + c] = -P
		b[48 + c] = P
		b[56 + c] = back[c]
	return {"b": b, "turn": 1, "cr": PackedInt32Array([1, 1, 1, 1]), "ep": -1}

static func copy_state(s: Dictionary) -> Dictionary:
	return {"b": s.b.duplicate(), "turn": s.turn, "cr": s.cr.duplicate(), "ep": s.ep}

static func sq_name(i: int) -> String:
	return "abcdefgh"[i & 7] + str(8 - (i >> 3))

static func sq_index(s: String) -> int:
	if s.length() < 2:
		return -1
	var c := "abcdefgh".find(s[0])
	if c < 0 or not s[1].is_valid_int():
		return -1
	var r := 8 - int(s[1])
	if r < 0 or r > 7:
		return -1
	return r * 8 + c

static func attacked(b: PackedInt32Array, sq: int, by: int) -> bool:
	var r := sq >> 3
	var c := sq & 7
	var pr := r + 1 if by == 1 else r - 1
	if pr >= 0 and pr < 8:
		for dc in [-1, 1]:
			var cc: int = c + dc
			if cc >= 0 and cc < 8 and b[pr * 8 + cc] == by * P:
				return true
	for d in KN:
		var rr: int = r + d[0]
		var cc: int = c + d[1]
		if rr >= 0 and rr < 8 and cc >= 0 and cc < 8 and b[rr * 8 + cc] == by * N:
			return true
	for d in KG:
		var rr: int = r + d[0]
		var cc: int = c + d[1]
		if rr >= 0 and rr < 8 and cc >= 0 and cc < 8 and b[rr * 8 + cc] == by * K:
			return true
	for d in RD:
		var rr: int = r + d[0]
		var cc: int = c + d[1]
		while rr >= 0 and rr < 8 and cc >= 0 and cc < 8:
			var p := b[rr * 8 + cc]
			if p != 0:
				if p == by * R or p == by * Q:
					return true
				break
			rr += d[0]
			cc += d[1]
	for d in BD:
		var rr: int = r + d[0]
		var cc: int = c + d[1]
		while rr >= 0 and rr < 8 and cc >= 0 and cc < 8:
			var p := b[rr * 8 + cc]
			if p != 0:
				if p == by * B or p == by * Q:
					return true
				break
			rr += d[0]
			cc += d[1]
	return false

static func king_sq(b: PackedInt32Array, color: int) -> int:
	return b.find(color * K)

static func in_check(s: Dictionary) -> bool:
	var k := king_sq(s.b, s.turn)
	return k >= 0 and attacked(s.b, k, -s.turn)

static func _mv(f: int, t: int, p: int, x: int) -> Dictionary:
	return {"f": f, "t": t, "p": p, "x": x, "promo": 0, "dbl": false, "ep_cap": -1, "castle": 0}

static func gen(s: Dictionary, caps_only := false) -> Array:
	var b: PackedInt32Array = s.b
	var t: int = s.turn
	var out := []
	for sq in 64:
		var pc := b[sq]
		if pc == 0 or sign(pc) != t:
			continue
		var ty: int = abs(pc)
		var r := sq >> 3
		var c := sq & 7
		if ty == P:
			var d := -1 if t == 1 else 1
			var nr := r + d
			var last := 0 if t == 1 else 7
			var start := 6 if t == 1 else 1
			if nr < 0 or nr > 7:
				continue
			var fwd := nr * 8 + c
			if b[fwd] == 0:
				if nr == last:
					var m := _mv(sq, fwd, P, 0)
					m.promo = Q
					out.append(m)
				elif not caps_only:
					out.append(_mv(sq, fwd, P, 0))
					var two := (r + 2 * d) * 8 + c
					if r == start and b[two] == 0:
						var m2 := _mv(sq, two, P, 0)
						m2.dbl = true
						out.append(m2)
			for dc in [-1, 1]:
				var cc: int = c + dc
				if cc < 0 or cc > 7:
					continue
				var to := nr * 8 + cc
				if b[to] != 0 and sign(b[to]) == -t:
					var m3 := _mv(sq, to, P, b[to])
					if nr == last:
						m3.promo = Q
					out.append(m3)
				elif to == s.ep and b[to] == 0:
					var m4 := _mv(sq, to, P, -t * P)
					m4.ep_cap = r * 8 + cc
					out.append(m4)
		elif ty == N or ty == K:
			for d in (KN if ty == N else KG):
				var rr: int = r + d[0]
				var cc: int = c + d[1]
				if rr < 0 or rr > 7 or cc < 0 or cc > 7:
					continue
				var to := rr * 8 + cc
				var q := b[to]
				if q != 0:
					if sign(q) == -t:
						out.append(_mv(sq, to, ty, q))
				elif not caps_only:
					out.append(_mv(sq, to, ty, 0))
			if ty == K and not caps_only:
				var base := 56 if t == 1 else 0
				var ci := 0 if t == 1 else 2
				if sq == base + 4 and not attacked(b, sq, -t):
					if s.cr[ci] == 1 and b[base + 5] == 0 and b[base + 6] == 0 and b[base + 7] == t * R and not attacked(b, base + 5, -t) and not attacked(b, base + 6, -t):
						var mk := _mv(sq, base + 6, K, 0)
						mk.castle = 1
						out.append(mk)
					if s.cr[ci + 1] == 1 and b[base + 3] == 0 and b[base + 2] == 0 and b[base + 1] == 0 and b[base] == t * R and not attacked(b, base + 3, -t) and not attacked(b, base + 2, -t):
						var mq := _mv(sq, base + 2, K, 0)
						mq.castle = 2
						out.append(mq)
		else:
			var dirs: Array = RD if ty == R else (BD if ty == B else RD + BD)
			for d in dirs:
				var rr: int = r + d[0]
				var cc: int = c + d[1]
				while rr >= 0 and rr < 8 and cc >= 0 and cc < 8:
					var to := rr * 8 + cc
					var q := b[to]
					if q != 0:
						if sign(q) == -t:
							out.append(_mv(sq, to, ty, q))
						break
					if not caps_only:
						out.append(_mv(sq, to, ty, 0))
					rr += d[0]
					cc += d[1]
	var legal := []
	for m in out:
		var ns := apply(s, m)
		var k := king_sq(ns.b, t)
		if k >= 0 and not attacked(ns.b, k, -t):
			legal.append(m)
	return legal

static func apply(s: Dictionary, m: Dictionary) -> Dictionary:
	var b: PackedInt32Array = s.b.duplicate()
	var t: int = s.turn
	var cr: PackedInt32Array = s.cr.duplicate()
	var pc := b[m.f]
	b[m.f] = 0
	if m.ep_cap >= 0:
		b[m.ep_cap] = 0
	if m.promo != 0:
		pc = t * m.promo
	b[m.t] = pc
	if m.castle != 0:
		var base := 56 if t == 1 else 0
		if m.castle == 1:
			b[base + 5] = b[base + 7]
			b[base + 7] = 0
		else:
			b[base + 3] = b[base]
			b[base] = 0
	if m.p == K:
		var ci := 0 if t == 1 else 2
		cr[ci] = 0
		cr[ci + 1] = 0
	for q in [m.f, m.t]:
		if q == 63: cr[0] = 0
		if q == 56: cr[1] = 0
		if q == 7: cr[2] = 0
		if q == 0: cr[3] = 0
	var ep := -1
	if m.dbl:
		ep = (m.f + m.t) / 2
	return {"b": b, "turn": -t, "cr": cr, "ep": ep}

# ---------------- ИИ ----------------
static func evaluate(b: PackedInt32Array) -> int:
	var s := 0.0
	for i in 64:
		var pc := b[i]
		if pc == 0:
			continue
		var r := i >> 3
		var c := i & 7
		var t: int = abs(pc)
		var w := pc > 0
		var cen: float = 3.5 - max(abs(r - 3.5), abs(c - 3.5))
		var v: float = VAL[t]
		match t:
			P: v += ((6 - r) if w else (r - 1)) * 8 + (cen * 5 if c > 1 and c < 6 else 0)
			N: v += cen * 12
			B: v += cen * 6
			Q: v += cen * 3
			R: v += 20 if (r == 1 if w else r == 6) else 0
			K: v += -cen * 10 + (12 if (r == 7 if w else r == 0) else 0)
		s += v if w else -v
	return int(s)

static func _score(m: Dictionary) -> int:
	var sc := 0
	if m.x != 0:
		sc += VAL[abs(m.x)] * 10 - VAL[m.p] + 10
	if m.promo != 0:
		sc += 8000
	return sc

static func order(ms: Array) -> Array:
	ms.sort_custom(func(a, b): return _score(a) > _score(b))
	return ms

static func qs(s: Dictionary, a: int, bt: int, qd: int) -> int:
	var st: int = s.turn * evaluate(s.b)
	if st >= bt or qd <= 0:
		return st
	if st > a:
		a = st
	for m in order(gen(s, true)):
		var v := -qs(apply(s, m), -bt, -a, qd - 1)
		if v >= bt:
			return v
		if v > a:
			a = v
	return a

static func nega(s: Dictionary, d: int, a: int, bt: int, ply: int) -> int:
	if d == 0:
		return qs(s, a, bt, 3)
	var ms := gen(s)
	if ms.is_empty():
		return -100000 + ply if in_check(s) else 0
	for m in order(ms):
		var v := -nega(apply(s, m), d - 1, -bt, -a, ply + 1)
		if v >= bt:
			return v
		if v > a:
			a = v
	return a

static func best_move(s: Dictionary, depth: int) -> Dictionary:
	var ms := order(gen(s))
	if ms.is_empty():
		return {}
	var noise := 90 if depth == 1 else (18 if depth == 2 else 4)
	var best: Dictionary = ms[0]
	var bv := -1000000000
	for m in ms:
		var v := -nega(apply(s, m), depth - 1, -1000000000, -bv + noise, 1) + randi() % (noise + 1)
		if v > bv:
			bv = v
			best = m
	return best

static func perft(s: Dictionary, d: int) -> int:
	if d == 0:
		return 1
	var n := 0
	for m in gen(s):
		n += perft(apply(s, m), d - 1)
	return n
