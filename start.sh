#!/bin/bash

if [ ! -f /var/www/html/sites/default/settings.php ]; then
	# Upgrade debian packages
	DEBIAN_FRONTEND=noninteractive apt-get update
	DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

	# Start mysql
	/usr/bin/mysqld_safe & 
	sleep 10s
	
	# Generate random passwords 
	DRUPAL_DB="drupal"
	MYSQL_PASSWORD=`pwgen -c -n -1 12`
	DRUPAL_PASSWORD=`pwgen -c -n -1 12`
	echo mysql root password: $MYSQL_PASSWORD
	echo drupal password: $DRUPAL_PASSWORD
	echo $MYSQL_PASSWORD > /mysql-root-pw.txt
	echo $DRUPAL_PASSWORD > /drupal-db-pw.txt
	
	# Create database
	mysqladmin -u root password $MYSQL_PASSWORD 
	mysql -uroot -p$MYSQL_PASSWORD -e "CREATE DATABASE drupal; GRANT ALL PRIVILEGES ON drupal.* \
		TO 'drupal'@'localhost' IDENTIFIED BY '$DRUPAL_PASSWORD'; FLUSH PRIVILEGES;"

        # Install Composer
        cd /root/
        php composer-setup.php
        mv composer.phar /usr/local/bin/composer

        # Install Drush
        composer self-update
        composer global require drush/drush
        ln -s /root/.composer/vendor/drush/drush/drush /usr/local/bin/drush
	
	# Install Drupal
	rm -rf /var/www/html
	cd /var/www
	drush dl drupal-7 --drupal-project-rename=html
	cd /var/www/html
	drush site-install standard -y --account-name=admin --account-pass=admin \
		--db-url="mysqli://drupal:${DRUPAL_PASSWORD}@localhost:3306/drupal"
	mkdir /var/www/html/sites/default/files
	chmod a+w /var/www/html/sites/default
	chown -R www-data:www-data .

	# Download Date (required: date_popup, date_api)
	drush dl date

	# Install PHP-API-Wrapper
	cd /var/www/html/sites/all/libraries
	git clone https://github.com/brightcove/PHP-API-Wrapper.git
	cd /var/www/html/sites/all/libraries/PHP-API-Wrapper
	composer install

	# Install Brightcove
	drush en brightcove -y

	# Stop mysql
	killall mysqld
	sleep 10s
fi

supervisord -n
