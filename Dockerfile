FROM  php:7.4.25-apache-buster
LABEL MAINTAINER Sida Say <sida.say@khalibre.com>

ARG MOODLE_VERSION=3.9.11
ARG MOOSH_VERSION=1.3
ARG COMPOSER_VERSION=2.1.12
ENV DOCKERIZE_VERSION v0.6.1

VOLUME ["/var/moodledata"]
EXPOSE 80

# Let the container know that there is no tty JUST WHEN INSTALLING!
# Later we can run docker -ti and we need interactivity

ARG DEBIAN_FRONTEND=noninteractive

## extensions based on https://github.com/moodlehq/moodle-php-apache/blob/master/Dockerfile
COPY php-extensions.sh /tmp
RUN /tmp/php-extensions.sh


# set recommended opcache settings
# see https://www.php.net/manual/en/opcache.installation.php
## see https://docs.moodle.org/38/en/OPcache
RUN { \
  echo 'opcache.memory_consumption=1024'; \
  echo 'opcache.interned_strings_buffer=8'; \
  echo 'opcache.max_accelerated_files=10000'; \
  echo 'opcache.revalidate_freq=60'; \
  echo 'opcache.fast_shutdown=1'; \
  echo 'opcache.enable_cli=1'; \
  echo 'opcache.use_cwd=1'; \
  echo 'opcache.validate_timestamps = 1'; \
  echo 'opcache.save_comments=1'; \
  echo 'opcache.enable_file_override=0'; \
  } > /usr/local/etc/php/conf.d/opcache.ini

# usefull for moodle

RUN { \
  echo 'file_uploads = On'; \
  echo 'memory_limit = 512M'; \
  echo 'upload_max_filesize = 64M'; \
  echo 'post_max_size = 64M'; \
  echo 'max_execution_time = 600'; \
  } > /usr/local/etc/php/conf.d/uploads.ini

RUN a2enmod rewrite expires

RUN	echo "Installing moodle"; \
  curl -o moodle.tar.gz -fSL "https://github.com/moodle/moodle/archive/v${MOODLE_VERSION}.tar.gz"; \
  mkdir /usr/src/moodle; \
  tar -xf moodle.tar.gz -C /usr/src/moodle --strip 1; \
  rm moodle.tar.gz

RUN	echo "Installing composer"; \
  curl -o composer.phar -fSL "https://github.com/composer/composer/releases/download/${COMPOSER_VERSION}/composer.phar"; \
  chmod +x ./composer.phar; \
  mv ./composer.phar /usr/local/bin/composer

RUN	echo "Installing mooosh"; \
  curl -o moosh.tar.gz -fSL "https://github.com/tmuras/moosh/archive/${MOOSH_VERSION}.tar.gz"; \
  mkdir /usr/src/moosh; \
  tar -xf moosh.tar.gz -C /usr/src/moosh --strip 1; \
  composer install -d /usr/src/moosh; \
  ln -s /usr/src/moosh/moosh.php /usr/local/bin/moosh; \
  rm moosh.tar.gz

RUN curl -o dockerize.tar.gz -fSL "https://github.com/jwilder/dockerize/releases/download/${DOCKERIZE_VERSION}/dockerize-linux-amd64-${DOCKERIZE_VERSION}.tar.gz"; \
  tar -xf dockerize.tar.gz -C /usr/local/bin; \
  rm dockerize.tar.gz

COPY moodle-config.php /usr/src/moodle/config.php
COPY docker-entrypoint.sh /usr/local/bin/

# remove plugins installation better a init dir where scripts can be executed if exists, from entrypoint
# COPY plugins-config.sh /usr/local/bin/plugins-config.sh
# COPY plugins /usr/src/

# Fix the original permissions of /tmp, the PHP default upload tmp dir.


RUN chmod 777 /tmp && chmod +t /tmp ;\
  chown -R www-data:www-data -R /usr/src/moodle ;\
  chown www-data:www-data /var/www # moosh uses it
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
