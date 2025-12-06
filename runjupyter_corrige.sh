#!/bin/bash
#by Fabien BERINI for Romeo
# Amélioré selon les consignes du cours du 01-12-2025
# Corrections:
#   - SUPPRESSION de la vérification de port AVANT allocation (inutile)
#   - Vérification du port UNIQUEMENT sur le nœud de calcul (au bon moment)
#   - Option --workdir pour spécifier le répertoire de démarrage du notebook
#   - Utilisation de --gpus-per-node (conforme ROMEO)

set -e  # Arrêter le script en cas d'erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction d'affichage coloré
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Fonction d'aide
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Script automatisé pour lancer JupyterLab sur Romeo HPC

OPTIONS:
    -n, --name NAME         Nom de l'environnement Python (défaut: jupyter_env)
    -t, --time TIME         Temps d'allocation Slurm (défaut: 4:00:00)
    -c, --cpus CPUS         Nombre de CPUs (défaut: 1)
    -m, --memory MEMORY     Mémoire en GB (défaut: 1)
    -a, --arch ARCH         Architecture (x64cpu|armgpu, défaut: armgpu)
    -i, --codeprojet CODE   Code du projet pour lancer le job
    -w, --workdir PATH      Répertoire de démarrage pour Jupyter (défaut: auto)
    --gpus GPUS             Nombre de GPUs par nœud (défaut: 1)
    --pytorch-gpu           Installer PyTorch avec support GPU
    --packages PACKAGES     Packages Python supplémentaires (séparés par espaces)
    --copy-from PATH        Copier les fichiers depuis ce dossier
    -h, --help              Afficher cette aide

EXEMPLES:
    $0                                          # Configuration par défaut
    $0 -n mon_env -t 4:00:00 -c 8 -m 16       # Configuration personnalisée
    $0 --pytorch-gpu --packages "numpy pandas scikit-learn"
    $0 -w ~/mon_projet                         # Démarrer dans un répertoire spécifique
    $0 --gpus 2 -a armgpu                      # Avec 2 GPUs par nœud

NOTE: Les ports sont maintenant choisis automatiquement SUR LE NŒUD DE CALCUL
      au moment du lancement de Jupyter, garantissant leur disponibilité réelle.
EOF
}

# Obtenir le répertoire du script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Valeurs par défaut
ENV_NAME="jupyter_env"
SLURM_TIME="4:00:00"
SLURM_CPUS=1
SLURM_MEMORY=1
ARCH="armgpu"
GPUS=1
PYTORCH_GPU=false
EXTRA_PACKAGES=""
COPY_FROM=""
CUSTOM_WORKDIR=""
TOKEN=$(head /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 100)
PROJET=""

# Parse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            ENV_NAME="$2"
            shift 2
            ;;
        -t|--time)
            SLURM_TIME="$2"
            shift 2
            ;;
        -c|--cpus)
            SLURM_CPUS="$2"
            shift 2
            ;;
        -m|--memory)
            SLURM_MEMORY="$2"
            shift 2
            ;;
        -a|--arch)
            ARCH="$2"
            shift 2
            ;;
        -i|--codeprojet)
            PROJET="$2"
            shift 2
            ;;
        -w|--workdir)
            CUSTOM_WORKDIR="$2"
            shift 2
            ;;
        --gpus)
            GPUS="$2"
            shift 2
            ;;
        --pytorch-gpu)
            PYTORCH_GPU=true
            shift
            ;;
        --packages)
            EXTRA_PACKAGES="$2"
            shift 2
            ;;
        --copy-from)
            COPY_FROM="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Option inconnue: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validation des arguments
if [[ ! "$ARCH" =~ ^(x64cpu|armgpu)$ ]]; then
    print_error "Architecture doit être 'x64cpu' ou 'armgpu'"
    exit 1
fi

if ! [[ "$GPUS" =~ ^[0-9]+$ ]]; then
    print_error "Le nombre de GPUs doit être un nombre entier"
    exit 1
fi

if [[ "$GPUS" -gt 0 && "$ARCH" == "x64cpu" ]]; then
    print_error "Il n'y a pas de GPU disponible sur l'architecture x64cpu"
    exit 1
fi

# Variables globales
WORK_DIR="$PWD/jupyter_environments"
ENV_DIR="$WORK_DIR/$ENV_NAME"

# AMÉLIORATION: Possibilité de spécifier le répertoire de démarrage
if [[ -n "$CUSTOM_WORKDIR" ]]; then
    # Résoudre le chemin absolu
    if [[ "$CUSTOM_WORKDIR" = /* ]]; then
        JUPYTER_WORKSPACE="$CUSTOM_WORKDIR"
    else
        JUPYTER_WORKSPACE="$(pwd)/$CUSTOM_WORKDIR"
    fi
    print_info "Utilisation du répertoire de travail personnalisé: $JUPYTER_WORKSPACE"
else
    JUPYTER_WORKSPACE="$WORK_DIR/workspace_$ENV_NAME"
fi

JOB_SCRIPT="$WORK_DIR/jupyter_job_$ENV_NAME.sh"

if [ -z "$PROJET" ]; then
  read -p "Entrez le code du projet utilisé: " PROJET
fi

print_info "=== Configuration ==="
echo "Répertoire du script: $SCRIPT_DIR"
echo "Répertoire de travail: $WORK_DIR"
echo "Nom de l'environnement: $ENV_NAME"
echo "Architecture: $ARCH"
echo "Temps d'allocation: $SLURM_TIME"
echo "CPUs: $SLURM_CPUS"
echo "Mémoire: ${SLURM_MEMORY}GB"
echo "GPUs par nœud: $GPUS"
echo "PyTorch GPU: $PYTORCH_GPU"
echo "Répertoire de démarrage Jupyter: $JUPYTER_WORKSPACE"
echo "Code projet: $PROJET"
if [[ -n "$EXTRA_PACKAGES" ]]; then
    echo "Packages supplémentaires: $EXTRA_PACKAGES"
fi
echo
print_warning "Les ports seront choisis automatiquement sur le nœud de calcul"
echo

# Validation du dossier source pour la copie
if [[ -n "$COPY_FROM" ]]; then
    if [[ ! -d "$COPY_FROM" ]]; then
        print_error "Le dossier source '$COPY_FROM' n'existe pas"
        exit 1
    fi
    print_info "Copie de fichiers activée depuis: $COPY_FROM"
fi

# Création du répertoire de travail
print_info "Création du répertoire de travail..."
mkdir -p "$WORK_DIR"
mkdir -p "$JUPYTER_WORKSPACE"

# Vérifier si l'environnement existe déjà
if [[ -d "$ENV_DIR" ]]; then
    print_warning "L'environnement '$ENV_NAME' existe déjà."
    read -p "Voulez-vous le recréer ? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Suppression de l'environnement existant..."
        rm -rf "$ENV_DIR"
    else
        print_info "Utilisation de l'environnement existant..."
    fi
fi

# Copier les fichiers si demandé
if [[ -n "$COPY_FROM" ]]; then
    print_info "Copie des fichiers depuis '$COPY_FROM'..."
    FILE_COUNT=$(find "$COPY_FROM" -type f | wc -l)
    print_info "Nombre de fichiers à copier: $FILE_COUNT"

    if [[ $FILE_COUNT -gt 0 ]]; then
        cp -r "$COPY_FROM"/* "$JUPYTER_WORKSPACE/" 2>/dev/null || {
            print_warning "Certains fichiers n'ont pas pu être copiés"
            cp -r "$COPY_FROM"/.[^.]* "$JUPYTER_WORKSPACE/" 2>/dev/null || true
        }
        print_success "Fichiers copiés dans l'espace de travail Jupyter"
        COPIED_COUNT=$(find "$JUPYTER_WORKSPACE" -type f | wc -l)
        print_info "Fichiers copiés: $COPIED_COUNT"
    else
        print_warning "Aucun fichier trouvé dans le dossier source"
    fi
fi

# Créer le script de job Slurm
print_info "Création du script de job Slurm..."
cat > "$JOB_SCRIPT" << EOF
#!/bin/bash
#SBATCH --job-name=jupyter_$ENV_NAME
#SBATCH --time=$SLURM_TIME
#SBATCH --cpus-per-task=$SLURM_CPUS
#SBATCH --mem=${SLURM_MEMORY}GB
#SBATCH --output=$WORK_DIR/jupyter_%j.out
#SBATCH --error=$WORK_DIR/jupyter_%j.err
#SBATCH --account=$PROJET
#SBATCH --constraint=$ARCH
EOF

# Utilisation de --gpus-per-node (conforme ROMEO)
if [[ "$GPUS" -gt 0 ]]; then
    echo "#SBATCH --gpus-per-node=$GPUS" >> "$JOB_SCRIPT"
fi

cat >> "$JOB_SCRIPT" << 'JOBEOF'

# CORRECTION MAJEURE: Fonction pour vérifier si un port est libre SUR LE NŒUD DE CALCUL
check_node_port_available() {
    local port=$1
    
    if command -v netstat >/dev/null 2>&1; then
        if netstat -tuln 2>/dev/null | grep -q ":${port} "; then
            return 1  # Port occupé
        fi
    fi
    
    if command -v ss >/dev/null 2>&1; then
        if ss -tuln 2>/dev/null | grep -q ":${port} "; then
            return 1  # Port occupé
        fi
    fi
    
    return 0  # Port libre
}

# CORRECTION MAJEURE: Fonction pour trouver un port libre SUR LE NŒUD DE CALCUL
find_free_node_port() {
    local min_port=$1
    local max_port=$2
    local max_attempts=${3:-100}
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        # Utiliser shuf si disponible, sinon RANDOM
        if command -v shuf >/dev/null 2>&1; then
            local port=$(shuf -i ${min_port}-${max_port} -n 1)
        else
            local port=$((min_port + RANDOM % (max_port - min_port + 1)))
        fi
        
        if check_node_port_available "$port"; then
            echo "$port"
            return 0
        fi
        
        attempt=$((attempt + 1))
    done
    
    echo "Erreur: Impossible de trouver un port libre dans la plage ${min_port}-${max_port}" >&2
    return 1
}

# Charger l'environnement selon l'architecture
if [[ "ARCH_PLACEHOLDER" == "x64cpu" ]]; then
    romeo_load_x64cpu_env
    spack load python@3.13/wvvw4jo
elif [[ "ARCH_PLACEHOLDER" == "armgpu" ]]; then
    romeo_load_armgpu_env
    spack load python@3.13/wvvw4jo
fi

# Créer l'environnement s'il n'existe pas
if [[ ! -d "ENV_DIR_PLACEHOLDER" ]]; then
    echo "Création de l'environnement virtuel Python..."
    python -m venv "ENV_DIR_PLACEHOLDER"
fi

# Activer l'environnement virtuel
source "ENV_DIR_PLACEHOLDER/bin/activate"

# Mettre à jour pip
pip install --upgrade pip

# Installer JupyterLab s'il n'est pas déjà installé
if ! pip show jupyterlab > /dev/null 2>&1; then
    echo "Installation de JupyterLab..."
    pip install jupyterlab

    if [[ "PYTORCH_GPU_PLACEHOLDER" == "true" ]]; then
        echo "Installation de PyTorch avec support GPU..."
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126
    fi

    if [[ -n "EXTRA_PACKAGES_PLACEHOLDER" ]]; then
        echo "Installation des packages supplémentaires: EXTRA_PACKAGES_PLACEHOLDER"
        pip install EXTRA_PACKAGES_PLACEHOLDER
    fi
fi

# CORRECTION MAJEURE: Recherche des ports libres AU BON MOMENT (sur le nœud de calcul)
echo "=== Recherche de ports libres sur le nœud de calcul ==="
JUPYTER_PORT=$(find_free_node_port 8000 8999)
if [[ $? -ne 0 ]]; then
    echo "ERREUR: Impossible de trouver un port libre pour JupyterLab"
    exit 1
fi
echo "Port JupyterLab trouvé: $JUPYTER_PORT"

# CORRECTION: LOCAL_PORT n'a pas besoin d'être vérifié sur le nœud de calcul
# Il sera utilisé sur la machine locale de l'utilisateur
LOCAL_PORT=$JUPYTER_PORT
echo "Port local suggéré: $LOCAL_PORT (vous pouvez en choisir un autre libre sur votre machine)"

# Obtenir le nom du nœud
NODE_NAME=$(hostname)
echo ""
echo "=== INFORMATIONS DE CONNEXION ==="
echo "Nœud de calcul: $NODE_NAME"
echo "Port JupyterLab: $JUPYTER_PORT"
echo "Port local suggéré: $LOCAL_PORT"
echo "Répertoire de travail Jupyter: JUPYTER_WORKSPACE_PLACEHOLDER"
echo ""

# Créer le fichier de configuration Jupyter
mkdir -p ~/.jupyter
cat > ~/.jupyter/jupyter_lab_config.py << 'JUPYTEREOF'
c.ServerApp.allow_origin = '*'
c.ServerApp.allow_remote_access = True
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.open_browser = False
c.ServerApp.token = 'TOKEN_PLACEHOLDER'
c.ServerApp.password = ''
c.LabApp.check_for_updates_class = 'jupyterlab.NeverCheckForUpdate'
JUPYTEREOF

# Se déplacer dans le répertoire de travail Jupyter
cd "JUPYTER_WORKSPACE_PLACEHOLDER"

echo "Lancement de JupyterLab dans le répertoire: $(pwd)"
echo ""
echo "=== INSTRUCTIONS SSH ==="
echo "Dans un nouveau terminal LOCAL, exécutez:"
echo "ssh -N -L ${LOCAL_PORT}:${NODE_NAME}:${JUPYTER_PORT} \$USER@romeo1.univ-reims.fr"
echo ""
echo "Puis ouvrez votre navigateur à:"
echo "http://localhost:${LOCAL_PORT}/?token=TOKEN_PLACEHOLDER"
echo "=================================="
echo ""

# Créer un fichier avec les informations de connexion
cat > "WORK_DIR_PLACEHOLDER/connection_info_\$SLURM_JOB_ID.txt" << INFOEOF
NODE=$NODE_NAME
JUPYTER_PORT=$JUPYTER_PORT
LOCAL_PORT=$LOCAL_PORT
TOKEN=TOKEN_PLACEHOLDER
SSH_COMMAND=ssh -N -L ${LOCAL_PORT}:${NODE_NAME}:${JUPYTER_PORT} \$USER@romeo1.univ-reims.fr
BROWSER_URL=http://localhost:${LOCAL_PORT}/?token=TOKEN_PLACEHOLDER
INFOEOF

# Lancer JupyterLab avec le port trouvé dynamiquement sur le nœud
jupyter-lab --no-browser --port=${JUPYTER_PORT} --ip=0.0.0.0 --allow-root --NotebookApp.token='TOKEN_PLACEHOLDER' --NotebookApp.password=''
JOBEOF

# Substituer les variables dans le script
sed -i "s|ARCH_PLACEHOLDER|$ARCH|g" "$JOB_SCRIPT"
sed -i "s|ENV_DIR_PLACEHOLDER|$ENV_DIR|g" "$JOB_SCRIPT"
sed -i "s|PYTORCH_GPU_PLACEHOLDER|$PYTORCH_GPU|g" "$JOB_SCRIPT"
sed -i "s|EXTRA_PACKAGES_PLACEHOLDER|$EXTRA_PACKAGES|g" "$JOB_SCRIPT"
sed -i "s|JUPYTER_WORKSPACE_PLACEHOLDER|$JUPYTER_WORKSPACE|g" "$JOB_SCRIPT"
sed -i "s|TOKEN_PLACEHOLDER|$TOKEN|g" "$JOB_SCRIPT"
sed -i "s|WORK_DIR_PLACEHOLDER|$WORK_DIR|g" "$JOB_SCRIPT"

chmod +x "$JOB_SCRIPT"

# Soumission du job
print_info "Soumission du job Slurm..."
JOB_ID=$(sbatch "$JOB_SCRIPT" | grep -o '[0-9]\+')

if [[ -n "$JOB_ID" ]]; then
    print_success "Job soumis avec l'ID: $JOB_ID"
    print_info "Les ports seront automatiquement sélectionnés sur le nœud de calcul"
    print_info "Attente du démarrage du job..."

    ATTEMPTS=0
    MAX_ATTEMPTS=12

    while [[ $ATTEMPTS -lt $MAX_ATTEMPTS ]]; do
        JOB_STATE=$(squeue -j "$JOB_ID" -h -o "%T" 2>/dev/null || echo "COMPLETED")

        if [[ "$JOB_STATE" == "RUNNING" ]]; then
            print_success "Job en cours d'exécution !"
            break
        elif [[ "$JOB_STATE" == "PENDING" ]]; then
            ATTEMPTS=$((ATTEMPTS + 1))
            print_info "Job en attente... ($ATTEMPTS/$MAX_ATTEMPTS)"
            if [[ $ATTEMPTS -lt $MAX_ATTEMPTS ]]; then
                sleep 5
            fi
        else
            print_error "Le job a échoué (état: $JOB_STATE)"
            print_info "Consultez les logs: $WORK_DIR/jupyter_${JOB_ID}.err"
            exit 1
        fi
    done

    if [[ "$JOB_STATE" != "RUNNING" ]]; then
        print_error "Timeout: le job ne s'est pas lancé"
        exit 1
    fi

    sleep 5
    NODE_NAME=$(squeue -j "$JOB_ID" -h -o "%N")

    if [[ -n "$NODE_NAME" ]]; then
        print_success "JupyterLab démarre sur: $NODE_NAME"
        
        echo ""
        print_info "Pour connaître les ports exacts, consultez:"
        echo -e "${YELLOW}cat $WORK_DIR/connection_info_${JOB_ID}.txt${NC}"
        echo ""
        print_info "Ou suivez les logs en temps réel:"
        echo -e "${YELLOW}tail -f $WORK_DIR/jupyter_${JOB_ID}.out${NC}"
        echo ""
        print_info "Commandes utiles:"
        echo -e "- État: ${YELLOW}squeue --me${NC}"
        echo -e "- Arrêt: ${YELLOW}scancel $JOB_ID${NC}"
        echo ""
    fi
else
    print_error "Échec de la soumission du job"
    exit 1
fi
