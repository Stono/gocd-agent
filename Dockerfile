FROM gocd/gocd-agent-deprecated:17.2.0
MAINTAINER Karl Stoney <me@karlstoney.com>

# Component versions used in this build
ENV KUBECTL_VERSION 1.6.0
ENV TERRAFORM_VERSION 0.8.7
ENV DOCKER_VERSION 1.11.2
ENV COMPOSE_VERSION 1.9.0
ENV PEOPLEDATA_CLI_VERSION 1.2.36
ENV CLOUD_SDK_VERSION 150.0.0-0

# Get nodejs repos
RUN curl --silent --location https://deb.nodesource.com/setup_6.x | bash - >/dev/null

# Add our dependencies
RUN apt-get -y -q update && \
    apt-get -y -q install nodejs wget sudo python-openssl build-essential libssl-dev g++ unzip && \
    apt-get -y -q clean all

# Terraform
RUN cd /tmp && \
    wget https://releases.hashicorp.com/terraform/$TERRAFORM_VERSION/terraform_$TERRAFORM_VERSION\_linux_amd64.zip && \
    unzip terraform_*.zip && \
    mv terraform /usr/local/bin && \
    rm -rf *terraform*

# Download docker, the version that is compatible GKE
RUN cd /tmp && \
    wget --quiet https://get.docker.com/builds/Linux/i386/docker-$DOCKER_VERSION.tgz && \
    tar -xzf docker-*.tgz && \
    mv ./docker/docker /usr/local/bin/docker && \
    rm -rf docker* && \
    ln -s /usr/local/bin/docker /bin/docker

# Download docker-compose, again the version that is compatible with GKE
RUN cd /usr/local/bin && \
    wget --quiet https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-`uname -s`-`uname -m` && \
    mv docker-compose-* docker-compose && \
    chmod +x /usr/local/bin/docker-compose && \
    ln -s /usr/local/bin/docker-compose /bin/docker-compose

# Setup sudo to allow some compose related environment variables through
RUN echo 'Defaults  env_keep += "COMPOSE_PROJECT_NAME"' >> /etc/sudoers
RUN echo 'Defaults  env_keep += "GO_*"' >> /etc/sudoers
RUN echo 'go ALL=(ALL:ALL) NOPASSWD:ALL' >> /etc/sudoers

# Setup docker
RUN groupadd docker
RUN usermod -aG docker root
RUN usermod -aG docker go

# Setup git-crypt
RUN cd /tmp && \
    git clone --depth=1 https://github.com/AGWA/git-crypt && \
    cd git-crypt && \
    make && \
    make install PREFIX=/usr/local && \
    rm -rf /tmp/git-crypt*

ENV CLOUDSDK_INSTALL_DIR /usr/lib/google-cloud-sdk
ENV CLOUD_SDK_REPO cloud-sdk-trusty
ENV CLOUDSDK_PYTHON_SITEPACKAGES 1
RUN echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" > /etc/apt/sources.list.d/google-cloud-sdk.list
RUN curl --silent https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
RUN apt-get -y -q update && \
    apt-get -y -q install google-cloud-sdk=$CLOUD_SDK_VERSION && \
    apt-get -y -q clean all
RUN mkdir -p /etc/gcloud/keys

# Get the version of kubectl that matches our node deployment
RUN cd /usr/local/bin && \
    wget --quiet https://storage.googleapis.com/kubernetes-release/release/v$KUBECTL_VERSION/bin/linux/amd64/kubectl && \
    chmod +x kubectl

# Disable google cloud auto update... we should be pushing a new agent container
RUN gcloud config set --installation component_manager/disable_update_check true
RUN sed -i -- 's/\"disable_updater\": false/\"disable_updater\": true/g' $CLOUDSDK_INSTALL_DIR/lib/googlecloudsdk/core/config.json

# Add the Peopledata CLI
ARG GO_DEPENDENCY_LABEL_CLI_PEOPLEDATA=
RUN npm install -g --depth=0 --no-summary --quiet peopledata-cli@$PEOPLEDATA_CLI_VERSION && \
    rm -rf /tmp/npm*

WORKDIR /var/go

# Boot commands
COPY scripts/* /usr/local/bin/
CMD ["/usr/local/bin/run_agent.sh"]
