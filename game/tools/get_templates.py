# Достаёт из архива шаблонов экспорта Godot только файлы для Windows,
# читая архив кусками по HTTP (Range), не скачивая все 1,3 ГБ.
# Запуск: python tools/get_templates.py
import io, os, shutil, struct, subprocess, zipfile, zlib

VER = '4.7.2'
URL = 'https://github.com/godotengine/godot/releases/download/%s-stable/Godot_v%s-stable_export_templates.tpz' % (VER, VER)
DEST = os.path.join(os.environ['APPDATA'], 'Godot', 'export_templates', VER + '.stable')
WANT = ('windows_release_x86_64.exe', 'windows_debug_x86_64.exe', 'version.txt')


def resolve(url):
    out = subprocess.run(['curl', '-sIL', url], capture_output=True, text=True).stdout
    loc, size = url, 0
    for line in out.splitlines():
        l = line.lower()
        if l.startswith('location:'):
            loc = line.split(':', 1)[1].strip()
        if l.startswith('content-length:'):
            size = int(line.split(':', 1)[1])
    return loc, size


class HttpFile(io.RawIOBase):
    def __init__(self, url, size):
        self.url, self.size, self.pos = url, size, 0

    def seekable(self):
        return True

    def readable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self, off, whence=0):
        self.pos = off if whence == 0 else (self.pos + off if whence == 1 else self.size + off)
        return self.pos

    def read(self, n=-1):
        if n is None or n < 0:
            n = self.size - self.pos
        if n == 0 or self.pos >= self.size:
            return b''
        end = min(self.pos + n, self.size) - 1
        data = subprocess.run(['curl', '-sSL', '--retry', '3', '-r', '%d-%d' % (self.pos, end), self.url],
                              capture_output=True, check=True).stdout
        self.pos += len(data)
        return data

    def readinto(self, b):
        d = self.read(len(b))
        b[:len(d)] = d
        return len(d)


url, size = resolve(URL)
print('archive', size // 1_000_000, 'MB')
zf = zipfile.ZipFile(io.BufferedReader(HttpFile(url, size), buffer_size=1 << 20))
os.makedirs(DEST, exist_ok=True)
raw = HttpFile(url, size)
for info in zf.infolist():
    name = os.path.basename(info.filename)
    if name not in WANT:
        continue
    raw.seek(info.header_offset)
    hdr = raw.read(30)
    start = info.header_offset + 30 + struct.unpack('<H', hdr[26:28])[0] + struct.unpack('<H', hdr[28:30])[0]
    tmp = os.path.join(DEST, name + '.part')
    print('download', name, info.compress_size // 1_000_000, 'MB')
    subprocess.run(['curl', '-sSL', '--retry', '5', '-r', '%d-%d' % (start, start + info.compress_size - 1), '-o', tmp, url], check=True)
    out = os.path.join(DEST, name)
    with open(tmp, 'rb') as src, open(out, 'wb') as dst:
        if info.compress_type == zipfile.ZIP_STORED:
            shutil.copyfileobj(src, dst)
        else:
            d = zlib.decompressobj(-15)
            while True:
                chunk = src.read(8 << 20)
                if not chunk:
                    break
                dst.write(d.decompress(chunk))
            dst.write(d.flush())
    os.remove(tmp)
    assert os.path.getsize(out) == info.file_size, 'size mismatch ' + name
    print('ok', name)
print('ok ->', DEST)
