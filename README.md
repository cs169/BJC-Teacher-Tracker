# BJC Teacher Tracker
Sp23 Badges:

[![Bluejay Dashboard](https://img.shields.io/badge/Bluejay-Dashboard_BJC%20Teacher%20Tracker-blue.svg)](http://dashboard.bluejay.governify.io/dashboard/script/dashboardLoader.js?dashboardURL=https://reporter.bluejay.governify.io/api/v4/dashboards/tpa-CS169L-23-GH-cs169_BJC-Teacher-Tracker/main) •
[![All Specs](https://github.com/cs169/BJC-Teacher-Tracker-App/actions/workflows/specs.yml/badge.svg)](https://github.com/cs169/BJC-Teacher-Tracker-App/actions/workflows/specs.yml) •
[![RuboCop](https://github.com/cs169/BJC-Teacher-Tracker-App/actions/workflows/rubocop.yml/badge.svg)](https://github.com/cs169/BJC-Teacher-Tracker-App/actions/workflows/rubocop.yml) •
[![Maintainability](https://qlty.sh/gh/cs169/projects/BJC-Teacher-Tracker/maintainability.svg)](https://qlty.sh/gh/cs169/projects/BJC-Teacher-Tracker) •
[![Code Coverage](https://qlty.sh/gh/cs169/projects/BJC-Teacher-Tracker/coverage.svg)](https://qlty.sh/gh/cs169/projects/BJC-Teacher-Tracker) •
[![Pivotal Tracker](https://user-images.githubusercontent.com/67244883/154180887-f803124e-0156-4322-899d-ba475139d60d.png)](https://www.pivotaltracker.com/n/projects/2406982)

---

@beautyjoy/BJC-Teacher-Tracker Status:

[![All Specs](https://github.com/beautyjoy/BJC-Teacher-Tracker/actions/workflows/specs.yml/badge.svg)](https://github.com/beautyjoy/BJC-Teacher-Tracker/actions/workflows/specs.yml) •
[![RuboCop](https://github.com/beautyjoy/BJC-Teacher-Tracker/actions/workflows/rubocop.yml/badge.svg)](https://github.com/beautyjoy/BJC-Teacher-Tracker/actions/workflows/rubocop.yml) •
[![CodeQL](https://github.com/beautyjoy/BJC-Teacher-Tracker/actions/workflows/codeql-analysis.yml/badge.svg)](https://github.com/beautyjoy/BJC-Teacher-Tracker/actions/workflows/codeql-analysis.yml) •
[![codecov](https://codecov.io/gh/beautyjoy/BJC-Teacher-Tracker/branch/master/graph/badge.svg?token=96PyjKKVzi)](https://codecov.io/gh/beautyjoy/BJC-Teacher-Tracker) •
[![Maintainability](https://api.codeclimate.com/v1/badges/ca4948c3dbe825709c3e/maintainability)](https://codeclimate.com/github/beautyjoy/BJC-Teacher-Tracker/maintainability) •
[![Test Coverage](https://api.codeclimate.com/v1/badges/ca4948c3dbe825709c3e/test_coverage)](https://codeclimate.com/github/beautyjoy/BJC-Teacher-Tracker/test_coverage)
---

## Description

The Beauty and Joy of Computing (BJC) is an introductory computer science curriculum developed at UC Berkeley meant for high school freshmen up to college freshmen. The program has a teacher guide and a newly generated password that is to be given to any teacher who signs up for the program as a volunteer educator in the Bay Area - there are plans to expand the program to other states in late 2020. This pilot application is designed as a dashboard to track the workflow of teachers who run the program and provide high-level, descriptive statistics on the courses taught and participating schools. The BJC Teacher Tracker is a NEW project started in Fall 2019 by a group of 5 student developers in UC Berkeley's CS 169: Software Engineering.

## Features
```mermaid
C4Context
  title BJC Curriculum Management Dashboard

  Boundary(b1, "Dashboard System") {
    Person(teacher, "Teacher", "Signs up and manages own information")
    System(curriculumSystem, "Curriculum Dashboard", "Central platform for curriculum management")
    Person(admin, "Admin", "Administers systems and oversees communications")

    System(teacherInfoSystem, "Teacher Management System", "Manages teacher profiles")

    System(emailSystem, "Email System", "Handles all email communications")
   
    System(workshopSystem, "Workshop System", "Coordinates workshop registrations")

    Rel(admin, curriculumSystem, "Administers", "HTTPS", "left")
    Rel(admin, teacherInfoSystem, "Administers", "HTTPS", "left")
    Rel(admin, emailSystem, "Sends Emails", "SMTP", "down")
    Rel(admin, workshopSystem, "Organizes Workshops", "HTTPS", "up")
    Rel(teacher, curriculumSystem, "Accesses if approved", "HTTPS", "right")
    Rel(teacher, teacherInfoSystem, "Manages own profile", "HTTPS", "left")

    UpdateElementStyle(admin, $bgColor="#F9D648FF", $fontColor="#000000", $borderColor="#C4972F")
    UpdateElementStyle(teacher, $bgColor="#8ABAD3FF", $fontColor="#000000", $borderColor="#045D75")
    UpdateElementStyle(curriculumSystem, $bgColor="#F0F0F0", $fontColor="#000000", $borderColor="#707070")
    UpdateElementStyle(teacherInfoSystem, $bgColor="#B8DEE6", $fontColor="#000000", $borderColor="#76A5AF")
    UpdateElementStyle(emailSystem, $bgColor="#F7E0B5", $fontColor="#000000", $borderColor="#DDBE7E")
    UpdateElementStyle(workshopSystem, $bgColor="#D1F4C9", $fontColor="#000000", $borderColor="#95C896")

    UpdateRelStyle(teacher, curriculumSystem, $textColor="#046307", $lineColor="#0D4006")
    UpdateRelStyle(teacher, teacherInfoSystem, $textColor="#046307", $lineColor="#0D4006")
    UpdateRelStyle(admin, curriculumSystem, $textColor="#860136", $lineColor="#540229")
    UpdateRelStyle(admin, teacherInfoSystem, $textColor="#860136", $lineColor="#540229")
    UpdateRelStyle(admin, emailSystem, $textColor="#860136", $lineColor="#540229")
    UpdateRelStyle(admin, workshopSystem, $textColor="#860136", $lineColor="#540229")
 }

```

* Teachers can sign up at https://teachers.bjc.berkeley.edu
  * For homeschoolers, they need to upload additional support documents.
* Admins can log in to approve, deny, or request more information for each request.
* Admins can merge duplicate teacher records.
* Admins can create and modify workshops and relevant registrations.
* Admins can see a dashboard of teacher stats.
* Teachers can log in to view protected solutions content.
* Admins can create and modify email templates.


## Installation:

### Environmental Variable
* We are not using `application.yml` (rails env framework). Instead, we use a `.env` file at directory root to load all env vars. Use `.env.example` as a reference for env format.
* Use tools like [overmind](https://github.com/DarthSim/overmind) or [foreman](https://github.com/ddollar/foreman) to load in the env vars.
* You probably need to configure your own oauth keys and database name/passwords.

### Postgres Installation

#### MacOS:
* `brew install postgresql chromedriver`
* Start postgres if necessary. `brew services start postgresql`

#### Linux/WSL:
* `sudo apt install postgresql`
* Create a postgres user.
  * `sudo su - postgres` (to get into postgres shell)
  * `createuser --interactive --pwprompt` (in postgres shell)
  * Save `DB_USER` and `DB_PASSWORD` fields in the `.env` file.
* Start postgres if necessary. `pg_ctlcluster 12 main start`
  * Note: if you are using WSL2 on windows, the command to start postgres is `sudo service postgresql start`

### Framework/Gem Installation
* `rvm use 3.2.3` # Double-check `.ruby-version`
* `bundle`
* `bin/rails db:setup` (Run this after setting up Postgres)
* `nvm install 14` Node v14 is needed
* `yarn install` Yarn is needed

### Spin Up Server
* Use tools like [overmind](https://github.com/DarthSim/overmind) or [foreman](https://github.com/ddollar/foreman) to boot up server with env vars loaded.
* If you are using `overmind`, you can simply `npm run dev`.

### Available Commands
- For RSpec tests run `bundle exec rspec`
- For Cucumber tests run `bundle exec cucumber`
- For Rubocop check run `bundle exec rubocop` (Autocorrect all with `bundle exec rubocop -a`)
- To make someone an admin use db console access
  - Using psql
    - First run `heroku pg:psql` (for Heroku) or `psql bjc_teachers_dev` (for local) to get into psql
    - Alternatively, you can use `rails db` to get into psql
    - Then
      ```
      UPDATE teachers
      SET admin = true
      WHERE Email LIKE '%@berkeley.edu%'
      ;
      ```
      Of course, you can swap in the email of your choice.
  - Using rails console
    - First run `heroku run rails console` (for Heroku) or `rails console` (for local) to get into rails console
    - Then
      ```
      Teacher.where("email LIKE '%@berkeley.edu%'").update_all(admin: true)
      ```

## JavaScript and CSS with Webpack

* `stylesheet_pack_tag` doesn't work. :(
* Use `import '*.scss' in a _JavaScript file, and webpack will compile correctly
* If you need a new CSS-only import, make a new CSS *and* a new JS file.

## Deployed Site:

- https://teachers.bjc.berkeley.edu

## Steps to Deploying on Heroku

- ... create a heroku app, the default heroku-22 stack should work.
- `heroku buildpacks:set heroku/nodejs` # this must be the first buildpack.
- `heroku buildpacks:add --index 2 heroku/ruby`
- `heroku addons:create heroku-postgresql`
- `heroku git -a [app-name]`
- Make your local changes and start the commit process
- `git add .`
- `git commit -m "<Message>"`
- `git push heroku master` (If this fails, try commenting the release command in `Procfile` for this first deployment only and go on to the next step. After you are done with the deployment, uncomment back the release command again. For more information, see [this PR](https://github.com/cs169/BJC-Teacher-Tracker/pull/15).)

If bundler install runs successfully, continue with the following commands to correctly setup the PostgreSQL database on Heroku:

- `heroku run bin/rails db:drop` (if this fails, you can skip this step)
- `heroku run bin/rails db:schema:load`
- `heroku run bin/rails db:seed`
- `heroku config:set ...` for each of the environment variables.
- `heroku open`



### CodeClimate Local Test

TODO: Link to download CodeClimate binaries for macOS.

```
https://codeclimate.com/downloads/test-reporter/test-reporter-latest-darwin-amd64
```
