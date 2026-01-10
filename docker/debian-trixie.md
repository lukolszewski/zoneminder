# Debian Trixie Docker Build

## Goal

Create a Docker-based build and runtime environment for ZoneMinder on Debian 13 (Trixie).

## Architecture

```
Dockerfile.builder  →  .deb packages  →  Dockerfile.runtime  →  Running ZoneMinder
     (build)              (artifacts)         (install)            (+ MariaDB)
```

**Two-stage approach:**
1. **Builder image**: Compiles ZoneMinder, produces `.deb` packages
2. **Runtime image**: Installs `.deb`, runs ZoneMinder with Apache

## Files Created

| File | Purpose |
|------|---------|
| `docker/Dockerfile.builder` | Debian 13 build environment, creates .deb packages |
| `docker/Dockerfile.runtime` | Slim runtime image, installs .deb, runs ZM |
| `docker/entrypoint.sh` | Startup script (DB config, migrations, Apache) |
| `docker/docker-compose.yml` | Orchestrates builder, MariaDB, and ZoneMinder |
| `docker/packages/` | Output directory for .deb artifacts |

## Usage

### Build packages
```bash
cd docker
docker compose --profile build run --rm builder
# Packages output to docker/packages/
```

### Run ZoneMinder
```bash
cd docker
docker compose up -d
# Access at http://localhost:8080/zm/
```

## Current Status

- [x] Branch created: `docker-trixie-build`
- [x] Docker files created
- [x] Git submodules initialized (required for build)
- [x] Builder image compiling ZoneMinder
- [x] .deb packages created successfully
- [x] Runtime image built
- [x] Full stack tested (ZM + MariaDB)
- [ ] Committed

## Issues Encountered & Fixes

1. **Missing build deps**: Added `python3-sphinx-rtd-theme`, `ffmpeg`, `arp-scan`, `net-tools`, `iproute2`, Perl modules, `nlohmann-json3-dev`

2. **Git submodules not initialized**: Must run `git submodule update --init --recursive` before building Docker image (content is COPYed, .git is excluded)

3. **Trixie library versions**: FFmpeg libs are version 61 (libavcodec61, etc.), not 60. Also `policykit-1` replaced by `polkitd` + `pkexec`

4. **Runtime dependencies**: The .deb package has many Perl module dependencies that must be pre-installed in the runtime image

5. **Database schema**: The package postinst expects local MySQL. Entrypoint handles remote DB by checking for Config table and importing schema if missing

## Build Monitoring

```bash
tail -f /tmp/zm-build.log
```

## Next Steps

1. Wait for builder to finish creating .deb packages
2. Build runtime image: `docker compose build zoneminder`
3. Start stack: `docker compose up -d`
4. Test at http://localhost:8080/zm/
5. Commit (no CC attribution per user request)
