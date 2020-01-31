#!/bin/bash

# Make sure tfc_token environment variable is set
# to owners team token for organization

# Set address if using private Terraform Enterprise server.
# Set organization and workspace to create.
# You should edit these before running.

#tfc_token=<insert your API token here>
#address="<Terraform API>"
#organization="<name of the TFE organisation>"
#workspace="<name of the workspace to be created>"



tfc_token=`cat tfe_team_token`
address="app.terraform.io"
organization="joestack"
workspace="tfc-aws-bastion-host"

########################
# 01) CREATE WORKSPACE #
########################

# Set name of workspace in workspace.json (create a payload.json)
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

echo "Workspace $workspace has been created" && echo

#####################################
# 02) ASSIGN VARIABLES TO WORKSPACE #
#####################################

# Add variables to workspace
while IFS=',' read -r key value category hcl sensitive
do
  sed -e "s/my-organization/$organization/" \
      -e "s/my-workspace/$workspace/" \
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

echo "Variables have been assigned" && echo
