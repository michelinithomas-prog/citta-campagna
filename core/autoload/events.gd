extends Node
## Bus di segnali globale. Disaccoppia la logica dalla UI: chi produce un evento
## non deve sapere chi lo ascolta.
##
##   Events.currency_changed.emit("gold", 12.0, 3.0)
##   Events.game_over.connect(_on_game_over)
##
## Qui stanno solo i segnali che attraversano le scene. I segnali interni a un
## sistema restano sul sistema (vedi Wallet.changed, SimClock.ticked).

# --- flusso di gioco ----------------------------------------------------

## Una nuova partita è iniziata (dopo il menu o dopo un restart).
signal run_started(seed_value: int)
## La partita è finita. `stats` è libero: punteggio, round raggiunto, tempo...
signal run_ended(won: bool, stats: Dictionary)
## Pausa attivata o disattivata.
signal pause_toggled(paused: bool)

# --- economia -----------------------------------------------------------

## Inoltrato dal gioco quando un Wallet cambia, per aggiornare la UI.
signal currency_changed(currency: String, amount: float, delta: float)

# --- feedback -----------------------------------------------------------

## Messaggio a comparsa. `kind`: "info" | "good" | "bad".
signal toast_requested(text: String, kind: String)
## Richiesta di scossa della camera. `strength` in pixel, `duration` in secondi.
signal shake_requested(strength: float, duration: float)

# --- contenuti ----------------------------------------------------------

## I JSON di contenuto o di tuning sono stati ricaricati a caldo (F5).
signal content_reloaded


## Scorciatoia: Events.toast("Oro insufficiente", "bad")
func toast(text: String, kind: String = "info") -> void:
	toast_requested.emit(text, kind)


func shake(strength: float = 6.0, duration: float = 0.2) -> void:
	shake_requested.emit(strength, duration)
