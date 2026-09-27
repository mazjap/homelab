#!/bin/bash
#
# Weekly homelab backup + update (cron: Sundays at 3 AM).
#
# Everything is written to update.log and a single summary email is sent at
# the end, listing only what changed and what failed.
#
# Usage: auto-update.sh [--dry-run]
#   --dry-run  Fetch 4get and pull images, then report what would change.
#              Nothing is merged, rebuilt, or restarted, and no backup is made.

PISTACK_DIR="/mnt/pistack-data/pistack"
FOURGET_DIR="/mnt/pistack-data/4get"
LOG_FILE="$PISTACK_DIR/update.log"
BACKUP_DIR="$PISTACK_DIR/backups"
MAIL_TO="jordan.c4922@gmail.com"
LOG_MAX_LINES=10000

# Config files to back up before updating (runtime data is not included)
BACKUP_FILES=(
    docker-compose.yml
    .env
    auto-update.sh
    homepage/services.yaml
    homepage/widgets.yaml
    homepage/settings.yaml
    homepage/bookmarks.yaml
    homepage/custom.js
    homepage/custom.css
    4play/page-render.js
    4play/package.json
    4play/package-lock.json
)

DRY_RUN=false
[ "$1" = "--dry-run" ] && DRY_RUN=true

DATE=$(date +%Y%m%d_%H%M%S)
START_TIME=$(date +%s)

# Only one run at a time
exec 9>/tmp/pistack-auto-update.lock
if ! flock -n 9; then
    echo "auto-update.sh is already running" >&2
    exit 1
fi

# Keep the log from growing forever
if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt "$LOG_MAX_LINES" ]; then
    tail -n "$LOG_MAX_LINES" "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi

# From cron, send all output to the log only (so cron has nothing to email).
# When run by hand in a terminal, also show it on screen.
if [ -t 1 ]; then
    exec > >(tee -a "$LOG_FILE") 2>&1
else
    exec >> "$LOG_FILE" 2>&1
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

UPDATED=()
FAILED=()
NOTES=()
CHECKED_COUNT=0

updated() {
    UPDATED+=("$(printf '  %-22s %s' "$1" "$2")")
    log "UPDATED: $1 - $2"
}

failed() {
    FAILED+=("$(printf '  %-22s %s' "$1" "$2")")
    log "ERROR: $1 - $2"
}

note() {
    NOTES+=("  - $1")
    log "NOTE: $1"
}

send_report() {
    local status="Succeeded"
    [ ${#FAILED[@]} -gt 0 ] && status="Failed"

    local subject="Homelab Update $status"
    local updated_heading="Updated"
    if [ "$DRY_RUN" = true ]; then
        subject="[Dry run] $subject"
        updated_heading="Would update"
    fi

    local duration=$(( $(date +%s) - START_TIME ))

    {
        echo "To: $MAIL_TO"
        echo "Subject: $subject"
        echo "Content-Type: text/plain; charset=UTF-8"
        echo
        if [ ${#UPDATED[@]} -gt 0 ]; then
            echo "$updated_heading"
            printf '%s\n' "${UPDATED[@]}"
            echo
        fi
        if [ ${#FAILED[@]} -gt 0 ]; then
            echo "Failed"
            printf '%s\n' "${FAILED[@]}"
            echo
        fi
        if [ ${#NOTES[@]} -gt 0 ]; then
            echo "Notes"
            printf '%s\n' "${NOTES[@]}"
            echo
        fi
        if [ ${#UPDATED[@]} -eq 0 ] && [ ${#FAILED[@]} -eq 0 ]; then
            echo "Everything was already up to date."
            echo
        fi
        echo "Checked $CHECKED_COUNT services in $((duration / 60))m $((duration % 60))s on $(hostname)."
        echo "Full log: $LOG_FILE"
    } | /usr/sbin/sendmail -t

    log "Sent report: $subject"
    log "========== Update finished in $((duration / 60))m $((duration % 60))s =========="
}

# ---------------------------------------------------------------------------
# Backup
# ---------------------------------------------------------------------------

backup_configs() {
    if [ "$DRY_RUN" = true ]; then
        log "Dry run: skipping backup"
        return
    fi

    log "Creating backup..."
    mkdir -p "$BACKUP_DIR"

    local existing=()
    local f
    for f in "${BACKUP_FILES[@]}"; do
        if [ -e "$PISTACK_DIR/$f" ]; then
            existing+=("$f")
        else
            log "Backup: skipping missing file $f"
        fi
    done

    if ! tar -czf "$BACKUP_DIR/pistack-$DATE.tar.gz" -C "$PISTACK_DIR" "${existing[@]}"; then
        failed "backup" "could not create backup, update aborted"
        exit 1
    fi
    log "Backup created: $BACKUP_DIR/pistack-$DATE.tar.gz"

    # Keep the last 7 backups
    ls -t "$BACKUP_DIR"/pistack-*.tar.gz | tail -n +8 | xargs -r rm
}

# ---------------------------------------------------------------------------
# 4get (built locally from the fork, so it is not pulled)
# ---------------------------------------------------------------------------

update_4get() {
    log "Updating 4get..."
    if ! cd "$FOURGET_DIR"; then
        failed "4get" "repo not found at $FOURGET_DIR"
        return
    fi

    # Our ARM Dockerfile always wins merges (paired with .git/info/attributes)
    git config merge.ours.driver true

    # Stash any uncommitted changes (restored at the end)
    local stashed=false
    if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
        git stash && stashed=true
    fi

    local pre_merge merged=false behind=0
    pre_merge=$(git rev-parse HEAD)

    if git fetch upstream; then
        behind=$(git rev-list HEAD..upstream/master --count)
    else
        failed "4get" "could not fetch upstream"
    fi

    if [ "$behind" -gt 0 ]; then
        local dockerfile_changed
        dockerfile_changed=$(git log --oneline HEAD..upstream/master -- Dockerfile | wc -l)

        if [ "$DRY_RUN" = true ]; then
            updated "4get" "$behind upstream commits to merge, then rebuild"
            if [ "$dockerfile_changed" -gt 0 ]; then
                note "Upstream changed 4get's Dockerfile. Your ARM version will be kept; review with: git -C $FOURGET_DIR log -p HEAD..upstream/master -- Dockerfile"
            fi
        else
            log "4get is $behind commits behind, merging..."
            if git merge upstream/master --no-edit; then
                merged=true
                if [ "$dockerfile_changed" -gt 0 ]; then
                    note "Upstream changed 4get's Dockerfile. Your ARM version was kept; review with: git -C $FOURGET_DIR log -p ${pre_merge:0:7}..upstream/master -- Dockerfile"
                fi
            else
                local conflicts
                conflicts=$(git diff --name-only --diff-filter=U | paste -sd, - | sed 's/,/, /g')
                git merge --abort
                failed "4get" "merge conflict in ${conflicts:-unknown files}, kept current version"
            fi
        fi
    else
        log "4get is up to date with upstream"
    fi

    # Rebuild whenever the image wasn't built from the current commit. This
    # also catches manual merges, which would otherwise leave the image stale.
    local head_commit built_commit
    head_commit=$(git rev-parse HEAD)
    built_commit=$(docker image inspect 4get-arm:latest --format '{{ index .Config.Labels "fourget.commit" }}' 2>/dev/null)

    if [ "$head_commit" != "$built_commit" ]; then
        if [ "$DRY_RUN" = true ]; then
            [ "$behind" -eq 0 ] && updated "4get" "image would be rebuilt for ${head_commit:0:7} (repo changed since last build)"
        else
            log "4get image is from ${built_commit:-an unknown commit}, rebuilding for ${head_commit:0:7}..."
            if docker build --platform linux/arm64 --label "fourget.commit=$head_commit" -t 4get-arm:latest "$FOURGET_DIR"; then
                if [ "$merged" = true ]; then
                    updated "4get" "merged $behind upstream commits, image rebuilt (${head_commit:0:7})"
                    git push origin main || note "4get: could not push the merge to Gitea (origin)"
                else
                    updated "4get" "image rebuilt for ${head_commit:0:7} (repo changed since last build)"
                fi
            else
                if [ "$merged" = true ]; then
                    git reset --hard "$pre_merge"
                    failed "4get" "image build failed, merge reverted, kept current version"
                else
                    failed "4get" "image build failed, kept current version"
                fi
            fi
        fi
    else
        log "4get image matches ${head_commit:0:7}, no rebuild needed"
    fi

    if [ "$stashed" = true ]; then
        git stash pop || note "4get: could not restore stashed local changes (see git stash list)"
    fi
}

# ---------------------------------------------------------------------------
# Docker containers
# ---------------------------------------------------------------------------

declare -A SERVICE_IMAGE
declare -A PULL_RESULT

image_version() {
    local v
    v=$(docker image inspect --format '{{ index .Config.Labels "org.opencontainers.image.version" }}' "$1" 2>/dev/null)
    [ "$v" = "<no value>" ] && v=""
    echo "$v"
}

describe_change() {
    local old_version new_version
    old_version=$(image_version "$1")
    new_version=$(image_version "$2")

    if [ -n "$old_version" ] && [ -n "$new_version" ] && [ "$old_version" != "$new_version" ]; then
        echo "$old_version → $new_version"
    elif [ -n "$new_version" ]; then
        echo "new image (version $new_version)"
    else
        echo "new image"
    fi
}

# Pull one image, retrying so a transient registry error doesn't skip it
pull_image() {
    local image=$1 out attempt
    for attempt in 1 2 3; do
        if out=$(docker pull -q "$image" 2>&1); then
            PULL_RESULT[$image]="ok"
            return
        fi
        log "Pull attempt $attempt for $image failed: $(echo "$out" | tail -n 1)"
        [ "$attempt" -lt 3 ] && sleep $((attempt * 20))
    done
    PULL_RESULT[$image]=$(echo "$out" | tail -n 1 | cut -c 1-100)
}

update_containers() {
    log "Updating Docker containers..."
    cd "$PISTACK_DIR" || { failed "pistack" "directory not found"; return; }

    local services=() svc image
    while IFS=$'\t' read -r svc image; do
        services+=("$svc")
        SERVICE_IMAGE[$svc]=$image
    done < <(docker compose config --format json | python3 -c '
import json, sys
for name, svc in json.load(sys.stdin)["services"].items():
    print(name + "\t" + svc.get("image", ""))
')
    CHECKED_COUNT=${#services[@]}

    if [ "$CHECKED_COUNT" -eq 0 ]; then
        failed "docker compose" "could not read docker-compose.yml"
        return
    fi

    # Pull each image once (some are shared by several services)
    for svc in "${services[@]}"; do
        image=${SERVICE_IMAGE[$svc]}
        [ "$svc" = "fourget" ] && continue   # built locally by update_4get
        [ -z "$image" ] && continue
        [ -n "${PULL_RESULT[$image]}" ] && continue
        log "Pulling $image..."
        pull_image "$image"
    done

    # Compare what each container is running with what it will run next
    local cid running_id new_id
    for svc in "${services[@]}"; do
        [ "$svc" = "fourget" ] && continue   # reported by update_4get
        image=${SERVICE_IMAGE[$svc]}

        if [ "${PULL_RESULT[$image]}" != "ok" ]; then
            failed "$svc" "pull failed: ${PULL_RESULT[$image]}"
            continue
        fi

        cid=$(docker compose ps -a -q "$svc" | head -n 1)
        running_id=$(docker inspect --format '{{.Image}}' "$cid" 2>/dev/null)
        new_id=$(docker image inspect --format '{{.Id}}' "$image" 2>/dev/null)

        if [ -z "$running_id" ]; then
            note "$svc has no container yet, it will be created"
        elif [ "$running_id" != "$new_id" ]; then
            updated "$svc" "$(describe_change "$running_id" "$new_id")"
        fi
    done

    if [ "$DRY_RUN" = true ]; then
        log "Dry run: not restarting containers"
        return
    fi

    # Only containers whose image or config changed are recreated
    log "Starting containers with updated images..."
    if ! docker compose up -d; then
        failed "docker compose" "up -d failed, see $LOG_FILE"
    fi

    log "Waiting for services to stabilize..."
    sleep 30

    local state
    for svc in "${services[@]}"; do
        state=$(docker compose ps -a --format '{{.State}}' "$svc" | head -n 1)
        if [ "$state" != "running" ]; then
            failed "$svc" "not running after update (state: ${state:-no container})"
        fi
    done

    log "Cleaning up old Docker images..."
    docker image prune -f
}

# ---------------------------------------------------------------------------

trap send_report EXIT

if [ "$DRY_RUN" = true ]; then
    log "========== Starting automated update (dry run) =========="
else
    log "========== Starting automated update =========="
fi

backup_configs
update_4get
update_containers
