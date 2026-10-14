extends Node

## Server-authoritative day/night clock.
##
## Only the host (multiplayer authority) advances `time`. Clients never
## simulate their own clock — they just render whatever the host last sent
## them, so nobody can locally speed up or skip time.

signal game_time(time: float)
signal time_tick(day: int, hour: int, minute: int)
signal time_tick_day(day: int)

const MINUTES_PER_HOUR: int = 60
const MINUTES_PER_DAY: int = 24 * MINUTES_PER_HOUR
const GAME_MINUTE_DURATION: float = TAU / MINUTES_PER_DAY

## How often (seconds of real time) the host pushes a fresh time snapshot to
## clients. Self-correcting, so packet loss just means the next sync fixes it.
const SYNC_INTERVAL: float = 0.1

var initial_day: int = 1
var initial_hour: int = 12
var initial_minute: int = 0

var game_speed: float = 5.0

var time: float = 0.0
var current_minute: int = -1
var current_day: int = -1

var _sync_accumulator: float = 0.0


func _ready() -> void:
	set_initial_time()
	multiplayer.peer_connected.connect(_on_peer_connected)


func _process(delta: float) -> void:
	# Clients don't touch `time` themselves - they only update it when a
	# sync RPC arrives from the host (see _receive_time_sync below).
	if not _is_time_authority():
		return

	time += delta * game_speed * GAME_MINUTE_DURATION
	game_time.emit(time)
	recalculate_time()

	if multiplayer.has_multiplayer_peer():
		_sync_accumulator += delta
		if _sync_accumulator >= SYNC_INTERVAL:
			_sync_accumulator = 0.0
			_receive_time_sync.rpc(time, game_speed)


func set_initial_time() -> void:
	var initial_total_minutes := (initial_day * MINUTES_PER_DAY) + (initial_hour * MINUTES_PER_HOUR) + initial_minute
	time = initial_total_minutes * GAME_MINUTE_DURATION
	current_minute = -1
	current_day = -1


## UI entry point. Only actually changes anything when called on the host;
## a request coming from a plain client is silently ignored, so a client
## can never speed up or skip time - by itself or via a modified client.
func request_set_game_speed(new_speed: float) -> void:
	if not _is_time_authority():
		return
	game_speed = new_speed


func recalculate_time() -> void:
	var total_minutes := int(time / GAME_MINUTE_DURATION)
	var day := int(total_minutes / MINUTES_PER_DAY)
	var current_day_minutes := total_minutes % MINUTES_PER_DAY
	var hour := int(current_day_minutes / MINUTES_PER_HOUR)
	var minute := current_day_minutes % MINUTES_PER_HOUR

	if current_minute != minute:
		current_minute = minute
		time_tick.emit(day, hour, minute)

	if current_day != day:
		current_day = day
		time_tick_day.emit(day)


func _is_time_authority() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _on_peer_connected(peer_id: int) -> void:
	# Bring a newly-joined peer straight to the current authoritative time
	# instead of letting it start from the level's default initial time.
	if _is_time_authority():
		_receive_time_sync.rpc_id(peer_id, time, game_speed)


@rpc("authority", "call_remote", "reliable")
func _receive_time_sync(host_time: float, host_speed: float) -> void:
	time = host_time
	game_speed = host_speed
	game_time.emit(time)
	recalculate_time()
