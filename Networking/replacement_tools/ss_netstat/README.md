# NOSS - Netstat and SS replacement tool

## Description

POSIX compliant tool to replace netstat and ss tools. It is designed to be used in environments where netstat and ss tools are unavailable (e.g. embedded systems) as it does not require external dependencies.

## Usage

Default behavior is to display all IPv4/IPv6 connections (TCP, UDP, RAW), without resolving names. If at least one of the following arguments is specified, but no IP version is specified, then IPv4 is used by default.

### Arguments

```txt
-h, --help
    Print help and exit
-r, --resolve
    Resolve names
-p, --processes
    Display process information
-l, --listening
    Display only listening sockets
-t, --tcp
    Display TCP connections
-u, --udp
    Display UDP connections
-w, --raw
    Display RAW connections
-4, --ipv4
    Display only IPv4 connections
-6, --ipv6
    Display only IPv6 connections
```

### Run from memory

```bash
# Option 1 (recommended, if need to specify arguments)
sh <(curl -s http://10.10.10.10/noss.sh) -t -l -p

# Option 2
wget -qO- http://10.10.10.10/noss.sh | sh
```

## TODO

- [ ] Additional filters for connection states (ESTABLISHED, TIME_WAIT, etc.)
- [ ] Additional options:
  - [ ] Routing table (netstat -r)
  - [ ] Interface table (netstat -i)
  - [ ] ARP table (netstat -narp)
