#!/bin/bash

#cleanups
umount d

set -ex

origin="$(readlink -f -- "$0")"
origin="$(dirname "$origin")"

[ ! -d vendor_vndk ] && git clone https://github.com/phhusson/vendor_vndk -b android-10.0

targetArch=64
[ "$1" == 32 ] && targetArch=32

[ -z "$ANDROID_BUILD_TOP" ] && ANDROID_BUILD_TOP=/home/eugw/havoc
if [ -f "$2" ]; then
    "$origin"/simg2img "$2" "$origin"/s.img
else
    if [ "$targetArch" == 32 ];then
        simg2img $ANDROID_BUILD_TOP/out/target/product/phhgsi_a64_ab/system.img s.img
    else
        simg2img $ANDROID_BUILD_TOP/out/target/product/phhgsi_arm64_ab/system.img s.img
    fi
fi
rm -Rf tmp
mkdir -p d tmp
e2fsck -y -f s.img
resize2fs s.img 4000M
e2fsck -E unshare_blocks -y -f s.img
mount -o loop,rw s.img d
(
cd d
for vndk in 28 29;do
    for arch in 32 64;do
        d="$origin/vendor_vndk/vndk-${vndk}-arm${arch}"
        [ ! -d "$d" ] && continue
        p=lib
        [ "$arch" = 64 ] && p=lib64
        [ ! -d system/system_ext/apex/com.android.vndk.v${vndk}/${p}/ ] && continue
        for lib in $(cd "$d"; echo *);do
            cp "$origin/vendor_vndk/vndk-${vndk}-arm${arch}/$lib" system/system_ext/apex/com.android.vndk.v${vndk}/${p}/$lib
            xattr -w security.selinux u:object_r:system_lib_file:s0 system/system_ext/apex/com.android.vndk.v${vndk}/${p}/$lib
            echo $lib >> system/system_ext/apex/com.android.vndk.v${vndk}/etc/vndkcore.libraries.${vndk}.txt
        done
        sort -u system/system_ext/apex/com.android.vndk.v${vndk}/etc/vndkcore.libraries.${vndk}.txt > v
        mv -f v system/system_ext/apex/com.android.vndk.v${vndk}/etc/vndkcore.libraries.${vndk}.txt
        xattr -w security.selinux u:object_r:system_file:s0 system/system_ext/apex/com.android.vndk.v${vndk}/etc/vndkcore.libraries.${vndk}.txt

        grep -v -e libgui.so -e libft2.so system/system_ext/apex/com.android.vndk.v${vndk}/etc/vndkprivate.libraries.${vndk}.txt > v
        mv -f v system/system_ext/apex/com.android.vndk.v${vndk}/etc/vndkprivate.libraries.${vndk}.txt
        xattr -w security.selinux u:object_r:system_file:s0 system/system_ext/apex/com.android.vndk.v${vndk}/etc/vndkprivate.libraries.${vndk}.txt
    done
done


)
sleep 1


umount d

e2fsck -f -y s.img || true
resize2fs -M s.img
