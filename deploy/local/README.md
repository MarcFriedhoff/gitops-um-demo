# Local deployment of Universal Messaging Server

Run Universal Messaging Server in a Docker container locally and automatically create a new JMS channel named: "test".

```shell
docker run --privileged -e REALM_NAME=umtest -e INIT_JAVA_MEM_SIZE=2048 -e MAX_JAVA_MEM_SIZE=2048 -e MAX_DIRECT_MEM_SIZE=3G \
-e STARTUP_COMMAND="runUMTool.sh CreateChannel -channelname=test -rname=nsp://localhost:9000"  \
-v $(pwd)/licence.xml:/opt/softwareag/UniversalMessaging/server/umserver/license/license.xml:Z \
-v $(pwd)/umserver/data:/opt/softwareag/UniversalMessaging/server/umserver/data:Z \
-v $(pwd)/umserver/logs:/opt/softwareag/UniversalMessaging/server/umserver/logs:Z \
-v $(pwd)/umserver/conf:/opt/softwareag/UniversalMessaging/server/umserver/conf:Z \
-p 9000:9000 -p 9200:9200 --name umservercontainer sagcr.azurecr.io/universalmessaging-server:10.15
```
--> STARTUP_COMMAND="runUMTool.sh CreateChannel -channelname=test -rname=nsp://localhost:9000" will create a new JMS channel named "test".

Or via podman kube-playground:

```shell
podman kube play kube-play.yaml
```

Determine the pod name:
```shell
podman ps
```

Example Output: 
```shell
CONTAINER ID  IMAGE                                             COMMAND     CREATED         STATUS                   PORTS                                           NAMES
e28a6aa8ea6a  localhost/podman-pause:5.0.3-1715299200                       47 minutes ago  Up 47 minutes            0.0.0.0:9000->9000/tcp, 0.0.0.0:9200->9200/tcp  d808ef251a25-infra
1a9bb3a7c434  sagcr.azurecr.io/universalmessaging-server:10.15              47 minutes ago  Up 47 minutes (healthy)  0.0.0.0:9000->9000/tcp, 0.0.0.0:9200->9200/tcp  umservercontainer-pod-umservercontainer
```
--> The pod name is: umservercontainer-pod-umservercontainer

## Create a new JMS Channel using UMTool
```shell
docker exec umservercontainer-pod-umservercontainer runUMTool.sh "CreateChannel -channelname=jms-channel -rname=nsp://localhost:9000"
```

## Export Realm configuration
```shell
docker exec -it umservercontainer-pod-umservercontainer runUMTool.sh ExportRealmXML -rname=nsp://localhost:9000 -filename=/opt/softwareag/UniversalMessaging/server/umserver/conf/realmall.xml -exportall=true
```

## Channels configuration
```shell
docker exec -it umservercontainer-pod-umservercontainer runUMTool.sh ExportRealmXML -rname=nsp://localhost:9000 -filename=/opt/softwareag/UniversalMessaging/server/umserver/conf/channels.xml -channelsall=true
```

## Import Channels configuration locally
```shell
docker exec -it umservercontainer-pod-umservercontainer runUMTool.sh ImportRealmXML -rname=nsp://localhost:9000 -filename=/opt/softwareag/UniversalMessaging/server/umserver/conf/newchannels.xml -channels=true
```

# Kubernetes Deployment

For assets such as Channels / Queues, use MSR deployment as the "owner" of the assets to deploy them to the UM server.

## Import Realm configuration with MSR helm

### Create a ConfigMap with the realm configuration via values.yaml
```shell
extraConfigMaps:
  name: msr-um-realm-config
    data: 
      channels.xml: |
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <NirvanaRealm name="umtest" exportDate="2024-06-28Z" comment="Realm configuration from umtest" version="10.15" buildInfo="10.15.0.18.1045">
            <ChannelSet>
                <ChannelEntry>
                    <ChannelAttributesEntry name="newchannel" TTL="0" capacity="0" EID="0" jmsEngine="false" mergeEngine="false" type="MIXED_TYPE"/>
                    <StorePropertiesEntry HonorCapacityWhenFull="true" SyncOnEachWrite="false" SyncMaxBatchSize="0" SyncBatchTime="0" PerformAutomaticMaintenance="true" EnableCaching="true" CacheOnReload="true" Priority="4" EnableMulticast="false" MultiFileEventsPerSpindle="50000" StampDictionary="0"/>
                    <ChannelPermissionSet>
                        <ChannelACLEntry listACLEntries="true" modifyACLEntries="true" fullControl="true" getLastEID="true" purgeEvents="true" subscribe="true" publish="true" useNamedSubcription="true" host="localhost" name="sagadmin"/>
                        <ChannelGroupACLEntry listACLEntries="false" modifyACLEntries="false" fullControl="false" getLastEID="true" purgeEvents="false" subscribe="true" publish="false" useNamedSubcription="true" groupname="Everyone"/>
                    </ChannelPermissionSet>
                </ChannelEntry>
            </ChannelSet>
        </NirvanaRealm>
```


### Define a job in the values.yaml file:

see: https://github.com/SoftwareAG/webmethods-helm-charts/tree/main/microservicesruntime/examples/msr-post-init

```shell
jobs:
- name: deploy-assets-to-um
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-weight": "0"
    "helm.sh/hook-delete-policy": hook-succeeded
  image:
    repository: sagcr.azurecr.io/universalmessaging-tools
    tag: 10.15
  imagePullPolicy: IfNotPresent
  restartPolicy: Never
  env:
    # -- Environment variable for Shell script
    - name:  UM_HOST
      # -- Set UM Realm deployment (=hostname)
      value: wm-realm-um
  command: ["/bin/bash"]
  # -- Shell script to deploy / create assets in UM using runUMTool.sh
  args:
    - -c
    - >-
        echo Deploying Assets in UM [$UM_HOST] ...;
        runUMTool.sh CreateConnectionFactory -rname=nsp://$UM_HOST:9000 -factoryname=local_um -factorytype=default -connectionurl=nsp://$UM_HOST:9000 -durabletype=S
  volumeMounts:
    - name: msr-um-realm-config
      mountPath: /mnt/um-realm-config
      readOnly: true
  volumes: 
    - name: msr-um-realm-config
      configMap:
        name: msr-um-realm-config
```