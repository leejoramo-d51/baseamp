<!-- badges/ -->
[![Build Status](https://secure.travis-ci.org/kvz/baseamp.png?branch=master)](http://travis-ci.org/kvz/baseamp "Check this project's build status on TravisCI")
[![NPM version](http://badge.fury.io/js/baseamp.png)](https://npmjs.org/package/baseamp "View this project on NPM")
[![Dependency Status](https://david-dm.org/kvz/baseamp.png?theme=shields.io)](https://david-dm.org/kvz/baseamp)
[![Development Dependency Status](https://david-dm.org/kvz/baseamp/dev-status.png?theme=shields.io)](https://david-dm.org/kvz/baseamp#info=devDependencies)
<!-- /badges -->

# baseamp

Convert your Markdown todo lists to Basecamp Todolists and back

## Install

Being a commandline tool primarily, Baseamp prefers to be installed globally:

```bash
npm install -g baseamp
```

## Use

First set these environment keys:

```
export BASECAMP_USERNAME="<your private username>"
export BASECAMP_PASSWORD="<your private password>"
export BASECAMP_ACCOUNT_ID="<your private account id (1st number in urls)>"
export BASECAMP_PROJECT_ID="<your private project id (2nd number in urls)>"
```

**WARNING: Use a test project first, Baseamp will overwrite todos in existing projects!**

To download (from Basecamp API -> local markdown):

```bash
$ baseamp download -
## Bugs (this list should always be emptied first) (#21402412)

 - [ ] TIK Big file upload lists can exceed the assemblies.files database field length: http://support.transloadit.com/discussions/problems/13485-problem-with-assemblies-page-files-display (#133063190)
 - [ ] TIK result: false is ignored if step is piped into a storage step (#133071595)

## Documentation (#21403029)

 - [ ] Add ffmpeg new stack lists, link them, show lists which formats they support and which not directly in the docs, when one should use which and then also show the preset contents for each stack version (#133067237)

...etc...
```

To upload (from local markdown -> Basecamp API):

To download (from Basecamp API -> local markdown):

```bash
$ baseamp sync ./Our-Todos.md
```

## Warning: Sync Behavior & Limitations

Because our two datasources (a markdown file and the basecamp api) weren't really designed to run in sync, Baseamps syncing is far from perfect.

Here are pointers on behavior and things to watch out for.

When uploading, Baseamp:

 - Creates lists & todos that do not exists
 - Updates lists & todos that we already track the `(#id)` of in markdown text
 - Never deletes something that exist on Basecamp, but not in local markdown, as someone else may have added this item online.

When downloading, Baseamp:

 - Extracts full Todolists of a project, and saves them to a markdown file (or STDOUT), overwriting anything that was already there.
 - Sorts todos within lists alphabetically (`completed`, `due_at`, `assignee`, `content`)

When syncing, Baseamp:

 - Does a *download* after an *upload*, in order to save the IDs locally of newly created todos. Recommended mode of operation. Only works against a local `.md` file, not with STDIN/OUT

Baseamp cannot sync a todo's attachments or contents, but also won't override them, so you can safely use the webinterface to enrich todos.

There is no concept of sub-todos.

Keep in mind that if you remove 1 item from a list, it can result in `position` updates for siblings in that list.

During a sync, when there are conflicting values, the local Markdown file is leading. However, Baseamp does not uncomplete remotely completed items as the usecase for that is limited, and this allows people to check off items online.

## Use Git too!

If you want to avoid having other values overwritten, keep your Markdown file in Git, and do a download before editting & syncing.

This allows the use of a `Makefile` such as:

```bash
download: install
	git pull
	git add --all .
	git commit -am "Updated todolist" || true
	git push
	source env.sh && node_modules/.bin/baseamp download ./Backup.md
	cp ./Backup.md ./Basecamp.md
	git diff --color | cat || true
	git add --all .
	git commit -am "Downloaded from Basecamp" || true
	git push

sync: install
	@git pull
	@git add --all .
	git commit -am "Updated todolist" || true
	git push
	source env.sh && node_modules/.bin/baseamp download ./Backup.md
	git diff --color | cat || true
	@test -z "$$(git status --porcelain)" || (echo "--> There are remote changes since you were last here. Copy your changes, type 'make download', paste your changes, try sync again. " && false)
	source env.sh && node_modules/.bin/baseamp sync ./Basecamp.md
	git diff --color | cat || true
	@git add --all .
	git commit -am "Synced with Basecamp" || true
	git push
```

Now if you type `make sync` in your Git todolist repo, you'll never overwrite remote changes by accident, and you always have a backup in `Backup.md`.

## Todo

 - [ ] Support for rate limiter (500 req/10 minutes)
 - [ ] Remove unnecessary fat arrows
 - [ ] Tests for upload
 - [ ] remoteIds should be an instance variable (deal with async scope tho)
 - [ ] Summarize changes. Use that to avoid a double `Retrieving todolists...`
 - [ ] Consider the strategy of Markdown files never clearing Basecamp todo properties. E.g. only adding/changing assignees & dates, not clearing them. Not clearing completed == true.
 - [x] Add `weekstarter` mode, gives a quick overview of Last week / This week
 - [x] Write completed todos at bottom of md list
 - [x] Better positioning
 - [x] Due date mapping
 - [x] User mapping
 - [x] Fix SKIPOSes
 - [x] Figure out how to deal with positioning. One update triggers many remotely.
 - [x] Sync (combining upload, download)
 - [x] Skip uploads if payload is equal
 - [-] ~~Make upload support STDIN~~
 - [x] Upload
 - [x] Rename download to download, upload to upload
 - [x] Fix download bug duplicating todos over different lists

## Contribute

I'd be happy to accept pull requests. If you plan on working on something big, please first give a shout!

### Compile

This project is written in [CoffeeScript](http://coffeescript.org/), but the JavaScript it generates is commited back into the repository so people can use this module without a CoffeeScript dependency. If you want to work on the source, please do so in `./src` and type: `make build` or `make test` (also builds first). Please don't edit generated JavaScript in `./lib`!

### Test

Run tests via `make test`.

To single out a test use `make test GREP=30x`

### Development use

```bash
source env.sh
DEBUG=Baseamp:* ./bin/baseamp.js download -

source env.sh && make build && DEBUG=Baseamp:* ./bin/baseamp.js sync /tmp/full.md
```

Or use Makefile shortcuts

```bash
make run-download
make run-upload
```

### Release

Releasing a new version to npmjs.org can be done via `make release-patch` (or minor / major, depending on the [semantic versioning](http://semver.org/) impact of your changes). This:

 - updates the `package.json`
 - saves a release commit with the updated version in Git
 - pushes to GitHub
 - publishes to npmjs.org

## Authors

* [Kevin van Zonneveld](https://twitter.com/kvz)

## License

[MIT Licensed](LICENSE).

## Sponsor Development

Like this project? Consider a donation.
You'd be surprised how rewarding it is for me see someone spend actual money on these efforts, even if just $1.

<!-- badges/ -->
[![Gittip donate button](http://img.shields.io/gittip/kvz.png)](https://www.gittip.com/kvz/ "Sponsor the development of baseamp via Gittip")
[![Flattr donate button](http://img.shields.io/flattr/donate.png?color=yellow)](https://flattr.com/submit/auto?user_id=kvz&url=https://github.com/kvz/baseamp&title=baseamp&language=&tags=github&category=software "Sponsor the development of baseamp via Flattr")
[![PayPal donate button](http://img.shields.io/paypal/donate.png?color=yellow)](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=kevin%40vanzonneveld%2enet&lc=NL&item_name=Open%20source%20donation%20to%20Kevin%20van%20Zonneveld&currency_code=USD&bn=PP-DonationsBF%3abtn_donate_SM%2egif%3aNonHosted "Sponsor the development of baseamp via Paypal")
[![BitCoin donate button](http://img.shields.io/bitcoin/donate.png?color=yellow)](https://coinbase.com/checkouts/19BtCjLCboRgTAXiaEvnvkdoRyjd843Dg2 "Sponsor the development of baseamp via BitCoin")
<!-- /badges -->
