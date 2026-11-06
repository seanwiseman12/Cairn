"""Build the app's bundled mountain search database from GeoNames.

Keeps every named peak, mountain, volcano and mountain range (optionally hills)
from GeoNames' allCountries dump (CC BY 4.0, https://www.geonames.org) and
writes a small SQLite file the app searches offline (Services/PeakSearch.swift).

Tables:
  peaks(id, name, lat, lon, ele, country, kind, rank)
      lat/lon = degrees x 100000, stored as integers to save space
      kind = 0 peak, 1 mountain, 2 volcano, 3 range, 4 hill
      rank = how famous it is: elevation plus 400 per alternate name (up to 25).
             Well-known mountains have names in many languages, so "Ben Nevis"
             finds Scotland's before a same-named hill elsewhere.
  tokens(token, peak_id)
      one row per searchable word of the name and its Latin-script alternate names

Word splitting must match PeakSearch.words(in:) in the app.

Usage:
  curl -O https://download.geonames.org/export/dump/allCountries.zip
  python3 tools/make_peaks.py allCountries.zip Cairn/Resources/Peaks/peaks.sqlite [--hills]
"""
import io
import os
import sqlite3
import sys
import unicodedata
import zipfile

KINDS = {'PK': 0, 'PKS': 0, 'MT': 1, 'VLC': 2, 'MTS': 3}
HILL_KINDS = {'HLL': 4}
MAX_WORDS_PER_PEAK = 200  # famous peaks have hundreds of alternate names
FAME_PER_NAME = 400
MAX_FAME_NAMES = 25

# Letters that don't split into "base letter + accent", so need spelling out.
SPELL_OUT = str.maketrans({'ø': 'o', 'æ': 'ae', 'œ': 'oe', 'đ': 'd', 'ð': 'd', 'ł': 'l',
                           'ı': 'i', 'þ': 'th', 'ß': 'ss'})


def words(text):
    """Lowercase, accent-free words: "Mönch Peak" -> ["monch", "peak"]."""
    decomposed = unicodedata.normalize('NFKD', text.casefold().translate(SPELL_OUT))
    plain = ''.join(ch for ch in decomposed if not unicodedata.combining(ch))
    out, current = [], []
    for ch in plain:
        if ch.isalnum():
            current.append(ch)
        elif current:
            out.append(''.join(current))
            current = []
    if current:
        out.append(''.join(current))
    return out


def main():
    src, dest = sys.argv[1], sys.argv[2]
    kinds = dict(KINDS)
    if '--hills' in sys.argv:
        kinds.update(HILL_KINDS)

    if os.path.exists(dest):
        os.remove(dest)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    db = sqlite3.connect(dest)
    db.executescript('''
        PRAGMA page_size = 4096;
        CREATE TABLE peaks(
            id INTEGER PRIMARY KEY, name TEXT NOT NULL, lat INTEGER NOT NULL, lon INTEGER NOT NULL,
            ele INTEGER, country TEXT NOT NULL, kind INTEGER NOT NULL, rank INTEGER NOT NULL);
        CREATE TABLE tokens(token TEXT NOT NULL, peak_id INTEGER NOT NULL,
            PRIMARY KEY(token, peak_id)) WITHOUT ROWID;
    ''')

    peaks, tokens = [], []
    with zipfile.ZipFile(src) as archive, archive.open('allCountries.txt') as raw:
        for line in io.TextIOWrapper(raw, encoding='utf-8'):
            c = line.rstrip('\n').split('\t')
            if c[6] != 'T' or c[7] not in kinds:
                continue
            name = c[1].strip()
            norm_words = words(name) or words(c[2])
            if not norm_words:
                continue
            ele = int(c[15]) if c[15].lstrip('-').isdigit() else None
            if ele is None and c[16].lstrip('-').isdigit() and int(c[16]) > -500:
                ele = int(c[16])  # GeoNames' terrain-model elevation
            peak_id = int(c[0])
            alternates = [a for a in c[3].split(',') if a and len(a) <= 40 and 'http' not in a]
            rank = (ele or 0) + FAME_PER_NAME * min(len(alternates), MAX_FAME_NAMES)
            peaks.append((peak_id, name, round(float(c[4]) * 1e5), round(float(c[5]) * 1e5),
                          ele, c[8], kinds[c[7]], rank))

            searchable = set(norm_words) | set(words(c[2]))
            latin = [a for a in alternates if all(w.isascii() for w in words(a))]
            for alternate in latin:
                if len(searchable) >= MAX_WORDS_PER_PEAK:
                    break
                searchable.update(w for w in words(alternate) if not w.isdigit())
            tokens.extend((w, peak_id) for w in searchable)

    db.executemany('INSERT INTO peaks VALUES (?, ?, ?, ?, ?, ?, ?, ?)', peaks)
    db.executemany('INSERT INTO tokens VALUES (?, ?)', tokens)
    db.commit()
    db.execute('VACUUM')
    db.close()
    print(f'{len(peaks):,} peaks, {len(tokens):,} search words -> {dest} '
          f'({os.path.getsize(dest) / 1e6:.1f} MB)')


if __name__ == '__main__':
    main()
