#!/bin/bash
##############################################################################
#    Open LiteSpeed is an open source HTTP server.                           #
#    Copyright (C) 2013 - 2021 LiteSpeed Technologies, Inc.                  #
#                                                                            #
#    This program is free software: you can redistribute it and/or modify    #
#    it under the terms of the GNU General Public License as published by    #
#    the Free Software Foundation, either version 3 of the License, or       #
#    (at your option) any later version.                                     #
#                                                                            #
#    This program is distributed in the hope that it will be useful,         #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of          #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the            #
#    GNU General Public License for more details.                            #
#                                                                            #
#    You should have received a copy of the GNU General Public License       #
#    along with this program. If not, see http://www.gnu.org/licenses/.      #
##############################################################################

###    Author: dxu@litespeedtech.com (David Shue)


TEMPRANDSTR=
OSNAMEVER=UNKNOWN
OSNAME=
OSVER=
OSTYPE=$(uname -m)
MARIADBCPUARCH=
SERVER_ROOT=/usr/local/lsws
WEBCF="$SERVER_ROOT/conf/httpd_config.conf"
OLSINSTALLED=
MYSQLINSTALLED=
TESTGETERROR=no
DATABASENAME=olsdbname
USERNAME=olsdbuser
VERBOSE=0
PURE_DB=0
WORDPRESSPATH=$SERVER_ROOT/wordpress
WPPORT=80
SSLWPPORT=443
WORDPRESSINSTALLED=
INSTALLWORDPRESS=0
INSTALLWORDPRESSPLUS=0
FORCEYES=0
WPLANGUAGE=en_US
WPUSER=wpuser
WPTITLE=MySite
SITEDOMAIN=*
EMAIL=
ADMINPASSWORD=
ROOTPASSWORD=
USERPASSWORD=
WPPASSWORD=
LSPHPVERLIST=(56 70 71 72 73 74 80)
MARIADBVERLIST=(10.1 10.2 10.3 10.4 10.5)
LSPHPVER=74
MARIADBVER=10.4
WEBADMIN_LSPHPVER=73
ALLERRORS=0
TEMPPASSWORD=
ACTION=INSTALL
FOLLOWPARAM=
CONFFILE=myssl.conf
CSR=example.csr
KEY=example.key
CERT=example.crt
EPACE='        '
FPACE='    '
APT='apt-get -qq'
YUM='yum -q'
MYGITHUBURL=https://raw.githubusercontent.com/litespeedtech/ols1clk/master/ols1clk.sh

function echoY
{
    FLAG=$1
    shift
    echo -e "\033[38;5;148m$FLAG\033[39m$@"
}

function echoG
{
    FLAG=$1
    shift
    echo -e "\033[38;5;71m$FLAG\033[39m$@"
}

function echoB
{
    FLAG=$1
    shift
    echo -e "\033[38;1;34m$FLAG\033[39m$@"
}

function echoR
{
    FLAG=$1
    shift
    echo -e "\033[38;5;203m$FLAG\033[39m$@"
}

function echoW
{
    FLAG=${1}
    shift
    echo -e "\033[1m${EPACE}${FLAG}\033[0m${@}"
}

function echoNW
{
    FLAG=${1}
    shift
    echo -e "\033[1m${FLAG}\033[0m${@}"
}

function echoCYAN
{
    FLAG=$1
    shift
    echo -e "\033[1;36m$FLAG\033[0m$@"
}

function silent
{
    if [ "${VERBOSE}" = '1' ] ; then
        "$@"
    else
        "$@" >/dev/null 2>&1
    fi
}

function change_owner
{
    chown -R ${USER}:${GROUP} ${1}
}

function check_root
{
	local INST_USER
    INST_USER=$(id -u)
    if [ "$INST_USER" != 0 ] ; then
        echo "Sorry, only the root user can install."
        echo
        exit 1
    fi
}

function update_system(){
    echo 'System update'
    if [ "$OSNAME" = "centos" ] ; then
        silent "${YUM}" update >/dev/null 2>&1
    else
        silent "${APT}" update && "${APT}" upgrade -y >/dev/null 2>&1
    fi
}

function check_wget
{
    which wget  >/dev/null 2>&1
    if [ $? != 0 ] ; then
        if [ "$OSNAME" = "centos" ] ; then
            silent ${YUM} -y install wget
        else
            ${APT} -y install wget
        fi

        which wget  >/dev/null 2>&1
        if [ $? != 0 ] ; then
            echo "An error occured during wget installation."
            ALLERRORS=1
        fi
    fi
}

function check_curl
{
    which curl  >/dev/null 2>&1
    if [ $? != 0 ] ; then
        if [ "$OSNAME" = "centos" ] ; then
            silent ${YUM} -y install curl
        else
            ${APT} -y install curl
        fi

        which curl  >/dev/null 2>&1
        if [ $? != 0 ] ; then
            echo "An error occured during curl installation."
            ALLERRORS=1
        fi
    fi
}

function update_email
{
    if [ "$EMAIL" = '' ] ; then
        if [ "$SITEDOMAIN" = "*" ] ; then
            EMAIL=root@localhost
        else
            EMAIL=root@$SITEDOMAIN
        fi
    fi
}

function restart_lsws
{
    systemctl stop lsws >/dev/null 2>&1
    systemctl start lsws
}

function usage
{
    echo -e "\033[1mOPTIONS\033[0m"
    echo "  -A,    --adminpassword [PASSWORD]" "${EPACE}To set the WebAdmin password for OpenLiteSpeed instead of using a random one."
    echo "  -E,    --email [EMAIL]          " "${EPACE} To set the administrator email."
    echo " --lsphp [VERSION]                 " "To set the LSPHP version, such as 80. We currently support versions '${LSPHPVERLIST[@]}'."
    echo " --mariadbver [VERSION]            " "To set MariaDB version, such as 10.5. We currently support versions '${MARIADBVERLIST[@]}'."
    echo "  -W,    --wordpress              " "${EPACE} To install WordPress. You will still need to complete the WordPress setup by browser"
    echo " --wordpressplus [SITEDOMAIN]      " "To install, setup, and configure WordPress, also LSCache will be enabled"
    echo " --wordpresspath [WP_PATH]         " "To specify a location for the new WordPress installation or an existing WordPress."
    echo "  -R,    --dbrootpassword [PASSWORD]  " "     To set the database root password instead of using a random one."
    echo " --dbname [DATABASENAME]           " "To set the database name to be used by WordPress."
    echo " --dbuser [DBUSERNAME]             " "To set the WordPress username in the database."
    echo " --dbpassword [PASSWORD]           " "To set the WordPress table password in MySQL instead of using a random one."
    echo " --listenport [PORT]               " "To set the HTTP server listener port, default is 80."
    echo " --ssllistenport [PORT]            " "To set the HTTPS server listener port, default is 443."
    echo " --wpuser [WORDPRESSUSER]          " "To set the WordPress admin user for WordPress dashboard login. Default value is wpuser."
    echo " --wppassword [PASSWORD]           " "To set the WordPress admin user password for WordPress dashboard login."
    echo " --wplang [WP_LANGUAGE]            " "To set the WordPress language. Default value is \"en_US\" for English."
    echo " --sitetitle [WP_TITLE]            " "To set the WordPress site title. Default value is mySite."
    echo "  -U,    --uninstall              " "${EPACE} To uninstall OpenLiteSpeed and remove installation directory."
    echo "  -P,    --purgeall               " "${EPACE} To uninstall OpenLiteSpeed, remove installation directory, and purge all data in MySQL."
    echo "  -Q,    --quiet                  " "${EPACE} To use quiet mode, won't prompt to input anything."
    echo "  -V,    --version                " "${EPACE} To display the script version information."
    echo "  -v,    --verbose                " "${EPACE} To display more messages during the installation."
    echo " --update                          " "To update ols1clk from github."
    echo "  -H,    --help                   " "${EPACE} To display help messages."
    echo 
    echo -e "\033[1mEXAMPLES\033[0m"
    echo "./ols1clk.sh                       " "To install OpenLiteSpeed with a random WebAdmin password."
    echo "./ols1clk.sh --lsphp 80            " "To install OpenLiteSpeed with lsphp80."
    echo "./ols1clk.sh -A 123456 -e a@cc.com " "To install OpenLiteSpeed with WebAdmin password  \"123456\" and email a@cc.com."
    echo "./ols1clk.sh -R 123456 -W          " "To install OpenLiteSpeed with WordPress and MySQL root password \"123456\"."
    echo "./ols1clk.sh --wordpressplus a.com " "To install OpenLiteSpeed with a fully configured WordPress installation at \"a.com\"."
    echo
    exit 0
}

function display_license
{
    echo '**********************************************************************************************'
    echo '*                    Open LiteSpeed One click installation, Version 3.0                      *'
    echo '*                    Copyright (C) 2016 - 2021 LiteSpeed Technologies, Inc.                  *'
    echo '**********************************************************************************************'
}

function check_os
{
    if [ -f /etc/redhat-release ] ; then
        OSNAME=centos
        USER='nobody'
        GROUP='nobody'
        case $(cat /etc/centos-release | tr -dc '0-9.'|cut -d \. -f1) in 
        6)
            OSNAMEVER=CENTOS6
            OSVER=6
            ;;
        7)
            OSNAMEVER=CENTOS7
            OSVER=7
            ;;
        8)
            OSNAMEVER=CENTOS8
            OSVER=8
            ;;
        esac    
    elif [ -f /etc/lsb-release ] ; then
        OSNAME=ubuntu
        USER='nobody'
        GROUP='nogroup'
        case $(cat /etc/os-release | grep UBUNTU_CODENAME | cut -d = -f 2) in
        trusty)
            OSNAMEVER=UBUNTU14
            OSVER=trusty
            MARIADBCPUARCH="arch=amd64,i386,ppc64el"
            ;;
        xenial)
            OSNAMEVER=UBUNTU16
            OSVER=xenial
            MARIADBCPUARCH="arch=amd64,i386,ppc64el"
            ;;
        bionic)
            OSNAMEVER=UBUNTU18
            OSVER=bionic
            MARIADBCPUARCH="arch=amd64"
            ;;
        focal)            
            OSNAMEVER=UBUNTU20
            OSVER=focal
            MARIADBCPUARCH="arch=amd64"
            ;;
        esac
    elif [ -f /etc/debian_version ] ; then
        OSNAME=debian
        case $(cat /etc/os-release | grep VERSION_CODENAME | cut -d = -f 2) in
        wheezy)
            OSNAMEVER=DEBIAN7
            OSVER=wheezy
            MARIADBCPUARCH="arch=amd64,i386"
            ;;
        jessie)
            OSNAMEVER=DEBIAN8
            OSVER=jessie
            MARIADBCPUARCH="arch=amd64,i386"
            ;;
        stretch) 
            OSNAMEVER=DEBIAN9
            OSVER=stretch
            MARIADBCPUARCH="arch=amd64,i386"
            ;;
        buster)
            OSNAMEVER=DEBIAN10
            OSVER=buster
            MARIADBCPUARCH="arch=amd64,i386"
            ;;
        esac    
    fi

    if [ "$OSNAMEVER" = '' ] ; then
        echo "Sorry, currently one click installation only supports Centos(6-8), Debian(7-10) and Ubuntu(14,16,18,20)."
        echo "You can download the source code and build from it."
        echo "The url of the source code is https://github.com/litespeedtech/openlitespeed/releases."
        exit 1
    else
        if [ "$OSNAME" = "centos" ] ; then
            echo "Current platform is "  "$OSNAME $OSVER."
        else
            export DEBIAN_FRONTEND=noninteractive
            echo "Current platform is "  "$OSNAMEVER $OSNAME $OSVER."
        fi
    fi
}

function update_centos_hashlib
{
    if [ "$OSNAME" = 'centos' ] ; then
        silent ${YUM} -y install python-hashlib
    fi
}

function install_ols_centos
{
    local action=install
    if [ "$1" = "Update" ] ; then
        action=update
    elif [ "$1" = "Reinstall" ] ; then
        action=reinstall
    fi

    local JSON=
    if [ "x$LSPHPVER" = "x70" ] || [ "x$LSPHPVER" = "x71" ] || [ "x$LSPHPVER" = "x72" ] || [ "x$LSPHPVER" = "x73" ] || [ "x$LSPHPVER" = "x74" ]; then
        JSON=lsphp$LSPHPVER-json
    fi
    echo "${FPACE} - add epel repo"
    silent ${YUM} -y $action epel-release
    echo "${FPACE} - add litespeedtech repo"
    rpm -Uvh http://rpms.litespeedtech.com/centos/litespeed-repo-1.1-1.el$OSVER.noarch.rpm >/dev/null 2>&1
    echo "${FPACE} - $1 OpenLiteSpeed"
    silent ${YUM} -y $action openlitespeed
    if [ ! -e $SERVER_ROOT/lsphp$LSPHPVER/bin/lsphp ] ; then
        action=install
    fi
    echo "${FPACE} - $1 lsphp$LSPHPVER"
    if [ "$action" = "reinstall" ] ; then
        silent ${YUM} -y remove lsphp$LSPHPVER-mysqlnd
    fi
    silent ${YUM} -y install lsphp$LSPHPVER-mysqlnd
    if [ "$LSPHPVER" = "80" ]; then 
        silent ${YUM} -y $action lsphp$LSPHPVER lsphp$LSPHPVER-common lsphp$LSPHPVER-gd lsphp$LSPHPVER-process lsphp$LSPHPVER-mbstring \
        lsphp$LSPHPVER-xml lsphp$LSPHPVER-pdo lsphp$LSPHPVER-imap
    else
        silent ${YUM} -y $action lsphp$LSPHPVER lsphp$LSPHPVER-common lsphp$LSPHPVER-gd lsphp$LSPHPVER-process lsphp$LSPHPVER-mbstring \
        lsphp$LSPHPVER-xml lsphp$LSPHPVER-mcrypt lsphp$LSPHPVER-pdo lsphp$LSPHPVER-imap $JSON
    fi
    echo "${FPACE} - Setup lsphp symlink"
    if [ $? != 0 ] ; then
        echo "An error occured during OpenLiteSpeed installation."
        ALLERRORS=1
    else
        ln -sf $SERVER_ROOT/lsphp$LSPHPVER/bin/lsphp $SERVER_ROOT/fcgi-bin/lsphpnew
        sed -i -e "s/fcgi-bin\/lsphp/fcgi-bin\/lsphpnew/g" "${WEBCF}"
        sed -i -e "s/lsphp${WEBADMIN_LSPHPVER}\/bin\/lsphp/lsphp$LSPHPVER\/bin\/lsphp/g" "${WEBCF}"
    fi
}

function uninstall_ols_centos
{
    echo "${FPACE} - Remove OpenLiteSpeed"
    silent ${YUM} -y remove openlitespeed
    if [ $? != 0 ] ; then
        echo "An error occured while uninstalling OpenLiteSpeed."
        ALLERRORS=1
    fi
    rm -rf $SERVER_ROOT/
}

function uninstall_php_centos
{
    ls "${SERVER_ROOT}" | grep lsphp >/dev/null
    if [ $? = 0 ] ; then
        local LSPHPSTR="$(ls ${SERVER_ROOT} | grep -i lsphp | tr '\n' ' ')"
        for LSPHPVER in ${LSPHPSTR}; do 
            echo "${FPACE} - Detect LSPHP version $LSPHPVER"
            if [ "$LSPHPVER" = "lsphp80" ]; then
                silent ${YUM} -y remove lsphp$LSPHPVER lsphp$LSPHPVER-common lsphp$LSPHPVER-gd lsphp$LSPHPVER-process lsphp$LSPHPVER-mbstring \
                lsphp$LSPHPVER-mysqlnd lsphp$LSPHPVER-xml  lsphp$LSPHPVER-pdo lsphp$LSPHPVER-imap lsphp*
            else
                silent ${YUM} -y remove lsphp$LSPHPVER lsphp$LSPHPVER-common lsphp$LSPHPVER-gd lsphp$LSPHPVER-process lsphp$LSPHPVER-mbstring \
                lsphp$LSPHPVER-mysqlnd lsphp$LSPHPVER-xml lsphp$LSPHPVER-mcrypt lsphp$LSPHPVER-pdo lsphp$LSPHPVER-imap $JSON lsphp*
            fi                
            if [ $? != 0 ] ; then
                echo "An error occured while uninstalling lsphp$LSPHPVER"
                ALLERRORS=1
            fi
        done 
    else
        echo "${FPACE} - Uinstall LSPHP"
        ${YUM} -y remove lsphp*
        echo "Uninstallation cannot get the currently installed LSPHP version."
        echo "May not uninstall LSPHP correctly."
        LSPHPVER=
    fi
}

function install_ols_debian
{
    local action=
    local INSTALL_STATUS=0
    if [ "$1" = "Update" ] ; then
        action="--only-upgrade"
    elif [ "$1" = "Reinstall" ] ; then
        action="--reinstall"
    fi
    echo "${FPACE} - add litespeedtech repo"
    grep -Fq  "http://rpms.litespeedtech.com/debian/" /etc/apt/sources.list.d/lst_debian_repo.list 2>/dev/null
    if [ $? != 0 ] ; then
        echo "deb http://rpms.litespeedtech.com/debian/ $OSVER main"  > /etc/apt/sources.list.d/lst_debian_repo.list
    fi

    wget -qO /etc/apt/trusted.gpg.d/lst_debian_repo.gpg http://rpms.litespeedtech.com/debian/lst_debian_repo.gpg
    wget -qO /etc/apt/trusted.gpg.d/lst_repo.gpg http://rpms.litespeedtech.com/debian/lst_repo.gpg
    echo "${FPACE} - update list"
    ${APT} -y update
    echo "${FPACE} - $1 OpenLiteSpeed"
    silent ${APT} -y install $action openlitespeed

    if [ ${?} != 0 ] ; then
        echo "An error occured during OpenLiteSpeed installation."
        ALLERRORS=1
        INSTALL_STATUS=1
    fi
    if [ ! -e $SERVER_ROOT/lsphp$LSPHPVER/bin/lsphp ] ; then
        action=
    fi
    echo "${FPACE} - $1 lsphp$LSPHPVER"
    silent ${APT} -y install $action lsphp$LSPHPVER lsphp$LSPHPVER-mysql lsphp$LSPHPVER-imap lsphp$LSPHPVER-curl

    if [ "$LSPHPVER" = "56" ]; then
        silent ${APT} -y install $action lsphp$LSPHPVER-gd lsphp$LSPHPVER-mcrypt
    elif [ "$LSPHPVER" = "80" ]; then
        silent ${APT} -y install $action lsphp$LSPHPVER-common
    else
        silent ${APT} -y install $action lsphp$LSPHPVER-common lsphp$LSPHPVER-json
    fi

    if [ $? != 0 ] ; then
        echo "An error occured during lsphp$LSPHPVER installation."
        ALLERRORS=1
    fi
    echo "${FPACE} - Setup lsphp symlink"
    #if [ ${INSTALL_STATUS} = 0 ]; then 
    if [ -e $SERVER_ROOT/bin/openlitespeed ]; then 
        ln -sf $SERVER_ROOT/lsphp$LSPHPVER/bin/lsphp $SERVER_ROOT/fcgi-bin/lsphpnew
        sed -i -e "s/fcgi-bin\/lsphp/fcgi-bin\/lsphpnew/g" "${WEBCF}"    
        sed -i -e "s/lsphp${WEBADMIN_LSPHPVER}\/bin\/lsphp/lsphp$LSPHPVER\/bin\/lsphp/g" "${WEBCF}"
    fi
}


function uninstall_ols_debian
{
    echo "${FPACE} - Uninstall OpenLiteSpeed"
    silent ${APT} -y purge openlitespeed
    silent ${APT} -y remove openlitespeed
    ${APT} clean
    #rm -rf $SERVER_ROOT/
}

function uninstall_php_debian
{
    echo "${FPACE} - Uninstall LSPHP"
    silent ${APT} -y --purge remove lsphp*
    if [ -e /usr/bin/php ] && [ -L /usr/bin/php ]; then 
        rm -f /usr/bin/php
    fi
}

function action_uninstall
{
    if [ "$ACTION" = "UNINSTALL" ] ; then
        uninstall_warn
        uninstall
        uninstall_result
        exit 0
    fi    
} 

function action_purgeall
{    
    if [ "$ACTION" = "PURGEALL" ] ; then
        uninstall_warn
        if [ "$ROOTPASSWORD" = '' ] ; then
            passwd=
            echo "Please input the MySQL root password: "
            read passwd
            ROOTPASSWORD=$passwd
        fi
        uninstall
        purgedatabase
        uninstall_result
        exit 0
    fi
}

function download_wordpress
{
    echo 'Start Download WordPress file'
    if [ ! -e "$WORDPRESSPATH" ] ; then
        local WPDIRNAME=$(dirname $WORDPRESSPATH)
        local WPBASENAME=$(basename $WORDPRESSPATH)
        mkdir -p "$WORDPRESSPATH"; 
        cd "$WORDPRESSPATH"
    else
        echo "$WORDPRESSPATH exists, will use it."
    fi
    if [ "${WORDPRESSINSTALLED}" = '0' ];then 
        wp core download \
            --locale=$WPLANGUAGE \
            --path=$WORDPRESSPATH \
            --allow-root \
            --quiet
    fi        
    echo 'End Download WordPress file'
}
function create_wordpress_cf
{
    echo 'Start Create Wordpress config'
    cd "$WORDPRESSPATH"
    wp config create \
        --dbname=$DATABASENAME \
        --dbuser=$USERNAME \
        --dbpass=$USERPASSWORD \
        --locale=ro_RO \
        --allow-root \
        --quiet
    echo 'Done Create Wordpress config'
}

function install_wordpress_core
{
    echo 'Start Setting Core Wordpress'
    cd "$WORDPRESSPATH"
    wp core install \
        --url=$SITEDOMAIN \
        --title=$WPTITLE \
        --admin_user=$WPUSER \
        --admin_password=$WPPASSWORD \
        --admin_email=$EMAIL \
        --skip-email \
        --allow-root
    echo 'Install wordpress Cache plugin'    
    wp plugin install litespeed-cache \
        --allow-root \
        --activate \
        --quiet
    echo 'End Setting Core Wordpress'
}

function random_password
{
    if [ ! -z ${1} ]; then 
        TEMPPASSWORD="${1}"
    else    
        TEMPPASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16 ; echo '')
    fi
}

function main_gen_password
{
    random_password "${ADMINPASSWORD}"
    ADMINPASSWORD="${TEMPPASSWORD}"
    random_password "${ROOTPASSWORD}"
    ROOTPASSWORD="${TEMPPASSWORD}"
    random_password "${USERPASSWORD}"
    USERPASSWORD="${TEMPPASSWORD}"
    random_password "${WPPASSWORD}"
    WPPASSWORD="${TEMPPASSWORD}"
    read_password "$ADMINPASSWORD" "webAdmin password"
    ADMINPASSWORD=$TEMPPASSWORD
    
    if [ "$INSTALLWORDPRESS" = "1" ] ; then
        read_password "$ROOTPASSWORD" "MySQL root password"
        ROOTPASSWORD=$TEMPPASSWORD
        read_password "$USERPASSWORD" "MySQL user password"
        USERPASSWORD=$TEMPPASSWORD
    fi

    if [ "$INSTALLWORDPRESSPLUS" = "1" ] ; then
        read_password "$WPPASSWORD" "WordPress admin password"
        WPPASSWORD=$TEMPPASSWORD
    fi    
}

function main_set_password
{
    echo "WebAdmin username is [admin], password is [$ADMINPASSWORD]." > $SERVER_ROOT/password
    set_ols_password
}

function test_mysql_password
{
    CURROOTPASSWORD=$ROOTPASSWORD
    TESTPASSWORDERROR=0

    mysqladmin -uroot -p$CURROOTPASSWORD password $CURROOTPASSWORD
    if [ $? != 0 ] ; then
        #Sometimes, mysql will treat the password error and restart will fix it.
        service mysql restart
        if [ $? != 0 ] && [ "$OSNAME" = "centos" ] ; then
            service mysqld restart
        fi

        mysqladmin -uroot -p$CURROOTPASSWORD password $CURROOTPASSWORD
        if [ $? != 0 ] ; then
            printf '\033[31mPlease input the current root password:\033[0m'
            read answer
            mysqladmin -uroot -p$answer password $answer
            if [ $? = 0 ] ; then
                CURROOTPASSWORD=$answer
            else
                echo "root password is incorrect. 2 attempts remaining."
                printf '\033[31mPlease input the current root password:\033[0m'
                read answer
                mysqladmin -uroot -p$answer password $answer
                if [ $? = 0 ] ; then
                    CURROOTPASSWORD=$answer
                else
                    echo "root password is incorrect. 1 attempt remaining."
                    printf '\033[31mPlease input the current root password:\033[0m'
                    read answer
                    mysqladmin -uroot -p$answer password $answer
                    if [ $? = 0 ] ; then
                        CURROOTPASSWORD=$answer
                    else
                        echo "root password is incorrect. 0 attempts remaining."
                        echo
                        TESTPASSWORDERROR=1
                    fi
                fi
            fi
        fi
    fi

    export TESTPASSWORDERROR=$TESTPASSWORDERROR
    if [ "x$TESTPASSWORDERROR" = "x1" ] ; then
        export CURROOTPASSWORD=
    else
        export CURROOTPASSWORD=$CURROOTPASSWORD
    fi
}

function centos_install_mysql
{
    echo "${FPACE} - Add MariaDB repo"
    local REPOFILE=/etc/yum.repos.d/MariaDB.repo
    if [ ! -f $REPOFILE ] ; then
        local CENTOSVER=
        if [ "$OSTYPE" != "x86_64" ] ; then
            CENTOSVER=centos$OSVER-x86
        else
            CENTOSVER=centos$OSVER-amd64
        fi
        if [ "$OSNAMEVER" = "CENTOS8" ] ; then
            rpm --quiet --import https://downloads.mariadb.com/MariaDB/MariaDB-Server-GPG-KEY
            cat >> $REPOFILE <<END
[mariadb]
name = MariaDB
baseurl = https://downloads.mariadb.com/MariaDB/mariadb-$MARIADBVER/yum/rhel/\$releasever/\$basearch
gpgkey = file:///etc/pki/rpm-gpg/MariaDB-Server-GPG-KEY
gpgcheck=1
enabled = 1
module_hotfixes = 1
END
        else
            cat >> $REPOFILE <<END
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/$MARIADBVER/$CENTOSVER
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1

END
        fi 
    fi
    echo "${FPACE} - Install MariaDB"
    if [ "$OSNAMEVER" = "CENTOS8" ] ; then
        silent ${YUM} install -y boost-program-options
        silent ${YUM} --disablerepo=AppStream install -y MariaDB-server MariaDB-client
    else
        silent ${YUM} -y install MariaDB-server MariaDB-client
    fi
    if [ $? != 0 ] ; then
        echo "An error occured during installation of MariaDB. Please fix this error and try again."
        echo "You may want to manually run the command '${YUM} -y install MariaDB-server MariaDB-client' to check. Aborting installation!"
        exit 1
    fi
    echo "${FPACE} - Start MariaDB"
    if [ "$OSNAMEVER" = "CENTOS8" ] || [ "$OSNAMEVER" = "CENTOS7" ] ; then
        silent systemctl enable mariadb
        silent systemctl start  mariadb
    else
        service mysql start
    fi    
}

function debian_install_mysql
{
    echo "${FPACE} - Install software properties"
    if [ "$OSNAMEVER" = "DEBIAN7" ] ; then
        silent ${APT} -y -f install python-software-properties
        silent apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db
    elif [ "$OSNAMEVER" = "DEBIAN8" ] ; then
        silent ${APT} -y -f install software-properties-common
        silent apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db
    elif [ "$OSNAMEVER" = "DEBIAN9" ] ; then
        silent ${APT} -y -f install software-properties-common gnupg
        silent apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xF1656F24C74CD1D8
    elif [ "$OSNAMEVER" = "DEBIAN10" ] ; then
        silent ${APT} -y -f install software-properties-common gnupg
        silent apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xF1656F24C74CD1D8
    elif [ "$OSNAMEVER" = "UBUNTU14" ] ; then
        silent ${APT} -y -f install software-properties-common
        silent apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
    elif [ "$OSNAMEVER" = "UBUNTU16" ] ; then
        silent ${APT} -y -f install software-properties-common
        silent apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
    elif [ "$OSNAMEVER" = "UBUNTU18" ] ; then
        silent ${APT} -y -f install software-properties-common
        silent apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
    elif [ "$OSNAMEVER" = "UBUNTU20" ] ; then
        silent ${APT} -y -f install software-properties-common
        silent apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8    
    fi
    echo "${FPACE} - Add MariaDB repo"
    if [ -e /etc/apt/sources.list.d/mariadb_repo.list ]; then  
        grep -Fq  "http://mirror.jaleco.com/mariadb/repo/" /etc/apt/sources.list.d/mariadb_repo.list >/dev/null 2>&1
        if [ $? != 0 ] ; then
            echo "deb [$MARIADBCPUARCH] http://mirror.jaleco.com/mariadb/repo/$MARIADBVER/$OSNAME $OSVER main"  > /etc/apt/sources.list.d/mariadb_repo.list
        fi
    else 
        echo "deb [$MARIADBCPUARCH] http://mirror.jaleco.com/mariadb/repo/$MARIADBVER/$OSNAME $OSVER main"  > /etc/apt/sources.list.d/mariadb_repo.list    
    fi
    echo "${FPACE} - Update packages"
    ${APT} update
    echo "${FPACE} - Install MariaDB"
    silent ${APT} -y -f install mariadb-server
    if [ $? != 0 ] ; then
        echo "An error occured during installation of MariaDB. Please fix this error and try again."
        echo "You may want to manually run the command 'apt-get -y -f --allow-unauthenticated install mariadb-server' to check. Aborting installation!"
        exit 1
    fi
    echo "${FPACE} - Start MariaDB"
    service mysql start
}

function install_mysql
{
    echo "Start Install MariaDB"
    if [ "$OSNAME" = 'centos' ] ; then
        centos_install_mysql
    else
        debian_install_mysql
    fi
    if [ $? != 0 ] ; then
        echo "An error occured when starting the MariaDB service. "
        echo "Please fix this error and try again. Aborting installation!"
        exit 1
    fi

    echo "${FPACE} - Set MariaDB root"
    mysql -uroot -e "flush privileges;"
    mysqladmin -uroot password $ROOTPASSWORD
    if [ $? = 0 ] ; then
        CURROOTPASSWORD=$ROOTPASSWORD
    else
        #test it is the current password
        mysqladmin -uroot -p$ROOTPASSWORD password $ROOTPASSWORD
        if [ $? = 0 ] ; then
            #echo "MySQL root password is $ROOTPASSWORD"
            CURROOTPASSWORD=$ROOTPASSWORD
        else
            echo "Failed to set MySQL root password to $ROOTPASSWORD, it may already have a root password."
            printf '\033[31mInstallation must know the password for the next step.\033[0m'
            test_mysql_password

            if [ "$TESTPASSWORDERROR" = "1" ] ; then
                echo "If you forget your password you may stop the mysqld service and run the following command to reset it,"
                echo "mysqld_safe --skip-grant-tables &"
                echo "mysql --user=root mysql"
                echo "update user set Password=PASSWORD('new-password') where user='root'; flush privileges; exit; "
                echo "Aborting installation."
                echo
                exit 1
            fi

            if [ "$CURROOTPASSWORD" != "$ROOTPASSWORD" ] ; then
                echo "Current MySQL root password is $CURROOTPASSWORD, it will be changed to $ROOTPASSWORD."
                printf '\033[31mDo you still want to change it?[y/N]\033[0m '
                read answer
                echo

                if [ "$answer" != "Y" ] && [ "$answer" != "y" ] ; then
                    echo "OK, MySQL root password not changed."
                    ROOTPASSWORD=$CURROOTPASSWORD
                else
                    mysqladmin -uroot -p$CURROOTPASSWORD password $ROOTPASSWORD
                    if [ $? = 0 ] ; then
                        echo "OK, MySQL root password changed to $ROOTPASSWORD."
                    else
                        echo "Failed to change MySQL root password, it is still $CURROOTPASSWORD."
                        ROOTPASSWORD=$CURROOTPASSWORD
                    fi
                fi
            fi
        fi
    fi
    echo "End Install MariaDB"
}

function setup_mysql
{
    echo "Start setup mysql"
    local ERROR=
    #delete user if exists
    mysql -uroot -p$ROOTPASSWORD  -e "DELETE FROM mysql.user WHERE User = '$USERNAME@localhost';"

    echo `mysql -uroot -p$ROOTPASSWORD -e "SELECT user FROM mysql.user"` | grep "$USERNAME" >/dev/null
    if [ $? = 0 ] ; then
        echo "user $USERNAME exists in mysql.user"
    else
        mysql -uroot -p$ROOTPASSWORD  -e "CREATE USER $USERNAME@localhost IDENTIFIED BY '$USERPASSWORD';"
        if [ $? = 0 ] ; then
            mysql -uroot -p$ROOTPASSWORD  -e "GRANT ALL PRIVILEGES ON *.* TO '$USERNAME'@localhost IDENTIFIED BY '$USERPASSWORD';"
        else
            echo "Failed to create MySQL user $USERNAME. This user may already exist. If it does not, another problem occured."
            echo "Please check this and update the wp-config.php file."
            ERROR="Create user error"
        fi
    fi

    mysql -uroot -p$ROOTPASSWORD  -e "CREATE DATABASE IF NOT EXISTS $DATABASENAME;"
    if [ $? = 0 ] ; then
        mysql -uroot -p$ROOTPASSWORD  -e "GRANT ALL PRIVILEGES ON $DATABASENAME.* TO '$USERNAME'@localhost IDENTIFIED BY '$USERPASSWORD';"
    else
        echo "Failed to create database $DATABASENAME. It may already exist. If it does not, another problem occured."
        echo "Please check this and update the wp-config.php file."
        if [ "x$ERROR" = "x" ] ; then
            ERROR="Create database error"
        else
            ERROR="$ERROR and create database error"
        fi
    fi
    mysql -uroot -p$ROOTPASSWORD  -e "flush privileges;"

    if [ "x$ERROR" = "x" ] ; then
        echo "Finished MySQL setup without error."
    else
        echo "Finished MySQL setup - some error(s) occured."
    fi
    echo "End setup mysql"
}

function resetmysqlroot
{
    if [ "x$OSNAMEVER" = "xCENTOS8" ]; then
        MYSQLNAME='mariadb'
    else
        MYSQLNAME=mysql
    fi
    service $MYSQLNAME stop
    if [ $? != 0 ] && [ "x$OSNAME" = "xcentos" ] ; then
        service $MYSQLNAME stop
    fi

    DEFAULTPASSWD=$1

    echo "update user set Password=PASSWORD('$DEFAULTPASSWD') where user='root'; flush privileges; exit; " > /tmp/resetmysqlroot.sql
    mysqld_safe --skip-grant-tables &
    #mysql --user=root mysql < /tmp/resetmysqlroot.sql
    mysql --user=root mysql -e "update user set Password=PASSWORD('$DEFAULTPASSWD') where user='root'; flush privileges; exit; "
    sleep 1
    service $MYSQLNAME restart
}

function purgedatabase
{
    if [ "$MYSQLINSTALLED" != "1" ] ; then
        echo "MySQL-server not installed."
    else
        local ERROR=0
        test_mysql_password

        if [ "$TESTPASSWORDERROR" = "1" ] ; then
            echo "Failed to purge database."
            echo
            ERROR=1
            ALLERRORS=1
        else
            ROOTPASSWORD=$CURROOTPASSWORD
        fi

        if [ "$ERROR" = "0" ] ; then
            mysql -uroot -p$ROOTPASSWORD  -e "DELETE FROM mysql.user WHERE User = '$USERNAME@localhost';"
            mysql -uroot -p$ROOTPASSWORD  -e "DROP DATABASE IF EXISTS $DATABASENAME;"
            echo "Database purged."
        fi
    fi
}

function pure_mariadb
{
    if [ "$MYSQLINSTALLED" = "0" ] ; then
        install_mysql
        ROOTPASSWORD=$CURROOTPASSWORD
        setup_mysql        
    else
        echo 'MariaDB already exist, skip!'
    fi
}

function uninstall_result
{
    if [ "$ALLERRORS" != "0" ] ; then
        echo "Some error(s) occured. Please check these as you may need to manually fix them."
    fi
    echo 'End OpenLiteSpeed one click Uninstallation << << << << << << <<'
}


function install_openlitespeed
{
    echo "Start setup OpenLiteSpeed"
    local STATUS=Install
    if [ "$OLSINSTALLED" = "1" ] ; then
        OLS_VERSION=$(cat "$SERVER_ROOT"/VERSION)
        wget -qO "$SERVER_ROOT"/release.tmp  http://open.litespeedtech.com/packages/release?ver=$OLS_VERSION
        LATEST_VERSION=$(cat "$SERVER_ROOT"/release.tmp)
        rm "$SERVER_ROOT"/release.tmp
        if [ "$OLS_VERSION" = "$LATEST_VERSION" ] ; then
            STATUS=Reinstall
            echo "OpenLiteSpeed is already installed with the latest version, will attempt to reinstall it."
        else
            STATUS=Update
            echo "OpenLiteSpeed is already installed and newer version is available, will attempt to update it."
        fi
    fi

    if [ "$OSNAME" = "centos" ] ; then
        install_ols_centos $STATUS
    else
        install_ols_debian $STATUS
    fi
    silent killall -9 lsphp
    echo "End setup OpenLiteSpeed"
}


function gen_selfsigned_cert
{
    if [ -e $CONFFILE ] ; then
        source $CONFFILE 2>/dev/null
        if [ $? != 0 ]; then
            . $CONFFILE
        fi
    fi

    SSL_COUNTRY="${SSL_COUNTRY:-US}"
    SSL_STATE="${SSL_STATE:-New Jersey}"
    SSL_LOCALITY="${SSL_LOCALITY:-Virtual}"
    SSL_ORG="${SSL_ORG:-LiteSpeedCommunity}"
    SSL_ORGUNIT="${SSL_ORGUNIT:-Testing}"
    SSL_HOSTNAME="${SSL_HOSTNAME:-webadmin}"
    SSL_EMAIL="${SSL_EMAIL:-.}"
    COMMNAME=$(hostname)
    
    cat << EOF > $CSR
[req]
prompt=no
distinguished_name=openlitespeed
[openlitespeed]
commonName = ${COMMNAME}
countryName = ${SSL_COUNTRY}
localityName = ${SSL_LOCALITY}
organizationName = ${SSL_ORG}
organizationalUnitName = ${SSL_ORGUNIT}
stateOrProvinceName = ${SSL_STATE}
emailAddress = ${SSL_EMAIL}
name = openlitespeed
initials = CP
dnQualifier = openlitespeed
[server_exts]
extendedKeyUsage=1.3.6.1.5.5.7.3.1
EOF
    openssl req -x509 -config $CSR -extensions 'server_exts' -nodes -days 820 -newkey rsa:2048 -keyout ${KEY} -out ${CERT} >/dev/null 2>&1
    rm -f $CSR
    
    mv ${KEY}   $SERVER_ROOT/conf/$KEY
    mv ${CERT}  $SERVER_ROOT/conf/$CERT
    chmod 0600 $SERVER_ROOT/conf/$KEY
    chmod 0600 $SERVER_ROOT/conf/$CERT
}


function set_ols_password
{
    ENCRYPT_PASS=`"$SERVER_ROOT/admin/fcgi-bin/admin_php" -q "$SERVER_ROOT/admin/misc/htpasswd.php" $ADMINPASSWORD`
    if [ $? = 0 ] ; then
        echo "admin:$ENCRYPT_PASS" > "$SERVER_ROOT/admin/conf/htpasswd"
        if [ $? = 0 ] ; then
            echo "Set OpenLiteSpeed Web Admin access."
        else
            echo "OpenLiteSpeed WebAdmin password not changed."
        fi
    fi
}

function config_server
{
    if [ "$INSTALLWORDPRESS" != "1" ]; then 
        if [ -e "${WEBCF}" ] ; then
            sed -i -e "s/adminEmails/adminEmails $EMAIL\n#adminEmails/" "${WEBCF}"
            sed -i -e "s/8088/$WPPORT/" "${WEBCF}"
            sed -i -e "s/ls_enabled/ls_enabled   1\n#/" "${WEBCF}"

            cat >> ${WEBCF} <<END

listener Defaultssl {
address                 *:$SSLWPPORT
secure                  1
map                     Example *
keyFile                 $SERVER_ROOT/conf/$KEY
certFile                $SERVER_ROOT/conf/$CERT
}

END
            chown -R lsadm:lsadm $SERVER_ROOT/conf/
        else
            echo "${WEBCF} is missing. It appears that something went wrong during OpenLiteSpeed installation."
            ALLERRORS=1
        fi
        echo ols1clk > "$SERVER_ROOT/PLAT"
    fi
}

function config_vh_wp
{
    echo 'Start setup virtual host config'
    if [ -e "${WEBCF}" ] ; then
        cat ${WEBCF} | grep "virtualhost wordpress" >/dev/null
        if [ $? != 0 ] ; then
            sed -i -e "s/adminEmails/adminEmails $EMAIL\n#adminEmails/" "${WEBCF}"
            sed -i -e "s/ls_enabled/ls_enabled   1\n#/" "${WEBCF}"

            VHOSTCONF=$SERVER_ROOT/conf/vhosts/wordpress/vhconf.conf
            echo "${FPACE} - Check existing port"
            grep "address.*:${WPPORT}$\|${SSLWPPORT}$"  ${WEBCF} >/dev/null 2>&1
            if [ ${?} = 0 ]; then
                echo "Detect port ${WPPORT} || ${SSLWPPORT}, will skip domain setup!"
            else   
                echo "${FPACE} - Create wordpress listener"  
                cat >> ${WEBCF} <<END

listener wordpress {
address                 *:$WPPORT
secure                  0
map                     wordpress $SITEDOMAIN
}


listener wordpressssl {
address                 *:$SSLWPPORT
secure                  1
map                     wordpress $SITEDOMAIN
keyFile                 $SERVER_ROOT/conf/$KEY
certFile                $SERVER_ROOT/conf/$CERT
}

END
            fi
            echo "${FPACE} - Insert wordpress virtual host"  
            cat >> ${WEBCF} <<END

virtualhost wordpress {
vhRoot                  $WORDPRESSPATH
configFile              $VHOSTCONF
allowSymbolLink         1
enableScript            1
restrained              0
setUIDMode              2
}
END
            echo "${FPACE} - Create wordpress virtual host conf"
            mkdir -p $SERVER_ROOT/conf/vhosts/wordpress/
            cat > $VHOSTCONF <<END
docRoot                   \$VH_ROOT/
index  {
  useServer               0
  indexFiles              index.php
}

context / {
  location                \$VH_ROOT
  allowBrowse             1
  indexFiles              index.php

  rewrite  {
    enable                1
    inherit               1
    rewriteFile           $WORDPRESSPATH/.htaccess
  }
}

rewrite  {
  enable                  1
  autoLoadHtaccess        1
}

END
            chown -R lsadm:lsadm $SERVER_ROOT/conf/
        else 
            echo "${FPACE} - Detect wordpress exist, will skip virtual host conf setup!"
        fi
    else
        echo "${WEBCF} is missing. It appears that something went wrong during OpenLiteSpeed installation."
        ALLERRORS=1
    fi
    echo ols1clk > "$SERVER_ROOT/PLAT"
    echo 'End setup virtual host config'
}


function activate_cache
{
    cat > $WORDPRESSPATH/activate_cache.php <<END
<?php
include '$WORDPRESSPATH/wp-load.php';
include_once '$WORDPRESSPATH/wp-admin/includes/plugin.php';
include_once '$WORDPRESSPATH/wp-admin/includes/file.php';
define('WP_ADMIN', true);
activate_plugin('litespeed-cache/litespeed-cache.php', '', false, false);

END
    $SERVER_ROOT/fcgi-bin/lsphpnew $WORDPRESSPATH/activate_cache.php
    rm $WORDPRESSPATH/activate_cache.php
}


function check_cur_status
{
    if [ -e $SERVER_ROOT/bin/openlitespeed ] ; then
        OLSINSTALLED=1
    else
        OLSINSTALLED=0
    fi

    which mysqladmin  >/dev/null 2>&1
    if [ $? = 0 ] ; then
        MYSQLINSTALLED=1
    else
        MYSQLINSTALLED=0
    fi
}

function changeOlsPassword
{
    LSWS_HOME=$SERVER_ROOT
    ENCRYPT_PASS=`"$LSWS_HOME/admin/fcgi-bin/admin_php" -q "$LSWS_HOME/admin/misc/htpasswd.php" $ADMINPASSWORD`
    echo "$ADMIN_USER:$ENCRYPT_PASS" > "$LSWS_HOME/admin/conf/htpasswd"
    echo "Finished setting OpenLiteSpeed WebAdmin password to $ADMINPASSWORD."
}


function uninstall
{
    if [ "$OLSINSTALLED" = "1" ] ; then
        echo "${FPACE} - Stop OpenLiteSpeed"
        silent $SERVER_ROOT/bin/lswsctrl stop
        echo "${FPACE} - Stop LSPHP"
        silent killall -9 lsphp
        if [ "$OSNAME" = "centos" ] ; then
            uninstall_php_centos
            uninstall_ols_centos
        else
            uninstall_php_debian
            uninstall_ols_debian 
        fi
        echo Uninstalled.
    else
        echo "OpenLiteSpeed not installed."
    fi
}

function read_password
{
    if [ "$1" != "" ] ; then
        TEMPPASSWORD=$1
    else
        passwd=
        echo "Please input password for $2(press enter to get a random one):"
        read passwd
        if [ "$passwd" = "" ] ; then
            TEMPPASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16 ; echo '')
        else
            TEMPPASSWORD=$passwd
        fi
    fi
}

function check_php_param
{
    if [ "$OSNAMEVER" = "UBUNTU20" ] || [ "$OSNAMEVER" = "UBUNTU18" ] || [ "$OSNAMEVER" = "DEBIAN9" ] || [ "$OSNAMEVER" = "DEBIAN10" ]; then
        if [ "$LSPHPVER" = "56" ]; then
            echo "We do not support lsphp$LSPHPVER on $OSNAMEVER, lsphp73 will be used instead."
            LSPHPVER=73
        fi
    fi
}

function check_value_follow
{
    FOLLOWPARAM=$1
    local PARAM=$1
    local KEYWORD=$2

    if [ "$1" = "-n" ] || [ "$1" = "-e" ] || [ "$1" = "-E" ] ; then
        FOLLOWPARAM=
    else
        local PARAMCHAR=$(echo $1 | awk '{print substr($0,1,1)}')
        if [ "$PARAMCHAR" = "-" ] ; then
            FOLLOWPARAM=
        fi
    fi

    if [ -z "$FOLLOWPARAM" ] ; then
        if [ ! -z "$KEYWORD" ] ; then
            echo "Error: '$PARAM' is not a valid '$KEYWORD', please check and try again."
            usage
        fi
    fi
}


function fixLangTypo
{
    WP_LOCALE="af ak sq am ar hy rup_MK as az az_TR ba eu bel bn_BD bs_BA bg_BG my_MM ca bal zh_CN \
      zh_HK zh_TW co hr cs_CZ da_DK dv nl_NL nl_BE en_US en_AU 	en_CA en_GB eo et fo fi fr_BE fr_FR \
      fy fuc gl_ES ka_GE de_DE de_CH el gn gu_IN haw_US haz he_IL hi_IN hu_HU is_IS ido id_ID ga it_IT \
      ja jv_ID kn kk km kin ky_KY ko_KR ckb lo lv li lin lt_LT lb_LU mk_MK mg_MG ms_MY ml_IN mr xmf mn \
      me_ME ne_NP nb_NO nn_NO ory os ps fa_IR fa_AF pl_PL pt_BR pt_PT pa_IN rhg ro_RO ru_RU ru_UA rue \
      sah sa_IN srd gd sr_RS sd_PK si_LK sk_SK sl_SI so_SO azb es_AR es_CL es_CO es_MX es_PE es_PR es_ES \
      es_VE su_ID sw sv_SE gsw tl tg tzm ta_IN ta_LK tt_RU te th bo tir tr_TR tuk ug_CN uk ur uz_UZ vi \
      wa cy yor"
    LANGSTR=$(echo "$WPLANGUAGE" | awk '{print tolower($0)}')
    if [ "$LANGSTR" = "zh_cn" ] || [ "$LANGSTR" = "zh-cn" ] || [ "$LANGSTR" = "cn" ] ; then
        WPLANGUAGE=zh_CN
    fi

    if [ "$LANGSTR" = "zh_tw" ] || [ "$LANGSTR" = "zh-tw" ] || [ "$LANGSTR" = "tw" ] ; then
        WPLANGUAGE=zh_TW
    fi
    echo ${WP_LOCALE} | grep -w "${WPLANGUAGE}" -q
    if [ ${?} != 0 ]; then 
        echo "${WPLANGUAGE} language not found." 
        echo "Please check $WP_LOCALE"
        exit 1
    fi
}

function updatemyself
{
    local CURMD=$(md5sum "$0" | cut -d' ' -f1)
    local SERVERMD=$(md5sum  <(wget $MYGITHUBURL -O- 2>/dev/null)  | cut -d' ' -f1)
    if [ "$CURMD" = "$SERVERMD" ] ; then
        echo "You already have the latest version installed."
    else
        wget -O "$0" $MYGITHUBURL
        CURMD=$(md5sum "$0" | cut -d' ' -f1)
        if [ "$CURMD" = "$SERVERMD" ] ; then
            echo "Updated."
        else
            echo "Tried to update but seems to be failed."
        fi
    fi
    exit 0
}

function uninstall_warn
{
    if [ "$FORCEYES" != "1" ] ; then
        echo
        printf "\033[31mAre you sure you want to uninstall? Type 'Y' to continue, otherwise will quit.[y/N]\033[0m "
        read answer
        echo

        if [ "$answer" != "Y" ] && [ "$answer" != "y" ] ; then
            echo "Uninstallation aborted!"
            exit 0
        fi
        echo 
    fi
    echo 'Start OpenLiteSpeed one click Uninstallation >> >> >> >> >> >> >>'
}

function befor_install_display
{
    echo
    echo "Starting to install OpenLiteSpeed to $SERVER_ROOT/ with the parameters below,"
    echo "WebAdmin password:        " "$ADMINPASSWORD"
    echo "WebAdmin email:           " "$EMAIL"
    echo "LSPHP version:            " "$LSPHPVER"
    echo "MariaDB version:          " "$MARIADBVER"

    if [ "$INSTALLWORDPRESS" = "1" ] ; then
        echo "Install WordPress:        " Yes
        echo "WordPress HTTP port:      " "$WPPORT"
        echo "WordPress HTTPS port:     " "$SSLWPPORT"
        echo "WordPress language:       " "$WPLANGUAGE"        
        echo "Web site domain:          " "$SITEDOMAIN"
        echo "MySQL root Password:      " "$ROOTPASSWORD"
        echo "Database name:            " "$DATABASENAME"
        echo "Database username:        " "$USERNAME"
        echo "Database password:        " "$USERPASSWORD"

        if [ "$INSTALLWORDPRESSPLUS" = "1" ] ; then
            echo "WordPress plus:           " Yes
            echo "WordPress site title:     " "$WPTITLE"
            echo "WordPress username:       " "$WPUSER"
            echo "WordPress password:       " "$WPPASSWORD"
        else
            echo "WordPress plus:           " No
        fi


        if [ -e "$WORDPRESSPATH/wp-config.php" ] ; then
            echo "WordPress location:       " "$WORDPRESSPATH (Exsiting)"
            WORDPRESSINSTALLED=1
        else
            echo "WordPress location:       " "$WORDPRESSPATH (New install)"
            WORDPRESSINSTALLED=0
        fi
    else
        echo "Server HTTP port:         " "$WPPORT"
        echo "Server HTTPS port:        " "$SSLWPPORT"
    fi
    echo "Your password will be written to file:  $SERVER_ROOT/password"
    echo 
    if [ "$FORCEYES" != "1" ] ; then
        printf 'Are these settings correct? Type n to quit, otherwise will continue. [Y/n]'
        read answer
        if [ "$answer" = "N" ] || [ "$answer" = "n" ] ; then
            echo "Aborting installation!"
            exit 0
        fi
    fi  
    echo 'Start OpenLiteSpeed one click installation >> >> >> >> >> >> >>'
}

function install_wp_cli
{
    if [ -e /usr/local/bin/wp ]; then 
        echo 'WP CLI already exist'
		wp cli update --yes
    else    
        echo "Install wp_cli"
        wget -qO /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        chmod +x /usr/local/bin/wp
		wp cli update --yes
    fi
    if [ ! -e /usr/bin/php ] && [ ! -L /usr/bin/php ]; then
        ln -s ${SERVER_ROOT}/lsphp${LSPHPVER}/bin/php /usr/bin/php
    elif [ ! -e /usr/bin/php ]; then 
        rm -f /usr/bin/php > /dev/null 2>&1
        ln -s ${SERVER_ROOT}/lsphp${LSPHPVER}/bin/php /usr/bin/php  
    else 
        echo '/usr/bin/php symlink exist, skip symlink.'    
    fi
}

function main_install_wordpress
{
    if [ "${PURE_DB}" = '1' ]; then 
        echo 'Install MariaDB only'
        pure_mariadb
    else
        if [ "$WORDPRESSINSTALLED" = '1' ] ; then
            echo 'Skip WordPress installation!'
        else
            if [ "$INSTALLWORDPRESS" = "1" ] ; then
                install_wp_cli
                config_vh_wp
                check_port_usage
                if [ "$MYSQLINSTALLED" != "1" ] ; then
                    install_mysql
                else
                    test_mysql_password
                fi
                if [ "$TESTPASSWORDERROR" = "1" ] ; then
                    echo "MySQL setup bypassed, can not get root password."
                else
                    ROOTPASSWORD=$CURROOTPASSWORD
                    setup_mysql
                fi
                download_wordpress
                create_wordpress_cf
                if [ "$INSTALLWORDPRESSPLUS" = "1" ] ; then            
                    install_wordpress_core
                    echo "WordPress administrator username is [$WPUSER], password is [$WPPASSWORD]." >> $SERVER_ROOT/password  
                fi
                change_owner ${WORDPRESSPATH}
                echo "mysql WordPress DataBase name is [$DATABASENAME], username is [$USERNAME], password is [$USERPASSWORD]." >> $SERVER_ROOT/password    
                echo "mysql root password is [$ROOTPASSWORD]." >> $SERVER_ROOT/password        
            fi
        fi 
    fi    
}

function check_port_usage
{
    if [ "$WPPORT" = "80" ] || [ "$SSLWPPORT" = "443" ]; then
        echo "Avoid port 80/443 conflict."
        killall -9 apache  >/dev/null 2>&1
        killall -9 apache2  >/dev/null 2>&1
        killall -9 httpd    >/dev/null 2>&1
        killall -9 nginx    >/dev/null 2>&1
    fi
}

function after_install_display
{
    chmod 600 "$SERVER_ROOT/password"
    if [ "$ALLERRORS" = "0" ] ; then
        echo "Congratulations! Installation finished."
    else
        echo "Installation finished. Some errors seem to have occured, please check this as you may need to manually fix them."
    fi
    if [ "$INSTALLWORDPRESSPLUS" = "0" ] && [ "$INSTALLWORDPRESS" = "1" ] && [ "${PURE_DB}" = '0' ]; then
        echo "Please access http://server_IP:$WPPORT/ to finish setting up your WordPress site."
        echo "And also you may want to activate the LiteSpeed Cache plugin to get better performance."
    fi
    echo 'End OpenLiteSpeed one click installation << << << << << << <<'
    echo
}

function test_page
{
    local URL=$1
    local KEYWORD=$2
    local PAGENAME=$3
    curl -skL  $URL | grep -i "$KEYWORD" >/dev/null 2>&1
    if [ $? != 0 ] ; then
        echo "Error: $PAGENAME failed."
        TESTGETERROR=yes
    else
        echo "OK: $PAGENAME passed."
    fi
}

function test_ols_admin
{
    test_page https://localhost:7080/ "LiteSpeed WebAdmin" "test webAdmin page"
}

function test_ols
{
    test_page http://localhost:$WPPORT/  Congratulation "test Example HTTP vhost page"
    test_page https://localhost:$SSLWPPORT/  Congratulation "test Example HTTPS vhost page"
}

function test_wordpress
{
    test_page http://localhost:8088/  Congratulation "test Example vhost page"
    test_page http://localhost:$WPPORT/ "WordPress" "test wordpress HTTP first page"
    test_page https://localhost:$SSLWPPORT/ "WordPress" "test wordpress HTTPS first page"
}

function test_wordpress_plus
{
    test_page http://localhost:8088/  Congratulation "test Example vhost page"
    test_page http://$SITEDOMAIN:$WPPORT/ WordPress "test wordpress HTTP first page"
    test_page https://$SITEDOMAIN:$SSLWPPORT/ WordPress "test wordpress HTTPS first page"
}


function main_ols_test
{
    echo "Start auto testing >> >> >> >>"
    test_ols_admin
    if [ "${PURE_DB}" = '1' ]; then 
        test_ols
    elif [ "$INSTALLWORDPRESS" = "1" ] ; then
        if [ "$INSTALLWORDPRESSPLUS" = "1" ] ; then
            test_wordpress_plus
        else
            test_wordpress
        fi
    else
        test_ols
    fi

    if [ "${TESTGETERROR}" = "yes" ] ; then
        echo "Errors were encountered during testing. In many cases these errors can be solved manually by referring to installation logs."
        echo "Service loading issues can sometimes be resolved by performing a restart of the web server."
        echo "Reinstalling the web server can also help if neither of the above approaches resolve the issue."
    fi

    echo "End auto testing << << << <<"
    echo 'Thanks for using OpenLiteSpeed One click installation!'
    echo
}

function main_init_check
{
    check_root
    check_os
    check_cur_status
    check_php_param
}

function main_init_package
{
    update_centos_hashlib
    update_system
    check_wget
    check_curl
}

function main
{
    display_license
    main_init_check
    action_uninstall
    action_purgeall
    update_email
    main_gen_password
    befor_install_display
    main_init_package
    install_openlitespeed
    main_set_password
    gen_selfsigned_cert
    main_install_wordpress
    config_server
    restart_lsws
    after_install_display
    main_ols_test
}

while [ ! -z "${1}" ] ; do
    case "${1}" in
        -[aA] | --adminpassword )  
                check_value_follow "$2" ""
                if [ ! -z "$FOLLOWPARAM" ] ; then shift; fi
                ADMINPASSWORD=$FOLLOWPARAM
                ;;
        -[eE] | --email )          
                check_value_follow "$2" "email address"
                shift
                EMAIL=$FOLLOWPARAM
                ;;
        --lsphp )           
                check_value_follow "$2" "LSPHP version"
                shift
                cnt=${#LSPHPVERLIST[@]}
                for (( i = 0 ; i < cnt ; i++ )); do
                    if [ "$1" = "${LSPHPVERLIST[$i]}" ] ; then LSPHPVER=$1; fi
                done
                ;;
        --mariadbver )      
                check_value_follow "$2" "MariaDB version"
                shift
                cnt=${#MARIADBVERLIST[@]}
                for (( i = 0 ; i < cnt ; i++ )); do 
                    if [ "$1" = "${MARIADBVERLIST[$i]}" ] ; then MARIADBVER=$1; fi 
                done
                ;;
        --pure-mariadb )
                PURE_DB=1
                ;;        
        -[wW] | --wordpress )      
                INSTALLWORDPRESS=1
                ;;
        --wordpressplus )  
                check_value_follow "$2" "domain"
                shift
                SITEDOMAIN=$FOLLOWPARAM
                INSTALLWORDPRESS=1
                INSTALLWORDPRESSPLUS=1
                ;;
        --wordpresspath )  
                check_value_follow "$2" "WordPress path"
                shift
                WORDPRESSPATH=$FOLLOWPARAM
                INSTALLWORDPRESS=1
                ;;
        -[rR] | --dbrootpassword ) 
                check_value_follow "$2" ""
                if [ ! -z "$FOLLOWPARAM" ] ; then shift; fi
                ROOTPASSWORD=$FOLLOWPARAM
                ;;
        --dbname )         
                check_value_follow "$2" "database name"
                shift
                DATABASENAME=$FOLLOWPARAM
                ;;
        --dbuser )         
                check_value_follow "$2" "database username"
                shift
                USERNAME=$FOLLOWPARAM
                ;;
        --dbpassword )     
                check_value_follow "$2" ""
                if [ ! -z "$FOLLOWPARAM" ] ; then shift; fi
                USERPASSWORD=$FOLLOWPARAM
                ;;
        --listenport )      
                check_value_follow "$2" "HTTP listen port"
                shift
                WPPORT=$FOLLOWPARAM
                ;;
        --ssllistenport )   
                check_value_follow "$2" "HTTPS listen port"
                shift
                SSLWPPORT=$FOLLOWPARAM
                ;;
        --wpuser )          
               check_value_follow "$2" "WordPress user"
                shift
                WPUSER=$1
                ;;
        --wppassword )      
                check_value_follow "$2" ""
                if [ ! -z "$FOLLOWPARAM" ] ; then shift; fi
                WPPASSWORD=$FOLLOWPARAM
                ;;
        --wplang )          
                check_value_follow "$2" "WordPress language"
                shift
                WPLANGUAGE=$FOLLOWPARAM
                fixLangTypo
                ;;
        --sitetitle )       
                check_value_follow "$2" "WordPress website title"
                shift
                WPTITLE=$FOLLOWPARAM
                ;;
        -[Uu] | --uninstall )       
                ACTION=UNINSTALL
                ;;
        -[Pp] | --purgeall )        
                ACTION=PURGEALL
                ;;
        -[qQ] | --quiet )           
                FORCEYES=1
                ;;
        -V | --version )     
                display_license
                exit 0
                ;;
        --update )         
                updatemyself
                ;;
        -v | --verbose )             
                VERBOSE=1
                APT='apt-get'
                YUM='yum'
                ;;
        -[hH] | --help )           
                usage
                ;;
        * )                     
                usage
                ;;
    esac
    shift
done

main
