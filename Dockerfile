# Etherpad Lite Dockerfile
#
# Includes LibreOffice and some useful EP plugins.
#
# Based on https://github.com/ether/etherpad-lite
#
FROM node:14-buster-slim
LABEL maintainer="Bernhard Fürst, https://github.com/fuerst/etherpad-lite"

RUN apt update
# libreoffice > JRE will fail to install without /usr/share/man/man1
RUN mkdir -p /usr/share/man/man1
RUN apt install -y libreoffice

# plugins to install while building the container. By default no plugins are
# installed.
# If given a value, it has to be a space-separated, quoted list of plugin names.
#
# EXAMPLE:
#   ETHERPAD_PLUGINS="ep_codepad ep_author_neat"
ARG ETHERPAD_PLUGINS="ep_headings2 ep_markdown ep_comments_page \
                      ep_timesliderdiff ep_adminpads ep_hash_auth ep_tables4"

# By default, Etherpad container is built and run in "production" mode. This is
# leaner (development dependencies are not installed) and runs faster (among
# other things, assets are minified & compressed).
ENV NODE_ENV=production

# Follow the principle of least privilege: run as unprivileged user.
#
# Running as non-root enables running this image in platforms like OpenShift
# that do not allow images running as root.
RUN useradd --uid 5001 --create-home etherpad

RUN mkdir /opt/etherpad-lite && chown etherpad:0 /opt/etherpad-lite

USER etherpad

WORKDIR /opt/etherpad-lite

COPY --chown=etherpad:0 ./ ./

# install node dependencies for Etherpad
RUN bin/installDeps.sh && \
  npm install bcrypt && \
	rm -rf ~/.npm/_cacache

# Install the plugins, if ETHERPAD_PLUGINS is not empty.
#
# Bash trick: in the for loop ${ETHERPAD_PLUGINS} is NOT quoted, in order to be
# able to split at spaces.
RUN for PLUGIN_NAME in ${ETHERPAD_PLUGINS}; do npm install "${PLUGIN_NAME}" || exit 1; done

# Copy the configuration file.
COPY --chown=etherpad:0 ./settings.json.docker /opt/etherpad-lite/settings.json

# Fix permissions for root group
RUN chmod -R g=u .

EXPOSE 9001
CMD ["node", "--experimental-worker", "node_modules/ep_etherpad-lite/node/server.js"]
