'use strict';

const Q = require('q');
const mongo = require('mongodb');
const yaml = require('js-yaml');
const fs = require('fs');
const qlimit = require('qlimit');

const config = yaml.safeLoad(fs.readFileSync('../config.yaml', 'utf8'));
const username = config.mongo.username;
const password = config.mongo.password;
const host = config.mongo.host;
const port = config.mongo.port;
const db = config.mongo.db;
const ssl = config.mongo.ssl ? '?ssl=true' : '';
const replicas = config.mongo.replicas ? config.mongo.replicas.strip('not sure here') : '';
const url = `mongodb://${username}:${password}@${host}:${port}${replicas}/${db}${ssl}`;

mongo.connect(url, function (err, db) {
  db.collections(function (err, collections) {
    dropCollection(db, collections, 0).then(() => {
      db.close().then(() => { console.log('Done'); });
    });
  });
});

function dropCollection(db, collections, index, deferred) {
  deferred = deferred || Q.defer();
  if (index >= collections.length) {
    deferred.resolve();
    return deferred.promise;
  }

  const name = collections[index].s.name;
  console.log(`Deleting ${name} ...`);
  db.dropCollection(name, err => {
    if (err) {
      deferred.reject(err);
    } else
      dropCollection(db, collections, ++index, deferred);
  });
  return deferred.promise;
}
