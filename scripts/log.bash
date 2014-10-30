# common functions

log() {
    NOW=$(date +"%Y%m%d%H%M%S")
    echo [${NOW}] [${1}] $2
}

error() {
    NOW=$(date +"%Y%m%d%H%M%S")
    >&2 echo [${NOW}] [${1}] $2
}
