* README.txt
* 
* DESCRIPTION:
*    Information and installation instructions for the package MAIL_CLIENT
*
* AUTHOR:
*    Carsten Czarski (carsten.czarski@gmx.de)
*
* CONTRIBUTORS:
*    Andre Meier, Christian Hasslbauer, Thomas Schild, Axel Röber    
*
* PREREQUISITES:
*    Tested with Oracle Database 11.2.0.4 or higher; older versions might work, but this is not tested 
*    Java in the database must be installed and enabled
*    -----------------------------------------------------------------------
*      SQL> select comp_name, version from dba_registry where comp_name like '%JAVA%'
*
*      COMP_NAME                                VERSION
*      ---------------------------------------- ------------------------------
*      JServer JAVA Virtual Machine             11.2.0.4.0
*    -----------------------------------------------------------------------
*     
*    Appropriate "java_pool_size" setting; at least 50MB 
*  
*  PRIVILEGES REQUIRED:
*  The DB user which uses the package and the package owner need appropriate Java privileges
*  in order to connect to the mailserver. These privileges are to be granted
*  by a DBA user with the following command:
*
*  begin
*    dbms_java.grant_permission(
*      grantee           => '[dbuser]',
*      permission_type   => 'SYS:java.net.SocketPermission',
*      permission_name   => '[mailserver name or "*" for the whole network]',
*      permission_action => 'connect,resolve'
*    );
*  end;
*
*  begin
*    dbms_java.grant_permission(
*      grantee           => '[dbuser]',
*      permission_type   => 'SYS:java.lang.RuntimePermission',
*      permission_name   => 'setFactory',
*      permission_action => ''
*    );
*  end;
*
* INSTALLATION PROCDEDURE:
*    SQL> start install.sql
*
* PROCEDURE FOR PUBLISHING THE PACKAGE TO ALL USERS 
* Note: Java network privileges are still required
*    SQL> start grantPublic.sql 
* 
* DEINSTALLATION STEPS:
*    SQL> start uninstall.sql
* 
