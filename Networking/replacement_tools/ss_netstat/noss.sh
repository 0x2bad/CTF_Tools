#!/bin/sh

# Function for converting a state hex code into a human-readable state
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

# Function to handle IPv4 and IPv6 IP conversion
format_ip() {
    if [ "$(expr "$1" : '.*')" -eq 8 ]; then
        echo "$1" | sed -E 's/(..)(..)(..)(..)/ 0x\4 0x\3 0x\2 0x\1/g' | xargs printf "%d.%d.%d.%d"
    else
        echo "$1" | sed 's/\(....\)/\1:/g' | sed 's/:$//' | sed -E 's/(:0000)+/::/g' | sed 's/0000:/::/' | sed 's/::::/::/' | sed 's/:::/::/'
    fi
}

# Function for resolving IP to hostname
ip_resolve() {
    if getent hosts "$1" >/dev/null; then
        getent hosts "$1" | awk '{print $2}'
    else
        echo "$1"
    fi
}

# Function for parsing /proc/net/tcp, /proc/net/tcp6, /proc/net/udp, /proc/net/udp6, /proc/net/raw, and /proc/net/raw6
parse_proc_net() {
    file="$1"
    proto="$(basename "$1")"

    # Process each line
    tail -n +2 "$file" | while read -r line; do
        if [ -n "$line" ]; then
            # Using awk to extract necessary fields
            read -r socket_inode l_ip l_port r_ip r_port state uid <<EOF
$(echo "$line" | awk '{
    # Convert hex IP to decimal IP
    split($2, arr, ":");
    l_ip = arr[1];
    l_port = strtonum("0x" arr[2]);

    split($3, arr, ":");
    r_ip = arr[1];
    r_port = strtonum("0x" arr[2]);

    # Extract other fields
    print $10, l_ip, l_port, r_ip, r_port, $4, $8;
}')
EOF

            # Set the port to '*' if it exists and is 0, otherwise set it to '-'
            if [ "$l_port" -eq 0 ]; then l_port="*"; fi
            if [ "$r_port" -eq 0 ]; then r_port="*"; fi
            if [ -z "$l_port" ]; then l_port="-"; fi
            if [ -z "$r_port" ]; then r_port="-"; fi

            # Convert IP to human readable format if it exists, otherwise set it to '-'
            l_ip=$(format_ip "$l_ip")
            r_ip=$(format_ip "$r_ip")
            if [ -z "$l_ip" ]; then l_ip="-"; fi
            if [ -z "$r_ip" ]; then r_ip="-"; fi

            # Convert IP to hostname if NUMERIC is not set
            if [ "$RESOLVE" -eq 1 ]; then
                l_ip=$(ip_resolve "$l_ip")
                r_ip=$(ip_resolve "$r_ip")
            fi

            state_readable="$(socket_state "$state")"
            if [ -z "$state" ]; then state="-"; fi

            usr="$(grep ":$uid:" /etc/passwd | cut -d: -f1)"
            if [ -z "$usr" ]; then usr="-"; fi

            # If SHOW_PROCESS is set, lookup the PID and command
            pid_cmd='-' # Default to '-' if SHOW_PROCESS is not set
            if [ "$SHOW_PROCESS" -eq 1 ]; then
                pid_cmd=$(build_socket_lookup | grep "^$socket_inode:" | cut -d: -f2)
                if [ -z "$pid_cmd" ]; then pid_cmd='-'; fi # Reset to '-' if the PID is not found
            fi

            usrData="$uid/$usr"

            printf "%-5s %-25s %-25s %-15s %-15s %-13s\n" "$proto" "$l_ip:$l_port" "$r_ip:$r_port" "$state_readable" "$usrData" "$pid_cmd"
        fi
    done
}

# Function to build an in-memory string for socket inode lookup
build_socket_lookup() {
    socket_lookup=""
    for pid in /proc/[0-9]*; do                      # Loop through each directory in /proc that has a numeric name (representing a PID)
        if [ -d "$pid/fd" ]; then                    # Check if the process has a 'fd' directory (file descriptors)
            for fd in "$pid/fd"/*; do                # Loop through each file descriptor link in the 'fd' directory
                rlnk=$(readlink "$fd" | grep socket) # Check if the link is a socket
                if [ "$rlnk" ]; then
                    # If the link is a socket, extract the socket inode and store it in the in-memory string
                    socket=$(echo "$rlnk" | sed -n 's/.*socket:\[\([0-9]*\)\].*/\1/p')
                    # Also store the PID and command in the in-memory string
                    cmd=$(basename "$(tr '\0' ' ' <"$pid/cmdline" | awk '{print $1}')")
                    # The in-memory string is formatted as: socket_inode:pid/cmd
                    socket_lookup="$socket_lookup$socket:${pid##*/}/$cmd\n"
                fi
            done
        fi
    done
    echo "$socket_lookup"
}

main() {
    # Parse relevant files
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

    # Display the output
    printf "%-5s %-25s %-25s %-15s %-15s %-13s\n" "Proto" "Local Address" "Foreign Address" "State" "UID/User" "PID/Program name"
    if [ "$LISTENING" -eq 1 ]; then
        echo "$output" | sort -k 1,1 -k 2,2n -k 3,3n | grep "LISTEN"
    else
        echo "$output" | sort -k 1,1 -k 2,2n -k 3,3n
    fi
}

# Variables to control behavior based on arguments
RESOLVE=0
SHOW_PROCESS=0
LISTENING=0
SHOW_TCP=0
SHOW_UDP=0
SHOW_IPV4=0
SHOW_IPV6=0
SHOW_RAW=0

# Argument parsing
while [ "$#" -gt 0 ]; do
    case "$1" in
    -h | --help)
        echo "Usage: $0 [-r|--resolve] [-p|--process] [-l|--listening] [-t|--tcp] [-u|--udp] [-w|--raw] [-4|--ipv4] [-6|--ipv6]"
        exit 0
        ;;
    -r | --resolve) RESOLVE=1 ;;
    -p | --process) SHOW_PROCESS=1 ;;
    -l | --listening) LISTENING=1 ;;
    -t | --tcp) SHOW_TCP=1 ;;
    -u | --udp) SHOW_UDP=1 ;;
    -w | --raw) SHOW_RAW=1 ;;
    -4 | --ipv4) SHOW_IPV4=1 ;;
    -6 | --ipv6) SHOW_IPV6=1 ;;
    *)
        echo "Unknown argument: $1"
        exit 1
        ;;
    esac
    shift
done

# Set default behavior if no arguments are specified
case "$NUMERIC$RESOLVE$SHOW_PROCESS$LISTENING$SHOW_TCP$SHOW_UDP$SHOW_RAW$SHOW_IPV4$SHOW_IPV6" in
"000000000")
    SHOW_TCP=1
    SHOW_UDP=1
    SHOW_RAW=1
    SHOW_IPV4=1
    SHOW_IPV6=1
    ;;
esac

# Set default behavior if no arguments are specified
case "$SHOW_IPV4$SHOW_IPV6" in
"00") SHOW_IPV4=1 ;;
esac

# Set default behavior if no arguments are specified
case "$SHOW_TCP$SHOW_UDP$SHOW_RAW" in
"000")
    SHOW_TCP=1
    SHOW_UDP=1
    SHOW_RAW=1
    ;;
esac

main
