extends Node

const DISABLED_TEXTURE = preload("res://assets/icons/disabled.png");
const TODO_TEXTURE = preload("res://assets/icons/todo.png");

# The URL we will connect to
export var websocket_url = "ws://localhost:8080"

# Our WebSocketClient instance
var _client = WebSocketClient.new()
var _timer = null
var WRAM_START = 0xF50000;
var WRAM_SIZE = 0x20000;
var SAVEDATA_START = WRAM_START + 0xF000;
var SAVEDATA_SIZE = 0x500;
var VALID_GAMEMODES = [0x07, 0x09, 0x0b]
var _location_data = null
var _old_location_data = null

var locations_to_sram = {
    "SuperBunnyU": [[0x1F0, 0x30]],
    "SpiralU": [[0x1FC, 0x10]],
    "SpecM": [[0x1D5, 0x04]],
    "ParadoxM": [[0x1DE, 0xF0], [0x1DF, 0x01]],
    "ParadoxL": [[0x1FE, 0x30]],
    "Hookshot2": [[0x078, 0xF0]],
    "HypeCave": [[0x23C, 0xF0], [0x23D, 0x04]],
    "MireShed": [[0x21A, 0x30]],
    "Library": [[0x410, 0x80]],
    "SickKid": [[0x410, 0x04]],
    "Aginah": [[0x214, 0x10]],
    "FloodgateChest": [[0x216, 0x10]],
    "IceRodCave": [[0x240, 0x10]],
    "HammerPegs": [[0x24F, 0x04]],
    "MiniMoldorm": [[0x246, 0xF0], [0x247, 0x04]],
    "Waterfall": [[0x228, 0x30]],
    "PyramidFairy": [[0x22C, 0x30]],
    "Mimic": [[0x218, 0x10]],
    "ChestGame": [[0x20D, 0x04]],
    "ChickenHouse": [[0x210, 0x10]],
    "BonkRocks": [[0x248, 0x10]],
    "Brewery": [[0x20C, 0x10]],
    "Checkerboard": [[0x24D, 0x02]],
    "Blind": [[0x23A, 0xF0], [0x23B, 0x01]],
    "Spike": [[0x22E, 0x10]],
    "Cave45": [[0x237, 0x04]],
    "GraveyardLedge": [[0x237, 0x02]],
    "CHouse": [[0x238, 0x10]],
    "KingsTomb": [[0x226, 0x10]],
    "Sriracha": [[0x20A, 0x70], [0x410, 0x10]],
    "PotionShop": [[0x411, 0x20]],
    "Smith": [[0x411, 0x04]],
    "Powder": [[0x411, 0x80]],
    "Bombos Tablet": [[0x411, 0x02]],
    "Bottle Merchant": [[0x3C9, 0x02]],
    "Desert Ledge": [[0x2B0, 0x40]],
    "Ether Tablet": [[0x411, 0x01]],
    "Floating Island": [[0x285, 0x40]],
    "Flute Spot": [[0x2AA, 0x40]],
    "Hobo": [[0x3C9, 0x01]],
    "King Zora": [[0x410, 0x02]],
    "Lake Hylia Island": [[0x2B5, 0x40]],
    "Master Sword Pedestal": [[0x300, 0x40]],
    "Maze Race": [[0x2A8, 0x40]],
    "Mushroom": [[0x411, 0x10]],
    "Old Man": [[0x410, 0x01]],
    "Purple Chest": [[0x3C9, 0x10]],
    "Spectacle Rock": [[0x283, 0x40]],
    "Sunken Treasure": [[0x2BB, 0x40]],
    "Zora's Ledge": [[0x301, 0x40]],
    "Bumper Cave Ledge": [[0x2CA, 0x40]],
    "Catfish": [[0x410, 0x20]],
    "Digging Game": [[0x2E8, 0x40]],
    "Pyramid": [[0x2DB, 0x40]],
    "Stumpy": [[0x410, 0x08]],
}

enum AUTOTRACKER_STATUS {
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
    TRACKING,
    ERROR
}

var _at_status = AUTOTRACKER_STATUS.DISCONNECTED

func _ready() -> void:
    # Autotracking stuff
    _client.connect("connection_closed", self, "_closed")
    _client.connect("connection_error", self, "_closed")
    _client.connect("connection_established", self, "_connected")
    Events.connect("start_autotracking", self, "_connect_at")
    _client.connect("data_received", self, "_on_data")

func _connect_at():
    # Initiate connection to the given URL.
    if _at_status != AUTOTRACKER_STATUS.DISCONNECTED:
        return

    _client.set_verify_ssl_enabled(false)
    var err = _client.connect_to_url(websocket_url)
    if err != OK:
        print("Unable to connect")
        set_process(false)
    else:
        _timer = Timer.new()
        add_child(_timer)
        _timer.connect("timeout", self, "_on_Timer_timeout")
        _timer.set_wait_time(1.0)
        _timer.set_one_shot(false) 

func _closed(_was_clean = false):
    _timer.stop()
    remove_child(_timer)
    _location_data = null
    _old_location_data = null
    _at_status = AUTOTRACKER_STATUS.DISCONNECTED
    OS.set_window_title("Entrando - Auto-tracking disabled")

func _connected(_proto = ""):
    _client.get_peer(1).set_write_mode(WebSocketPeer.WRITE_MODE_TEXT)
    var init_data = {'Opcode': "DeviceList", 'Space': "SNES"}
    _client.get_peer(1).put_packet(JSON.print(init_data).to_utf8())
    _at_status = AUTOTRACKER_STATUS.CONNECTING

func _on_data():
    var res_raw =_client.get_peer(1).get_packet()
    if _at_status == AUTOTRACKER_STATUS.CONNECTING:
        var res = JSON.parse(res_raw.get_string_from_utf8())
        if res.error != OK:
            print("Error parsing JSON")
            return    
        var device = res.result['Results'][0]
        var connect_data = {'Opcode': "Attach", 'Space': "SNES", 'Operands': [device]}
        _client.get_peer(1).put_packet(JSON.print(connect_data).to_utf8())
        OS.set_window_title("Entrando - Auto-tracking enabled: connected to " + device)

        _at_status = AUTOTRACKER_STATUS.CONNECTED
        _timer.start()

    elif _at_status == AUTOTRACKER_STATUS.CONNECTED:
        if VALID_GAMEMODES.has(res_raw[0]):
            _at_status = AUTOTRACKER_STATUS.TRACKING
            _timer.paused = true
            get_location_data()

func get_location_data():
     _client.disconnect("data_received", self, "_on_data")
     _client.connect("data_received", self, "_build_location_data")
     read_snes_mem(SAVEDATA_START, 0x400)
     read_snes_mem(SAVEDATA_START + 0x410, 2)

func process_location_data():
    if _old_location_data == null:
        _old_location_data = PoolByteArray()
        _old_location_data.resize(_location_data.size())
        _old_location_data.fill(0)

    var underworld = get_parent().find_node("GUILayer")
    var lightworld = get_parent().find_node("LightWorld")
    var darkworld = get_parent().find_node("DarkWorld")

    for loc in locations_to_sram:
        var locs_data = locations_to_sram[loc]
        var all_locs_checked = true            
        var any_locs_checked  = false
        var was_any_change = false
        for loc_data in locs_data:
            var addr = loc_data[0]
            var mask = loc_data[1]
            var new_value = _location_data[addr] & mask
            var old_value = _old_location_data[addr] & mask
            was_any_change = was_any_change || (new_value != old_value)
            any_locs_checked = any_locs_checked || (new_value == mask)
            all_locs_checked = all_locs_checked && (new_value == mask)
        if was_any_change and (all_locs_checked or any_locs_checked):
            var underworld_node = underworld.find_node(loc)
            if (underworld_node):
                underworld_node.get_child(0).set_pressed_texture(DISABLED_TEXTURE if all_locs_checked else TODO_TEXTURE);
                underworld_node.get_child(0).set_pressed(true)
            else:
                var overworld_node = lightworld.find_node(loc)
                if (overworld_node == null):
                    overworld_node = darkworld.find_node(loc)
                    if (overworld_node == null):
                        print("Error Autotracking: Unable to find node " + loc)
                        continue
                overworld_node.get_child(0).hide()
                # Do this to allow ctrl-z to undo
                Util.add_hidden(overworld_node.get_child(0))

    _old_location_data = _location_data
    _location_data = null
    _timer.paused = false
    _at_status = AUTOTRACKER_STATUS.CONNECTED

func _build_location_data():
    var res_raw =_client.get_peer(1).get_packet()
    if _location_data == null:
        _location_data = res_raw
        
        # Add empty data to pad the array for the SRAM we aren't reading
        # This allows us to address the array with the real SRAM addresses
        var empty_data = PoolByteArray()
        empty_data.resize(0x410 - res_raw.size())
        empty_data.fill(0)
        _location_data = _location_data + empty_data
        return
    else:
        _location_data = _location_data + res_raw
    if _location_data.size() == 0x410 + 2:
        _client.disconnect("data_received", self, "_build_location_data")
        _client.connect("data_received", self, "_on_data")
        process_location_data()

func read_snes_mem(addr, size):
    var read_data = {'Opcode': "GetAddress", 'Space': "SNES", 'Operands': ["%x" % addr, "%x" % size]}
    _client.get_peer(1).put_packet(JSON.print(read_data).to_utf8())

func _on_Timer_timeout():
    if _at_status == AUTOTRACKER_STATUS.CONNECTED:
        read_snes_mem(WRAM_START + 0x10, 1)

func _process(_delta):
    _client.poll()
