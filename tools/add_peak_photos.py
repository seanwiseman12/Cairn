"""Add a photo to every peak that has one on Wikidata, in the bundled database.

Asks Wikidata (through QLever, a fast public Wikidata query service; the
official endpoint times out on a query this big) for every mountain, peak,
volcano, hill and range that has both a GeoNames ID (P1566) and an image (P18),
then stores the Wikimedia Commons file name for the peaks already in
peaks.sqlite. The app fetches the picture, author and license from Commons
when a peak is shown (Services/PeakPhotos.swift).

Table added:
  photos(peak_id, file)   file = Commons file name, e.g. "Cervino cloud.jpg"

Run after make_peaks.py (it rebuilds the database from scratch):
  python3 tools/add_peak_photos.py Cairn/Resources/Peaks/peaks.sqlite
"""
import csv
import io
import sqlite3
import subprocess
import sys
import urllib.parse

ENDPOINT = 'https://qlever.dev/api/wikidata'
# Wikidata classes: mountain, summit, volcano, stratovolcano, mountain range, hill,
# massif, shield volcano, cinder cone, lava dome, caldera... (instances only, no subclass walk).
TYPES = ['Q8502', 'Q207326', 'Q8072', 'Q169358', 'Q46831', 'Q54050', 'Q1061151',
         'Q190869', 'Q212057', 'Q1595289', 'Q740445']
QUERY = '''
PREFIX wd: <http://www.wikidata.org/entity/>
PREFIX wdt: <http://www.wikidata.org/prop/direct/>
SELECT ?gn ?img WHERE {
  VALUES ?type { %s }
  ?item wdt:P31 ?type ; wdt:P1566 ?gn ; wdt:P18 ?img .
}
''' % ' '.join('wd:' + t for t in TYPES)
FILE_PREFIX = 'http://commons.wikimedia.org/wiki/Special:FilePath/'


def fetch():
    # curl (built into macOS) rather than urllib, which fails on python.org
    # installs that haven't run "Install Certificates.command".
    url = ENDPOINT + '?' + urllib.parse.urlencode({'query': QUERY})
    text = subprocess.run(
        ['curl', '-sSfL', '--max-time', '300', '-H', 'Accept: text/csv',
         '-A', 'CairnPeakPhotos/1.0 (build script)', url],
        check=True, capture_output=True, text=True).stdout
    photos = {}
    for row in csv.DictReader(io.StringIO(text)):
        gn, img = row.get('gn', ''), row.get('img', '')
        if gn.isdigit() and img.startswith(FILE_PREFIX):
            # A peak can have several images; keep the first.
            photos.setdefault(int(gn), urllib.parse.unquote(img[len(FILE_PREFIX):]))
    return photos


def main():
    dest = sys.argv[1]
    photos = fetch()
    db = sqlite3.connect(dest)
    ids = {row[0] for row in db.execute('SELECT id FROM peaks')}
    rows = [(peak_id, name) for peak_id, name in photos.items() if peak_id in ids]
    db.executescript('''
        DROP TABLE IF EXISTS photos;
        CREATE TABLE photos(peak_id INTEGER PRIMARY KEY, file TEXT NOT NULL);
    ''')
    db.executemany('INSERT INTO photos VALUES (?, ?)', rows)
    db.commit()
    db.execute('VACUUM')
    db.close()
    print(f'{len(photos):,} Wikidata mountains with photos, {len(rows):,} matched -> {dest}')


if __name__ == '__main__':
    main()
