// import groovy library
import groovy.time.*
import groovy.json.*

machineList = [NODE_NAME]

def pre_job() {
  // set up core_dump folder
  sh """
    ln -snf /home/tigergraph/tigergraph/logs/coredump/ /home/tigergraph/tigergraph_coredump || true
    echo /home/tigergraph/tigergraph_coredump/core-%e-%s-%p.%t | sudo tee /proc/sys/kernel/core_pattern || true
    if ! ps aux | grep bash | grep period_check.sh; then
      bash ${slave_script_dir}/period_check.sh &
    fi
  """
  env.NO_COLLECTION = 'false'
  env.NO_FAIL = NO_FAIL
  def data = ["job_id": BUILD_NUMBER_SELF, "status": "RUNNING",
      "start_t": new Date().format("yyyy-MM-dd HH:mm:ss"),
      "os": OS, "log_dir": log_dir, "edge_infos": [:]]
  def edge_name_prefix = ""
  if (JOB_ID_SELF == 'test_job') {
    if (params.CLUSTER_TYPE == "cluster") {
      //For cluster, try to get all machines
      def times_max = 24 * 12, interval = 5, counter = 0
      while (counter < times_max) {
        lock('end2end_get_slave') {
          def machineListStr = UTIL.run_cmd_get_stdout("""
                bash "${openNebula_dir}/getSlaveNumber.sh" "${log_dir}" "list" "${MACHINE}" || true
          """)
          machineList += machineListStr.tokenize(",")
          while (machineList.size() > cluster_nodes_num) {
            machineList.pop();
          }
          if (machineList.size() == cluster_nodes_num) {
            println machineList
            currentBuild.description += " slaves:"

            // take the cluster offline
            for (def machine in machineList) {
              if (machine != NODE_NAME) {
                currentBuild.description += " ${machine}"
              }
              UTIL.sendToServer("/nodes/${machine}/takeOffline", 'PUT', ["log_dir": log_dir
                  , "offline_message": "${USER_NAME} ${JOB_NAME}#${BUILD_NUMBER} " +
                  "${JOB_NAME_SELF}#${BUILD_NUMBER_SELF} ${PARAM} Running Cluster Slave"])
            }
          }
        }
        if (machineList.size() < cluster_nodes_num) {
          echo "Machine used up, times: ${counter}, will sleep ${interval} minutes, then re-retry ..."
          sleep interval * 60
        } else {
          break
        }
        ++counter
      }
      if (counter == times_max) {
        def stage_err = "Timeout due to Out of machines after 24 hours."
        UTIL.notification('', 'FAIL', USER_NAME, hipchat_test_room, ["Reason": stage_err])
        echo stage_err
        error(stage_err)
      }

      UTIL.clusterConfigGen(machineList, clusterConfig, "${log_dir}/install_config.json");
    } else {
      //For single server
      UTIL.clusterConfigGen(["127.0.0.1"], singleConfig, "${log_dir}/install_config.json");
    }

    //clear the env & reinstall IUM
    UTIL.run_bash("bash ${distribute_mit_dir}/uninstall_platform.sh ${log_dir}/install_config.json &> ${log_dir}/bigtest_log/uninstall.log")
    UTIL.run_bash("bash ${shell_script_dir}/install_ium.sh ${PROJECT_VERSION} ${UTIL.get_branch_name('gium')} &> ${log_dir}/bigtest_log/install_ium.log")

    //allocate test cases
    data['unittests'] = UNITTESTS
    data['integrations'] = INTEGRATION
    edge_name_prefix = "test"
  } else {
    edge_name_prefix = "build"
  }
  check_disk_usage()

  def machine_id_arr = []
  for (def machine in machineList) {
    machine_id_arr.add(["to_id": machine])
  }
  data['edge_infos']['slave_node'] = [
    "edge_name": "${edge_name_prefix}_node_info",
    "edge_data": machine_id_arr
  ]
  data['edge_infos']['mwh_request'] = [
    "edge_name": "mwh_${edge_name_prefix}_info",
    "edge_data": [["to_id": "${JOB_ID.toLowerCase()}${BUILD_NUMBER}"]]
  ]
  UTIL.sendToServer("/${JOB_ID_SELF.toLowerCase()}/withEdge", 'POST', data)
}


def job_success(start_t) {
  // take online once the job succeed
  if (JOB_ID_SELF == "test_job") {
    for (def machine in machineList) {
      UTIL.sendToServer("/nodes/${machine}/takeOnline", 'PUT', ["log_dir": log_dir])
    }
  }
  def data = ["status": "SUCCESS", "end_t": new Date().format("yyyy-MM-dd HH:mm:ss"),
      "timecost": TimeCategory.minus(new Date(), start_t).toString()]
  UTIL.sendToServer("/${JOB_ID_SELF.toLowerCase()}/${BUILD_NUMBER_SELF}", 'PUT', data)
  UTIL.check_log_url()
}

def job_failed(err) {
  echo "${err}"
  if (UTIL.check_if_aborted() == false) {
    def machine_ip_list = "";
    for (def machine in machineList) {
      machine_ip_list += "${machine.tokenize('_')[-2]} ${machine.tokenize('_')[-1]}; "
    }
    def notify_dict = ["Reason": "${err.getMessage()}", "Machine":
        machine_ip_list + "(${CONFIG['MASTER_MACHINE_USERNAME_PWD']})"
        , "Log": "<a href=\"${log_url}\">Check all logs</a>"]
    if (JOB_ID_SELF == "test_job") {
      // update offline info for failure
      for (def machine in machineList) {
        UTIL.sendToServer("/nodes/${machine}/takeOffline", 'PUT', ["log_dir": log_dir
            , "offline_message": "${USER_NAME} ${JOB_NAME}#${BUILD_NUMBER} " +
            "${JOB_NAME_SELF}#${BUILD_NUMBER_SELF} ${PARAM} ${UNITTESTS} Cluster Debugging"])
      }

      notify_dict["Comment"] = "The cluster is taken offline for you to debug. You can click " +
          "<a href='http://${CONFIG['rest_server_address']}/api/test_job/${BUILD_NUMBER_SELF}/reclaim?user=${USER_NAME}'>here</a>" +
          " to return the cluster(take it online) immediately"
      notify_dict["Reason"] += " ${UTIL.print_err_summary()}"
    } else {
      notify_dict["Comment"] = "This is build job"
    }
    UTIL.notification(PARAM, 'FAIL', USER_NAME, hipchat_test_room, notify_dict)

    def cur_t = new Date().format("yyyy-MM-dd HH:mm:ss"), end_debug_t = new Date().toCalendar()
    end_debug_t.add(Calendar.HOUR_OF_DAY, CONFIG['default_debug_time'])
    end_debug_t = end_debug_t.getTime().format("yyyy-MM-dd HH:mm:ss")
    def data = ["status": "FAILURE", "end_t": cur_t, "message": err.getMessage()]
    if (JOB_ID_SELF == "test_job") {
      data["message"] += " ${UTIL.print_err_summary()}"
      data["debugger"] = USER_NAME
      data["debug_start"] = cur_t
      data["debug_end"] = end_debug_t
      data["debug_status"] = true
    }
    UTIL.sendToServer("/${JOB_ID_SELF.toLowerCase()}/${BUILD_NUMBER_SELF}", 'PUT', data)
    check_disk_usage()
  }
  UTIL.check_log_url()
  currentBuild.result = 'FAILURE'
}

def stage_gworkspace() {
  def stage_name = 'Gworkspace'
  stage (stage_name) {
    // gle auto build for gle feature branch before gworkspace
    //    to make sure the gle auto build is done
    if (JOB_ID_SELF == 'build_job') {
      try {
        echo 'GLE auto build before gworkspace and build binary'
        UTIL.auto_build(UTIL.get_branch_name('gle'), UTIL.get_branch_name('glelib'),
            UTIL.get_branch_name('utility'), UTIL.get_branch_name('third_party'),
            UTIL.get_branch_name('document'))
      } catch (err) {
        def auto_build_err = "GLE auto build failed before gworkspace build binary"
        echo auto_build_err
        println err
        UTIL.notification('', 'FAIL', USER_NAME, hipchat_test_room, ["Reason": auto_build_err])
        error(auto_build_err)
      }
    }
    lock("end2end_gworkspace_${JOB_NAME}#${BUILD_NUMBER}") {
      // set timeout 20 minutes
      timeout(time: 20, unit: 'MINUTES') {
        echo "${stage_name} starts"
        // if test_by_tag is specified, pass it to gworkspace script
        def test_by_tag = params.test_by_tag
        if (test_by_tag == null || test_by_tag.trim() == "none") {
          test_by_tag = ""
        }
        def result = UTIL.run_cmd_get_stderr("""python "${python_script_dir}/gworkspace.py" """ +
            """ "${log_dir}" "${BASE_BRANCH}" "${BIGTEST_BASE_BRANCH}" "${PARAM}" """ +
            """ "${VERSION_FILE}" "${mark_tag_name}" "${test_by_tag}" """)
        if (result != "") {
          def stage_err = "${stage_name} failed"
          echo stage_err
          echo result
          error(stage_err)
        }
      }
    }
  } // stage end
}

def stage_build() {
  def stage_name = 'Build Binary'
  stage (stage_name) {
    // set timeout 1 hour
    timeout(time: 80, unit: 'MINUTES') {
      try {
        echo "${stage_name} starts"
        UTIL.run_bash """
          # add sanitizer option in scons compile when build cpkg
          if [ "${SANITIZER}" != "none" -a "${SANITIZER}" != "NONE" ]; then
            bash ${shell_script_dir}/add_sanitizer_option.sh ${product_dir} \
                &>${log_dir}/add_sanitizer_option.log
          fi
          # change gsql.jar to make gsql version be a number instead of branch name
          bash ${shell_script_dir}/change_gsql_jar.sh  &> ${log_dir}/change_gsql_jar.log
          cd ${product_dir} && ./cpkg.sh -jn -i ${mark_tag_name} &> ${log_dir}/cpkg.log
          cp -f ${product_dir}/tigergraph.bin ${log_dir}/${MACHINE}_tigergraph.bin
        """
      } catch (err) {
        echo "${err}"
        def stage_err = "${stage_name} failed"
        echo stage_err
        error(stage_err)
      }
    }
  } // stage end
}


def stage_install() {
  def stage_name = 'Binary Installation'
  stage (stage_name) {
    // set timeout 1 hour
    timeout(time: 40, unit: 'MINUTES') {
      try {
        echo "${stage_name} starts"
        def build_label = "${CONFIG['labelPrefix']['build']}_centos6"
        echo build_label
        if (SKIP_BUILD != "false") {
          UTIL.run_bash """
            mkdir -p ${log_dir}/../${build_label}_copy_from_${SKIP_BUILD}
            cp -pf ${log_dir}/../../${SKIP_BUILD}/${build_label}*/*tigergraph.bin \
                ${product_dir}/tigergraph.bin
          """
        } else {
          UTIL.run_bash "cp -f ${log_dir}/../${build_label}*/*tigergraph.bin ${product_dir}/tigergraph.bin"
        }
        UTIL.run_bash("bash ${distribute_mit_dir}/setup_cluster_config.sh ${log_dir}/install_config.json &> ${log_dir}/bigtest_log/setup_cluster.log")
        UTIL.run_bash("cd ${product_dir} && " +
            " bash ${shell_script_dir}/install_pkg.sh &> ${log_dir}/install_pkg.log")
      } catch (err) {
        echo "${err}"
        def stage_err = "${stage_name} failed"
        echo stage_err
        error(stage_err)
      }
    }
  } // stage end
}

def stage_component_test() {
  def stage_name = 'Component unit test'
  stage (stage_name) {
    def timeout_t = 540
    if (JOB_ID == 'HOURLY') {
      timeout_t = 540
    }
    if (SANITIZER != "none") {
      timeout_t = 240
    }
    timeout(time: timeout_t, unit: 'MINUTES') {
      try {
        echo "${stage_name} starts"
        // if UNITTESTS is "none", it still will be passed into unittest_file.
        // because unittest_file will check UNITTESTS value by regular expression.
        def ut_test_opt = ""
        if (1 == 1) {
          if (DEBUG_UT != "none") {
            ut_test_opt += "-db '${DEBUG_UT}'"
          }
          if (SANITIZER != "none") {
            ut_test_opt += "-sanitizer '${SANITIZER}'"
          }
        }
        UTIL.run_bash """
          ${unittest_folder}/run.sh ${log_dir} -b '${mark_tag_name}' -u '${UNITTESTS}' ${ut_test_opt}
        """
      } catch (err) {
        echo "${err}"
        def stage_err = "${stage_name} failed"
        echo stage_err
        error(stage_err)
      }
    }
  } // stage end
}

def stage_integration_test() {
  def stage_name = 'Integration test'
  stage (stage_name) {
    def timeout_t = 540
    if (JOB_ID == 'HOURLY') {
      timeout_t = 500
    }
    if (SANITIZER != "none") {
      timeout_t = 240
    }
    timeout(time: timeout_t, unit: 'MINUTES') {
      try {
        echo "${stage_name} starts"
        def it_opts = ""
        // check if it is hourly and only one test job of hourly need to backup schema
        if (JOB_ID == 'HOURLY' && PARALLEL_INDEX == "ubuntu16 : 0") {
          it_opts += " -h "
        }
        // check if to skip gsql back compatibility test
        if (params.skip_bc_test != null && params.skip_bc_test == true) {
          it_opts += " -skip_bc "
        }
        UTIL.run_bash "${integration_folder}/run.sh ${log_dir} -i '${INTEGRATION}' ${it_opts}"
      } catch (err) {
        echo "${err}"
        def stage_err = "${stage_name} failed"
        echo stage_err
        error(stage_err)
      }
    }
    if (Integer.parseInt(NO_FAIL) >= 2 && fileExists(log_dir + '/really_fail_flag')) {
      UTIL.run_bash """
        rm -rf ${log_dir}/really_fail_flag
        ${shell_script_dir}/collector.sh ${log_dir} &> $log_dir/bigtest_log/collector.log
      """
      error("Tests Failed with no_fail option enabled")
    }
  } // stage end
}

def check_disk_usage() {
  def disk_usage = UTIL.run_cmd_get_stdout("""
    echo \$(df -Ph ~ | tail -1 | awk '{print \$5}' | cut -d'%' -f 1)
  """, true, false)
  echo "Space usage of /home/tigergraph folder is ${disk_usage}"
  if (Integer.parseInt(disk_usage) > 80) {
    echo "Disk usage of /home/tigergraph larger than 80% !!!!!!"
    error("Disk usage of /home/tigergraph larger than 80% !!!!!!")
  }
  disk_usage = UTIL.run_cmd_get_stdout("""
    echo \$(df -Ph /tmp | tail -1 | awk '{print \$5}' | cut -d'%' -f 1)
  """, true, false)
  echo "Space usage of /tmp folder is ${disk_usage}"
  if (Integer.parseInt(disk_usage) > 80) {
    echo "Disk usage of /tmp larger than 80% !!!!!!"
    error("Disk usage of /tmp larger than 80% !!!!!!")
  }
}

return this
