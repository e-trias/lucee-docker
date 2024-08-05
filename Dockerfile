FROM tomcat:9-jdk11 AS lucee

ARG LUCEE_VERSION=5.3.10.120
ARG TARGET_ENV=DEV
ARG SERVER_WEBROOT=/srv/www/app/webroot

ARG BASE_DIR
ARG CATALINA_BASE
ARG CATALINA_HOME
ARG CATALINA_OPTS
ARG DB_HOST
ARG DB_PASSWORD
ARG DB_PORT
ARG DB_USERNAME
ARG HOST_WOONPLAN
ARG JDBC_SSL_STRING
ARG LUCEE_DOWNLOAD
ARG LUCEE_EXTENSIONS
ARG LUCEE_SERVER
ARG POSTGRES_DB_ETRIAS
ARG POSTGRES_DB_WOONPLAN
ARG SERVER_PORT
ARG WEBAPP_BASE

ENV BASE_DIR=/srv/www
ENV CATALINA_BASE=${BASE_DIR}/catalina-base
ENV CATALINA_HOME=/usr/local/tomcat
ENV CATALINA_OPTS=${CATALINA_OPTS}
ENV DB_HOST=${DB_HOST}
ENV DB_PASSWORD=${DB_PASSWORD}
ENV DB_PORT=${DB_PORT}
ENV DB_USERNAME=${DB_USERNAME}
ENV HOST_WOONPLAN=${HOST_WOONPLAN}
ENV JDBC_SSL_STRING=${JDBC_SSL_STRING}
ENV LUCEE_DOWNLOAD=https://release.lucee.org/rest/update/provider/loader/
ENV LUCEE_EXTENSIONS=${LUCEE_EXTENSIONS}
ENV LUCEE_SERVER=${CATALINA_BASE}/lucee-server
ENV POSTGRES_DB_ETRIAS=${POSTGRES_DB_ETRIAS}
ENV POSTGRES_DB_WOONPLAN=${POSTGRES_DB_WOONPLAN}
ENV SERVER_PORT=${SERVER_PORT}
ENV SERVER_WEBROOT=${SERVER_WEBROOT}
ENV TARGET_ENV=${TARGET_ENV}
ENV WEBAPP_BASE=${BASE_DIR}/app

# Copy certificates into the build context
COPY certificates /etc/certs

# Convert PEM to DER
RUN openssl x509 -outform der -in /etc/certs/${HOST_WOONPLAN}.pem -out /etc/certs/${HOST_WOONPLAN}.der

# import the certificate into the Java trust store
RUN keytool -import -alias ${HOST_WOONPLAN} -keystore ${JRE_HOME}/lib/security/cacerts -file /etc/certs/${HOST_WOONPLAN}.der -storepass changeit -noprompt

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

