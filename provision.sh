timedatectl set-timezone $TIMEZONE

echo '==> Setting time zone to '$(cat /etc/timezone)

echo '==> Setting Ubuntu repositories'

apt-get -q=2 update --fix-missing

echo '==> Installing Linux tools'

cp /vagrant/config/bash_aliases /home/vagrant/.bash_aliases
chown vagrant:vagrant /home/vagrant/.bash_aliases
apt-get -q=2 install software-properties-common bash-completion curl tree zip unzip pv whois &>/dev/null

echo '==> Installing Git and Subversion'

apt-get -q=2 install git subversion &>/dev/null

echo '==> Installing Apache'

apt-get -q=2 install apache2 apache2-utils &>/dev/null
apt-get -q=2 update
cp /vagrant/config/localhost.conf /etc/apache2/conf-available/localhost.conf
cp /vagrant/config/virtualhost.conf /etc/apache2/sites-available/virtualhost.conf
sed -i 's|GUEST_SYNCED_FOLDER|'$GUEST_SYNCED_FOLDER'|' /etc/apache2/sites-available/virtualhost.conf
sed -i 's|FORWARDED_PORT_80|'$FORWARDED_PORT_80'|' /etc/apache2/sites-available/virtualhost.conf
a2enconf localhost &>/dev/null
a2enmod rewrite vhost_alias &>/dev/null
a2ensite virtualhost &>/dev/null

echo '==> Setting MariaDB 10.4 repository'

apt-get -q=2 update
apt-get install software-properties-common gnupg -y
apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
add-apt-repository --remove 'https://mirrors.evowise.com/mariadb/repo/10.4/ubuntu'
add-apt-repository 'deb [arch=amd64,arm64,ppc64el] https://mirror.netcologne.de/mariadb/repo/10.4/ubuntu focal main'

echo '==> Installing MariaDB'
apt-get -q=2 update
DEBIAN_FRONTEND=noninteractive apt-get -q=2 install mariadb-server

echo '==> Setting Up ElasticSearch Repository'

curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list
apt-get -q=2 update
DEBIAN_FRONTEND=noninteractive apt-get -q=2 install elasticsearch

echo '==> Enabling Elasticsearch'
systemctl start elasticsearch
systemctl enable elasticsearch

cd /usr/share/elasticsearch 
bin/elasticsearch-plugin install analysis-phonetic
bin/elasticsearch-plugin install analysis-icu
cd /home/vagrant/

echo '==> Setting PHP 8.1 repository'

add-apt-repository -y ppa:ondrej/php &>/dev/null
apt-get -q=2 update

echo '==> Installing PHP'

apt-get -q=2 install php8.1 libapache2-mod-php8.1 libphp8.0-embed \
	php8.1-ctype php8.1-dom php8.1-fileinfo php8.1-iconv php8.1-simplexml \
	php8.1-sockets php8.1-tokenizer php8.1-xmlwriter php8.1-xsl \
    php8.1-bcmath php8.1-gmp php8.1-bz2 php8.1-cli php8.1-curl php8.1-fpm php8.1-gd php8.1-imap php8.1-intl \
    php8.1-mbstring php8.1-mysql php8.1-mysqlnd php8.1-opcache php8.1-pgsql php8.1-pspell php8.1-readline \
    php8.1-soap php8.1-sqlite3 php8.1-tidy php8.1-xdebug php8.1-xml php8.1-xmlrpc php8.1-yaml php8.1-zip
	
a2dismod mpm_event &>/dev/null
a2enmod mpm_prefork &>/dev/null
a2enmod php8.1 &>/dev/null
a2enmod headers &>/dev/null
cp /vagrant/config/php.ini.htaccess /var/www/.htaccess
PHP_ERROR_REPORTING_INT=$(php -r 'echo '"$PHP_ERROR_REPORTING"';')
sed -i 's|PHP_ERROR_REPORTING_INT|'$PHP_ERROR_REPORTING_INT'|' /var/www/.htaccess

echo '==> Installing Composer'
cd ~
curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
php -r "if (hash_file('SHA384', '/tmp/composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer

composer self-update 2.2.18

echo '==> Installing Adminer'

if [ ! -d /usr/share/adminer ]; then
    mkdir -p /usr/share/adminer
    curl -LsS https://www.adminer.org/latest-en.php -o /usr/share/adminer/adminer.php
    sed -i 's|{if($F=="")return|{if(true)|' /usr/share/adminer/adminer.php
    curl -LsS https://raw.githubusercontent.com/vrana/adminer/master/designs/nicu/adminer.css -o /usr/share/adminer/adminer.css
fi
cp /vagrant/config/adminer.conf /etc/apache2/conf-available/adminer.conf
sed -i 's|FORWARDED_PORT_80|'$FORWARDED_PORT_80'|' /etc/apache2/conf-available/adminer.conf
a2enconf adminer &>/dev/null

echo '==> Starting Apache'

apache2ctl configtest
service apache2 restart

echo '==> Starting MariaDB'

service mariadb restart
mysqladmin -u root password ""

echo '==> Cleaning apt cache'

apt-get -q=2 autoclean
apt-get -q=2 autoremove

echo '==> Setup static pwd for vagrant user(12345)'
echo "12345" | passwd --stdin vagrant

echo '==> Versions:'

lsb_release -d | cut -f 2
openssl version
curl --version | head -n1 | cut -d '(' -f 1
svn --version | grep svn,
git --version
apache2 -v | head -n1
mariadb -V
bin/elasticsearch --version

php -v | head -n1
python2 --version 2>/dev/stdout
python3 --version
