# rbear

VPN over SSH using [sshuttle](https://github.com/sshuttle/sshuttle) with automatic reconnect and a macOS kill switch (pf firewall).

All traffic is routed through your server. If the tunnel drops, the kill switch blocks everything until it reconnects.

## Install

```bash
brew install sshuttle
```

## Setup

```bash
./rbear.sh configure
```

Edit `rbear.conf` and set your server IP.

## Usage

```bash
sudo ./rbear.sh start    # start VPN daemon
sudo ./rbear.sh stop     # stop VPN daemon
sudo ./rbear.sh status   # show status
./rbear.sh check         # IP leak test
```
