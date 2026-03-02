#!/bin/bash

LOG_FILE="/home/jman/pistack/update.log"
BACKUP_DIR="/home/jman/pistack/backups"
DATE=$(date +%Y%m%d_%H%M%S)
START_TIME=$(date +%s)

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "========== Starting automated update =========="

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup configuration files only (not runtime data)
log "Creating backup..."
cd /home/jman/pistack
tar -czf "$BACKUP_DIR/pistack-$DATE.tar.gz" \
    docker-compose.yml \
    .env \
    homepage/services.yaml \
    homepage/widgets.yaml \
    homepage/settings.yaml \
    homepage/bookmarks.yaml \
    homepage/custom.js \
    homepage/custom.css \
    2>> "$LOG_FILE"

if [ $? -ne 0 ]; then
    log "ERROR: Backup failed, aborting update"
    exit 1
fi

log "Backup created: $BACKUP_DIR/pistack-$DATE.tar.gz"

# Update 4get
log "Updating 4get..."
cd /home/jman/4get

# Stash any uncommitted changes
git stash

# Fetch upstream
git fetch upstream 2>> "$LOG_FILE"

# Check if there are updates
BEHIND=$(git rev-list HEAD..upstream/master --count)

if [ "$BEHIND" -gt 0 ]; then
    log "4get is $BEHIND commits behind, updating..."
    
    # Try to merge
    git merge upstream/master --no-edit 2>> "$LOG_FILE"
    
    if [ $? -ne 0 ]; then
        log "ERROR: Merge conflict in 4get, aborting 4get update"
        git merge --abort
        git stash pop 2>/dev/null
        log "Continuing with current 4get version"
    else
        log "4get merged successfully, rebuilding..."
        
        # Try to build
        docker build --platform linux/arm64 -t 4get-arm:latest . >> "$LOG_FILE" 2>&1
        
        if [ $? -ne 0 ]; then
            log "ERROR: 4get build failed, reverting..."
            git reset --hard HEAD~1
            log "Reverted to previous 4get version"
        else
            log "4get rebuilt successfully"
            git push origin main 2>> "$LOG_FILE"
        fi
        
        git stash pop 2>/dev/null
    fi
else
    log "4get is up to date"
fi

# Update Docker containers
log "Updating Docker containers..."
cd /home/jman/pistack

# Pull latest images
log "Pulling latest images..."

# Get list of all services except fourget (bc it's not in the registry since it's manually compiled)
SERVICES=$(docker compose config --services | grep -v "^fourget$" | tr '\n' ' ')
log "Services to update: $SERVICES"

docker compose pull $SERVICES >> "$LOG_FILE" 2>&1

if [ $? -ne 0 ]; then
    log "ERROR: Failed to pull images, aborting container update"
    log "Containers remain running with current versions"
    exit 1
fi

# Stop containers
log "Stopping containers..."
docker compose down >> "$LOG_FILE" 2>&1

# Start with new images
log "Starting containers with updated images..."
docker compose up -d >> "$LOG_FILE" 2>&1

if [ $? -ne 0 ]; then
    log "ERROR: Failed to start containers, attempting rollback..."
    
    # Extract backup
    tar -xzf "$BACKUP_DIR/pistack-$DATE.tar.gz" -C /home/jman/pistack-restore
    cd /home/jman/pistack-restore
    docker compose up -d >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log "Rollback successful, services restored"
    else
        log "CRITICAL: Rollback failed, manual intervention required!"
        exit 1
    fi
else
    log "Containers started successfully"
fi

# Wait for services to be healthy
log "Waiting for services to stabilize..."
sleep 30

# Check if critical services are running
CRITICAL_SERVICES="pihole homepage gitea"
ALL_HEALTHY=true

for service in $CRITICAL_SERVICES; do
    if ! docker ps | grep -q "$service"; then
        log "WARNING: $service is not running"
        ALL_HEALTHY=false
    fi
done

if [ "$ALL_HEALTHY" = false ]; then
    log "WARNING: Some services failed to start, check manually"
fi

# Clean up old backups (keep last 7)
log "Cleaning up old backups..."
cd "$BACKUP_DIR"
ls -t pistack-*.tar.gz | tail -n +8 | xargs -r rm

# Clean up old Docker images
log "Cleaning up old Docker images..."
docker image prune -f >> "$LOG_FILE" 2>&1

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

log "========== Update completed =========="
log "Total duration: ${MINUTES}m ${SECONDS}s"
