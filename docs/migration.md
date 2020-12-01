# Migrating a database from 1.9 to 2.3

In order to migrate a database with existing data from OpenMRS 1.9 compatibility to 2.3 compatibility,
we have established the following process.

## Migration steps to run (in order)

#### 1. Ensure all data is sync'd, stop everything and back-up existing data 

There are several purposes to this.  First, if anything goes wrong in the upgrade, we want to be able to revert the system
to it's pre-migration state and ensure there are no disruptions to usage and no loss of data.  Second, as the upgrade
migration process will be performing data transformations and also excluding some historical data, the full backup will
serve as an archive in case any of the original data needs to be retrieved and accessed in the future.

Steps:

* Ensure all child servers have fully synchronized their changes up to the parent server.
* Stop usage of all servers and shut down Tomcat on all servers in sync network.
* Stop OpenMRS and any other connections to the existing database on the parent server.
* Back up existing .OpenMRS directory, especially complex_obs, on all parent and child servers.
* Take a full back-up of the existing database in case any issues arise during the upgrade process.

  ```mysqldump -u${MYSQL_USERNAME} -p${MYSQL_PASSWORD} ${OPENMRS_DATABASE_NAME} > ${MYSQL_BACKUP_FILENAME}```

#### 2. Back up the specific tables and data we wish to retain

Over the long history of the Rwanda EMR system, there are tables and data that remain in the system but are no longer used
or needed.  There are also tables that may have served as a historical archive, but add no additional value to the 
existing clinical data and can be backed up and archived.  We should consider excluding this data from our upgrade process.

Those tables that should be included in schema, but excluded from data may include:

* sync_record, sync_server_record, sync_import:  Not needed since all servers will be sync'd up.
* hl7_in_archive, hl7_in_error, hl7_in_queue:  Used by InfoPath form entry, no usage since 2011.
* formentry_archive, formentry_error, formentry_queue:  Used by InfoPath form entry, no usage since 2011.
* formentry_xsn:  Contains (large) binary InfoPath form files that contained the schema and layout for InfoPath forms
* emrmonitor_report, emrmonitor_report_metric:  Monitoring / uptime data logged when this was running, but no longer needed.

Steps:

Execute:  [export-db-for-upgrade.sh](../src/main/resources/scripts/export-db-for-upgrade.sh)

#### 3. Perform database migrations to convert the 1.9-compatible export into 2.3-compatible exports

The primary task here is to run the OpenMRS core upgrade process.  However, those upgrades will fail if the database is not
in a certain valid state at the start of the upgrade.  The core upgrades also do not fully account for each of the 
RwandaEMR modules, existing configurations, and other non-standard database state.  So the actual migration involves
pre-migration updates, the OpenMRS upgrade, and finally post-migration updates.

Steps:

Execute:  [execute-2x-migration.sh](../src/main/resources/scripts/execute-2x-migration.sh)

Parameters you need to pass into this script:

```--inputSqlFile=/path/to/sql/file.sql```: Point this to the mysqldump file produced in Step 2 above
```--migrationDir=/path/to/migration/dir```: Point this to an empty directory to write migration output files

This script uses Docker under the hood to perform the migration, as well as other libraries.  You need the following
installed in order to execute this script:

* Docker
* Java 8
* Maven 3
* pv (pipe viewer)

This script performs the following operations:

1.  Creates a new MySQL 5.6 Docker instance and imports the provided mysqldump source file into this database.
2.  Executes the [pre-2x-upgrade](../src/main/resources/migrations/pre-2x-upgrade) migrations against this database.  See [liquibase](liquibase.md).
3.  Starts up OpenMRS in a Docker container connected to the MySQL container, and executes the core updates for OpenMRS 2.3
4.  Executes the [post-2x-upgrade](../src/main/resources/migrations/post-2x-upgrade) migrations against this database.   See [liquibase](liquibase.md).
5.  Creates a mysqldump backup of this upgraded DB, compatible with MySQL 5.6
6.  Performs a MySQL 5.7 upgrade against this database
7.  Creates a mysqldump backup of this upgraded DB, compatible with MySQL 5.7
8.  Performs a MySQL 8.0 upgrade against this database
9.  Creates a mysqldump backup of this upgraded DB, compatible with MySQL 8.0
10. Destroys the Docker containers

The result of this is that this script takes an OpenMRS 1.9 on MySQL 5.6 database dump as input, and produces 3 
output artifacts, each representing the upgraded database that is compatible with OpenMRS 2.3, and able to be 
sourced into MySQL 5.6, 5.7, or 8.0 instances as needed.

#### 4. Install the new RwandaEMR 2.x distribution

Now that you have a 2.x-compatible database dump, you can now proceed to the [deployment / installation process](installation.md).
