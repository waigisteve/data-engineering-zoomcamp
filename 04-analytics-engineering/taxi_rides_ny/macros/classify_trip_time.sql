{% macro classify_trip_time(datetime_column) %}

    case
        when extract(hour from {{ datetime_column }}) >= 7
         and extract(hour from {{ datetime_column }}) < 10
            then 'Morning Rush'

        when extract(hour from {{ datetime_column }}) >= 10
         and extract(hour from {{ datetime_column }}) < 16
            then 'Midday'

        when extract(hour from {{ datetime_column }}) >= 16
         and extract(hour from {{ datetime_column }}) < 19
            then 'Evening Rush'

        when extract(hour from {{ datetime_column }}) >= 19
            then 'Evening'

        else 'Overnight'
    end

{% endmacro %}
