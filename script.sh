# 1. Configurar IP fija en Netplan
cat << 'EOF' | sudo tee /etc/netplan/50-cloud-init.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp1s0:
      dhcp4: true
    enp2s0:
      dhcp4: false
      addresses:
        - 192.168.100.220/24
      routes:
        - to: default
          via: 192.168.100.1
      nameservers:
        addresses: [9.9.9.9, 149.112.112.112]
EOF
sudo netplan apply

# 2. Instalar servicios
sudo apt update
sudo apt install -y isc-dhcp-server bind9 bind9utils

# 3. Configurar Interfaz DHCP
sudo sed -i 's/INTERFACESv4=""/INTERFACESv4="enp2s0"/' /etc/default/isc-dhcp-server

# 4. Configurar DHCP (dhcpd.conf)
cat << 'EOF' | sudo tee /etc/dhcp/dhcpd.conf
default-lease-time 600;
max-lease-time 7200;
authoritative;

subnet 192.168.100.0 netmask 255.255.255.0 {
    option routers 192.168.100.1;
    option domain-name "fritcoin.local";
    option domain-name-servers 192.168.100.220;
}

subnet 192.168.150.0 netmask 255.255.255.0 {
    range 192.168.150.120 192.168.150.170;
    option routers 192.168.150.254;
    option domain-name "fritcoin.local";
    option domain-name-servers 192.168.100.220;
}

subnet 192.168.200.0 netmask 255.255.255.0 {
    option routers 192.168.200.8;
    option domain-name "fritcoin.local";
    option domain-name-servers 192.168.100.220;

    host SXbitcoinWindows11 {
        hardware ethernet 52:54:00:09:1A:18;
        fixed-address 192.168.200.20;
    }
    host SXethereumUbuntuDesktop {
        hardware ethernet 52:54:00:60:be:f0;
        fixed-address 192.168.200.40;
    }
    host SXinterUbuntuDesktop {
        hardware ethernet 52:54:00:4b:16:d2;
        fixed-address 192.168.200.120;
    }
}
EOF

# 5. Configurar Reenviadores DNS
cat << 'EOF' | sudo tee /etc/bind/named.conf.options
options {
        directory "/var/cache/bind";
        forwarders {
                9.9.9.9;
                149.112.112.112;
        };
        dnssec-validation auto;
        listen-on-v6 { any; };
};
EOF

# 6. Zonas DNS (named.conf.local)
cat << 'EOF' | sudo tee /etc/bind/named.conf.local
zone "fritcoin.local" { type master; file "/etc/bind/db.fritcoin.local"; };
zone "100.168.192.in-addr.arpa" { type master; file "/etc/bind/db.192.168.100"; };
zone "200.168.192.in-addr.arpa" { type master; file "/etc/bind/db.192.168.200"; };
EOF

# 7. Zona Directa
cat << 'EOF' | sudo tee /etc/bind/db.fritcoin.local
$TTL 604800
@ IN SOA giomarhugojunyijordi.fritcoin.local. root.fritcoin.local. ( 2 604800 86400 2419200 604800 )
@ IN NS giomarhugojunyijordi.fritcoin.local.
giomarhugojunyijordi IN A 192.168.100.220
@ IN MX 10 mail1.fritcoin.local.
@ IN MX 10 mail2.fritcoin.local.
@ IN MX 20 mail3.fritcoin.local.
mail1 IN A 192.168.100.20
mail2 IN A 192.168.100.21
mail3 IN A 192.168.100.22
ftp1 IN A 192.168.100.23
ftp2 IN A 192.168.100.24
ftp3 IN A 192.168.100.25
monero IN CNAME ftp2.fritcoin.local.
bitcoin IN A 192.168.200.20
cosmos IN CNAME bitcoin.fritcoin.local.
ethereum IN A 192.168.200.40
inter IN A 192.168.200.120
EOF

# 8. Zonas Inversas
cat << 'EOF' | sudo tee /etc/bind/db.192.168.100
$TTL 604800
@ IN SOA giomarhugojunyijordi.fritcoin.local. root.fritcoin.local. ( 1 604800 86400 2419200 604800 )
@ IN NS giomarhugojunyijordi.fritcoin.local.
220 IN PTR giomarhugojunyijordi.fritcoin.local.
20 IN PTR mail1.fritcoin.local.
21 IN PTR mail2.fritcoin.local.
22 IN PTR mail3.fritcoin.local.
23 IN PTR ftp1.fritcoin.local.
24 IN PTR ftp2.fritcoin.local.
25 IN PTR ftp3.fritcoin.local.
EOF

cat << 'EOF' | sudo tee /etc/bind/db.192.168.200
$TTL 604800
@ IN SOA giomarhugojunyijordi.fritcoin.local. root.fritcoin.local. ( 1 604800 86400 2419200 604800 )
@ IN NS giomarhugojunyijordi.fritcoin.local.
20 IN PTR bitcoin.fritcoin.local.
40 IN PTR ethereum.fritcoin.local.
120 IN PTR inter.fritcoin.local.
EOF

# 9. Reiniciar servicios
sudo systemctl restart isc-dhcp-server
sudo systemctl restart named
sudo systemctl status isc-dhcp-server --no-pager
sudo systemctl status named --no-pager
