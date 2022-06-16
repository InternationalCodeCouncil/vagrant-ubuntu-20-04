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

echo '==> Setting MariaDB 10.3 repository'

apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc' &>/dev/null
cp /vagrant/config/MariaDB.list /etc/apt/sources.list.d/MariaDB.list
apt-get -q=2 update

echo '==> Installing MariaDB'

DEBIAN_FRONTEND=noninteractive apt-get -q=2 install mariadb-server=10.3 -y &>/dev/null

echo '==> Setting Up ElasticSearch Repository'

curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list
apt-get -q=2 update
DEBIAN_FRONTEND=noninteractive apt-get -q=2 install elasticsearch &>/dev/null

echo '==> Installing Elasticsearch Plugins'

/usr/share/elasticsearch/bin/elasticsearch-plugin install analysis-phonetic analysis-icu

echo '==> Enabling Elasticsearch'
systemctl start elasticsearch
systemctl enable elasticsearch



echo '==> Setting PHP 7.4 repository'

add-apt-repository -y ppa:ondrej/php &>/dev/null
apt-get -q=2 update

echo '==> Installing PHP'

apt-get -q=2 install php7.4 libapache2-mod-php7.4 libphp7.4-embed \
    php7.4-bcmath php7.4-gmp php7.4-bz2 php7.4-cli php7.4-curl php7.4-fpm php7.4-gd php7.4-imap php7.4-intl php7.4-json \
    php7.4-mbstring php7.4-mysql php7.4-mysqlnd php7.4-opcache php7.4-pgsql php7.4-pspell php7.4-readline \
    php7.4-soap php7.4-sqlite3 php7.4-tidy php7.4-xdebug php7.4-xml php7.4-xmlrpc php7.4-yaml php7.4-zip &>/dev/null
a2dismod mpm_event &>/dev/null
a2enmod mpm_prefork &>/dev/null
a2enmod php7.4 &>/dev/null
cp /vagrant/config/php.ini.htaccess /var/www/.htaccess
PHP_ERROR_REPORTING_INT=$(php -r 'echo '"$PHP_ERROR_REPORTING"';')
sed -i 's|PHP_ERROR_REPORTING_INT|'$PHP_ERROR_REPORTING_INT'|' /var/www/.htaccess

echo '==> Installing Composer'
cd ~
curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
php -r "if (hash_file('SHA384', '/tmp/composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer

composer self-update 1.10.26

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

service mysql restart
mysqladmin -u root password ""

echo '==>Importing dbs from /home/vagrant/dbs/'
cd /home/vagrant/dbs/ && cat *.sql | mysql -u root

echo '==> Cleaning apt cache'

apt-get -q=2 autoclean
apt-get -q=2 autoremove

echo '==> Setup static pwd for vagrant user(vagrant)'

sed -i 's/^#* *\(PermitRootLogin\)\(.*\)$/\1 yes/' /etc/ssh/sshd_config
sed -i 's/^#* *\(PasswordAuthentication\)\(.*\)$/\1 yes/' /etc/ssh/sshd_config
systemctl restart sshd.service
echo -e "vagrant\nvagrant" | (passwd vagrant)
echo -e "root\nroot" | (passwd root)

echo '==> Versions:'

lsb_release -d | cut -f 2
openssl version
curl --version | head -n1 | cut -d '(' -f 1
svn --version | grep svn,
git --version
apache2 -v | head -n1
mysql -V
elasticsearch --version

php -v | head -n1
python2 --version 2>/dev/stdout
python3 --version
