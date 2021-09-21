# Ballerina Container based Performance Tests

This repository contains container based performance tests for Ballerina. The tests are running in an AKS cluster.

[![Daily Build](https://github.com/ballerina-platform/ballerina-performance-cloud/actions/workflows/spawn_cluster.yml/badge.svg)](https://github.com/ballerina-platform/ballerina-performance-cloud/actions/workflows/spawn_cluster.yml)
[![Lang Comparison](https://github.com/ballerina-platform/ballerina-performance-cloud/actions/workflows/lang_comparison.yml/badge.svg)](https://github.com/ballerina-platform/ballerina-performance-cloud/actions/workflows/lang_comparison.yml)
[![db_test_workflow](https://github.com/ballerina-platform/ballerina-performance-cloud/actions/workflows/db_test_workflow.yml/badge.svg)](https://github.com/ballerina-platform/ballerina-performance-cloud/actions/workflows/db_test_workflow.yml)

## Dashboard
[https://ballerina.io/ballerina-performance-cloud/](https://ballerina.io/ballerina-performance-cloud/)

### How to add new tests
1. Create a new Ballerina package in `/tests` folder
   
2. Configure the Cloud.toml to generate Docker and Kubernetes artifacts. 
   Please note that repository name should be `ballerina` to push the image. Sample Cloud.toml should look like below. 
```toml
[container.image]
repository= "ballerina"
name="<ballerina_project_name>" # Docker image name should be same as package name

[cloud.deployment] 
# Resource Allocations Change these according to your scenario needs
# min_memory="256Mi" 
# max_memory="512Mi"
# min_cpu="200m"
# max_cpu="500m"
[cloud.deployment.autoscaling]
# min_replicas=1
# max_replicas=1
```
3. Create a `deployment` folder in `tests/<ballerina_project_name>/deployment`.
   This folder should contain all the extra yamls should be applied to k8s. This will be done using Kustomize. `ingress.yml` is mandatory.
   
4. Create a `scripts` folder in `tests/<ballerina_project_name>/scripts`
   This folder should contain the Jmeter script, and a bash script name `run.sh` to start the jmeter script.
   The `run.sh` will be the entry point to Jmeter vm. Sample `run.sh` will look like below.
```bash
#!/bin/bash 
set -e
source base-scenario.sh

jmeter -n -t "$scriptsDir/"http-post-request.jmx -l "$resultsDir/"original.jtl -Jusers="$concurrent_users" -Jduration=1200 -Jhost=bal.perf.test -Jport=443 -Jprotocol=https -Jpath=passthrough $payload_flags

```

5. Create a CSV file with the same name as the `<ballerina_project_name>` in the summary directory.
   Once the test is executed results will be appended to this csv file.
   Make sure to add the following headers into the csv.
```csv
Label,# Samples,Average,Median,90% Line,95% Line,99% Line,Min,Max,Error %,Throughput,Received KB/sec,Std. Dev.,Date,Payload,Users
```

6. Finally, configure the GitHub Action workflow file in the `.github/workflows/<workflow>.yaml` to trigger the test.
    Sample workflow file:
```yaml
name: h1_h1_passthrough

on:
  workflow_dispatch:
  repository_dispatch:
    types: [ h1_h1_passthrough ]
jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      max-parallel: 1
      matrix:
        payload: [50, 1024]
        users: [60, 200]
    env:
      TEST_NAME: "h1_h1_passthrough"
      TEST_ROOT: "tests"
    steps:
    - uses: actions/checkout@v2
    - name: Login to DockerHub
      uses: docker/login-action@v1
      with:
        username: ${{ secrets.DOCKER_HUB_USERNAME }}
        password: ${{ secrets.DOCKER_HUB_ACCESS_TOKEN }}
    - name: Ballerina Build
      uses: ballerina-platform/ballerina-action@nightly
      env:
        CI_BUILD: true
        WORKING_DIR: tests/h1_h1_passthrough
      with:
        args:
          build
    - name: Docker push
      run: docker push ballerina/${TEST_NAME}:latest
    - name: Copy artifacts
      run: |
        ls -ltr
        cp -a ${TEST_ROOT}/${TEST_NAME}/target/kubernetes/${TEST_NAME}/. ${TEST_ROOT}/${TEST_NAME}/deployment/
    - name: 'Install Kustomize'
      run: |
        curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
    - name: 'Run Kustomize'
      run: |
          kustomize build ${TEST_ROOT}/${TEST_NAME}/deployment > ${TEST_ROOT}/${TEST_NAME}/final.yaml
    - name: Configure AKS
      uses: azure/aks-set-context@v1
      with:
        creds: '${{ secrets.AZURE_CREDENTIALS }}'
        cluster-name: ${{ secrets.CLUSTER_NAME }}
        resource-group: ${{ secrets.CLUSTER_RESOURCE_GROUP }}
    - name: Deploy artifacts
      run: |
        kubectl apply -f ${TEST_ROOT}/${TEST_NAME}/final.yaml
    - name: Login via Az module
      uses: azure/login@v1
      with:
        creds: ${{secrets.AZURE_CREDENTIALS}}
    - name: Write values to outputs
      id: write
      run: |
        echo "::set-output name=cluster-ip::$(kubectl get service nginx-ingress-ingress-nginx-controller --namespace ingress-basic -w  \
                                              -o 'go-template={{with .status.loadBalancer.ingress}}{{range .}}{{.ip}}{{"\n"}}{{end}}{{.err}}{{end}}' 2>/dev/null \
                                              | head -n1)"
        echo "::set-output name=scenario-name::${TEST_NAME}"
        echo "::set-output name=vm-name::bal-perf-vm-`echo ${TEST_NAME} | tr '_' '-'`-${{ matrix.users }}-${{ matrix.payload }}-${{ GITHUB.RUN_NUMBER }}"
        echo "::set-output name=git-token::${{ secrets.BALLERINA_BOT_TOKEN }}"
        echo "::set-output name=space-id::${{ secrets.SPACE_ID }}"
        echo "::set-output name=message-key::${{ secrets.MESSAGE_KEY }}"
        echo "::set-output name=chat-token::${{ secrets.CHAT_TOKEN }}"
        echo "::set-output name=custom-image-name::$(cat image.txt)"
    - name: Create VM Instance
      id: vminstance
      uses: azure/CLI@v1
      with:
        azcliversion: 2.0.72
        inlineScript: |
          az vm create --resource-group "${{ secrets.CLUSTER_RESOURCE_GROUP }}"  --name "${{ steps.write.outputs.vm-name }}"  --admin-username "${{ secrets.VM_USER }}" --admin-password "${{ secrets.VM_PWD }}" --location  eastus \
          --image "mi_${{ steps.write.outputs.custom-image-name }}" --tags benchmark-number=${{ steps.write.outputs.vm-name }} --size Standard_F4s_v2
          echo "::set-output name=ip-address::$(az vm show -d -g "${{ secrets.CLUSTER_RESOURCE_GROUP }}" -n "${{ steps.write.outputs.vm-name }}" --query publicIps -o tsv)"
    - name: Wait for VM instance
      run: sleep 60s
      shell: bash
    - name: Execute performance tests
      uses: appleboy/ssh-action@master
      env: 
        IP: ${{ steps.write.outputs.cluster-ip }}
        SCENARIO_NAME: ${{ steps.write.outputs.scenario-name }}
        GITHUB_TOKEN: ${{steps.write.outputs.git-token}}
        PAYLOAD: ${{ matrix.payload }}
        USERS: ${{ matrix.users }}
      with:
        host: ${{ steps.vminstance.outputs.ip-address }}
        username: ${{ secrets.VM_USER }}
        password: ${{ secrets.VM_PWD }}
        envs: IP,SCENARIO_NAME,GITHUB_TOKEN,PAYLOAD,USERS,SPACE_ID,MESSAGE_KEY,CHAT_TOKEN
        timeout: 300s #5 mins
        command_timeout: '180m' #3 hours
        script: |
          source /etc/profile.d/10-perf-vm.sh
          execute-tests.sh -c $IP -s $SCENARIO_NAME -t $GITHUB_TOKEN -p $PAYLOAD -u $USERS -i $SPACE_ID -m $MESSAGE_KEY -a $CHAT_TOKEN
    - name: Undeploy Kubernetes artifacts
      if: always()
      run: |
        kubectl delete -f ${TEST_ROOT}/${TEST_NAME}/final.yaml
    - name: Cleanup VM
      if: always()
      continue-on-error: true
      uses: azure/CLI@v1
      with:
        azcliversion: 2.0.72
        inlineScript: |
          az resource delete --ids $(az resource list --tag benchmark-number=${{ steps.write.outputs.vm-name }} -otable --query "[].id" -otsv)
          var=`az disk list --query "[?tags.\"benchmark-number\"=='${{ steps.write.outputs.vm-name }}'].id" -otable -otsv`
          if [ -n "$var" ]
          then
              az resource delete --ids ${var}
          else 
              echo "Disk is already deleted"
          fi

``` 

