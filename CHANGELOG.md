# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [v0.2.0](https://github.com/supermethodhq/ex_stl/tree/v0.2.0) (2026-01-07)

### Fixed

- Time-series decomposition ordering - Series are now automatically sorted into chronological order before decomposition
- Series validation - Added validation requiring at least 2 full periods before attempting to fit
- MSTL `seasonal_lengths` validation - Now validates that:
  - Values are at least 3 (minimum period length)
  - Values are odd numbers (required by STL algorithm)
  - Series contains enough samples for the specified seasonal lengths
- Updated module docs and added specs

## [v0.1.0](https://github.com/supermethodhq/ex_stl/tree/v0.1.0) (2025-05-09)

Initial release.
