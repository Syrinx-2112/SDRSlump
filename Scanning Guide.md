# 📡 GUIDE PRATIQUE DU SIGINT « PAUVRE »
## RTL‑SDR & logiciels libres — du photon au renseignement
*Version 1.0 — compilation de cours + annexes techniques*

---

## ⚖️ Préambule légal & éthique (à lire avant tout le reste)

**La règle d'or : on n'analyse que ce qu'on a le droit d'écouter.**

| Catégorie | Exemples | Statut |
|---|---|---|
| Diffusions publiques | FM, DAB, TV, NOAA/Meteo, GPS | ✅ Réception libre |
| Balises « broadcast » de sécurité | ADS‑B (1090 MHz), AIS (162 MHz), COSPAS‑SARSAT (406 MHz) | ✅ Réception libre et encouragée |
| Objets courts portés sans chiffrement | Capteurs 433/868 MHz, **vos propres** télécommandes, APRS | ✅ Surtout **vos propres émissions** (exercices de labo) |
| Communications privées | Téléphonie, pagers, voix numérique, données privées | ❌ **Interception et décodage interdits** (secret des correspondances) |

En France, l'interception de correspondances émises à titre privé est un délit (art. 226‑15 CP) ; idem dans la plupart des pays. Le GSM/LTE est en outre chiffré : l'attaque de ces systèmes sort du cadre civil **et** de ce guide. Un analyste sérieux se distingue d'un pirate précisément par cette discipline. Dans le doute : **s'abstenir**, et s'entraîner sur ses propres émetteurs (une télécommande 433 MHz et un HackRF font un labo parfait).

---

## Chapitre 1 — La chaîne SIGINT : de l'onde au renseignement

```
 Onde EM → Antenne → [Filtre] → [LNA] → SDR (ADC) → flux I/Q
        → DSP (FFT, démodulation) → visualisation → décodage
        → analyse (fiche signalétique, base de données) → RENSEIGNEMENT
```

Trois concepts à graver au fer rouge :

1. **Le SDR remplace le matériel par du logiciel** : le convertisseur numérise un large pan de spectre et tout le reste (filtres, démodulateurs) devient du code. Un même matériel décode ADS‑B, AIS et NOAA.
2. **L'enregistrement I/Q est l'équivalent SIGINT du négatif photo** : deux échantillons par instant (In‑phase, Quadrature) décrivent amplitude **et phase**. On enregistre d'abord, on analyse ensuite, autant de fois qu'on veut, hors ligne.
3. **Le renseignement n'est pas le signal** : le signal est un fait physique (fréquence, puissance, modulation) ; le renseignement est une **interprétation corrélée dans le temps** (« cet émetteur n'émet que les mardis », « cette balise apparaît avant chaque convoi »). D'où l'importance du **journal de bord** et des bases de données.

---

## Chapitre 2 — Matériel : la station de l'analyste fauché

### 2.1 Les récepteurs SDR abordables

| Matériel | Couverture | ADC | Bande passante | ~Prix | Usage type |
|---|---|---|---|---|---|
| **RTL‑SDR V3/V4** | 24–1766 MHz (V4 : HF direct) | 8 bit | 2,4 MS/s | 30 € | Le couteau suisse d'initiation |
| **Airspy Mini** | 24–1800 MHz | 12 bit | 10 MHz | 130 € | Dynamique sérieuse |
| **SDRplay RSP1A** | 1 kHz–2 GHz | 12‑14 bit | 10 MHz | 140 € | HF + VHF/UHF |
| **HackRF One** | 1–6 GHz, **émission** | 8 bit | 20 MHz | 130 € | Labo d'émission/replay |
| **PlutoSDR / LimeSDR** | TX/RX full‑duplex | 12 bit | 20+ MHz | 180 €+ | Prototypage complet |

Limites du RTL‑SDR à connaître par cœur : **8 bit → ~50 dB de dynamique** (6,02×8+1,76), erreur d'horloge de ±50 ppm non calibré, *spurs* internes. **Test rituel avant toute analyse : débrancher l'antenne. Si la raie demeure, elle vient de votre machine, pas du ciel.**

### 2.2 Antennes : le vrai maillon faible

- **Fouet fourni** : dépannage uniquement.
- **Dipole λ/2 bricolé** : longueur totale ≈ **143 / f(MHz)** mètres (ex. 1,43 m pour 100 MHz ; 2×17 cm en V pour 137 MHz NOAA).
- **Ground plane / discone** : pour le scan large bande.
- **Yagi** : gain + **direction** → première étape vers la localisation.
- Règle de Friis implicite : *le bruit de toute la chaîne est dicté par son premier étage*. Donc : **LNA au plus près de l'antenne**, câble court, et **filtre notch FM** (88–108 MHz) si un émetteur de radiodiffusion proche sature votre front‑end (cause n°1 d'intermodulation et de « signaux fantômes »).

---

## Chapitre 3 — La boîte à outils logicielle libre

| Outil | Rôle |
|---|---|
| `rtl-sdr` (rtl_test, rtl_fm, rtl_sdr, rtl_power) | Pilote + outils CLI de base |
| **Gqrx / SDR++ / SigDigger** | Réception & visualisation générales |
| **QSpectrumAnalyzer** | Scan large bande + waterfall longue durée (notre capture de cours) |
| **Inspectrum** | Analyse forensique I/Q : mesure de cadence symboles, déviation, offsets |
| **Universal Radio Hacker (URH)** | Reverse‑engineering de protocoles numériques simples |
| **GNU Radio Companion** | Chaînes DSP sur mesure |
| `multimon-ng` | FSK/AFSK/POCSAG/DTMF (sur **vos** signaux !) |
| `rtl_433` | Capteurs ISM 433/868 (météo, TPMS, prises) |
| `dump1090‑fa` / `AIS‑caster` | ADS‑B / AIS |
| **SatDump / QSSTV** | Satellites météo (APT, LRPT, GOES…) |
| `kalibrate-rtl` | Calibration ppm via les porteuses GSM |
| **Gpredict** | Prédiction de passages satellites |
| **SigMF** | Format d'enregistrement I/Q + métadonnées (indispensable en labo) |

---

## Chapitre 4 — Méthode : le rituel de l'analyste

1. **Calibrer** : `kalibrate-rtl -s GSM900` → noter le ppm → l'injecter partout (`-p`).
2. **Scanner large** : QSpectrumAnalyzer ou `rtl_power -f 100M:400M:1M -i 10 -e 3600 scan.csv` (+ `heatmap.py` pour la carte d'occupation). Constituer la **baseline** du site.
3. **Détecter & cataloguer** : chaque raie/bloc reçoit une **fiche signalétique** (modèle en annexe C).
4. **Zoomer** : réduire la plage, affiner le bin, passer le gain au crible (ni muet, ni saturé).
5. **Enregistrer** : `rtl_sdr -f 433.92M -s 2048000 -p 42 capture.sigmf-data` + métadonnées SigMF (fréquence, sample rate, gain, antenne, heure UTC, opérateur).
6. **Analyser hors ligne** : Inspectrum/URH/GNU Radio → hypothèses de modulation → décodage → **interprétation** et mise à jour de la base.

---

## Chapitre 5 — Travaux pratiques (progressifs)

### TP1 — Premier spectre, premiers dB (FM 88–108 MHz)
*Objectif* : retrouver les notions du cours d'introduction.
Observer : canal de **200 kHz**, puissance relative, et dans un démodulateur FM large, le **RDS** (sous‑porteuse 57 kHz) qui affiche le nom de la station — première expérience de « décodage ». *Concept* : règle de Carson B ≈ 2(Δf + f_mod) = 2(75+15) ≈ 180 kHz.

### TP2 — ADS‑B (1090 MHz) : le SIGINT « gentil »
`dump1090-fa` → liste d'avions + carte. *Concepts* : modulation PPM, trames 112 bits, CRC ; ELINT appliqué : mesurer votre portée de réception vs horizon théorique (annexe A).

### TP3 — AIS (161,975 / 162,025 MHz)
`AIS-catcher` → noms, caps, vitesses des navires. *Concepts* : GMSK 9600 bauds, TDMS (les trames se partagent le temps), croisement avec un site public (VesselFinder) pour **valider** vos décodages — démarche scientifique.

### TP4 — Le zoo ISM (433,92 / 868 MHz)
`rtl_433` → stations météo, TPMS, prises connectées. *Concepts* : **OOK** et **FSK** visibles à l'œil dans la waterfall (trafic en rafales, duty cycle minuscule) ; notion de trame répétée (redondance = robustesse).

### TP5 — Satellites météo (137 MHz) : le Doppler en direct
Prédire un passage avec Gpredict, recevoir NOAA en APT (SatDump). *Concept* : la **courbe en S** du Doppler dans la waterfall (±3,4 kHz à 137 MHz pour un LEO) — signature physique d'un objet en mouvement, base de la caractérisation orbitale.

### TP6 — Forensique d'une télécommande 433 MHz (VOTRE labo)
Enregistrer 2 s d'I/Q à 2 MS/s → Inspectrum : mesurer durée des pulses, cadence, codage OOK → URH : extraire les bits, identifier un codage Manchester, rejouer la trame avec HackRF (sur charge dummy ou en chambre, selon réglementation). *Concepts* : débit symboles, codage ligne, replay — le cœur du reverse‑engineering RF.

### TP7 — Cartographie GSM (observation **seulement**)
Observer la structure en peignes (porteuses espacées de **200 kHz**, GMSK ~271 ksym/s) : compter les balises BCCH = cartographier l'activité des opérateurs. **Aucun décodage** : exercice de cartographie, pas d'interception.

---

## Chapitre 6 — Monter en gamme : le SIGINT qui dure

- **Surveillance continue** : `cron` + `rtl_power` → heatmaps quotidiennes → détection d'**anomalies** (nouvel émetteur, changement d'horaire). Le renseignement naît de la **rupture de motif**.
- **Base de données** : SQLite (fréquence, première/dernière vue, puissance max, modulation supposée) = votre ordre de bataille électromagnétique local.
- **Localisation** : Yagi + mesure RSSI ; puis, quand le budget suit, **KrakenSDR** (goniométrie Doppler cohérente à 5 canaux, ~500 €).
- **GNU Radio** : quand les décodeurs du commerce ne suffisent plus, on construit le sien.

---

# ANNEXE A — Physique & technique des ondes EM

### A.1 L'onde et le spectre
Onde = champs E⊥B se propageant à c ≈ 3×10⁸ m/s ; **λ = 300 / f(MHz)** en mètres. Bandes : HF 3–30 MHz, VHF 30–300, UHF 300–3000, SHF 3–30 GHz.

### A.2 Propagation
- **HF** : réflexion ionosphérique (couches D/E/F ; la D absorbe le jour, la F « rebondit » la nuit) → communications à des milliers de km ; notion de MUF, cycles solaires.
- **VHF/UHF** : quasi ligne droite → **horizon radio** d(km) ≈ 4,12(√h₁+√h₂) ; exceptions : *ducting* troposphérique (inversions de température → VHF à 1000 km), sporadique‑E.
- **> 5 GHz** : pluie, obstacles, réflexions.

### A.3 Antennes
Gain en **dBi** (réf. isotrope) ; dipole ≈ 2,15 dBi ; **polarisation** : une antenne verticale écoute mal une émission horizontale (perte jusqu'à 20 dB) ; taille ∝ λ ; ROS < 2 souhaité.

### A.4 Puissances, bruit, bilan de liaison
- Références : dBm (1 mW), dBFS (pleine échelle ADC).
- Plancher thermique : **−174 dBm/Hz** → dans B hertz : −174 + 10log₁₀(B). Ex. 10 kHz → **−134 dBm** ; 2 MHz → **−111 dBm**.
- Pertes en espace libre : **FSPL(dB) = 32,44 + 20log₁₀ f(MHz) + 20log₁₀ d(km)**. Ex. 433 MHz à 1 km ≈ 85 dB ; à 10 km ≈ 105 dB.
- Bilan : P_rx = P_tx + G_tx + G_rx − FSPL − pertes. *Exemple* : balise 10 dBm, 0 dBi, 1 km → ≈ −75 dBm reçus : confortable ; à 100 km → −125 dBm : il faudra du gain, de la bande étroite et de l'intégration.
- Quantification : SNR ≈ 6,02·N + 1,76 dB (8 bit ≈ 50 dB) → pourquoi les « gros » SDR en 12‑14 bit changent la vie.

### A.5 FFT, résolution, compromis
Δf = F_s / N ; fenêtrage (Hamming…) = compromis fuite/résolution ; moyennage : le bruit ↓ de 10log₁₀(n) — c'est le **gain de traitement** qui révèle les signaux sous le plancher ; et le compromis temps/fréquence déjà vu en cours (bin fin = balayage lent).

### A.6 Mémo modulations
| Famille | Paramètre varié | Exemple typique | Signature spectrale |
|---|---|---|---|
| AM / SSB | amplitude | HF, aéronautique | porteuse + bandes latérales |
| FM | fréquence | FM, APRS, TETRA analogique | trace large « vivante » |
| OOK/ASK | amplitude (tout ou rien) | télécommandes 433 | rafales rectangulaires |
| FSK/GFSK/GMSK | fréquence (discrète) | AIS, BT, POCSAG | raies/trace stable, largeur fixe |
| PSK/QAM | phase (/amplitude) | liaisons données | bloc large structuré |
| OFDM | multi‑porteuses | DAB, DVB‑T, WiFi | bloc **plat** à bords nets |

---

# ANNEXE B — Cartographie du spectre (Région ITU 1, indicative)

> « La carte n'est pas le territoire » : les tableaux d'attribution (ITU RR ; en France **TNRBF de l'ANFR**) disent le *droit*, votre waterfall dit le *fait*. L'écart entre les deux est précisément votre terrain de jeu.

| Plage | Occupants typiques |
|---|---|
| 3–30 kHz / 30–300 kHz | VLF marines, signaux horaires / LF, LW, NDB |
| 190–535 kHz | Balises NDB (aéronautique) |
| 526–1606 kHz | Radiodiffusion AM (MF) |
| 2,3–25 MHz | HF : broadcast, maritime, amateur (3,5/7/14/21/28 MHz), militaire, FT8 (14,074) |
| 87,5–108 MHz | FM |
| 108–118 / 118–137 MHz | VOR‑ILS / voix aéronautique AM |
| 137–138 MHz | Satellites météo (NOAA 137,1/137,62/137,9125), amateur |
| 144–146 MHz | Amateur 2 m ; APRS 144,800 ; ISS 145,800 |
| 156–162 MHz | VHF maritime ; AIS 161,975/162,025 |
| 169–170 MHz | Paging (observation interdite du contenu !), PMSE |
| 174–240 MHz | Bande III : DAB, PMSE, usages défense |
| 380–400 MHz | TETRA (sécurité/secours) |
| 406–406,1 MHz | Balises détresse COSPAS‑SARSAT |
| 433,05–434,79 / 446 MHz | ISM 433 / PMR446 |
| 700–960 MHz | LTE 700/800 ; GSM‑900 (DL 925–960) |
| 960–1215 MHz | Radionav aéronautique ; **ADS‑B 1090** |
| 1575,42 MHz | GPS L1 / Galileo E1 |
| 1800–2700 MHz | 2G/3G/4G/5G |
| 2400–2500 MHz | ISM : WiFi, BT, fours… |

**Construire SA carte locale** : scan `rtl_power` sur 24 h → heatmap → superposer au tableau officiel → tout ce qui « dépasse » (inconnu, hors attribution, hors horaires) devient **cible de caractérisation**.

---

# ANNEXE C — Antisèche de l'analyste

**Commandes**
```bash
rtl_test -t                     # détection + gains supportés
kalibrate-rtl -s GSM900         # calibration ppm
rtl_power -f 100M:400M:1M -i 10 -e 3600 scan.csv   # occupation
rtl_sdr -f 433.92M -s 2048000 cap.bin              # enregistrement I/Q
rtl_fm -f 144.8M -M fm -s 22050 | aplay -r 22050 -f S16_LE
rtl_433 -F kv | tee capteurs.log
dump1090-fa / AIS-catcher / satdump / multimon-ng / insulinpect… (cf. ch. 3)
```

**Formules** : λ=300/f(MHz) ; dipole 143/f ; quart d'onde 71/f ; plancher = −174+10log B ; FSPL = 32,44+20log f+20log d ; Δf(Hz) = f×ppm×10⁻⁶ ; SNR(ADC) ≈ 6,02N+1,76.

**Fiche signalétique ELINT (modèle)** — exemple renseigné depuis notre capture de cours :

| Champ | Valeur d'exemple |
|---|---|
| Désignation | SIG‑001 |
| Fréquence | 201,500 MHz (±10 kHz, bin 10 kHz) |
| Largeur occupée | < 10 kHz (raie fine) |
| Puissance | −60 dB (rel.), émerge +40 dB/plancher |
| Modulation supposée | porteuse continue / balise CW |
| Duty cycle | 100 % sur 90 s d'historique |
| Stabilité | aucune dérive visible |
| Hypothèse | balise locale ou diffusion narrowband |
| Prochaine action | zoom bin 1 kHz + enregistrement 10 min |

**Mini‑glossaire** : *spur* (raie parasite interne), *baseline* (référence du site), *duty cycle*, *SNR*, *I/Q*, *SigMF*, *ppm*, *LNA*, *notch*, *waterfall*, *fiche signalétique*.

---
