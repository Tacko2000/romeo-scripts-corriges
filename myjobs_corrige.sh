#!/bin/bash

# Script de monitoring des jobs SLURM avec visualisation graphique
# Créé par le Centre de calcul ROMEO, avec assistance IA
# Amélioré selon les consignes du cours du 01-12-2025
# Corrections:
#   - Parsing corrigé des CPU_IDs (bug du code commenté résolu)
#   - Regroupement par APU/architecture

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Caractères pour la visualisation
CORE_FREE="."
CORE_USED="■"
GPU_FREE="○"
GPU_USED="●"

# Fonction pour afficher l'en-tête
print_header() {
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}                           MONITORING DES JOBS SLURM                           ${NC}"
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Fonction pour obtenir les informations d'un noeud
get_node_info() {
    local node_name=$1
    local node_info=$(scontrol show node "$node_name" 2>/dev/null)

    if [ $? -eq 0 ]; then
        local total_cores=$(echo "$node_info" | grep -oP 'CPUTot=\K\d+')
        local total_gpus=$(echo "$node_info" | grep -oP 'Gres=gpu:[^:]*:\K\d+' || echo "0")
        local features=$(echo "$node_info" | grep -oP 'AvailableFeatures=\K[^[:space:]]+' || echo "unknown")

        echo "$total_cores:$total_gpus:$features"
    else
        echo "0:0:unknown"
    fi
}

# CORRECTION 1: Fonction améliorée pour parser les CPU_IDs
parse_cpu_ids() {
    local cpu_ids=$1
    local cpu_list=""
    
    # Séparer par les virgules
    IFS=',' read -ra RANGES <<< "$cpu_ids"
    for range in "${RANGES[@]}"; do
        if [[ $range == *"-"* ]]; then
            # Range format: "0-19"
            local start=$(echo $range | cut -d'-' -f1)
            local end=$(echo $range | cut -d'-' -f2)
            for ((i=start; i<=end; i++)); do
                cpu_list="${cpu_list}${i},"
            done
        else
            # Single CPU: "7"
            cpu_list="${cpu_list}${range},"
        fi
    done
    
    # Retirer la virgule finale
    echo "${cpu_list%,}"
}

# Fonction pour parser les GPU GRES (ex: "gpu:h100:1(IDX:0)")
parse_gpu_gres() {
    local gres=$1
    echo "$gres" | grep -oP 'gpu:[^:]*:\K\d+' || echo "0"
}

# Fonction pour obtenir les ressources allouées d'un job par nœud
get_job_node_allocation() {
    local jobid=$1
    local job_details=$(scontrol show jobid -dd "$jobid" 2>/dev/null)

    if [ $? -ne 0 ]; then
        echo ""
        return
    fi

    # Parser les lignes "Nodes=..." pour obtenir les allocations par nœud
    echo "$job_details" | grep -E "^\s*Nodes=" | while read -r line; do
        local node_name=$(echo "$line" | grep -oP 'Nodes=\K[^[:space:]]+')
        local cpu_ids=$(echo "$line" | grep -oP 'CPU_IDs=\K[^[:space:]]+')
        local gres=$(echo "$line" | grep -oP 'GRES=\K[^[:space:]]+' || echo "")

        local allocated_cores=$(parse_cpu_ids "$cpu_ids")
        local allocated_gpus=$(parse_gpu_gres "$gres")

        echo "$node_name:$allocated_cores:$allocated_gpus"
    done
}

# Fonction pour visualiser un noeud
visualize_node() {
    local node_name=$1
    local allocated_cores=$2
    local allocated_gpus=$3
    local total_cores=$4
    local total_gpus=$5
    
    echo -e "\n    ${BOLD}${CYAN}┌─ $node_name ─$(printf '─%.0s' $(seq 1 $((26 - ${#node_name}))))┐${NC}"

    # Affichage des coeurs
    local core_line="    ${CYAN}│${NC} Coeurs: "
    local cores_per_line=20
    local line_count=0

    # CORRECTION 2: Conversion correcte de la chaîne CSV en array
    IFS=',' read -ra allocated_cores_array <<< "$allocated_cores"
    
    for ((i=0; i<total_cores; i++)); do
        # Vérifier si le core i est dans la liste allouée
        local is_allocated=0
        for core in "${allocated_cores_array[@]}"; do
            if [[ "$core" == "$i" ]]; then
                is_allocated=1
                break
            fi
        done
        
        if [[ $is_allocated -eq 1 ]]; then
            core_line+="${GREEN}${CORE_USED}${NC}"
        else
            core_line+="${CORE_FREE}"
        fi

        line_count=$((line_count + 1))
        if [ $line_count -eq $cores_per_line ] && [ $i -lt $((total_cores - 1)) ]; then
            core_line+=" ${CYAN}│${NC}\n    ${CYAN}│${NC}         "
            line_count=0
        fi
    done

    # Compléter la ligne avec des espaces si nécessaire
    local remaining_space=$((cores_per_line - line_count))
    if [ $line_count -gt 0 ] && [ $remaining_space -gt 0 ]; then
        core_line+="$(printf ' %.0s' $(seq 1 $remaining_space))"
    fi
    core_line+=" ${CYAN}│${NC}"

    echo -e "$core_line"

    # Affichage des GPUs si présents
    if [ $total_gpus -gt 0 ]; then
        local gpu_line="    ${CYAN}│${NC} GPUs  : "
        for ((i=1; i<=total_gpus; i++)); do
            if [ $i -le $allocated_gpus ]; then
                gpu_line+="${YELLOW}${GPU_USED}${NC} "
            else
                gpu_line+="${GPU_FREE} "
            fi
        done

        # Compléter avec des espaces
        local gpu_spaces=$((cores_per_line - total_gpus * 2))
        gpu_line+="$(printf ' %.0s' $(seq 1 $gpu_spaces)) ${CYAN}│${NC}"
        echo -e "$gpu_line"
    fi

    echo -e "    ${CYAN}└$(printf '─%.0s' $(seq 1 30))┘${NC}"
}

# Fonction pour obtenir le statut coloré
get_colored_status() {
    local status=$1
    case $status in
        "RUNNING") echo -e "${GREEN}$status${NC}" ;;
        "PENDING") echo -e "${YELLOW}$status${NC}" ;;
        "COMPLETED") echo -e "${BLUE}$status${NC}" ;;
        "FAILED") echo -e "${RED}$status${NC}" ;;
        "CANCELLED") echo -e "${PURPLE}$status${NC}" ;;
        *) echo "$status" ;;
    esac
}

# Fonction pour formater la durée
format_duration() {
    local duration=$1
    echo "$duration"
}

# AMÉLIORATION: Fonction pour regrouper les nœuds par APU/architecture
group_nodes_by_apu() {
    local allocations="$1"
    declare -A apu_groups
    
    # Grouper par feature/APU
    while IFS= read -r allocation; do
        if [ -z "$allocation" ]; then
            continue
        fi
        
        local node=$(echo "$allocation" | cut -d: -f1)
        local node_info=$(get_node_info "$node")
        local features=$(echo "$node_info" | cut -d: -f3)
        
        if [[ -z "${apu_groups[$features]}" ]]; then
            apu_groups[$features]="$allocation"
        else
            apu_groups[$features]="${apu_groups[$features]}|$allocation"
        fi
    done <<< "$allocations"
    
    # Retourner les groupes
    for apu in "${!apu_groups[@]}"; do
        echo "APU:$apu:${apu_groups[$apu]}"
    done
}

# Fonction principale
main() {
    print_header

    # Vérifier que SLURM est disponible
    if ! command -v squeue &> /dev/null; then
        echo -e "${RED}Erreur: SLURM n'est pas disponible ou squeue n'est pas dans le PATH${NC}"
        exit 1
    fi

    # Obtenir les jobs de l'utilisateur courant
    local user=$(whoami)
    local jobs=$(squeue -u "$user" -h -o "%i|%j|%V|%D|%C|%m|%l|%P|%T|%f|%R")

    if [ -z "$jobs" ]; then
        echo -e "${YELLOW}Aucun job trouvé pour l'utilisateur $user${NC}"
        exit 0
    fi

    echo -e "${BOLD}Utilisateur: $user${NC}\n"

    # Traiter chaque job
    while IFS='|' read -r jobid name submit_time nodes cores memory time_limit partition status features nodelist; do
        if [ -z "$jobid" ]; then continue; fi

        echo -e "${BOLD}${CYAN}Job ID: $jobid${NC}"
        echo -e "  Nom: $name"
        echo -e "  Date de soumission: $submit_time"
        echo -e "  Nombre de noeuds: $nodes"

        # Obtenir plus d'informations détaillées du job
        local job_details=$(scontrol show job "$jobid" 2>/dev/null)
        if [ $? -eq 0 ]; then
            local tres=$(echo "$job_details" | grep -oP 'TresPerNode=\K[^[:space:]]*' || echo "")
            local gpus_per_node="0"

            # Extraire le nombre de GPUs
            if [[ $tres == *"gpu:"* ]]; then
                gpus_per_node=$(echo "$tres" | grep -oP 'gpu:\K\d+' || echo "0")
            fi
        fi

        echo -e "  Durée MAX: $(format_duration "$time_limit")"
        echo -e "  Partition: $partition"
        echo -e "  Status: $(get_colored_status "$status")"
        echo -e "  Contraintes: ${features:-"Aucune"}"

        # AMÉLIORATION: Visualisation avec regroupement par APU
        if [ "$status" = "RUNNING" ] && [ ! -z "$nodelist" ] && [ "$nodelist" != "(null)" ]; then
            echo -e "\n${BOLD}${GREEN}Visualisation des ressources allouées (regroupées par APU):${NC}"

            # Obtenir les allocations réelles par nœud
            local node_allocations=$(get_job_node_allocation "$jobid")
            if [ ! -z "$node_allocations" ]; then
                # Regrouper par APU
                local grouped=$(group_nodes_by_apu "$node_allocations")
                
                # Afficher par groupe APU
                local current_apu=""
                while IFS= read -r group_line; do
                    if [[ $group_line == APU:* ]]; then
                        local apu=$(echo "$group_line" | cut -d: -f2)
                        local allocations=$(echo "$group_line" | cut -d: -f3-)
                        
                        if [[ "$current_apu" != "$apu" ]]; then
                            current_apu="$apu"
                            echo -e "\n  ${BOLD}${PURPLE}╔═══ Architecture: $apu ═══╗${NC}"
                        fi
                        
                        # Traiter chaque allocation dans ce groupe
                        IFS='|' read -ra alloc_items <<< "$allocations"
                        for item in "${alloc_items[@]}"; do
                            if [ ! -z "$item" ]; then
                                local node=$(echo "$item" | cut -d: -f1)
                                local alloc_cores=$(echo "$item" | cut -d: -f2)
                                local alloc_gpus=$(echo "$item" | cut -d: -f3)

                                # Obtenir les informations totales du nœud
                                local node_info=$(get_node_info "$node")
                                local total_cores=$(echo "$node_info" | cut -d: -f1)
                                local total_gpus=$(echo "$node_info" | cut -d: -f2)

                                visualize_node "$node" "$alloc_cores" "$alloc_gpus" "$total_cores" "$total_gpus"
                            fi
                        done
                    fi
                done <<< "$grouped"
            else
                echo -e "  ${YELLOW}Impossible d'obtenir les détails d'allocation pour ce job${NC}"
            fi
        fi

        echo -e "\n${BOLD}────────────────────────────────────────────────────────────────${NC}\n"

    done <<< "$jobs"

    echo -e "${BOLD}${BLUE}Légende:${NC}"
    echo -e "  ${CORE_FREE} = Coeur libre    ${GREEN}${CORE_USED}${NC} = Coeur alloué"
    echo -e "  ${GPU_FREE} = GPU libre     ${YELLOW}${GPU_USED}${NC} = GPU alloué"
    echo ""
}

# Exécution du script principal
main "$@"
