# ---------------------------------------------------------------------

sda1=`blkid | grep root | cut -f 1 -d ':'`

mkdir -p /tmp/mnt/sda1
mount ${sda1} -o defaults,noatime,nodiratime,commit=60 /tmp/mnt/sda1

# ---------------------------------------------------------------------

/tmp/mnt/sda1/dd-wrt/etc/init.d/dd-wrt.sh start

# ---------------------------------------------------------------------
