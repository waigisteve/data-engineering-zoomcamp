{% macro classify_day_type(datetime_column) %}

    case
        when extract(isodow from {{ datetime_column }}) between 1 and 5
            then 'Weekday'
        else 'Weekend'
    end

{% endmacro %}
