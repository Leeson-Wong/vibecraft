# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **OpenClaw Integration**: Native support for OpenClaw universal AI gateway
  - New `openclaw-hook/` directory with OpenClaw hook implementation
  - Hook listens to tool invoke, tool complete, command, and message events
  - Automatic event transformation from OpenClaw to Vibecraft format
  - Cross-platform support (Windows, macOS, Linux) via OpenClaw
  - Tool mapping for OpenClaw tools to Vibecraft stations
  - Documentation in `openclaw-hook/README.md` and updated main `README.md`
