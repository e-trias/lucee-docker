#!/usr/bin/env bash

set -e

# ./warmup_extension.sh <(server|web)> '<extension_id>'
# example:
# ./warmup_extension.sh server '43AC6017-4EF7-4F14-89AB253C347E6A8F'

EXTENSION_TYPE=$1
EXTENSION_ID=$2
EXTENSION_VERSION=$3

SERVER_CONTEXT=${CATALINA_BASE}/lucee-server/context
DEPLOY_DIR=${CATALINA_BASE}/lucee-server/deploy
WEB_CONTEXT=${CATALINA_BASE}/lucee-web/context

echo "create a test app"
mkdir -p ${SERVER_WEBROOT}/test_app

cat > ${SERVER_WEBROOT}/test_app/Application.cfc <<EOF
component {
  this.ormenabled = true;
}
EOF

cat > ${SERVER_WEBROOT}/test_app/index.cfm <<EOF
<cfscript>
  param name="url.type" default="";
  param name="url.extensionId" default="";
  param name="url.version" default="";
  serverAdmin = new Administrator(url.type, "$LUCEE_ADMIN_PASSWORD");
  extensions = serverAdmin.getExtensions();
  // dump(var=extensions, format="text");
  if ( url.extensionId == 'FAD1E8CB-4F45-4184-86359145767C29DE' ) {
    try {
     ormReload();
    } catch (any e) {
      sleep 30;
      ormReload();
    }
  }

  sql = "select * from extensions where id = '#url.extensionId#'";
  if (len(url.version)) {
    sql &= " and version = '#url.version#'";
  }

  extension = queryExecute(
    sql,
    {},
    {dbtype="query"}
  );

  // dump(extension);

  // throw an error when the extension isn't found.
  // that will cause curl to fail and the loop to retry
  if (extension.recordCount == 0) {
    throw();
  }
</cfscript>
EOF

echo "warmup tomcat to trigger extension installation"

catalina.sh start
echo "wait until extension is installed"
until $(curl --output /dev/null --silent --head --fail "http://localhost:${SERVER_PORT}/test_app/?type=${EXTENSION_TYPE}&extensionId=${EXTENSION_ID}&version=${EXTENSION_VERSION}"); do
  printf '.'
  sleep 1
done
echo ""
catalina.sh stop

echo "cleanup workarounds"
rm -rf ${SERVER_WEBROOT}/test_app