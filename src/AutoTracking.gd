extends Node

const DISABLED_TEXTURE = preload("res://assets/icons/disabled.png");
const TODO_TEXTURE = preload("res://assets/icons/todo.png");
const BLANK_TEXTURE = preload("res://assets/icons/blankTexture.png");

# The URL we will connect to
export var websocket_url = "ws://localhost:"
export var websocket_port = 23074
export var device_name = ""

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
    "Tavern": [[0x206, 0x10]],
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
    "Well": [[0x05E, 0xF0], [0x05F, 0x01]],
    "Uncle": [[0x3C6, 0x01], [0x0AA, 0x10]],
    "Hideout": [[0x1C3, 0x02]],
    "Lumberjacks": [[0x1C5, 0x02]],
}

#seen mask, seen byte, dungeon current/total byte
var dungeon_masks = {
    "HC": [0x00C0, 2],
    "EP": [0x0020, 4],
    "DP": [0x0010, 6],
    "TH": [0x2000, 20],
    "AT": [0x0008, 8],
    "PD": [0x0002, 12],
    "SP": [0x0004, 10],
    "SW": [0x8000, 16],
    "TT": [0x1000, 22],
    "IP": [0x4000, 18],
    "MM": [0x0001, 14],
    "TR": [0x0800, 24],
    "GT": [0x0400, 26],
}

enum AUTOTRACKER_STATUS {
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
    TRACKING,
    ERROR
}

var _at_status = AUTOTRACKER_STATUS.DISCONNECTED

onready var status_label = $"/root/Tracker/GUILayer/GUI/Container/Margin/HSplitContainer/Entrances/Dungeons/VBoxContainer/AutoTrackStatus"
onready var notes_window = $"/root/Tracker/NotesWindow"


func _ready() -> void:
    # Autotracking stuff
    _client.connect("connection_closed", self, "_closed")
    _client.connect("connection_error", self, "_closed")
    _client.connect("connection_established", self, "_connected")
    Events.connect("start_autotracking", self, "_connect_at")
    _client.connect("data_received", self, "_on_data")
    Events.connect("update_autotracking_port", self, "_on_update_autotracking_port")
    Events.connect("set_selected_device", self, "_on_set_selected_device")
    Events.connect("refresh_devices", self, "_connect_at")

    var config = ConfigFile.new()
    var err = config.load("user://config.cfg")
    if err == OK:
        if config.get_value("AutoTracking", "Device"):
            device_name = config.get_value("AutoTracking", "Device")
        if config.get_value("AutoTracking", "Port"):
            websocket_port = config.get_value("AutoTracking", "Port")

func _connect_at():
    var final_ws_url = websocket_url + str(websocket_port)
    # Initiate connection to the given URL.
    if _at_status != AUTOTRACKER_STATUS.DISCONNECTED:
        _reconnect()
        return

    _client.set_verify_ssl_enabled(false)
    var err = _client.connect_to_url(final_ws_url)

    if err != OK:
        status_label.text = "Error" + str(err)
    else:
        _timer = Timer.new()
        add_child(_timer)
        _timer.connect("timeout", self, "_on_Timer_timeout")
        _timer.set_wait_time(1.0)
        _timer.set_one_shot(false) 

func _reconnect():
    Events.emit_signal('set_connected_device', 0)
    Events.emit_signal('set_discovered_devices', [])
    _client.disconnect_from_host()
    while _at_status != AUTOTRACKER_STATUS.DISCONNECTED:
        yield(get_tree().create_timer(0.1), "timeout")
    _connect_at()   

func _on_update_autotracking_port(_port):
    websocket_port = _port
    _reconnect()

func _on_set_selected_device(_device):
    device_name = _device
    _reconnect()

func _closed(_was_clean = false):
    _timer.stop()
    remove_child(_timer)
    _location_data = null
    _old_location_data = null
    _at_status = AUTOTRACKER_STATUS.DISCONNECTED
    status_label.text = "Disabled"

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
        if res.result['Results'].size() == 0:
            Events.emit_signal('set_connected_device', 0)
            Events.emit_signal('set_discovered_devices', [])
            status_label.text = "No devices found"
            return
        var device_index = 0
        if device_name != "":
            for i in range(res.result['Results'].size()):
                if res.result['Results'][i] == device_name:
                    device_index = i
                    break
        var device = res.result['Results'][device_index]
        Events.emit_signal('set_discovered_devices', res.result['Results'])
        var connect_data = {'Opcode': "Attach", 'Space': "SNES", 'Operands': [device]}
        _client.get_peer(1).put_packet(JSON.print(connect_data).to_utf8())
        Events.emit_signal('set_connected_device', device_index)
        status_label.text = "Connected to " + device

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
    read_snes_mem(SAVEDATA_START, 0x500)
    #read_snes_mem(SAVEDATA_START + 0x410, 2)
    read_snes_mem(0xF65410, 0x30)
    read_snes_mem(0x7FC0, 2)
    

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
                if all_locs_checked:
                    underworld_node.self_modulate = Color("282626")
                    if !(loc == "ParadoxM" or loc == "ParadoxL"):
                        underworld_node.get_child(0).set_pressed_texture(BLANK_TEXTURE)
                        underworld_node.get_child(0).set_pressed(true)
                else:
                    underworld_node.get_child(0).set_pressed_texture(DISABLED_TEXTURE if all_locs_checked else TODO_TEXTURE)
                    underworld_node.get_child(0).set_pressed(true)
            else:
                var overworld_node = lightworld.find_node(loc)
                if (overworld_node == null):
                    overworld_node = lightworld.find_node("*@" + loc + "@*")
                    if (overworld_node == null):
                        overworld_node = darkworld.find_node(loc)
                        if (overworld_node == null):
                            overworld_node = darkworld.find_node("*@" + loc + "@*")
                            if (overworld_node == null):
                                print("Error Autotracking: Unable to find node " + loc)
                                continue
                overworld_node.get_child(0).hide()
                # Do this to allow ctrl-z to undo
                Util.add_hidden(overworld_node.get_child(0))    
#Autotrack dungeon item counts and key counts when in dungeon (not in VT)
    if !(_location_data[0x530] == 86 and _location_data[0x531] == 84):
        var dungeon_item_count_seen = (_location_data[0x403] << 8) + _location_data[0x404]
        var dungeon_key_count_seen = (_location_data[0x474] << 8) + _location_data[0x475]
        var big_key_field = (_location_data[0x366] << 8) + _location_data[0x367]
        for dun in dungeon_masks:
            var mask_data = dungeon_masks[dun]
            notes_window.find_node(dun).set_current_checks(_location_data[0x4B0 + mask_data[1]] + ((_location_data[0x4B0 + mask_data[1] - 1]) << 8))
            notes_window.find_node(dun).set_current_keys(_location_data[0x4E0 + (mask_data[1]/2)])
            if dungeon_item_count_seen & mask_data[0]:
                notes_window.find_node(dun).set_total_checks(_location_data[0x500 + mask_data[1]] + ((_location_data[0x500 + mask_data[1] - 1]) << 8))
            if dungeon_key_count_seen & mask_data[0]:
                notes_window.find_node(dun).set_total_keys(_location_data[0x520 + (mask_data[1]/2)])
                
            #Big Keys
            if big_key_field & mask_data[0]:
                notes_window.find_node(dun).find_node("BigKey").visible = true
            
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
        #var empty_data = PoolByteArray()
        #empty_data.resize(0x410 - res_raw.size())
        #empty_data.fill(0)
        #_location_data = _location_data + empty_data
        return
    else:
        _location_data = _location_data + res_raw
    #if _location_data.size() == 0x410 + 2:
        
    if _location_data.size() > 0x530:
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
