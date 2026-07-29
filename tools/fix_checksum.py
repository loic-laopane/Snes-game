#!/usr/bin/env python3
"""Patches the SNES header checksum/complement in a LoROM .sfc file in place.
Usage: fix_checksum.py path/to/rom.sfc
"""
import sys

def main():
    path = sys.argv[1]
    with open(path, "rb") as f:
        data = bytearray(f.read())

    # Zero out the checksum fields before computing (standard practice: the
    # complement bytes are set to $FF/$FF conventionally during the sum pass,
    # so the checksum + complement always add up to $FFFF regardless of the
    # real checksum value).
    data[0x7fdc] = 0xff
    data[0x7fdd] = 0xff
    data[0x7fde] = 0xff
    data[0x7fdf] = 0xff

    checksum = sum(data) & 0xffff
    complement = checksum ^ 0xffff

    data[0x7fdc] = complement & 0xff
    data[0x7fdd] = (complement >> 8) & 0xff
    data[0x7fde] = checksum & 0xff
    data[0x7fdf] = (checksum >> 8) & 0xff

    with open(path, "wb") as f:
        f.write(data)

    print(f"{path}: checksum=${checksum:04x} complement=${complement:04x}")

if __name__ == "__main__":
    main()
