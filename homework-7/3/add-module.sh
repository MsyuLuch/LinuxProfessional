#!/bin/bash

mkdir /usr/lib/dracut/modules.d/01test
cd /usr/lib/dracut/modules.d/01test
cat >module-setup.sh<<EOF

#------------------------------------------------
#!/bin/bash

check() {
     return 0
}
depends() {
     return 0
}
install() {
     inst_hook cleanup 00 "/usr/lib/dracut/modules.d/01test/test.sh"
}
#------------------------------------------------
EOF

cat >test.sh<<EOF
#------------------------------------------------
#!/bin/bash
exec 0<>/dev/console 1<>/dev/console 2<>/dev/console
cat <<'msgend'
 ___________________
< I'm dracut module >
 -------------------
    \
     \
        .--.
       |o_o |
       |:_/ |
      //   \ \
     (|     | )
    /'\_   _/`\
    \___)=(___/
msgend
sleep 10
echo " continuing...."
#------------------------------------------------
EOF

chmod +x test.sh && chmod +x module-setup.sh
dracut -f -v
lsinitrd -m /boot/initramfs-$(uname -r).img | grep test
