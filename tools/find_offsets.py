#!/usr/bin/env python3
"""Locate the Home Clean patch sites in a KPPMainApp.js.hbc and build the patched bundle.

Use this to port the patch to another firmware. It finds the code by its structure rather
than by fixed offsets, and fails if the structure no longer matches.

    pip install hermes-dec
    python3 tools/find_offsets.py KPPMainApp.js.hbc KPPMainApp.patched.hbc
"""
import hashlib
import importlib
import os
import re
import subprocess
import sys
import tempfile

from hermes_dec.parsers.hbc_file_parser import HBCReader

FUNCTION = re.compile(r"^=> \[Function #(\d+) ")
INSTRUCTION = re.compile(r"^==> ([0-9a-f]{8}): <(\w+)>: <(.*?)>(.*)$")
REGISTER = re.compile(r"Reg8: (\d+)")


def read_functions(listing):
    """Yield (function id, instructions) for each function in a hbc-disassembler listing."""
    number, instructions = None, []
    with open(listing, errors="replace") as lines:
        for line in lines:
            header = FUNCTION.match(line)
            if header:
                if number is not None:
                    yield number, instructions
                number, instructions = int(header.group(1)), []
                continue
            match = INSTRUCTION.match(line)
            if match:
                address, name, operands, comment = match.groups()
                instructions.append((int(address, 16), name, operands, comment))
    if number is not None:
        yield number, instructions


def mentions(instructions, text):
    return any(f"'{text}'" in comment for *_, comment in instructions)


def factory_site(instructions):
    """Return (site, target): the check after the library card, and the final `return null`."""
    site = target = None
    for i, (_, _, _, comment) in enumerate(instructions):
        if "'TemplateFromYourLibraryCard'" in comment:
            assert instructions[i + 1][1].startswith("JStrictEqual"), "unexpected library check"
            site = instructions[i + 2]
            assert site[1] == "LoadFromEnvironment", "unexpected instruction at the patch site"
        if "'BackToTop'" in comment:
            assert instructions[i + 1][1].startswith("JStrictEqual"), "unexpected BackToTop check"
            target = instructions[i + 2]
            assert target[1] == "LoadConstNull", "chain does not end in return null"
    assert site and target, "card chain not found"
    return site[0], target[0]


def pagination_site(instructions):
    """Return (site, register): the `Mov` that sets the height of cards other than the first."""
    names = [name for _, name, _, _ in instructions]
    shape = ["Mov", "JStrictNotEqual", "LoadFromEnvironment", "Mov", "JNotGreater"]
    for i in range(len(names) - len(shape)):
        if names[i:i + len(shape)] == shape and instructions[i][2] == instructions[i + 3][2]:
            return instructions[i][0], int(REGISTER.findall(instructions[i][2])[0])
    raise AssertionError("pagination pattern not found")


def main(source, destination):
    reader = HBCReader()
    with open(source, "rb") as file:
        reader.read_whole_file(file)
    version = reader.header.version
    opcodes = importlib.import_module(f"hermes_dec.parsers.hbc_opcodes.hbc{version}")
    jmp_long = opcodes.JmpLong.opcode
    load_uint8 = opcodes.LoadConstUInt8.opcode

    with tempfile.TemporaryDirectory() as folder:
        listing = os.path.join(folder, "bundle.hasm")
        subprocess.run(["hbc-disassembler", source, listing], check=True, stdout=subprocess.DEVNULL)
        factories, callbacks = [], []
        for number, instructions in read_functions(listing):
            if mentions(instructions, "TemplateFromYourLibraryCard") and mentions(instructions, "_renderBackToTop"):
                factories.append((number, *factory_site(instructions)))
            elif all(mentions(instructions, t) for t in ("getCardHeightDimension", "cardHeightManager", "LAUNCH_PAD_CARD_TYPE")):
                callbacks.append((number, *pagination_site(instructions)))
    assert len(factories) == 2, f"expected 2 card factories, found {factories}"
    assert len(callbacks) == 1, f"expected 1 pagination callback, found {callbacks}"

    data = bytearray(open(source, "rb").read())
    pokes = []

    def poke(offset, values):
        data[offset:offset + len(values)] = values
        pokes.append((offset, bytes(values)))

    for number, site, target in factories:
        base = reader.function_headers[number].offset
        print(f"card factory #{number}: {site:#x} -> {target:#x}")
        poke(base + site, bytes([jmp_long]) + (target - site).to_bytes(4, "little", signed=True))
    number, site, register = callbacks[0]
    print(f"pagination callback #{number}: {site:#x}, r{register}")
    poke(reader.function_headers[number].offset + site, bytes([load_uint8, register, 0]))
    data[-20:] = hashlib.sha1(bytes(data[:-20])).digest()
    pokes.append((len(data) - 20, bytes(data[-20:])))

    with open(destination, "wb") as file:
        file.write(data)
    print("\nValues for package/payload/homeclean.sh:")
    print("SHA_ORIG=" + hashlib.sha256(open(source, "rb").read()).hexdigest())
    print("SHA_PATCHED=" + hashlib.sha256(data).hexdigest())
    for offset, values in pokes:
        print(f"poke {offset} '" + "".join(f"\\{b:03o}" for b in values) + "'")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
