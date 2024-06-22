package Kursach.AptekaSystem.RowMappers;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.jdbc.core.RowMapper;

import java.sql.ResultSet;
import java.sql.SQLException;

public class JsonNodeRowMapper implements RowMapper<JsonNode> {

    private static final ObjectMapper objectMapper = new ObjectMapper();

    @Override
    public JsonNode mapRow(ResultSet rs, int rowNum) throws SQLException {
        String jsonString = rs.getString(1);
        try {
            return objectMapper.readTree(jsonString);
        } catch (Exception e) {
            throw new SQLException("Ошибка при конвертации строки в JsonNode", e);
        }
    }
}
