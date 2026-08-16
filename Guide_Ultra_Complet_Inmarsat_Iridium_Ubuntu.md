# 📡 Guide Ultra-Complet : Réception et Analyse Inmarsat & Iridium sur Ubuntu

> **Version étendue** — Du montage matériel au décodage avancé, en passant par la théorie des signaux, l'automatisation et la légalité.

---

## Table des matières

1. [Introduction et contexte](#1-introduction-et-contexte)
2. [Théorie des signaux et des constellations](#2-théorie-des-signaux-et-des-constellations)
3. [La chaîne de réception RTL-SDR](#3-la-chaîne-de-réception-rtl-sdr)
4. [Matériel requis et montage](#4-matériel-requis-et-montage)
5. [Préparation complète d'Ubuntu](#5-préparation-complète-dubuntu)
6. [Visualisation du spectre en temps réel](#6-visualisation-du-spectre-en-temps-réel)
7. [Réception Inmarsat (GEO)](#7-réception-inmarsat-geo)
8. [Réception Iridium (LEO)](#8-réception-iridium-leo)
9. [Enregistrement et analyse IQ hors-ligne](#9-enregistrement-et-analyse-iq-hors-ligne)
10. [Décodage avancé](#10-décodage-avancé)
11. [Scripts d'automatisation](#11-scripts-dautomatisation)
12. [Dépannage exhaustif](#12-dépannage-exhaustif)
13. [Aspects légaux et éthiques](#13-aspects-légaux-et-éthiques)
14. [Ressources et communautés](#14-ressources-et-communautés)
15. [Glossaire](#15-glossaire)

---

## 1. Introduction et contexte

### 1.1 Pourquoi recevoir Inmarsat et Iridium ?

Les satellites de télécommunications géostationnaires (**Inmarsat**) et en orbite basse (**Iridium**) émettent en bande L (~1,5–1,6 GHz), une fréquence accessible avec un simple dongle RTL-SDR et une antenne patch. Ces signaux contiennent :

- **Données de sécurité maritime** (NAVAREA, météo, EGC)
- **Communications aéronautiques** (ACARS via Inmarsat Aero)
- **Signaux de télémétrie et paging** (Iridium)
- **Beacons et porteuses de référence**

Ces signaux offrent une excellente introduction à la radio logicielle (SDR), combinant physique des ondes, traitement du signal numérique, et programmation.

### 1.2 Ce que vous apprendrez

- Pointer un satellite géostationnaire avec une antenne directive
- Recevoir des satellites LEO sans pointage (constellation omniprésente)
- Manipuler des échantillons IQ complexes
- Utiliser GNU Radio, SDR++, Inspectrum, JAERO et gr-iridium
- Automatiser des captures et analyses

---

## 2. Théorie des signaux et des constellations

### 2.1 Inmarsat — Orbite Géostationnaire (GEO)

| Paramètre | Valeur |
|-----------|--------|
| Altitude | ~35 786 km |
| Vitesse angulaire | Identique à la rotation terrestre |
| Position | Fixe dans le ciel (azimut/élévation constants) |
| Bande L (espace→terre) | 1525 – 1559 MHz |
| Bande L (terre→espace) | 1626,5 – 1660,5 MHz |
| Polarisation | Circulaire (RHCP/LHCP) |

**Constellation Inmarsat-4 et I-6 :**
- **IOR** (Indian Ocean Region) — 64° E
- **AOR-W** (Atlantic Ocean Region-West) — 54° W
- **AOR-E** (Atlantic Ocean Region-East) — 15,5° W
- **POR** (Pacific Ocean Region) — 178° E

Depuis la France métropolitaine, c'est **AOR-E (~15,5° W)** qui est visible.

**Services :**
- **Inmarsat-C** : Messages courts, données, EGC (Enhanced Group Call) — 600 bps BPSK
- **Inmarsat Aero** : Voix et données ACARS — 600/1200 bps BPSK/AM
- **FleetBroadband / BGAN** : Données haut débit (plus difficile à recevoir sans équipement dédié)

### 2.2 Iridium — Orbite Basse (LEO)

| Paramètre | Valeur |
|-----------|--------|
| Altitude | ~780 km |
| Nombre de satellites | 66 (+ spares) |
| Orbites | 6 plans orbitaux à 86,4° d'inclinaison |
| Période orbitale | ~100 minutes |
| Bande | 1616 – 1626,5 MHz |
| Accès multiple | TDMA/FDMA |
| Décalage Doppler | ±40 kHz à 1,6 GHz |

**Architecture :**
- Les satellites fonctionnent en mode **bent-pipe** (répéteur) ou avec traitement à bord
- Les utilisateurs communiquent directement avec le satellite visible
- Les satellites se déplacent rapidement dans le ciel (passage de ~10 min)

**Signaux accessibles :**
- **Ring alerts / paging** : Non chiffrés, contiennent des identifiants et horodatages
- **Canaux de contrôle** : Télémétrie, synchronisation
- **Trafic utilisateur** : Chiffré (propriétaire), inaccessible

### 2.3 Physique des ondes en bande L

- **Atténuation atmosphérique** : Faible en bande L (< 0,1 dB)
- **Traversée du verre** : Possible (perte ~3–6 dB selon le type de vitrage)
- **Traversée des murs** : Très atténuante (béton, métal) — privilégier l'extérieur
- **Polarisation** : Les antennes patch sont généralement à polarisation linéaire ou circulaire. Le signal satellite est circulaire (RHCP). Une antenne linéaire récupère 3 dB de moins mais suffit pour la réception.

---

## 3. La chaîne de réception RTL-SDR

### 3.1 Le tuner R820T2

Le **Rafael Micro R820T2** est un tuner TV numérique rebaptisé radio logicielle grâce au projet RTL-SDR.

| Caractéristique | Valeur |
|-----------------|--------|
| Plage de fréquences | ~24 – 1766 MHz |
| Bande passante max | ~2,4 MHz (stable à 2,048 MHz) |
| Résolution ADC | 8 bits |
| Sensibilité | ~-110 dBm (typique) |
| Niveau de bruit (NF) | ~3,5 – 6 dB |
| Bias-tee | 4,5 V (logiciel) |

**Limitations :**
- Échantillonnage 8 bits → plage dynamique limitée (~50 dB)
- Images de fréquence (aliasing) possibles si filtrage insuffisant
- Bruit USB 3.0 à proximité (fréquences harmoniques)

### 3.2 Le SAWbird+ — Préamplification et filtrage

Le **SAWbird+** est un amplificateur faible bruit (LNA) + filtre SAW intégré.

| Modèle | Bande | Gain | NF |
|--------|-------|------|-----|
| SAWbird+ iO | 1525 – 1560 MHz | ~30 dB | < 1 dB |
| SAWbird+ IR | 1616 – 1626,5 MHz | ~30 dB | < 1 dB |

**Alimentation :** Via bias-tee 4,5 V du RTL-SDR (courant ~60 mA).

**Schéma de la chaîne complète :**

```
[Antenne patch] ──SMA──> [SAWbird+ IN] ──LNA+Filtrage──> [SAWbird+ OUT] ──SMA──> [RTL-SDR] ──USB──> [PC]
                                    ^
                              Alimentation 4,5V
                              (Bias-tee logiciel)
```

---

## 4. Matériel requis et montage

### 4.1 Liste du matériel

| Équipement | Référence suggérée | Prix indicatif |
|-----------|-------------------|----------------|
| Dongle RTL-SDR | Nooelec NESDR Smart (R820T2 + TCXO + bias-tee) | ~30 € |
| LNA + Filtre Inmarsat | Nooelec SAWbird+ iO | ~45 € |
| LNA + Filtre Iridium | Nooelec SAWbird+ IR | ~45 € |
| Antenne Inmarsat | Patch 1525–1560 MHz | ~35 € |
| Antenne Iridium | Patch 1616–1626,5 MHz | ~35 € |
| Câble SMA | SMA mâle-mâble, 50 Ω, < 30 cm entre SAWbird et dongle | ~10 € |
| Rallonge USB | USB 2.0 active ou passive de 1–3 m | ~10 € |
| Support antenne | Trépied photo avec adaptateur 1/4" | ~15 € |

### 4.2 Montage pas à pas

#### Étape 1 — Assemblage intérieur (test)

1. **Ne branchez pas encore le dongle USB.**
2. Vissez l'antenne patch sur l'entrée **IN/ANT** du SAWbird+.
3. Vissez un câble SMA entre la sortie **OUT** du SAWbird+ et l'entrée du NESDR Smart.
4. Vérifiez que les connecteurs sont bien serrés (à la main, ne pas forcer).

#### Étape 2 — Positionnement

**Pour Inmarsat (GEO) :**
- Utilisez un calculateur de pointage GEO (ex: DishPointer ou Satellite Calculations)
- Entrez votre position GPS et la longitude du satellite (15,5° W pour AOR-E)
- Obtenez azimut et élévation
- Exemple depuis Paris :
  - Azimut : ~197° (SSO)
  - Élévation : ~32°
- Orientez l'antenne (face plane vers le satellite)
- Le faisceau est large (~70°) : une orientation approximative suffit pour commencer

**Pour Iridium (LEO) :**
- Posez l'antenne à plat, face vers le zénith (ciel)
- Vue dégagée à 360° idéalement
- Évitez les obstacles proches (murs, arbres)

#### Étape 3 — Connexion au PC

1. Branchez la rallonge USB sur un port **USB 2.0** (évitez USB 3.0 à proximité du dongle)
2. Branchez le NESDR Smart sur la rallonge
3. Éloignez le dongle du PC (30 cm minimum) pour réduire le bruit d'interférence

---

## 5. Préparation complète d'Ubuntu

### 5.1 Mise à jour du système

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential git cmake pkg-config \
  libusb-1.0-0-dev libboost-all-dev libfftw3-dev \
  libsoapysdr-dev soapysdr-tools \
  libqt5widgets5 libqt5charts5-dev \
  gnuradio gnuradio-dev \
  wine wine64 winetricks \
  rtl-sdr gqrx-sdr \
  sox libsox-fmt-all \
  python3-pip python3-numpy python3-scipy python3-matplotlib
```

### 5.2 Blacklist des pilotes TV

Le noyau Linux charge par défaut des pilotes DVB-T qui empêchent l'accès raw au dongle.

```bash
echo -e "blacklist dvb_usb_rtl28xxu\nblacklist rtl2832\nblacklist rtl2830" | \
  sudo tee /etc/modprobe.d/blacklist-rtlsdr.conf
sudo update-initramfs -u
```

**Redémarrage obligatoire :**
```bash
sudo reboot
```

### 5.3 Vérification du dongle

Après redémarrage :

```bash
rtl_test -t
```

**Sortie attendue :**
```
Found 1 device(s):
  0:  Realtek, RTL2838UHIDIR, SN: 00000001

Using device 0: Generic RTL2832U OEM
Found Rafael Micro R820T tuner
Supported gain values (29): 0.0 0.9 1.4 ... 49.6
Sampling at 2048000 S/s.
```

Si vous obtenez `No supported devices found`, vérifiez :
- Le dongle est bien branché
- Les pilotes DVB sont bien blacklistés
- Essayez un autre port USB

### 5.4 Installation de rtl_biast (bias-tee)

```bash
sudo apt install rtl-sdr
# rtl_biast est généralement inclus dans le paquet rtl-sdr moderne

# Vérification
rtl_biast -h
```

### 5.5 Installation de SDR++ (méthode recommandée)

SDR++ est un logiciel moderne, léger, avec support natif du bias-tee.

#### Méthode A — Depuis les releases (binaire)

```bash
cd ~/Téléchargements
wget https://github.com/AlexandreRouma/SDRPlusPlus/releases/download/1.2.1/sdrpp_ubuntu_focal_amd64.deb
sudo apt install ./sdrpp_ubuntu_focal_amd64.deb
```

#### Méthode B — Compilation depuis les sources (version de développement)

```bash
cd ~
git clone https://github.com/AlexandreRouma/SDRPlusPlus.git
cd SDRPlusPlus
mkdir build && cd build
cmake .. -DOPT_BUILD_SOAPY_SOURCE=OFF
make -j$(nproc)
sudo make install
sudo ldconfig
```

### 5.6 Installation d'Inspectrum

```bash
sudo apt install inspectrum
```

### 5.7 Installation de SigDigger

```bash
cd ~/Téléchargements
wget https://github.com/BatchDrake/SigDigger/releases/download/v0.3.0/SigDigger-0.3.0-x86_64.AppImage
chmod +x SigDigger-0.3.0-x86_64.AppImage
sudo mv SigDigger-0.3.0-x86_64.AppImage /usr/local/bin/sigdigger
```

### 5.8 Installation de gr-iridium (pour Iridium)

```bash
cd ~
git clone https://github.com/secdev/gr-iridium.git
cd gr-iridium
mkdir build && cd build
cmake ..
make -j$(nproc)
sudo make install
sudo ldconfig
```

**Vérification :**
```bash
python3 -c "import iridium"
```

### 5.9 Configuration de Wine pour JAERO

```bash
# Activation architecture 32 bits (si nécessaire)
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install -y wine wine32 winetricks

# Configuration initiale de Wine
winecfg
# Sélectionnez Windows 10 comme version par défaut

# Téléchargement de JAERO
mkdir -p ~/JAERO && cd ~/JAERO
wget https://github.com/jonti1792/JAERO/releases/download/v1.0.4.13/JAERO.exe
```

---

## 6. Visualisation du spectre en temps réel

### 6.1 Démarrage avec SDR++

```bash
sdrpp
```

**Configuration :**

1. **Source** → RTL-SDR → Refresh → Sélectionnez le périphérique
2. **Sample Rate** : 2,048 MS/s
3. **Bias Tee** : ✓ Cocher (alimente le SAWbird+)
4. **Gain** : 30 dB (ajuster selon le spectre)
5. **Fréquence** :
   - Inmarsat : commencez à **1 541,5 MHz**
   - Iridium : commencez à **1 626 MHz**
6. **FFT Size** : 65 536 (pour une bonne résolution fréquentielle)
7. **FFT Rate** : 30 FPS

### 6.2 Démarrage avec Gqrx

```bash
# Activez d'abord le bias-tee
rtl_biast -b 1

# Lancez Gqrx
gqrx
```

**Configuration Gqrx :**

| Paramètre | Valeur |
|-----------|--------|
| Device | `rtl=0` |
| Sample Rate | 2,048 MS/s |
| Décodeur | Complexe flottant 32 bits |
| Fréquence | 1 541 500 000 Hz (Inmarsat) ou 1 626 000 000 Hz (Iridium) |
| Mode | WFM (stéréo) pour repérage, puis USB/RAW |
| Gain RF | ~30 dB |

### 6.3 Interprétation du spectre

#### Inmarsat — Ce que vous devez voir

- **Beacon (porteuse pilote)** : Raie verticale fine et constante, très au-dessus du bruit
  - Fréquence typique : ~1 541,45 MHz (varie selon le satellite)
  - Utilisation : **référence d'orientation** — maximisez le S/N en ajustant l'antenne
- **STD-C** : Porteuse continue (NCS) + rafales courtes de quelques secondes
- **Aero** : Signaux plus larges entre 1 545 et 1 559 MHz

#### Iridium — Ce que vous devez voir

- **Bursts TDMA** : Petits tirets horizontaux de quelques millisecondes
- **Pente Doppler** : Les bursts sont légèrement inclinés (effet Doppler du LEO)
- **Fréquence** : Bursts dispersés sur toute la bande 1 616–1 626,5 MHz
- **Validation** : Vous devez voir plusieurs bursts par seconde

---

## 7. Réception Inmarsat (GEO)

### 7.1 Identification du satellite

Depuis la France, le satellite visible est **Inmarsat-4 AOR-E** à ~15,5° W.

**Vérification en ligne :**
- CelesTrak — éphémérides GEO
- SatBeams — couverture et fréquences
- LyngSat — fréquences actives

### 7.2 Fréquences principales

| Service | Fréquence centrale | Description |
|---------|-------------------|-------------|
| NCS / Beacon | 1 541,450 MHz | Porteuse pilote du satellite |
| STD-C NCS | 1 531,000 MHz | Canal de contrôle réseau |
| STD-C TDM | 1 531,500 MHz | Canal de données |
| Aero H+ | 1 545,200 MHz | Voix aéronautique |
| Aero-C | 1 546,000 MHz | Données ACARS |
| Aero-I | 1 551,000 MHz | Données aéronautiques |

*Note : Ces fréquences sont indicatives. Le spectre varie selon le trafic et la région.*

### 7.3 Optimisation du pointage

1. Réglez-vous sur le beacon (~1 541,45 MHz)
2. Ajustez lentement l'azimut et l'élévation
3. Observez le niveau du pic dans SDR++ ou Gqrx
4. **Objectif** : Maximiser le rapport Signal/Bruit (S/N)
5. Une fois optimisé, fixez l'antenne solidement

### 7.4 Capture IQ brute (Inmarsat)

```bash
# Activez le bias-tee
rtl_biast -b 1

# Capture sur le beacon / canal STD-C
rtl_sdr -f 1541450000 -s 2048000 -g 40 -T inmarsat_beacon_2MHz.iq

# -f : fréquence centrale (Hz)
# -s : taux d'echantillonnage (2,048 MHz)
# -g : gain (0–49,6 dB)
# -T : active le bias-tee
# Sortie : fichier binaire IQ, 8 bits complexe (I/Q entrelacés)

# Pour arrêter : Ctrl+C
```

**Estimation de la taille du fichier :**
- 2,048 MS/s × 2 octets (I+Q) = 4,096 Mo/s
- 1 minute = ~246 Mo
- 10 minutes = ~2,4 Go

### 7.5 Enregistrement audio pour JAERO

Dans Gqrx :
1. Centrez-vous sur un canal actif (ex: 1 545,2 MHz Aero)
2. Mode : **USB** (Bande Latérale Unique)
3. Bande passante audio : 10–12 kHz
4. Cliquez sur l'icône d'enregistrement (disquette rouge)
5. Enregistrez 5–10 minutes minimum

---

## 8. Réception Iridium (LEO)

### 8.1 Particularités du signal Iridium

| Caractéristique | Description |
|-----------------|-------------|
| Modulation | QPSK / DE-QPSK |
| Accès multiple | TDMA (Time Division Multiple Access) |
| Burst | ~8,28 ms |
| Débit symbole | 25 ksymb/s |
| Décalage Doppler | Jusqu'à ±40 kHz |
| Bande par canal | ~41,67 kHz |

### 8.2 Capture IQ brute (Iridium)

```bash
# Activez le bias-tee
rtl_biast -b 1

# Capture centrée sur 1 626 MHz (milieu de la bande)
rtl_sdr -f 1626000000 -s 2048000 -g 40 -T iridium_capture.iq

# Alternative : capture plus large avec un SDR plus performant
# (Le RTL-SDR est limité à 2,4 MHz, ce qui couvre ~48 canaux)
```

### 8.3 Utilisation de gr-iridium

```bash
# Analyse d'une capture IQ existante
cd ~/gr-iridium
python3 iridium_extractor.py -f 1626000000 -s 2048000 ~/iridium_capture.iq

# Ou en temps réel (nécessite une source SDR configurée dans GNU Radio)
# Voir le README de gr-iridium pour les flowgraphs
```

**Sortie typique :**
```
IRA: t=1234567890.123 f=1626000000.000 s=0 l=100
IRA: t=1234567890.456 f=1626000041.667 s=1 l=98
...
```

---

## 9. Enregistrement et analyse IQ hors-ligne

### 9.1 Format des fichiers IQ

Les fichiers générés par `rtl_sdr` contiennent des échantillons complexes 8 bits :
- Structure : [I0][Q0][I1][Q1][I2][Q2]...
- I et Q : unsigned 8-bit (0–255), centrés sur 127

### 9.2 Analyse avec Inspectrum

```bash
inspectrum
```

**Procédure :**
1. File → Open → sélectionnez le fichier `.iq`
2. Configurez :
   - Sample rate : `2048000`
   - Sample format : **Complex, unsigned 8-bit**
3. Utilisez la molette pour zoomer
4. Activez les curseurs pour mesurer :
   - Durée des bursts
   - Espacement fréquentiel
   - Pente Doppler (Iridium)

### 9.3 Analyse avec SigDigger

```bash
sigdigger
```

**Avantages :**
- Analyse spectrale avancée (spectrogramme haute résolution)
- Démodulation intégrée
- Mesure de phase et amplitude
- Support des fichiers IQ très volumineux

### 9.4 Analyse avec Python (script personnalisé)

```python
#!/usr/bin/env python3
# Script d'analyse IQ basique pour signaux Inmarsat/Iridium

import numpy as np
import matplotlib.pyplot as plt

# Paramètres
filename = "inmarsat_beacon_2MHz.iq"
sample_rate = 2_048_000
center_freq = 1_541_450_000

# Lecture du fichier
raw = np.fromfile(filename, dtype=np.uint8)

# Conversion I/Q
I = raw[0::2].astype(np.float32) - 127.5
Q = raw[1::2].astype(np.float32) - 127.5
samples = I + 1j * Q

# Normalisation
samples = samples / np.max(np.abs(samples))

# Spectre moyenné
n_fft = 65536
overlap = 0.5
hop = int(n_fft * (1 - overlap))

spectrogram = []
for i in range(0, len(samples) - n_fft, hop):
    window = samples[i:i+n_fft] * np.hanning(n_fft)
    fft = np.fft.fftshift(np.fft.fft(window))
    spectrogram.append(20 * np.log10(np.abs(fft) + 1e-10))

spectrogram = np.array(spectrogram)

# Affichage
plt.figure(figsize=(14, 6))
plt.imshow(spectrogram.T, aspect='auto', origin='lower', cmap='viridis',
           extent=[0, len(samples)/sample_rate, 
                   center_freq - sample_rate/2, center_freq + sample_rate/2])
plt.colorbar(label='Amplitude (dB)')
plt.xlabel('Temps (s)')
plt.ylabel('Frequence (Hz)')
plt.title('Spectrogramme Inmarsat')
plt.tight_layout()
plt.savefig('spectrogram_inmarsat.png', dpi=150)
print("Spectrogramme sauvegarde : spectrogram_inmarsat.png")
```

---

## 10. Décodage avancé

### 10.1 JAERO — Décodage Inmarsat (Aero / STD-C)

JAERO est le logiciel de référence pour décoder Inmarsat Aero et STD-C.

#### Installation et lancement

```bash
cd ~/JAERO
wine JAERO.exe
```

#### Configuration JAERO

1. **Mode** : Sélectionnez le type de signal
   - **Aero** : Voix + données ACARS (600/1200 bps)
   - **STD-C** : Messages EGC, météo, sécurité (600 bps BPSK)
2. **Source audio** :
   - Méthode simple : File → Open → sélectionnez le fichier WAV enregistré dans Gqrx
   - Méthode live (avancée) : configuration PulseAudio avec module-null-sink

#### Méthode live avec PulseAudio (optionnel)

```bash
# Creation d'un sink virtuel
pactl load-module module-null-sink sink_name=jaero_sink

# Dans Gqrx : sortie audio → "jaero_sink"
# Dans JAERO : entrée audio → monitor de "jaero_sink"
```

#### Types de messages décodables

| Type | Description | Visibilité |
|------|-------------|------------|
| EGC SafetyNET | Messages de sécurité maritime | Public |
| EGC FleetNET | Messages commerciaux | Restreint |
| ACARS | Données aéronautiques (vol, météo) | Public/Restreint |
| CPDLC | Communications pilote/contrôleur | Restreint |

### 10.2 gr-iridium — Décodage Iridium

```bash
# Extraction des bursts d'une capture
cd ~/gr-iridium
python3 iridium_extractor.py -r 2048000 -f 1626000000 -o output.bits capture.iq

# Analyse des bursts
python3 iridium_parser.py output.bits
```

**Informations extraites :**
- Horodatage des bursts
- Identifiants de canal
- Données de synchronisation
- Messages de paging (non chiffrés)

### 10.3 Universal Radio Hacker (URH)

URH est un outil puissant pour l'analyse de protocoles radio.

```bash
pip3 install urh
urh
```

**Utilisation :**
1. File → Open → sélectionnez le fichier IQ
2. Configurez le sample rate et la fréquence centrale
3. Utilisez l'onglet "Interpretation" pour zoomer sur les bursts
4. Analysez la modulation et le débit symbole

---

## 11. Scripts d'automatisation

### 11.1 Script de capture automatique Inmarsat

```bash
#!/bin/bash
# capture_inmarsat.sh — Capture automatique avec horodatage

FREQ=1541450000
SAMPLE_RATE=2048000
GAIN=40
DURATION=300  # 5 minutes
OUTPUT_DIR="$HOME/captures/inmarsat"

mkdir -p $OUTPUT_DIR

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="$OUTPUT_DIR/inmarsat_${TIMESTAMP}_${FREQ}.iq"

echo "Demarrage capture Inmarsat"
echo "Frequence : $FREQ Hz"
echo "Duree : $DURATION secondes"
echo "Fichier : $OUTPUT_FILE"

rtl_biast -b 1
timeout $DURATION rtl_sdr -f $FREQ -s $SAMPLE_RATE -g $GAIN -T "$OUTPUT_FILE"
rtl_biast -b 0

echo "Capture terminee : $OUTPUT_FILE"
ls -lh "$OUTPUT_FILE"
```

### 11.2 Script de capture automatique Iridium

```bash
#!/bin/bash
# capture_iridium.sh — Capture Iridium avec detection de passage satellite

FREQ=1626000000
SAMPLE_RATE=2048000
GAIN=40
OUTPUT_DIR="$HOME/captures/iridium"

mkdir -p $OUTPUT_DIR

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="$OUTPUT_DIR/iridium_${TIMESTAMP}.iq"

echo "Demarrage capture Iridium"
rtl_biast -b 1

# Capture continue, arret manuel (Ctrl+C)
rtl_sdr -f $FREQ -s $SAMPLE_RATE -g $GAIN -T "$OUTPUT_FILE"

rtl_biast -b 0
echo "Capture terminee"
```

### 11.3 Script de surveillance du spectre (Python)

```python
#!/usr/bin/env python3
# spectrum_monitor.py — Surveillance simple du spectre Inmarsat
# Affiche la puissance moyenne et detecte les pics

import numpy as np
import time
import signal
import sys

SAMPLE_RATE = 2_048_000
CENTER_FREQ = 1_541_450_000
GAIN = 40
THRESHOLD_DB = -30  # Seuil de detection en dB

def signal_handler(sig, frame):
    print("\nArret...")
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)

print(f"Surveillance du spectre Inmarsat a {CENTER_FREQ/1e6} MHz")
print("Ctrl+C pour arreter")

try:
    from rtlsdr import RtlSdr

    sdr = RtlSdr()
    sdr.center_freq = CENTER_FREQ
    sdr.sample_rate = SAMPLE_RATE
    sdr.gain = GAIN

    while True:
        samples = sdr.read_samples(1024*256)
        power_db = 10 * np.log10(np.mean(np.abs(samples)**2) + 1e-10)

        # Detection simple de pic (beacon)
        fft = np.fft.fftshift(np.fft.fft(samples[:4096]))
        freqs = np.fft.fftshift(np.fft.fftfreq(4096, 1/SAMPLE_RATE)) + CENTER_FREQ
        spectrum_db = 20 * np.log10(np.abs(fft) + 1e-10)
        peak_db = np.max(spectrum_db)
        peak_freq = freqs[np.argmax(spectrum_db)]

        print(f"\rPuissance moyenne : {power_db:6.1f} dB | "
              f"Pic : {peak_db:6.1f} dB @ {peak_freq/1e6:.4f} MHz", end='')

        time.sleep(0.5)

except ImportError:
    print("Module rtlsdr non installe. Installez-le avec : pip3 install pyrtlsdr")
except Exception as e:
    print(f"Erreur : {e}")
```

### 11.4 Cron job pour captures régulières

```bash
# Editez le crontab
crontab -e

# Capture Inmarsat tous les jours a 14h00 (5 minutes)
0 14 * * * /home/$USER/scripts/capture_inmarsat.sh >> /home/$USER/captures/inmarsat.log 2>&1

# Capture Iridium tous les jours a 15h00 (10 minutes)
0 15 * * * timeout 600 /home/$USER/scripts/capture_iridium.sh >> /home/$USER/captures/iridium.log 2>&1
```

---

## 12. Dépannage exhaustif

### 12.1 Problèmes matériels

| Symptôme | Diagnostic | Solution |
|----------|-----------|----------|
| `No supported devices found` | Pilote DVB actif ou dongle non reconnu | Blacklist DVB + reboot ; changer de port USB |
| Dongle très chaud | Consommation excessive | Bias-tee actif sans LNA ? Verifiez les cables |
| Signal faible malgré bon pointage | Cable trop long ou de mauvaise qualite | Utilisez du coaxial de qualite (< 30 cm entre SAWbird et dongle) |
| SAWbird non alimente | Bias-tee OFF ou cable defectueux | `rtl_biast -b 1` ; testez la tension avec un multimetre |
| Connecteurs desserres | Perte de signal intermittente | Verifiez le couplage SMA (doit etre serre a la main) |

### 12.2 Problèmes de spectre

| Symptôme | Cause probable | Solution |
|----------|---------------|----------|
| Spectre plat, aucun signal | Bias-tee OFF ; antenne mal pointee ; frequence hors bande | Activez bias-tee ; verifiez le pointage ; confirmez la frequence |
| Spectre sature (barres rouges) | Gain trop eleve | Baissez le gain a 20–30 dB |
| Raies parasites fixes a intervalles reguliers | Interferences USB 3.0 / HDMI / CPU | Eloignez le dongle du PC ; utilisez une rallonge USB ; eteignez l'ecran |
| Bruit eleve sur toute la bande | Alimentation bruyante ou port USB 3.0 | Port USB 2.0 avec hub alimente ; alimentation PC de qualite |
| Signal present puis disparait | Pointage degrade (vent, deplacement) | Fixez solidement l'antenne ; verifiez l'orientation |

### 12.3 Problèmes logiciels

| Symptôme | Cause probable | Solution |
|----------|---------------|----------|
| SDR++ ne demarre pas | Dependances manquantes | `sudo apt install libgl1 libopengl0` |
| Gqrx plante au demarrage | Configuration corrompue | `rm ~/.config/gqrx/default.conf` |
| JAERO ne decode rien | Mauvais mode ou mauvaise frequence audio | Verifiez le mode (Aero vs STD-C) et le symbol rate |
| gr-iridium erreur de compilation | Version GNU Radio incompatible | Utilisez GNU Radio 3.8 ou 3.10 selon la branche de gr-iridium |
| `rtl_test` affiche des pertes de samples | USB insuffisant ou CPU surcharge | Fermez les applications lourdes ; verifiez `dmesg` pour les erreurs USB |

### 12.4 Optimisation des performances

```bash
# Verifier les pertes USB
dmesg | grep -i usb | tail -20

# Verifier la charge CPU pendant la capture
htop

# Tester differents gains
for gain in 0 10 20 30 40 49; do
    echo "Test gain : $gain dB"
    timeout 5 rtl_sdr -f 1541450000 -s 2048000 -g $gain -T /dev/null
done

# Verifier la temperature du dongle (si accessible)
sensors  # necessite lm-sensors
```

---

## 13. Aspects légaux et éthiques

### 13.1 Cadre légal français

- **Article L336-3 du Code des postes et des communications electroniques (CPCE)** :
  - L'interception de communications non destinees au public est interdite
  - La **divulgation** de telles communications est egalement interdite

- **Exceptions** :
  - Les messages de **securite maritime** (EGC SafetyNET, NAVAREA) sont publics par nature
  - Les **beacons et porteuses de telemetrie** ne sont pas des communications
  - La reception passive a titre personnel et prive est generalement toleree

### 13.2 Bonnes pratiques éthiques

| ✅ Faites | ❌ Ne faites pas |
|-----------|----------------|
| Recevoir et analyser les beacons | Diffuser du contenu de communications privees |
| Decoder les messages EGC publics | Tenter de casser le chiffrement des communications |
| Partager des captures de spectre anonymisees | Enregistrer et archiver des communications vocales privees |
| Contribuer aux projets open-source (gr-iridium, JAERO) | Utiliser ces outils a des fins de surveillance non autorisee |
| Signaler les problemes de securite aux operateurs | Vendre ou commercialiser des données interceptees |

### 13.3 Note internationale

Les réglementations varient selon les pays. Aux États-Unis, la reception de signaux non chiffres est autorisée par le **Communications Act of 1934** (section 705), mais la divulgation reste encadree. Verifiez toujours la legislation locale.

---

## 14. Ressources et communautés

### 14.1 Projets et logiciels

| Projet | Lien | Description |
|--------|------|-------------|
| RTL-SDR | rtl-sdr.com | Blog et ressources RTL-SDR |
| SDR++ | github.com/AlexandreRouma/SDRPlusPlus | Logiciel SDR moderne |
| Gqrx | gqrx.dk | Recepteur SDR pour Linux |
| JAERO | github.com/jonti1792/JAERO | Decodeur Inmarsat Aero/STD-C |
| gr-iridium | github.com/secdev/gr-iridium | Decodeur Iridium pour GNU Radio |
| Inspectrum | github.com/miek/inspectrum | Analyseur de fichiers IQ |
| SigDigger | github.com/BatchDrake/SigDigger | Analyseur SDR avance |
| Universal Radio Hacker | github.com/jopohl/urh | Analyse et reverse engineering radio |
| SatNOGS | satnogs.org | Reseau de stations d'ecoute satellite |

### 14.2 Documentation technique

- Inmarsat Services Overview (inmarsat.com)
- Iridium Modem Documentation (iridium.com)
- ITU Radio Regulations (itu.int)
- CelesTrak Orbital Data (celestrak.org)

### 14.3 Communautés

- **Reddit** : r/RTLSDR, r/amateurradio, r/signalidentification
- **Discord** : Serveurs SDR et radioamateur
- **Forums** : RadioReference, SDR-Radio.com

---

## 15. Glossaire

| Terme | Definition |
|-------|-----------|
| **ADC** | Analog-to-Digital Converter — Convertisseur analogique-numérique |
| **BPSK** | Binary Phase-Shift Keying — Modulation par deplacement de phase binaire |
| **Bias-tee** | Dispositif injectant une alimentation DC sur une ligne RF |
| **Burst** | Emission courte et ponctuelle (typique du TDMA) |
| **Doppler** | Decalage de frequence du au mouvement relatif emetteur/recepteur |
| **EGC** | Enhanced Group Call — Systeme de diffusion de messages Inmarsat |
| **FFT** | Fast Fourier Transform — Transformee de Fourier rapide |
| **GEO** | Geostationary Earth Orbit — Orbite geostationnaire |
| **IQ** | In-phase / Quadrature — Representation complexe d'un signal |
| **LEO** | Low Earth Orbit — Orbite basse |
| **LNA** | Low Noise Amplifier — Amplificateur faible bruit |
| **NCS** | Network Coordination Station — Station de coordination reseau |
| **QPSK** | Quadrature Phase-Shift Keying — Modulation par deplacement de phase en quadrature |
| **SAW** | Surface Acoustic Wave — Filtre a ondes acoustiques de surface |
| **SDR** | Software-Defined Radio — Radio logicielle |
| **SMA** | SubMiniature version A — Connecteur coaxial RF |
| **TDMA** | Time Division Multiple Access — Acces multiple par repartition dans le temps |
| **WFM** | Wideband FM — Modulation de frequence a large bande |

---

## Annexes

### A. Tableau comparatif Inmarsat vs Iridium

| Aspect | Inmarsat | Iridium |
|--------|----------|---------|
| Type d'orbite | GEO (fixe) | LEO (defilant) |
| Altitude | ~35 786 km | ~780 km |
| Bande | 1525–1560 MHz | 1616–1626,5 MHz |
| Pointage antenne | Precis (azimut/elevation) | A plat (zenith) |
| Signal caracteristique | Porteuses continues, beacon | Bursts courts TDMA |
| Effet Doppler | Negligeable | Important (±40 kHz) |
| Decodeur principal | JAERO | gr-iridium |
| Contenu decodable | EGC public, ACARS | Headers, paging (non chiffre) |

### B. Fréquences de référence

```
Inmarsat AOR-E (15,5° W) — depuis Europe de l'Ouest
├── Beacon NCS     : ~1541,450 MHz
├── STD-C NCS      : ~1531,000 MHz
├── STD-C TDM      : ~1531,500 MHz
├── Aero H+ Voice  : ~1545,200 MHz
├── Aero-C Data    : ~1546,000 MHz
└── Aero-I Data    : ~1551,000 MHz

Iridium
├── Bande complete : 1616,000 – 1626,500 MHz
├── Centre bande   : 1621,500 MHz
└── Canaux espaces : ~41,67 kHz
```

### C. Checklist de validation

- [ ] Dongle reconnu (`rtl_test -t` OK)
- [ ] Bias-tee active (`rtl_biast -b 1`)
- [ ] SAWbird+ alimente (chaud au toucher, modere)
- [ ] Antenne correctement orientee (Inmarsat) / a plat (Iridium)
- [ ] Gain ajuste (pas de saturation)
- [ ] Beacon ou bursts visibles sur le spectre
- [ ] Capture IQ testee et lisible (Inspectrum)
- [ ] Decodage fonctionnel (JAERO ou gr-iridium)

---

> **Document genere pour usage educatif et experimental.**
> Respectez la legislation en vigueur dans votre pays.
