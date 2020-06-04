#!/bin/bash

if [[ -z "${CIRCLE_PULL_REQUEST}" ]];
then
	echo "This is not a pull request, no sniffing needed."
	exit 0
else
	echo "This is a pull request, continuing"
fi

# Check if phpcs.xml is present 
if [ ! -f phpcs.xml ]
then
	echo "No phpcs.xml file found."
	exit 0
fi

if [[ -z $GITHUB_TOKEN ]];
then
	echo "GITHUB_TOKEN not set"
	exit 1
fi

regexp="[[:digit:]]\+$"
PR_NUMBER=`echo $CIRCLE_PULL_REQUEST | grep -o $regexp`

url="https://api.github.com/repos/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/pulls/$PR_NUMBER"

target_branch=$(curl -s -X GET -G \
$url \
-d access_token=$GITHUB_TOKEN | jq '.base.ref' | tr -d '"')

echo "Resetting $target_branch to where the remote version is..."
git checkout -q $target_branch

git reset --hard -q origin/$target_branch

git checkout -q $CIRCLE_BRANCH

echo "Getting list of changed files..."
changed_files=$(git diff --name-only $target_branch..$CIRCLE_BRANCH -- '*.php')

if [[ -z $changed_files ]]
then
	echo "There are no files to check."
	exit 0
fi

echo "Installing VIPCS and PHPCS Globally"
composer g require --dev automattic/vipwpcs dealerdirect/phpcodesniffer-composer-installer

echo "Installing VIPCS and PHPCS at the project level"
composer require --dev automattic/vipwpcs dealerdirect/phpcodesniffer-composer-installer

echo "Checking which standards are installed"
~/.composer/vendor/bin/phpcs -i

echo "Running phpcs..."
~/.composer/vendor/bin/phpcs --standard=WordPress-VIP-Go -sp --basepath=. --ignore=vendor --exclude=WordPress.WP.TimezoneChange $changed_files