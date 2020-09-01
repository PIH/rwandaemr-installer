select @child_server_uuid;
select @sync_parent_uuid;
select @sync_parent_name;

update global_property set property_value=@sync_parent_name where property='sync.server_name';

INSERT INTO global_property(property, property_value, uuid)
VALUES ('sync.server_uuid', @sync_parent_uuid, uuid())
ON DUPLICATE KEY UPDATE property_value = @sync_parent_uuid;

insert into sync_server(nickname, server_type,  uuid, disabled)
  select * from (select @child_name, 'CHILD', @child_server_uuid, 0) as tmp
  where not exists (select server_id from sync_server where nickname=@child_name)
  LIMIT 1;

update sync_server set server_type='CHILD', uuid=@child_server_uuid, disabled=0 where nickname= @child_name;

select server_id from sync_server where nickname= @child_name into @child_server_id;

select 0 into @send_to;
select 0 into @receive_from;

-- add the default sync classes not to send/export
insert into sync_server_class(class_id, server_id, send_to, receive_from)
  select * from (select class_id, @child_server_id, @send_to, @receive_from from sync_class where default_send_to=0) as tmp
  where not exists (select server_id from sync_server_class where server_id = @child_server_id) ;

select class_id from sync_class where name = 'org.openmrs.org.openmrs' into @org_openmrs_class_id;
select @org_openmrs_class_id;
-- do not send any org.openmrs classes from this parent to the child
insert into sync_server_class(class_id, server_id, send_to, receive_from)
  select * from (select @org_openmrs_class_id, @child_server_id, 0, 1) as tmp
  where not exists (select server_class_id from sync_server_class where class_id = @org_openmrs_class_id and server_id = @child_server_id);

select class_id from sync_class where name = 'org.openmrs.api.db.SerializedObject' into @org_openmrs_api_db_serializedobject_class_id;
-- do not send any org.openmrs.api.db.SerializedObject classes to the parent
insert into sync_server_class(class_id, server_id, send_to, receive_from)
  select * from (select @org_openmrs_api_db_serializedobject_class_id, @child_server_id, 1, 0) as tmp
  where not exists (select server_class_id from sync_server_class where class_id = @org_openmrs_api_db_serializedobject_class_id and server_id = @child_server_id);

select class_id from sync_class where name = 'org.openmrs.module.reporting' into @org_openmrs_module_reporting_class_id;
-- do not send any org.openmrs.module.reporting classes to the parent
insert into sync_server_class(class_id, server_id, send_to, receive_from)
  select * from (select @org_openmrs_module_reporting_class_id, @child_server_id, 1, 0) as tmp
  where not exists (select server_class_id from sync_server_class where class_id = @org_openmrs_module_reporting_class_id and server_id = @child_server_id);

