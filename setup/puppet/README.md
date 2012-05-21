To install ghtorrent using Puppet under Debian execute the following steps.

```sh
apt-get update
apt-get upgrade
apt-get install -y puppet git lsb-core
git clone git@github.com:gousiosg/github-mirror.git
cd github-mirror/setup/puppet
sudo tools/setup.sh
sudo tools/run.sh mirror
```
