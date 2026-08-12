Voici une liste détaillée des outils présents sur les quatre distributions radio spécialisées que vous avez mentionnées, avec leurs références et des instructions d'installation pour Ubuntu.

***

## 1. Gorizont (Gorizont-RTLSDR)

**Site de référence / Téléchargement :**  
- Page SourceForge : https://sourceforge.net/projects/gorizont-rtlsdr/  
- Article RTL-SDR.com : https://www.rtl-sdr.com/gorizont-rtlsdr-another-linux-os-distro-with-built-in-rtl-sdr-support-software/ [rtl-sdr](https://www.rtl-sdr.com/gorizont-rtlsdr-another-linux-os-distro-with-built-in-rtl-sdr-support-software/)

**Outils principaux inclus :**
- **GQRX** (récepteur SDR) – https://github.com/cjcliffe/gqrx  
- **SigDigger** (analyseur de signaux) – https://github.com/BalintSee/sigdigger  
- **Universal Radio Hacker** – https://github.com/jopohl/urh  
- **Welle.io** (récepteur DAB/DAB+) – https://github.com/AlbrechtL/welle.io  
- **GNU Radio** – https://www.gnuradio.org/  
- **multimon-ng** (décodeur de modes numériques) – https://github.com/EliasOenal/multimon-ng  
- **fldigi** – https://www.w1hkj.org/  
- **Baudline** (analyseur de spectre audio)  
- **Dream DRM** (via Wine) – http://www.dream-software.de/  
- **gqrx-scan**, **w-scan** (outils de scan DVB-T/ATSC)  
- **guglielmo** (récepteur FM/DAB léger) [sourceforge](https://sourceforge.net/projects/gorizont-rtlsdr/files/gorizont-rtlsdr/)

**Installation sur Ubuntu :**

Gorizont est une distribution basée sur Xubuntu 20.04 LTS. Pour installer les outils individuellement sur Ubuntu :

```bash
# Mise à jour
sudo apt update && sudo apt upgrade -y

# Installation des dépendances de base
sudo apt install -y build-essential cmake git libboost-all-dev \
    libfftw3-dev libgsl-dev libqt5-dev libqt5opengl5-dev \
    libpulse-dev libsoapysdr-dev librtlsdr-dev

# GQRX
sudo apt install gqrx-sdr

# GNU Radio
sudo apt install gnuradio gnuradio-dev

# SigDigger
sudo apt install sigdigger

# Universal Radio Hacker
sudo apt install universal-radio-hacker

# Welle.io (DAB)
sudo apt install welle-io

# Fldigi
sudo apt install fldigi

# Multimon-ng
sudo apt install multimon-ng

# RTL-SDR drivers
sudo apt install rtl-sdr librtlsdr-dev
```

***

## 2. Skywave Linux

**Site de référence :**  
- Site officiel : https://skywavelinux.com/ [skywavelinux](https://skywavelinux.com/)
- GitHub (scripts de build) : https://github.com/brightflash64/Skywave-Linux [github](https://github.com/brightflash64/Skywave-Linux)
- GitHub (scripts SDR) : https://github.com/AB9IL/Skywave-Linux-scripts [github](https://github.com/AB9IL/Skywave-Linux-scripts/releases)

**Outils principaux inclus :**
- **Gqrx**, **CubicSDR**, **SDR++** (récepteurs SDR)  
- **GNU Radio**  
- **Dump1090**, **DumpHFDL**, **ACARSdec**, **VDLM2dec** (trafic aérien)  
- **Fldigi**, **JS8Call**, **WSJT-X** (modes numériques)  
- **SatDump**, **GPredict** (satellites)  
- **SoapySDR** et drivers (Airspy, BladeRF, HackRF, RTL-SDR, USRP, LimeSDR, PlutoSDR, etc.)  
- **Multimon-ng**, **RTLSDR-Airband**  
- **OBS-Studio**, **Audacity**, **SMPlayer** (multimédia)  
- **Neovim**, **Python**, **Go**, **JupyterLab** (développement)  
- **Tor**, **I2P**, **WireGuard**, **OpenVPN** (réseau et confidentialité)  
- **Reticulum**, **MeshChat** (réseau maillé LoRa) [skywavelinux](https://skywavelinux.com/)

**Installation sur Ubuntu :**

Skywave Linux est basé sur Debian Sid. Pour une installation manuelle sur Ubuntu :

```bash
# Mise à jour
sudo apt update && sudo apt upgrade -y

# RTL-SDR et drivers
sudo apt install rtl-sdr librtlsdr-dev libsoapysdr-dev

# Gqrx
sudo apt install gqrx-sdr

# GNU Radio
sudo apt install gnuradio gnuradio-dev

# CubicSDR (téléchargement manuel)
wget https://github.com/cjcliffe/CubicSDR/releases/download/0.2.7/CubicSDR-0.2.7-x86_64.AppImage
chmod +x CubicSDR-0.2.7-x86_64.AppImage

# SDR++
sudo apt install sdrpp

# Dump1090 (trafic aérien)
sudo apt install dump1090-fa

# Fldigi, WSJT-X, JS8Call
sudo apt install fldigi wsjtx js8call

# GPredict (satellites)
sudo apt install gpredict

# SatDump (téléchargement manuel ou via PPA si disponible)
# Voir https://github.com/SatDump/SatDump

# Multimon-ng
sudo apt install multimon-ng

# SoapySDR et modules
sudo apt install soapysdr-module-rtlsdr soapysdr-module-hackrf soapysdr-module-bladerf
```

***

## 3. SigIntOS

**Site de référence :**  
- Site officiel : https://www.sigintos.com/  
- Liste des logiciels : https://www.sigintos.com/wiki/about/software-list/ [sigintos](https://www.sigintos.com/wiki/about/software-list/)
- GitHub (démos) : https://github.com/abmaeld/sigintos-with-rtl-sdr-and-hackrf-demos [github](https://github.com/abmaeld/sigintos-with-rtl-sdr-and-hackrf-demos)

**Outils principaux inclus :**
- **GSM/4G/5G** : YateBTS, Gr-gsm, srsRAN 4G, Open5GS  
- **Traitement du signal** : GNU Radio, Gqrx, SDRAngel, SigDigger  
- **Trafic aérien** : Dump1090, ADSB Web  
- **Trafic maritime** : OpenCPN  
- **Satellites** : GPredict  
- **Drivers SDR** : BladeRF, HackRF, RTL-SDR, USRP (UHD), Osmo-sdr  
- **Serveurs** : Apache, MySQL, MongoDB [sigintos](https://www.sigintos.com/wiki/about/software-list/)

**Installation sur Ubuntu :**

SigIntOS est basé sur Ubuntu. Pour installer les outils individuellement :

```bash
# Mise à jour
sudo apt update && sudo apt upgrade -y

# GNU Radio
sudo apt install gnuradio gnuradio-dev

# Gqrx
sudo apt install gqrx-sdr

# SDRAngel
sudo apt install sdrangel

# SigDigger
sudo apt install sigdigger

# Dump1090
sudo apt install dump1090-faVoici une liste détaillée des outils présents sur les quatre distributions radio spécialisées que vous avez mentionnées, avec leurs références et des instructions d'installation pour Ubuntu.

---

## 1. Gorizont (Gorizont-RTLSDR)

**Site de référence / Téléchargement :**  
- Page SourceForge : https://sourceforge.net/projects/gorizont-rtlsdr/  
- Article RTL-SDR.com : https://www.rtl-sdr.com/gorizont-rtlsdr-another-linux-os-distro-with-built-in-rtl-sdr-support-software/  [github](https://github.com/brightflash64/Skywave-Linux/blob/master/getnewsoftware.sh)

**Outils principaux inclus :**
- **GQRX** (récepteur SDR) – https://github.com/cjcliffe/gqrx  
- **SigDigger** (analyseur de signaux) – https://github.com/BalintSee/sigdigger  
- **Universal Radio Hacker** – https://github.com/jopohl/urh  
- **Welle.io** (récepteur DAB/DAB+) – https://github.com/AlbrechtL/welle.io  
- **GNU Radio** – https://www.gnuradio.org/  
- **multimon-ng** (décodeur de modes numériques) – https://github.com/EliasOenal/multimon-ng  
- **fldigi** – https://www.w1hkj.org/  
- **Baudline** (analyseur de spectre audio)  
- **Dream DRM** (via Wine) – http://www.dream-software.de/  
- **gqrx-scan**, **w-scan** (outils de scan DVB-T/ATSC)  
- **guglielmo** (récepteur FM/DAB léger)  [emmanuelbama](https://emmanuelbama.net/2019/10/14/signtos-distribution-gnu-linux-pour-pentest-radio-frequence/)

**Installation sur Ubuntu :**

Gorizont est une distribution basée sur Xubuntu 20.04 LTS. Pour installer les outils individuellement sur Ubuntu :

```bash
# Mise à jour
sudo apt update && sudo apt upgrade -y

# Installation des dépendances de base
sudo apt install -y build-essential cmake git libboost-all-dev \
    libfftw3-dev libgsl-dev libqt5-dev libqt5opengl5-dev \
    libpulse-dev libsoapysdr-dev librtlsdr-dev

# GQRX
sudo apt install gqrx-sdr

# GNU Radio
sudo apt install gnuradio gnuradio-dev

# SigDigger
sudo apt install sigdigger

# Universal Radio Hacker
sudo apt install universal-radio-hacker

# Welle.io (DAB)
sudo apt install welle-io

# Fldigi
sudo apt install fldigi

# Multimon-ng
sudo apt install multimon-ng

# RTL-SDR drivers
sudo apt install rtl-sdr librtlsdr-dev
```

---

## 2. Skywave Linux

**Site de référence :**  
- Site officiel : https://skywavelinux.com/  [archive](https://archive.org/details/andy_v25)  
- GitHub (scripts de build) : https://github.com/brightflash64/Skywave-Linux  [osdn](https://osdn.net/projects/sfnet_kb1oiq-andysham/releases/)  
- GitHub (scripts SDR) : https://github.com/AB9IL/Skywave-Linux-scripts  [groups](https://groups.io/g/linuxham/topic/released_andy_s_ham_radio/91683083)

**Outils principaux inclus :**
- **Gqrx**, **CubicSDR**, **SDR++** (récepteurs SDR)  
- **GNU Radio**  
- **Dump1090**, **DumpHFDL**, **ACARSdec**, **VDLM2dec** (trafic aérien)  
- **Fldigi**, **JS8Call**, **WSJT-X** (modes numériques)  
- **SatDump**, **GPredict** (satellites)  
- **SoapySDR** et drivers (Airspy, BladeRF, HackRF, RTL-SDR, USRP, LimeSDR, PlutoSDR, etc.)  
- **Multimon-ng**, **RTLSDR-Airband**  
- **OBS-Studio**, **Audacity**, **SMPlayer** (multimédia)  
- **Neovim**, **Python**, **Go**, **JupyterLab** (développement)  
- **Tor**, **I2P**, **WireGuard**, **OpenVPN** (réseau et confidentialité)  
- **Reticulum**, **MeshChat** (réseau maillé LoRa)  [rtl-sdr](https://www.rtl-sdr.com/gorizont-rtlsdr-linux-distro-updated-to-v2-0-3/)

**Installation sur Ubuntu :**

Skywave Linux est basé sur Debian Sid. Pour une installation manuelle sur Ubuntu :

```bash
# Mise à jour
sudo apt update && sudo apt upgrade -y

# RTL-SDR et drivers
sudo apt install rtl-sdr librtlsdr-dev libsoapysdr-dev

# Gqrx
sudo apt install gqrx-sdr

# GNU Radio
sudo apt install gnuradio gnuradio-dev

# CubicSDR (téléchargement manuel)
wget https://github.com/cjcliffe/CubicSDR/releases/download/0.2.7/CubicSDR-0.2.7-x86_64.AppImage
chmod +x CubicSDR-0.2.7-x86_64.AppImage

# SDR++
sudo apt install sdrpp

# Dump1090 (trafic aérien)
sudo apt install dump1090-fa

# Fldigi, WSJT-X, JS8Call
sudo apt install fldigi wsjtx js8call

# GPredict (satellites)
sudo apt install gpredict

# SatDump (téléchargement manuel ou via PPA si disponible)
# Voir https://github.com/SatDump/SatDump

# Multimon-ng
sudo apt install multimon-ng

# SoapySDR et modules
sudo apt install soapysdr-module-rtlsdr soapysdr-module-hackrf soapysdr-module-bladerf
```

---

## 3. SigIntOS

**Site de référence :**  
- Site officiel : https://www.sigintos.com/  
- Liste des logiciels : https://www.sigintos.com/wiki/about/software-list/  [github](https://github.com/AB9IL/Skywave-Linux-scripts/releases)  
- GitHub (démos) : https://github.com/abmaeld/sigintos-with-rtl-sdr-and-hackrf-demos  [groups.google](https://groups.google.com/g/ct-comunicacoes-e-tecnologias/c/MpWfI3ZqAls)

**Outils principaux inclus :**
- **GSM/4G/5G** : YateBTS, Gr-gsm, srsRAN 4G, Open5GS  
- **Traitement du signal** : GNU Radio, Gqrx, SDRAngel, SigDigger  
- **Trafic aérien** : Dump1090, ADSB Web  
- **Trafic maritime** : OpenCPN  
- **Satellites** : GPredict  
- **Drivers SDR** : BladeRF, HackRF, RTL-SDR, USRP (UHD), Osmo-sdr  
- **Serveurs** : Apache, MySQL, MongoDB  [github](https://github.com/AB9IL/Skywave-Linux-scripts/releases)

**Installation sur Ubuntu :**

SigIntOS est basé sur Ubuntu. Pour installer les outils individuellement :

```bash
# Mise à jour
sudo apt update && sudo apt upgrade -y

# GNU Radio
sudo apt install gnuradio gnuradio-dev

# Gqrx
sudo apt install gqrx-sdr

# SDRAngel
sudo apt install sdrangel

# SigDigger
sudo apt install sigdigger

# Dump1090
sudo apt install dump1090-fa

# GPredict
sudo apt install gpredict

# OpenCPN
sudo apt install opencpn

# RTL-SDR, HackRF, BladeRF drivers
sudo apt install rtl-sdr librtlsdr-dev hackrf libhackrf-dev bladerf libbladerf-dev

# UHD (USRP)
sudo apt install libuhd-dev uhd-host

# Osmo-sdr
sudo apt install libosmosdr-dev

# srsRAN 4G (installation manuelle)
git clone https://github.com/srsran/srsRAN_4G.git
cd srsRAN_4G && mkdir build && cd build
cmake ../
make && sudo make install

# YateBTS (installation manuelle)
git clone https://github.com/YateBTS/yatebts.git
cd yatebts && ./configure && make && sudo make install
```

---

## 4. Andy's HAM Linux (AHRL)

**Site de référence :**  
- SourceForge : https://sourceforge.net/projects/kb1oiq-andysham/  [medium](https://medium.com/@tomac/sigintos-a-wireless-pentest-distro-review-a7ea93ee8f8b)  
- Documentation : https://sourceforge.net/projects/kb1oiq-andysham/files/v27/GETTING_STARTED

**Outils principaux inclus :**
- **Modes numériques** : Fldigi, NBEMS, FreeDV, WSJT-X, JS8Call, M17  
- **Logging** : XLog, cqrlog, fllog  
- **Contrôle de transceiver** : flrig, grig, CHIRP  
- **Satellites** : GPredict, Xastir  
- **Antennes** : xnec2c, fl_moxgen, aa-analyzer, VOACAP  
- **CW** : xcwcp, qrq, Micro-Fox  
- **SDR** : Gqrx, SDRangel, GNU Radio Companion, Quisk, Direwolf  
- **Électronique** : KiCad, gEDA, EasySpice  
- **Packet** : linpac, linamc  [medium](https://medium.com/@abmaeld/sigintos-with-sdr-and-hackrf-demos-f46154b8c770)

**Installation sur Ubuntu :**

AHRL est un script d'installation qui peut être exécuté sur Ubuntu. Voici comment installer les outils individuellement :

```bash
# Mise à jour
sudo apt update && sudo apt upgrade -y

# Fldigi et NBEMS
sudo apt install fldigi flrig fllog

# WSJT-X, JS8Call
sudo apt install wsjtx js8call

# FreeDV
sudo apt install freedv

# Gqrx
sudo apt install gqrx-sdr

# SDRangel
sudo apt install sdrangel

# GNU Radio
sudo apt install gnuradio gnuradio-dev

# GPredict
sudo apt install gpredict

# Xastir
sudo apt install xastir

# Direwolf
sudo apt install direwolf

# KiCad
sudo apt install kicad

# CHIRP
sudo apt install chirp

# XCWCP (CW)
sudo apt install xcwcp

# RTL-SDR drivers
sudo apt install rtl-sdr librtlsdr-dev
```

---

## Tableau récapitulatif

| Distribution | Base | Outils phares | Site de référence |
|--------------|------|---------------|-------------------|
| **Gorizont** | Xubuntu 20.04 | GQRX, SigDigger, URH, Welle.io, GNU Radio | [SourceForge](https://sourceforge.net/projects/gorizont-rtlsdr/)  [sourceforge](https://sourceforge.net/projects/kb1oiq-andysham/files/v27/) |
| **Skywave** | Debian Sid | Gqrx, CubicSDR, Dump1090, Fldigi, SatDump, GPredict | [skywavelinux.com](https://skywavelinux.com/)  [archive](https://archive.org/details/andy_v25) |
| **SigIntOS** | Ubuntu | YateBTS, srsRAN, Open5GS, Gqrx, SDRAngel, Dump1090 | [sigintos.com](https://www.sigintos.com/)  [github](https://github.com/AB9IL/Skywave-Linux-scripts/releases) |
| **Andy's HAM** | Xubuntu/Ubuntu | Fldigi, WSJT-X, Gqrx, GPredict, KiCad, CHIRP | [SourceForge](https://sourceforge.net/projects/kb1oiq-andysham/)  [ea1uro](https://ea1uro.com/radio/sigint/) |

---
