extends TestCase

var clock: SimClock
var ticks: Array[int]


func before_each() -> void:
	clock = SimClock.new(0.1)
	ticks = []
	clock.ticked.connect(func(index: int, _step: float) -> void: ticks.append(index))


func after_each() -> void:
	clock = null  # rompe il ciclo lambda ↔ istanza di test


func test_nessun_tick_sotto_lo_step() -> void:
	assert_eq(clock.advance(0.05), 0)
	assert_eq(ticks.size(), 0)


func test_il_resto_si_accumula_fra_i_frame() -> void:
	clock.advance(0.06)
	clock.advance(0.06)
	assert_eq(ticks.size(), 1, "0.06 + 0.06 = 0.12 → un tick, 0.02 in cassa")


func test_un_delta_lungo_emette_piu_tick() -> void:
	assert_eq(clock.advance(0.35), 3)
	assert_eq(ticks, [1, 2, 3] as Array[int])


func test_in_pausa_non_ticca() -> void:
	clock.paused = true
	assert_eq(clock.advance(1.0), 0)


func test_la_velocita_moltiplica_il_tempo() -> void:
	clock.speed = 2.0
	assert_eq(clock.advance(0.5), 10)


func test_advance_seconds_per_il_progresso_offline() -> void:
	assert_eq(clock.advance_seconds(60.0), 600)
	assert_almost(clock.elapsed(), 60.0)


func test_advance_seconds_ignora_la_pausa() -> void:
	clock.paused = true
	assert_eq(clock.advance_seconds(1.0), 10)


func test_il_limite_per_frame_protegge_dai_frame_lunghi() -> void:
	var emitted := clock.advance(10000.0)
	assert_eq(emitted, SimClock.MAX_TICKS_PER_ADVANCE)


func test_batch_done_riassume_il_gruppo() -> void:
	var batches: Array[int] = []
	clock.batch_done.connect(func(count: int) -> void: batches.append(count))
	clock.advance(0.35)
	assert_eq(batches, [3] as Array[int], "un solo batch_done per advance, non uno per tick")


func test_reset_azzera_tutto() -> void:
	clock.advance(0.35)
	clock.reset()
	assert_eq(clock.tick_count, 0)
	assert_eq(clock.advance(0.05), 0, "anche l'accumulatore deve essere azzerato")


func test_lo_stesso_tempo_totale_da_gli_stessi_tick() -> void:
	var a := SimClock.new(0.1)
	var b := SimClock.new(0.1)
	a.advance(1.0)
	for i in 60:
		b.advance(1.0 / 60.0)
	# La somma di 60 delta da 1/60 non fa esattamente 1.0: si tollera un tick
	# di scarto, non di più (una deriva vera si vedrebbe subito).
	assert_lt(absi(a.tick_count - b.tick_count), 2, "un frame lungo o tanti corti: stesso risultato")
	assert_eq(a.tick_count, 10)


func test_un_secondo_di_frame_a_60fps_non_perde_tick() -> void:
	var clock := SimClock.new(0.1)
	for i in 600:
		clock.advance(1.0 / 60.0)
	assert_eq(clock.tick_count, 100, "10 secondi a 60fps = 100 tick da 0.1s")
