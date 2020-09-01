update global_property set property_value=@child_name where property='sync.server_name';

INSERT INTO global_property(property, property_value, uuid)
VALUES ('sync.server_uuid', @child_server_uuid, uuid())
ON DUPLICATE KEY UPDATE property_value = @child_server_uuid;

-- update global_property set property_value='<%= @sync_admin_email %>' where property='sync.admin_email';
update global_property set property_value='500' where property='sync.max_records.web';

insert into sync_server(nickname, address, server_type, username, password, uuid, disabled)
  select * from (select @sync_parent_name, @sync_parent_address, 'PARENT', @sync_parent_user_name,  @sync_parent_user_password, @sync_parent_uuid, 0) as tmp
  where not exists (select server_id from sync_server where nickname=@sync_parent_name) LIMIT 1;

update sync_server set address=@sync_parent_address, server_type='PARENT', username=@sync_parent_user_name, password=@sync_parent_user_password, uuid=@sync_parent_uuid, disabled=0 where nickname=@sync_parent_name;

select server_id from sync_server where nickname=@sync_parent_name into @parent_server_id;
select @parent_server_id;


-- add the default sync classes not to send/export
select 0 into @send_to;
select 0 into @receive_from;
select 1 into @default_send_to;
select 1 into @default_receive_from;

-- add the default sync classes not to send/export
insert into sync_server_class(class_id, server_id, send_to, receive_from)
  select * from (select class_id, @parent_server_id, @send_to, @receive_from from sync_class where default_send_to=0) as tmp
  where not exists (select server_id from sync_server_class where server_id = @parent_server_id) ;

-- add org.openmrs
insert into sync_class(name, default_send_to, default_receive_from)
  select * from (select 'org.openmrs', @default_send_to, @default_receive_from) as tmp
  where not exists (select class_id from sync_class where name = 'org.openmrs') ;

select class_id from sync_class where name = 'org.openmrs' into @org_openmrs_class_id;
select @org_openmrs_class_id;

-- do not receive any org.openmrs classes from the parent
insert into sync_server_class(class_id, server_id, send_to, receive_from)
  select * from (select @org_openmrs_class_id, @parent_server_id, 1, 0) as tmp
  where not exists (select server_class_id from sync_server_class
  where class_id = @org_openmrs_class_id and server_id = @parent_server_id);

-- add org.openmrs.api.db.SerializedObject
insert into sync_class(name, default_send_to, default_receive_from)
  select * from (select 'org.openmrs.api.db.SerializedObject', @default_send_to, @default_receive_from) as tmp
  where not exists (select class_id from sync_class where name = 'org.openmrs.api.db.SerializedObject') ;

select class_id from sync_class where name = 'org.openmrs.api.db.SerializedObject' into @org_openmrs_api_db_serializedobject_class_id;
select @org_openmrs_api_db_serializedobject_class_id;

-- do not send any org.openmrs.api.db.SerializedObject classes to the parent
insert into sync_server_class(class_id, server_id, send_to, receive_from)
  select * from (select @org_openmrs_api_db_serializedobject_class_id, @parent_server_id, 0, 1) as tmp
  where not exists (select server_class_id from sync_server_class
  where class_id = @org_openmrs_api_db_serializedobject_class_id and server_id = @parent_server_id);

-- add org.openmrs.module.reporting
insert into sync_class(name, default_send_to, default_receive_from)
  select * from (select 'org.openmrs.module.reporting', @default_send_to, @default_receive_from) as tmp
  where not exists (select class_id from sync_class where name = 'org.openmrs.module.reporting') ;

select class_id from sync_class where name = 'org.openmrs.module.reporting' into @org_openmrs_module_reporting_class_id;
select @org_openmrs_module_reporting_class_id;

-- do not send any org.openmrs.module.reporting classes to the parent
insert into sync_server_class(class_id, server_id, send_to, receive_from)
  select * from (select @org_openmrs_module_reporting_class_id, @parent_server_id, 0, 1) as tmp
  where not exists (select server_class_id from sync_server_class
  where class_id = @org_openmrs_module_reporting_class_id and server_id = @parent_server_id);

