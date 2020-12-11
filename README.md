# vaccel
A meta repo for gathering all the necessary components for running (and releasing) a vaccel environment.

This repo is meant to track versions of the various components that work with
each other, allow easy development locally using the build scripts and
orchestrating e2e tests of the whole stack.

## Building

The `build.sh` script allows you to build all the necessarry components, or one
component at a time during development. It is using the component specific
scripts under the `scripts` directory.

For more info abou the script:

```bash
./build.sh --help
```
