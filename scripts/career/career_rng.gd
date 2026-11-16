class_name CareerRng
extends RefCounted
# CPython's random.Random, bit for bit: same MT19937 core, same int/string
# seeding (sha512 of the seed text fed into init_by_array) and the same
# random()/getrandbits()/randbelow()/choice()/uniform() surfaces. The career
# port needs it because the prototype derives transfer demands, response dates
# and contract terms from `random.Random("<seed>:<salt>")`; without the exact
# generator the ported numbers drift from the reference implementation.
# Godot's HashingContext stops at SHA-256, so SHA-512 is spelled out below.

const N := 624
const M := 397
const MATRIX_A := 0x9908b0df
const UPPER_MASK := 0x80000000
const LOWER_MASK := 0x7fffffff
const MASK32 := 0xffffffff

const SHA512_K := [
	4794697086780616226, 8158064640168781261, -5349999486874862801, -1606136188198331460,
	4131703408338449720, 6480981068601479193, -7908458776815382629, -6116909921290321640,
	-2880145864133508542, 1334009975649890238, 2608012711638119052, 6128411473006802146,
	8268148722764581231, -9160688886553864527, -7215885187991268811, -4495734319001033068,
	-1973867731355612462, -1171420211273849373, 1135362057144423861, 2597628984639134821,
	3308224258029322869, 5365058923640841347, 6679025012923562964, 8573033837759648693,
	-7476448914759557205, -6327057829258317296, -5763719355590565569, -4658551843659510044,
	-4116276920077217854, -3051310485924567259, 489312712824947311, 1452737877330783856,
	2861767655752347644, 3322285676063803686, 5560940570517711597, 5996557281743188959,
	7280758554555802590, 8532644243296465576, -9096487096722542874, -7894198246740708037,
	-6719396339535248540, -6333637450476146687, -4446306890439682159, -4076793802049405392,
	-3345356375505022440, -2983346525034927856, -860691631967231958, 1182934255886127544,
	1847814050463011016, 2177327727835720531, 2830643537854262169, 3796741975233480872,
	4115178125766777443, 5681478168544905931, 6601373596472566643, 7507060721942968483,
	8399075790359081724, 8693463985226723168, -8878714635349349518, -8302665154208450068,
	-8016688836872298968, -6606660893046293015, -4685533653050689259, -4147400797238176981,
	-3880063495543823972, -3348786107499101689, -1523767162380948706, -757361751448694408,
	500013540394364858, 748580250866718886, 1242879168328830382, 1977374033974150939,
	2944078676154940804, 3659926193048069267, 4368137639120453308, 4836135668995329356,
	5532061633213252278, 6448918945643986474, 6902733635092675308, 7801388544844847127,
]
const SHA512_IV := [
	7640891576956012808, -4942790177534073029, 4354685564936845355, -6534734903238641935,
	5840696475078001361, -7276294671716946913, 2270897969802886507, 6620516959819538809,
]
var _mt: PackedInt64Array = PackedInt64Array()
var _index := N


static func seeded(seed_text: String) -> CareerRng:
	var rng := CareerRng.new()
	rng._seed_text(seed_text)
	return rng


func _init() -> void:
	_mt.resize(N)
	for index in range(N):
		_mt[index] = 0
	_init_genrand(5489)


func _seed_text(seed_text: String) -> void:
	# CPython: int.from_bytes(a + sha512(a).digest()) then one 32-bit word per
	# 4 bytes, least significant first.
	var payload := seed_text.to_utf8_buffer()
	var raw := payload + _sha512(payload)
	var key: Array[int] = []
	var cursor := raw.size()
	while cursor > 0:
		var take := mini(4, cursor)
		var word := 0
		for offset in range(take):
			word = (word << 8) | int(raw[cursor - take + offset])
		key.append(word)
		cursor -= take
	_init_by_array(key)


func _init_genrand(seed_value: int) -> void:
	_mt[0] = seed_value & MASK32
	for index in range(1, N):
		var previous := _mt[index - 1]
		_mt[index] = (1812433253 * (previous ^ (previous >> 30)) + index) & MASK32
	_index = N


func _init_by_array(key: Array[int]) -> void:
	_init_genrand(19650218)
	var i := 1
	var j := 0
	var key_length := key.size()
	var rounds := maxi(N, key_length)
	for _round in range(rounds):
		var previous := _mt[i - 1]
		_mt[i] = ((_mt[i] ^ ((previous ^ (previous >> 30)) * 1664525)) \
			+ key[j] + j) & MASK32
		i += 1
		j += 1
		if i >= N:
			_mt[0] = _mt[N - 1]
			i = 1
		if j >= key_length:
			j = 0
	for _round in range(N - 1):
		var previous := _mt[i - 1]
		_mt[i] = ((_mt[i] ^ ((previous ^ (previous >> 30)) * 1566083941)) - i) & MASK32
		i += 1
		if i >= N:
			_mt[0] = _mt[N - 1]
			i = 1
	_mt[0] = UPPER_MASK


func _twist() -> void:
	for index in range(N):
		var y := (_mt[index] & UPPER_MASK) | (_mt[(index + 1) % N] & LOWER_MASK)
		var shifted: int = y >> 1
		if (y & 1) != 0:
			shifted ^= MATRIX_A
		_mt[index] = _mt[(index + M) % N] ^ shifted
	_index = 0


func next_uint32() -> int:
	if _index >= N:
		_twist()
	var y := _mt[_index]
	_index += 1
	y ^= y >> 11
	y ^= (y << 7) & 0x9d2c5680
	y ^= (y << 15) & 0xefc60000
	y ^= y >> 18
	return y & MASK32


func next_float() -> float:
	var high: int = next_uint32() >> 5
	var low: int = next_uint32() >> 6
	return (float(high) * 67108864.0 + float(low)) * (1.0 / 9007199254740992.0)


func getrandbits(bits: int) -> int:
	if bits <= 32:
		return next_uint32() >> (32 - bits)
	var value := 0
	var remaining := bits
	while remaining > 0:
		var take := mini(32, remaining)
		value = (value << take) | (next_uint32() >> (32 - take))
		remaining -= take
	return value


func randbelow(limit: int) -> int:
	if limit <= 0:
		return 0
	# CPython draws n.bit_length() bits and rejects out-of-range draws; the
	# rejection matters because it consumes the stream exactly like Python.
	var bits := 0
	var probe := limit
	while probe > 0:
		probe >>= 1
		bits += 1
	for _attempt in range(4096):
		var value := getrandbits(bits)
		if value < limit:
			return value
	return 0


func randint(low: int, high: int) -> int:
	return low + randbelow(high - low + 1)


func choice(values: Array):
	return values[randbelow(values.size())]


func uniform(low: float, high: float) -> float:
	return low + (high - low) * next_float()


static func python_round(value: float) -> int:
	# Python's round() is half-to-even; int(round(x)) shows up in the wage and
	# contract formulas, so the port must not use GDScript's half-away-from-zero.
	var base := int(floor(value))
	var fraction := value - float(base)
	if fraction > 0.5:
		return base + 1
	if fraction < 0.5:
		return base
	return base if base % 2 == 0 else base + 1


static func _shr(value: int, bits: int) -> int:
	return (value >> bits) & ((1 << (64 - bits)) - 1)


static func _rotr(value: int, bits: int) -> int:
	return _shr(value, bits) | (value << (64 - bits))


static func _sha512(data: PackedByteArray) -> PackedByteArray:
	var message := data.duplicate()
	var bit_length := data.size() * 8
	message.append(0x80)
	while message.size() % 128 != 112:
		message.append(0)
	for _zero in range(8):
		message.append(0)
	for shift in range(7, -1, -1):
		message.append((bit_length >> (shift * 8)) & 0xff)
	var state: Array = SHA512_IV.duplicate(true)
	for block_start in range(0, message.size(), 128):
		var words: Array[int] = []
		words.resize(80)
		for index in range(16):
			var word := 0
			for byte_offset in range(8):
				word = (word << 8) | int(message[block_start + index * 8 + byte_offset])
			words[index] = word
		for index in range(16, 80):
			var s0 := _rotr(words[index - 15], 1) ^ _rotr(words[index - 15], 8) \
				^ _shr(words[index - 15], 7)
			var s1 := _rotr(words[index - 2], 19) ^ _rotr(words[index - 2], 61) \
				^ _shr(words[index - 2], 6)
			words[index] = words[index - 16] + s0 + words[index - 7] + s1
		var a: int = state[0]
		var b: int = state[1]
		var c: int = state[2]
		var d: int = state[3]
		var e: int = state[4]
		var f: int = state[5]
		var g: int = state[6]
		var h: int = state[7]
		for index in range(80):
			var sum1 := _rotr(e, 14) ^ _rotr(e, 18) ^ _rotr(e, 41)
			var choice_bits := (e & f) ^ (~e & g)
			var temp1: int = h + sum1 + choice_bits + SHA512_K[index] + words[index]
			var sum0 := _rotr(a, 28) ^ _rotr(a, 34) ^ _rotr(a, 39)
			var majority := (a & b) ^ (a & c) ^ (b & c)
			var temp2: int = sum0 + majority
			h = g
			g = f
			f = e
			e = d + temp1
			d = c
			c = b
			b = a
			a = temp1 + temp2
		state[0] += a
		state[1] += b
		state[2] += c
		state[3] += d
		state[4] += e
		state[5] += f
		state[6] += g
		state[7] += h
	var digest := PackedByteArray()
	for word in state:
		for shift in range(7, -1, -1):
			digest.append((word >> (shift * 8)) & 0xff)
	return digest
