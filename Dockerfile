FROM mcr.microsoft.com/powershell:7.1.3-debian-buster-slim

# Install azure-cli
ARG AZCLI_VER=2.22.1-1~buster
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y upgrade \
    && apt-get -y install --no-install-recommends ca-certificates curl apt-transport-https lsb-release gnupg wget \
    && curl -sL https://packages.microsoft.com/keys/microsoft.asc | \
        gpg --dearmor | \
        tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null \
    && AZ_REPO=$(lsb_release -cs) \
    && echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | \
        tee /etc/apt/sources.list.d/azure-cli.list \
    && wget https://packages.microsoft.com/config/debian/10/packages-microsoft-prod.deb -O packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && apt-get update && apt-get -y install --no-install-recommends \
        azure-cli=${AZCLI_VER} \
        dotnet-sdk-3.1 \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install PowerShell Az module
ARG AZ_PWSH_VER=5.9.0
RUN pwsh -noni -c "\$ProgressPreference='SilentlyContinue'; Install-Module Az -AllowClobber -RequiredVersion '${AZ_PWSH_VER}' -Repository PSGallery -Force -Scope AllUsers"
ARG AZ_SYNAPSE_VER=0.11.0
RUN pwsh -noni -c "\$ProgressPreference='SilentlyContinue'; Install-Module Az.Synapse -AllowClobber -RequiredVersion '${AZ_SYNAPSE_VER}' -Repository PSGallery -Force -Scope AllUsers"

# Install Corvus.Deployment module
ADD module /usr/local/share/powershell/Modules/Corvus.Deployment

# Default to non-root user
RUN useradd -c 'corvus.deployment user' -m -d /home/corvus -s /bin/bash corvus
USER corvus
ENV HOME /home/corvus

# Bicep installs into the user folder
ARG AZ_BICEP_VER=v0.3.255
RUN az bicep install --version $AZ_BICEP_VER

WORKDIR /home/corvus