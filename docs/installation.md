# RwandaEMR 2.x Installation

There are three primary methods we use to install and run the RwandaEMR 2.x distribution.

* Native Ubuntu (currently for production)
* Docker (currently for test/ci)
* SDK (development)

## Native installation

In order to properly document, test, and describe the steps involved in a native Ubuntu installation, I'll describe each
of the below steps using Vagrant to simulate a new, freshly installed machine.

#### 1. Install the O/S

We are considering using this opportunity to upgrade to the latest Ubuntu LTS - 20.04.  
Our [Ubuntu 20.04 Vagrant box](../src/main/resources/vagrant/20.04/Vagrantfile) reflects this.
Copy this Vagrantfile into your directory of choice, and run:  ```vagrant up```
You can ssh into the box at any time by running ```vagrant ssh``` from this same directory.

#### 2. Install the software components

We use [Ansible](../src/main/resources/ansible) here to both execute and document the steps involved in the process
Get a terminal in the above directory, and execute:
```./vagrant-install.sh```
This will execute an installation for the Vagrant Box set up in Step 1, and perform the following steps:

* Install base packages and configure timezone
* Install MySQL 8.0
* Install an "openmrs" user and "/home/openmrs" directory to install the software
* Install OpenJDK-8-JDK and Tomcat 7.0.107
* Configure Tomcat for basic use (non-SSL, no Apache) and set-up a service and log rotation
* Download the distribution and install all artifacts into appropriate directories

These steps can be adjusted to meet your needs (add SSL, etc), but should also serve as a reference for how we might do things.

The biggest change in the above from what we may have done historically is in how we install the distribution artifacts.
The RwandaEMR 2.x distribution is published and version-controlled via Maven, and both released versions and snapshot
versions should be retrieved via the OpenMRS Maven repository.

SNAPSHOT versions which update periodically during development and testing 
[can be found here](https://openmrs.jfrog.io/ui/repos/tree/General/modules-pih-snapshots%2Forg%2Fopenmrs%2Fdistro%2Frwandaemr-imb%2F2.0.0-SNAPSHOT).  

One should generally identify the most recent SNAPSHOT available by timestamp in the filename, and download this version.
One can also use the [download-maven-artifact.sh](../src/main/resources/scripts/download-maven-artifact.sh) script to achieve this.

Release versions [can be found here](https://openmrs.jfrog.io/ui/repos/tree/General/modules-pih%2Forg%2Fopenmrs%2Fdistro%2Frwandaemr-imb)

These distribution artifacts are zip files that contain several directories.  These directories may expand in the future, but 
currently contain:

* openmrs_webapps/openmrs.war  ->  Gets installed into the tomcat/webapps folder
* openmrs_modules/*.omod       ->  Gets installed into the modules folder
* openmrs_configuration/*      ->  Gets installed into a "configuration" directory in the OpenMRS data directory

#### 3. Restore the database

* Source in the migrated database create during the [migration](migration.md) that is compatible with the MySQL version installed above.
* Restore any other data that had been backed up in the OpenMRS data directory (eg. complex obs, etc)

#### 4. Start up the server

* You should be able to start up the server, see it start up, and tail the logs and confirm there are no errors.
* You should be able to log into the server and navigate around

## Docker Installation

Installing using Docker is the technique employed on the test/CI servers.  This process can be best explained by reviewing
the [docker-compose setup](../src/main/resources/docker/docker-compose-2x.yml) and
the [deploy-rwandaemr.sh](../src/main/resources/scripts/deploy-rwandaemr.sh) script that is used to set up our CI / test servers.

Currently, the main usage of this project is in the provisioning of CI servers for testing.  The scripts are executed
from the Bamboo CI server, using a command in the format of:

```-vv <host> /bin/bash -c "'cd <workdir> && ./rwandaemr-installer/src/main/resources/scripts/<script> <args>'"```

#### Weekly job

* Runs once per week (Monday 9pm)
* Purpose is full refresh using the latest data from an anonymized backup, and testing the full migration and installation process
* Executes the following stages (script and args shown):
  * Download database:
    ```download-rwanda-db.sh --siteName=butaro```
  * Refresh 1.x environment:
    ```deploy-rwandaemr.sh --siteName=butaro --version=1x --omrsDbPort=3308 --omrsServerPort=8080 --recreate=true```
  * Refresh 2.x environment:
    ```deploy-rwandaemr.sh --siteName=butaro --version=2x --omrsDbPort=3307 --omrsServerPort=8081 --recreate=true```

#### Nightly job

* Runs once per day at 9pm (excluding Monday, which is reserved for the full refresh job)
* Purpose is to update servers to the latest distribution (modules, war, etc) but not recreating the database
* Executes the following stages (script and args shown):
  * Refresh 1.x environment:
    ```deploy-rwandaemr.sh --siteName=butaro --version=1x --omrsDbPort=3308 --omrsServerPort=8080```
  * Refresh 2.x environment:
    ```deploy-rwandaemr.sh --siteName=butaro --version=2x --omrsDbPort=3307 --omrsServerPort=8081```
