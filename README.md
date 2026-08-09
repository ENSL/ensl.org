[![Test](https://github.com/ENSL/ensl.org/actions/workflows/test.yml/badge.svg)](https://github.com/ENSL/ensl.org/actions/workflows/test.yml)
[![Maintainability](https://qlty.sh/gh/ENSL/projects/ensl.org/maintainability.svg)](https://qlty.sh/gh/ENSL/projects/ensl.org)
[![Code Coverage](https://qlty.sh/gh/ENSL/projects/ensl.org/coverage.svg)](https://qlty.sh/gh/ENSL/projects/ensl.org)
[![Brakeman](https://img.shields.io/badge/Brakeman-enabled-0A66C2)](https://github.com/presidentbeef/brakeman)

[![Ruby](https://img.shields.io/badge/Ruby-3.4.8-CC342D?logo=ruby&logoColor=white)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-8.1.x-D30001?logo=rubyonrails&logoColor=white)](https://rubyonrails.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

# ENSL Website

Source code for [ensl.org](https://www.ensl.org), built with Ruby on Rails.

## Stack

- Ruby 3.4
- Rails 8.1
- MariaDB
- Redis + Sidekiq
- Turbo, Importmap and Tailwind CSS

## Documentation

See [INSTALL.md](INSTALL.md) for installation and [DEVELOPMENT.md](DEVELOPMENT.md) for day-to-day development.

## Features

- Articles and comments
- Forums, topics, private messages and shoutbox
- User accounts, detailed profiles, ACL, teams
- Contest system with weekly map schedules
  - Match with referee and details
  - Ladder for ELO-based ranking
  - League for traditional points-based tournament
  - Brackets for bracket-style tournaments
  - Team challenge system with score reporting
  - Match predictions with scored leaderboards
- Gather pick-up system with captain picks, map voting and server voting
  - Mobile-friendly
- File and directory library for demos, movies and uploads
- Map, movie and server databases
- Passkey authentication, 2FA, scrypt etc. for security
- Polls, voting, issue tracking and ENSL plugin API
- Gaming data analysis and rankings display

## Contributors

- [Ari Timonen](https://github.com/jirikivaari) (Original Author)
- [Florent Latombe](https://github.com/flatombe)
- [Luke Barratt](https://github.com/lbarratt)
- [Callum Barratt](https://github.com/cbarratt)
- [Joseph Hutchins](https://github.com/taekwonjoe01)
