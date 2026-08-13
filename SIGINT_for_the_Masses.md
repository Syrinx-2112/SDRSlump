# SIGINT for the Masses
## Guide ultime de la réception radio amateur et du RF-OSINT passif (RTL-SDR & au-delà)

> Compilation et mise en cohérence de trois échanges (Qwen, Kimi, Perplexity), complétée par des rappels scientifiques (propagation, bruit, Doppler, polarisation) et des sections pratiques (matériel, antennes, logiciels, distributions Linux, méthodologie).

---

## 0. Avertissement légal et éthique

Ce guide couvre exclusivement de la **réception passive** de signaux radio. Il ne traite ni de décryptage, ni d'émission, ni de brouillage, ni d'interception de communications privées ou protégées.

Ce qui est dans le périmètre :
- Signaux **publics ou ouverts** : météo satellite (NOAA APT, Meteor LRPT), balises radioamateur, télémétrie CubeSat publique, ADS-B, trafic aéronautique non chiffré (ACARS), diffusion TV/radio, bandes radioamateur.
- Analyse spectrale passive : détection de porteuses, mesure de fréquence/bande passante, classification de modulation, corrélation Doppler avec des éphémérides publiques.

Ce qui est explicitement **hors périmètre** et que ce guide ne couvre pas :
- Communications privées, chiffrées, militaires ou gouvernementales non destinées au public ;
- Décodage de contenus protégés ou de télémétries non publiques ;
- Émission (uplink) sans licence — cela exige une licence radioamateur, un contrôle strict de la puissance, de la bande et de la direction, sous peine de brouillage et de sanctions lourdes ;
- Interception de balises de détresse à des fins d'analyse : si vous captez une détresse réelle, il faut **alerter les secours**, pas l'archiver comme un « signal intéressant ».

La réglementation varie selon les pays. En France/Europe, l'écoute de communications non destinées au public, leur décryptage ou leur diffusion sont interdits même en réception purement passive. Vérifiez toujours auprès de votre autorité nationale (ANFR en France, Ofcom au Royaume-Uni, FCC aux États-Unis, etc.) avant toute activité, en particulier pour les fréquences aéronautiques, maritimes et GSM/4G/5G.

---

## 1. Taxonomie : que recouvre le « SIGINT » pour un amateur ?

Le renseignement d'origine électromagnétique (**SIGINT**, *Signals Intelligence*) se décompose classiquement en plusieurs familles :

| Sigle | Signification | Contenu |
|---|---|---|
| **COMINT** | *Communications Intelligence* | Interception de communications (voix, texte) |
| **ELINT** | *Electronic Intelligence* | Émissions radar et non-communications |
| **FISINT** | *Foreign Instrumentation Signals Intelligence* | Signaux de télémesure/instrumentation |
| **RF-OSINT** | *Radio Frequency Open Source Intelligence* | Observation du spectre, identification de porteuses, classification de modulation, corrélation avec des sources ouvertes (TLE, éphémérides, bases publiques) |

Pour un amateur équipé d'un RTL-SDR, la partie réaliste, légale et pédagogique se limite presque entièrement au **RF-OSINT** : cartographier ce qui est visible dans le spectre, comprendre sa structure, et le documenter avec rigueur — sans jamais chercher à extraire du contenu privé.

C'est dans cet esprit (celui des pionniers de l'écoute spatiale amateur, ou des chercheurs qui ont documenté publiquement les protocoles satellites civils) que ce guide est construit : **bidouille sérieuse, mesure, documentation, esprit critique.**

---

## 2. Rappels scientifiques fondamentaux

Comprendre ces notions évite de perdre du temps sur du matériel mal dimensionné.

### 2.1 Échantillonnage et bande passante utile (Nyquist-Shannon)

Pour capturer sans ambiguïté un signal occupant une largeur de bande *B*, il faut un taux d'échantillonnage complexe (IQ) au moins égal à *B*, et en pratique **2 à 3 fois** la largeur réelle du signal pour laisser de la marge au filtrage. C'est une conséquence directe du théorème de Nyquist-Shannon appliqué à un signal en bande de base complexe (IQ) : la bande instantanée utilisable est égale au taux d'échantillonnage, centrée sur la fréquence choisie.

Le RTL-SDR échantillonne typiquement autour de **2,048 Ms/s** en 8 bits, ce qui plafonne sa bande instantanée utile autour de 2 MHz — largement suffisant pour des signaux étroits (balises CW, AFSK, LRPT ~700 kHz) mais **insuffisant** pour du DVB-S/S2 à plusieurs Msym/s.

| Signal | Largeur/débit typique | Faisabilité RTL-SDR |
|---|---|---|
| NOAA APT | FM vidéo ~34 kHz | Très faisable |
| Meteor LRPT | ~600–800 kHz | Faisable (1,024–2,048 Ms/s) |
| AFSK 1200 baud | quelques kHz | Très faisable |
| FSK/BPSK 9k6 | dizaines de kHz | Faisable |
| GMSK 38,4k–100k | centaines de kHz max | Faisable |
| DVB-S ~2 Msym/s | trop large | Non recommandé |
| DVB-S2 haut débit | très large | Impossible avec RTL-SDR seul |
| GNSS L1 | très faible, étalé (spread spectrum) | Très difficile, projet de recherche |

### 2.2 Bruit thermique, SNR et figure de bruit (formule de Friis)

La puissance de bruit thermique dans une bande *B* (Hz), à température *T* (Kelvin), vaut :

```
N = k · T · B        (k = constante de Boltzmann ≈ 1,38 × 10⁻²³ J/K)
```

Convertie en dBm à température ambiante (T ≈ 290 K) :

```
N (dBm) ≈ -174 + 10·log₁₀(B)
```

Plus la bande passante utile est large, plus le plancher de bruit remonte — c'est pourquoi filtrer étroitement autour du signal utile (au lieu de tout démoduler large bande) améliore directement le rapport signal/bruit (SNR).

Un récepteur ajoute son propre bruit, quantifié par la **figure de bruit (NF)**. Quand plusieurs étages sont mis en cascade (antenne → câble → LNA → SDR), la formule de Friis donne la figure de bruit globale :

```
F_total = F1 + (F2 - 1)/G1 + (F3 - 1)/(G1·G2) + ...
```

où *F1, F2...* sont les facteurs de bruit linéaires de chaque étage et *G1, G2...* leurs gains linéaires. **Conséquence pratique majeure : le premier étage (le plus proche de l'antenne) domine la figure de bruit totale.** C'est pourquoi on place le LNA au pied de l'antenne plutôt qu'au bout d'un câble, et pourquoi un LNA à faible NF placé en tête « rachète » les pertes des étages suivants.

| Bande passante | Bruit thermique (NF=0) | Avec NF = 2 dB |
|---|---|---|
| 15 kHz | -132,2 dBm | -130,2 dBm |
| 250 kHz | -118 dBm | -116 dBm |
| 1 MHz | -114 dBm | -112 dBm |

### 2.3 Affaiblissement de propagation en espace libre (FSPL)

```
FSPL (dB) = 20·log₁₀(d) + 20·log₁₀(f) + 32,45     (d en km, f en MHz)
```

Cet affaiblissement croît avec le carré de la distance **et** de la fréquence : un lien à 1,6 GHz perd nettement plus qu'un lien à 137 MHz sur la même distance.

| Fréquence | FSPL à 1500 km (orbite LEO typique) |
|---|---|
| 137 MHz | ~138,6 dB |
| 435 MHz | ~147,2 dB |
| 1,6 GHz | ~160,0 dB |
| 2,4 GHz | ~163,6 dB |

### 2.4 Exemple de budget de liaison — NOAA APT à 137 MHz

Hypothèses d'ordre de grandeur : distance 1500 km, EIRP satellite ≈ 39 dBm, antenne QFH ≈ +3 dBi, pertes câble ≈ -1 dB, FSPL ≈ 138,6 dB.

```
Puissance reçue ≈ EIRP + gain antenne - pertes - FSPL
                ≈ 39 + 3 - 1 - 138,6 ≈ -97,6 dBm
```

Avec un bruit thermique sur 15 kHz et NF=2 dB à environ -130,2 dBm, le SNR théorique dépasse **30 dB** : largement décodable avec du matériel correct. Ce même calcul appliqué en bande L (1,6 GHz) montre que l'affaiblissement supplémentaire de FSPL (+20 dB environ) rend le gain d'antenne (parabole, LNA de qualité) beaucoup plus critique.

### 2.5 Effet Doppler

Un satellite défilant (orbite basse, LEO) s'approche puis s'éloigne de l'observateur pendant un passage, ce qui décale la fréquence perçue :

```
Δf = f · (v_r / c)
```

où *v_r* est la composante radiale de la vitesse du satellite par rapport au récepteur, et *c* la vitesse de la lumière. Pour une vitesse orbitale LEO typique de ~7,5 km/s :

| Fréquence porteuse | Décalage Doppler max approximatif |
|---|---|
| 137 MHz | ±3,4 kHz |
| 145 MHz | ±3,6 kHz |
| 435 MHz | ±10,9 kHz |
| 1,6 GHz | ±40 kHz |
| 2,4 GHz | ±60 kHz |
| 10 GHz | ±250 kHz |

Un signal dont la fréquence dérive en suivant une courbe en « S » compatible avec un passage prévu (calculé à partir des éléments orbitaux TLE) peut raisonnablement être associé au satellite catalogué correspondant. Un signal **plat** dans le temps est plutôt un signal géostationnaire (GEO), terrestre, un oscillateur local du récepteur, ou une interférence.

Pour les signaux numériques modulés, une erreur résiduelle de fréquence non corrigée peut casser la démodulation : viser une correction Doppler réduisant l'erreur sous **5 à 10 % du débit symbole**. À noter : un satellite **géostationnaire** (Inmarsat, GOES, QO-100...) ne présente quasiment aucun Doppler dynamique côté récepteur fixe, ce qui simplifie énormément la chaîne de réception par rapport à un LEO.

### 2.6 Polarisation

Beaucoup de satellites émettent en polarisation **circulaire** (RHCP — *Right Hand Circular Polarization* — ou LHCP — *Left Hand Circular Polarization*). Une antenne à polarisation linéaire (dipôle, Yagi simple) reçoit tout de même le signal, mais avec une perte théorique pouvant atteindre **3 dB**, plus des évanouissements liés à la rotation relative de polarisation (satellite en rotation, géométrie changeante). Pour un signal LEO ou géostationnaire, une antenne à polarisation circulaire **adaptée au sens d'émission** (QFH, hélice, patch circulaire) est donc préférable.

### 2.7 Gain d'une antenne parabolique

```
G (dBi) ≈ 10·log₁₀( η · (π·D/λ)² )
```

avec *D* le diamètre, *λ* la longueur d'onde, et *η* l'efficacité de l'illumination (typiquement 0,5 à 0,65 pour une parabole grand public).

| Fréquence | Diamètre | Gain approximatif |
|---|---|---|
| 1,6 GHz | 60 cm | ~17 dBi |
| 2,4 GHz | 60 cm | ~21 dBi |
| 10 GHz | 60 cm | ~33 dBi |
| 10 GHz | 90 cm | ~37 dBi |

Plus la fréquence augmente, plus la parabole devient directive à diamètre égal (le lobe se resserre), donc plus le pointage doit être précis.

---

## 3. Matériel : le RTL-SDR et sa chaîne

### 3.1 Caractéristiques typiques d'un dongle RTL-SDR

- Tuner : R820T2 ou équivalent.
- Plage de fréquence : environ 24 MHz à 1766 MHz (variable selon le hardware).
- Échantillonnage : jusqu'à 2,4 Ms/s, stable généralement autour de 2,048 Ms/s.
- Résolution : 8 bits (dynamique limitée comparée aux SDR professionnels).
- USB 2.0.
- Pas de cohérence de phase native entre plusieurs dongles.
- Bias tee sur certains modèles (typiquement 4,5 ou 5 V).
- TCXO interne : ~0,5 ppm sur les bons modèles, moins bon sur l'entrée de gamme.

**Pourquoi la stabilité fréquentielle compte** : à 137 MHz, 1 ppm de dérive représente 137 Hz ; à 1,6 GHz, cela représente 1,6 kHz. Sur un signal numérique étroit, cette dérive peut suffire à dégrader ou casser le décodage — d'où l'intérêt d'un TCXO de qualité, voire d'une référence externe (GPSDO) pour les usages avancés.

### 3.2 Ce que le RTL-SDR peut et ne peut pas faire

**Peut faire correctement** : signaux étroits (CW, FM étroite, AFSK, FSK, BPSK bas débit), imagerie NOAA APT, Meteor LRPT, balises VHF/UHF, télémétrie CubeSat modérée, signaux downconvertis depuis Ku/C/QO-100, observation spectrale passive.

**Ne peut pas bien faire** : DVB-S/S2 haut débit (trop étroit en bande instantanée), signaux très larges (SAR, liaisons haut débit), réception très faible sans antenne adaptée (GNSS direct), mesures cohérentes multi-antennes (TDOA, interférométrie) sans matériel dédié, forte dynamique en présence d'émetteurs puissants proches (FM broadcast, TV, radars).

### 3.3 Plusieurs dongles en parallèle

Utile pour : observer une bande large pendant qu'un autre dongle suit une balise précise, séparer VHF/UHF, ou obtenir de la diversité d'antenne. Limites à connaître :
- les RTL-SDR **ne sont pas cohérents en phase** par défaut (pour du TDOA/AOA/interférométrie il faut du matériel dédié type KrakenSDR, PlutoSDR, LimeSDR, USRP) ;
- plusieurs dongles sur le même hub USB 2.0 peuvent saturer la bande passante USB si tous enregistrent en IQ simultanément (un flux à 2,048 Ms/s en IQ 8 bits représente environ 4 Mo/s, donc ~14,4 Go/heure par dongle en enregistrement continu).

### 3.4 Filtres

Le RTL-SDR est **facilement saturé** par des signaux forts hors bande (l'ADC 8 bits a une dynamique limitée). Un bon filtre passe-bande en tête de chaîne améliore souvent davantage les résultats qu'un LNA mal placé. Filtres utiles selon l'usage : passe-bande 137 MHz (NOAA/Meteor), passe-bande 145 MHz (ISS/amateur VHF), passe-bande 435 MHz (UHF amateur/CubeSat), filtre L-band (1,5–1,7 GHz), coupe-bande FM 88–108 MHz, filtre LTE/4G/5G selon l'environnement.

### 3.5 LNA (amplificateur faible bruit)

Un LNA mal utilisé dégrade les performances au lieu de les améliorer (saturation en présence de signaux forts). Critères de choix : figure de bruit NF < 1 dB si possible, gain modéré (15–30 dB), bon point de compression P1dB, bon IP3 (linéarité), bande passante adaptée à l'usage. Comme vu au §2.2 (formule de Friis), le placement au plus près de l'antenne est ce qui compte le plus — un LNA en bout de câble long apporte beaucoup moins de bénéfice.

### 3.6 Câbles et connectique

En VHF/UHF, un câble correct suffit. En bande L et au-delà, les pertes deviennent vite importantes : éviter les longs RG-58, préférer LMR-240/LMR-400/RG-213 à faible perte, connecter le LNA au plus près de l'antenne, utiliser des connecteurs SMA/N de qualité. À 1,6 GHz, quelques mètres de mauvais câble peuvent coûter plusieurs dB — soit littéralement la différence entre un décodage réussi et un échec.

### 3.7 Bias tee

Permet d'alimenter un LNA distant via le câble coaxial, sans câble d'alimentation séparé. À vérifier : tension fournie par le RTL-SDR (souvent 4,5–5 V) vs tension acceptée par le LNA, consommation, polarité, présence d'un filtre pour ne pas renvoyer l'alimentation vers le tuner.

---

## 4. Antennes

### 4.1 QFH (Quadrifilar Helix Antenna)

Grand classique pour NOAA APT et Meteor LRPT à 137 MHz. Avantages : polarisation circulaire native, diagramme large vers le ciel (pas besoin de rotor pour un passage LEO), bon comportement en réception LEO. Inconvénients : encombrement à 137 MHz, construction plus délicate qu'un dipôle simple (les dimensions dépendent de la vitesse de propagation du câble/fil utilisé — utiliser un calculateur dédié, par exemple les outils en ligne spécialisés QFH).

### 4.2 Turnstile

Deux dipôles croisés alimentés en quadrature (déphasage 90°, souvent via des lignes quart d'onde). Simple, efficace en VHF/UHF, bonne pour les satellites LEO.

### 4.3 Yagi

Pour UHF CubeSat ou cibles spécifiques nécessitant du gain : plus de directivité (donc de gain), nécessite un rotor azimut/élévation pour suivre un passage LEO, polarisation généralement linéaire (perte possible face à un signal circulaire — on peut croiser deux Yagis pour circulariser). Exemple : une Yagi 435 MHz à 10–15 éléments donne typiquement 10–14 dBi.

### 4.4 Hélice axiale (mode axial)

Très efficace pour la bande L (1,5–2,4 GHz), avec un gain qui augmente avec le nombre de spires et le rapport diamètre/longueur d'onde.

### 4.5 Antenne patch

Compacte pour la bande L, polarisation circulaire possible via coins tronqués. Bande passante parfois étroite, construction PCB précise nécessaire (préférer un substrat faible perte au FR4 standard en gigahertz).

### 4.6 Paraboles

Voir formule de gain au §2.7. Plus la fréquence est haute, plus le pointage doit être précis. Pour QO-100/Es'hail-2 (voir §6.6), l'ordre de grandeur est un gain de plusieurs dizaines de dBi avec une parabole de 60–90 cm équipée du bon feed.

---

## 5. Downconversion Ku/C/QO-100 et LNB satellite

Le RTL-SDR ne monte pas assez haut en fréquence pour recevoir directement la plupart des liaisons Ku/Ka/C : il faut passer par un **downconverter**, le plus simple et répandu étant le LNB (*Low Noise Block*) de télévision satellite.

Un LNB universel reçoit typiquement la bande basse Ku (~10,7–11,7 GHz) et la bande haute Ku (~11,7–12,75 GHz), et les convertit vers une fréquence intermédiaire (IF) exploitable par un récepteur classique (950–2150 MHz). La sélection se fait par la tension d'alimentation et un ton de commande :
- **13 V** : polarisation verticale/RHCP selon le système ;
- **18 V** : polarisation horizontale/LHCP selon le système ;
- **ton 22 kHz** : sélection de la bande haute sur un LNB universel.

Important : le RTL-SDR ne peut **pas** alimenter directement un LNB — il faut une alimentation dédiée, un récepteur satellite servant de source IF, un injecteur DC, ou un montage spécifique. Le RTL-SDR peut ensuite recevoir l'IF (950–2150 MHz) si le tuner le permet, mais la bande passante instantanée reste limitée : le DVB-S/S2 large est impossible, seules des porteuses étroites ou signaux publics compatibles sont accessibles. Il faut aussi connaître la fréquence de l'oscillateur local du LNB pour remonter de l'IF observée vers la fréquence satellite réelle.

**QO-100 (Es'hail-2)** est un satellite géostationnaire amateur très populaire, avec des transpondeurs radioamateur accessibles en réception avec une parabole et un LNB adapté (souvent modifié/référencé sur 10 ou 25 MHz pour la stabilité). C'est un excellent terrain de jeu légal pour l'écoute de balises, l'expérimentation LNB, la mesure de stabilité fréquentielle et les mesures Doppler très faibles (satellite GEO). Rappel : l'**uplink** exige une licence radioamateur et des précautions absolues contre le brouillage — ce guide ne couvre que la réception.

---

## 6. Panorama des bandes, cibles et setups par mission

| Bande | Fréquences | Satellites / signaux typiques | Matériel clé |
|---|---|---|---|
| VHF/UHF LEO | 137–170 MHz, 400–470 MHz | NOAA 15/18/19 (APT), Meteor-M (LRPT), Orbcomm, ISS | RTL-SDR direct + QFH/dipôle |
| Bande L | 1,5–1,7 GHz | Inmarsat, Iridium, Thuraya, GPS/GNSS, GOES HRIT (~1,694 GHz) | RTL-SDR + LNA + filtre + antenne patch/hélice |
| Bande S | 2,2–2,4 GHz | Télémétrie de certains satellites, quelques CubeSats | Downconverter ou RTL-SDR v3/v4 en direct sampling + LNA |
| Bande C | 3,4–4,2 GHz | TV satellite FTA, télémesure de satellites GEO | Downconverter obligatoire + parabole TVSat |
| Bande Ku | 10,7–12,75 GHz | TV satellite DVB-S/S2, flux data | Parabole TVSat + LNB universel + RTL-SDR |

### 6.1 Météo LEO — NOAA APT et Meteor-M LRPT

**Difficulté** : faible à moyenne — excellent projet d'initiation.

Matériel : RTL-SDR (idéalement TCXO 0,5 ppm), antenne QFH ou turnstile 137 MHz, filtre passe-bande 137 MHz, LNA faible bruit avec bias tee (un « Sawbird NOAA » combine filtre + LNA en un seul module), câble court de qualité.

Logiciel : **SDR++** ou **Gqrx** pour l'écoute et le réglage, **SatDump** (moderne, complet) pour le décodage APT/LRPT — WXtoImg existe encore mais n'est plus maintenu —, **GPredict** ou **Orbitron** pour le tracking et la correction Doppler.

Points techniques Meteor LRPT : la correction Doppler devient importante (signal numérique ~600–800 kHz de large), il faut soit décoder en temps réel avec suivi automatique, soit enregistrer l'IQ brut pour un décodage/une correction offline optimisée.

**Astuce méthodologique** : enregistrer le flux IQ brut et décoder offline permet d'optimiser le traitement (fenêtrage, filtrage, correction Doppler fine) sans contrainte de temps réel, et de ré-analyser plus tard avec de meilleurs outils.

### 6.2 ISS et SSTV

L'ISS émet occasionnellement du SSTV (*Slow-Scan Television*) autour de 145,8 MHz FM lors d'événements ARISS annoncés. Matériel : RTL-SDR, antenne VHF simple, logiciel de décodage SSTV. Activité irrégulière — il faut suivre les annonces de la communauté radioamateur.

### 6.3 Satellites radioamateurs et CubeSats à télémétrie ouverte

Nombreux satellites amateurs diffusent balises VHF/UHF, transpondeurs, télémétrie publique, en modes CW, FM, AFSK, FSK, BPSK, GMSK, LoRa expérimental, AX.25. Outil de référence : **gr-satellites** (bibliothèque de décodeurs pour de nombreux CubeSats), complété par **URH** (*Universal Radio Hacker*) pour l'analyse offline de signaux inconnus mais publics. Vérifier systématiquement que la télémétrie visée est bien publique/destinée à la communauté amateur (bases **SatNOGS DB**, **AMSAT**).

**SatNOGS** permet en plus de contribuer à un réseau ouvert de stations sol : automatisation des passages, décodage de télémétries connues, partage d'observations publiques.

### 6.4 Inmarsat AERO (bande L) — étude de cas approfondie

C'est l'exemple le plus riche pédagogiquement pour comprendre une chaîne SIGINT complète en bande L.

**Contexte** : Inmarsat AERO est le service aéronautique par satellite d'Inmarsat. Il transporte de l'ACARS (messages datalink avion/sol), de la voix AERO (canaux circuit), de l'ADS-C (surveillance automatique dépendante contractuelle), selon différentes générations (Aero-H/H+/I-4). La partie qui nous intéresse en réception amateur est le trafic **paquet de données** (ACARS) et les bursts de signalisation.

**Fréquences downlink typiques** (satellite → sol) — à titre d'exemple pour des satellites Inmarsat-4/Alphasat historiquement utilisés, chaque canal faisant environ 10,5 kHz de large :

| Satellite (position orbitale) | Région couverte | Ordre de grandeur des fréquences ACARS |
|---|---|---|
| Alphasat / I-4 F4 (~25°E) | Europe, Atlantique | ~1545,0–1545,4 MHz |
| I-4 F3 (~54°O) | Amériques | ~1545,0–1545,2 MHz |
| I-4 F2 (~143,5°E) | Asie-Pacifique | ~1545,0–1545,2 MHz |
| I-4 F1 (~109°E) | Inde, Océan Indien | ~1545,1 MHz |

> Les positions orbitales et fréquences exactes évoluent avec le temps (repositionnement de flotte) : toujours vérifier les valeurs courantes auprès de sources communautaires à jour avant de configurer une station.

**Chaîne matérielle recommandée** :

```
[Antenne hélice/patch circulaire, polarisation LHCP] → [Filtre + LNA bande L] → [RTL-SDR] → [PC]
```

- **Antenne** : hélice quadrifilaire ou patch circulaire **LHCP** (Inmarsat émet en polarisation circulaire gauche) ; une antenne linéaire fonctionne mais avec ~3 dB de perte (cf. §2.6).
- **Filtre+LNA bande L** : un module combinant filtre passe-bande 1,5–1,7 GHz et LNA en tête de ligne, alimenté par bias tee au plus près de l'antenne (cf. §2.2, formule de Friis).
- **RTL-SDR** : gain RF ajusté progressivement pour rester sous le seuil de saturation (voir plus bas).

**Chaîne logicielle GNU Radio** (schéma bloc) :

```
[RTL-SDR Source] → [Filtre passe-bas/passe-bande] → [Frequency Xlating FIR Filter] → [Rational Resampler] → [Sortie audio ou fichier WAV]
```

Paramètres indicatifs pour cibler un canal ACARS :
- Sample rate source : 2 048 000 Hz.
- Fréquence centrale : celle du canal visé, en évitant de la caler exactement dessus (viser légèrement au-dessus pour éviter le bruit DC au centre du tuner RTL — un artefact classique des tuners à conversion directe).
- Gain RF : procéder par paliers, en partant de 0 et en augmentant jusqu'à voir le signal sortir du bruit, puis reculer dès l'apparition de produits d'intermodulation (signaux fantômes symétriques autour d'un signal fort) — un gain de l'ordre de 35–42 dB est un point de départ typique.
- Filtre passe-bas : coupure ~15 kHz, transition ~5 kHz, fenêtre de Hamming — pour isoler le canal de 10,5 kHz de ses voisins.
- Rééchantillonnage final : ramener vers 48 000 Hz pour l'étage de décodage.
- Activer la compensation DC offset et l'équilibrage IQ (particulièrement utiles en bande L, où les défauts du tuner sont plus visibles).

**Décodage** : l'outil de référence pour Inmarsat AERO/ACARS est **JAERO**, qui peut fonctionner en flux audio temps réel (carte son virtuelle/monitor PulseAudio), en lecture de fichier WAV (approche « offline », pratique pour analyser à tête reposée après une capture), ou en flux réseau (UDP) pour un pipeline sans passer par l'audio.

**Correction Doppler** : Inmarsat AERO étant géostationnaire, il n'y a pas de Doppler dynamique significatif côté récepteur fixe (cf. §2.5) — ce qui simplifie beaucoup la chaîne comparé à un LEO.

**Ce que révèle ce type de décodage (à but pédagogique et d'observation du trafic ouvert, pas d'exploitation ciblée)** : messages ACARS texte (plans de vol, demandes météo, alertes techniques génériques), identifiants d'aéronef, numéros de vol, rapports de position ADS-C, événements de connexion/déconnexion réseau. JAERO peut exporter en JSON, KML (visualisation dans un outil de cartographie) ou texte brut.

**Pour aller plus loin** : un *polyphase channelizer* dans GNU Radio permet de décoder plusieurs canaux ACARS simultanément avec un seul RTL-SDR ; une corrélation avec de la réception ADS-B (1090 MHz) permet de recouper les identifiants d'aéronefs.

### 6.5 GOES / Himawari / Elektro-L (HRIT/EMWIN)

Les satellites météo géostationnaires modernes (GOES-16/17/18 pour les Amériques, Meteosat Second Generation pour l'Europe) diffusent en bande L. Matériel : RTL-SDR + LNA + filtre 1,694 GHz (ou module combiné dédié), parabole TVSat 60–90 cm avec feed adapté en bande L, éventuellement un downconverter selon la couverture du SDR utilisé. Logiciel : **SatDump** est aujourd'hui l'outil le plus abouti pour ce type de flux.

### 6.6 TVSat C-Band et Ku-Band — au-delà de la simple réception TV

Matériel : parabole TVSat (80 cm à 1,2 m minimum), LNB universel (Ku) ou LNB C-Band avec downconverter, RTL-SDR connecté au LNB via une alimentation adaptée (13/18 V, ton 22 kHz — voir §5). Logiciel : SDR++ (avec plugin DVB-S/S2 si disponible), décodeurs DVB-S/S2 dédiés, **SigDigger** pour l'analyse spectrale approfondie.

Au-delà des chaînes TV classiques, les transpondeurs satellite TV transportent aussi des flux de données (télémesure, liaisons IP satellitaires, trafic VSAT) repérables en scannant méthodiquement les transpondeurs disponibles — c'est ce type de démarche systématique de balayage et d'identification qui relève du RF-OSINT.

### 6.7 GNSS (à titre indicatif)

GPS L1 (1575,42 MHz), Galileo E1 (idem), GLONASS G1 (~1602 MHz), GPS L5/Galileo E5a (1176,45 MHz). Le RTL-SDR peut théoriquement échantillonner ces bandes, mais les signaux sont **sous le bruit thermique** (signaux à spectre étalé de très faible puissance), nécessitant un traitement long, une antenne active, et des algorithmes d'acquisition/corrélation complexes. Ce n'est pas un projet d'initiation mais une expérimentation de recherche.

---

## 7. Méthode d'analyse spectrale passive (RF-OSINT)

### 7.1 Survey spectral

Objectif : cartographier les porteuses visibles sur une bande donnée (par exemple avec `rtl_power` pour générer une heatmap fréquence/temps). Intérêt : identifier des porteuses continues, repérer des signaux intermittents, détecter des balises, comparer avec des prédictions de passage satellite.

### 7.2 Fiche de mesure pour chaque signal inconnu (mais public)

À consigner systématiquement : date/heure UTC, fréquence centrale, sample rate, gain, antenne utilisée, bande passante approximative observée, type apparent de modulation (CW, FM, FSK, PSK, burst...), durée, niveau, dérive fréquentielle observée, position GPS de la station de réception.

### 7.3 Classification visuelle de modulation (signature spectrale)

| Signature spectrale | Type probable |
|---|---|
| Porteuse étroite stable | CW, balise |
| FM large avec audio | Voix, SSTV, APT |
| Deux tons alternés | AFSK |
| Spectre carré/en cloche | FSK/BPSK |
| Bursts réguliers | TDMA/paquet |
| Spectre étalé | GNSS ou spread spectrum |
| Sidebands symétriques | AM/DSB |
| Structure périodique | Télémétrie cyclique |

Ce n'est qu'après avoir confirmé qu'un signal est **public** que l'on tente un décodeur connu (multimon-ng, gr-satellites, JAERO, etc.).

### 7.4 Identification par Doppler

Voir la formule et le tableau du §2.5. Un signal qui suit une courbe Doppler compatible avec un passage LEO prévu (calculé via GPredict et des TLE publics) peut être associé au satellite catalogué correspondant, avec un niveau de confiance à documenter honnêtement — jamais présenté comme une certitude sans recoupement.

### 7.5 Enregistrement et métadonnées IQ

Pour toute capture destinée à une analyse offline, conserver systématiquement : fréquence centrale, sample rate, gain, date UTC, matériel (dongle, antenne, filtre, LNA), conditions météo si pertinent, TLE utilisés, notes libres. Le format **SigMF** (metadata JSON standard pour fichiers IQ) est recommandé pour cette documentation, ou à défaut un fichier texte compagnon systématique.

### 7.6 Correction Doppler en pratique

- **En temps réel** : GPredict piloté via hamlib/rigctld pour ajuster automatiquement la fréquence du récepteur pendant le passage.
- **Offline** : à partir d'un enregistrement IQ, estimer la dérive puis la corriger par multiplication avec une exponentielle complexe (rotation de phase progressive compensant le décalage), suivie d'un rééchantillonnage si nécessaire — réalisable dans GNU Radio ou en Python/NumPy.

---

## 8. Panorama logiciel

### 8.1 Pilotes et outils de base (Linux)

`rtl-sdr`, `librtlsdr-dev` fournissent les pilotes et utilitaires en ligne de commande (`rtl_sdr`, `rtl_power`, `rtl_fm`, `rtl_tcp`). Il est souvent nécessaire de blacklister le module noyau DVB-T générique pour que le dongle soit reconnu comme périphérique SDR plutôt que comme tuner TV.

### 8.2 Réception / SDR généraliste

- **SDR++** — multiplateforme, moderne, bon choix général.
- **Gqrx** — simple, efficace sous Linux, basé sur GNU Radio.
- **SDRAngel** — très complet, inclut un scanner de fréquences intégré et de nombreux plugins de démodulation/décodage.
- **CubicSDR** — multiplateforme.
- **SigDigger** — analyseur de signaux orienté investigation, bon pour l'inspection fine.

### 8.3 Suivi orbital

**GPredict** (suivi, passages, Doppler, pilotage de rotor), Orbitron (Windows), Heavens-Above et N2YO (prédictions en ligne), CelesTrak et Space-Track (sources de TLE publics/officiels), SatNOGS (réseau et base de données communautaire).

### 8.4 Décodage

**SatDump** (NOAA APT, Meteor LRPT et bien d'autres — outil de référence actuel), **gr-satellites** (bibliothèque de décodeurs CubeSat/amateur), **JAERO** (Inmarsat AERO/ACARS-C), **gr-iridium** (bursts Iridium), **URH** (*Universal Radio Hacker*, analyse de signaux numériques inconnus), **multimon-ng** (AFSK, DTMF, POCSAG, etc. — uniquement sur signaux publics/licites), **Audacity** (analyse spectrale de fichiers audio), **Inspectrum** et **Baudline** (analyse offline de spectrogrammes).

### 8.5 Trafic aérien complémentaire

**Dump1090** (ADS-B 1090 MHz), **ACARSdec** (ACARS VHF classique, hors satellite), **VDLM2dec**, **DumpHFDL** — utiles pour recouper les identifiants d'aéronefs obtenus en bande L (Inmarsat) avec les données ADS-B/ACARS terrestres.

### 8.6 Automatisation

Scripts bash/Python (`pyrtlsdr`, SoapySDR), cron pour la planification, GPredict + hamlib/rigctld pour le pilotage de rotor et la correction Doppler, SQLite pour les journaux, rsync pour l'archivage automatique des captures.

---

## 9. Distributions Linux spécialisées « radio »

Plusieurs distributions packagent l'essentiel de l'écosystème SDR pour éviter une installation manuelle fastidieuse. Voici les quatre les plus citées dans la communauté, avec leurs outils phares et des instructions pour reproduire l'essentiel de leur contenu sur une Ubuntu standard.

### 9.1 Gorizont (Gorizont-RTLSDR)

Basée sur Xubuntu 20.04 LTS.

- Site : SourceForge (page projet *gorizont-rtlsdr*) ; article de présentation sur rtl-sdr.com.
- Outils : Gqrx, SigDigger, Universal Radio Hacker (URH), Welle.io (DAB/DAB+), GNU Radio, multimon-ng, fldigi, Baudline, Dream DRM (via Wine), gqrx-scan/w-scan (scan DVB-T/ATSC), guglielmo (FM/DAB léger).

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential cmake git libboost-all-dev \
    libfftw3-dev libgsl-dev libqt5-dev libqt5opengl5-dev \
    libpulse-dev libsoapysdr-dev librtlsdr-dev

sudo apt install -y gqrx-sdr gnuradio gnuradio-dev sigdigger \
    universal-radio-hacker welle-io fldigi multimon-ng \
    rtl-sdr librtlsdr-dev
```

### 9.2 Skywave Linux

Basée sur Debian Sid.

- Site : skywavelinux.com ; dépôts GitHub (scripts de build, scripts SDR complémentaires).
- Outils : Gqrx, CubicSDR, SDR++, GNU Radio, Dump1090, DumpHFDL, ACARSdec, VDLM2dec (trafic aérien), fldigi, JS8Call, WSJT-X (modes numériques amateur), SatDump, GPredict, SoapySDR (+ drivers Airspy/BladeRF/HackRF/RTL-SDR/USRP/LimeSDR/PlutoSDR), multimon-ng, RTLSDR-Airband, ainsi que des outils multimédia (OBS Studio, Audacity), de développement (Neovim, Python, Go, JupyterLab) et réseau/confidentialité (Tor, I2P, WireGuard, OpenVPN, Reticulum, MeshChat pour réseaux maillés LoRa).

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y rtl-sdr librtlsdr-dev libsoapysdr-dev
sudo apt install -y gqrx-sdr gnuradio gnuradio-dev
# CubicSDR : téléchargement direct (AppImage) depuis les releases GitHub du projet
wget https://github.com/cjcliffe/CubicSDR/releases/download/0.2.7/CubicSDR-0.2.7-x86_64.AppImage
chmod +x CubicSDR-0.2.7-x86_64.AppImage

sudo apt install -y sdrpp dump1090-fa fldigi wsjtx js8call gpredict multimon-ng
sudo apt install -y soapysdr-module-rtlsdr soapysdr-module-hackrf soapysdr-module-bladerf
# SatDump : voir le dépôt GitHub du projet (build manuel ou paquet selon disponibilité)
```

### 9.3 SigIntOS

Basée sur Ubuntu.

- Site : sigintos.com (avec une liste logicielle publiée sur leur wiki) ; dépôt GitHub de démonstrations RTL-SDR/HackRF.
- Outils : côté GSM/4G/5G — YateBTS, gr-gsm, srsRAN 4G, Open5GS (⚠️ ces outils touchent à l'émission/simulation de réseaux cellulaires : usage strictement encadré légalement, généralement en cage de Faraday ou banc de test isolé, jamais en émission réelle sans autorisation) ; traitement du signal — GNU Radio, Gqrx, SDRAngel, SigDigger ; trafic aérien — Dump1090, interface web ADS-B ; trafic maritime — OpenCPN ; satellites — GPredict ; pilotes — BladeRF, HackRF, RTL-SDR, USRP (UHD), OsmoSDR ; services serveur — Apache, MySQL, MongoDB (pour l'archivage de données).

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y gnuradio gnuradio-dev gqrx-sdr sdrangel sigdigger \
    dump1090-fa gpredict opencpn
sudo apt install -y rtl-sdr librtlsdr-dev hackrf libhackrf-dev \
    bladerf libbladerf-dev libuhd-dev uhd-host libosmosdr-dev

# srsRAN 4G (build manuel — dépôt GitHub officiel srsran/srsRAN_4G)
git clone https://github.com/srsran/srsRAN_4G.git
cd srsRAN_4G && mkdir build && cd build && cmake ../ && make && sudo make install

# YateBTS (build manuel — usage GSM extrêmement réglementé, cf. avertissement §0)
git clone https://github.com/YateBTS/yatebts.git
cd yatebts && ./configure && make && sudo make install
```

### 9.4 Andy's HAM Radio Linux (AHRL)

Basée sur Xubuntu/Ubuntu, distribuée sous forme de script d'installation.

- Site : SourceForge (projet *kb1oiq-andysham*), documentation « Getting Started ».
- Outils : modes numériques — fldigi, NBEMS, FreeDV, WSJT-X, JS8Call, M17 ; logging — XLog, cqrlog, fllog ; contrôle transceiver — flrig, grig, CHIRP ; satellites — GPredict, Xastir ; antennes — xnec2c, fl_moxgen, aa-analyzer, VOACAP ; CW — xcwcp, qrq, Micro-Fox ; SDR — Gqrx, SDRAngel, GNU Radio Companion, Quisk, Direwolf (TNC logiciel AX.25/APRS) ; électronique — KiCad, gEDA, EasySpice ; paquet radio — linpac, linamc.

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y fldigi flrig fllog wsjtx js8call freedv
sudo apt install -y gqrx-sdr sdrangel gnuradio gnuradio-dev
sudo apt install -y gpredict xastir direwolf kicad chirp xcwcp
sudo apt install -y rtl-sdr librtlsdr-dev
```

### 9.5 Tableau récapitulatif

| Distribution | Base | Outils phares | Référence |
|---|---|---|---|
| Gorizont | Xubuntu 20.04 | Gqrx, SigDigger, URH, Welle.io, GNU Radio | SourceForge *gorizont-rtlsdr* |
| Skywave Linux | Debian Sid | Gqrx, CubicSDR, Dump1090, fldigi, SatDump, GPredict | skywavelinux.com |
| SigIntOS | Ubuntu | YateBTS, srsRAN, Open5GS, Gqrx, SDRAngel, Dump1090 | sigintos.com |
| Andy's HAM Linux | Xubuntu/Ubuntu | fldigi, WSJT-X, Gqrx, GPredict, KiCad, CHIRP | SourceForge *kb1oiq-andysham* |

---

## 10. Station minimale « scanner → identifier → capturer → analyser »

Configuration compacte pour débuter le RF-OSINT passif sans installer une distribution complète.

| Étape | Outil | Rôle |
|---|---|---|
| 1. Réception SDR | Gqrx | Récepteur principal, spectre temps réel |
| 2. Scan de fréquences | gqrx-scanner ou SDRAngel (Frequency Scanner) | Balayage automatique d'une plage et détection d'activité |
| 3. Enregistrement | Gqrx (audio ou IQ) | Capture des signaux détectés |
| 4. Analyse audio | Audacity | Visualisation spectrale du contenu capturé |
| 5. Décodage numérique | multimon-ng, fldigi | Décodage de modes numériques connus (AFSK, POCSAG, RTTY, PSK31...) |

### 10.1 Installation

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential cmake git pkg-config \
    libboost-all-dev libfftw3-dev libgsl-dev \
    libqt5opengl5-dev libpulse-dev libsoapysdr-dev \
    librtlsdr-dev rtl-sdr

sudo apt install -y gqrx-sdr gnuradio
sudo apt install -y libvolk1-bin
volk_profile        # optimise les routines DSP pour le CPU local (recommandé)

# gqrx-scanner (scanner externe piloté via l'interface distante de Gqrx)
cd ~
git clone https://github.com/neural75/gqrx-scanner.git
cd gqrx-scanner && mkdir build && cd build && cmake .. && make && sudo make install

# SDRAngel (alternative avec scanner intégré, via Snap)
sudo snap install sdrangel
sudo snap connect sdrangel:raw-usb
sudo snap connect sdrangel:audio-record

sudo apt install -y audacity multimon-ng fldigi
```

### 10.2 Workflow type

1. **Scanner** une plage de fréquences : lancer Gqrx, activer `Tools → Remote Control`, puis dans un autre terminal : `gqrx-scanner -f 100000000 -t 200000000 -s 10000 -m sweep` (balaye 100–200 MHz par pas de 10 kHz). Avec SDRAngel, ajouter un *Device Set* puis le plugin *Frequency Scanner* et configurer plage + seuil de détection.
2. **Identifier** les fréquences actives : observer le spectre, noter les pics de puissance et la signature de modulation visible (cf. §7.3).
3. **Capturer** le signal repéré : sur Gqrx, régler le mode de démodulation adéquat (AM/FM/NFM/USB...), puis `File → Record` pour l'audio ou `File → I/Q recording` pour la capture brute (préférable pour une analyse ultérieure poussée).
4. **Analyser** : dans Audacity, `Analyze → Plot Spectrum` pour visualiser tonalités, bande passante, motifs répétitifs. Pour un signal numérique, tenter un décodage avec multimon-ng :

```bash
multimon-ng -t raw -a FSK1200 -a FSK2400 -a AFSK1200 fichier.wav
# ou en flux temps réel via une pipe nommée depuis la sortie audio de Gqrx :
mkfifo /tmp/sdr_pipe
multimon-ng -t raw -a FSK1200 -a POCSAG512 -a POCSAG1200 /tmp/sdr_pipe &
```

Pour fldigi, router la sortie audio de Gqrx vers l'entrée de fldigi via PulseAudio (`parec`/`pacat`) ou un câble audio virtuel, puis choisir le mode adapté (RTTY, PSK31, FT8...).

### 10.3 Dépannage courant : conflit de version Gqrx / GNU Radio

Erreur typique : `gqrx: error while loading shared libraries: libgnuradio-digital.so.3.X.X: cannot open shared object file`. Cela signifie que Gqrx a été compilé contre une version de GNU Radio différente de celle installée.

**Solution recommandée — réinstallation propre via le PPA officiel :**

```bash
sudo apt purge --auto-remove gqrx-sdr gnuradio libgnuradio-*
sudo apt autoremove
sudo add-apt-repository ppa:gnuradio/gnuradio-releases
sudo apt update
sudo apt install gnuradio gqrx-sdr
sudo ldconfig
```

**Diagnostic préalable utile :**

```bash
ldconfig -p | grep gnuradio-digital     # version(s) de bibliothèque réellement présentes
dpkg -l | grep gnuradio                 # paquets GNU Radio installés
lsb_release -a                          # version d'Ubuntu
```

**Solution de contournement rapide (non recommandée en usage durable)** : créer un lien symbolique vers la version disponible — utile en dépannage ponctuel mais risqué en cas d'écart de version trop important entre l'ABI attendue et l'ABI réelle :

```bash
sudo ln -s /usr/lib/x86_64-linux-gnu/libgnuradio-digital.so.3.10.11 \
           /usr/lib/x86_64-linux-gnu/libgnuradio-digital.so.3.10.10
sudo ldconfig
```

**Vérification finale :**

```bash
ldd /usr/bin/gqrx | grep gnuradio
gqrx
```

---

## 11. Dépannage général

### 11.1 Saturation / intermodulation

Symptômes : raies fantômes, intermodulation, remontée du bruit de fond, décodage instable. Causes fréquentes : gain trop élevé, absence de filtrage, LNA surdimensionné placé en présence de signaux forts. Solutions : baisser le gain, ajouter un atténuateur, ajouter un filtre passe-bande adapté, retirer ou repositionner le LNA, éloigner le RTL-SDR des sources d'interférence numérique (USB 3.0, écrans, alimentations à découpage).

### 11.2 Dérive fréquentielle

Causes : TCXO de qualité médiocre, variation de température, mauvaise calibration, sample rate mal configuré. Solutions : calibrer sur une porteuse connue (station de référence, balise stable), utiliser une référence externe si disponible (GPSDO), et utiliser GPredict pour distinguer un Doppler réel d'une simple dérive locale de l'oscillateur.

### 11.3 Décodage numérique impossible

Causes possibles : Doppler non corrigé, mauvais débit symbole supposé, mauvaise hypothèse de modulation, inversion spectrale (IQ inversés), SNR insuffisant, bande passante de filtrage trop étroite ou trop large par rapport au signal réel.

---

## 12. Sécurité physique

### 12.1 Antennes extérieures

Fixation solide, prise au vent à anticiper, haubanage si nécessaire, pas d'installation à proximité des lignes électriques, mise à la terre, protection contre la foudre pour toute installation fixe extérieure.

### 12.2 Paraboles

Ne jamais pointer une parabole vers le Soleil sans protection (risque d'échauffement du feed/LNB), attention aux bords métalliques, prise au vent importante à prendre en compte dans le dimensionnement du mât.

### 12.3 LNB et alimentations

Tension 13/18 V DC sur le coaxial : risque de court-circuit, vérifier systématiquement la polarité, ne jamais alimenter un RTL-SDR directement sans circuit adapté, utiliser des alimentations protégées.

### 12.4 Émission

Ne jamais improviser un uplink : licence radioamateur requise, risque réel de brouillage satellite, conséquences légales lourdes, nécessité absolue de contrôler puissance, bande, mode et direction. **Ce guide ne couvre que la réception passive.**

---

## 13. Méthodologie et rigueur expérimentale

Que l'on soit passionné ou sceptique face à des observations non confirmées, la bonne méthode reste toujours la même :

1. Noter systématiquement tout en **UTC**.
2. Enregistrer le signal brut (IQ) quand c'est pertinent.
3. Sauvegarder fréquence, sample rate, gain, antenne utilisée.
4. Comparer avec des prédictions orbitales publiques (TLE).
5. Vérifier avec un second récepteur si possible.
6. Ne documenter publiquement que ce qui est vérifiable.
7. Ne pas confondre artefact, interférence et signal réel.
8. Ne jamais extrapoler une observation en « preuve » sans analyse solide.
9. Respecter la loi et la vie privée en toute circonstance.

**Carnet de bord type** — pour chaque observation : date/heure UTC, position GPS, matériel utilisé, antenne, fréquence, sample rate, gain, logiciel, TLE utilisés, capture d'écran, fichier IQ associé, notes d'observation libres, résultat du décodage, niveau de confiance de l'identification.

---

## 14. Idées d'expériences pédagogiques

- **Mesurer le Doppler d'un satellite connu** : choisir un satellite public actif, calculer le passage avec GPredict, enregistrer IQ ou waterfall, mesurer fréquence vs temps, comparer à la courbe Doppler prédite, en déduire l'erreur ppm résiduelle du RTL-SDR.
- **Comparer deux antennes** : même satellite, même passage si possible ; comparer niveau moyen et SNR entre QFH, dipôle, Yagi ; noter les effets de polarisation.
- **Mesurer le gain réel d'une parabole** : comparer la réception d'un signal public stable avec une antenne de référence connue, corriger des pertes câble, estimer le gain réel obtenu.
- **Cartographier les interférences locales** : `rtl_power` sur plusieurs bandes, comparaison jour/nuit, identification des sources typiques (alimentations à découpage, CPL, écrans), amélioration du filtrage/blindage en conséquence.
- **Tester la stabilité d'un LNB** : observer une balise publique stable, mesurer la dérive sur 10 minutes puis 1 heure, comparer un LNB standard à un LNB référencé, documenter température et alimentation.

---

## 15. Exemples de configurations complètes

### 15.1 Station météo portable (NOAA/Meteor)

RTL-SDR Blog V3/V4, QFH 137 MHz, filtre passe-bande 137 MHz, LNA faible bruit avec bias tee, câble court, PC portable, SDR++/Gqrx + SatDump + GPredict. Capacités : APT NOAA, LRPT Meteor, observation spectrale 136–138 MHz.

### 15.2 Station UHF CubeSat

RTL-SDR avec bon TCXO, turnstile 435 MHz ou petite Yagi, filtre 435 MHz, LNA UHF, rotor manuel ou automatique, gr-satellites. Capacités : balises UHF, AFSK/FSK/BPSK, CubeSats publics, contribution SatNOGS.

### 15.3 Station parabole expérimentale (Ku/QO-100)

Parabole 60–90 cm, LNB universel (ou modifié/référencé), alimentation 13/18 V + ton 22 kHz, RTL-SDR, éventuel convertisseur/PLL additionnel, support stable. Capacités : observation de l'IF 950–2150 MHz, balises étroites, expérimentation LNB, réception QO-100.

### 15.4 Station avancée multi-capteurs

Un RTL-SDR dédié à la météo VHF, un autre à l'UHF amateur, un SDR plus large bande (SDRplay/Airspy) pour le survey, une référence GPSDO/10 MHz si disponible, des filtres par bande, un switch RF ou des splitters avec isolation, un PC puissant, une base de données pour l'archivage. Capacités : survey multi-bandes, corrélation temporelle entre bandes, archivage IQ systématique, mesure de stabilité, expérimentations Doppler avancées.

### 15.5 Station Inmarsat AERO dédiée (checklist de démarrage)

```
□ Antenne hélicoïdale/patch LHCP pointée vers le satellite géostationnaire visible localement
□ Filtre+LNA bande L en tête de ligne, alimenté par bias tee
□ RTL-SDR v3/v4, gain ~35-42 dB, sample rate 2,048 Ms/s
□ GNU Radio : flowgraph avec Frequency Xlating FIR Filter + Resampler vers 48 kHz
□ JAERO lancé, mode AERO-P, BPSK, largeur de canal 10 500 Hz
□ Vérification visuelle : porteuse stable et fine dans le waterfall (pas un burst isolé)
□ Enregistrement IQ/WAV brut pour archive et analyse offline
```

---

## 16. Bonnes pratiques de documentation

Pour chaque fichier IQ conservé, ajouter un fichier `.json` ou `.txt` compagnon reprenant les métadonnées du §7.5 (idéalement au format SigMF). Pour les images décodées (APT/LRPT/HRIT) : conserver l'image brute **et** l'image post-traitée, conserver les logs de décodage, noter explicitement si une interpolation ou une correction a été appliquée — la traçabilité de chaque transformation est ce qui distingue une observation amateur rigoureuse d'une simple capture d'écran.

---

## 17. Ressources et références

- **RTL-SDR Blog** (rtl-sdr.com) — guides exhaustifs matériel et logiciel (NOAA, GOES, Inmarsat...).
- **SatDump** — github.com/SatDump/SatDump — décodeur satellite le plus complet actuellement.
- **JAERO** — décodeur de référence pour Inmarsat AERO/ACARS-C.
- **gr-satellites** — bibliothèque de décodeurs CubeSat/amateur pour GNU Radio.
- **AMSAT** — guide et éphémérides des satellites radioamateurs.
- **SatNOGS** — réseau et base de données ouverte de stations sol.
- **CelesTrak** et **Space-Track** — sources de TLE (éléments orbitaux).
- **jcoppens.com** — calculateur en ligne d'antenne QFH.
- Distributions spécialisées : Gorizont-RTLSDR (SourceForge), Skywave Linux (skywavelinux.com), SigIntOS (sigintos.com), Andy's HAM Radio Linux (SourceForge, projet *kb1oiq-andysham*).
- Autorités de régulation à consulter selon le pays : ANFR (France), Ofcom (Royaume-Uni), FCC (États-Unis), etc.

---

## 18. Ce qu'il faut retenir

Avec un simple RTL-SDR, un amateur peut légalement et légitimement : recevoir des images météo satellite, suivre des passages et mesurer le Doppler, décoder des télémétries publiques (CubeSats, ACARS satellite), expérimenter avec antennes/LNB/paraboles, construire une station automatisée, apprendre l'analyse spectrale passive, contribuer à des réseaux open source comme SatNOGS.

Le RTL-SDR a néanmoins des limites structurelles : bande passante instantanée faible (~2 MHz), dynamique limitée (8 bits), absence de cohérence de phase native entre dongles, peu adapté aux signaux larges ou très faibles (GNSS, DVB-S2 haut débit) — il nécessite de bonnes antennes et un filtrage soigné pour donner sa pleine mesure.

**Ce qui compte le plus n'est jamais le dongle lui-même, mais** : l'antenne (adaptée en gain et polarisation à la cible), le filtrage (contre la saturation), le LNA correctement placé (au pied de l'antenne, cf. Friis), la calibration fréquentielle, le suivi Doppler, la documentation rigoureuse (carnet de bord, métadonnées), et le respect scrupuleux du cadre légal.

### Progression recommandée

1. Station 137 MHz NOAA/Meteor avec QFH — pour valider toute la chaîne (antenne, tracking, décodage) sur une cible facile et gratifiante.
2. Montée en fréquence vers l'UHF CubeSat/amateur — pour se familiariser avec gr-satellites et le pointage/rotor.
3. Passage à la bande L (Inmarsat AERO, GOES/HRIT) — le « sweet spot » du RF-OSINT amateur, où l'apport d'un bon LNA et d'une antenne circulaire adaptée devient déterminant.
4. Parabole LNB/Ku (TVSat, QO-100) — pour explorer le downconvertissement et les hautes fréquences.

C'est la progression naturelle vers une station de réception « RF-OSINT satellite » amateur sérieuse, documentée, et respectueuse du cadre légal.
