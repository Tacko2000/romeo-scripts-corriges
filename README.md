# Scripts ROMEO - Formation du 1er décembre 2025

Scripts améliorés pour le monitoring des jobs SLURM et le lancement de notebooks Jupyter sur le supercalculateur ROMEO2025.

## 📋 Table des matières

- [À propos](#à-propos)
- [Scripts disponibles](#scripts-disponibles)
- [Corrections et améliorations](#corrections-et-améliorations)
- [Installation](#installation)
- [Utilisation](#utilisation)
- [Exemples](#exemples)
- [Auteurs](#auteurs)

## 🎯 À propos

Ce dépôt contient deux scripts Bash corrigés et améliorés dans le cadre de la formation ROMEO du 1er décembre 2025 :

1. **myjobs_corrige.sh** - Script de monitoring des jobs SLURM avec visualisation graphique
2. **runjupyter_corrige.sh** - Script automatisé pour lancer JupyterLab sur ROMEO HPC

### Contexte de la formation

Formation interactive sur l'utilisation de ROMEO2025 et l'exploitation des performances GPU, organisée par le Centre de Calcul Régional ROMEO de l'Université de Reims Champagne-Ardenne.

## 📦 Scripts disponibles

### 1. myjobs_corrige.sh

Script de monitoring des jobs SLURM avec visualisation graphique des ressources allouées.

**Fonctionnalités :**
- Affichage coloré et structuré des informations de jobs
- Visualisation graphique des cœurs CPU et GPU alloués
- Regroupement des nœuds par architecture (APU)
- Support des architectures x64cpu et armgpu

### 2. runjupyter_corrige.sh

Script automatisé pour lancer JupyterLab sur Romeo HPC avec gestion intelligente des ports.

**Fonctionnalités :**
- Création automatique d'environnements Python virtuels
- Sélection automatique de ports libres sur le nœud de calcul
- Support GPU avec installation optionnelle de PyTorch
- Répertoire de travail personnalisable
- Copie automatique de fichiers sources
- Gestion des tunnels SSH

## 🔧 Corrections et améliorations

### Corrections apportées à myjobs.v3.sh

1. **Correction du parsing des CPU_IDs**
   - Le code original contenait un bug dans la boucle de vérification des cœurs alloués
   - Utilisation correcte de `IFS` pour convertir la chaîne CSV en tableau
   - Vérification améliorée de l'allocation des cœurs

2. **Regroupement par APU/architecture**
   - Ajout d'une fonction `group_nodes_by_apu()` pour regrouper les nœuds par architecture
   - Affichage structuré par type d'architecture (x64cpu, armgpu)
   - Meilleure lisibilité pour les allocations multi-nœuds

### Corrections apportées à runjupyter.beta.sh

1. **Gestion intelligente des ports**
   - **SUPPRESSION** de la vérification de port AVANT allocation (inutile et source d'erreurs)
   - Vérification des ports UNIQUEMENT sur le nœud de calcul (au bon moment)
   - Recherche dynamique de ports libres dans la plage 8000-8999
   - Garantie que les ports choisis sont réellement disponibles

2. **Option --workdir**
   - Possibilité de spécifier le répertoire de démarrage du notebook
   - Support des chemins relatifs et absolus
   - Meilleure flexibilité pour les projets existants

3. **Utilisation de --gpus-per-node**
   - Conformité avec la syntaxe SLURM de ROMEO
   - Remplacement de `--gpus` par `--gpus-per-node`

4. **Amélioration de la robustesse**
   - Gestion des timeouts avec limites configurables
   - Meilleure détection de l'état des jobs
   - Messages d'erreur plus explicites

## 📥 Installation

### Prérequis

- Accès à ROMEO via SSH : `ssh <login>@romeo1.univ-reims.fr`
- Compte projet ROMEO valide
- Bash 4.0 ou supérieur

### Téléchargement

```bash
# Se connecter à ROMEO
ssh <login>@romeo1.univ-reims.fr

# Cloner le dépôt
git clone <URL_DU_DEPOT>
cd <nom_du_depot>

# Rendre les scripts exécutables
chmod +x myjobs_corrige.sh
chmod +x runjupyter_corrige.sh
```

## 🚀 Utilisation

### Script myjobs_corrige.sh

**Utilisation basique :**

```bash
./myjobs_corrige.sh
```

Le script affiche automatiquement tous vos jobs en cours avec :
- Informations détaillées (ID, nom, statut, ressources)
- Visualisation graphique des cœurs et GPU alloués
- Regroupement par architecture

**Exemple d'allocation pour tester :**

```bash
salloc --nodes=4 --ntasks=8 -c 2 --time=01:00:00 \
       --account=r250127 --constraint=armgpu \
       --mem=1G --gpus-per-node=2
```

**Note sur le bug corrigé :**
Le bug initial dans le script original empêchait l'affichage correct des cœurs alloués. La commande d'allocation mentionnée contenait une erreur (`--task` au lieu de `--ntasks`), ce qui a été corrigé dans nos exemples.

### Script runjupyter_corrige.sh

**Syntaxe :**

```bash
./runjupyter_corrige.sh [OPTIONS]
```

**Options principales :**

```
-n, --name NAME         Nom de l'environnement Python (défaut: jupyter_env)
-t, --time TIME         Temps d'allocation Slurm (défaut: 4:00:00)
-c, --cpus CPUS         Nombre de CPUs (défaut: 1)
-m, --memory MEMORY     Mémoire en GB (défaut: 1)
-a, --arch ARCH         Architecture (x64cpu|armgpu, défaut: armgpu)
-i, --codeprojet CODE   Code du projet pour lancer le job
-w, --workdir PATH      Répertoire de démarrage pour Jupyter
--gpus GPUS             Nombre de GPUs par nœud (défaut: 1)
--pytorch-gpu           Installer PyTorch avec support GPU
--packages PACKAGES     Packages Python supplémentaires
--copy-from PATH        Copier les fichiers depuis ce dossier
-h, --help              Afficher l'aide
```

## 💡 Exemples

### Exemple 1 : Configuration par défaut

```bash
./runjupyter_corrige.sh -i r250127
```

Crée un environnement Jupyter avec :
- 1 CPU, 1 GB RAM, 1 GPU
- Architecture armgpu
- Durée 4h
- Port choisi automatiquement sur le nœud

### Exemple 2 : Configuration pour deep learning

```bash
./runjupyter_corrige.sh \
  -n mon_dl_env \
  -t 8:00:00 \
  -c 8 \
  -m 32 \
  -a armgpu \
  --gpus 2 \
  --pytorch-gpu \
  --packages "numpy pandas scikit-learn matplotlib" \
  -i r250127
```

### Exemple 3 : Utilisation d'un projet existant

```bash
./runjupyter_corrige.sh \
  -n projet_analyse \
  -w ~/mon_projet \
  --copy-from ~/mon_projet/data \
  -i r250127
```

### Exemple 4 : Connexion SSH et accès au notebook

Après le lancement du script, vous obtiendrez des informations de connexion :

```bash
# 1. Dans un NOUVEAU terminal LOCAL, créer le tunnel SSH :
ssh -N -L 8888:romeo-a046:8123 login@romeo1.univ-reims.fr

# 2. Ouvrir le navigateur à l'adresse :
http://localhost:8888/?token=<TOKEN_FOURNI>
```

**Important :** La commande SSH semblera bloquée, c'est normal ! Le tunnel est actif.

### Vérification des jobs en cours

```bash
# Lister vos jobs
squeue --me

# Visualiser avec le script amélioré
./myjobs_corrige.sh

# Consulter les logs Jupyter
tail -f ~/jupyter_environments/jupyter_<JOBID>.out

# Arrêter un job
scancel <JOBID>
```

## 📊 Légende de visualisation (myjobs)

```
. = Cœur libre    ■ = Cœur alloué
○ = GPU libre     ● = GPU alloué
```

**Codes couleur des statuts :**
- 🟢 RUNNING (vert)
- 🟡 PENDING (jaune)
- 🔵 COMPLETED (bleu)
- 🔴 FAILED (rouge)
- 🟣 CANCELLED (violet)

## 🐛 Résolution des problèmes

### Port déjà utilisé

Si vous obtenez l'erreur "port already in use" :

```bash
# Arrêter le job
scancel <JOBID>

# Relancer le script (un nouveau port sera choisi)
./runjupyter_corrige.sh -i <projet>
```

### Job ne démarre pas

```bash
# Vérifier l'état du job
squeue --me

# Consulter les erreurs
cat ~/jupyter_environments/jupyter_<JOBID>.err
```

### Environnement Python corrompu

```bash
# Supprimer l'environnement
rm -rf ~/jupyter_environments/<nom_env>

# Recréer en relançant le script
./runjupyter_corrige.sh -n <nom_env> -i <projet>
```

## 📚 Documentation complémentaire

- [Documentation ROMEO](https://romeo.univ-reims.fr)
- [Documentation Spack](https://spack.readthedocs.io)
- [Documentation SLURM](https://slurm.schedmd.com)
- [Support ROMEO](https://docs.claude.com)

## 👥 Auteurs

- **Script original** : Fabien BERINI - Centre de Calcul ROMEO
- **Corrections et améliorations** : Travaux pratiques formation du 1er décembre 2025
- **Formateur** : Arnaud RENARD - Directeur du Centre de Calcul Régional ROMEO

## 📧 Contact

Pour toute question sur ROMEO ou ces scripts :

**Arnaud RENARD**  
Université de Reims Champagne-Ardenne  
Directeur du Centre de Calcul Régional ROMEO  
Email : Via le portail ROMEO  
Tél : +33 326 91 85 91  
Web : http://romeo.univ-reims.fr

## 📜 Licence

Scripts fournis dans le cadre de la formation ROMEO - Usage académique et de recherche.

## 🔄 Changelog

### Version corrigée (1er décembre 2025)

**myjobs_corrige.sh :**
- ✅ Correction du bug de parsing des CPU_IDs
- ✅ Ajout du regroupement par APU/architecture
- ✅ Amélioration de l'affichage visuel

**runjupyter_corrige.sh :**
- ✅ Correction de la vérification des ports (déplacée sur le nœud de calcul)
- ✅ Ajout de l'option --workdir
- ✅ Utilisation de --gpus-per-node (conforme ROMEO)
- ✅ Amélioration de la robustesse et gestion d'erreurs

---

**Dernière mise à jour** : Décembre 2025  
**Version** : 1.0 - Scripts corrigés
