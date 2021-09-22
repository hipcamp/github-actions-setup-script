# github-actions-setup-script
This is a utility script for setting up GitHub Actions Runners.

`curl -fsSL https://raw.githubusercontent.com/hipcamp/github-actions-setup-script/main/setup.sh | bash -s RUNNERS=[number of runners] GITHUB_URL=[https://github.com/your-org] TOKEN=[your token] LABELS=[label_1,label_2]`
curl -fsSL https://raw.githubusercontent.com/hipcamp/github-actions-setup-script/main/root.sh | bash -s RUNNERS=1 GITHUB_URL=https://github.com/hipcamp TOKEN=ACX5ZMKCXJPENTP6HS7NQJLBJNUEW LABELS=hulkbuster