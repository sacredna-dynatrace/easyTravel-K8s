#!/usr/bin/env python3
"""
easyTravel 한글화용 아카이브 패처 (WAR / JAR)

  python3 patch_archive.py --in ROOT.war --out ROOT.ko.war \
      [--overlay i18n/ko/frontend/overlay] [--strings i18n/ko/frontend/class-strings.json]

1) --overlay : 디렉터리 안의 파일로 아카이브 내 같은 경로 파일을 교체(없으면 추가)
2) --strings : .class 파일의 문자열 상수(CONSTANT_String)를 교체
   JSON 형식 { "<archive 내 class 경로>": { "영문": "한글", ... } }
   중첩 jar 안의 class 는 "WEB-INF/lib/foo.jar!/com/x/Y.class" 로 지정

class 문자열 교체 방식:
   기존 CONSTANT_Utf8 은 건드리지 않고 새 Utf8 항목을 constant pool 끝에 추가한 뒤
   해당 CONSTANT_String 의 참조만 새 항목으로 바꾼다. (필드/메서드 이름 등과 공유된 Utf8 도 안전)
   지정한 영문 문자열을 하나라도 찾지 못하면 실패한다 (원본 이미지 변경 감지용).
"""
import argparse
import io
import json
import os
import struct
import sys
import zipfile


# ---------------------------------------------------------------- class file
def _java_utf8(s: str) -> bytes:
    """Java modified UTF-8 (BMP 문자는 일반 UTF-8 과 동일, NUL 과 보조문자만 다름)."""
    out = bytearray()
    for ch in s:
        c = ord(ch)
        if c == 0:
            out += b"\xc0\x80"
        elif c > 0xFFFF:  # surrogate pair 로 인코딩
            c -= 0x10000
            for u in (0xD800 + (c >> 10), 0xDC00 + (c & 0x3FF)):
                out += bytes([0xE0 | (u >> 12), 0x80 | ((u >> 6) & 0x3F), 0x80 | (u & 0x3F)])
        else:
            out += ch.encode("utf-8")
    return bytes(out)


def patch_class(data: bytes, mapping: dict, name: str) -> bytes:
    if data[:4] != b"\xca\xfe\xba\xbe":
        raise ValueError(f"{name}: not a class file")
    count = struct.unpack(">H", data[8:10])[0]
    i, k = 10, 1
    utf = {}           # index -> str
    str_refs = []      # (byte offset of string_index, utf index)
    while k < count:
        t = data[i]
        if t == 1:
            ln = struct.unpack(">H", data[i + 1:i + 3])[0]
            utf[k] = data[i + 3:i + 3 + ln].decode("utf-8", "surrogatepass")
            i += 3 + ln
        elif t in (3, 4):
            i += 5
        elif t in (5, 6):
            i += 9
            k += 1
        elif t in (7, 16, 19, 20):
            i += 3
        elif t == 8:
            str_refs.append((i + 1, struct.unpack(">H", data[i + 1:i + 3])[0]))
            i += 3
        elif t in (9, 10, 11, 12, 17, 18):
            i += 5
        elif t == 15:
            i += 4
        else:
            raise ValueError(f"{name}: unknown constant tag {t}")
        k += 1
    pool_end = i

    buf = bytearray(data)
    appended = bytearray()
    new_index = {}
    next_idx = count
    found = set()
    for off, uidx in str_refs:
        val = utf.get(uidx)
        if val in mapping:
            found.add(val)
            if val not in new_index:
                enc = _java_utf8(mapping[val])
                appended += b"\x01" + struct.pack(">H", len(enc)) + enc
                new_index[val] = next_idx
                next_idx += 1
            buf[off:off + 2] = struct.pack(">H", new_index[val])
    missing = set(mapping) - found
    if missing:
        raise KeyError(f"{name}: strings not found: {sorted(missing)}")
    if next_idx > 0xFFFF:
        raise OverflowError(f"{name}: constant pool overflow")
    buf[8:10] = struct.pack(">H", next_idx)
    return bytes(buf[:pool_end]) + bytes(appended) + bytes(buf[pool_end:])


# ---------------------------------------------------------------- archives
def patch_zip(data: bytes, overlay: dict, strings: dict, label: str, stats: dict) -> bytes:
    """overlay: {path: bytes}, strings: {path: mapping} (path 는 이 아카이브 기준, 'a.jar!/b' 허용)"""
    nested = {}
    direct = {}
    for p, m in strings.items():
        if "!/" in p:
            outer, inner = p.split("!/", 1)
            nested.setdefault(outer, {})[inner] = m
        else:
            direct[p] = m

    zin = zipfile.ZipFile(io.BytesIO(data))
    out = io.BytesIO()
    zout = zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED)
    seen = set()
    for info in zin.infolist():
        name = info.filename
        seen.add(name)
        content = zin.read(name)
        if name in overlay:
            content = overlay[name]
            stats["overlay"] += 1
        if name in direct:
            content = patch_class(content, direct[name], f"{label}!/{name}")
            stats["class"] += 1
        if name in nested:
            content = patch_zip(content, {}, nested[name], f"{label}!/{name}", stats)
        zi = zipfile.ZipInfo(name, date_time=info.date_time)
        zi.external_attr = info.external_attr
        zi.compress_type = info.compress_type
        zout.writestr(zi, content)
    for name, content in overlay.items():
        if name not in seen:
            zout.writestr(name, content)
            stats["added"] += 1
    for p in list(direct) + list(nested):
        if p not in seen:
            raise FileNotFoundError(f"{label}: {p} not found in archive")
    zout.close()
    return out.getvalue()


def load_overlay(root):
    files = {}
    if not root or not os.path.isdir(root):
        return files
    for dp, _, fs in os.walk(root):
        for f in fs:
            if f == ".gitkeep":
                continue
            full = os.path.join(dp, f)
            rel = os.path.relpath(full, root).replace(os.sep, "/")
            with open(full, "rb") as fh:
                files[rel] = fh.read()
    return files


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="src", required=True)
    ap.add_argument("--out", dest="dst", required=True)
    ap.add_argument("--overlay")
    ap.add_argument("--strings")
    a = ap.parse_args()

    overlay = load_overlay(a.overlay)
    strings = {}
    if a.strings:
        if not os.path.exists(a.strings):
            raise FileNotFoundError(a.strings)
        with open(a.strings, encoding="utf-8") as fh:
            strings = {k: v for k, v in json.load(fh).items() if not k.startswith("_")}
    stats = {"overlay": 0, "added": 0, "class": 0}
    with open(a.src, "rb") as fh:
        data = fh.read()
    result = patch_zip(data, overlay, strings, os.path.basename(a.src), stats)
    with open(a.dst, "wb") as fh:
        fh.write(result)
    print(f"{a.src} -> {a.dst}: overlay replaced={stats['overlay']} added={stats['added']} classes patched={stats['class']}")


if __name__ == "__main__":
    sys.exit(main())
