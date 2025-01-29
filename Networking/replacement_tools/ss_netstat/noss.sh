#!/bin/sh

# Make state code human-readable
socket_state() {
    case "$1" in
    "01") echo "ESTABLISHED" ;;
    "02") echo "SYN_SENT" ;;
    "03") echo "SYN_RECV" ;;
    "04") echo "FIN_WAIT1" ;;
    "05") echo "FIN_WAIT2" ;;
    "06") echo "TIME_WAIT" ;;
    "07") echo "CLOSE" ;;
    "08") echo "CLOSE_WAIT" ;;
    "09") echo "LAST_ACK" ;;
    "0A") echo "LISTEN" ;;
    "0B") echo "CLOSING" ;;
    "0C") echo "NEW_SYN_RECV" ;;
    *) echo "UNKNOWN" ;;
    esac
}

format_ip() {
    ip_len=$(printf "%s" "$1" | wc -c)

    if [ "$ip_len" -eq 8 ]; then
        echo "$1" | sed -r 's/(..)(..)(..)(..)/ 0x\4 0x\3 0x\2 0x\1/g' | xargs printf "%d.%d.%d.%d"
    else
        echo "$1" | sed 's/\(....\)/\1:/g' | sed 's/:$//' | sed -r 's/(:0000)+/::/g' | sed 's/0000:/::/' | sed 's/::::/::/' | sed 's/:::/::/'
    fi
}

ip_resolve() {
    resolved_ip=$(getent hosts "$1" | awk '{print $2}')
    echo "${resolved_ip:-$1}"  # If resolution fails, return original IP
}

# Parser for /proc/net/*
parse_proc_net() {
    file="$1"
    proto="$(basename "$1")"

    tail -n +2 "$file" | while read -r line; do
        if [ -n "$line" ]; then
            set -- $(echo "$line" | awk '{
                split($2, arr, ":");
                l_ip = arr[1];
                l_port = arr[2];

                split($3, arr, ":");
                r_ip = arr[1];
                r_port = arr[2];

                print $10, l_ip, l_port, r_ip, r_port, $4, $8;
            }')

            socket_inode="$1"
            l_ip="$2"
            l_port="$3"
            r_ip="$4"
            r_port="$5"
            state="$6"
            uid="$7"

            # Convert hex ports to decimal
            l_port=$(printf "%d" "0x$l_port")
            r_port=$(printf "%d" "0x$r_port")

            # Fix empty ports and IPs
            l_port=${l_port:-"-"}
            r_port=${r_port:-"-"}
            l_ip=${l_ip:-"-"}
            r_ip=${r_ip:-"-"}

            # Convert IP to readable format
            l_ip=$(format_ip "$l_ip")
            r_ip=$(format_ip "$r_ip")

            # Resolve IP if enabled
            if [ "$RESOLVE" -eq 1 ]; then
                l_ip=$(ip_resolve "$l_ip")
                r_ip=$(ip_resolve "$r_ip")
            fi

            state_readable="$(socket_state "$state")"

            usr="$(grep ":$uid:" /etc/passwd | cut -d: -f1)"
            usr=${usr:-"-"}

            # If SHOW_PROCESS is set, lookup the PID and command
            pid_cmd="-"
            if [ "$SHOW_PROCESS" -eq 1 ]; then
                pid_cmd=$(build_socket_lookup | grep "^$socket_inode:" | cut -d: -f2)
                pid_cmd=${pid_cmd:-"-"}
            fi

            usrData="$uid/$usr"

            printf "%-5s %-42s %-42s %-12s %-15s %-20s\n" "$proto" "$l_ip:$l_port" "$r_ip:$r_port" "$state_readable" "$usrData" "$pid_cmd"
        fi
    done
}

# Build an in-memory string for socket inode lookup
build_socket_lookup() {
    for pid in /proc/[0-9]*; do
        if [ -d "$pid/fd" ]; then
            for fd in "$pid/fd"/*; do
                rlnk=$(readlink "$fd" 2>/dev/null | grep socket || echo "")
                if [ "$rlnk" ]; then
                    socket=$(echo "$rlnk" | sed -n 's/.*socket:\[\([0-9]*\)\].*/\1/p')
                    cmd=$(tr '\0' ' ' <"$pid/cmdline" | awk '{print $1}')
                    cmd=${cmd:-"-"}
                    echo "$socket:${pid##*/}/$cmd"
                fi
            done
        fi
    done
}


main() {
    case "$SHOW_IPV4$SHOW_IPV6$SHOW_TCP$SHOW_UDP$SHOW_RAW" in
        "00000") output="" ;;
        "10100") output="$(parse_proc_net "/proc/net/tcp")" ;;
        "10010") output="$(parse_proc_net "/proc/net/udp")" ;;
        "10001") output="$(parse_proc_net "/proc/net/raw")" ;;
        "10110") output="$(parse_proc_net "/proc/net/tcp")\n$(parse_proc_net "/proc/net/udp")" ;;
        "10101") output="$(parse_proc_net "/proc/net/tcp")\n$(parse_proc_net "/proc/net/raw")" ;;
        "10011") output="$(parse_proc_net "/proc/net/udp")\n$(parse_proc_net "/proc/net/raw")" ;;
        "10111") output="$(parse_proc_net "/proc/net/tcp")\n$(parse_proc_net "/proc/net/udp")\n$(parse_proc_net "/proc/net/raw")" ;;
        "01100") output="$(parse_proc_net "/proc/net/tcp6")" ;;
        "01010") output="$(parse_proc_net "/proc/net/udp6")" ;;
        "01001") output="$(parse_proc_net "/proc/net/raw6")" ;;
        "01110") output="$(parse_proc_net "/proc/net/tcp6")\n$(parse_proc_net "/proc/net/udp6")" ;;
        "01101") output="$(parse_proc_net "/proc/net/tcp6")\n$(parse_proc_net "/proc/net/raw6")" ;;
        "01011") output="$(parse_proc_net "/proc/net/udp6")\n$(parse_proc_net "/proc/net/raw6")" ;;
        "01111") output="$(parse_proc_net "/proc/net/tcp6")\n$(parse_proc_net "/proc/net/udp6")\n$(parse_proc_net "/proc/net/raw6")" ;;
        "11100") output="$(parse_proc_net "/proc/net/tcp")\n$(parse_proc_net "/proc/net/tcp6")" ;;
        "11010") output="$(parse_proc_net "/proc/net/udp")\n$(parse_proc_net "/proc/net/udp6")" ;;
        "11001") output="$(parse_proc_net "/proc/net/raw")\n$(parse_proc_net "/proc/net/raw6")" ;;
        "11110") output="$(parse_proc_net "/proc/net/tcp")\n$(parse_proc_net "/proc/net/tcp6")\n$(parse_proc_net "/proc/net/udp")\n$(parse_proc_net "/proc/net/udp6")" ;;
        "11101") output="$(parse_proc_net "/proc/net/tcp")\n$(parse_proc_net "/proc/net/tcp6")\n$(parse_proc_net "/proc/net/raw")\n$(parse_proc_net "/proc/net/raw6")" ;;
        "11011") output="$(parse_proc_net "/proc/net/udp")\n$(parse_proc_net "/proc/net/udp6")\n$(parse_proc_net "/proc/net/raw")\n$(parse_proc_net "/proc/net/raw6")" ;;
        "11111") output="$(parse_proc_net "/proc/net/tcp")\n$(parse_proc_net "/proc/net/tcp6")\n$(parse_proc_net "/proc/net/udp")\n$(parse_proc_net "/proc/net/udp6")\n$(parse_proc_net "/proc/net/raw")\n$(parse_proc_net "/proc/net/raw6")" ;;
    esac

    printf "%-5s %-42s %-42s %-12s %-15s %-20s\n" \
        "Proto" "Local Address" "Foreign Address" "State" "UID/User" "PID/Program"

    printf "%-5s %-42s %-42s %-12s %-15s %-20s\n" \
        "-----" "------------------------------------------" "------------------------------------------" "------------" "---------------" "--------------------"


    if [ "$LISTENING" -eq 1 ]; then
        echo "$output" | grep "LISTEN" | sort -k 1,1 -k 2,2n -k 3,3n
    else
        echo "$output" | sort -k 1,1 -k 2,2n -k 3,3n
    fi
}

RESOLVE=0
SHOW_PROCESS=0
LISTENING=0
SHOW_TCP=0
SHOW_UDP=0
SHOW_IPV4=0
SHOW_IPV6=0
SHOW_RAW=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            cat <<EOF
Usage: $0 [options]
Options:
  -r, --resolve     Resolve IP addresses to hostnames
  -p, --process     Show associated process names
  -l, --listening   Show only listening sockets
  -t, --tcp         Show TCP connections
  -u, --udp         Show UDP connections
  -w, --raw         Show RAW connections
  -4, --ipv4        Show only IPv4 connections
  -6, --ipv6        Show only IPv6 connections
EOF
            exit 0
            ;;
        -r|--resolve) RESOLVE=1 ;;
        -p|--process) SHOW_PROCESS=1 ;;
        -l|--listening) LISTENING=1 ;;
        -t|--tcp) SHOW_TCP=1 ;;
        -u|--udp) SHOW_UDP=1 ;;
        -w|--raw) SHOW_RAW=1 ;;
        -4|--ipv4) SHOW_IPV4=1 ;;
        -6|--ipv6) SHOW_IPV6=1 ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
    shift
done

# Set default behavior if no arguments are specified
if [ "$SHOW_IPV4" -eq 0 ] && [ "$SHOW_IPV6" -eq 0 ]; then SHOW_IPV4=1; fi
if [ "$SHOW_TCP" -eq 0 ] && [ "$SHOW_UDP" -eq 0 ] && [ "$SHOW_RAW" -eq 0 ]; then
    SHOW_TCP=1
    SHOW_UDP=1
    SHOW_RAW=1
fi

main
