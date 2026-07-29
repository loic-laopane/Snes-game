#!/usr/bin/env python3
"""Minimal libretro frontend: loads a core + ROM, runs N frames, dumps the
raw framebuffer to a PNG. No menu, no shaders, no notifications -- just the
core's actual video output. Requires: pip install pillow.
"""
import ctypes as C
import sys
from PIL import Image

CORE = "/usr/lib/x86_64-linux-gnu/libretro/snes9x_libretro.so"

RETRO_ENVIRONMENT_SET_PIXEL_FORMAT = 10
RETRO_ENVIRONMENT_GET_LOG_INTERFACE = 27
RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS = 17
RETRO_ENVIRONMENT_GET_VARIABLE = 15
RETRO_ENVIRONMENT_SET_VARIABLES = 16
RETRO_ENVIRONMENT_GET_CAN_DUMP_STATE = 8

pixel_format = {"fmt": 1}  # default RETRO_PIXEL_FORMAT_0RGB1555 = 0, RGB565=1, XRGB8888=2

class RetroGameInfo(C.Structure):
    _fields_ = [
        ("path", C.c_char_p),
        ("data", C.c_void_p),
        ("size", C.c_size_t),
        ("meta", C.c_char_p),
    ]

core = C.CDLL(CORE)

core.retro_set_environment.argtypes = [C.c_void_p]
core.retro_set_video_refresh.argtypes = [C.c_void_p]
core.retro_set_audio_sample.argtypes = [C.c_void_p]
core.retro_set_audio_sample_batch.argtypes = [C.c_void_p]
core.retro_set_input_poll.argtypes = [C.c_void_p]
core.retro_set_input_state.argtypes = [C.c_void_p]
core.retro_load_game.argtypes = [C.POINTER(RetroGameInfo)]
core.retro_load_game.restype = C.c_bool
core.retro_run.argtypes = []
core.retro_get_system_av_info.argtypes = [C.c_void_p]

last_frame = {}

ENVFUNC = C.CFUNCTYPE(C.c_bool, C.c_uint, C.c_void_p)
def env_cb(cmd, data):
    if cmd == RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
        fmt = C.cast(data, C.POINTER(C.c_int))[0]
        pixel_format["fmt"] = fmt
        return True
    return False
env_cb_c = ENVFUNC(env_cb)

VIDEOFUNC = C.CFUNCTYPE(None, C.c_void_p, C.c_uint, C.c_uint, C.c_size_t)
def video_cb(data, width, height, pitch):
    if not data:
        return
    fmt = pixel_format["fmt"]
    buf = C.string_at(data, pitch * height)
    last_frame["buf"] = buf
    last_frame["width"] = width
    last_frame["height"] = height
    last_frame["pitch"] = pitch
    last_frame["fmt"] = fmt
video_cb_c = VIDEOFUNC(video_cb)

AUDIOSFUNC = C.CFUNCTYPE(None, C.c_int16, C.c_int16)
def audio_sample_cb(l, r):
    pass
audio_sample_cb_c = AUDIOSFUNC(audio_sample_cb)

AUDIOBFUNC = C.CFUNCTYPE(C.c_size_t, C.c_void_p, C.c_size_t)
def audio_batch_cb(data, frames):
    return frames
audio_batch_cb_c = AUDIOBFUNC(audio_batch_cb)

POLLFUNC = C.CFUNCTYPE(None)
def input_poll_cb():
    pass
input_poll_cb_c = POLLFUNC(input_poll_cb)

# port, device, index, id -> pressed(0/1) or axis value
button_state = {}

STATEFUNC = C.CFUNCTYPE(C.c_int16, C.c_uint, C.c_uint, C.c_uint, C.c_uint)
def input_state_cb(port, device, index, idd):
    if port == 0:
        return button_state.get(idd, 0)
    return 0
input_state_cb_c = STATEFUNC(input_state_cb)

core.retro_set_environment(env_cb_c)
core.retro_set_video_refresh(video_cb_c)
core.retro_set_audio_sample(audio_sample_cb_c)
core.retro_set_audio_sample_batch(audio_batch_cb_c)
core.retro_set_input_poll(input_poll_cb_c)
core.retro_set_input_state(input_state_cb_c)

core.retro_init()

romPath = sys.argv[1]
with open(romPath, "rb") as f:
    romData = f.read()

romBuf = C.create_string_buffer(romData, len(romData))
info = RetroGameInfo(
    path=romPath.encode(),
    data=C.cast(romBuf, C.c_void_p),
    size=len(romData),
    meta=None,
)

ok = core.retro_load_game(C.byref(info))
print("load_game:", ok)
if not ok:
    sys.exit(1)

RETRO_DEVICE_ID_JOYPAD_B = 0
RETRO_DEVICE_ID_JOYPAD_Y = 1
RETRO_DEVICE_ID_JOYPAD_SELECT = 2
RETRO_DEVICE_ID_JOYPAD_START = 3
RETRO_DEVICE_ID_JOYPAD_UP = 4
RETRO_DEVICE_ID_JOYPAD_DOWN = 5
RETRO_DEVICE_ID_JOYPAD_LEFT = 6
RETRO_DEVICE_ID_JOYPAD_RIGHT = 7
RETRO_DEVICE_ID_JOYPAD_A = 8
RETRO_DEVICE_ID_JOYPAD_X = 9

NUM_FRAMES = int(sys.argv[2]) if len(sys.argv) > 2 else 120
OUT = sys.argv[3] if len(sys.argv) > 3 else "/tmp/out.png"

script = {}
if len(sys.argv) > 4:
    # simple script: "frame:button,frame:button,..." held from that frame on.
    # Multiple buttons at the same frame: use "frame:btn1+btn2".
    for part in sys.argv[4].split(","):
        f, b = part.split(":")
        script.setdefault(int(f), []).append(b)

held = set()
for i in range(NUM_FRAMES):
    if i in script:
        for entry in script[i]:
            for b in entry.split("+"):
                if b == "none":
                    held.clear()
                else:
                    held.add(b)
    button_state.clear()
    namemap = {
        "left": RETRO_DEVICE_ID_JOYPAD_LEFT, "right": RETRO_DEVICE_ID_JOYPAD_RIGHT,
        "a": RETRO_DEVICE_ID_JOYPAD_A, "b": RETRO_DEVICE_ID_JOYPAD_B,
    }
    for b in held:
        button_state[namemap[b]] = 1
    core.retro_run()

buf = last_frame["buf"]
w = last_frame["width"]
h = last_frame["height"]
pitch = last_frame["pitch"]
fmt = last_frame["fmt"]
print("frame:", w, h, pitch, "fmt", fmt)


img = Image.new("RGB", (w, h))
px = img.load()
for y in range(h):
    row_off = y * pitch
    for x in range(w):
        if fmt == 1:  # XRGB8888
            off = row_off + x * 4
            b = buf[off]; g = buf[off+1]; r = buf[off+2]
        elif fmt == 2:  # RGB565
            off = row_off + x * 2
            val = buf[off] | (buf[off+1] << 8)
            r = (val >> 11) & 0x1f
            g = (val >> 5) & 0x3f
            b = val & 0x1f
            r = (r * 255) // 31
            g = (g * 255) // 63
            b = (b * 255) // 31
        else:  # 0RGB1555
            off = row_off + x * 2
            val = buf[off] | (buf[off+1] << 8)
            r = (val >> 10) & 0x1f
            g = (val >> 5) & 0x1f
            b = val & 0x1f
            r = (r * 255) // 31
            g = (g * 255) // 31
            b = (b * 255) // 31
        px[x, y] = (r, g, b)

img.save(OUT)
print("saved", OUT)
