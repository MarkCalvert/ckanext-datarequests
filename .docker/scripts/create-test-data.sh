
#!/usr/bin/env sh
##
# Create some example content for extension BDD tests.
#
set -e

CKAN_ACTION_URL=http://ckan:3000/api/action
CKAN_INI_FILE=/app/ckan/default/production.ini

. /app/ckan/default/bin/activate \
    && cd /app/ckan/default/src/ckan

# We know the "admin" sysadmin account exists, so we'll use her API KEY to create further data
API_KEY=$(paster --plugin=ckan user admin -c ${CKAN_INI_FILE} | tr -d '\n' | sed -r 's/^(.*)apikey=(\S*)(.*)/\2/')

# # 
##
# BEGIN: Add sysadmin config values. 
# This needs to be done before closing datarequests as they require the below config values
#
echo "Adding ckan.datarequests.closing_circumstances:"

curl -L -s --header "Authorization: ${API_KEY}" --header "Content-Type: application/json" \
    --data '{"ckan.datarequests.closing_circumstances":"Released as open data|nominate_dataset\nOpen dataset already exists|nominate_dataset\nPartially released|nominate_dataset\nTo be released as open data at a later date|nominate_approximate_date\nData openly available elsewhere\nNot suitable for release as open data\nRequested data not available/cannot be compiled\nRequestor initiated closure"}' \
    ${CKAN_ACTION_URL}/config_option_update

##
# END.
#

##
# BEGIN: Create a test organisation with test users for admin, editor and member
#
TEST_ORG_NAME=test
TEST_ORG_TITLE="Test"

echo "Creating test users for ${TEST_ORG_TITLE} Organisation:"

paster --plugin=ckan user add ckan_user email=ckan_user@localhost password=password -c ${CKAN_INI_FILE}
paster --plugin=ckan user add test_org_admin email=test_org_admin@localhost password=password -c ${CKAN_INI_FILE}
paster --plugin=ckan user add test_org_editor email=test_org_editor@localhost password=password -c ${CKAN_INI_FILE}
paster --plugin=ckan user add test_org_member email=test_org_member@localhost password=password -c ${CKAN_INI_FILE}

echo "Creating ${TEST_ORG_TITLE} Organisation:"

TEST_ORG=$( \
    curl -L -s --header "Authorization: ${API_KEY}" \
    --data "name=${TEST_ORG_NAME}&title=${TEST_ORG_TITLE}" \
    ${CKAN_ACTION_URL}/organization_create
)

TEST_ORG_ID=$(echo $TEST_ORG | sed -r 's/^(.*)"id": "(.*)",(.*)/\2/')

echo "Assigning test users to ${TEST_ORG_TITLE} Organisation:"

curl -L -s --header "Authorization: ${API_KEY}" \
    --data "id=${TEST_ORG_ID}&object=test_org_admin&object_type=user&capacity=admin" \
    ${CKAN_ACTION_URL}/member_create

curl -L -s --header "Authorization: ${API_KEY}" \
    --data "id=${TEST_ORG_ID}&object=test_org_editor&object_type=user&capacity=editor" \
    ${CKAN_ACTION_URL}/member_create

curl -L -s --header "Authorization: ${API_KEY}" \
    --data "id=${TEST_ORG_ID}&object=test_org_member&object_type=user&capacity=member" \
    ${CKAN_ACTION_URL}/member_create
##
# END.
#

##
# BEGIN: Create a Data Request organisation with test users for admin, editor and member and default data requests
#
# Data Requests requires a specific organisation to exist in order to create DRs for Data.Qld
DR_ORG_NAME=open-data-administration-data-requests
DR_ORG_TITLE="Open Data Administration (data requests)"

echo "Creating test users for ${DR_ORG_TITLE} Organisation:"

paster --plugin=ckan user add dr_admin email=dr_admin@localhost password=password -c ${CKAN_INI_FILE}
paster --plugin=ckan user add dr_editor email=dr_editor@localhost password=password -c ${CKAN_INI_FILE}
paster --plugin=ckan user add dr_member email=dr_member@localhost password=password -c ${CKAN_INI_FILE}

echo "Creating ${DR_ORG_TITLE} Organisation:"

DR_ORG=$( \
    curl -L -s --header "Authorization: ${API_KEY}" \
    --data "name=${DR_ORG_NAME}&title=${DR_ORG_TITLE}" \
    ${CKAN_ACTION_URL}/organization_create
)

DR_ORG_ID=$(echo $DR_ORG | sed -r 's/^(.*)"id": "(.*)",(.*)/\2/')

echo "Assigning test users to ${DR_ORG_TITLE} Organisation:"

curl -L -s --header "Authorization: ${API_KEY}" \
    --data "id=${DR_ORG_ID}&object=dr_admin&object_type=user&capacity=admin" \
    ${CKAN_ACTION_URL}/member_create

curl -L -s --header "Authorization: ${API_KEY}" \
    --data "id=${DR_ORG_ID}&object=dr_editor&object_type=user&capacity=editor" \
    ${CKAN_ACTION_URL}/member_create

curl -L -s --header "Authorization: ${API_KEY}" \
    --data "id=${DR_ORG_ID}&object=dr_member&object_type=user&capacity=member" \
    ${CKAN_ACTION_URL}/member_create


echo "Creating test Data Request:"

curl -L -s --header "Authorization: ${API_KEY}" \
    --data "title=Test Request&description=This is an example&organization_id=${DR_ORG_ID}" \
    ${CKAN_ACTION_URL}/create_datarequest

echo "Creating closed Data Request:"

Closed_DR=$( \
    curl -L -s \
    --header "Authorization: ${API_KEY}" \
    --data "title=Closed Request&description=This is an example&organization_id=${DR_ORG_ID}" \
    ${CKAN_ACTION_URL}/create_datarequest \
)

echo $Closed_DR

# # Get the ID of that newly created Data Request
CLOSE_DR_ID=$(echo $Closed_DR | tr -d '\n' | sed -r 's/^(.*)}, "id": "([a-z0-9\-]*)",(.*)/\2/')
echo $CLOSE_DR_ID

echo "Closing Data Request:"

curl -L -s --header "Authorization: ${API_KEY}" \
    --data "id=${CLOSE_DR_ID}&close_circumstance=Requestor initiated closure" \
    ${CKAN_ACTION_URL}/close_datarequest

##
# END.
#

# Use CKAN's built-in paster command for creating some test datasets...
paster create-test-data -c ${CKAN_INI_FILE}

# Datasets need to be assigned to an organisation

echo "Assigning test Datasets to Organisation open-data-administration-data-requests..."

curl -L -s -q --header "Authorization: ${API_KEY}" \
    --data "id=annakarenina&owner_org=${DR_ORG_ID}" \
    ${CKAN_ACTION_URL}/package_patch >> /dev/null

curl -L -s -q --header "Authorization: ${API_KEY}" \
    --data "id=warandpeace&owner_org=${DR_ORG_ID}" \
    ${CKAN_ACTION_URL}/package_patch >> /dev/null
##
# END.
#

deactivate
