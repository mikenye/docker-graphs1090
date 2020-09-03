# mikenye/graphs1090

[`graphs1090`](https://github.com/wiedehopf/graphs1090) is an excellent tool by [wiedehopf](https://github.com/wiedehopf) that generates graphs for `dump1090`/`readsb` and their variants.

This container can receive:

* Beast data from a provider such as `dump1090` or `readsb`, either via network or via a shared docker volume
* Optionally, MLAT data from a provider such as `mlat-client` (if you want to see MLAT statistics)

It builds and runs on `linux/amd64`, `linux/arm/v6`, `linux/arm/v7` and `linux/arm64` (see below).

## Supported tags and respective Dockerfiles

* `latest` should always contain the latest released version of `graphs1090`. This image is built nightly from the `master` branch `Dockerfile` for all supported architectures.
* `development` (`dev` branch, `Dockerfile`, `amd64` architecture only, built on commit, not recommended for production)
* Specific version tags are available if required, however these are not regularly updated. It is generally recommended to run latest.

## Multi Architecture Support

* `linux/amd64`: Built on Linux x86-64
* `linux/arm/v6`: Built on Odroid HC2 running ARMv7 32-bit
* `linux/arm/v7`: Built on Odroid HC2 running ARMv7 32-bit
* `linux/arm64`: Built on a Raspberry Pi 4 Model B running ARMv8 64-bit

## Prerequisites

You will need a source of Beast data. This could be an RPi running PiAware, the [`mikenye/piaware`](https://hub.docker.com/r/mikenye/piaware) image or [`mikenye/readsb`](https://hub.docker.com/r/mikenye/readsb).

Optionally, you will need a source of MLAT data. This could be an RPi running PiAware, the [`mikenye/piaware`](https://hub.docker.com/r/mikenye/piaware) image, or any other host/container running `mlat-client` that is configured to *listen* for Beast connections.

## Up-and-Running with `docker run`

```shell
docker run -d \
    --name=graphs1090 \
    -p 8080:80 \
    -e TZ=<TIMEZONE> \
    -e BEASTHOST=<BEASTHOST> \
    -e MLATHOST=<MLATHOST> \
    -e LAT=<ANTENNA_LATITUDE> \
    -e LONG=<ANTENNA_LONGITUDE> \
    mikenye/graphs1090:latest
```

Replacing:

* `TIMEZONE` with your timezone
* `BEASTHOST` with the IP address/hostname of a host that can provide Beast data
* `MLATHOST` with the IP address/hostname of a host that can provide MLAT data
* `LAT` with your antenna's latitude (optional, but required for range graph)
* `LONG` with your antenna's longitude (optional, but required for range graph)

For example:

```shell
docker run -d \
    --name=graphs1090 \
    -p 8080:80 \
    -v graphs1090_rrd:/var/lib/collectd/rrd \
    -e TZ=Australia/Perth \
    -e BEASTHOST=readsb \
    -e MLATHOST=piaware \
    -e LAT=-33.33333 \
    -e LONG=111.11111 \
    mikenye/graphs1090:latest
```

You should now be able to browse to <http://dockerhost:8080> to access the `graphs1090` web interface.

## Up-and-Running with `docker-compose`

An example `docker-compose.yml` file is below:

```yaml
version: '2.0'

networks:
  adsbnet:

volumes:
  graphs1090_rrd:

services:
  graphs1090:
    image: mikenye/graphs1090:latest
    tty: true
    container_name: graphs1090
    restart: always
    volumes:
      - graphs1090_rrd:/var/lib/collectd/rrd
    ports:
      - 8080:80
    environment:
      - BEASTHOST=readsb
      - MLATHOST=piaware
      - TZ=Australia/Perth
      - LAT=-33.33333
      - LONG=111.11111
    networks:
      - adsbnet
```

You should now be able to browse to <http://dockerhost:8080> to access the `graphs1090` web interface.

## Up-and-Running with `docker-compose`, with `mikenye/readsb`

This example uses a shared docker volume to provide the required JSON data into `graphs1090`. This approach offers the following benefits over using `BEASTHOST`:

* Less CPU utilisation
* The `Messages > -3dBFS` value will be populated

The shared docker volume should:

* Be mounted read/write into the `readsb` container at the path specified by the `--write-json` argument
* Be mounted read-only into the `graphs1090` at `/data`

An example `docker-compose.yml` file is below:

```yaml
version: '2.0'

networks:
  adsbnet:

volumes:
  graphs1090_rrd:
  readsb_json:

services:

  readsb:
    image: mikenye/readsb:latest
    tty: true
    container_name: readsb
    restart: always
    devices:
      - /dev/bus/usb:/dev/bus/usb
    ports:
      - 8081:8080
      - 30003:30003
      - 30005:30005
    networks:
      - adsbnet
    environment:
      - TZ=Australia/Perth
      - PULLMLAT=piaware:30105,adsbx:30105,rbfeeder:30105
    command:
      - --dcfilter
      - --device-type=rtlsdr
      - --gain=36.4
      - --fix
      - --json-location-accuracy=2
      - --lat=-xx.xxxxx
      - --lon=xxx.xxxxx
      - --modeac
      - --ppm=0
      - --net
      - --stats-every=3600
      - --quiet
      - --net-connector=127.0.0.1,30105,beast_in
      - --write-json=/run/readsb
    volumes:
      - readsb_json:/run/readsb

  graphs1090:
    image: mikenye/graphs1090:latest
    tty: true
    container_name: graphs1090
    restart: always
    volumes:
      - graphs1090_rrd:/var/lib/collectd/rrd
      - readsb_json:/data:ro
    ports:
      - 8080:80
    environment:
      - TZ=Australia/Perth
      - LAT=-33.33333
      - LONG=111.11111
    networks:
      - adsbnet

  ...other services...
```

The docker volume `readsb_json` is the shared volume by both containers. The `readsb` container will write the required JSON files into the volume. Those files will then be read by `graphs1090`.

The `readsb` container is configured to pull MLAT data (via the `PULLMLAT` environment variable) from containers that implement MLAT. This MLAT data is available via port `30105`. We then feed this data back into the `readsb` instance with `--net-connector=127.0.0.1,30105,beast_in`, so the MLAT statistics appear in the JSON output. If running with this method, it is imparative that `--forward-mlat` is NOT passed as a command line argument to `readsb`.

You should now be able to browse to <http://dockerhost:8080> to access the `graphs1090` web interface.

## Ports

### Outgoing

This container will try to connect to:

* `BEASTHOST` on TCP port `30005` by default. This can be changed by setting the `BEASTPORT` environment variable.
* If specified, `MLATHOST` on TCP port `30105` by default. This can be changed by setting the `MLATPORT` environment variable.

### Incoming

This container accepts HTTP connections on TCP port `80` by default. You can change this with the container's port mapping. In the examples above, this has been changed to `8080`.

## Volumes & Mount Points

| Mount Point | Purpose |
|------|------|------|
| `/var/lib/collectd/rrd` | Contains the RRDs and historical graphs data. It is recommended to map this to persistent storage.
| `/data` | Should contain the JSON files generated by `readsb`/`dump1090` if not using `BEASTHOST`. If used, should be mounted read-only (with the `:ro` directive).

## Runtime Environment Variables

| Environment Variable | Purpose | Default |
|----------------------|---------|---------|
| BEASTHOST | Optional. IP/Hostname of a Mode-S/Beast provider (`dump1090`/`readsb`) | |
| BEASTPORT | Optional. TCP port number of Mode-S/Beast provider (`dump1090`/`readsb`) | `30005` |
| MLATHOST | Optional. IP/Hostname of an MLAT provider | |
| MLATPORT | Optional. TCP port number of MLAT provider | `30105` |
| LAT | Optional. Latitude of your antenna | |
| LONG | Optional. Longitude of your antenna | |
| TZ | Optional but recommended. Your local timezone in [TZ-database-name](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) format | |

Without setting the `TZ` environment variable, the graphs generated by `graphs1090` won't be in your local timezone, and will instead be in `UTC`.

Without setting the `MLATHOST` environment variables, the graphs generated by `graphs1090` won't have any MLAT data.

Without setting the `LAT` and `LONG` environment variables, the graphs generated by `graphs1090` won't include range data.

## Logging

All logs are to the container's stdout and can be viewed with `docker logs [-f] container`.

## Getting help

Please feel free to [open an issue on the project's GitHub](https://github.com/mikenye/docker-graphs1090/issues).

I also have a [Discord channel](https://discord.gg/sTf9uYF), feel free to [join](https://discord.gg/sTf9uYF) and converse.

## Changelog

### 20200508

* Add `linux/arm/v6` architecture support

### 20200504

* Original Image
