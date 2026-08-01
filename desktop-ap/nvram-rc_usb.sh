# desktop-ap — Entware + Debian chroot

sda=""
sdb=""

for dev in /dev/sd*1; do
    label=$(blkid -s LABEL $dev | cut -d= -f2 | cut -d\" -f 2)

    case "$label" in
        sda)
            sda="$dev"
            ;;
        sdb)
            sdb="$dev"
            ;;
        *)
            echo "Unknown label $label on $dev, skipping" >> /tmp/FLOESS.LOG
            ;;
    esac
done

echo "Root device: $sda" >> /tmp/FLOESS.LOG
echo "Media device: $sdb" >> /tmp/FLOESS.LOG

mount -o noatime,nodiratime,commit=60 ${sda} /tmp/mnt/sda1
mount -o noatime,nodiratime,commit=60 ${sdb} /tmp/mnt/sdb1

/tmp/mnt/sda1/dd-wrt/etc/init.d/dd-wrt.sh start
