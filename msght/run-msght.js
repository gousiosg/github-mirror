/*
 * Script run-msght.js - script that runs ght's retrieve-repo command concurrently and cycles through keys. If
 *     a key does not have access to a repo, then it will try again with another key. This outputs
 *     directly to stdout, which can/should be piped into a logfile.
 *
 * Input Pameters:
 *     -k: the path to the keys file
 *     -p: the path to the projects file, which should be of the format: organization repo
 *     -t: the number of processes to run concurrently (optional)
 *
 * Example use:
 *     node run-msght.js -k keys.txt -p projects.txt -t 4
 *     //This will run GHT on all projects using the given keys.
 *     //This will run 4 processes concurrently.
 *
 * NOTE: This is intended for use by the msght-functions script
*/
const exec = require('child_process').exec;
const spawn = require('child_process').spawn;
const appInsights = require('applicationinsights');
const fs = require('fs');
const config = require('painless-config');

const keys_flag = '-k';
const repos_flag = '-r';
const processes_flag = '-t';

//Global variables used throughout the script
var keys_file_path, repos_file_path;
var processes = 4;
var keys = [];
var orgs = [];
var repos = [];
var process_map = {}; //0 = running, 1 = stopped
var proc_active = {}; //0 = inactive, 1 = active
var proc_pid = {}; //Maps ID to PID of process
var proc_finished = {}; //0 = thread hasn't hit end, 1 == thread has hit end
var proc_access = {}; //0 = unknown access, 1 = verified access
var orgIndex = 0;
var finishedCount = 0;

//Initialize Application Insights
appInsights.setup(config.get('APPINSIGHTS_INSTRUMENTATIONKEY')).setAutoCollectExceptions(true).start();
const appInsightsClient = appInsights.getClient(config.get('APPINSIGHTS_INSTRUMENTATIONKEY'));

//Grab the arguments
for (var argI = 0; argI < process.argv.length; ++argI) {
  switch (process.argv[argI]) {
    case keys_flag:
      keys_file_path = process.argv[++argI];
      break;
    case repos_flag:
      repos_file_path = process.argv[++argI];
      break;
    case processes_flag:
      processes = parseInt(process.argv[++argI], 10);
      break;
  }
}

//Check if all args were passed in correctly
if (!keys_file_path || !repos_file_path) {
  console.log('Must pass the path to projects file using -p flag and \
 the keys file using the -k flag. Optionally pass in the number of \
 processes with the -t flag. for example: \r\n\
 node msght_run.js -k keys.txt -r repos.txt -t 4 ');
  process.exit(1);
}

// Load the keys, repos, and orgs, and start processing
keys = readLines(keys_file_path);
const repoSpecs = readLines(repos_file_path);
repoSpecs.forEach(storeOrgAndRepo);
printStartMessage();
start();

function readLines(path) {
  const orgString = fs.readFileSync(path, 'utf8');
  return orgString.split(/\r?\n/).filter(element => !!element).map(org => org.trim());
}

//Store the org and repo gathered when reading orgs.txt
function storeOrgAndRepo(line) {
  var parts = line.split(/ /);
  if (parts.length == 2) {
    orgs[orgs.length] = parts[0];
    repos[repos.length] = parts[1];
  }
}

//Prints the starting message that identifies the number of processes,
//  keys, orgs, and repos.
function printStartMessage() {
  console.log('[year-month-day: hour-minute-second]:');
  log('Grabbed all keys, org names, and repo names.', -1);
  log('Number of processes: ' + processes, -1);
  log('Number of keys: ' + keys.length, -1);
  log('Number of orgs: ' + orgs.length, -1);
  log('number of repos: ' + repos.length, -1);
  log('starting...', -1);
}

//Function start - Starts spawning 't' number of processes
function start() {
  appInsightsClient.trackEvent("Data Collection Starting", { Details: "MSGHT has begun collecting data." });
  for (var i = 0; i < processes & i < orgs.length; i++) {
    proc_finished[i] = 0;
    proc_active[i] = 0;
    proc_access[i] = 0; //Unknown access
    setupSpawn(i);
  }
}

//Function setupSpawn - Begins the spawning process for one 'id'
function setupSpawn(id) {
  spawnProcess(id, orgIndex % keys.length, orgIndex++ % orgs.length, 0);
}

//Function spawnProcess - Determines if no key has access to an organization
//  and starts the new process.
function spawnProcess(id, keyI, orgI, num_tries) {
  if (num_tries >= keys.length) {
    appInsightsClient.trackEvent("Inaccessible Repo", { SpawnID: id.toString(), Details: "No given key was able to access org: " + orgs[orgI] + ", repo: " + repos[orgI] });
    log(id + ": No key works for org: " + orgs[orgI] + ', repo: ' + repos[orgI], id.toString());

    //Move on to the next org/repo
    startNext(id);
    return;
  }

  //Show which set of keys and project data are starting up
  log('keyI: ' + keyI + ', orgI: ' + orgI + ' out of ' + (orgs.length - 1) + ', Number of key tries: ' + num_tries, id);
  appInsightsClient.trackEvent("Beginning Data Acquisition", { SpawnID: id.toString(), Details: "Data acquisition has begun for org: " + orgs[orgI] + " repo: " + repos[orgI] });
  startProcess(keys[keyI], orgs[orgI], repos[orgI], id, keyI, orgI, num_tries);
}

//Function startProcess - Does the actual spawning of a process
//  and sets up its handling.
function startProcess(key, org, repo, id, keyI, orgI, num_tried) {
  if (proc_active[id] == 1) {
    log("/!\\WARNING: Trying to start new process while active.", id);
  }

  log(`STARTING RETRIEVE  ==== ${org}/${repo}`);
  proc_active[id] = 1;
  var proc = spawn('ruby', [`-I${__dirname}/../lib`, `${__dirname}/../bin/ght-retrieve-repo`,
    '-c', `${__dirname}/../../config.yaml`, '-t', key, '-l', 50000, org, repo],
    { detached: true });
  process_map[proc.pid] = 0; //Mark that the process is running
  proc_pid[id] = proc.pid;
  log("Process id is: " + proc.pid, id);
  proc.stdout.on('data', function (line) {
    processData(line, proc, id, repo, org, key, keyI, orgI, num_tried)
  });
  proc.stderr.on('data', function (line) {
    processData(line, proc, id, repo, org, key, keyI, orgI, num_tried)
  });
  proc.on('error', function (err) {
    hitException(id, err);
  });
  proc.on('exit', function (code, signal) {
    exitProcess(id, proc, proc.pid, code, signal, repo, org)
  });
}

//Function exitProcess - called when a process finshes. Starts on the
//  next process
function exitProcess(id, proc, pid, code, signal, repo, org) {
  proc.kill('SIGKILL');
  proc_active[id] = 0;
  if (signal == null && process_map[proc.pid] == 0 && proc_pid[id] == pid) {
    process_map[proc.pid] = 1; //Mark that it has been finished
    appInsightsClient.trackEvent("Repo Data Gathered", {
      SpawnID: id.toString(),
      Repository: repo, Organization: org
    });
    startNext(id);
  }
  else if (process_map[proc.pid] == 1) {
    log("Process with pid: " + pid + " exited with signal: " + signal + " and code: " + code, id);
  }
  process_map[proc.pid] = 1; //Mark that process is finished
}

//Function hitException - called when a process hits an exception.
function hitException(id, err) {
  log("Hit error", id);
  log(error, id);
  appInsightsClient.trackException(err);
}

//Function processData - Called when data is received by a process
//  through stdout. Checks if the key doesn't have access and Prints
//  out the output.
function processData(line, proc, id, repo, org, key, keyI, orgI, num_tried) {
  log(line, id);
  line = line.toString();
  if (proc_active[id] == 0 || proc_pid[id] != proc.pid) {
    log("/!\\ Process receiving data after becoming inactive. Old PID: " + proc.pid + " new PID is: " + proc_pid[id] + " Data is: " + line, id);
    return;
  }

  if (line.indexOf('404, Status: Not Found') > -1 && proc_access[id] == 0) {
    log("PID: " + proc.pid + ", Key whose first four characters are: " + key.substring(0, 4) +
      "could not access org: " + org + " repo: " + repo, id);
    appInsightsClient.trackEvent("Key Does Not Have Access to Repo",
      { SpawnID: id.toString(), Key: key.substring(0, 4), Repository: repo, Org: org });

    proc.kill('SIGKILL');
    process_map[proc.pid] = 1;
    proc_active[id] = 0;
    spawnProcess(id, (keyI + 1) % keys.length, orgI, ++num_tried);
  }
  else {
    proc_access[id] = 1; //Mark that it has access
  }
}

//Function startNext - starts a process on its next task. Checks if
//  all repos have been processed, are currently being processed,
//  or if there's more work that needs doing.
function startNext(id) {
  log("Process finished", id);
  if (proc_finished[id] >= 1) {
    log("Process trying to finish more than once", id);
    return;
  }
  if (orgIndex >= orgs.length) {
    ++finishedCount;
    proc_finished[id] += 1;
    log("Finshed count: " + finishedCount, id);
    if (finishedCount >= processes || finishedCount >= orgs.length) {
      appInsightsClient.trackEvent("Data Collection Complete");
      for (var i in proc_finished) {
        log("Finished state: " + proc_finished[i], i);
      }
      log("All repo data gathered. Exiting.", id);
      process.exit(0);
    }
  }
  else if (orgIndex < orgs.length) {
    log("Starting on next process", id);
    log("Finished count: " + finishedCount, id);
    setupSpawn(id);
  }
  else {
    log("Finished count: " + finishedCount, id);
  }
}


//Function log - logs the data with the date-time prepended (primarily for debugging)
function log(string, id) {
  var date = new Date(Date.now());
  console.log('[' + date.getFullYear() + '-' + (date.getMonth() + 1) + '-' + date.getDate() + ': ' + date.getHours() + '-' + date.getMinutes() + '-' + date.getSeconds() + ']-SpawnID: ' + id + ': ' + string);
}