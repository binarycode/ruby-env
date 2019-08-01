# Minimal Ruby Image generator

## Prerequisites
* buildah

## Usage

Using sudo:
```
$ sudo ./build.sh -r RUBY_VERSION -d DEBIAN_VERSION
```

Rootless:
```
$ buildah unshare ./build.sh -r RUBY_VERSION -d DEBIAN_VERSION
```
