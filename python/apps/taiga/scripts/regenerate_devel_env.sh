#!/bin/bash

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2021-present Kaleidos Ventures SL

export DJANGO_SETTINGS_MODULE=taiga.base.django.settings

show_answer=true
while [ $# -gt 0 ]; do
  	case "$1" in
    	-y)
    	  	show_answer=false
      	;;
  	esac
	shift
done

if $show_answer ; then
	echo "WARNING!! This script will REMOVE your Taiga's database and you'll LOSE all the data."
	read -p "Are you sure you want to proceed? (Press Y to continue): " -n 1 -r
	echo    # (optional) move to a new line
	if [[ ! $REPLY =~ ^[Yy]$ ]] ; then
		exit 1
	fi
	echo
fi

read -p 'Specify a Postgres user [default: postgres]: ' dbuser
read -p 'Specify database name [default: taiga]: ' dbname
read -p 'Specify host [default: localhost]: ' dbhost
read -p 'Specify port [default: 5432]: ' dbport
dbuser=${dbuser:-postgres}
dbname=${dbname:-taiga}
dbhost=${dbhost:-localhost}
dbport=${dbport:-5432}

echo "-> Remove '${dbname}' DB"
dropdb -U $dbuser -h $dbhost -p $dbport $dbname
echo "-> Create '${dbname}' DB"
createdb -U $dbuser -h $dbhost -p $dbport $dbname

if [ "$?" -ne "0" ]; then
  echo && echo "Error accessing the database, aborting."
else
  echo "-> Load migrations"
  python -m taiga migrate
  python -m taiga tasksqueue init
  echo "-> Load initial user (admin/123123)"
  python -m taiga loadfixtures initial_user
  echo "-> Load initial project_templates (scrum/kanban)"
  python -m taiga loadfixtures initial_project_templates
  echo "-> Generate sample data"
  python -m taiga sampledata
fi
