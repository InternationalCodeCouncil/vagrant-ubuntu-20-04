timedatectl set-timezone $TIMEZONE

echo '==> Setting time zone to '$(cat /etc/timezone)

echo '==> Setting Ubuntu repositories'

apt-get -q=2 update --fix-missing

echo '==> Installing Linux tools'

cp /vagrant/config/bash_aliases /home/vagrant/.bash_aliases
chown vagrant:vagrant /home/vagrant/.bash_aliases
apt-get -q=2 install software-properties-common bash-completion curl tree zip unzip pv whois > /dev/null 2>&1

echo '==> Installing Git'

apt-get -q=2 install git git-man > /dev/null 2>&1

echo '==> Installing Apache'

apt-get -q=2 install apache2 apache2-utils > /dev/null 2>&1
apt-get -q=2 update
cp /vagrant/config/localhost.conf /etc/apache2/conf-available/localhost.conf
cp /vagrant/config/virtualhost.conf /etc/apache2/sites-available/virtualhost.conf
sed -i 's|GUEST_SYNCED_FOLDER|'$GUEST_SYNCED_FOLDER'|' /etc/apache2/sites-available/virtualhost.conf
sed -i 's|FORWARDED_PORT_80|'$FORWARDED_PORT_80'|' /etc/apache2/sites-available/virtualhost.conf
a2enconf localhost > /dev/null 2>&1
a2enmod rewrite vhost_alias > /dev/null 2>&1
a2ensite virtualhost > /dev/null 2>&1

echo '==> Installing Subversion'

apt-get -q=2 install subversion > /dev/null 2>&1

echo '==> Setting MariaDB 10.6 repository'

apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc' > /dev/null 2>&1
cp /vagrant/config/MariaDB.list /etc/apt/sources.list.d/MariaDB.list
apt-get -q=2 update

echo '==> Installing MariaDB'

DEBIAN_FRONTEND=noninteractive apt-get -q=2 install mariadb-server > /dev/null 2>&1

echo '==> Setting PHP 7.4 repository'

add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1
apt-get -q=2 update

echo '==> Installing PHP'

apt-get -q=2 install php7.4 libapache2-mod-php7.4 libphp7.4-embed \
    php7.4-bcmath php7.4-bz2 php7.4-cli php7.4-curl php7.4-fpm php7.4-gd php7.4-imap php7.4-intl php7.4-json \
    php7.4-mbstring php7.4-mysql php7.4-mysqlnd php7.4-opcache php7.4-pgsql php7.4-pspell php7.4-readline \
    php7.4-soap php7.4-sqlite3 php7.4-tidy php7.4-xdebug php7.4-xml php7.4-xmlrpc php7.4-yaml php7.4-zip > /dev/null 2>&1
a2dismod mpm_event > /dev/null 2>&1
a2enmod mpm_prefork > /dev/null 2>&1
a2enmod php7.4 > /dev/null 2>&1
cp /vagrant/config/php.ini.htaccess /var/www/.htaccess
PHP_ERROR_REPORTING_INT=$(php -r 'echo '"$PHP_ERROR_REPORTING"';')
sed -i 's|PHP_ERROR_REPORTING_INT|'$PHP_ERROR_REPORTING_INT'|' /var/www/.htaccess

echo '==> Installing Adminer'

if [ ! -d /usr/share/adminer ]; then
    mkdir -p /usr/share/adminer
    curl -LsS https://www.adminer.org/latest-en.php -o /usr/share/adminer/adminer.php
    sed -i 's|{if($F=="")return|{if(true)|' /usr/share/adminer/adminer.php
    curl -LsS https://raw.githubusercontent.com/vrana/adminer/master/designs/nicu/adminer.css -o /usr/share/adminer/adminer.css
fi
cp /vagrant/config/adminer.conf /etc/apache2/conf-available/adminer.conf
sed -i 's|FORWARDED_PORT_80|'$FORWARDED_PORT_80'|' /etc/apache2/conf-available/adminer.conf
a2enconf adminer > /dev/null 2>&1

echo '==> Starting Apache'

apache2ctl configtest
service apache2 restart

echo '==> Starting MariaDB'

service mysql restart
mysqladmin -u root password ""

echo '==> Cleaning apt cache'

apt-get -q=2 autoclean
apt-get -q=2 autoremove

echo '==> Versions:'

lsb_release -d | cut -f 2
openssl version
curl --version | head -n1 | cut -d '(' -f 1
svn --version | grep svn,
git --version
apache2 -v | head -n1
mysql -V
php -v | head -n1
python2 --version 2>/dev/stdout
python3 --version
