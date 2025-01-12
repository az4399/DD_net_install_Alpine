#!/bin/sh

# 验证当前是否为root权限
[ "$(id -u)" = "0" ] || { echo "Error: You must be root"; exit 1; }

# 自动选择源
rgeo=$(wget -qO- https://ipip.rehi.org/country_code || echo "FAILED")
if [ "$rgeo" = "FAILED" ]; then
    echo "Failed to detect country, using default mirror"
    repo=https://dl-cdn.alpinelinux.org/alpine/latest-stable
else
    if [ "$rgeo" = "CN" ]; then
        repo=https://mirrors.tuna.tsinghua.edu.cn/alpine/latest-stable
    else
        repo=https://dl-cdn.alpinelinux.org/alpine/latest-stable
    fi
fi

# 获取系统架构
arch=$(uname -m)
echo "系统平台：${arch}"

# 下载启动内核
wget -q ${repo}/releases/${arch}/netboot/vmlinuz-virt -O /boot/vmlinuz-netboot || { echo "Download failed!"; exit 1; }
wget -q ${repo}/releases/${arch}/netboot/initramfs-virt -O /boot/initramfs-netboot || { echo "Download failed!"; exit 1; }

# 生成ssh密钥
yes | ssh-keygen -t ed25519 -N '' -f KEY

# 上传ssh公钥，返回公钥直链，用于grub启动
ssh_key="$(curl -k -F "file=@KEY.pub" https://file.io | sed 's/.*"link":"//;s/".*//')"

# 创建grub启动文件
cat > /etc/grub.d/40_custom << EOF
#!/bin/sh
exec tail -n +3 \$0
menuentry 'Alpine' {
    linux /boot/vmlinuz-netboot alpine_repo="${repo}/main" modloop="${repo}/releases/${arch}/netboot/modloop-virt" modules="loop,squashfs" initrd="initramfs-netboot" console=tty0 ssh_key="${ssh_key}"
    initrd /boot/initramfs-netboot
}
EOF

if command -v grub-install >/dev/null 2>&1; then
    grub-mkconfig -o /boot/grub/grub.cfg
    grub-reboot Alpine
elif command -v grub2-install >/dev/null 2>&1; then
    grub2-mkconfig -o /boot/grub2/grub.cfg
    grub2-reboot Alpine
else
    echo "不支持当前系统"
    exit 1
fi

cat KEY
echo "请保存私钥，然后重启服务器继续安装"

read -p "重启服务器[y/n]：" reboot
if [ "${reboot}" = "y" ] || [ "${reboot}" = "yes" ] || [ "${reboot}" = "Y" ]; then
    reboot
fi
