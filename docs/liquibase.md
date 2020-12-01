# Liquibase migration scripts

We use Liquibase as the means to author and execute the migrations that need to be run both pre-upgrade and post-upgrade
of OpenMRS core.  The steps for executing the liquibase migrations are as follows:

The [migrations folder](../src/main/resources/migrations) contains upgrade scripts to be run via liquibase prior to or immediately following an upgrade.
This is not packaged but is intended to be used standalone from the command line.

To execute this, you should run the following command from the top-level directory of this project:

`mvn liquibase:update`

This accepts several arguments to control access to the database to execute the migrations against.  
The arguments are as follows, which show their default values that will be used if they are not explicity included:

-Ddb_host=localhost
-Ddb_port=3306
-Ddb_name=openmrs
-Ddb_user=openmrs
-Ddb_password=openmrs
-Dchangelog_dir=pre-2x-upgrade

So, to execute 2x pre-upgrade migrations, followed by post-upgrade migrations on an instance of MySQL, 
where the above are accurate aside from db_port and db_password, you would run:

`mvn liquibase:update -Ddb_port=3308 -Ddb_password=MyRootPassword123`
`mvn liquibase:update -Ddb_port=3308 -Ddb_password=MyRootPassword123 -Dchangelog_dir=post-2x-upgrade`

