DROP PROCEDURE IF EXISTS ensure_concept;

#

CREATE PROCEDURE ensure_concept (
    _concept_uuid CHAR(38),
    data_type_name VARCHAR(255),
    class_name VARCHAR(255),
    _is_set TINYINT(1)
)
BEGIN
    DECLARE data_type_id INT;
    DECLARE class_id INT;
    DECLARE _concept_id INT;

    SELECT concept_id INTO _concept_id FROM concept WHERE uuid = _concept_uuid COLLATE utf8_unicode_ci;

    IF ( _concept_id IS NULL ) THEN

        SELECT concept_datatype_id INTO data_type_id FROM concept_datatype WHERE name = data_type_name COLLATE utf8_unicode_ci;
        SELECT concept_class_id INTO class_id FROM concept_class WHERE name = class_name COLLATE utf8_unicode_ci;

        INSERT INTO concept (datatype_id, class_id, is_set, creator, date_created, changed_by, date_changed, uuid)
        values (data_type_id, class_id, _is_set, 1, now(), 1, now(), _concept_uuid);

    END IF;
END;

#

DROP PROCEDURE IF EXISTS ensure_concept_name;

#

CREATE PROCEDURE ensure_concept_name (
    _concept_name_uuid CHAR(38),
    _concept_uuid CHAR(38),
    _name VARCHAR(255),
    _concept_name_type VARCHAR(50)
)
BEGIN
    DECLARE _locale_preferred_val TINYINT(1);
    DECLARE _concept_id INT;
    DECLARE _concept_name_id INT;

    CASE
        WHEN _concept_name_type = 'FULLY_SPECIFIED' THEN
            SET _locale_preferred_val = '1';
        ELSE
            SET _locale_preferred_val = '0';
        END CASE;

    SELECT concept_id INTO _concept_id FROM concept WHERE uuid = _concept_uuid COLLATE utf8_unicode_ci;
    SELECT concept_name_id INTO _concept_name_id FROM concept_name WHERE uuid = _concept_name_uuid COLLATE utf8_unicode_ci;

    IF ( _concept_name_id IS NULL ) THEN

        INSERT INTO concept_name (concept_id, name, locale, locale_preferred, creator, date_created, concept_name_type, uuid)
        values (_concept_id, _name, 'en', _locale_preferred_val, 1, now(), _concept_name_type, _concept_name_uuid);

    END IF;
END;

#

DROP PROCEDURE IF EXISTS ensure_global_property;

#

CREATE PROCEDURE ensure_global_property (
    _name VARCHAR(255),
    _value MEDIUMTEXT,
    _description TEXT
)
BEGIN
    DECLARE _gp_uuid CHAR(38);

    SELECT uuid INTO _gp_uuid FROM global_property WHERE property = _name COLLATE utf8_unicode_ci;

    IF ( _gp_uuid IS NULL ) THEN

        INSERT INTO global_property (property, property_value, description, uuid)
        values (_name, _value, _description, uuid());

    END IF;

    UPDATE global_property SET property_value = _value WHERE property = _name COLLATE utf8_unicode_ci;

END;

#
