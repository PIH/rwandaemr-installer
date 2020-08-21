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

DROP PROCEDURE IF EXISTS ensure_concept_and_frequency;

#

CREATE PROCEDURE ensure_concept_and_frequency (
    _frequency_uuid CHAR(38),
    _concept_uuid CHAR(38),
    _frequency_per_day DOUBLE
)
BEGIN
    DECLARE _concept_id INT;
    DECLARE _frequency_id INT;

    SELECT order_frequency_id INTO _frequency_id FROM order_frequency WHERE uuid = _frequency_uuid COLLATE utf8_unicode_ci;

    IF ( _frequency_id IS NULL ) THEN

        SELECT concept_id INTO _concept_id FROM concept WHERE uuid = _concept_uuid COLLATE utf8_unicode_ci;

        IF ( _concept_id IS NULL ) THEN
            CALL ensure_concept(_concept_uuid, 'N/A', 'Frequency', 0);
            SELECT concept_id INTO _concept_id FROM concept WHERE uuid = _concept_uuid COLLATE utf8_unicode_ci;
        END IF;

        INSERT INTO order_frequency (concept_id, frequency_per_day, creator, date_created, uuid)
        values (_concept_id, _frequency_per_day, 1, now(), _frequency_uuid);

    END IF;
END;

#

DROP PROCEDURE IF EXISTS migrate_frequency;

#

CREATE PROCEDURE migrate_frequency (
    _frequency_uuid CHAR(38),
    _frequency_non_coded VARCHAR(255)
)
BEGIN
    DECLARE _frequency_id INT;
    SELECT order_frequency_id INTO _frequency_id FROM order_frequency WHERE uuid = _frequency_uuid COLLATE utf8_unicode_ci;
    IF ( _frequency_id IS NOT NULL ) THEN
        UPDATE drug_order SET frequency = _frequency_id where frequency_non_coded = _frequency_non_coded COLLATE utf8_unicode_ci;
    END IF;
END;

#