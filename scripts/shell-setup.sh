#!/bin/bash

# per the following $0 doesn't work reliably when the script is sourced:
# https://stackoverflow.com/questions/35006457/choosing-between-0-and-bash-source.  But 
# in some cases I've found BASH_SOURCE hasn't been set correctly.
declare SCRIPT=$0
if [[ "$SCRIPT" == "/bin/bash" ]]; then
    SCRIPT="${BASH_SOURCE}"
fi

if [[ -z "${SCRIPT}" ]]; then
    echo "BASH_SOURCE: ${BASH_SOURCE}, 0 is: $0"
    echo "Failed to find the running name of the script, you need to set DEMO_HOME manually"
fi

export DEMO_HOME=$( cd "$(dirname "${SCRIPT}")/.." ; pwd -P )
export PROJECT_PREFIX=${1:-k8-win}
export vm_prj="${PROJECT_PREFIX}-vm"
export sup_prj="${PROJECT_PREFIX}-support"

echo "DEMO_HOME set to $DEMO_HOME"
echo "PROJECT_PREFIX is $PROJECT_PREFIX"
echo "vm_prj is $vm_prj"
echo "sup_prj is $sup_prj"

alias cpr='tkn pr cancel $(tkn pr list -o name --limit 1 | cut -f 2 -d "/")'
alias ctr='tkn tr cancel $(tkn tr list -o name --limit 1 | cut -f 2 -d "/")'

# shorthand for creating a pipeline run file and watching the logs
pr () {
    FILE="$1"
    oc create -f $FILE && tkn pr logs -L -f
}

tskr () {
    FILE="$1"
    oc create -f $FILE && tkn tr logs -L -f
}

aws-up() {
    local CLUSTER_NAME=${1:-${CLUSTERNAME}}
    if [[ -z "${CLUSTER_NAME}" ]]; then
        echo "Must provide a cluster name either as parameter or in environment variable `CLUSTERNAME`"
        return 1
    fi

    local AWS_REGION=${REGION}
    if [[ -z "${AWS_REGION}" ]]; then
        echo "Must provide a region by way of REGION environment variable"
        return 1
    fi

    aws ec2 start-instances --instance-ids --region=${AWS_REGION} \
        $(aws ec2 describe-instances --region ${AWS_REGION} --query 'Reservations[*].Instances[*].{Instance:InstanceId}' --output text --filters "Name=tag-key,Values=kubernetes.io/cluster/${CLUSTER_NAME}-*" "Name=instance-state-name,Values=stopped")
}

aws-down() {
    local CLUSTER_NAME=${1:-${CLUSTERNAME}}
    if [[ -z "$CLUSTER_NAME" ]]; then
        echo "Must provide a cluster name either as parameter or in environment variable `CLUSTERNAME`"
        return 1
    fi

    local AWS_REGION=${REGION}
    if [[ -z "${AWS_REGION}" ]]; then
        echo "Must provide a region by way of REGION environment variable"
        return 1
    fi

    aws ec2 stop-instances --instance-ids --region ${AWS_REGION} \
        $(aws ec2 describe-instances --region ${AWS_REGION} --query 'Reservations[*].Instances[*].{Instance:InstanceId}' --output text --filters "Name=tag-key,Values=kubernetes.io/cluster/${CLUSTER_NAME}-*" "Name=instance-state-name,Values=running") 
}

if [[ -f $DEMO_HOME/install/openshift-installer/kustomize/installer-workspace/auth/kubeconfig ]]; then
    echo "Found kubeconfig for created cluster.  Setting KUBECONFIG to point to it"
    export KUBECONFIG=$DEMO_HOME/install/openshift-installer/kustomize/installer-workspace/auth/kubeconfig
fi