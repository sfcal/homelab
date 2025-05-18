# Build the container
docker build -t homelab-infra -f Dockerfile .

# Run the container with your repo mounted
docker run -it --rm \
  -v "$HOME/.ssh:/home/devops/.ssh" \
  -v "$HOME/.kube:/home/devops/.kube" \
  -v "$PWD:/workspace" \
  -v "$HOME/.home:/home/devops/.home" \
  -v "$HOME/homelab:/home/devops/homelab" \
  -v "$HOME/.gitconfig:/home/devops/.gitconfig" \
  -e ENV=dev \
  homelab-infra "$@"
