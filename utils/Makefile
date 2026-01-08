gke.build:
	@docker build -f Dockerfile.gke -t gke-image:latest .

gke.shell: gke.build
	@docker run -it --rm \
	  -v config:/root/.config/gcloud \
	  -e GOOGLE_APPLICATION_CREDENTIALS=/root/.config/gcloud/application_default_credentials.json \
		gke-image:latest /bin/bash

