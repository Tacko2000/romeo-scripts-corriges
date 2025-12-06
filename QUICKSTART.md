# 🚀 Guide de démarrage rapide

## Installation en 3 étapes

### 1. Se connecter à ROMEO

```bash
ssh <votre_login>@romeo1.univ-reims.fr
```

### 2. Cloner et installer

```bash
# Cloner le dépôt
git clone <URL_DU_DEPOT> romeo-scripts-corriges
cd romeo-scripts-corriges

# Rendre les scripts exécutables
chmod +x myjobs_corrige.sh runjupyter_corrige.sh
```

### 3. Tester les scripts

#### Test de myjobs_corrige.sh

```bash
# D'abord, allouer des ressources
salloc --nodes=2 --ntasks=4 -c 2 --time=00:30:00 \
       --account=<votre_projet> --constraint=armgpu \
       --mem=1G --gpus-per-node=1

# Dans un autre terminal, visualiser vos jobs
./myjobs_corrige.sh
```

#### Test de runjupyter_corrige.sh

```bash
# Lancer Jupyter avec configuration minimale
./runjupyter_corrige.sh -i <votre_projet>

# Ou avec PyTorch et plus de ressources
./runjupyter_corrige.sh \
  -n mon_env \
  -c 4 \
  -m 8 \
  --gpus 1 \
  --pytorch-gpu \
  -i <votre_projet>
```

## 🔌 Connexion à Jupyter

Après le lancement, vous verrez :

```
=== INSTRUCTIONS DE CONNEXION ===

1. Dans un NOUVEAU terminal LOCAL, exécutez cette commande:
ssh -N -L 8888:romeo-a046:8123 login@romeo1.univ-reims.fr

2. Ouvrez votre navigateur web à cette adresse:
http://localhost:8888/?token=<TOKEN>
```

## 📱 Commandes utiles

```bash
# Voir vos jobs
squeue --me

# Voir les détails avec visualisation
./myjobs_corrige.sh

# Voir les logs Jupyter
tail -f ~/jupyter_environments/jupyter_*.out

# Arrêter un job
scancel <JOBID>

# Voir votre quota disque
myquota
```

## ⚠️ Problèmes fréquents

### "Port already in use"
➡️ Solution : Arrêter le job (`scancel <JOBID>`) et relancer

### "Permission denied"
➡️ Solution : `chmod +x *.sh`

### Job ne démarre pas
➡️ Solution : Vérifier avec `squeue --me` et consulter les logs

## 📖 Documentation complète

Pour plus de détails, consultez le [README.md](README.md) complet.

## 💬 Besoin d'aide ?

- Documentation ROMEO : https://romeo.univ-reims.fr
- Support : Via le portail ROMEO
