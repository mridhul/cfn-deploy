#!/usr/bin/env bash

# Exit on error. Append "|| true" if you expect an error.
set -o errexit  # same as -e
# Exit on error inside any functions or subshells.
set -o errtrace
# Do not allow use of undefined vars. Use ${VAR:-} to use an undefined VAR
set -o nounset
# Catch if the pipe fucntion fails
set -o pipefail

AWS_PROFILE="default"

[[ -z "$AWS_ACCESS_KEY_ID" ]] && echo "AWS_ACCESS_KEY_ID is not SET!"; exit 1
[[ -z "$AWS_SECRET_ACCESS_KEY" ]] && echo "AWS_SECRET_ACCESS_KEY is not SET!"; exit 1
[[ -z "$AWS_REGION" ]] && echo "AWS_REGION is not SET!"; exit 1

aws configure --profile ${AWS_PROFILE} set aws_access_key_id ${AWS_ACCESS_KEY_ID}
aws configure --profile ${AWS_PROFILE} set aws_secret_access_key ${AWS_SECRET_ACCESS_KEY}
aws configure --profile ${AWS_PROFILE} set region ${AWS_REGION}


cfn-deploy(){
    usage="Usage: $(basename "$0") region stack-name [aws-cli-opts]
    where:
    region       - the AWS region
    stack-name   - the stack name
    aws-cli-opts - extra options passed directly to create-stack/update-stack
    "

    if [ "$1" == "-h" ] || [ "$1" == "--help" ] || [ "$1" == "help" ] || [ "$1" == "usage" ] ; then
    echo "$usage"
    exit -1
    fi

    if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] ; then
    echo "$usage"
    exit -1
    fi

    shopt -s failglob
    set -eu -o pipefail

    echo "Checking if stack exists ..."

    if ! aws cloudformation describe-stacks --region $1 --stack-name $2 ; then

    echo -e "\nStack does not exist, creating ..."
    aws cloudformation create-stack \
        --region $1 \
        --stack-name $2 \
        ${@:3}

    echo "Waiting for stack to be created ..."
    aws cloudformation wait stack-create-complete \
        --region $1 \
        --stack-name $2 \

    else

    echo -e "\nStack exists, attempting update ..."

    set +e
    update_output=$( aws cloudformation update-stack \
        --region $1 \
        --stack-name $2 \
        ${@:3}  2>&1)
    status=$?
    set -e

    echo "$update_output"

    if [ $status -ne 0 ] ; then

        # Don't fail for no-op update
        if [[ $update_output == *"ValidationError"* && $update_output == *"No updates"* ]] ; then
        echo -e "\nFinished create/update - no updates to be performed"
        exit 0
        else
        exit $status
        fi

    fi

    echo "Waiting for stack update to complete ..."
    aws cloudformation wait stack-update-complete \
        --region $1 \
        --stack-name $2 \

    fi

    echo "Finished create/update successfully!"
}

cfn-deploy $AWS_REGION $STACK_NAME $TEMPLATE_FILE $PARAMETERS_FILE $CAPABLITIES