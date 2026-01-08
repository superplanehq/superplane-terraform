gke.build:
	@docker build -f Dockerfile.gke -t gke-image:latest .

gke.shell: gke.build
	@docker run -it --rm \
	  -v config:/root/.config/gcloud \
	  -v $(shell cd .. && pwd):/workspace \
	  -w /workspace \
		gke-image:latest /bin/bash

