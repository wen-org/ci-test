/*
* some common function and variable defind in this file
*/

// import groovy library
import groovy.time.*
import groovy.json.*
import net.sf.json.*

slave_script_dir = "${bigtest_dir}/slave_script"
jenkins_script_dir = "${bigtest_dir}/jenkins_script"
config_dir = "${jenkins_script_dir}/config"
python_script_dir = "${jenkins_script_dir}/python_script"
shell_script_dir = "${jenkins_script_dir}/shell_script"
distribute_mit_dir = "${jenkins_script_dir}/distribute_mit"
unittest_folder = "${jenkins_script_dir}/unittest"
integration_folder = "${jenkins_script_dir}/integration_test"
openNebula_dir = "${bigtest_dir}/opennebula_script"

// read config json file
CONFIG = readJSON file: "${config_dir}/config.json"

// log_dir is original all log folders
log_dir = CONFIG['log_dir']
timecost_config_folder = "${log_dir}/config/timecost_config"

// gle auto build dir
ROOT_DIR = "${env.HOME}/auto_build_pipeline"

GIT_USER = CONFIG['GIT_USER']
GIT_TOKEN = CONFIG['GIT_TOKEN']

// qa_account username
qa_User = CONFIG['qa_User']

jenkins_ip = CONFIG['JENKINS_IP']
jenkins_port = CONFIG['JENKINS_PORT']
jenkins_address = "http://${jenkins_ip}:${jenkins_port}"

hipchat_test_room = CONFIG['hipchat_test_room']

// ftp server info
ftpSrv='ftp.graphsql.com'
ftpUrl="ftp://${ftpSrv}"
ftpPath="/product/hourly"

// build os and test os mapping dict
build_os_dict = ['centos6', 'centos7', 'ubuntu14', 'ubuntu16']
//build_os_dict = ['centos6', 'centos7', 'ubuntu14']

// cluster and single server config
clusterConfig = "${config_dir}/env/cluster.json"
singleConfig = "${config_dir}/env/single.json"
tmpConf = readJSON file: "${clusterConfig}"
cluster_nodes_num = tmpConf["nodes"].size()

/*
* init function for each pipeline to set variables and create log dir
*/
def init() {
  // get buildUser from environment
  wrap([$class: 'BuildUser']) {
    BUILD_USER = env.BUILD_USER
  }
  NO_FAIL = NO_FAIL.trim()
  NODE_NAME = env.NODE_NAME
  env.PRODUCT = product_dir
  BUILD_NUMBER_SELF = currentBuild.number

  // it is not test_job/build_job
  if (JOB_ID_SELF == JOB_ID) {
    BUILD_NUMBER = BUILD_NUMBER_SELF
    FORCE = params.FORCE
  }

  // log_dir is identified by JOB_NAME and BUILD_NUMBER
  mark_tag_name = "${JOB_NAME}_${BUILD_NUMBER}"
  log_dir += "/${mark_tag_name}"
  // if test_by_tag is specified, use it to mark the pipeline
  if (params.test_by_tag != null && params.test_by_tag.trim() != "none") {
    mark_tag_name = params.test_by_tag
  }
  VERSION_FILE = log_dir + "/version"
  openNebula_log = log_dir + "/openNebula_log"

  if (JOB_ID != 'HOURLY') {
    hipchat_test_room = 'none'
  } else {
    PARAM = ''
  }

  // it is test_job/build_job
  if (JOB_ID_SELF != JOB_ID) {
    currentBuild.description = NODE_NAME
    log_dir += "/${NODE_NAME}"
    if (JOB_ID_SELF == "test_job") {
      log_dir += "_${PARALLEL_INDEX[-1..-1]}"
    }
  }
  log_url = "http://${CONFIG['log_review_machine']}/Log.php?directory=${log_dir}"
}

def pre_pipeline() {
  if (JOB_ID_SELF != JOB_ID) {
    sh """
      sudo service rpcbind start || true
      sudo mount -t nfs 192.168.11.9:/volume5/datapool /mnt/nfs_datapool || true
    """
  }
  create_log_dir()
  check_log_url()
  USER_NOTIFIED = sendToServer("/users/${USER_NAME}", 'GET')['result'][0]['hipchat_name']
  echo "User to notified is ${USER_NOTIFIED}"
}

/*
*  Instead of run comand one by one,
*  Combine all bash command together to run once.
*  Used for the command that has output redirection
*/
def run_bash(String command, Boolean showCmd = true) {
  if (showCmd) {
    echo command
  }
  sh "#!/bin/bash \n  ${command}"
}

/*
*  param: run_bash_mod is used to run command together.
*  get std output
*/
def run_cmd_get_stdout(String cmd, Boolean run_bash_mod = false, Boolean showCmd = true) {
  if (run_bash_mod) {
    if (showCmd) {
      echo cmd
    }
    cmd = "#!/bin/bash \n ${cmd}"
  }
  def result = sh(script: cmd, returnStdout: true)
  while (result.endsWith('\n')) {
    result = result.substring(0, result.length() - 1)
  }
  return result
}

/*
*  get std err
*/
def run_cmd_get_stderr(String cmd) {
  def redirect_cmd = "${cmd} 3>&1 1>&2 2>&3"
  def result = sh(script: redirect_cmd, returnStdout: true)
  while (result.endsWith('\n')) {
    result = result.substring(0, result.length() - 1)
  }
  return result
}


def check_log_url() {
  echo "\"\033[31mYou can check all logs at ${log_url}" +
      "\n=================================================" +
      "=========================================================\033[0m\""
}

/*
*  send curl to MIT REST server to get http result
*/
def sendToServer(url_suffix, method, data = null) {
  def url = "http://${CONFIG['rest_server_address']}/api"
  if (url_suffix != "") {
    url += url_suffix;
  }
  def res = ''
  if (method == "GET" || method == "DELETE") {
    res = run_cmd_get_stdout("curl -X ${method} ${url}")
  } else {
    res = run_cmd_get_stdout("curl -H 'Content-Type: application/json' -X ${method} "
        + " -d '${new JsonOutput().toJson(data)}' '${url}'")
  }
  return new JsonSlurper().parseText(res)
}

/*
*  send notification to Hipchat user
*  sub_test == true means it is not in master, but in test_job/build_job
*/
def notification(String parameters, String state, String user_name, String room_name,
      notify_dict) {
  if (JOB_ID_SELF == JOB_ID) {
    notify_dict["name"] = "${JOB_ID_SELF}#${BUILD_NUMBER_SELF}"
    notify_dict["url"] = "${jenkins_address}/job/${JOB_NAME_SELF}/${BUILD_NUMBER_SELF}"
  } else {
    notify_dict["name"] = "${JOB_ID_SELF}#${BUILD_NUMBER_SELF} of ${JOB_ID}#${BUILD_NUMBER}"
    notify_dict["url"] = "${jenkins_address}/job/${JOB_NAME_SELF}/${BUILD_NUMBER_SELF}"
  }
  def cmd = """ python "${python_script_dir}/notification.py" "${parameters}" "${state}" """ +
      """ "${USER_NOTIFIED}" "${room_name}" '${new JsonOutput().toJson(notify_dict)}' """
  sh cmd
  if (state == "FAIL") {
    run_bash """
      touch ${log_dir}/failed_flag
    """
  }
}

/*
*  split the string to get unittests and integrations array
*/
def remove_total(str) {
  def groups = str.tokenize('#')
  def new_groups = []
  for (def group in groups) {
    new_groups.push(group.tokenize('@')[0])
  }
  return new_groups
}

/*
* make jenkins output hyperlink
*/
String getHyperlink(String url, String text) {
  hudson.console.ModelHyperlinkNote.encodeTo(url, text)
}

@NonCPS def getEntries(m) {m.collect {k, v -> [k, v]}}


def git_clone(repo, path) {
  echo "git clone ${repo} in ${path}"
  run_bash("""
    git clone -b ${BASE_BRANCH} --quiet \
      https://${GIT_USER}:${GIT_TOKEN}@github.com/TigerGraph/${repo}.git ${path} --depth=1
  """, false)
}

def create_log_dir() {
  echo log_dir
  run_bash("""
    sudo mkdir -p '${log_dir}/bigtest_log'
    sudo chown -R graphsql:graphsql '${log_dir}/'
    sudo chmod 777 -R '${log_dir}'
    'env' &> '${log_dir}/bigtest_log/environment_variables.log'
  """)
}

// get branch name
def get_branch_name (repo) {
  return run_cmd_get_stderr("""
    python "${python_script_dir}/get_branch_name.py" "${PARAM}" "${repo}" "${BASE_BRANCH}"
  """)
}

def print_summary() {
  if (!fileExists(VERSION_FILE)) {
    return
  }
  def summary = sendToServer("/${JOB_ID_SELF.toLowerCase()}/${BUILD_NUMBER_SELF}/summary?stages=all",
      'GET')['result'];
  echo summary
  return summary
}

def print_err_summary() {
  def err_summary = sendToServer("/${JOB_ID_SELF.toLowerCase()}/${BUILD_NUMBER_SELF}/summary?stages=failed",
      'GET')['result'];
  echo err_summary;
  return err_summary;
}

def conclude_summary() {
  echo 'conclude summary'
  run_bash("""
    bash ${shell_script_dir}/conclude_summary.sh ${log_dir}
  """, false)
}

def check_if_aborted() {
  sleep 8
  def grep_info = 'It is aborted'
  def aborted = run_cmd_get_stdout("""
    actions=\$(curl --silent ${BUILD_URL}api/json | jq -r '.actions[]._class')
    echo \$actions
    for act in \$actions; do
      if [[ "\$act" == "jenkins.model.InterruptedBuildAction" ]]; then
        echo '${grep_info}'
      fi
    done
  """, true)
  echo aborted
  if (aborted.contains(grep_info)) {
    return true
  }
  return false
}

//combine ip list with srouce config file
//to generate the target config file
def clusterConfigGen(mList, srcFile, tgtFile) {
  println "Enter clusterConfigGen"
  def jsonSrc = readJSON file: srcFile
  def jsonTgt = new JSONObject()

  def nodesSrc = jsonSrc["nodes"]
  def nodesTgt = [:]
  def loginTgt = [:]
  if (mList.size() != nodesSrc.size()) {
    return false;
  }

  for (def i = 0; i < nodesSrc.size(); ++i) {
    nodesTgt.put(nodesSrc[i], mList[i].tokenize('_')[-1])
    loginTgt.put(nodesSrc[i], "graphsql graphsql")
  }

  jsonTgt["nodes.ip"] = nodesTgt
  jsonTgt["nodes.login"] = loginTgt
  jsonTgt["gpe.server"] = jsonSrc["gpe"]
  jsonTgt["gse.server"] = jsonSrc["gse"]
  jsonTgt["restpp.server"] = jsonSrc["restpp"]
  jsonTgt["zk.server"] = [:]
  jsonTgt["kafka.server"] = [:]
  jsonTgt["zk.server"]["nodes"] = nodesSrc
  jsonTgt["kafka.server"]["nodes"] = nodesSrc
  jsonTgt["tigergraph.user.name"] = "graphsql"
  jsonTgt["tigergraph.user.password"] = "graphsql"
  jsonTgt["tigergraph.root.dir"] = "/home/graphsql/tigergraph"
  jsonTgt["license.key"] = "curl -s ftp://ftp.graphsql.com/lic/license.txt".execute().text.trim();

  writeJSON file: tgtFile, json: jsonTgt, pretty: 4

  return true;
}

def auto_build(gle_branch, glelib_branch, utility_branch, third_party_branch, document_branch) {
  build job: 'gle_auto_build', parameters: [
    [$class: 'StringParameterValue', name: 'GLE_BRANCH', value: gle_branch],
    [$class: 'StringParameterValue', name: 'GLELIB_BRANCH', value: glelib_branch],
    [$class: 'StringParameterValue', name: 'utility_branch', value: utility_branch],
    [$class: 'StringParameterValue', name: 'third_party_branch', value: third_party_branch],
    [$class: 'StringParameterValue', name: 'document_branch', value: document_branch]
  ]
}

return this
