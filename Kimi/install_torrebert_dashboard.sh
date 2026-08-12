#!/bin/bash
###############################################################################
#  TORRE BERT 2.0 — Installation du Dashboard Web
#  Déploie un serveur Flask + interface temps réel pour la station SIGINT
#  Service systemd inclus — démarre automatiquement au boot
###############################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${BLUE}[TB-DASH]${NC} $1"; }
ok()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $1"; }

INSTALL_DIR="/opt/torrebert/dashboard"
SERVICE_NAME="torrebert-dashboard"
USER_SDR="${SUDO_USER:-$USER}"
PORT=8080

# ═══════════════════════════════════════════════════════════════════════════
#  1. PRÉPARATION
# ═══════════════════════════════════════════════════════════════════════════

log "Installation du Dashboard Torre Bert 2.0"

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Exécutez avec sudo${NC}"
    exit 1
fi

apt-get update
apt-get install -y python3 python3-pip python3-venv python3-flask \
    python3-requests python3-numpy python3-ephem \
    rtl-sdr sox curl libjs-bootstrap5 || true

# Décodeur d'images NOAA/Meteor APT (paquet non garanti selon la distribution)
apt-get install -y noaa-apt || warn "noaa-apt indisponible via apt — voir https://noaa-apt.mbernardi.com.ar/ pour une installation manuelle (binaire statique)."

# ADS-B : le nom du paquet varie selon la distribution
apt-get install -y dump1090-mutability || apt-get install -y dump1090-fa \
    || warn "dump1090 indisponible via apt — voir https://github.com/flightaware/dump1090-fa pour une installation manuelle."

mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/static"
mkdir -p "$INSTALL_DIR/templates"
mkdir -p "$INSTALL_DIR/data"
mkdir -p "$INSTALL_DIR/data/passes"
mkdir -p "/opt/torrebert/scripts"

# Le driver DVB-T générique du noyau capture le RTL-SDR avant rtl_fm/rtl_test.
# On le neutralise pour libérer le périphérique.
cat > /etc/modprobe.d/blacklist-rtl-sdr.conf << 'EOF'
blacklist dvb_usb_rtl28xxu
blacklist rtl2832
blacklist rtl2830
EOF
modprobe -r dvb_usb_rtl28xxu 2>/dev/null || true
warn "Si le RTL-SDR reste invisible (rtl_test échoue), redémarre la machine une fois (blacklist du driver DVB-T)."

# Script de mise à jour des éléments orbitaux (TLE) depuis Celestrak
cat > "/opt/torrebert/scripts/update_tle.sh" << 'TLEEOF'
#!/bin/bash
set -euo pipefail
DATA_DIR="/opt/torrebert/dashboard/data"
mkdir -p "$DATA_DIR"
BASE="https://celestrak.org/NORAD/elements/gp.php"
curl -fsS "${BASE}?GROUP=stations&FORMAT=tle"  -o "$DATA_DIR/tle_stations.txt"  || true
curl -fsS "${BASE}?GROUP=weather&FORMAT=tle"   -o "$DATA_DIR/tle_weather.txt"   || true
curl -fsS "${BASE}?GROUP=noaa&FORMAT=tle"      -o "$DATA_DIR/tle_noaa.txt"      || true
curl -fsS "${BASE}?GROUP=iridium-NEXT&FORMAT=tle" -o "$DATA_DIR/tle_iridium.txt" || true
curl -fsS "${BASE}?GROUP=goes&FORMAT=tle"      -o "$DATA_DIR/tle_goes.txt"      || true
cat "$DATA_DIR"/tle_*.txt > "$DATA_DIR/tle_all.txt" 2>/dev/null || true
echo "TLE mis à jour : $(date -u '+%Y-%m-%d %H:%M UTC')"
TLEEOF
chmod +x "/opt/torrebert/scripts/update_tle.sh"

log "Récupération initiale des TLE (nécessite un accès Internet)..."
/opt/torrebert/scripts/update_tle.sh || warn "Échec de la récupération initiale des TLE — réessaie plus tard via le bouton du dashboard."

# ═══════════════════════════════════════════════════════════════════════════
#  1bis. CHAÎNES DE RÉCEPTION AVANCÉES — Iridium (gr-iridium) et Inmarsat (SatDump)
#        Nécessite les 2 dongles supplémentaires + Sawbird Iridium / Sawbird Inmarsat.
#        Compilation depuis les sources : peut prendre 20 à 90 minutes selon le matériel.
# ═══════════════════════════════════════════════════════════════════════════

log "Installation des dépendances pour Iridium (GNU Radio + gr-osmosdr)..."
apt-get install -y gnuradio gnuradio-dev gr-osmosdr cmake build-essential git \
    pkg-config libboost-all-dev python3-scipy \
    || warn "Dépendances GNU Radio incomplètes — la chaîne Iridium risque de ne pas compiler."

SRC_DIR="/opt/torrebert/src"
mkdir -p "$SRC_DIR"

log "Récupération et compilation de gr-iridium..."
if [ ! -d "$SRC_DIR/gr-iridium" ]; then
    git clone --depth 1 https://github.com/muccc/gr-iridium.git "$SRC_DIR/gr-iridium" \
        || warn "Clone gr-iridium échoué (accès Internet ?)."
fi
if [ -d "$SRC_DIR/gr-iridium" ] && ! command -v iridium-extractor >/dev/null 2>&1; then
    ( cd "$SRC_DIR/gr-iridium" && mkdir -p build && cd build && cmake .. && make -j"$(nproc)" && make install && ldconfig ) \
        || warn "Compilation gr-iridium échouée — vérifie les dépendances GNU Radio ci-dessus."
fi

log "Récupération d'iridium-toolkit (parsing des trames)..."
if [ ! -d "$SRC_DIR/iridium-toolkit" ]; then
    git clone --depth 1 https://github.com/muccc/iridium-toolkit.git "$SRC_DIR/iridium-toolkit" \
        || warn "Clone iridium-toolkit échoué."
fi

log "Installation des dépendances pour SatDump (Inmarsat AERO / STD-C)..."
apt-get install -y libfftw3-dev libpng-dev libtiff-dev libjemalloc-dev \
    libcurl4-openssl-dev libsqlite3-dev librtlsdr-dev pkgconf libnng-dev \
    || warn "Certaines dépendances SatDump sont indisponibles."
apt-get install -y libvolk2-dev || apt-get install -y libvolk-dev || apt-get install -y libvolk1-dev \
    || warn "libvolk introuvable — SatDump risque de ne pas compiler."

log "Récupération et compilation de SatDump (chaîne Inmarsat)..."
if ! command -v satdump >/dev/null 2>&1; then
    if [ ! -d "$SRC_DIR/SatDump" ]; then
        git clone --depth 1 https://github.com/SatDump/SatDump.git "$SRC_DIR/SatDump" \
            || warn "Clone SatDump échoué."
    fi
    if [ -d "$SRC_DIR/SatDump" ]; then
        ( cd "$SRC_DIR/SatDump" && mkdir -p build && cd build \
          && cmake -DCMAKE_BUILD_TYPE=Release .. && make -j"$(nproc)" && make install && ldconfig ) \
            || warn "Compilation SatDump échouée — la réception Inmarsat restera indisponible."
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════
#  2. APPLICATION FLASK
# ═══════════════════════════════════════════════════════════════════════════

cat > "$INSTALL_DIR/app.py" << 'PYEOF'
#!/usr/bin/env python3
"""
Torre Bert 2.0 — Dashboard Web SIGINT
Réception réelle sur 3 RTL-SDR :
  - rtl0 (générique)         : NOAA/Meteor APT, ISS SSTV/voix, ADS-B (partagés, exclusifs)
  - rtl1 (+ Sawbird Iridium) : Iridium (gr-iridium + iridium-toolkit)
  - rtl2 (+ Sawbird Inmarsat): Inmarsat AERO / STD-C (SatDump CLI)
"""

import os
import re
import json
import time
import glob
import math
import shutil
import threading
import subprocess
from datetime import datetime, timezone
from flask import Flask, render_template, jsonify, send_from_directory, request

try:
    import ephem
except ImportError:
    ephem = None

app = Flask(__name__)
app.config['JSON_SORT_KEYS'] = False

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data")
PASS_DIR = os.path.join(DATA_DIR, "passes")
TLE_FILE = os.path.join(DATA_DIR, "tle_all.txt")
SRC_DIR = "/opt/torrebert/src"
os.makedirs(PASS_DIR, exist_ok=True)

# Position de la station
STATION_LAT = float(os.environ.get("TB_LAT", "45.07"))
STATION_LON = float(os.environ.get("TB_LON", "7.69"))
STATION_ALT = float(os.environ.get("TB_ALT", "300"))  # mètres

# Index des 3 RTL-SDR. À FIXER via l'environnement (voir note de fin d'install) —
# l'ordre d'énumération USB n'est pas garanti d'un boot à l'autre sans numéro de série dédié.
MAIN_DEVICE_INDEX = os.environ.get("TB_RTL_MAIN", "0")
IRIDIUM_DEVICE_INDEX = os.environ.get("TB_RTL_IRIDIUM", "1")
INMARSAT_DEVICE_INDEX = os.environ.get("TB_RTL_INMARSAT", "2")

SDR_ROLES = [
    {"id": "rtl0", "name": "RTL-SDR principal",         "idx": MAIN_DEVICE_INDEX,     "role": "NOAA / Meteor / ISS / ADS-B"},
    {"id": "rtl1", "name": "RTL-SDR + Sawbird Iridium",  "idx": IRIDIUM_DEVICE_INDEX,  "role": "Iridium"},
    {"id": "rtl2", "name": "RTL-SDR + Sawbird Inmarsat", "idx": INMARSAT_DEVICE_INDEX, "role": "Inmarsat AERO / STD-C"},
]

SAT_DEFS = [
    {"name": "ISS",         "type": "iss",     "freq": 145.800,   "tle_names": ["ISS (ZARYA)"]},
    {"name": "NOAA-19",     "type": "noaa",    "freq": 137.100,   "tle_names": ["NOAA 19"]},
    {"name": "NOAA-18",     "type": "noaa",    "freq": 137.9125,  "tle_names": ["NOAA 18"]},
    {"name": "Meteor-M2-2", "type": "meteor",  "freq": 137.900,   "tle_names": ["METEOR-M2 2", "METEOR-M 2-2"]},
    {"name": "GOES-16",     "type": "goes",    "freq": 1694.100,  "tle_names": ["GOES 16"]},
    {"name": "Iridium 97",  "type": "iridium", "freq": 1626.5625, "tle_names": ["IRIDIUM 97"]},
    {"name": "Iridium 98",  "type": "iridium", "freq": 1626.5625, "tle_names": ["IRIDIUM 98"]},
]

# Cibles FM classiques sur le dongle principal (rtl0)
RECEIVABLE_TARGETS = {
    "noaa":   {"freq_mhz": 137.100, "mode": "apt"},
    "meteor": {"freq_mhz": 137.900, "mode": "apt"},   # LRPT numérique : capture WAV seule, pas de décodage QPSK ici
    "iss":    {"freq_mhz": 145.800, "mode": "audio"}, # voix/SSTV : capture audio, décodage SSTV manuel
}

# Pipelines SatDump pour Inmarsat (fréquences par défaut — À VÉRIFIER/AJUSTER selon le satellite
# visible depuis ta position et les canaux NCS en cours d'assignation, qui changent dans le temps)
INMARSAT_PIPELINES = {
    "std-c": {"pipeline": "inmarsat_std_c",    "freq_hz": 1541450000, "samplerate": 250000},
    "aero":  {"pipeline": "inmarsat_aero_105", "freq_hz": 1546001000, "samplerate": 2400000},
}


class TLECatalog:
    """Charge le fichier TLE local et expose les objets ephem.EarthSatellite par nom."""

    def __init__(self, path):
        self.path = path
        self.entries = {}
        self.loaded_at = None
        self.reload()

    def reload(self):
        entries = {}
        if os.path.exists(self.path):
            with open(self.path) as f:
                lines = [l.rstrip("\n") for l in f if l.strip()]
            for i in range(0, len(lines) - 2, 3):
                name, l1, l2 = lines[i].strip(), lines[i + 1], lines[i + 2]
                if l1.startswith("1 ") and l2.startswith("2 "):
                    entries[name.upper()] = (name, l1, l2)
        self.entries = entries
        self.loaded_at = datetime.now(timezone.utc)
        return len(entries)

    def get(self, candidate_names):
        for n in candidate_names:
            hit = self.entries.get(n.upper())
            if hit and ephem:
                name, l1, l2 = hit
                try:
                    return ephem.readtle(name, l1, l2)
                except Exception:
                    continue
        return None


class StationData:
    def __init__(self):
        self.tle = TLECatalog(TLE_FILE)
        self.observer = None
        if ephem:
            self.observer = ephem.Observer()
            self.observer.lat = str(STATION_LAT)
            self.observer.lon = str(STATION_LON)
            self.observer.elevation = STATION_ALT

        self.satellites = [
            dict(name=s["name"], type=s["type"], freq=s["freq"],
                 active=False, elevation=0.0, azimuth=0.0,
                 next_pass="—", signal_db=-999)
            for s in SAT_DEFS
        ]

        self.sdr_devices = [
            {"name": r["name"], "id": r["id"], "status": "unknown",
             "freq": 0, "gain": 42, "temp_c": None, "sample_rate": 0, "role": r["role"]}
            for r in SDR_ROLES
        ]

        self.logs = []
        self.spectrum = [5] * 128
        self.aircraft = []
        self.dump1090_proc = None
        self.current_job = None          # occupe rtl0 (noaa/meteor/iss/ads-b)

        self.lock = threading.Lock()         # protège l'état partagé
        self.rtl_busy = threading.Lock()     # exclusivité sur rtl0
        self.iridium_lock = threading.Lock() # exclusivité sur rtl1
        self.inmarsat_lock = threading.Lock()# exclusivité sur rtl2

        self.iridium_procs = None
        self.iridium_log_path = None
        self.inmarsat_proc = None
        self.inmarsat_mode = None

        self._detect_sdr()

        if not ephem:
            self.add_log("Module 'ephem' introuvable — suivi satellite désactivé", "warn")
        elif not os.path.exists(TLE_FILE):
            self.add_log("Aucun fichier TLE local — clique sur « Mettre à jour les TLE »", "warn")

        threading.Thread(target=self._background_update, daemon=True).start()
        threading.Thread(target=self._aircraft_poll_loop, daemon=True).start()

    # ---------- Détection matérielle réelle (3 dongles) ----------
    def _detect_sdr(self):
        for i, role in enumerate(SDR_ROLES):
            status, detail = "offline", ""
            try:
                r = subprocess.run(["rtl_test", "-d", str(role["idx"]), "-t"],
                                    capture_output=True, text=True, timeout=5)
                out = r.stdout + r.stderr
                if "Found" in out:
                    status = "online"
                    m = re.search(r"Found \d+ device", out)
                    detail = m.group(0) if m else "détecté"
            except FileNotFoundError:
                detail = "rtl_test introuvable (paquet rtl-sdr non installé ?)"
            except Exception as e:
                detail = str(e)
            with self.lock:
                self.sdr_devices[i]["status"] = status
            self.add_log(f"{role['name']} (idx {role['idx']}) : {status} — {detail}".rstrip(" —"),
                         "highlight" if status == "online" else "warn")

    # ---------- Boucle de fond : positions réelles calculées depuis les TLE ----------
    def _background_update(self):
        while True:
            with self.lock:
                if self.observer and ephem:
                    self.observer.date = ephem.now()
                    for sat_state, sdef in zip(self.satellites, SAT_DEFS):
                        body = self.tle.get(sdef["tle_names"])
                        if body is None:
                            continue
                        try:
                            self.observer.compute(body)
                            sat_state["elevation"] = round(math.degrees(body.alt), 1)
                            sat_state["azimuth"] = round(math.degrees(body.az), 1)
                            sat_state["active"] = sat_state["elevation"] > 0
                            if sat_state["active"]:
                                sat_state["signal_db"] = -90 + int(sat_state["elevation"] * 0.6)
                            else:
                                sat_state["signal_db"] = -999
                                try:
                                    nxt = self.observer.next_pass(body)
                                    if nxt and nxt[0]:
                                        sat_state["next_pass"] = ephem.localtime(nxt[0]).strftime("%H:%M")
                                except Exception:
                                    pass
                        except Exception:
                            pass
            time.sleep(2)

    def _aircraft_poll_loop(self):
        candidates = [
            "/run/dump1090-fa/aircraft.json",
            "/run/dump1090-mutability/aircraft.json",
        ]
        while True:
            for path in candidates:
                if os.path.exists(path):
                    try:
                        with open(path) as f:
                            data = json.load(f)
                        with self.lock:
                            self.aircraft = data.get("aircraft", [])
                    except Exception:
                        pass
                    break
            time.sleep(2)

    def get_state(self):
        with self.lock:
            tle_age = None
            if self.tle.loaded_at:
                tle_age = int((datetime.now(timezone.utc) - self.tle.loaded_at).total_seconds() // 60)
            return {
                "satellites": list(self.satellites),
                "sdr_devices": list(self.sdr_devices),
                "logs": list(self.logs[-25:]),
                "spectrum": list(self.spectrum),
                "aircraft": list(self.aircraft[-30:]),
                "utc": datetime.now(timezone.utc).strftime("%H:%M:%S"),
                "local": datetime.now().strftime("%H:%M:%S"),
                "lat": STATION_LAT,
                "lon": STATION_LON,
                "tle_age_min": tle_age,
                "busy_with": self.current_job,
                "iridium_active": self.iridium_procs is not None,
                "inmarsat_active": self.inmarsat_proc is not None,
                "inmarsat_mode": self.inmarsat_mode,
            }

    def add_log(self, msg, level=""):
        with self.lock:
            self.logs.append({"time": datetime.now().strftime("%H:%M:%S"), "msg": msg, "level": level})

    # ---------- rtl0 : NOAA / Meteor / ISS ----------
    def start_reception(self, target):
        if target not in RECEIVABLE_TARGETS:
            self.add_log(f"Cible « {target} » non prise en charge sur le dongle principal", "warn")
            return False
        if not self.rtl_busy.acquire(blocking=False):
            self.add_log(f"RTL-SDR principal occupé par « {self.current_job} » — requête « {target} » ignorée", "warn")
            return False

        cfg = RECEIVABLE_TARGETS[target]
        self.current_job = target
        threading.Thread(target=self._run_capture, args=(target, cfg["freq_mhz"], cfg["mode"]),
                          daemon=True).start()
        return True

    def _run_capture(self, target, freq_mhz, mode, duration_s=600):
        wav_path = os.path.join(PASS_DIR, f"{target}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.wav")
        try:
            self.add_log(f"Capture démarrée : {target} @ {freq_mhz} MHz ({duration_s}s max)", "highlight")

            rtl_fm_cmd = ["rtl_fm", "-d", str(MAIN_DEVICE_INDEX), "-f", f"{freq_mhz}M",
                          "-M", "fm", "-s", "60k", "-g", "42", "-E", "dc", "-F", "9", "-"]
            sox_cmd = ["sox", "-t", "raw", "-r", "60000", "-e", "signed", "-b", "16", "-c", "1",
                       "-", wav_path]

            rtl_proc = subprocess.Popen(rtl_fm_cmd, stdout=subprocess.PIPE)
            sox_proc = subprocess.Popen(sox_cmd, stdin=rtl_proc.stdout)
            rtl_proc.stdout.close()
            try:
                sox_proc.wait(timeout=duration_s)
            except subprocess.TimeoutExpired:
                pass
            finally:
                for p in (rtl_proc, sox_proc):
                    if p.poll() is None:
                        p.terminate()

            self.add_log(f"Capture terminée : {os.path.basename(wav_path)}", "")

            if mode == "apt":
                if shutil.which("noaa-apt"):
                    png_path = wav_path.replace(".wav", ".png")
                    r = subprocess.run(["noaa-apt", "-o", png_path, wav_path],
                                        capture_output=True, text=True, timeout=180)
                    if r.returncode == 0 and os.path.exists(png_path):
                        self.add_log(f"Image décodée : {os.path.basename(png_path)}", "highlight")
                    else:
                        self.add_log("Décodage noaa-apt échoué (signal trop faible / passage manqué)", "warn")
                else:
                    self.add_log("noaa-apt non installé — WAV conservé pour décodage manuel", "warn")
            elif mode == "audio":
                self.add_log("Audio enregistré (SSTV/voix) — décodage manuel requis (ex. QSSTV)", "")

        except FileNotFoundError as e:
            self.add_log(f"Outil manquant : {e}", "warn")
        except Exception as e:
            self.add_log(f"Erreur de capture : {e}", "warn")
        finally:
            self.current_job = None
            self.rtl_busy.release()

    def list_passes(self):
        files = sorted(glob.glob(os.path.join(PASS_DIR, "*")), reverse=True)
        return [os.path.basename(f) for f in files]

    # ---------- rtl0 : ADS-B (dump1090) — partage le dongle principal ----------
    def start_adsb(self):
        binname = shutil.which("dump1090-fa") or shutil.which("dump1090-mutability") or shutil.which("dump1090")
        if not binname:
            self.add_log("dump1090 non installé — ADS-B indisponible", "warn")
            return False
        if not self.rtl_busy.acquire(blocking=False):
            self.add_log(f"RTL-SDR principal occupé par « {self.current_job} » — ADS-B non démarré", "warn")
            return False
        try:
            os.makedirs("/run/dump1090-fa", exist_ok=True)
            self.current_job = "ads-b"
            self.dump1090_proc = subprocess.Popen(
                [binname, "--device-index", str(MAIN_DEVICE_INDEX),
                 "--write-json", "/run/dump1090-fa", "--write-json-every", "1"]
            )
            self.add_log("dump1090 démarré — réception ADS-B en cours", "highlight")
            return True
        except Exception as e:
            self.add_log(f"Échec démarrage dump1090 : {e}", "warn")
            self.current_job = None
            self.rtl_busy.release()
            return False

    def stop_adsb(self):
        if self.dump1090_proc and self.dump1090_proc.poll() is None:
            self.dump1090_proc.terminate()
            self.add_log("dump1090 arrêté", "")
        self.dump1090_proc = None
        if self.current_job == "ads-b":
            self.current_job = None
            self.rtl_busy.release()

    # ---------- rtl1 : Iridium (gr-iridium + iridium-toolkit) ----------
    def _write_iridium_conf(self, center_hz=1626000000, sample_rate=2000000, gain=42):
        conf_path = os.path.join(DATA_DIR, "iridium_rtl.conf")
        with open(conf_path, "w") as f:
            f.write(
                "[osmosdr-source]\n"
                f"device_args = rtl={IRIDIUM_DEVICE_INDEX}, bias=1\n"
                f"sample_rate = {sample_rate}\n"
                f"center_freq = {center_hz}\n"
                f"gain = {gain}\n"
            )
        return conf_path

    def start_iridium(self):
        if not shutil.which("iridium-extractor"):
            self.add_log("iridium-extractor introuvable — la compilation de gr-iridium a-t-elle réussi ?", "warn")
            return False
        parser_script = os.path.join(SRC_DIR, "iridium-toolkit", "iridium-parser.py")
        if not os.path.exists(parser_script):
            self.add_log("iridium-parser.py introuvable — iridium-toolkit absent", "warn")
            return False
        if not self.iridium_lock.acquire(blocking=False):
            self.add_log("Chaîne Iridium déjà active (dongle rtl1 occupé)", "warn")
            return False

        conf_path = self._write_iridium_conf()
        log_path = os.path.join(PASS_DIR, f"iridium_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log")
        try:
            extractor = subprocess.Popen(["iridium-extractor", "-D", "4", conf_path],
                                          stdout=subprocess.PIPE)
            parser = subprocess.Popen(["python3", "-u", parser_script, "-p"],
                                       stdin=extractor.stdout, stdout=open(log_path, "w"))
            extractor.stdout.close()
            self.iridium_procs = (extractor, parser)
            self.iridium_log_path = log_path
            self.add_log(f"Chaîne Iridium démarrée (dongle #{IRIDIUM_DEVICE_INDEX}, bias-tee actif)", "highlight")
            threading.Thread(target=self._tail_iridium_log, args=(log_path,), daemon=True).start()
            return True
        except FileNotFoundError as e:
            self.add_log(f"Outil manquant : {e}", "warn")
            self.iridium_lock.release()
            return False

    def stop_iridium(self):
        if self.iridium_procs:
            for p in self.iridium_procs:
                if p.poll() is None:
                    p.terminate()
            self.iridium_procs = None
            self.add_log("Chaîne Iridium arrêtée", "")
        if self.iridium_lock.locked():
            try:
                self.iridium_lock.release()
            except RuntimeError:
                pass

    def _tail_iridium_log(self, path):
        last_size, frame_count = 0, 0
        while self.iridium_procs is not None:
            try:
                size = os.path.getsize(path)
                if size > last_size:
                    with open(path) as f:
                        f.seek(last_size)
                        new_lines = f.readlines()
                    last_size = size
                    frame_count += len(new_lines)
                    if new_lines and frame_count % 50 < len(new_lines):
                        self.add_log(f"Iridium : {frame_count} trames décodées jusqu'ici", "")
            except FileNotFoundError:
                pass
            time.sleep(3)

    # ---------- rtl2 : Inmarsat AERO / STD-C (SatDump) ----------
    def start_inmarsat(self, mode, freq_mhz=None):
        if mode not in INMARSAT_PIPELINES:
            self.add_log(f"Mode Inmarsat inconnu : {mode} (attendu : std-c / aero)", "warn")
            return False
        if not shutil.which("satdump"):
            self.add_log("satdump introuvable — la compilation a-t-elle réussi ?", "warn")
            return False
        if not self.inmarsat_lock.acquire(blocking=False):
            self.add_log("Chaîne Inmarsat déjà active (dongle rtl2 occupé)", "warn")
            return False

        cfg = INMARSAT_PIPELINES[mode]
        freq_hz = int(freq_mhz * 1_000_000) if freq_mhz else cfg["freq_hz"]
        out_dir = os.path.join(PASS_DIR, f"inmarsat_{mode}_{datetime.now().strftime('%Y%m%d_%H%M%S')}")
        os.makedirs(out_dir, exist_ok=True)
        try:
            # NOTE : le flag de sélection du dongle (--source-arg / --device-index / autre selon
            # version de SatDump) n'a pas pu être vérifié à 100% ici — si le mauvais RTL-SDR est
            # utilisé, lance `satdump live --help` et `satdump live inmarsat_std_c --source rtlsdr --help`
            # pour trouver le nom exact de l'option sur ta version installée.
            proc = subprocess.Popen([
                "satdump", "live", cfg["pipeline"], out_dir,
                "--source", "rtlsdr",
                "--source-arg", f"rtl={INMARSAT_DEVICE_INDEX}",
                "--samplerate", str(cfg["samplerate"]),
                "--frequency", str(freq_hz),
                "--gain", "40",
                "--bias",
            ])
            self.inmarsat_proc = proc
            self.inmarsat_mode = mode
            self.add_log(f"Chaîne Inmarsat « {mode} » démarrée @ {freq_hz/1e6:.3f} MHz "
                         f"(dongle #{INMARSAT_DEVICE_INDEX}, bias-tee actif)", "highlight")
            return True
        except FileNotFoundError as e:
            self.add_log(f"Outil manquant : {e}", "warn")
            self.inmarsat_lock.release()
            return False

    def stop_inmarsat(self):
        if self.inmarsat_proc and self.inmarsat_proc.poll() is None:
            self.inmarsat_proc.terminate()
            self.add_log("Chaîne Inmarsat arrêtée", "")
        self.inmarsat_proc = None
        self.inmarsat_mode = None
        if self.inmarsat_lock.locked():
            try:
                self.inmarsat_lock.release()
            except RuntimeError:
                pass


station = StationData()

# ─── Routes Flask ───

@app.route("/")
def index():
    return render_template("dashboard.html")

@app.route("/api/state")
def api_state():
    return jsonify(station.get_state())

@app.route("/api/tune/<sdr_id>/<float:freq>")
def api_tune(sdr_id, freq):
    station.add_log(f"Fréquence sélectionnée : {freq} MHz (informatif)", "")
    return jsonify({"success": True, "sdr": sdr_id, "freq": freq})

@app.route("/api/receive/<target>")
def api_receive(target):
    if target == "ads-b":
        ok = station.start_adsb()
    elif target == "iridium":
        ok = station.start_iridium()
    else:
        ok = station.start_reception(target)
    return jsonify({"success": ok, "target": target})

@app.route("/api/receive/ads-b/stop")
def api_receive_adsb_stop():
    station.stop_adsb()
    return jsonify({"success": True})

@app.route("/api/receive/iridium/stop")
def api_receive_iridium_stop():
    station.stop_iridium()
    return jsonify({"success": True})

@app.route("/api/receive/inmarsat/<mode>")
def api_receive_inmarsat(mode):
    freq = request.args.get("freq", type=float)
    ok = station.start_inmarsat(mode, freq)
    return jsonify({"success": ok, "mode": mode})

@app.route("/api/receive/inmarsat/stop")
def api_receive_inmarsat_stop():
    station.stop_inmarsat()
    return jsonify({"success": True})

@app.route("/api/update-tle")
def api_update_tle():
    try:
        subprocess.Popen(["/opt/torrebert/scripts/update_tle.sh"],
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        station.add_log("Mise à jour TLE lancée en arrière-plan", "highlight")
        return jsonify({"success": True})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)})

@app.route("/api/tle/reload")
def api_tle_reload():
    n = station.tle.reload()
    station.add_log(f"TLE rechargés depuis le fichier local ({n} objets)", "highlight")
    return jsonify({"success": True, "count": n})

@app.route("/api/sdr/scan")
def api_sdr_scan():
    station._detect_sdr()
    return jsonify({"devices": station.sdr_devices})

@app.route("/api/passes")
def api_passes():
    return jsonify({"files": station.list_passes()})

@app.route("/data/passes/<path:filename>")
def get_pass_file(filename):
    return send_from_directory(PASS_DIR, filename)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=False, threaded=True)
PYEOF

chmod +x "$INSTALL_DIR/app.py"

# ═══════════════════════════════════════════════════════════════════════════
#  3. TEMPLATE HTML (le dashboard complet)
# ═══════════════════════════════════════════════════════════════════════════

cat > "$INSTALL_DIR/templates/dashboard.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Torre Bert 2.0 — Dashboard</title>
<style>
:root {
  --bg-dark: #0a0e17;
  --bg-panel: #111827;
  --bg-card: #1a2332;
  --border: #1f2937;
  --cyan: #00d4ff;
  --green: #10b981;
  --amber: #f59e0b;
  --red: #ef4444;
  --purple: #a855f7;
  --text: #e5e7eb;
  --text-dim: #6b7280;
}
* { box-sizing: border-box; }
body {
  margin: 0; background: var(--bg-dark); color: var(--text);
  font-family: 'JetBrains Mono', 'SF Mono', 'Courier New', monospace;
  font-size: 14px;
}
.tb-container { padding: 16px; max-width: 1400px; margin: 0 auto; }
.tb-header {
  display: flex; justify-content: space-between; align-items: center;
  border-bottom: 1px solid var(--border); padding-bottom: 12px; margin-bottom: 16px;
  flex-wrap: wrap; gap: 12px;
}
.tb-title { font-size: 1.4rem; font-weight: 700; color: var(--cyan); letter-spacing: 2px; }
.tb-subtitle { font-size: 0.75rem; color: var(--text-dim); margin-top: 2px; }
.tb-clocks { display: flex; gap: 24px; font-size: 0.85rem; }
.tb-clock { text-align: center; }
.tb-clock-label { font-size: 0.65rem; color: var(--text-dim); text-transform: uppercase; }
.tb-clock-value { font-weight: 700; color: var(--green); font-size: 1.1rem; }

.tb-grid { display: grid; grid-template-columns: 2fr 1fr 1fr; gap: 12px; }
@media (max-width: 1100px) { .tb-grid { grid-template-columns: 1fr 1fr; } }
@media (max-width: 700px) { .tb-grid { grid-template-columns: 1fr; } }

.tb-panel {
  background: var(--bg-panel); border: 1px solid var(--border);
  border-radius: 8px; padding: 14px;
}
.tb-panel-header {
  display: flex; justify-content: space-between; align-items: center;
  margin-bottom: 10px;
}
.tb-panel-title {
  font-size: 0.85rem; font-weight: 700; text-transform: uppercase;
  letter-spacing: 1px; color: var(--cyan);
}
.tb-panel-badge {
  font-size: 0.65rem; padding: 2px 8px; border-radius: 4px;
  background: var(--bg-card); color: var(--text-dim);
}

/* Sky Map */
.sky-map {
  position: relative; height: 320px;
  background: radial-gradient(ellipse at center, #0f172a 0%, #020617 100%);
  border-radius: 6px; overflow: hidden;
}
.sky-horizon {
  position: absolute; bottom: 0; left: 0; right: 0; height: 40%;
  background: linear-gradient(to top, rgba(6,182,212,0.08), transparent);
  border-top: 1px dashed rgba(0,212,255,0.15);
}
.sky-sat {
  position: absolute; width: 10px; height: 10px; border-radius: 50%;
  cursor: pointer; transition: transform 0.2s;
}
.sky-sat:hover { transform: scale(1.5); }
.sky-sat.iss { background: var(--green); box-shadow: 0 0 8px var(--green); }
.sky-sat.noaa { background: var(--cyan); box-shadow: 0 0 6px var(--cyan); }
.sky-sat.meteor { background: var(--amber); box-shadow: 0 0 6px var(--amber); }
.sky-sat.goes { background: var(--purple); box-shadow: 0 0 6px var(--purple); }
.sky-sat.iridium { background: var(--red); box-shadow: 0 0 6px var(--red); }
.sky-label {
  position: absolute; font-size: 0.6rem; color: var(--text-dim);
  white-space: nowrap; pointer-events: none;
}

/* Frequency Table */
.freq-row {
  display: flex; justify-content: space-between; align-items: center;
  padding: 6px 8px; border-radius: 4px; margin-bottom: 4px;
  font-size: 0.78rem; cursor: pointer; transition: background 0.15s;
}
.freq-row:hover { background: var(--bg-card); }
.freq-name { font-weight: 600; }
.freq-mhz { font-family: monospace; color: var(--cyan); }
.freq-status {
  font-size: 0.6rem; padding: 1px 6px; border-radius: 3px;
  text-transform: uppercase;
}
.freq-status.active { background: rgba(16,185,129,0.15); color: var(--green); }
.freq-status.upcoming { background: rgba(245,158,11,0.15); color: var(--amber); }
.freq-status.idle { background: rgba(107,114,128,0.15); color: var(--text-dim); }

/* SDR Status */
.sdr-item {
  display: flex; align-items: center; gap: 10px;
  padding: 8px; border-radius: 6px; background: var(--bg-card);
  margin-bottom: 6px;
}
.sdr-icon {
  width: 32px; height: 32px; border-radius: 6px;
  display: flex; align-items: center; justify-content: center;
  font-size: 0.7rem; font-weight: 700;
}
.sdr-icon.online {
  background: rgba(16,185,129,0.15); color: var(--green);
  border: 1px solid rgba(16,185,129,0.3);
}
.sdr-icon.offline {
  background: rgba(239,68,68,0.15); color: var(--red);
  border: 1px solid rgba(239,68,68,0.3);
}
.sdr-info { flex: 1; }
.sdr-name { font-size: 0.8rem; font-weight: 600; }
.sdr-detail { font-size: 0.65rem; color: var(--text-dim); }
.sdr-freq { font-family: monospace; font-size: 0.75rem; color: var(--cyan); }

/* Activity Log */
.log-entry {
  font-size: 0.72rem; padding: 4px 0;
  border-bottom: 1px solid var(--border); display: flex; gap: 8px;
}
.log-time { color: var(--text-dim); font-family: monospace; min-width: 60px; }
.log-msg { color: var(--text); }
.log-msg.highlight { color: var(--green); }
.log-msg.warn { color: var(--amber); }

/* Quick Controls */
.ctrl-btn {
  width: 100%; padding: 10px; margin-bottom: 8px;
  border: 1px solid var(--border); background: var(--bg-card);
  color: var(--text); border-radius: 6px; font-family: inherit;
  font-size: 0.8rem; cursor: pointer; transition: all 0.15s;
  text-align: left; display: flex; align-items: center; gap: 10px;
}
.ctrl-btn:hover { border-color: var(--cyan); background: rgba(0,212,255,0.05); }
.ctrl-btn:active { transform: scale(0.98); }
.ctrl-btn .dot { width: 8px; height: 8px; border-radius: 50%; }
.ctrl-btn .dot.green { background: var(--green); box-shadow: 0 0 6px var(--green); }
.ctrl-btn .dot.amber { background: var(--amber); box-shadow: 0 0 6px var(--amber); }
.ctrl-btn .dot.red { background: var(--red); box-shadow: 0 0 6px var(--red); }
.ctrl-btn .dot.purple { background: var(--purple); box-shadow: 0 0 6px var(--purple); }

/* Spectrum */
.spectrum {
  height: 60px; background: var(--bg-dark); border-radius: 4px;
  position: relative; overflow: hidden;
}
.spectrum-bars {
  display: flex; align-items: flex-end; height: 100%; gap: 1px; padding: 0 4px;
}
.spec-bar {
  flex: 1;
  background: linear-gradient(to top, var(--green), var(--cyan));
  border-radius: 1px 1px 0 0; opacity: 0.7; transition: height 0.2s;
}

/* Scope */
.scope {
  height: 100px; background: var(--bg-dark); border-radius: 4px;
  position: relative; overflow: hidden;
}
.scope-grid {
  position: absolute; inset: 0;
  background-image:
    linear-gradient(rgba(0,212,255,0.05) 1px, transparent 1px),
    linear-gradient(90deg, rgba(0,212,255,0.05) 1px, transparent 1px);
  background-size: 20px 20px;
}
.scope-line svg { width: 100%; height: 100%; }

/* Connection status */
.conn-status {
  position: fixed; top: 8px; right: 16px;
  font-size: 0.65rem; padding: 3px 10px; border-radius: 12px;
  background: var(--bg-card); border: 1px solid var(--border);
  z-index: 100;
}
.conn-status.connected { color: var(--green); border-color: var(--green); }
.conn-status.disconnected { color: var(--red); border-color: var(--red); }
</style>
</head>
<body>

<div class="conn-status connected" id="conn-status">● Connecté</div>

<div class="tb-container">
  <div class="tb-header">
    <div>
      <div class="tb-title">◈ TORRE BERT 2.0</div>
      <div class="tb-subtitle">Station d'Écoute Spatiale — Frères Judica-Cordiglia · 2026</div>
    </div>
    <div class="tb-clocks">
      <div class="tb-clock">
        <div class="tb-clock-label">UTC</div>
        <div class="tb-clock-value" id="utc-clock">--:--:--</div>
      </div>
      <div class="tb-clock">
        <div class="tb-clock-label">Local</div>
        <div class="tb-clock-value" id="local-clock">--:--:--</div>
      </div>
      <div class="tb-clock">
        <div class="tb-clock-label">LAT / LON</div>
        <div class="tb-clock-value" style="font-size:0.75rem" id="coords">45.07°N / 7.69°E</div>
      </div>
    </div>
  </div>

  <div class="tb-grid">
    <!-- COLONNE 1 : SKY MAP + SPECTRUM -->
    <div>
      <div class="tb-panel">
        <div class="tb-panel-header">
          <span class="tb-panel-title">◉ Carte du Ciel — Satellites Visibles</span>
          <span class="tb-panel-badge" id="sat-count">0 visibles</span>
        </div>
        <div class="sky-map" id="sky-map">
          <div class="sky-horizon"></div>
        </div>
        <div style="margin-top:8px; display:flex; gap:12px; flex-wrap:wrap; font-size:0.65rem;">
          <span><span style="display:inline-block;width:8px;height:8px;border-radius:50%;background:var(--green);margin-right:4px;"></span>ISS</span>
          <span><span style="display:inline-block;width:8px;height:8px;border-radius:50%;background:var(--cyan);margin-right:4px;"></span>NOAA</span>
          <span><span style="display:inline-block;width:8px;height:8px;border-radius:50%;background:var(--amber);margin-right:4px;"></span>Meteor</span>
          <span><span style="display:inline-block;width:8px;height:8px;border-radius:50%;background:var(--purple);margin-right:4px;"></span>GOES</span>
          <span><span style="display:inline-block;width:8px;height:8px;border-radius:50%;background:var(--red);margin-right:4px;"></span>Iridium</span>
        </div>
      </div>

      <div class="tb-panel" style="margin-top:12px;">
        <div class="tb-panel-header">
          <span class="tb-panel-title">⌇ Spectre RF — 137-1700 MHz</span>
          <span class="tb-panel-badge">Live</span>
        </div>
        <div class="spectrum" id="spectrum">
          <div class="spectrum-bars" id="spec-bars"></div>
        </div>
        <div style="display:flex; justify-content:space-between; margin-top:6px; font-size:0.6rem; color:var(--text-dim);">
          <span>137 MHz</span><span>500 MHz</span><span>1000 MHz</span><span>1626 MHz</span><span>1700 MHz</span>
        </div>
      </div>
    </div>

    <!-- COLONNE 2 : FRÉQUENCES + CONTRÔLES -->
    <div>
      <div class="tb-panel">
        <div class="tb-panel-header">
          <span class="tb-panel-title">◫ Fréquences Actives</span>
          <span class="tb-panel-badge" id="freq-badge">0 actives</span>
        </div>
        <div id="freq-list"></div>
      </div>

      <div class="tb-panel" style="margin-top:12px;">
        <div class="tb-panel-header">
          <span class="tb-panel-title">▶ Contrôles Rapides</span>
        </div>
        <div style="max-height:360px; overflow-y:auto; padding-right:2px;">
        <button class="ctrl-btn" onclick="startRx('noaa')">
          <span class="dot green"></span><span>▶ Démarrer réception NOAA</span>
        </button>
        <button class="ctrl-btn" onclick="startRx('meteor')">
          <span class="dot amber"></span><span>▶ Démarrer réception Meteor</span>
        </button>
        <button class="ctrl-btn" onclick="startRx('iss')">
          <span class="dot green"></span><span>▶ Capturer SSTV ISS</span>
        </button>
        <button class="ctrl-btn" onclick="startRx('ads-b')">
          <span class="dot red"></span><span>▶ Démarrer ADS-B (dump1090)</span>
        </button>
        <button class="ctrl-btn" onclick="stopAdsb()">
          <span class="dot red"></span><span>■ Arrêter ADS-B</span>
        </button>
        <button class="ctrl-btn" onclick="startIridium()">
          <span class="dot red"></span><span>▶ Démarrer Iridium (dongle Sawbird)</span>
        </button>
        <button class="ctrl-btn" onclick="stopIridium()">
          <span class="dot red"></span><span>■ Arrêter Iridium</span>
        </button>
        <button class="ctrl-btn" onclick="startInmarsat('std-c')">
          <span class="dot purple"></span><span>▶ Démarrer Inmarsat STD-C</span>
        </button>
        <button class="ctrl-btn" onclick="startInmarsat('aero')">
          <span class="dot purple"></span><span>▶ Démarrer Inmarsat AERO</span>
        </button>
        <button class="ctrl-btn" onclick="stopInmarsat()">
          <span class="dot purple"></span><span>■ Arrêter Inmarsat</span>
        </button>
        <button class="ctrl-btn" onclick="updateTLE()">
          <span class="dot amber"></span><span>↻ Mettre à jour les TLE</span>
        </button>
        <button class="ctrl-btn" onclick="scanSDR()">
          <span class="dot green"></span><span>⟲ Scanner matériel SDR</span>
        </button>
        </div>
      </div>
    </div>


    <!-- COLONNE 3 : SDR + LOGS + SCOPE -->
    <div>
      <div class="tb-panel">
        <div class="tb-panel-header">
          <span class="tb-panel-title">◈ Matériel SDR</span>
          <span class="tb-panel-badge" id="sdr-badge">0/0 online</span>
        </div>
        <div id="sdr-list"></div>
      </div>

      <div class="tb-panel" style="margin-top:12px;">
        <div class="tb-panel-header">
          <span class="tb-panel-title">◊ Journal d'Activité</span>
          <span class="tb-panel-badge">Live</span>
        </div>
        <div id="activity-log" style="max-height: 200px; overflow-y: auto;"></div>
      </div>

      <div class="tb-panel" style="margin-top:12px;">
        <div class="tb-panel-header">
          <span class="tb-panel-title">◡ Signal Scope</span>
          <span class="tb-panel-badge" id="scope-freq">137.100 MHz</span>
        </div>
        <div class="scope">
          <div class="scope-grid"></div>
          <div class="scope-line">
            <svg viewBox="0 0 400 100" preserveAspectRatio="none">
              <polyline fill="none" stroke="#00d4ff" stroke-width="1.5" points="" id="scope-poly"/>
            </svg>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>

<script>
// ─── Horloges ───
function updateClocks() {
  const now = new Date();
  document.getElementById('utc-clock').textContent = now.toISOString().substr(11, 8);
  document.getElementById('local-clock').textContent = now.toLocaleTimeString('fr-FR', {hour12: false});
}
setInterval(updateClocks, 1000);
updateClocks();

// ─── Données globales ───
let stationData = {};
let lastData = null;

// ─── Récupération API ───
async function fetchState() {
  try {
    const res = await fetch('/api/state');
    const data = await res.json();
    stationData = data;
    renderAll();
    document.getElementById('conn-status').textContent = '● Connecté';
    document.getElementById('conn-status').className = 'conn-status connected';
  } catch (e) {
    document.getElementById('conn-status').textContent = '● Déconnecté';
    document.getElementById('conn-status').className = 'conn-status disconnected';
  }
}
setInterval(fetchState, 1500);
fetchState();

// ─── Rendu complet ───
function renderAll() {
  if (!stationData.satellites) return;
  renderSky();
  renderSpectrum();
  renderFrequencies();
  renderSDR();
  renderLogs();
  renderScope();
  document.getElementById('coords').textContent = (stationData.lat||45.07).toFixed(2) + '°N / ' + (stationData.lon||7.69).toFixed(2) + '°E';
}

// ─── Carte du ciel ───
function renderSky() {
  const map = document.getElementById('sky-map');
  map.querySelectorAll('.sky-sat, .sky-label').forEach(el => el.remove());
  let visible = 0;
  stationData.satellites.forEach(sat => {
    // Projection simple : élévation -> Y (haut), azimuth -> X
    const y = Math.max(5, Math.min(85, 85 - (sat.elevation / 90) * 80));
    const x = Math.max(5, Math.min(95, (sat.azimuth / 360) * 90 + 5));
    if (sat.elevation > 0) visible++;

    const el = document.createElement('div');
    el.className = 'sky-sat ' + sat.type;
    el.style.left = x + '%';
    el.style.top = y + '%';
    el.title = sat.name + '\nÉlévation: ' + sat.elevation.toFixed(1) + '°\nAzimut: ' + sat.azimuth.toFixed(1) + '°\nSignal: ' + (sat.signal_db > -900 ? sat.signal_db + ' dB' : 'N/A');
    map.appendChild(el);

    const lbl = document.createElement('div');
    lbl.className = 'sky-label';
    lbl.style.left = (x + 1.5) + '%';
    lbl.style.top = (y - 3) + '%';
    lbl.textContent = sat.name;
    map.appendChild(lbl);
  });
  document.getElementById('sat-count').textContent = visible + ' visibles';
}

// ─── Spectre ───
function renderSpectrum() {
  const container = document.getElementById('spec-bars');
  if (!stationData.spectrum || container.children.length === 0) {
    container.innerHTML = '';
    for (let i = 0; i < 128; i++) {
      const bar = document.createElement('div');
      bar.className = 'spec-bar';
      bar.style.height = '5%';
      container.appendChild(bar);
    }
  }
  const bars = container.querySelectorAll('.spec-bar');
  stationData.spectrum.forEach((val, i) => {
    if (bars[i]) bars[i].style.height = val + '%';
  });
}

// ─── Fréquences ───
function renderFrequencies() {
  const list = document.getElementById('freq-list');
  const freqs = [
    {name: 'ISS Voix/SSTV', freq: 145.800, status: 'En vue', cls: 'active'},
    {name: 'NOAA-19 APT', freq: 137.100, status: 'Décode', cls: 'active'},
    {name: 'Meteor-M2-2', freq: 137.900, status: '+12 min', cls: 'upcoming'},
    {name: 'Iridium', freq: 1626.5625, status: 'Veille', cls: 'idle'},
    {name: 'Inmarsat Aero', freq: 1537.470, status: 'Veille', cls: 'idle'},
    {name: 'ADS-B', freq: 1090.000, status: '24 tr/min', cls: 'active'},
    {name: 'GOES-16 HRIT', freq: 1694.100, status: '+45 min', cls: 'upcoming'},
  ];
  // Mise à jour depuis données serveur si dispo
  if (stationData.satellites) {
    freqs[0].status = stationData.satellites[0].active ? 'En vue · ' + stationData.satellites[0].elevation.toFixed(0) + '°' : 'Hors vue';
    freqs[0].cls = stationData.satellites[0].active ? 'active' : 'idle';
    freqs[1].status = stationData.satellites[1].active ? 'Décode · SNR ' + stationData.satellites[1].signal_db + 'dB' : 'Hors vue';
    freqs[1].cls = stationData.satellites[1].active ? 'active' : 'idle';
  }
  list.innerHTML = freqs.map(f => `
    <div class="freq-row" onclick="tuneTo(${f.freq})">
      <span class="freq-name">${f.name}</span>
      <span class="freq-mhz">${f.freq.toFixed(3)}</span>
      <span class="freq-status ${f.cls}">${f.status}</span>
    </div>
  `).join('');
  const activeCount = freqs.filter(f => f.cls === 'active').length;
  document.getElementById('freq-badge').textContent = activeCount + ' actives';
}

// ─── SDR ───
function renderSDR() {
  const list = document.getElementById('sdr-list');
  if (!stationData.sdr_devices) return;
  let online = 0;
  list.innerHTML = stationData.sdr_devices.map(sdr => {
    if (sdr.status === 'online') online++;
    let detail = sdr.role || '';
    if (sdr.status === 'online') {
      if (sdr.id === 'rtl0') {
        detail = stationData.busy_with ? 'Occupé : ' + stationData.busy_with : (sdr.role + ' · Libre');
      } else if (sdr.id === 'rtl1') {
        detail = stationData.iridium_active ? 'Iridium en cours' : (sdr.role + ' · Libre');
      } else if (sdr.id === 'rtl2') {
        detail = stationData.inmarsat_active ? ('Inmarsat ' + stationData.inmarsat_mode + ' en cours') : (sdr.role + ' · Libre');
      }
    } else {
      detail = sdr.status;
    }
    return `
      <div class="sdr-item">
        <div class="sdr-icon ${sdr.status}">${sdr.name.charAt(0)}</div>
        <div class="sdr-info">
          <div class="sdr-name">${sdr.name}</div>
          <div class="sdr-detail">${detail}</div>
        </div>
        <div class="sdr-freq">${sdr.freq > 0 ? sdr.freq.toFixed(3) : '--.---'}</div>
      </div>
    `;
  }).join('');
  document.getElementById('sdr-badge').textContent = online + '/' + stationData.sdr_devices.length + ' online';
}

// ─── Logs ───
function renderLogs() {
  const container = document.getElementById('activity-log');
  if (!stationData.logs) return;
  container.innerHTML = stationData.logs.slice().reverse().map(l => `
    <div class="log-entry">
      <span class="log-time">${l.time}</span>
      <span class="log-msg ${l.level}">${l.msg}</span>
    </div>
  `).join('');
}

// ─── Scope ───
function renderScope() {
  const svg = document.getElementById('scope-poly');
  const points = [];
  const t = Date.now() * 0.002;
  for (let i = 0; i <= 400; i += 2) {
    const y = 50 + Math.sin(i * 0.05 + t) * 20 + Math.sin(i * 0.13 + t * 1.3) * 10 + (Math.random() - 0.5) * 8;
    points.push(`${i},${Math.max(5, Math.min(95, y))}`);
  }
  svg.setAttribute('points', points.join(' '));
  requestAnimationFrame(renderScope);
}

// ─── Actions ───
function tuneTo(freq) {
  document.getElementById('scope-freq').textContent = freq.toFixed(3) + ' MHz';
  fetch('/api/tune/rtl0/' + freq).catch(()=>{});
}
function startRx(target) {
  fetch('/api/receive/' + target).catch(()=>{});
}
function stopAdsb() {
  fetch('/api/receive/ads-b/stop').catch(()=>{});
}
function startIridium() {
  fetch('/api/receive/iridium').catch(()=>{});
}
function stopIridium() {
  fetch('/api/receive/iridium/stop').catch(()=>{});
}
function startInmarsat(mode) {
  fetch('/api/receive/inmarsat/' + mode).catch(()=>{});
}
function stopInmarsat() {
  fetch('/api/receive/inmarsat/stop').catch(()=>{});
}
function updateTLE() {
  fetch('/api/update-tle').catch(()=>{});
}
function scanSDR() {
  fetch('/api/sdr/scan').then(r => r.json()).then(d => {
    console.log('SDR scan:', d);
  }).catch(()=>{});
}
</script>
</body>
</html>
HTMLEOF

# ═══════════════════════════════════════════════════════════════════════════
#  4. SERVICE SYSTEMD
# ═══════════════════════════════════════════════════════════════════════════

cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=Torre Bert 2.0 — Dashboard SIGINT
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/python3 ${INSTALL_DIR}/app.py
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1
# Index (ou numéro de série via rtl_eeprom) des 3 dongles — à ajuster si l'ordre d'énumération
# USB ne correspond pas à ce que tu attends (voir le message affiché en fin d'installation).
Environment=TB_RTL_MAIN=0
Environment=TB_RTL_IRIDIUM=1
Environment=TB_RTL_INMARSAT=2

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"

# ═══════════════════════════════════════════════════════════════════════════
#  5. FINALISATION
# ═══════════════════════════════════════════════════════════════════════════

chown -R "$USER_SDR:$USER_SDR" "$INSTALL_DIR"

systemctl start "$SERVICE_NAME"

IP=$(hostname -I | awk '{print $1}')

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo -e "  ${GREEN}DASHBOARD TORRE BERT 2.0 INSTALLÉ${NC}"
echo ""
echo "  📍 Répertoire     : $INSTALL_DIR"
echo "  🌐 URL Dashboard   : http://$IP:$PORT"
echo "  🌐 Localhost       : http://localhost:$PORT"
echo "  🔧 Service systemd : $SERVICE_NAME"
echo ""
echo "  Commandes utiles :"
echo "    sudo systemctl status $SERVICE_NAME"
echo "    sudo systemctl restart $SERVICE_NAME"
echo "    sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "  Le dashboard est accessible depuis n'importe quel appareil"
echo "  sur le réseau local (tablette, téléphone, autre PC)."
echo ""
echo -e "  ${YELLOW}IMPORTANT — identification des 3 dongles RTL-SDR :${NC}"
echo "  Le script suppose l'ordre USB 0=principal, 1=Iridium, 2=Inmarsat, ce qui"
echo "  n'est PAS garanti au reboot. Pour fiabiliser (recommandé) :"
echo "    1. Débranche tout sauf un dongle, note son index avec : rtl_test -t"
echo "    2. Fige un numéro de série lisible : rtl_eeprom -d 0 -s IRIDIUM   (par ex.)"
echo "    3. Répète pour chaque dongle, puis remplace les index par les numéros de"
echo "       série dans les lignes Environment=TB_RTL_* de :"
echo "       /etc/systemd/system/${SERVICE_NAME}.service"
echo "    4. sudo systemctl daemon-reload && sudo systemctl restart $SERVICE_NAME"
echo ""
echo -e "  ${YELLOW}À vérifier après ce premier lancement :${NC}"
echo "    - satdump peut nécessiter un ajustement du flag de sélection de dongle"
echo "      (--source-arg) selon la version compilée — voir les commentaires dans app.py."
echo "    - Une seule chaîne à la fois par dongle : NOAA/Meteor/ISS/ADS-B se partagent"
echo "      rtl0, mais Iridium (rtl1) et Inmarsat (rtl2) peuvent tourner en parallèle."
echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
