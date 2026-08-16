class_name SimClock
extends RefCounted
## Orologio a passo fisso: rende la simulazione deterministica e testabile.
##
## Il gioco chiama advance(delta) da _process; l'orologio accumula il tempo ed
## emette N tick di durata esatta. La logica ascolta `ticked` e non vede mai il
## delta reale del frame — così lo stesso seed dà sempre lo stesso risultato,
## a 30 come a 144 fps.
##
##   var clock := SimClock.new(1.0 / 20.0)   # 20 tick al secondo
##   clock.ticked.connect(_on_tick)
##   clock.advance(get_process_delta_time())
##
## Per il progresso offline dell'idle: clock.advance_seconds(3600).

signal ticked(index: int, step: float)
## Emesso una volta sola dopo un gruppo di tick: comodo per aggiornare la UI
## una volta invece che per ogni tick.
signal batch_done(count: int)

## Quanti tick al massimo si possono emettere in una singola advance().
## Evita che un frame lunghissimo (finestra spostata, breakpoint) blocchi il gioco.
const MAX_TICKS_PER_ADVANCE := 600

## Tolleranza sul confronto con lo step. Sommare 60 delta da 1/60 dà
## 0.9999999999999999, non 1.0: senza epsilon si perderebbe un tick ogni secondo.
const EPSILON := 1e-9

var step: float
var speed: float = 1.0
var paused: bool = false
var tick_count: int = 0

var _accumulator: float = 0.0


func _init(step_seconds: float = 1.0 / 30.0) -> void:
	step = step_seconds


## Da chiamare ogni frame. Restituisce quanti tick sono stati emessi.
func advance(delta: float) -> int:
	if paused or delta <= 0.0:
		return 0
	_accumulator += delta * speed

	var emitted := 0
	while _accumulator >= step - EPSILON and emitted < MAX_TICKS_PER_ADVANCE:
		_accumulator -= step
		tick_count += 1
		emitted += 1
		ticked.emit(tick_count, step)

	if emitted >= MAX_TICKS_PER_ADVANCE:
		_accumulator = 0.0

	if emitted > 0:
		batch_done.emit(emitted)
	return emitted


## Il tempo simulato accumulato che non e' ancora diventato un tick, fra 0 e
## `step`.
##
## Serve a **disegnare fra un tick e l'altro**. La logica avanza a scatti esatti
## — venti al secondo in questo gioco — ed e' quello che la rende deterministica
## e riproducibile con lo stesso seme. Ma lo schermo ne disegna cento e passa, e
## se ogni disegno mostra lo stesso valore fino al tick successivo, tutto cio'
## che si muove si muove a scatti di un ventesimo di secondo.
##
## Chi disegna puo' chiedere questo resto e mostrare **dove sara'** la cosa che
## si muove, invece di dove era all'ultimo tick. La simulazione non se ne
## accorge: e' una sola sottrazione, e sta tutta dalla parte della vista.
func resto() -> float:
	return _accumulator


## Simula N secondi in un colpo solo, ignorando pause e limite per-frame.
## Usato dal progresso offline e dai test.
func advance_seconds(seconds: float) -> int:
	if seconds <= 0.0:
		return 0
	var ticks := int(floorf((seconds + _accumulator) / step))
	_accumulator = fposmod(seconds + _accumulator, step)
	for i in ticks:
		tick_count += 1
		ticked.emit(tick_count, step)
	if ticks > 0:
		batch_done.emit(ticks)
	return ticks


## Secondi di simulazione trascorsi dall'inizio.
func elapsed() -> float:
	return tick_count * step


func reset() -> void:
	tick_count = 0
	_accumulator = 0.0
	paused = false


func _to_string() -> String:
	return "SimClock(step=%.4f, tick=%d, speed=%.1fx)" % [step, tick_count, speed]
