#!/usr/bin/env bash
# AUTHOR: gotbletu <gotbletu@gmail.com>
# SOCIAL: https://www.youtube.com/user/gotbletu|https://github.com/gotbletu|https://twitter.com/gotbletu
# DESC:   easy samba server setup
# DEMO:   https://youtu.be/HGO4lqh0LN8
# CTR:    Abhinav Kulshreshtha (https://github.com/Abhinav1217)
#         Damian Rath (https://github.com/damianrath)
# REFF:   https://www.digitalocean.com/community/tutorials/how-to-set-up-a-samba-share-for-a-small-organization-on-ubuntu-16-04
#         https://askubuntu.com/questions/88108/samba-share-read-only-for-guests-read-write-for-authenticated-users
#         https://getsol.us/articles/software/samba/en/

# check for sudo access
if [ "$(id -u)" != "0" ]; then
  echo "Sorry, you need to run this with sudo."
  exit 1
fi

Color_Off='\e[0m'
Black='\e[0;30m'
Red='\e[0;31m'
Green='\e[0;32m'
Yellow='\e[0;33m'
Blue='\e[0;34m'
Purple='\e[0;35m'
Cyan='\e[0;36m'
White='\e[0;37m'

# install required packages
find_pkm() { for i;do command -v "$i" > /dev/null 2>&1 && { echo "$i"; return 0;};done;return 1; }
PKMGR=$(find_pkm apt apt-get aptitude dnf emerge eopkg pacman zypper)
if [ "$PKMGR" = "apt" ]; then
  apt update
  apt install -y samba coreutils sed gawk
elif [ "$PKMGR" = "apt-get" ]; then
  apt-get update
  apt-get install --no-install-recommends -y samba coreutils sed gawk
elif [ "$PKMGR" = "aptitude" ]; then
  aptitude update
  aptitude install --without-recommends -y samba coreutils sed gawk
elif [ "$PKMGR" = "dnf" ]; then
  dnf check-update
  dnf install -y samba coreutils sed gawk
elif [ "$PKMGR" = "emerge" ]; then
  emerge --sync
  emerge samba coreutils sed gawk
elif [ "$PKMGR" = "eopkg" ]; then
  eopkg update-repo
  eopkg install samba coreutils sed gawk
elif [ "$PKMGR" = "pacman" ]; then
  pacman -Syy
  pacman --noconfirm -S samba coreutils sed gawk
elif [ "$PKMGR" = "zypper" ]; then
  zypper refresh
  zypper install -y samba coreutils sed gawk
fi

printf "\n"

SMB_CONFIG="/etc/samba/smb.conf"
#[ -f "$SMB_CONFIG" ] && cp "$SMB_CONFG"{,.backup}   # create backup config
cp smb.conf "$SMB_CONFIG"

echo -e "${Green}create save directory (e.g /media/data/samba, do not use home directory e.g /home/user/):${Color_Off}"
echo -e "${Green}>>>Note<<< directory path will auto be created if path does not exist${Color_Off}"
read -r -e SAVEDIR
SAVEDIR=$(echo "$SAVEDIR" | sed 's/\/*$//g') # remove trailing slashes in path
mkdir -p "$SAVEDIR"
sed -i 's@MYSAVEDIR@'"$SAVEDIR"'@g' "$SMB_CONFIG"

echo -e "${Green}create name for your samba server share (e.g batmansmb):${Color_Off}"
read -r SERVERNAME
sed -i "s/MYSERVERNAME/$SERVERNAME/g" "$SMB_CONFIG"

# create group has all users including guest users
GROUPNAME=sambashare
groupadd "$GROUPNAME"
chown :"$GROUPNAME" "$SAVEDIR"

# create group has all normal users but not including guest users
GROUPNAME_USERS=smbusers
groupadd "$GROUPNAME_USERS"

# create admins group
GROUPNAME_ADMINS=smbadmins
groupadd "$GROUPNAME_ADMINS"

# create guest user
echo -e "${Green}create guest user (e.g visitor) [read only access]:${Color_Off}"
read -r GUESTUSER
sed -i "s/MYGUESTUSER/$GUESTUSER/g" "$SMB_CONFIG"
mkdir "$SAVEDIR/everyone"
useradd -d "$SAVEDIR/everyone" -M -s /usr/sbin/nologin -G "$GROUPNAME" "$GUESTUSER"
chown "$GUESTUSER":"$GROUPNAME" "$SAVEDIR/everyone"
chmod 2770 "$SAVEDIR/everyone"
smbpasswd -a "$GUESTUSER"
smbpasswd -e "$GUESTUSER"

# create normal user, add user to config, add user to groups, set inherit permissions, create samba password
echo -e "${Green}create normal user (e.g bruce) [read/write access]:${Color_Off}"
read -r USERNAME
sed -i "s/MYUSERNAME/$USERNAME/g" "$SMB_CONFIG"
mkdir "$SAVEDIR/$USERNAME"
useradd -d "$SAVEDIR/$USERNAME" -M -s /usr/sbin/nologin -G "$GROUPNAME","$GROUPNAME_USERS" "$USERNAME"
chown "$USERNAME":"$GROUPNAME" "$SAVEDIR/$USERNAME"
chmod 2770 "$SAVEDIR/$USERNAME"
smbpasswd -a "$USERNAME"
smbpasswd -e "$USERNAME"

# create admin user
echo -e "${Green}create administrator user (e.g godmode):${Color_Off}"
read -r ADMIN
sed -i "s/MYADMIN/$ADMIN/g" "$SMB_CONFIG"
mkdir "$SAVEDIR/$ADMIN"
useradd -d "$SAVEDIR/$ADMIN" -M -s /usr/sbin/nologin -G "$GROUPNAME","$GROUPNAME_ADMINS" "$ADMIN"
chown "$ADMIN":"$GROUPNAME" "$SAVEDIR/$ADMIN"
chmod 2770 "$SAVEDIR/$ADMIN"
smbpasswd -a "$ADMIN"
smbpasswd -e "$ADMIN"

# enable and start service
if [ "$PKMGR" = "apt" ]; then
  systemctl enable --now nmbd.service smbd.service
elif [ "$PKMGR" = "apt-get" ]; then
  systemctl enable --now nmbd.service smbd.service
elif [ "$PKMGR" = "aptitude" ]; then
  systemctl enable --now nmbd.service smbd.service
elif [ "$PKMGR" = "dnf" ]; then
  systemctl enable --now nmb.service smb.service
elif [ "$PKMGR" = "emerge" ]; then
  systemctl enable --now nmbd.service smbd.service
elif [ "$PKMGR" = "eopkg" ]; then
  systemctl enable --now nmb.service smb.service
elif [ "$PKMGR" = "pacman" ]; then
  systemctl enable --now nmb.service smb.service
elif [ "$PKMGR" = "zypper" ]; then
  systemctl enable --now nmb.service smb.service
fi

printf "\n"

MY_IP="$(ip addr | awk '/global/ {print $1,$2}' | cut -d'/' -f1 | cut -d' ' -f2 | head -n 1)"
echo -e "${Yellow}>>>Server will be hosted at ${Red}smb://$MY_IP ${Yellow}or ${Red}smb://$SERVERNAME${Color_Off}"
echo -e "${Purple}You might need to check your firewall/iptables configurations.${Color_Off}"
