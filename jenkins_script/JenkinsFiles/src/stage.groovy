// import groovy library
import groovy.time.*

def stage_QA_check() {
  def stage_name = "check QA issue existance"
  stage (stage_name) {
    // if JOB is merge_request_pipeline and FORCE = true and BUILD_USER is 'QA Duty', can skip QA check
    if (FORCE == false || BUILD_USER != qa_User) {
      echo "${stage_name} starts"
      // check every 10 minutes
      def times_max = 24 * 6, interval = 10, counter = 0
      while (counter < times_max) {
        // get the stderr and check whether it has error
        def result = UTIL.run_cmd_get_stderr("""python "${python_script_dir}/issue_manager.py" check QA Bug QA_HOURLY_FAILURE""")
        if (result != "") {
          def stage_err = "It is in waiting list due to QA Hourly Failure."
          if (FORCE == true && BUILD_USER != qa_User) {
             stage_err = "${stage_err} ${qa_User} not login, so -FORCE is not taking effect. "
          }
          if (counter == 0) {
            echo "${stage_err} ${result.trim()}"
            UTIL.notification('', 'STATUS', USER_NAME, hipchat_test_room, ["Reason": stage_err])
          }
        } else {
          break
        }
        sleep interval * 60
        echo "Times: ${counter}, will sleep ${interval} minutes, then re-retry ..."
        counter += 1
      }
      if (counter == times_max) {
        def stage_err = "Timeout due to QA Hourly Failure after 24 hours."
        UTIL.notification('', 'FAIL', USER_NAME, hipchat_test_room, ["Reason": stage_err])
        echo stage_err
        error(stage_err)
      }
    }
  } // stage end
}

def stage_validate() {
  def stage_name = "validation"
  stage (stage_name) {
    if (params.test_by_tag != null && params.test_by_tag.trim() != "none") {
      echo "No need to validate pull request because test_by_tag is specified"
      return;
    }
    echo "${stage_name} starts"
    def validate_state = "PRE"
    if (JOB_ID == 'WIP') {
      validate_state = 'WIP'
    }
    lock('end2end_git'){
      def result = UTIL.run_cmd_get_stderr("""python "${python_script_dir}/validate.py" """ +
          """ "${PARAM}" "${validate_state}" "${FORCE}" "${BASE_BRANCH}" """)
      if (result != "") {
        def stage_err = "${result.trim()}"
        echo stage_err
        if (result.startsWith("WARNING: ")) {
          UTIL.notification(PARAM, 'STATUS', USER_NAME, hipchat_test_room, ["WARNING": "${stage_err.substring(9)}"])
        } else {
          UTIL.notification(PARAM, 'FAIL', USER_NAME, hipchat_test_room, ["Reason": stage_err])
          error(stage_err)
        }
      }
    }

    // register in MIT3.0

    // check throttle
    def opCount = UTIL.sendToServer("/users/${USER_NAME}/checkThrottle", 'GET')['result']
    if (opCount >= CONFIG['user_throttle']) {
      def stage_err = "Your running mit/wip + debugging job can not be larger than " +
          "${CONFIG['user_throttle']}. You have ${opCount} now."
      echo stage_err
      UTIL.notification(PARAM, 'FAIL', USER_NAME, hipchat_test_room,
          ["Reason": stage_err, "Comment": "You can use mit -ls to check your running mit/wip" +
              ", and use mit -return node_ip to return your debugging node"])
      error(stage_err)
    }
  } // stage end
}

def stage_merge() {
  stage ('merge pull requests') {
    // if FORCE is true and BUILD_USER is 'QA Duty', force push
    if (FORCE == false || BUILD_USER != qa_User) {
      echo 'checking QA Hourly Status before merging starts'
      def result = UTIL.run_cmd_get_stderr("""python "${python_script_dir}/issue_manager.py" check QA Bug QA_HOURLY_FAILURE""")
      if (result != "") {
        def check_err = "Merge to base branch failed due to QA Hourly Failure.\n" +
            "        MIT will re-submit this job for you."
        echo check_err
        echo result
        resubmit_job()
        UTIL.notification('', 'FAIL', USER_NAME, hipchat_test_room, ["Reason": check_err])
        error(check_err)
      }
    }
    echo "merge pull requests starts"
    lock('end2end_git') {
      def res = UTIL.run_cmd_get_stderr("""python "${python_script_dir}/merge_pull_request.py" """ +
          """ "${PARAM}" "${BUILD_URL}" "${VERSION_FILE}" """)
      if (res != "") {
        def merge_err = "Merge pull requests failed. <p>${res.trim()}</p>"
        echo merge_err
        UTIL.notification('', 'FAIL', USER_NAME, hipchat_test_room, ["Reason": merge_err])
        error(merge_err)
      }
    }
    // only if PARAM contains gle, do gle auto build for gle master branch
    //     as the feature branch is already merged
    if (PARAM.contains('gle')) {
      try {
        echo 'GLE auto build after merging'
        UTIL.auto_build(params.BASE_BRANCH, params.BASE_BRANCH, params.BASE_BRANCH, params.BASE_BRANCH, params.BASE_BRANCH)
      } catch (err) {
        def auto_build_err = "GLE auto build failed after merging"
        echo auto_build_err
        println err
        UTIL.notification('', 'FAIL', USER_NAME, hipchat_test_room, ["Reason": auto_build_err])
        error(auto_build_err)
      }
    }
  } //stage end
}


def resubmit_job() {
  def param_str = PARAM.replaceAll("#", "%23")
  def resubmit_url = "http://${CONFIG['jenkins_account']}:${CONFIG['jenkins_pwd']}" +
      "@${jenkins_ip}:${jenkins_port}/job/${JOB_NAME}/buildWithParameters"
  sh """
    curl --fail -G -X POST "${resubmit_url}" \
        --data "BIGTEST_BASE_BRANCH=${BIGTEST_BASE_BRANCH}" \
        --data "USER_NAME=${USER_NAME}" --data "PARAM=${param_str}" --data "BASE_BRANCH=${BASE_BRANCH}" \
        --data-urlencode "UNITTESTS=${UNITTESTS}" --data-urlencode "INTEGRATION=${INTEGRATION}" \
        --data-urlencode "CLUSTER_TYPE=${CLUSTER_TYPE}" \
        --data-urlencode "SKIP_BUILD=${SKIP_BUILD}"
  """
}

def once_success(start_t, msg) {
  UTIL.sendToServer("/${JOB_ID.toLowerCase()}/${BUILD_NUMBER}/nodeOnline", "GET")
  def timecost = TimeCategory.minus(new Date(), start_t).toString()
  def data = ["status": "SUCCESS", "end_t": new Date().format("yyyy-MM-dd HH:mm:ss"),
      "timecost": timecost]
  // ignore SANITIZER test, so it will not affect the data precision
  if (SANITIZER != "none" || DEBUG_UT != "none" || Integer.parseInt(NO_FAIL) >= 2 || SKIP_BUILD != "false"
      || (INTEGRATION == "none" && UNITTESTS == "none")) {
    data["message"] = "ignore"
  }
  UTIL.sendToServer("/${JOB_ID.toLowerCase()}/${BUILD_NUMBER}", 'PUT', data)
  UTIL.notification(PARAM, 'PASS', USER_NAME, hipchat_test_room,
      ["Result": msg, "timecost": timecost])

  UTIL.conclude_summary()
  UTIL.print_summary()
  remove_mark_tag()
  if (JOB_ID == "MIT" && SANITIZER == "none" && DEBUG_UT == "none") {
    calculate_time_cost()
  }
  sh "rm -rf ${bigtest_dir}"

  currentBuild.result = 'SUCCESS'
}

def once_failed(err) {
  UTIL.sendToServer("/${JOB_ID.toLowerCase()}/${BUILD_NUMBER}/revertAll", 'GET')
  UTIL.sendToServer("/${JOB_ID.toLowerCase()}/${BUILD_NUMBER}/nodeOnline", "GET")
  def data = ["status": "FAILURE", "end_t": new Date().format("yyyy-MM-dd HH:mm:ss")]
  if (UTIL.check_if_aborted() == false) {
    data["message"] = "${UTIL.print_err_summary()}"
    currentBuild.result = 'FAILURE'
  } else {
    data["status"] = "ABORTED"
    currentBuild.result = 'ABORTED'
  }
  UTIL.sendToServer("/${JOB_ID.toLowerCase()}/${BUILD_NUMBER}", 'PUT', data)

  UTIL.conclude_summary()
  UTIL.print_summary()
  remove_mark_tag()
  check_if_node_break()
  sh "rm -rf ${bigtest_dir}"

  if (JOB_ID == "HOURLY") {
    resubmit_job()
  }
}

// Mark as stable
def tag_stable() {
  def tag_res = UTIL.run_cmd_get_stderr("python '${python_script_dir}/tag_manager.py' " +
      " '${CONFIG['qa_stable_tag']}' '${VERSION_FILE}' create")
  if (tag_res != "") {
    def tag_err = "Tag stable failed."
    echo "${tag_err} ${tag_res.trim()}"
    UTIL.notification('', 'FAIL', USER_NAME, hipchat_test_room, ["Reason": tag_err])
    error(tag_err)
  }
  // store binary in 11.10 ftp server
  echo 'store binary in 11.10 ftp server'
  UTIL.run_bash("""
    binary_files=\$(ls ${log_dir}/build_*/*tigergraph.bin)
    for b_f in \$binary_files; do
      b_f_name=\$(basename \$b_f)
      b_f_name="\${b_f_name%.*}"
      curl ${ftpUrl} -Q "DELE ${ftpPath}/\${b_f_name}_3.bin" -Q "RNFR ${ftpPath}/\${b_f_name}_2.bin" -Q "RNTO ${ftpPath}/\${b_f_name}_3.bin"
      curl ${ftpUrl} -Q "DELE ${ftpPath}/\${b_f_name}_2.bin" -Q "RNFR ${ftpPath}/\${b_f_name}_1.bin" -Q "RNTO ${ftpPath}/\${b_f_name}_2.bin"
      curl ${ftpUrl} -Q "DELE ${ftpPath}/\${b_f_name}_1.bin" -Q "RNFR ${ftpPath}/\${b_f_name}.bin" -Q "RNTO ${ftpPath}/\${b_f_name}_1.bin"
      curl --ftp-create-dirs -T \$b_f ${ftpUrl}/${ftpPath}/\${b_f_name}.bin
    done
  """, false)
}

def remove_mark_tag() {
  // if VERSION_FILE not exit, then gworkspace failed, so tag does not exist
  // if test_by_tag is specified, do not remove the specified tag.
  if (!fileExists(VERSION_FILE) || (params.test_by_tag != null && params.test_by_tag.trim() != "none")) {
    return
  }
  def tag_res = UTIL.run_cmd_get_stderr("python '${python_script_dir}/tag_manager.py' " +
      "'${mark_tag_name}' '${VERSION_FILE}' delete")
  if (tag_res != "") {
    def tag_err = "Failed to remove tag that marks commits for current pipeline"
    echo "${tag_err} ${tag_res.trim()}"
    UTIL.notification('', 'FAIL', USER_NAME, hipchat_test_room, ["Reason": tag_err])
    error(tag_err)
  }
}

def calculate_time_cost() {
  UTIL.run_bash """
    python ${unittest_folder}/update_ut_timecost.py ${log_dir}/unit_test_summary \
        ${timecost_config_folder}/unittest_timecost.json
    python ${integration_folder}/update_it_timecost.py ${log_dir}/integration_test_summary \
        ${timecost_config_folder}/integration_timecost.json
  """
}

def check_if_node_break() {
  def grep_info = 'node break'
  def check_node = UTIL.run_cmd_get_stdout("""
    if [[ -f "${log_dir}/version" ]] && ! ls ${log_dir}/*/failed_flag &>/dev/null \
        && ! ls ${log_dir}/failed_flag &>/dev/null; then
      echo "${grep_info}"
    fi
  """, true)
  echo check_node
  if (check_node.contains(grep_info)) {
    def notify_dict = ["Reason": "Test machine might lose connections or jenkins pipeline was canceled",
        "Comment": "You can ask QA team for help"]
    UTIL.notification(PARAM, 'FAIL', USER_NAME, hipchat_test_room, notify_dict)
  }
}

def test_on_vm(os, unit_tests, integration_tests, test_id) {
  // running on the machine(s), default value is 'MIT'
  return {
    stage("parallel testing in ${os}") {
      def machine_name = "${CONFIG['labelPrefix']['test']}_${os}"
      if (JOB_ID == 'HOURLY') {
        machine_name = "${CONFIG['labelPrefix']['hourly']}_${os}"
        // check the number of available ${CONFIG['labelPrefix']['hourly']}_${os} machines
        def avail_vm_num = UTIL.run_cmd_get_stdout("""
          bash "${openNebula_dir}/getSlaveNumber.sh" "${log_dir}" "value" "${machine_name}" || true
        """)
        // if no macine are available, use MIT machines(${CONFIG['labelPrefix']['test']}_${os})
        if (!avail_vm_num.isInteger() || avail_vm_num.toInteger() == 0) {
          machine_name = "${CONFIG['labelPrefix']['test']}_${os}"
        }
      }
      if (MACHINE != 'MIT') {
        machine_name = "${MACHINE}_${os}"
      }
      echo "unittests: ${unit_tests}"
      echo "integration tests: ${integration_tests}"
      def test_by_tag_tmp = "none"
      if (params.test_by_tag != null && params.test_by_tag.trim() != "none") {
        test_by_tag_tmp = params.test_by_tag
      }
      build job: 'parallel_test_pipeline', parameters: [
        [$class: 'StringParameterValue', name: 'PARAM', value: PARAM],
        [$class: 'StringParameterValue', name: 'USER_NAME', value: USER_NAME],
        [$class: 'StringParameterValue', name: 'MACHINE', value: machine_name],
        [$class: 'StringParameterValue', name: 'BASE_BRANCH', value: BASE_BRANCH],
        [$class: 'StringParameterValue', name: 'BIGTEST_BASE_BRANCH', value: BIGTEST_BASE_BRANCH],
        [$class: 'StringParameterValue', name: 'UNITTESTS', value: unit_tests],
        [$class: 'StringParameterValue', name: 'INTEGRATION', value: integration_tests],
        [$class: 'StringParameterValue', name: 'JOB_ID', value: JOB_ID],
        [$class: 'StringParameterValue', name: 'JOB_NAME', value: JOB_NAME],
        [$class: 'StringParameterValue', name: 'BUILD_NUMBER', value: "${BUILD_NUMBER}"],
        [$class: 'StringParameterValue', name: 'OS', value: os],
        [$class: 'StringParameterValue', name: 'SKIP_BUILD', value: SKIP_BUILD],
        [$class: 'StringParameterValue', name: 'PARALLEL_INDEX', value: test_id],
        [$class: 'StringParameterValue', name: 'PROJECT_VERSION', value: PROJECT_VERSION],
        [$class: 'StringParameterValue', name: 'NO_FAIL', value: NO_FAIL],
        [$class: 'StringParameterValue', name: 'DEBUG_UT', value: DEBUG_UT],
        [$class: 'StringParameterValue', name: 'SANITIZER', value: SANITIZER],
        [$class: 'BooleanParameterValue', name: 'skip_bc_test', value: params.skip_bc_test],
        [$class: 'StringParameterValue', name: 'test_by_tag', value: test_by_tag_tmp],
        [$class: 'StringParameterValue', name: 'CLUSTER_TYPE', value: CLUSTER_TYPE]
      ]
    }
  }
}

def build_on_vm() {
  // running on the machine(s), default value is 'MIT'
  def os = "centos6"
  def build_machine = "${CONFIG['labelPrefix']['build']}_${os}"
  def test_by_tag_tmp = "none"
  if (params.test_by_tag != null && params.test_by_tag.trim() != "none") {
    test_by_tag_tmp = params.test_by_tag
  }
  stage("build in ${build_machine}") {
    if (SKIP_BUILD == "false") {
      build job: 'build_pkg_pipeline', parameters: [
        [$class: 'StringParameterValue', name: 'PARAM', value: PARAM],
        [$class: 'StringParameterValue', name: 'USER_NAME', value: USER_NAME],
        [$class: 'StringParameterValue', name: 'OS', value: os],
        [$class: 'StringParameterValue', name: 'MACHINE', value: build_machine],
        [$class: 'StringParameterValue', name: 'BASE_BRANCH', value: BASE_BRANCH],
        [$class: 'StringParameterValue', name: 'BIGTEST_BASE_BRANCH', value: BIGTEST_BASE_BRANCH],
        [$class: 'StringParameterValue', name: 'JOB_ID', value: JOB_ID],
        [$class: 'StringParameterValue', name: 'JOB_NAME', value: JOB_NAME],
        [$class: 'StringParameterValue', name: 'BUILD_NUMBER', value: "${BUILD_NUMBER}"],
        [$class: 'StringParameterValue', name: 'PROJECT_VERSION', value: PROJECT_VERSION],
        [$class: 'StringParameterValue', name: 'NO_FAIL', value: NO_FAIL],
        [$class: 'StringParameterValue', name: 'DEBUG_UT', value: DEBUG_UT],
        [$class: 'StringParameterValue', name: 'SANITIZER', value: SANITIZER],
        [$class: 'StringParameterValue', name: 'test_by_tag', value: test_by_tag_tmp]
      ]
    }
  }
}

def stage_parallel_testing() {
  try {

    def pull_req_arr = [];
    for (def pull_req : PARAM.tokenize(';')) {
      def repo = pull_req.tokenize('#')[0], num = pull_req.tokenize('#')[1];
      pull_req_arr.add([
        "to_id": repo,
        "pullreq": Integer.parseInt(num)
      ])
    }
    def data = ["job_id": BUILD_NUMBER, "job_type": JOB_ID.toLowerCase(), "status": "RUNNING",
        "start_t": new Date().format("yyyy-MM-dd HH:mm:ss"), "force": FORCE, "pullreq": PARAM,
        "unittests": UNITTESTS, "integrations": INTEGRATION, "base_branch": BASE_BRANCH,
        "bigtest_base_branch": BIGTEST_BASE_BRANCH, "skip_build": SKIP_BUILD,
        "log_dir": log_dir, "edge_infos": [:]]
    data['edge_infos']["user"] = ["edge_name": "user_request_info", "edge_data": [["to_id": USER_NAME]]]
    data['edge_infos']["repo"] = [
      "edge_name": "repo_request_info",
      "edge_data": pull_req_arr
    ]
    UTIL.sendToServer("/${JOB_ID.toLowerCase()}/withEdge", 'POST', data)

    // parallel testing start
    UTIL.notification(PARAM, 'START', USER_NAME, hipchat_test_room, [:])
    def total_vm_num = 4, total_os_num = 4, unittest_group = [], integration_group = []
    def to_run_UNITTESTS = "", to_run_INTEGRATION = ""
    def parallel_build = [:]

    to_run_UNITTESTS = UTIL.run_cmd_get_stdout("""
      python "${unittest_folder}/get_unittests.py" "${unittest_folder}/unittests_dependency.json" \
          "${PARAM}" "${UNITTESTS}" "${JOB_ID}" "${CONFIG['all_unittests']}"
    """)
    if (params.test_by_tag != null && params.test_by_tag.trim() != "none" && UNITTESTS == "default") {
      to_run_UNITTESTS = CONFIG['all_unittests']
    }

    lock('end2end_git') {
      to_run_INTEGRATION = UTIL.run_cmd_get_stdout("""
        bash "${integration_folder}/get_integrations.sh" "${INTEGRATION}" "${UTIL.get_branch_name('gle')}" \
            &> ${log_dir}/bigtest_log/get_integrations.log
        str=\$(grep "all integrations tests: " ${log_dir}/bigtest_log/get_integrations.log)
        echo \${str##*all integrations tests: }
      """, true)
    }

    if (JOB_ID != 'HOURLY') {
      def avail_vm_num = UTIL.run_cmd_get_stdout("""
        bash "${openNebula_dir}/getSlaveNumber.sh" "${log_dir}" "value" "${CONFIG['labelPrefix']['test']}" || true
      """)
      echo "available vm number is: ${avail_vm_num}"
      if (avail_vm_num.isInteger()) {
        if (NUM_MACHINE != "default" && NUM_MACHINE.isInteger() && NUM_MACHINE.toInteger() <= avail_vm_num.toInteger()) {
          total_vm_num = NUM_MACHINE.toInteger()
        } else if (avail_vm_num.toInteger() >= 32) {
          total_vm_num = 8
        }
      }
      echo "vm number for usage is: ${total_vm_num}"
      def unittest_res = UTIL.run_cmd_get_stdout("""
        python "${unittest_folder}/group_unittest.py" "${timecost_config_folder}/unittest_timecost.json" \
            ${total_vm_num} "${to_run_UNITTESTS}" "${log_dir}/bigtest_log/group_unittest.log"
      """)
      unittest_group = UTIL.remove_total(unittest_res)
      integration_group = UTIL.remove_total(UTIL.run_cmd_get_stdout("""
        python "${integration_folder}/group_integration.py" "${timecost_config_folder}/integration_timecost.json" \
            ${total_vm_num} "${unittest_res}" "${to_run_INTEGRATION}" "${log_dir}/bigtest_log/group_integrations.log"
      """))
    } else {
      for (def i = 0; i < total_vm_num; i++) {
        unittest_group.push(to_run_UNITTESTS)
        integration_group.push(to_run_INTEGRATION)
      }
    }
    println "unittest group: " + unittest_group
    println "integration group: " + integration_group
    parallel_build['failFast'] = (Integer.parseInt(NO_FAIL) == 0)

    def real_vm_num = total_vm_num
    // it is distributed cluster rather than single server
    if (params.CLUSTER_TYPE == "cluster") {
      real_vm_num = total_vm_num * cluster_nodes_num
    }
    UTIL.sendToServer("/${JOB_ID.toLowerCase()}/${BUILD_NUMBER}", 'PUT', ["num_of_nodes": real_vm_num])

    // build stage
    build_on_vm()

    // parallel test stage
    def parallel_test = [:]
    parallel_test['failFast'] = (Integer.parseInt(NO_FAIL) == 0)
    for (def index = 0; index < unittest_group.size(); index++) {
      def this_os = build_os_dict[index % build_os_dict.size()]
      def this_ut = unittest_group[index]
      if (this_os == 'centos6' && this_ut.contains("vis")) {
        def next_index = index + 1
        // if the next one is out of bound, swap with the first one
        if (next_index >= unittest_group.size()) {
          next_index = 0
        }
        // can not swap with itself
        if (JOB_ID != 'HOURLY' && next_index != index) {
          unittest_group.swap(index, next_index)
          // integration group also need to be swaped, otherwise distribution uneven
          integration_group.swap(index, next_index)
        } else {
          unittest_group[index] = this_ut.minus("vis")
        }
      }
    }
    for (def index = 0; index < unittest_group.size(); index++) {
      def this_os = build_os_dict[index % build_os_dict.size()]
      def this_ut = unittest_group[index]
      def test_id = this_os + " : " + index;
      parallel_test[test_id] = test_on_vm(this_os,
          unittest_group[index], integration_group[index], test_id)
    }
    parallel parallel_test

    // back to master machine
  } catch (err) {
    echo "parallel test failed"
    // if job is hourly_qualification_certification, create a QA ticket
    if (JOB_ID == 'HOURLY') {
      def ticket_info = "[QA-HQC] Test failure. Blocking issue. Build number #${BUILD_NUMBER}"
      def msg = "Check detail information at jenkins: ${jenkins_address}/job/${JOB_NAME}/${BUILD_NUMBER}"
      def result = UTIL.run_cmd_get_stdout("""python "${python_script_dir}/issue_manager.py" """ +
          """create "${CONFIG['qa_stable_tag']}" QA "${ticket_info}" "${VERSION_FILE}" Bug QA_HOURLY_FAILURE Kaiyuan.liu "${msg}" """)
      echo result
    }
    throw err
  }
}

return this
