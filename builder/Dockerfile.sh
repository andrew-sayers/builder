#!/bin/sh

set -e

. ../utils/Dockerfile-utils.sh

# Node releases: https://nodejs.org/en/about/releases/
# This should normally be the Active LTS release,
# or optionally the latest Current release,
# if that release will become an Active LTS in future.
NODE_VERSION="$(cat node-version.txt)"

# JSDoc documentation is generated by jsdoc:
NPM_PACKAGES="$NPM_PACKAGES jsdoc"
APT_PACKAGES="$APT_PACKAGES"

# Several repositories are build with Google's Closure compiler:
NPM_PACKAGES="$NPM_PACKAGES google-closure-compiler"
APT_PACKAGES="$APT_PACKAGES inotify-tools"

# Unit tests are use Jasmine:
NPM_PACKAGES="$NPM_PACKAGES jasmine"
APT_PACKAGES="$APT_PACKAGES"

# The dashboard uses vue:
NPM_PACKAGES="$NPM_PACKAGES @vue/cli-service"
APT_PACKAGES="$APT_PACKAGES"

# Header:
cat <<EOF
FROM node:$NODE_VERSION
RUN true \\
&& mkdir -p /opt/sleepdiary/bin \\
&& echo PATH="/opt/sleepdiary/bin:$PATH" > /etc/profile.d/fix_path.sh \\
EOF

# JSDoc timestamps all documents.  To generate a repeatable build, we need a fake timestamp.
# We use libfaketime, which I've only been able to make work when it's installed in /tmp:
if echo "$NPM_PACKAGES" | grep -q jsdoc
then cat <<EOF
 \\
&& git clone --depth 1 https://github.com/wolfcw/libfaketime.git /tmp/libfaketime \\
&& sed -i -e 's/\/usr\/local/\/tmp\/libfaketime/' /tmp/libfaketime/Makefile /tmp/libfaketime/*/Makefile \\
&& make -j -C /tmp/libfaketime/src \\
&& ln -s . /tmp/libfaketime/lib \\
&& ln -s src /tmp/libfaketime/faketime \\
EOF
fi

install_npm_packages $NPM_PACKAGES
install_apt_packages $APT_PACKAGES

# VuePress requires node_modules to be in the same directory as the package itself:
# * installing globally with `npm install -g` doesn't install all the dependencies
# * installing elsewhere and symlinking causes errors
# * installing elsewhere and symlinking subdirectories causes errors
# * installing elsewhere and hardlinking works, so long as we're on the same filesystem
# * installing elsewhere and copying works, but is slow
#
# ... so we install elsewher and use `install-directory.sh`
#
# Note: it's possible I've made some silly mistake that causes all of this,
# but I can't get useful guidance or error messages to figure out what.
cat <<EOF
\\
&& mkdir /opt/sleepdiary/vuepress \\
&& cd /opt/sleepdiary/vuepress \\
&& npm install vuepress@next @vuepress/plugin-search@next @vuepress/theme-default@next \\
EOF

footer

cat <<EOF
COPY root /
RUN chmod 755 /opt/sleepdiary/*.sh /opt/sleepdiary/bin/*
ENV PATH="/opt/sleepdiary/bin:${PATH}"
WORKDIR /app
EOF
