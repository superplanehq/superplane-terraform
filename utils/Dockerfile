FROM google/cloud-sdk:550.0.0

# install helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 | bash

# install vim
RUN apt-get update && apt-get install -y vim jq kubectl
