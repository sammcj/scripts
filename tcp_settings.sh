sysctl net.ipv4.tcp_timestamps > tcpsettings.txt
sysctl net.ipv4.tcp_sack >> tcpsettings.txt
sysctl net.ipv4.tcp_low_latency >> tcpsettings.txt
sysctl net.ipv4.tcp_window_scaling >> tcpsettings.txt
sysctl net.ipv4.tcp_dsack >> tcpsettings.txt
sysctl net.ipv4.tcp_tw_reuse >> tcpsettings.txt
sysctl net.ipv4.tcp_tw_recycle >> tcpsettings.txt
sysctl net.core.netdev_max_backlog >> tcpsettings.txt
sysctl net.core.rmem_max >> tcpsettings.txt
sysctl net.core.wmem_max >> tcpsettings.txt
sysctl net.core.rmem_default >> tcpsettings.txt
sysctl net.core.wmem_default >> tcpsettings.txt
sysctl net.core.optmem_max >> tcpsettings.txt
sysctl net.ipv4.tcp_rmem >> tcpsettings.txt
sysctl net.ipv4.tcp_wmem >> tcpsettings.txt

cat tcpsettings.txt