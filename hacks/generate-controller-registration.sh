# Copyright 2022 Intel Corporation. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

chart="$(tar -C charts -c gardener-extension-cri-resmgr | gzip -n | base64 | tr -d '\n')"
OUT=examples/ctrldeploy-ctrlreg.yaml

#FOR DEBUG
#rm -rf /tmp/extract_dir && mkdir -p /tmp/extract_dir/ ; echo $chart | base64 -d  | gunzip | tar -xv -C /tmp/extract_dir && find /tmp/extract_dir

cat <<EOT > "$OUT"
# This file is generated by hacks/generate-controller-registration.sh - Do not commit, but change generation script!
---
apiVersion: core.gardener.cloud/v1beta1
kind: ControllerDeployment
metadata:
  name: cri-resmgr-extension
type: helm
providerConfig:
  chart: $chart

  values:
    ### For development purposes - set it to 0 (if you want to register extension but use local process with "make start").
    # replicaCount: 1            

    ### Uncomment this is you want to overwrite extension image or internal installation and agent images.
    ### Remember to build and push image  "make REGISTRY=v2.isvimgreg.com TAG=mybranch build-images push-images"
    ### "image" overwrites extension (for seed) and "images" overwrite installation/agent (for shoot) images defined in charts/images.yaml
    #image:
    #  repository: v2.isvimgreg.com/gardener-extension-cri-resmgr
    #  tag: mybranch
    #  pullPolicy: Always
    #imageVectorOverwrite: |
    #  images:
    #  - name: gardener-extension-cri-resmgr-installation
    #    tag: mybranch
    #    repository: v2.isvimgreg.com/gardener-extension-cri-resmgr-installation
    #  - name: gardener-extension-cri-resmgr-agent
    #    tag: mybranch
    #    repository: v2.isvimgreg.com/gardener-extension-cri-resmgr-agent
    ### Uncomment to provide own "fallback" configuration for CRI-Resource-Manager
    ### Use ballons policy as an example:
    # based on: https://github.com/intel/cri-resource-manager/blob/master/sample-configs/balloons-policy.cfg
    configs:
      fallback: |
        policy:
          Active: balloons
      default: |
        policy:
          Active: balloons
          AvailableResources:
            CPU: cpuset:1-15
          ReservedResources:
            CPU: cpuset:15
          balloons:
            PinCPU: true
            PinMemory: true
            IdleCPUClass: idle
            BalloonTypes:
              - Name: "full-core-turbo"
                MinCPUs: 2
                CPUClass: "turbo"
                MinBalloons: 2
        logger:
          Debug: resource-manager,cache,policy,resource-control,config-server
          Klog:
            # Enables nice logs with logger names that can be used in Debug
            skip_headers: true
        dump:
          Config: off:.*,full:((Create)|(Remove)|(Run)|(Update)|(Start)|(Stop)).*

    ### Example of how to use default
    #   fallback: |
    #     ### This is default policy from CRI-resource-manage fallback.cfg.sample
    #     policy:
    #       Active: topology-aware
    #       ReservedResources:
    #         CPU: 750m
    #     logger:
    #       Debug: resource-manager,cache,policy,resource-control
    #       Klog:
    #         # Enables nice logs with logger names that can be used in Debug
    #         skip_headers: true
    #     dump:
    #       Config: off:.*,full:((Create)|(Remove)|(Run)|(Update)|(Start)|(Stop)).*
---
apiVersion: core.gardener.cloud/v1beta1
kind: ControllerRegistration
metadata:
  name: cri-resmgr-extension
spec:
  deployment:
    # For development purpose - deploy the extensions before even shoots are created (or enabled)
    #policy: Always
    deploymentRefs:
    - name: cri-resmgr-extension
  resources:
  - kind: Extension
    type: cri-resmgr-extension
    globallyEnabled: false
    reconcileTimeout: "60s"
EOT

echo "Successfully generated ControllerRegistration and ControllerDeployment example to $OUT"
