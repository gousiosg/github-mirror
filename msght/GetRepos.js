'use strict';

/*
 * Script GetRepos.js - script that grabs all github repositories for an Organization and
 * prints them to stdout. This also adds a webhook to the org.
 * The repo and org names can easily be piped into a file using '>' or '>>'.
 *
 * Input parameters:
 * -org: the name of the organization whose repos you want to grabs
 * -tr: the read token to be used to complete this operation
 * -tw: the webhook token to be used to create webhooks for orgs
 *
 * example use:
 *   node GetRepos.js -org microsoft -tr 0123456789012345678901234567890123456789 -tw 0123456789012345678901234567890123456789
 */
const GitHubApi = require('github');
const config = require('painless-config');
const Q = require('q');
const fs = require('fs');
const qlimit = require('qlimit');

//Strings for flags
const orgFlag = '-org';
const orgsFlag = '-orgs';
const hooksFlag = '-hooks';
const tokenReadFlag = '-tr';
const tokenHookFlag = '-tw';
const fileFlag = '-f';

//The data itself that is stored from the commandline arguments
let org;
let orgs;
let filepath;
let tokenHook = config.get('GHT_WEBHOOK_TOKEN');
let tokenRead = config.get('GHT_READ_TOKEN');
let hookSecret = config.get('GHT_WEBHOOK_SECRET');
let hookUrl;

var verbose = false;

//Read through all arguments to find the organization and token
for (var k = 0; k < process.argv.length; k++) {
  switch (process.argv[k]) {
    case orgFlag:
      org = process.argv[++k];
      break;

    case orgsFlag:
      orgs = process.argv[++k];
      break;

    case tokenReadFlag:
      tokenRead = process.argv[++k];
      break;

    case tokenHookFlag:
      tokenHook = process.argv[++k];
      break;

    case fileFlag:
      filepath = process.argv[++k];
      break;

    case hooksFlag:
      hookUrl = config.get('GHT_WEBHOOK_URL');
      break;
  }
}

//If we didn't set the org, inform the user and exit
if (!org && !orgs) {
  console.log("Must specify -org or -orgs. Exiting");
  process.exit(1);
}

//If we didn't set the token, inform the user and exit
if (!tokenHook || !tokenRead) {
  console.log("Must pass the read and webhook tokens with the -tr and -tw flags, respectively. Exiting");
  process.exit(1);
}

var github = new GitHubApi({
  headers: {
    "user-agent": "msghtdev"
  },
  Promise: Q.Promise,
  timeout: 5000
});

github.authenticate({
  type: "token",
  token: tokenRead
});

if (org) {
  orgs = Q([org]);
} else {
  orgs = loadOrgs(orgs);
}

orgs.then(orgList => {
  getReposForOrgs(orgList, filepath)
    .then(() => { checkWebHooks(orgList, hookUrl, hookSecret); })
    .then(() => { process.exit(0); })
    .catch(err => {
      console.log(err);
    });
});

function getReposForOrgs(orgs, path) {
  const limiter = qlimit(1);
  return Q.allSettled(orgs.map(limiter(o => {
    return getRepos(o).then(repos => { return writeList(o, repos, path); });
  })));
}

function getRepos(org) {
  let list = [];
  return visitAll(github.repos.getForOrg({ org: org, per_page: 100 }), body => {
    list = list.concat(body.map(repo => repo.name));
  }).then(() => {
    return list.sort(function (a, b) {
      return a.toLowerCase().localeCompare(b.toLowerCase());
    });
  });
}

function getOrgs() {
  return collect(
    github.users.getOrgs({ per_page: 100 }),
    org => org.login,
    (a, b) => { return a.toLowerCase().localeCompare(b.toLowerCase()); }
  );
}

function collect(query, selector, sorter) {
  let list = [];
  return visitAll(query, body => {
    list = list.concat(body.map(selector));
  }).then(() => {
    return sorter ? list.sort(sorter) : list;
  });
}

function loadOrgs(path) {
  if (path.startsWith('*')) {
    path = path.substr(1);
    return getOrgs().then(orgList => { return writeList(null, orgList, path); });
  }
  // read the orgs file and break it into trimmed lines
  const orgString = fs.readFileSync(path, 'utf8');
  return Q(orgString.split(/\r?\n/).filter(element => !!element).map(org => org.trim()));
}

function writeList(prefix, list, path) {
  prefix = prefix ? prefix + ' ' : '';
  if (path === 'console') {
    list.forEach(entry => {
      console.log(`${prefix}${entry}`);
    });
    return Q(list);
  }

  var output = fs.createWriteStream(path, { flags: 'a' });
  list.forEach(repo => {
    output.write(`${prefix}${repo}\n`);
  });
  output.end();
  return Q(list);
}

function checkWebHooks(orgs, url, secret) {
  const limiter = qlimit(1);
  return Q.allSettled(orgs.map(limiter(o => {
    return checkWebHook(o, url, secret);
  })));
}

function checkWebHook(org, url, secret) {
  if (!url) {
    return Q(null);
  }

  let hook = null;
  return visitAll(github.orgs.getHooks({ org: org, per_page: 100 }), hooks => {
    hook = hook || hooks.find(entry => entry.config.url.toLowerCase() === url.toLowerCase());
  }).then(() => {
    if (hook) {
      return Q(null);
    }
    const config = {
      url: hookUrl,
      content_type: 'json',
      secret: secret
    };
    return github.orgs.createHook({ org: org, name: 'web', config: config, events: '*', active: true });
  });
}

function visitAll(initial, visitor) {
  const deferred = Q.defer();
  initial.then(res => {
    createWalker(visitor, deferred)(null, res);
  }, err => { deferred.reject(err) });
  const result = deferred.promise;
  return result;
}

function createWalker(visitor, deferred) {
  const walker = (err, response) => {
    if (err) {
      return Q.reject(err);
    }

    visitor(response);
    if (github.hasNextPage(response)) {
      github.getNextPage(response, walker)
    } else {
      deferred.resolve(null);
    }
  }
  return walker;
}
