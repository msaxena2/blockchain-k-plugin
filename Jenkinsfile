pipeline {
  agent {
    dockerfile {
      label 'docker'
      additionalBuildArgs '--build-arg K_COMMIT=$(cat deps/k_release)'
    }
  }
  options {
    ansiColor('xterm')
  }
  stages {
    stage("Init title") {
      when { changeRequest() }
      steps {
        script {
          currentBuild.displayName = "PR ${env.CHANGE_ID}: ${env.CHANGE_TITLE}"
        }
      }
    }
    stage("Test compilation") {
      when { changeRequest() }
      steps {
        dir ('deps/libff') {
          checkout([$class: 'GitSCM',
          branches: [[name: '*/master']],
          extensions: [[$class: 'SubmoduleOption',
                        disableSubmodules: false,
                        parentCredentials: false,
                        recursiveSubmodules: true,
                        reference: '',
                        trackingSubmodules: false]], 
          userRemoteConfigs: [[url: 'git@github.com:scipr-lab/libff.git']]])
          sh '''
            mkdir build
            cd build
            cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=../../../install
            make -j16
            make install
          '''
        }
        dir ('deps/cryptopp') {
          checkout([$class: 'GitSCM',
          branches: [[name: 'refs/tags/CRYPTOPP_8_2_0']],
          extensions: [[$class: 'SubmoduleOption',
                        disableSubmodules: false,
                        parentCredentials: false,
                        recursiveSubmodules: true,
                        reference: '',
                        trackingSubmodules: false]], 
          userRemoteConfigs: [[url: 'git@https://github.com/weidai11/cryptopp.git']]])
          sh '''
            make -j16
	    make install PREFIX=../../install
          '''
        }
        sh 'make -j16 INCLUDE_PATH=install/include LIBRARY_PATH=install/lib'
      }
    stage('Deploy') {
      when { branch 'master' }
      steps {
        build job: 'rv-devops/master', propagate: false, wait: false                                  \
            , parameters: [ booleanParam(name: 'UPDATE_DEPS_SUBMODULE', value: true)                  \
                          , string(name: 'PR_REVIEWER', value: 'ehildenb')                            \
                          , string(name: 'UPDATE_DEPS_REPOSITORY', value: 'kframework/evm-semantics') \
                          , string(name: 'UPDATE_DEPS_SUBMODULE_DIR', value: 'deps/plugin')           \
                          ]
      }
    }
  }
}
