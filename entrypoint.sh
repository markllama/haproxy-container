#/bin/bash
#
# INPUTS
#  IFACE=$1
# or
#  COMAND=$@
#
# ENVIRONMENT
#  IP_PROTOCOL
#
set -ex

data_dir="/data"

#function parse_args() {
#    while getopts "$OPTSTRING" opt ; do
#
#    done
#}

function main() {
    local haproxy_conf="$data_dir/haproxy.conf"
    # Determine the interface
    local interface=$(get_interface $1)
    #
    check_data_dir $data_dir
    check_haproxy_conf $haproxy_conf
    set_ownership $data_dir

    # Hand over control to the DHCPD process
    $(run_cmd) /usr/sbin/haproxy \
               -f $haproxy_conf \
               -db \
               -V
}


function run_cmd() {
    # Support docker run --init parameter which obsoletes the use of dumb-init,
    # but support dumb-init for those that still use it without --init

    local run
    if [ -x "/dev/init" ]; then
        run="exec"
    else
        run="exec /usr/bin/dumb-init --"
    fi

    echo $run
}

function get_interface() {
    local IFACE
    # Single argument to command line is interface name
    if [ $# -eq 1 -a -n "$1" ]; then
        # skip wait-for-interface behavior if found in path
        if ! which "$1" >/dev/null; then
            # loop until interface is found, or we give up
            NEXT_WAIT_TIME=1
            until [ -e "/sys/class/net/$1" ] || [ $NEXT_WAIT_TIME -eq 4 ]; do
                sleep $(( NEXT_WAIT_TIME++ ))
                echo "Waiting for interface '$1' to become available... ${NEXT_WAIT_TIME}"
            done
            if [ -e "/sys/class/net/$1" ]; then
                IFACE="$1"
            fi
        fi
    fi
    echo $IFACE
}

# No arguments mean all interfaces
#if [ -z "$1" ]; then
#    IFACE=" "
#fi

#if [ -z "$IFACE" ]; then
#    # Run another binary
#    $run "$@"
#fi
    
# Run dhcpd for specified interface or all interfaces


function check_data_dir() {
    local data_dir=$1
    
    if [ ! -d "$data_dir" ]; then
        echo "Please ensure '$data_dir' folder is available."
        echo 'If you just want to keep your configuration in "data/", add -v "$(pwd)/data:/data" to the docker run command line.'
        exit 1
    fi
}

function check_haproxy_conf() {
    local haproxy_conf=$1
    
    if [ ! -r "$haproxy_conf" ]; then
        echo "Please ensure '$haproxy_conf' exists and is readable."
        echo "Run the container with arguments 'man haproxy.conf' if you need help with creating the configuration."
        exit 1
    fi
}


function set_ownership() {
    local data_dir=$1
    
    uid=$(stat -c%u "$data_dir")
    gid=$(stat -c%g "$data_dir")
    if [ $gid -ne 0 ]; then
        groupmod -g $gid haproxy
    fi
    if [ $uid -ne 0 ]; then
        usermod -u $uid haproxy
    fi
}


#---------------------------------------------------------------------------------------------
# MAIN
#---------------------------------------------------------------------------------------------



main $*
