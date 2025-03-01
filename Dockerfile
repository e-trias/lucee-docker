###
## Build:
#
#  if passing LUCEE_VERSION, it must include modifier, e.g. -SNAPSHOT, -RC, if there is one
#     you can also set the value to CUSTOM and place a Lucee JAR file in resources/catalina-base/lib
#  if passing LUCEE_EXTENSIONS, the value has to be in double quotes
#
#  docker image build \
#    --build-arg LUCEE_VERSION=5.3.8.133-SNAPSHOT \
#    --build-arg LUCEE_ADMIN_PASSWORD=changeit \
#    --build-arg LUCEE_EXTENSIONS="3F9DFF32-B555-449D-B0EB5DB723044045;name=WebSocket" \
#    -t isapir/lucee-538 .
#
#  docker push isapir/lucee-538
#
###
## Run:
#
#  HOST_WEBROOT=/work/webroot
#
#  docker container run -d --rm -p 8080:8080 --name lucee-8080 \
#    -v $HOST_WEBROOT:/srv/www/app/webroot \
#    -e LUCEE_PRESERVE_CASE=true \
#    -e CATALINA_OPTS="-Xmx4g"
#    isapir/lucee-538
#
###
## Project home: https://github.com/isapir/lucee-docker
#

# Allow to specify the base Tomcat image (must have curl)
ARG TOMCAT_IMAGE_TAG=9-jdk11

FROM tomcat:$TOMCAT_IMAGE_TAG AS Lucee


# Set default LUCEE_VERSION
#   Override at build time with --build-arg LUCEE_VERSION=5.2.9.38-SNAPSHOT
ARG LUCEE_VERSION=5.3.10.120

# Allow to specify the Lucee Admin Password at build time with --build-arg LUCEE_ADMIN_PASSWORD=changeit
ARG LUCEE_ADMIN_PASSWORD=

# Install optional Lucee extensions in the comma separated format {extension-uuid};name=X;label=XY;version=m.n
#   e.g. "3F9DFF32-B555-449D-B0EB5DB723044045;name=WebSocket"
ARG LUCEE_EXTENSIONS=

# Pass JVM options when Tomcat starts, e.g. --build-arg CATALINA_OPTS="-Xmx2g"
ARG CATALINA_OPTS=

# Allow to set a custom webroot directory
ARG SERVER_WEBROOT=/srv/www/app/webroot
ARG SERVER_PORT=8080

# Set Target Env for post warmup file copy, default is DEV - files will be copied from resources/target-envs/DEV
ARG TARGET_ENV=DEV

ARG DB_HOST=
ARG DB_PASSWORD=
ARG DB_PORT=
ARG DB_USERNAME=
ARG JDBC_SSL_STRING=
ARG POSTGRES_DB_ETRIAS=
ARG POSTGRES_DB_WOONPLAN=

ENV DB_HOST=${DB_HOST}
ENV DB_PASSWORD=${DB_PASSWORD}
ENV DB_PORT=${DB_PORT}
ENV DB_USERNAME=${DB_USERNAME}
ENV JDBC_SSL_STRING=${JDBC_SSL_STRING}
ENV POSTGRES_DB_WOONPLAN=${POSTGRES_DB_WOONPLAN}
ENV POSTGRES_DB_ETRIAS=${POSTGRES_DB_ETRIAS}


ENV LUCEE_EXTENSIONS=${LUCEE_EXTENSIONS}
ENV SERVER_WEBROOT=${SERVER_WEBROOT}
ENV SERVER_PORT=${SERVER_PORT}
ENV CATALINA_OPTS=${CATALINA_OPTS}

ENV BASE_DIR /srv/www

# Map a host directory for web app, which must have a webroot subdirectory, with
#   -v <host-directory-app>:${BASE_DIR}/app
ENV CATALINA_BASE ${BASE_DIR}/catalina-base
ENV CATALINA_HOME /usr/local/tomcat
ENV WEBAPP_BASE ${BASE_DIR}/app
ENV LUCEE_DOWNLOAD https://release.lucee.org/rest/update/provider/loader/

# Lucee server directory
ENV LUCEE_SERVER ${CATALINA_BASE}/lucee-server

ENV TARGET_ENV ${TARGET_ENV}

# displays the OS version and Lucee Server path
# calls makebase.sh and downloads Lucee if the version is not set to CUSTOM
RUN cat /etc/os-release \
    && $CATALINA_HOME/bin/makebase.sh $CATALINA_BASE \
    &&  if [ "$LUCEE_VERSION" != "CUSTOM" ] ; then \
            echo Downloading Lucee ${LUCEE_VERSION}... \
            && curl -L -o "${CATALINA_BASE}/lib/${LUCEE_VERSION}.jar" "${LUCEE_DOWNLOAD}${LUCEE_VERSION}" ; \
        fi

# copy the files from resources/catalina_base to the image
COPY resources/catalina-base ${CATALINA_BASE}

# copy the files from app, including the required subdirectory webroot, to the image
COPY app ${WEBAPP_BASE}

# create password.txt file if password is set
RUN if [ "$LUCEE_ADMIN_PASSWORD" != "" ] ; then \
        mkdir -p "${LUCEE_SERVER}/context" \
        && echo $LUCEE_ADMIN_PASSWORD > "${LUCEE_SERVER}/context/password.txt" ; \
    fi

WORKDIR ${BASE_DIR}

# INSTALL CFSPREADSHEET (from https://github.com/jamiejackson/lucee5-install-extensions)
# COPY warmup_extension.sh ./tmp/
# RUN chmod a+x ./tmp/warmup_extension.sh
RUN echo "~=%# install cfspreadsheet extension #%=~" \
  && cd ${CATALINA_BASE}/lucee-server/deploy && { curl -O https://raw.githubusercontent.com/Leftbower/cfspreadsheet-lucee-5/master/cfspreadsheet-lucee-5.lex ; cd -; }
  # && ./tmp/warmup_extension.sh server '037A27FF-0B80-4CBA-B954BEBD790B460E'

RUN if [ "$LUCEE_VERSION" \> "5.3.6" ] || [ "$LUCEE_VERSION" == "CUSTOM" ] ; then \
      echo "Enabled LUCEE_ENABLE_WARMUP" \
        && export LUCEE_ENABLE_WARMUP=true \
        && export LUCEE_EXTENSIONS \
        && catalina.sh run ; \
    else \
      echo "Start Tomcat and wait 20 seconds to shut down" \
        && catalina.sh start \
        && sleep 20 \
        && catalina.sh stop ; \
    fi

# copy additional lucee-server and lucee-web after the warmup completes
COPY resources/target-envs/${TARGET_ENV} ${CATALINA_BASE}
