#!/bin/bash

# Make sure tfc_token environment variable is set
# to owners team token for organization

# Set address if using private Terraform Enterprise server.
# Set organization and workspace to create.
# You should edit these before running.

tfc_token=`cat tfe_team_token`
address="app.terraform.io"
organization="joestack"
workspace="tfc-api-code-deployment"

########################
# 01) CREATE WORKSPACE #
########################

#Set name of workspace in workspace.json (create a payload.json)
sed -e "s/placeholder/$workspace/" < workspace.template.json > workspace.json

# Create workspace 
workspace_result=$(
  curl -Ss \
       --header "Authorization: Bearer $tfc_token" \
       --header "Content-Type: application/vnd.api+json" \
       --request POST \
	     --data @workspace.json \
       "https://${address}/api/v2/organizations/${organization}/workspaces"
)

workspace_id=$(
  echo $workspace_result | jq -r ".data | select (.attributes.name == \"$workspace\") | .id "
)

echo "Workspace created. WorkspaceID: $workspace_id" && echo

#####################################
# 02) ASSIGN VARIABLES TO WORKSPACE #
#####################################

# Add variables to workspace
while IFS=',' read -r key value category hcl sensitive
do
  sed -e "s/my-organization/$organization/" \
      -e "s/my-workspace/$workspace_id/" \
      -e "s/my-key/$key/" \
      -e "s/my-value/$value/" \
      -e "s/my-category/$category/" \
      -e "s/my-hcl/$hcl/" \
      -e "s/my-sensitive/$sensitive/" < variable.template.json  > variable.json
  
  echo "Adding variable $key in category $category "
  
  upload_variable_result=$(
    curl -Ss \
         --header "Authorization: Bearer $tfc_token" \
         --header "Content-Type: application/vnd.api+json" \
         --data @variable.json \
         "https://${address}/api/v2/vars?filter%5Borganization%5D%5Bname%5D=${organization}&filter%5Bworkspace%5D%5Bname%5D=${workspace}"
  )
done < variables.csv

####################################
# 03) Create configuration version #
####################################
configuration_version_result=$(
  curl -Ss \
       --header "Authorization: Bearer $tfc_token" \
       --header "Content-Type: application/vnd.api+json" \
       --request POST \
       --data @configversion.json \
       "https://${address}/api/v2/workspaces/${workspace_id}/configuration-versions"
  )

upload_url=$(
  echo $configuration_version_result | jq -r '.data.attributes."upload-url"'
)
configversion_id=$(
  echo $configuration_version_result | jq -r '.data.id'
)

echo "URL: $upload_url"
echo "configversion_id: $configversion_id" && echo

############################
# 04) Upload Configuration #
############################

#build myconfig.tar.gz
create_config=$(
  cd config
  tar -cvf myconfig.tar .
  gzip myconfig.tar
  mv myconfig.tar.gz ../.
  cd ..
)

echo "Config tar.gz created and ready for upload"
echo "imagine this code could also be cloned from a repository"

# Upload configuration
upload_config=$(
  curl -Ss \
       --header "Content-Type: application/octet-stream" \
       --request PUT \
       --data-binary @myconfig.tar.gz \
       "$upload_url"
)

echo "config uploaded..." && echo

##################
# 05) Run a Plan #
##################

sed -e "s/workspace_id/$workspace_id/" \
    -e "s/configversion_id/$configversion_id/" < run-plan.template.json > run-plan.json

run_plan=$(
  curl -Ss \
       --header "Authorization: Bearer $tfc_token" \
       --header "Content-Type: application/vnd.api+json" \
       --request POST \
       --data @run-plan.json \
       "https://${address}/api/v2/runs"
)

run_id=$(
  echo $run_plan | jq -r '.data.id'
)

echo "Run-ID: $run_id" && echo

#######################################################
# 06 & 07) Apply the plan if it is in the right state #
#######################################################

continue=1
while [ $continue -ne 0 ]
do
  # check status 
  check_status=$(
    curl -Ss \
         --header "Authorization: Bearer $tfc_token" \
         --header "Content-Type: application/vnd.api+json" \
         "https://${address}/api/v2/runs/${run_id}" |\
    jq -r '.data.attributes.status'
  )

  if [[ "$check_status" == "cost_estimated" ]] ; then
    continue=0
    # Do the apply
    echo "cost estimated. Doing apply..."
    apply_result=$(
      curl -Ss \
           --header "Authorization: Bearer $tfc_token" \
           --header "Content-Type: application/vnd.api+json" \
           --data @apply.json \
           "https://${address}/api/v2/runs/${run_id}/actions/apply"
    )
  elif [[ "$check_status" == "errored" ]]; then
    echo "Plan errored or hard-mandatory policy failed"
    continue=0
  else
    echo "current status: $check_status"
    sleep 5
  fi
done


